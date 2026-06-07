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

  # Sources a player may assign to an action: the 8 action buttons PLUS the four
  # d-pad/stick directions, so the d-pad can be bound too (Left/Right cycles
  # through this whole list in the rebind screen).
  def self.assignable_sources
    buttons + [Input::UP, Input::DOWN, Input::LEFT, Input::RIGHT]
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
    { Input::C => "C", Input::B => "B", Input::A => "A", Input::X => "X",
      Input::Y => "Y", Input::Z => "Z", Input::L => "L", Input::R => "R",
      Input::UP => "Up", Input::DOWN => "Down",
      Input::LEFT => "Left", Input::RIGHT => "Right" }[b] || b.to_s
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

  def self.reset!
    @remap = defaults
    @mp_bind = {}
  end

  def self.bind_path
    File.join(Dir.pwd, "control_bindings.txt")
  rescue
    "control_bindings.txt"
  end

  def self.save
    ensure_init
    lines = buttons.map { |b| "#{source_name(b)}=#{source_name(@remap[b] || b)}" }
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
    @mp_bind = {}
    return unless File.exist?(bind_path)
    name_to_btn = {}
    assignable_sources.each { |b| name_to_btn[source_name(b)] = b }
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
        a = name_to_btn[k]; s = name_to_btn[v]
        @remap[a] = s if a && s
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
      mp_trigger(action) if mp_source_fired?(btn)
    end
  rescue
    nil
  end

  #-----------------------------------------------------------------------------
  # Controller-navigable rebind screen. Uses RAW input (bypass) the whole time so
  # it stays navigable no matter how the player has rebound things.
  #-----------------------------------------------------------------------------
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

    sel    = 0
    redraw = true
    b_hold = 0
    loop do
      Graphics.update
      Input.update
      b_hold = (Input.press?(Input::B) ? b_hold + 1 : 0)
      if redraw
        draw_menu(spr.bitmap, rows, sel)
        redraw = false
      end
      if Input.repeat?(Input::DOWN)
        sel = (sel + 1) % rows.length; redraw = true; (pbPlayCursorSE rescue nil)
      elsif Input.repeat?(Input::UP)
        sel = (sel - 1) % rows.length; redraw = true; (pbPlayCursorSE rescue nil)
      elsif Input.trigger?(Input::RIGHT)
        r = rows[sel]
        if r[:type] == :btn; cycle(r[:key], 1); redraw = true; (pbPlayDecisionSE rescue nil)
        elsif r[:type] == :mp; mp_cycle(r[:key], 1); redraw = true; (pbPlayDecisionSE rescue nil); end
      elsif Input.trigger?(Input::LEFT)
        r = rows[sel]
        if r[:type] == :btn; cycle(r[:key], -1); redraw = true; (pbPlayDecisionSE rescue nil)
        elsif r[:type] == :mp; mp_cycle(r[:key], -1); redraw = true; (pbPlayDecisionSE rescue nil); end
      elsif Input.trigger?(Input::C)
        if rows[sel][:type] == :reset
          reset!; redraw = true; (pbPlayDecisionSE rescue nil)
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

  def self.draw_menu(bmp, rows, sel)
    w = bmp.width
    h = bmp.height
    bmp.clear
    bmp.fill_rect(0, 0, w, h, Color.new(18, 16, 28, 235))
    base   = Color.new(255, 255, 255)
    shadow = Color.new(0, 0, 0)
    dim    = Color.new(170, 170, 190)
    selc   = Color.new(120, 220, 255)
    head   = Color.new(150, 255, 180)
    chg    = Color.new(255, 225, 120)
    pbSetSystemFont(bmp)

    # ---- Vertical layout: scale so the rows fill the screen down to a small
    # bottom margin, with a reserved description strip just above it. ----
    title_h  = 34
    hint_h   = 22
    top      = title_h + hint_h + 8          # first row y
    desc_h   = 40                            # description strip at the bottom
    bottom_margin = 10
    # Right column has the most rows: MP header + mp_actions + reset.
    right_rows = mp_actions.length + 1
    avail = h - top - desc_h - bottom_margin
    # +1 accounts for the MP header line occupying one row slot.
    rowh = (avail / (right_rows + 1).to_f).floor
    rowh = 30 if rowh < 30
    rowh = 60 if rowh > 60
    val_font = [(rowh * 0.62).to_i, 16].max
    val_font = 30 if val_font > 30

    bmp.font.size = title_h - 6 rescue nil
    pbDrawShadowText(bmp, 0, 6, w, title_h, _INTL("Rebind Controls"), selc, shadow, 1)
    bmp.font.size = 16 rescue nil
    pbDrawShadowText(bmp, 0, title_h + 4, w, hint_h,
      _INTL("Up/Down: move   Left/Right: change   Hold B / Esc: save & exit"),
      dim, shadow, 1)

    btn_rows = (0...rows.length).select { |i| rows[i][:type] == :btn }
    other    = (0...rows.length).select { |i| rows[i][:type] != :btn }

    colW = w / 2
    bmp.font.size = val_font rescue nil

    draw_one = proc do |i, x_label, x_val, y|
      r   = rows[i]
      col = (sel == i) ? selc : base
      if (sel == i)
        bmp.fill_rect(x_label - 6, y, (x_val + 116) - (x_label - 6), rowh - 2, Color.new(70, 90, 140, 120))
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

    # ---- Description strip for the highlighted row. ----
    dy = h - desc_h - bottom_margin + 4
    bmp.fill_rect(16, dy - 6, w - 32, 2, Color.new(90, 90, 110, 200))
    bmp.font.size = 17 rescue nil
    pbDrawShadowText(bmp, 22, dy, w - 44, desc_h, row_description(rows[sel]), Color.new(220, 220, 235), shadow, 0)
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
      def trigger?(b); _rebind_orig_trigger?(ControlRebind.src(b)); end
      def press?(b);   _rebind_orig_press?(ControlRebind.src(b));   end
      def repeat?(b);  _rebind_orig_repeat?(ControlRebind.src(b));  end
    end
  end
  if Input.respond_to?(:release?)
    module Input
      class << self
        alias_method :_rebind_orig_release?, :release?
        def release?(b); _rebind_orig_release?(ControlRebind.src(b)); end
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
    DEBOUNCE_FRAMES = 6  # ~100ms @60fps: covers dup-device + contact bounce,
                         # well under a human's deliberate double-tap (>150ms).
    GUARDED = begin
      [Input::A, Input::B, Input::C, Input::X, Input::Y, Input::Z, Input::L, Input::R]
    rescue
      [11, 12, 13, 14, 15, 16, 17, 18]
    end

    @seq           = 0
    @last_accept   = {}
    @cache         = {}
    @c_fired_seq   = -1   # last frame logical C produced an accepted trigger

    def self.bump!
      @seq += 1
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
      @seq         ||= 0
      s = @seq
      c = @cache[b]
      return c[1] if c && c[0] == s
      result =
        if !raw_val
          false
        else
          last = @last_accept[b]
          if last && (s - last) <= DEBOUNCE_FRAMES && (s - last) >= 0
            false           # spurious duplicate edge / bounce -> swallow it
          else
            @last_accept[b] = s
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
      def trigger?(b)
        base = _mpconfirm_prev_trigger?(b)
        return base if base
        if (b == Input::C) && (ControlRebind.mp_confirm_bridge_active? rescue false)
          return _mpconfirm_prev_trigger?(Input::A)
        end
        base
      rescue
        _mpconfirm_prev_trigger?(b)
      end
    end
  end
  $mp_confirm_bridge_installed = true
end
