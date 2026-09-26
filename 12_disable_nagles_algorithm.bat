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
echo [12] Disabling Nagle's Algorithm (TCPNoDelay & TcpAckFrequency)
echo ========================================================

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' -ErrorAction SilentlyContinue | ForEach-Object { New-ItemProperty -Path $_.PSPath -Name 'TcpAckFrequency' -PropertyType DWord -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null; New-ItemProperty -Path $_.PSPath -Name 'TCPNoDelay' -PropertyType DWord -Value 1 -Force -ErrorAction SilentlyContinue | Out-Null }"

echo [SUCCESS] Nagle Algorithm disabled on all network interfaces.
echo.
if /i "%~1" neq "/nopause" pause
