module AutoplayBot
  module_function

  LOG_ROTATE_BYTES = 1_000_000 unless const_defined?(:LOG_ROTATE_BYTES)

  def rotate_log_if_needed
    return unless defined?(AutoplayBot::LOG_FILE)
    return unless File.exist?(AutoplayBot::LOG_FILE)
    return if File.size(AutoplayBot::LOG_FILE).to_i < LOG_ROTATE_BYTES
    backup = "#{AutoplayBot::LOG_FILE}.old"
    File.delete(backup) if File.exist?(backup)
    File.rename(AutoplayBot::LOG_FILE, backup)
  rescue
    nil
  end

  def log(message)
    raw = message.to_s
    now = Time.now.to_f
    if @last_log_text == raw && @last_log_at && now - @last_log_at.to_f < 1.0
      return
    end
    @last_log_text = raw
    @last_log_at = now
    AutoplayBot::State.ensure_dirs if defined?(AutoplayBot::State)
    if !@last_log_rotate_check_at || now - @last_log_rotate_check_at.to_f > 5.0
      @last_log_rotate_check_at = now
      rotate_log_if_needed
    end
    line = "[#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}] #{raw}"
    File.open(AutoplayBot::LOG_FILE, "a") { |f| f.puts(line) }
    Object.new.send(:echoln, "[AutoplayBot] #{raw}") if Object.new.respond_to?(:echoln, true)
  rescue
    nil
  end

  def prompt_choose(message, commands, cmd_if_cancel = 0, default_cmd = 0)
    AutoplayBot::PromptPolicy.choose(message, commands, cmd_if_cancel, default_cmd)
  end

  def prompt_text(message, minlength, maxlength, initial = "", mode = 0, pokemon = nil)
    AutoplayBot::PromptPolicy.text_for(message, minlength, maxlength, initial, mode, pokemon)
  end

  def manual_exclusive_prompt?(message, commands)
    return false unless defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.prompt_control?
    return false unless defined?(AutoplayBot::PromptPolicy) &&
                        AutoplayBot::PromptPolicy.respond_to?(:manual_exclusive_choice?)
    return false unless AutoplayBot::PromptPolicy.manual_exclusive_choice?(message, commands)
    label = commands && commands.respond_to?(:first) ? commands.first.to_s : "choice"
    AutoplayBot::Runtime.manual_needed("exclusive choice: #{label}")
    true
  rescue
    false
  end

  def status(message)
    text = message.to_s.gsub(/\s+/, " ").strip
    return if text.empty?
    @status_message = text
    @status_history ||= []
    frame = Graphics.frame_count rescue 0
    unless @status_history.last && @status_history.last["text"] == text
      @status_history << { "frame" => frame.to_i, "text" => text }
      @status_history.shift while @status_history.length > 4
    end
    AutoplayBot::Overlay.request_refresh! if defined?(AutoplayBot::Overlay) &&
                                             AutoplayBot::Overlay.respond_to?(:request_refresh!)
  rescue
    nil
  end

  def status_message
    @status_message || "idle"
  end

  def status_history
    @status_history || []
  rescue
    []
  end

  module Runtime
    module_function

    def install!
      install_pause_menu_hooks!
      return if @installed
      @installed = true
      @mode = "idle"
      @hotkey_armed = true
    rescue => e
      AutoplayBot.log("runtime install failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def enabled?
      AutoplayBot::Config.enabled?
    rescue
      false
    end

    def state_loaded?
      return false unless defined?(AutoplayBot::State)
      return true unless AutoplayBot::State.respond_to?(:loaded?)
      AutoplayBot::State.loaded?
    rescue
      false
    end

    def state_deferred?
      @deferred_state_clear_reason && !state_loaded?
    rescue
      false
    end

    def running?
      @mode == "running"
    end

    def arming?
      @mode == "arming"
    end

    def active?
      enabled? && @mode && @mode != "idle"
    end

    def paused?
      @mode == "paused" || @mode == "manual_needed"
    end

    def overlay_visible?
      return false unless enabled?
      return false if defined?(AutoplayBot::Config) &&
                      AutoplayBot::Config.respond_to?(:overlay_enabled?) &&
                      !AutoplayBot::Config.overlay_enabled?
      return false if startup_overlay_suppressed?
      return true if @mode == "running"
      return true if @mode == "arming"
      false
    end

    def startup_overlay_suppressed?
      return false unless @mode == "running"
      return false if startup_light? || @startup_bootstrap_pending || startup_memory_defer_active?
      return false unless @started_at
      current_time_seconds - @started_at.to_f < 0.10
    rescue
      false
    end

    def virtual_input_allowed?
      enabled? && running? && safe_input_context? && !human_override_active?
    end

    def run_modifier_allowed?
      return false unless virtual_input_allowed?
      return false unless map_scene_ready?
      return false if battle_context? || menu_context_active? || forced_input_context?
      return false unless defined?(Input) && Input.const_defined?(:ACTION)
      return false unless defined?($Trainer) && $Trainer &&
                          $Trainer.respond_to?(:has_running_shoes) &&
                          $Trainer.has_running_shoes
      return false if defined?($PokemonSystem) && $PokemonSystem &&
                      $PokemonSystem.respond_to?(:runstyle) &&
                      $PokemonSystem.runstyle.to_i == 1
      if defined?($PokemonGlobal) && $PokemonGlobal
        return false if $PokemonGlobal.respond_to?(:bicycle) && $PokemonGlobal.bicycle
        return false if $PokemonGlobal.respond_to?(:surfing) && $PokemonGlobal.surfing
        return false if $PokemonGlobal.respond_to?(:diving) && $PokemonGlobal.diving
      end
      if defined?($game_player) && $game_player && $game_player.respond_to?(:pbTerrainTag)
        terrain = $game_player.pbTerrainTag rescue nil
        return false if terrain && terrain.respond_to?(:must_walk) && terrain.must_walk
      end
      true
    rescue
      false
    end

    def prompt_control?
      enabled? && running? && safe_input_context? && !human_override_active?
    end

    def dialog_control?
      return false unless enabled? && running? && safe_input_context?
      return true unless human_override_active?
      return true if battle_context? || forced_input_context?
      return false unless @human_override_last_at
      current_time_seconds - @human_override_last_at.to_f >= 3.0
    rescue
      false
    end

    def message_hook_control?
      return false unless enabled? && running?
      return true if battle_message_context? || battle_engine_active?
      return true if safe_input_context?
      false
    rescue
      false
    end

    def prompt_choice_control?
      return false unless enabled? && running? && safe_input_context?
      return true unless human_override_active?
      return false unless @human_override_last_at
      return false if current_time_seconds - @human_override_last_at.to_f < 3.0
      clear_human_override_for_prompt!("choice")
      true
    rescue
      false
    end

    def pause_menu_control?
      enabled? && running? && !human_override_active?
    rescue
      false
    end

    def after_input_update
      return if @inside_update
      @inside_update = true
      AutoplayBot::InputQueue.begin_frame
      install! unless @installed
      install_pause_menu_hooks! unless @pause_menu_hooks_installed
      observe_game_speed!
      handle_hotkey
      human_override_tick
      process_armed_start
      refresh_startup_feedback_overlay
      return if @mode == "arming"
      start!("autostart") if @mode == "idle" && AutoplayBot::Config.autostart? && !@user_stopped && can_start_now?
      return if @started_frame && (Graphics.frame_count rescue 0).to_i == @started_frame.to_i
      detect_post_battle_map_return! if running?
      battle_active = running? && battle_context?
      battle_context_guard!(battle_active) if running?
      battle_intro_speed_lock_tick if running?
      capture_storage_watchdog_tick if running?
      battle_transition_watchdog_tick if running?
      post_battle_map_recover_tick if running?
      overworld_battle_dialog_recover_tick if running?
      map_battle_state_sweeper_tick if running?
      stale_forced_prompt_tick if running?
      black_transition_watchdog_tick if running?
      stale_map_menu_watchdog_tick if running? || @mode == "arming"
      battle_active = running? && battle_context?
      menu_active = running? && !battle_active && menu_context_active?
      if battle_active || menu_active
        context_interrupt_overworld_motion!(battle_active ? "battle" : "menu")
      else
        clear_context_interrupt_latch!
      end
      battle_confirm_pulse_tick if running? && battle_active
      battle_scene_idle_confirm_tick if running? && battle_active
      tick if running? && !battle_active && !menu_active && !forced_input_context? && !human_override_active? && runtime_tick_due?
      forced_prompt_tick if running?
      pause_menu_action_tick if running? && !battle_active
      menu_idle_watchdog_tick if running? && !battle_active
      battle_idle_watchdog_tick if running?
    rescue => e
      manual_needed("runtime update failure: #{e.class}: #{e.message}")
    ensure
      @inside_update = false
    end

    def handle_hotkey
      refresh_hotkey_latch
      return unless @hotkey_armed
      return unless hotkey_pressed?
      frame = Graphics.frame_count rescue 0
      now = current_time_seconds
      @last_hotkey_at = -9999.0 if @last_hotkey_at.nil?
      return if now - @last_hotkey_at.to_f < 0.25
      @last_hotkey_at = now
      @last_hotkey_frame = frame.to_i
      disarm_hotkey
      if active?
        stop!("user hotkey")
      elsif enabled?
        # F5 must feel like an interrupt.  Start immediately and let the
        # lightweight startup window defer scanners/state work after the game
        # has had a chance to draw and accept input again.
        start!("user hotkey", 0, true)
      end
    end

    def refresh_startup_feedback_overlay
      return unless defined?(AutoplayBot::Overlay)
      return unless startup_feedback_active?
      now = current_time_seconds
      return if @last_startup_feedback_overlay_at &&
                now - @last_startup_feedback_overlay_at.to_f < 0.15
      @last_startup_feedback_overlay_at = now
      AutoplayBot::Overlay.quick_feedback!(startup_feedback_text, false)
    rescue
      nil
    end

    def hotkey_pressed?
      button = AutoplayBot::Config.pause_button
      return false unless button
      if Input.respond_to?(:autoplay_bot_original_trigger?)
        return Input.autoplay_bot_original_trigger?(button)
      end
      Input.trigger?(button)
    rescue
      false
    end

    def refresh_hotkey_latch
      @hotkey_armed = true unless hotkey_down?
    rescue
      @hotkey_armed = true if @hotkey_armed.nil?
    end

    def disarm_hotkey
      @hotkey_armed = false
    rescue
      nil
    end

    def install_pause_menu_hooks!
      return if @pause_menu_hooks_installed
      return unless defined?(PokemonPauseMenu_Scene)
      klass = PokemonPauseMenu_Scene
      return unless klass.method_defined?(:pbShowCommands)
      klass.class_eval do
        alias autoplay_bot_runtime_pause_menu_pbShowCommands pbShowCommands unless method_defined?(:autoplay_bot_runtime_pause_menu_pbShowCommands)

        def pbShowCommands(commands)
          if defined?(AutoplayBot::Runtime) &&
             AutoplayBot::Runtime.pause_menu_control? &&
             defined?(AutoplayBot::MenuTools) &&
             AutoplayBot::MenuTools.respond_to?(:choose_pause_command)
            choice = AutoplayBot::MenuTools.choose_pause_command(commands)
            return choice unless choice.nil?
          end
          autoplay_bot_runtime_pause_menu_pbShowCommands(commands)
        end
      end
      @pause_menu_hooks_installed = true
      AutoplayBot.log("runtime pause menu hook installed") if AutoplayBot.respond_to?(:log)
    rescue => e
      AutoplayBot.log("runtime pause menu hook failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def process_armed_start
      return unless @mode == "arming"
      frame = Graphics.frame_count rescue 0
      now = current_time_seconds
      @last_armed_start_check_at ||= 0.0
      return if now - @last_armed_start_check_at.to_f < 0.04
      @last_armed_start_check_at = now
      @armed_start_frame ||= frame.to_i
      @armed_start_at ||= now
      if lightweight_hotkey_start_ready?
        start!("user hotkey", hotkey_start_settle_frames, true)
        return
      end
      if arming_startup_defer_active?(frame, now)
        AutoplayBot.status("arming: taking over")
        AutoplayBot::Overlay.quick_feedback!(startup_feedback_text) if defined?(AutoplayBot::Overlay)
        return
      end
      reason = lightweight_start_block_reason
      if frame.to_i - @armed_start_frame.to_i > 600 || now - @armed_start_at.to_f > 8.0
        ignore_hotkey_start!(reason)
        return
      end
      @last_arming_overlay_frame ||= -9999
      @last_arming_overlay_at ||= 0.0
      if frame.to_i - @last_arming_overlay_frame.to_i >= 15 ||
         now - @last_arming_overlay_at.to_f >= 0.25
        @last_arming_overlay_frame = frame.to_i
        @last_arming_overlay_at = now
        AutoplayBot.status("arming: #{reason}")
        AutoplayBot::Overlay.quick_feedback!(startup_feedback_text) if defined?(AutoplayBot::Overlay)
      end
    rescue => e
      AutoplayBot.log("armed start failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      ignore_hotkey_start!("wait for overworld")
    end

    def lightweight_hotkey_start_ready?
      return true if battle_hotkey_start_ready?
      return true if menu_hotkey_start_ready?
      return false unless live_overworld_surface?
      return false unless trainer_ready?
      return false if hard_scene_transition_busy?
      if defined?($game_temp) && $game_temp
        return false if $game_temp.player_transferring || $game_temp.transition_processing || $game_temp.to_title
      end
      return false if defined?($game_player) && $game_player &&
                      $game_player.respond_to?(:moving?) && $game_player.moving?
      true
    rescue
      false
    end

    def lightweight_start_block_reason
      return "wait battle/menu" if battle_context? || menu_context_active?
      return "wait overworld" unless live_overworld_surface?
      return "wait trainer setup" unless trainer_ready?
      return "wait transition" if hard_scene_transition_busy?
      if defined?($game_temp) && $game_temp &&
         ($game_temp.player_transferring || $game_temp.transition_processing || $game_temp.to_title)
        return "wait transfer"
      end
      return "wait player stop" if defined?($game_player) && $game_player &&
                                  $game_player.respond_to?(:moving?) && $game_player.moving?
      "wait map"
    rescue
      "wait map"
    end

    def arming_startup_defer_active?(frame = nil, now = nil)
      return false unless @armed_start_frame || @armed_start_at
      frame ||= (Graphics.frame_count rescue 0).to_i
      now ||= current_time_seconds
      frame_waiting = @armed_start_frame && frame.to_i - @armed_start_frame.to_i < arm_start_min_frames
      time_waiting = @armed_start_at && now.to_f - @armed_start_at.to_f < arm_start_min_seconds
      frame_waiting || time_waiting
    rescue
      false
    end

    def arm_start_min_frames
      speed = game_speed_multiplier
      return 2 if speed >= 7
      return 3 if speed >= 3
      4
    rescue
      4
    end

    def arm_start_min_seconds
      0.03
    rescue
      0.03
    end

    def arming_ready_reason?(reason)
      return true if reason.to_s == "ready"
      map_scene_ready? && control_block_reason.nil?
    rescue
      false
    end

    def arm_start!(detail = nil)
      @mode = "arming"
      @user_stopped = false
      @armed_start_frame = (Graphics.frame_count rescue 0).to_i
      @armed_start_at = current_time_seconds
      @armed_start_detail = detail.to_s
      @last_armed_start_check_at = nil
      @human_override_active = false
      @human_override_last_frame = nil
      @human_override_last_at = nil
      @quick_start_pos = nil
      @quick_start_stable_frames = 0
      @quick_start_last_frame = nil
      @last_arming_overlay_at = nil
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      AutoplayBot.status("arming: #{detail && !detail.to_s.empty? ? detail : "waiting"}")
      if defined?(AutoplayBot::Overlay)
        AutoplayBot::Overlay.quick_feedback!(startup_feedback_text)
        AutoplayBot::Overlay.request_refresh!
      end
    rescue => e
      AutoplayBot.log("arm start failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def hotkey_start_settle_frames
      1
    end

    def start!(reason = "start", settle_frames = nil, bypass_gate = false)
      install! unless @installed
      unless bypass_gate || can_start_now?(settle_frames)
        block_start!(reason, start_block_reason)
        return false
      end
      @user_stopped = false
      @mode = "running"
      @armed_start_frame = nil
      frame = (Graphics.frame_count rescue 0).to_i
      @started_frame = frame
      @started_at = current_time_seconds
      @startup_light_until_frame = frame + startup_light_frames
      @startup_light_until_at = @started_at.to_f + startup_light_seconds
      @startup_start_pos = current_position_key
      @startup_bootstrap_pending = true
      @startup_bootstrap_phase = 0
      @startup_bootstrap_reason = reason.to_s
      @startup_bootstrap_started_frame = frame
      @startup_bootstrap_started_at = @started_at
      @last_runtime_tick_at = nil
      @human_override_active = false
      @human_override_last_frame = nil
      @human_override_last_at = nil
      @quick_start_pos = nil
      @quick_start_stable_frames = 0
      @quick_start_last_frame = nil
      @last_arming_overlay_frame = nil
      @last_arming_overlay_at = nil
      @last_startup_feedback_overlay_at = nil
      @pending_start_feedback_text = instant_start_feedback_text
      AutoplayBot::InputQueue.clear
      battle_start = defined?($scene) && $scene && $scene.class.to_s =~ /Battle/
      AutoplayBot.status(battle_start ? "battle: taking over" : "startup: instant takeover")
      if defined?(AutoplayBot::Overlay)
        AutoplayBot::Overlay.request_refresh!
      end
      true
    rescue => e
      AutoplayBot.log("start failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def block_start!(reason, detail = nil)
      @mode = "idle"
      @user_stopped = true if reason.to_s.include?("hotkey")
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      message = detail && !detail.to_s.empty? ? detail.to_s : "wait for overworld"
      AutoplayBot.status("off: #{message}")
      AutoplayBot.log("start ignored: #{reason}; #{message}") if AutoplayBot.respond_to?(:log)
      if state_loaded?
        AutoplayBot::State.set_mode(@mode)
        if reason.to_s.include?("hotkey") && AutoplayBot::State.respond_to?(:postpone_save)
          frame = Graphics.frame_count rescue 0
          AutoplayBot::State.postpone_save(frame)
        else
          AutoplayBot::State.save!(true)
        end
      end
      AutoplayBot::Overlay.dispose if defined?(AutoplayBot::Overlay)
    rescue => e
      AutoplayBot.log("start block failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def ignore_hotkey_start!(detail = nil)
      @mode = "idle"
      @user_stopped = false
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      message = detail && !detail.to_s.empty? ? detail.to_s : "wait for player control"
      AutoplayBot.status("off: #{message}")
      now = current_time_seconds
      @last_ignored_hotkey_at = -9999.0 if @last_ignored_hotkey_at.nil?
      if now - @last_ignored_hotkey_at.to_f >= 1.0
        @last_ignored_hotkey_at = now
        AutoplayBot.log("hotkey ignored; #{message}") if AutoplayBot.respond_to?(:log)
      end
      AutoplayBot::Overlay.dispose if defined?(AutoplayBot::Overlay)
    rescue => e
      AutoplayBot.log("hotkey ignore failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def can_start_now?(settle_frames = nil)
      return false unless map_scene_ready?
      return true if !settle_frames.nil? && map_controls_ready?
      map_scene_settled?(settle_frames) && map_controls_ready?
    rescue
      false
    end

    def can_hotkey_start_now?(settle_frames = nil)
      return true if can_start_now?(settle_frames)
      return true if battle_hotkey_start_ready?
      return true if menu_hotkey_start_ready?
      false
    rescue
      false
    end

    def battle_hotkey_start_ready?
      return false unless trainer_ready?
      return false unless real_battle_scene?
      return false if hard_scene_transition_busy?
      true
    rescue
      false
    end

    def menu_hotkey_start_ready?
      return false unless trainer_ready?
      return false if battle_context?
      return false unless menu_context_active?
      return false if hard_scene_transition_busy?
      scene_name = defined?($scene) && $scene ? $scene.class.to_s : ""
      return false if scene_name =~ /Title|Intro|Load|Splash|Credit/i
      true
    rescue
      false
    end

    def quick_start_ready?(settle_frames = nil)
      return false unless map_scene_ready?
      return false unless map_controls_ready?
      frame = Graphics.frame_count rescue 0
      pos = if defined?($game_map) && $game_map && defined?($game_player) && $game_player
              [$game_map.map_id, $game_player.x, $game_player.y]
            else
              nil
            end
      if @quick_start_pos == pos
        @quick_start_stable_frames = @quick_start_stable_frames.to_i + [frame.to_i - @quick_start_last_frame.to_i, 1].max
      else
        @quick_start_pos = pos
        @quick_start_stable_frames = 0
      end
      @quick_start_last_frame = frame.to_i
      needed = [[settle_frames.to_i, 1].max, 6].min
      @quick_start_stable_frames.to_i >= needed
    rescue
      false
    end

    def safe_input_context?
      return true if forced_input_context?
      return true if menu_context_active?
      return true if map_scene_ready?
      return true if battle_context?
      false
    rescue
      false
    end

    def forced_input_context?
      @forced_input_context == true
    end

    def battle_prompt_context?
      !!(forced_input_context? && @forced_input_label.to_s =~ /battle/i)
    rescue
      false
    end

    def pokedex_entry_autoskip?
      enabled? && running?
    rescue
      false
    end

    def note_pokedex_entry_skipped!(species = nil)
      clear_forced_prompt_state! if forced_input_context? && @forced_input_label.to_s =~ /pokedex/i
      AutoplayBot.status("pokedex: skipped entry") if AutoplayBot.respond_to?(:status)
      now = current_time_seconds
      return if @last_pokedex_skip_log_at && now - @last_pokedex_skip_log_at.to_f < 1.0
      @last_pokedex_skip_log_at = now
      AutoplayBot.log("skipped pokedex entry #{species} at #{map_position_for_log}") if AutoplayBot.respond_to?(:log)
    rescue
      nil
    end

    def with_forced_input_context(label = "prompt")
      clear_generation = @forced_input_clear_generation.to_i
      old_context = @forced_input_context
      old_label = @forced_input_label
      old_started_at = @forced_input_started_at
      old_started_frame = @forced_input_started_frame
      old_attempts = @forced_input_press_attempts
      old_escape_presses = @forced_input_escape_presses
      @forced_input_context = true
      @forced_input_label = label.to_s
      unless old_context
        @forced_input_started_at = current_time_seconds
        @forced_input_started_frame = (Graphics.frame_count rescue 0).to_i
        @forced_input_press_attempts = 0
        @forced_input_escape_presses = 0
        @last_forced_prompt_frame = nil
        @last_forced_prompt_time = nil
      end
      completed = false
      result = yield
      completed = true
      result
    ensure
      if @forced_input_clear_generation.to_i == clear_generation
        @forced_input_context = old_context
        @forced_input_label = old_label
        @forced_input_started_at = old_started_at
        @forced_input_started_frame = old_started_frame
        @forced_input_press_attempts = old_attempts
        @forced_input_escape_presses = old_escape_presses
      end
      battle_label = label.to_s =~ /battle/i
      if completed && running? && !battle_label &&
         defined?(AutoplayBot::Director) &&
         AutoplayBot::Director.respond_to?(:note_forced_input_complete!)
        AutoplayBot::Director.note_forced_input_complete!(label)
      end
    end

    def forced_prompt_tick
      return unless forced_input_context?
      emergency_hotkey_stop
      return unless running?
      label = @forced_input_label && !@forced_input_label.empty? ? @forced_input_label : "prompt"
      if human_override_active?
        return if prompt_human_override_hold?(label)
        clear_human_override_for_prompt!(label)
      end
      return unless prompt_press_due?(label)
      remember_prompt_press!
      if human_confirm_input_active?
        throttled_prompt_status("#{label}: player input")
        return
      end
      @forced_input_press_attempts = @forced_input_press_attempts.to_i + 1
      escape = forced_prompt_escape_due?(label)
      queue_prompt_press(label, escape)
    rescue
      nil
    end

    def runtime_tick_due?
      now = current_time_seconds
      interval = runtime_tick_interval_seconds
      return false if @last_runtime_tick_at && now - @last_runtime_tick_at.to_f < interval
      @last_runtime_tick_at = now
      true
    rescue
      true
    end

    def runtime_tick_interval_seconds
      return 0.018 if critical_speed_context?
      return 0.025 if startup_light?
      return 0.018 if queued_static_map_movement?
      return 0.060 if queued_map_movement?
      speed = game_speed_multiplier
      return 0.045 if speed >= 7
      return 0.035 if speed >= 3
      0.025
    rescue
      0.035
    end

    def queued_map_movement?
      return false unless defined?(AutoplayBot::InputQueue) &&
                          AutoplayBot::InputQueue.respond_to?(:dir_frames_remaining) &&
                          AutoplayBot::InputQueue.dir_frames_remaining.to_i > 2
      return false unless defined?($scene) && defined?(Scene_Map) && $scene.is_a?(Scene_Map)
      true
    rescue
      false
    end

    def queued_static_map_movement?
      return false unless queued_map_movement?
      return false unless defined?($game_player) && $game_player
      return false if $game_player.respond_to?(:moving?) && $game_player.moving?
      true
    rescue
      false
    end

    def prompt_press_due?(label)
      now = current_time_seconds
      last = @last_forced_prompt_time
      return true unless last
      return false if now - last.to_f < prompt_min_interval_seconds(label)
      true
    rescue
      true
    end

    def remember_prompt_press!
      @last_forced_prompt_time = current_time_seconds
      @last_forced_prompt_frame = (Graphics.frame_count rescue 0).to_i
    rescue
      nil
    end

    def prompt_min_interval_seconds(label)
      speed = game_speed_multiplier
      battle = label.to_s =~ /battle/i
      return 0.06 if battle && speed >= 5
      return 0.08 if battle
      speed >= 5 ? 0.10 : 0.10
    rescue
      0.10
    end

    def prompt_hold_frames
      speed = game_speed_multiplier
      return [[speed.to_i * 2, 12].max, 24].min if speed >= 7
      return [[speed.to_i * 2, 8].max, 14].min if speed >= 3
      3
    rescue
      3
    end

    def queue_prompt_press(label, escape = false)
      button = :USE
      if escape
        @forced_input_escape_presses = @forced_input_escape_presses.to_i + 1
        button = :BACK if (@forced_input_escape_presses % 3).zero?
      end
      frames = prompt_hold_frames
      if button == :USE
        queue_confirm_press(frames)
      else
        AutoplayBot::InputQueue.tap(button, frames)
        AutoplayBot::InputQueue.tap_next(button, frames) if AutoplayBot::InputQueue.respond_to?(:tap_next)
      end
      suffix = button == :BACK ? "escape" : "use"
      throttled_prompt_status("#{label}: pressing #{suffix}")
      note_battle_automation! if battle_prompt_label?(label) || battle_context?
    rescue
      nil
    end

    def queue_confirm_press(frames = nil)
      frames ||= prompt_hold_frames
      queued = false
      [:USE, :C].each do |button|
        next unless defined?(Input) && Input.const_defined?(button)
        queued = true if AutoplayBot::InputQueue.tap(button, frames)
        if AutoplayBot::InputQueue.respond_to?(:tap_next)
          queued = true if AutoplayBot::InputQueue.tap_next(button, frames)
        end
      end
      queued
    rescue
      false
    end

    def battle_confirm_pulse_tick
      return unless battle_context?
      return unless battle_text_prompt_active?
      return if battle_pulse_human_override_hold?
      clear_human_override_for_prompt!("battle") if human_override_active?
      return unless battle_confirm_pulse_due?
      queue_confirm_press(prompt_hold_frames)
      @battle_confirm_pulse_count = @battle_confirm_pulse_count.to_i + 1
      if (@battle_confirm_pulse_count % 12).zero?
        throttled_prompt_status("battle: confirm pulse")
      end
    rescue
      nil
    end

    def battle_dialog_update_pulse!
      return unless running?
      prompt_label = forced_input_context? && battle_prompt_label?(@forced_input_label)
      return unless battle_text_prompt_active? || prompt_label
      return if battle_pulse_human_override_hold?
      clear_human_override_for_prompt!("battle") if human_override_active?
      now = current_time_seconds
      @last_battle_dialog_update_pulse_at ||= 0.0
      return if now - @last_battle_dialog_update_pulse_at.to_f < battle_dialog_pulse_interval_seconds
      @last_battle_dialog_update_pulse_at = now
      queue_confirm_press(prompt_hold_frames)
      @battle_confirm_pulse_count = @battle_confirm_pulse_count.to_i + 1
      throttled_prompt_status("battle: dialog pulse") if (@battle_confirm_pulse_count % 12).zero?
    rescue
      nil
    end

    def battle_scene_idle_confirm_tick(label = "battle scene")
      return unless running?
      return if forced_input_context? && !battle_prompt_label?(@forced_input_label)
      return if battle_pulse_human_override_hold?
      return unless battle_context?
      return unless real_battle_scene? || raw_battle_flag_active?
      frame = (Graphics.frame_count rescue 0).to_i
      return if @battle_transition_clear_until_frame &&
                frame <= @battle_transition_clear_until_frame.to_i
      now = current_time_seconds
      started = @battle_context_started_at || @battle_engine_last_seen_at || now
      grace = game_speed_multiplier >= 7 ? 0.18 : 0.35
      return if now - started.to_f < grace
      @last_battle_scene_idle_confirm_at ||= 0.0
      interval = game_speed_multiplier >= 7 ? 0.09 : (game_speed_multiplier >= 3 ? 0.12 : 0.18)
      return if now - @last_battle_scene_idle_confirm_at.to_f < interval
      @last_battle_scene_idle_confirm_at = now
      queue_confirm_press(prompt_hold_frames)
      @battle_scene_idle_confirm_count = @battle_scene_idle_confirm_count.to_i + 1
      if (@battle_scene_idle_confirm_count % 14).zero?
        throttled_prompt_status("#{label}: confirm")
      end
    rescue
      nil
    end

    def battle_dialog_confirm_trigger?(button)
      return false unless running?
      return false unless confirm_button_value?(button)
      prompt_label = forced_input_context? && battle_prompt_label?(@forced_input_label)
      return false unless battle_text_prompt_active? || prompt_label
      return false if battle_pulse_human_override_hold?
      now = current_time_seconds
      @last_direct_battle_dialog_trigger_at ||= 0.0
      return false if now - @last_direct_battle_dialog_trigger_at.to_f < battle_dialog_direct_interval_seconds
      @last_direct_battle_dialog_trigger_at = now
      @last_direct_battle_dialog_trigger_frame = (Graphics.frame_count rescue 0).to_i
      @battle_confirm_pulse_count = @battle_confirm_pulse_count.to_i + 1
      note_battle_automation!
      throttled_prompt_status("battle: accept text") if (@battle_confirm_pulse_count % 8).zero?
      true
    rescue
      false
    end

    def confirm_button_value?(button)
      return false unless defined?(Input)
      [:USE, :C].any? do |name|
        Input.const_defined?(name) && button == Input.const_get(name)
      end
    rescue
      false
    end

    def battle_text_prompt_active?
      return true if top_right_window_context?
      return true if battle_message_context?
      return true if battle_ability_splash_active?
      return true if recent_battle_message_active?
      return true if forced_input_context? && battle_prompt_label?(@forced_input_label)
      return true if battle_context? && soft_map_message_busy?
      false
    rescue
      false
    end

    def recent_battle_message_active?
      return false unless @recent_battle_message_until_at
      if current_time_seconds > @recent_battle_message_until_at.to_f
        @recent_battle_message_until_at = nil
        return false
      end
      true
    rescue
      false
    end

    def battle_state_hint?
      battle_message_context? || battle_engine_active? || battle_context? ||
        real_battle_scene? || raw_battle_flag_active? || battle_prompt_context?
    rescue
      false
    end

    def battle_like_message?(message = nil)
      return true if battle_state_hint?
      text = normalize_message_text(message)
      return false if text.empty?
      strong = /(Exp\.? Points|boosted|grew to Lv|wants to learn|forgot how|learned |fainted|defeated|black(ed)? out|used .*!|super effective|not very effective|critical hit|missed|failed|no effect|restored|healed|caught|broke free|escaped|stored in box|transferred|added to your party|registered|Pok[eé]dex|evolved|is evolving|sent out|go!|appeared|challenged)/i
      return true if text =~ strong
      return false unless @battle_engine_last_seen_at &&
                          current_time_seconds - @battle_engine_last_seen_at.to_f < 12.0
      text =~ /(\bally\b|\bfoe\b|\bwild\b|enemy|opposing|turn|party|box|ball|move|attack|status)/i
    rescue
      false
    end

    def note_battle_dialog_message!(message = nil, label = "battle dialog")
      note_battle_engine_active!(label)
      @recent_battle_message_until_at = current_time_seconds + battle_message_recent_seconds
      @last_battle_dialog_text = normalize_message_text(message)[0, 80]
      @last_battle_scene_idle_confirm_at = 0.0
      queue_confirm_press(prompt_hold_frames)
    rescue
      nil
    end

    def battle_message_recent_seconds
      speed = game_speed_multiplier
      return 2.4 if speed >= 7
      return 3.0 if speed >= 3
      3.8
    rescue
      3.0
    end

    def normalize_message_text(message)
      message.to_s.gsub(/\\[A-Za-z](\[[^\]]*\])?/, " ").gsub(/\s+/, " ").strip
    rescue
      ""
    end

    def message_window_text(msgwindow)
      return nil unless msgwindow
      if msgwindow.respond_to?(:text)
        return msgwindow.text
      end
      if msgwindow.instance_variable_defined?(:@text)
        return msgwindow.instance_variable_get(:@text)
      end
      nil
    rescue
      nil
    end

    def battle_prompt_label?(label)
      label.to_s =~ /battle|level up|pokedex|evol|move|caught|storage|nickname|sprite/i
    rescue
      false
    end

    def auto_skip_battle_paused_message?(message)
      return false unless enabled? && running?
      text = message.to_s
      return true if text =~ /has been added to your party/i
      return true if text =~ /was transferred to/i
      return true if text =~ /was stored in box/i
      return true if text =~ /It was stored in box/i
      return true if text =~ /data was added to the Pok/i
      false
    rescue
      false
    end

    def note_skipped_battle_message!(message, label = "battle message")
      note_battle_engine_active!(label) if respond_to?(:note_battle_engine_active!)
      note_capture_storage_progress!(label, message) if capture_storage_text?(label, message)
      clear_forced_prompt_state! if forced_input_context? &&
                                    @forced_input_label.to_s =~ /battle|caught|storage|pokedex/i &&
                                    !capture_storage_active?
      short = message.to_s.gsub(/\s+/, " ").strip
      short = short[0, 48] + "..." if short.length > 51
      AutoplayBot.status("battle: skipped #{short}") if AutoplayBot.respond_to?(:status)
      now = current_time_seconds
      arm_post_capture_confirm!(label, message)
      queue_confirm_press(prompt_hold_frames)
      return if @last_skipped_battle_message == short && @last_skipped_battle_message_at &&
                now - @last_skipped_battle_message_at.to_f < 1.0
      @last_skipped_battle_message = short
      @last_skipped_battle_message_at = now
      AutoplayBot.log("skipped battle message: #{short}") if AutoplayBot.respond_to?(:log)
    rescue
      nil
    end

    def arm_post_capture_confirm!(label = nil, message = nil)
      text = [label, message].compact.join(" ")
      return unless text =~ /caught|storage|pokedex|transferred|stored in box|added to your party|data was added/i
      @post_capture_confirm_until_at = current_time_seconds + post_capture_confirm_seconds
      @last_battle_scene_idle_confirm_at = 0.0
    rescue
      nil
    end

    def post_capture_confirm_seconds
      speed = game_speed_multiplier
      return 4.0 if speed >= 7
      return 4.8 if speed >= 3
      5.8
    rescue
      4.8
    end

    def post_capture_confirm_active?
      return false unless @post_capture_confirm_until_at
      if current_time_seconds > @post_capture_confirm_until_at.to_f
        @post_capture_confirm_until_at = nil
        return false
      end
      true
    rescue
      false
    end

    def capture_storage_text?(label = nil, message = nil)
      [label, message].compact.join(" ") =~ /caught|storage|stored in box|added to your party|transferred|data was added/i
    rescue
      false
    end

    def with_capture_storage_context(label = "caught storage")
      old_depth = @capture_storage_context_depth.to_i
      @capture_storage_context_depth = old_depth + 1
      note_capture_storage_progress!(label, "begin")
      yield
    ensure
      @capture_storage_context_depth = old_depth
      note_capture_storage_progress!(label, "finished")
      arm_post_capture_confirm!(label, "finished")
    end

    def note_capture_storage_progress!(label = nil, message = nil)
      now = current_time_seconds
      @capture_storage_started_at ||= now
      @capture_storage_last_seen_at = now
      @last_battle_scene_idle_confirm_at = 0.0
      until_at = now + capture_storage_grace_seconds
      current_until = @post_capture_confirm_until_at ? @post_capture_confirm_until_at.to_f : 0.0
      @post_capture_confirm_until_at = [current_until, until_at].max
      note_battle_engine_active!(label || "caught storage") if respond_to?(:note_battle_engine_active!)
      if !@last_capture_storage_log_at || now - @last_capture_storage_log_at.to_f >= 1.0
        @last_capture_storage_log_at = now
        AutoplayBot.log("capture storage active: #{[label, message].compact.join(' ')}") if AutoplayBot.respond_to?(:log)
      end
    rescue
      nil
    end

    def capture_storage_active?
      return true if @capture_storage_context_depth.to_i > 0
      return false unless @capture_storage_last_seen_at
      now = current_time_seconds
      if now - @capture_storage_last_seen_at.to_f > capture_storage_grace_seconds
        @capture_storage_started_at = nil
        @capture_storage_last_seen_at = nil
        @last_capture_storage_confirm_at = nil
        return false
      end
      return true if post_capture_confirm_active?
      return true if raw_battle_flag_active? || real_battle_scene?
      return true if @battle_engine_last_seen_at && now - @battle_engine_last_seen_at.to_f < 2.0
      false
    rescue
      false
    end

    def capture_storage_grace_seconds
      speed = game_speed_multiplier
      return 6.5 if speed >= 7
      return 7.5 if speed >= 3
      8.5
    rescue
      7.5
    end

    def capture_storage_watchdog_tick
      return unless capture_storage_active?
      now = current_time_seconds
      @last_capture_storage_confirm_at ||= 0.0
      interval = game_speed_multiplier >= 7 ? 0.12 : (game_speed_multiplier >= 3 ? 0.18 : 0.25)
      return if now - @last_capture_storage_confirm_at.to_f < interval
      @last_capture_storage_confirm_at = now
      queue_confirm_press(prompt_hold_frames)
      AutoplayBot.status("battle: storing catch") if AutoplayBot.respond_to?(:status)
    rescue
      nil
    end

    def bot_battle_fast_forward?
      enabled? && running?
    rescue
      false
    end

    def note_battle_ability_splash!(label = "ability splash", _battler = nil)
      note_battle_engine_active!(label)
      @battle_ability_splash_until_at = current_time_seconds + 1.25
      now = current_time_seconds
      if !@last_battle_ability_splash_log_at ||
         now - @last_battle_ability_splash_log_at.to_f >= 4.0
        @last_battle_ability_splash_log_at = now
        AutoplayBot.log("battle ability splash skipped: #{label}") if AutoplayBot.respond_to?(:log)
      end
    rescue
      nil
    end

    def battle_ability_splash_active?
      return true if @battle_ability_splash_until_at &&
                     current_time_seconds <= @battle_ability_splash_until_at.to_f
      scene = battle_scene_object
      return false unless scene
      if scene.instance_variable_defined?(:@abilityMsgState)
        state = scene.instance_variable_get(:@abilityMsgState) rescue nil
        return true if state && state != :idle
      end
      sprites = scene.instance_variable_get(:@sprites) rescue nil
      return false unless sprites && sprites.respond_to?(:[])
      [0, 1].any? do |side|
        ["abilityBar_#{side}", "ability2Bar_#{side}", "abilityMessage"].any? do |key|
          sprite = sprites[key] rescue nil
          sprite && sprite.respond_to?(:visible) && sprite.visible
        end
      end
    rescue
      false
    end

    def hide_battle_ability_splash!(scene = nil, battler = nil)
      scene ||= battle_scene_object
      return false unless scene
      if scene.instance_variable_defined?(:@abilityMsgState)
        scene.instance_variable_set(:@abilityMsgState, :idle)
        scene.instance_variable_set(:@abilityMsgFrames, 0) if scene.instance_variable_defined?(:@abilityMsgFrames)
      end
      sprites = scene.instance_variable_get(:@sprites) rescue nil
      return true unless sprites && sprites.respond_to?(:[])
      sides = []
      side = (battler.index.to_i % 2 rescue nil)
      sides << side if side
      sides = [0, 1] if sides.empty?
      keys = ["abilityMessage"]
      sides.each do |s|
        keys << "abilityBar_#{s}"
        keys << "ability2Bar_#{s}"
      end
      keys.uniq.each do |key|
        sprite = sprites[key] rescue nil
        next unless sprite
        sprite.visible = false if sprite.respond_to?(:visible=)
        sprite.opacity = 0 if sprite.respond_to?(:opacity=)
      end
      true
    rescue
      false
    end

    def note_battle_engine_active!(reason = "battle")
      @battle_engine_active = true
      @battle_engine_reason = reason.to_s
      @battle_engine_last_seen_at = current_time_seconds
      @battle_map_idle_seen_at = nil
      @battle_engine_end_seen_at = nil
      @battle_context_seen_real_scene = true if defined?($scene) && $scene && $scene.class.to_s =~ /Battle/
    rescue
      nil
    end

    def note_battle_engine_end!
      @battle_engine_active = false
      @battle_engine_reason = nil
      @battle_engine_last_seen_at = current_time_seconds
      @battle_engine_end_seen_at = @battle_engine_last_seen_at
      @battle_message_context_depth = 0
      @recent_battle_message_until_at = current_time_seconds + battle_message_recent_seconds
      @battle_map_idle_seen_at = nil
    rescue
      nil
    end

    def battle_engine_active?
      return true if capture_storage_active?
      return false unless @battle_engine_active
      return true if defined?($scene) && $scene && $scene.class.to_s =~ /Battle/
      return true if @battle_message_context_depth.to_i > 0
      return true if raw_battle_flag_active? &&
                     @battle_engine_last_seen_at &&
                     current_time_seconds - @battle_engine_last_seen_at.to_f < 4.0
      @battle_engine_active = false
      false
    rescue
      false
    end

    def live_battle_protected?
      return true if capture_storage_active?
      return true if real_battle_scene?
      return true if battle_message_context?
      return true if @battle_engine_active && @battle_engine_last_seen_at &&
                     current_time_seconds - @battle_engine_last_seen_at.to_f < 12.0
      if @battle_context_active && !@last_battle_context_end_at
        return true if @battle_context_seen_real_scene
        return false if battle_intro_timed_out?
        return true
      end
      false
    rescue
      false
    end

    def with_battle_message_context(label = "battle dialog")
      old_depth = @battle_message_context_depth.to_i
      @battle_message_context_depth = old_depth + 1
      note_battle_engine_active!(label)
      yield
    ensure
      @battle_message_context_depth = old_depth
      @battle_engine_last_seen_at = current_time_seconds if @battle_engine_active
    end

    def battle_message_context?
      @battle_message_context_depth.to_i > 0
    rescue
      false
    end

    def with_top_right_window_context(label = "top right")
      old_depth = @top_right_window_depth.to_i
      @top_right_window_depth = old_depth + 1
      note_battle_engine_active!(label) if battle_context? || battle_engine_active? ||
                                           (defined?($scene) && $scene && $scene.class.to_s =~ /Battle/)
      yield
    ensure
      @top_right_window_depth = old_depth
      @battle_engine_last_seen_at = current_time_seconds if @battle_engine_active
    end

    def top_right_window_context?
      @top_right_window_depth.to_i > 0
    rescue
      false
    end

    def message_wait_tick
      if battle_message_context? || battle_engine_active? || battle_context? || recent_battle_message_active?
        battle_dialog_update_pulse!
      else
        dialog_tick
      end
    rescue
      nil
    end

    def battle_dialog_direct_interval_frames
      speed = game_speed_multiplier
      return 2 if speed >= 7
      return 3 if speed >= 3
      4
    rescue
      4
    end

    def battle_dialog_direct_interval_seconds
      speed = game_speed_multiplier
      return 0.035 if speed >= 7
      return 0.05 if speed >= 3
      0.07
    rescue
      0.07
    end

    def battle_dialog_pulse_interval_seconds
      speed = game_speed_multiplier
      return 0.045 if speed >= 7
      return 0.06 if speed >= 3
      0.08
    rescue
      0.08
    end

    def battle_confirm_pulse_due?
      now = current_time_seconds
      @last_battle_confirm_pulse_at ||= 0.0
      interval = game_speed_multiplier >= 7 ? 0.055 : (game_speed_multiplier >= 3 ? 0.08 : 0.12)
      return false if now - @last_battle_confirm_pulse_at.to_f < interval
      @last_battle_confirm_pulse_at = now
      true
    rescue
      true
    end

    def battle_pulse_human_override_hold?
      return false unless human_override_active?
      return false unless @human_override_last_at
      if current_time_seconds - @human_override_last_at.to_f < 3.0
        throttled_prompt_status("override: battle wait")
        return true
      end
      clear_human_override_for_prompt!("battle")
      false
    rescue
      false
    end

    def prompt_human_override_hold?(label = "prompt")
      return false unless human_override_active?
      return false unless @human_override_last_at
      if current_time_seconds - @human_override_last_at.to_f < 3.0
        throttled_prompt_status("override: #{label} wait")
        return true
      end
      false
    rescue
      false
    end

    def clear_human_override_for_prompt!(label = "prompt")
      return unless human_override_active?
      @human_override_active = false
      @human_override_last_frame = nil
      @human_override_last_at = nil
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      if defined?(AutoplayBot::Director) &&
         AutoplayBot::Director.respond_to?(:note_human_override_complete!)
        AutoplayBot::Director.note_human_override_complete!(label.to_s)
      end
      throttled_prompt_status("override: #{label} resumed")
    rescue
      @human_override_active = false
    end

    def stale_forced_prompt_tick
      return unless stale_forced_prompt_context?
      label = @forced_input_label && !@forced_input_label.empty? ? @forced_input_label : "prompt"
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      clear_forced_prompt_state!
      @last_runtime_tick_at = nil
      if defined?(AutoplayBot::Director)
        if label.to_s =~ /battle/i &&
           AutoplayBot::Director.respond_to?(:note_battle_context_end!)
          AutoplayBot::Director.note_battle_context_end!
        elsif AutoplayBot::Director.respond_to?(:note_forced_input_complete!)
          AutoplayBot::Director.note_forced_input_complete!("stale #{label}")
        end
      end
      AutoplayBot.status("#{label}: reroute")
      now = current_time_seconds
      if !@last_stale_forced_prompt_log_at || now - @last_stale_forced_prompt_log_at.to_f >= 1.0
        @last_stale_forced_prompt_log_at = now
        AutoplayBot.log("cleared stale forced #{label} at #{map_position_for_log}") if AutoplayBot.respond_to?(:log)
      end
      AutoplayBot::Overlay.update(true) if defined?(AutoplayBot::Overlay)
    rescue => e
      AutoplayBot.log("stale forced prompt clear failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def stale_forced_prompt_context?
      return false unless forced_input_context?
      return false if capture_storage_active?
      label = @forced_input_label.to_s
      return false if protected_forced_prompt_label?(label) &&
                      (top_right_window_context? || battle_message_context? || battle_engine_active? || battle_context?)
      if @forced_input_label.to_s =~ /battle/i &&
         map_scene_ready? &&
         !(defined?($scene) && $scene && $scene.class.to_s =~ /Battle/) &&
         !overworld_recovery_busy?
        return true if forced_prompt_elapsed_seconds >= 0.75
      end
      return false unless map_free_for_reroute?
      elapsed = forced_prompt_elapsed_seconds
      return true if elapsed >= 0.75
      return true if @last_battle_context_end_at &&
                     current_time_seconds - @last_battle_context_end_at.to_f >= 0.4
      false
    rescue
      false
    end

    def protected_forced_prompt_label?(label)
      label.to_s =~ /battle|level up|pokedex|evol|move|caught|storage|nickname/i
    rescue
      false
    end

    def map_free_for_reroute?
      return false unless map_scene_ready?
      return false if defined?($scene) && $scene && $scene.class.to_s =~ /Battle/
      return false if raw_battle_flag_active?
      if defined?($game_temp) && $game_temp
        return false if ($game_temp.in_menu && !map_menu_flag_ignored?) || $game_temp.message_window_showing
        return false if $game_temp.player_transferring || $game_temp.transition_processing || $game_temp.to_title
      end
      return false if defined?($PokemonTemp) && $PokemonTemp &&
                      $PokemonTemp.respond_to?(:miniupdate) && $PokemonTemp.miniupdate
      true
    rescue
      false
    end

    def map_position_for_log
      if defined?($game_map) && $game_map && defined?($game_player) && $game_player
        "map #{$game_map.map_id} x#{$game_player.x} y#{$game_player.y}"
      else
        "no map"
      end
    rescue
      "no map"
    end

    def forced_prompt_escape_due?(label)
      return false unless label.to_s =~ /battle|pokedex|evol/i
      return false if @forced_input_press_attempts.to_i < 10
      forced_prompt_elapsed_seconds > 1.4
    rescue
      false
    end

    def forced_prompt_elapsed_seconds
      return 0.0 unless @forced_input_started_at
      current_time_seconds - @forced_input_started_at.to_f
    rescue
      0.0
    end

    def throttled_prompt_status(text)
      now = current_time_seconds
      return if @last_prompt_status_text == text && @last_prompt_status_at &&
                now - @last_prompt_status_at.to_f < 0.6
      @last_prompt_status_text = text
      @last_prompt_status_at = now
      AutoplayBot.status(text)
    rescue
      nil
    end

    def human_confirm_input_active?
      return false unless defined?(Input)
      [:USE, :BACK].any? do |name|
        next false unless Input.const_defined?(name)
        button = Input.const_get(name)
        if Input.respond_to?(:autoplay_bot_original_press?)
          Input.autoplay_bot_original_press?(button) ||
            (Input.respond_to?(:autoplay_bot_original_trigger?) && Input.autoplay_bot_original_trigger?(button))
        else
          Input.press?(button) || Input.trigger?(button)
        end
      end
    rescue
      false
    end

    def game_speed_multiplier
      speed = defined?($GameSpeed) ? $GameSpeed.to_i : 1
      [[speed, 1].max, 20].min
    rescue
      1
    end

    def observe_game_speed!
      speed = game_speed_multiplier
      now = current_time_seconds
      frame = (Graphics.frame_count rescue 0).to_i
      if @last_observed_game_speed.nil?
        @last_observed_game_speed = speed
        @last_speed_change_at = now
        @last_speed_change_frame = frame
        return speed
      end
      return speed if @last_observed_game_speed.to_i == speed.to_i

      old_speed = @last_observed_game_speed.to_i
      @last_observed_game_speed = speed
      @last_speed_change_at = now
      @last_speed_change_frame = frame
      @last_runtime_tick_at = nil
      clear_static_coast_input!
      if AutoplayBot.respond_to?(:log)
        AutoplayBot.log("speed changed x#{old_speed} -> x#{speed}; adapting bot timers")
      end
      AutoplayBot.status("speed x#{speed}: adapting") if running? && AutoplayBot.respond_to?(:status)
      speed
    rescue
      1
    end

    def speed_recently_changed?(seconds = 0.30)
      return false unless @last_speed_change_at
      current_time_seconds - @last_speed_change_at.to_f < seconds.to_f
    rescue
      false
    end

    def frameskip_speed_guard?
      false
    rescue
      false
    end

    def critical_speed_context?
      now = current_time_seconds
      return true if @battle_context_active
      return true if raw_battle_flag_active?
      return true if real_battle_scene?
      return true if @battle_message_context_depth.to_i > 0
      return true if @top_right_window_depth.to_i > 0
      return true if capture_storage_active?
      return true if post_capture_confirm_active?
      return true if battle_ability_splash_active?
      return true if forced_input_context? && battle_prompt_label?(@forced_input_label)
      return true if @post_battle_resume_until_at &&
                     now <= @post_battle_resume_until_at.to_f
      return true if @battle_engine_active && @battle_engine_last_seen_at &&
                     now - @battle_engine_last_seen_at.to_f < 18.0
      return true if hard_scene_transition_busy? && battle_transition_related?
      return true if menu_context_active? && bot_menu_pending_action
      false
    rescue
      false
    end

    def frameskip_guard_reason
      return "battle intro" if battle_intro_speed_guard?
      return "battle scene" if real_battle_scene?
      return "battle flag" if raw_battle_flag_active?
      return "battle prompt" if forced_input_context? && battle_prompt_label?(@forced_input_label)
      return "capture/storage" if capture_storage_active?
      return "menu action" if menu_context_active? && bot_menu_pending_action
      return "transition" if hard_scene_transition_busy?
      "critical"
    rescue
      "critical"
    end

    def note_frameskip_guard!(speed)
      speed = speed.to_i
      return if speed <= 1
      @frameskip_guard_last_speed = speed
      now = current_time_seconds
      return if @last_frameskip_guard_log_at &&
                now - @last_frameskip_guard_log_at.to_f < 6.0
      @last_frameskip_guard_log_at = now
      reason = frameskip_guard_reason
      AutoplayBot.log("speed x#{speed} observed during #{reason}") if AutoplayBot.respond_to?(:log)
    rescue
      nil
    end

    def current_time_seconds
      Time.now.to_f
    rescue
      0.0
    end

    def clear_forced_prompt_state!
      @forced_input_clear_generation = @forced_input_clear_generation.to_i + 1
      @forced_input_context = false
      @forced_input_label = nil
      @forced_input_started_at = nil
      @forced_input_started_frame = nil
      @forced_input_press_attempts = 0
      @forced_input_escape_presses = 0
      @last_forced_prompt_time = nil
      @last_forced_prompt_frame = nil
      @last_dialog_time = nil
      @last_dialog_frame = nil
      @last_battle_dialog_update_pulse_at = nil
      @last_direct_battle_dialog_trigger_frame = nil
      @last_direct_battle_dialog_trigger_at = nil
      @last_prompt_status_text = nil
      @last_prompt_status_at = nil
      @top_right_window_depth = 0 unless @top_right_window_depth.to_i > 0
    rescue
      nil
    end

    def menu_idle_watchdog_tick
      return unless defined?(AutoplayBot::Config) && AutoplayBot::Config.menu_idle_escape?
      return if forced_input_context? || human_override_active?
      if stale_map_menu_flag_context?
        stale_map_menu_watchdog_tick
        return
      end
      return if @menu_escape_cooldown_until_at && current_time_seconds < @menu_escape_cooldown_until_at.to_f
      unless menu_context_active?
        note_menu_context_clear!
        return
      end
      if menu_prompt_active?
        note_menu_context_clear!
        return
      end
      frame = (Graphics.frame_count rescue 0).to_i
      key = menu_context_key
      if @menu_idle_key != key
        @menu_idle_key = key
        @menu_idle_started_frame = frame
        @menu_idle_started_at = current_time_seconds
        @menu_idle_escape_attempts = 0
        @last_menu_escape_frame = -9999
        @last_menu_escape_at = 0.0
        return
      end
      elapsed = frame - @menu_idle_started_frame.to_i
      elapsed_seconds = current_time_seconds - @menu_idle_started_at.to_f
      timeout = menu_idle_timeout_frames
      timeout_seconds = menu_idle_timeout_seconds
      return if elapsed < timeout && elapsed_seconds < timeout_seconds
      return if frame - @last_menu_escape_frame.to_i < 24 &&
                current_time_seconds - @last_menu_escape_at.to_f < menu_escape_interval_seconds
      @last_menu_escape_frame = frame
      @last_menu_escape_at = current_time_seconds
      @menu_idle_escape_attempts = @menu_idle_escape_attempts.to_i + 1
      AutoplayBot::MenuTools.clear! if defined?(AutoplayBot::MenuTools) && AutoplayBot::MenuTools.respond_to?(:clear!)
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      if defined?(AutoplayBot::InputQueue)
        frames = @menu_idle_escape_attempts.to_i >= 3 ? 4 : 2
        AutoplayBot::InputQueue.tap(:BACK, frames)
        AutoplayBot::InputQueue.tap_next(:BACK, frames) if AutoplayBot::InputQueue.respond_to?(:tap_next)
      end
      AutoplayBot.status("menu: escape #{@menu_idle_escape_attempts}")
      record_menu_escape!(key) if @menu_idle_escape_attempts == 1 || (@menu_idle_escape_attempts % 4).zero?
    rescue => e
      AutoplayBot.log("menu watchdog failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def menu_idle_timeout_seconds
      return game_speed_multiplier >= 7 ? 1.1 : 1.5 unless bot_menu_pending_action
      return 0.75 if cosmetic_menu_context?
      if defined?(AutoplayBot::MenuTools) &&
         AutoplayBot::MenuTools.respond_to?(:pending_age_seconds) &&
         AutoplayBot::MenuTools.pending_age_seconds.to_f > 1.4
        return 0.45
      end
      game_speed_multiplier >= 7 ? 1.1 : 1.6
    rescue
      1.0
    end

    def menu_escape_interval_seconds
      return game_speed_multiplier >= 7 ? 0.45 : 0.65 unless bot_menu_pending_action
      game_speed_multiplier >= 7 ? 0.14 : 0.22
    rescue
      0.22
    end

    def bot_menu_pending_action
      return nil unless defined?(AutoplayBot::MenuTools) &&
                        AutoplayBot::MenuTools.respond_to?(:pending_action)
      AutoplayBot::MenuTools.pending_action
    rescue
      nil
    end

    def pause_menu_action_tick
      return if forced_input_context? || human_override_active?
      return unless menu_context_active?
      return unless defined?(AutoplayBot::MenuTools) &&
                    AutoplayBot::MenuTools.respond_to?(:pending_action) &&
                    AutoplayBot::MenuTools.pending_action
      scene_name = defined?($scene) && $scene ? $scene.class.to_s : ""
      if AutoplayBot::MenuTools.respond_to?(:complete_opened_scene_action_if_ready!) &&
         AutoplayBot::MenuTools.complete_opened_scene_action_if_ready!(scene_name)
        return
      end
      return if menu_prompt_active?
      return unless AutoplayBot::MenuTools.respond_to?(:drive_open_pause_menu!)
      AutoplayBot::MenuTools.drive_open_pause_menu!
    rescue => e
      AutoplayBot.log("pause menu action tick failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def menu_context_active?
      return false if defined?($game_temp) && $game_temp && $game_temp.in_battle
      return false if map_menu_flag_ignored?
      return false if stale_map_menu_flag_context?
      return true if defined?($game_temp) && $game_temp && $game_temp.in_menu
      scene_name = defined?($scene) && $scene ? $scene.class.to_s : ""
      scene_name =~ /Menu|Storage|Bag|Party|Summary|Pokedex|Pok[eé]mon|Mart|Tutor|Option|Save|PC|Hair|Cloth|Outfit|Wardrobe|Boutique|Fashion/i
    rescue
      false
    end

    def cosmetic_menu_context?
      scene_name = defined?($scene) && $scene ? $scene.class.to_s : ""
      scene_name =~ /Hair|Cloth|Outfit|Wardrobe|Boutique|Fashion/i
    rescue
      false
    end

    def menu_idle_timeout_frames
      return 90 if cosmetic_menu_context?
      if defined?(AutoplayBot::MenuTools) &&
         AutoplayBot::MenuTools.respond_to?(:pending_action) &&
         AutoplayBot::MenuTools.pending_action &&
         AutoplayBot::MenuTools.respond_to?(:pending_stale?) &&
         AutoplayBot::MenuTools.pending_stale?(180)
        return 90
      end
      configured = AutoplayBot::Config.menu_idle_escape_frames rescue 600
      [[configured.to_i, 300].min, 120].max
    rescue
      300
    end

    def menu_prompt_active?
      return true if defined?($game_temp) && $game_temp && $game_temp.message_window_showing
      return true if defined?($game_temp) && $game_temp && ($game_temp.player_transferring || $game_temp.transition_processing || $game_temp.to_title)
      if defined?(AutoplayBot::MenuTools) &&
         AutoplayBot::MenuTools.respond_to?(:pending_action) &&
         AutoplayBot::MenuTools.pending_action
        stale = AutoplayBot::MenuTools.respond_to?(:pending_stale?) && AutoplayBot::MenuTools.pending_stale?(240)
        menu_age = AutoplayBot::MenuTools.respond_to?(:pending_age) ? AutoplayBot::MenuTools.pending_age.to_i : 0
        return false if menu_age >= 45
        return true unless stale
      end
      false
    rescue
      false
    end

    def stale_map_menu_watchdog_tick
      unless stale_map_menu_flag_context?
        clear_stale_map_menu_watchdog!
        return
      end
      now = current_time_seconds
      key = stale_map_menu_key
      if @stale_map_menu_key != key
        @stale_map_menu_key = key
        @stale_map_menu_started_at = now
        @stale_map_menu_logged = false
        return
      end
      elapsed = now - (@stale_map_menu_started_at || now).to_f
      return if elapsed < stale_map_menu_clear_seconds
      return if @last_stale_map_menu_clear_at &&
                now - @last_stale_map_menu_clear_at.to_f < stale_map_menu_reclear_cooldown_seconds

      @last_stale_map_menu_clear_at = now
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      AutoplayBot::MenuTools.clear! if defined?(AutoplayBot::MenuTools) && AutoplayBot::MenuTools.respond_to?(:clear!)
      if defined?($game_temp) && $game_temp && $game_temp.respond_to?(:in_menu=)
        $game_temp.in_menu = false
      end
      @stale_map_menu_ignore_until_at = now + stale_map_menu_ignore_seconds
      @last_runtime_tick_at = nil
      @menu_escape_cooldown_until_at = now + menu_clear_cooldown_seconds
      clear_menu_idle_watchdog!
      clear_stale_map_menu_watchdog!
      AutoplayBot.status("menu: stale map flag cleared")
      AutoplayBot.log("cleared stale Scene_Map menu flag at #{map_position_for_log}") if AutoplayBot.respond_to?(:log)
      AutoplayBot::Overlay.update(true) if defined?(AutoplayBot::Overlay)
    rescue => e
      clear_stale_map_menu_watchdog!
      AutoplayBot.log("stale map menu watchdog failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def stale_map_menu_flag_context?
      return false unless defined?($game_temp) && $game_temp && $game_temp.in_menu
      return false if map_menu_flag_ignored?
      return false unless defined?($scene) && defined?(Scene_Map) && $scene.is_a?(Scene_Map)
      return false if bot_menu_pending_action
      return false if forced_input_context? || battle_context?
      return false if $game_temp.message_window_showing
      return false if $game_temp.player_transferring || $game_temp.transition_processing || $game_temp.to_title
      true
    rescue
      false
    end

    def map_menu_flag_ignored?
      return false unless @stale_map_menu_ignore_until_at
      return false if current_time_seconds >= @stale_map_menu_ignore_until_at.to_f
      return false unless defined?($game_temp) && $game_temp && $game_temp.in_menu
      return false unless defined?($scene) && defined?(Scene_Map) && $scene.is_a?(Scene_Map)
      return false if bot_menu_pending_action
      return false if forced_input_context? || battle_context?
      return false if $game_temp.message_window_showing
      return false if $game_temp.player_transferring || $game_temp.transition_processing || $game_temp.to_title
      true
    rescue
      false
    end

    def stale_map_menu_key
      map_id = defined?($game_map) && $game_map ? $game_map.map_id : nil
      x = defined?($game_player) && $game_player ? $game_player.x : nil
      y = defined?($game_player) && $game_player ? $game_player.y : nil
      [map_id, x, y]
    rescue
      ["unknown"]
    end

    def stale_map_menu_clear_seconds
      game_speed_multiplier >= 7 ? 0.75 : 1.25
    rescue
      1.0
    end

    def stale_map_menu_reclear_cooldown_seconds
      game_speed_multiplier >= 7 ? 1.5 : 2.0
    rescue
      2.0
    end

    def stale_map_menu_ignore_seconds
      game_speed_multiplier >= 7 ? 4.0 : 5.0
    rescue
      4.0
    end

    def clear_stale_map_menu_watchdog!
      @stale_map_menu_key = nil
      @stale_map_menu_started_at = nil
      @stale_map_menu_logged = false
    rescue
      nil
    end

    def menu_context_key
      scene_name = defined?($scene) && $scene ? $scene.class.to_s : "unknown"
      in_menu = defined?($game_temp) && $game_temp && $game_temp.in_menu ? "menu" : "scene"
      "#{scene_name}:#{in_menu}"
    rescue
      "menu"
    end

    def record_menu_escape!(key)
      reason = "idle menu escape #{key}"
      AutoplayBot.log(reason) if AutoplayBot.respond_to?(:log)
      if state_loaded? && AutoplayBot::State.respond_to?(:record_failure_event)
        AutoplayBot::State.record_failure_event(reason, "source" => "menu_idle_watchdog", "attempts" => @menu_idle_escape_attempts)
      end
    rescue
      nil
    end

    def note_menu_context_clear!
      if @menu_idle_key && @menu_idle_escape_attempts.to_i > 0
        AutoplayBot.log("menu idle cleared #{@menu_idle_key} after #{@menu_idle_escape_attempts} escapes") if AutoplayBot.respond_to?(:log)
        @menu_escape_cooldown_until_at = current_time_seconds + menu_clear_cooldown_seconds
      end
      clear_menu_idle_watchdog!
    rescue
      clear_menu_idle_watchdog!
    end

    def menu_clear_cooldown_seconds
      game_speed_multiplier >= 7 ? 0.85 : 1.1
    rescue
      1.0
    end

    def clear_menu_idle_watchdog!
      @menu_idle_key = nil
      @menu_idle_started_frame = nil
      @menu_idle_started_at = nil
      @menu_idle_escape_attempts = 0
      @last_menu_escape_frame = nil
      @last_menu_escape_at = nil
    rescue
      nil
    end

    def battle_context_guard!(active = battle_context?)
      frame = (Graphics.frame_count rescue 0).to_i
      if active
        unless @battle_context_active
          @battle_context_active = true
          @battle_context_started_frame = frame
          @battle_context_started_at = current_time_seconds
          @battle_context_seen_real_scene = real_battle_scene?
          @battle_real_scene_seen_at = @battle_context_seen_real_scene ? current_time_seconds : nil
          @last_battle_context_end_at = nil
          @post_battle_resume_until_at = nil
          @post_battle_map_seen_at = nil
          @battle_map_idle_seen_at = nil
          @battle_engine_end_seen_at = nil
          @battle_transition_clear_until_frame = frame + 24
          enter_battle_intro_speed_lock!("battle start")
          @last_battle_context_status_frame = -9999
          @battle_idle_started_frame = frame
          @last_battle_takeover_frame = frame
          @battle_takeover_sequence = nil
          AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
          AutoplayBot::MenuTools.clear! if defined?(AutoplayBot::MenuTools) && AutoplayBot::MenuTools.respond_to?(:clear!)
          AutoplayBot::Overlay.dispose if defined?(AutoplayBot::Overlay)
          if defined?(AutoplayBot::Director) &&
             AutoplayBot::Director.respond_to?(:note_battle_context_start!)
            AutoplayBot::Director.note_battle_context_start!
          end
          AutoplayBot.status("battle: starting")
          AutoplayBot.log("battle context start") if AutoplayBot.respond_to?(:log)
        end
        if real_battle_scene?
          @battle_context_seen_real_scene = true
          @battle_real_scene_seen_at ||= current_time_seconds
          release_battle_intro_speed_lock!("battle scene")
        end
        if frame - @last_battle_context_status_frame.to_i >= 90
          @last_battle_context_status_frame = frame
          AutoplayBot.status("battle: waiting") unless forced_input_context?
        end
        if frame <= @battle_transition_clear_until_frame.to_i
          AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
        end
        return
      end

      return unless @battle_context_active
      @battle_context_active = false
      @battle_context_started_frame = nil
      @battle_context_started_at = nil
      @battle_context_seen_real_scene = false
      @battle_real_scene_seen_at = nil
      @battle_map_idle_seen_at = nil
      @post_battle_map_seen_at = nil
      ended_at = current_time_seconds
      @last_battle_context_end_at = ended_at
      @post_battle_resume_until_at = ended_at + 3.0
      @map_battle_flag_seen_at = nil
      @battle_transition_clear_until_frame = nil
      @last_battle_context_status_frame = nil
      @last_runtime_tick_at = nil
      release_battle_intro_speed_lock!("battle end")
      clear_battle_idle_watchdog!
      clear_forced_prompt_state! if battle_prompt_context? && map_free_for_reroute?
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      if defined?(AutoplayBot::Director) &&
         AutoplayBot::Director.respond_to?(:note_battle_context_end!)
        AutoplayBot::Director.note_battle_context_end!
      end
      AutoplayBot.status("battle: finished")
      AutoplayBot.log("battle context end") if AutoplayBot.respond_to?(:log)
      AutoplayBot::Overlay.update(true) if defined?(AutoplayBot::Overlay)
    rescue => e
      AutoplayBot.log("battle context guard failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def clear_battle_context_guard!
      @battle_context_active = false
      @battle_context_started_frame = nil
      @battle_context_started_at = nil
      @battle_context_seen_real_scene = false
      @battle_real_scene_seen_at = nil
      @post_battle_map_seen_at = nil
      @battle_map_idle_seen_at = nil
      @battle_engine_end_seen_at = nil
      @map_battle_flag_seen_at = nil
      @battle_transition_clear_until_frame = nil
      @last_battle_context_status_frame = nil
      @last_battle_confirm_pulse_at = nil
      @battle_confirm_pulse_count = 0
      release_battle_intro_speed_lock!("clear battle guard")
      clear_battle_transition_watchdog!
    rescue
      nil
    end

    def battle_intro_speed_lock_tick
      if battle_intro_limbo_surface? || battle_intro_raw_startup_pending?
        enter_battle_intro_speed_lock!("battle intro")
      elsif @battle_intro_speed_locked
        release_battle_intro_speed_lock!("intro complete")
      end
    rescue
      nil
    end

    def enter_battle_intro_speed_lock!(reason = "battle intro")
      speed = game_speed_multiplier
      @battle_intro_speed_lock_started_at ||= current_time_seconds
      @battle_intro_speed_lock_reason = reason.to_s
      if !@battle_intro_speed_locked
        @battle_intro_observed_speed = speed > 0 ? speed : 1
        @battle_intro_speed_locked = true
        AutoplayBot.log("battle intro speed observe x#{@battle_intro_observed_speed} #{reason}") if AutoplayBot.respond_to?(:log)
      end
      @battle_intro_speed_lock_until_at = current_time_seconds + battle_intro_speed_lock_seconds
    rescue
      nil
    end

    def release_battle_intro_speed_lock!(reason = "battle intro done")
      return unless @battle_intro_speed_locked
      AutoplayBot.log("battle intro speed observe released #{reason}") if AutoplayBot.respond_to?(:log)
      @battle_intro_speed_locked = false
      @battle_intro_observed_speed = nil
      @battle_intro_speed_lock_started_at = nil
      @battle_intro_speed_lock_until_at = nil
      @battle_intro_speed_lock_reason = nil
    rescue
      @battle_intro_speed_locked = false
    end

    def battle_intro_speed_lock_active?
      return false unless @battle_intro_speed_locked
      return false unless running?
      return false if real_battle_scene?
      return false unless battle_intro_limbo_surface? || battle_intro_raw_startup_pending?
      if @battle_intro_speed_lock_until_at &&
         current_time_seconds > @battle_intro_speed_lock_until_at.to_f
        enter_battle_intro_speed_lock!("battle intro still pending")
      end
      true
    rescue
      false
    end

    def battle_intro_speed_lock_seconds
      8.0
    rescue
      8.0
    end

    def soft_recover_battle_intro_transition!(reason)
      enter_battle_intro_speed_lock!(reason)
      now = current_time_seconds
      if !@last_battle_intro_soft_recover_at ||
         now - @last_battle_intro_soft_recover_at.to_f >= 1.5
        @last_battle_intro_soft_recover_at = now
        queue_confirm_press(prompt_hold_frames) if respond_to?(:queue_confirm_press)
        begin
          Graphics.frame_reset if defined?(Graphics) && Graphics.respond_to?(:frame_reset)
        rescue
          nil
        end
        AutoplayBot.status("battle: intro wait x1") if AutoplayBot.respond_to?(:status)
        AutoplayBot.log("soft battle intro wait #{reason} at #{map_position_for_log}") if AutoplayBot.respond_to?(:log)
      end
      clear_battle_transition_watchdog!
      true
    rescue => e
      AutoplayBot.log("soft battle intro recovery failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def battle_transition_watchdog_tick
      unless battle_transition_watchdog_active?
        clear_battle_transition_watchdog!
        return
      end
      now = current_time_seconds
      key = battle_transition_watchdog_key
      if @battle_transition_watchdog_key != key
        @battle_transition_watchdog_key = key
        @battle_transition_watchdog_started_at = battle_intro_limbo_surface? ? (@battle_context_started_at || @map_battle_flag_seen_at || now) : now
        @battle_transition_watchdog_logged = false
        @last_battle_transition_pulse_at = 0.0
        return
      end

      started = @battle_transition_watchdog_started_at || now
      elapsed = now - started.to_f
      if elapsed >= battle_transition_watchdog_pulse_seconds
        pulse_stuck_battle_transition(now, elapsed)
      end
      clear_after = battle_intro_limbo_surface? ? battle_intro_limbo_clear_seconds : battle_transition_watchdog_clear_seconds
      return if elapsed < clear_after
      return unless battle_transition_recoverable_surface?
      if battle_startup_transition_protected?
        soft_recover_battle_intro_transition!("battle transition #{elapsed.round(1)}s")
        return
      end

      log_battle_transition_watchdog(elapsed)
      recover_stuck_battle_transition!("battle transition timeout")
    rescue => e
      AutoplayBot.log("battle transition watchdog failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      clear_battle_transition_watchdog!
    end

    def battle_transition_watchdog_active?
      return false if human_override_active?
      return false if capture_storage_active?
      return false if defined?($scene) && $scene && $scene.class.to_s =~ /Battle/
      return false unless battle_transition_related?
      now = current_time_seconds
      if hard_scene_transition_busy?
        @battle_transition_recently_busy_at = now
        return true
      end
      if battle_intro_limbo_surface?
        started = @battle_context_started_at || @map_battle_flag_seen_at || @battle_engine_last_seen_at || now
        return true if now - started.to_f >= battle_transition_watchdog_pulse_seconds
      end
      return true if @battle_transition_recently_busy_at &&
                     now - @battle_transition_recently_busy_at.to_f < 1.25 &&
                     !map_controls_ready?
      return true if @battle_context_active &&
                     @battle_context_started_at &&
                     now - @battle_context_started_at.to_f >= battle_transition_watchdog_pulse_seconds &&
                     !map_scene_ready?
      false
    rescue
      false
    end

    def battle_transition_related?
      now = current_time_seconds
      return true if raw_battle_flag_active?
      return true if @battle_context_active
      return true if battle_prompt_context?
      return true if director_runtime_mode_battle?
      return true if @post_battle_resume_until_at &&
                     now <= @post_battle_resume_until_at.to_f + 3.0
      return true if @battle_engine_last_seen_at &&
                     now - @battle_engine_last_seen_at.to_f < 8.0
      return true if @last_battle_context_end_at &&
                     now - @last_battle_context_end_at.to_f < 12.0
      false
    rescue
      false
    end

    def battle_transition_watchdog_key
      scene_name = defined?($scene) && $scene ? $scene.class.to_s : "none"
      map_id = defined?($game_map) && $game_map ? $game_map.map_id : nil
      x = defined?($game_player) && $game_player ? $game_player.x : nil
      y = defined?($game_player) && $game_player ? $game_player.y : nil
      # Keep this key stable through transition flag flicker.  Speed-up mode can
      # toggle miniupdate/transition flags while the visual fade is still black;
      # including those flags here resets the watchdog forever.
      [scene_name, map_id, x, y, safe_bool(raw_battle_flag_active?)]
    rescue
      ["unknown"]
    end

    def battle_intro_limbo_surface?
      return false if real_battle_scene?
      return false if post_battle_overworld_resume?
      return false unless live_overworld_surface?
      return false unless raw_battle_flag_active?
      return false if @battle_context_seen_real_scene
      if defined?($game_temp) && $game_temp
        return false if $game_temp.in_menu && !map_menu_flag_ignored?
        return false if $game_temp.message_window_showing
        return false if $game_temp.player_transferring || $game_temp.to_title
      end
      true
    rescue
      false
    end

    def battle_startup_transition_protected?
      return false unless running?
      return true if battle_intro_limbo_surface?
      return true if battle_intro_raw_startup_pending?
      return true if @battle_intro_speed_locked && battle_intro_raw_startup_pending?
      false
    rescue
      false
    end

    def battle_intro_raw_startup_pending?
      return false unless running?
      return false if real_battle_scene?
      return false if @battle_context_seen_real_scene
      return false if post_battle_overworld_resume?
      return false unless raw_battle_flag_active?
      started = @battle_context_started_at || @map_battle_flag_seen_at || @battle_engine_last_seen_at
      return false unless started
      current_time_seconds - started.to_f <= battle_intro_protect_seconds
    rescue
      false
    end

    def battle_intro_protect_seconds
      240.0
    rescue
      240.0
    end

    def pulse_stuck_battle_transition(now, elapsed)
      return if @last_battle_transition_pulse_at &&
                now - @last_battle_transition_pulse_at.to_f < battle_transition_pulse_interval_seconds
      @last_battle_transition_pulse_at = now
      frames = prompt_hold_frames
      if defined?(AutoplayBot::InputQueue)
        AutoplayBot::InputQueue.tap(:USE, frames)
        AutoplayBot::InputQueue.tap_next(:USE, frames) if AutoplayBot::InputQueue.respond_to?(:tap_next)
      end
      AutoplayBot.status("battle: transition #{elapsed.round(1)}s")
    rescue
      nil
    end

    def battle_transition_recoverable_surface?
      return false if capture_storage_active?
      return true if battle_startup_transition_protected?
      return true if battle_intro_limbo_surface?
      return false if defined?($scene) && $scene && $scene.class.to_s =~ /Battle|Title|Intro|Load|Save/
      return false if defined?($game_temp) && $game_temp && $game_temp.to_title
      live_overworld_surface?
    rescue
      false
    end

    def recover_stuck_battle_transition!(reason)
      return soft_recover_battle_intro_transition!(reason) if battle_startup_transition_protected?
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      clear_forced_prompt_state!
      begin
        Graphics.transition(0) if defined?(Graphics) && Graphics.respond_to?(:transition)
        Graphics.frame_reset if defined?(Graphics) && Graphics.respond_to?(:frame_reset)
      rescue
        nil
      end
      if defined?($game_temp) && $game_temp
        $game_temp.in_battle = false if $game_temp.respond_to?(:in_battle=)
        $game_temp.transition_processing = false if $game_temp.respond_to?(:transition_processing=)
      end
      if defined?($PokemonSystem) && $PokemonSystem &&
         $PokemonSystem.respond_to?(:is_in_battle=)
        $PokemonSystem.is_in_battle = false
      end
      if defined?($PokemonTemp) && $PokemonTemp &&
         $PokemonTemp.respond_to?(:miniupdate=)
        $PokemonTemp.miniupdate = false
      end
      @battle_engine_active = false
      @battle_engine_reason = nil
      @battle_message_context_depth = 0
      @battle_context_active = false
      @battle_context_started_frame = nil
      @battle_context_started_at = nil
      @battle_context_seen_real_scene = false
      @post_battle_map_seen_at = nil
      @map_battle_flag_seen_at = nil
      @battle_transition_clear_until_frame = nil
      @last_battle_context_end_at = current_time_seconds
      @post_battle_resume_until_at = current_time_seconds + 1.5
      @last_battle_transition_recovered_at = current_time_seconds
      @last_runtime_tick_at = nil
      clear_battle_idle_watchdog!
      clear_map_battle_sweeper!
      clear_battle_transition_watchdog!
      if defined?(AutoplayBot::Director) &&
         AutoplayBot::Director.respond_to?(:note_battle_context_end!)
        AutoplayBot::Director.note_battle_context_end!
      end
      AutoplayBot.status("battle: recovered transition")
      AutoplayBot.log("recovered #{reason} at #{map_position_for_log}") if AutoplayBot.respond_to?(:log)
      AutoplayBot::Overlay.update(true) if defined?(AutoplayBot::Overlay)
      true
    rescue => e
      AutoplayBot.log("recover battle transition failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def battle_transition_watchdog_pulse_seconds
      game_speed_multiplier >= 7 ? 1.2 : 2.0
    rescue
      2.0
    end

    def battle_transition_watchdog_clear_seconds
      game_speed_multiplier >= 7 ? 5.5 : 9.0
    rescue
      9.0
    end

    def battle_intro_limbo_clear_seconds
      speed = game_speed_multiplier
      return 12.0 if speed >= 7
      return 13.5 if speed >= 3
      15.0
    rescue
      13.5
    end

    def battle_intro_speed_guard?
      enabled? && running? && (battle_intro_limbo_surface? || battle_intro_speed_lock_active?)
    rescue
      false
    end

    def battle_intro_transition_cap_frames
      12
    rescue
      12
    end

    def battle_transition_pulse_interval_seconds
      game_speed_multiplier >= 7 ? 0.35 : 0.55
    rescue
      0.55
    end

    def log_battle_transition_watchdog(elapsed)
      return if @battle_transition_watchdog_logged
      @battle_transition_watchdog_logged = true
      bits = []
      if defined?($game_temp) && $game_temp
        bits << "battle=#{safe_bool($game_temp.in_battle)}"
        bits << "xfer=#{safe_bool($game_temp.player_transferring)}"
        bits << "trans=#{safe_bool($game_temp.transition_processing)}"
      end
      bits << "mini=#{safe_bool($PokemonTemp.miniupdate)}" if defined?($PokemonTemp) && $PokemonTemp.respond_to?(:miniupdate)
      bits << "scene=#{defined?($scene) && $scene ? $scene.class : "none"}"
      AutoplayBot.log("battle transition stuck #{elapsed.round(1)}s #{bits.join(' ')} at #{map_position_for_log}") if AutoplayBot.respond_to?(:log)
    rescue
      nil
    end

    def clear_battle_transition_watchdog!
      @battle_transition_watchdog_key = nil
      @battle_transition_watchdog_started_at = nil
      @last_battle_transition_pulse_at = nil
      @battle_transition_watchdog_logged = false
      @battle_transition_recently_busy_at = nil
    rescue
      nil
    end

    def black_transition_watchdog_tick
      unless black_transition_watchdog_active?
        clear_black_transition_watchdog!
        return
      end

      now = current_time_seconds
      key = black_transition_watchdog_key
      if @black_transition_watchdog_key != key
        @black_transition_watchdog_key = key
        @black_transition_watchdog_started_at = now
        @black_transition_watchdog_logged = false
        @last_black_transition_pulse_at = 0.0
        return
      end

      started = @black_transition_watchdog_started_at || now
      elapsed = now - started.to_f
      pulse_black_transition(now, elapsed) if elapsed >= black_transition_pulse_seconds
      return if elapsed < black_transition_clear_seconds
      return unless black_transition_recoverable_surface?
      if battle_startup_transition_protected?
        soft_recover_battle_intro_transition!("black transition #{elapsed.round(1)}s")
        return
      end

      recover_stuck_black_transition!("black transition timeout #{elapsed.round(1)}s")
    rescue => e
      clear_black_transition_watchdog!
      AutoplayBot.log("black transition watchdog failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def black_transition_watchdog_active?
      return false unless running?
      return false if human_override_active?
      return false if capture_storage_active?
      return false if defined?($scene) && $scene && $scene.class.to_s =~ /Title|Intro|Load|Save/
      return false if real_battle_scene?
      return false if defined?($game_temp) && $game_temp &&
                      (($game_temp.in_menu && !map_menu_flag_ignored?) ||
                       $game_temp.message_window_showing || $game_temp.to_title)
      return true if hard_scene_transition_busy?
      return true if post_capture_confirm_active? && battle_transition_related?
      return true if battle_transition_related? && live_overworld_surface? && !map_controls_ready?
      false
    rescue
      false
    end

    def black_transition_watchdog_key
      scene_name = defined?($scene) && $scene ? $scene.class.to_s : "none"
      map_id = defined?($game_map) && $game_map ? $game_map.map_id : nil
      x = defined?($game_player) && $game_player ? $game_player.x : nil
      y = defined?($game_player) && $game_player ? $game_player.y : nil
      flags = []
      if defined?($game_temp) && $game_temp
        flags << safe_bool($game_temp.player_transferring)
        flags << safe_bool($game_temp.transition_processing)
        flags << safe_bool($game_temp.in_battle)
      end
      flags << safe_bool($PokemonTemp.miniupdate) if defined?($PokemonTemp) && $PokemonTemp.respond_to?(:miniupdate)
      [scene_name, map_id, x, y, flags.join("")]
    rescue
      ["unknown"]
    end

    def pulse_black_transition(now, elapsed)
      return if @last_black_transition_pulse_at &&
                now - @last_black_transition_pulse_at.to_f < black_transition_pulse_interval_seconds
      @last_black_transition_pulse_at = now
      queue_confirm_press(prompt_hold_frames) if respond_to?(:queue_confirm_press)
      AutoplayBot.status("transition: black #{elapsed.round(1)}s")
    rescue
      nil
    end

    def black_transition_recoverable_surface?
      return false if capture_storage_active?
      return true if battle_startup_transition_protected?
      return false if defined?($scene) && $scene && $scene.class.to_s =~ /Battle|Title|Intro|Load|Save/
      return false if defined?($game_temp) && $game_temp &&
                      (($game_temp.in_menu && !map_menu_flag_ignored?) ||
                       $game_temp.message_window_showing || $game_temp.to_title)
      return true if live_overworld_surface?
      return true if defined?($game_map) && $game_map && defined?($game_player) && $game_player
      false
    rescue
      false
    end

    def recover_stuck_black_transition!(reason)
      return soft_recover_battle_intro_transition!(reason) if battle_startup_transition_protected?
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      begin
        Graphics.transition(0) if defined?(Graphics) && Graphics.respond_to?(:transition)
        Graphics.frame_reset if defined?(Graphics) && Graphics.respond_to?(:frame_reset)
      rescue
        nil
      end
      if defined?($game_temp) && $game_temp
        $game_temp.transition_processing = false if $game_temp.respond_to?(:transition_processing=)
        $game_temp.player_transferring = false if $game_temp.respond_to?(:player_transferring=)
      end
      if defined?($PokemonTemp) && $PokemonTemp &&
         $PokemonTemp.respond_to?(:miniupdate=)
        $PokemonTemp.miniupdate = false
      end
      if battle_transition_related? || raw_battle_flag_active?
        clear_stale_battle_flags!("black transition") if respond_to?(:clear_stale_battle_flags!)
      else
        @last_runtime_tick_at = nil
        @post_battle_resume_until_at = current_time_seconds + 1.0
      end
      clear_black_transition_watchdog!
      AutoplayBot.status("transition: recovered")
      AutoplayBot.log("recovered #{reason} at #{map_position_for_log}") if AutoplayBot.respond_to?(:log)
      AutoplayBot::Overlay.update(true) if defined?(AutoplayBot::Overlay)
      true
    rescue => e
      clear_black_transition_watchdog!
      AutoplayBot.log("black transition recovery failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def black_transition_pulse_seconds
      game_speed_multiplier >= 7 ? 1.5 : 2.2
    rescue
      2.2
    end

    def black_transition_clear_seconds
      game_speed_multiplier >= 7 ? 6.0 : 8.0
    rescue
      8.0
    end

    def black_transition_pulse_interval_seconds
      game_speed_multiplier >= 7 ? 0.45 : 0.7
    rescue
      0.7
    end

    def clear_black_transition_watchdog!
      @black_transition_watchdog_key = nil
      @black_transition_watchdog_started_at = nil
      @black_transition_watchdog_logged = false
      @last_black_transition_pulse_at = nil
    rescue
      nil
    end

    def battle_transition_cooldown_active?(seconds = 2.5)
      now = current_time_seconds
      return true if raw_battle_flag_active?
      return true if @battle_context_active
      return true if @battle_engine_active &&
                     @battle_engine_last_seen_at &&
                     now - @battle_engine_last_seen_at.to_f < seconds.to_f
      return true if @last_battle_context_end_at &&
                     now - @last_battle_context_end_at.to_f < seconds.to_f
      return true if @post_battle_resume_until_at &&
                     now <= @post_battle_resume_until_at.to_f
      return true if @last_battle_transition_recovered_at &&
                     now - @last_battle_transition_recovered_at.to_f < seconds.to_f
      false
    rescue
      true
    end

    def battle_idle_watchdog_tick
      unless battle_context?
        clear_battle_idle_watchdog!
        return
      end
      return if forced_input_context? || human_override_active?
      return unless safe_input_context?
      frame = (Graphics.frame_count rescue 0).to_i
      now = current_time_seconds
      @battle_idle_started_frame ||= frame
      @battle_idle_started_at ||= now
      @last_battle_takeover_frame ||= -9999
      @last_battle_takeover_at ||= 0.0
      return if frame - @battle_idle_started_frame.to_i < 180 &&
                now - @battle_idle_started_at.to_f < 2.6

      if !@battle_takeover_sequence || @battle_takeover_sequence.empty?
        return if frame - @last_battle_takeover_frame.to_i < 90 &&
                  now - @last_battle_takeover_at.to_f < 1.2
        @battle_takeover_sequence = [:up, :left, :use]
        AutoplayBot.status("battle: resume menu")
      end

      return if frame - @last_battle_takeover_frame.to_i < 4 &&
                now - @last_battle_takeover_at.to_f < 0.08
      @last_battle_takeover_frame = frame
      @last_battle_takeover_at = now
      case @battle_takeover_sequence.shift
      when :up
        AutoplayBot::InputQueue.hold_dir(8, 2) if defined?(AutoplayBot::InputQueue)
      when :left
        AutoplayBot::InputQueue.hold_dir(4, 2) if defined?(AutoplayBot::InputQueue)
      when :use
        AutoplayBot::InputQueue.tap(:USE, 2) if defined?(AutoplayBot::InputQueue)
      end
    rescue => e
      AutoplayBot.log("battle watchdog failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      clear_battle_idle_watchdog!
    end

    def clear_battle_idle_watchdog!
      @battle_idle_started_frame = nil
      @battle_idle_started_at = nil
      @last_battle_takeover_frame = nil
      @last_battle_takeover_at = nil
      @battle_takeover_sequence = nil
      @last_battle_confirm_pulse_at = nil
      @last_direct_battle_dialog_trigger_frame = nil
      @battle_confirm_pulse_count = 0
      @last_battle_scene_idle_confirm_at = nil
      @battle_scene_idle_confirm_count = 0
      @post_capture_confirm_until_at = nil
    rescue
      nil
    end

    def note_battle_automation!
      frame = (Graphics.frame_count rescue 0).to_i
      @battle_idle_started_frame = frame
      @battle_idle_started_at = current_time_seconds
      @last_battle_takeover_frame = frame
      @last_battle_takeover_at = current_time_seconds
      @battle_takeover_sequence = nil
      @last_battle_confirm_pulse_at = current_time_seconds
      @last_battle_scene_idle_confirm_at = current_time_seconds
    rescue
      nil
    end

    def map_scene_ready?
      ready = live_overworld_surface?
      scene_key = ready ? [($scene.object_id rescue 0), ($game_map.map_id rescue nil)] : nil
      if @map_scene_key != scene_key
        @map_scene_key = scene_key
        @map_scene_ready_frame = Graphics.frame_count rescue 0
      end
      ready
    rescue
      false
    end

    def live_overworld_surface?
      return false unless defined?($game_map) && $game_map && defined?($game_player) && $game_player
      scene_name = defined?($scene) && $scene ? $scene.class.to_s : ""
      strict_map = defined?(Scene_Map) && defined?($scene) && $scene.is_a?(Scene_Map)
      scene_looks_map = scene_name =~ /Scene_Map|Map/i
      unless strict_map || scene_looks_map
        return false if scene_name =~ /Title|Intro|Load|Save|Menu|Battle|Splash|Credit|Name|Choose|Option|Settings/i
      end
      true
    rescue
      false
    end

    def map_scene_settled?(settle_frames = nil)
      return false unless map_scene_ready?
      frame = Graphics.frame_count rescue 0
      frames = settle_frames.nil? ? 90 : settle_frames.to_i
      frame.to_i - @map_scene_ready_frame.to_i >= [frames, 0].max
    rescue
      false
    end

    def map_controls_ready?
      return false unless map_scene_ready?
      control_block_reason.nil?
    rescue
      false
    end

    def control_block_reason
      return "no map surface" unless live_overworld_surface?
      return "trainer setup" unless trainer_ready?
      if defined?($game_temp) && $game_temp
        return "battle flag" if battle_context?
        return "stale map menu flag" if stale_map_menu_flag_context?
        return "menu flag" if $game_temp.in_menu && !map_menu_flag_ignored?
        return "message flag" if $game_temp.message_window_showing
        return "transfer flag" if $game_temp.player_transferring || $game_temp.transition_processing || $game_temp.to_title
      end
      return "pokemon temp" if defined?($PokemonTemp) && $PokemonTemp && $PokemonTemp.respond_to?(:miniupdate) && $PokemonTemp.miniupdate
      return "forced/hidden player" if player_forced_or_hidden?
      return "player moving" if defined?($game_player) && $game_player && $game_player.respond_to?(:moving?) && $game_player.moving?
      return "event busy" if map_events_busy?
      if Object.new.respond_to?(:pbMapInterpreterRunning?, true)
        return "interpreter running" if Object.new.send(:pbMapInterpreterRunning?)
      end
      nil
    rescue => e
      "control check #{e.class}"
    end

    def battle_context?
      return false if post_battle_overworld_resume?
      return false if stale_map_battle_context?
      return true if active_battle_context_still_live?
      return true if battle_engine_active?
      return true if battle_message_context?
      return true if raw_battle_flag_active?
      return true if defined?($scene) && $scene && $scene.class.to_s =~ /Battle/
      false
    rescue
      false
    end

    def active_battle_context_still_live?
      return false unless @battle_context_active
      now = current_time_seconds
      if battle_live_signal?
        @battle_map_idle_seen_at = nil
        return true
      end
      return true if @battle_context_started_at &&
                     now - @battle_context_started_at.to_f < battle_active_min_seconds
      return true if @battle_engine_last_seen_at &&
                     now - @battle_engine_last_seen_at.to_f < battle_active_idle_grace_seconds
      return true if @battle_real_scene_seen_at &&
                     now - @battle_real_scene_seen_at.to_f < battle_active_idle_grace_seconds
      return false if battle_map_idle_confirmed?
      return false if battle_latch_soft_timeout?
      true
    rescue
      false
    end

    def battle_live_signal?
      return true if battle_engine_active?
      return true if battle_message_context?
      return true if raw_battle_flag_active?
      return true if recent_battle_message_active?
      return true if battle_prompt_context?
      return true if capture_storage_active?
      return true if battle_ability_splash_active?
      return true if defined?($scene) && $scene && $scene.class.to_s =~ /Battle/
      return true if soft_map_message_busy? && (@battle_context_seen_real_scene || @battle_engine_last_seen_at)
      false
    rescue
      false
    end

    def battle_map_idle_confirmed?
      return false unless map_scene_ready?
      return false if hard_scene_transition_busy?
      return false if defined?($game_temp) && $game_temp &&
                      ($game_temp.message_window_showing ||
                       $game_temp.player_transferring ||
                       $game_temp.transition_processing ||
                       $game_temp.to_title)
      return false if defined?($PokemonTemp) && $PokemonTemp &&
                      $PokemonTemp.respond_to?(:miniupdate) && $PokemonTemp.miniupdate
      return false if defined?($game_player) && $game_player &&
                      $game_player.respond_to?(:moving?) && $game_player.moving?
      return false if player_forced_or_hidden? || map_events_busy?
      now = current_time_seconds
      @battle_map_idle_seen_at ||= now
      now - @battle_map_idle_seen_at.to_f >= battle_map_idle_confirm_seconds
    rescue
      false
    end

    def battle_active_min_seconds
      speed = game_speed_multiplier
      return 2.0 if speed >= 7
      return 3.0 if speed >= 3
      4.0
    rescue
      3.0
    end

    def battle_active_idle_grace_seconds
      speed = game_speed_multiplier
      return 3.5 if speed >= 7
      return 5.0 if speed >= 3
      7.0
    rescue
      5.0
    end

    def battle_map_idle_confirm_seconds
      speed = game_speed_multiplier
      return 0.4 if speed >= 7
      return 0.7 if speed >= 3
      1.0
    rescue
      0.7
    end

    def battle_latch_soft_timeout?
      return false unless map_scene_ready?
      return false if raw_battle_flag_active? || real_battle_scene? || battle_message_context?
      now = current_time_seconds
      seen = @battle_engine_last_seen_at || @battle_context_started_at || now
      limit = game_speed_multiplier >= 7 ? 10.0 : 18.0
      now - seen.to_f >= limit
    rescue
      false
    end

    def raw_battle_flag_active?
      return true if defined?($game_temp) && $game_temp && $game_temp.in_battle
      return true if defined?($PokemonSystem) && $PokemonSystem &&
                     $PokemonSystem.respond_to?(:is_in_battle) &&
                     $PokemonSystem.is_in_battle
      false
    rescue
      false
    end

    def battle_overlay_hidden?
      return true if battle_prompt_context? && !stale_forced_prompt_context?
      return false if post_battle_overworld_resume?
      return false if stale_map_battle_context?
      raw_battle_flag_active? || (defined?($scene) && $scene && $scene.class.to_s =~ /Battle/)
    rescue
      false
    end

    def note_battle_end_resume!
      now = current_time_seconds
      @post_battle_resume_until_at = now + 3.0
      @last_battle_context_end_at = now
      @battle_context_active = false
      @battle_context_started_frame = nil
      @battle_context_started_at = nil
      @battle_context_seen_real_scene = false
      @post_battle_map_seen_at = nil
      @map_battle_flag_seen_at = nil
      @battle_transition_clear_until_frame = nil
      @last_battle_context_status_frame = nil
      @last_runtime_tick_at = nil
      clear_battle_idle_watchdog!
      clear_forced_prompt_state! if battle_prompt_context?
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      AutoplayBot::TeamBuilder.request_training_rotation!("battle ended") if defined?(AutoplayBot::TeamBuilder) &&
                                                                            AutoplayBot::TeamBuilder.respond_to?(:request_training_rotation!)
      AutoplayBot.status("battle: resume map") if AutoplayBot.respond_to?(:status)
    rescue
      nil
    end

    def detect_post_battle_map_return!
      return unless @battle_context_active
      return unless @battle_context_seen_real_scene
      return unless raw_battle_flag_active?
      return if battle_engine_active?
      return if real_battle_scene?
      return unless map_scene_ready?
      return if defined?($game_temp) && $game_temp &&
                ($game_temp.message_window_showing ||
                 $game_temp.player_transferring ||
                 $game_temp.transition_processing ||
                 $game_temp.to_title)
      now = current_time_seconds
      @post_battle_map_seen_at ||= now
      return if now - @post_battle_map_seen_at.to_f < 0.25
      AutoplayBot.log("detected battle returned to map with stale battle flag at #{map_position_for_log}") if AutoplayBot.respond_to?(:log)
      note_battle_end_resume!
    rescue => e
      AutoplayBot.log("post battle map return detection failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def post_battle_overworld_resume?
      return false unless @post_battle_resume_until_at
      now = current_time_seconds
      if now > @post_battle_resume_until_at.to_f
        @post_battle_resume_until_at = nil
        return false
      end
      return false if defined?($scene) && $scene && $scene.class.to_s =~ /Battle/
      return false unless live_overworld_surface?
      if defined?($game_temp) && $game_temp
        return false if $game_temp.message_window_showing
        return false if $game_temp.player_transferring || $game_temp.transition_processing || $game_temp.to_title
      end
      true
    rescue
      false
    end

    def map_battle_state_sweeper_tick
      return unless map_scene_ready?
      return if battle_engine_active?
      return if real_battle_scene?
      return if hard_scene_transition_busy?

      battleish = raw_battle_flag_active? ||
                  @battle_context_active ||
                  battle_prompt_context? ||
                  director_runtime_mode_battle?
      unless battleish
        clear_map_battle_sweeper!
        return
      end

      now = current_time_seconds
      if battle_startup_transition_protected?
        pulse_stuck_battle_transition(now, now - (@battle_context_started_at || @map_battle_flag_seen_at || now).to_f)
        clear_map_battle_sweeper!
        AutoplayBot.status("battle: startup wait") if AutoplayBot.respond_to?(:status)
        return
      end
      intro_timeout = battle_intro_timed_out?(now)
      if raw_battle_flag_active? && !post_battle_overworld_resume? &&
         !(@last_battle_context_end_at && now - @last_battle_context_end_at.to_f >= 1.0) &&
         !intro_timeout
        clear_map_battle_sweeper!
        return
      end
      unless @map_battle_sweeper_started_at
        @map_battle_sweeper_started_at = intro_timeout && @battle_context_started_at ? @battle_context_started_at : now
        @map_battle_sweeper_started_frame = (Graphics.frame_count rescue 0).to_i
        @map_battle_sweeper_logged = false
      end
      elapsed = now - @map_battle_sweeper_started_at.to_f
      log_map_battle_sweeper_once
      if raw_battle_flag_active?
        # Wild battle setup lives on Scene_Map briefly before the battle scene takes over.
        # Clearing that early corrupts the transition, so only treat it as stale after
        # a real timeout.
        return if elapsed < (intro_timeout ? 0.4 : battle_intro_map_grace_seconds)
      end

      if soft_map_message_busy?
        pulse_map_battle_prompt_clear(now)
        return if elapsed < 2.0
      else
        return if elapsed < 0.9
      end

      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      clear_forced_prompt_state!
      clear_stale_battle_flags!("map battle sweeper")
      @last_battle_context_end_at = now
      @last_runtime_tick_at = nil
      clear_map_battle_sweeper!
      AutoplayBot.status("battle: map state cleared")
      AutoplayBot::Overlay.update(true) if defined?(AutoplayBot::Overlay)
    rescue => e
      clear_map_battle_sweeper!
      AutoplayBot.log("map battle sweeper failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def clear_map_battle_sweeper!
      @map_battle_sweeper_started_at = nil
      @map_battle_sweeper_started_frame = nil
      @last_map_battle_prompt_pulse_at = nil
      @map_battle_sweeper_logged = false
    rescue
      nil
    end

    def log_map_battle_sweeper_once
      return if @map_battle_sweeper_logged
      @map_battle_sweeper_logged = true
      bits = []
      bits << "raw=#{raw_battle_flag_active?}"
      bits << "guard=#{@battle_context_active == true}"
      bits << "forced=#{battle_prompt_context?}"
      bits << "director=#{director_runtime_mode_battle?}"
      bits << "message=#{soft_map_message_busy?}"
      bits << "status=#{AutoplayBot.status_message}"
      AutoplayBot.log("map battle sweeper armed #{bits.join(' ')} at #{map_position_for_log}") if AutoplayBot.respond_to?(:log)
    rescue
      nil
    end

    def real_battle_scene?
      defined?($scene) && $scene && $scene.class.to_s =~ /Battle/
    rescue
      false
    end

    def battle_scene_object
      return $scene if defined?($scene) && $scene && $scene.class.to_s =~ /Battle/
      nil
    rescue
      nil
    end

    def hard_scene_transition_busy?
      return true if defined?($game_temp) && $game_temp &&
                     ($game_temp.player_transferring ||
                      $game_temp.transition_processing ||
                      $game_temp.to_title)
      return true if defined?($PokemonTemp) && $PokemonTemp &&
                     $PokemonTemp.respond_to?(:miniupdate) && $PokemonTemp.miniupdate
      false
    rescue
      true
    end

    def soft_map_message_busy?
      defined?($game_temp) && $game_temp && $game_temp.message_window_showing
    rescue
      false
    end

    def director_runtime_mode_battle?
      return false unless state_loaded? && AutoplayBot::State.respond_to?(:runtime_mode)
      return false unless AutoplayBot::State.runtime_mode.to_s == "battle"
      return true if raw_battle_flag_active?
      return true if real_battle_scene?
      return true if battle_prompt_context?
      return true if battle_engine_active?
      now = current_time_seconds
      return true if @battle_context_active && !stale_map_battle_context?
      return true if @battle_engine_last_seen_at &&
                     now - @battle_engine_last_seen_at.to_f < 2.0
      return true if @last_battle_context_end_at &&
                     now - @last_battle_context_end_at.to_f < 1.5
      if live_overworld_surface? && AutoplayBot::State.respond_to?(:set_runtime_mode)
        AutoplayBot::State.set_runtime_mode("story")
      end
      false
    rescue
      false
    end

    def pulse_map_battle_prompt_clear(now = current_time_seconds)
      return if @last_map_battle_prompt_pulse_at &&
                now - @last_map_battle_prompt_pulse_at.to_f < 0.18
      @last_map_battle_prompt_pulse_at = now
      frames = prompt_hold_frames
      AutoplayBot::InputQueue.tap(:USE, frames) if defined?(AutoplayBot::InputQueue)
      AutoplayBot::InputQueue.tap_next(:USE, frames) if defined?(AutoplayBot::InputQueue) &&
                                                        AutoplayBot::InputQueue.respond_to?(:tap_next)
      AutoplayBot.status("battle: clearing map prompt")
    rescue
      nil
    end

    def overworld_battle_dialog_recover_tick
      return unless forced_input_context?
      return unless @forced_input_label.to_s =~ /battle/i
      return unless map_scene_ready?
      return if defined?($scene) && $scene && $scene.class.to_s =~ /Battle/
      return if overworld_recovery_busy?

      now = current_time_seconds
      if raw_battle_flag_active? && !post_battle_overworld_resume? &&
         !(@last_battle_context_end_at && now - @last_battle_context_end_at.to_f >= 1.0)
        pulse_map_battle_prompt_clear(now) if soft_map_message_busy?
        return
      end
      elapsed = forced_prompt_elapsed_seconds
      battle_elapsed = @battle_context_started_at ? now - @battle_context_started_at.to_f : elapsed
      return if elapsed < 0.75 && battle_elapsed < 1.2
      return if @last_overworld_battle_dialog_recover_at &&
                now - @last_overworld_battle_dialog_recover_at.to_f < 0.5

      @last_overworld_battle_dialog_recover_at = now
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      clear_forced_prompt_state!
      clear_stale_battle_flags!("overworld battle dialog")
      @last_runtime_tick_at = nil
      AutoplayBot.status("battle: overworld dialog cleared")
      AutoplayBot::Overlay.update(true) if defined?(AutoplayBot::Overlay)
    rescue => e
      AutoplayBot.log("overworld battle dialog recovery failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def overworld_recovery_busy?
      return true if defined?($game_temp) && $game_temp &&
                     (($game_temp.in_menu && !map_menu_flag_ignored?) ||
                      $game_temp.message_window_showing ||
                      $game_temp.player_transferring ||
                      $game_temp.transition_processing ||
                      $game_temp.to_title)
      return true if defined?($PokemonTemp) && $PokemonTemp &&
                     $PokemonTemp.respond_to?(:miniupdate) && $PokemonTemp.miniupdate
      return true if defined?($game_player) && $game_player &&
                     $game_player.respond_to?(:moving?) && $game_player.moving?
      false
    rescue
      true
    end

    def post_battle_map_recover_tick
      return unless @last_battle_context_end_at
      return unless map_scene_ready?
      return if battle_engine_active?
      return if defined?($scene) && $scene && $scene.class.to_s =~ /Battle/
      return unless raw_battle_flag_active? || forced_input_context?
      return if overworld_recovery_busy?
      return if current_time_seconds - @last_battle_context_end_at.to_f < 0.35

      label = @forced_input_label.to_s
      clear_forced_prompt_state! if forced_input_context? && label =~ /battle|pokedex|evol|prompt/i
      clear_stale_battle_flags!("post-battle overworld recovery") if raw_battle_flag_active?
      @last_runtime_tick_at = nil
      AutoplayBot.status("battle: overworld resume")
      AutoplayBot::Overlay.update(true) if defined?(AutoplayBot::Overlay)
    rescue => e
      AutoplayBot.log("post battle map recover failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def recover_stale_raw_map_battle!(snap = nil)
      return false unless map_scene_ready?
      return false unless raw_battle_flag_active?
      return false if real_battle_scene?
      return false if battle_engine_active? || capture_storage_active?
      if stale_raw_map_recovery_busy?
        clear_stale_raw_map_recovery!
        @stale_raw_map_recovery_status = "waiting map"
        return false
      end

      key = stale_raw_map_recovery_key(snap)
      now = current_time_seconds
      if @stale_raw_map_recovery_key != key
        @stale_raw_map_recovery_key = key
        @stale_raw_map_recovery_seen_at = now
        @stale_raw_map_recovery_logged = false
      end
      elapsed = now - @stale_raw_map_recovery_seen_at.to_f
      @stale_raw_map_recovery_status = "stale #{elapsed.round(1)}s"
      unless @stale_raw_map_recovery_logged
        @stale_raw_map_recovery_logged = true
        AutoplayBot.log("stale raw battle flag on map #{key.join(':')}") if AutoplayBot.respond_to?(:log)
      end
      return false if elapsed < stale_raw_map_clear_seconds

      cleared = clear_stale_battle_flags!("stale raw map")
      if cleared
        clear_stale_raw_map_recovery!
        @last_runtime_tick_at = nil
        @post_battle_resume_until_at = now + 0.35
      end
      cleared
    rescue => e
      clear_stale_raw_map_recovery!
      AutoplayBot.log("stale raw map recovery failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def stale_raw_map_recovery_status
      @stale_raw_map_recovery_status || "runtime recovery"
    rescue
      "runtime recovery"
    end

    def stale_raw_map_recovery_key(snap = nil)
      map_id = snap && snap["map_id"] ? snap["map_id"] : (defined?($game_map) && $game_map ? $game_map.map_id : nil)
      x = snap && snap["x"] ? snap["x"] : (defined?($game_player) && $game_player ? $game_player.x : nil)
      y = snap && snap["y"] ? snap["y"] : (defined?($game_player) && $game_player ? $game_player.y : nil)
      [map_id, x, y]
    rescue
      ["unknown"]
    end

    def stale_raw_map_recovery_busy
      return true if defined?($game_temp) && $game_temp &&
                     ($game_temp.message_window_showing ||
                      $game_temp.player_transferring ||
                      $game_temp.transition_processing ||
                      $game_temp.to_title)
      return true if defined?($PokemonTemp) && $PokemonTemp &&
                     $PokemonTemp.respond_to?(:miniupdate) && $PokemonTemp.miniupdate
      return true if defined?($game_player) && $game_player &&
                     $game_player.respond_to?(:moving?) && $game_player.moving?
      false
    rescue
      true
    end

    def stale_raw_map_recovery_busy?
      stale_raw_map_recovery_busy
    rescue
      true
    end

    def clear_stale_raw_map_recovery!
      @stale_raw_map_recovery_key = nil
      @stale_raw_map_recovery_seen_at = nil
      @stale_raw_map_recovery_logged = false
      @stale_raw_map_recovery_status = nil
    rescue
      nil
    end

    def stale_raw_map_clear_seconds
      speed = game_speed_multiplier
      return 0.35 if speed >= 7
      return 0.55 if speed >= 3
      0.8
    rescue
      0.6
    end

    def stale_map_battle_context?
      return false unless map_scene_ready?
      return false if battle_engine_active?
      return false if defined?($scene) && $scene && $scene.class.to_s =~ /Battle/
      return false unless raw_battle_flag_active?
      return false if battle_map_busy?
      return false unless @last_battle_context_end_at || @post_battle_resume_until_at
      now = current_time_seconds
      @map_battle_flag_seen_at ||= now
      if @last_battle_context_end_at && now - @last_battle_context_end_at.to_f >= 0.75
        clear_forced_prompt_state! if battle_prompt_context?
        @map_battle_flag_seen_at = nil
        return true
      end
      started = @battle_context_started_at || @map_battle_flag_seen_at
      if @battle_context_active && !@battle_context_seen_real_scene &&
         started && now - started.to_f < battle_start_grace_seconds
        return false
      end
      return false if now - started.to_f < 6.0
      return false if now - @map_battle_flag_seen_at.to_f < 2.0
      clear_forced_prompt_state! if battle_prompt_context?
      @map_battle_flag_seen_at = nil
      true
    rescue
      false
    end

    def battle_map_busy?
      return true if defined?($game_temp) && $game_temp &&
                     ($game_temp.message_window_showing ||
                      $game_temp.player_transferring ||
                      $game_temp.transition_processing ||
                      $game_temp.to_title)
      return true if defined?($PokemonTemp) && $PokemonTemp &&
                     $PokemonTemp.respond_to?(:miniupdate) && $PokemonTemp.miniupdate
      return true if defined?($game_player) && $game_player &&
                     $game_player.respond_to?(:moving?) && $game_player.moving?
      false
    rescue
      true
    end

    def stale_battle_flag_clear_allowed?(reason = nil)
      return false unless map_scene_ready?
      return false if capture_storage_active?
      return false if battle_engine_active?
      return false if defined?($scene) && $scene && $scene.class.to_s =~ /Battle/
      return false if battle_map_busy?
      now = current_time_seconds
      reason_text = reason.to_s
      if reason_text =~ /post-battle|overworld battle dialog|map battle sweeper|stale raw map/i
        return true if @last_battle_context_end_at &&
                       now - @last_battle_context_end_at.to_f >= 0.5
        return true if @post_battle_resume_until_at &&
                       now <= @post_battle_resume_until_at.to_f
        return true if reason_text =~ /stale raw map/i &&
                       @stale_raw_map_recovery_seen_at &&
                       now - @stale_raw_map_recovery_seen_at.to_f >= stale_raw_map_clear_seconds
      end
      seen = @battle_context_started_at || @map_battle_flag_seen_at || @last_battle_context_end_at
      if reason_text =~ /map battle sweeper|battle intro timeout/i &&
         @battle_context_active && !@battle_context_seen_real_scene &&
         @battle_context_started_at &&
         now - @battle_context_started_at.to_f < battle_start_grace_seconds
        return false
      end
      return false unless seen
      now - seen.to_f >= stale_battle_clear_seconds
    rescue
      false
    end

    def battle_start_grace_seconds
      speed = game_speed_multiplier
      return 5.0 if speed >= 7
      return 8.0 if speed >= 3
      14.0
    rescue
      14.0
    end

    def battle_intro_map_grace_seconds
      speed = game_speed_multiplier
      return 2.5 if speed >= 7
      return 4.0 if speed >= 3
      7.0
    rescue
      7.0
    end

    def stale_battle_clear_seconds
      speed = game_speed_multiplier
      return 5.0 if speed >= 7
      return 7.0 if speed >= 3
      10.0
    rescue
      10.0
    end

    def battle_intro_timed_out?(now = current_time_seconds)
      return false unless @battle_context_active
      return false if @battle_context_seen_real_scene
      return false unless @battle_context_started_at
      now.to_f - @battle_context_started_at.to_f >= battle_start_grace_seconds
    rescue
      false
    end

    def clear_stale_battle_flags!(reason = "stale battle")
      unless stale_battle_flag_clear_allowed?(reason)
        clear_forced_prompt_state! if battle_prompt_context? && map_scene_ready? && !battle_map_busy?
        AutoplayBot.log("deferred stale battle clear: #{reason}") if AutoplayBot.respond_to?(:log)
        return false
      end
      if defined?($game_temp) && $game_temp && $game_temp.respond_to?(:in_battle=)
        $game_temp.in_battle = false
      end
      if defined?($PokemonSystem) && $PokemonSystem &&
         $PokemonSystem.respond_to?(:is_in_battle=)
        $PokemonSystem.is_in_battle = false
      end
      @map_battle_flag_seen_at = nil
      @battle_context_active = false
      @battle_context_started_frame = nil
      @battle_context_started_at = nil
      @battle_context_seen_real_scene = false
      @post_battle_map_seen_at = nil
      @battle_engine_active = false
      @battle_engine_reason = nil
      @battle_message_context_depth = 0
      @battle_transition_clear_until_frame = nil
      @last_battle_context_status_frame = nil
      clear_battle_idle_watchdog!
      clear_forced_prompt_state! if battle_prompt_context?
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      if defined?(AutoplayBot::Director) &&
         AutoplayBot::Director.respond_to?(:note_battle_context_end!)
        AutoplayBot::Director.note_battle_context_end!
      end
      AutoplayBot.status("battle: reroute after #{reason}")
      AutoplayBot.log("cleared #{reason} at map #{defined?($game_map) && $game_map ? $game_map.map_id : '?'} x#{defined?($game_player) && $game_player ? $game_player.x : '?'} y#{defined?($game_player) && $game_player ? $game_player.y : '?'}") if AutoplayBot.respond_to?(:log)
      AutoplayBot::Overlay.update(true) if defined?(AutoplayBot::Overlay)
      true
    rescue => e
      AutoplayBot.log("stale battle clear failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def trainer_ready?
      return false unless defined?($Trainer) && $Trainer
      return false if $Trainer.respond_to?(:character_ID) && $Trainer.character_ID.to_i < 0
      return false if $Trainer.respond_to?(:name) && $Trainer.name.to_s.strip.empty?
      true
    rescue
      false
    end

    def player_forced_or_hidden?
      return false unless defined?($game_player) && $game_player
      return true if $game_player.respond_to?(:move_route_forcing) && $game_player.move_route_forcing
      return true if $game_player.respond_to?(:transparent) && $game_player.transparent
      false
    rescue
      true
    end

    def map_events_busy?
      return false unless defined?($game_map) && $game_map && $game_map.respond_to?(:events) && $game_map.events
      $game_map.events.values.any? do |event|
        next false unless event
        (event.respond_to?(:starting) && event.starting) ||
          (event.respond_to?(:move_route_forcing) && event.move_route_forcing)
      end
    rescue
      true
    end

    def start_block_reason
      return "ready battle" if battle_hotkey_start_ready?
      return "ready menu" if menu_hotkey_start_ready?
      unless map_scene_ready?
        scene_name = defined?($scene) && $scene ? $scene.class.to_s : "no scene"
        return "wait overworld #{scene_name}"
      end
      if @mode == "arming"
        reason = control_block_reason
        return "wait #{reason}" if reason
        quick_start_ready?(hotkey_start_settle_frames)
        return "ready"
      else
        return "wait for scene settle" unless map_scene_settled?
      end
      return "wait for trainer setup" unless trainer_ready?
      return "wait for battle/menu" if battle_context? || (defined?($game_temp) && $game_temp && $game_temp.in_menu && !map_menu_flag_ignored?)
      return "wait for message" if defined?($game_temp) && $game_temp && $game_temp.message_window_showing
      if defined?($game_temp) && $game_temp && ($game_temp.player_transferring || $game_temp.transition_processing || $game_temp.to_title)
        return "wait for transition"
      end
      return "wait for cutscene" if player_forced_or_hidden? || map_events_busy?
      return "wait for player stop" if defined?($game_player) && $game_player && $game_player.respond_to?(:moving?) && $game_player.moving?
      if Object.new.respond_to?(:pbMapInterpreterRunning?, true) && Object.new.send(:pbMapInterpreterRunning?)
        return "wait for event"
      end
      "ready"
    rescue
      "wait for overworld"
    end

    def stop!(reason = "stop")
      hotkey_stop = reason.to_s.include?("hotkey")
      release_battle_intro = !hotkey_stop && battle_intro_limbo_surface?
      @mode = "idle"
      @user_stopped = true if hotkey_stop
      AutoplayBot::InputQueue.clear if hotkey_stop && defined?(AutoplayBot::InputQueue)
      AutoplayBot::Overlay.dispose if hotkey_stop && defined?(AutoplayBot::Overlay)
      @human_override_active = false
      @human_override_last_frame = nil
      @human_override_last_at = nil
      @last_runtime_tick_at = nil
      @quick_start_pos = nil
      @quick_start_stable_frames = 0
      @quick_start_last_frame = nil
      @deferred_state_clear_reason = nil
      @deferred_state_clear_started = false
      @startup_bootstrap_pending = false
      @startup_bootstrap_phase = nil
      @pending_start_feedback_text = nil
      @started_frame = nil
      @started_at = nil
      clear_startup_light!
      clear_context_interrupt_latch!
      recover_stuck_battle_transition!("battle intro stop") if release_battle_intro
      clear_menu_idle_watchdog!
      clear_battle_idle_watchdog!
      clear_battle_context_guard!
      clear_forced_prompt_state!
      clear_stale_map_menu_watchdog!
      AutoplayBot::InputQueue.clear
      AutoplayBot::Director.reset_runtime! if defined?(AutoplayBot::Director) && AutoplayBot::Director.respond_to?(:reset_runtime!)
      AutoplayBot::BotCore.reset_runtime!("stop #{reason}") if defined?(AutoplayBot::BotCore) && AutoplayBot::BotCore.respond_to?(:reset_runtime!)
      AutoplayBot::MenuTools.clear! if defined?(AutoplayBot::MenuTools) && AutoplayBot::MenuTools.respond_to?(:clear!)
      if state_loaded?
        if AutoplayBot::State.respond_to?(:clear_runtime_flags!)
          AutoplayBot::State.clear_runtime_flags!("stop #{reason}")
        else
          AutoplayBot::State.set_mode(@mode)
        end
        if hotkey_stop
          frame = Graphics.frame_count rescue 0
          AutoplayBot::State.postpone_save(frame) if AutoplayBot::State.respond_to?(:postpone_save)
        else
          AutoplayBot::State.save!(true)
        end
      end
      AutoplayBot.status("off: #{reason}")
      AutoplayBot::Overlay.dispose if defined?(AutoplayBot::Overlay)
      AutoplayBot.log("stopped: #{reason}") if AutoplayBot.respond_to?(:log)
    rescue => e
      AutoplayBot.log("stop failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def pause!(reason = "pause")
      stop!(reason)
    rescue => e
      AutoplayBot.log("pause failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def manual_needed(reason)
      AutoplayBot::State.record_failure_event(reason, "source" => "manual_needed") if state_loaded? && AutoplayBot::State.respond_to?(:record_failure_event)
      if soft_recovery_allowed?(reason) &&
         defined?(AutoplayBot::Director) &&
         AutoplayBot::Director.respond_to?(:soft_recover!) &&
         AutoplayBot::Director.soft_recover!(reason)
        @mode = "running"
        if state_loaded?
          AutoplayBot::State.set_mode(@mode)
          AutoplayBot::State.save!(true)
        end
        AutoplayBot.log("soft recovery: #{reason}") if AutoplayBot.respond_to?(:log)
        return
      end
      @mode = "manual_needed"
      @human_override_active = false
      @human_override_last_frame = nil
      @human_override_last_at = nil
      clear_battle_idle_watchdog!
      clear_battle_context_guard!
      clear_forced_prompt_state!
      clear_stale_map_menu_watchdog!
      AutoplayBot::InputQueue.clear
      AutoplayBot::Director.reset_runtime! if defined?(AutoplayBot::Director) && AutoplayBot::Director.respond_to?(:reset_runtime!)
      AutoplayBot::BotCore.reset_runtime!("manual #{reason}") if defined?(AutoplayBot::BotCore) && AutoplayBot::BotCore.respond_to?(:reset_runtime!)
      if state_loaded?
        AutoplayBot::State.set_mode(@mode)
        AutoplayBot::State.add_manual_note(reason)
        AutoplayBot::State.save!(true)
      end
      AutoplayBot.status("manual: #{reason}") if defined?(AutoplayBot)
      AutoplayBot::Overlay.dispose if defined?(AutoplayBot::Overlay)
      AutoplayBot.log("manual needed: #{reason}") if AutoplayBot.respond_to?(:log)
    rescue
      nil
    end

    def soft_recovery_allowed?(reason)
      return false unless running?
      return false unless defined?(AutoplayBot::Config) && AutoplayBot::Config.soft_recovery?
      text = reason.to_s.downcase
      return false if text.include?("exclusive choice")
      return false if text.include?("runtime update failure")
      return false if text.include?("director failure")
      return false if text.include?("start failed")
      true
    rescue
      false
    end

    def tick
      return unless enabled?
      if battle_or_menu_context_active?
        context_interrupt_overworld_motion!("battle/menu")
        return false
      end
      if startup_light?
        AutoplayBot::State.set_runtime_mode("startup") if state_loaded? &&
                                                           AutoplayBot::State.respond_to?(:set_runtime_mode)
        AutoplayBot.status("startup: taking over")
        return
      end
      return if startup_bootstrap_tick
      return if speed_change_settle_tick
      return if pause_menu_preflight_tick
      team_rotation_tick
      coast = map_movement_coasting?
      flush_deferred_state_clear_if_safe
      if defined?(AutoplayBot::BotCore) && AutoplayBot::BotCore.respond_to?(:tick)
        @last_movement_coast_frame = (Graphics.frame_count rescue 0).to_i if coast
        AutoplayBot::BotCore.tick(coast)
      elsif coast
        @last_movement_coast_frame = (Graphics.frame_count rescue 0).to_i
        AutoplayBot::Director.coast_tick if defined?(AutoplayBot::Director) && AutoplayBot::Director.respond_to?(:coast_tick)
      else
        AutoplayBot::Director.tick
      end
      frame = Graphics.frame_count rescue 0
      AutoplayBot::State.maybe_save(frame) if state_loaded? && !performance_coast? && !battle_context?
    end

    def startup_bootstrap_tick
      return false unless @startup_bootstrap_pending
      phase = @startup_bootstrap_phase.to_i
      frame = (Graphics.frame_count rescue 0).to_i
      case phase
      when 0
        AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
        clear_menu_idle_watchdog!
        clear_battle_idle_watchdog!
        clear_battle_context_guard!
        clear_forced_prompt_state!
        clear_stale_map_menu_watchdog!
        @startup_bootstrap_phase = 1
        AutoplayBot.status("startup: controls ready")
      when 1
        AutoplayBot::MenuTools.clear! if defined?(AutoplayBot::MenuTools) &&
                                         AutoplayBot::MenuTools.respond_to?(:clear!)
        @startup_bootstrap_phase = 2
        AutoplayBot.status("startup: menu clear")
      when 2
        AutoplayBot::BotCore.reset_runtime!("start #{@startup_bootstrap_reason}") if defined?(AutoplayBot::BotCore) &&
                                                                                    AutoplayBot::BotCore.respond_to?(:reset_runtime!)
        @startup_bootstrap_phase = 3
        AutoplayBot.status("startup: route memory reset")
      when 3
        AutoplayBot::Director.reset_runtime! if defined?(AutoplayBot::Director) &&
                                                AutoplayBot::Director.respond_to?(:reset_runtime!)
        @startup_bootstrap_phase = 4
        AutoplayBot.status("startup: old planner reset")
      when 4
        if !state_loaded? && defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:load_ephemeral!)
          AutoplayBot::State.load_ephemeral!("start #{@startup_bootstrap_reason}")
        end
        if state_loaded? && defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:clear_runtime_flags!)
          AutoplayBot::State.clear_runtime_flags!("start #{@startup_bootstrap_reason}")
        else
          @deferred_state_clear_reason ||= "start #{@startup_bootstrap_reason}"
        end
        AutoplayBot::State.set_mode(@mode) if state_loaded? &&
                                              AutoplayBot::State.respond_to?(:set_mode)
        AutoplayBot::State.postpone_save(frame) if state_loaded? &&
                                                   AutoplayBot::State.respond_to?(:postpone_save)
        @startup_bootstrap_phase = 5
        AutoplayBot.status(state_ephemeral? ? "startup: live memory" : "startup: memory ready")
      else
        @startup_bootstrap_pending = false
        @startup_bootstrap_phase = nil
        AutoplayBot.status(battle_hotkey_start_ready? ? "battle: ready" : "bot ready")
        AutoplayBot.log("started: #{@startup_bootstrap_reason}") if AutoplayBot.respond_to?(:log)
      end
      true
    rescue => e
      @startup_bootstrap_pending = false
      @startup_bootstrap_phase = nil
      AutoplayBot.status("startup: skipped #{e.class}")
      AutoplayBot.log("startup bootstrap failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      true
    end

    def speed_change_settle_tick
      return false unless speed_recently_changed?(0.22)
      return false unless defined?($scene) && defined?(Scene_Map) && $scene.is_a?(Scene_Map)
      return false if battle_context? || forced_input_context? || menu_context_active?
      return false unless map_controls_ready?
      AutoplayBot.status("speed x#{game_speed_multiplier}: settling")
      true
    rescue
      false
    end

    def pause_menu_preflight_tick
      return false unless defined?(AutoplayBot::MenuTools) &&
                          AutoplayBot::MenuTools.respond_to?(:pending_action) &&
                          AutoplayBot::MenuTools.respond_to?(:open_pause_menu) &&
                          AutoplayBot::MenuTools.respond_to?(:pause_menu_available_for?)
      return false if AutoplayBot::MenuTools.pending_action
      return false unless pause_menu_heal_preflight_needed?
      return false unless AutoplayBot::MenuTools.pause_menu_available_for?(:heal)
      return false unless map_controls_ready?
      return false if battle_transition_cooldown_active?(3.0)
      return false if battle_context? || forced_input_context? || human_override_active?
      return false if menu_context_active?
      frame = (Graphics.frame_count rescue 0).to_i
      return false if @pause_heal_preflight_block_until_frame &&
                      frame < @pause_heal_preflight_block_until_frame.to_i
      @last_pause_heal_preflight_frame ||= -9999
      return false if frame - @last_pause_heal_preflight_frame.to_i < 60
      @last_pause_heal_preflight_frame = frame
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      context_interrupt_overworld_motion!("urgent heal", false)
      if defined?(AutoplayBot::Navigator) && AutoplayBot::Navigator.respond_to?(:reset!)
        AutoplayBot::Navigator.reset!("urgent pause heal")
      end
      AutoplayBot.status("menu: urgent Heal Pokemon")
      opened = AutoplayBot::MenuTools.open_pause_menu(:heal, "party HP low before overworld action")
      unless opened
        @pause_heal_preflight_failures = @pause_heal_preflight_failures.to_i + 1
        if @pause_heal_preflight_failures >= 2
          @pause_heal_preflight_block_until_frame = frame + 900
          AutoplayBot.status("menu: heal skipped for now")
        end
        return false
      end
      @pause_heal_preflight_failures = 0
      @pause_heal_preflight_block_until_frame = nil
      true
    rescue => e
      AutoplayBot.log("pause menu preflight failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def team_rotation_tick
      return false unless defined?(AutoplayBot::TeamBuilder) &&
                          AutoplayBot::TeamBuilder.respond_to?(:maybe_rotate_training_lead!)
      return false unless defined?(AutoplayBot::Config) && AutoplayBot::Config.team_strategy?
      return false if startup_light? || @startup_bootstrap_pending
      return false if battle_context? || forced_input_context? || menu_context_active?
      return false if human_override_active?
      return false if battle_transition_cooldown_active?(1.0)
      return false unless map_scene_ready?
      if defined?($game_temp) && $game_temp
        return false if $game_temp.message_window_showing
        return false if $game_temp.player_transferring || $game_temp.transition_processing || $game_temp.to_title
      end
      return false if defined?($game_player) && $game_player &&
                      $game_player.respond_to?(:moving?) && $game_player.moving?
      if defined?(AutoplayBot::InputQueue) &&
         AutoplayBot::InputQueue.respond_to?(:dir_frames_remaining) &&
         AutoplayBot::InputQueue.dir_frames_remaining.to_i > 0
        return false
      end
      return false unless map_controls_ready?
      AutoplayBot::TeamBuilder.maybe_rotate_training_lead!("safe overworld")
    rescue => e
      AutoplayBot.log("team rotation tick failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def pause_menu_heal_preflight_needed?
      return false unless defined?($Trainer) && $Trainer && $Trainer.respond_to?(:party)
      party = Array($Trainer.party).compact
      return false if party.empty?
      total_hp = 0
      current_hp = 0
      able = 0
      critical = false
      party.each do |pkmn|
        hp = pkmn.respond_to?(:hp) ? pkmn.hp.to_i : 0
        max_hp = pkmn.respond_to?(:totalhp) ? pkmn.totalhp.to_i : hp
        max_hp = 1 if max_hp <= 0
        hp = [[hp, 0].max, max_hp].min
        total_hp += max_hp
        current_hp += hp
        able += 1 if hp > 0
        critical = true if hp > 0 && hp.to_f / max_hp.to_f <= 0.25
      end
      return true if able <= 1 && party.length > 1
      return true if critical
      return false if total_hp <= 0
      current_hp.to_f / total_hp.to_f <= 0.65
    rescue
      false
    end

    def flush_deferred_state_clear_if_safe
      return unless @deferred_state_clear_reason
      return if startup_light?
      return unless deferred_state_load_window?
      return if @deferred_state_clear_started
      @deferred_state_clear_started = true
      if !state_loaded? && defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:load_ephemeral!)
        AutoplayBot.status("startup: live memory")
        AutoplayBot::State.load_ephemeral!(@deferred_state_clear_reason)
      end
      AutoplayBot::State.clear_runtime_flags!(@deferred_state_clear_reason) if defined?(AutoplayBot::State) &&
                                                                              AutoplayBot::State.respond_to?(:clear_runtime_flags!)
      AutoplayBot::State.set_mode(@mode) if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:set_mode)
      @deferred_state_clear_reason = nil
      @deferred_state_clear_started = false
    rescue => e
      @deferred_state_clear_reason = nil
      @deferred_state_clear_started = false
      AutoplayBot.log("deferred state load failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def deferred_state_load_window?
      return false unless defined?(AutoplayBot::State)
      return false if startup_memory_defer_active?
      return true if state_loaded?
      frame = (Graphics.frame_count rescue 0).to_i
      return false if @started_frame && frame - @started_frame.to_i < 1800
      return false if @started_at && current_time_seconds - @started_at.to_f < 20.0
      return false if map_movement_coasting?
      return false unless defined?($scene) && defined?(Scene_Map) && $scene.is_a?(Scene_Map)
      return false if battle_context? || menu_context_active? || forced_input_context?
      if defined?($game_temp) && $game_temp
        return false if $game_temp.message_window_showing
        return false if $game_temp.player_transferring || $game_temp.transition_processing || $game_temp.to_title
      end
      return false if defined?($game_player) && $game_player && $game_player.respond_to?(:moving?) && $game_player.moving?
      true
    rescue
      false
    end

    def state_ephemeral?
      defined?(AutoplayBot::State) &&
        AutoplayBot::State.respond_to?(:ephemeral?) &&
        AutoplayBot::State.ephemeral?
    rescue
      false
    end

    def startup_memory_defer_active?
      return false unless @started_frame || @started_at
      frame = (Graphics.frame_count rescue 0).to_i
      now = current_time_seconds
      return true if @started_frame && frame - @started_frame.to_i < startup_memory_defer_frames
      return true if @started_at && now - @started_at.to_f < startup_memory_defer_seconds
      false
    rescue
      false
    end

    def startup_memory_defer_frames
      speed = game_speed_multiplier
      return 8 if speed >= 7
      return 10 if speed >= 3
      12
    rescue
      12
    end

    def startup_memory_defer_seconds
      0.25
    rescue
      0.25
    end

    def startup_light_frames
      speed = game_speed_multiplier
      return 8 if speed >= 7
      return 10 if speed >= 3
      12
    rescue
      12
    end

    def startup_light_seconds
      0.18
    rescue
      0.18
    end

    def current_position_key
      return nil unless defined?($game_map) && $game_map &&
                        defined?($game_player) && $game_player
      [$game_map.map_id, $game_player.x, $game_player.y]
    rescue
      nil
    end

    def startup_position_changed?
      start = @startup_start_pos
      now = current_position_key
      start && now && start != now
    rescue
      false
    end

    def clear_startup_light!
      @startup_light_until_frame = nil
      @startup_light_until_at = nil
      @startup_start_pos = nil
    rescue
      nil
    end

    def startup_light?
      if startup_position_changed?
        clear_startup_light!
        return false
      end
      now = current_time_seconds
      frame = (Graphics.frame_count rescue 0).to_i
      time_active = @startup_light_until_at && now < @startup_light_until_at.to_f
      frame_active = @startup_light_until_frame && frame < @startup_light_until_frame.to_i
      return true if time_active || frame_active
      clear_startup_light!
      false
    rescue
      clear_startup_light!
      false
    end

    def map_movement_coasting?
      return false unless defined?(AutoplayBot::InputQueue) &&
                          AutoplayBot::InputQueue.respond_to?(:dir_frames_remaining) &&
                          AutoplayBot::InputQueue.dir_frames_remaining > 2
      return false unless defined?($scene) && defined?(Scene_Map) && $scene.is_a?(Scene_Map)
      return false unless defined?($game_player) && $game_player
      if raw_battle_flag_active?
        AutoplayBot::InputQueue.clear
        return false
      end
      dir = AutoplayBot::InputQueue.respond_to?(:dir4) ? AutoplayBot::InputQueue.dir4.to_i : 0
      return false unless [2, 4, 6, 8].include?(dir)
      moving = $game_player.respond_to?(:moving?) && $game_player.moving?
      unless moving
        unless static_coast_dir_passable?(dir)
          AutoplayBot.status("coast blocked: #{@last_static_coast_block_reason || 'blocked'}") if AutoplayBot.respond_to?(:status)
          notify_static_coast_block!(dir, @last_static_coast_block_reason || "blocked")
          AutoplayBot::InputQueue.clear
          clear_static_coast_input!
          return false
        end
        if stale_static_coast_input?(dir)
          notify_static_coast_block!(dir, "stale coast #{dir}")
          AutoplayBot::InputQueue.clear
          clear_static_coast_input!
          return false
        end
      else
        clear_static_coast_input!
      end
      if defined?($game_temp) && $game_temp
        return false if $game_temp.message_window_showing
        return false if $game_temp.in_battle || ($game_temp.in_menu && !map_menu_flag_ignored?)
        return false if $game_temp.player_transferring || $game_temp.transition_processing || $game_temp.to_title
      end
      true
    rescue
      false
    end

    def static_coast_dir_passable?(dir)
      return false unless [2, 4, 6, 8].include?(dir.to_i)
      return false unless defined?($game_player) && $game_player
      @last_static_coast_block_reason = nil
      if static_coast_live_event_blocked?(dir)
        @last_static_coast_block_reason = "live event #{dir}"
        return false
      end
      if $game_player.respond_to?(:can_move_in_direction?)
        ok = $game_player.can_move_in_direction?(dir)
        @last_static_coast_block_reason = "tile #{dir}" unless ok
        return ok
      end
      if defined?(AutoplayBot::Pathfinder) && AutoplayBot::Pathfinder.respond_to?(:passable?)
        ok = AutoplayBot::Pathfinder.passable?($game_player.x, $game_player.y, dir)
        @last_static_coast_block_reason = "path #{dir}" unless ok
        return ok
      end
      ok = $game_player.respond_to?(:passable?) && $game_player.passable?($game_player.x, $game_player.y, dir)
      @last_static_coast_block_reason = "passable #{dir}" unless ok
      ok
    rescue
      @last_static_coast_block_reason = "error"
      false
    end

    def static_coast_live_event_blocked?(dir)
      return false unless [2, 4, 6, 8].include?(dir.to_i)
      return false unless defined?($game_player) && $game_player
      return false unless defined?($game_map) && $game_map && $game_map.respond_to?(:events)
      dx, dy = case dir.to_i
               when 2 then [0, 1]
               when 4 then [-1, 0]
               when 6 then [1, 0]
               when 8 then [0, -1]
               else [0, 0]
               end
      tx = $game_player.x.to_i + dx
      ty = $game_player.y.to_i + dy
      events = $game_map.events ? $game_map.events.values : []
      events.any? { |event| static_coast_blocking_event_at?(event, tx, ty) }
    rescue
      false
    end

    def static_coast_blocking_event_at?(event, tx, ty)
      return false unless event && event.respond_to?(:x) && event.respond_to?(:y)
      return false unless event.x.to_i == tx.to_i && event.y.to_i == ty.to_i
      return false if event_flag_true?(event, :erased) || event_flag_true?(event, :erased?)
      return false if event_flag_true?(event, :through)
      return false if event_flag_true?(event, :transparent)
      priority = event_numeric_attr(event, :priority_type, :@priority_type)
      return false if !priority.nil? && priority.to_i != 1
      has_sprite = !event_string_attr(event, :character_name, :@character_name).empty?
      tile_id = event_numeric_attr(event, :tile_id, :@tile_id).to_i
      has_sprite || tile_id > 0
    rescue
      false
    end

    def event_flag_true?(event, method_name)
      return !!event.send(method_name) if event.respond_to?(method_name)
      ivar = :"@#{method_name.to_s.sub(/\?$/, '')}"
      event.instance_variable_defined?(ivar) && !!event.instance_variable_get(ivar)
    rescue
      false
    end

    def event_string_attr(event, method_name, ivar)
      return event.send(method_name).to_s if event.respond_to?(method_name)
      event.instance_variable_defined?(ivar) ? event.instance_variable_get(ivar).to_s : ""
    rescue
      ""
    end

    def event_numeric_attr(event, method_name, ivar)
      return event.send(method_name) if event.respond_to?(method_name)
      event.instance_variable_defined?(ivar) ? event.instance_variable_get(ivar) : nil
    rescue
      nil
    end

    def notify_static_coast_block!(dir, reason)
      if defined?(AutoplayBot::Navigator) &&
         AutoplayBot::Navigator.respond_to?(:note_static_coast_block!)
        AutoplayBot::Navigator.note_static_coast_block!(dir, reason)
      end
      if defined?(AutoplayBot::BotCore) &&
         AutoplayBot::BotCore.respond_to?(:note_static_coast_block!)
        AutoplayBot::BotCore.note_static_coast_block!(dir, reason)
      end
    rescue
      nil
    end

    def stale_static_coast_input?(dir)
      return false unless defined?($game_player) && $game_player
      frame = (Graphics.frame_count rescue 0).to_i
      now = current_time_seconds
      key = [
        (defined?($game_map) && $game_map ? $game_map.map_id : nil),
        $game_player.x,
        $game_player.y,
        dir.to_i
      ]
      if @static_coast_key == key
        elapsed = frame - @static_coast_frame.to_i
        elapsed_time = now - @static_coast_time.to_f
        return true if elapsed_time > static_coast_input_seconds_limit
        return true if elapsed > static_coast_input_limit
      else
        @static_coast_key = key
        @static_coast_frame = frame
        @static_coast_time = now
      end
      false
    rescue
      false
    end

    def clear_static_coast_input!
      @static_coast_key = nil
      @static_coast_frame = nil
      @static_coast_time = nil
    rescue
      nil
    end

    def static_coast_input_limit
      # A legitimate step should begin quickly; long static input is almost
      # always the bot waiting on a stale direction after a rail or encounter.
      speed = game_speed_multiplier
      return 2 if speed >= 7
      return 5 if speed >= 3
      12
    rescue
      5
    end

    def static_coast_input_seconds_limit
      speed = game_speed_multiplier
      return 0.035 if speed >= 7
      return 0.08 if speed >= 3
      0.16
    rescue
      0.08
    end

    def performance_coast?
      frame = (Graphics.frame_count rescue 0).to_i
      return true if startup_light?
      return true if map_movement_coasting?
      @last_movement_coast_frame && frame - @last_movement_coast_frame.to_i < 36
    rescue
      false
    end

    def dialog_tick
      return unless dialog_control?
      emergency_hotkey_stop
      return unless dialog_control?
      if human_override_active?
        return if prompt_human_override_hold?("dialog")
        clear_human_override_for_prompt!("dialog")
      end
      now = current_time_seconds
      @last_dialog_time ||= 0.0
      return if now - @last_dialog_time.to_f < (game_speed_multiplier >= 5 ? 0.10 : 0.08)
      @last_dialog_time = now
      @last_dialog_frame = (Graphics.frame_count rescue 0).to_i
      if human_confirm_input_active?
        throttled_prompt_status("dialog: player input")
        return
      end
      throttled_prompt_status("dialog: advancing")
      frames = prompt_hold_frames
      if AutoplayBot::InputQueue.respond_to?(:tap_next)
        AutoplayBot::InputQueue.tap_next(:USE, frames)
      else
        AutoplayBot::InputQueue.tap(:USE, frames)
      end
    rescue
      nil
    end

    def after_graphics_update
      return if @inside_graphics_update || @inside_update
      @inside_graphics_update = true
      install! unless @installed
      observe_game_speed!
      graphics_hotkey_tick
      process_armed_start if @mode == "arming"
      flush_pending_start_feedback
      AutoplayBot::Overlay.update(false) if defined?(AutoplayBot::Overlay) && overlay_visible?
      return unless active?
      battle_intro_speed_lock_tick if running?
      capture_storage_watchdog_tick if running?
      black_transition_watchdog_tick if running?
      stale_map_menu_watchdog_tick if running? || @mode == "arming"
      if running? && battle_context? && bot_battle_fast_forward?
        hide_battle_ability_splash! if battle_ability_splash_active?
      end
      if running? && battle_context? &&
         (post_capture_confirm_active? ||
          battle_ability_splash_active? ||
          battle_startup_transition_protected? ||
          (forced_input_context? && battle_prompt_label?(@forced_input_label)))
        battle_scene_idle_confirm_tick("battle")
      end
    rescue
      nil
    ensure
      @inside_graphics_update = false
    end

    def flush_pending_start_feedback
      return unless @pending_start_feedback_text
      return unless defined?(AutoplayBot::Overlay)
      text = @pending_start_feedback_text
      @pending_start_feedback_text = nil
      AutoplayBot::Overlay.quick_feedback!(text, true)
      AutoplayBot::Overlay.request_refresh!
    rescue
      @pending_start_feedback_text = nil
    end

    def graphics_hotkey_tick
      return unless enabled?
      refresh_hotkey_latch
      return unless @hotkey_armed
      return unless async_hotkey_down? || hotkey_down?
      frame = Graphics.frame_count rescue 0
      now = current_time_seconds
      @last_hotkey_at = -9999.0 if @last_hotkey_at.nil?
      return if now - @last_hotkey_at.to_f < 0.25
      @last_hotkey_at = now
      @last_hotkey_frame = frame.to_i
      disarm_hotkey
      if active?
        stop!("user hotkey")
      else
        start!("user hotkey", 0, true)
      end
    rescue
      nil
    end

    def emergency_hotkey_stop
      return unless active?
      return unless hotkey_down?
      frame = Graphics.frame_count rescue 0
      now = current_time_seconds
      @last_emergency_hotkey_at = -9999.0 if @last_emergency_hotkey_at.nil?
      return if now - @last_emergency_hotkey_at.to_f < 0.25
      return if @last_hotkey_at && now - @last_hotkey_at.to_f < 0.22
      @last_emergency_hotkey_at = now
      @last_emergency_hotkey_frame = frame.to_i
      @last_hotkey_frame = frame.to_i
      @last_hotkey_at = now
      disarm_hotkey
      stop!("user hotkey")
    rescue
      nil
    end

    def hotkey_down?
      button = AutoplayBot::Config.pause_button
      return false unless button
      return true if async_hotkey_down?(button)
      if Input.respond_to?(:autoplay_bot_original_press?)
        return Input.autoplay_bot_original_press?(button)
      end
      Input.press?(button)
    rescue
      false
    end

    def async_hotkey_down?(_button = nil)
      vk = hotkey_virtual_key
      return false unless vk
      api = get_async_key_state_api
      return false unless api
      (api.call(vk).to_i & 0x8000) != 0
    rescue
      false
    end

    def get_async_key_state_api
      return @get_async_key_state_api if defined?(@get_async_key_state_api)
      @get_async_key_state_api = nil
      return nil unless defined?(Win32API)
      @get_async_key_state_api = Win32API.new("user32", "GetAsyncKeyState", "i", "i")
    rescue
      @get_async_key_state_api = nil
    end

    def hotkey_virtual_key
      label = AutoplayBot::Config.get("pause_key", "F5").to_s.upcase
      return 0x70 + Regexp.last_match(1).to_i - 1 if label =~ /^F([1-9]|1[0-2])$/
      return 0x1B if ["ESC", "ESCAPE"].include?(label)
      return 0x20 if label == "SPACE"
      return label.unpack("C").first if label.length == 1 && label =~ /[A-Z0-9]/
      nil
    rescue
      nil
    end

    def human_override_active?
      @human_override_active == true
    rescue
      false
    end

    def human_override_tick
      return unless running?
      return if forced_input_context?
      frame = (Graphics.frame_count rescue 0).to_i
      now = current_time_seconds

      if battle_context?
        return unless @human_override_active
        if frame - @human_override_last_frame.to_i < 180 &&
           now - @human_override_last_at.to_f < 3.0
          AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
          AutoplayBot.status("override: battle wait")
          return
        end
        @human_override_active = false
        @human_override_last_frame = nil
        @human_override_last_at = nil
        @battle_idle_started_frame = frame - 180
        @battle_idle_started_at = now - 3.0
        AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
        director_notified = false
        if defined?(AutoplayBot::Director) &&
           AutoplayBot::Director.respond_to?(:note_human_override_complete!)
          AutoplayBot::Director.note_human_override_complete!("battle")
          director_notified = true
        end
        AutoplayBot.status("override: battle resumed") unless director_notified
        return
      end

      if human_movement_input?
        unless @human_override_active
          if defined?(AutoplayBot::Director) &&
             AutoplayBot::Director.respond_to?(:note_human_override_start!)
            AutoplayBot::Director.note_human_override_start!
          end
        end
        @human_override_active = true
        @human_override_last_frame = frame
        @human_override_last_at = now
        AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
        AutoplayBot.status("override: player walking")
        return
      end
      return unless @human_override_active
      if frame - @human_override_last_frame.to_i < 180 &&
         now - @human_override_last_at.to_f < 3.0
        AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
        AutoplayBot.status("override: waiting 3s")
        return
      end
      @human_override_active = false
      @human_override_last_frame = nil
      @human_override_last_at = nil
      director_notified = false
      if defined?(AutoplayBot::Director) &&
         AutoplayBot::Director.respond_to?(:note_human_override_complete!)
        AutoplayBot::Director.note_human_override_complete!("player control")
        director_notified = true
      end
      AutoplayBot.status("override: released") unless director_notified
    rescue
      @human_override_active = false
    end

    def human_movement_input?
      return false unless defined?(Input)
      return false if battle_context?
      if Input.respond_to?(:autoplay_bot_original_dir8)
        dir = Input.autoplay_bot_original_dir8 rescue 0
        return true if dir.to_i > 0
      end
      [:UP, :DOWN, :LEFT, :RIGHT].any? do |name|
        next false unless Input.const_defined?(name)
        button = Input.const_get(name)
        if Input.respond_to?(:autoplay_bot_original_press?)
          Input.autoplay_bot_original_press?(button)
        else
          Input.press?(button)
        end
      end
    rescue
      false
    end

    def status_text
      mode = @mode || "idle"
      state_ready = defined?(AutoplayBot::State) &&
                    (!AutoplayBot::State.respond_to?(:loaded?) || AutoplayBot::State.loaded?)
      state_ready = false if mode == "arming"
      objective = nil
      objective = AutoplayBot::State.current_objective if state_ready
      label = objective && (objective["label"] || objective["id"])
      coasting = performance_coast?
      pos = if defined?($game_player) && $game_player && defined?($game_map) && $game_map
              "M#{$game_map.map_id} #{$game_player.x},#{$game_player.y}"
            else
              "no map"
            end
      money = nil
      money = "$#{$Trainer.money.to_i}" if defined?($Trainer) && $Trainer && $Trainer.respond_to?(:money)
      mission = nil
      mission = AutoplayBot::MissionControl.summary if !coasting && !startup_diagnostics_active? && state_ready && defined?(AutoplayBot::MissionControl) && AutoplayBot::MissionControl.respond_to?(:summary)
      lines = [join_status_bits(["Bot #{mode}", pos, money, short_text(mission, 24)])]
      lines.concat(running_startup_diagnostic_lines) if mode == "running"
      if mode == "running" && startup_light?
        left = @startup_light_until_at ? [@startup_light_until_at.to_f - current_time_seconds, 0.0].max : 0.0
        lines << "Startup fast #{format('%.2f', left)}s | movement live"
        lines.concat(start_diagnostic_lines[0, 2])
      end
      if mode == "running" && battle_context?
        lines << join_status_bits(["Scene battle", battle_context_overlay_detail])
        lines << "Now #{short_text(AutoplayBot.status_message, 58)}"
        if @last_battle_dialog_text && !@last_battle_dialog_text.to_s.empty?
          lines << "Text #{short_text(@last_battle_dialog_text, 58)}"
        end
        return lines[0, 4].join("\n")
      end
      if coasting && mode == "running"
        runtime_mode = AutoplayBot::State.runtime_mode rescue nil
        lines << "Mode #{short_text(runtime_mode, 18)}" if runtime_mode && !runtime_mode.to_s.empty?
        lines << "Now #{short_text(AutoplayBot.status_message, 58)}"
        return lines[0, 4].join("\n")
      end
      if mode == "arming"
        lines.concat(start_diagnostic_lines)
      end
      if state_ready
        runtime_mode = AutoplayBot::State.runtime_mode rescue nil
        stuck = AutoplayBot::State.last_stuck_signature rescue nil
        mode_bits = []
        mode_bits << "Mode #{short_text(runtime_mode, 16)}" if runtime_mode && !runtime_mode.to_s.empty?
        if stuck_overlay_visible?(stuck) && stuck["reason"] && !stuck["reason"].to_s.empty?
          mode_bits << "Avoid #{short_text(stuck_overlay_summary(stuck), 28)}"
        end
        retries = AutoplayBot::State.objective_retry_count(objective) rescue 0
        mode_bits << "Retry #{retries}" if retries.to_i > 0
        if human_override_active?
          left = 3 - (((Graphics.frame_count rescue 0).to_i - @human_override_last_frame.to_i) / 60)
          mode_bits << "Override #{[left, 0].max}s"
        end
        lines << join_status_bits(mode_bits) unless mode_bits.empty?
        recovery = AutoplayBot::State.recovery_plan rescue nil
        route_bits = []
        if recovery && recovery["reason"] && !recovery["reason"].to_s.empty?
          route_bits << "Recovery #{short_text(recovery["reason"], 24)}"
        end
        heal_route = AutoplayBot::State.last_heal_route rescue nil
        if heal_route && heal_route["label"] && !heal_route["label"].to_s.empty?
          route_bits << "Heal #{short_text(heal_route["label"], 24)}"
        end
        lines << join_status_bits(route_bits) unless route_bits.empty?
        active_goal = AutoplayBot::State.active_goal rescue nil
        if active_goal && active_goal["kind"]
          detail = [
            active_goal["kind"],
            ("s#{active_goal["score"]}" if active_goal["score"]),
            ("p#{active_goal["path"]}" if active_goal["path"]),
            active_goal["label"]
          ].compact.join(" ")
          lines << "Think #{short_text(detail, 58)}" unless detail.empty?
        end
        if defined?(AutoplayBot::BotCore) && AutoplayBot::BotCore.respond_to?(:debug_overlay_lines)
          lines.concat(AutoplayBot::BotCore.debug_overlay_lines)
        elsif defined?(AutoplayBot::Director) && AutoplayBot::Director.respond_to?(:debug_overlay_lines)
          lines.concat(AutoplayBot::Director.debug_overlay_lines)
        end
      elsif mode == "running" && defined?(AutoplayBot::BotCore) && AutoplayBot::BotCore.respond_to?(:debug_overlay_lines)
        lines.concat(AutoplayBot::BotCore.debug_overlay_lines)
      end
      lines << join_status_bits(["Goal #{short_text(label, 28)}", "Now #{short_text(AutoplayBot.status_message, 30)}"]) if label && !label.to_s.empty?
      lines << "Now #{short_text(AutoplayBot.status_message, 58)}" if !label || label.to_s.empty?
      if mode == "running" && !startup_light? &&
         defined?(AutoplayBot::ResourcePlanner) &&
         (!defined?(AutoplayBot::Config) || AutoplayBot::Config.resource_overlay_detail != "off")
        plan = AutoplayBot::ResourcePlanner.current_plan rescue nil
        need = plan && plan["need"]
        lines << "Need #{short_text(need.join(', '), 58)}" if need && need.respond_to?(:empty?) && !need.empty?
      end
      history = AutoplayBot.status_history.map { |entry| entry["text"] }.reject { |text| text == AutoplayBot.status_message }.last(2)
      lines << "Recent #{short_text(history.join(' > '), 58)}" unless history.empty?
      lines.join("\n")
    rescue
      "Bot status unavailable"
    end

    def battle_context_overlay_detail
      bits = []
      bits << "engine" if @battle_engine_active
      bits << "raw" if raw_battle_flag_active?
      bits << "scene" if real_battle_scene?
      bits << "message" if battle_message_context? || recent_battle_message_active?
      bits << "prompt" if battle_prompt_context?
      bits << "x#{game_speed_multiplier}"
      bits.reject { |bit| bit.to_s.empty? }.join(" ")
    rescue
      "active"
    end

    def running_startup_diagnostic_lines
      return [] unless @mode == "running"
      age = @started_at ? current_time_seconds - @started_at.to_f : 0.0
      lines = []
      if startup_light?
        left = @startup_light_until_at ? [@startup_light_until_at.to_f - current_time_seconds, 0.0].max : 0.0
        lines << "Startup #{startup_spinner} light takeover #{format('%.1f', left)}s | age #{format('%.1f', age)}s"
      elsif @startup_bootstrap_pending
        phase = [[@startup_bootstrap_phase.to_i + 1, 1].max, 6].min
        lines << "Startup #{startup_spinner} bootstrap #{phase}/6 | age #{format('%.1f', age)}s"
      elsif startup_memory_defer_active?
        left = startup_memory_defer_left_seconds
        label = state_ephemeral? ? "live memory ready" : (state_loaded? ? "settling runtime memory" : "preparing live memory")
        lines << "Startup #{startup_spinner} #{label} #{format('%.1f', left)}s"
      elsif defined?(AutoplayBot::BotCore) && AutoplayBot::BotCore.respond_to?(:startup_overlay_line)
        line = AutoplayBot::BotCore.startup_overlay_line
        lines << line if line && !line.to_s.empty?
      end
      lines[0, 2]
    rescue
      []
    end

    def startup_spinner
      frames = Graphics.frame_count rescue 0
      ["-", "\\", "|", "/"][(frames.to_i / 12) % 4]
    rescue
      "-"
    end

    def startup_memory_defer_left_seconds
      left_at = @started_at ? startup_memory_defer_seconds - (current_time_seconds - @started_at.to_f) : 0.0
      left_frame = 0.0
      if @started_frame
        remaining = startup_memory_defer_frames - ((Graphics.frame_count rescue 0).to_i - @started_frame.to_i)
        left_frame = remaining.to_f / 60.0
      end
      [[left_at, left_frame].max, 0.0].max
    rescue
      0.0
    end

    def startup_diagnostics_active?
      return false unless @mode == "running"
      return true if startup_light? || @startup_bootstrap_pending || startup_memory_defer_active?
      return false unless @started_at
      current_time_seconds - @started_at.to_f < 4.0
    rescue
      false
    end

    def startup_feedback_active?
      return true if @mode == "arming"
      startup_diagnostics_active?
    rescue
      false
    end

    def full_overlay_deferred?
      return false unless @mode == "arming"
      return false unless @armed_start_at
      current_time_seconds - @armed_start_at.to_f < 0.12
    rescue
      false
    end

    def startup_feedback_text
      mode = @mode || "idle"
      if mode == "arming"
        age = @armed_start_at ? current_time_seconds - @armed_start_at.to_f : 0.0
        reason = @armed_start_detail
        reason = @armed_start_detail if reason.nil? || reason.to_s.empty?
        return join_status_bits(["Bot arming #{startup_spinner}", "#{format('%.1f', age)}s", reason])
      end
      if mode == "running" && startup_diagnostics_active?
        diag = running_startup_diagnostic_lines.first
        return join_status_bits(["Bot starting #{startup_spinner}", short_text(AutoplayBot.status_message, 24), short_text(diag, 34)])
      end
      join_status_bits(["Bot #{mode}", AutoplayBot.status_message])
    rescue
      "Bot arming"
    end

    def instant_start_feedback_text
      scene_name = defined?($scene) && $scene ? $scene.class.to_s : "no scene"
      map_id = defined?($game_map) && $game_map ? $game_map.map_id : "?"
      join_status_bits(["Bot running", "instant", "scene #{short_text(scene_name, 18)}", "M#{map_id}", "F5 stop"])
    rescue
      "Bot running | instant | F5 stop"
    end

    def battle_or_menu_context_active?
      return true if battle_context?
      return true if menu_context_active?
      false
    rescue
      false
    end

    def context_interrupt_overworld_motion!(reason = "context", reset_planners = true)
      frame = (Graphics.frame_count rescue 0).to_i
      key = reason.to_s
      repeat = @last_context_interrupt_key == key
      unless repeat
        AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      end
      clear_static_coast_input!
      return if repeat || !reset_planners
      @last_context_interrupt_key = key
      @last_context_interrupt_frame = frame
      if defined?(AutoplayBot::Navigator) && AutoplayBot::Navigator.respond_to?(:reset!)
        AutoplayBot::Navigator.reset!(reason)
      end
      if defined?(AutoplayBot::BotCore) && AutoplayBot::BotCore.respond_to?(:context_interrupt!)
        AutoplayBot::BotCore.context_interrupt!(reason)
      end
    rescue
      nil
    end

    def clear_context_interrupt_latch!
      @last_context_interrupt_key = nil
      @last_context_interrupt_frame = nil
    rescue
      nil
    end

    def start_diagnostic_lines
      scene_name = defined?($scene) && $scene ? $scene.class.to_s : "no scene"
      temp_bits = []
      if defined?($game_temp) && $game_temp
        temp_bits << "battle=#{safe_bool($game_temp.in_battle)}"
        temp_bits << "menu=#{safe_bool($game_temp.in_menu)}"
        temp_bits << "msg=#{safe_bool($game_temp.message_window_showing)}"
        temp_bits << "xfer=#{safe_bool($game_temp.player_transferring || $game_temp.transition_processing || $game_temp.to_title)}"
      else
        temp_bits << "no temp"
      end
      player_bits = []
      if defined?($game_player) && $game_player
        player_bits << "moving=#{safe_bool($game_player.respond_to?(:moving?) && $game_player.moving?)}"
        player_bits << "forced=#{safe_bool($game_player.respond_to?(:move_route_forcing) && $game_player.move_route_forcing)}"
        player_bits << "hidden=#{safe_bool($game_player.respond_to?(:transparent) && $game_player.transparent)}"
      else
        player_bits << "no player"
      end
      surface_ready = live_overworld_surface?
      trainer_ready = trainer_ready?
      transfer_busy = defined?($game_temp) && $game_temp &&
                      ($game_temp.player_transferring || $game_temp.transition_processing || $game_temp.to_title)
      moving = defined?($game_player) && $game_player &&
               $game_player.respond_to?(:moving?) && $game_player.moving?
      block = if battle_context? || menu_context_active?
                "battle/menu"
              elsif !surface_ready
                "no map"
              elsif !trainer_ready
                "trainer setup"
              elsif transfer_busy
                "transfer"
              elsif moving
                "player moving"
              else
                "none"
              end
      armed_age = @armed_start_at ? (current_time_seconds - @armed_start_at.to_f).round(2) : 0
      [
        "Scene #{short_text(scene_name, 52)}",
        "Gate surface=#{safe_bool(surface_ready)} trainer=#{safe_bool(trainer_ready)} age=#{armed_age}s",
        "Block #{short_text(block, 46)}",
        "Temp #{temp_bits.join(' ')}",
        "Player #{player_bits.join(' ')}"
      ]
    rescue => e
      ["Diag failed #{e.class}"]
    end

    def safe_bool(value)
      value ? "Y" : "n"
    rescue
      "?"
    end

    def map_interpreter_running?
      Object.new.respond_to?(:pbMapInterpreterRunning?, true) && Object.new.send(:pbMapInterpreterRunning?)
    rescue
      false
    end

    def short_text(text, max = 46)
      value = text.to_s.gsub(/\s+/, " ").strip
      return value if value.length <= max
      "#{value[0, max - 3]}..."
    rescue
      ""
    end

    def join_status_bits(bits)
      Array(bits).compact.reject { |bit| bit.to_s.empty? }.join(" | ")
    rescue
      ""
    end

    def stuck_overlay_summary(stuck)
      details = stuck["details"].is_a?(Hash) ? stuck["details"] : {}
      bits = []
      bits << stuck["reason"].to_s
      label = details["name"] || details["key"]
      bits << label.to_s unless label.to_s.empty?
      if details["x"] && details["y"]
        bits << "@#{details["x"]},#{details["y"]}"
      end
      count = stuck["count"].to_i
      bits << "x#{count}" if count > 1
      bits.compact.reject { |bit| bit.to_s.empty? }.join(" ")
    rescue
      stuck && stuck["reason"] ? stuck["reason"].to_s : "stuck"
    end

    def stuck_overlay_visible?(stuck)
      return false unless stuck.is_a?(Hash)
      time = stuck["time"].to_i
      return false if time > 0 && Time.now.to_i - time > 45
      details = stuck["details"].is_a?(Hash) ? stuck["details"] : {}
      map_id = details["map_id"] || details["map"]
      if map_id && defined?($game_map) && $game_map
        return false if map_id.to_i != $game_map.map_id.to_i
      end
      true
    rescue
      false
    end
  end
end

module Input
  class << self
    alias autoplay_bot_original_update update unless method_defined?(:autoplay_bot_original_update)
    alias autoplay_bot_original_trigger? trigger? unless method_defined?(:autoplay_bot_original_trigger?)
    alias autoplay_bot_original_press? press? unless method_defined?(:autoplay_bot_original_press?)
    alias autoplay_bot_original_repeat? repeat? unless method_defined?(:autoplay_bot_original_repeat?)
    alias autoplay_bot_original_dir4 dir4 unless method_defined?(:autoplay_bot_original_dir4)
    alias autoplay_bot_original_dir8 dir8 unless method_defined?(:autoplay_bot_original_dir8)
  end

  def self.update
    autoplay_bot_original_update
    AutoplayBot::Runtime.after_input_update if defined?(AutoplayBot::Runtime)
  end

  def self.trigger?(button)
    return true if defined?(AutoplayBot::Runtime) &&
                   AutoplayBot::Runtime.respond_to?(:battle_dialog_confirm_trigger?) &&
                   AutoplayBot::Runtime.battle_dialog_confirm_trigger?(button)
    return true if defined?(AutoplayBot::Runtime) &&
                   AutoplayBot::Runtime.virtual_input_allowed? &&
                   AutoplayBot::InputQueue.triggered?(button)
    autoplay_bot_original_trigger?(button)
  end

  def self.press?(button)
    return true if defined?(AutoplayBot::Runtime) &&
                   AutoplayBot::Runtime.virtual_input_allowed? &&
                   AutoplayBot::InputQueue.pressed?(button)
    autoplay_bot_original_press?(button)
  end

  def self.repeat?(button)
    return true if defined?(AutoplayBot::Runtime) &&
                   AutoplayBot::Runtime.virtual_input_allowed? &&
                   AutoplayBot::InputQueue.repeated?(button)
    autoplay_bot_original_repeat?(button)
  end

  def self.dir4
    if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.virtual_input_allowed?
      virtual_dir = AutoplayBot::InputQueue.dir4
      return virtual_dir if virtual_dir && virtual_dir > 0
    end
    autoplay_bot_original_dir4
  end

  def self.dir8
    if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.virtual_input_allowed?
      virtual_dir = AutoplayBot::InputQueue.dir8
      return virtual_dir if virtual_dir && virtual_dir > 0
    end
    autoplay_bot_original_dir8
  end
end

module Graphics
  class << self
    alias autoplay_bot_original_update update unless method_defined?(:autoplay_bot_original_update)
    alias autoplay_bot_original_transition transition if method_defined?(:transition) && !method_defined?(:autoplay_bot_original_transition)
  end

  def self.update(*args)
    autoplay_bot_original_update(*args)
    AutoplayBot::Runtime.after_graphics_update if defined?(AutoplayBot::Runtime)
  end

  if respond_to?(:autoplay_bot_original_transition)
    def self.transition(*args)
      transition_guard = false
      if defined?(AutoplayBot::Runtime)
        transition_guard ||= AutoplayBot::Runtime.respond_to?(:battle_intro_speed_guard?) &&
                              AutoplayBot::Runtime.battle_intro_speed_guard?
      end
      if transition_guard && args[0].is_a?(Numeric)
        capped = AutoplayBot::Runtime.respond_to?(:battle_intro_transition_cap_frames) ? AutoplayBot::Runtime.battle_intro_transition_cap_frames : 12
        args = args.dup
        args[0] = [args[0].to_i, capped.to_i].min
      end
      autoplay_bot_original_transition(*args)
    end
  end
end

if defined?(Game_Player)
  class Game_Player
    alias autoplay_bot_original_update_command_new update_command_new unless method_defined?(:autoplay_bot_original_update_command_new)

    def update_command_new
      if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.virtual_input_allowed?
        dir = AutoplayBot::InputQueue.dir8
        if dir && dir > 0
          before_x = @x
          before_y = @y
          autoplay_bot_original_update_command_new
          return if (moving? rescue false)
          return if @x != before_x || @y != before_y
          if autoplay_bot_can_direct_move? && autoplay_bot_direct_move_fallback_ready?(dir)
            autoplay_bot_log_direct_move(dir)
            case dir
            when 2 then move_down
            when 4 then move_left
            when 6 then move_right
            when 8 then move_up
            end
            @lastdirframe = Graphics.frame_count if defined?(Graphics) && dir != @lastdir
            @lastdir = dir
            return
          end
          return
        end
      end
      @autoplay_bot_fallback_dir = nil
      autoplay_bot_original_update_command_new
    end

    def autoplay_bot_direct_move_fallback_ready?(dir)
      frame = Graphics.frame_count rescue 0
      if @autoplay_bot_fallback_dir != dir
        @autoplay_bot_fallback_dir = dir
        @autoplay_bot_fallback_frame = frame.to_i
        return false
      end
      frame.to_i - @autoplay_bot_fallback_frame.to_i >= 1
    rescue
      false
    end

    def autoplay_bot_can_direct_move?
      return false if moving? rescue false
      return false if defined?($game_temp) && $game_temp &&
                      (($game_temp.in_menu &&
                        !(defined?(AutoplayBot::Runtime) &&
                          AutoplayBot::Runtime.respond_to?(:map_menu_flag_ignored?) &&
                          AutoplayBot::Runtime.map_menu_flag_ignored?)) ||
                       $game_temp.in_battle || $game_temp.message_window_showing)
      return false if defined?($PokemonTemp) && $PokemonTemp && $PokemonTemp.respond_to?(:miniupdate) && $PokemonTemp.miniupdate
      if Object.new.respond_to?(:pbMapInterpreterRunning?, true)
        return false if Object.new.send(:pbMapInterpreterRunning?)
      end
      true
    rescue
      false
    end

    def autoplay_bot_log_direct_move(dir)
      frame = Graphics.frame_count rescue 0
      @autoplay_bot_last_direct_move_log = -9999 if @autoplay_bot_last_direct_move_log.nil?
      return if frame.to_i - @autoplay_bot_last_direct_move_log.to_i < 300
      @autoplay_bot_last_direct_move_log = frame.to_i
      AutoplayBot.log("player direct move dir=#{dir}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    rescue
      nil
    end
  end
end

module AutoplayBot
  module Overlay
    COMPACT_FONT_SIZE = 11 unless const_defined?(:COMPACT_FONT_SIZE)
    COMPACT_LINE_HEIGHT = 11 unless const_defined?(:COMPACT_LINE_HEIGHT)
    MAX_STATUS_LINES = 10 unless const_defined?(:MAX_STATUS_LINES)
    MAX_LINE_CHARS = 78 unless const_defined?(:MAX_LINE_CHARS)
    QUICK_WIDTH = 300 unless const_defined?(:QUICK_WIDTH)
    QUICK_HEIGHT = 46 unless const_defined?(:QUICK_HEIGHT)
    QUICK_FONT_SIZE = 14 unless const_defined?(:QUICK_FONT_SIZE)
    HUD_FONT_SIZE = 13 unless const_defined?(:HUD_FONT_SIZE)
    HUD_LINE_HEIGHT = 16 unless const_defined?(:HUD_LINE_HEIGHT)
    HUD_MARGIN = 8 unless const_defined?(:HUD_MARGIN)
    HUD_MIN_WIDTH = 320 unless const_defined?(:HUD_MIN_WIDTH)
    HUD_MAX_WIDTH = 624 unless const_defined?(:HUD_MAX_WIDTH)

    module_function

    def compact_hud?
      return false if defined?(AutoplayBot::Config) &&
                      AutoplayBot::Config.respond_to?(:overlay_mode) &&
                      AutoplayBot::Config.overlay_mode == "classic_window"
      return false if defined?(AutoplayBot::Config) &&
                      AutoplayBot::Config.respond_to?(:overlay_enabled?) &&
                      !AutoplayBot::Config.overlay_enabled?
      true
    rescue
      true
    end

    def create
      return create_hud if compact_hud?
      return unless defined?(Window_AdvancedTextPokemon) || defined?(Window_UnformattedTextPokemon)
      return unless defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.overlay_visible?
      dispose_window
      window_class = defined?(Window_AdvancedTextPokemon) ? Window_AdvancedTextPokemon : Window_UnformattedTextPokemon
      @overlay_shape = overlay_shape
      @window = window_class.newWithSize("", 6, 8, @overlay_shape["width"], @overlay_shape["height"])
      @window.z = 99998 if @window.respond_to?(:z=)
      @window.visible = true
      apply_compact_style
      update(true)
    rescue => e
      AutoplayBot.log("overlay create failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def update(force = false)
      return unless defined?(AutoplayBot::Runtime)
      return dispose unless AutoplayBot::Runtime.overlay_visible?
      if compact_hud?
        dispose_window
        dispose_quick_feedback
        update_hud(force)
        return
      end
      dispose_hud
      if AutoplayBot::Runtime.respond_to?(:startup_feedback_active?) &&
         AutoplayBot::Runtime.startup_feedback_active?
        quick_feedback!(AutoplayBot::Runtime.startup_feedback_text, force)
      end
      return if AutoplayBot::Runtime.respond_to?(:full_overlay_deferred?) &&
                AutoplayBot::Runtime.full_overlay_deferred?
      create unless window_alive?
      return unless window_alive?
      if @overlay_shape != overlay_shape
        dispose_window
        create
        return
      end
      frame = Graphics.frame_count rescue 0
      @last_update_frame = -9999 if @last_update_frame.nil?
      if @refresh_requested
        force = true
        @refresh_requested = false
      end
      return if !force && frame.to_i - @last_update_frame.to_i < update_interval_frames
      @last_update_frame = frame.to_i
      text = compact_text(AutoplayBot::Runtime.status_text)
      apply_compact_style
      if @window.text != text
        @window.text = text
        apply_compact_style
      end
      @window.visible = true
      dispose_quick_feedback if window_alive?
    rescue
      nil
    end

    def request_refresh!
      @refresh_requested = true
    rescue
      nil
    end

    def quick_feedback!(text = nil, force = true)
      return unless defined?(Sprite) && defined?(Bitmap)
      return unless defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.overlay_visible?
      frame = Graphics.frame_count rescue 0
      text = text.to_s
      text = AutoplayBot::Runtime.startup_feedback_text if text.empty? &&
                                                          AutoplayBot::Runtime.respond_to?(:startup_feedback_text)
      if compact_hud?
        update_hud(force, text)
        return
      end
      @quick_last_frame = -9999 if @quick_last_frame.nil?
      return if !force && quick_feedback_alive? && @quick_text == text &&
                frame.to_i - @quick_last_frame.to_i < 6
      create_quick_feedback unless quick_feedback_alive?
      return unless quick_feedback_alive?
      @quick_last_frame = frame.to_i
      @quick_text = text
      draw_quick_feedback(text)
      @quick_sprite.visible = true if @quick_sprite.respond_to?(:visible=)
    rescue => e
      AutoplayBot.log("overlay quick feedback failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def create_quick_feedback
      dispose_quick_feedback
      @quick_bitmap = Bitmap.new(QUICK_WIDTH, QUICK_HEIGHT)
      @quick_sprite = Sprite.new
      @quick_sprite.bitmap = @quick_bitmap if @quick_sprite.respond_to?(:bitmap=)
      @quick_sprite.x = 8 if @quick_sprite.respond_to?(:x=)
      @quick_sprite.y = 8 if @quick_sprite.respond_to?(:y=)
      @quick_sprite.z = 99999 if @quick_sprite.respond_to?(:z=)
    rescue => e
      @quick_bitmap = nil
      @quick_sprite = nil
      AutoplayBot.log("overlay quick create failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def draw_quick_feedback(text)
      return unless @quick_bitmap
      @quick_bitmap.clear if @quick_bitmap.respond_to?(:clear)
      bg = defined?(Color) ? Color.new(0, 0, 0, 178) : nil
      border = defined?(Color) ? Color.new(230, 230, 230, 230) : nil
      white = defined?(Color) ? Color.new(255, 255, 255, 255) : nil
      soft = defined?(Color) ? Color.new(200, 220, 255, 255) : nil
      @quick_bitmap.fill_rect(0, 0, QUICK_WIDTH, QUICK_HEIGHT, bg) if bg
      @quick_bitmap.fill_rect(0, 0, QUICK_WIDTH, 2, border) if border
      @quick_bitmap.fill_rect(0, QUICK_HEIGHT - 2, QUICK_WIDTH, 2, border) if border
      font = @quick_bitmap.respond_to?(:font) ? @quick_bitmap.font : nil
      font.size = QUICK_FONT_SIZE if font && font.respond_to?(:size=)
      font.color = white if font && white && font.respond_to?(:color=)
      lines = text.to_s.split(/\s*\|\s*/).map { |line| quick_trim_line(line) }.reject { |line| line.empty? }
      lines = ["Bot arming", "waiting for game"] if lines.empty?
      first = lines.shift.to_s
      second = quick_trim_line(lines.join(" | "))
      @quick_bitmap.draw_text(8, 4, QUICK_WIDTH - 16, 18, first)
      if second && !second.empty?
        font.color = soft if font && soft && font.respond_to?(:color=)
        @quick_bitmap.draw_text(8, 24, QUICK_WIDTH - 16, 18, second)
      end
    rescue => e
      AutoplayBot.log("overlay quick draw failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def quick_trim_line(line)
      value = line.to_s.gsub(/\s+/, " ").strip
      max = 34
      return value if value.length <= max
      "#{value[0, max - 3]}..."
    rescue
      line.to_s
    end

    def update_hud(force = false, quick_text = nil)
      return unless defined?(Sprite) && defined?(Bitmap)
      create_hud unless hud_alive?
      return unless hud_alive?
      shape = hud_shape
      if @hud_shape != shape
        dispose_hud
        create_hud
        return unless hud_alive?
      end
      frame = Graphics.frame_count rescue 0
      @last_hud_update_frame = -9999 if @last_hud_update_frame.nil?
      if @refresh_requested
        force = true
        @refresh_requested = false
      end
      interval = hud_update_interval_frames
      return if !force && quick_text.nil? && frame.to_i - @last_hud_update_frame.to_i < interval
      return if !force && !quick_text.nil? && @hud_quick_text == quick_text &&
                frame.to_i - @last_hud_update_frame.to_i < 4
      @last_hud_update_frame = frame.to_i
      @hud_quick_text = quick_text
      lines = hud_lines(quick_text)
      signature = lines.join("\n")
      @last_hud_draw_frame = -9999 if @last_hud_draw_frame.nil?
      return if !force && @hud_signature == signature &&
                frame.to_i - @last_hud_draw_frame.to_i < interval
      @hud_signature = signature
      @last_hud_draw_frame = frame.to_i
      draw_hud(lines)
      @hud_sprite.visible = true if @hud_sprite.respond_to?(:visible=)
    rescue => e
      AutoplayBot.log("overlay hud update failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def create_hud
      dispose_hud
      @hud_shape = hud_shape
      @hud_bitmap = Bitmap.new(@hud_shape["width"], @hud_shape["height"])
      @hud_sprite = Sprite.new
      @hud_sprite.bitmap = @hud_bitmap if @hud_sprite.respond_to?(:bitmap=)
      @hud_sprite.x = HUD_MARGIN if @hud_sprite.respond_to?(:x=)
      @hud_sprite.y = HUD_MARGIN if @hud_sprite.respond_to?(:y=)
      @hud_sprite.z = 99999 if @hud_sprite.respond_to?(:z=)
    rescue => e
      @hud_shape = nil
      @hud_bitmap = nil
      @hud_sprite = nil
      AutoplayBot.log("overlay hud create failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def hud_shape
      screen_width = Graphics.width rescue 640
      width = [[screen_width.to_i - (HUD_MARGIN * 2), HUD_MAX_WIDTH].min, HUD_MIN_WIDTH].max
      limit = hud_line_limit
      height = 12 + (limit * HUD_LINE_HEIGHT)
      { "width" => width, "height" => height }
    rescue
      { "width" => 520, "height" => 76 }
    end

    def hud_line_limit
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.respond_to?(:battle_overlay_hidden?) &&
         AutoplayBot::Runtime.battle_overlay_hidden?
        return 3
      end
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.respond_to?(:performance_coast?) &&
         AutoplayBot::Runtime.performance_coast?
        return 4
      end
      5
    rescue
      4
    end

    def hud_update_interval_frames
      return 4 if AutoplayBot::Runtime.respond_to?(:arming?) && AutoplayBot::Runtime.arming?
      return 6 if AutoplayBot::Runtime.respond_to?(:startup_diagnostics_active?) &&
                  AutoplayBot::Runtime.startup_diagnostics_active?
      return 18 if AutoplayBot::Runtime.respond_to?(:battle_overlay_hidden?) &&
                   AutoplayBot::Runtime.battle_overlay_hidden?
      AutoplayBot::Runtime.performance_coast? ? 45 : 18
    rescue
      18
    end

    def hud_lines(quick_text = nil)
      raw = quick_text && !quick_text.to_s.empty? ? quick_text.to_s : AutoplayBot::Runtime.status_text.to_s
      lines = raw.split(quick_text ? /\s*\|\s*/ : /\n/).map { |line| trim_hud_line(line) }
      lines = lines.reject { |line| line.nil? || line.empty? }
      lines = ["Bot starting", "waiting for game"] if lines.empty?
      speed = AutoplayBot::Runtime.respond_to?(:game_speed_multiplier) ? AutoplayBot::Runtime.game_speed_multiplier : nil
      hint = AutoplayBot::Runtime.respond_to?(:arming?) && AutoplayBot::Runtime.arming? ? "F5 cancel" : "F5 stop"
      header = [lines.shift, (speed ? "x#{speed}" : nil), hint].compact.reject { |bit| bit.to_s.empty? }.join(" | ")
      result = [trim_hud_line(header)]
      result.concat(lines)
      result[0, hud_line_limit]
    rescue
      ["Bot status unavailable"]
    end

    def draw_hud(lines)
      return unless @hud_bitmap
      @hud_bitmap.clear if @hud_bitmap.respond_to?(:clear)
      width = @hud_shape && @hud_shape["width"] ? @hud_shape["width"].to_i : HUD_MIN_WIDTH
      height = @hud_shape && @hud_shape["height"] ? @hud_shape["height"].to_i : 76
      bg = defined?(Color) ? Color.new(0, 0, 0, 166) : nil
      border = defined?(Color) ? Color.new(220, 230, 240, 210) : nil
      accent = hud_accent_color
      white = defined?(Color) ? Color.new(255, 255, 255, 255) : nil
      soft = defined?(Color) ? Color.new(202, 220, 238, 255) : nil
      @hud_bitmap.fill_rect(0, 0, width, height, bg) if bg
      @hud_bitmap.fill_rect(0, 0, width, 2, border) if border
      @hud_bitmap.fill_rect(0, height - 2, width, 2, border) if border
      @hud_bitmap.fill_rect(0, 0, 4, height, accent) if accent
      font = @hud_bitmap.respond_to?(:font) ? @hud_bitmap.font : nil
      font.size = HUD_FONT_SIZE if font && font.respond_to?(:size=)
      y = 6
      lines.each_with_index do |line, index|
        font.color = (index == 0 ? white : soft) if font && font.respond_to?(:color=)
        @hud_bitmap.draw_text(10, y, width - 18, HUD_LINE_HEIGHT, line.to_s)
        y += HUD_LINE_HEIGHT
      end
    rescue => e
      AutoplayBot.log("overlay hud draw failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def hud_accent_color
      return nil unless defined?(Color)
      mode = AutoplayBot::Runtime.instance_variable_get(:@mode) rescue nil
      case mode.to_s
      when "arming" then Color.new(255, 206, 72, 230)
      when "running" then Color.new(92, 224, 150, 230)
      else Color.new(180, 190, 205, 220)
      end
    rescue
      nil
    end

    def trim_hud_line(line)
      value = line.to_s.gsub(/\s+/, " ").strip
      max = hud_char_limit
      return value if value.length <= max
      "#{value[0, max - 3]}..."
    rescue
      line.to_s
    end

    def hud_char_limit
      width = @hud_shape && @hud_shape["width"] ? @hud_shape["width"].to_i : (Graphics.width rescue 640)
      [[(width - 22) / 7, 36].max, 92].min
    rescue
      70
    end

    def compact_text(text)
      lines = text.to_s.split(/\n/)
      lines = lines.reject { |line| line.nil? || line.empty? }.map { |line| trim_line(line) }
      limit = status_line_limit
      return lines.join("\n") if lines.length <= limit
      lines[0, limit].join("\n")
    rescue
      text.to_s
    end

    def trim_line(line)
      value = line.to_s.gsub(/\s+/, " ").strip
      return value if value.length <= MAX_LINE_CHARS
      "#{value[0, MAX_LINE_CHARS - 3]}..."
    rescue
      line.to_s
    end

    def overlay_width
      width = Graphics.width rescue 640
      [[width.to_i - 12, 560].min, 420].max
    rescue
      520
    end

    def overlay_shape
      height = AutoplayBot::Runtime.performance_coast? ? 112 : 154
      { "width" => overlay_width, "height" => height }
    rescue
      { "width" => 520, "height" => 154 }
    end

    def update_interval_frames
      return 6 if AutoplayBot::Runtime.respond_to?(:arming?) && AutoplayBot::Runtime.arming?
      return 12 if AutoplayBot::Runtime.respond_to?(:startup_diagnostics_active?) &&
                   AutoplayBot::Runtime.startup_diagnostics_active?
      AutoplayBot::Runtime.performance_coast? ? 60 : 24
    rescue
      24
    end

    def status_line_limit
      AutoplayBot::Runtime.performance_coast? ? 5 : MAX_STATUS_LINES
    rescue
      MAX_STATUS_LINES
    end

    def apply_compact_style
      return unless @window
      if @window.respond_to?(:lineHeight)
        current_height = @window.instance_variable_get(:@lineHeight) rescue nil
        @window.lineHeight(COMPACT_LINE_HEIGHT) if current_height.to_i != COMPACT_LINE_HEIGHT
      else
        @window.instance_variable_set(:@lineHeight, COMPACT_LINE_HEIGHT) if @window.instance_variable_defined?(:@lineHeight)
        @window.instance_variable_set(:@lineheight, COMPACT_LINE_HEIGHT) if @window.instance_variable_defined?(:@lineheight)
      end
      apply_font_to(@window)
      if @window.respond_to?(:contents)
        contents = @window.contents rescue nil
        apply_font_to(contents) if contents
      end
    rescue
      nil
    end

    def apply_font_to(target)
      return unless target
      font = target.respond_to?(:font) ? target.font : nil
      return unless font && font.respond_to?(:size=)
      font.size = COMPACT_FONT_SIZE
    rescue
      nil
    end

    def dispose
      dispose_window
      dispose_quick_feedback
      dispose_hud
    rescue
      @window = nil
      @quick_sprite = nil
      @quick_bitmap = nil
      @hud_sprite = nil
      @hud_bitmap = nil
    end

    def dispose_window
      @window.dispose if window_alive?
      @window = nil
      @overlay_shape = nil
    rescue
      @window = nil
      @overlay_shape = nil
    end

    def dispose_quick_feedback
      if @quick_sprite && @quick_sprite.respond_to?(:dispose)
        @quick_sprite.dispose unless @quick_sprite.respond_to?(:disposed?) && @quick_sprite.disposed?
      end
      if @quick_bitmap && @quick_bitmap.respond_to?(:disposed?)
        @quick_bitmap.dispose unless @quick_bitmap.disposed?
      elsif @quick_bitmap && @quick_bitmap.respond_to?(:dispose)
        @quick_bitmap.dispose
      end
      @quick_sprite = nil
      @quick_bitmap = nil
      @quick_text = nil
    rescue
      @quick_sprite = nil
      @quick_bitmap = nil
      @quick_text = nil
    end

    def dispose_hud
      if @hud_sprite && @hud_sprite.respond_to?(:dispose)
        @hud_sprite.dispose unless @hud_sprite.respond_to?(:disposed?) && @hud_sprite.disposed?
      end
      if @hud_bitmap && @hud_bitmap.respond_to?(:disposed?)
        @hud_bitmap.dispose unless @hud_bitmap.disposed?
      elsif @hud_bitmap && @hud_bitmap.respond_to?(:dispose)
        @hud_bitmap.dispose
      end
      @hud_sprite = nil
      @hud_bitmap = nil
      @hud_shape = nil
      @hud_signature = nil
      @hud_quick_text = nil
    rescue
      @hud_sprite = nil
      @hud_bitmap = nil
      @hud_shape = nil
    end

    def window_alive?
      return false unless @window
      return true unless @window.respond_to?(:disposed?)
      !@window.disposed?
    rescue
      false
    end

    def quick_feedback_alive?
      return false unless @quick_sprite && @quick_bitmap
      return false if @quick_sprite.respond_to?(:disposed?) && @quick_sprite.disposed?
      return false if @quick_bitmap.respond_to?(:disposed?) && @quick_bitmap.disposed?
      true
    rescue
      false
    end

    def hud_alive?
      return false unless @hud_sprite && @hud_bitmap
      return false if @hud_sprite.respond_to?(:disposed?) && @hud_sprite.disposed?
      return false if @hud_bitmap.respond_to?(:disposed?) && @hud_bitmap.disposed?
      true
    rescue
      false
    end
  end
end

if defined?(Scene_Map)
  class Scene_Map
    alias autoplay_bot_original_createSpritesets createSpritesets unless method_defined?(:autoplay_bot_original_createSpritesets)
    alias autoplay_bot_original_update update unless method_defined?(:autoplay_bot_original_update)
    alias autoplay_bot_original_dispose dispose unless method_defined?(:autoplay_bot_original_dispose)

    def createSpritesets
      autoplay_bot_original_createSpritesets
      AutoplayBot::Overlay.update(true) if defined?(AutoplayBot::Overlay)
    end

    def update
      autoplay_bot_original_update
      AutoplayBot::Overlay.update if defined?(AutoplayBot::Overlay)
    end

    def dispose
      AutoplayBot::Overlay.dispose if defined?(AutoplayBot::Overlay)
      autoplay_bot_original_dispose
    end
  end
end

if defined?(PokemonPauseMenu_Scene)
  class PokemonPauseMenu_Scene
    if method_defined?(:pbShowCommands)
      alias autoplay_bot_original_pause_menu_pbShowCommands pbShowCommands unless method_defined?(:autoplay_bot_original_pause_menu_pbShowCommands)

      def pbShowCommands(commands)
        if defined?(AutoplayBot::Runtime) &&
           AutoplayBot::Runtime.pause_menu_control? &&
           defined?(AutoplayBot::MenuTools) &&
           AutoplayBot::MenuTools.respond_to?(:choose_pause_command)
          choice = AutoplayBot::MenuTools.choose_pause_command(commands)
          return choice unless choice.nil?
        end
        autoplay_bot_original_pause_menu_pbShowCommands(commands)
      end
    end
  end
end

if defined?(PokemonPauseMenu)
  class PokemonPauseMenu
    if method_defined?(:heal_legacy_party)
      alias autoplay_bot_original_heal_legacy_party heal_legacy_party unless method_defined?(:autoplay_bot_original_heal_legacy_party)

      def heal_legacy_party
        if autoplay_bot_pending_menu_action?(:heal)
          ret = autoplay_bot_original_heal_legacy_party
          AutoplayBot::MenuTools.note_menu_action_completed!(:heal, "party healed") if defined?(AutoplayBot::MenuTools)
          return ret
        end
        autoplay_bot_original_heal_legacy_party
      rescue => e
        AutoplayBot::MenuTools.note_menu_action_blocked!(:heal, e.message) if defined?(AutoplayBot::MenuTools)
        raise e
      end
    end

    if method_defined?(:open_kuray_shop)
      alias autoplay_bot_original_open_kuray_shop open_kuray_shop unless method_defined?(:autoplay_bot_original_open_kuray_shop)

      def open_kuray_shop
        if autoplay_bot_pending_menu_action?(:kuray_shop)
          pbPlayDecisionSE rescue nil
          handled = defined?(AutoplayBot::MenuTools) &&
                    AutoplayBot::MenuTools.respond_to?(:handle_kuray_shop_for_bot) &&
                    AutoplayBot::MenuTools.handle_kuray_shop_for_bot
          if handled
            AutoplayBot::MenuTools.note_menu_action_completed!(:kuray_shop, "restock checked") if defined?(AutoplayBot::MenuTools)
          else
            AutoplayBot::MenuTools.note_menu_action_blocked!(:kuray_shop, "shop handler unavailable") if defined?(AutoplayBot::MenuTools)
          end
          @scene.pbRefresh if @scene && @scene.respond_to?(:pbRefresh)
          return
        end
        autoplay_bot_original_open_kuray_shop
      rescue => e
        AutoplayBot::MenuTools.note_menu_action_blocked!(:kuray_shop, e.message) if defined?(AutoplayBot::MenuTools)
        raise e
      end
    end

    if method_defined?(:open_legacy_pc)
      alias autoplay_bot_original_open_legacy_pc open_legacy_pc unless method_defined?(:autoplay_bot_original_open_legacy_pc)

      def open_legacy_pc
        if autoplay_bot_pending_menu_action?(:pc)
          pbPlayDecisionSE rescue nil
          AutoplayBot::MenuTools.note_pc_menu_seen! if defined?(AutoplayBot::MenuTools) && AutoplayBot::MenuTools.respond_to?(:note_pc_menu_seen!)
          @scene.pbRefresh if @scene && @scene.respond_to?(:pbRefresh)
          return
        end
        autoplay_bot_original_open_legacy_pc
      rescue => e
        AutoplayBot::MenuTools.note_menu_action_blocked!(:pc, e.message) if defined?(AutoplayBot::MenuTools)
        raise e
      end
    end

    if method_defined?(:open_tutornet)
      alias autoplay_bot_original_open_tutornet open_tutornet unless method_defined?(:autoplay_bot_original_open_tutornet)

      def open_tutornet
        if autoplay_bot_pending_menu_action?(:tutor_net)
          pbPlayDecisionSE rescue nil
          AutoplayBot::MenuTools.note_tutor_net_seen! if defined?(AutoplayBot::MenuTools) && AutoplayBot::MenuTools.respond_to?(:note_tutor_net_seen!)
          @scene.pbRefresh if @scene && @scene.respond_to?(:pbRefresh)
          return
        end
        autoplay_bot_original_open_tutornet
      rescue => e
        AutoplayBot::MenuTools.note_menu_action_blocked!(:tutor_net, e.message) if defined?(AutoplayBot::MenuTools)
        raise e
      end
    end

    def autoplay_bot_pending_menu_action?(action)
      defined?(AutoplayBot::Runtime) &&
        AutoplayBot::Runtime.prompt_control? &&
        defined?(AutoplayBot::MenuTools) &&
        AutoplayBot::MenuTools.respond_to?(:pending_action) &&
        AutoplayBot::MenuTools.pending_action == action.to_sym
    rescue
      false
    end
  end
end

if defined?(PokeBattle_Scene)
  class PokeBattle_Scene
    if method_defined?(:pbShowAbilitySplash)
      alias autoplay_bot_original_scene_pbShowAbilitySplash pbShowAbilitySplash unless method_defined?(:autoplay_bot_original_scene_pbShowAbilitySplash)

      def pbShowAbilitySplash(*args, &block)
        if defined?(AutoplayBot::Runtime) &&
           AutoplayBot::Runtime.respond_to?(:bot_battle_fast_forward?) &&
           AutoplayBot::Runtime.bot_battle_fast_forward?
          battler = args[0] rescue nil
          AutoplayBot::Runtime.note_battle_ability_splash!("scene ability", battler) if AutoplayBot::Runtime.respond_to?(:note_battle_ability_splash!)
          AutoplayBot::Runtime.hide_battle_ability_splash!(self, battler) if AutoplayBot::Runtime.respond_to?(:hide_battle_ability_splash!)
          return nil
        end
        autoplay_bot_original_scene_pbShowAbilitySplash(*args, &block)
      end
    end

    if method_defined?(:pbHideAbilitySplash)
      alias autoplay_bot_original_scene_pbHideAbilitySplash pbHideAbilitySplash unless method_defined?(:autoplay_bot_original_scene_pbHideAbilitySplash)

      def pbHideAbilitySplash(*args, &block)
        if defined?(AutoplayBot::Runtime) &&
           AutoplayBot::Runtime.respond_to?(:bot_battle_fast_forward?) &&
           AutoplayBot::Runtime.bot_battle_fast_forward?
          battler = args[0] rescue nil
          AutoplayBot::Runtime.hide_battle_ability_splash!(self, battler) if AutoplayBot::Runtime.respond_to?(:hide_battle_ability_splash!)
          return nil
        end
        autoplay_bot_original_scene_pbHideAbilitySplash(*args, &block)
      end
    end

    if method_defined?(:pbInputUpdate)
      alias autoplay_bot_original_scene_pbInputUpdate pbInputUpdate unless method_defined?(:autoplay_bot_original_scene_pbInputUpdate)

      def pbInputUpdate(*args, &block)
        result = autoplay_bot_original_scene_pbInputUpdate(*args, &block)
        if defined?(AutoplayBot::Runtime) &&
           AutoplayBot::Runtime.respond_to?(:battle_dialog_update_pulse!)
          AutoplayBot::Runtime.note_battle_engine_active!("scene input") if AutoplayBot::Runtime.respond_to?(:note_battle_engine_active!)
          AutoplayBot::Runtime.battle_dialog_update_pulse!
          if AutoplayBot::Runtime.respond_to?(:battle_scene_idle_confirm_tick)
            AutoplayBot::Runtime.battle_scene_idle_confirm_tick("battle start")
          end
        end
        result
      end
    end

    if method_defined?(:pbShowPokedex)
      alias autoplay_bot_original_scene_pbShowPokedex pbShowPokedex unless method_defined?(:autoplay_bot_original_scene_pbShowPokedex)

      def pbShowPokedex(species)
        if defined?(AutoplayBot::Runtime) &&
           AutoplayBot::Runtime.enabled? &&
           AutoplayBot::Runtime.running?
          AutoplayBot::Runtime.note_pokedex_entry_skipped!(species) if AutoplayBot::Runtime.respond_to?(:note_pokedex_entry_skipped!)
          return nil
        end
        autoplay_bot_original_scene_pbShowPokedex(species)
      end
    end

    if method_defined?(:pbDisplayMessage)
      alias autoplay_bot_original_pbDisplayMessage pbDisplayMessage unless method_defined?(:autoplay_bot_original_pbDisplayMessage)

      def pbDisplayMessage(msg, brief = false, &block)
        if defined?(AutoplayBot::Runtime) &&
           AutoplayBot::Runtime.enabled? &&
           AutoplayBot::Runtime.running?
          AutoplayBot::Runtime.note_battle_dialog_message!(msg, brief ? "battle brief" : "battle dialog") if AutoplayBot::Runtime.respond_to?(:note_battle_dialog_message!)
          return AutoplayBot::Runtime.with_battle_message_context("battle dialog") do
            AutoplayBot::Runtime.with_forced_input_context("battle dialog") do
              autoplay_bot_original_pbDisplayMessage(msg, brief, &block)
            end
          end
        end
        autoplay_bot_original_pbDisplayMessage(msg, brief, &block)
      end
    end

    if method_defined?(:pbDisplayPausedMessage)
      alias autoplay_bot_original_pbDisplayPausedMessage pbDisplayPausedMessage unless method_defined?(:autoplay_bot_original_pbDisplayPausedMessage)

    def pbDisplayPausedMessage(msg, &block)
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.enabled? &&
         AutoplayBot::Runtime.running?
        if AutoplayBot::Runtime.respond_to?(:auto_skip_battle_paused_message?) &&
           AutoplayBot::Runtime.auto_skip_battle_paused_message?(msg)
          AutoplayBot::Runtime.note_skipped_battle_message!(msg, "battle storage") if AutoplayBot::Runtime.respond_to?(:note_skipped_battle_message!)
          return nil
        end
        AutoplayBot::Runtime.note_battle_dialog_message!(msg, "battle paused") if AutoplayBot::Runtime.respond_to?(:note_battle_dialog_message!)
        return AutoplayBot::Runtime.with_battle_message_context("battle dialog") do
          AutoplayBot::Runtime.with_forced_input_context("battle dialog") do
            autoplay_bot_original_pbDisplayPausedMessage(msg, &block)
            end
          end
        end
        autoplay_bot_original_pbDisplayPausedMessage(msg, &block)
      end
    end

    if method_defined?(:pbDisplay)
      alias autoplay_bot_original_scene_pbDisplay pbDisplay unless method_defined?(:autoplay_bot_original_scene_pbDisplay)

      def pbDisplay(msg, *args, &block)
        if defined?(AutoplayBot::Runtime) &&
           AutoplayBot::Runtime.enabled? &&
           AutoplayBot::Runtime.running?
          AutoplayBot::Runtime.note_battle_dialog_message!(msg, "battle dialog") if AutoplayBot::Runtime.respond_to?(:note_battle_dialog_message!)
          return AutoplayBot::Runtime.with_battle_message_context("battle dialog") do
            AutoplayBot::Runtime.with_forced_input_context("battle dialog") do
              autoplay_bot_original_scene_pbDisplay(msg, *args, &block)
            end
          end
        end
        autoplay_bot_original_scene_pbDisplay(msg, *args, &block)
      end
    end
  end
end

if defined?(PokeBattle_SceneEBDX)
  class PokeBattle_SceneEBDX
    if method_defined?(:pbShowAbilitySplash)
      alias autoplay_bot_original_ebdx_pbShowAbilitySplash pbShowAbilitySplash unless method_defined?(:autoplay_bot_original_ebdx_pbShowAbilitySplash)

      def pbShowAbilitySplash(*args, &block)
        if defined?(AutoplayBot::Runtime) &&
           AutoplayBot::Runtime.respond_to?(:bot_battle_fast_forward?) &&
           AutoplayBot::Runtime.bot_battle_fast_forward?
          battler = args[0] rescue nil
          AutoplayBot::Runtime.note_battle_ability_splash!("ebdx ability", battler) if AutoplayBot::Runtime.respond_to?(:note_battle_ability_splash!)
          AutoplayBot::Runtime.hide_battle_ability_splash!(self, battler) if AutoplayBot::Runtime.respond_to?(:hide_battle_ability_splash!)
          return nil
        end
        autoplay_bot_original_ebdx_pbShowAbilitySplash(*args, &block)
      end
    end

    if method_defined?(:pbHideAbilitySplash)
      alias autoplay_bot_original_ebdx_pbHideAbilitySplash pbHideAbilitySplash unless method_defined?(:autoplay_bot_original_ebdx_pbHideAbilitySplash)

      def pbHideAbilitySplash(*args, &block)
        if defined?(AutoplayBot::Runtime) &&
           AutoplayBot::Runtime.respond_to?(:bot_battle_fast_forward?) &&
           AutoplayBot::Runtime.bot_battle_fast_forward?
          battler = args[0] rescue nil
          AutoplayBot::Runtime.hide_battle_ability_splash!(self, battler) if AutoplayBot::Runtime.respond_to?(:hide_battle_ability_splash!)
          return nil
        end
        autoplay_bot_original_ebdx_pbHideAbilitySplash(*args, &block)
      end
    end

    if method_defined?(:pbInputUpdate)
      alias autoplay_bot_original_ebdx_scene_pbInputUpdate pbInputUpdate unless method_defined?(:autoplay_bot_original_ebdx_scene_pbInputUpdate)

      def pbInputUpdate(*args, &block)
        result = autoplay_bot_original_ebdx_scene_pbInputUpdate(*args, &block)
        if defined?(AutoplayBot::Runtime) &&
           AutoplayBot::Runtime.respond_to?(:battle_dialog_update_pulse!)
          AutoplayBot::Runtime.note_battle_engine_active!("scene input") if AutoplayBot::Runtime.respond_to?(:note_battle_engine_active!)
          AutoplayBot::Runtime.battle_dialog_update_pulse!
          if AutoplayBot::Runtime.respond_to?(:battle_scene_idle_confirm_tick)
            AutoplayBot::Runtime.battle_scene_idle_confirm_tick("battle start")
          end
        end
        result
      end
    end

    if method_defined?(:pbDisplayMessage)
      alias autoplay_bot_original_ebdx_pbDisplayMessage pbDisplayMessage unless method_defined?(:autoplay_bot_original_ebdx_pbDisplayMessage)

      def pbDisplayMessage(msg, brief = false, &block)
        if defined?(AutoplayBot::Runtime) &&
           AutoplayBot::Runtime.enabled? &&
           AutoplayBot::Runtime.running?
          AutoplayBot::Runtime.note_battle_dialog_message!(msg, brief ? "battle brief" : "battle dialog") if AutoplayBot::Runtime.respond_to?(:note_battle_dialog_message!)
          return AutoplayBot::Runtime.with_battle_message_context("battle dialog") do
            AutoplayBot::Runtime.with_forced_input_context("battle dialog") do
              autoplay_bot_original_ebdx_pbDisplayMessage(msg, brief, &block)
            end
          end
        end
        autoplay_bot_original_ebdx_pbDisplayMessage(msg, brief, &block)
      end
    end

    if method_defined?(:pbDisplayPausedMessage)
      alias autoplay_bot_original_ebdx_pbDisplayPausedMessage pbDisplayPausedMessage unless method_defined?(:autoplay_bot_original_ebdx_pbDisplayPausedMessage)

    def pbDisplayPausedMessage(msg, &block)
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.enabled? &&
         AutoplayBot::Runtime.running?
        if AutoplayBot::Runtime.respond_to?(:auto_skip_battle_paused_message?) &&
           AutoplayBot::Runtime.auto_skip_battle_paused_message?(msg)
          AutoplayBot::Runtime.note_skipped_battle_message!(msg, "battle storage") if AutoplayBot::Runtime.respond_to?(:note_skipped_battle_message!)
          return nil
        end
        AutoplayBot::Runtime.note_battle_dialog_message!(msg, "battle paused") if AutoplayBot::Runtime.respond_to?(:note_battle_dialog_message!)
        return AutoplayBot::Runtime.with_battle_message_context("battle dialog") do
          AutoplayBot::Runtime.with_forced_input_context("battle dialog") do
            autoplay_bot_original_ebdx_pbDisplayPausedMessage(msg, &block)
            end
          end
        end
        autoplay_bot_original_ebdx_pbDisplayPausedMessage(msg, &block)
      end
    end

    if method_defined?(:pbDisplay)
      alias autoplay_bot_original_ebdx_scene_pbDisplay pbDisplay unless method_defined?(:autoplay_bot_original_ebdx_scene_pbDisplay)

      def pbDisplay(msg, *args, &block)
        if defined?(AutoplayBot::Runtime) &&
           AutoplayBot::Runtime.enabled? &&
           AutoplayBot::Runtime.running?
          AutoplayBot::Runtime.note_battle_dialog_message!(msg, "battle dialog") if AutoplayBot::Runtime.respond_to?(:note_battle_dialog_message!)
          return AutoplayBot::Runtime.with_battle_message_context("battle dialog") do
            AutoplayBot::Runtime.with_forced_input_context("battle dialog") do
              autoplay_bot_original_ebdx_scene_pbDisplay(msg, *args, &block)
            end
          end
        end
        autoplay_bot_original_ebdx_scene_pbDisplay(msg, *args, &block)
      end
    end
  end
end

class Object
  if private_method_defined?(:pbMessageDisplay) || method_defined?(:pbMessageDisplay)
    alias autoplay_bot_original_pbMessageDisplay pbMessageDisplay unless method_defined?(:autoplay_bot_original_pbMessageDisplay)

    def pbMessageDisplay(msgwindow, message, letterbyletter = true, commandProc = nil, withSound = true, &block)
      if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.message_hook_control?
        wrapped_block = proc do
          AutoplayBot::Runtime.message_wait_tick
          block.call if block
        end
        battle_message = AutoplayBot::Runtime.respond_to?(:battle_like_message?) &&
                         AutoplayBot::Runtime.battle_like_message?(message)
        if battle_message || AutoplayBot::Runtime.battle_engine_active? || AutoplayBot::Runtime.battle_message_context?
          AutoplayBot::Runtime.note_battle_dialog_message!(message, "battle dialog") if AutoplayBot::Runtime.respond_to?(:note_battle_dialog_message!)
          return AutoplayBot::Runtime.with_battle_message_context("battle dialog") do
            autoplay_bot_original_pbMessageDisplay(msgwindow, message, letterbyletter, commandProc, withSound, &wrapped_block)
          end
        end
        return autoplay_bot_original_pbMessageDisplay(msgwindow, message, letterbyletter, commandProc, withSound, &wrapped_block)
      end
      autoplay_bot_original_pbMessageDisplay(msgwindow, message, letterbyletter, commandProc, withSound, &block)
    end

    private :pbMessageDisplay
  end

  if private_method_defined?(:pbMessageWaitForInput) || method_defined?(:pbMessageWaitForInput)
    alias autoplay_bot_original_pbMessageWaitForInput pbMessageWaitForInput unless method_defined?(:autoplay_bot_original_pbMessageWaitForInput)

    def pbMessageWaitForInput(msgwindow, frames, showPause = false, &block)
      if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.message_hook_control?
        wrapped_block = proc do
          AutoplayBot::Runtime.message_wait_tick
          block.call if block
        end
        text = AutoplayBot::Runtime.respond_to?(:message_window_text) ? AutoplayBot::Runtime.message_window_text(msgwindow) : nil
        battle_message = AutoplayBot::Runtime.respond_to?(:battle_like_message?) &&
                         AutoplayBot::Runtime.battle_like_message?(text)
        if battle_message || AutoplayBot::Runtime.battle_engine_active? || AutoplayBot::Runtime.battle_message_context?
          AutoplayBot::Runtime.note_battle_dialog_message!(text, "battle wait") if AutoplayBot::Runtime.respond_to?(:note_battle_dialog_message!)
          return AutoplayBot::Runtime.with_battle_message_context("battle dialog") do
            autoplay_bot_original_pbMessageWaitForInput(msgwindow, frames, showPause, &wrapped_block)
          end
        end
        return autoplay_bot_original_pbMessageWaitForInput(msgwindow, frames, showPause, &wrapped_block)
      end
      autoplay_bot_original_pbMessageWaitForInput(msgwindow, frames, showPause, &block)
    end

    private :pbMessageWaitForInput
  end

  if private_method_defined?(:pbMessage) || method_defined?(:pbMessage)
    alias autoplay_bot_original_pbMessage pbMessage unless method_defined?(:autoplay_bot_original_pbMessage)

    def pbMessage(message, commands = nil, cmdIfCancel = 0, skin = nil, defaultCmd = 0, &block)
      if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.prompt_choice_control? && commands
        if AutoplayBot.manual_exclusive_prompt?(message, commands)
          return autoplay_bot_original_pbMessage(message, commands, cmdIfCancel, skin, defaultCmd, &block)
        end
        return AutoplayBot.prompt_choose(message, commands, cmdIfCancel, defaultCmd)
      end
      autoplay_bot_original_pbMessage(message, commands, cmdIfCancel, skin, defaultCmd, &block)
    end

    private :pbMessage
  end

  if private_method_defined?(:pbMessageNoSound) || method_defined?(:pbMessageNoSound)
    alias autoplay_bot_original_pbMessageNoSound pbMessageNoSound unless method_defined?(:autoplay_bot_original_pbMessageNoSound)

    def pbMessageNoSound(message, commands = nil, cmdIfCancel = 0, skin = nil, defaultCmd = 0, &block)
      if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.prompt_choice_control? && commands
        if AutoplayBot.manual_exclusive_prompt?(message, commands)
          return autoplay_bot_original_pbMessageNoSound(message, commands, cmdIfCancel, skin, defaultCmd, &block)
        end
        return AutoplayBot.prompt_choose(message, commands, cmdIfCancel, defaultCmd)
      end
      autoplay_bot_original_pbMessageNoSound(message, commands, cmdIfCancel, skin, defaultCmd, &block)
    end

    private :pbMessageNoSound
  end

  if private_method_defined?(:pbPokemonMart) || method_defined?(:pbPokemonMart)
    alias autoplay_bot_original_pbPokemonMart pbPokemonMart unless private_method_defined?(:autoplay_bot_original_pbPokemonMart) || method_defined?(:autoplay_bot_original_pbPokemonMart)

    def pbPokemonMart(stock, speech = nil, cantsell = false)
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.prompt_control? &&
         defined?(AutoplayBot::ShopPolicy) &&
         AutoplayBot::ShopPolicy.respond_to?(:handle_mart) &&
         AutoplayBot::ShopPolicy.handle_mart(stock, speech)
        return
      end
      autoplay_bot_original_pbPokemonMart(stock, speech, cantsell)
    end

    private :pbPokemonMart
  end

  if private_method_defined?(:pbShowPokedex) || method_defined?(:pbShowPokedex)
    alias autoplay_bot_original_object_pbShowPokedex pbShowPokedex unless private_method_defined?(:autoplay_bot_original_object_pbShowPokedex) || method_defined?(:autoplay_bot_original_object_pbShowPokedex)

    def pbShowPokedex(species)
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.enabled? &&
         AutoplayBot::Runtime.running?
        AutoplayBot::Runtime.note_pokedex_entry_skipped!(species) if AutoplayBot::Runtime.respond_to?(:note_pokedex_entry_skipped!)
        return nil
      end
      autoplay_bot_original_object_pbShowPokedex(species)
    end

    private :pbShowPokedex
  end

  if private_method_defined?(:pbShowCommands) || method_defined?(:pbShowCommands)
    alias autoplay_bot_original_pbShowCommands pbShowCommands unless method_defined?(:autoplay_bot_original_pbShowCommands)

    def pbShowCommands(msgwindow, commands = nil, cmdIfCancel = 0, defaultCmd = 0, x_offset = nil, y_offset = nil)
      if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.prompt_choice_control? && commands
        if AutoplayBot.manual_exclusive_prompt?(nil, commands)
          return autoplay_bot_original_pbShowCommands(msgwindow, commands, cmdIfCancel, defaultCmd, x_offset, y_offset)
        end
        return AutoplayBot.prompt_choose(nil, commands, cmdIfCancel, defaultCmd)
      end
      autoplay_bot_original_pbShowCommands(msgwindow, commands, cmdIfCancel, defaultCmd, x_offset, y_offset)
    end

    private :pbShowCommands
  end

  if private_method_defined?(:pbShowCommandsWithHelp) || method_defined?(:pbShowCommandsWithHelp)
    alias autoplay_bot_original_pbShowCommandsWithHelp pbShowCommandsWithHelp unless method_defined?(:autoplay_bot_original_pbShowCommandsWithHelp)

    def pbShowCommandsWithHelp(msgwindow, commands, help, cmdIfCancel = 0, defaultCmd = 0)
      if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.prompt_choice_control? && commands
        message = help && help[defaultCmd]
        if AutoplayBot.manual_exclusive_prompt?(message, commands)
          return autoplay_bot_original_pbShowCommandsWithHelp(msgwindow, commands, help, cmdIfCancel, defaultCmd)
        end
        return AutoplayBot.prompt_choose(message, commands, cmdIfCancel, defaultCmd)
      end
      autoplay_bot_original_pbShowCommandsWithHelp(msgwindow, commands, help, cmdIfCancel, defaultCmd)
    end

    private :pbShowCommandsWithHelp
  end

  if private_method_defined?(:pbConfirmMessage) || method_defined?(:pbConfirmMessage)
    alias autoplay_bot_original_pbConfirmMessage pbConfirmMessage unless method_defined?(:autoplay_bot_original_pbConfirmMessage)

    def pbConfirmMessage(message, &block)
      return AutoplayBot::PromptPolicy.confirm(message, false) if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.prompt_choice_control?
      autoplay_bot_original_pbConfirmMessage(message, &block)
    end

    private :pbConfirmMessage
  end

  if private_method_defined?(:pbConfirmMessageSerious) || method_defined?(:pbConfirmMessageSerious)
    alias autoplay_bot_original_pbConfirmMessageSerious pbConfirmMessageSerious unless method_defined?(:autoplay_bot_original_pbConfirmMessageSerious)

    def pbConfirmMessageSerious(message, &block)
      return AutoplayBot::PromptPolicy.confirm(message, true) if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.prompt_choice_control?
      autoplay_bot_original_pbConfirmMessageSerious(message, &block)
    end

    private :pbConfirmMessageSerious
  end

  if private_method_defined?(:pbMessageChooseNumber) || method_defined?(:pbMessageChooseNumber)
    alias autoplay_bot_original_pbMessageChooseNumber pbMessageChooseNumber unless method_defined?(:autoplay_bot_original_pbMessageChooseNumber)

    def pbMessageChooseNumber(message, params, &block)
      return AutoplayBot::PromptPolicy.number(message, params) if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.prompt_choice_control?
      autoplay_bot_original_pbMessageChooseNumber(message, params, &block)
    end

    private :pbMessageChooseNumber
  end

  if private_method_defined?(:pbEnterText) || method_defined?(:pbEnterText)
    alias autoplay_bot_original_pbEnterText pbEnterText unless method_defined?(:autoplay_bot_original_pbEnterText)

    def pbEnterText(helptext, minlength, maxlength, initialText = "", mode = 0, pokemon = nil, nofadeout = false)
      return AutoplayBot.prompt_text(helptext, minlength, maxlength, initialText, mode, pokemon) if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.prompt_choice_control?
      autoplay_bot_original_pbEnterText(helptext, minlength, maxlength, initialText, mode, pokemon, nofadeout)
    end

    private :pbEnterText
  end

  if private_method_defined?(:pbEnterPlayerName) || method_defined?(:pbEnterPlayerName)
    alias autoplay_bot_original_pbEnterPlayerName pbEnterPlayerName unless method_defined?(:autoplay_bot_original_pbEnterPlayerName)

    def pbEnterPlayerName(helptext, minlength, maxlength, initialText = "", nofadeout = false)
      return AutoplayBot.prompt_text(helptext, minlength, maxlength, initialText, 0, nil) if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.prompt_choice_control?
      autoplay_bot_original_pbEnterPlayerName(helptext, minlength, maxlength, initialText, nofadeout)
    end

    private :pbEnterPlayerName
  end

  if private_method_defined?(:pbEnterPokemonName) || method_defined?(:pbEnterPokemonName)
    alias autoplay_bot_original_pbEnterPokemonName pbEnterPokemonName unless method_defined?(:autoplay_bot_original_pbEnterPokemonName)

    def pbEnterPokemonName(helptext, minlength, maxlength, initialText = "", pokemon = nil, nofadeout = false)
      return AutoplayBot.prompt_text(helptext, minlength, maxlength, initialText, 0, pokemon) if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.prompt_choice_control?
      autoplay_bot_original_pbEnterPokemonName(helptext, minlength, maxlength, initialText, pokemon, nofadeout)
    end

    private :pbEnterPokemonName
  end

  if private_method_defined?(:pbNickname) || method_defined?(:pbNickname)
    alias autoplay_bot_original_pbNickname pbNickname unless method_defined?(:autoplay_bot_original_pbNickname)

    def pbNickname(pkmn)
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.prompt_choice_control? &&
         defined?(AutoplayBot::PromptPolicy) &&
         AutoplayBot::PromptPolicy.respond_to?(:apply_capture_nickname) &&
         AutoplayBot::PromptPolicy.apply_capture_nickname(pkmn)
        return
      end
      autoplay_bot_original_pbNickname(pkmn)
    end

    private :pbNickname
  end

  if private_method_defined?(:pbTrainerPC) || method_defined?(:pbTrainerPC)
    alias autoplay_bot_original_pbTrainerPC pbTrainerPC unless method_defined?(:autoplay_bot_original_pbTrainerPC)

    def pbTrainerPC
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.prompt_control? &&
         defined?(AutoplayBot::Director) &&
         AutoplayBot::Director.respond_to?(:handle_bedroom_pc!) &&
         AutoplayBot::Director.handle_bedroom_pc!
        return
      end
      autoplay_bot_original_pbTrainerPC
    end

    private :pbTrainerPC
  end

  if private_method_defined?(:pbSetPokemonCenter) || method_defined?(:pbSetPokemonCenter)
    alias autoplay_bot_original_pbSetPokemonCenter pbSetPokemonCenter unless method_defined?(:autoplay_bot_original_pbSetPokemonCenter)

    def pbSetPokemonCenter
      ret = autoplay_bot_original_pbSetPokemonCenter
      if defined?(AutoplayBot::State) &&
         (!AutoplayBot::State.respond_to?(:loaded?) || AutoplayBot::State.loaded?) &&
         defined?($PokemonGlobal) && $PokemonGlobal &&
         $PokemonGlobal.respond_to?(:pokecenterMapId)
        AutoplayBot::State.record_heal_hub(
          $PokemonGlobal.pokecenterMapId,
          ($PokemonGlobal.pokecenterX if $PokemonGlobal.respond_to?(:pokecenterX)),
          ($PokemonGlobal.pokecenterY if $PokemonGlobal.respond_to?(:pokecenterY)),
          ($PokemonGlobal.pokecenterDirection if $PokemonGlobal.respond_to?(:pokecenterDirection)),
          "Pokemon Center"
        )
      end
      ret
    end

    private :pbSetPokemonCenter
  end

  if private_method_defined?(:pbTopRightWindow) || method_defined?(:pbTopRightWindow)
    alias autoplay_bot_original_pbTopRightWindow pbTopRightWindow unless method_defined?(:autoplay_bot_original_pbTopRightWindow)

    def pbTopRightWindow(text, scene = nil)
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.enabled? &&
         AutoplayBot::Runtime.running?
        return AutoplayBot::Runtime.with_top_right_window_context("level up stats") do
          AutoplayBot::Runtime.with_battle_message_context("level up stats") do
            AutoplayBot::Runtime.with_forced_input_context("level up") do
              autoplay_bot_original_pbTopRightWindow(text, scene)
            end
          end
        end
      end
      autoplay_bot_original_pbTopRightWindow(text, scene)
    end

    private :pbTopRightWindow
  end

  if private_method_defined?(:pbStartOver) || method_defined?(:pbStartOver)
    alias autoplay_bot_original_pbStartOver pbStartOver unless private_method_defined?(:autoplay_bot_original_pbStartOver) || method_defined?(:autoplay_bot_original_pbStartOver)

    def pbStartOver(gameover = false)
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.enabled? &&
         AutoplayBot::Runtime.running? &&
         defined?(AutoplayBot::Director) &&
         AutoplayBot::Director.respond_to?(:note_blackout_start!)
        AutoplayBot::Director.note_blackout_start!(gameover)
      end

      ret = nil
      begin
        ret = autoplay_bot_original_pbStartOver(gameover)
      ensure
        if defined?(AutoplayBot::Runtime) &&
           AutoplayBot::Runtime.enabled? &&
           AutoplayBot::Runtime.running? &&
           defined?(AutoplayBot::Director) &&
           AutoplayBot::Director.respond_to?(:note_blackout_complete!)
          AutoplayBot::Director.note_blackout_complete!(gameover)
        end
      end
      ret
    end

    private :pbStartOver
  end

  if private_method_defined?(:pbGenerateWildPokemon) || method_defined?(:pbGenerateWildPokemon)
    alias autoplay_bot_original_pbGenerateWildPokemon pbGenerateWildPokemon unless method_defined?(:autoplay_bot_original_pbGenerateWildPokemon)

    def pbGenerateWildPokemon(species, level, isRoamer = false)
      pokemon = autoplay_bot_original_pbGenerateWildPokemon(species, level, isRoamer)
      AutoplayBot::DexTracker.observe_pokemon(pokemon) if defined?(AutoplayBot::DexTracker)
      pokemon
    end

    private :pbGenerateWildPokemon
  end

  if private_method_defined?(:pbAddPokemon) || method_defined?(:pbAddPokemon)
    alias autoplay_bot_original_pbAddPokemon pbAddPokemon unless method_defined?(:autoplay_bot_original_pbAddPokemon)

    def pbAddPokemon(pkmn, level = 1, see_form = true, dontRandomize = false, variableToSave = nil)
      before_counts = defined?(AutoplayBot::DexTracker) ? AutoplayBot::DexTracker.live_counts : {}
      ret = autoplay_bot_original_pbAddPokemon(pkmn, level, see_form, dontRandomize, variableToSave)
      AutoplayBot::DexTracker.record_count_delta(before_counts, AutoplayBot::DexTracker.live_counts) if ret && defined?(AutoplayBot::DexTracker)
      AutoplayBot::DexTracker.record_owned_fusion(pkmn) if ret && defined?(AutoplayBot::DexTracker) && AutoplayBot::DexTracker.respond_to?(:record_owned_fusion)
      ret
    end

    private :pbAddPokemon
  end

  if private_method_defined?(:pbAddPokemonSilent) || method_defined?(:pbAddPokemonSilent)
    alias autoplay_bot_original_pbAddPokemonSilent pbAddPokemonSilent unless method_defined?(:autoplay_bot_original_pbAddPokemonSilent)

    def pbAddPokemonSilent(pkmn, level = 1, see_form = true)
      before_counts = defined?(AutoplayBot::DexTracker) ? AutoplayBot::DexTracker.live_counts : {}
      ret = autoplay_bot_original_pbAddPokemonSilent(pkmn, level, see_form)
      AutoplayBot::DexTracker.record_count_delta(before_counts, AutoplayBot::DexTracker.live_counts) if ret && defined?(AutoplayBot::DexTracker)
      AutoplayBot::DexTracker.record_owned_fusion(pkmn) if ret && defined?(AutoplayBot::DexTracker) && AutoplayBot::DexTracker.respond_to?(:record_owned_fusion)
      ret
    end

    private :pbAddPokemonSilent
  end

  if private_method_defined?(:pbAddPokemonID) || method_defined?(:pbAddPokemonID)
    alias autoplay_bot_original_pbAddPokemonID pbAddPokemonID unless method_defined?(:autoplay_bot_original_pbAddPokemonID)

    def pbAddPokemonID(pokemon_id, level = 1, see_form = true, skip_randomize = false)
      before_counts = defined?(AutoplayBot::DexTracker) ? AutoplayBot::DexTracker.live_counts : {}
      ret = autoplay_bot_original_pbAddPokemonID(pokemon_id, level, see_form, skip_randomize)
      AutoplayBot::DexTracker.record_count_delta(before_counts, AutoplayBot::DexTracker.live_counts) if ret && defined?(AutoplayBot::DexTracker)
      AutoplayBot::DexTracker.record_owned_fusion(pokemon_id) if ret && defined?(AutoplayBot::DexTracker) && AutoplayBot::DexTracker.respond_to?(:record_owned_fusion)
      ret
    end

    private :pbAddPokemonID
  end

  if private_method_defined?(:pbAddToParty) || method_defined?(:pbAddToParty)
    alias autoplay_bot_original_pbAddToParty pbAddToParty unless method_defined?(:autoplay_bot_original_pbAddToParty)

    def pbAddToParty(pkmn, level = 1, see_form = true, dontRandomize = false)
      before_counts = defined?(AutoplayBot::DexTracker) ? AutoplayBot::DexTracker.live_counts : {}
      ret = autoplay_bot_original_pbAddToParty(pkmn, level, see_form, dontRandomize)
      AutoplayBot::DexTracker.record_count_delta(before_counts, AutoplayBot::DexTracker.live_counts) if ret && defined?(AutoplayBot::DexTracker)
      AutoplayBot::DexTracker.record_owned_fusion(pkmn) if ret && defined?(AutoplayBot::DexTracker) && AutoplayBot::DexTracker.respond_to?(:record_owned_fusion)
      ret
    end

    private :pbAddToParty
  end

  if private_method_defined?(:pbAddToPartySilent) || method_defined?(:pbAddToPartySilent)
    alias autoplay_bot_original_pbAddToPartySilent pbAddToPartySilent unless method_defined?(:autoplay_bot_original_pbAddToPartySilent)

    def pbAddToPartySilent(pkmn, level = nil, see_form = true)
      before_counts = defined?(AutoplayBot::DexTracker) ? AutoplayBot::DexTracker.live_counts : {}
      ret = autoplay_bot_original_pbAddToPartySilent(pkmn, level, see_form)
      AutoplayBot::DexTracker.record_count_delta(before_counts, AutoplayBot::DexTracker.live_counts) if ret && defined?(AutoplayBot::DexTracker)
      AutoplayBot::DexTracker.record_owned_fusion(pkmn) if ret && defined?(AutoplayBot::DexTracker) && AutoplayBot::DexTracker.respond_to?(:record_owned_fusion)
      ret
    end

    private :pbAddToPartySilent
  end

  if private_method_defined?(:pbAddForeignPokemon) || method_defined?(:pbAddForeignPokemon)
    alias autoplay_bot_original_pbAddForeignPokemon pbAddForeignPokemon unless method_defined?(:autoplay_bot_original_pbAddForeignPokemon)

    def pbAddForeignPokemon(pkmn, level = 1, owner_name = nil, nickname = nil, owner_gender = 0, see_form = true)
      before_counts = defined?(AutoplayBot::DexTracker) ? AutoplayBot::DexTracker.live_counts : {}
      ret = autoplay_bot_original_pbAddForeignPokemon(pkmn, level, owner_name, nickname, owner_gender, see_form)
      AutoplayBot::DexTracker.record_count_delta(before_counts, AutoplayBot::DexTracker.live_counts) if ret && defined?(AutoplayBot::DexTracker)
      AutoplayBot::DexTracker.record_owned_fusion(pkmn) if ret && defined?(AutoplayBot::DexTracker) && AutoplayBot::DexTracker.respond_to?(:record_owned_fusion)
      ret
    end

    private :pbAddForeignPokemon
  end
end

class << Kernel
  if method_defined?(:pbShowCommands) || private_method_defined?(:pbShowCommands)
    alias autoplay_bot_original_singleton_pbShowCommands pbShowCommands unless method_defined?(:autoplay_bot_original_singleton_pbShowCommands)

    def pbShowCommands(msgwindow, commands = nil, cmdIfCancel = 0, defaultCmd = 0, x_offset = nil, y_offset = nil)
      if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.prompt_choice_control? && commands
        if AutoplayBot.manual_exclusive_prompt?(nil, commands)
          return autoplay_bot_original_singleton_pbShowCommands(msgwindow, commands, cmdIfCancel, defaultCmd, x_offset, y_offset)
        end
        return AutoplayBot.prompt_choose(nil, commands, cmdIfCancel, defaultCmd)
      end
      autoplay_bot_original_singleton_pbShowCommands(msgwindow, commands, cmdIfCancel, defaultCmd, x_offset, y_offset)
    end
  end
end

if defined?(PokemonLoad_Scene)
  class PokemonLoad_Scene
    alias autoplay_bot_original_pbChoose pbChoose unless method_defined?(:autoplay_bot_original_pbChoose)

    def pbChoose(commands, *args)
      if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.prompt_choice_control?
        default = args[0].is_a?(Integer) && args[0] >= 0 ? args[0] : 0
        return AutoplayBot.prompt_choose(nil, commands, 0, default)
      end
      autoplay_bot_original_pbChoose(commands, *args)
    end
  end
end

if defined?(PokemonSummary_Scene)
  class PokemonSummary_Scene
    alias autoplay_bot_original_pbChooseMoveToForget pbChooseMoveToForget unless method_defined?(:autoplay_bot_original_pbChooseMoveToForget)

    def pbChooseMoveToForget(move_to_learn)
      if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.prompt_choice_control?
        if defined?(AutoplayBot::TeamBuilder) && AutoplayBot::TeamBuilder.respond_to?(:move_forget_index)
          return AutoplayBot::TeamBuilder.move_forget_index(@pokemon, move_to_learn)
        end
        return 0
      end
      autoplay_bot_original_pbChooseMoveToForget(move_to_learn)
    end
  end
end

if defined?(PokemonPokedexInfoScreen)
  class PokemonPokedexInfoScreen
    alias autoplay_bot_original_pbDexEntry pbDexEntry unless method_defined?(:autoplay_bot_original_pbDexEntry)

    def pbDexEntry(species)
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.enabled? &&
         AutoplayBot::Runtime.running?
        AutoplayBot::Runtime.note_pokedex_entry_skipped!(species) if AutoplayBot::Runtime.respond_to?(:note_pokedex_entry_skipped!)
        return nil
      end
      autoplay_bot_original_pbDexEntry(species)
    end
  end
end

if defined?(PokemonPokedexInfo_Scene)
  class PokemonPokedexInfo_Scene
    if method_defined?(:pbSceneBrief)
      alias autoplay_bot_original_pbSceneBrief pbSceneBrief unless method_defined?(:autoplay_bot_original_pbSceneBrief)

      def pbSceneBrief
        if defined?(AutoplayBot::Runtime) &&
           AutoplayBot::Runtime.respond_to?(:pokedex_entry_autoskip?) &&
           AutoplayBot::Runtime.pokedex_entry_autoskip?
          AutoplayBot::Runtime.note_pokedex_entry_skipped!(@species) if AutoplayBot::Runtime.respond_to?(:note_pokedex_entry_skipped!)
          2.times do
            Graphics.update
            Input.update
            pbUpdate rescue nil
          end
          return nil
        end
        autoplay_bot_original_pbSceneBrief
      end
    end

    alias autoplay_bot_original_pbChooseAlt pbChooseAlt unless method_defined?(:autoplay_bot_original_pbChooseAlt)

    def pbChooseAlt(brief = false)
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.prompt_choice_control? &&
         respond_to?(:select_sprite)
        AutoplayBot.status("sprite: selecting") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:status)
        if respond_to?(:set_displayed_to_current_alt) && @available
          set_displayed_to_current_alt(@available) rescue nil
        end
        return if select_sprite(brief)
      end
      autoplay_bot_original_pbChooseAlt(brief)
    rescue => e
      AutoplayBot.log("sprite selection hook failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      autoplay_bot_original_pbChooseAlt(brief)
    end
  end
end

if defined?(PokemonSelection)
  module PokemonSelection
    class << self
      alias autoplay_bot_original_choose choose unless method_defined?(:autoplay_bot_original_choose)

      def choose(min = 1, max = 6, canCancel = false, acceptFainted = false, ableproc = nil)
        unless defined?(AutoplayBot::Runtime) &&
               AutoplayBot::Runtime.prompt_choice_control? &&
               defined?(AutoplayBot::TeamBuilder)
          return autoplay_bot_original_choose(min, max, canCancel, acceptFainted, ableproc)
        end
        chosen = AutoplayBot::TeamBuilder.selection_for_context(min, max, acceptFainted, ableproc)
        if chosen.empty?
          AutoplayBot.log("team selection found no eligible Pokemon") if AutoplayBot.respond_to?(:log)
          return false if canCancel
          return autoplay_bot_original_choose(min, max, canCancel, acceptFainted, ableproc)
        end
        PokemonSelection.restore if respond_to?(:restore) &&
                                    defined?($PokemonGlobal) &&
                                    $PokemonGlobal &&
                                    $PokemonGlobal.respond_to?(:pokemonSelectionOriginalParty) &&
                                    $PokemonGlobal.pokemonSelectionOriginalParty
        if defined?($Trainer) && $Trainer && $Trainer.respond_to?(:party) && $Trainer.respond_to?(:party=)
          if $Trainer.party.size != chosen.size && defined?($PokemonGlobal) && $PokemonGlobal
            if $PokemonGlobal.respond_to?(:pokemonSelectionOriginalParty=)
              $PokemonGlobal.pokemonSelectionOriginalParty = $Trainer.party
            else
              $PokemonGlobal.instance_variable_set(:@pokemonSelectionOriginalParty, $Trainer.party)
            end
          end
          $Trainer.party = chosen
        end
        AutoplayBot.status("team: selected #{chosen.length}")
        AutoplayBot.log("team selection chose #{chosen.length} Pokemon") if AutoplayBot.respond_to?(:log)
        true
      rescue => e
        AutoplayBot.log("team selection hook failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
        autoplay_bot_original_choose(min, max, canCancel, acceptFainted, ableproc)
      end
    end
  end
end

if Object.private_method_defined?(:pbChoosePokemon)
  class Object
    alias autoplay_bot_original_pbChoosePokemon pbChoosePokemon unless private_method_defined?(:autoplay_bot_original_pbChoosePokemon)

    def pbChoosePokemon(variableNumber, nameVarNumber, ableProc = nil, allowIneligible = false)
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.prompt_choice_control? &&
         defined?(AutoplayBot::TeamBuilder) &&
         AutoplayBot::TeamBuilder.caught_storage_context?
        index = AutoplayBot::TeamBuilder.swap_out_party_index(ableProc, allowIneligible)
        if index && index.to_i >= 0
          pkmn = $Trainer.party[index] rescue nil
          pbSet(variableNumber, index.to_i) if defined?(pbSet)
          pbSet(nameVarNumber, (pkmn && pkmn.respond_to?(:name) ? pkmn.name : "")) if defined?(pbSet)
          AutoplayBot.status("team: box #{pkmn.name}") if pkmn && AutoplayBot.respond_to?(:status)
          AutoplayBot.log("caught storage selected party slot #{index} for PC") if AutoplayBot.respond_to?(:log)
          return index.to_i
        end
      end
      autoplay_bot_original_pbChoosePokemon(variableNumber, nameVarNumber, ableProc, allowIneligible)
    rescue => e
      AutoplayBot.log("caught party selection hook failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      autoplay_bot_original_pbChoosePokemon(variableNumber, nameVarNumber, ableProc, allowIneligible)
    end

    private :pbChoosePokemon
  end
end

if defined?(PokeBattle_Battle)
  class PokeBattle_Battle
    alias autoplay_bot_original_pbDisplay pbDisplay unless method_defined?(:autoplay_bot_original_pbDisplay)
    alias autoplay_bot_original_pbDisplayBrief pbDisplayBrief unless method_defined?(:autoplay_bot_original_pbDisplayBrief)
    alias autoplay_bot_original_pbCommandPhase pbCommandPhase unless method_defined?(:autoplay_bot_original_pbCommandPhase)
    alias autoplay_bot_original_pbAutoFightMenu pbAutoFightMenu unless method_defined?(:autoplay_bot_original_pbAutoFightMenu)
    alias autoplay_bot_original_pbDisplayPaused pbDisplayPaused unless method_defined?(:autoplay_bot_original_pbDisplayPaused)
    alias autoplay_bot_original_pbDisplayConfirm pbDisplayConfirm unless method_defined?(:autoplay_bot_original_pbDisplayConfirm)
    alias autoplay_bot_original_pbSwitchInBetween pbSwitchInBetween unless method_defined?(:autoplay_bot_original_pbSwitchInBetween)
    alias autoplay_bot_original_pbGetReplacementPokemonIndex pbGetReplacementPokemonIndex unless method_defined?(:autoplay_bot_original_pbGetReplacementPokemonIndex)
    alias autoplay_bot_original_pbEndOfBattle pbEndOfBattle if method_defined?(:pbEndOfBattle) && !method_defined?(:autoplay_bot_original_pbEndOfBattle)
    alias autoplay_bot_original_pbShowAbilitySplash pbShowAbilitySplash if method_defined?(:pbShowAbilitySplash) && !method_defined?(:autoplay_bot_original_pbShowAbilitySplash)
    alias autoplay_bot_original_pbHideAbilitySplash pbHideAbilitySplash if method_defined?(:pbHideAbilitySplash) && !method_defined?(:autoplay_bot_original_pbHideAbilitySplash)
    alias autoplay_bot_original_pbReplaceAbilitySplash pbReplaceAbilitySplash if method_defined?(:pbReplaceAbilitySplash) && !method_defined?(:autoplay_bot_original_pbReplaceAbilitySplash)

    if method_defined?(:autoplay_bot_original_pbShowAbilitySplash)
      def pbShowAbilitySplash(*args, &block)
        if defined?(AutoplayBot::Runtime) &&
           AutoplayBot::Runtime.respond_to?(:bot_battle_fast_forward?) &&
           AutoplayBot::Runtime.bot_battle_fast_forward?
          battler = args[0] rescue nil
          AutoplayBot::Runtime.note_battle_ability_splash!("battle ability", battler) if AutoplayBot::Runtime.respond_to?(:note_battle_ability_splash!)
          AutoplayBot::Runtime.hide_battle_ability_splash!(@scene, battler) if AutoplayBot::Runtime.respond_to?(:hide_battle_ability_splash!)
          return nil
        end
        autoplay_bot_original_pbShowAbilitySplash(*args, &block)
      end
    end

    if method_defined?(:autoplay_bot_original_pbHideAbilitySplash)
      def pbHideAbilitySplash(*args, &block)
        if defined?(AutoplayBot::Runtime) &&
           AutoplayBot::Runtime.respond_to?(:bot_battle_fast_forward?) &&
           AutoplayBot::Runtime.bot_battle_fast_forward?
          battler = args[0] rescue nil
          AutoplayBot::Runtime.hide_battle_ability_splash!(@scene, battler) if AutoplayBot::Runtime.respond_to?(:hide_battle_ability_splash!)
          return nil
        end
        autoplay_bot_original_pbHideAbilitySplash(*args, &block)
      end
    end

    if method_defined?(:autoplay_bot_original_pbReplaceAbilitySplash)
      def pbReplaceAbilitySplash(*args, &block)
        if defined?(AutoplayBot::Runtime) &&
           AutoplayBot::Runtime.respond_to?(:bot_battle_fast_forward?) &&
           AutoplayBot::Runtime.bot_battle_fast_forward?
          battler = args[0] rescue nil
          AutoplayBot::Runtime.note_battle_ability_splash!("battle ability replace", battler) if AutoplayBot::Runtime.respond_to?(:note_battle_ability_splash!)
          AutoplayBot::Runtime.hide_battle_ability_splash!(@scene, battler) if AutoplayBot::Runtime.respond_to?(:hide_battle_ability_splash!)
          return nil
        end
        autoplay_bot_original_pbReplaceAbilitySplash(*args, &block)
      end
    end

    def pbDisplay(msg, &block)
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.enabled? &&
         AutoplayBot::Runtime.running?
        AutoplayBot::Runtime.note_battle_dialog_message!(msg, "battle dialog") if AutoplayBot::Runtime.respond_to?(:note_battle_dialog_message!)
        return AutoplayBot::Runtime.with_battle_message_context("battle dialog") do
          AutoplayBot::Runtime.with_forced_input_context("battle dialog") do
            autoplay_bot_original_pbDisplay(msg, &block)
          end
        end
      end
      autoplay_bot_original_pbDisplay(msg, &block)
    end

    def pbDisplayBrief(msg)
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.enabled? &&
         AutoplayBot::Runtime.running?
        AutoplayBot::Runtime.note_battle_dialog_message!(msg, "battle brief") if AutoplayBot::Runtime.respond_to?(:note_battle_dialog_message!)
        return AutoplayBot::Runtime.with_battle_message_context("battle brief") do
          AutoplayBot::Runtime.with_forced_input_context("battle dialog") do
            autoplay_bot_original_pbDisplayBrief(msg)
          end
        end
      end
      autoplay_bot_original_pbDisplayBrief(msg)
    end

    def pbDisplayPaused(msg, &block)
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.enabled? &&
         AutoplayBot::Runtime.running?
        if AutoplayBot::Runtime.respond_to?(:auto_skip_battle_paused_message?) &&
           AutoplayBot::Runtime.auto_skip_battle_paused_message?(msg)
          AutoplayBot::Runtime.note_skipped_battle_message!(msg, "battle storage") if AutoplayBot::Runtime.respond_to?(:note_skipped_battle_message!)
          return nil
        end
        AutoplayBot::Runtime.note_battle_dialog_message!(msg, "battle paused") if AutoplayBot::Runtime.respond_to?(:note_battle_dialog_message!)
        return AutoplayBot::Runtime.with_battle_message_context("battle dialog") do
          AutoplayBot::Runtime.with_forced_input_context("battle dialog") do
            autoplay_bot_original_pbDisplayPaused(msg, &block)
          end
        end
      end
      autoplay_bot_original_pbDisplayPaused(msg, &block)
    end

    def pbCommandPhase
      return autoplay_bot_original_pbCommandPhase unless defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.prompt_control?
      AutoplayBot::Runtime.note_battle_engine_active!("command") if AutoplayBot::Runtime.respond_to?(:note_battle_engine_active!)
      AutoplayBot::Runtime.note_battle_automation! if AutoplayBot::Runtime.respond_to?(:note_battle_automation!)
      AutoplayBot::RepeatableBattleLedger.note_battle_start(self) if defined?(AutoplayBot::RepeatableBattleLedger)
      @scene.pbBeginCommandPhase
      @battlers.each_with_index do |battler, i|
        next unless battler
        pbClearChoice(i) if pbCanShowCommands?(i)
      end
      for side in 0...2
        @megaEvolution[side].each_with_index do |megaEvo, i|
          @megaEvolution[side][i] = -1 if megaEvo >= 0
        end
      end
      autoplay_bot_choose_player_actions
      return if @decision != 0
      old_control = @controlPlayer
      @controlPlayer = false
      pbCommandPhaseLoop(false)
    ensure
      @controlPlayer = old_control unless old_control.nil?
    end

    def autoplay_bot_choose_player_actions
      action_consumed = false
      action_count = 0
      @battlers.each_with_index do |battler, idxBattler|
        break if action_consumed || @decision != 0
        next unless battler && pbOwnedByPlayer?(idxBattler)
        next if @choices[idxBattler] && @choices[idxBattler][0] != :None
        next unless pbCanShowCommands?(idxBattler)
        if AutoplayBot::BattlePolicy.try_register_turn(self, idxBattler, @battleAI, action_count == 0)
          action_count += 1
          item = @choices[idxBattler][1] rescue nil
          action_consumed = (@choices[idxBattler][0] == :UseItem && (pbItemUsesAllActions?(item) rescue false))
          next
        end
        begin
          @autoplay_bot_first_action = (action_count == 0)
          action_count += 1 if autoplay_bot_force_player_action(idxBattler, @battleAI)
        rescue => e
          AutoplayBot.log("battle AI fallback for battler #{idxBattler}: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
          action_count += 1 if respond_to?(:pbAutoChooseMove) && pbAutoChooseMove(idxBattler, false)
        ensure
          @autoplay_bot_first_action = nil
        end
      end
      autoplay_bot_ensure_player_actions(@battleAI) unless action_consumed || @decision != 0
    end

    def autoplay_bot_ensure_player_actions(ai = nil)
      @battlers.each_with_index do |battler, idxBattler|
        next unless battler && pbOwnedByPlayer?(idxBattler)
        next unless pbCanShowCommands?(idxBattler)
        next unless @choices[idxBattler] && @choices[idxBattler][0] == :None
        autoplay_bot_force_player_action(idxBattler, ai)
      end
    rescue => e
      AutoplayBot.log("battle ensure player actions failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    end

    def autoplay_bot_force_player_action(idxBattler, ai = nil)
      return true if @choices[idxBattler] && @choices[idxBattler][0] != :None
      if defined?(AutoplayBot::BattlePolicy) &&
         AutoplayBot::BattlePolicy.respond_to?(:try_register_best_move) &&
         AutoplayBot::BattlePolicy.try_register_best_move(self, idxBattler, ai)
        AutoplayBot::Runtime.note_battle_automation! if defined?(AutoplayBot::Runtime) &&
                                                        AutoplayBot::Runtime.respond_to?(:note_battle_automation!)
        return true
      end
      if respond_to?(:pbAutoChooseMove) && pbAutoChooseMove(idxBattler, false)
        AutoplayBot.status("battle: forced legal move") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:status)
        AutoplayBot.log("battle fallback: forced legal move for battler #{idxBattler}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
        AutoplayBot::Runtime.note_battle_automation! if defined?(AutoplayBot::Runtime) &&
                                                        AutoplayBot::Runtime.respond_to?(:note_battle_automation!)
        return true
      end
      false
    rescue => e
      AutoplayBot.log("battle force action failed for battler #{idxBattler}: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def pbAutoFightMenu(idxBattler)
      AutoplayBot::Runtime.note_battle_engine_active!("auto fight") if defined?(AutoplayBot::Runtime) &&
                                                                       AutoplayBot::Runtime.respond_to?(:note_battle_engine_active!)
      first_action = @autoplay_bot_first_action.nil? ? true : @autoplay_bot_first_action
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.prompt_control? &&
         pbOwnedByPlayer?(idxBattler) &&
         AutoplayBot::BattlePolicy.try_register_turn(self, idxBattler, @battleAI, first_action)
        AutoplayBot::Runtime.note_battle_automation! if AutoplayBot::Runtime.respond_to?(:note_battle_automation!)
        return true
      end
      autoplay_bot_original_pbAutoFightMenu(idxBattler)
    end

    def pbDisplayConfirm(msg)
      AutoplayBot::Runtime.note_battle_engine_active!("confirm") if defined?(AutoplayBot::Runtime) &&
                                                                    AutoplayBot::Runtime.respond_to?(:note_battle_engine_active!)
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.prompt_control? &&
         defined?(AutoplayBot::BattlePolicy)
        response = AutoplayBot::BattlePolicy.battle_confirm_response(self, msg)
        return response unless response.nil?
        return AutoplayBot::PromptPolicy.confirm(msg, false) if defined?(AutoplayBot::PromptPolicy)
      end
      autoplay_bot_original_pbDisplayConfirm(msg)
    end

    def pbSwitchInBetween(idxBattler, checkLaxOnly = false, canCancel = false)
      AutoplayBot::Runtime.note_battle_engine_active!("switch prompt") if defined?(AutoplayBot::Runtime) &&
                                                                          AutoplayBot::Runtime.respond_to?(:note_battle_engine_active!)
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.prompt_control? &&
         defined?(AutoplayBot::BattlePolicy) &&
         pbOwnedByPlayer?(idxBattler)
        choice = AutoplayBot::BattlePolicy.best_replacement_index(self, idxBattler, checkLaxOnly, canCancel, @battleAI)
        if choice && choice.to_i >= 0
          AutoplayBot::BattlePolicy.clear_pending_enemy_switch(self)
          return choice.to_i
        end
        if canCancel
          AutoplayBot::BattlePolicy.clear_pending_enemy_switch(self)
          return -1
        end
      end
      ret = autoplay_bot_original_pbSwitchInBetween(idxBattler, checkLaxOnly, canCancel)
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.prompt_control? &&
         defined?(AutoplayBot::BattlePolicy) &&
         !pbOwnedByPlayer?(idxBattler)
        AutoplayBot::BattlePolicy.note_pending_enemy_switch(self, idxBattler, ret)
      end
      ret
    end

    def pbGetReplacementPokemonIndex(idxBattler, random = false)
      AutoplayBot::Runtime.note_battle_engine_active!("replacement") if defined?(AutoplayBot::Runtime) &&
                                                                        AutoplayBot::Runtime.respond_to?(:note_battle_engine_active!)
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.prompt_control? &&
         defined?(AutoplayBot::BattlePolicy) &&
         pbOwnedByPlayer?(idxBattler) &&
         !random
        choice = AutoplayBot::BattlePolicy.best_replacement_index(self, idxBattler, true, false, @battleAI)
        if choice && choice.to_i >= 0
          AutoplayBot::BattlePolicy.clear_pending_enemy_switch(self)
          return choice.to_i
        end
      end
      autoplay_bot_original_pbGetReplacementPokemonIndex(idxBattler, random)
    end

    if method_defined?(:autoplay_bot_original_pbEndOfBattle)
      def pbEndOfBattle(*args)
        ret = autoplay_bot_original_pbEndOfBattle(*args)
        AutoplayBot::RepeatableBattleLedger.note_battle_end(self) if defined?(AutoplayBot::RepeatableBattleLedger)
        if defined?(AutoplayBot::Runtime)
          if AutoplayBot::Runtime.respond_to?(:note_battle_engine_end!)
            AutoplayBot::Runtime.note_battle_engine_end!
          elsif AutoplayBot::Runtime.respond_to?(:note_battle_end_resume!)
            AutoplayBot::Runtime.note_battle_end_resume!
          end
        end
        ret
      end
    end
  end
end

if defined?(PokeBattle_BattleCommon)
  module PokeBattle_BattleCommon
    alias autoplay_bot_original_pbRecordAndStoreCaughtPokemon pbRecordAndStoreCaughtPokemon unless method_defined?(:autoplay_bot_original_pbRecordAndStoreCaughtPokemon)
    if method_defined?(:pbHandleCaughtPokemonStorage) && !method_defined?(:autoplay_bot_original_pbHandleCaughtPokemonStorage)
      alias autoplay_bot_original_pbHandleCaughtPokemonStorage pbHandleCaughtPokemonStorage
    end

    if method_defined?(:autoplay_bot_original_pbHandleCaughtPokemonStorage)
      def pbHandleCaughtPokemonStorage(caughtPokemon)
        if defined?(AutoplayBot::Runtime) &&
           AutoplayBot::Runtime.enabled? &&
           AutoplayBot::Runtime.running? &&
           defined?(AutoplayBot::TeamBuilder)
          AutoplayBot::Runtime.note_battle_engine_active!("caught storage") if AutoplayBot::Runtime.respond_to?(:note_battle_engine_active!)
          return AutoplayBot::Runtime.with_capture_storage_context("caught storage") do
            AutoplayBot::Runtime.with_battle_message_context("caught storage") do
              AutoplayBot::Runtime.with_forced_input_context("caught storage") do
                AutoplayBot::TeamBuilder.with_pending_caught(caughtPokemon) do
                  autoplay_bot_original_pbHandleCaughtPokemonStorage(caughtPokemon)
                end
              end
            end
          end
        end
        autoplay_bot_original_pbHandleCaughtPokemonStorage(caughtPokemon)
      ensure
        if defined?(AutoplayBot::TeamBuilder)
          if AutoplayBot::TeamBuilder.respond_to?(:request_roster_plan_refresh!)
            AutoplayBot::TeamBuilder.request_roster_plan_refresh!("after catch storage")
          else
            AutoplayBot::TeamBuilder.record_roster_plan!("after catch storage")
          end
        end
        AutoplayBot::TeamBuilder.request_training_rotation!("catch storage") if defined?(AutoplayBot::TeamBuilder) &&
                                                                                AutoplayBot::TeamBuilder.respond_to?(:request_training_rotation!)
      end
    end

    def pbRecordAndStoreCaughtPokemon
      caught = (@caughtPokemon ? @caughtPokemon.compact.dup : []) rescue []
      ret = if defined?(AutoplayBot::Runtime) &&
               AutoplayBot::Runtime.enabled? &&
               AutoplayBot::Runtime.running?
              AutoplayBot::Runtime.note_battle_engine_active!("caught record") if AutoplayBot::Runtime.respond_to?(:note_battle_engine_active!)
              AutoplayBot::Runtime.with_capture_storage_context("caught storage") do
                AutoplayBot::Runtime.with_battle_message_context("caught storage") do
                  AutoplayBot::Runtime.with_forced_input_context("caught storage") do
                    autoplay_bot_original_pbRecordAndStoreCaughtPokemon
                  end
                end
              end
            else
              autoplay_bot_original_pbRecordAndStoreCaughtPokemon
            end
      if defined?(AutoplayBot::DexTracker)
        caught.each do |pkmn|
          AutoplayBot::DexTracker.record_caught_pokemon(pkmn)
          AutoplayBot::BattlePolicy.note_caught_pokemon(pkmn) if defined?(AutoplayBot::BattlePolicy) &&
                                                                 AutoplayBot::BattlePolicy.respond_to?(:note_caught_pokemon)
        end
      end
      if defined?(AutoplayBot::TeamBuilder)
        if AutoplayBot::TeamBuilder.respond_to?(:request_roster_plan_refresh!)
          AutoplayBot::TeamBuilder.request_roster_plan_refresh!("after catch")
        else
          AutoplayBot::TeamBuilder.record_roster_plan!("after catch")
        end
      end
      AutoplayBot::TeamBuilder.request_training_rotation!("catch") if defined?(AutoplayBot::TeamBuilder) &&
                                                                      AutoplayBot::TeamBuilder.respond_to?(:request_training_rotation!)
      ret
    end
  end
end
