# Returns $true if WPF GUI is available (desktop session with display); $false otherwise (Server Core, SSH, remoting, etc.)
function Test-WpfAvailable {
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

# Processes all pending WPF window messages (input, render, etc.) to keep the UI responsive
# during long-running operations on the UI thread. Equivalent to Application.DoEvents().
function DoEvents {
    if (-not $script:GuiWindow) { return }
    $frame = [System.Windows.Threading.DispatcherFrame]::new()
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke(
        [System.Windows.Threading.DispatcherPriority]::Background,
        [System.Windows.Threading.DispatcherOperationCallback]{
            param($f)
            $f.Continue = $false
            return $null
        },
        $frame
    )
    [System.Windows.Threading.Dispatcher]::PushFrame($frame)
}


# Runs a scriptblock in a background PowerShell runspace while keeping the UI responsive.
# In GUI mode, the work executes on a separate thread and the UI thread pumps messages (~60fps).
# In CLI mode, the scriptblock runs directly in the current session.
function Invoke-NonBlocking {
    param(
        [scriptblock]$ScriptBlock,
        [object[]]$ArgumentList = @()
    )

    if (-not $script:GuiWindow) {
        return (& $ScriptBlock @ArgumentList)
    }

    $ps = [powershell]::Create()
    try {
        $null = $ps.AddScript($ScriptBlock.ToString())
        foreach ($arg in $ArgumentList) {
            $null = $ps.AddArgument($arg)
        }

        $handle = $ps.BeginInvoke()

        while (-not $handle.IsCompleted) {
            DoEvents
            Start-Sleep -Milliseconds 16
        }

        $result = $ps.EndInvoke($handle)

        if ($result.Count -eq 0) { return $null }
        if ($result.Count -eq 1) { return $result[0] }
        return @($result)
    }
    finally {
        $ps.Dispose()
    }
}
