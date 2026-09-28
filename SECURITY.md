# Security Policy and Threat Model
win11janitor changes Windows policy and may require elevation. The D: repository and its scripts must be trusted before an administrator launches them.

## Trust boundaries
- No scripts or executable binaries are downloaded and launched automatically. Never run an unreviewed fork or downloaded `irm | iex` payload as administrator.
- JSON snapshots are data, not executable code. Restore validates module IDs and allowlisted targets; there is no arbitrary command operation in the module catalog.
- Apply/Restore use exclusive file locks and record trace IDs. Schema-v2 completed snapshots contain verified post-apply state; Restore refuses unexpected third-party changes unless `-ForceRestore` is deliberately given.
- User-scoped changes are bound to the elevated account. When the interactive Explorer owner differs, HKCU mutation is refused; a headless session requires `-ExpectedUserSid` for HKCU operations.
- Edition/build support and Edge presence must be detected. A successful write of a registry key is not proof a Windows feature honors it.
- `Diagnostics.ps1` has no mutation path; `PerformanceLab.ps1` analyzes workspace CSV and only launches `PresentMon.exe` when an explicit matching SHA-256 is supplied.
- `SessionLab.ps1` Plan binds each selected background process to PID + process creation FILETIME + full image path + executable SHA-256 + owner SID. Apply requires that saved plan and `-Experimental`, rechecks all identities/states before the first mutation, and writes the PREPARED session journal first.

## Local file integrity
The engine does **not** provide a cryptographic security boundary against a local attacker who can modify the elevated script, the repository or its snapshots. Restrict modification of `D:\win11janitor` to trusted administrators/users, review `git diff` before running elevated, and obtain reviewed releases from the official project.
An arbitrary untrusted program already running as the same privileged user can also tamper with policy or snapshots. JSON path validation, a workspace prefix and an unkeyed hash are not a substitute for trusted directory ACLs or signed distribution.
## Recovery
If Apply fails, its caught-error path attempts to restore touched targets. Power loss can leave a PREPARED snapshot without post-apply values: inspect the backup and use explicit `-ForceRestore` only after comparing the device's current values. If an unrelated administrator account was used by mistake, do not restore its HKCU state into the normal user's hive.
On an unexplained conflict (exit 4), inspect the conflicting module/target and Group Policy or other system managers before restoring. Maintain original backup files until VM acceptance verifies new releases.
For a legacy v1 snapshot containing HKCU operations, include `-ExpectedUserSid` to bind the target account. Machine-only legacy restores remain supported without this flag.

## Verification boundary
Automated tests and dry-runs do not execute elevated engine Apply/Restore or SessionLab EcoQoS Apply on the development PC. SessionLab native reads and planning have been exercised read-only. The feature branch is not production-accepted until the VM matrix and complete state-diff acceptance gates pass.

## Reporting
Report security defects through GitHub private vulnerability reporting when available; otherwise open a minimal issue without credentials, computer identifiers or sensitive logs.
