@echo off
setlocal EnableExtensions
title win11janitor - safe, reversible privacy profile
set "TEMP=%~dp0.workspace\tmp"
set "TMP=%TEMP%"
set "TMPDIR=%TEMP%"
if not exist "%TEMP%" mkdir "%TEMP%" >nul 2>&1
if not exist "%TEMP%" (
    echo [ERROR] Cannot create D: workspace temp directory.
    endlocal & exit /b 10
)
echo ==== SAFE PROFILE PREVIEW ====
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0src\Win11Janitor.ps1" -Action Plan -Profile Safe
if errorlevel 1 (
    echo [ERROR] Planning failed. No system settings changed.
    endlocal & exit /b 1
)
choice /C YN /N /M "Apply these reversible privacy settings? [Y/N] "
if errorlevel 3 (
    echo [ERROR] Could not obtain confirmation.
    endlocal & exit /b 1
)
if errorlevel 2 (
    echo Cancelled. No system settings changed.
    endlocal & exit /b 0
)
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0src\Win11Janitor.ps1" -Action Apply -Profile Safe
if errorlevel 1 (
    echo [ERROR] Review the status above and use the printed snapshot path if necessary.
    endlocal & exit /b 1
)
echo [OK] Safe profile applied or already configured. Keep your snapshot for rollback.
endlocal & exit /b 0
