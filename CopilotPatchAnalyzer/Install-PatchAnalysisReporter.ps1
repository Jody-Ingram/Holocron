param(
    [switch]$AllUsers,
    [switch]$NoDesktopShortcut,
    [switch]$NoStartMenuShortcut
)

$ErrorActionPreference = "Stop"

$AppName = "Patch Analysis Reporter"
$SafeName = "PatchAnalysisReporter"

$InstallRoot = if ($AllUsers) {
    Join-Path $env:ProgramData $SafeName
} else {
    Join-Path $env:LOCALAPPDATA $SafeName
}

New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null

$SourceLauncher = Join-Path $PSScriptRoot "Launch-PatchAnalysisReporter.ps1"
$SourceIcon = Join-Path $PSScriptRoot "PatchAnalysisReporter.ico"

$LauncherPath = Join-Path $InstallRoot "Launch-PatchAnalysisReporter.ps1"
$IconPath = Join-Path $InstallRoot "PatchAnalysisReporter.ico"

Copy-Item -Path $SourceLauncher -Destination $LauncherPath -Force
Copy-Item -Path $SourceIcon -Destination $IconPath -Force

$PowerShellPath = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"

function New-AppShortcut {
    param(
        [string]$ShortcutPath
    )

    $Shell = New-Object -ComObject WScript.Shell
    $Shortcut = $Shell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $PowerShellPath
    $Shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$LauncherPath`""
    $Shortcut.WorkingDirectory = $InstallRoot
    $Shortcut.IconLocation = "$IconPath,0"
    $Shortcut.Description = "Launch Patch Analysis Reporter"
    $Shortcut.Save()
}

if (-not $NoDesktopShortcut) {
    $DesktopPath = if ($AllUsers) {
        [Environment]::GetFolderPath("CommonDesktopDirectory")
    } else {
        [Environment]::GetFolderPath("Desktop")
    }

    New-AppShortcut -ShortcutPath (Join-Path $DesktopPath "$AppName.lnk")
}

if (-not $NoStartMenuShortcut) {
    $StartMenuPath = if ($AllUsers) {
        Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs"
    } else {
        Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
    }

    New-AppShortcut -ShortcutPath (Join-Path $StartMenuPath "$AppName.lnk")
}

Write-Host ""
Write-Host "Installed $AppName."
Write-Host "Install path: $InstallRoot"
Write-Host ""
Write-Host "Usage:"
Write-Host "1. Select or open an Outlook email."
Write-Host "2. Click the Patch Analysis Reporter shortcut."
Write-Host "3. The email prompt is copied to clipboard, Notepad opens as backup, and Copilot launches."