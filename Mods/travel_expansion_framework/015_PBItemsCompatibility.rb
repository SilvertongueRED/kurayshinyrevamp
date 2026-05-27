module TravelExpansionFramework
  IMPORTED_ITEM_ID_RANGE_START = 50_000 if !const_defined?(:IMPORTED_ITEM_ID_RANGE_START)
  IMPORTED_ITEM_ID_RANGE_SIZE  = 20_000 if !const_defined?(:IMPORTED_ITEM_ID_RANGE_SIZE)
  REBORN_ITEM_ICON_EXTENSIONS  = [".png", ".PNG", ".gif", ".GIF"].freeze if !const_defined?(:REBORN_ITEM_ICON_EXTENSIONS)

  REBORN_MANUAL_ITEM_DATA = {
    "REVERSECANDY" => {
      :ID            => 527_001,
      :name          => "Reverse Candy",
      :desc          => "An ordinary, unhealthy piece of candy. It lowers the level of a single Pokemon by one.",
      :price         => 150,
      :medicine      => true,
      :noUseInBattle => true,
      :levelup       => true
    },
    "PHANTOMCANDYS" => {
      :ID            => 824_001,
      :name          => "Phantom Candy S",
      :desc          => "A spectral candy packed with energy. It grants a single Pokemon a small amount of Exp. Points.",
      :price         => 20,
      :medicine      => true,
      :noUseInBattle => true,
      :levelup       => true
    },
    "PHANTOMCANDYM" => {
      :ID            => 824_002,
      :name          => "Phantom Candy M",
      :desc          => "A spectral candy packed with energy. It grants a single Pokemon a moderate amount of Exp. Points.",
      :price         => 50,
      :medicine      => true,
      :noUseInBattle => true,
      :levelup       => true
    }
  }.freeze if !const_defined?(:REBORN_MANUAL_ITEM_DATA)

  REBORN_ICON_ALIASES = {
    "REVERSECANDY"  => "commoncandy",
    "PHANTOMCANDYS" => "expcandys",
    "PHANTOMCANDYM" => "expcandym"
  }.freeze if !const_defined?(:REBORN_ICON_ALIASES)

  REBORN_EXP_CANDY_VALUES = {
    "EXPCANDYXS"    => 100,
    "EXPCANDYS"     => 800,
    "PHANTOMCANDYS" => 800,
    "EXPCANDYM"     => 3_000,
    "PHANTOMCANDYM" => 3_000,
    "EXPCANDYL"     => 10_000,
    "EXPCANDYXL"    => 30_000
  }.freeze if !const_defined?(:REBORN_EXP_CANDY_VALUES)

  REBORN_STATUS_ITEM_ALIASES = {
    "POPROCKS"        => :AWAKENING,
    "PEPPERMINT"      => :ANTIDOTE,
    "SALTWATERTAFFY"  => :BURNHEAL,
    "CHEWINGGUM"      => :PARLYZHEAL,
    "REDHOTS"         => :ICEHEAL,
    "COTTONCANDY"     => :REVIVE
  }.freeze if !const_defined?(:REBORN_STATUS_ITEM_ALIASES)

  REBORN_HP_ITEM_VALUES = {
    "VANILLAIC"   => 30,
    "CHOCOLATEIC" => 70,
    "STRAWBIC"    => 90,
    "STRAWCAKE"   => 150,
    "BLUEMIC"     => 200
  }.freeze if !const_defined?(:REBORN_HP_ITEM_VALUES)

  REBORN_HAPPINESS_ONLY_ITEMS = {
    "POKESNAX"      => "level up",
    "GOURMETTREAT"  => "level up"
  }.freeze if !const_defined?(:REBORN_HAPPINESS_ONLY_ITEMS)

  EXTERNAL_NATURE_MINTS = {
    "HARDYMINT"   => :HARDY,
    "LONELYMINT"  => :LONELY,
    "BRAVEMINT"   => :BRAVE,
    "ADAMANTMINT" => :ADAMANT,
    "NAUGHTYMINT" => :NAUGHTY,
    "BOLDMINT"    => :BOLD,
    "DOCILEMINT"  => :DOCILE,
    "RELAXEDMINT" => :RELAXED,
    "IMPISHMINT"  => :IMPISH,
    "LAXMINT"     => :LAX,
    "TIMIDMINT"   => :TIMID,
    "HASTYMINT"   => :HASTY,
    "SERIOUSMINT" => :SERIOUS,
    "JOLLYMINT"   => :JOLLY,
    "NAIVEMINT"   => :NAIVE,
    "MODESTMINT"  => :MODEST,
    "MILDMINT"    => :MILD,
    "QUIETMINT"   => :QUIET,
    "BASHFULMINT" => :BASHFUL,
    "RASHMINT"    => :RASH,
    "CALMMINT"    => :CALM,
    "GENTLEMINT"  => :GENTLE,
    "SASSYMINT"   => :SASSY,
    "CAREFULMINT" => :CAREFUL,
    "QUIRKYMINT"  => :QUIRKY
  }.freeze if !const_defined?(:EXTERNAL_NATURE_MINTS)

  EXTERNAL_IV_CAPSULE_STATS = {
    "SCAPSULA"              => :HP,
    "HCAPSULA"              => :HP,
    "HPCAPSULA"             => :HP,
    "HPCAPSULE"             => :HP,
    "HEALTHCAPSULE"         => :HP,
    "VIGORCAPSULE"          => :HP,
    "VITALCAPSULE"          => :HP,
    "ACAPSULA"              => :ATTACK,
    "ATTACKCAPSULE"         => :ATTACK,
    "MUSCLECAPSULE"         => :ATTACK,
    "POWERCAPSULE"          => :ATTACK,
    "STRONGCAPSULE"         => :ATTACK,
    "DCAPSULA"              => :DEFENSE,
    "DEFENSECAPSULE"        => :DEFENSE,
    "RESISTCAPSULE"         => :DEFENSE,
    "ROBUSTCAPSULE"         => :DEFENSE,
    "AECAPSULA"             => :SPECIAL_ATTACK,
    "SPATKCAPSULE"          => :SPECIAL_ATTACK,
    "SPECIALATTACKCAPSULE"  => :SPECIAL_ATTACK,
    "GENIUSCAPSULE"         => :SPECIAL_ATTACK,
    "WISECAPSULE"           => :SPECIAL_ATTACK,
    "DECAPSULA"             => :SPECIAL_DEFENSE,
    "SPDEFCAPSULE"          => :SPECIAL_DEFENSE,
    "SPECIALDEFENSECAPSULE" => :SPECIAL_DEFENSE,
    "CLEVERCAPSULE"         => :SPECIAL_DEFENSE,
    "SPIRITCAPSULE"         => :SPECIAL_DEFENSE,
    "VCAPSULA"              => :SPEED,
    "SPEEDCAPSULE"          => :SPEED,
    "SWIFTCAPSULE"          => :SPEED,
    "IMPETUCAPSULE"         => :SPEED
  }.freeze if !const_defined?(:EXTERNAL_IV_CAPSULE_STATS)

  EXTERNAL_NATIVE_ITEM_DELEGATES = {
    "POTION"         => :POTION,
    "SUPERPOTION"    => :SUPERPOTION,
    "HYPERPOTION"    => :HYPERPOTION,
    "MAXPOTION"      => :MAXPOTION,
    "FULLRESTORE"    => :FULLRESTORE,
    "REVIVE"         => :REVIVE,
    "MAXREVIVE"      => :MAXREVIVE,
    "ANTIDOTE"       => :ANTIDOTE,
    "AWAKENING"      => :AWAKENING,
    "BURNHEAL"       => :BURNHEAL,
    "ICEHEAL"        => :ICEHEAL,
    "PARALYZEHEAL"   => :PARLYZHEAL,
    "PARLYZHEAL"     => :PARLYZHEAL,
    "FULLHEAL"       => :FULLHEAL,
    "FRESHWATER"     => :FRESHWATER,
    "SODAPOP"        => :SODAPOP,
    "LEMONADE"       => :LEMONADE,
    "MOOMOOMILK"     => :MOOMOOMILK,
    "ENERGYPOWDER"   => :ENERGYPOWDER,
    "ENERGYROOT"     => :ENERGYROOT,
    "HEALPOWDER"     => :HEALPOWDER,
    "REVIVALHERB"    => :REVIVALHERB,
    "ETHER"          => :ETHER,
    "MAXETHER"       => :MAXETHER,
    "ELIXIR"         => :ELIXIR,
    "MAXELIXIR"      => :MAXELIXIR,
    "RARECANDY"      => :RARECANDY,
    "HPUP"           => :HPUP,
    "PROTEIN"        => :PROTEIN,
    "IRON"           => :IRON,
    "CALCIUM"        => :CALCIUM,
    "ZINC"           => :ZINC,
    "CARBOS"         => :CARBOS,
    "HEALTHWING"     => :HEALTHWING,
    "MUSCLEWING"     => :MUSCLEWING,
    "RESISTWING"     => :RESISTWING,
    "GENIUSWING"     => :GENIUSWING,
    "CLEVERWING"     => :CLEVERWING,
    "SWIFTWING"      => :SWIFTWING,
    "PPUP"           => :PPUP,
    "PPMAX"          => :PPMAX,
    "ABILITYCAPSULE" => :ABILITYCAPSULE,
    "ABILITYPATCH"   => :SECRETCAPSULE,
    "SECRETCAPSULE"  => :SECRETCAPSULE
  }.freeze if !const_defined?(:EXTERNAL_NATIVE_ITEM_DELEGATES)

  module_function

  def active_item_lookup_expansion_id
    expansion = current_runtime_expansion_id if respond_to?(:current_runtime_expansion_id)
    expansion = current_expansion_marker if (expansion.nil? || expansion.to_s.empty?) && respond_to?(:current_expansion_marker)
    expansion = expansion.to_s
    return nil if expansion.empty?
    return expansion
  end

  def imported_item_expansion_candidates
    candidates = []
    candidates.concat(external_projects.keys) if respond_to?(:external_projects) && external_projects
    candidates.concat(registry(:expansions).keys) if respond_to?(:registry)
    imported_runtime_items.each_value do |metadata|
      next if !metadata.is_a?(Hash)
      candidates << metadata[:expansion_id]
      candidates << metadata["expansion_id"]
    end
    candidates.concat([
      "reborn",
      "insurgence",
      "pokemon_uranium",
      "uranium",
      "xenoverse",
      "pokemon_xenoverse",
      "opalo",
      "pokemon_opalo",
      "empyrean",
      "pokemonempyrean",
      "pokemon_empyrean",
      "realidea",
      "soulstones",
      "soulstones2",
      "anil",
      "pokemon_anil",
      "pokemon_indigo",
      "indigo",
      "bushido",
      "pokemon_bushido",
      "darkhorizon",
      "dark_horizon",
      "pokemon_darkhorizon",
      "pokemon_dark_horizon",
      "infinity",
      "pokemon_infinity",
      "solar_eclipse",
      "solareclipse",
      "pokemon_solar_eclipse",
      "pokemon_solareclipse",
      "solar_light_lunar_dark",
      "solar_light_and_lunar_dark",
      "pokemon_solar_light_lunar_dark",
      "vanguard",
      "pokemon_vanguard",
      "pokemon_z",
      "pokemonz",
      "z",
      "chaos_in_vesita",
      "chaosinvesita",
      "pokemon_chaos_in_vesita",
      "deserted",
      "pokemon_deserted",
      "gadir_deluxe",
      "gadirdeluxe",
      "gadirdelux",
      "pokemon_gadir_deluxe",
      "pokemon_gadir_delux",
      "hollow_woods",
      "hollowwoods",
      "pokemon_hollow_woods",
      "pokemon_hollowwoods",
      "keishou",
      "pokemon_keishou",
      "unbreakable_ties",
      "unbreakableties",
      "pokemon_unbreakable_ties",
      "pokemon_unbreakableties",
      "vaudelle_region",
      "travel_expansion_sample_annex"
    ])
    return candidates.compact.map(&:to_s).find_all { |entry| !entry.empty? }.uniq
  rescue
    return []
  end

  def canonical_imported_item_reference(item_identifier)
    raw = item_identifier.to_s.strip.gsub(/\A:/, "")
    return nil if raw.empty? || raw.upcase !~ /\ATEF_/
    matched_expansion = nil
    safety = 0
    loop do
      matched = nil
      matched_prefix = nil
      imported_item_expansion_candidates.each do |expansion_id|
        prefix = imported_item_prefix(expansion_id)
        next if prefix.nil? || prefix.empty?
        if raw.upcase.start_with?(prefix.upcase) && (matched_prefix.nil? || prefix.length > matched_prefix.length)
          matched = expansion_id
          matched_prefix = prefix
        end
      end
      break if matched.nil? || matched_prefix.nil?
      matched_expansion = matched
      raw = raw[matched_prefix.length..-1].to_s
      safety += 1
      break if safety > 8
    end
    return nil if matched_expansion.nil? || raw.empty?
    return [matched_expansion, raw]
  rescue
    return nil
  end

  def inferred_item_expansion_id(item_identifier)
    raw = item_identifier.to_s.strip.gsub(/\A:/, "")
    return nil if raw.empty?
    canonical = canonical_imported_item_reference(raw)
    return canonical[0] if canonical
    return nil if raw.upcase.start_with?("TEF_")
    known_origin = known_imported_item_origin_id(raw)
    return known_origin if known_origin && !known_origin.empty?
    explicit = active_item_lookup_expansion_id
    return explicit if explicit && !explicit.empty?
    return nil
  end

  def known_imported_item_origin_id(item_identifier)
    raw = item_identifier.to_s.strip.gsub(/\A:/, "")
    return nil if raw.empty? || raw.upcase.start_with?("TEF_")
    normalized = normalized_imported_item_name(raw)
    return nil if normalized.empty?
    return nil if base_item_try_get(raw.to_sym)

    cached = imported_item_origin_cache[normalized]
    return cached if cached && !cached.empty?

    imported_runtime_item_lookup.each_value do |metadata|
      next if !metadata.is_a?(Hash)
      remember_imported_item_origin(metadata)
      raw_name = normalized_imported_item_name(imported_item_metadata_value(metadata, :raw_name))
      next if raw_name != normalized
      expansion = imported_item_metadata_value(metadata, :expansion_id).to_s
      imported_item_origin_cache[normalized] = expansion if !expansion.empty?
      return expansion if !expansion.empty?
    end

    imported_runtime_items.each_value do |metadata|
      next if !metadata.is_a?(Hash)
      remember_imported_item_origin(metadata)
      raw_name = normalized_imported_item_name(imported_item_metadata_value(metadata, :raw_name))
      next if raw_name != normalized
      expansion = imported_item_metadata_value(metadata, :expansion_id).to_s
      imported_item_origin_cache[normalized] = expansion if !expansion.empty?
      return expansion if !expansion.empty?
    end

    # Reborn has the broadest item compatibility table right now. Prefer the
    # item's known source over the current map so Reborn items keep their
    # behavior after the player carries them into another world.
    if reborn_item_catalog.has_key?(normalized) ||
       REBORN_EXP_CANDY_VALUES.has_key?(normalized) ||
       REBORN_STATUS_ITEM_ALIASES.has_key?(normalized) ||
       REBORN_HP_ITEM_VALUES.has_key?(normalized) ||
       REBORN_HAPPINESS_ONLY_ITEMS.has_key?(normalized) ||
       REBORN_MANUAL_ITEM_DATA.has_key?(normalized)
      imported_item_origin_cache[normalized] = "reborn"
      return "reborn"
    end
    imported_item_expansion_candidates.each do |expansion_id|
      next if expansion_id.to_s.empty? || expansion_id.to_s == "reborn"
      catalog = generic_pbs_item_catalog(expansion_id)
      next if !catalog.is_a?(Hash) || !catalog.has_key?(normalized)
      imported_item_origin_cache[normalized] = expansion_id.to_s
      return expansion_id.to_s
    end
    return nil
  rescue => e
    log("Known imported item origin lookup failed for #{item_identifier.inspect}: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def humanize_external_item_name(value)
    text = value.to_s.strip
    return "Imported Item" if text.empty?
    text = text.gsub(/\A:/, "")
    text = text.gsub(/([a-z\d])([A-Z])/, '\1 \2')
    text = text.tr("_", " ")
    text = text.gsub(/\s+/, " ").strip
    words = text.split(" ")
    return "Imported Item" if words.empty?
    return words.map { |word| word[0] ? word[0].upcase + word[1..-1].to_s.downcase : word }.join(" ")
  end

  def imported_item_display_name(expansion_id)
    info = external_projects[expansion_id.to_s]
    return info[:display_name].to_s if info.is_a?(Hash) && !info[:display_name].to_s.empty?
    return expansion_id.to_s
  end

  def base_item_try_get(value)
    return value if value.is_a?(GameData::Item)
    return nil if !defined?(GameData::Item::DATA) || !GameData::Item::DATA.is_a?(Hash)
    query = value
    query = query.to_sym if query.is_a?(String)
    return GameData::Item::DATA[query]
  rescue
    return nil
  end

  def imported_item_runtime_symbol(expansion_id, item_name)
    expansion = expansion_id.to_s
    raw = imported_item_raw_name(expansion, item_name)
    return nil if expansion.empty? || raw.empty?
    normalized = raw.upcase.gsub(/[^\w]+/, "_").gsub(/\A_+|_+\z/, "")
    return nil if normalized.empty?
    return :"TEF_#{slugify(expansion).upcase}_#{normalized}"
  end

  def imported_item_prefix(expansion_id)
    expansion = expansion_id.to_s
    return nil if expansion.empty?
    return "TEF_#{slugify(expansion).upcase}_"
  end

  def imported_item_raw_name(expansion_id, item_identifier)
    expansion = expansion_id.to_s
    raw = item_identifier.to_s.strip.gsub(/\A:/, "")
    canonical = canonical_imported_item_reference(raw)
    if canonical && canonical[0].to_s == expansion
      canonical_raw = canonical[1].to_s
      alias_raw = canonical_imported_item_numeric_raw_alias(expansion, canonical_raw)
      return alias_raw if alias_raw
      return canonical_raw
    end
    prefix = imported_item_prefix(expansion_id)
    return raw if raw.empty? || prefix.nil? || prefix.empty?
    loop do
      break if !raw.upcase.start_with?(prefix.upcase)
      raw = raw[prefix.length..-1].to_s
    end
    alias_raw = canonical_imported_item_numeric_raw_alias(expansion, raw)
    return alias_raw if alias_raw
    return raw
  end

  def imported_item_id_number_for_raw_name(expansion_id, raw_name)
    expansion = expansion_id.to_s
    raw = raw_name.to_s.strip.gsub(/\A:/, "")
    signature = "#{expansion}:#{raw}"
    hash_value = 0
    signature.each_byte { |byte| hash_value = ((hash_value * 131) + byte) % IMPORTED_ITEM_ID_RANGE_SIZE }
    candidate = IMPORTED_ITEM_ID_RANGE_START + hash_value
    0.upto(IMPORTED_ITEM_ID_RANGE_SIZE - 1) do |offset|
      id_number = IMPORTED_ITEM_ID_RANGE_START + ((candidate - IMPORTED_ITEM_ID_RANGE_START + offset) % IMPORTED_ITEM_ID_RANGE_SIZE)
      existing = base_item_try_get(id_number)
      return id_number if existing.nil? || imported_item_id_belongs_to_raw?(existing, expansion, raw)
    end
    return IMPORTED_ITEM_ID_RANGE_START + hash_value
  end

  def imported_item_id_number(expansion_id, item_name)
    expansion = expansion_id.to_s
    raw = imported_item_raw_name(expansion, item_name)
    return imported_item_id_number_for_raw_name(expansion, raw)
  end

  def imported_item_id_belongs_to_raw?(item_data, expansion_id, raw_name)
    return false if item_data.nil?
    expansion = expansion_id.to_s
    raw = raw_name.to_s
    item_id = item_data.id rescue nil
    runtime_symbol = imported_item_runtime_symbol(expansion, raw)
    return true if item_id && runtime_symbol && item_id == runtime_symbol
    metadata = item_data.instance_variable_get(:@travel_expansion_item_metadata) rescue nil
    return false if !metadata.is_a?(Hash)
    metadata_expansion = imported_item_metadata_value(metadata, :expansion_id).to_s
    metadata_raw = imported_item_metadata_value(metadata, :raw_name).to_s
    return metadata_expansion == expansion && normalized_imported_item_name(metadata_raw) == normalized_imported_item_name(raw)
  rescue
    return false
  end

  def imported_item_numeric_alias_cache
    @imported_item_numeric_alias_cache ||= {}
  end

  def canonical_imported_item_numeric_raw_alias(expansion_id, raw_name)
    expansion = expansion_id.to_s
    text = raw_name.to_s.strip.gsub(/\A:/, "")
    return nil if expansion.empty? || text !~ /\A\d+\z/
    target = text.to_i
    return nil if target <= 0
    cache_key = "#{expansion}:#{target}"
    cached = imported_item_numeric_alias_cache[cache_key]
    return nil if cached == false
    return cached if cached

    catalog = generic_pbs_item_catalog(expansion)
    if catalog.is_a?(Hash) && !catalog.empty?
      catalog.each_value do |entry|
        next if !entry.is_a?(Hash)
        candidate_raw = (entry[:raw_name] || entry["raw_name"]).to_s
        next if candidate_raw.empty? || candidate_raw == text
        native_id = integer(entry[:native_id_number] || entry["native_id_number"] || entry[:id_number] || entry["id_number"], 0)
        id_number = imported_item_id_number_for_raw_name(expansion, candidate_raw)
        if native_id.to_i == target || id_number.to_i == target
          imported_item_numeric_alias_cache[cache_key] = candidate_raw
          return candidate_raw
        end
      end
    end

    imported_item_numeric_alias_cache[cache_key] = false
    return nil
  rescue => e
    log("Imported numeric item alias lookup failed for #{expansion_id}/#{raw_name}: #{e.class}: #{e.message}") if respond_to?(:log)
    imported_item_numeric_alias_cache[cache_key] = false if defined?(cache_key) && cache_key
    return nil
  end

  def imported_item_handler_registry
    @imported_item_handler_registry ||= {}
  end

  def imported_runtime_items
    @imported_runtime_items ||= {}
  end

  def imported_runtime_item_lookup
    @imported_runtime_item_lookup ||= {}
  end

  def imported_item_origin_cache
    @imported_item_origin_cache ||= {}
  end

  def normalized_imported_item_name(value)
    return value.to_s.strip.gsub(/\A:/, "").upcase.gsub(/[^\w]+/, "")
  rescue
    return ""
  end

  def remember_imported_item_origin(metadata)
    return if !metadata.is_a?(Hash)
    normalized = normalized_imported_item_name(imported_item_metadata_value(metadata, :raw_name))
    expansion = imported_item_metadata_value(metadata, :expansion_id).to_s
    return if normalized.empty? || expansion.empty?
    imported_item_origin_cache[normalized] = expansion
  rescue
  end

  def item_icon_filename_cache
    @item_icon_filename_cache ||= {}
  end

  def held_item_icon_filename_cache
    @held_item_icon_filename_cache ||= {}
  end

  def imported_item_icon_path_cache
    @imported_item_icon_path_cache ||= {}
  end

  def clear_item_icon_filename_cache!
    @item_icon_filename_cache = {}
    @held_item_icon_filename_cache = {}
    @imported_item_icon_path_cache = {}
  end

  def imported_item_metadata_guard_depth
    @imported_item_metadata_guard_depth ||= 0
  end

  def with_imported_item_metadata_guard
    @imported_item_metadata_guard_depth = imported_item_metadata_guard_depth + 1
    return yield
  ensure
    @imported_item_metadata_guard_depth = [imported_item_metadata_guard_depth - 1, 0].max
  end

  def imported_item_registration_stack
    @imported_item_registration_stack ||= {}
  end

  def imported_item_runtime_symbol?(value)
    return false if value.nil?
    identifier = value.is_a?(GameData::Item) ? value.id : value
    text = identifier.to_s.strip
    return false if text.empty?
    return text.start_with?("TEF_")
  rescue
    return false
  end

  def raw_item_data(item)
    return item if item.is_a?(GameData::Item)
    return nil if !defined?(GameData::Item::DATA) || !GameData::Item::DATA.is_a?(Hash)
    query = item
    query = query.to_sym if query.is_a?(String)
    return GameData::Item::DATA[query]
  rescue
    return nil
  end

  def attach_imported_item_metadata(item_data, metadata)
    return if item_data.nil? || !item_data.is_a?(GameData::Item) || !metadata.is_a?(Hash)
    item_data.instance_variable_set(:@travel_expansion_item_metadata, metadata)
  rescue
  end

  def imported_item_metadata_value(metadata, key)
    return nil if !metadata.is_a?(Hash)
    return metadata[key] if metadata.has_key?(key)
    return metadata[key.to_s] if metadata.has_key?(key.to_s)
    return nil
  rescue
    return nil
  end

  def canonical_imported_item_metadata(metadata)
    return nil if !metadata.is_a?(Hash)
    return metadata if imported_item_metadata_guard_depth > 2
    with_imported_item_metadata_guard do
      runtime_symbol = imported_item_metadata_value(metadata, :runtime_symbol)
      raw_name = imported_item_metadata_value(metadata, :raw_name)
      canonical = canonical_imported_item_reference(runtime_symbol)
      canonical = canonical_imported_item_reference(raw_name) if canonical.nil?
      return metadata if canonical.nil?

      canonical_expansion = canonical[0].to_s
      canonical_raw = canonical[1].to_s
      alias_raw = canonical_imported_item_numeric_raw_alias(canonical_expansion, canonical_raw)
      canonical_raw = alias_raw if alias_raw
      return metadata if canonical_expansion.empty? || canonical_raw.empty?

      current_expansion = imported_item_metadata_value(metadata, :expansion_id).to_s
      current_raw = imported_item_metadata_value(metadata, :raw_name).to_s
      return metadata if current_expansion == canonical_expansion && current_raw == canonical_raw

      imported = ensure_external_item_registered(canonical_expansion, canonical_raw)
      canonical_metadata = nil
      canonical_item = raw_item_data(imported) if imported
      canonical_metadata = canonical_item.instance_variable_get(:@travel_expansion_item_metadata) rescue nil
      canonical_metadata ||= imported_runtime_item_lookup[imported] if imported
      canonical_metadata ||= imported_runtime_item_lookup[imported.to_s] if imported
      canonical_metadata ||= metadata.merge({
        :runtime_symbol => imported_item_runtime_symbol(canonical_expansion, canonical_raw),
        :raw_name       => canonical_raw,
        :expansion_id   => canonical_expansion
      })
      remember_imported_item_origin(canonical_metadata)

      alias_keys = []
      alias_keys << runtime_symbol
      alias_keys << runtime_symbol.to_s if runtime_symbol
      alias_keys << raw_name
      alias_keys << raw_name.to_s if raw_name
      id_number = imported_item_metadata_value(metadata, :id_number)
      alias_keys << id_number
      alias_keys << id_number.to_s if id_number
      alias_keys.compact.uniq.each do |key|
        imported_runtime_item_lookup[key] = canonical_metadata
      end

      alias_item = raw_item_data(runtime_symbol) if runtime_symbol
      attach_imported_item_metadata(alias_item, canonical_metadata) if alias_item
      register_imported_item_handlers(runtime_symbol, canonical_metadata) if runtime_symbol
      return canonical_metadata
    end
  rescue => e
    log("Imported item metadata canonicalization failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return metadata
  end

  def canonical_imported_item_alias_target(item)
    item_data = raw_item_data(item)
    metadata = direct_imported_item_metadata(item_data || item, false)
    expansion = imported_item_metadata_value(metadata, :expansion_id).to_s if metadata
    raw = imported_item_metadata_value(metadata, :raw_name).to_s if metadata
    if expansion.to_s.empty?
      canonical = canonical_imported_item_reference(item_data ? (item_data.id rescue nil) : item)
      expansion = canonical[0].to_s if canonical
      raw = canonical[1].to_s if canonical && raw.to_s.empty?
    end
    alias_raw = canonical_imported_item_numeric_raw_alias(expansion, raw)
    return nil if alias_raw.nil? || alias_raw.empty?
    resolved = ensure_external_item_registered(expansion, alias_raw)
    return nil if resolved.nil?
    current_id = item_data ? (item_data.id rescue nil) : item
    return nil if current_id == resolved
    return resolved
  rescue => e
    log("Imported item alias target lookup failed for #{item.inspect}: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def repair_imported_item_pocket_layout!
    return false if !defined?($PokemonBag) || !$PokemonBag
    pockets = $PokemonBag.instance_variable_get(:@pockets) rescue nil
    return false if !pockets.respond_to?(:each_with_index)
    new_pockets = []
    0.upto(PokemonBag.numPockets) { |index| new_pockets[index] = [] } if defined?(PokemonBag)
    return false if new_pockets.empty?
    moved = false
    pockets.each_with_index do |pocket, pocket_index|
      next if !pocket.respond_to?(:each)
      pocket.each do |slot|
        next if !slot || !slot.respond_to?(:[])
        item_data = GameData::Item.try_get(slot[0]) rescue nil
        target_pocket = item_data && item_data.respond_to?(:pocket) ? item_data.pocket.to_i : pocket_index
        target_pocket = pocket_index if target_pocket <= 0 || target_pocket >= new_pockets.length
        moved = true if target_pocket != pocket_index
        existing = new_pockets[target_pocket].find { |entry| entry && entry[0] == slot[0] }
        if existing
          existing[1] = existing[1].to_i + slot[1].to_i
          moved = true
        else
          new_pockets[target_pocket] << slot
        end
      end
    end
    $PokemonBag.instance_variable_set(:@pockets, new_pockets) if moved
    return moved
  rescue => e
    log("Imported item pocket layout repair failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def repair_imported_item_aliases!
    return false if @repair_imported_item_aliases_guard
    @repair_imported_item_aliases_guard = true
    changed = false

    if respond_to?(:each_raw_bag_item_slot)
      each_raw_bag_item_slot do |_pocket, _pocket_index, _slot_index, slot|
        target = canonical_imported_item_alias_target(slot[0])
        next if target.nil?
        old = slot[0]
        slot[0] = target
        changed = true
        log("[items] repaired imported bag item #{old.inspect} -> #{target.inspect}") if respond_to?(:log)
      end
    end

    if defined?($PokemonBag) && $PokemonBag
      registered = $PokemonBag.instance_variable_get(:@registeredItems) rescue nil
      if registered.respond_to?(:each_with_index)
        registered.each_with_index do |item, index|
          target = canonical_imported_item_alias_target(item)
          next if target.nil?
          registered[index] = target
          changed = true
        end
        registered.compact! if registered.respond_to?(:compact!)
      end
      changed = true if repair_imported_item_pocket_layout!
    end

    if respond_to?(:each_pc_item_slot)
      each_pc_item_slot do |_items, _slot_index, slot|
        target = canonical_imported_item_alias_target(slot[0])
        next if target.nil?
        old = slot[0]
        slot[0] = target
        changed = true
        log("[items] repaired imported PC item #{old.inspect} -> #{target.inspect}") if respond_to?(:log)
      end
    end

    return changed
  rescue => e
    log("Imported item alias repair failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  ensure
    @repair_imported_item_aliases_guard = false
  end

  def imported_item_lookup_key(item)
    return nil if item.nil?
    if item.is_a?(GameData::Item)
      metadata = item.instance_variable_get(:@travel_expansion_item_metadata) rescue nil
      return metadata[:runtime_symbol] if metadata.is_a?(Hash) && metadata[:runtime_symbol]
      return item.id
    end
    query = item
    query = query.to_sym if query.is_a?(String)
    return query
  rescue
    return nil
  end

  def item_icon_cache_key(item, item_data = nil)
    data = item_data || raw_item_data(item)
    if data
      id = data.id rescue nil
      id_number = data.id_number rescue nil
      return "#{id}:#{id_number}" if id || id_number
    end
    lookup_key = imported_item_lookup_key(item)
    return lookup_key.to_s if lookup_key
    return item.to_s
  rescue
    return item.to_s
  end

  def direct_imported_item_metadata(item, allow_registration = true)
    return nil if item.nil?
    keys = []
    if item.is_a?(GameData::Item)
      item_id = item.id rescue nil
      item_number = item.id_number rescue nil
      keys << item
      keys << item_id
      keys << item_id.to_s if item_id
      keys << item_number
      keys << item_number.to_s if item_number
      attached = item.instance_variable_get(:@travel_expansion_item_metadata) rescue nil
      return canonical_imported_item_metadata(attached) if attached.is_a?(Hash)
    else
      keys << item
      if item.is_a?(String)
        keys << item.to_sym rescue nil
      elsif item.is_a?(Symbol)
        keys << item.to_s
      elsif item.is_a?(Integer)
        keys << item.to_s
      end
    end
    keys.compact.each do |key|
      metadata = imported_runtime_item_lookup[key]
      return canonical_imported_item_metadata(metadata) if metadata.is_a?(Hash)
    end
    return nil if !allow_registration

    identifier = item.is_a?(GameData::Item) ? (item.id rescue nil) : item
    expansion_id = inferred_item_expansion_id(identifier)
    return nil if expansion_id.nil? || expansion_id.to_s.empty?
    imported = ensure_external_item_registered(expansion_id, identifier)
    return nil if imported.nil?

    registered_item = raw_item_data(imported)
    post_keys = [imported, imported.to_s]
    if registered_item
      post_keys << registered_item
      post_keys << (registered_item.id rescue nil)
      post_keys << ((registered_item.id rescue nil).to_s rescue nil)
      post_keys << (registered_item.id_number rescue nil)
      post_keys << ((registered_item.id_number rescue nil).to_s rescue nil)
    end
    post_keys.compact.each do |key|
      metadata = imported_runtime_item_lookup[key]
      return canonical_imported_item_metadata(metadata) if metadata.is_a?(Hash)
    end
    return nil
  rescue
    return nil
  end

  def imported_item_metadata(item)
    return direct_imported_item_metadata(item, true)
  rescue
    return nil
  end

  def imported_runtime_item?(item)
    key = imported_item_lookup_key(item)
    return false if key.nil?
    return imported_runtime_item_lookup.has_key?(key)
  rescue
    return false
  end

  def imported_item_plural(name)
    text = name.to_s.strip
    return "Imported Items" if text.empty?
    return text if text.end_with?("s")
    return text.sub(/y\z/i, "ies") if text =~ /[^aeiou]y\z/i
    return "#{text}es" if text =~ /(s|x|z|ch|sh)\z/i
    return "#{text}s"
  end

  def normalize_imported_item_text(text)
    value = text.to_s.dup
    replacements = {
      "\\n"       => "\n",
      "\\\""      => "\"",
      "\\'"       => "'",
      "PokÃ©mon"   => "Pokemon",
      "Ã©"        => "e",
      "â€™"       => "'",
      "â€œ"       => "\"",
      "â€\x9d"    => "\"",
      "â€“"       => "-",
      "â€”"       => "-",
      "Ã—"        => "x"
    }
    replacements.each { |bad, good| value.gsub!(bad, good) }
    return value
  rescue
    return text.to_s
  end

  def reborn_item_catalog
    return @reborn_item_catalog if @reborn_item_catalog
    @reborn_item_catalog = parse_reborn_item_catalog
    return @reborn_item_catalog
  end

  def reborn_item_catalog_source_path
    info = external_projects["reborn"] if respond_to?(:external_projects)
    roots = []
    if info.is_a?(Hash)
      roots << info[:root]
      roots << info[:filesystem_bridge_root]
      roots << info[:source_mount_root]
      roots << info[:archive_mount_root]
    end
    roots << linked_project_bridge_root("reborn") if respond_to?(:linked_project_bridge_root)
    roots.compact.each do |root|
      next if root.to_s.empty?
      candidate = runtime_exact_file_path(File.join(root.to_s, "Scripts", "Reborn", "itemtext.rb")) if respond_to?(:runtime_exact_file_path)
      return candidate if candidate && File.file?(candidate)
    end
    return nil
  rescue
    return nil
  end

  def parse_reborn_item_value(raw_value)
    value = raw_value.to_s.strip
    value = value.sub(/,\s*\z/, "").strip
    return true if value == "true"
    return false if value == "false"
    return value.to_i if value =~ /\A-?\d+\z/
    return Regexp.last_match(1).to_sym if value =~ /\A:(\w+)\z/
    if (value.start_with?("\"") && value.end_with?("\"")) || (value.start_with?("'") && value.end_with?("'"))
      value = value[1...-1]
    end
    return normalize_imported_item_text(value)
  end

  def parse_reborn_item_catalog
    catalog = {}
    source_path = reborn_item_catalog_source_path
    if source_path && File.file?(source_path)
      current_key = nil
      current_data = nil
      File.foreach(source_path) do |line|
        if current_data.nil?
          next if line !~ /^\s*:(\w+)\s*=>\s*\{\s*$/
          current_key = Regexp.last_match(1).upcase
          current_data = {}
          next
        end
        stripped = line.strip
        if stripped == "}," || stripped == "}"
          catalog[current_key] = current_data
          current_key = nil
          current_data = nil
          next
        end
        next if stripped.empty? || stripped.start_with?("#")
        next if stripped !~ /\A:(\w+)\s*=>\s*(.+)\z/
        current_data[Regexp.last_match(1).to_sym] = parse_reborn_item_value(Regexp.last_match(2))
      end
    end
    REBORN_MANUAL_ITEM_DATA.each do |key, data|
      catalog[key] ||= {}
      catalog[key] = catalog[key].merge(data)
    end
    return catalog
  rescue => e
    log("Reborn item catalog parse failed: #{e.class}: #{e.message}")
    return REBORN_MANUAL_ITEM_DATA.dup
  end

  def generic_pbs_item_catalog(expansion_id)
    @generic_pbs_item_catalogs ||= {}
    expansion = expansion_id.to_s
    return {} if expansion.empty? || expansion == "reborn"
    return @generic_pbs_item_catalogs[expansion] if @generic_pbs_item_catalogs.has_key?(expansion)
    catalog = {}
    generic_pbs_item_catalog_source_paths(expansion).each do |source_path|
      parsed = parse_generic_pbs_item_catalog(source_path)
      catalog.merge!(parsed) if parsed.is_a?(Hash)
    end
    catalog = generic_dat_item_catalog(expansion) if catalog.empty?
    @generic_pbs_item_catalogs[expansion] = catalog
    return @generic_pbs_item_catalogs[expansion]
  rescue => e
    log("Generic PBS item catalog lookup failed for #{expansion_id}: #{e.class}: #{e.message}") if respond_to?(:log)
    return {}
  end

  def generic_pbs_item_catalog_source_path(expansion_id)
    expansion = expansion_id.to_s
    return nil if expansion.empty?
    info = external_projects[expansion] if respond_to?(:external_projects)
    roots = []
    if info.is_a?(Hash)
      roots << (info[:root] || info["root"])
      roots << (info[:filesystem_bridge_root] || info["filesystem_bridge_root"])
      roots << (info[:source_mount_root] || info["source_mount_root"])
      roots << (info[:archive_mount_root] || info["archive_mount_root"])
    end
    roots << linked_project_bridge_root(expansion) if respond_to?(:linked_project_bridge_root)
    if expansion == "pokemon_keishou"
      roots << linked_project_bridge_root("keishou") if respond_to?(:linked_project_bridge_root)
      roots << File.expand_path("C:/Games/PIF/ExpansionLibrary/LinkedProjects/keishou")
    end
    roots.compact.map { |root| root.to_s }.reject { |root| root.empty? }.uniq.each do |root|
      candidate = runtime_exact_file_path(File.join(root, "PBS", "items.txt")) if respond_to?(:runtime_exact_file_path)
      return candidate if candidate && File.file?(candidate)
    end
    return nil
  rescue
    return nil
  end

  def generic_pbs_item_catalog_source_paths(expansion_id)
    first = generic_pbs_item_catalog_source_path(expansion_id)
    return [] if first.nil? || !File.file?(first)
    directory = File.dirname(first)
    paths = Dir[File.join(directory, "items*.txt")].sort
    paths = [first] if paths.empty?
    paths.map do |candidate|
      exact = runtime_exact_file_path(candidate) if respond_to?(:runtime_exact_file_path)
      exact ||= candidate
      exact
    end.compact.select { |candidate| File.file?(candidate) }.uniq
  rescue
    return []
  end

  def generic_dat_item_catalog(expansion_id)
    source_path = generic_dat_item_catalog_source_path(expansion_id)
    return parse_generic_dat_item_catalog(source_path)
  rescue => e
    log("Generic compiled item catalog lookup failed for #{expansion_id}: #{e.class}: #{e.message}") if respond_to?(:log)
    return {}
  end

  def generic_dat_item_catalog_source_path(expansion_id)
    expansion = expansion_id.to_s
    return nil if expansion.empty?
    info = external_projects[expansion] if respond_to?(:external_projects)
    roots = []
    if info.is_a?(Hash)
      roots << (info[:data_root] || info["data_root"])
      roots << (info[:prepared_data_root] || info["prepared_data_root"])
      roots << (info[:root] || info["root"])
      roots << (info[:filesystem_bridge_root] || info["filesystem_bridge_root"])
      roots << (info[:source_mount_root] || info["source_mount_root"])
      roots << (info[:archive_mount_root] || info["archive_mount_root"])
    end
    roots << linked_project_bridge_root(expansion) if respond_to?(:linked_project_bridge_root)
    roots.compact.map { |root| root.to_s }.reject { |root| root.empty? }.uniq.each do |root|
      candidates = [
        File.join(root, "items.dat"),
        File.join(root, "Data", "items.dat")
      ]
      candidates.each do |candidate|
        exact = runtime_exact_file_path(candidate) if respond_to?(:runtime_exact_file_path)
        exact ||= candidate
        return exact if exact && File.file?(exact)
      end
    end
    return nil
  rescue
    return nil
  end

  def generic_dat_item_ivar(object, *names)
    return nil if object.nil?
    names.each do |name|
      ivar = name.to_s.start_with?("@") ? name.to_s : "@#{name}"
      return object.instance_variable_get(ivar) if object.instance_variable_defined?(ivar)
    end
    return nil
  rescue
    return nil
  end

  def parse_generic_dat_item_catalog(source_path)
    catalog = {}
    return catalog if source_path.nil? || !File.file?(source_path)
    raw_items = Marshal.load(File.binread(source_path))
    entries = raw_items.is_a?(Hash) ? raw_items.values : Array(raw_items)
    entries.each do |entry|
      raw_id = generic_dat_item_ivar(entry, :id)
      normalized = normalized_imported_item_name(raw_id)
      next if normalized.empty?
      catalog[normalized] = {
        :raw_name    => raw_id.to_s,
        :name        => generic_dat_item_ivar(entry, :real_name, :name),
        :nameplural  => generic_dat_item_ivar(entry, :real_name_plural, :name_plural),
        :description => generic_dat_item_ivar(entry, :real_description, :description),
        :price       => generic_dat_item_ivar(entry, :price),
        :pocket      => generic_dat_item_ivar(entry, :pocket),
        :fielduse    => generic_dat_item_ivar(entry, :field_use, :fielduse),
        :battleuse   => generic_dat_item_ivar(entry, :battle_use, :battleuse),
        :flags       => generic_dat_item_ivar(entry, :flags),
        :move        => generic_dat_item_ivar(entry, :move)
      }
    end
    return catalog
  rescue => e
    log("Generic compiled item catalog parse failed for #{source_path}: #{e.class}: #{e.message}") if respond_to?(:log)
    return {}
  end

  def parse_legacy_pbs_csv_fields(line)
    fields = []
    field = +""
    quoted = false
    index = 0
    text = line.to_s
    while index < text.length
      char = text[index]
      if quoted
        if char == "\""
          if text[index + 1] == "\""
            field << "\""
            index += 1
          else
            quoted = false
          end
        else
          field << char
        end
      elsif char == "\""
        quoted = true
      elsif char == ","
        fields << field.strip
        field = +""
      else
        field << char
      end
      index += 1
    end
    fields << field.strip
    return fields
  rescue
    return line.to_s.split(",").map { |value| value.to_s.strip }
  end

  def parse_legacy_pbs_item_line(line)
    fields = parse_legacy_pbs_csv_fields(line)
    return nil if fields.length < 7
    native_id = integer(fields[0], 0)
    raw_name = fields[1].to_s.strip
    return nil if raw_name.empty?
    entry = {
      :source_format     => :legacy_csv,
      :id_number         => native_id,
      :native_id_number  => native_id,
      :raw_name          => raw_name,
      :name              => normalize_imported_item_text(fields[2]),
      :nameplural        => normalize_imported_item_text(fields[3]),
      :pocket            => integer(fields[4], 1),
      :price             => integer(fields[5], 0),
      :description       => normalize_imported_item_text(fields[6]),
      :fielduse          => integer(fields[7], 0),
      :battleuse         => integer(fields[8], 0),
      :type              => integer(fields[9], 0),
      :move              => fields[10].to_s.strip,
      :icon_logical_path => nil
    }
    entry[:icon_logical_path] = "Graphics/Icons/item#{native_id}" if native_id > 0
    flags = fields[11..-1] || []
    entry[:flags] = flags.map { |flag| flag.to_s.strip }.reject { |flag| flag.empty? }
    return entry
  rescue => e
    log("Legacy PBS item line parse failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def parse_generic_pbs_item_catalog(source_path)
    catalog = {}
    return catalog if source_path.nil? || !File.file?(source_path)
    current_key = nil
    current_data = nil
    File.foreach(source_path) do |line|
      stripped = line.to_s.strip
      next if stripped.empty? || stripped.start_with?("#")
      if stripped =~ /\A-?\d+\s*,/
        entry = parse_legacy_pbs_item_line(stripped)
        if entry
          key = normalized_imported_item_name(entry[:raw_name])
          catalog[key] = entry if !key.empty?
        end
        current_key = nil
        current_data = nil
        next
      end
      if stripped =~ /\A\[(.+?)\]\z/
        current_key = normalized_imported_item_name(Regexp.last_match(1))
        current_data = { :raw_name => Regexp.last_match(1).to_s.strip }
        catalog[current_key] = current_data if !current_key.empty?
        next
      end
      next if current_data.nil?
      next if stripped !~ /\A([^=]+?)\s*=\s*(.*)\z/
      raw_key = Regexp.last_match(1).to_s
      raw_value = Regexp.last_match(2)
      key = raw_key.strip.downcase.gsub(/\s+/, "_").to_sym
      current_data[key] = parse_generic_pbs_item_value(raw_value)
    end
    return catalog
  rescue => e
    log("Generic PBS item catalog parse failed for #{source_path}: #{e.class}: #{e.message}") if respond_to?(:log)
    return {}
  end

  def parse_generic_pbs_item_value(raw_value)
    value = raw_value.to_s.strip
    value = value.to_i if value =~ /\A-?\d+\z/
    return value if value.is_a?(Integer)
    return true if value.downcase == "true"
    return false if value.downcase == "false"
    if (value.start_with?("\"") && value.end_with?("\"")) || (value.start_with?("'") && value.end_with?("'"))
      value = value[1...-1]
    end
    return normalize_imported_item_text(value)
  rescue
    return raw_value.to_s
  end

  def ensure_ordered_hash_loader_for_imported_messages
    return if defined?(::OrderedHash)
    klass = Class.new(Hash) do
      def initialize
        @keys = []
        super
      end

      def []=(key, value)
        @keys ||= []
        @keys << key if !has_key?(key)
        super(key, value)
      end

      def keys
        return @keys || super
      end

      def self._load(string)
        result = new
        keysvalues = Marshal.load(string) rescue [[], []]
        keys = keysvalues[0] || []
        values = keysvalues[1] || []
        keys.each_with_index { |key, index| result[key] = values[index] }
        return result
      end
    end
    Object.const_set(:OrderedHash, klass)
  rescue
  end

  def generic_item_translation_source_path(expansion_id)
    expansion = expansion_id.to_s
    return nil if expansion.empty?
    info = external_projects[expansion] if respond_to?(:external_projects)
    roots = []
    if info.is_a?(Hash)
      roots << (info[:data_root] || info["data_root"])
      roots << (info[:prepared_data_root] || info["prepared_data_root"])
      roots << (info[:root] || info["root"])
      roots << (info[:filesystem_bridge_root] || info["filesystem_bridge_root"])
      roots << (info[:source_mount_root] || info["source_mount_root"])
      roots << (info[:archive_mount_root] || info["archive_mount_root"])
    end
    roots << linked_project_bridge_root(expansion) if respond_to?(:linked_project_bridge_root)
    roots.compact.map { |root| root.to_s }.reject { |root| root.empty? }.uniq.each do |root|
      candidate = runtime_exact_file_path(File.join(root, "Data", "english.dat")) if respond_to?(:runtime_exact_file_path)
      candidate ||= File.join(root, "Data", "english.dat")
      return candidate if candidate && File.file?(candidate)
    end
    return nil
  rescue
    return nil
  end

  def collect_generic_item_translation_strings(value, strings, depth = 0)
    return if depth > 4 || value.nil?
    if value.is_a?(Hash)
      value.each do |source, translated|
        strings[source.to_s] = translated.to_s if source.is_a?(String) && translated.is_a?(String) && source != translated
        collect_generic_item_translation_strings(translated, strings, depth + 1) if !translated.is_a?(String)
      end
    elsif value.is_a?(Array)
      value.each { |entry| collect_generic_item_translation_strings(entry, strings, depth + 1) }
    end
  rescue
  end

  def generic_item_translation_catalog(expansion_id)
    @generic_item_translation_catalogs ||= {}
    expansion = expansion_id.to_s
    return {} if expansion.empty?
    return @generic_item_translation_catalogs[expansion] if @generic_item_translation_catalogs.has_key?(expansion)
    catalog = {
      :strings           => {},
      :item_names        => nil,
      :item_name_plurals => nil,
      :item_descriptions => nil
    }
    source_path = generic_item_translation_source_path(expansion)
    if source_path && File.file?(source_path)
      ensure_ordered_hash_loader_for_imported_messages
      data = Marshal.load(File.binread(source_path))
      if data.is_a?(Array)
        catalog[:item_names] = data[7] if data[7].is_a?(Array)
        catalog[:item_name_plurals] = data[8] if data[8].is_a?(Array)
        catalog[:item_descriptions] = data[9] if data[9].is_a?(Array)
      end
      if catalog[:item_names].nil? && catalog[:item_name_plurals].nil? && catalog[:item_descriptions].nil?
        collect_generic_item_translation_strings(data, catalog[:strings])
      end
    end
    @generic_item_translation_catalogs[expansion] = catalog
    return catalog
  rescue => e
    log("Generic item translation catalog failed for #{expansion_id}: #{e.class}: #{e.message}") if respond_to?(:log)
    @generic_item_translation_catalogs[expansion] = {}
    return {}
  end

  def generic_item_translation_value(expansion_id, native_id, kind, fallback)
    catalog = generic_item_translation_catalog(expansion_id)
    value = nil
    index = integer(native_id, 0)
    array_key = case kind
                when :name then :item_names
                when :plural then :item_name_plurals
                when :description then :item_descriptions
                else nil
                end
    values = catalog[array_key] if array_key
    value = values[index] if index > 0 && values.is_a?(Array) && index < values.length
    value = catalog[:strings][fallback.to_s] if (value.nil? || value.to_s.empty?) &&
                                                catalog[:strings].is_a?(Hash) &&
                                                catalog[:strings].has_key?(fallback.to_s)
    value = fallback if value.nil? || value.to_s.empty?
    return normalize_imported_item_text(value)
  rescue
    return normalize_imported_item_text(fallback)
  end

  def generic_pbs_item_flags(entry)
    flags = entry[:flags] if entry.is_a?(Hash)
    return [] if flags.nil?
    return flags if flags.is_a?(Array)
    return flags.to_s.split(",").map { |flag| flag.strip }.reject { |flag| flag.empty? }
  rescue
    return []
  end

  def generic_pbs_item_field_use(value)
    raw = value.to_s.strip.downcase
    return 0 if raw.empty? || raw == "none" || raw == "no_use" || raw == "nouse"
    return 1 if raw == "onpokemon" || raw == "on_pokemon"
    return 2 if raw == "direct" || raw == "frombag" || raw == "from_bag"
    return integer(value, 0)
  rescue
    return 0
  end

  def generic_pbs_item_battle_use(value)
    raw = value.to_s.strip.downcase
    return 0 if raw.empty? || raw == "none" || raw == "no_use" || raw == "nouse"
    return 1 if raw == "onpokemon" || raw == "on_pokemon"
    return 2 if raw == "direct" || raw == "frombag" || raw == "from_bag"
    return 3 if raw == "onmove" || raw == "on_move"
    return integer(value, 0)
  rescue
    return 0
  end

  def external_mint_nature_for(normalized_name)
    nature_id = EXTERNAL_NATURE_MINTS[normalized_name.to_s]
    return nil if nature_id.nil?
    return nil if defined?(GameData::Nature) && !GameData::Nature.exists?(nature_id)
    return nature_id
  rescue
    return nil
  end

  def external_iv_capsule_stat_for(normalized_name, display_name = nil, description = nil)
    normalized = normalized_name.to_s
    stat_id = EXTERNAL_IV_CAPSULE_STATS[normalized]
    return stat_id if stat_id

    text = "#{normalized} #{display_name} #{description}".downcase
    return nil if text !~ /(capsule|capsula|chapa|iv)/
    return :SPECIAL_ATTACK if text =~ /(special attack|sp\.?\s*attack|spatk|at\.?\s*esp|ataque especial)/
    return :SPECIAL_DEFENSE if text =~ /(special defense|sp\.?\s*defense|spdef|def\.?\s*esp|defensa especial)/
    return :HP if text =~ /(\bhp\b|\bps\b|health|vigor|vital)/
    return :ATTACK if text =~ /(\battack\b|ataque|muscle|power|strong|fuerte)/
    return :DEFENSE if text =~ /(\bdefense\b|defensa|resist|robust|robusta)/
    return :SPEED if text =~ /(\bspeed\b|velocidad|swift|impetu)/
    return nil
  rescue
    return nil
  end

  def external_native_delegate_for(normalized_name)
    native_item = EXTERNAL_NATIVE_ITEM_DELEGATES[normalized_name.to_s]
    return nil if native_item.nil?
    native_data = base_item_try_get(native_item)
    return native_data ? native_data.id : nil
  rescue
    return nil
  end

  def imported_item_expansion_matches?(expansion_id, candidates)
    values = [expansion_id.to_s]
    values << canonical_new_project_id(expansion_id) if respond_to?(:canonical_new_project_id)
    values.compact.map { |value| value.to_s }.any? { |value| candidates.include?(value) }
  rescue
    return candidates.include?(expansion_id.to_s)
  end

  def anil_item_metadata_definition(raw_name)
    normalized = normalized_imported_item_name(raw_name)
    return nil if !["ROCKSMASHITEM", "ROCKSMASH", "ROCKSMASHKEY", "PICO", "PICKAXE"].include?(normalized)
    return {
      :name              => "Pickaxe",
      :name_plural       => "Pickaxes",
      :description       => "A sturdy tool that breaks small cracked rocks.",
      :price             => 0,
      :pocket            => 8,
      :type              => 6,
      :field_use         => 2,
      :battle_use        => 0,
      :handler_kind      => :external_rock_smash,
      :use_message       => "This can break small cracked rocks.",
      :native_id_number  => 0,
      :icon_logical_path => "Graphics/Items/ROCKSMASHITEM"
    }
  end

  def rejuvenation_item_metadata_definition(raw_name)
    normalized = normalized_imported_item_name(raw_name)
    return nil if normalized != "STEAMBALL"
    return {
      :name              => "Steam Ball",
      :name_plural       => "Steam Balls",
      :description       => "A somewhat different Poke Ball that works especially well on Water- and Fire-type Pokemon.",
      :price             => 1200,
      :pocket            => 3,
      :type              => 3,
      :field_use         => 0,
      :battle_use        => 3,
      :handler_kind      => :external_steam_ball,
      :native_id_number  => 665,
      :icon_logical_path => "Graphics/Icons/steamball"
    }
  end

  def insurgence_item_metadata_definition(raw_name)
    normalized = normalized_imported_item_name(raw_name)
    return nil if normalized != "QUARTZFLUTE"
    return {
      :name              => "Quartz Flute",
      :name_plural       => "Quartz Flutes",
      :description       => "A clear flute that calls Mew while exploring.",
      :price             => 0,
      :pocket            => 8,
      :type              => 6,
      :field_use         => 2,
      :battle_use        => 0,
      :handler_kind      => :external_quartz_flute,
      :use_message       => "A clear note rings out.",
      :native_id_number  => 0,
      :icon_logical_path => "Graphics/Icons/item858"
    }
  end

  def generic_pbs_item_definition(expansion_id, raw_name)
    catalog = generic_pbs_item_catalog(expansion_id)
    normalized = normalized_imported_item_name(raw_name)
    entry = catalog[normalized] || {}
    return nil if entry.empty?
    flags = generic_pbs_item_flags(entry).map { |flag| flag.to_s.downcase }
    native_id = integer(entry[:native_id_number] || entry[:id_number], 0)
    display_name = normalize_imported_item_text(entry[:name] || humanize_external_item_name(raw_name))
    display_plural = normalize_imported_item_text(entry[:nameplural] || entry[:name_plural] || imported_item_plural(display_name))
    description = normalize_imported_item_text(entry[:description] || _INTL("{1} imported from {2}.", display_name, imported_item_display_name(expansion_id)))
    display_name = generic_item_translation_value(expansion_id, native_id, :name, display_name)
    display_plural = generic_item_translation_value(expansion_id, native_id, :plural, display_plural)
    description = generic_item_translation_value(expansion_id, native_id, :description, description)
    if respond_to?(:anil_expansion_id?) && anil_expansion_id?(expansion_id) && respond_to?(:anil_translate_text)
      display_name = normalize_imported_item_text(anil_translate_text(display_name))
      display_plural = normalize_imported_item_text(anil_translate_text(display_plural))
      description = normalize_imported_item_text(anil_translate_text(description))
    end
    pocket = integer(entry[:pocket], 1)
    item_type = integer(entry[:type], 0)
    field_use = generic_pbs_item_field_use(entry[:fielduse] || entry[:field_use])
    battle_use = generic_pbs_item_battle_use(entry[:battleuse] || entry[:battle_use])
    move = entry[:move].to_s.strip
    move = nil if move.empty?
    move = move.to_sym if move

    is_ball = flags.include?("pokeball") || normalized.end_with?("BALL")
    is_berry = flags.include?("berry") || normalized.end_with?("BERRY")
    is_key_item = flags.include?("keyitem") || flags.include?("key_item") || pocket == 8
    is_mail = flags.include?("mail")

    if is_key_item
      pocket = 8
      item_type = 6
    elsif is_berry
      pocket = 5
      item_type = 5
    elsif is_ball
      pocket = 3
      item_type = 3
    elsif is_mail
      pocket = 6
      item_type = 1
    elsif flags.include?("fossil")
      item_type = 8
    elsif flags.include?("megastone") || flags.include?("mega_stone")
      item_type = 12
    end

    handler_kind = nil
    use_message = nil
    native_item = nil
    battle_delegate = nil
    nature_id = nil
    stat_id = nil
    iv_amount = nil
    allow_hidden_abilities = false
    ability_scope = nil
    if field_use == 2 && is_key_item
      handler_kind = :generic_item_info
      use_message = description
    end

    detected_nature = external_mint_nature_for(normalized)
    if detected_nature
      pocket = 2
      field_use = 1
      handler_kind = :external_mint
      nature_id = detected_nature
    end

    detected_stat = external_iv_capsule_stat_for(normalized, display_name, description)
    if detected_stat
      pocket = 2
      field_use = 1
      handler_kind = :external_iv_capsule
      stat_id = detected_stat
      iv_amount = 10
    end

    detected_native = external_native_delegate_for(normalized)
    if detected_native
      native_data = base_item_try_get(detected_native)
      handler_kind = :delegate_native_item
      native_item = detected_native
      native_battle_use = native_data && native_data.respond_to?(:battle_use) ? integer(native_data.battle_use, 0) : 0
      native_field_use = native_data && native_data.respond_to?(:field_use) ? integer(native_data.field_use, field_use) : field_use
      battle_delegate = detected_native if native_battle_use > 0
      field_use = native_field_use
      field_use = 1 if field_use == 0
      battle_use = native_battle_use if native_battle_use > 0
    elsif ["ABILITYPATCH", "SECRETCAPSULE"].include?(normalized)
      pocket = 2
      field_use = 1
      handler_kind = :external_ability_capsule
      allow_hidden_abilities = true
      ability_scope = :hidden
    elsif normalized == "SUPERCAPSULE"
      pocket = 2
      field_use = 1
      handler_kind = :external_ability_capsule
      allow_hidden_abilities = true
      ability_scope = :all
    elsif normalized == "RANDOMABILITYCAPSULE"
      pocket = 2
      field_use = 1
      handler_kind = :external_ability_capsule
      allow_hidden_abilities = true
      ability_scope = :random
    elsif normalized == "ABILITYCAPSULE"
      pocket = 2
      field_use = 1
      handler_kind = :external_ability_capsule
      ability_scope = :regular
    end

    icon_logical_path = entry[:icon_logical_path].to_s
    icon_logical_path = "Graphics/Items/#{raw_name.to_s.strip.gsub(/\A:/, "")}" if icon_logical_path.empty?

    return {
      :name              => display_name,
      :name_plural       => display_plural,
      :description       => description,
      :price             => integer(entry[:price], 0),
      :pocket            => pocket,
      :type              => item_type,
      :field_use         => field_use,
      :battle_use        => battle_use,
      :move              => move,
      :handler_kind      => handler_kind,
      :use_message       => use_message,
      :native_item       => native_item,
      :battle_delegate   => battle_delegate,
      :happiness_method  => nil,
      :heal_amount       => nil,
      :exp_value         => nil,
      :nature_id         => nature_id,
      :stat_id           => stat_id,
      :iv_amount         => iv_amount,
      :allow_hidden_abilities => allow_hidden_abilities,
      :ability_scope     => ability_scope,
      :native_id_number  => native_id,
      :icon_logical_path => icon_logical_path
    }
  rescue => e
    log("Generic PBS item definition failed for #{expansion_id}/#{raw_name}: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def truthy_external_item_flag?(value)
    return true if value == true
    return value != 0 if value.is_a?(Numeric)
    return value.to_s.downcase == "true"
  end

  def imported_item_icon_name(expansion_id, raw_name)
    normalized = raw_name.to_s.strip.upcase.gsub(/[^\w]+/, "")
    return nil if normalized.empty?
    return REBORN_ICON_ALIASES[normalized] if expansion_id.to_s == "reborn" && REBORN_ICON_ALIASES[normalized]
    return normalized.downcase
  end

  def imported_item_icon_filename(metadata)
    return nil if !metadata.is_a?(Hash)
    logical = metadata[:icon_logical_path].to_s
    expansion_id = metadata[:expansion_id].to_s
    return nil if logical.empty? || expansion_id.empty?
    cache_key = "#{expansion_id}|#{logical}"
    cache = imported_item_icon_path_cache
    return cache[cache_key] if cache.has_key?(cache_key)
    resolved = resolve_runtime_path_for_expansion(expansion_id, logical, REBORN_ITEM_ICON_EXTENSIONS) if respond_to?(:resolve_runtime_path_for_expansion)
    if (resolved.nil? || resolved.to_s.empty?) && expansion_id == "pokemon_keishou" &&
       respond_to?(:resolve_runtime_path_for_expansion)
      resolved = resolve_runtime_path_for_expansion("keishou", logical, REBORN_ITEM_ICON_EXTENSIONS)
    end
    if resolved.nil? || resolved.to_s.empty?
      cache[cache_key] = nil
      return nil
    end
    cache[cache_key] = resolved.to_s.sub(/\.(png|gif|bmp)\z/i, "")
    return cache[cache_key]
  rescue
    return nil
  end

  def safe_item_icon_filename(item)
    return "Graphics/Items/back" if item.nil?
    item_data = raw_item_data(item)
    return "Graphics/Items/000" if item_data.nil?
    cache_key = item_icon_cache_key(item, item_data)
    if respond_to?(:current_expansion_marker)
      marker = current_expansion_marker.to_s
      cache_key = "#{marker}|#{cache_key}" if !marker.empty?
    end
    cache = item_icon_filename_cache
    return cache[cache_key] if cache.has_key?(cache_key)

    metadata = direct_imported_item_metadata(item, true)
    if metadata
      imported_icon = imported_item_icon_filename(metadata)
      if imported_icon && !imported_icon.empty?
        cache[cache_key] = imported_icon
        return cache[cache_key]
      end
    end

    if defined?(::PokegunTerminal) && defined?(::PokegunTerminal::ITEM_DATA)
      pokegun_data = ::PokegunTerminal::ITEM_DATA[item_data.id] rescue nil
      if pokegun_data && !pokegun_data[:icon].to_s.empty?
        if pbResolveBitmap(pokegun_data[:icon].to_s)
          cache[cache_key] = pokegun_data[:icon].to_s
          return cache[cache_key]
        end
      end
    end

    if defined?(::BloodboundCatalysts) && defined?(::BloodboundCatalysts::CATALYSTS)
      catalyst = ::BloodboundCatalysts::CATALYSTS[item_data.id] rescue nil
      if catalyst
        icon_file = catalyst[2].to_s
        path = "Graphics/Multiplayer/#{icon_file}"
        if !icon_file.empty? && pbResolveBitmap(path)
          cache[cache_key] = path
          return cache[cache_key]
        end
      end
    end

    if respond_to?(:keishou_native_item_icon_filename)
      keishou_icon = keishou_native_item_icon_filename(item_data)
      if keishou_icon && !keishou_icon.empty?
        cache[cache_key] = keishou_icon
        return cache[cache_key]
      end
    end

    ret = sprintf("Graphics/Items/%s", item_data.id)
    if pbResolveBitmap(ret)
      cache[cache_key] = ret
      return cache[cache_key]
    end
    if item_data.is_machine?
      prefix = "machine"
      if item_data.is_HM?
        prefix = "machine_hm"
      elsif item_data.is_TR?
        prefix = "machine_tr"
      end
      move_type = GameData::Move.get(item_data.move).type
      type_data = GameData::Type.get(move_type)
      ret = sprintf("Graphics/Items/%s_%s", prefix, type_data.id)
      if pbResolveBitmap(ret)
        cache[cache_key] = ret
        return cache[cache_key]
      end
      if !item_data.is_TM?
        ret = sprintf("Graphics/Items/machine_%s", type_data.id)
        if pbResolveBitmap(ret)
          cache[cache_key] = ret
          return cache[cache_key]
        end
      end
    end
    cache[cache_key] = "Graphics/Items/000"
    return cache[cache_key]
  rescue => e
    log("Safe item icon resolution failed for #{item.inspect}: #{e.class}: #{e.message}")
    return "Graphics/Items/000"
  end

  def safe_item_held_icon_filename(item)
    item_data = raw_item_data(item)
    return nil if item_data.nil?
    cache_key = item_icon_cache_key(item, item_data)
    cache = held_item_icon_filename_cache
    return cache[cache_key] if cache.has_key?(cache_key)

    if defined?(::PokegunTerminal) && defined?(::PokegunTerminal::ITEM_DATA)
      pokegun_data = ::PokegunTerminal::ITEM_DATA[item_data.id] rescue nil
      if pokegun_data && !pokegun_data[:icon].to_s.empty?
        if pbResolveBitmap(pokegun_data[:icon].to_s)
          cache[cache_key] = pokegun_data[:icon].to_s
          return cache[cache_key]
        end
      end
    end

    name_base = item_data.is_mail? ? "mail" : "item"
    ret = sprintf("Graphics/Pictures/Party/icon_%s_%s", name_base, item_data.id)
    if pbResolveBitmap(ret)
      cache[cache_key] = ret
      return cache[cache_key]
    end
    cache[cache_key] = sprintf("Graphics/Pictures/Party/icon_%s", name_base)
    return cache[cache_key]
  rescue => e
    log("Safe held item icon resolution failed for #{item.inspect}: #{e.class}: #{e.message}")
    return nil
  end

  def reborn_imported_item_definition(raw_name)
    normalized = raw_name.to_s.strip.upcase.gsub(/[^\w]+/, "")
    return nil if normalized.empty?
    entry = reborn_item_catalog[normalized] || {}
    display_name = normalize_imported_item_text(entry[:name] || humanize_external_item_name(raw_name))
    description = normalize_imported_item_text(entry[:desc] || _INTL("{1} imported from Pokemon Reborn.", display_name))
    price = integer(entry[:price], 0)

    pocket = 1
    item_type = 0
    if truthy_external_item_flag?(entry[:keyitem]) || truthy_external_item_flag?(entry[:questitem]) || truthy_external_item_flag?(entry[:story])
      pocket = 8
      item_type = 6
    elsif truthy_external_item_flag?(entry[:berry])
      pocket = 5
      item_type = 5
    elsif truthy_external_item_flag?(entry[:medicine]) || truthy_external_item_flag?(entry[:healing]) ||
          truthy_external_item_flag?(entry[:status]) || truthy_external_item_flag?(entry[:revival]) ||
          truthy_external_item_flag?(entry[:levelup]) || truthy_external_item_flag?(entry[:mint]) ||
          truthy_external_item_flag?(entry[:vitamin])
      pocket = 2
    elsif truthy_external_item_flag?(entry[:battleitem])
      pocket = 7
    elsif truthy_external_item_flag?(entry[:mail])
      pocket = 6
      item_type = 1
    elsif truthy_external_item_flag?(entry[:ball]) || normalized.end_with?("BALL")
      pocket = 3
      item_type = 3
    end

    item_type = 7 if truthy_external_item_flag?(entry[:evoitem])
    item_type = 8 if truthy_external_item_flag?(entry[:fossil])
    item_type = 9 if truthy_external_item_flag?(entry[:apricorn])
    item_type = 10 if truthy_external_item_flag?(entry[:gem])
    item_type = 11 if truthy_external_item_flag?(entry[:mulch])
    item_type = 12 if truthy_external_item_flag?(entry[:megastone])

    definition = {
      :name              => display_name,
      :description       => description,
      :price             => price,
      :pocket            => pocket,
      :type              => item_type,
      :field_use         => 0,
      :battle_use        => 0,
      :handler_kind      => nil,
      :native_item       => nil,
      :battle_delegate   => nil,
      :happiness_method  => nil,
      :heal_amount       => nil,
      :exp_value         => nil,
      :nature_id         => nil,
      :stat_id           => nil,
      :iv_amount         => nil,
      :allow_hidden_abilities => false,
      :ability_scope     => nil,
      :icon_logical_path => nil
    }

    icon_name = imported_item_icon_name("reborn", normalized)
    definition[:icon_logical_path] = "Graphics/Icons/#{icon_name}" if icon_name

    detected_nature = external_mint_nature_for(normalized)
    if detected_nature
      definition[:field_use] = 1
      definition[:pocket] = 2
      definition[:handler_kind] = :external_mint
      definition[:nature_id] = detected_nature
      return definition
    end

    detected_stat = external_iv_capsule_stat_for(normalized, display_name, description)
    if detected_stat
      definition[:field_use] = 1
      definition[:pocket] = 2
      definition[:handler_kind] = :external_iv_capsule
      definition[:stat_id] = detected_stat
      definition[:iv_amount] = 10
      return definition
    end

    detected_native = external_native_delegate_for(normalized)
    if detected_native
      native_data = base_item_try_get(detected_native)
      native_battle_use = native_data && native_data.respond_to?(:battle_use) ? integer(native_data.battle_use, 0) : 0
      native_field_use = native_data && native_data.respond_to?(:field_use) ? integer(native_data.field_use, definition[:field_use]) : definition[:field_use]
      definition[:handler_kind] = :delegate_native_item
      definition[:native_item] = detected_native
      definition[:battle_delegate] = detected_native if native_battle_use > 0
      definition[:field_use] = native_field_use
      definition[:field_use] = 1 if definition[:field_use] == 0
      definition[:battle_use] = native_battle_use if native_battle_use > 0
      return definition
    end

    if ["COMMONCANDY", "REVERSECANDY"].include?(normalized)
      definition[:field_use] = 1
      definition[:handler_kind] = :reborn_common_candy
      return definition
    end

    if REBORN_EXP_CANDY_VALUES[normalized]
      definition[:field_use] = 1
      definition[:handler_kind] = :reborn_exp_candy
      definition[:exp_value] = REBORN_EXP_CANDY_VALUES[normalized]
      return definition
    end

    native_status_item = REBORN_STATUS_ITEM_ALIASES[normalized]
    if native_status_item
      definition[:field_use] = 1
      definition[:battle_use] = 1 if normalized != "COTTONCANDY"
      definition[:battle_use] = 1 if normalized == "COTTONCANDY"
      definition[:handler_kind] = :delegate_native_item
      definition[:native_item] = native_status_item
      definition[:battle_delegate] = native_status_item
      definition[:happiness_method] = "candy" if normalized != "COTTONCANDY"
      definition[:happiness_method] = "candy" if normalized == "COTTONCANDY"
      return definition
    end

    if REBORN_HP_ITEM_VALUES[normalized]
      definition[:field_use] = 1
      definition[:battle_use] = 1
      definition[:handler_kind] = :reborn_hp_item
      definition[:heal_amount] = REBORN_HP_ITEM_VALUES[normalized]
      if ["VANILLAIC", "CHOCOLATEIC", "STRAWBIC"].include?(normalized)
        definition[:happiness_method] = "candy"
      elsif normalized == "BLUEMIC"
        definition[:happiness_method] = "bluecandy"
      end
      return definition
    end

    if REBORN_HAPPINESS_ONLY_ITEMS[normalized]
      definition[:field_use] = 1
      definition[:handler_kind] = :reborn_happiness_only
      definition[:happiness_method] = REBORN_HAPPINESS_ONLY_ITEMS[normalized]
      return definition
    end

    if truthy_external_item_flag?(entry[:medicine]) || truthy_external_item_flag?(entry[:levelup])
      definition[:field_use] = 1
    end
    return definition
  end

  def imported_item_registration_definition(expansion_id, raw_name)
    expansion = expansion_id.to_s
    normalized = raw_name.to_s.strip.gsub(/\A:/, "")
    return nil if expansion.empty? || normalized.empty?
    return reborn_imported_item_definition(normalized) if expansion == "reborn"
    if imported_item_expansion_matches?(expansion, ["anil", "pokemon_anil", "indigo", "pokemon_indigo"])
      anil = anil_item_metadata_definition(normalized)
      return anil if anil.is_a?(Hash)
    end
    if imported_item_expansion_matches?(expansion, ["rejuvenation", "pokemon_rejuvenation"])
      rejuvenation = rejuvenation_item_metadata_definition(normalized)
      return rejuvenation if rejuvenation.is_a?(Hash)
    end
    if imported_item_expansion_matches?(expansion, ["insurgence", "pokemon_insurgence"])
      insurgence = insurgence_item_metadata_definition(normalized)
      return insurgence if insurgence.is_a?(Hash)
    end
    if ["keishou", "pokemon_keishou"].include?(expansion) && respond_to?(:keishou_item_metadata_definition)
      keishou = keishou_item_metadata_definition(normalized)
      return keishou if keishou.is_a?(Hash)
    end
    generic = generic_pbs_item_definition(expansion, normalized)
    return generic if generic
    return nil
  end

  def apply_external_item_happiness_change(pkmn, method)
    return if pkmn.nil? || method.nil? || method.to_s.empty?
    pkmn.changeHappiness(method)
  rescue => e
    log("Imported item happiness change failed for #{pkmn.name}: #{e.class}: #{e.message}")
  end

  def external_item_no_effect(scene)
    scene.pbDisplay(_INTL("It won't have any effect.")) if scene && scene.respond_to?(:pbDisplay)
    return false
  end

  def external_item_valid_pokemon_target?(pkmn)
    return false if pkmn.nil?
    return false if pkmn.respond_to?(:egg?) && pkmn.egg?
    return false if pkmn.respond_to?(:shadowPokemon?) && pkmn.shadowPokemon?
    return false if pkmn.respond_to?(:isShadow?) && pkmn.isShadow?
    return true
  rescue
    return false
  end

  def imported_stat_display_name(stat_id)
    stat_data = GameData::Stat.try_get(stat_id) if defined?(GameData::Stat)
    return stat_data.name if stat_data && stat_data.respond_to?(:name)
    return stat_id.to_s.split("_").map { |part| part.capitalize }.join(" ")
  rescue
    return stat_id.to_s
  end

  def apply_external_mint_item(pkmn, scene, nature_id)
    return external_item_no_effect(scene) if !external_item_valid_pokemon_target?(pkmn)
    nature_data = GameData::Nature.try_get(nature_id) if defined?(GameData::Nature)
    return external_item_no_effect(scene) if nature_data.nil?
    current_id = nil
    current_id = pkmn.nature_for_stats_id if pkmn.respond_to?(:nature_for_stats_id)
    current_id = pkmn.nature_id if current_id.nil? && pkmn.respond_to?(:nature_id)
    current_id = pkmn.nature.id if current_id.nil? && pkmn.respond_to?(:nature) && pkmn.nature
    return external_item_no_effect(scene) if current_id == nature_data.id
    if pkmn.respond_to?(:nature_for_stats=)
      pkmn.nature_for_stats = nature_data.id
    elsif pkmn.respond_to?(:nature=)
      pkmn.nature = nature_data.id
    else
      return external_item_no_effect(scene)
    end
    scene.pbHardRefresh if scene && scene.respond_to?(:pbHardRefresh)
    scene.pbRefresh if scene && scene.respond_to?(:pbRefresh)
    scene.pbDisplay(_INTL("{1}'s stats now reflect a {2} nature.", pkmn.name, nature_data.name)) if scene && scene.respond_to?(:pbDisplay)
    return true
  rescue => e
    log("Imported mint failed for #{pkmn ? pkmn.name : "nil"}: #{e.class}: #{e.message}")
    return external_item_no_effect(scene)
  end

  def apply_external_iv_capsule_item(pkmn, scene, stat_id, amount)
    return external_item_no_effect(scene) if !external_item_valid_pokemon_target?(pkmn)
    return external_item_no_effect(scene) if !pkmn.respond_to?(:iv) || pkmn.iv.nil?
    stat_data = GameData::Stat.try_get(stat_id) if defined?(GameData::Stat)
    return external_item_no_effect(scene) if stat_data.nil?
    limit = defined?(Pokemon::IV_STAT_LIMIT) ? Pokemon::IV_STAT_LIMIT : 31
    iv_maxed = pkmn.respond_to?(:ivMaxed) && pkmn.ivMaxed && pkmn.ivMaxed[stat_data.id]
    current = pkmn.iv[stat_data.id].to_i
    return external_item_no_effect(scene) if iv_maxed || current >= limit
    pkmn.iv[stat_data.id] = [current + [amount.to_i, 1].max, limit].min
    pkmn.calc_stats if pkmn.respond_to?(:calc_stats)
    scene.pbHardRefresh if scene && scene.respond_to?(:pbHardRefresh)
    scene.pbRefresh if scene && scene.respond_to?(:pbRefresh)
    scene.pbDisplay(_INTL("{1}'s {2} IV rose!", pkmn.name, imported_stat_display_name(stat_data.id))) if scene && scene.respond_to?(:pbDisplay)
    return true
  rescue => e
    log("Imported IV capsule failed for #{pkmn ? pkmn.name : "nil"}: #{e.class}: #{e.message}")
    return external_item_no_effect(scene)
  end

  def external_ability_capsule_choices(pkmn, scope)
    return [] if pkmn.nil? || !pkmn.respond_to?(:getAbilityList)
    scope = scope || :regular
    if defined?(pbAbilityCapsuleChoices) && scope != :all && scope != :random
      return pbAbilityCapsuleChoices(pkmn, scope == :hidden)
    end
    choices = []
    seen_abilities = {}
    current_ability = pkmn.respond_to?(:ability_id) ? pkmn.ability_id : nil
    pkmn.getAbilityList.each do |ability_id, ability_index|
      next if ability_id.nil? || seen_abilities[ability_id]
      next if scope == :regular && ability_index.to_i >= 2
      next if scope == :hidden && ability_index.to_i < 2
      next if ability_id == current_ability
      seen_abilities[ability_id] = true
      choices << [ability_id, ability_index]
    end
    return choices
  rescue
    return []
  end

  def apply_external_ability_capsule_item(pkmn, scene, scope)
    return external_item_no_effect(scene) if !external_item_valid_pokemon_target?(pkmn)
    return external_item_no_effect(scene) if pkmn.respond_to?(:isSpecies?) && pkmn.isSpecies?(:ZYGARDE)
    choices = external_ability_capsule_choices(pkmn, scope)
    return external_item_no_effect(scene) if choices.empty?
    chosen_ability = nil
    if scope == :random
      chosen_ability = choices[rand(choices.length)]
    elsif defined?(pbChooseAbilityCapsuleTarget)
      chosen_ability = pbChooseAbilityCapsuleTarget(pkmn, scene, choices)
    else
      chosen_ability = choices[0]
      if choices.length > 1 && scene && scene.respond_to?(:pbShowCommands)
        commands = choices.map { |ability_id, _ability_index| GameData::Ability.get(ability_id).name }
        chosen_index = scene.pbShowCommands(_INTL("Choose an ability."), commands, 0)
        return false if chosen_index.nil? || chosen_index < 0
        chosen_ability = choices[chosen_index]
      end
      ability_name = GameData::Ability.get(chosen_ability[0]).name
      if scene && scene.respond_to?(:pbConfirm)
        return false if !scene.pbConfirm(_INTL("Would you like to change {1}'s Ability to {2}?", pkmn.name, ability_name))
      end
    end
    return false if chosen_ability.nil?
    if defined?(pbApplyAbilityCapsuleChoice)
      return pbApplyAbilityCapsuleChoice(pkmn, scene, chosen_ability)
    end
    ability_id, ability_index = chosen_ability
    ability_name = GameData::Ability.get(ability_id).name
    pkmn.ability_index = ability_index if pkmn.respond_to?(:ability_index=)
    pkmn.ability = ability_id if pkmn.respond_to?(:ability=)
    scene.pbHardRefresh if scene && scene.respond_to?(:pbHardRefresh)
    scene.pbDisplay(_INTL("{1}'s Ability changed to {2}!", pkmn.name, ability_name)) if scene && scene.respond_to?(:pbDisplay)
    return true
  rescue => e
    log("Imported ability capsule failed for #{pkmn ? pkmn.name : "nil"}: #{e.class}: #{e.message}")
    return external_item_no_effect(scene)
  end

  def external_rock_smash_target_event
    return nil if !defined?($game_player) || !$game_player || !$game_player.respond_to?(:pbFacingEvent)
    event = ($game_player.pbFacingEvent(true) rescue nil)
    event = ($game_player.pbFacingEvent rescue nil) if event.nil?
    return nil if event.nil?
    name = event.respond_to?(:name) ? event.name.to_s : ""
    return event if name =~ /(smash\s*rock|smashrock|rock\s*smash|breakable\s*rock|cracked\s*rock)/i
    return event if name =~ /\brock\b/i
    return nil
  rescue
    return nil
  end

  def use_external_rock_smash_item
    event = external_rock_smash_target_event
    if event.nil?
      pbMessage(_INTL("There is no breakable rock here.")) if defined?(pbMessage)
      return false
    end
    confirmed = defined?(pbConfirmMessage) ? pbConfirmMessage(_INTL("This rock appears to be breakable. Use the Pickaxe?")) : true
    return false if !confirmed
    holder = nil
    holder = $Trainer.get_pokemon_with_move(:ROCKSMASH) if defined?($Trainer) && $Trainer &&
                                                           $Trainer.respond_to?(:get_pokemon_with_move)
    actor_name = holder && holder.respond_to?(:name) ? holder.name : nil
    actor_name = $Trainer.name if actor_name.to_s.empty? && defined?($Trainer) && $Trainer.respond_to?(:name)
    actor_name = "You" if actor_name.to_s.empty?
    pbMessage(_INTL("{1} used the Pickaxe!", actor_name)) if defined?(pbMessage)
    pbHiddenMoveAnimation(holder) if holder && defined?(pbHiddenMoveAnimation)
    if defined?(pbSmashEvent)
      pbSmashEvent(event)
    elsif event.respond_to?(:erase)
      event.erase
    end
    pbRockSmashRandomEncounter if defined?(pbRockSmashRandomEncounter)
    return true
  rescue => e
    log("Imported Rock Smash item failed: #{e.class}: #{e.message}") if respond_to?(:log)
    pbMessage(_INTL("The Pickaxe could not be used here.")) if defined?(pbMessage)
    return false
  end

  def external_battler_has_type?(battler, type_id)
    type = type_id.to_sym
    return true if battler.respond_to?(:pbHasType?) && battler.pbHasType?(type)
    return true if battler.respond_to?(:hasType?) && battler.hasType?(type)
    if battler.respond_to?(:types)
      types = battler.types
      return true if types && types.map { |entry| entry.to_sym rescue entry }.include?(type)
    end
    pokemon = battler.respond_to?(:pokemon) ? battler.pokemon : nil
    if pokemon && pokemon.respond_to?(:types)
      types = pokemon.types
      return true if types && types.map { |entry| entry.to_sym rescue entry }.include?(type)
    end
    return false
  rescue
    return false
  end

  def ensure_external_ball_type!(runtime_symbol)
    return false if runtime_symbol.nil? || !defined?($BallTypes) || !$BallTypes.is_a?(Hash)
    return true if $BallTypes.values.include?(runtime_symbol)
    max_index = $BallTypes.keys.compact.map { |key| integer(key, -1) }.max.to_i
    $BallTypes[[max_index + 1, 41].max] = runtime_symbol
    return true
  rescue => e
    log("Imported ball type registration failed for #{runtime_symbol}: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def ensure_external_ball_graphics!(runtime_symbol, expansion_id, source_ball)
    return false if runtime_symbol.nil? || expansion_id.to_s.empty? || source_ball.to_s.empty?
    begin
      require "fileutils" if !defined?(FileUtils)
    rescue Exception
    end
    return false if !defined?(FileUtils)
    copied = false
    pairs = [
      ["Graphics/Pictures/Battle/#{source_ball}", "Graphics/Battle animations/ball_#{runtime_symbol}"],
      ["Graphics/Pictures/Battle/#{source_ball}_open", "Graphics/Battle animations/ball_#{runtime_symbol}_open"],
      ["Graphics/Pictures/Summary/summaryball#{source_ball}", "Graphics/Pictures/Summary/icon_ball_#{runtime_symbol}"]
    ]
    pairs.each do |source_logical, target_logical|
      next if defined?(pbResolveBitmap) && pbResolveBitmap(target_logical)
      source = resolve_runtime_path_for_expansion(expansion_id, source_logical, [".png", ".gif", ".jpg", ".jpeg", ".bmp"]) if respond_to?(:resolve_runtime_path_for_expansion)
      next if source.to_s.empty? || !File.file?(source)
      target = File.join(Dir.pwd, "#{target_logical}#{File.extname(source)}")
      FileUtils.mkdir_p(File.dirname(target))
      next if File.file?(target)
      FileUtils.cp(source, target)
      copied = true
    end
    return copied
  rescue => e
    log("Imported ball graphics bridge failed for #{runtime_symbol}: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def use_external_quartz_flute_item
    if respond_to?(:insurgence_expansion_id?) && !insurgence_expansion_id?
      pbMessage(_INTL("Mew does not answer from this world.")) if defined?(pbMessage)
      return true
    end
    if respond_to?(:insurgence_mew_transform_interaction!) && insurgence_mew_transform_interaction!(false)
      return true
    end
    pbMessage(_INTL("A clear note rings out, but nothing responds right now.")) if defined?(pbMessage)
    return true
  rescue => e
    log("Imported Quartz Flute item failed: #{e.class}: #{e.message}") if respond_to?(:log)
    pbMessage(_INTL("The Quartz Flute gives a quiet, harmless note.")) if defined?(pbMessage)
    return false
  end

  def imported_exp_gain_cap(pkmn)
    return nil if pkmn.nil?
    return nil if !defined?(GameData::GrowthRate)
    cap_level = nil
    if defined?($PokemonSystem) && $PokemonSystem && $PokemonSystem.respond_to?(:kuraylevelcap) &&
       $PokemonSystem.kuraylevelcap.to_i > 0 && defined?(getkuraylevelcap)
      cap_level = getkuraylevelcap
    end
    return nil if cap_level.nil? || cap_level.to_i <= 0
    growth = pkmn.growth_rate
    return growth.minimum_exp_for_level(cap_level.to_i)
  rescue
    return nil
  end

  def apply_reborn_exp_candy(pkmn, scene, exp_value)
    if pkmn.nil? || pkmn.level >= GameData::GrowthRate.max_level ||
       (pkmn.respond_to?(:shadowPokemon?) && pkmn.shadowPokemon?) ||
       (pkmn.respond_to?(:isShadow?) && pkmn.isShadow?)
      scene.pbDisplay(_INTL("It won't have any effect.")) if scene && scene.respond_to?(:pbDisplay)
      return false
    end

    growth = pkmn.growth_rate
    max_exp = growth.maximum_exp
    target_exp = [pkmn.exp + exp_value.to_i, max_exp].min
    cap_exp = imported_exp_gain_cap(pkmn)
    target_exp = [target_exp, cap_exp].min if cap_exp

    if target_exp <= pkmn.exp
      scene.pbDisplay(_INTL("It won't have any effect.")) if scene && scene.respond_to?(:pbDisplay)
      return false
    end

    original_level = pkmn.level
    target_level = growth.level_from_exp(target_exp)
    original_happiness = pkmn.happiness if pkmn.respond_to?(:happiness)

    if target_level > original_level
      (original_level + 1).upto(target_level) do |level|
        pbChangeLevel(pkmn, level, scene)
        pkmn.happiness = original_happiness if !original_happiness.nil? && pkmn.respond_to?(:happiness=)
      end
      pkmn.exp = target_exp
      pkmn.happiness = original_happiness if !original_happiness.nil? && pkmn.respond_to?(:happiness=)
      scene.pbHardRefresh if scene && scene.respond_to?(:pbHardRefresh)
      scene.pbRefresh if scene && scene.respond_to?(:pbRefresh)
    else
      pkmn.exp = target_exp
      scene.pbRefresh if scene && scene.respond_to?(:pbRefresh)
      scene.pbDisplay(_INTL("{1} gained Exp. Points.", pkmn.name)) if scene && scene.respond_to?(:pbDisplay)
    end
    return true
  rescue => e
    log("Imported exp candy failed for #{pkmn&.name}: #{e.class}: #{e.message}")
    scene.pbDisplay(_INTL("It won't have any effect.")) if scene && scene.respond_to?(:pbDisplay)
    return false
  end

  def register_imported_item_handlers(runtime_symbol, metadata)
    return if runtime_symbol.nil? || !metadata.is_a?(Hash) || !defined?(ItemHandlers)
    key = "#{runtime_symbol}:#{metadata[:handler_kind]}"
    return if imported_item_handler_registry[key]

    case metadata[:handler_kind]
    when :generic_item_info
      message = normalize_imported_item_text(metadata[:use_message] || metadata[:description] || _INTL("Nothing happened."))
      ItemHandlers::UseFromBag.add(runtime_symbol, proc { |_item|
        pbMessage(message) if defined?(pbMessage)
        next 1
      })
      ItemHandlers::UseInField.add(runtime_symbol, proc { |_item|
        pbMessage(message) if defined?(pbMessage)
        next true
      })
    when :reborn_common_candy
      ItemHandlers::UseOnPokemon.add(runtime_symbol, proc { |_item, pkmn, scene|
        if pkmn.nil? || pkmn.level <= 1 || (pkmn.respond_to?(:shadowPokemon?) && pkmn.shadowPokemon?) ||
           (pkmn.respond_to?(:isShadow?) && pkmn.isShadow?)
          scene.pbDisplay(_INTL("It won't have any effect.")) if scene && scene.respond_to?(:pbDisplay)
          next false
        end
        pbChangeLevel(pkmn, pkmn.level - 1, scene)
        apply_external_item_happiness_change(pkmn, "badcandy")
        scene.pbHardRefresh if scene && scene.respond_to?(:pbHardRefresh)
        next true
      })
    when :reborn_exp_candy
      exp_value = metadata[:exp_value].to_i
      ItemHandlers::UseOnPokemon.add(runtime_symbol, proc { |_item, pkmn, scene|
        next apply_reborn_exp_candy(pkmn, scene, exp_value)
      })
    when :external_mint
      nature_id = metadata[:nature_id]
      ItemHandlers::UseOnPokemon.add(runtime_symbol, proc { |_item, pkmn, scene|
        next apply_external_mint_item(pkmn, scene, nature_id)
      })
    when :external_iv_capsule
      stat_id = metadata[:stat_id]
      iv_amount = metadata[:iv_amount] || 10
      ItemHandlers::UseOnPokemon.add(runtime_symbol, proc { |_item, pkmn, scene|
        next apply_external_iv_capsule_item(pkmn, scene, stat_id, iv_amount)
      })
    when :external_ability_capsule
      scope = metadata[:ability_scope] || (metadata[:allow_hidden_abilities] ? :hidden : :regular)
      ItemHandlers::UseOnPokemon.add(runtime_symbol, proc { |_item, pkmn, scene|
        next apply_external_ability_capsule_item(pkmn, scene, scope)
      })
    when :external_rock_smash
      ItemHandlers::UseInField.add(runtime_symbol, proc { |_item|
        next TravelExpansionFramework.use_external_rock_smash_item ? 1 : 0
      })
      ItemHandlers::UseFromBag.add(runtime_symbol, proc { |_item|
        next TravelExpansionFramework.use_external_rock_smash_item ? 2 : 0
      })
    when :external_steam_ball
      ensure_external_ball_type!(runtime_symbol)
      ensure_external_ball_graphics!(runtime_symbol, metadata[:expansion_id] || metadata["expansion_id"], "STEAMBALL")
      if defined?(BallHandlers)
        BallHandlers::ModifyCatchRate.add(runtime_symbol, proc { |_ball, catch_rate, _battle, battler, ultra_beast|
          rate = catch_rate.to_i
          is_ultra_beast = ultra_beast
          is_ultra_beast = pbIsUltraBeast?(battler) if !is_ultra_beast && defined?(pbIsUltraBeast?)
          rate = (rate * 0.1).floor if is_ultra_beast
          if TravelExpansionFramework.external_battler_has_type?(battler, :FIRE) ||
             TravelExpansionFramework.external_battler_has_type?(battler, :WATER)
            rate = (rate * 3.5).floor
          end
          next [rate.to_i, 1].max
        })
      end
    when :external_quartz_flute
      ItemHandlers::UseInField.add(runtime_symbol, proc { |_item|
        next TravelExpansionFramework.use_external_quartz_flute_item ? 1 : 0
      })
      ItemHandlers::UseFromBag.add(runtime_symbol, proc { |_item|
        next TravelExpansionFramework.use_external_quartz_flute_item ? 2 : 0
      })
    when :delegate_native_item
      native_item = metadata[:native_item]
      battle_item = metadata[:battle_delegate] || native_item
      happiness_method = metadata[:happiness_method]
      ItemHandlers::UseOnPokemon.add(runtime_symbol, proc { |_item, pkmn, scene|
        used = ItemHandlers.triggerUseOnPokemon(native_item, pkmn, scene)
        apply_external_item_happiness_change(pkmn, happiness_method) if used && happiness_method
        next used
      })
      if battle_item
        ItemHandlers::CanUseInBattle.add(runtime_symbol, proc { |_item, pkmn, battler, move, first_action, battle, scene, show_messages|
          next ItemHandlers.triggerCanUseInBattle(battle_item, pkmn, battler, move, first_action, battle, scene, show_messages)
        })
        ItemHandlers::BattleUseOnPokemon.add(runtime_symbol, proc { |_item, pkmn, battler, choices, scene|
          ItemHandlers.triggerBattleUseOnPokemon(battle_item, pkmn, battler, choices, scene)
          apply_external_item_happiness_change(pkmn, happiness_method) if happiness_method
          next true
        })
      end
    when :reborn_hp_item
      heal_amount = metadata[:heal_amount].to_i
      happiness_method = metadata[:happiness_method]
      ItemHandlers::UseOnPokemon.add(runtime_symbol, proc { |_item, pkmn, scene|
        used = pbHPItem(pkmn, heal_amount, scene)
        apply_external_item_happiness_change(pkmn, happiness_method) if used && happiness_method
        next used
      })
      ItemHandlers::CanUseInBattle.add(runtime_symbol, proc { |_item, pkmn, battler, move, first_action, battle, scene, show_messages|
        next ItemHandlers.triggerCanUseInBattle(:POTION, pkmn, battler, move, first_action, battle, scene, show_messages)
      })
      ItemHandlers::BattleUseOnPokemon.add(runtime_symbol, proc { |_item, pkmn, battler, _choices, scene|
        pbBattleHPItem(pkmn, battler, heal_amount, scene)
        apply_external_item_happiness_change(pkmn, happiness_method) if happiness_method
        next true
      })
    when :reborn_happiness_only
      happiness_method = metadata[:happiness_method]
      ItemHandlers::UseOnPokemon.add(runtime_symbol, proc { |_item, pkmn, scene|
        if pkmn.nil? || !pkmn.respond_to?(:happiness) || pkmn.happiness >= 255
          scene.pbDisplay(_INTL("It won't have any effect.")) if scene && scene.respond_to?(:pbDisplay)
          next false
        end
        apply_external_item_happiness_change(pkmn, happiness_method)
        scene.pbRefresh if scene && scene.respond_to?(:pbRefresh)
        scene.pbDisplay(_INTL("{1} enjoyed the treat!", pkmn.name)) if scene && scene.respond_to?(:pbDisplay)
        next true
      })
    end

    imported_item_handler_registry[key] = true
  rescue => e
    log("Imported item handler registration failed for #{runtime_symbol}: #{e.class}: #{e.message}")
  end

  def refresh_imported_item_registration!(runtime_symbol, expansion, raw, item_data = nil, definition = nil)
    return nil if runtime_symbol.nil?
    definition ||= imported_item_registration_definition(expansion, raw) || {}
    id_number = item_data && item_data.respond_to?(:id_number) ? item_data.id_number : imported_item_id_number(expansion, raw)
    display_name = definition[:name].to_s
    display_name = humanize_external_item_name(raw) if display_name.empty?
    display_plural = definition[:name_plural].to_s
    display_plural = imported_item_plural(display_name) if display_plural.empty?
    description = definition[:description].to_s
    if description.empty?
      description = _INTL("{1} imported from {2}. Some custom behavior may require a dedicated compatibility adapter.",
                          display_name, imported_item_display_name(expansion))
    end

    GameData::Item.register({
      :id          => runtime_symbol,
      :id_number   => id_number,
      :name        => display_name,
      :name_plural => display_plural,
      :pocket      => integer(definition[:pocket], item_data && item_data.respond_to?(:pocket) ? item_data.pocket : 1),
      :price       => integer(definition[:price], item_data && item_data.respond_to?(:price) ? item_data.price : 0),
      :description => description,
      :field_use   => integer(definition[:field_use], item_data && item_data.respond_to?(:field_use) ? item_data.field_use : 0),
      :battle_use  => integer(definition[:battle_use], item_data && item_data.respond_to?(:battle_use) ? item_data.battle_use : 0),
      :type        => integer(definition[:type], item_data && item_data.respond_to?(:type) ? item_data.type : 0),
      :move        => definition[:move]
    })
    MessageTypes.set(MessageTypes::Items, id_number, display_name) if defined?(MessageTypes)
    MessageTypes.set(MessageTypes::ItemPlurals, id_number, display_plural) if defined?(MessageTypes)
    MessageTypes.set(MessageTypes::ItemDescriptions, id_number, description) if defined?(MessageTypes)

    metadata = (imported_runtime_items[runtime_symbol] || {}).merge(definition).merge({
      :runtime_symbol => runtime_symbol,
      :raw_name       => raw,
      :expansion_id   => expansion,
      :id_number      => id_number
    })
    imported_runtime_items[runtime_symbol] = metadata
    remember_imported_item_origin(metadata)
    imported_runtime_item_lookup[runtime_symbol] = metadata
    imported_runtime_item_lookup[runtime_symbol.to_s] = metadata
    imported_runtime_item_lookup[id_number] = metadata
    imported_runtime_item_lookup[id_number.to_s] = metadata
    refreshed_item = base_item_try_get(runtime_symbol)
    attach_imported_item_metadata(item_data, metadata) if item_data
    attach_imported_item_metadata(refreshed_item, metadata)
    imported_runtime_item_lookup[item_data] = metadata if item_data
    imported_runtime_item_lookup[refreshed_item] = metadata if refreshed_item
    register_imported_item_handlers(runtime_symbol, metadata)
    clear_item_icon_filename_cache!
    return metadata
  rescue => e
    log("Imported item metadata refresh failed for #{runtime_symbol}: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def ensure_external_item_registered(expansion_id, item_identifier)
    expansion = expansion_id.to_s
    return nil if expansion.empty?
    if item_identifier.is_a?(Symbol) || item_identifier.is_a?(String)
      canonical = canonical_imported_item_reference(item_identifier)
      if canonical
        return nil if canonical[0].to_s != expansion
        raw = canonical[1].to_s
      else
        raw = imported_item_raw_name(expansion, item_identifier)
      end
      return nil if raw.empty?
      direct_item = base_item_try_get(raw.to_sym)
      return direct_item.id if direct_item
      if raw.start_with?("TEF_")
        return nil
      end

      runtime_symbol = imported_item_runtime_symbol(expansion, raw)
      return nil if runtime_symbol.nil?
      existing = base_item_try_get(runtime_symbol)
      if existing
        refresh_imported_item_registration!(runtime_symbol, expansion, raw, existing)
        return existing.id
      end
      registration_key = "#{expansion}:#{runtime_symbol}"
      if imported_item_registration_stack[registration_key]
        return runtime_symbol if imported_item_runtime_symbol?(runtime_symbol)
        return nil
      end
      imported_item_registration_stack[registration_key] = true

      definition = imported_item_registration_definition(expansion, raw) || {}
      id_number = imported_item_id_number(expansion, raw)
      display_name = definition[:name].to_s
      display_name = humanize_external_item_name(raw) if display_name.empty?
      display_plural = definition[:name_plural].to_s
      display_plural = imported_item_plural(display_name) if display_plural.empty?
      description = definition[:description].to_s
      if description.empty?
        description = _INTL("{1} imported from {2}. Some custom behavior may require a dedicated compatibility adapter.",
                            display_name, imported_item_display_name(expansion))
      end

      GameData::Item.register({
        :id          => runtime_symbol,
        :id_number   => id_number,
        :name        => display_name,
        :name_plural => display_plural,
        :pocket      => integer(definition[:pocket], 1),
        :price       => integer(definition[:price], 0),
        :description => description,
        :field_use   => integer(definition[:field_use], 0),
        :battle_use  => integer(definition[:battle_use], 0),
        :type        => integer(definition[:type], 0),
        :move        => definition[:move]
      })
      MessageTypes.set(MessageTypes::Items, id_number, display_name)
      MessageTypes.set(MessageTypes::ItemPlurals, id_number, display_plural)
      MessageTypes.set(MessageTypes::ItemDescriptions, id_number, description)

      imported_runtime_items[runtime_symbol] = definition.merge({
        :runtime_symbol => runtime_symbol,
        :raw_name       => raw,
        :expansion_id   => expansion,
        :id_number      => id_number
      })
      remember_imported_item_origin(imported_runtime_items[runtime_symbol])
      imported_runtime_item_lookup[runtime_symbol] = imported_runtime_items[runtime_symbol]
      imported_runtime_item_lookup[runtime_symbol.to_s] = imported_runtime_items[runtime_symbol]
      imported_runtime_item_lookup[id_number] = imported_runtime_items[runtime_symbol]
      imported_runtime_item_lookup[id_number.to_s] = imported_runtime_items[runtime_symbol]
      registered_item = base_item_try_get(runtime_symbol)
      attach_imported_item_metadata(registered_item, imported_runtime_items[runtime_symbol])
      attach_imported_item_metadata(base_item_try_get(id_number), imported_runtime_items[runtime_symbol]) if registered_item.nil?
      if registered_item
        imported_runtime_item_lookup[registered_item] = imported_runtime_items[runtime_symbol]
      end

      register_imported_item_handlers(runtime_symbol, imported_runtime_items[runtime_symbol])
      clear_item_icon_filename_cache!
      log("Registered imported item #{runtime_symbol} for #{expansion} from #{raw}")
      return runtime_symbol
    end
    return nil
  rescue => e
    log("Imported item registration failed for #{expansion_id}/#{item_identifier}: #{e.class}: #{e.message}")
    return nil
  ensure
    imported_item_registration_stack.delete(registration_key) if defined?(registration_key) && registration_key
  end

  def resolve_pb_item_constant(name)
    raw = name.to_s.strip
    return nil if raw.empty?
    candidates = []
    candidates << raw
    candidates << raw.upcase if raw != raw.upcase
    candidates << raw.downcase if raw != raw.downcase
    candidates.each do |candidate|
      item_data = base_item_try_get(candidate.to_sym)
      return item_data.id_number if item_data
    end
    expansion_id = inferred_item_expansion_id(raw)
    return nil if expansion_id.nil?
    imported = ensure_external_item_registered(expansion_id, raw)
    return nil if imported.nil?
    item_data = base_item_try_get(imported)
    return item_data.id_number if item_data
    return nil
  rescue => e
    log("PBItems resolution failed for #{name}: #{e.class}: #{e.message}")
    return nil
  end
end

if defined?(Pokemon) && Pokemon.method_defined?(:changeHappiness) &&
   !Pokemon.method_defined?(:tef_items_original_change_happiness)
  class Pokemon
    alias tef_items_original_change_happiness changeHappiness

    def changeHappiness(method)
      case method.to_s
      when "candy", "level up"
        return tef_items_original_change_happiness("levelup")
      when "bluecandy"
        gain = 220
        gain += 1 if @poke_ball == :LUXURYBALL
        gain = (gain * 1.5).floor if hasItem?(:SOOTHEBELL)
        @happiness = (@happiness + gain).clamp(0, 255)
        return @happiness
      when "badcandy"
        happiness_range = @happiness / 100
        gain = [-5, -4, -3][happiness_range]
        @happiness = (@happiness + gain).clamp(0, 255)
        return @happiness
      end
      return tef_items_original_change_happiness(method)
    end
  end
end

if defined?(PBItems)
  class << PBItems
    if !method_defined?(:tef_original_const_missing)
      alias tef_original_const_missing const_missing if method_defined?(:const_missing)
    end

    def const_missing(name)
      item_id = TravelExpansionFramework.resolve_pb_item_constant(name)
      if item_id
        item_data = TravelExpansionFramework.raw_item_data(item_id)
        return item_id if TravelExpansionFramework.imported_runtime_item?(item_data)
        return const_set(name, item_id)
      end
      if defined?(tef_original_const_missing)
        return tef_original_const_missing(name)
      end
      raise NameError, "uninitialized constant PBItems::#{name}"
    end
  end
end

if defined?(PokemonBag)
  class PokemonBag
    alias tef_imported_alias_original_rearrange rearrange unless method_defined?(:tef_imported_alias_original_rearrange)

    def rearrange
      if defined?(TravelExpansionFramework) &&
         TravelExpansionFramework.respond_to?(:repair_imported_item_aliases!)
        TravelExpansionFramework.repair_imported_item_aliases!
      end
      return tef_imported_alias_original_rearrange
    end
  end
end

module GameData
  class Item
    class << self
      if !method_defined?(:tef_original_try_get)
        alias tef_original_try_get try_get
      end
      if !method_defined?(:tef_original_get)
        alias tef_original_get get
      end
      if !method_defined?(:tef_original_exists)
        alias tef_original_exists exists?
      end
      if !method_defined?(:tef_original_icon_filename)
        alias tef_original_icon_filename icon_filename
      end

      def try_get(other)
        data = tef_original_try_get(other)
        return data if data
        return nil if !other.is_a?(Symbol) && !other.is_a?(String)
        expansion_id = TravelExpansionFramework.inferred_item_expansion_id(other)
        return nil if expansion_id.nil?
        imported = TravelExpansionFramework.ensure_external_item_registered(expansion_id, other)
        return TravelExpansionFramework.raw_item_data(imported) if imported
        return nil
      end

      def get(other)
        data = try_get(other)
        return data if data
        return tef_original_get(other)
      end

      def exists?(other)
        data = try_get(other)
        return true if data
        return tef_original_exists(other)
      end

      def icon_filename(item)
        return TravelExpansionFramework.safe_item_icon_filename(item)
      end
    end
  end
end
