# Import & execute regfile (OVERRIDE: Supports both Foundation and Root Regfiles)
function ImportRegistryFile {
    param (
        $message,
        $path
    )

    Write-Host $message

    # Search paths: 1. Root/Regfiles, 2. Foundation/Regfiles
    $searchPaths = @($script:CustomRegfilesPath, $script:RegfilesPath)
    
    $resolvedPath = $null
    $resolvedSysprepPath = $null

    foreach ($basePath in $searchPaths) {
        $p = Join-Path $basePath $path
        $sp = Join-Path $basePath "Sysprep\$path"
        if ((Test-Path $p) -and (Test-Path $sp)) {
            $resolvedPath = $p
            $resolvedSysprepPath = $sp
            break
        }
    }

    if (-not $resolvedPath) {
        Write-Host "Error: Unable to find registry file: $path in any Regfiles directory" -ForegroundColor Red
        Write-Host ""
        return
    }

    # Reset exit code before running reg.exe for reliable success detection
    $global:LASTEXITCODE = 0

    if ($script:Params.ContainsKey("Sysprep") -or $script:Params.ContainsKey("User")) {
        # Sysprep targets Default user, User targets the specified user
        $hiveDatPath = if ($script:Params.ContainsKey("Sysprep")) {
            GetUserDirectory -userName "Default" -fileName "NTUSER.DAT"
        } else {
            GetUserDirectory -userName $script:Params.Item("User") -fileName "NTUSER.DAT"
        }

        $regResult = Invoke-NonBlocking -ScriptBlock {
            param($datPath, $regFilePath)
            $global:LASTEXITCODE = 0
            reg load "HKU\Default" $datPath | Out-Null
            $output = reg import $regFilePath 2>&1
            $code = $LASTEXITCODE
            reg unload "HKU\Default" | Out-Null
            return @{ Output = $output; ExitCode = $code }
        } -ArgumentList @($hiveDatPath, $resolvedSysprepPath)
    }
    else {
        $regResult = Invoke-NonBlocking -ScriptBlock {
            param($regFilePath)
            $global:LASTEXITCODE = 0
            $output = reg import $regFilePath 2>&1
            return @{ Output = $output; ExitCode = $LASTEXITCODE }
        } -ArgumentList $resolvedPath
    }

    $regOutput = $regResult.Output
    $hasSuccess = $regResult.ExitCode -eq 0
    
    if ($regOutput) {
        foreach ($line in $regOutput) {
            $lineText = if ($line -is [System.Management.Automation.ErrorRecord]) { $line.Exception.Message } else { $line.ToString() }
            if ($lineText -and $lineText.Length -gt 0) {
                if ($hasSuccess) {
                    Write-Host $lineText
                }
                else {
                    Write-Host $lineText -ForegroundColor Red
                }
            }
        }
    }

    if (-not $hasSuccess) {
        Write-Host "Failed importing registry file: $path" -ForegroundColor Red
    }

    Write-Host ""
}
