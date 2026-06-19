# =============================================================================
# File: 690_ForkFixes/002_MPOverlayMiniupdate.rb
# Purpose: Keep the multiplayer overlays (chat panel + hotkey HUD) animated
#          and fully interactive during ALL blocking loops — intro event scripts,
#          message display, forced-move sequences, etc.
#
# Root cause of the original bug:
#   pbMessageDisplay (and every other blocking UI loop in the engine) calls
#   Graphics.update + Input.update each frame, so Tab/mouse state-changes fire
#   correctly via global_poll. However those loops do NOT call $chat_window.update
#   or MultiplayerUI.update_hotkey_hud — only the Scene_Map#update alias does.
#   Result: the chat panel and HUD freeze visually and don't respond to
#   Tab/mouse until control returns to the normal Scene_Map main loop (i.e.
#   after the intro is over).
#
# Fix:
#   Hook pbUpdateSceneMap, which is the lightweight per-frame call made from
#   every blocking loop (pbMessageDisplay, pbMessageWaitForInput, etc.).
#   Ticking the overlays here is sufficient and doesn't double-fire in normal
#   gameplay (pbUpdateSceneMap is NOT invoked from the Scene_Map main loop).
# =============================================================================

if defined?(MultiplayerClient)
  unless $kif_mp_overlay_miniupdate_hooked
    $kif_mp_overlay_miniupdate_hooked = true

    alias _kif_mp_overlay_pbUpdateSceneMap_orig pbUpdateSceneMap

    def pbUpdateSceneMap
      _kif_mp_overlay_pbUpdateSceneMap_orig

      # Tick chat window so animation, redraw, and mouse handling all run
      # even when we're inside a blocking message or event-script loop.
      begin
        $chat_window.update if $chat_window && defined?(ChatWindow)
      rescue
      end

      # Tick the hotkey HUD for the same reason.
      begin
        MultiplayerUI.update_hotkey_hud if defined?(MultiplayerUI) &&
                                           MultiplayerUI.respond_to?(:update_hotkey_hud)
      rescue
      end
    end

  end
end
