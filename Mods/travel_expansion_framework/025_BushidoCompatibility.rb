module TravelExpansionFramework
  module_function

  def bushido_expansion_ids
    ids = []
    ids << BUSHIDO_EXPANSION_ID if const_defined?(:BUSHIDO_EXPANSION_ID)
    ids += BUSHIDO_LEGACY_EXPANSION_IDS if const_defined?(:BUSHIDO_LEGACY_EXPANSION_IDS)
    ids << "bushido"
    ids << "pokemon_bushido"
    return ids.uniq
  rescue
    return ["bushido", "pokemon_bushido"]
  end

  def bushido_active_now?(map_id = nil)
    return !active_project_expansion_id(bushido_expansion_ids, map_id).nil? if respond_to?(:active_project_expansion_id)
    marker = current_expansion_marker.to_s rescue ""
    return bushido_expansion_ids.include?(marker)
  rescue
    return false
  end

  def bushido_identifier(value)
    return value if value.is_a?(Symbol) || value.is_a?(Integer)
    text = value.to_s.strip.gsub(/\A:/, "")
    return nil if text.empty?
    return text.upcase.gsub(/[^A-Z0-9_]+/, "_").gsub(/\A_+|_+\z/, "").to_sym
  rescue
    return nil
  end

  def bushido_species(value)
    resolved = resolve_external_species(value, "bushido") if respond_to?(:resolve_external_species)
    return resolved if resolved
    identifier = bushido_identifier(value)
    data = GameData::Species.try_get(identifier) rescue nil
    return data.id if data && data.respond_to?(:id)
    return identifier
  rescue
    return bushido_identifier(value)
  end

  def bushido_item(value)
    metadata = direct_imported_item_metadata(value, false) if respond_to?(:direct_imported_item_metadata)
    runtime_symbol = imported_item_metadata_value(metadata, :runtime_symbol) if metadata && respond_to?(:imported_item_metadata_value)
    return runtime_symbol if runtime_symbol
    if value.is_a?(Integer)
      raw_name = bushido_item_raw_name_from_number(value)
      if raw_name
        bushido_expansion_ids.each do |expansion_id|
          resolved = ensure_external_item_registered(expansion_id, raw_name) if respond_to?(:ensure_external_item_registered)
          return resolved if resolved
        end
      end
    end
    identifier = bushido_identifier(value)
    resolved = ensure_external_item_registered("bushido", identifier) if identifier && respond_to?(:ensure_external_item_registered)
    return resolved if resolved
    data = GameData::Item.try_get(identifier) rescue nil
    return data.id if data && data.respond_to?(:id)
    return identifier
  rescue
    return bushido_identifier(value)
  end

  def bushido_item_raw_name_from_number(value)
    target = value.to_i
    return nil if target <= 0
    bushido_expansion_ids.each do |expansion_id|
      catalog = generic_pbs_item_catalog(expansion_id) if respond_to?(:generic_pbs_item_catalog)
      next if !catalog.is_a?(Hash) || catalog.empty?
      catalog.each_value do |entry|
        next if !entry.is_a?(Hash)
        raw = entry[:raw_name] || entry["raw_name"]
        next if raw.to_s.empty?
        native_id = integer(entry[:native_id_number] || entry["native_id_number"] || entry[:id_number] || entry["id_number"], 0) if respond_to?(:integer)
        return raw.to_s if native_id.to_i == target
        generated_id = imported_item_id_number(expansion_id, raw) if respond_to?(:imported_item_id_number)
        return raw.to_s if generated_id.to_i == target
      end
    end
    return nil
  rescue => e
    log("[bushido] numeric item lookup failed for #{value.inspect}: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def bushido_normalize_text(text)
    value = text.to_s.dup
    value = value.encode("UTF-8", invalid: :replace, undef: :replace, replace: "") if value.respond_to?(:encode)
    replacements = {
      0x2018 => "'",
      0x2019 => "'",
      0x201A => "'",
      0x201B => "'",
      0x02BC => "'",
      0xFF07 => "'",
      0x201C => "\"",
      0x201D => "\"",
      0x201E => "\"",
      0x00AB => "\"",
      0x00BB => "\"",
      0x2013 => "-",
      0x2014 => "-",
      0x2212 => "-",
      0x2026 => "...",
      0x00A0 => " "
    }
    replacements.each do |codepoint, replacement|
      value.gsub!([codepoint].pack("U"), replacement) rescue nil
    end
    value.gsub!(/\s+\n/, "\n")
    return value
  rescue
    return text.to_s
  end

  def bushido_preserve_party_noop!(source = nil)
    log("[bushido] suppressed host party reset from #{source}") if respond_to?(:log)
    $game_system.menu_disabled = false if defined?($game_system) && $game_system && $game_system.respond_to?(:menu_disabled=)
    return true
  rescue
    return true
  end

  def bushido_sanitize_event_script(script)
    return script if !bushido_active_now?
    text = script.to_s
    sanitized = text.dup
    sanitized.gsub!(/^\s*\$Trainer\.party\s*=\s*\[\]\s*$/i, "TravelExpansionFramework.bushido_preserve_party_noop!('$Trainer.party=[]')")
    sanitized.gsub!(/^\s*\$Trainer\.party\.compact!\s*$/i, "TravelExpansionFramework.bushido_preserve_party_noop!('$Trainer.party.compact!')")
    return sanitized
  rescue => e
    log("[bushido] script sanitization failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return script
  end

  def bushido_create_pokemon(species, level)
    return species if defined?(Pokemon) && species.is_a?(Pokemon)
    return Pokemon.new(species, bushido_safe_level(level)) if defined?(Pokemon)
    return nil
  rescue => e
    log("[bushido] failed to create Pokemon #{species.inspect}: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def bushido_record_owned_pokemon(pkmn, see_form = true)
    return if !$Trainer || pkmn.nil? || !$Trainer.respond_to?(:pokedex) || !$Trainer.pokedex
    $Trainer.pokedex.register(pkmn) if see_form && $Trainer.pokedex.respond_to?(:register)
    $Trainer.pokedex.set_seen(pkmn.species) if $Trainer.pokedex.respond_to?(:set_seen)
    $Trainer.pokedex.set_owned(pkmn.species) if $Trainer.pokedex.respond_to?(:set_owned)
  rescue
  end

  def bushido_give_pokemon_safely(species, level, silent = false, prefer_party = true)
    resolved = bushido_species(species)
    pkmn = bushido_create_pokemon(resolved, level)
    return false if pkmn.nil? || !$Trainer
    party = $Trainer.party if $Trainer.respond_to?(:party)
    party = [] if !party.is_a?(Array)
    party_full = $Trainer.respond_to?(:party_full?) ? $Trainer.party_full? : party.length >= 6
    if prefer_party && !party_full
      pkmn.record_first_moves if pkmn.respond_to?(:record_first_moves)
      bushido_record_owned_pokemon(pkmn)
      party << pkmn
      $Trainer.party = party if $Trainer.respond_to?(:party=)
      pbMessage(_INTL("{1} obtained {2}!\\me[Pkmn get]\\wtnp[20]", $Trainer.name, pkmn.speciesName)) if !silent && defined?(pbMessage)
      $game_system.menu_disabled = false if defined?($game_system) && $game_system && $game_system.respond_to?(:menu_disabled=)
      return true
    end

    if defined?($PokemonStorage) && $PokemonStorage && $PokemonStorage.respond_to?(:pbStoreCaught)
      pkmn.record_first_moves if pkmn.respond_to?(:record_first_moves)
      bushido_record_owned_pokemon(pkmn)
      stored_box = $PokemonStorage.pbStoreCaught(pkmn)
      if stored_box && stored_box.to_i >= 0
        if !silent && defined?(pbMessage)
          box_name = ($PokemonStorage[stored_box].name rescue "a PC Box")
          pbMessage(_INTL("{1} was sent to {2}.", pkmn.name, box_name))
        end
        $game_system.menu_disabled = false if defined?($game_system) && $game_system && $game_system.respond_to?(:menu_disabled=)
        return true
      end
    end

    pbMessage(_INTL("There is no more room for Pokemon.")) if !silent && defined?(pbMessage)
    return false
  rescue => e
    log("[bushido] safe Pokemon gift failed for #{species.inspect}: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def bushido_safe_level(level)
    value = level.to_i
    value = 1 if value <= 0
    return value
  rescue
    return 1
  end

  def bushido_call_helper(method_name, *args)
    return Kernel.send(method_name, *args) if defined?(Kernel) && Kernel.respond_to?(method_name)
    return send(method_name, *args) if respond_to?(method_name, true)
    return nil
  rescue
    return nil
  end

  def bushido_root_path
    return project_root_path(BUSHIDO_EXPANSION_ID, "Bushido", ["Pokemon Bushido"]) if respond_to?(:project_root_path) &&
                                                                                       const_defined?(:BUSHIDO_EXPANSION_ID)
    ["C:/Games/Bushido", "C:/Games/Pokemon Bushido"].each { |path| return path if File.directory?(path) }
    return nil
  rescue
    return nil
  end

  def bushido_dialogue_data_path
    root = bushido_root_path
    return nil if root.to_s.empty?
    path = File.join(root, "Data", "Scripts", "023_PluginScripts", "007_BattleScript_Data.rb")
    return path if File.file?(path)
    return nil
  rescue
    return nil
  end

  def bushido_load_dialogue_data!
    return true if @bushido_dialogue_data_loaded
    path = bushido_dialogue_data_path
    return false if path.to_s.empty?
    load(path)
    @bushido_dialogue_data_loaded = true
    log("[bushido] loaded dialogue data constants from #{path}") if respond_to?(:log)
    return true
  rescue => e
    @bushido_dialogue_data_loaded = true
    log("[bushido] dialogue data load failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def bushido_legacy_dex_capacity
    max = 2048
    max = [max, PBSpecies.maxValue.to_i + 1].max if defined?(PBSpecies) && PBSpecies.respond_to?(:maxValue)
    return max
  rescue
    return 2048
  end

  def install_bushido_legacy_player_accessors!(klass)
    return false if klass.nil?
    klass.class_eval do
      def tef_bushido_runtime_array_attr(name)
        ivar = :"@tef_bushido_#{name}"
        value = instance_variable_get(ivar)
        value = [] if !value.is_a?(Array)
        instance_variable_set(ivar, value)
        return value
      end unless method_defined?(:tef_bushido_runtime_array_attr)
    end
    [:seen, :owned, :formseen, :formlastseen, :shadowcaught].each do |name|
      klass.class_eval do
        define_method(name) do
          tef_bushido_runtime_array_attr(name)
        end unless method_defined?(name)

        define_method("#{name}=") do |value|
          ivar = :"@tef_bushido_#{name}"
          instance_variable_set(ivar, value.is_a?(Array) ? value.clone : [])
        end unless method_defined?("#{name}=")
      end
    end
    return true
  rescue => e
    log("[bushido] failed to install legacy player accessors on #{klass}: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def ensure_bushido_player_runtime_fields!(player = nil)
    install_bushido_legacy_player_accessors!(::Trainer) if defined?(::Trainer)
    install_bushido_legacy_player_accessors!(::Player) if defined?(::Player)
    player ||= (defined?($Trainer) ? $Trainer : nil)
    return false if player.nil?
    install_bushido_legacy_player_accessors!(class << player; self; end)
    return true
  rescue => e
    log("[bushido] failed to ensure player runtime fields: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def bushido_dependent_events
    return nil if !defined?($PokemonTemp) || !$PokemonTemp || !$PokemonTemp.respond_to?(:dependentEvents)
    return $PokemonTemp.dependentEvents
  rescue
    return nil
  end

  def bushido_follower_event(dependent_events = nil)
    dependent_events ||= bushido_dependent_events
    if defined?(pbGetDependency)
      event = pbGetDependency("FollowerPkmn") rescue nil
      return event if event
    end
    if dependent_events && dependent_events.respond_to?(:getEventByName)
      event = dependent_events.getEventByName("FollowerPkmn") rescue nil
      return event if event
    end
    global_events = (defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.respond_to?(:dependentEvents)) ? $PokemonGlobal.dependentEvents : []
    real_events = dependent_events.respond_to?(:realEvents) ? dependent_events.realEvents : []
    global_events.each_with_index do |data, index|
      next if !data || data[8].to_s != "FollowerPkmn"
      event = real_events[index] rescue nil
      return event if event
    end
    return real_events.find { |event| event } rescue nil
  rescue => e
    log("[bushido] follower lookup failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def bushido_following_move_route(commands = [], wait_complete = false)
    dependent_events = bushido_dependent_events
    event = bushido_follower_event(dependent_events)
    route_commands = Array(commands).compact
    return nil if route_commands.empty?
    if event && defined?(pbMoveRoute)
      route = pbMoveRoute(event, route_commands, wait_complete)
      dependent_events.refresh_sprite(false) if dependent_events && dependent_events.respond_to?(:refresh_sprite)
      return route
    end
    record_release_shim_hit("followingMoveRoute", "follower_system", "missing_follower_noop") if respond_to?(:record_release_shim_hit)
    return nil
  rescue => e
    log("[bushido] followingMoveRoute failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  class BushidoDexProxy
    include Enumerable

    def initialize(player, kind, values)
      @player = player
      @kind = kind
      @values = values.is_a?(Array) ? values : []
    end

    def [](index)
      species = species_index(index)
      if species && species >= 0 && species < @values.length
        cached = @values[species]
        return cached if cached
      end
      return pokedex_flag(species)
    rescue
      return false
    end

    def []=(index, value)
      species = species_index(index)
      if species && species >= 0
        @values[species] = value
        set_pokedex_flag(species) if value
      end
      return value
    rescue
      return value
    end

    def each
      limit = [@values.length, TravelExpansionFramework.bushido_legacy_dex_capacity].max
      i = 0
      while i < limit
        yield self[i]
        i += 1
      end
    end

    def length
      return [@values.length, TravelExpansionFramework.bushido_legacy_dex_capacity].max
    rescue
      return @values.length
    end
    alias size length

    def empty?
      return !any? { |value| value }
    rescue
      return true
    end

    def compact!
      @values.compact!
      return self
    rescue
      return self
    end

    def to_a
      array = []
      each_with_index { |value, index| array[index] = value }
      return array
    rescue
      return @values.clone
    end

    private

    def species_index(value)
      return value if value.is_a?(Integer)
      text = value.to_s
      return text.to_i if text[/\A\d+\z/]
      resolved = TravelExpansionFramework.bushido_species(value) if defined?(TravelExpansionFramework) &&
                                                                    TravelExpansionFramework.respond_to?(:bushido_species)
      return resolved if resolved.is_a?(Integer)
      return nil
    rescue
      return nil
    end

    def pokedex_flag(species)
      return false if !species || species <= 0 || !@player || !@player.respond_to?(:pokedex)
      dex = @player.pokedex
      return false if !dex
      method = (@kind == :owned) ? :owned? : :seen?
      return dex.send(method, species) if dex.respond_to?(method)
      return @player.send(method, species) if @player.respond_to?(method)
      return false
    rescue
      return false
    end

    def set_pokedex_flag(species)
      return false if !species || species <= 0 || !@player || !@player.respond_to?(:pokedex)
      dex = @player.pokedex
      return false if !dex
      method = (@kind == :owned) ? :set_owned : :set_seen
      if dex.respond_to?(method)
        begin
          dex.send(method, species, false)
        rescue ArgumentError
          dex.send(method, species)
        end
      end
      if defined?(TravelExpansionFramework) && TravelExpansionFramework.respond_to?(:record_dex_progress)
        TravelExpansionFramework.record_dex_progress(species, @kind == :owned, "bushido")
      end
      return true
    rescue
      return false
    end
  end

  def bushido_transfer_with_transition(map_id, x, y, transition = nil, direction = nil)
    return false if !$game_temp
    if $game_temp.player_transferring || $game_temp.message_window_showing || $game_temp.transition_processing
      log("[bushido] deferred pbTransferWithTransition while transfer/message/transition was active") if respond_to?(:log)
      return false
    end
    source_map_id = ($game_map.map_id rescue nil)
    expansion_id = active_project_expansion_id(bushido_expansion_ids, source_map_id) if respond_to?(:active_project_expansion_id)
    expansion_id = BUSHIDO_EXPANSION_ID if (!expansion_id || expansion_id.to_s.empty?) && const_defined?(:BUSHIDO_EXPANSION_ID)
    expansion_id = "bushido" if !expansion_id || expansion_id.to_s.empty?
    target_map_id = integer(map_id, 0)
    target_map_id = translate_expansion_map_id(expansion_id, target_map_id) if respond_to?(:translate_expansion_map_id)
    target_direction = integer(direction, 0)
    target_direction = ($game_player.direction rescue 2) if target_direction <= 0
    anchor = {
      :map_id    => target_map_id,
      :x         => integer(x, 0),
      :y         => integer(y, 0),
      :direction => target_direction
    }
    log("[bushido] pbTransferWithTransition #{map_id.inspect} -> #{anchor[:map_id]} #{anchor[:x]},#{anchor[:y]} #{transition.inspect}") if respond_to?(:log)
    if respond_to?(:safe_transfer_to_anchor)
      result = safe_transfer_to_anchor(anchor, {
        :source            => :bushido_transition_transfer,
        :expansion_id      => expansion_id,
        :allow_story_state => true,
        :immediate         => true,
        :auto_rescue       => false
      })
      return true if result
    end
    pbFadeOutIn {
      $game_temp.player_transferring = true if $game_temp.respond_to?(:player_transferring=)
      $game_temp.player_new_map_id = anchor[:map_id]
      $game_temp.player_new_x = anchor[:x]
      $game_temp.player_new_y = anchor[:y]
      $game_temp.player_new_direction = anchor[:direction]
      if defined?(pbUpdateSceneMap)
        pbUpdateSceneMap
      elsif $scene && $scene.respond_to?(:transfer_player)
        $scene.transfer_player(false)
      end
      $game_map.autoplay if $game_map && $game_map.respond_to?(:autoplay)
      $game_map.refresh if $game_map && $game_map.respond_to?(:refresh)
    }
    release_player_movement_lock if respond_to?(:release_player_movement_lock)
    return true
  rescue => e
    log("[bushido] pbTransferWithTransition failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    $game_temp.player_transferring = false if $game_temp && $game_temp.respond_to?(:player_transferring=)
    $game_temp.transition_processing = false if $game_temp && $game_temp.respond_to?(:transition_processing=)
    release_player_movement_lock if respond_to?(:release_player_movement_lock)
    return false
  end
end

if defined?(PokemonTemp)
  class PokemonTemp
    def dialogueData
      @dialogueData = { :DIAL => false } if !@dialogueData.is_a?(Hash)
      return @dialogueData
    end

    def dialogueData=(value)
      @dialogueData = value.is_a?(Hash) ? value : { :DIAL => false }
      return @dialogueData
    end

    def dialogueDone
      @dialogueDone = {} if !@dialogueDone.is_a?(Hash)
      return @dialogueDone
    end

    def dialogueDone=(value)
      @dialogueDone = value.is_a?(Hash) ? value : {}
      return @dialogueDone
    end

    def dialogueInstances
      @dialogueInstances = {} if !@dialogueInstances.is_a?(Hash)
      return @dialogueInstances
    end

    def dialogueInstances=(value)
      @dialogueInstances = value.is_a?(Hash) ? value : {}
      return @dialogueInstances
    end

    def orderData
      @orderData = {} if !@orderData.is_a?(Hash)
      return @orderData
    end

    def orderData=(value)
      @orderData = value.is_a?(Hash) ? value : {}
      return @orderData
    end
  end
end

if defined?(Trainer)
  class Trainer
    def tef_bushido_legacy_dex_values(kind)
      ivar = (kind == :owned) ? :@tef_bushido_owned : :@tef_bushido_seen
      values = instance_variable_get(ivar)
      values = [] if !values.is_a?(Array)
      instance_variable_set(ivar, values)
      return values
    end

    def tef_bushido_legacy_default_value(value)
      return value.collect { |entry| entry.is_a?(Array) ? entry.clone : entry } if value.is_a?(Array)
      return value
    rescue
      return nil
    end

    def tef_bushido_legacy_array(ivar, default_value = nil)
      values = instance_variable_get(ivar)
      values = [] if !values.is_a?(Array)
      capacity = TravelExpansionFramework.bushido_legacy_dex_capacity if defined?(TravelExpansionFramework) &&
                                                                         TravelExpansionFramework.respond_to?(:bushido_legacy_dex_capacity)
      capacity ||= 2048
      while values.length <= capacity
        values << tef_bushido_legacy_default_value(default_value)
      end
      instance_variable_set(ivar, values)
      return values
    rescue
      values ||= []
      instance_variable_set(ivar, values)
      return values
    end

    def seen
      values = tef_bushido_legacy_dex_values(:seen)
      return TravelExpansionFramework::BushidoDexProxy.new(self, :seen, values) if defined?(TravelExpansionFramework::BushidoDexProxy)
      return values
    end

    def seen=(value)
      @tef_bushido_seen = value.is_a?(Array) ? value.clone : []
      return @tef_bushido_seen
    end

    def owned
      values = tef_bushido_legacy_dex_values(:owned)
      return TravelExpansionFramework::BushidoDexProxy.new(self, :owned, values) if defined?(TravelExpansionFramework::BushidoDexProxy)
      return values
    end

    def owned=(value)
      @tef_bushido_owned = value.is_a?(Array) ? value.clone : []
      return @tef_bushido_owned
    end

    def formseen
      values = tef_bushido_legacy_array(:@tef_bushido_formseen, [[], []])
      values.each_with_index { |value, index| values[index] = [[], []] if !value.is_a?(Array) }
      return values
    end

    def formseen=(value)
      @tef_bushido_formseen = value.is_a?(Array) ? value.clone : []
      return @tef_bushido_formseen
    end

    def formlastseen
      values = tef_bushido_legacy_array(:@tef_bushido_formlastseen, [])
      values.each_with_index { |value, index| values[index] = [] if !value.is_a?(Array) }
      return values
    end

    def formlastseen=(value)
      @tef_bushido_formlastseen = value.is_a?(Array) ? value.clone : []
      return @tef_bushido_formlastseen
    end

    def shadowcaught
      return tef_bushido_legacy_array(:@tef_bushido_shadowcaught, false)
    end

    def shadowcaught=(value)
      @tef_bushido_shadowcaught = value.is_a?(Array) ? value.clone : []
      return @tef_bushido_shadowcaught
    end
  end
end

module TrainerDialogue
  def self.ensure_storage!
    return false if !$PokemonTemp
    $PokemonTemp.dialogueData[:DIAL] = false if !$PokemonTemp.dialogueData.has_key?(:DIAL)
    return true
  rescue
    return false
  end

  def self.set(param, data)
    return false if !ensure_storage!
    key = param.to_s
    $PokemonTemp.dialogueData[:DIAL] = true
    $PokemonTemp.dialogueData[key] = data
    $PokemonTemp.dialogueDone[key] = 2
    base_key = key.split(",")[0].to_s
    $PokemonTemp.dialogueInstances[base_key] = 1 if !base_key.empty?
    return true
  rescue
    return false
  end

  def self.copy(param, to_copy)
    return false if !ensure_storage!
    return set(param, $PokemonTemp.dialogueData[to_copy.to_s])
  rescue
    return false
  end

  def self.resetAll
    return false if !$PokemonTemp
    $PokemonTemp.dialogueData = { :DIAL => false }
    $PokemonTemp.dialogueDone = {}
    $PokemonTemp.dialogueInstances = {}
    $PokemonTemp.orderData = {}
    return true
  rescue
    return false
  end

  def self.hasData?
    return false if !ensure_storage!
    return $PokemonTemp.dialogueData[:DIAL] ? true : false
  rescue
    return false
  end

  def self.get(param = nil)
    return false if !hasData?
    return $PokemonTemp.dialogueData[param.to_s] if param
    return $PokemonTemp.dialogueData
  rescue
    return false
  end

  def self.setDone(param)
    return false if !ensure_storage!
    key = param.to_s
    $PokemonTemp.dialogueDone[key] = 1 if !key.include?("rand")
    return true
  rescue
    return false
  end

  def self.setFinal
    return false if !ensure_storage!
    $PokemonTemp.dialogueDone.keys.each do |key|
      next if $PokemonTemp.dialogueDone[key] != 1
      $PokemonTemp.dialogueDone[key] = 0
      $PokemonTemp.dialogueData[key] = nil
    end
    return true
  rescue
    return false
  end

  def self.eval(parameter, _no_pri = false)
    return -1 if !hasData?
    key = parameter.to_s
    return -1 if !$PokemonTemp.dialogueDone[key]
    return -1 if [0, 1].include?($PokemonTemp.dialogueDone[key])
    data = $PokemonTemp.dialogueData[key]
    return 0 if data.is_a?(String)
    return 1 if data.is_a?(Hash)
    return 2 if data.is_a?(Proc)
    return 3 if data.is_a?(Array)
    return -1
  rescue
    return -1
  end

  def self.display(parameter, battle = nil, scene = nil, no_pri = false)
    key = parameter.to_s
    if $PokemonTemp && $PokemonTemp.dialogueInstances[key].is_a?(Numeric) && $PokemonTemp.dialogueInstances[key] > 1
      key = "#{key},#{$PokemonTemp.dialogueInstances[key]}"
    end
    data = get(key)
    return false if !data
    if data.is_a?(Proc) && battle
      data.call(battle)
    elsif data.is_a?(Array)
      data.each { |line| pbMessage(_INTL(line.to_s)) if defined?(pbMessage) }
    elsif data.is_a?(Hash) && data["text"]
      Array(data["text"]).each { |line| pbMessage(_INTL(line.to_s)) if defined?(pbMessage) }
    elsif data.is_a?(String)
      pbMessage(_INTL(data)) if defined?(pbMessage)
    end
    setDone(key)
    setInstance(parameter)
    return true
  rescue => e
    TravelExpansionFramework.log("[bushido] dialogue display skipped: #{e.class}: #{e.message}") if defined?(TravelExpansionFramework) &&
                                                                                                   TravelExpansionFramework.respond_to?(:log)
    return false
  end

  def self.forceSet(parameter)
    return false if !ensure_storage!
    key = parameter.to_s
    $PokemonTemp.dialogueDone[key] = 1
    parts = key.split(",")
    $PokemonTemp.dialogueInstances[parts[0]] = parts[1].to_i + 1 if parts[0]
    return true
  rescue
    return false
  end

  def self.setInstance(parameter)
    return false if !$PokemonTemp
    key = parameter.to_s
    return true if key.include?("rand")
    no_increment = ["lowHP", "lowHPOpp", "halfHP", "halfHPOpp", "bigDamage", "bigDamageOpp",
                    "smlDamage", "smlDamageOpp", "attack", "attackOpp", "superEff", "superEffOpp",
                    "notEff", "notEffOpp"]
    $PokemonTemp.dialogueInstances[key] = 1 if !$PokemonTemp.dialogueInstances[key].is_a?(Numeric)
    $PokemonTemp.dialogueInstances[key] += 1 if !no_increment.include?(key)
    return true
  rescue
    return false
  end

  def self.changeTrainerSprite(_name, _scene, _delay = 2)
    return false
  end
end unless defined?(TrainerDialogue)

module BattleScripting
  def self.resolve_dialogue_constant(name)
    TravelExpansionFramework.bushido_load_dialogue_data! if defined?(TravelExpansionFramework) &&
                                                            TravelExpansionFramework.respond_to?(:bushido_load_dialogue_data!)
    return nil if !defined?(DialogueModule)
    key = name.is_a?(Symbol) ? name : name.to_s.gsub(/\A:/, "").to_sym
    return DialogueModule.const_get(key) if DialogueModule.const_defined?(key)
    return nil
  rescue => e
    TravelExpansionFramework.log("[bushido] dialogue constant #{name.inspect} unavailable: #{e.class}: #{e.message}") if defined?(TravelExpansionFramework) &&
                                                                                                                       TravelExpansionFramework.respond_to?(:log)
    return nil
  end

  def self.set(param, data)
    return TrainerDialogue.set(param, data) if defined?(TrainerDialogue) && TrainerDialogue.respond_to?(:set)
    return false
  end

  def self.copy(param, data)
    return TrainerDialogue.copy(param, data) if defined?(TrainerDialogue) && TrainerDialogue.respond_to?(:copy)
    return false
  end

  def self.setInScript(param, name)
    value = resolve_dialogue_constant(name)
    return false if value.nil?
    return set(param, value)
  end

  def self.ensure_order_data!
    return {} if !$PokemonTemp
    $PokemonTemp.orderData ||= {}
    return $PokemonTemp.orderData
  rescue
    return {}
  end

  def self.hasOrderData?
    return ensure_order_data!["hasOrder"] ? true : false
  end

  def self.hasAceData?
    return ensure_order_data!["hasAce"] ? true : false
  end

  def self.getAceOf(id)
    value = ensure_order_data!["ace#{id}"]
    return value if value
    return -1
  end

  def self.getOrderOf(id)
    value = ensure_order_data!["order#{id}"]
    return value if value
    return []
  end

  def self.setTrainerOrder(*args)
    data = ensure_order_data!
    fail = false
    data["hasOrder"] = true
    args.each_with_index do |entry, index|
      if !entry.is_a?(Array) || entry.length != 6 || data["ace#{2 * index + 1}"]
        fail = true
        break
      end
      data["order#{2 * index + 1}"] = entry
    end
    data["hasOrder"] = false if fail
    return !fail
  rescue
    return false
  end

  def self.setTrainerAce(*args)
    data = ensure_order_data!
    fail = false
    data["hasAce"] = true
    args.each_with_index do |entry, index|
      if !entry.is_a?(Numeric) || data["order#{2 * index + 1}"]
        fail = true
        break
      end
      data["ace#{2 * index + 1}"] = [[entry.to_i, 0].max, 6].min
    end
    data["hasAce"] = false if fail
    return !fail
  rescue
    return false
  end
end unless defined?(BattleScripting)

if defined?(Interpreter) && !Interpreter.const_defined?(:BattleScripting)
  Interpreter.const_set(:BattleScripting, ::BattleScripting)
end

if defined?(Game_Interpreter) && !Game_Interpreter.const_defined?(:BattleScripting)
  Game_Interpreter.const_set(:BattleScripting, ::BattleScripting)
end

def vRI(item, quantity = 1)
  resolved = TravelExpansionFramework.bushido_item(item)
  return pbReceiveItem(resolved, quantity.to_i) if respond_to?(:pbReceiveItem, true)
  return Kernel.pbReceiveItem(resolved, quantity.to_i) if defined?(Kernel) && Kernel.respond_to?(:pbReceiveItem)
  return false
rescue
  return false
end

def vFI(item, quantity = 1)
  resolved = TravelExpansionFramework.bushido_item(item)
  return pbItemBall(resolved, quantity.to_i) if respond_to?(:pbItemBall, true)
  return Kernel.pbItemBall(resolved, quantity.to_i) if defined?(Kernel) && Kernel.respond_to?(:pbItemBall)
  return false
rescue
  return false
end

def vDI(item, quantity = 1)
  resolved = TravelExpansionFramework.bushido_item(item)
  return $PokemonBag.pbDeleteItem(resolved, quantity.to_i) if $PokemonBag && $PokemonBag.respond_to?(:pbDeleteItem)
  return false
rescue
  return false
end

def vAI(item, quantity = 1)
  resolved = TravelExpansionFramework.bushido_item(item)
  return $PokemonBag.pbStoreItem(resolved, quantity.to_i) if $PokemonBag && $PokemonBag.respond_to?(:pbStoreItem)
  return false
rescue
  return false
end

def vIQ(item)
  resolved = TravelExpansionFramework.bushido_item(item)
  return $PokemonBag.pbQuantity(resolved) if $PokemonBag && $PokemonBag.respond_to?(:pbQuantity)
  return 0
rescue
  return 0
end

def vHI(item)
  resolved = TravelExpansionFramework.bushido_item(item)
  return $PokemonBag.pbHasItem?(resolved) if $PokemonBag && $PokemonBag.respond_to?(:pbHasItem?)
  return false
rescue
  return false
end

def vGP(species, level)
  return TravelExpansionFramework.bushido_give_pokemon_safely(species, level, false, true) if defined?(TravelExpansionFramework) &&
                                                                                            TravelExpansionFramework.respond_to?(:bushido_give_pokemon_safely)
  return false
rescue
  return false
end

def vAP(species, level)
  return TravelExpansionFramework.bushido_give_pokemon_safely(species, level, false, true) if defined?(TravelExpansionFramework) &&
                                                                                            TravelExpansionFramework.respond_to?(:bushido_give_pokemon_safely)
  return false
rescue
  return false
end

def vRP(species, level, from, nickname, gender = 0)
  resolved = TravelExpansionFramework.bushido_species(species)
  level = TravelExpansionFramework.bushido_safe_level(level)
  return pbAddForeignPokemon(resolved, level, from, nickname, gender) if respond_to?(:pbAddForeignPokemon, true)
  return pbAddPokemon(resolved, level) if respond_to?(:pbAddPokemon, true)
  return false
rescue
  return false
end

def vDP(index = 0)
  if defined?(TravelExpansionFramework) &&
     TravelExpansionFramework.respond_to?(:bushido_active_now?) &&
     TravelExpansionFramework.bushido_active_now?
    return TravelExpansionFramework.bushido_preserve_party_noop!("vDP(#{index.inspect})") if TravelExpansionFramework.respond_to?(:bushido_preserve_party_noop!)
    return true
  end
  return pbRemovePokemonAt(index.to_i) if respond_to?(:pbRemovePokemonAt, true)
  return false
rescue
  return false
end

def vGPS(species, level)
  return TravelExpansionFramework.bushido_give_pokemon_safely(species, level, true, true) if defined?(TravelExpansionFramework) &&
                                                                                          TravelExpansionFramework.respond_to?(:bushido_give_pokemon_safely)
  return false
rescue
  return false
end

def vAPS(species, level)
  return TravelExpansionFramework.bushido_give_pokemon_safely(species, level, true, true) if defined?(TravelExpansionFramework) &&
                                                                                          TravelExpansionFramework.respond_to?(:bushido_give_pokemon_safely)
  return false
rescue
  return false
end

def vHP(species)
  resolved = TravelExpansionFramework.bushido_species(species)
  return pbHasSpecies?(resolved) if respond_to?(:pbHasSpecies?, true)
  return $Trainer.has_species?(resolved) if $Trainer && $Trainer.respond_to?(:has_species?)
  return false
rescue
  return false
end

def vWB(species, level, result_variable = 0, can_escape = true, can_lose = false)
  resolved = TravelExpansionFramework.bushido_species(species)
  level = TravelExpansionFramework.bushido_safe_level(level)
  return pbWildBattle(resolved, level, result_variable.to_i, can_escape, can_lose) if respond_to?(:pbWildBattle, true)
  return Kernel.pbWildBattle(resolved, level) if defined?(Kernel) && Kernel.respond_to?(:pbWildBattle)
  return false
rescue
  return false
end

def vTB(trainer_type, trainer_name, end_speech = "...", double_battle = false, trainer_version = 0, can_lose = false, outcome_variable = 0)
  TravelExpansionFramework.ensure_bushido_player_runtime_fields! if defined?(TravelExpansionFramework) &&
                                                                 TravelExpansionFramework.respond_to?(:ensure_bushido_player_runtime_fields!)
  type = trainer_type.is_a?(Symbol) ? trainer_type : trainer_type.to_s.upcase.gsub(/[^A-Z0-9_]+/, "_").to_sym
  return pbTrainerBattle(type, trainer_name, end_speech, double_battle, trainer_version.to_i, can_lose, outcome_variable.to_i) if respond_to?(:pbTrainerBattle, true)
  return false
rescue
  return false
end

def vCry(species, volume = 80, pitch = 100)
  resolved = TravelExpansionFramework.bushido_species(species)
  return pbPlayCrySpecies(resolved, 0, volume, pitch) if respond_to?(:pbPlayCrySpecies, true)
  return pbSEPlay(pbCryFile(resolved), volume, pitch) if respond_to?(:pbCryFile, true) && respond_to?(:pbSEPlay, true)
  return true
rescue
  return true
end

def vSS(event_id, self_switch = "A")
  return pbSetSelfSwitch(event_id.to_i, self_switch.to_s, true) if respond_to?(:pbSetSelfSwitch, true)
  return false
rescue
  return false
end

def vSSF(event_id, self_switch = "A")
  return pbSetSelfSwitch(event_id.to_i, self_switch.to_s, false) if respond_to?(:pbSetSelfSwitch, true)
  return false
rescue
  return false
end

def vTSS(event_id = @event_id, self_switch = "A")
  key = [($game_map.map_id rescue 0), event_id.to_i, self_switch.to_s]
  $game_self_switches[key] = !$game_self_switches[key]
  $game_map.need_refresh = true if $game_map && $game_map.respond_to?(:need_refresh=)
  return true
rescue
  return false
end

def vTSSR(self_switch, min_event_id, max_event_id)
  min_event_id.to_i.upto(max_event_id.to_i) { |event_id| vTSS(event_id, self_switch) }
  return true
rescue
  return false
end

def vO(_outfit = 0)
  return true
end

def vG(_gender = 0)
  return true
end

def vTG
  return true
end

def vTRD(dex_index = 0)
  pbUnlockDex(dex_index.to_i) if respond_to?(:pbUnlockDex, true)
  return true
rescue
  return true
end

def vTPD
  $Trainer.pokedex = true if $Trainer && $Trainer.respond_to?(:pokedex=)
  return true
rescue
  return true
end

def vTRS
  $PokemonGlobal.runningShoes = true if $PokemonGlobal && $PokemonGlobal.respond_to?(:runningShoes=)
  return true
rescue
  return true
end

def vTPG
  $Trainer.pokegear = true if $Trainer && $Trainer.respond_to?(:pokegear=)
  return true
rescue
  return true
end

def vTGS(switch_id)
  id = switch_id.to_i
  return false if id <= 0 || !$game_switches
  $game_switches[id] = !$game_switches[id]
  $game_map.need_refresh = true if $game_map && $game_map.respond_to?(:need_refresh=)
  return true
rescue
  return false
end

if defined?(DependentEvents)
  class DependentEvents
    def setMoveRoute(commands, waitComplete = true)
      if defined?(TravelExpansionFramework) &&
         TravelExpansionFramework.respond_to?(:bushido_active_now?) &&
         TravelExpansionFramework.bushido_active_now?
        return TravelExpansionFramework.bushido_following_move_route(commands, waitComplete) if TravelExpansionFramework.respond_to?(:bushido_following_move_route)
      end
      return nil
    end unless method_defined?(:setMoveRoute)
  end
end

if defined?(followingMoveRoute) && !defined?(tef_bushido_original_followingMoveRoute)
  alias tef_bushido_original_followingMoveRoute followingMoveRoute
end

def followingMoveRoute(commands, waitComplete = false)
  if defined?(TravelExpansionFramework) &&
     TravelExpansionFramework.respond_to?(:bushido_active_now?) &&
     TravelExpansionFramework.bushido_active_now?
    route = TravelExpansionFramework.bushido_following_move_route(commands, waitComplete) if TravelExpansionFramework.respond_to?(:bushido_following_move_route)
    return route
  end
  return send(:tef_bushido_original_followingMoveRoute, commands, waitComplete) if respond_to?(:tef_bushido_original_followingMoveRoute, true)
  return FollowingMoveRoute(commands, waitComplete) if respond_to?(:FollowingMoveRoute, true)
  return nil
end

def pbTransferWithTransition(map_id, x, y, transition = nil, dir = ($game_player.direction rescue 2))
  if defined?(TravelExpansionFramework) && TravelExpansionFramework.respond_to?(:bushido_transfer_with_transition)
    return TravelExpansionFramework.bushido_transfer_with_transition(map_id, x, y, transition, dir)
  end
  return false if !$game_temp || $game_temp.player_transferring || $game_temp.message_window_showing || $game_temp.transition_processing
  pbFadeOutIn {
    $game_temp.player_transferring = true
    $game_temp.player_new_map_id = map_id.to_i
    $game_temp.player_new_x = x.to_i
    $game_temp.player_new_y = y.to_i
    $game_temp.player_new_direction = dir.to_i
    if defined?(pbUpdateSceneMap)
      pbUpdateSceneMap
    elsif $scene && $scene.respond_to?(:transfer_player)
      $scene.transfer_player(false)
    end
  }
  return true
rescue
  $game_temp.player_transferring = false if $game_temp && $game_temp.respond_to?(:player_transferring=)
  $game_temp.transition_processing = false if $game_temp && $game_temp.respond_to?(:transition_processing=)
  return false
end unless defined?(pbTransferWithTransition)

[
  [:vReceiveItem, :vRI], [:vItemReceive, :vRI], [:vGI, :vRI], [:vGetItem, :vRI], [:vItemGet, :vRI],
  [:vFindItem, :vFI], [:vItemFind, :vFI], [:vItemBall, :vFI],
  [:vDeleteItem, :vDI], [:vItemDelete, :vDI], [:vRemoveItem, :vDI], [:vItemRemove, :vDI],
  [:vAddItem, :vAI], [:vAddItemSilent, :vAI], [:vItemAdd, :vAI], [:vItemSilent, :vAI],
  [:vItemQuantity, :vIQ], [:vQuantityItem, :vIQ], [:vHasItem, :vHI],
  [:vGivePokemon, :vGP], [:vAddPokemon, :vAP], [:vReceivePokemon, :vRP],
  [:vDeletePokemon, :vDP], [:vRemovePokemon, :vDP],
  [:vGivePokemonSilent, :vGPS], [:vAddPokemonSilent, :vAPS],
  [:vHasPokemon, :vHP], [:vHS, :vHP], [:vHasSpecies, :vHP],
  [:vWildBattle, :vWB], [:vTrainerBattle, :vTB],
  [:vPlayCry, :vCry], [:vPC, :vCry],
  [:vSST, :vSS], [:vSSt, :vSS], [:vSetSelfSwitch, :vSS], [:vSetSelfSwitchTrue, :vSS],
  [:vSSf, :vSSF], [:vSetSelfSwitchFalse, :vSSF],
  [:vtSS, :vTSS], [:vToggleSelfSwitch, :vTSS],
  [:vToggleSelfSwitchRange, :vTSSR], [:vRTSS, :vTSSR], [:vRangeToggleSelfSwitch, :vTSSR],
  [:vOutfit, :vO], [:vSO, :vO], [:vSetOutfit, :vO],
  [:vGender, :vG], [:vSG, :vG], [:vSetGender, :vG],
  [:vToggleGender, :vTG],
  [:vToggleRegionDex, :vTRD],
  [:vTogglePokedex, :vTPD], [:vTogglePokeDex, :vTPD],
  [:vToggleRunningShoes, :vTRS], [:vRS, :vTRS], [:vRunningShoes, :vTRS],
  [:vTogglePokegear, :vTPG], [:vTogglePokeGear, :vTPG],
  [:vtGS, :vTGS], [:vTS, :vTGS], [:vToggleGlobalSwitch, :vTGS], [:vToggleGameSwitch, :vTGS], [:vToggleSwitch, :vTGS]
].each do |alias_name, target_name|
  next if Object.private_method_defined?(alias_name) || Object.method_defined?(alias_name)
  Object.send(:define_method, alias_name) { |*args| send(target_name, *args) }
  Object.send(:private, alias_name)
end

if defined?(Interpreter)
  class Interpreter
    alias tef_bushido_original_execute_script execute_script unless method_defined?(:tef_bushido_original_execute_script)
    alias tef_bushido_original_command_135 command_135 unless method_defined?(:tef_bushido_original_command_135) || !method_defined?(:command_135)

    def execute_script(script)
      if defined?(TravelExpansionFramework) &&
         TravelExpansionFramework.respond_to?(:ensure_bushido_player_runtime_fields!) &&
         (script.to_s.include?("$Trainer.owned") ||
          script.to_s.include?("$Trainer.seen") ||
          (TravelExpansionFramework.respond_to?(:bushido_active_now?) && TravelExpansionFramework.bushido_active_now?))
        TravelExpansionFramework.ensure_bushido_player_runtime_fields!
      end
      if defined?(TravelExpansionFramework) &&
         TravelExpansionFramework.respond_to?(:bushido_sanitize_event_script) &&
         TravelExpansionFramework.respond_to?(:bushido_active_now?) &&
         TravelExpansionFramework.bushido_active_now?
        script = TravelExpansionFramework.bushido_sanitize_event_script(script)
      end
      return tef_bushido_original_execute_script(script)
    end

    def command_135
      if defined?(TravelExpansionFramework) &&
         TravelExpansionFramework.respond_to?(:bushido_active_now?) &&
         TravelExpansionFramework.bushido_active_now? &&
         @parameters && @parameters[0].to_i == 0
        $game_system.menu_disabled = false if $game_system && $game_system.respond_to?(:menu_disabled=)
        TravelExpansionFramework.log("[bushido] suppressed menu disable during imported starter/story setup") if TravelExpansionFramework.respond_to?(:log)
        return true
      end
      return tef_bushido_original_command_135 if respond_to?(:tef_bushido_original_command_135, true)
      $game_system.menu_disabled = (@parameters[0] == 0) if $game_system
      return true
    end
  end
end

if defined?(pbMessageDisplay) && !defined?(tef_bushido_original_pbMessageDisplay)
  alias tef_bushido_original_pbMessageDisplay pbMessageDisplay
end

def pbMessageDisplay(msgwindow, message, letterbyletter = true, commandProc = nil, withSound = true)
  if defined?(TravelExpansionFramework) &&
     TravelExpansionFramework.respond_to?(:bushido_normalize_text) &&
     TravelExpansionFramework.respond_to?(:bushido_active_now?) &&
     TravelExpansionFramework.bushido_active_now?
    message = TravelExpansionFramework.bushido_normalize_text(message)
  end
  return tef_bushido_original_pbMessageDisplay(msgwindow, message, letterbyletter, commandProc, withSound) if respond_to?(:tef_bushido_original_pbMessageDisplay, true)
  return nil
end

TravelExpansionFramework.ensure_bushido_player_runtime_fields! if defined?(TravelExpansionFramework) &&
                                                                 TravelExpansionFramework.respond_to?(:ensure_bushido_player_runtime_fields!)
