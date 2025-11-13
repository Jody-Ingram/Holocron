<#
Script  :  Windows-Temp-Public-DNS.ps1
Version :  1.0
Date    :  11/13/2025
Author: Jody Ingram
Pre-reqs: PowerShell
Notes: This script temporarily changes the DNS servers on a Windows machine to public DNS resolvers. This is useful for accessing Azure public endpoints when internal DNS is blocking them. The script automatically reverts the DNS settings after a specified timeout or when the user indicates they are done.
#>

param(
  [string[]]$ResolverIPs = @('1.1.1.1'),
  [int]$TimeoutMinutes = 30,
  [string]$AdapterName
)

# --- Admin check ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Host "❌ Run this PowerShell as Administrator." -ForegroundColor Red
  exit 1
}

# --- Pick adapter ---
if (-not $AdapterName) {
  $AdapterName = (Get-NetAdapter | Where-Object Status -eq Up | Select-Object -ExpandProperty Name -First 1)
}
if (-not $AdapterName) { Write-Host "❌ No active adapter found." -ForegroundColor Red; exit 1 }

Write-Host "✅ Using adapter: $AdapterName" -ForegroundColor Green

# --- Paths & names ---
$root = 'C:\ProgramData\TempPublicDNS'
$null = New-Item -ItemType Directory -Path $root -Force -ErrorAction SilentlyContinue
$stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$stateFile = Join-Path $root "state-$($AdapterName)-$stamp.json"
$revertScript = Join-Path $root "Revert-DNS.ps1"
$taskName = "TempPublicDNS-Revert-$($AdapterName)"

# --- Capture current DNS (IPv4) ---
$current = Get-DnsClientServerAddress -InterfaceAlias $AdapterName -AddressFamily IPv4 -ErrorAction Stop
$original = [PSCustomObject]@{
  AdapterName = $AdapterName
  OriginalServers = $current.ServerAddresses
  CreatedAt = (Get-Date).ToString("o")
  TaskName = $taskName
}
$original | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8

Write-Host "📄 Saved original DNS: $($original.OriginalServers -join ', ')" -ForegroundColor Yellow

# --- Write the revert script (self-deleting & task-cleaning) ---
@"
param(
  [string]\$StateFile,
  [string]\$TaskName
)
try {
  if (-not (Test-Path \$StateFile)) { throw "State file not found: \$StateFile" }
  \$state = Get-Content \$StateFile -Raw | ConvertFrom-Json
  \$adapter = \$state.AdapterName
  \$orig = \$state.OriginalServers

  if (\$orig -and \$orig.Count -gt 0) {
    Set-DnsClientServerAddress -InterfaceAlias \$adapter -ServerAddresses \$orig -ErrorAction Stop
  } else {
    Set-DnsClientServerAddress -InterfaceAlias \$adapter -ResetServerAddresses -ErrorAction Stop
  }

  ipconfig /flushdns | Out-Null

  # Remove the scheduled task (if present)
  try { Unregister-ScheduledTask -TaskName \$TaskName -Confirm:\$false -ErrorAction SilentlyContinue } catch {}

  # Remove state file
  Remove-Item -Path \$StateFile -Force -ErrorAction SilentlyContinue

} catch {
  # Best-effort cleanup; write an event for visibility
  Write-EventLog -LogName Application -Source "PowerShell" -EntryType Warning -EventId 5000 -Message ("Revert-DNS failed: " + \$_)
} finally {
  # If multiple state files accumulate, that's okay; each run cleans its own
}
"@ | Set-Content -Path $revertScript -Encoding UTF8

# --- Set temporary DNS ---
Write-Host "🕓 Applying temporary DNS: $($ResolverIPs -join ', ')" -ForegroundColor Cyan
Set-DnsClientServerAddress -InterfaceAlias $AdapterName -ServerAddresses $ResolverIPs -ErrorAction Stop
ipconfig /flushdns | Out-Null
Write-Host "✅ Temporary DNS applied." -ForegroundColor Green

# --- Create Scheduled Task to auto-revert ---
$runTime = (Get-Date).AddMinutes($TimeoutMinutes)
$action  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$revertScript`" -StateFile `"$stateFile`" -TaskName `"$taskName`""
$trigger = New-ScheduledTaskTrigger -Once -At $runTime
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -Compatibility Win8

# If a previous task exists, clean it
try { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue } catch {}

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings | Out-Null

Write-Host "⏱️  Auto-revert scheduled at $($runTime.ToString('yyyy-MM-dd HH:mm')) (Task: $taskName)" -ForegroundColor Yellow

# --- Also hook PowerShell exit to revert (best-effort if user closes window nicely) ---
$script:reverted = $false
$revert = {
  if (-not $script:reverted) {
    try {
      & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $using:revertScript -StateFile $using:stateFile -TaskName $using:taskName
      $script:reverted = $true
    } catch {}
  }
}
Register-EngineEvent PowerShell.Exiting -Action $revert | Out-Null

# --- User workflow ---
Write-Host ""
Write-Host "🌐 You can now access Azure public endpoints (DNS bypass in effect)." -ForegroundColor Cyan
Write-Host "👉 Press ENTER when finished to restore original DNS immediately (otherwise it auto-reverts at the scheduled time)." -ForegroundColor Cyan
Read-Host | Out-Null

# --- Immediate revert & cleanup ---
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $revertScript -StateFile $stateFile -TaskName $taskName
Write-Host "🎉 DNS restored and safety task cleaned up." -ForegroundColor Green
