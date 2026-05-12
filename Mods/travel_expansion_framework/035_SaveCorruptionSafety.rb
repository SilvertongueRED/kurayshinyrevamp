module TravelExpansionFramework
  SAVE_SAFETY_BACKUP_DIRNAME = "TravelExpansionSaveBackups" unless const_defined?(:SAVE_SAFETY_BACKUP_DIRNAME)
  SAVE_SAFETY_MAX_BACKUPS    = 30 unless const_defined?(:SAVE_SAFETY_MAX_BACKUPS)

  class SaveSafetyPreviewTrainer
    attr_accessor :name
    attr_accessor :save_slot
    attr_accessor :trainer_type
    attr_accessor :id
    attr_accessor :last_time_saved
    attr_accessor :character_ID
    attr_accessor :outfit
    attr_accessor :skin_tone
    attr_accessor :clothes
    attr_accessor :hat
    attr_accessor :hat2
    attr_accessor :hair
    attr_accessor :hair_color
    attr_accessor :hat_color
    attr_accessor :hat2_color
    attr_accessor :clothes_color
    attr_accessor :new_game_plus_unlocked

    def initialize(name = "Recoverable Save")
      @name = name.to_s.empty? ? "Recoverable Save" : name.to_s
      @save_slot = nil
      @trainer_type = nil
      @id = 0
      @last_time_saved = Time.at(1)
      @character_ID = 0
      @outfit = 0
      @skin_tone = 0
      @clothes = save_safety_default_outfit
      @hat = nil
      @hat2 = nil
      @hair = save_safety_default_hair
      @hair_color = 0
      @hat_color = 0
      @hat2_color = 0
      @clothes_color = 0
      @new_game_plus_unlocked = false
    end

    def badge_count; 0; end
    def lowest_difficulty; 0; end
    def game_mode; 0; end
    def male?; false; end
    def female?; false; end
    def character_ID; 0; end
    def party; []; end
    def new_game_plus_unlocked; false; end

    def public_ID(_id = nil); 0; end
    def secret_ID(_id = nil); 0; end
    def has_pokedex; false; end
    def pokedex; nil; end

    private

    def save_safety_default_outfit
      return Settings::STARTING_OUTFIT if defined?(Settings::STARTING_OUTFIT)
      return defined?(STARTING_OUTFIT) ? STARTING_OUTFIT : "001"
    rescue
      return "001"
    end

    def save_safety_default_hair
      return "3_#{save_safety_default_outfit}"
    rescue
      return "3_001"
    end
  end

  class SaveSafetyPreviewMap
    def initialize(map_id = 0)
      @map_id = map_id.to_i rescue 0
    end

    def map_id
      return @map_id
    end
  end

  class SaveSafetyPreviewMapFactory
    def initialize(map_id = 0)
      @map = SaveSafetyPreviewMap.new(map_id)
    end

    def map
      return @map
    end
  end

  class << self
    def save_safety_log(message)
      log("[save_safety] #{message}") if respond_to?(:log)
    rescue
    end

    def save_safety_expand_path(path)
      return File.expand_path(path.to_s)
    rescue
      return path.to_s
    end

    def save_safety_backup_dir(file_path)
      base_dir = File.dirname(save_safety_expand_path(file_path))
      dir = File.join(base_dir, SAVE_SAFETY_BACKUP_DIRNAME)
      ensure_dir(dir) if respond_to?(:ensure_dir)
      Dir.mkdir(dir) if !File.directory?(dir)
      return dir
    rescue
      return File.dirname(file_path.to_s)
    end

    def save_safety_copy_file(source, target)
      return false if !source || !target || !File.file?(source)
      File.open(source, "rb") do |input|
        File.open(target, "wb") do |output|
          while (chunk = input.read(1024 * 64))
            output.write(chunk)
          end
        end
      end
      return true
    rescue => e
      save_safety_log("copy failed #{source} -> #{target}: #{e.class}: #{e.message}")
      return false
    end

    def save_safety_backup_file(file_path, reason = "manual", once = false)
      return nil if !file_path || !File.file?(file_path)
      expanded = save_safety_expand_path(file_path)
      @save_safety_backup_once ||= {}
      once_key = "#{expanded}|#{reason}"
      return @save_safety_backup_once[once_key] if once && @save_safety_backup_once[once_key]
      dir = save_safety_backup_dir(expanded)
      base = File.basename(expanded, ".*").gsub(/[^\w.-]/, "_")
      ext = File.extname(expanded)
      stamp = Time.now.strftime("%Y%m%d_%H%M%S")
      target = File.join(dir, "#{base}_#{reason}_#{stamp}#{ext}")
      suffix = 0
      while File.file?(target)
        suffix += 1
        target = File.join(dir, "#{base}_#{reason}_#{stamp}_#{suffix}#{ext}")
      end
      if save_safety_copy_file(expanded, target)
        @save_safety_backup_once[once_key] = target if once
        save_safety_prune_backups(dir, base, ext)
        save_safety_log("backup #{reason}: #{expanded} -> #{target}")
        return target
      end
      return nil
    rescue => e
      save_safety_log("backup #{reason} failed for #{file_path}: #{e.class}: #{e.message}")
      return nil
    end

    def save_safety_latest_backup(file_path)
      candidates = save_safety_backup_candidates(file_path)
      return candidates.first
    rescue => e
      save_safety_log("latest backup lookup failed for #{file_path}: #{e.class}: #{e.message}")
      return nil
    end

    def save_safety_backup_candidates(file_path)
      return [] if !file_path
      expanded = save_safety_expand_path(file_path)
      dir = save_safety_backup_dir(expanded)
      base = File.basename(expanded, ".*").gsub(/[^\w.-]/, "_")
      ext = File.extname(expanded)
      files = Dir[File.join(dir, "#{base}_*#{ext}")].select { |path| File.file?(path) }
      files.concat(save_safety_neighbor_backups(expanded))
      seen = {}
      files = files.select do |path|
        key = save_safety_expand_path(path).downcase
        next false if seen[key]
        seen[key] = true
        true
      end
      return files.sort_by { |path| File.mtime(path) rescue Time.at(0) }.reverse
    rescue => e
      save_safety_log("backup candidate lookup failed for #{file_path}: #{e.class}: #{e.message}")
      return []
    end

    def save_safety_preview_hash(file_path, reason = "recoverable")
      name = File.basename(file_path.to_s, ".rxdata")
      trainer = SaveSafetyPreviewTrainer.new("Recovery")
      trainer.save_slot = name
      save_safety_log("preview placeholder shown for #{file_path} (#{reason})")
      return {
        :player => trainer,
        :frame_count => 0,
        :map_factory => SaveSafetyPreviewMapFactory.new(42),
        :tef_recovery_preview => true,
        :tef_recovery_source => file_path.to_s
      }
    rescue => e
      save_safety_log("preview placeholder failed for #{file_path}: #{e.class}: #{e.message}")
      return {}
    end

    def save_safety_recovery_preview?(save_data)
      return save_data.is_a?(Hash) && save_data[:tef_recovery_preview] == true
    rescue
      return false
    end

    def save_safety_neighbor_backups(file_path)
      expanded = save_safety_expand_path(file_path)
      dir = File.dirname(expanded)
      ext = File.extname(expanded)
      base = File.basename(expanded, ".*")
      candidates = []
      [File.join(dir, "#{base} *#{ext}"), File.join(dir, "Backup*#{ext}")].each do |pattern|
        candidates.concat(Dir[pattern])
      end
      expanded_downcase = expanded.downcase
      return candidates.select { |path| File.file?(path) && save_safety_expand_path(path).downcase != expanded_downcase }
    rescue
      return []
    end

    def save_safety_prune_backups(dir, base, ext)
      return if !File.directory?(dir)
      pattern = File.join(dir, "#{base}_*#{ext}")
      files = Dir[pattern].sort_by { |path| File.mtime(path) rescue Time.at(0) }
      max = integer(SAVE_SAFETY_MAX_BACKUPS, 30) rescue 30
      return if max <= 0 || files.length <= max
      files[0, files.length - max].each { |path| File.delete(path) rescue nil }
    rescue
    end

    def save_safety_atomic_dump(file_path, save_data, reason = "save")
      expanded = save_safety_expand_path(file_path)
      dir = File.dirname(expanded)
      base = File.basename(expanded)
      temp = File.join(dir, ".#{base}.tef_tmp_#{Time.now.strftime("%Y%m%d%H%M%S")}_#{rand(1_000_000)}")
      File.open(temp, "wb") do |file|
        Marshal.dump(save_data, file)
        file.flush rescue nil
        file.fsync rescue nil
      end
      File.open(temp, "rb") { |file| Marshal.load(file) }
      save_safety_backup_file(expanded, reason, false) if File.file?(expanded)
      save_safety_copy_file(expanded, expanded + ".bak") if File.file?(expanded)
      File.delete(expanded) if File.file?(expanded)
      File.rename(temp, expanded)
      save_safety_log("atomic #{reason} write completed for #{expanded}")
      return true
    rescue => e
      File.delete(temp) if temp && File.file?(temp) rescue nil
      save_safety_log("atomic #{reason} write failed for #{file_path}: #{e.class}: #{e.message}")
      raise e
    end

    def save_safety_values
      return SaveData.instance_variable_get(:@values) if defined?(SaveData)
      return []
    rescue
      return []
    end

    def save_safety_value_id(value)
      return value.id if value.respond_to?(:id)
      return nil
    rescue
      return nil
    end

    def save_safety_value_optional?(value)
      return value.send(:optional?) if value.respond_to?(:optional?, true)
      return value.instance_variable_get(:@optional) == true
    rescue
      return false
    end

    def save_safety_value_modded?(value)
      return value.modded? if value.respond_to?(:modded?)
      return !value.instance_variable_get(:@vanilla_id).nil?
    rescue
      return false
    end

    def save_safety_value_vanilla_id(value)
      return value.vanilla_id if value.respond_to?(:vanilla_id)
      return value.instance_variable_get(:@vanilla_id)
    rescue
      return nil
    end

    def save_safety_value_has_new_game?(value)
      return value.has_new_game_proc? if value.respond_to?(:has_new_game_proc?)
      return !value.instance_variable_get(:@new_game_value_proc).nil?
    rescue
      return false
    end

    def save_safety_value_new_game(value)
      return value.get_new_game_value if value.respond_to?(:get_new_game_value)
      proc = value.instance_variable_get(:@new_game_value_proc)
      return proc.call if proc
      return nil
    end

    def save_safety_clone_value(value)
      return value.make_vanilla if value.respond_to?(:make_vanilla)
      return value.clone
    rescue
      return value
    end

    def save_safety_safe_resolve_modded_data(save_data)
      return save_data if !save_data.is_a?(Hash)
      save_safety_values.each do |value|
        id = save_safety_value_id(value)
        next if id.nil? || save_data.has_key?(id) || !save_safety_value_optional?(value)
        begin
          save_data[id] = save_safety_value_new_game(value)
        rescue => e
          save_safety_log("optional #{id.inspect} default skipped: #{e.class}: #{e.message}")
        end
      end
      save_safety_values.each do |value|
        id = save_safety_value_id(value)
        vanilla_id = save_safety_value_vanilla_id(value)
        next if id.nil? || vanilla_id.nil? || !save_safety_value_modded?(value)
        begin
          if save_data.has_key?(id)
            save_data[vanilla_id] = save_safety_clone_value(save_data[id])
          elsif save_data.has_key?(vanilla_id)
            begin
              save_data[id] = value.get_from_vanilla(save_data[vanilla_id])
            rescue
              save_data[id] = save_safety_clone_value(save_data[vanilla_id])
            end
          end
        rescue => e
          save_safety_log("modded #{id.inspect}/#{vanilla_id.inspect} sync skipped: #{e.class}: #{e.message}")
        end
      end
      return save_data
    end

    def save_safety_sanitize_travel_root!(save_data, context = "load")
      return save_data if !save_data.is_a?(Hash)
      root = save_data[:travel_expansion_root] || save_data["travel_expansion_root"]
      if root.nil?
        save_data[:travel_expansion_root] = save_root_to_hash(SaveRoot.new) if const_defined?(:SaveRoot) && respond_to?(:save_root_to_hash)
      elsif root.is_a?(Hash)
        root["failed_transition_log"] ||= []
        root[:failed_transition_log] ||= root["failed_transition_log"] if root.has_key?("failed_transition_log")
        root["dormant_references"] ||= []
        root["missing_expansions"] ||= []
      elsif respond_to?(:save_root_to_hash)
        save_data[:travel_expansion_root] = save_root_to_hash(root)
      else
        save_data[:travel_expansion_root] = {}
      end
      return save_data
    rescue => e
      save_safety_log("travel root sanitize failed during #{context}: #{e.class}: #{e.message}")
      save_data[:travel_expansion_root] = {} if save_data.is_a?(Hash)
      return save_data
    end

    def save_safety_runtime_proxy?(value)
      return false if value.nil?
      class_name = value.class.name.to_s
      return true if class_name == "TravelExpansionFramework::UraniumTerrainTagProxy"
      return true if class_name == "TravelExpansionFramework::EmpyreanTerrainTagProxy"
      return true if class_name == "TravelExpansionFramework::SolarEclipseTerrainTagProxy"
      return false
    rescue
      return false
    end

    def save_safety_unwrap_runtime_proxy(value)
      return value if !save_safety_runtime_proxy?(value)
      return value.source if value.respond_to?(:source)
      return value.instance_variable_get(:@source) if value.instance_variable_defined?(:@source)
      return []
    rescue
      return []
    end

    def save_safety_sanitize_map_runtime_proxies!(map, context = "load")
      return map if !map
      if map.instance_variable_defined?(:@terrain_tags)
        terrain_tags = map.instance_variable_get(:@terrain_tags)
        if save_safety_runtime_proxy?(terrain_tags)
          map.instance_variable_set(:@terrain_tags, save_safety_unwrap_runtime_proxy(terrain_tags))
          save_safety_log("unwrapped runtime terrain proxy during #{context}")
        end
      end
      return map
    rescue => e
      save_safety_log("map proxy sanitize failed during #{context}: #{e.class}: #{e.message}")
      return map
    end

    def save_safety_sanitize_map_factory_runtime_proxies!(map_factory, context = "load")
      return map_factory if !map_factory
      maps = nil
      maps = map_factory.maps if map_factory.respond_to?(:maps)
      maps = map_factory.instance_variable_get(:@maps) if maps.nil? && map_factory.instance_variable_defined?(:@maps)
      Array(maps).each { |map| save_safety_sanitize_map_runtime_proxies!(map, context) }
      return map_factory
    rescue => e
      save_safety_log("map factory proxy sanitize failed during #{context}: #{e.class}: #{e.message}")
      return map_factory
    end

    def save_safety_sanitize_hash!(save_data, context = "load")
      return save_data if !save_data.is_a?(Hash)
      save_safety_sanitize_travel_root!(save_data, context)
      save_safety_sanitize_map_factory_runtime_proxies!(save_data[:map_factory], context) if save_data.has_key?(:map_factory)
      return save_data
    rescue => e
      save_safety_log("hash sanitize failed during #{context}: #{e.class}: #{e.message}")
      return save_data
    end

    def save_safety_lenient_load_value?(value)
      id = save_safety_value_id(value)
      return true if save_safety_value_optional?(value)
      return true if save_safety_value_modded?(value)
      return true if id == :travel_expansion_root
      return true if id == :kuray_pokemon_system_file
      return false
    end

    def save_safety_value_valid?(value, save_data)
      id = save_safety_value_id(value)
      return true if id.nil?
      present = save_data.has_key?(id)
      return true if !present && (save_safety_value_optional?(value) ||
                                  save_safety_value_modded?(value) ||
                                  save_safety_value_has_new_game?(value))
      if value.respond_to?(:valid?)
        valid = value.valid?(save_data[id])
        if !valid && save_safety_lenient_load_value?(value)
          save_safety_log("lenient validity accepted for #{id.inspect}")
          return true
        end
        return valid
      end
      return true
    rescue => e
      return true if save_safety_lenient_load_value?(value)
      save_safety_log("strict validity failed for #{id.inspect}: #{e.class}: #{e.message}")
      return false
    end
  end
end

if defined?(PokemonLoadScreen)
  class PokemonLoadScreen
    alias tef_save_safety_original_title_load_save_file load_save_file unless method_defined?(:tef_save_safety_original_title_load_save_file)
    alias tef_save_safety_original_try_load_backup try_load_backup unless method_defined?(:tef_save_safety_original_try_load_backup)

    def load_save_file(file_path, preview = false)
      begin
        original = method(:tef_save_safety_original_title_load_save_file)
        save_data = if original.arity == 1
                      tef_save_safety_original_title_load_save_file(file_path)
                    else
                      tef_save_safety_original_title_load_save_file(file_path, preview)
                    end
        if preview && (!save_data.is_a?(Hash) || save_data.empty?) && File.file?(file_path)
          return TravelExpansionFramework.save_safety_preview_hash(file_path, "empty_preview") if defined?(TravelExpansionFramework)
        end
        return save_data
      rescue => e
        if preview && File.file?(file_path) && defined?(TravelExpansionFramework)
          TravelExpansionFramework.save_safety_log("title preview kept visible for #{file_path}: #{e.class}: #{e.message}")
          return TravelExpansionFramework.save_safety_preview_hash(file_path, "preview_error")
        end
        raise e
      end
    end

    def try_load_backup(file_path)
      begin
        if defined?(TravelExpansionFramework)
          candidates = []
          candidates << (file_path + ".bak") if File.file?(file_path + ".bak")
          candidates.concat(TravelExpansionFramework.save_safety_backup_candidates(file_path))
          candidates.each do |backup|
            next if !backup || !File.file?(backup)
            begin
              save_data = SaveData.read_from_file(backup)
              next unless SaveData.valid?(save_data)
              pbMessage(_INTL("The save file could not be loaded. A protected backup will be loaded instead."))
              return save_data
            rescue => backup_error
              TravelExpansionFramework.save_safety_log("backup candidate failed #{backup}: #{backup_error.class}: #{backup_error.message}")
              next
            end
          end
        end
      rescue => e
        TravelExpansionFramework.save_safety_log("load-screen backup fallback failed: #{e.class}: #{e.message}") if defined?(TravelExpansionFramework)
      end
      return tef_save_safety_original_try_load_backup(file_path)
    end
  end
end

if defined?(PokemonLoad_Scene)
  class PokemonLoad_Scene
    alias tef_save_safety_original_load_save_file load_save_file unless method_defined?(:tef_save_safety_original_load_save_file)

    def load_save_file(file_path)
      begin
        return tef_save_safety_original_load_save_file(file_path)
      rescue => e
        if defined?(TravelExpansionFramework)
          candidates = []
          candidates << (file_path + ".bak") if File.file?(file_path + ".bak")
          candidates.concat(TravelExpansionFramework.save_safety_backup_candidates(file_path))
          candidates.each do |backup|
            next if !backup || !File.file?(backup)
            begin
              save_data = SaveData.read_from_file(backup)
              next unless SaveData.valid?(save_data)
              TravelExpansionFramework.save_safety_log("legacy load scene using protected backup #{backup} after #{e.class}: #{e.message}")
              return save_data
            rescue => backup_error
              TravelExpansionFramework.save_safety_log("legacy backup candidate failed #{backup}: #{backup_error.class}: #{backup_error.message}")
              next
            end
          end
        end
        raise e
      end
    end
  end
end

if defined?(SaveData)
  module SaveData
    class << self
      alias tef_save_safety_original_read_from_file read_from_file unless method_defined?(:tef_save_safety_original_read_from_file)
      alias tef_save_safety_original_save_to_file save_to_file unless method_defined?(:tef_save_safety_original_save_to_file)
      alias tef_save_safety_original_valid valid? unless method_defined?(:tef_save_safety_original_valid)
      alias tef_save_safety_original_resolve_modded_data resolve_modded_data unless method_defined?(:tef_save_safety_original_resolve_modded_data)
      alias tef_save_safety_original_load_values load_values unless method_defined?(:tef_save_safety_original_load_values)
      alias tef_save_safety_original_peek_from_file peek_from_file if method_defined?(:peek_from_file) && !method_defined?(:tef_save_safety_original_peek_from_file)

      def tef_save_safety_candidate_paths(file_path)
        return [] if !defined?(TravelExpansionFramework)
        paths = []
        paths << (file_path + ".bak") if File.file?(file_path + ".bak")
        paths.concat(TravelExpansionFramework.save_safety_backup_candidates(file_path))
        seen = {}
        expanded_source = TravelExpansionFramework.save_safety_expand_path(file_path).downcase
        return paths.select do |path|
          next false if !path || !File.file?(path)
          key = TravelExpansionFramework.save_safety_expand_path(path).downcase
          next false if key == expanded_source || seen[key]
          seen[key] = true
          true
        end
      rescue
        return []
      end

      def tef_save_safety_read_hash_direct(file_path, run_conversion, context)
        save_data = get_data_from_file(file_path)
        save_data = to_hash_format(save_data) if save_data.is_a?(Array)
        converted = false
        if run_conversion
          begin
            converted = (!save_data.empty? && run_conversions(save_data))
          rescue => e
            TravelExpansionFramework.save_safety_log("#{context} conversion skipped for #{file_path}: #{e.class}: #{e.message}") if defined?(TravelExpansionFramework)
          end
        end
        begin
          resolve_modded_data(save_data)
        rescue => e
          TravelExpansionFramework.save_safety_log("#{context} resolve fallback for #{file_path}: #{e.class}: #{e.message}") if defined?(TravelExpansionFramework)
          TravelExpansionFramework.save_safety_safe_resolve_modded_data(save_data) if defined?(TravelExpansionFramework)
        end
        TravelExpansionFramework.save_safety_sanitize_hash!(save_data, context) if defined?(TravelExpansionFramework)
        return [save_data, converted]
      end

      def tef_save_safety_load_backup_candidate(file_path, context)
        tef_save_safety_candidate_paths(file_path).each do |backup|
          begin
            save_data, = tef_save_safety_read_hash_direct(backup, false, "#{context}_backup")
            next unless valid?(save_data)
            TravelExpansionFramework.save_safety_log("#{context} recovered #{file_path} from #{backup}") if defined?(TravelExpansionFramework)
            return save_data
          rescue => e
            TravelExpansionFramework.save_safety_log("#{context} backup candidate failed #{backup}: #{e.class}: #{e.message}") if defined?(TravelExpansionFramework)
            next
          end
        end
        return nil
      end

      def read_from_file(file_path)
        validate file_path => String
        TravelExpansionFramework.save_safety_backup_file(file_path, "preload", true) if defined?(TravelExpansionFramework)
        begin
          save_data, converted = tef_save_safety_read_hash_direct(file_path, true, "read")
        rescue => e
          recovered = tef_save_safety_load_backup_candidate(file_path, "read")
          return recovered if recovered
          raise e
        end
        if defined?(TravelExpansionFramework) && !valid?(save_data)
          recovered = tef_save_safety_load_backup_candidate(file_path, "read_invalid")
          return recovered if recovered
        end
        if converted && !save_data.empty? && defined?(TravelExpansionFramework)
          TravelExpansionFramework.save_safety_atomic_dump(file_path, save_data, "converted")
        end
        return save_data
      end

      def peek_from_file(file_path)
        validate file_path => String
        begin
          save_data, = tef_save_safety_read_hash_direct(file_path, false, "peek")
        rescue => e
          recovered = tef_save_safety_load_backup_candidate(file_path, "peek")
          return recovered if recovered
          raise e
        end
        if defined?(TravelExpansionFramework) && !valid?(save_data)
          recovered = tef_save_safety_load_backup_candidate(file_path, "peek_invalid")
          return recovered if recovered
        end
        return save_data
      end

      def save_to_file(file_path)
        validate file_path => String
        save_data = self.compile_save_hash
        if defined?(TravelExpansionFramework)
          TravelExpansionFramework.save_safety_sanitize_hash!(save_data, "save")
          TravelExpansionFramework.save_safety_atomic_dump(file_path, save_data, "save")
        else
          tef_save_safety_original_save_to_file(file_path)
        end
      end

      def valid?(save_data)
        validate save_data => Hash
        if defined?(TravelExpansionFramework)
          TravelExpansionFramework.save_safety_safe_resolve_modded_data(save_data)
          TravelExpansionFramework.save_safety_sanitize_hash!(save_data, "valid")
          values = instance_variable_get(:@values) || []
          return values.all? { |value| TravelExpansionFramework.save_safety_value_valid?(value, save_data) }
        end
        return tef_save_safety_original_valid(save_data)
      end

      def resolve_modded_data(save_data)
        if defined?(TravelExpansionFramework)
          return TravelExpansionFramework.save_safety_safe_resolve_modded_data(save_data)
        end
        return tef_save_safety_original_resolve_modded_data(save_data)
      end

      def load_values(save_data, &condition_block)
        values = instance_variable_get(:@values) || []
        values.each do |value|
          next if block_given? && !condition_block.call(value)
          id = TravelExpansionFramework.save_safety_value_id(value) if defined?(TravelExpansionFramework)
          begin
            if save_data.has_key?(value.id)
              value.load(save_data[value.id])
            elsif value.has_new_game_proc?
              value.load_new_game_value
            end
          rescue => e
            if defined?(TravelExpansionFramework) && TravelExpansionFramework.save_safety_lenient_load_value?(value)
              TravelExpansionFramework.save_safety_log("lenient load skipped #{id.inspect}: #{e.class}: #{e.message}")
              if id == :travel_expansion_root && TravelExpansionFramework.respond_to?(:load_save_root)
                TravelExpansionFramework.load_save_root(nil) rescue nil
              end
              next
            end
            raise e
          end
        end
      end
    end
  end
end
