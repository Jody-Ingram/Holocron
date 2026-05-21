# Patch Analysis Reporter - Auto Deploy Package

This package is preconfigured with a Copilot Agent URL. Please change this to reflect your Copilot Agent URL.

https://m365.cloud.microsoft/chat/add-your-url-here

## Recommended quick deployment

Use the Windows shortcut launcher. It avoids Outlook VBA macro security and is much easier to hand to another person.

### Current user install

1. Extract the ZIP.
2. Double-click `INSTALL-CurrentUser.cmd`.
3. A **Patch Analysis Reporter** shortcut is created on the user's Desktop and Start Menu.

### Use

1. Select or open an email in classic Outlook.
2. Click **Patch Analysis Reporter** from Desktop or Start Menu.
3. The selected email is converted into an analysis prompt.
4. The prompt is copied to clipboard.
5. A Notepad backup opens.
6. The Copilot Agent opens in Microsoft Edge.

## All-users install

Run `INSTALL-AllUsers-RunAsAdmin.cmd` as Administrator.

Or run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-PatchAnalysisReporter.ps1 -AllUsers
```

## Intune Win32 app install command

```cmd
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-PatchAnalysisReporter.ps1 -AllUsers
```

## Intune detection rule example

Use a PowerShell detection rule:

```powershell
Test-Path "$env:ProgramData\PatchAnalysisReporter\Launch-PatchAnalysisReporter.ps1"
```

## Uninstall command

```cmd
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall-PatchAnalysisReporter.ps1 -AllUsers
```

## Optional classic Outlook VBA module

`OutlookVBA_PatchAnalysisReporter.bas` is included if you still want a classic Outlook ribbon macro.

Manual import steps:

1. Open classic Outlook.
2. Press `Alt + F11`.
3. In VBA editor, go to `File > Import File`.
4. Import `OutlookVBA_PatchAnalysisReporter.bas`.
5. Save.
6. In Outlook, go to `File > Options > Customize Ribbon`.
7. Create a custom group and add the macro:
   `PatchAnalysisReporter.OpenPatchAnalysisReporter_WithEmail`.

Note: this VBA approach is not recommended for broad deployment unless macros are signed/trusted.
