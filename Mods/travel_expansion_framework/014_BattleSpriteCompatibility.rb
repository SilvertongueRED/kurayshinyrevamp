if defined?(Pokemon)
  class Pokemon
    attr_accessor :tef_source_expansion_id unless method_defined?(:tef_source_expansion_id)
    attr_accessor :tef_source_species unless method_defined?(:tef_source_species)
    attr_accessor :tef_source_form unless method_defined?(:tef_source_form)

    alias tef_decades_original_initialize initialize unless method_defined?(:tef_decades_original_initialize)

    def initialize(species, *args)
      source_species = species
      tef_decades_original_initialize(species, *args)
      if defined?(TravelExpansionFramework) &&
         TravelExpansionFramework.respond_to?(:decades_pokemon_battle_sprite_context?) &&
         TravelExpansionFramework.decades_pokemon_battle_sprite_context?
        expansion_id = TravelExpansionFramework.const_defined?(:DECADES_EXPANSION_ID) ? TravelExpansionFramework::DECADES_EXPANSION_ID : "decades"
        @tef_source_expansion_id ||= expansion_id
        @tef_source_species ||= source_species
      end
    end
  end
end

module TravelExpansionFramework
  module_function

  DECADES_POKEMON_SPRITE_EXTENSIONS = ["", ".png", ".gif", ".jpg", ".jpeg", ".bmp"].freeze unless const_defined?(:DECADES_POKEMON_SPRITE_EXTENSIONS)
  DECADES_DEFAULT_MAP_BLOCK_START = 46_000 unless const_defined?(:DECADES_DEFAULT_MAP_BLOCK_START)
  DECADES_DEFAULT_MAP_BLOCK_SIZE = 1_000 unless const_defined?(:DECADES_DEFAULT_MAP_BLOCK_SIZE)
  DECADES_SMALL_BATTLER_FRAME_MAX = 128 unless const_defined?(:DECADES_SMALL_BATTLER_FRAME_MAX)

  def imported_trainer_battle_sprite_patches_enabled?
    return respond_to?(:imported_trainer_native_battle_sprites_enabled?) && imported_trainer_native_battle_sprites_enabled?
  rescue
    return false
  end

  def imported_external_trainer?(trainer)
    return false if trainer.nil?
    return trainer.respond_to?(:travel_expansion_external_trainer?) && trainer.travel_expansion_external_trainer?
  rescue
    return false
  end

  def imported_trainer_sprite_path(trainer, fallback = nil)
    return nil if !imported_trainer_battle_sprite_patches_enabled?
    candidates = []
    candidates << fallback
    candidates << trainer.sprite_override if trainer && trainer.respond_to?(:sprite_override)
    if trainer && trainer.respond_to?(:travel_expansion_external_trainer_type_data)
      data = trainer.travel_expansion_external_trainer_type_data
      if data.is_a?(Hash)
        candidates << data[:front_sprite]
        candidates << data[:overworld_sprite]
      end
    end
    candidates.each do |candidate|
      logical = normalize_string_or_nil(candidate)
      next if logical.nil?
      return logical if pbResolveBitmap(logical)
    end
    return nil
  rescue
    return nil
  end

  def load_logical_bitmap(logical_path)
    logical = normalize_string_or_nil(logical_path)
    return nil if logical.nil?
    normalized = logical.gsub("\\", "/").sub(/\A\.\//, "")
    return nil if normalized.empty?
    normalized = normalized.sub(/\A\//, "")
    ext = File.extname(normalized)
    normalized = normalized[0...-ext.length] if !ext.empty?
    folder = File.dirname(normalized)
    folder = "" if folder == "."
    folder = "#{folder}/" if !folder.empty? && !folder.end_with?("/")
    filename = File.basename(normalized)
    return nil if filename.nil? || filename.empty?
    return RPG::Cache.load_bitmap(folder, filename)
  rescue => e
    log("[battle sprites] failed to load #{logical_path}: #{e.class}: #{e.message}")
    return nil
  end

  def apply_imported_trainer_bitmap!(sprite, bitmap)
    return if sprite.nil? || bitmap.nil?
    sprite.bitmap = bitmap
    if sprite.bitmap.width > sprite.bitmap.height * 2
      sprite.src_rect.x = 0
      sprite.src_rect.width = sprite.bitmap.width / 5
    else
      sprite.src_rect.x = 0
      sprite.src_rect.width = sprite.bitmap.width
    end
    sprite.src_rect.height = sprite.bitmap.height
    sprite.ox = sprite.src_rect.width / 2
    sprite.oy = sprite.bitmap.height
  rescue => e
    log("[battle sprites] failed to apply bitmap: #{e.class}: #{e.message}")
  end

  def imported_trainer_bitmap(trainer, fallback = nil)
    return nil if trainer.nil?
    imported_path = imported_trainer_sprite_path(trainer, fallback)
    return nil if imported_path.nil?
    return load_logical_bitmap(imported_path)
  rescue
    return nil
  end

  def apply_imported_trainer_sprite_to_scene!(scene, idx, trainer, fallback = nil)
    return if !imported_trainer_battle_sprite_patches_enabled?
    return if scene.nil? || !imported_external_trainer?(trainer)
    sprite = nil
    if scene.instance_variable_defined?(:@sprites)
      sprites = scene.instance_variable_get(:@sprites)
      sprite = sprites["trainer_#{idx}"] if sprites.is_a?(Hash)
      sprite = sprites["trainer_#{idx + 1}"] if sprite.nil? && sprites.is_a?(Hash)
    end
    return if sprite.nil?
    bitmap = imported_trainer_bitmap(trainer, fallback)
    return if bitmap.nil?
    apply_imported_trainer_bitmap!(sprite, bitmap)
  rescue => e
    log("[battle sprites] failed to patch scene trainer #{idx}: #{e.class}: #{e.message}")
  end

  def decades_virtual_map_id?(map_id = nil)
    map = integer(map_id || ($game_map.map_id rescue 0), 0)
    return false if map <= 0
    ids = decades_sprite_expansion_ids
    direct = current_map_expansion_id(map) if respond_to?(:current_map_expansion_id)
    return true if direct && ids.include?(direct.to_s)
    ids.each do |expansion_id|
      manifest = manifest_for(expansion_id) if respond_to?(:manifest_for)
      next if !manifest.is_a?(Hash) || !manifest[:map_block].is_a?(Hash)
      start_id = integer(manifest[:map_block][:start] || manifest[:map_block]["start"], 0)
      size = integer(manifest[:map_block][:size] || manifest[:map_block]["size"], DECADES_DEFAULT_MAP_BLOCK_SIZE)
      return true if start_id > 0 && size > 0 && map >= start_id && map < start_id + size
    end
    return map >= DECADES_DEFAULT_MAP_BLOCK_START && map < DECADES_DEFAULT_MAP_BLOCK_START + DECADES_DEFAULT_MAP_BLOCK_SIZE
  rescue
    return false
  end

  def decades_pokemon_battle_sprite_context?
    active_battle = @active_imported_battle_expansion_id
    return true if active_battle && decades_sprite_expansion_ids.include?(active_battle.to_s)
    return true if decades_virtual_map_id?
    return false if !respond_to?(:decades_expansion_ids)
    if respond_to?(:decades_active_now?) && decades_active_now?
      return true
    end
    ids = decades_expansion_ids.map { |id| id.to_s }
    candidates = []
    candidates << current_runtime_expansion_id if respond_to?(:current_runtime_expansion_id)
    candidates << current_asset_expansion_id if respond_to?(:current_asset_expansion_id)
    candidates << current_expansion_marker if respond_to?(:current_expansion_marker)
    candidates << current_map_expansion_id if respond_to?(:current_map_expansion_id)
    candidates.compact.each do |candidate|
      return true if ids.include?(candidate.to_s)
    end
    return false
  rescue
    return false
  end

  def decades_placeholder_species?(species_ref)
    return true if species_ref.nil?
    text = species_ref.to_s.gsub(/\A:/, "").upcase
    return true if text.empty? || text == "NIL" || text == "NONE" || text == "0"
    return true if text == "PIKACHU"
    return false
  rescue
    return false
  end

  def decades_sprite_expansion_ids
    ids = respond_to?(:decades_expansion_ids) ? decades_expansion_ids : []
    ids = [const_defined?(:DECADES_EXPANSION_ID) ? DECADES_EXPANSION_ID : "decades"] if ids.empty?
    return ids.map { |id| id.to_s }
  rescue
    return ["decades", "pokemon_decades"]
  end

  def pokemon_metadata_value(pokemon, reader_name, ivar_name)
    return nil if pokemon.nil?
    pokemon = pokemon.pokemon if pokemon.respond_to?(:pokemon)
    return pokemon.send(reader_name) if pokemon.respond_to?(reader_name)
    return pokemon.instance_variable_get(ivar_name) if pokemon.instance_variable_defined?(ivar_name)
    return nil
  rescue
    return nil
  end

  def decades_pokemon_source_expansion(pokemon)
    value = pokemon_metadata_value(pokemon, :tef_source_expansion_id, :@tef_source_expansion_id)
    value ||= pokemon_metadata_value(pokemon, :tef_origin_expansion_id, :@tef_origin_expansion_id)
    value ||= pokemon_metadata_value(pokemon, :travel_expansion_expansion_id, :@travel_expansion_expansion_id)
    return value.to_s if value && !value.to_s.empty?
    return nil
  rescue
    return nil
  end

  def decades_pokemon_from_decades?(pokemon)
    expansion = decades_pokemon_source_expansion(pokemon)
    return false if expansion.nil? || expansion.empty?
    return decades_sprite_expansion_ids.include?(expansion)
  rescue
    return false
  end

  def pokemon_dormant_species_value(pokemon)
    reference = pokemon_metadata_value(pokemon, :tef_dormant_species_reference, :@tef_dormant_species_reference)
    reference ||= pokemon_metadata_value(pokemon, :csf_dormant_species_reference, :@csf_dormant_species_reference)
    return nil if !reference.is_a?(Hash)
    return reference["species"] || reference[:species]
  rescue
    return nil
  end

  def decades_pokemon_source_species(pokemon)
    source = pokemon_metadata_value(pokemon, :tef_source_species, :@tef_source_species)
    source ||= pokemon_dormant_species_value(pokemon)
    return source if source && !source.to_s.empty?
    return nil
  rescue
    return nil
  end

  def decades_pokemon_display_name_species(pokemon)
    return nil if pokemon.nil?
    raw = pokemon
    unwrapped = raw.respond_to?(:pokemon) ? raw.pokemon : raw
    use_display_name = false
    if raw.respond_to?(:index)
      use_display_name = raw.index.to_i.odd?
    end
    use_display_name ||= decades_pokemon_battle_sprite_context?
    use_display_name ||= decades_virtual_map_id?
    use_display_name ||= decades_pokemon_from_decades?(raw)
    use_display_name ||= decades_pokemon_from_decades?(unwrapped)
    return nil if !use_display_name
    candidates = []
    candidates << raw.name if raw.respond_to?(:name)
    candidates << unwrapped.name if unwrapped && unwrapped.respond_to?(:name)
    candidates.each do |candidate|
      text = candidate.to_s.strip
      next if text.empty?
      normalized = text.upcase.gsub(/[^A-Z0-9_]/, "")
      next if normalized.empty? || normalized == "NIL"
      return normalized.to_sym
    end
    return nil
  rescue
    return nil
  end

  def decades_pokemon_species_symbol(species_ref)
    return nil if species_ref.nil?
    pokemon = species_ref.respond_to?(:pokemon) ? species_ref.pokemon : species_ref
    source_species = decades_pokemon_source_species(pokemon)
    display_species = decades_pokemon_display_name_species(species_ref)
    if display_species && decades_placeholder_species?(source_species)
      return display_species
    end
    return source_species.to_sym if source_species.is_a?(String) || source_species.is_a?(Symbol)
    return display_species if display_species
    return pokemon.species if pokemon.respond_to?(:species) && pokemon.species
    return species_ref.species if species_ref.respond_to?(:species) && species_ref.species
    expansion_id = const_defined?(:DECADES_EXPANSION_ID) ? DECADES_EXPANSION_ID : "decades"
    resolved = resolve_expansion_species(expansion_id, species_ref) if respond_to?(:resolve_expansion_species)
    return resolved if resolved.is_a?(Symbol)
    if defined?(CustomSpeciesFramework) && CustomSpeciesFramework.respond_to?(:compatibility_alias_target)
      resolved = CustomSpeciesFramework.compatibility_alias_target(species_ref, expansion_id) rescue nil
      return resolved if resolved.is_a?(Symbol)
    end
    if defined?(GameData::Species)
      data = GameData::Species.try_get(species_ref) rescue nil
      return data.species if data && data.respond_to?(:species)
      data = GameData::Species::DATA[species_ref] if defined?(GameData::Species::DATA) && GameData::Species::DATA.respond_to?(:[])
      return data.species if data && data.respond_to?(:species)
    end
    return species_ref.to_sym if species_ref.is_a?(String) || species_ref.is_a?(Symbol)
    return nil
  rescue
    return nil
  end

  def decades_pokemon_form_value(pokemon = nil, explicit_form = nil)
    value = explicit_form
    value = pokemon_metadata_value(pokemon, :tef_source_form, :@tef_source_form) if (value.nil? || value.to_s.empty?) && pokemon
    value = pokemon.form if (value.nil? || value.to_s.empty?) && pokemon && pokemon.respond_to?(:form)
    value = pokemon.form_simple if (value.nil? || value.to_s.empty?) && pokemon && pokemon.respond_to?(:form_simple)
    value = 0 if value.nil?
    return value.to_i
  rescue
    return 0
  end

  def decades_pokemon_sprite_candidates(species_ref, pokemon = nil, form = nil, female = false)
    candidates = []
    source_species = decades_pokemon_source_species(pokemon)
    display_species = decades_pokemon_display_name_species(pokemon)
    symbol = decades_placeholder_species?(source_species) ? decades_pokemon_species_symbol(display_species) : decades_pokemon_species_symbol(source_species)
    symbol ||= decades_pokemon_species_symbol(source_species)
    symbol ||= decades_pokemon_species_symbol(species_ref)
    symbol ||= decades_pokemon_species_symbol(pokemon)
    raw_names = []
    actual_species = nil
    actual_species = pokemon.species if pokemon && pokemon.respond_to?(:species)
    actual_species ||= species_ref.species if species_ref && species_ref.respond_to?(:species)
    if decades_placeholder_species?(source_species)
      raw_names << display_species.to_s if display_species
      raw_names << source_species.to_s if source_species
    else
      raw_names << source_species.to_s if source_species
      raw_names << display_species.to_s if display_species
    end
    raw_names << symbol.to_s if symbol
    raw_names << actual_species.to_s if actual_species
    raw_names << species_ref.to_s if species_ref.is_a?(String) || species_ref.is_a?(Symbol)
    raw_names.compact!
    raw_names.map! { |name| name.gsub(/\A:/, "").upcase }
    raw_names.reject! { |name| name.empty? || name == "NIL" }
    raw_names.uniq!
    sprite_form = decades_pokemon_form_value(pokemon, form)
    raw_names.each do |name|
      if female
        candidates << "#{name}_female"
        candidates << "#{name}_F"
      end
      if sprite_form > 0
        candidates << "#{name}_#{sprite_form}"
        candidates << "#{name}_#{sprite_form + 1}"
      end
      candidates << name
    end
    return candidates.uniq
  rescue
    return []
  end

  def decades_pokemon_sprite_path(species_ref, back = false, shiny = false, pokemon = nil, form = nil, female = false)
    return nil if !decades_pokemon_battle_sprite_context? && !decades_pokemon_from_decades?(pokemon)
    expansion_id = const_defined?(:DECADES_EXPANSION_ID) ? DECADES_EXPANSION_ID : "decades"
    candidates = decades_pokemon_sprite_candidates(species_ref, pokemon, form, female)
    return nil if candidates.empty?
    folders = []
    folders << (back ? "Back shiny" : "Front shiny") if shiny
    folders << (back ? "Back" : "Front")
    folders.each do |folder|
      candidates.each do |candidate|
        logical = "Graphics/Pokemon/#{folder}/#{candidate}"
        path = resolve_runtime_path_for_expansion(expansion_id, logical, DECADES_POKEMON_SPRITE_EXTENSIONS) if respond_to?(:resolve_runtime_path_for_expansion)
        if path
          log_runtime_asset_once(expansion_id, "pokemon sprite", logical, path) if respond_to?(:log_runtime_asset_once)
          return path
        end
      end
    end
    log_runtime_asset_once(expansion_id, "pokemon sprite missing", candidates.first, back ? "back" : "front") if respond_to?(:log_runtime_asset_once)
    return nil
  rescue => e
    log("[decades] Pokemon sprite lookup failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def decades_ebdx_bitmap_request?
    return CustomSpeciesFramework.ebdx_bitmap_request? if defined?(CustomSpeciesFramework) && CustomSpeciesFramework.respond_to?(:ebdx_bitmap_request?)
    return caller_locations(1, 18).any? { |location| location.path.to_s.include?("660_EBDX") }
  rescue
    return false
  end

  def decades_static_frame_bitmap(path)
    source = Bitmap.new(path)
    width = source.width.to_i
    height = source.height.to_i
    return nil if width <= 0 || height <= 0
    frame_width = width > height * 2 ? height : width
    frame = Bitmap.new(frame_width, height)
    frame.blt(0, 0, source, Rect.new(0, 0, frame_width, height))
    source.dispose if source.respond_to?(:dispose)
    bitmap = AnimatedBitmap.from_bitmap(frame)
    if frame_width <= DECADES_SMALL_BATTLER_FRAME_MAX && height <= DECADES_SMALL_BATTLER_FRAME_MAX
      bitmap.scale_bitmap(3)
    end
    return bitmap
  rescue => e
    source.dispose if source && source.respond_to?(:dispose) rescue nil
    log("[decades] failed to normalize sprite sheet #{path}: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def decades_load_pokemon_battler_bitmap(species_ref, back = false, pokemon = nil, form = nil, shiny = false, female = false, scale = nil, speed = 2)
    path = decades_pokemon_sprite_path(species_ref, back, shiny, pokemon, form, female)
    return nil if path.nil?
    if decades_ebdx_bitmap_request? && defined?(BitmapEBDX)
      default_scale = if defined?(EliteBattle)
                        back ? EliteBattle::BACK_SPRITE_SCALE : EliteBattle::FRONT_SPRITE_SCALE
                      else
                        back ? Settings::BACKRPSPRITE_SCALE : Settings::FRONTSPRITE_SCALE
                      end
      return BitmapEBDX.new(path, scale || default_scale, speed)
    end
    normalized = decades_static_frame_bitmap(path)
    return normalized if normalized
    return AnimatedBitmap.new(path).recognizeDims rescue AnimatedBitmap.new(path)
  rescue => e
    log("[decades] failed to load Pokemon battler sprite #{species_ref.inspect}: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def apply_decades_pokemon_battler_bitmap!(sprite, pokemon, back = false, species = nil)
    return false if sprite.nil? || pokemon.nil?
    return false if !decades_pokemon_battle_sprite_context? && !decades_pokemon_from_decades?(pokemon)
    return false if back && !decades_pokemon_from_decades?(pokemon)
    bitmap = decades_sprite_bitmap_from_pokemon(pokemon, back, species, true)
    return false if bitmap.nil?
    previous = sprite.instance_variable_get(:@_iconBitmap) if sprite.instance_variable_defined?(:@_iconBitmap)
    previous.dispose if previous && previous != bitmap && previous.respond_to?(:dispose)
    sprite.instance_variable_set(:@back, back)
    sprite.instance_variable_set(:@pkmn, pokemon)
    sprite.instance_variable_set(:@_iconBitmap, bitmap)
    sprite.mirror = true if back && sprite.respond_to?(:mirror=)
    scale = back ? Settings::BACKRPSPRITE_SCALE : Settings::FRONTSPRITE_SCALE
    bitmap.scale_bitmap(scale) if bitmap.respond_to?(:scale_bitmap)
    sprite.bitmap = bitmap.bitmap if sprite.respond_to?(:bitmap=)
    sprite.pbSetPosition if sprite.respond_to?(:pbSetPosition)
    name = pokemon.respond_to?(:name) ? pokemon.name : species
    log_runtime_asset_once("decades", "pokemon sprite applied", "#{name}/#{back ? "back" : "front"}", "battle") if respond_to?(:log_runtime_asset_once)
    return true
  rescue => e
    log("[decades] failed to apply battle sprite directly: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def decades_sprite_bitmap_from_pokemon(pokemon, back = false, species = nil, make_shiny = true)
    return nil if !decades_pokemon_battle_sprite_context? && !decades_pokemon_from_decades?(pokemon)
    return nil if back && !decades_pokemon_from_decades?(pokemon)
    raw = pokemon
    pkmn = raw.respond_to?(:pokemon) ? raw.pokemon : raw
    source_species = decades_pokemon_source_species(raw)
    source_species ||= decades_pokemon_source_species(pkmn)
    display_species = decades_pokemon_display_name_species(raw)
    lookup_species = decades_placeholder_species?(source_species) ? display_species : source_species
    lookup_species ||= display_species || species
    lookup_species ||= raw.species if raw.respond_to?(:species)
    lookup_species ||= pkmn.species if pkmn && pkmn.respond_to?(:species)
    shiny = make_shiny && pkmn && pkmn.respond_to?(:shiny?) ? pkmn.shiny? : false
    female = pkmn && pkmn.respond_to?(:female?) ? pkmn.female? : false
    form = decades_pokemon_form_value(pkmn || raw, nil)
    return decades_load_pokemon_battler_bitmap(lookup_species, back, raw, form, shiny, female)
  rescue => e
    log("[decades] sprite_bitmap_from_pokemon fallback failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end
end

if defined?(PokemonBattlerSprite)
  class PokemonBattlerSprite
    alias tef_decades_original_setPokemonBitmap setPokemonBitmap unless method_defined?(:tef_decades_original_setPokemonBitmap)

    def setPokemonBitmap(pkmn, back = false)
      if defined?(TravelExpansionFramework) &&
         TravelExpansionFramework.respond_to?(:apply_decades_pokemon_battler_bitmap!) &&
         TravelExpansionFramework.apply_decades_pokemon_battler_bitmap!(self, pkmn, back)
        return
      end
      return tef_decades_original_setPokemonBitmap(pkmn, back)
    end
  end
end

class PokeBattle_Scene
  alias tef_imported_trainer_original_pbCreateTrainerFrontSprite pbCreateTrainerFrontSprite

  def pbCreateTrainerFrontSprite(idxTrainer, trainerType, numTrainers = 1, sprite_override = nil, custom_appearance = nil)
    tef_imported_trainer_original_pbCreateTrainerFrontSprite(idxTrainer, trainerType, numTrainers, sprite_override, custom_appearance)
    return if !TravelExpansionFramework.imported_trainer_battle_sprite_patches_enabled?
    return if !@battle || !@battle.respond_to?(:opponent)
    trainer = @battle.opponent[idxTrainer] rescue nil
    return if !TravelExpansionFramework.imported_external_trainer?(trainer)
    imported_path = TravelExpansionFramework.imported_trainer_sprite_path(trainer, sprite_override)
    return if imported_path.nil?
    sprite = @sprites["trainer_#{idxTrainer + 1}"]
    return if sprite.nil?
    bitmap = TravelExpansionFramework.load_logical_bitmap(imported_path)
    return if bitmap.nil?
    TravelExpansionFramework.apply_imported_trainer_bitmap!(sprite, bitmap)
  end
end

class PokeBattle_Scene
  if method_defined?(:initializeSprites) && !method_defined?(:tef_imported_trainer_original_initializeSprites)
    alias tef_imported_trainer_original_initializeSprites initializeSprites

    def initializeSprites(*args)
      result = tef_imported_trainer_original_initializeSprites(*args)
      return result if !TravelExpansionFramework.imported_trainer_battle_sprite_patches_enabled?
      if @battle && @battle.respond_to?(:opponent)
        Array(@battle.opponent).each_with_index do |trainer, idx|
          TravelExpansionFramework.apply_imported_trainer_sprite_to_scene!(self, idx, trainer)
        end
      end
      return result
    end
  end
end

if defined?(KIFTrainerSprite)
  class KIFTrainerSprite
    alias tef_imported_trainer_original_setTrainerBitmap setTrainerBitmap unless method_defined?(:tef_imported_trainer_original_setTrainerBitmap)

    def setTrainerBitmap(trainer = nil)
      tef_imported_trainer_original_setTrainerBitmap(trainer)
      return if !TravelExpansionFramework.imported_trainer_battle_sprite_patches_enabled?
      trainer = @trainer if trainer.nil?
      return if !TravelExpansionFramework.imported_external_trainer?(trainer)
      bitmap = TravelExpansionFramework.imported_trainer_bitmap(trainer)
      return if bitmap.nil?
      TravelExpansionFramework.apply_imported_trainer_bitmap!(self, bitmap)
      @loaded = true
    end
  end
end

alias tef_imported_trainer_original_pbBattleAnimationOverride pbBattleAnimationOverride
def pbBattleAnimationOverride(viewport, battletype = 0, foe = nil)
  return tef_imported_trainer_original_pbBattleAnimationOverride(viewport, battletype, foe) if !TravelExpansionFramework.imported_trainer_battle_sprite_patches_enabled?
  if (battletype == 1 || battletype == 3) && foe.is_a?(Array) && foe.length == 1
    trainer = foe[0]
    return false if TravelExpansionFramework.imported_external_trainer?(trainer)
  end
  return tef_imported_trainer_original_pbBattleAnimationOverride(viewport, battletype, foe)
end

if defined?(CustomSpeciesFramework)
  module CustomSpeciesFramework
    class << self
      alias tef_decades_original_battler_asset_path battler_asset_path unless method_defined?(:tef_decades_original_battler_asset_path)

      def battler_asset_path(species, back = false)
        return tef_decades_original_battler_asset_path(species, back) if back
        if defined?(TravelExpansionFramework) && TravelExpansionFramework.decades_pokemon_battle_sprite_context?
          path = TravelExpansionFramework.decades_pokemon_sprite_path(species, back)
          return path if path
        end
        return tef_decades_original_battler_asset_path(species, back)
      end
    end
  end
end

if defined?(GameData::Species)
  module GameData
    class Species
      class << self
        alias tef_decades_original_front_sprite_filename front_sprite_filename unless method_defined?(:tef_decades_original_front_sprite_filename)
        alias tef_decades_original_back_sprite_filename back_sprite_filename unless method_defined?(:tef_decades_original_back_sprite_filename)

        def front_sprite_filename(species, form = 0, gender = 0, shiny = false, shadow = false)
          if defined?(TravelExpansionFramework) && TravelExpansionFramework.decades_pokemon_battle_sprite_context?
            female = gender == 1 || gender == true
            path = TravelExpansionFramework.decades_pokemon_sprite_path(species, false, shiny, nil, form, female)
            return path if path
          end
          return tef_decades_original_front_sprite_filename(species, form, gender, shiny, shadow)
        end

        def back_sprite_filename(species, form = 0, gender = 0, shiny = false, shadow = false)
          return tef_decades_original_back_sprite_filename(species, form, gender, shiny, shadow)
        end

        if method_defined?(:front_sprite_bitmap)
          alias tef_decades_original_front_sprite_bitmap front_sprite_bitmap unless method_defined?(:tef_decades_original_front_sprite_bitmap)

          def front_sprite_bitmap(dex_number, *args)
            if defined?(TravelExpansionFramework) && TravelExpansionFramework.decades_pokemon_battle_sprite_context?
              form = args[0] || 0
              gender = args[1] || 0
              shiny = args[2] || false
              bitmap = TravelExpansionFramework.decades_load_pokemon_battler_bitmap(dex_number, false, nil, form, shiny, gender == 1 || gender == true)
              return bitmap if bitmap
            end
            return tef_decades_original_front_sprite_bitmap(dex_number, *args)
          end
        end

        if method_defined?(:back_sprite_bitmap)
          alias tef_decades_original_back_sprite_bitmap back_sprite_bitmap unless method_defined?(:tef_decades_original_back_sprite_bitmap)

          def back_sprite_bitmap(dex_number, *args)
            return tef_decades_original_back_sprite_bitmap(dex_number, *args)
          end
        end

        if method_defined?(:sprite_bitmap_from_pokemon)
          alias tef_decades_original_sprite_bitmap_from_pokemon sprite_bitmap_from_pokemon unless method_defined?(:tef_decades_original_sprite_bitmap_from_pokemon)

          def sprite_bitmap_from_pokemon(pkmn, back = false, species = nil, makeShiny = true)
            if defined?(TravelExpansionFramework)
              bitmap = TravelExpansionFramework.decades_sprite_bitmap_from_pokemon(pkmn, back, species, makeShiny)
              return bitmap if bitmap
            end
            begin
              return tef_decades_original_sprite_bitmap_from_pokemon(pkmn, back, species, makeShiny)
            rescue ArgumentError
              return tef_decades_original_sprite_bitmap_from_pokemon(pkmn, back, species)
            end
          end
        end
      end
    end
  end
end

alias tef_decades_original_pbLoadPokemonBitmapSpecies pbLoadPokemonBitmapSpecies unless defined?(tef_decades_original_pbLoadPokemonBitmapSpecies)
def pbLoadPokemonBitmapSpecies(pokemon, species, back = false, scale = nil, speed = 2)
  if defined?(TravelExpansionFramework) &&
     (TravelExpansionFramework.decades_pokemon_battle_sprite_context? || TravelExpansionFramework.decades_pokemon_from_decades?(pokemon))
    return tef_decades_original_pbLoadPokemonBitmapSpecies(pokemon, species, back, scale, speed) if back && !TravelExpansionFramework.decades_pokemon_from_decades?(pokemon)
    pokemon = pokemon.pokemon if pokemon.respond_to?(:pokemon)
    species = pokemon.species if species.nil? && pokemon && pokemon.respond_to?(:species)
    shiny = pokemon.respond_to?(:shiny?) ? pokemon.shiny? : false
    female = pokemon.respond_to?(:female?) ? pokemon.female? : false
    form = pokemon.respond_to?(:form) ? pokemon.form : nil
    bitmap = TravelExpansionFramework.decades_load_pokemon_battler_bitmap(species, back, pokemon, form, shiny, female, scale, speed)
    return bitmap if bitmap
  end
  return tef_decades_original_pbLoadPokemonBitmapSpecies(pokemon, species, back, scale, speed)
end

alias tef_decades_original_pbLoadPokemonBitmap pbLoadPokemonBitmap unless defined?(tef_decades_original_pbLoadPokemonBitmap)
def pbLoadPokemonBitmap(pokemon, back = false)
  if defined?(TravelExpansionFramework) &&
     (TravelExpansionFramework.decades_pokemon_battle_sprite_context? || TravelExpansionFramework.decades_pokemon_from_decades?(pokemon))
    bitmap = TravelExpansionFramework.decades_sprite_bitmap_from_pokemon(pokemon, back)
    return bitmap if bitmap
  end
  return tef_decades_original_pbLoadPokemonBitmap(pokemon, back)
end

alias tef_decades_original_pbLoadSpeciesBitmap pbLoadSpeciesBitmap unless defined?(tef_decades_original_pbLoadSpeciesBitmap)
def pbLoadSpeciesBitmap(species, female = false, form = 0, shiny = false, shadow = false, back = false, egg = false, scale = nil)
  if !egg && !back && defined?(TravelExpansionFramework) && TravelExpansionFramework.decades_pokemon_battle_sprite_context?
    bitmap = TravelExpansionFramework.decades_load_pokemon_battler_bitmap(species, back, nil, form, shiny, female, scale)
    return bitmap if bitmap
  end
  return tef_decades_original_pbLoadSpeciesBitmap(species, female, form, shiny, shadow, back, egg, scale)
end

alias tef_decades_original_pbPokemonBitmapFile pbPokemonBitmapFile unless defined?(tef_decades_original_pbPokemonBitmapFile)
def pbPokemonBitmapFile(species, *args)
  if defined?(TravelExpansionFramework) && TravelExpansionFramework.decades_pokemon_battle_sprite_context?
    shiny = args[0] || false
    back = args.length >= 2 ? args[1] : false
    return tef_decades_original_pbPokemonBitmapFile(species, *args) if back
    path = TravelExpansionFramework.decades_pokemon_sprite_path(species, back, shiny)
    return path if path
  end
  return tef_decades_original_pbPokemonBitmapFile(species, *args)
end
