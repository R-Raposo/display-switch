using System.ComponentModel;
using System.Runtime.InteropServices;
using DisplaySwitch.Native;

namespace DisplaySwitch;

/// <summary>
/// The confirmation popup: a small dark window at the bottom centre of the built-in screen that
/// never takes keyboard focus and hides itself after a few seconds. Created once and reused.
/// </summary>
internal sealed unsafe class Toast : IDisposable
{
    private const string ClassName = "DisplaySwitch.Toast";
    private const nuint HideTimerId = 1;
    private const uint VisibleMs = 4000;

    // Sizes at 96 DPI (100% scaling); scaled for the target screen
    private const int MinWidth = 340;
    private const int Height = 64;
    private const int Padding = 24;
    private const int BottomMargin = 40;
    private const int FontPoints = 13;

    private const uint BackgroundColor = 0x00202020; // COLORREF is 0x00BBGGRR
    private const uint TextColor = 0x00FFFFFF;

    private static Toast? s_instance;

    private readonly nint _hwnd;
    private readonly nint _brush;
    private nint _font;
    private uint _fontDpi;
    private string _text = "";

    public Toast()
    {
        _brush = Gdi32.CreateSolidBrush(BackgroundColor);
        nint instance = Kernel32.GetModuleHandle(null);

        fixed (char* className = ClassName)
        {
            var windowClass = new User32.WNDCLASSEXW
            {
                cbSize = (uint)sizeof(User32.WNDCLASSEXW),
                lpfnWndProc = &WndProc,
                hInstance = instance,
                hbrBackground = _brush,
                lpszClassName = className,
            };
            if (User32.RegisterClassEx(windowClass) == 0)
            {
                throw new Win32Exception(Marshal.GetLastPInvokeError());
            }
        }

        _hwnd = User32.CreateWindowEx(
            User32.WS_EX_TOPMOST | User32.WS_EX_TOOLWINDOW | User32.WS_EX_NOACTIVATE,
            ClassName, null, User32.WS_POPUP, 0, 0, 0, 0, 0, 0, instance, 0);
        if (_hwnd == 0)
        {
            throw new Win32Exception(Marshal.GetLastPInvokeError());
        }

        s_instance = this;
    }

    public void Show(string text)
    {
        _text = text;
        Place();
        User32.InvalidateRect(_hwnd, 0, true);
        User32.KillTimer(_hwnd, HideTimerId);
        User32.SetTimer(_hwnd, HideTimerId, VisibleMs, 0);
    }

    public void Dispose()
    {
        s_instance = null;
        User32.DestroyWindow(_hwnd);
        if (_font != 0)
        {
            Gdi32.DeleteObject(_font);
        }
        Gdi32.DeleteObject(_brush);
    }

    /// <summary>Sizes and positions the popup on the built-in screen and shows it without activating it.</summary>
    private void Place()
    {
        nint monitor = Display.FindBuiltInMonitor();
        var info = new User32.MONITORINFOEXW { cbSize = (uint)sizeof(User32.MONITORINFOEXW) };
        if (!User32.GetMonitorInfo(monitor, ref info))
        {
            return;
        }

        uint dpi = Shcore.GetDpiForMonitor(monitor, Shcore.MDT_EFFECTIVE_DPI, out uint dpiX, out _) == 0 ? dpiX : 96;
        EnsureFont(dpi);

        User32.RECT work = info.rcWork;
        int workWidth = work.Right - work.Left;
        int width = Math.Min(Math.Max(Scale(MinWidth, dpi), MeasureText() + 2 * Scale(Padding, dpi)), workWidth);
        int height = Scale(Height, dpi);
        int x = work.Left + (workWidth - width) / 2;
        int y = work.Bottom - height - Scale(BottomMargin, dpi);

        User32.SetWindowPos(_hwnd, User32.HWND_TOPMOST, x, y, width, height,
            User32.SWP_NOACTIVATE | User32.SWP_SHOWWINDOW);
    }

    private void EnsureFont(uint dpi)
    {
        if (_font != 0 && _fontDpi == dpi)
        {
            return;
        }
        if (_font != 0)
        {
            Gdi32.DeleteObject(_font);
        }

        // Negative height = character height in pixels for the given point size
        int height = -(int)(FontPoints * dpi / 72);
        _font = Gdi32.CreateFont(height, 0, 0, 0, Gdi32.FW_NORMAL, 0, 0, 0, Gdi32.DEFAULT_CHARSET,
            0, 0, Gdi32.CLEARTYPE_QUALITY, 0, "Segoe UI");
        _fontDpi = dpi;
    }

    private int MeasureText()
    {
        nint hdc = User32.GetDC(_hwnd);
        nint previous = Gdi32.SelectObject(hdc, _font);
        var bounds = default(User32.RECT);
        User32.DrawText(hdc, _text, -1, ref bounds, User32.DT_CALCRECT | User32.DT_SINGLELINE | User32.DT_NOPREFIX);
        Gdi32.SelectObject(hdc, previous);
        User32.ReleaseDC(_hwnd, hdc);
        return bounds.Right - bounds.Left;
    }

    private void Paint()
    {
        nint hdc = User32.BeginPaint(_hwnd, out User32.PAINTSTRUCT paint);
        User32.GetClientRect(_hwnd, out User32.RECT client);
        User32.FillRect(hdc, client, _brush);
        Gdi32.SetBkMode(hdc, Gdi32.TRANSPARENT);
        Gdi32.SetTextColor(hdc, TextColor);
        nint previous = Gdi32.SelectObject(hdc, _font);
        User32.DrawText(hdc, _text, -1, ref client,
            User32.DT_CENTER | User32.DT_VCENTER | User32.DT_SINGLELINE | User32.DT_NOPREFIX);
        Gdi32.SelectObject(hdc, previous);
        User32.EndPaint(_hwnd, paint);
    }

    private static int Scale(int value, uint dpi) => (int)(value * dpi / 96);

    [UnmanagedCallersOnly]
    private static nint WndProc(nint hwnd, uint message, nuint wParam, nint lParam)
    {
        Toast? toast = s_instance;
        switch (message)
        {
            case User32.WM_PAINT when toast is not null:
                toast.Paint();
                return 0;

            case User32.WM_TIMER when wParam == HideTimerId:
                User32.KillTimer(hwnd, HideTimerId);
                User32.ShowWindow(hwnd, User32.SW_HIDE);
                return 0;

            // Screens were added, removed or rearranged while the popup is up: move it back onto the built-in screen
            case User32.WM_DISPLAYCHANGE when toast is not null && User32.IsWindowVisible(hwnd):
                toast.Place();
                break;

            // The taskbar arrives on a screen after the switch, shrinking its work area: move above it
            case User32.WM_SETTINGCHANGE when wParam == User32.SPI_SETWORKAREA && toast is not null && User32.IsWindowVisible(hwnd):
                toast.Place();
                break;

            // The popup sizes itself for each screen's DPI; ignore Windows' suggested size
            case User32.WM_DPICHANGED:
                return 0;
        }

        return User32.DefWindowProc(hwnd, message, wParam, lParam);
    }
}
