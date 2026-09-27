@echo off
setlocal EnableExtensions
title win11janitor - read-only hardware and startup diagnostics
set "TEMP=%~dp0.workspace\tmp"
set "TMP=%TEMP%"
set "TMPDIR=%TEMP%"
if not exist "%TEMP%" mkdir "%TEMP%" >nul 2>&1
if not exist "%TEMP%" (
    echo [ERROR] Cannot create D: project temporary directory.
    endlocal & exit /b 10
)
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0src\Diagnostics.ps1" -Category All -Save %*
set "RC=%errorlevel%"
if not "%RC%"=="0" echo [WARNING] Diagnostics did not fully complete. Exit code %RC%.
endlocal & exit /b %RC%
