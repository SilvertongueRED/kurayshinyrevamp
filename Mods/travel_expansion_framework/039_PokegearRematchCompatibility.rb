if defined?(PokemonGlobalMetadata)
  class PokemonGlobalMetadata
    attr_accessor :tef_phone_rematch_entries
    attr_accessor :tef_phone_rematch_sequence
    attr_accessor :tef_phone_rematch_backfill_signature
  end
end

module TravelExpansionFramework
  PHONE_REMATCH_BACKFILL_VERSION = 6 unless const_defined?(:PHONE_REMATCH_BACKFILL_VERSION)
  PHONE_REMATCH_LEVEL_MODES = {
    :default => "Default levels",
    :scaled  => "Scale to party",
    :level100 => "Level 100"
  }.freeze

  class << self
    def phone_rematch_entries
      return {} if !$PokemonGlobal
      $PokemonGlobal.tef_phone_rematch_entries = {} if !$PokemonGlobal.tef_phone_rematch_entries.is_a?(Hash)
      return $PokemonGlobal.tef_phone_rematch_entries
    rescue
      return {}
    end

    def phone_rematch_value_key(value)
      return value.inspect
    rescue
      return value.to_s
    end

    def phone_rematch_blank_bitmap
      @phone_rematch_blank_bitmap ||= Bitmap.new(1, 1)
      return @phone_rematch_blank_bitmap
    rescue
      @phone_rematch_blank_bitmap ||= BitmapWrapper.new(1, 1) if defined?(BitmapWrapper)
      return @phone_rematch_blank_bitmap
    end

    def phone_rematch_entry_key(expansion_id, trainer_type, trainer_name, trainer_version)
      [
        expansion_id.to_s,
        phone_rematch_value_key(trainer_type),
        trainer_name.to_s,
        integer(trainer_version, 0)
      ].join("|")
    end

    def phone_rematch_trainer_version_from_object(trainer, fallback = 0)
      return integer(fallback, 0) if trainer.nil?
      [:travel_expansion_external_trainer_version, :trainer_version, :version].each do |method_name|
        next if !trainer.respond_to?(method_name)
        value = trainer.send(method_name) rescue nil
        return integer(value, fallback) if !value.nil?
      end
      [:@travel_expansion_external_trainer_version, :@travel_expansion_trainer_version,
       :@trainer_version, :@version].each do |ivar|
        next if !trainer.instance_variable_defined?(ivar)
        value = trainer.instance_variable_get(ivar) rescue nil
        return integer(value, fallback) if !value.nil?
      end
      return integer(fallback, 0)
    rescue
      return integer(fallback, 0)
    end

    def phone_rematch_external_trainer_type_from_object(trainer, fallback = nil)
      return fallback if trainer.nil?
      if trainer.respond_to?(:travel_expansion_external_trainer_type)
        value = trainer.travel_expansion_external_trainer_type rescue nil
        return value if !value.nil?
      end
      if trainer.instance_variable_defined?(:@travel_expansion_external_trainer_type)
        value = trainer.instance_variable_get(:@travel_expansion_external_trainer_type) rescue nil
        return value if !value.nil?
      end
      return trainer.trainer_type if trainer.respond_to?(:trainer_type)
      return fallback
    rescue
      return fallback
    end

    def phone_rematch_entry_canonical_key(entry)
      return "" if !entry.is_a?(Hash)
      expansion_id = entry["expansion_id"].to_s
      trainer_type = entry["trainer_type"]
      type_key = entry["trainer_type_key"].to_s
      if type_key.empty? || type_key == "nil"
        type_key = phone_rematch_value_key(trainer_type)
      end
      [
        expansion_id,
        type_key,
        entry["trainer_name"].to_s,
        integer(entry["trainer_version"], 0)
      ].join("|")
    rescue
      return entry["key"].to_s
    end

    def next_phone_rematch_sequence
      return 0 if !$PokemonGlobal
      current = integer($PokemonGlobal.tef_phone_rematch_sequence, 0) + 1
      $PokemonGlobal.tef_phone_rematch_sequence = current
      return current
    rescue
      return 0
    end

    def phone_rematch_current_expansion_id
      map_expansion = current_map_expansion_id if respond_to?(:current_map_expansion_id)
      return map_expansion.to_s if !map_expansion.to_s.empty?
      return "" if defined?($game_map) && $game_map
      marker = current_expansion_marker if respond_to?(:current_expansion_marker)
      return marker.to_s if !marker.to_s.empty?
      return ""
    rescue
      return ""
    end

    def phone_rematch_display_type_for_trainer(trainer, fallback_type)
      if trainer
        data = trainer.respond_to?(:travel_expansion_external_trainer_type_data) ? trainer.travel_expansion_external_trainer_type_data : {}
        runtime_id = data[:runtime_id] || data["runtime_id"] if data.is_a?(Hash)
        return runtime_id if phone_rematch_trainer_type_available?(runtime_id)
        return trainer.trainer_type if trainer.respond_to?(:trainer_type) && phone_rematch_trainer_type_available?(trainer.trainer_type)
      end
      return fallback_type if phone_rematch_trainer_type_available?(fallback_type)
      return TRAINER_HOST_PLACEHOLDER_TYPE if defined?(TRAINER_HOST_PLACEHOLDER_TYPE) && phone_rematch_trainer_type_available?(TRAINER_HOST_PLACEHOLDER_TYPE)
      begin
        return GameData::TrainerType.keys[0] if defined?(GameData::TrainerType) && GameData::TrainerType.respond_to?(:keys)
      rescue
      end
      return fallback_type
    end

    def phone_rematch_trainer_type_available?(trainer_type)
      return false if trainer_type.nil?
      return GameData::TrainerType.exists?(trainer_type) if defined?(GameData::TrainerType)
      return false
    rescue
      return false
    end

    def phone_rematch_external_trainer(expansion_id, trainer_type, trainer_name, trainer_version)
      return nil if expansion_id.to_s.empty? || !respond_to?(:load_external_trainer)
      return load_external_trainer(expansion_id, trainer_type, trainer_name, trainer_version)
    rescue
      return nil
    end

    def phone_rematch_host_trainer(trainer_type, trainer_name, trainer_version)
      trainer = nil
      trainer = tef_original_pbLoadTrainer(trainer_type, trainer_name, trainer_version) if defined?(tef_original_pbLoadTrainer)
      return trainer if trainer
      return nil
    rescue
      return nil
    end

    def phone_rematch_host_trainer_available?(trainer_type, trainer_name, trainer_version)
      return true if phone_rematch_host_trainer(trainer_type, trainer_name, trainer_version)
      if defined?(getTrainersDataMode)
        mode_record = getTrainersDataMode.try_get(trainer_type, trainer_name, trainer_version) rescue nil
        return true if mode_record
      end
      if defined?(GameData::Trainer)
        return true if GameData::Trainer.exists?(trainer_type, trainer_name, trainer_version)
      end
      return false
    rescue
      return false
    end

    def phone_rematch_loadable?(expansion_id, trainer_type, trainer_name, trainer_version)
      if !expansion_id.to_s.empty?
        return !phone_rematch_external_trainer(expansion_id, trainer_type, trainer_name, trainer_version).nil?
      end
      return phone_rematch_host_trainer_available?(trainer_type, trainer_name, trainer_version)
    rescue
      return false
    end

    def record_phone_rematch_from_argument(arg)
      return false if @phone_rematch_running
      if arg.is_a?(Array) && arg.length >= 3
        return record_phone_rematch_trainer(arg[0], arg[1], arg[2], arg[3])
      end
      return false if !defined?(NPCTrainer) || !arg.is_a?(NPCTrainer)
      expansion_id = external_trainer_expansion_id(arg) if respond_to?(:external_trainer_expansion_id)
      trainer_type = if arg.respond_to?(:travel_expansion_external_trainer_type) && arg.travel_expansion_external_trainer_type
                       arg.travel_expansion_external_trainer_type
                     else
                       arg.trainer_type
                     end
      version = phone_rematch_trainer_version_from_object(arg, 0)
      return record_phone_rematch_trainer(
        trainer_type,
        arg.name,
        version,
        arg.respond_to?(:lose_text) ? arg.lose_text : nil,
        :expansion_id => expansion_id,
        :source_trainer => arg
      )
    rescue => e
      log("[phone_rematch] record from argument failed: #{e.class}: #{e.message}") if respond_to?(:log)
      return false
    end

    def record_phone_rematch_trainer(trainer_type, trainer_name, trainer_version = 0, end_speech = nil, options = {})
      return false if !$PokemonGlobal || @phone_rematch_running
      name = trainer_name.to_s
      return false if name.empty?
      version = integer(trainer_version, 0)
      expansion_id = options[:expansion_id].to_s
      expansion_id = phone_rematch_current_expansion_id if expansion_id.empty?
      sample_trainer = options[:source_trainer]
      if sample_trainer.nil? && !expansion_id.empty? && respond_to?(:load_external_trainer)
        sample_trainer = phone_rematch_external_trainer(expansion_id, trainer_type, name, version)
      end
      if sample_trainer
        sample_expansion = external_trainer_expansion_id(sample_trainer) if respond_to?(:external_trainer_expansion_id)
        expansion_id = sample_expansion.to_s if !sample_expansion.to_s.empty?
        trainer_type = phone_rematch_external_trainer_type_from_object(sample_trainer, trainer_type)
        version = phone_rematch_trainer_version_from_object(sample_trainer, version)
      end
      event_record = phone_rematch_event_record_for_context(name, trainer_type, version, options)
      if event_record
        trainer_type = event_record[0]
        version = integer(event_record[2], version)
        end_speech = event_record[3] if (end_speech.nil? || end_speech.to_s.empty?) && event_record[3]
        if sample_trainer.nil? && !expansion_id.empty? && respond_to?(:load_external_trainer)
          sample_trainer = phone_rematch_external_trainer(expansion_id, trainer_type, name, version)
        end
      end
      corrected_to_host = false
      if sample_trainer.nil? && !expansion_id.empty?
        host_trainer = phone_rematch_host_trainer(trainer_type, name, version)
        if host_trainer
          log("[phone_rematch] corrected host trainer source for #{name} #{trainer_type}/#{version} from #{expansion_id}") if respond_to?(:log)
          expansion_id = ""
          sample_trainer = host_trainer
          corrected_to_host = true
        end
      end
      return false if sample_trainer.nil? && !phone_rematch_loadable?(expansion_id, trainer_type, name, version)
      contact_type = phone_rematch_display_type_for_trainer(sample_trainer, trainer_type)
      key = phone_rematch_entry_key(expansion_id, trainer_type, name, version)
      entries = phone_rematch_entries
      entry = entries[key] || {}
      entry["key"] = key
      entry["expansion_id"] = expansion_id
      entry["source_locked_to_host"] = true if corrected_to_host
      entry.delete("source_locked_to_host") if !corrected_to_host && !expansion_id.empty?
      entry["trainer_type"] = trainer_type
      entry["trainer_type_key"] = phone_rematch_value_key(trainer_type)
      entry["contact_type"] = contact_type
      entry["contact_type_key"] = phone_rematch_value_key(contact_type)
      entry["trainer_name"] = name
      entry["trainer_version"] = version
      entry["end_speech"] = end_speech.to_s if end_speech && !end_speech.to_s.empty?
      entry["map_id"] = integer(options[:map_id], ($game_map && $game_map.respond_to?(:map_id)) ? $game_map.map_id : 0)
      if options.key?(:event_id)
        entry["event_id"] = integer(options[:event_id], 0)
      elsif pbMapInterpreterRunning?
        event = pbMapInterpreter.get_character(0) rescue nil
        entry["event_id"] = event.respond_to?(:id) ? event.id : 0
      else
        entry["event_id"] ||= 0
      end
      entry["sequence"] = next_phone_rematch_sequence
      entries[key] = entry
      ensure_phone_number_for_rematch(entry)
      log("[phone_rematch] registered #{name} #{trainer_type}/#{version} expansion=#{expansion_id.empty? ? "host" : expansion_id}") if respond_to?(:log)
      return true
    rescue => e
      log("[phone_rematch] register failed for #{trainer_type}/#{trainer_name}/#{trainer_version}: #{e.class}: #{e.message}") if respond_to?(:log)
      return false
    end

    def ensure_phone_number_for_rematch(entry)
      return false if !$PokemonGlobal || !entry.is_a?(Hash)
      $PokemonGlobal.phoneNumbers = [] if !$PokemonGlobal.phoneNumbers.is_a?(Array)
      contact_type = entry["contact_type"]
      trainer_name = entry["trainer_name"].to_s
      return false if trainer_name.empty?
      map_id = integer(entry["map_id"], ($game_map ? $game_map.map_id : 0))
      event_id = integer(entry["event_id"], 0)
      contact_key = phone_rematch_value_key(contact_type)
      existing = $PokemonGlobal.phoneNumbers.find do |num|
        num.is_a?(Array) && num.length == 8 &&
          phone_rematch_value_key(num[1]) == contact_key &&
          num[2].to_s == trainer_name &&
          integer(num[6], 0) == map_id &&
          integer(num[7], 0) == event_id
      end
      existing ||= $PokemonGlobal.phoneNumbers.find do |num|
        num.is_a?(Array) && num.length == 8 &&
          phone_rematch_value_key(num[1]) == contact_key &&
          num[2].to_s == trainer_name &&
          !phone_rematch_registered_entry_for_phone_number(num)
      end
      if existing
        existing[0] = true
        existing[3] = 0
        existing[4] = 2
        existing[5] = [integer(existing[5], 0), 1].max
        existing[6] = map_id
        existing[7] = event_id
      else
        $PokemonGlobal.phoneNumbers << [true, contact_type, trainer_name, 0, 2, 1, map_id, event_id]
      end
      return true
    rescue => e
      log("[phone_rematch] phone contact sync failed: #{e.class}: #{e.message}") if respond_to?(:log)
      return false
    end

    def phone_rematch_entry_loadable_entry?(entry)
      return false if !entry.is_a?(Hash)
      return phone_rematch_loadable?(
        entry["expansion_id"].to_s,
        entry["trainer_type"],
        entry["trainer_name"].to_s,
        integer(entry["trainer_version"], 0)
      )
    rescue
      return false
    end

    def repair_phone_rematch_entry_source!(entry)
      return entry if !entry.is_a?(Hash)
      corrected_to_host = false
      if integer(entry["source_repair_version"], 0) != PHONE_REMATCH_BACKFILL_VERSION
        record = phone_rematch_event_record_for_context(
          entry["trainer_name"].to_s,
          entry["trainer_type"],
          integer(entry["trainer_version"], 0),
          :map_id => integer(entry["map_id"], 0),
          :event_id => integer(entry["event_id"], 0)
        )
        if record
          entry["trainer_type"] = record[0]
          entry["trainer_type_key"] = phone_rematch_value_key(record[0])
          entry["trainer_version"] = integer(record[2], 0)
          entry["end_speech"] = record[3].to_s if record[3] && !record[3].to_s.empty?
        end
        expansion_id = entry["expansion_id"].to_s
        if !expansion_id.empty?
          imported = phone_rematch_external_trainer(
            expansion_id,
            entry["trainer_type"],
            entry["trainer_name"].to_s,
            integer(entry["trainer_version"], 0)
          )
          host_trainer = phone_rematch_host_trainer(
            entry["trainer_type"],
            entry["trainer_name"].to_s,
            integer(entry["trainer_version"], 0)
          )
          if imported.nil? && host_trainer
            log("[phone_rematch] repaired wrong expansion label for #{entry["trainer_name"]} #{entry["trainer_type"]}/#{entry["trainer_version"]} from #{expansion_id} to host") if respond_to?(:log)
            entry["expansion_id"] = ""
            entry["source_locked_to_host"] = true
            corrected_to_host = true
            entry["contact_type"] = phone_rematch_display_type_for_trainer(host_trainer, entry["trainer_type"])
            entry["contact_type_key"] = phone_rematch_value_key(entry["contact_type"])
          end
        end
        entry["source_repair_version"] = PHONE_REMATCH_BACKFILL_VERSION
      end
      if entry["expansion_id"].to_s.empty? && entry["source_locked_to_host"] != true &&
         !corrected_to_host && integer(entry["map_id"], 0) > 0 && respond_to?(:current_map_expansion_id)
        expansion_id = current_map_expansion_id(integer(entry["map_id"], 0))
        entry["expansion_id"] = expansion_id.to_s if !expansion_id.to_s.empty?
      end
      entry["key"] = phone_rematch_entry_key(
        entry["expansion_id"].to_s,
        entry["trainer_type"],
        entry["trainer_name"].to_s,
        integer(entry["trainer_version"], 0)
      )
      return entry
    rescue => e
      log("[phone_rematch] entry repair failed: #{e.class}: #{e.message}") if respond_to?(:log)
      return entry
    end

    def preferred_phone_rematch_entry(existing, candidate)
      return candidate if existing.nil?
      return candidate if existing["native_phone"] && !candidate["native_phone"]
      existing_loadable = phone_rematch_entry_loadable_entry?(existing)
      candidate_loadable = phone_rematch_entry_loadable_entry?(candidate)
      return candidate if candidate_loadable && !existing_loadable
      return candidate if integer(candidate["sequence"], 0) > integer(existing["sequence"], 0)
      return existing
    rescue
      return existing || candidate
    end

    def normalize_phone_rematch_entries!
      return if !$PokemonGlobal
      entries = phone_rematch_entries
      normalized = {}
      entries.each_value do |entry|
        next if !entry.is_a?(Hash)
        repair_phone_rematch_entry_source!(entry)
        key = phone_rematch_entry_canonical_key(entry)
        next if key.empty?
        entry["key"] = key
        normalized[key] = preferred_phone_rematch_entry(normalized[key], entry)
      end
      $PokemonGlobal.tef_phone_rematch_entries = normalized
    rescue => e
      log("[phone_rematch] entry normalization failed: #{e.class}: #{e.message}") if respond_to?(:log)
    end

    def phone_rematch_registered_entry_for_phone_number(num)
      return nil if !num.is_a?(Array) || num.length != 8
      trainer_name = num[2].to_s
      return nil if trainer_name.empty?
      map_id = integer(num[6], 0)
      event_id = integer(num[7], 0)
      contact_key = phone_rematch_value_key(num[1])
      candidates = phone_rematch_entries.values.find_all do |entry|
        entry.is_a?(Hash) &&
          entry["trainer_name"].to_s == trainer_name &&
          (entry["contact_type_key"].to_s == contact_key.to_s ||
           (map_id > 0 && integer(entry["map_id"], 0) == map_id && integer(entry["event_id"], 0) == event_id))
      end
      return candidates.max_by { |entry| integer(entry["sequence"], 0) }
    rescue
      return nil
    end

    def dedupe_phone_rematch_phone_numbers!
      return if !$PokemonGlobal || !$PokemonGlobal.phoneNumbers.is_a?(Array)
      best = {}
      passthrough = []
      $PokemonGlobal.phoneNumbers.each do |num|
        if !num.is_a?(Array) || num.length != 8
          passthrough << num
          next
        end
        key = [
          phone_rematch_value_key(num[1]),
          num[2].to_s
        ].join("|")
        current = best[key]
        if current.nil?
          best[key] = num
          next
        end
        current_entry = phone_rematch_registered_entry_for_phone_number(current)
        next_entry = phone_rematch_registered_entry_for_phone_number(num)
        best[key] = num if
          (next_entry && !current_entry) ||
          integer(num[5], 0) > integer(current[5], 0) ||
          (num[0] && !current[0])
      end
      $PokemonGlobal.phoneNumbers = passthrough + best.values
    rescue => e
      log("[phone_rematch] phone contact dedupe failed: #{e.class}: #{e.message}") if respond_to?(:log)
    end

    def sync_phone_rematch_contacts!(full_backfill = false)
      backfill_phone_rematches_from_self_switches! if full_backfill
      normalize_phone_rematch_entries!
      dedupe_phone_rematch_phone_numbers!
      phone_rematch_entries.each_value { |entry| ensure_phone_number_for_rematch(entry) }
      dedupe_phone_rematch_phone_numbers!
    rescue => e
      log("[phone_rematch] contact sync failed: #{e.class}: #{e.message}") if respond_to?(:log)
    end

    def visible_phone_contacts?
      return false if !$PokemonGlobal || !$PokemonGlobal.phoneNumbers.is_a?(Array)
      return $PokemonGlobal.phoneNumbers.any? { |num| num.is_a?(Array) && num[0] }
    rescue
      return false
    end

    def quick_phone_rematch_pokegear_access!
      return false if !$Trainer || !$Trainer.respond_to?(:has_pokegear=)
      has_entries = false
      begin
        has_entries = phone_rematch_entries.values.any? { |entry| entry.is_a?(Hash) }
      rescue
        has_entries = false
      end
      return false if !has_entries && !visible_phone_contacts?
      return true if $Trainer.respond_to?(:has_pokegear) && $Trainer.has_pokegear
      $Trainer.has_pokegear = true
      log("[phone_rematch] enabled host Pokegear access for rematch phonebook") if respond_to?(:log)
      return true
    rescue => e
      log("[phone_rematch] quick Pokegear access failed: #{e.class}: #{e.message}") if respond_to?(:log)
      return false
    end

    def ensure_phone_rematch_pokegear_access!(full_sync = true)
      return false if !$Trainer || !$Trainer.respond_to?(:has_pokegear=)
      sync_phone_rematch_contacts!(true) if full_sync
      return quick_phone_rematch_pokegear_access!
    rescue => e
      log("[phone_rematch] Pokegear access sync failed: #{e.class}: #{e.message}") if respond_to?(:log)
      return false
    end

    def phone_rematch_menu_available?
      return false if !$PokemonGlobal
      return true if phone_rematch_entries.values.any? { |entry| entry.is_a?(Hash) }
      return visible_phone_contacts?
    rescue
      return false
    end

    def phone_rematch_enable_access_if_available!
      return false if !$Trainer || !$Trainer.respond_to?(:has_pokegear=)
      return false if !phone_rematch_menu_available?
      return true if $Trainer.respond_to?(:has_pokegear) && $Trainer.has_pokegear
      $Trainer.has_pokegear = true
      log("[phone_rematch] enabled host Pokegear access for rematch phonebook") if respond_to?(:log)
      return true
    rescue => e
      log("[phone_rematch] Pokegear access enable failed: #{e.class}: #{e.message}") if respond_to?(:log)
      return false
    end

    def native_phone_trainer_entries
      return [] if !$PokemonGlobal || !$PokemonGlobal.phoneNumbers.is_a?(Array)
      entries = []
      $PokemonGlobal.phoneNumbers.each do |num|
        next if !num.is_a?(Array) || !num[0] || num.length != 8
        trainer_type = num[1]
        trainer_name = num[2].to_s
        next if trainer_name.empty?
        next if phone_rematch_registered_entry_for_phone_number(num) || phone_rematch_entry_for(trainer_type, trainer_name)
        map_id = integer(num[6], 0)
        expansion_id = current_map_expansion_id(map_id) if respond_to?(:current_map_expansion_id)
        entries << {
          "key" => "native_phone|#{phone_rematch_value_key(trainer_type)}|#{trainer_name}|#{map_id}|#{integer(num[7], 0)}",
          "expansion_id" => expansion_id.to_s,
          "trainer_type" => trainer_type,
          "trainer_type_key" => phone_rematch_value_key(trainer_type),
          "contact_type" => trainer_type,
          "contact_type_key" => phone_rematch_value_key(trainer_type),
          "trainer_name" => trainer_name,
          "trainer_version" => 0,
          "map_id" => map_id,
          "event_id" => integer(num[7], 0),
          "sequence" => 0,
          "native_phone" => true,
          "native_rematch_ready" => integer(num[4], 0) >= 2
        }
      end
      return entries
    rescue => e
      log("[phone_rematch] native phone merge failed: #{e.class}: #{e.message}") if respond_to?(:log)
      return []
    end

    def phone_rematch_menu_entries
      normalize_phone_rematch_entries! if $PokemonGlobal
      entries = []
      entries.concat(phone_rematch_entries.values.find_all { |entry| entry.is_a?(Hash) })
      entries.concat(native_phone_trainer_entries)
      unique = {}
      entries.each do |entry|
        repair_phone_rematch_entry_source!(entry) if entry.is_a?(Hash) && !entry["native_phone"]
        key = phone_rematch_entry_canonical_key(entry)
        key = [
          entry["expansion_id"].to_s,
          phone_rematch_value_key(entry["trainer_type"]),
          entry["trainer_name"].to_s,
          integer(entry["trainer_version"], 0)
        ].join("|") if key.to_s.empty?
        unique[key] = preferred_phone_rematch_entry(unique[key], entry)
      end
      return unique.values.sort_by do |entry|
        [
          phone_rematch_world_label(entry),
          phone_rematch_trainer_display_name(entry),
          integer(entry["sequence"], 0)
        ]
      end
    rescue => e
      log("[phone_rematch] rematch menu build failed: #{e.class}: #{e.message}") if respond_to?(:log)
      return []
    end

    def phone_rematch_menu_available?
      return false if !$PokemonGlobal
      return true if phone_rematch_entries.values.any? { |entry| entry.is_a?(Hash) }
      return visible_phone_contacts?
    rescue
      return false
    end

    def phone_rematch_world_label(entry)
      expansion_id = entry.is_a?(Hash) ? entry["expansion_id"].to_s : ""
      return "Infinite Fusion" if expansion_id.empty? || (defined?(HOST_EXPANSION_ID) && expansion_id == HOST_EXPANSION_ID)
      return release_world_display_name(expansion_id) if respond_to?(:release_world_display_name)
      manifest = manifest_for(expansion_id) if respond_to?(:manifest_for)
      return manifest[:name].to_s if manifest.is_a?(Hash) && manifest[:name] && !manifest[:name].to_s.empty?
      return expansion_id.split(/[_\s-]+/).map { |part| part.capitalize }.join(" ")
    rescue
      return expansion_id.to_s
    end

    def phone_rematch_location_label(entry)
      world = phone_rematch_world_label(entry)
      map_id = integer(entry["map_id"], 0) if entry.is_a?(Hash)
      map_name = ""
      if map_id && map_id > 0
        map_name = pbGetMessage(MessageTypes::MapNames, map_id) rescue ""
      end
      parts = [world]
      parts << map_name if !map_name.to_s.empty?
      return parts.join(" - ")
    rescue
      return phone_rematch_world_label(entry)
    end

    def phone_rematch_trainer_icon_filename(entry)
      source = phone_rematch_trainer_icon_source(entry)
      return source[:filename] if source.is_a?(Hash)
      return nil
    rescue
      return nil
    end

    def phone_rematch_trainer_type_key_candidates(value)
      text = value.to_s.strip
      return [] if text.empty?
      candidates = []
      if text =~ /\A:([A-Za-z_][A-Za-z0-9_]*)\z/
        candidates << $1.to_sym
      elsif text =~ /\A"(.+)"\z/ || text =~ /\A'(.+)'\z/
        candidates << $1
        candidates << $1.to_sym if $1 =~ /\A[A-Za-z_][A-Za-z0-9_]*\z/
      else
        candidates << text.to_sym if text =~ /\A[A-Za-z_][A-Za-z0-9_]*\z/
        candidates << text.to_i if text =~ /\A-?\d+\z/
      end
      return candidates
    rescue
      return []
    end

    def phone_rematch_unique_values(values)
      seen = {}
      result = []
      values.each do |value|
        next if value.nil?
        key = phone_rematch_value_key(value)
        next if seen[key]
        seen[key] = true
        result << value
      end
      return result
    rescue
      return values.compact
    end

    def phone_rematch_primary_type_candidates(entry)
      candidates = []
      candidates << entry["trainer_type"]
      candidates.concat(phone_rematch_trainer_type_key_candidates(entry["trainer_type_key"]))
      if respond_to?(:imported_trainer_type_data)
        candidates.dup.each do |trainer_type|
          data = imported_trainer_type_data(trainer_type, entry["expansion_id"]) rescue nil
          next if !data.is_a?(Hash)
          candidates << data[:runtime_id]
          candidates << data["runtime_id"]
          candidates << data[:id]
          candidates << data["id"]
        end
      end
      return phone_rematch_unique_values(candidates)
    rescue
      return [entry["trainer_type"]].compact
    end

    def phone_rematch_contact_type_candidates(entry)
      candidates = []
      candidates << entry["contact_type"]
      candidates.concat(phone_rematch_trainer_type_key_candidates(entry["contact_type_key"]))
      return phone_rematch_unique_values(candidates)
    rescue
      return [entry["contact_type"]].compact
    end

    def phone_rematch_imported_type_asset(entry, trainer_type, key)
      return nil if !respond_to?(:imported_trainer_type_data)
      data = imported_trainer_type_data(trainer_type, entry["expansion_id"]) rescue nil
      return nil if !data.is_a?(Hash)
      raw = data[key] || data[key.to_s]
      logical = normalize_string_or_nil(raw) if respond_to?(:normalize_string_or_nil)
      logical ||= raw.to_s.strip if raw
      return nil if logical.to_s.empty?
      if respond_to?(:resolve_runtime_path_for_expansion)
        resolved = resolve_runtime_path_for_expansion(data[:expansion_id] || data["expansion_id"], logical, TRAINER_ASSET_EXTENSIONS) rescue nil
        return resolved if resolved
      end
      return logical if !defined?(pbResolveBitmap) || pbResolveBitmap(logical)
      return nil
    rescue
      return nil
    end

    def phone_rematch_game_data_type_asset(trainer_type, key)
      return nil if !defined?(GameData::TrainerType)
      data = GameData::TrainerType.try_get(trainer_type) rescue nil
      return nil if data.nil?
      filename = if key == :overworld_sprite
                   GameData::TrainerType.charset_filename(data.id) rescue nil
                 else
                   GameData::TrainerType.front_sprite_filename(data.id) rescue nil
                 end
      return filename if filename && (!defined?(pbResolveBitmap) || pbResolveBitmap(filename))
      return nil
    rescue
      return nil
    end

    def phone_rematch_icon_source_from_candidates(entry, candidates, style)
      key = (style == :front) ? :front_sprite : :overworld_sprite
      candidates.each do |trainer_type|
        filename = phone_rematch_imported_type_asset(entry, trainer_type, key)
        filename ||= phone_rematch_game_data_type_asset(trainer_type, key)
        return { :filename => filename, :style => style } if filename
      end
      return nil
    rescue
      return nil
    end

    def phone_rematch_trainer_icon_source(entry)
      return nil if !entry.is_a?(Hash)
      primary_candidates = phone_rematch_primary_type_candidates(entry)
      contact_candidates = phone_rematch_contact_type_candidates(entry)
      return phone_rematch_icon_source_from_candidates(entry, primary_candidates, :charset) ||
             phone_rematch_icon_source_from_candidates(entry, primary_candidates, :front) ||
             phone_rematch_icon_source_from_candidates(entry, contact_candidates, :charset) ||
             phone_rematch_icon_source_from_candidates(entry, contact_candidates, :front)
    rescue
      return nil
    end

    def record_phone_rematch_from_trainer_battle_start_args(args)
      return false if @phone_rematch_running || !args.is_a?(Array) || args.empty?
      if args[0].is_a?(Array)
        trainer = args[0]
        return false if trainer.length < 2
        return record_phone_rematch_trainer(trainer[0], trainer[1], trainer[2], trainer[3])
      end
      return false if args.length < 2
      trainer_type = args[0]
      trainer_name = args[1]
      version = 0
      end_speech = nil
      args[2..-1].to_a.each do |arg|
        if arg.is_a?(Integer)
          version = arg if version.to_i == 0
        elsif arg.is_a?(String)
          end_speech = arg if end_speech.nil?
        elsif arg.is_a?(Hash)
          version = integer(arg[:version] || arg["version"], version) if arg.has_key?(:version) || arg.has_key?("version")
          end_speech = arg[:end_speech] || arg["end_speech"] || end_speech if arg.has_key?(:end_speech) || arg.has_key?("end_speech")
        end
      end
      return record_phone_rematch_trainer(trainer_type, trainer_name, version, end_speech)
    rescue => e
      log("[phone_rematch] TrainerBattle.start record failed: #{e.class}: #{e.message}") if respond_to?(:log)
      return false
    end

    def self_switch_data_for_phone_rematches
      return {} if !defined?($game_self_switches) || !$game_self_switches
      return $game_self_switches.instance_variable_get(:@data) || {}
    rescue
      return {}
    end

    def defeated_trainer_self_switch_keys
      data = self_switch_data_for_phone_rematches
      keys = []
      data.each do |key, value|
        next if !value || !key.is_a?(Array) || key.length < 3
        map_id = integer(key[0], 0)
        event_id = integer(key[1], 0)
        switch_name = key[2].to_s
        next if switch_name.empty?
        keys << [map_id, event_id, switch_name] if map_id > 0 && event_id > 0
      end
      return keys.uniq.sort
    rescue
      return []
    end

    def phone_rematch_backfill_signature(keys)
      checksum = 0
      keys.each do |key|
        map_id = integer(key[0], 0)
        event_id = integer(key[1], 0)
        switch_value = key[2].to_s.bytes.inject(0) { |sum, byte| (sum + byte) & 0x3fffffff }
        checksum = ((checksum * 131) + (map_id * 31) + event_id + switch_value) & 0x3fffffff
      end
      return "v#{PHONE_REMATCH_BACKFILL_VERSION}:#{keys.length}:#{checksum}"
    end

    def backfill_phone_rematches_from_self_switches!
      return 0 if !$PokemonGlobal
      keys = defeated_trainer_self_switch_keys
      signature = phone_rematch_backfill_signature(keys)
      return 0 if $PokemonGlobal.tef_phone_rematch_backfill_signature.to_s == signature
      count = 0
      event_keys = keys.map { |key| [integer(key[0], 0), integer(key[1], 0)] }.uniq.sort
      event_keys.each do |map_id, event_id|
        count += backfill_phone_rematches_from_event(map_id, event_id)
      end
      $PokemonGlobal.tef_phone_rematch_backfill_signature = signature
      log("[phone_rematch] retroactive scan registered #{count} defeated trainer contact(s)") if count > 0 && respond_to?(:log)
      return count
    rescue => e
      log("[phone_rematch] retroactive scan failed: #{e.class}: #{e.message}") if respond_to?(:log)
      return 0
    end

    def backfill_phone_rematches_from_event(map_id, event_id)
      map = load_map_for_phone_rematch_backfill(map_id)
      event = map && map.respond_to?(:events) ? map.events[event_id] : nil
      return 0 if !event
      expansion_id = current_map_expansion_id(map_id) if respond_to?(:current_map_expansion_id)
      expansion_id = expansion_id.to_s
      entries = trainer_battle_records_from_event(event)
      count = 0
      entries.each do |record|
        next if !record || record.length < 3
        count += 1 if record_phone_rematch_trainer(
          record[0], record[1], record[2], record[3],
          :expansion_id => expansion_id,
          :map_id => map_id,
          :event_id => event_id
        )
      end
      return count
    rescue => e
      log("[phone_rematch] retroactive event scan failed map=#{map_id} event=#{event_id}: #{e.class}: #{e.message}") if respond_to?(:log)
      return 0
    end

    def load_map_for_phone_rematch_backfill(map_id)
      return load_map_data(map_id) if respond_to?(:load_map_data)
      return load_data(sprintf("Data/Map%03d.rxdata", map_id))
    rescue
      return nil
    end

    def phone_rematch_event_record_for_context(trainer_name, trainer_type = nil, trainer_version = 0, options = {})
      map_id = integer(options[:map_id], ($game_map && $game_map.respond_to?(:map_id)) ? $game_map.map_id : 0)
      event_id = if options.key?(:event_id)
                   integer(options[:event_id], 0)
                 elsif pbMapInterpreterRunning?
                   event = pbMapInterpreter.get_character(0) rescue nil
                   event.respond_to?(:id) ? event.id : 0
                 else
                   0
                 end
      return nil if map_id <= 0 || event_id <= 0
      map = load_map_for_phone_rematch_backfill(map_id)
      event = map && map.respond_to?(:events) ? map.events[event_id] : nil
      return nil if !event
      name = trainer_name.to_s
      type_key = phone_rematch_value_key(trainer_type)
      version = integer(trainer_version, 0)
      records = trainer_battle_records_from_event(event)
      candidates = records.find_all { |record| record && record[1].to_s == name }
      return nil if candidates.empty?
      exact = candidates.find do |record|
        phone_rematch_value_key(record[0]) == type_key && integer(record[2], 0) == version
      end
      return exact if exact
      same_type = candidates.find { |record| phone_rematch_value_key(record[0]) == type_key }
      return same_type if same_type
      same_version = candidates.find { |record| integer(record[2], 0) == version }
      return same_version if same_version && candidates.length == 1
      return candidates.first if candidates.length == 1
      return nil
    rescue => e
      log("[phone_rematch] event source repair failed: #{e.class}: #{e.message}") if respond_to?(:log)
      return nil
    end

    def trainer_battle_records_from_event(event)
      scripts = event_script_blocks_for_phone_rematch(event)
      records = []
      scripts.each do |script|
        records.concat(trainer_battle_records_from_script(script))
      end
      unique = {}
      records.each do |record|
        key = [phone_rematch_value_key(record[0]), record[1].to_s, integer(record[2], 0)].join("|")
        unique[key] ||= record
      end
      return unique.values
    rescue
      return []
    end

    def event_script_blocks_for_phone_rematch(event)
      blocks = []
      Array(event.pages).each do |page|
        list = page.respond_to?(:list) ? Array(page.list) : []
        index = 0
        while index < list.length
          command = list[index]
          if command && command.respond_to?(:code) && command.code == 355
            lines = [command.parameters[0].to_s]
            index += 1
            while index < list.length && list[index] && list[index].respond_to?(:code) && list[index].code == 655
              lines << list[index].parameters[0].to_s
              index += 1
            end
            blocks << lines.join("\n")
          elsif command && command.respond_to?(:code) && command.code == 111 &&
                command.parameters.is_a?(Array) && command.parameters[0] == 12
            blocks << command.parameters[1].to_s
            index += 1
          else
            index += 1
          end
        end
      end
      return blocks
    rescue
      return []
    end

    def trainer_battle_records_from_script(script)
      records = []
      extract_phone_rematch_calls(script, "pbTrainerBattle").each do |args_text|
        args = split_phone_rematch_args(args_text)
        next if args.length < 2
        trainer_type = parse_phone_rematch_token(args[0])
        trainer_name = parse_phone_rematch_token(args[1])
        party_id = parse_phone_rematch_token(args[4])
        end_speech = parse_phone_rematch_token(args[2])
        next if trainer_type.nil? || trainer_name.to_s.empty?
        records << [trainer_type, trainer_name.to_s, integer(party_id, 0), end_speech]
      end
      extract_phone_rematch_calls(script, "pbDoubleTrainerBattle").each do |args_text|
        args = split_phone_rematch_args(args_text)
        [[0, 1, 2, 3], [4, 5, 6, 7]].each do |offsets|
          trainer_type = parse_phone_rematch_token(args[offsets[0]])
          trainer_name = parse_phone_rematch_token(args[offsets[1]])
          party_id = parse_phone_rematch_token(args[offsets[2]])
          end_speech = parse_phone_rematch_token(args[offsets[3]])
          next if trainer_type.nil? || trainer_name.to_s.empty?
          records << [trainer_type, trainer_name.to_s, integer(party_id, 0), end_speech]
        end
      end
      extract_phone_rematch_calls(script, "pbTripleTrainerBattle").each do |args_text|
        args = split_phone_rematch_args(args_text)
        [[0, 1, 2, 3], [4, 5, 6, 7], [8, 9, 10, 11]].each do |offsets|
          trainer_type = parse_phone_rematch_token(args[offsets[0]])
          trainer_name = parse_phone_rematch_token(args[offsets[1]])
          party_id = parse_phone_rematch_token(args[offsets[2]])
          end_speech = parse_phone_rematch_token(args[offsets[3]])
          next if trainer_type.nil? || trainer_name.to_s.empty?
          records << [trainer_type, trainer_name.to_s, integer(party_id, 0), end_speech]
        end
      end
      extract_phone_rematch_calls(script, "TrainerBattle.start").each do |args_text|
        args = split_phone_rematch_args(args_text)
        records.concat(trainer_battle_start_records_from_args(args))
      end
      return records
    rescue
      return []
    end

    def trainer_battle_start_records_from_args(args)
      records = []
      return records if !args.is_a?(Array) || args.empty?
      array_trainer = parse_phone_rematch_array_token(args[0])
      if array_trainer && array_trainer.length >= 2
        trainer_type = array_trainer[0]
        trainer_name = array_trainer[1]
        party_id = array_trainer[2]
        end_speech = array_trainer[3]
        records << [trainer_type, trainer_name.to_s, integer(party_id, 0), end_speech] if trainer_type && !trainer_name.to_s.empty?
        return records
      end
      return records if args.length < 2
      trainer_type = parse_phone_rematch_token(args[0])
      trainer_name = parse_phone_rematch_token(args[1])
      return records if trainer_type.nil? || trainer_name.to_s.empty?
      party_id = 0
      end_speech = nil
      args[2..-1].to_a.each do |arg|
        value = parse_phone_rematch_token(arg)
        if value.is_a?(Integer) && party_id == 0
          party_id = value
        elsif value.is_a?(String) && end_speech.nil?
          end_speech = value
        end
      end
      records << [trainer_type, trainer_name.to_s, integer(party_id, 0), end_speech]
      return records
    rescue
      return []
    end

    def extract_phone_rematch_calls(script, method_name)
      calls = []
      needle = "#{method_name}("
      index = 0
      while index < script.length
        found = script.index(needle, index)
        break if !found
        open_index = found + method_name.length
        close_index = closing_paren_for_phone_rematch(script, open_index)
        if close_index
          calls << script[(open_index + 1)...close_index]
          index = close_index + 1
        else
          index = found + needle.length
        end
      end
      return calls
    end

    def closing_paren_for_phone_rematch(text, open_index)
      depth = 0
      quote = nil
      escaped = false
      index = open_index
      while index < text.length
        char = text[index, 1]
        if quote
          escaped = (!escaped && char == "\\")
          if char == quote && !escaped
            quote = nil
          elsif char != "\\"
            escaped = false
          end
        else
          quote = char if char == "\"" || char == "'"
          depth += 1 if char == "("
          if char == ")"
            depth -= 1
            return index if depth == 0
          end
        end
        index += 1
      end
      return nil
    end

    def split_phone_rematch_args(args_text)
      args = []
      current = ""
      depth = 0
      quote = nil
      escaped = false
      index = 0
      while index < args_text.length
        char = args_text[index, 1]
        if quote
          current << char
          escaped = (!escaped && char == "\\")
          if char == quote && !escaped
            quote = nil
          elsif char != "\\"
            escaped = false
          end
        else
          case char
          when "\"", "'"
            quote = char
            current << char
          when "(", "[", "{"
            depth += 1
            current << char
          when ")", "]", "}"
            depth -= 1 if depth > 0
            current << char
          when ","
            if depth == 0
              args << current.strip
              current = ""
            else
              current << char
            end
          else
            current << char
          end
        end
        index += 1
      end
      args << current.strip if !current.strip.empty?
      return args
    end

    def parse_phone_rematch_array_token(token)
      text = token.to_s.strip
      return nil if !text.start_with?("[") || !text.end_with?("]")
      inner = text[1...-1]
      return split_phone_rematch_args(inner).map { |part| parse_phone_rematch_token(part) }
    rescue
      return nil
    end

    def parse_phone_rematch_token(token)
      text = token.to_s.strip
      return nil if text.empty? || text == "nil"
      if text =~ /\A(?:_I|_INTL)\((.*)\)\z/m
        inner = split_phone_rematch_args($1)[0]
        return parse_phone_rematch_token(inner)
      end
      return text.to_i if text =~ /\A-?\d+\z/
      return text[1..-1].to_sym if text =~ /\A:[A-Za-z_][A-Za-z0-9_]*\z/
      if text =~ /\A(PBTrainers|PBTrainer)::([A-Za-z_][A-Za-z0-9_]*)\z/
        mod_name = $1
        const_name = $2
        if Object.const_defined?(mod_name)
          mod = Object.const_get(mod_name)
          return mod.const_get(const_name) if mod.respond_to?(:const_defined?) && mod.const_defined?(const_name)
        end
        return const_name.to_sym
      end
      if text =~ /\A[A-Z][A-Za-z0-9_]*\z/
        return Object.const_get(text) if Object.const_defined?(text)
        return text.to_sym
      end
      if (text.start_with?("\"") && text.end_with?("\"")) || (text.start_with?("'") && text.end_with?("'"))
        return eval(text)
      end
      return nil
    rescue
      return nil
    end

    def phone_rematch_entry_for(contact_type, trainer_name)
      name = trainer_name.to_s
      contact_key = phone_rematch_value_key(contact_type)
      candidates = phone_rematch_entries.values.find_all do |entry|
        entry.is_a?(Hash) &&
          entry["trainer_name"].to_s == name &&
          entry["contact_type_key"].to_s == contact_key.to_s
      end
      candidates = phone_rematch_entries.values.find_all do |entry|
        entry.is_a?(Hash) && entry["trainer_name"].to_s == name
      end if candidates.empty?
      return candidates.max_by { |entry| integer(entry["sequence"], 0) }
    rescue
      return nil
    end

    def phone_rematch_imported_type_label(entry, trainer_type)
      return nil if !respond_to?(:imported_trainer_type_data)
      data = imported_trainer_type_data(trainer_type, entry["expansion_id"]) rescue nil
      return nil if !data.is_a?(Hash)
      label = data[:title] || data["title"] || data[:name] || data["name"] || data[:real_name] || data["real_name"]
      label = localized_external_trainer_text(data[:expansion_id] || data["expansion_id"] || entry["expansion_id"], label) if respond_to?(:localized_external_trainer_text)
      label = label.to_s.strip
      return nil if label.empty? || label =~ /\ATEF_/i
      return label
    rescue
      return nil
    end

    def phone_rematch_native_type_label(trainer_type)
      return nil if trainer_type.nil? || !defined?(GameData::TrainerType)
      data = GameData::TrainerType.try_get(trainer_type) rescue nil
      return nil if data.nil?
      label = data.name.to_s.strip rescue ""
      return nil if label.empty? || label =~ /\ATEF_/i
      return label
    rescue
      return nil
    end

    def phone_rematch_humanized_type_label(trainer_type)
      text = trainer_type.to_s
      text = text.gsub(/\A:/, "")
      text = text.gsub(/\ATEF_[A-Z0-9]+_/, "")
      text = text.gsub(/[_\-]+/, " ").strip
      return "Trainer" if text.empty?
      return text.split(/\s+/).map { |part| part[0, 1].to_s.upcase + part[1..-1].to_s.downcase }.join(" ")
    rescue
      return "Trainer"
    end

    def phone_rematch_trainer_type_label(entry)
      return "Trainer" if !entry.is_a?(Hash)
      primary_candidates = phone_rematch_primary_type_candidates(entry)
      primary_candidates.each do |trainer_type|
        label = phone_rematch_imported_type_label(entry, trainer_type)
        return label if label
      end
      primary_candidates.each do |trainer_type|
        label = phone_rematch_native_type_label(trainer_type)
        return label if label
      end
      phone_rematch_contact_type_candidates(entry).each do |trainer_type|
        next if trainer_type == entry["trainer_type"]
        label = phone_rematch_native_type_label(trainer_type)
        return label if label
      end
      return phone_rematch_humanized_type_label(entry["trainer_type"] || entry["contact_type"])
    rescue
      return "Trainer"
    end

    def phone_rematch_trainer_display_name(entry)
      type_name = phone_rematch_trainer_type_label(entry)
      name = pbGetMessageFromHash(MessageTypes::TrainerNames, entry["trainer_name"]) rescue entry["trainer_name"].to_s
      return "#{type_name} #{name}".strip
    end

    def load_phone_rematch_trainer(entry)
      return nil if !entry.is_a?(Hash)
      repair_phone_rematch_entry_source!(entry)
      expansion_id = entry["expansion_id"].to_s
      trainer_type = entry["trainer_type"]
      trainer_name = entry["trainer_name"].to_s
      trainer_version = integer(entry["trainer_version"], 0)
      trainer = nil
      if !expansion_id.empty? && respond_to?(:load_external_trainer)
        trainer = phone_rematch_external_trainer(expansion_id, trainer_type, trainer_name, trainer_version)
      end
      if trainer.nil? && expansion_id.empty?
        trainer = phone_rematch_host_trainer(trainer_type, trainer_name, trainer_version)
      end
      trainer ||= pbLoadTrainer(trainer_type, trainer_name, trainer_version) if trainer.nil? && expansion_id.empty? && defined?(pbLoadTrainer)
      return trainer
    rescue => e
      log("[phone_rematch] load failed: #{e.class}: #{e.message}") if respond_to?(:log)
      return nil
    end

    def clone_phone_rematch_trainer(trainer)
      return Marshal.load(Marshal.dump(trainer))
    rescue
      begin
        cloned = trainer.clone
        cloned.party = Array(trainer.party).map do |pkmn|
          Marshal.load(Marshal.dump(pkmn)) rescue (pkmn.clone rescue pkmn)
        end if cloned.respond_to?(:party=) && trainer.respond_to?(:party)
        return cloned
      rescue
        return trainer
      end
    end

    def phone_rematch_party_target_level
      return 1 if !$Trainer || !$Trainer.respond_to?(:party)
      levels = Array($Trainer.party).compact.find_all { |pkmn| !pkmn.respond_to?(:egg?) || !pkmn.egg? }.map { |pkmn| integer(pkmn.level, 1) }
      return [levels.max || 1, 1].max
    rescue
      return 1
    end

    def apply_phone_rematch_level_mode!(trainer, mode)
      return trainer if !trainer || !trainer.respond_to?(:party)
      target = nil
      case mode
      when :scaled
        target = phone_rematch_party_target_level
      when :level100
        target = 100
      else
        return trainer
      end
      Array(trainer.party).each do |pkmn|
        next if !pkmn || (pkmn.respond_to?(:egg?) && pkmn.egg?)
        new_level = (mode == :scaled) ? [integer(pkmn.level, 1), target].max : target
        new_level = [[new_level, 1].max, GameData::GrowthRate.max_level].min if defined?(GameData::GrowthRate)
        pkmn.level = new_level if pkmn.respond_to?(:level=)
        pkmn.calc_stats if pkmn.respond_to?(:calc_stats)
        pkmn.heal if pkmn.respond_to?(:heal)
      end
      return trainer
    rescue => e
      log("[phone_rematch] level mode #{mode} failed: #{e.class}: #{e.message}") if respond_to?(:log)
      return trainer
    end

    def phone_rematch_select_level_mode(entry)
      display_name = phone_rematch_trainer_display_name(entry)
      commands = PHONE_REMATCH_LEVEL_MODES.values + ["Cancel"]
      choice = pbMessage(_INTL("Call {1} for a rematch?", display_name), commands, commands.length)
      return nil if choice.nil? || choice < 0 || choice >= PHONE_REMATCH_LEVEL_MODES.length
      return PHONE_REMATCH_LEVEL_MODES.keys[choice]
    end

    def open_phone_rematch_prompt(entry)
      mode = phone_rematch_select_level_mode(entry)
      return false if mode.nil?
      return start_phone_rematch_battle(entry, mode)
    end

    def start_phone_rematch_battle(entry, mode = :default)
      if !$Trainer || !$Trainer.respond_to?(:able_pokemon_count) || $Trainer.able_pokemon_count <= 0
        pbMessage(_INTL("You need a healthy Pokemon before calling for a rematch."))
        return false
      end
      trainer = load_phone_rematch_trainer(entry)
      if trainer.nil?
        if entry.is_a?(Hash) && entry["native_phone"] && defined?(tef_phone_rematch_original_pbCallTrainer)
          return tef_phone_rematch_original_pbCallTrainer(entry["trainer_type"], entry["trainer_name"])
        end
        pbMessage(_INTL("That trainer could not be reached right now."))
        log("[phone_rematch] missing rematch trainer #{entry.inspect}") if respond_to?(:log)
        return false
      end
      trainer = clone_phone_rematch_trainer(trainer)
      trainer = apply_phone_rematch_level_mode!(trainer, mode)
      expansion_id = entry["expansion_id"].to_s
      previous_phone_rematch = @phone_rematch_running
      previous_battle_context = @active_imported_battle_expansion_id
      previous_menu_state = $game_temp.in_menu if defined?($game_temp) && $game_temp
      previous_waiting_trainer = $PokemonTemp.waitingTrainer if defined?($PokemonTemp) && $PokemonTemp && $PokemonTemp.respond_to?(:waitingTrainer)
      @phone_rematch_running = true
      @active_imported_battle_expansion_id = expansion_id if !expansion_id.empty?
      $game_temp.in_menu = false if defined?($game_temp) && $game_temp.respond_to?(:in_menu=)
      $PokemonTemp.waitingTrainer = nil if defined?($PokemonTemp) && $PokemonTemp && $PokemonTemp.respond_to?(:waitingTrainer=)
      begin
        Events.onTrainerPartyLoad.trigger(nil, trainer) if defined?(Events)
        party_size = trainer.respond_to?(:party) ? Array(trainer.party).length : 0
        log("[phone_rematch] starting #{phone_rematch_trainer_display_name(entry)} mode=#{mode} expansion=#{expansion_id.empty? ? "host" : expansion_id} party=#{party_size}") if respond_to?(:log)
        decision = tef_phone_rematch_run_trainer_core(trainer)
        log("[phone_rematch] decision #{decision.inspect} for #{phone_rematch_trainer_display_name(entry)}") if respond_to?(:log)
        return decision == 1 || decision == true
      ensure
        @active_imported_battle_expansion_id = previous_battle_context
        @phone_rematch_running = previous_phone_rematch
        $game_temp.in_menu = previous_menu_state if defined?($game_temp) && $game_temp.respond_to?(:in_menu=) && !previous_menu_state.nil?
        $PokemonTemp.waitingTrainer = previous_waiting_trainer if defined?($PokemonTemp) && $PokemonTemp && $PokemonTemp.respond_to?(:waitingTrainer=) && previous_waiting_trainer
      end
    rescue => e
      @phone_rematch_running = false
      log("[phone_rematch] battle failed: #{e.class}: #{e.message}") if respond_to?(:log)
      pbMessage(_INTL("The rematch could not start safely."))
      return false
    end
  end
end

if defined?(IconSprite)
  class IconSprite
    alias tef_phone_rematch_original_setBitmap setBitmap if method_defined?(:setBitmap) && !method_defined?(:tef_phone_rematch_original_setBitmap)
    def setBitmap(file, hue = 0)
      tef_phone_rematch_original_setBitmap(file, hue)
      if self.bitmap.nil? && defined?(TravelExpansionFramework) && TravelExpansionFramework.respond_to?(:phone_rematch_blank_bitmap)
        self.bitmap = TravelExpansionFramework.phone_rematch_blank_bitmap
        self.src_rect = Rect.new(0, 0, 1, 1) if defined?(Rect)
      end
    rescue => e
      clearBitmaps if respond_to?(:clearBitmaps)
      if defined?(TravelExpansionFramework) && TravelExpansionFramework.respond_to?(:phone_rematch_blank_bitmap)
        self.bitmap = TravelExpansionFramework.phone_rematch_blank_bitmap
        self.src_rect = Rect.new(0, 0, 1, 1) if defined?(Rect)
        TravelExpansionFramework.log("[phone_rematch] blanked missing phone icon #{file.inspect}: #{e.class}: #{e.message}") if TravelExpansionFramework.respond_to?(:log)
      end
    end
  end
end

def tef_phone_rematch_run_trainer_core(*args)
  return tef_phone_rematch_original_pbTrainerBattleCore(*args) if defined?(tef_phone_rematch_original_pbTrainerBattleCore)
  return pbTrainerBattleCore(*args) if defined?(pbTrainerBattleCore)
  return tef_original_pbTrainerBattleCore(*args) if defined?(tef_original_pbTrainerBattleCore)
  return 0
end

alias tef_phone_rematch_original_pbTrainerBattleCore pbTrainerBattleCore if defined?(pbTrainerBattleCore) && !defined?(tef_phone_rematch_original_pbTrainerBattleCore)
def pbTrainerBattleCore(*args)
  decision = tef_phone_rematch_original_pbTrainerBattleCore(*args)
  if decision && decision != 0 && defined?(TravelExpansionFramework)
    args.each { |arg| TravelExpansionFramework.record_phone_rematch_from_argument(arg) }
  end
  return decision
end

alias tef_phone_rematch_original_pbTrainerBattle pbTrainerBattle if defined?(pbTrainerBattle) && !defined?(tef_phone_rematch_original_pbTrainerBattle)
def pbTrainerBattle(trainerID, trainerName, endSpeech=nil,
                    doubleBattle=false, trainerPartyID=0, canLose=false, outcomeVar=1,
                    name_override=nil, trainer_type_overide=nil)
  result = tef_phone_rematch_original_pbTrainerBattle(trainerID, trainerName, endSpeech,
                                                      doubleBattle, trainerPartyID, canLose, outcomeVar,
                                                      name_override, trainer_type_overide)
  if !$PokemonTemp || !$PokemonTemp.waitingTrainer
    TravelExpansionFramework.record_phone_rematch_trainer(trainerID, trainerName, trainerPartyID, endSpeech) if defined?(TravelExpansionFramework)
  end
  return result
end

alias tef_phone_rematch_original_pbDoubleTrainerBattle pbDoubleTrainerBattle if defined?(pbDoubleTrainerBattle) && !defined?(tef_phone_rematch_original_pbDoubleTrainerBattle)
def pbDoubleTrainerBattle(trainerID1, trainerName1, trainerPartyID1, endSpeech1,
                          trainerID2, trainerName2, trainerPartyID2=0, endSpeech2=nil,
                          canLose=false, outcomeVar=1)
  result = tef_phone_rematch_original_pbDoubleTrainerBattle(trainerID1, trainerName1, trainerPartyID1, endSpeech1,
                                                            trainerID2, trainerName2, trainerPartyID2, endSpeech2,
                                                            canLose, outcomeVar)
  if defined?(TravelExpansionFramework)
    TravelExpansionFramework.record_phone_rematch_trainer(trainerID1, trainerName1, trainerPartyID1, endSpeech1)
    TravelExpansionFramework.record_phone_rematch_trainer(trainerID2, trainerName2, trainerPartyID2, endSpeech2)
  end
  return result
end

alias tef_phone_rematch_original_pbTripleTrainerBattle pbTripleTrainerBattle if defined?(pbTripleTrainerBattle) && !defined?(tef_phone_rematch_original_pbTripleTrainerBattle)
def pbTripleTrainerBattle(trainerID1, trainerName1, trainerPartyID1, endSpeech1,
                          trainerID2, trainerName2, trainerPartyID2, endSpeech2,
                          trainerID3, trainerName3, trainerPartyID3=0, endSpeech3=nil,
                          canLose=false, outcomeVar=1)
  result = tef_phone_rematch_original_pbTripleTrainerBattle(trainerID1, trainerName1, trainerPartyID1, endSpeech1,
                                                            trainerID2, trainerName2, trainerPartyID2, endSpeech2,
                                                            trainerID3, trainerName3, trainerPartyID3, endSpeech3,
                                                            canLose, outcomeVar)
  if defined?(TravelExpansionFramework)
    TravelExpansionFramework.record_phone_rematch_trainer(trainerID1, trainerName1, trainerPartyID1, endSpeech1)
    TravelExpansionFramework.record_phone_rematch_trainer(trainerID2, trainerName2, trainerPartyID2, endSpeech2)
    TravelExpansionFramework.record_phone_rematch_trainer(trainerID3, trainerName3, trainerPartyID3, endSpeech3)
  end
  return result
end

if defined?(TrainerBattle)
  class << TrainerBattle
    alias tef_phone_rematch_original_start start if method_defined?(:start) && !method_defined?(:tef_phone_rematch_original_start)
    def start(*args)
      result = tef_phone_rematch_original_start(*args)
      TravelExpansionFramework.record_phone_rematch_from_trainer_battle_start_args(args) if result && defined?(TravelExpansionFramework)
      return result
    end
  end
end

alias tef_phone_rematch_original_pbCallTrainer pbCallTrainer if defined?(pbCallTrainer) && !defined?(tef_phone_rematch_original_pbCallTrainer)
def pbCallTrainer(trtype, trname)
  if defined?(TravelExpansionFramework)
    TravelExpansionFramework.sync_phone_rematch_contacts!(false)
    entry = TravelExpansionFramework.phone_rematch_entry_for(trtype, trname)
    return TravelExpansionFramework.open_phone_rematch_prompt(entry) if entry
  end
  return tef_phone_rematch_original_pbCallTrainer(trtype, trname) if defined?(tef_phone_rematch_original_pbCallTrainer)
end

if defined?(PokemonPokegearScreen)
  class PokemonPokegearScreen
    alias tef_phone_rematch_original_pbStartScreen pbStartScreen if method_defined?(:pbStartScreen) && !method_defined?(:tef_phone_rematch_original_pbStartScreen)
    def pbStartScreen(*args)
      TravelExpansionFramework.quick_phone_rematch_pokegear_access! if defined?(TravelExpansionFramework) &&
                                                                       TravelExpansionFramework.respond_to?(:quick_phone_rematch_pokegear_access!)
      if !defined?(TravelExpansionFramework) || !TravelExpansionFramework.respond_to?(:phone_rematch_menu_available?) ||
         !TravelExpansionFramework.phone_rematch_menu_available?
        return tef_phone_rematch_original_pbStartScreen(*args)
      end
      commands = []
      cmdMap = -1
      cmdPhone = -1
      cmdRematches = -1
      cmdJukebox = -1
      cmdTutornet = -1
      commands[cmdMap = commands.length] = ["map", _INTL("Map")]
      if $PokemonGlobal.phoneNumbers && $PokemonGlobal.phoneNumbers.any? { |num| num.is_a?(Array) && num[0] }
        commands[cmdPhone = commands.length] = ["phone", _INTL("Phone")]
      end
      commands[cmdRematches = commands.length] = ["phone", _INTL("Rematches")]
      commands[cmdJukebox = commands.length] = ["jukebox", _INTL("Jukebox")]
      if defined?(PokemonTutorNet_Scene) && defined?(PokemonTutorNetScreen)
        commands[cmdTutornet = commands.length] = ["tutornet", _INTL("Tutor.net")]
      end
      @scene.pbStartScene(commands)
      loop do
        cmd = @scene.pbScene
        if cmd < 0
          break
        elsif cmdMap >= 0 && cmd == cmdMap
          pbShowMap(-1, false)
        elsif cmdPhone >= 0 && cmd == cmdPhone
          pbFadeOutIn { PokemonPhoneScene.new.start }
        elsif cmdRematches >= 0 && cmd == cmdRematches
          pbFadeOutIn { PokemonPhoneRematchScene.new.start }
        elsif cmdJukebox >= 0 && cmd == cmdJukebox
          pbFadeOutIn {
            scene = PokemonJukebox_Scene.new
            screen = PokemonJukeboxScreen.new(scene)
            screen.pbStartScreen
          }
        elsif cmdTutornet >= 0 && cmd == cmdTutornet
          pbFadeOutIn {
            scene = PokemonTutorNet_Scene.new
            screen = PokemonTutorNetScreen.new(scene)
            screen.pbStartScreen
          }
        end
      end
      @scene.pbEndScene
    end
  end
end

class PokemonPhoneRematchScene
  def start
    TravelExpansionFramework.ensure_phone_rematch_pokegear_access! if defined?(TravelExpansionFramework)
    @entries = defined?(TravelExpansionFramework) ? TravelExpansionFramework.phone_rematch_menu_entries : []
    if @entries.empty?
      pbMessage(_INTL("There are no rematches stored yet."))
      return
    end
    pending_entry = nil
    pending_mode = nil
    commands = @entries.map { |entry| TravelExpansionFramework.phone_rematch_trainer_display_name(entry) }
    @sprites = {}
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    addBackgroundPlane(@sprites, "bg", "phonebg", @viewport)
    @sprites["list"] = Window_PhoneList.newEmpty(152, 32, Graphics.width - 142, Graphics.height - 80, @viewport)
    @sprites["header"] = Window_UnformattedTextPokemon.newWithSize(_INTL("Rematches"), 2, -18, 150, 64, @viewport)
    @sprites["header"].baseColor = Color.new(248, 248, 248)
    @sprites["header"].shadowColor = Color.new(0, 0, 0)
    @sprites["bottom"] = Window_AdvancedTextPokemon.newWithSize("", 162, Graphics.height - 64, Graphics.width - 158, 64, @viewport)
    @sprites["info"] = Window_AdvancedTextPokemon.newWithSize("", -8, 224, 180, 160, @viewport)
    @sprites["icon"] = IconSprite.new(70, 102, @viewport)
    @sprites["list"].commands = commands
    @icon_cache = {}
    refresh_entry(0)
    pbFadeInAndShow(@sprites)
    pbActivateWindow(@sprites, "list") {
      oldindex = -1
      loop do
        Graphics.update
        Input.update
        pbUpdateSpriteHash(@sprites)
        if @sprites["list"].index != oldindex
          oldindex = @sprites["list"].index
          refresh_entry(oldindex)
        end
        if Input.trigger?(Input::BACK)
          pbPlayCloseMenuSE
          break
        elsif Input.trigger?(Input::USE)
          index = @sprites["list"].index
          if index >= 0 && @entries[index]
            mode = TravelExpansionFramework.phone_rematch_select_level_mode(@entries[index])
            if mode
              pending_entry = @entries[index]
              pending_mode = mode
              break
            end
            refresh_entry(index)
          end
        end
      end
    }
    pbFadeOutAndHide(@sprites)
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
    if pending_entry && pending_mode
      TravelExpansionFramework.start_phone_rematch_battle(pending_entry, pending_mode)
    end
  end

  def refresh_entry(index)
    entry = @entries[index] || {}
    @sprites["bottom"].text = "<ac>" + TravelExpansionFramework.phone_rematch_location_label(entry)
    total = @entries.length
    world = TravelExpansionFramework.phone_rematch_world_label(entry)
    source = entry["native_phone"] ? _INTL("Phone contact") : _INTL("Defeated trainer")
    @sprites["info"].text = _INTL("Stored<br><r>{1}<br>{2}<br><r>{3}", total, source, world)
    source_info = @icon_cache[entry["key"]]
    if !@icon_cache.has_key?(entry["key"])
      source_info = TravelExpansionFramework.phone_rematch_trainer_icon_source(entry)
      @icon_cache[entry["key"]] = source_info
    end
    filename = source_info.is_a?(Hash) ? source_info[:filename] : source_info
    style = source_info.is_a?(Hash) ? source_info[:style] : :charset
    if filename
      begin
        @sprites["icon"].setBitmap(filename)
        if @sprites["icon"].bitmap
          charwidth = @sprites["icon"].bitmap.width
          charheight = @sprites["icon"].bitmap.height
          @sprites["icon"].zoom_x = 1.0
          @sprites["icon"].zoom_y = 1.0
          if style == :front
            max_w = 64.0
            max_h = 64.0
            scale = [max_w / [charwidth, 1].max, max_h / [charheight, 1].max, 1.0].min
            @sprites["icon"].src_rect = Rect.new(0, 0, charwidth, charheight)
            @sprites["icon"].zoom_x = scale
            @sprites["icon"].zoom_y = scale
            @sprites["icon"].x = (84 - (charwidth * scale / 2)).to_i
            @sprites["icon"].y = (132 - (charheight * scale / 2)).to_i
          else
            @sprites["icon"].x = 86 - charwidth / 8
            @sprites["icon"].y = 134 - charheight / 8
            @sprites["icon"].src_rect = Rect.new(0, 0, charwidth / 4, charheight / 4)
          end
        end
        return
      rescue
      end
    end
    @sprites["icon"].zoom_x = 1.0 if @sprites["icon"].respond_to?(:zoom_x=)
    @sprites["icon"].zoom_y = 1.0 if @sprites["icon"].respond_to?(:zoom_y=)
    @sprites["icon"].clearBitmaps if @sprites["icon"].respond_to?(:clearBitmaps)
  end
end

if defined?(PokemonPhoneScene)
  class PokemonPhoneScene
    alias tef_phone_rematch_original_start start if method_defined?(:start) && !method_defined?(:tef_phone_rematch_original_start)
    def start(*args)
      TravelExpansionFramework.sync_phone_rematch_contacts!(false) if defined?(TravelExpansionFramework)
      return tef_phone_rematch_original_start(*args)
    end
  end
end

if defined?(PokemonPauseMenu)
  class PokemonPauseMenu
    alias tef_phone_rematch_original_pbStartPokemonMenu pbStartPokemonMenu if method_defined?(:pbStartPokemonMenu) && !method_defined?(:tef_phone_rematch_original_pbStartPokemonMenu)
    def pbStartPokemonMenu(*args)
      TravelExpansionFramework.quick_phone_rematch_pokegear_access! if defined?(TravelExpansionFramework) &&
                                                                       TravelExpansionFramework.respond_to?(:quick_phone_rematch_pokegear_access!)
      return tef_phone_rematch_original_pbStartPokemonMenu(*args)
    end
  end
end
