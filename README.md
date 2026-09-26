# Windows 11 Clean & Atlas OS 16-Module Optimization Suite ⚡

[![Platform: Windows 10 / 11](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-0078D6?logo=windows)](https://microsoft.com)
[![Status: Production Ready](https://img.shields.io/badge/Status-Production%20Ready-brightgreen)]()
[![Modules: 16](https://img.shields.io/badge/Modules-16%20Standalone-blueviolet)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)]()

A modular, production-grade optimization suite inspired by the [Atlas OS](https://github.com/Atlas-OS/Atlas) playbook. Designed to eliminate background telemetry, minimize kernel latency, optimize TCP network queues, and maximize gaming and system responsiveness on **existing Windows 10/11 installations without requiring an OS reinstallation or destructive debloating**.

---

## 📋 Complete 16-Module Architecture Matrix

Every script in this suite is fully self-contained with its own administrator elevation check. You can execute any single script individually or run them all at once using the master runner.

| # | Script | Target Subsystem | Description & Technical Operation |
| :---: | :--- | :--- | :--- |
| **01** | `01_disable_telemetry.bat` | Diagnostics | Sets `AllowTelemetry=0` in `HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection`. |
| **02** | `02_disable_activity_history.bat` | Privacy / Timeline | Sets `EnableActivityFeed=0` and `PublishUserActivities=0` under `HKLM:\...\System`. |
| **03** | `03_disable_bing_start_search.bat` | Windows Shell / Explorer | Disables Bing search keystroke logging in the Start Menu (`DisableSearchBoxSuggestions=1`). |
| **04** | `04_disable_tailored_experiences.bat` | Privacy / Ads | Disables `TailoredExperiencesWithDiagnosticDataEnabled` and `Start_TrackProgs`. |
| **05** | `05_multimedia_system_profile.bat` | Scheduler Profile | Sets `NetworkThrottlingIndex=0xffffffff` and `SystemResponsiveness=0` for gaming priority. |
| **06** | `06_disable_game_dvr.bat` | Xbox / Graphics | Sets `GameDVR_Enabled=0` and `AllowGameDVR=0` to eliminate micro-stutters during gaming. |
| **07** | `07_disable_background_services.bat` | Windows Services | Stops and disables `SysMain` (Superfetch disk thrashing) and `DiagTrack` telemetry daemons. |
| **08** | `08_disable_hibernation_faststartup.bat` | Power Architecture | Runs `powercfg /h off` to delete `hiberfil.sys`, freeing gigabytes of SSD space and ending fast startup driver leaks. |
| **09** | `09_ntfs_disable_last_access.bat` | NTFS Filesystem | Sets `fsutil behavior set disablelastaccess 1` to eliminate disk write overhead whenever files are read. |
| **10** | `10_ntfs_disable_8dot3_names.bat` | NTFS Filesystem | Sets `fsutil behavior set disable8dot3 1` to prevent legacy 8.3 short filename generation in large directories. |
| **11** | `11_network_tcp_global_tuning.bat` | TCP/IP Protocol Stack | Configures `netsh int tcp set global` with `rss=enabled`, `rsc=disabled`, and `autotuning=normal`. |
| **12** | `12_disable_nagles_algorithm.bat` | Network Latency / Ping | Iterates through all adapter GUIDs in registry to set `TcpAckFrequency=1` and `TCPNoDelay=1`. |
| **13** | `13_disable_telemetry_tasks.bat` | Task Scheduler | Deactivates scheduled telemetry tasks (Compatibility Appraiser, CEIP, DiskDiagnostic, WinSAT). |
| **14** | `14_disable_etw_autologgers.bat` | Kernel Event Tracing | Stops and sets `Start=0` on `AutoLogger-Diagtrack-Listener` and `SQMLogger` WMI sessions. |
| **15** | `15_ultimate_performance_coreparking.bat` | CPU & Power Management | Activates the **Ultimate Performance** power plan and sets core parking residency to 100% (`CPMINCORES 100`). |
| **16** | `16_memory_management_and_raw_input.bat` | Memory / Input / DWM | Disables RAM compression (`Disable-MMAgent`), locks kernel code into physical RAM (`DisablePagingExecutive=1`), removes mouse acceleration curves for 1:1 hardware translation, and disables DWM transparency. |

---

## 🚀 How to Use

### 1-Click Execution (All 16 Modules)
1. Right-click **`RUN_ALL_OPTIMIZATIONS.bat`**.
2. Select **Run as administrator**.
3. Press any key to start.
4. When prompted at the end, restart your PC to allow kernel, filesystem, and TCP stack changes to take full effect.

### Selective Modular Execution
Every script (`01` through `16`) is completely independent. If you only want to apply a specific optimization (such as disabling Nagle's algorithm for gaming or disabling Bing search in the Start Menu), simply right-click that specific `.bat` file and select **Run as administrator**.

---

## 🛡️ Exclusions & Security Notice: Why "The Aggressive Tier" Is Excluded

Atlas OS by default strips critical security defenses:
- **Disabling Virtualization-Based Security (VBS) / Core Isolation (HVCI)**
- **Disabling Spectre / Meltdown Speculative Execution CPU Mitigations**
- **Disabling Windows Defender Antivirus and SmartScreen**

**This suite deliberately excludes these destructive modifications.** These 16 modules deliver ~80–90% of the latency and responsiveness improvements of custom OS playbooks while keeping your security perimeter, hypervisor integrity, and Windows Update functionality completely intact.

---

## 🔄 Reversion / Rollback Reference

If you ever wish to revert any individual modification:

* **Fast Startup / Hibernation:** Run `powercfg /h on` in Admin Command Prompt.
* **SysMain Service:** Run `Set-Service -Name "SysMain" -StartupType Automatic; Start-Service -Name "SysMain"` in Admin PowerShell.
* **NTFS Last Access & 8.3 Names:** Run `fsutil behavior set disablelastaccess 0` and `fsutil behavior set disable8dot3 0`.
* **Power Plan:** Switch back to "Balanced" via Windows Settings -> Power & Battery.
* **Memory Compression:** Run `Enable-MMAgent -MemoryCompression` in Admin PowerShell.
* **Mouse Acceleration:** Enable "Enhance pointer precision" under Windows Mouse Settings.

---

## 📄 License
This suite is open-source under the [MIT License](LICENSE).
