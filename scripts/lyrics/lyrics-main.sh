#!/bin/bash

cache_dir="/tmp/lyrics_cache"
mkdir -p "$cache_dir"

# Default parameters
max_length=65
offset_ms=0
update_interval_ms=200
json_output=0

# Parse command-line arguments
debug=0
debug_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
  --debug)
    debug=1
    shift
    ;;
  --debug-file)
    debug_file="$2"
    shift 2
    ;;
  --offset)
    offset_ms="$2"
    shift 2
    ;;
  --interval)
    update_interval_ms="$2"
    shift 2
    ;;
  --max-length)
    max_length="$2"
    shift 2
    ;;
  --json)
    json_output=1
    shift
    ;;
  *)
    echo "Unknown option: $1"
    echo "Usage: $0 [--debug] [--debug-file FILE] [--offset MS] [--interval MS] [--max-length LENGTH] [--json]"
    exit 1
    ;;
  esac
done

# Convert parameters once
update_interval_sec=$(awk "BEGIN {print $update_interval_ms / 1000}")
offset_sec=$(awk "BEGIN {print $offset_ms / 1000}")

# Debug log function
debug_log() {
  if [[ -n "$debug_file" ]]; then
    echo "[$(date '+%H:%M:%S.%3N')] $*" >>"$debug_file"
  fi
}

truncate_text() {
  local text="$1"
  if ((${#text} > max_length)); then
    echo "${text:0:max_length}…"
  else
    echo "$text"
  fi
}

# Global arrays for parsed lyrics (parsed once per song)
declare -a LYRICS_LINES
declare -a LYRICS_TIMES

# Parse lyrics once and store in global arrays
parse_lyrics() {
  local raw_lyrics="$1"

  # Clear arrays
  LYRICS_LINES=()
  LYRICS_TIMES=()

  if [[ -z "$raw_lyrics" ]]; then
    return
  fi

  local line_idx=0
  while IFS= read -r line; do
    if [[ "$line" =~ \[([0-9]+):([0-9]+\.[0-9]+)\] ]]; then
      local min="${BASH_REMATCH[1]}"
      local sec="${BASH_REMATCH[2]}"
      # Use bash arithmetic where possible
      local time_float=$(awk "BEGIN {printf \"%.2f\", $min*60 + $sec}")
      local text_only="${line#*]}"                           # Remove timestamp faster than sed
      text_only="${text_only#"${text_only%%[![:space:]]*}"}" # Trim leading spaces

      LYRICS_LINES[$line_idx]="$text_only"
      LYRICS_TIMES[$line_idx]="$time_float"
      ((line_idx++))
    fi
  done <<<"$raw_lyrics"

  debug_log "Parsed ${#LYRICS_LINES[@]} lyrics lines"
}

# Fast binary-like search for current line (start from last known position)
find_current_line() {
  local position_sec="$1"
  local start_idx="${2:-0}"

  local current_idx=-1
  local total=${#LYRICS_LINES[@]}

  # Start from last known position for efficiency
  for ((i = start_idx; i < total; i++)); do
    # Use bash's (( )) for faster comparison
    if (($(awk "BEGIN {print ($position_sec >= ${LYRICS_TIMES[$i]} ? 1 : 0)}"))); then
      current_idx=$i
    else
      # Times are sorted, so we can break early
      break
    fi
  done

  echo "$current_idx"
}

# Generate tooltip only when needed
generate_tooltip() {
  local current_idx="$1"

  if ((current_idx == -1)); then
    echo "Waiting for lyrics..."
    return
  fi

  # Calculate range (5 lines before and after)
  local start_idx=$((current_idx - 5))
  local end_idx=$((current_idx + 5))
  local total=${#LYRICS_LINES[@]}

  if ((start_idx < 0)); then
    start_idx=0
  fi
  if ((end_idx >= total)); then
    end_idx=$((total - 1))
  fi

  # Build output with all lines (including empty)
  local output=""
  for ((i = start_idx; i <= end_idx; i++)); do
    local line_text="${LYRICS_LINES[$i]}"

    if ((i == current_idx)); then
      # Highlight current line
      if [[ -n "$output" ]]; then
        output+=$'\n'
      fi
      output+="▶ ${line_text} ◀"
    else
      if [[ -n "$output" ]]; then
        output+=$'\n'
      fi
      output+="  ${line_text}"
    fi
  done

  echo -n "$output"
}

last_cache_key=""
last_position_sec=0
last_duration_sec=0
last_output=""
last_tooltip=""
last_line_idx=0

while true; do
  status=$(playerctl status 2>/dev/null)
  if [[ "$status" != "Playing" ]]; then
    if [[ "$status" == "Paused" && -n "$last_output" ]]; then
      # Keep showing last lyrics line when paused
      if ((json_output)); then
        jq -cn --arg text "$last_output" --arg tooltip "$last_tooltip" '{text:$text, tooltip:$tooltip}'
      else
        echo "$last_output"
      fi
    else
      # Don't show anything when not playing or no lyrics available
      if ((json_output)); then
        echo '{"text":"","tooltip":""}'
      else
        echo ""
      fi
    fi
    sleep 1
    continue
  fi

  artist=$(playerctl metadata artist 2>/dev/null)
  title=$(playerctl metadata title 2>/dev/null)
  duration=$(playerctl metadata mpris:length 2>/dev/null || echo 0)
  duration_sec=$(awk "BEGIN {print int($duration / 1000000)}")

  if [[ -z "$artist" || -z "$title" ]]; then
    if ((json_output)); then
      echo '{"text":"","tooltip":""}'
    else
      echo ""
    fi
    sleep 1
    continue
  fi

  cache_key=$(printf "%s_%s" "$artist" "$title" |
    tr ' ' '_' |
    tr -dc 'A-Za-z0-9_')
  cache_file="${cache_dir}/${cache_key}.json"

  if [[ "$cache_key" != "$last_cache_key" ]]; then
    last_cache_key="$cache_key"
    last_position_sec=0
    last_duration_sec="$duration_sec"
    last_line_idx=0

    if ((debug)); then
      echo "—▶ New song detected: '$artist' — '$title'"
      echo "    cache_key = '$cache_key'"
    fi

    if [[ -f "$cache_file" ]]; then
      cache_hit=1
      if ((debug)); then
        echo "    [cache hit] reading from $cache_file"
      fi
    else
      cache_hit=0
      if ((debug)); then
        echo "    [cache miss] fetching from API…"
      fi

      if ((json_output)); then
        loading_text=$(truncate_text "Loading lyrics for $title - $artist")
        jq -cn --arg text "$loading_text" --arg tooltip "Loading..." '{text:$text, tooltip:$tooltip}'
      else
        echo "$(truncate_text "Loading lyrics for $title - $artist")"
      fi

      sleep 2 # Sleep to allow playerctl to update metadata fully, avoids incorrect api calls

      artist_encoded=$(printf "%s" "$artist" | jq -sRr @uri)
      title_encoded=$(printf "%s" "$title" | jq -sRr @uri)
      duration=$(playerctl metadata mpris:length 2>/dev/null || echo 0)
      duration_sec=$(awk "BEGIN {print int($duration / 1000000)}")

      api_url="https://lrclib.net/api/get?artist_name=${artist_encoded}&track_name=${title_encoded}&duration=${duration_sec}"
      if ((debug)); then
        echo "    Requesting:"
        echo "      $api_url"
      fi

      response=$(curl -s -H "User-Agent: waybar_lyrics (https://github.com/rainaisntbald/waybar_lyrics)" "$api_url")
      response=$(echo "$response" | jq --arg url "$api_url" '. + {request_url: $url}')
      echo "$response" >"$cache_file"
    fi

    raw_lyrics=$(jq -r '.syncedLyrics // ""' <"$cache_file" 2>/dev/null)
    if [[ -z "$raw_lyrics" ]]; then
      # Clear arrays
      LYRICS_LINES=()
      LYRICS_TIMES=()
      if ((debug)); then
        echo "    [warning] no syncedLyrics in JSON, fallback to empty"
      fi
    else
      # Parse lyrics ONCE per song
      parse_lyrics "$raw_lyrics"
      if ((debug)); then
        echo "    Loaded ${#LYRICS_LINES[@]} lyric lines"
      fi
    fi
  fi

  if ((debug)); then
    if ((cache_hit)); then
      echo "    (cache hit for '$cache_key')"
    else
      echo "    (cache miss for '$cache_key')"
    fi
    sleep 1
    continue
  fi

  position_sec=$(playerctl position 2>/dev/null)
  if [[ -z "$position_sec" ]]; then
    position_sec=0
  fi

  # Apply offset once
  position_sec=$(awk "BEGIN {printf \"%.2f\", $position_sec + $offset_sec}")

  debug_log "position: $position_sec, offset: $offset_ms ms, lines: ${#LYRICS_LINES[@]}"

  delta=$(awk "BEGIN {print $position_sec - $last_position_sec}")
  if (($(awk "BEGIN {print ($delta < -0.1)}"))); then
    last_position_sec="$position_sec"
    last_line_idx=0 # Reset line index on seek
  fi

  last_position_sec="$position_sec"

  if ((${#LYRICS_LINES[@]} > 0)); then
    # Find current line starting from last known position
    current_idx=$(find_current_line "$position_sec" "$last_line_idx")

    if ((current_idx == -1)); then
      # No lyrics line found - show nothing
      if ((json_output)); then
        echo '{"text":"","tooltip":""}'
      else
        echo ""
      fi
      last_output=""
      last_tooltip=""
    else
      last_line_idx=$current_idx
      current_line="${LYRICS_LINES[$current_idx]}"
      output=" $(truncate_text "$current_line")"

      if ((json_output)); then
        # Generate tooltip only when needed
        tooltip=$(generate_tooltip "$current_idx")

        # Produce valid JSON; keep real newlines for tooltip
        jq -cn --arg text "$output" --arg tooltip "$tooltip" '{text:$text, tooltip:$tooltip}'
        last_tooltip="$tooltip"
      else
        echo "$output"
      fi

      last_output="$output"
    fi
  else
    # No synced lyrics available - show nothing
    if ((json_output)); then
      echo '{"text":"","tooltip":"No synced lyrics available"}'
    else
      echo ""
    fi
    last_output=""
    last_tooltip=""
  fi

  sleep "$update_interval_sec"
done
