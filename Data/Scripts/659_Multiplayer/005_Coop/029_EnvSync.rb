#===============================================================================
# MODULE 29: Co-op Environment Sync (time-of-day + weather on squad join)
#===============================================================================
# When you JOIN someone's squad, your in-game time-of-day and overworld weather
# are aligned to the squad LEADER's, so co-op partners share the same day/night
# lighting and weather instead of each running on their own system clock.
#
#   * Time-of-day in KIF is derived purely from pbGetTimeNow (== Time.now). We
#     keep a signed offset (leader_clock - my_clock) and add it inside an aliased
#     pbGetTimeNow, so every day/night calc follows the leader's clock. Because
#     both clocks tick at the same rate, the alignment holds for the whole
#     session (not just the instant of joining).
#   * Weather is re-applied via $game_screen.weather(type, power, duration).
#
# Wire protocol (relayed by the server to squad members, like COOP_TGT_INTENT):
#   SQUAD_ENV_REQ:                      joiner asks the squad for the leader's env
#   SQUAD_ENV:<epoch_f>|<wtype>|<wpow>  leader's current clock + weather
#
# Everything is guarded and a no-op when solo / not connected.
#===============================================================================

module MPEnvSync
  @time_offset = 0.0     # seconds to add to Time.now to match the squad leader
  @time_active = false
  @last_request_at = nil
  @pending_weather = nil # [type_str, power] queued on the NET thread, applied on main
  @env_mutex = Mutex.new

  module_function

  def time_offset; @time_offset; end
  def time_active?; @time_active; end

  def set_time_from_leader(leader_epoch)
    le = leader_epoch.to_f
    return if le <= 0
    @time_offset = le - Time.now.to_f
    @time_active = true
    # Invalidate PBDayNight's tone cache so the day/night tint recomputes on the
    # next frame instead of lagging up to 30s behind the adopted clock. Only
    # nils a timestamp (no graphics calls), so it is safe off the main thread.
    begin
      PBDayNight.instance_variable_set(:@dayNightToneLastUpdate, nil) if defined?(PBDayNight)
    rescue
    end
    MultiplayerDebug.info("MP-ENV", "Time synced to leader (offset=#{@time_offset.round(1)}s)") if defined?(MultiplayerDebug)
  rescue
    nil
  end

  def clear
    @time_offset = 0.0
    @time_active = false
  end

  # --- weather helpers --------------------------------------------------------
  def current_weather_payload
    return ["None", 0] unless defined?($game_screen) && $game_screen
    t = ($game_screen.weather_type rescue 0)
    ts = (t.nil? || t == 0 || t == :None) ? "None" : t.to_s
    p  = ($game_screen.weather_power rescue 0).to_i
    [ts, p]
  rescue
    ["None", 0]
  end

  def apply_weather(type_str, power)
    return unless defined?($game_screen) && $game_screen
    ts = type_str.to_s
    sym = (ts.empty? || ts == "0" || ts.downcase == "none") ? :None : ts.to_sym
    begin
      if defined?(GameData) && defined?(GameData::Weather)
        sym = :None unless (GameData::Weather.exists?(sym) rescue true)
      end
    rescue
      sym = :None
    end
    # duration in 1/20s ticks; ~40 = a gentle 2s fade-in
    $game_screen.weather(sym, power.to_i, 40)
    MultiplayerDebug.info("MP-ENV", "Weather synced to leader: #{sym} pow=#{power}") if defined?(MultiplayerDebug)
  rescue => e
    MultiplayerDebug.warn("MP-ENV", "apply_weather err: #{e.class}: #{e.message}") if defined?(MultiplayerDebug)
  end

  # --- senders ----------------------------------------------------------------
  # Called by a joiner right after they join a squad they do NOT lead.
  def request_env
    return unless defined?(MultiplayerClient) && MultiplayerClient.respond_to?(:send_data)
    return unless (MultiplayerClient.in_squad? rescue false)
    return if (MultiplayerClient.is_leader? rescue false)
    # debounce so a flurry of SQUAD_STATE packets doesn't spam requests
    now = Time.now.to_f
    return if @last_request_at && (now - @last_request_at) < 2.0
    @last_request_at = now
    MultiplayerClient.send_data("SQUAD_ENV_REQ:", rate_limit_type: :GENERAL)
    MultiplayerDebug.info("MP-ENV", "Requested env from squad leader") if defined?(MultiplayerDebug)
  rescue
    nil
  end

  # Called by the squad LEADER when asked (or when a member joins): broadcast our
  # current clock + weather to the squad.
  def broadcast_env
    return unless defined?(MultiplayerClient) && MultiplayerClient.respond_to?(:send_data)
    return unless (MultiplayerClient.in_squad? rescue false)
    return unless (MultiplayerClient.is_leader? rescue false)
    epoch = (pbGetTimeNow.to_f rescue Time.now.to_f)
    wtype, wpow = current_weather_payload
    MultiplayerClient.send_data("SQUAD_ENV:#{epoch}|#{wtype}|#{wpow}", rate_limit_type: :GENERAL)
    MultiplayerDebug.info("MP-ENV", "Leader broadcast env (#{wtype}/#{wpow})") if defined?(MultiplayerDebug)
  rescue
    nil
  end

  # --- receivers (called from 003_Client.rb dispatch) -------------------------
  def on_env_request(from_sid)
    # Only the leader answers; relays to the whole squad which is harmless.
    broadcast_env if (MultiplayerClient.is_leader? rescue false)
  rescue
    nil
  end

  def on_env_received(from_sid, epoch, wtype, wpow)
    # Only adopt env from the LEADER, and never override our own if we ARE leader.
    return if (MultiplayerClient.is_leader? rescue false)
    leader = (MultiplayerClient.squad[:leader].to_s rescue nil)
    if leader && !leader.empty?
      a = leader.gsub(/\ASID/i, "")
      b = from_sid.to_s.gsub(/\ASID/i, "")
      unless a == b || (!a.empty? && !b.empty? && (a.include?(b) || b.include?(a)))
        MultiplayerDebug.info("MP-ENV", "Ignoring env from non-leader #{from_sid}") if defined?(MultiplayerDebug)
        return
      end
    end
    set_time_from_leader(epoch)
    # Weather touches $game_screen (graphics); never do that on the NET reader
    # thread. Queue it and let the main-thread pump (Scene_Map#update) apply it.
    set_pending_weather(wtype, wpow)
  rescue
    nil
  end

  # Thread-safe handoff of the desired weather to the main thread.
  def set_pending_weather(type_str, power)
    @env_mutex.synchronize { @pending_weather = [type_str.to_s, power.to_i] }
  rescue
    nil
  end

  # Called every frame on the MAIN thread (from Scene_Map#update). Applies any
  # weather that arrived over the network, safely on the render thread.
  def pump
    # PRIMARY path on the official server: pull the leader env that rode in on
    # their SYNC packet (see local_trainer_snapshot piggyback). The SQUAD_ENV
    # request/response below it still works on a self-hosted server.
    poll_leader_env_from_sync
    w = nil
    @env_mutex.synchronize { w = @pending_weather; @pending_weather = nil }
    apply_weather(w[0], w[1]) if w
  rescue
    nil
  end

  # Adopt the squad leader's time-of-day + weather from the leader-stamped keys
  # (:tod/:wx/:wpow) that arrive inside their relayed SYNC. Throttled ~1/s;
  # weather only re-applied on change. No fork-only server message required.
  def poll_leader_env_from_sync
    return unless defined?(MultiplayerClient)
    return unless (MultiplayerClient.in_squad? rescue false)
    return if (MultiplayerClient.is_leader? rescue false)
    now = Time.now.to_f
    return if @last_sync_poll && (now - @last_sync_poll) < 1.0
    @last_sync_poll = now
    leader = (MultiplayerClient.squad[:leader].to_s rescue nil)
    return if leader.nil? || leader.empty?
    players = (MultiplayerClient.players rescue nil)
    return unless players.is_a?(Hash)
    pd = players[leader]
    if pd.nil?
      norm = leader.gsub(/\ASID/i, "")
      unless norm.empty?
        players.each { |k, v| (pd = v; break) if k.to_s.gsub(/\ASID/i, "") == norm }
      end
    end
    return unless pd.is_a?(Hash)
    tod = pd[:tod]
    set_time_from_leader(tod.to_f) if tod && tod.to_f > 0
    wx = pd[:wx]; wpow = pd[:wpow]
    if wx && (wx.to_s != @last_applied_wx.to_s || wpow.to_i != @last_applied_wpow.to_i)
      @last_applied_wx = wx.to_s; @last_applied_wpow = wpow.to_i
      set_pending_weather(wx, wpow)
    end
  rescue
    nil
  end

  # --- squad lifecycle hook (called from SQUAD_STATE handler) -----------------
  def on_squad_state(prev_squad, new_squad)
    joined_now = prev_squad.nil? && new_squad && new_squad[:members].is_a?(Array) && !new_squad[:members].empty?
    if joined_now
      request_env unless (MultiplayerClient.is_leader? rescue false)
    elsif new_squad.nil?
      clear  # left/disbanded -> back to our own clock
    end
  rescue
    nil
  end
end

#-------------------------------------------------------------------------------
# Override pbGetTimeNow so all day/night calculations follow the synced clock.
#-------------------------------------------------------------------------------
class Object
  unless method_defined?(:mpenv_orig_pbGetTimeNow) || private_method_defined?(:mpenv_orig_pbGetTimeNow)
    alias_method :mpenv_orig_pbGetTimeNow, :pbGetTimeNow
    def pbGetTimeNow
      if defined?(MPEnvSync) && MPEnvSync.time_active?
        return mpenv_orig_pbGetTimeNow + MPEnvSync.time_offset
      end
      mpenv_orig_pbGetTimeNow
    end
  end
end

MultiplayerDebug.info("MODULE-29", "MPEnvSync (time+weather) loaded") if defined?(MultiplayerDebug)
