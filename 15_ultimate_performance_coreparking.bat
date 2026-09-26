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
echo [15] Ultimate Performance Power Plan & Core Unparking
echo ========================================================

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$res = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1; $guid = ($res -split ' ')[3]; if ($guid) { powercfg -setactive $guid } else { powercfg -setactive scheme_min }"
powercfg -setacvalueindex scheme_current sub_processor CPMINCORES 100
powercfg -setactive scheme_current

echo [SUCCESS] Ultimate Performance power scheme active & Core Parking disabled.
echo.
if /i "%~1" neq "/nopause" pause
