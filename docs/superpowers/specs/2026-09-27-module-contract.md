# Module and diagnostic contract — 2026-09-27
Primary source: [modular implementation plan](../plans/2026-09-27-modular-update.md).

## Native module schema
The centralized `src/Modules.ps1` catalog defines `id`, `mode`, `description`, typed `operations`, `minBuild`, `proPolicy`, `edgeRequired`, `impact` and `reference`. Every supported operation has a concrete registry path/name/type, task identity or service identity. Modules 18–23 are Optional, never included in the default Safe profile.
`src/Capabilities.ps1` reads Windows client type, EditionID, build and Edge installation status. Minimum build applies to all modules; ProPolicy allows specified Pro/Enterprise/Education/IoT variants, not Home. EdgeRequired fails if Edge is absent. Plan/Audit must report UNSUPPORTED without writing OS settings.
An explicit unsupported Apply is rejected with exit 3 before snapshot; Advanced/All may skip unsupported modules and return exit 2. Unsupported capabilities may not be auto-overridden. Feature changes cannot be inferred from the registry alone.

## Snapshot and account contract
The engine retains legacy schema 1. New schema 2 snapshots add state PREPARED/APPLIED, userSid, appliedUtc and expectedState captured immediately after verifying each operation. PREPARED is written before any mutation and APPLIED replaces the snapshot only after the complete selected apply sequence is verified.
Restore preflight under lock compares current state with original or expectedState. Any third-party divergence blocks the entire restoration before mutation, exit code 4. Explicit ForceRestore suppresses only divergence checking; it does not bypass catalog allowlists or snapshot-path checks.
An HKCU Apply or Restore validates the current elevated Windows SID against same-session Explorer; absent Explorer requires explicit ExpectedUserSid. A v1 HKCU snapshot also requires explicit ExpectedUserSid, as it has no userSid metadata.
## Diagnostic JSON
`src/Diagnostics.ps1 -Category All|Hardware|Startup|Interrupts -Json [-Save]` outputs schemaVersion=1, timestampUtc, traceId, status, per-probe status/data and savedTo. Per-probe failures are UNAVAILABLE and make the overall status PARTIAL (exit 2). Save uses atomic rename into D:\win11janitor\.workspace\benchmarks, without modifying Windows settings.
Hardware: operating-system edition/build, CPU cores/threads, GPU/driver, memory, Windows-reported physical disk media/health and battery where available. No BIOS/device serials. Startup: Run key names, scheduled logon task names, Startup directory file names; never emit command lines. Interrupts: current MSI and affinity policy registry indicators on PCI graphics/network/USB/audio devices; not a claim about actual DPC/ISR routing.
Absent P/E-core topology, unsupported sensors and unknown drive media types stay UNKNOWN/UNAVAILABLE; do not invent data.

## Performance Lab JSON
`src/PerformanceLab.ps1` accepts Analyze, Compare or opt-in Capture. CSV import is restricted to files within the D: project benchmarks tree and capped at 32 MiB. Uses PresentMon 2.x default `Application`, `SwapChainAddress` and `MsBetweenPresents` columns; selects the most populated swap chain and requires at least 120 valid frames.
Metrics: mean present-interval in milliseconds, estimated present FPS (1000/mean), nearest-rank p95/p99 intervals and reciprocal of the mean slowest one percent of intervals. They are not display-FPS or true input-latency measurements. Multiple process names require ProcessName. Comparisons are never marked same-scenario verified.
For Capture, only `D:\win11janitor\.workspace\tools\PresentMon.exe` may execute; the caller must supply a matching 64-digit SHA-256 and an already-running, sanitized exe name. Duration is limited to 10–180 seconds plus a bounded timeout. No downloader, admin relaunch, global ETW session termination or arbitrary shell arguments.
PresentMon option source: https://github.com/GameTechDev/PresentMon/blob/main/README-ConsoleApplication.md
No performance gain is credited to any optimization without repeated matched-scene A/B tests, temperature/power controls and failure reporting.

## Exit codes and release gates
0 complete; 1 execution failure; 2 partial or unavailable; 3 unsupported operation; 4 restore conflict. No user-visible all-success message may be emitted on partial or rollback failure.
Every new mutation requires schema tests, mock edition tests, no-mutation dry-runs, real Windows VM Apply/Restore state diff, safe failure injection and documentation. The development laptop must not be used for elevated mutation tests.
