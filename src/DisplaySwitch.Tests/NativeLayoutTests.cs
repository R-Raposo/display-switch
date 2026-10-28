using System.Runtime.CompilerServices;
using DisplaySwitch.Native;

namespace DisplaySwitch.Tests;

public class NativeLayoutTests
{
    [Fact]
    public void Display_config_structs_match_the_windows_sdk()
    {
        Assert.Equal(72, Unsafe.SizeOf<DisplayConfig.PathInfo>());
        Assert.Equal(64, Unsafe.SizeOf<DisplayConfig.ModeInfo>());
    }

    [Fact]
    public void User32_structs_match_the_windows_sdk_on_64_bit()
    {
        Assert.True(Environment.Is64BitProcess);
        Assert.Equal(80, Unsafe.SizeOf<User32.WNDCLASSEXW>());
        Assert.Equal(48, Unsafe.SizeOf<User32.MSG>());
        Assert.Equal(104, Unsafe.SizeOf<User32.MONITORINFOEXW>());
        Assert.Equal(72, Unsafe.SizeOf<User32.PAINTSTRUCT>());
    }
}
