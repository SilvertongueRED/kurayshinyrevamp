#===============================================================================
# Co-op Ally Target Marker (visual layer)  -- hardened revision
#===============================================================================
# Loads AFTER EBDX (660) and BossUIHooks (661) so these scene overrides sit on
# top of whatever battle scene is active.
#
# Draws a pulsing "ALLY" marker with a downward arrow over every foe a co-op
# teammate has already chosen to attack this round, so you can spread damage
# instead of doubling up. It refreshes:
#   * every frame during YOUR command / target selection (pbFrameUpdate hook), and
#   * every frame during the co-op action-sync wait (006_ActionSync.rb), where it
#     is called with force=true because that wait is, by definition, the window
#     between your command phase and the attack phase.
#
# WHY EARLIER REVISIONS SHOWED NOTHING (the bugs this revision targets):
#   1. The marker sprites were created on the scene's @viewport. Under the default
#      EBDX UI that viewport shares z=99999 with several others and the marker
#      could end up underneath EBDX layers. We now draw on a DEDICATED viewport at
#      a z above every EBDX layer, so the marker is always on top.
#   2. The action-sync wait can return instantly (ally already submitted), and the
#      refresh there was gated on CoopTargetIntent.active?, which could already be
#      false. The wait now forces a refresh (force=true) that bypasses that gate.
#   3. Positioning assumed a fixed -176px offset and hard-clamped to y=4, which
#      could detach the marker from the foe under EBDX zoom. Positioning is now
#      derived from the sprite's actual height with a gentle clamp.
#
# Pairs with module CoopTargetIntent (659_Multiplayer/005_Coop). Completely inert
# outside co-op battles, and every drawing path is guarded so a missing sprite or
# attribute can never crash the battle.
#===============================================================================

#-------------------------------------------------------------------------------
# Drawing implementation -- defined once on the base scene, inherited by every
# subclass (PokeBattle_SceneEBDX, etc.).
#-------------------------------------------------------------------------------
class PokeBattle_Scene
  COOP_MARKER_VP_Z = 100050 unless const_defined?(:COOP_MARKER_VP_Z)

  # Dedicated viewport that sits above every EBDX UI layer.
  def coop_marker_viewport
    if !@coop_marker_viewport || (@coop_marker_viewport.respond_to?(:disposed?) && @coop_marker_viewport.disposed?)
      @coop_marker_viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @coop_marker_viewport.z = COOP_MARKER_VP_Z
    end
    @coop_marker_viewport
  rescue
    @viewport
  end

  # force=true -> draw even if CoopTargetIntent.active? is false (used by the
  # action-sync wait loop, which is always between command and attack phases).
  def coop_update_ally_target_markers(force = false)
    # DISABLED: the floating over-foe ALLY marker proved unreliable (z-order /
    # EBDX sprite-position dependent -- it drifted to the wrong spot and only
    # showed for one client). Replaced by the fixed top-right Squad Target HUD
    # (002_SquadTargetHUD.rb), which is sprite-independent and symmetric. Kept
    # so existing hooks/dispose calls stay valid; it now only hides.
    coop_hide_ally_target_markers
    return
    return unless defined?(CoopTargetIntent) && defined?(CoopBattleState)
    @coop_intent_markers ||= {}

    unless CoopBattleState.in_coop_battle? && (force || CoopTargetIntent.active?)
      coop_hide_ally_target_markers
      return
    end

    targets = CoopTargetIntent.active_targets(@battle)   # { foe_idx => count }
    if targets.nil? || targets.empty?
      coop_hide_ally_target_markers
      return
    end

    # No need for an ally target marker once a single foe is left -- there is no
    # ambiguity about who to hit.
    begin
      alive_foes = 0
      @battle.battlers.each_with_index do |b, i|
        next unless b && !(b.fainted? rescue true)
        next if (@battle.pbOwnedByPlayer?(i) rescue true)
        alive_foes += 1
      end
      if alive_foes <= 1
        coop_hide_ally_target_markers
        return
      end
    rescue
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
      spr_poke = (@sprites["pokemon_#{idx}"] rescue nil)
      b        = (@battle.battlers[idx] rescue nil)
      # Only the foe being alive matters -- never skip just because the sprite is
      # momentarily missing (EBDX rebuilds battler sprites and they can be nil for
      # a frame). A nil sprite simply triggers the canonical-slot fallback below.
      if !b || (b.fainted? rescue true)
        spr = @coop_intent_markers[idx]
        spr.visible = false if spr && !spr.disposed?
        next
      end
      poke = (spr_poke && !(spr_poke.respond_to?(:disposed?) && spr_poke.disposed?)) ? spr_poke : nil

      spr = @coop_intent_markers[idx]
      if !spr || spr.disposed?
        spr = coop_build_marker_sprite
        @coop_intent_markers[idx] = spr
      end
      next unless spr

      bw = (spr.bitmap ? spr.bitmap.width : 104)

      # Anchor priority: the live battler sprite's screen position (bottom-centre
      # origin). If that's missing or parked at a junk coordinate (0,0 / way
      # off-screen, which happens for a frame or two under EBDX), fall back to the
      # canonical battler slot so the arrow still floats over the right Pokemon.
      px = nil; py = nil; sprite_h = 160
      if poke
        tx = (poke.x rescue nil); ty = (poke.y rescue nil)
        if tx && ty && tx > 0 && ty > 0 && tx < (Graphics.width + 96) && ty < (Graphics.height + 96)
          px = tx; py = ty
          begin
            if poke.respond_to?(:src_rect) && poke.src_rect && poke.src_rect.height > 0
              zy = (poke.respond_to?(:zoom_y) ? (poke.zoom_y || 1.0) : 1.0)
              sprite_h = (poke.src_rect.height * zy).to_i
            elsif poke.bitmap && !poke.bitmap.disposed?
              sprite_h = poke.bitmap.height
            end
          rescue
            sprite_h = 160
          end
        end
      end
      if px.nil? || py.nil?
        begin
          ss = (@battle.sideSizes[idx % 2] rescue 2)
          pos = PokeBattle_SceneConstants.pbBattlerPosition(idx, ss)
          px = pos[0]; py = pos[1]
        rescue
          px = (Graphics.width * 3 / 4); py = (Graphics.height / 3)
        end
      end
      sprite_h = 96 if sprite_h < 96
      sprite_h = 320 if sprite_h > 320

      marker_h = (spr.bitmap ? spr.bitmap.height : 46)
      spr.x = px - bw / 2
      spr.y = py - sprite_h - marker_h + 8
      spr.y = 2 if spr.y < 2
      spr.y = (Graphics.height - marker_h - 2) if spr.y > (Graphics.height - marker_h - 2)
      spr.opacity = pulse
      spr.visible = true

      unless @coop_marker_logged_idx == idx
        @coop_marker_logged_idx = idx
        MultiplayerDebug.info("COOP-TGT", "Marker VISIBLE over foe b#{idx} at (#{spr.x},#{spr.y})") if defined?(MultiplayerDebug)
      end
    end
  rescue => e
    MultiplayerDebug.warn("COOP-TGT", "marker update err: #{e.class}: #{e.message}") if defined?(MultiplayerDebug)
    nil
  end

  # Builds the little label+arrow bitmap once per foe slot.
  def coop_build_marker_sprite
    spr = Sprite.new(coop_marker_viewport)
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
    spr.visible = false
    spr
  rescue
    nil
  end

  def coop_hide_ally_target_markers
    return unless @coop_intent_markers
    @coop_marker_logged_idx = nil
    @coop_intent_markers.each_value do |spr|
      spr.visible = false if spr && !spr.disposed?
    end
  rescue
    nil
  end

  def coop_dispose_ally_target_markers
    if @coop_intent_markers
      @coop_intent_markers.each_value do |spr|
        next unless spr
        spr.bitmap.dispose if spr.bitmap && !spr.bitmap.disposed?
        spr.dispose unless spr.disposed?
      end
      @coop_intent_markers = {}
    end
    if @coop_marker_viewport && !(@coop_marker_viewport.respond_to?(:disposed?) && @coop_marker_viewport.disposed?)
      @coop_marker_viewport.dispose
      @coop_marker_viewport = nil
    end
  rescue
    nil
  end
end

#-------------------------------------------------------------------------------
# Hook installer -- wraps the per-frame + command/attack lifecycle methods on a
# given scene class, chaining onto whatever that class' own version currently is.
# Only wraps a class that DEFINES ITS OWN version (owner == the class), so each
# concrete scene (base + EBDX subclass) gets a wrapper that correctly chains to
# its real implementation instead of being shadowed.
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

    if owns?(klass, :pbFrameUpdate) &&
       !klass.instance_methods(false).include?(:coop_tgtmarker_pbFrameUpdate)
      klass.send(:alias_method, :coop_tgtmarker_pbFrameUpdate, :pbFrameUpdate)
      klass.send(:define_method, :pbFrameUpdate) do |cw = nil|
        coop_tgtmarker_pbFrameUpdate(cw)
        coop_update_ally_target_markers rescue nil
        coop_update_squad_target_hud rescue nil
      end
    end

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

    if owns?(klass, :pbBeginAttackPhase) &&
       !klass.instance_methods(false).include?(:coop_tgtmarker_pbBeginAttackPhase)
      klass.send(:alias_method, :coop_tgtmarker_pbBeginAttackPhase, :pbBeginAttackPhase)
      klass.send(:define_method, :pbBeginAttackPhase) do
        coop_tgtmarker_pbBeginAttackPhase
        CoopTargetIntent.on_attack_phase_begin(@battle) rescue nil if defined?(CoopTargetIntent)
        coop_hide_ally_target_markers rescue nil
        coop_hide_squad_target_hud rescue nil
      end
    end

    if owns?(klass, :pbDisposeSprites) &&
       !klass.instance_methods(false).include?(:coop_tgtmarker_pbDisposeSprites)
      klass.send(:alias_method, :coop_tgtmarker_pbDisposeSprites, :pbDisposeSprites)
      klass.send(:define_method, :pbDisposeSprites) do
        coop_dispose_ally_target_markers rescue nil
        coop_dispose_squad_target_hud rescue nil
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

MultiplayerDebug.info("COOP-TGT-MARKER", "Ally target marker layer loaded (hardened)") if defined?(MultiplayerDebug)
