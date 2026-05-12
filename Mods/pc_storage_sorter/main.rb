module PCStorageSorter
  FIRST_SORTED_BOX = 1
  UNKNOWN_DEX = 999_999

  def self.prepare_box_commands!(commands)
    return nil if !commands || commands.empty?

    labels = commands.map { |cmd| cmd.to_s }
    if labels.include?("Sort") && labels.include?("Sort (all Boxes)")
      commands.map! do |cmd|
        case cmd.to_s
        when "Sort"
          _INTL("Sort Box")
        when "Sort (all Boxes)"
          _INTL("Sort All Boxes")
        else
          cmd
        end
      end
      return nil
    end

    return nil if labels.include?("Sort Box") || labels.include?("Sort All Boxes")
    return nil if !labels.include?("Jump") || !labels.include?("Wallpaper")
    return nil if !labels.include?("Name")
    return nil if !labels.include?("Cancel")

    cancel_index = labels.index("Cancel")
    commands.insert(cancel_index, _INTL("Sort All Boxes"))
    commands.insert(cancel_index, _INTL("Sort Box"))
    return { :box => cancel_index, :all => cancel_index + 1 }
  end

  def self.level_for(pokemon)
    return pokemon.level.to_i if pokemon && pokemon.respond_to?(:level)
    return 0
  end

  def self.dex_number_for(pokemon)
    return UNKNOWN_DEX if !pokemon
    if pokemon.respond_to?(:dexNum)
      value = pokemon.dexNum rescue nil
      return value.to_i if value && value.to_i > 0
    end
    species = pokemon.respond_to?(:species) ? pokemon.species : nil
    if species && defined?(GameData::Species)
      species_data = GameData::Species.get(species) rescue nil
      if species_data && species_data.respond_to?(:id_number)
        value = species_data.id_number
        return value.to_i if value && value.to_i > 0
      end
    end
    return UNKNOWN_DEX
  end

  def self.name_for(pokemon)
    return "" if !pokemon
    if pokemon.respond_to?(:speciesName)
      return pokemon.speciesName.to_s.downcase
    elsif pokemon.respond_to?(:name)
      return pokemon.name.to_s.downcase
    end
    return ""
  end

  def self.sort_entries(entries, mode)
    entries.sort_by do |entry|
      pokemon = entry[0]
      original_order = entry[3]
      case mode
      when :level
        [-level_for(pokemon), dex_number_for(pokemon), name_for(pokemon), original_order]
      when :dex
        [dex_number_for(pokemon), -level_for(pokemon), name_for(pokemon), original_order]
      else
        [original_order]
      end
    end
  end

  def self.sortable_box?(storage, box_index)
    return false if box_index < 0 || box_index >= storage.maxBoxes
    box = storage[box_index]
    return false if box.respond_to?(:sortlock?) && box.sortlock?
    return true
  end
end

class PokemonBox
  attr_accessor :sortlock unless method_defined?(:sortlock)
  attr_accessor :exportlock unless method_defined?(:exportlock)

  if !method_defined?(:pc_storage_sorter_original_initialize) &&
     !private_method_defined?(:pc_storage_sorter_original_initialize)
    alias pc_storage_sorter_original_initialize initialize
  end

  def initialize(*args)
    pc_storage_sorter_original_initialize(*args)
    @sortlock = false if !defined?(@sortlock) || @sortlock.nil?
    @exportlock = false if !defined?(@exportlock) || @exportlock.nil?
  end

  def sortlock?
    return !!@sortlock
  end unless method_defined?(:sortlock?)

  def exportlock?
    return !!@exportlock
  end unless method_defined?(:exportlock?)
end

class PokemonStorageScreen
  if method_defined?(:pbShowCommands) && !method_defined?(:pc_storage_sorter_original_pbShowCommands)
    alias pc_storage_sorter_original_pbShowCommands pbShowCommands
  end

  def pbShowCommands(message, commands, index = 0)
    sort_commands = PCStorageSorter.prepare_box_commands!(commands)
    command = pc_storage_sorter_original_pbShowCommands(message, commands, index)
    if sort_commands
      @pc_storage_sorter_pending_box_command = :box if command == sort_commands[:box]
      @pc_storage_sorter_pending_box_command = :all if command == sort_commands[:all]
    end
    return command
  end

  if method_defined?(:pbBoxCommands) && !method_defined?(:pc_storage_sorter_original_pbBoxCommands)
    alias pc_storage_sorter_original_pbBoxCommands pbBoxCommands
  end

  def pbBoxCommands
    @pc_storage_sorter_pending_box_command = nil
    result = pc_storage_sorter_original_pbBoxCommands
    pending_command = @pc_storage_sorter_pending_box_command
    @pc_storage_sorter_pending_box_command = nil
    pre_sort_boxes(pending_command == :all) if pending_command
    return result
  end

  def pre_sort_boxes(all_sorting = false)
    choices = [
      _INTL("Sort by Level (High First)"),
      _INTL("Sort by Dex Number"),
      _INTL("Cancel")
    ]
    message = all_sorting ? _INTL("Sort all boxes how?") : _INTL("Sort this box how?")
    choice = pbShowCommands(message, choices)
    return if !choice || choice < 0 || choice >= 2

    mode = (choice == 0) ? :level : :dex
    count = pc_storage_sorter_apply_sort(mode, all_sorting)
    if count && count > 0
      pbHardRefresh
      if all_sorting
        pbDisplay(_INTL("Sorted {1} Pokemon. Box 1 is open for new captures.", count))
      else
        pbDisplay(_INTL("Sorted {1} Pokemon.", count))
      end
    end
  end

  def pc_storage_sorter_apply_sort(mode, all_sorting)
    if all_sorting
      return pc_storage_sorter_sort_all(mode)
    end
    return pc_storage_sorter_sort_current_box(mode)
  end

  def pc_storage_sorter_sort_current_box(mode)
    box_index = @storage.currentBox
    if !PCStorageSorter.sortable_box?(@storage, box_index)
      pbDisplay(_INTL("This box is locked for sorting."))
      return 0
    end

    entries = []
    limit = @storage.maxPokemon(box_index)
    for slot in 0...limit
      pokemon = @storage[box_index, slot]
      next if !pokemon
      entries << [pokemon, box_index, slot, entries.length]
    end
    if entries.empty?
      pbDisplay(_INTL("There are no Pokemon to sort."))
      return 0
    end

    sorted = PCStorageSorter.sort_entries(entries, mode)
    for slot in 0...limit
      @storage[box_index, slot] = nil
    end
    sorted.each_with_index do |entry, slot|
      @storage[box_index, slot] = entry[0]
    end
    return sorted.length
  end

  def pc_storage_sorter_sort_all(mode)
    if !PCStorageSorter.sortable_box?(@storage, 0)
      pbDisplay(_INTL("Box 1 is locked for sorting."))
      return 0
    end

    entries = []
    for box_index in 0...@storage.maxBoxes
      next if !PCStorageSorter.sortable_box?(@storage, box_index)
      limit = @storage.maxPokemon(box_index)
      for slot in 0...limit
        pokemon = @storage[box_index, slot]
        next if !pokemon
        entries << [pokemon, box_index, slot, entries.length]
      end
    end
    if entries.empty?
      pbDisplay(_INTL("There are no Pokemon to sort."))
      return 0
    end

    destination_boxes = []
    capacity = 0
    for box_index in PCStorageSorter::FIRST_SORTED_BOX...@storage.maxBoxes
      next if !PCStorageSorter.sortable_box?(@storage, box_index)
      destination_boxes << box_index
      capacity += @storage.maxPokemon(box_index)
    end
    if capacity < entries.length
      pbDisplay(_INTL("There is not enough room to leave Box 1 open."))
      return 0
    end

    entries.each do |entry|
      @storage[entry[1], entry[2]] = nil
    end

    sorted = PCStorageSorter.sort_entries(entries, mode)
    box_cursor = 0
    slot_cursor = 0
    sorted.each do |entry|
      box_index = destination_boxes[box_cursor]
      @storage[box_index, slot_cursor] = entry[0]
      slot_cursor += 1
      if slot_cursor >= @storage.maxPokemon(box_index)
        box_cursor += 1
        slot_cursor = 0
      end
    end
    return sorted.length
  end
end
