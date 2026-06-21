#===============================================================================
# Raw-HID controller INPUT reader (direct DualSense / DS4, no Steam Input)
#                                                       [ControllerHIDInput.rb]
#===============================================================================
# On the bare game exe a DualSense plugged in directly is invisible to BOTH the
# winmm joystick API and XInput (see memory: dualsense-directexe-winmm-xinput-
# blind). Only mkxp's SDL layer sees it -- and it does not expose Create/Select
# or the triggers as readable RGSS buttons. This module reads the controller's
# input reports STRAIGHT off raw HID using Ruby's Fiddle (real 64-bit FFI, so
# device HANDLEs survive -- the same approach the rumble HID bridge already uses
# to WRITE to the pad in 691_Rumble/007_RumbleHIDBridge.rb).
#
# It parses the documented DualSense report and produces an SDL game-controller
# button set ({sdl_index => true}) -- the SAME format ControlRebind already
# consumes -- so once fed in, Select (Create -> SDL 4 = Back) toggles the HUD,
# every face/shoulder button is correct, the d-pad is readable, and L2/R2 come
# through as analog triggers. A background thread does the blocking ReadFile so
# the main loop never stalls; everything is rescued and INERT if Fiddle is
# missing, no Sony pad is present, or the OS refuses the handle.
#
# This file only READS and exposes the data (+ a diagnostic readout). Feeding it
# into the live input layer is done by ControlRebind.
#===============================================================================
# --- Fiddle Windows last-error shim (mkxp-z embedded Ruby) -- mirrors 691_Rumble/007.
# Fiddle::Function#call invokes Fiddle.win32_last_error= / last_error= after every
# native call; this embedded Ruby's Fiddle lacks them, so each call would raise
# NoMethodError (rescued) and silently "fail". Idempotent: no-op if already set by
# the rumble bridges. Installed here so this reader never depends on their load.
begin
  require 'fiddle'
  module Fiddle
    unless respond_to?(:win32_last_error)
      def self.win32_last_error; Thread.current[:__kif_fiddle_w32err] || 0; end
    end
    unless respond_to?(:win32_last_error=)
      def self.win32_last_error=(v); Thread.current[:__kif_fiddle_w32err] = v; end
    end
    unless respond_to?(:last_error)
      def self.last_error; Thread.current[:__kif_fiddle_err] || 0; end
    end
    unless respond_to?(:last_error=)
      def self.last_error=(v); Thread.current[:__kif_fiddle_err] = v; end
    end
  end
rescue Exception
end

module ControllerHIDInput
  VID_SONY           = 0x054C
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
  WNULL = "\x00\x00".b

  # SDL game-controller button indices (match ControlRebind / keybindings.mkxp1).
  SDL_A=0; SDL_B=1; SDL_X=2; SDL_Y=3; SDL_BACK=4; SDL_GUIDE=5; SDL_START=6
  SDL_L3=7; SDL_R3=8; SDL_L1=9; SDL_R1=10; SDL_DU=11; SDL_DD=12; SDL_DL=13; SDL_DR=14

  SDL_NAME = {
    SDL_A => "Cross", SDL_B => "Circle", SDL_X => "Square", SDL_Y => "Triangle",
    SDL_BACK => "Create(Select)", SDL_GUIDE => "PS", SDL_START => "Options",
    SDL_L3 => "L3", SDL_R3 => "R3", SDL_L1 => "L1", SDL_R1 => "R1",
    SDL_DU => "D-Up", SDL_DD => "D-Down", SDL_DL => "D-Left", SDL_DR => "D-Right"
  }

  @load_tried = false
  @loaded     = false
  @fn         = nil
  @handle     = nil      # read handle (Integer address) or nil
  @kind       = nil      # :dualsense / :dualshock4
  @conn       = :usb     # :usb / :bt (from report id)
  @snapshot   = nil      # frozen [sdlmask, l2, r2] or nil
  @last_read  = -1.0e9
  @last_scan  = -1.0e9
  @last_err   = nil
  @thread     = nil
  @stop       = false
  @started    = false

  class << self
    attr_reader :kind, :conn, :last_err, :loaded

    def now_ms; Time.now.to_f * 1000.0; end

    def fiddle_dlopen(path)
      Fiddle.respond_to?(:dlopen) ? Fiddle.dlopen(path) : Fiddle::Handle.new(path)
    end

    def load!
      return @loaded if @load_tried
      @load_tried = true
      @loaded = false
      begin
        require 'fiddle'
        k32 = fiddle_dlopen('kernel32.dll')
        cfg = fiddle_dlopen('cfgmgr32.dll')
        hid = fiddle_dlopen('hid.dll')
        tp = Fiddle::TYPE_VOIDP
        ti = Fiddle::TYPE_INT
        @fn = {}
        @fn[:CreateFileW]   = Fiddle::Function.new(k32['CreateFileW'], [tp, ti, ti, tp, ti, ti, tp], tp)
        @fn[:ReadFile]      = Fiddle::Function.new(k32['ReadFile'], [tp, tp, ti, tp, tp], ti)
        @fn[:CloseHandle]   = Fiddle::Function.new(k32['CloseHandle'], [tp], ti)
        @fn[:CM_Size]       = Fiddle::Function.new(cfg['CM_Get_Device_Interface_List_SizeW'], [tp, tp, tp, ti], ti)
        @fn[:CM_List]       = Fiddle::Function.new(cfg['CM_Get_Device_Interface_ListW'], [tp, tp, tp, ti, ti], ti)
        @fn[:GetAttributes] = Fiddle::Function.new(hid['HidD_GetAttributes'], [tp, tp], ti)
        @loaded = true
      rescue Exception => e
        @last_err = "fiddle unavailable: #{e.class}"
        @loaded = false
      end
      @loaded
    end

    def each_hid_path
      len_buf = ("\0" * 4).b
      return if @fn[:CM_Size].call(len_buf, HID_GUID, 0, 0) != 0
      nchars = len_buf.unpack1('L<')
      return if nchars.nil? || nchars < 2 || nchars > 2_000_000
      buf = ("\0" * (nchars * 2)).b
      return if @fn[:CM_List].call(HID_GUID, 0, buf, nchars, 0) != 0
      i = 0; cur = "".b; total = buf.bytesize
      while i + 1 < total
        unit = buf[i, 2]; i += 2
        if unit == WNULL
          if cur.bytesize > 0
            yield(cur + WNULL); cur = "".b
          else
            break
          end
        else
          cur << unit
        end
      end
    end

    def open_with(wpath, access)
      share = 0x1 | 0x2                  # FILE_SHARE_READ|WRITE
      h = @fn[:CreateFileW].call(wpath, access, share, 0, 3, 0, 0)   # OPEN_EXISTING
      addr = (h.respond_to?(:to_i) ? h.to_i : h) & 0xFFFFFFFFFFFFFFFF
      return nil if addr == 0 || addr == INVALID_HANDLE
      addr
    end

    def attrs_of(addr)
      b = ("\0" * 12).b
      b[0, 4] = [12].pack('L<')          # HIDD_ATTRIBUTES.Size
      return nil if @fn[:GetAttributes].call(addr, b) == 0
      [b[4, 2].unpack1('S<'), b[6, 2].unpack1('S<')]   # VendorID, ProductID
    end

    def kind_for(vid, pid)
      return nil unless vid == VID_SONY
      return :dualsense  if DUALSENSE_PIDS.include?(pid)
      return :dualshock4 if DS4_PIDS.include?(pid)
      nil
    end

    # Find a Sony pad and open a dedicated READ handle (separate from the rumble
    # WRITE handle so blocking reads never serialize against motor writes).
    def find_and_open!
      return true if @handle
      return false unless load!
      t = now_ms
      return false if (t - @last_scan) < 1500.0    # throttle empty rescans
      @last_scan = t
      opened = false
      each_hid_path do |wpath|
        q = open_with(wpath, 0)                     # query-only (safest)
        next unless q
        a = attrs_of(q)
        @fn[:CloseHandle].call(q) rescue nil
        k = a && kind_for(a[0], a[1])
        next unless k
        r = open_with(wpath, 0x80000000)            # GENERIC_READ
        next unless r
        @handle = r; @kind = k; @last_err = nil
        opened = true
        break
      end
      @last_err = "no DualSense/DS4 enumerated" unless opened || @last_err
      opened
    end

    def close_read
      if @handle
        @fn[:CloseHandle].call(@handle) rescue nil
        @handle = nil
      end
    end

    # Parse a DualSense/DS4 input report into [sdlmask, l2, r2]. USB report id
    # 0x01 (data at +0), Bluetooth id 0x31 (data shifted +1). nil if unusable.
    def parse(buf, n)
      return nil if n.nil? || n < 11
      id = buf.getbyte(0)
      if    id == 0x01 then lx = 1; @conn = :usb
      elsif id == 0x31 then lx = 2; @conn = :bt
      else  return nil
      end
      d_off = lx + 7; s_off = lx + 8; m_off = lx + 9
      return nil if m_off >= n
      b0 = buf.getbyte(d_off) || 0   # dpad(low nibble) + faces(high nibble)
      b1 = buf.getbyte(s_off) || 0   # L1 R1 L2 R2 Create Options L3 R3
      b2 = buf.getbyte(m_off) || 0   # PS Touchpad Mute ...
      m = 0
      m |= (1 << SDL_X)  if (b0 & 0x10) != 0   # Square
      m |= (1 << SDL_A)  if (b0 & 0x20) != 0   # Cross
      m |= (1 << SDL_B)  if (b0 & 0x40) != 0   # Circle
      m |= (1 << SDL_Y)  if (b0 & 0x80) != 0   # Triangle
      m |= (1 << SDL_L1)    if (b1 & 0x01) != 0
      m |= (1 << SDL_R1)    if (b1 & 0x02) != 0
      m |= (1 << SDL_BACK)  if (b1 & 0x10) != 0   # Create / Share = Select
      m |= (1 << SDL_START) if (b1 & 0x20) != 0   # Options
      m |= (1 << SDL_L3)    if (b1 & 0x40) != 0
      m |= (1 << SDL_R3)    if (b1 & 0x80) != 0
      m |= (1 << SDL_GUIDE) if (b2 & 0x01) != 0   # PS
      case (b0 & 0x0F)
      when 0 then m |= (1 << SDL_DU)
      when 1 then m |= (1 << SDL_DU) | (1 << SDL_DR)
      when 2 then m |= (1 << SDL_DR)
      when 3 then m |= (1 << SDL_DR) | (1 << SDL_DD)
      when 4 then m |= (1 << SDL_DD)
      when 5 then m |= (1 << SDL_DD) | (1 << SDL_DL)
      when 6 then m |= (1 << SDL_DL)
      when 7 then m |= (1 << SDL_DL) | (1 << SDL_DU)
      end
      l2 = buf.getbyte(lx + 4) || 0
      r2 = buf.getbyte(lx + 5) || 0
      [m, l2, r2].freeze
    rescue
      nil
    end

    def reader_loop
      rbuf = ("\0" * 64).b
      nrd  = ("\0" * 4).b
      until @stop
        if @handle.nil?
          (find_and_open! rescue nil)
          (sleep 0.4; next) if @handle.nil?
        end
        ok = (@fn[:ReadFile].call(@handle, rbuf, 64, nrd, 0) rescue 0)
        if ok != 0
          n = nrd.unpack1('L<')
          snap = parse(rbuf, n)
          if snap
            @snapshot = snap
            @last_read = now_ms
          end
          sleep 0.001                 # yield: main loop always gets a slice
        else
          close_read                  # device went away -> rescan
          sleep 0.4
        end
      end
    rescue
      nil
    end

    # Lazily start the reader. Safe to call every frame / multiple times.
    def ensure_started
      return if @started
      return unless load!
      @started = true
      @stop = false
      begin
        @thread = Thread.new { reader_loop }
        @thread.abort_on_exception = false rescue nil
      rescue Exception => e
        @last_err = "thread start failed: #{e.class}"
        @started = false
      end
    rescue
      nil
    end

    def stop!
      @stop = true
      close_read
    end

    # Currently delivering fresh reports?
    def active?
      ensure_started
      !@snapshot.nil? && (now_ms - @last_read) < 600.0
    rescue
      false
    end

    # {sdl_index => true} for ControlRebind. Empty hash when not pressed.
    def sdl_set
      s = @snapshot
      return {} unless s
      m = s[0]; set = {}
      (0..14).each { |i| set[i] = true if (m & (1 << i)) != 0 }
      set
    rescue
      {}
    end

    def triggers
      s = @snapshot
      s ? [s[1], s[2]] : [0, 0]
    rescue
      [0, 0]
    end

    # Lines for the Controller Diagnostic. Each: [text, hot_bool].
    def diag_lines
      ensure_started
      return [["raw-HID: Fiddle unavailable (#{@last_err})", true]] unless @loaded
      if @handle.nil?
        return [["raw-HID: no DualSense/DS4 open (#{@last_err})", true]]
      end
      s = @snapshot
      return [["raw-HID: #{@kind}/#{@conn} open, waiting for first report...", true]] if s.nil?
      stale = (now_ms - @last_read) >= 600.0
      set = sdl_set
      names = []
      (0..14).each { |i| names << SDL_NAME[i] if set[i] }
      [
        ["raw-HID: #{@kind} over #{@conn}  #{stale ? '(STALE)' : '(reading OK)'}", stale],
        ["  buttons: #{names.empty? ? '(none)' : names.join(' ')}", !names.empty?],
        ["  L2:#{s[1]}  R2:#{s[2]}", (s[1].to_i > 20 || s[2].to_i > 20)]
      ]
    rescue => e
      [["raw-HID: error #{e.class}", true]]
    end
  end
end
