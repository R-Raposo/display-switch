namespace DisplaySwitch.Tests;

public class HotkeyTests
{
    [Theory]
    [InlineData("Ctrl+Alt+F9", 0x3u, 0x78u, "Ctrl+Alt+F9")]
    [InlineData("ctrl + alt + f10", 0x3u, 0x79u, "Ctrl+Alt+F10")]
    [InlineData("Control+Shift+Alt+D", 0x7u, 0x44u, "Ctrl+Alt+Shift+D")]
    [InlineData("Alt+Ctrl+Shift+F12", 0x7u, 0x7Bu, "Ctrl+Alt+Shift+F12")]
    [InlineData("Ctrl+Alt+7", 0x3u, 0x37u, "Ctrl+Alt+7")]
    [InlineData("Ctrl++Alt+F1", 0x3u, 0x70u, "Ctrl+Alt+F1")]
    [InlineData("F5", 0x0u, 0x74u, "F5")]
    public void TryParse_accepts_valid_text(string text, uint modifiers, uint virtualKey, string normalized)
    {
        Assert.True(Hotkey.TryParse(text, out Hotkey hotkey));
        Assert.Equal(modifiers, hotkey.Modifiers);
        Assert.Equal(virtualKey, hotkey.VirtualKey);
        Assert.Equal(normalized, hotkey.Text);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("Ctrl+Alt")]
    [InlineData("ctrl+banana")]
    [InlineData("Win+P")]
    [InlineData("Ctrl+Alt+F13")]
    [InlineData("Ctrl+Alt+F0")]
    [InlineData("Ctrl+Alt+F01")]
    [InlineData("Ctrl+A+B")]
    public void TryParse_rejects_invalid_text(string? text)
    {
        Assert.False(Hotkey.TryParse(text, out _));
    }
}
