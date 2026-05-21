@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-PatchAnalysisReporter.ps1"
echo.
pause