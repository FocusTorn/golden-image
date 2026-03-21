# JSONC support (Windows PowerShell 5.1)

`_master_config.json` may contain JSONC (`//` comments, trailing commas).

- **PowerShell 7+**: parsed via `System.Text.Json` (no extra files).
- **Windows PowerShell 5.1**: requires `Newtonsoft.Json.dll` in this folder.

Install (extracts the `.nupkg` with `System.IO.Compression.ZipFile`, not `Expand-Archive`, which rejects `.nupkg`):

```powershell
cd P:\Projects\golden-image\_helpers
powershell -ExecutionPolicy Bypass -File .\Install-NewtonsoftJson.ps1
```

You may commit `Newtonsoft.Json.dll` to avoid the install step on new machines.
