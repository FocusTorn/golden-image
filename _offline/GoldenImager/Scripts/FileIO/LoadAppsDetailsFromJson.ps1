# Read Apps.json and return list of app objects with optional filtering
function LoadAppsDetailsFromJson {
    param (
        [switch]$OnlyInstalled,
        [string]$InstalledList = "",
        [switch]$InitialCheckedFromJson
    )

    $apps = @()
    try {
        $jsonContent = Get-Content -Path $script:AppsListFilePath -Raw | ConvertFrom-Json
    }
    catch {
        Write-Error "Failed to read Apps.json: $_"
        return $apps
    }

    foreach ($appData in $jsonContent.Apps) {
        $appId = $appData.AppId.Trim()
        if ($appId.length -eq 0) { continue }

        $isInstalled = $true
        if ($OnlyInstalled) {
            $isInstalled = $false
            # Check list passed from background job
            if ($InstalledList -match [regex]::Escape($appId)) { $isInstalled = $true }
            # Fallback: Live check if list is empty
            elseif (Get-AppxPackage -Name $appId -ErrorAction SilentlyContinue) { $isInstalled = $true }
            
            # Special case for Edge
            if (($appId -eq "Microsoft.Edge") -and ($InstalledList -match "Microsoft.Edge")) { $isInstalled = $true }
        }

        if (-not $isInstalled) { continue }

        $friendlyName = if ($appData.FriendlyName) { $appData.FriendlyName } else { $appId }
        $displayName = if ($appData.FriendlyName) { "$($appData.FriendlyName) ($appId)" } else { $appId }
        $isChecked = if ($InitialCheckedFromJson) { $appData.SelectedByDefault } else { $false }

        $apps += [PSCustomObject]@{
            AppId = $appId
            FriendlyName = $friendlyName
            DisplayName = $displayName
            IsChecked = $isChecked
            Description = $appData.Description
            SelectedByDefault = $appData.SelectedByDefault
            Recommendation = $appData.Recommendation
        }
    }

    return $apps
}
