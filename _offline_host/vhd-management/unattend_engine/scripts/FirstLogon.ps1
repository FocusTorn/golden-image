$scripts = @(
	{
		Set-ItemProperty -LiteralPath 'Registry::HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name 'AutoLogonCount' -Type 'DWord' -Force -Value 0;
	};
	{
		@(
			Get-ChildItem -LiteralPath 'C:\' -Force;
			Get-ChildItem -LiteralPath 'C:\Users' -Force;
			Get-ChildItem -LiteralPath 'C:\Users\Default' -Force -Recurse -Depth 2;
			Get-ChildItem -LiteralPath 'C:\Users\Public' -Force -Recurse -Depth 2;
			Get-ChildItem -LiteralPath 'C:\ProgramData' -Force;
		) | Where-Object -FilterScript {
			$_.Attributes.HasFlag( [System.IO.FileAttributes]::ReparsePoint );
		} | Remove-Item -Force -Recurse -Verbose;
	};
	{
		cmd.exe /c "rmdir C:\Windows.old";
	};
);

& {
  [float] $complete = 0;
  [float] $increment = 100 / $scripts.Count;
  foreach( $script in $scripts ) {
    Write-Progress -Id 0 -Activity 'Finalizing installation.' -PercentComplete $complete;
    & $script;
    $complete += $increment;
  }
} *>&1 | Out-String -Width 1KB -Stream >> "C:\Windows\Setup\Scripts\FirstLogon.log";
