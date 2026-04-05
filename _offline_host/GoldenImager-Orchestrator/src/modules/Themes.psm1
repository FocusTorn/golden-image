$Styles = @"
    <!-- INDUSTRIAL SLAB PALETTE (SYNCED TO GOLDENIMAGER2) -->
    <SolidColorBrush x:Key="BgMain" Color="#182224"/>
    <SolidColorBrush x:Key="BgPanel" Color="#1C2427"/>
    <SolidColorBrush x:Key="BgDarker" Color="#0B0F10"/>
    <SolidColorBrush x:Key="BgCard" Color="#232D30"/>
    <SolidColorBrush x:Key="TextMain" Color="#E2E8F0"/>
    <SolidColorBrush x:Key="TextDim" Color="#94A3B8"/>
    <SolidColorBrush x:Key="AccentBrush" Color="#00CCFF"/>
    <SolidColorBrush x:Key="BorderMuted" Color="#333D40"/>
    <SolidColorBrush x:Key="DividerEdge" Color="#0D1214"/>
    <SolidColorBrush x:Key="DividerCore" Color="#2C3233"/>

    <!-- NAVIGATION / SIDEBAR BUTTONS -->
    <Style x:Key="NavButton" TargetType="Button">
        <Setter Property="Background" Value="Transparent"/>
        <Setter Property="Foreground" Value="{DynamicResource TextDim}"/>
        <Setter Property="BorderThickness" Value="0"/>
        <Setter Property="Padding" Value="15,12"/>
        <Setter Property="HorizontalContentAlignment" Value="Left"/>
        <Setter Property="Template">
            <Setter.Value>
                <ControlTemplate TargetType="Button">
                    <Border x:Name="Root" Background="{TemplateBinding Background}" BorderThickness="3,0,0,0" BorderBrush="Transparent">
                        <ContentPresenter Margin="{TemplateBinding Padding}" HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center"/>
                    </Border>
                    <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter Property="Background" Value="#2A3639"/>
                            <Setter Property="Foreground" Value="{DynamicResource TextMain}"/>
                        </Trigger>
                        <DataTrigger Binding="{Binding IsEnabled, RelativeSource={RelativeSource Self}}" Value="False">
                            <Setter TargetName="Root" Property="BorderBrush" Value="{DynamicResource AccentBrush}"/>
                            <Setter Property="Background" Value="#232D30"/>
                            <Setter Property="Foreground" Value="{DynamicResource AccentBrush}"/>
                        </DataTrigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>

    <!-- ACTION BUTTONS (INDUSTRIAL SLAB) -->
    <Style x:Key="ModernButton" TargetType="Button">
        <Setter Property="Background" Value="#232D30"/>
        <Setter Property="Foreground" Value="{DynamicResource TextMain}"/>
        <Setter Property="BorderThickness" Value="1"/>
        <Setter Property="BorderBrush" Value="{DynamicResource BorderMuted}"/>
        <Setter Property="Padding" Value="15,8"/>
        <Setter Property="Template">
            <Setter.Value>
                <ControlTemplate TargetType="Button">
                    <Grid>
                        <Border x:Name="Shadow" Margin="0,1,0,-1" Background="#000000" Opacity="0.1" CornerRadius="4"/>
                        <Border x:Name="Base" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="4">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </Grid>
                    <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter Property="Background" Value="#2A3639"/>
                            <Setter Property="BorderBrush" Value="{DynamicResource AccentBrush}"/>
                        </Trigger>
                        <Trigger Property="IsPressed" Value="True">
                            <Setter Property="Background" Value="#1C2427"/>
                            <Setter TargetName="Base" Property="Padding" Value="1,1,0,0"/>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>

    <!-- INDUSTRIAL COMPONENTS -->
    <Style TargetType="CheckBox">
        <Setter Property="Foreground" Value="{DynamicResource TextMain}"/>
        <Setter Property="Margin" Value="0,5"/>
    </Style>

    <Style x:Key="LogBox" TargetType="TextBox">
        <Setter Property="Background" Value="#0B0F10"/>
        <Setter Property="Foreground" Value="#00FF41"/>
        <Setter Property="FontFamily" Value="Consolas"/>
        <Setter Property="Padding" Value="12"/>
        <Setter Property="IsReadOnly" Value="True"/>
        <Setter Property="BorderThickness" Value="0"/>
        <Setter Property="VerticalScrollBarVisibility" Value="Auto"/>
    </Style>

    <!-- HUD TEXT -->
    <Style x:Key="HudLabel" TargetType="TextBlock">
        <Setter Property="Foreground" Value="{DynamicResource TextDim}"/>
        <Setter Property="FontSize" Value="10"/>
        <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>

    <Style x:Key="HudValue" TargetType="TextBlock">
        <Setter Property="Foreground" Value="#FF4444"/>
        <Setter Property="FontSize" Value="12"/>
        <Setter Property="FontWeight" Value="Bold"/>
    </Style>
"@

function Get-ThemeStyles { return $Global:Styles }
Export-ModuleMember -Function Get-ThemeStyles
