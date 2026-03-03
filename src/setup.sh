#!/usr/bin/env bash

set -e

if [ $# -ne 2 ]; then
  echo "Usage: $0 <src> <dest>" >&2
  exit 1
fi

STATUSLINE_SRC="$1"
STATUSLINE_DEST="$2"
SETTINGS_FILE="$HOME/.claude/settings.json"

# Helper to prompt user - returns 0 (yes) if user says yes or just presses enter
# Handles both TTY (interactive) and non-TTY (piped) input
prompt_user() {
  local prompt_text="$1"
  local response

  if [ -t 0 ]; then
    # stdin is a TTY (interactive), use read -p for nice prompt
    read -p "$prompt_text" response
  else
    # stdin is piped/redirected, read silently from stdin
    read response
  fi

  # Return success (0) if response is empty or doesn't start with n/N
  # Return failure (1) if response starts with n/N
  [[ ! "$response" =~ ^[nN]$ ]]
}

# Prompt for backup if existing file is a regular file (not a symlink)
if [ -f "$STATUSLINE_DEST" ] && [ ! -L "$STATUSLINE_DEST" ]; then
  if prompt_user "Backup existing statusline script? [Y/n] "; then
    cp "$STATUSLINE_DEST" "$STATUSLINE_DEST.bak"
    echo "Backed up existing statusline script to $STATUSLINE_DEST.bak"
  fi
fi

# Create symlink
ln -sf "$STATUSLINE_SRC" "$STATUSLINE_DEST"
echo "Linked $STATUSLINE_DEST -> $STATUSLINE_SRC"

# Check and update settings.json if needed
if [ -f "$SETTINGS_FILE" ]; then
  expected_cmd="bash $STATUSLINE_DEST"
  current_cmd=$(jq -r '.statusLine.command // empty' "$SETTINGS_FILE" 2>/dev/null || echo "")

  if [ -n "$current_cmd" ] && [ "$current_cmd" != "$expected_cmd" ]; then
    echo ""
    echo "Current statusLine.command: $current_cmd"
    if prompt_user "Update settings.json to use: $expected_cmd? [Y/n] "; then
      jq ".statusLine.command = \"$expected_cmd\"" "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
      echo "Updated $SETTINGS_FILE"
    fi
  fi
fi
