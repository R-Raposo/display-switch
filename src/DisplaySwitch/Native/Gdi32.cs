using System.Runtime.InteropServices;

namespace DisplaySwitch.Native;

internal static partial class Gdi32
{
    public const int TRANSPARENT = 1;
    public const int FW_NORMAL = 400;
    public const uint DEFAULT_CHARSET = 1;
    public const uint CLEARTYPE_QUALITY = 5;

    [LibraryImport("gdi32.dll")]
    public static partial nint CreateSolidBrush(uint color);

    [LibraryImport("gdi32.dll", EntryPoint = "CreateFontW", StringMarshalling = StringMarshalling.Utf16)]
    public static partial nint CreateFont(int height, int width, int escapement, int orientation, int weight,
        uint italic, uint underline, uint strikeOut, uint charSet, uint outPrecision, uint clipPrecision,
        uint quality, uint pitchAndFamily, string faceName);

    [LibraryImport("gdi32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool DeleteObject(nint handle);

    [LibraryImport("gdi32.dll")]
    public static partial nint SelectObject(nint hdc, nint handle);

    [LibraryImport("gdi32.dll")]
    public static partial uint SetTextColor(nint hdc, uint color);

    [LibraryImport("gdi32.dll")]
    public static partial int SetBkMode(nint hdc, int mode);
}
