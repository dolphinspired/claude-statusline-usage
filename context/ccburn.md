# ccburn

Source: https://juanjofuchs.github.io/ai-development/2026/01/13/introducing-ccburn-visual-token-tracking.html
Version installed: 0.4.3 (pip)

## What it does

Terminal TUI that visualizes Claude Code token consumption as burn-up charts — actual usage climbing against a linear "budget pace" line. Same format as sprint burn-up charts.

## Limit windows tracked

| Command         | Window                   |
|----------------|--------------------------|
| `session`       | 5-hour rolling window    |
| `weekly`        | 7-day all-models limit   |
| `weekly-sonnet` | 7-day Sonnet-only limit  |
| `monthly`       | Monthly credits (enterprise) |

## Burn-up chart logic

Each chart shows:
- Actual usage climbing over time
- A "budget pace" line (linear consumption across the full window)

Status indicators:
- 🧊 Behind pace — headroom remaining
- 🔥 On pace — tracking budget
- 🚨 Burning too hot — exceeding safe pace

## CLI flags

```
--compact / -c    Single-line output for status bars / tmux
--json / -j       Structured JSON output for scripting
--once / -1       Print once and exit (no live updates)
--since / -s      Time-window zoom, e.g. '2h', '24h', '7d'
--interval / -i   Refresh interval in seconds (default: 5)
--debug / -d      Show raw API response
```

## Compact mode output format

Single line showing all limits, e.g.:
```
Session: 🔥 45% (2h14m) | Weekly: 🧊 12% | Sonnet: 🧊 3%
```

## Data source

Reads Claude Code usage data via the `claude /usage` command (requires `claude` CLI with valid credentials).

## Stack

- Rich — terminal UI and formatting
- Plotext — chart rendering in terminal
- Typer — CLI framework
- httpx — HTTP client

## Usage in this repo

Installed in `.venv/`. Run via `.venv/bin/ccburn [command] [flags]`.
