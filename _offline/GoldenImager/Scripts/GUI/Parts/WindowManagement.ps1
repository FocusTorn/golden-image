# Implement window resize functionality
function Initialize-WindowResize {
    param($window)
    $resizeLeft = $window.FindName('ResizeLeft')
    $resizeRight = $window.FindName('ResizeRight')
    $resizeTop = $window.FindName('ResizeTop')
    $resizeBottom = $window.FindName('ResizeBottom')
    $resizeTopLeft = $window.FindName('ResizeTopLeft')
    $resizeTopRight = $window.FindName('ResizeTopRight')
    $resizeBottomLeft = $window.FindName('ResizeBottomLeft')
    $resizeBottomRight = $window.FindName('ResizeBottomRight')

    $script:resizing = $false
    $script:resizeEdges = $null
    $script:resizeStart = $null
    $script:windowStart = $null
    $script:resizeElement = $null

    $resizeHandler = {
        param($evtSender, $e)
        
        $script:resizing = $true
        $script:resizeElement = $evtSender
        $script:resizeStart = [System.Windows.Forms.Cursor]::Position
        $script:windowStart = @{
            Left = $window.Left
            Top = $window.Top
            Width = $window.ActualWidth
            Height = $window.ActualHeight
        }
        
        # Parse direction tag into edge flags for cleaner resize logic
        $direction = $evtSender.Tag
        $script:resizeEdges = @{
            Left = $direction -match 'Left'
            Right = $direction -match 'Right'
            Top = $direction -match 'Top'
            Bottom = $direction -match 'Bottom'
        }
        
        $evtSender.CaptureMouse()
        $e.Handled = $true
    }

    $moveHandler = {
        param($evtSender, $e)
        if (-not $script:resizing) { return }
        
        $current = [System.Windows.Forms.Cursor]::Position
        $deltaX = $current.X - $script:resizeStart.X
        $deltaY = $current.Y - $script:resizeStart.Y

        # Handle horizontal resize
        if ($script:resizeEdges.Left) {
            $newWidth = [Math]::Max($window.MinWidth, $script:windowStart.Width - $deltaX)
            if ($newWidth -ne $window.Width) {
                $window.Left = $script:windowStart.Left + ($script:windowStart.Width - $newWidth)
                $window.Width = $newWidth
            }
        }
        elseif ($script:resizeEdges.Right) {
            $window.Width = [Math]::Max($window.MinWidth, $script:windowStart.Width + $deltaX)
        }

        # Handle vertical resize
        if ($script:resizeEdges.Top) {
            $newHeight = [Math]::Max($window.MinHeight, $script:windowStart.Height - $deltaY)
            if ($newHeight -ne $window.Height) {
                $window.Top = $script:windowStart.Top + ($script:windowStart.Height - $newHeight)
                $window.Height = $newHeight
            }
        }
        elseif ($script:resizeEdges.Bottom) {
            $window.Height = [Math]::Max($window.MinHeight, $script:windowStart.Height + $deltaY)
        }
        
        $e.Handled = $true
    }

    $releaseHandler = {
        param($evtSender, $e)
        if ($script:resizing -and $script:resizeElement) {
            $script:resizing = $false
            $script:resizeEdges = $null
            $script:resizeElement.ReleaseMouseCapture()
            $script:resizeElement = $null
            $e.Handled = $true
        }
    }

    # Set tags and add event handlers for resize borders
    $resizeLeft.Tag = 'Left'; $resizeLeft.Add_PreviewMouseLeftButtonDown($resizeHandler); $resizeLeft.Add_MouseMove($moveHandler); $resizeLeft.Add_MouseLeftButtonUp($releaseHandler)
    $resizeRight.Tag = 'Right'; $resizeRight.Add_PreviewMouseLeftButtonDown($resizeHandler); $resizeRight.Add_MouseMove($moveHandler); $resizeRight.Add_MouseLeftButtonUp($releaseHandler)
    $resizeTop.Tag = 'Top'; $resizeTop.Add_PreviewMouseLeftButtonDown($resizeHandler); $resizeTop.Add_MouseMove($moveHandler); $resizeTop.Add_MouseLeftButtonUp($releaseHandler)
    $resizeBottom.Tag = 'Bottom'; $resizeBottom.Add_PreviewMouseLeftButtonDown($resizeHandler); $resizeBottom.Add_MouseMove($moveHandler); $resizeBottom.Add_MouseLeftButtonUp($releaseHandler)
    $resizeTopLeft.Tag = 'TopLeft'; $resizeTopLeft.Add_PreviewMouseLeftButtonDown($resizeHandler); $resizeTopLeft.Add_MouseMove($moveHandler); $resizeTopLeft.Add_MouseLeftButtonUp($releaseHandler)
    $resizeTopRight.Tag = 'TopRight'; $resizeTopRight.Add_PreviewMouseLeftButtonDown($resizeHandler); $resizeTopRight.Add_MouseMove($moveHandler); $resizeTopRight.Add_MouseLeftButtonUp($releaseHandler)
    $resizeBottomLeft.Tag = 'BottomLeft'; $resizeBottomLeft.Add_PreviewMouseLeftButtonDown($resizeHandler); $resizeBottomLeft.Add_MouseMove($moveHandler); $resizeBottomLeft.Add_MouseLeftButtonUp($releaseHandler)
    $resizeBottomRight.Tag = 'BottomRight'; $resizeBottomRight.Add_PreviewMouseLeftButtonDown($resizeHandler); $resizeBottomRight.Add_MouseMove($moveHandler); $resizeBottomRight.Add_MouseLeftButtonUp($releaseHandler)
}

function Initialize-WindowClosing {
    param($window, $windowBoundsPath)
    $window.Add_Closing({
        $script:CancelRequested = $true
        try {
            if ($window.WindowState -eq 'Normal') {
                $bounds = @{ Left = $window.Left; Top = $window.Top; Width = $window.Width; Height = $window.Height }
                $bounds | ConvertTo-Json | Set-Content -Path $windowBoundsPath -Encoding UTF8 -Force
            }
        } catch { }
    })
}
