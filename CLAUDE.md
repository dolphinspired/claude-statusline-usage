# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Tooling repo for a Claude Code statusline that displays subscription usage metrics inline in the terminal. Shows context window usage, session rate-limit burn, and weekly rate-limit burn.

## Environment

Python venv at `.venv/` for dev tooling (pytest, Pillow). Activate with `source .venv/bin/activate` or prefix commands with `.venv/bin/`.

`ccburn` is expected to be installed globally (e.g. `pipx install ccburn`), not in the venv.

```bash
# Install dev dependencies
pip install -r requirements.txt

# Run ccburn (primary tool for usage data)
ccburn --json --once   # structured output for scripting
```

Test the statusline script manually:

```bash
echo '{}' | bash src/statusline.sh
```

## Architecture

### Data sources

Two separate data streams feed the statusline:

1. **Statusline JSON** (stdin to `src/statusline.sh`) — provided by Claude Code at render time. Contains model name, cwd, and context window stats (`used_percentage`, `context_window_size`).

2. **ccburn** — `ccburn --json --once` fetches rate-limit utilization (session, weekly) from the Claude API. The script caches the output to avoid calling on every render. See `context/ccburn.md` for full reference.

### ccburn JSON shape

```json
{
  "limits": {
    "session": { "utilization": 0.42, "resets_at": "<ISO timestamp>" },
    "weekly":  { "utilization": 0.17, "resets_at": "<ISO timestamp>" }
  }
}
```

`utilization` is a 0–1 float. `resets_at` is an ISO timestamp.

### Caching

ccburn output is cached to `$STATUSLINE_CACHE_DIR/ccburn.json` (default: `~/.claude/cache/ccburn.json`) with a TTL controlled by `STATUSLINE_CACHE_TTL` (default: 30 seconds).

Set `CCBURN_DATA` in the environment to inject raw ccburn JSON directly — binary discovery and cache are skipped entirely. Used by tests and for manual overrides.

### ccburn binary discovery

`command -v ccburn` (PATH only — no venv fallback)

### Statusline output

Two lines:

- **Line 1:** `[Model] 📁 folder (branch)`
- **Line 2:** `Context [cyan_bar] N%` · `Session [magenta_bar] N% [reset_time]` · `Week [green_bar] N% [reset_date]`

Session and Week sections only appear when ccburn data is available.

## Regenerating the README screenshot

```bash
.venv/bin/python3 src/render_screenshot.py   # run from repo root
```

Update the sample model name or utilization values inside the script as needed.

## Context files

- `context/ccburn.md` — ccburn tool reference (commands, flags, JSON output format).
- `context/usage-command-decompiled.md` — reconstructed TypeScript source of Claude Code's internal `/usage` tab; reference for the underlying API shape.
- `context/ccburn-sample-output.json` — sample `ccburn --json` output.
