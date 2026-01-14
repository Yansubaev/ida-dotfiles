#!/bin/bash

cache_dir="/tmp/lyrics_cache"

# Get current playing track info
status=$(playerctl status 2>/dev/null)
if [[ "$status" != "Playing" && "$status" != "Paused" ]]; then
  echo "Not playing"
  exit 0
fi

artist=$(playerctl metadata artist 2>/dev/null)
title=$(playerctl metadata title 2>/dev/null)

if [[ -z "$artist" || -z "$title" ]]; then
  echo "No track info"
  exit 0
fi

# Generate cache key
cache_key=$(printf "%s_%s" "$artist" "$title" |
  tr ' ' '_' |
  tr -dc 'A-Za-z0-9_')
cache_file="${cache_dir}/${cache_key}.json"

# Check if cache file exists
if [[ ! -f "$cache_file" ]]; then
  echo "No lyrics available"
  exit 0
fi

# Read lyrics
raw_lyrics=$(jq -r '.syncedLyrics // ""' <"$cache_file" 2>/dev/null)
if [[ -z "$raw_lyrics" ]]; then
  echo "No synced lyrics"
  exit 0
fi

# Get current position
position_sec=$(playerctl position 2>/dev/null)
if [[ -z "$position_sec" ]]; then
  position_sec=0
fi

# Find current line index
declare -a lyrics_lines
declare -a lyrics_times
line_idx=0
while IFS= read -r line; do
  if [[ "$line" =~ \[([0-9]+):([0-9]+\.[0-9]+)\] ]]; then
    min="${BASH_REMATCH[1]}"
    sec="${BASH_REMATCH[2]}"
    time_float=$(awk "BEGIN {print $min*60 + $sec}")
    text_only=$(sed -E 's/\[[0-9:.]+\]//g' <<<"$line")
    # Remove emoji symbols
    text_only=$(echo "$text_only" | perl -CS -pe 's/[\x{1F600}-\x{1F64F}\x{1F300}-\x{1F5FF}\x{1F680}-\x{1F6FF}\x{1F1E0}-\x{1F1FF}\x{2600}-\x{26FF}\x{2700}-\x{27BF}\x{1F900}-\x{1F9FF}\x{1FA70}-\x{1FAFF}\x{FE00}-\x{FE0F}\x{1F018}-\x{1F270}\x{238C}-\x{2454}\x{20D0}-\x{20FF}]//g' 2>/dev/null || echo "$text_only")
    lyrics_lines[$line_idx]="$text_only"
    lyrics_times[$line_idx]="$time_float"
    ((line_idx++))
  fi
done <<<"$raw_lyrics"

# Find current line
current_idx=-1
for ((i = 0; i < ${#lyrics_lines[@]}; i++)); do
  if (($(awk "BEGIN {print ($position_sec >= ${lyrics_times[$i]})}"))); then
    current_idx=$i
  fi
done

if ((current_idx == -1)); then
  echo "Waiting for lyrics..."
  exit 0
fi

# Calculate range (5 lines before and after)
start_idx=$((current_idx - 5))
end_idx=$((current_idx + 5))

if ((start_idx < 0)); then
  start_idx=0
fi
if ((end_idx >= ${#lyrics_lines[@]})); then
  end_idx=$((${#lyrics_lines[@]} - 1))
fi

# Build output
output=""
for ((i = start_idx; i <= end_idx; i++)); do
  line_text="${lyrics_lines[$i]}"
  
  # Skip empty lines
  if [[ -z "${line_text//[[:space:]]/}" ]]; then
    continue
  fi
  
  if ((i == current_idx)); then
    # Highlight current line with Unicode box characters
    output+="▶ ${line_text} ◀\n"
  else
    output+="  ${line_text}\n"
  fi
done

# Output with proper escaping for waybar tooltip
echo -e "$output" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
