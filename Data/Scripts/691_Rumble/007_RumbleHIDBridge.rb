#===============================================================================
# Controller Vibration / Rumble  -  DIRECT RAW-HID BRIDGE (no Steam Input, no recompile)
#-------------------------------------------------------------------------------
# The XInput backend (001) only sees XInput devices: Xbox pads, or a DualSense /
# DS4 that has been WRAPPED into a virtual Xbox pad by Steam Input or DS4Windows.
# A DualSense plugged in directly (USB or Bluetooth) with Steam Input OFF is NOT
# an XInput device, so:
#   * XInputGetState() reports "not connected" on every slot  -> the old code said
#     "No controller detected" even though the engine's SDL layer drives the pad
#     fine in-game;
#   * and there was no way to actually rumble it.
#
# This layer talks to the DualSense / DualShock 4 over RAW HID using Win32 through
# Ruby's Fiddle (real 64-bit FFI, so device HANDLEs survive - unlike the engine's
# 32-bit-oriented Win32API shim). It:
#   * enumerates HID devices, finds a Sony pad by VID/PID,
#   * reports the REAL kind (:dualsense / :dualshock4) for the Test readout,
#   * drives the two motors by writing the controller's native output report
#     (DualSense USB id 0x02 / Bluetooth id 0x31 + CRC-32; DS4 USB id 0x05).
#
# Priority once loaded:  native Steam Input (006) > direct raw-HID (here) > XInput.
# Everything is wrapped: if Fiddle is missing, no Sony pad is present, or the OS
# refuses the handle (e.g. Steam Input has the device hidden/locked), this layer
# is INERT and the XInput backend is used exactly as before. Non-Windows -> inert.
#===============================================================================
#-------------------------------------------------------------------------------
# Fiddle Windows last-error shim (mkxp-z embedded Ruby).
# Fiddle::Function#call fires, immediately AFTER every native call, a small set
# of module hooks to record the OS error: last_error= and, on Windows,
# win32_last_error= AND win32_last_socket_error=. This embedded Ruby's Fiddle
# C-extension defines NONE of them, so every Fiddle call raised e.g.
#   NoMethodError: undefined method `win32_last_socket_error=' for Fiddle:Module
# which (being rescued) made SteamAPI_Init, the ISteamInput calls, IsSteamRunning
# AND the whole raw-HID bridge silently "fail" though the DLLs loaded fine.
# Define thread-local accessors for the three known hooks PLUS a narrow
# method_missing net so no future *_error hook can ever raise here again.
begin
  require 'fiddle'
  module Fiddle
    {
      :last_error              => :__kif_fiddle_err,
      :win32_last_error        => :__kif_fiddle_w32err,
      :win32_last_socket_error => :__kif_fiddle_sockerr,
    }.each do |getter, slot|
      define_singleton_method(getter) { Thread.current[slot] || 0 } unless respond_to?(getter)
      setter = :"#{getter}="
      define_singleton_method(setter) { |v| Thread.current[slot] = v } unless respond_to?(setter)
    end
    unless respond_to?(:__kif_fiddle_err_net)
      def self.__kif_fiddle_err_net; true; end
      def self.method_missing(name, *args)
        s = name.to_s
        if s.end_with?("error") || s.end_with?("error=")
          slot = :"__kif_mm_#{s.delete('=')}"
          return s.end_with?("=") ? (Thread.current[slot] = args[0]) : (Thread.current[slot] || 0)
        end
        super
      end
    end
  end
rescue Exception
end

module Haptics
  module HID
    VID_SONY = 0x054C
    PID_DUALSENSE      = 0x0CE6
    PID_DUALSENSE_EDGE = 0x0DF2
    PID_DS4_V1         = 0x05C4
    PID_DS4_V2         = 0x09CC
    PID_DS4_DONGLE     = 0x0BA0
    DUALSENSE_PIDS = [PID_DUALSENSE, PID_DUALSENSE_EDGE]
    DS4_PIDS       = [PID_DS4_V1, PID_DS4_V2, PID_DS4_DONGLE]

    # GUID_DEVINTERFACE_HID  {4D1E55B2-F16F-11CF-88CB-001111000030}
    HID_GUID = "\xB2\x55\x1E\x4D\x6F\xF1\xCF\x11\x88\xCB\x00\x11\x11\x00\x00\x30".b

    INVALID_HANDLE = 0xFFFFFFFFFFFFFFFF
    RESCAN_MS = 4000.0

    @load_tried = false
    @loaded     = false   # Fiddle + funcs bound?
    @last_scan  = -1.0e9
    @handle     = nil     # writable device handle (Integer address) or nil
    @kind       = nil     # :dualsense / :dualshock4 / nil
    @conn       = nil     # :usb / :bt
    @out_len    = 0       # output report length for the open device
    @seq        = 0       # DualSense Bluetooth output sequence nibble
    @last_err   = nil     # human-readable last problem (for diagnostics)
    @applied    = nil     # [lo,hi] last bytes written (dedupe)

    class << self
      attr_reader :kind, :conn, :out_len, :last_err

      def now_ms; Time.now.to_f * 1000.0; end

      # Fiddle.dlopen lives in the pure-Ruby fiddle.rb wrapper, which mkxp-z's
      # embedded Ruby does NOT load (only the Fiddle C extension is present), so
      # Fiddle.dlopen raised "undefined method `dlopen' for Fiddle:Module" and
      # silently killed this bridge (exe_dir too -> exedir=nil in the log).
      # Fiddle::Handle.new is the C primitive Fiddle.dlopen merely wraps
      # (def dlopen(l); Fiddle::Handle.new(l); end); it returns the same Handle,
      # on which handle[name] yields the symbol address exactly as used here.
      def fiddle_dlopen(path)
        Fiddle.respond_to?(:dlopen) ? Fiddle.dlopen(path) : Fiddle::Handle.new(path)
      end

      # ----- lazy Fiddle binding (dlopen success == we are on Windows) ------
      def load!
        return @loaded if @load_tried
        @load_tried = true
        @loaded = false
        begin
          require 'fiddle'
        rescue Exception => e
          @last_err = "require fiddle failed: #{e.class}: #{e.message}"
          return false
        end
        # zlib stays LAZY (BT CRC-32 only, via _hid_zlib_ok?) so a build lacking the
        # zlib ext still gets USB rumble + detection.
        k32 = cfg = hid = nil
        begin; k32 = fiddle_dlopen('kernel32.dll'); rescue Exception => e
          @last_err = "dlopen kernel32 failed: #{e.class}: #{e.message}"; return false; end
        begin; cfg = fiddle_dlopen('cfgmgr32.dll'); rescue Exception => e
          @last_err = "dlopen cfgmgr32 failed: #{e.class}: #{e.message}"; return false; end
        begin; hid = fiddle_dlopen('hid.dll'); rescue Exception => e
          @last_err = "dlopen hid.dll failed: #{e.class}: #{e.message}"; return false; end
        tp = Fiddle::TYPE_VOIDP; ti = Fiddle::TYPE_INT
        @fn = {}
        @bind_fail = []
        bind = lambda do |key, handle, sym, args, ret|
          begin
            @fn[key] = Fiddle::Function.new(handle[sym], args, ret)
          rescue Exception => e
            @fn[key] = nil
            @bind_fail << "#{sym}:#{e.class}"
          end
        end
        # Each symbol bound INDEPENDENTLY: one missing/odd export must NOT abort the
        # whole bridge. The old single-begin-block bound them together, so any one
        # failure blanked detection entirely -> the "No controller detected" report.
        bind.call(:CreateFileW,     k32, 'CreateFileW',   [tp, ti, ti, tp, ti, ti, tp], tp)
        bind.call(:WriteFile,       k32, 'WriteFile',     [tp, tp, ti, tp, tp], ti)
        bind.call(:CloseHandle,     k32, 'CloseHandle',   [tp], ti)
        bind.call(:CM_Size,         cfg, 'CM_Get_Device_Interface_List_SizeW', [tp, tp, tp, ti], ti)
        bind.call(:CM_List,         cfg, 'CM_Get_Device_Interface_ListW',      [tp, tp, tp, ti, ti], ti)
        bind.call(:GetAttributes,   hid, 'HidD_GetAttributes',     [tp, tp], ti)
        bind.call(:GetPreparsed,    hid, 'HidD_GetPreparsedData',  [tp, tp], ti)
        bind.call(:FreePreparsed,   hid, 'HidD_FreePreparsedData', [tp], ti)
        bind.call(:GetCaps,         hid, 'HidP_GetCaps',           [tp, tp], ti)
        bind.call(:SetOutputReport, hid, 'HidD_SetOutputReport',   [tp, tp, ti], ti)
        # Minimum needed to ENUMERATE + identify a pad (label / detection):
        essential = [:CreateFileW, :CloseHandle, :CM_Size, :CM_List, :GetAttributes]
        missing = essential.select { |k| @fn[k].nil? }
        if missing.empty?
          @loaded = true
          @last_err = (@bind_fail.empty? ? nil : "optional HID symbols missing: #{@bind_fail.join(',')}")
        else
          @last_err = "essential HID symbols missing: #{missing.join(',')} (bind errs: #{@bind_fail.join(',')})"
          @loaded = false
        end
        @loaded
      rescue Exception => e
        @last_err = "load! crashed: #{e.class}: #{e.message}"
        @loaded = false
      end

      WNULL = "\x00\x00".b   # one UTF-16LE NUL code unit

      # Walk the CM_Get_Device_Interface_ListW multi-sz buffer in 2-byte units,
      # yielding each NUL-terminated UTF-16LE interface path (terminator kept).
      def each_hid_path
        len_buf = ("\0" * 4).b
        return if @fn[:CM_Size].call(len_buf, HID_GUID, 0, 0) != 0
        nchars = len_buf.unpack1('L<')
        return if nchars.nil? || nchars < 2 || nchars > 2_000_000
        buf = ("\0" * (nchars * 2)).b
        return if @fn[:CM_List].call(HID_GUID, 0, buf, nchars, 0) != 0
        i = 0
        cur = "".b
        total = buf.bytesize
        while i + 1 < total
          unit = buf[i, 2]
          i += 2
          if unit == WNULL
            if cur.bytesize > 0
              yield (cur + WNULL)   # re-attach terminator for CreateFileW
              cur = "".b
            else
              break                 # double-NUL = end of list
            end
          else
            cur << unit
          end
        end
      end

      # A 32-bit access mask like GENERIC_READ|WRITE (0xC0000000) overflows a SIGNED
      # Fiddle int ("bignum too big to convert into `long'"), which crashed the
      # write-open of the DualSense -> detected-but-not-writable -> no rumble (the
      # query-open uses access 0 so detection still worked). Pass the two's-complement
      # signed value; the OS still receives the identical 0xC0000000 DWORD. USB + BT.
      def to_i32(x)
        x &= 0xFFFFFFFF
        x >= 0x80000000 ? x - 0x100000000 : x
      end

      def open_path(wpath, write)
        access = write ? to_i32(0x80000000 | 0x40000000) : 0   # GENERIC_READ|WRITE or query-only
        share  = 0x1 | 0x2                                      # FILE_SHARE_READ|WRITE
        h = @fn[:CreateFileW].call(wpath, access, share, 0, 3, 0, 0)   # OPEN_EXISTING
        addr = (h.respond_to?(:to_i) ? h.to_i : h) & 0xFFFFFFFFFFFFFFFF
        return nil if addr == 0 || addr == INVALID_HANDLE
        return addr
      end

      def attrs_of(addr)
        b = ("\0" * 12).b
        b[0, 4] = [12].pack('L<')        # HIDD_ATTRIBUTES.Size
        return nil if @fn[:GetAttributes].call(addr, b) == 0
        [b[4, 2].unpack1('S<'), b[6, 2].unpack1('S<')]   # VendorID, ProductID
      end

      # OutputReportByteLength via HidP caps (DualSense 48 USB / 78 BT; DS4 32 / 78)
      def output_len_of(addr)
        return 0 if @fn[:GetPreparsed].nil? || @fn[:GetCaps].nil?
        pp = ("\0" * 8).b
        return 0 if @fn[:GetPreparsed].call(addr, pp) == 0
        pre = pp.unpack1('Q<')
        return 0 if pre.nil? || pre == 0
        caps = ("\0" * 128).b
        st = @fn[:GetCaps].call(pre, caps)
        @fn[:FreePreparsed].call(pre) rescue nil
        return 0 if st != 0x00110000     # HIDP_STATUS_SUCCESS
        caps[6, 2].unpack1('S<').to_i    # OutputReportByteLength
      end

      def kind_for(vid, pid)
        return nil unless vid == VID_SONY
        return :dualsense  if DUALSENSE_PIDS.include?(pid)
        return :dualshock4 if DS4_PIDS.include?(pid)
        nil
      end

      # ----- (re)scan ------------------------------------------------------
      #  * a live writable handle is kept and NOT re-enumerated (cheap) until a
      #    write fails and clears it;
      #  * empty scans are throttled to RESCAN_MS so per-frame ready? is cheap.
      def scan(force = false)
        unless load!
          log_hid_once(0, [], false)   # load failed -> record exactly why (no silent inert)
          return
        end
        return if @handle && !force                       # keep working handle
        t = now_ms
        return if !force && (t - @last_scan) < RESCAN_MS   # throttle empty re-scans
        @last_scan = t
        close_handle
        detected = nil
        paths = 0; sony = []
        begin
          each_hid_path do |wpath|
            paths += 1
            q = open_path(wpath, false)        # query-open works even if write-locked
            next unless q
            a = attrs_of(q)
            k = a && kind_for(a[0], a[1])
            if k
              sony << k
              detected ||= k
              w = open_path(wpath, true)        # try to grab it for output
              if w
                ol = output_len_of(w)
                ol = (k == :dualshock4 ? 32 : 48) if ol <= 0
                if k == :dualshock4 && ol >= 78   # DS4 over BT not reliable here -> XInput
                  @fn[:CloseHandle].call(w) rescue nil
                else
                  @fn[:CloseHandle].call(q) rescue nil
                  @handle  = w
                  @kind    = k
                  @out_len = ol
                  @conn    = (ol >= 78 ? :bt : :usb)
                  @applied = nil
                  @last_err = nil
                  log_hid_once(paths, sony, true)
                  return
                end
              end
            end
            @fn[:CloseHandle].call(q) rescue nil
          end
        rescue Exception => e
          @kind = detected
          @last_err = "enumeration crashed after #{paths} paths: #{e.class}: #{e.message}"
          log_hid_once(paths, sony, false)
          return
        end
        @kind = detected     # label-only (visible but not writable)
        @last_err = if detected
          "found #{detected} but could not open for output (Steam Input/SDL may hold it write-locked)"
        elsif paths == 0
          "no HID interfaces enumerated (CM list empty)"
        else
          "no Sony pad among #{paths} HID interfaces"
        end
        log_hid_once(paths, sony, false)
      end

      # zlib is only needed for the DualSense BLUETOOTH report CRC-32. Probe it
      # lazily so a missing zlib extension never blocks USB rumble or detection.
      def _hid_zlib_ok?
        return @zlib_ok unless @zlib_ok.nil?
        @zlib_ok = (require 'zlib'; defined?(Zlib) ? true : false) rescue false
      end

      # One-shot (escalating) diagnostic so a live DIRECT-EXE run shows exactly why
      # the raw-HID path did or did not bind: enumerated HID paths, Sony pads seen,
      # whether one opened writable, report length / connection, zlib, last error.
      # Logs at most once per state level: 0 nothing, 1 found-not-writable, 2 writable.
      # Never logs on the Steam-Input path (HID is not scanned there).
      def log_hid_once(paths, sony, writable)
        lvl = writable ? 2 : (@kind ? 1 : 0)
        return if (@logged_hid_lvl || -1) >= lvl
        @logged_hid_lvl = lvl
        begin
          base = (Dir.pwd rescue ".")
          dir  = File.join(base, "Logs")
          (Dir.mkdir(dir) rescue nil) unless File.directory?(dir)
          fpath = File.directory?(dir) ? File.join(dir, "rumble_hid.log") : File.join(base, "rumble_hid.log")
          File.open(fpath, "a") do |f|
            f.puts("[#{Time.now}] HID bridge: loaded=#{@loaded} hid_paths=#{paths} sony_found=#{sony.inspect} kind=#{@kind.inspect} writable=#{writable} out_len=#{@out_len} conn=#{@conn.inspect} zlib=#{(_hid_zlib_ok? rescue nil)} err=#{@last_err.inspect}")
          end
        rescue Exception
        end
      end

      def close_handle
        if @handle
          @fn[:CloseHandle].call(@handle) rescue nil
          @handle = nil
        end
        @applied = nil
      end

      def ready?                  # writable raw-HID device available?
        load!
        scan(false) if @handle.nil?
        !@handle.nil?
      end

      def detect_kind            # kind for the label, even if not writable
        load!
        scan(false)
        @kind
      end

      # lo8/hi8 already scaled to 0..255 (low/strong, high/weak)
      def rumble(lo8, hi8)
        return false unless @handle
        lo8 = clamp8(lo8); hi8 = clamp8(hi8)
        return true if @applied == [lo8, hi8]
        rep = build_report(lo8, hi8)
        return false unless rep
        if write_report(rep)
          @applied = [lo8, hi8]
          return true
        end
        close_handle                       # device went away -> rescan next call
        @last_err = "write failed; rescanning"
        false
      end

      def clamp8(x)
        x = x.to_i; x = 0 if x < 0; x = 255 if x > 255; x
      end

      def build_report(lo8, hi8)
        case @kind
        when :dualsense
          if @conn == :bt
            return nil unless _hid_zlib_ok?    # BT output report needs CRC-32 (zlib)
            r = ("\0" * @out_len).b
            r.setbyte(0, 0x31)
            r.setbyte(1, ((@seq & 0x0F) << 4) | 0x02)   # seq nibble + data tag
            @seq = (@seq + 1) & 0x0F
            ds_common!(r, 2, lo8, hi8)
            seed = Zlib.crc32("\xA2".b)                 # CRC seed byte
            crc  = Zlib.crc32(r[0, @out_len - 4], seed) # over seed + report[0..len-5]
            r[@out_len - 4, 4] = [crc].pack('V')
            r
          else
            r = ("\0" * @out_len).b
            r.setbyte(0, 0x02)
            ds_common!(r, 1, lo8, hi8)
            r
          end
        when :dualshock4
          r = ("\0" * @out_len).b
          r.setbyte(0, 0x05)
          r.setbyte(1, 0x01)        # enable rumble, leave LED untouched
          r.setbyte(4, hi8)         # right / weak / high-freq
          r.setbyte(5, lo8)         # left  / strong / low-freq
          r
        else
          nil
        end
      rescue Exception => e
        @last_err = "build err #{e.class}"
        nil
      end

      # DualSense common output block starting at offset `o`
      def ds_common!(r, o, lo8, hi8)
        r.setbyte(o + 0, 0x03)   # valid_flag0: HAPTICS_SELECT(0x02)|COMPATIBLE_VIBRATION(0x01) - motors are IGNORED without HAPTICS_SELECT on current DS firmware
        r.setbyte(o + 2, hi8)    # motor_right (weak / high-freq)
        r.setbyte(o + 3, lo8)    # motor_left  (strong / low-freq)
        r.setbyte(o + 38, 0x04)  # valid_flag2: COMPATIBLE_VIBRATION2 (newer firmware)
      end

      def write_report(rep)
        wrote = ("\0" * 4).b
        return true if @fn[:WriteFile] && @fn[:WriteFile].call(@handle, rep, rep.bytesize, wrote, 0) != 0
        return false if @fn[:SetOutputReport].nil?
        @fn[:SetOutputReport].call(@handle, rep, rep.bytesize) != 0   # control-transfer fallback
      rescue Exception
        false
      end

      # Forced fresh probe used by the Test Vibration button: re-runs load!,
      # re-scans, and (if a writable handle is obtained) actually sends one
      # rumble output report - logging the result every press so the live log
      # always reflects the CURRENT build (the normal one-shot log can be stale
      # across a re-test in the same session).
      def test_probe!(do_write = true)
        @logged_hid_lvl = -1
        @load_tried = false
        close_handle
        scan(true)
        if @handle && do_write
          ok = (write_report(build_report(180, 180)) rescue false)
          begin
            base = (Dir.pwd rescue "."); dir = File.join(base, "Logs")
            (Dir.mkdir(dir) rescue nil) unless File.directory?(dir)
            fp = File.directory?(dir) ? File.join(dir, "rumble_hid.log") : File.join(base, "rumble_hid.log")
            File.open(fp, "a") { |f| f.puts("[#{Time.now}] HID test write: kind=#{@kind.inspect} conn=#{@conn.inspect} out_len=#{@out_len} write_ok=#{ok} err=#{@last_err.inspect}") }
          rescue Exception
          end
          @applied = nil   # let the real test pattern re-send fresh values
        end
        @handle ? true : false
      rescue Exception => e
        (@last_err = "test_probe! crashed: #{e.class}: #{e.message}") rescue nil
        false
      end

      def diagnostics
        load!
        { :loaded => @loaded, :kind => @kind, :conn => @conn,
          :out_len => @out_len, :writable => !@handle.nil?, :error => @last_err }
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Splice the raw-HID backend into the priority chain:
#     native Steam Input (006)  >  direct raw-HID (here)  >  XInput (001)
# We alias the *current* (post-006) primitives, so the native path is untouched
# and only the non-native branch gains an HID stage above XInput.
#-------------------------------------------------------------------------------
module Haptics
  class << self
    unless method_defined?(:_hid_prev_ready?) || private_method_defined?(:_hid_prev_ready?)
      alias_method :_hid_prev_ready?, :ready?
      def ready?
        return true if native_available?
        return true if (Haptics::HID.ready? rescue false)
        _hid_prev_ready?
      end
    end

    unless method_defined?(:_hid_prev_set_motors) || private_method_defined?(:_hid_prev_set_motors)
      alias_method :_hid_prev_set_motors, :set_motors
      def set_motors(low01, high01)
        if !native_available? && (Haptics::HID.ready? rescue false)
          scale = intensity.to_f / 100.0
          lo = (low01.to_f  * scale * 255.0).round
          hi = (high01.to_f * scale * 255.0).round
          Haptics::HID.rumble(lo, hi) rescue nil
          return
        end
        _hid_prev_set_motors(low01, high01)   # native (006) or XInput (001)
      end
    end

    unless method_defined?(:_hid_prev_tick) || private_method_defined?(:_hid_prev_tick)
      alias_method :_hid_prev_tick, :tick
      def tick
        return _hid_prev_tick if native_available?
        if (Haptics::HID.ready? rescue false)
          if @active
            t = now_ms
            advance_step(t) if t >= @step_end   # advance_step -> set_motors -> HID
          end
          return
        end
        _hid_prev_tick
      end
    end

    unless method_defined?(:_hid_prev_controller_kind) || private_method_defined?(:_hid_prev_controller_kind)
      alias_method :_hid_prev_controller_kind, :controller_kind
      def controller_kind
        return _hid_prev_controller_kind if native_available?
        k = (Haptics::HID.detect_kind rescue nil)
        return k if k
        _hid_prev_controller_kind            # :xinput / :unknown
      end
    end

    # true when rumble is going out over the direct raw-HID path (not native, not XInput)
    def hid_direct?
      return false if native_available?
      (Haptics::HID.ready? rescue false)
    end

    def hid_connection
      Haptics::HID.conn
    end

    def stop_hid
      Haptics::HID.close_handle rescue nil
    end
  end
end
