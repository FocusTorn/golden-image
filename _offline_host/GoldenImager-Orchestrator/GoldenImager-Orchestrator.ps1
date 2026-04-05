# GoldenImager-Orchestrator (v3.0 - Stealth Jet Edition)
# High-Fidelity UI Reconstruction: 1-to-1 Parity with GoldenImager2

Add-Type -AssemblyName PresentationFramework, WindowsBase, PresentationCore

$BaseDir = $PSScriptRoot
$ModuleDir = [System.IO.Path]::Combine($BaseDir, "src", "modules")

Import-Module (Join-Path $ModuleDir "Installer.psm1")
Import-Module (Join-Path $ModuleDir "Generator.psm1")
Import-Module (Join-Path $ModuleDir "PackerEngine.psm1")

# --- ELEVATION GUARD ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [Windows.MessageBox]::Show("CRITICAL: Stealth control plane requires Administrator elevation.", "Access Denied", "OK", "Error")
    exit
}

# --- SETTINGS MANAGEMENT ---
$SettingsPath = [System.IO.Path]::Combine($BaseDir, "settings.json")
function Load-AppSettings { if (Test-Path $SettingsPath) { return Get-Content $SettingsPath | ConvertFrom-Json -AsHashtable }; return @{ IsoUrl = ""; AdminPassword = "PackerTemp123!"; VMName = "GoldenImager-Build"; PackerVersion = "1.11.2" } }
function Save-AppSettings { $Global:Cfg | ConvertTo-Json -Depth 10 | Set-Content $SettingsPath -Force }
$Global:Cfg = Load-AppSettings

$Global:Cfg = Load-AppSettings
$PackerInstallPath = "$env:LOCALAPPDATA\Packer\packer.exe"

# --- UI STATE TRACKING ---
$Global:ActiveProcess = $null

# --- INFRASTRUCTURE HELPERS ---
function Check-HyperV {
    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
        if ($feature -and $feature.State -eq 'Enabled') { return $true }
    } catch {}
    return $false
}

# --- XAML UI AS RAW STRING (HARDENED & INLINED) ---
$xamlString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="GOLDEN IMAGER - ORCHESTRATOR [V3.0]" Height="850" Width="1250" 
        Background="#182224" WindowStartupLocation="CenterScreen" UseLayoutRounding="True">
    
    <Window.Resources>
        <!-- STEALTH JET PALETTE -->
        <SolidColorBrush x:Key="BgMain" Color="#182224"/>
        <SolidColorBrush x:Key="BgPanel" Color="#1C2427"/>
        <SolidColorBrush x:Key="BgDarker" Color="#0B0F10"/>
        <SolidColorBrush x:Key="BgCard" Color="#232D30"/>
        <SolidColorBrush x:Key="TextMain" Color="#E2E8F0"/>
        <SolidColorBrush x:Key="TextDim" Color="#94A3B8"/>
        <SolidColorBrush x:Key="AccentBrush" Color="#00CCFF"/>
        <SolidColorBrush x:Key="BorderMuted" Color="#333D40"/>
        
        <LinearGradientBrush x:Key="ContentGrad" StartPoint="0,0" EndPoint="0,1">
            <GradientStop Color="#161E20" Offset="0"/>
            <GradientStop Color="#161E20" Offset="0.66"/>
            <GradientStop Color="#0D1113" Offset="1"/>
        </LinearGradientBrush>

        <!-- COMPONENTS -->
        <Style x:Key="NavButton" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Height" Value="48"/>
            <Setter Property="Width" Value="48"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Root" Background="{TemplateBinding Background}" SnapsToDevicePixels="True">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#2A3639"/>
                            </Trigger>
                            <DataTrigger Binding="{Binding IsEnabled, RelativeSource={RelativeSource Self}}" Value="False">
                                <Setter Property="Background" Value="#12181A"/>
                                <Setter TargetName="Root" Property="BorderThickness" Value="3,0,0,0"/>
                                <Setter TargetName="Root" Property="BorderBrush" Value="{DynamicResource AccentBrush}"/>
                            </DataTrigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="ActionButton" TargetType="Button">
            <Setter Property="Background" Value="#232D30"/>
            <Setter Property="Foreground" Value="{DynamicResource TextMain}"/>
            <Setter Property="BorderBrush" Value="{DynamicResource BorderMuted}"/>
            <Setter Property="Padding" Value="20,10"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="4">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#2A3639"/>
                                <Setter Property="BorderBrush" Value="{DynamicResource AccentBrush}"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        
        <Style x:Key="ModernBox" TargetType="TextBox">
            <Setter Property="Background" Value="#0B0F10"/>
            <Setter Property="Foreground" Value="{DynamicResource TextMain}"/>
            <Setter Property="BorderBrush" Value="#333D40"/>
            <Setter Property="Padding" Value="8"/>
            <Setter Property="CaretBrush" Value="{DynamicResource AccentBrush}"/>
        </Style>

        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="{DynamicResource TextDim}"/>
            <Setter Property="Margin" Value="0,5"/>
        </Style>
    </Window.Resources>
    
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/> <!-- HEADER -->
            <RowDefinition Height="4"/>    <!-- H-DIVIDER TOP -->
            <RowDefinition Height="*"/>    <!-- BODY -->
            <RowDefinition Height="4"/>    <!-- H-DIVIDER BOTTOM -->
            <RowDefinition Height="Auto"/> <!-- STATUS -->
        </Grid.RowDefinitions>

        <!-- HEADER -->
        <Border Grid.Row="0" Padding="20,12" Background="#182224">
            <DockPanel LastChildFill="True">
                <StackPanel Orientation="Horizontal" DockPanel.Dock="Left">
                    <TextBlock Text="PIPELINE" Foreground="{DynamicResource AccentBrush}" FontSize="18" FontWeight="Black" Margin="0,0,10,0"/>
                    <TextBlock Text="ORCHESTRATOR" Foreground="{DynamicResource TextMain}" FontSize="18" FontWeight="SemiBold"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                    <StackPanel Margin="15,0">
                        <TextBlock Text="PACKER" Foreground="{DynamicResource TextDim}" FontSize="9"/>
                        <TextBlock x:Name="HUDPacker" Text="REFRESHING" Foreground="#FF4444" FontSize="11" FontWeight="Bold"/>
                    </StackPanel>
                    <StackPanel Margin="15,0">
                        <TextBlock Text="OSDBUILDER" Foreground="{DynamicResource TextDim}" FontSize="9"/>
                        <TextBlock x:Name="HUDOSD" Text="REFRESHING" Foreground="#FF4444" FontSize="11" FontWeight="Bold"/>
                    </StackPanel>
                    <StackPanel Margin="15,0">
                        <TextBlock Text="HYPER-V" Foreground="{DynamicResource TextDim}" FontSize="9"/>
                        <TextBlock x:Name="HUDHyperV" Text="REFRESHING" Foreground="#FF4444" FontSize="11" FontWeight="Bold"/>
                    </StackPanel>
                </StackPanel>
            </DockPanel>
        </Border>

        <!-- H-DIVIDER TOP -->
        <Border Grid.Row="1" BorderThickness="0,1" BorderBrush="#0D1214" Background="#2C3233"/>

        <!-- BODY -->
        <Grid Grid.Row="2">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="48"/>
                <ColumnDefinition Width="4"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- SIDEBAR -->
            <Border Grid.Column="0" Background="#1C2427">
                <StackPanel>
                    <Button x:Name="Nav_Pipeline" Style="{StaticResource NavButton}" IsEnabled="False" ToolTip="Build Pipeline">
                        <Path Data="M12 2L4.5 20.29l.71.71L12 18l6.79 3 .71-.71z" Fill="#94A3B8" Height="18" Stretch="Uniform"/>
                    </Button>
                    <Button x:Name="Nav_Config" Style="{StaticResource NavButton}" ToolTip="Configuration">
                        <Path Data="M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.09.63-.09.94s.02.64.07.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z" Fill="#94A3B8" Height="18" Stretch="Uniform"/>
                    </Button>
                </StackPanel>
            </Border>

            <!-- V-DIVIDER -->
            <Border Grid.Column="1" BorderThickness="1,0" BorderBrush="#0D1214" Background="#2C3233"/>

            <!-- CONTENT -->
            <Grid Grid.Column="2" Background="{StaticResource ContentGrad}">
                
                <!-- PIPELINE VIEW -->
                <Grid x:Name="View_Pipeline" Visibility="Visible" Margin="30">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    
                    <TextBlock Grid.Row="0" Text="BUILD PIPELINE" Foreground="{DynamicResource TextMain}" FontSize="24" FontWeight="Black" Margin="0,0,0,30"/>
                    
                    <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,30">
                        <Border Background="#232D30" BorderThickness="1" BorderBrush="#333D40" CornerRadius="6" Padding="20" Width="320">
                            <StackPanel>
                                <TextBlock Text="PIPELINE STAGES" Foreground="{DynamicResource AccentBrush}" FontWeight="Black" Margin="0,0,0,15"/>
                                <CheckBox x:Name="Stage_Customize" Content="0. Customize (UI/Tweaks)" IsChecked="True"/>
                                <CheckBox x:Name="Stage_Scoop" Content="1. Scoop Bundle" IsChecked="True"/>
                                <CheckBox x:Name="Stage_MSVC" Content="2. MSVC Build Tools" IsChecked="True"/>
                                <CheckBox x:Name="Stage_Apps" Content="3. System Apps" IsChecked="True"/>
                                <CheckBox x:Name="Stage_Rust" Content="4. Rust &amp; Linkers" IsChecked="True"/>
                                <CheckBox x:Name="Stage_Finalize" Content="5. DISM &amp; Purge" IsChecked="True"/>
                            </StackPanel>
                        </Border>
                        <StackPanel Margin="20,0,0,0" VerticalAlignment="Bottom">
                            <Button x:Name="Btn_Generate" Content=" GENERATE PAYLOAD " Style="{StaticResource ActionButton}" Margin="0,0,0,10"/>
                            <Button x:Name="Btn_Ignite" Content=" IGNITE BUILD ENGINE " Style="{StaticResource ActionButton}" Foreground="{DynamicResource AccentBrush}"/>
                        </StackPanel>
                    </StackPanel>

                    <Grid Grid.Row="2">
                        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                        <TextBlock Text="BUILD TELEMETRY" Foreground="{DynamicResource TextDim}" FontSize="10" Margin="0,0,0,8"/>
                        <TextBox x:Name="LogBox" Grid.Row="1" Style="{StaticResource ModernBox}" IsReadOnly="True" FontFamily="Consolas" VerticalScrollBarVisibility="Auto"/>
                    </Grid>
                </Grid>

                <!-- CONFIGURATION VIEW -->
                <Grid x:Name="View_Config" Visibility="Collapsed" Margin="30">
                    <StackPanel>
                        <TextBlock Text="CONFIGURATION" Foreground="{DynamicResource TextMain}" FontSize="24" FontWeight="Black" Margin="0,0,0,30"/>
                        <Border Background="#232D30" BorderThickness="1" BorderBrush="#333D40" CornerRadius="6" Padding="25">
                            <StackPanel>
                                <TextBlock Text="SOURCE ISO PATH" Foreground="{DynamicResource TextDim}" FontSize="9" Margin="0,0,0,5"/>
                                <TextBox x:Name="Set_IsoUrl" Style="{StaticResource ModernBox}" Margin="0,0,0,20"/>
                                
                                <TextBlock Text="ADMINISTRATOR PASSWORD" Foreground="{DynamicResource TextDim}" FontSize="9" Margin="0,0,0,5"/>
                                <TextBox x:Name="Set_AdminPass" Style="{StaticResource ModernBox}" Margin="0,0,0,20"/>
                                
                                <TextBlock Text="VM BUILD NAME" Foreground="{DynamicResource TextDim}" FontSize="9" Margin="0,0,0,5"/>
                                <TextBox x:Name="Set_VMName" Style="{StaticResource ModernBox}" Margin="0,0,0,25"/>
                                
                                <Button x:Name="Btn_SaveSettings" Content="SAVE SETTINGS" Style="{StaticResource ActionButton}" HorizontalAlignment="Left" Margin="0,0,0,30"/>
                                
                                <TextBlock Text="TOOL ACQUISITION" Foreground="{DynamicResource AccentBrush}" FontWeight="Black" Margin="0,0,0,15"/>
                                <StackPanel Orientation="Horizontal">
                                    <Button x:Name="GetPackerBtn" Content="ACQUIRE PACKER" Style="{StaticResource ActionButton}" Margin="0,0,10,0"/>
                                    <Button x:Name="GetOSDBtn" Content="INSTALL OSDBUILDER" Style="{StaticResource ActionButton}"/>
                                </StackPanel>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </Grid>
            </Grid>
        </Grid>

        <!-- H-DIVIDER BOTTOM -->
        <Border Grid.Row="3" BorderThickness="0,1" BorderBrush="#0D1214" Background="#1D2325"/>

        <!-- STATUS BAR -->
        <Border Grid.Row="4" Background="#1C2427" Padding="20,10">
            <Grid>
                <ProgressBar x:Name="JobProgress" Height="2" IsIndeterminate="True" Visibility="Hidden" VerticalAlignment="Top" Background="Transparent" Foreground="{DynamicResource AccentBrush}"/>
                <DockPanel Margin="0,5,0,0">
                    <TextBlock x:Name="StatusText" Text="STANDBY" Foreground="{DynamicResource TextDim}" FontSize="11" VerticalAlignment="Center"/>
                    <Button x:Name="Btn_Stop" Content=" ABORT BUILD " Style="{StaticResource ActionButton}" Foreground="#FF4444" HorizontalAlignment="Right" Visibility="Collapsed"/>
                </DockPanel>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

# --- ENGINE LOGIC ---
function Write-Log { param($msg) $LogBox.Dispatcher.Invoke([action]{ $LogBox.AppendText("$msg`r`n"); $LogBox.ScrollToEnd() }) }

# Parse UI
$Window = [Windows.Markup.XamlReader]::Parse($xamlString)

# Map Elements
$LogBox       = $Window.FindName("LogBox")
$HUDPacker    = $Window.FindName("HUDPacker"); $HUDOSD = $Window.FindName("HUDOSD"); $HUDHyperV = $Window.FindName("HUDHyperV")
$JobProgress  = $Window.FindName("JobProgress"); $Btn_Ignite = $Window.FindName("Btn_Ignite"); $Btn_Stop = $Window.FindName("Btn_Stop")
$View_Pipeline = $Window.FindName("View_Pipeline"); $View_Config = $Window.FindName("View_Config")
$Nav_Pipeline = $Window.FindName("Nav_Pipeline"); $Nav_Config = $Window.FindName("Nav_Config")
$StatusText   = $Window.FindName("StatusText")

# Map Settings
$Set_IsoUrl    = $Window.FindName("Set_IsoUrl"); $Set_AdminPass = $Window.FindName("Set_AdminPass"); $Set_VMName = $Window.FindName("Set_VMName")
$Set_IsoUrl.Text    = $Global:Cfg.IsoUrl
$Set_AdminPass.Text = $Global:Cfg.AdminPassword
$Set_VMName.Text    = $Global:Cfg.VMName

# Navigation Logic
function Show-View {
    param($viewName)
    $View_Pipeline.Visibility = if ($viewName -eq "Pipeline") { "Visible" } else { "Collapsed" }
    $View_Config.Visibility   = if ($viewName -eq "Config")   { "Visible" } else { "Collapsed" }
    $Nav_Pipeline.IsEnabled   = if ($viewName -eq "Pipeline") { $false } else { $true }
    $Nav_Config.IsEnabled     = if ($viewName -eq "Config")   { $false } else { $true }
}

$Nav_Pipeline.Add_Click({ Show-View "Pipeline" })
$Nav_Config.Add_Click({ Show-View "Config" })

# Functionality
function Refresh-HUD {
    $p = Get-Command packer -ErrorAction SilentlyContinue
    if (-not $p -and (Test-Path $PackerInstallPath)) { $p = $PackerInstallPath }
    
    if ($p -and $HUDPacker) { 
        $HUDPacker.Foreground = "#00FF41"; 
        $HUDPacker.Text = if ($p -is [string]) { "ACTIVE (LOCAL)" } else { "ACTIVE (v$($p.Version))" }
        $Btn_Ignite.IsEnabled = $true 
    }
    if ($HUDOSD -and (Get-Module -ListAvailable OSDBuilder)) { $HUDOSD.Foreground = "#00FF41"; $HUDOSD.Text = "READY" }
    if ($HUDHyperV -and (Check-HyperV)) { $HUDHyperV.Foreground = "#00FF41"; $HUDHyperV.Text = "ATTACHED" }
}

$Window.FindName("Btn_SaveSettings").Add_Click({
    $Global:Cfg.IsoUrl = $Set_IsoUrl.Text; $Global:Cfg.AdminPassword = $Set_AdminPass.Text; $Global:Cfg.VMName = $Set_VMName.Text
    Save-AppSettings; Write-Log "[OK] Stealth configuration persistent."
})

$Window.FindName("GetPackerBtn").Add_Click({
    $Btn_Ignite.IsEnabled = $false
    $JobProgress.Visibility = "Visible"
    Get-Packer -LogBox $LogBox -Version $Global:Cfg.PackerVersion
})

$Window.FindName("GetOSDBtn").Add_Click({
    $JobProgress.Visibility = "Visible"
    Install-OSDBuilderModule -LogBox $LogBox
})

$Window.FindName("Btn_Generate").Add_Click({
    Write-Log "[*] Orchestrator: Constructing stealth payload..."
    $payloadDir = [System.IO.Path]::Combine($BaseDir, "payload", "scripts")
    try {
        Stage-PayloadScripts -TargetDir $payloadDir
        $activeStages = @()
        if ($Window.FindName("Stage_Customize").IsChecked) { $activeStages += "Customize" }
        if ($Window.FindName("Stage_Scoop").IsChecked)     { $activeStages += "1_Scoop" }
        if ($Window.FindName("Stage_MSVC").IsChecked)      { $activeStages += "2_MSVC" }
        if ($Window.FindName("Stage_Apps").IsChecked)      { $activeStages += "3_System_Apps" }
        if ($Window.FindName("Stage_Rust").IsChecked)      { $activeStages += "4_Rust_Finish" }
        if ($Window.FindName("Stage_Finalize").IsChecked)  { $activeStages += "5_Finalize" }

        New-BootstrapDevPs1 -OutputPath ([System.IO.Path]::Combine($payloadDir, "BootstrapDev.ps1")) -Stages $activeStages
        New-OrchestratorUnattendXml -OutputPath ([System.IO.Path]::Combine($BaseDir, "payload", "autounattend.xml")) -Settings $Global:Cfg -BypassOptions @{ BypassTPM = $true; BypassSecureBoot = $true }
        Write-Log "[SUCCESS] Stealth payload ready."
    } catch { Write-Log "[ERROR] Payload assembly failed: $($_.Exception.Message)" }
})

$Btn_Ignite.Add_Click({
    $template = [System.IO.Path]::Combine($BaseDir, "templates", "vhd-orchestrator.pkr.hcl")
    $vars = @{ iso_url = $Global:Cfg.IsoUrl; vm_name = $Global:Cfg.VMName; admin_password = $Global:Cfg.AdminPassword }
    
    # Resolve the active Packer executable path
    $p = Get-Command packer -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    if (-not $p -and (Test-Path $PackerInstallPath)) { $p = $PackerInstallPath }
    if (-not $p) { Write-Log "[ERROR] Packer engine not found. Please click 'ACQUIRE PACKER' in Settings."; return }

    $Global:ActiveProcess = Start-PackerBuildAsync -PackerTemplatePath $template -PackerExePath $p -LogTextBox $LogBox -Variables $vars
    $Btn_Ignite.IsEnabled = $false; $Btn_Stop.Visibility = "Visible"; $JobProgress.Visibility = "Visible"; $StatusText.Text = "BUILD IN PROGRESS"
    Write-Log "[i] Orchestration Heartbeat: Engine launched. Waiting for VM lifecycle events..."

    # Register for Exit event to reset HUD
    Register-ObjectEvent -InputObject $Global:ActiveProcess -EventName "Exited" -Action {
        $Window.Dispatcher.Invoke([action]{
            $StatusText.Text = "STANDBY"
            $JobProgress.Visibility = "Hidden"
            $Btn_Stop.Visibility = "Collapsed"
            $Btn_Ignite.IsEnabled = $true
        })
    } | Out-Null
})

$Btn_Stop.Add_Click({
    if ($Global:ActiveProcess) {
        Write-Log "[!] ABORT: Terminating build engine..."
        try { $Global:ActiveProcess.Kill(); Write-Log "[OK] Engine offline." } catch { Write-Host "[ERR] $($_.Exception.Message)" }
        $Btn_Stop.Visibility = "Collapsed"; $Btn_Ignite.IsEnabled = $true; $StatusText.Text = "ABORTING"
    }
})

# Sync Timer
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(2)
$timer.Add_Tick({ Refresh-HUD })
$timer.Start()

Refresh-HUD
$Window.ShowDialog() | Out-Null
