# Installs the Display Switch shortcuts for the current user.
# Asks for a hotkey per display mode and re-asks when the combination is
# invalid or already taken. Safe to re-run to change hotkeys.

$ErrorActionPreference = 'Stop'

$Modes = @(
    @{ Mode = 'internal'; Name = 'Main screen only';   Default = 'Ctrl+Alt+F9' },
    @{ Mode = 'extend';   Name = 'Extend displays';    Default = 'Ctrl+Alt+F10' }
)

$InstallDir = Join-Path $env:LOCALAPPDATA 'DisplaySwitch'
$MenuDir    = Join-Path ([Environment]::GetFolderPath('Programs')) 'Display Switch'

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
function Get-ShortcutHotkeys([string]$Exclude) {
    $shell = New-Object -ComObject WScript.Shell
    $found = @{}
    $roots = 'Desktop', 'CommonDesktopDirectory', 'StartMenu', 'CommonStartMenu' |
        ForEach-Object { [Environment]::GetFolderPath($_) } | Where-Object { $_ -and (Test-Path $_) }
    foreach ($lnk in (Get-ChildItem $roots -Filter *.lnk -Recurse -ErrorAction SilentlyContinue)) {
        if ($Exclude -and $lnk.FullName.StartsWith($Exclude, 'OrdinalIgnoreCase')) { continue }
        try { $hk = $shell.CreateShortcut($lnk.FullName).Hotkey } catch { continue }
        if (-not $hk) { continue }
        $parsed = ConvertTo-Hotkey $hk
        if ($parsed) { $found[$parsed.Text] = $lnk.BaseName }
    }
    $found
}

# True if some program (or another shortcut) already owns this combination.
function Test-HotkeyTaken($Hotkey) {
    $id = 0x5D5
    $ok = [DisplaySwitch.Native]::RegisterHotKey([IntPtr]::Zero, $id, $Hotkey.Modifiers -bor 0x4000, $Hotkey.Vk)
    if ($ok) { [void][DisplaySwitch.Native]::UnregisterHotKey([IntPtr]::Zero, $id) }
    -not $ok
}

# Waits until Explorer has registered ($Taken = $true) or released ($Taken = $false)
# a shortcut's hotkey. Returns whether that happened before the timeout.
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
function Test-Hotkey($Hotkey, [string[]]$AlreadyChosen, [hashtable]$ShortcutHotkeys, [string[]]$OwnPrevious) {
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
        elseif ($OwnPrevious -notcontains $Hotkey.Text -and (Test-HotkeyTaken $Hotkey)) {
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

function Read-Hotkey($ModeInfo, [string[]]$AlreadyChosen, [hashtable]$ShortcutHotkeys, [string[]]$OwnPrevious) {
    while ($true) {
        $answer = "$(Read-Host "Hotkey for '$($ModeInfo.Name)' [Enter = $($ModeInfo.Default), 'none' = no hotkey]")".Trim()
        if (-not $answer) { $answer = $ModeInfo.Default }
        if ($answer -eq 'none') { return $null }

        $hotkey = ConvertTo-Hotkey $answer
        if (-not $hotkey) {
            Write-Host '  Could not read that. Use something like Ctrl+Alt+F9 or Ctrl+Shift+Alt+D (keys: A-Z, 0-9, F1-F12).' -ForegroundColor Yellow
            continue
        }

        $check = Test-Hotkey $hotkey $AlreadyChosen $ShortcutHotkeys $OwnPrevious
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

function Install-DisplaySwitch {
    Write-Host ''
    Write-Host 'Display Switch installer' -ForegroundColor Cyan
    Write-Host 'Pick a keyboard shortcut for each display mode. Press Enter to accept the suggestion.'
    Write-Host ''

    # Hotkeys from a previous install count as ours, not as conflicts
    $shell = New-Object -ComObject WScript.Shell
    $ownPrevious = @()
    if (Test-Path $MenuDir) {
        $ownPrevious = Get-ChildItem $MenuDir -Filter *.lnk | ForEach-Object {
            $p = ConvertTo-Hotkey $shell.CreateShortcut($_.FullName).Hotkey
            if ($p) { $p.Text }
        }
    }

    $shortcutHotkeys = Get-ShortcutHotkeys -Exclude $MenuDir
    $chosen = @{}
    foreach ($m in $Modes) {
        $chosen[$m.Mode] = Read-Hotkey $m @($chosen.Values | ForEach-Object { $_.Text }) $shortcutHotkeys $ownPrevious
    }

    New-Item -ItemType Directory -Force $InstallDir | Out-Null
    $script = Join-Path $InstallDir 'switch-display.ps1'
    Copy-Item (Join-Path $PSScriptRoot 'switch-display.ps1') $script -Force
    Unblock-File $script

    # Explorer keeps its own list of shortcut hotkeys and can mix them up when
    # shortcuts that still have hotkeys are deleted or renamed. So first clear the
    # hotkeys on our existing shortcuts and wait for Windows to release them; the
    # new hotkeys are then registered from scratch.
    New-Item -ItemType Directory -Force $MenuDir | Out-Null
    $released = @()
    foreach ($lnk in (Get-ChildItem $MenuDir -Filter *.lnk)) {
        $s = $shell.CreateShortcut($lnk.FullName)
        $old = ConvertTo-Hotkey $s.Hotkey
        if ($old) { $s.Hotkey = ''; $s.Save(); $released += $old }
    }
    if ($released.Count) {
        Send-ShellRefresh
        foreach ($old in $released) { [void](Wait-HotkeyState $old $false) }
    }
    $names = $Modes | ForEach-Object { "$($_.Name).lnk" }
    Get-ChildItem $MenuDir -Filter *.lnk | Where-Object { $names -notcontains $_.Name } | Remove-Item -Force

    # conhost --headless hides the console completely; older Windows 10 builds lack it
    $headless = [Environment]::OSVersion.Version.Build -ge 19041
    $psArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""

    $saveShortcut = {
        param($m)
        $s = $shell.CreateShortcut((Join-Path $MenuDir "$($m.Name).lnk"))
        if ($headless) {
            $s.TargetPath = "$env:WINDIR\System32\conhost.exe"
            $s.Arguments  = "--headless powershell.exe $psArgs -Mode $($m.Mode)"
        }
        else {
            $s.TargetPath = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
            $s.Arguments  = "$psArgs -Mode $($m.Mode)"
        }
        $s.IconLocation = "$env:WINDIR\System32\DisplaySwitch.exe,0"
        $s.Description  = "Switch display mode: $($m.Name)"
        $s.Hotkey = if ($chosen[$m.Mode]) { $chosen[$m.Mode].Text } else { '' }
        $s.Save()
    }
    foreach ($m in $Modes) { & $saveShortcut $m }
    Send-ShellRefresh

    $inactive = @()
    foreach ($m in $Modes) {
        $hk = $chosen[$m.Mode]
        if ($hk -and -not (Wait-HotkeyState $hk $true)) { $inactive += $hk.Text }
    }

    Write-Host ''
    Write-Host 'Installed.' -ForegroundColor Green
    foreach ($m in $Modes) {
        $text = if ($chosen[$m.Mode]) { $chosen[$m.Mode].Text } else { '(no hotkey)' }
        Write-Host ("  {0,-20} {1}" -f $m.Name, $text)
    }
    if ($inactive.Count) {
        Write-Host ''
        Write-Host "Windows has not activated $($inactive -join ' and ') yet. Sign out and back in" -ForegroundColor Yellow
        Write-Host '(or restart) and it will start working.' -ForegroundColor Yellow
    }
    Write-Host ''
    Write-Host "Shortcuts are in the Start menu under 'Display Switch'."
    Write-Host 'Try your hotkeys now. Some tools grab keys in a way Windows cannot report, so if'
    Write-Host 'something else happens (e.g. the PC locks), run Install.cmd again and pick another.'
    Write-Host 'On laptops you may need to hold Fn for F1-F12.'
}

# Dot-sourcing (". .\install.ps1") loads the functions without installing
if ($MyInvocation.InvocationName -ne '.') { Install-DisplaySwitch }
