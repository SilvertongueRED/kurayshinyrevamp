#===============================================================================
# MODULE 28: Co-op Target Intent (Live Ally Targeting Preview)
#===============================================================================
# Lets co-op allies see, DURING their own command selection, which opposing
# Pokemon their teammate has already chosen to attack -- so they don't waste a
# turn double-targeting the same foe.
#
# How it works:
#   * As soon as the local player confirms a single-target move against a foe
#     (pbChooseTarget below), we broadcast a tiny COOP_TGT_INTENT packet.
#   * Allies store that intent (CoopTargetIntent.receive) and the battle scene
#     draws a floating "ALLY" marker over the chosen foe (see the marker layer in
#     Data/Scripts/662_CoopTargetMarker).
#
# Network message:
#   COOP_TGT_INTENT:<battle_id>|<turn>|<attacker_idx>|<target_idx>
#     turn         = battle.turnCount + 1 (upcoming round, same convention as
#                    CoopActionSync so both clients agree on which round it is)
#     attacker_idx = battler index of the ally's attacking Pokemon
#     target_idx   = battler index of the foe being targeted
#
# Battler indices are identical on every client (the co-op battle is
# deterministic), so a target_idx received from an ally points at the exact same
# on-screen Pokemon locally. Everything here is a safe no-op outside co-op.
#===============================================================================

module CoopTargetIntent
  # { attacker_idx => { :target => Integer, :turn => Integer, :sid => String } }
  @remote_intents = {}
  @active = false   # true only while the local player is choosing commands

  module_function

  #-----------------------------------------------------------------------------
  # Lifecycle (driven by the scene's command/attack phase hooks)
  #-----------------------------------------------------------------------------
  def on_command_phase_begin(battle)
    @active = true
    prune_stale(battle)
  end

  def on_attack_phase_begin(_battle)
    @active = false
  end

  def active?
    @active
  end

  def clear
    @remote_intents = {}
  end

  def reset
    @remote_intents = {}
    @active = false
  end

  def current_turn_for(battle)
    (battle.turnCount + 1) rescue 0
  end

  # Drop intents that aren't for the upcoming round anymore.
  def prune_stale(battle)
    return unless battle
    cur = current_turn_for(battle)
    @remote_intents.reject! { |_idx, info| info[:turn] != cur }
  rescue
    nil
  end

  #-----------------------------------------------------------------------------
  # Broadcast: the local player just chose a target for one of their Pokemon
  #-----------------------------------------------------------------------------
  def broadcast(battle, attacker_idx, target_idx)
    return unless defined?(CoopBattleState) && CoopBattleState.in_coop_battle?
    return unless defined?(MultiplayerClient) && MultiplayerClient.respond_to?(:send_data)
    return if attacker_idx.nil? || target_idx.nil? || target_idx < 0

    battle_id = CoopBattleState.battle_id
    turn      = current_turn_for(battle)
    msg = "COOP_TGT_INTENT:#{battle_id}|#{turn}|#{attacker_idx}|#{target_idx}"
    MultiplayerClient.send_data(msg, rate_limit_type: :ACTION)
    MultiplayerDebug.info("COOP-TGT", "Broadcast intent: u#{attacker_idx} -> b#{target_idx} (turn #{turn})") if defined?(MultiplayerDebug)
  rescue => e
    MultiplayerDebug.warn("COOP-TGT", "broadcast failed: #{e.class}: #{e.message}") if defined?(MultiplayerDebug)
  end

  #-----------------------------------------------------------------------------
  # Receive: an ally chose a target (called from the network handler)
  #-----------------------------------------------------------------------------
  def receive(from_sid, battle_id, turn, attacker_idx, target_idx)
    return false unless defined?(CoopBattleState)

    # Battle context check (ignore intents from a different/old battle)
    cur_id = CoopBattleState.battle_id rescue nil
    return false if cur_id && battle_id && cur_id.to_s != battle_id.to_s

    # Only honour intents from actual allies
    if CoopBattleState.respond_to?(:is_ally?)
      return false unless CoopBattleState.is_ally?(from_sid)
    end

    @remote_intents[attacker_idx.to_i] = {
      :target => target_idx.to_i,
      :turn   => turn.to_i,
      :sid    => from_sid.to_s
    }
    MultiplayerDebug.info("COOP-TGT", "Received intent from #{from_sid}: u#{attacker_idx} -> b#{target_idx} (turn #{turn})") if defined?(MultiplayerDebug)
    true
  rescue => e
    MultiplayerDebug.warn("COOP-TGT", "receive failed: #{e.class}: #{e.message}") if defined?(MultiplayerDebug)
    false
  end

  #-----------------------------------------------------------------------------
  # Query for the marker renderer.
  # Returns { target_idx => count } for intents valid this round.
  #-----------------------------------------------------------------------------
  def active_targets(battle)
    out = {}
    return out unless battle
    cur = current_turn_for(battle)
    @remote_intents.each_value do |info|
      next unless info[:turn] == cur
      t = info[:target]
      next if t.nil? || t < 0
      out[t] ||= 0
      out[t]  += 1
    end
    out
  rescue
    {}
  end

  def any_for_turn?(battle)
    !active_targets(battle).empty?
  end
end

#===============================================================================
# Broadcast hook: fire an intent the moment a foe target is locked in.
#===============================================================================
class PokeBattle_Battle
  unless method_defined?(:coop_tgtintent_pbChooseTarget)
    alias coop_tgtintent_pbChooseTarget pbChooseTarget
  end

  def pbChooseTarget(battler, move)
    ret = coop_tgtintent_pbChooseTarget(battler, move)
    if ret && defined?(CoopBattleState) && CoopBattleState.in_coop_battle? && defined?(CoopTargetIntent)
      begin
        if pbOwnedByPlayer?(battler.index)
          tgt = (@choices[battler.index][3] rescue -1)
          # Only flag single-target moves aimed at a foe -- that's the case where
          # teammates can wastefully pick the same opponent.
          single = true
          begin
            single = (move.pbTarget(battler).num_targets == 1)
          rescue
            single = true
          end
          if tgt && tgt >= 0 && single && opposes?(battler.index, tgt)
            CoopTargetIntent.broadcast(self, battler.index, tgt)
          end
        end
      rescue => e
        MultiplayerDebug.warn("COOP-TGT", "pbChooseTarget hook err: #{e.class}: #{e.message}") if defined?(MultiplayerDebug)
      end
    end
    ret
  end
end

##MultiplayerDebug.info("MODULE-28", "CoopTargetIntent loaded successfully")
