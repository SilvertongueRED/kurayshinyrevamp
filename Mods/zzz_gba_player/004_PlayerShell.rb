# frozen_string_literal: true

module GBAPlayer
  class ShellScene
    BG = Color.new(18, 22, 30, 230)
    PANEL = Color.new(42, 49, 66, 245)
    PANEL_2 = Color.new(26, 31, 43, 245)
    BORDER = Color.new(172, 184, 204)
    WHITE = Color.new(248, 248, 248)
    DIM = Color.new(174, 184, 196)
    SHADOW = Color.new(0, 0, 0)
    ACCENT = Color.new(71, 126, 180)
    ACCENT_2 = Color.new(120, 192, 168)
    DANGER = Color.new(178, 70, 86)

    def initialize(mode = :mobile)
      @mode = mode
    end

    def pbStart
      setup
      main
    ensure
      dispose
    end

    def pc_mode?
      @mode == :pc
    end

    def setup
      @roms = GBAPlayer.discover_roms
      @selected = selected_index_from_last
      @status = GBAPlayer.bridge_status
      @done = false
      @buttons = []
      @keep_mirror_on_dispose = false
      @mirror_active = GBAPlayer.mirror_running?
      @mirror_launching = false
      @last_frame_mtime = nil
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 100_000
      @sprite = Sprite.new(@viewport)
      @sprite.bitmap = Bitmap.new(Graphics.width, Graphics.height)
      @frame_sprite = Sprite.new(@viewport)
      @frame_sprite.z = 50
      @frame_sprite.visible = false
      @hud_sprite = Sprite.new(@viewport)
      @hud_sprite.z = 100
      @hud_sprite.bitmap = Bitmap.new(Graphics.width, Graphics.height)
      draw
    end

    def main
      loop do
        Graphics.update
        Input.update
        update
        update_mirror_frame
        break if @done
      end
    end

    def update
      refresh_mirror_state
      clicked = mouse_left?
      return if update_mouse(clicked) || clicked
      if @mirror_active
        if input_trigger?(:UP) then tap_mirror("UP")
        elsif input_trigger?(:DOWN) then tap_mirror("DOWN")
        elsif input_trigger?(:LEFT) then tap_mirror("LEFT")
        elsif input_trigger?(:RIGHT) then tap_mirror("RIGHT")
        elsif input_trigger?(:USE) || input_trigger?(:C) then tap_mirror("A")
        elsif input_trigger?(:BACK) || input_trigger?(:B) then tap_mirror("B")
        end
        return
      end
      if input_trigger?(:BACK) || input_trigger?(:B)
        @done = true
        return
      end
      if input_trigger?(:UP)
        move_selection(-1)
      elsif input_trigger?(:DOWN)
        move_selection(1)
      elsif input_trigger?(:LEFT)
        move_selection(-1)
      elsif input_trigger?(:RIGHT)
        move_selection(1)
      elsif input_trigger?(:USE) || input_trigger?(:C)
        launch_selected
      end
    end

    def update_mouse(clicked = nil)
      clicked = mouse_left? if clicked.nil?
      return false unless clicked
      pos = mouse_position
      return false unless pos
      mx, my = pos
      @buttons.each do |button|
        next unless hit?(button[:rect], mx, my)
        handle_action(button[:action])
        return true
      end
      false
    end

    def handle_action(action)
      case action
      when :play then launch_selected
      when :stop
        GBAPlayer.stop_mirror
        @mirror_active = false
        @mirror_launching = false
        @status = "Mirror stopped."
        clear_frame
        draw
      when :tap_a then @mirror_active ? tap_mirror("A") : launch_selected
      when :tap_b then @mirror_active ? tap_mirror("B") : (@done = true)
      when :tap_up then tap_mirror("UP")
      when :tap_down then tap_mirror("DOWN")
      when :tap_left then tap_mirror("LEFT")
      when :tap_right then tap_mirror("RIGHT")
      when :tap_start then tap_mirror("START")
      when :tap_select then tap_mirror("SELECT")
      when :prev_rom
        move_selection(-1)
      when :next_rom
        move_selection(1)
      when :refresh
        @roms = GBAPlayer.discover_roms
        @selected = [@selected, @roms.length - 1].min
        @selected = 0 if @selected < 0
        @status = "Library refreshed. Found #{@roms.length} ROM(s)."
        draw
      when :resume
        resume_last
      when :import
        return unless pc_mode?
        with_hidden_shell { GBAPlayer.import_save_menu }
        @status = "Returned from save importer."
        draw
      when :settings
        with_hidden_shell { GBAPlayer.open_settings_menu }
        @status = GBAPlayer.bridge_status
        draw
      when :rom_folder
        GBAPlayer.open_folder(File.join(GBAPlayer::ROOT, "ROMs"))
      when :close
        @done = true
      end
    end

    def with_hidden_shell
      overlay_hidden = false
      pause_mirror = GBAPlayer.mirror_running?
      set_shell_visible(false)
      if defined?(GBAPlayer::WalkalongOverlay) && GBAPlayer::WalkalongOverlay.active?
        overlay_hidden = GBAPlayer::WalkalongOverlay.modal_hide
      elsif pause_mirror
        GBAPlayer.send_mirror_pause(true) if GBAPlayer.respond_to?(:send_mirror_pause)
      end
      yield
    ensure
      if overlay_hidden
        GBAPlayer::WalkalongOverlay.modal_show
      elsif pause_mirror
        GBAPlayer.send_mirror_pause(false) if GBAPlayer.respond_to?(:send_mirror_pause)
      end
      set_shell_visible(true)
    end

    def set_shell_visible(visible)
      [@sprite, @hud_sprite, @frame_sprite].each do |sprite|
        sprite.visible = visible if sprite && !sprite.disposed?
      end
    rescue
      nil
    end

    def selected_index_from_last
      last = GBAPlayer.absolute_path(GBAPlayer.config["last_rom"])
      index = @roms.index { |path| path.downcase == last.downcase }
      index || 0
    end

    def move_selection(delta)
      return if @roms.empty?
      @selected = (@selected + delta) % @roms.length
      draw
    end

    def launch_selected
      if @roms.empty?
        @status = "No ROMs found. Put .gba files in Mods/zzz_gba_player/ROMs."
        draw
        return
      end
      rom = @roms[@selected]
      if GBAPlayer.start_walkalong(rom)
        @mirror_active = true
        @mirror_launching = true
        @keep_mirror_on_dispose = true
        @done = true
        @status = "Starting #{GBAPlayer.rom_label(rom)} as walkalong..."
      else
        @status = "Mirror launch failed. Open Settings for bridge/emulator status."
      end
      draw
    end

    def resume_last
      path = GBAPlayer.absolute_path(GBAPlayer.config["last_rom"])
      if path.empty? || !File.file?(path)
        @status = "No last-played ROM was found."
        draw
        return
      end
      @selected = @roms.index { |rom| rom.downcase == path.downcase } || @selected
      if GBAPlayer.start_walkalong(path)
        @mirror_active = true
        @mirror_launching = true
        @keep_mirror_on_dispose = true
        @done = true
        @status = "Resuming #{GBAPlayer.rom_label(path)} as walkalong..."
      else
        @status = "Mirror resume failed. Open Settings for bridge/emulator status."
      end
      draw
    end

    def tap_mirror(button)
      if GBAPlayer.send_mirror_button(button)
        @status = "#{button}"
      else
        @status = "Mirror is not ready yet."
      end
      draw_status(@hud_sprite.bitmap) if @hud_sprite && @hud_sprite.bitmap
    end

    def refresh_mirror_state
      was_active = @mirror_active
      state = GBAPlayer.mirror_status["state"].to_s
      if state == "ready"
        @mirror_launching = false
        @mirror_active = true
      elsif @mirror_launching && state.empty?
        @mirror_active = true
      else
        @mirror_launching = false if state == "error" || state == "stopped"
        @mirror_active = false
      end
      draw if was_active != @mirror_active
    end

    def update_mirror_frame
      return clear_frame if !@mirror_active
      frame_path = GBAPlayer.mirror_frame_path
      return unless File.file?(frame_path)
      mtime = File.mtime(frame_path) rescue nil
      return if !mtime || mtime == @last_frame_mtime
      bitmap = Bitmap.new(frame_path) rescue nil
      return if !bitmap
      old = @frame_sprite.bitmap
      @frame_sprite.bitmap = bitmap
      old.dispose if old && !old.disposed?
      @last_frame_mtime = mtime
      apply_frame_rect
    end

    def apply_frame_rect
      return if !@screen_rect || !@frame_sprite || !@frame_sprite.bitmap
      x, y, w, h = @screen_rect
      @frame_sprite.x = x
      @frame_sprite.y = y
      @frame_sprite.zoom_x = w.to_f / @frame_sprite.bitmap.width
      @frame_sprite.zoom_y = h.to_f / @frame_sprite.bitmap.height
      @frame_sprite.visible = true
    end

    def clear_frame
      return if !@frame_sprite
      @frame_sprite.visible = false
      if @frame_sprite.bitmap && !@frame_sprite.bitmap.disposed?
        @frame_sprite.bitmap.dispose
      end
      @frame_sprite.bitmap = nil
      @last_frame_mtime = nil
    rescue
      nil
    end

    def draw
      base = @sprite.bitmap
      hud = @hud_sprite.bitmap
      base.clear
      hud.clear
      @buttons.clear
      draw_background(base)
      draw_screen(base)
      if @mirror_active
        draw_play_header(hud)
      else
        draw_header(hud)
        draw_cartridge(hud)
      end
      draw_controls(hud)
      draw_status(hud)
      apply_frame_rect
    end

    def draw_background(b)
      if @mirror_active
        b.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(2, 4, 8, 245))
        b.fill_rect(0, 0, Graphics.width, 24, Color.new(14, 18, 26, 190))
        b.fill_rect(0, Graphics.height - 34, Graphics.width, 34, Color.new(14, 18, 26, 190))
      else
        b.fill_rect(0, 0, Graphics.width, Graphics.height, BG)
        draw_rect(b, 10, 10, Graphics.width - 20, Graphics.height - 20, Color.new(48, 56, 74, 250))
        draw_rect(b, 18, 18, Graphics.width - 36, Graphics.height - 36, PANEL)
        draw_border(b, 10, 10, Graphics.width - 20, Graphics.height - 20, BORDER)
        draw_border(b, 18, 18, Graphics.width - 36, Graphics.height - 36, Color.new(85, 96, 116))
        b.fill_rect(32, Graphics.height - 90, Graphics.width - 64, 4, Color.new(21, 25, 34))
        b.fill_rect(34, Graphics.height - 84, Graphics.width - 68, 2, Color.new(82, 92, 112))
      end
    end

    def draw_header(b)
      pbSetSystemFont(b) if defined?(pbSetSystemFont)
      b.font.size = 24
      draw_text(b, 28, 18, 150, 30, "GBA Player", WHITE)
      b.font.size = 13
      status = @mirror_active ? "LIVE" : "READY"
      color = @mirror_active ? ACCENT_2 : DIM
      draw_text(b, Graphics.width - 114, 20, 82, 22, status, color, 2)
    end

    def draw_cartridge(b)
      y = 42
      prev_rect = [28, y, 26, 22]
      cart_rect = [58, y, 226, 22]
      next_rect = [288, y, 26, 22]
      draw_rect(b, prev_rect[0], prev_rect[1], prev_rect[2], prev_rect[3], Color.new(34, 40, 54))
      draw_rect(b, next_rect[0], next_rect[1], next_rect[2], next_rect[3], Color.new(34, 40, 54))
      draw_rect(b, cart_rect[0], cart_rect[1], cart_rect[2], cart_rect[3], Color.new(27, 32, 44))
      draw_border(b, cart_rect[0], cart_rect[1], cart_rect[2], cart_rect[3], BORDER)
      @buttons << { :rect => prev_rect, :action => :prev_rom }
      @buttons << { :rect => next_rect, :action => :next_rom }
      pbSetSystemFont(b) if defined?(pbSetSystemFont)
      b.font.size = 14
      draw_text(b, prev_rect[0], prev_rect[1] + 1, prev_rect[2], prev_rect[3] - 2, "<", WHITE, 1)
      draw_text(b, next_rect[0], next_rect[1] + 1, next_rect[2], next_rect[3] - 2, ">", WHITE, 1)
      draw_text(b, cart_rect[0] + 8, cart_rect[1] + 1, cart_rect[2] - 16, cart_rect[3] - 2, selected_rom_label, WHITE, 1)
      play_rect = [Graphics.width - 174, y, 62, 22]
      close_rect = [Graphics.width - 104, y, 72, 22]
      draw_rect(b, play_rect[0], play_rect[1], play_rect[2], play_rect[3], @mirror_active ? DANGER : ACCENT_2)
      draw_rect(b, close_rect[0], close_rect[1], close_rect[2], close_rect[3], Color.new(34, 40, 54))
      draw_border(b, play_rect[0], play_rect[1], play_rect[2], play_rect[3], BORDER)
      draw_border(b, close_rect[0], close_rect[1], close_rect[2], close_rect[3], BORDER)
      @buttons << { :rect => play_rect, :action => @mirror_active ? :stop : :play }
      @buttons << { :rect => close_rect, :action => :close }
      draw_text(b, play_rect[0], play_rect[1] + 1, play_rect[2], play_rect[3] - 2, @mirror_active ? "Stop" : "Play", WHITE, 1)
      draw_text(b, close_rect[0], close_rect[1] + 1, close_rect[2], close_rect[3] - 2, "Close", WHITE, 1)
    end

    def draw_play_header(b)
      y = 10
      label = selected_rom_label
      bar = [16, y, Graphics.width - 32, 24]
      stop_rect = [Graphics.width - 158, y + 1, 58, 22]
      close_rect = [Graphics.width - 92, y + 1, 76, 22]
      draw_rect(b, bar[0], bar[1], bar[2], bar[3], Color.new(12, 16, 24, 220))
      draw_border(b, bar[0], bar[1], bar[2], bar[3], Color.new(86, 98, 120))
      draw_rect(b, stop_rect[0], stop_rect[1], stop_rect[2], stop_rect[3], DANGER)
      draw_rect(b, close_rect[0], close_rect[1], close_rect[2], close_rect[3], Color.new(34, 40, 54, 235))
      draw_border(b, stop_rect[0], stop_rect[1], stop_rect[2], stop_rect[3], BORDER)
      draw_border(b, close_rect[0], close_rect[1], close_rect[2], close_rect[3], BORDER)
      @buttons << { :rect => stop_rect, :action => :stop }
      @buttons << { :rect => close_rect, :action => :close }
      pbSetSystemFont(b) if defined?(pbSetSystemFont)
      b.font.size = 14
      draw_text(b, bar[0] + 10, bar[1] + 2, bar[2] - 180, 20, label, WHITE)
      draw_text(b, stop_rect[0], stop_rect[1] + 1, stop_rect[2], stop_rect[3] - 2, "Stop", WHITE, 1)
      draw_text(b, close_rect[0], close_rect[1] + 1, close_rect[2], close_rect[3] - 2, "Close", WHITE, 1)
    end

    def draw_screen(b)
      x, y, w, h = screen_geometry
      @screen_rect = [x, y, w, h]
      frame_pad = @mirror_active ? 8 : 14
      draw_rect(b, x - frame_pad, y - frame_pad, w + frame_pad * 2, h + frame_pad * 2, Color.new(13, 17, 24))
      draw_border(b, x - frame_pad, y - frame_pad, w + frame_pad * 2, h + frame_pad * 2, BORDER)
      b.fill_rect(x, y, w, h, Color.new(3, 7, 11))
      b.fill_rect(x + 4, y + 4, w - 8, h - 8, Color.new(10, 18, 26))
      return if @mirror_active
      label = selected_rom_label
      pbSetSystemFont(b) if defined?(pbSetSystemFont)
      b.font.size = 26
      draw_text(b, x + 12, y + (h / 2) - 30, w - 24, 36, label, WHITE, 1)
      b.font.size = 14
      detail = @roms.empty? ? "No cartridge inserted" : "Press A or Play"
      draw_text(b, x + 12, y + (h / 2) + 6, w - 24, 24, detail, DIM, 1)
    end

    def screen_geometry
      if @mirror_active
        max_w = Graphics.width - 32
        max_h = Graphics.height - 64
        w = [max_w, (max_h * 3 / 2)].min
        h = w * 2 / 3
        x = (Graphics.width - w) / 2
        y = (Graphics.height - h) / 2 + 4
        return [x, y, w, h]
      end
      w = [[Graphics.width - 212, 240].max, 300].min
      h = w * 2 / 3
      x = (Graphics.width - w) / 2
      [x, 70, w, h]
    end

    def draw_controls(b)
      y = Graphics.height - 98
      x = @mirror_active ? 28 : 54
      pad = @mirror_active ? Color.new(10, 14, 22, 220) : Color.new(18, 22, 32)
      draw_rect(b, x + 22, y, 24, 68, pad)
      draw_rect(b, x, y + 22, 68, 24, pad)
      draw_border(b, x + 22, y, 24, 68, BORDER)
      draw_border(b, x, y + 22, 68, 24, BORDER)
      @buttons << { :rect => [x + 22, y, 24, 22], :action => @mirror_active ? :tap_up : :prev_rom }
      @buttons << { :rect => [x + 22, y + 46, 24, 22], :action => @mirror_active ? :tap_down : :next_rom }
      @buttons << { :rect => [x, y + 22, 22, 24], :action => @mirror_active ? :tap_left : :prev_rom }
      @buttons << { :rect => [x + 46, y + 22, 22, 24], :action => @mirror_active ? :tap_right : :next_rom }
      if @mirror_active
        draw_round_button(b, Graphics.width - 112, y + 22, 36, "B", :tap_b, DANGER)
        draw_round_button(b, Graphics.width - 68, y + 4, 40, "A", :tap_a, ACCENT_2)
        draw_small_control(b, Graphics.width / 2 - 86, y + 42, "SELECT", :tap_select)
        draw_small_control(b, Graphics.width / 2 + 10, y + 42, "START", :tap_start)
      else
        draw_round_button(b, Graphics.width - 136, y + 22, 38, "B", :tap_b, DANGER)
        draw_round_button(b, Graphics.width - 88, y, 44, "A", :tap_a, ACCENT_2)
        if pc_mode?
          draw_small_control(b, Graphics.width / 2 - 88, y + 42, "IMPORT", :import)
          draw_small_control(b, Graphics.width / 2 + 12, y + 42, "SETTINGS", :settings)
        else
          draw_small_control(b, Graphics.width / 2 - 88, y + 42, "SETTINGS", :settings)
          draw_small_control(b, Graphics.width / 2 + 12, y + 42, "CLOSE", :close)
        end
        draw_speaker(b, Graphics.width - 64, y + 46)
      end
    end

    def draw_round_button(b, x, y, size, label, action, color)
      rect = [x, y, size, size]
      draw_rect(b, x, y, size, size, color)
      draw_border(b, x, y, size, size, BORDER)
      @buttons << { :rect => rect, :action => action }
      b.font.size = 22
      draw_text(b, x, y + 5, size, size - 8, label, WHITE, 1)
    end

    def draw_small_control(b, x, y, label, action)
      rect = [x, y, 78, 24]
      draw_rect(b, rect[0], rect[1], rect[2], rect[3], Color.new(26, 31, 43))
      draw_border(b, rect[0], rect[1], rect[2], rect[3], BORDER)
      @buttons << { :rect => rect, :action => action }
      b.font.size = 12
      draw_text(b, rect[0], rect[1] + 2, rect[2], rect[3] - 3, label, WHITE, 1)
    end

    def draw_status(b)
      x = 28
      y = Graphics.height - 28
      w = Graphics.width - 56
      draw_rect(b, x, y, w, 18, Color.new(25, 30, 42))
      draw_border(b, x, y, w, 18, Color.new(85, 96, 116))
      pbSetSystemFont(b) if defined?(pbSetSystemFont)
      b.font.size = 12
      draw_text(b, x + 8, y, w - 16, 18, @status.to_s, DIM)
    end

    def draw_speaker(b, x, y)
      color = Color.new(20, 24, 32)
      4.times do |i|
        b.fill_rect(x + i * 9, y + (i % 2), 3, 18, color)
      end
    end

    def selected_rom_label
      return "No ROM" if @roms.empty?
      GBAPlayer.rom_label(@roms[@selected])
    end

    def draw_rect(b, x, y, w, h, color)
      b.fill_rect(x + 2, y, w - 4, h, color)
      b.fill_rect(x, y + 2, w, h - 4, color)
      b.fill_rect(x + 1, y + 1, w - 2, h - 2, color)
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
      return false if !defined?(Input::MOUSELEFT)
      Input.trigger?(Input::MOUSELEFT)
    rescue
      false
    end

    def input_trigger?(name)
      return false unless defined?(Input)
      code = Input.const_get(name) rescue nil
      return false if !code
      Input.trigger?(code)
    rescue
      false
    end

    def hit?(rect, mx, my)
      mx >= rect[0] && mx < rect[0] + rect[2] && my >= rect[1] && my < rect[1] + rect[3]
    end

    def dispose
      if @sprite
        @sprite.bitmap.dispose if @sprite.bitmap && !@sprite.bitmap.disposed?
        @sprite.dispose
      end
      if @hud_sprite
        @hud_sprite.bitmap.dispose if @hud_sprite.bitmap && !@hud_sprite.bitmap.disposed?
        @hud_sprite.dispose
      end
      clear_frame
      @frame_sprite.dispose if @frame_sprite && !@frame_sprite.disposed?
      GBAPlayer.stop_mirror unless @keep_mirror_on_dispose
      @viewport.dispose if @viewport && !@viewport.disposed?
    rescue
      nil
    end
  end
end
