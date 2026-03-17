
net share E_DRIVE=E:\ /GRANT:Everyone,FULL

net use Z: \\localhost\E_DRIVE /user:Administrator 654654



On the VM, run:

1. Hostname

$env:COMPUTERNAME
or

hostname
2. IPv4 address

(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -notlike "169.*" }).IPAddress
or, simpler:

(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.PrefixOrigin -eq "Dhcp" -or $_.PrefixOrigin -eq "Manual" }).IPAddress
Or using ipconfig:

ipconfig | Select-String "IPv4"


















$Password = "654654"

# 1. Set Administrator Password
([ADSI]"WinNT://localhost/Administrator,user").SetPassword($Password)

# 2. Enable Remote Desktop & Disable NLA (required for Audit Mode/Enhanced Session)
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"



# 3. Restart TermService so it picks up the new registry settings
Restart-Service -Name "TermService" -Force -ErrorAction SilentlyContinue
Get-Service "UmRdpService" -ErrorAction SilentlyContinue | Restart-Service -Force -ErrorAction SilentlyContinue

# RunOnce: Restart TermService at first logon (RDP listener often doesn't bind until a user session exists)
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name "RDPListenerFix" -Value 'powershell -NoProfile -Command "Restart-Service TermService -Force; Get-Service UmRdpService -ErrorAction SilentlyContinue | Restart-Service -Force -ErrorAction SilentlyContinue"' -Type String -Force

# 4. Configure Hyper-V & RDP Services
$Services = @("TermService", "vmicguestinterface")
foreach ($Svc in $Services) {
    Set-Service -Name $Svc -StartupType Automatic
    Start-Service -Name $Svc -ErrorAction SilentlyContinue
}

# 5. Configure AutoLogon for Administrator
$WinlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty -Path $WinlogonPath -Name "AutoAdminLogon" -Value "1"
Set-ItemProperty -Path $WinlogonPath -Name "DefaultUserName" -Value "Administrator"
Set-ItemProperty -Path $WinlogonPath -Name "DefaultPassword" -Value $Password

# 6. Ensure RDP port is 3389 (some images have it changed)
$rdpTcpPath = "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
if (Test-Path $rdpTcpPath) { Set-ItemProperty -Path $rdpTcpPath -Name "PortNumber" -Value 3389 -Type DWord -Force -ErrorAction SilentlyContinue }

# 7. Disable Windows Hello (Prevents session blocking on Win 10/11)
$PasswordLessPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device"
if (Test-Path $PasswordLessPath) {
    Set-ItemProperty -Path $PasswordLessPath -Name "DevicePasswordLessBuildVersion" -Value 0
}

Write-Host "Configuration Complete!" -ForegroundColor Green

# --- RDP listener still INACTIVE? Try these fixes ---
#
# 1. Delete RDP self-signed certificate (use certlm.msc for LOCAL COMPUTER certs, not certmgr):
#    - Run: certlm.msc
#    - Expand: Remote Desktop > Certificates
#    - Right-click the RDP self-signed cert > Delete
#    - Restart-Service TermService -Force
#
# 2. Fix MachineKeys permissions (required for RDP to recreate the cert):
#    - Open: %ProgramData%\Microsoft\Crypto\RSA\MachineKeys
#    - Right-click MachineKeys folder > Properties > Security > Edit
#    - Add/ensure: Everyone = Read, Write
#    - Add/ensure: Administrators = Full control
#    - Restart-Service TermService -Force











1. Confirm TermService is listening on any port

$termsvc = Get-CimInstance -Class Win32_Service -Filter 'Name="Termservice"' | Select-Object Name, ProcessID
Get-NetTCPConnection | Where-Object { $_.OwningProcess -eq $termsvc.ProcessID -and $_.State -eq 'Listen' }
If nothing is returned, TermService is not binding any port.

2. Copy RDP-Tcp registry from a working machine

If the host (or another VM) has working RDP:

On the working machine: export
HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp
to a .reg file.
Copy the file into the VM and merge it (double‑click or regedit /s file.reg).
Restart TermService:
Restart-Service TermService -Force
3. Check UmRdpService

Get-Service TermService, UmRdpService
Both should be Running. If UmRdpService is stopped, start it:

Start-Service UmRdpService -ErrorAction SilentlyContinue
Restart-Service TermService -Force
4. Audit Mode / OOBE







# Verify VM

Write-Host "--- Hyper-V & RDP Health Check ---" -ForegroundColor Cyan

function Get-StatusColor { param($ok) if ($ok) { 'Green' } else { 'Red' } }

# 1. Check RDP Listener (registry port may differ from default 3389)
$RDPPort = 3389
$portKey = Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "PortNumber" -ErrorAction SilentlyContinue
if ($portKey) { $RDPPort = $portKey.PortNumber }
$RDPListening = (Get-NetTCPConnection -LocalPort $RDPPort -State Listen -ErrorAction SilentlyContinue).Count -gt 0
if (-not $RDPListening) { $RDPListening = (netstat -an | Select-String ":$RDPPort\s+.*LISTENING").Count -gt 0 }
Write-Host "RDP Listener: $(if ($RDPListening) { "ACTIVE (port $RDPPort)" } else { "INACTIVE (port $RDPPort not listening)" })" -ForegroundColor (Get-StatusColor $RDPListening)

# 2. Check Required Services (Should be 'Running')
$Services = @("TermService", "vmicguestinterface")
foreach ($Svc in $Services) {
    $Status = (Get-Service $Svc -ErrorAction SilentlyContinue).Status
    $ok = $Status -eq 'Running'
    Write-Host "Service $Svc`: $Status" -ForegroundColor (Get-StatusColor $ok)
}

# 3. Check AutoLogon Registry Settings
$Logon = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -ErrorAction SilentlyContinue
Write-Host "`n--- AutoLogon Status ---" -ForegroundColor Cyan
Write-Host "AutoAdminLogon: $(if ($Logon) { $Logon.AutoAdminLogon } else { 'N/A' })"
Write-Host "DefaultUser:    $(if ($Logon) { $Logon.DefaultUserName } else { 'N/A' })"
$pwdOk = $Logon -and $Logon.DefaultPassword -eq '654654'
Write-Host "Password Set:   $(if ($pwdOk) { 'YES' } else { 'NO' })" -ForegroundColor (Get-StatusColor $pwdOk)

# 4. Check NLA (Should be 0 for easiest Audit Mode connection)
$NLA = Get-ItemProperty "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthentication" -ErrorAction SilentlyContinue
$nlaOk = $NLA -and $NLA.UserAuthentication -eq 0
Write-Host "NLA Disabled:   $(if ($NLA) { if ($nlaOk) { 'YES' } else { 'NO' } } else { 'N/A' })" -ForegroundColor (Get-StatusColor $nlaOk)







Start-Sleep -Seconds 5
Restart-Computer






# On Host


$VMName = "Windows 11 Master" # <-- CHANGE THIS to your VM's name

# 1. Enable Global Enhanced Session Policy on Host
Set-VMHost -EnableEnhancedSessionMode $true

# 2. Enable Guest Services & Enhanced Transport for the VM
Enable-VMIntegrationService -VMName $VMName -Name "Guest Service Interface"
Set-VM -VMName $VMName -EnhancedSessionTransportType HvSocket

# 3. Verification Check
$Status = Get-VMHost | Select-Object -Property EnableEnhancedSessionMode
$GuestSvc = Get-VMIntegrationService -VMName $VMName -Name "Guest Service Interface"

Write-Host "--- Host Verification ---" -ForegroundColor Cyan
Write-Host "Global Enhanced Session: $($Status.EnableEnhancedSessionMode)"
Write-Host "Guest Service Status:    $($GuestSvc.PrimaryStatusDescription)"























Enable RDP connections:
reg add "HKLM\System\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f

Enable the Firewall Rule:
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes

Disable NLA (Optional but recommended for Audit Mode):
If you have trouble connecting without a password, this allows older RDP versions:
reg add "HKLM\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v UserAuthentication /t REG_DWORD /d 0 /f 




























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
