using DisplaySwitch.Native;

namespace DisplaySwitch;

internal enum DisplayMode
{
    MainScreenOnly,
    Extend,
}

internal static unsafe class Display
{
    /// <summary>Applies the topology. Returns 0 on success, otherwise the Windows error code.</summary>
    public static int Switch(DisplayMode mode)
    {
        uint topology = mode == DisplayMode.MainScreenOnly
            ? DisplayConfig.SDC_TOPOLOGY_INTERNAL
            : DisplayConfig.SDC_TOPOLOGY_EXTEND;
        return DisplayConfig.SetDisplayConfig(0, 0, 0, 0, topology | DisplayConfig.SDC_APPLY);
    }

    /// <summary>Number of active screens (not cached, so it reflects a switch straight away).</summary>
    public static int MonitorCount => User32.GetSystemMetrics(User32.SM_CMONITORS);

    /// <summary>
    /// The built-in screen, or the primary monitor when there is none (desktop PCs). In extend mode the
    /// primary monitor may be an external one that is still showing another computer.
    /// </summary>
    public static nint FindBuiltInMonitor()
    {
        nint primary = User32.MonitorFromPoint(default, User32.MONITOR_DEFAULTTOPRIMARY);

        // The configuration can change between the size query and the read; retry a couple of times
        for (int attempt = 0; attempt < 3; attempt++)
        {
            if (DisplayConfig.GetDisplayConfigBufferSizes(DisplayConfig.QDC_ONLY_ACTIVE_PATHS, out uint pathCount, out uint modeCount) != 0)
            {
                break;
            }

            var paths = new DisplayConfig.PathInfo[pathCount];
            var modes = new DisplayConfig.ModeInfo[modeCount];
            int result;
            fixed (DisplayConfig.PathInfo* pathPointer = paths)
            fixed (DisplayConfig.ModeInfo* modePointer = modes)
            {
                result = DisplayConfig.QueryDisplayConfig(DisplayConfig.QDC_ONLY_ACTIVE_PATHS,
                    ref pathCount, pathPointer, ref modeCount, modePointer, 0);
            }

            if (result == DisplayConfig.ERROR_INSUFFICIENT_BUFFER)
            {
                continue;
            }
            if (result != 0)
            {
                break;
            }

            for (int i = 0; i < pathCount; i++)
            {
                DisplayConfig.PathInfo path = paths[i];
                if (!IsBuiltIn(path.TargetOutputTechnology) || path.SourceModeInfoIdx >= modeCount)
                {
                    continue;
                }

                DisplayConfig.ModeInfo source = modes[path.SourceModeInfoIdx];
                if (source.InfoType != DisplayConfig.MODE_INFO_TYPE_SOURCE)
                {
                    continue;
                }

                var topLeft = new User32.POINT { X = source.SourcePositionX, Y = source.SourcePositionY };
                return User32.MonitorFromPoint(topLeft, User32.MONITOR_DEFAULTTOPRIMARY);
            }
            break;
        }

        return primary;
    }

    private static bool IsBuiltIn(uint outputTechnology) => outputTechnology is
        DisplayConfig.OUTPUT_TECHNOLOGY_INTERNAL or
        DisplayConfig.OUTPUT_TECHNOLOGY_LVDS or
        DisplayConfig.OUTPUT_TECHNOLOGY_DISPLAYPORT_EMBEDDED or
        DisplayConfig.OUTPUT_TECHNOLOGY_UDI_EMBEDDED;
}
