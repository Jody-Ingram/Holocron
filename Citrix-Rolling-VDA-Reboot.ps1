<#
Script  :  Citrix-Rolling-VDA-Reboot.ps1
Version :  CURRENTLY IN DEVELOPMENT
Date    :  2/8/2022
Author: Jody Ingram
Notes: This script will put Citrix VDAs into Maintenance Mode, query for user sessions and once cleared off, it will reboot and put them back into production.
#>

asnp Citrix*
# Server uptime in hours. Adjust as needed. To be called later for exclusions purposes. 
$ServerUptime = 72

# Define the threshold for how many VDAs can be down at once. Adjust as needed. Number is a percent. 
$MaxServersDown = 30

# Citrix Delivery Controllers. ADJUST PER CITRIX FARM!
# Note: I will eventually add all delivery controllers here as seperate variables as I adjust this script.
$DDCServer = "svdc1ctxddc1001.whs.int" # Epic DC1 Farm

# Get Citrix Delivery Groups

foreach ($group in Get-DDCServerDesktopGroup -AdminAddress $DDCServer -Tag AutoReboot)
{
    write-host $group.Name
	
	$total = (Get-DDCServerMachine -DesktopGroupName $group.Name -AdminAddress $DDCServer| measure-object).Count
    write-host "`t" $total hosts found
	$allowedDown = [Math]::Ceiling($total * $MaxServersDown / 100)
    write-host "`t" $allowedDown hosts allowed down
	$down = 0;
	$down += (Get-DDCServerMachine -DesktopGroupName $group.Name -RegistrationState Unregistered -AdminAddress $DDCServer| measure-object).Count
	$down += (Get-DDCServerMachine -DesktopGroupName $group.Name -RegistrationState AgentError -AdminAddress $DDCServer| measure-object).Count
	$down += (Get-DDCServerMachine -DesktopGroupName $group.Name -InMaintenanceMode $true -AdminAddress $DDCServer| measure-object).Count
	write-host "`t" $down hosts are down

	# Checks the Maintenance Mode status of machines currently running.

	foreach ($vm in Get-DDCServerMachine -DesktopGroupName $group.Name -InMaintenanceMode $true -AdminAddress $DDCServer)
	{
        write-host "`t" $vm.MachineName "Maintenance Mode:" $vm.AssociatedUserNames.Count Users - Pending Reboot
		if ($vm.AssociatedUserNames.Count -eq 0)
		{
			New-DDCServerHostingPowerAction -MachineName $vm.MachineName -Action Restart -AdminAddress $DDCServer
			write-host Reboot $vm.MachineName
			Set-DDCServerMachineMaintenanceMode -InputObject $vm.MachineName -MaintenanceMode $false -AdminAddress $DDCServer
			write-host Disable MaintenanceMode $vm.MachineName
		}
	}
	if ($down -lt $allowedDown)
	{
		$vmsToGet = $allowedDown - $down
        $vmsWithUptime = @{};
        write-host "`t" need $vmsToGet more hosts down
		foreach ($vm in Get-DDCServerMachine -DesktopGroupName $group.Name -RegistrationState Registered -InMaintenanceMode $false)
	    {
            try { 
                $wmi=Get-WmiObject -class Win32_OperatingSystem -computer $vm.IPAddress
                $LBTime=$wmi.ConvertToDateTime($wmi.Lastbootuptime)
                [TimeSpan]$uptime=New-TimeSpan $LBTime $(get-date)
                $vmsWithUptime.Add($vm.MachineName,$uptime)
                write-host "`t`t" $vm.MachineName $uptime.TotalHours Hours
            }
            catch {  
               
            }
        }
        foreach ($k in $vmsWithUptime.GetEnumerator() | Where-Object {$_.value.TotalHours -ge $ServerUptime} | sort -Property value.TotalHours -descending | select -first $vmsToGet)
        {
        	$vm = Get-DDCServerMachine -MachineName $k.Name		
			if ($vm.AssociatedUserNames.Count -eq 0)
			{
				New-DDCServerHostingPowerAction -MachineName $vm.MachineName -Action Restart -AdminAddress $DDCServer
				write-host Reboot $vm.MachineName
			}
			else
			{
				Set-DDCServerMachineMaintenanceMode -InputObject $vm.MachineName -MaintenanceMode $true -AdminAddress $DDCServer
				write-host Enable MaintenanceMode $vm.MachineName
			}
		}
	}
}
