@echo off
setlocal EnableExtensions
title win11janitor - optional performance capture and analysis
set "TEMP=%~dp0.workspace\tmp"
set "TMP=%TEMP%"
set "TMPDIR=%TEMP%"
if not exist "%TEMP%" mkdir "%TEMP%" >nul 2>&1
if not exist "%TEMP%" (endlocal & exit /b 10)
if "%~1"=="" (
    echo Usage: RUN_PERFORMANCE_LAB.bat -Action Analyze -InputCsv "D:\win11janitor\.workspace\benchmarks\captures\capture.csv"
    echo See README.md for Capture, Compare and hash-pinning requirements.
    endlocal & exit /b 2
)
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0src\PerformanceLab.ps1" %*
set "RC=%errorlevel%"
endlocal & exit /b %RC%
