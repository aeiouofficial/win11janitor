@echo off
setlocal EnableDelayedExpansion

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Administrator privileges required.
    echo Right-click this script and select "Run as administrator".
    echo.
    if /i "%~1" neq "/nopause" pause
    exit /b 1
)

echo ========================================================
echo [01] Disabling Windows Telemetry & Diagnostic Data
echo ========================================================

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v "AllowTelemetry" /t REG_DWORD /d 0 /f >nul
if %errorlevel% equ 0 (
    echo [SUCCESS] AllowTelemetry set to 0 ^(Security/Disabled^).
) else (
    echo [FAILED] Unable to set AllowTelemetry registry key.
)

echo.
if /i "%~1" neq "/nopause" pause
