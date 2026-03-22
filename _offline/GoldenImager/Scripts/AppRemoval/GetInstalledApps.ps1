# Returns a list of installed apps by scanning Appx and Registry (Fast, 100% Offline)
function Get-OfflineInstalledApps {
    $apps = @()
    # 1. Get all Appx Packages (system-wide)
    try {
        $apps += Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
    } catch { 
        # Fallback to current user if AllUsers fails in Audit Mode
        try { $apps += Get-AppxPackage | Select-Object -ExpandProperty Name } catch { }
    }

    # 2. Get Registry-based installs (64-bit and 32-bit)
    $regPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($path in $regPaths) {
        try {
            $items = Get-ItemProperty $path -ErrorAction SilentlyContinue
            if ($items) {
                foreach ($item in $items) {
                    if ($item.DisplayName) { $apps += $item.DisplayName }
                    elseif ($item.PSChildName) { $apps += $item.PSChildName }
                }
            }
        } catch { }
    }

    return $apps | Where-Object { $_ } | Sort-Object -Unique
}

# Run winget list and return installed apps (sync or async)
# Uses full path to winget because Start-Job runs in a separate process that may not have winget in PATH
function GetInstalledAppsViaWinget {
    param (
        [int]$TimeOut = 15,
        [switch]$Async
    )

    # Fast offline scan first
    $offlineApps = Get-OfflineInstalledApps
    $offlineResult = $offlineApps -join "`n"

    if (-not $script:WingetInstalled -or -not $script:WingetPath) { 
        return $offlineResult 
    }

    $wingetExe = $script:WingetPath
    $scriptBlock = { 
        param($exe, $offlineResult) 
        $w = & $exe list --accept-source-agreements --disable-interactivity 2>$null
        if ($w) { return $w }
        return $offlineResult
    }

    if ($Async) {
        $wingetListJob = Start-Job -ArgumentList $wingetExe, $offlineResult -ScriptBlock $scriptBlock
        return @{ Job = $wingetListJob; StartTime = Get-Date }
    }
    else {
        # Use Start-Process for more reliable timeout than Start-Job in Audit Mode
        $tempFile = [System.IO.Path]::GetTempFileName()
        try {
            $p = Start-Process -FilePath $wingetExe -ArgumentList "list --accept-source-agreements --disable-interactivity" -NoNewWindow -PassThru -RedirectStandardOutput $tempFile -ErrorAction SilentlyContinue
            if ($p) {
                $p | Wait-Process -Timeout $TimeOut -ErrorAction SilentlyContinue
                if (-not $p.HasExited) {
                    $p | Stop-Process -Force -ErrorAction SilentlyContinue
                } else {
                    $result = Get-Content $tempFile -Raw
                    if ($result -and $result.Length -gt 100) { return $result }
                }
            }
        } finally {
            if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
        }
        return $offlineResult
    }
}
