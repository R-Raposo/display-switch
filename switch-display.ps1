# Usage: switch-display.ps1 -Mode internal|extend
param(
    [Parameter(Mandatory)]
    [ValidateSet('internal', 'extend')]
    [string]$Mode
)

$label = @{ internal = 'Main screen only'; extend = 'Extend displays' }[$Mode]

# Switch first, before any slow setup. Calls the display API directly (what Win+P
# uses): DisplaySwitch.exe's /internal and /extend arguments are ignored on some
# Windows 11 builds. The API is declared with an in-memory type rather than
# Add-Type, which would run the C# compiler and add about half a second.
$asm  = [AppDomain]::CurrentDomain.DefineDynamicAssembly((New-Object Reflection.AssemblyName 'DisplaySwitchApi'), 'Run')
$type = $asm.DefineDynamicModule('DisplaySwitchApi').DefineType('User32', 'Public, Class')
$setDisplayConfig = $type.DefinePInvokeMethod('SetDisplayConfig', 'user32.dll', 'Public, Static, PinvokeImpl', 'Standard', [int],
    [Type[]]@([uint32], [IntPtr], [uint32], [IntPtr], [uint32]), 'Winapi', 'Auto')
$setDisplayConfig.SetImplementationFlags('PreserveSig')
$user32 = $type.CreateType()

$topology = @{ internal = 0x1; extend = 0x4 }[$Mode]   # SDC_TOPOLOGY_INTERNAL / SDC_TOPOLOGY_EXTEND
$result = $user32::SetDisplayConfig(0, [IntPtr]::Zero, 0, [IntPtr]::Zero, $topology -bor 0x80)   # | SDC_APPLY

# Everything below only prepares the popup, while the monitors finish switching
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# A popup that never takes keyboard focus, so typing in other apps isn't interrupted
# (WarningAction: the class only overrides protected members, which Add-Type reports as "no public methods")
Add-Type -ReferencedAssemblies System.Windows.Forms -WarningAction SilentlyContinue -TypeDefinition @'
using System.Windows.Forms;
public class DisplaySwitchToast : Form {
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override CreateParams CreateParams {
        get {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= 0x08000000 | 0x80 | 0x8;   // WS_EX_NOACTIVATE | WS_EX_TOOLWINDOW | WS_EX_TOPMOST
            return cp;
        }
    }
}
'@

Add-Type -Namespace DisplaySwitch -Name Native -MemberDefinition @'
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct DISPLAY_DEVICE {
    public int cb;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]  public string DeviceName;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
    public int StateFlags;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceID;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
}
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool EnumDisplayDevices(string device, uint devNum, ref DISPLAY_DEVICE dd, uint flags);
'@

# The laptop's built-in screen, or the main display if there isn't one (desktop PCs).
# In extend mode the main display may be an external monitor that is still showing
# another computer, so the popup goes on the built-in screen instead.
function Get-BuiltInScreen {
    try {
        # Monitor IDs (e.g. "SHP1544") of panels connected internally: 0x80000000 = internal,
        # 6 = LVDS, 11 = embedded DisplayPort, 12 = embedded UDI
        $internalIds = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorConnectionParams -ErrorAction Stop |
            Where-Object { @(2147483648, 6, 11, 12) -contains [int64]$_.VideoOutputTechnology } |
            ForEach-Object { ($_.InstanceName -split '\\')[1] }
        foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
            $dd = New-Object DisplaySwitch.Native+DISPLAY_DEVICE
            $dd.cb = [System.Runtime.InteropServices.Marshal]::SizeOf($dd)
            if ([DisplaySwitch.Native]::EnumDisplayDevices($screen.DeviceName, 0, [ref]$dd, 0) -and
                $internalIds -contains ($dd.DeviceID -split '\\')[1]) {
                return $screen
            }
        }
    }
    catch { }
    [System.Windows.Forms.Screen]::PrimaryScreen
}

# A second monitor (especially behind a dock) can take a few seconds to come up
if ($Mode -eq 'extend') {
    $deadline = (Get-Date).AddSeconds(4)
    while ([System.Windows.Forms.SystemInformation]::MonitorCount -lt 2 -and (Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 250
    }
    if ([System.Windows.Forms.SystemInformation]::MonitorCount -lt 2) { $label = 'no second screen found' }
}
elseif ($result -ne 0) {
    $label = "could not switch (error $result)"
}
# Give Windows a moment to settle the new layout before placing the popup
# (the popup setup above already took a while)
Start-Sleep -Milliseconds 500

$form = New-Object DisplaySwitchToast
$form.FormBorderStyle = 'None'
$form.ShowInTaskbar = $false
$form.StartPosition = 'Manual'
$form.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 32)
$form.Size = New-Object System.Drawing.Size(340, 64)

$text = New-Object System.Windows.Forms.Label
$text.Text = "Display: $label"
$text.ForeColor = [System.Drawing.Color]::White
$text.Font = New-Object System.Drawing.Font('Segoe UI', 13)
$text.Dock = 'Fill'
$text.TextAlign = 'MiddleCenter'
$form.Controls.Add($text)

# Bottom-centre of the built-in screen, just above the taskbar
$area = (Get-BuiltInScreen).WorkingArea
$form.Location = New-Object System.Drawing.Point(
    ($area.Left + ($area.Width - $form.Width) / 2),
    ($area.Bottom - $form.Height - 40))

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 4000   # long enough to read once the monitors have finished switching
$timer.Add_Tick({ $timer.Stop(); $form.Close() })
$timer.Start()

[System.Windows.Forms.Application]::Run($form)
