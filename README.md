# Windows 11 Clean & Atlas OS–Inspired 23-Module Optimization Suite ⚡

[![Platform: Windows 11](https://img.shields.io/badge/Platform-Windows%2011-0078D6?logo=windows)](https://www.microsoft.com/windows/windows-11)
[![Status: Validation Pending](https://img.shields.io/badge/Status-Validation%20Pending-orange)](#-validation--performance)
[![Modules: 23](https://img.shields.io/badge/Modules-23%20Modular-blueviolet)](#-complete-17-module-architecture-matrix)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A modular, reversible **Windows 11 privacy and configuration suite**, inspired by the modular approach of [Atlas OS](https://github.com/Atlas-OS/Atlas) but not affiliated with it. It works on **existing Windows installations without an OS reinstall or destructive debloating**. Its five-module Safe profile limits unnecessary data collection; eleven functional changes are opt-in, and seven unverified or potentially counterproductive performance tweaks are retained as audit-only entries. The six newer modules include explicit Windows edition/build and feature checks.

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

## 🧩 Six Additional Opt-in Modules (18–23)

These modules use the same centralized PowerShell engine. They do not change the default five-module Safe profile and have no new legacy batch wrappers. Unsupported edition/build or absent Edge capabilities are reported as `UNSUPPORTED`; explicitly requesting an unsupported module refuses mutation.

| # | Module | Availability | Reversible change / functional trade-off |
| :---: | :--- | :--- | :--- |
| 18 | Search highlights | Pro/Enterprise/Education, build 22621+ | Disable dynamic search highlights; local file/app search remains available. |
| 19 | Cloud search | Pro/Enterprise/Education | Prevent Windows Search from querying cloud sources such as OneDrive/SharePoint. |
| 20 | Widgets | Pro/Enterprise/Education | Disable the Widgets experience using the device policy. |
| 21 | Edge background | Edge installed | Stop Edge background apps after the last browser window closes. |
| 22 | Edge startup boost | Edge installed | Disable preloading; Edge may take longer to launch. |
| 23 | Cross-device clipboard | Pro/Enterprise/Education | Prevent clipboard synchronization while retaining local history. |

These are functionality/privacy controls, not proven FPS optimizations. Module metadata includes impact and upstream policy references, returned in JSON Plan output.

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

**Important:** Elevated `HKCU` operations now check the interactive Explorer account and refuse to change another account's registry settings. For intentionally headless sessions without Explorer, pass `-ExpectedUserSid` matching `whoami /user`; this is not a cross-account override. Machine-only modules do not require an Explorer session.

### Hardware, Startup and Interrupt Inventory

Run `RUN_DIAGNOSTICS.bat` for a read-only inventory saved to `D:\win11janitor\.workspace\benchmarks`. The individual probes report `UNAVAILABLE` instead of fabricating absent sensor readings. Startup command lines and device serial numbers are deliberately excluded from normal output.

```powershell
pwsh -NoProfile -File .\src\Diagnostics.ps1 -Category Hardware -Json
pwsh -NoProfile -File .\src\Diagnostics.ps1 -Category Interrupts -Json
pwsh -NoProfile -File .\src\Diagnostics.ps1 -Category All -Save -Json
```

### Performance Lab (PresentMon CSV)

Analyze captured `MsBetweenPresents` values and compare the dominant swap chain. The tool reports estimated present cadence, p95/p99 frame times and a slowest-one-percent FPS estimate. It cannot establish comparable workloads from CSV alone, nor does it claim measured display FPS.

```powershell
pwsh -NoProfile -File .\src\PerformanceLab.ps1 -Action Analyze -InputCsv 'D:\win11janitor\.workspace\benchmarks\captures\baseline.csv' -Json
pwsh -NoProfile -File .\src\PerformanceLab.ps1 -Action Compare -InputCsv 'D:\win11janitor\.workspace\benchmarks\captures\baseline.csv' -CandidateCsv 'D:\win11janitor\.workspace\benchmarks\captures\candidate.csv' -Save -Json
```

Optional Capture uses a separately reviewed PresentMon console executable placed at `D:\win11janitor\.workspace\tools\PresentMon.exe`. Supply the independently verified SHA-256 using `-ExpectedSha256`, the exact game executable with `-ProcessName`, and `-Action Capture`; no binary is downloaded automatically. Captures are limited to 10–180 seconds and saved only to the project workspace. See [Performance Lab CLI](https://github.com/GameTechDev/PresentMon/blob/main/README-ConsoleApplication.md).

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

New schema-v2 snapshots also record verified post-apply target states. Before Restore, the engine checks that each target still matches either its saved original or the recorded applied state. An external change returns exit code `4` before restoration; `-ForceRestore` explicitly bypasses that conflict guard. Legacy v1 snapshots remain readable, but HKCU restoration requires `-ExpectedUserSid` because older snapshots lack account binding. On a caught Apply failure, the engine attempts to roll back touched targets. After power loss or forced termination, manual Restore may require `-ForceRestore` if the incomplete snapshot has no verified post-apply state.

**Exit codes:** `0` = success; `1` = execution/rollback failure; `2` = partial result; `3` = unsupported/audit-only operation; `4` = restore conflict. Inspect individual results rather than trusting a headline alone.

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

This suite is open-source under the [MIT License](LICENSE). See [CHANGELOG.md](CHANGELOG.md), [ROADMAP.md](ROADMAP.md), [SECURITY.md](SECURITY.md) and `docs/superpowers/` for engineering plans and the source-backed module contract. No third-party application code or binaries are vendored.
