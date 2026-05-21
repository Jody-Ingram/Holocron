# Patch Analysis Reporter Launcher
# Reads the selected/open Outlook email, prepares an analysis prompt, then opens the Copilot agent.
# Copilot URL is preconfigured below.

$ErrorActionPreference = "Stop"

$CopilotUrl = 'https://m365.cloud.microsoft/chat/?titleId=T_223cf89f-228b-0d3b-e8a5-d6023b91ece0&source=embedded-builder'
$PromptFile = Join-Path $env:TEMP "PatchAnalysisReporter_EmailPrompt.txt"
$MaxBodyChars = 15000
$OpenNotepadBackup = $true

function Get-EdgePath {
    $paths = @(
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:LOCALAPPDATA\Microsoft\Edge\Application\msedge.exe"
    )

    foreach ($path in $paths) {
        if (Test-Path $path) {
            return $path
        }
    }

    throw "Microsoft Edge was not found in the standard install paths."
}

function Test-IsMailItem {
    param([object]$Item)

    try {
        # Outlook olMailItem = 43
        if ($Item.Class -eq 43) {
            return $true
        }
    } catch {}

    try {
        if ([string]$Item.MessageClass -like "IPM.Note*") {
            return $true
        }
    } catch {}

    return $false
}

function Get-OutlookApplication {
    try {
        return [Runtime.InteropServices.Marshal]::GetActiveObject("Outlook.Application")
    } catch {
        try {
            return New-Object -ComObject Outlook.Application
        } catch {
            return $null
        }
    }
}

function Get-CurrentOutlookMail {
    $outlook = Get-OutlookApplication
    if ($null -eq $outlook) {
        return $null
    }

    try {
        $inspector = $outlook.ActiveInspector()
        if ($null -ne $inspector) {
            $item = $inspector.CurrentItem
            if ($null -ne $item -and (Test-IsMailItem -Item $item)) {
                return $item
            }
        }
    } catch {}

    try {
        $explorer = $outlook.ActiveExplorer()
        if ($null -ne $explorer) {
            $selection = $explorer.Selection
            if ($null -ne $selection -and $selection.Count -gt 0) {
                $item = $selection.Item(1)
                if ($null -ne $item -and (Test-IsMailItem -Item $item)) {
                    return $item
                }
            }
        }
    } catch {}

    return $null
}

function Limit-Text {
    param(
        [string]$Text,
        [int]$MaxLength
    )

    if ([string]::IsNullOrEmpty($Text)) {
        return ""
    }

    if ($Text.Length -le $MaxLength) {
        return $Text
    }

    return $Text.Substring(0, $MaxLength) + "`r`n`r`n[Body truncated at $MaxLength characters.]"
}

function Show-InfoPopup {
    param(
        [string]$Message,
        [string]$Title = "Patch Analysis Reporter",
        [int]$Seconds = 5
    )

    try {
        $wsh = New-Object -ComObject WScript.Shell
        [void]$wsh.Popup($Message, $Seconds, $Title, 64)
    } catch {}
}

try {
    $edgePath = Get-EdgePath
    $mail = Get-CurrentOutlookMail

    if ($null -ne $mail) {
        $subject = [string]$mail.Subject
        $senderName = [string]$mail.SenderName
        $senderEmail = ""
        $received = ""
        $body = ""

        try { $senderEmail = [string]$mail.SenderEmailAddress } catch {}
        try { $received = [string]$mail.ReceivedTime } catch {}
        try { $body = Limit-Text -Text ([string]$mail.Body) -MaxLength $MaxBodyChars } catch {}

        $prompt = @"
Analyze this email for Windows patch known issues, Server OS risk, Epic/healthcare application impact, and recommended next steps.

Focus on:
- Windows Server OS patch risk
- Microsoft known issues / mitigations / rollbacks
- Epic or healthcare application impact
- Required validation steps
- Recommended operational response

Subject: $subject
From: $senderName <$senderEmail>
Received: $received

Email Body:
$body
"@

        $utf8WithBom = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllText($PromptFile, $prompt, $utf8WithBom)

        try {
            Set-Clipboard -Value $prompt
        } catch {}

        if ($OpenNotepadBackup) {
            Start-Process -FilePath "notepad.exe" -ArgumentList "`"$PromptFile`""
        }
    } else {
        Show-InfoPopup -Message "No selected/open Outlook email was detected. The Copilot agent will still open."
    }

    Start-Process -FilePath $edgePath -ArgumentList @("--app=`"$CopilotUrl`"", "--no-first-run")
} catch {
    Show-InfoPopup -Message ("Error: " + $_.Exception.Message) -Seconds 10
    throw
}