#!/usr/bin/env bash
set -euo pipefail

readonly RESET=$'\033[0m'
readonly BLUE=$'\033[34m'
readonly WHITE=$'\033[97m'
readonly CYAN=$'\033[36m'
readonly RED=$'\033[31m'
readonly GREEN=$'\033[32m'
readonly GRAY=$'\033[90m'
readonly BOLD=$'\033[1m'
readonly MAGENTA=$'\033[95m'

# build_bar <pct> <fill_color>: outputs a colored 10-block progress bar
build_bar() {
  local -r pct=$1
  local -r fill_color=$2
  local -r width=10
  local -r filled=$(( pct * width / 100 ))
  local -r empty=$(( width - filled ))
  local bar=""
  local i
  if [[ $filled -gt 0 ]]; then
    bar+="${fill_color}"
    for ((i = 0; i < filled; i++)); do bar+="█"; done
    bar+="${RESET}"
  fi
  if [[ $empty -gt 0 ]]; then
    bar+="${GRAY}"
    for ((i = 0; i < empty; i++)); do bar+="░"; done
    bar+="${RESET}"
  fi
  printf '%s' "$bar"
}

# file_mtime <path>: epoch modification time, portable across GNU (stat -c)
# and BSD/macOS (stat -f). Prints 0 if the file is missing or unreadable.
file_mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || printf '0'
}

# ISO timestamps are parsed with jq rather than `date`, because `date -d` and
# the `%-m` no-pad flag are GNU-only and fail on BSD/macOS. jq's localtime
# yields the array [year, month(0-based), mday, hour, min, sec, wday, yday]
# in local time. The leading sub() calls strip fractional seconds and the
# timezone offset so fromdateiso8601 accepts the value.

# format_session_reset <iso>: local time, e.g. "2pm", "11am"
format_session_reset() {
  local -r ts="$1"
  if [[ -z "$ts" ]]; then return 0; fi
  printf '%s' "$ts" | jq -rR '
    ((sub("\\.[0-9]+";"") | sub("([+-][0-9]{2}:[0-9]{2})$|Z$";"")) + "Z")
    | (try fromdateiso8601 catch empty) | localtime
    | .[3] as $hour
    | ((if $hour % 12 == 0 then 12 else $hour % 12 end) | tostring)
      + (if $hour < 12 then "am" else "pm" end)
  ' 2>/dev/null
}

# format_week_reset <iso>: local date, e.g. "3/6", "12/31"
format_week_reset() {
  local -r ts="$1"
  if [[ -z "$ts" ]]; then return 0; fi
  printf '%s' "$ts" | jq -rR '
    ((sub("\\.[0-9]+";"") | sub("([+-][0-9]{2}:[0-9]{2})$|Z$";"")) + "Z")
    | (try fromdateiso8601 catch empty) | localtime
    | ((.[1] + 1) | tostring) + "/" + (.[2] | tostring)
  ' 2>/dev/null
}

_main() {
  local -r input="$(cat)"

  local -r model="$(printf '%s' "$input" | jq -r '.model.display_name // .model.id // "Claude"')"
  local cwd
  cwd="$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // ""')"
  cwd="${cwd:-$PWD}"

  local -r folder="$(basename "$cwd")"
  local -r context_pct="$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')"
  local -r ctx_size="$(printf '%s' "$input" | jq -r '.context_window.context_window_size // 0')"

  # Git branch — use GIT_BRANCH env var if set (even to empty); otherwise detect via git
  local branch=""
  if [[ -n "${GIT_BRANCH+x}" ]]; then
    branch="$GIT_BRANCH"
  elif git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    branch="$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null \
      || git -C "$cwd" rev-parse --short HEAD 2>/dev/null \
      || true)"
  fi

  # --- Line 1: model / folder / branch ---
  local line1="${BLUE}[${WHITE}${model}${BLUE}]${RESET} 📁 ${CYAN}${folder}${RESET}"
  if [[ -n "$branch" ]]; then
    line1+=" ${RED}(${branch})${RESET}"
  fi

  # --- Context section ---
  local ctx_section
  if [[ -n "$context_pct" ]] && [[ "$ctx_size" -gt 0 ]] 2>/dev/null; then
    local -r ctx_bar="$(build_bar "$context_pct" "$CYAN")"
    ctx_section="${BOLD}${WHITE}Context${RESET} ${ctx_bar} ${WHITE}${context_pct}%${RESET}"
  else
    ctx_section="${BOLD}${WHITE}Context${RESET} ${GRAY}░░░░░░░░░░${RESET} ${GRAY}--%${RESET}"
  fi

  # --- ccburn binary discovery ---
  local -r ccburn_cache="${STATUSLINE_CACHE_DIR:-$HOME/.claude/cache}/ccburn.json"
  local -r cache_max_age="${STATUSLINE_CACHE_TTL:-30}"
  local ccburn_bin=""
  ccburn_bin="$(command -v ccburn 2>/dev/null)" || true

  # --- Fetch/cache ccburn data ---
  local session_section=""
  local week_section=""
  local ccburn_data="${CCBURN_DATA:-}"

  if [[ -z "$ccburn_data" ]] && [[ -x "$ccburn_bin" ]]; then
    mkdir -p "$(dirname "$ccburn_cache")" 2>/dev/null || true
    local fetch_fresh=1
    if [[ -f "$ccburn_cache" ]]; then
      local cache_mtime
      cache_mtime="$(file_mtime "$ccburn_cache")"
      local -r cache_age=$(( $(date +%s) - cache_mtime ))
      if [[ "$cache_age" -lt "$cache_max_age" ]]; then
        fetch_fresh=0
      fi
    fi

    if [[ "$fetch_fresh" -eq 1 ]]; then
      local ccburn_json=""
      ccburn_json="$("$ccburn_bin" --json --once 2>/dev/null)" || true
      if [[ -n "$ccburn_json" ]] && printf '%s' "$ccburn_json" | jq -e . >/dev/null 2>&1; then
        printf '%s\n' "$ccburn_json" > "$ccburn_cache"
      fi
    fi
  fi

  if [[ -z "$ccburn_data" ]] && [[ -f "$ccburn_cache" ]]; then
    ccburn_data="$(cat "$ccburn_cache" 2>/dev/null)" || true
  fi

  if [[ -n "$ccburn_data" ]] && printf '%s' "$ccburn_data" | jq -e . >/dev/null 2>&1; then
    local -r session_util="$(printf '%s' "$ccburn_data" | jq -r '.limits.session.utilization // empty')"
    local -r session_reset_ts="$(printf '%s' "$ccburn_data" | jq -r '.limits.session.resets_at // empty')"
    local -r week_util="$(printf '%s' "$ccburn_data" | jq -r '.limits.weekly.utilization // empty')"
    local -r week_reset_ts="$(printf '%s' "$ccburn_data" | jq -r '.limits.weekly.resets_at // empty')"

    if [[ -n "$session_util" ]]; then
      local session_pct
      session_pct="$(awk "BEGIN {printf \"%.0f\", $session_util * 100}")" || session_pct=0
      if [[ "$session_pct" -gt 100 ]]; then session_pct=100; fi
      if [[ "$session_pct" -lt 0 ]]; then session_pct=0; fi
      local -r session_bar="$(build_bar "$session_pct" "$MAGENTA")"
      local -r session_reset="$(format_session_reset "$session_reset_ts")"
      session_section="${BOLD}${WHITE}Usage${RESET} ${session_bar} ${WHITE}${session_pct}%${RESET}"
      if [[ -n "$session_reset" ]]; then
        session_section+=" ${GRAY}[${session_reset}]${RESET}"
      fi
    fi

    if [[ -n "$week_util" ]]; then
      local week_pct
      week_pct="$(awk "BEGIN {printf \"%.0f\", $week_util * 100}")" || week_pct=0
      if [[ "$week_pct" -gt 100 ]]; then week_pct=100; fi
      if [[ "$week_pct" -lt 0 ]]; then week_pct=0; fi
      local -r week_bar="$(build_bar "$week_pct" "$GREEN")"
      local -r week_reset="$(format_week_reset "$week_reset_ts")"
      week_section="${BOLD}${WHITE}Week${RESET} ${week_bar} ${WHITE}${week_pct}%${RESET}"
      if [[ -n "$week_reset" ]]; then
        week_section+=" ${GRAY}[${week_reset}]${RESET}"
      fi
    fi
  fi

  # --- Assemble line 2: Context always present; Usage + Week appended if available ---
  local line2="$ctx_section"
  if [[ -n "$session_section" ]]; then
    line2+=" ${GRAY}•${RESET} ${session_section}"
  fi
  if [[ -n "$week_section" ]]; then
    line2+=" ${GRAY}•${RESET} ${week_section}"
  fi

  printf "%s\n%s\n" "$line1" "$line2"
}

_main "$@"
