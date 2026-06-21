#===============================================================================
# Controller Diagnostic (read-only raw input viewer)   [ControllerDiagnostic.rb]
#===============================================================================
# A SAFE, read-only overlay that shows the RAW values the game receives from a
# controller -- raw HID (direct DualSense via Fiddle, the fix path for the bare
# exe), the winmm joystick API, XInput (Xbox / Steam Input virtual pad), AND the
# engine's own logical buttons. It changes NOTHING: never binds, never writes a
# file, never alters input. Its purpose is to confirm the raw-HID reader sees
# every button (especially Create/Select) before it is wired into the live input
# layer.
#
# OPEN IT:  hold  Left Ctrl + Left Shift  and tap  C   (any screen).
# CLOSE IT: press  Esc  (or the controller B / Cancel button).
#===============================================================================

module ControllerDiag
  @running = false

  begin
    GAKS = Win32API.new('user32', 'GetAsyncKeyState', ['i'], 'i')
  rescue
    GAKS = nil
  end

  begin
    JGP = Win32API.new('winmm', 'joyGetPosEx',   ['i', 'p'], 'i')
    JND = Win32API.new('winmm', 'joyGetNumDevs', [],         'i')
  rescue
    JGP = nil; JND = nil
  end

  begin
    XI = nil
    ["xinput1_4", "xinput1_3", "xinput9_1_0"].each do |dll|
      begin
        fn = Win32API.new(dll, "XInputGetState", ["l", "p"], "l")
        probe = fn.call(0, "\0" * 16)
        if probe.is_a?(Integer); XI = fn; break; end
      rescue
        next
      end
    end
  rescue
    XI = nil
  end

  VK_LCTRL  = 0xA2
  VK_LSHIFT = 0xA0
  VK_C      = 0x43
  VK_ESC    = 0x1B

  def self.key_down?(vk)
    return false unless GAKS
    (GAKS.call(vk) & 0x8000) != 0
  rescue
    false
  end

  def self.open_combo_edge?
    held = key_down?(VK_LCTRL) && key_down?(VK_LSHIFT)
    c    = held && key_down?(VK_C)
    was  = (@combo_was ||= false)
    @combo_was = c
    c && !was
  rescue
    false
  end

  def self.winmm_read
    return nil unless JGP
    nd = (JND ? (JND.call rescue 0) : 0)
    nd = 16 if nd.nil? || nd <= 0
    (0...nd).each do |id|
      buf = [52, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0].pack("L13")
      res = (JGP.call(id, buf) rescue 1)
      next unless res == 0
      v = buf.unpack("L13")
      return {
        :id => id, :rc => res, :devs => nd,
        :x => v[2], :y => v[3], :z => v[4], :r => v[5], :u => v[6], :vv => v[7],
        :buttons => v[8], :btnnum => v[9], :pov => v[10]
      }
    end
    { :id => -1, :rc => -1, :devs => nd, :buttons => 0, :pov => 0xFFFF }
  rescue
    nil
  end

  def self.xinput_read
    return nil unless XI
    (0..3).each do |i|
      buf = "\0" * 16
      next unless (XI.call(i, buf) rescue 1167) == 0
      return {
        :slot => i,
        :buttons => buf[4, 2].unpack("S<")[0],
        :lt => buf[6, 1].unpack("C")[0],
        :rt => buf[7, 1].unpack("C")[0]
      }
    end
    nil
  rescue
    nil
  end

  def self.bits_set(mask, count)
    out = []
    (0...count).each { |i| out << i if (mask & (1 << i)) != 0 }
    out
  rescue
    []
  end

  def self.pov_label(pov)
    return "center" if pov.nil? || pov == 0xFFFF || pov == 0xFFFFFFFF || pov > 36000
    deg = pov / 100.0
    dir = if deg >= 315 || deg <= 45 then "UP"
          elsif deg > 45  && deg < 135  then "RIGHT"
          elsif deg >= 135 && deg <= 225 then "DOWN"
          else "LEFT"
          end
    "#{dir} (#{deg.round}deg)"
  rescue
    "?"
  end

  def self.line(bmp, x, y, str, col = nil)
    bmp.font.color = (col || Color.new(235, 235, 245))
    bmp.draw_text(x, y, bmp.width - x - 8, 20, str, 0)
  rescue
    nil
  end

  def self.run
    return if @running
    @running = true
    (ControllerHIDInput.ensure_started rescue nil)
    prev_bypass = (ControlRebind.instance_variable_get(:@bypass) rescue nil)
    (ControlRebind.instance_variable_set(:@bypass, true) rescue nil)
    vp = Viewport.new(0, 0, Graphics.width, Graphics.height); vp.z = 999999
    spr = Sprite.new(vp); spr.bitmap = Bitmap.new(Graphics.width, Graphics.height)
    bmp = spr.bitmap
    esc_was = true
    loop do
      Graphics.update
      Input.update
      draw(bmp)
      esc_now = key_down?(VK_ESC)
      close = (esc_now && !esc_was)
      close ||= (Input.trigger?(Input::B) rescue false)
      esc_was = esc_now
      break if close
    end
  rescue
    nil
  ensure
    begin
      spr.bitmap.dispose if spr && spr.bitmap && !spr.bitmap.disposed?
      spr.dispose if spr && !spr.disposed?
      vp.dispose if vp && !vp.disposed?
    rescue
      nil
    end
    (ControlRebind.instance_variable_set(:@bypass, prev_bypass) rescue nil)
    @running = false
  end

  def self.draw(bmp)
    w = bmp.width; h = bmp.height
    bmp.clear
    bmp.fill_rect(0, 0, w, h, Color.new(12, 12, 20, 255))
    (pbSetSystemFont(bmp) rescue nil)
    cyan  = Color.new(120, 220, 255)
    green = Color.new(150, 255, 180)
    amber = Color.new(255, 225, 120)
    grey  = Color.new(180, 180, 200)

    bmp.font.size = 22 rescue nil
    line(bmp, 8, 6, "Controller Diagnostic  (read-only)", cyan)
    bmp.font.size = 15 rescue nil
    line(bmp, 8, 30, "Press ONE button/trigger/d-pad at a time; note which line changes.", grey)

    y = 52
    bmp.font.size = 17 rescue nil
    line(bmp, 8, y, "== raw HID (direct DualSense via Fiddle -- the fix path) ==", cyan); y += 22
    bmp.font.size = 15 rescue nil
    if defined?(ControllerHIDInput)
      lines = (ControllerHIDInput.diag_lines rescue [["raw-HID: error", true]])
      lines.each { |txt, hot| line(bmp, 12, y, txt, (hot ? amber : green)); y += 19 }
    else
      line(bmp, 12, y, "raw-HID module not loaded", amber); y += 19
    end
    y += 4

    bmp.font.size = 17 rescue nil
    line(bmp, 8, y, "-- winmm (legacy joystick API) --", green); y += 21
    bmp.font.size = 15 rescue nil
    wm = winmm_read
    if wm.nil?
      line(bmp, 12, y, "winmm: unavailable", grey); y += 19
    elsif wm[:id] == -1
      line(bmp, 12, y, "No winmm joystick responding. (slots probed: #{wm[:devs]})", grey); y += 19
    else
      bits = bits_set(wm[:buttons], 32)
      bstr = bits.empty? ? "(none)" : bits.inspect
      pl = pov_label(wm[:pov])
      line(bmp, 12, y, "id #{wm[:id]}  dwButtons 0x%08X bits #{bstr}  POV #{pl}" % wm[:buttons],
           (bits.empty? && pl == 'center' ? grey : amber)); y += 19
    end

    bmp.font.size = 17 rescue nil
    line(bmp, 8, y, "-- XInput (Xbox / Steam Input virtual pad) --", green); y += 21
    bmp.font.size = 15 rescue nil
    xi = xinput_read
    if xi.nil?
      line(bmp, 12, y, "XInput: no device on slots 0-3 (expected on bare exe)", grey); y += 19
    else
      xb = bits_set(xi[:buttons], 16)
      xstr = xb.empty? ? "(none)" : xb.inspect
      thot = (xi[:lt].to_i > 20 || xi[:rt].to_i > 20)
      line(bmp, 12, y, "slot #{xi[:slot]}  wButtons 0x%04X bits #{xstr}" % xi[:buttons],
           (xb.empty? ? grey : amber)); y += 19
      line(bmp, 12, y, "triggers  LT:#{xi[:lt]}   RT:#{xi[:rt]}", (thot ? amber : grey)); y += 19
    end

    bmp.font.size = 17 rescue nil
    line(bmp, 8, y, "-- Engine buttons (SDL mapping) --", green); y += 21
    bmp.font.size = 15 rescue nil
    logicals = [["C", Input::C], ["B", Input::B], ["A", Input::A], ["X", Input::X],
                ["Y", Input::Y], ["Z", Input::Z], ["L", Input::L], ["R", Input::R]]
    lheld = []
    logicals.each { |nm, b| lheld << nm if (Input.press?(b) rescue false) }
    lstr = lheld.empty? ? "(none)" : lheld.join(" ")
    dirs = []
    dirs << "UP"    if (Input.press?(Input::UP)    rescue false)
    dirs << "DOWN"  if (Input.press?(Input::DOWN)  rescue false)
    dirs << "LEFT"  if (Input.press?(Input::LEFT)  rescue false)
    dirs << "RIGHT" if (Input.press?(Input::RIGHT) rescue false)
    dstr = dirs.empty? ? "(none)" : dirs.join(" ")
    line(bmp, 12, y, "logical: #{lstr}   dirs: #{dstr}",
         ((lheld.empty? && dirs.empty?) ? grey : amber)); y += 19

    bmp.font.size = 14 rescue nil
    bmp.font.size = 17 rescue nil
    line(bmp, 8, y, "-- ControlRebind trigger view (chat/profile) --", green); y += 21
    bmp.font.size = 15 rescue nil
    if defined?(ControlRebind)
      ws = (ControlRebind.winmm_trigger_set rescue {:lt=>false,:rt=>false})
      dl = (ControlRebind.trigger_down?(:lt) rescue false)
      dr = (ControlRebind.trigger_down?(:rt) rescue false)
      line(bmp, 12, y, "winmm LT(din6):#{ws[:lt] ? %q{YES} : %q{no}}  RT(din7):#{ws[:rt] ? %q{YES} : %q{no}}", ((ws[:lt]||ws[:rt]) ? amber : grey)); y += 19
      line(bmp, 12, y, "trigger_down? LT->chat:#{dl ? %q{YES} : %q{no}}  RT->profile:#{dr ? %q{YES} : %q{no}}", ((dl||dr) ? amber : grey)); y += 19
    else
      line(bmp, 12, y, "ControlRebind not loaded", grey); y += 19
    end

    line(bmp, 8, h - 22, "Esc or controller B to close.  Nothing here changes any setting.", grey)
  rescue
    nil
  end
end

#-------------------------------------------------------------------------------
# Global open hook: Left Ctrl + Left Shift + C opens the diagnostic from any
# scene. Guarded; loaded once. Wraps the existing Input.update chain.
#-------------------------------------------------------------------------------
unless defined?($controller_diag_hook) && $controller_diag_hook
  module Input
    class << self
      alias_method :_ctrldiag_prev_update, :update
      def update(*a)
        _ctrldiag_prev_update(*a)
        if !ControllerDiag.instance_variable_get(:@running) && ControllerDiag.open_combo_edge?
          ControllerDiag.run
        end
      rescue
        nil
      end
    end
  end
  $controller_diag_hook = true
end
