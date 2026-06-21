# ===========================================
# File: 016_ProfileF8Toggle.rb
# Purpose: Open/close the Profile panel on F8.
#          Escape and B also close it when open.
#          Pattern mirrors 014_CaseScreen_F7Toggle.rb exactly.
# ===========================================

module KIFProfileF8Toggle
  @last_badge_count = nil

  def self.tick_badge_sync
    return unless defined?(MultiplayerClient) && MultiplayerClient.session_id
    return if ($game_temp&.in_battle rescue false)
    count = ($Trainer.badges.count { |b| b == true } rescue nil)
    return if count.nil?
    if count != @last_badge_count
      @last_badge_count = count
      MultiplayerClient.send_data("STAT_BADGE_UPDATE:#{count}") rescue nil
    end
  rescue; end

  # True when ControlRebind's overworld MP-hotkey poller is the live handler for
  # the Profile action this frame: it has a :profile binding AND we are in the
  # overworld, where Scene_Map#update calls ControlRebind.mp_poll. When true we
  # must NOT also toggle on Input::F8, or the two handlers cancel each other out.
  def self.control_rebind_owns_profile_key?
    return false unless defined?(ControlRebind) && ControlRebind.respond_to?(:mp_bind)
    return false if ($game_temp && $game_temp.in_battle rescue false)
    return false unless ($scene.is_a?(Scene_Map) rescue false)
    !(ControlRebind.mp_bind[:profile] rescue nil).nil?
  rescue
    false
  end

  def self.tick_open_shortcut
    begin
      return unless defined?(MultiplayerClient) && MultiplayerClient.session_id
      ready = if defined?(MultiplayerUI) && MultiplayerUI.respond_to?(:overlay_hotkeys_available?)
                MultiplayerUI.overlay_hotkeys_available?
              else
                $scene && $scene.is_a?(Scene_Map) &&
                  !($game_temp&.in_menu rescue false) &&
                  !($game_temp&.in_battle rescue false) &&
                  !($game_player&.move_route_forcing rescue false)
              end
      return unless ready

      # F8: toggle own profile.
      # NOTE: ControlRebind.mp_poll also fires the :profile action on its bound
      # key (default "F8") every overworld frame, reading the physical F8 via
      # GetAsyncKeyState. If we ALSO toggle here on Input::F8, one F8 press
      # toggles TWICE in a single frame (open then immediately close) and the
      # panel never appears -- the reported bug. So in the overworld we cede F8
      # entirely to ControlRebind (the single, rebind-aware handler). In battle
      # ControlRebind does NOT poll the MP hotkeys, so we still handle F8 here.
      unless control_rebind_owns_profile_key?
        if defined?(Input::F8) && Input.trigger?(Input::F8)
          if defined?(MultiplayerUI::ProfilePanel) && MultiplayerUI::ProfilePanel.open?
            MultiplayerUI::ProfilePanel.close
          else
            MultiplayerUI::ProfilePanel.open(uuid: "self")
          end
          return
        end
      end

      # Escape or B: close profile if open
      if defined?(MultiplayerUI::ProfilePanel) && MultiplayerUI::ProfilePanel.open?
        back_triggered = Input.trigger?(Input::B) || (defined?(Input::BACK) && Input.trigger?(Input::BACK))
        if back_triggered
          MultiplayerUI::ProfilePanel.close
        end
      end
    rescue => e
      # Silently ignore — non-critical HUD
    end
  end
end

# ---------- Hook Scene_Map update (non-invasive) ----------
if defined?(Scene_Map)
  class ::Scene_Map
    alias kif_profile_f8_update update unless method_defined?(:kif_profile_f8_update)
    def update
      kif_profile_f8_update
      KIFProfileF8Toggle.tick_open_shortcut
      KIFProfileF8Toggle.tick_badge_sync
    end
  end
end

if defined?(PokeBattle_Scene)
  class ::PokeBattle_Scene
    alias kif_profile_f8_pbUpdate pbUpdate unless method_defined?(:kif_profile_f8_pbUpdate)
    def pbUpdate(cw = nil)
      kif_profile_f8_pbUpdate(cw)
      KIFProfileF8Toggle.tick_open_shortcut
      KIFProfileF8Toggle.tick_badge_sync
    end
  end
end
