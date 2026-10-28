using System.ComponentModel;
using System.Runtime.InteropServices;
using DisplaySwitch.Native;

namespace DisplaySwitch;

/// <summary>
/// Hidden message-only window that receives the global hotkeys, timer ticks and results posted
/// from background work, and that "DisplaySwitch.exe --exit" finds to ask the running copy to quit.
/// </summary>
internal sealed unsafe class HotkeyWindow : IDisposable
{
    private const string ClassName = "DisplaySwitch.Hotkeys";

    private static HotkeyWindow? s_instance;

    private readonly nint _hwnd;
    private readonly Action<int> _onHotkey;
    private readonly Action<nuint> _onTimer;
    private readonly Action<nuint, nint> _onPosted;
    private readonly List<int> _registered = [];

    public HotkeyWindow(Action<int> onHotkey, Action<nuint> onTimer, Action<nuint, nint> onPosted)
    {
        _onHotkey = onHotkey;
        _onTimer = onTimer;
        _onPosted = onPosted;
        nint instance = Kernel32.GetModuleHandle(null);

        fixed (char* className = ClassName)
        {
            var windowClass = new User32.WNDCLASSEXW
            {
                cbSize = (uint)sizeof(User32.WNDCLASSEXW),
                lpfnWndProc = &WndProc,
                hInstance = instance,
                lpszClassName = className,
            };
            if (User32.RegisterClassEx(windowClass) == 0)
            {
                throw new Win32Exception(Marshal.GetLastPInvokeError());
            }
        }

        _hwnd = User32.CreateWindowEx(0, ClassName, null, 0, 0, 0, 0, 0, User32.HWND_MESSAGE, 0, instance, 0);
        if (_hwnd == 0)
        {
            throw new Win32Exception(Marshal.GetLastPInvokeError());
        }

        s_instance = this;
    }

    /// <summary>Registers a global hotkey. Returns false when another program already owns it.</summary>
    public bool Register(int id, Hotkey hotkey)
    {
        if (!User32.RegisterHotKey(_hwnd, id, hotkey.Modifiers | User32.MOD_NOREPEAT, hotkey.VirtualKey))
        {
            return false;
        }
        _registered.Add(id);
        return true;
    }

    public void StartTimer(nuint id, uint intervalMs) => User32.SetTimer(_hwnd, id, intervalMs, 0);

    public void StopTimer(nuint id) => User32.KillTimer(_hwnd, id);

    /// <summary>Hands two values to the window's thread; safe to call from any thread.</summary>
    public void Post(nuint wParam, nint lParam) => User32.PostMessage(_hwnd, User32.WM_APP, wParam, lParam);

    /// <summary>Ends the message loop.</summary>
    public void Close() => User32.PostMessage(_hwnd, User32.WM_CLOSE, 0, 0);

    /// <summary>Asks a running copy to quit. Returns false when none is running.</summary>
    public static bool SignalExit()
    {
        nint hwnd = User32.FindWindowEx(User32.HWND_MESSAGE, 0, ClassName, null);
        return hwnd != 0 && User32.PostMessage(hwnd, User32.WM_CLOSE, 0, 0);
    }

    public static void RunMessageLoop()
    {
        while (User32.GetMessage(out User32.MSG message, 0, 0, 0) > 0)
        {
            User32.TranslateMessage(message);
            User32.DispatchMessage(message);
        }
    }

    public void Dispose()
    {
        foreach (int id in _registered)
        {
            User32.UnregisterHotKey(_hwnd, id);
        }
        _registered.Clear();
        s_instance = null;
        User32.DestroyWindow(_hwnd);
    }

    [UnmanagedCallersOnly]
    private static nint WndProc(nint hwnd, uint message, nuint wParam, nint lParam)
    {
        switch (message)
        {
            case User32.WM_HOTKEY:
                s_instance?._onHotkey((int)wParam);
                return 0;

            case User32.WM_TIMER:
                s_instance?._onTimer(wParam);
                return 0;

            case User32.WM_APP:
                s_instance?._onPosted(wParam, lParam);
                return 0;

            case User32.WM_CLOSE:
                User32.DestroyWindow(hwnd);
                return 0;

            case User32.WM_DESTROY:
                User32.PostQuitMessage(0);
                return 0;
        }

        return User32.DefWindowProc(hwnd, message, wParam, lParam);
    }
}
