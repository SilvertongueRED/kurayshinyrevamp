# Safe fallback definitions for saves that were written by removable framework
# mods. These shims must not mark the real mods as loaded.

module TravelExpansionFramework
  class SaveRoot
    attr_accessor :schema_version
    attr_accessor :framework_version
    attr_accessor :enabled_signature
    attr_accessor :expansions
    attr_accessor :missing_expansions
    attr_accessor :dormant_references
    attr_accessor :player_relocation_log
    attr_accessor :migration_history
    attr_accessor :last_host_anchor
    attr_accessor :canonical_location
    attr_accessor :last_good_host_anchor
    attr_accessor :last_good_expansion_anchors
    attr_accessor :last_completed_transition
    attr_accessor :failed_transition_log
    attr_accessor :release_manifest_version
    attr_accessor :release_last_safe_load_at
    attr_accessor :release_shim_hits
    attr_accessor :host_dex_shadow

    def initialize
      @schema_version = 0
      @framework_version = nil
      @enabled_signature = []
      @expansions = {}
      @missing_expansions = []
      @dormant_references = []
      @player_relocation_log = []
      @migration_history = []
      @last_host_anchor = nil
      @canonical_location = nil
      @last_good_host_anchor = nil
      @last_good_expansion_anchors = {}
      @last_completed_transition = nil
      @failed_transition_log = []
      @release_manifest_version = nil
      @release_last_safe_load_at = nil
      @release_shim_hits = {}
      @host_dex_shadow = { "seen" => {}, "owned" => {} }
    end
  end

  class ExpansionState
    attr_accessor :id
    attr_accessor :version
    attr_accessor :enabled
    attr_accessor :installed
    attr_accessor :last_mode
    attr_accessor :shared_world
    attr_accessor :isolated_mode
    attr_accessor :badges
    attr_accessor :quests
    attr_accessor :regional_dex
    attr_accessor :fly_destinations
    attr_accessor :dormant_references
    attr_accessor :travel_count
    attr_accessor :last_entry_at
    attr_accessor :last_anchor
    attr_accessor :last_good_anchor
    attr_accessor :metadata

    def initialize(id = nil)
      @id = id.to_s
      @version = nil
      @enabled = true
      @installed = true
      @last_mode = "shared"
      @shared_world = true
      @isolated_mode = false
      @badges = {}
      @quests = {}
      @regional_dex = { "seen" => {}, "owned" => {} }
      @fly_destinations = {}
      @dormant_references = []
      @travel_count = 0
      @last_entry_at = nil
      @last_anchor = nil
      @last_good_anchor = nil
      @metadata = {}
    end
  end

  class ExternalCommonEventRunner
    attr_accessor :expansion_id
    attr_accessor :common_event_id
    attr_accessor :interpreter

    def initialize(expansion_id = nil, common_event_id = nil)
      @expansion_id = expansion_id.to_s
      @common_event_id = common_event_id
      @interpreter = nil
    end

    def common_event; nil; end
    def trigger; 0; end
    def switch_id; 0; end
    def list; nil; end
    def refresh; @interpreter = nil; end
    def update; end

    def name
      return "Missing Expansion Common Event #{@common_event_id}"
    end
  end

  class SolarEclipseTerrainTagProxy
    attr_accessor :source

    def initialize(source = nil)
      @source = source
    end

    def [](index)
      return @source[index] if @source.respond_to?(:[])
      return nil
    rescue
      return nil
    end

    def []=(index, value)
      @source[index] = value if @source.respond_to?(:[]=)
    rescue
    end

    def method_missing(name, *args, &block)
      return @source.public_send(name, *args, &block) if @source.respond_to?(name)
      super
    end

    def respond_to_missing?(name, include_private = false)
      return true if @source.respond_to?(name, include_private)
      super
    end
  end

  class UraniumTerrainTagProxy < SolarEclipseTerrainTagProxy; end
  class EmpyreanTerrainTagProxy < SolarEclipseTerrainTagProxy; end

  class XenoverseAchievementShim
    attr_accessor :name
    attr_accessor :title
    attr_accessor :description
    attr_accessor :image
    attr_accessor :amount
    attr_accessor :progress
    attr_accessor :hidden
    attr_accessor :locked
    attr_accessor :callback
    attr_accessor :disabled

    def initialize(name = nil, *_args)
      @name = name.to_s
    end

    def each; end
    def [](key); instance_variable_get("@#{key}") rescue nil; end
    def []=(key, value); instance_variable_set("@#{key}", value) rescue value; end
  end

  class XenoverseAchievementsHash < Hash; end
end

module ModSaveFallbacks
  RESERVED_EXPANSION_MAP_START = 20_000
  FALLBACK_SPECIES = [:DITTO, :RATTATA, :BULBASAUR]

  @preserved_travel_root = nil
  @last_relocation = nil

  module_function

  def travel_framework_loaded?
    return defined?(TravelExpansionFramework::VERSION) ? true : false
  end

  def custom_species_framework_loaded?
    return defined?(CustomSpeciesFramework) ? true : false
  end

  def player_identity_bedroom_loaded?
    return true if defined?(PlayerIdentityBedroomAddon)
    return defined?($player_identity_bedroom_mod_loaded) && $player_identity_bedroom_mod_loaded
  end

  def travel_root_from(save_data)
    return nil if !save_data.is_a?(Hash)
    return save_data[:travel_expansion_root] || save_data["travel_expansion_root"]
  end

  def player_from(save_data)
    return nil if !save_data.is_a?(Hash)
    return save_data[:player] || save_data["player"]
  rescue
    return nil
  end

  def save_has_custom_species_state?(save_data)
    global = save_data[:global_metadata] || save_data["global_metadata"] rescue nil
    return true if object_value(global, :csf_framework_signature)
    each_saved_pokemon(save_data) do |pokemon, _location|
      return true if pokemon.instance_variable_defined?(:@csf_dormant_species_reference)
    end
    return false
  rescue
    return false
  end

  def save_has_player_identity_bedroom_state?(save_data)
    player = player_from(save_data)
    return false if !player
    return true if object_value(player, :player_identity_gender)
    return true if object_value(player, :player_presentation_gender)
    return true if object_value(player, :player_bedroom_map_id)
    return true if player.instance_variable_defined?(:@player_intro_hair_dye_prompted)
    return false
  rescue
    return false
  end

  def missing_frameworks_for(save_data)
    missing = []
    missing << "Travel Expansion Framework" if travel_root_from(save_data) && !travel_framework_loaded?
    if !custom_species_framework_loaded? &&
       !travel_framework_loaded? &&
       save_has_custom_species_state?(save_data)
      missing << "Custom Species Framework"
    end
    if !player_identity_bedroom_loaded? && save_has_player_identity_bedroom_state?(save_data)
      missing << "Player Identity Bedroom"
    end
    missing_map_id = missing_current_map_id(save_data)
    if missing_map_id > 0 &&
       !missing.include?("Travel Expansion Framework")
      missing << sprintf("Missing map file Data/Map%03d.rxdata", missing_map_id)
    end
    return missing
  end

  def save_has_missing_current_map?(save_data)
    return missing_current_map_id(save_data) > 0
  end

  def missing_current_map_id(save_data)
    factory = save_data[:map_factory] || save_data["map_factory"] rescue nil
    return 0 if !factory
    map_id = current_map_id_from_factory(factory)
    return map_id if map_id > 0 && !current_map_available?(map_id)
    return 0
  rescue
    return 0
  end

  def fallback_needed?(save_data)
    return !missing_frameworks_for(save_data).empty?
  end

  def species_framework_loaded?
    return true if custom_species_framework_loaded?
    return true if travel_framework_loaded?
    return false
  end

  def should_sanitize_custom_species?(save_data)
    return false if species_framework_loaded?
    return save_has_custom_species_state?(save_data)
  rescue
    return false
  end

  def after_read_save_hash!(save_data, preview = false)
    return save_data if !save_data.is_a?(Hash)
    root = travel_root_from(save_data)
    @preserved_travel_root = root if root && !preview && !travel_framework_loaded?
    sanitize_save_hash_maps!(save_data) if !preview
    sanitize_save_hash_player_position!(save_data) if !preview
    sanitize_item_storages!(save_data)
    if should_sanitize_custom_species?(save_data)
      sanitize_custom_species!(save_data, preview)
    elsif species_framework_loaded?
      restore_available_dormant_species!(save_data, preview)
    end
    return save_data
  end

  def merge_preserved_values!(save_data)
    return save_data if !save_data.is_a?(Hash)
    if @preserved_travel_root &&
       !save_data.has_key?(:travel_expansion_root) &&
       !save_data.has_key?("travel_expansion_root")
      save_data[:travel_expansion_root] = travel_root_to_hash(@preserved_travel_root)
    end
    return save_data
  end

  def sanitize_loaded_globals!
    @last_relocation = nil
    return false if !$MapFactory
    sanitize_global_dependent_event_maps!($PokemonGlobal, nil) if $PokemonGlobal
    map_id = current_map_id_from_factory($MapFactory)
    map = $MapFactory.map rescue nil
    map_id = integer(object_value(map, :map_id), map_id) if map
    return false if current_map_available?(map_id)
    anchor = best_host_anchor_from_globals
    return false if !anchor || !host_map_file_exists?(anchor[:map_id])
    $MapFactory = PokemonMapFactory.new(anchor[:map_id])
    $game_player.moveto(anchor[:x], anchor[:y]) if $game_player
    $game_player.direction = anchor[:direction] if $game_player && $game_player.respond_to?(:direction=)
    @last_relocation = {
      "from_map_id" => map_id,
      "to" => anchor,
      "reason" => missing_map_relocation_reason(map_id)
    }
    return true
  rescue
    return false
  end

  def last_relocation
    return @last_relocation
  end

  def best_host_anchor_from_globals
    root = @preserved_travel_root
    anchors = []
    anchors << canonical_host_anchor(root)
    anchors << object_value(root, :last_good_host_anchor)
    anchors << object_value(root, :last_host_anchor)
    if $PokemonGlobal
      anchors << object_value($PokemonGlobal, :tef_last_host_anchor)
      if host_map_file_exists?(object_value($PokemonGlobal, :pokecenterMapId))
        anchors << {
          :map_id => object_value($PokemonGlobal, :pokecenterMapId),
          :x => object_value($PokemonGlobal, :pokecenterX),
          :y => object_value($PokemonGlobal, :pokecenterY),
          :direction => object_value($PokemonGlobal, :pokecenterDirection)
        }
      end
    end
    if defined?($data_system) && $data_system
      anchors << {
        :map_id => $data_system.start_map_id,
        :x => $data_system.start_x,
        :y => $data_system.start_y,
        :direction => 2
      }
    end
    anchors.each do |anchor|
      safe = safe_host_anchor(anchor)
      return safe if safe
    end
    return safe_host_anchor({ :map_id => 1, :x => 0, :y => 0, :direction => 2 }) if host_map_file_exists?(1)
    return nil
  end

  def sanitize_save_hash_maps!(save_data)
    factory = save_data[:map_factory] || save_data["map_factory"]
    return save_data if !factory
    map_id = current_map_id_from_factory(factory)
    return save_data if current_map_available?(map_id)
    anchor = best_host_anchor_from_save(save_data)
    return save_data if !anchor || !host_map_file_exists?(anchor[:map_id])
    replacement = safe_map_factory(anchor[:map_id])
    if replacement
      if save_data.has_key?(:map_factory)
        save_data[:map_factory] = replacement
      else
        save_data["map_factory"] = replacement
      end
    end
    move_saved_game_player!(save_data[:game_player] || save_data["game_player"], anchor)
    sanitize_global_dependent_event_maps!(save_data[:global_metadata] || save_data["global_metadata"], anchor[:map_id])
    @last_relocation = {
      "from_map_id" => map_id,
      "to" => anchor,
      "reason" => missing_map_relocation_reason(map_id)
    }
    return save_data
  rescue
    return save_data
  end

  def safe_map_factory(map_id)
    return nil if !defined?(PokemonMapFactory)
    return PokemonMapFactory.new(map_id)
  rescue
    return nil
  end

  def best_host_anchor_from_save(save_data)
    root = travel_root_from(save_data)
    global = save_data[:global_metadata] || save_data["global_metadata"]
    anchors = []
    anchors << canonical_host_anchor(root)
    anchors << object_value(root, :last_good_host_anchor)
    anchors << object_value(root, :last_host_anchor)
    anchors << object_value(global, :tef_last_host_anchor)
    if global && host_map_file_exists?(object_value(global, :pokecenterMapId))
      anchors << {
        :map_id => object_value(global, :pokecenterMapId),
        :x => object_value(global, :pokecenterX),
        :y => object_value(global, :pokecenterY),
        :direction => object_value(global, :pokecenterDirection)
      }
    end
    if defined?($data_system) && $data_system
      anchors << {
        :map_id => $data_system.start_map_id,
        :x => $data_system.start_x,
        :y => $data_system.start_y,
        :direction => 2
      }
    end
    anchors.each do |anchor|
      safe = safe_host_anchor(anchor)
      return safe if safe
    end
    return safe_host_anchor({ :map_id => 1, :x => 0, :y => 0, :direction => 2 }) if host_map_file_exists?(1)
    return nil
  rescue
    return nil
  end

  def safe_host_anchor(anchor)
    normalized = normalize_anchor(anchor)
    return nil if !normalized || !host_map_file_exists?(normalized[:map_id])
    map = load_map_for_safety_check(normalized[:map_id])
    return normalized if !map
    return nearest_safe_anchor(normalized, map)
  rescue
    return nil
  end

  def sanitize_save_hash_player_position!(save_data)
    return save_data if !save_data.is_a?(Hash)
    global = save_data[:global_metadata] || save_data["global_metadata"]
    return save_data if preserve_current_player_position?(global)
    factory = save_data[:map_factory] || save_data["map_factory"]
    game_player = save_data[:game_player] || save_data["game_player"]
    return save_data if !factory || !game_player
    map_id = current_map_id_from_factory(factory)
    return save_data if map_id <= 0 || !current_map_available?(map_id)
    anchor = {
      :map_id => map_id,
      :x => object_value(game_player, :x),
      :y => object_value(game_player, :y),
      :direction => object_value(game_player, :direction)
    }
    safe = nearest_safe_anchor(anchor)
    return save_data if !safe || same_tile_anchor?(anchor, safe)
    move_saved_game_player!(game_player, safe)
    @last_relocation = {
      "from_map_id" => map_id,
      "to" => safe,
      "reason" => "unsafe_saved_player_tile"
    }
    return save_data
  rescue
    return save_data
  end

  def sanitize_loaded_player_position!
    return false if !$game_map || !$game_player
    return false if preserve_current_player_position?($PokemonGlobal)
    map_id = integer($game_map.map_id, 0)
    anchor = {
      :map_id => map_id,
      :x => $game_player.x,
      :y => $game_player.y,
      :direction => ($game_player.direction rescue 2)
    }
    safe = nearest_safe_anchor(anchor, $game_map)
    return false if !safe || same_tile_anchor?(anchor, safe)
    $game_player.moveto(safe[:x], safe[:y])
    $game_player.direction = safe[:direction] if $game_player.respond_to?(:direction=)
    @last_relocation = {
      "from_map_id" => map_id,
      "to" => safe,
      "reason" => "unsafe_loaded_player_tile"
    }
    return true
  rescue
    return false
  end

  def preserve_current_player_position?(global)
    return true if object_value(global, :surfing)
    return true if object_value(global, :diving)
    return true if object_value(global, :sliding)
    return true if integer(object_value(global, :bridge), 0) > 0
    return false
  rescue
    return false
  end

  def same_tile_anchor?(left, right)
    return false if !left || !right
    return integer(left[:map_id] || left["map_id"], 0) == integer(right[:map_id] || right["map_id"], 0) &&
           integer(left[:x] || left["x"], 0) == integer(right[:x] || right["x"], 0) &&
           integer(left[:y] || left["y"], 0) == integer(right[:y] || right["y"], 0)
  rescue
    return false
  end

  def nearest_safe_anchor(anchor, map = nil)
    normalized = normalize_anchor(anchor)
    return nil if !normalized || !current_map_available?(normalized[:map_id])
    check_map = map || load_map_for_safety_check(normalized[:map_id])
    return normalized if !check_map
    start_x = integer(normalized[:x], 0)
    start_y = integer(normalized[:y], 0)
    search_offsets(16).each do |offset|
      x = start_x + offset[0]
      y = start_y + offset[1]
      next if !safe_landing_tile?(check_map, x, y)
      return {
        :map_id => normalized[:map_id],
        :x => x,
        :y => y,
        :direction => normalized[:direction]
      }
    end
    return nil
  rescue
    return nil
  end

  def search_offsets(radius)
    offsets = [[0, 0]]
    (1..radius).each do |distance|
      (-distance..distance).each do |dx|
        dy = distance - dx.abs
        offsets << [dx, dy]
        offsets << [dx, -dy] if dy != 0
      end
    end
    offsets.sort_by { |offset| [offset[0].abs + offset[1].abs, offset[1] < 0 ? 1 : 0, offset[0].abs] }
  end

  def safe_landing_tile?(map, x, y)
    return false if !map || !map.respond_to?(:valid?) || !map.valid?(x, y)
    if map.respond_to?(:passableStrict?)
      return false if !map.passableStrict?(x, y, 2, nil)
    end
    return can_leave_tile?(map, x, y)
  rescue
    return false
  end

  def can_leave_tile?(map, x, y)
    [[2, 0, 1], [4, -1, 0], [6, 1, 0], [8, 0, -1]].any? do |entry|
      direction, dx, dy = entry
      next false if !map.valid?(x + dx, y + dy)
      next false if map.respond_to?(:passableStrict?) && !map.passableStrict?(x + dx, y + dy, 2, nil)
      next false if map.respond_to?(:passable?) && !map.passable?(x, y, direction, nil)
      next false if map.respond_to?(:passable?) && !map.passable?(x + dx, y + dy, 10 - direction, nil)
      true
    end
  rescue
    return false
  end

  def load_map_for_safety_check(map_id)
    id = integer(map_id, 0)
    return $game_map if defined?($game_map) && $game_map && integer($game_map.map_id, 0) == id
    return nil if !defined?(Game_Map)
    map = Game_Map.new
    map.setup(id)
    return map
  rescue
    return nil
  end

  def move_saved_game_player!(game_player, anchor)
    return if !game_player || !anchor
    if game_player.respond_to?(:moveto)
      game_player.moveto(anchor[:x], anchor[:y])
    else
      game_player.instance_variable_set(:@x, anchor[:x])
      game_player.instance_variable_set(:@y, anchor[:y])
    end
    if game_player.respond_to?(:direction=)
      game_player.direction = anchor[:direction]
    else
      game_player.instance_variable_set(:@direction, anchor[:direction])
    end
  rescue
  end

  def sanitize_global_dependent_event_maps!(global, fallback_map_id)
    return if !global
    events = object_value(global, :dependentEvents)
    return if !events.respond_to?(:delete_if)
    fallback_id = integer(fallback_map_id, 0)
    events.delete_if do |event_data|
      next false if !event_data.respond_to?(:[])
      current_map_id = integer(event_data[2], 0)
      next false if current_map_id <= 0 || current_map_available?(current_map_id)
      if fallback_id > 0 && host_map_file_exists?(fallback_id) && event_data.respond_to?(:[]=)
        event_data[2] = fallback_id
        event_data[3] = 0 if event_data.length > 3
        event_data[4] = 0 if event_data.length > 4
        next false
      end
      true
    end
  rescue
  end

  def sanitize_item_storages!(save_data)
    return save_data if !save_data.is_a?(Hash)
    [:bag, "bag", :kuray_bag, "kuray_bag"].each do |key|
      sanitize_bag!(save_data[key]) if save_data.has_key?(key)
    end
    [:global_metadata, "global_metadata", :kuray_global_metadata, "kuray_global_metadata"].each do |key|
      sanitize_global_item_data!(save_data[key]) if save_data.has_key?(key)
    end
    sanitize_game_variables_items!(save_data[:variables] || save_data["variables"])
    return save_data
  rescue
    return save_data
  end

  def sanitize_runtime_items!
    sanitize_bag!($PokemonBag) if defined?($PokemonBag) && $PokemonBag
    sanitize_global_item_data!($PokemonGlobal) if defined?($PokemonGlobal) && $PokemonGlobal
    sanitize_game_variables_items!($game_variables) if defined?($game_variables) && $game_variables
    return true
  rescue
    return false
  end

  def sanitize_global_item_data!(global)
    return if !global
    sanitize_pc_item_storage!(object_value(global, :pcItemStorage))
    sanitize_pocket_arrays!(object_value(global, :pokemonSelectionOriginalBag), global, "pokemon_selection_original_bag")
    mailbox = object_value(global, :mailbox)
    if mailbox.respond_to?(:each_with_index)
      mailbox.each_with_index do |mail, index|
        item = object_value(mail, :item)
        next if item.nil? || item_reference_valid?(item)
        quarantine_missing_item!(global, "mailbox", index, item, 1)
        mailbox[index] = nil if mailbox.respond_to?(:[]=)
      end
      mailbox.compact! if mailbox.respond_to?(:compact!)
    end
  rescue
  end

  def sanitize_game_variables_items!(variables)
    return if !variables
    data = variables.instance_variable_get(:@data) if variables.instance_variable_defined?(:@data)
    return if !data.respond_to?(:each)
    data.each do |value|
      sanitize_bag!(value) if defined?(PokemonBag) && value.is_a?(PokemonBag)
      sanitize_pc_item_storage!(value) if defined?(PCItemStorage) && value.is_a?(PCItemStorage)
    end
  rescue
  end

  def sanitize_bag!(bag)
    return if !bag
    restore_quarantined_bag_items!(bag)
    pockets = bag.instance_variable_get(:@pockets) if bag.instance_variable_defined?(:@pockets)
    return if !pockets.is_a?(Array)
    num_pockets = safe_num_bag_pockets(pockets)
    new_pockets = Array.new(num_pockets + 1) { [] }
    pockets.each_with_index do |pocket, pocket_index|
      next if !pocket.respond_to?(:each)
      pocket.each do |slot|
        item_id, qty = item_slot_values(slot)
        item_data = safe_item_data(item_id)
        qty = integer(qty, 1)
        if item_data && qty > 0
          target_pocket = valid_bag_pocket(item_data.pocket, num_pockets)
          new_pockets[target_pocket] << [item_data.id, qty]
        else
          quarantine_missing_item!(bag, "bag", pocket_index, item_id, qty)
        end
      end
    end
    bag.instance_variable_set(:@pockets, new_pockets)
    sanitize_bag_registered_items!(bag)
    sanitize_bag_choices!(bag, num_pockets)
  rescue
  end

  def sanitize_pc_item_storage!(storage)
    return if !storage
    restore_quarantined_pc_items!(storage)
    items = storage.instance_variable_get(:@items) if storage.instance_variable_defined?(:@items)
    return if !items.respond_to?(:each_with_index)
    items.each_with_index do |slot, index|
      item_id, qty = item_slot_values(slot)
      item_data = safe_item_data(item_id)
      qty = integer(qty, 1)
      if item_data && qty > 0 && slot.respond_to?(:[]=)
        slot[0] = item_data.id
        slot[1] = qty
      else
        quarantine_missing_item!(storage, "pc_item_storage", index, item_id, qty)
        items[index] = nil if items.respond_to?(:[]=)
      end
    end
    items.compact! if items.respond_to?(:compact!)
  rescue
  end

  def sanitize_pocket_arrays!(pockets, owner, container)
    return if !pockets.is_a?(Array)
    pockets.each_with_index do |pocket, pocket_index|
      next if !pocket.respond_to?(:each_with_index)
      pocket.each_with_index do |slot, slot_index|
        item_id, qty = item_slot_values(slot)
        item_data = safe_item_data(item_id)
        if item_data && integer(qty, 1) > 0 && slot.respond_to?(:[]=)
          slot[0] = item_data.id
          slot[1] = integer(qty, 1)
        else
          quarantine_missing_item!(owner, container, "#{pocket_index}:#{slot_index}", item_id, qty)
          pocket[slot_index] = nil if pocket.respond_to?(:[]=)
        end
      end
      pocket.compact! if pocket.respond_to?(:compact!)
    end
  rescue
  end

  def sanitize_bag_registered_items!(bag)
    registered = bag.instance_variable_get(:@registeredItems) if bag.instance_variable_defined?(:@registeredItems)
    registered = [] if !registered.is_a?(Array)
    registered.map! do |item_id|
      item_data = safe_item_data(item_id)
      item_data ? item_data.id : nil
    end
    registered.compact!
    bag.instance_variable_set(:@registeredItems, registered)
  rescue
  end

  def sanitize_bag_choices!(bag, num_pockets)
    choices = bag.instance_variable_get(:@choices) if bag.instance_variable_defined?(:@choices)
    choices = [] if !choices.is_a?(Array)
    (0..num_pockets).each { |i| choices[i] = integer(choices[i], 0) }
    choices.slice!(num_pockets + 1, choices.length) if choices.length > num_pockets + 1
    bag.instance_variable_set(:@choices, choices)
    lastpocket = valid_bag_pocket(bag.instance_variable_get(:@lastpocket), num_pockets) rescue 1
    bag.instance_variable_set(:@lastpocket, lastpocket)
  rescue
  end

  def restore_quarantined_bag_items!(bag)
    restore_quarantined_items!(bag) do |item_data, qty, _record|
      pockets = bag.instance_variable_get(:@pockets) if bag.instance_variable_defined?(:@pockets)
      next false if !pockets.is_a?(Array)
      num_pockets = safe_num_bag_pockets(pockets)
      pocket = valid_bag_pocket(item_data.pocket, num_pockets)
      pockets[pocket] ||= []
      pockets[pocket] << [item_data.id, qty]
      true
    end
  rescue
  end

  def restore_quarantined_pc_items!(storage)
    restore_quarantined_items!(storage) do |item_data, qty, _record|
      items = storage.instance_variable_get(:@items) if storage.instance_variable_defined?(:@items)
      next false if !items.respond_to?(:push)
      items.push([item_data.id, qty])
      true
    end
  rescue
  end

  def restore_quarantined_items!(owner)
    records = owner.instance_variable_get(:@mod_fallback_removed_items) if owner.instance_variable_defined?(:@mod_fallback_removed_items)
    return if !records.is_a?(Array) || records.empty?
    remaining = []
    records.each do |record|
      item_id = record["item_id"] || record[:item_id] || record["item"] || record[:item]
      qty = integer(record["qty"] || record[:qty], 1)
      item_data = safe_item_data(item_id)
      restored = item_data && qty > 0 && yield(item_data, qty, record)
      remaining << record if !restored
    end
    owner.instance_variable_set(:@mod_fallback_removed_items, remaining)
  rescue
  end

  def quarantine_missing_item!(owner, container, location, item_id, qty)
    return if !owner || item_id.nil? || item_id == 0
    records = owner.instance_variable_get(:@mod_fallback_removed_items) if owner.instance_variable_defined?(:@mod_fallback_removed_items)
    records = [] if !records.is_a?(Array)
    existing = records.find do |record|
      (record["container"] || record[:container]).to_s == container.to_s &&
        (record["location"] || record[:location]).to_s == location.to_s &&
        (record["item_id"] || record[:item_id] || record["item"] || record[:item]) == item_id
    end
    if existing
      existing["qty"] = integer(existing["qty"] || existing[:qty], 0) + [integer(qty, 1), 1].max
    else
      records << {
        "container" => container.to_s,
        "location" => location.to_s,
        "item_id" => item_id,
        "qty" => [integer(qty, 1), 1].max
      }
    end
    owner.instance_variable_set(:@mod_fallback_removed_items, records)
  rescue
  end

  def item_slot_values(slot)
    return [nil, 0] if !slot.respond_to?(:[])
    [slot[0], slot[1]]
  rescue
    [nil, 0]
  end

  def safe_item_data(item)
    return nil if item.nil? || item == 0
    return GameData::Item.try_get(item) if defined?(GameData::Item)
    return nil
  rescue
    return nil
  end

  def safe_num_bag_pockets(pockets)
    return PokemonBag.numPockets if defined?(PokemonBag)
    return [pockets.length - 1, 1].max
  rescue
    return [pockets.length - 1, 1].max
  end

  def valid_bag_pocket(value, num_pockets)
    pocket = integer(value, 1)
    return 1 if pocket <= 0 || pocket > num_pockets
    return pocket
  end

  def current_map_id_from_factory(factory)
    return 0 if !factory
    maps = object_value(factory, :maps)
    map_index = integer(object_value(factory, :mapIndex), 0)
    map = maps[map_index] if maps.respond_to?(:[])
    map ||= maps[0] if maps.respond_to?(:[])
    return integer(object_value(map, :map_id), 0) if map
    return 0
  rescue
    return 0
  end

  def current_map_available?(map_id)
    id = integer(map_id, 0)
    return false if id <= 0
    return true if map_file_exists?(id)
    return false if id >= RESERVED_EXPANSION_MAP_START && !travel_framework_loaded?
    return true if travel_framework_map_available?(id)
    return false
  end

  def travel_framework_map_available?(map_id)
    return false if !travel_framework_loaded?
    framework = TravelExpansionFramework
    id = integer(map_id, 0)
    return framework.valid_map_id?(id) if framework.respond_to?(:valid_map_id?)
    return framework.expansion_map_active?(id) if framework.respond_to?(:expansion_map_active?)
    if framework.respond_to?(:expansion_map_entry)
      return !framework.expansion_map_entry(id).nil?
    end
    return false
  rescue
    return false
  end

  def missing_map_relocation_reason(map_id)
    id = integer(map_id, 0)
    return "missing_travel_expansion_framework" if id >= RESERVED_EXPANSION_MAP_START && !travel_framework_loaded?
    return "missing_removable_mod_map"
  end

  def canonical_host_anchor(root)
    record = object_value(root, :canonical_location)
    return nil if !record.is_a?(Hash)
    kind = (record["kind"] || record[:kind]).to_s
    return nil if kind != "host"
    return record["anchor"] || record[:anchor]
  rescue
    return nil
  end

  def sanitize_custom_species!(save_data, preview)
    placeholder = fallback_species_id
    return save_data if !placeholder
    each_saved_pokemon(save_data) do |pokemon, location|
      sanitize_pokemon_species!(pokemon, location, placeholder, preview)
      sanitize_pokemon_held_item!(pokemon, location)
    end
    return save_data
  end

  def restore_available_dormant_species!(save_data, preview)
    each_saved_pokemon(save_data) do |pokemon, _location|
      restore_pokemon_species_if_available!(pokemon, preview)
    end
    return save_data
  rescue
    return save_data
  end

  def sanitize_pokemon_species!(pokemon, location, placeholder, preview)
    restore_pokemon_species_if_available!(pokemon, preview)
    species = pokemon.instance_variable_get(:@species) rescue nil
    return if species.nil? || species_reference_valid?(species)
    if !pokemon.instance_variable_defined?(:@csf_dormant_species_reference)
      pokemon.instance_variable_set(:@csf_dormant_species_reference, pokemon_snapshot(pokemon, location, species))
    end
    pokemon.instance_variable_set(:@species, placeholder)
    species_data = safe_species_data(placeholder)
    pokemon.instance_variable_set(:@species_data, species_data) if species_data
    pokemon.instance_variable_set(:@form, 0) if preview
    pokemon.calc_stats if !preview && pokemon.respond_to?(:calc_stats)
  rescue
  end

  def restore_pokemon_species_if_available!(pokemon, preview)
    return false if !pokemon.instance_variable_defined?(:@csf_dormant_species_reference)
    reference = pokemon.instance_variable_get(:@csf_dormant_species_reference)
    original_species = reference["species"] if reference.is_a?(Hash)
    original_species ||= reference[:species] if reference.is_a?(Hash)
    return false if original_species.nil?
    species_data = safe_species_data(original_species)
    return false if !species_data
    restored_species = species_data.respond_to?(:species) ? species_data.species : original_species
    pokemon.instance_variable_set(:@species, restored_species)
    pokemon.instance_variable_set(:@species_data, species_data)
    pokemon.instance_variable_set(:@form, species_data.form) if species_data.respond_to?(:form)
    pokemon.remove_instance_variable(:@csf_dormant_species_reference) if pokemon.instance_variable_defined?(:@csf_dormant_species_reference)
    pokemon.calc_stats if !preview && pokemon.respond_to?(:calc_stats)
    return true
  rescue
    return false
  end

  def sanitize_pokemon_held_item!(pokemon, location)
    item = pokemon.instance_variable_get(:@item) rescue nil
    return if item.nil? || item_reference_valid?(item)
    if !pokemon.instance_variable_defined?(:@csf_dormant_item_reference)
      species = pokemon.instance_variable_get(:@species) rescue nil
      pokemon.instance_variable_set(:@csf_dormant_item_reference, {
        "type" => "held_item",
        "location" => location.to_s,
        "item" => item.to_s,
        "snapshot" => pokemon_snapshot(pokemon, location, species)
      })
    end
    pokemon.instance_variable_set(:@item, nil)
  rescue
  end

  def each_saved_pokemon(save_data)
    player = save_data[:player] || save_data["player"] rescue nil
    party = []
    if player
      party = player.instance_variable_get(:@party) if player.instance_variable_defined?(:@party)
      party = player.party if (!party || party.empty?) && player.respond_to?(:party)
    end
    Array(party).each_with_index do |pokemon, index|
      yield pokemon, "party:#{index}" if pokemon
    end
    storage = save_data[:storage_system] || save_data["storage_system"] rescue nil
    boxes = []
    if storage
      boxes = storage.instance_variable_get(:@boxes) if storage.instance_variable_defined?(:@boxes)
      boxes = storage.boxes if (!boxes || boxes.empty?) && storage.respond_to?(:boxes)
    end
    Array(boxes).each_with_index do |box, box_index|
      pokemon_list = []
      if box
        pokemon_list = box.instance_variable_get(:@pokemon) if box.instance_variable_defined?(:@pokemon)
        pokemon_list = box.pokemon if (!pokemon_list || pokemon_list.empty?) && box.respond_to?(:pokemon)
      end
      Array(pokemon_list).each_with_index do |pokemon, slot_index|
        yield pokemon, "box:#{box_index}:#{slot_index}" if pokemon
      end
    end
  rescue
  end

  def pokemon_snapshot(pokemon, location, species)
    {
      "location" => location.to_s,
      "species" => species.to_s,
      "form" => (pokemon.instance_variable_get(:@form) rescue nil),
      "forced_form" => (pokemon.instance_variable_get(:@forced_form) rescue nil),
      "level" => (pokemon.instance_variable_get(:@level) rescue nil),
      "item" => (pokemon.instance_variable_get(:@item) rescue nil).to_s
    }
  rescue
    { "location" => location.to_s, "species" => species.to_s }
  end

  def fallback_species_id
    FALLBACK_SPECIES.each { |species| return species if species_reference_valid?(species) }
    return nil
  end

  def species_reference_valid?(species)
    return !safe_species_data(species).nil?
  rescue
    return false
  end

  def safe_species_data(species)
    return nil if species.nil?
    return nil if !defined?(GameData::Species)
    return GameData::Species.try_get(species) if GameData::Species.respond_to?(:try_get)
    return nil if !GameData::Species::DATA.has_key?(species) && !GameData::Species::DATA.has_key?(species.to_s.to_sym)
    return GameData::Species::DATA[species] || GameData::Species::DATA[species.to_s.to_sym]
  rescue
    return nil
  end

  def item_reference_valid?(item)
    return false if item.nil?
    return GameData::Item.exists?(item) if defined?(GameData::Item)
    return true
  rescue
    return false
  end

  def host_map_file_exists?(map_id)
    id = integer(map_id, 0)
    return false if id <= 0 || id >= RESERVED_EXPANSION_MAP_START
    return map_file_exists?(id)
  rescue
    return false
  end

  def map_file_exists?(map_id)
    id = integer(map_id, 0)
    return false if id <= 0
    path = sprintf("Data/Map%03d.rxdata", id)
    return pbRgssExists?(path) if defined?(pbRgssExists?)
    return File.file?(path)
  rescue
    return false
  end

  def normalize_anchor(anchor)
    return nil if anchor.nil?
    if anchor.is_a?(Array)
      return {
        :map_id => integer(anchor[0], 0),
        :x => integer(anchor[1], 0),
        :y => integer(anchor[2], 0),
        :direction => valid_direction(integer(anchor[3], 2))
      }
    end
    return nil if !anchor.is_a?(Hash)
    {
      :map_id => integer(anchor["map_id"] || anchor[:map_id], 0),
      :x => integer(anchor["x"] || anchor[:x], 0),
      :y => integer(anchor["y"] || anchor[:y], 0),
      :direction => valid_direction(integer(anchor["direction"] || anchor[:direction], 2))
    }
  rescue
    return nil
  end

  def valid_direction(value)
    return [2, 4, 6, 8].include?(value) ? value : 2
  end

  def object_value(object, name)
    return nil if object.nil?
    return object[name.to_s] if object.is_a?(Hash) && object.has_key?(name.to_s)
    return object[name] if object.is_a?(Hash) && object.has_key?(name)
    return object.send(name) if object.respond_to?(name)
    return object.instance_variable_get("@#{name}") if object.instance_variable_defined?("@#{name}")
    return nil
  rescue
    return nil
  end

  def integer(value, fallback = 0)
    return value if value.is_a?(Integer)
    return fallback if value.nil?
    return Integer(value)
  rescue
    return fallback
  end

  def travel_root_to_hash(root)
    return root if root.is_a?(Hash)
    fields = [
      :schema_version, :framework_version, :enabled_signature, :missing_expansions,
      :dormant_references, :player_relocation_log, :migration_history,
      :last_host_anchor, :canonical_location, :last_good_host_anchor,
      :last_good_expansion_anchors, :last_completed_transition,
      :failed_transition_log, :release_manifest_version, :release_last_safe_load_at,
      :release_shim_hits, :host_dex_shadow
    ]
    hash = {}
    fields.each { |field| hash[field.to_s] = object_value(root, field) }
    expansions = object_value(root, :expansions)
    if expansions.is_a?(Hash)
      hash["expansions"] = {}
      expansions.each do |id, state|
        hash["expansions"][id.to_s] = expansion_state_to_hash(state)
      end
    else
      hash["expansions"] = {}
    end
    return hash
  rescue
    return {}
  end

  def expansion_state_to_hash(state)
    return state if state.is_a?(Hash)
    fields = [
      :id, :version, :enabled, :installed, :last_mode, :shared_world,
      :isolated_mode, :badges, :quests, :regional_dex, :fly_destinations,
      :dormant_references, :travel_count, :last_entry_at, :last_anchor,
      :last_good_anchor, :metadata
    ]
    hash = {}
    fields.each { |field| hash[field.to_s] = object_value(state, field) }
    return hash
  rescue
    return {}
  end
end

module SaveData
  class << self
    alias mod_fallback_original_read_from_file read_from_file unless method_defined?(:mod_fallback_original_read_from_file)
    alias mod_fallback_original_peek_from_file peek_from_file if method_defined?(:peek_from_file) &&
                                                                 !method_defined?(:mod_fallback_original_peek_from_file)
    alias mod_fallback_original_compile_save_hash compile_save_hash unless method_defined?(:mod_fallback_original_compile_save_hash)

    def read_from_file(file_path)
      save_data = mod_fallback_original_read_from_file(file_path)
      ModSaveFallbacks.after_read_save_hash!(save_data, false) if defined?(ModSaveFallbacks)
      return save_data
    end

    if method_defined?(:mod_fallback_original_peek_from_file)
      def peek_from_file(file_path)
        save_data = mod_fallback_original_peek_from_file(file_path)
        ModSaveFallbacks.after_read_save_hash!(save_data, true) if defined?(ModSaveFallbacks)
        return save_data
      end
    end

    def compile_save_hash
      save_data = mod_fallback_original_compile_save_hash
      ModSaveFallbacks.merge_preserved_values!(save_data) if defined?(ModSaveFallbacks)
      return save_data
    end
  end
end

if defined?(PokemonLoadScreen)
  class PokemonLoadScreen
    alias mod_fallback_original_confirm_selected_save_load confirm_selected_save_load unless method_defined?(:mod_fallback_original_confirm_selected_save_load)

    def confirm_selected_save_load
      return true if !@selected_file
      if defined?(ModSaveFallbacks) && @save_data && !@save_data.empty?
        file_path = SaveData.get_full_path(@selected_file)
        missing_content = ModSaveFallbacks.missing_frameworks_for(@save_data)
        if !missing_content.empty?
          @confirmed_mod_fallback_saves ||= {}
          confirmation_key = [file_path, missing_content.join(",")].join("|")
          if !@confirmed_mod_fallback_saves[confirmation_key]
            confirmed = pbConfirmMessageSerious(_INTL("This save references content that is not available in the current install:\n{1}\n\nThe game can try to load it safely by disabling missing content and moving you to a safe host location if needed.\nContinue?", missing_content.join(", ")))
            return false if !confirmed
            @confirmed_mod_fallback_saves[confirmation_key] = true
            @save_data = load_selected_save_data
            return false if @save_data.empty?
          end
        end
      end
      return mod_fallback_original_confirm_selected_save_load
    end
  end
end

if defined?(PokemonBag_Scene)
  class PokemonBag_Scene
    alias mod_fallback_original_pbStartScene pbStartScene unless method_defined?(:mod_fallback_original_pbStartScene)

    def pbStartScene(bag, choosing = false, filterproc = nil, resetpocket = true)
      ModSaveFallbacks.sanitize_bag!(bag) if defined?(ModSaveFallbacks)
      return mod_fallback_original_pbStartScene(bag, choosing, filterproc, resetpocket)
    end
  end
end

if defined?(Game)
  module Game
    class << self
      alias mod_fallback_original_load load unless method_defined?(:mod_fallback_original_load)

      def load(save_data)
        ModSaveFallbacks.after_read_save_hash!(save_data, false) if defined?(ModSaveFallbacks)
        result = mod_fallback_original_load(save_data)
        if defined?(ModSaveFallbacks)
          ModSaveFallbacks.sanitize_runtime_items!
          ModSaveFallbacks.sanitize_loaded_globals!
          ModSaveFallbacks.sanitize_loaded_player_position!
        end
        return result
      end
    end
  end
end
