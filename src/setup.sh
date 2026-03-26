#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

log()       { printf '[%s] %s\n' "$SCRIPT_NAME" "$*" >&2; }
die()       { log "ERROR: $*"; exit 1; }
prompt_Yn() { local r; read -r -p "[$SCRIPT_NAME] $* [Y/n] " r; [[ -z "$r" || "$r" =~ ^[Yy]$ ]]; }

_main() {
  if [[ $# -ne 2 ]]; then
    die "Usage: $SCRIPT_NAME <src> <dest>"
  fi

  local -r src="$1"
  local -r dest="$2"
  local -r settings_file="$HOME/.claude/settings.json"

  # Prompt for backup if existing file is a regular file (not a symlink)
  if [[ -f "$dest" ]] && [[ ! -L "$dest" ]]; then
    if prompt_Yn "Backup existing statusline script?"; then
      cp "$dest" "$dest.bak"
      log "Backed up existing statusline script to $dest.bak"
    fi
  fi

  # Create symlink
  ln -sf "$src" "$dest"
  log "Linked $dest -> $src"

  # Check and update settings.json if needed
  if [[ -f "$settings_file" ]]; then
    local -r expected_cmd="bash $dest"
    local current_cmd=""
    current_cmd="$(jq -r '.statusLine.command // empty' "$settings_file")" || true

    if [[ -n "$current_cmd" ]] && [[ "$current_cmd" != "$expected_cmd" ]]; then
      printf '\n' >&2
      log "Current statusLine.command: $current_cmd"
      if prompt_Yn "Update settings.json to use: $expected_cmd?"; then
        jq --arg cmd "$expected_cmd" '.statusLine.command = $cmd' "$settings_file" \
          > "$settings_file.tmp" && mv "$settings_file.tmp" "$settings_file"
        log "Updated $settings_file"
      fi
    fi
  fi
}

_main "$@"
