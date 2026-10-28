using System.Globalization;

namespace DisplaySwitch;

/// <summary>A global hotkey in the form RegisterHotKey expects, plus its display text.</summary>
internal readonly record struct Hotkey(uint Modifiers, uint VirtualKey, string Text)
{
    public const uint ModAlt = 0x1;
    public const uint ModControl = 0x2;
    public const uint ModShift = 0x4;

    /// <summary>
    /// Parses text like "Ctrl+Alt+F9": modifiers Ctrl (or Control), Alt and Shift, plus exactly one
    /// key A-Z, 0-9 or F1-F12. Case and spaces don't matter. Same rules as install.ps1.
    /// </summary>
    public static bool TryParse(string? text, out Hotkey hotkey)
    {
        hotkey = default;
        if (string.IsNullOrWhiteSpace(text))
        {
            return false;
        }

        uint modifiers = 0;
        uint virtualKey = 0;
        string? key = null;
        foreach (string raw in text.Split('+'))
        {
            string part = raw.Trim().ToUpperInvariant();
            switch (part)
            {
                case "":
                    continue;
                case "CTRL" or "CONTROL":
                    modifiers |= ModControl;
                    break;
                case "ALT":
                    modifiers |= ModAlt;
                    break;
                case "SHIFT":
                    modifiers |= ModShift;
                    break;
                default:
                    if (key is not null || !TryGetVirtualKey(part, out virtualKey))
                    {
                        return false;
                    }
                    key = part;
                    break;
            }
        }

        if (key is null)
        {
            return false;
        }

        var names = new List<string>(4);
        if ((modifiers & ModControl) != 0) names.Add("Ctrl");
        if ((modifiers & ModAlt) != 0) names.Add("Alt");
        if ((modifiers & ModShift) != 0) names.Add("Shift");
        names.Add(key);

        hotkey = new Hotkey(modifiers, virtualKey, string.Join('+', names));
        return true;
    }

    private static bool TryGetVirtualKey(string key, out uint virtualKey)
    {
        virtualKey = 0;

        // Letters and digits use their ASCII code as the virtual-key code
        if (key.Length == 1 && (char.IsAsciiLetterUpper(key[0]) || char.IsAsciiDigit(key[0])))
        {
            virtualKey = key[0];
            return true;
        }

        // F1-F12 are VK_F1 (0x70) onwards; reject forms like "F01"
        if (key.Length is 2 or 3 && key[0] == 'F' && key[1] != '0' &&
            int.TryParse(key.AsSpan(1), NumberStyles.None, CultureInfo.InvariantCulture, out int number) &&
            number is >= 1 and <= 12)
        {
            virtualKey = (uint)(0x70 + number - 1);
            return true;
        }

        return false;
    }
}
