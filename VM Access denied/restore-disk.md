Step 1: Open VM Backup

Go to:

Virtual Machines

→ Select your VM
→ Backup

Step 2: Click Restore VM

Choose: Restore VM

Step 3: Select Recovery Point

Choose:
correct date/time
latest healthy restore point

Example:
Recovery Point:
19-Apr-2026 11:19 PM

Step 4: Choose Job Type

Select:
Recover Disks
⚠️ Do NOT choose Replace Existing
This creates new disks safely.

Step 5: Provide Restore Details

Fill:
Target Storage Account

Example:
rsgxxxxx898guestd
Target Resource Group

Example:
rsg-xxxxx-weu1-d-001
Managed Disk

Select: Yes

Step 6: Start Restore

Click: Restore
Azure starts background restore job.

Step 7: Check Backup Job Status

Go to:
Recovery Services Vault > select the one used for backup > select the virtual machines


→ Backup items
Look for:
VM name

Wait until status shows: Completed ✅

Do not proceed before this.


Step 8: Open Azure Disks

Go to: Azure Portal → Disks

Step 9: Identify New Restored Disks

Look for new disks like:
restored-os-disk
restored-data-disk-1
restored-data-disk-2

Azure may use auto-generated names.
Check:
Created Time

to identify them.

Step 9: Open broken VM 

SWAP the OS Disk and Deattach the old disk and Attach the new data disk and keep a note of order in data disk.
