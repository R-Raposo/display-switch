# Changelog

## 2.0.0 (unreleased)

### Changed

- Display Switch is now a small background program (.NET 10, Native AOT)
  instead of PowerShell scripts started by Start menu shortcuts. The display
  starts switching right after the key press instead of about 4 seconds later.
- Hotkeys are registered by the program itself. This avoids Explorer's
  3-second delay for shortcut hotkeys and its hotkey mix-ups after shortcuts
  are renamed.
- The confirmation popup appears as soon as the hotkey is pressed, even when
  Windows takes a while to bring a monitor up, and stays above the taskbar.
- The confirmation popup is drawn sharply at any display scaling.

### Added

- Release zips for x64 and ARM64, with SHA-256 checksums and build provenance
  attestation.

### Removed

- `switch-display.ps1` and the Start menu shortcuts. The installer removes them
  when upgrading.

## 1.0.0 (not released)

- PowerShell version: Start menu shortcuts with hotkeys, an installer that
  validates hotkey choices, and a confirmation popup on the built-in screen.
