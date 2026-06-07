#===============================================================================
# Co-op Squad Target HUD  (fixed-position, low-dependency)
#===============================================================================
# A reliable companion to the over-foe "ALLY" marker (001_TargetMarker.rb).
#
# WHY THIS EXISTS:
#   The floating marker draws ON TOP of each foe's battler sprite, so it depends
#   on exact sprite positions and on sitting above whatever battle UI is active
#   (EBDX layers, zoom, etc.). Those dependencies have repeatedly made it show
#   nothing. This HUD instead draws a small FIXED panel in the top-left corner
#   that simply lists, in plain text, which squad Pokemon is aiming at which foe
#   this round -- "Pikachu  >  Rattata". No sprite alignment, no z-order race,
#   so it works under every battle UI including a missing-art EBDX fallback.
#
# DATA SOURCES (any one is enough; they reinforce each other):
#   * Your own locked choices       (@battle.choices for player-owned battlers)
#   * Your ally's live target intent (CoopTargetIntent, broadcast on confirm)
#   * Your ally's synced action      (006_ActionSync feeds CoopTargetIntent too)
#
# If two squad members aim at the SAME foe the line turns red and is tagged
# "x2" so you can spread damage without voice chat. Completely inert outside a
# co-op battle and every path is guarded so it can never crash the battle.
#===============================================================================

class PokeBattle_Scene
  COOP_HUD_VP_Z = 100049 unless const_defined?(:COOP_HUD_VP_Z)

  def coop_hud_viewport
    if !@coop_hud_viewport || (@coop_hud_viewport.respond_to?(:disposed?) && @coop_hud_viewport.disposed?)
      @coop_hud_viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @coop_hud_viewport.z = COOP_HUD_VP_Z
    end
    @coop_hud_viewport
  rescue
    @viewport
  end

  # Collect attacker_idx => target_idx for the upcoming round, merging the local
  # player's locked choices with the ally's broadcast/synced intent.
  def coop_collect_target_pairs
    pairs = {}

    if defined?(CoopTargetIntent) && CoopTargetIntent.respond_to?(:intent_pairs)
      (CoopTargetIntent.intent_pairs(@battle) rescue []).each do |atk, tgt|
        pairs[atk.to_i] = tgt.to_i if atk && tgt && tgt.to_i >= 0
      end
    end

    begin
      choices = (@battle.choices rescue nil)
      if choices
        @battle.battlers.each_with_index do |b, idx|
          next unless b
          next unless (@battle.pbOwnedByPlayer?(idx) rescue false)
          ch = choices[idx]
          next unless ch.is_a?(Array) && ch[0] == :UseMove
          tgt = ch[3]
          next if tgt.nil? || tgt.to_i < 0
          next unless (@battle.opposes?(idx, tgt.to_i) rescue false)
          pairs[idx] = tgt.to_i
        end
      end
    rescue
    end

    pairs
  rescue
    {}
  end

  def coop_battler_label(idx)
    b = (@battle.battlers[idx] rescue nil)
    return "?" unless b
    n = (b.name rescue nil)
    (n && !n.to_s.empty?) ? n.to_s : "?"
  rescue
    "?"
  end

  def coop_update_squad_target_hud
    # DISABLED: replaced by the live over-foe ALLY marker (001_TargetMarker.rb),
    # which now tracks a teammate's hovered target in real time during target
    # selection. The fixed top-left list blocked the foe HP boxes, so it is off.
    coop_hide_squad_target_hud
    return
    return unless defined?(CoopBattleState) && CoopBattleState.respond_to?(:in_coop_battle?)
    unless CoopBattleState.in_coop_battle?
      coop_hide_squad_target_hud
      return
    end

    pairs = coop_collect_target_pairs
    if pairs.nil? || pairs.empty?
      coop_hide_squad_target_hud
      return
    end

    tgt_counts = Hash.new(0)
    pairs.each_value { |t| tgt_counts[t] += 1 }

    sig = pairs.sort.map { |a, t| "#{a}>#{t}" }.join(",")
    return if sig == @coop_hud_sig && @coop_hud_sprite && !@coop_hud_sprite.disposed?
    @coop_hud_sig = sig

    rows = pairs.sort.map do |atk, tgt|
      dup = tgt_counts[tgt] > 1
      { :text => "#{coop_battler_label(atk)}  >  #{coop_battler_label(tgt)}#{dup ? "  x#{tgt_counts[tgt]}" : ""}",
        :dup  => dup }
    end

    coop_render_squad_target_hud(rows)
  rescue => e
    MultiplayerDebug.warn("COOP-HUD", "hud update err: #{e.class}: #{e.message}") if defined?(MultiplayerDebug)
    nil
  end

  def coop_render_squad_target_hud(rows)
    title = (_INTL("SQUAD TARGETS") rescue "SQUAD TARGETS")
    pad   = 8
    lh    = 22
    w     = 240
    h     = pad * 2 + lh + rows.length * lh

    spr = @coop_hud_sprite
    if !spr || spr.disposed?
      spr = Sprite.new(coop_hud_viewport)
      spr.x = 6
      spr.y = 6
      @coop_hud_sprite = spr
    end
    spr.bitmap.dispose if spr.bitmap && !spr.bitmap.disposed?
    bmp = Bitmap.new(w, h)
    edge = Color.new(80, 220, 255, 255)
    bmp.fill_rect(0, 0, w, h, Color.new(0, 0, 0, 170))
    bmp.fill_rect(0, 0, w, 2, edge)
    bmp.fill_rect(0, h - 2, w, 2, edge)
    bmp.fill_rect(0, 0, 2, h, edge)
    bmp.fill_rect(w - 2, 0, 2, h, edge)

    bmp.font.size = 16 rescue nil
    bmp.font.bold = true rescue nil
    bmp.font.color = Color.new(120, 230, 255, 255)
    bmp.draw_text(pad, pad - 2, w - pad * 2, lh, title, 0) rescue nil

    rows.each_with_index do |row, i|
      bmp.font.color = row[:dup] ? Color.new(255, 110, 110, 255) : Color.new(255, 255, 255, 255)
      bmp.draw_text(pad, pad - 2 + lh * (i + 1), w - pad * 2, lh, row[:text], 0) rescue nil
    end

    spr.bitmap = bmp
    spr.visible = true
  rescue => e
    MultiplayerDebug.warn("COOP-HUD", "hud render err: #{e.class}: #{e.message}") if defined?(MultiplayerDebug)
    nil
  end

  def coop_hide_squad_target_hud
    @coop_hud_sig = nil
    @coop_hud_sprite.visible = false if @coop_hud_sprite && !@coop_hud_sprite.disposed?
  rescue
    nil
  end

  def coop_dispose_squad_target_hud
    if @coop_hud_sprite
      @coop_hud_sprite.bitmap.dispose if @coop_hud_sprite.bitmap && !@coop_hud_sprite.bitmap.disposed?
      @coop_hud_sprite.dispose unless @coop_hud_sprite.disposed?
      @coop_hud_sprite = nil
    end
    if @coop_hud_viewport && !(@coop_hud_viewport.respond_to?(:disposed?) && @coop_hud_viewport.disposed?)
      @coop_hud_viewport.dispose
      @coop_hud_viewport = nil
    end
    @coop_hud_sig = nil
  rescue
    nil
  end
end

MultiplayerDebug.info("COOP-HUD", "Squad target HUD loaded") if defined?(MultiplayerDebug)
