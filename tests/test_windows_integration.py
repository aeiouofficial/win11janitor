"""Non-mutating integration checks of Windows batch wrappers and snapshot guards."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import unittest
from uuid import uuid4

ROOT = Path(__file__).resolve().parents[1]
TMP = ROOT / ".workspace" / "tmp"
BACKUPS = ROOT / ".workspace" / "backups"
ENGINE = ROOT / "src" / "Win11Janitor.ps1"


def run(args):
    TMP.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, TEMP=str(TMP), TMP=str(TMP), TMPDIR=str(TMP),
               HOME=str(ROOT / ".workspace"))
    return subprocess.run(args, cwd=ROOT, env=env, capture_output=True,
                          text=True, encoding="utf-8", errors="replace",
                          timeout=35)


class WindowsIntegration(unittest.TestCase):
    def test_safe_legacy_launcher_remains_read_only_in_whatif(self):
        cmd = shutil.which("cmd.exe")
        self.assertIsNotNone(cmd, "cmd.exe must exist on the Windows test host")
        bat = ROOT / "01_disable_telemetry.bat"
        result = run([cmd, "/d", "/c", str(bat), "-WhatIf", "-Json"])
        self.assertEqual(result.returncode, 0, result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["results"][0]["status"], "WOULD_APPLY")
        self.assertIsNone(payload["snapshot"])

    def test_audit_only_legacy_launcher_propagates_failure(self):
        cmd = shutil.which("cmd.exe")
        self.assertIsNotNone(cmd, "cmd.exe must exist on the Windows test host")
        bat = ROOT / "05_multimedia_system_profile.bat"
        result = run([cmd, "/d", "/c", str(bat), "-WhatIf", "-Json"])
        self.assertEqual(result.returncode, 3, result.stderr)
        payload = json.loads(result.stdout)
        self.assertEqual(payload["results"][0]["status"], "AUDIT_ONLY")
        self.assertIsNone(payload["snapshot"])

    def test_restore_rejects_snapshot_target_not_in_module_catalog(self):
        BACKUPS.mkdir(parents=True, exist_ok=True)
        filename = BACKUPS / f"test-forged-{uuid4().hex}.json"
        filename.write_text(json.dumps({
            "schemaVersion": 1, "root": str(ROOT),
            "modules": ["01"], "entries": [{
                "module": "01", "kind": "Registry",
                "path": r"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
                "name": "Dangerous", "present": False,
                "keyPresent": True, "previousValue": None,
                "previousKind": None
            }]
        }), encoding="utf-8")
        try:
            result = run(["pwsh", "-NoProfile", "-NonInteractive",
                          "-File", str(ENGINE), "-Action", "Restore",
                          "-Snapshot", str(filename), "-WhatIf", "-Json"])
            self.assertEqual(result.returncode, 1, result.stderr)
            payload = json.loads(result.stdout)
            self.assertEqual(payload["status"], "ERROR")
        finally:
            filename.unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()
