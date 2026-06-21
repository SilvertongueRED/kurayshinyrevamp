# =============================================================================
# File: 690_ForkFixes/003_MPHudMenuMinimize.rb
# Purpose: Auto-minimize the multiplayer overlays (hotkey HUD + chat handle)
#          whenever the player opens ANY menu (pause menu, Options, Pokedex,
#          Bag, PC, etc.), and keep them tickable while the menu is open so the
#          minimize/maximize click still works there.
#
# Why this is needed:
#   The hotkey HUD / chat are ticked ONLY from Scene_Map#update, PokeBattle_Scene
#   #pbUpdate and (for message loops) pbUpdateSceneMap. None of those run inside a
#   menu's own loop (PokemonOption_Scene, Pokedex, etc.), so while a menu is open
#   the overlays simply FREEZE on whatever frame they were on:
#     * they don't auto-minimize, and
#     * their own mouse handling never runs, so you can't minimize them by hand.
#
# Fix (self-contained -- no edits to the HUD/chat files):
#   1. Track "a menu is open" via $game_temp.in_menu (set by Scene_Map#call_menu
#      for the whole pause-menu session) PLUS a depth counter around pbFadeOutIn
#      (catches menus opened by a direct field hotkey that bypasses call_menu).
#   2. Edge-triggered on entry: remember the player's current min/max state, then
#      minimize the HUD and collapse the chat handle.
#   3. Edge-triggered on exit: restore exactly what the player had before, without
#      force-opening the chat panel.
#   4. Drive MultiplayerUI.update_hotkey_hud + $chat_window.update from a
#      Input.update hook while a menu is open. Input.update runs every frame in
#      every menu loop and (unlike Graphics.update) is plain Ruby userspace, so
#      recreating the HUD bitmaps from here is safe. This also makes the manual
#      minimize/maximize click work inside menus.
# =============================================================================

if defined?(MultiplayerUI)

  module MultiplayerUI
    # Nesting-safe count of how many pbFadeOutIn-style menu transitions are open.
    def self.menu_overlay_depth
      @menu_overlay_depth ||= 0
    end

    def self.menu_overlay_depth=(v)
      @menu_overlay_depth = [v.to_i, 0].max
    end

    # True whenever the player is inside any menu the overlays should hide for.
    def self.menu_overlay_active?
      return true if menu_overlay_depth > 0
      return true if ($game_temp && $game_temp.in_menu rescue false)
      false
    rescue
      false
    end

    # Edge-triggered minimize-on-enter / restore-on-exit. Cheap to call every
    # frame: it only does work on the transition.
    def self.apply_menu_overlay_state
      return unless multiplayer_connected? || ($hotkey_hud rescue nil)
      active = menu_overlay_active?

      if active && !@menu_overlay_applied
        @menu_overlay_applied = true
        # Remember what the player had so we can put it back on exit.
        @menu_pre_hud_min  = overlays_minimized?
        @menu_pre_chat_min = (defined?(ChatState) ? (ChatState.handle_minimized rescue false) : false)

        hud = ensure_hotkey_hud
        hud.set_minimized(true) if hud && hud.respond_to?(:set_minimized)
        ChatState.handle_minimized = true if defined?(ChatState)

      elsif !active && @menu_overlay_applied
        @menu_overlay_applied = false
        hud = ($hotkey_hud rescue nil)
        if hud && hud.respond_to?(:set_minimized)
          hud.set_minimized(@menu_pre_hud_min ? true : false)
        end
        # Restore the chat handle WITHOUT force-deploying the panel.
        if defined?(ChatState)
          ChatState.handle_minimized = @menu_pre_chat_min ? true : false
        end
      end
    rescue
    end

    # Per-frame driver used while a menu is open (called from Input.update).
    def self.tick_menu_overlays
      apply_menu_overlay_state
      return unless menu_overlay_active?
      update_hotkey_hud if respond_to?(:update_hotkey_hud)
      begin
        $chat_window.update if $chat_window && defined?(ChatWindow)
      rescue
      end
    rescue
    end
  end

  # -- Count pbFadeOutIn-based menus (those that bypass call_menu/in_menu) ------
  if defined?(pbFadeOutIn)
    unless $kif_mp_hud_menumin_fadehook
      $kif_mp_hud_menumin_fadehook = true
      alias _kif_mp_hud_menumin_pbFadeOutIn pbFadeOutIn

      def pbFadeOutIn(z = 99999, nofadeout = false)
        MultiplayerUI.menu_overlay_depth += 1 if defined?(MultiplayerUI)
        begin
          _kif_mp_hud_menumin_pbFadeOutIn(z, nofadeout) { yield if block_given? }
        ensure
          MultiplayerUI.menu_overlay_depth -= 1 if defined?(MultiplayerUI)
        end
      end
    end
  end

  # -- Drive the overlays every frame; they minimize while any menu is open -----
  unless $kif_mp_hud_menumin_inputhook
    $kif_mp_hud_menumin_inputhook = true
    module Input
      class << Input
        alias kif_mp_hud_menumin_update update
      end

      def self.update
        kif_mp_hud_menumin_update
        begin
          MultiplayerUI.tick_menu_overlays if defined?(MultiplayerUI)
        rescue
        end
      end
    end
  end

end
