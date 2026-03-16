
1. Identify the Drive Letter & Label
Run this to see exactly how the guest sees your staging drive:
 Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' } | Select-Object DriveLetter, FileSystemLabel, Size
 * Data Point: Verify the FileSystemLabel matches exactly "Golden Imaging".


2. Identify the Active User
Run this to confirm the account name:
 whoami
 $env:USERNAME
 * Data Point: Ensure it is indeed Administrator.


3. Apply the "Host-to-Guest" Connection Fix
PowerShell Direct and remote administration often block local Administrator accounts with blank passwords unless this specific registry key is set. This is the most
likely reason your Host is seeing "Invalid Credential":


 # 1. Allow local accounts (Administrator) to perform remote tasks without a password
 Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "LocalAccountTokenFilterPolicy" -Value 1 -Force

 # 2. Ensure PowerShell Remoting is fully enabled
 Enable-PSRemoting -Force -SkipNetworkProfileCheck

 # 3. (Optional) Set the Network to Private to avoid firewall blocks
 Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private

4. Verify Guest Services are running
The Host uses Guest Services to move files. Check if the service is active:


 Get-Service -Name "vmicguestinterface" | Select-Object Status, StartType
 * Action: If it is Stopped, run Start-Service vmicguestinterface.
