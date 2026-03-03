"""
Unit tests for src/statusline-command.sh.

Run with: make test-unit
"""

import json
import os
import re
import subprocess
import tempfile

import pytest

SCRIPT = "./src/statusline-command.sh"

ANSI_ESCAPE = re.compile(r"\x1b\[[0-9;]*m")


def strip_ansi(text: str) -> str:
    return ANSI_ESCAPE.sub("", text)


def run_script(
    stdin_data: dict,
    ccburn_mock: dict | None = None,
    extra_env: dict | None = None,
) -> tuple[str, str]:
    env = {
        **os.environ,
        "TZ": "UTC",
        "STATUSLINE_CACHE_DIR": tempfile.mkdtemp(),
    }
    if ccburn_mock is not None:
        env["CCBURN_DATA"] = json.dumps(ccburn_mock)
    if extra_env:
        env.update(extra_env)

    result = subprocess.run(
        ["bash", str(SCRIPT)],
        input=json.dumps(stdin_data),
        capture_output=True,
        text=True,
        env=env,
    )
    lines = result.stdout.splitlines()
    while len(lines) < 2:
        lines.append("")
    return strip_ansi(lines[0]), strip_ansi(lines[1])


def make_ccburn(
    session_util: float = 0.45,
    week_util: float = 0.12,
    session_resets_at: str = "2026-03-03T14:00:00Z",
    week_resets_at: str = "2026-03-06T00:00:00Z",
) -> dict:
    return {
        "limits": {
            "session": {"utilization": session_util, "resets_at": session_resets_at},
            "weekly": {"utilization": week_util, "resets_at": week_resets_at},
        }
    }


@pytest.fixture()
def git_repo(tmp_path):
    git_env = {
        **os.environ,
        "GIT_AUTHOR_NAME": "Test",
        "GIT_AUTHOR_EMAIL": "t@t.com",
        "GIT_COMMITTER_NAME": "Test",
        "GIT_COMMITTER_EMAIL": "t@t.com",
    }
    subprocess.run(["git", "init", str(tmp_path)], check=True, capture_output=True)
    subprocess.run(
        ["git", "-C", str(tmp_path), "commit", "--allow-empty", "-m", "init"],
        check=True,
        capture_output=True,
        env=git_env,
    )
    return str(tmp_path)


# ---------------------------------------------------------------------------
# Line 1
# ---------------------------------------------------------------------------

class TestLine1:
    def test_model_display_name(self):
        line1, _ = run_script({"model": {"display_name": "claude-opus-4-6"}})
        assert "claude-opus-4-6" in line1

    def test_model_id_fallback(self):
        line1, _ = run_script({"model": {"id": "claude-sonnet-4-6"}})
        assert "claude-sonnet-4-6" in line1

    def test_model_default_fallback(self):
        line1, _ = run_script({})
        assert "Claude" in line1

    def test_model_in_brackets(self):
        line1, _ = run_script({"model": {"display_name": "TestModel"}})
        assert "[TestModel]" in line1

    def test_folder_shown(self, tmp_path):
        line1, _ = run_script({"workspace": {"current_dir": str(tmp_path)}})
        assert tmp_path.name in line1

    def test_folder_icon(self):
        line1, _ = run_script({})
        assert "📁" in line1

    def test_git_branch_shown(self, git_repo):
        line1, _ = run_script({"workspace": {"current_dir": git_repo}})
        assert re.search(r"\(main\)|\(master\)", line1), f"No branch in: {line1}"

    def test_no_branch_outside_git(self, tmp_path):
        line1, _ = run_script({"workspace": {"current_dir": str(tmp_path)}})
        assert "(" not in line1


# ---------------------------------------------------------------------------
# Line 2 — Context section
# ---------------------------------------------------------------------------

class TestContextSection:
    def test_context_label_always_present(self):
        _, line2 = run_script({})
        assert "Context" in line2

    def test_context_percentage_shown(self):
        stdin = {"context_window": {"used_percentage": 42, "context_window_size": 200000}}
        _, line2 = run_script(stdin)
        assert "42%" in line2

    def test_missing_context_shows_dash(self):
        _, line2 = run_script({})
        assert "--%"in line2

    def test_zero_ctx_size_treated_as_missing(self):
        stdin = {"context_window": {"used_percentage": 50, "context_window_size": 0}}
        _, line2 = run_script(stdin)
        assert "--%"in line2


# ---------------------------------------------------------------------------
# Line 2 — Session section
# ---------------------------------------------------------------------------

class TestSessionSection:
    def test_session_label_shown(self):
        _, line2 = run_script({}, ccburn_mock=make_ccburn())
        assert "Session" in line2

    def test_session_percentage(self):
        _, line2 = run_script({}, ccburn_mock=make_ccburn(session_util=0.45))
        assert "45%" in line2

    def test_session_reset_pm(self):
        _, line2 = run_script({}, ccburn_mock=make_ccburn(session_resets_at="2026-03-03T14:00:00Z"))
        assert "[2pm]" in line2

    def test_session_reset_am(self):
        _, line2 = run_script({}, ccburn_mock=make_ccburn(session_resets_at="2026-03-03T09:00:00Z"))
        assert "[9am]" in line2

    def test_session_reset_noon(self):
        _, line2 = run_script({}, ccburn_mock=make_ccburn(session_resets_at="2026-03-03T12:00:00Z"))
        assert "[12pm]" in line2

    def test_session_clamped_at_100(self):
        _, line2 = run_script({}, ccburn_mock=make_ccburn(session_util=1.5))
        assert "100%" in line2

    def test_session_clamped_at_0(self):
        _, line2 = run_script({}, ccburn_mock=make_ccburn(session_util=-0.1))
        assert "0%" in line2

    def test_session_absent_with_no_data(self):
        _, line2 = run_script({}, ccburn_mock={"limits": {}})
        assert "Session" not in line2

    def test_null_session_util_omits_section(self):
        mock = {
            "limits": {
                "session": {"utilization": None, "resets_at": "2026-03-03T14:00:00Z"},
                "weekly": {"utilization": 0.1, "resets_at": "2026-03-06T00:00:00Z"},
            }
        }
        _, line2 = run_script({}, ccburn_mock=mock)
        assert "Session" not in line2


# ---------------------------------------------------------------------------
# Line 2 — Week section
# ---------------------------------------------------------------------------

class TestWeekSection:
    def test_week_label_shown(self):
        _, line2 = run_script({}, ccburn_mock=make_ccburn())
        assert "Week" in line2

    def test_week_percentage(self):
        _, line2 = run_script({}, ccburn_mock=make_ccburn(week_util=0.12))
        assert "12%" in line2

    def test_week_reset_date(self):
        _, line2 = run_script({}, ccburn_mock=make_ccburn(week_resets_at="2026-03-06T00:00:00Z"))
        assert "[3/6]" in line2

    def test_week_reset_no_leading_zero(self):
        _, line2 = run_script({}, ccburn_mock=make_ccburn(week_resets_at="2026-03-01T00:00:00Z"))
        assert "[3/1]" in line2

    def test_week_clamped_at_100(self):
        _, line2 = run_script({}, ccburn_mock=make_ccburn(week_util=2.0))
        assert "100%" in line2

    def test_week_absent_with_no_data(self):
        _, line2 = run_script({}, ccburn_mock={"limits": {}})
        assert "Week" not in line2

    def test_null_week_util_omits_section(self):
        mock = {
            "limits": {
                "session": {"utilization": 0.5, "resets_at": "2026-03-03T14:00:00Z"},
                "weekly": {"utilization": None, "resets_at": "2026-03-06T00:00:00Z"},
            }
        }
        _, line2 = run_script({}, ccburn_mock=mock)
        assert "Week" not in line2
        assert "Session" in line2


# ---------------------------------------------------------------------------
# Separators
# ---------------------------------------------------------------------------

class TestSeparators:
    def test_separator_present_with_ccburn(self):
        _, line2 = run_script({}, ccburn_mock=make_ccburn())
        assert "•" in line2

    def test_no_separator_with_no_data(self):
        _, line2 = run_script({}, ccburn_mock={"limits": {}})
        assert "•" not in line2

    def test_two_separators_all_sections(self):
        stdin = {"context_window": {"used_percentage": 50, "context_window_size": 200000}}
        _, line2 = run_script(stdin, ccburn_mock=make_ccburn())
        assert line2.count("•") == 2
