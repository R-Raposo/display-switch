# Display Switch

Keyboard shortcuts that switch a Windows PC between **Main screen only** and
**Extend displays**, with a small on-screen confirmation each time.

Handy when a laptop is plugged into a monitor that is showing another computer:
press the hotkey and everything moves back to the laptop's own screen, even when
you can't see what's on the monitor.

The confirmation appears as soon as you press the hotkey, always on the
laptop's built-in screen, never on an external monitor, which may still be
showing another computer.

Display Switch is a tiny background program that registers the hotkeys itself,
so the switch starts as soon as you press them. It has no window or tray icon;
it shows up in Task Manager as `DisplaySwitch`.

## Install

1. Download the zip for your PC from the
   [Releases page](https://github.com/R-Raposo/display-switch/releases):
   `DisplaySwitch-win-x64.zip` for most PCs, `DisplaySwitch-win-arm64.zip` for
   ARM (Snapdragon) laptops.
2. Right-click the zip > **Properties** > tick **Unblock** > **OK**.
   Windows marks downloaded files, and this avoids security prompts.
3. Extract the zip anywhere and double-click **`Install.cmd`**
   (not `install.ps1`).
4. Pick a hotkey for each mode. Press Enter to accept the suggestions
   (`Ctrl+Alt+F9` and `Ctrl+Alt+F10`).
5. Try the hotkeys. On laptops you may need to hold **Fn** for F1-F12.

Display Switch starts right away and then every time you sign in.

To change the hotkeys later, double-click **`Install.cmd`** again.

Keep the extracted folder if you want to uninstall or change hotkeys later;
otherwise it can be deleted, and you can download it again when needed.

### "Windows protected your PC"

`DisplaySwitch.exe` isn't code-signed, so Windows SmartScreen may warn the first
time it runs. Choose **More info** > **Run anyway**. To check you have the
genuine file:

- Compare the zip's SHA-256 hash with `SHA256SUMS.txt` on the release:
  `Get-FileHash DisplaySwitch-win-x64.zip`
- Or verify that GitHub built it from this repository's source:
  `gh attestation verify DisplaySwitch-win-x64.zip --owner R-Raposo`

### How the installer checks hotkeys

The installer asks again if a combination:

- can't be read (use something like `Ctrl+Alt+F9` or `Ctrl+Shift+Alt+D`; keys A-Z, 0-9, F1-F12)
- has no Ctrl or Alt
- is a letter or number with only one modifier (it would hijack shortcuts like `Ctrl+C`)
- is `Alt+F4` or `Ctrl+F4`
- is already picked for the other mode
- is already used by another shortcut or program

It asks for confirmation when `Ctrl+Alt` is combined with a letter or number,
because on different keyboard layouts `Ctrl+Alt` works like AltGr and may be
needed to type a character, and when a function key has only one modifier.

## Uninstall

Double-click **`Uninstall.cmd`** (not `uninstall.ps1`). It stops Display
Switch, removes it from startup and deletes the installed files.

## Files in the release zip

| File | What it is | Run it? |
|---|---|---|
| **`Install.cmd`** | Launcher for the installer. Starts `install.ps1` and keeps the window open so you can read the result. | **Yes, to install** (double-click) |
| **`Uninstall.cmd`** | Launcher for the uninstaller. Starts `uninstall.ps1` and keeps the window open. | **Yes, to uninstall** (double-click) |
| `install.ps1` | The installer: asks for the hotkeys, checks them, installs `DisplaySwitch.exe` and adds it to startup. | No, `Install.cmd` runs it |
| `uninstall.ps1` | The uninstaller: stops the program and removes it. | No, `Uninstall.cmd` runs it |
| `DisplaySwitch.exe` | The program. The installer copies it to your profile and starts it. | No, the installer starts it |
| `README.md` | This file. | |
| `LICENSE` | MIT license. | |

**Why both `.cmd` and `.ps1`?** Windows doesn't run `.ps1` files on
double-click: it opens them in Notepad, and its default script policy often
blocks them. The `.cmd` launchers run the matching `.ps1` with
`-ExecutionPolicy Bypass` for that one run only (no system setting changes),
then pause so the window stays open. The installer logic stays in readable
`.ps1` files.

## What it installs

- `%LOCALAPPDATA%\DisplaySwitch\DisplaySwitch.exe`
- `%LOCALAPPDATA%\DisplaySwitch\settings.ini` (your hotkeys)
- A `Display Switch` shortcut in your Startup folder (listed in Task Manager >
  Startup apps)

No admin rights are needed, and nothing outside your own user profile changes.

## Requirements

- Windows 10 or 11, x64 or ARM64. Nothing else to install.
- It uses the Windows display API (`SetDisplayConfig`, the same thing Win+P
  uses). It doesn't call `DisplaySwitch.exe` from Windows, whose `/internal`
  and `/extend` arguments are ignored on some Windows 11 builds.

## Known limits

- Hotkeys work once you are signed in. At the lock screen use **Win+P**, then
  Up arrow a few times, then Enter, to get "PC screen only".
- "Main screen only" uses the laptop's built-in screen. On a desktop PC without
  one, Windows picks the first monitor, and the confirmation appears on the
  main display.
- Bringing up a monitor that has been idle can take Windows a couple of
  seconds; the confirmation shows straight away and the screens follow.
- With no second monitor connected there is nothing to extend to, so
  "Extend displays" shows "no second screen found".
- Some tools capture keys in a way Windows can't report, so the installer may
  not spot every conflict. If a hotkey does something else, run Install.cmd
  again and pick another.
- Antivirus or IT policies on managed PCs may block unsigned programs or
  PowerShell scripts. In that case it won't install or run.

## Build from source

Requires the .NET 10 SDK.

```
dotnet test DisplaySwitch.slnx
```

The release exe is built with Native AOT, which also needs the Visual Studio
"Desktop development with C++" workload:

```
dotnet publish src/DisplaySwitch -c Release -r win-x64
```

## License

[MIT](LICENSE)
