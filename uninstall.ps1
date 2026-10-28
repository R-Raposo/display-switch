# Removes the Display Switch shortcuts and script for the current user.

$InstallDir = Join-Path $env:LOCALAPPDATA 'DisplaySwitch'
$MenuDir    = Join-Path ([Environment]::GetFolderPath('Programs')) 'Display Switch'

# Clear the hotkeys before deleting the shortcuts, so Explorer releases them
# cleanly instead of keeping stale entries around
if (Test-Path $MenuDir) {
    $shell = New-Object -ComObject WScript.Shell
    foreach ($lnk in (Get-ChildItem $MenuDir -Filter *.lnk)) {
        $s = $shell.CreateShortcut($lnk.FullName)
        if ($s.Hotkey) { $s.Hotkey = ''; $s.Save() }
    }
    Start-Sleep -Seconds 2
}

foreach ($dir in $MenuDir, $InstallDir) {
    if (Test-Path $dir) {
        Remove-Item $dir -Recurse -Force
        Write-Host "Removed $dir"
    }
}
Write-Host 'Display Switch uninstalled.' -ForegroundColor Green
