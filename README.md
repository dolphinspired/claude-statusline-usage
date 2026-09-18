# claude-statusline-usage

A Claude Code statusline script that displays context window usage and subscription rate-limit burn inline in the terminal.

## Preview

![Statusline preview](img/statusline.png)

## What it does

`src/statusline.sh` renders two lines:

- **Line 1:** active model, current folder, git branch
- **Line 2:** context window fill bar · usage rate-limit bar · weekly rate-limit bar

Context is always shown. Usage and weekly bars appear when `ccburn` data is available.

## Requirements

- `bash`, `jq`, `git`, `awk` (standard on Linux/macOS)
- `ccburn` installed globally (see Setup)

## Setup

Install `ccburn` globally (once):

```bash
pipx install ccburn
# or: pip install --user ccburn
```

Then run:

```bash
make setup
```

This copies `src/statusline.sh` to `~/.claude/statusline.sh` and registers it in `~/.claude/settings.json` (and creates a `.venv/` for dev tooling).

For reference, the entry `make setup` writes to `~/.claude/settings.json` is:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline.sh"
  }
}
```

## Usage

### Statusline script

Test it manually:

```bash
make print
# or
echo '{"model":{"display_name":"claude-sonnet-4-6"},"context_window":{"used_percentage":42,"context_window_size":200000}}' | bash src/statusline.sh
```

Run the unit test suite:

```bash
make test
```

### ccburn

```bash
# Interactive TUI (live-updating burn-up charts)
ccburn session
ccburn weekly

# JSON output for scripting
ccburn --json --once
```

## Configuration

| Variable               | Default                      | Description                                  |
|------------------------|------------------------------|----------------------------------------------|
| `STATUSLINE_CACHE_DIR` | `~/.claude/cache`            | Directory for the ccburn response cache file |
| `STATUSLINE_CACHE_TTL` | `30` (seconds)               | How long to reuse a cached ccburn response   |
| `CCBURN_DATA`          | _(unset)_                    | Inject ccburn JSON directly; skips cache     |
| `GIT_BRANCH`           | _(unset)_                    | Override git branch detection                |

## Project structure

```
src/
  statusline.sh         Claude Code statusline script
tests/
  test_statusline.py    pytest suite
context/
  ccburn.md                     ccburn command and flag reference
  ccburn-sample-output.json     sample ccburn --json output
  usage-command-decompiled.md   reconstructed source of Claude Code's /usage tab
```
