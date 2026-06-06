#===============================================================================
# Controller-navigable Control Rebinding                  [ControlRebind.rb]
#===============================================================================
# The engine (mkxp-z) exposes no Ruby API to change real key/gamepad bindings
# (its native F1 menu owns those and is not controller-navigable). This adds a
# SAFE Ruby-side remap layer instead: each game action button can be made to read
# from a different logical button.
#
# Safety:
#   * Identity by default -> ZERO behaviour change until you actually rebind.
#   * Always-available "Reset to defaults".
#   * The rebind screen reads RAW input (bypass) so a remap can never lock you
#     out of the rebind screen itself.
#   * Only the 8 action buttons are remappable; movement (the d-pad/stick) is
#     never touched.
#   * Every path is rescued so input can never crash.
#
# Reached from the (already controller-navigable) Options menu -> "Rebind
# Controls". Persists to control_bindings.txt in the game folder.
#===============================================================================

module ControlRebind
  @bypass = false
  @remap  = {}

  # The 8 remappable logical buttons (each game action IS one of these).
  def self.buttons
    [Input::C, Input::B, Input::A, Input::X, Input::Y, Input::Z, Input::L, Input::R]
  end

  # Action rows for the UI: [logical_button, friendly_label]
  def self.actions
    [
      [Input::C, _INTL("Confirm")],
      [Input::B, _INTL("Cancel")],
      [Input::A, _INTL("Action")],
      [Input::X, _INTL("Jump Up (X)")],
      [Input::Y, _INTL("Jump Down (Y)")],
      [Input::Z, _INTL("Special / Menu (Z)")],
      [Input::L, _INTL("Aux L")],
      [Input::R, _INTL("Aux R")]
    ]
  end

  def self.source_name(b)
    { Input::C => "C", Input::B => "B", Input::A => "A", Input::X => "X",
      Input::Y => "Y", Input::Z => "Z", Input::L => "L", Input::R => "R" }[b] || b.to_s
  end

  def self.defaults
    h = {}
    buttons.each { |b| h[b] = b }
    h
  end

  def self.ensure_init
    @remap = defaults if !@remap || @remap.empty?
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
    list = buttons
    cur  = @remap[action] || action
    i    = list.index(cur) || 0
    @remap[action] = list[(i + dir) % list.length]
  rescue
    nil
  end

  def self.reset!
    @remap = defaults
  end

  def self.bind_path
    File.join(Dir.pwd, "control_bindings.txt")
  rescue
    "control_bindings.txt"
  end

  def self.save
    ensure_init
    lines = buttons.map { |b| "#{source_name(b)}=#{source_name(@remap[b] || b)}" }
    File.open(bind_path, "w") { |f| f.write(lines.join("\n")) }
  rescue
    nil
  end

  def self.load
    @remap = defaults
    return unless File.exist?(bind_path)
    name_to_btn = {}
    buttons.each { |b| name_to_btn[source_name(b)] = b }
    File.read(bind_path).each_line do |ln|
      k, v = ln.strip.split("=", 2)
      next unless k && v
      a = name_to_btn[k]; s = name_to_btn[v]
      @remap[a] = s if a && s
    end
  rescue
    @remap = defaults
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
    acts  = actions
    total = acts.length + 1   # + "Reset to defaults" row
    sel   = 0
    redraw = true
    loop do
      Graphics.update
      Input.update
      if redraw
        draw_menu(spr.bitmap, acts, sel)
        redraw = false
      end
      if Input.repeat?(Input::DOWN)
        sel = (sel + 1) % total; redraw = true; (pbPlayCursorSE rescue nil)
      elsif Input.repeat?(Input::UP)
        sel = (sel - 1) % total; redraw = true; (pbPlayCursorSE rescue nil)
      elsif Input.trigger?(Input::RIGHT)
        if sel < acts.length; cycle(acts[sel][0], 1); redraw = true; (pbPlayDecisionSE rescue nil); end
      elsif Input.trigger?(Input::LEFT)
        if sel < acts.length; cycle(acts[sel][0], -1); redraw = true; (pbPlayDecisionSE rescue nil); end
      elsif Input.trigger?(Input::C)
        if sel == acts.length
          reset!; redraw = true; (pbPlayDecisionSE rescue nil)
        end
      elsif Input.trigger?(Input::B)
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

  def self.draw_menu(bmp, acts, sel)
    w = bmp.width
    bmp.clear
    bmp.fill_rect(0, 0, w, bmp.height, Color.new(18, 16, 28, 235))
    base   = Color.new(255, 255, 255)
    shadow = Color.new(0, 0, 0)
    dim    = Color.new(170, 170, 190)
    selc   = Color.new(120, 220, 255)
    pbSetSystemFont(bmp)
    bmp.font.size = 28 rescue nil
    pbDrawShadowText(bmp, 0, 20, w, 40, _INTL("Rebind Controls"), selc, shadow, 1)
    bmp.font.size = 20 rescue nil
    pbDrawShadowText(bmp, 0, 66, w, 26, _INTL("Left / Right: change    Up / Down: move    B: save & exit"), dim, shadow, 1)
    label_x = 70
    val_x   = w - 200
    y = 112
    acts.each_with_index do |(act, label), i|
      col = (sel == i) ? selc : base
      pbDrawShadowText(bmp, label_x, y, val_x - label_x, 28, label, col, shadow, 0)
      src = @remap[act] || act
      changed = (src != act)
      vtxt = "<  #{source_name(src)}  >"
      pbDrawShadowText(bmp, val_x, y, 180, 28, vtxt, (changed ? Color.new(255, 225, 120) : col), shadow, 0)
      y += 32
    end
    col = (sel == acts.length) ? selc : dim
    pbDrawShadowText(bmp, label_x, y + 12, w - label_x, 28, _INTL("Reset to defaults  (press Confirm)"), col, shadow, 0)
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
        _INTL("Reassign the action buttons. Fully controller-navigable."),
        _INTL("Open")))
    rescue
    end
    options
  end
end

# Load saved bindings at boot.
ControlRebind.load rescue nil
