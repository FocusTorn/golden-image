# Get-RemoteLog.ps1
# Pulls the latest installation log from the VM for a specific category.
# Usage: .\Get-RemoteLog.ps1 scoop
#        .\Get-RemoteLog.ps1 apps
#        .\Get-RemoteLog.ps1 rust
#        .\Get-RemoteLog.ps1 msvc

Param(
    [Parameter(Position = 0)]
    [ValidateSet("scoop", "apps", "rust", "msvc", "bootstrapper")]
    [string]$Category = "rust"
)

# Map category to log file naming patterns
$PatternMap = @{
    "scoop"        = "Install_Stage_1_Scoop_*.log"
    "msvc"         = "vs_setup*.log"
    "bootstrapper" = "dd_bootstrapper_*.log"
    "apps"         = "Install_Stage_3_Apps_*.log"
    "rust"         = "Install_Stage_4_Rust_*.log"
}

$LogFilter = $PatternMap[$Category]

$TargetAdmin = "Administrator"
$VMName = "Windows 11 Master"
$creds = New-Object System.Management.Automation.PSCredential(".\$TargetAdmin", (New-Object System.Security.SecureString))

Write-Host "--- ROG STRIX: HARVESTING RECENT [$($Category.ToUpper())] LOG FROM VM ---" -ForegroundColor Cyan

$ScriptBlock = {
    param($Filter)
    $latest = Get-ChildItem -Path "F:\return" -Filter $Filter -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending |
              Select-Object -First 1
    
    if ($latest) {
        Write-Host "`n>>> DISPLAYING: $($latest.FullName)" -ForegroundColor Yellow
        Write-Host "----------------------------------------------------------------" -ForegroundColor Gray
        Get-Content -Path $latest.FullName
        Write-Host "----------------------------------------------------------------" -ForegroundColor Gray
    } else {
        Write-Host "[!] No logs matching '$Filter' found in F:\return" -ForegroundColor Red
    }
}

Invoke-Command -VMName $VMName -Credential $creds -ScriptBlock $ScriptBlock -ArgumentList $LogFilter
