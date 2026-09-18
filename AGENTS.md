# AGENTS.md

Instructions for an AI coding agent (Claude Code, etc.) setting up this
statusline for a user. Follow these steps top to bottom. Do not skip
verification.

## What you are installing

A two-line Claude Code statusline:

- **Line 1:** active model, current folder, git branch
- **Line 2:** context window usage · session rate-limit burn · weekly rate-limit burn

The session and weekly bars require `ccburn`; without it, only the context
line shows (this is expected, not an error).

## Prerequisites

Check these are on `PATH` before proceeding:

- `bash`, `jq`, `git`, `awk`, `date` — standard on Linux; on macOS ensure `jq`
  is installed (`brew install jq`).
- `ccburn` — installed globally, **not** in a virtualenv (see next step).

```bash
for c in bash jq git awk date; do command -v "$c" >/dev/null || echo "MISSING: $c"; done
```

If any are missing, install them with the system package manager before
continuing.

## Step 1 — Get the repo

If you are not already inside a clone of this repo, clone it to a **permanent**
location the user is comfortable keeping (not a temp directory), then `cd` in:

```bash
git clone https://github.com/dolphinspired/claude-statusline-usage.git
cd claude-statusline-usage
```

The setup copies the script out of the repo, so the clone does not need to
stay — but keep it if the user may want to update later (see Updating below).

## Step 2 — Install ccburn (global)

`ccburn` fetches the rate-limit data. Install it globally so `command -v
ccburn` resolves from any directory:

```bash
command -v ccburn >/dev/null || pipx install ccburn || pip install --user ccburn
```

If neither `pipx` nor `pip --user` is available, ask the user how they prefer
to install Python CLIs. The statusline still works without `ccburn` — it just
omits the session/weekly bars.

## Step 3 — Install the statusline

Run the setup script from the repo root. It copies the script into
`~/.claude/`, and registers (or offers to update) `statusLine` in
`~/.claude/settings.json`:

```bash
bash src/setup.sh "$PWD/src/statusline.sh" "$HOME/.claude/statusline.sh"
```

If a statusline is already configured with a different command, the script
prompts before changing it.

## Step 4 — Verify

1. Render the statusline directly. You should see a formatted line, not an
   error:

   ```bash
   echo '{}' | bash "$HOME/.claude/statusline.sh"
   ```

2. Confirm settings.json points at it:

   ```bash
   jq '.statusLine' "$HOME/.claude/settings.json"
   ```

   Expected shape:

   ```json
   {
     "type": "command",
     "command": "bash /home/<user>/.claude/statusline.sh"
   }
   ```

3. Tell the user to restart Claude Code (or open a new session) — the
   statusline appears at the bottom of the terminal.

## Updating

The script is a **copy**, so pull the repo and re-run Step 3 to get a newer
version:

```bash
git pull
bash src/setup.sh "$PWD/src/statusline.sh" "$HOME/.claude/statusline.sh"
```

## Configuration (optional)

These environment variables tune behavior; defaults are fine for most users.

| Variable               | Default           | Description                                  |
|------------------------|-------------------|----------------------------------------------|
| `STATUSLINE_CACHE_DIR` | `~/.claude/cache` | Directory for the ccburn response cache file |
| `STATUSLINE_CACHE_TTL` | `30` (seconds)    | How long to reuse a cached ccburn response   |
| `CCBURN_DATA`          | _(unset)_         | Inject ccburn JSON directly; skips cache     |
| `GIT_BRANCH`           | _(unset)_         | Override git branch detection                |

## Troubleshooting

- **No statusline at all** → settings.json not wired up. Re-run Step 3 and
  check `jq '.statusLine' ~/.claude/settings.json`.
- **Only the context line, no session/weekly bars** → `ccburn` not found on
  `PATH`, or it has no data yet. Confirm `command -v ccburn`.
- **`jq: command not found`** during setup → install `jq`, then re-run Step 3.
