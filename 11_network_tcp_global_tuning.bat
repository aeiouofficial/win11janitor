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
echo [11] Low-Latency TCP/IP Stack Parameters Tuning
echo ========================================================

echo Applying netsh TCP stack configuration...
netsh int tcp set global autotuninglevel=normal
netsh int tcp set global rss=enabled
netsh int tcp set global rsc=disabled
netsh int tcp set global ecncapability=disabled
netsh int tcp set global timestamps=disabled

echo.
echo [DONE] Receive Segment Coalescing (RSC) disabled to eliminate packet jitter.
echo        Receive-Side Scaling (RSS) enabled for multi-core packet distribution.
echo.
if /i "%~1" neq "/nopause" pause
