# GuiFork: Import undo/revert regfile (from Regfiles/Undo/ or Regfiles/Sysprep/Undo/)
function ImportRegistryFileForRevert {
    param (
        $message,
        $path
    )

    $undoPath = "Undo\$path"
    $mainPath = "$script:RegfilesPath\$undoPath"
    $sysprepPath = "$script:RegfilesPath\Sysprep\$undoPath"

    Write-Host $message

    # Undo files are in Undo/ subfolder; Sysprep may not have Undo copies
    if (-not (Test-Path $mainPath)) {
        $mainPath = "$script:RegfilesPath\$path"
        $sysprepPath = "$script:RegfilesPath\Sysprep\$path"
        $undoPath = $path
    }
    if (-not (Test-Path $mainPath)) {
        Write-Host "Error: Unable to find registry revert file: $path" -ForegroundColor Red
        Write-Host ""
        return
    }

    $global:LASTEXITCODE = 0

    if ($script:Params.ContainsKey("Sysprep") -or $script:Params.ContainsKey("User")) {
        $hiveDatPath = if ($script:Params.ContainsKey("Sysprep")) {
            GetUserDirectory -userName "Default" -fileName "NTUSER.DAT"
        } else {
            GetUserDirectory -userName $script:Params.Item("User") -fileName "NTUSER.DAT"
        }
        $regFilePath = if (Test-Path $sysprepPath) { $sysprepPath } else { $mainPath }
        $regResult = Invoke-NonBlocking -ScriptBlock {
            param($datPath, $regFilePath)
            $global:LASTEXITCODE = 0
            reg load "HKU\Default" $datPath | Out-Null
            $output = reg import $regFilePath 2>&1
            $code = $LASTEXITCODE
            reg unload "HKU\Default" | Out-Null
            return @{ Output = $output; ExitCode = $code }
        } -ArgumentList @($hiveDatPath, $regFilePath)
    }
    else {
        $regResult = Invoke-NonBlocking -ScriptBlock {
            param($regFilePath)
            $global:LASTEXITCODE = 0
            $output = reg import $regFilePath 2>&1
            return @{ Output = $output; ExitCode = $LASTEXITCODE }
        } -ArgumentList $mainPath
    }

    $regOutput = $regResult.Output
    $hasSuccess = $regResult.ExitCode -eq 0

    if ($regOutput) {
        foreach ($line in $regOutput) {
            $lineText = if ($line -is [System.Management.Automation.ErrorRecord]) { $line.Exception.Message } else { $line.ToString() }
            if ($lineText -and $lineText.Length -gt 0) {
                if ($hasSuccess) { Write-Host $lineText }
                else { Write-Host $lineText -ForegroundColor Red }
            }
        }
    }
    if (-not $hasSuccess) {
        Write-Host "Failed importing registry revert file: $path" -ForegroundColor Red
    }
    Write-Host ""
}
