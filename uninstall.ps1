# Removes Display Switch for the current user, including the previous PowerShell version.

$InstallDir    = Join-Path $env:LOCALAPPDATA 'DisplaySwitch'
$ExePath       = Join-Path $InstallDir 'DisplaySwitch.exe'
$StartupLink   = Join-Path ([Environment]::GetFolderPath('Startup')) 'Display Switch.lnk'
$LegacyMenuDir = Join-Path ([Environment]::GetFolderPath('Programs')) 'Display Switch'

# Stop the running program so its hotkeys are released and the exe can be deleted
if (Test-Path $ExePath) {
    Start-Process $ExePath -ArgumentList '--exit' -Wait
    $running = Get-Process DisplaySwitch -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $ExePath }
    if ($running) {
        $running | Wait-Process -Timeout 5 -ErrorAction SilentlyContinue
        $running | Where-Object { -not $_.HasExited } | Stop-Process -Force
    }
}

if (Test-Path $StartupLink) {
    Remove-Item $StartupLink -Force
    Write-Host "Removed $StartupLink"
}

# Previous version: clear the shortcut hotkeys before deleting, so Explorer releases them cleanly
if (Test-Path $LegacyMenuDir) {
    $shell = New-Object -ComObject WScript.Shell
    foreach ($lnk in (Get-ChildItem $LegacyMenuDir -Filter *.lnk)) {
        $s = $shell.CreateShortcut($lnk.FullName)
        if ($s.Hotkey) { $s.Hotkey = ''; $s.Save() }
    }
    Start-Sleep -Seconds 2
    Remove-Item $LegacyMenuDir -Recurse -Force
    Write-Host "Removed $LegacyMenuDir"
}

if (Test-Path $InstallDir) {
    Remove-Item $InstallDir -Recurse -Force
    Write-Host "Removed $InstallDir"
}
Write-Host 'Display Switch uninstalled.' -ForegroundColor Green
