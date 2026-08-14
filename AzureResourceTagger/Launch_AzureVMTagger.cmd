@echo off
setlocal

set "SCRIPT=%~dp0AzureVMTagger.ps1"

if not exist "%SCRIPT%" (
    echo AzureVMTagger.ps1 was not found next to this launcher.
    pause
    exit /b 1
)

where pwsh.exe >nul 2>&1
if %errorlevel%==0 (
    start "" pwsh.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%SCRIPT%"
    exit /b 0
)

where powershell.exe >nul 2>&1
if %errorlevel%==0 (
    start "" powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%SCRIPT%"
    exit /b 0
)

echo PowerShell was not found.
pause
exit /b 1
