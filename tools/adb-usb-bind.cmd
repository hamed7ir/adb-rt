@echo off
setlocal
echo.
echo === adb-rt : WinUSB interface-GUID BIND (NEEDS "Run as administrator") ===
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0usbbind.ps1" %*
echo.
echo exit code = %ERRORLEVEL%   (0 = ok, 1 = write failed, 2 = cannot run)
echo.
pause
