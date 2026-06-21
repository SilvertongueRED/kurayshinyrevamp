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
# FORK FIX (2026-06-20): the mod's battlegui getter force-coerced a stored 0/nil
#   to 3 (Classic+) and mutated @battlegui, so once the mod was installed the
#   Options "Swap BattleGUI" choice was permanently stuck on Classic+ (even with
#   Ghost + EBDX both off). The PokemonSystem#battlegui getter/setter below now
#   re-gate that on the live Ghost toggle: Ghost ON -> 3, Ghost OFF -> the real
#   stored choice (Off/Type 1/Type 2), and "Classic+" is never recorded as a
#   standalone choice so it can't strand the option across save loads.
#   NOTE: a player who deliberately chose "Type 2" still sees Classic+ type icons
#   while the mod is loaded (the mod treats 2 and 3 alike); that is mod-side.
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
      # The player's genuine Swap-BattleGUI choice (0=Off,1=Type1,2=Type2). 3
      # (Classic+) is the Ghost skin, never a standalone choice, so it is never
      # recorded as "real" -- that is what kept "Off" from sticking before.
      real = (ps.instance_variable_get(:@gvbridge_real_battlegui) rescue nil)
      if real.nil?
        cur = (ps.instance_variable_get(:@battlegui) rescue nil)
        real = (cur.nil? || cur == 3) ? 0 : cur
        ps.instance_variable_set(:@gvbridge_real_battlegui, real)
      end
      # Ghost ON -> 3 so pbGhostUseType2UI? (reads @battlegui directly) renders
      # Classic+. Ghost OFF -> the player's real choice, preserved exactly.
      ps.instance_variable_set(:@battlegui, ghost_active? ? 3 : real)
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
      if v == 3
        # Classic+ is the Ghost skin, not a standalone Swap-BattleGUI choice.
        # Never store it as the player's real pick (otherwise the mod's on_load /
        # scene force would permanently strand "Swap BattleGUI" on Classic+).
        # Only reflect it in the working ivar while Ghost visuals are actually on.
        @battlegui = 3 if GhostVisualsBridge.ghost_active?
        return
      end
      @gvbridge_real_battlegui = v
      @battlegui = v
    end

    # FORK FIX (#3): re-gate the mod's battlegui getter (which force-coerced a
    # stored 0/nil to 3 and mutated @battlegui) so the Options "Swap BattleGUI"
    # choice is honoured again whenever Ghost visuals are off -- including plain
    # vanilla and EBDX. Returns the player's real choice (0/1/2) with NO forcing.
    def battlegui
      return $ghost_force_gui if defined?($ghost_force_gui) && $ghost_force_gui
      return 3 if GhostVisualsBridge.ghost_active?
      real = (@gvbridge_real_battlegui rescue nil)
      real = (@battlegui rescue nil) if real.nil?
      (real.nil? || real == 3) ? 0 : real
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
