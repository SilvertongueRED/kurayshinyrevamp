#===============================================================================
# Controller Vibration / Rumble  -  CORE ENGINE
#-------------------------------------------------------------------------------
# Pure-Ruby rumble for KIF. Drives the controller's two vibration motors through
# Windows XInput (XInputSetState) via the engine's Win32API binding. No engine
# recompile required.
#
#   * LOW  motor (left)  = heavy / low-frequency rumble  -> "body / bass"
#   * HIGH motor (right) = light / high-frequency buzz   -> "texture / treble"
#
# Works on any XInput controller: Xbox pads natively, and a DualSense/DS4 when
# it is presented through Steam Input or DS4Windows (XInput mode) - which is the
# usual configuration when launching from Steam. On platforms without Win32API
# (Linux/Mac) or with no XInput pad present, every call degrades to a safe no-op.
#
# A pattern is an Array of steps:  [ low(0.0..1.0), high(0.0..1.0), duration_ms ]
# The scheduler is time-sliced and advanced once per frame from Graphics.update,
# so it never blocks the game loop.
#===============================================================================
module Haptics
  DLL_CANDIDATES = ["xinput1_4", "xinput1_3", "xinput9_1_0"]

  @init_done    = false   # backend probed yet?
  @backend_ok   = false   # Win32API + an XInput DLL available?
  @xi_set       = nil     # Win32API XInputSetState
  @xi_get       = nil     # Win32API XInputGetState
  @pad_index    = nil     # active XInput slot 0..3, or nil
  @last_scan_ms = -100000.0

  # Scheduler state
  @queue        = nil
  @active       = false
  @cur_priority = 0
  @step_end     = 0.0
  @applied_lo   = -1
  @applied_hi   = -1

  PAD_RESCAN_INTERVAL_MS = 4000.0

  #--- time ---------------------------------------------------------------------
  def self.now_ms
    return Time.now.to_f * 1000.0
  end

  #--- settings readers (defensive; nil/old-save => sensible default) -----------
  def self.system
    return (defined?($PokemonSystem) ? $PokemonSystem : nil)
  end

  def self.master_on?
    s = system
    return true unless s
    v = (s.rumble_master rescue nil)
    return v.nil? ? true : (v == 0)   # 0 = On, 1 = Off
  end

  def self.intensity
    s = system
    return 70 unless s
    v = (s.rumble_intensity rescue nil)
    v = 70 if v.nil?
    v = 0 if v < 0
    v = 100 if v > 100
    return v
  end

  def self.category_on?(cat)
    s = system
    return true unless s
    v = case cat
        when :battle      then (s.rumble_cat_battle rescue nil)
        when :overworld   then (s.rumble_cat_overworld rescue nil)
        when :encounters  then (s.rumble_cat_encounters rescue nil)
        else 0
        end
    return v.nil? ? true : (v == 0)
  end

  #--- backend ------------------------------------------------------------------
  def self.init_backend
    @init_done = true
    @backend_ok = false
    return unless defined?(Win32API)
    DLL_CANDIDATES.each do |dll|
      begin
        set_fn = Win32API.new(dll, "XInputSetState", ["l", "p"], "l")
        get_fn = Win32API.new(dll, "XInputGetState", ["l", "p"], "l")
        # Probe: a working DLL returns an Integer (0 connected / 1167 not).
        probe = get_fn.call(0, "\0" * 16)
        if probe.is_a?(Integer)
          @xi_set = set_fn
          @xi_get = get_fn
          @backend_ok = true
          break
        end
      rescue
        next
      end
    end
    scan_pad(true) if @backend_ok
  end

  # Find the first connected XInput slot. Throttled unless force=true.
  def self.scan_pad(force = false)
    return @pad_index unless @backend_ok
    t = now_ms
    return @pad_index if !force && (t - @last_scan_ms) < PAD_RESCAN_INTERVAL_MS
    @last_scan_ms = t
    found = nil
    (0..3).each do |i|
      begin
        found = i if @xi_get.call(i, "\0" * 16) == 0
      rescue
        found = nil
      end
      break if found
    end
    @pad_index = found
    return @pad_index
  end

  def self.ready?
    init_backend unless @init_done
    return false unless @backend_ok
    scan_pad(false) if @pad_index.nil?
    return !@pad_index.nil?
  end

  #--- low level motor write ----------------------------------------------------
  def self.set_motors(low01, high01)
    return unless @backend_ok
    idx = @pad_index
    return if idx.nil?
    scale = intensity.to_f / 100.0
    lo = (low01.to_f  * scale * 65535.0).round
    hi = (high01.to_f * scale * 65535.0).round
    lo = 0 if lo < 0; lo = 65535 if lo > 65535
    hi = 0 if hi < 0; hi = 65535 if hi > 65535
    return if lo == @applied_lo && hi == @applied_hi
    @applied_lo = lo
    @applied_hi = hi
    begin
      res = @xi_set.call(idx, [lo, hi].pack("vv"))
      if res != 0
        # Controller went away - force a rescan on the next opportunity.
        @pad_index  = nil
        @applied_lo = -1
        @applied_hi = -1
      end
    rescue
      @pad_index = nil
    end
  end

  def self.stop
    @queue = nil
    @active = false
    @cur_priority = 0
    set_motors(0.0, 0.0)
  end

  #--- public: schedule a pattern ----------------------------------------------
  # category : :battle / :overworld / :encounters / nil (always, e.g. Test)
  # priority : higher wins; a lower-priority request is ignored while a higher
  #            one is still playing (so a footstep never stomps a boss cue).
  def self.play(pattern, category = nil, priority = 2)
    return unless master_on?
    return if category && !category_on?(category)
    return if pattern.nil? || pattern.empty?
    return unless ready?
    return if @active && priority < @cur_priority
    @queue = pattern.map { |s| s.dup }
    @cur_priority = priority
    @active = true
    advance_step(now_ms)   # start immediately for responsiveness
  end

  def self.advance_step(t)
    if @queue.nil? || @queue.empty?
      set_motors(0.0, 0.0)
      @active = false
      @cur_priority = 0
      return
    end
    step = @queue.shift
    set_motors(step[0], step[1])
    @step_end = t + (step[2] || 0).to_f
  end

  #--- public: per-frame tick (called from Graphics.update) ----------------------
  def self.tick
    return unless @init_done            # don't probe from the render thread
    return unless @backend_ok
    if @active
      t = now_ms
      advance_step(t) if t >= @step_end
    end
  end

  #--- public: settings test button --------------------------------------------
  def self.test
    init_backend unless @init_done
    Haptics::Patterns.respond_to?(:test) ? play(Haptics::Patterns.test, nil, 9) : nil
  end

  # Boot self-diagnostic: fires once a frame after load, on EVERY launch, so a
  # fresh rumble log always lands without needing a Test press. Proves the
  # 691_Rumble folder actually loaded on this build + forces HID/Steam probes.
  def self._boot_diag_once
    return if @boot_diag_done
    @boot_diag_done = true
    begin
      base = (Dir.pwd rescue "."); dir = File.join(base, "Logs")
      (Dir.mkdir(dir) rescue nil) unless File.directory?(dir)
      File.open(File.join(dir, "rumble_boot.log"), "a") do |f|
        f.puts("[#{Time.now}] rumble boot: 691 loaded; backend_ok=#{@backend_ok.inspect} pad=#{@pad_index.inspect} " +
               "HID=#{defined?(Haptics::HID) ? 'yes' : 'NO'} Steam=#{defined?(SteamHaptics) ? 'yes' : 'NO'} " +
               "native=#{(native_available? rescue '?')} kind=#{(controller_kind rescue '?')}")
      end
    rescue Exception
    end
    # force fresh detection logs (no rumble write at boot - that stays on the Test button)
    (Haptics::HID.test_probe!(false) rescue nil) if defined?(Haptics::HID)
    (SteamHaptics.available? rescue nil) if defined?(SteamHaptics)
  end

  def self.diagnostics
    init_backend unless @init_done
    return {
      :win32api   => (defined?(Win32API) ? true : false),
      :backend_ok => @backend_ok,
      :pad_index  => @pad_index
    }
  end
end

#-------------------------------------------------------------------------------
# Per-frame pump. Graphics.update runs in every game loop (overworld, battle,
# menus, transitions), making it the one universal, always-available tick. The
# work done per frame is O(1) and fully rescued, so it can never affect drawing.
#-------------------------------------------------------------------------------
module Graphics
  class << self
    unless respond_to?(:_rumble_orig_update)
      alias_method :_rumble_orig_update, :update
      def update(*args, &blk)
        _rumble_orig_update(*args, &blk)
        Haptics.tick rescue nil
        Haptics._boot_diag_once rescue nil
      end
    end
  end
end
