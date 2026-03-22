<#
.SYNOPSIS
    Shared utility library for Golden Image VHD management.
    Provides lock mitigation and VHD transition engine.
#>

# Resolve project root relative to this script
$LocalProjectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent

# Import shared configuration utilities
. (Join-Path $LocalProjectRoot "_helpers\ConfigUtils.ps1")

# --- VHD ENGINE ---

function Invoke-PollUntil {
    Param([scriptblock]$Condition, [int]$MaxWaitSeconds = 5, [int]$IntervalMs = 300)
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    do {
        try { $result = & $Condition; if ($null -ne $result -and $result -ne $false) { return $result } } catch {}
        Start-Sleep -Milliseconds $IntervalMs
    } while ($stopwatch.Elapsed.TotalSeconds -lt $MaxWaitSeconds)
    return $null
}

function Get-VhdInfoSafe {
    Param([string]$VhdPath, [int]$TimeoutSeconds = 3)
    $job = Start-Job { param($p) Import-Module Hyper-V; Get-VHD -Path $p } -ArgumentList $VhdPath
    if (Wait-Job $job -Timeout $TimeoutSeconds) { $r = Receive-Job $job; Remove-Job $job -Force; return $r }
    Stop-Job $job; Remove-Job $job -Force; return $null
}

function Get-VmDriveForVhd {
    Param([string]$VhdPath, [string]$VMName)
    $all = Get-VMHardDiskDrive -VMName $VMName -ErrorAction SilentlyContinue
    $match = $all | Where-Object { $_.Path -and (($_.Path -eq $VhdPath) -or ((Split-Path $_.Path -Leaf) -eq (Split-Path $VhdPath -Leaf))) } | Select-Object -First 1
    if ($match) { return $match }
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($VhdPath)
    $all | Where-Object { $_.Path -and (Split-Path $_.Path -Leaf) -like "${baseName}*" } | Select-Object -First 1
}

function Test-IsVhdLockError {
    Param($ErrorRecord)
    $msg = $ErrorRecord.ToString() + " " + $ErrorRecord.Exception.Message
    return ($msg -like "*used by another process*" -or $msg -like "*in use*" -or $msg -like "*0x80070020*")
}

function Invoke-SmartRelease {
    Param([string]$VhdPath, [string]$VMName)
    Write-Host "[*] Smart Release: $VhdPath" -ForegroundColor Gray
    
    # 1. Release from VM
    $vmDrive = Get-VmDriveForVhd -VhdPath $VhdPath -VMName $VMName
    if ($vmDrive) {
        Write-Host "    -> Removing from VM: $VMName" -ForegroundColor Yellow
        $vmDrive | Remove-VMHardDiskDrive -ErrorAction SilentlyContinue
    }

    # 2. Release from Host
    $vhdInfo = Get-VhdInfoSafe -VhdPath $VhdPath
    if ($vhdInfo -and $vhdInfo.Attached) {
        Write-Host "    -> Dismounting from Host" -ForegroundColor Yellow
        Dismount-VHD -Path $VhdPath -ErrorAction SilentlyContinue
    }

    # 3. Force Escalation
    Get-Disk | Where-Object { $_.FriendlyName -like "*Virtual*" } | Set-Disk -IsOffline $true -ErrorAction SilentlyContinue
}

function Invoke-VhdTransition {
    Param([ValidateSet("Host", "VM")][string]$Target, [string]$VhdPath, [string]$VMName)
    Invoke-SmartRelease -VhdPath $VhdPath -VMName $VMName
    if ($Target -eq "Host") {
        Mount-VHD -Path $VhdPath -ErrorAction Stop
        return Invoke-PollUntil { $v = Get-VhdInfoSafe -VhdPath $VhdPath; if ($v -and $v.Attached -and $v.DiskNumber -ne $null) { $v } }
    } else {
        # Prevent .avhdx creation: Remove any existing snapshots before attaching a new drive.
        # Hyper-V creates differencing disks for newly attached drives if snapshots exist.
        if (Get-VMSnapshot -VMName $VMName -ErrorAction SilentlyContinue) {
            Write-Host "[*] Removing VM snapshots to prevent .avhdx aliases..." -ForegroundColor Yellow
            Get-VMSnapshot -VMName $VMName | Remove-VMSnapshot -IncludeAllChildSnapshots -ErrorAction SilentlyContinue
        }

        Add-VMHardDiskDrive -VMName $VMName -ControllerType SCSI -Path $VhdPath -ErrorAction Stop
        return Invoke-PollUntil { Get-VmDriveForVhd -VhdPath $VhdPath -VMName $VMName }
    }
}
