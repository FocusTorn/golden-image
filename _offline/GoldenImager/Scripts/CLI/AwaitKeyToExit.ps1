function AwaitKeyToExit {
    if (-not $Silent) {
        Write-Output ""
        Write-Output "Press any key to exit..."
        $null = [System.Console]::ReadKey()
    }

    Stop-Transcript -ErrorAction SilentlyContinue
    if (Get-Command Copy-LogToReturnPath -ErrorAction SilentlyContinue) {
        Copy-LogToReturnPath
    }
    Exit
}
