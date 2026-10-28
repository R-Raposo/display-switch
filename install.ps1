# Installs Display Switch for the current user.
# Asks for a hotkey per display mode, re-asks when a combination is invalid or already
# taken, installs DisplaySwitch.exe and starts it at sign-in. Safe to re-run to change hotkeys.

$ErrorActionPreference = 'Stop'

$Modes = @(
    @{ Key = 'MainScreenOnly'; Name = 'Main screen only'; Default = 'Ctrl+Alt+F9' },
    @{ Key = 'ExtendDisplays'; Name = 'Extend displays';  Default = 'Ctrl+Alt+F10' }
)

$InstallDir    = Join-Path $env:LOCALAPPDATA 'DisplaySwitch'
$ExePath       = Join-Path $InstallDir 'DisplaySwitch.exe'
$SettingsPath  = Join-Path $InstallDir 'settings.ini'
$StartupLink   = Join-Path ([Environment]::GetFolderPath('Startup')) 'Display Switch.lnk'

# Previous version: Start menu shortcuts with hotkeys that ran a PowerShell script
$LegacyMenuDir = Join-Path ([Environment]::GetFolderPath('Programs')) 'Display Switch'
$LegacyScript  = Join-Path $InstallDir 'switch-display.ps1'

Add-Type -Namespace DisplaySwitch -Name Native -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true)] public static extern bool RegisterHotKey(IntPtr hWnd, int id, uint mods, uint vk);
[DllImport("user32.dll")] public static extern bool UnregisterHotKey(IntPtr hWnd, int id);
[DllImport("shell32.dll")] public static extern void SHChangeNotify(int eventId, uint flags, IntPtr a, IntPtr b);
'@

# Turns text like "ctrl + alt + f9" into a hotkey object, or $null if it can't be read.
function ConvertTo-Hotkey([string]$Text) {
    $ctrl = $false; $alt = $false; $shift = $false; $key = $null
    foreach ($part in ($Text -split '\+' | ForEach-Object { $_.Trim().ToUpper() } | Where-Object { $_ })) {
        switch -Regex ($part) {
            '^(CTRL|CONTROL)$'   { $ctrl = $true; continue }
            '^ALT$'              { $alt = $true; continue }
            '^SHIFT$'            { $shift = $true; continue }
            '^([A-Z0-9]|F([1-9]|1[0-2]))$' { if ($key) { return $null }; $key = $part; continue }
            default              { return $null }
        }
    }
    if (-not $key) { return $null }

    $vk = if ($key.Length -eq 1) { [int][char]$key } else { 0x70 + [int]$key.Substring(1) - 1 }
    $parts = @(); if ($ctrl) { $parts += 'Ctrl' }; if ($alt) { $parts += 'Alt' }; if ($shift) { $parts += 'Shift' }

    [pscustomobject]@{
        Text      = (($parts + $key) -join '+')
        Ctrl      = $ctrl
        Alt       = $alt
        Shift     = $shift
        Key       = $key
        IsFKey    = $key.Length -gt 1
        Modifiers = [int]$alt + 2 * [int]$ctrl + 4 * [int]$shift   # MOD_ALT=1, MOD_CONTROL=2, MOD_SHIFT=4
        Vk        = $vk
    }
}

# Hotkeys set on other shortcuts in the desktop and Start menu, keyed by their text.
function Get-ShortcutHotkeys {
    $shell = New-Object -ComObject WScript.Shell
    $found = @{}
    $roots = 'Desktop', 'CommonDesktopDirectory', 'StartMenu', 'CommonStartMenu' |
        ForEach-Object { [Environment]::GetFolderPath($_) } | Where-Object { $_ -and (Test-Path $_) }
    foreach ($lnk in (Get-ChildItem $roots -Filter *.lnk -Recurse -ErrorAction SilentlyContinue)) {
        try { $hk = $shell.CreateShortcut($lnk.FullName).Hotkey } catch { continue }
        if (-not $hk) { continue }
        $parsed = ConvertTo-Hotkey $hk
        if ($parsed) { $found[$parsed.Text] = $lnk.BaseName }
    }
    $found
}

# True if some program (or a shortcut) already owns this combination.
function Test-HotkeyTaken($Hotkey) {
    $id = 0x5D5
    $ok = [DisplaySwitch.Native]::RegisterHotKey([IntPtr]::Zero, $id, $Hotkey.Modifiers -bor 0x4000, $Hotkey.Vk)
    if ($ok) { [void][DisplaySwitch.Native]::UnregisterHotKey([IntPtr]::Zero, $id) }
    -not $ok
}

# Waits until a hotkey is owned ($Taken = $true) or free ($Taken = $false).
# Returns whether that happened before the timeout.
function Wait-HotkeyState($Hotkey, [bool]$Taken, [int]$TimeoutMs = 4000) {
    $deadline = (Get-Date).AddMilliseconds($TimeoutMs)
    do {
        if ((Test-HotkeyTaken $Hotkey) -eq $Taken) { return $true }
        Start-Sleep -Milliseconds 250
    } while ((Get-Date) -lt $deadline)
    $false
}

function Send-ShellRefresh {
    [DisplaySwitch.Native]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
}

# Returns @{ Errors = @(...); Warnings = @(...) } for a parsed hotkey.
function Test-Hotkey($Hotkey, [string[]]$AlreadyChosen, [hashtable]$ShortcutHotkeys) {
    $errors = @(); $warnings = @()
    $modCount = [int]$Hotkey.Ctrl + [int]$Hotkey.Alt + [int]$Hotkey.Shift

    if (-not ($Hotkey.Ctrl -or $Hotkey.Alt)) {
        $errors += 'It must include Ctrl or Alt.'
    }
    elseif (-not $Hotkey.IsFKey -and $modCount -lt 2) {
        $errors += 'Letters and numbers need at least two modifiers (e.g. Ctrl+Alt+K), or they would hijack normal shortcuts like Ctrl+C.'
    }
    if ($Hotkey.Text -eq 'Alt+F4' -or $Hotkey.Text -eq 'Ctrl+F4') {
        $errors += "$($Hotkey.Text) is used by Windows and most apps to close windows and tabs."
    }
    if ($AlreadyChosen -contains $Hotkey.Text) {
        $errors += 'You already picked this combination for the other mode.'
    }
    if ($errors.Count -eq 0) {
        if ($ShortcutHotkeys.ContainsKey($Hotkey.Text)) {
            $errors += "Already used by the shortcut '$($ShortcutHotkeys[$Hotkey.Text])'."
        }
        elseif (Test-HotkeyTaken $Hotkey) {
            $errors += 'Already taken by another program.'
        }
    }

    if ($Hotkey.Ctrl -and $Hotkey.Alt -and -not $Hotkey.IsFKey) {
        $warnings += 'On different keyboard layouts Ctrl+Alt works like AltGr, so this combination may be needed to type a character (accents, currency signs, symbols).'
    }
    if ($Hotkey.IsFKey -and $modCount -eq 1) {
        $warnings += 'Single-modifier function keys are often used by apps (browsers, IDEs, games).'
    }
    @{ Errors = $errors; Warnings = $warnings }
}

function Read-Hotkey($ModeInfo, [string[]]$AlreadyChosen, [hashtable]$ShortcutHotkeys) {
    while ($true) {
        $answer = "$(Read-Host "Hotkey for '$($ModeInfo.Name)' [Enter = $($ModeInfo.Default), 'none' = no hotkey]")".Trim()
        if (-not $answer) { $answer = $ModeInfo.Default }
        if ($answer -eq 'none') { return $null }

        $hotkey = ConvertTo-Hotkey $answer
        if (-not $hotkey) {
            Write-Host '  Could not read that. Use something like Ctrl+Alt+F9 or Ctrl+Shift+Alt+D (keys: A-Z, 0-9, F1-F12).' -ForegroundColor Yellow
            continue
        }

        $check = Test-Hotkey $hotkey $AlreadyChosen $ShortcutHotkeys
        if ($check.Errors.Count) {
            $check.Errors | ForEach-Object { Write-Host "  $($hotkey.Text): $_" -ForegroundColor Yellow }
            continue
        }
        if ($check.Warnings.Count) {
            $check.Warnings | ForEach-Object { Write-Host "  Note: $_" -ForegroundColor DarkYellow }
            if ("$(Read-Host "  Use $($hotkey.Text) anyway? (y/N)")".Trim() -notmatch '^(y|yes)$') { continue }
        }
        return $hotkey
    }
}

# Asks a running Display Switch to quit and waits for it, so its hotkeys are free and the exe can be replaced.
function Stop-DisplaySwitch {
    if (Test-Path $ExePath) {
        Start-Process $ExePath -ArgumentList '--exit' -Wait
    }
    $running = Get-Process DisplaySwitch -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $ExePath }
    if ($running) {
        $running | Wait-Process -Timeout 5 -ErrorAction SilentlyContinue
        $running | Where-Object { -not $_.HasExited } | Stop-Process -Force
    }
}

# Removes the previous PowerShell version. Its shortcut hotkeys are cleared first and released
# by Windows before the shortcuts are deleted; Explorer mixes up hotkeys otherwise.
function Remove-LegacyVersion {
    if (Test-Path $LegacyMenuDir) {
        $shell = New-Object -ComObject WScript.Shell
        $released = @()
        foreach ($lnk in (Get-ChildItem $LegacyMenuDir -Filter *.lnk)) {
            $s = $shell.CreateShortcut($lnk.FullName)
            $old = ConvertTo-Hotkey $s.Hotkey
            if ($old) { $s.Hotkey = ''; $s.Save(); $released += $old }
        }
        if ($released.Count) {
            Send-ShellRefresh
            foreach ($old in $released) { [void](Wait-HotkeyState $old $false) }
        }
        Remove-Item $LegacyMenuDir -Recurse -Force
        Write-Host 'Removed the previous version (Start menu shortcuts).'
    }
    if (Test-Path $LegacyScript) { Remove-Item $LegacyScript -Force }
}

function Install-DisplaySwitch {
    $source = Join-Path $PSScriptRoot 'DisplaySwitch.exe'
    if (-not (Test-Path $source)) {
        Write-Host 'DisplaySwitch.exe was not found next to install.ps1.' -ForegroundColor Red
        Write-Host 'Download a release zip from the GitHub Releases page rather than the source code.' -ForegroundColor Red
        exit 1
    }

    Write-Host ''
    Write-Host 'Display Switch installer' -ForegroundColor Cyan
    Write-Host 'Pick a keyboard shortcut for each display mode. Press Enter to accept the suggestion.'
    Write-Host ''

    Stop-DisplaySwitch
    Remove-LegacyVersion

    $shortcutHotkeys = Get-ShortcutHotkeys
    $chosen = @{}
    foreach ($m in $Modes) {
        $chosen[$m.Key] = Read-Hotkey $m @($chosen.Values | ForEach-Object { $_.Text }) $shortcutHotkeys
    }

    New-Item -ItemType Directory -Force $InstallDir | Out-Null
    Copy-Item $source $ExePath -Force
    Unblock-File $ExePath

    $lines = foreach ($m in $Modes) {
        $value = if ($chosen[$m.Key]) { $chosen[$m.Key].Text } else { 'none' }
        "$($m.Key)=$value"
    }
    Set-Content -Path $SettingsPath -Value $lines -Encoding ASCII

    $active = @($Modes | Where-Object { $chosen[$_.Key] })
    if (-not $active.Count) {
        if (Test-Path $StartupLink) { Remove-Item $StartupLink -Force }
        Write-Host ''
        Write-Host 'No hotkeys chosen, so Display Switch will not run. Run Install.cmd again to pick some.' -ForegroundColor Yellow
        return
    }

    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut($StartupLink)
    $link.TargetPath = $ExePath
    $link.WorkingDirectory = $InstallDir
    $link.Description = 'Display Switch: hotkeys to switch display mode'
    $link.Save()

    Start-Process $ExePath

    # The program owns its hotkeys once it is running
    $inactive = @()
    foreach ($m in $active) {
        if (-not (Wait-HotkeyState $chosen[$m.Key] $true)) { $inactive += $chosen[$m.Key].Text }
    }

    Write-Host ''
    Write-Host 'Installed.' -ForegroundColor Green
    foreach ($m in $Modes) {
        $text = if ($chosen[$m.Key]) { $chosen[$m.Key].Text } else { '(no hotkey)' }
        Write-Host ("  {0,-20} {1}" -f $m.Name, $text)
    }
    if ($inactive.Count) {
        Write-Host ''
        Write-Host "Display Switch could not register $($inactive -join ' and '). Another program may have taken it;" -ForegroundColor Yellow
        Write-Host 'run Install.cmd again and pick another.' -ForegroundColor Yellow
    }
    Write-Host ''
    Write-Host 'Display Switch is running and starts automatically when you sign in.'
    Write-Host 'Try your hotkeys now. Some tools grab keys in a way Windows cannot report, so if'
    Write-Host 'something else happens (e.g. the PC locks), run Install.cmd again and pick another.'
    Write-Host 'On laptops you may need to hold Fn for F1-F12.'
}

# Dot-sourcing (". .\install.ps1") loads the functions without installing
if ($MyInvocation.InvocationName -ne '.') { Install-DisplaySwitch }
