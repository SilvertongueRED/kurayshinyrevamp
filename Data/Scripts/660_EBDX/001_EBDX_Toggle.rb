#===============================================================================
#  EBDX Toggle System for KIF Multiplayer
#===============================================================================
#  Adds a per-player toggle to switch between EBDX enhanced battles and
#  vanilla KIF battles. This is purely local - multiplayer sync is unaffected.
#===============================================================================

class PokemonSystem
  attr_accessor :mp_ebdx_enabled  # 0 = off (vanilla), 1 = on (EBDX visuals)

  alias ebdx_toggle_original_initialize initialize unless method_defined?(:ebdx_toggle_original_initialize)
  def initialize
    ebdx_toggle_original_initialize
    @mp_ebdx_enabled = 1  # On by default for EBDX visuals
  end
end

#===============================================================================
#  Global toggle check module
#===============================================================================
module EBDXToggle
  def self.enabled?
    return $PokemonSystem && $PokemonSystem.mp_ebdx_enabled == 1
  end

  # ---------------------------------------------------------------------------
  #  Asset availability probe.
  #  EBDX's battle UI needs its art under Graphics/EBDX/Pictures/. If that art
  #  is missing on this install, pbBitmap returns 1x1 placeholders and the
  #  battle scene crashes (BagWindowEBDX -> Bitmap.new(w, height/4 == 0):
  #  "failed to create bitmap"). When the art is absent we report false here so
  #  pbNewBattleScene transparently falls back to the working vanilla battle UI.
  #  This is purely local rendering: multiplayer sync/compat is unaffected, and
  #  any player who DOES have the EBDX art keeps full EBDX automatically. Drop
  #  the art back into Graphics/EBDX/Pictures/ and EBDX re-enables itself.
  # ---------------------------------------------------------------------------
  @assets_available = nil
  def self.assets_available?
    return @assets_available unless @assets_available.nil?
    required = [
      "Graphics/EBDX/Pictures/UI/skin1",          # battle command-window skin (scene init, very first thing drawn)
      "Graphics/EBDX/Pictures/UI/btnCmd",
      "Graphics/EBDX/Pictures/UI/partyBar",       # HP / party bars
      "Graphics/EBDX/Pictures/UI/moveSelButtons",
      "Graphics/EBDX/Pictures/Bag/itemContainer",
      "Graphics/EBDX/Pictures/Bag/pocketIcons"
    ]
    @assets_available = true
    begin
      required.each do |path|
        if (pbResolveBitmap(path) rescue nil).nil?
          @assets_available = false
          break
        end
      end
    rescue
      @assets_available = false
    end
    if !@assets_available && !$ebdx_assets_warned
      $ebdx_assets_warned = true
      msg = "[EBDX] Battle UI art is missing (Graphics/EBDX/Pictures/ has no UI/ or Bag/ files - only Battlers/ is present here), so EVERY battle (single-player AND multiplayer) falls back to the standard UI. This is NOT a multiplayer setting: EBDX renders locally the instant the art exists, regardless of an opponent's/squadmate's UI choice. Drop the EBDX 'Pictures' art pack into Graphics/EBDX/Pictures/ to enable EBDX visuals."
      (MultiplayerDebug.info("EBDX", msg) rescue nil) if defined?(MultiplayerDebug)
      p msg if $DEBUG
    end
    return @assets_available
  end

  def self.reset_asset_cache
    @assets_available = nil
  end
end
