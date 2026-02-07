$csharpSource = @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Interop;

public class WindowHelperV3 {
    private static HwndSourceHook _hook;
    
    public static void RegisterTaskbarFix(IntPtr hwnd) {
        try {
            HwndSource source = HwndSource.FromHwnd(hwnd);
            if (source != null) {
                _hook = new HwndSourceHook(HookProc);
                source.AddHook(_hook);
            }
        } catch (Exception ex) {
            Console.WriteLine("Failed to register hook: " + ex.Message);
        }
    }

    private static IntPtr HookProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled) {
        if (msg == 0x0024) { // WM_GETMINMAXINFO
            AdjustMinMaxInfo(hwnd, lParam);
            handled = true;
        }
        return IntPtr.Zero;
    }

    // --- USER32 (Window Styles & Blur Falling back) ---
    [DllImport("user32.dll")]
    private static extern int GetWindowLong(IntPtr hWnd, int nIndex);
    
    [DllImport("user32.dll", EntryPoint = "SetWindowLong")]
    private static extern int SetWindowLong32(IntPtr hWnd, int nIndex, int dwNewLong);
    
    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtr")]
    private static extern IntPtr SetWindowLongPtr64(IntPtr hWnd, int nIndex, IntPtr dwNewLong);

    [DllImport("user32.dll")]
    private static extern int SetWindowCompositionAttribute(IntPtr hwnd, ref WindowCompositionAttributeData data);

    [StructLayout(LayoutKind.Sequential)]
    private struct WindowCompositionAttributeData {
        public WindowCompositionAttribute Attribute;
        public IntPtr Data;
        public int SizeOfData;
    }

    private enum WindowCompositionAttribute {
        WCA_ACCENT_POLICY = 19
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct AccentPolicy {
        public AccentState AccentState;
        public int AccentFlags;
        public int GradientColor;
        public int AnimationId;
    }

    private enum AccentState {
        ACCENT_DISABLED = 0,
        ACCENT_ENABLE_GRADIENT = 1,
        ACCENT_ENABLE_TRANSPARENTGRADIENT = 2,
        ACCENT_ENABLE_BLURBEHIND = 3,
        ACCENT_ENABLE_ACRYLICBLURBEHIND = 4, // Windows 10 1803+
        ACCENT_INVALID_STATE = 5
    }

    private const int GWL_EXSTYLE = -20;
    private const int WS_EX_APPWINDOW = 0x00040000;
    private const int WS_EX_TOOLWINDOW = 0x00000080;

    public static IntPtr SetWindowLongPtr(IntPtr hWnd, int nIndex, IntPtr dwNewLong) {
        if (IntPtr.Size == 8)
            return SetWindowLongPtr64(hWnd, nIndex, dwNewLong);
        else
            return new IntPtr(SetWindowLong32(hWnd, nIndex, dwNewLong.ToInt32()));
    }

    public static void HideFromTaskbar(IntPtr hWnd) {
        IntPtr exStyle = (IntPtr)GetWindowLong(hWnd, GWL_EXSTYLE);
        long val = exStyle.ToInt64();
        val = val & ~WS_EX_APPWINDOW;
        val = val | WS_EX_TOOLWINDOW;
        SetWindowLongPtr(hWnd, GWL_EXSTYLE, (IntPtr)val);
    }

    // --- DWMAPI (Visual Effects Win11) ---
    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

    private const int DWMWA_USE_IMMERSIVE_DARK_MODE = 20;
    private const int DWMWA_SYSTEMBACKDROP_TYPE = 38;
    private const int DWMWA_WINDOW_CORNER_PREFERENCE = 33;
    
    private const int DWMSBT_TABBEDWINDOW = 4; // Mica Alt
    private const int DWMSBT_MAINWINDOW = 2; // Mica

    public static void SetWindowTheme(IntPtr hWnd, bool isDark) {
        int darkMode = isDark ? 1 : 0;
        DwmSetWindowAttribute(hWnd, DWMWA_USE_IMMERSIVE_DARK_MODE, ref darkMode, sizeof(int));
    }

    public static void ApplyBlur(IntPtr hwnd, bool isDark) {
        // 1. Try Win11 Backdrop first (Mica)
        int backdrop = DWMSBT_MAINWINDOW;
        int result = DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, ref backdrop, sizeof(int));
        
        if (result != 0) {
            // 2. Fallback to Win10 Acrylic Blur
            var accent = new AccentPolicy();
            accent.AccentState = AccentState.ACCENT_ENABLE_ACRYLICBLURBEHIND;
            
            // Set tint for Acrylic (AABBGRRR)
            // We use a high alpha to prevent the "messy" look user complained about
            if (isDark) accent.GradientColor = (0x99 << 24) | (0x12 << 16) | (0x12 << 8) | 0x12; 
            else accent.GradientColor = (0xCC << 24) | (0xF5 << 16) | (0xF5 << 8) | 0xF5;

            var accentStructSize = Marshal.SizeOf(accent);
            var accentPtr = Marshal.AllocHGlobal(accentStructSize);
            Marshal.StructureToPtr(accent, accentPtr, false);

            var data = new WindowCompositionAttributeData();
            data.Attribute = WindowCompositionAttribute.WCA_ACCENT_POLICY;
            data.SizeOfData = accentStructSize;
            data.Data = accentPtr;

            SetWindowCompositionAttribute(hwnd, ref data);
            Marshal.FreeHGlobal(accentPtr);
        }
    }

    // --- (Rest of the MinMax functions preserved) ---
    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int x; public int y; }
    [StructLayout(LayoutKind.Sequential)]
    public struct MINMAXINFO { public POINT ptReserved; public POINT ptMaxSize; public POINT ptMaxPosition; public POINT ptMinTrackSize; public POINT ptMaxTrackSize; }
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)]
    public struct MONITORINFO { public int cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags; }
    [DllImport("user32.dll")]
    private static extern IntPtr MonitorFromWindow(IntPtr handle, int flags);
    [DllImport("user32.dll")]
    private static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFO lpmi);

    public static void AdjustMinMaxInfo(IntPtr hwnd, IntPtr lParam) {
        try {
            IntPtr monitor = MonitorFromWindow(hwnd, 2); 
            if (monitor != IntPtr.Zero) {
                MONITORINFO monitorInfo = new MONITORINFO();
                monitorInfo.cbSize = Marshal.SizeOf(typeof(MONITORINFO));
                GetMonitorInfo(monitor, ref monitorInfo);
                RECT rcWork = monitorInfo.rcWork;
                RECT rcMonitor = monitorInfo.rcMonitor;
                int modWidth = Math.Abs(rcWork.Right - rcWork.Left);
                int modHeight = Math.Abs(rcWork.Bottom - rcWork.Top);
                Marshal.WriteInt32(lParam, 8, modWidth);
                Marshal.WriteInt32(lParam, 12, modHeight);
                Marshal.WriteInt32(lParam, 16, Math.Abs(rcWork.Left - rcMonitor.Left));
                Marshal.WriteInt32(lParam, 20, Math.Abs(rcWork.Top - rcMonitor.Top));
            }
        } catch {}
    }
}
'@

function Initialize-WindowUtils {
    $dllPath = Join-Path $global:InstallationRoot "config\WindowHelperV3.dll"
    if (-not ("WindowHelperV3" -as [type])) {
        if (Test-Path $dllPath) {
            try { 
                Add-Type -TypeDefinition $csharpSource -Language CSharp -OutputAssembly $dllPath -ReferencedAssemblies "PresentationCore", "WindowsBase", "PresentationFramework", "System.Xaml" -ErrorAction Stop
            }
            catch { 
                # If cached/locked, might fail, but usually assumes loaded. 
                # Fallback to in-memory if file write fails (rare)
                Add-Type -TypeDefinition $csharpSource -Language CSharp -ReferencedAssemblies "PresentationCore", "WindowsBase", "PresentationFramework", "System.Xaml"
            }
        }
        else {
            Add-Type -TypeDefinition $csharpSource -Language CSharp -OutputAssembly $dllPath -ReferencedAssemblies "PresentationCore", "WindowsBase", "PresentationFramework", "System.Xaml"
        }
    }
}

function Apply-MicaEffect {
    param($Window)
    Initialize-WindowUtils
    try {
        $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($Window)).Handle
        [WindowHelperV2]::ApplySystemBackdrop($hwnd)
    }
    catch { Write-AppLog -Message "Mica Effect failed: $_" -Level WARN }
}

