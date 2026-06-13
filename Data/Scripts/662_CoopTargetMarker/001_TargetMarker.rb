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
    # RE-ENABLED (user request 2026-06-10): live over-foe ALLY arrow that
    # tracks the squadmate's currently-hovered foe, updated pre-confirm. Fed by
    # CoopTargetIntent (SYNC :bhov piggyback = official-server-safe).
    # User can hide it via Multiplayer Settings -> "Ally Arrow".
    if defined?(CoopTargetIntent) && CoopTargetIntent.respond_to?(:arrow_pref_on?) && !CoopTargetIntent.arrow_pref_on?
      coop_hide_ally_target_markers
      return
    end
    return unless defined?(CoopTargetIntent) && defined?(CoopBattleState)
    @coop_intent_markers ||= {}

    unless CoopBattleState.in_coop_battle? && (force || CoopTargetIntent.active?)
      coop_hide_ally_target_markers
      return
    end

    # Pull each squadmate's live hovered-foe (rides the relayed SYNC :bhov) into
    # @remote_intents every frame BEFORE we read them. Without this call the
    # received hover data sat unread in @players[sid][:bhov] and active_targets was
    # always empty, so the ALLY arrow never appeared. Official-server-safe (no fork
    # server message required -- it piggybacks the SYNC packet the server relays).
    (CoopTargetIntent.ingest_sync_hovers(@battle) rescue nil) if CoopTargetIntent.respond_to?(:ingest_sync_hovers)

    targets = CoopTargetIntent.active_targets(@battle)   # { foe_idx => count }
    if targets.nil? || targets.empty?
      coop_hide_ally_target_markers
      return
    end

    # With a single foe left there is no ambiguity about who to hit, so
    # FOE-side markers are suppressed -- but player-side markers (an ally
    # aiming a support move at themselves / their squadmate) still show.
    alive_foes = 99
    begin
      alive_foes = 0
      @battle.battlers.each_with_index do |b, i|
        next unless b && !(b.fainted? rescue true)
        next if (@battle.pbOwnedByPlayer?(i) rescue true)
        alive_foes += 1
      end
    rescue
      alive_foes = 99
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
      # Suppress foe-side markers when only one foe is alive (no ambiguity);
      # player-side markers always draw.
      is_foe = (@battle.opposes?(idx) rescue ((idx % 2) == 1))
      if is_foe && alive_foes <= 1
        spr = @coop_intent_markers[idx]
        spr.visible = false if spr && !spr.disposed?
        next
      end
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
      # Player-side targets: the tall back sprites push the marker up into the
      # opposing data boxes, so drop it until its top sits just below the
      # lowest opposing health bar (small gap). Foe-targeted markers keep
      # their original position.
      if !is_foe
        floor_y = coop_marker_foe_databox_bottom
        spr.y = floor_y + 6 if floor_y && spr.y < floor_y + 6
      end
      spr.y = (Graphics.height - marker_h - 2) if spr.y > (Graphics.height - marker_h - 2)
      spr.opacity = pulse
      spr.visible = true

      unless @coop_marker_logged_idx == idx
        @coop_marker_logged_idx = idx
        MultiplayerDebug.info("COOP-TGT", "Marker VISIBLE over battler b#{idx} at (#{spr.x},#{spr.y})") if defined?(MultiplayerDebug)
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

  # Bottom screen-edge (y) of the lowest visible OPPOSING data box, or nil if
  # none can be measured. Works for both the vanilla scene's plain databox
  # sprites and EBDX's DataBoxEBDX wrapper (y = top of its "base" sprite).
  def coop_marker_foe_databox_bottom
    bottom = nil
    @battle.battlers.each_with_index do |b, i|
      next unless b
      next unless (@battle.opposes?(i) rescue ((i % 2) == 1))
      box = (@sprites["dataBox_#{i}"] rescue nil)
      next unless box
      next if ((box.respond_to?(:disposed?) && box.disposed?) rescue false)
      next if ((box.respond_to?(:visible) && !box.visible) rescue false)
      by = (box.y rescue nil)
      next unless by.is_a?(Numeric)
      bh = 0
      begin
        if box.respond_to?(:bitmap) && box.bitmap && !box.bitmap.disposed?
          bh = box.bitmap.height.to_i
        end
      rescue
        bh = 0
      end
      if bh <= 0
        begin
          inner = box.instance_variable_get(:@sprites)
          base  = inner.is_a?(Hash) ? inner["base"] : nil
          bh = base.bitmap.height.to_i if base && base.bitmap && !base.bitmap.disposed?
        rescue
          bh = 0
        end
      end
      bh = 60 if bh <= 0 || bh > 200   # sane default / overlay-art guard
      bb = by.to_i + bh
      bottom = bb if bottom.nil? || bb > bottom
    end
    bottom
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
      end
    end

    if owns?(klass, :pbSelectBattler) &&
       !klass.instance_methods(false).include?(:coop_tgtmarker_pbSelectBattler)
      klass.send(:alias_method, :coop_tgtmarker_pbSelectBattler, :pbSelectBattler)
      klass.send(:define_method, :pbSelectBattler) do |idxBattler, selectMode = 1|
        r = coop_tgtmarker_pbSelectBattler(idxBattler, selectMode)
        # Live hover: every target-selection UI (vanilla / EBDX / Mouse UI mod)
        # funnels cursor changes through here with selectMode == 2, so this is
        # the override-proof place to publish which foe we're aiming at.
        if defined?(CoopTargetIntent) && CoopTargetIntent.respond_to?(:on_select_battler)
          begin
            CoopTargetIntent.on_select_battler(@battle, idxBattler, selectMode)
          rescue
          end
        end
        r
      end
    end

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

MultiplayerDebug.info("COOP-TGT-MARKER", "Ally target marker layer loaded (hardened)") if defined?(MultiplayerDebug)
