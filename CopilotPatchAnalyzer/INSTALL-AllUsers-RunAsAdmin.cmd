@echo off
setlocal
echo This should be run as Administrator.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-PatchAnalysisReporter.ps1" -AllUsers
echo.
pause