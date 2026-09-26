"""Source-level safety contracts for CMD compatibility entrypoints."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class WrapperContracts(unittest.TestCase):
    def test_every_legacy_entrypoint_routes_through_the_engine(self):
        files = sorted(ROOT.glob("[0-1][0-9]_*.bat"))
        self.assertEqual(len(files), 17)
        for script in files:
            with self.subTest(script=script.name):
                text = script.read_text(encoding="utf-8").lower()
                self.assertIn("src\\win11janitor.ps1", text)
                self.assertIn("exit /b", text)
                for unsafe in ("reg add", "sc config", "fsutil behavior set",
                               "netsh int tcp set", "disable-mmagent",
                               "powercfg /h off"):
                    self.assertNotIn(unsafe, text)

    def test_master_never_announces_unconditional_success(self):
        runner = (ROOT / "RUN_ALL_OPTIMIZATIONS.bat").read_text(
            encoding="utf-8").lower()
        self.assertIn("-profile safe", runner)
        self.assertIn("if errorlevel 1", runner)
        self.assertNotIn("all 16 optimization modules completed successfully", runner)

    def test_original_readme_presentation_is_preserved(self):
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertTrue(readme.startswith("# Windows 11 Clean & Atlas OS"))
        for marker in (
            "[![Platform:", "[![Status:", "[![Modules:", "[![License:",
            "## 📋 Complete 17-Module Architecture Matrix",
            "| # | Script | Target Subsystem | Description & Technical Operation |",
            "## 🚀 How to Use", "## 🛡️ Exclusions & Security Notice",
            "## 🔄 Reversion / Rollback Reference", "## 📄 License",
        ):
            with self.subTest(marker=marker):
                self.assertIn(marker, readme)
        self.assertEqual(readme.count("| **0") + readme.count("| **1"), 17)

    def test_documentation_does_not_make_unsupported_claims(self):
        readme = (ROOT / "README.md").read_text(
            encoding="utf-8").lower()
        self.assertNotIn("80–90%", readme)
        self.assertIn("rollback", readme)
        self.assertIn("audit-only", readme)


if __name__ == "__main__":
    unittest.main()
