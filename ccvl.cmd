@echo off
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0ccvl.ps1" %*
exit /b %ERRORLEVEL%
