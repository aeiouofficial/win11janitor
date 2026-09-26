# win11janitor: safety and correctness repairs

## Approved brief
Correct the existing 16-module suite and master runner in D:\win11janitor. Preserve non-destructive deployment, meaningful privacy changes, security protections, and existing recognizable entrypoints. Store all temporary files, snapshots, tests and logs inside D:\win11janitor, never on C:. No live OS tweaks during engineering or test verification.

## Evidence and design
The original scripts unconditionally change services, filesystem, networking and power configuration; most ignore error codes. MMCSS SystemResponsiveness=0 is clamped to 20 per Microsoft. Broad changes to SysMain, RAM compression, RSC, Nagle, ETW and core parking lack universally demonstrated gains. The local folder was an unversioned copy; original files have been committed to baseline/original (863989c), development is on fix/safe-modules-rollback.

Introduce a native PowerShell orchestration entrypoint with explicit Audit, Plan, Apply and Restore. Retain numbered batch wrappers for compatibility. Default Safe applies only reversible, low-risk privacy changes; Advanced is opt-in for functional trade-offs. Modules with no verified broad benefit become audit-only instead of falsely claiming optimization. A rollback snapshot is persisted inside D:\win11janitor\.workspace\backups BEFORE modification. Failures propagate nonzero exit codes. No Windows setting changes or rollback snapshots during Plan/Audit/dry-run (project-local temporary directory creation is permitted). Never disable Defender, updates, VBS or SmartScreen.

## Implementation tasks and verification
1. Write executable no-mutation CLI contract tests. Observe red against missing PowerShell entrypoint and unsafe legacy runner.
2. Implement centralized PowerShell module catalog, registry/service/task state capture, transaction logging, dry-run plan, supported modules and exact restoration. Test no-mutation paths live; never run Apply on development host.
3. Convert 16 entrypoints and master runner into exit-code-preserving wrappers; safe master default, auditable unsupported module errors. Test source contracts and subprocess integration.
4. Update README and CHANGELOG with genuine guarantees, limited edition support, module behavior, rollback invocation, caveats, and baseline measurements. Verify exact changed paths, parse PowerShell and Python tests, Git diff.
5. Keep changes in local feature branch. Do not push, merge or run system-changing commands during implementation.

## Scope decisions
Module 01 requests Required diagnostic data (level 1) where stricter settings are absent; it preserves an existing level-0 policy rather than weakening privacy on Enterprise/Education. No claim that all diagnostics can be disabled on Home/Pro. Modules 02-04 are opt-in privacy-safe. Modules 06 (DVR), 07 (DiagTrack only), 08 (Fast Startup only), 13 (telemetry tasks only) and 16 (user mouse pointer acceleration / transparency only) require explicit selection. Modules 05, 09-12, 14 and 15 are audit-only pending workload-specific evidence; no silent mutation. Add reversible advertising-ID control (17), included in Safe profile.

## Success criteria
Tests verify Audit/Plan/WhatIf never modify the OS, Apply requires elevation, Safe excludes aggressive features, snapshots are D-only, unsupported modules cannot report success, wrappers propagate errors and no C: workspace paths appear in scripts. System-level Apply/Restore require an explicit user-run elevated smoke test and cannot be honestly claimed verified from a no-mutation run.
