#requires -Version 5.1
<#
Azure VM Standard Tagger
- Reads target VMs from: C:\Tools\Azure_Resource_Tagger\AzureVMs.csv
- Expected CSV columns: NAME, SUBSCRIPTION, RESOURCE GROUP
- Adds ONLY missing standard tags.
- Does NOT delete tags.
- Does NOT overwrite an existing tag value.
- Creates a CSV results log under C:\Tools\Azure_Resource_Tagger\Logs
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$CsvPath = 'C:\Tools\Azure_Resource_Tagger\AzureVMs.csv'
$LogFolder = 'C:\Tools\Azure_Resource_Tagger\Logs'
$RequiredColumns = @('NAME', 'SUBSCRIPTION', 'RESOURCE GROUP')

$StandardTags = @(
    [pscustomobject]@{ Name = 'Application';       Example = 'APPLICATION NAME' }
    [pscustomobject]@{ Name = 'Application Group'; Example = 'APP SUPPORT GROUP' }
    [pscustomobject]@{ Name = 'Application Tier';  Example = 'Tier 4' }
    [pscustomobject]@{ Name = 'Business Unit';     Example = 'IT' }
    [pscustomobject]@{ Name = 'Contact Group';     Example = 'az-alerts-appSupport' }
    [pscustomobject]@{ Name = 'Environment';       Example = 'Dev' }
    [pscustomobject]@{ Name = 'LOA Level';         Example = 'LOA4' }
    [pscustomobject]@{ Name = 'Owner';             Example = 'user@domain.org' }
    [pscustomobject]@{ Name = 'Patch Week';        Example = 'Patch Week 1' }
    [pscustomobject]@{ Name = 'Role';              Example = 'Virtual Machine' }
)

if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    throw 'This GUI script is intended for Windows.'
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

function Show-Error {
    param([string]$Message, [string]$Title = 'Azure VM Standard Tagger')
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}

function Show-Info {
    param([string]$Message, [string]$Title = 'Azure VM Standard Tagger')
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
}

function Ensure-AzModules {
    $requiredModules = @('Az.Accounts', 'Az.Resources')
    $missingModules = @()

    foreach ($moduleName in $requiredModules) {
        if (-not (Get-Module -ListAvailable -Name $moduleName)) {
            $missingModules += $moduleName
        }
    }

    if ($missingModules.Count -gt 0) {
        $message = @"
The following Azure PowerShell modules are missing:

$($missingModules -join ', ')

Install them now for the current user?
"@
        $answer = [System.Windows.Forms.MessageBox]::Show(
            $message,
            'Azure PowerShell modules required',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
            throw "Required Azure PowerShell modules are not installed: $($missingModules -join ', ')"
        }

        foreach ($moduleName in $missingModules) {
            Install-Module -Name $moduleName -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
        }
    }

    Import-Module Az.Accounts -ErrorAction Stop
    Import-Module Az.Resources -ErrorAction Stop
}

function Ensure-AzureConnection {
    $context = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $context -or -not $context.Account) {
        Connect-AzAccount -ErrorAction Stop | Out-Null
    }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Azure VM Standard Tagger'
$form.Size = New-Object System.Drawing.Size(1040, 830)
$form.StartPosition = 'CenterScreen'
$form.MinimumSize = New-Object System.Drawing.Size(1040, 830)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)
$form.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = 'Azure VM Standard Tagger'
$titleLabel.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 18)
$titleLabel.AutoSize = $true
$titleLabel.Location = New-Object System.Drawing.Point(20, 14)
$form.Controls.Add($titleLabel)

$subTitleLabel = New-Object System.Windows.Forms.Label
$subTitleLabel.Text = 'Adds only missing standard tags. Existing tags and existing tag values are preserved.'
$subTitleLabel.AutoSize = $true
$subTitleLabel.ForeColor = [System.Drawing.Color]::DimGray
$subTitleLabel.Location = New-Object System.Drawing.Point(23, 49)
$form.Controls.Add($subTitleLabel)

# Target VM group
$targetGroup = New-Object System.Windows.Forms.GroupBox
$targetGroup.Text = 'Target VMs'
$targetGroup.Location = New-Object System.Drawing.Point(20, 78)
$targetGroup.Size = New-Object System.Drawing.Size(985, 245)
$form.Controls.Add($targetGroup)

$csvCaption = New-Object System.Windows.Forms.Label
$csvCaption.Text = 'CSV:'
$csvCaption.AutoSize = $true
$csvCaption.Location = New-Object System.Drawing.Point(15, 28)
$targetGroup.Controls.Add($csvCaption)

$csvPathText = New-Object System.Windows.Forms.TextBox
$csvPathText.Text = $CsvPath
$csvPathText.ReadOnly = $true
$csvPathText.Location = New-Object System.Drawing.Point(55, 24)
$csvPathText.Size = New-Object System.Drawing.Size(700, 25)
$targetGroup.Controls.Add($csvPathText)

$reloadButton = New-Object System.Windows.Forms.Button
$reloadButton.Text = 'Reload CSV'
$reloadButton.Location = New-Object System.Drawing.Point(770, 22)
$reloadButton.Size = New-Object System.Drawing.Size(95, 28)
$targetGroup.Controls.Add($reloadButton)

$csvStatusLabel = New-Object System.Windows.Forms.Label
$csvStatusLabel.Text = 'Not loaded'
$csvStatusLabel.AutoSize = $true
$csvStatusLabel.Location = New-Object System.Drawing.Point(15, 59)
$csvStatusLabel.ForeColor = [System.Drawing.Color]::DimGray
$targetGroup.Controls.Add($csvStatusLabel)

$vmList = New-Object System.Windows.Forms.ListView
$vmList.View = [System.Windows.Forms.View]::Details
$vmList.FullRowSelect = $true
$vmList.GridLines = $true
$vmList.Location = New-Object System.Drawing.Point(15, 84)
$vmList.Size = New-Object System.Drawing.Size(950, 145)
[void]$vmList.Columns.Add('VM Name', 260)
[void]$vmList.Columns.Add('Subscription', 260)
[void]$vmList.Columns.Add('Resource Group', 390)
$targetGroup.Controls.Add($vmList)

# Standard tag group
$tagGroup = New-Object System.Windows.Forms.GroupBox
$tagGroup.Text = 'Standard Tag Values'
$tagGroup.Location = New-Object System.Drawing.Point(20, 333)
$tagGroup.Size = New-Object System.Drawing.Size(985, 275)
$form.Controls.Add($tagGroup)

$tagTextBoxes = @{}
$leftX = 18
$rightX = 500
$labelWidth = 135
$textWidth = 315
$startY = 28
$rowHeight = 45

for ($i = 0; $i -lt $StandardTags.Count; $i++) {
    $tag = $StandardTags[$i]
    if ($i -lt 5) {
        $x = $leftX
        $y = $startY + ($i * $rowHeight)
    } else {
        $x = $rightX
        $y = $startY + (($i - 5) * $rowHeight)
    }

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $tag.Name
    $label.Location = New-Object System.Drawing.Point($x, ($y + 4))
    $label.Size = New-Object System.Drawing.Size($labelWidth, 22)
    $tagGroup.Controls.Add($label)

    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point(($x + $labelWidth), $y)
    $textBox.Size = New-Object System.Drawing.Size($textWidth, 25)
    $textBox.Tag = $tag.Example
    $tagGroup.Controls.Add($textBox)
    $tagTextBoxes[$tag.Name] = $textBox

    $exampleLabel = New-Object System.Windows.Forms.Label
    $exampleLabel.Text = "Example: $($tag.Example)"
    $exampleLabel.ForeColor = [System.Drawing.Color]::Gray
    $exampleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 7.5)
    $exampleLabel.Location = New-Object System.Drawing.Point(($x + $labelWidth), ($y + 25))
    $exampleLabel.Size = New-Object System.Drawing.Size($textWidth, 17)
    $tagGroup.Controls.Add($exampleLabel)
}

$warningLabel = New-Object System.Windows.Forms.Label
$warningLabel.Text = 'All 10 values are required. A tag already present on a VM is skipped, even if its current value differs.'
$warningLabel.AutoSize = $true
$warningLabel.ForeColor = [System.Drawing.Color]::DarkSlateGray
$warningLabel.Location = New-Object System.Drawing.Point(20, 620)
$form.Controls.Add($warningLabel)

$applyButton = New-Object System.Windows.Forms.Button
$applyButton.Text = 'Apply Missing Tags'
$applyButton.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 10)
$applyButton.Location = New-Object System.Drawing.Point(20, 650)
$applyButton.Size = New-Object System.Drawing.Size(180, 38)
$applyButton.Enabled = $false
$form.Controls.Add($applyButton)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(220, 653)
$progressBar.Size = New-Object System.Drawing.Size(785, 28)
$progressBar.Minimum = 0
$progressBar.Value = 0
$form.Controls.Add($progressBar)

$runStatusLabel = New-Object System.Windows.Forms.Label
$runStatusLabel.Text = 'Ready.'
$runStatusLabel.Location = New-Object System.Drawing.Point(20, 696)
$runStatusLabel.Size = New-Object System.Drawing.Size(985, 22)
$form.Controls.Add($runStatusLabel)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(20, 722)
$logBox.Size = New-Object System.Drawing.Size(985, 58)
$logBox.Multiline = $true
$logBox.ScrollBars = 'Vertical'
$logBox.ReadOnly = $true
$form.Controls.Add($logBox)

$script:VmRows = @()
$script:SubscriptionContextCache = @{}

function Write-GuiLog {
    param([string]$Message)
    $timestamp = Get-Date -Format 'HH:mm:ss'
    $logBox.AppendText("[$timestamp] $Message`r`n")
    $logBox.SelectionStart = $logBox.Text.Length
    $logBox.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Load-VMList {
    $vmList.Items.Clear()
    $applyButton.Enabled = $false
    $script:VmRows = @()

    if (-not (Test-Path -LiteralPath $CsvPath)) {
        $csvStatusLabel.Text = "CSV not found. Create/copy the file to: $CsvPath"
        $csvStatusLabel.ForeColor = [System.Drawing.Color]::Firebrick
        return
    }

    try {
        $rows = @(Import-Csv -LiteralPath $CsvPath)
        if ($rows.Count -eq 0) {
            throw 'The CSV contains no VM rows.'
        }

        $headers = @($rows[0].PSObject.Properties.Name)
        $missingColumns = @($RequiredColumns | Where-Object { $_ -notin $headers })
        if ($missingColumns.Count -gt 0) {
            throw "Missing required CSV column(s): $($missingColumns -join ', ')"
        }

        $invalidRows = @(
            $rows | Where-Object {
                [string]::IsNullOrWhiteSpace($_.'NAME') -or
                [string]::IsNullOrWhiteSpace($_.'SUBSCRIPTION') -or
                [string]::IsNullOrWhiteSpace($_.'RESOURCE GROUP')
            }
        )

        if ($invalidRows.Count -gt 0) {
            throw "The CSV has $($invalidRows.Count) row(s) missing NAME, SUBSCRIPTION, or RESOURCE GROUP."
        }

        # Remove accidental duplicate target rows.
        $rows = @(
            $rows |
            Group-Object { "$($_.'SUBSCRIPTION')|$($_.'RESOURCE GROUP')|$($_.'NAME')" } |
            ForEach-Object { $_.Group[0] }
        )

        $script:VmRows = $rows

        foreach ($row in $script:VmRows) {
            $item = New-Object System.Windows.Forms.ListViewItem([string]$row.'NAME')
            [void]$item.SubItems.Add([string]$row.'SUBSCRIPTION')
            [void]$item.SubItems.Add([string]$row.'RESOURCE GROUP')
            [void]$vmList.Items.Add($item)
        }

        $subscriptionCount = @($script:VmRows | Select-Object -ExpandProperty 'SUBSCRIPTION' -Unique).Count
        $csvStatusLabel.Text = "Loaded $($script:VmRows.Count) VM(s) across $subscriptionCount subscription(s)."
        $csvStatusLabel.ForeColor = [System.Drawing.Color]::DarkGreen
        $applyButton.Enabled = $true
        Write-GuiLog "Loaded $($script:VmRows.Count) VM(s) from CSV."
    }
    catch {
        $csvStatusLabel.Text = "CSV error: $($_.Exception.Message)"
        $csvStatusLabel.ForeColor = [System.Drawing.Color]::Firebrick
        Show-Error $_.Exception.Message 'CSV Error'
    }
}

$reloadButton.Add_Click({
    Load-VMList
})

$applyButton.Add_Click({
    if ($script:VmRows.Count -eq 0) {
        Show-Error 'No VM rows are loaded from the CSV.'
        return
    }

    $requestedTags = @{}
    $blankTagNames = @()

    foreach ($tag in $StandardTags) {
        $value = $tagTextBoxes[$tag.Name].Text.Trim()
        if ([string]::IsNullOrWhiteSpace($value)) {
            $blankTagNames += $tag.Name
        } else {
            $requestedTags[$tag.Name] = $value
        }
    }

    if ($blankTagNames.Count -gt 0) {
        Show-Error "Please fill in all standard tag values.`r`n`r`nMissing: $($blankTagNames -join ', ')" 'Missing Tag Values'
        return
    }

    $summary = ($StandardTags | ForEach-Object {
        "$($_.Name) = $($requestedTags[$_.Name])"
    }) -join "`r`n"

    $confirmation = @"
You are about to process $($script:VmRows.Count) VM(s).

This tool will:
  - ADD a standard tag only when that tag is missing.
  - PRESERVE all non-standard existing tags.
  - PRESERVE existing values for standard tags.
  - NEVER delete a tag.

Tag values to use:

$summary

Continue?
"@

    $answer = [System.Windows.Forms.MessageBox]::Show(
        $confirmation,
        'Confirm Azure Tag Update',
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
        return
    }

    $applyButton.Enabled = $false
    $reloadButton.Enabled = $false
    $progressBar.Minimum = 0
    $progressBar.Maximum = $script:VmRows.Count
    $progressBar.Value = 0
    $logBox.Clear()

    try {
        $runStatusLabel.Text = 'Checking Azure PowerShell modules...'
        [System.Windows.Forms.Application]::DoEvents()
        Ensure-AzModules

        $runStatusLabel.Text = 'Checking Azure sign-in...'
        [System.Windows.Forms.Application]::DoEvents()
        Ensure-AzureConnection

        if (-not (Test-Path -LiteralPath $LogFolder)) {
            New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
        }

        $results = New-Object System.Collections.Generic.List[object]
        $addedVmCount = 0
        $noChangeVmCount = 0
        $failedVmCount = 0
        $totalAddedTags = 0

        for ($index = 0; $index -lt $script:VmRows.Count; $index++) {
            $row = $script:VmRows[$index]
            $vmName = [string]$row.'NAME'
            $subscriptionName = [string]$row.'SUBSCRIPTION'
            $resourceGroupName = [string]$row.'RESOURCE GROUP'

            $runStatusLabel.Text = "Processing $($index + 1) of $($script:VmRows.Count): $vmName"
            [System.Windows.Forms.Application]::DoEvents()

            try {
                if (-not $script:SubscriptionContextCache.ContainsKey($subscriptionName)) {
                    $subscriptions = @(Get-AzSubscription -SubscriptionName $subscriptionName -ErrorAction Stop)

                    if ($subscriptions.Count -eq 0) {
                        throw "Subscription '$subscriptionName' was not found for the signed-in account."
                    }

                    if ($subscriptions.Count -gt 1) {
                        $enabledSubscriptions = @($subscriptions | Where-Object { $_.State -eq 'Enabled' })
                        if ($enabledSubscriptions.Count -eq 1) {
                            $subscription = $enabledSubscriptions[0]
                        } else {
                            throw "More than one accessible subscription is named '$subscriptionName'. Use unique subscription names in the CSV."
                        }
                    } else {
                        $subscription = $subscriptions[0]
                    }

                    $context = Set-AzContext `
                        -SubscriptionId $subscription.Id `
                        -Tenant $subscription.TenantId `
                        -Scope Process `
                        -ErrorAction Stop

                    $script:SubscriptionContextCache[$subscriptionName] = $context
                    Write-GuiLog "Resolved subscription: $subscriptionName"
                }

                $context = $script:SubscriptionContextCache[$subscriptionName]

                $resources = @(
                    Get-AzResource `
                        -Name $vmName `
                        -ResourceGroupName $resourceGroupName `
                        -ResourceType 'Microsoft.Compute/virtualMachines' `
                        -DefaultProfile $context `
                        -ErrorAction Stop
                )

                # Get-AzResource supports wildcards, so enforce an exact resource-name match.
                $resource = @(
                    $resources | Where-Object {
                        $_.Name -eq $vmName -and
                        $_.ResourceGroupName -eq $resourceGroupName -and
                        $_.ResourceType -eq 'Microsoft.Compute/virtualMachines'
                    }
                )

                if ($resource.Count -eq 0) {
                    throw "VM not found in subscription/resource group."
                }
                if ($resource.Count -gt 1) {
                    throw "More than one exact VM resource match was returned."
                }

                $resource = $resource[0]
                $existingTagNames = @()
                if ($null -ne $resource.Tags) {
                    $existingTagNames = @($resource.Tags.Keys)
                }

                $missingTags = @{}
                $existingStandardTags = @()

                foreach ($tagName in $requestedTags.Keys) {
                    if ($existingTagNames -contains $tagName) {
                        $existingStandardTags += $tagName
                    } else {
                        $missingTags[$tagName] = $requestedTags[$tagName]
                    }
                }

                if ($missingTags.Count -gt 0) {
                    Update-AzTag `
                        -ResourceId $resource.ResourceId `
                        -Tag $missingTags `
                        -Operation Merge `
                        -DefaultProfile $context `
                        -ErrorAction Stop | Out-Null

                    $addedVmCount++
                    $totalAddedTags += $missingTags.Count
                    $status = 'Updated'
                    Write-GuiLog "$vmName - added $($missingTags.Count) missing tag(s)."
                } else {
                    $noChangeVmCount++
                    $status = 'No change'
                    Write-GuiLog "$vmName - all standard tags already exist."
                }

                $results.Add([pscustomobject]@{
                    Name                  = $vmName
                    Subscription          = $subscriptionName
                    ResourceGroup         = $resourceGroupName
                    Status                = $status
                    AddedTagCount         = $missingTags.Count
                    AddedTags             = (@($missingTags.Keys) -join '; ')
                    ExistingStandardTags  = ($existingStandardTags -join '; ')
                    Error                 = ''
                })
            }
            catch {
                $failedVmCount++
                $errorMessage = $_.Exception.Message
                Write-GuiLog "$vmName - ERROR: $errorMessage"
                $results.Add([pscustomobject]@{
                    Name                  = $vmName
                    Subscription          = $subscriptionName
                    ResourceGroup         = $resourceGroupName
                    Status                = 'Failed'
                    AddedTagCount         = 0
                    AddedTags             = ''
                    ExistingStandardTags  = ''
                    Error                 = $errorMessage
                })
            }

            $progressBar.Value = $index + 1
            [System.Windows.Forms.Application]::DoEvents()
        }

        $logPath = Join-Path $LogFolder ("AzureVMTagger_{0}.csv" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
        $results | Export-Csv -LiteralPath $logPath -NoTypeInformation -Encoding UTF8

        $runStatusLabel.Text = "Complete. Updated: $addedVmCount | No change: $noChangeVmCount | Failed: $failedVmCount | Tags added: $totalAddedTags"
        Write-GuiLog "Results exported to: $logPath"

        $finishMessage = @"
Tagging complete.

VMs updated:       $addedVmCount
VMs with no change: $noChangeVmCount
VMs failed:        $failedVmCount
Total tags added:  $totalAddedTags

Results log:
$logPath
"@
        Show-Info $finishMessage 'Azure Tagging Complete'
    }
    catch {
        $runStatusLabel.Text = 'Run stopped due to an error.'
        Show-Error $_.Exception.Message 'Azure Tagging Error'
    }
    finally {
        $applyButton.Enabled = ($script:VmRows.Count -gt 0)
        $reloadButton.Enabled = $true
    }
})

$form.Add_Shown({
    Load-VMList
})

[void]$form.ShowDialog()
