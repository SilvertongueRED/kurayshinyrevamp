module AutoplayBot
  module SceneObserver
    module_function

    def snapshot
      frame = frame_count
      scene_name = scene_class_name
      map_id = current_map_id
      x = player_x
      y = player_y
      raw_battle = raw_battle_flag_active?
      message = message_active?
      menu = menu_active?(scene_name)
      transfer = transfer_active?
      battle_scene = scene_name =~ /Battle/
      moving = player_moving?
      cutscene = cutscene_active?
      stale_raw = stale_raw_battle_on_map?(raw_battle, battle_scene, message, menu, transfer, moving, cutscene)
      runtime_battle = runtime_battle_hint?(stale_raw)
      scene = classify(scene_name, raw_battle, stale_raw, message, menu, transfer, battle_scene, cutscene, runtime_battle)

      update_stability(scene, map_id, x, y, frame)
      @last_snapshot = {
        "scene" => scene,
        "detail" => detail_for(scene, scene_name, raw_battle, stale_raw),
        "scene_name" => scene_name,
        "map_id" => map_id,
        "x" => x,
        "y" => y,
        "moving" => moving,
        "message" => message,
        "menu" => menu,
        "transfer" => transfer,
        "battle_scene" => battle_scene ? true : false,
        "runtime_battle" => runtime_battle,
        "raw_battle" => raw_battle,
        "stale_raw_battle" => stale_raw,
        "cutscene" => cutscene,
        "frame" => frame,
        "stable_frames" => @stable_frames.to_i,
        "map_stable_frames" => @map_stable_frames.to_i
      }
    rescue => e
      AutoplayBot.log("scene observer failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      {
        "scene" => "cutscene",
        "detail" => "observer error",
        "frame" => frame_count,
        "stable_frames" => 0,
        "map_stable_frames" => 0
      }
    end

    def last_snapshot
      @last_snapshot || snapshot
    rescue
      nil
    end

    def map_control_ready?(snap = nil)
      snap ||= last_snapshot || snapshot
      snap["scene"].to_s == "map" && !snap["moving"]
    rescue
      false
    end

    def battle_scene?(snap = nil)
      snap ||= last_snapshot || snapshot
      snap["scene"].to_s =~ /^battle/
    rescue
      false
    end

    def frame_count
      Graphics.frame_count rescue 0
    end

    def current_map_id
      defined?($game_map) && $game_map ? $game_map.map_id : nil
    rescue
      nil
    end

    def player_x
      defined?($game_player) && $game_player ? $game_player.x : nil
    rescue
      nil
    end

    def player_y
      defined?($game_player) && $game_player ? $game_player.y : nil
    rescue
      nil
    end

    def scene_class_name
      defined?($scene) && $scene ? $scene.class.to_s : "none"
    rescue
      "none"
    end

    def map_scene?
      defined?($scene) && defined?(Scene_Map) && $scene.is_a?(Scene_Map)
    rescue
      false
    end

    def raw_battle_flag_active?
      return true if defined?($game_temp) && $game_temp && $game_temp.respond_to?(:in_battle) && $game_temp.in_battle
      return true if defined?($PokemonSystem) && $PokemonSystem &&
                     $PokemonSystem.respond_to?(:is_in_battle) &&
                     $PokemonSystem.is_in_battle
      false
    rescue
      false
    end

    def message_active?
      defined?($game_temp) && $game_temp &&
        $game_temp.respond_to?(:message_window_showing) &&
        $game_temp.message_window_showing
    rescue
      false
    end

    def menu_active?(scene_name = nil)
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.respond_to?(:map_menu_flag_ignored?) &&
         AutoplayBot::Runtime.map_menu_flag_ignored?
        return false
      end
      return true if defined?($game_temp) && $game_temp &&
                      $game_temp.respond_to?(:in_menu) && $game_temp.in_menu
      name = scene_name || scene_class_name
      name =~ /Menu|Bag|Party|Summary|Pokedex|Pokemon|Storage|PC|Mart|Shop|Tutor|Option|Save|Load|Outfit|Cloth|Hair|Name|Sprite/
    rescue
      false
    end

    def transfer_active?
      return false unless defined?($game_temp) && $game_temp
      $game_temp.player_transferring || $game_temp.transition_processing || $game_temp.to_title
    rescue
      false
    end

    def player_moving?
      defined?($game_player) && $game_player &&
        $game_player.respond_to?(:moving?) && $game_player.moving?
    rescue
      false
    end

    def cutscene_active?
      return true if pokemon_temp_busy?
      return true if player_forced_or_hidden?
      return true if map_events_busy?
      if Object.new.respond_to?(:pbMapInterpreterRunning?, true)
        return true if Object.new.send(:pbMapInterpreterRunning?)
      end
      false
    rescue
      false
    end

    def pokemon_temp_busy?
      defined?($PokemonTemp) && $PokemonTemp &&
        $PokemonTemp.respond_to?(:miniupdate) && $PokemonTemp.miniupdate
    rescue
      false
    end

    def player_forced_or_hidden?
      return false unless defined?($game_player) && $game_player
      return true if $game_player.respond_to?(:move_route_forcing) && $game_player.move_route_forcing
      return true if $game_player.respond_to?(:transparent) && $game_player.transparent
      false
    rescue
      false
    end

    def map_events_busy?
      return false unless defined?($game_map) && $game_map
      if $game_map.respond_to?(:interpreter)
        interpreter = $game_map.interpreter
        return true if interpreter && interpreter.respond_to?(:running?) && interpreter.running?
      end
      events = $game_map.respond_to?(:events) ? $game_map.events : nil
      return false unless events && events.respond_to?(:values)
      events.values.any? do |event|
        event && event.respond_to?(:move_route_forcing) && event.move_route_forcing
      end
    rescue
      false
    end

    def stale_raw_battle_on_map?(raw_battle, battle_scene, message, menu, transfer, moving, cutscene)
      unless raw_battle
        @raw_battle_seen_frame = nil
        return false
      end
      frame = frame_count
      @raw_battle_seen_frame ||= frame
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.respond_to?(:stale_map_battle_context?) &&
         AutoplayBot::Runtime.stale_map_battle_context?
        return true
      end
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.respond_to?(:post_battle_overworld_resume?) &&
         AutoplayBot::Runtime.post_battle_overworld_resume?
        return true
      end
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.respond_to?(:live_battle_protected?) &&
         AutoplayBot::Runtime.live_battle_protected?
        return false
      end
      return false if battle_scene || message || menu || transfer || moving || cutscene
      return false unless map_scene?
      frame.to_i - @raw_battle_seen_frame.to_i >= 420
    rescue
      false
    end

    def runtime_battle_hint?(stale_raw = false)
      return false if stale_raw
      return false unless defined?(AutoplayBot::Runtime)
      if AutoplayBot::Runtime.respond_to?(:post_battle_overworld_resume?) &&
         AutoplayBot::Runtime.post_battle_overworld_resume?
        return false
      end
      if AutoplayBot::Runtime.respond_to?(:battle_state_hint?) &&
         AutoplayBot::Runtime.battle_state_hint?
        return true
      end
      false
    rescue
      false
    end

    def classify(_scene_name, raw_battle, stale_raw, message, menu, transfer, battle_scene, cutscene, runtime_battle = false)
      return "transfer" if transfer
      return(message ? "battle_message" : "battle_command") if battle_scene || runtime_battle
      return "message" if message
      return "menu" if menu
      return "battle_intro" if raw_battle && !stale_raw
      return "cutscene" if cutscene
      return "map" if map_scene?
      "cutscene"
    rescue
      "cutscene"
    end

    def detail_for(scene, scene_name, raw_battle, stale_raw)
      return "raw battle ignored on map" if stale_raw
      return scene_name.to_s if scene == "menu" || scene == "cutscene"
      return "battle flag" if raw_battle && scene == "battle_intro"
      scene_name.to_s
    rescue
      ""
    end

    def update_stability(scene, map_id, x, y, frame)
      if @last_scene == scene
        @stable_frames = @stable_frames.to_i + [frame.to_i - @last_frame.to_i, 1].max
      else
        @stable_frames = 0
      end
      if @last_map_id == map_id && @last_x == x && @last_y == y
        @map_stable_frames = @map_stable_frames.to_i + [frame.to_i - @last_frame.to_i, 1].max
      else
        @map_stable_frames = 0
      end
      @last_scene = scene
      @last_map_id = map_id
      @last_x = x
      @last_y = y
      @last_frame = frame
    rescue
      @stable_frames = 0
      @map_stable_frames = 0
    end
  end

  module Navigator
    DIR_DELTAS = {
      2 => [0, 1],
      4 => [-1, 0],
      6 => [1, 0],
      8 => [0, -1]
    } unless const_defined?(:DIR_DELTAS)

    module_function

    def state_memory_ready?
      return false unless defined?(AutoplayBot::State)
      return true unless AutoplayBot::State.respond_to?(:loaded?)
      AutoplayBot::State.loaded?
    rescue
      false
    end

    def reset!(reason = nil)
      @goal_key = nil
      @goal = nil
      @path = nil
      @path_index = 0
      @path_started_at = nil
      @last_target_key = nil
      @last_action = reason ? "reset #{reason}" : nil
      @recovery_reason = nil
      @escape_queue = nil
      @trying = nil
      @coast_watch = nil
      @pending_completion = nil if reason.to_s =~ /stop|start|manual|hotkey/i
      @recent_tiles = []
      @last_progress_frame = SceneObserver.frame_count
      @last_progress_pos = nil
    rescue
      nil
    end

    def observe_scene(snap)
      complete_pending_if_scene_changed(snap)
      remember_tile(snap)
      update_progress(snap)
    rescue => e
      AutoplayBot.log("navigator observe failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def coast_tick(snap)
      observe_scene(snap) if snap
      @last_action = "coast moving" if snap && snap["moving"]
    rescue
      nil
    end

    def coast_stalled?(snap)
      return false unless snap && snap["scene"].to_s == "map"
      queued_dir = queued_direction
      queued = [2, 4, 6, 8].include?(queued_dir)
      return false unless queued || @trying || snap["moving"]
      tile = [snap["map_id"], snap["x"], snap["y"]]
      @last_progress_pos ||= tile
      @last_progress_frame ||= snap["frame"].to_i
      return false unless @last_progress_pos == tile

      if @trying
        elapsed = snap["frame"].to_i - @trying["frame"].to_i
        return elapsed >= coast_stall_frame_limit(true)
      end

      if queued
        key = [snap["map_id"], snap["x"], snap["y"], queued_dir]
        if @coast_watch && @coast_watch["key"] == key
          elapsed = snap["frame"].to_i - @coast_watch["frame"].to_i
          return elapsed >= coast_stall_frame_limit(true)
        end
        @coast_watch = { "key" => key, "frame" => snap["frame"].to_i }
        return false
      end

      stable = snap["map_stable_frames"].to_i
      elapsed = snap["frame"].to_i - @last_progress_frame.to_i
      limit = coast_stall_frame_limit(false)
      stable >= limit || elapsed >= limit
    rescue
      false
    end

    def coast_looping?(snap)
      return false unless snap && snap["scene"].to_s == "map"
      return false unless queued_direction_active? || @trying || snap["moving"]
      loop_detected?
    rescue
      false
    end

    def queued_direction_active?
      [2, 4, 6, 8].include?(queued_direction)
    rescue
      false
    end

    def queued_direction
      return 0 unless defined?(AutoplayBot::InputQueue)
      return 0 unless AutoplayBot::InputQueue.respond_to?(:dir4)
      dir = AutoplayBot::InputQueue.dir4.to_i
      return dir if [2, 4, 6, 8].include?(dir)
      0
    rescue
      0
    end

    def coast_stall_frame_limit(bot_owned = true)
      speed = navigation_speedup_multiplier
      base = bot_owned ? 30 : 72
      return 10 if speed >= 7 && bot_owned
      return 16 if speed >= 3 && bot_owned
      return 28 if bot_owned
      base
    rescue
      30
    end

    def note_coast_stall!(snap, reason = "coast_stalled")
      begin_recovery(reason, snap) if snap
      @last_action = "stalled #{reason}"
    rescue
      nil
    end

    def note_static_coast_block!(dir, reason = "static_coast_blocked")
      dir = dir.to_i
      return false unless [2, 4, 6, 8].include?(dir)
      snap = (SceneObserver.snapshot rescue nil) || SceneObserver.last_snapshot
      return false unless snap && snap["scene"].to_s == "map"
      @trying = {
        "frame" => snap["frame"].to_i,
        "map_id" => snap["map_id"],
        "x" => snap["x"],
        "y" => snap["y"],
        "dir" => dir,
        "run" => 1,
        "moved" => 0
      }
      remember_blocked_try!(reason)
      @recovery_reason = reason.to_s
      @path = nil
      @path_index = 0
      @coast_watch = nil
      @escape_queue = escape_dirs(reason, snap)
      @trying = nil
      @last_progress_pos = [snap["map_id"], snap["x"], snap["y"]]
      @last_progress_frame = snap["frame"].to_i
      @last_action = "blocked #{dir_label(dir)}"
      true
    rescue
      false
    end

    def follow(goal, snap)
      return false unless goal && snap
      observe_scene(snap)
      return wait_action("waiting: #{snap["scene"]}") unless snap["scene"].to_s == "map"
      if snap["moving"]
        if coast_stalled?(snap)
          begin_recovery("moving_no_progress", snap)
          return escape_step(snap)
        elsif coast_looping?(snap)
          begin_recovery(loop_axis == :vertical ? "vertical_loop" : "horizontal_loop", snap)
          return escape_step(snap)
        end
        return wait_action("moving")
      end

      if @escape_queue && !@escape_queue.empty?
        return escape_step(snap)
      end

      commit_goal(goal, snap)
      if @trying && !stale_without_progress?(snap)
        dir = @trying["dir"].to_i
        elapsed = snap["frame"].to_i - @trying["frame"].to_i
        return wait_action("try #{dir_label(dir)} #{elapsed}f")
      end
      if loop_detected?
        begin_recovery(loop_axis == :vertical ? "vertical_loop" : "horizontal_loop", snap)
        return escape_step(snap)
      end
      if stale_without_progress?(snap)
        begin_recovery("stuck_no_progress", snap)
        return escape_step(snap)
      end

      ensure_path(goal, snap)
      unless @path
        if goal["kind"].to_s == "progress"
          begin_recovery("no_path", snap)
          return escape_step(snap)
        end
        fail_goal(goal, "no_path")
        return false
      end
      if @path_index.to_i >= @path.length
        return activate_or_finish(goal, snap)
      end

      issue_path_run(goal, snap)
    rescue => e
      @last_action = "navigator error #{e.class}"
      AutoplayBot.log("navigator follow failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def commit_goal(goal, snap)
      key = goal_key(goal)
      if @goal_key != key || @goal_map_id.to_i != snap["map_id"].to_i
        @goal_key = key
        @goal_map_id = snap["map_id"]
        @goal = goal
        @path = nil
        @path_index = 0
        @path_started_at = snap["frame"]
        @recovery_reason = nil
        @escape_queue = nil
        @trying = nil
        @recent_tiles = []
        @last_progress_pos = [snap["map_id"], snap["x"], snap["y"]]
        @last_progress_frame = snap["frame"]
        log_transition("target #{goal_label(goal)}")
      end
    rescue
      nil
    end

    def ensure_path(goal, snap)
      return if @path && @path_index.to_i < @path.length
      @path = build_path(goal)
      @path_index = 0
      @path_started_at = snap["frame"]
      if @path
        @last_action = @path.empty? ? "at target" : "path #{@path.length} steps"
      else
        @last_action = "no path"
      end
    rescue => e
      @path = nil
      @last_action = "path error #{e.class}"
    end

    def build_path(goal)
      record = goal["record"].is_a?(Hash) ? goal["record"] : goal
      budget = path_budget(goal)
      kind = goal["kind"].to_s
      if ["nearby_collect", "nearby_npc", "nearby_building", "battle", "shop", "heal"].include?(kind) ||
         ["item", "resource", "npc", "trainer", "event"].include?(goal["target_kind"].to_s)
        path = event_path(record, budget)
        return path if path
      end
      x = (goal["x"] || record["x"]).to_i
      y = (goal["y"] || record["y"]).to_i
      include_adjacent = goal["include_adjacent"] == true
      AutoplayBot::Pathfinder.path_to(x, y, budget, include_adjacent)
    rescue
      nil
    end

    def event_path(record, budget)
      if defined?(AutoplayBot::Director) &&
         AutoplayBot::Director.respond_to?(:path_to_event_action)
        return AutoplayBot::Director.path_to_event_action(record, budget)
      end
      include_adjacent = ![1, 2].include?(record["trigger"].to_i)
      AutoplayBot::Pathfinder.path_to(record["x"].to_i, record["y"].to_i, budget, include_adjacent)
    rescue
      nil
    end

    def issue_path_run(goal, snap)
      dir = @path[@path_index].to_i
      unless [2, 4, 6, 8].include?(dir)
        @path_index += 1
        return true
      end
      unless passable_from_player?(dir)
        @trying = {
          "frame" => snap["frame"],
          "map_id" => snap["map_id"],
          "x" => snap["x"],
          "y" => snap["y"],
          "dir" => dir,
          "run" => 1,
          "moved" => 0
        }
        begin_recovery("blocked_step", snap)
        return escape_step(snap)
      end
      run = straight_run_count(dir, goal)
      frames = hold_frames_for(dir, run, goal)
      @trying = {
        "frame" => snap["frame"],
        "map_id" => snap["map_id"],
        "x" => snap["x"],
        "y" => snap["y"],
        "dir" => dir,
        "run" => run,
        "moved" => 0
      }
      @last_action = "move #{dir_label(dir)} #{run}t"
      AutoplayBot::InputQueue.hold_dir(dir, frames) if defined?(AutoplayBot::InputQueue)
      AutoplayBot.status("nav #{goal_label(goal)} #{dir_label(dir)} #{remaining_steps} left") if AutoplayBot.respond_to?(:status)
      true
    rescue => e
      @last_action = "move error #{e.class}"
      false
    end

    def straight_run_count(dir, goal)
      cap = straight_run_cap(goal)
      count = 0
      i = @path_index.to_i
      while i < @path.length && @path[i].to_i == dir && count < cap
        count += 1
        i += 1
      end
      [count, 1].max
    rescue
      1
    end

    def straight_run_cap(goal)
      speed = navigation_speedup_multiplier
      if speed >= 7
        return 1
      elsif speed >= 3
        return 1 if ["nearby_collect", "nearby_npc", "nearby_building", "battle", "shop", "heal"].include?(goal["kind"].to_s)
        return 2 if goal["kind"].to_s =~ /building|shop|heal/
      end
      return 1 if ["nearby_collect", "nearby_npc", "nearby_building", "battle", "shop", "heal"].include?(goal["kind"].to_s)
      map_id = current_map_id.to_i
      if defined?(AutoplayBot::Director)
        building_ids = AutoplayBot::Director.const_defined?(:BUILDING_CLEANUP_MAP_IDS) ? AutoplayBot::Director.const_get(:BUILDING_CLEANUP_MAP_IDS) : []
        town_ids = AutoplayBot::Director.const_defined?(:TOWN_CLEANUP_MAP_IDS) ? AutoplayBot::Director.const_get(:TOWN_CLEANUP_MAP_IDS) : []
        return 3 if building_ids.include?(map_id)
        return 8 if town_ids.include?(map_id)
      end
      6
    rescue
      4
    end

    def navigation_speedup_multiplier
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.respond_to?(:game_speed_multiplier)
        return AutoplayBot::Runtime.game_speed_multiplier.to_i
      end
      defined?($GameSpeed) ? $GameSpeed.to_i : 1
    rescue
      1
    end

    def hold_frames_for(_dir, run, goal)
      path_segment = []
      run.to_i.times { path_segment << @path[@path_index.to_i].to_i }
      if defined?(AutoplayBot::Director) &&
         AutoplayBot::Director.respond_to?(:movement_hold_frames)
        minimum = goal["kind"].to_s == "progress" ? 5 : 4
        minimum = 4 if navigation_speedup_multiplier >= 7
        frames = AutoplayBot::Director.movement_hold_frames(path_segment, minimum)
        return [[frames.to_i, minimum].max, 12].min if navigation_speedup_multiplier >= 7
        return frames
      end
      [run.to_i * 8, 4].max
    rescue
      8
    end

    def activate_or_finish(goal, snap)
      record = goal["record"].is_a?(Hash) ? goal["record"] : goal
      kind = goal["kind"].to_s
      if goal["exit_dir"]
        dir = goal["exit_dir"].to_i
        @last_action = "exit #{dir_label(dir)}"
        @pending_completion = completion_record(goal, snap)
        AutoplayBot::InputQueue.hold_dir(dir, transfer_hold_frames) if defined?(AutoplayBot::InputQueue)
        AutoplayBot.status("exit #{goal_label(goal)}") if AutoplayBot.respond_to?(:status)
        return true
      end
      if kind == "progress" || kind == "nearby_building" || record["trigger"].to_i == 1
        @last_action = "step transfer"
        @pending_completion = completion_record(goal, snap)
        AutoplayBot.status("enter #{goal_label(goal)}") if AutoplayBot.respond_to?(:status)
        return true
      end
      face_and_use(goal, record, snap)
    rescue => e
      @last_action = "activate error #{e.class}"
      false
    end

    def transfer_hold_frames
      speed = navigation_speedup_multiplier
      return 4 if speed >= 7
      return 5 if speed >= 3
      8
    rescue
      6
    end

    def face_and_use(goal, record, snap)
      dir = record["face_dir"] ? record["face_dir"].to_i : direction_toward(record["x"].to_i, record["y"].to_i, snap["x"].to_i, snap["y"].to_i)
      key = goal_key(goal)
      if dir && [2, 4, 6, 8].include?(dir)
        unless player_facing_dir == dir
          AutoplayBot::InputQueue.hold_dir(dir, 1) if defined?(AutoplayBot::InputQueue)
          @last_action = "face #{dir_label(dir)}"
          AutoplayBot.status("face #{goal_label(goal)} #{dir_label(dir)}") if AutoplayBot.respond_to?(:status)
          return true
        end
        if state_memory_ready?
          AutoplayBot::State.mark_target_attempted(record, "activate", goal["target_kind"] || goal["kind"]) if AutoplayBot::State.respond_to?(:mark_target_attempted)
        end
        @pending_completion = completion_record(goal, snap)
        AutoplayBot::InputQueue.tap(:USE, 1) if defined?(AutoplayBot::InputQueue)
        @last_action = "face #{dir_label(dir)} use"
      else
        if state_memory_ready?
          AutoplayBot::State.mark_target_attempted(record, "activate", goal["target_kind"] || goal["kind"]) if AutoplayBot::State.respond_to?(:mark_target_attempted)
        end
        @pending_completion = completion_record(goal, snap)
        AutoplayBot::InputQueue.tap(:USE, 2) if defined?(AutoplayBot::InputQueue)
        @last_action = "use"
      end
      AutoplayBot.status("use #{goal_label(goal)}") if AutoplayBot.respond_to?(:status)
      @last_target_key = key
      true
    rescue
      false
    end

    def completion_record(goal, snap)
      {
        "goal" => goal,
        "key" => goal_key(goal),
        "kind" => goal["target_kind"] || goal["kind"],
        "map_id" => snap["map_id"],
        "x" => snap["x"],
        "y" => snap["y"],
        "frame" => snap["frame"]
      }
    rescue
      nil
    end

    def complete_pending_if_scene_changed(snap)
      pending = @pending_completion
      return unless pending && snap
      elapsed = snap["frame"].to_i - pending["frame"].to_i
      if snap["map_id"].to_i != pending["map_id"].to_i
        mark_pending_done(pending, true, "map changed")
        @pending_completion = nil
        reset!("map change")
        return
      end
      if snap["scene"].to_s != "map" && elapsed >= 1
        mark_pending_done(pending, false, "scene #{snap["scene"]}")
        @pending_completion = nil
        return
      end
      if elapsed > pending_completion_timeout_frames(pending)
        mark_pending_failed(pending, "no_response")
        @pending_completion = nil
        begin_recovery("interaction_no_response", snap)
      end
    rescue
      @pending_completion = nil
    end

    def pending_completion_timeout_frames(pending)
      kind = pending && pending["kind"].to_s
      goal = pending && pending["goal"].is_a?(Hash) ? pending["goal"] : {}
      record = goal && goal["record"].is_a?(Hash) ? goal["record"] : goal
      text = [kind, goal && goal["kind"], goal && goal["target_kind"]].compact.join(" ")
      fast_interaction = (record && record["live_goal"]) || text =~ /nearby|resource|item|npc|trainer/
      base = fast_interaction ? 48 : 120
      speed = navigation_speedup_multiplier
      return [[base / 3, 16].max, base].min if speed >= 7
      return [[base / 2, 24].max, base].min if speed >= 3
      base
    rescue
      60
    end

    def mark_pending_done(pending, transfer, reason)
      goal = pending["goal"] || {}
      record = goal["record"].is_a?(Hash) ? goal["record"] : goal
      kind = pending["kind"] || goal["kind"]
      remember_local_done_target(record, kind, reason)
      if state_memory_ready?
        AutoplayBot::State.mark_target_done(record, kind) if AutoplayBot::State.respond_to?(:mark_target_done)
        AutoplayBot::State.mark_transfer_visited(record["key"]) if transfer && record["key"] && AutoplayBot::State.respond_to?(:mark_transfer_visited)
        AutoplayBot::State.touch_frontier(record["key"], true, reason) if transfer && record["key"] && AutoplayBot::State.respond_to?(:touch_frontier)
        AutoplayBot::State.touch_cleanup_target(AutoplayBot::State.target_key(record, kind), true, reason) if AutoplayBot::State.respond_to?(:touch_cleanup_target)
      end
      AutoplayBot::WorldCoveragePlanner.note_target_done(record, transfer ? "transfer" : kind, reason) if defined?(AutoplayBot::WorldCoveragePlanner)
      log_transition("complete #{goal_label(goal)} #{reason}")
    rescue
      nil
    end

    def mark_pending_failed(pending, reason)
      goal = pending["goal"] || {}
      record = goal["record"].is_a?(Hash) ? goal["record"] : goal
      fail_goal_record(record, goal["target_kind"] || goal["kind"], reason)
    rescue
      nil
    end

    def fail_goal(goal, reason)
      record = goal["record"].is_a?(Hash) ? goal["record"] : goal
      fail_goal_record(record, goal["target_kind"] || goal["kind"], reason)
      reset!(reason)
    rescue
      nil
    end

    def fail_goal_record(record, kind, reason)
      remember_local_failed_target(record, kind, reason)
      return unless state_memory_ready?
      AutoplayBot::State.mark_target_attempted(record, reason, kind) if AutoplayBot::State.respond_to?(:mark_target_attempted)
      attempts = AutoplayBot::State.target_attempt_count(record, kind) rescue 0
      if attempts.to_i >= target_attempt_limit(kind)
        AutoplayBot::State.mark_target_failed(record, reason, kind) if AutoplayBot::State.respond_to?(:mark_target_failed)
        key = AutoplayBot::State.target_key(record, kind) rescue nil
        AutoplayBot::State.touch_frontier(key, false, reason) if key && AutoplayBot::State.respond_to?(:touch_frontier)
        AutoplayBot::State.touch_cleanup_target(key, false, reason) if key && AutoplayBot::State.respond_to?(:touch_cleanup_target)
        AutoplayBot.log("navigator skipped #{key}: #{reason}") if AutoplayBot.respond_to?(:log)
      end
      AutoplayBot::WorldCoveragePlanner.note_target_failed(record, kind, reason) if defined?(AutoplayBot::WorldCoveragePlanner) && attempts.to_i >= target_attempt_limit(kind)
    rescue
      nil
    end

    def remember_local_failed_target(record, kind, reason)
      return unless record
      @local_failed_targets ||= {}
      key = local_target_key(record, kind)
      frame = SceneObserver.frame_count
      entry = @local_failed_targets[key] ||= { "count" => 0 }
      entry["count"] = entry["count"].to_i + 1
      entry["reason"] = reason.to_s
      entry["until"] = if reason.to_s =~ /missing_field_move/i
                         frame + 3600
                       else
                         frame + (entry["count"].to_i >= 5 ? 1800 : 360)
                       end
      remember_local_failed_alias(record, reason, entry["until"])
      log_transition("defer #{key} #{reason}")
    rescue
      nil
    end

    def remember_local_failed_alias(record, reason, until_frame)
      return unless record
      @local_failed_targets ||= {}
      alias_key = local_target_key(record, "any")
      entry = @local_failed_targets[alias_key] ||= { "count" => 0 }
      entry["count"] = [entry["count"].to_i + 1, 5].min
      entry["reason"] = reason.to_s
      entry["until"] = [entry["until"].to_i, until_frame.to_i].max
    rescue
      nil
    end

    def remember_local_done_target(record, kind, reason)
      return unless record
      @local_done_targets ||= {}
      key = local_target_key(record, kind)
      frame = SceneObserver.frame_count
      cooldown = local_done_cooldown_frames(kind, reason)
      entry = @local_done_targets[key] ||= { "count" => 0 }
      entry["count"] = entry["count"].to_i + 1
      entry["reason"] = reason.to_s
      entry["until"] = frame + cooldown
      alias_entry = @local_done_targets[local_target_key(record, "any")] ||= { "count" => 0 }
      alias_entry["count"] = alias_entry["count"].to_i + 1
      alias_entry["reason"] = reason.to_s
      alias_entry["until"] = [alias_entry["until"].to_i, frame + cooldown].max
    rescue
      nil
    end

    def local_done_cooldown_frames(kind, reason)
      text = [kind, reason].compact.join(" ")
      return 1800 if text =~ /rock_smash|strength|cut|field/i
      return 3600 if text =~ /resource|item|nearby_collect/i && text =~ /scene message|message|map changed/i
      return 900 if text =~ /scene message|message/i
      600
    rescue
      600
    end

    def target_locally_failed?(record, kind)
      purge_local_failed_targets
      purge_local_done_targets
      done = @local_done_targets && @local_done_targets[local_target_key(record, kind)]
      return true if done && done["until"].to_i > SceneObserver.frame_count.to_i
      any_done = @local_done_targets && @local_done_targets[local_target_key(record, "any")]
      return true if any_done && any_done["until"].to_i > SceneObserver.frame_count.to_i
      entry = @local_failed_targets && @local_failed_targets[local_target_key(record, kind)]
      return true if entry && entry["until"].to_i > SceneObserver.frame_count.to_i
      any_failed = @local_failed_targets && @local_failed_targets[local_target_key(record, "any")]
      any_failed && any_failed["until"].to_i > SceneObserver.frame_count.to_i
    rescue
      false
    end

    def purge_local_failed_targets
      return unless @local_failed_targets
      frame = SceneObserver.frame_count.to_i
      @local_failed_targets.delete_if { |_key, entry| entry["until"].to_i <= frame }
    rescue
      nil
    end

    def purge_local_done_targets
      return unless @local_done_targets
      frame = SceneObserver.frame_count.to_i
      @local_done_targets.delete_if { |_key, entry| entry["until"].to_i <= frame }
    rescue
      nil
    end

    def local_target_key(record, kind)
      if kind.to_s == "any"
        return [
          kind,
          record["map_id"] || current_map_id,
          record["x"],
          record["y"],
          record["destination_map_id"]
        ].compact.join(":")
      end
      [
        kind,
        record["map_id"] || current_map_id,
        record["key"],
        record["event_id"],
        record["x"],
        record["y"],
        record["destination_map_id"]
      ].compact.join(":")
    rescue
      kind.to_s
    end

    def begin_recovery(reason, snap)
      remember_blocked_try!(reason)
      @recovery_reason = reason
      @path = nil
      @path_index = 0
      @escape_queue = escape_dirs(reason, snap)
      @trying = nil
      signature = stuck_signature(reason, snap)
      if state_memory_ready? && AutoplayBot::State.respond_to?(:record_stuck_signature)
        AutoplayBot::State.record_stuck_signature(signature, reason, diagnostic(snap))
      end
      @last_action = "recover #{reason}"
      AutoplayBot.status("recover #{reason}") if AutoplayBot.respond_to?(:status)
    rescue
      nil
    end

    def escape_step(snap)
      @escape_queue ||= escape_dirs("stuck", snap)
      while @escape_queue && !@escape_queue.empty?
        dir = @escape_queue.shift.to_i
        next unless [2, 4, 6, 8].include?(dir)
        if passable_from_player?(dir)
          AutoplayBot::InputQueue.hold_dir(dir, escape_hold_frames) if defined?(AutoplayBot::InputQueue)
          @trying = { "frame" => snap["frame"], "map_id" => snap["map_id"], "x" => snap["x"], "y" => snap["y"], "dir" => dir, "run" => 1 }
          @last_action = "escape #{dir_label(dir)}"
          return true
        end
      end
      fail_goal(@goal || {}, @recovery_reason || "escape_failed") if @goal
      false
    rescue
      false
    end

    def escape_hold_frames
      speed = navigation_speedup_multiplier
      return 4 if speed >= 7
      return 5 if speed >= 3
      8
    rescue
      6
    end

    def escape_dirs(reason, _snap)
      blocked_dir = @trying && @trying["dir"].to_i
      if [2, 4, 6, 8].include?(blocked_dir)
        side = blocked_dir == 2 || blocked_dir == 8 ? [4, 6] : [8, 2]
        return (side + [reverse_dir(blocked_dir), blocked_dir]).compact.uniq
      end
      if reason.to_s =~ /horizontal/
        [8, 2, 4, 6]
      elsif reason.to_s =~ /vertical/
        [4, 6, 8, 2]
      else
        [8, 2, 4, 6]
      end
    rescue
      [8, 2, 4, 6]
    end

    def passable_from_player?(dir)
      return false unless defined?($game_player) && $game_player
      return false if live_event_blocked_from_player?(dir)
      return $game_player.can_move_in_direction?(dir) if $game_player.respond_to?(:can_move_in_direction?)
      if defined?(AutoplayBot::Pathfinder) && AutoplayBot::Pathfinder.respond_to?(:passable?)
        return AutoplayBot::Pathfinder.passable?($game_player.x, $game_player.y, dir)
      end
      $game_player.passable?($game_player.x, $game_player.y, dir)
    rescue
      false
    end

    def live_event_blocked_from_player?(dir)
      return false unless [2, 4, 6, 8].include?(dir.to_i)
      return false unless defined?($game_player) && $game_player
      dx, dy = DIR_DELTAS[dir.to_i] || [0, 0]
      blocking_event_at?($game_player.x.to_i + dx, $game_player.y.to_i + dy)
    rescue
      false
    end

    def blocking_event_at?(tx, ty)
      return false unless defined?($game_map) && $game_map && $game_map.respond_to?(:events)
      events = $game_map.events ? $game_map.events.values : []
      events.any? { |event| blocking_event?(event, tx, ty) }
    rescue
      false
    end

    def blocking_event?(event, tx, ty)
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

    def update_progress(snap)
      pos = [snap["map_id"], snap["x"], snap["y"]]
      if @last_progress_pos != pos
        advance_path_for_movement(@last_progress_pos, pos)
        @last_progress_pos = pos
        @last_progress_frame = snap["frame"]
        @coast_watch = nil
      end
    rescue
      nil
    end

    def advance_path_for_movement(previous, current)
      return unless previous && current
      return unless previous[0].to_i == current[0].to_i
      dir, steps = movement_dir_and_steps(previous, current)
      return unless dir
      steps.times do
        if @path && @path[@path_index.to_i].to_i == dir.to_i
          @path_index = @path_index.to_i + 1
        elsif @trying && @trying["dir"].to_i == dir.to_i && @path
          @path_index = [@path_index.to_i + 1, @path.length].min
        else
          @path = nil
          @path_index = 0
          @last_action = "repath after drift"
          break
        end
      end
      @trying = nil
    rescue
      @trying = nil
    end

    def movement_dir_and_steps(previous, current)
      dx = current[1].to_i - previous[1].to_i
      dy = current[2].to_i - previous[2].to_i
      return [6, dx.abs] if dx > 0 && dy == 0
      return [4, dx.abs] if dx < 0 && dy == 0
      return [2, dy.abs] if dy > 0 && dx == 0
      return [8, dy.abs] if dy < 0 && dx == 0
      nil
    rescue
      nil
    end

    def stale_without_progress?(snap)
      return false unless @goal
      return false if snap["moving"]
      return false unless @trying
      elapsed = snap["frame"].to_i - @trying["frame"].to_i
      elapsed > blocked_try_frame_limit
    rescue
      false
    end

    def blocked_try_frame_limit
      return 36 if @goal && @goal["kind"].to_s == "progress"
      30
    rescue
      36
    end

    def remember_tile(snap)
      return unless snap && snap["scene"].to_s == "map"
      tile = [snap["map_id"], snap["x"], snap["y"]]
      @recent_tiles ||= []
      @recent_tiles << tile
      @recent_tiles.shift while @recent_tiles.length > 12
    rescue
      nil
    end

    def loop_detected?
      return false unless @recent_tiles && @recent_tiles.length >= 8
      tiles = @recent_tiles.last(8)
      return false if tiles.map { |t| t[0] }.uniq.length > 1
      xs = tiles.map { |t| t[1] }.uniq.compact
      ys = tiles.map { |t| t[2] }.uniq.compact
      return true if xs.length == 2 && ys.length == 1 && tiles.length >= 8
      return true if ys.length == 2 && xs.length == 1 && tiles.length >= 8
      false
    rescue
      false
    end

    def loop_axis
      tiles = @recent_tiles.last(8)
      xs = tiles.map { |t| t[1] }.uniq.compact
      ys = tiles.map { |t| t[2] }.uniq.compact
      return :horizontal if xs.length == 2 && ys.length == 1
      return :vertical if ys.length == 2 && xs.length == 1
      :unknown
    rescue
      :unknown
    end

    def stuck_signature(reason, snap)
      goal = @goal || {}
      [reason, snap["scene"], snap["map_id"], snap["x"], snap["y"], goal_key(goal)].compact.join(":")
    rescue
      reason.to_s
    end

    def diagnostic(snap = nil)
      snap ||= SceneObserver.last_snapshot || {}
      goal = @goal || {}
      {
        "scene" => snap["scene"],
        "goal" => goal["kind"],
        "target" => goal_key(goal),
        "tile" => [snap["map_id"], snap["x"], snap["y"]].compact.join(","),
        "moving" => snap["moving"],
        "queued_dir" => (defined?(AutoplayBot::InputQueue) ? AutoplayBot::InputQueue.dir4 : nil),
        "path_index" => @path_index,
        "path_left" => remaining_steps,
        "action" => @last_action
      }
    rescue
      {}
    end

    def current_map_id
      defined?($game_map) && $game_map ? $game_map.map_id : nil
    rescue
      nil
    end

    def player_facing_dir
      return nil unless defined?($game_player) && $game_player
      return $game_player.direction.to_i if $game_player.respond_to?(:direction)
      nil
    rescue
      nil
    end

    def direction_toward(tx, ty, px = nil, py = nil)
      px ||= defined?($game_player) && $game_player ? $game_player.x : nil
      py ||= defined?($game_player) && $game_player ? $game_player.y : nil
      return nil if px.nil? || py.nil?
      dx = tx.to_i - px.to_i
      dy = ty.to_i - py.to_i
      return 6 if dx > 0 && dx.abs >= dy.abs
      return 4 if dx < 0 && dx.abs >= dy.abs
      return 2 if dy > 0
      return 8 if dy < 0
      nil
    rescue
      nil
    end

    def reverse_dir(dir)
      { 2 => 8, 8 => 2, 4 => 6, 6 => 4 }[dir.to_i]
    rescue
      nil
    end

    def remember_blocked_try!(reason)
      return unless @trying
      dir = @trying["dir"].to_i
      return unless [2, 4, 6, 8].include?(dir)
      pos = [@trying["map_id"], @trying["x"], @trying["y"]]
      if defined?(AutoplayBot::Director) && AutoplayBot::Director.respond_to?(:remember_blocked_step!)
        AutoplayBot::Director.remember_blocked_step!(pos, dir, reason)
      end
    rescue
      nil
    end

    def path_budget(goal)
      kind = goal["target_kind"] || goal["kind"]
      default = goal["kind"].to_s == "progress" ? 3200 : 900
      if defined?(AutoplayBot::BotCore) &&
         AutoplayBot::BotCore.respond_to?(:cold_start?) &&
         AutoplayBot::BotCore.cold_start?
        default = [default, 1600].min
      end
      if defined?(AutoplayBot::Config) && AutoplayBot::Config.respond_to?(:adaptive_path_node_budget)
        return AutoplayBot::Config.adaptive_path_node_budget(default, kind)
      end
      default
    rescue
      1200
    end

    def remaining_steps
      return 0 unless @path
      [@path.length - @path_index.to_i, 0].max
    rescue
      0
    end

    def path_length
      @path ? @path.length.to_i : nil
    rescue
      nil
    end

    def goal_key(goal)
      record = goal["record"].is_a?(Hash) ? goal["record"] : goal
      return record["nav_key"].to_s if record["nav_key"]
      return goal["nav_key"].to_s if goal["nav_key"]
      if state_memory_ready? && AutoplayBot::State.respond_to?(:target_key)
        return AutoplayBot::State.target_key(record, goal["target_kind"] || goal["kind"])
      end
      [goal["kind"], record["map_id"], record["key"], record["x"], record["y"], record["destination_map_id"]].compact.join(":")
    rescue
      "goal"
    end

    def goal_label(goal)
      label = goal["label"] || goal["event_name"] || (goal["record"] && goal["record"]["event_name"]) || goal["kind"]
      label.to_s.gsub(/\s+/, " ").strip
    rescue
      "goal"
    end

    def dir_label(dir)
      case dir.to_i
      when 2 then "down"
      when 4 then "left"
      when 6 then "right"
      when 8 then "up"
      else "dir"
      end
    rescue
      "dir"
    end

    def wait_action(text)
      @last_action = text
      true
    rescue
      true
    end

    def log_transition(text)
      return if @last_logged_transition == text
      @last_logged_transition = text
      AutoplayBot.log("navigator #{text}") if AutoplayBot.respond_to?(:log)
    rescue
      nil
    end

    def debug_overlay_lines
      lines = []
      if @goal
        target = goal_key(@goal)
        bits = ["Target #{short(@goal["kind"], 12)}"]
        bits << short(target, 34)
        bits << "#{remaining_steps} left" if @path
        lines << bits.join(" ")
      end
      lines << "Action #{short(@last_action, 54)}" if @last_action && !@last_action.to_s.empty?
      lines << "Recover #{short(@recovery_reason, 48)}" if @recovery_reason
      lines
    rescue
      []
    end

    def short(text, max)
      value = text.to_s.gsub(/\s+/, " ").strip
      value.length > max.to_i ? value[0, max.to_i - 3] + "..." : value
    rescue
      ""
    end
  end

  module DexHuntPlanner
    module_function

    HUNT_STATES = [
      "assess",
      "heal",
      "restock",
      "select_zone",
      "travel_to_zone",
      "patrol",
      "battle",
      "post_battle",
      "rotate_team",
      "unlock_next_area"
    ] unless const_defined?(:HUNT_STATES)

    def reset_runtime!(reason = nil)
      finish_session!(reason || "reset")
      @state = "assess"
      @current_zone_key = nil
      @current_zone_method = nil
      @current_map_id = nil
      @current_session = nil
      @last_action = "ready"
    rescue
      nil
    end

    def enabled?
      defined?(AutoplayBot::Config) &&
        AutoplayBot::Config.respond_to?(:wild_capture_focus?) &&
        AutoplayBot::Config.wild_capture_focus?
    rescue
      false
    end

    def choose_goal(snap, story = nil, map = nil)
      return nil unless enabled?
      return nil unless snap && snap["scene"].to_s == "map"
      observe_zone_context!(snap)
      if snap["moving"] || snap["transfer"] || snap["cutscene"] || snap["raw_battle"]
        @state = "assess"
        @last_action = "waiting for map control"
        return nil
      end

      if hard_restock_needed?
        goal = safe_botcore_call(:pokemart_restock_goal, map, snap, story)
        return annotate_goal(goal, "restock", "balls below floor") if goal
        @state = "restock"
        @last_action = "balls low; finding shop"
      end

      method = detect_zone_method(snap)
      if method && hunt_zone_budget_expired?(snap, method)
        cooldown_zone!(snap, method, "low_yield")
        @state = "select_zone"
        @last_action = "zone #{method} cooled down"
        return nil if conservative_unlocks?
      end

      if method && wild_supplies_ready? && !zone_on_cooldown?(snap, method)
        goal = safe_botcore_call(:wild_capture_goal, snap)
        return annotate_goal(goal, "patrol", "#{method} hunt") if goal
        @state = "patrol"
        @last_action = "#{method} zone; choosing patrol"
      end

      if manual_unlocks?
        @state = "unlock_next_area"
        @last_action = "manual unlock mode; no local zone"
        return nil
      end
      return annotate_goal(story, "unlock_next_area", "unlock more species") if story && conservative_unlocks?
      @state = "select_zone"
      @last_action = method ? "zone unavailable; explorer fallback" : "no zone here; seek grass/cave"
      nil
    rescue => e
      @state = "assess"
      @last_action = "hunt error #{e.class}"
      AutoplayBot.log("dex hunt planner failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      nil
    end

    def observe_zone_context!(snap)
      method = detect_zone_method(snap)
      map_id = snap["map_id"].to_i
      if method
        zone_key = zone_key(map_id, method)
        start_session!(map_id, method) if @current_zone_key != zone_key
        record_zone(map_id, method)
      elsif @current_map_id && @current_map_id.to_i != map_id
        finish_session!("map_change")
      end
      @current_map_id = map_id
    rescue
      nil
    end

    def detect_zone_method(snap = nil)
      snap ||= last_snapshot
      return nil unless snap
      return "cave_floor" if safe_botcore_call(:cave_encounter_map?) &&
                             safe_botcore_call(:cave_floor_tile?, snap["x"], snap["y"])
      return "grass" if safe_botcore_call(:grass_tile?, snap["x"], snap["y"])
      nearby = safe_botcore_call(:nearby_grass_targets, snap, 8)
      return "grass" if nearby && nearby.respond_to?(:any?) && nearby.any?
      nil
    rescue
      nil
    end

    def record_observed_pokemon(pokemon_or_species, map_id = nil, level = nil)
      return unless defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:record_hunt_encounter)
      snap = last_snapshot
      map_id ||= snap && snap["map_id"]
      method = @current_zone_method || detect_zone_method(snap) || "unknown"
      start_session!(map_id || 0, method) if @current_zone_key != zone_key(map_id || 0, method)
      species_keys_for(pokemon_or_species).each do |species_key|
        needed = hard_needed?(pokemon_or_species)
        AutoplayBot::State.record_hunt_encounter(map_id || 0, method, species_key, level, needed)
        @current_session["encounters"] = @current_session["encounters"].to_i + 1 if @current_session
        if @current_session
          if needed
            @current_session["needed_seen"] = @current_session["needed_seen"].to_i + 1
            @current_session["since_yield"] = 0
          else
            @current_session["since_yield"] = @current_session["since_yield"].to_i + 1
          end
        end
      end
      refresh_storage_memory_if_due!("encounter")
      @last_action = "observed #{species_label(pokemon_or_species)}"
    rescue
      nil
    end

    def record_caught_pokemon(pokemon_or_species)
      return unless defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:record_hunt_catch)
      snap = last_snapshot
      map_id = snap && snap["map_id"]
      method = @current_zone_method || detect_zone_method(snap) || "unknown"
      species_keys_for(pokemon_or_species).each do |species_key|
        AutoplayBot::State.record_hunt_catch(species_key, map_id, method)
      end
      @current_session["catches"] = @current_session["catches"].to_i + 1 if @current_session
      @current_session["since_yield"] = 0 if @current_session
      refresh_storage_memory_if_due!("catch", true)
      @last_action = "caught #{species_label(pokemon_or_species)}"
      request_team_rotation!("dex catch")
    rescue
      nil
    end

    def record_capture_attempt(pokemon_or_species, ball = nil, battle = nil)
      return unless defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:record_catch_attempt)
      species_keys_for(pokemon_or_species).each do |species_key|
        AutoplayBot::State.record_catch_attempt(
          species_key,
          ball,
          "method" => @current_zone_method || "unknown",
          "turn" => (defined?(AutoplayBot::BattlePolicy) ? AutoplayBot::BattlePolicy.battle_turn(battle) : 0)
        )
      end
      @current_session["attempts"] = @current_session["attempts"].to_i + 1 if @current_session
      @last_action = "ball #{ball}"
    rescue
      nil
    end

    def current_zone_method
      @current_zone_method
    rescue
      nil
    end

    def debug_overlay_lines
      lines = []
      bits = ["Hunt #{@state || "assess"} #{debug_spinner}"]
      bits << "zone #{@current_zone_method}" if @current_zone_method
      bits << "#{@current_session["encounters"].to_i}/#{hunt_budget}" if @current_session
      lines << bits.join(" | ")
      lines << "Hunt #{short(@last_action, 54)}" if @last_action && !@last_action.to_s.empty?
      lines
    rescue
      []
    end

    def annotate_goal(goal, state, action)
      return nil unless goal
      @state = HUNT_STATES.include?(state.to_s) ? state.to_s : "assess"
      @last_action = action.to_s
      goal["hunt_state"] = @state
      goal["hunt_action"] = @last_action
      goal
    rescue
      goal
    end

    def debug_spinner
      frame = defined?(AutoplayBot::SceneObserver) && AutoplayBot::SceneObserver.respond_to?(:frame_count) ? AutoplayBot::SceneObserver.frame_count : 0
      ["-", "\\", "|", "/"][(frame.to_i / 12) % 4]
    rescue
      "-"
    end

    def safe_botcore_call(name, *args)
      return nil unless defined?(AutoplayBot::BotCore) && AutoplayBot::BotCore.respond_to?(name)
      AutoplayBot::BotCore.send(name, *args)
    rescue
      nil
    end

    def start_session!(map_id, method)
      finish_session!("zone_change") if @current_session
      @current_zone_key = zone_key(map_id, method)
      @current_zone_method = method.to_s
      @current_map_id = map_id.to_i
      @current_session = {
        "map_id" => map_id.to_i,
        "method" => method.to_s,
        "started_at" => Time.now.to_i,
        "encounters" => 0,
        "needed_seen" => 0,
        "catches" => 0,
        "attempts" => 0,
        "since_yield" => 0
      }
      @state = "select_zone"
      @last_action = "zone #{method}"
    rescue
      nil
    end

    def finish_session!(reason = "finished")
      return unless @current_session && defined?(AutoplayBot::State) &&
                    AutoplayBot::State.respond_to?(:record_hunt_session)
      return unless hunt_state_write_ready?
      AutoplayBot::State.record_hunt_session(@current_session.merge("reason" => reason.to_s, "ended_at" => Time.now.to_i))
      @current_session = nil
    rescue
      @current_session = nil
    end

    def record_zone(map_id, method)
      return unless defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:record_hunt_zone)
      return unless hunt_state_write_ready?
      AutoplayBot::State.record_hunt_zone(
        map_id,
        method,
        "nearby_heal" => nil,
        "nearby_shop" => nil,
        "standard_balls" => standard_ball_count,
        "heals" => heal_item_count
      )
    rescue
      nil
    end

    def hunt_zone_budget_expired?(snap, method)
      return false unless @current_session
      return false if @current_session["method"].to_s != method.to_s
      @current_session["since_yield"].to_i >= hunt_budget
    rescue
      false
    end

    def cooldown_zone!(snap, method, reason)
      return unless snap && defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:set_hunt_zone_cooldown)
      return unless hunt_state_write_ready?
      seconds = hunt_budget == 12 ? 180 : 420
      AutoplayBot::State.set_hunt_zone_cooldown(snap["map_id"], method, reason, seconds)
      finish_session!(reason)
      @last_action = "zone cooldown #{reason}"
    rescue
      nil
    end

    def zone_on_cooldown?(snap, method)
      return false unless snap && defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:hunt_zone_on_cooldown?)
      return false unless hunt_state_write_ready?
      AutoplayBot::State.hunt_zone_on_cooldown?(snap["map_id"], method)
    rescue
      false
    end

    def hunt_state_write_ready?
      return false if defined?(AutoplayBot::Runtime) &&
                      AutoplayBot::Runtime.respond_to?(:startup_diagnostics_active?) &&
                      AutoplayBot::Runtime.startup_diagnostics_active?
      return true unless defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:loaded?)
      AutoplayBot::State.loaded?
    rescue
      false
    end

    def hard_restock_needed?
      standard_ball_count <= 0
    rescue
      false
    end

    def wild_supplies_ready?
      standard_ball_count > 0
    rescue
      true
    end

    def standard_ball_count
      if defined?(AutoplayBot::ShopPolicy) && AutoplayBot::ShopPolicy.respond_to?(:standard_ball_count)
        return AutoplayBot::ShopPolicy.standard_ball_count
      end
      return 0 unless defined?(AutoplayBot::BattlePolicy)
      [:POKEBALL, :GREATBALL, :ULTRABALL, :FUSIONBALL, :PREMIERBALL, :QUICKBALL, :DUSKBALL, :TIMERBALL, :NETBALL].inject(0) do |sum, item|
        sum + AutoplayBot::BattlePolicy.bag_quantity(item).to_i
      end
    rescue
      0
    end

    def heal_item_count
      return 0 unless defined?(AutoplayBot::ShopPolicy)
      [:POTION, :SUPERPOTION, :HYPERPOTION, :MAXPOTION, :FULLRESTORE, :REVIVE].inject(0) do |sum, item|
        sum + AutoplayBot::ShopPolicy.quantity(item).to_i
      end
    rescue
      0
    end

    def hunt_budget
      configured = if defined?(AutoplayBot::Config) && AutoplayBot::Config.respond_to?(:hunt_encounter_budget)
                     AutoplayBot::Config.hunt_encounter_budget.to_i
                   else
                     24
                   end
      speed = hunt_speedup_multiplier
      return [[configured, 14].min, 8].max if speed >= 7
      return [[configured, 18].min, 10].max if speed >= 3
      configured
    rescue
      24
    end

    def hunt_speedup_multiplier
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.respond_to?(:game_speed_multiplier)
        return AutoplayBot::Runtime.game_speed_multiplier.to_i
      end
      defined?($GameSpeed) ? $GameSpeed.to_i : 1
    rescue
      1
    end

    def conservative_unlocks?
      !defined?(AutoplayBot::Config) || !AutoplayBot::Config.respond_to?(:manual_hunt_unlocks?) || !AutoplayBot::Config.manual_hunt_unlocks?
    rescue
      true
    end

    def manual_unlocks?
      defined?(AutoplayBot::Config) && AutoplayBot::Config.respond_to?(:manual_hunt_unlocks?) && AutoplayBot::Config.manual_hunt_unlocks?
    rescue
      false
    end

    def zone_key(map_id, method)
      "#{map_id.to_i}:#{method}"
    rescue
      "0:unknown"
    end

    def species_keys_for(pokemon_or_species)
      if defined?(AutoplayBot::DexTracker) && AutoplayBot::DexTracker.respond_to?(:base_species_for)
        keys = AutoplayBot::DexTracker.base_species_for(pokemon_or_species)
        return Array(keys).compact.map(&:to_s).uniq
      end
      [pokemon_or_species.to_s]
    rescue
      []
    end

    def hard_needed?(pokemon_or_species)
      defined?(AutoplayBot::DexTracker) &&
        AutoplayBot::DexTracker.respond_to?(:hard_needed_for?) &&
        AutoplayBot::DexTracker.hard_needed_for?(pokemon_or_species)
    rescue
      false
    end

    def species_label(pokemon_or_species)
      if pokemon_or_species.respond_to?(:name) && pokemon_or_species.name
        return pokemon_or_species.name.to_s
      end
      pokemon_or_species.to_s
    rescue
      "pokemon"
    end

    def request_team_rotation!(reason)
      return unless defined?(AutoplayBot::TeamBuilder) &&
                    AutoplayBot::TeamBuilder.respond_to?(:request_training_rotation!)
      AutoplayBot::TeamBuilder.request_training_rotation!(reason)
      if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:set_team_rotation_plan)
        AutoplayBot::State.set_team_rotation_plan("reason" => reason.to_s, "requested" => true)
      end
    rescue
      nil
    end

    def refresh_storage_memory_if_due!(reason = "hunt", force = false)
      return unless defined?(AutoplayBot::DexTracker) &&
                    AutoplayBot::DexTracker.respond_to?(:refresh_storage_counts!)
      frame = AutoplayBot::SceneObserver.frame_count rescue 0
      @last_storage_refresh_frame ||= -9999
      encounters = @current_session ? @current_session["encounters"].to_i : 0
      catches = @current_session ? @current_session["catches"].to_i : 0
      due_by_time = frame.to_i - @last_storage_refresh_frame.to_i >= storage_refresh_frames
      due_by_session = encounters > 0 && (encounters % 12).zero?
      due_by_catch = catches > 0 && (catches % 3).zero?
      return unless force || due_by_time || due_by_session || due_by_catch
      @last_storage_refresh_frame = frame.to_i
      AutoplayBot::DexTracker.refresh_storage_counts!(reason, due_by_time || due_by_session || due_by_catch)
    rescue
      nil
    end

    def storage_refresh_frames
      speed = defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.respond_to?(:game_speed_multiplier) ? AutoplayBot::Runtime.game_speed_multiplier : 1
      return 900 if speed.to_i >= 7
      return 1200 if speed.to_i >= 3
      1800
    rescue
      1800
    end

    def last_snapshot
      AutoplayBot::SceneObserver.last_snapshot if defined?(AutoplayBot::SceneObserver)
    rescue
      nil
    end

    def short(text, max)
      value = text.to_s.gsub(/\s+/, " ").strip
      value.length > max.to_i ? value[0, max.to_i - 3] + "..." : value
    rescue
      ""
    end
  end

  module WorldCoveragePlanner
    module_function

    WORLD_STATES = [
      "unlock_story",
      "travel_to_unlock",
      "clear_current_map",
      "hunt_zone",
      "trainer_clear",
      "item_clear",
      "npc_clear",
      "backtrack_zone",
      "restock_heal",
      "manual_blocked"
    ] unless const_defined?(:WORLD_STATES)

    def reset_runtime!(reason = nil)
      @state = "unlock_story"
      @last_action = reason ? "reset #{reason}" : "ready"
      @route_cache = {}
      @graph_cache = nil
      @last_observed_key = nil
      @last_gate_scan_frame = -9999
      @last_plan_frame = -9999
    rescue
      nil
    end

    def enabled?
      !defined?(AutoplayBot::Config) ||
        !AutoplayBot::Config.respond_to?(:world_coverage?) ||
        AutoplayBot::Config.world_coverage?
    rescue
      true
    end

    def choose_goal(snap, story = nil, map = nil)
      return nil unless enabled?
      return nil unless snap && snap["scene"].to_s == "map"
      map ||= safe_botcore_call(:current_map_data)
      observe_map!(snap, map)
      return wait_goal("waiting for map control") if snap["moving"] || snap["transfer"] || snap["cutscene"] || snap["raw_battle"]

      opportunistic = opportunistic_current_map_goal(snap, map, story)
      return opportunistic if opportunistic

      if story_unlock_goal?(story)
        return annotate_goal(story, "unlock_story", "story unlock priority")
      end

      clear_goal = clear_current_map_goal(snap, map)
      return clear_goal if clear_goal

      route_goal = route_to_unlock_goal(snap, map)
      return route_goal if route_goal

      @state = "hunt_zone"
      @last_action = "no world unlock; hunt planner can run"
      nil
    rescue => e
      @state = "manual_blocked"
      @last_action = "world error #{e.class}"
      AutoplayBot.log("world coverage planner failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      nil
    end

    def opportunistic_current_map_goal(snap, map, story)
      return nil unless map && snap && snap["scene"].to_s == "map"
      field = safe_botcore_call(:field_obstacle_goal, snap, story)
      return annotate_goal(field, "item_clear", "nearby field obstacle") if field

      collect = safe_botcore_call(:nearby_collect_goal, map, snap, story)
      return annotate_goal(collect, "item_clear", "nearby item/resource") if collect

      trainer = safe_botcore_call(:nearby_trainer_goal, map, snap, story ? 8 : 14)
      return annotate_goal(trainer, "trainer_clear", "nearby trainer") if trainer

      npc = safe_botcore_call(:nearby_npc_goal, map, snap, story)
      return annotate_goal(npc, "npc_clear", "nearby NPC") if npc

      live = safe_botcore_call(:live_nearby_goal, snap, story ? 6 : 10)
      return annotate_goal(live, "clear_current_map", "live nearby target") if live

      nil
    rescue
      nil
    end

    def wait_goal(action)
      @last_action = action.to_s
      nil
    rescue
      nil
    end

    def story_unlock_goal?(story)
      return false unless story
      return false if defined?(AutoplayBot::Config) &&
                      AutoplayBot::Config.respond_to?(:story_unlock_priority?) &&
                      !AutoplayBot::Config.story_unlock_priority?
      true
    rescue
      false
    end

    def observe_map!(snap, map)
      return unless snap && defined?(AutoplayBot::State)
      frame = snap["frame"].to_i
      key = "#{snap["map_id"]}:#{frame / observe_interval_frames}"
      return if @last_observed_key == key
      @last_observed_key = key
      seed_scanner_maps!
      counts = atlas_counts(map)
      targets = atlas_targets(map)
      transfers = Array(map && map["transfers"]).select { |record| record.is_a?(Hash) }
      status = atlas_status_for(map)
      methods = encounter_methods_for(snap, map)
      AutoplayBot::State.record_world_map(
        snap["map_id"],
        "name" => map_name(map, snap["map_id"]),
        "status" => status,
        "counts" => counts,
        "targets" => targets,
        "transfers" => transfers,
        "encounter_methods" => methods
      ) if AutoplayBot::State.respond_to?(:record_world_map)
      record_field_gates!(snap) if frame - @last_gate_scan_frame.to_i >= gate_scan_interval_frames
    rescue
      nil
    end

    def observe_interval_frames
      speed = speed_multiplier
      return 240 if speed >= 7
      return 180 if speed >= 3
      120
    rescue
      180
    end

    def gate_scan_interval_frames
      speed = speed_multiplier
      return 600 if speed >= 7
      return 420 if speed >= 3
      300
    rescue
      420
    end

    def atlas_counts(map)
      {
        "transfers" => Array(map && map["transfers"]).length,
        "trainers" => Array(map && map["trainers"]).length,
        "items" => Array(map && map["items"]).length,
        "resources" => Array(map && map["field_resources"]).length,
        "npcs" => Array(map && map["npcs"]).length,
        "buildings" => building_transfer_count(map),
        "zones" => Array(map && map["wild_statics"]).length + Array(map && map["gifts"]).length
      }
    rescue
      {}
    end

    def seed_scanner_maps!
      return unless defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:record_world_map)
      maps = scanner_maps
      return if maps.empty?
      keys = maps.keys.map(&:to_s).sort_by { |key| key.to_i }
      if @scanner_seed_token != scanner_cache_token
        @scanner_seed_token = scanner_cache_token
        @scanner_seed_index = 0
      end
      @scanner_seed_index ||= 0
      budget = speed_multiplier >= 7 ? 2 : 4
      budget.times do
        break if keys.empty?
        key = keys[@scanner_seed_index.to_i % keys.length]
        @scanner_seed_index = @scanner_seed_index.to_i + 1
        map = maps[key]
        next unless map.is_a?(Hash)
        entry = AutoplayBot::State.world_map_entry(key.to_i) if AutoplayBot::State.respond_to?(:world_map_entry)
        next if entry && entry["seen_at"] && entry["status"].to_s != "unseen"
        next if entry && entry["status"].to_s == "unseen" && entry["counts"].is_a?(Hash)
        AutoplayBot::State.record_world_map(
          key.to_i,
          "name" => map["name"],
          "status" => "unseen",
          "counts" => atlas_counts(map)
        )
      end
    rescue
      nil
    end

    def atlas_targets(map)
      targets = []
      [["trainer", "trainers"], ["item", "items"], ["resource", "field_resources"], ["npc", "npcs"], ["static", "wild_statics"], ["gift", "gifts"]].each do |kind, key|
        Array(map && map[key]).each do |record|
          next unless record.is_a?(Hash)
          targets << {
            "kind" => kind,
            "key" => record["key"] || record["event_id"],
            "map_id" => record["map_id"] || (map && map["id"]),
            "x" => record["x"],
            "y" => record["y"],
            "label" => record["event_name"] || record["name"]
          }
        end
      end
      targets
    rescue
      []
    end

    def atlas_status_for(map)
      return "seen" unless map
      pending = pending_target_count(map)
      return "cleared" if pending <= 0 && Array(map["transfers"]).empty?
      pending <= 0 ? "partially_cleared" : "seen"
    rescue
      "seen"
    end

    def pending_target_count(map)
      count = 0
      [["trainer", "trainers"], ["item", "items"], ["resource", "field_resources"], ["npc", "npcs"], ["static", "wild_statics"], ["gift", "gifts"], ["transfer", "transfers"]].each do |kind, key|
        Array(map && map[key]).each do |record|
          next unless record.is_a?(Hash)
          next if safe_botcore_call(:target_done_or_failed?, record, kind)
          next if safe_botcore_call(:attempts_exhausted?, record, kind)
          count += 1
        end
      end
      count
    rescue
      0
    end

    def encounter_methods_for(snap, map)
      methods = []
      methods << "grass" if safe_botcore_call(:nearby_grass_targets, snap, 10).to_a.any?
      methods << "cave_floor" if safe_botcore_call(:cave_encounter_map?)
      methods << "static" unless Array(map && map["wild_statics"]).empty?
      methods << "gift" unless Array(map && map["gifts"]).empty?
      methods.uniq
    rescue
      []
    end

    def record_field_gates!(snap)
      @last_gate_scan_frame = snap["frame"].to_i
      records = safe_botcore_call(:live_field_obstacle_records, snap, 12)
      Array(records).each do |record|
        kind = safe_botcore_call(:field_move_target_kind, record["event_name"]) || "field_move"
        next if safe_botcore_call(:field_move_available?, kind)
        AutoplayBot::State.record_ability_gate(record, kind, "missing_field_move") if AutoplayBot::State.respond_to?(:record_ability_gate)
      end
    rescue
      nil
    end

    def clear_current_map_goal(snap, map)
      return nil unless map
      field = safe_botcore_call(:field_obstacle_goal, snap, nil)
      return annotate_goal(field, "item_clear", "field obstacle") if field

      collect = safe_botcore_call(:nearby_collect_goal, map, snap, nil)
      return annotate_goal(collect, "item_clear", "nearby item/resource") if collect

      trainer = safe_botcore_call(:trainer_steal_goal, map, snap, nil)
      return annotate_goal(trainer, "trainer_clear", "nearby trainer") if trainer

      npc = safe_botcore_call(:nearby_npc_goal, map, snap, nil)
      return annotate_goal(npc, "npc_clear", "nearby NPC") if npc

      building = safe_botcore_call(:nearby_building_goal, map, snap, nil)
      return annotate_goal(building, "clear_current_map", "nearby building") if building
      nil
    rescue
      nil
    end

    def route_to_unlock_goal(snap, map)
      transfer = current_map_transfer_goal(snap, map)
      return transfer if transfer
      return nil if defined?(AutoplayBot::Config) &&
                    AutoplayBot::Config.respond_to?(:world_backtrack_policy) &&
                    AutoplayBot::Config.world_backtrack_policy == "off"
      cross = cross_map_route_goal(snap, map)
      return cross if cross
      nil
    rescue
      nil
    end

    def current_map_transfer_goal(snap, map)
      transfers = Array(map && map["transfers"]).select do |record|
        next false unless usable_transfer?(record)
        next false if safe_botcore_call(:target_done_or_failed?, record, "transfer")
        next false if safe_botcore_call(:attempts_exhausted?, record, "transfer")
        true
      end
      record = transfers.min_by { |tr| safe_botcore_call(:manhattan, tr, snap).to_i }
      return nil unless record
      label = "Explore #{map_name_for_id(record["destination_map_id"]) || record["event_name"] || "transfer"}"
      goal = safe_botcore_call(:progress_transfer, "world_transfer_#{record["key"] || record.object_id}", label, record.merge("map_id" => snap["map_id"]), "travel_to_unlock")
      annotate_goal(goal, "travel_to_unlock", "unvisited transfer")
    rescue
      nil
    end

    def usable_transfer?(record)
      return false unless record.is_a?(Hash) && record["x"] && record["y"]
      dest = record["destination_map_id"] || record["to_map"] || record["map"]
      return false unless dest && dest.to_i > 0
      return false if defined?(AutoplayBot::State) &&
                      AutoplayBot::State.respond_to?(:transfer_visited?) &&
                      record["key"] && AutoplayBot::State.transfer_visited?(record["key"])
      true
    rescue
      false
    end

    def cross_map_route_goal(snap, current_map)
      target_map_id = best_backtrack_map_id(snap["map_id"])
      return nil unless target_map_id
      transfer = first_transfer_toward(snap["map_id"], target_map_id, current_map)
      return nil unless transfer
      label = "Route to #{map_name_for_id(target_map_id)}"
      goal = safe_botcore_call(:progress_transfer, "world_route_#{snap["map_id"]}_#{target_map_id}", label, transfer.merge("map_id" => snap["map_id"]), "backtrack_zone")
      annotate_goal(goal, "backtrack_zone", "atlas route to #{target_map_id}")
    rescue
      nil
    end

    def best_backtrack_map_id(current_map_id)
      return nil unless defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:world_atlas)
      maps = (AutoplayBot::State.world_atlas["maps"] || {})
      candidates = maps.values.select do |entry|
        next false unless entry.is_a?(Hash)
        id = entry["map_id"].to_i
        next false if id <= 0 || id == current_map_id.to_i
        next false if entry["status"].to_s == "cleared"
        entry_pending_count(entry) > 0
      end
      candidates = candidates.first(32)
      best = candidates.max_by do |entry|
        score = entry_pending_count(entry)
        score += 10 if entry["status"].to_s == "return_later"
        score += 5 if entry["status"].to_s == "partially_cleared"
        score
      end
      best && best["map_id"].to_i
    rescue
      nil
    end

    def entry_pending_count(entry)
      targets = entry["targets"].is_a?(Hash) ? entry["targets"] : {}
      transfers = entry["transfers"].is_a?(Hash) ? entry["transfers"] : {}
      (targets.values + transfers.values).count do |record|
        status = record.is_a?(Hash) ? record["status"].to_s : ""
        status.empty? || status == "seen" || status == "attempted" || status == "return_later"
      end
    rescue
      0
    end

    def first_transfer_toward(from_map_id, to_map_id, current_map)
      from_map_id = from_map_id.to_i
      to_map_id = to_map_id.to_i
      return nil if from_map_id <= 0 || to_map_id <= 0 || from_map_id == to_map_id
      cache_key = "#{from_map_id}:#{to_map_id}:#{scanner_cache_token}"
      cached = @route_cache && @route_cache[cache_key]
      return cached["transfer"] if cached && cached["until"].to_i > frame_count

      edges = transfer_graph(current_map)
      queue = [from_map_id]
      seen = { from_map_id => true }
      parent = {}
      until queue.empty? || seen.length > 240
        map_id = queue.shift
        break if map_id == to_map_id
        Array(edges[map_id]).each do |record|
          dest = transfer_dest(record)
          next if dest <= 0 || seen[dest]
          seen[dest] = true
          parent[dest] = [map_id, record]
          queue << dest
        end
      end
      return nil unless seen[to_map_id]

      step = to_map_id
      route_keys = []
      first_record = nil
      while parent[step]
        prev, record = parent[step]
        route_keys.unshift(record["key"] || "#{prev}:#{transfer_dest(record)}")
        first_record = record if prev.to_i == from_map_id
        step = prev
      end
      AutoplayBot::State.record_world_route(from_map_id, to_map_id, route_keys, "atlas_route") if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:record_world_route)
      @route_cache ||= {}
      @route_cache[cache_key] = { "transfer" => first_record, "until" => frame_count + 900 } if first_record
      first_record
    rescue
      nil
    end

    def transfer_graph(current_map = nil)
      token = scanner_cache_token
      return @graph_cache["edges"] if @graph_cache && @graph_cache["token"] == token
      edges = {}
      scanner_maps.each do |map_id, map|
        id = map_id.to_i
        Array(map && map["transfers"]).each do |record|
          next unless record.is_a?(Hash)
          dest = transfer_dest(record)
          next if dest <= 0
          copy = record.merge("map_id" => id)
          edges[id] ||= []
          edges[id] << copy
        end
      end
      if current_map && current_map["id"]
        id = current_map["id"].to_i
        edges[id] ||= []
        Array(current_map["transfers"]).each do |record|
          next unless record.is_a?(Hash)
          dest = transfer_dest(record)
          next if dest <= 0
          edges[id] << record.merge("map_id" => id)
        end
      end
      @graph_cache = { "token" => token, "edges" => edges }
      edges
    rescue
      {}
    end

    def scanner_maps
      return {} unless defined?(AutoplayBot::WorldScanner)
      index = AutoplayBot::WorldScanner.instance_variable_get(:@index) rescue nil
      maps = index && index["maps"].is_a?(Hash) ? index["maps"] : {}
      maps
    rescue
      {}
    end

    def scanner_cache_token
      index = defined?(AutoplayBot::WorldScanner) ? (AutoplayBot::WorldScanner.instance_variable_get(:@index) rescue nil) : nil
      "#{index && index["built_at"]}:#{scanner_maps.length}"
    rescue
      "live"
    end

    def transfer_dest(record)
      (record["destination_map_id"] || record["to_map"] || record["map"]).to_i
    rescue
      0
    end

    def note_target_done(record, kind, reason = nil)
      return unless defined?(AutoplayBot::State)
      if kind.to_s == "transfer"
        AutoplayBot::State.mark_world_transfer_status(record, "completed", reason) if AutoplayBot::State.respond_to?(:mark_world_transfer_status)
      else
        AutoplayBot::State.mark_world_target_status(record, "completed", kind, reason) if AutoplayBot::State.respond_to?(:mark_world_target_status)
      end
    rescue
      nil
    end

    def note_target_failed(record, kind, reason = nil)
      return unless defined?(AutoplayBot::State)
      status = reason.to_s =~ /missing_field_move/i ? "blocked" : "return_later"
      if kind.to_s == "transfer"
        AutoplayBot::State.mark_world_transfer_status(record, status, reason) if AutoplayBot::State.respond_to?(:mark_world_transfer_status)
      else
        AutoplayBot::State.mark_world_target_status(record, status, kind, reason) if AutoplayBot::State.respond_to?(:mark_world_target_status)
      end
    rescue
      nil
    end

    def annotate_goal(goal, state, action)
      return nil unless goal
      @state = WORLD_STATES.include?(state.to_s) ? state.to_s : "unlock_story"
      @last_action = action.to_s
      goal["world_state"] = @state
      goal["world_action"] = @last_action
      goal["score"] = [goal["score"].to_i, world_score(@state)].max
      record_world_plan(goal)
      goal
    rescue
      goal
    end

    def world_score(state)
      case state.to_s
      when "unlock_story" then 260
      when "travel_to_unlock" then 215
      when "restock_heal" then 205
      when "trainer_clear" then 175
      when "item_clear" then 165
      when "npc_clear" then 145
      when "backtrack_zone" then 120
      else 100
      end
    rescue
      100
    end

    def record_world_plan(goal)
      return unless defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:record_world_plan)
      record = goal["record"].is_a?(Hash) ? goal["record"] : {}
      AutoplayBot::State.record_world_plan(
        "state" => @state,
        "action" => @last_action,
        "goal" => goal["label"],
        "kind" => goal["kind"],
        "target_kind" => goal["target_kind"],
        "map_id" => record["map_id"] || goal["map_id"],
        "x" => record["x"] || goal["x"],
        "y" => record["y"] || goal["y"]
      )
    rescue
      nil
    end

    def debug_overlay_lines
      lines = []
      lines << "World #{@state || "unlock"} #{debug_spinner} #{short(@last_action, 38)}"
      if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:last_world_plan)
        plan = AutoplayBot::State.last_world_plan
        lines << "Atlas #{short(plan && plan["goal"], 42)}" if plan && plan["goal"]
      end
      lines.compact
    rescue
      []
    end

    def safe_botcore_call(name, *args)
      return nil unless defined?(AutoplayBot::BotCore) && AutoplayBot::BotCore.respond_to?(name)
      AutoplayBot::BotCore.send(name, *args)
    rescue
      nil
    end

    def map_name(map, map_id)
      value = map && map["name"] ? map["name"].to_s : ""
      value.empty? ? map_name_for_id(map_id) : value
    rescue
      "Map #{map_id}"
    end

    def map_name_for_id(map_id)
      value = safe_botcore_call(:map_name_for_id, map_id).to_s
      value = safe_botcore_call(:current_map_name_for_transfer, map_id).to_s if value.empty?
      value.empty? ? "Map #{map_id}" : value
    rescue
      "Map #{map_id}"
    end

    def building_transfer_count(map)
      Array(map && map["transfers"]).count do |record|
        text = [record["event_name"], record["name"], record["args"], record["script"], map_name_for_id(transfer_dest(record))].compact.join(" ")
        text =~ /house|mart|shop|center|gym|gate|lab|building|room/i
      end
    rescue
      0
    end

    def speed_multiplier
      if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.respond_to?(:game_speed_multiplier)
        return AutoplayBot::Runtime.game_speed_multiplier.to_i
      end
      defined?($GameSpeed) ? $GameSpeed.to_i : 1
    rescue
      1
    end

    def frame_count
      defined?(AutoplayBot::SceneObserver) && AutoplayBot::SceneObserver.respond_to?(:frame_count) ? AutoplayBot::SceneObserver.frame_count.to_i : 0
    rescue
      0
    end

    def debug_spinner
      ["-", "\\", "|", "/"][(frame_count / 12) % 4]
    rescue
      "-"
    end

    def short(text, max)
      value = text.to_s.gsub(/\s+/, " ").strip
      value.length > max.to_i ? value[0, max.to_i - 3] + "..." : value
    rescue
      ""
    end
  end

  module BotCore
    module_function

    def reset_runtime!(reason = nil)
      @active_goal = nil
      @active_goal_key = nil
      @last_scene = nil
      @last_map_id = nil
      @settle_until_frame = nil
      @last_goal_choice_frame = nil
      @menu_idle_frame = nil
      @menu_idle_started_at = nil
      @last_status = nil
      @rail_path_cache = nil
      @route_motion_guard = nil
      @route_axis_history = nil
      @adapter_progress_state = nil
      @adapter_stall_blocks = nil
      @static_coast_watch = nil
      @last_pause_menu_goal_frame = nil
      @cold_start_until_frame = SceneObserver.frame_count + cold_start_frames
      @cold_start_until_at = botcore_now + cold_start_seconds
      @cold_start_position = current_position_key
      Navigator.reset!(reason || "runtime reset") if defined?(AutoplayBot::Navigator)
      WorldCoveragePlanner.reset_runtime!(reason || "runtime reset") if defined?(AutoplayBot::WorldCoveragePlanner)
      DexHuntPlanner.reset_runtime!(reason || "runtime reset") if defined?(AutoplayBot::DexHuntPlanner)
    rescue
      nil
    end

    def context_interrupt!(reason = "context")
      @active_goal = nil
      @active_goal_key = nil
      @last_goal_choice_frame = nil
      @rail_path_cache = nil
      @route_motion_guard = nil
      @route_axis_history = nil
      @adapter_progress_state = nil
      @static_coast_watch = nil
      @rail_action = "#{reason}: waiting"
      clear_static_map_coast_watch! if respond_to?(:clear_static_map_coast_watch!)
      reset_adapter_motion_state!(nil, reason) if respond_to?(:reset_adapter_motion_state!)
    rescue
      nil
    end

    def note_static_coast_block!(dir, reason = "static coast")
      snap = (SceneObserver.snapshot rescue nil) || SceneObserver.last_snapshot
      return false unless snap && snap["scene"].to_s == "map"
      if @active_goal && @active_goal["kind"].to_s == "adapter"
        block_adapter_goal!(adapter_progress_key(@active_goal, snap), snap, "static #{reason}")
        reset_adapter_motion_state!(snap, reason)
        @active_goal = nil
        @active_goal_key = nil
        @last_goal_choice_frame = nil
      end
      clear_static_map_coast_watch! if respond_to?(:clear_static_map_coast_watch!)
      @rail_path_cache = nil
      @route_motion_guard = nil
      @route_axis_history = nil
      @rail_action = "blocked #{dir}: #{reason}"
      true
    rescue
      false
    end

    def tick(coast = false)
      snap = SceneObserver.snapshot
      unless snap["scene"].to_s == "menu"
        @menu_idle_frame = nil
        @menu_idle_started_at = nil
      end
      scene_transition_tick(snap)
      Navigator.observe_scene(snap)
      update_state_position(snap)

      return stale_raw_battle_map_tick(snap) if stale_raw_battle_map?(snap)

      case snap["scene"].to_s
      when "message"
        return message_tick(snap)
      when "battle_intro", "battle_command", "battle_message"
        return battle_tick(snap)
      when "menu"
        return menu_tick(snap)
      when "transfer", "cutscene"
        return wait_scene_tick(snap)
      end

      map_coast = snap["scene"].to_s == "map" && (coast || snap["moving"])
      nav_coast_stalled = defined?(AutoplayBot::Navigator) &&
                           AutoplayBot::Navigator.respond_to?(:coast_stalled?) &&
                           AutoplayBot::Navigator.coast_stalled?(snap)
      nav_coast_looping = defined?(AutoplayBot::Navigator) &&
                           AutoplayBot::Navigator.respond_to?(:coast_looping?) &&
                           AutoplayBot::Navigator.coast_looping?(snap)

      if map_coast && (nav_coast_stalled || nav_coast_looping ||
                       static_map_coast_stalled?(snap, coast) || stale_map_coast?(snap, coast))
        AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
        reason = if nav_coast_looping
                   "movement loop"
                 elsif nav_coast_stalled
                   "no tile progress"
                 else
                   "stale coast"
                 end
        if @active_goal && @active_goal["kind"].to_s == "adapter"
          block_adapter_goal!(adapter_progress_key(@active_goal, snap), snap, "coast #{reason}")
        elsif @active_goal
          record = @active_goal["record"].is_a?(Hash) ? @active_goal["record"] : @active_goal
          kind = @active_goal["target_kind"] || @active_goal["kind"]
          mark_local_target_failed(record, kind, "coast #{reason}")
        end
        Navigator.note_coast_stall!(snap, "coast_#{reason.gsub(/\s+/, '_')}") if defined?(AutoplayBot::Navigator) &&
                                                                                AutoplayBot::Navigator.respond_to?(:note_coast_stall!)
        @active_goal = nil
        @active_goal_key = nil
        @rail_action = "replan: #{reason}"
        reset_adapter_motion_state!(snap, reason)
        Navigator.reset!(reason) if defined?(AutoplayBot::Navigator)
        clear_static_map_coast_watch!
        map_coast = false
      end

      if map_coast && urgent_pause_menu_stop_needed?(snap)
        AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
        Navigator.reset!("pause menu stop") if defined?(AutoplayBot::Navigator)
        set_mode("recovery")
        status_once("menu: stop for heal/supplies")
        return true
      end

      if map_coast
        Navigator.coast_tick(snap)
        set_mode("navigation")
        status_once(snap["moving"] ? "moving" : "coast: checking step")
        return true
      end
      clear_static_map_coast_watch!

      return wait_settle_tick(snap) if settling?(snap)

      urgent_menu = urgent_pause_menu_goal(snap)
      if urgent_menu
        @active_goal = urgent_menu
        @active_goal_key = Navigator.goal_key(urgent_menu) if defined?(AutoplayBot::Navigator)
        @last_goal_choice_frame = snap["frame"]
        return adapter_tick(urgent_menu, snap)
      end

      goal = active_or_new_goal(snap)
      scan_current_map_if_needed(snap, goal)
      if goal && goal["kind"].to_s == "adapter"
        handled = adapter_tick(goal, snap)
        if handled
          return true unless adapter_stalled_after_tick?(goal, snap)

          AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
          @active_goal = nil
          @active_goal_key = nil
          @rail_action = "recover: rail stale"
          reset_adapter_motion_state!(snap, "adapter stagnant")
          Navigator.reset!("adapter stagnant") if defined?(AutoplayBot::Navigator)
          return fallback_explore_tick(snap, "rail stale", true)
        end

        @active_goal = nil
        @active_goal_key = nil
        return fallback_explore_tick(snap, "adapter no action", true)
      end
      @rail_action = nil
      unless goal
        return fallback_explore_tick(snap, "explore no goal", true)
      end

      record_goal(goal)
      set_mode(mode_for_goal(goal))
      handled = Navigator.follow(goal, snap)
      return true if handled

      @active_goal = nil
      @active_goal_key = nil
      fallback_explore_tick(snap, "nav no action", true)
    rescue => e
      if AutoplayBot.respond_to?(:log)
        trace = e.backtrace && e.backtrace.first
        AutoplayBot.log("bot core failed: #{e.class}: #{e.message} #{trace}")
      end
      AutoplayBot.status("core recover #{e.class}") if AutoplayBot.respond_to?(:status)
      Navigator.reset!("core error") if defined?(AutoplayBot::Navigator)
      false
    end

    def adapter_stalled_after_tick?(goal, snap)
      return false unless goal && snap && snap["scene"].to_s == "map"
      return false if snap["moving"]
      key = adapter_progress_key(goal, snap)
      pos = [snap["map_id"].to_i, snap["x"].to_i, snap["y"].to_i]
      frame = snap["frame"].to_i
      @adapter_progress_state ||= {}
      state = @adapter_progress_state
      if state["key"] != key || state["pos"] != pos
        state["key"] = key
        state["pos"] = pos
        state["frame"] = frame
        state["action"] = @rail_action.to_s
        return false
      end
      elapsed = frame - state["frame"].to_i
      return false if elapsed < adapter_stall_frame_limit(goal)
      block_adapter_goal!(key, snap, "stalled #{elapsed}f")
      if AutoplayBot.respond_to?(:log)
        AutoplayBot.log("adapter stalled #{key} at map #{snap["map_id"]} x#{snap["x"]} y#{snap["y"]} action=#{@rail_action}")
      end
      state["frame"] = frame
      true
    rescue
      false
    end

    def adapter_progress_key(goal, snap = nil)
      if defined?(AutoplayBot::Navigator) && AutoplayBot::Navigator.respond_to?(:goal_key)
        return AutoplayBot::Navigator.goal_key(goal).to_s
      end
      record = goal["record"].is_a?(Hash) ? goal["record"] : goal
      [
        goal["adapter"],
        record["map_id"] || (snap && snap["map_id"]),
        record["key"],
        record["x"],
        record["y"],
        goal["label"]
      ].compact.join(":")
    rescue
      goal.to_s
    end

    def adapter_stall_frame_limit(goal)
      adapter = goal["adapter"].to_s
      if adapter == "wild_grass_patrol" || adapter == "unknown_map_wander"
        speed = botcore_speed_multiplier
        return 16 if speed >= 7
        return 24 if speed >= 3
        return 36
      end
      return 60 if adapter == "auto_transfer_rail" || adapter == "auto_edge_rail"
      return 240 if adapter == "forest_cross_rail"
      72
    rescue
      60
    end

    def block_adapter_goal!(key, snap, reason = "stalled")
      @adapter_stall_blocks ||= {}
      frame = snap && snap["frame"] ? snap["frame"].to_i : SceneObserver.frame_count.to_i
      entry = @adapter_stall_blocks[key.to_s] ||= { "count" => 0 }
      entry["count"] = entry["count"].to_i + 1
      entry["reason"] = reason.to_s
      if reason.to_s =~ /coast|loop|stalled|stagnant|repeat|no tile/i
        entry["until"] = frame + [300 + (entry["count"].to_i * 120), 900].min
      else
        entry["until"] = frame + [90 + (entry["count"].to_i * 30), 240].min
      end
    rescue
      nil
    end

    def adapter_goal_blocked?(goal, snap = nil)
      return false unless goal
      @adapter_stall_blocks ||= {}
      frame = snap && snap["frame"] ? snap["frame"].to_i : SceneObserver.frame_count.to_i
      @adapter_stall_blocks.delete_if { |_key, entry| entry["until"].to_i <= frame }
      key = adapter_progress_key(goal, snap)
      entry = @adapter_stall_blocks[key.to_s]
      entry && entry["until"].to_i > frame
    rescue
      false
    end

    def stale_raw_battle_map?(snap)
      snap &&
        snap["scene"].to_s == "map" &&
        snap["raw_battle"] == true &&
        snap["stale_raw_battle"] == true
    rescue
      false
    end

    def stale_raw_battle_map_tick(snap)
      set_mode("recovery")
      key = [snap["map_id"], snap["x"], snap["y"]]
      if @stale_raw_map_tick_key != key
        @stale_raw_map_tick_key = key
        AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
        reset_adapter_motion_state!(snap, "stale raw map")
        Navigator.reset!("stale raw map") if defined?(AutoplayBot::Navigator)
      end
      recovered = if defined?(AutoplayBot::Runtime) &&
                     AutoplayBot::Runtime.respond_to?(:recover_stale_raw_map_battle!)
                    AutoplayBot::Runtime.recover_stale_raw_map_battle!(snap)
                  else
                    false
                  end
      if recovered
        @stale_raw_map_tick_key = nil
        @active_goal = nil
        @active_goal_key = nil
        @rail_action = "battle flag: cleared"
        AutoplayBot.status("battle: map resumed") if AutoplayBot.respond_to?(:status)
      else
        detail = if defined?(AutoplayBot::Runtime) &&
                    AutoplayBot::Runtime.respond_to?(:stale_raw_map_recovery_status)
                   AutoplayBot::Runtime.stale_raw_map_recovery_status
                 else
                   "runtime recovery"
                 end
        @rail_action = "battle flag: #{detail}"
        AutoplayBot.status("battle: #{detail}") if AutoplayBot.respond_to?(:status)
      end
      true
    rescue => e
      AutoplayBot.log("stale raw map tick failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      true
    end

    def scene_transition_tick(snap)
      if @last_scene && @last_scene.to_s =~ /^battle/ && snap["scene"].to_s == "map"
        @settle_until_frame = snap["frame"].to_i + 36
        reset_adapter_motion_state!(snap, "battle ended")
        Navigator.reset!("battle ended")
      elsif @last_map_id && snap["map_id"] && @last_map_id.to_i != snap["map_id"].to_i
        @settle_until_frame = snap["frame"].to_i + 24
        @active_goal = nil
        @active_goal_key = nil
        reset_adapter_motion_state!(snap, "map changed")
        Navigator.reset!("map changed")
      end
      @last_scene = snap["scene"]
      @last_map_id = snap["map_id"] if snap["map_id"]
    rescue
      nil
    end

    def reset_adapter_motion_state!(snap, _reason = nil)
      @grass_path_cache = nil
      key = snap && snap["map_id"] ? snap["map_id"].to_i : nil
      return unless key
      [@grass_patrol_state, @fallback_explore_state].each do |store|
        next unless store && store[key].is_a?(Hash)
        store[key]["dir"] = nil
        store[key]["steps"] = 0
        store[key]["last_pos"] = [snap["map_id"], snap["x"], snap["y"]]
        store[key]["last_progress_frame"] = snap["frame"].to_i
      end
    rescue
      nil
    end

    def update_state_position(snap)
      return unless state_write_allowed?
      AutoplayBot::State.update_last_position(snap["map_id"], snap["x"], snap["y"]) if snap["map_id"] && AutoplayBot::State.respond_to?(:update_last_position)
      AutoplayBot::State.mark_map_seen(snap["map_id"]) if snap["map_id"] && AutoplayBot::State.respond_to?(:mark_map_seen)
    rescue
      nil
    end

    def settling?(snap)
      @settle_until_frame && snap["frame"].to_i < @settle_until_frame.to_i
    rescue
      false
    end

    def stale_map_coast?(snap, coast)
      return false unless snap && snap["scene"].to_s == "map"
      return false unless coast || snap["moving"]
      stable = snap["map_stable_frames"].to_i
      return true if coast && !snap["moving"] && stable >= static_coast_frame_limit
      return true if coast && stable >= 42
      return true if snap["moving"] && stable >= 72
      false
    rescue
      false
    end

    def static_map_coast_stalled?(snap, coast)
      return false unless snap && snap["scene"].to_s == "map"
      unless coast && !snap["moving"]
        clear_static_map_coast_watch!
        return false
      end
      return false unless defined?(AutoplayBot::InputQueue) &&
                          AutoplayBot::InputQueue.respond_to?(:dir_frames_remaining) &&
                          AutoplayBot::InputQueue.respond_to?(:dir4)
      frames_left = AutoplayBot::InputQueue.dir_frames_remaining.to_i
      dir = AutoplayBot::InputQueue.dir4.to_i
      unless frames_left > 0 && [2, 4, 6, 8].include?(dir)
        clear_static_map_coast_watch!
        return false
      end
      frame = snap["frame"].to_i
      now = botcore_now
      key = [snap["map_id"].to_i, snap["x"].to_i, snap["y"].to_i, dir]
      if @static_coast_watch && @static_coast_watch["key"] == key
        @static_coast_watch["ticks"] = @static_coast_watch["ticks"].to_i + 1
        elapsed_frames = frame - @static_coast_watch["frame"].to_i
        elapsed_time = now - @static_coast_watch["time"].to_f
        stalled = @static_coast_watch["ticks"].to_i >= static_map_coast_tick_limit ||
                  elapsed_frames >= static_map_coast_frame_limit ||
                  elapsed_time >= static_map_coast_seconds_limit
        if stalled
          if AutoplayBot.respond_to?(:log)
            AutoplayBot.log("static coast stalled map=#{snap["map_id"]} x=#{snap["x"]} y=#{snap["y"]} dir=#{dir} frames_left=#{frames_left} ticks=#{@static_coast_watch["ticks"]} elapsed=#{elapsed_frames}")
          end
          return true
        end
      else
        @static_coast_watch = {
          "key" => key,
          "frame" => frame,
          "time" => now,
          "ticks" => 1
        }
      end
      false
    rescue
      false
    end

    def clear_static_map_coast_watch!
      @static_coast_watch = nil
    rescue
      nil
    end

    def static_map_coast_tick_limit
      speed = botcore_speed_multiplier
      return 2 if speed >= 7
      return 3 if speed >= 3
      5
    rescue
      3
    end

    def static_map_coast_frame_limit
      speed = botcore_speed_multiplier
      return 3 if speed >= 7
      return 5 if speed >= 3
      8
    rescue
      5
    end

    def static_map_coast_seconds_limit
      speed = botcore_speed_multiplier
      return 0.04 if speed >= 7
      return 0.08 if speed >= 3
      0.12
    rescue
      0.08
    end

    def botcore_speed_multiplier
      if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.respond_to?(:game_speed_multiplier)
        return AutoplayBot::Runtime.game_speed_multiplier.to_i
      end
      1
    rescue
      1
    end

    def static_coast_frame_limit
      speed = botcore_speed_multiplier
      return 4 if speed >= 7
      return 6 if speed >= 3
      10
    rescue
      7
    end

    def movement_stall_frame_limit(base)
      speed = botcore_speed_multiplier
      base = base.to_i
      return [[base / 3, 6].max, base].min if speed >= 7
      return [[base / 2, 8].max, base].min if speed >= 3
      base
    rescue
      base.to_i
    end

    def wait_settle_tick(_snap)
      set_mode("navigation")
      status_once("settling after scene")
      true
    rescue
      true
    end

    def message_tick(_snap)
      set_mode("story")
      status_once("message: advance")
      pulse_use(10)
      true
    rescue
      true
    end

    def battle_tick(snap)
      set_mode("battle")
      if snap["scene"].to_s == "battle_intro"
        key = [snap["map_id"], snap["x"], snap["y"], snap["raw_battle"]]
        if @battle_intro_key != key
          @battle_intro_key = key
          @battle_intro_started_at = botcore_now
          @battle_intro_reset_done = false
          @battle_intro_clear_requested_at = nil
        end
        @active_goal = nil
        @rail_action = "battle intro: waiting"
        unless @battle_intro_reset_done
          AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
          Navigator.reset!("battle intro") if defined?(AutoplayBot::Navigator)
          @battle_intro_reset_done = true
        end
        elapsed = botcore_now - @battle_intro_started_at.to_f
        if elapsed >= battle_intro_nudge_seconds
          @rail_action = "battle intro: nudge #{elapsed.round(1)}s"
          pulse_use_seconds(0.25)
        end
        if elapsed >= battle_intro_timeout_seconds
          @battle_intro_clear_requested_at ||= botcore_now
          @rail_action = "battle intro: watchdog waiting"
        end
        status_once("battle: starting")
      elsif snap["scene"].to_s == "battle_message"
        @battle_intro_key = nil
        @battle_intro_started_at = nil
        @battle_intro_reset_done = false
        status_once("battle message: advance")
        pulse_use(8)
      else
        @battle_intro_key = nil
        @battle_intro_started_at = nil
        @battle_intro_reset_done = false
        if defined?(AutoplayBot::Runtime) &&
           AutoplayBot::Runtime.respond_to?(:battle_scene_idle_confirm_tick)
          AutoplayBot::Runtime.battle_scene_idle_confirm_tick("battle policy")
        end
        status_once("battle: policy")
      end
      true
    rescue
      true
    end

    def menu_tick(snap)
      set_mode("menu")
      @menu_idle_frame ||= snap["frame"].to_i
      @menu_idle_started_at ||= botcore_now
      status_once("menu: wait")
      timeout = if defined?(AutoplayBot::Config) && AutoplayBot::Config.respond_to?(:menu_idle_escape_frames)
                  AutoplayBot::Config.menu_idle_escape_frames
                else
                  600
                end
      pending = pause_menu_pending_action
      timeout = pending ? [timeout.to_i, 120].min : 18
      timeout_seconds = pending ? 1.25 : 0.3
      if snap["frame"].to_i - @menu_idle_frame.to_i > timeout.to_i ||
         botcore_now - @menu_idle_started_at.to_f > timeout_seconds
        if defined?(AutoplayBot::MenuTools) && !pending && AutoplayBot::MenuTools.respond_to?(:clear!)
          AutoplayBot::MenuTools.clear!
        end
        if defined?(AutoplayBot::InputQueue)
          AutoplayBot::InputQueue.clear
          AutoplayBot::InputQueue.tap(:BACK, 2)
          AutoplayBot::InputQueue.tap_next(:BACK, 2) if AutoplayBot::InputQueue.respond_to?(:tap_next)
        end
        @menu_idle_frame = snap["frame"].to_i
        @menu_idle_started_at = botcore_now
        status_once("menu: backing out")
      end
      true
    rescue
      true
    end

    def wait_scene_tick(snap)
      set_mode(snap["scene"].to_s == "transfer" ? "navigation" : "story")
      status_once("wait #{snap["scene"]}")
      true
    rescue
      true
    end

    def pulse_use(interval_frames)
      frame = SceneObserver.frame_count
      @last_use_pulse_frame ||= -9999
      return if frame.to_i - @last_use_pulse_frame.to_i < interval_frames.to_i
      @last_use_pulse_frame = frame.to_i
      AutoplayBot::InputQueue.tap(:USE, 2) if defined?(AutoplayBot::InputQueue)
    rescue
      nil
    end

    def pulse_use_seconds(interval_seconds)
      now = botcore_now
      @last_use_pulse_at ||= 0.0
      return if now - @last_use_pulse_at.to_f < interval_seconds.to_f
      @last_use_pulse_at = now
      AutoplayBot::InputQueue.tap(:USE, 2) if defined?(AutoplayBot::InputQueue)
    rescue
      nil
    end

    def battle_intro_nudge_seconds
      speed = defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.respond_to?(:game_speed_multiplier) ? AutoplayBot::Runtime.game_speed_multiplier : 1
      speed.to_i >= 7 ? 1.0 : 1.8
    rescue
      1.8
    end

    def battle_intro_timeout_seconds
      if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.respond_to?(:battle_start_grace_seconds)
        return AutoplayBot::Runtime.battle_start_grace_seconds
      end
      10.0
    rescue
      10.0
    end

    def botcore_now
      if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.respond_to?(:current_time_seconds)
        return AutoplayBot::Runtime.current_time_seconds
      end
      Time.now.to_f
    rescue
      0.0
    end

    def scan_current_map_if_needed(snap, goal = nil)
      return unless defined?(AutoplayBot::WorldScanner) && state_write_allowed?
      return if startup_scan_deferred?
      return if goal && ["progress", "adapter"].include?(goal["kind"].to_s) && goal["adapter"].to_s != "unknown_map_wander"
      frame = snap["frame"].to_i
      return if @last_scan_map_id.to_i == snap["map_id"].to_i &&
                @last_scan_frame && frame - @last_scan_frame.to_i < 240
      map = AutoplayBot::WorldScanner.current_map_data
      @last_scan_map_id = snap["map_id"]
      @last_scan_frame = frame
      summary = map_summary_targets(map)
      AutoplayBot::State.record_map_knowledge(snap["map_id"], "targets" => summary, "name" => (map && map["name"])) if AutoplayBot::State.respond_to?(:record_map_knowledge)
    rescue => e
      AutoplayBot.log("bot map scan failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def map_summary_targets(map)
      targets = []
      return targets unless map
      [["item", "items"], ["resource", "field_resources"], ["npc", "npcs"], ["trainer", "trainers"], ["transfer", "transfers"]].each do |kind, key|
        Array(map[key]).each do |record|
          next unless record.is_a?(Hash)
          targets << {
            "kind" => kind,
            "key" => record["key"] || record["event_id"],
            "x" => record["x"],
            "y" => record["y"],
            "label" => record["event_name"]
          }
        end
      end
      targets
    rescue
      []
    end

    def active_or_new_goal(snap)
      if @active_goal && goal_still_valid?(@active_goal, snap)
        return @active_goal
      end
      @active_goal = choose_goal(snap)
      @active_goal_key = @active_goal ? Navigator.goal_key(@active_goal) : nil
      @last_goal_choice_frame = snap["frame"]
      @active_goal
    rescue
      nil
    end

    def goal_still_valid?(goal, snap)
      return false unless goal
      return false if goal["map_id"] && snap["map_id"] && goal["map_id"].to_i != snap["map_id"].to_i
      record = goal["record"].is_a?(Hash) ? goal["record"] : goal
      kind = goal["target_kind"] || goal["kind"]
      return false if target_done_or_failed?(record, kind)
      return false if local_priority_preempts_goal?(goal, snap)
      return false if encounter_zone_should_preempt_goal?(goal, snap)
      if goal["adapter"].to_s == "unknown_map_wander"
        return false if snap["frame"].to_i - @last_goal_choice_frame.to_i > 90
      end
      if goal["adapter"].to_s == "wild_grass_patrol"
        return false if snap["scene"].to_s != "map"
        unless cave_encounter_map?
          return false if !grass_tile?(snap["x"], snap["y"]) &&
                          snap["frame"].to_i - @last_goal_choice_frame.to_i > 240
        end
      end
      if goal["adapter"].to_s == "pause_menu_action"
        pending = if defined?(AutoplayBot::MenuTools) && AutoplayBot::MenuTools.respond_to?(:pending_action)
                    AutoplayBot::MenuTools.pending_action
                  else
                    nil
                  end
        action = goal["menu_action"].to_s
        return true if pending && pending.to_s == action
        return false unless pause_menu_goal_allowed?(snap)
        return false unless pause_menu_action_available?(action)
      end
      true
    rescue
      false
    end

    def local_priority_preempts_goal?(goal, snap)
      return false unless snap && snap["scene"].to_s == "map"
      return false if snap["moving"] || snap["transfer"] || snap["cutscene"] || snap["raw_battle"]
      return false if snap["map_stable_frames"].to_i < 4
      return false if snap["frame"].to_i - @last_goal_choice_frame.to_i < 18
      kind = (goal["target_kind"] || goal["kind"]).to_s
      adapter = goal["adapter"].to_s
      return false if %w[item resource gift static trainer].include?(kind)
      return false if %w[pause_menu_action wild_grass_patrol].include?(adapter)
      live = live_interaction_goals(snap, 2).find do |candidate|
        priority_live_goal_candidate?(candidate, snap, nil)
      end
      !!live
    rescue
      false
    end

    def choose_goal(snap)
      story = story_goal(snap)
      story = nil if adapter_goal_blocked?(story, snap)

      live_priority = priority_live_goal(snap, story)
      return live_priority if live_priority

      if immediate_hunt_surface?(snap)
        if cold_start? || state_deferred?
          return adapter_goal("wild_grass_patrol", wild_capture_goal_label(snap), "score" => 230)
        end
        hunt = AutoplayBot::DexHuntPlanner.choose_goal(snap, nil, nil) if defined?(AutoplayBot::DexHuntPlanner)
        return hunt if hunt
        return adapter_goal("wild_grass_patrol", wild_capture_goal_label(snap), "score" => 220)
      end
      if startup_scan_deferred? && wild_capture_focus_active? && wild_capture_supplies_ready? &&
         [2, 4, 6, 8].include?(adjacent_grass_dir(snap))
        return adapter_goal("wild_grass_patrol", wild_capture_goal_label(snap), "score" => 215)
      end

      return story if cold_start? && story
      return story if state_deferred? && story
      menu = pause_menu_goal(snap, story)
      return menu if menu
      map = current_map_data
      shop = pokemart_restock_goal(map, snap, story)
      return shop if shop

      world = AutoplayBot::WorldCoveragePlanner.choose_goal(snap, story, map) if !startup_scan_deferred? &&
                                                                                defined?(AutoplayBot::WorldCoveragePlanner)
      return world if world

      if defined?(AutoplayBot::Config) && AutoplayBot::Config.wild_capture_focus?
        hunt = AutoplayBot::DexHuntPlanner.choose_goal(snap, story, map) if defined?(AutoplayBot::DexHuntPlanner)
        return hunt if hunt
        encounter = encounter_explore_goal(map, snap, story)
        return encounter if encounter
      end

      field = field_obstacle_goal(snap, story)
      return field if field
      trainer_steal = trainer_steal_goal(map, snap, story)
      return trainer_steal if trainer_steal
      if defined?(AutoplayBot::Config) && AutoplayBot::Config.wild_capture_focus?
        collect = nearby_collect_goal(map, snap, story)
        return collect if collect && (!story || manhattan(collect["record"], snap) <= 4)
        npc = nearby_npc_goal(map, snap, story)
        return npc if npc && (!story || manhattan(npc["record"], snap) <= 3)
        building = nearby_building_goal(map, snap, story)
        return building if building && (!story || manhattan(building["record"], snap) <= 4)
        return story if story
        if wild_capture_supplies_ready? &&
           (cave_encounter_map? || nearby_grass_targets(snap, 8).any?)
          return adapter_goal("wild_grass_patrol", wild_capture_goal_label(snap), "score" => 45)
        end
        return unknown_map_goal(map, snap) || adapter_goal("unknown_map_wander", "Find supplies or route", "score" => 35)
      end
      collect = nearby_collect_goal(map, snap, story)
      return collect if collect
      npc = nearby_npc_goal(map, snap, story)
      return npc if npc
      return story if story
      building = nearby_building_goal(map, snap, nil)
      return building if building
      frontier = frontier_goal(map, snap)
      return frontier if frontier
      unknown_map_goal(map, snap)
    rescue => e
      AutoplayBot.log("goal choice failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      nil
    end

    def encounter_zone_should_preempt_goal?(goal, snap)
      return false unless wild_capture_focus_active?
      return false unless snap && snap["scene"].to_s == "map"
      return false unless wild_capture_supplies_ready?
      adapter = goal["adapter"].to_s
      kind = goal["kind"].to_s
      target_kind = goal["target_kind"].to_s
      return false if adapter == "wild_grass_patrol"
      return false if adapter == "pause_menu_action" || kind == "shop" || kind == "heal"
      return false if target_kind == "shop" || target_kind == "heal"
      return false if cold_start? || state_deferred?
      return true if wild_encounter_floor_here?(snap)
      path = cached_path_to_nearby_grass(snap)
      return true if path && !path.empty? && path.length <= encounter_preempt_path_limit
      false
    rescue
      false
    end

    def encounter_preempt_path_limit
      speed = botcore_speed_multiplier
      return 10 if speed.to_i >= 7
      14
    rescue
      14
    end

    def pause_menu_goal(snap, story = nil)
      pending = pause_menu_pending_goal
      return pending if pending
      return nil if defer_nonurgent_menu_for_hunt?(snap)
      return nil unless pause_menu_goal_allowed?(snap, false)

      if pause_menu_heal_needed? && pause_menu_action_available?(:heal)
        return pause_menu_goal_for(:heal, "Heal from pause menu", "party needs healing", 190)
      end

      if pause_menu_shop_needed? && pause_menu_action_available?(:kuray_shop) &&
         !defer_kuray_for_nearby_mart?(snap, story)
        return pause_menu_goal_for(:kuray_shop, "Restock from Kuray Shop", "supplies low", 170)
      end

      if pause_menu_pc_needed?(snap, story) && pause_menu_action_available?(:pc)
        return pause_menu_goal_for(:pc, "Review PC storage", "party/storage planning", 110)
      end

      if pause_menu_bag_needed?(snap, story) && pause_menu_action_available?(:bag)
        return pause_menu_goal_for(:bag, "Check Bag supplies", "inventory planning", 85)
      end
      nil
    rescue => e
      AutoplayBot.log("pause menu goal failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      nil
    end

    def urgent_pause_menu_goal(snap)
      pending = pause_menu_pending_goal
      return pending if pending
      return nil unless pause_menu_goal_allowed?(snap, true)
      if pause_menu_heal_needed? && pause_menu_action_available?(:heal)
        return pause_menu_goal_for(:heal, "Heal from pause menu", "urgent party healing", 240)
      end
      return nil if defer_nonurgent_menu_for_hunt?(snap)
      if pause_menu_shop_needed? && pause_menu_action_available?(:kuray_shop) &&
         !defer_kuray_for_nearby_mart?(snap, nil)
        return pause_menu_goal_for(:kuray_shop, "Restock from Kuray Shop", "urgent supply restock", 205)
      end
      nil
    rescue
      nil
    end

    def immediate_hunt_surface?(snap)
      return false unless wild_capture_focus_active?
      return false unless snap && snap["scene"].to_s == "map"
      return false unless wild_capture_supplies_ready?
      return false if pause_menu_heal_needed?
      return false if pause_menu_pending_goal
      wild_encounter_floor_here?(snap)
    rescue
      false
    end

    def defer_nonurgent_menu_for_hunt?(snap)
      return true if cold_start? || state_deferred?
      return false unless wild_capture_focus_active?
      return false unless snap && snap["scene"].to_s == "map"
      return false unless wild_capture_supplies_ready?
      return true if wild_encounter_floor_here?(snap)
      path = cached_path_to_nearby_grass(snap)
      path && !path.empty? && path.length <= 3
    rescue
      false
    end

    def defer_kuray_for_nearby_mart?(snap, story = nil)
      return false unless snap && snap["scene"].to_s == "map"
      return false if story && strong_story_pressure?
      map = current_map_data
      return true if current_mart_map?(map)
      Array(map && map["transfers"]).any? do |record|
        record.is_a?(Hash) && mart_transfer_like?(record) && manhattan(record, snap) <= 24
      end
    rescue
      false
    end

    def pokemart_restock_goal(map, snap, story = nil)
      return nil unless snap && snap["scene"].to_s == "map"
      return nil unless pokemart_restock_needed?
      clerk = mart_clerk_goal(map, snap)
      return clerk if clerk
      return nil if story && strong_story_pressure?
      return nil unless map
      candidates = []
      Array(map["transfers"]).each do |record|
        next unless record.is_a?(Hash) && record["x"] && record["y"]
        next unless mart_transfer_like?(record)
        next if target_done_or_failed?(record, "mart")
        next if attempts_exhausted?(record, "mart")
        goal = goal_from_record("nearby_building", "mart", record, 175)
        goal["label"] = "Restock at Pokemart" if goal
        candidates << goal
      end
      best_reachable_candidate(candidates, snap, story ? 18 : 32)
    rescue
      nil
    end

    def pokemart_restock_needed?
      return true if wild_capture_focus_active? && !wild_capture_supplies_ready?
      defined?(AutoplayBot::ShopPolicy) &&
        AutoplayBot::ShopPolicy.respond_to?(:restock_needed?) &&
        AutoplayBot::ShopPolicy.restock_needed?
    rescue
      false
    end

    def mart_clerk_goal(map, snap)
      return nil unless current_mart_map?(map)
      candidates = []
      Array(map && map["npcs"]).each do |record|
        next unless record.is_a?(Hash) && record["x"] && record["y"]
        text = [record["event_name"], record["name"], record["args"], record["script"]].compact.join(" ")
        score = text =~ /clerk|cashier|mart|shop|poke ?mart|seller|counter/i ? 190 : 150
        goal = goal_from_record("shop", "shop", record, score)
        goal["label"] = "Buy Poke Balls" if goal
        candidates << goal
      end
      best_reachable_candidate(candidates, snap, 18)
    rescue
      nil
    end

    def current_mart_map?(map)
      name = map && map["name"] ? map["name"].to_s : current_map_name_for_transfer(current_map_id)
      name =~ /mart|shop|store/i
    rescue
      false
    end

    def mart_transfer_like?(record)
      text = [record["event_name"], record["name"], record["args"], record["script"]].compact.join(" ")
      return true if text =~ /mart|shop|store|poke ?mart/i
      dest = record["destination_map_id"] || record["to_map"] || record["map"]
      map_name_for_id(dest) =~ /mart|shop|store/i
    rescue
      false
    end

    def map_name_for_id(map_id)
      return "" unless map_id
      if defined?(AutoplayBot::WorldScanner)
        index = AutoplayBot::WorldScanner.instance_variable_get(:@index) rescue nil
        names = index && index["map_names"].is_a?(Hash) ? index["map_names"] : nil
        return names[map_id.to_s].to_s if names && names[map_id.to_s]
      end
      ""
    rescue
      ""
    end

    def best_reachable_candidate(candidates, snap, radius)
      usable = Array(candidates).compact.select do |goal|
        record = goal["record"].is_a?(Hash) ? goal["record"] : goal
        next false unless record && record["x"] && record["y"]
        kind = goal["target_kind"] || goal["kind"]
        next false if target_done_or_failed?(record, kind)
        next false if attempts_exhausted?(record, kind)
        next false if manhattan(record, snap) > radius.to_i
        true
      end
      sorted = usable.sort_by do |goal|
        record = goal["record"].is_a?(Hash) ? goal["record"] : goal
        [-goal["score"].to_i, manhattan(record, snap)]
      end
      sorted.first(reachability_probe_limit).find { |goal| nearby_goal_reachable?(goal, snap) } || sorted.first
    rescue
      nil
    end

    def reachability_probe_limit
      speed = defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.respond_to?(:game_speed_multiplier) ? AutoplayBot::Runtime.game_speed_multiplier : 1
      return 2 if speed.to_i >= 7
      return 3 if speed.to_i >= 3
      4
    rescue
      3
    end

    def field_obstacle_goal(snap, story = nil)
      return nil unless snap && snap["scene"].to_s == "map"
      return nil if story && strong_story_pressure? && snap["map_stable_frames"].to_i < 120
      records = live_field_obstacle_records(snap, story ? 5 : 9)
      return nil if records.empty?
      goals = records.map do |record|
        kind = field_move_target_kind(record["event_name"])
        next nil if target_done_or_failed?(record, kind)
        next nil if attempts_exhausted?(record, kind)
        unless field_move_available?(kind)
          mark_local_target_failed(record, kind, "missing_field_move")
          next nil
        end
        goal = goal_from_record("nearby_collect", kind, record, 125)
        goal["label"] = field_move_label(kind) if goal
        goal
      end
      best_reachable_candidate(goals, snap, story ? 7 : 12)
    rescue
      nil
    end

    def live_field_obstacle_records(snap, radius)
      return [] unless defined?($game_map) && $game_map && $game_map.respond_to?(:events)
      events = $game_map.events ? $game_map.events.values : []
      records = []
      events.each do |event|
        next unless field_obstacle_event?(event)
        dist = (event.x.to_i - snap["x"].to_i).abs + (event.y.to_i - snap["y"].to_i).abs
        next if dist > radius.to_i
        event_id = event.respond_to?(:id) ? event.id : event.object_id
        event_name = event.respond_to?(:name) ? event.name.to_s : "field obstacle"
        records << {
          "key" => "field:#{snap["map_id"]}:#{event_id}:#{event.x}:#{event.y}",
          "map_id" => snap["map_id"],
          "event_id" => event_id,
          "event_name" => event_name,
          "x" => event.x,
          "y" => event.y,
          "trigger" => 0
        }
      end
      records
    rescue
      []
    end

    def field_obstacle_event?(event)
      return false unless event && event.respond_to?(:x) && event.respond_to?(:y)
      return false if event.respond_to?(:erased) && event.erased
      name = event.respond_to?(:name) ? event.name.to_s : ""
      name =~ /cuttree|cut tree|smashrock|rock smash|strengthboulder|strength boulder/i
    rescue
      false
    end

    def field_move_target_kind(name)
      text = name.to_s
      return "rock_smash" if text =~ /smashrock|rock smash/i
      return "strength" if text =~ /strengthboulder|strength boulder/i
      "cut"
    rescue
      "field_obstacle"
    end

    def field_move_label(kind)
      case kind.to_s
      when "rock_smash" then "Use Rock Smash"
      when "strength" then "Use Strength"
      when "cut" then "Use Cut"
      else "Use field move"
      end
    rescue
      "Use field move"
    end

    def field_move_available?(kind)
      case kind.to_s
      when "rock_smash"
        field_move_unlocked?(:ROCKSMASH, :PICKAXE, field_move_badge_constant(:BADGE_FOR_ROCKSMASH))
      when "strength"
        return false if pokemon_map_strength_active?
        field_move_unlocked?(:STRENGTH, :LEVER, field_move_badge_constant(:BADGE_FOR_STRENGTH))
      when "cut"
        field_move_unlocked?(:CUT, :MACHETE, field_move_badge_constant(:BADGE_FOR_CUT))
      else
        false
      end
    rescue
      false
    end

    def field_move_unlocked?(move, item, badge)
      return true if bag_quantity_for_item(item) > 0
      return false unless field_move_badge_ok?(badge)
      return true if defined?($DEBUG) && $DEBUG
      trainer_has_move?(move)
    rescue
      false
    end

    def field_move_badge_constant(name)
      key = name.to_s
      if defined?(Settings) && Settings.respond_to?(:const_defined?) && Settings.const_defined?(key)
        return Settings.const_get(key)
      end
      -1
    rescue
      -1
    end

    def field_move_badge_ok?(badge)
      badge = badge.to_i
      return true if badge < 0
      return true if defined?($DEBUG) && $DEBUG
      return false unless defined?($Trainer) && $Trainer
      if defined?(Settings) && Settings.respond_to?(:const_defined?) &&
         Settings.const_defined?("FIELD_MOVES_COUNT_BADGES") && Settings::FIELD_MOVES_COUNT_BADGES
        return $Trainer.respond_to?(:badge_count) && $Trainer.badge_count.to_i >= badge
      end
      badges = $Trainer.respond_to?(:badges) ? $Trainer.badges : nil
      !!(badges && badges[badge])
    rescue
      false
    end

    def trainer_has_move?(move)
      return false unless defined?($Trainer) && $Trainer
      return true if $Trainer.respond_to?(:get_pokemon_with_move) && $Trainer.get_pokemon_with_move(move)
      party = $Trainer.respond_to?(:party) ? Array($Trainer.party).compact : []
      move_id = move.to_s.upcase
      party.any? do |pkmn|
        next false unless pkmn
        if pkmn.respond_to?(:knowsMove?)
          pkmn.knowsMove?(move)
        elsif pkmn.respond_to?(:moves)
          Array(pkmn.moves).any? do |m|
            id = m.respond_to?(:id) ? m.id : m
            id.to_s.upcase == move_id
          end
        else
          false
        end
      end
    rescue
      false
    end

    def bag_quantity_for_item(item)
      return 0 unless defined?($PokemonBag) && $PokemonBag
      return $PokemonBag.pbQuantity(item).to_i if $PokemonBag.respond_to?(:pbQuantity)
      return ($PokemonBag.pbHasItem?(item) ? 1 : 0) if $PokemonBag.respond_to?(:pbHasItem?)
      0
    rescue
      0
    end

    def pokemon_map_strength_active?
      defined?($PokemonMap) && $PokemonMap &&
        $PokemonMap.respond_to?(:strengthUsed) && $PokemonMap.strengthUsed
    rescue
      false
    end

    def urgent_pause_menu_stop_needed?(snap)
      return false unless snap && snap["scene"].to_s == "map"
      return false if snap["message"] || snap["menu"] || snap["transfer"] ||
                      snap["battle_scene"] || snap["raw_battle"] || snap["cutscene"]
      return false unless defined?(AutoplayBot::MenuTools)
      return false unless defined?($Trainer) && $Trainer
      return false unless trainer_has_pokedex? || starter_obtained? || trainer_party_count > 0
      return true if pause_menu_heal_needed? && pause_menu_action_available?(:heal)
      return true if pause_menu_shop_needed? && pause_menu_action_available?(:kuray_shop)
      false
    rescue
      false
    end

    def pause_menu_pending_goal
      return nil unless defined?(AutoplayBot::MenuTools) && AutoplayBot::MenuTools.respond_to?(:pending_action)
      action = AutoplayBot::MenuTools.pending_action
      return nil unless action
      reason = AutoplayBot::MenuTools.respond_to?(:pending_reason) ? AutoplayBot::MenuTools.pending_reason : "pending"
      pause_menu_goal_for(action, "Use #{pause_menu_action_label(action)}", reason, 220)
    rescue
      nil
    end

    def pause_menu_goal_allowed?(snap, allow_startup = false)
      return false unless snap && snap["scene"].to_s == "map"
      return false if snap["moving"] || snap["message"] || snap["menu"] || snap["transfer"] ||
                      snap["battle_scene"] || snap["raw_battle"] || snap["cutscene"]
      return false if snap["map_stable_frames"].to_i < 12
      return false if !allow_startup && (cold_start? || state_deferred?)
      return false unless defined?(AutoplayBot::MenuTools)
      return false unless defined?($Trainer) && $Trainer
      return false unless trainer_has_pokedex? || starter_obtained? || trainer_party_count > 0
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.respond_to?(:map_controls_ready?) &&
         !AutoplayBot::Runtime.map_controls_ready?
        return false
      end
      true
    rescue
      false
    end

    def pause_menu_action_available?(action)
      return false if menu_action_temporarily_blocked?(action)
      return false unless defined?(AutoplayBot::MenuTools) && AutoplayBot::MenuTools.respond_to?(:pause_menu_available_for?)
      AutoplayBot::MenuTools.pause_menu_available_for?(action.to_sym)
    rescue
      false
    end

    def pause_menu_goal_for(action, label, reason, score)
      action = action.to_sym
      kind = case action
             when :heal then "heal"
             when :kuray_shop then "shop"
             else "menu"
             end
      adapter_goal(
        "pause_menu_action",
        label || "Use #{pause_menu_action_label(action)}",
        "menu_action" => action.to_s,
        "menu_reason" => reason.to_s,
        "target_kind" => kind,
        "score" => score.to_i
      )
    rescue
      nil
    end

    def pause_menu_heal_needed?
      return false unless trainer_has_pokedex? || starter_obtained? || trainer_party_count > 0
      return true if dcall(:party_needs_center_heal?, false)
      return false unless defined?($Trainer) && $Trainer && $Trainer.respond_to?(:party)
      party = Array($Trainer.party).compact
      return false if party.empty?
      total = 0
      hp = 0
      able = 0
      critical = false
      party.each do |pkmn|
        cur = pkmn.respond_to?(:hp) ? pkmn.hp.to_i : 0
        max = pkmn.respond_to?(:totalhp) ? pkmn.totalhp.to_i : cur
        max = [max, 1].max
        cur = [[cur, 0].max, max].min
        total += max
        hp += cur
        able += 1 if cur > 0
        critical = true if cur > 0 && cur.to_f / max.to_f <= 0.25
      end
      return true if able <= 1 && party.length > 1
      return true if critical
      total > 0 && hp.to_f / total.to_f <= 0.65
    rescue
      false
    end

    def pause_menu_shop_needed?
      return true if dcall(:pause_menu_shop_needed?, false)
      return false unless trainer_has_pokedex?
      return true if wild_capture_focus_active? && !wild_capture_supplies_ready?
      return false unless defined?(AutoplayBot::ShopPolicy) && AutoplayBot::ShopPolicy.respond_to?(:restock_needed?)
      AutoplayBot::ShopPolicy.restock_needed?
    rescue
      false
    end

    def pause_menu_pc_needed?(snap, story = nil)
      return false if strong_story_pressure? && story
      return false unless trainer_has_pokedex? || starter_obtained?
      count = trainer_party_count
      return true if count >= 6
      frame = snap["frame"].to_i
      @last_pause_pc_goal_frame ||= -9999
      return false if story
      return false if frame - @last_pause_pc_goal_frame.to_i < 7200
      false
    rescue
      false
    end

    def pause_menu_bag_needed?(snap, story = nil)
      # Passive bag checks can open sorting submenus; resource snapshots read the bag directly.
      return false
      return false if strong_story_pressure? && story
      return false unless trainer_has_pokedex?
      frame = snap["frame"].to_i
      @last_bag_goal_frame ||= -9999
      return false if frame - @last_bag_goal_frame.to_i < 5400
      plan = if defined?(AutoplayBot::ResourcePlanner) && AutoplayBot::ResourcePlanner.respond_to?(:current_plan)
               AutoplayBot::ResourcePlanner.current_plan
             else
               nil
             end
      needs = plan.is_a?(Hash) ? Array(plan["need"]) : []
      needs.any?
    rescue
      false
    end

    def trainer_party_count
      return 0 unless defined?($Trainer) && $Trainer
      return $Trainer.party_count.to_i if $Trainer.respond_to?(:party_count)
      return Array($Trainer.party).compact.length if $Trainer.respond_to?(:party)
      0
    rescue
      0
    end

    def pause_menu_action_label(action)
      if defined?(AutoplayBot::MenuTools) && AutoplayBot::MenuTools.respond_to?(:action_label)
        return AutoplayBot::MenuTools.action_label(action)
      end
      action.to_s
    rescue
      "menu"
    end

    def current_map_data
      return cached_current_map_data(false) if startup_scan_deferred?
      defined?(AutoplayBot::WorldScanner) ? AutoplayBot::WorldScanner.current_map_data : nil
    rescue
      nil
    end

    def cached_current_map_data(allow_live_scan = false)
      return nil unless defined?(AutoplayBot::WorldScanner) && defined?($game_map) && $game_map
      index = AutoplayBot::WorldScanner.instance_variable_get(:@index) rescue nil
      maps = index && index["maps"].is_a?(Hash) ? index["maps"] : nil
      data = maps ? maps[$game_map.map_id.to_s] : nil
      if data && AutoplayBot::WorldScanner.respond_to?(:map_data_matches_live?) &&
         !AutoplayBot::WorldScanner.map_data_matches_live?(data)
        return allow_live_scan ? AutoplayBot::WorldScanner.current_map_data : nil
      end
      data
    rescue
      nil
    end

    def startup_scan_deferred?
      return true if cold_start? || state_deferred?
      return true if defined?(AutoplayBot::Runtime) &&
                     AutoplayBot::Runtime.respond_to?(:startup_diagnostics_active?) &&
                     AutoplayBot::Runtime.startup_diagnostics_active?
      false
    rescue
      false
    end

    def current_position_key
      return nil unless defined?($game_map) && $game_map &&
                        defined?($game_player) && $game_player
      [$game_map.map_id, $game_player.x, $game_player.y]
    rescue
      nil
    end

    def cold_start?
      return false unless @cold_start_until_frame
      now = current_position_key
      if @cold_start_position && now && @cold_start_position != now
        @cold_start_until_frame = nil
        @cold_start_until_at = nil
        @cold_start_position = nil
        return false
      end
      active = SceneObserver.frame_count.to_i < @cold_start_until_frame.to_i ||
               (@cold_start_until_at && botcore_now < @cold_start_until_at.to_f)
      unless active
        @cold_start_until_frame = nil
        @cold_start_until_at = nil
        @cold_start_position = nil
      end
      active
    rescue
      @cold_start_until_frame = nil
      @cold_start_until_at = nil
      @cold_start_position = nil
      false
    end

    def cold_start_frames
      speed = defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.respond_to?(:game_speed_multiplier) ? AutoplayBot::Runtime.game_speed_multiplier : 1
      return 6 if speed.to_i >= 7
      return 10 if speed.to_i >= 3
      14
    rescue
      12
    end

    def cold_start_seconds
      speed = defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.respond_to?(:game_speed_multiplier) ? AutoplayBot::Runtime.game_speed_multiplier : 1
      return 0.12 if speed.to_i >= 7
      return 0.16 if speed.to_i >= 3
      0.22
    rescue
      0.18
    end

    def nearby_collect_goal(map, snap, story)
      return nil unless local_discovery?
      radius = collect_radius(story)
      candidates = []
      Array(map && map["items"]).each { |r| candidates << goal_from_record("nearby_collect", "item", r, 120) }
      Array(map && map["field_resources"]).each { |r| candidates << goal_from_record("nearby_collect", "resource", r, 115) }
      Array(map && map["gifts"]).each { |r| candidates << goal_from_record("nearby_collect", "gift", r, 100) }
      Array(map && map["wild_statics"]).each { |r| candidates << goal_from_record("nearby_collect", "static", r, 95) }
      best_nearby(candidates, snap, radius)
    rescue
      nil
    end

    def nearby_npc_goal(map, snap, story)
      return nil unless local_discovery?
      return nil if strong_story_pressure? && story
      radius = npc_radius(story)
      candidates = []
      Array(map && map["npcs"]).each { |r| candidates << goal_from_record("nearby_npc", "npc", r, 70) }
      Array(map && map["trainers"]).each { |r| candidates << goal_from_record("battle", "trainer", r, 65) }
      best_nearby(candidates, snap, radius)
    rescue
      nil
    end

    def nearby_trainer_goal(map, snap, radius = 3)
      candidates = []
      Array(map && map["trainers"]).each { |r| candidates << goal_from_record("battle", "trainer", r, 90) }
      best_nearby(candidates, snap, radius)
    rescue
      nil
    end

    def trainer_steal_goal(map, snap, story = nil)
      return nil unless snap && snap["scene"].to_s == "map"
      return nil unless trainer_capture_wanted?
      return nil if strong_story_pressure? && story && !trainer_capture_supplies_ready?
      candidates = []
      Array(map && map["trainers"]).each do |record|
        next unless record.is_a?(Hash)
        goal = goal_from_record("battle", "trainer", record, 185)
        goal["label"] = "Challenge trainer / steal Pokemon" if goal
        candidates << goal
      end
      radius = trainer_capture_supplies_ready? ? (story ? 12 : 30) : 10
      best_reachable_candidate(candidates, snap, radius)
    rescue
      nil
    end

    def trainer_capture_wanted?
      policy = defined?(AutoplayBot::Config) && AutoplayBot::Config.respond_to?(:trainer_capture_policy) ?
                 AutoplayBot::Config.trainer_capture_policy.to_s : "respect_game"
      return false if policy == "off"
      return true if policy == "force_rocket_balls" || policy == "force_all_balls"
      return true if defined?($PokemonSystem) && $PokemonSystem &&
                     $PokemonSystem.respond_to?(:rocketballsteal) &&
                     $PokemonSystem.rocketballsteal.to_i > 0
      false
    rescue
      false
    end

    def trainer_capture_supplies_ready?
      return false unless trainer_capture_wanted?
      if defined?(AutoplayBot::BattlePolicy) && AutoplayBot::BattlePolicy.respond_to?(:bag_quantity)
        return true if AutoplayBot::BattlePolicy.bag_quantity(:ROCKETBALL).to_i > 0
        return true if defined?(AutoplayBot::BattlePolicy) &&
                       AutoplayBot::BattlePolicy.respond_to?(:wild_capture_ball_count_without_reserved) &&
                       trainer_capture_all_balls? &&
                       AutoplayBot::BattlePolicy.wild_capture_ball_count_without_reserved.to_i > 0
      end
      false
    rescue
      false
    end

    def trainer_capture_all_balls?
      policy = defined?(AutoplayBot::Config) && AutoplayBot::Config.respond_to?(:trainer_capture_policy) ?
                 AutoplayBot::Config.trainer_capture_policy.to_s : "respect_game"
      return true if policy == "force_all_balls"
      defined?($PokemonSystem) && $PokemonSystem &&
        $PokemonSystem.respond_to?(:rocketballsteal) &&
        $PokemonSystem.rocketballsteal.to_i >= 2
    rescue
      false
    end

    def encounter_explore_goal(map, snap, story = nil)
      return nil unless snap && snap["scene"].to_s == "map"
      return nil if strong_story_pressure? && story && !wild_capture_supplies_ready?

      grass = wild_capture_goal(snap)
      return grass if grass

      immediate_trainer = nearby_trainer_goal(map, snap, 5)
      return immediate_trainer if immediate_trainer

      trainer = nearby_trainer_goal(map, snap, story ? 14 : 28)
      return trainer if trainer

      nil
    rescue
      nil
    end

    def nearby_building_goal(map, snap, story)
      return nil unless local_discovery?
      return nil if strong_story_pressure? && story
      radius = building_radius(story)
      candidates = []
      Array(map && map["transfers"]).each do |record|
        next if state_memory_ready? && AutoplayBot::State.respond_to?(:transfer_visited?) && AutoplayBot::State.transfer_visited?(record["key"])
        next if story && same_target?(record, story["record"] || story)
        candidates << goal_from_record("nearby_building", "building", record, 55)
      end
      best_nearby(candidates, snap, radius)
    rescue
      nil
    end

    def best_nearby(candidates, snap, radius)
      usable = Array(candidates).compact.select do |goal|
        record = goal["record"]
        next false unless record && record["x"] && record["y"]
        next false if target_done_or_failed?(record, goal["target_kind"])
        next false if attempts_exhausted?(record, goal["target_kind"])
        manhattan(record, snap) <= radius.to_i
      end
      sorted = usable.sort_by { |goal| [-(goal["score"].to_i - manhattan(goal["record"], snap)), manhattan(goal["record"], snap)] }
      sorted.first(6).find { |goal| nearby_goal_reachable?(goal, snap) }
    rescue
      nil
    end

    def nearby_goal_reachable?(goal, snap)
      return true unless goal && snap
      return true unless defined?(AutoplayBot::Navigator) && AutoplayBot::Navigator.respond_to?(:build_path)
      @nearby_reach_cache ||= {}
      record = goal["record"].is_a?(Hash) ? goal["record"] : goal
      key = [
        snap["map_id"], snap["x"], snap["y"],
        goal["kind"], goal["target_kind"], record["key"], record["event_id"], record["x"], record["y"]
      ].compact.join(":")
      frame = snap["frame"].to_i
      cached = @nearby_reach_cache[key]
      return cached["ok"] if cached && frame - cached["frame"].to_i < 90
      path = AutoplayBot::Navigator.build_path(goal)
      ok = path ? true : false
      @nearby_reach_cache[key] = { "frame" => frame, "ok" => ok }
      @nearby_reach_cache.shift while @nearby_reach_cache.length > 48
      ok
    rescue
      true
    end

    def wild_capture_goal(snap)
      return nil unless snap && snap["scene"].to_s == "map"
      return nil unless wild_capture_supplies_ready?
      return nil if grass_patrol_temporarily_blocked?(snap)
      label = wild_capture_goal_label(snap)
      return adapter_goal("wild_grass_patrol", label, "score" => 170) if wild_encounter_floor_here?(snap)
      path = cached_path_to_nearby_grass(snap)
      return nil unless path && !path.empty?
      adapter_goal("wild_grass_patrol", label, "score" => 170)
    rescue
      nil
    end

    def wild_capture_focus_active?
      defined?(AutoplayBot::Config) &&
        AutoplayBot::Config.respond_to?(:wild_capture_focus?) &&
        AutoplayBot::Config.wild_capture_focus?
    rescue
      false
    end

    def wild_capture_supplies_ready?
      wild_capture_ball_count > 0
    rescue
      true
    end

    def wild_capture_ball_count
      return 0 unless defined?($PokemonBag) && $PokemonBag
      wild_capture_ball_items.inject(0) do |sum, item|
        qty = if defined?(AutoplayBot::BattlePolicy) &&
                 AutoplayBot::BattlePolicy.respond_to?(:bag_quantity)
                AutoplayBot::BattlePolicy.bag_quantity(item)
              elsif $PokemonBag.respond_to?(:pbQuantity)
                $PokemonBag.pbQuantity(item).to_i
              elsif $PokemonBag.respond_to?(:pbHasItem?)
                $PokemonBag.pbHasItem?(item) ? 1 : 0
              else
                0
              end
        sum + qty.to_i
      end
    rescue
      0
    end

    def wild_capture_ball_items
      [
        :QUICKBALL, :ULTRABALL, :DUSKBALL, :TIMERBALL, :NETBALL,
        :GREATBALL, :FUSIONBALL, :POKEBALL, :PREMIERBALL
      ]
    rescue
      [:POKEBALL]
    end

    def grass_patrol_temporarily_blocked?(snap)
      return false unless snap
      state = @grass_patrol_state && @grass_patrol_state[snap["map_id"].to_i]
      return false unless state.is_a?(Hash)
      state["abort_until"].to_i > snap["frame"].to_i
    rescue
      false
    end

    def grass_no_supplies_tick(snap)
      @active_goal = nil
      @active_goal_key = nil
      @grass_path_cache = nil
      if grass_tile?(snap["x"], snap["y"])
        dir = passable_non_grass_dir(snap, nil) || choose_fallback_explore_dir(snap, { "blocked_dirs" => {} }, false)
        if [2, 4, 6, 8].include?(dir)
          @rail_action = "grass: no balls exit #{dir_label(dir)}"
          AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
          AutoplayBot::InputQueue.hold_dir(dir, rail_hold_frames(dir)) if defined?(AutoplayBot::InputQueue)
          return true
        end
      end
      @rail_action = "grass: no balls, seek supplies"
      AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
      fallback_explore_tick(snap, "no balls route", false)
    rescue => e
      @rail_action = "grass: no balls error #{e.class}"
      false
    end

    def grass_tile?(x, y)
      return false unless defined?($game_map) && $game_map && $game_map.respond_to?(:terrain_tag)
      tag = $game_map.terrain_tag(x.to_i, y.to_i) rescue nil
      return true if tag && tag.respond_to?(:land_wild_encounters) && tag.land_wild_encounters
      return true if tag && tag.respond_to?(:shows_grass_rustle) && tag.shows_grass_rustle
      false
    rescue
      false
    end

    def cave_encounter_map?
      if defined?($PokemonEncounters) && $PokemonEncounters
        return true if $PokemonEncounters.respond_to?(:has_cave_encounters?) &&
                       $PokemonEncounters.has_cave_encounters?
      end
      return true if cave_like_current_map?
      false
    rescue
      false
    end

    def cave_like_current_map?
      map_id = current_map_id
      name = ""
      if defined?(AutoplayBot::WorldScanner) && AutoplayBot::WorldScanner.respond_to?(:map_name)
        name = AutoplayBot::WorldScanner.map_name(map_id).to_s
      end
      if name.nil? || name.empty? || name =~ /\AMap\s+\d+\z/i
        data = cached_current_map_data rescue nil
        name = data["name"].to_s if data && data["name"]
      end
      if defined?($game_map) && $game_map
        name = [name, ($game_map.tileset_name if $game_map.respond_to?(:tileset_name)),
                ($game_map.battleback_name if $game_map.respond_to?(:battleback_name))].compact.join(" ")
      end
      return true if name =~ /cave|cavern|tunnel|rock|mt\.|mount|mountain|mine|ruins|sewer|den|hideout|dungeon|well|diglett/i
      false
    rescue
      false
    end

    def wild_encounter_floor_here?(snap)
      return false unless snap && snap["scene"].to_s == "map"
      return true if grass_tile?(snap["x"], snap["y"])
      return true if cave_encounter_map? && cave_floor_tile?(snap["x"], snap["y"])
      false
    rescue
      false
    end

    def wild_capture_goal_label(snap = nil)
      cave_encounter_map? ? "Find cave encounters and catch" : "Find grass and catch"
    rescue
      "Find encounters and catch"
    end

    def cave_floor_tile?(x, y)
      x = x.to_i
      y = y.to_i
      if defined?(AutoplayBot::Pathfinder) && AutoplayBot::Pathfinder.respond_to?(:valid_tile?)
        return false unless AutoplayBot::Pathfinder.valid_tile?(x, y)
      end
      if defined?($game_map) && $game_map && $game_map.respond_to?(:terrain_tag)
        tag = $game_map.terrain_tag(x, y) rescue nil
        return false if tag && tag.respond_to?(:ice) && tag.ice
      end
      true
    rescue
      false
    end

    def cached_path_to_nearby_grass(snap)
      key = [snap["map_id"].to_i, snap["x"].to_i, snap["y"].to_i]
      cache = @grass_path_cache
      if cache && cache["key"] == key && snap["frame"].to_i - cache["frame"].to_i < 90
        return cache["path"]
      end
      targets = nearby_grass_targets(snap, grass_search_radius)
      path = if targets.empty?
               nil
             elsif defined?(AutoplayBot::Pathfinder) && AutoplayBot::Pathfinder.respond_to?(:find_path_to_any)
               AutoplayBot::Pathfinder.find_path_to_any(targets, grass_path_budget)
             else
               nil
             end
      @grass_path_cache = { "key" => key, "frame" => snap["frame"].to_i, "path" => path }
      path
    rescue
      nil
    end

    def nearby_grass_targets(snap, radius)
      return [] unless defined?($game_map) && $game_map
      width = $game_map.respond_to?(:width) ? $game_map.width.to_i : snap["x"].to_i + radius.to_i + 1
      height = $game_map.respond_to?(:height) ? $game_map.height.to_i : snap["y"].to_i + radius.to_i + 1
      min_x = [snap["x"].to_i - radius.to_i, 0].max
      max_x = [snap["x"].to_i + radius.to_i, width - 1].min
      min_y = [snap["y"].to_i - radius.to_i, 0].max
      max_y = [snap["y"].to_i + radius.to_i, height - 1].min
      targets = []
      y = min_y
      while y <= max_y
        x = min_x
        while x <= max_x
          targets << [x, y] if grass_tile?(x, y) && grass_candidate_tile?(x, y)
          x += 1
        end
        y += 1
      end
      targets.sort_by { |tx, ty| (tx - snap["x"].to_i).abs + (ty - snap["y"].to_i).abs }.first(96)
    rescue
      []
    end

    def grass_candidate_tile?(x, y)
      return false unless defined?(AutoplayBot::Pathfinder) && AutoplayBot::Pathfinder.respond_to?(:valid_tile?)
      return false unless AutoplayBot::Pathfinder.valid_tile?(x.to_i, y.to_i)
      [2, 4, 6, 8].any? do |dir|
        dx, dy = dir_delta(dir)
        AutoplayBot::Pathfinder.valid_tile?(x.to_i - dx, y.to_i - dy)
      end
    rescue
      true
    end

    def grass_search_radius
      20
    rescue
      20
    end

    def grass_path_budget
      if defined?(AutoplayBot::Config) && AutoplayBot::Config.respond_to?(:path_node_budget)
        return AutoplayBot::Config.path_node_budget(1200)
      end
      1200
    rescue
      1200
    end

    def dir_delta(dir)
      case dir.to_i
      when 2 then [0, 1]
      when 4 then [-1, 0]
      when 6 then [1, 0]
      when 8 then [0, -1]
      else [0, 0]
      end
    rescue
      [0, 0]
    end

    def unknown_map_goal(map, snap)
      target = best_unknown_map_target(map, snap)
      return target if target
      adapter_goal("unknown_map_wander", "Explore current map", "score" => 40)
    rescue
      adapter_goal("unknown_map_wander", "Explore current map", "score" => 40)
    end

    def best_unknown_map_target(map, snap)
      return live_nearby_goal(snap, 12) || live_adjacent_event_goal(snap) unless map
      candidates = []
      Array(map["trainers"]).each { |r| candidates << goal_from_record("battle", "trainer", r, 100) }
      Array(map["items"]).each { |r| candidates << goal_from_record("nearby_collect", "item", r, 92) }
      Array(map["field_resources"]).each { |r| candidates << goal_from_record("nearby_collect", "resource", r, 88) }
      Array(map["gifts"]).each { |r| candidates << goal_from_record("nearby_collect", "gift", r, 84) }
      Array(map["wild_statics"]).each { |r| candidates << goal_from_record("nearby_collect", "static", r, 80) }
      Array(map["npcs"]).each { |r| candidates << goal_from_record("nearby_npc", "npc", r, 78) }
      Array(map["transfers"]).each do |record|
        next if state_memory_ready? && AutoplayBot::State.respond_to?(:transfer_visited?) && AutoplayBot::State.transfer_visited?(record["key"])
        candidates << goal_from_record("nearby_building", "building", record, 66)
      end
      live = live_adjacent_event_goal(snap)
      candidates << live if live
      candidates.concat(live_interaction_goals(snap, 10))
      best_unknown_candidate(candidates, snap)
    rescue
      live_adjacent_event_goal(snap)
    end

    def best_unknown_candidate(candidates, snap)
      limit = unknown_target_radius
      usable = Array(candidates).compact.select do |goal|
        record = goal["record"].is_a?(Hash) ? goal["record"] : goal
        next false unless record && record["x"] && record["y"]
        kind = goal["target_kind"] || goal["kind"]
        next false if target_done_or_failed?(record, kind)
        next false if attempts_exhausted?(record, kind)
        manhattan(record, snap) <= limit
      end
      sorted = usable.sort_by do |goal|
        record = goal["record"].is_a?(Hash) ? goal["record"] : goal
        distance = manhattan(record, snap)
        [-goal["score"].to_i, distance]
      end
      probed = sorted.first(reachability_probe_limit)
      reachable = probed.find { |goal| nearby_goal_reachable?(goal, snap) }
      unless reachable
        blocked = probed.find { |goal| goal["kind"].to_s != "progress" }
        if blocked
          record = blocked["record"].is_a?(Hash) ? blocked["record"] : blocked
          mark_local_target_failed(record, blocked["target_kind"] || blocked["kind"], "no_path")
        end
      end
      reachable || sorted.find { |goal| goal["kind"].to_s == "progress" }
    rescue
      nil
    end

    def unknown_target_radius
      if defined?(AutoplayBot::Config) && AutoplayBot::Config.respond_to?(:local_discovery_path_limit)
        return [AutoplayBot::Config.local_discovery_path_limit.to_i, 48].max
      end
      48
    rescue
      48
    end

    def live_adjacent_event_goal(snap)
      live_nearby_goal(snap, 2)
    rescue
      nil
    end

    def priority_live_goal(snap, story = nil)
      return nil unless snap && snap["scene"].to_s == "map"
      return nil if snap["moving"] || snap["transfer"] || snap["cutscene"] || snap["raw_battle"]
      return nil if snap["map_stable_frames"].to_i < 3
      radius = story ? 5 : 9
      goals = live_interaction_goals(snap, radius).select do |goal|
        priority_live_goal_candidate?(goal, snap, story)
      end
      best_unknown_candidate(goals, snap)
    rescue
      nil
    end

    def priority_live_goal_candidate?(goal, snap, story = nil)
      record = goal && goal["record"].is_a?(Hash) ? goal["record"] : goal
      return false unless record && record["x"] && record["y"]
      kind = (goal["target_kind"] || goal["kind"]).to_s
      dist = manhattan(record, snap)
      return false if dist > (story ? 5 : 9)
      return true if %w[item resource gift static trainer].include?(kind)
      # Generic NPC chatter is useful, but do not let it steal long-range story
      # routing unless the bot is already next to the person.
      return true if kind == "npc" && dist <= (story ? 1 : 2)
      false
    rescue
      false
    end

    def live_nearby_goal(snap, radius = 8)
      best_unknown_candidate(live_interaction_goals(snap, radius), snap)
    rescue
      nil
    end

    def live_interaction_goals(snap, radius = 8)
      return [] unless defined?($game_map) && $game_map && defined?($game_player) && $game_player
      events = $game_map.respond_to?(:events) && $game_map.events ? $game_map.events.values : []
      goals = []
      events.each do |event|
        next unless event && event.respond_to?(:x) && event.respond_to?(:y)
        dist = (event.x.to_i - $game_player.x.to_i).abs + (event.y.to_i - $game_player.y.to_i).abs
        next if dist <= 0 || dist > radius.to_i
        next if event.respond_to?(:erased) && event.erased
        next unless live_event_relevant?(event)
        name = event.respond_to?(:name) ? event.name.to_s : "event"
        kind, target_kind, score = live_event_goal_classification(event)
        next unless live_event_goal_actionable?(event, target_kind)
        record = {
          "key" => "live:#{snap["map_id"]}:#{event.respond_to?(:id) ? event.id : name}:#{event.x}:#{event.y}",
          "map_id" => snap["map_id"],
          "event_id" => (event.respond_to?(:id) ? event.id : nil),
          "event_name" => name,
          "x" => event.x,
          "y" => event.y,
          "trigger" => live_event_trigger(event),
          "graphic" => live_event_sprite_name(event),
          "tile_id" => live_event_tile_id(event),
          "live_goal" => true
        }
        goal = goal_from_record(kind, target_kind, record, score.to_i - dist)
        goals << goal if goal
      end
      goals
    rescue
      []
    end

    def live_event_relevant?(event)
      return false unless event
      name = event.respond_to?(:name) ? event.name.to_s : ""
      return false if name =~ /follower|dependent|player shadow|reflection/i
      text = [name, live_event_sprite_name(event), live_event_tile_id(event)].join(" ")
      known = text =~ /trainer|rival|rocket|grunt|leader|bug|lass|hiker|camper|picnicker|fisher|sailor|psychic|cooltrainer|ace|blackbelt|bird keeper|item|ball|mushroom|berry|web|trash|forage|pickup|hidden|sign|notice|board|npc|clerk|nurse|mart|shop/i
      return true if known && live_event_has_meaningful_commands?(event)
      live_event_has_meaningful_commands?(event) &&
        (!live_event_sprite_name(event).empty? || live_event_tile_id(event).to_i > 0)
    rescue
      false
    end

    def live_event_goal_classification(event)
      name = event.respond_to?(:name) ? event.name.to_s : ""
      sprite = live_event_sprite_name(event)
      text = [name, sprite, live_event_tile_id(event)].join(" ")
      return ["battle", "trainer", 152] if text =~ /trainer|rival|rocket|grunt|leader|bug|lass|hiker|camper|picnicker|fisher|sailor|psychic|cooltrainer|ace|blackbelt|bird keeper/i
      return ["nearby_collect", "resource", 146] if text =~ /mushroom|berry|web|trash|forage|pickup|hidden|apricorn|plant|harvest/i
      return ["nearby_collect", "item", 144] if text =~ /item|ball|pok[eé]ball|poke.?ball|tm|hm|pickup/i
      return ["nearby_npc", "npc", 62] if text =~ /sign|notice|board/i
      ["nearby_npc", "npc", 92]
    rescue
      ["nearby_npc", "npc", 74]
    end

    def live_event_goal_actionable?(event, target_kind)
      return false unless event
      return live_event_has_meaningful_commands?(event) if %w[item resource gift static npc].include?(target_kind.to_s)
      true
    rescue
      false
    end

    def live_event_sprite_name(event)
      return event.character_name.to_s if event.respond_to?(:character_name)
      value = event.instance_variable_get(:@character_name) if event.respond_to?(:instance_variable_get)
      value.to_s
    rescue
      ""
    end

    def live_event_tile_id(event)
      return event.tile_id.to_i if event.respond_to?(:tile_id)
      value = event.instance_variable_get(:@tile_id) if event.respond_to?(:instance_variable_get)
      value.to_i
    rescue
      0
    end

    def live_event_trigger(event)
      return event.trigger.to_i if event.respond_to?(:trigger)
      value = event.instance_variable_get(:@trigger) if event.respond_to?(:instance_variable_get)
      value.to_i
    rescue
      0
    end

    def live_event_has_meaningful_commands?(event)
      list = live_event_command_list(event)
      return false unless list && list.respond_to?(:any?)
      list.any? do |command|
        code = command.respond_to?(:code) ? command.code.to_i : 0
        code > 0 && code != 108 && code != 408
      end
    rescue
      false
    end

    def live_event_command_list(event)
      return event.list if event.respond_to?(:list) && event.list
      if event.respond_to?(:instance_variable_get) && event.instance_variable_defined?(:@list)
        return event.instance_variable_get(:@list)
      end
      page = if event.respond_to?(:instance_variable_get) && event.instance_variable_defined?(:@page)
               event.instance_variable_get(:@page)
             end
      if page
        return page.list if page.respond_to?(:list)
        if page.respond_to?(:instance_variable_get) && page.instance_variable_defined?(:@list)
          return page.instance_variable_get(:@list)
        end
      end
      nil
    rescue
      nil
    end

    def goal_from_record(kind, target_kind, record, score)
      record = stringify_hash(record)
      record["map_id"] ||= current_map_id
      {
        "kind" => kind,
        "target_kind" => target_kind,
        "score" => score,
        "label" => record["event_name"] || target_kind,
        "map_id" => record["map_id"] || current_map_id,
        "x" => record["x"],
        "y" => record["y"],
        "record" => record
      }
    rescue
      nil
    end

    def story_goal(snap)
      map_id = snap["map_id"].to_i
      d = AutoplayBot::Director if defined?(AutoplayBot::Director)
      return player_house_goal(map_id, snap) if d && player_house_related?(map_id)
      return oak_lab_goal(map_id) if d && oak_lab?(map_id)
      return pallet_goal(map_id) if d && map_id == dconst(:PALLET_TOWN_MAP_ID, 42)
      return route1_goal(map_id) if d && map_id == dconst(:ROUTE_1_MAP_ID, 78)
      return viridian_goal(map_id) if d && map_id == dconst(:VIRIDIAN_CITY_MAP_ID, 79)
      return mart_goal(map_id) if d && map_id == dconst(:VIRIDIAN_MART_MAP_ID, 81)
      return route2_south_goal(map_id) if d && map_id == dconst(:ROUTE_2_SOUTH_MAP_ID, 86)
      return forest_south_gate_goal(map_id) if d && map_id == dconst(:VIRIDIAN_FOREST_SOUTH_GATE_MAP_ID, 88)
      return forest_goal(map_id) if d && map_id == dconst(:VIRIDIAN_FOREST_MAP_ID, 491)
      return forest_north_gate_goal(map_id) if d && map_id == dconst(:VIRIDIAN_FOREST_NORTH_GATE_MAP_ID, 89)
      return route2_north_goal(map_id) if d && map_id == dconst(:ROUTE_2_NORTH_MAP_ID, 90)
      return pewter_goal(map_id) if d && map_id == dconst(:PEWTER_CITY_MAP_ID, 380)
      return pewter_gym_goal(map_id) if d && map_id == dconst(:PEWTER_GYM_MAP_ID, 386)
      nil
    rescue
      nil
    end

    def adapter_goal(adapter, label, extra = nil)
      goal = {
        "kind" => "adapter",
        "adapter" => adapter,
        "label" => label,
        "map_id" => current_map_id,
        "score" => 200
      }
      goal.merge!(extra) if extra.is_a?(Hash)
      goal
    end

    def player_house_goal(map_id, snap = nil)
      starter_room = dconst(:STARTER_ROOM_MAP_ID, 71)
      player_house = dconst(:PLAYER_HOUSE_MAP_ID, 43)
      house_ids = dconst(:PLAYER_HOUSE_MAP_IDS, [43, 3])
      room_ids = dconst(:PLAYER_ROOM_MAP_IDS, [starter_room, 67, 68, 69, 70, 71, 73])
      if Array(room_ids).map(&:to_i).include?(map_id.to_i)
        outfit = bedroom_outfit_goal(map_id, snap)
        return outfit if outfit
        if !cold_start? && !state_deferred? && dcall(:should_check_bedroom_pc?, false)
          return progress_event("starter_bedroom_pc_potion", "Check bedroom PC", drecord(:BEDROOM_PC_EVENT, {}).merge("map_id" => map_id), "story")
        end
        return adapter_goal("starter_room_rail", "Use bedroom stairs")
      end

      if map_id.to_i == player_house.to_i && !starter_clothes_ready?
        record = drecord(:STARTER_CLOTHES_EVENT, {}).merge("map_id" => map_id)
        return progress_event("starter_get_clothes", "Get dressed", record, "story")
      end

      return adapter_goal("player_house_exit_rail", "Exit downstairs") if Array(house_ids).map(&:to_i).include?(map_id.to_i)

      transfer = house_exit_transfer(map_id)
      return progress_transfer("starter_exit_house", "Exit downstairs", transfer, "travel") if transfer
      record = {
        "key" => "#{map_id}:house_exit:fallback",
        "map_id" => map_id,
        "event_name" => "House exit",
        "x" => 7,
        "y" => 10,
        "trigger" => 1,
        "destination_map_id" => dconst(:PALLET_TOWN_MAP_ID, 42)
      }
      progress_transfer("starter_exit_house", "Exit downstairs", record, "travel")
    rescue
      adapter_goal("starter_house", "Get dressed")
    end

    def bedroom_outfit_goal(map_id, snap)
      return nil if starter_clothes_ready?
      map = current_map_data
      outfits = Array(map && map["items"]).select do |record|
        record.is_a?(Hash) && record["x"] && record["y"] &&
          record["args"].to_s =~ /FAVORITEOUTFIT|CLOTHES|OUTFIT/i
      end
      record = outfits.min_by { |entry| manhattan(entry, snap) }
      return nil unless record
      record = stringify_hash(record).merge(
        "map_id" => map_id,
        "frontier_kind" => "item",
        "frontier_key" => "bedroom_outfit:#{map_id}:#{record["event_id"] || record["x"]}:#{record["y"]}"
      )
      progress_event("starter_get_bedroom_clothes_#{map_id}", "Get dressed", record, "story")
    rescue
      nil
    end

    def house_exit_transfer(map_id)
      if cold_start?
        fallback = dcall(:fallback_house_to_pallet_transfer, nil)
        return stringify_hash(fallback).merge("map_id" => map_id) if fallback
      end
      transfer = dcall(:house_to_pallet_transfer, nil)
      return stringify_hash(transfer).merge("map_id" => map_id) if transfer
      map = current_map_data
      pallet = dconst(:PALLET_TOWN_MAP_ID, 42)
      record = Array(map && map["transfers"]).find { |tr| tr.is_a?(Hash) && tr["destination_map_id"].to_i == pallet.to_i }
      record ? stringify_hash(record).merge("map_id" => map_id) : nil
    rescue
      nil
    end

    def pallet_goal(map_id)
      if !starter_obtained?
        unless game_switch?(96) || game_switch?(898)
          return progress_event("starter_meet_rival", "Meet rival outside", drecord(:PALLET_RIVAL_EVENT, {}).merge("map_id" => map_id), "story")
        end
        return adapter_goal("pallet_north_rail", "Find Professor Oak") unless game_switch?(898)
        return adapter_goal("pallet_north_rail", "Professor Oak trigger")
      end
      if game_switch?(61) && !game_switch?(220) && !trainer_has_pokedex?
        return adapter_goal("pallet_north_rail", "Go to Viridian Mart")
      end
      if game_switch?(220) && !trainer_has_pokedex?
        record = drecord(:PALLET_LAB_TRANSFER, {}).merge("map_id" => map_id, "destination_map_id" => preferred_lab_map_id)
        return progress_transfer("oak_parcel_return_lab", "Return to Professor Oak", record, "travel")
      end
      return adapter_goal("pallet_north_rail", "Head toward Viridian City") if trainer_has_pokedex?
      nil
    end

    def route1_goal(map_id)
      if game_switch?(220) && !trainer_has_pokedex?
        return adapter_goal("route1_south_rail", "Return to Pallet Town")
      end
      if game_switch?(61) || trainer_has_pokedex?
        label = trainer_has_pokedex? ? "Go to Viridian City" : "Go to Viridian Mart"
        return adapter_goal("route1_north_rail", label)
      end
      nil
    end

    def viridian_goal(map_id)
      if game_switch?(220) && !trainer_has_pokedex?
        return adapter_goal("viridian_south_rail", "Return to Professor Oak")
      end
      if game_switch?(61) && !trainer_has_pokedex?
        return progress_transfer("viridian_enter_mart", "Enter Viridian Mart", drecord(:VIRIDIAN_MART_TRANSFER, {}).merge("map_id" => map_id), "travel")
      end
      if trainer_has_pokedex?
        return adapter_goal("viridian_route2_rail", "Head to Route 2")
      end
      nil
    end

    def mart_goal(map_id)
      if game_switch?(61) && !game_switch?(220) && !trainer_has_pokedex?
        return progress_event("oak_parcel_get", "Get Oak's Parcel", drecord(:VIRIDIAN_MART_CLERK, {}).merge("map_id" => map_id), "story")
      end
      if game_switch?(220) || trainer_has_pokedex?
        return progress_transfer("viridian_mart_exit", "Leave Viridian Mart", drecord(:VIRIDIAN_MART_EXIT, {}).merge("map_id" => map_id), "travel")
      end
      nil
    end

    def oak_lab_goal(map_id)
      if game_switch?(220) && !trainer_has_pokedex?
        return progress_event("oak_parcel_deliver", "Deliver Oak's Parcel", drecord(:OAK_EVENT, {}).merge("map_id" => map_id), "story")
      end
      return adapter_goal("oak_lab", "Oak lab story") unless trainer_has_pokedex?
      record = drecord(:LAB_EXIT_TRANSFER, {}).merge("map_id" => map_id, "key" => "#{map_id}:lab_exit:42")
      progress_transfer("oak_lab_exit", "Exit Oak's lab", record, "travel")
    rescue
      adapter_goal("oak_lab", "Oak lab story")
    end

    def route2_south_goal(map_id)
      return nil unless trainer_has_pokedex?
      progress_transfer("route2_forest_gate", "Enter Viridian Forest gate", drecord(:ROUTE_2_FOREST_GATE_TRANSFER, {}).merge("map_id" => map_id), "travel")
    end

    def forest_south_gate_goal(map_id)
      return nil unless trainer_has_pokedex?
      progress_transfer("forest_south_gate_north", "Enter Viridian Forest", drecord(:FOREST_SOUTH_GATE_NORTH_TRANSFER, {}).merge("map_id" => map_id), "travel")
    end

    def forest_goal(map_id)
      return nil unless trainer_has_pokedex?
      objective("forest_cross", "travel", "Cross Viridian Forest")
      adapter_goal("forest_cross_rail", "Cross Viridian Forest", "target_kind" => "travel", "score" => 230)
    end

    def forest_north_gate_goal(map_id)
      return nil unless trainer_has_pokedex?
      progress_transfer("forest_leave", "Leave Viridian Forest", drecord(:FOREST_NORTH_GATE_EXIT, {}).merge("map_id" => map_id), "travel")
    end

    def route2_north_goal(map_id)
      return nil unless trainer_has_pokedex?
      adapter_goal("route2_pewter_rail", "Head to Pewter City")
    end

    def pewter_goal(map_id)
      return nil unless trainer_has_pokedex?
      return nil if first_badge_obtained?
      adapter_goal("pewter_gym_rail", "Challenge Pewter Gym")
    end

    def pewter_gym_goal(map_id)
      return nil unless trainer_has_pokedex?
      return nil if first_badge_obtained?
      progress_event("brock", "Battle Brock", drecord(:BROCK_EVENT, {}).merge("map_id" => map_id), "battle")
    end

    def progress_edge(id, label, point, dir, map_id, type)
      record = {
        "key" => id,
        "map_id" => map_id,
        "x" => point["x"] || point[:x],
        "y" => point["y"] || point[:y],
        "event_name" => label,
        "nav_key" => "progress:#{id}:#{map_id}:#{point["x"] || point[:x]}:#{point["y"] || point[:y]}"
      }
      objective(id, type, label)
      adapter_goal(
        "auto_edge_rail",
        label,
        "record" => stringify_hash(record).merge("exit_dir" => dir),
        "target_kind" => type,
        "exit_dir" => dir,
        "score" => 190
      )
    end

    def progress_transfer(id, label, record, type)
      record = stringify_hash(record)
      if record["x"] && record["y"] && record["trigger"].to_i == 1
        objective(id, type, label)
        return adapter_goal(
          "auto_transfer_rail",
          label,
          "record" => record,
          "target_kind" => type,
          "score" => 185
        )
      end
      progress_goal(id, label, record, type).merge("include_adjacent" => false)
    end

    def progress_event(id, label, record, type)
      progress_goal(id, label, record, type)
    end

    def progress_goal(id, label, record, type)
      objective(id, type, label)
      record = stringify_hash(record)
      {
        "kind" => "progress",
        "target_kind" => type,
        "score" => 180,
        "label" => label,
        "map_id" => record["map_id"] || current_map_id,
        "x" => record["x"],
        "y" => record["y"],
        "record" => record
      }
    end

    def frontier_goal(map, snap)
      return nil unless defined?(AutoplayBot::Config) && AutoplayBot::Config.frontier_explore?
      transfers = Array(map && map["transfers"]).select do |record|
        next false unless record.is_a?(Hash) && record["x"] && record["y"]
        next false if state_memory_ready? && AutoplayBot::State.respond_to?(:transfer_visited?) && AutoplayBot::State.transfer_visited?(record["key"])
        next false if target_done_or_failed?(record, "transfer")
        next false if attempts_exhausted?(record, "transfer")
        true
      end
      record = transfers.min_by { |tr| manhattan(tr, snap) }
      return nil unless record
      progress_transfer("frontier_#{record["key"]}", "Explore #{record["event_name"] || "transfer"}", stringify_hash(record).merge("map_id" => snap["map_id"]), "frontier_explore")
    rescue
      nil
    end

    def adapter_tick(goal, snap)
      set_mode("story")
      status_once("adapter #{goal["adapter"]}")
      if defined?(AutoplayBot::Director)
        case goal["adapter"].to_s
        when "starter_room_rail"
          return starter_room_rail_tick(snap)
        when "player_house_exit_rail"
          return player_house_exit_rail_tick(snap)
        when "pallet_north_rail"
          return pallet_north_rail_tick(snap)
        when "route1_north_rail"
          return route1_north_rail_tick(snap)
        when "route1_south_rail"
          return route1_south_rail_tick(snap)
        when "viridian_route2_rail"
          return viridian_route2_rail_tick(snap)
        when "viridian_south_rail"
          return viridian_south_rail_tick(snap)
        when "forest_cross_rail"
          return forest_cross_rail_tick(snap)
        when "route2_pewter_rail"
          return route2_pewter_rail_tick(snap)
        when "pewter_gym_rail"
          return pewter_gym_rail_tick(snap)
        when "auto_edge_rail"
          return auto_edge_rail_tick(goal, snap)
        when "auto_transfer_rail"
          return auto_transfer_rail_tick(goal, snap)
        when "wild_grass_patrol"
          return wild_grass_patrol_tick(snap)
        when "unknown_map_wander"
          return unknown_map_wander_tick(snap)
        when "pause_menu_action"
          return pause_menu_action_tick(goal, snap)
        when "starter_house"
          return AutoplayBot::Director.starter_house_tick if AutoplayBot::Director.respond_to?(:starter_house_tick)
        when "oak_lab"
          return AutoplayBot::Director.oak_lab_story_tick if AutoplayBot::Director.respond_to?(:oak_lab_story_tick)
        end
      end
      false
    rescue => e
      AutoplayBot.log("adapter failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def pause_menu_action_tick(goal, snap)
      action_text = goal["menu_action"].to_s
      return false if action_text.empty?
      action = action_text.to_sym
      label = pause_menu_action_label(action)
      mode = case action
             when :heal then "recovery"
             when :kuray_shop then "shop"
             else "menu"
             end
      set_mode(mode)
      if snap && snap["scene"].to_s == "map"
        AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
        Navigator.reset!("pause menu #{action_text}") if defined?(AutoplayBot::Navigator)
      end

      pending = if defined?(AutoplayBot::MenuTools) && AutoplayBot::MenuTools.respond_to?(:pending_action)
                  AutoplayBot::MenuTools.pending_action
                else
                  nil
                end
      if pending
        if pending.to_sym == action
          maybe_retry_pause_menu_open(action, snap)
          status_once("menu: #{label} pending")
        else
          status_once("menu: wait #{pause_menu_action_label(pending)}")
        end
        return true
      end

      unless pause_menu_goal_allowed?(snap) && pause_menu_action_available?(action)
        mark_menu_action_unavailable!(action, snap)
        @active_goal = nil
        status_once("menu: #{label} unavailable")
        return fallback_after_menu_unavailable_tick(action, snap)
      end

      reason = goal["menu_reason"] || goal["label"] || label
      opened = defined?(AutoplayBot::MenuTools) &&
               AutoplayBot::MenuTools.respond_to?(:open_pause_menu) &&
               AutoplayBot::MenuTools.open_pause_menu(action, reason)
      if opened
        frame = snap["frame"].to_i
        @last_pause_menu_goal_frame = frame
        @last_pause_pc_goal_frame = frame if action == :pc
        @last_bag_goal_frame = frame if action == :bag
        @last_pokemon_goal_frame = frame if action == :pokemon
        status_once("menu: open #{label}")
        return true
      end

      @active_goal = nil
      status_once("menu: #{label} failed")
      true
    rescue => e
      AutoplayBot.log("pause menu adapter failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      @active_goal = nil
      true
    end

    def maybe_retry_pause_menu_open(action, snap)
      return unless snap && snap["scene"].to_s == "map"
      return unless defined?(AutoplayBot::MenuTools) && AutoplayBot::MenuTools.respond_to?(:pending_age)
      age = AutoplayBot::MenuTools.pending_age.to_i
      if age > 150 && AutoplayBot::MenuTools.respond_to?(:note_menu_action_blocked!)
        AutoplayBot::MenuTools.note_menu_action_blocked!(action, "menu did not open")
        @active_goal = nil
        return
      end
      return if age < 36
      frame = snap["frame"].to_i
      @last_pause_menu_retry_frame ||= -9999
      return if frame - @last_pause_menu_retry_frame.to_i < 45
      @last_pause_menu_retry_frame = frame
      AutoplayBot::InputQueue.tap(:BACK, 2) if defined?(AutoplayBot::InputQueue)
    rescue
      nil
    end

    def mark_menu_action_unavailable!(action, snap)
      @menu_action_unavailable_until ||= {}
      frame = snap && snap["frame"] ? snap["frame"].to_i : SceneObserver.frame_count.to_i
      cooldown = action.to_sym == :kuray_shop ? 1800 : 600
      @menu_action_unavailable_until[action.to_sym] = frame + cooldown
      if defined?(AutoplayBot::MenuTools) &&
         AutoplayBot::MenuTools.respond_to?(:note_menu_action_blocked!)
        AutoplayBot::MenuTools.note_menu_action_blocked!(action, "unavailable from bot core")
      end
    rescue
      nil
    end

    def menu_action_temporarily_blocked?(action, snap = nil)
      blocks = @menu_action_unavailable_until
      return false unless blocks.is_a?(Hash)
      frame = snap && snap["frame"] ? snap["frame"].to_i : SceneObserver.frame_count.to_i
      blocks.delete_if { |_key, until_frame| until_frame.to_i <= frame }
      until_frame = blocks[action.to_sym]
      until_frame && until_frame.to_i > frame
    rescue
      false
    end

    def fallback_after_menu_unavailable_tick(action, snap)
      if action.to_sym == :kuray_shop
        grass = wild_capture_supplies_ready? ? wild_capture_goal(snap) : nil
        return wild_grass_patrol_tick(snap) if grass
        return fallback_explore_tick(snap, "shop unavailable", false)
      end
      false
    rescue
      false
    end

    def wild_grass_patrol_tick(snap)
      set_mode("catch")
      return true unless snap && snap["scene"].to_s == "map"
      unless wild_capture_supplies_ready?
        return grass_no_supplies_tick(snap)
      end
      return true if fallback_immediate_target_tick(snap, true)

      @grass_patrol_state ||= {}
      key = snap["map_id"].to_i
      state = @grass_patrol_state[key] ||= {
        "dir" => nil,
        "steps" => 0,
        "last_pos" => nil,
        "last_progress_frame" => snap["frame"].to_i,
        "blocked_dirs" => {}
      }

      if cave_encounter_map? && cave_floor_tile?(snap["x"], snap["y"]) && !grass_tile?(snap["x"], snap["y"])
        return cave_encounter_patrol_tick(snap, state)
      end

      track_grass_progress!(snap, state)
      purge_grass_dir_blocks!(snap, state)

      if grass_tile?(snap["x"], snap["y"])
        if grass_patrol_abort_needed?(snap, state)
          return grass_patrol_abort_tick(snap, state, "grass patrol stalled")
        end
        return grass_patrol_step(snap, state)
      end

      if grass_state_stalled?(snap, state, state["dir"])
        block_grass_dir!(snap, state, state["dir"], "grass_seek_stalled")
      end

      dir = adjacent_grass_dir(snap, state)
      if [2, 4, 6, 8].include?(dir)
        @rail_action = "grass: step in #{dir_label(dir)}"
        AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
        AutoplayBot::InputQueue.hold_dir(dir, rail_hold_frames(dir)) if defined?(AutoplayBot::InputQueue)
        state["dir"] = dir
        state["steps"] = 0
        return true
      end

      path = cached_path_to_nearby_grass(snap)
      if path && !path.empty?
        dir = path.first.to_i
        unless rail_dir_passable?(dir)
          block_grass_dir!(snap, state, dir, "enter_blocked")
          @grass_path_cache = nil
          return grass_entry_recover_tick(snap, state, "grass enter blocked")
        end
        if grass_dir_blocked?(state, dir, snap)
          remember_rail_block!(snap, dir, "grass_dir_blocked")
          @grass_path_cache = nil
          return grass_entry_recover_tick(snap, state, "grass enter blocked")
        end
        if grass_state_stalled?(snap, state, dir)
          block_grass_dir!(snap, state, dir, "enter_stalled")
          @grass_path_cache = nil
          return grass_entry_recover_tick(snap, state, "grass enter stuck")
        end
        frames = rail_hold_path_frames(path, 5)
        @rail_action = "grass: enter #{dir_label(dir)} #{path.length} steps"
        AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
        AutoplayBot::InputQueue.hold_dir(dir, frames) if defined?(AutoplayBot::InputQueue)
        state["dir"] = dir
        return true
      end

      fallback_explore_tick(snap, "grass no path", true)
    rescue => e
      @rail_action = "grass: error #{e.class}"
      AutoplayBot.log("grass patrol failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def fallback_explore_tick(snap, reason = "explore", prefer_grass = true, forced_mode = nil)
      set_mode(forced_mode || (prefer_grass ? "catch" : "frontier_explore"))
      return true unless snap && snap["scene"].to_s == "map"
      return true if fallback_immediate_target_tick(snap, prefer_grass)

      if prefer_grass && !grass_tile?(snap["x"], snap["y"])
        return true if fallback_seek_encounter_surface_tick(snap, reason)
      end

      if prefer_grass && grass_tile?(snap["x"], snap["y"])
        @grass_patrol_state ||= {}
        grass_state = @grass_patrol_state[snap["map_id"].to_i] ||= {
          "dir" => nil,
          "steps" => 0,
          "last_pos" => nil,
          "last_progress_frame" => snap["frame"].to_i,
          "blocked_dirs" => {}
        }
        track_grass_progress!(snap, grass_state)
        purge_grass_dir_blocks!(snap, grass_state)
        return grass_patrol_step(snap, grass_state)
      end

      @fallback_explore_state ||= {}
      key = snap["map_id"].to_i
      state = @fallback_explore_state[key] ||= {
        "dir" => nil,
        "steps" => 0,
        "last_pos" => nil,
        "last_progress_frame" => snap["frame"].to_i,
        "blocked_dirs" => {}
      }
      purge_fallback_dir_blocks!(snap, state)

      current_pos = [snap["map_id"], snap["x"], snap["y"]]
      if state["last_pos"] != current_pos
        state["last_pos"] = current_pos
        state["last_progress_frame"] = snap["frame"].to_i
        state["steps"] = state["steps"].to_i + 1
      end

      dir = state["dir"].to_i
      if fallback_state_stalled?(snap, state, dir)
        block_fallback_dir!(snap, state, dir)
        dir = nil
      end
      if ![2, 4, 6, 8].include?(dir) ||
         state["steps"].to_i >= fallback_explore_commit_steps ||
         fallback_dir_blocked?(state, dir, snap) ||
         !rail_dir_passable?(dir) ||
         fallback_loop_risk?(dir)
        dir = choose_fallback_explore_dir(snap, state, prefer_grass)
        state["dir"] = dir
        state["steps"] = 0
      end

      if [2, 4, 6, 8].include?(dir) && rail_dir_passable?(dir)
        @rail_action = @fallback_target_action || "#{reason}: step #{dir_label(dir)}"
        AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
        AutoplayBot::InputQueue.hold_dir(dir, rail_hold_frames(dir)) if defined?(AutoplayBot::InputQueue)
        return true
      end

      return true if field_obstacle_use_tick(snap, reason)

      @rail_action = "#{reason}: no passable step"
      clear_dir = fallback_clear_blocks_dir(snap, state)
      if [2, 4, 6, 8].include?(clear_dir)
        @rail_action = "#{reason}: unblock #{dir_label(clear_dir)}"
        AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
        AutoplayBot::InputQueue.hold_dir(clear_dir, rail_hold_frames(clear_dir)) if defined?(AutoplayBot::InputQueue)
        state["dir"] = clear_dir
        state["steps"] = 0
        return true
      end
      AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
      true
    rescue => e
      @rail_action = "#{reason}: fallback error #{e.class}"
      AutoplayBot.log("fallback explore failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def fallback_seek_encounter_surface_tick(snap, reason = "seek")
      return false unless snap && snap["scene"].to_s == "map"
      if cave_encounter_map? && cave_floor_tile?(snap["x"], snap["y"])
        @grass_patrol_state ||= {}
        state = @grass_patrol_state[snap["map_id"].to_i] ||= {
          "dir" => nil,
          "steps" => 0,
          "last_pos" => nil,
          "last_progress_frame" => snap["frame"].to_i,
          "blocked_dirs" => {}
        }
        return cave_encounter_patrol_tick(snap, state)
      end

      @grass_seek_state ||= {}
      state = @grass_seek_state[snap["map_id"].to_i] ||= {
        "dir" => nil,
        "steps" => 0,
        "last_pos" => nil,
        "last_progress_frame" => snap["frame"].to_i,
        "blocked_dirs" => {}
      }
      track_grass_progress!(snap, state)
      purge_grass_dir_blocks!(snap, state)
      if grass_state_stalled?(snap, state, state["dir"])
        block_grass_dir!(snap, state, state["dir"], "grass_seek_stalled")
      end

      dir = adjacent_grass_dir(snap, state)
      if [2, 4, 6, 8].include?(dir)
        @rail_action = "#{reason}: enter grass #{dir_label(dir)}"
        AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
        AutoplayBot::InputQueue.hold_dir(dir, rail_hold_frames(dir)) if defined?(AutoplayBot::InputQueue)
        state["dir"] = dir
        state["steps"] = 0
        return true
      end

      path = cached_path_to_nearby_grass(snap)
      if path && !path.empty?
        dir = path.first.to_i
        if [2, 4, 6, 8].include?(dir) && rail_dir_passable?(dir) && !grass_dir_blocked?(state, dir, snap)
          @rail_action = "#{reason}: seek grass #{dir_label(dir)} #{path.length}"
          AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
          AutoplayBot::InputQueue.hold_dir(dir, rail_hold_path_frames(path, 6)) if defined?(AutoplayBot::InputQueue)
          state["dir"] = dir
          state["steps"] = 0
          return true
        end
        @grass_path_cache = nil if [2, 4, 6, 8].include?(dir)
      end
      false
    rescue => e
      @rail_action = "#{reason}: seek grass error #{e.class}"
      false
    end

    def fallback_immediate_target_tick(snap, prefer_grass = true)
      return false unless snap && snap["scene"].to_s == "map"
      return false if snap["moving"] || snap["transfer"] || snap["cutscene"] || snap["raw_battle"]
      goals = immediate_interaction_goals(snap, prefer_grass)
      goal = best_unknown_candidate(goals, snap)
      return false unless goal
      record = goal["record"].is_a?(Hash) ? goal["record"] : goal
      return false unless immediate_interaction_reachable_now?(record, snap)
      @active_goal = goal
      @active_goal_key = Navigator.goal_key(goal) if defined?(AutoplayBot::Navigator)
      @last_goal_choice_frame = snap["frame"]
      @rail_action = "nearby #{goal["target_kind"] || goal["kind"]}: #{goal["label"]}"
      AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
      handled = Navigator.follow(goal, snap)
      unless handled
        mark_local_target_failed(record, goal["target_kind"] || goal["kind"], "nearby_no_action")
        @active_goal = nil
        @active_goal_key = nil
      end
      handled
    rescue => e
      @rail_action = "nearby target error #{e.class}"
      false
    end

    def immediate_interaction_goals(snap, prefer_grass = true)
      radius = prefer_grass ? 2 : 3
      goals = live_interaction_goals(snap, radius)
      map = current_map_data
      [
        ["items", "nearby_collect", "item", 165],
        ["field_resources", "nearby_collect", "resource", 162],
        ["trainers", "battle", "trainer", 158],
        ["gifts", "nearby_collect", "gift", 148],
        ["wild_statics", "nearby_collect", "static", 145],
        ["npcs", "nearby_npc", "npc", 92]
      ].each do |key, kind, target_kind, score|
        Array(map && map[key]).each do |record|
          next unless record.is_a?(Hash) && record["x"] && record["y"]
          next if target_done_or_failed?(record, target_kind)
          next if attempts_exhausted?(record, target_kind)
          dist = manhattan(record, snap)
          next if dist > radius
          next if target_kind == "npc" && prefer_grass && dist > 1
          goals << goal_from_record(kind, target_kind, record, score.to_i - dist)
        end
      end
      goals.compact.select do |goal|
        record = goal["record"].is_a?(Hash) ? goal["record"] : goal
        kind = (goal["target_kind"] || goal["kind"]).to_s
        next false unless record && record["x"] && record["y"]
        next false if target_done_or_failed?(record, kind)
        next false if attempts_exhausted?(record, kind)
        dist = manhattan(record, snap)
        next false if dist > radius
        next false if kind == "npc" && prefer_grass && dist > 1
        true
      end
    rescue
      []
    end

    def immediate_interaction_reachable_now?(record, snap)
      return false unless record && snap
      dist = manhattan(record, snap)
      return true if dist <= 1 && immediate_interaction_adjacent_ok?(record, snap)
      path = defined?(AutoplayBot::Navigator) && AutoplayBot::Navigator.respond_to?(:event_path) ?
               AutoplayBot::Navigator.event_path(record, 180) : nil
      path && path.length <= 1
    rescue
      false
    end

    def immediate_interaction_adjacent_ok?(record, snap)
      return false unless record && snap
      dist = manhattan(record, snap)
      return true if dist == 0 && record["trigger"].to_i == 1
      return true if dist == 0 && record["target_kind"].to_s =~ /item|resource|static|gift/
      return false if dist > 1
      if record["live_goal"]
        return false unless live_record_event_still_actionable?(record)
      end
      true
    rescue
      false
    end

    def live_record_event_still_actionable?(record)
      return true unless record && record["event_id"]
      return true unless defined?($game_map) && $game_map && $game_map.respond_to?(:events)
      event = $game_map.events && $game_map.events[record["event_id"].to_i]
      return false unless event
      return false if event.respond_to?(:erased) && event.erased
      live_event_has_meaningful_commands?(event)
    rescue
      true
    end

    def cave_encounter_patrol_tick(snap, state)
      track_grass_progress!(snap, state)
      purge_grass_dir_blocks!(snap, state)

      if cave_patrol_abort_needed?(snap, state)
        return cave_patrol_recover_tick(snap, state, "cave patrol stalled")
      end

      dir = state["dir"].to_i
      if cave_state_stalled?(snap, state, dir)
        block_grass_dir!(snap, state, dir, "cave_stalled")
        return cave_patrol_recover_tick(snap, state, "cave blocked #{dir_label(dir)}")
      end
      if !cave_step_passable?(snap, dir) ||
         state["steps"].to_i >= cave_patrol_commit_steps ||
         grass_loop_risk?(dir)
        dir = choose_cave_patrol_dir(snap, state)
        state["dir"] = dir
        state["steps"] = 0
      end

      if cave_step_passable?(snap, dir)
        @rail_action = "cave: patrol #{dir_label(dir)} open #{cave_target_open_count(snap, dir)}"
        AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
        AutoplayBot::InputQueue.hold_dir(dir, cave_hold_frames(dir)) if defined?(AutoplayBot::InputQueue)
        return true
      end

      clear_dir = grass_clear_blocks_dir(snap, state)
      if [2, 4, 6, 8].include?(clear_dir) && cave_step_passable?(snap, clear_dir)
        @rail_action = "cave: unblock #{dir_label(clear_dir)}"
        AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
        AutoplayBot::InputQueue.hold_dir(clear_dir, cave_hold_frames(clear_dir)) if defined?(AutoplayBot::InputQueue)
        state["dir"] = clear_dir
        state["steps"] = 0
        return true
      end

      fallback_explore_tick(snap, "cave encounter no step", false, "catch")
    rescue => e
      @rail_action = "cave: encounter error #{e.class}"
      false
    end

    def cave_step_passable?(snap, dir)
      return false unless snap && [2, 4, 6, 8].include?(dir.to_i)
      if defined?(AutoplayBot::Navigator) &&
         AutoplayBot::Navigator.respond_to?(:live_event_blocked_from_player?) &&
         AutoplayBot::Navigator.live_event_blocked_from_player?(dir)
        return false
      end
      cave_edge_passable_from?(snap["x"].to_i, snap["y"].to_i, dir)
    rescue
      false
    end

    def choose_cave_patrol_dir(snap, state)
      last = state["dir"].to_i
      reverse = reverse_dir_for_rail(last)
      dirs = passable_cave_dirs(snap, state)
      return nil if dirs.empty?
      current_open = dirs.length
      dirs.max_by do |dir|
        score = 0
        score += 8 if dir == last && current_open <= 2
        score -= 10 if dir == last && current_open > 2
        score -= 18 if grass_dir_blocked?(state, dir, snap)
        score -= 4 if reverse && dir == reverse && current_open > 1
        score -= 22 if cave_dead_end_dir?(snap, dir) && current_open > 1
        score += cave_target_open_count(snap, dir) * 7
        score += 12 if grass_loop_breaking_dir?(dir)
        score += tile_novelty_score(snap, dir)
        score += directional_bias_score(snap, dir)
        score
      end
    rescue
      [8, 6, 2, 4].find { |dir| cave_step_passable?(snap, dir) }
    end

    def cave_patrol_commit_steps
      speed = defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.respond_to?(:game_speed_multiplier) ? AutoplayBot::Runtime.game_speed_multiplier : 1
      return 3 if speed.to_i >= 7
      return 4 if speed.to_i >= 3
      4
    rescue
      4
    end

    def cave_hold_frames(dir)
      [[rail_hold_frames(dir).to_i, 4].max, 14].min
    rescue
      8
    end

    def cave_state_stalled?(snap, state, dir = nil)
      dir = (dir || state["dir"]).to_i
      return false unless [2, 4, 6, 8].include?(dir)
      return false if snap["moving"]
      last = state["last_progress_frame"]
      return false unless last
      snap["frame"].to_i - last.to_i >= cave_stall_frame_limit
    rescue
      false
    end

    def cave_stall_frame_limit
      movement_stall_frame_limit(18)
    rescue
      18
    end

    def cave_patrol_abort_needed?(snap, state)
      return false unless snap && state
      return true if state["stall_count"].to_i >= 2
      blocks = state["blocked_dirs"]
      blocks.is_a?(Hash) && blocks.length >= 2 && state["stall_count"].to_i >= 1
    rescue
      false
    end

    def cave_patrol_recover_tick(snap, state, reason = "cave stuck")
      dir = choose_cave_recover_dir(snap, state)
      if [2, 4, 6, 8].include?(dir)
        @rail_action = "#{reason}: turn #{dir_label(dir)} open #{cave_target_open_count(snap, dir)}"
        AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
        AutoplayBot::InputQueue.hold_dir(dir, cave_hold_frames(dir)) if defined?(AutoplayBot::InputQueue)
        state["dir"] = dir
        state["steps"] = 0
        state["last_progress_frame"] = snap["frame"].to_i
        return true
      end
      state["blocked_dirs"] = {}
      state["dir"] = nil
      @active_goal = nil
      @active_goal_key = nil
      @rail_action = "#{reason}: replan cave"
      AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
      fallback_explore_tick(snap, reason, false, "catch")
    rescue => e
      @rail_action = "#{reason}: recover error #{e.class}"
      false
    end

    def choose_cave_recover_dir(snap, state)
      dirs = passable_cave_dirs(snap, state)
      return nil if dirs.empty?
      last = state["dir"].to_i
      reverse = reverse_dir_for_rail(last)
      dirs.max_by do |dir|
        score = 0
        score += 16 if dir != last
        score += 18 if reverse && dir == reverse
        score += cave_target_open_count(snap, dir) * 8
        score -= 20 if cave_dead_end_dir?(snap, dir) && dirs.length > 1
        score += 14 if grass_loop_breaking_dir?(dir)
        score += tile_novelty_score(snap, dir)
        score += directional_bias_score(snap, dir)
        score
      end
    rescue
      [8, 6, 2, 4].find { |dir| cave_step_passable?(snap, dir) }
    end

    def passable_cave_dirs(snap, state = nil)
      [8, 6, 2, 4].select do |dir|
        next false if state && grass_dir_blocked?(state, dir, snap)
        cave_step_passable?(snap, dir)
      end
    rescue
      []
    end

    def cave_dead_end_dir?(snap, dir)
      cave_target_open_count(snap, dir).to_i <= 1
    rescue
      false
    end

    def cave_target_open_count(snap, dir)
      return 0 unless snap && [2, 4, 6, 8].include?(dir.to_i)
      dx, dy = dir_delta(dir)
      nx = snap["x"].to_i + dx
      ny = snap["y"].to_i + dy
      [8, 6, 2, 4].count { |next_dir| cave_edge_passable_from?(nx, ny, next_dir) }
    rescue
      0
    end

    def cave_edge_passable_from?(x, y, dir)
      return false unless [2, 4, 6, 8].include?(dir.to_i)
      return false unless cave_floor_tile?(x, y)
      if defined?(AutoplayBot::Pathfinder) && AutoplayBot::Pathfinder.respond_to?(:passable?)
        return false unless AutoplayBot::Pathfinder.passable?(x.to_i, y.to_i, dir)
      elsif defined?($game_player) && $game_player
        return false unless $game_player.passable?(x.to_i, y.to_i, dir)
      end
      dx, dy = dir_delta(dir)
      cave_floor_tile?(x.to_i + dx, y.to_i + dy)
    rescue
      false
    end

    def fallback_explore_commit_steps
      4
    rescue
      4
    end

    def fallback_state_stalled?(snap, state, dir = nil)
      dir = (dir || state["dir"]).to_i
      return false unless [2, 4, 6, 8].include?(dir)
      return false if snap["moving"]
      last = state["last_progress_frame"]
      return false unless last
      snap["frame"].to_i - last.to_i >= fallback_stall_frame_limit
    rescue
      false
    end

    def fallback_stall_frame_limit
      movement_stall_frame_limit(30)
    rescue
      30
    end

    def block_fallback_dir!(snap, state, dir)
      dir = dir.to_i
      return unless [2, 4, 6, 8].include?(dir)
      state["blocked_dirs"] ||= {}
      state["blocked_dirs"][dir.to_s] = snap["frame"].to_i + 120
      state["dir"] = nil
      state["steps"] = fallback_explore_commit_steps
      state["last_progress_frame"] = snap["frame"].to_i
    rescue
      nil
    end

    def fallback_dir_blocked?(state, dir, snap = nil)
      blocks = state && state["blocked_dirs"]
      return false unless blocks.is_a?(Hash)
      until_frame = blocks[dir.to_i.to_s]
      return false unless until_frame
      frame = snap ? snap["frame"].to_i : SceneObserver.frame_count.to_i
      until_frame.to_i > frame
    rescue
      false
    end

    def purge_fallback_dir_blocks!(snap, state)
      blocks = state["blocked_dirs"]
      return unless blocks.is_a?(Hash) && !blocks.empty?
      frame = snap["frame"].to_i
      blocks.delete_if { |_dir, until_frame| until_frame.to_i <= frame }
    rescue
      nil
    end

    def choose_fallback_explore_dir(snap, state, prefer_grass = true)
      @fallback_target_action = nil
      dirs = [8, 6, 2, 4].select { |dir| rail_dir_passable?(dir) && !fallback_dir_blocked?(state, dir, snap) }
      return fallback_clear_blocks_dir(snap, state) if dirs.empty?
      targets = fallback_target_candidates(snap, prefer_grass ? 20 : 24, prefer_grass)
      path_dir = fallback_path_dir_to_candidates(snap, targets, state)
      return path_dir if path_dir
      target = targets.first ? [targets.first["x"], targets.first["y"]] : nil
      last = state["dir"].to_i
      reverse = reverse_dir_for_rail(last)
      dirs.max_by do |dir|
        dx, dy = dir_delta(dir)
        nx = snap["x"].to_i + dx
        ny = snap["y"].to_i + dy
        score = 0
        score += 18 if dir == last
        score -= 14 if reverse && dir == reverse
        score += 20 if loop_breaking_dir?(dir)
        score += tile_novelty_score(snap, dir)
        score += directional_bias_score(snap, dir)
        if prefer_grass
          score += 60 if grass_tile?(nx, ny)
          if target
            before = (target[0].to_i - snap["x"].to_i).abs + (target[1].to_i - snap["y"].to_i).abs
            after = (target[0].to_i - nx).abs + (target[1].to_i - ny).abs
            score += (before - after) * 8
          end
        end
        if target
          before = (target[0].to_i - snap["x"].to_i).abs + (target[1].to_i - snap["y"].to_i).abs
          after = (target[0].to_i - nx).abs + (target[1].to_i - ny).abs
          score += (before - after) * 5
        end
        score
      end
    rescue
      [8, 6, 2, 4].find { |dir| rail_dir_passable?(dir) }
    end

    def fallback_target_candidates(snap, radius = 20, prefer_grass = true)
      candidates = []
      if prefer_grass && wild_capture_supplies_ready?
        nearby_grass_targets(snap, [radius.to_i, grass_search_radius].min).first(24).each do |x, y|
          dist = (x.to_i - snap["x"].to_i).abs + (y.to_i - snap["y"].to_i).abs
          candidates << {
            "kind" => "grass",
            "x" => x.to_i,
            "y" => y.to_i,
            "score" => 130 - dist,
            "label" => "grass"
          }
        end
      end

      map = current_map_data
      [
        ["trainers", "trainer", 152],
        ["items", "item", 148],
        ["field_resources", "resource", 146],
        ["npcs", "npc", 92],
        ["transfers", "transfer", 78]
      ].each do |key, kind, base_score|
        Array(map && map[key]).each do |record|
          next unless record.is_a?(Hash) && record["x"] && record["y"]
          next if target_done_or_failed?(record, kind)
          next if attempts_exhausted?(record, kind)
          dist = manhattan(record, snap)
          next if dist > radius.to_i
          next if prefer_grass && dist > 2
          candidates << {
            "kind" => kind,
            "x" => record["x"].to_i,
            "y" => record["y"].to_i,
            "score" => base_score.to_i - dist,
            "label" => record["event_name"] || kind
          }
        end
      end
      live_interaction_goals(snap, [radius.to_i, 14].min).each do |goal|
        record = goal["record"].is_a?(Hash) ? goal["record"] : goal
        next unless record && record["x"] && record["y"]
        kind = goal["target_kind"] || goal["kind"]
        next if target_done_or_failed?(record, kind)
        next if attempts_exhausted?(record, kind)
        dist = manhattan(record, snap)
        next if dist > radius.to_i
        next if prefer_grass && dist > 2
        candidates << {
          "kind" => kind,
          "x" => record["x"].to_i,
          "y" => record["y"].to_i,
          "score" => goal["score"].to_i - dist,
          "label" => record["event_name"] || kind
        }
      end
      candidates.sort_by do |entry|
        dist = (entry["x"].to_i - snap["x"].to_i).abs + (entry["y"].to_i - snap["y"].to_i).abs
        [-entry["score"].to_i, dist]
      end
    rescue
      []
    end

    def fallback_path_dir_to_candidates(snap, candidates, state = nil)
      started = botcore_now
      Array(candidates).first(fallback_probe_limit).each do |candidate|
        break if botcore_now - started.to_f > fallback_probe_seconds
        target = [candidate["x"].to_i, candidate["y"].to_i]
        dir = fallback_path_dir_to_target(snap, target, state, candidate["kind"].to_s != "grass")
        next unless [2, 4, 6, 8].include?(dir)
        @fallback_target_action = "explore #{candidate["kind"]} #{dir_label(dir)}"
        return dir
      end
      nil
    rescue
      nil
    end

    def fallback_probe_limit
      speed = defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.respond_to?(:game_speed_multiplier) ? AutoplayBot::Runtime.game_speed_multiplier : 1
      return 2 if speed.to_i >= 7
      return 3 if speed.to_i >= 3
      4
    rescue
      3
    end

    def fallback_probe_seconds
      speed = defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.respond_to?(:game_speed_multiplier) ? AutoplayBot::Runtime.game_speed_multiplier : 1
      speed.to_i >= 7 ? 0.012 : 0.020
    rescue
      0.016
    end

    def fallback_path_dir_to_target(snap, target, state = nil, include_approaches = true)
      return nil unless snap && target && target[0] && target[1]
      tx = target[0].to_i
      ty = target[1].to_i
      targets = [[tx, ty]]
      targets += transfer_approaches(tx, ty) if include_approaches
      path = rail_path_to_any(targets, fallback_target_path_budget(snap))
      return nil unless path && !path.empty?
      dir = path.first.to_i
      return nil unless [2, 4, 6, 8].include?(dir)
      return nil if state && fallback_dir_blocked?(state, dir, snap)
      return nil unless rail_dir_passable?(dir)
      dir
    rescue
      nil
    end

    def fallback_target_path_budget(snap)
      map_id = snap && snap["map_id"] ? snap["map_id"].to_i : current_map_id.to_i
      return 1600 if map_id == dconst(:VIRIDIAN_FOREST_MAP_ID, 491).to_i
      1100
    rescue
      1100
    end

    def fallback_clear_blocks_dir(snap, state)
      return nil unless snap && state
      blocks = state["blocked_dirs"]
      return nil unless blocks.is_a?(Hash) && !blocks.empty?
      blocks.clear
      [8, 6, 2, 4].find { |dir| rail_dir_passable?(dir) }
    rescue
      nil
    end

    def nearest_local_interaction_target(snap, radius = 16)
      map = current_map_data
      candidates = []
      [["items", 120], ["field_resources", 115], ["npcs", 80], ["trainers", 76], ["transfers", 70]].each do |key, score|
        Array(map && map[key]).each do |record|
          next unless record.is_a?(Hash) && record["x"] && record["y"]
          kind = key == "transfers" ? "transfer" : key.sub(/s$/, "")
          next if target_done_or_failed?(record, kind)
          next if attempts_exhausted?(record, kind)
          dist = manhattan(record, snap)
          next if dist > radius.to_i
          candidates << [record["x"].to_i, record["y"].to_i, score.to_i - dist, dist]
        end
      end
      best = candidates.sort_by { |entry| [-entry[2].to_i, entry[3].to_i] }.first
      best ? best[0, 2] : nil
    rescue
      nil
    end

    def field_obstacle_use_tick(snap, reason = "blocked")
      return false unless snap && snap["scene"].to_s == "map"
      dirs = [8, 6, 2, 4]
      dirs.each do |dir|
        event = field_obstacle_event_in_dir(snap, dir)
        next unless event
        event_name = event.respond_to?(:name) ? event.name.to_s : ""
        kind = field_move_target_kind(event_name)
        record = field_obstacle_record_from_event(event, snap)
        next if record && target_done_or_failed?(record, kind)
        unless field_move_available?(kind)
          mark_local_target_failed(record, kind, "missing_field_move")
          @rail_action = "#{reason}: #{field_move_label(kind)} unavailable"
          AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
          next
        end
        @rail_action = "#{reason}: #{field_move_label(kind)}"
        AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
        if defined?(AutoplayBot::InputQueue)
          AutoplayBot::InputQueue.hold_dir(dir, 2)
          AutoplayBot::InputQueue.tap_next(:USE, 2) if AutoplayBot::InputQueue.respond_to?(:tap_next)
        end
        return true
      end
      false
    rescue
      false
    end

    def field_obstacle_record_from_event(event, snap)
      return nil unless event && snap
      event_id = event.respond_to?(:id) ? event.id : event.object_id
      event_name = event.respond_to?(:name) ? event.name.to_s : "field obstacle"
      {
        "key" => "field:#{snap["map_id"]}:#{event_id}:#{event.x}:#{event.y}",
        "map_id" => snap["map_id"],
        "event_id" => event_id,
        "event_name" => event_name,
        "x" => event.x,
        "y" => event.y,
        "trigger" => 0
      }
    rescue
      nil
    end

    def field_obstacle_event_in_dir(snap, dir)
      return nil unless defined?($game_map) && $game_map && $game_map.respond_to?(:events)
      dx, dy = dir_delta(dir)
      tx = snap["x"].to_i + dx
      ty = snap["y"].to_i + dy
      events = $game_map.events ? $game_map.events.values : []
      events.find { |event| field_obstacle_event?(event) && event.x.to_i == tx && event.y.to_i == ty }
    rescue
      nil
    end

    def nearest_visible_grass_target(snap, radius = 12)
      targets = nearby_grass_targets(snap, radius.to_i)
      targets && targets.first
    rescue
      nil
    end

    def fallback_loop_risk?(dir)
      return false unless defined?(AutoplayBot::Navigator) && AutoplayBot::Navigator.respond_to?(:loop_axis)
      axis = AutoplayBot::Navigator.loop_axis
      return [4, 6].include?(dir.to_i) if axis == :horizontal
      return [8, 2].include?(dir.to_i) if axis == :vertical
      false
    rescue
      false
    end

    def grass_patrol_step(snap, state)
      dir = state["dir"].to_i
      if grass_state_stalled?(snap, state, dir)
        block_grass_dir!(snap, state, dir, "patrol_stalled")
        dir = nil
      end
      if !grass_step_passable?(snap, dir) ||
         state["steps"].to_i >= grass_patrol_commit_steps ||
         grass_loop_risk?(dir)
        dir = choose_grass_patrol_dir(snap, state)
        state["dir"] = dir
        state["steps"] = 0
      end

      if grass_step_passable?(snap, dir)
        @rail_action = "grass: patrol #{dir_label(dir)}"
        AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
        AutoplayBot::InputQueue.hold_dir(dir, rail_hold_frames(dir)) if defined?(AutoplayBot::InputQueue)
        return true
      end

      exit_dir = passable_non_grass_dir(snap, state)
      if exit_dir
        @rail_action = "grass: reset edge #{dir_label(exit_dir)}"
        AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
        AutoplayBot::InputQueue.hold_dir(exit_dir, rail_hold_frames(exit_dir)) if defined?(AutoplayBot::InputQueue)
        state["dir"] = reverse_dir_for_rail(exit_dir)
        state["steps"] = 0
        return true
      end

      clear_dir = grass_clear_blocks_dir(snap, state)
      if [2, 4, 6, 8].include?(clear_dir)
        @rail_action = "grass: unblock #{dir_label(clear_dir)}"
        AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
        AutoplayBot::InputQueue.hold_dir(clear_dir, rail_hold_frames(clear_dir)) if defined?(AutoplayBot::InputQueue)
        state["dir"] = clear_dir
        state["steps"] = 0
        return true
      end

      stir_dir = grass_stir_dir(snap, state)
      if [2, 4, 6, 8].include?(stir_dir)
        @rail_action = "grass: stir #{dir_label(stir_dir)}"
        AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
        AutoplayBot::InputQueue.hold_dir(stir_dir, rail_hold_frames(stir_dir)) if defined?(AutoplayBot::InputQueue)
        state["dir"] = stir_dir
        state["steps"] = 0
        state["last_progress_frame"] = snap["frame"].to_i
        return true
      end

      @rail_action = "grass: wait in patch"
      AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
      true
    rescue
      false
    end

    def track_grass_progress!(snap, state)
      state["blocked_dirs"] ||= {}
      frame = snap["frame"].to_i
      current_pos = [snap["map_id"], snap["x"], snap["y"]]
      if state["last_pos"] != current_pos
        state["last_pos"] = current_pos
        state["last_progress_frame"] = frame
        state["steps"] = state["steps"].to_i + 1
        state["stall_pos"] = current_pos
        state["stall_count"] = 0
      else
        state["last_progress_frame"] ||= frame
      end
    rescue
      nil
    end

    def grass_state_stalled?(snap, state, dir = nil)
      dir = (dir || state["dir"]).to_i
      return false unless [2, 4, 6, 8].include?(dir)
      return false if snap["moving"]
      last = state["last_progress_frame"]
      return false unless last
      snap["frame"].to_i - last.to_i >= grass_stall_frame_limit
    rescue
      false
    end

    def grass_stall_frame_limit
      movement_stall_frame_limit(30)
    rescue
      30
    end

    def block_grass_dir!(snap, state, dir, reason = "stalled")
      dir = dir.to_i
      return unless [2, 4, 6, 8].include?(dir)
      state["blocked_dirs"] ||= {}
      frame = snap["frame"].to_i
      existing_until = state["blocked_dirs"][dir.to_s].to_i
      already_blocked = existing_until > frame
      state["blocked_dirs"][dir.to_s] = [existing_until, frame + grass_dir_cooldown_frames].max
      state["dir"] = nil
      state["steps"] = grass_patrol_commit_steps
      state["last_progress_frame"] = frame
      record_grass_stall!(snap, state, dir, reason)
      remember_rail_block!(snap, dir, reason) unless transient_rail_block_reason?(reason)
      @rail_action = "grass: rotate #{dir_label(dir)} #{reason}"
      AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
      if !already_blocked && grass_block_log_allowed?(snap, dir, reason) && AutoplayBot.respond_to?(:log)
        AutoplayBot.log("grass blocked #{dir_label(dir)} #{reason} at map #{snap["map_id"]} x#{snap["x"]} y#{snap["y"]}")
      end
    rescue
      nil
    end

    def record_grass_stall!(snap, state, dir, reason = "stalled")
      return unless snap && state
      return unless reason.to_s =~ /stalled|blocked|stuck/i
      pos = [snap["map_id"].to_i, snap["x"].to_i, snap["y"].to_i]
      if state["stall_pos"] == pos
        state["stall_count"] = state["stall_count"].to_i + 1
      else
        state["stall_pos"] = pos
        state["stall_count"] = 1
      end
      state["last_stall_dir"] = dir.to_i
      state["last_stall_reason"] = reason.to_s
    rescue
      nil
    end

    def grass_patrol_abort_needed?(snap, state)
      return false unless snap && state
      return true if state["abort_until"].to_i > snap["frame"].to_i
      return true if state["stall_count"].to_i >= grass_patrol_stall_limit
      blocks = state["blocked_dirs"]
      blocks.is_a?(Hash) && blocks.length >= 3 && state["stall_count"].to_i >= 2
    rescue
      false
    end

    def grass_patrol_stall_limit
      3
    rescue
      3
    end

    def grass_patrol_abort_tick(snap, state, reason = "grass stuck")
      @grass_path_cache = nil
      state["abort_until"] = snap["frame"].to_i + grass_patrol_abort_frames
      dir = passable_non_grass_dir(snap, state) ||
            choose_fallback_explore_dir(snap, { "blocked_dirs" => {} }, false)
      if [2, 4, 6, 8].include?(dir)
        @rail_action = "#{reason}: exit #{dir_label(dir)}"
        AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
        AutoplayBot::InputQueue.hold_dir(dir, rail_hold_frames(dir)) if defined?(AutoplayBot::InputQueue)
        state["dir"] = dir
        state["steps"] = 0
        state["last_progress_frame"] = snap["frame"].to_i
        return true
      end
      state["blocked_dirs"] = {}
      @active_goal = nil
      @active_goal_key = nil
      @rail_action = "#{reason}: replan"
      AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
      fallback_explore_tick(snap, reason, false)
    rescue => e
      @rail_action = "#{reason}: abort error #{e.class}"
      false
    end

    def grass_patrol_abort_frames
      speed = botcore_speed_multiplier
      return 48 if speed >= 7
      return 72 if speed >= 3
      120
    rescue
      90
    end

    def grass_block_log_allowed?(snap, dir, reason)
      @grass_block_log_frames ||= {}
      key = [snap["map_id"], snap["x"], snap["y"], dir.to_i, reason.to_s].join(":")
      frame = snap["frame"].to_i
      last = @grass_block_log_frames[key].to_i
      return false if last > 0 && frame - last < 240
      @grass_block_log_frames[key] = frame
      @grass_block_log_frames.shift while @grass_block_log_frames.length > 80
      true
    rescue
      true
    end

    def grass_dir_cooldown_frames
      speed = botcore_speed_multiplier
      return 45 if speed >= 7
      return 75 if speed >= 3
      105
    rescue
      90
    end

    def purge_grass_dir_blocks!(snap, state)
      blocks = state["blocked_dirs"]
      return unless blocks.is_a?(Hash) && !blocks.empty?
      frame = snap["frame"].to_i
      blocks.delete_if { |_dir, until_frame| until_frame.to_i <= frame }
    rescue
      nil
    end

    def grass_dir_blocked?(state, dir, snap = nil)
      blocks = state && state["blocked_dirs"]
      return false unless blocks.is_a?(Hash)
      until_frame = blocks[dir.to_i.to_s]
      return false unless until_frame
      frame = snap ? snap["frame"].to_i : SceneObserver.frame_count.to_i
      until_frame.to_i > frame
    rescue
      false
    end

    def grass_patrol_commit_steps
      speed = defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.respond_to?(:game_speed_multiplier) ? AutoplayBot::Runtime.game_speed_multiplier : 1
      return 3 if speed.to_i >= 7
      return 4 if speed.to_i >= 3
      5
    rescue
      5
    end

    def grass_step_passable?(snap, dir)
      return false unless [2, 4, 6, 8].include?(dir.to_i)
      return false unless rail_dir_passable?(dir)
      dx, dy = dir_delta(dir)
      grass_tile?(snap["x"].to_i + dx, snap["y"].to_i + dy)
    rescue
      false
    end

    def grass_clear_blocks_dir(snap, state)
      return nil unless snap && state
      blocks = state["blocked_dirs"]
      return nil unless blocks.is_a?(Hash) && !blocks.empty?
      blocks.clear
      [8, 6, 2, 4].find { |dir| grass_step_passable?(snap, dir) } ||
        [8, 6, 2, 4].find { |dir| rail_dir_passable?(dir) }
    rescue
      nil
    end

    def grass_stir_dir(snap, state)
      return nil unless snap && grass_tile?(snap["x"], snap["y"])
      last = state && state["dir"] ? state["dir"].to_i : nil
      reverse = reverse_dir_for_rail(last)
      dirs = [last, 8, 6, 2, 4, reverse].compact.uniq
      dirs.find { |dir| grass_relaxed_step_passable?(snap, dir) } ||
        dirs.find { |dir| grass_step_passable?(snap, dir) } ||
        [8, 6, 2, 4].find { |dir| rail_dir_passable?(dir) }
    rescue
      nil
    end

    def grass_relaxed_step_passable?(snap, dir)
      return false unless snap && [2, 4, 6, 8].include?(dir.to_i)
      dx, dy = dir_delta(dir)
      nx = snap["x"].to_i + dx
      ny = snap["y"].to_i + dy
      return false unless grass_tile?(nx, ny)
      if defined?(AutoplayBot::Navigator) &&
         AutoplayBot::Navigator.respond_to?(:live_event_blocked_from_player?) &&
         AutoplayBot::Navigator.live_event_blocked_from_player?(dir)
        return false
      end
      return true if rail_dir_passable?(dir)
      route_valid_tile?(nx, ny)
    rescue
      false
    end

    def choose_grass_patrol_dir(snap, state)
      last = state["dir"].to_i
      reverse = reverse_dir_for_rail(last)
      dirs = [last, 8, 6, 2, 4, reverse].compact.uniq.select do |dir|
        !grass_dir_blocked?(state, dir, snap) && grass_step_passable?(snap, dir)
      end
      return nil if dirs.empty?
      open = dirs.length
      dirs.max_by do |dir|
        score = 0
        score += 14 if dir == last && open <= 2
        score += 6 if dir == last && open > 2
        score -= 18 if grass_dir_blocked?(state, dir, snap)
        score -= 18 if reverse && dir == reverse && open > 1
        score -= 20 if state["last_stall_dir"].to_i == dir.to_i
        score += 18 if grass_loop_breaking_dir?(dir)
        score += tile_novelty_score(snap, dir)
        score += directional_bias_score(snap, dir)
        score
      end
    rescue
      [8, 6, 2, 4].find { |dir| grass_step_passable?(snap, dir) }
    end

    def grass_loop_risk?(dir)
      return false unless defined?(AutoplayBot::Navigator) && AutoplayBot::Navigator.respond_to?(:loop_axis)
      axis = AutoplayBot::Navigator.loop_axis
      return [4, 6].include?(dir.to_i) if axis == :horizontal
      return [8, 2].include?(dir.to_i) if axis == :vertical
      false
    rescue
      false
    end

    def grass_loop_breaking_dir?(dir)
      return false unless defined?(AutoplayBot::Navigator) && AutoplayBot::Navigator.respond_to?(:loop_axis)
      axis = AutoplayBot::Navigator.loop_axis
      return [8, 2].include?(dir.to_i) if axis == :horizontal
      return [4, 6].include?(dir.to_i) if axis == :vertical
      false
    rescue
      false
    end

    def grass_entry_recover_tick(snap, state, reason)
      @grass_path_cache = nil
      state["last_progress_frame"] = snap["frame"].to_i
      dir = choose_grass_entry_recover_dir(snap, state)
      if [2, 4, 6, 8].include?(dir)
        @rail_action = "#{reason}: escape #{dir_label(dir)}"
        AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
        AutoplayBot::InputQueue.hold_dir(dir, rail_hold_frames(dir)) if defined?(AutoplayBot::InputQueue)
        state["dir"] = dir
        state["steps"] = 0
        return true
      end
      fallback = choose_fallback_explore_dir(snap, { "blocked_dirs" => {} }, true)
      if [2, 4, 6, 8].include?(fallback)
        @rail_action = "#{reason}: fallback #{dir_label(fallback)}"
        AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
        AutoplayBot::InputQueue.hold_dir(fallback, rail_hold_frames(fallback)) if defined?(AutoplayBot::InputQueue)
        state["dir"] = fallback
        state["steps"] = 0
        return true
      end
      @rail_action = "#{reason}: no escape"
      AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
      true
    rescue => e
      @rail_action = "#{reason}: recover error #{e.class}"
      false
    end

    def choose_grass_entry_recover_dir(snap, state)
      dirs = [8, 2, 4, 6].select do |dir|
        rail_dir_passable?(dir) && !grass_dir_blocked?(state, dir, snap)
      end
      return nil if dirs.empty?
      target = nearest_visible_grass_target(snap, 16)
      last = state["dir"].to_i
      reverse = reverse_dir_for_rail(last)
      dirs.max_by do |dir|
        dx, dy = dir_delta(dir)
        nx = snap["x"].to_i + dx
        ny = snap["y"].to_i + dy
        score = 0
        score -= 8 if reverse && dir == reverse
        score += 18 if grass_loop_breaking_dir?(dir)
        score += 10 unless grass_tile?(nx, ny)
        score += tile_novelty_score(snap, dir)
        if target
          before = (target[0].to_i - snap["x"].to_i).abs + (target[1].to_i - snap["y"].to_i).abs
          after = (target[0].to_i - nx).abs + (target[1].to_i - ny).abs
          score += (before - after) * 5
        end
        score
      end
    rescue
      [8, 2, 4, 6].find { |dir| rail_dir_passable?(dir) }
    end

    def passable_non_grass_dir(snap, state = nil)
      [8, 6, 2, 4].find do |dir|
        next false if state && grass_dir_blocked?(state, dir, snap)
        next false unless rail_dir_passable?(dir)
        dx, dy = dir_delta(dir)
        !grass_tile?(snap["x"].to_i + dx, snap["y"].to_i + dy)
      end
    rescue
      nil
    end

    def unknown_map_wander_tick(snap)
      set_mode("frontier_explore")
      if defined?(AutoplayBot::Config) && AutoplayBot::Config.respond_to?(:wild_capture_focus?)
        return fallback_explore_tick(snap, "explore current map", AutoplayBot::Config.wild_capture_focus?, "frontier_explore")
      end
      return fallback_explore_tick(snap, "explore current map", true, "frontier_explore")

      @wander_state ||= {}
      key = snap["map_id"].to_i
      state = @wander_state[key] ||= {
        "dir" => nil,
        "steps" => 0,
        "last_pos" => nil,
        "last_progress_frame" => snap["frame"].to_i,
        "blocked_dirs" => {}
      }
      purge_fallback_dir_blocks!(snap, state)
      current_pos = [snap["map_id"], snap["x"], snap["y"]]
      if state["last_pos"] != current_pos
        state["last_pos"] = current_pos
        state["last_progress_frame"] = snap["frame"].to_i
        state["steps"] = state["steps"].to_i + 1
      end

      dir = state["dir"].to_i
      if fallback_state_stalled?(snap, state, dir)
        block_fallback_dir!(snap, state, dir)
        dir = nil
      end
      if ![2, 4, 6, 8].include?(dir) ||
         state["steps"].to_i >= wander_commit_steps ||
         fallback_dir_blocked?(state, dir, snap) ||
         !rail_dir_passable?(dir) ||
         wander_loop_risk?(dir)
        dir = choose_wander_dir(snap, state)
        state["dir"] = dir
        state["steps"] = 0
      end

      if [2, 4, 6, 8].include?(dir) && rail_dir_passable?(dir)
        @rail_action = "explore walk #{dir_label(dir)}"
        AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
        AutoplayBot::InputQueue.hold_dir(dir, rail_hold_frames(dir)) if defined?(AutoplayBot::InputQueue)
        return true
      end

      @rail_action = "explore wait: no passable step"
      AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
      false
    rescue => e
      @rail_action = "explore error #{e.class}"
      AutoplayBot.log("unknown wander failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def wander_commit_steps
      5
    rescue
      5
    end

    def choose_wander_dir(snap, state)
      last = state["dir"].to_i
      reverse = reverse_dir_for_rail(last)
      dirs = [8, 6, 2, 4].select { |dir| rail_dir_passable?(dir) && !fallback_dir_blocked?(state, dir, snap) }
      return fallback_clear_blocks_dir(snap, state) if dirs.empty?
      return nil if dirs.empty?
      dirs.max_by do |dir|
        score = 0
        score += 10 if dir == last
        score -= 8 if reverse && dir == reverse
        score += 12 if loop_breaking_dir?(dir)
        score += tile_novelty_score(snap, dir)
        score += directional_bias_score(snap, dir)
        score
      end
    rescue
      [8, 6, 2, 4].find { |dir| rail_dir_passable?(dir) }
    end

    def loop_breaking_dir?(dir)
      return false unless defined?(AutoplayBot::Navigator) && AutoplayBot::Navigator.respond_to?(:loop_axis)
      axis = AutoplayBot::Navigator.loop_axis
      return [8, 2].include?(dir.to_i) if axis == :horizontal
      return [4, 6].include?(dir.to_i) if axis == :vertical
      false
    rescue
      false
    end

    def wander_loop_risk?(dir)
      return false unless defined?(AutoplayBot::Navigator) && AutoplayBot::Navigator.respond_to?(:loop_axis)
      axis = AutoplayBot::Navigator.loop_axis
      return [4, 6].include?(dir.to_i) if axis == :horizontal
      return [8, 2].include?(dir.to_i) if axis == :vertical
      false
    rescue
      false
    end

    def tile_novelty_score(snap, dir)
      dx, dy = case dir.to_i
               when 2 then [0, 1]
               when 4 then [-1, 0]
               when 6 then [1, 0]
               when 8 then [0, -1]
               else [0, 0]
               end
      nx = snap["x"].to_i + dx
      ny = snap["y"].to_i + dy
      recent = AutoplayBot::Navigator.instance_variable_get(:@recent_tiles) rescue []
      return 8 unless recent && recent.any?
      seen = recent.count { |tile| tile[0].to_i == snap["map_id"].to_i && tile[1].to_i == nx && tile[2].to_i == ny }
      [8 - (seen * 4), -8].max
    rescue
      0
    end

    def directional_bias_score(snap, dir)
      return 0 unless defined?($game_map) && $game_map
      width = $game_map.respond_to?(:width) ? $game_map.width.to_i : 0
      height = $game_map.respond_to?(:height) ? $game_map.height.to_i : 0
      score = 0
      score += 2 if dir.to_i == 6 && width > 0 && snap["x"].to_i < width / 2
      score += 2 if dir.to_i == 4 && width > 0 && snap["x"].to_i >= width / 2
      score += 3 if dir.to_i == 8 && height > 0 && snap["y"].to_i > 2
      score
    rescue
      0
    end

    def starter_room_rail_tick(snap)
      set_mode("navigation")
      record = dcall(:room_to_house_transfer, nil) ||
               dcall(:fallback_room_to_house_transfer, nil) ||
               { "key" => "bedroom:stairs", "x" => 10, "y" => 5, "trigger" => 1 }
      rail_follow_floor_transfer(
        "bedroom stairs",
        stringify_hash(record).merge("x" => (record["x"] || record[:x] || 10), "y" => (record["y"] || record[:y] || 5)),
        snap
      )
    rescue => e
      AutoplayBot.log("starter room rail failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def player_house_exit_rail_tick(snap)
      set_mode("navigation")
      record = dcall(:house_to_pallet_transfer, nil) ||
               dcall(:fallback_house_to_pallet_transfer, nil) ||
               { "key" => "house:exit", "x" => 7, "y" => 10, "trigger" => 1 }
      rail_follow_floor_transfer(
        "house exit",
        stringify_hash(record).merge("x" => (record["x"] || record[:x] || 7), "y" => (record["y"] || record[:y] || 10)),
        snap
      )
    rescue => e
      AutoplayBot.log("house exit rail failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def pallet_north_rail_tick(snap)
      set_mode("navigation")
      rail_follow_edge(
        "Pallet north road",
        [20, 0],
        8,
        [[20, 1], [19, 1], [21, 1], [20, 2], [19, 2], [21, 2]],
        snap
      )
    rescue => e
      AutoplayBot.log("pallet north rail failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def route1_north_rail_tick(snap)
      set_mode("navigation")
      point = dconst(:ROUTE_1_NORTH_EXIT, { "x" => 14, "y" => 0 })
      tx = (point["x"] || point[:x]).to_i
      ty = (point["y"] || point[:y]).to_i
      if snap["y"].to_i <= 7
        return rail_follow_edge(
          "Route 1 north exit",
          [tx, ty],
          8,
          route_exit_approaches(tx, ty, 8),
          snap
        )
      end
      route_band_rail("Route 1 north", 8, tx, ty, snap)
    rescue => e
      AutoplayBot.log("route 1 north rail failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def route1_south_rail_tick(snap)
      set_mode("navigation")
      point = dconst(:ROUTE_1_SOUTH_EXIT, { "x" => 20, "y" => 49 })
      tx = (point["x"] || point[:x]).to_i
      ty = (point["y"] || point[:y]).to_i
      bounds = rail_map_bounds
      edge_y = bounds ? bounds["height"].to_i - 1 : ty
      if snap["y"].to_i >= edge_y - 7
        return rail_follow_edge(
          "Route 1 south exit",
          [tx, ty],
          2,
          route_exit_approaches(tx, ty, 2),
          snap
        )
      end
      route_band_rail("Route 1 south", 2, tx, ty, snap)
    rescue => e
      AutoplayBot.log("route 1 south rail failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def viridian_route2_rail_tick(snap)
      set_mode("navigation")
      point = dconst(:VIRIDIAN_ROUTE_2_EXIT, { "x" => 27, "y" => 0 })
      tx = (point["x"] || point[:x]).to_i
      ty = (point["y"] || point[:y]).to_i
      if snap["y"].to_i <= 7
        return rail_follow_edge(
          "Viridian north exit",
          [tx, ty],
          8,
          route_exit_approaches(tx, ty, 8),
          snap
        )
      end
      route_band_rail("Viridian north", 8, tx, ty, snap)
    rescue => e
      AutoplayBot.log("viridian north rail failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def viridian_south_rail_tick(snap)
      set_mode("navigation")
      point = dconst(:VIRIDIAN_ROUTE_1_EXIT, { "x" => 21, "y" => 49 })
      tx = (point["x"] || point[:x]).to_i
      ty = (point["y"] || point[:y]).to_i
      bounds = rail_map_bounds
      edge_y = bounds ? bounds["height"].to_i - 1 : ty
      if snap["y"].to_i >= edge_y - 7
        return rail_follow_edge(
          "Viridian south exit",
          [tx, ty],
          2,
          route_exit_approaches(tx, ty, 2),
          snap
        )
      end
      route_band_rail("Viridian south", 2, tx, ty, snap)
    rescue => e
      AutoplayBot.log("viridian south rail failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def forest_cross_rail_tick(snap)
      set_mode("navigation")
      return false unless snap && snap["map_id"].to_i == dconst(:VIRIDIAN_FOREST_MAP_ID, 491).to_i
      record = drecord(:FOREST_NORTH_GATE_TRANSFER, { "x" => 13, "y" => 6 }).merge("map_id" => snap["map_id"])
      if forest_cross_exit_ready?(snap)
        @rail_action = "Cross Viridian Forest: enter gate"
        return rail_follow_transfer("North Forest Gate", record, snap)
      end

      target = forest_cross_target(snap)
      return true if forest_cross_path_tick("Cross Viridian Forest", target, snap)
      reachable = forest_cross_reachable_target(snap, target)
      return true if reachable && reachable != target &&
                     forest_cross_path_tick("Cross Viridian Forest", reachable, snap)

      dir = forest_cross_scripted_dir(snap, target)
      if [2, 4, 6, 8].include?(dir)
        @rail_action = "Cross Viridian Forest: step #{dir_label(dir)} -> #{target[0]},#{target[1]}"
        AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
        if defined?(AutoplayBot::InputQueue)
          AutoplayBot::InputQueue.clear
          AutoplayBot::InputQueue.hold_dir(dir, forest_cross_hold_frames(dir))
        end
        return true
      end

      @rail_action = "Cross Viridian Forest: blocked @#{snap["x"]},#{snap["y"]}"
      AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      true
    rescue => e
      @rail_action = "Cross Viridian Forest: error #{e.class}"
      AutoplayBot.log("forest cross rail failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def forest_cross_exit_ready?(snap)
      x = snap["x"].to_i
      y = snap["y"].to_i
      y <= 7 && x >= 12 && x <= 14
    rescue
      false
    end

    def forest_cross_target(snap)
      x = snap["x"].to_i
      y = snap["y"].to_i
      return [43, 36] if y >= 34 && x < 36
      return [39, 29] if y >= 30 && x >= 36
      return [38, 18] if y >= 19 && x >= 36
      return [28, 18] if y >= 18 && x > 28
      return [24, 17] if y >= 17 && x > 24
      return [23, 11] if y > 11 && x >= 18
      return [18, 11] if y <= 12 && x > 18
      return [14, 16] if y < 16 && x >= 14
      return [11, 16] if y >= 16 && x > 11
      return [11, 8] if y > 8 && x <= 14
      [13, 6]
    rescue
      [13, 6]
    end

    def forest_cross_waypoints
      [
        [43, 36],
        [39, 29],
        [38, 18],
        [28, 18],
        [24, 17],
        [23, 11],
        [18, 11],
        [14, 16],
        [11, 16],
        [11, 8],
        [13, 6]
      ]
    rescue
      [[13, 6]]
    end

    def forest_cross_scripted_dir(snap, target)
      candidates = forest_cross_dir_candidates(snap, target)
      candidates.find { |dir| forest_cross_passable?(snap, dir) }
    rescue
      [8, 2, 4, 6].find { |dir| forest_cross_passable?(snap, dir) }
    end

    def forest_cross_dir_candidates(snap, target)
      x = snap["x"].to_i
      y = snap["y"].to_i
      tx = target[0].to_i
      ty = target[1].to_i
      horizontal = tx < x ? 4 : (tx > x ? 6 : nil)
      vertical = ty < y ? 8 : (ty > y ? 2 : nil)
      reverse_h = horizontal == 4 ? 6 : (horizontal == 6 ? 4 : nil)
      reverse_v = vertical == 8 ? 2 : (vertical == 2 ? 8 : nil)
      primary = (tx - x).abs >= (ty - y).abs ? [horizontal, vertical] : [vertical, horizontal]
      # Viridian Forest's upper corridor has tree teeth around y 9-10. Force
      # the lane correction before sideways travel so the rail cannot grind left
      # into the forest wall at tiles like M491 x31,y9.
      if y <= 12 && x > 18
        lane = y < 11 ? 2 : (y > 11 ? 8 : nil)
        primary = [lane, horizontal, vertical, 2, 8]
      elsif y <= 12
        primary = [vertical, horizontal, 2, 8]
      elsif y >= 34
        primary = [horizontal, vertical, 8, 2]
      end
      (primary + [vertical, horizontal, reverse_v, reverse_h, 8, 2, 4, 6]).compact.uniq
    rescue
      [8, 2, 4, 6]
    end

    def forest_cross_passable?(snap, dir)
      return false unless snap && [2, 4, 6, 8].include?(dir.to_i)
      return false unless defined?($game_player) && $game_player
      x = snap["x"].to_i
      y = snap["y"].to_i
      return false if x > 18 && y < 11 && dir.to_i == 4
      if $game_player.respond_to?(:passable?)
        return false unless $game_player.passable?(x, y, dir)
      else
        return false unless rail_dir_passable?(dir)
      end
      dx, dy = dir_delta(dir)
      nx = x + dx
      ny = y + dy
      return false if forest_cross_forbidden_tile?(nx, ny)
      true
    rescue
      false
    end

    def forest_cross_forbidden_tile?(x, y)
      return true if y.to_i < 5
      false
    rescue
      false
    end

    def forest_cross_hold_frames(dir)
      [rail_hold_frames(dir), 5].max
    rescue
      8
    end

    def forest_cross_path_tick(label, target, snap)
      targets = forest_cross_target_tiles(target[0], target[1])
      path = rail_path_to_any(targets, forest_cross_path_budget)
      return false unless path && !path.empty?
      dir = path.first.to_i
      return false unless rail_dir_passable?(dir)
      @rail_action = "#{label}: path #{dir_label(dir)} #{path.length} to #{target[0]},#{target[1]}"
      AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
      AutoplayBot::InputQueue.hold_dir(dir, rail_hold_path_frames(path, 7)) if defined?(AutoplayBot::InputQueue)
      true
    rescue
      false
    end

    def forest_cross_target_tiles(tx, ty)
      tiles = []
      [0, 1, 2].each do |radius|
        (-radius..radius).each do |dx|
          (-radius..radius).each do |dy|
            next if dx.abs + dy.abs > radius
            tiles << [tx.to_i + dx, ty.to_i + dy]
          end
        end
      end
      tiles.uniq.select do |x, y|
        defined?(AutoplayBot::Pathfinder) &&
          AutoplayBot::Pathfinder.respond_to?(:valid_tile?) &&
          AutoplayBot::Pathfinder.valid_tile?(x, y)
      end
    rescue
      [[tx.to_i, ty.to_i]]
    end

    def forest_cross_reachable_target(snap, preferred)
      waypoints = forest_cross_waypoints
      start_index = waypoints.index(preferred) || 0
      ordered = waypoints[start_index..-1].to_a + waypoints[0...start_index].to_a
      ordered.first(6).find do |target|
        path = rail_path_to_any(forest_cross_target_tiles(target[0], target[1]), forest_cross_path_budget)
        path && !path.empty?
      end
    rescue
      nil
    end

    def forest_cross_detour_dir(snap, target)
      dirs = [8, 2, 4, 6].select { |dir| rail_dir_passable?(dir) }
      return nil if dirs.empty?
      before = (target[0].to_i - snap["x"].to_i).abs + (target[1].to_i - snap["y"].to_i).abs
      dirs.max_by do |dir|
        dx, dy = dir_delta(dir)
        nx = snap["x"].to_i + dx
        ny = snap["y"].to_i + dy
        after = (target[0].to_i - nx).abs + (target[1].to_i - ny).abs
        score = (before - after) * 12
        score += 16 if [8, 2].include?(dir)
        score += 35 if loop_breaking_dir?(dir)
        score += tile_novelty_score(snap, dir)
        score += 10 if grass_tile?(nx, ny)
        score
      end
    rescue
      [8, 2, 4, 6].find { |dir| rail_dir_passable?(dir) }
    end

    def forest_cross_path_budget
      5200
    rescue
      4200
    end

    def route2_pewter_rail_tick(snap)
      set_mode("navigation")
      point = dconst(:ROUTE_2_PEWTER_EXIT, { "x" => 11, "y" => 0 })
      tx = (point["x"] || point[:x]).to_i
      ty = (point["y"] || point[:y]).to_i
      if snap["y"].to_i <= 7
        return rail_follow_edge(
          "Route 2 Pewter exit",
          [tx, ty],
          8,
          route_exit_approaches(tx, ty, 8),
          snap
        )
      end
      route_band_rail("Route 2 north", 8, tx, ty, snap)
    rescue => e
      AutoplayBot.log("route 2 pewter rail failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def pewter_gym_rail_tick(snap)
      set_mode("navigation")
      record = drecord(:PEWTER_GYM_TRANSFER, { "x" => 11, "y" => 11 })
      tx = (record["x"] || record[:x] || 11).to_i
      ty = (record["y"] || record[:y] || 11).to_i
      if (snap["y"].to_i - ty).abs <= 8
        return rail_follow_transfer("Pewter Gym", record, snap)
      end
      route_band_rail("Pewter gym approach", 8, tx, ty, snap)
    rescue => e
      AutoplayBot.log("pewter gym rail failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def auto_edge_rail_tick(goal, snap)
      set_mode("navigation")
      record = stringify_hash(goal["record"] || goal)
      tx = (record["x"] || goal["x"]).to_i
      ty = (record["y"] || goal["y"]).to_i
      dir = (goal["exit_dir"] || record["exit_dir"]).to_i
      return false unless [2, 4, 6, 8].include?(dir)
      label = goal["label"] || record["event_name"] || "map exit"
      if near_edge_for_rail?(snap, dir, 7)
        return rail_follow_edge(
          "#{label} exit",
          [tx, ty],
          dir,
          route_exit_approaches(tx, ty, dir),
          snap
        )
      end
      route_axis_rail(label.to_s, dir, tx, ty, snap)
    rescue => e
      AutoplayBot.log("auto edge rail failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def auto_transfer_rail_tick(goal, snap)
      set_mode("navigation")
      record = stringify_hash(goal["record"] || goal)
      tx = (record["x"] || goal["x"]).to_i
      ty = (record["y"] || goal["y"]).to_i
      label = goal["label"] || record["event_name"] || "transfer"
      dx = tx - snap["x"].to_i
      dy = ty - snap["y"].to_i
      if dx.abs + dy.abs <= 10
        return rail_follow_floor_transfer(label.to_s, record.merge("x" => tx, "y" => ty), snap) if floor_transfer_like?(record, snap)
        return rail_follow_transfer(label.to_s, record.merge("x" => tx, "y" => ty), snap)
      end
      return true if route_transfer_direct_path_tick(label.to_s, record.merge("x" => tx, "y" => ty), snap)
      dir = dy.abs >= dx.abs ? (dy < 0 ? 8 : 2) : (dx < 0 ? 4 : 6)
      route_axis_rail(label.to_s, dir, tx, ty, snap)
    rescue => e
      AutoplayBot.log("auto transfer rail failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def route_axis_rail(label, dir, tx, ty, snap)
      case dir.to_i
      when 2, 8
        route_band_rail(label, dir, tx, ty, snap)
      when 4, 6
        route_column_rail(label, dir, tx, ty, snap)
      else
        false
      end
    rescue
      false
    end

    def route_precise_path_tick(label, targets, snap, budget = 1400)
      return false unless snap && snap["scene"].to_s == "map"
      path = rail_path_to_any(targets, budget.to_i)
      return false unless path && !path.empty?
      dir = path.first.to_i
      return false unless rail_dir_passable?(dir)
      return false unless route_motion_allowed?(label, snap, dir, "path")
      @rail_action = "#{label}: path #{dir_label(dir)} #{path.length}"
      AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
      AutoplayBot::InputQueue.hold_dir(dir, rail_hold_path_frames(path, 7)) if defined?(AutoplayBot::InputQueue)
      true
    rescue
      false
    end

    def route_transfer_direct_path_tick(label, record, snap)
      return false unless record && snap
      tx = record["x"].to_i
      ty = record["y"].to_i
      return false if tx == 0 && ty == 0 && !record["x"] && !record["y"]
      dx = tx - snap["x"].to_i
      dy = ty - snap["y"].to_i
      dir = dy.abs >= dx.abs ? (dy < 0 ? 8 : 2) : (dx < 0 ? 4 : 6)
      targets = [[tx, ty]] + route_exit_approaches(tx, ty, dir) + transfer_approaches(tx, ty)
      budget = route_transfer_direct_budget(label, snap)
      route_precise_path_tick(label, targets.uniq, snap, budget)
    rescue
      false
    end

    def route_transfer_direct_budget(label, snap)
      base = if snap && snap["map_id"].to_i == dconst(:VIRIDIAN_FOREST_MAP_ID, 491).to_i
               3600
             elsif label.to_s =~ /forest|gate|route/i
               3200
             else
               2400
             end
      if defined?(AutoplayBot::Config) && AutoplayBot::Config.respond_to?(:adaptive_path_node_budget)
        return [AutoplayBot::Config.adaptive_path_node_budget(base, "transfer").to_i, base].max
      end
      base
    rescue
      2400
    end

    def route_band_rail(label, exit_dir, preferred_x, final_y, snap)
      return false unless defined?($game_player) && $game_player
      if @last_rail_label.to_s != label.to_s
        @route_motion_guard = nil
        @route_axis_history = nil
        Navigator.reset!("rail #{label}") if defined?(AutoplayBot::Navigator) &&
                                             AutoplayBot::Navigator.respond_to?(:reset!)
      end
      @last_rail_label = label.to_s

      px = $game_player.x.to_i
      py = $game_player.y.to_i
      band_y = route_band_y(py, final_y.to_i, exit_dir)
      forward = exit_dir.to_i
      exit_targets = route_edge_targets(preferred_x.to_i, final_y.to_i, exit_dir, snap)
      return true if route_precise_path_tick(label, exit_targets, snap, route_axis_precise_budget(label, snap))
      return true if route_forward_progress_tick(label, snap, forward, py, final_y, "y", band_y)

      path = rail_path_to_any(route_band_targets(preferred_x.to_i, band_y, snap), route_band_path_budget(label, snap))
      if path && !path.empty?
        dir = path.first.to_i
        if rail_dir_passable?(dir)
          if route_motion_allowed?(label, snap, dir, "band")
            @rail_action = "#{label}: band y#{band_y} #{dir_label(dir)} #{path.length}"
            AutoplayBot.status(@rail_action)
            AutoplayBot::InputQueue.hold_dir(dir, rail_hold_path_frames(path, 6)) if defined?(AutoplayBot::InputQueue)
            return true
          end
          remember_rail_block!(snap, dir, "#{label}_band_repeat")
        end
        remember_rail_block!(snap, path.first.to_i, "#{label}_band_blocked")
      end

      return true if rail_grass_fallback_allowed?(label) && route_grass_fallback(label, snap, "band")

      dir = route_axis_escape_dir(exit_dir, preferred_x.to_i, px, snap)
      return true if route_escape_progress_tick(label, snap, dir, exit_dir, "y", band_y)
      return true if route_alternate_escape_tick(label, snap, exit_dir, dir, "y", band_y)

      @rail_action = "#{label}: no band path y#{band_y}"
      AutoplayBot.status(@rail_action)
      false
    rescue => e
      @rail_action = "#{label}: error #{e.class}"
      false
    end

    def route_column_rail(label, exit_dir, final_x, preferred_y, snap)
      return false unless defined?($game_player) && $game_player
      if @last_rail_label.to_s != label.to_s
        @route_motion_guard = nil
        @route_axis_history = nil
        Navigator.reset!("rail #{label}") if defined?(AutoplayBot::Navigator) &&
                                             AutoplayBot::Navigator.respond_to?(:reset!)
      end
      @last_rail_label = label.to_s

      px = $game_player.x.to_i
      py = $game_player.y.to_i
      band_x = route_band_x(px, final_x.to_i, exit_dir)
      forward = exit_dir.to_i
      exit_targets = route_edge_targets(final_x.to_i, preferred_y.to_i, exit_dir, snap)
      return true if route_precise_path_tick(label, exit_targets, snap, route_axis_precise_budget(label, snap))
      return true if route_forward_progress_tick(label, snap, forward, px, final_x, "x", band_x)

      path = rail_path_to_any(route_column_targets(band_x, preferred_y.to_i, snap), route_band_path_budget(label, snap))
      if path && !path.empty?
        dir = path.first.to_i
        if rail_dir_passable?(dir)
          if route_motion_allowed?(label, snap, dir, "column")
            @rail_action = "#{label}: column x#{band_x} #{dir_label(dir)} #{path.length}"
            AutoplayBot.status(@rail_action)
            AutoplayBot::InputQueue.hold_dir(dir, rail_hold_path_frames(path, 6)) if defined?(AutoplayBot::InputQueue)
            return true
          end
          remember_rail_block!(snap, dir, "#{label}_column_repeat")
        end
        remember_rail_block!(snap, path.first.to_i, "#{label}_column_blocked")
      end

      return true if rail_grass_fallback_allowed?(label) && route_grass_fallback(label, snap, "column")

      dir = route_column_escape_dir(exit_dir, preferred_y.to_i, py, snap)
      return true if route_escape_progress_tick(label, snap, dir, exit_dir, "x", band_x)
      return true if route_alternate_escape_tick(label, snap, exit_dir, dir, "x", band_x)

      @rail_action = "#{label}: no column path x#{band_x}"
      AutoplayBot.status(@rail_action)
      false
    rescue => e
      @rail_action = "#{label}: error #{e.class}"
      false
    end

    def route_axis_precise_budget(label, snap)
      return 3400 if snap && snap["map_id"].to_i == dconst(:VIRIDIAN_FOREST_MAP_ID, 491).to_i
      return 3000 if label.to_s =~ /forest|route|gate/i
      return 2600 if label.to_s =~ /Viridian|Pewter|City|town|Mart|Center/i
      1800
    rescue
      1800
    end

    def route_band_path_budget(label, snap)
      base = route_axis_precise_budget(label, snap)
      [[base.to_i / 2, 1200].max, base.to_i].min
    rescue
      1200
    end

    def rail_grass_fallback_allowed?(label = nil)
      goal = @active_goal || {}
      adapter = goal["adapter"].to_s
      target_kind = goal["target_kind"].to_s
      return false if target_kind == "travel" || target_kind == "story"
      return false if adapter == "auto_transfer_rail" || adapter == "auto_edge_rail"
      return false if label.to_s =~ /Cross Viridian Forest|Viridian north|Route 2|Route 1|Pallet north/i
      true
    rescue
      true
    end

    def route_forward_step_allowed?(dir, current_axis, final_axis)
      case dir.to_i
      when 8, 4 then current_axis.to_i > final_axis.to_i + 1
      when 2, 6 then current_axis.to_i < final_axis.to_i - 1
      else false
      end
    rescue
      false
    end

    def route_forward_progress_tick(label, snap, forward, current_axis, final_axis, axis_name, band_axis)
      return false unless route_forward_step_allowed?(forward, current_axis, final_axis)
      clear = route_forward_clearance?(forward, route_forward_clearance_tiles(label))
      return false unless clear || rail_dir_passable?(forward)
      return false unless route_motion_allowed?(label, snap, forward, "forward")
      suffix = clear ? "clear" : "step"
      @rail_action = "#{label}: forward #{dir_label(forward)} #{suffix} toward #{axis_name}#{band_axis}"
      AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
      AutoplayBot::InputQueue.hold_dir(forward, rail_hold_frames(forward)) if defined?(AutoplayBot::InputQueue)
      true
    rescue
      false
    end

    def route_escape_progress_tick(label, snap, dir, _exit_dir, axis_name, band_axis)
      return false unless dir && route_motion_allowed?(label, snap, dir, "escape")
      @rail_action = "#{label}: escape #{dir_label(dir)} toward #{axis_name}#{band_axis}"
      AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
      AutoplayBot::InputQueue.hold_dir(dir, rail_hold_frames(dir)) if defined?(AutoplayBot::InputQueue)
      true
    rescue
      false
    end

    def route_alternate_escape_tick(label, snap, exit_dir, blocked_dir, axis_name, band_axis)
      candidates = route_perpendicular_escape_dirs(exit_dir, snap) +
                   [exit_dir.to_i, reverse_dir_for_rail(exit_dir)]
      candidates.compact.uniq.each do |dir|
        next if blocked_dir && dir.to_i == blocked_dir.to_i
        next unless rail_dir_passable?(dir)
        next unless route_motion_allowed?(label, snap, dir, "escape_alt")
        @rail_action = "#{label}: detour #{dir_label(dir)} toward #{axis_name}#{band_axis}"
        AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
        AutoplayBot::InputQueue.hold_dir(dir, rail_hold_frames(dir)) if defined?(AutoplayBot::InputQueue)
        return true
      end
      false
    rescue
      false
    end

    def route_path_starts_backward?(path, exit_dir)
      first = Array(path).first.to_i
      return first == 2 if exit_dir.to_i == 8
      return first == 8 if exit_dir.to_i == 2
      return first == 6 if exit_dir.to_i == 4
      return first == 4 if exit_dir.to_i == 6
      false
    rescue
      false
    end

    def route_band_y(current_y, final_y, exit_dir)
      step = 6
      if exit_dir.to_i == 8
        [current_y.to_i - step, [final_y.to_i + 2, 1].max].max
      else
        bounds = rail_map_bounds
        max_y = bounds ? bounds["height"].to_i - 2 : [final_y.to_i - 1, current_y.to_i + step].max
        [current_y.to_i + step, [final_y.to_i - 2, max_y].min].min
      end
    rescue
      current_y.to_i
    end

    def route_band_x(current_x, final_x, exit_dir)
      step = 6
      if exit_dir.to_i == 4
        [current_x.to_i - step, [final_x.to_i + 2, 1].max].max
      else
        bounds = rail_map_bounds
        max_x = bounds ? bounds["width"].to_i - 2 : [final_x.to_i - 1, current_x.to_i + step].max
        [current_x.to_i + step, [final_x.to_i - 2, max_x].min].min
      end
    rescue
      current_x.to_i
    end

    def route_band_targets(preferred_x, band_y, snap)
      bounds = rail_map_bounds
      max_x = bounds ? bounds["width"].to_i - 1 : [preferred_x.to_i + 12, snap["x"].to_i + 12].max
      min_x = 0
      centers = [snap["x"].to_i, preferred_x.to_i, ((snap["x"].to_i + preferred_x.to_i) / 2)]
      xs = []
      (0..16).each do |radius|
        centers.each do |center|
          [center - radius, center + radius].each do |x|
            next if x < min_x || x > max_x
            xs << x
          end
        end
      end
      xs.uniq.map { |x| [x, band_y.to_i] }.select do |x, y|
        defined?(AutoplayBot::Pathfinder) &&
          AutoplayBot::Pathfinder.respond_to?(:valid_tile?) &&
          AutoplayBot::Pathfinder.valid_tile?(x, y)
      end.first(40)
    rescue
      []
    end

    def route_column_targets(band_x, preferred_y, snap)
      bounds = rail_map_bounds
      max_y = bounds ? bounds["height"].to_i - 1 : [preferred_y.to_i + 12, snap["y"].to_i + 12].max
      min_y = 0
      centers = [snap["y"].to_i, preferred_y.to_i, ((snap["y"].to_i + preferred_y.to_i) / 2)]
      ys = []
      (0..16).each do |radius|
        centers.each do |center|
          [center - radius, center + radius].each do |y|
            next if y < min_y || y > max_y
            ys << y
          end
        end
      end
      ys.uniq.map { |y| [band_x.to_i, y] }.select do |x, y|
        defined?(AutoplayBot::Pathfinder) &&
          AutoplayBot::Pathfinder.respond_to?(:valid_tile?) &&
          AutoplayBot::Pathfinder.valid_tile?(x, y)
      end.first(40)
    rescue
      []
    end

    def route_motion_allowed?(label, snap, dir, kind = "rail")
      return true unless snap && [2, 4, 6, 8].include?(dir.to_i)
      @route_motion_guard ||= {}
      key = route_motion_guard_key(label, snap, dir, kind)
      frame = route_motion_frame(snap)
      now = route_motion_time
      entry = @route_motion_guard[key]
      if entry &&
         frame - entry["frame"].to_i <= route_motion_guard_frame_window &&
         now - entry["time"].to_f <= route_motion_guard_seconds_window
        entry["count"] = entry["count"].to_i + 1
        entry["frame"] = frame
        entry["time"] = now
      else
        entry = { "count" => 1, "frame" => frame, "time" => now }
        @route_motion_guard[key] = entry
      end
      @route_motion_guard.shift while @route_motion_guard.length > 48
      looping = route_axis_motion_looping?(label, snap, dir, kind, frame, now)
      if entry["count"].to_i <= route_motion_repeat_limit(kind) && !looping
        remember_route_motion_sample!(label, snap, dir, kind, frame, now)
        return true
      end

      reason = looping ? "loop" : "repeat"
      remember_rail_block!(snap, dir, "#{label}_#{kind}_#{reason}")
      @rail_path_cache = nil
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      @rail_action = "#{label}: replan #{kind} #{reason} #{dir_label(dir)}"
      AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
      false
    rescue
      true
    end

    def route_motion_guard_key(label, snap, dir, kind)
      [
        snap["map_id"].to_i,
        snap["x"].to_i,
        snap["y"].to_i,
        label.to_s,
        kind.to_s,
        dir.to_i
      ].join(":")
    rescue
      "#{label}:#{kind}:#{dir}"
    end

    def route_motion_frame(snap)
      return snap["frame"].to_i if snap && snap["frame"]
      return SceneObserver.frame_count.to_i if defined?(SceneObserver) &&
                                              SceneObserver.respond_to?(:frame_count)
      Graphics.frame_count.to_i
    rescue
      0
    end

    def route_motion_time
      if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.respond_to?(:current_time_seconds)
        return AutoplayBot::Runtime.current_time_seconds.to_f
      end
      Time.now.to_f
    rescue
      0.0
    end

    def route_motion_guard_frame_window
      speed = rail_speedup_multiplier
      return 28 if speed >= 7
      return 45 if speed >= 3
      72
    rescue
      45
    end

    def route_motion_guard_seconds_window
      speed = rail_speedup_multiplier
      return 0.75 if speed >= 7
      return 1.0 if speed >= 3
      1.5
    rescue
      1.0
    end

    def route_motion_repeat_limit(kind)
      return 1 if kind.to_s =~ /escape/
      return 2 if kind.to_s == "forward"
      2
    rescue
      2
    end

    def route_axis_motion_looping?(label, snap, dir, kind, frame, now)
      return false unless snap && [2, 4, 6, 8].include?(dir.to_i)
      return false if kind.to_s == "forward"
      samples = route_recent_motion_samples(label, snap, frame, now)
      return false if samples.length < 3
      current = {
        "x" => snap["x"].to_i,
        "y" => snap["y"].to_i,
        "dir" => dir.to_i
      }
      all = samples + [current]
      if [4, 6].include?(dir.to_i)
        dirs = all.map { |entry| entry["dir"].to_i }
        xs = all.map { |entry| entry["x"].to_i }
        ys = all.map { |entry| entry["y"].to_i }
        return false unless dirs.include?(4) && dirs.include?(6)
        return false unless ys.max - ys.min <= 1
        return false unless xs.max - xs.min <= 4
        return true
      end
      if [2, 8].include?(dir.to_i)
        dirs = all.map { |entry| entry["dir"].to_i }
        xs = all.map { |entry| entry["x"].to_i }
        ys = all.map { |entry| entry["y"].to_i }
        return false unless dirs.include?(2) && dirs.include?(8)
        return false unless xs.max - xs.min <= 1
        return false unless ys.max - ys.min <= 4
        return true
      end
      false
    rescue
      false
    end

    def route_recent_motion_samples(label, snap, frame, now)
      @route_axis_history ||= []
      map_id = snap["map_id"].to_i
      @route_axis_history.select do |entry|
        entry["label"].to_s == label.to_s &&
          entry["map_id"].to_i == map_id &&
          frame - entry["frame"].to_i <= 180 &&
          now - entry["time"].to_f <= 4.0
      end.last(5)
    rescue
      []
    end

    def remember_route_motion_sample!(label, snap, dir, kind, frame, now)
      @route_axis_history ||= []
      @route_axis_history << {
        "label" => label.to_s,
        "map_id" => snap["map_id"].to_i,
        "x" => snap["x"].to_i,
        "y" => snap["y"].to_i,
        "dir" => dir.to_i,
        "kind" => kind.to_s,
        "frame" => frame.to_i,
        "time" => now.to_f
      }
      @route_axis_history.shift while @route_axis_history.length > 32
    rescue
      nil
    end

    def route_axis_escape_dir(exit_dir, preferred_x, player_x, snap = nil)
      horizontal = preferred_x.to_i < player_x.to_i ? 4 : (preferred_x.to_i > player_x.to_i ? 6 : nil)
      opposite = horizontal == 4 ? 6 : (horizontal == 6 ? 4 : nil)
      laterals = horizontal ? [horizontal, opposite] : route_perpendicular_escape_dirs(exit_dir, snap)
      candidates = []
      candidates << exit_dir.to_i if route_forward_clearance?(exit_dir, 2)
      candidates.concat(laterals)
      candidates << reverse_dir_for_rail(exit_dir)
      candidates.compact.uniq.find { |dir| rail_dir_passable?(dir) }
    rescue
      nil
    end

    def route_column_escape_dir(exit_dir, preferred_y, player_y, snap = nil)
      vertical = preferred_y.to_i < player_y.to_i ? 8 : (preferred_y.to_i > player_y.to_i ? 2 : nil)
      opposite = vertical == 8 ? 2 : (vertical == 2 ? 8 : nil)
      laterals = vertical ? [vertical, opposite] : route_perpendicular_escape_dirs(exit_dir, snap)
      candidates = []
      candidates << exit_dir.to_i if route_forward_clearance?(exit_dir, 2)
      candidates.concat(laterals)
      candidates << reverse_dir_for_rail(exit_dir)
      candidates.compact.uniq.find { |dir| rail_dir_passable?(dir) }
    rescue
      nil
    end

    def route_perpendicular_escape_dirs(exit_dir, snap = nil)
      dirs = [2, 8].include?(exit_dir.to_i) ? [4, 6] : [8, 2]
      dirs.sort_by do |dir|
        [
          -route_dir_clearance(dir, 4),
          route_escape_edge_penalty(dir, snap)
        ]
      end
    rescue
      [4, 6, 8, 2]
    end

    def route_escape_edge_penalty(dir, snap = nil)
      return 0 unless snap
      bounds = rail_map_bounds
      return 0 unless bounds
      x = snap["x"].to_i
      y = snap["y"].to_i
      case dir.to_i
      when 4 then x <= 1 ? 8 : 0
      when 6 then x >= bounds["width"].to_i - 2 ? 8 : 0
      when 8 then y <= 1 ? 8 : 0
      when 2 then y >= bounds["height"].to_i - 2 ? 8 : 0
      else 0
      end
    rescue
      0
    end

    def route_forward_clearance_tiles(label = nil)
      return 4 if label.to_s =~ /Viridian|Pewter|Mart|Center|City|town/i
      return 3 if label.to_s =~ /Route|Forest|Gate/i
      2
    rescue
      3
    end

    def route_forward_clearance?(dir, tiles = 3)
      route_dir_clearance(dir, tiles.to_i) >= tiles.to_i
    rescue
      false
    end

    def route_dir_clearance(dir, tiles = 4)
      return 0 unless [2, 4, 6, 8].include?(dir.to_i)
      return 0 unless defined?($game_player) && $game_player
      x = $game_player.x.to_i
      y = $game_player.y.to_i
      clear = 0
      tiles.to_i.times do
        break unless route_passable_from?(x, y, dir)
        dx, dy = dir_delta(dir)
        x += dx
        y += dy
        break unless route_valid_tile?(x, y)
        clear += 1
      end
      clear
    rescue
      0
    end

    def route_passable_from?(x, y, dir)
      if defined?(AutoplayBot::Pathfinder) && AutoplayBot::Pathfinder.respond_to?(:passable?)
        return AutoplayBot::Pathfinder.passable?(x.to_i, y.to_i, dir)
      end
      return false unless defined?($game_player) && $game_player
      $game_player.passable?(x.to_i, y.to_i, dir)
    rescue
      false
    end

    def route_valid_tile?(x, y)
      if defined?(AutoplayBot::Pathfinder) && AutoplayBot::Pathfinder.respond_to?(:valid_tile?)
        return AutoplayBot::Pathfinder.valid_tile?(x.to_i, y.to_i)
      end
      return false unless defined?($game_map) && $game_map
      return $game_map.valid?(x.to_i, y.to_i) if $game_map.respond_to?(:valid?)
      x.to_i >= 0 && y.to_i >= 0
    rescue
      false
    end

    def route_grass_fallback(label, snap, reason = "rail")
      return false unless defined?(AutoplayBot::Config) &&
                          AutoplayBot::Config.respond_to?(:wild_capture_focus?) &&
                          AutoplayBot::Config.wild_capture_focus?
      return false unless snap && snap["scene"].to_s == "map"
      if cave_encounter_map? && cave_floor_tile?(snap["x"], snap["y"])
        @rail_action = "#{label}: cave patrol #{reason}"
        AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
        return wild_grass_patrol_tick(snap)
      end

      if grass_tile?(snap["x"], snap["y"])
        @rail_action = "#{label}: grass patrol"
        AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
        return wild_grass_patrol_tick(snap)
      end

      dir = adjacent_grass_dir(snap)
      if dir
        @rail_action = "#{label}: grass #{dir_label(dir)} #{reason}"
        AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
        AutoplayBot::InputQueue.hold_dir(dir, rail_hold_frames(dir)) if defined?(AutoplayBot::InputQueue)
        return true
      end

      path = cached_path_to_nearby_grass(snap)
      return false unless path && !path.empty?
      dir = path.first.to_i
      return false unless rail_dir_passable?(dir)
      @rail_action = "#{label}: grass path #{dir_label(dir)} #{path.length}"
      AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
      AutoplayBot::InputQueue.hold_dir(dir, rail_hold_path_frames(path, 6)) if defined?(AutoplayBot::InputQueue)
      true
    rescue => e
      @rail_action = "#{label}: grass fallback error #{e.class}"
      false
    end

    def adjacent_grass_dir(snap, state = nil)
      return nil unless snap
      [8, 4, 6, 2].find do |dir|
        next false if state && grass_dir_blocked?(state, dir, snap)
        next false unless rail_dir_passable?(dir)
        dx, dy = dir_delta(dir)
        grass_tile?(snap["x"].to_i + dx, snap["y"].to_i + dy)
      end
    rescue
      nil
    end

    def reverse_dir_for_rail(dir)
      { 2 => 8, 8 => 2, 4 => 6, 6 => 4 }[dir.to_i]
    rescue
      nil
    end

    def route_exit_approaches(tx, ty, exit_dir)
      case exit_dir.to_i
      when 8
        [[tx, ty + 1], [tx - 1, ty + 1], [tx + 1, ty + 1], [tx, ty + 2], [tx - 1, ty + 2], [tx + 1, ty + 2]]
      when 2
        [[tx, ty - 1], [tx - 1, ty - 1], [tx + 1, ty - 1], [tx, ty - 2], [tx - 1, ty - 2], [tx + 1, ty - 2]]
      when 4
        [[tx + 1, ty], [tx + 1, ty - 1], [tx + 1, ty + 1], [tx + 2, ty], [tx + 2, ty - 1], [tx + 2, ty + 1]]
      when 6
        [[tx - 1, ty], [tx - 1, ty - 1], [tx - 1, ty + 1], [tx - 2, ty], [tx - 2, ty - 1], [tx - 2, ty + 1]]
      else
        []
      end
    rescue
      []
    end

    def route_edge_targets(primary_axis, final_axis, exit_dir, snap)
      targets = route_exit_approaches(primary_axis.to_i, final_axis.to_i, exit_dir)
      bounds = rail_map_bounds
      return targets.uniq unless bounds && snap

      case exit_dir.to_i
      when 8, 2
        rows = route_edge_rows(final_axis.to_i, exit_dir, bounds)
        xs = route_edge_values(primary_axis.to_i, snap["x"].to_i, 0, bounds["width"].to_i - 1)
        rows.each { |y| xs.each { |x| targets << [x, y] } }
      when 4, 6
        cols = route_edge_cols(primary_axis.to_i, exit_dir, bounds)
        ys = route_edge_values(final_axis.to_i, snap["y"].to_i, 0, bounds["height"].to_i - 1)
        cols.each { |x| ys.each { |y| targets << [x, y] } }
      end

      targets.uniq.select { |x, y| route_valid_tile?(x, y) }.first(64)
    rescue
      route_exit_approaches(primary_axis.to_i, final_axis.to_i, exit_dir)
    end

    def route_edge_rows(final_y, exit_dir, bounds)
      if exit_dir.to_i == 8
        rows = [final_y.to_i + 1, final_y.to_i + 2, 1, 2, 3, 4]
      else
        max_y = bounds["height"].to_i - 1
        rows = [final_y.to_i - 1, final_y.to_i - 2, max_y - 1, max_y - 2, max_y - 3, max_y - 4]
      end
      rows.select { |y| y >= 0 && y < bounds["height"].to_i }.uniq
    rescue
      []
    end

    def route_edge_cols(final_x, exit_dir, bounds)
      if exit_dir.to_i == 4
        cols = [final_x.to_i + 1, final_x.to_i + 2, 1, 2, 3, 4]
      else
        max_x = bounds["width"].to_i - 1
        cols = [final_x.to_i - 1, final_x.to_i - 2, max_x - 1, max_x - 2, max_x - 3, max_x - 4]
      end
      cols.select { |x| x >= 0 && x < bounds["width"].to_i }.uniq
    rescue
      []
    end

    def route_edge_values(primary, current, min_value, max_value)
      min_value = min_value.to_i
      max_value = max_value.to_i
      return [] if max_value < min_value
      (min_value..max_value).to_a.sort_by do |value|
        [
          (value.to_i - primary.to_i).abs,
          (value.to_i - current.to_i).abs
        ]
      end.first(32)
    rescue
      []
    end

    def transfer_approaches(tx, ty)
      [
        [tx, ty + 1], [tx, ty - 1], [tx - 1, ty], [tx + 1, ty],
        [tx - 1, ty + 1], [tx + 1, ty + 1], [tx - 1, ty - 1], [tx + 1, ty - 1]
      ]
    rescue
      []
    end

    def near_edge_for_rail?(snap, dir, distance = 7)
      bounds = rail_map_bounds
      return false unless bounds && snap
      case dir.to_i
      when 8 then snap["y"].to_i <= distance.to_i
      when 2 then snap["y"].to_i >= bounds["height"].to_i - 1 - distance.to_i
      when 4 then snap["x"].to_i <= distance.to_i
      when 6 then snap["x"].to_i >= bounds["width"].to_i - 1 - distance.to_i
      else false
      end
    rescue
      false
    end

    def rail_map_bounds
      return nil unless defined?($game_map) && $game_map
      width = $game_map.respond_to?(:width) ? $game_map.width.to_i : 0
      height = $game_map.respond_to?(:height) ? $game_map.height.to_i : 0
      return nil if width <= 0 || height <= 0
      { "width" => width, "height" => height }
    rescue
      nil
    end

    def rail_follow_floor_transfer(label, record, snap)
      record = stringify_hash(record || {})
      live = live_transfer_xy(record)
      tx = (live && live[0] || record["x"]).to_i
      ty = (live && live[1] || record["y"]).to_i
      return false if tx == 0 && ty == 0 && !record["x"] && !record["y"]
      rail_follow(
        "#{label} floor",
        [tx, ty],
        transfer_approaches(tx, ty),
        snap
      )
    rescue => e
      @rail_action = "#{label}: floor error #{e.class}"
      false
    end

    def floor_transfer_like?(record, snap)
      map_id = (snap && snap["map_id"] || current_map_id).to_i
      room_ids = dconst(:PLAYER_ROOM_MAP_IDS, [71, 67, 68, 69, 70, 73])
      house_ids = dconst(:PLAYER_HOUSE_MAP_IDS, [43, 3])
      return true if Array(room_ids).map(&:to_i).include?(map_id)
      return true if Array(house_ids).map(&:to_i).include?(map_id)
      return true if oak_lab?(map_id)
      return true if map_id == dconst(:VIRIDIAN_MART_MAP_ID, 81).to_i
      return true if map_id == dconst(:PEWTER_GYM_MAP_ID, 386).to_i

      name = current_map_name_for_transfer(map_id)
      return true if name =~ /room|house|mart|center|centre|gym|gate|lab|museum|hotel|cafe|store|tower|cave|sewer|building|factory|club|mansion/i
      false
    rescue
      false
    end

    def current_map_name_for_transfer(map_id)
      map = current_map_data
      return map["name"].to_s if map && map["name"]
      if defined?(AutoplayBot::WorldScanner)
        index = AutoplayBot::WorldScanner.instance_variable_get(:@index) rescue nil
        names = index && index["map_names"].is_a?(Hash) ? index["map_names"] : nil
        return names[map_id.to_s].to_s if names && names[map_id.to_s]
      end
      ""
    rescue
      ""
    end

    def rail_follow_transfer(label, record, snap)
      return false unless defined?($game_player) && $game_player
      record = stringify_hash(record || {})
      live = live_transfer_xy(record)
      tx = (live && live[0] || record["x"]).to_i
      ty = (live && live[1] || record["y"]).to_i
      return false if tx == 0 && ty == 0 && !record["x"] && !record["y"]

      Navigator.reset!("rail #{label} door") if defined?(AutoplayBot::Navigator) &&
                                                AutoplayBot::Navigator.respond_to?(:reset!) &&
                                                @last_rail_label.to_s != "#{label} door"
      @last_rail_label = "#{label} door"

      x = $game_player.x.to_i
      y = $game_player.y.to_i
      primary = primary_transfer_entry_candidates(tx, ty, record, snap)
      if primary_transfer_entry_tile?(x, y, primary)
        return transfer_entry_pulse(label, tx, ty, snap)
      end
      if !primary.empty?
        primary_path = rail_path_to_any(primary, 700)
        if primary_path && primary_path.empty?
          return transfer_entry_pulse(label, tx, ty, snap)
        elsif primary_path && !primary_path.empty?
          dir = primary_path.first.to_i
          if rail_dir_passable?(dir)
            @rail_action = "#{label}: align door #{dir_label(dir)} #{primary_path.length}"
            AutoplayBot.status(@rail_action)
            AutoplayBot::InputQueue.hold_dir(dir, rail_hold_path_frames(primary_path, 8)) if defined?(AutoplayBot::InputQueue)
            return true
          end
        end
      end

      candidates = transfer_entry_candidates(tx, ty)
      if transfer_entry_tile?(x, y, tx, ty, candidates)
        return transfer_entry_pulse(label, tx, ty, snap)
      end

      path = rail_path_to_any(candidates, 700)
      if path && path.empty?
        return transfer_entry_pulse(label, tx, ty, snap)
      elsif path && !path.empty?
        dir = path.first.to_i
        if rail_dir_passable?(dir)
          @rail_action = "#{label}: door path #{dir_label(dir)} #{path.length}"
          AutoplayBot.status(@rail_action)
          AutoplayBot::InputQueue.hold_dir(dir, rail_hold_path_frames(path, 8)) if defined?(AutoplayBot::InputQueue)
          return true
        end
        remember_rail_block!(snap, dir, "#{label}_door_blocked")
      end

      if adjacent_to_target?(x, y, tx, ty)
        return transfer_entry_pulse(label, tx, ty, snap)
      end

      dir = rail_best_step_toward(tx, ty)
      if dir
        @rail_action = "#{label}: door probe #{dir_label(dir)}"
        AutoplayBot.status(@rail_action)
        AutoplayBot::InputQueue.hold_dir(dir, rail_hold_frames(dir)) if defined?(AutoplayBot::InputQueue)
        return true
      end

      @rail_action = "#{label}: door no move"
      AutoplayBot.status(@rail_action)
      false
    rescue => e
      @rail_action = "#{label}: door error #{e.class}"
      AutoplayBot.log("transfer rail failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def live_transfer_xy(record)
      return nil unless defined?($game_map) && $game_map && $game_map.respond_to?(:events)
      event_id = record["event_id"]
      if (!event_id || event_id.to_i <= 0) && record["key"]
        parts = record["key"].to_s.split(":")
        event_id = parts[1] if parts.length >= 2
      end
      event = $game_map.events[event_id.to_i] if event_id && event_id.to_i > 0
      return nil unless event && event.respond_to?(:x) && event.respond_to?(:y)
      [event.x.to_i, event.y.to_i]
    rescue
      nil
    end

    def transfer_entry_candidates(tx, ty)
      [
        [tx, ty + 1], [tx, ty], [tx, ty + 2],
        [tx - 1, ty + 1], [tx + 1, ty + 1],
        [tx, ty - 1], [tx, ty - 2],
        [tx - 1, ty - 1], [tx + 1, ty - 1],
        [tx - 1, ty], [tx + 1, ty],
        [tx - 2, ty], [tx + 2, ty]
      ].uniq
    rescue
      []
    end

    def primary_transfer_entry_candidates(tx, ty, record, snap)
      return [] unless door_transfer_like?(record, snap)
      [
        [tx, ty + 1],
        [tx, ty + 2],
        [tx - 1, ty + 1],
        [tx + 1, ty + 1]
      ].uniq.select do |x, y|
        defined?(AutoplayBot::Pathfinder) &&
          AutoplayBot::Pathfinder.respond_to?(:valid_tile?) &&
          AutoplayBot::Pathfinder.valid_tile?(x.to_i, y.to_i)
      end
    rescue
      []
    end

    def primary_transfer_entry_tile?(x, y, primary)
      Array(primary).any? { |entry| entry && entry[0].to_i == x.to_i && entry[1].to_i == y.to_i }
    rescue
      false
    end

    def door_transfer_like?(record, snap)
      return false if floor_transfer_like?(record, snap)
      return false unless record
      ty = record["y"].to_i
      bounds = rail_map_bounds
      return false if bounds && (ty <= 1 || ty >= bounds["height"].to_i - 2)
      text = [record["event_name"], record["name"], record["args"], record["script"], current_map_name_for_transfer(snap && snap["map_id"])].compact.join(" ")
      return true if text =~ /door|entrance|house|mart|center|centre|gym|lab|gate|building|store|shop|museum|cave/i
      true
    rescue
      false
    end

    def transfer_entry_tile?(x, y, tx, ty, candidates = nil)
      return true if adjacent_to_target?(x, y, tx, ty)
      Array(candidates || transfer_entry_candidates(tx, ty)).any? do |entry|
        entry && entry[0].to_i == x.to_i && entry[1].to_i == y.to_i
      end
    rescue
      false
    end

    def transfer_entry_dir(x, y, tx, ty)
      dir = dir_from_to(x, y, tx, ty)
      return dir if dir
      return 8 if x.to_i == tx.to_i && y.to_i > ty.to_i
      return 2 if x.to_i == tx.to_i && y.to_i < ty.to_i
      return 4 if y.to_i == ty.to_i && x.to_i > tx.to_i
      return 6 if y.to_i == ty.to_i && x.to_i < tx.to_i
      bounds = rail_map_bounds
      if bounds
        return 8 if ty.to_i <= 1
        return 2 if ty.to_i >= bounds["height"].to_i - 2
        return 4 if tx.to_i <= 1
        return 6 if tx.to_i >= bounds["width"].to_i - 2
      end
      8
    rescue
      8
    end

    def transfer_entry_pulse(label, tx, ty, snap)
      return false unless defined?(AutoplayBot::InputQueue)
      x = $game_player.x.to_i
      y = $game_player.y.to_i
      dir = transfer_entry_dir(x, y, tx, ty)
      key = [snap && snap["map_id"], label, tx, ty].join(":")
      @door_entry_attempts ||= {}
      data = @door_entry_attempts[key] ||= { "count" => 0, "last_frame" => -9999 }
      frame = SceneObserver.frame_count
      data["count"] = 0 if frame.to_i - data["last_frame"].to_i > 90
      data["last_frame"] = frame.to_i
      data["count"] = data["count"].to_i + 1

      if data["count"].to_i % 9 == 0
        @rail_action = "#{label}: door use"
        AutoplayBot.status(@rail_action)
        AutoplayBot::InputQueue.tap(:USE, 2)
        return true
      end

      if data["count"].to_i % 7 == 0
        back = reverse_dir_for_rail(dir)
        if back && rail_dir_passable?(back)
          @rail_action = "#{label}: door reset #{dir_label(back)}"
          AutoplayBot.status(@rail_action)
          AutoplayBot::InputQueue.hold_dir(back, 4)
          return true
        end
      end

      @rail_action = "#{label}: enter #{dir_label(dir)} ##{data["count"]}"
      AutoplayBot.status(@rail_action)
      AutoplayBot::InputQueue.hold_dir(dir, [rail_hold_frames(dir), 14].max)
      true
    rescue => e
      @rail_action = "#{label}: enter error #{e.class}"
      false
    end

    def rail_follow(label, target, approach_tiles, snap)
      return false unless defined?($game_player) && $game_player
      Navigator.reset!("rail #{label}") if defined?(AutoplayBot::Navigator) &&
                                           AutoplayBot::Navigator.respond_to?(:reset!) &&
                                           @last_rail_label.to_s != label.to_s
      @last_rail_label = label.to_s
      x = $game_player.x.to_i
      y = $game_player.y.to_i
      tx = target[0].to_i
      ty = target[1].to_i
      if x == tx && y == ty
        return floor_transfer_pulse(label, tx, ty, snap) if label.to_s =~ /floor/i
        @rail_action = "#{label}: trigger"
        AutoplayBot.status(@rail_action)
        AutoplayBot::InputQueue.tap(:USE, 2) if defined?(AutoplayBot::InputQueue)
        return true
      end
      if adjacent_to_target?(x, y, tx, ty)
        dir = dir_from_to(x, y, tx, ty)
        if rail_dir_passable?(dir)
          @rail_action = "#{label}: step #{dir_label(dir)}"
          AutoplayBot.status(@rail_action)
          AutoplayBot::InputQueue.hold_dir(dir, rail_hold_frames(dir)) if defined?(AutoplayBot::InputQueue)
          return true
        end
      end
      path = rail_path_to(target, false) || rail_path_to_any(approach_tiles)
      if path && !path.empty?
        dir = path.first.to_i
        if rail_dir_passable?(dir)
          @rail_action = "#{label}: path #{dir_label(dir)} #{path.length}"
          AutoplayBot.status(@rail_action)
          AutoplayBot::InputQueue.hold_dir(dir, rail_hold_frames(dir)) if defined?(AutoplayBot::InputQueue)
          return true
        end
        remember_rail_block!(snap, dir, "#{label}_blocked")
      end
      dir = rail_best_step_toward(tx, ty)
      if dir
        @rail_action = "#{label}: probe #{dir_label(dir)}"
        AutoplayBot.status(@rail_action)
        AutoplayBot::InputQueue.hold_dir(dir, rail_hold_frames(dir)) if defined?(AutoplayBot::InputQueue)
        return true
      end
      @rail_action = "#{label}: no move"
      AutoplayBot.status(@rail_action)
      false
    rescue => e
      @rail_action = "#{label}: error #{e.class}"
      false
    end

    def floor_transfer_pulse(label, tx, ty, snap)
      return false unless defined?(AutoplayBot::InputQueue)
      key = [snap && snap["map_id"], label, tx, ty].join(":")
      @floor_transfer_attempts ||= {}
      data = @floor_transfer_attempts[key] ||= { "count" => 0, "last_frame" => -9999 }
      frame = SceneObserver.frame_count
      data["count"] = 0 if frame.to_i - data["last_frame"].to_i > 90
      data["last_frame"] = frame.to_i
      data["count"] = data["count"].to_i + 1

      if data["count"].to_i > 18
        @rail_action = "#{label}: stuck transfer"
        AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
        AutoplayBot::InputQueue.clear
        fail_goal(@goal || {}, "floor_transfer_stuck") if @goal
        if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.respond_to?(:stop!)
          AutoplayBot::Runtime.stop!("stuck transfer #{label}")
        end
        return true
      end

      dir = floor_transfer_exit_dir(tx, ty, snap)
      if data["count"].to_i % 6 == 0
        back = reverse_dir_for_rail(dir)
        if back && rail_dir_passable?(back)
          @rail_action = "#{label}: floor reset #{dir_label(back)}"
          AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
          AutoplayBot::InputQueue.hold_dir(back, 4)
          return true
        end
      end

      @rail_action = "#{label}: floor step #{dir_label(dir)} ##{data["count"]}"
      AutoplayBot.status(@rail_action) if AutoplayBot.respond_to?(:status)
      AutoplayBot::InputQueue.hold_dir(dir, [rail_hold_frames(dir), 14].max)
      true
    rescue => e
      @rail_action = "#{label}: floor step error #{e.class}"
      false
    end

    def floor_transfer_exit_dir(tx, ty, snap)
      bounds = rail_map_bounds
      if bounds
        return 2 if ty.to_i >= bounds["height"].to_i - 3
        return 8 if ty.to_i <= 2
        return 6 if tx.to_i >= bounds["width"].to_i - 3
        return 4 if tx.to_i <= 2
      end
      sx = snap && snap["x"] ? snap["x"].to_i : (defined?($game_player) && $game_player ? $game_player.x.to_i : tx.to_i)
      sy = snap && snap["y"] ? snap["y"].to_i : (defined?($game_player) && $game_player ? $game_player.y.to_i : ty.to_i)
      dir_from_to(sx, sy, tx, ty) || 2
    rescue
      2
    end

    def rail_follow_edge(label, target, exit_dir, approach_tiles, snap)
      return false unless defined?($game_player) && $game_player
      Navigator.reset!("rail #{label}") if defined?(AutoplayBot::Navigator) &&
                                           AutoplayBot::Navigator.respond_to?(:reset!) &&
                                           @last_rail_label.to_s != label.to_s
      @last_rail_label = label.to_s
      x = $game_player.x.to_i
      y = $game_player.y.to_i
      tx = target[0].to_i
      ty = target[1].to_i
      if x == tx && y == ty || route_edge_exit_ready?(snap, exit_dir)
        @rail_action = "#{label}: exit #{dir_label(exit_dir)}"
        AutoplayBot.status(@rail_action)
        AutoplayBot::InputQueue.hold_dir(exit_dir, rail_hold_frames(exit_dir)) if defined?(AutoplayBot::InputQueue)
        return true
      end
      edge_targets = route_edge_targets(tx, ty, exit_dir, snap)
      path = rail_path_to(target, false) ||
             rail_path_to_any((Array(approach_tiles) + edge_targets).uniq, route_axis_precise_budget(label, snap))
      if path && !path.empty?
        dir = path.first.to_i
        if rail_dir_passable?(dir)
          @rail_action = "#{label}: path #{dir_label(dir)} #{path.length}"
          AutoplayBot.status(@rail_action)
          AutoplayBot::InputQueue.hold_dir(dir, rail_hold_frames(dir)) if defined?(AutoplayBot::InputQueue)
          return true
        end
        remember_rail_block!(snap, dir, "#{label}_blocked")
      end
      dir = rail_best_step_toward(tx, ty)
      if dir
        @rail_action = "#{label}: probe #{dir_label(dir)}"
        AutoplayBot.status(@rail_action)
        AutoplayBot::InputQueue.hold_dir(dir, rail_hold_frames(dir)) if defined?(AutoplayBot::InputQueue)
        return true
      end
      @rail_action = "#{label}: no move"
      AutoplayBot.status(@rail_action)
      false
    rescue => e
      @rail_action = "#{label}: error #{e.class}"
      false
    end

    def route_edge_exit_ready?(snap, exit_dir)
      return false unless snap && near_edge_for_rail?(snap, exit_dir, 2)
      route_passable_from?(snap["x"].to_i, snap["y"].to_i, exit_dir)
    rescue
      false
    end

    def rail_path_to(target, include_adjacent = false, budget = 1200)
      return nil unless defined?(AutoplayBot::Pathfinder)
      key = rail_path_cache_key("one", [[target[0].to_i, target[1].to_i]], budget, include_adjacent)
      cached_rail_path(key) do
        AutoplayBot::Pathfinder.path_to(target[0].to_i, target[1].to_i, budget.to_i, include_adjacent)
      end
    rescue
      nil
    end

    def rail_path_to_any(targets, budget = 1200)
      return nil unless defined?(AutoplayBot::Pathfinder) && AutoplayBot::Pathfinder.respond_to?(:find_path_to_any)
      valid = Array(targets).select do |entry|
        entry && AutoplayBot::Pathfinder.valid_tile?(entry[0].to_i, entry[1].to_i)
      end
      return nil if valid.empty?
      key = rail_path_cache_key("any", valid, budget, false)
      cached_rail_path(key) do
        AutoplayBot::Pathfinder.find_path_to_any(valid, budget.to_i)
      end
    rescue
      nil
    end

    def cached_rail_path(key)
      @rail_path_cache ||= {}
      frame = SceneObserver.frame_count.to_i
      entry = @rail_path_cache[key]
      return entry["path"] if entry && frame - entry["frame"].to_i <= 45
      path = yield
      @rail_path_cache[key] = { "frame" => frame, "path" => path }
      @rail_path_cache.shift while @rail_path_cache.length > 24
      path
    rescue
      yield
    end

    def rail_path_cache_key(kind, targets, budget, include_adjacent)
      pos = defined?($game_player) && $game_player ? [$game_player.x, $game_player.y] : [nil, nil]
      compact_targets = Array(targets).first(16).map { |x, y| "#{x.to_i},#{y.to_i}" }.join(";")
      [
        kind,
        current_map_id,
        pos[0],
        pos[1],
        budget.to_i,
        include_adjacent ? 1 : 0,
        compact_targets
      ].join("|")
    rescue
      "#{kind}|#{current_map_id}|unknown"
    end

    def adjacent_to_target?(x, y, tx, ty)
      (x.to_i - tx.to_i).abs + (y.to_i - ty.to_i).abs == 1
    rescue
      false
    end

    def dir_from_to(x, y, tx, ty)
      return 6 if tx.to_i > x.to_i && ty.to_i == y.to_i
      return 4 if tx.to_i < x.to_i && ty.to_i == y.to_i
      return 2 if ty.to_i > y.to_i && tx.to_i == x.to_i
      return 8 if ty.to_i < y.to_i && tx.to_i == x.to_i
      nil
    rescue
      nil
    end

    def rail_best_step_toward(tx, ty)
      return nil unless defined?($game_player) && $game_player
      x = $game_player.x.to_i
      y = $game_player.y.to_i
      dx = tx.to_i - x
      dy = ty.to_i - y
      ordered = []
      if dx.abs >= dy.abs
        ordered << (dx > 0 ? 6 : 4) if dx != 0
        ordered << (dy > 0 ? 2 : 8) if dy != 0
      else
        ordered << (dy > 0 ? 2 : 8) if dy != 0
        ordered << (dx > 0 ? 6 : 4) if dx != 0
      end
      ordered.concat([8, 2, 4, 6])
      ordered.compact.uniq.find { |dir| rail_dir_passable?(dir) }
    rescue
      nil
    end

    def rail_dir_passable?(dir)
      return false unless [2, 4, 6, 8].include?(dir.to_i)
      return false unless defined?($game_player) && $game_player
      if defined?(AutoplayBot::Navigator) &&
         AutoplayBot::Navigator.respond_to?(:live_event_blocked_from_player?) &&
         AutoplayBot::Navigator.live_event_blocked_from_player?(dir)
        return false
      end
      return $game_player.can_move_in_direction?(dir) if $game_player.respond_to?(:can_move_in_direction?)
      return AutoplayBot::Pathfinder.passable?($game_player.x, $game_player.y, dir) if defined?(AutoplayBot::Pathfinder)
      $game_player.passable?($game_player.x, $game_player.y, dir)
    rescue
      false
    end

    def remember_rail_block!(snap, dir, reason)
      return if transient_rail_block_reason?(reason)
      return unless defined?(AutoplayBot::Director) && AutoplayBot::Director.respond_to?(:remember_blocked_step!)
      AutoplayBot::Director.remember_blocked_step!([snap["map_id"], snap["x"], snap["y"]], dir, reason)
    rescue
      nil
    end

    def transient_rail_block_reason?(reason)
      text = reason.to_s.downcase
      return true if text.include?("patrol_stalled")
      return true if text.include?("enter_stalled")
      return true if text.include?("enter_blocked")
      return true if text.include?("grass_dir_blocked")
      return true if text.include?("grass")
      return true if text.include?("fallback")
      false
    rescue
      false
    end

    def rail_hold_frames(dir)
      minimum = rail_speedup_multiplier >= 7 ? 4 : 6
      if defined?(AutoplayBot::Director) && AutoplayBot::Director.respond_to?(:movement_hold_frames)
        return AutoplayBot::Director.movement_hold_frames([dir], minimum)
      end
      8
    rescue
      8
    end

    def rail_hold_path_frames(path, minimum = 6)
      segment = Array(path).map(&:to_i)
      return rail_hold_frames(segment.first) if segment.empty?
      speed = rail_speedup_multiplier
      adjusted_minimum = minimum.to_i
      adjusted_minimum = [adjusted_minimum, 4].min if speed >= 7
      adjusted_minimum = [adjusted_minimum, 5].min if speed >= 3
      if defined?(AutoplayBot::Director) && AutoplayBot::Director.respond_to?(:movement_hold_frames)
        return AutoplayBot::Director.movement_hold_frames(segment, adjusted_minimum)
      end
      [segment.take_while { |dir| dir == segment.first }.length * 8, adjusted_minimum].max
    rescue
      rail_hold_frames(Array(path).first || 2)
    end

    def rail_speedup_multiplier
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.respond_to?(:game_speed_multiplier)
        return AutoplayBot::Runtime.game_speed_multiplier.to_i
      end
      defined?($GameSpeed) ? $GameSpeed.to_i : 1
    rescue
      1
    end

    def dir_label(dir)
      if defined?(AutoplayBot::Navigator) && AutoplayBot::Navigator.respond_to?(:dir_label)
        return AutoplayBot::Navigator.dir_label(dir)
      end
      case dir.to_i
      when 2 then "down"
      when 4 then "left"
      when 6 then "right"
      when 8 then "up"
      else "dir"
      end
    rescue
      "dir"
    end

    def player_house_related?(map_id)
      d = AutoplayBot::Director
      ids = []
      ids += d.const_get(:PLAYER_ROOM_MAP_IDS) if d.const_defined?(:PLAYER_ROOM_MAP_IDS)
      ids += d.const_get(:PLAYER_HOUSE_MAP_IDS) if d.const_defined?(:PLAYER_HOUSE_MAP_IDS)
      ids.include?(map_id.to_i)
    rescue
      [71, 43, 3].include?(map_id.to_i)
    end

    def oak_lab?(map_id)
      ids = dconst(:OAK_LAB_MAP_IDS, [77, 659])
      ids.include?(map_id.to_i)
    rescue
      false
    end

    def local_discovery?
      !defined?(AutoplayBot::Config) || AutoplayBot::Config.local_discovery?
    rescue
      true
    end

    def collect_radius(story)
      base = defined?(AutoplayBot::Config) ? AutoplayBot::Config.local_discovery_distance : 10
      story ? [base.to_i, 14].max : [base.to_i, 18].max
    rescue
      12
    end

    def npc_radius(story)
      story ? 5 : 9
    rescue
      5
    end

    def building_radius(story)
      story ? 4 : 8
    rescue
      6
    end

    def strong_story_pressure?
      return true unless trainer_has_pokedex?
      false
    rescue
      true
    end

    def target_done_or_failed?(record, kind)
      if defined?(AutoplayBot::Navigator) &&
         AutoplayBot::Navigator.respond_to?(:target_locally_failed?) &&
         AutoplayBot::Navigator.target_locally_failed?(record, kind)
        return true
      end
      return false unless state_memory_ready?
      if repeatable_trainer_target?(record, kind)
        if AutoplayBot::State.respond_to?(:trainer_done_for_now?) &&
           AutoplayBot::State.trainer_done_for_now?(record)
          return true
        end
        return true if AutoplayBot::State.respond_to?(:target_failed?) && AutoplayBot::State.target_failed?(record, 300, kind)
        return false
      end
      return true if AutoplayBot::State.respond_to?(:target_done?) && AutoplayBot::State.target_done?(record, kind)
      return true if AutoplayBot::State.respond_to?(:target_failed?) && AutoplayBot::State.target_failed?(record, 300, kind)
      false
    rescue
      false
    end

    def repeatable_trainer_target?(record, kind = nil)
      return false unless record.is_a?(Hash)
      text = [kind, record["kind"], record["type"], record["trainer_key"], record["call"], record["repeatable_status"], record["repeatable_reason"], record["event_name"], record["name"]].compact.join(" ")
      return false unless text =~ /trainer|pbTrainerBattle/i
      return true if kind.to_s == "trainer" || record["trainer_key"] || text =~ /pbTrainerBattle/i
      text =~ /confirmed_repeatable|likely_repeatable|rematch|re[- ]?battle|repeat|versus seeker|vs\.?\s*seeker|canRematch/i
    rescue
      false
    end

    def mark_local_target_failed(record, kind, reason)
      return unless record
      if defined?(AutoplayBot::Navigator) && AutoplayBot::Navigator.respond_to?(:fail_goal_record)
        AutoplayBot::Navigator.fail_goal_record(record, kind, reason)
      elsif state_memory_ready? && AutoplayBot::State.respond_to?(:mark_target_attempted)
        AutoplayBot::State.mark_target_attempted(record, reason, kind)
      end
    rescue
      nil
    end

    def attempts_exhausted?(record, kind)
      return false unless state_memory_ready? && AutoplayBot::State.respond_to?(:target_attempt_count)
      AutoplayBot::State.target_attempt_count(record, kind).to_i >= target_attempt_limit(kind)
    rescue
      false
    end

    def target_attempt_limit(kind)
      text = kind.to_s
      return 3 if text =~ /item|resource|gift|static/
      return 4 if text =~ /building|transfer/
      return 5
    rescue
      5
    end

    def same_target?(a, b)
      return false unless a && b
      return true if a["key"] && b["key"] && a["key"].to_s == b["key"].to_s
      a["x"].to_i == b["x"].to_i && a["y"].to_i == b["y"].to_i && a["map_id"].to_i == b["map_id"].to_i
    rescue
      false
    end

    def manhattan(record, snap)
      (record["x"].to_i - snap["x"].to_i).abs + (record["y"].to_i - snap["y"].to_i).abs
    rescue
      9999
    end

    def objective(id, type, label)
      return unless state_write_allowed?
      current = AutoplayBot::State.current_objective rescue nil
      return if current && current["id"].to_s == id.to_s
      AutoplayBot::State.current_objective = {
        "id" => id,
        "type" => type,
        "label" => label,
        "map_id" => current_map_id,
        "time" => Time.now.to_i
      }
    rescue
      nil
    end

    def record_goal(goal)
      return unless state_write_allowed?
      record = goal["record"].is_a?(Hash) ? goal["record"] : goal
      AutoplayBot::State.record_active_goal(
        "kind" => goal["kind"],
        "target_kind" => goal["target_kind"],
        "label" => goal["label"],
        "target" => Navigator.goal_key(goal),
        "score" => goal["score"],
        "path" => Navigator.path_length,
        "map_id" => record["map_id"],
        "x" => record["x"],
        "y" => record["y"]
      )
    rescue
      nil
    end

    def set_mode(mode)
      AutoplayBot::State.set_runtime_mode(mode) if state_write_allowed? && AutoplayBot::State.respond_to?(:set_runtime_mode)
    rescue
      nil
    end

    def state_memory_ready?
      return false unless defined?(AutoplayBot::State)
      return true unless AutoplayBot::State.respond_to?(:loaded?)
      AutoplayBot::State.loaded?
    rescue
      false
    end

    def state_deferred?
      defined?(AutoplayBot::Runtime) &&
        AutoplayBot::Runtime.respond_to?(:state_deferred?) &&
        AutoplayBot::Runtime.state_deferred?
    rescue
      false
    end

    def state_write_allowed?
      return false unless defined?(AutoplayBot::State)
      return true if state_memory_ready?
      return false if cold_start?
      return false if state_deferred?
      false
    rescue
      false
    end

    def mode_for_goal(goal)
      case goal["kind"].to_s
      when "nearby_collect" then "frontier_explore"
      when "nearby_npc", "nearby_building" then "navigation"
      when "heal" then "recovery"
      when "shop" then "shop"
      when "battle" then "battle"
      else goal["target_kind"].to_s == "battle" ? "battle" : "navigation"
      end
    rescue
      "navigation"
    end

    def status_once(text)
      return if @last_status == text
      @last_status = text
      AutoplayBot.status(text) if AutoplayBot.respond_to?(:status)
    rescue
      nil
    end

    def current_map_id
      defined?($game_map) && $game_map ? $game_map.map_id : nil
    rescue
      nil
    end

    def dconst(name, fallback = nil)
      return fallback unless defined?(AutoplayBot::Director)
      AutoplayBot::Director.const_defined?(name) ? AutoplayBot::Director.const_get(name) : fallback
    rescue
      fallback
    end

    def drecord(name, fallback = {})
      value = dconst(name, fallback)
      stringify_hash(value)
    rescue
      stringify_hash(fallback)
    end

    def dcall(name, default = nil)
      return default unless defined?(AutoplayBot::Director) && AutoplayBot::Director.respond_to?(name)
      AutoplayBot::Director.send(name)
    rescue
      default
    end

    def game_switch?(id)
      if defined?(AutoplayBot::Director) && AutoplayBot::Director.respond_to?(:game_switch?)
        return AutoplayBot::Director.game_switch?(id)
      end
      defined?($game_switches) && $game_switches && $game_switches[id.to_i] == true
    rescue
      false
    end

    def trainer_has_pokedex?
      dcall(:trainer_has_pokedex?, false)
    end

    def starter_obtained?
      dcall(:starter_obtained?, false)
    end

    def starter_clothes_ready?
      dcall(:starter_clothes_ready?, true)
    end

    def first_badge_obtained?
      dcall(:first_badge_obtained?, false)
    end

    def preferred_lab_map_id
      dcall(:preferred_lab_map_id, 77)
    end

    def stringify_hash(hash)
      out = {}
      hash.each { |k, v| out[k.to_s] = v } if hash.respond_to?(:each)
      out
    rescue
      {}
    end

    def startup_overlay_line
      if cold_start?
        return "Startup #{debug_spinner} scene settle #{format('%.1f', cold_start_remaining_seconds)}s | scan deferred"
      end
      if state_deferred?
        return "Startup #{debug_spinner} memory deferred | live map only"
      end
      snap = SceneObserver.last_snapshot rescue nil
      if snap && snap["scene"].to_s == "map" &&
         (!@active_goal || @active_goal.empty?) &&
         (!@rail_action || @rail_action.to_s.empty?)
        return "Think #{debug_spinner} #{short(no_goal_hint(snap), 48)}"
      end
      nil
    rescue
      nil
    end

    def cold_start_remaining_seconds
      frame_left = 0.0
      if @cold_start_until_frame
        frame_left = [@cold_start_until_frame.to_i - SceneObserver.frame_count.to_i, 0].max.to_f / 60.0
      end
      time_left = @cold_start_until_at ? [@cold_start_until_at.to_f - botcore_now, 0.0].max : 0.0
      [frame_left, time_left].max
    rescue
      0.0
    end

    def no_goal_hint(snap)
      if wild_capture_focus_active?
        method = defined?(AutoplayBot::DexHuntPlanner) &&
                 AutoplayBot::DexHuntPlanner.respond_to?(:detect_zone_method) ?
                   AutoplayBot::DexHuntPlanner.detect_zone_method(snap) : nil
        return "hunt zone #{method}; choosing patrol" if method
        return "no local encounter zone; seeking route/grass"
      end
      "choosing map goal"
    rescue
      "choosing goal"
    end

    def debug_spinner
      ["-", "\\", "|", "/"][(SceneObserver.frame_count.to_i / 12) % 4]
    rescue
      "-"
    end

    def debug_overlay_lines
      snap = SceneObserver.last_snapshot rescue nil
      lines = []
      if snap
        bits = ["Scene #{snap["scene"]}"]
        bits << short(snap["detail"], 20) if snap["detail"] && snap["detail"].to_s != snap["scene"].to_s
        lines << bits.join(" | ")
      end
      goal = @active_goal
      if goal
        detail = "Goal #{short(goal["label"], 34)}"
        detail += " | Rail #{short(@rail_action, 26)}" if @rail_action && !@rail_action.to_s.empty?
        lines << detail
      elsif @rail_action && !@rail_action.to_s.empty?
        lines << "Rail #{short(@rail_action, 54)}"
      end
      queued_input = queued_input_overlay_line
      lines << queued_input if queued_input
      lines.concat(AutoplayBot::WorldCoveragePlanner.debug_overlay_lines) if defined?(AutoplayBot::WorldCoveragePlanner)
      lines.concat(AutoplayBot::DexHuntPlanner.debug_overlay_lines) if defined?(AutoplayBot::DexHuntPlanner)
      lines.concat(Navigator.debug_overlay_lines) if defined?(AutoplayBot::Navigator)
      lines[0, 4]
    rescue
      []
    end

    def queued_input_overlay_line
      return nil unless defined?(AutoplayBot::InputQueue) &&
                        AutoplayBot::InputQueue.respond_to?(:dir_frames_remaining) &&
                        AutoplayBot::InputQueue.respond_to?(:dir4)
      frames = AutoplayBot::InputQueue.dir_frames_remaining.to_i
      dir = AutoplayBot::InputQueue.dir4.to_i
      return nil unless frames > 0 && [2, 4, 6, 8].include?(dir)
      "Input #{botcore_dir_label(dir)} #{frames}f"
    rescue
      nil
    end

    def botcore_dir_label(dir)
      case dir.to_i
      when 2 then "down"
      when 4 then "left"
      when 6 then "right"
      when 8 then "up"
      else "dir"
      end
    rescue
      "dir"
    end

    def short(text, max)
      value = text.to_s.gsub(/\s+/, " ").strip
      value.length > max.to_i ? value[0, max.to_i - 3] + "..." : value
    rescue
      ""
    end
  end
end
