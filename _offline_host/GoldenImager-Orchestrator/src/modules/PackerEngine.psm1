function Start-PackerBuildAsync {
    param (
        [string]$PackerTemplatePath,
        [string]$PackerExePath = "packer.exe",
        [object]$LogTextBox,
        [hashtable]$Variables
    )

    # 1. Construct Variable Flags with accurate quoting
    $varFlags = ""
    if ($Variables) {
        foreach ($key in $Variables.Keys) {
            $val = $Variables[$key]
            $varFlags += "-var `"$key=$val`" "
        }
    }

    # 2. Get Absolute Template Path for safety
    $fullTemplatePath = [System.IO.Path]::GetFullPath($PackerTemplatePath)
    if (-not (Test-Path $fullTemplatePath)) {
        throw "CRITICAL: Packer template missing at $fullTemplatePath"
    }

    # 3. Initialize the .NET Process
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo.FileName = $PackerExePath
    $process.StartInfo.WorkingDirectory = [System.IO.Path]::GetDirectoryName($fullTemplatePath)
    $process.StartInfo.Arguments = "build $varFlags -on-error=ask `"$fullTemplatePath`""
    
    $LogTextBox.AppendText("[DEBUG] Working Directory: $($process.StartInfo.WorkingDirectory)`r`n")
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    $process.StartInfo.CreateNoWindow = $true
    $process.EnableRaisingEvents = $true

    # Event Subscriptions
    $outEvent = Register-ObjectEvent -InputObject $process -EventName "OutputDataReceived" -Action {
        $line = $Event.SourceEventArgs.Data
        if (![string]::IsNullOrWhiteSpace($line)) {
            $LogTextBox.Dispatcher.Invoke([action]{
                $LogTextBox.AppendText("$line`r`n")
                $LogTextBox.ScrollToEnd()
            })
        }
    }

    $errEvent = Register-ObjectEvent -InputObject $process -EventName "ErrorDataReceived" -Action {
        $line = $Event.SourceEventArgs.Data
        if (![string]::IsNullOrWhiteSpace($line)) {
            $LogTextBox.Dispatcher.Invoke([action]{
                $LogTextBox.AppendText("[PKR-ERROR]: $line`r`n")
                $LogTextBox.ScrollToEnd()
            })
        }
    }

    $exitEvent = Register-ObjectEvent -InputObject $process -EventName "Exited" -Action {
        $LogTextBox.Dispatcher.Invoke([action]{
            $LogTextBox.AppendText("`r`n[+] BUILD ENGINE: PROCESS TERMINATED.`r`n")
            $LogTextBox.ScrollToEnd()
        })
        Unregister-Event -SourceIdentifier $outEvent.Name
        Unregister-Event -SourceIdentifier $errEvent.Name
        Unregister-Event -SourceIdentifier $exitEvent.Name
        $process.Dispose()
    }

    $LogTextBox.AppendText("[*] Ignite: Building Image with Variables: $varFlags`r`n")
    $process.Start() | Out-Null
    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()

    # Return process object for cancellation support in GUI
    return $process
}

Export-ModuleMember -Function Start-PackerBuildAsync
