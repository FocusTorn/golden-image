# Read Apps.json and return list of app objects with optional filtering.
# Offline-first: uses Get-AppxPackage and Get-AppxProvisionedPackage (same logic as Generate_App_Lists.ps1).
# No WinGet dependency for audit/sysprep mode.
function LoadAppsDetailsFromJson {
    param (
        [switch]$OnlyInstalled,
        [string]$InstalledList = "",
        [switch]$InitialCheckedFromJson,
        [ValidateSet('FromJson', 'UserNotListed', 'ProvisionedNotListed', 'AllNotListed')]
        [string]$ViewMode = 'FromJson'
    )

    $apps = @()
    $guidPattern = '^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$'
    $needInstalled = $OnlyInstalled -or $ViewMode -ne 'FromJson'
    $needProvisioned = $ViewMode -in @('UserNotListed', 'ProvisionedNotListed', 'AllNotListed')

    $installedNames = @()
    $provisionedNames = @()

    if ($needInstalled) {
        try {
            $installedPkgs = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            if (-not $installedPkgs) { $installedPkgs = @(Get-AppxPackage -ErrorAction SilentlyContinue) }
            $installedNames = @($installedPkgs | ForEach-Object { $_.Name } | Where-Object { $_ } | Sort-Object -Unique)
        } catch { }
    }

    if ($needProvisioned) {
        try {
            $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
            $provisionedNames = @($provisioned | ForEach-Object { $_.DisplayName } | Where-Object { $_ } | Sort-Object -Unique)
        } catch { }
    }

    $userOnlyNames = @($installedNames | Where-Object { $provisionedNames -notcontains $_ })

    $jsonAppIds = @()
    $jsonContent = $null
    try {
        $jsonContent = Get-Content -Path $script:AppsListFilePath -Raw -ErrorAction Stop | ConvertFrom-Json
        foreach ($appData in $jsonContent.Apps) {
            $appId = $appData.AppId.Trim()
            if ($appId.Length -gt 0) {
                $jsonAppIds += $appId
            }
        }
    } catch {
        Write-Error "Failed to read Apps.json: $_"
        return $apps
    }

    if ($script:OverlayAppsListFilePath -and (Test-Path $script:OverlayAppsListFilePath)) {
        try {
            $overlayContent = Get-Content -Path $script:OverlayAppsListFilePath -Raw -ErrorAction Stop | ConvertFrom-Json
            foreach ($overlayApp in $overlayContent.Apps) {
                $oId = $overlayApp.AppId.Trim()
                if ($oId.Length -gt 0 -and $jsonAppIds -notcontains $oId) {
                    $jsonContent.Apps += $overlayApp
                    $jsonAppIds += $oId
                }
            }
        } catch {
            Write-Warning "Failed to read overlay Apps.json: $_"
        }
    }

    # --- ViewMode: Not-listed modes (apps on system but NOT in Apps.json) ---
    if ($ViewMode -eq 'UserNotListed') {
        $namesToShow = @($userOnlyNames | Where-Object { $jsonAppIds -notcontains $_ -and $_ -notmatch $guidPattern })
    }
    elseif ($ViewMode -eq 'ProvisionedNotListed') {
        $namesToShow = @($provisionedNames | Where-Object { $jsonAppIds -notcontains $_ -and $_ -notmatch $guidPattern })
    }
    elseif ($ViewMode -eq 'AllNotListed') {
        $allSystemNames = @($installedNames + $provisionedNames | Sort-Object -Unique)
        $namesToShow = @($allSystemNames | Where-Object { $jsonAppIds -notcontains $_ -and $_ -notmatch $guidPattern })
    }
    else {
        $namesToShow = @()
    }

    if ($namesToShow.Count -gt 0) {
        foreach ($name in $namesToShow) {
            $apps += [PSCustomObject]@{
                AppId            = $name
                FriendlyName     = $name
                DisplayName     = $name
                IsChecked        = $false
                Description     = "(Not in curated list)"
                SelectedByDefault = $false
                Recommendation  = "optional"
            }
        }
        return $apps
    }

    # --- ViewMode: FromJson (default) ---
    if ($ViewMode -ne 'FromJson') { return $apps }

    foreach ($appData in $jsonContent.Apps) {
        $appId = $appData.AppId.Trim()
        if ($appId.Length -eq 0) { continue }
        if ($appId -match $guidPattern) { continue }

        if ($OnlyInstalled) {
            $isInstalled = $installedNames -contains $appId
            if (-not $isInstalled) { continue }
        }

        $friendlyName = if ($appData.FriendlyName) { $appData.FriendlyName } else { $appId }
        $displayName = if ($appData.FriendlyName) { "$($appData.FriendlyName) ($appId)" } else { $appId }
        $isChecked = if ($InitialCheckedFromJson) { $appData.SelectedByDefault } else { $false }

        $apps += [PSCustomObject]@{
            AppId            = $appId
            FriendlyName     = $friendlyName
            DisplayName     = $displayName
            IsChecked        = $isChecked
            Description     = $appData.Description
            SelectedByDefault = $appData.SelectedByDefault
            Recommendation  = $appData.Recommendation
        }
    }

    return $apps
}
