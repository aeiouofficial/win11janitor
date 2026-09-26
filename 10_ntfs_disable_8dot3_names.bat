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
echo [10] Disabling NTFS 8.3 Short Filename Creation
echo ========================================================

echo Setting NTFS behavior: disable8dot3 1...
fsutil behavior set disable8dot3 1

echo.
echo [DONE] Legacy 8.3 filename generation disabled across all volumes.
echo        Significantly accelerates file lookups in large directories.
echo.
if /i "%~1" neq "/nopause" pause
