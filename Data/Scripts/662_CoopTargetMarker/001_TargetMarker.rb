#===============================================================================
# Co-op Ally Target Marker (visual layer)
#===============================================================================
# Loads AFTER EBDX (660) and BossUIHooks (661) so these scene overrides sit on
# top of whatever battle scene is active.
#
# Draws a small pulsing "ALLY" marker with a downward arrow above every foe that
# a co-op teammate has already chosen to attack this round. It refreshes every
# frame during the command / target-selection menus AND during the co-op
# action-sync wait (see 659_Multiplayer/005_Coop/006_ActionSync.rb), so a
# teammate's pick shows up live while you are still deciding -- letting you
# spread damage instead of doubling up.
#
# Pairs with module CoopTargetIntent (659_Multiplayer/005_Coop). Completely
# inert outside of co-op battles, and every drawing path is guarded so a missing
# sprite or attribute can never crash the battle.
#
# IMPORTANT (the bug this revision fixes):
#   The active battle UIs are NOT all the same class. The default EBDX UI uses a
#   SUBCLASS, PokeBattle_SceneEBDX < PokeBattle_Scene, that overrides
#   pbFrameUpdate / pbBeginCommandPhase / pbBeginAttackPhase / pbDisposeSprites
#   WITHOUT calling super. Hooks placed only on the base PokeBattle_Scene are
#   therefore shadowed and never run under EBDX -- which is why the marker never
#   appeared with the default battle UI. We now install the frame/lifecycle
#   wrappers on EVERY concrete scene class that defines its own versions (base
#   PokeBattle_Scene, used by vanilla and the GhostBattle Classic+ mod, AND
#   PokeBattle_SceneEBDX). The drawing implementation lives once on the base and
#   is inherited by the subclass.
#===============================================================================

#-------------------------------------------------------------------------------
# Drawing implementation -- defined once on the base scene, inherited by every
# subclass (PokeBattle_SceneEBDX, etc.).
#-------------------------------------------------------------------------------
class PokeBattle_Scene
  COOP_MARKER_Z = 90000 unless const_defined?(:COOP_MARKER_Z)

  def coop_update_ally_target_markers
    return unless defined?(CoopTargetIntent) && defined?(CoopBattleState)
    @coop_intent_markers ||= {}

    # Only while the local player is actually choosing commands in a co-op battle
    unless CoopBattleState.in_coop_battle? && CoopTargetIntent.active?
      coop_hide_ally_target_markers
      return
    end

    targets = CoopTargetIntent.active_targets(@battle)   # { foe_idx => count }
    if targets.nil? || targets.empty?
      coop_hide_ally_target_markers
      return
    end

    # Gentle pulse so the marker is easy to notice
    @coop_intent_pulse ||= 0
    @coop_intent_pulse += 1
    pulse = 188 + (Math.sin(@coop_intent_pulse * 0.18) * 67).to_i
    pulse = 255 if pulse > 255
    pulse = 120 if pulse < 120

    # Hide markers whose target is no longer flagged
    @coop_intent_markers.each do |idx, spr|
      next unless spr && !spr.disposed?
      spr.visible = false unless targets.key?(idx)
    end

    targets.each_key do |idx|
      poke = (@sprites["pokemon_#{idx}"] rescue nil)
      b    = (@battle.battlers[idx] rescue nil)
      if !poke || (poke.respond_to?(:disposed?) && poke.disposed?) || !b || b.fainted?
        spr = @coop_intent_markers[idx]
        spr.visible = false if spr && !spr.disposed?
        next
      end

      spr = @coop_intent_markers[idx]
      if !spr || spr.disposed?
        spr = coop_build_marker_sprite
        @coop_intent_markers[idx] = spr
      end
      next unless spr

      bw = (spr.bitmap ? spr.bitmap.width : 104)
      px = (poke.x rescue (Graphics.width / 2))
      py = (poke.y rescue (Graphics.height / 2))
      spr.x = px - bw / 2
      spr.y = py - 176          # battler sprites use a bottom origin -> float above
      spr.y = 4 if spr.y < 4
      spr.z = COOP_MARKER_Z
      spr.opacity = pulse
      spr.visible = true
    end
  rescue
    nil
  end

  # Builds the little label+arrow bitmap once per foe slot.
  def coop_build_marker_sprite
    spr = Sprite.new(@viewport)
    w = 104
    h = 46
    bmp = Bitmap.new(w, h)

    boxw = 96
    boxh = 26
    boxx = (w - boxw) / 2
    edge = Color.new(80, 220, 255, 255)
    # translucent backing
    bmp.fill_rect(boxx, 0, boxw, boxh, Color.new(0, 0, 0, 160))
    # bright border
    bmp.fill_rect(boxx, 0, boxw, 2, edge)
    bmp.fill_rect(boxx, boxh - 2, boxw, 2, edge)
    bmp.fill_rect(boxx, 0, 2, boxh, edge)
    bmp.fill_rect(boxx + boxw - 2, 0, 2, boxh, edge)

    # label (use the default battle font; only tweak size/colour to stay safe)
    bmp.font.size = 18 rescue nil
    bmp.font.bold = true rescue nil
    bmp.font.color = Color.new(255, 255, 255, 255)
    label = (_INTL("ALLY") rescue "ALLY")
    bmp.draw_text(boxx, 2, boxw, boxh - 2, label, 1) rescue nil

    # downward-pointing arrow beneath the label
    cx = w / 2
    ay = boxh
    (0...14).each do |row|
      half = 14 - row
      break if half <= 0
      bmp.fill_rect(cx - half, ay + row, half * 2, 1, edge)
    end

    spr.bitmap = bmp
    spr.z = COOP_MARKER_Z
    spr.visible = false
    spr
  rescue
    nil
  end

  def coop_hide_ally_target_markers
    return unless @coop_intent_markers
    @coop_intent_markers.each_value do |spr|
      spr.visible = false if spr && !spr.disposed?
    end
  rescue
    nil
  end

  def coop_dispose_ally_target_markers
    return unless @coop_intent_markers
    @coop_intent_markers.each_value do |spr|
      next unless spr
      spr.bitmap.dispose if spr.bitmap && !spr.bitmap.disposed?
      spr.dispose unless spr.disposed?
    end
    @coop_intent_markers = {}
  rescue
    nil
  end
end

#-------------------------------------------------------------------------------
# Hook installer -- wraps the per-frame + command/attack lifecycle methods on a
# given scene class, chaining onto whatever that class' own version currently
# is. We only wrap a class that DEFINES ITS OWN version of the method (owner ==
# the class), so each concrete scene (base + EBDX subclass) gets a wrapper that
# correctly chains to its real implementation instead of being shadowed.
#-------------------------------------------------------------------------------
module CoopTargetMarkerHooks
  module_function

  def owns?(klass, meth)
    (klass.method_defined?(meth) || klass.private_method_defined?(meth)) &&
      klass.instance_method(meth).owner == klass
  rescue
    false
  end

  def install(klass)
    return unless klass.is_a?(Class)

    # Per-frame: draw/refresh the markers after the scene's normal frame update.
    if owns?(klass, :pbFrameUpdate) &&
       !klass.instance_methods(false).include?(:coop_tgtmarker_pbFrameUpdate)
      klass.send(:alias_method, :coop_tgtmarker_pbFrameUpdate, :pbFrameUpdate)
      klass.send(:define_method, :pbFrameUpdate) do |cw = nil|
        coop_tgtmarker_pbFrameUpdate(cw)
        coop_update_ally_target_markers rescue nil
      end
    end

    # Command phase begin: tell CoopTargetIntent we are now choosing.
    if owns?(klass, :pbBeginCommandPhase) &&
       !klass.instance_methods(false).include?(:coop_tgtmarker_pbBeginCommandPhase)
      klass.send(:alias_method, :coop_tgtmarker_pbBeginCommandPhase, :pbBeginCommandPhase)
      klass.send(:define_method, :pbBeginCommandPhase) do
        coop_tgtmarker_pbBeginCommandPhase
        if defined?(CoopTargetIntent) && defined?(CoopBattleState) && CoopBattleState.in_coop_battle?
          CoopTargetIntent.on_command_phase_begin(@battle) rescue nil
        end
      end
    end

    # Attack phase begin: selection is over -> stop showing/refreshing markers.
    if owns?(klass, :pbBeginAttackPhase) &&
       !klass.instance_methods(false).include?(:coop_tgtmarker_pbBeginAttackPhase)
      klass.send(:alias_method, :coop_tgtmarker_pbBeginAttackPhase, :pbBeginAttackPhase)
      klass.send(:define_method, :pbBeginAttackPhase) do
        coop_tgtmarker_pbBeginAttackPhase
        CoopTargetIntent.on_attack_phase_begin(@battle) rescue nil if defined?(CoopTargetIntent)
        coop_hide_ally_target_markers rescue nil
      end
    end

    # Dispose our extra sprites with the scene.
    if owns?(klass, :pbDisposeSprites) &&
       !klass.instance_methods(false).include?(:coop_tgtmarker_pbDisposeSprites)
      klass.send(:alias_method, :coop_tgtmarker_pbDisposeSprites, :pbDisposeSprites)
      klass.send(:define_method, :pbDisposeSprites) do
        coop_dispose_ally_target_markers rescue nil
        coop_tgtmarker_pbDisposeSprites
      end
    end
  rescue => e
    MultiplayerDebug.warn("COOP-TGT-MARKER", "install failed for #{klass}: #{e.class}: #{e.message}") if defined?(MultiplayerDebug)
  end
end

# Install on every concrete scene class that exists at load time.
#   * PokeBattle_Scene       -> vanilla UI and the GhostBattle Classic+ mod
#   * PokeBattle_SceneEBDX    -> default Elite Battle DX UI (a subclass)
CoopTargetMarkerHooks.install(PokeBattle_Scene) if defined?(PokeBattle_Scene)
CoopTargetMarkerHooks.install(PokeBattle_SceneEBDX) if defined?(PokeBattle_SceneEBDX)

##MultiplayerDebug.info("COOP-TGT-MARKER", "Ally target marker layer loaded") if defined?(MultiplayerDebug)
