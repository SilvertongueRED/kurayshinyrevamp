module AutoplayBot
  module JSON
    module_function

    def dump(obj, indent = 0)
      return ModManager::JSON.dump(obj, indent) if defined?(ModManager::JSON)
      case obj
      when Hash
        return "{}" if obj.empty?
        space = "  " * (indent + 1)
        parts = obj.map { |k, v| "\n#{space}\"#{escape(k.to_s)}\": #{dump(v, indent + 1)}" }
        "{" + parts.join(",") + "\n" + ("  " * indent) + "}"
      when Array
        return "[]" if obj.empty?
        space = "  " * (indent + 1)
        parts = obj.map { |v| "\n#{space}#{dump(v, indent + 1)}" }
        "[" + parts.join(",") + "\n" + ("  " * indent) + "]"
      when String
        "\"#{escape(obj)}\""
      when Integer, Float
        obj.to_s
      when TrueClass
        "true"
      when FalseClass
        "false"
      when NilClass
        "null"
      else
        "\"#{escape(obj.to_s)}\""
      end
    end

    def parse(str)
      return ModManager::JSON.parse(str) if defined?(ModManager::JSON)
      @s = str.to_s
      @i = 0
      read_value
    end

    def escape(str)
      str.to_s.gsub(/["\\\b\f\r\t\n]/) do |m|
        case m
        when '"' then "\\\""
        when "\\" then "\\\\"
        when "\b" then "\\b"
        when "\f" then "\\f"
        when "\r" then "\\r"
        when "\t" then "\\t"
        when "\n" then "\\n"
        else m
        end
      end
    end

    def skip_ws
      @i += 1 while @i < @s.length && @s[@i, 1] =~ /\s/
    end

    def read_value
      skip_ws
      return nil if @i >= @s.length
      case @s[@i, 1]
      when "{" then read_object
      when "[" then read_array
      when "\"" then read_string
      when "t" then @i += 4; true
      when "f" then @i += 5; false
      when "n" then @i += 4; nil
      else read_number
      end
    end

    def read_object
      out = {}
      @i += 1
      skip_ws
      if @s[@i, 1] == "}"
        @i += 1
        return out
      end
      loop do
        key = read_string
        skip_ws
        @i += 1 if @s[@i, 1] == ":"
        out[key] = read_value
        skip_ws
        break if @s[@i, 1] == "}" && (@i += 1)
        @i += 1 if @s[@i, 1] == ","
      end
      out
    end

    def read_array
      out = []
      @i += 1
      skip_ws
      if @s[@i, 1] == "]"
        @i += 1
        return out
      end
      loop do
        out << read_value
        skip_ws
        break if @s[@i, 1] == "]" && (@i += 1)
        @i += 1 if @s[@i, 1] == ","
      end
      out
    end

    def read_string
      out = ""
      @i += 1
      while @i < @s.length
        ch = @s[@i, 1]
        @i += 1
        break if ch == "\""
        if ch == "\\"
          esc = @s[@i, 1]
          @i += 1
          out << case esc
                 when "\"", "\\", "/" then esc
                 when "b" then "\b"
                 when "f" then "\f"
                 when "n" then "\n"
                 when "r" then "\r"
                 when "t" then "\t"
                 else esc.to_s
                 end
        else
          out << ch
        end
      end
      out
    end

    def read_number
      start = @i
      @i += 1 while @i < @s.length && @s[@i, 1] =~ /[-+0-9.eE]/
      raw = @s[start...@i].to_s
      return raw.to_f if raw.include?(".") || raw.include?("e") || raw.include?("E")
      Integer(raw) rescue 0
    end
  end

  module State
    module_function

    MAX_FAILURE_EVENTS = 30 unless const_defined?(:MAX_FAILURE_EVENTS)
    MAX_MANUAL_NOTES = 20 unless const_defined?(:MAX_MANUAL_NOTES)
    MAX_FRONTIER_QUEUE = 60 unless const_defined?(:MAX_FRONTIER_QUEUE)
    MAX_CLEANUP_QUEUE = 80 unless const_defined?(:MAX_CLEANUP_QUEUE)
    MAX_RESOURCE_SNAPSHOTS = 10 unless const_defined?(:MAX_RESOURCE_SNAPSHOTS)
    MAX_TEAM_SNAPSHOTS = 6 unless const_defined?(:MAX_TEAM_SNAPSHOTS)
    MAX_STORAGE_SNAPSHOTS = 6 unless const_defined?(:MAX_STORAGE_SNAPSHOTS)
    MAX_STORAGE_DECISIONS = 20 unless const_defined?(:MAX_STORAGE_DECISIONS)
    MAX_BATTLE_REWARDS = 10 unless const_defined?(:MAX_BATTLE_REWARDS)
    MAX_PURCHASE_HISTORY = 20 unless const_defined?(:MAX_PURCHASE_HISTORY)
    MAX_STUCK_SIGNATURES = 50 unless const_defined?(:MAX_STUCK_SIGNATURES)
    MAX_MAP_KNOWLEDGE_MAPS = 48 unless const_defined?(:MAX_MAP_KNOWLEDGE_MAPS)
    MAX_MAP_TARGETS = 64 unless const_defined?(:MAX_MAP_TARGETS)
    MAX_HUNT_ZONES = 96 unless const_defined?(:MAX_HUNT_ZONES)
    MAX_HUNT_SESSIONS = 24 unless const_defined?(:MAX_HUNT_SESSIONS)
    MAX_SPECIES_TARGETS = 256 unless const_defined?(:MAX_SPECIES_TARGETS)
    MAX_CATCH_ATTEMPTS = 256 unless const_defined?(:MAX_CATCH_ATTEMPTS)
    MAX_ATLAS_MAPS = 160 unless const_defined?(:MAX_ATLAS_MAPS)
    MAX_ATLAS_ROUTES = 80 unless const_defined?(:MAX_ATLAS_ROUTES)
    MAX_ATLAS_GATES = 80 unless const_defined?(:MAX_ATLAS_GATES)
    TRAINER_REPEAT_BATTLE_LIMIT = 2 unless const_defined?(:TRAINER_REPEAT_BATTLE_LIMIT)
    TRAINER_ROCKET_CAPTURE_LIMIT = 1 unless const_defined?(:TRAINER_ROCKET_CAPTURE_LIMIT)
    TRAINER_ROCKET_ATTEMPT_LIMIT = 3 unless const_defined?(:TRAINER_ROCKET_ATTEMPT_LIMIT)

    def data
      if !@loaded
        runtime_live? ? load_ephemeral!("live runtime") : load!
      end
      @data
    end

    def runtime_live?
      return false unless defined?(AutoplayBot::Runtime)
      return true if AutoplayBot::Runtime.respond_to?(:active?) && AutoplayBot::Runtime.active?
      return true if AutoplayBot::Runtime.respond_to?(:startup_diagnostics_active?) &&
                     AutoplayBot::Runtime.startup_diagnostics_active?
      false
    rescue
      false
    end

    def load_ephemeral!(reason = "live runtime")
      ensure_dirs
      @data = default_data
      @loaded = true
      @ephemeral = true
      @dirty = false
      @last_save_frame = 0
      normalize!
      unless @ephemeral_logged
        AutoplayBot.log("state memory is live-only: #{reason}") if AutoplayBot.respond_to?(:log)
        @ephemeral_logged = true
      end
      @data
    rescue => e
      @data = default_data
      @loaded = true
      @ephemeral = true
      @dirty = false
      AutoplayBot.log("state live-only init failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      @data
    end

    def load!
      ensure_dirs
      if File.exist?(AutoplayBot::STATE_FILE)
        begin
          raw = File.read(AutoplayBot::STATE_FILE)
          raw = raw[3..-1].to_s if raw && raw[0, 3] == "\xEF\xBB\xBF"
          parsed = AutoplayBot::JSON.parse(raw)
          @data = parsed.is_a?(Hash) ? parsed : default_data
        rescue => e
          @data = default_data
          AutoplayBot.log("state load failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
        end
      else
        @data = default_data
      end
      @loaded = true
      @ephemeral = false
      @dirty = false
      @last_save_frame = 0
      normalize!
      @data
    end

    def loaded?
      @loaded == true
    rescue
      false
    end

    def ephemeral?
      @ephemeral == true
    rescue
      false
    end

    def ensure_dirs
      [AutoplayBot::DATA_DIR, AutoplayBot::CACHE_DIR, AutoplayBot::LOG_DIR].each do |dir|
        Dir.mkdir(dir) unless File.directory?(dir)
      rescue
        nil
      end
    end

    def default_data
      {
        "version" => 1,
        "global" => {
          "created_at" => Time.now.to_i,
          "last_log" => nil
        },
        "saves" => {}
      }
    end

    def save_key
      trainer_name = nil
      trainer_id = nil
      trainer_name = $Trainer.name if defined?($Trainer) && $Trainer && $Trainer.respond_to?(:name)
      trainer_id = $Trainer.id if defined?($Trainer) && $Trainer && $Trainer.respond_to?(:id)
      name_part = trainer_name && !trainer_name.to_s.empty? ? trainer_name.to_s : "boot"
      id_part = trainer_id ? trainer_id.to_s : "noid"
      "#{name_part}_#{id_part}"
    rescue
      "boot_noid"
    end

    def save_bucket
      key = save_key
      data["saves"][key] ||= default_save_bucket
      ensure_save_bucket_schema(data["saves"][key])
    end

    def default_save_bucket
      {
        "first_seen_at" => Time.now.to_i,
        "last_seen_at" => Time.now.to_i,
        "mode" => "idle",
        "current_objective" => nil,
        "visited_transfers" => {},
        "visited_maps" => {},
        "completed_targets" => {},
        "observed_encounters" => {},
        "caught_species" => {},
        "desired_duplicates" => {},
        "deferred_targets" => {},
        "prime_directive" => {},
        "fusion_seen" => {},
        "fusion_owned" => {},
        "failure_events" => [],
        "blackouts" => [],
        "battle_losses" => [],
        "manual_notes" => [],
        "stuck_counters" => {},
        "runtime_mode" => "story",
        "last_heal_hub" => nil,
        "last_heal_route" => nil,
        "active_goal" => nil,
        "route_anchor" => nil,
        "frontier_queue" => [],
        "cleanup_queue" => [],
        "map_knowledge" => {},
        "failed_targets" => {},
        "attempted_targets" => {},
        "resource_plan" => {},
        "shop_stock_memory" => {},
        "purchase_history" => [],
        "trainer_ledger" => {},
        "repeatable_battles" => {},
        "battle_reward_history" => [],
        "farm_cooldowns" => {},
        "resource_snapshots" => [],
        "team_plan" => nil,
        "team_snapshots" => [],
        "storage_snapshot" => nil,
        "storage_snapshots" => [],
        "storage_decisions" => [],
        "hunt_zones" => {},
        "species_targets" => {},
        "hunt_sessions" => [],
        "zone_cooldowns" => {},
        "catch_attempts" => {},
        "team_rotation_plan" => nil,
        "world_atlas" => {
          "maps" => {},
          "routes" => {},
          "ability_gates" => {},
          "last_plan" => nil
        },
        "objective_retries" => {},
        "training_plan" => nil,
        "recovery_plan" => nil,
        "stuck_signatures" => {},
        "last_stuck_signature" => nil,
        "last_position" => nil
      }
    end

    def normalize!
      data["version"] ||= 1
      data["global"] ||= {}
      data["saves"] ||= {}
      data["saves"].each_value do |bucket|
        next unless bucket.is_a?(Hash)
        ensure_save_bucket_schema(bucket)
        compact_save_bucket!(bucket)
      end
    rescue
      nil
    end

    def ensure_save_bucket_schema(bucket = nil)
      bucket ||= save_bucket
      defaults = default_save_bucket
      defaults.each do |key, value|
        next if bucket.key?(key)
        bucket[key] = deep_copy(value)
        mark_dirty
      end
      bucket
    rescue
      bucket
    end

    def compact_save_bucket!(bucket)
      cap_array!(bucket, "failure_events", MAX_FAILURE_EVENTS)
      cap_array!(bucket, "manual_notes", MAX_MANUAL_NOTES)
      cap_array!(bucket, "frontier_queue", MAX_FRONTIER_QUEUE)
      cap_array!(bucket, "cleanup_queue", MAX_CLEANUP_QUEUE)
      cap_array!(bucket, "resource_snapshots", MAX_RESOURCE_SNAPSHOTS)
      cap_array!(bucket, "team_snapshots", MAX_TEAM_SNAPSHOTS)
      cap_array!(bucket, "storage_snapshots", MAX_STORAGE_SNAPSHOTS)
      cap_array!(bucket, "storage_decisions", MAX_STORAGE_DECISIONS)
      cap_array!(bucket, "battle_reward_history", MAX_BATTLE_REWARDS)
      cap_array!(bucket, "purchase_history", MAX_PURCHASE_HISTORY)
      cap_array!(bucket, "hunt_sessions", MAX_HUNT_SESSIONS)
      cap_hash_by_time!(bucket, "stuck_signatures", MAX_STUCK_SIGNATURES)
      cap_hash_by_time!(bucket, "hunt_zones", MAX_HUNT_ZONES)
      cap_hash_by_time!(bucket, "species_targets", MAX_SPECIES_TARGETS)
      cap_hash_by_time!(bucket, "catch_attempts", MAX_CATCH_ATTEMPTS)
      cap_hash_by_time!(bucket, "zone_cooldowns", MAX_HUNT_ZONES)
      compact_world_atlas!(bucket)
      compact_map_knowledge!(bucket)
    rescue
      nil
    end

    def cap_array!(bucket, key, max)
      list = bucket[key]
      return unless list.is_a?(Array)
      return if list.length <= max.to_i
      bucket[key] = list[-max.to_i, max.to_i] || []
      mark_dirty
    rescue
      nil
    end

    def cap_hash_by_time!(bucket, key, max)
      hash = bucket[key]
      return unless hash.is_a?(Hash)
      return if hash.length <= max.to_i
      kept = {}
      hash.to_a.sort_by { |pair| timed_entry_sort_value(pair[1]) }.last(max.to_i).each do |pair|
        kept[pair[0]] = pair[1]
      end
      bucket[key] = kept
      mark_dirty
    rescue
      nil
    end

    def compact_map_knowledge!(bucket)
      knowledge = bucket["map_knowledge"]
      return unless knowledge.is_a?(Hash)
      if knowledge.length > MAX_MAP_KNOWLEDGE_MAPS
        kept = {}
        knowledge.to_a.sort_by { |pair| timed_entry_sort_value(pair[1]) }.last(MAX_MAP_KNOWLEDGE_MAPS).each do |pair|
          kept[pair[0]] = pair[1]
        end
        bucket["map_knowledge"] = knowledge = kept
        mark_dirty
      end
      knowledge.each_value do |entry|
        next unless entry.is_a?(Hash)
        targets = entry["targets"]
        next unless targets.is_a?(Hash)
        next if targets.length <= MAX_MAP_TARGETS
        kept_targets = {}
        targets.to_a.sort_by { |pair| timed_entry_sort_value(pair[1]) }.last(MAX_MAP_TARGETS).each do |pair|
          kept_targets[pair[0]] = pair[1]
        end
        entry["targets"] = kept_targets
        mark_dirty
      end
    rescue
      nil
    end

    def compact_world_atlas!(bucket)
      atlas = bucket["world_atlas"]
      return unless atlas.is_a?(Hash)
      atlas["maps"] ||= {}
      atlas["routes"] ||= {}
      atlas["ability_gates"] ||= {}
      if atlas["maps"].is_a?(Hash) && atlas["maps"].length > MAX_ATLAS_MAPS
        kept = {}
        atlas["maps"].to_a.sort_by { |pair| timed_entry_sort_value(pair[1]) }.last(MAX_ATLAS_MAPS).each do |pair|
          kept[pair[0]] = pair[1]
        end
        atlas["maps"] = kept
        mark_dirty
      end
      if atlas["routes"].is_a?(Hash) && atlas["routes"].length > MAX_ATLAS_ROUTES
        kept = {}
        atlas["routes"].to_a.sort_by { |pair| timed_entry_sort_value(pair[1]) }.last(MAX_ATLAS_ROUTES).each do |pair|
          kept[pair[0]] = pair[1]
        end
        atlas["routes"] = kept
        mark_dirty
      end
      if atlas["ability_gates"].is_a?(Hash) && atlas["ability_gates"].length > MAX_ATLAS_GATES
        kept = {}
        atlas["ability_gates"].to_a.sort_by { |pair| timed_entry_sort_value(pair[1]) }.last(MAX_ATLAS_GATES).each do |pair|
          kept[pair[0]] = pair[1]
        end
        atlas["ability_gates"] = kept
        mark_dirty
      end
    rescue
      nil
    end

    def timed_entry_sort_value(entry)
      return 0 unless entry.is_a?(Hash)
      entry["last_seen_at"].to_i > 0 ? entry["last_seen_at"].to_i : entry["time"].to_i
    rescue
      0
    end

    def deep_copy(value)
      Marshal.load(Marshal.dump(value))
    rescue
      value
    end

    def mark_dirty
      @dirty = true
    end

    def save!(force = false)
      return unless @loaded
      return if @ephemeral
      return if !force && !@dirty
      ensure_dirs
      data["global"]["last_saved_at"] = Time.now.to_i
      save_bucket["last_seen_at"] = Time.now.to_i
      File.open(AutoplayBot::STATE_FILE, "w") { |f| f.write(AutoplayBot::JSON.dump(data)) }
      @dirty = false
    rescue => e
      AutoplayBot.log("state save failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def maybe_save(frame_count)
      @last_save_frame ||= 0
      return if frame_count.to_i - @last_save_frame.to_i < 300
      @last_save_frame = frame_count.to_i
      save!
    end

    def postpone_save(frame_count = nil)
      @last_save_frame = frame_count || (Graphics.frame_count rescue 0)
    rescue
      @last_save_frame = 0
    end

    def set_mode(mode)
      save_bucket["mode"] = mode.to_s
      mark_dirty
    end

    def runtime_mode
      save_bucket["runtime_mode"] || "story"
    rescue
      "story"
    end

    def set_runtime_mode(mode)
      value = mode.to_s
      return if value.empty? || save_bucket["runtime_mode"].to_s == value
      save_bucket["runtime_mode"] = value
      mark_dirty
    rescue
      nil
    end

    def current_objective
      save_bucket["current_objective"]
    end

    def current_objective=(objective)
      save_bucket["current_objective"] = objective
      mark_dirty
    end

    def record_active_goal(goal = nil)
      save_bucket["active_goal"] = goal ? stringify_keys(goal).merge("time" => Time.now.to_i) : nil
      mark_dirty
    rescue
      nil
    end

    def active_goal
      save_bucket["active_goal"]
    rescue
      nil
    end

    def mark_map_seen(map_id)
      return unless map_id
      save_bucket["visited_maps"][map_id.to_s] = Time.now.to_i
      mark_dirty
    end

    def update_last_position(map_id, x, y)
      save_bucket["last_position"] = {
        "map_id" => map_id,
        "x" => x,
        "y" => y,
        "time" => Time.now.to_i
      }
      mark_dirty
    rescue
      nil
    end

    def last_position
      save_bucket["last_position"]
    rescue
      nil
    end

    def record_map_knowledge(map_id, summary = {})
      return unless map_id
      knowledge = save_bucket["map_knowledge"] ||= {}
      entry = knowledge[map_id.to_s] ||= {
        "seen_at" => Time.now.to_i,
        "targets" => {}
      }
      entry["last_seen_at"] = Time.now.to_i
      entry["summary"] = stringify_keys(summary)
      targets = entry["targets"] ||= {}
      Array(summary["targets"] || summary[:targets]).each do |target|
        next unless target.is_a?(Hash)
        key = target["key"] || target_key(target["record"] || target, target["kind"])
        targets[key.to_s] = stringify_keys(target).merge("last_seen_at" => Time.now.to_i)
      end
      mark_dirty
      entry
    rescue
      nil
    end

    def map_knowledge(map_id = nil)
      knowledge = save_bucket["map_knowledge"] ||= {}
      map_id ? knowledge[map_id.to_s] : knowledge
    rescue
      map_id ? nil : {}
    end

    def world_atlas
      atlas = save_bucket["world_atlas"] ||= {}
      atlas["maps"] ||= {}
      atlas["routes"] ||= {}
      atlas["ability_gates"] ||= {}
      atlas
    rescue
      { "maps" => {}, "routes" => {}, "ability_gates" => {} }
    end

    def world_map_entry(map_id)
      return nil unless map_id
      atlas = world_atlas
      maps = atlas["maps"] ||= {}
      maps[map_id.to_s] ||= {
        "map_id" => map_id.to_i,
        "status" => "unseen",
        "targets" => {},
        "transfers" => {},
        "encounter_methods" => {},
        "seen_at" => Time.now.to_i
      }
    rescue
      nil
    end

    def record_world_map(map_id, info = {})
      entry = world_map_entry(map_id)
      return nil unless entry
      info = stringify_keys(info || {})
      entry["map_id"] = map_id.to_i
      entry["name"] = info["name"].to_s unless info["name"].to_s.empty?
      entry["last_seen_at"] = Time.now.to_i
      status = info["status"].to_s
      entry["status"] = status unless status.empty?
      entry["counts"] = stringify_keys(info["counts"] || {}) if info["counts"].is_a?(Hash)
      methods = info["encounter_methods"]
      if methods.respond_to?(:each)
        bucket = entry["encounter_methods"] ||= {}
        methods.each { |method| bucket[method.to_s] = Time.now.to_i }
      end
      targets = entry["targets"] ||= {}
      Array(info["targets"]).each do |target|
        next unless target.is_a?(Hash)
        key = target["key"] || target_key(target["record"] || target, target["kind"])
        next if key.to_s.empty?
        existing = targets[key.to_s] ||= {}
        target.each { |k, v| existing[k.to_s] = stringify_keys(v) }
        existing["last_seen_at"] = Time.now.to_i
        existing["status"] ||= "seen"
      end
      transfers = entry["transfers"] ||= {}
      Array(info["transfers"]).each do |transfer|
        next unless transfer.is_a?(Hash)
        key = transfer["key"] || target_key(transfer, "transfer")
        next if key.to_s.empty?
        existing = transfers[key.to_s] ||= {}
        transfer.each { |k, v| existing[k.to_s] = stringify_keys(v) }
        existing["last_seen_at"] = Time.now.to_i
        existing["status"] ||= "seen"
      end
      mark_dirty
      entry
    rescue
      nil
    end

    def world_map_status(map_id)
      entry = world_map_entry(map_id)
      entry ? entry["status"].to_s : "unseen"
    rescue
      "unseen"
    end

    def set_world_map_status(map_id, status, reason = nil)
      entry = world_map_entry(map_id)
      return nil unless entry
      entry["status"] = status.to_s
      entry["status_reason"] = reason.to_s unless reason.nil?
      entry["status_time"] = Time.now.to_i
      mark_dirty
      entry
    rescue
      nil
    end

    def mark_world_target_status(record_or_key, status, kind = nil, reason = nil)
      key = record_or_key.is_a?(Hash) ? target_key(record_or_key, kind) : record_or_key.to_s
      return nil if key.empty?
      map_id = record_or_key.is_a?(Hash) ? record_or_key["map_id"] : nil
      map_id ||= current_objective["map_id"] if current_objective.is_a?(Hash)
      map_id ||= (defined?($game_map) && $game_map ? $game_map.map_id : nil)
      entry = world_map_entry(map_id)
      return nil unless entry
      targets = entry["targets"] ||= {}
      target = targets[key] ||= { "key" => key, "kind" => kind.to_s }
      target["status"] = status.to_s
      target["reason"] = reason.to_s unless reason.nil?
      target["time"] = Time.now.to_i
      mark_dirty
      target
    rescue
      nil
    end

    def mark_world_transfer_status(record_or_key, status, reason = nil)
      key = record_or_key.is_a?(Hash) ? (record_or_key["key"] || target_key(record_or_key, "transfer")) : record_or_key.to_s
      return nil if key.empty?
      map_id = record_or_key.is_a?(Hash) ? record_or_key["map_id"] : nil
      map_id ||= (defined?($game_map) && $game_map ? $game_map.map_id : nil)
      entry = world_map_entry(map_id)
      return nil unless entry
      transfers = entry["transfers"] ||= {}
      transfer = transfers[key] ||= { "key" => key, "kind" => "transfer" }
      if record_or_key.is_a?(Hash)
        record_or_key.each { |k, v| transfer[k.to_s] = stringify_keys(v) }
      end
      transfer["status"] = status.to_s
      transfer["reason"] = reason.to_s unless reason.nil?
      transfer["time"] = Time.now.to_i
      mark_dirty
      transfer
    rescue
      nil
    end

    def record_world_route(from_map, to_map, transfer_keys, reason = nil)
      return nil unless from_map && to_map
      atlas = world_atlas
      routes = atlas["routes"] ||= {}
      key = "#{from_map.to_i}:#{to_map.to_i}"
      routes[key] = {
        "from_map" => from_map.to_i,
        "to_map" => to_map.to_i,
        "transfers" => Array(transfer_keys).map(&:to_s),
        "reason" => reason.to_s,
        "time" => Time.now.to_i
      }
      mark_dirty
      routes[key]
    rescue
      nil
    end

    def world_route(from_map, to_map)
      routes = (world_atlas["routes"] || {})
      routes["#{from_map.to_i}:#{to_map.to_i}"]
    rescue
      nil
    end

    def record_ability_gate(record_or_key, requirement, reason = nil)
      key = record_or_key.is_a?(Hash) ? target_key(record_or_key, requirement) : record_or_key.to_s
      return nil if key.empty?
      gates = world_atlas["ability_gates"] ||= {}
      entry = gates[key] ||= { "count" => 0 }
      entry["count"] = entry["count"].to_i + 1
      entry["requirement"] = requirement.to_s
      entry["reason"] = reason.to_s unless reason.nil?
      entry["map_id"] = record_or_key["map_id"] if record_or_key.is_a?(Hash)
      entry["x"] = record_or_key["x"] if record_or_key.is_a?(Hash)
      entry["y"] = record_or_key["y"] if record_or_key.is_a?(Hash)
      entry["time"] = Time.now.to_i
      mark_dirty
      entry
    rescue
      nil
    end

    def record_world_plan(plan = {})
      atlas = world_atlas
      atlas["last_plan"] = stringify_keys(plan || {}).merge("time" => Time.now.to_i)
      mark_dirty
    rescue
      nil
    end

    def last_world_plan
      world_atlas["last_plan"]
    rescue
      nil
    end

    def set_route_anchor(map_id, x = nil, y = nil, label = nil)
      return unless map_id
      save_bucket["route_anchor"] = {
        "map_id" => map_id,
        "x" => x,
        "y" => y,
        "label" => label.to_s,
        "time" => Time.now.to_i
      }
      mark_dirty
    rescue
      nil
    end

    def route_anchor
      save_bucket["route_anchor"]
    rescue
      nil
    end

    def record_heal_hub(map_id, x = nil, y = nil, direction = nil, label = nil)
      return unless map_id && map_id.to_i > 0
      save_bucket["last_heal_hub"] = {
        "map_id" => map_id.to_i,
        "x" => x,
        "y" => y,
        "direction" => direction,
        "label" => label.to_s,
        "time" => Time.now.to_i
      }
      mark_dirty
    rescue
      nil
    end

    def last_heal_hub
      save_bucket["last_heal_hub"]
    rescue
      nil
    end

    def record_heal_route(map_id, label, target = nil, path_length = nil)
      return unless map_id
      save_bucket["last_heal_route"] = {
        "map_id" => map_id.to_i,
        "label" => label.to_s,
        "target" => target,
        "path_length" => path_length,
        "time" => Time.now.to_i
      }
      mark_dirty
    rescue
      nil
    end

    def last_heal_route
      save_bucket["last_heal_route"]
    rescue
      nil
    end

    def transfer_key(map_id, event_id, destination_map_id, x = nil, y = nil)
      [map_id, event_id, destination_map_id, x, y].compact.map(&:to_s).join(":")
    end

    def mark_transfer_visited(key)
      save_bucket["visited_transfers"][key.to_s] = Time.now.to_i
      mark_dirty
    end

    def transfer_visited?(key)
      !!save_bucket["visited_transfers"][key.to_s]
    end

    def mark_target_done(record_or_key, kind = nil)
      key = record_or_key.is_a?(Hash) ? target_key(record_or_key, kind) : record_or_key.to_s
      return if key.empty?
      save_bucket["completed_targets"][key] = Time.now.to_i
      mark_dirty
    rescue
      nil
    end

    def target_done?(record_or_key, kind = nil)
      key = record_or_key.is_a?(Hash) ? target_key(record_or_key, kind) : record_or_key.to_s
      !!save_bucket["completed_targets"][key]
    rescue
      false
    end

    def target_key(record, kind = nil)
      return record.to_s unless record.is_a?(Hash)
      [
        kind || record["kind"] || record["type"] || "target",
        record["map_id"],
        record["key"] || record["event_id"] || record["event_name"],
        record["x"],
        record["y"],
        record["destination_map_id"]
      ].compact.map(&:to_s).join(":")
    rescue
      "target"
    end

    def mark_target_failed(record_or_key, reason = "failed", kind = nil)
      key = record_or_key.is_a?(Hash) ? target_key(record_or_key, kind) : record_or_key.to_s
      return if key.empty?
      failed = save_bucket["failed_targets"] ||= {}
      entry = failed[key] ||= { "count" => 0 }
      entry["count"] = entry["count"].to_i + 1
      entry["reason"] = reason.to_s
      entry["time"] = Time.now.to_i
      mark_dirty
      entry
    rescue
      nil
    end

    def record_stuck_signature(signature, reason = "stuck", details = nil)
      key = signature.to_s
      return if key.empty?
      stuck = save_bucket["stuck_signatures"] ||= {}
      entry = stuck[key] ||= { "count" => 0 }
      entry["count"] = entry["count"].to_i + 1
      entry["reason"] = reason.to_s
      entry["details"] = details if details
      entry["time"] = Time.now.to_i
      save_bucket["last_stuck_signature"] = entry.merge("signature" => key)
      mark_dirty
      entry
    rescue
      nil
    end

    def stuck_signature_recent?(signature, cooldown_seconds = 600)
      entry = (save_bucket["stuck_signatures"] || {})[signature.to_s]
      return false unless entry
      Time.now.to_i - entry["time"].to_i < cooldown_seconds.to_i
    rescue
      false
    end

    def last_stuck_signature
      save_bucket["last_stuck_signature"]
    rescue
      nil
    end

    def clear_last_stuck_signature!
      save_bucket["last_stuck_signature"] = nil
      mark_dirty
    rescue
      nil
    end

    def target_failed?(record_or_key, cooldown_seconds = 300, kind = nil)
      key = record_or_key.is_a?(Hash) ? target_key(record_or_key, kind) : record_or_key.to_s
      entry = (save_bucket["failed_targets"] || {})[key]
      return false unless entry
      return true if cooldown_seconds.to_i <= 0
      Time.now.to_i - entry["time"].to_i < cooldown_seconds.to_i
    rescue
      false
    end

    def mark_target_attempted(record_or_key, reason = "attempted", kind = nil)
      key = record_or_key.is_a?(Hash) ? target_key(record_or_key, kind) : record_or_key.to_s
      return if key.empty?
      attempts = save_bucket["attempted_targets"] ||= {}
      entry = attempts[key] ||= { "count" => 0 }
      entry["count"] = entry["count"].to_i + 1
      entry["reason"] = reason.to_s
      entry["time"] = Time.now.to_i
      mark_dirty
      entry
    rescue
      nil
    end

    def target_attempted?(record_or_key, cooldown_seconds = 5, kind = nil)
      key = record_or_key.is_a?(Hash) ? target_key(record_or_key, kind) : record_or_key.to_s
      entry = (save_bucket["attempted_targets"] || {})[key]
      return false unless entry
      return true if cooldown_seconds.to_i <= 0
      Time.now.to_i - entry["time"].to_i < cooldown_seconds.to_i
    rescue
      false
    end

    def target_attempt_count(record_or_key, kind = nil)
      key = record_or_key.is_a?(Hash) ? target_key(record_or_key, kind) : record_or_key.to_s
      entry = (save_bucket["attempted_targets"] || {})[key]
      entry ? entry["count"].to_i : 0
    rescue
      0
    end

    def clear_runtime_flags!(reason = "reset")
      bucket = save_bucket
      bucket["mode"] = "idle"
      bucket["runtime_mode"] = "story"
      bucket["current_objective"] = nil
      bucket["training_plan"] = nil
      bucket["recovery_plan"] = nil
      bucket["active_goal"] = nil
      bucket["objective_retries"] = {}
      bucket["attempted_targets"] = {}
      bucket["last_stuck_signature"] = nil
      bucket["last_runtime_reset"] = {
        "reason" => reason.to_s,
        "time" => Time.now.to_i
      }
      mark_dirty
    rescue
      nil
    end

    def record_resource_snapshot(snapshot = {})
      bucket = save_bucket
      entry = stringify_keys(snapshot).merge("time" => Time.now.to_i)
      snapshots = bucket["resource_snapshots"] ||= []
      snapshots << entry
      snapshots.shift while snapshots.length > MAX_RESOURCE_SNAPSHOTS
      bucket["resource_plan"] = entry["plan"] if entry["plan"].is_a?(Hash)
      mark_dirty
    rescue
      nil
    end

    def record_team_plan(plan = {})
      bucket = save_bucket
      entry = stringify_keys(plan).merge("time" => Time.now.to_i)
      snapshots = bucket["team_snapshots"] ||= []
      snapshots << entry
      snapshots.shift while snapshots.length > MAX_TEAM_SNAPSHOTS
      bucket["team_plan"] = entry
      mark_dirty
    rescue
      nil
    end

    def record_storage_snapshot(snapshot = {})
      bucket = save_bucket
      entry = stringify_keys(snapshot).merge("time" => Time.now.to_i)
      snapshots = bucket["storage_snapshots"] ||= []
      snapshots << entry
      snapshots.shift while snapshots.length > MAX_STORAGE_SNAPSHOTS
      bucket["storage_snapshot"] = entry
      mark_dirty
    rescue
      nil
    end

    def storage_snapshot
      save_bucket["storage_snapshot"]
    rescue
      nil
    end

    def record_storage_decision(info = {})
      bucket = save_bucket
      decisions = bucket["storage_decisions"] ||= []
      decisions << stringify_keys(info).merge("time" => Time.now.to_i)
      decisions.shift while decisions.length > MAX_STORAGE_DECISIONS
      mark_dirty
    rescue
      nil
    end

    def remember_shop_stock(map_id, stock = [])
      key = map_id ? map_id.to_s : "unknown"
      memory = save_bucket["shop_stock_memory"] ||= {}
      memory[key] = {
        "time" => Time.now.to_i,
        "stock" => stock.compact.map(&:to_s).uniq
      }
      mark_dirty
    rescue
      nil
    end

    def record_purchase(purchases = [], money_before = nil, money_after = nil)
      return unless purchases.respond_to?(:each)
      counts = {}
      purchases.each { |item| counts[item.to_s] = counts[item.to_s].to_i + 1 }
      return if counts.empty?
      entries = save_bucket["purchase_history"] ||= []
      entries << {
        "time" => Time.now.to_i,
        "map" => (defined?($game_map) && $game_map ? $game_map.map_id : nil),
        "items" => counts,
        "money_before" => money_before,
        "money_after" => money_after
      }
      entries.shift while entries.length > MAX_PURCHASE_HISTORY
      mark_dirty
    rescue
      nil
    end

    def trainer_key(record_or_key = nil)
      return record_or_key.to_s unless record_or_key.is_a?(Hash)
      [
        "trainer",
        record_or_key["map_id"],
        record_or_key["event_id"] || record_or_key["event_name"],
        record_or_key["x"],
        record_or_key["y"],
        record_or_key["args"]
      ].compact.map(&:to_s).join(":")
    rescue
      "trainer:unknown"
    end

    def note_trainer_candidate(record = {})
      return unless record.is_a?(Hash)
      entry = trainer_ledger_entry(record)
      entry["record"] ||= stringify_keys(record)
      entry["hint"] = record["repeatable_status"].to_s unless record["repeatable_status"].to_s.empty?
      entry["last_seen"] = Time.now.to_i
      mark_dirty
      entry
    rescue
      nil
    end

    def trainer_ledger_entry(record = nil, info = {})
      has_record = record.is_a?(Hash) && !record.empty?
      has_info = info.is_a?(Hash) && !info.empty?
      return nil unless has_record || has_info
      record = fallback_trainer_record(info) unless has_record
      key = trainer_key(record)
      ledger = save_bucket["trainer_ledger"] ||= {}
      entry = ledger[key] ||= {
        "key" => key,
        "starts" => 0,
        "wins" => 0,
        "losses" => 0,
        "rocket_attempt_count" => 0,
        "rocket_capture_count" => 0,
        "rocket_attempts" => {},
        "rocket_captures" => {}
      }
      entry["record"] ||= stringify_keys(record)
      entry
    rescue
      nil
    end

    def record_trainer_battle_start(record = nil, info = {})
      record = fallback_trainer_record(info) unless record.is_a?(Hash) && !record.empty?
      key = trainer_key(record)
      entry = trainer_ledger_entry(record, info) || { "key" => key, "starts" => 0, "wins" => 0, "losses" => 0 }
      entry["record"] ||= stringify_keys(record)
      entry["hint"] ||= record["repeatable_status"].to_s unless record["repeatable_status"].to_s.empty?
      entry["starts"] = entry["starts"].to_i + 1
      entry["last_start"] = Time.now.to_i
      entry["last_info"] = stringify_keys(info)
      if entry["starts"].to_i > 1
        mark_repeatable_battle(key, entry, "confirmed_repeatable")
      end
      mark_dirty
      entry
    rescue
      nil
    end

    def record_trainer_battle_end(record = nil, info = {})
      record = fallback_trainer_record(info) unless record.is_a?(Hash) && !record.empty?
      key = trainer_key(record)
      entry = trainer_ledger_entry(record, info) || { "key" => key, "starts" => 0, "wins" => 0, "losses" => 0 }
      result = (info["result"] || info[:result]).to_s
      if result =~ /win|caught/i
        entry["wins"] = entry["wins"].to_i + 1
      elsif result =~ /lose|loss|blackout/i
        entry["losses"] = entry["losses"].to_i + 1
      end
      entry["last_end"] = Time.now.to_i
      entry["last_result"] = result
      entry["last_reward"] = info["money_delta"] || info[:money_delta]
      hint = entry["hint"].to_s
      if entry["starts"].to_i > 1 || entry["wins"].to_i > 1
        mark_repeatable_battle(key, entry, "confirmed_repeatable")
      elsif hint == "likely_repeatable"
        mark_repeatable_battle(key, entry, "likely_repeatable")
      elsif hint == "likely_one_shot"
        entry["status"] = "likely_one_shot"
      else
        entry["status"] ||= "unknown"
      end
      rewards = save_bucket["battle_reward_history"] ||= []
      rewards << stringify_keys(info).merge("key" => key, "time" => Time.now.to_i)
      rewards.shift while rewards.length > MAX_BATTLE_REWARDS
      mark_dirty
      entry
    rescue
      nil
    end

    def trainer_battle_count(record = nil)
      entry = trainer_ledger_entry(record)
      return 0 unless entry
      completed = entry["wins"].to_i + entry["losses"].to_i
      [entry["starts"].to_i, completed].max
    rescue
      0
    end

    def trainer_done_for_now?(record = nil, max_battles = TRAINER_REPEAT_BATTLE_LIMIT)
      entry = trainer_ledger_entry(record)
      return false unless entry
      trainer_battle_count(record).to_i >= max_battles.to_i
    rescue
      false
    end

    def trainer_rocket_capture_allowed?(record = nil)
      entry = trainer_ledger_entry(record)
      return true unless entry
      return false if entry["rocket_capture_count"].to_i >= TRAINER_ROCKET_CAPTURE_LIMIT
      return false if entry["rocket_attempt_count"].to_i >= TRAINER_ROCKET_ATTEMPT_LIMIT
      true
    rescue
      true
    end

    def record_trainer_rocket_attempt(record = nil, species_key = nil, ball = nil, info = {})
      entry = trainer_ledger_entry(record, info)
      return nil unless entry
      species = species_key.to_s
      species = "unknown" if species.empty?
      entry["rocket_attempt_count"] = entry["rocket_attempt_count"].to_i + 1
      entry["last_rocket_attempt"] = Time.now.to_i
      entry["last_rocket_ball"] = ball.to_s unless ball.nil?
      attempts = entry["rocket_attempts"] ||= {}
      attempts[species] = attempts[species].to_i + 1
      mark_dirty
      entry
    rescue
      nil
    end

    def record_trainer_rocket_capture(record = nil, species_key = nil, ball = nil, info = {})
      entry = trainer_ledger_entry(record, info)
      return nil unless entry
      species = species_key.to_s
      species = "unknown" if species.empty?
      captures = entry["rocket_captures"] ||= {}
      unless captures[species].to_i > 0
        entry["rocket_capture_count"] = entry["rocket_capture_count"].to_i + 1
      end
      captures[species] = captures[species].to_i + 1
      entry["last_rocket_capture"] = Time.now.to_i
      entry["last_rocket_ball"] = ball.to_s unless ball.nil?
      mark_dirty
      entry
    rescue
      nil
    end

    def mark_repeatable_battle(key, entry, status = "confirmed_repeatable")
      repeatables = save_bucket["repeatable_battles"] ||= {}
      repeatables[key.to_s] = {
        "key" => key.to_s,
        "status" => status.to_s,
        "record" => entry["record"],
        "wins" => entry["wins"].to_i,
        "starts" => entry["starts"].to_i,
        "last_seen" => Time.now.to_i,
        "last_reward" => entry["last_reward"]
      }
      entry["status"] = status.to_s
    rescue
      nil
    end

    def fallback_trainer_record(info = {})
      opponents = info["opponents"] || info[:opponents]
      opponent_text = opponents.respond_to?(:join) ? opponents.join("+") : opponents.to_s
      {
        "map_id" => info["map"] || info[:map],
        "event_id" => "observed",
        "event_name" => opponent_text.empty? ? "Observed Trainer" : opponent_text,
        "x" => info["x"] || info[:x],
        "y" => info["y"] || info[:y],
        "args" => opponent_text,
        "repeatable_status" => "unknown"
      }
    rescue
      { "event_id" => "observed", "event_name" => "Observed Trainer", "repeatable_status" => "unknown" }
    end

    def repeatable_battles_for_map(map_id)
      repeatables = save_bucket["repeatable_battles"] || {}
      repeatables.values.select do |entry|
        record = entry["record"] || {}
        record["map_id"].to_i == map_id.to_i &&
          ["confirmed_repeatable", "likely_repeatable"].include?(entry["status"].to_s)
      end
    rescue
      []
    end

    def farm_cycle_count(objective = nil)
      objective ||= current_objective
      id = objective.is_a?(Hash) ? objective["id"].to_s : objective.to_s
      id = "unknown" if id.empty?
      entry = (save_bucket["farm_cooldowns"] || {})[id]
      entry ? entry["count"].to_i : 0
    rescue
      0
    end

    def increment_farm_cycle(objective = nil, reason = nil)
      objective ||= current_objective
      id = objective.is_a?(Hash) ? objective["id"].to_s : objective.to_s
      id = "unknown" if id.empty?
      farm = save_bucket["farm_cooldowns"] ||= {}
      entry = farm[id] ||= { "count" => 0 }
      entry["count"] = entry["count"].to_i + 1
      entry["reason"] = reason.to_s
      entry["time"] = Time.now.to_i
      mark_dirty
      entry["count"].to_i
    rescue
      0
    end

    def stringify_keys(value)
      case value
      when Hash
        out = {}
        value.each { |k, v| out[k.to_s] = stringify_keys(v) }
        out
      when Array
        value.map { |entry| stringify_keys(entry) }
      else
        value
      end
    rescue
      value
    end

    def failed_target_count(record_or_key, kind = nil)
      key = record_or_key.is_a?(Hash) ? target_key(record_or_key, kind) : record_or_key.to_s
      entry = (save_bucket["failed_targets"] || {})[key]
      entry ? entry["count"].to_i : 0
    rescue
      0
    end

    def observe_encounter(map_id, species_key, level = nil)
      return if species_key.nil?
      bucket = save_bucket["observed_encounters"][map_id.to_s] ||= {}
      entry = bucket[species_key.to_s] ||= { "count" => 0, "levels" => [] }
      entry["count"] = entry["count"].to_i + 1
      entry["levels"] << level.to_i if level
      entry["levels"] = entry["levels"].uniq.sort.last(20)
      mark_dirty
    end

    def record_catch(species_key)
      return if species_key.nil?
      caught = save_bucket["caught_species"]
      caught[species_key.to_s] = caught[species_key.to_s].to_i + 1
      mark_dirty
    end

    def hunt_zone_key(map_id, method)
      "#{map_id.to_i}:#{method.to_s.empty? ? "unknown" : method}"
    rescue
      "0:unknown"
    end

    def hunt_zones
      save_bucket["hunt_zones"] ||= {}
    rescue
      {}
    end

    def hunt_zone(map_id, method)
      zones = hunt_zones
      key = hunt_zone_key(map_id, method)
      zones[key] ||= {
        "map_id" => map_id.to_i,
        "method" => method.to_s,
        "seen_species" => {},
        "caught_species" => {},
        "encounter_count" => 0,
        "catch_attempts" => 0,
        "failed_anchors" => {},
        "nearby_heal" => nil,
        "nearby_shop" => nil,
        "last_seen_at" => Time.now.to_i
      }
    rescue
      {}
    end

    def record_hunt_zone(map_id, method, info = {})
      zone = hunt_zone(map_id, method)
      info = stringify_keys(info || {})
      info.each do |key, value|
        next if ["seen_species", "caught_species", "failed_anchors"].include?(key.to_s)
        zone[key.to_s] = value
      end
      zone["map_id"] = map_id.to_i
      zone["method"] = method.to_s
      zone["last_seen_at"] = Time.now.to_i
      mark_dirty
      zone
    rescue
      nil
    end

    def record_hunt_encounter(map_id, method, species_key, level = nil, needed = false)
      return if species_key.nil?
      zone = record_hunt_zone(map_id, method)
      return unless zone
      species = species_key.to_s
      seen = zone["seen_species"] ||= {}
      entry = seen[species] ||= { "count" => 0, "levels" => [] }
      entry["count"] = entry["count"].to_i + 1
      entry["last_seen_at"] = Time.now.to_i
      entry["needed"] = true if needed
      entry["levels"] ||= []
      entry["levels"] << level.to_i if level
      entry["levels"] = entry["levels"].uniq.sort.last(20)
      zone["encounter_count"] = zone["encounter_count"].to_i + 1
      zone["recent_yield"] = needed ? "needed_seen" : "seen"

      targets = save_bucket["species_targets"] ||= {}
      target = targets[species] ||= { "seen_count" => 0, "caught_count" => 0 }
      target["seen_count"] = target["seen_count"].to_i + 1
      target["last_seen_at"] = Time.now.to_i
      target["last_seen_map"] = map_id.to_i
      target["last_seen_method"] = method.to_s
      target["needed"] = needed
      mark_dirty
    rescue
      nil
    end

    def record_hunt_catch(species_key, map_id = nil, method = nil)
      return if species_key.nil?
      species = species_key.to_s
      targets = save_bucket["species_targets"] ||= {}
      target = targets[species] ||= { "seen_count" => 0, "caught_count" => 0 }
      target["caught_count"] = target["caught_count"].to_i + 1
      target["last_caught_at"] = Time.now.to_i
      target["last_seen_at"] ||= Time.now.to_i
      target["last_caught_map"] = map_id.to_i if map_id
      target["last_caught_method"] = method.to_s if method
      if map_id
        zone = record_hunt_zone(map_id, method || "unknown")
        if zone
          caught = zone["caught_species"] ||= {}
          caught[species] = caught[species].to_i + 1
          zone["recent_yield"] = "caught"
        end
      end
      mark_dirty
    rescue
      nil
    end

    def record_catch_attempt(species_key, ball = nil, info = {})
      return if species_key.nil?
      species = species_key.to_s
      attempts = save_bucket["catch_attempts"] ||= {}
      entry = attempts[species] ||= { "count" => 0, "balls" => {} }
      entry["count"] = entry["count"].to_i + 1
      entry["last_ball"] = ball.to_s if ball
      entry["last_attempt_at"] = Time.now.to_i
      entry["time"] = entry["last_attempt_at"]
      entry["balls"] ||= {}
      entry["balls"][ball.to_s] = entry["balls"][ball.to_s].to_i + 1 if ball
      stringify_keys(info || {}).each { |key, value| entry[key] = value }
      mark_dirty
    rescue
      nil
    end

    def set_hunt_zone_cooldown(map_id, method, reason = "cooldown", seconds = 300)
      cooldowns = save_bucket["zone_cooldowns"] ||= {}
      key = hunt_zone_key(map_id, method)
      cooldowns[key] = {
        "map_id" => map_id.to_i,
        "method" => method.to_s,
        "reason" => reason.to_s,
        "until" => Time.now.to_i + seconds.to_i,
        "time" => Time.now.to_i
      }
      mark_dirty
    rescue
      nil
    end

    def hunt_zone_on_cooldown?(map_id, method)
      cooldowns = save_bucket["zone_cooldowns"] ||= {}
      key = hunt_zone_key(map_id, method)
      entry = cooldowns[key]
      return false unless entry
      if entry["until"].to_i <= Time.now.to_i
        cooldowns.delete(key)
        mark_dirty
        return false
      end
      true
    rescue
      false
    end

    def record_hunt_session(session = {})
      sessions = save_bucket["hunt_sessions"] ||= []
      sessions << stringify_keys(session || {}).merge("time" => Time.now.to_i)
      sessions.shift while sessions.length > MAX_HUNT_SESSIONS
      mark_dirty
    rescue
      nil
    end

    def set_team_rotation_plan(plan = {})
      save_bucket["team_rotation_plan"] = stringify_keys(plan || {}).merge("time" => Time.now.to_i)
      mark_dirty
    rescue
      nil
    end

    def record_prime_directive(snapshot = {})
      save_bucket["prime_directive"] = stringify_keys(snapshot).merge("time" => Time.now.to_i)
      mark_dirty
    rescue
      nil
    end

    def prime_directive
      save_bucket["prime_directive"] || {}
    rescue
      {}
    end

    def record_fusion_seen(key, info = {})
      return if key.nil? || key.to_s.empty?
      entry = (save_bucket["fusion_seen"] ||= {})[key.to_s] ||= { "count" => 0 }
      entry["count"] = entry["count"].to_i + 1
      entry["last_seen_at"] = Time.now.to_i
      entry["map"] = info["map"] || info[:map] if info
      entry["species"] = info["species"] || info[:species] if info
      mark_dirty
    rescue
      nil
    end

    def record_fusion_owned(key, info = {})
      return if key.nil? || key.to_s.empty?
      entry = (save_bucket["fusion_owned"] ||= {})[key.to_s] ||= { "count" => 0 }
      entry["count"] = entry["count"].to_i + 1
      entry["last_owned_at"] = Time.now.to_i
      entry["map"] = info["map"] || info[:map] if info
      entry["species"] = info["species"] || info[:species] if info
      mark_dirty
    rescue
      nil
    end

    def fusion_owned?(key)
      entry = (save_bucket["fusion_owned"] || {})[key.to_s]
      entry && entry["count"].to_i > 0
    rescue
      false
    end

    def fusion_seen?(key)
      entry = (save_bucket["fusion_seen"] || {})[key.to_s]
      entry && entry["count"].to_i > 0
    rescue
      false
    end

    def record_failure_event(reason, context = {})
      return if defined?(AutoplayBot::Config) && !AutoplayBot::Config.self_improvement_logging?
      events = save_bucket["failure_events"] ||= []
      events << {
        "time" => Time.now.to_i,
        "reason" => reason.to_s,
        "mode" => (runtime_mode rescue nil),
        "objective" => current_objective,
        "map" => (defined?($game_map) && $game_map ? $game_map.map_id : nil),
        "x" => (defined?($game_player) && $game_player ? $game_player.x : nil),
        "y" => (defined?($game_player) && $game_player ? $game_player.y : nil),
        "context" => stringify_keys(context || {})
      }
      events.shift while events.length > MAX_FAILURE_EVENTS
      mark_dirty
    rescue
      nil
    end

    def failure_events
      save_bucket["failure_events"] || []
    rescue
      []
    end

    def defer_target(species_key, reason)
      return if species_key.nil?
      save_bucket["deferred_targets"][species_key.to_s] = {
        "reason" => reason.to_s,
        "time" => Time.now.to_i
      }
      mark_dirty
    end

    def increment_objective_retry(objective = nil, reason = nil)
      objective ||= current_objective
      id = objective.is_a?(Hash) ? objective["id"].to_s : objective.to_s
      id = "unknown" if id.empty?
      retries = save_bucket["objective_retries"] ||= {}
      entry = retries[id] ||= { "count" => 0 }
      entry["count"] = entry["count"].to_i + 1
      entry["reason"] = reason.to_s
      entry["time"] = Time.now.to_i
      mark_dirty
      entry["count"].to_i
    rescue
      0
    end

    def objective_retry_count(objective = nil)
      objective ||= current_objective
      id = objective.is_a?(Hash) ? objective["id"].to_s : objective.to_s
      entry = (save_bucket["objective_retries"] || {})[id]
      entry ? entry["count"].to_i : 0
    rescue
      0
    end

    def set_recovery_plan(plan)
      save_bucket["recovery_plan"] = plan
      mark_dirty
    rescue
      nil
    end

    def recovery_plan
      save_bucket["recovery_plan"]
    rescue
      nil
    end

    def set_training_plan(plan)
      save_bucket["training_plan"] = plan
      mark_dirty
    rescue
      nil
    end

    def training_plan
      save_bucket["training_plan"]
    rescue
      nil
    end

    def clear_training_plan
      save_bucket["training_plan"] = nil
      mark_dirty
    rescue
      nil
    end

    def enqueue_frontier(record, kind = "transfer", priority = 50)
      return unless record.is_a?(Hash)
      key = target_key(record, kind)
      queue = save_bucket["frontier_queue"] ||= []
      return if queue.any? { |entry| entry["key"].to_s == key }
      queue << {
        "key" => key,
        "kind" => kind.to_s,
        "record" => record,
        "priority" => priority.to_i,
        "time" => Time.now.to_i,
        "tries" => 0
      }
      queue.sort_by! { |entry| [entry["priority"].to_i, entry["time"].to_i] }
      queue.shift while queue.length > MAX_FRONTIER_QUEUE
      mark_dirty
    rescue
      nil
    end

    def enqueue_cleanup_target(record, kind = "target", priority = 50, reason = nil)
      return unless record.is_a?(Hash)
      key = target_key(record, kind)
      return if target_done?(record, kind)
      queue = save_bucket["cleanup_queue"] ||= []
      entry = queue.find { |item| item["key"].to_s == key }
      if entry
        entry["priority"] = [entry["priority"].to_i, priority.to_i].min
        entry["last_seen"] = Time.now.to_i
        entry["reason"] = reason.to_s unless reason.to_s.empty?
      else
        queue << {
          "key" => key,
          "kind" => kind.to_s,
          "record" => stringify_keys(record),
          "priority" => priority.to_i,
          "reason" => reason.to_s,
          "time" => Time.now.to_i,
          "tries" => 0
        }
      end
      queue.sort_by! { |item| [item["priority"].to_i, item["time"].to_i] }
      queue.shift while queue.length > MAX_CLEANUP_QUEUE
      mark_dirty
    rescue
      nil
    end

    def next_cleanup_target(map_id = nil)
      queue = save_bucket["cleanup_queue"] ||= []
      queue.find do |entry|
        record = entry["record"] || {}
        next false if map_id && record["map_id"].to_i != map_id.to_i
        next false if target_done?(entry["key"])
        next false if target_failed?(entry["key"], 240)
        true
      end
    rescue
      nil
    end

    def touch_cleanup_target(key, success = false, reason = nil)
      queue = save_bucket["cleanup_queue"] ||= []
      index = queue.index { |entry| entry["key"].to_s == key.to_s }
      return unless index
      entry = queue[index]
      if success
        queue.delete_at(index)
      else
        entry["tries"] = entry["tries"].to_i + 1
        entry["last_reason"] = reason.to_s
        entry["last_time"] = Time.now.to_i
        mark_target_failed(key, reason.to_s)
      end
      mark_dirty
    rescue
      nil
    end

    def next_frontier(map_id = nil)
      queue = save_bucket["frontier_queue"] ||= []
      queue.find do |entry|
        record = entry["record"] || {}
        next false if map_id && record["map_id"].to_i != map_id.to_i
        !target_failed?(entry["key"], 180)
      end
    rescue
      nil
    end

    def touch_frontier(key, success = false, reason = nil)
      queue = save_bucket["frontier_queue"] ||= []
      index = queue.index { |entry| entry["key"].to_s == key.to_s }
      return unless index
      entry = queue[index]
      if success
        queue.delete_at(index)
      else
        entry["tries"] = entry["tries"].to_i + 1
        entry["last_reason"] = reason.to_s
        entry["last_time"] = Time.now.to_i
        mark_target_failed(key, reason.to_s)
      end
      mark_dirty
    rescue
      nil
    end

    def add_manual_note(reason)
      notes = save_bucket["manual_notes"]
      notes << {
        "time" => Time.now.to_i,
        "map" => (defined?($game_map) && $game_map ? $game_map.map_id : nil),
        "x" => (defined?($game_player) && $game_player ? $game_player.x : nil),
        "y" => (defined?($game_player) && $game_player ? $game_player.y : nil),
        "reason" => reason.to_s
      }
      notes.shift while notes.length > MAX_MANUAL_NOTES
      mark_dirty
    end

    def record_blackout(info = {})
      entries = save_bucket["blackouts"] ||= []
      entries << {
        "time" => Time.now.to_i,
        "from_map" => info["from_map"],
        "from_x" => info["from_x"],
        "from_y" => info["from_y"],
        "return_map" => info["return_map"],
        "return_x" => info["return_x"],
        "return_y" => info["return_y"],
        "objective" => info["objective"],
        "gameover" => info["gameover"] == true
      }
      entries.shift while entries.length > 20
      mark_dirty
    rescue
      nil
    end

    def record_battle_loss(info = {})
      entries = save_bucket["battle_losses"] ||= []
      entries << {
        "time" => Time.now.to_i,
        "map" => info["map"] || info[:map],
        "x" => info["x"] || info[:x],
        "y" => info["y"] || info[:y],
        "objective" => info["objective"] || info[:objective],
        "reason" => (info["reason"] || info[:reason]).to_s
      }
      entries.shift while entries.length > 30
      mark_dirty
    rescue
      nil
    end
  end
end
