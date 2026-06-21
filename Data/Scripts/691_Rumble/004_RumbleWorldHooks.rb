#===============================================================================
# Controller Vibration / Rumble  -  OVERWORLD & ENCOUNTER HOOKS
#-------------------------------------------------------------------------------
#  * Per-step pulses while walking / running (also faint variants for bike/surf)
#  * Distinct battle-start cues:  wild | alpha | swarm | trainer | gym leader
#===============================================================================
module Haptics
  module Overworld
    def self.on_step
      return unless Haptics.category_on?(:overworld)
      return unless defined?($game_player) && $game_player
      pg  = (defined?($PokemonGlobal) ? $PokemonGlobal : nil)
      spd = ($game_player.move_speed rescue 3)

      if pg && (pg.surfing rescue false)
        Haptics.play(Haptics::Patterns.step_surf, :overworld, 1)
      elsif (pg && (pg.bicycle rescue false)) || (spd && spd >= 5)
        Haptics.play(Haptics::Patterns.step_bike, :overworld, 1)
      elsif spd && spd >= 4
        Haptics.play(Haptics::Patterns.step_run, :overworld, 1)
      else
        Haptics.play(Haptics::Patterns.step_walk, :overworld, 1)
      end
    end
  end

  module Encounter
    def self.same_species?(foes)
      list = foes.map { |p| (p.species rescue nil) }.compact
      return false if list.empty?
      return list.uniq.length == 1
    end

    def self.alpha?(foes)
      foes.any? { |p| p.respond_to?(:alpha?) && (p.alpha? rescue false) }
    end

    def self.gym_leader?(opponents)
      return false unless opponents.is_a?(Array)
      return false unless defined?(is_gym_leader)
      opponents.any? { |t| (is_gym_leader(t) rescue false) }
    end

    def self.on_battle_start(battle)
      return unless Haptics.category_on?(:encounters)
      return unless battle

      if (battle.trainerBattle? rescue false)
        opp = (battle.instance_variable_get(:@opponent) rescue nil)
        if gym_leader?(opp)
          Haptics.play(Haptics::Patterns.encounter_sweep + Haptics::Patterns.gym_leader, :encounters, 3)
        else
          Haptics.play(Haptics::Patterns.encounter_sweep + Haptics::Patterns.trainer, :encounters, 3)
        end
        return
      end

      if (battle.wildBattle? rescue false)
        foes = (battle.instance_variable_get(:@party2) rescue nil)
        foes = [] unless foes.is_a?(Array)
        foes = foes.compact
        if alpha?(foes)
          Haptics.play(Haptics::Patterns.encounter_sweep + Haptics::Patterns.alpha, :encounters, 3)
        elsif foes.length >= 3 || (foes.length == 2 && same_species?(foes))
          Haptics.play(Haptics::Patterns.encounter_sweep + Haptics::Patterns.swarm, :encounters, 3)
        else
          Haptics.play(Haptics::Patterns.encounter_sweep + Haptics::Patterns.wild, :encounters, 3)
        end
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Hook: every overworld step.
#-------------------------------------------------------------------------------
if defined?(Events) && Events.respond_to?(:onStepTaken)
  Events.onStepTaken += proc { Haptics::Overworld.on_step rescue nil }
end

#-------------------------------------------------------------------------------
# Hook: battle start (covers wild + trainer; alpha/swarm/leader classified live).
# Installed late so it wraps whatever pbStartBattle ends up being after all mods.
#-------------------------------------------------------------------------------
if defined?(PokeBattle_Battle)
  class PokeBattle_Battle
    unless method_defined?(:_rumble_orig_pbStartBattle)
      alias_method :_rumble_orig_pbStartBattle, :pbStartBattle
      def pbStartBattle(*args, &blk)
        Haptics::Encounter.on_battle_start(self) rescue nil
        _rumble_orig_pbStartBattle(*args, &blk)
      end
    end
  end
end
