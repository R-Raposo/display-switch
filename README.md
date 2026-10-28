# Display Switch

Keyboard shortcuts that switch a Windows PC between **Main screen only** and
**Extend displays**, with a small on-screen confirmation each time.

Handy when a laptop is plugged into a monitor that is showing another computer:
press the hotkey and everything moves back to the laptop's own screen, even when
you can't see what's on the monitor.

The confirmation always appears on the laptop's built-in screen, never on an
external monitor, which may still be showing another computer.

## Files

| File | What it is | Run it? |
|---|---|---|
| **`Install.cmd`** | Launcher for the installer. Starts `install.ps1` and keeps the window open so you can read the result. | **Yes, to install** (double-click) |
| **`Uninstall.cmd`** | Launcher for the uninstaller. Starts `uninstall.ps1` and keeps the window open. | **Yes, to uninstall** (double-click) |
| `install.ps1` | The installer itself: asks for the hotkeys, checks them, copies `switch-display.ps1` and creates the Start menu shortcuts. | No, `Install.cmd` runs it |
| `uninstall.ps1` | The uninstaller itself: removes the Start menu shortcuts and the installed script. | No, `Uninstall.cmd` runs it |
| `switch-display.ps1` | Switches the display mode and shows the confirmation popup. The installer copies it to your profile, and the shortcuts run that copy. | No, the hotkeys run it |
| `README.md` | This file. | |
| `LICENSE` | MIT license. | |
| `.gitattributes` | Keeps Windows line endings in git so the scripts work after download. | |

**Why both `.cmd` and `.ps1`?** Windows doesn't run `.ps1` files on
double-click: it opens them in Notepad, and its default script policy often
blocks them. The `.cmd` launchers run the matching `.ps1` with
`-ExecutionPolicy Bypass` for that one run only (no system setting changes),
then pause so the window stays open. All the logic is in the `.ps1` files,
so it's easy to read and review.

## Install

1. Download the files: on GitHub, **Code > Download ZIP**.
2. Right-click the zip > **Properties** > tick **Unblock** > **OK**.
   Windows marks downloaded files, and this avoids security prompts.
3. Extract the zip anywhere and double-click **`Install.cmd`**
   (not `install.ps1`).
4. Pick a hotkey for each mode. Press Enter to accept the suggestions
   (`Ctrl+Alt+F9` and `Ctrl+Alt+F10`).
5. Try the hotkeys. On laptops you may need to hold **Fn** for F1-F12.

To change the hotkeys later, double-click **`Install.cmd`** again.

Keep the extracted folder if you want to uninstall or change hotkeys later;
otherwise it can be deleted, and you can download it again when needed.

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

Double-click **`Uninstall.cmd`** (not `uninstall.ps1`). It removes the
Start menu shortcuts, their hotkeys and the installed script.

## What it installs

- `%LOCALAPPDATA%\DisplaySwitch\switch-display.ps1`
- Start menu > **Display Switch** > "Main screen only" and "Extend displays"

No admin rights are needed, and nothing outside your own user profile changes.

## Requirements

- Windows 10 or 11.
- Only built-in parts are used: the Windows display API (`SetDisplayConfig`,
  the same thing Win+P uses), Windows PowerShell 5.1 and .NET Framework.
  It doesn't call `DisplaySwitch.exe`, whose `/internal` and `/extend`
  arguments are ignored on some Windows 11 builds.

## Known limits

- Hotkeys work once you are signed in. At the lock screen use **Win+P**, then
  Up arrow a few times, then Enter, to get "PC screen only".
- "Main screen only" uses the laptop's built-in screen. On a desktop PC without
  one, Windows picks the first monitor, and the confirmation appears on the
  main display.
- With no second monitor connected there is nothing to extend to, so
  "Extend displays" shows "no second screen found".
- Some tools capture keys in a way Windows can't report, so the installer may
  not spot every conflict. If a hotkey does something else, run Install.cmd
  again and pick another.
- At high display scaling (150% and up) the popup may look slightly blurry.
- Antivirus or IT policies on managed PCs may block or flag PowerShell scripts
  started from a shortcut. In that case it won't run.

## License

[MIT](LICENSE)
