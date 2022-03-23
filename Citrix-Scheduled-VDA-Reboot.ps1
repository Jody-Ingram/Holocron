<#
Script  :  Citrix-Scheduled-VDA-Reboot.ps1
Version :  1.0
Date    :  3/23/2022
Author: Jody Ingram
Notes: This script is used to reboot Citrix PVS VDA servers. It will put them into Maintenance Mode, notify the end users, reboot and take them out of Maintenance Mode. 
Launcher Code: -ExecutionPolicy bypass -File C:\Scripting\Citrix-Scheduled-VDA-Reboot.ps1 -AdGroup AD-REBOOT-GROUP
#>

Param(
	
	[String]$ADGroup) # Defines the AD Group that will send the reboot request to.
	
# Imports Citrix and AD Snap-In Modules for PowerShell.
Add-PSSnapin Citrix*
Import-Module active*

# Pulls computer objects from AD group and drops them into a server list that the script reads.

$VDAList = Get-ADGroupMember $ADGroup | Select-Object -ExpandProperty Name
$ServerList = @()

# Verifies the Power State of the VMs. If they are not "On", the script skips them. 

ForEach($server in $VDAList)
{
	$OnlineCheck = Get-BrokerMachine -HostedMachineName $server | Select-Object -ExpandProperty PowerState
	
	If($OnlineCheck = "On") {$ServerList += $server}
}

# Enables Maintenance Mode for servers in list
foreach($server in $ServerList) {Set-BrokerMachine -MachineName Whs\$server -InMaintenanceMode 1}


# Sends Citrix Pop-Up message to user sessions that the server will be rebooted in 60 minutes.

foreach($server in $ServerList)
{
	$msg = "This Citrix Server will be rebooted in 60 minutes. Please save your work, log off, and relaunch your application to grab a new session on a different server. Thank you!"
	$users = Get-BrokerSession -hostedmachinename $server
	
	If($users -ne $null){Send-BrokerSessionMessage $users -MessageStyle Information -Title "Reboot Warning" -Text $msg}							
}

Start-Sleep -Seconds 1800

# Sends Citrix Pop-Up message to user sessions that the server will be rebooted in 30 minutes.
foreach($server in $ServerList)
{
	$msg = "This Citrix Server will be rebooted in 30 minutes. Please save your work, log off, and relaunch your application to grab a new session on a different server. Thank you!"
	$users = Get-BrokerSession -hostedmachinename $server
	
	If($users -ne $null){Send-BrokerSessionMessage $users -MessageStyle Information -Title "Reboot Warning" -Text $msg}				
}

Start-Sleep -Seconds 1500

# Sends Citrix Pop-Up message to user sessions that the server will be rebooted in 5 minutes.
foreach($server in $ServerList)
{
	$msg = "This Citrix Server will be rebooted in 5 minutes. Please save your work, log off, and relaunch your application to grab a new session on a different server. Thank you!"
	$users = Get-BrokerSession -hostedmachinename $server
	
	If($users -ne $null){Send-BrokerSessionMessage $users -MessageStyle Information -Title "Reboot Warning" -Text $msg}								
}

Start-Sleep -Seconds 240

# Sends Citrix Pop-Up message to user sessions that the server will be rebooted in 1 minute1.
foreach($server in $ServerList)
{
	$msg = "This Citrix Server will be rebooted in 1 minute. Please save your work, log off, and relaunch your application to grab a new session on a different server. Thank you!"
	$users = Get-BrokerSession -hostedmachinename $server
	
	If($users -ne $null){Send-BrokerSessionMessage $users -MessageStyle Information -Title "Reboot Warning" -Text $msg}								
}

Start-Sleep -Seconds 60

# Force logs user sessions off of the servers.
foreach($server in $ServerList)
{
	Get-BrokerSession -hostedmachinename $server | Stop-BrokerSession
	Start-Sleep -Seconds 10
}

Start-Sleep -Seconds 300

# This starts the server reboot process.

foreach($server in $ServerList)
{
	New-BrokerHostingPowerAction -Action 'Restart' -MachineName $server
	Set-BrokerMachine -MachineName whs\$server -InMaintenanceMode 0 # Disables Maintenance Mode on servers
	
	Start-Sleep -Seconds 30
}
