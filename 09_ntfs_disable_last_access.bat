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
echo [09] Disabling NTFS Last Access Timestamp Writes
echo ========================================================

echo Setting NTFS behavior: disablelastaccess 1...
fsutil behavior set disablelastaccess 1

echo.
echo [DONE] Unnecessary disk write overhead on file read eliminated.
echo.
if /i "%~1" neq "/nopause" pause
