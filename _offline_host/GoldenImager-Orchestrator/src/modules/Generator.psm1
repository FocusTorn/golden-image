# Generator Module v1.2
# Optimized for absolute path joining and source reliability

$ScriptSourceRoot = "P:\Projects\golden-image\_offline\GoldenImager2\src-tauri\resources\scripts"

function Stage-PayloadScripts {
    param(
        [Parameter(Mandatory=$true)][string]$TargetDir
    )

    if ([string]::IsNullOrWhiteSpace($TargetDir)) { throw "TargetDir is null or empty" }
    
    if (-not (Test-Path $TargetDir)) { 
        New-Item $TargetDir -ItemType Directory -Force | Out-Null 
    }

    $Scripts = @("1_Scoop.ps1", "2_MSVC.ps1", "3_System_Apps.ps1", "4_Rust_Finish.ps1", "5_Finalize.ps1", "Customize.ps1")
    
    # Module Scope Check (Explicit)
    if (-not (Test-Path $script:ScriptSourceRoot)) {
        throw "CRITICAL: Script source directory missing: $script:ScriptSourceRoot"
    }

    foreach ($s in $Scripts) {
        $src = [System.IO.Path]::Combine($script:ScriptSourceRoot, $s)
        if (Test-Path $src) {
            Copy-Item $src -Destination $TargetDir -Force -ErrorAction Stop
        } else {
            throw "CRITICAL: Build stage script missing: $src"
        }
    }
}

function New-OrchestratorUnattendXml {
    param(
        [string]$OutputPath,
        [hashtable]$Settings,
        [hashtable]$BypassOptions
    )

    $AdminPass = if ($Settings.AdminPassword) { $Settings.AdminPassword } else { "PackerTemp123!" }
    $BypassTPS = if ($BypassOptions.BypassTPM) { 'reg add HKLM\SYSTEM\Setup\LabConfig /v BypassTPMCheck /t REG_DWORD /d 1 /f & ' } else { '' }
    $BypassSecureBoot = if ($BypassOptions.BypassSecureBoot) { 'reg add HKLM\SYSTEM\Setup\LabConfig /v BypassSecureBootCheck /t REG_DWORD /d 1 /f & ' } else { '' }

    $xml = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
                    <Order>1</Order>
                    <Path>cmd.exe /c "${BypassTPS}${BypassSecureBoot}reg add HKLM\SYSTEM\Setup\LabConfig /v BypassRAMCheck /t REG_DWORD /d 1 /f"</Path>
                </RunSynchronousCommand>
            </RunSynchronous>
            <UserData>
                <AcceptEula>true</AcceptEula>
                <ProductKey><Key>VK7JG-NPHTM-C97JM-9MPGT-3V66T</Key></ProductKey>
            </UserData>
            <DiskConfiguration>
                <Disk wcm:action="add" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
                    <DiskID>0</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                    <CreatePartitions>
                        <CreatePartition wcm:action="add"><Order>1</Order><Size>300</Size><Type>Primary</Type></CreatePartition>
                        <CreatePartition wcm:action="add"><Order>2</Order><Size>128</Size><Type>MSR</Type></CreatePartition>
                        <CreatePartition wcm:action="add"><Order>3</Order><Extend>true</Extend><Type>Primary</Type></CreatePartition>
                    </CreatePartitions>
                </Disk>
                <WillShowUI>OnError</WillShowUI>
            </DiskConfiguration>
            <ImageInstall>
                <OSImage>
                    <InstallTo><DiskID>0</DiskID><PartitionID>3</PartitionID></InstallTo>
                </OSImage>
            </ImageInstall>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <AutoLogon>
                <Password><Value>$AdminPass</Value><PlainText>true</PlainText></Password>
                <Enabled>true</Enabled>
                <Username>Administrator</Username>
            </AutoLogon>
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
                    <Order>1</Order>
                    <CommandLine>powershell.exe -ExecutionPolicy Bypass -File \"C:\Windows\Setup\Scripts\BootstrapDev.ps1\"</CommandLine>
                </SynchronousCommand>
            </FirstLogonCommands>
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideLocalUserScreen>true</HideLocalUserScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <ProtectYourPC>3</ProtectYourPC>
            </OOBE>
        </component>
    </settings>
</unattend>
"@
    $xml | Set-Content $OutputPath -Force -Encoding UTF8
}

function New-BootstrapDevPs1 {
    param([string]$OutputPath, [string[]]$Stages)
    $content = @(
        "`$ErrorActionPreference = 'Stop'",
        "Write-Host '[*] Initializing Developer Bootstrap...' -ForegroundColor Cyan",
        "Set-Location 'C:\Windows\Setup\Scripts'"
    )
    # Refined path joining for the bootstrap script
    foreach ($s in $Stages) { $content += "Write-Host '>>> STAGE: $s'; & '.\$s.ps1'" }
    $content | Set-Content $OutputPath -Force -Encoding UTF8
}

Export-ModuleMember -Function Stage-PayloadScripts, New-OrchestratorUnattendXml, New-BootstrapDevPs1
