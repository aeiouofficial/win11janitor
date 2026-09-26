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
echo [03] Disabling Bing Web Search in Start Menu
echo ========================================================

reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v "DisableSearchBoxSuggestions" /t REG_DWORD /d 1 /f >nul

echo [SUCCESS] Start Menu Bing search suggestions disabled.
echo.
if /i "%~1" neq "/nopause" pause
