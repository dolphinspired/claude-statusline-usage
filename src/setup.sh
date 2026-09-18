#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

log()       { printf '[%s] %s\n' "$SCRIPT_NAME" "$*" >&2; }
die()       { log "ERROR: $*"; exit 1; }
prompt_Yn() { local r; read -r -p "[$SCRIPT_NAME] $* [Y/n] " r; [[ -z "$r" || "$r" =~ ^[Yy]$ ]]; }

# Write the statusline command into settings.json, preserving any other
# statusLine fields the user may already have set.
_set_statusline() {
  local -r file="$1"
  local -r cmd="$2"
  local -r tmp="$file.tmp"
  jq --arg cmd "$cmd" \
    '.statusLine = ((.statusLine // {}) + {type: "command", command: $cmd})' \
    "$file" > "$tmp" && mv "$tmp" "$file"
}

_main() {
  if [[ $# -ne 2 ]]; then
    die "Usage: $SCRIPT_NAME <src> <dest>"
  fi

  command -v jq >/dev/null 2>&1 || die "jq is required but not installed"

  local -r src="$1"
  local -r dest="$2"
  local -r settings_file="$HOME/.claude/settings.json"

  [[ -f "$src" ]] || die "source script not found: $src"

  mkdir -p "$(dirname "$dest")"

  # Remove an existing symlink so we never write through it onto its target.
  if [[ -L "$dest" ]]; then
    rm -f "$dest"
  # Back up a real existing file before overwriting it.
  elif [[ -f "$dest" ]]; then
    if prompt_Yn "Backup existing statusline script?"; then
      cp "$dest" "$dest.bak"
      log "Backed up existing statusline script to $dest.bak"
    fi
  fi

  # Copy the script into place so this repo can be moved or deleted afterward.
  cp "$src" "$dest"
  log "Installed statusline script to $dest"

  # Register (or offer to update) the statusline in settings.json.
  local -r expected_cmd="bash $dest"
  mkdir -p "$(dirname "$settings_file")"
  if [[ ! -f "$settings_file" ]]; then
    printf '{}\n' > "$settings_file"
    log "Created $settings_file"
  fi

  local current_cmd=""
  current_cmd="$(jq -r '.statusLine.command // empty' "$settings_file")" || true

  if [[ -z "$current_cmd" ]]; then
    _set_statusline "$settings_file" "$expected_cmd"
    log "Registered statusline in $settings_file"
  elif [[ "$current_cmd" != "$expected_cmd" ]]; then
    printf '\n' >&2
    log "Current statusLine.command: $current_cmd"
    if prompt_Yn "Update settings.json to use: $expected_cmd?"; then
      _set_statusline "$settings_file" "$expected_cmd"
      log "Updated $settings_file"
    fi
  else
    log "settings.json already points at this statusline"
  fi

  log "Done. Restart Claude Code (or start a new session) to see the statusline."
}

_main "$@"
