#==============================================================================
# GhostBattle Classic+  <->  EBDX  runtime compatibility bridge   (fork shim)
#==============================================================================
# WHY THIS FILE EXISTS
#   The "GhostBattle Classic+" mod hard-forces EBDX visuals OFF and forces the
#   battle GUI to "Classic+" the moment it loads:
#       * PokemonSystem#mp_ebdx_enabled  -> always returns 0
#       * EBDXToggle.enabled?            -> always returns false
#       * PokemonSystem#battlegui        -> coerces 0 -> 3 (Classic+) and mutates
#                                           the stored @battlegui ivar
#   Because those are applied at LOAD time, the only way to get EBDX back was to
#   uninstall the mod AND restart the game. Frustrating.
#
# WHAT THIS DOES (without editing the mod itself)
#   This file is a root Mods/*.rb script, so the Dir["./Mods/*.rb"] glob in
#   999_Main.rb loads it AFTER Mods/000_mod_manager_loader.rb has already loaded
#   every sub-folder mod (including GhostBattle Classic+). That means our
#   re-overrides below win over the mod's hard overrides.
#
#   It re-gates the mod's overrides on the player's new
#   "Ghost Battle Visuals" Multiplayer-Options toggle so a player can switch,
#   at runtime with no restart and no uninstall, between:
#       * EBDX visuals              (Ghost OFF, EBDX ON)
#       * GhostBattle Classic+      (Ghost ON  -> EBDX auto-off)
#       * plain vanilla battle UI   (Ghost OFF, EBDX OFF)
#
#   It is completely inert when the GhostBattle Classic+ mod is NOT installed
#   (everything is guarded on `defined?(GhostForceClassicPlus)`), so non-Ghost
#   players are unaffected and EBDX keeps working exactly as before.
#
# KNOWN LIMITATION (engine/mod design, not fixable from the fork side)
#   The mod reads the raw @battlegui ivar directly (pbGhostUseType2UI?) and
#   force-converts value 0, so while the mod is installed the literal "Off /
#   default(0)" battle GUI cannot be represented -- "both visuals off" therefore
#   renders as the clean Type-1 vanilla bars. A player who deliberately chose
#   "Type 2" still sees the Classic+ type icons (the mod treats 2 and 3 alike).
#   Removing those two caveats would require a one-line change to the mod.
#==============================================================================

if defined?(GhostForceClassicPlus) && defined?(GhostVisualsBridge)

  module GhostVisualsBridge
    # Normalise the stored @battlegui for the upcoming battle based on the
    # active visual mode. Called from pbNewBattleScene, i.e. BEFORE the mod's
    # GhostForceClassicPlus#pbStartScene force runs, so the value we set sticks.
    #   * Ghost ON  -> 3 (Classic+), so the mod renders its UI.
    #   * Ghost OFF -> the player's real choice, coerced away from {0, nil, 3}
    #                  to 1 so (a) the mod's "0 -> Classic+" force never triggers
    #                  and (b) pbGhostUseType2UI? (which reads the ivar directly)
    #                  reports false -> no Classic+ styling leaks into vanilla/EBDX.
    def self.apply_battlegui!
      ps = $PokemonSystem
      return unless ps
      cur = (ps.instance_variable_get(:@battlegui) rescue nil)
      # First-time capture of the player's genuine pre-Ghost battle-GUI choice.
      if (ps.instance_variable_get(:@gvbridge_real_battlegui) rescue nil).nil?
        real = cur
        real = 1 if real.nil? || real == 0 || real == 3
        ps.instance_variable_set(:@gvbridge_real_battlegui, real)
      end
      if ghost_active?
        ps.instance_variable_set(:@battlegui, 3)
      else
        real = (ps.instance_variable_get(:@gvbridge_real_battlegui) rescue nil)
        real = 1 if real.nil? || real == 0 || real == 3
        ps.instance_variable_set(:@battlegui, real)
      end
    rescue
      nil
    end
  end

  #----------------------------------------------------------------------------
  # PokemonSystem: undo the mod's hard overrides, gate them on the new toggle.
  #----------------------------------------------------------------------------
  class PokemonSystem
    # EFFECTIVE EBDX flag: 0 while Ghost visuals are active, otherwise the raw
    # stored value (default ON). This both drives EBDXToggle.enabled? and makes
    # the mod's own internal `mp_ebdx_enabled == 1` guards behave correctly.
    def mp_ebdx_enabled
      return 0 if GhostVisualsBridge.ghost_active?
      raw = (@mp_ebdx_enabled rescue nil)
      raw.nil? ? 1 : raw
    end

    # Remember the player's genuine battle-GUI choice so Ghost OFF can restore it.
    if method_defined?(:battlegui=)
      alias gvbridge_orig_battlegui_set battlegui= unless method_defined?(:gvbridge_orig_battlegui_set)
    end
    def battlegui=(v)
      @gvbridge_real_battlegui = v
      @battlegui = v
    end
  end

  #----------------------------------------------------------------------------
  # EBDXToggle: respect the EBDX toggle again whenever Ghost visuals are off.
  #----------------------------------------------------------------------------
  module EBDXToggle
    def self.enabled?
      return false if GhostVisualsBridge.ghost_active?
      return $PokemonSystem && $PokemonSystem.mp_ebdx_enabled == 1
    end
  end

  #----------------------------------------------------------------------------
  # Battle scene factory: normalise @battlegui right before the scene is built.
  #----------------------------------------------------------------------------
  alias gvbridge_pre_pbNewBattleScene pbNewBattleScene unless defined?(gvbridge_pre_pbNewBattleScene)
  def pbNewBattleScene
    GhostVisualsBridge.apply_battlegui! rescue nil
    gvbridge_pre_pbNewBattleScene
  end

  #----------------------------------------------------------------------------
  # Suppress the mod's active-battler highlight / tone shuffle when Ghost
  # visuals are off, so it never bleeds into EBDX or the plain vanilla UI.
  #----------------------------------------------------------------------------
  class PokeBattle_Scene
    if method_defined?(:pbRefreshBattlerTones)
      alias gvbridge_mod_pbRefreshBattlerTones pbRefreshBattlerTones unless method_defined?(:gvbridge_mod_pbRefreshBattlerTones)
      def pbRefreshBattlerTones(*args)
        return unless GhostVisualsBridge.ghost_active?
        gvbridge_mod_pbRefreshBattlerTones(*args)
      end
    end
  end

  #----------------------------------------------------------------------------
  # Co-op ally target marker: make sure our over-foe "ALLY" arrow + Squad Target
  # HUD hooks are installed on the scene classes the mod actually uses. The
  # installer is idempotent (guards on its own alias names), so this is a safe
  # belt-and-braces re-install in case the mod redefined a hooked method after
  # 662_CoopTargetMarker first installed. The marker draws on its own viewport
  # at z=100050, far above the mod's battler/glow sprites (z <= 80), so it is
  # never occluded by Classic+ layering.
  #----------------------------------------------------------------------------
  if defined?(CoopTargetMarkerHooks)
    CoopTargetMarkerHooks.install(PokeBattle_Scene) if defined?(PokeBattle_Scene)
    CoopTargetMarkerHooks.install(PokeBattle_SceneEBDX) if defined?(PokeBattle_SceneEBDX)
  end

  (MultiplayerDebug.info("GHOST-EBDX", "Runtime EBDX<->GhostBattle bridge active (ghost_active=#{GhostVisualsBridge.ghost_active?})") rescue nil) if defined?(MultiplayerDebug)

end
