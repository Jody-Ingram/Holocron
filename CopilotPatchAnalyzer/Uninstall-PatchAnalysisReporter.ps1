param(
    [switch]$AllUsers
)

$AppName = "Patch Analysis Reporter"
$SafeName = "PatchAnalysisReporter"

$InstallRoot = if ($AllUsers) {
    Join-Path $env:ProgramData $SafeName
} else {
    Join-Path $env:LOCALAPPDATA $SafeName
}

$DesktopPath = if ($AllUsers) {
    [Environment]::GetFolderPath("CommonDesktopDirectory")
} else {
    [Environment]::GetFolderPath("Desktop")
}

$StartMenuPath = if ($AllUsers) {
    Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs"
} else {
    Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
}

Remove-Item -Path (Join-Path $DesktopPath "$AppName.lnk") -Force -ErrorAction SilentlyContinue
Remove-Item -Path (Join-Path $StartMenuPath "$AppName.lnk") -Force -ErrorAction SilentlyContinue
Remove-Item -Path $InstallRoot -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Removed $AppName."