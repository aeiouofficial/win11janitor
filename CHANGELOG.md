# Changelog

## Unreleased — 2026-09-26

- Preserve the original unversioned local scripts in baseline commit `863989c` on `baseline/original`.
- Add a centralized PowerShell CLI with Audit, Plan, Apply, Restore, dry-run and structured JSON output.
- Add rollback snapshots that record previously absent registry values, registry data types, task state and service startup/running state before applying changes.
- Add post-apply verification, attempted automatic rollback after failures and structured logs with trace IDs.
- Replace unconditional one-click execution with a Safe-profile preview and explicit confirmation.
- On Home/Pro, configure the Required diagnostic level rather than falsely claim complete diagnostic-data shutdown; preserve existing stricter zero policies on supported editions.
- Make Game DVR, DiagTrack, Fast Startup, selected telemetry tasks and pointer acceleration explicit optional operations.
- Preserve SysMain, hibernation, networking defaults, NTFS settings, ETW, memory compression, kernel paging, CPU parking and existing power plans unless workload-specific evidence justifies a separate project.
- Add an advertising-ID privacy module (17) and correct mouse registry types to REG_SZ.
- Replace old batch implementations with error-propagating compatibility wrappers. Experimental batch launchers refuse mutation.
- Add non-mutating regression tests and local implementation specifications.

### Known verification limit

Read-only and dry-run CLI tests do not prove the elevated Apply/Restore paths. Exercise those paths on a disposable Windows VM before production use; benchmark performance claims separately. No Windows configuration changes were intentionally applied during development.
