@echo off
setlocal
echo.
echo === adb-rt : WinUSB interface-GUID CHECK (read only, no admin needed) ===
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0usbreg.ps1" %*
echo.
echo exit code = %ERRORLEVEL%   (0 = nothing blocked, 1 = blocked, 2 = could not read)
echo.
pause
