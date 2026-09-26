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
echo [07] Disabling Heavy Background Services (SysMain & DiagTrack)
echo ========================================================

echo Stopping and disabling SysMain (SuperFetch)...
sc stop SysMain >nul 2>&1
sc config SysMain start=disabled >nul 2>&1

echo Stopping and disabling DiagTrack (Connected User Experiences)...
sc stop DiagTrack >nul 2>&1
sc config DiagTrack start=disabled >nul 2>&1

echo [SUCCESS] SysMain and DiagTrack services disabled.
echo.
if /i "%~1" neq "/nopause" pause
