#===============================================================================
# Controller Vibration / Rumble  -  STEAM INPUT BRIDGE (pure Ruby, no recompile)
#-------------------------------------------------------------------------------
# The problem this solves
# ------------------------
# When KIF is launched through Steam as a NON-STEAM GAME with "Steam Input" on,
# Steam hands the game a VIRTUAL XBOX 360 pad and hides the real controller. SDL
# and XInput therefore only ever see "Xbox", so a DualSense is reported as Xbox
# in the Test Vibration readout. The ONLY supported way to see the REAL type
# through that disguise is the Steamworks Steam Input API.
#
# 006_RumbleNativeBridge.rb already routes detection + rumble + lightbar through
# a `SteamHaptics` module IF the engine was recompiled with the C++ Steam Input
# patch (see (Source)/SteamInputPatch/). Almost nobody runs that custom build -
# the shipped Game.exe is the stock mkxp-z, which has no such module.
#
# This file provides the SAME `SteamHaptics` contract in PURE RUBY via Fiddle
# (the engine already bundles Fiddle; the 007 raw-HID bridge depends on it too).
# It loads steam_api64.dll and calls the documented flat Steam Input C API:
#     SteamAPI_Init / SteamAPI_InitFlat
#     SteamAPI_SteamInput_vNNN  (interface accessor; version auto-probed)
#     SteamAPI_ISteamInput_{Init,RunFrame,GetConnectedControllers,
#                           GetInputTypeForHandle,TriggerVibration,
#                           TriggerVibrationExtended,SetLEDColor}
# so the stock exe gains native DualSense detection (k_ESteamInputType_PS5
# Controller == 13), the two trigger motors, and lightbar tinting - with NO
# engine rebuild and Steam Input left ON.
#
# One manual step
# ---------------
#   * steam_api64.dll must sit next to Game.exe. It is a free Steamworks
#     redistributable and is already present in the install folder of virtually
#     any Steam game you own - copy that one over. (Any reasonably recent build
#     exports the flat symbols used here.)
#   * Launch via Steam (the non-Steam shortcut) with Steam Input enabled, so
#     Steam puts the App ID in the environment. If it didn't, we fall back to
#     Valve's public Spacewar App ID (480) via the environment.
#
# Safety
# ------
# Everything is fully wrapped. No DLL, no Steam, non-Windows, init failure, or no
# Steam-Input controller -> this module is INERT, `SteamHaptics.available?`
# returns false, and 006 / 007 / 001 fall back exactly as before. If the engine
# WAS compiled with the native C++ `SteamHaptics`, this file detects that and
# leaves the native binding completely untouched.
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

unless defined?(SteamHaptics)   # never shadow the native C++ binding if present

module Haptics
  module SteamInputAPI
    INPUT_MAX     = 16          # STEAM_INPUT_MAX_COUNT
    HANDLE_BYTES  = 8           # sizeof(InputHandle_t)
    LED_SET_COLOR = 0           # k_ESteamInputLEDFlag_SetColor
    LED_RESTORE   = 1           # k_ESteamInputLEDFlag_RestoreUserDefault
    # ISteamInput interface accessor versions, newest first.
    IFACE_VERSIONS = %w[v006 v005 v004 v003 v002 v001]
    LIST_THROTTLE_MS = 750.0

    @tried        = false
    @ok           = false
    @lib          = nil
    @iface        = 0           # ISteamInput* as an Integer address
    @count        = 0
    @handles      = []
    @last_refresh = -1.0e9
    @err          = nil
    @fn           = {}
    @logged       = false
    @steam_running = nil        # SteamAPI_IsSteamRunning() result (diag)
    @init_reason   = nil        # captured [S_API FAIL] text (diag)
    @env_before    = {}         # SteamAppId/GameId/OverlayGameId as Steam left them
    @iface_ver     = nil        # which SteamInput0xx accessor resolved
    @appid_file    = nil        # path we wrote/expect steam_appid.txt at
    @appid_ok      = nil        # appid file present after ensure?
    @last_init_ok  = false      # steam_api_init outcome

    class << self
      attr_reader :err

      def now_ms; Time.now.to_f * 1000.0; end

      # --- launch-context gate ------------------------------------------------
      # The BARE Game.exe must NOT engage Steam (which forces the Spacewar appid
      # 480 + Steam Input + recreates steam_appid.txt). Engage ONLY when Steam
      # actually launched the game, or when the user explicitly forces it with a
      # steam_input_on.txt flag next to the exe. steam_input_off.txt forces off.
      def flag_file_cwd?(name)
        d = (Dir.pwd rescue nil)
        return false unless d
        File.exist?(File.join(d, name))
      rescue Exception
        false
      end

      def launched_via_steam?
        return true if ENV["SteamClientLaunch"].to_s == "1"
        return true if ENV["SteamEnv"].to_s == "1"
        %w[SteamGameId SteamAppId SteamOverlayGameId].each do |k|
          v = ENV[k].to_s
          return true if v =~ /\A\d+\z/ && v != "0"
        end
        false
      rescue Exception
        false
      end

      def steam_input_should_engage?
        return false if flag_file_cwd?("steam_input_off.txt")
        return true  if flag_file_cwd?("steam_input_on.txt")
        launched_via_steam?
      end

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

      def windows?
        !!(RUBY_PLATFORM =~ /mswin|mingw|cygwin/)
      end

      #--- one-time load + Steam init ---------------------------------------
      def load!
        return @ok if @tried
        @tried = true
        @ok    = false
        unless windows?
          @err = "not Windows"
          log_once; return false
        end
        unless steam_input_should_engage?
          @err = "Steam Input idle: bare launch (not via Steam). Drop steam_input_on.txt next to Game.exe to force it on."
          log_once; return false
        end
        begin
          require 'fiddle'
        rescue Exception => e
          @err = "fiddle unavailable: #{e.class}"
          log_once; return false
        end
        @lib = nil
        @dll_path = nil
        @dll_errs = []
        cands = ["steam_api64.dll", File.join(Dir.pwd, "steam_api64.dll")]
        ed = (exe_dir rescue nil)
        cands << File.join(ed, "steam_api64.dll") if ed
        cands.uniq.each do |p|
          begin
            @lib = fiddle_dlopen(p)
            @dll_path = p
            break
          rescue Exception => e
            @dll_errs << "#{p} -> #{e.class}: #{e.message}"
            next
          end
        end
        if @lib.nil?
          pwd_has = (File.exist?(File.join(Dir.pwd, "steam_api64.dll")) rescue false)
          exe_has = (ed && File.exist?(File.join(ed, "steam_api64.dll"))) ? true : false
          @err = "steam_api64.dll load failed (pwd_has=#{pwd_has} exe_has=#{exe_has} exedir=#{ed.inspect}); #{@dll_errs.join(' | ')}"
          log_once; return false
        end
        if bind_functions && start_steam
          @ok = true
        end
        log_once
        return @ok
      end

      # Absolute directory of the running Game.exe (authoritative even if the
      # process working directory is not the game folder), via GetModuleFileNameW.
      def exe_dir
        require 'fiddle'
        k32 = fiddle_dlopen('kernel32.dll')
        gmf = Fiddle::Function.new(k32['GetModuleFileNameW'],
              [Fiddle::TYPE_VOIDP, Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT], Fiddle::TYPE_INT)
        buf = ("\0" * (520)).b               # 260 wide chars
        n = gmf.call(0, buf, 260).to_i
        return nil if n <= 0
        path = buf[0, n * 2].force_encoding("UTF-16LE").encode("UTF-8") rescue nil
        return nil if path.nil? || path.empty?
        File.dirname(path)
      rescue Exception
        nil
      end

      def func(name, args, ret)
        addr = (@lib[name] rescue nil)
        return nil if addr.nil?
        Fiddle::Function.new(addr, args, ret)
      rescue Exception
        nil
      end

      def bind_functions
        tp = Fiddle::TYPE_VOIDP
        ti = Fiddle::TYPE_INT
        tv = Fiddle::TYPE_VOID
        tc = Fiddle::TYPE_CHAR
        tq = Fiddle::TYPE_LONG_LONG
        @fn[:Init]     = func("SteamAPI_Init",     [],   tc)
        @fn[:InitSafe] = func("SteamAPI_InitSafe", [],   tc)   # legacy bool init, no debug assert
        @fn[:IsRunning]= func("SteamAPI_IsSteamRunning", [], tc)
        @fn[:InitFlat] = func("SteamAPI_InitFlat", [tp], ti)
        @fn[:Shutdown] = func("SteamAPI_Shutdown", [],   tv)
        @fn[:RunCb]    = func("SteamAPI_RunCallbacks", [], tv)   # optional
        @fn[:I_Init]   = func("SteamAPI_ISteamInput_Init",  [tp, ti], tc)
        @fn[:I_Run]    = func("SteamAPI_ISteamInput_RunFrame", [tp, ti], tv)
        @fn[:I_GetCons]= func("SteamAPI_ISteamInput_GetConnectedControllers", [tp, tp], ti)
        @fn[:I_Type]   = func("SteamAPI_ISteamInput_GetInputTypeForHandle", [tp, tq], ti)
        @fn[:I_Vib]    = func("SteamAPI_ISteamInput_TriggerVibration", [tp, tq, ti, ti], tv)
        @fn[:I_VibEx]  = func("SteamAPI_ISteamInput_TriggerVibrationExtended", [tp, tq, ti, ti, ti, ti], tv)
        @fn[:I_Led]    = func("SteamAPI_ISteamInput_SetLEDColor", [tp, tq, ti, ti, ti, ti], tv)
        # Minimum needed for the core job (detection):
        have_init = @fn[:Init] || @fn[:InitSafe] || @fn[:InitFlat]
        unless have_init && @fn[:I_GetCons] && @fn[:I_Type]
          @err = "steam_api64.dll missing expected Steam Input symbols"
          return false
        end
        true
      end

      def truthy_char(r)
        return false if r.nil?
        (r.to_i & 0xFF) != 0
      end

      # Write steam_appid.txt = 480 next to Game.exe if absent (see start_steam).
      def ensure_appid_file!
        @appid_file = File.join(Dir.pwd, "steam_appid.txt")
        return if File.exist?(@appid_file)
        File.open(@appid_file, "w") { |f| f.write("480") }
      rescue Exception
        # read-only working dir etc. -> rely on the env fallback in start_steam
      end

      def steam_api_init
        if @fn[:Init]
          return true if (truthy_char(@fn[:Init].call) rescue false)
        end
        # InitSafe is the same connect path without the debug assert; present
        # on this stock (pre-1.59) steam_api64.dll where InitFlat is not, and it
        # can win if Init's first pass raced the Steam client coming up.
        if @fn[:InitSafe]
          return true if (truthy_char(@fn[:InitSafe].call) rescue false)
        end
        if @fn[:InitFlat]
          buf = ("\0" * 1024).b
          return true if (@fn[:InitFlat].call(buf) rescue 1).to_i == 0   # 0 == k_ESteamAPIInitResult_OK
        end
        false
      end

      # Capture SteamAppId / SteamGameId / SteamOverlayGameId exactly as the Steam
      # launch left them, BEFORE we normalise, so the log shows what a non-Steam
      # shortcut actually provides (the original failure was the classic
      # "no appID found" - Steam set nothing the SDK accepts).
      def snapshot_env!
        %w[SteamAppId SteamGameId SteamOverlayGameId].each do |k|
          @env_before[k] = (ENV[k] rescue nil)
        end
      rescue Exception
      end

      # Pin Valve's public Spacewar id (480) into all three vars up front so the
      # file and the environment can never disagree before the first init: a stale
      # synthetic non-Steam GameID left in the environment can make Steam's
      # ConnectToGlobalUser refuse the 480 we put in steam_appid.txt.
      def normalize_steam_env!
        ENV["SteamAppId"]         = "480"
        ENV["SteamGameId"]        = "480"
        ENV["SteamOverlayGameId"] = "480"
      rescue Exception
      end

      # Best-effort: redirect OS-level stderr (fd 2) across the init call so the
      # classic SDK's "[S_API FAIL] SteamAPI_Init() failed; <reason>." line is
      # captured for the log. Fully self-restoring; if the redirect is unsupported
      # (windowed process with no real fd 2) the block still runs and we just get
      # no extra text.
      def capture_init_reason
        tmp = nil; saved = nil
        begin
          base = (Dir.pwd rescue ".")
          dir  = File.join(base, "Logs")
          (Dir.mkdir(dir) rescue nil) unless File.directory?(dir)
          tmp  = File.join(File.directory?(dir) ? dir : base, "._si_init_err.tmp")
          $stderr.flush rescue nil
          saved = $stderr.dup                 # dup ORIGINAL fd2 first; if this
          redir = File.open(tmp, "w+")        # raises we never touch $stderr
          $stderr.reopen(redir)
          redir.close
        rescue Exception
          saved = nil
        end
        begin
          yield
        ensure
          if saved
            begin
              $stderr.flush rescue nil
              $stderr.reopen(saved)
              saved.close rescue nil
            rescue Exception
            end
          end
        end
        txt = ""
        begin
          txt = (File.read(tmp).to_s rescue "") if tmp
        rescue Exception
        end
        (File.delete(tmp) rescue nil) if tmp
        txt
      end

      def start_steam
        # The shipped game runs as a NON-STEAM shortcut, so Steam injects no
        # SDK-usable SteamAppId ("no appID found"). steam_appid.txt holding Valve's
        # public Spacewar id (480) next to Game.exe is read by SteamAPI_Init with
        # top priority; we ALSO pin the environment to 480 so file and env agree.
        # Both are self-healing.
        @cwd = (Dir.pwd rescue nil)
        snapshot_env!
        ensure_appid_file!
        @appid_ok = (File.exist?(@appid_file) rescue nil) if @appid_file
        normalize_steam_env!

        @steam_running = (truthy_char(@fn[:IsRunning].call) rescue nil) if @fn[:IsRunning]

        reason = (capture_init_reason { @last_init_ok = (steam_api_init rescue false) } rescue "")
        r = reason.to_s.gsub(/\s+/, " ").strip
        m = r[/\[S_API[^\]]*\][^\[]*/i]
        if m
          @init_reason = m.strip[0, 240]
        elsif !r.empty?
          @init_reason = r[0, 240]
        end

        unless @last_init_ok
          @err =
            if @steam_running == false
              "SteamAPI_Init failed: Steam is not detected as running. Start Steam first, and run the game at the SAME admin level as Steam."
            elsif @init_reason
              "SteamAPI_Init failed: #{@init_reason}"
            else
              "SteamAPI_Init failed (launch through Steam with Steam Input on; if it is, run game and Steam at the same admin level)"
            end
          return false
        end

        @iface = resolve_interface
        if @iface == 0
          @err = "SteamInput interface unavailable in this steam_api64.dll"
          (@fn[:Shutdown].call rescue nil)
          return false
        end
        (@fn[:I_Init].call(@iface, 1) rescue nil) if @fn[:I_Init]   # bExplicitlyCallRunFrame
        do_refresh
        @err = nil
        true
      end
      def resolve_interface
        IFACE_VERSIONS.each do |v|
          f = func("SteamAPI_SteamInput_#{v}", [], Fiddle::TYPE_VOIDP)
          next unless f
          ptr  = (f.call rescue nil)
          addr = ptr ? ptr.to_i : 0
          if addr != 0
            @iface_ver = v
            return addr
          end
        end
        0
      end

      #--- frame pump + controller enumeration ------------------------------
      def pump
        (@fn[:I_Run].call(@iface, 1) rescue nil) if @fn[:I_Run] && @iface != 0
        (@fn[:RunCb].call rescue nil) if @fn[:RunCb]
      end

      def do_refresh
        return if @iface == 0 || @fn[:I_GetCons].nil?
        pump
        buf = ("\0" * (INPUT_MAX * HANDLE_BYTES)).b
        n = (@fn[:I_GetCons].call(@iface, buf) rescue 0).to_i
        n = 0 if n < 0
        n = INPUT_MAX if n > INPUT_MAX
        @count = n
        @handles = []
        n.times { |i| @handles << buf[i * HANDLE_BYTES, HANDLE_BYTES].unpack1("Q<") }
        @last_refresh = now_ms
      end

      def refresh_list(force = false)
        return if @iface == 0
        return if !force && (now_ms - @last_refresh) < LIST_THROTTLE_MS
        do_refresh
      end

      def poke
        return unless load!
        refresh_list(false)
      end

      def primary; @handles[0] || 0; end

      # InputHandle_t is uint64; pass the identical bit pattern as a signed 64.
      def s64(x)
        x = x.to_i & 0xFFFFFFFFFFFFFFFF
        x >= 0x8000000000000000 ? x - 0x10000000000000000 : x
      end

      def c16(x); x = x.to_i; x = 0 if x < 0; x = 65535 if x > 65535; x; end
      def c8(x);  x = x.to_i; x = 0 if x < 0; x = 255   if x > 255;   x; end

      #--- public surface mirrored by the SteamHaptics shim below -----------
      def available?
        return false unless load!
        poke
        refresh_list(true) if @count == 0   # Steam Input populates a frame or two after init
        @count > 0 && primary != 0
      end

      def run_frame
        return unless @ok
        do_refresh                       # once per game frame (matches C++ refresh())
      end

      def controller_count
        return 0 unless load!
        poke
        @count
      end

      def controller_type
        return 0 unless load!
        poke
        h = primary
        return 0 if h == 0 || @fn[:I_Type].nil?
        (@fn[:I_Type].call(@iface, s64(h)) rescue 0).to_i
      end

      def rumble(lo, hi)
        return unless @ok
        h = primary; return if h == 0 || @fn[:I_Vib].nil?
        (@fn[:I_Vib].call(@iface, s64(h), c16(lo), c16(hi)) rescue nil)
      end

      def rumble_ex(lo, hi, lt, rt)
        return unless @ok
        h = primary; return if h == 0
        if @fn[:I_VibEx]
          (@fn[:I_VibEx].call(@iface, s64(h), c16(lo), c16(hi), c16(lt), c16(rt)) rescue nil)
        else
          rumble(lo, hi)
        end
      end

      def led(r, g, b)
        return unless @ok
        h = primary; return if h == 0 || @fn[:I_Led].nil?
        (@fn[:I_Led].call(@iface, s64(h), c8(r), c8(g), c8(b), LED_SET_COLOR) rescue nil)
      end

      def led_reset
        return unless @ok
        h = primary; return if h == 0 || @fn[:I_Led].nil?
        (@fn[:I_Led].call(@iface, s64(h), 0, 0, 0, LED_RESTORE) rescue nil)
      end

      # One-shot startup log so a live run can confirm WHY detection did or did not
      # work (ok?/controller count/real type/appid/error). Writes to Logs/.
      def log_once
        return if @logged
        @logged = true
        begin
          base = (Dir.pwd rescue ".")
          dir  = File.join(base, "Logs")
          (Dir.mkdir(dir) rescue nil) unless File.directory?(dir)
          path = File.directory?(dir) ? File.join(dir, "rumble_steaminput.log") : File.join(base, "rumble_steaminput.log")
          t = 0
          begin
            h = (@handles[0] || 0)
            t = (@fn[:I_Type].call(@iface, s64(h)) rescue 0).to_i if @ok && h != 0 && @fn[:I_Type]
          rescue Exception
          end
          File.open(path, "a") do |f|
            f.puts("[#{Time.now}] SteamInput bridge: ok=#{@ok} count=#{@count} iface=#{@iface != 0} ifver=#{@iface_ver.inspect} type=#{t} (13=DualSense,2/3=Xbox) steam_running=#{@steam_running.inspect} dll=#{@dll_path.inspect} appid_now=#{ENV['SteamAppId'].inspect} appid_env_before=#{@env_before.inspect} appid_file=#{@appid_file.inspect} appid_file_ok=#{@appid_ok.inspect} cwd=#{@cwd.inspect} init_reason=#{@init_reason.inspect} err=#{@err.inspect}")
          end
        rescue Exception
        end
      end

      def diagnostics
        load!
        { :ok => @ok, :count => @count, :iface => (@iface != 0),
          :steam_running => @steam_running, :reason => @init_reason, :error => @err }
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Expose the pure-Ruby bridge under the SAME name + contract the native C++ patch
# would register, so 006_RumbleNativeBridge.rb consumes it with ZERO changes.
#-------------------------------------------------------------------------------
module SteamHaptics
  S = Haptics::SteamInputAPI
  def self.available?;                 S.available?;                  end
  def self.run_frame;                  S.run_frame;                   end
  def self.controller_count;           S.controller_count;            end
  def self.controller_type;            S.controller_type;             end
  def self.rumble(lo, hi);             S.rumble(lo, hi);              end
  def self.rumble_ex(lo, hi, lt, rt);  S.rumble_ex(lo, hi, lt, rt);   end
  def self.led(r, g, b);               S.led(r, g, b);                end
  def self.led_reset;                  S.led_reset;                   end
  def self.diagnostics;                S.diagnostics;                 end
end

end # unless defined?(SteamHaptics)

#===============================================================================
# Honest in-game readout: explain WHY it shows Xbox and what to do about it.
# Loaded after 005 (RumbleOptionsScene) and 006 (native_available?/controller_kind),
# so both are defined here. Touching only this new file keeps 005 unchanged.
#===============================================================================
module Haptics
  # Returns a one-line hint for the Test Vibration readout, or nil when no hint
  # is useful (native path working, or a non-Xbox pad already detected directly).
  def self.steam_input_note
    return nil if (native_available? rescue false)        # native path is live -> no note
    k = (controller_kind rescue :unknown)
    return nil unless [:xbox, :xinput].include?(k)        # only the generic Xbox/XInput case
    reason = nil; steam_running = nil
    if defined?(SteamHaptics) && SteamHaptics.respond_to?(:diagnostics)
      d = (SteamHaptics.diagnostics rescue {})
      reason = d[:error]
      steam_running = d[:steam_running]
    end
    if reason && reason.to_s =~ /not found/i
      _INTL("Steam Input is active. Copy steam_api64.dll next to Game.exe to detect your DualSense natively.")
    elsif steam_running == false
      _INTL("Steam isn't detected as running. Launch through Steam (Steam Input on) and run the game at the same admin level as Steam.")
    elsif reason
      _INTL("Steam Input native detect unavailable: {1}", reason.to_s)
    else
      _INTL("If this is a DualSense behind Steam Input, add steam_api64.dll next to Game.exe for native detection.")
    end
  end
end

if defined?(RumbleOptionsScene)
  class RumbleOptionsScene
    unless method_defined?(:_si_orig_rumble_detected_label) ||
           private_method_defined?(:_si_orig_rumble_detected_label)
      alias_method :_si_orig_rumble_detected_label, :rumble_detected_label
      def rumble_detected_label
        base = _si_orig_rumble_detected_label
        note = (Haptics.steam_input_note rescue nil)
        note ? "#{base}\n#{note}" : base
      end
    end

    # Short, always-available explainer of the two DualSense paths, shown as a
    # "Controller Setup Help" button at the bottom of the Controller Vibration page.
    unless method_defined?(:_si_orig_pbGetOptions) ||
           private_method_defined?(:_si_orig_pbGetOptions)
      alias_method :_si_orig_pbGetOptions, :pbGetOptions
      def pbGetOptions(inloadscreen = false)
        opts = _si_orig_pbGetOptions(inloadscreen)
        begin
          opts << ButtonOption.new(_INTL("Controller Setup Help"),
            proc {
              begin
                if defined?(pbMessage)
                  pbMessage(_INTL("DualSense / controller setup:"))
                  pbMessage(_INTL("Steam Input OFF (DualSense plugged in directly): it's detected as a DualSense and rumbles automatically - no extra files."))
                  pbMessage(_INTL("Steam Input ON (KIF as a non-Steam game): the game is handed a virtual Xbox pad. To get native DualSense rumble, trigger motors and lightbar, put your own steam_api64.dll (from any Steam game you own) next to Game.exe."))
                  pbMessage(_INTL("Xbox and other XInput controllers always work as-is."))
                end
              rescue
              end
            },
            _INTL("How to get DualSense rumble / lightbar, with or without Steam Input."),
            _INTL("Help"))
        rescue
        end
        opts
      end
    end
  end
end
