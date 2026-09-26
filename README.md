# Windows 11 Clean & Atlas OS–Inspired 17-Module Optimization Suite ⚡

[![Platform: Windows 11](https://img.shields.io/badge/Platform-Windows%2011-0078D6?logo=windows)](https://www.microsoft.com/windows/windows-11)
[![Status: Validation Pending](https://img.shields.io/badge/Status-Validation%20Pending-orange)](#-validation--performance)
[![Modules: 17](https://img.shields.io/badge/Modules-17%20Modular-blueviolet)](#-complete-17-module-architecture-matrix)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A modular, reversible **Windows 11 privacy and configuration suite**, inspired by the modular approach of [Atlas OS](https://github.com/Atlas-OS/Atlas) but not affiliated with it. It works on **existing Windows installations without an OS reinstall or destructive debloating**. Its five-module Safe profile limits unnecessary data collection; five functional changes are opt-in, and seven unverified or potentially counterproductive performance tweaks are retained as audit-only entries.

**Scope:** this release makes no unmeasured FPS, input-latency or throughput promises. The elevated Apply/Restore workflow still requires acceptance testing on a disposable Windows VM before being described as production-ready.

---

## 📋 Complete 17-Module Architecture Matrix

Every numbered batch file is a compatibility launcher for the centralized PowerShell engine. The **Safe** profile is the default; **Optional** modules require deliberate selection or the Advanced profile; **Audit-only** entries refuse mutation and return a nonzero exit code.

| # | Script | Target Subsystem | Description & Technical Operation |
| :---: | :--- | :--- | :--- |
| **01** | `01_disable_telemetry.bat` | Diagnostics | **Safe** — Requests Required diagnostic data (`AllowTelemetry=1`) when appropriate; preserves a stricter pre-existing zero policy. Required diagnostics cannot be fully disabled on Home/Pro. |
| **02** | `02_disable_activity_history.bat` | Privacy / Activity | **Safe** — Disables publishing and uploading Windows Activity History without deleting user data. |
| **03** | `03_disable_bing_start_search.bat` | Windows Shell / Explorer | **Safe** — Disables Start menu web-search suggestions for the current account; this is not a claim that Windows logs every keystroke. |
| **04** | `04_disable_tailored_experiences.bat` | Privacy / Personalization | **Safe** — Disables tailored experiences based on diagnostic data; preserves Start application tracking. |
| **05** | `05_multimedia_system_profile.bat` | Multimedia Scheduler | **Audit-only** — Does not apply unsupported blanket MMCSS or `SystemResponsiveness=0` tweaks. |
| **06** | `06_disable_game_dvr.bat` | Xbox / Game Capture | **Optional** — Disables Game DVR recording only when explicitly requested; it is not a guaranteed micro-stutter fix. |
| **07** | `07_disable_background_services.bat` | Windows Services | **Optional** — Disables `DiagTrack` only; keeps `SysMain` and its potential performance benefits. |
| **08** | `08_disable_hibernation_faststartup.bat` | Power / Startup | **Optional** — Disables Fast Startup while preserving hibernation and `hiberfil.sys`. |
| **09** | `09_ntfs_disable_last_access.bat` | NTFS Filesystem | **Audit-only** — Preserves Windows' existing Last Access behavior and backup compatibility. |
| **10** | `10_ntfs_disable_8dot3_names.bat` | NTFS Filesystem | **Audit-only** — Preserves existing 8.3 filename settings and legacy application compatibility. |
| **11** | `11_network_tcp_global_tuning.bat` | TCP/IP Stack | **Audit-only** — Does not impose unmeasured RSS, RSC, ECN or autotuning changes on every adapter. |
| **12** | `12_disable_nagles_algorithm.bat` | Network Latency | **Audit-only** — Does not modify every TCP interface or imply that TCP changes improve UDP games. |
| **13** | `13_disable_telemetry_tasks.bat` | Task Scheduler | **Optional** — Disables only three named CEIP/Feedback tasks when present; preserves compatibility, disk diagnostic and WinSAT tasks. |
| **14** | `14_disable_etw_autologgers.bat` | Windows Diagnostics | **Audit-only** — Preserves ETW tracing needed for reliability and troubleshooting. |
| **15** | `15_ultimate_performance_coreparking.bat` | CPU / Power | **Audit-only** — Preserves adaptive CPU core parking and the existing power plan. |
| **16** | `16_memory_management_and_raw_input.bat` | Input / Desktop | **Optional** — Disables current-user pointer acceleration and transparency only; preserves memory compression and kernel paging. |
| **17** | `17_disable_advertising_id.bat` | Privacy / Advertising | **Safe** — Disables the current user's Windows advertising identifier. |

---

## 🚀 How to Use

### 1-Click Execution (Safe Profile)

1. Right-click **`RUN_ALL_OPTIMIZATIONS.bat`** and choose **Run as administrator**.
2. Review the displayed plan. The master runner offers only modules **01, 02, 03, 04 and 17** by default.
3. Confirm the changes. The engine writes a per-run rollback snapshot **before** modifying any Windows setting.
4. Check the reported status and retain the snapshot path printed after execution. Restart only if Windows or an affected feature requires it.

### Selective Modular Execution

You can still launch any numbered `.bat` file individually. For example, `06_disable_game_dvr.bat` changes Game DVR only; an audit-only entry such as `05_multimedia_system_profile.bat` explicitly refuses to apply its former tweak. These scripts use Windows PowerShell 5.1 and forward their exit codes.

Use the PowerShell CLI for **read-only inspection**, module-specific changes or rollback. The examples below use PowerShell 7 (`pwsh`), where installed; the included batch launchers use built-in Windows PowerShell.

```powershell
# No elevation; these operations do not change Windows settings.
pwsh -NoProfile -File .\src\Win11Janitor.ps1 -Action Audit -Profile Advanced -Json
pwsh -NoProfile -File .\src\Win11Janitor.ps1 -Action Audit -Module 05 -Json
pwsh -NoProfile -File .\src\Win11Janitor.ps1 -Action Plan -Profile Safe -Json
pwsh -NoProfile -File .\src\Win11Janitor.ps1 -Action Apply -Profile Safe -WhatIf -Json

# Explicitly selected changes; run in an elevated terminal.
pwsh -NoProfile -File .\src\Win11Janitor.ps1 -Action Apply -Profile Safe
pwsh -NoProfile -File .\src\Win11Janitor.ps1 -Action Apply -Module 06

# Use the exact JSON snapshot path printed by your own Apply run.
pwsh -NoProfile -File .\src\Win11Janitor.ps1 -Action Restore -Snapshot 'D:\win11janitor\.workspace\backups\YOUR_SNAPSHOT.json' -WhatIf
pwsh -NoProfile -File .\src\Win11Janitor.ps1 -Action Restore -Snapshot 'D:\win11janitor\.workspace\backups\YOUR_SNAPSHOT.json'
```

**Important:** Elevated `HKCU` changes affect the account running the process. If UAC switches to a different administrator account, the current-user privacy settings affect that administrator, not your normal account.

---

## 🛡️ Exclusions & Security Notice: Why "The Aggressive Tier" Is Excluded

Security-sensitive and unproven system-wide tweaks are **not** part of the Safe profile. This suite deliberately avoids:

- **Disabling Virtualization-Based Security (VBS), Core Isolation (HVCI) or CPU security mitigations.**
- **Disabling Microsoft Defender Antivirus, SmartScreen or Windows Update.**
- **Unconditionally disabling SysMain, memory compression, ETW, CPU parking or networking features.**
- **Bulk removal of Windows components, security services or user applications.**

Optional changes can still disable functionality you use (for example, Game DVR or Fast Startup). Review the target module before applying it. Windows updates may also change the availability or behavior of individual settings.

**Workspace policy:** project-generated temporary files, logs and rollback snapshots belong in `D:\win11janitor\.workspace`. Applying Windows registry settings naturally causes the operating system to write to its installed system volume; the tool cannot redirect Windows' own system storage.

---

## 🔄 Reversion / Rollback Reference

Unlike generic "restore Windows defaults" scripts, the new engine captures **your actual original settings** before Apply. A snapshot can record previously absent registry values, value types, service startup state and scheduled-task state.

1. Preserve the JSON snapshot reported by Apply under `D:\win11janitor\.workspace\backups`.
2. Preview restoration using `-Action Restore -Snapshot YOUR_PATH -WhatIf`.
3. Restore from an elevated terminal using the exact same path.
4. If you applied multiple overlapping snapshots, restore the **newest first**.

On a caught Apply failure, the engine attempts to roll back affected targets and reports any restoration failures. Power loss or forced termination may still require a manual Restore. Never substitute guessed Windows defaults for the saved state.

**Exit codes:** `0` = success; `1` = execution/rollback failure; `2` = partial apply; `3` = unsupported audit-only operation. Inspect individual results rather than trusting a headline alone.

---

## 🧪 Validation & Performance

The automated suite checks safe planning, dry-run behavior, PowerShell parsing, batch-wrapper error propagation, snapshot validation, preservation of stricter diagnostic settings and documentation integrity. **Automated tests do not execute elevated Apply/Restore on your Windows installation.** Production acceptance requires a disposable VM and a successful Apply → inspect → Restore → compare sequence.

Actual responsiveness gains should be established through before/after measurements of the affected workload—boot-to-idle time, idle resource usage, application startup, game frame-time percentiles and network latency or throughput. Use targeted Microsoft performance diagnostics before disabling background services or changing networking defaults.

```powershell
$env:TEMP = 'D:\win11janitor\.workspace\tmp'
$env:TMP = $env:TEMP
$env:PYTHONDONTWRITEBYTECODE = '1'
python -m unittest discover -s tests -v
```

Technical references: [Windows diagnostic-data policies](https://learn.microsoft.com/en-us/windows/privacy/configure-windows-diagnostic-data-in-your-organization), [Multimedia Class Scheduler Service](https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service) and [NTFS behavior](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/fsutil-behavior).

---

## 📄 License

This suite is open-source under the [MIT License](LICENSE). See [CHANGELOG.md](CHANGELOG.md) for changes and `docs/superpowers/` for the engineering design and implementation plan.
