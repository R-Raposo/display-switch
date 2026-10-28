using System.Runtime.InteropServices;

namespace DisplaySwitch.Native;

/// <summary>The display configuration API (the same one Win+P uses).</summary>
internal static unsafe partial class DisplayConfig
{
    public const uint QDC_ONLY_ACTIVE_PATHS = 0x2;
    public const uint SDC_TOPOLOGY_INTERNAL = 0x1;
    public const uint SDC_TOPOLOGY_EXTEND = 0x4;
    public const uint SDC_APPLY = 0x80;
    public const uint MODE_INFO_TYPE_SOURCE = 1;
    public const int ERROR_INSUFFICIENT_BUFFER = 122;

    // Output technologies of panels built into the device
    public const uint OUTPUT_TECHNOLOGY_LVDS = 6;
    public const uint OUTPUT_TECHNOLOGY_DISPLAYPORT_EMBEDDED = 11;
    public const uint OUTPUT_TECHNOLOGY_UDI_EMBEDDED = 13;
    public const uint OUTPUT_TECHNOLOGY_INTERNAL = 0x80000000;

    /// <summary>
    /// DISPLAYCONFIG_PATH_INFO (72 bytes). Only the fields this program reads are declared:
    /// sourceInfo.modeInfoIdx at offset 12 and targetInfo.outputTechnology at offset 36.
    /// </summary>
    [StructLayout(LayoutKind.Explicit, Size = 72)]
    public struct PathInfo
    {
        [FieldOffset(12)] public uint SourceModeInfoIdx;
        [FieldOffset(36)] public uint TargetOutputTechnology;
    }

    /// <summary>
    /// DISPLAYCONFIG_MODE_INFO (64 bytes). For a source mode, the union at offset 16 is
    /// DISPLAYCONFIG_SOURCE_MODE: width, height, pixelFormat, then position (x at 28, y at 32).
    /// </summary>
    [StructLayout(LayoutKind.Explicit, Size = 64)]
    public struct ModeInfo
    {
        [FieldOffset(0)] public uint InfoType;
        [FieldOffset(28)] public int SourcePositionX;
        [FieldOffset(32)] public int SourcePositionY;
    }

    [LibraryImport("user32.dll")]
    public static partial int GetDisplayConfigBufferSizes(uint flags, out uint pathCount, out uint modeCount);

    [LibraryImport("user32.dll")]
    public static partial int QueryDisplayConfig(uint flags, ref uint pathCount, PathInfo* paths,
        ref uint modeCount, ModeInfo* modes, nint currentTopologyId);

    [LibraryImport("user32.dll")]
    public static partial int SetDisplayConfig(uint pathCount, nint paths, uint modeCount, nint modes, uint flags);
}
