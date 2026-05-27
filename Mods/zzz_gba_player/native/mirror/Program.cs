using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text;

internal static class Program
{
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_KEYUP = 0x0101;
    private const uint PW_CLIENTONLY = 0x00000001;
    private const int SW_HIDE = 0;
    private const int SW_SHOWNOACTIVATE = 4;
    private const uint CLSCTX_ALL = 23;
    private const int THREAD_SUSPEND_RESUME = 0x0002;
    private const uint SWP_NOSIZE = 0x0001;
    private const uint SWP_NOMOVE = 0x0002;
    private const uint SWP_NOACTIVATE = 0x0010;
    private const uint SWP_FRAMECHANGED = 0x0020;
    private const uint SWP_SHOWWINDOW = 0x0040;
    private const uint MAPVK_VK_TO_VSC = 0;
    private const int GWL_STYLE = -16;
    private const int GWL_EXSTYLE = -20;
    private const long WS_VISIBLE = 0x10000000L;
    private const long WS_CHILD = 0x40000000L;
    private const long WS_POPUP = 0x80000000L;
    private const long WS_CAPTION = 0x00C00000L;
    private const long WS_THICKFRAME = 0x00040000L;
    private const long WS_SYSMENU = 0x00080000L;
    private const long WS_MINIMIZEBOX = 0x00020000L;
    private const long WS_MAXIMIZEBOX = 0x00010000L;
    private const int WS_EX_TOOLWINDOW = 0x00000080;
    private const int WS_EX_APPWINDOW = 0x00040000;
    private static readonly IntPtr HWND_TOP = new(0);
    private static readonly IntPtr HWND_BOTTOM = new(1);

    private static readonly Dictionary<string, int[]> Keys = new(StringComparer.OrdinalIgnoreCase)
    {
        ["UP"] = new[] { 0x49, 0x26 },
        ["DOWN"] = new[] { 0x4B, 0x28 },
        ["LEFT"] = new[] { 0x4A, 0x25 },
        ["RIGHT"] = new[] { 0x4C, 0x27 },
        ["A"] = new[] { 0x58 },
        ["B"] = new[] { 0x5A },
        ["L"] = new[] { 0x41 },
        ["R"] = new[] { 0x53 },
        ["START"] = new[] { 0x0D },
        ["SELECT"] = new[] { 0x08 }
    };

    [DllImport("user32.dll")] private static extern bool PrintWindow(IntPtr hwnd, IntPtr hdcBlt, uint nFlags);
    [DllImport("user32.dll")] private static extern bool GetClientRect(IntPtr hwnd, out RECT lpRect);
    [DllImport("user32.dll")] private static extern bool IsWindow(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern bool PostMessage(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] private static extern bool MoveWindow(IntPtr hwnd, int x, int y, int w, int h, bool repaint);
    [DllImport("user32.dll")] private static extern bool ShowWindow(IntPtr hwnd, int nCmdShow);
    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern bool GetWindowRect(IntPtr hwnd, out RECT lpRect);
    [DllImport("user32.dll")] private static extern bool SetWindowPos(IntPtr hwnd, IntPtr hwndInsertAfter, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] private static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);
    [DllImport("user32.dll")] private static extern IntPtr GetParent(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);
    [DllImport("user32.dll")] private static extern uint MapVirtualKey(uint uCode, uint uMapType);
    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")] private static extern IntPtr GetWindowLongPtr(IntPtr hWnd, int nIndex);
    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW")] private static extern IntPtr SetWindowLongPtr(IntPtr hWnd, int nIndex, IntPtr dwNewLong);
    [DllImport("kernel32.dll")] private static extern IntPtr OpenThread(int dwDesiredAccess, bool bInheritHandle, uint dwThreadId);
    [DllImport("kernel32.dll")] private static extern uint SuspendThread(IntPtr hThread);
    [DllImport("kernel32.dll")] private static extern int ResumeThread(IntPtr hThread);
    [DllImport("kernel32.dll")] private static extern bool CloseHandle(IntPtr hObject);

    private delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    private sealed class Options
    {
        public string Emulator = "";
        public string Rom = "";
        public string Frame = "";
        public string Command = "";
        public string Status = "";
        public int Width = 240;
        public int Height = 160;
        public int Fps = 20;
        public int Volume = 64;
        public int VolumePercent = 25;
        public bool HideWindow = true;
        public bool EmbedWindow = true;
        public int HostPid;
        public int RectX;
        public int RectY;
        public int RectWidth = 240;
        public int RectHeight = 160;
        public int LogicalWidth;
        public int LogicalHeight;
        public bool LockAspect = true;
    }

    public static int Main(string[] args)
    {
        var opt = ParseArgs(args);
        try
        {
            var foregroundBeforeLaunch = GetForegroundWindow();
            Directory.CreateDirectory(Path.GetDirectoryName(opt.Frame) ?? ".");
            Directory.CreateDirectory(Path.GetDirectoryName(opt.Command) ?? ".");
            Directory.CreateDirectory(Path.GetDirectoryName(opt.Status) ?? ".");
            File.WriteAllText(opt.Command, "");

            var host = ResolveHostWindow(opt, foregroundBeforeLaunch);
            using var proc = StartEmulator(opt);
            var hwnd = WaitForWindow(proc);
            if (hwnd == IntPtr.Zero)
            {
                WriteStatus(opt, "error", "mGBA window was not found.");
                return 2;
            }

            var embedded = opt.EmbedWindow && host != IntPtr.Zero && host != hwnd;
            if (embedded)
            {
                embedded = EmbedInHost(hwnd, host, opt);
                if (embedded) SetForegroundWindow(host);
            }
            if (!embedded && opt.HideWindow)
            {
                HideFromTaskbar(hwnd);
                ShowWindow(hwnd, SW_SHOWNOACTIVATE);
                ParkBehindHost(hwnd, host);
                if (host != IntPtr.Zero && host != hwnd)
                {
                    SetForegroundWindow(host);
                }
            }

            WriteStatus(opt, "ready", $"mode={(embedded ? "embed" : "capture")}\npid={proc.Id};hwnd={hwnd};host={host};frame=0");
            RunLoop(opt, proc, hwnd, host, embedded);
            return 0;
        }
        catch (Exception ex)
        {
            WriteStatus(opt, "error", ex.ToString());
            return 1;
        }
    }

    private static Options ParseArgs(string[] args)
    {
        var opt = new Options();
        for (var i = 0; i < args.Length; i++)
        {
            string value() => i + 1 < args.Length ? args[++i] : "";
            switch (args[i])
            {
                case "--emulator": opt.Emulator = value(); break;
                case "--rom": opt.Rom = value(); break;
                case "--frame": opt.Frame = value(); break;
                case "--command": opt.Command = value(); break;
                case "--status": opt.Status = value(); break;
                case "--width": int.TryParse(value(), out opt.Width); break;
                case "--height": int.TryParse(value(), out opt.Height); break;
                case "--fps": int.TryParse(value(), out opt.Fps); break;
                case "--volume": int.TryParse(value(), out opt.Volume); break;
                case "--volume-percent": int.TryParse(value(), out opt.VolumePercent); break;
                case "--host-pid": int.TryParse(value(), out opt.HostPid); break;
                case "--logical-width": int.TryParse(value(), out opt.LogicalWidth); break;
                case "--logical-height": int.TryParse(value(), out opt.LogicalHeight); break;
                case "--rect":
                    int.TryParse(value(), out opt.RectX);
                    int.TryParse(value(), out opt.RectY);
                    int.TryParse(value(), out opt.RectWidth);
                    int.TryParse(value(), out opt.RectHeight);
                    break;
                case "--embed": opt.EmbedWindow = true; break;
                case "--no-embed": opt.EmbedWindow = false; break;
                case "--lock-aspect": opt.LockAspect = true; break;
                case "--free-aspect": opt.LockAspect = false; break;
                case "--show-window": opt.HideWindow = false; break;
            }
        }
        if (string.IsNullOrWhiteSpace(opt.Emulator) || !File.Exists(opt.Emulator)) throw new FileNotFoundException("Emulator not found", opt.Emulator);
        if (string.IsNullOrWhiteSpace(opt.Rom) || !File.Exists(opt.Rom)) throw new FileNotFoundException("ROM not found", opt.Rom);
        if (string.IsNullOrWhiteSpace(opt.Frame)) throw new ArgumentException("--frame is required");
        if (string.IsNullOrWhiteSpace(opt.Command)) throw new ArgumentException("--command is required");
        if (string.IsNullOrWhiteSpace(opt.Status)) throw new ArgumentException("--status is required");
        opt.Width = Math.Max(1, opt.Width);
        opt.Height = Math.Max(1, opt.Height);
        opt.RectWidth = Math.Max(1, opt.RectWidth);
        opt.RectHeight = Math.Max(1, opt.RectHeight);
        opt.Fps = Math.Clamp(opt.Fps, 1, 60);
        opt.Volume = Math.Clamp(opt.Volume, 0, 512);
        opt.VolumePercent = Math.Clamp(opt.VolumePercent, 0, 100);
        return opt;
    }

    private static Process StartEmulator(Options opt)
    {
        var psi = new ProcessStartInfo
        {
            FileName = opt.Emulator,
            WorkingDirectory = Path.GetDirectoryName(opt.Emulator) ?? ".",
            UseShellExecute = false
        };
        psi.ArgumentList.Add("--scale");
        psi.ArgumentList.Add("3");
        psi.ArgumentList.Add("-C");
        psi.ArgumentList.Add($"volume={opt.Volume}");
        psi.ArgumentList.Add("-C");
        psi.ArgumentList.Add("mute=0");
        psi.ArgumentList.Add(opt.Rom);
        return Process.Start(psi) ?? throw new InvalidOperationException("Failed to start mGBA.");
    }

    private static IntPtr WaitForWindow(Process proc)
    {
        for (var i = 0; i < 200; i++)
        {
            if (proc.HasExited) return IntPtr.Zero;
            proc.Refresh();
            if (proc.MainWindowHandle != IntPtr.Zero) return proc.MainWindowHandle;
            Thread.Sleep(50);
        }
        return IntPtr.Zero;
    }

    private static void RunLoop(Options opt, Process proc, IntPtr hwnd, IntPtr host, bool embedded)
    {
        long commandOffset = 0;
        var frame = 0;
        var paused = false;
        var delay = Math.Max(15, 1000 / opt.Fps);
        SetProcessVolume(proc.Id, opt.VolumePercent);
        while (!proc.HasExited && IsWindow(hwnd))
        {
            if (ProcessCommands(opt, ref commandOffset, hwnd, proc, host, embedded, ref paused)) break;
            if (!paused && embedded)
            {
                MoveEmbeddedWindow(hwnd, host, opt);
            }
            else if (!paused)
            {
                if (opt.HideWindow) ParkBehindHost(hwnd, host);
                CaptureFrame(hwnd, opt.Frame, opt.Width, opt.Height);
            }
            frame++;
            if (frame % opt.Fps == 0) WriteStatus(opt, "ready", $"mode={(embedded ? "embed" : "capture")}\npaused={(paused ? 1 : 0)}\nvolume={opt.VolumePercent}\npid={proc.Id};hwnd={hwnd};host={host};frame={frame}");
            Thread.Sleep(delay);
        }
        try { if (!proc.HasExited) proc.Kill(); } catch { }
        WriteStatus(opt, "stopped", $"frame={frame}");
    }

    private static bool ProcessCommands(Options opt, ref long offset, IntPtr hwnd, Process proc, IntPtr host, bool embedded, ref bool paused)
    {
        if (!File.Exists(opt.Command)) return false;
        using var fs = new FileStream(opt.Command, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
        if (offset > fs.Length) offset = 0;
        fs.Seek(offset, SeekOrigin.Begin);
        using var reader = new StreamReader(fs, Encoding.UTF8, true, 1024, true);
        string? line;
        while ((line = reader.ReadLine()) != null)
        {
            var parts = line.Trim().Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length == 0) continue;
            if (parts[0].Equals("quit", StringComparison.OrdinalIgnoreCase)) return true;
            if (parts[0].Equals("tap", StringComparison.OrdinalIgnoreCase) && parts.Length > 1) Tap(hwnd, parts[1]);
            if (parts[0].Equals("down", StringComparison.OrdinalIgnoreCase) && parts.Length > 1) KeyDown(hwnd, parts[1]);
            if (parts[0].Equals("up", StringComparison.OrdinalIgnoreCase) && parts.Length > 1) KeyUp(hwnd, parts[1]);
            if (parts[0].Equals("hold", StringComparison.OrdinalIgnoreCase) && parts.Length > 1)
            {
                var ms = parts.Length > 2 && int.TryParse(parts[2], out var parsed) ? parsed : 90;
                Hold(hwnd, parts[1], ms);
            }
            if (parts[0].Equals("pause", StringComparison.OrdinalIgnoreCase)) PauseEmulator(proc, hwnd, ref paused);
            if (parts[0].Equals("resume", StringComparison.OrdinalIgnoreCase)) ResumeEmulator(proc, hwnd, host, embedded, opt, ref paused);
            if (parts[0].Equals("volume", StringComparison.OrdinalIgnoreCase) && parts.Length > 1)
            {
                if (int.TryParse(parts[1], out var volume))
                {
                    opt.VolumePercent = Math.Clamp(volume, 0, 100);
                    SetProcessVolume(proc.Id, opt.VolumePercent);
                }
            }
            if (parts[0].Equals("reset", StringComparison.OrdinalIgnoreCase)) Tap(hwnd, "START");
            if (parts[0].Equals("rect", StringComparison.OrdinalIgnoreCase) && parts.Length >= 5)
            {
                int.TryParse(parts[1], out opt.RectX);
                int.TryParse(parts[2], out opt.RectY);
                int.TryParse(parts[3], out opt.RectWidth);
                int.TryParse(parts[4], out opt.RectHeight);
                opt.RectWidth = Math.Max(1, opt.RectWidth);
                opt.RectHeight = Math.Max(1, opt.RectHeight);
                if (parts.Length >= 7)
                {
                    int.TryParse(parts[5], out opt.LogicalWidth);
                    int.TryParse(parts[6], out opt.LogicalHeight);
                }
                if (embedded) MoveEmbeddedWindow(hwnd, host, opt);
            }
        }
        offset = fs.Position;
        return proc.HasExited;
    }

    private static void Tap(IntPtr hwnd, string keyName)
    {
        Hold(hwnd, keyName, 45);
    }

    private static void Hold(IntPtr hwnd, string keyName, int milliseconds)
    {
        milliseconds = Math.Clamp(milliseconds, 25, 500);
        KeyDown(hwnd, keyName);
        Thread.Sleep(milliseconds);
        KeyUp(hwnd, keyName);
    }

    private static void KeyDown(IntPtr hwnd, string keyName)
    {
        if (!Keys.TryGetValue(keyName, out var keys)) return;
        foreach (var vk in keys)
        {
            PostMessage(hwnd, WM_KEYDOWN, (IntPtr)vk, KeyLParam(vk, false));
        }
    }

    private static void KeyUp(IntPtr hwnd, string keyName)
    {
        if (!Keys.TryGetValue(keyName, out var keys)) return;
        for (var i = keys.Length - 1; i >= 0; i--)
        {
            var vk = keys[i];
            PostMessage(hwnd, WM_KEYUP, (IntPtr)vk, KeyLParam(vk, true));
        }
    }

    private static void PauseEmulator(Process proc, IntPtr hwnd, ref bool paused)
    {
        if (paused || proc.HasExited) return;
        ShowWindow(hwnd, SW_HIDE);
        SuspendProcess(proc);
        paused = true;
    }

    private static void ResumeEmulator(Process proc, IntPtr hwnd, IntPtr host, bool embedded, Options opt, ref bool paused)
    {
        if (proc.HasExited) return;
        if (paused)
        {
            ResumeProcess(proc);
            paused = false;
        }
        ShowWindow(hwnd, SW_SHOWNOACTIVATE);
        if (embedded) MoveEmbeddedWindow(hwnd, host, opt);
        else if (opt.HideWindow) ParkBehindHost(hwnd, host);
        SetProcessVolume(proc.Id, opt.VolumePercent);
    }

    private static void SuspendProcess(Process proc)
    {
        try
        {
            foreach (ProcessThread thread in proc.Threads)
            {
                var handle = OpenThread(THREAD_SUSPEND_RESUME, false, (uint)thread.Id);
                if (handle == IntPtr.Zero) continue;
                try { SuspendThread(handle); }
                finally { CloseHandle(handle); }
            }
        }
        catch { }
    }

    private static void ResumeProcess(Process proc)
    {
        try
        {
            foreach (ProcessThread thread in proc.Threads)
            {
                var handle = OpenThread(THREAD_SUSPEND_RESUME, false, (uint)thread.Id);
                if (handle == IntPtr.Zero) continue;
                try
                {
                    while (ResumeThread(handle) > 0) { }
                }
                finally { CloseHandle(handle); }
            }
        }
        catch { }
    }

    private static IntPtr KeyLParam(int vk, bool keyUp)
    {
        var scan = (int)MapVirtualKey((uint)vk, MAPVK_VK_TO_VSC);
        var value = 1 | (scan << 16);
        if (IsExtendedKey(vk)) value |= 1 << 24;
        if (keyUp) value |= (1 << 30) | unchecked((int)0x80000000);
        return (IntPtr)value;
    }

    private static bool IsExtendedKey(int vk)
    {
        return vk is 0x21 or 0x22 or 0x23 or 0x24 or 0x25 or 0x26 or 0x27 or 0x28 or 0x2D or 0x2E;
    }

    private static void ParkBehindHost(IntPtr hwnd, IntPtr host)
    {
        var x = 0;
        var y = 0;
        var w = 720;
        var h = 480;
        if (host != IntPtr.Zero && host != hwnd && GetWindowRect(host, out var rect))
        {
            x = rect.Left;
            y = rect.Top;
            w = Math.Max(240, rect.Right - rect.Left);
            h = Math.Max(160, rect.Bottom - rect.Top);
        }
        SetWindowPos(hwnd, HWND_BOTTOM, x, y, w, h, SWP_NOACTIVATE | SWP_SHOWWINDOW);
    }

    private static IntPtr ResolveHostWindow(Options opt, IntPtr fallback)
    {
        if (opt.HostPid > 0)
        {
            var byPid = FindWindowForProcess(opt.HostPid);
            if (byPid != IntPtr.Zero) return byPid;
        }
        return fallback;
    }

    private static IntPtr FindWindowForProcess(int pid)
    {
        var result = IntPtr.Zero;
        EnumWindows((hwnd, _) =>
        {
            GetWindowThreadProcessId(hwnd, out var windowPid);
            if (windowPid == pid && GetParent(hwnd) == IntPtr.Zero && IsWindowVisible(hwnd))
            {
                result = hwnd;
                return false;
            }
            return true;
        }, IntPtr.Zero);
        return result;
    }

    private static bool EmbedInHost(IntPtr hwnd, IntPtr host, Options opt)
    {
        HideFromTaskbar(hwnd);
        SetParent(hwnd, host);
        var style = GetWindowLongPtr(hwnd, GWL_STYLE).ToInt64();
        style &= ~(WS_POPUP | WS_CAPTION | WS_THICKFRAME | WS_SYSMENU | WS_MINIMIZEBOX | WS_MAXIMIZEBOX);
        style |= WS_CHILD | WS_VISIBLE;
        SetWindowLongPtr(hwnd, GWL_STYLE, (IntPtr)style);
        var exStyle = GetWindowLongPtr(hwnd, GWL_EXSTYLE).ToInt64();
        exStyle &= ~WS_EX_APPWINDOW;
        exStyle |= WS_EX_TOOLWINDOW;
        SetWindowLongPtr(hwnd, GWL_EXSTYLE, (IntPtr)exStyle);
        SetWindowPos(hwnd, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_FRAMECHANGED | SWP_SHOWWINDOW);
        ShowWindow(hwnd, SW_SHOWNOACTIVATE);
        MoveEmbeddedWindow(hwnd, host, opt);
        return GetParent(hwnd) == host;
    }

    private static void MoveEmbeddedWindow(IntPtr hwnd, IntPtr host, Options opt)
    {
        if (host == IntPtr.Zero || !GetClientRect(host, out var client))
        {
            SetWindowPos(hwnd, HWND_TOP, opt.RectX, opt.RectY, opt.RectWidth, opt.RectHeight, SWP_NOACTIVATE | SWP_SHOWWINDOW);
            return;
        }
        var clientW = Math.Max(1, client.Right - client.Left);
        var clientH = Math.Max(1, client.Bottom - client.Top);
        var logicalW = opt.LogicalWidth > 0 ? opt.LogicalWidth : clientW;
        var logicalH = opt.LogicalHeight > 0 ? opt.LogicalHeight : clientH;
        var scaleX = clientW / (double)Math.Max(1, logicalW);
        var scaleY = clientH / (double)Math.Max(1, logicalH);
        var scale = Math.Min(scaleX, scaleY);
        var contentW = logicalW * scale;
        var contentH = logicalH * scale;
        var offsetX = (clientW - contentW) / 2.0;
        var offsetY = (clientH - contentH) / 2.0;
        var x = (int)Math.Round(offsetX + (opt.RectX * scale));
        var y = (int)Math.Round(offsetY + (opt.RectY * scale));
        var w = Math.Max(1, (int)Math.Round(opt.RectWidth * scale));
        var h = Math.Max(1, (int)Math.Round(opt.RectHeight * scale));
        if (opt.LockAspect)
        {
            const double gbaAspect = 240.0 / 160.0;
            var currentAspect = w / (double)Math.Max(1, h);
            if (currentAspect > gbaAspect)
            {
                var adjusted = Math.Max(1, (int)Math.Round(h * gbaAspect));
                x += (w - adjusted) / 2;
                w = adjusted;
            }
            else if (currentAspect < gbaAspect)
            {
                var adjusted = Math.Max(1, (int)Math.Round(w / gbaAspect));
                y += (h - adjusted) / 2;
                h = adjusted;
            }
        }
        SetWindowPos(hwnd, HWND_TOP, x, y, w, h, SWP_NOACTIVATE | SWP_SHOWWINDOW);
    }

    private static void HideFromTaskbar(IntPtr hwnd)
    {
        var style = GetWindowLongPtr(hwnd, GWL_EXSTYLE).ToInt64();
        style &= ~WS_EX_APPWINDOW;
        style |= WS_EX_TOOLWINDOW;
        SetWindowLongPtr(hwnd, GWL_EXSTYLE, (IntPtr)style);
    }

    private static void CaptureFrame(IntPtr hwnd, string framePath, int width, int height)
    {
        if (!GetClientRect(hwnd, out var rect)) return;
        var sourceW = Math.Max(1, rect.Right - rect.Left);
        var sourceH = Math.Max(1, rect.Bottom - rect.Top);
        using var source = new Bitmap(sourceW, sourceH, PixelFormat.Format24bppRgb);
        using (var g = Graphics.FromImage(source))
        {
            var hdc = g.GetHdc();
            try { PrintWindow(hwnd, hdc, PW_CLIENTONLY); }
            finally { g.ReleaseHdc(hdc); }
        }
        using var dest = new Bitmap(width, height, PixelFormat.Format24bppRgb);
        using (var g = Graphics.FromImage(dest))
        {
            g.InterpolationMode = InterpolationMode.NearestNeighbor;
            g.PixelOffsetMode = PixelOffsetMode.Half;
            g.DrawImage(source, new Rectangle(0, 0, width, height), new Rectangle(0, 0, sourceW, sourceH), GraphicsUnit.Pixel);
        }
        var tmp = framePath + ".tmp.png";
        dest.Save(tmp, ImageFormat.Png);
        try
        {
            File.Move(tmp, framePath, true);
            File.SetLastWriteTimeUtc(framePath, DateTime.UtcNow);
        }
        catch
        {
            try
            {
                File.Copy(tmp, framePath, true);
                File.SetLastWriteTimeUtc(framePath, DateTime.UtcNow);
            }
            catch { }
        }
        finally
        {
            File.Delete(tmp);
        }
    }

    private static void SetProcessVolume(int pid, int percent)
    {
        try
        {
            var enumeratorType = Type.GetTypeFromCLSID(new Guid("BCDE0395-E52F-467C-8E3D-C4579291692E"));
            if (enumeratorType == null) return;
            var enumerator = (IMMDeviceEnumerator?)Activator.CreateInstance(enumeratorType);
            if (enumerator == null) return;
            if (enumerator.GetDefaultAudioEndpoint(EDataFlow.eRender, ERole.eMultimedia, out var device) != 0) return;
            var iid = typeof(IAudioSessionManager2).GUID;
            if (device.Activate(ref iid, CLSCTX_ALL, IntPtr.Zero, out var managerObject) != 0) return;
            var manager = (IAudioSessionManager2)managerObject;
            if (manager.GetSessionEnumerator(out var sessions) != 0) return;
            if (sessions.GetCount(out var count) != 0) return;
            var level = Math.Clamp(percent, 0, 100) / 100f;
            var context = Guid.Empty;
            for (var i = 0; i < count; i++)
            {
                if (sessions.GetSession(i, out var control) != 0 || control == null) continue;
                if (control is not IAudioSessionControl2 control2) continue;
                if (control2.GetProcessId(out var sessionPid) != 0 || sessionPid != pid) continue;
                if (control is ISimpleAudioVolume simple)
                {
                    simple.SetMute(false, ref context);
                    simple.SetMasterVolume(level, ref context);
                }
            }
        }
        catch { }
    }

    private enum EDataFlow
    {
        eRender,
        eCapture,
        eAll
    }

    private enum ERole
    {
        eConsole,
        eMultimedia,
        eCommunications
    }

    private enum AudioSessionState
    {
        AudioSessionStateInactive,
        AudioSessionStateActive,
        AudioSessionStateExpired
    }

    [ComImport]
    [Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    private sealed class MMDeviceEnumerator
    {
    }

    [ComImport]
    [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IMMDeviceEnumerator
    {
        [PreserveSig] int EnumAudioEndpoints(EDataFlow dataFlow, uint dwStateMask, out IntPtr ppDevices);
        [PreserveSig] int GetDefaultAudioEndpoint(EDataFlow dataFlow, ERole role, out IMMDevice ppEndpoint);
        [PreserveSig] int GetDevice([MarshalAs(UnmanagedType.LPWStr)] string pwstrId, out IMMDevice ppDevice);
        [PreserveSig] int RegisterEndpointNotificationCallback(IntPtr pClient);
        [PreserveSig] int UnregisterEndpointNotificationCallback(IntPtr pClient);
    }

    [ComImport]
    [Guid("D666063F-1587-4E43-81F1-B948E807363F")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IMMDevice
    {
        [PreserveSig] int Activate(ref Guid iid, uint dwClsCtx, IntPtr pActivationParams, [MarshalAs(UnmanagedType.IUnknown)] out object ppInterface);
        [PreserveSig] int OpenPropertyStore(uint stgmAccess, out IntPtr ppProperties);
        [PreserveSig] int GetId([MarshalAs(UnmanagedType.LPWStr)] out string ppstrId);
        [PreserveSig] int GetState(out uint pdwState);
    }

    [ComImport]
    [Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IAudioSessionManager2
    {
        [PreserveSig] int GetAudioSessionControl(ref Guid audioSessionGuid, uint streamFlags, out IAudioSessionControl sessionControl);
        [PreserveSig] int GetSimpleAudioVolume(ref Guid audioSessionGuid, uint streamFlags, out ISimpleAudioVolume audioVolume);
        [PreserveSig] int GetSessionEnumerator(out IAudioSessionEnumerator sessionEnum);
        [PreserveSig] int RegisterSessionNotification(IntPtr sessionNotification);
        [PreserveSig] int UnregisterSessionNotification(IntPtr sessionNotification);
        [PreserveSig] int RegisterDuckNotification([MarshalAs(UnmanagedType.LPWStr)] string sessionId, IntPtr duckNotification);
        [PreserveSig] int UnregisterDuckNotification(IntPtr duckNotification);
    }

    [ComImport]
    [Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IAudioSessionEnumerator
    {
        [PreserveSig] int GetCount(out int sessionCount);
        [PreserveSig] int GetSession(int sessionCount, out IAudioSessionControl session);
    }

    [ComImport]
    [Guid("F4B1A599-7266-4319-A8CA-E70ACB11E8CD")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IAudioSessionControl
    {
        [PreserveSig] int GetState(out AudioSessionState state);
        [PreserveSig] int GetDisplayName([MarshalAs(UnmanagedType.LPWStr)] out string displayName);
        [PreserveSig] int SetDisplayName([MarshalAs(UnmanagedType.LPWStr)] string displayName, ref Guid eventContext);
        [PreserveSig] int GetIconPath([MarshalAs(UnmanagedType.LPWStr)] out string iconPath);
        [PreserveSig] int SetIconPath([MarshalAs(UnmanagedType.LPWStr)] string iconPath, ref Guid eventContext);
        [PreserveSig] int GetGroupingParam(out Guid groupingParam);
        [PreserveSig] int SetGroupingParam(ref Guid groupingParam, ref Guid eventContext);
        [PreserveSig] int RegisterAudioSessionNotification(IntPtr newNotifications);
        [PreserveSig] int UnregisterAudioSessionNotification(IntPtr newNotifications);
    }

    [ComImport]
    [Guid("BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IAudioSessionControl2
    {
        [PreserveSig] int GetState(out AudioSessionState state);
        [PreserveSig] int GetDisplayName([MarshalAs(UnmanagedType.LPWStr)] out string displayName);
        [PreserveSig] int SetDisplayName([MarshalAs(UnmanagedType.LPWStr)] string displayName, ref Guid eventContext);
        [PreserveSig] int GetIconPath([MarshalAs(UnmanagedType.LPWStr)] out string iconPath);
        [PreserveSig] int SetIconPath([MarshalAs(UnmanagedType.LPWStr)] string iconPath, ref Guid eventContext);
        [PreserveSig] int GetGroupingParam(out Guid groupingParam);
        [PreserveSig] int SetGroupingParam(ref Guid groupingParam, ref Guid eventContext);
        [PreserveSig] int RegisterAudioSessionNotification(IntPtr newNotifications);
        [PreserveSig] int UnregisterAudioSessionNotification(IntPtr newNotifications);
        [PreserveSig] int GetSessionIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string retVal);
        [PreserveSig] int GetSessionInstanceIdentifier([MarshalAs(UnmanagedType.LPWStr)] out string retVal);
        [PreserveSig] int GetProcessId(out uint retVal);
        [PreserveSig] int IsSystemSoundsSession();
        [PreserveSig] int SetDuckingPreference(bool optOut);
    }

    [ComImport]
    [Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface ISimpleAudioVolume
    {
        [PreserveSig] int SetMasterVolume(float level, ref Guid eventContext);
        [PreserveSig] int GetMasterVolume(out float level);
        [PreserveSig] int SetMute(bool isMuted, ref Guid eventContext);
        [PreserveSig] int GetMute(out bool isMuted);
    }

    private static void WriteStatus(Options opt, string state, string detail)
    {
        var text = $"state={state}\n{detail}\nupdated={DateTimeOffset.Now:O}\n";
        File.WriteAllText(opt.Status, text);
    }
}
