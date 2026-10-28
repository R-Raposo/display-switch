namespace DisplaySwitch;

/// <summary>Hotkeys chosen by the installer. A null hotkey means "none".</summary>
internal sealed record Settings(Hotkey? MainScreenOnly, Hotkey? ExtendDisplays)
{
    public static Settings Defaults { get; } = new(Required("Ctrl+Alt+F9"), Required("Ctrl+Alt+F10"));

    public static string DefaultPath { get; } = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "DisplaySwitch", "settings.ini");

    /// <summary>Reads the settings file; a missing or unreadable file gives the defaults.</summary>
    public static Settings Load(string path)
    {
        try
        {
            return Parse(File.ReadAllLines(path));
        }
        catch (IOException)
        {
            return Defaults;
        }
        catch (UnauthorizedAccessException)
        {
            return Defaults;
        }
    }

    /// <summary>Reads "Name=Value" lines. Unknown lines are ignored; unreadable values keep the default.</summary>
    public static Settings Parse(IEnumerable<string> lines)
    {
        Hotkey? mainScreenOnly = Defaults.MainScreenOnly;
        Hotkey? extendDisplays = Defaults.ExtendDisplays;

        foreach (string line in lines)
        {
            int separator = line.IndexOf('=', StringComparison.Ordinal);
            if (separator < 0)
            {
                continue;
            }

            string name = line[..separator].Trim();
            string value = line[(separator + 1)..].Trim();
            if (name.Equals(nameof(MainScreenOnly), StringComparison.OrdinalIgnoreCase))
            {
                mainScreenOnly = ReadHotkey(value, mainScreenOnly);
            }
            else if (name.Equals(nameof(ExtendDisplays), StringComparison.OrdinalIgnoreCase))
            {
                extendDisplays = ReadHotkey(value, extendDisplays);
            }
        }

        return new Settings(mainScreenOnly, extendDisplays);
    }

    private static Hotkey? ReadHotkey(string value, Hotkey? fallback)
    {
        if (value.Equals("none", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        return Hotkey.TryParse(value, out Hotkey hotkey) ? hotkey : fallback;
    }

    private static Hotkey Required(string text) =>
        Hotkey.TryParse(text, out Hotkey hotkey) ? hotkey : throw new InvalidOperationException($"Invalid built-in hotkey '{text}'.");
}
