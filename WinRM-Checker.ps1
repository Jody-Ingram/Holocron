<#
Script  :  WinRM-Checker.ps1
Version :  1.0
Date    :  8/22/22
Author: Jody Ingram
Notes: Checks a list of servers to validate if Win-RM is actively running and if port 5895 is listening.
#>

# Imports the list of Azure VMs
$ServerList = Import-CSV -Path .\AzureVMList.csv

# Validates if the WinRM service is currently running; Exports to CSV. 
Test-WSMan -ComputerName "$ServerList" -Authentication Default | export-csv "C:\Tools\Test-WSMan-COMPLETE.csv"

# Validates if port 5895 is currently listening; Exports to CSV. 
Telnet $ServerList 5895 | export-csv "C:\Tools\TelnetCheck.csv"