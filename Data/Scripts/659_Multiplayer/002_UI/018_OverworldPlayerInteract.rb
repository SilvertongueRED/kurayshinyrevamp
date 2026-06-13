#===============================================================================
# Overworld Multiplayer Player Interaction
#===============================================================================
# Press the action button (USE / Confirm) while facing another multiplayer
# player's overworld sprite -- exactly like talking to an NPC -- to open the
# same player-actions context menu used by the Player List and Chat:
#   View Profile / Send PM / Invite to Squad / Battle Request / Request Trade /
#   Inspect Party / Teleport to Player.
#
# Implementation notes:
#   * Wraps Game_Player#check_event_trigger_there. With trigger set including 0
#     that method is only reached from update_event_triggering's
#     Input.trigger?(Input::USE) branch, AFTER the engine's own gates (not
#     while an event/interpreter is running, not during miniupdate, and not
#     while an MP UI is blocking overworld input). So we inherit every gate a
#     normal NPC interaction has.
#   * Real map events always win: we only act when no event consumed the press.
#   * Remote players live in MultiplayerClient.players (sid => {:map,:x,:y,...},
#     tile coordinates -- the same data 003_PlayerSprites.rb renders from).
#   * Entirely client-side: no new network messages, official-server-safe.
#===============================================================================

module MPOverworldInteract
  module_function

  # Find a remote player standing on tile (tx, ty) of the current map.
  # Returns [sid, data] or nil.
  def remote_player_at(tx, ty)
    return nil unless defined?(MultiplayerClient)
    return nil unless (MultiplayerClient.instance_variable_get(:@connected) rescue false)
    players = (MultiplayerClient.players rescue nil)
    return nil unless players.is_a?(Hash)
    map_id = ($game_map.map_id rescue nil)
    return nil unless map_id
    players.each do |sid, data|
      next unless data.is_a?(Hash)
      next unless data[:map] && data[:x] && data[:y]
      next unless data[:map].to_i == map_id.to_i
      return [sid.to_s, data] if data[:x].to_i == tx.to_i && data[:y].to_i == ty.to_i
    end
    nil
  rescue
    nil
  end

  # Screen position for a tile (same formula the remote player sprites use),
  # so the menu pops up beside the player rather than in a screen corner.
  def screen_pos_for_tile(tx, ty)
    x_px = tx * 32 + 16 - $game_map.display_x / 4
    y_px = ty * 32 + 32 - $game_map.display_y / 4
    [x_px + 18, y_px - 72]
  rescue
    [Graphics.width / 2, Graphics.height / 2]
  end

  # SID comparison that tolerates the "SID40" vs "40" formats.
  def norm_sid(s)
    s.to_s.upcase.sub(/\ASID/, "")
  end

  # True if `sid` is a fellow member of my current squad.
  def squad_member?(sid)
    return false unless defined?(MultiplayerClient)
    return false unless (MultiplayerClient.in_squad? rescue false)
    squad = (MultiplayerClient.squad rescue nil)
    return false unless squad.is_a?(Hash) && squad[:members].is_a?(Array)
    q = norm_sid(sid)
    return false if q.empty?
    squad[:members].any? { |m| m.is_a?(Hash) && norm_sid(m[:sid]) == q }
  rescue
    false
  end

  # Squadmate interaction: show the SAME action set the Squad window (F4)
  # offers for this member, instead of the generic player-actions menu.
  def interact_squad(sid, name, scx, scy)
    squad     = (MultiplayerClient.squad rescue nil) || {}
    leader    = squad[:leader].to_s
    my_sid    = (MultiplayerClient.session_id.to_s rescue "")
    is_leader = !leader.empty? && norm_sid(leader) == norm_sid(my_sid)

    opts = []; acts = []
    opts << "View Profile";       acts << :profile
    opts << "Send PM";            acts << :pm
    opts << "Battle Request";     acts << :battle
    opts << "Request Trade";      acts << :trade
    opts << "Inspect Party";      acts << :inspect
    opts << "Teleport to Player"; acts << :teleport
    if is_leader
      opts << "Make Leader";      acts << :make_leader
      opts << "Kick from Squad";  acts << :kick
    end
    opts << "Leave Squad";        acts << :leave

    choice = nil
    begin
      choice = MultiplayerUI.player_context_menu(name, scx, scy, nil, opts)
    rescue => e
      MultiplayerDebug.warn("OW-INTERACT", "squad menu err: #{e.class}: #{e.message}") if defined?(MultiplayerDebug)
    end
    return if choice.nil?
    case acts[choice]
    when :make_leader then (MultiplayerClient.transfer_leadership(sid) rescue nil)
    when :kick        then (MultiplayerClient.kick_from_squad(sid) rescue nil)
    when :leave       then (MultiplayerClient.leave_squad rescue nil)
    else
      ctx_map = { :profile => 0, :pm => 1, :battle => 3, :trade => 4, :inspect => 5, :teleport => 6 }
      if ctx_map.key?(acts[choice])
        begin
          Input._execute_ctx_action(ctx_map[acts[choice]], sid, name)
        rescue => e
          MultiplayerDebug.warn("OW-INTERACT", "squad action #{acts[choice]} err: #{e.class}: #{e.message}") if defined?(MultiplayerDebug)
        end
      end
    end
  end

  # Open the player-actions menu for whoever stands on (tx, ty).
  # Returns true if a remote player was there (press consumed).
  def interact(tx, ty)
    found = remote_player_at(tx, ty)
    return false unless found
    sid, data = found
    name = (data[:name].to_s.empty? ? sid : data[:name].to_s)
    return false unless defined?(MultiplayerUI) && MultiplayerUI.respond_to?(:player_context_menu)
    MultiplayerDebug.info("OW-INTERACT", "Facing remote player #{name} (#{sid}) at (#{tx},#{ty}) - opening actions menu") if defined?(MultiplayerDebug)
    scx, scy = screen_pos_for_tile(tx, ty)
    if squad_member?(sid)
      interact_squad(sid, name, scx, scy)
      Input.update rescue nil
      return true
    end
    action = nil
    begin
      action = MultiplayerUI.player_context_menu(name, scx, scy, nil)
    rescue => e
      MultiplayerDebug.warn("OW-INTERACT", "context menu err: #{e.class}: #{e.message}") if defined?(MultiplayerDebug)
      action = nil
    end
    if !action.nil?
      begin
        Input._execute_ctx_action(action, sid, name)
      rescue => e
        MultiplayerDebug.warn("OW-INTERACT", "action #{action} err: #{e.class}: #{e.message}") if defined?(MultiplayerDebug)
      end
    end
    # Eat the closing/confirming press so it doesn't immediately re-trigger an
    # interaction or menu on the very next overworld frame.
    Input.update rescue nil
    true
  rescue
    false
  end
end

class Game_Player
  unless method_defined?(:mp_owinteract_check_event_trigger_there)
    alias mp_owinteract_check_event_trigger_there check_event_trigger_there
  end

  def check_event_trigger_there(triggers)
    result = mp_owinteract_check_event_trigger_there(triggers)
    begin
      # Only the manual action-button path (trigger 0) may open the menu, and
      # only when no real event consumed the press.
      if !result && triggers.is_a?(Array) && triggers.include?(0) &&
         !($game_system.map_interpreter.running? rescue false) &&
         !($game_temp.in_menu rescue false) && !($game_temp.in_battle rescue false)
        new_x = @x + (@direction == 6 ? 1 : @direction == 4 ? -1 : 0)
        new_y = @y + (@direction == 2 ? 1 : @direction == 8 ? -1 : 0)
        result = true if MPOverworldInteract.interact(new_x, new_y)
      end
    rescue
    end
    result
  end
end

MultiplayerDebug.info("OW-INTERACT", "Overworld player interaction loaded") if defined?(MultiplayerDebug)

#===============================================================================
# TEMP INPUT DIAGNOSTIC (safe to delete) -- logs the LOAD FINGERPRINT of this
# build, and on every controller face-button edge which LOGICAL button it fires
# as, so we can see exactly what the PlayStation "Circle" maps to and whether it
# is what opens/confirms the overworld player popup.
#===============================================================================
MultiplayerDebug.info("OW-DIAG", "BUILD v2 loaded: popup-hardening + input diagnostic active") if defined?(MultiplayerDebug)
if defined?(MultiplayerDebug) && !(defined?($ow_input_diag_installed) && $ow_input_diag_installed)
  module Input
    class << self
      alias_method :_owdiag_prev_update, :update
      def update(*a)
        _owdiag_prev_update(*a)
        begin
          names = [["C",Input::C],["B",Input::B],["A",Input::A],
                   ["X",Input::X],["Y",Input::Y],["Z",Input::Z],
                   ["L",Input::L],["R",Input::R]]
          raw = []
          names.each do |nm,b|
            hit = (Input.respond_to?(:_rebind_orig_trigger?) ? (Input._rebind_orig_trigger?(b) rescue false) : false)
            raw << nm if hit
          end
          unless raw.empty?
            tu = (Input.trigger?(Input::USE)  rescue false)
            tb = (Input.trigger?(Input::BACK) rescue false)
            ce = ((defined?(InputDedupe) && InputDedupe.respond_to?(:confirm_edge?)) ? (InputDedupe.confirm_edge? rescue false) : false)
            MultiplayerDebug.info("INPUT-DIAG",
              "raw_edge=[#{raw.join(',')}] USE_trig=#{tu ? 1 : 0} BACK_trig=#{tb ? 1 : 0} confirm_edge=#{ce ? 1 : 0}")
          end
        rescue
        end
      end
    end
  end
  $ow_input_diag_installed = true
end
