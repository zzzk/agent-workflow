#!/usr/bin/env bash
# Claude Code status line script
# Displays: context window usage, 5-hour rate limit, 7-day rate limit

input=$(cat)

# ---------------------------------------------------------------------------
# Context window
# ---------------------------------------------------------------------------
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

if [ -n "$used_pct" ]; then
  # Build a 10-block bar
  filled=$(printf '%.0f' "$(echo "$used_pct / 10" | bc -l)")
  bar=""
  for i in $(seq 1 10); do
    if [ "$i" -le "$filled" ]; then
      bar="${bar}█"
    else
      bar="${bar}░"
    fi
  done

  # Pick colour: green → yellow → red
  int_pct=$(printf '%.0f' "$used_pct")
  if [ "$int_pct" -ge 90 ]; then
    color="\033[31m"   # red
  elif [ "$int_pct" -ge 70 ]; then
    color="\033[33m"   # yellow
  else
    color="\033[32m"   # green
  fi
  reset="\033[0m"

  ctx_part=$(printf "${color}ctx [${bar}] %d%%${reset}" "$int_pct")
else
  ctx_part="ctx [----------] --%"
fi

# ---------------------------------------------------------------------------
# Rate limits
# ---------------------------------------------------------------------------
format_reset() {
  local resets_at="$1"
  if [ -z "$resets_at" ]; then
    echo "?"
    return
  fi
  now=$(date +%s)
  diff=$(( resets_at - now ))
  if [ "$diff" -le 0 ]; then
    echo "soon"
  elif [ "$diff" -lt 3600 ]; then
    printf "%dm" $(( diff / 60 ))
  else
    printf "%dh%dm" $(( diff / 3600 )) $(( (diff % 3600) / 60 ))
  fi
}

# Weekday + Uhrzeit statt Countdown (z.B. "Tue 17:00") - portabel fuer
# GNU date (Linux/Sandbox, "-d @epoch") und BSD date (macOS, "-r epoch").
format_reset_datetime() {
  local resets_at="$1"
  if [ -z "$resets_at" ]; then
    echo "?"
    return
  fi
  date -d "@$resets_at" +"%a %H:%M" 2>/dev/null || date -r "$resets_at" +"%a %H:%M" 2>/dev/null
}

five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_resets=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

seven_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_resets=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

if [ -n "$five_pct" ]; then
  five_int=$(printf '%.0f' "$five_pct")
  five_reset_str=$(format_reset "$five_resets")
  five_part=$(printf "5h: %d%% (resets %s)" "$five_int" "$five_reset_str")
else
  five_part=""
fi

if [ -n "$seven_pct" ]; then
  seven_int=$(printf '%.0f' "$seven_pct")
  seven_reset_str=$(format_reset_datetime "$seven_resets")
  seven_part=$(printf "7d: %d%% (resets %s)" "$seven_int" "$seven_reset_str")
else
  seven_part=""
fi

# ---------------------------------------------------------------------------
# Assemble output
# ---------------------------------------------------------------------------
parts=()
parts+=("$ctx_part")
[ -n "$five_part" ]  && parts+=("$five_part")
[ -n "$seven_part" ] && parts+=("$seven_part")

# Join with separator
output=""
for part in "${parts[@]}"; do
  if [ -z "$output" ]; then
    output="$part"
  else
    output="$output  |  $part"
  fi
done

printf '%s\n' "$output"
