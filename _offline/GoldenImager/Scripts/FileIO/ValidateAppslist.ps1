# Returns a validated list of apps. Overlay: allows apps not in Apps.json (audit mode "not listed" apps).
# Remove-AppxPackage can remove any app by name; no need to restrict to curated list.
function ValidateAppslist {
    param (
        $appsList
    )

    $validatedAppsList = @()
    foreach ($app in $appsList) {
        $app = $app.Trim()
        $appString = $app.Trim('*')
        if ($appString.Length -gt 0) {
            $validatedAppsList += $appString
        }
    }
    return $validatedAppsList
}
