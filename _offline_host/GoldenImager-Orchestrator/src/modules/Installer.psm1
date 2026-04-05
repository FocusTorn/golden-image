Import-Module ThreadJob -ErrorAction SilentlyContinue

function Get-Packer {
    param(
        [string]$InstallPath = "$env:LOCALAPPDATA\Packer",
        [string]$Version = "1.11.2",
        [object]$LogBox
    )

    if (Get-Command packer -ErrorAction SilentlyContinue) {
        $LogBox.Dispatcher.Invoke([action]{ $LogBox.AppendText("[OK] Packer already in PATH.`r`n") })
        return $null
    }

    $binPath = [System.IO.Path]::Combine($InstallPath, "packer.exe")
    if (Test-Path $binPath) {
        $LogBox.Dispatcher.Invoke([action]{ $LogBox.AppendText("[OK] Packer found at $binPath.`r`n") })
        return $null
    }

    # Start Job and return it to caller for tracking
    return Start-ThreadJob -ArgumentList $InstallPath, $Version, $LogBox -ScriptBlock {
        param($path, $ver, $log)
        
        $log.Dispatcher.Invoke([action]{ $log.AppendText("[*] Thread: Acquiring Packer v$ver...`r`n") })
        
        if (!(Test-Path $path)) { New-Item $path -ItemType Directory -Force | Out-Null }
        $url = "https://releases.hashicorp.com/packer/$ver/packer_$($ver)_windows_amd64.zip"
        $zip = [System.IO.Path]::Combine($path, "packer.zip")

        try {
            $log.Dispatcher.Invoke([action]{ $log.AppendText("    -> Downloading ZIP...`r`n") })
            Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -ErrorAction Stop
            
            $log.Dispatcher.Invoke([action]{ $log.AppendText("    -> Extracting binary...`r`n") })
            Expand-Archive -Path $zip -DestinationPath $path -Force
            Remove-Item $zip -Force
            
            $log.Dispatcher.Invoke([action]{ $log.AppendText("[SUCCESS] Packer ready at $path`r`n") })
        } catch {
            $log.Dispatcher.Invoke([action]{ $log.AppendText("[ERROR] Packer download failed: $($_.Exception.Message)`r`n") })
        }
    }
}

function Install-OSDBuilderModule {
    param([object]$LogBox)

    return Start-ThreadJob -ArgumentList $LogBox -ScriptBlock {
        param($log)
        if (Get-Module -ListAvailable OSDBuilder) {
            $log.Dispatcher.Invoke([action]{ $log.AppendText("[OK] OSDBuilder module already installed.`r`n") })
            return
        }

        $log.Dispatcher.Invoke([action]{ $log.AppendText("[*] Thread: Installing OSDBuilder from PSGallery...`r`n") })
        try {
            # Use -Scope CurrentUser to avoid permissions issues
            Install-Module -Name OSDBuilder -Force -Scope CurrentUser -AllowClobber -ErrorAction Stop
            $log.Dispatcher.Invoke([action]{ $log.AppendText("[SUCCESS] OSDBuilder module installed.`r`n") })
        } catch {
            $log.Dispatcher.Invoke([action]{ $log.AppendText("[ERROR] OSDBuilder installation failed: $($_.Exception.Message)`r`n") })
        }
    }
}

function Check-HyperV {
    $feature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
    if ($feature -and $feature.State -eq 'Enabled') { return $true }
    return $false
}

Export-ModuleMember -Function Get-Packer, Install-OSDBuilderModule, Check-HyperV
