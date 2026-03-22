# ------------------------------------------------------------------------------
# Typography configuration - customize fonts, colors, weights, spacing for UI text
# Edit these values to change the look of card titles, subtitles, labels, etc.
# ------------------------------------------------------------------------------
$script:Typography = @{
    # Base font family for text (icons use IconFontFamily)
    FontFamily = "Segoe UI"
    IconFontFamily = "Segoe Fluent Icons"

    # Page title (e.g. "Golden Imager" on splash)
    PageTitleFontSize = 28
    PageTitleFontWeight = "Bold"
    PageTitleFontFamily = "Segoe UI"
    PageTitleColor = $null  # null = use FgColor

    # Tab titles (e.g. "App Removal", "System Tweaks")
    TabTitleFontSize = 20
    TabTitleFontWeight = "Bold"
    TabTitleFontFamily = "Segoe UI"
    TabTitleColor = $null

    # Card titles (e.g. "Connection Settings", "Stages Audit", "Execution Options")
    CardTitleFontSize = 16
    CardTitleFontWeight = "Bold"
    CardTitleFontFamily = "Segoe UI"
    CardTitleColor = $null
    CardTitleMargin = "0,0,0,13"

    # Card subtitle / description (e.g. "Select which apps you want to remove...")
    CardSubtitleFontSize = 13
    CardSubtitleFontWeight = "Normal"
    CardSubtitleFontFamily = "Segoe UI"
    CardSubtitleColor = $null

    # Labels (e.g. "App Profile:", "Tweak Profile:", "R", "P", "L" column headers)
    LabelFontSize = 12
    LabelFontWeight = "Normal"
    LabelFontFamily = "Segoe UI"
    LabelColor = $null

    # Small labels (e.g. R/P/L column headers)
    LabelSmallFontSize = 11
    LabelSmallFontWeight = "Normal"

    # Table headers (e.g. "Name", "Description", "App ID")
    TableHeaderFontSize = 16
    TableHeaderFontWeight = "SemiBold"
    TableHeaderFontFamily = "Segoe UI"
    TableHeaderColor = $null

    # Body text (descriptions, status messages)
    BodyFontSize = 12
    BodyFontWeight = "Normal"
    BodyFontFamily = "Segoe UI"
    BodyColor = $null

    # Search box placeholder and input
    SearchFontSize = 13
    SearchFontWeight = "Normal"
    SearchPlaceholderOpacity = 0.5

    # Primary button text (e.g. "Apply Changes", "Custom Setup")
    ButtonPrimaryFontSize = 18
    ButtonPrimaryFontWeight = "SemiBold"
    ButtonSecondaryFontSize = 14
    ButtonSecondaryFontWeight = "Normal"

    # Nav buttons ("Back", "Next")
    NavButtonFontSize = 14
    NavButtonFontWeight = "Normal"

    # Help link text
    HelpLinkFontSize = 12
    HelpLinkFontWeight = "Bold"

    # Character spacing (hundredths of em, 0 = default, 100 = 0.1em wider)
    CharacterSpacing = 0
}

# ------------------------------------------------------------------------------
# Taskbar icon - DLL path and icon index for the window/taskbar icon
# ------------------------------------------------------------------------------
$script:TaskbarIcon = @{
    DllPath   = (Join-Path $env:SystemRoot "System32\imageres.dll")  # Full path to DLL containing icons
    IconIndex = 251                                                   # Icon index within the DLL
}
