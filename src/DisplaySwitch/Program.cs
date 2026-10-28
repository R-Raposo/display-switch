using DisplaySwitch;

// "DisplaySwitch.exe --exit" asks the running copy to quit (used by the installer and uninstaller)
if (args is ["--exit"])
{
    HotkeyWindow.SignalExit();
    return 0;
}

// Only one copy runs at a time
using var mutex = new Mutex(initiallyOwned: false, @"Local\DisplaySwitch", out bool firstInstance);
if (!firstInstance)
{
    return 0;
}

using var app = new App();
if (!app.Start(Settings.Load(Settings.DefaultPath)))
{
    return 0;
}

HotkeyWindow.RunMessageLoop();
return 0;
