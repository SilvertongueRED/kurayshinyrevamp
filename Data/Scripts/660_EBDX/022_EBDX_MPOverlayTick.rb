# ===========================================
# File: 022_EBDX_MPOverlayTick.rb
# Purpose: Drive the multiplayer Hotkey HUD + Chat overlay update during EBDX
#          battles.
#
# PokeBattle_SceneEBDX < PokeBattle_Scene overrides pbUpdate WITHOUT calling
# super, so the base-class pbUpdate hooks installed in 659 (HotkeyHUD / ChatUI)
# never fire under the EBDX battle UI. Without a per-frame update during battle
# the overlay just freezes in whatever state it had on the overworld -- which is
# why "HUD On All Screens = Off" failed to dismiss it in EBDX battles, and why
# the Min/Max button could not summon or redraw it mid-battle.
#
# We install the SAME overlay update on the concrete EBDX scene class so battle
# frames refresh visibility (honouring the setting / per-battle override) on
# every battle UI. Base (non-EBDX) battles are already covered by 659's hooks.
# ===========================================

if defined?(PokeBattle_SceneEBDX)
  class PokeBattle_SceneEBDX
    unless method_defined?(:kif_mp_overlay_ebdx_pbUpdate)
      alias kif_mp_overlay_ebdx_pbUpdate pbUpdate
      def pbUpdate(cw = nil)
        kif_mp_overlay_ebdx_pbUpdate(cw)
        MultiplayerUI.update_hotkey_hud if defined?(MultiplayerUI)
        $chat_window.update if $chat_window
      end
    end
  end
end
