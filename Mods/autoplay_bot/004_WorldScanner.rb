module AutoplayBot
  module WorldScanner
    SCRIPT_CODES = [111, 122, 355, 655] unless const_defined?(:SCRIPT_CODES)
    COMMENT_CODES = [108, 408] unless const_defined?(:COMMENT_CODES)
    TEXT_CODES = [101, 401] unless const_defined?(:TEXT_CODES)
    TRANSFER_CODE = 201 unless const_defined?(:TRANSFER_CODE)
    COMMON_EVENT_CODE = 117 unless const_defined?(:COMMON_EVENT_CODE)
    SCANNER_VERSION = 7 unless const_defined?(:SCANNER_VERSION)

    module_function

    def index
      @index ||= runtime_active_without_cache_load? ? empty_index : (load_cache || empty_index)
    end

    def runtime_active_without_cache_load?
      return false unless defined?(AutoplayBot::Runtime)
      return true if AutoplayBot::Runtime.respond_to?(:active?) && AutoplayBot::Runtime.active?
      return true if AutoplayBot::Runtime.respond_to?(:startup_diagnostics_active?) &&
                     AutoplayBot::Runtime.startup_diagnostics_active?
      false
    rescue
      false
    end

    def empty_index
      {
        "version" => SCANNER_VERSION,
        "built_at" => nil,
        "maps" => {},
        "map_names" => {},
        "errors" => []
      }
    end

    def load_cache
      return nil unless File.exist?(AutoplayBot::CACHE_FILE)
      return nil if File.size(AutoplayBot::CACHE_FILE).to_i > 5_000_000
      parsed = AutoplayBot::JSON.parse(File.read(AutoplayBot::CACHE_FILE))
      return nil unless parsed.is_a?(Hash) && parsed["version"].to_i == SCANNER_VERSION
      parsed.is_a?(Hash) ? parsed : nil
    rescue
      nil
    end

    def save_cache
      AutoplayBot::State.ensure_dirs if defined?(AutoplayBot::State)
      index["built_at"] = Time.now.to_i
      File.open(AutoplayBot::CACHE_FILE, "w") { |f| f.write(AutoplayBot::JSON.dump(compact_cache(index))) }
    rescue => e
      AutoplayBot.log("world cache save failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def compact_cache(source)
      compact = empty_index
      compact["built_at"] = source["built_at"]
      compact["map_names"] = source["map_names"] || {}
      compact["errors"] = source["errors"] || []
      (source["maps"] || {}).each do |map_id, map|
        next unless map.is_a?(Hash)
        compact["maps"][map_id.to_s] = {
          "id" => map["id"],
          "name" => map["name"],
          "width" => map["width"],
          "height" => map["height"],
          "encounter_step" => map["encounter_step"],
          "transfers" => map["transfers"] || [],
          "npcs" => map["npcs"] || [],
          "trainers" => map["trainers"] || [],
          "items" => map["items"] || [],
          "field_resources" => map["field_resources"] || [],
          "gifts" => map["gifts"] || [],
          "wild_statics" => map["wild_statics"] || []
        }
        compact["maps"][map_id.to_s]["error"] = map["error"] if map["error"]
      end
      compact
    end

    def start
      return if @started
      @started = true
      if runtime_active_without_cache_load?
        @queue = []
        @live_map_names ||= {}
        AutoplayBot.log("world scan skipped during live runtime") if AutoplayBot.respond_to?(:log)
        return
      end
      @queue = map_ids
      load_map_names
      AutoplayBot.log("world scan queued #{@queue.length} map(s)") if AutoplayBot.respond_to?(:log)
    rescue => e
      AutoplayBot.log("world scan start failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def finished?
      @started && (!@queue || @queue.empty?)
    end

    def tick(budget = 2)
      start unless @started
      return if !@queue || @queue.empty?
      budget.to_i.times do
        map_id = @queue.shift
        break unless map_id
        next if index["maps"][map_id.to_s]
        index["maps"][map_id.to_s] = scan_map(map_id)
      end
      @scanned_since_save = @scanned_since_save.to_i + budget.to_i
      if @scanned_since_save >= 25 || @queue.empty?
        @scanned_since_save = 0
        save_cache
      end
    rescue => e
      index["errors"] << "tick: #{e.class}: #{e.message}"
      AutoplayBot.log("world scan tick failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
    end

    def map_ids
      files = Dir["Data/Map*.rxdata"]
      files.map do |path|
        match = File.basename(path).match(/Map(\d+)\.rxdata/i)
        match ? match[1].to_i : nil
      end.compact.sort
    end

    def load_map_names
      infos = load_rgss_data("Data/MapInfos.rxdata") rescue nil
      return unless infos.respond_to?(:each)
      infos.each do |id, info|
        next unless info
        index["map_names"][id.to_s] = safe_string(info.respond_to?(:name) ? info.name : "")
      end
    end

    def map_name(map_id)
      if @index && @index["map_names"].is_a?(Hash)
        name = @index["map_names"][map_id.to_s]
        return name if name && !name.to_s.empty?
      end
      if @live_map_names && @live_map_names[map_id.to_s]
        return @live_map_names[map_id.to_s]
      end
      "Map #{map_id}"
    end

    def current_map_data
      return nil unless defined?($game_map) && $game_map
      key = $game_map.map_id.to_s
      cached = @index && @index["maps"].is_a?(Hash) ? @index["maps"][key] : nil
      if cached && map_data_matches_live?(cached)
        return cached
      end
      @live_maps ||= {}
      live = @live_maps[key]
      unless live && map_data_matches_live?(live)
        live = scan_map($game_map.map_id)
        @live_maps[key] = live
      end
      live
    end

    def map_data_matches_live?(data)
      return false unless data.is_a?(Hash)
      return true unless defined?($game_map) && $game_map
      live_width = $game_map.respond_to?(:width) ? $game_map.width.to_i : 0
      live_height = $game_map.respond_to?(:height) ? $game_map.height.to_i : 0
      data_width = data["width"].to_i
      data_height = data["height"].to_i
      return false if live_width > 0 && data_width > 0 && live_width != data_width
      return false if live_height > 0 && data_height > 0 && live_height != data_height
      if defined?($game_player) && $game_player
        return false if data_width > 0 && $game_player.x.to_i >= data_width
        return false if data_height > 0 && $game_player.y.to_i >= data_height
      end
      true
    rescue
      false
    end

    def scan_map(map_id)
      map = load_rgss_data(sprintf("Data/Map%03d.rxdata", map_id))
      data = {
        "id" => map_id,
        "name" => map_name(map_id),
        "width" => map.respond_to?(:width) ? map.width : nil,
        "height" => map.respond_to?(:height) ? map.height : nil,
        "encounter_step" => map.respond_to?(:encounter_step) ? map.encounter_step : nil,
        "transfers" => [],
        "npcs" => [],
        "trainers" => [],
        "items" => [],
        "field_resources" => [],
        "gifts" => [],
        "wild_statics" => [],
        "events" => []
      }
      events = map.respond_to?(:events) && map.events ? map.events : {}
      events.each do |event_id, event|
        event_record = scan_event(map_id, event_id, event)
        data["events"] << event_record
        data["transfers"].concat(event_record["transfers"])
        data["npcs"].concat(event_record["npcs"])
        data["trainers"].concat(event_record["trainers"])
        data["items"].concat(event_record["items"])
        data["field_resources"].concat(event_record["field_resources"])
        data["gifts"].concat(event_record["gifts"])
        data["wild_statics"].concat(event_record["wild_statics"])
      end
      data
    rescue => e
      {
        "id" => map_id,
        "name" => map_name(map_id),
        "error" => "#{e.class}: #{e.message}",
        "transfers" => [],
        "npcs" => [],
        "trainers" => [],
        "items" => [],
        "field_resources" => [],
        "gifts" => [],
        "wild_statics" => [],
        "events" => []
      }
    end

    def scan_event(map_id, event_id, event)
      record = {
        "id" => event_id,
        "name" => safe_string(event.respond_to?(:name) ? event.name : ""),
        "x" => event.respond_to?(:x) ? event.x : nil,
        "y" => event.respond_to?(:y) ? event.y : nil,
        "pages" => [],
        "transfers" => [],
        "npcs" => [],
        "trainers" => [],
        "items" => [],
        "field_resources" => [],
        "gifts" => [],
        "wild_statics" => [],
        "comments" => []
      }
      pages = event.respond_to?(:pages) && event.pages ? event.pages : []
      pages.each_with_index do |page, page_index|
        page_record = {
          "page" => page_index + 1,
          "trigger" => page.respond_to?(:trigger) ? page.trigger : nil,
          "condition" => condition_hash(page.respond_to?(:condition) ? page.condition : nil)
        }
        scripts = []
        commands = page.respond_to?(:list) && page.list ? page.list : []
        commands.each do |cmd|
          code = cmd.respond_to?(:code) ? cmd.code : nil
          params = cmd.respond_to?(:parameters) ? cmd.parameters : []
          if code == TRANSFER_CODE
            transfer = transfer_record(map_id, event_id, event, page, page_index, params)
            record["transfers"] << transfer if transfer
          elsif code == COMMON_EVENT_CODE
            scripts.concat(common_event_scripts(params[0].to_i))
          elsif SCRIPT_CODES.include?(code)
            scripts.concat(script_fragments(params))
          elsif COMMENT_CODES.include?(code)
            record["comments"] << params[0].to_s if params && params[0]
          elsif TEXT_CODES.include?(code)
            scripts << params[0].to_s if params && params[0]
          end
        end
        script_text = scripts.join("\n")
        record["trainers"].concat(annotate_page_records(extract_trainer_records(map_id, event_id, event, script_text), page_record))
        record["items"].concat(annotate_page_records(extract_item_records(map_id, event_id, event, script_text), page_record))
        record["field_resources"].concat(annotate_page_records(extract_field_resource_records(map_id, event_id, event, script_text), page_record))
        record["gifts"].concat(annotate_page_records(extract_gift_records(map_id, event_id, event, script_text), page_record))
        record["wild_statics"].concat(annotate_page_records(extract_wild_records(map_id, event_id, event, script_text), page_record))
        page_record["script_digest"] = script_digest(script_text)
        record["pages"] << page_record
        if npc_page?(page, event)
          npc = npc_record(map_id, event_id, event, page, page_index, script_text)
          record["npcs"] << npc if npc
        end
      end
      prune_non_npc_records!(record)
      record
    end

    def annotate_page_records(records, page_record)
      return [] unless records.respond_to?(:each)
      records.each do |record|
        next unless record.is_a?(Hash)
        record["page"] ||= page_record["page"]
        record["trigger"] ||= page_record["trigger"]
      end
      records
    rescue
      records || []
    end

    def script_fragments(value)
      out = []
      case value
      when Array
        value.each { |entry| out.concat(script_fragments(entry)) }
      else
        text = value.to_s
        out << text if script_fragment?(text)
      end
      out
    rescue
      []
    end

    def script_fragment?(text)
      return false if text.nil?
      str = text.to_s
      return false if str.empty?
      str =~ /pb[A-Za-z_]|Kernel\.|\$Pokemon|\$game_|PBItems|PokemonSelection|setBattleRule|finishQuest|pbAcceptNewQuest/
    rescue
      false
    end

    def common_events
      @common_events ||= load_rgss_data("Data/CommonEvents.rxdata")
    rescue
      nil
    end

    def common_event_scripts(common_event_id, seen = nil)
      id = common_event_id.to_i
      return [] if id <= 0
      seen ||= {}
      return [] if seen[id]
      seen[id] = true
      events = common_events
      common = events[id] if events && events.respond_to?(:[])
      return [] unless common && common.respond_to?(:list) && common.list
      out = []
      common.list.each do |cmd|
        code = cmd.respond_to?(:code) ? cmd.code : nil
        params = cmd.respond_to?(:parameters) ? cmd.parameters : []
        if code == COMMON_EVENT_CODE
          out.concat(common_event_scripts(params[0].to_i, seen))
        elsif SCRIPT_CODES.include?(code)
          out.concat(script_fragments(params))
        end
      end
      out
    rescue
      []
    end

    def npc_page?(page, event)
      return false unless page
      trigger = page.respond_to?(:trigger) ? page.trigger.to_i : 0
      return false unless trigger == 0
      graphic = page.respond_to?(:graphic) ? page.graphic : nil
      return false unless graphic
      character_name = graphic.respond_to?(:character_name) ? graphic.character_name.to_s : ""
      tile_id = graphic.respond_to?(:tile_id) ? graphic.tile_id.to_i : 0
      return false if character_name.empty? && tile_id <= 0
      name = event.respond_to?(:name) ? event.name.to_s : ""
      return false if name =~ /door|exit|warp|stairs|transfer|hidden|item|ball|pc|tv|bed/i
      return false if character_name =~ /object ball|itemball|door|stairs|sign|pc|tv|bed/i
      true
    rescue
      false
    end

    def npc_record(map_id, event_id, event, page, page_index, script_text)
      graphic = page.respond_to?(:graphic) ? page.graphic : nil
      character_name = graphic && graphic.respond_to?(:character_name) ? graphic.character_name.to_s : ""
      {
        "key" => "npc:#{map_id}:#{event_id}",
        "map_id" => map_id,
        "event_id" => event_id,
        "event_name" => safe_string(event.respond_to?(:name) ? event.name : ""),
        "page" => page_index + 1,
        "trigger" => page.respond_to?(:trigger) ? page.trigger : nil,
        "x" => event.respond_to?(:x) ? event.x : nil,
        "y" => event.respond_to?(:y) ? event.y : nil,
        "graphic" => safe_string(character_name),
        "script_digest" => script_digest(script_text)
      }
    rescue
      nil
    end

    def prune_non_npc_records!(record)
      return record unless record
      non_npc_event_ids = {}
      (record["transfers"] || []).each do |entry|
        event_id = entry["event_id"].to_i
        non_npc_event_ids[event_id] = true if event_id > 0
      end
      (record["items"] || []).each do |entry|
        event_id = entry["event_id"].to_i
        non_npc_event_ids[event_id] = true if event_id > 0
      end
      seen = {}
      record["npcs"] = (record["npcs"] || []).select do |npc|
        event_id = npc["event_id"].to_i
        next false if non_npc_event_ids[event_id]
        key = npc["key"] || "#{npc["map_id"]}:#{npc["event_id"]}"
        next false if seen[key]
        seen[key] = true
        true
      end
      record
    rescue
      record
    end

    def transfer_record(map_id, event_id, event, page, page_index, params)
      destination = params[1].to_i rescue 0
      return nil if destination <= 0
      dest_x = params[2].to_i rescue nil
      dest_y = params[3].to_i rescue nil
      {
        "key" => AutoplayBot::State.transfer_key(map_id, event_id, destination, dest_x, dest_y),
        "map_id" => map_id,
        "event_id" => event_id,
        "event_name" => safe_string(event.respond_to?(:name) ? event.name : ""),
        "page" => page_index + 1,
        "trigger" => page.respond_to?(:trigger) ? page.trigger : nil,
        "x" => event.respond_to?(:x) ? event.x : nil,
        "y" => event.respond_to?(:y) ? event.y : nil,
        "destination_map_id" => destination,
        "destination_name" => map_name(destination),
        "destination_x" => dest_x,
        "destination_y" => dest_y,
        "destination_direction" => params[4]
      }
    rescue
      nil
    end

    def extract_trainer_records(map_id, event_id, event, script_text)
      out = []
      script_text.scan(/pbTrainerBattle\s*\((.*?)\)/m).each do |match|
        record = base_script_record(map_id, event_id, event).merge(
          "call" => "pbTrainerBattle",
          "args" => shrink(match[0]),
          "repeatable_status" => trainer_repeatability_status(script_text),
          "repeatable_reason" => trainer_repeatability_reason(script_text)
        )
        record["trainer_key"] = trainer_key(record)
        out << record
      end
      out
    end

    def trainer_repeatability_status(script_text)
      text = script_text.to_s
      return "likely_repeatable" if text =~ /rematch|re[- ]?battle|repeat|versus seeker|vs\.?\s*seeker|canRematch|pbTrainerIntro/i
      return "likely_one_shot" if text =~ /\$game_self_switches|pbSetSelfSwitch|setSelfSwitch|self[-_ ]switch|\$game_switches\[[^\]]+\]\s*=\s*true|erase_event|eraseevent/i
      "unknown"
    rescue
      "unknown"
    end

    def trainer_repeatability_reason(script_text)
      status = trainer_repeatability_status(script_text)
      case status
      when "likely_repeatable" then "script mentions rematch/rebattle behavior"
      when "likely_one_shot" then "script appears to set switch/self-switch after battle"
      else "no repeatability evidence in script"
      end
    rescue
      "unknown"
    end

    def trainer_key(record)
      [
        "trainer",
        record["map_id"],
        record["event_id"] || record["event_name"],
        record["x"],
        record["y"],
        record["args"]
      ].compact.map(&:to_s).join(":")
    rescue
      "trainer:unknown"
    end

    def extract_item_records(map_id, event_id, event, script_text)
      out = []
      script_text.scan(/(?:Kernel\.)?pbItemBall\s*\((.*?)\)/m).each do |match|
        out << base_script_record(map_id, event_id, event).merge("call" => "pbItemBall", "args" => shrink(match[0]))
      end
      script_text.scan(/(?:Kernel\.)?pbReceiveItem\s*\((.*?)\)/m).each do |match|
        out << base_script_record(map_id, event_id, event).merge("call" => "pbReceiveItem", "args" => shrink(match[0]))
      end
      out
    end

    def extract_field_resource_records(map_id, event_id, event, script_text)
      kind = field_resource_kind(event, script_text)
      return [] unless kind
      [
        base_script_record(map_id, event_id, event).merge(
          "call" => "fieldResource",
          "args" => shrink(script_text),
          "resource_kind" => kind
        )
      ]
    rescue
      []
    end

    def field_resource_kind(event, script_text)
      name = event.respond_to?(:name) ? event.name.to_s : ""
      text = "#{name} #{script_text}".downcase
      return "spider_web" if text =~ /\bweb\b|spider|spinarak|ariados/
      return "trash" if text =~ /trash\s*can|trashcan|\btrash\b|garbage|dustbin|rubbish/
      return "mushroom" if text =~ /mushroom|fungus|paras/
      return "berry" if text =~ /berry|apricorn|forage/
      return "honey_tree" if text =~ /honey\s*tree|\bhoney\b|sweet\s*scent/
      nil
    rescue
      nil
    end

    def extract_gift_records(map_id, event_id, event, script_text)
      out = []
      script_text.scan(/pbAddPokemon(?:ID|Silent|ToParty|ToPartySilent)?\s*\((.*?)\)/m).each do |match|
        out << base_script_record(map_id, event_id, event).merge("call" => "pbAddPokemon", "args" => shrink(match[0]))
      end
      out
    end

    def extract_wild_records(map_id, event_id, event, script_text)
      out = []
      script_text.scan(/pb(?:Wild|DoubleWild|TripleWild|1v3Wild)Battle\w*\s*\((.*?)\)/m).each do |match|
        out << base_script_record(map_id, event_id, event).merge("call" => "pbWildBattle", "args" => shrink(match[0]))
      end
      out
    end

    def base_script_record(map_id, event_id, event)
      {
        "map_id" => map_id,
        "event_id" => event_id,
        "event_name" => safe_string(event.respond_to?(:name) ? event.name : ""),
        "x" => event.respond_to?(:x) ? event.x : nil,
        "y" => event.respond_to?(:y) ? event.y : nil
      }
    end

    def condition_hash(condition)
      return {} unless condition
      {
        "switch1_valid" => condition.respond_to?(:switch1_valid) ? condition.switch1_valid : nil,
        "switch2_valid" => condition.respond_to?(:switch2_valid) ? condition.switch2_valid : nil,
        "variable_valid" => condition.respond_to?(:variable_valid) ? condition.variable_valid : nil,
        "self_switch_valid" => condition.respond_to?(:self_switch_valid) ? condition.self_switch_valid : nil,
        "switch1_id" => condition.respond_to?(:switch1_id) ? condition.switch1_id : nil,
        "switch2_id" => condition.respond_to?(:switch2_id) ? condition.switch2_id : nil,
        "variable_id" => condition.respond_to?(:variable_id) ? condition.variable_id : nil,
        "variable_value" => condition.respond_to?(:variable_value) ? condition.variable_value : nil,
        "self_switch_ch" => condition.respond_to?(:self_switch_ch) ? condition.self_switch_ch : nil
      }
    end

    def script_digest(text)
      return "" if text.to_s.empty?
      shrink(text.to_s.gsub(/\s+/, " "))
    end

    def shrink(text, length = 220)
      str = safe_string(text)
      str.length > length ? str[0, length] : str
    end

    def safe_string(value)
      value.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")
    rescue
      value.to_s
    end

    def load_rgss_data(path)
      if Kernel.respond_to?(:load_data, true)
        return Kernel.send(:load_data, path)
      end
      if Object.new.respond_to?(:load_data, true)
        return Object.new.send(:load_data, path)
      end
      File.open(path, "rb") { |f| Marshal.load(f) }
    end

    def nearest_unvisited_transfer
      map = current_map_data
      return nil unless map && defined?($game_player) && $game_player
      candidates = map["transfers"].reject do |tr|
        AutoplayBot::State.transfer_visited?(tr["key"]) ||
          (AutoplayBot::State.respond_to?(:target_failed?) && AutoplayBot::State.target_failed?(tr, 180, "transfer"))
      end
      return nil if candidates.empty?
      candidates.min_by do |tr|
        (tr["x"].to_i - $game_player.x).abs + (tr["y"].to_i - $game_player.y).abs
      end
    end
  end

  module Pathfinder
    DIRS = [
      [2, 0, 1],
      [4, -1, 0],
      [6, 1, 0],
      [8, 0, -1]
    ] unless const_defined?(:DIRS)

    module_function

    def path_to(x, y, max_nodes = 1200, include_adjacent = true)
      return nil unless defined?($game_player) && $game_player && defined?($game_map) && $game_map
      targets = include_adjacent ? reachable_targets_for(x.to_i, y.to_i) : exact_target_for(x.to_i, y.to_i)
      return [] if targets.any? { |tx, ty| tx == $game_player.x && ty == $game_player.y }
      find_path_to_any(targets, max_nodes)
    end

    def exact_target_for(x, y)
      valid_tile?(x, y) ? [[x, y]] : []
    end

    def reachable_targets_for(x, y)
      targets = []
      targets << [x, y] if valid_tile?(x, y)
      DIRS.each do |_dir, dx, dy|
        nx = x - dx
        ny = y - dy
        targets << [nx, ny] if valid_tile?(nx, ny)
      end
      targets.uniq
    end

    def find_path_to_any(targets, max_nodes)
      start = [$game_player.x, $game_player.y]
      target_lookup = {}
      targets.each { |t| target_lookup[[t[0], t[1]]] = true }
      return [] if target_lookup[start]

      queue = [start]
      parent = {}
      visited = { start => true }
      head = 0
      searched = 0
      started_at = Time.now.to_f
      while head < queue.length
        pos = queue[head]
        head += 1
        searched += 1
        return nil if searched > max_nodes
        return nil if path_search_should_abort?(started_at, searched, max_nodes)
        DIRS.each do |dir, dx, dy|
          jump_pos = ledge_jump_destination(pos[0], pos[1], dir, dx, dy)
          if jump_pos && !visited[jump_pos]
            visited[jump_pos] = true
            parent[jump_pos] = [pos, dir]
            return reconstruct_path(jump_pos, parent, start) if target_lookup[jump_pos]
            queue << jump_pos
            next
          end
          nx = pos[0] + dx
          ny = pos[1] + dy
          next unless valid_tile?(nx, ny)
          next unless passable?(pos[0], pos[1], dir)
          next_pos = [nx, ny]
          next if visited[next_pos]
          visited[next_pos] = true
          parent[next_pos] = [pos, dir]
          return reconstruct_path(next_pos, parent, start) if target_lookup[next_pos]
          queue << next_pos
        end
      end
      nil
    end

    def path_search_should_abort?(started_at, searched, max_nodes)
      return false unless (searched.to_i % 64).zero?
      if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.respond_to?(:emergency_hotkey_stop)
        AutoplayBot::Runtime.emergency_hotkey_stop
        return true if AutoplayBot::Runtime.respond_to?(:running?) && !AutoplayBot::Runtime.running?
      end
      Time.now.to_f - started_at.to_f > path_time_budget_seconds(max_nodes)
    rescue
      false
    end

    def path_time_budget_seconds(max_nodes)
      budget = max_nodes.to_i
      base = if defined?(AutoplayBot::Config) && AutoplayBot::Config.respond_to?(:planner_budget)
               case AutoplayBot::Config.planner_budget
               when "aggressive" then 0.040
               when "balanced" then 0.028
               else 0.016
               end
             else
               0.016
             end
      base += 0.008 if budget >= 2400
      base += 0.010 if budget >= 4800
      [[base, 0.010].max, 0.055].min
    rescue
      0.016
    end

    def reconstruct_path(pos, parent, start)
      path = []
      current = pos
      until current == start
        entry = parent[current]
        break unless entry
        current = entry[0]
        path << entry[1]
      end
      path.reverse
    rescue
      []
    end

    def valid_tile?(x, y)
      return false unless defined?($game_map) && $game_map
      return $game_map.valid?(x, y) if $game_map.respond_to?(:valid?)
      x >= 0 && y >= 0
    rescue
      false
    end

    def passable?(x, y, dir)
      return false unless defined?($game_player) && $game_player
      return false if blocked_step?(x, y, dir)
      $game_player.passable?(x, y, dir)
    rescue
      false
    end

    def ledge_jump_destination(x, y, dir, dx = nil, dy = nil)
      dx ||= direction_delta(dir)[0]
      dy ||= direction_delta(dir)[1]
      ledge_x = x.to_i + dx.to_i
      ledge_y = y.to_i + dy.to_i
      return nil if blocked_step?(x, y, dir)
      return nil unless terrain_ledge?(ledge_x, ledge_y, dir)
      land_x = x.to_i + (dx.to_i * 2)
      land_y = y.to_i + (dy.to_i * 2)
      return nil unless valid_tile?(land_x, land_y)
      return nil unless ledge_landing_open?(land_x, land_y)
      return nil if event_blocks_tile?(land_x, land_y)
      [land_x, land_y]
    rescue
      nil
    end

    def direction_delta(dir)
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

    def blocked_step?(x, y, dir)
      defined?(AutoplayBot::Director) &&
        AutoplayBot::Director.respond_to?(:pathfinder_blocked_step?) &&
        AutoplayBot::Director.pathfinder_blocked_step?($game_map.map_id, x, y, dir)
    rescue
      false
    end

    def terrain_ledge?(x, y, dir = nil)
      return false unless defined?($game_map) && $game_map && $game_map.respond_to?(:terrain_tag)
      tag = $game_map.terrain_tag(x.to_i, y.to_i) rescue nil
      return false unless tag && tag.respond_to?(:ledge)
      ledge = tag.ledge
      return false unless ledge
      return true if dir.nil?
      # Some terrain tags only say "this is a ledge" without encoding the
      # allowed jump direction. Treat those as standard south/down ledges
      # instead of allowing the bot to climb up cliffs from below.
      return dir.to_i == 2 if ledge == true
      return ledge.to_i == dir.to_i if ledge.respond_to?(:to_i) && ledge.to_i > 0
      true
    rescue
      false
    end

    def event_blocks_tile?(x, y)
      return false unless defined?($game_map) && $game_map && $game_map.respond_to?(:events) && $game_map.events
      $game_map.events.values.any? do |event|
        next false unless event && event.respond_to?(:x) && event.respond_to?(:y)
        next false unless event.x.to_i == x.to_i && event.y.to_i == y.to_i
        next false if event.respond_to?(:through) && event.through
        tile_id = event.respond_to?(:tile_id) ? event.tile_id.to_i : 0
        graphic = event.respond_to?(:character_name) ? event.character_name.to_s : ""
        tile_id > 0 || !graphic.empty?
      end
    rescue
      false
    end

    def ledge_landing_open?(x, y)
      return false unless valid_tile?(x, y)
      if defined?($game_map) && $game_map && $game_map.respond_to?(:passableStrict?)
        return [2, 4, 6, 8].any? { |dir| $game_map.passableStrict?(x.to_i, y.to_i, dir, $game_player) rescue true }
      end
      true
    rescue
      true
    end

    def heuristic(pos, targets)
      targets.map { |tx, ty| (tx - pos[0]).abs + (ty - pos[1]).abs }.min || 0
    end
  end
end
