@echo off
setlocal EnableExtensions
title win11janitor - background EcoQoS session lab
set "TEMP=%~dp0.workspace\tmp"
set "TMP=%TEMP%"
set "TMPDIR=%TEMP%"
if not exist "%TEMP%" mkdir "%TEMP%" >nul 2>&1
if not exist "%TEMP%" (
    echo [ERROR] Cannot create D: project temporary directory.
    endlocal & exit /b 10
)
if "%~1"=="" (
    echo Usage examples:
    echo   RUN_SESSION_LAB.bat -Action Inspect -ProcessId 1234
    echo   RUN_SESSION_LAB.bat -Action Plan -BackgroundProcessId 1234
    echo Apply requires the saved plan plus -Experimental. See README.md.
    endlocal & exit /b 2
)
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0src\SessionLab.ps1" %*
set "RC=%errorlevel%"
endlocal & exit /b %RC%
