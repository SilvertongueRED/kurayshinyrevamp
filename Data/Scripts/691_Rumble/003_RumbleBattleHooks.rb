#===============================================================================
# Controller Vibration / Rumble  -  BATTLE HOOKS
#-------------------------------------------------------------------------------
# Fires type-flavoured rumble when:
#   * one of YOUR Pokemon uses a move      (outgoing: wind-up + lighter motif)
#   * one of YOUR Pokemon is hit by a move (incoming: full-strength impact)
#   * a status (non-damaging) move is used BY or ON your Pokemon
#       (its own distinct soft "effect" shimmer, not an impact)
#   * your Pokemon takes indirect damage   (recoil / poison / burn / hazards)
#
# TIMING: the OUTGOING (you attacked) cue now fires the instant the move
# animation BEGINS - i.e. on the attack itself - rather than after the whole
# animation finishes (which made it land late, on the moment of impact).
#
# COVERAGE: the incoming impact is driven from pbHitAndHPLossAnimation, which is
# the canonical move-damage display in BOTH the default UI and EBDX. (The old
# pbDamageAnimation hook missed move damage entirely in the default UI - that
# path only shows indirect damage there - which is why being attacked often
# didn't buzz.) pbDamageAnimation is still hooked, but only for genuine indirect
# damage, and is suppressed while a move-hit animation is already handling it.
#
# Only the human player's own battlers buzz (allies/foes never do), so this is
# co-op / PvP safe and never reacts to the opponent's controller.
#===============================================================================
module Haptics
  module Battle
    @last_type     = :NORMAL
    @in_move_hit   = false   # true while pbHitAndHPLossAnimation is running

    # Pokeball-open cue timing: delay so the buzz lands when the ball actually
    # bursts open (~0.8s into the throw), and fire one cue per ball (staggered).
    BALL_OPEN_DELAY_MS   = 820
    BALL_OPEN_STAGGER_MS = 230

    def self.last_type;     @last_type; end
    def self.last_type=(v); @last_type = (v || :NORMAL); end
    def self.in_move_hit;     @in_move_hit; end
    def self.in_move_hit=(v); @in_move_hit = v; end

    # Owned by the actual human player (not an ally trainer in co-op).
    def self.player_owned?(battler)
      return false unless battler
      return (battler.pbOwnedByPlayer? rescue false)
    end

    # Accepts a move id (symbol/int), a GameData::Move, or a battle move object.
    def self.move_type(move)
      return :NORMAL if move.nil?
      if !move.is_a?(Symbol) && !move.is_a?(Integer) && move.respond_to?(:type)
        t = (move.type rescue nil)
        return t if t
      end
      if defined?(GameData) && GameData.const_defined?(:Move)
        data = (GameData::Move.try_get(move) rescue nil)
        if data
          t = (data.type rescue nil)
          return t || :NORMAL
        end
      end
      return :NORMAL
    end

    # True if the move is a STATUS (non-damaging) move. Works on a move id, a
    # GameData::Move, or a battle move object. Falls back to "damaging" on doubt.
    def self.status_move?(move)
      return false if move.nil?
      # battle move object / GameData::Move
      if !move.is_a?(Symbol) && !move.is_a?(Integer)
        return true  if (move.respond_to?(:statusMove?)   && (move.statusMove?   rescue false))
        return false if (move.respond_to?(:damagingMove?) && (move.damagingMove? rescue false))
        c = (move.category rescue nil)
        return (c == 2) unless c.nil?
      end
      if defined?(GameData) && GameData.const_defined?(:Move)
        data = (GameData::Move.try_get(move) rescue nil)
        c = (data.category rescue nil) if data
        return (c == 2) unless c.nil?
      end
      return false
    end

    # Any of the targets owned by the human player?
    def self.any_player_target?(targets)
      return false unless targets
      list = targets.is_a?(Array) ? targets : [targets]
      list.any? { |t| player_owned?(t) rescue false }
    end

    #---------------------------------------------------------------------------
    # Called the INSTANT a move's animation begins (before it plays out), so the
    # buzz lands on the attack itself.
    #   * You attacked      -> outgoing cue (status shimmer for a status move).
    #   * Foe used a STATUS move on you -> status-incoming cue (damaging foe
    #     moves are handled later, at HP loss, so the hit lands when it connects).
    #---------------------------------------------------------------------------
    def self.on_move_animation(_battle, move, user, targets)
      return unless Haptics.category_on?(:battle)
      type = move_type(move)
      self.last_type = type
      is_status = status_move?(move)

      if player_owned?(user)
        if is_status
          Haptics.play(Haptics::Patterns.status_outgoing(type), :battle, 2)
        else
          Haptics.play(Haptics::Patterns.outgoing(type), :battle, 2)
        end
        return
      end

      # Move used by someone who isn't the player. Only status moves get their
      # cue here (a soft "something was done to me"); damaging moves buzz at the
      # moment of impact via the HP-loss hook below.
      if is_status && any_player_target?(targets)
        Haptics.play(Haptics::Patterns.status_incoming(type), :battle, 2)
      end
    end

    #---------------------------------------------------------------------------
    # Called when a move's damage + HP loss is shown (the real move-hit path in
    # both UIs). Fires the full-strength impact for any of YOUR battlers that got
    # hit, flavoured by the attacker's move type. targets entries are
    # [battler, oldHP, effectiveness].
    #---------------------------------------------------------------------------
    def self.on_hit_and_hp_loss(targets)
      return unless Haptics.category_on?(:battle)
      return unless targets
      hit_player = false
      targets.each do |t|
        b = t.is_a?(Array) ? t[0] : t
        next unless player_owned?(b)
        hit_player = true
        break
      end
      return unless hit_player
      Haptics.play(Haptics::Patterns.incoming(@last_type || :NORMAL), :battle, 2)
    end

    #---------------------------------------------------------------------------
    # Called when a battler plays its standalone damage (flash) animation. With
    # the HP-loss hook now carrying move impacts, this is left to cover INDIRECT
    # damage to your Pokemon (recoil, poison, burn, hazards, weather, item/ability
    # chip). Suppressed while a move-hit animation is already handling it, so the
    # EBDX path (where the hit anim calls this internally) never double-buzzes.
    #---------------------------------------------------------------------------
    #---------------------------------------------------------------------------
    # Called as your side begins sending out battler(s). Fires the gentle
    # "ball opening" expand cue once, but only if one of the balls being thrown
    # is YOUR OWN Pokemon (never a foe's, never a co-op ally's).
    #---------------------------------------------------------------------------
    def self.on_send_out(scene, send_outs)
      return unless Haptics.category_on?(:battle)
      return unless send_outs
      battle = (scene.instance_variable_get(:@battle) rescue nil)
      return unless battle
      mine = send_outs.count do |b|
        idx = b.is_a?(Array) ? b[0] : b
        btlr = (battle.battlers[idx] rescue nil)
        player_owned?(btlr)
      end
      return if mine <= 0
      # One delayed "expand outward & fade" cue per ball, staggered, so doubles
      # /triples give a distinct pop for each Pokemon as its ball opens.
      mine.times do |i|
        Haptics.play_delayed(Haptics::Patterns.ball_open,
          BALL_OPEN_DELAY_MS + i * BALL_OPEN_STAGGER_MS, :battle, 3)
      end
    end

    def self.on_damage(battler, _effectiveness = 0)
      return unless Haptics.category_on?(:battle)
      return if @in_move_hit
      return unless player_owned?(battler)
      Haptics.play(Haptics::Patterns.indirect, :battle, 2)
    end
  end
end

#-------------------------------------------------------------------------------
# Hook: move animation (one class - the battle object).  pbAnimation(move,...)
# delegates to the scene, so wrapping it here covers both the default UI and
# EBDX. Fire the cue BEFORE the (blocking) animation plays so it lands on the
# attack itself instead of at the end / moment of impact.
#-------------------------------------------------------------------------------
if defined?(PokeBattle_Battle)
  class PokeBattle_Battle
    unless method_defined?(:_rumble_orig_pbAnimation)
      alias_method :_rumble_orig_pbAnimation, :pbAnimation
      def pbAnimation(move, user, targets, hitNum = 0)
        Haptics::Battle.on_move_animation(self, move, user, targets) rescue nil
        _rumble_orig_pbAnimation(move, user, targets, hitNum)
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Hook: move damage + HP-loss animation. This is the canonical "got hit by a
# move" display in BOTH the base UI and EBDX (EBDX's version internally calls
# pbDamageAnimation, the base one does not), so it is the reliable place to buzz
# the defender. Installed on every concrete scene class - base AND EBDX - since
# EBDX overrides it without calling super. We also flag @in_move_hit around the
# original so the nested pbDamageAnimation (EBDX) doesn't double-fire.
#-------------------------------------------------------------------------------
_rumble_scene_classes = []
_rumble_scene_classes << PokeBattle_Scene     if defined?(PokeBattle_Scene)
_rumble_scene_classes << PokeBattle_SceneEBDX if defined?(PokeBattle_SceneEBDX)

_rumble_scene_classes.each do |klass|
  klass.class_eval do
    if method_defined?(:pbHitAndHPLossAnimation) && !method_defined?(:_rumble_orig_pbHitAndHPLossAnimation)
      alias_method :_rumble_orig_pbHitAndHPLossAnimation, :pbHitAndHPLossAnimation
      def pbHitAndHPLossAnimation(targets)
        Haptics::Battle.on_hit_and_hp_loss(targets) rescue nil
        prev = Haptics::Battle.in_move_hit
        Haptics::Battle.in_move_hit = true
        begin
          _rumble_orig_pbHitAndHPLossAnimation(targets)
        ensure
          Haptics::Battle.in_move_hit = prev
        end
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Hook: standalone damage (flash) animation - now used for INDIRECT damage only.
# Same per-class install (base + EBDX) as above. Self-suppresses while a move
# hit is in progress (see @in_move_hit), so this only buzzes for non-move damage.
#-------------------------------------------------------------------------------
_rumble_scene_classes.each do |klass|
  klass.class_eval do
    unless method_defined?(:_rumble_orig_pbDamageAnimation)
      alias_method :_rumble_orig_pbDamageAnimation, :pbDamageAnimation
      def pbDamageAnimation(battler, effectiveness = 0)
        Haptics::Battle.on_damage(battler, effectiveness) rescue nil
        _rumble_orig_pbDamageAnimation(battler, effectiveness)
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Hook: send-out animation (your ball opening). pbSendOutBattlers is on every
# concrete scene class (base AND EBDX, which overrides without super), so install
# per-class. We fire the gentle "expand" cue at the start of the send-out, gated
# to the player's own Pokemon inside on_send_out, then run the original anim.
#-------------------------------------------------------------------------------
_rumble_scene_classes.each do |klass|
  klass.class_eval do
    if method_defined?(:pbSendOutBattlers) && !method_defined?(:_rumble_orig_pbSendOutBattlers)
      alias_method :_rumble_orig_pbSendOutBattlers, :pbSendOutBattlers
      def pbSendOutBattlers(sendOuts, startBattle = false)
        Haptics::Battle.on_send_out(self, sendOuts) rescue nil
        _rumble_orig_pbSendOutBattlers(sendOuts, startBattle)
      end
    end
  end
end
