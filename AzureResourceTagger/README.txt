Azure VM Standard Tagger

FILES
-----
AzureVMTagger.ps1
    Main Windows Forms GUI.

Launch_AzureVMTagger.cmd
    Double-click this file to launch the GUI.

SETUP
-----
1. Create:
   C:\Tools\Azure_Resource_Tagger

2. Place these two files in that folder.

3. Place your VM CSV at:
   C:\Tools\Azure_Resource_Tagger\AzureVMs.csv

4. The CSV must contain these columns:
   NAME
   SUBSCRIPTION
   RESOURCE GROUP

5. Double-click:
   Launch_AzureVMTagger.cmd

BEHAVIOR
--------
- You enter the 10 standard tag values once.
- The same values are evaluated for every VM in the CSV.
- If a standard tag is missing on a VM, the tag is added.
- If a standard tag already exists, its current value is preserved.
- Existing non-standard tags are preserved.
- No tags are deleted.
- A results CSV is created under:
  C:\Tools\Azure_Resource_Tagger\Logs

AZURE POWERSHELL
----------------
The tool uses:
- Az.Accounts
- Az.Resources

If either module is missing, the GUI offers to install it for the current user.
