namespace DisplaySwitch.Tests;

public class SettingsTests
{
    [Fact]
    public void Defaults_are_ctrl_alt_f9_and_f10()
    {
        Assert.Equal("Ctrl+Alt+F9", Settings.Defaults.MainScreenOnly?.Text);
        Assert.Equal("Ctrl+Alt+F10", Settings.Defaults.ExtendDisplays?.Text);
    }

    [Fact]
    public void Parse_reads_both_keys_ignoring_case_and_spaces()
    {
        Settings settings = Settings.Parse(["  mainscreenonly = ctrl+shift+alt+d ", "ExtendDisplays=Ctrl+Alt+F11"]);

        Assert.Equal("Ctrl+Alt+Shift+D", settings.MainScreenOnly?.Text);
        Assert.Equal("Ctrl+Alt+F11", settings.ExtendDisplays?.Text);
    }

    [Fact]
    public void Parse_treats_none_as_no_hotkey()
    {
        Settings settings = Settings.Parse(["MainScreenOnly=none", "ExtendDisplays=NONE"]);

        Assert.Null(settings.MainScreenOnly);
        Assert.Null(settings.ExtendDisplays);
    }

    [Fact]
    public void Parse_keeps_defaults_for_missing_or_unreadable_values()
    {
        Settings settings = Settings.Parse(["MainScreenOnly=ctrl+banana", "# comment", "junk line", "Other=Ctrl+Alt+K"]);

        Assert.Equal(Settings.Defaults, settings);
    }

    [Fact]
    public void Load_returns_defaults_when_the_file_is_missing()
    {
        string path = Path.Combine(Path.GetTempPath(), Guid.NewGuid().ToString("N"), "settings.ini");

        Assert.Equal(Settings.Defaults, Settings.Load(path));
    }

    [Fact]
    public void Load_reads_a_real_file()
    {
        string path = Path.GetTempFileName();
        try
        {
            File.WriteAllLines(path, ["MainScreenOnly=Ctrl+Alt+F7", "ExtendDisplays=none"]);

            Settings settings = Settings.Load(path);

            Assert.Equal("Ctrl+Alt+F7", settings.MainScreenOnly?.Text);
            Assert.Null(settings.ExtendDisplays);
        }
        finally
        {
            File.Delete(path);
        }
    }
}
