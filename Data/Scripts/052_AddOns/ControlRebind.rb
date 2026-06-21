#===============================================================================
# Controller-navigable Control Rebinding                  [ControlRebind.rb]
#===============================================================================
# The engine (mkxp-z) exposes no Ruby API to change real key/gamepad bindings
# (its native F1 menu owns those and is not controller-navigable). This adds a
# SAFE Ruby-side remap layer instead: each game action button can be made to read
# from a different logical button.
#
# It ALSO adds optional Multiplayer hotkey bindings: assign a spare controller
# button -- OR a keyboard key / mouse button -- to an MP function (Squad, Player
# List, Chat, GTS, Cases, Profile, Min/Max HUD) so players can reach those
# without the fixed F-keys. Both layers are opt-in (identity / unbound by
# default) so there is ZERO behaviour change until used.
#
# Keyboard / mouse MP bindings are polled with GetAsyncKeyState (the same Win32
# path the F3/F4 hotkeys already use), so e.g. F9 can be assigned to Min/Max HUD.
#
# NOTE ON THE D-PAD: mkxp-z reports the controller D-pad and the analog stick as
# the SAME logical directions (Up/Down/Left/Right) and exposes no Ruby API to
# read the raw hat, so the D-pad cannot be made an INDIVIDUALLY assignable source
# here. The engine's native F1 "Key bindings" menu DOES list Pad Up/Pad Down/Pad
# Left/Pad Right as separate slots -- that is the only place the D-pad can be
# bound on its own.
#
# Safety:
#   * Identity by default -> ZERO behaviour change until you actually rebind.
#   * MP bindings default to unbound; movement (d-pad/stick) is never assignable
#     so walking can never break.
#   * Always-available "Reset to defaults".
#   * The rebind screen reads RAW input (bypass) so a remap can never lock you
#     out of the rebind screen itself.
#   * Every path is rescued so input can never crash.
#
# Reached from the (already controller-navigable) Options menu -> "Rebind
# Controls". Persists to control_bindings.txt in the game folder.
#===============================================================================

module ControlRebind
  @bypass = false
  @remap  = {}
  @mp_kb  = {}
  @mp_pad = {}
  @pad_bind = {}
  @vk_last = {}
  @trig_down = nil
  @trig_edge = {}
  @trig_suppress_cancel = false
  @phys_prev = nil
  @phys_down = {}
  @phys_edge = {}

  #-----------------------------------------------------------------------------
  # Win32 raw key/mouse reader (for keyboard + mouse MP bindings). nil on
  # platforms without Win32API (then keyboard/mouse bindings simply never fire).
  #-----------------------------------------------------------------------------
  begin
    GetAsyncKeyState        = Win32API.new('user32', 'GetAsyncKeyState', ['i'], 'i')
    GetForegroundWindow     = Win32API.new('user32', 'GetForegroundWindow', [], 'i')
    GetWindowThreadProcessId = Win32API.new('user32', 'GetWindowThreadProcessId', ['i', 'p'], 'i')
  rescue
    GetAsyncKeyState = nil
    GetForegroundWindow = nil
    GetWindowThreadProcessId = nil
  end

  # --- XInput physical controller read (for Action-row hold-to-bind) -----------
  # The rebind screen reads the engine's LOGICAL buttons, which are already mapped
  # THROUGH keybindings.mkxp1 -- so a held pad button reports as whatever it is
  # currently bound to, not which physical button it is. To let "Confirm then hold
  # a button" capture the REAL pad button (and write its SDL index into the F1
  # keybindings), we read the physical button bitmask straight from XInput, the
  # same Win32API path the rumble engine uses. nil / no-op if unavailable.
  begin
    _xi_get = nil
    ["xinput1_4", "xinput1_3", "xinput9_1_0"].each do |dll|
      begin
        fn = Win32API.new(dll, "XInputGetState", ["l", "p"], "l")
        probe = fn.call(0, "\0" * 16)
        if probe.is_a?(Integer); _xi_get = fn; break; end
      rescue
        next
      end
    end
    XInputGetState = _xi_get
  rescue
    XInputGetState = nil
  end

  # --- winmm joystick read (for a DirectInput-class pad like a DualSense that is
  # NOT going through Steam Input / XInput) -------------------------------------
  # XInput only sees XInput devices (Xbox pads, or the virtual pad Steam Input
  # presents). A DualSense connected directly is invisible to XInput, so its
  # face / shoulder / Select buttons never reach the Action-row capture. winmm's
  # joyGetPosEx reads ANY connected joystick via a simple struct with no
  # recompile -- the same Win32API approach the rest of this file uses. nil/no-op
  # if unavailable.
  begin
    JoyGetPosEx   = Win32API.new('winmm', 'joyGetPosEx',   ['i', 'p'], 'i')
    JoyGetNumDevs = Win32API.new('winmm', 'joyGetNumDevs', [],         'i')
  rescue
    JoyGetPosEx = nil; JoyGetNumDevs = nil
  end

  # XInput wButtons bit -> SDL game-controller button index (matches KB_CBTN_CATALOG).
  XINPUT_TO_SDL = {
    0x1000 => 0,  0x2000 => 1,  0x4000 => 2,  0x8000 => 3,    # A B X Y
    0x0020 => 4,  0x0400 => 5,  0x0010 => 6,                  # Back Guide Start
    0x0040 => 7,  0x0080 => 8,                                # L-Stick R-Stick
    0x0100 => 9,  0x0200 => 10,                               # L-Btn R-Btn
    0x0001 => 11, 0x0002 => 12, 0x0004 => 13, 0x0008 => 14    # D-pad U/D/L/R
  } unless const_defined?(:XINPUT_TO_SDL)

  # wButtons bitmask of the first connected XInput pad (focused window only), or nil.
  def self.xinput_buttons
    fn = (XInputGetState rescue nil)
    return nil unless fn
    return nil unless window_active?
    (0..3).each do |i|
      buf = "\0" * 16
      next unless (fn.call(i, buf) rescue 1167) == 0
      # XINPUT_STATE = dwPacketNumber(4) + GAMEPAD{ wButtons(2) ... }
      return buf[4, 2].unpack("S<")[0]
    end
    nil
  rescue
    nil
  end

  # SDL index of a single physical pad button being held (XInput). Face / shoulder
  # / stick / Start / Back / Guide are checked before the D-pad. nil if none.
  def self.xinput_held_sdl
    bits = xinput_buttons
    return nil if bits.nil? || bits == 0
    [0x1000, 0x2000, 0x4000, 0x8000, 0x0010, 0x0020, 0x0100, 0x0200,
     0x0040, 0x0080, 0x0400, 0x0001, 0x0002, 0x0004, 0x0008].each do |bit|
      return XINPUT_TO_SDL[bit] if (bits & bit) != 0
    end
    nil
  rescue
    nil
  end

  # DualSense / DualShock DirectInput button order -> SDL game-controller index
  # (the index keybindings.mkxp1 and KB_CBTN_CATALOG use). Only reached when no
  # XInput device is present, so a PlayStation-style layout is the safe default
  # (an Xbox pad would have been read through XInput instead). L2/R2-as-button and
  # the touchpad click have no SDL button and are intentionally dropped.
  WINMM_DINPUT_TO_SDL = {
    0 => 2,    # Square        -> X (West face)
    1 => 0,    # Cross         -> A (South face)
    2 => 1,    # Circle        -> B (East face)
    3 => 3,    # Triangle      -> Y (North face)
    4 => 9,    # L1            -> L-Shoulder
    5 => 10,   # R1            -> R-Shoulder
    8 => 4,    # Share/Create  -> Back  (this is the "Select" button)
    9 => 6,    # Options       -> Start
    10 => 7,   # L3            -> L-Stick click
    11 => 8,   # R3            -> R-Stick click
    12 => 5    # PS            -> Guide
  } unless const_defined?(:WINMM_DINPUT_TO_SDL)

  # SDL index of the controller "Select" button (Back / View / DualSense Create),
  # the one opposite Start. Always wired to the HUD min/max toggle.
  SELECT_SDL = 4 unless const_defined?(:SELECT_SDL)

  # Set {sdl_index => true} of buttons physically held on the first connected
  # winmm joystick (DualSense fallback). Includes the POV hat as the D-pad.
  def self.winmm_held_sdl_set
    fn = (JoyGetPosEx rescue nil)
    return {} unless fn
    return {} unless window_active?
    nd = (JoyGetNumDevs.call rescue 0)
    return {} if nd.nil? || nd <= 0
    (0...nd).each do |id|
      # JOYINFOEX (13 DWORDs): dwSize=52, dwFlags=JOY_RETURNBUTTONS|JOY_RETURNPOV.
      buf = [52, 0xC0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0].pack("L13")
      res = (fn.call(id, buf) rescue 1)
      next unless res == 0   # JOYERR_NOERROR
      v       = buf.unpack("L13")
      buttons = v[8]
      pov     = v[10]
      set = {}
      WINMM_DINPUT_TO_SDL.each { |din, sdl| set[sdl] = true if (buttons & (1 << din)) != 0 }
      if pov && pov >= 0 && pov <= 36000 && pov != 0xFFFF
        set[11] = true if pov >= 31500 || pov <= 4500    # Up
        set[14] = true if pov >= 4500  && pov <= 13500   # Right
        set[12] = true if pov >= 13500 && pov <= 22500   # Down
        set[13] = true if pov >= 22500 && pov <= 31500   # Left
      end
      return set
    end
    {}
  rescue
    {}
  end

  # Single physical SDL button held via winmm (face / shoulder / Select before
  # the D-pad). nil if none. Used by the Action-row capture fallback.
  def self.winmm_held_sdl
    set = winmm_held_sdl_set
    return nil if set.nil? || set.empty?
    [0, 1, 2, 3, 4, 6, 9, 10, 7, 8, 5, 11, 12, 13, 14].each { |sdl| return sdl if set[sdl] }
    nil
  rescue
    nil
  end

  # Unified set of physically-held SDL buttons this frame. On the BARE EXE a
  # directly-connected DualSense is invisible to XInput AND winmm, so the raw-HID
  # reader (ControllerHIDInput) is the ONLY source that sees it and is tried
  # FIRST. Falls back to XInput (Xbox / Steam Input virtual pad) then winmm -- this
  # is what makes the D-pad, Select and face buttons bindable on the bare exe.
  def self.phys_held_sdl_set
    if defined?(ControllerHIDInput)
      (ControllerHIDInput.ensure_started rescue nil)
      return ((ControllerHIDInput.sdl_set rescue {}) || {}) if (ControllerHIDInput.active? rescue false)
    end
    bits = xinput_buttons
    unless bits.nil?
      set = {}
      XINPUT_TO_SDL.each { |bit, sdl| set[sdl] = true if (bits & bit) != 0 }
      return set
    end
    winmm_held_sdl_set
  rescue
    {}
  end

  # Per-frame physical-pad latch (called once per Input.update from the global
  # frame hook). Derives a rising edge per SDL button from the held level so a
  # Ruby-side pad binding fires exactly once per press. Dormant during the rebind
  # menu (@bypass): the capture screen reads the pad directly instead.
  def self.phys_poll!
    @phys_edge = {}
    @trig_edge = { :lt => false, :rt => false }
    # Cache the trigger->Cancel suppression BEFORE the bypass early-out so it stays
    # fresh inside the rebind menu / diagnostic too (both set @bypass).
    @trig_suppress_cancel = compute_trigger_suppresses_cancel
    if @bypass
      @phys_prev = nil   # re-prime on resume so a held button can't fake an edge
      @trig_down = nil
      return
    end
    cur = phys_held_sdl_set || {}
    if @phys_prev.nil? || @trig_down.nil?
      @phys_prev = cur; @phys_down = cur
      lr = trigger_raw
      @trig_down  = { :lt => (lr[0].to_i > TRIG_PRESS) || trigger_eng_held?(:lt) || winmm_trigger_held?(:lt),
                      :rt => (lr[1].to_i > TRIG_PRESS) || trigger_eng_held?(:rt) || winmm_trigger_held?(:rt) }
      @trig_armed = { :lt => !@trig_down[:lt], :rt => !@trig_down[:rt] }
      @trig_up    = { :lt => 0, :rt => 0 }
      return             # prime: no edges on the first frame after a (re)start
    end
    cur.each_key { |sdl| @phys_edge[sdl] = true unless @phys_prev[sdl] }
    @phys_down = cur
    @phys_prev = cur
    # Trigger held = raw-HID analog past threshold (hysteresis) OR the engine button
    # the trigger is mapped to (L2->F5, R2->F9). Fire ONCE per pull; re-arm only
    # after a sustained release so engine auto-repeat can't double-toggle.
    lr = trigger_raw
    @trig_armed ||= { :lt => true, :rt => true }
    @trig_up    ||= { :lt => 99,   :rt => 99 }
    [[:lt, lr[0].to_i], [:rt, lr[1].to_i]].each do |which, v|
      analog = @trig_down[which] ? (v > TRIG_RELEASE) : (v > TRIG_PRESS)
      held   = analog || trigger_eng_held?(which) || winmm_trigger_held?(which)
      @trig_down[which] = held
      if held
        @trig_edge[which]  = true if @trig_armed[which]
        @trig_armed[which] = false
        @trig_up[which]    = 0
      else
        @trig_up[which]   += 1
        @trig_armed[which] = true if @trig_up[which] >= TRIG_RELEASE_SUSTAIN
      end
    end
  rescue
    @phys_edge = {}
    @trig_edge = { :lt => false, :rt => false }
  end

  def self.phys_down?(sdl)
    (@phys_down || {})[sdl] ? true : false
  rescue
    false
  end

  def self.phys_edge?(sdl)
    (@phys_edge || {})[sdl] ? true : false
  rescue
    false
  end

  # --- Analog trigger (LT/RT) reading -----------------------------------------
  # On the bare exe the DualSense triggers are ONLY readable via raw HID (the
  # engine maps them to stray logical buttons; XInput/winmm are blind). Under
  # Steam Input the virtual pad exposes them through XInput instead, so we read
  # raw HID first and fall back to XInput. The 0-255 analog value is thresholded
  # into a digital press with hysteresis so a bound trigger fires once per pull
  # and never chatters at the boundary.
  TRIG_PRESS   = 80 unless const_defined?(:TRIG_PRESS)    # rise above -> pressed
  TRIG_RELEASE = 40 unless const_defined?(:TRIG_RELEASE)  # fall below -> released
  # Frames a trigger must read RELEASED before its edge re-arms. Stops the engine's
  # mid-hold auto-repeat (raw SDL pad drops press? ~20f then re-fires) from making
  # one pull toggle Chat/Profile twice.
  TRIG_RELEASE_SUSTAIN = 8 unless const_defined?(:TRIG_RELEASE_SUSTAIN)

  def self.xinput_triggers
    fn = (XInputGetState rescue nil)
    return nil unless fn
    return nil unless window_active?
    (0..3).each do |i|
      buf = "\0" * 16
      next unless (fn.call(i, buf) rescue 1167) == 0
      return [buf[6, 1].unpack("C")[0].to_i, buf[7, 1].unpack("C")[0].to_i]
    end
    nil
  rescue
    nil
  end

  # Raw [L2, R2] analog values, 0-255. [0,0] when no pad is readable.
  def self.trigger_raw
    if defined?(ControllerHIDInput)
      (ControllerHIDInput.ensure_started rescue nil)
      return ((ControllerHIDInput.triggers rescue [0, 0]) || [0, 0]) if (ControllerHIDInput.active? rescue false)
    end
    xinput_triggers || [0, 0]
  rescue
    [0, 0]
  end

  # Are the DualSense/DualShock TRIGGERS (L2/R2) physically held, read via winmm
  # (DirectInput): button index 6 = L2, 7 = R2. On the BARE EXE this is the ONLY
  # reader that sees the triggers (raw-HID won't open the device, XInput is blind),
  # and winmm reports L2/R2 as digital buttons -- PROVEN by the Controller
  # Diagnostic, whose winmm read this now mirrors EXACTLY: probe up to 16 slots even
  # when joyGetNumDevs returns 0, JOY_RETURNALL (0xFF), and no foreground gate. Only
  # gated by XInput-present: with a Steam-Input / Xbox virtual pad live its DInput
  # buttons 6/7 are Back/Start (NOT L2/R2), so we defer to the analog trigger_raw
  # path there. Returns { :lt => bool, :rt => bool }.
  def self.winmm_trigger_set
    return { :lt => false, :rt => false } unless xinput_buttons.nil?
    fn = (JoyGetPosEx rescue nil)
    return { :lt => false, :rt => false } unless fn
    nd = (JoyGetNumDevs.call rescue 0)
    nd = 16 if nd.nil? || nd <= 0
    (0...nd).each do |id|
      buf = [52, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0].pack("L13")
      next unless (fn.call(id, buf) rescue 1) == 0
      b = buf.unpack("L13")[8]
      return { :lt => ((b & (1 << 6)) != 0), :rt => ((b & (1 << 7)) != 0) }
    end
    { :lt => false, :rt => false }
  rescue
    { :lt => false, :rt => false }
  end

  def self.winmm_trigger_held?(which)
    s = winmm_trigger_set
    which == :rt ? s[:rt] : s[:lt]
  rescue
    false
  end

  # Is the engine logical button a trigger is mapped to currently held? After the
  # keybinding migration L2 -> F5 and R2 -> F9, so a trigger PULL reads as F5/F9 at
  # the engine level (reliable on the bare exe, unlike raw HID). Read the engine's
  # own press? (pre-remap); F5/F9 are never remapped, so this is clean.
  def self.trigger_eng_held?(which)
    btn = (which == :rt ? (defined?(Input::F9) ? Input::F9 : nil)
                        : (defined?(Input::F5) ? Input::F5 : nil))
    return false unless btn
    if Input.respond_to?(:_rebind_orig_press?)
      Input._rebind_orig_press?(btn) ? true : false
    else
      Input.press?(btn) ? true : false
    end
  rescue
    false
  end

  # Live (un-latched) held state of a trigger -- used by the rebind capture screen.
  # True if the raw-HID analog is past threshold OR the engine F5/F9 button (the
  # migrated trigger mapping) is held.
  def self.trigger_down?(which)
    lr = trigger_raw
    v  = (which == :rt ? lr[1] : lr[0]).to_i
    (v > TRIG_PRESS) || trigger_eng_held?(which) || winmm_trigger_held?(which)
  rescue
    false
  end

  # Rising edge of a trigger THIS frame (computed in phys_poll!).
  def self.trigger_edge?(which)
    (@trig_edge || {})[which] ? true : false
  rescue
    false
  end

  # Cached once per frame (phys_poll!): should the spurious engine Cancel that a
  # pulled trigger generates be swallowed? True only while a trigger is pulled AND
  # the real Cancel button (Circle / Pad B) is NOT physically held.
  def self.compute_trigger_suppresses_cancel
    lt = 0; rt = 0; cancel_held = false
    if defined?(ControllerHIDInput) && (ControllerHIDInput.active? rescue false)
      lr = (ControllerHIDInput.triggers rescue [0, 0]) || [0, 0]
      lt = lr[0].to_i; rt = lr[1].to_i
      set = (ControllerHIDInput.sdl_set rescue {}) || {}
      cancel_held = set[1] ? true : false   # SDL_B (Circle) == real Cancel
    else
      xi = xinput_triggers
      return false unless xi
      lt = xi[0].to_i; rt = xi[1].to_i
      bits = xinput_buttons
      cancel_held = (bits && (bits & 0x2000) != 0) ? true : false   # XInput B
    end
    return false unless (lt > 30 || rt > 30)
    !cancel_held
  rescue
    false
  end

  def self.trigger_suppresses_cancel?
    @trig_suppress_cancel ? true : false
  rescue
    false
  end

  def self.window_active?
    gfw = (GetForegroundWindow rescue nil)
    gwt = (GetWindowThreadProcessId rescue nil)
    return true unless gfw && gwt
    foreground = gfw.call
    return true if foreground == 0
    pid_buf = [0].pack('L')
    gwt.call(foreground, pid_buf)
    foreground_pid = pid_buf.unpack('L')[0]
    foreground_pid == Process.pid
  rescue
    true
  end

  # True only on the FRAME the VK transitions from up to down (edge), and only
  # when the game window is focused (so a key typed into another app is ignored).
  def self.vk_edge?(vk)
    gaks = (GetAsyncKeyState rescue nil)
    return false unless gaks
    return false unless window_active?
    down = (gaks.call(vk) & 0x8000) != 0
    @vk_last ||= {}
    was = @vk_last[vk] || false
    @vk_last[vk] = down
    down && !was
  rescue
    false
  end

  # The 8 remappable logical buttons (each game action IS one of these).
  def self.buttons
    [Input::C, Input::B, Input::A, Input::X, Input::Y, Input::Z, Input::L, Input::R]
  end

  # Controller TRIGGERS (LT/RT). mkxp has no default binding for the analog
  # triggers, so the player maps them to spare RGSS buttons via the engine F1
  # "Key Bindings" menu: Left Trigger -> F5, Right Trigger -> F9 (the only two
  # function buttons not already used by GTS(F6)/Cases(F7)/Screenshot(F8) and
  # only debug-used for F9). We then expose them as assignable "LT"/"RT" sources.
  # Guarded: a missing constant just drops that trigger (no crash).
  def self.trigger_sources
    @trigger_sources ||= begin
      list = []
      list << [Input::F5, "Aux 1"] if defined?(Input::F5)
      list << [Input::F9, "Aux 2"] if defined?(Input::F9)
      list
    rescue
      []
    end
  end

  def self.trigger_buttons
    trigger_sources.map { |b, _l| b }
  end

  # Sources a player may assign to an action: the 8 action buttons PLUS the four
  # d-pad/stick directions, so the d-pad can be bound too (Left/Right cycles
  # through this whole list in the rebind screen).
  def self.assignable_sources
    buttons + [Input::UP, Input::DOWN, Input::LEFT, Input::RIGHT] + trigger_buttons
  end

  # Action rows for the UI: [logical_button, friendly_label]
  def self.actions
    [
      [Input::C, _INTL("Confirm (USE)")],
      [Input::B, _INTL("Cancel / Menu")],
      [Input::A, _INTL("MP Actions/Run")],
      [Input::X, _INTL("Button X")],
      [Input::Y, _INTL("Button Y")],
      [Input::Z, _INTL("Menu (Z)")],
      [Input::L, _INTL("Aux L")],
      [Input::R, _INTL("Aux R")]
    ]
  end

  # Plain-language description of what each action button does in-game. Shown at
  # the bottom of the rebind screen for the highlighted row.
  def self.action_descriptions
    {
      Input::C => _INTL("CONFIRM / USE: the main \"yes\" button -- talk, advance text, pick menu items, and confirm in every menu. In Multiplayer menus the MP Actions/Run button confirms too."),
      Input::B => _INTL("CANCEL / BACK: backs out of menus; opens the pause menu in the overworld. HOLD ~0.5s from any menu to instantly exit ALL menus to the overworld."),
      Input::A => _INTL("MP ACTIONS / RUN: hold to run in the overworld; ALSO the Confirm button inside the Multiplayer menus (Squad, Player List, GTS, Cases, Profile), plus a secondary key in Pokedex/Party/Summary/Bag."),
      Input::X => _INTL("Spare button. No core default; used by some menus/mods."),
      Input::Y => _INTL("Spare button. No core default; used by some menus/mods."),
      Input::Z => _INTL("Auxiliary menu button used by some screens."),
      Input::L => _INTL("Page left: previous page/box in PC, Pokedex, party, etc."),
      Input::R => _INTL("Page right: next page/box in PC, Pokedex, party, etc.")
    }
  end

  #-----------------------------------------------------------------------------
  # Multiplayer hotkey actions. Each can be bound to a spare controller button,
  # a keyboard key, or a mouse button so it works without the fixed F-keys.
  #-----------------------------------------------------------------------------
  def self.mp_actions
    [
      [:squad,   _INTL("MP: Squad menu")],
      [:players, _INTL("MP: Player list")],
      [:chat,    _INTL("MP: Chat")],
      [:gts,     _INTL("MP: GTS")],
      [:cases,   _INTL("MP: Cases")],
      [:profile, _INTL("MP: Profile")],
      [:hud,     _INTL("MP: Min/Max HUD")]
    ]
  end

  def self.mp_action_descriptions
    {
      :squad   => _INTL("Open/close the Squad menu (co-op party)."),
      :players => _INTL("Open/close the online Player List."),
      :chat    => _INTL("Open/close the chat window (F10 by default; Left Trigger on a controller). The T key only starts typing a message -- it never opens or closes chat."),
      :gts     => _INTL("Open the Global Trade System."),
      :cases   => _INTL("Open the Cases menu."),
      :profile => _INTL("Toggle your own Profile card (F8 by default; Right Trigger on a controller)."),
      :hud     => _INTL("Minimise / maximise the multiplayer HUD and chat. The controller Select button (opposite Start) always does this too.")
    }
  end

  # Keyboard / mouse sources assignable to an MP action. Each is [token, label, VK].
  # token is what we store in control_bindings.txt (prefixed "K:" on disk).
  def self.key_sources
    @key_sources ||= begin
      list = []
      # Function keys F1..F12 (VK 0x70..0x7B)
      (1..12).each { |n| list << ["F#{n}", "F#{n}", 0x6F + n] }
      # Handy extra keys
      list << ["Tab",   "Tab",   0x09]
      list << ["Grave", "`",     0xC0]
      list << ["Insert","Insert",0x2D]
      list << ["Delete","Delete",0x2E]
      list << ["Home",  "Home",  0x24]
      list << ["End",   "End",   0x23]
      list << ["PgUp",  "PgUp",  0x21]
      list << ["PgDn",  "PgDn",  0x22]
      # Mouse buttons (left/right are gameplay; middle + 2 side buttons are spare)
      list << ["Mouse3","Mouse3",0x04]  # middle
      list << ["Mouse4","Mouse4",0x05]  # X1 / back
      list << ["Mouse5","Mouse5",0x06]  # X2 / forward
      # Letters A-Z and digits 0-9 so ANY keyboard key can be bound (the rebind
      # screen captures whatever is held). Tokens are the bare character.
      ("A".."Z").each { |c| list << [c, c, c.ord] }            # VK 0x41..0x5A
      (0..9).each      { |n| list << [n.to_s, n.to_s, 0x30 + n] }  # VK 0x30..0x39
      list
    end
  end

  def self.key_token_for(tok)
    key_sources.find { |t, _l, _vk| t == tok }
  end

  # ---- Dual MP bindings: each hotkey has an independent KEYBOARD slot and
  # CONTROLLER slot, both live at once. Keyboard slot = a key/mouse token (String).
  # Controller slot = an SDL pad-button index (Integer) OR :lt/:rt for the analog
  # triggers. Confirm (Pad A=0) / Cancel (Pad B=1, Start=6) are never offered as
  # pad sources so core navigation can't be hijacked. The D-pad is read off the
  # PHYSICAL hat via raw HID, distinct from the analog stick used to walk. -------
  MP_PAD_SDL_ALLOWED = [11, 12, 13, 14, 2, 3, 9, 10, 4, 5, 7, 8] unless const_defined?(:MP_PAD_SDL_ALLOWED)

  MP_PAD_LABELS = {
    0 => "Pad A", 1 => "Pad B", 2 => "Pad X", 3 => "Pad Y", 4 => "Select",
    5 => "Guide", 6 => "Start", 7 => "L-Stick", 8 => "R-Stick", 9 => "L1",
    10 => "R1", 11 => "D-Up", 12 => "D-Down", 13 => "D-Left", 14 => "D-Right"
  } unless const_defined?(:MP_PAD_LABELS)

  def self.mp_kb;  @mp_kb  ||= {}; end
  def self.mp_pad; @mp_pad ||= {}; end

  # Short label for a controller MP source (SDL index, or :lt/:rt trigger).
  def self.mp_pad_label(src)
    return "LT" if src == :lt
    return "RT" if src == :rt
    return (MP_PAD_LABELS[src] || "Btn #{src}") if src.is_a?(Integer)
    "-"
  rescue
    "-"
  end

  # Short label for a keyboard/mouse MP source token.
  def self.mp_key_label(tok)
    return "-" if tok.nil?
    ent = key_token_for(tok)
    ent ? ent[1] : tok.to_s
  rescue
    "-"
  end

  # Backward-compatible MERGED view (read-only): non-nil for an action if EITHER a
  # keyboard or a controller source is bound. Kept for external callers that only
  # ask "is this action bound?" (e.g. 016_ProfileF8Toggle).
  def self.mp_bind
    h = {}
    mp_actions.each { |k, _l| h[k] = (mp_pad[k] || mp_kb[k]) }
    h
  rescue
    {}
  end

  def self.source_name(b)
    m = { Input::C => "C", Input::B => "B", Input::A => "A", Input::X => "X",
      Input::Y => "Y", Input::Z => "Z", Input::L => "L", Input::R => "R",
      Input::UP => "Up", Input::DOWN => "Down",
      Input::LEFT => "Left", Input::RIGHT => "Right" }
    trigger_sources.each { |btn, lbl| m[btn] = lbl }
    m[b] || b.to_s
  end

  # Display name for an MP binding (controller button, key token, or unbound).
  def self.mp_source_name(b)
    return "-" if b.nil?
    if b.is_a?(String)
      ent = key_token_for(b)
      return ent ? ent[1] : b
    end
    source_name(b)
  end

  # Value shown on an MP row. The HUD row always advertises the controller Select
  # button alongside whatever key/button is bound (Tab by default) -> "Tab/Select".
  def self.mp_row_value_label(key)
    kb  = mp_kb[key]
    pad = mp_pad[key]
    kbs  = kb  ? mp_key_label(kb)  : "-"
    pads = pad ? mp_pad_label(pad) : "-"
    if key == :hud
      # Select always toggles the HUD; advertise it alongside any extra binding.
      pads = (pad && pad != SELECT_SDL) ? "#{mp_pad_label(pad)}/Sel" : "Select"
    end
    "#{kbs} / #{pads}"
  rescue
    "-"
  end

  # ---- Bound-control labels for in-menu tooltips -------------------------------
  # The controller button currently bound to a logical action (reflects whatever
  # the player set in the rebind menu). Used by the MP menus so their on-screen
  # hints always match the player's real bindings.
  def self.controller_label(action_button)
    s = (@remap && @remap[action_button]) || action_button
    source_name(s)
  rescue
    source_name(action_button) rescue "?"
  end

  def self.confirm_label; controller_label(Input::C); end
  def self.cancel_label;  controller_label(Input::B); end
  def self.action_label;  controller_label(Input::A); end

  # "What opens this MP feature": the fixed F-key default plus any custom binding
  # from the rebind menu (controller button / key / mouse).
  MP_DEFAULT_KEYS = { :squad => "1", :players => "3", :chat => "F10",
                      :gts => "0", :cases => "2", :profile => "F8",
                      :hud => "" } unless const_defined?(:MP_DEFAULT_KEYS)
  def self.mp_open_label(key)
    parts = []
    kb  = (mp_kb[key]  rescue nil)
    pad = (mp_pad[key] rescue nil)
    parts << mp_key_label(kb)  if kb
    parts << mp_pad_label(pad) if pad
    if parts.empty?
      base = (MP_DEFAULT_KEYS[key] || "").to_s
      return base.empty? ? "-" : base
    end
    parts.join(" / ")
  rescue
    (MP_DEFAULT_KEYS[key] rescue "") || ""
  end

  # ===========================================================================
  # F1-PARITY CONTROLLER BINDINGS  (keybindings.mkxp1)        [added 2026-06-16]
  #
  # The engine's native F1 "Key Bindings" menu reads/writes Data/keybindings.mkxp1
  # -- a binary BindingMap that is the REAL source of truth for which physical
  # pad button maps to which logical RGSS button. The 8 action rows of THIS menu
  # now read & rewrite the CONTROLLER entries of that SAME file, so the in-game
  # (controller-friendly) menu and the F1 menu always agree: rebinding "Confirm"
  # to Pad Y here changes the very entry the F1 menu lists. mkxp-z loads the map
  # only at boot and exposes no Ruby hot-reload, so changes apply on NEXT launch.
  #
  # Binary format (formVer 2):
  #   header : <III  = formVer(2), rgssVer, count
  #   entry  : count x 16 bytes = type(i32) u0(i32) u1(i32) target(i32)
  #            type 1=keyboard scancode(u0)  2=controller button(SDL index u0)
  #                 3=hat  4=axis
  #            target = RGSS Input id; in this engine the Input constant value IS
  #            that id (A=11 B=12 C=13 X=14 Y=15 Z=16 L=17 R=18), so identity.
  # ===========================================================================
  def self.kb_target_for(action); action; end

  # Ordered catalog of assignable physical controller buttons a :btn row cycles
  # through (SDL game-controller button index -> short label). Pad A is the
  # bottom/South face button, Pad B the right/East face button, etc.
  KB_CBTN_CATALOG = [
    [0, "Pad A"], [1, "Pad B"], [2, "Pad X"], [3, "Pad Y"], [4, "Back"],
    [6, "Start"], [9, "L-Btn"], [10, "R-Btn"], [7, "L-Stick"], [8, "R-Stick"],
    [11, "D-Up"], [12, "D-Down"], [13, "D-Left"], [14, "D-Right"], [5, "Guide"]
  ] unless const_defined?(:KB_CBTN_CATALOG)

  def self.kb_cbtn_label(sdl)
    return _INTL("(none)") if sdl.nil?
    ent = KB_CBTN_CATALOG.find { |i, _l| i == sdl }
    ent ? ent[1] : "Btn #{sdl}"
  rescue
    "?"
  end

  # The LIVE keybindings file the engine actually loads at boot
  # (System.data_directory + "keybindings.mkxp1", an AppData location). This is
  # the file the F1 menu reads/writes, so it is also the one we read/write to keep
  # the two menus in lock-step. nil if System.data_directory is unavailable.
  def self.kb_live_path
    d = (System.data_directory rescue nil)
    return nil unless d && !d.to_s.empty?
    d = d.to_s
    d += "/" unless d.end_with?("/") || d.end_with?("\\")
    d + "keybindings.mkxp1"
  rescue
    nil
  end

  # The shipped default template under Data/ (copied to the live path on first run).
  def self.kb_template_path
    File.join(Dir.pwd, "Data", "keybindings.mkxp1")
  rescue
    "Data/keybindings.mkxp1"
  end

  # Read/write target: the live file when known, else the template.
  def self.kb_path
    kb_live_path || kb_template_path
  rescue
    kb_template_path
  end

  # Parse the binary file -> {:form,:rgss,:entries=>[{:t,:u0,:u1,:tgt},...]} or
  # nil if missing / unreadable / not formVer 2. Round-trips byte-exact.
  def self.kb_parse(path = kb_path)
    return nil unless path && File.exist?(path)
    data = File.binread(path)
    return nil if data.bytesize < 12
    form, rgss, count = data[0, 12].unpack("l<l<l<")
    return nil unless form == 2
    entries = []; off = 12
    count.times do
      break if off + 16 > data.bytesize
      t, u0, u1, tgt = data[off, 16].unpack("l<l<l<l<")
      entries << { :t => t, :u0 => u0, :u1 => u1, :tgt => tgt }
      off += 16
    end
    { :form => form, :rgss => rgss, :entries => entries }
  rescue
    nil
  end

  def self.kb_serialize(parsed)
    e = parsed[:entries]
    out = [parsed[:form], parsed[:rgss], e.length].pack("l<l<l<")
    e.each { |h| out << [h[:t], h[:u0], h[:u1], h[:tgt]].pack("l<l<l<l<") }
    out
  end

  # Write back, making a one-time .kbbak backup first. Returns true on success.
  def self.kb_write(parsed)
    return false if @kb_readonly
    path = kb_path
    bak  = path + ".kbbak"
    File.binwrite(bak, File.binread(path)) if File.exist?(path) && !File.exist?(bak)
    File.binwrite(path, kb_serialize(parsed))
    true
  rescue
    false
  end

  # Load entries for the menu session. Duplicate physical-button mappings across
  # different logical actions are PRESERVED (the player may deliberately bind one
  # pad button to two actions); only exact byte-identical duplicate entries are
  # dropped. Runtime double-fire (the "Pad B also confirms" class) is handled
  # separately by the InputDedupe layer, not by stripping bindings here.
  def self.kb_menu_load
    @kb_readonly = false
    live = kb_live_path
    # First run: seed the live file from the shipped template (same as the game's
    # own copyKeybindings) so the controller defaults are present to display/edit.
    if live && !File.exist?(live)
      begin
        tpl = kb_template_path
        File.binwrite(live, File.binread(tpl)) if File.exist?(tpl)
      rescue
      end
    end
    @kb_parsed = kb_parse(live || kb_template_path)
    if @kb_parsed.nil?
      # Live file missing/unreadable/unexpected format: show the template values
      # read-only so the rows aren't blank, but do NOT risk overwriting the live
      # file with a possibly-mismatched format.
      @kb_parsed = kb_parse(kb_template_path)
      @kb_readonly = true if @kb_parsed
    end
    @kb_dirty  = false
    return unless @kb_parsed
    # DUPLICATES ALLOWED (2026-06-21): a single physical pad button MAY map to
    # more than one logical action (e.g. Pad X on both "Button X" and "MP
    # Actions/Run"). We no longer drop the later mapping -- doing so blanked the
    # second row and silently rewrote the user's keybindings file. Only exact
    # byte-identical duplicate entries are removed (those are pure noise).
    seen_all = {}; kept = []
    @kb_parsed[:entries].each do |h|
      sig = [h[:t], h[:u0], h[:u1], h[:tgt]]
      next if seen_all[sig]
      seen_all[sig] = true
      kept << h
    end
    if kept.length != @kb_parsed[:entries].length
      @kb_parsed[:entries] = kept
      @kb_dirty = true
    end
  rescue
    @kb_parsed = nil
  end

  # SDL index currently bound to a logical action (nil if no controller entry).
  def self.kb_cbtn_for(action)
    return nil unless @kb_parsed
    tgt = kb_target_for(action)
    ent = @kb_parsed[:entries].find { |h| h[:t] == 2 && h[:tgt] == tgt }
    ent ? ent[:u0] : nil
  rescue
    nil
  end

  # Bind (or, with nil, clear) the controller button for an action. Enforces
  # exclusivity: the chosen pad button is removed from any OTHER action first, so
  # one physical button never maps to two logical actions.
  def self.kb_set_cbtn(action, sdl)
    return unless @kb_parsed
    tgt = kb_target_for(action)
    es  = @kb_parsed[:entries]
    # DUPLICATES ALLOWED: clear only this action's previous pad bind; do NOT
    # unbind the chosen button from other actions (the same button may serve two).
    es.reject! { |h| h[:t] == 2 && h[:tgt] == tgt }
    es << { :t => 2, :u0 => sdl, :u1 => 0, :tgt => tgt } unless sdl.nil?
    @kb_dirty = true
  rescue
    nil
  end

  def self.kb_cycle(action, dir)
    list = [nil] + KB_CBTN_CATALOG.map { |i, _l| i }
    cur  = kb_cbtn_for(action)
    i    = list.index(cur) || 0
    kb_set_cbtn(action, list[(i + dir) % list.length])
  rescue
    nil
  end

  def self.kb_commit_if_dirty
    return false unless @kb_dirty && @kb_parsed
    ok = kb_write(@kb_parsed)
    @kb_dirty = false if ok
    ok
  rescue
    false
  end

  # ---------------------------------------------------------------------------
  # One-time default migration: Cancel / Menu (B) -> Pad B + Start (controller)
  # + Escape + Keypad 0 (keyboard) -- dropping the stray Pad X / Left-shoulder
  # controller binds and the 'X' keyboard bind that shipped on Cancel. This
  # mirrors the patched Data/ template onto an EXISTING live keybindings file,
  # which copyKeybindings never refreshes once it exists. Marker-guarded so it
  # runs exactly once and never fights a later deliberate rebind. Fully rescued;
  # backs the live file up to .kbbak first.
  # ---------------------------------------------------------------------------
  CANCEL_MIGRATION_ID = "cancel_default_v2" unless const_defined?(:CANCEL_MIGRATION_ID)

  def self.kb_marker_path
    lp = kb_live_path
    return nil unless lp
    File.join(File.dirname(lp), "kif_keybind_migrations.txt")
  rescue
    nil
  end

  def self.kb_migration_done?(id)
    mp = kb_marker_path
    return false unless mp && File.exist?(mp)
    File.read(mp).each_line.any? { |ln| ln.strip == id }
  rescue
    false
  end

  def self.kb_mark_migration(id)
    mp = kb_marker_path
    return unless mp
    File.open(mp, "a") { |f| f.write(id + "\n") }
  rescue
    nil
  end

  def self.ensure_cancel_default_migration!
    return if kb_migration_done?(CANCEL_MIGRATION_ID)
    live = kb_live_path
    return unless live && File.exist?(live)
    parsed = kb_parse(live)
    return unless parsed
    b   = Input::B   # logical Cancel target (12)
    es  = parsed[:entries]
    orig = kb_serialize(parsed)
    # Pad B (SDL 1) and Start (SDL 6) map to Cancel ONLY (drop any other mapping
    # so one physical press never fires two logical buttons).
    es.reject! { |h| h[:t] == 2 && (h[:u0] == 1 || h[:u0] == 6) }
    # Drop the stray Cancel binds that shipped: Pad X (2) / L-shoulder (9) / 'X' key (27).
    es.reject! { |h| h[:tgt] == b && h[:t] == 2 && (h[:u0] == 2 || h[:u0] == 9) }
    es.reject! { |h| h[:tgt] == b && h[:t] == 1 && h[:u0] == 27 }
    # (Re)add the wanted binds: Pad B, Start, Escape, Keypad 0.
    [[2, 1], [2, 6], [1, 41], [1, 98]].each do |t, u0|
      unless es.any? { |h| h[:t] == t && h[:u0] == u0 && h[:tgt] == b }
        es << { :t => t, :u0 => u0, :u1 => 0, :tgt => b }
      end
    end
    if kb_serialize(parsed) != orig
      bak = live + ".kbbak"
      File.binwrite(bak, File.binread(live)) unless File.exist?(bak)
      File.binwrite(live, kb_serialize(parsed))
    end
    kb_mark_migration(CANCEL_MIGRATION_ID)
  rescue
    nil
  end

  # ---- Trigger + shoulder keybinding migration (v3, axis-correct) ------------
  # FIX 2026-06-20: the controller TRIGGERS are analog AXES, not buttons. The old
  # migration bound JButton 6/7 -> F5/F9, but on an SDL game controller button 6
  # is START and button 7 is the LEFT-STICK click; the real triggers are AXIS 4
  # (L2) and AXIS 5 (R2). So pulling a trigger never produced F5/F9 and Chat /
  # Profile never fired from the pad. We now bind the trigger AXES (positive half)
  # -> F5/F9 (Ruby then fires Chat on F5 = Left Trigger, Profile on F9 = Right
  # Trigger) and hand Start back to Cancel(B). We ALSO repair the SHOULDER buttons:
  # L1 = JButton 9, R1 = JButton 10. The shipped file mis-bound R1 -> L(AUX1) and
  # D-pad-Up(11) -> R(AUX2) with L1 unbound, so the bumpers never paged; now L1 ->
  # L (previous page) and R1 -> R (next page). mkxp-z reads keybindings only at
  # boot, so this applies on the NEXT launch. New marker id so it re-runs over the
  # old broken mapping; .kbbak backup first; fully rescued.
  TRIGGER_MIGRATION_ID = "controller_axis_bumper_v3" unless const_defined?(:TRIGGER_MIGRATION_ID)
  L2_AXIS = 4 unless const_defined?(:L2_AXIS)         # SDL_CONTROLLER_AXIS_TRIGGERLEFT
  R2_AXIS = 5 unless const_defined?(:R2_AXIS)         # SDL_CONTROLLER_AXIS_TRIGGERRIGHT
  L1_JBUTTON = 9  unless const_defined?(:L1_JBUTTON)  # SDL_CONTROLLER_BUTTON_LEFTSHOULDER
  R1_JBUTTON = 10 unless const_defined?(:R1_JBUTTON)  # SDL_CONTROLLER_BUTTON_RIGHTSHOULDER
  KB_AXIS_POSITIVE = 1 unless const_defined?(:KB_AXIS_POSITIVE)  # mkxp JAxis dir 0=neg/1=pos

  # Rewrite a parsed keybinding map to the corrected trigger-axis + shoulder
  # layout. Idempotent; returns true if anything changed.
  def self.apply_controller_axis_bumper_fix!(parsed)
    return false unless parsed && parsed[:entries]
    es   = parsed[:entries]
    f5   = (defined?(Input::F5) ? Input::F5 : 25)
    f9   = (defined?(Input::F9) ? Input::F9 : 29)
    laux = (defined?(Input::L)  ? Input::L  : 17)
    raux = (defined?(Input::R)  ? Input::R  : 18)
    bcan = (defined?(Input::B)  ? Input::B  : 12)
    orig = kb_serialize(parsed)
    # Triggers: drop old wrong button->F5/F9 binds, any prior axis binds, and stray
    # binds on Start(6)/L-Stick(7); then bind the trigger AXES (positive) -> F5/F9.
    es.reject! { |h| h[:t] == 2 && (h[:tgt] == f5 || h[:tgt] == f9) }
    es.reject! { |h| h[:t] == 3 && (h[:tgt] == f5 || h[:tgt] == f9) }
    es.reject! { |h| h[:t] == 2 && (h[:u0] == 6 || h[:u0] == 7) }
    es << { :t => 3, :u0 => L2_AXIS, :u1 => KB_AXIS_POSITIVE, :tgt => f5 }
    es << { :t => 3, :u0 => R2_AXIS, :u1 => KB_AXIS_POSITIVE, :tgt => f9 }
    es << { :t => 2, :u0 => 6, :u1 => 0, :tgt => bcan } unless es.any? { |h| h[:t] == 2 && h[:u0] == 6 }
    # Shoulders: clear any controller bind to L/R and any bind on btns 9/10/11,
    # then bind L1 -> L (page left) and R1 -> R (page right).
    es.reject! { |h| h[:t] == 2 && (h[:tgt] == laux || h[:tgt] == raux) }
    es.reject! { |h| h[:t] == 2 && (h[:u0] == L1_JBUTTON || h[:u0] == R1_JBUTTON || h[:u0] == 11) }
    es << { :t => 2, :u0 => L1_JBUTTON, :u1 => 0, :tgt => laux }
    es << { :t => 2, :u0 => R1_JBUTTON, :u1 => 0, :tgt => raux }
    kb_serialize(parsed) != orig
  rescue
    false
  end

  def self.ensure_trigger_migration!
    return if kb_migration_done?(TRIGGER_MIGRATION_ID)
    live = kb_live_path
    return unless live && File.exist?(live)
    parsed = kb_parse(live)
    return unless parsed
    if apply_controller_axis_bumper_fix!(parsed)
      bak = live + ".kbbak"
      File.binwrite(bak, File.binread(live)) unless File.exist?(bak)
      File.binwrite(live, kb_serialize(parsed))
    end
    kb_mark_migration(TRIGGER_MIGRATION_ID)
  rescue
    nil
  end

  def self.defaults
    h = {}
    buttons.each { |b| h[b] = b }
    h
  end

  def self.ensure_init
    @remap = defaults if !@remap || @remap.empty?
    @mp_kb  ||= defaults_mp_kb.dup
    @mp_pad ||= defaults_mp_pad.dup
    @pad_bind ||= {}
    @vk_last ||= {}
  end

  def self.pad_bind
    @pad_bind ||= {}
  end

  # The engine's CURRENT physical-pad -> logical-action map, read once at boot
  # straight from keybindings.mkxp1. mkxp-z loads that file only at boot and
  # rewrites it from its in-memory copy on exit, so any in-session edit is
  # reverted -- which is why Action rebinds never used to survive a relaunch. We
  # therefore keep our OWN pad bindings (below) and apply them at runtime; this
  # map is only consulted to avoid double-firing a button the engine ALREADY maps
  # to the same action.
  def self.kb_native_map
    @kb_native_map ||= begin
      m = {}
      p = kb_parse(kb_live_path || kb_template_path)
      p[:entries].each { |h| m[h[:u0]] = h[:tgt] if h[:t] == 2 } if p
      m
    rescue
      {}
    end
  end

  # The physical SDL button our Ruby layer should OR-in for a logical action, or
  # nil: nil when nothing is bound OR when the engine already maps that button to
  # this action (so one press can never fire twice).
  def self.pad_extra_active?(action)
    sdl = pad_bind[action]
    return nil if sdl.nil?
    return nil if kb_native_map[sdl] == action
    sdl
  rescue
    nil
  end

  def self.pad_action_edge?(action)
    return false if @bypass
    sdl = pad_extra_active?(action)
    return false if sdl.nil?
    phys_edge?(sdl)
  rescue
    false
  end

  def self.pad_action_down?(action)
    return false if @bypass
    sdl = pad_extra_active?(action)
    return false if sdl.nil?
    phys_down?(sdl)
  rescue
    false
  end

  # Bind (nil clears) a physical pad button to a logical action, exclusive within
  # our layer so one physical button drives only one action.
  def self.pad_set(action, sdl)
    if sdl
      # DUPLICATES ALLOWED: keep this button on any other action it is also bound to.
      pad_bind[action] = sdl
    else
      pad_bind.delete(action)
    end
  rescue
    nil
  end

  def self.pad_cycle(action, dir)
    list = [nil] + KB_CBTN_CATALOG.map { |i, _l| i }
    cur  = pad_bind[action]
    i    = list.index(cur) || 0
    pad_set(action, list[(i + dir) % list.length])
  rescue
    nil
  end

  # The controller button shown on an Action row: our override if the player set
  # one, else the engine's current default (from keybindings.mkxp1).
  def self.pad_effective_cbtn(action)
    return pad_bind[action] if pad_bind.key?(action)
    kb_cbtn_for(action)
  rescue
    nil
  end

  # Translate a requested logical button into the physical source to query.
  # Identity (and therefore harmless) unless the player has rebound it.
  def self.src(button)
    return button if @bypass
    @remap ||= {}
    s = @remap[button]
    s.nil? ? button : s
  rescue
    button
  end

  def self.cycle(action, dir)
    ensure_init
    list = assignable_sources
    cur  = @remap[action] || action
    i    = list.index(cur) || 0
    @remap[action] = list[(i + dir) % list.length]
  rescue
    nil
  end

  # Default MP hotkey bindings. These are the fixed F-key shortcuts from base
  # KIFM, pre-populated so the rebind menu shows them bound out of the box.
  # Tab is the HUD min/max toggle (works everywhere via the global poller).
  def self.defaults_mp_kb
    { :squad   => "1", :players => "3", :chat => "F10",
      :gts     => "0", :cases   => "2", :profile => "F8",
      :hud     => "Tab" }
  end

  # Controller defaults the fork ships with: D-pad for the four menus, the two
  # analog triggers for Chat (LT) and Profile (RT), Select for the HUD toggle.
  def self.defaults_mp_pad
    { :squad   => 11,  # D-Up
      :players => 14,  # D-Right
      :gts     => 12,  # D-Down
      :cases   => 13,  # D-Left
      :chat    => :lt, # Left Trigger
      :profile => :rt, # Right Trigger
      :hud     => SELECT_SDL }
  end

  def self.reset!
    @remap = defaults
    @mp_kb  = defaults_mp_kb.dup
    @mp_pad = defaults_mp_pad.dup
    @pad_bind = {}
  end

  def self.bind_path
    File.join(Dir.pwd, "control_bindings.txt")
  rescue
    "control_bindings.txt"
  end

  def self.save
    ensure_init
    lines = buttons.map do |b|
      s = @remap[b] || b
      val = s.is_a?(String) ? "K:#{s}" : source_name(s)
      "#{source_name(b)}=#{val}"
    end
    mp_actions.each do |act, _l|
      kb = mp_kb[act]
      lines << "MK:#{act}=#{kb.nil? ? '-' : kb}"
      pad = mp_pad[act]
      psv = pad.nil? ? "-" : (pad == :lt ? "LT" : (pad == :rt ? "RT" : pad.to_s))
      lines << "MC:#{act}=#{psv}"
    end
    pad_bind.each do |act, sdl|
      next if sdl.nil?
      lines << "PB:#{source_name(act)}=#{sdl}"
    end
    File.open(bind_path, "w") { |f| f.write(lines.join("\n")) }
  rescue
    nil
  end

  def self.load
    @remap = defaults
    @mp_kb  = defaults_mp_kb.dup
    @mp_pad = defaults_mp_pad.dup
    @pad_bind = {}
    return unless File.exist?(bind_path)
    name_to_btn = {}
    assignable_sources.each { |b| name_to_btn[source_name(b)] = b }
    valid = mp_actions.map { |k, _l| k }
    File.read(bind_path).each_line do |ln|
      ln = ln.strip
      next if ln.empty?
      if ln.start_with?("MK:")                      # keyboard slot
        k, v = ln.sub("MK:", "").split("=", 2)
        next unless k && v
        sym = k.to_sym; next unless valid.include?(sym)
        @mp_kb[sym] = (v == "-" || v.empty? || !key_token_for(v)) ? nil : v
      elsif ln.start_with?("MC:")                   # controller slot
        k, v = ln.sub("MC:", "").split("=", 2)
        next unless k && v
        sym = k.to_sym; next unless valid.include?(sym)
        @mp_pad[sym] = mp_pad_token_parse(v)
      elsif ln.start_with?("MP:")                   # legacy single slot
        k, v = ln.sub("MP:", "").split("=", 2)
        next unless k && v
        sym = k.to_sym; next unless valid.include?(sym)
        if v.start_with?("K:")
          tok = v.sub("K:", ""); @mp_kb[sym] = tok if key_token_for(tok)
        elsif v == "LT" || v == "RT"
          @mp_pad[sym] = (v == "LT" ? :lt : :rt)
        end
      elsif ln.start_with?("PB:")
        k, v = ln.sub("PB:", "").split("=", 2)
        next unless k && v
        a   = name_to_btn[k]
        sdl = (Integer(v) rescue nil)
        @pad_bind[a] = sdl if a && sdl
      else
        k, v = ln.split("=", 2)
        next unless k && v
        a = name_to_btn[k]
        next unless a
        if v.start_with?("K:")
          tok = v.sub("K:", "")
          @remap[a] = tok if key_token_for(tok)
        else
          s = name_to_btn[v]
          @remap[a] = s if s
        end
      end
    end
    # Migration: the chat-toggle key moved from "T" to "F10". "T" is now reserved
    # for "start typing in the chat box" only and must never close the chat window,
    # so upgrade any saved binding still pointing chat at the old "T" default.
    @mp_kb[:chat] = "F10" if @mp_kb[:chat] == "T"
  rescue
    @remap = defaults
    @mp_kb  = defaults_mp_kb.dup
    @mp_pad = defaults_mp_pad.dup
    @pad_bind = {}
  end

  # Parse a saved controller-slot token: "-" -> nil, "LT"/"RT" -> trigger, else an
  # SDL button index integer.
  def self.mp_pad_token_parse(v)
    return nil if v.nil? || v == "-" || v.empty?
    return :lt if v == "LT"
    return :rt if v == "RT"
    (Integer(v) rescue nil)
  rescue
    nil
  end

  #-----------------------------------------------------------------------------
  # Raw (un-remapped) edge read, used by the MP poller so a player's remap can't
  # double-translate an MP binding.
  #-----------------------------------------------------------------------------
  def self.raw_trigger?(b)
    if Input.respond_to?(:_rebind_orig_trigger?)
      Input._rebind_orig_trigger?(b)
    else
      Input.trigger?(b)
    end
  rescue
    false
  end

  # Fire the MP function bound to a button. Mirrors HotkeyHUD#_trigger_action so
  # it does not depend on a live HUD instance.
  def self.mp_trigger(key)
    case key
    when :chat
      # Cancel any in-progress typing first so F10 / Left Trigger cleanly closes
      # the whole chat window. (The T key only opens the typing box; it never
      # toggles the window, so the toggle path must own the cancel-then-close.)
      if defined?(Input) && Input.respond_to?(:close_chat_input) &&
         ($chat_window && ($chat_window.input_mode rescue false))
        Input.close_chat_input rescue nil
      end
      ChatState.toggle_deploy if defined?(ChatState)
    when :gts
      GTSUI.open if defined?(GTSUI)
    when :players
      if defined?(MultiplayerUI)
        if MultiplayerUI.instance_variable_get(:@playerlist_open)
          MultiplayerUI.instance_variable_set(:@playerlist_close_requested, true)
        else
          MultiplayerUI.openPlayerList rescue nil
        end
      end
    when :squad
      if defined?(MultiplayerUI) && defined?(MultiplayerClient) && (MultiplayerClient.in_squad? rescue false)
        if MultiplayerUI.instance_variable_get(:@squadwindow_open)
          MultiplayerUI.instance_variable_set(:@squadwindow_close_requested, true)
        else
          MultiplayerUI.openSquadWindow rescue nil
        end
      end
    when :cases
      if defined?(KIFCases)
        if KIFCases.screen_open?
          KIFCases.request_close rescue nil
        else
          KIFCases::CaseSelectScreen.open rescue nil
        end
      end
    when :profile
      MultiplayerUI::ProfilePanel.toggle(uuid: "self") if defined?(MultiplayerUI::ProfilePanel)
    when :hud
      if defined?(MultiplayerUI) && MultiplayerUI.respond_to?(:toggle_hud_hotkey)
        MultiplayerUI.toggle_hud_hotkey
      elsif defined?(MultiplayerUI) && MultiplayerUI.respond_to?(:toggle_overlays_minimized)
        MultiplayerUI.toggle_overlays_minimized
      end
    end
  rescue
    nil
  end

  # Does the KEYBOARD slot token fire this frame? (GetAsyncKeyState edge.)
  def self.mp_source_fired_kb?(tok)
    ent = key_token_for(tok)
    return false unless ent
    vk_edge?(ent[2])
  rescue
    false
  end

  # Does the CONTROLLER slot source fire this frame? Triggers use the latched
  # trigger edge; SDL buttons/D-pad use the physical-pad edge (raw HID / XInput).
  def self.mp_source_fired_pad?(src)
    return trigger_edge?(:lt) if src == :lt
    return trigger_edge?(:rt) if src == :rt
    return phys_edge?(src)    if src.is_a?(Integer)
    false
  rescue
    false
  end

  # True while a Multiplayer modal menu (Player List + its action menu, Squad,
  # Profile card, Cases, GTS) is on screen. Used by the confirm bridge so the
  # controller's Action button (A) also works as Confirm inside those menus --
  # they only listen for C/USE, so a controller whose face button maps to A
  # would otherwise need a double-tap (or not work at all) to confirm.
  def self.mp_confirm_bridge_active?
    return false unless defined?(MultiplayerUI)
    if MultiplayerUI.respond_to?(:mouse_modal_overlay_open?)
      return true if (MultiplayerUI.mouse_modal_overlay_open? rescue false)
    end
    return true if (defined?(GTSUI) && GTSUI.respond_to?(:open?) && GTSUI.open? rescue false)
    false
  rescue
    false
  end

  # Called every overworld frame. Fires an MP action when EITHER its keyboard slot
  # or its controller slot is pressed this frame.
  def self.mp_poll
    return if @bypass
    return unless defined?(MultiplayerClient)
    mp_actions.each do |action, _l|
      next if action == :hud   # HUD toggle is polled globally (works in menus/battles)
      kb  = mp_kb[action]
      pad = mp_pad[action]
      fire = (kb && mp_source_fired_kb?(kb)) || (pad && mp_source_fired_pad?(pad))
      if fire
        mp_trigger(action)
        # Exactly ONE MP hotkey per frame. The D-pad hat reports a diagonal as TWO
        # directions at once (Up-Right = D-Up AND D-Right), so without this a near-
        # diagonal D-Right press would fire BOTH Squad(D-Right) and Player List(D-Up)
        # and the wrong menu would win. mp_actions lists Squad before Player List, so
        # a D-Right (or Up-Right) press resolves to Squad.
        break
      end
    end
  rescue
    nil
  end

  # Polled EVERY frame (all scenes) so the HUD/chat min-max toggle works inside
  # menus, battles, etc -- not just the overworld. Only :hud is global; the other
  # MP hotkeys stay overworld-only (you should not open GTS mid-battle).
  def self.global_poll
    return if @bypass
    # Lazily snapshot the pre-menu graphics the FIRST nested Input.update of an
    # overworld-frame menu loop (see Scene_Map#main wrapper). Cheap: runs once
    # per menu-open, never during a clean walking frame (update() itself never
    # calls Input.update), and skipped during events/dialogue (no throw there).
    if ($kifm_in_overworld_update rescue false) && $kifm_update_baseline.nil? &&
       !kifm_event_or_message_active?
      $kifm_update_baseline = (snapshot_live_graphics rescue nil)
    end
    poll_hold_b_exit rescue nil
    # HUD min/max fires on the bound key/button (Tab by default) OR the controller
    # Select button (SDL Back=4 -- DualSense "Create"), which is always wired here.
    hud_kb  = mp_kb[:hud]
    hud_pad = mp_pad[:hud]
    fire_hud = false
    fire_hud = true if hud_kb  && mp_source_fired_kb?(hud_kb)
    fire_hud = true if hud_pad && hud_pad != SELECT_SDL && mp_source_fired_pad?(hud_pad)
    fire_hud = true if (phys_edge?(SELECT_SDL) rescue false)
    mp_trigger(:hud) if fire_hud
  rescue
    nil
  end

  def self.hold_b_exit_count_reset
    @hold_b_exit_count = 0
  rescue
    nil
  end

  # Snapshot the object_ids of every live, non-disposed Window/Sprite/Viewport
  # at the moment we enter the overworld menu chain. Anything NOT in this set
  # that is still alive after a hold-B quick-exit is a LEAKED menu graphic whose
  # disposal got skipped when `throw` unwound past its (ensure-less) cleanup.
  def self.snapshot_live_graphics
    set = {}
    [Sprite, Window, Viewport].each do |klass|
      next unless defined?(klass)
      ObjectSpace.each_object(klass) do |o|
        begin
          set[o.object_id] = true unless o.disposed?
        rescue
          nil
        end
      end
    end
    set
  rescue
    nil
  end

  # Dispose any Window/Sprite/Viewport created during the menu chain that is
  # still alive (i.e. not in the pre-menu snapshot). GC.start does NOT dispose
  # RGSS C-backed graphics, so without this the leaked menu windows stay drawn
  # on top of the overworld -- the "stuck overlaid menus" bug. Sprites/windows
  # are disposed first, viewports last; every call is guarded.
  def self.dispose_leaked_graphics(pre)
    return if pre.nil?
    [Sprite, Window, Viewport].each do |klass|
      next unless defined?(klass)
      ObjectSpace.each_object(klass) do |o|
        begin
          next if pre[o.object_id]
          next if o.disposed?
          o.dispose
        rescue
          nil
        end
      end
    end
  rescue
    nil
  end

  # True while an NPC message box or a running map-event interpreter is active.
  # Hold-B quick-exit is suppressed in this state so it can't unwind out of the
  # middle of an event script (which would corrupt interpreter state).
  def self.kifm_event_or_message_active?
    return true if (defined?($game_temp) && $game_temp &&
                    $game_temp.message_window_showing rescue false)
    return true if (defined?(pbMapInterpreterRunning?) && pbMapInterpreterRunning? rescue false)
    false
  rescue
    false
  end

  # Fires every frame (via global_poll -> Input.update) when inside the
  # overworld menu chain. Counts consecutive frames B is held and throws
  # :kifm_back_to_overworld once the threshold is reached, unwinding all
  # menus back to Scene_Map#call_menu's catch block. Graphics.freeze is
  # called first so the screen holds on the last menu frame during unwind,
  # then a Graphics.transition fades from that snapshot to the live overworld.
  # NOTE: Ruby's `rescue` does NOT catch `throw`, so rescue nil in callers
  # cannot swallow the throw -- it propagates cleanly through any rescue block.
  def self.poll_hold_b_exit
    in_chain  = ($kifm_in_menu_chain rescue false)        # pause-menu chain (call_menu catch)
    in_owupd  = ($kifm_in_overworld_update rescue false)  # any menu nested in an overworld frame
    return unless in_chain || in_owupd
    return if @bypass
    # Never tear out of an active event/dialogue: throwing past pbMapInterpreter
    # would leave the interpreter mid-command and resume a broken event next
    # frame. The pause-menu chain is exempt (no interpreter runs under it).
    return if in_owupd && !in_chain && kifm_event_or_message_active?
    b_held = (Input.press?(Input::B) rescue false)
    if b_held
      @hold_b_exit_count = (@hold_b_exit_count || 0) + 1
      if @hold_b_exit_count >= HOLD_B_EXIT_FRAMES
        @hold_b_exit_count = 0
        (pbPlayCancelSE rescue nil)
        (Graphics.freeze rescue nil)
        throw(:kifm_back_to_overworld)
      end
    else
      @hold_b_exit_count = 0
    end
  rescue
    nil
  end

  # --- Frame-stable keyboard state for action (btn) rows bound to a key --------
  # When a logical action button is rebound to a KEYBOARD key (its @remap value is
  # a String token), Input.trigger?/press? must answer from that key. We snapshot
  # the needed VKs once per frame so repeated trigger? calls within a frame all
  # agree (a real engine-style edge). Costs nothing unless a key is actually bound.
  def self.poll_remap_keys!
    @key_frame_states = {}
    return if @bypass
    rm = @remap || {}
    toks = rm.values.select { |s| s.is_a?(String) }
    return if toks.empty?
    gaks = (GetAsyncKeyState rescue nil)
    return unless gaks
    active = window_active?
    @key_prev ||= {}
    seen = {}
    toks.uniq.each do |tok|
      ent = key_token_for(tok); next unless ent
      vk = ent[2]
      down = active && ((gaks.call(vk) & 0x8000) != 0)
      prev = @key_prev[vk] || false
      @key_frame_states[vk] = { :down => down, :edge => (down && !prev) }
      seen[vk] = down
    end
    seen.each { |vk, d| @key_prev[vk] = d }
  rescue
    @key_frame_states = {}
  end

  def self.remap_key_down?(tok)
    ent = key_token_for(tok); return false unless ent
    st = (@key_frame_states || {})[ent[2]]; st ? st[:down] : false
  rescue
    false
  end

  def self.remap_key_edge?(tok)
    ent = key_token_for(tok); return false unless ent
    st = (@key_frame_states || {})[ent[2]]; st ? st[:edge] : false
  rescue
    false
  end

  #-----------------------------------------------------------------------------
  # Controller-navigable rebind screen. Uses RAW input (bypass) the whole time so
  # it stays navigable no matter how the player has rebound things.
  #-----------------------------------------------------------------------------
  # Is a Win32 virtual-key currently held down (level, not edge)?
  def self.vk_down?(vk)
    gaks = (GetAsyncKeyState rescue nil)
    return false unless gaks
    return false unless window_active?
    (gaks.call(vk) & 0x8000) != 0
  rescue
    false
  end

  # Classic hold-to-bind capture. Returns the source currently HELD that is valid
  # for the given row type, or nil. For :btn rows the source is one of the logical
  # buttons or a d-pad/stick direction (Integer). For :mp rows it can additionally
  # be a keyboard/mouse token (String). The first match wins; face buttons are
  # checked before directions so a deliberate button press isn't shadowed.
  def self.detect_held_source(type)
    # MP hotkey capture: an analog trigger, OR a physical pad button (raw HID /
    # XInput -- includes the D-pad hat, distinct from the walking stick), OR a
    # keyboard / mouse key. Confirm/Cancel/Start are excluded (MP_PAD_SDL_ALLOWED)
    # so navigation can't be repurposed.
    return :lt if trigger_down?(:lt)
    return :rt if trigger_down?(:rt)
    sdl = mp_capture_pad_sdl
    return sdl unless sdl.nil?
    key_sources.each { |tok, _l, vk| return tok if vk_down?(vk) }
    nil
  rescue
    nil
  end

  # One allowed physical pad button held this frame, for MP capture.
  def self.mp_capture_pad_sdl
    set = phys_held_sdl_set
    return nil if set.nil? || set.empty?
    MP_PAD_SDL_ALLOWED.each { |sdl| return sdl if set[sdl] }
    nil
  rescue
    nil
  end

  # The physical SDL pad button the player is holding, for ACTION-row hold-to-bind.
  # XInput gives the real button directly; if XInput is unavailable we fall back to
  # mapping the held LOGICAL button back to its physical SDL index via the live
  # keybindings (so holding the button currently bound to Confirm rebinds THAT pad
  # button). nil if nothing usable is held.
  def self.detect_held_pad_sdl
    s = xinput_held_sdl
    return s unless s.nil?
    s = winmm_held_sdl
    return s unless s.nil?
    [Input::C, Input::B, Input::A, Input::X, Input::Y, Input::Z, Input::L, Input::R,
     Input::UP, Input::DOWN, Input::LEFT, Input::RIGHT].each do |logical|
      next unless (Input.press?(logical) rescue false)
      if @kb_parsed
        ent = @kb_parsed[:entries].find { |h| h[:t] == 2 && h[:tgt] == logical }
        return ent[:u0] if ent
      end
    end
    nil
  rescue
    nil
  end

  # Commit a captured source onto a row (left column => remap, right column => MP).
  def self.apply_binding(r, src)
    return if r.nil? || src.nil?
    if r[:type] == :btn
      @remap[r[:key]] = src
    elsif r[:type] == :mp
      if src.is_a?(String)
        mp_kb[r[:key]] = src     # keyboard / mouse token
      else
        mp_pad[r[:key]] = src    # SDL pad-button index or :lt / :rt
      end
    end
  rescue
    nil
  end

  HOLD_FRAMES = 16 unless const_defined?(:HOLD_FRAMES)  # ~0.27s hold to confirm
  HOLD_B_EXIT_FRAMES = 30 unless const_defined?(:HOLD_B_EXIT_FRAMES)  # ~0.5s hold to exit all menus
  @hold_b_exit_count = 0

  def self.open_menu
    ensure_init
    ensure_cancel_default_migration! rescue nil
    kb_menu_load
    @bypass = true
    vp = Viewport.new(0, 0, Graphics.width, Graphics.height)
    vp.z = 99999
    spr = Sprite.new(vp)
    spr.bitmap = Bitmap.new(Graphics.width, Graphics.height)

    rows = []
    actions.each    { |b, l| rows << { :type => :btn, :key => b, :label => l } }
    mp_actions.each { |k, l| rows << { :type => :mp,  :key => k, :label => l } }
    rows << { :type => :reset, :label => _INTL("Reset to defaults") }

    sel       = 0
    redraw    = true
    b_hold    = 0
    listening = false   # classic hold-to-bind capture mode for rows[sel]
    armed     = false   # require all inputs released once before capturing
    hold_src  = nil
    hold_cnt  = 0
    loop do
      Graphics.update
      Input.update

      # ---------------- Capture (listen) mode ----------------
      if listening
        r = rows[sel]
        # Esc cancels the capture (NOT B -- B may be the button being bound).
        if vk_down?(0x1B)
          listening = false; armed = false; hold_src = nil; hold_cnt = 0
          (pbPlayCancelSE rescue nil)
          draw_menu(spr.bitmap, rows, sel, false, 0)
          next
        end
        cur = (r[:type] == :btn) ? detect_held_pad_sdl : detect_held_source(r[:type])
        if cur.nil?
          armed = true          # everything released -> ready to capture
          hold_src = nil; hold_cnt = 0
        elsif !armed
          # still holding the button that opened capture; wait for release
        elsif cur == hold_src
          hold_cnt += 1
          if hold_cnt >= HOLD_FRAMES
            if r[:type] == :btn
              pad_set(r[:key], cur)       # cur is a physical SDL button index
            else
              apply_binding(r, cur)
            end
            listening = false; armed = false; hold_src = nil; hold_cnt = 0
            (pbPlayDecisionSE rescue nil)
          end
        else
          hold_src = cur; hold_cnt = 1
        end
        draw_menu(spr.bitmap, rows, sel, true, hold_cnt)
        next
      end

      # ---------------- Normal navigation ----------------
      b_hold = (Input.press?(Input::B) ? b_hold + 1 : 0)
      if redraw
        draw_menu(spr.bitmap, rows, sel, false, 0)
        redraw = false
      end
      if Input.repeat?(Input::DOWN)
        sel = (sel + 1) % rows.length; redraw = true; (pbPlayCursorSE rescue nil)
      elsif Input.repeat?(Input::UP)
        sel = (sel - 1) % rows.length; redraw = true; (pbPlayCursorSE rescue nil)
      elsif Input.trigger?(Input::C) || Input.trigger?(Input::A)
        r = rows[sel]
        if r[:type] == :reset
          reset!; redraw = true; (pbPlayDecisionSE rescue nil)
        else
          # Action rows AND MP rows: Confirm, then HOLD the input to bind it.
          # (Action rows also still support L/R to quick-cycle pad buttons.)
          listening = true; armed = false; hold_src = nil; hold_cnt = 0
          (pbPlayDecisionSE rescue nil)
          draw_menu(spr.bitmap, rows, sel, true, 0)
        end
      elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
        r = rows[sel]
        left = Input.trigger?(Input::LEFT)
        if r[:type] == :btn
          # Cycle the physical controller button bound to this action.
          pad_cycle(r[:key], left ? -1 : 1); redraw = true; (pbPlayCursorSE rescue nil)
        elsif r[:type] == :mp
          # LEFT clears the keyboard slot, RIGHT clears the controller slot.
          if left then mp_kb[r[:key]] = nil else mp_pad[r[:key]] = nil end
          redraw = true; (pbPlayCancelSE rescue nil)
        end
      elsif Input.trigger?(Input::B) || b_hold >= 18
        (pbPlayCancelSE rescue nil)
        break
      end
    end
    save
    kb_changed = kb_commit_if_dirty
    spr.bitmap.dispose if spr.bitmap && !spr.bitmap.disposed?
    spr.dispose unless spr.disposed?
    vp.dispose unless vp.disposed?
    if kb_changed
      (pbMessage(_INTL("Controller buttons were saved into the game's key bindings (the same ones the F1 menu uses).\nThey take effect the next time you start the game.")) rescue nil)
    end
  rescue
    nil
  ensure
    @bypass = false
  end

  def self.row_description(r)
    return "" unless r
    case r[:type]
    when :btn   then (action_descriptions[r[:key]] || "") + _INTL("  [Confirm + hold a pad button, or L/R to cycle. Saved immediately; works right away.]")
    when :mp    then (mp_action_descriptions[r[:key]] || "") + _INTL("  [Confirm, then HOLD a pad button/trigger to set the controller slot, or a key for the keyboard slot. LEFT clears key, RIGHT clears pad.]")
    when :reset then _INTL("Restore ALL rebinds -- action buttons and MP hotkeys -- to their defaults.")
    else ""
    end
  rescue
    ""
  end

  def self.draw_menu(bmp, rows, sel, listening = false, hold_cnt = 0)
    w = bmp.width
    h = bmp.height
    bmp.clear
    # Fully OPAQUE so the Options menu behind the rebind viewport never shows
    # through (previously alpha 235 let it bleed and looked messy while scrolling).
    bmp.fill_rect(0, 0, w, h, Color.new(18, 16, 28, 255))
    base   = Color.new(255, 255, 255)
    shadow = Color.new(0, 0, 0)
    dim    = Color.new(180, 180, 200)
    selc   = Color.new(120, 220, 255)
    head   = Color.new(150, 255, 180)
    chg    = Color.new(255, 225, 120)
    pbSetSystemFont(bmp)

    # ---- Vertical layout. Taller header + description strips (bigger, easier to
    # read), so rows scale a touch smaller to keep everything on the 512x384 screen.
    title_h  = 32
    hint_h   = 38                            # two readable instruction lines
    top      = title_h + hint_h + 6          # first row y
    desc_h   = 58                            # two wrapped description lines
    bottom_margin = 8
    # Right column has the most rows: MP header + mp_actions + reset.
    right_rows = mp_actions.length + 1
    avail = h - top - desc_h - bottom_margin
    # +1 accounts for the MP header line occupying one row slot.
    rowh = (avail / (right_rows + 1).to_f).floor
    rowh = 24 if rowh < 24
    rowh = 60 if rowh > 60
    val_font = [(rowh * 0.62).to_i, 16].max
    val_font = 30 if val_font > 30

    bmp.font.size = title_h - 4 rescue nil
    pbDrawShadowText(bmp, 0, 4, w, title_h, _INTL("Rebind Controls"), selc, shadow, 1)
    # Two-line instructions (bigger than the old single line, with breathing room).
    bmp.font.size = 18 rescue nil
    pbDrawShadowText(bmp, 0, title_h + 2, w, 18,
      _INTL("Up/Down: move    Confirm then HOLD an input to bind it    Esc: exit"), dim, shadow, 1)
    pbDrawShadowText(bmp, 0, title_h + 20, w, 18,
      _INTL("MP rows show  key / controller .  Hold a key OR pad button/trigger; each sets its own slot."), dim, shadow, 1)

    btn_rows = (0...rows.length).select { |i| rows[i][:type] == :btn }
    other    = (0...rows.length).select { |i| rows[i][:type] != :btn }

    colW = w / 2
    bmp.font.size = val_font rescue nil

    draw_one = proc do |i, x_label, x_val, y|
      r   = rows[i]
      col = (sel == i) ? selc : base
      if (sel == i)
        bmp.fill_rect(x_label - 6, y, (x_val + 116) - (x_label - 6), rowh - 2, Color.new(46, 55, 86, 255))
      end
      if r[:type] == :reset
        c2 = (sel == i) ? selc : dim
        pbDrawShadowText(bmp, x_label, y, colW - 24, rowh - 2, _INTL("Reset to defaults"), c2, shadow, 0)
      else
        pbDrawShadowText(bmp, x_label, y, x_val - x_label - 4, rowh - 2, r[:label], col, shadow, 0)
        if r[:type] == :btn
          sdl = pad_effective_cbtn(r[:key])
          changed = pad_bind.key?(r[:key])
          pbDrawShadowText(bmp, x_val, y, 124, rowh - 2, "< #{kb_cbtn_label(sdl)} >", (changed ? chg : dim), shadow, 0)
        else
          kb = mp_kb[r[:key]]; pad = mp_pad[r[:key]]
          bound = (kb || pad)
          save_fs = bmp.font.size
          bmp.font.size = [[val_font - 8, 18].min, 13].max rescue nil
          pbDrawShadowText(bmp, x_val, y, 126, rowh - 2, "< #{mp_row_value_label(r[:key])} >", (bound ? chg : dim), shadow, 0)
          bmp.font.size = save_fs rescue nil
        end
      end
    end

    # Left column: the action buttons.
    y = top
    btn_rows.each do |i|
      draw_one.call(i, 22, colW - 128, y)
      y += rowh
    end

    # Right column: MP hotkeys header, MP rows, then Reset.
    x_label2 = colW + 16
    x_val2   = w - 128
    y = top
    bmp.font.size = [val_font - 2, 14].max rescue nil
    pbDrawShadowText(bmp, x_label2, y, colW - 20, rowh - 2, _INTL("- MP hotkeys: key / controller -"), head, shadow, 0)
    bmp.font.size = val_font rescue nil
    y += rowh
    other.each do |i|
      draw_one.call(i, x_label2, x_val2, y)
      y += rowh
    end

    # ---- Description / capture-prompt strip for the highlighted row. ----
    dy = h - desc_h - bottom_margin + 2
    bmp.fill_rect(12, dy - 6, w - 24, 2, Color.new(74, 74, 92, 255))
    if listening
      bmp.font.size = 19 rescue nil
      rsel   = (rows[sel] rescue nil)
      lbl    = (rsel && rsel[:label]) ? rsel[:label] : "this action"
      is_btn = (rsel && rsel[:type] == :btn)
      what   = is_btn ? _INTL("a controller button") : _INTL("a pad button / trigger / key")
      pbDrawShadowText(bmp, 16, dy, w - 32, 22,
        _INTL("HOLD {1} to bind to \"{2}\"", what, lbl),
        Color.new(255, 235, 150), shadow, 0)
      sub = is_btn ?
        _INTL("(D-Pad works too. Esc cancels. Keyboard keys are set in the F1 menu.)") :
        _INTL("(HOLD a pad button/trigger OR a key -- it auto-detects which slot. Esc cancels.)")
      pbDrawShadowText(bmp, 16, dy + 22, w - 32, 18, sub, Color.new(200, 200, 215), shadow, 0)
      # Hold-progress bar so the player can see the bind is registering.
      frac = [hold_cnt.to_f / [HOLD_FRAMES, 1].max, 1.0].min
      bx = 16; by = dy + 44; bw = w - 32; bh = 7
      bmp.fill_rect(bx, by, bw, bh, Color.new(36, 36, 50, 255))
      bmp.fill_rect(bx, by, (bw * frac).to_i, bh, Color.new(120, 220, 255, 255))
    else
      bmp.font.size = 16 rescue nil
      desc = row_description(rows[sel]).to_s
      maxw = w - 32
      # Greedy word-wrap into up to 3 lines that always fit the strip width, so a
      # long description wraps cleanly instead of overflowing off the screen edge.
      lines = []; cur = ""
      desc.split(" ").each do |word|
        trial = cur.empty? ? word : (cur + " " + word)
        if ((bmp.text_size(trial).width rescue (trial.length * 8)) <= maxw)
          cur = trial
        else
          lines << cur unless cur.empty?
          cur = word
        end
      end
      lines << cur unless cur.empty?
      max_lines = 3
      if lines.length > max_lines
        lines = lines[0, max_lines]
        lines[max_lines - 1] = lines[max_lines - 1].to_s + "..."
      end
      ly = dy
      lines.each do |ln|
        pbDrawShadowText(bmp, 16, ly, maxw, 18, ln, Color.new(225, 225, 240), shadow, 0)
        ly += 18
      end
    end
  rescue
    nil
  end
end

#-------------------------------------------------------------------------------
# Install the input remap override exactly once. Aliases the engine's native
# singleton methods and routes the requested logical button through the remap.
# Identity by default, so this is a no-op until the player rebinds.
#-------------------------------------------------------------------------------
unless defined?($control_rebind_installed) && $control_rebind_installed
  module Input
    class << self
      alias_method :_rebind_orig_trigger?, :trigger?
      alias_method :_rebind_orig_press?,   :press?
      alias_method :_rebind_orig_repeat?,  :repeat?
      def trigger?(b)
        s = ControlRebind.src(b)
        return (ControlRebind.remap_key_edge?(s) || ControlRebind.pad_action_edge?(b)) if s.is_a?(String)
        _rebind_orig_trigger?(s) || ControlRebind.pad_action_edge?(b)
      end
      def press?(b)
        s = ControlRebind.src(b)
        return (ControlRebind.remap_key_down?(s) || ControlRebind.pad_action_down?(b)) if s.is_a?(String)
        _rebind_orig_press?(s) || ControlRebind.pad_action_down?(b)
      end
      def repeat?(b)
        s = ControlRebind.src(b)
        return (ControlRebind.remap_key_down?(s) || ControlRebind.pad_action_down?(b)) if s.is_a?(String)
        _rebind_orig_repeat?(s) || ControlRebind.pad_action_down?(b)
      end
    end
  end
  if Input.respond_to?(:release?)
    module Input
      class << self
        alias_method :_rebind_orig_release?, :release?
        def release?(b)
          s = ControlRebind.src(b)
          return false if s.is_a?(String)
          _rebind_orig_release?(s)
        end
      end
    end
  end
  $control_rebind_installed = true
end

#-------------------------------------------------------------------------------
# Add "Rebind Controls" to the in-game Options menu (already controller-nav).
#-------------------------------------------------------------------------------
class PokemonOption_Scene
  unless method_defined?(:_rebind_orig_pbAddOnOptions)
    alias_method :_rebind_orig_pbAddOnOptions, :pbAddOnOptions
  end
  def pbAddOnOptions(options)
    options = _rebind_orig_pbAddOnOptions(options)
    return options unless self.class == PokemonOption_Scene
    begin
      options.push(ButtonOption.new(
        _INTL("Rebind Controls"),
        proc { ControlRebind.open_menu },
        _INTL("Reassign action buttons and bind a controller button, keyboard key, or mouse button to Multiplayer hotkeys. Fully controller-navigable."),
        _INTL("Open")))
    rescue
    end
    options
  end
end

#-------------------------------------------------------------------------------
# Overworld poller for the MP hotkey bindings (no-op unless the player bound a
# button). Guarded so it can never affect or crash the map update.
#-------------------------------------------------------------------------------
if defined?(Scene_Map)
  class Scene_Map
    unless method_defined?(:_ctrlrebind_orig_update)
      alias_method :_ctrlrebind_orig_update, :update
      def update(*args)
        _ctrlrebind_orig_update(*args)
        ControlRebind.mp_poll rescue nil
      end
    end
  end
end

# Load saved bindings at boot.
ControlRebind.load rescue nil
# Snapshot the engine's boot-time physical-pad map so our Ruby pad layer never
# double-fires a button the engine already maps to the same action.
ControlRebind.kb_native_map rescue nil
# One-time: apply the shipped Cancel/Menu default (Escape + Keypad 0 + Pad B + Start, no
# strays) onto an existing live keybindings file -- the game never refreshes it
# once it exists. Guarded so it runs once and respects later user rebinds.
ControlRebind.ensure_cancel_default_migration! rescue nil
# One-time: bind the controller trigger AXES (L2->F5, R2->F9) and shoulders (L1->L, R1->R)
# so triggers drive Chat/Profile and bumpers page menus. Applies on the next launch.
ControlRebind.ensure_trigger_migration! rescue nil

#-------------------------------------------------------------------------------
# Global confirm/action input de-duplicator.                  [input double-fire]
#
# Some controllers (and some keyboards) deliver a single physical button press
# as TWO rapid trigger? edges: either a duplicated input device firing a frame
# apart, or mechanical contact bounce (press/release/press within a few ms). The
# result is that one Confirm reads as two ("selects twice"). Mouse clicks use a
# different device path and are unaffected -- which matches the reported symptom.
#
# Fix: enforce trigger?'s real contract -- exactly one true per genuine press --
# for the ACTION buttons only (A B C X Y Z L R). After an accepted trigger, any
# further trigger edge for the same button within a short debounce window is
# swallowed. Directional buttons, press? and repeat? are left untouched, so held
# navigation, movement and "mash to escape" are unchanged. For a well-behaved
# single press the behaviour is byte-for-byte identical to before; this ONLY
# removes the spurious second fire.
#
# CONFIRM COALESCER (added): a single physical button can be bound to BOTH
# logical C and logical A at the same time (this is how the fork's controller A
# button was set up). When that happens, one press fires C *and* A on the same
# frame, and screens that accept either read it as a DOUBLE confirm. We treat a
# same-frame C+A pair as one confirm: the redundant A edge is swallowed while C
# is firing. This is a no-op on stock KIF (where one button maps to only one
# logical button, so C and A never co-fire), so original-KIF compatibility is
# preserved.
#-------------------------------------------------------------------------------
$kif_confirm_debug = true unless defined?($kif_confirm_debug)  # TEMP: confirm double-fire diag; set false to silence
unless defined?($input_dedupe_installed) && $input_dedupe_installed
  module InputDedupe
    GUARDED = begin
      [Input::A, Input::B, Input::C, Input::X, Input::Y, Input::Z, Input::L, Input::R]
    rescue
      [11, 12, 13, 14, 15, 16, 17, 18]
    end
    # Frames a guarded button must read UP *continuously* before its single-press
    # latch may re-arm. A duplicate-input device / contact-bouncing controller
    # releases for only 1-2 frames between its two echo edges; a deliberate
    # re-press is far longer, so it is never eaten.
    RELEASE_SUSTAIN = 3
    # ---- Blip-resistant UNIFIED confirm latch tunables ----------------------
    # Read directly off a raw controller (no Steam Input virtual pad), press?
    # can briefly DROP mid-hold (wireless / HID polling jitter). The per-button
    # latch above re-arms after only RELEASE_SUSTAIN(3) UP frames, so such a drop
    # makes ONE physical press fire a SECOND confirm -- the MP-menu "double
    # confirm" that shows up only on the bare exe. The dedicated confirm latch
    # below keys off (C OR A) held and needs a LONGER sustained release to
    # re-arm, plus a min cooldown between accepted confirms, so the jitter echo
    # is swallowed while the first genuine press always passes. Raise these if a
    # double still slips through on a very jittery pad; lower if confirms feel
    # sticky. (No effect under Steam Input, whose virtual pad never jitters.)
    CONFIRM_RELEASE_SUSTAIN = 8   # UP frames (~133ms @60fps) needed to re-arm
    CONFIRM_COOLDOWN        = 10  # min frames (~167ms) between accepted confirms

    # ---- Auto-repeat-resistant MENU CONFIRM (the bare-exe double-select) -----
    # PROVEN by ControlInputLog.txt: on the bare game.exe the engine delivers a
    # HELD confirm button (Pad A -> logical C) as a string of SEPARATE presses --
    # press? falls to 0 for ~19-23 frames mid-hold, then re-asserts with a fresh
    # trigger? edge, roughly every 22-27 frames (engine auto-repeat on the raw SDL
    # device). Each re-assertion is a REAL engine edge, so a slightly-long hold
    # fires a menu confirm 2-5 times. Steam Input hides it (its virtual pad holds a
    # steady level). The repeat GAP (~23f) is longer than the old re-arm(8)+
    # cooldown(10), so neither can span it -- and a fixed gap that DID span it would
    # also eat fast deliberate taps (text-skip). Fix: a VIRTUAL HOLD that bridges
    # those short UP gaps -- asserts on press?, releases only after AUTOREPEAT_BRIDGE
    # CONTINUOUS UP frames (> the worst repeat gap). Its RISING edge fires exactly
    # once per genuine press and NEVER on a repeat pulse. Used only by the menu-
    # confirm consumers (confirm_edge? / edge? / the command-window path), so
    # overworld text-skip and naming -- which read the raw per-button @edge -- are
    # completely unaffected.
    AUTOREPEAT_BRIDGE = 30  # continuous UP frames to end a held burst (~0.5s @60)
    AUTOREPEAT_PHYS_GRACE = 4    # UP frames the raw-HID button must read RELEASED to re-arm
    AUTOREPEAT_MAXHOLD    = 180  # stuck-safety: force-clear a virtual hold after ~3s

    @seq         = 0
    @armed       = {}   # per-button latch: a fresh press may fire
    @up          = {}   # per-button consecutive UP-frame counter
    @edge        = {}   # per-button press?-derived rising edge for the current @seq
    @c_fired_seq = -1   # last @seq logical C produced an edge (C+A coalesce)
    # Prime DISARMED with a satisfied up-counter: the first real press arms then
    # fires, but a button HELD at install / scene-entry is consumed (no leak).
    (GUARDED rescue []).each { |b| @armed[b] = false; @up[b] = 99 }
    # Blip-resistant confirm latch state (primed disarmed; cooldown clear).
    @c_armed = false; @c_up = 99; @c_cool = 0; @confirm_latch = false
    @b_armed = {}; @b_up = {}; @b_cool = {}; @b_edge = {}
    (GUARDED rescue []).each { |b| @b_armed[b] = false; @b_up[b] = 99; @b_cool[b] = 0; @b_edge[b] = false }
    # Auto-repeat virtual-hold state: confirm (C-or-A) + per-button. Primed RELEASED.
    @cv_hold = false; @cv_low = 99; @cv_edge = false
    @bv_hold = {}; @bv_low = {}; @bv_edge = {}
    (GUARDED rescue []).each { |b| @bv_hold[b] = false; @bv_low[b] = 99; @bv_edge[b] = false }
    # Per-frame flag: a command/selectable menu is the active confirm consumer THIS
    # frame (set by the Window_CommandPokemon#update hook, cleared each bump!).
    @ar_active = false

    # Called once per Input.update. We do NOT trust the engine's trigger? EDGE for
    # guarded buttons: a duplicate-input device / bouncing controller delivers ONE
    # physical press as TWO trigger? edges a frame or two apart, and that echo
    # leaks into whatever screen reads confirm next -- e.g. a mini command popup
    # that opens instantly then auto-selects its first item (the "mini menus fire
    # twice" report). press? is a LEVEL with no such bounce, so we derive our OWN
    # rising edge from it here, latched per button: it fires EXACTLY once per
    # physical press and only re-arms after a SUSTAINED release. Immune to the
    # double-edge AND to the popup-open leak (the opening press is consumed; the
    # next in-popup confirm requires a real release first).
    def self.bump!
      @seq += 1
      @ar_active = false
      @armed ||= {}; @up ||= {}; @edge ||= {}
      GUARDED.each do |b|
        down = (Input.press?(b) rescue false) ? true : false
        if down
          @up[b] = 0
        else
          @up[b] = (@up[b] || 0) + 1
          @armed[b] = true if @up[b] >= RELEASE_SUSTAIN   # re-arm only after a sustained release
        end
        fired = (@armed[b] && down) ? true : false
        @armed[b] = false if fired                        # consume
        @edge[b] = fired
      end
      # C+A coalesce: a face button bound to BOTH logical C and A fires both edges
      # the same frame; keep C, drop the redundant A so a menu reading both does
      # not double-act. No-op on stock KIF (one source -> one logical button).
      if (@edge[Input::C] && @edge[Input::A] rescue false)
        @edge[Input::A] = false
      end

      # ---- Blip-resistant UNIFIED confirm latch (drives confirm_edge?) -------
      # Keyed off the HELD level of (C OR A), NOT the per-button edges above, so
      # two edges spread across adjacent frames -- or a press? that drops then
      # re-asserts mid-hold on a raw pad -- collapse into ONE confirm. Re-arms
      # only after CONFIRM_RELEASE_SUSTAIN sustained UP frames and refuses a new
      # confirm within CONFIRM_COOLDOWN frames of the last accepted one.
      c_down = ((Input.press?(Input::C) rescue false) || (Input.press?(Input::A) rescue false)) ? true : false
      if c_down
        @c_up = 0
      else
        @c_up = (@c_up || 99) + 1
        @c_armed = true if @c_up >= CONFIRM_RELEASE_SUSTAIN
      end
      @c_cool -= 1 if (@c_cool || 0) > 0
      c_fire = (@c_armed && c_down && (@c_cool || 0) <= 0) ? true : false
      if c_fire
        @c_armed = false
        @c_cool  = CONFIRM_COOLDOWN
      end
      @confirm_latch = c_fire

      # ---- Blip-resistant PER-BUTTON latch (drives edge?, used by the Cases
      # buy/open screen where C and A are DISTINCT actions). Same debounce as the
      # confirm latch, tracked independently per button so C and A never merge.
      @b_up ||= {}; @b_armed ||= {}; @b_cool ||= {}; @b_edge ||= {}
      GUARDED.each do |b|
        bd = (Input.press?(b) rescue false) ? true : false
        if bd
          @b_up[b] = 0
        else
          @b_up[b] = (@b_up[b] || 99) + 1
          @b_armed[b] = true if @b_up[b] >= CONFIRM_RELEASE_SUSTAIN
        end
        @b_cool[b] = (@b_cool[b] || 0) - 1 if (@b_cool[b] || 0) > 0
        bf = (@b_armed[b] && bd && (@b_cool[b] || 0) <= 0) ? true : false
        if bf
          @b_armed[b] = false
          @b_cool[b]  = CONFIRM_COOLDOWN
        end
        @b_edge[b] = bf
      end

      # ---- Auto-repeat-resistant MENU CONFIRM (engine-only, universal) ------
      # ROOT CAUSE (proven, ControlInputLog): the bare-exe engine delivers a HELD
      # confirm button as periodic press/release PULSES (~3 down / ~20 up), so a
      # slightly-long hold fires a menu confirm 2-5x. We bridge those engine UP gaps
      # with a virtual hold: it asserts on press? and clears only after
      # AUTOREPEAT_BRIDGE continuous UP frames (> the worst gap), so exactly ONE
      # rising edge per genuine press. EXEMPT only while dialogue text is advancing
      # (a message window is up and NO command window), where each pulse SHOULD
      # re-fire so holding/mashing skips text fast. Every confirm consumer (filter
      # C/A, confirm_edge?, edge?) reads this -> covers MP menus, vanilla popups and
      # mod dropdowns alike with no per-menu code, no controller-read dependency.
      msg_showing  = ($game_temp.message_window_showing rescue false) ? true : false
      # Dialogue hold-to-skip exemption (lets a held Confirm auto-repeat to advance
      # text) must apply ONLY to genuine field/battle dialogue -- NOT to a menu that
      # happens to pop a message/help window. Inside a menu ($game_temp.in_menu) we
      # keep the physical-hold protection so a held Pad A can never re-fire a 2nd
      # confirm once a message appears (the "first press single, then doubles" bug).
      in_menu_now  = ($game_temp.in_menu rescue false) ? true : false
      text_advance = (msg_showing && !@ar_active && !in_menu_now) ? true : false
      @bv_hold ||= {}; @bv_low ||= {}; @bv_edge ||= {}; @bv_phys ||= {}; @bv_age ||= {}
      # Logical Confirm -> backing physical SDL face button (Pad A=0 -> C, Pad X=2 -> A/Action).
      # For these two the HELD state is driven by the RAW-HID physical button, which (unlike
      # the engine's press?) does NOT auto-repeat and stays reliable even when press? drops
      # mid-hold. This makes Confirm crisp 1:1: it clears the instant the face button is
      # physically released, so a held Pad A cannot auto-repeat into a 2nd confirm, yet a
      # fast genuine re-tap (real release between) still fires. Keyboard / HID-blind pads
      # have no phys signal and fall back to the original press?-gap bridge unchanged.
      # Physical SDL face buttons that can drive each logical confirm. Pad A (0) is
      # commonly bound to BOTH logical C and logical A, and Pad X (2) to Action, so
      # logical A must treat EITHER as its physical hold -- otherwise a held Pad A
      # drives @bv_edge[A] through the unreliable press? path and auto-repeats.
      bv_phys_sdl = { Input::C => [0], Input::A => [0, 2] }
      GUARDED.each do |b|
        d    = (Input.press?(b) rescue false) ? true : false
        prev = @bv_hold[b]
        if text_advance
          # DIALOGUE: pure press? behaviour so a HELD Confirm auto-repeats and
          # fast-forwards text (the message loop reads trigger? -> this edge). The
          # physical-hold path is deliberately skipped while advancing text.
          @bv_hold[b] = d ? true : false
          @bv_low[b]  = 0 if d
          @bv_phys[b] = false; @bv_age[b] = 0
        else
          # MENU: for Confirm (C) / Action (A) the HELD state is driven by the RAW-HID
          # physical face button (Pad A=0, Pad X=2). The physical bit does NOT auto-repeat
          # and stays valid even when press? drops mid-hold, giving crisp one-confirm-per-
          # press immune to the bare-exe auto-repeat double; a real release lets a fast
          # re-tap fire. Other buttons + keyboard / HID-blind pads keep the press?-gap path.
          sdls  = bv_phys_sdl[b]
          pheld = (sdls && sdls.any? { |x| (ControlRebind.phys_down?(x) rescue false) }) ? true : false
          if d || pheld
            @bv_hold[b] = true; @bv_low[b] = 0
            @bv_phys[b] = true if pheld             # this hold-cycle is backed by the real pad
            @bv_age[b]  = (@bv_age[b] || 0) + 1
          else
            @bv_low[b] = (@bv_low[b] || 99) + 1
            if @bv_phys[b]
              @bv_hold[b] = false if @bv_low[b] >= AUTOREPEAT_PHYS_GRACE   # pad-backed: clear only after a short jitter-tolerant physical release (raw HID can drop 1-2 frames)
            elsif @bv_low[b] >= AUTOREPEAT_BRIDGE
              @bv_hold[b] = false                   # keyboard / HID-blind: bridge the press? auto-repeat gap
            end
            unless @bv_hold[b]
              @bv_phys[b] = false; @bv_age[b] = 0   # hold ended -> reset the pad-backed flag
            end
          end
          # Stuck-safety: never let one hold persist forever (e.g. a wedged HID read);
          # after ~3s force it open so Confirm can never die permanently.
          if @bv_hold[b] && (@bv_age[b] || 0) > AUTOREPEAT_MAXHOLD
            @bv_hold[b] = false; @bv_phys[b] = false; @bv_age[b] = 0
          end
        end
        @bv_edge[b] = (@bv_hold[b] && !prev) ? true : false
      end

      # Confirm = logical C OR A, collapsed to one edge.
      @cv_edge = (@bv_edge[Input::C] || @bv_edge[Input::A]) ? true : false

      # ---- TEMP confirm diagnostic (gated by $kif_confirm_debug; remove after confirm) ----
      if $kif_confirm_debug
        begin
          pc  = (Input.press?(Input::C) rescue false) ? 1 : 0
          ph0 = (ControlRebind.phys_down?(0) rescue false) ? 1 : 0
          ph2 = (ControlRebind.phys_down?(2) rescue false) ? 1 : 0
          if @bv_edge[Input::C] || @bv_edge[Input::A] || pc==1 || ph0==1 || ph2==1
            InputDedupe.dbg("Cedge=#{@bv_edge[Input::C] ? 1 : 0} Aedge=#{@bv_edge[Input::A] ? 1 : 0} pressC=#{pc} hold=#{@bv_hold[Input::C] ? 1 : 0} low=#{@bv_low[Input::C]} age=#{@bv_age[Input::C]} phys0=#{ph0} phys2=#{ph2} pbackC=#{@bv_phys[Input::C] ? 1 : 0} msg=#{msg_showing ? 1 : 0} ar=#{@ar_active ? 1 : 0} txt=#{text_advance ? 1 : 0}")
          end
        rescue
        end
      end
    rescue
      nil
    end

    # TEMP confirm diagnostic sink (ENOENT-safe; no popup). Writes Logs/confirm_debug.log.
    def self.dbg(msg)
      return unless $kif_confirm_debug
      begin
        dir = (File.expand_path("Logs") rescue "Logs")
        Dir.mkdir(dir) unless (File.directory?(dir) rescue false)
        File.open(File.join(dir, "confirm_debug.log"), "a:UTF-8") { |fh| fh.puts("[#{(Graphics.frame_count rescue 0)}] #{msg}") }
      rescue
        nil
      end
    end

    def self.guarded?(b)
      GUARDED.include?(b)
    end

    # Set by the Window_CommandPokemon#update hook: a command/selectable menu is
    # driving input THIS frame, so filter() should auto-repeat-suppress C/A. Cleared
    # at the top of every bump! (one Input.update later).
    def self.mark_command_window_active
      @ar_active = true
    rescue
      nil
    end

    # For guarded buttons return our press?-derived single-press edge (computed
    # once per @seq in bump!), IGNORING the engine's raw trigger? (which double-
    # fires on a bouncy device). Unguarded buttons pass through unchanged.
    def self.filter(b, raw_val)
      return raw_val unless guarded?(b)
      # CONFIRM (logical C / USE): pass the RAW engine edge straight through -- exactly
      # like clean OG KIF, which never double-fires. User logs proved the engine fires
      # trigger?(C) exactly ONCE per Pad A press (engT=1 once); the de-dup virtual-hold
      # below is what ADDED the bare-exe second edge, so we simply do not apply it to C.
      # (The MP-confirm bridge already no longer remaps C, so this raw edge is what every
      # menu sees.) Chat-typing lock + trigger-as-Cancel suppressor wrap this and still apply.
      return (raw_val ? true : false) if b == Input::C
      # Action (A) keeps the de-dup edge so the Action button stays single AND drives
      # confirm_edge? for the Multiplayer menus.
      if b == Input::A
        @bv_edge ||= {}
        return @bv_edge[b] ? true : false
      end
      @edge ||= {}
      @edge[b] ? true : false
    rescue
      raw_val
    end

    # ---- Unified confirm edge (shared by the MP bridge + MPMenuConfirm) -----
    # @edge is the game's single source of truth for "this button was freshly
    # pressed THIS frame": computed ONCE per Input.update (bump!) from the
    # press? LEVEL, true for exactly ONE frame per physical press, re-armed
    # only after a sustained release, immune to hardware double edges, with a
    # same-frame C+A double-binding coalesced to C. Exposing it lets every MP
    # confirm consumer read this SAME latch. (Previously the bridge and
    # MPMenuConfirm each kept a PRIVATE latch beside this one; one physical
    # press could then be consumed once per latch -- firing again in the
    # screen a menu had just opened (popup double-fire) -- while the private
    # latches' activation/poll-gap disarms could eat the first press in menus
    # that poll intermittently (the press-twice symptom).)
    def self.edge?(b)
      # Blip-resistant per-button edge (Cases buy/open use C and A distinctly).
      # Falls back to the raw per-button edge for any non-guarded button.
      if guarded?(b)
        return (@bv_edge && @bv_edge[b]) ? true : false
      end
      @edge ? (@edge[b] ? true : false) : false
    rescue
      false
    end

    # One logical Confirm: logical C (USE) or logical A (ACTION). Thanks to
    # the C+A coalesce in bump! this is exactly one TRUE frame per physical
    # press no matter how Confirm is bound (Pad A on C, on A, or on both).
    def self.confirm_edge?
      # Single blip-resistant confirm (see bump!): exactly one TRUE frame per
      # physical confirm press, immune to the raw-controller press? jitter that
      # made the MP menus double-confirm on the bare exe but not under Steam Input.
      ((@bv_edge && (@bv_edge[Input::C] || @bv_edge[Input::A])) || @cv_edge) ? true : false
    rescue
      false
    end
  end

  module Input
    class << self
      alias_method :_dedupe_prev_trigger?, :trigger?
      alias_method :_dedupe_prev_update,   :update
      def trigger?(b)
        InputDedupe.filter(b, _dedupe_prev_trigger?(b))
      rescue
        _dedupe_prev_trigger?(b)
      end
      def update(*a)
        _dedupe_prev_update(*a)
        InputDedupe.bump!
      end
    end
  end
  $input_dedupe_installed = true
end

#-------------------------------------------------------------------------------
# Command-window confirm scope.                         [bare-exe double-select]
# Flag the frames a Pokemon command/selectable menu is the active input consumer
# (the party "Do what?" popup, the pause menu, shops, and any mod menu built on
# Window_CommandPokemon / pbShowCommands). InputDedupe.filter then routes logical
# Confirm (C/A) through its auto-repeat-resistant virtual-hold edge ONLY in those
# frames, so a held Pad A can't auto-select a popup on the bare exe. Overworld
# text-skip and naming never update a command window, so they are untouched.
# Window_CommandPokemon has no own #update (it is inherited from
# SpriteWindow_SelectableEx); aliasing here also covers Ex / Color subclasses,
# which do not override it.
#-------------------------------------------------------------------------------
unless defined?($kif_cmdwin_ar_hook) && $kif_cmdwin_ar_hook
  # Hook the BASE selectable-window update so EVERY command / list / selectable menu
  # (Window_CommandPokemon + its Color/Ex subclasses, the party "Do what?" popup, the
  # pause menu, bag, PC, shops, mod command menus) marks itself the active confirm
  # consumer for this frame -> InputDedupe suppresses the held-button auto-repeat there.
  # The dialogue message window is NOT a SpriteWindow_SelectableEx, so text advance is
  # never flagged and fast tap/hold-to-skip stays intact.
  target = if defined?(SpriteWindow_SelectableEx) then SpriteWindow_SelectableEx
           elsif defined?(Window_CommandPokemon)  then Window_CommandPokemon
           end
  if target
    target.class_eval do
      unless method_defined?(:_kif_ar_orig_update)
        alias_method :_kif_ar_orig_update, :update
        def update(*a)
          _kif_ar_orig_update(*a)
          (InputDedupe.mark_command_window_active rescue nil)
        end
      end
    end
  end
  $kif_cmdwin_ar_hook = true
end

#-------------------------------------------------------------------------------
# MP-menu Confirm bridge.                                  [MP menu single-press]
#
# The custom Multiplayer menus (Player List + its per-player action menu, Squad,
# Profile card, Cases, GTS) confirm only on Input::C (== Input::USE). If a player
# unbinds Pad A from C (to stop the double-confirm), their controller's face
# button now maps to Input::A only, so those MP menus stop accepting it -- the
# reported "have to double-tap Pad A to confirm, but only in MP menus" symptom.
#
# Fix: ONLY while an MP modal menu is open, let a Confirm (C/USE) query also
# succeed when the Action button (A) is pressed. Tightly scoped: it does nothing
# in normal gameplay or stock-KIF menus, so original-KIF multiplayer is untouched.
#
# Installed LAST so the chain is bridge -> dedupe -> remap -> engine: the bridged
# A read still passes through the de-duplicator, so it stays a single press.
#-------------------------------------------------------------------------------
unless defined?($mp_confirm_bridge_installed) && $mp_confirm_bridge_installed
  module Input
    class << self
      alias_method :_mpconfirm_prev_trigger?, :trigger?

      # Unified single-press confirm for the Multiplayer menus (F3 Player List,
      # F4 Squad, F6 GTS, F7 Cases, F8 Profile, chat menus -- anything where
      # ControlRebind.mp_confirm_bridge_active? is true).
      #
      # Why this exists: those menus confirm on Input::USE (== C). A controller
      # face button (Pad A) may be bound to logical C, logical A, or BOTH. The
      # global de-duplicator above can swallow the single Pad-A edge inside these
      # menus (its confirm-coalescer drops A when C fired the same frame, and its
      # debounce can clip a press), which is the "have to press Pad A twice" bug.
      #
      # This reads the ENGINE trigger?/press? for the (remapped) C and A buttons
      # directly -- bypassing the de-duplicator entirely -- OR-collapses the C+A
      # double-binding into ONE logical press, and re-arms only after the button is
      # physically released. Net effect: exactly one confirm per real press, no
      # double-fire, no missed first press. Computed once per frame for stability.
      # UNIFIED 2026-06-12: the bridge no longer keeps a PRIVATE latch. It
      # reads the global single-press confirm edge computed once per
      # Input.update by InputDedupe.bump! (press?-derived; one TRUE frame per
      # physical press; re-arms only after a sustained release; C+A
      # double-binding coalesced). Every confirm consumer now shares that ONE
      # latch, so a press consumed in one screen can never fire again in the
      # screen it opened (the mini-popup double-fire), and there are no
      # per-menu activation/poll-gap disarms left to eat a first press (the
      # double-press-to-interact symptom). The opening press cannot leak into
      # a new menu either: its edge lives for exactly the one frame in which
      # the OPENING screen consumed it, and every menu loop here runs
      # Graphics.update + Input.update before polling, which recomputes the
      # edge to false while the button is still held.
      def _mpc_confirm_single?
        InputDedupe.confirm_edge?
      rescue
        false
      end

      def trigger?(b)
        active = (ControlRebind.mp_confirm_bridge_active? rescue false)
        # ONLY remap the ACTION button (A) to the shared confirm edge -- NEVER the
        # Confirm button (C). Remapping C made trigger?(C) return confirm_edge? (C OR A),
        # so a stray A edge (or a stuck MP flag) leaked a PHANTOM second confirm into
        # every menu that reads trigger?(C) -- the bare-exe "Pad A double-fire". C now
        # always reads its own single de-duped edge; the Action button still confirms in
        # MP menus via this A path + the explicit trigger?(ACTION)/MPMenuConfirm reads.
        if b == Input::A && active   # ACTION==A only
          return _mpc_confirm_single?
        end
        _mpconfirm_prev_trigger?(b)
      rescue
        _mpconfirm_prev_trigger?(b)
      end
    end
  end
  $mp_confirm_bridge_installed = true
end

#-------------------------------------------------------------------------------
# Per-frame GLOBAL hooks (run in EVERY scene via Input.update):
#   1) refresh the frame-stable state of any keyboard key bound to an action row
#   2) poll the global HUD/chat min-max toggle (Tab by default) so it works in
#      menus, battles, etc -- not just the overworld.
# Installed last so it wraps the de-dup/bridge chain. Fully guarded.
#-------------------------------------------------------------------------------
unless defined?($control_rebind_frame_hook) && $control_rebind_frame_hook
  module Input
    class << self
      alias_method :_ctrlrebind_prev_update, :update
      def update(*a)
        _ctrlrebind_prev_update(*a)
        ControlRebind.poll_remap_keys! rescue nil
        ControlRebind.phys_poll! rescue nil
        ControlRebind.global_poll rescue nil
      end
    end
  end
  $control_rebind_frame_hook = true
end

#-------------------------------------------------------------------------------
# Trigger-as-Cancel suppressor.                         [LT must not act as Esc]
#
# On the bare exe the engine's default SDL game-controller map fires a logical
# button (Cancel / B for the LEFT trigger) when an analog trigger is pulled, so
# pulling LT closes menus / opens the pause menu -- even though the fork now uses
# LT as a Multiplayer hotkey (Chat). The engine map cannot be hot-reloaded, so
# the spurious Cancel is swallowed HERE: while a raw-HID / XInput trigger is
# pulled AND the real Cancel button (Circle / Pad B) is NOT physically held,
# Input's Cancel reads return false. Real Circle / Esc presses are unaffected
# (Circle held -> not suppressed), and it is inert unless a pad with readable
# triggers is live. The decision is cached once per frame in phys_poll!.
# Installed LAST so it wraps the de-dup / confirm-bridge chain.
#-------------------------------------------------------------------------------
unless defined?($trigger_cancel_suppressor_installed) && $trigger_cancel_suppressor_installed
  module Input
    class << self
      alias_method :_trigsupp_prev_trigger?, :trigger?
      alias_method :_trigsupp_prev_press?,   :press?
      alias_method :_trigsupp_prev_repeat?,  :repeat?
      def trigger?(b)
        return false if b == Input::B && (ControlRebind.trigger_suppresses_cancel? rescue false)
        _trigsupp_prev_trigger?(b)
      rescue
        _trigsupp_prev_trigger?(b)
      end
      def press?(b)
        return false if b == Input::B && (ControlRebind.trigger_suppresses_cancel? rescue false)
        _trigsupp_prev_press?(b)
      rescue
        _trigsupp_prev_press?(b)
      end
      def repeat?(b)
        return false if b == Input::B && (ControlRebind.trigger_suppresses_cancel? rescue false)
        _trigsupp_prev_repeat?(b)
      rescue
        _trigsupp_prev_repeat?(b)
      end
    end
  end
  $trigger_cancel_suppressor_installed = true
end

#-------------------------------------------------------------------------------
# MPMenuConfirm -- bullet-proof single-press confirm for the custom Multiplayer
# menus (Player List, Cases, Profile).                    [single-press confirm]
#
# Those menus kept needing TWO controller presses to confirm. The global confirm
# bridge above tries to fix that transparently, but it depends on a chain of
# conditions (mp_confirm_bridge_active?, the engine trigger? edge, per-frame
# caching) and a weak link anywhere re-exposes the double-press. This helper
# sidesteps all of it: each menu calls MPMenuConfirm.pressed?(:its_key) DIRECTLY
# and we derive the rising edge ourselves from the raw HELD state (press?) of the
# confirm buttons, latched so it fires EXACTLY ONCE per physical press and only
# re-arms after a full release. It cannot double-fire and never eats the first
# press (the latch starts disarmed, so the press that OPENED the menu is consumed
# automatically -- you must release before the first in-menu confirm registers).
#
# press? is read straight off the rebind layer (NOT trigger?), so it bypasses the
# de-duplicator and the confirm bridge entirely; the keyboard confirm (Z/Enter ==
# C) and a controller face button mapped to logical C or A both drive it.
#-------------------------------------------------------------------------------
unless defined?($mp_menu_confirm_installed) && $mp_menu_confirm_installed
  module MPMenuConfirm
    @state = {}
    module_function

    # UNIFIED 2026-06-12: MPMenuConfirm used to keep a PRIVATE per-menu latch
    # (press?-derived, with poll-gap + activation disarms). Running its own
    # latch beside the global de-duplicator's meant ONE physical press could
    # be consumed once by EACH latch: a menu fired via this latch, then the
    # screen it opened fired again via the bridge/dedupe latch -- the
    # mini-popup double-fire. Meanwhile its disarm rules could eat the first
    # press in menus that poll intermittently (e.g. from an elsif chain) --
    # the press-twice symptom. It now simply reads the global single-press
    # confirm edge computed once per Input.update in InputDedupe.bump!: one
    # TRUE frame per physical press, shared by EVERY confirm consumer, so a
    # press fires exactly once game-wide. The per-menu `key` is kept only for
    # API compatibility.
    def pressed?(key = :default)
      InputDedupe.confirm_edge?
    rescue
      false
    end

    # Single-button variant: keeps menus that map C and A to DIFFERENT actions
    # (e.g. the Case buy/open screen) working without collapsing the two buttons.
    def button_pressed?(button, key)
      InputDedupe.edge?(button)
    rescue
      false
    end

    def reset(key = :default)
      (@state ||= {})[key] = { armed: false, frame: -2, val: false }
    rescue
      nil
    end
  end
  $mp_menu_confirm_installed = true
end

#-------------------------------------------------------------------------------
# Hold-B quick-exit: wrap Scene_Map#call_menu so a ~0.5s B hold from any depth
# of the overworld menu stack instantly returns the player to the overworld.
#
# Design:
#   * global_poll (runs every Input.update, including inside menu loops) calls
#     poll_hold_b_exit, which counts consecutive frames B is held.
#   * When the threshold is reached it calls Graphics.freeze (snapshot) then
#     throw(:kifm_back_to_overworld).
#   * Ruby's `throw` is NOT an exception -- `rescue` blocks do NOT stop it.
#     It unwinds the call stack running `ensure` blocks until the matching
#     `catch` below is found.
#   * $kifm_in_menu_chain guards the throw so it only fires when the catch is
#     actually on the stack (set true just before the catch, false in ensure).
#   * After catch returns, GC.start forces disposal of any leaked menu sprites
#     whose EndScene was skipped. Graphics.transition(8) fades from the frozen
#     snapshot to the live overworld.
#   * ensure always resets in_menu and the chain flag regardless of exit path.
#-------------------------------------------------------------------------------
$kifm_in_menu_chain = false unless defined?($kifm_in_menu_chain)
# True for the whole duration of one overworld Scene_Map#update (see the
# Scene_Map#main wrapper below). Lets hold-B fire from menus opened by mod
# hotkeys / field menus that bypass call_menu entirely.
$kifm_in_overworld_update = false unless defined?($kifm_in_overworld_update)
# Pre-menu live-graphics snapshot for the universal (non-call_menu) exit path.
$kifm_update_baseline = nil unless defined?($kifm_update_baseline)

if defined?(Scene_Map) && !Scene_Map.method_defined?(:_hold_b_exit_orig_call_menu)
  class Scene_Map
    alias_method :_hold_b_exit_orig_call_menu, :call_menu
    def call_menu
      ControlRebind.hold_b_exit_count_reset rescue nil
      $kifm_in_menu_chain = true
      throw_happened = true                  # flipped to false on normal exit
      pre_menu_graphics = (ControlRebind.snapshot_live_graphics rescue nil)
      catch(:kifm_back_to_overworld) do
        _hold_b_exit_orig_call_menu
        throw_happened = false
      end
      if throw_happened
        # The throw unwound past every menu's disposal code (none of it is in an
        # `ensure`), so their Windows/Sprites are still drawn. GC.start cannot
        # dispose RGSS graphics -- explicitly dispose everything created during
        # the menu chain BEFORE fading back, or the menus stay stacked on screen.
        (ControlRebind.dispose_leaked_graphics(pre_menu_graphics) rescue nil)
        GC.start rescue nil
        (Graphics.transition(8) rescue nil)
      end
    ensure
      $kifm_in_menu_chain = false
      ($game_temp.in_menu = false) rescue nil
      ControlRebind.hold_b_exit_count_reset rescue nil
    end
  end
end

#-------------------------------------------------------------------------------
# UNIVERSAL hold-B catch -- wrap the overworld FRAME LOOP (Scene_Map#main) so a
# B hold also exits menus that BYPASS call_menu: mod hotkey menus, field/QoL
# menus, "Mod Settings", Ball Seals, etc. Each such menu runs its own loop
# nested inside ONE Scene_Map#update call, so a catch around that per-frame
# update() dominates them all -- regardless of how many mods alias #update,
# because mods wrap #update, never #main, leaving this the outermost guard.
#
# The pause-menu chain keeps its own inner call_menu catch; a throw lands on
# whichever catch is nearest (call_menu for the pause chain, this one for
# everything else) and both unwind cleanly back to the live overworld.
#-------------------------------------------------------------------------------
if defined?(Scene_Map) && !Scene_Map.method_defined?(:_kifm_guarded_update)
  class Scene_Map
    # One overworld frame, with the hold-B quick-exit catch wrapped around the
    # (possibly mod-aliased) #update chain. Any menu opened during this update
    # -- a hotkey poll, Events.onMapUpdate, a field menu -- unwinds to here.
    def _kifm_guarded_update
      $kifm_in_overworld_update = true
      $kifm_update_baseline = nil
      threw = true
      catch(:kifm_back_to_overworld) do
        update
        threw = false
      end
      if threw
        # The throw skipped every menu's disposal (none of it is in an ensure).
        # GC.start can't free RGSS C-backed Window/Sprite/Viewport, so dispose
        # anything created after the pre-menu snapshot, then fade the frozen
        # last-menu frame to the live overworld.
        (ControlRebind.dispose_leaked_graphics($kifm_update_baseline) rescue nil)
        GC.start rescue nil
        (Graphics.transition(8) rescue nil)
      end
    ensure
      $kifm_in_overworld_update = false
      $kifm_update_baseline = nil
      ($game_temp.in_menu = false) rescue nil
      ControlRebind.hold_b_exit_count_reset rescue nil
    end

    # Re-implementation of the stock overworld loop (002_Scene_Map.rb#main) that
    # routes the per-frame update through _kifm_guarded_update. Kept byte-faithful
    # to the original aside from that one call.
    alias_method :_kifm_orig_main, :main
    def main
      createSpritesets
      Graphics.transition(20)
      loop do
        Graphics.update
        Input.update
        _kifm_guarded_update
        break if $scene != self
      end
      Graphics.freeze
      dispose
      if $game_temp.to_title
        Graphics.transition(20)
        Graphics.freeze
      end
    end
  end
end
