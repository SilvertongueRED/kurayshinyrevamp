using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Text;

internal static class Program
{
    private const uint RETRO_DEVICE_JOYPAD = 1;
    private const uint RETRO_DEVICE_ID_JOYPAD_B = 0;
    private const uint RETRO_DEVICE_ID_JOYPAD_SELECT = 2;
    private const uint RETRO_DEVICE_ID_JOYPAD_START = 3;
    private const uint RETRO_DEVICE_ID_JOYPAD_UP = 4;
    private const uint RETRO_DEVICE_ID_JOYPAD_DOWN = 5;
    private const uint RETRO_DEVICE_ID_JOYPAD_LEFT = 6;
    private const uint RETRO_DEVICE_ID_JOYPAD_RIGHT = 7;
    private const uint RETRO_DEVICE_ID_JOYPAD_A = 8;
    private const uint RETRO_DEVICE_ID_JOYPAD_L = 10;
    private const uint RETRO_DEVICE_ID_JOYPAD_R = 11;
    private const uint RETRO_DEVICE_ID_JOYPAD_MASK = 256;

    private const uint RETRO_ENVIRONMENT_GET_CAN_DUPE = 3;
    private const uint RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY = 9;
    private const uint RETRO_ENVIRONMENT_SET_PIXEL_FORMAT = 10;
    private const uint RETRO_ENVIRONMENT_GET_VARIABLE = 15;
    private const uint RETRO_ENVIRONMENT_SET_VARIABLES = 16;
    private const uint RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE = 17;
    private const uint RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME = 18;
    private const uint RETRO_ENVIRONMENT_SET_FRAME_TIME_CALLBACK = 21;
    private const uint RETRO_ENVIRONMENT_SET_AUDIO_CALLBACK = 22;
    private const uint RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY = 31;
    private const uint RETRO_ENVIRONMENT_SET_CONTROLLER_INFO = 35;
    private const uint RETRO_ENVIRONMENT_SET_GEOMETRY = 37;
    private const uint RETRO_ENVIRONMENT_GET_INPUT_BITMASKS = 0x10000 | 51;
    private const uint RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION = 52;
    private const uint RETRO_ENVIRONMENT_SET_CORE_OPTIONS = 53;
    private const uint RETRO_ENVIRONMENT_SET_CORE_OPTIONS_INTL = 54;
    private const uint RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2 = 67;
    private const uint RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2_INTL = 68;
    private const uint RETRO_ENVIRONMENT_SET_VARIABLE = 70;

    private const int RETRO_PIXEL_FORMAT_0RGB1555 = 0;
    private const int RETRO_PIXEL_FORMAT_XRGB8888 = 1;
    private const int RETRO_PIXEL_FORMAT_RGB565 = 2;
    private const uint RETRO_MEMORY_SAVE_RAM = 0;

    public static int Main(string[] args)
    {
        var opt = Options.Parse(args);
        try
        {
            opt.Ensure();
            File.WriteAllText(opt.Command, "");
            WriteStatus(opt, "starting", "mode=core\nbackend=libretro");
            using var host = new LibretroHost(opt);
            host.Run();
            WriteStatus(opt, "stopped", "mode=core\nbackend=libretro");
            return 0;
        }
        catch (Exception ex)
        {
            WriteStatus(opt, "error", $"mode=core\nbackend=libretro\nmessage={SanitizeStatus(ex.Message)}\nexception={SanitizeStatus(ex.ToString())}");
            return 1;
        }
    }

    private sealed class Options
    {
        public string Core = "";
        public string Rom = "";
        public string Frame = "";
        public string Command = "";
        public string Status = "";
        public string SaveDir = "";
        public string SystemDir = "";
        public int Fps = 30;
        public int VolumePercent = 25;
        public int AudioBufferMs = 240;

        public static Options Parse(string[] args)
        {
            var opt = new Options();
            for (var i = 0; i < args.Length; i++)
            {
                string value() => i + 1 < args.Length ? args[++i] : "";
                switch (args[i])
                {
                    case "--core": opt.Core = value(); break;
                    case "--rom": opt.Rom = value(); break;
                    case "--frame": opt.Frame = value(); break;
                    case "--command": opt.Command = value(); break;
                    case "--status": opt.Status = value(); break;
                    case "--save-dir": opt.SaveDir = value(); break;
                    case "--system-dir": opt.SystemDir = value(); break;
                    case "--fps": int.TryParse(value(), out opt.Fps); break;
                    case "--volume-percent": int.TryParse(value(), out opt.VolumePercent); break;
                    case "--audio-buffer-ms": int.TryParse(value(), out opt.AudioBufferMs); break;
                }
            }
            opt.Fps = Math.Clamp(opt.Fps, 10, 60);
            opt.VolumePercent = Math.Clamp(opt.VolumePercent, 0, 100);
            opt.AudioBufferMs = Math.Clamp(opt.AudioBufferMs, 60, 600);
            return opt;
        }

        public void Ensure()
        {
            if (string.IsNullOrWhiteSpace(Core) || !File.Exists(Core)) throw new FileNotFoundException("Libretro core not found", Core);
            if (string.IsNullOrWhiteSpace(Rom) || !File.Exists(Rom)) throw new FileNotFoundException("ROM not found", Rom);
            if (string.IsNullOrWhiteSpace(Frame)) throw new ArgumentException("--frame is required");
            if (string.IsNullOrWhiteSpace(Command)) throw new ArgumentException("--command is required");
            if (string.IsNullOrWhiteSpace(Status)) throw new ArgumentException("--status is required");
            if (string.IsNullOrWhiteSpace(SaveDir)) SaveDir = Path.Combine(Path.GetDirectoryName(Rom) ?? ".", "Saves");
            if (string.IsNullOrWhiteSpace(SystemDir)) SystemDir = Path.Combine(Path.GetDirectoryName(Core) ?? ".", "system");
            Directory.CreateDirectory(Path.GetDirectoryName(Frame) ?? ".");
            Directory.CreateDirectory(Path.GetDirectoryName(Command) ?? ".");
            Directory.CreateDirectory(Path.GetDirectoryName(Status) ?? ".");
            Directory.CreateDirectory(SaveDir);
            Directory.CreateDirectory(SystemDir);
        }
    }

    private sealed class LibretroHost : IDisposable
    {
        private readonly Options _opt;
        private readonly IntPtr _library;
        private readonly WaveOutDevice _audio = new();
        private readonly bool[] _held = new bool[16];
        private readonly int[] _tapFrames = new int[16];
        private readonly Dictionary<string, uint> _buttonMap = new(StringComparer.OrdinalIgnoreCase)
        {
            ["A"] = RETRO_DEVICE_ID_JOYPAD_A,
            ["B"] = RETRO_DEVICE_ID_JOYPAD_B,
            ["L"] = RETRO_DEVICE_ID_JOYPAD_L,
            ["R"] = RETRO_DEVICE_ID_JOYPAD_R,
            ["START"] = RETRO_DEVICE_ID_JOYPAD_START,
            ["SELECT"] = RETRO_DEVICE_ID_JOYPAD_SELECT,
            ["UP"] = RETRO_DEVICE_ID_JOYPAD_UP,
            ["DOWN"] = RETRO_DEVICE_ID_JOYPAD_DOWN,
            ["LEFT"] = RETRO_DEVICE_ID_JOYPAD_LEFT,
            ["RIGHT"] = RETRO_DEVICE_ID_JOYPAD_RIGHT
        };

        private readonly RetroEnvironment _environment;
        private readonly RetroVideoRefresh _videoRefresh;
        private readonly RetroAudioSample _audioSample;
        private readonly RetroAudioSampleBatch _audioSampleBatch;
        private readonly RetroInputPoll _inputPoll;
        private readonly RetroInputState _inputState;

        private readonly RetroSetEnvironment _retroSetEnvironment;
        private readonly RetroSetVideoRefresh _retroSetVideoRefresh;
        private readonly RetroSetAudioSample _retroSetAudioSample;
        private readonly RetroSetAudioSampleBatch _retroSetAudioSampleBatch;
        private readonly RetroSetInputPoll _retroSetInputPoll;
        private readonly RetroSetInputState _retroSetInputState;
        private readonly RetroInit _retroInit;
        private readonly RetroDeinit _retroDeinit;
        private readonly RetroGetSystemInfo _retroGetSystemInfo;
        private readonly RetroGetSystemAvInfo _retroGetSystemAvInfo;
        private readonly RetroLoadGame _retroLoadGame;
        private readonly RetroUnloadGame _retroUnloadGame;
        private readonly RetroRun _retroRun;
        private readonly RetroGetMemoryData _retroGetMemoryData;
        private readonly RetroGetMemorySize _retroGetMemorySize;

        private IntPtr _systemDirPtr;
        private IntPtr _saveDirPtr;
        private IntPtr _romPathPtr;
        private IntPtr _romDataPtr;
        private UIntPtr _romDataSize;
        private bool _loaded;
        private bool _paused;
        private long _commandOffset;
        private int _pixelFormat = RETRO_PIXEL_FORMAT_0RGB1555;
        private double _coreFps = 59.7275;
        private double _sampleRate = 44100.0;
        private long _nextFrameWriteTicks;
        private long _lastSaveTicks;
        private int _frameCount;
        private int _lastWidth;
        private int _lastHeight;
        private string _savePath = "";
        private string _lastFramePath = "";
        private int _frameSlot;

        public LibretroHost(Options opt)
        {
            _opt = opt;
            _library = NativeLibrary.Load(opt.Core);
            _environment = EnvironmentCallback;
            _videoRefresh = VideoRefresh;
            _audioSample = AudioSample;
            _audioSampleBatch = AudioSampleBatch;
            _inputPoll = InputPoll;
            _inputState = InputState;

            _retroSetEnvironment = Export<RetroSetEnvironment>("retro_set_environment");
            _retroSetVideoRefresh = Export<RetroSetVideoRefresh>("retro_set_video_refresh");
            _retroSetAudioSample = Export<RetroSetAudioSample>("retro_set_audio_sample");
            _retroSetAudioSampleBatch = Export<RetroSetAudioSampleBatch>("retro_set_audio_sample_batch");
            _retroSetInputPoll = Export<RetroSetInputPoll>("retro_set_input_poll");
            _retroSetInputState = Export<RetroSetInputState>("retro_set_input_state");
            _retroInit = Export<RetroInit>("retro_init");
            _retroDeinit = Export<RetroDeinit>("retro_deinit");
            _retroGetSystemInfo = Export<RetroGetSystemInfo>("retro_get_system_info");
            _retroGetSystemAvInfo = Export<RetroGetSystemAvInfo>("retro_get_system_av_info");
            _retroLoadGame = Export<RetroLoadGame>("retro_load_game");
            _retroUnloadGame = Export<RetroUnloadGame>("retro_unload_game");
            _retroRun = Export<RetroRun>("retro_run");
            _retroGetMemoryData = Export<RetroGetMemoryData>("retro_get_memory_data");
            _retroGetMemorySize = Export<RetroGetMemorySize>("retro_get_memory_size");
        }

        public void Run()
        {
            _systemDirPtr = Utf8(Path.GetFullPath(_opt.SystemDir).Replace('\\', '/'));
            _saveDirPtr = Utf8(Path.GetFullPath(_opt.SaveDir).Replace('\\', '/'));
            _romPathPtr = Utf8(Path.GetFullPath(_opt.Rom).Replace('\\', '/'));

            _retroSetEnvironment(_environment);
            _retroSetVideoRefresh(_videoRefresh);
            _retroSetAudioSample(_audioSample);
            _retroSetAudioSampleBatch(_audioSampleBatch);
            _retroSetInputPoll(_inputPoll);
            _retroSetInputState(_inputState);
            _retroInit();

            var info = new RetroSystemInfo();
            _retroGetSystemInfo(ref info);
            var libraryName = PtrToUtf8(info.LibraryName);
            var libraryVersion = PtrToUtf8(info.LibraryVersion);
            PrepareRomData(info.NeedFullpath != 0);

            var game = new RetroGameInfo
            {
                Path = _romPathPtr,
                Data = _romDataPtr,
                Size = _romDataSize,
                Meta = IntPtr.Zero
            };
            if (!_retroLoadGame(ref game)) throw new InvalidOperationException("The libretro core rejected this ROM.");
            _loaded = true;

            var av = new RetroSystemAvInfo();
            _retroGetSystemAvInfo(ref av);
            _coreFps = av.Timing.Fps > 1.0 ? av.Timing.Fps : _coreFps;
            _sampleRate = av.Timing.SampleRate > 1.0 ? av.Timing.SampleRate : _sampleRate;
            _audio.Open((int)Math.Round(_sampleRate), _opt.VolumePercent, _opt.AudioBufferMs);

            _savePath = SavePathFor(_opt.Rom, _opt.SaveDir);
            LoadSaveRam();

            WriteStatus(_opt, "ready",
                $"mode=core\nbackend=libretro\ncore={SanitizeStatus(libraryName)} {SanitizeStatus(libraryVersion)}\npaused=0\nvolume={_opt.VolumePercent}\nframe=0");

            var clock = Stopwatch.StartNew();
            var frameTicks = Stopwatch.Frequency / _coreFps;
            var statusEvery = Math.Max(1, (int)Math.Round(_coreFps));
            while (true)
            {
                var start = Stopwatch.GetTimestamp();
                if (ProcessCommands()) break;
                if (_paused)
                {
                    Thread.Sleep(15);
                    continue;
                }

                _retroRun();
                _frameCount++;
                DecayTapFrames();
                if (_frameCount % statusEvery == 0)
                {
                    WriteStatus(_opt, "ready", ReadyStatus(paused: false));
                }
                if (clock.ElapsedMilliseconds - TicksToMs(_lastSaveTicks) > 2000)
                {
                    SaveRam();
                    _lastSaveTicks = MsToTicks(clock.ElapsedMilliseconds);
                }

                var elapsed = Stopwatch.GetTimestamp() - start;
                var remainingMs = ((frameTicks - elapsed) * 1000.0) / Stopwatch.Frequency;
                if (remainingMs > 1) Thread.Sleep((int)remainingMs);
            }
        }

        public void Dispose()
        {
            SaveRam();
            if (_loaded)
            {
                try { _retroUnloadGame(); } catch { }
            }
            try { _retroDeinit(); } catch { }
            _audio.Dispose();
            Free(_systemDirPtr);
            Free(_saveDirPtr);
            Free(_romPathPtr);
            Free(_romDataPtr);
            if (_library != IntPtr.Zero) NativeLibrary.Free(_library);
        }

        private T Export<T>(string name) where T : Delegate
        {
            return Marshal.GetDelegateForFunctionPointer<T>(NativeLibrary.GetExport(_library, name));
        }

        private bool EnvironmentCallback(uint command, IntPtr data)
        {
            switch (command)
            {
                case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
                    Marshal.WriteIntPtr(data, _systemDirPtr);
                    return true;
                case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
                    Marshal.WriteIntPtr(data, _saveDirPtr);
                    return true;
                case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:
                    var requested = Marshal.ReadInt32(data);
                    if (requested == RETRO_PIXEL_FORMAT_XRGB8888 || requested == RETRO_PIXEL_FORMAT_RGB565 || requested == RETRO_PIXEL_FORMAT_0RGB1555)
                    {
                        _pixelFormat = requested;
                        return true;
                    }
                    return false;
                case RETRO_ENVIRONMENT_GET_CAN_DUPE:
                case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:
                    Marshal.WriteByte(data, 0);
                    return true;
                case RETRO_ENVIRONMENT_GET_INPUT_BITMASKS:
                    return true;
                case RETRO_ENVIRONMENT_SET_VARIABLES:
                case RETRO_ENVIRONMENT_SET_VARIABLE:
                case RETRO_ENVIRONMENT_SET_CORE_OPTIONS:
                case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_INTL:
                case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2:
                case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2_INTL:
                case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME:
                case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO:
                case RETRO_ENVIRONMENT_SET_FRAME_TIME_CALLBACK:
                case RETRO_ENVIRONMENT_SET_AUDIO_CALLBACK:
                    return true;
                case RETRO_ENVIRONMENT_SET_GEOMETRY:
                    return true;
                case RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION:
                    Marshal.WriteInt32(data, 2);
                    return true;
                case RETRO_ENVIRONMENT_GET_VARIABLE:
                    if (data != IntPtr.Zero) Marshal.WriteIntPtr(data, IntPtr.Size, IntPtr.Zero);
                    return false;
                default:
                    return false;
            }
        }

        private void VideoRefresh(IntPtr data, uint width, uint height, UIntPtr pitch)
        {
            if (data == IntPtr.Zero || width == 0 || height == 0) return;
            var now = Stopwatch.GetTimestamp();
            var minTicks = Stopwatch.Frequency / Math.Max(1, _opt.Fps);
            if (now < _nextFrameWriteTicks) return;
            _nextFrameWriteTicks = now + minTicks;
            _lastWidth = (int)width;
            _lastHeight = (int)height;
            SaveFrame(data, (int)width, (int)height, checked((int)pitch));
        }

        private void AudioSample(short left, short right)
        {
            Span<byte> bytes = stackalloc byte[4];
            BitConverter.TryWriteBytes(bytes[..2], left);
            BitConverter.TryWriteBytes(bytes[2..], right);
            _audio.Queue(bytes);
        }

        private UIntPtr AudioSampleBatch(IntPtr data, UIntPtr frames)
        {
            var count = checked((int)frames);
            if (count > 0) _audio.Queue(data, count * 4);
            return frames;
        }

        private void InputPoll()
        {
        }

        private short InputState(uint port, uint device, uint index, uint id)
        {
            if (port != 0 || device != RETRO_DEVICE_JOYPAD) return 0;
            if (id == RETRO_DEVICE_ID_JOYPAD_MASK)
            {
                var mask = 0;
                for (var i = 0; i < _held.Length; i++)
                {
                    if (_held[i] || _tapFrames[i] > 0) mask |= 1 << i;
                }
                return (short)mask;
            }
            if (id >= _held.Length) return 0;
            return (short)((_held[id] || _tapFrames[id] > 0) ? 1 : 0);
        }

        private bool ProcessCommands()
        {
            if (!File.Exists(_opt.Command)) return false;
            using var fs = new FileStream(_opt.Command, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
            if (_commandOffset > fs.Length) _commandOffset = 0;
            fs.Seek(_commandOffset, SeekOrigin.Begin);
            using var reader = new StreamReader(fs, Encoding.UTF8, false, 1024, leaveOpen: true);
            string? line;
            while ((line = reader.ReadLine()) != null)
            {
                HandleCommand(line.Trim());
            }
            _commandOffset = fs.Position;
            return _quitRequested;
        }

        private bool _quitRequested;

        private void HandleCommand(string line)
        {
            if (string.IsNullOrWhiteSpace(line)) return;
            var parts = line.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            var op = parts[0].ToLowerInvariant();
            if (op == "quit")
            {
                _quitRequested = true;
                return;
            }
            if (op == "pause")
            {
                _paused = true;
                _audio.Reset();
                WriteStatus(_opt, "ready", ReadyStatus(paused: true));
                return;
            }
            if (op == "resume")
            {
                _paused = false;
                WriteStatus(_opt, "ready", ReadyStatus(paused: false));
                return;
            }
            if (op == "volume" && parts.Length >= 2 && int.TryParse(parts[1], out var volume))
            {
                _opt.VolumePercent = Math.Clamp(volume, 0, 100);
                _audio.SetVolume(_opt.VolumePercent);
                return;
            }
            if (parts.Length < 2 || !_buttonMap.TryGetValue(parts[1], out var button) || button >= _held.Length) return;
            switch (op)
            {
                case "tap":
                    _tapFrames[button] = Math.Max(_tapFrames[button], 5);
                    break;
                case "hold":
                    var ms = 90;
                    if (parts.Length >= 3) int.TryParse(parts[2], out ms);
                    _tapFrames[button] = Math.Max(_tapFrames[button], Math.Clamp((int)Math.Round(_coreFps * Math.Clamp(ms, 35, 600) / 1000.0), 2, 40));
                    break;
                case "down":
                    _held[button] = true;
                    break;
                case "up":
                    _held[button] = false;
                    break;
            }
        }

        private void DecayTapFrames()
        {
            for (var i = 0; i < _tapFrames.Length; i++)
            {
                if (_tapFrames[i] > 0) _tapFrames[i]--;
            }
        }

        private void PrepareRomData(bool needFullPath)
        {
            if (needFullPath) return;
            var bytes = File.ReadAllBytes(_opt.Rom);
            _romDataPtr = Marshal.AllocHGlobal(bytes.Length);
            Marshal.Copy(bytes, 0, _romDataPtr, bytes.Length);
            _romDataSize = (UIntPtr)bytes.Length;
        }

        private void LoadSaveRam()
        {
            var ptr = _retroGetMemoryData(RETRO_MEMORY_SAVE_RAM);
            var size = checked((int)_retroGetMemorySize(RETRO_MEMORY_SAVE_RAM));
            if (ptr == IntPtr.Zero || size <= 0 || !File.Exists(_savePath)) return;
            var bytes = File.ReadAllBytes(_savePath);
            Marshal.Copy(bytes, 0, ptr, Math.Min(bytes.Length, size));
        }

        private void SaveRam()
        {
            if (!_loaded || string.IsNullOrWhiteSpace(_savePath)) return;
            var ptr = _retroGetMemoryData(RETRO_MEMORY_SAVE_RAM);
            var size = checked((int)_retroGetMemorySize(RETRO_MEMORY_SAVE_RAM));
            if (ptr == IntPtr.Zero || size <= 0) return;
            var bytes = new byte[size];
            Marshal.Copy(ptr, bytes, 0, size);
            var tmp = _savePath + ".tmp";
            File.WriteAllBytes(tmp, bytes);
            TryPublishFile(tmp, _savePath);
        }

        private void SaveFrame(IntPtr source, int width, int height, int pitch)
        {
            using var bitmap = new Bitmap(width, height, System.Drawing.Imaging.PixelFormat.Format32bppRgb);
            var rect = new Rectangle(0, 0, width, height);
            var data = bitmap.LockBits(rect, ImageLockMode.WriteOnly, System.Drawing.Imaging.PixelFormat.Format32bppRgb);
            try
            {
                if (_pixelFormat == RETRO_PIXEL_FORMAT_XRGB8888)
                {
                    CopyRows(source, pitch, data.Scan0, data.Stride, width * 4, height);
                }
                else
                {
                    Convert16BitFrame(source, pitch, data.Scan0, data.Stride, width, height, _pixelFormat == RETRO_PIXEL_FORMAT_RGB565);
                }
            }
            finally
            {
                bitmap.UnlockBits(data);
            }
            var target = NextFramePath();
            var tmp = target + ".tmp";
            bitmap.Save(tmp, ImageFormat.Png);
            if (TryPublishFile(tmp, target))
            {
                _lastFramePath = target;
                WriteStatus(_opt, "ready", ReadyStatus(paused: _paused));
            }
        }

        private string NextFramePath()
        {
            _frameSlot = (_frameSlot + 1) % 4;
            var dir = Path.GetDirectoryName(_opt.Frame) ?? ".";
            var name = Path.GetFileNameWithoutExtension(_opt.Frame);
            return Path.Combine(dir, $"{name}.{_frameSlot}.png");
        }

        private string ReadyStatus(bool paused)
        {
            var framePath = string.IsNullOrWhiteSpace(_lastFramePath) ? _opt.Frame : _lastFramePath;
            return $"mode=core\nbackend=libretro\npaused={(paused ? 1 : 0)}\nvolume={_opt.VolumePercent}\nframe={_frameCount}\nwidth={_lastWidth}\nheight={_lastHeight}\nframe_path={framePath}";
        }
    }

    private sealed class WaveOutDevice : IDisposable
    {
        private const int WAVE_FORMAT_PCM = 1;
        private const int WAVE_MAPPER = -1;
        private const int WHDR_DONE = 0x00000001;
        private readonly List<BufferHandle> _buffers = new();
        private IntPtr _handle;
        private int _queuedBytes;
        private int _maxQueuedBytes = 44100;

        public void Open(int sampleRate, int volumePercent, int bufferMs)
        {
            var fmt = new WaveFormatEx
            {
                FormatTag = WAVE_FORMAT_PCM,
                Channels = 2,
                SamplesPerSec = (uint)Math.Clamp(sampleRate, 8000, 192000),
                BitsPerSample = 16,
                BlockAlign = 4,
                CbSize = 0
            };
            fmt.AvgBytesPerSec = fmt.SamplesPerSec * fmt.BlockAlign;
            _maxQueuedBytes = Math.Max(8192, (int)(fmt.AvgBytesPerSec * Math.Clamp(bufferMs, 60, 600) / 1000));
            if (waveOutOpen(out _handle, WAVE_MAPPER, ref fmt, IntPtr.Zero, IntPtr.Zero, 0) != 0)
            {
                _handle = IntPtr.Zero;
                return;
            }
            SetVolume(volumePercent);
        }

        public void Queue(ReadOnlySpan<byte> bytes)
        {
            if (_handle == IntPtr.Zero || bytes.IsEmpty) return;
            Cleanup();
            if (_queuedBytes > _maxQueuedBytes) return;
            var data = Marshal.AllocHGlobal(bytes.Length);
            Marshal.Copy(bytes.ToArray(), 0, data, bytes.Length);
            QueueAllocated(data, bytes.Length);
        }

        public void Queue(IntPtr source, int bytes)
        {
            if (_handle == IntPtr.Zero || source == IntPtr.Zero || bytes <= 0) return;
            Cleanup();
            if (_queuedBytes > _maxQueuedBytes) return;
            var data = Marshal.AllocHGlobal(bytes);
            CopyMemory(data, source, (UIntPtr)bytes);
            QueueAllocated(data, bytes);
        }

        public void SetVolume(int percent)
        {
            if (_handle == IntPtr.Zero) return;
            var value = (uint)(Math.Clamp(percent, 0, 100) * 0xFFFF / 100);
            waveOutSetVolume(_handle, value | (value << 16));
        }

        public void Reset()
        {
            if (_handle == IntPtr.Zero) return;
            waveOutReset(_handle);
            Cleanup(force: true);
        }

        public void Dispose()
        {
            if (_handle == IntPtr.Zero) return;
            waveOutReset(_handle);
            Cleanup(force: true);
            waveOutClose(_handle);
            _handle = IntPtr.Zero;
        }

        private void QueueAllocated(IntPtr data, int bytes)
        {
            var header = new WaveHeader
            {
                Data = data,
                BufferLength = (uint)bytes
            };
            var headerPtr = Marshal.AllocHGlobal(Marshal.SizeOf<WaveHeader>());
            Marshal.StructureToPtr(header, headerPtr, false);
            if (waveOutPrepareHeader(_handle, headerPtr, Marshal.SizeOf<WaveHeader>()) != 0 ||
                waveOutWrite(_handle, headerPtr, Marshal.SizeOf<WaveHeader>()) != 0)
            {
                Marshal.FreeHGlobal(data);
                Marshal.FreeHGlobal(headerPtr);
                return;
            }
            _buffers.Add(new BufferHandle(headerPtr, data, bytes));
            _queuedBytes += bytes;
        }

        private void Cleanup(bool force = false)
        {
            for (var i = _buffers.Count - 1; i >= 0; i--)
            {
                var handle = _buffers[i];
                var header = Marshal.PtrToStructure<WaveHeader>(handle.Header);
                if (!force && (header.Flags & WHDR_DONE) == 0) continue;
                waveOutUnprepareHeader(_handle, handle.Header, Marshal.SizeOf<WaveHeader>());
                Marshal.FreeHGlobal(handle.Data);
                Marshal.FreeHGlobal(handle.Header);
                _queuedBytes -= handle.Length;
                _buffers.RemoveAt(i);
            }
        }

        private readonly record struct BufferHandle(IntPtr Header, IntPtr Data, int Length);

        [StructLayout(LayoutKind.Sequential)]
        private struct WaveFormatEx
        {
            public ushort FormatTag;
            public ushort Channels;
            public uint SamplesPerSec;
            public uint AvgBytesPerSec;
            public ushort BlockAlign;
            public ushort BitsPerSample;
            public ushort CbSize;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct WaveHeader
        {
            public IntPtr Data;
            public uint BufferLength;
            public uint BytesRecorded;
            public IntPtr User;
            public uint Flags;
            public uint Loops;
            public IntPtr Next;
            public IntPtr Reserved;
        }

        [DllImport("winmm.dll")]
        private static extern int waveOutOpen(out IntPtr hwo, int uDeviceID, ref WaveFormatEx pwfx, IntPtr dwCallback, IntPtr dwInstance, int fdwOpen);

        [DllImport("winmm.dll")]
        private static extern int waveOutPrepareHeader(IntPtr hwo, IntPtr pwh, int cbwh);

        [DllImport("winmm.dll")]
        private static extern int waveOutWrite(IntPtr hwo, IntPtr pwh, int cbwh);

        [DllImport("winmm.dll")]
        private static extern int waveOutUnprepareHeader(IntPtr hwo, IntPtr pwh, int cbwh);

        [DllImport("winmm.dll")]
        private static extern int waveOutReset(IntPtr hwo);

        [DllImport("winmm.dll")]
        private static extern int waveOutClose(IntPtr hwo);

        [DllImport("winmm.dll")]
        private static extern int waveOutSetVolume(IntPtr hwo, uint dwVolume);
    }

    private static string SavePathFor(string rom, string saveDir)
    {
        var name = Path.GetFileNameWithoutExtension(rom);
        return Path.Combine(saveDir, name + ".srm");
    }

    private static void WriteStatus(Options opt, string state, string details)
    {
        if (string.IsNullOrWhiteSpace(opt.Status)) return;
        var text = $"state={state}\n{details}\n";
        var tmp = $"{opt.Status}.{Environment.ProcessId}.tmp";
        File.WriteAllText(tmp, text);
        TryPublishFile(tmp, opt.Status);
    }

    private static string SanitizeStatus(string text)
    {
        return text.Replace("\r", " ").Replace("\n", " ").Trim();
    }

    private static void CopyRows(IntPtr source, int sourceStride, IntPtr dest, int destStride, int rowBytes, int rows)
    {
        for (var y = 0; y < rows; y++)
        {
            CopyMemory(IntPtr.Add(dest, y * destStride), IntPtr.Add(source, y * sourceStride), (UIntPtr)rowBytes);
        }
    }

    private static void Convert16BitFrame(IntPtr source, int sourceStride, IntPtr dest, int destStride, int width, int height, bool rgb565)
    {
        var input = new byte[sourceStride * height];
        Marshal.Copy(source, input, 0, input.Length);
        var output = new byte[destStride * height];
        for (var y = 0; y < height; y++)
        {
            var inRow = y * sourceStride;
            var outRow = y * destStride;
            for (var x = 0; x < width; x++)
            {
                var value = input[inRow + x * 2] | (input[inRow + x * 2 + 1] << 8);
                int r;
                int g;
                int b;
                if (rgb565)
                {
                    r = (value >> 11) & 0x1F;
                    g = (value >> 5) & 0x3F;
                    b = value & 0x1F;
                    r = (r << 3) | (r >> 2);
                    g = (g << 2) | (g >> 4);
                    b = (b << 3) | (b >> 2);
                }
                else
                {
                    r = (value >> 10) & 0x1F;
                    g = (value >> 5) & 0x1F;
                    b = value & 0x1F;
                    r = (r << 3) | (r >> 2);
                    g = (g << 3) | (g >> 2);
                    b = (b << 3) | (b >> 2);
                }
                var offset = outRow + x * 4;
                output[offset] = (byte)b;
                output[offset + 1] = (byte)g;
                output[offset + 2] = (byte)r;
                output[offset + 3] = 0;
            }
        }
        Marshal.Copy(output, 0, dest, output.Length);
    }

    private static IntPtr Utf8(string text)
    {
        var bytes = Encoding.UTF8.GetBytes(text + "\0");
        var ptr = Marshal.AllocHGlobal(bytes.Length);
        Marshal.Copy(bytes, 0, ptr, bytes.Length);
        return ptr;
    }

    private static string PtrToUtf8(IntPtr ptr)
    {
        if (ptr == IntPtr.Zero) return "";
        var bytes = new List<byte>();
        var offset = 0;
        while (true)
        {
            var b = Marshal.ReadByte(ptr, offset++);
            if (b == 0) break;
            bytes.Add(b);
        }
        return Encoding.UTF8.GetString(bytes.ToArray());
    }

    private static void Free(IntPtr ptr)
    {
        if (ptr != IntPtr.Zero) Marshal.FreeHGlobal(ptr);
    }

    private static bool TryPublishFile(string tmp, string target)
    {
        try
        {
            File.Move(tmp, target, true);
            File.SetLastWriteTimeUtc(target, DateTime.UtcNow);
            return true;
        }
        catch
        {
            try
            {
                File.Copy(tmp, target, true);
                File.SetLastWriteTimeUtc(target, DateTime.UtcNow);
                return true;
            }
            catch
            {
                return false;
            }
            finally
            {
                try { File.Delete(tmp); } catch { }
            }
        }
        finally
        {
            try { if (File.Exists(tmp)) File.Delete(tmp); } catch { }
        }
    }

    private static long MsToTicks(long ms) => ms;
    private static long TicksToMs(long ticks) => ticks;

    [DllImport("kernel32.dll", EntryPoint = "RtlMoveMemory")]
    private static extern void CopyMemory(IntPtr dest, IntPtr src, UIntPtr count);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate bool RetroEnvironment(uint command, IntPtr data);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate void RetroVideoRefresh(IntPtr data, uint width, uint height, UIntPtr pitch);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate void RetroAudioSample(short left, short right);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate UIntPtr RetroAudioSampleBatch(IntPtr data, UIntPtr frames);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate void RetroInputPoll();

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate short RetroInputState(uint port, uint device, uint index, uint id);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate void RetroSetEnvironment(RetroEnvironment cb);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate void RetroSetVideoRefresh(RetroVideoRefresh cb);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate void RetroSetAudioSample(RetroAudioSample cb);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate void RetroSetAudioSampleBatch(RetroAudioSampleBatch cb);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate void RetroSetInputPoll(RetroInputPoll cb);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate void RetroSetInputState(RetroInputState cb);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate void RetroInit();

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate void RetroDeinit();

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate void RetroGetSystemInfo(ref RetroSystemInfo info);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate void RetroGetSystemAvInfo(ref RetroSystemAvInfo info);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate bool RetroLoadGame(ref RetroGameInfo game);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate void RetroUnloadGame();

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate void RetroRun();

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate IntPtr RetroGetMemoryData(uint id);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate UIntPtr RetroGetMemorySize(uint id);

    [StructLayout(LayoutKind.Sequential)]
    private struct RetroSystemInfo
    {
        public IntPtr LibraryName;
        public IntPtr LibraryVersion;
        public IntPtr ValidExtensions;
        public byte NeedFullpath;
        public byte BlockExtract;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct RetroGameInfo
    {
        public IntPtr Path;
        public IntPtr Data;
        public UIntPtr Size;
        public IntPtr Meta;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct RetroGameGeometry
    {
        public uint BaseWidth;
        public uint BaseHeight;
        public uint MaxWidth;
        public uint MaxHeight;
        public float AspectRatio;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct RetroSystemTiming
    {
        public double Fps;
        public double SampleRate;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct RetroSystemAvInfo
    {
        public RetroGameGeometry Geometry;
        public RetroSystemTiming Timing;
    }
}
