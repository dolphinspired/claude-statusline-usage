#!/usr/bin/env bash

input=$(cat)

# Parse JSON fields
model=$(echo "$input" | jq -r '.model.display_name // .model.id // "Claude"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
cwd=${cwd:-$PWD}

folder=$(basename "$cwd")

context_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')

ctx_size=${ctx_size:-0}
total_input=${total_input:-0}
total_output=${total_output:-0}

# Git branch
branch=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# ANSI color codes
RESET=$'\033[0m'
BLUE=$'\033[34m'
WHITE=$'\033[97m'
CYAN=$'\033[36m'
RED=$'\033[31m'
GREEN=$'\033[32m'
GRAY=$'\033[90m'
BOLD=$'\033[1m'
DIM=$'\033[2m'

# --- Line 1: model / folder / branch ---
line1="${BLUE}[${WHITE}${model}${BLUE}]${RESET} 📁 ${CYAN}${folder}${RESET}"
if [ -n "$branch" ]; then
  line1+=" ${RED}(${branch})${RESET}"
fi

# build_bar <pct> <fill_color>: outputs a colored 10-block progress bar
build_bar() {
  local pct=$1
  local fill_color=$2
  local width=10
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  local bar=""
  local i
  [ $filled -gt 0 ] && bar+="${fill_color}" && for i in $(seq 1 $filled); do bar+="█"; done && bar+="${RESET}"
  [ $empty -gt 0 ]  && bar+="${GRAY}"        && for i in $(seq 1 $empty);  do bar+="░"; done && bar+="${RESET}"
  echo "$bar"
}

# --- Line 2: context window bars ---
if [ -n "$context_pct" ] && [ "${ctx_size:-0}" -gt 0 ] 2>/dev/null; then
  ctx_bar=$(build_bar "$context_pct" "$GREEN")
  usage_tokens=$(( total_input + total_output ))
  usage_pct=$(( usage_tokens * 100 / ctx_size ))
  [ $usage_pct -gt 100 ] && usage_pct=100
  usage_bar=$(build_bar "$usage_pct" "$CYAN")
  line2="${BOLD}${WHITE}Context${RESET} ${ctx_bar} ${WHITE}${context_pct}%${RESET}  ${GRAY}|${RESET}  ${BOLD}${WHITE}Usage${RESET} ${usage_bar} ${WHITE}${usage_pct}%${RESET}"
else
  empty_bar="${GRAY}░░░░░░░░░░${RESET}"
  line2="${BOLD}${WHITE}Context${RESET} ${empty_bar} ${GRAY}--%${RESET}  ${GRAY}|${RESET}  ${BOLD}${WHITE}Usage${RESET} ${empty_bar} ${GRAY}--%${RESET}"
fi

printf "%s\n%s\n" "$line1" "$line2"

# ============================================================
# Rate-limit usage bars
# ============================================================

CREDS_FILE="$HOME/.claude/.credentials.json"
CACHE_FILE="/tmp/claude-usage-cache.json"
CACHE_MAX_AGE=300

[ -f "$CREDS_FILE" ] || exit 0

access_token=$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDS_FILE" 2>/dev/null)
expires_at=$(jq -r '.claudeAiOauth.expiresAt // 0' "$CREDS_FILE" 2>/dev/null)

[ -z "$access_token" ] && exit 0

# expiresAt is in milliseconds
now_ms=$(( $(date +%s) * 1000 ))
if [ "$expires_at" -le "$now_ms" ] 2>/dev/null; then
  exit 0
fi

# Use cache if fresh enough
fetch_fresh=1
if [ -f "$CACHE_FILE" ]; then
  cache_mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
  cache_age=$(( $(date +%s) - cache_mtime ))
  [ "$cache_age" -lt "$CACHE_MAX_AGE" ] && fetch_fresh=0
fi

if [ "$fetch_fresh" -eq 1 ]; then
  api_response=$(curl -sf \
    -H "Authorization: Bearer $access_token" \
    -H "Content-Type: application/json" \
    --max-time 5 \
    "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
  if [ $? -eq 0 ] && [ -n "$api_response" ]; then
    echo "$api_response" > "$CACHE_FILE"
  else
    exit 0
  fi
fi

usage_json=$(cat "$CACHE_FILE" 2>/dev/null)
[ -z "$usage_json" ] && exit 0

# Extract rate-limit fields
five_hour_pct=$(echo "$usage_json" | jq -r '.five_hour.utilization // empty')
five_hour_reset=$(echo "$usage_json" | jq -r '.five_hour.resets_at // empty')
seven_day_pct=$(echo "$usage_json" | jq -r '.seven_day.utilization // empty')
seven_day_reset=$(echo "$usage_json" | jq -r '.seven_day.resets_at // empty')
seven_day_sonnet_pct=$(echo "$usage_json" | jq -r '.seven_day_sonnet.utilization // empty')
seven_day_sonnet_reset=$(echo "$usage_json" | jq -r '.seven_day_sonnet.resets_at // empty')
extra_enabled=$(echo "$usage_json" | jq -r '.extra_usage.is_enabled // empty')
extra_limit=$(echo "$usage_json" | jq -r '.extra_usage.monthly_limit // empty')
extra_used=$(echo "$usage_json" | jq -r '.extra_usage.used_credits // empty')
extra_pct=$(echo "$usage_json" | jq -r '.extra_usage.utilization // empty')

# format_reset <iso_timestamp>: returns "in Xh Ym" | "in Xd" | "now"
format_reset() {
  local ts="$1"
  [ -z "$ts" ] && return
  local reset_s
  reset_s=$(date -d "$ts" +%s 2>/dev/null)
  [ -z "$reset_s" ] && return
  local diff=$(( reset_s - $(date +%s) ))
  if [ "$diff" -le 0 ]; then
    echo "now"
  elif [ "$diff" -lt 86400 ]; then
    local h=$(( diff / 3600 ))
    local m=$(( (diff % 3600) / 60 ))
    if [ "$h" -gt 0 ] && [ "$m" -gt 0 ]; then
      echo "in ${h}h ${m}m"
    elif [ "$h" -gt 0 ]; then
      echo "in ${h}h"
    else
      echo "in ${m}m"
    fi
  else
    echo "in $(( diff / 86400 ))d"
  fi
}

# render_usage_segment <label> <pct_float> <reset_ts>: prints a segment string (no trailing newline)
render_usage_segment() {
  local label="$1"
  local pct_raw="$2"
  local reset_ts="$3"
  local pct=0
  if [ -n "$pct_raw" ]; then
    pct=$(printf "%.0f" "$pct_raw" 2>/dev/null)
    [ -z "$pct" ] && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100
    [ "$pct" -lt 0 ]   2>/dev/null && pct=0
  fi
  local bar
  bar=$(build_bar "$pct" "$GREEN")
  local reset_str
  reset_str=$(format_reset "$reset_ts")
  local out="${BOLD}${WHITE}${label}${RESET} ${bar} ${WHITE}${pct}%${RESET}"
  [ -n "$reset_str" ] && out+=" ${DIM}· ${reset_str}${RESET}"
  printf "%s" "$out"
}

# --- Usage line 1: Session and/or Week ---
has_session=0
has_week=0
[ -n "$five_hour_pct" ] && has_session=1
[ -n "$seven_day_pct" ] && has_week=1

if [ "$has_session" -eq 1 ] && [ "$has_week" -eq 1 ]; then
  seg1=$(render_usage_segment "Session" "$five_hour_pct" "$five_hour_reset")
  seg2=$(render_usage_segment "Week   " "$seven_day_pct" "$seven_day_reset")
  printf "%s  ${GRAY}|${RESET}  %s\n" "$seg1" "$seg2"
elif [ "$has_session" -eq 1 ]; then
  printf "%s\n" "$(render_usage_segment "Session" "$five_hour_pct" "$five_hour_reset")"
elif [ "$has_week" -eq 1 ]; then
  printf "%s\n" "$(render_usage_segment "Week   " "$seven_day_pct" "$seven_day_reset")"
fi

# --- Usage line 2: Sonnet week ---
if [ -n "$seven_day_sonnet_pct" ]; then
  printf "%s\n" "$(render_usage_segment "Sonnet " "$seven_day_sonnet_pct" "$seven_day_sonnet_reset")"
fi

# --- Usage line 3: Extra usage ---
if [ "$extra_enabled" = "true" ] && [ -n "$extra_pct" ] && [ -n "$extra_limit" ] && [ -n "$extra_used" ]; then
  pct=0
  pct=$(printf "%.0f" "$extra_pct" 2>/dev/null)
  [ -z "$pct" ] && pct=0
  [ "$pct" -gt 100 ] 2>/dev/null && pct=100
  [ "$pct" -lt 0 ]   2>/dev/null && pct=0
  bar=$(build_bar "$pct" "$GREEN")
  used_dollars=$(awk "BEGIN {printf \"%.2f\", $extra_used / 100}" 2>/dev/null || echo "?")
  limit_dollars=$(awk "BEGIN {printf \"%.2f\", $extra_limit / 100}" 2>/dev/null || echo "?")
  printf "%s %s ${WHITE}%d%%${RESET} ${DIM}· \$%s/\$%s${RESET}\n" \
    "${BOLD}${WHITE}Extra  ${RESET}" "$bar" "$pct" "$used_dollars" "$limit_dollars"
fi
