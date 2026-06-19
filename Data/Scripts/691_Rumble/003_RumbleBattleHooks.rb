#===============================================================================
# Controller Vibration / Rumble  -  BATTLE HOOKS
#-------------------------------------------------------------------------------
# Fires type-flavoured rumble when:
#   * one of YOUR Pokemon uses a move      (outgoing: wind-up + lighter motif)
#   * one of YOUR Pokemon is hit by a move (incoming: full-strength impact)
#
# The move's TYPE is captured at animation time and reused at the damage moment,
# so the impact that lands on your Pokemon carries the attacker's type flavour.
# Only the human player's own battlers buzz (allies/foes never do), so this is
# co-op / PvP safe and never reacts to the opponent's controller.
#===============================================================================
module Haptics
  module Battle
    @last_type = :NORMAL

    def self.last_type;     @last_type; end
    def self.last_type=(v); @last_type = (v || :NORMAL); end

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

    # Called after a move's animation begins playing.
    def self.on_move_animation(_battle, move, user, _targets)
      return unless Haptics.category_on?(:battle)
      type = move_type(move)
      self.last_type = type
      if player_owned?(user)
        Haptics.play(Haptics::Patterns.outgoing(type), :battle, 2)
      end
    end

    # Called when a battler plays its damage (flash) animation.
    def self.on_damage(battler, _effectiveness = 0)
      return unless Haptics.category_on?(:battle)
      return unless player_owned?(battler)
      Haptics.play(Haptics::Patterns.incoming(@last_type || :NORMAL), :battle, 2)
    end
  end
end

#-------------------------------------------------------------------------------
# Hook: move animation (one class - the battle object).  pbAnimation(move,...)
# delegates to the scene, so wrapping it here covers both the default UI and EBDX.
#-------------------------------------------------------------------------------
if defined?(PokeBattle_Battle)
  class PokeBattle_Battle
    unless method_defined?(:_rumble_orig_pbAnimation)
      alias_method :_rumble_orig_pbAnimation, :pbAnimation
      def pbAnimation(move, user, targets, hitNum = 0)
        _rumble_orig_pbAnimation(move, user, targets, hitNum)
        Haptics::Battle.on_move_animation(self, move, user, targets) rescue nil
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Hook: damage animation. The EBDX scene is a subclass that OVERRIDES
# pbDamageAnimation without calling super, so the alias must be installed on
# every concrete scene class - base AND EBDX - or it is silently dead under the
# default (EBDX) UI.
#-------------------------------------------------------------------------------
_rumble_scene_classes = []
_rumble_scene_classes << PokeBattle_Scene     if defined?(PokeBattle_Scene)
_rumble_scene_classes << PokeBattle_SceneEBDX if defined?(PokeBattle_SceneEBDX)
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
