# frozen_string_literal: true

module GBAPlayer
  module PhysicalKeys
    VK = {
      "BACKSPACE" => 0x08, "TAB" => 0x09, "ENTER" => 0x0D, "SHIFT" => 0x10,
      "CTRL" => 0x11, "ALT" => 0x12, "ESC" => 0x1B, "ESCAPE" => 0x1B,
      "SPACE" => 0x20, "LEFT" => 0x25, "UP" => 0x26, "RIGHT" => 0x27,
      "DOWN" => 0x28, "," => 0xBC, "<" => 0xBC, "." => 0xBE, ">" => 0xBE
    }

    12.times { |i| VK["F#{i + 1}"] = 0x70 + i }
    ("A".."Z").each { |ch| VK[ch] = ch.ord }
    ("0".."9").each { |ch| VK[ch] = ch.ord }

    begin
      @@GetAsyncKeyState = Win32API.new("user32", "GetAsyncKeyState", ["i"], "i")
      @available = true
    rescue
      @available = false
    end

    @last = {}
    @held = {}

    module_function

    def available?
      @available
    end

    def vk_for(name)
      text = name.to_s.strip.upcase
      return nil if text.empty?
      VK[text]
    end

    def pressed?(name)
      vk = vk_for(name)
      return false if !vk || !@available
      (@@GetAsyncKeyState.call(vk) & 0x8000) != 0
    rescue
      false
    end

    def trigger?(name)
      key = name.to_s.strip.upcase
      now = pressed?(key)
      was = @last[key] || false
      @last[key] = now
      now && !was
    end

    def repeat?(name, delay = 12, rate = 4)
      key = name.to_s.strip.upcase
      now = pressed?(key)
      @held[key] = now ? (@held[key] || 0) + 1 : 0
      return false if @held[key] <= 0
      return true if @held[key] == 1
      return false if @held[key] < delay
      ((@held[key] - delay) % rate) == 0
    end
  end

  module WalkalongOverlay
    WHITE = Color.new(248, 248, 248)
    DIM = Color.new(176, 188, 202)
    SHADOW = Color.new(0, 0, 0)
    BODY = Color.new(18, 22, 30, 232)
    PANEL = Color.new(34, 40, 54, 232)
    BORDER = Color.new(168, 182, 204, 230)
    ACCENT = Color.new(120, 192, 168, 235)
    DANGER = Color.new(178, 70, 86, 235)
    GLASS = Color.new(3, 6, 10, 245)
    SHELL_HILITE = Color.new(48, 55, 72, 210)
    SCREEN_WIDTH = 180
    MIN_SCREEN_WIDTH = 144
    TAB_W = 112
    TAB_H = 22

    @active = false
    @pocketed = false
    @dragging_volume = false
    @rom = nil
    @viewport = nil
    @body_sprite = nil
    @frame_sprite = nil
    @last_frame_mtime = nil
    @size_mode = nil
    @buttons = []
    @frame_counter = 0
    @mouse_hold_button = nil
    @mouse_hold_sent_at = 0
    @dragging_shell = false
    @drag_offset_x = 0
    @drag_offset_y = 0
    @modal_hidden = false

    module_function

    def start(path)
      @rom = GBAPlayer.absolute_path(path)
      @active = true
      @pocketed = GBAPlayer.config["walkalong_pocketed"] == true
      @dragging_volume = false
      @dragging_shell = false
      @modal_hidden = false
      @mouse_hold_button = nil
      @mouse_hold_sent_at = 0
      @size_mode = "fixed"
      @mirror_mode = nil
      @mirror_status_counter = 0
      @core_fallback_attempted = false
      create_sprites
      redraw
      true
    end

    def stop
      @active = false
      @pocketed = false
      @dragging_volume = false
      @dragging_shell = false
      @modal_hidden = false
      release_mouse_hold
      @mouse_hold_button = nil
      GBAPlayer.config["walkalong_pocketed"] = false
      GBAPlayer.write_config
      GBAPlayer.stop_mirror
      dispose
      true
    end

    def active?
      @active
    end

    def modal_hide
      return false unless @active
      finish_shell_drag if @dragging_shell
      release_mouse_hold
      @dragging_volume = false
      @modal_hidden = true
      @body_sprite.visible = false if @body_sprite && !@body_sprite.disposed?
      @frame_sprite.visible = false if @frame_sprite && !@frame_sprite.disposed?
      GBAPlayer.send_mirror_pause(true) unless @pocketed
      true
    rescue
      false
    end

    def modal_show
      return false unless @active
      @modal_hidden = false
      create_sprites
      @body_sprite.visible = true if @body_sprite && !@body_sprite.disposed?
      @frame_sprite.visible = true if @frame_sprite && !@frame_sprite.disposed? && !@pocketed
      GBAPlayer.send_mirror_pause(false) unless @pocketed
      redraw
      sync_mirror_rect unless @pocketed
      true
    rescue
      false
    end

    def update(force = false)
      return dispose unless @active
      create_sprites
      return unless alive?
      @frame_counter += 1
      return if @modal_hidden
      redraw if force || @frame_counter % 30 == 1
      if @pocketed
        GBAPlayer.send_mirror_pause(true) if @frame_counter == 1 || @frame_counter % 60 == 0
      else
        sync_mirror_rect if @frame_counter == 1 || @frame_counter % 15 == 0
        handle_bridge_error
        update_frame
      end
      update_input
      update_mouse
    rescue Exception => e
      GBAPlayer.log("walkalong update failed #{e.class}: #{e.message}") if GBAPlayer.respond_to?(:log)
    end

    def create_sprites
      return if alive?
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 999_999
      @body_sprite = Sprite.new(@viewport)
      @body_sprite.bitmap = Bitmap.new(Graphics.width, Graphics.height)
      @body_sprite.z = 0
      @frame_sprite = Sprite.new(@viewport)
      @frame_sprite.z = 1
      @frame_sprite.visible = false
      @last_frame_mtime = nil
      redraw
    rescue Exception => e
      GBAPlayer.log("walkalong create failed #{e.class}: #{e.message}") if GBAPlayer.respond_to?(:log)
    end

    def alive?
      return false if !@body_sprite || !@frame_sprite
      return false if @body_sprite.respond_to?(:disposed?) && @body_sprite.disposed?
      return false if @frame_sprite.respond_to?(:disposed?) && @frame_sprite.disposed?
      return false if !@body_sprite.bitmap || @body_sprite.bitmap.disposed?
      true
    rescue
      false
    end

    def fixed_screen_width
      configured = GBAPlayer.config["walkalong_screen_width"].to_i rescue SCREEN_WIDTH
      configured = SCREEN_WIDTH if configured <= 0
      [[configured, MIN_SCREEN_WIDTH].max, 220].min
    end

    def geometry
      if @pocketed
        tab_x = (Graphics.width - TAB_W) / 2
        tab_y = Graphics.height - TAB_H - 2
        return {
          :body => [tab_x, tab_y, TAB_W, TAB_H],
          :screen => [0, 0, 1, 1],
          :controls => [tab_x, tab_y, TAB_W, TAB_H],
          :tab => [tab_x, tab_y, TAB_W, TAB_H]
        }
      end
      screen_w = [fixed_screen_width, Graphics.width - 48].min
      screen_w = [screen_w, MIN_SCREEN_WIDTH].max
      screen_h = screen_w * 2 / 3
      body_w = screen_w + 20
      header_h = 18
      screen_gap = 4
      control_h = 44
      body_h = header_h + screen_gap + screen_h + control_h + 4
      volume_hang = 12
      pos = GBAPlayer.config["walkalong_position"].to_s
      x = pos.include?("left") ? 12 : Graphics.width - body_w - volume_hang - 12
      x = 6 if x < 6
      y = pos.include?("bottom") ? Graphics.height - body_h - 12 : 38
      y = 6 if y < 6
      if draggable_position?
        x = GBAPlayer.config["walkalong_x"].to_i
        y = GBAPlayer.config["walkalong_y"].to_i
      end
      x, y = clamp_shell_position(x, y, body_w, body_h, volume_hang)
      screen_x = x + ((body_w - screen_w) / 2)
      screen_y = y + header_h + screen_gap
      controls_y = screen_y + screen_h + 3
      {
        :body => [x, y, body_w, body_h],
        :screen => [screen_x, screen_y, screen_w, screen_h],
        :controls => [x, controls_y, body_w, control_h],
        :volume => [x + body_w + 1, screen_y - 1, 6, screen_h + 2],
        :drag => [x, y, body_w - 68, header_h + 4]
      }
    end

    def draggable_position?
      GBAPlayer.config["walkalong_x"].is_a?(Numeric) && GBAPlayer.config["walkalong_y"].is_a?(Numeric)
    rescue
      false
    end

    def clamp_shell_position(x, y, body_w, body_h, volume_hang = 0)
      max_x = [Graphics.width - body_w - volume_hang - 4, 4].max
      max_y = [Graphics.height - body_h - 4, 4].max
      [
        [[x.to_i, 4].max, max_x].min,
        [[y.to_i, 4].max, max_y].min
      ]
    end

    def screen_rect
      geometry[:screen]
    end

    def sync_mirror_rect
      GBAPlayer.send_mirror_rect(screen_rect) if GBAPlayer.respond_to?(:send_mirror_rect)
    rescue
      false
    end

    def redraw
      return unless alive?
      b = @body_sprite.bitmap
      b.clear
      @buttons.clear
      geo = geometry
      if @pocketed
        draw_tab(b, geo[:tab])
        @frame_sprite.visible = false if @frame_sprite
        return
      end
      x, y, w, h = geo[:body]
      sx, sy, sw, sh = geo[:screen]
      draw_rect(b, x + 4, y + 4, w, h, Color.new(0, 0, 0, 110))
      draw_rect(b, x, y, w, h, BODY)
      b.fill_rect(x + 6, y + 6, w - 12, 1, SHELL_HILITE)
      draw_border(b, x, y, w, h, BORDER)
      draw_rect(b, sx - 6, sy - 6, sw + 12, sh + 12, Color.new(5, 8, 13, 250))
      draw_border(b, sx - 6, sy - 6, sw + 12, sh + 12, Color.new(92, 104, 126, 235))
      draw_border(b, sx - 3, sy - 3, sw + 6, sh + 6, Color.new(26, 32, 44, 245))
      b.fill_rect(sx, sy, sw, sh, GLASS)
      draw_header(b, x, y, w)
      @buttons << { :rect => geo[:drag], :action => :drag } if geo[:drag]
      draw_controls(b, geo)
      draw_volume_slider(b, geo)
      place_frame
    end

    def draw_tab(b, rect)
      x, y, w, h = rect
      draw_round_rect(b, x, y, w, h, BODY, 6)
      draw_border(b, x, y, w, h, BORDER)
      pbSetSystemFont(b) if defined?(pbSetSystemFont)
      b.font.size = 12
      draw_text(b, x, y + 2, w, h - 2, "GBA Player", WHITE, 1)
      @buttons << { :rect => rect, :action => :resume }
    end

    def draw_header(b, x, y, w)
      pbSetSystemFont(b) if defined?(pbSetSystemFont)
      b.font.size = 13
      label = @rom && !@rom.empty? ? GBAPlayer.rom_label(@rom) : "GBA"
      b.fill_rect(x + 7, y + 6, 4, 4, Color.new(220, 72, 82))
      b.fill_rect(x + 13, y + 7, 8, 2, Color.new(92, 104, 126, 235))
      draw_text(b, x + 25, y + 1, w - 80, 16, label, WHITE)
      pocket = [x + w - 62, y + 2, 25, 15]
      power = [x + w - 32, y + 2, 23, 15]
      draw_round_rect(b, pocket[0], pocket[1], pocket[2], pocket[3], PANEL, 5)
      draw_round_rect(b, power[0], power[1], power[2], power[3], DANGER, 5)
      draw_border(b, pocket[0], pocket[1], pocket[2], pocket[3], BORDER)
      draw_border(b, power[0], power[1], power[2], power[3], BORDER)
      @buttons << { :rect => pocket, :action => :pocket }
      @buttons << { :rect => power, :action => :stop }
      b.font.size = 8
      draw_text(b, pocket[0], pocket[1], pocket[2], pocket[3] - 1, "POC", WHITE, 1)
      draw_text(b, power[0], power[1], power[2], power[3] - 1, "PWR", WHITE, 1)
    end

    def draw_controls(b, geo)
      x, _y, w, _h = geo[:body]
      _cx, control_y, _cw, _ch = geo[:controls]
      dpad_cx = x + 27
      dpad_cy = control_y + 20
      draw_round_rect(b, dpad_cx - 6, dpad_cy - 19, 12, 38, PANEL, 4)
      draw_round_rect(b, dpad_cx - 19, dpad_cy - 6, 38, 12, PANEL, 4)
      draw_border(b, dpad_cx - 6, dpad_cy - 19, 12, 38, BORDER)
      draw_border(b, dpad_cx - 19, dpad_cy - 6, 38, 12, BORDER)
      draw_circle(b, dpad_cx, dpad_cy, 6, Color.new(18, 22, 30, 245))
      @buttons << { :rect => [dpad_cx - 27, dpad_cy - 27, 54, 54], :action => :dpad, :center => [dpad_cx, dpad_cy] }

      mid_x = x + (w / 2) - 17
      select = [mid_x, control_y + 21, 36, 10]
      start = [mid_x, control_y + 33, 36, 10]
      [select, start].each { |rect| draw_round_rect(b, rect[0], rect[1], rect[2], rect[3], PANEL, 5); draw_border(b, rect[0], rect[1], rect[2], rect[3], BORDER) }
      @buttons << { :rect => select, :action => :tap, :button => "SELECT" }
      @buttons << { :rect => start, :action => :tap, :button => "START" }

      l_rect = [x + w - 57, control_y + 1, 24, 10]
      r_rect = [x + w - 30, control_y + 1, 24, 10]
      b_rect = [x + w - 50, control_y + 21, 23, 23]
      a_rect = [x + w - 24, control_y + 14, 24, 24]
      [l_rect, r_rect].each { |rect| draw_round_rect(b, rect[0], rect[1], rect[2], rect[3], PANEL, 4); draw_border(b, rect[0], rect[1], rect[2], rect[3], BORDER) }
      draw_circle(b, b_rect[0] + (b_rect[2] / 2), b_rect[1] + (b_rect[3] / 2), b_rect[2] / 2, BORDER)
      draw_circle(b, b_rect[0] + (b_rect[2] / 2), b_rect[1] + (b_rect[3] / 2), (b_rect[2] / 2) - 1, DANGER)
      draw_circle(b, a_rect[0] + (a_rect[2] / 2), a_rect[1] + (a_rect[3] / 2), a_rect[2] / 2, BORDER)
      draw_circle(b, a_rect[0] + (a_rect[2] / 2), a_rect[1] + (a_rect[3] / 2), (a_rect[2] / 2) - 1, ACCENT)
      @buttons << { :rect => l_rect, :action => :tap, :button => "L" }
      @buttons << { :rect => r_rect, :action => :tap, :button => "R" }
      @buttons << { :rect => b_rect, :action => :tap, :button => "B" }
      @buttons << { :rect => a_rect, :action => :tap, :button => "A" }

      4.times { |i| b.fill_rect(x + w - 26 + i * 5, control_y + 36, 2, 8, Color.new(7, 10, 16, 210)) }
      pbSetSystemFont(b) if defined?(pbSetSystemFont)
      b.font.size = 13
      draw_text(b, b_rect[0], b_rect[1] + 1, b_rect[2], 19, "B", WHITE, 1)
      draw_text(b, a_rect[0], a_rect[1] + 1, a_rect[2], 21, "A", WHITE, 1)
      b.font.size = 8
      draw_text(b, l_rect[0], l_rect[1] - 1, l_rect[2], 12, "L", WHITE, 1)
      draw_text(b, r_rect[0], r_rect[1] - 1, r_rect[2], 12, "R", WHITE, 1)
      draw_text(b, select[0], select[1] - 3, select[2], 12, "SELECT", WHITE, 1)
      draw_text(b, start[0], start[1] - 3, start[2], 12, "START", WHITE, 1)
    end

    def draw_volume_slider(b, geo)
      return unless geo[:volume]
      x, y, w, h = geo[:volume]
      volume = current_volume_percent
      track_top = y + 10
      track_h = [h - 20, 8].max
      knob_y = track_top + ((100 - volume) * track_h / 100)
      draw_round_rect(b, x - 1, y, w + 3, h, Color.new(5, 8, 13, 250), 4)
      draw_border(b, x - 1, y, w + 3, h, Color.new(92, 104, 126, 235))
      draw_round_rect(b, x + 1, y + 4, w - 1, h - 8, Color.new(8, 12, 18, 220), 4)
      b.fill_rect(x + (w / 2) - 1, track_top, 3, track_h, Color.new(96, 110, 132, 235))
      b.fill_rect(x + (w / 2) - 1, knob_y, 3, track_top + track_h - knob_y, ACCENT)
      draw_round_rect(b, x - 3, knob_y - 3, w + 6, 7, ACCENT, 4)
      pbSetSystemFont(b) if defined?(pbSetSystemFont)
      b.font.size = 7
      draw_text(b, x - 8, y + h - 10, w + 16, 10, "VOL", DIM, 1)
      @buttons << { :rect => [x - 10, y, w + 20, h], :action => :volume }
    end

    def place_frame
      return if !@frame_sprite || !@frame_sprite.bitmap
      sx, sy, sw, sh = geometry[:screen]
      @frame_sprite.x = sx
      @frame_sprite.y = sy
      @frame_sprite.zoom_x = sw.to_f / @frame_sprite.bitmap.width
      @frame_sprite.zoom_y = sh.to_f / @frame_sprite.bitmap.height
      @frame_sprite.visible = true
    end

    def update_frame
      return if embedded_mirror?
      frame_path = if GBAPlayer.respond_to?(:current_mirror_frame_path)
                     GBAPlayer.current_mirror_frame_path
                   else
                     GBAPlayer.mirror_frame_path
                   end
      return unless File.file?(frame_path)
      mtime = File.mtime(frame_path) rescue nil
      frame_key = "#{frame_path}|#{mtime.to_f}"
      return if !mtime || frame_key == @last_frame_mtime
      bitmap = Bitmap.new(frame_path) rescue nil
      return if !bitmap
      old = @frame_sprite.bitmap
      @frame_sprite.bitmap = bitmap
      old.dispose if old && !old.disposed?
      @last_frame_mtime = frame_key
      place_frame
    end

    def embedded_mirror?
      return false unless GBAPlayer.respond_to?(:mirror_embed_enabled?) && GBAPlayer.mirror_embed_enabled?
      @mirror_status_counter = (@mirror_status_counter || 0) + 1
      if @mirror_status_counter == 1 || @mirror_status_counter % 6 == 0
        @mirror_mode = GBAPlayer.respond_to?(:mirror_status) ? GBAPlayer.mirror_status["mode"].to_s : ""
      end
      return false if @mirror_mode == "core" || @mirror_mode == "capture"
      return false if @mirror_mode.empty? && GBAPlayer.respond_to?(:native_core_enabled?) && GBAPlayer.native_core_enabled?
      @mirror_mode.empty? || @mirror_mode == "embed"
    rescue
      false
    end

    def handle_bridge_error
      return false unless GBAPlayer.respond_to?(:mirror_status)
      status = GBAPlayer.mirror_status
      return false unless status["state"].to_s == "error"
      mode = status["mode"].to_s
      return false unless mode == "core"
      return false if @core_fallback_attempted
      @core_fallback_attempted = true
      GBAPlayer.log("native core errored; falling back to mirror #{status.inspect}") if GBAPlayer.respond_to?(:log)
      return false if GBAPlayer.respond_to?(:bridge_backend) && GBAPlayer.bridge_backend == "native"
      return false unless @rom && File.file?(@rom)
      GBAPlayer.start_mirror(@rom, screen_rect)
      @mirror_mode = nil
      @last_frame_mtime = nil
      redraw
      true
    rescue Exception => e
      GBAPlayer.log("native core fallback failed #{e.class}: #{e.message}") if GBAPlayer.respond_to?(:log)
      false
    end

    def update_input
      return unless defined?(GBAPlayer::PhysicalKeys) && GBAPlayer::PhysicalKeys.available?
      keymap = GBAPlayer.config["keymap"] || {}
      if GBAPlayer::PhysicalKeys.trigger?(keymap["stop"])
        power_off
        return
      end
      if GBAPlayer::PhysicalKeys.trigger?(keymap["toggle_size"])
        @pocketed ? resume_from_pocket : pocket
        return
      end
      return if @pocketed
      {
        "up" => "UP", "down" => "DOWN", "left" => "LEFT", "right" => "RIGHT"
      }.each do |name, button|
        GBAPlayer.send_mirror_button(button) if GBAPlayer::PhysicalKeys.repeat?(keymap[name])
      end
      {
        "a" => "A", "b" => "B", "l" => "L", "r" => "R",
        "start" => "START", "select" => "SELECT"
      }.each do |name, button|
        GBAPlayer.send_mirror_button(button) if GBAPlayer::PhysicalKeys.trigger?(keymap[name])
      end
    end

    def update_mouse
      pos = mouse_position
      if @dragging_shell
        if mouse_pressed? && pos
          update_shell_drag(pos[0], pos[1])
          return
        end
        finish_shell_drag
      end
      if @dragging_volume
        if mouse_pressed? && pos
          set_volume_from_mouse(pos[1])
          return
        end
        @dragging_volume = false
        GBAPlayer.write_config
        redraw
      end
      release_mouse_hold unless mouse_pressed?
      return unless pos
      mx, my = pos
      button = button_at(mx, my)
      if mouse_pressed? && button && button[:action] == :dpad
        dpad_button = dpad_button_for(button, mx, my)
        if dpad_button
          if @mouse_hold_button && @mouse_hold_button != dpad_button
            GBAPlayer.send_mirror_key_up(@mouse_hold_button) if GBAPlayer.respond_to?(:send_mirror_key_up)
          end
          if @mouse_hold_button != dpad_button
            GBAPlayer.send_mirror_key_down(dpad_button) if GBAPlayer.respond_to?(:send_mirror_key_down)
            @mouse_hold_button = dpad_button
            @mouse_hold_sent_at = @frame_counter
          elsif (@frame_counter - @mouse_hold_sent_at) >= 6
            GBAPlayer.send_mirror_key_down(dpad_button) if GBAPlayer.respond_to?(:send_mirror_key_down)
            @mouse_hold_sent_at = @frame_counter
          end
        else
          release_mouse_hold
        end
        return
      end
      return unless mouse_trigger? && button
      case button[:action]
      when :stop
        power_off
      when :pocket
        pocket
      when :resume
        resume_from_pocket
      when :drag
        begin_shell_drag(mx, my)
      when :tap
        GBAPlayer.send_mirror_button(button[:button]) if button[:button]
      when :dpad
        dpad_button = dpad_button_for(button, mx, my)
        GBAPlayer.send_mirror_hold(dpad_button, 85) if dpad_button
      when :volume
        @dragging_volume = true
        set_volume_from_mouse(my)
      end
    end

    def cycle_size
      sync_mirror_rect
    end

    def begin_shell_drag(mx, my)
      x, y, _w, _h = geometry[:body]
      @dragging_shell = true
      @drag_offset_x = mx - x
      @drag_offset_y = my - y
      true
    end

    def update_shell_drag(mx, my)
      geo = geometry
      _x, _y, body_w, body_h = geo[:body]
      volume_hang = 12
      x, y = clamp_shell_position(mx - @drag_offset_x, my - @drag_offset_y, body_w, body_h, volume_hang)
      GBAPlayer.config["walkalong_x"] = x
      GBAPlayer.config["walkalong_y"] = y
      @mirror_mode = nil
      redraw
      sync_mirror_rect
    end

    def finish_shell_drag
      return unless @dragging_shell
      @dragging_shell = false
      GBAPlayer.write_config
      sync_mirror_rect
    end

    def release_mouse_hold
      return unless @mouse_hold_button
      GBAPlayer.send_mirror_key_up(@mouse_hold_button) if GBAPlayer.respond_to?(:send_mirror_key_up)
      @mouse_hold_button = nil
    rescue
      @mouse_hold_button = nil
    end

    def dpad_button_for(button, mx, my)
      cx, cy = button[:center]
      dx = mx - cx
      dy = my - cy
      return nil if dx.abs < 4 && dy.abs < 4
      dx.abs > dy.abs ? (dx < 0 ? "LEFT" : "RIGHT") : (dy < 0 ? "UP" : "DOWN")
    end

    def pocket
      return if @pocketed
      release_mouse_hold
      @pocketed = true
      GBAPlayer.config["walkalong_pocketed"] = true
      GBAPlayer.write_config
      GBAPlayer.send_mirror_pause(true)
      @mirror_mode = nil
      redraw
      true
    end

    def resume_from_pocket
      return unless @active
      @pocketed = false
      GBAPlayer.config["walkalong_pocketed"] = false
      GBAPlayer.write_config
      GBAPlayer.send_mirror_pause(false)
      @mirror_mode = nil
      redraw
      sync_mirror_rect
      true
    end

    def power_off
      stop
    end

    def current_volume_percent
      volume = GBAPlayer.config["emulator_volume_percent"].to_i rescue 25
      [[volume, 0].max, 100].min
    end

    def set_volume_from_mouse(my)
      geo = geometry
      return unless geo[:volume]
      _x, y, _w, h = geo[:volume]
      track_top = y + 10
      track_h = [h - 20, 8].max
      relative = [[my - track_top, 0].max, track_h].min
      volume = 100 - (relative * 100 / track_h)
      return if volume == current_volume_percent
      GBAPlayer.config["emulator_volume_percent"] = volume
      GBAPlayer.send_mirror_volume(volume)
      redraw
    end

    def dispose
      if @frame_sprite
        @frame_sprite.bitmap.dispose if @frame_sprite.bitmap && !@frame_sprite.bitmap.disposed?
        @frame_sprite.dispose if !@frame_sprite.disposed?
      end
      if @body_sprite
        @body_sprite.bitmap.dispose if @body_sprite.bitmap && !@body_sprite.bitmap.disposed?
        @body_sprite.dispose if !@body_sprite.disposed?
      end
      @viewport.dispose if @viewport && !@viewport.disposed?
      @viewport = nil
      @body_sprite = nil
      @frame_sprite = nil
      @last_frame_mtime = nil
      @mirror_mode = nil
      @mirror_status_counter = 0
    rescue
      nil
    end

    def draw_rect(b, x, y, w, h, color)
      b.fill_rect(x + 2, y, w - 4, h, color)
      b.fill_rect(x, y + 2, w, h - 4, color)
      b.fill_rect(x + 1, y + 1, w - 2, h - 2, color)
    end

    def draw_round_rect(b, x, y, w, h, color, radius = 4)
      radius = [[radius.to_i, 1].max, [w, h].min / 2].min
      return b.fill_rect(x, y, w, h, color) if radius <= 1
      inner_w = w - radius * 2
      inner_h = h - radius * 2
      b.fill_rect(x + radius, y, inner_w, h, color) if inner_w > 0
      b.fill_rect(x, y + radius, w, inner_h, color) if inner_h > 0
      b.fill_rect(x + 1, y + 1, radius, radius, color)
      b.fill_rect(x + w - radius - 1, y + 1, radius, radius, color)
      b.fill_rect(x + 1, y + h - radius - 1, radius, radius, color)
      b.fill_rect(x + w - radius - 1, y + h - radius - 1, radius, radius, color)
    end

    def draw_circle(b, cx, cy, radius, color)
      r = [radius.to_i, 1].max
      (-r..r).each do |dy|
        dx = Math.sqrt((r * r) - (dy * dy)).floor
        b.fill_rect(cx - dx, cy + dy, (dx * 2) + 1, 1, color)
      end
    end

    def draw_border(b, x, y, w, h, color)
      b.fill_rect(x + 2, y, w - 4, 1, color)
      b.fill_rect(x + 2, y + h - 1, w - 4, 1, color)
      b.fill_rect(x, y + 2, 1, h - 4, color)
      b.fill_rect(x + w - 1, y + 2, 1, h - 4, color)
    end

    def draw_text(b, x, y, w, h, text, color, align = 0)
      if defined?(pbDrawShadowText)
        pbDrawShadowText(b, x, y, w, h, text.to_s, color, SHADOW, align)
      else
        b.font.color = color
        b.draw_text(x, y, w, h, text.to_s, align)
      end
    end

    def mouse_position
      return MouseUI.pointer_position if defined?(MouseUI) && MouseUI.respond_to?(:pointer_position)
      return [Input.mouse_x, Input.mouse_y] if Input.respond_to?(:mouse_x) && Input.respond_to?(:mouse_y)
      nil
    rescue
      nil
    end

    def mouse_left?
      mouse_trigger?
    end

    def mouse_trigger?
      return false if !defined?(Input::MOUSELEFT)
      Input.trigger?(Input::MOUSELEFT)
    rescue
      false
    end

    def mouse_pressed?
      return false if !defined?(Input::MOUSELEFT)
      return Input.press?(Input::MOUSELEFT) if Input.respond_to?(:press?)
      Input.trigger?(Input::MOUSELEFT)
    rescue
      false
    end

    def button_at(mx, my)
      @buttons.find { |button| hit?(button[:rect], mx, my) }
    end

    def hit?(rect, mx, my)
      mx >= rect[0] && mx < rect[0] + rect[2] && my >= rect[1] && my < rect[1] + rect[3]
    end
  end

  def self.start_walkalong(path)
    path = absolute_path(path)
    return false unless File.file?(path)
    WalkalongOverlay.start(path) if defined?(WalkalongOverlay)
    rect = defined?(WalkalongOverlay) ? WalkalongOverlay.screen_rect : nil
    started = false
    if respond_to?(:native_core_enabled?) && native_core_enabled?
      started = start_native_core(path, rect)
      return true if started
      if respond_to?(:bridge_backend) && bridge_backend == "native"
        WalkalongOverlay.stop if defined?(WalkalongOverlay)
        return false
      end
    end
    unless start_mirror(path, rect)
      WalkalongOverlay.stop if defined?(WalkalongOverlay)
      return false
    end
    WalkalongOverlay.sync_mirror_rect if defined?(WalkalongOverlay)
    true
  end
end

if defined?(Graphics) && Graphics.respond_to?(:update)
  class << Graphics
    alias gba_player_walkalong_original_update update unless method_defined?(:gba_player_walkalong_original_update)

    def update
      gba_player_walkalong_original_update
      if defined?(GBAPlayer::WalkalongOverlay) && GBAPlayer::WalkalongOverlay.active?
        GBAPlayer::WalkalongOverlay.update
      end
    end
  end
end
