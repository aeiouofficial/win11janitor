"""Type and restore validation without changing any Windows setting."""
import json
from pathlib import Path
import unittest
from test_cli import ROOT, WORKSPACE, invoke


class StateContracts(unittest.TestCase):
    def test_mouse_values_keep_reg_sz_type(self):
        result, payload = invoke("-Action", "Plan", "-Module", "16")
        self.assertEqual(result.returncode, 0, result.stderr)
        targets = payload["results"][0]["targets"]
        mouse = [t for t in targets if t["name"].startswith("Mouse")]
        self.assertEqual(len(mouse), 3)
        self.assertTrue(all(t["valueKind"] == "String" for t in mouse))

    def test_valid_restore_dry_run_reads_only_the_backup(self):
        backup = WORKSPACE / "backups"
        backup.mkdir(parents=True, exist_ok=True)
        fixture = backup / "test-restore-dry-run.json"
        fixture.write_text(json.dumps({
            "schemaVersion": 1, "root": str(ROOT),
            "modules": ["01"],
            "entries": [{
                "module": "01", "kind": "Registry",
                "path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\DataCollection",
                "name": "AllowTelemetry", "present": False,
                "keyPresent": True, "previousValue": None,
                "previousKind": None
            }]
        }), encoding="utf-8")
        try:
            result, payload = invoke("-Action", "Restore",
                                     "-Snapshot", str(fixture), "-WhatIf")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(payload["results"][0]["status"], "WOULD_RESTORE")
        finally:
            fixture.unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()
