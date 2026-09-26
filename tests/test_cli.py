"""Non-mutating contract tests for the Windows 11 Janitor CLI."""
import json
import os
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "src" / "Win11Janitor.ps1"
WORKSPACE = ROOT / ".workspace"
TEMP = WORKSPACE / "tmp"


def invoke(*args):
    TEMP.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, TEMP=str(TEMP), TMP=str(TEMP),
               TMPDIR=str(TEMP), HOME=str(WORKSPACE))
    result = subprocess.run(
        ["pwsh", "-NoProfile", "-NonInteractive", "-File", str(ENGINE),
         *args, "-Json"], cwd=ROOT, env=env, text=True,
        capture_output=True, timeout=25, encoding="utf-8", errors="replace")
    try:
        payload = json.loads(result.stdout)
    except ValueError:
        payload = None
    return result, payload


class ReadOnlyContract(unittest.TestCase):
    def test_safe_plan_is_bounded(self):
        result, payload = invoke("-Action", "Plan", "-Profile", "Safe")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(payload["action"], "Plan")
        self.assertEqual({x["id"] for x in payload["results"]},
                         {"01", "02", "03", "04", "17"})

    def test_audit_reports_unsupported_modules(self):
        result, payload = invoke("-Action", "Audit", "-Module", "05")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(payload["results"][0]["status"], "AUDIT_ONLY")

    def test_dry_run_is_non_mutating(self):
        backups = WORKSPACE / "backups"
        before = set(backups.glob("*.json")) if backups.exists() else set()
        result, payload = invoke("-Action", "Apply", "-Profile", "Safe",
                                 "-WhatIf")
        after = set(backups.glob("*.json")) if backups.exists() else set()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(before, after)
        self.assertTrue(all(x["status"] == "WOULD_APPLY"
                            for x in payload["results"]))

    def test_apply_rejects_audit_only_module(self):
        result, payload = invoke("-Action", "Apply", "-Module", "05",
                                 "-WhatIf")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(payload["results"][0]["status"], "AUDIT_ONLY")

    def test_restore_rejects_outside_snapshot(self):
        result, payload = invoke("-Action", "Restore", "-Snapshot",
                                 str(ROOT / "README.md"), "-WhatIf")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("ERROR", payload["status"])


if __name__ == "__main__":
    unittest.main()
