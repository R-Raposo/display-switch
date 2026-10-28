namespace DisplaySwitch;

/// <summary>Connects the hotkeys to display switching and the popup.</summary>
internal sealed class App : IDisposable
{
    private const int MainScreenOnlyId = 1;
    private const int ExtendDisplaysId = 2;

    private const nuint ExtendCheckTimer = 1;
    private const nuint ExitTimer = 2;
    private const uint ExtendCheckIntervalMs = 250;
    private const long ExtendWaitMs = 4000;
    private const uint StartupErrorExitMs = 4500;

    private readonly Toast _toast = new();
    private readonly HotkeyWindow _window;
    private long _extendDeadline;

    public App() => _window = new HotkeyWindow(OnHotkey, OnTimer);

    /// <summary>
    /// Registers the configured hotkeys. Returns false when there is nothing to run for
    /// (no hotkeys configured); the caller then exits.
    /// </summary>
    public bool Start(Settings settings)
    {
        var taken = new List<string>(2);
        int registered = 0;
        TryRegister(MainScreenOnlyId, settings.MainScreenOnly);
        TryRegister(ExtendDisplaysId, settings.ExtendDisplays);

        if (taken.Count > 0)
        {
            _toast.Show(taken.Count == 1
                ? $"{taken[0]} is in use by another program. Run Install.cmd to pick another."
                : $"{taken[0]} and {taken[1]} are in use by other programs. Run Install.cmd to pick others.");
        }

        if (registered == 0)
        {
            if (taken.Count == 0)
            {
                return false;
            }
            // Keep running just long enough for the message to be read
            _window.StartTimer(ExitTimer, StartupErrorExitMs);
        }
        return true;

        void TryRegister(int id, Hotkey? hotkey)
        {
            if (hotkey is not { } key)
            {
                return;
            }
            if (_window.Register(id, key))
            {
                registered++;
            }
            else
            {
                taken.Add(key.Text);
            }
        }
    }

    public void Dispose()
    {
        _window.Dispose();
        _toast.Dispose();
    }

    private void OnHotkey(int id)
    {
        DisplayMode mode;
        switch (id)
        {
            case MainScreenOnlyId:
                mode = DisplayMode.MainScreenOnly;
                break;
            case ExtendDisplaysId:
                mode = DisplayMode.Extend;
                break;
            default:
                return;
        }

        _window.StopTimer(ExtendCheckTimer);

        // Switch first; everything else only reports the result
        int result = Display.Switch(mode);

        if (mode == DisplayMode.MainScreenOnly || Display.MonitorCount >= 2)
        {
            _toast.Show(result == 0 ? Label(mode) : $"Display: could not switch (error {result})");
            return;
        }

        // Extend, but the second screen isn't active yet: a slow monitor or dock, or none connected
        _toast.Show(Label(mode));
        _extendDeadline = Environment.TickCount64 + ExtendWaitMs;
        _window.StartTimer(ExtendCheckTimer, ExtendCheckIntervalMs);
    }

    private void OnTimer(nuint id)
    {
        if (id == ExitTimer)
        {
            _window.Close();
            return;
        }
        if (id != ExtendCheckTimer)
        {
            return;
        }

        if (Display.MonitorCount >= 2)
        {
            _window.StopTimer(ExtendCheckTimer);
            _toast.Show(Label(DisplayMode.Extend)); // re-place it now that the layout has changed
        }
        else if (Environment.TickCount64 >= _extendDeadline)
        {
            _window.StopTimer(ExtendCheckTimer);
            _toast.Show("Display: no second screen found");
        }
    }

    private static string Label(DisplayMode mode) =>
        mode == DisplayMode.MainScreenOnly ? "Display: Main screen only" : "Display: Extend displays";
}
