# Plan: pytest Unit Tests for statusline-command.sh

## Context

`src/statusline-command.sh` has no automated tests. All testing is manual (`make test` pipes `{}` through the script and eyeballs ANSI output). The script has two data sources — stdin JSON (model, context) and ccburn JSON (session/week usage) — and two code paths for ccburn (binary + cache, or cache-only). A minimal script modification plus a pytest suite will enable reliable, repeatable validation of all rendering logic.

## Files to Modify

- `src/statusline-command.sh` — add `STATUSLINE_CCBURN_MOCK` env var support
- `Makefile` — add `PYTEST` var, `install-dev`, `test-unit` targets; extend `.PHONY`

## Files to Create

- `requirements-dev.txt` — `pytest>=8.0`
- `tests/test_statusline.py` — full pytest suite

---

## 1. Script change — `src/statusline-command.sh`

Replace the ccburn fetch block (lines 91–139) with a refactored version that:

1. Declares `ccburn_data=""` before the branching logic
2. Checks `STATUSLINE_CCBURN_MOCK` first; if set, assigns it to `ccburn_data` and skips binary/cache entirely
3. Falls through to existing binary+cache logic (`elif [ -x "$ccburn_bin" ]`) — behavior identical to today when mock is unset
4. Moves all parsing (session_util, week_util, bar building) into a standalone `if [ -n "$ccburn_data" ]` block after the fetch block (no longer nested inside the binary guard)

Key: the mock env var short-circuits binary discovery entirely, enabling tests to inject synthetic ccburn JSON without a real ccburn installation.

## 2. `requirements-dev.txt`

```
pytest>=8.0
```

## 3. `tests/test_statusline.py`

Design decisions:
- `run_script()` helper: runs script as subprocess, passes stdin JSON + optional `STATUSLINE_CCBURN_MOCK`, forces `TZ=UTC` for deterministic `date -d` output, sets `STATUSLINE_CACHE_DIR` to a tmp dir, returns `(line1, line2)` with ANSI stripped
- `strip_ansi()`: regex strips `\x1b\[[0-9;]*m` sequences before assertions
- `make_ccburn()`: factory for mock ccburn payloads with sensible defaults
- `git_repo` fixture: creates a real minimal git repo in `tmp_path` for branch tests
- Tests grouped: Line1, Context, Session, Week, NoCcburn, Separators

## 4. `Makefile` changes

```makefile
PYTEST := $(VENV)/bin/pytest

.PHONY: setup install install-dev test test-unit clean

install-dev: install
	$(PIP) install -r requirements-dev.txt

test-unit: install-dev
	$(PYTEST) tests/ -v
```

## Verification

```bash
make test-unit   # all tests green
make test        # smoke test still works
```

## Status

- [x] Plan saved
- [x] `src/statusline-command.sh` modified (STATUSLINE_CCBURN_MOCK support)
- [x] `requirements-dev.txt` created
- [x] `tests/test_statusline.py` created
- [x] `Makefile` updated
- [x] `make test-unit` — all tests passing
