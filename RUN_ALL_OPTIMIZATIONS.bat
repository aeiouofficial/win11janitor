@echo off
setlocal EnableDelayedExpansion
title Windows 11 Clean & Atlas OS 16-Module Optimization Suite

:: ---------------------------------------------------------------------
:: Administrator Check
:: ---------------------------------------------------------------------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo ====================================================================
    echo [ERROR] ADMINISTRATOR PRIVILEGES REQUIRED
    echo ====================================================================
    echo This suite modifies system registry, power plans, and system services.
    echo Please right-click 'RUN_ALL_OPTIMIZATIONS.bat' and select:
    echo        "Run as administrator"
    echo ====================================================================
    echo.
    pause
    exit /b 1
)

cls
echo ====================================================================
echo        WINDOWS 11 CLEAN ^& ATLAS OS 16-MODULE OPTIMIZATION SUITE
echo ====================================================================
echo  This suite executes all 16 discrete performance and privacy modules:
echo    [01] Diagnostic Telemetry & Data Collection
echo    [02] Activity History & Timeline Tracking
echo    [03] Bing Web Search in Start Menu
echo    [04] Tailored Experiences & App Launch Tracking
echo    [05] Multimedia Scheduler & System Responsiveness
echo    [06] Xbox Game DVR Micro-stutter Elimination
echo    [07] Background Services (SysMain & DiagTrack)
echo    [08] Hibernation & Fast Startup (Real Clean Shutdowns)
echo    [09] NTFS Last Access Timestamp Writes
echo    [10] NTFS 8.3 Short Filename Creation
echo    [11] Low-Latency TCP/IP Stack Parameters
echo    [12] Nagle's Algorithm (TCPNoDelay & TcpAckFrequency)
echo    [13] Telemetry Scheduled Tasks
echo    [14] ETW Kernel AutoLoggers
echo    [15] Ultimate Performance Power Plan & Core Unparking
echo    [16] Memory Architecture, Raw Input & DWM Compositing
echo ====================================================================
echo.
echo Press any key to start all 16 optimizations...
pause >nul

set "SCRIPT_DIR=%~dp0"

echo.
echo [*] Executing Module 01: Diagnostic Telemetry...
call "%SCRIPT_DIR%01_disable_telemetry.bat" /nopause

echo.
echo [*] Executing Module 02: Activity History...
call "%SCRIPT_DIR%02_disable_activity_history.bat" /nopause

echo.
echo [*] Executing Module 03: Bing Web Search in Start Menu...
call "%SCRIPT_DIR%03_disable_bing_start_search.bat" /nopause

echo.
echo [*] Executing Module 04: Tailored Experiences & App Tracking...
call "%SCRIPT_DIR%04_disable_tailored_experiences.bat" /nopause

echo.
echo [*] Executing Module 05: Multimedia Scheduler Profile...
call "%SCRIPT_DIR%05_multimedia_system_profile.bat" /nopause

echo.
echo [*] Executing Module 06: Xbox Game DVR Elimination...
call "%SCRIPT_DIR%06_disable_game_dvr.bat" /nopause

echo.
echo [*] Executing Module 07: Background Services (SysMain & DiagTrack)...
call "%SCRIPT_DIR%07_disable_background_services.bat" /nopause

echo.
echo [*] Executing Module 08: Hibernation & Fast Startup...
call "%SCRIPT_DIR%08_disable_hibernation_faststartup.bat" /nopause

echo.
echo [*] Executing Module 09: NTFS Last Access Writes...
call "%SCRIPT_DIR%09_ntfs_disable_last_access.bat" /nopause

echo.
echo [*] Executing Module 10: NTFS 8.3 Filename Creation...
call "%SCRIPT_DIR%10_ntfs_disable_8dot3_names.bat" /nopause

echo.
echo [*] Executing Module 11: Low-Latency TCP/IP Stack...
call "%SCRIPT_DIR%11_network_tcp_global_tuning.bat" /nopause

echo.
echo [*] Executing Module 12: Nagle's Algorithm...
call "%SCRIPT_DIR%12_disable_nagles_algorithm.bat" /nopause

echo.
echo [*] Executing Module 13: Telemetry Scheduled Tasks...
call "%SCRIPT_DIR%13_disable_telemetry_tasks.bat" /nopause

echo.
echo [*] Executing Module 14: ETW Kernel AutoLoggers...
call "%SCRIPT_DIR%14_disable_etw_autologgers.bat" /nopause

echo.
echo [*] Executing Module 15: Ultimate Performance & Core Unparking...
call "%SCRIPT_DIR%15_ultimate_performance_coreparking.bat" /nopause

echo.
echo [*] Executing Module 16: Memory Architecture, Raw Input & DWM...
call "%SCRIPT_DIR%16_memory_management_and_raw_input.bat" /nopause

echo.
echo ====================================================================
echo  ALL 16 OPTIMIZATION MODULES COMPLETED SUCCESSFULLY!
echo ====================================================================
echo  A system reboot is required for all kernel, networking, and
echo  registry changes to take full effect.
echo ====================================================================
echo.
set /p REBOOT="Would you like to restart your computer now? (Y/N): "
if /i "!REBOOT!"=="Y" (
    echo Restarting computer in 5 seconds...
    shutdown /r /t 5
) else (
    echo Please restart your computer manually when convenient.
    pause
)
