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
echo [08] Disabling Hibernation & Fast Startup (Real Shutdowns)
echo ========================================================

echo Disabling Windows Hibernation file (hiberfil.sys)...
powercfg /h off

echo.
echo [DONE] Hibernation disabled. Several gigabytes of SSD space freed.
echo        Fast Startup memory leaks and driver state corruption prevented.
echo.
if /i "%~1" neq "/nopause" pause
