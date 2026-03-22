# Extract icon from imageres.dll for taskbar; AppUserModelID to separate from PowerShell
$iconCode = @'
using System;
using System.Runtime.InteropServices;
public class Shell32_Extract {
    [DllImport("Shell32.dll", EntryPoint="ExtractIconExW", CharSet=CharSet.Unicode, ExactSpelling=true, CallingConvention=CallingConvention.StdCall)]
    public static extern int ExtractIconEx(string lpszFile, int iconIndex, out IntPtr phiconLarge, out IntPtr phiconSmall, int nIcons);
}
'@
$appIdCode = @'
using System;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
public class PSAppID {
    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99")]
    private interface IPropertyStore {
        uint GetCount([Out] out uint cProps);
        uint GetAt([In] uint iProp, out PropertyKey pkey);
        uint GetValue([In] ref PropertyKey key, [Out] PropVariant pv);
        uint SetValue([In] ref PropertyKey key, [In] PropVariant pv);
        uint Commit();
    }
    [StructLayout(LayoutKind.Sequential, Pack = 4)]
    public struct PropertyKey {
        private Guid formatId;
        private Int32 propertyId;
        public PropertyKey(string formatId, Int32 propertyId) { this.formatId = new Guid(formatId); this.propertyId = propertyId; }
    }
    [StructLayout(LayoutKind.Explicit)]
    public class PropVariant : IDisposable {
        [FieldOffset(0)] ushort valueType;
        [FieldOffset(8)] IntPtr ptr;
        public PropVariant(string value) {
            if (value == null) throw new ArgumentException("Failed to set value.");
            valueType = (ushort)VarEnum.VT_LPWSTR;
            ptr = Marshal.StringToCoTaskMemUni(value);
        }
        public void Dispose() { PropVariantClear(this); GC.SuppressFinalize(this); }
    }
    [DllImport("Ole32.dll", PreserveSig = false)]
    private static extern void PropVariantClear([In, Out] PropVariant pvar);
    [DllImport("shell32.dll")]
    private static extern int SHGetPropertyStoreForWindow(IntPtr hwnd, ref Guid iid, [Out, MarshalAs(UnmanagedType.Interface)] out IPropertyStore propertyStore);
    public static void SetAppIdForWindow(IntPtr hwnd, string appId) {
        Guid iid = new Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99");
        IPropertyStore prop;
        if (SHGetPropertyStoreForWindow(hwnd, ref iid, out prop) == 0) {
            PropertyKey key = new PropertyKey("{9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3}", 5);
            PropVariant pv = new PropVariant(appId);
            prop.SetValue(ref key, pv);
            Marshal.ReleaseComObject(prop);
        }
    }
}
'@
if (-not ([System.Management.Automation.PSTypeName]'Shell32_Extract').Type) {
    Add-Type -TypeDefinition $iconCode -ErrorAction SilentlyContinue
}
if (-not ([System.Management.Automation.PSTypeName]'PSAppID').Type) {
    Add-Type -TypeDefinition $appIdCode -ErrorAction SilentlyContinue
}

# Apply typography config from $script:Typography to window.Resources
function Apply-TypographyResources {
    param($window)
    $tw = $script:Typography
    $fwMap = @{
        Normal = [System.Windows.FontWeights]::Normal
        Light = [System.Windows.FontWeights]::Light
        SemiBold = [System.Windows.FontWeights]::SemiBold
        Bold = [System.Windows.FontWeights]::Bold
        ExtraBold = [System.Windows.FontWeights]::ExtraBold
    }
    $getFw = { param($k, $d) if ($fwMap[$k]) { $fwMap[$k] } else { $d } }
    $fgBrush = $window.Resources["FgColor"]
    $brush = { param($c) if ($c) { [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString($c)) } else { $fgBrush } }
    $add = { param($k, $v) if (-not $window.Resources.Contains($k)) { $window.Resources.Add($k, $v) } }
    & $add "PageTitleFontSize" ([double]$tw.PageTitleFontSize)
    & $add "PageTitleFontWeight" (& $getFw $tw.PageTitleFontWeight ([System.Windows.FontWeights]::Bold))
    & $add "PageTitleFontFamily" ([System.Windows.Media.FontFamily]::new($tw.PageTitleFontFamily))
    & $add "PageTitleColor" (& $brush $tw.PageTitleColor)
    & $add "TabTitleFontSize" ([double]$tw.TabTitleFontSize)
    & $add "TabTitleFontWeight" (& $getFw $tw.TabTitleFontWeight ([System.Windows.FontWeights]::Bold))
    & $add "TabTitleFontFamily" ([System.Windows.Media.FontFamily]::new($tw.TabTitleFontFamily))
    & $add "TabTitleColor" (& $brush $tw.TabTitleColor)
    & $add "CardTitleFontSize" ([double]$tw.CardTitleFontSize)
    & $add "CardTitleFontWeight" (& $getFw $tw.CardTitleFontWeight ([System.Windows.FontWeights]::Bold))
    & $add "CardTitleFontFamily" ([System.Windows.Media.FontFamily]::new($tw.CardTitleFontFamily))
    & $add "CardTitleColor" (& $brush $tw.CardTitleColor)
    $marginParts = $tw.CardTitleMargin -split ','
    $cardTitleMargin = if ($marginParts.Count -ge 4) { [System.Windows.Thickness]::new([double]$marginParts[0], [double]$marginParts[1], [double]$marginParts[2], [double]$marginParts[3]) } else { [System.Windows.Thickness]::new(0, 0, 0, 13) }
    & $add "CardTitleMargin" $cardTitleMargin
    & $add "CardSubtitleFontSize" ([double]$tw.CardSubtitleFontSize)
    & $add "CardSubtitleFontWeight" (& $getFw $tw.CardSubtitleFontWeight ([System.Windows.FontWeights]::Normal))
    & $add "CardSubtitleFontFamily" ([System.Windows.Media.FontFamily]::new($tw.CardSubtitleFontFamily))
    & $add "CardSubtitleColor" (& $brush $tw.CardSubtitleColor)
    & $add "LabelFontSize" ([double]$tw.LabelFontSize)
    & $add "LabelFontWeight" (& $getFw $tw.LabelFontWeight ([System.Windows.FontWeights]::Normal))
    & $add "LabelFontFamily" ([System.Windows.Media.FontFamily]::new($tw.LabelFontFamily))
    & $add "LabelColor" (& $brush $tw.LabelColor)
    & $add "LabelSmallFontSize" ([double]$tw.LabelSmallFontSize)
    & $add "LabelSmallFontWeight" (& $getFw $tw.LabelSmallFontWeight ([System.Windows.FontWeights]::Normal))
    & $add "TableHeaderFontSize" ([double]$tw.TableHeaderFontSize)
    & $add "TableHeaderFontWeight" (& $getFw $tw.TableHeaderFontWeight ([System.Windows.FontWeights]::SemiBold))
    & $add "TableHeaderFontFamily" ([System.Windows.Media.FontFamily]::new($tw.TableHeaderFontFamily))
    & $add "TableHeaderColor" (& $brush $tw.TableHeaderColor)
    & $add "BodyFontSize" ([double]$tw.BodyFontSize)
    & $add "BodyFontWeight" (& $getFw $tw.BodyFontWeight ([System.Windows.FontWeights]::Normal))
    & $add "BodyFontFamily" ([System.Windows.Media.FontFamily]::new($tw.BodyFontFamily))
    & $add "BodyColor" (& $brush $tw.BodyColor)
    & $add "SearchFontSize" ([double]$tw.SearchFontSize)
    & $add "SearchFontWeight" (& $getFw $tw.SearchFontWeight ([System.Windows.FontWeights]::Normal))
    & $add "SearchPlaceholderOpacity" ([double]$tw.SearchPlaceholderOpacity)
    & $add "ButtonPrimaryFontSize" ([double]$tw.ButtonPrimaryFontSize)
    & $add "ButtonPrimaryFontWeight" (& $getFw $tw.ButtonPrimaryFontWeight ([System.Windows.FontWeights]::SemiBold))
    & $add "ButtonSecondaryFontSize" ([double]$tw.ButtonSecondaryFontSize)
    & $add "ButtonSecondaryFontWeight" (& $getFw $tw.ButtonSecondaryFontWeight ([System.Windows.FontWeights]::Normal))
    & $add "NavButtonFontSize" ([double]$tw.NavButtonFontSize)
    & $add "NavButtonFontWeight" (& $getFw $tw.NavButtonFontWeight ([System.Windows.FontWeights]::Normal))
    & $add "HelpLinkFontSize" ([double]$tw.HelpLinkFontSize)
    & $add "HelpLinkFontWeight" (& $getFw $tw.HelpLinkFontWeight ([System.Windows.FontWeights]::Bold))
    & $add "CustomSetupFontSize" ([double]$tw.CustomSetupFontSize)
    & $add "CustomSetupFontWeight" (& $getFw $tw.CustomSetupFontWeight ([System.Windows.FontWeights]::SemiBold))
    & $add "IconFontFamily" ([System.Windows.Media.FontFamily]::new($tw.IconFontFamily))
    & $add "BaseFontFamily" ([System.Windows.Media.FontFamily]::new($tw.FontFamily))
    & $add "TypographyCharacterSpacing" ([int]$tw.CharacterSpacing)
}
