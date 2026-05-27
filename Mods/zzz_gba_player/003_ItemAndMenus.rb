# frozen_string_literal: true

GBA_PLAYER_ITEM_NUMBER = 8061

module GBAPlayer
  ITEM_ID = :GBAPLAYER

  module_function

  def register_item
    return if !defined?(GameData::Item)
    GameData::Item.register({
      :id          => ITEM_ID,
      :id_number   => GBA_PLAYER_ITEM_NUMBER,
      :name        => "GBA Player",
      :name_plural => "GBA Players",
      :pocket      => 8,
      :price       => 0,
      :description => "A key item that opens a local GBA library and Pokemon save importer.",
      :field_use   => 0,
      :battle_use  => 0,
      :type        => 6,
      :move        => nil
    })
    MessageTypes.set(MessageTypes::Items, GBA_PLAYER_ITEM_NUMBER, "GBA Player") if defined?(MessageTypes)
    MessageTypes.set(MessageTypes::ItemPlurals, GBA_PLAYER_ITEM_NUMBER, "GBA Players") if defined?(MessageTypes)
    if defined?(MessageTypes)
      MessageTypes.set(MessageTypes::ItemDescriptions, GBA_PLAYER_ITEM_NUMBER,
        "A key item that opens a local GBA library and Pokemon save importer.")
    end
  end

  def ensure_key_item!
    return false if !$PokemonBag
    return true if $PokemonBag.pbHasItem?(ITEM_ID)
    $PokemonBag.pbStoreItem(ITEM_ID)
  rescue
    false
  end

  def open_menu
    open_mobile_menu
  end

  def open_mobile_menu
    ensure_directories
    ensure_key_item!
    if defined?(GBAPlayer::ShellScene) && defined?(Graphics) && defined?(Sprite)
      GBAPlayer::ShellScene.new(:mobile).pbStart
      return
    end
    open_mobile_text_menu
  end

  def open_pc_menu
    ensure_directories
    ensure_key_item!
    if defined?(GBAPlayer::ShellScene) && defined?(Graphics) && defined?(Sprite)
      GBAPlayer::ShellScene.new(:pc).pbStart
      return
    end
    open_text_menu(true)
  end

  def open_text_menu(allow_import = true)
    command = 0
    loop do
      commands = [
        _INTL("Play ROM"),
        _INTL("Resume Last ROM")
      ]
      commands << _INTL("Import Pokemon From Save") if allow_import
      commands << _INTL("Settings")
      commands << _INTL("Close")
      command = pbMessage(_INTL("GBA Player"), commands, -1, nil, command)
      case command
      when 0 then open_rom_menu
      when 1 then resume_last_rom
      else
        if allow_import && command == 2
          import_save_menu
        elsif command == commands.length - 2
          open_settings_menu
        else
          break
        end
      end
    end
  end

  def open_mobile_text_menu
    open_text_menu(false)
  end

  def open_rom_menu
    roms = discover_roms
    if roms.empty?
      pbMessage(GBAPlayer.intl("No ROMs were found.\nPut local .gba, .gb, .gbc, or .zip files in:\n{1}", File.join(ROOT, "ROMs")))
      return
    end
    last_rom = absolute_path(config["last_rom"])
    roms = roms.sort_by do |path|
      [
        (path.downcase == last_rom.downcase) ? 0 : 1,
        favorite?(path) ? 0 : 1,
        rom_label(path).downcase
      ]
    end
    command = 0
    loop do
      commands = roms.map do |path|
        prefix = ""
        prefix = "[Last] " if path.downcase == last_rom.downcase
        prefix += "[Fav] " if favorite?(path)
        prefix + rom_label(path)
      end
      commands << _INTL("Refresh Library")
      commands << _INTL("Cancel")
      command = pbMessage(_INTL("Choose a ROM."), commands, -1, nil, command)
      break if command < 0 || command >= commands.length - 2
      if command == commands.length - 2
        roms = discover_roms
        pbMessage(GBAPlayer.intl("Library refreshed. Found {1} ROM(s).", roms.length))
        next
      end
      show_rom_actions(roms[command])
      last_rom = absolute_path(config["last_rom"])
    end
  end

  def show_rom_actions(path)
    command = pbMessage(GBAPlayer.intl("{1}", rom_label(path)), [
      _INTL("Play"),
      favorite?(path) ? _INTL("Remove Favorite") : _INTL("Add Favorite"),
      _INTL("Cancel")
    ], -1)
    case command
    when 0
      if start_walkalong(path)
        pbMessage(GBAPlayer.intl("Started {1}.", rom_label(path)))
      else
        pbMessage(_INTL("That ROM could not be opened. Check Settings for bridge status."))
      end
    when 1
      toggle_favorite(path)
    end
  end

  def toggle_favorite(path)
    path = absolute_path(path)
    config["favorites"] = Array(config["favorites"])
    existing = config["favorites"].find { |fav| absolute_path(fav).downcase == path.downcase }
    if existing
      config["favorites"].delete(existing)
      pbMessage(_INTL("Removed from favorites."))
    else
      config["favorites"] << path
      pbMessage(_INTL("Added to favorites."))
    end
    write_config
  end

  def resume_last_rom
    path = absolute_path(config["last_rom"])
    if path.empty? || !File.file?(path)
      pbMessage(_INTL("No last-played ROM was found."))
      return
    end
    start_walkalong(path)
  end

  def open_settings_menu
    command = 0
    loop do
      commands = [
        _INTL("Bridge Status"),
        _INTL("Open ROM Folder"),
        _INTL("Open Save Folder"),
        _INTL("Toggle Bridge Backend"),
        _INTL("Toggle Display Mode"),
        _INTL("Reload Config"),
        _INTL("Close")
      ]
      command = pbMessage(_INTL("GBA Player Settings"), commands, -1, nil, command)
      case command
      when 0
        pbMessage(GBAPlayer.intl("{1}\nBackend: {2}\nDisplay mode: {3}", bridge_status, bridge_backend, display_mode))
      when 1
        open_folder(File.join(ROOT, "ROMs"))
      when 2
        open_folder(File.join(ROOT, "Saves"))
      when 3
        pbMessage(GBAPlayer.intl("Bridge backend set to {1}.", toggle_bridge_backend))
      when 4
        pbMessage(GBAPlayer.intl("Display mode set to {1}.", toggle_display_mode))
      when 5
        reload_config
        pbMessage(_INTL("Config reloaded."))
      else
        break
      end
    end
  end

  def open_folder(path)
    ensure_directories
    system("start \"\" #{cmd_quote(windows_path(path))}")
  rescue
    pbMessage(_INTL("Could not open that folder."))
  end

  def import_save_menu
    saves = discover_saves
    if saves.empty?
      pbMessage(GBAPlayer.intl("No save files were found.\nPut .sav or .srm files in:\n{1}", File.join(ROOT, "Saves")))
      return
    end
    commands = saves.map { |path| label_for_path(path) }
    commands << _INTL("Cancel")
    command = pbMessage(_INTL("Choose a Gen 3 save."), commands, -1)
    return if command < 0 || command >= saves.length
    parse_and_import_save(saves[command])
  end

  def parse_and_import_save(path)
    parsed = Gen3SaveParser.parse(path, config)
    show_save_preview(parsed)
    entries = choose_import_entries(parsed)
    return if entries.empty?
    import_entries(parsed, entries)
  rescue Exception => e
    pbMessage(GBAPlayer.intl("That save could not be imported.\n{1}", e.message))
  end

  def show_save_preview(parsed)
    trainer = parsed[:trainer] || {}
    party_count = importable_entries(parsed[:party]).length
    box_count = importable_entries(parsed[:boxes].flatten).length
    saved_at = File.mtime(parsed[:path]).strftime("%Y-%m-%d %H:%M") rescue "Unknown"
    text = GBAPlayer.intl("Trainer: {1}\nSave index: {2}\nFile time: {3}\nParty: {4}  Boxes: {5}",
      trainer[:name] || "GBA",
      parsed[:save_index],
      saved_at,
      party_count,
      box_count)
    pbMessage(text)
    show_warning_summary(parsed[:warnings])
  end

  def choose_import_entries(parsed)
    party = importable_entries(parsed[:party])
    current_box = parsed[:current_box].to_i
    current = importable_entries(parsed[:boxes][current_box] || [])
    all_boxes = importable_entries(parsed[:boxes].flatten)
    commands = []
    actions = []
    commands << GBAPlayer.intl("Party ({1})", party.length)
    actions << party
    commands << GBAPlayer.intl("Current Box ({1})", current.length)
    actions << current
    commands << GBAPlayer.intl("All Boxes ({1})", all_boxes.length)
    actions << all_boxes
    commands << _INTL("Selected Pokemon")
    actions << :selected
    commands << _INTL("Cancel")
    choice = pbMessage(_INTL("What should be imported?"), commands, -1)
    return [] if choice < 0 || choice >= commands.length - 1
    return selected_import_entries(party + all_boxes) if actions[choice] == :selected
    actions[choice]
  end

  def selected_import_entries(pool)
    pool = pool.uniq
    selected = []
    command = 0
    loop do
      commands = pool.map do |entry|
        mark = selected.include?(entry) ? "[x] " : "[ ] "
        mark + import_entry_label(entry)
      end
      commands << GBAPlayer.intl("Import Selected ({1})", selected.length)
      commands << _INTL("Cancel")
      command = pbMessage(_INTL("Choose Pokemon."), commands, -1, nil, command)
      return [] if command < 0 || command == commands.length - 1
      return selected if command == commands.length - 2
      if selected.include?(pool[command])
        selected.delete(pool[command])
      else
        selected << pool[command]
      end
    end
  end

  def import_entries(parsed, entries)
    entries = importable_entries(entries)
    if entries.empty?
      pbMessage(_INTL("There are no compatible Pokemon to import."))
      return
    end
    free_slots = storage_free_slots
    if free_slots < entries.length
      pbMessage(GBAPlayer.intl("There is only room for {1} Pokemon in your PC boxes.\nImport cancelled before anything was written.", free_slots))
      return
    end
    history = load_history
    duplicate_count = entries.count { |entry| history[history_key(parsed, entry)] }
    if duplicate_count > 0
      ok = pbConfirmMessage(GBAPlayer.intl("{1} selected Pokemon look like duplicates from an earlier import.\nImport copies anyway?", duplicate_count))
      return if !ok
    end
    return if !pbConfirmMessage(GBAPlayer.intl("Import {1} copied Pokemon into your PC boxes?", entries.length))
    imported = 0
    entries.each do |entry|
      pokemon = entry[:pokemon].clone
      box = $PokemonStorage.pbStoreCaught(pokemon)
      if box < 0
        pbMessage(GBAPlayer.intl("The PC became full. Import stopped after {1} Pokemon.", imported))
        break
      end
      history[history_key(parsed, entry)] = Time.now.to_i
      imported += 1
      register_dex(pokemon)
    end
    write_history(history)
    pbMessage(GBAPlayer.intl("Imported {1} Pokemon as copies.", imported))
  end

  def importable_entries(entries)
    Array(entries).select { |entry| entry && entry[:pokemon] }
  end

  def import_entry_label(entry)
    pkmn = entry[:pokemon]
    GBAPlayer.intl("{1} Lv.{2} ({3} {4})",
      pkmn.name,
      pkmn.level,
      entry[:source],
      entry[:slot_index].to_i + 1)
  end

  def show_warning_summary(warnings)
    warnings = Array(warnings).compact
    return if warnings.empty?
    shown = warnings[0, 5].join("\n")
    extra = warnings.length > 5 ? GBAPlayer.intl("\n...and {1} more warning(s).", warnings.length - 5) : ""
    pbMessage(GBAPlayer.intl("Import notes:\n{1}{2}", shown, extra))
  end

  def storage_free_slots
    return 0 if !$PokemonStorage
    free = 0
    for box in 0...$PokemonStorage.maxBoxes
      for index in 0...$PokemonStorage.maxPokemon(box)
        free += 1 if !$PokemonStorage[box, index]
      end
    end
    free
  end

  def history_key(parsed, entry)
    "#{parsed[:fingerprint]}:#{entry[:duplicate_key]}"
  end

  def register_dex(pokemon)
    return if !$Trainer || !$Trainer.respond_to?(:pokedex) || !$Trainer.pokedex
    $Trainer.pokedex.register(pokemon) if $Trainer.pokedex.respond_to?(:register)
  rescue
    nil
  end

end

GBAPlayer.register_item

if defined?(ItemHandlers)
  ItemHandlers::UseFromBag.add(:GBAPLAYER, proc { |_item|
    GBAPlayer.open_menu
    next 1
  })
  ItemHandlers::UseInField.add(:GBAPLAYER, proc { |_item|
    GBAPlayer.open_menu
    next 1
  })
end

if defined?(EventHandlers) && EventHandlers.respond_to?(:add)
  EventHandlers.add(:on_load_save_file, :gba_player_ensure_key_item) do |_save_data|
    GBAPlayer.ensure_key_item!
  end
end

class GBAPlayerPC
  def shouldShow?
    true
  end

  def name
    _INTL("GBA Player")
  end

  def access
    GBAPlayer.ensure_key_item!
    pbMessage(_INTL("\\se[PC access]Accessed the GBA Player."))
    GBAPlayer.open_pc_menu
  end
end

PokemonPCList.registerPC(GBAPlayerPC.new) if defined?(PokemonPCList)
