# win11janitor

Reversible Windows 11 privacy configuration for an existing installation. This project is **not** an FPS accelerator and does not require an OS reinstall, third-party Windows image, destructive debloating, disabling Microsoft Defender, or disabling VBS.

## Safety and execution

- Default master runner previews five Safe privacy modules, requests confirmation, and reports errors rather than unconditionally claiming success.
- `Audit`, `Plan`, `Apply -WhatIf` and `Restore -WhatIf` do not change Windows settings. Use these first.
- Before `Apply` changes a Windows setting, it records the original state of *every selected target* in a JSON snapshot inside `D:\win11janitor\.workspace\backups`. The engine attempts an automatic rollback on caught failures; abrupt power loss or process termination requires manual restore from the saved snapshot. Review rollback results because restoration can itself fail.
- Logs, snapshots, lock files and project temporary files stay inside `D:\win11janitor\.workspace`. Windows naturally persists registry changes on its system drive when you apply them.
- Optional modules can remove features you use; select them only deliberately. Unsupported performance experiments are **audit-only** and return nonzero on an attempted apply.
- Elevated HKCU operations affect whichever user account runs the elevated terminal. If UAC asks for another administrator's credentials, do not apply user-specific modules from that other account.
- Never restore overlapping snapshots out of order; restore the most recent first. Preserve snapshot files.

## Module matrix

| ID | Mode | Behavior |
|---|---|---|
| 01 | Safe | Use Required diagnostics if unset or less restrictive; preserve an existing stricter zero policy. Home/Pro cannot turn all required diagnostics off. |
| 02 | Safe | Disable activity-feed publishing and uploading. |
| 03 | Safe | Disable Start menu web search suggestions for the current account. |
| 04 | Safe | Disable diagnostic-data tailored experiences, preserving Start application tracking. |
| 05 | Audit-only | Avoid unsupported global MMCSS/network-priority tweaks. |
| 06 | Optional | Disable Game DVR capture when you do not need it. |
| 07 | Optional | Disable DiagTrack, **not SysMain**. |
| 08 | Optional | Disable Fast Startup while keeping hibernation. |
| 09 | Audit-only | Preserve the existing NTFS Last Access policy. |
| 10 | Audit-only | Preserve the existing NTFS 8.3-name policy. |
| 11 | Audit-only | Preserve TCP auto-tuning, RSS/RSC, ECN and timestamps. |
| 12 | Audit-only | Do not disable Nagle for every network interface. |
| 13 | Optional | Disable only the named CEIP and Feedback scheduled tasks where available. |
| 14 | Audit-only | Preserve ETW diagnostic tracing. |
| 15 | Audit-only | Preserve adaptive CPU parking and the original power plan. |
| 16 | Optional | Change pointer acceleration and transparency only; preserve memory compression and kernel paging. |
| 17 | Safe | Disable the current-user advertising ID. |

The 17 numbered batch files remain compatible launchers; audit-only launchers explicitly refuse to mutate Windows. Audit-only entries document deliberately excluded tweaks; they do not benchmark the excluded settings. They accept extra PowerShell arguments after the module ID, e.g. `-WhatIf -Json`.

## Usage

From `D:\win11janitor`. Read-only commands do not require elevation. Use an **elevated terminal** only after reviewing the plan:

```powershell
# Inspect and preview without changing Windows:
pwsh -NoProfile -File .\src\Win11Janitor.ps1 -Action Audit -Profile Advanced -Json
pwsh -NoProfile -File .\src\Win11Janitor.ps1 -Action Plan -Profile Safe -Json
pwsh -NoProfile -File .\src\Win11Janitor.ps1 -Action Apply -Profile Safe -WhatIf -Json

# Deliberate changes, from an elevated terminal:
.\RUN_ALL_OPTIMIZATIONS.bat
pwsh -NoProfile -File .\src\Win11Janitor.ps1 -Action Apply -Module 06
pwsh -NoProfile -File .\src\Win11Janitor.ps1 -Action Apply -Profile Advanced

# Replace SNAPSHOT_PATH with the exact path printed when Apply ran:
pwsh -NoProfile -File .\src\Win11Janitor.ps1 -Action Restore -Snapshot SNAPSHOT_PATH -WhatIf
pwsh -NoProfile -File .\src\Win11Janitor.ps1 -Action Restore -Snapshot SNAPSHOT_PATH
```

`pwsh` is PowerShell 7; legacy launchers use built-in Windows PowerShell 5.1. Exit codes: 0 successful, 1 error/rollback problem, 2 partial apply, 3 unsupported module. Inspect JSON `status` and individual `results`, not just the exit code. A successful dry-run does **not** establish that an elevated Apply/Restore works on every Windows edition.

## Validation and performance

Run tests without modifying Windows settings:

```powershell
$env:TEMP='D:\win11janitor\.workspace\tmp'
$env:TMP=$env:TEMP
$env:PYTHONDONTWRITEBYTECODE='1'
python -m unittest discover -s tests -v
```

A disposable Windows VM with a snapshot is required for the elevated Apply/Restore acceptance gate. Only claim a performance gain when it is measured on the specific PC/workload: boot-to-idle, idle CPU/RAM, frame-time percentiles, application launch times and network throughput/latency. Earlier quantitative performance claims were unsubstantiated and have been removed.

References: [Microsoft diagnostic-data policy](https://learn.microsoft.com/en-us/windows/privacy/configure-windows-diagnostic-data-in-your-organization), [MMCSS](https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service), [NTFS behavior](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/fsutil-behavior).

License: MIT (see LICENSE).
