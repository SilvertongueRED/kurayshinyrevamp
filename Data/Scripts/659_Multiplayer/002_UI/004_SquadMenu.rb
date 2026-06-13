# ===========================================
# File: 006_UI_SquadMenu.rb
# Purpose: Pause-menu "Squad" entry + Squad window/actions
#         + Bottom-left "Coop : NvN" proximity HUD (crisp text)
# Notes: No base edits; safe alias hooks only.
# ===========================================

##MultiplayerDebug.info("UI-SQ", "Squad menu hook loaded.")

module MultiplayerUI
  def self.inject_squad_entry(cmds)
    return false unless cmds.is_a?(Array)
    begin
      return false unless MultiplayerClient.instance_variable_get(:@connected)
      MultiplayerClient.request_squad_state
      return false unless MultiplayerClient.in_squad?

      label = _INTL("Squad")
      return false if cmds.include?(label)

      idx = cmds.index(_INTL("Player List"))
      if idx
        cmds.insert(idx + 1, label)
      else
        oi = cmds.index(_INTL("Outfit"))
        insert_at = oi ? (oi + 1) : cmds.length
        cmds.insert(insert_at, label)
      end
      ##MultiplayerDebug.info("UI-SQ", "Injected 'Squad' option.")
      true
    rescue => e
      ##MultiplayerDebug.error("UI-SQ", "Injection failed: #{e.message}")
      false
    end
  end

  def self.openSquadWindow
    unless MultiplayerClient.in_squad?
      pbMessage(_INTL("You are not in a squad."))
      return
    end

    # Set flag to prevent multiple windows
    MultiplayerUI.instance_variable_set(:@squadwindow_open, true)
    MultiplayerUI.instance_variable_set(:@squadwindow_close_requested, false)

    MultiplayerClient.request_squad_state

    begin
      viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      viewport.z = 99999

      bg = Sprite.new(viewport)
      bg.bitmap = Bitmap.new(Graphics.width, Graphics.height)
      bg.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0, 160))

      squad   = MultiplayerClient.squad
      leader  = squad[:leader].to_s
      my_sid  = MultiplayerClient.session_id.to_s
      is_leader = (leader == my_sid)

      names = squad[:members].map do |m|
        tag = (m[:sid] == leader) ? _INTL(" (Leader)") : ""
        _INTL("{1}{2}", m[:name].to_s, tag)
      end

      win = Window_CommandPokemon.new(names)
      win.viewport = viewport
      win.width  = Graphics.width - 32
      win.height = 160
      win.x = 16
      win.y = (Graphics.height - win.height) / 2
      win.opacity = 210
      win.index = 0

      help_text = _INTL("Select a member for actions.")
      help = Window_UnformattedTextPokemon.newWithSize(
        help_text, 0, 0, Graphics.width - 32, 64, viewport
      )
      help.x = (Graphics.width - help.width) / 2
      help.y = win.y - help.height - 8

      loop do
        Graphics.update
        Input.update
        win.update

        # Check for F4 close request
        if MultiplayerUI.instance_variable_get(:@squadwindow_close_requested)
          ##MultiplayerDebug.info("UI-SQ-F4CLOSE", "F4 close request detected")
          MultiplayerUI.instance_variable_set(:@squadwindow_close_requested, false)
          pbSEPlay("GUI menu close")
          break
        end

        if Input.trigger?(Input::BACK)
          pbSEPlay("GUI menu close"); break
        elsif Input.trigger?(Input::USE)
          sel = win.index
          member      = squad[:members][sel]
          chosen_sid  = member[:sid].to_s
          chosen_name = member[:name].to_s
          is_self     = (chosen_sid == my_sid)

          # Combined action menu: the SAME per-player actions as the F3 Player List
          # (minus Invite to Squad -- they're already here) plus squad management.
          opts = []
          acts = []
          if is_self
            opts << _INTL("View Profile");       acts << :profile
          else
            opts << _INTL("View Profile");       acts << :profile
            opts << _INTL("Send PM");            acts << :pm
            opts << _INTL("Battle Request");     acts << :battle
            opts << _INTL("Request Trade");      acts << :trade
            opts << _INTL("Inspect Party");      acts << :inspect
            opts << _INTL("Teleport to Player"); acts << :teleport
          end
          if is_leader && !is_self
            opts << _INTL("Make Leader");        acts << :make_leader
            opts << _INTL("Kick from Squad");    acts << :kick
          end
          opts << _INTL("Leave Squad");          acts << :leave
          opts << _INTL("Cancel");               acts << :cancel

          choice = pbMessage(_INTL("{1}:", chosen_name), opts, opts.length)  # cmdIfCancel is 1-based -> last opt ("Cancel")
          act = acts[choice] || :cancel

          # The player actions reuse the shared executor (identical to F3). They
          # open their own UI or fire their own request, so close the squad window
          # first to avoid overlapping overlays.
          ctx_map = { :profile => 0, :pm => 1, :battle => 3, :trade => 4, :inspect => 5, :teleport => 6 }
          if ctx_map.key?(act)
            MultiplayerUI.instance_variable_set(:@squadwindow_open, false)
            help.dispose if help && !help.disposed?
            win.dispose  if win && !win.disposed?
            bg.dispose   if bg && !bg.disposed?
            viewport.dispose if viewport && !viewport.disposed?
            # Defer the action until we're back on the map. The Squad window
            # runs inside the pause-menu scene, where map-context UIs (e.g.
            # ProfilePanel.open) bail out because overlay_scene_type != :map.
            # Scene_Map.update fires this once the pause menu has fully closed.
            MultiplayerUI.instance_variable_set(:@pending_ctx_action, [ctx_map[act], chosen_sid, chosen_name])
            return
          end

          case act
          when :make_leader then MultiplayerClient.transfer_leadership(chosen_sid)
          when :kick        then MultiplayerClient.kick_from_squad(chosen_sid)
          when :leave
            MultiplayerClient.leave_squad
            break
          end

          MultiplayerClient.request_squad_state
          squad = MultiplayerClient.squad
          if !squad || !MultiplayerClient.in_squad?
            pbMessage(_INTL("You are no longer in a squad.")); break
          end
          leader = squad[:leader].to_s
          is_leader = (leader == my_sid)

          names = squad[:members].map do |m|
            tag = (m[:sid] == leader) ? _INTL(" (Leader)") : ""
            _INTL("{1}{2}", m[:name].to_s, tag)
          end
          win.commands = names
          win.index = [win.index, names.length - 1].min
        end
      end

      help.dispose if help && !help.disposed?
      win.dispose  if win && !win.disposed?
      bg.dispose   if bg && !bg.disposed?
      viewport.dispose if viewport && !viewport.disposed?
    rescue => e
      ##MultiplayerDebug.error("UI-SQ", "Exception in Squad window: #{e.class} - #{e.message}")
      begin
        help.dispose if help && !help.disposed?
        win.dispose  if win && !win.disposed?
        bg.dispose   if bg && !bg.disposed?
        viewport.dispose if viewport && !viewport.disposed?
      rescue; end
      pbMessage(_INTL("Squad menu encountered an error and was closed."))
    ensure
      # Always clear flag when window closes
      MultiplayerUI.instance_variable_set(:@squadwindow_open, false)
    end
  end

  # Fire a ctx action deferred from the Squad window (which runs inside the
  # pause-menu scene). Runs only on the map so map-context UIs like the Profile
  # panel don't bail on the overlay_scene_type guard.
  def self.fire_pending_ctx_action
    pa = MultiplayerUI.instance_variable_get(:@pending_ctx_action)
    return unless pa
    return if ($game_temp && $game_temp.in_menu rescue false)
    begin
      return unless MultiplayerUI.respond_to?(:overlay_scene_type) &&
                    MultiplayerUI.overlay_scene_type == :map
    rescue
      return
    end
    MultiplayerUI.instance_variable_set(:@pending_ctx_action, nil)
    begin
      Input._execute_ctx_action(pa[0], pa[1], pa[2])
    rescue => e
      ##MultiplayerDebug.error("UI-SQ", "Deferred ctx action error: #{e.message}")
    end
  end
end

# === Hook into Pause Menu (Scene level) like Player List does ===
if defined?(PokemonPauseMenu_Scene)
  class ::PokemonPauseMenu_Scene
    alias kif_sq_pbShowCommands pbShowCommands unless method_defined?(:kif_sq_pbShowCommands)
    def pbShowCommands(commands)
      loop do
        display = commands.dup
        MultiplayerUI.inject_squad_entry(display)
        ret_disp = kif_sq_pbShowCommands(display)
        return ret_disp if ret_disp.nil? || ret_disp < 0
        if display[ret_disp] == _INTL("Squad")
          begin; MultiplayerUI.openSquadWindow; rescue => e
            ##MultiplayerDebug.error("UI-SQ", "Open squad error: #{e.message}")
          end
          # If a per-player action was queued (View Profile, Inspect, etc.),
          # close the pause menu so it can fire on the map. Otherwise the user
          # just backed out of the Squad window -> re-show the pause menu.
          return -1 if MultiplayerUI.instance_variable_get(:@pending_ctx_action)
          next
        end
        if display.length != commands.length
          insert_at = (display.index(_INTL("Squad")) || display.length) - 1
          return ret_disp - 1 if ret_disp > insert_at
        end
        return ret_disp
      end
    end
  end
  ##MultiplayerDebug.info("UI-SQ", "Hooked PokemonPauseMenu_Scene.pbShowCommands for Squad option.")
else
  ##MultiplayerDebug.warn("UI-SQ", "PokemonPauseMenu_Scene not found — Squad menu hook disabled.")
end

# ===========================================
# HUD: Bottom-left "Coop : NvN" proximity indicator (crisp text)
# ===========================================

if defined?(Scene_Map)
  module MultiplayerUI
    class CoopHUD
      UPDATE_TICKS = 10        # ~6x/sec
      WIDTH  = 220
      HEIGHT = 44
      PADX   = 12
      PADY   = 8
      FONT_MAX = 24
      FONT_MIN = 16

      def initialize
        @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
        @viewport.z = 99_400
        @ticks = 0
        @visible = false
        @last_text = nil

        # Panel/window (box only; we never let it render text)
        @win = if defined?(Window_UnformattedTextPokemon)
                 Window_UnformattedTextPokemon.newWithSize("", 8, Graphics.height - HEIGHT - 8, WIDTH, HEIGHT, @viewport)
               else
                 Window_Selectable.new(8, Graphics.height - HEIGHT - 8, WIDTH, HEIGHT)
               end
        @win.opacity = 160 rescue nil
        @win.back_opacity = 160 if @win.respond_to?(:back_opacity)
        @win.visible = false
        begin
          @win.text = "" if @win.respond_to?(:text=)
          @win.setText("") if @win.respond_to?(:setText)
        rescue; end

        # Text sprite (we draw our own text, centered)
        @textspr = Sprite.new(@viewport)
        @textspr.x = @win.x + PADX
        @textspr.y = @win.y + PADY
        @textspr.z = (@win.z || 0) + 1 rescue 0
        @textspr.visible = false
        @textspr.bitmap = Bitmap.new(WIDTH - PADX*2, HEIGHT - PADY*2)
        _kif_set_font(@textspr.bitmap)

        ##MultiplayerDebug.info("UI-COOP-HUD", "HUD initialized (#{WIDTH}x#{HEIGHT}).")
      rescue => e
        ##MultiplayerDebug.error("UI-COOP-HUD", "Init error: #{e.class} - #{e.message}")
        dispose rescue nil
      end

      def dispose
        if @textspr
          @textspr.bitmap.dispose if @textspr.bitmap && !@textspr.bitmap.disposed?
          @textspr.dispose
        end
        @win.dispose      if @win && !@win.disposed?
        @viewport.dispose if @viewport && !@viewport.disposed?
        ##MultiplayerDebug.info("UI-COOP-HUD", "HUD disposed.")
      rescue => e
        ##MultiplayerDebug.error("UI-COOP-HUD", "Dispose error: #{e.message}")
      end

      def update
        return unless @win && !@win.disposed?
        @ticks += 1
        return if (@ticks % UPDATE_TICKS) != 0

        begin
          if !MultiplayerClient.instance_variable_get(:@connected) || !MultiplayerClient.in_squad?
            set_visible(false); return
          end

          mode_text = compute_mode_text
          if mode_text.nil? || mode_text.empty?
            set_visible(false)
          else
            if @last_text != mode_text
              set_text(mode_text)
              @last_text = mode_text
              ##MultiplayerDebug.info("UI-COOP-HUD", "Label=#{mode_text}")
            end
            set_visible(true)
          end
        rescue => e
          ##MultiplayerDebug.error("UI-COOP-HUD", "Update error: #{e.class} - #{e.message}")
          set_visible(false)
        end
      end

      private

      def _kif_set_font(bmp)
        if defined?(pbSetSystemFont)
          pbSetSystemFont(bmp)
        else
          # default font ok
        end
      end

      def _set_font_size(bmp, size)
        _kif_set_font(bmp)
        bmp.font.size = size
      rescue; end

      # center + outline
      def _draw_text_center_outlined(text)
        bmp = @textspr.bitmap
        bmp.clear

        # Pick a font size that fits WIDTH-2*PADX
        target_w = bmp.width
        size = FONT_MAX
        loop do
          _set_font_size(bmp, size)
          w = bmp.text_size(text).width
          break if w <= target_w || size <= FONT_MIN
          size -= 1
        end

        w = bmp.text_size(text).width
        h = bmp.text_size(text).height
        x = (bmp.width  - w) / 2
        y = (bmp.height - h) / 2

        # Outline/shadow
        [[-1,0],[1,0],[0,-1],[0,1]].each do |dx,dy|
          bmp.font.color = Color.new(40,40,40)
          bmp.draw_text(Rect.new(x+dx, y+dy, w, h), text, 0)
        end
        bmp.font.color = Color.new(248,248,248)
        bmp.draw_text(Rect.new(x, y, w, h), text, 0)
      end

      def set_text(txt)
        # ensure panel stays bottom-left even if screen size changes
        @win.x = 8
        @win.y = Graphics.height - HEIGHT - 8
        @win.width  = WIDTH  rescue nil
        @win.height = HEIGHT rescue nil

        @textspr.x = @win.x + PADX
        @textspr.y = @win.y + PADY
        if !@textspr.bitmap || @textspr.bitmap.disposed? ||
           @textspr.bitmap.width  != (WIDTH - PADX*2) ||
           @textspr.bitmap.height != (HEIGHT - PADY*2)
          @textspr.bitmap.dispose if @textspr.bitmap && !@textspr.bitmap.disposed?
          @textspr.bitmap = Bitmap.new(WIDTH - PADX*2, HEIGHT - PADY*2)
          _kif_set_font(@textspr.bitmap)
        end

        _draw_text_center_outlined(txt)
      end

      def set_visible(flag)
        return if @visible == flag
        @visible = flag
        @win.visible     = flag rescue nil
        @textspr.visible = flag rescue nil
        ##MultiplayerDebug.info("UI-COOP-HUD", flag ? "Shown" : "Hidden")
      end

      # Returns "Coop : 1v1/2v2/3v3" or nil
      def compute_mode_text
        squad = MultiplayerClient.squad rescue nil
        return nil unless squad && squad[:members].is_a?(Array)
        my_sid = MultiplayerClient.session_id.to_s rescue nil
        return nil if my_sid.nil? || my_sid.empty?

        # If *you* are busy, force 1v1 display
        begin
          if MultiplayerClient.respond_to?(:player_busy?) && MultiplayerClient.player_busy?(my_sid)
            return "Coop : 1v1"
          end
        rescue; end

        my_map = $game_map.map_id rescue nil
        my_x   = $game_player.x   rescue nil
        my_y   = $game_player.y   rescue nil
        return nil unless my_map && my_x && my_y

        players_hash = (MultiplayerClient.players rescue nil)
        return nil unless players_hash.is_a?(Hash)

        total_players = 1

        squad[:members].each do |m|
          sid = m[:sid].to_s
          next if sid.empty? || sid == my_sid
          pinfo = players_hash[sid] rescue nil
          # must be on same map
          next unless pinfo && pinfo[:map].to_i == my_map.to_i

          # skip allies who are busy
          begin
            next if MultiplayerClient.respond_to?(:player_busy?) && MultiplayerClient.player_busy?(sid)
          rescue; end

          dx = (pinfo[:x].to_i - my_x).abs
          dy = (pinfo[:y].to_i - my_y).abs
          dist = dx + dy
          total_players += 1 if dist <= 12
        end

        total_players = [[total_players, 1].max, 3].min
        case total_players
        when 1 then "Coop : 1v1"
        when 2 then "Coop : 2v2"
        else        "Coop : 3v3"
        end
      rescue => e
        ##MultiplayerDebug.error("UI-COOP-HUD", "compute_mode_text error: #{e.message}")
        nil
      end
    end
  end


  # === Robust Scene_Map hooks ===
  class Scene_Map
    def self._kif_has_method?(sym); instance_methods(false).map { |m| m.to_sym }.include?(sym); end

    if _kif_has_method?(:start)
      ##MultiplayerDebug.info("UI-COOP-HUD", "Hooking Scene_Map.start")
      alias kif_coop_hud_start start unless method_defined?(:kif_coop_hud_start)
      def start
        kif_coop_hud_start
        begin
          @kif_coop_hud ||= MultiplayerUI::CoopHUD.new
          ##MultiplayerDebug.info("UI-COOP-HUD", "Scene_Map.start → HUD created.")
        rescue => e
          ##MultiplayerDebug.error("UI-COOP-HUD", "Scene_Map.start error: #{e.message}")
        end
      end
    elsif _kif_has_method?(:main)
      ##MultiplayerDebug.info("UI-COOP-HUD", "Hooking Scene_Map.main (no :start found)")
      alias kif_coop_hud_main main unless method_defined?(:kif_coop_hud_main)
      def main
        begin
          @kif_coop_hud ||= MultiplayerUI::CoopHUD.new
          ##MultiplayerDebug.info("UI-COOP-HUD", "Scene_Map.main → HUD created (pre).")
        rescue => e
          ##MultiplayerDebug.error("UI-COOP-HUD", "Scene_Map.main pre error: #{e.message}")
        end
        kif_coop_hud_main
        begin
          if @kif_coop_hud
            @kif_coop_hud.dispose; @kif_coop_hud = nil
            ##MultiplayerDebug.info("UI-COOP-HUD", "Scene_Map.main → HUD disposed (post).")
          end
        rescue => e
          ##MultiplayerDebug.error("UI-COOP-HUD", "Scene_Map.main post error: #{e.message}")
        end
      end
    else
      ##MultiplayerDebug.warn("UI-COOP-HUD", "Scene_Map has neither :start nor :main; will lazy-init in :update.")
    end

    if _kif_has_method?(:terminate)
      ##MultiplayerDebug.info("UI-COOP-HUD", "Hooking Scene_Map.terminate")
      alias kif_coop_hud_terminate terminate unless method_defined?(:kif_coop_hud_terminate)
      def terminate
        begin
          if @kif_coop_hud
            @kif_coop_hud.dispose; @kif_coop_hud = nil
            ##MultiplayerDebug.info("UI-COOP-HUD", "Scene_Map.terminate → HUD disposed.")
          end
        rescue => e
          ##MultiplayerDebug.error("UI-COOP-HUD", "Scene_Map.terminate error: #{e.message}")
        end
        kif_coop_hud_terminate
      end
    end

    if _kif_has_method?(:update)
      ##MultiplayerDebug.info("UI-COOP-HUD", "Hooking Scene_Map.update")
      alias kif_coop_hud_update update unless method_defined?(:kif_coop_hud_update)
      def update
        if !@kif_coop_hud
          begin
            @kif_coop_hud = MultiplayerUI::CoopHUD.new
            ##MultiplayerDebug.info("UI-COOP-HUD", "Scene_Map.update → HUD created (lazy).")
          rescue => e
            ##MultiplayerDebug.error("UI-COOP-HUD", "Scene_Map.update lazy-init error: #{e.message}")
          end
        end
        begin
          @kif_coop_hud.update if @kif_coop_hud
        rescue => e
          ##MultiplayerDebug.error("UI-COOP-HUD", "Scene_Map.update HUD error: #{e.message}")
        end
        (MultiplayerUI.fire_pending_ctx_action rescue nil)
        kif_coop_hud_update
      end
    else
      ##MultiplayerDebug.warn("UI-COOP-HUD", "Scene_Map has no :update; HUD will not tick.")
    end
  end
else
  ##MultiplayerDebug.warn("UI-COOP-HUD", "Scene_Map not found — HUD disabled.")
end
