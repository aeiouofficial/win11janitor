# Changelog

## Unreleased — 2026-09-27

- Document a source-backed modular expansion plan, security contract and phased roadmap.
- Extend the catalog from 17 to 23 modules with six explicitly opt-in, edition/build/Edge-gated Windows Search, Widgets, browser background and clipboard controls.
- Add Windows capability detection; unsupported modules are visible in Plan/Audit and refuse explicit Apply instead of silently writing ineffective policies.
- Add read-only hardware, startup and interrupt inventory with per-probe failure status and D-only optional JSON exports.
- Add the optional, hash-pinned PresentMon adapter plus bounded CSV import, frame-time analysis and A/B reports; no unverified performance claims.
- Add SID-aware HKCU safety and guarded schema-v2 snapshots containing verified post-apply state; detect external changes before Restore.
- Add `RUN_DIAGNOSTICS.bat` and `RUN_PERFORMANCE_LAB.bat`; preserve the existing 17 compatibility launchers and the professional README structure.
- Add Windows local, non-mutating tests for the new module matrix, diagnostics, account safety, snapshot comparisons and deterministic performance parsing.
- Add P4 session foundation: PowerShell 5.1-compatible Win32 interop for process power-throttling and CPU-set inspection, identity-bound EcoQoS plans, transactional session journals, exact-state Restore and explicit `-Experimental` mutation gating. No game CPU-set/priority mutation or watchdog is enabled yet.
- Preserve all project-created caches, temporary files, reports, logs and snapshots under `D:\win11janitor\.workspace`.

**Not yet production-accepted:** no elevated Apply/Restore VM matrix has been executed; real PresentMon capture and SessionLab EcoQoS Apply/Restore require separate VM validation. CPU-set writes, game-process priority/affinity, watchdog recovery and vendor GPU adapters remain deferred.

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
