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
  @local_hover = "" # "battle_id:atk:tgt" the local player is hovering (rides SYNC)

  module_function

  #-----------------------------------------------------------------------------
  # Lifecycle (driven by the scene's command/attack phase hooks)
  #-----------------------------------------------------------------------------
  def on_command_phase_begin(battle)
    @active = true
    @local_hover = ""
    prune_stale(battle)
  end

  def on_attack_phase_begin(_battle)
    @active = false
    @local_hover = ""
  end

  def active?
    @active
  end

  def clear
    @remote_intents = {}
    @local_hover = ""
  end

  def reset
    @remote_intents = {}
    @active = false
    @local_hover = ""
  end

  def current_turn_for(battle)
    (battle.turnCount + 1) rescue 0
  end

  # Drop intents that aren't for the upcoming round anymore.
  def prune_stale(battle)
    return unless battle
    cur = current_turn_for(battle)
    @remote_intents.reject! { |_idx, info| (info[:turn].to_i - cur).abs > 1 }
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

  # Live (tentative) hover broadcast: fired while the player is STILL moving the
  # target cursor, so a teammate sees in real time which foe this Pokemon is
  # aiming at before it is locked in. Same wire format + receiver as broadcast.
  # Only single-target foe moves owned by the local player qualify.
  def broadcast_hover(battle, attacker_idx, hovered_idx, target_data)
    return unless defined?(CoopBattleState) && CoopBattleState.in_coop_battle?
    return if attacker_idx.nil? || hovered_idx.nil? || hovered_idx < 0
    single = true
    begin; single = (target_data.num_targets == 1); rescue; single = true; end
    return unless single
    return unless (battle.pbOwnedByPlayer?(attacker_idx) rescue false)
    return unless (battle.opposes?(attacker_idx, hovered_idx) rescue false)
    set_local_hover(battle, attacker_idx, hovered_idx)
    broadcast(battle, attacker_idx, hovered_idx)
  rescue
    nil
  end

  #-----------------------------------------------------------------------------
  # Receive: an ally chose a target (called from the network handler)
  #-----------------------------------------------------------------------------
  def receive(from_sid, battle_id, turn, attacker_idx, target_idx)
    return false unless defined?(CoopBattleState)

    # Battle context check (ignore intents from a different/old battle)
    cur_id = CoopBattleState.battle_id rescue nil
    return false if cur_id && battle_id && cur_id.to_s != battle_id.to_s

    # Ally filtering is now ADVISORY ONLY. The server only relays COOP_TGT_INTENT
    # to the sender's own squad members (coop_recipients_for), and the battle_id
    # guard above already proves this intent belongs to the current battle. So any
    # intent that reaches us here is, by construction, from a teammate in this
    # exact co-op battle. The previous code hard-dropped intents whose sid format
    # didn't exactly match get_ally_sids -- and because the live COOP_TGT_INTENT
    # path uses the server FROM: sid while the confirmed/action-sync path uses a
    # different sid source, that mismatch silently ate every LIVE hover update
    # (the confirmed marker showed, but it "never updated when the ally moved
    # their cursor", and "one client showed nothing"). We now NEVER drop on a sid
    # mismatch; we only log when the sid isn't recognised, after a fuzzy compare.
    if CoopBattleState.respond_to?(:get_ally_sids)
      allies = (CoopBattleState.get_ally_sids rescue []) || []
      if allies.any?
        _nf = from_sid.to_s.gsub(/\ASID/i, "")
        matched = allies.any? do |s|
          a = s.to_s.gsub(/\ASID/i, "")
          a == _nf || (!a.empty? && !_nf.empty? && (a.include?(_nf) || _nf.include?(a)))
        end
        unless matched
          MultiplayerDebug.warn("COOP-TGT", "intent sid #{from_sid} not in ally list #{allies.inspect} - accepting anyway (battle_id matched)") if defined?(MultiplayerDebug)
        end
      end
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
      next unless (info[:turn].to_i - cur).abs <= 1
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

  # Returns [[attacker_idx, target_idx], ...] for intents valid this round.
  # Used by the fixed Squad Target HUD (662/002_SquadTargetHUD.rb).
  def intent_pairs(battle)
    out = []
    return out unless battle
    cur = current_turn_for(battle)
    @remote_intents.each do |atk, info|
      next unless (info[:turn].to_i - cur).abs <= 1
      t = info[:target]
      next if t.nil? || t < 0
      out << [atk.to_i, t.to_i]
    end
    out
  rescue
    []
  end

  #-----------------------------------------------------------------------------
  # Live hover over SYNC (official-server safe; COOP_TGT_INTENT is dropped there)
  #-----------------------------------------------------------------------------
  def set_local_hover(battle, atk, tgt)
    bid = (CoopBattleState.battle_id rescue nil)
    @local_hover = "#{bid}:#{atk.to_i}:#{tgt.to_i}"
  rescue
    nil
  end

  def local_hover_token
    @local_hover.to_s
  end

  # Pull squad allies live hover tokens out of their relayed SYNC record
  # (@players[sid][:bhov] == "battle_id:atk:tgt") and feed them into the same
  # @remote_intents the Squad Target HUD reads. Called every frame in-battle.
  def ingest_sync_hovers(battle)
    return unless battle && defined?(MultiplayerClient) && defined?(CoopBattleState)
    return unless CoopBattleState.in_coop_battle?
    players = (MultiplayerClient.players rescue nil)
    return unless players.is_a?(Hash)
    bid = (CoopBattleState.battle_id rescue nil)
    cur = current_turn_for(battle)
    allies = (CoopBattleState.get_ally_sids rescue []) || []
    allies.each do |asid|
      pd = players[asid.to_s]
      if pd.nil?
        norm = asid.to_s.gsub(/\ASID/i, "")
        players.each { |k, v| (pd = v; break) if k.to_s.gsub(/\ASID/i, "") == norm } unless norm.empty?
      end
      next unless pd.is_a?(Hash)
      tok = pd[:bhov].to_s
      next if tok.empty?
      parts = tok.split(":")
      next unless parts.length == 3
      b_id, atk, tgt = parts[0], parts[1].to_i, parts[2].to_i
      next if bid && !b_id.to_s.empty? && bid.to_s != b_id.to_s
      next if tgt < 0
      receive(asid.to_s, b_id, cur, atk, tgt)
    end
  rescue
    nil
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
