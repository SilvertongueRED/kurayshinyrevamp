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
  @mp_bind = {}
  @vk_last = {}

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
      [Input::C, _INTL("Confirm")],
      [Input::B, _INTL("Cancel")],
      [Input::A, _INTL("Action")],
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
      Input::C => _INTL("Confirm / interact / advance text. The main \"yes\" button."),
      Input::B => _INTL("Cancel / back out of menus. Hold while walking to run."),
      Input::A => _INTL("Action button: opens the Ready Menu (registered items) and acts as a secondary confirm in some screens."),
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
      [:squad,   _INTL("MP: Squad menu (F4)")],
      [:players, _INTL("MP: Player list (F3)")],
      [:chat,    _INTL("MP: Chat (T / F10)")],
      [:gts,     _INTL("MP: GTS (F6)")],
      [:cases,   _INTL("MP: Cases (F7)")],
      [:profile, _INTL("MP: Profile card (F8)")],
      [:hud,     _INTL("MP: Min/Max HUD+Chat")]
    ]
  end

  def self.mp_action_descriptions
    {
      :squad   => _INTL("Open/close the Squad menu (co-op party)."),
      :players => _INTL("Open/close the online Player List."),
      :chat    => _INTL("Toggle the chat box."),
      :gts     => _INTL("Open the Global Trade System."),
      :cases   => _INTL("Open the Cases menu."),
      :profile => _INTL("Toggle your own Profile card."),
      :hud     => _INTL("Minimise / maximise the multiplayer HUD and chat.")
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

  # Buttons assignable to an MP action. nil = unbound, then the spare controller
  # buttons, then every keyboard/mouse source (stored as its token String).
  # The d-pad/stick is deliberately excluded so movement can never be hijacked.
  def self.mp_assignable
    [nil, Input::A, Input::X, Input::Y, Input::Z, Input::L, Input::R] +
      trigger_buttons +
      key_sources.map { |tok, _l, _vk| tok }
  end

  def self.mp_bind
    @mp_bind ||= {}
  end

  def self.mp_cycle(action, dir)
    list = mp_assignable
    cur  = mp_bind[action]
    i    = list.index(cur) || 0
    mp_bind[action] = list[(i + dir) % list.length]
  rescue
    nil
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
  MP_DEFAULT_KEYS = { :squad => "F4", :players => "F3", :chat => "T/F10",
                      :gts => "F6", :cases => "F7", :profile => "F8",
                      :hud => "" } unless const_defined?(:MP_DEFAULT_KEYS)
  def self.mp_open_label(key)
    base = (MP_DEFAULT_KEYS[key] || "").to_s
    b = (mp_bind[key] rescue nil)
    if base.empty?
      b ? mp_source_name(b) : "-"
    else
      b ? "#{base} / #{mp_source_name(b)}" : base
    end
  rescue
    (MP_DEFAULT_KEYS[key] rescue "") || ""
  end

  def self.defaults
    h = {}
    buttons.each { |b| h[b] = b }
    h
  end

  def self.ensure_init
    @remap = defaults if !@remap || @remap.empty?
    @mp_bind ||= {}
    @vk_last ||= {}
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

  # Default MP hotkey bindings. Tab is bound to the HUD min/max toggle out of
  # the box (works everywhere via the global poller below); rebindable in menu.
  def self.defaults_mp
    { :hud => "Tab" }
  end

  def self.reset!
    @remap = defaults
    @mp_bind = defaults_mp.dup
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
    mp_bind.each do |act, b|
      next if b.nil?
      val = b.is_a?(String) ? "K:#{b}" : source_name(b)
      lines << "MP:#{act}=#{val}"
    end
    File.open(bind_path, "w") { |f| f.write(lines.join("\n")) }
  rescue
    nil
  end

  def self.load
    @remap = defaults
    @mp_bind = defaults_mp.dup
    return unless File.exist?(bind_path)
    name_to_btn = {}
    assignable_sources.each { |b| name_to_btn[source_name(b)] = b }
    # Back-compat: older saves used "LT"/"RT" labels for the two trigger buttons.
    name_to_btn["LT"] = Input::F5 if defined?(Input::F5)
    name_to_btn["RT"] = Input::F9 if defined?(Input::F9)
    File.read(bind_path).each_line do |ln|
      ln = ln.strip
      next if ln.empty?
      if ln.start_with?("MP:")
        k, v = ln.sub("MP:", "").split("=", 2)
        next unless k && v
        if v.start_with?("K:")
          tok = v.sub("K:", "")
          @mp_bind[k.to_sym] = tok if key_token_for(tok)
        else
          b = name_to_btn[v]
          @mp_bind[k.to_sym] = b if b
        end
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
  rescue
    @remap = defaults
    @mp_bind = {}
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
      if defined?(MultiplayerUI) && MultiplayerUI.respond_to?(:toggle_overlays_minimized)
        MultiplayerUI.toggle_overlays_minimized
      end
    end
  rescue
    nil
  end

  # Should this MP source fire this frame? Controller buttons use the engine edge
  # read; keyboard/mouse tokens use GetAsyncKeyState edge detection.
  def self.mp_source_fired?(btn)
    if btn.is_a?(String)
      ent = key_token_for(btn)
      return false unless ent
      vk_edge?(ent[2])
    else
      raw_trigger?(btn)
    end
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

  # Called every overworld frame. Only does anything if the player bound a button.
  def self.mp_poll
    return if @bypass
    return unless @mp_bind && !@mp_bind.empty?
    return unless defined?(MultiplayerClient)
    @mp_bind.each do |action, btn|
      next unless btn
      next if action == :hud   # HUD toggle is polled globally (works in menus/battles)
      mp_trigger(action) if mp_source_fired?(btn)
    end
  rescue
    nil
  end

  # Polled EVERY frame (all scenes) so the HUD/chat min-max toggle works inside
  # menus, battles, etc -- not just the overworld. Only :hud is global; the other
  # MP hotkeys stay overworld-only (you should not open GTS mid-battle).
  def self.global_poll
    return if @bypass
    btn = (@mp_bind && @mp_bind[:hud])
    return unless btn
    mp_trigger(:hud) if mp_source_fired?(btn)
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
    buttons.each { |b| return b if (Input.press?(b) rescue false) }
    trigger_buttons.each { |b| return b if (Input.press?(b) rescue false) }
    [Input::UP, Input::DOWN, Input::LEFT, Input::RIGHT].each do |d|
      return d if (Input.press?(d) rescue false)
    end
    # Keyboard / mouse keys are now bindable to BOTH action rows and MP rows.
    # Controller buttons + directions are checked first (above) so a key that is
    # also a game button maps to the button.
    key_sources.each { |tok, _l, vk| return tok if vk_down?(vk) }
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
      mp_bind[r[:key]] = src
    end
  rescue
    nil
  end

  HOLD_FRAMES = 16 unless const_defined?(:HOLD_FRAMES)  # ~0.27s hold to confirm

  def self.open_menu
    ensure_init
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
        cur = detect_held_source(r[:type])
        if cur.nil?
          armed = true          # everything released -> ready to capture
          hold_src = nil; hold_cnt = 0
        elsif !armed
          # still holding the button that opened capture; wait for release
        elsif cur == hold_src
          hold_cnt += 1
          if hold_cnt >= HOLD_FRAMES
            apply_binding(r, cur)
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
          # Enter classic hold-to-bind: now hold the button/key/mouse to assign.
          listening = true; armed = false; hold_src = nil; hold_cnt = 0
          (pbPlayDecisionSE rescue nil)
          draw_menu(spr.bitmap, rows, sel, true, 0)
        end
      elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
        # Left/Right now CLEARS a binding (btn -> default, MP -> unbound).
        r = rows[sel]
        if r[:type] == :btn
          @remap[r[:key]] = r[:key]; redraw = true; (pbPlayCancelSE rescue nil)
        elsif r[:type] == :mp
          mp_bind[r[:key]] = nil; redraw = true; (pbPlayCancelSE rescue nil)
        end
      elsif Input.trigger?(Input::B) || b_hold >= 18
        (pbPlayCancelSE rescue nil)
        break
      end
    end
    save
    spr.bitmap.dispose if spr.bitmap && !spr.bitmap.disposed?
    spr.dispose unless spr.disposed?
    vp.dispose unless vp.disposed?
  rescue
    nil
  ensure
    @bypass = false
  end

  def self.row_description(r)
    return "" unless r
    case r[:type]
    when :btn   then action_descriptions[r[:key]] || ""
    when :mp    then (mp_action_descriptions[r[:key]] || "") + _INTL("  (bind a controller button, keyboard key, or mouse button)")
    when :reset then _INTL("Restore every action and MP binding to its default.")
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
      _INTL("Up/Down: move    Confirm: rebind    L/R: clear"), dim, shadow, 1)
    pbDrawShadowText(bmp, 0, title_h + 20, w, 18,
      _INTL("Hold a button / key / mouse to assign    Start / Esc: exit"), dim, shadow, 1)

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
          src = @remap[r[:key]] || r[:key]
          changed = (src != r[:key])
          pbDrawShadowText(bmp, x_val, y, 116, rowh - 2, "< #{source_name(src)} >", (changed ? chg : col), shadow, 0)
        else
          b = mp_bind[r[:key]]
          pbDrawShadowText(bmp, x_val, y, 116, rowh - 2, "< #{mp_source_name(b)} >", (b ? chg : dim), shadow, 0)
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
    pbDrawShadowText(bmp, x_label2, y, colW - 20, rowh - 2, _INTL("- MP hotkeys (button / key / mouse) -"), head, shadow, 0)
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
      lbl = (rows[sel][:label] rescue "this action")
      pbDrawShadowText(bmp, 16, dy, w - 32, 22,
        _INTL("HOLD a button / key / mouse to bind to \"{1}\"", lbl),
        Color.new(255, 235, 150), shadow, 0)
      pbDrawShadowText(bmp, 16, dy + 22, w - 32, 18,
        _INTL("(Esc cancels.  D-Pad works here too.)"), Color.new(200, 200, 215), shadow, 0)
      # Hold-progress bar so the player can see the bind is registering.
      frac = [hold_cnt.to_f / [HOLD_FRAMES, 1].max, 1.0].min
      bx = 16; by = dy + 44; bw = w - 32; bh = 7
      bmp.fill_rect(bx, by, bw, bh, Color.new(36, 36, 50, 255))
      bmp.fill_rect(bx, by, (bw * frac).to_i, bh, Color.new(120, 220, 255, 255))
    else
      bmp.font.size = 18 rescue nil
      desc = row_description(rows[sel]).to_s
      maxw = w - 32
      # word-wrap into up to two lines so a bigger font never runs off the page
      line1 = ""; line2 = ""
      desc.split(" ").each do |word|
        trial = line1.empty? ? word : (line1 + " " + word)
        fits = ((bmp.text_size(trial).width rescue (trial.length * 9)) <= maxw)
        if fits && line2.empty?
          line1 = trial
        else
          line2 = line2.empty? ? word : (line2 + " " + word)
        end
      end
      pbDrawShadowText(bmp, 16, dy, maxw, 24, line1, Color.new(225, 225, 240), shadow, 0)
      pbDrawShadowText(bmp, 16, dy + 26, maxw, 24, line2, Color.new(225, 225, 240), shadow, 0) unless line2.empty?
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
        return ControlRebind.remap_key_edge?(s) if s.is_a?(String)
        _rebind_orig_trigger?(s)
      end
      def press?(b)
        s = ControlRebind.src(b)
        return ControlRebind.remap_key_down?(s) if s.is_a?(String)
        _rebind_orig_press?(s)
      end
      def repeat?(b)
        s = ControlRebind.src(b)
        return ControlRebind.remap_key_down?(s) if s.is_a?(String)
        _rebind_orig_repeat?(s)
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
unless defined?($input_dedupe_installed) && $input_dedupe_installed
  module InputDedupe
    DEBOUNCE_FRAMES = 3  # ~50ms @60fps: the engine's trigger? already requires a
                         # release before a new edge, so a genuine dup-device /
                         # contact bounce lands within 1-2 frames. 6 frames (100ms)
                         # was long enough to also swallow a DELIBERATE second
                         # confirm chained across a screen transition (e.g. pick a
                         # case -> open the case, or pick a player -> pick an
                         # action), which is exactly the "have to press confirm
                         # twice to open anything" report. 3 frames still kills the
                         # double-FIRE while never touching a real re-press (>120ms).
    GUARDED = begin
      [Input::A, Input::B, Input::C, Input::X, Input::Y, Input::Z, Input::L, Input::R]
    rescue
      [11, 12, 13, 14, 15, 16, 17, 18]
    end

    @seq           = 0
    @last_accept   = {}
    @cache         = {}
    @released      = {}   # has button been released since its last accepted trigger?
    @c_fired_seq   = -1   # last frame logical C produced an accepted trigger

    def self.bump!
      @seq += 1
      # A genuine re-press always has a RELEASE between edges; a hardware double-
      # fire / duplicate-device echo does not. Track releases so we only ever
      # swallow the latter -- a deliberate second confirm is never eaten (kills
      # the "had to press confirm twice to open something" residual).
      @released ||= {}
      GUARDED.each { |b| @released[b] = true unless (Input.press?(b) rescue false) }
    rescue
      nil
    end

    def self.guarded?(b)
      GUARDED.include?(b)
    end

    # Given the engine's raw trigger? result for button b, return the de-duped
    # result. Same-frame repeated reads stay consistent via a per-seq cache.
    def self.filter(b, raw_val)
      return raw_val unless guarded?(b)
      @last_accept ||= {}
      @cache       ||= {}
      @released    ||= {}
      @seq         ||= 0
      s = @seq
      c = @cache[b]
      return c[1] if c && c[0] == s
      result =
        if !raw_val
          false
        else
          last = @last_accept[b]
          if last && (s - last) <= DEBOUNCE_FRAMES && (s - last) >= 0 && !@released[b]
            false           # duplicate edge with NO release between -> bounce, swallow
          else
            @last_accept[b] = s
            @released[b]    = false   # fresh accepted press; not released since
            true
          end
        end
      # ---- confirm coalescing ----
      if result && (b == Input::C rescue false)
        @c_fired_seq = s
      elsif result && (b == Input::A rescue false) && @c_fired_seq == s
        result = false      # C already fired this frame -> A is the redundant twin
      end
      @cache[b] = [s, result]
      result
    rescue
      raw_val
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
      @mpc_frame      = -1
      @mpc_val        = false
      @mpc_was_down   = false   # confirm button physically held on the previous poll
      @mpc_active_was = false   # was the confirm bridge active on the previous poll

      # Return TRUE on exactly the frame a fresh Confirm/Action press BEGINS.
      #
      # We derive the rising edge OURSELVES from the raw engine press? (level) state
      # of the physical buttons bound to logical C and A -- we do NOT trust the
      # engine trigger? edge here. Some controllers deliver one physical press as
      # TWO trigger? edges (the hardware double-fire this whole subsystem exists
      # for). Reading that raw trigger? inside the bridge re-exposed the double in
      # MP menus: the first edge advanced a menu and the second edge (next frame)
      # immediately acted again on the new screen, so the user saw "nothing useful
      # happened, press again" -- the reported double-press. A press?-derived edge
      # fires EXACTLY ONCE per physical press (immune to that bounce) and bypasses
      # the de-duplicator, so the first press is never eaten either.
      #
      # No separate "armed" flag (which previously got stuck FALSE across a menu
      # transition and ate the first press). We only compare against last poll's
      # physical state, and when the bridge first becomes active we treat whatever
      # is currently held as already-consumed (require a release first) so the very
      # press that OPENED the menu can't leak through as an in-menu confirm.
      def _mpc_confirm_single?
        f = (Graphics.frame_count rescue 0)
        return @mpc_val if f == @mpc_frame
        @mpc_frame = f
        cC = (ControlRebind.src(Input::C) rescue Input::C)
        cA = (ControlRebind.src(Input::A) rescue Input::A)
        down = ((_rebind_orig_press?(cC) rescue false) ||
                (_rebind_orig_press?(cA) rescue false)) ? true : false
        @mpc_was_down = down unless @mpc_active_was   # prime on bridge activation
        @mpc_active_was = true
        @mpc_val      = (down && !@mpc_was_down)
        @mpc_was_down = down
        @mpc_val
      rescue
        false
      end

      def trigger?(b)
        active = (ControlRebind.mp_confirm_bridge_active? rescue false)
        if (b == Input::C || b == Input::A) && active   # USE==C, ACTION==A
          return _mpc_confirm_single?
        end
        @mpc_active_was = false unless active   # re-prime next time the bridge opens
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
        ControlRebind.global_poll rescue nil
      end
    end
  end
  $control_rebind_frame_hook = true
end
