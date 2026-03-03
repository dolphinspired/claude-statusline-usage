#!/usr/bin/env bash

input=$(cat)

# Parse JSON fields
model=$(echo "$input" | jq -r '.model.display_name // .model.id // "Claude"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
cwd=${cwd:-$PWD}

folder=$(basename "$cwd")

context_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')

ctx_size=${ctx_size:-0}

# Git branch — use GIT_BRANCH env var if set (even to empty); otherwise detect via git
branch=""
if [ -n "${GIT_BRANCH+x}" ]; then
  branch="$GIT_BRANCH"
elif git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
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
MAGENTA=$'\033[95m'

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

# --- Context section ---
if [ -n "$context_pct" ] && [ "${ctx_size:-0}" -gt 0 ] 2>/dev/null; then
  ctx_bar=$(build_bar "$context_pct" "$CYAN")
  ctx_section="${BOLD}${WHITE}Context${RESET} ${ctx_bar} ${WHITE}${context_pct}%${RESET}"
else
  empty_bar="${GRAY}░░░░░░░░░░${RESET}"
  ctx_section="${BOLD}${WHITE}Context${RESET} ${empty_bar} ${GRAY}--%${RESET}"
fi

# --- ccburn binary discovery ---
# Script may be symlinked to ~/.claude/; resolve real path to find repo's .venv
CCBURN_CACHE="${STATUSLINE_CACHE_DIR:-$HOME/.claude/cache}/ccburn.json"
CACHE_MAX_AGE="${STATUSLINE_CACHE_TTL:-30}"

ccburn_bin=$(command -v ccburn 2>/dev/null)
if [ -z "$ccburn_bin" ]; then
  script_real=$(readlink -f "$0" 2>/dev/null || echo "$0")
  repo_dir=$(dirname "$(dirname "$script_real")")
  ccburn_bin="$repo_dir/.venv/bin/ccburn"
fi

# --- Reset-time formatters ---
# format_session_reset <iso>: e.g. "2pm", "11am"
format_session_reset() {
  local ts="$1"
  [ -z "$ts" ] && return
  date -d "$ts" +"%l%p" 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -d ' '
}

# format_week_reset <iso>: e.g. "3/6", "12/31"
format_week_reset() {
  local ts="$1"
  [ -z "$ts" ] && return
  date -d "$ts" +"%-m/%-d" 2>/dev/null
}

# --- Fetch/cache ccburn data ---
session_section=""
week_section=""
ccburn_data="${CCBURN_DATA:-}"

if [ -z "$ccburn_data" ] && [ -x "$ccburn_bin" ]; then
  mkdir -p "$(dirname "$CCBURN_CACHE")" 2>/dev/null
  fetch_fresh=1
  if [ -f "$CCBURN_CACHE" ]; then
    cache_mtime=$(stat -c %Y "$CCBURN_CACHE" 2>/dev/null || echo 0)
    cache_age=$(( $(date +%s) - cache_mtime ))
    [ "$cache_age" -lt "$CACHE_MAX_AGE" ] && fetch_fresh=0
  fi

  if [ "$fetch_fresh" -eq 1 ]; then
    ccburn_json=$("$ccburn_bin" --json --once 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$ccburn_json" ]; then
      echo "$ccburn_json" > "$CCBURN_CACHE"
    fi
  fi

  if [ -f "$CCBURN_CACHE" ]; then
    ccburn_data=$(cat "$CCBURN_CACHE" 2>/dev/null)
  fi
fi

if [ -n "$ccburn_data" ]; then
  session_util=$(echo "$ccburn_data" | jq -r '.limits.session.utilization // empty')
  session_reset_ts=$(echo "$ccburn_data" | jq -r '.limits.session.resets_at // empty')
  week_util=$(echo "$ccburn_data" | jq -r '.limits.weekly.utilization // empty')
  week_reset_ts=$(echo "$ccburn_data" | jq -r '.limits.weekly.resets_at // empty')

  if [ -n "$session_util" ]; then
    session_pct=$(awk "BEGIN {printf \"%.0f\", $session_util * 100}" 2>/dev/null || echo 0)
    [ "$session_pct" -gt 100 ] 2>/dev/null && session_pct=100
    [ "$session_pct" -lt 0 ]   2>/dev/null && session_pct=0
    session_bar=$(build_bar "$session_pct" "$MAGENTA")
    session_reset=$(format_session_reset "$session_reset_ts")
    session_section="${BOLD}${WHITE}Session${RESET} ${session_bar} ${WHITE}${session_pct}%${RESET}"
    [ -n "$session_reset" ] && session_section+=" ${GRAY}[${session_reset}]${RESET}"
  fi

  if [ -n "$week_util" ]; then
    week_pct=$(awk "BEGIN {printf \"%.0f\", $week_util * 100}" 2>/dev/null || echo 0)
    [ "$week_pct" -gt 100 ] 2>/dev/null && week_pct=100
    [ "$week_pct" -lt 0 ]   2>/dev/null && week_pct=0
    week_bar=$(build_bar "$week_pct" "$GREEN")
    week_reset=$(format_week_reset "$week_reset_ts")
    week_section="${BOLD}${WHITE}Week${RESET} ${week_bar} ${WHITE}${week_pct}%${RESET}"
    [ -n "$week_reset" ] && week_section+=" ${GRAY}[${week_reset}]${RESET}"
  fi
fi

# --- Assemble line 2: Context always present; Session + Week appended if available ---
line2="$ctx_section"
if [ -n "$session_section" ]; then
  line2+=" ${GRAY}•${RESET} ${session_section}"
fi
if [ -n "$week_section" ]; then
  line2+=" ${GRAY}•${RESET} ${week_section}"
fi

printf "%s\n%s\n" "$line1" "$line2"
