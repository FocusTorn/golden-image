# Golden Imager overlay: Offline-only app removal (no WinGet, no network).
# Edge and OneDrive use Remove-AppxPackage/Remove-ProvisionedAppxPackage like other apps.
# Suitable for offline audit mode and Sysprep.

function RemoveApps {
    param (
        $appslist
    )

    $targetUser = GetTargetUserForAppRemoval

    $appIndex = 0
    $appCount = @($appsList).Count

    Foreach ($app in $appsList) {
        if ($script:CancelRequested) {
            return
        }

        $appIndex++

        if ($script:ApplySubStepCallback -and $appCount -gt 1) {
            & $script:ApplySubStepCallback "Removing apps ($appIndex/$appCount)" $appIndex $appCount
        }

        Write-Host "Attempting to remove $app..."

        $appPattern = '*' + $app + '*'

        try {
            switch ($targetUser) {
                "AllUsers" {
                    Invoke-NonBlocking -TimeoutSeconds 120 -ScriptBlock {
                        param($pattern)
                        Get-AppxPackage -Name $pattern -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction Continue
                        Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like $pattern } | ForEach-Object { Remove-ProvisionedAppxPackage -Online -AllUsers -PackageName $_.PackageName }
                    } -ArgumentList $appPattern
                }
                "CurrentUser" {
                    Invoke-NonBlocking -TimeoutSeconds 120 -ScriptBlock {
                        param($pattern)
                        Get-AppxPackage -Name $pattern | Remove-AppxPackage -ErrorAction Continue
                    } -ArgumentList $appPattern
                }
                default {
                    Invoke-NonBlocking -TimeoutSeconds 120 -ScriptBlock {
                        param($pattern, $user)
                        $userAccount = New-Object System.Security.Principal.NTAccount($user)
                        $userSid = $userAccount.Translate([System.Security.Principal.SecurityIdentifier]).Value
                        Get-AppxPackage -Name $pattern -User $userSid | Remove-AppxPackage -User $userSid -ErrorAction Continue
                    } -ArgumentList @($appPattern, $targetUser)
                }
            }
        }
        catch {
            if ($DebugPreference -ne "SilentlyContinue") {
                Write-Host "Something went wrong while trying to remove $app" -ForegroundColor Yellow
                Write-Host $psitem.Exception.StackTrace -ForegroundColor Gray
            }
        }
    }

    Write-Host ""
}
