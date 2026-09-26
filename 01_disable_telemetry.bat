@echo off
setlocal EnableExtensions
rem Compatibility entrypoint; never executes direct registry/service/network tweaks.
set "TEMP=%~dp0.workspace\tmp"
set "TMP=%TEMP%"
set "TMPDIR=%TEMP%"
if not exist "%TEMP%" mkdir "%TEMP%" >nul 2>&1
if not exist "%TEMP%" (
    echo [ERROR] Cannot create D: workspace temp directory.
    endlocal & exit /b 10
)
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0src\Win11Janitor.ps1" -Action Apply -Module 01 %*
set "RESULT=%ERRORLEVEL%"
endlocal & exit /b %RESULT%
