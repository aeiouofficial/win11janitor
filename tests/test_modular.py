"""Non-mutating coverage for edition guards, diagnostics and frame analysis."""
import json
import os
from pathlib import Path
import subprocess
import unittest
from uuid import uuid4
from test_cli import ROOT, WORKSPACE, invoke

SRC = ROOT / "src"
BENCH = WORKSPACE / "benchmarks" / "captures"


def run_ps(script):
    env = dict(os.environ, TEMP=str(WORKSPACE / "tmp"),
               TMP=str(WORKSPACE / "tmp"), TMPDIR=str(WORKSPACE / "tmp"),
               PYTHONDONTWRITEBYTECODE="1", POWERSHELL_TELEMETRY_OPTOUT="1")
    return subprocess.run(["pwsh", "-NoProfile", "-NonInteractive", "-Command",
                           script], cwd=ROOT, env=env, capture_output=True,
                          text=True, encoding="utf-8", errors="replace", timeout=25)


def run_file(script, *args):
    return run_ps_file(SRC / script, *args)


def run_ps_file(script, *args):
    env = dict(os.environ, TEMP=str(WORKSPACE / "tmp"),
               TMP=str(WORKSPACE / "tmp"), TMPDIR=str(WORKSPACE / "tmp"),
               PYTHONDONTWRITEBYTECODE="1", POWERSHELL_TELEMETRY_OPTOUT="1")
    return subprocess.run(["pwsh", "-NoProfile", "-NonInteractive",
                           "-File", str(script), *args, "-Json"], cwd=ROOT,
                          env=env, capture_output=True, text=True,
                          encoding="utf-8", errors="replace", timeout=50)
class ModuleExpansion(unittest.TestCase):
    def test_old_safe_contract_unchanged(self):
        status, payload = invoke("-Action", "Plan", "-Profile", "Safe")
        self.assertEqual(status.returncode, 0, status.stderr)
        self.assertEqual({x["id"] for x in payload["results"]},
                         {"01", "02", "03", "04", "17"})

    def test_new_modules_are_opt_in_with_references(self):
        status, payload = invoke("-Action", "Plan", "-Profile", "Advanced")
        self.assertEqual(status.returncode, 0, status.stderr)
        extras = {x["id"]: x for x in payload["results"] if int(x["id"]) >= 18}
        self.assertEqual(set(extras), {"18", "19", "20", "21", "22", "23"})
        self.assertTrue(all(x["reference"].startswith("https://learn.microsoft.com/")
                            and x["impact"] for x in extras.values()))
        self.assertIn("capabilities", payload)

    def test_home_and_missing_edge_are_blocked_by_metadata(self):
        modules = SRC / "Modules.ps1"
        caps = SRC / "Capabilities.ps1"
        code = (". '" + str(modules) + "'; . '" + str(caps) +
                "'; $home=[pscustomobject]@{client=$true;build=26200;"
                "edition='Core';edgePresent=$false}; "
                "$pro=[pscustomobject]@{client=$true;build=26200;"
                "edition='Professional';edgePresent=$true}; "
                "$results=@(18..23|%{ $m=$script:Catalog[[string]$_]; "
                "[pscustomobject]@{id=$m.id;home=[string]"
                "(Get-ModuleSupportReason $m $home);pro=[string]"
                "(Get-ModuleSupportReason $m $pro)} });"
                "$results|ConvertTo-Json -Compress")
        proc = run_ps(code)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        result = json.loads(proc.stdout)
        self.assertEqual(len(result), 6)
        self.assertTrue(all(item["home"] and not item["pro"] for item in result))
    def test_advanced_dry_run_never_snapshots(self):
        backup = WORKSPACE / "backups"
        before = set(backup.glob("*.json")) if backup.exists() else set()
        proc, payload = invoke("-Action", "Apply", "-Profile", "Advanced", "-WhatIf")
        self.assertIn(proc.returncode, (0, 2), proc.stderr)
        self.assertIsNone(payload["snapshot"])
        self.assertTrue(all(x["status"] in ("WOULD_APPLY", "UNSUPPORTED")
                            for x in payload["results"]))
        after = set(backup.glob("*.json")) if backup.exists() else set()
        self.assertEqual(before, after)


class DiagnosticsContracts(unittest.TestCase):
    def test_hardware_diagnostic_does_not_save_by_default(self):
        proc = run_file("Diagnostics.ps1", "-Category", "Hardware")
        self.assertIn(proc.returncode, (0, 2), proc.stderr)
        report = json.loads(proc.stdout)
        self.assertEqual(report["schemaVersion"], 1)
        self.assertIsNone(report["savedTo"])
        self.assertIn(report["probes"]["Hardware"]["status"], ("OK", "UNAVAILABLE"))

    def test_startup_redacts_commands(self):
        proc = run_file("Diagnostics.ps1", "-Category", "Startup")
        self.assertIn(proc.returncode, (0, 2), proc.stderr)
        report = json.loads(proc.stdout)
        startup = report["probes"]["Startup"]
        if startup["status"] == "OK":
            self.assertTrue(all(entry["commandRedacted"]
                                for entry in startup["data"]["runEntries"]))
            self.assertNotIn("commandLine", proc.stdout)

    def test_interrupts_never_request_configuration(self):
        proc = run_file("Diagnostics.ps1", "-Category", "Interrupts")
        self.assertIn(proc.returncode, (0, 2), proc.stderr)
        report = json.loads(proc.stdout)
        self.assertIn("Interrupts", report["probes"])
        self.assertIsNone(report["savedTo"])
class SnapshotGuardContracts(unittest.TestCase):
    def test_state_comparison_detects_external_registry_change(self):
        state = SRC / "State.ps1"
        code = (". '" + str(state) + "'; "
                "$op=[pscustomobject]@{Kind='Registry'};"
                "$a=[pscustomobject]@{present=$true;previousKind='DWord';"
                "previousValue=0};"
                "$b=[pscustomobject]@{present=$true;previousKind='DWord';"
                "previousValue=1};"
                "if((Test-SameTargetState $op $a $a) -and "
                "-not (Test-SameTargetState $op $a $b)){exit 0}else{exit 9}")
        proc = run_ps(code)
        self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_preflight_detects_external_empty_registry_key(self):
        state = SRC / "State.ps1"
        code = (". '" + str(state) + "';"
                "$op=[pscustomobject]@{Kind='Registry'};"
                "$before=[pscustomobject]@{present=$false;keyPresent=$false};"
                "$external=[pscustomobject]@{present=$false;keyPresent=$true};"
                "if(-not (Test-SameTargetState $op $before $external) -and "
                "(Test-SameTargetState $op $before $before)){exit 0}else{exit 9}")
        proc = run_ps(code)
        self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_expected_sid_mismatch_fails_closed(self):
        safety = SRC / "AccountSafety.ps1"
        code = (". '" + str(safety) + "'; try { "
                "Assert-JanitorAccountContext -Targets @() "
                "-ExpectedUserSid 'S-1-5-21-not-current'; exit 8"
                "} catch {exit 0}")
        proc = run_ps(code)
        self.assertEqual(proc.returncode, 0, proc.stderr)
class PerformanceLabContracts(unittest.TestCase):
    def setUp(self):
        BENCH.mkdir(parents=True, exist_ok=True)
        marker = uuid4().hex
        self.baseline = BENCH / f"test-baseline-{marker}.csv"
        self.candidate = BENCH / f"test-candidate-{marker}.csv"
        header = "Application,ProcessID,SwapChainAddress,MsBetweenPresents\n"
        self.baseline.write_text(header + ("unit.exe,42,0xAAA,10.0\n" * 200),
                                 encoding="utf-8")
        self.candidate.write_text(header + ("unit.exe,42,0xAAA,8.333333\n" * 200),
                                  encoding="utf-8")

    def tearDown(self):
        self.baseline.unlink(missing_ok=True)
        self.candidate.unlink(missing_ok=True)

    def test_repeatable_csv_comparison(self):
        proc = run_file("PerformanceLab.ps1", "-Action", "Compare",
                        "-InputCsv", str(self.baseline),
                        "-CandidateCsv", str(self.candidate))
        self.assertEqual(proc.returncode, 0, proc.stderr)
        result = json.loads(proc.stdout)["result"]
        self.assertAlmostEqual(result["baseline"]["estimatedFps"], 100.0, places=1)
        self.assertAlmostEqual(result["candidate"]["estimatedFps"], 120.0, places=1)
        self.assertFalse(result["verifiedSameScenario"])

    def test_csv_cannot_escape_workspace(self):
        proc = run_file("PerformanceLab.ps1", "-Action", "Analyze",
                        "-InputCsv", str(ROOT / "README.md"))
        self.assertEqual(proc.returncode, 1)
        self.assertIn("workspace", proc.stdout)

    def test_capture_requires_pinned_tool_hash(self):
        proc = run_file("PerformanceLab.ps1", "-Action", "Capture",
                        "-ProcessName", "unit.exe")
        self.assertEqual(proc.returncode, 1)
        self.assertIn("ExpectedSha256", proc.stdout)


class CrossRuntimeContracts(unittest.TestCase):
    def test_windows_powershell_51_parses_all_modules(self):
        src = str(SRC).replace("'", "''")
        command = ("$failed=@(); Get-ChildItem -LiteralPath '" + src +
                   "' -Filter *.ps1 | ForEach-Object { $tokens=$null; "
                   "$errors=$null; $null=[System.Management.Automation.Language.Parser]"
                   "::ParseFile($_.FullName,[ref]$tokens,[ref]$errors); "
                   "if($errors){$failed+=$_.Name} };"
                   "if($failed.Count){Write-Output ($failed -join ',');exit 8}else{exit 0}")
        env = dict(os.environ, TEMP=str(WORKSPACE / "tmp"),
                   TMP=str(WORKSPACE / "tmp"), TMPDIR=str(WORKSPACE / "tmp"))
        p = subprocess.run(["powershell.exe", "-NoProfile", "-NonInteractive",
                            "-Command", command], cwd=ROOT, env=env,
                           capture_output=True, text=True, timeout=25)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)

    def test_d_drive_workspace_guard_rejects_outside_path(self):
        helper = SRC / "Workspace.ps1"
        code = (". '" + str(helper) + "';"
                "try {$null=Assert-JanitorWorkspacePath "
                "-Path 'C:\\Windows\\Temp\\untrusted.csv' "
                "-AllowedRoot 'D:\\win11janitor'; exit 7} "
                "catch {exit 0}")
        p = run_ps(code)
        self.assertEqual(p.returncode, 0, p.stderr)

    def test_schema_two_snapshot_dry_run(self):
        path = WORKSPACE / "backups" / f"test-v2-{uuid4().hex}.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        fixture = {"schemaVersion": 2, "root": str(ROOT), "state": "APPLIED",
                   "userSid": "not-used-for-HKLM", "modules": ["18"], "entries": [{
                       "module": "18", "kind": "Registry",
                       "path": r"HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search",
                       "name": "EnableDynamicContentInWSB", "present": False,
                       "keyPresent": False, "previousKind": None, "previousValue": None,
                       "expectedState": {"present": True, "previousKind": "DWord",
                                         "previousValue": 0}
                   }]}
        path.write_text(json.dumps(fixture), encoding="utf-8")
        try:
            status, payload = invoke("-Action", "Restore", "-Snapshot",
                                     str(path), "-WhatIf")
            self.assertEqual(status.returncode, 0, status.stderr)
            self.assertEqual(payload["results"][0]["status"], "WOULD_RESTORE")
        finally:
            path.unlink(missing_ok=True)

    def test_restore_rejects_nested_snapshot_path(self):
        nested = WORKSPACE / "backups" / f"nested-{uuid4().hex}"
        nested.mkdir(parents=True, exist_ok=True)
        fixture = nested / "snapshot.json"
        fixture.write_text(json.dumps({"schemaVersion": 2, "root": str(ROOT),
            "entries": [{"module": "18", "kind": "Registry",
                "path": r"HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search",
                "name": "EnableDynamicContentInWSB", "present": False}]}),
            encoding="utf-8")
        try:
            proc, payload = invoke("-Action", "Restore", "-Snapshot", str(fixture),
                                   "-WhatIf")
            self.assertEqual(proc.returncode, 1, proc.stderr)
            self.assertEqual(payload["status"], "ERROR")
        finally:
            fixture.unlink(missing_ok=True)
            nested.rmdir()


if __name__ == "__main__":
    unittest.main()
