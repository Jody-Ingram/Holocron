<#
Script  :  Azure-Local-Force-Cluster-Deployment.ps1
Version :  1.0
Date    :  4/21/2026
Author  :  Jody Ingram
Purpose :  Deploys Azure Local Cluster using ARM template, with retry logic for common timeout/cancel failure patterns.
#>


 # Import Modules

Import-Module Az.Accounts -ErrorAction Stop
Import-Module Az.Resources -ErrorAction Stop


param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$TemplateFile,

    [Parameter(Mandatory = $true)]
    [string]$TemplateParameterFile,

    [string]$DeploymentName = ("azlocal-" + (Get-Date -Format "yyyyMMdd-HHmmss")),

    [int]$MaxRetries = 3,

    [int]$PollSeconds = 60
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message)
    Write-Host ("[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message)
}

function Test-TimeoutLikeFailure {
    param($Deployment)

    if (-not $Deployment) { return $false }
    if (-not $Deployment.Outputs) { }

    $raw = $Deployment | ConvertTo-Json -Depth 20

    return (
        $raw -match "No Updates were received from the HCI device in the last 60 minutes" -or
        $raw -match "CleanStuckJobInProgress" -or
        $raw -match "CloudDeploy_Deploy Operation cancelled" -or
        $raw -match "DeployClusterOperationFailed"
    )
}

function Get-DeploymentTerminalState {
    param(
        [string]$RgName,
        [string]$Name
    )

    $dep = Get-AzResourceGroupDeployment -ResourceGroupName $RgName -Name $Name -ErrorAction Stop
    return $dep
}

function Start-AzureLocalDeployment {
    param(
        [string]$RgName,
        [string]$Name,
        [string]$TplFile,
        [string]$ParamFile
    )

    Write-Log "Starting deployment '$Name' in resource group '$RgName'..."

    # -AsJob keeps the shell free while ARM deployment runs server-side
    $null = New-AzResourceGroupDeployment `
        -Name $Name `
        -ResourceGroupName $RgName `
        -TemplateFile $TplFile `
        -TemplateParameterFile $ParamFile `
        -Verbose `
        -AsJob

    Write-Log "Deployment submitted."
}

function Wait-AzureLocalDeployment {
    param(
        [string]$RgName,
        [string]$Name,
        [int]$PollIntervalSeconds
    )

    while ($true) {
        Start-Sleep -Seconds $PollIntervalSeconds

        try {
            $dep = Get-DeploymentTerminalState -RgName $RgName -Name $Name
        }
        catch {
            Write-Log "Could not read deployment state. Retrying deployment..."
            continue
        }

        Write-Log ("ProvisioningState = {0}" -f $dep.ProvisioningState)

        switch ($dep.ProvisioningState) {
            "Succeeded" { return $dep }
            "Failed"    { return $dep }
            default     { }
        }
    }
}

function Get-DeploymentFailureDetails {
    param($Deployment)

    try {
        $ops = Get-AzResourceGroupDeploymentOperation `
            -ResourceGroupName $Deployment.ResourceGroupName `
            -DeploymentName $Deployment.DeploymentName `
            -ErrorAction Stop

        return $ops
    }
    catch {
        Write-Log "Unable to retrieve deployment operations."
        return $null
    }
}




Write-Log "Setting Azure context to subscription $SubscriptionId"
Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null

if (-not (Test-Path $TemplateFile)) {
    throw "Template file not found: $TemplateFile"
}

if (-not (Test-Path $TemplateParameterFile)) {
    throw "Template parameter file not found: $TemplateParameterFile"
}

$attempt = 1
$lastFailure = $null

while ($attempt -le $MaxRetries) {
    $currentDeploymentName = "{0}-try{1}" -f $DeploymentName, $attempt

    Write-Log "=== Attempt $attempt of $MaxRetries ==="

    Start-AzureLocalDeployment `
        -RgName $ResourceGroupName `
        -Name $currentDeploymentName `
        -TplFile $TemplateFile `
        -ParamFile $TemplateParameterFile

    $result = Wait-AzureLocalDeployment `
        -RgName $ResourceGroupName `
        -Name $currentDeploymentName `
        -PollIntervalSeconds $PollSeconds

    if ($result.ProvisioningState -eq "Succeeded") {
        Write-Log "Deployment succeeded on attempt $attempt."
        $result
        exit 0
    }

    Write-Log "Deployment failed on attempt $attempt."
    $lastFailure = $result

    $ops = Get-DeploymentFailureDetails -Deployment $result
    if ($ops) {
        Write-Log "Recent deployment operation details:"
        $ops |
            Select-Object OperationId, ProvisioningState, Timestamp, TargetResource, StatusCode, StatusMessage |
            Format-List
    }

    $timeoutLike = Test-TimeoutLikeFailure -Deployment $result
    if ($timeoutLike -and $attempt -lt $MaxRetries) {
        Write-Log "Detected timeout/cancel pattern. Waiting 5 minutes before retry..."
        Start-Sleep -Seconds 300
        $attempt++
        continue
    }

    Write-Log "Failure was not recognized as auto-retryable, or max retries reached."
    break
}

Write-Error "Deployment did not succeed after $attempt attempt(s)."
if ($lastFailure) {
    $lastFailure | Format-List *
}
exit 1
