#!/bin/bash

set -euo pipefail

IDA_ICONS_DIR_DEFAULT="$HOME/.local/share/icons/ida"
IDA_REGISTRY_DEFAULT="$HOME/.local/share/ida/apps.tsv"

ida__ensure_dir() {
  local dir="$1"
  mkdir -p "$dir"
}

ida__is_url() {
  case "$1" in
    http://*|https://*) return 0 ;;
    *) return 1 ;;
  esac
}

ida__prompt_yes_no() {
  local prompt="$1"
  local default_no="${2:-true}"

  # If not in an interactive terminal, default to "no".
  if [ ! -t 0 ]; then
    if [ "$default_no" = "true" ]; then
      return 1
    fi
    return 0
  fi

  local reply=""
  read -r -p "$prompt" reply
  case "${reply,,}" in
    y|yes) return 0 ;;
    *)
      if [ "$default_no" = "true" ]; then
        return 1
      fi
      return 0
      ;;
  esac
}

ida__download_icon() {
  local url="$1"
  local dest_without_ext="$2"

  local tmp
  tmp="$(mktemp)"

  # Use EXIT trap (not RETURN) so it reliably fires.
  # With `set -u`, a RETURN trap can sometimes run outside the variable scope.
  trap 'rm -f "${tmp:-}"' EXIT

  local user_agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"

  if command -v curl >/dev/null 2>&1; then
    if ! curl -fsSL -A "$user_agent" -H 'Accept: image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8' "$url" -o "$tmp"; then
      echo "Warning: failed to download icon: $url" >&2
      if ida__prompt_yes_no "Continue without icon? [y/N] "; then
        return 2
      fi
      return 1
    fi
  elif command -v wget >/dev/null 2>&1; then
    if ! wget -qO "$tmp" --user-agent "$user_agent" --header='Accept: image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8' "$url"; then
      echo "Warning: failed to download icon: $url" >&2
      if ida__prompt_yes_no "Continue without icon? [y/N] "; then
        return 2
      fi
      return 1
    fi
  else
    echo "Error: need curl or wget to download icons" >&2
    return 1
  fi

  local ext=""
  if [[ "$url" =~ \.([A-Za-z0-9]+)(\?|#|$) ]]; then
    ext="${BASH_REMATCH[1]}"
  fi

  if [ -z "$ext" ]; then
    if command -v file >/dev/null 2>&1; then
      local mime
      mime="$(file -b --mime-type "$tmp" || true)"
      case "$mime" in
        image/png) ext="png" ;;
        image/svg+xml) ext="svg" ;;
        image/webp) ext="webp" ;;
        image/jpeg) ext="jpg" ;;
        image/gif) ext="gif" ;;
        image/x-icon) ext="ico" ;;
      esac
    fi
  fi

  [ -z "$ext" ] && ext="png"

  local dest="${dest_without_ext}.${ext}"
  cp -f "$tmp" "$dest"
  echo "$dest"
}

ida__copy_icon() {
  local src="$1"
  local dest_without_ext="$2"

  if [ ! -f "$src" ]; then
    echo "Error: icon file not found: $src" >&2
    return 1
  fi

  # No-op if source already matches our target.
  # (e.g., user passes an icon already in ~/.local/share/icons/ida)
  if [ "$src" = "${dest_without_ext}.${src##*.}" ]; then
    echo "$src"
    return 0
  fi

  local ext="${src##*.}"
  if [ "$ext" = "$src" ]; then
    ext="png"
  fi

  local dest="${dest_without_ext}.${ext}"
  cp -f "$src" "$dest"
  echo "$dest"
}

# Resolve an icon spec into a usable Icon= value.
# - If empty: returns empty
# - If URL: downloads to $icons_dir/<app_name>.<ext>
# - If path: copies to $icons_dir/<app_name>.<ext>
# - Otherwise: treat as icon theme name and return as-is
ida_resolve_icon() {
  local app_name="$1"
  local icon_spec="${2:-}"
  local icons_dir="${3:-$IDA_ICONS_DIR_DEFAULT}"

  [ -z "$icon_spec" ] && return 0

  ida__ensure_dir "$icons_dir"

  local dest_base="$icons_dir/$app_name"

  if ida__is_url "$icon_spec"; then
    local downloaded
    if downloaded="$(ida__download_icon "$icon_spec" "$dest_base")"; then
      echo "$downloaded"
      return 0
    fi

    # If user chose to continue without icon, return empty.
    if [ "$?" -eq 2 ]; then
      return 0
    fi

    return 1
  fi

  if [[ "$icon_spec" == /* || "$icon_spec" == ./* || "$icon_spec" == ../* || -f "$icon_spec" ]]; then
    ida__copy_icon "$icon_spec" "$dest_base"
    return 0
  fi

  echo "$icon_spec"
}

# Registry format (TSV):
# name\ttype\tdesktop_file\ticon\tcreated_at_epoch
ida_registry_add() {
  local name="$1"
  local app_type="$2"
  local desktop_file="$3"
  local icon_value="${4:-}"
  local registry_file="${5:-$IDA_REGISTRY_DEFAULT}"

  ida__ensure_dir "$(dirname "$registry_file")"

  # Remove any existing entry for name+type
  if [ -f "$registry_file" ]; then
    awk -F'\t' -v n="$name" -v t="$app_type" '!( $1==n && $2==t )' "$registry_file" >"${registry_file}.tmp" || true
    mv -f "${registry_file}.tmp" "$registry_file"
  fi

  printf "%s\t%s\t%s\t%s\t%s\n" \
    "$name" \
    "$app_type" \
    "$desktop_file" \
    "$icon_value" \
    "$(date +%s)" >>"$registry_file"
}
