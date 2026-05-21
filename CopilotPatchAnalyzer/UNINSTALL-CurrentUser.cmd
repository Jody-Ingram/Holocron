@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-PatchAnalysisReporter.ps1"
echo.
pause