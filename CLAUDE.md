# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

Research and tooling repo for building a Claude Code statusline that displays subscription usage metrics. The goal is to show rate-limit consumption (session, weekly, Sonnet) inline in a terminal statusline, sourced from the Claude API.

## Environment

Python venv at `.venv/`. Activate with `source .venv/bin/activate` or prefix commands with `.venv/bin/`.

```bash
# Install dependencies
pip install -r requirements.txt

# Run ccburn (primary tool for usage data)
.venv/bin/ccburn session --compact --once
.venv/bin/ccburn --json --once   # structured output for scripting
```

The shell statusline script reads from stdin (Claude Code's statusline JSON) and also hits the usage API directly:

```bash
# Test the statusline script manually
echo '{}' | bash src/statusline-command.sh
```

## Architecture

### Data sources

Two separate data streams feed the statusline:

1. **Statusline JSON** (stdin to `src/statusline-command.sh`) — provided by Claude Code at render time. Contains model name, cwd, context window stats (`used_percentage`, `context_window_size`, `total_input_tokens`, `total_output_tokens`).

2. **Usage API** — `GET https://api.anthropic.com/api/oauth/usage` with the OAuth token from `~/.claude/.credentials.json`. Returns rate-limit utilization for `five_hour`, `seven_day`, `seven_day_sonnet`, and `extra_usage`. Cached to `/tmp/claude-usage-cache.json` with a 5-minute TTL to avoid hammering the API on every render.

### API response shape

```ts
interface UsageResponse {
  five_hour?:        { utilization: number | null; resets_at: string };  // 5-hr rolling session
  seven_day?:        { utilization: number | null; resets_at: string };  // weekly all-models
  seven_day_sonnet?: { utilization: number | null; resets_at: string };  // weekly Sonnet-only
  extra_usage?: {
    is_enabled:    boolean;
    monthly_limit: number | null;  // cents, null = unlimited
    used_credits?: number;         // cents
    utilization?:  number;         // 0–100
  };
}
```

`utilization` is 0–100 (percent). `resets_at` is an ISO timestamp.

### ccburn

`ccburn` is a pip-installable TUI that visualizes the same API data as burn-up charts. Useful for reference and for `--compact`/`--json` output in scripts. See `context/ccburn.md` for full flag reference.

## Context files

- `context/usage-command-decompiled.md` — reconstructed TypeScript source of Claude Code's internal `/usage` tab, showing exactly how the app fetches and renders usage data. Authoritative reference for the API shape.
- `context/ccburn.md` — ccburn tool reference (commands, flags, compact output format).
