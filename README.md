# claude-statusline-usage

Research and tooling for displaying Claude Code subscription usage metrics in a terminal statusline.

## What it does

- `src/statusline-command.sh` — a Claude Code statusline script that renders two or three lines:
  - **Line 1:** active model, current folder, git branch
  - **Line 2:** context window bars (filled vs. used tokens)
  - **Lines 3–5:** rate-limit bars for Session (5h), Week (7d), Sonnet week, and Extra usage — pulled live from the Claude API and cached for 5 minutes
- `ccburn` — a TUI tool (installed via pip) that renders the same rate-limit data as burn-up charts; useful for at-a-glance usage monitoring

## Requirements

- Python 3.10+
- `bash`, `jq`, `curl`, `git`, `awk` (standard on Linux/macOS)
- A Claude Code subscription (usage API requires OAuth credentials at `~/.claude/.credentials.json`)

## Setup

```bash
make setup
```

This creates `.venv/` and installs `ccburn`.

## Usage

### Statusline script

Register `src/statusline-command.sh` as your Claude Code statusline command in `~/.claude/settings.json`:

```json
{
  "statusCommand": "/path/to/claude-statusline-usage/src/statusline-command.sh"
}
```

Test it manually:

```bash
make test
# or
echo '{"model":{"display_name":"claude-sonnet-4-6"},"context_window":{"used_percentage":42,"context_window_size":200000,"total_input_tokens":70000,"total_output_tokens":14000}}' | bash src/statusline-command.sh
```

### ccburn

```bash
# Interactive TUI (live-updating burn-up charts)
.venv/bin/ccburn session
.venv/bin/ccburn weekly
.venv/bin/ccburn weekly-sonnet

# Single-line compact output (for scripts / status bars)
.venv/bin/ccburn --compact --once

# JSON output for scripting
.venv/bin/ccburn --json --once
```

## Configuration

The statusline script has two hardcoded tunables near the top of the rate-limit section:

| Variable        | Default                              | Description                        |
|----------------|--------------------------------------|------------------------------------|
| `CREDS_FILE`   | `~/.claude/.credentials.json`        | OAuth credentials from Claude Code |
| `CACHE_FILE`   | `/tmp/claude-usage-cache.json`       | Usage API response cache path      |
| `CACHE_MAX_AGE`| `300` (seconds)                      | How long to reuse a cached response|

## Project structure

```
src/
  statusline-command.sh   Claude Code statusline script
context/
  usage-command-decompiled.md   Reconstructed source of Claude Code's /usage tab
  ccburn.md                     ccburn command and flag reference
```
