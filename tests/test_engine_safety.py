"""Regression gates: safe state reads and failure-scoped rollback."""
from pathlib import Path
import os
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "src" / "Win11Janitor.ps1"
STATE = ROOT / "src" / "State.ps1"

class EngineSafety(unittest.TestCase):
    def test_registry_access_failure_is_not_silenced(self):
        env = dict(os.environ, TEMP=str(ROOT / ".workspace" / "tmp"),
                   TMP=str(ROOT / ".workspace" / "tmp"))
        code = (
            ". '" + str(STATE).replace("'", "''") + "'; "
            "$op=[pscustomobject]@{Kind='Registry';Path='MISSINGDRIVE:\\Nope';Name='X'}; "
            "try { $null=Read-Target $op '99'; exit 0 } catch { exit 21 }"
        )
        result = subprocess.run(["pwsh", "-NoProfile", "-NonInteractive",
                                 "-Command", code], cwd=ROOT, env=env,
                                capture_output=True, text=True,
                                encoding="utf-8", errors="replace", timeout=15)
        self.assertEqual(result.returncode, 21, result.stderr)

    def test_existing_stricter_diagnostic_policy_is_preserved(self):
        env = dict(os.environ, TEMP=str(ROOT / ".workspace" / "tmp"),
                   TMP=str(ROOT / ".workspace" / "tmp"))
        modules = ROOT / "src" / "Modules.ps1"
        code = (
            ". '" + str(modules) + "'; . '" + str(STATE) + "'; "
            "$op=$script:Catalog['01'].operations[0]; "
            "$s=[pscustomobject]@{present=$true;previousKind='DWord';previousValue=0}; "
            "if(Test-Target $op $s){exit 0}else{exit 22}"
        )
        p = subprocess.run(["pwsh", "-NoProfile", "-NonInteractive",
                            "-Command", code], cwd=ROOT, env=env,
                           capture_output=True, text=True, encoding="utf-8",
                           errors="replace", timeout=15)
        self.assertEqual(p.returncode, 0, p.stderr)

    def test_rollback_excludes_untouched_snapshot_entries(self):
        source = ENGINE.read_text(encoding="utf-8")
        self.assertIn("$touched = @()", source)
        self.assertIn("$touched += $orig", source)
        self.assertIn("$reverse = @($touched)", source)
        self.assertLess(source.index("$touched += $orig"),
                        source.index("$outcome = Set-Target"))

if __name__ == "__main__":
    unittest.main()
