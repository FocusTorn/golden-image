$scripts = @(
	{
		[System.Diagnostics.EventLog]::WriteEntry( 'UnattendGenerator', "User '$env:USERNAME' has requested to unlock the Start menu layout.", [System.Diagnostics.EventLogEntryType]::Information, 1 );
	};
	{
		@(
		  Get-ChildItem -LiteralPath $env:USERPROFILE -Force -Recurse -Depth 2;
		) | Where-Object -FilterScript {
			$_.Attributes.HasFlag( [System.IO.FileAttributes]::ReparsePoint );
		} | Remove-Item -Force -Recurse -Verbose;
	};
	{
		Remove-Item -LiteralPath "${env:USERPROFILE}\Desktop\Microsoft Edge.lnk" -ErrorAction 'SilentlyContinue' -Verbose;
	};
	{
		reg.exe add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /ve /f;
	};
	{
		Set-ItemProperty -LiteralPath 'Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Search' -Name 'SearchboxTaskbarMode' -Type 'DWord' -Value 0;
	};
	{
		Set-ItemProperty -LiteralPath 'Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting' -Type 'DWord' -Value 2 -Force;
	};
	{
		# Desktop Icons configuration
		$paths = @(
			'Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu',
			'Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel'
		)
		foreach ($p in $paths) {
			New-Item -Path $p -Force -ErrorAction SilentlyContinue | Out-Null
			Set-ItemProperty -Path $p -Name '{645ff040-5081-101b-9f08-00aa002f954e}' -Value 0 -Type 'DWord'
			$guids = @('{5399e694-6ce5-4d6c-8fce-1d8870fdcba0}', '{b4bfcc3a-db2c-424c-b029-7fe99a87c641}', 
					  '{a8cdff1c-4878-43be-b5fd-f8091c1c60d0}', '{374de290-123f-4565-9164-39c4925e467b}',
					  '{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}', '{f874310e-b6b7-47dc-bc84-b9e6b38f5903}',
					  '{1cf1260c-4dd0-4ebb-811f-33c572699fde}', '{f02c1a0d-be21-4350-88b0-7367fc96ef3c}',
					  '{3add1653-eb32-4cb0-bbd7-dfa0abb5acca}', '{20d04fe0-3aea-1069-a2d8-08002b30309d}',
					  '{59031a47-3f72-44a7-89c5-5595fe6b30ee}', '{a0953c92-50dc-43bf-be83-3742fed03c9c}')
			foreach ($g in $guids) { Set-ItemProperty -Path $p -Name $g -Value 1 -Type 'DWord' }
		}
	};
	{
		Set-ItemProperty -Path 'Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Start' -Name 'VisiblePlaces' -Value $( [convert]::FromBase64String('ztU0LVr6Q0WC8iLm6vd3PC+zZ+PeiVVDv85h83sYqTdKsL10SvloT4vWQ5gHHai8') ) -Type 'Binary';
	};
	{
		& 'C:\Windows\Setup\Scripts\SetColorTheme.ps1';
	};
	{
		Get-Process -Name 'explorer' -ErrorAction 'SilentlyContinue' | Where-Object { $_.SessionId -eq (Get-Process -Id $PID).SessionId } | Stop-Process -Force;
	};
);

& {
  [float] $complete = 0;
  [float] $increment = 100 / $scripts.Count;
  foreach( $script in $scripts ) {
    Write-Progress -Id 0 -Activity 'Configuring user account.' -PercentComplete $complete;
    & $script;
    $complete += $increment;
  }
} *>&1 | Out-String -Width 1KB -Stream >> "$env:TEMP\UserOnce.log";
