module TravelExpansionFramework
  module_function

  OPALO_EXPANSION_ID = "opalo" unless const_defined?(:OPALO_EXPANSION_ID)
  OPALO_LEGACY_EXPANSION_IDS = ["pokemon_opalo"].freeze unless const_defined?(:OPALO_LEGACY_EXPANSION_IDS)
  OPALO_COMPAT_PICTURE_OVERRIDES = %w[
    MenuNuzNormalClaro
    MenuNuzNormalOsc
    MenuNuzNuzClaro
    MenuNuzNuzOsc
    MenuNuzNormalDif1
    MenuNuzNormalDif1Claro
    MenuNuzNormalDif2
    MenuNuzNormalDif2Claro
    MenuNuzNormalDif3
    MenuNuzNormalDif3Claro
  ].freeze unless const_defined?(:OPALO_COMPAT_PICTURE_OVERRIDES)
  OPALO_LENS_OF_TRUTH_DURATION_SECONDS = 14 unless const_defined?(:OPALO_LENS_OF_TRUTH_DURATION_SECONDS)
  OPALO_LENS_OF_TRUTH_RANGE = 3 unless const_defined?(:OPALO_LENS_OF_TRUTH_RANGE)
  OPALO_STARTER_ROOM_LOCAL_MAP_ID = 5 unless const_defined?(:OPALO_STARTER_ROOM_LOCAL_MAP_ID)
  OPALO_STARTER_TOWN_LOCAL_MAP_ID = 2 unless const_defined?(:OPALO_STARTER_TOWN_LOCAL_MAP_ID)
  OPALO_STARTER_ROUTE_LOCAL_MAP_ID = 6 unless const_defined?(:OPALO_STARTER_ROUTE_LOCAL_MAP_ID)
  OPALO_STARTER_SELECTED_SWITCH = 62 unless const_defined?(:OPALO_STARTER_SELECTED_SWITCH)
  OPALO_STARTER_FLED_SWITCH = 63 unless const_defined?(:OPALO_STARTER_FLED_SWITCH)
  OPALO_STARTER_HIDDEN_SWITCH = 64 unless const_defined?(:OPALO_STARTER_HIDDEN_SWITCH)
  OPALO_STARTER_CHASE_SWITCH = 65 unless const_defined?(:OPALO_STARTER_CHASE_SWITCH)
  OPALO_STARTER_POOCHYENA_SWITCH = 66 unless const_defined?(:OPALO_STARTER_POOCHYENA_SWITCH)
  OPALO_STARTER_BATTLE_DONE_SWITCH = 67 unless const_defined?(:OPALO_STARTER_BATTLE_DONE_SWITCH)
  OPALO_STARTER_PROFESSOR_SWITCH = 68 unless const_defined?(:OPALO_STARTER_PROFESSOR_SWITCH)
  OPALO_STARTER_CHOICE_VARIABLE = 54 unless const_defined?(:OPALO_STARTER_CHOICE_VARIABLE)
  EMPYREAN_EXPANSION_ID = "empyrean" unless const_defined?(:EMPYREAN_EXPANSION_ID)
  EMPYREAN_LEGACY_EXPANSION_IDS = ["pokemonempyrean", "pokemon_empyrean"].freeze unless const_defined?(:EMPYREAN_LEGACY_EXPANSION_IDS)
  REALIDEA_EXPANSION_ID = "realidea" unless const_defined?(:REALIDEA_EXPANSION_ID)
  SOULSTONES_EXPANSION_ID = "soulstones" unless const_defined?(:SOULSTONES_EXPANSION_ID)
  SOULSTONES2_EXPANSION_ID = "soulstones2" unless const_defined?(:SOULSTONES2_EXPANSION_ID)
  ANIL_EXPANSION_ID = "anil" unless const_defined?(:ANIL_EXPANSION_ID)
  ANIL_LEGACY_EXPANSION_IDS = ["pokemon_anil", "pokemon_indigo", "indigo"].freeze unless const_defined?(:ANIL_LEGACY_EXPANSION_IDS)
  BUSHIDO_EXPANSION_ID = "bushido" unless const_defined?(:BUSHIDO_EXPANSION_ID)
  BUSHIDO_LEGACY_EXPANSION_IDS = ["pokemon_bushido"].freeze unless const_defined?(:BUSHIDO_LEGACY_EXPANSION_IDS)
  DARKHORIZON_EXPANSION_ID = "darkhorizon" unless const_defined?(:DARKHORIZON_EXPANSION_ID)
  DARKHORIZON_LEGACY_EXPANSION_IDS = ["dark_horizon", "pokemon_darkhorizon", "pokemon_dark_horizon"].freeze unless const_defined?(:DARKHORIZON_LEGACY_EXPANSION_IDS)
  INFINITY_EXPANSION_ID = "infinity" unless const_defined?(:INFINITY_EXPANSION_ID)
  INFINITY_LEGACY_EXPANSION_IDS = ["pokemon_infinity"].freeze unless const_defined?(:INFINITY_LEGACY_EXPANSION_IDS)
  INFINITY_LAB_LOCAL_MAP_ID = 41 unless const_defined?(:INFINITY_LAB_LOCAL_MAP_ID)
  INFINITY_LAB_STAIR_LANDINGS = {
    [15, 25] => [13, 24, 4],
    [14, 4]  => [16, 5, 6]
  }.freeze unless const_defined?(:INFINITY_LAB_STAIR_LANDINGS)
  INFINITY_VISUAL_WATCHDOG_FRAMES = 30 unless const_defined?(:INFINITY_VISUAL_WATCHDOG_FRAMES)
  SOLAR_ECLIPSE_EXPANSION_ID = "solar_eclipse" unless const_defined?(:SOLAR_ECLIPSE_EXPANSION_ID)
  SOLAR_ECLIPSE_LEGACY_EXPANSION_IDS = ["solareclipse", "pokemon_solar_eclipse", "pokemon_solareclipse", "solar_light_lunar_dark", "solar_light_and_lunar_dark", "pokemon_solar_light_lunar_dark"].freeze unless const_defined?(:SOLAR_ECLIPSE_LEGACY_EXPANSION_IDS)
  VANGUARD_EXPANSION_ID = "vanguard" unless const_defined?(:VANGUARD_EXPANSION_ID)
  VANGUARD_LEGACY_EXPANSION_IDS = ["pokemon_vanguard"].freeze unless const_defined?(:VANGUARD_LEGACY_EXPANSION_IDS)
  POKEMON_Z_EXPANSION_ID = "pokemon_z" unless const_defined?(:POKEMON_Z_EXPANSION_ID)
  POKEMON_Z_LEGACY_EXPANSION_IDS = ["z", "pokemonz"].freeze unless const_defined?(:POKEMON_Z_LEGACY_EXPANSION_IDS)
  CHAOS_IN_VESITA_EXPANSION_ID = "chaos_in_vesita" unless const_defined?(:CHAOS_IN_VESITA_EXPANSION_ID)
  CHAOS_IN_VESITA_LEGACY_EXPANSION_IDS = ["chaosinvesita", "pokemon_chaos_in_vesita", "chaos_vesita"].freeze unless const_defined?(:CHAOS_IN_VESITA_LEGACY_EXPANSION_IDS)
  DESERTED_EXPANSION_ID = "deserted" unless const_defined?(:DESERTED_EXPANSION_ID)
  DESERTED_LEGACY_EXPANSION_IDS = ["pokemon_deserted"].freeze unless const_defined?(:DESERTED_LEGACY_EXPANSION_IDS)
  GADIR_DELUXE_EXPANSION_ID = "gadir_deluxe" unless const_defined?(:GADIR_DELUXE_EXPANSION_ID)
  GADIR_DELUXE_LEGACY_EXPANSION_IDS = ["gadirdeluxe", "gadirdelux", "pokemon_gadir_deluxe", "pokemon_gadir_delux"].freeze unless const_defined?(:GADIR_DELUXE_LEGACY_EXPANSION_IDS)
  GADIR_DELUXE_INTRO_LOCAL_MAP_ID = 1 unless const_defined?(:GADIR_DELUXE_INTRO_LOCAL_MAP_ID)
  GADIR_DELUXE_HOME_LOCAL_MAP_ID = 78 unless const_defined?(:GADIR_DELUXE_HOME_LOCAL_MAP_ID)
  GADIR_DELUXE_SWITCH_CHAPI_INTRO = 62 unless const_defined?(:GADIR_DELUXE_SWITCH_CHAPI_INTRO)
  GADIR_DELUXE_SWITCH_FININTRO = 63 unless const_defined?(:GADIR_DELUXE_SWITCH_FININTRO)
  GADIR_DELUXE_WAKEUP_SWITCH = 78 unless const_defined?(:GADIR_DELUXE_WAKEUP_SWITCH)
  GADIR_DELUXE_SWITCH_ENCIENDE = 596 unless const_defined?(:GADIR_DELUXE_SWITCH_ENCIENDE)
  GADIR_DELUXE_SWITCH_ULTIMO_PARCHE = 702 unless const_defined?(:GADIR_DELUXE_SWITCH_ULTIMO_PARCHE)
  GADIR_DELUXE_INTRO_IDLE_RECOVERY_FRAMES = 150 unless const_defined?(:GADIR_DELUXE_INTRO_IDLE_RECOVERY_FRAMES)
  GADIR_DELUXE_INTRO_RECOVERY_EVENT_IDS = [3, 5, 9].freeze unless const_defined?(:GADIR_DELUXE_INTRO_RECOVERY_EVENT_IDS)
  GADIR_DELUXE_HOME_WAKEUP_EVENT_ID = 12 unless const_defined?(:GADIR_DELUXE_HOME_WAKEUP_EVENT_ID)
  GADIR_DELUXE_HOME_EXIT_EVENT_IDS = [3, 4].freeze unless const_defined?(:GADIR_DELUXE_HOME_EXIT_EVENT_IDS)
  GADIR_DELUXE_HOME_SAFE_X = 14 unless const_defined?(:GADIR_DELUXE_HOME_SAFE_X)
  GADIR_DELUXE_HOME_SAFE_Y = 12 unless const_defined?(:GADIR_DELUXE_HOME_SAFE_Y)
  GADIR_DELUXE_HOME_SAFE_DIRECTION = 6 unless const_defined?(:GADIR_DELUXE_HOME_SAFE_DIRECTION)
  HOLLOW_WOODS_EXPANSION_ID = "hollow_woods" unless const_defined?(:HOLLOW_WOODS_EXPANSION_ID)
  HOLLOW_WOODS_LEGACY_EXPANSION_IDS = ["hollowwoods", "pokemon_hollow_woods", "pokemon_hollowwoods"].freeze unless const_defined?(:HOLLOW_WOODS_LEGACY_EXPANSION_IDS)
  KEISHOU_EXPANSION_ID = "keishou" unless const_defined?(:KEISHOU_EXPANSION_ID)
  KEISHOU_LEGACY_EXPANSION_IDS = ["pokemon_keishou"].freeze unless const_defined?(:KEISHOU_LEGACY_EXPANSION_IDS)
  UNBREAKABLE_TIES_EXPANSION_ID = "unbreakable_ties" unless const_defined?(:UNBREAKABLE_TIES_EXPANSION_ID)
  UNBREAKABLE_TIES_LEGACY_EXPANSION_IDS = ["unbreakableties", "pokemon_unbreakable_ties", "pokemon_unbreakableties"].freeze unless const_defined?(:UNBREAKABLE_TIES_LEGACY_EXPANSION_IDS)
  DECADES_EXPANSION_ID = "decades" unless const_defined?(:DECADES_EXPANSION_ID)
  DECADES_LEGACY_EXPANSION_IDS = ["pokemon_decades"].freeze unless const_defined?(:DECADES_LEGACY_EXPANSION_IDS)
  DECADES_INTRO_LOCAL_MAP_ID = 1 unless const_defined?(:DECADES_INTRO_LOCAL_MAP_ID)
  DECADES_SPEEDUP_PUNISHMENT_SWITCH = 90 unless const_defined?(:DECADES_SPEEDUP_PUNISHMENT_SWITCH)
  DECADES_STORY_START_LOCAL_MAP_ID = 32 unless const_defined?(:DECADES_STORY_START_LOCAL_MAP_ID)
  DECADES_STORY_START_EVENT_ID = 3 unless const_defined?(:DECADES_STORY_START_EVENT_ID)
  DECADES_BATTLE_MODE_LOCAL_MAP_ID = 33 unless const_defined?(:DECADES_BATTLE_MODE_LOCAL_MAP_ID)
  DECADES_GATEHOUSE_LOCAL_MAP_ID = 91 unless const_defined?(:DECADES_GATEHOUSE_LOCAL_MAP_ID)
  DECADES_GATEHOUSE_TV_EVENT_ID = 3 unless const_defined?(:DECADES_GATEHOUSE_TV_EVENT_ID)
  DECADES_GATEHOUSE_TRASH_EVENT_IDS = [1, 2].freeze unless const_defined?(:DECADES_GATEHOUSE_TRASH_EVENT_IDS)
  DECADES_TRASH_ENCOUNTER_SPECIES = [:TRUBBISH, :GRIMER, :RATTATA, :GULPIN, :ZIGZAGOON].freeze unless const_defined?(:DECADES_TRASH_ENCOUNTER_SPECIES)
  REJUVENATION_EXPANSION_ID = "rejuvenation" unless const_defined?(:REJUVENATION_EXPANSION_ID)
  REJUVENATION_LEGACY_EXPANSION_IDS = ["pokemon_rejuvenation", "rejuv", "pokemon_rejuv"].freeze unless const_defined?(:REJUVENATION_LEGACY_EXPANSION_IDS)
  REJUVENATION_INTRO_LOCAL_MAP_ID = 1 unless const_defined?(:REJUVENATION_INTRO_LOCAL_MAP_ID)
  REJUVENATION_EXPLORATION_LOCAL_MAP_ID = 21 unless const_defined?(:REJUVENATION_EXPLORATION_LOCAL_MAP_ID)
  POKEMON_VOID_EXPANSION_ID = "pokemon_void" unless const_defined?(:POKEMON_VOID_EXPANSION_ID)
  POKEMON_VOID_LEGACY_EXPANSION_IDS = ["void"].freeze unless const_defined?(:POKEMON_VOID_LEGACY_EXPANSION_IDS)
  POKEMON_VOID_SPECIES_ALIASES = {
    :TAMATOO  => :CSF_VOID_TAMATOO,
    :FLARET   => :CSF_VOID_FLARET,
    :CUBBLE   => :CSF_VOID_CUBBLE,
    :SEDIMITE => :CSF_VOID_SEDIMITE
  }.freeze unless const_defined?(:POKEMON_VOID_SPECIES_ALIASES)
  DECADES_STORY_MODE_KIT_ITEMS = [
    [:POKEBALL, 10],
    [:POTION, 5],
    [:ANTIDOTE, 2],
    [:PARLYZHEAL, 2],
    [:REPEL, 3],
    [:ESCAPEROPE, 1]
  ].freeze unless const_defined?(:DECADES_STORY_MODE_KIT_ITEMS)
  DECADES_STORY_REGION_LOCAL_MAP_IDS = [77, 87, 90, 96, 101, 103, 111, 113, 115, 117, 119, 121, 123, 125, 127, 129, 131, 133].freeze unless const_defined?(:DECADES_STORY_REGION_LOCAL_MAP_IDS)
  NEW_PROJECT_HOST_PLAYER_VISUAL_KEYS = ["character_ID", "trainer_type", "outfit", "clothes", "hat", "hat2", "hair",
                                          "skin_tone", "clothes_color", "hat_color", "hat2_color", "hair_color"].freeze unless const_defined?(:NEW_PROJECT_HOST_PLAYER_VISUAL_KEYS)
  NEW_PROJECT_PARTY_ISOLATION_IDS = [KEISHOU_EXPANSION_ID].freeze unless const_defined?(:NEW_PROJECT_PARTY_ISOLATION_IDS)
  NEW_PROJECT_BANKED_GIFT_IDS = [KEISHOU_EXPANSION_ID, OPALO_EXPANSION_ID].freeze unless const_defined?(:NEW_PROJECT_BANKED_GIFT_IDS)
  EMPYREAN_TERRAIN_TAG_TRANSLATIONS = {
    4  => 15, # Essentials Rock -> Infinite Fusion Rock
    6  => 7,  # Essentials StillWater -> Infinite Fusion surfable water
    15 => 4   # Essentials Bridge -> Infinite Fusion Bridge
  }.freeze unless const_defined?(:EMPYREAN_TERRAIN_TAG_TRANSLATIONS)
  EMPYREAN_BRIDGE_SCAN_RADIUS = 3 unless const_defined?(:EMPYREAN_BRIDGE_SCAN_RADIUS)

  class EmpyreanTerrainTagProxy
    attr_reader :source

    def initialize(source)
      @source = source
    end

    def _dump(_depth = -1)
      return Marshal.dump(@source)
    rescue
      return Marshal.dump([])
    end

    def self._load(payload)
      source = Marshal.load(payload) rescue []
      return new(source)
    end

    def [](index)
      if TravelExpansionFramework.respond_to?(:empyrean_bridge_tile_id?) &&
         TravelExpansionFramework.empyrean_bridge_tile_id?(index)
        return 4
      end
      return TravelExpansionFramework.empyrean_translate_terrain_tag(@source[index])
    rescue
      return TravelExpansionFramework.empyrean_translate_terrain_tag(nil)
    end

    def []=(index, value)
      return if !@source.respond_to?(:[]=)
      @source[index] = value
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

  class HollowWoodsGameMode
    DEFAULTS = {
      "levelcap"   => 0,
      "randomizer" => 0,
      "nuzlocke"   => 0,
      "autoheal"   => 0
    }.freeze unless const_defined?(:DEFAULTS)

    def initialize
      DEFAULTS.each { |key, value| instance_variable_set("@#{key}", value) }
    end

    def metadata
      return nil if !defined?(TravelExpansionFramework) ||
                    !TravelExpansionFramework.respond_to?(:new_project_metadata)
      expansion = nil
      expansion = TravelExpansionFramework.current_new_project_expansion_id if TravelExpansionFramework.respond_to?(:current_new_project_expansion_id)
      expansion = TravelExpansionFramework::HOLLOW_WOODS_EXPANSION_ID if expansion.to_s.empty? &&
                                                                        TravelExpansionFramework.const_defined?(:HOLLOW_WOODS_EXPANSION_ID)
      return TravelExpansionFramework.new_project_metadata(expansion)
    rescue
      return nil
    end

    def settings_store
      meta = metadata
      return nil if !meta
      meta["hollow_woods_game_mode"] = {} if !meta["hollow_woods_game_mode"].is_a?(Hash)
      return meta["hollow_woods_game_mode"]
    rescue
      return nil
    end

    def normalize_key(name)
      key = name.to_s
      key = key[0, key.length - 1] if key[-1, 1] == "="
      return key.downcase
    rescue
      return name.to_s.downcase
    end

    def integer(value, fallback = 0)
      if defined?(TravelExpansionFramework) && TravelExpansionFramework.respond_to?(:integer)
        return TravelExpansionFramework.integer(value, fallback)
      end
      return fallback if value.nil?
      return value ? 1 : 0 if value == true || value == false
      return value.to_i
    rescue
      return fallback
    end

    def [](name)
      key = normalize_key(name)
      store = settings_store
      return integer(store[key], DEFAULTS[key] || 0) if store && store.has_key?(key)
      ivar = "@#{key}"
      return integer(instance_variable_get(ivar), DEFAULTS[key] || 0) if instance_variable_defined?(ivar)
      return DEFAULTS[key] || 0
    end

    def []=(name, value)
      key = normalize_key(name)
      normalized = integer(value, DEFAULTS[key] || 0)
      instance_variable_set("@#{key}", normalized)
      store = settings_store
      store[key] = normalized if store
      return normalized
    end

    DEFAULTS.keys.each do |key|
      define_method(key) { self[key] }
      define_method("#{key}=") { |value| self[key] = value }
    end

    def method_missing(name, *args, &block)
      method_name = name.to_s
      if method_name[-1, 1] == "="
        return self[method_name] = args.first
      end
      return self[method_name] if args.empty?
      super
    end

    def respond_to_missing?(_name, _include_private = false)
      return true
    end
  end

  NEW_PROJECT_COMPATIBILITY_PROFILES = {
    "opalo"           => { :aliases => ["pokemon_opalo"], :language => :opalo_translation },
    "pokemon_opalo"   => { :canonical => "opalo" },
    "empyrean"        => { :aliases => ["pokemonempyrean", "pokemon_empyrean"], :identity => :host },
    "pokemonempyrean" => { :canonical => "empyrean" },
    "pokemon_empyrean" => { :canonical => "empyrean" },
    "realidea"        => { :aliases => [], :identity => :host, :language => :realidea_translation },
    "soulstones"      => { :aliases => [], :identity => :host },
    "soulstones2"     => { :aliases => [], :identity => :host },
    "anil"            => { :aliases => ["pokemon_anil", "pokemon_indigo", "indigo"], :identity => :host },
    "pokemon_anil"    => { :canonical => "anil" },
    "pokemon_indigo"  => { :canonical => "anil" },
    "indigo"          => { :canonical => "anil" },
    "bushido"         => { :aliases => ["pokemon_bushido"], :identity => :host },
    "pokemon_bushido" => { :canonical => "bushido" },
    "darkhorizon"     => { :aliases => ["dark_horizon", "pokemon_darkhorizon", "pokemon_dark_horizon"], :identity => :host },
    "dark_horizon"    => { :canonical => "darkhorizon" },
    "pokemon_darkhorizon" => { :canonical => "darkhorizon" },
    "pokemon_dark_horizon" => { :canonical => "darkhorizon" },
    "infinity"        => { :aliases => ["pokemon_infinity"], :identity => :host },
    "pokemon_infinity" => { :canonical => "infinity" },
    "solar_eclipse"   => { :aliases => ["solareclipse", "pokemon_solar_eclipse", "pokemon_solareclipse", "solar_light_lunar_dark", "solar_light_and_lunar_dark", "pokemon_solar_light_lunar_dark"], :identity => :host },
    "solareclipse"    => { :canonical => "solar_eclipse" },
    "pokemon_solar_eclipse" => { :canonical => "solar_eclipse" },
    "pokemon_solareclipse" => { :canonical => "solar_eclipse" },
    "solar_light_lunar_dark" => { :canonical => "solar_eclipse" },
    "solar_light_and_lunar_dark" => { :canonical => "solar_eclipse" },
    "pokemon_solar_light_lunar_dark" => { :canonical => "solar_eclipse" },
    "vanguard"        => { :aliases => ["pokemon_vanguard"], :identity => :host },
    "pokemon_vanguard" => { :canonical => "vanguard" },
    "pokemon_z"       => { :aliases => ["z", "pokemonz"], :identity => :host },
    "z"               => { :canonical => "pokemon_z" },
    "pokemonz"        => { :canonical => "pokemon_z" },
    "chaos_in_vesita" => { :aliases => ["chaosinvesita", "pokemon_chaos_in_vesita", "chaos_vesita"], :identity => :host },
    "chaosinvesita"   => { :canonical => "chaos_in_vesita" },
    "pokemon_chaos_in_vesita" => { :canonical => "chaos_in_vesita" },
    "chaos_vesita"    => { :canonical => "chaos_in_vesita" },
    "deserted"        => { :aliases => ["pokemon_deserted"], :identity => :host },
    "pokemon_deserted" => { :canonical => "deserted" },
    "gadir_deluxe"    => { :aliases => ["gadirdeluxe", "gadirdelux", "pokemon_gadir_deluxe", "pokemon_gadir_delux"], :identity => :host },
    "gadirdeluxe"     => { :canonical => "gadir_deluxe" },
    "gadirdelux"      => { :canonical => "gadir_deluxe" },
    "pokemon_gadir_deluxe" => { :canonical => "gadir_deluxe" },
    "pokemon_gadir_delux" => { :canonical => "gadir_deluxe" },
    "hollow_woods"    => { :aliases => ["hollowwoods", "pokemon_hollow_woods", "pokemon_hollowwoods"], :identity => :host },
    "hollowwoods"     => { :canonical => "hollow_woods" },
    "pokemon_hollow_woods" => { :canonical => "hollow_woods" },
    "pokemon_hollowwoods" => { :canonical => "hollow_woods" },
    "keishou"         => { :aliases => ["pokemon_keishou"], :identity => :host },
    "pokemon_keishou" => { :canonical => "keishou" },
    "unbreakable_ties" => { :aliases => ["unbreakableties", "pokemon_unbreakable_ties", "pokemon_unbreakableties"], :identity => :host },
    "unbreakableties" => { :canonical => "unbreakable_ties" },
    "pokemon_unbreakable_ties" => { :canonical => "unbreakable_ties" },
    "pokemon_unbreakableties" => { :canonical => "unbreakable_ties" },
    "decades"         => { :aliases => ["pokemon_decades"], :identity => :host },
    "pokemon_decades" => { :canonical => "decades" },
    "rejuvenation"    => { :aliases => ["pokemon_rejuvenation", "rejuv", "pokemon_rejuv"], :identity => :host },
    "pokemon_rejuvenation" => { :canonical => "rejuvenation" },
    "rejuv"           => { :canonical => "rejuvenation" },
    "pokemon_rejuv"   => { :canonical => "rejuvenation" },
    "pokemon_void"    => { :aliases => ["void"], :identity => :host },
    "void"            => { :canonical => "pokemon_void" }
  }.freeze unless const_defined?(:NEW_PROJECT_COMPATIBILITY_PROFILES)

  if !defined?(::OrderedHash)
    class ::OrderedHash < Hash
      def initialize
        @keys = []
        super
      end

      def keys
        return @keys ? @keys.clone : super
      end

      def []=(key, value)
        @keys ||= []
        @keys << key if !has_key?(key)
        return super(key, value)
      end

      def self._load(string)
        result = self.new
        keysvalues = Marshal.load(string) rescue [[], []]
        keys = keysvalues[0] || []
        values = keysvalues[1] || []
        for i in 0...keys.length
          result[keys[i]] = values[i]
        end
        return result
      end
    end
  end

  if defined?(::OrderedHash) && !::OrderedHash.respond_to?(:_load)
    class ::OrderedHash
      def self._load(string)
        result = self.new
        keysvalues = Marshal.load(string) rescue [[], []]
        keys = keysvalues[0] || []
        values = keysvalues[1] || []
        for i in 0...keys.length
          result[keys[i]] = values[i] if result.respond_to?(:[]=)
        end
        return result
      end
    end
  end

  def safe_new_project_id_text(value)
    return "" if value.nil?
    text = nil
    if value.is_a?(String)
      text = value
    elsif value.is_a?(Symbol) || value.is_a?(Numeric)
      text = value.to_s
    elsif value.respond_to?(:to_str)
      text = value.to_str rescue nil
    end
    text = "" if text.nil?
    return text.gsub("\\", "/").strip
  rescue Exception
    return ""
  end

  def canonical_new_project_id(expansion_id)
    id = safe_new_project_id_text(expansion_id)
    profile = NEW_PROJECT_COMPATIBILITY_PROFILES[id] rescue nil
    canonical = safe_new_project_id_text(profile[:canonical]) if profile.is_a?(Hash) && profile[:canonical]
    return canonical if canonical && !canonical.empty?
    return id
  rescue Exception
    return safe_new_project_id_text(expansion_id)
  end

  def expansion_id_in_list?(expansion_id, ids)
    @new_project_id_list_depth ||= 0
    return false if @new_project_id_list_depth > 8
    @new_project_id_list_depth += 1
    target = canonical_new_project_id(expansion_id)
    raw_target = safe_new_project_id_text(expansion_id)
    return false if target.empty? && raw_target.empty?
    list = ids.is_a?(Array) ? ids : [ids]
    return list.flatten.compact.any? do |id|
      candidate = canonical_new_project_id(id)
      raw_candidate = safe_new_project_id_text(id)
      (!target.empty? && (candidate == target || raw_candidate == target)) ||
        (!raw_target.empty? && (candidate == raw_target || raw_candidate == raw_target))
    end
  rescue Exception
    return false
  ensure
    @new_project_id_list_depth = [(@new_project_id_list_depth || 1) - 1, 0].max
  end

  def active_project_expansion_id(ids, map_id = nil)
    @new_project_active_cache ||= {}
    runtime_id = current_runtime_expansion_id if respond_to?(:current_runtime_expansion_id)
    return canonical_new_project_id(runtime_id) if expansion_id_in_list?(runtime_id, ids)
    target_map_id = integer(map_id || ($game_map.map_id rescue 0), 0)
    marker = current_expansion_marker if respond_to?(:current_expansion_marker)
    frame = (Graphics.frame_count rescue 0)
    if @new_project_active_cache_frame != frame
      @new_project_active_cache = {}
      @new_project_active_cache_frame = frame
    end
    cache_key = [ids.map(&:to_s).sort.join("|"), target_map_id, marker.to_s, frame]
    return @new_project_active_cache[cache_key] if @new_project_active_cache.has_key?(cache_key)
    if target_map_id > 0 && respond_to?(:current_map_expansion_id)
      map_expansion = current_map_expansion_id(target_map_id)
      if expansion_id_in_list?(map_expansion, ids)
        result = canonical_new_project_id(map_expansion)
        @new_project_active_cache[cache_key] = result
        return result
      end
    end
    if target_map_id <= 0 && expansion_id_in_list?(marker, ids)
      result = canonical_new_project_id(marker)
      @new_project_active_cache[cache_key] = result
      return result
    end
    @new_project_active_cache[cache_key] = nil
    return nil
  rescue
    return nil
  end

  def opalo_expansion_ids
    return [OPALO_EXPANSION_ID] + OPALO_LEGACY_EXPANSION_IDS
  end

  def empyrean_expansion_ids
    return [EMPYREAN_EXPANSION_ID] + EMPYREAN_LEGACY_EXPANSION_IDS
  end

  def anil_expansion_ids
    return [ANIL_EXPANSION_ID] + ANIL_LEGACY_EXPANSION_IDS
  end

  def gadir_deluxe_expansion_ids
    return [GADIR_DELUXE_EXPANSION_ID] + GADIR_DELUXE_LEGACY_EXPANSION_IDS
  end

  def hollow_woods_expansion_ids
    return [HOLLOW_WOODS_EXPANSION_ID] + HOLLOW_WOODS_LEGACY_EXPANSION_IDS
  end

  def infinity_expansion_ids
    return [INFINITY_EXPANSION_ID] + INFINITY_LEGACY_EXPANSION_IDS
  end

  def decades_expansion_ids
    return [DECADES_EXPANSION_ID] + DECADES_LEGACY_EXPANSION_IDS
  end

  def rejuvenation_expansion_ids
    return [REJUVENATION_EXPANSION_ID] + REJUVENATION_LEGACY_EXPANSION_IDS
  end

  def pokemon_void_expansion_ids
    return [POKEMON_VOID_EXPANSION_ID] + POKEMON_VOID_LEGACY_EXPANSION_IDS
  end

  def newly_registered_project_expansion_ids
    return [BUSHIDO_EXPANSION_ID] + BUSHIDO_LEGACY_EXPANSION_IDS +
           [DARKHORIZON_EXPANSION_ID] + DARKHORIZON_LEGACY_EXPANSION_IDS +
           [INFINITY_EXPANSION_ID] + INFINITY_LEGACY_EXPANSION_IDS +
           [SOLAR_ECLIPSE_EXPANSION_ID] + SOLAR_ECLIPSE_LEGACY_EXPANSION_IDS +
           [VANGUARD_EXPANSION_ID] + VANGUARD_LEGACY_EXPANSION_IDS +
           [POKEMON_Z_EXPANSION_ID] + POKEMON_Z_LEGACY_EXPANSION_IDS +
           [CHAOS_IN_VESITA_EXPANSION_ID] + CHAOS_IN_VESITA_LEGACY_EXPANSION_IDS +
           [DESERTED_EXPANSION_ID] + DESERTED_LEGACY_EXPANSION_IDS +
           [GADIR_DELUXE_EXPANSION_ID] + GADIR_DELUXE_LEGACY_EXPANSION_IDS +
           [HOLLOW_WOODS_EXPANSION_ID] + HOLLOW_WOODS_LEGACY_EXPANSION_IDS +
           [KEISHOU_EXPANSION_ID] + KEISHOU_LEGACY_EXPANSION_IDS +
           [UNBREAKABLE_TIES_EXPANSION_ID] + UNBREAKABLE_TIES_LEGACY_EXPANSION_IDS +
           [DECADES_EXPANSION_ID] + DECADES_LEGACY_EXPANSION_IDS +
           [REJUVENATION_EXPANSION_ID] + REJUVENATION_LEGACY_EXPANSION_IDS +
           [POKEMON_VOID_EXPANSION_ID] + POKEMON_VOID_LEGACY_EXPANSION_IDS
  end

  def new_project_expansion_ids
    return opalo_expansion_ids + empyrean_expansion_ids + [
      REALIDEA_EXPANSION_ID,
      SOULSTONES_EXPANSION_ID,
      SOULSTONES2_EXPANSION_ID
    ] + anil_expansion_ids + newly_registered_project_expansion_ids
  end

  def anil_expansion_id?(expansion_id = nil)
    return expansion_id_in_list?(expansion_id, anil_expansion_ids) if !expansion_id.nil? && !expansion_id.to_s.empty?
    return !active_project_expansion_id(anil_expansion_ids).nil?
  end

  def anil_active_now?(map_id = nil)
    return !active_project_expansion_id(anil_expansion_ids, map_id).nil?
  end

  def current_anil_expansion_id(map_id = nil)
    return active_project_expansion_id(anil_expansion_ids, map_id)
  end

  def anil_root_path
    return project_root_path(ANIL_EXPANSION_ID, "Anil", ["Pokemon Anil", "Pokemon Indigo"])
  end

  def anil_metadata
    expansion = active_project_expansion_id(anil_expansion_ids) || ANIL_EXPANSION_ID
    state = state_for(expansion) rescue nil
    return nil if !state || !state.respond_to?(:metadata)
    state.metadata = {} if state.metadata.nil? && state.respond_to?(:metadata=)
    return state.metadata if state.metadata.is_a?(Hash)
    return nil
  rescue
    return nil
  end

  def anil_remember_value(key, value)
    meta = anil_metadata
    meta[key.to_s] = value if meta
    return value
  rescue
    return value
  end

  def anil_value(key, fallback = nil)
    meta = anil_metadata
    return fallback if !meta || !meta.has_key?(key.to_s)
    return meta[key.to_s]
  rescue
    return fallback
  end

  def anil_truthy?(value)
    return false if value.nil?
    return value if value == true || value == false
    text = value.to_s.strip.downcase
    return false if text.empty? || ["false", "0", "no", "off", "nil"].include?(text)
    return true
  rescue
    return false
  end

  def anil_temp_switch_key(map_id, event_id, switch_name = "A")
    map = integer(map_id || ($game_map.map_id rescue 0), 0)
    event = integer(event_id, 0)
    switch = switch_name.to_s
    switch = "A" if switch.empty?
    return [map, event, switch]
  end

  def anil_temp_switch_value(map_id, event_id, switch_name = "A")
    key = anil_temp_switch_key(map_id, event_id, switch_name)
    return false if !defined?($game_self_switches) || !$game_self_switches
    return $game_self_switches[key] ? true : false
  rescue
    return false
  end

  def anil_set_temp_switch(map_id, event_id, switch_name = "A", value = true)
    return false if !defined?($game_self_switches) || !$game_self_switches
    key = anil_temp_switch_key(map_id, event_id, switch_name)
    $game_self_switches[key] = value ? true : false
    $game_map.need_refresh = true if defined?($game_map) && $game_map && $game_map.respond_to?(:need_refresh=)
    return true
  rescue
    return false
  end

  def anil_default_starter_regions
    return [
      ["Kanto",  [:BULBASAUR, :CHARMANDER, :SQUIRTLE]],
      ["Johto",  [:CHIKORITA, :CYNDAQUIL, :TOTODILE]],
      ["Hoenn",  [:TREECKO, :TORCHIC, :MUDKIP]],
      ["Sinnoh", [:TURTWIG, :CHIMCHAR, :PIPLUP]],
      ["Unova",  [:SNIVY, :TEPIG, :OSHAWOTT]],
      ["Kalos",  [:CHESPIN, :FENNEKIN, :FROAKIE]],
      ["Alola",  [:ROWLET, :LITTEN, :POPPLIO]],
      ["Galar",  [:GROOKEY, :SCORBUNNY, :SOBBLE]],
      ["Paldea", [:SPRIGATITO, :FUECOCO, :QUAXLY]]
    ]
  end

  def new_project_identity_expansion_ids
    return new_project_expansion_ids
  end

  def opalo_expansion_id?(expansion_id = nil)
    return expansion_id_in_list?(expansion_id, opalo_expansion_ids) if !expansion_id.nil? && !expansion_id.to_s.empty?
    return !active_project_expansion_id(opalo_expansion_ids).nil?
  end

  def opalo_active_now?(map_id = nil)
    return !active_project_expansion_id(opalo_expansion_ids, map_id).nil?
  end

  def empyrean_expansion_id?(expansion_id = nil)
    return expansion_id_in_list?(expansion_id, empyrean_expansion_ids) if !expansion_id.nil? && !expansion_id.to_s.empty?
    return !active_project_expansion_id(empyrean_expansion_ids).nil?
  end

  def empyrean_active_now?(map_id = nil)
    return !active_project_expansion_id(empyrean_expansion_ids, map_id).nil?
  end

  def empyrean_translate_terrain_tag(tag)
    value = integer(tag, 0) if respond_to?(:integer)
    value = tag.to_i if value.nil?
    return 0 if value <= 0
    return EMPYREAN_TERRAIN_TAG_TRANSLATIONS[value] || value
  rescue
    return 0
  end

  def empyrean_wrap_terrain_tags(expansion_id, terrain_tags)
    return terrain_tags if terrain_tags.nil?
    return terrain_tags if !empyrean_expansion_ids.include?(expansion_id.to_s)
    return terrain_tags if terrain_tags.is_a?(EmpyreanTerrainTagProxy)
    return EmpyreanTerrainTagProxy.new(terrain_tags)
  rescue
    return terrain_tags
  end

  def empyrean_map?(map_id = nil)
    current_map_id = map_id
    current_map_id = $game_map.map_id if current_map_id.nil? && defined?($game_map) && $game_map && $game_map.respond_to?(:map_id)
    return empyrean_expansion_ids.include?(current_map_expansion_id(current_map_id).to_s) if respond_to?(:current_map_expansion_id)
    return empyrean_active_now?(current_map_id)
  rescue
    return false
  end

  def empyrean_bridge_command_list?(list)
    Array(list).any? do |command|
      code = command.respond_to?(:code) ? command.code : command.instance_variable_get(:@code)
      next false if code.to_i != 355 && code.to_i != 655
      params = command.respond_to?(:parameters) ? command.parameters : command.instance_variable_get(:@parameters)
      Array(params).join("\n")[/pbBridge(On|Off)/i]
    end
  rescue
    return false
  end

  def empyrean_bridge_events(game_map)
    return [] if !game_map || !game_map.respond_to?(:events)
    game_map.events.values.select do |event|
      next false if !event
      list = event.respond_to?(:list) ? event.list : event.instance_variable_get(:@list)
      empyrean_bridge_command_list?(list)
    end
  rescue
    return []
  end

  def empyrean_bridge_on_event_at?(game_map, x, y)
    return false if !game_map || !game_map.respond_to?(:events)
    game_map.events.values.any? do |event|
      next false if !event
      ex = event.respond_to?(:x) ? event.x : event.instance_variable_get(:@x)
      ey = event.respond_to?(:y) ? event.y : event.instance_variable_get(:@y)
      next false if ex.to_i != x.to_i || ey.to_i != y.to_i
      list = event.respond_to?(:list) ? event.list : event.instance_variable_get(:@list)
      Array(list).any? do |command|
        code = command.respond_to?(:code) ? command.code : command.instance_variable_get(:@code)
        next false if code.to_i != 355 && code.to_i != 655
        params = command.respond_to?(:parameters) ? command.parameters : command.instance_variable_get(:@parameters)
        Array(params).join("\n")[/pbBridgeOn/i]
      end
    end
  rescue
    return false
  end

  def empyrean_bridge_surface_tile_ids_at(game_map, x, y)
    return [] if !game_map || !game_map.respond_to?(:valid?) || !game_map.valid?(x, y)
    data = game_map.respond_to?(:data) ? game_map.data : game_map.instance_variable_get(:@map).data
    passages = game_map.respond_to?(:passages) ? game_map.passages : game_map.instance_variable_get(:@passages)
    priorities = game_map.respond_to?(:priorities) ? game_map.priorities : game_map.instance_variable_get(:@priorities)
    terrain_tags = game_map.respond_to?(:terrain_tags) ? game_map.terrain_tags : game_map.instance_variable_get(:@terrain_tags)
    return [] if !data || !passages || !priorities || !terrain_tags
    ids = []
    [2, 1, 0].each do |layer|
      tile_id = data[x, y, layer] rescue nil
      next if tile_id.nil? || tile_id.to_i <= 0
      tag_value = terrain_tags[tile_id] rescue 0
      translated = empyrean_translate_terrain_tag(tag_value)
      terrain = GameData::TerrainTag.try_get(translated) if defined?(GameData) && defined?(GameData::TerrainTag)
      if terrain && terrain.respond_to?(:bridge) && terrain.bridge
        ids << tile_id.to_i
        next
      end
      next if terrain && terrain.respond_to?(:ignore_passability) && terrain.ignore_passability
      next if terrain && terrain.respond_to?(:id) && terrain.id != :None && translated.to_i != 0
      passage = passages[tile_id] rescue nil
      priority = priorities[tile_id] rescue 0
      next if passage.nil?
      ids << tile_id.to_i if priority.to_i > 0 && (passage.to_i & 0x0f) == 0
    end
    return ids.uniq
  rescue
    return []
  end

  def empyrean_prepare_bridge_cache!(game_map)
    return false if !game_map || !empyrean_map?(game_map.map_id)
    map_id = game_map.map_id
    @empyrean_bridge_tile_ids_by_map_id ||= {}
    @empyrean_bridge_coords_by_map_id ||= {}
    return true if @empyrean_bridge_tile_ids_by_map_id[map_id] &&
                   @empyrean_bridge_coords_by_map_id[map_id]
    tile_ids = {}
    coords = {}
    queue = []
    radius = EMPYREAN_BRIDGE_SCAN_RADIUS
    empyrean_bridge_events(game_map).each do |event|
      ex = event.respond_to?(:x) ? event.x : event.instance_variable_get(:@x)
      ey = event.respond_to?(:y) ? event.y : event.instance_variable_get(:@y)
      (-radius..radius).each do |dx|
        (-radius..radius).each do |dy|
          x = ex.to_i + dx
          y = ey.to_i + dy
          ids = empyrean_bridge_surface_tile_ids_at(game_map, x, y)
          next if ids.empty?
          key = "#{x},#{y}"
          next if coords[key]
          coords[key] = true
          ids.each { |tile_id| tile_ids[tile_id] = true }
          queue << [x, y]
        end
      end
    end
    checked = 0
    until queue.empty? || checked > 1200
      checked += 1
      x, y = queue.shift
      [[1, 0], [-1, 0], [0, 1], [0, -1]].each do |dx, dy|
        nx = x + dx
        ny = y + dy
        key = "#{nx},#{ny}"
        next if coords[key]
        ids = empyrean_bridge_surface_tile_ids_at(game_map, nx, ny)
        next if ids.empty?
        coords[key] = true
        ids.each { |tile_id| tile_ids[tile_id] = true }
        queue << [nx, ny]
      end
    end
    @empyrean_bridge_tile_ids_by_map_id[map_id] = tile_ids
    @empyrean_bridge_coords_by_map_id[map_id] = coords
    game_map.instance_variable_set(:@tef_empyrean_bridge_tile_ids, tile_ids)
    game_map.instance_variable_set(:@tef_empyrean_bridge_coords, coords)
    log("[empyrean] bridge cache map=#{map_id} tiles=#{tile_ids.length} coords=#{coords.length}") if respond_to?(:log) && !tile_ids.empty?
    return true
  rescue => e
    log("[empyrean] bridge cache failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def empyrean_bridge_tile_id?(tile_id, map_id = nil)
    return false if tile_id.nil?
    current_map_id = map_id
    current_map_id = $game_map.map_id if current_map_id.nil? && defined?($game_map) && $game_map && $game_map.respond_to?(:map_id)
    return false if !current_map_id || !empyrean_map?(current_map_id)
    @empyrean_bridge_tile_ids_by_map_id ||= {}
    empyrean_prepare_bridge_cache!($game_map) if defined?($game_map) && $game_map &&
                                                 $game_map.respond_to?(:map_id) &&
                                                 $game_map.map_id == current_map_id &&
                                                 !@empyrean_bridge_tile_ids_by_map_id[current_map_id]
    cache = @empyrean_bridge_tile_ids_by_map_id[current_map_id]
    return cache && cache[tile_id.to_i] ? true : false
  rescue
    return false
  end

  def empyrean_bridge_surface_coord?(game_map, x, y)
    return false if !game_map || !game_map.respond_to?(:valid?) || !game_map.valid?(x, y)
    empyrean_prepare_bridge_cache!(game_map)
    coords = game_map.instance_variable_get(:@tef_empyrean_bridge_coords)
    return true if coords && coords["#{x},#{y}"]
    return !empyrean_bridge_surface_tile_ids_at(game_map, x, y).empty?
  rescue
    return false
  end

  def empyrean_set_bridge_height!(height = 2)
    return true if !defined?($PokemonGlobal) || !$PokemonGlobal
    value = integer(height, 2) if respond_to?(:integer)
    value = height.to_i if value.nil?
    value = 2 if value <= 0
    $PokemonGlobal.bridge = value if $PokemonGlobal.respond_to?(:bridge=)
    return true
  rescue
    return true
  end

  def empyrean_clear_bridge_height!
    $PokemonGlobal.bridge = 0 if defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.respond_to?(:bridge=)
    return true
  rescue
    return true
  end

  def empyrean_prepare_bridge_for_step!(game_map, x, y, d)
    return false if !empyrean_map?(game_map.map_id)
    return false if ![2, 4, 6, 8].include?(d.to_i)
    new_x = x + (d.to_i == 6 ? 1 : d.to_i == 4 ? -1 : 0)
    new_y = y + (d.to_i == 2 ? 1 : d.to_i == 8 ? -1 : 0)
    if empyrean_bridge_on_event_at?(game_map, x, y) ||
       empyrean_bridge_on_event_at?(game_map, new_x, new_y) ||
       empyrean_bridge_surface_coord?(game_map, x, y) ||
       empyrean_bridge_surface_coord?(game_map, new_x, new_y)
      return empyrean_set_bridge_height!(2)
    end
    return false
  rescue
    return false
  end

  def empyrean_bridge_step_passable?(game_map, x, y, d)
    return false if !empyrean_map?(game_map.map_id)
    return false if !defined?($PokemonGlobal) || !$PokemonGlobal || !$PokemonGlobal.respond_to?(:bridge) || $PokemonGlobal.bridge.to_i <= 0
    return false if ![2, 4, 6, 8].include?(d.to_i)
    new_x = x + (d.to_i == 6 ? 1 : d.to_i == 4 ? -1 : 0)
    new_y = y + (d.to_i == 2 ? 1 : d.to_i == 8 ? -1 : 0)
    return empyrean_bridge_surface_coord?(game_map, x, y) ||
           empyrean_bridge_surface_coord?(game_map, new_x, new_y)
  rescue
    return false
  end

  def gadir_deluxe_active_now?(map_id = nil)
    return !active_project_expansion_id(gadir_deluxe_expansion_ids, map_id).nil?
  end

  def hollow_woods_active_now?(map_id = nil)
    return !active_project_expansion_id(hollow_woods_expansion_ids, map_id).nil?
  end

  def infinity_active_now?(map_id = nil)
    return !active_project_expansion_id(infinity_expansion_ids, map_id).nil?
  end

  def rejuvenation_expansion_id?(expansion_id = nil)
    return expansion_id_in_list?(expansion_id, rejuvenation_expansion_ids) if !expansion_id.nil? && !expansion_id.to_s.empty?
    return !active_project_expansion_id(rejuvenation_expansion_ids).nil?
  end

  def rejuvenation_active_now?(map_id = nil)
    return !active_project_expansion_id(rejuvenation_expansion_ids, map_id).nil?
  end

  def current_rejuvenation_expansion_id(map_id = nil)
    return active_project_expansion_id(rejuvenation_expansion_ids, map_id)
  end

  def void_map_block_id?(map_id = nil)
    target = integer(map_id || ($game_map.map_id rescue 0), 0)
    return false if target <= 0
    manifest = manifest_for(POKEMON_VOID_EXPANSION_ID) if respond_to?(:manifest_for)
    if manifest.is_a?(Hash)
      block = manifest[:map_block] || manifest["map_block"]
      if block.is_a?(Hash)
        start_id = integer(block[:start] || block["start"], 0)
        size = integer(block[:size] || block["size"], 0)
        return true if start_id > 0 && size > 0 && target >= start_id && target < start_id + size
      end
    end
    # Void's first release import is fixed at 48000. Keep this explicit fallback
    # because message rendering can run before the active expansion marker is set.
    return target >= 48000 && target < 49000
  rescue
    target = (map_id || ($game_map.map_id rescue 0)).to_i rescue 0
    return target >= 48000 && target < 49000
  end

  def void_active_now?(map_id = nil)
    return true if void_map_block_id?(map_id)
    current_map = integer(($game_map.map_id rescue 0), 0)
    local_map = integer(map_id, 0)
    return true if local_map > 0 && local_map < 1000 && void_map_block_id?(current_map)
    return !active_project_expansion_id(pokemon_void_expansion_ids, map_id).nil?
  end

  def current_void_expansion_id(map_id = nil)
    return POKEMON_VOID_EXPANSION_ID if void_map_block_id?(map_id)
    current_map = integer(($game_map.map_id rescue 0), 0)
    local_map = integer(map_id, 0)
    return POKEMON_VOID_EXPANSION_ID if local_map > 0 && local_map < 1000 && void_map_block_id?(current_map)
    return active_project_expansion_id(pokemon_void_expansion_ids, map_id)
  end

  def rejuvenation_root_path
    return project_root_path(REJUVENATION_EXPANSION_ID, "Rejuvenation", ["Pokemon Rejuvenation", "Rejuv", "Pokemon Rejuv"])
  end

  def infinity_local_map_id(map_id = nil)
    current_map = integer(map_id || ($game_map.map_id rescue 0), 0)
    expansion = active_project_expansion_id(infinity_expansion_ids, current_map)
    return nil if expansion.to_s.empty?
    return local_map_id_for(expansion, current_map) if respond_to?(:local_map_id_for)
    return current_map
  rescue
    return nil
  end

  def infinity_lab_map?(map_id = nil)
    current_map = integer(map_id || ($game_map.map_id rescue 0), 0)
    return true if current_map == INFINITY_LAB_LOCAL_MAP_ID && infinity_active_now?
    return integer(infinity_local_map_id(current_map), 0) == INFINITY_LAB_LOCAL_MAP_ID
  rescue
    return false
  end

  def infinity_lab_stair_landing_for(x, y)
    return INFINITY_LAB_STAIR_LANDINGS[[integer(x, 0), integer(y, 0)]]
  rescue
    return nil
  end

  def event_command_code(command)
    return command.code if command && command.respond_to?(:code)
    return command.instance_variable_get(:@code) if command
    return nil
  rescue
    return nil
  end

  def infinity_lab_stair_resume_index(list, index)
    return nil if !list.respond_to?(:[])
    i = integer(index, -1) + 1
    return nil if i <= 0
    saw_route = false
    while i < list.length
      code = event_command_code(list[i])
      if code == 209
        saw_route = true
        i += 1
        next
      end
      if code == 509 && saw_route
        i += 1
        next
      end
      return i if code == 223 && saw_route
      break
    end
    return nil
  rescue
    return nil
  end

  def rewrite_infinity_lab_stair_transfer(source_map_id, event_id, index, list, target_map_id, target_x, target_y, target_direction = 0)
    return nil if !infinity_lab_map?(source_map_id)
    return nil if !infinity_lab_map?(target_map_id)
    landing = infinity_lab_stair_landing_for(target_x, target_y)
    return nil if !landing
    final_x, final_y, final_direction = landing
    resume_index = infinity_lab_stair_resume_index(list, index)
    @infinity_pending_lab_stair_cleanup = {
      :map_id    => integer(target_map_id, 0),
      :x         => final_x,
      :y         => final_y,
      :event_id  => integer(event_id, 0),
      :resume    => resume_index,
      :direction => final_direction
    }
    log("[infinity] rewrote lab stair transfer event #{event_id}: #{target_x},#{target_y} -> #{final_x},#{final_y}; resume=#{resume_index || "next"}") if respond_to?(:log)
    return {
      :map_id       => target_map_id,
      :x            => final_x,
      :y            => final_y,
      :direction    => final_direction || target_direction,
      :resume_index => resume_index
    }
  rescue => e
    log("[infinity] lab stair transfer rewrite failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def finish_infinity_lab_stair_transfer_rewrite!(reason = "transfer")
    pending = @infinity_pending_lab_stair_cleanup
    return false if !pending.is_a?(Hash)
    return false if !defined?($game_map) || !$game_map || !defined?($game_player) || !$game_player
    if integer($game_map.map_id, 0) != integer(pending[:map_id], 0)
      @infinity_pending_lab_stair_cleanup = nil
      return false
    end
    $game_player.through = false if $game_player.respond_to?(:through=)
    $game_player.transparent = false if $game_player.respond_to?(:transparent=)
    if $game_player.respond_to?(:direction=) && integer(pending[:direction], 0) > 0
      $game_player.direction = integer(pending[:direction], 0)
    end
    $game_player.straighten if $game_player.respond_to?(:straighten)
    @infinity_pending_lab_stair_cleanup = nil
    log("[infinity] finished lab stair transfer cleanup after #{reason}: #{$game_player.x},#{$game_player.y}") if respond_to?(:log)
    return true
  rescue => e
    @infinity_pending_lab_stair_cleanup = nil
    log("[infinity] lab stair transfer cleanup failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def decades_active_now?(map_id = nil)
    return !active_project_expansion_id(decades_expansion_ids, map_id).nil?
  end

  def decades_intro_map?(map_id = nil)
    map = integer(map_id, 0)
    map = $game_map.map_id if map <= 0 && defined?($game_map) && $game_map
    expansion = active_project_expansion_id(decades_expansion_ids, map)
    return false if expansion.nil?
    local_map = local_map_id_for(expansion, map) rescue map
    return integer(local_map, 0) == DECADES_INTRO_LOCAL_MAP_ID
  rescue
    return false
  end

  def decades_speedup_punishment_switch?(switch_id, map_id = nil)
    return integer(switch_id, 0) == DECADES_SPEEDUP_PUNISHMENT_SWITCH &&
           decades_intro_map?(map_id)
  rescue
    return false
  end

  def decades_speedup_punishment_branch?(params, map_id = nil, _event_id = nil)
    data = Array(params)
    return false if data[0].to_i != 0
    return false if data[2].to_i != 0
    return decades_speedup_punishment_switch?(data[1], map_id)
  rescue
    return false
  end

  def decades_speedup_punishment_assignment?(params, map_id = nil)
    data = Array(params)
    return false if data.length < 3
    first = integer(data[0], 0)
    last = integer(data[1], first)
    value = integer(data[2], 0)
    return false if value != 0
    return first <= DECADES_SPEEDUP_PUNISHMENT_SWITCH &&
           last >= DECADES_SPEEDUP_PUNISHMENT_SWITCH &&
           decades_intro_map?(map_id)
  rescue
    return false
  end

  def decades_clear_speedup_punishment!(source = nil)
    if defined?($game_switches) && $game_switches
      $game_switches[DECADES_SPEEDUP_PUNISHMENT_SWITCH] = false
      $game_map.need_refresh = true if defined?($game_map) && $game_map
    end
    record_release_shim_hit("decades_speedup_punishment", "startup", "blocked") if respond_to?(:record_release_shim_hit)
    log("[decades] blocked intro speed-up punishment#{source ? " from #{source}" : ""}") if respond_to?(:log)
    return true
  rescue => e
    log("[decades] speed-up punishment guard failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def decades_story_region_transfer?(source_map_id, event_id, target_map_id)
    source_map = integer(source_map_id, 0)
    expansion = active_project_expansion_id(decades_expansion_ids, source_map)
    return false if expansion.nil?
    source_local = local_map_id_for(expansion, source_map) rescue source_map
    target_local = local_map_id_for(expansion, target_map_id) rescue target_map_id
    return integer(source_local, 0) == DECADES_STORY_START_LOCAL_MAP_ID &&
           integer(event_id, 0) == DECADES_STORY_START_EVENT_ID &&
           DECADES_STORY_REGION_LOCAL_MAP_IDS.include?(integer(target_local, 0))
  rescue
    return false
  end

  def decades_note_story_region_transfer!(target_map_id = nil, source = nil)
    meta = new_project_metadata(DECADES_EXPANSION_ID) || new_project_metadata
    if meta
      meta["story_region_started"] = true
      meta["story_region_target_map"] = integer(target_map_id, 0) if target_map_id
      meta["story_region_started_at"] = timestamp_string if respond_to?(:timestamp_string)
    end
    record_release_shim_hit("decades_story_region_transfer", "story_transfer", "single_route") if respond_to?(:record_release_shim_hit)
    log("[decades] ended startup city selector after first route#{source ? " from #{source}" : ""}") if respond_to?(:log)
    return true
  rescue => e
    log("[decades] story region transfer marker failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def decades_safe_intro_bag_add(item, qty = 1, *args)
    meta = new_project_metadata(DECADES_EXPANSION_ID) || new_project_metadata
    grants = nil
    if meta
      meta["intro_item_grants"] = {} if !meta["intro_item_grants"].is_a?(Hash)
      grants = meta["intro_item_grants"]
    end
    key = item.to_s.upcase
    if grants && grants[key]
      record_release_shim_hit("decades_intro_item_grant", "item_handlers", "deduped") if respond_to?(:record_release_shim_hit)
      log("[decades] skipped duplicate intro item grant #{key}") if respond_to?(:log)
      return true
    end
    result = false
    result = decades_store_story_item(item, qty) if respond_to?(:decades_store_story_item)
    result = $bag.add(item, qty, *args) if !result && defined?($bag) && $bag && $bag.respond_to?(:add)
    grants[key] = { "qty" => integer(qty, 1), "granted_at" => (timestamp_string if respond_to?(:timestamp_string)) } if grants
    record_release_shim_hit("decades_intro_item_grant", "item_handlers", "once") if respond_to?(:record_release_shim_hit)
    return result
  rescue => e
    log("[decades] intro item grant failed safely for #{item.inspect}: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def decades_item_exists?(item)
    return release_item_exists?(item) if respond_to?(:release_item_exists?)
    return GameData::Item.exists?(item) if defined?(GameData::Item) && GameData::Item.respond_to?(:exists?)
    return !GameData::Item.get(item).nil? if defined?(GameData::Item) && GameData::Item.respond_to?(:get)
    return true
  rescue
    return false
  end

  def decades_store_story_item(item, qty = 1)
    return false if !decades_item_exists?(item)
    quantity = [integer(qty, 1), 1].max
    if defined?($PokemonBag) && $PokemonBag
      return true if $PokemonBag.respond_to?(:pbStoreItem) && $PokemonBag.pbStoreItem(item, quantity)
      return true if $PokemonBag.respond_to?(:add) && $PokemonBag.add(item, quantity)
    end
    if defined?($bag) && $bag
      return true if $bag.respond_to?(:pbStoreItem) && $bag.pbStoreItem(item, quantity)
      return true if $bag.respond_to?(:add) && $bag.add(item, quantity)
    end
    return false
  rescue => e
    log("[decades] story kit item #{item.inspect} skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def decades_grant_story_mode_kit!(source = nil)
    meta = new_project_metadata(DECADES_EXPANSION_ID) || new_project_metadata
    if meta
      meta["story_mode_item_kit"] = {} if !meta["story_mode_item_kit"].is_a?(Hash)
      kit = meta["story_mode_item_kit"]
      return true if kit["granted"]
    elsif @decades_story_mode_kit_granted
      return true
    end
    granted = {}
    DECADES_STORY_MODE_KIT_ITEMS.each do |item, qty|
      next if !decades_store_story_item(item, qty)
      granted[item.to_s] = integer(qty, 1)
    end
    if meta
      meta["story_mode_item_kit"]["granted"] = true
      meta["story_mode_item_kit"]["source"] = source.to_s if source
      meta["story_mode_item_kit"]["items"] = granted
      meta["story_mode_item_kit"]["granted_at"] = timestamp_string if respond_to?(:timestamp_string)
    end
    @decades_story_mode_kit_granted = true
    record_release_shim_hit("decades_story_mode_kit", "item_handlers", "granted_once") if respond_to?(:record_release_shim_hit)
    log("[decades] granted host-safe Story Mode item kit#{source ? " from #{source}" : ""}: #{granted.inspect}") if respond_to?(:log)
    return true
  rescue => e
    log("[decades] story mode kit grant failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def decades_character_select!(*args)
    ensure_player_global! if respond_to?(:ensure_player_global!)
    apply_new_project_gender_selection! if respond_to?(:apply_new_project_gender_selection!)
    apply_host_player_visuals!(DECADES_EXPANSION_ID) if respond_to?(:apply_host_player_visuals!)
    record_release_shim_hit("pbCharacterSelect", "startup", "host_identity") if respond_to?(:record_release_shim_hit)
    log("[decades] skipped imported character selector; host player identity retained") if respond_to?(:log)
    return true
  rescue => e
    log("[decades] character selector fallback failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def decades_current_local_map_id(map_id = nil)
    map = integer(map_id, 0)
    map = $game_map.map_id if map <= 0 && defined?($game_map) && $game_map
    expansion = active_project_expansion_id(decades_expansion_ids, map)
    return 0 if expansion.nil?
    return integer(local_map_id_for(expansion, map), map)
  rescue
    return integer(map_id, 0)
  end

  def decades_current_event_id(fallback_event_id = nil)
    context = current_runtime_context if respond_to?(:current_runtime_context)
    event_id = integer(context[:event_id], 0) if context.is_a?(Hash)
    event_id = integer(fallback_event_id, 0) if event_id.to_i <= 0
    return event_id.to_i
  rescue
    return integer(fallback_event_id, 0)
  end

  def decades_current_event(event_id = nil)
    id = decades_current_event_id(event_id)
    return nil if id <= 0 || !defined?($game_map) || !$game_map || !$game_map.respond_to?(:events)
    return $game_map.events[id] rescue nil
  end

  def current_or_facing_event(event = nil, event_id = nil)
    return event if event && event.respond_to?(:id)
    resolved = decades_current_event(event_id)
    if resolved.nil? && defined?($game_player) && $game_player
      if $game_player.respond_to?(:pbFacingEvent)
        resolved = $game_player.pbFacingEvent(true) rescue nil
        resolved ||= $game_player.pbFacingEvent rescue nil
      end
    end
    return resolved
  rescue
    return event
  end

  def decades_current_event_name(event_id = nil)
    event = decades_current_event(event_id)
    return "" if event.nil?
    return event.name.to_s if event.respond_to?(:name)
    return event.instance_variable_get(:@event).name.to_s rescue ""
  end

  def imported_event_signature(event = nil, event_id = nil)
    resolved = current_or_facing_event(event, event_id)
    parts = []
    parts << resolved.name if resolved && resolved.respond_to?(:name)
    parts << resolved.character_name if resolved && resolved.respond_to?(:character_name)
    raw_event = resolved.instance_variable_get(:@event) rescue nil
    parts << raw_event.name if raw_event && raw_event.respond_to?(:name)
    page = resolved.instance_variable_get(:@page) rescue nil
    graphic = page.graphic if page && page.respond_to?(:graphic)
    parts << graphic.character_name if graphic && graphic.respond_to?(:character_name)
    Array(resolved.list).each do |command|
      code = command.respond_to?(:code) ? command.code.to_i : 0
      next if ![108, 408].include?(code)
      parts.concat(Array(command.parameters))
    end if resolved && resolved.respond_to?(:list)
    return parts.compact.map(&:to_s).join(" ")
  rescue
    return ""
  end

  def imported_event_looks_like_tv?(event = nil, event_id = nil)
    signature = imported_event_signature(event, event_id)
    text = signature.downcase
    return false if text.empty?
    return false if text.include?("headbutttree")
    return true if text.include?("television")
    return true if text.include?("tvvisual")
    return true if text.include?(" tv")
    return true if text.include?("_tv")
    return true if text.include?("tv_")
    return true if text.include?("monitor")
    return true if text.include?("screen")
    return true if text.include?("broadcast")
    return true if text.include?("news")
    return false
  rescue
    return false
  end

  def imported_tv_event?(event = nil, event_id = nil, map_id = nil, expansion_ids = nil)
    map = integer(map_id, 0)
    map = $game_map.map_id if map <= 0 && defined?($game_map) && $game_map
    expansion = nil
    if expansion_ids
      expansion = active_project_expansion_id(Array(expansion_ids), map) if respond_to?(:active_project_expansion_id)
      return false if expansion.nil?
    else
      expansion = current_map_expansion_id(map) if respond_to?(:current_map_expansion_id)
      return false if expansion.nil? || expansion.to_s.empty?
    end
    return imported_event_looks_like_tv?(event, event_id)
  rescue
    return false
  end

  def decades_gatehouse_tv_event?(event_id = nil, map_id = nil)
    return imported_tv_event?(nil, event_id, map_id, decades_expansion_ids)
  rescue
    return false
  end

  def decades_gatehouse_trash_event?(event_id = nil, map_id = nil)
    return false if !decades_active_now?(map_id)
    return false if decades_current_local_map_id(map_id) != DECADES_GATEHOUSE_LOCAL_MAP_ID
    id = decades_current_event_id(event_id)
    return true if DECADES_GATEHOUSE_TRASH_EVENT_IDS.include?(id)
    return decades_current_event_name(id) =~ /Trash/i ? true : false
  rescue
    return false
  end

  def decades_watch_tv!(*_args)
    record_release_shim_hit("decades.pbWatchTV", "item_handlers", "local_broadcast") if respond_to?(:record_release_shim_hit)
    pbMessage(_INTL("The TV is showing a local news report.")) if defined?(pbMessage)
    return true
  rescue => e
    log("[decades] TV event skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def watch_imported_tv!(event = nil, *_args)
    expansion = current_map_expansion_id if respond_to?(:current_map_expansion_id)
    record_release_shim_hit("pbHeadbutt.tv_redirect", "item_handlers", expansion || "imported") if respond_to?(:record_release_shim_hit)
    if expansion && decades_expansion_ids.include?(expansion.to_s)
      return decades_watch_tv!(event)
    end
    pbMessage(_INTL("The TV is showing a local program.")) if defined?(pbMessage)
    return true
  rescue => e
    log("[tv] imported TV event skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def decades_resolve_trash_species
    DECADES_TRASH_ENCOUNTER_SPECIES.each do |species|
      resolved = resolve_expansion_species(DECADES_EXPANSION_ID, species) if respond_to?(:resolve_expansion_species)
      resolved ||= species
      exists = !defined?(GameData::Species) || GameData::Species.exists?(resolved) rescue false
      return resolved if exists
    end
    return :RATTATA
  rescue
    return :RATTATA
  end

  def decades_trash_encounter!(*_args)
    return false if !decades_gatehouse_trash_event?
    record_release_shim_hit("TrashCans.pbTrashEncounter", "encounters", "decades_gatehouse") if respond_to?(:record_release_shim_hit)
    if rand(100) < 25
      species = decades_resolve_trash_species
      pbMessage(_INTL("Something jumped out!")) if defined?(pbMessage)
      return start_decades_wild_battle(species, decades_effective_battle_level(3)) if respond_to?(:start_decades_wild_battle)
    end
    pbMessage(_INTL("There's nothing interesting inside.")) if defined?(pbMessage)
    return false
  rescue => e
    log("[decades] trash can encounter skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def decades_headbutt!(event = nil, *_args)
    event_id = event.respond_to?(:id) ? event.id : nil
    return nil if !imported_tv_event?(event, event_id)
    return watch_imported_tv!(event)
  rescue => e
    log("[decades] headbutt TV redirect failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def decades_prepare_event_script(script, map_id = nil, event_id = nil)
    return script if script.nil? || !decades_active_now?(map_id)
    text = script.to_s
    rewritten = text.dup
    if rewritten.include?("pbCharacterSelect")
      rewritten.gsub!(/(^|\n)([ \t]*)pbCharacterSelect[ \t]*(?:\(\s*\))?[ \t]*(?=\r?\n|\z)/) do
        "#{$1}#{$2}TravelExpansionFramework.decades_character_select!"
      end
    end
    if decades_intro_map?(map_id) && rewritten.include?("$bag.add")
      rewritten.gsub!(/\$bag\.add\s*\(/, "TravelExpansionFramework.decades_safe_intro_bag_add(")
    end
    if rewritten != text
      record_release_shim_hit("decades_event_script", "startup", "rewritten") if respond_to?(:record_release_shim_hit)
      log("[decades] rewrote startup event script #{event_id || "?"} on map #{map_id || "?"}") if respond_to?(:log)
    end
    return rewritten
  rescue => e
    log("[decades] event script preparation failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return script
  end

  def hollow_woods_game_mode
    @hollow_woods_game_mode = HollowWoodsGameMode.new if !@hollow_woods_game_mode.is_a?(HollowWoodsGameMode)
    return @hollow_woods_game_mode
  rescue
    return HollowWoodsGameMode.new
  end

  def hollow_woods_apply_game_mode_defaults!(source = nil)
    mode = hollow_woods_game_mode
    mode.levelcap = 0
    mode.randomizer = 0
    mode.nuzlocke = 0
    mode.autoheal = 0
    if defined?($GameMode)
      $GameMode = mode if $GameMode.nil? || !$GameMode.respond_to?(:randomizer)
    else
      $GameMode = mode
    end
    meta = new_project_metadata(HOLLOW_WOODS_EXPANSION_ID) || new_project_metadata
    if meta
      meta["hollow_woods_game_mode_source"] = source.to_s if source
      meta["hollow_woods_game_mode_ready"] = true
    end
    log("[hollow_woods] applied host-safe game mode defaults#{source ? " from #{source}" : ""}") if respond_to?(:log)
    return mode
  rescue => e
    log("[hollow_woods] game mode default setup failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def hollow_woods_watch_tv!(*_args)
    hollow_woods_apply_game_mode_defaults!(:watch_tv) if respond_to?(:hollow_woods_apply_game_mode_defaults!)
    pbMessage(_INTL("The TV is showing a quiet local broadcast.")) if defined?(pbMessage)
    return true
  rescue => e
    log("[hollow_woods] TV event skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def hollow_woods_starter_species(species_ref)
    raw = species_ref.to_s.upcase.gsub(/[^A-Z0-9_]/, "")
    raw = "REMORAID" if ["REMOIRAID", "REMOIRAD"].include?(raw)
    raw = "VULPIX" if raw.empty?
    resolved = resolve_expansion_species(HOLLOW_WOODS_EXPANSION_ID, raw.to_sym) if respond_to?(:resolve_expansion_species)
    resolved ||= raw.to_sym
    data = GameData::Species.try_get(resolved) rescue nil
    data ||= GameData::Species.try_get(raw.to_sym) rescue nil
    return data.species if data && data.respond_to?(:species)
    return data.id if data && data.respond_to?(:id)
    fallback = GameData::Species.try_get(:VULPIX) rescue nil
    return fallback.species if fallback && fallback.respond_to?(:species)
    return :VULPIX
  rescue
    return :VULPIX
  end

  def hollow_woods_species_name(species)
    data = GameData::Species.try_get(species) rescue nil
    return data.name if data && data.respond_to?(:name)
    return species.to_s.split("_").map { |part| part.capitalize }.join(" ")
  rescue
    return species.to_s
  end

  def hollow_woods_choose_starter!(*species_refs)
    hollow_woods_apply_game_mode_defaults!(:starter_selection) if respond_to?(:hollow_woods_apply_game_mode_defaults!)
    species = Array(species_refs).flatten.map { |entry| hollow_woods_starter_species(entry) }.compact
    species = [:VULPIX, :REMORAID, :COTTONEE] if species.empty?
    species.uniq!
    names = species.map { |entry| hollow_woods_species_name(entry) }
    cancel_index = names.length
    choice = 0
    if defined?(pbMessage)
      choice = pbMessage(_INTL("Which Pokemon will travel with you?"), names + [_INTL("Cancel")], cancel_index, nil, 0)
    end
    return nil if choice.nil? || choice.to_i < 0 || choice.to_i >= species.length
    selected = species[choice.to_i]
    result = false
    if defined?(pbAddPokemon)
      result = pbAddPokemon(selected, 5)
    elsif defined?(pbAddPokemonSilent)
      result = pbAddPokemonSilent(selected, 5)
    end
    meta = new_project_metadata(HOLLOW_WOODS_EXPANSION_ID) || new_project_metadata
    if meta
      meta["hollow_woods_starter_species"] = selected.to_s
      meta["hollow_woods_starter_received"] = result ? true : false
    end
    log("[hollow_woods] starter selection #{selected} result=#{result}") if respond_to?(:log)
    return selected
  rescue => e
    log("[hollow_woods] starter selection skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def infinity_check_roaming!(event_id = nil, *_args)
    map_id = integer(($game_map.map_id rescue 0), 0) if respond_to?(:integer)
    map_id = ($game_map.map_id rescue 0).to_i if map_id.nil?
    return false if !infinity_active_now?(map_id)
    if defined?($PokemonGlobal) && $PokemonGlobal
      $PokemonGlobal.roamPosition = {} if $PokemonGlobal.respond_to?(:roamPosition=) &&
                                          !$PokemonGlobal.roamPosition.is_a?(Hash)
      $PokemonGlobal.roamPokemon = [] if $PokemonGlobal.respond_to?(:roamPokemon=) &&
                                        !$PokemonGlobal.roamPokemon.is_a?(Array)
      $PokemonGlobal.roamedAlready = false if $PokemonGlobal.respond_to?(:roamedAlready=) &&
                                             $PokemonGlobal.roamedAlready.nil?
    end
    @infinity_roaming_skip_logged ||= {}
    key = [map_id, event_id || :global]
    if !@infinity_roaming_skip_logged[key]
      @infinity_roaming_skip_logged[key] = true
      suffix = event_id ? " event #{event_id}" : ""
      log("[infinity] optional pbCheckRoaming skipped safely on map #{map_id}#{suffix}") if respond_to?(:log)
    end
    return false
  rescue => e
    log("[infinity] roaming check skipped safely after error: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def gadir_deluxe_switch_active?(expansion_id, switch_id)
    expansion = canonical_new_project_id(expansion_id)
    begin
      return true if expansion_switch_value(expansion, switch_id)
    rescue
    end
    if defined?($game_switches) && $game_switches &&
       $game_switches.respond_to?(:tef_compat_original_get)
      return $game_switches.tef_compat_original_get(integer(switch_id, 0)) == true
    end
    return false
  rescue
    return false
  end

  def gadir_deluxe_set_switch!(expansion_id, switch_id, value = true)
    expansion = canonical_new_project_id(expansion_id)
    set_expansion_switch_value(expansion, switch_id, value)
    $game_map.need_refresh = true if defined?($game_map) && $game_map && $game_map.respond_to?(:need_refresh=)
    return value
  rescue
    return value
  end

  def new_project_map_interpreter_running?
    interpreter = nil
    interpreter = $game_system.map_interpreter if defined?($game_system) &&
                                                 $game_system &&
                                                 $game_system.respond_to?(:map_interpreter)
    return false if !interpreter
    return interpreter.running? if interpreter.respond_to?(:running?)
    return false
  rescue
    return false
  end

  def new_project_message_or_transfer_busy?
    return false if !defined?($game_temp) || !$game_temp
    return true if $game_temp.respond_to?(:message_window_showing) && $game_temp.message_window_showing
    return true if $game_temp.respond_to?(:player_transferring) && $game_temp.player_transferring
    return true if $game_temp.respond_to?(:transition_processing) && $game_temp.transition_processing
    return false
  rescue
    return false
  end

  def new_project_message_showing?
    return true if defined?($game_temp) && $game_temp &&
                   $game_temp.respond_to?(:message_window_showing) &&
                   $game_temp.message_window_showing
    return true if defined?($game_message) && $game_message &&
                   $game_message.respond_to?(:busy?) &&
                   $game_message.busy?
    return false
  rescue
    return false
  end

  def new_project_transition_locked?
    return false if !defined?($game_temp) || !$game_temp
    return true if $game_temp.respond_to?(:transition_processing) && $game_temp.transition_processing
    return true if $game_temp.respond_to?(:player_transferring) && $game_temp.player_transferring
    return false
  rescue
    return false
  end

  def new_project_current_map_interpreter
    if defined?(pbMapInterpreter) && pbMapInterpreter
      return pbMapInterpreter
    end
    if defined?($game_system) && $game_system &&
       $game_system.respond_to?(:map_interpreter)
      return $game_system.map_interpreter
    end
    return nil
  rescue
    return nil
  end

  def new_project_current_interpreter_event_id
    interpreter = new_project_current_map_interpreter
    return 0 if !interpreter
    return integer(interpreter.instance_variable_get(:@event_id), 0)
  rescue
    return 0
  end

  def new_project_release_player_controls!(clear_message = false, clear_transfer = true)
    $game_system.menu_disabled = false if defined?($game_system) && $game_system && $game_system.respond_to?(:menu_disabled=)
    if defined?($game_temp) && $game_temp
      $game_temp.message_window_showing = false if clear_message && $game_temp.respond_to?(:message_window_showing=)
      $game_temp.menu_calling = false if $game_temp.respond_to?(:menu_calling=)
      $game_temp.in_menu = false if $game_temp.respond_to?(:in_menu=)
      if clear_transfer
        $game_temp.player_transferring = false if $game_temp.respond_to?(:player_transferring=)
        $game_temp.transition_processing = false if $game_temp.respond_to?(:transition_processing=)
        $game_temp.transition_name = "" if $game_temp.respond_to?(:transition_name=)
      end
    end
    if defined?($PokemonTemp) && $PokemonTemp
      $PokemonTemp.miniupdate = false if $PokemonTemp.respond_to?(:miniupdate=)
      $PokemonTemp.hiddenMoveEventCalling = false if $PokemonTemp.respond_to?(:hiddenMoveEventCalling=)
      $PokemonTemp.keyItemCalling = false if $PokemonTemp.respond_to?(:keyItemCalling=)
      $PokemonTemp.waitingTrainer = nil if $PokemonTemp.respond_to?(:waitingTrainer=)
    end
    if defined?($game_player) && $game_player
      $game_player.unlock if $game_player.respond_to?(:unlock)
      $game_player.cancelMoveRoute if $game_player.respond_to?(:cancelMoveRoute)
      $game_player.straighten if $game_player.respond_to?(:straighten)
      $game_player.through = false if $game_player.respond_to?(:through=)
      $game_player.transparent = false if $game_player.respond_to?(:transparent=)
    end
    return true
  rescue
    return false
  end

  def new_project_visuals_dark?(scene = nil)
    screen = defined?($game_screen) ? $game_screen : nil
    return true if respond_to?(:screen_visuals_stuck_dark?) && screen_visuals_stuck_dark?(screen)
    if defined?(Graphics) && Graphics.respond_to?(:brightness)
      return true if visual_number(Graphics.brightness, 255) <= 5
    end
    renderer = scene && scene.respond_to?(:map_renderer) ? scene.map_renderer : nil
    if renderer
      tone = renderer.respond_to?(:tone) ? renderer.tone : nil
      color = renderer.respond_to?(:color) ? renderer.color : nil
      return true if dark_screen_tone?(tone) || opaque_black_color?(color)
    end
    return false
  rescue
    return false
  end

  def gadir_deluxe_intro_identity_progress?(metadata)
    return false if !metadata.is_a?(Hash)
    return true if metadata.has_key?("intro_skin_selection")
    return true if metadata.has_key?("intro_gender_selection")
    return true if metadata.has_key?("intro_gender")
    return true if metadata.has_key?("intro_name")
    return true if metadata.has_key?("intro_requested_name")
    return false
  rescue
    return false
  end

  def gadir_deluxe_intro_context(map_id = nil)
    target_map_id = integer(map_id || ($game_map.map_id rescue 0), 0)
    expansion = active_project_expansion_id(gadir_deluxe_expansion_ids, target_map_id)
    return nil if expansion.to_s.empty?
    local_map = local_map_id_for(expansion, target_map_id) rescue target_map_id
    return nil if integer(local_map, 0) != GADIR_DELUXE_INTRO_LOCAL_MAP_ID
    return expansion
  rescue
    return nil
  end

  def gadir_deluxe_intro_dark_tone_command?(tone, event_id = nil, map_id = nil)
    expansion = gadir_deluxe_intro_context(map_id)
    return false if expansion.to_s.empty?
    return false if !GADIR_DELUXE_INTRO_RECOVERY_EVENT_IDS.include?(integer(event_id, 0))
    return false if !respond_to?(:dark_screen_tone?) || !dark_screen_tone?(tone)
    metadata = new_project_metadata(expansion)
    return true if gadir_deluxe_intro_identity_progress?(metadata)
    return true if gadir_deluxe_switch_active?(expansion, GADIR_DELUXE_SWITCH_CHAPI_INTRO)
    return false
  rescue
    return false
  end

  def new_project_clear_message_state!
    if defined?($game_temp) && $game_temp &&
       $game_temp.respond_to?(:message_window_showing=)
      $game_temp.message_window_showing = false
    end
    if defined?($game_message) && $game_message && $game_message.respond_to?(:clear)
      $game_message.clear
    end
    return true
  rescue
    return false
  end

  def new_project_clear_screen_pictures!(reason = "new project recovery")
    return false if !defined?($game_screen) || !$game_screen ||
                    !$game_screen.respond_to?(:pictures)
    changed = false
    pictures = $game_screen.pictures rescue nil
    return false if !pictures
    pictures.each do |picture|
      next if !picture
      if picture.respond_to?(:name)
        changed = true if !picture.name.to_s.empty?
      elsif picture.instance_variable_defined?(:@name)
        changed = true if !picture.instance_variable_get(:@name).to_s.empty?
      else
        changed = true
      end
      if picture.respond_to?(:erase)
        picture.erase
      else
        picture.instance_variable_set(:@name, "") if picture.instance_variable_defined?(:@name)
        picture.instance_variable_set(:@opacity, 0) if picture.instance_variable_defined?(:@opacity)
        picture.instance_variable_set(:@duration, 0) if picture.instance_variable_defined?(:@duration)
      end
    end
    log("[visual] cleared imported screen pictures after #{reason}") if changed && respond_to?(:log)
    return changed
  rescue => e
    log("[visual] imported picture cleanup failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def gadir_deluxe_recover_intro_dark_tone!(event_id = nil, map_id = nil)
    expansion = gadir_deluxe_intro_context(map_id)
    return false if expansion.to_s.empty?
    log("[gadir_deluxe] intercepted stalled intro dark tone from event #{event_id}; completing intro safely") if respond_to?(:log)
    return gadir_deluxe_complete_intro_recovery!(expansion)
  rescue => e
    log("[gadir_deluxe] dark tone recovery failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def reset_gadir_deluxe_intro_recovery_counter!(metadata = nil)
    metadata["gadir_intro_idle_frames"] = 0 if metadata
    @gadir_deluxe_intro_idle_frames = 0
    return true
  rescue
    @gadir_deluxe_intro_idle_frames = 0
    return true
  end

  def gadir_deluxe_complete_intro_recovery!(expansion_id)
    expansion = canonical_new_project_id(expansion_id)
    return false if expansion.to_s.empty?
    [
      GADIR_DELUXE_SWITCH_CHAPI_INTRO,
      GADIR_DELUXE_SWITCH_FININTRO,
      GADIR_DELUXE_WAKEUP_SWITCH,
      GADIR_DELUXE_SWITCH_ENCIENDE,
      GADIR_DELUXE_SWITCH_ULTIMO_PARCHE
    ].each { |switch_id| gadir_deluxe_set_switch!(expansion, switch_id, true) }
    with_runtime_context(expansion) do
      if defined?($PokemonBag) && $PokemonBag && $PokemonBag.respond_to?(:pbStoreItem)
        $PokemonBag.pbStoreItem(:MISIONARIO) rescue nil
      end
    end
    $game_temp.player_transferring = false if defined?($game_temp) && $game_temp && $game_temp.respond_to?(:player_transferring=)
    $game_temp.transition_processing = false if defined?($game_temp) && $game_temp && $game_temp.respond_to?(:transition_processing=)
    $game_temp.transition_name = "" if defined?($game_temp) && $game_temp && $game_temp.respond_to?(:transition_name=)
    new_project_clear_message_state! if respond_to?(:new_project_clear_message_state!)
    new_project_clear_screen_pictures!("gadir_deluxe intro recovery") if respond_to?(:new_project_clear_screen_pictures!)
    clear_stuck_screen_effects!("gadir_deluxe intro recovery", true) if respond_to?(:clear_stuck_screen_effects!)
    if defined?($game_system) && $game_system &&
       $game_system.respond_to?(:map_interpreter) &&
       $game_system.map_interpreter &&
       $game_system.map_interpreter.respond_to?(:clear)
      $game_system.map_interpreter.clear
    end
    release_player_movement_lock if respond_to?(:release_player_movement_lock)
    apply_host_player_visuals!(expansion) if respond_to?(:apply_host_player_visuals!)
    target_map = translate_expansion_map_id(expansion, GADIR_DELUXE_HOME_LOCAL_MAP_ID)
    log("[gadir_deluxe] recovered stalled character intro; transferring to bedroom start") if respond_to?(:log)
    result = safe_transfer_to_anchor({
      :map_id    => target_map,
      :x         => GADIR_DELUXE_HOME_SAFE_X,
      :y         => GADIR_DELUXE_HOME_SAFE_Y,
      :direction => GADIR_DELUXE_HOME_SAFE_DIRECTION
    }, {
      :source            => :story_transfer,
      :expansion_id      => expansion,
      :allow_story_state => false,
      :immediate         => true,
      :auto_rescue       => false
    })
    new_project_clear_screen_pictures!("gadir_deluxe post intro transfer") if respond_to?(:new_project_clear_screen_pictures!)
    return result
  rescue => e
    log("[gadir_deluxe] intro recovery failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def gadir_deluxe_home_recovery_update!(scene = nil)
    return false if !defined?($game_map) || !$game_map
    map_id = integer($game_map.map_id, 0)
    expansion = active_project_expansion_id(gadir_deluxe_expansion_ids, map_id)
    return false if expansion.to_s.empty?
    local_map = local_map_id_for(expansion, map_id) rescue map_id
    return false if integer(local_map, 0) != GADIR_DELUXE_HOME_LOCAL_MAP_ID
    metadata = new_project_metadata(expansion)
    interpreter = new_project_current_map_interpreter
    event_id = new_project_current_interpreter_event_id
    return false if GADIR_DELUXE_HOME_EXIT_EVENT_IDS.include?(event_id)
    wakeup_done = gadir_deluxe_switch_active?(expansion, GADIR_DELUXE_WAKEUP_SWITCH)
    intro_done = gadir_deluxe_switch_active?(expansion, GADIR_DELUXE_SWITCH_FININTRO)
    return false if !wakeup_done && !intro_done
    if intro_done && !wakeup_done
      gadir_deluxe_set_switch!(expansion, GADIR_DELUXE_WAKEUP_SWITCH, true)
      wakeup_done = true
      if event_id == GADIR_DELUXE_HOME_WAKEUP_EVENT_ID && interpreter &&
         respond_to?(:clear_interpreter_state!)
        clear_interpreter_state!(interpreter, "gadir_deluxe bedroom wakeup autorun")
      end
    end
    visual_recovery_needed = new_project_visuals_dark?(scene)
    safe_landing_needed = metadata ? !metadata["gadir_home_safe_landing_recovered"] : false
    control_release_needed = metadata ? !metadata["gadir_home_controls_released"] : true
    if !visual_recovery_needed && !safe_landing_needed && !control_release_needed
      return false
    end
    new_project_clear_screen_pictures!("gadir_deluxe bedroom wakeup") if visual_recovery_needed && respond_to?(:new_project_clear_screen_pictures!)
    clear_stuck_screen_effects!("gadir_deluxe bedroom wakeup", true) if visual_recovery_needed && respond_to?(:clear_stuck_screen_effects!)
    new_project_release_player_controls!(true, true)
    if safe_landing_needed && defined?($game_player) && $game_player &&
       $game_player.respond_to?(:moveto)
      $game_player.moveto(GADIR_DELUXE_HOME_SAFE_X, GADIR_DELUXE_HOME_SAFE_Y)
      if $game_player.respond_to?(:direction=)
        $game_player.direction = GADIR_DELUXE_HOME_SAFE_DIRECTION
      end
      metadata["gadir_home_safe_landing_recovered"] = true if metadata
      log("[gadir_deluxe] placed player on safe bedroom exit tile #{GADIR_DELUXE_HOME_SAFE_X},#{GADIR_DELUXE_HOME_SAFE_Y}") if respond_to?(:log)
    end
    apply_host_player_visuals!(expansion) if respond_to?(:apply_host_player_visuals!)
    if metadata
      metadata["gadir_home_visuals_recovered"] = true if visual_recovery_needed
      metadata["gadir_home_controls_released"] = true
    end
    log("[gadir_deluxe] released bedroom wakeup controls on map #{map_id}") if respond_to?(:log)
    return true
  rescue => e
    log("[gadir_deluxe] bedroom wakeup recovery failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def gadir_deluxe_intro_recovery_update!(scene = nil)
    return false if !defined?($game_map) || !$game_map
    map_id = integer($game_map.map_id, 0)
    expansion = active_project_expansion_id(gadir_deluxe_expansion_ids, map_id)
    return false if expansion.to_s.empty?
    local_map = local_map_id_for(expansion, map_id) rescue map_id
    metadata = new_project_metadata(expansion)
    if integer(local_map, 0) != GADIR_DELUXE_INTRO_LOCAL_MAP_ID
      reset_gadir_deluxe_intro_recovery_counter!(metadata)
      return false
    end
    started = gadir_deluxe_switch_active?(expansion, GADIR_DELUXE_SWITCH_CHAPI_INTRO)
    finished = begin
      expansion_switch_value(expansion, GADIR_DELUXE_SWITCH_FININTRO)
    rescue
      false
    end
    if finished
      reset_gadir_deluxe_intro_recovery_counter!(metadata)
      return false
    end
    progressed = started || gadir_deluxe_intro_identity_progress?(metadata)
    if !progressed
      reset_gadir_deluxe_intro_recovery_counter!(metadata)
      return false
    end
    interpreter_running = new_project_map_interpreter_running?
    transition_locked = new_project_transition_locked?
    visuals_dark = new_project_visuals_dark?(scene)
    if new_project_message_showing? && !transition_locked && !visuals_dark
      reset_gadir_deluxe_intro_recovery_counter!(metadata)
      return false
    end
    if interpreter_running || new_project_message_or_transfer_busy?
      if !transition_locked && !visuals_dark
        reset_gadir_deluxe_intro_recovery_counter!(metadata)
        return false
      end
    end
    frames = metadata ? integer(metadata["gadir_intro_idle_frames"], 0) : integer(@gadir_deluxe_intro_idle_frames, 0)
    frames += 1
    metadata["gadir_intro_idle_frames"] = frames if metadata
    @gadir_deluxe_intro_idle_frames = frames
    return false if frames < GADIR_DELUXE_INTRO_IDLE_RECOVERY_FRAMES
    reset_gadir_deluxe_intro_recovery_counter!(metadata)
    return gadir_deluxe_complete_intro_recovery!(expansion)
  rescue => e
    log("[gadir_deluxe] intro recovery update failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def new_project_identity_active_now?(map_id = nil)
    return new_project_active_now?(map_id)
  end

  def new_project_active_now?(map_id = nil)
    return true if respond_to?(:void_active_now?) && void_active_now?(map_id)
    return !active_project_expansion_id(new_project_expansion_ids, map_id).nil?
  end

  def current_new_project_expansion_id(map_id = nil)
    return current_void_expansion_id(map_id) if respond_to?(:void_active_now?) && void_active_now?(map_id)
    return active_project_expansion_id(new_project_expansion_ids, map_id)
  end

  def bare_species_constant_resolution_active?
    expansion = active_project_expansion_id(new_project_expansion_ids)
    expansion ||= current_runtime_expansion_id if respond_to?(:current_runtime_expansion_id)
    return false if expansion.to_s.empty?
    return false if defined?(HOST_EXPANSION_ID) && expansion.to_s == HOST_EXPANSION_ID.to_s
    return true
  rescue
    return false
  end

  def project_root_path(project_id, fallback_folder, aliases = [])
    info = external_projects[project_id] rescue nil
    root = info[:root].to_s if info.is_a?(Hash)
    return root if !root.to_s.empty? && File.directory?(root)
    ([fallback_folder] + Array(aliases)).each do |folder|
      path = File.join("C:/Games", folder.to_s)
      return path if File.directory?(path)
    end
    return root if !root.to_s.empty?
    return nil
  rescue
    return nil
  end

  def opalo_root_path
    return project_root_path(OPALO_EXPANSION_ID, "Opalo", ["Pokemon Opalo"])
  end

  def opalo_translation_path
    root = opalo_root_path
    return nil if root.to_s.empty?
    ["intl.txt", File.join("Data", "english.txt"), File.join("Data", "intl.txt")].each do |relative|
      path = File.join(root, relative)
      return path if File.file?(path)
    end
    return nil
  rescue
    return nil
  end

  def opalo_compat_asset_root
    return File.join(framework_root, "compat_assets", OPALO_EXPANSION_ID)
  rescue
    return File.expand_path("./Mods/#{FRAMEWORK_MOD_ID}/compat_assets/#{OPALO_EXPANSION_ID}")
  end

  def opalo_asset_context_active?
    @opalo_asset_context_depth ||= 0
    return false if @opalo_asset_context_depth > 0
    @opalo_asset_context_depth += 1
    expansion = @rendering_expansion_id if instance_variable_defined?(:@rendering_expansion_id)
    expansion = current_runtime_expansion_id if safe_new_project_id_text(expansion).empty? && respond_to?(:current_runtime_expansion_id)
    if safe_new_project_id_text(expansion).empty? && defined?($game_map) && $game_map && respond_to?(:direct_map_expansion_id)
      map_id = $game_map.respond_to?(:map_id) ? $game_map.map_id : nil
      expansion = direct_map_expansion_id(map_id)
    end
    return false if safe_new_project_id_text(expansion).empty?
    return opalo_expansion_id?(expansion)
  rescue Exception
    return false
  ensure
    @opalo_asset_context_depth = [(@opalo_asset_context_depth || 1) - 1, 0].max
  end

  def opalo_picture_override_path(logical_path, extensions = [])
    return nil if !opalo_asset_context_active?
    normalized = logical_path.to_s.gsub("\\", "/").sub(/\A\.\//, "").sub(%r{\A/+}, "")
    return nil if normalized.empty? || normalized.end_with?("/")
    extname = File.extname(normalized)
    without_ext = extname.empty? ? normalized : normalized[0...-extname.length]
    return nil if without_ext !~ %r{\AGraphics/Pictures/([^/]+)\z}i
    picture_name = $1.to_s
    return nil if !OPALO_COMPAT_PICTURE_OVERRIDES.include?(picture_name)
    exts = extensions.is_a?(Array) ? extensions : [extensions]
    exts = [".png"] if exts.empty? || exts.all? { |ext| ext.to_s.empty? }
    candidates = []
    candidates << normalized if !extname.empty?
    exts.each do |ext|
      ext = ext.to_s
      next if ext.empty?
      candidates << "#{without_ext}#{ext}"
    end
    candidates.uniq.each do |candidate|
      path = File.join(opalo_compat_asset_root, *candidate.split("/"))
      return path if File.file?(path)
    end
    return nil
  rescue => e
    log("[opalo] picture override failed for #{logical_path}: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def opalo_lens_event?(event)
    return false if !event
    map_id = event.instance_variable_get(:@map_id) rescue nil
    return false if !opalo_active_now?(map_id)
    name = event.respond_to?(:name) ? event.name.to_s : ""
    return name.include?("#EOT")
  rescue
    return false
  end

  def opalo_lens_show_event?(event)
    name = event.respond_to?(:name) ? event.name.to_s : ""
    return name[/SHOW/i] != nil
  rescue
    return false
  end

  def opalo_lens_hide_event?(event)
    name = event.respond_to?(:name) ? event.name.to_s : ""
    return name[/HIDE/i] != nil
  rescue
    return false
  end

  def opalo_lens_event_limit_opacity(event, fallback)
    name = event.respond_to?(:name) ? event.name.to_s : ""
    value = name[/(\d+)/, 1]
    return integer(value, fallback) if value
    return fallback
  rescue
    return fallback
  end

  def opalo_lens_active?
    return false if !defined?($scene) || !$scene || !$scene.respond_to?(:eye_of_truth_time)
    return integer($scene.eye_of_truth_time, 0) > 0
  rescue
    return false
  end

  def opalo_lens_event_in_range?(event)
    return false if !opalo_lens_active?
    return false if !defined?($game_player) || !$game_player
    distance_x = integer(event.x, 0) - integer($game_player.x, 0)
    distance_y = integer(event.y, 0) - integer($game_player.y, 0)
    return Math.sqrt((distance_x * distance_x) + (distance_y * distance_y)) <= OPALO_LENS_OF_TRUTH_RANGE
  rescue
    return false
  end

  def opalo_event_under_player?(event)
    return false if !defined?($game_player) || !$game_player
    return event.respond_to?(:at_coordinate?) && event.at_coordinate?($game_player.x, $game_player.y)
  rescue
    return false
  end

  def apply_opalo_lens_event_state!(event, immediate = false)
    return false if !opalo_lens_event?(event)
    in_range = opalo_lens_event_in_range?(event)
    current = integer(event.opacity, 255)
    target = current
    if opalo_lens_show_event?(event)
      target = in_range ? opalo_lens_event_limit_opacity(event, 255) : 0
      event.through = !in_range || opalo_event_under_player?(event) if event.respond_to?(:through=)
    elsif opalo_lens_hide_event?(event)
      target = in_range ? opalo_lens_event_limit_opacity(event, 0) : 255
      event.through = in_range || opalo_event_under_player?(event) if event.respond_to?(:through=)
    else
      return false
    end
    if immediate
      event.opacity = target if event.respond_to?(:opacity=)
    elsif event.respond_to?(:opacity=)
      step = 26
      event.opacity = [[current + step, target].min, 255].min if current < target
      event.opacity = [[current - step, target].max, 0].max if current > target
    end
    return true
  rescue => e
    log("[opalo] Lens of Truth event shim failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def activate_opalo_lens_of_truth!
    return false if !opalo_active_now?
    return false if !defined?($scene) || !$scene
    return false if !$scene.respond_to?(:eye_of_truth_time=)
    frames = (Graphics.frame_rate rescue 40).to_i
    frames = 40 if frames <= 0
    $scene.eye_of_truth_time = OPALO_LENS_OF_TRUTH_DURATION_SECONDS * frames
    return true
  rescue
    return false
  end

  def realidea_root_path
    return project_root_path(REALIDEA_EXPANSION_ID, "Realidea", ["Pokemon Realidea", "Pokemon Realidea System"])
  end

  def realidea_translation_path
    root = realidea_root_path
    return nil if root.to_s.empty?
    [File.join("Data", "English.dat"), File.join("Data", "english.dat")].each do |relative|
      path = File.join(root, relative)
      return path if File.file?(path)
    end
    return nil
  rescue
    return nil
  end

  def read_utf8_lines(path)
    return [] if path.to_s.empty? || !File.file?(path)
    lines = []
    File.open(path, "rb") do |file|
      file.each_line do |line|
        text = line.to_s.dup
        text.force_encoding("UTF-8") if text.respond_to?(:force_encoding)
        text = text.encode("UTF-8", :invalid => :replace, :undef => :replace, :replace => "")
        text.gsub!(/\r?\n\z/, "")
        lines << text
      end
    end
    return lines
  rescue => e
    log("[translation] failed to read #{path}: #{e.class}: #{e.message}") if respond_to?(:log)
    return []
  end

  def opalo_translation_key(text)
    normalized = text.to_s.dup
    normalized.gsub!("\r", "")
    normalized.gsub!(/\\n/i, " ")
    normalized.gsub!("\n", " ")
    normalized.gsub!("\001", "")
    normalized.gsub!(/[ \t]+/, " ")
    normalized.strip!
    return normalized.to_s
  rescue
    return text.to_s
  end

  def opalo_translation_key_variants(text)
    base = opalo_translation_key(text)
    return [] if base.empty?
    variants = [base]
    stripped_window = base.gsub(/\A(?:\\w\[[^\]]+\]\s*)+/i, "").strip
    variants << stripped_window if !stripped_window.empty?
    stripped_controls = stripped_window.gsub(/\\[A-Za-z]+\[[^\]]*\]/, "").strip
    variants << stripped_controls if !stripped_controls.empty?
    compacted = stripped_window.gsub(/\s+/, " ").strip
    variants << compacted if !compacted.empty?
    return variants.compact.reject { |entry| entry.to_s.empty? }.uniq
  rescue
    value = opalo_translation_key(text)
    return value.empty? ? [] : [value]
  end

  def opalo_decode_translation_markup(text)
    decoded = text.to_s.dup
    decoded.gsub!("<<n>>", "\n")
    decoded.gsub!("<<N>>", "\n")
    decoded.gsub!(/\\n/i, "\n")
    return decoded
  rescue
    return text.to_s
  end

  def opalo_collect_translation_entry!(catalog, source, translated, scope = nil)
    keys = opalo_translation_key_variants(source)
    return if keys.empty?
    text = opalo_decode_translation_markup(translated)
    return if text.to_s.empty?
    keys.each do |key|
      if scope
        catalog[:maps][scope] ||= {}
        catalog[:maps][scope][key] = text
      else
        catalog[:script][key] = text
      end
      catalog[:all][key] = text if !catalog[:all].has_key?(key)
    end
  rescue => e
    log("[opalo] translation entry failed: #{e.class}: #{e.message}") if respond_to?(:log)
  end

  def opalo_translation_catalog
    @opalo_translation_catalog ||= begin
      catalog = { :loaded => true, :maps => {}, :script => {}, :all => {} }
      path = opalo_translation_path
      pending = nil
      current_scope = nil
      read_utf8_lines(path).each do |line|
        next if line.start_with?("#")
        if line[/\A\[Map(\d+)\]\z/i]
          current_scope = integer($1, 0)
          pending = nil
          next
        elsif line[/\A\[(\d+)\]\z/i]
          current_scope = nil
          pending = nil
          next
        end
        next if line.empty? && pending.nil?
        if pending.nil?
          pending = line
          next
        end
        opalo_collect_translation_entry!(catalog, pending, line, current_scope)
        pending = nil
      end
      catalog
    end
    return @opalo_translation_catalog
  rescue => e
    log("[opalo] translation catalog load failed: #{e.class}: #{e.message}") if respond_to?(:log)
    @opalo_translation_catalog = { :loaded => true, :maps => {}, :script => {}, :all => {} }
    return @opalo_translation_catalog
  end

  def opalo_current_local_map_id(map_id = nil)
    current_map_id = integer(map_id || ($game_map.map_id rescue 0), 0)
    return 0 if current_map_id <= 0
    expansion = active_project_expansion_id(opalo_expansion_ids, current_map_id) || OPALO_EXPANSION_ID
    return local_map_id_for(expansion, current_map_id) if respond_to?(:local_map_id_for)
    return current_map_id
  rescue
    return 0
  end

  def opalo_metadata(expansion_id = nil)
    expansion = expansion_id.to_s
    expansion = active_project_expansion_id(opalo_expansion_ids) if expansion.empty?
    expansion = OPALO_EXPANSION_ID if expansion.to_s.empty?
    return new_project_metadata(expansion) if respond_to?(:new_project_metadata)
    state = state_for(expansion) rescue nil
    return nil if !state || !state.respond_to?(:metadata)
    state.metadata = {} if state.metadata.nil? && state.respond_to?(:metadata=)
    return state.metadata if state.metadata.is_a?(Hash)
    return nil
  rescue
    return nil
  end

  def opalo_valid_starter_choice?(choice)
    return [1, 2, 3].include?(integer(choice, 0))
  rescue
    return false
  end

  def remember_opalo_starter_choice!(choice, expansion_id = nil)
    selected = integer(choice, 0)
    return nil if !opalo_valid_starter_choice?(selected)
    meta = opalo_metadata(expansion_id)
    meta["opalo_starter_choice"] = selected if meta
    return selected
  rescue
    return nil
  end

  def remembered_opalo_starter_choice(expansion_id = nil)
    meta = opalo_metadata(expansion_id)
    choice = integer(meta && meta["opalo_starter_choice"], 0)
    return choice if opalo_valid_starter_choice?(choice)
    return 0
  rescue
    return 0
  end

  def opalo_repair_starter_room_state!(map_id = nil, reason = "runtime")
    current_map_id = integer(map_id || ($game_map.map_id rescue 0), 0)
    return false if current_map_id <= 0 || !opalo_active_now?(current_map_id)
    local_map = opalo_current_local_map_id(current_map_id)
    starter_maps = [
      OPALO_STARTER_TOWN_LOCAL_MAP_ID,
      OPALO_STARTER_ROOM_LOCAL_MAP_ID,
      OPALO_STARTER_ROUTE_LOCAL_MAP_ID
    ]
    return false if !starter_maps.include?(local_map)
    return false if !defined?($game_switches) || !$game_switches || !defined?($game_variables) || !$game_variables

    expansion = active_project_expansion_id(opalo_expansion_ids, current_map_id) || OPALO_EXPANSION_ID
    changed = false
    choice = integer($game_variables[OPALO_STARTER_CHOICE_VARIABLE], 0)
    remember_opalo_starter_choice!(choice, expansion) if opalo_valid_starter_choice?(choice)

    fled = $game_switches[OPALO_STARTER_FLED_SWITCH] == true
    hidden = $game_switches[OPALO_STARTER_HIDDEN_SWITCH] == true
    chasing = $game_switches[OPALO_STARTER_CHASE_SWITCH] == true
    poochyena_seen = $game_switches[OPALO_STARTER_POOCHYENA_SWITCH] == true
    battle_done = $game_switches[OPALO_STARTER_BATTLE_DONE_SWITCH] == true
    professor_seen = $game_switches[OPALO_STARTER_PROFESSOR_SWITCH] == true
    starter_story_started = fled || hidden || chasing || poochyena_seen || battle_done || professor_seen
    if starter_story_started && $game_switches[OPALO_STARTER_SELECTED_SWITCH] != true
      $game_switches[OPALO_STARTER_SELECTED_SWITCH] = true
      changed = true
    end

    if starter_story_started && !opalo_valid_starter_choice?(choice)
      remembered = remembered_opalo_starter_choice(expansion)
      remembered = 1 if !opalo_valid_starter_choice?(remembered)
      $game_variables[OPALO_STARTER_CHOICE_VARIABLE] = remembered
      remember_opalo_starter_choice!(remembered, expansion)
      changed = true
    end

    if changed
      meta = opalo_metadata(expansion)
      if meta
        meta["opalo_starter_state_repaired"] = {
          "map_id"     => current_map_id,
          "local_map"  => local_map,
          "reason"     => reason.to_s,
          "choice"     => integer($game_variables[OPALO_STARTER_CHOICE_VARIABLE], 0),
          "updated_at" => (timestamp_string if respond_to?(:timestamp_string))
        }
      end
      $game_map.need_refresh = true if defined?($game_map) && $game_map && $game_map.respond_to?(:need_refresh=)
      log("[opalo] repaired starter room state on map #{current_map_id} (local #{local_map}) via #{reason}; choice=#{$game_variables[OPALO_STARTER_CHOICE_VARIABLE]}") if respond_to?(:log)
    end
    return changed
  rescue => e
    log("[opalo] starter room repair failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def opalo_translate_text(text, map_id = nil)
    source = text.to_s
    return source if source.empty?
    trailer = source[/\001+\z/].to_s
    lookup_source = trailer.empty? ? source : source[0, source.length - trailer.length]
    prefix = lookup_source[/\A(?:\\w\[[^\]]+\]\s*)+/i].to_s
    keys = opalo_translation_key_variants(lookup_source)
    return source if keys.empty?
    catalog = opalo_translation_catalog
    local_map_id = opalo_current_local_map_id(map_id)
    translated = nil
    if catalog[:maps].is_a?(Hash)
      keys.each do |key|
        translated = catalog[:maps][local_map_id][key] if translated.nil? && catalog[:maps][local_map_id].is_a?(Hash)
        translated = catalog[:maps][0][key] if translated.nil? && catalog[:maps][0].is_a?(Hash)
      end
    end
    if translated.nil? && catalog[:script].is_a?(Hash)
      keys.each do |key|
        translated = catalog[:script][key]
        break if translated
      end
    end
    if translated.nil? && catalog[:all].is_a?(Hash)
      keys.each do |key|
        translated = catalog[:all][key]
        break if translated
      end
    end
    return source if translated.nil? || translated.to_s.empty?
    result = opalo_decode_translation_markup(translated)
    result = "#{prefix}#{result}" if !prefix.empty? && result !~ /\A#{Regexp.escape(prefix)}/
    return "#{result}#{trailer}"
  rescue => e
    log("[opalo] translation lookup failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return text.to_s
  end

  def format_translation_text(template, values)
    result = template.to_s.dup
    Array(values).each_with_index do |value, index|
      result.gsub!(/\{#{index + 1}\}/, value.to_s)
    end
    return result
  rescue
    return template.to_s
  end

  def translate_opalo_commands(commands, map_id = nil)
    return commands if !commands
    return Array(commands).map { |entry| opalo_translate_text(entry, map_id) }
  rescue
    return commands
  end

  def realidea_current_local_map_id(map_id = nil)
    current_map_id = integer(map_id || ($game_map.map_id rescue 0), 0)
    return 0 if current_map_id <= 0
    return local_map_id_for(REALIDEA_EXPANSION_ID, current_map_id) if respond_to?(:local_map_id_for)
    return current_map_id
  rescue
    return 0
  end

  def realidea_fuzzy_translation_key(text)
    normalized = text.to_s.dup
    normalized.force_encoding("UTF-8") if normalized.respond_to?(:force_encoding)
    normalized = normalized.encode("UTF-8", :invalid => :replace, :undef => :replace, :replace => "") if normalized.respond_to?(:encode)
    normalized.gsub!(/&quot;/i, "\"")
    normalized.gsub!(/\r/, " ")
    normalized.gsub!(/\\[Nn]/, " ")
    normalized.gsub!(/\n/, " ")
    normalized.gsub!(/\001/, " ")
    normalized.gsub!(/\\(?:tg|xn)\[([^\]]+)\]/i, " \\1 ")
    normalized.gsub!(/\\[A-Za-z]+\[[^\]]*\]/, " ")
    normalized.gsub!(/<\/?[^>]+>/, " ")
    normalized.gsub!(/[\"'\.,;:!\?\(\)\[\]\{\}]+/, " ")
    normalized.gsub!(/\s+/, " ")
    normalized.strip!
    normalized.downcase!
    return normalized.to_s
  rescue
    return text.to_s
  end

  def realidea_common_prefix_length(left, right)
    left = left.to_s
    right = right.to_s
    limit = [left.length, right.length].min
    index = 0
    index += 1 while index < limit && left[index, 1] == right[index, 1]
    return index
  rescue
    return 0
  end

  def realidea_collect_translation_entry!(catalog, source, translated, scope = nil)
    text = opalo_decode_translation_markup(translated)
    return if text.to_s.empty?
    keys = opalo_translation_key_variants(source)
    return if keys.empty?
    keys.each do |key|
      if scope
        catalog[:maps][scope] ||= {}
        catalog[:maps][scope][key] = text
      else
        catalog[:script][key] = text
      end
      catalog[:all][key] = text if !catalog[:all].has_key?(key)
    end
    fuzzy_key = realidea_fuzzy_translation_key(source)
    return if fuzzy_key.empty?
    if scope
      catalog[:map_entries][scope] ||= []
      catalog[:map_entries][scope] << [fuzzy_key, text]
    else
      catalog[:script_entries] << [fuzzy_key, text]
    end
    catalog[:all_entries] << [fuzzy_key, text]
  rescue => e
    log("[realidea] translation entry failed: #{e.class}: #{e.message}") if respond_to?(:log)
  end

  def realidea_collect_translation_entries!(catalog, entries, scope = nil)
    return if !entries || !entries.respond_to?(:each)
    entries.each do |source, translated|
      realidea_collect_translation_entry!(catalog, source, translated, scope)
    end
  rescue => e
    log("[realidea] translation section failed: #{e.class}: #{e.message}") if respond_to?(:log)
  end

  def realidea_translation_catalog
    @realidea_translation_catalog ||= begin
      catalog = {
        :loaded => true,
        :maps => {},
        :script => {},
        :all => {},
        :map_entries => {},
        :script_entries => [],
        :all_entries => []
      }
      path = realidea_translation_path
      if path && File.file?(path)
        data = File.open(path, "rb") { |file| Marshal.load(file) }
        if data.is_a?(Array)
          maps = data[0]
          if maps.is_a?(Array)
            maps.each_with_index do |entries, map_index|
              realidea_collect_translation_entries!(catalog, entries, map_index)
            end
          elsif maps.is_a?(Hash)
            maps.each do |map_index, entries|
              realidea_collect_translation_entries!(catalog, entries, integer(map_index, 0))
            end
          end
          realidea_collect_translation_entries!(catalog, data[23], nil) if data.length > 23
        elsif data.is_a?(Hash)
          data.each do |source, translated|
            realidea_collect_translation_entry!(catalog, source, translated, nil)
          end
        end
      end
      catalog
    end
    return @realidea_translation_catalog
  rescue => e
    log("[realidea] translation catalog load failed: #{e.class}: #{e.message}") if respond_to?(:log)
    @realidea_translation_catalog = {
      :loaded => true,
      :maps => {},
      :script => {},
      :all => {},
      :map_entries => {},
      :script_entries => [],
      :all_entries => []
    }
    return @realidea_translation_catalog
  end

  def realidea_fuzzy_translation(catalog, source, local_map_id)
    source_key = realidea_fuzzy_translation_key(source)
    return nil if source_key.length < 36
    candidates = []
    candidates.concat(catalog[:map_entries][local_map_id] || []) if catalog[:map_entries].is_a?(Hash)
    candidates.concat(catalog[:map_entries][0] || []) if catalog[:map_entries].is_a?(Hash) && local_map_id != 0
    candidates.concat(catalog[:script_entries] || [])
    candidates.concat(catalog[:all_entries] || [])
    best_text = nil
    best_score = 0
    candidates.each do |entry|
      next if !entry || entry.length < 2
      candidate_key = entry[0].to_s
      next if candidate_key.empty?
      score = realidea_common_prefix_length(source_key, candidate_key)
      next if score < 48
      if score > best_score
        best_score = score
        best_text = entry[1]
      end
    end
    return best_text
  rescue
    return nil
  end

  def realidea_translate_text(text, map_id = nil)
    source = text.to_s
    return source if source.empty?
    trailer = source[/\001+\z/].to_s
    lookup_source = trailer.empty? ? source : source[0, source.length - trailer.length]
    keys = opalo_translation_key_variants(lookup_source)
    return source if keys.empty?
    catalog = realidea_translation_catalog
    local_map_id = realidea_current_local_map_id(map_id)
    translated = nil
    if catalog[:maps].is_a?(Hash)
      keys.each do |key|
        translated = catalog[:maps][local_map_id][key] if translated.nil? && catalog[:maps][local_map_id].is_a?(Hash)
        translated = catalog[:maps][0][key] if translated.nil? && catalog[:maps][0].is_a?(Hash)
      end
    end
    if translated.nil? && catalog[:script].is_a?(Hash)
      keys.each do |key|
        translated = catalog[:script][key]
        break if translated
      end
    end
    if translated.nil? && catalog[:all].is_a?(Hash)
      keys.each do |key|
        translated = catalog[:all][key]
        break if translated
      end
    end
    translated = realidea_fuzzy_translation(catalog, lookup_source, local_map_id) if translated.nil?
    return source if translated.nil? || translated.to_s.empty?
    result = opalo_decode_translation_markup(translated)
    return "#{result}#{trailer}"
  rescue => e
    log("[realidea] translation lookup failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return text.to_s
  end

  def cleanup_imported_message_text(text, map_id = nil)
    source = text.to_s
    return source if source.empty?
    trailer = source[/\001+\z/].to_s
    body = trailer.empty? ? source.dup : source[0, source.length - trailer.length]
    body.gsub!(/&quot;/i, "\"")
    body.gsub!(/<br\s*\/?>/i, "\n")
    body.gsub!(/\\(?:tg|xn|dxn|dxor)\[\\[Vv]\[(\d+)\]\]\s*/i) do
      speaker = ($game_variables[$1.to_i] rescue nil).to_s
      speaker = "Someone" if speaker.empty?
      "#{speaker}: "
    end
    body.gsub!(/\\(?:tg|xn|dxn|dxor)\[([^\]]+)\]\s*/i) { "#{$1}: " }
    body.gsub!(/\\js\[([^\]]*)\]\s*/i) do
      speaker = $1.to_s.strip
      speaker.empty? || speaker[/\A\?+\z/] ? "" : "#{speaker}: "
    end
    body.gsub!(/\\(?:pg|pog|sh)/i, "")
    body.gsub!(/\\(?:wtnp|wt|w|l|c|ts|se|me|ch)\[[^\]]*\]/i, "")
    body.gsub!(/\\(?:\.\.\.|\.\.|\.|\||\^)/, "")
    body.gsub!(/<\/?(?:fs|c2|c3|ac|al|ar|b|i|u)[^>]*>/i, "")
    body.gsub!(/<icon=[^>]+>/i, "")
    body.gsub!(/<[^>]+>/, "")
    body.gsub!(/\\[Nn]/, "\n")
    body.gsub!(/[ \t]+\n/, "\n")
    body.gsub!(/\n[ \t]+/, "\n")
    body.gsub!(/[ \t]{2,}/, " ")
    body.strip!
    # Host pbMessageDisplay prepends a colour tag based on the active
    # windowskin. Void's imported dark portrait windowskin can report bad
    # colour pixels in the host renderer, making otherwise valid text invisible.
    body.gsub!(/<\/?c[23][^>]*>/i, "")
    return "#{body}#{trailer}"
  rescue
    return text.to_s
  end

  def void_host_player_name
    name = ($Trainer.name rescue nil).to_s.strip
    return name if !name.empty?
    return "Player"
  rescue
    return "Player"
  end

  def void_default_rival_name(slot = 1)
    return ["Ronan", "Nia", "Seren"][integer(slot, 1) - 1] || "Rival"
  rescue
    return "Rival"
  end

  def void_current_rival_slot
    meta = new_project_metadata(POKEMON_VOID_EXPANSION_ID) if respond_to?(:new_project_metadata)
    if meta.is_a?(Hash)
      slot = integer(meta["void_current_rival_slot"], 0)
      return slot if slot > 0
    end
    store = respond_to?(:void_rival_graphic_store) ? void_rival_graphic_store : nil
    map_id = ($game_map.map_id rescue 0).to_i
    if store.is_a?(Hash)
      store.to_a.reverse_each do |entry|
        key = entry[0].to_s
        data = entry[1]
        next if !data.is_a?(Hash)
        key_map_id = key.split(":", 2)[0].to_i
        next if map_id > 0 && key_map_id > 0 && key_map_id != map_id
        slot = integer(data["rival_slot"], 0)
        return slot if slot > 0
      end
    end
    return 1
  rescue
    return 1
  end

  def void_set_rival_dialogue_portrait!(rival_slot = nil, fallback_event_id = nil, *args)
    slot = integer(rival_slot, 0)
    slot = 1 if slot <= 0
    meta = new_project_metadata(POKEMON_VOID_EXPANSION_ID) if respond_to?(:new_project_metadata)
    meta["void_current_rival_slot"] = slot if meta.is_a?(Hash)
    record_release_shim_hit("pbSetRivalDialoguePortrait", "menu_settings", "slot=#{slot}") if respond_to?(:record_release_shim_hit)
    map_id = ($game_map.map_id rescue nil) if defined?($game_map) && $game_map
    if defined?($game_map) && $game_map && void_active_now?(map_id)
      void_prepare_map_runtime!($game_map, "rival_dialogue_slot") if respond_to?(:void_prepare_map_runtime!)
    end
    return true
  rescue => e
    log("[void] rival dialogue portrait skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def void_dialog_dynamic_subject
    return void_default_rival_name(void_current_rival_slot)
  rescue
    return void_default_rival_name(1)
  end

  def void_dialog_token_name(prefix)
    key = prefix.to_s.downcase
    case key
    when "player", "player_name", "trainer", "trainer_name"
      return void_host_player_name
    when "c", "character", "char", "rival2", "r2"
      return void_default_rival_name(2)
    when "d", "default", "default_rival", "rival", "rival1", "r1"
      return void_default_rival_name(1)
    when "rival3", "r3"
      return void_default_rival_name(3)
    end
    return nil
  rescue
    return nil
  end

  def void_dialog_token_value(raw_token)
    token = raw_token.to_s.strip
    return nil if token.empty?
    if token[/\A([A-Za-z0-9_]+)_n:([^|{}]*)\|([^{}]*)\z/i]
      return $3.to_s
    end
    if token[/\A([A-Za-z0-9_]+)_([a-z])\z/i]
      base_name = void_dialog_token_name($1)
      return nil if base_name.to_s.empty?
      case $2.downcase
      when "o"
        return "#{base_name}'s"
      when "s"
        return base_name
      end
      return base_name
    end
    return void_dialog_token_name(token)
  rescue
    return nil
  end

  def normalize_void_possessive_text(text)
    body = text.to_s.dup
    body.gsub!(/('s)+/i, "'s")
    body.gsub!(/\b(Ronan|Nia|Seren)'s\s+'s\b/i, "\\1's")
    body.gsub!(/\b(Ronan|Nia|Seren)\s+place\b/i, "\\1's place")
    return body
  rescue
    return text.to_s
  end

  def normalize_void_text_glyphs(text)
    body = text.to_s.dup
    replacements = {
      [0x2018].pack("U") => "'",
      [0x2019].pack("U") => "'",
      [0x201A].pack("U") => "'",
      [0x201B].pack("U") => "'",
      [0x2032].pack("U") => "'",
      [0x201C].pack("U") => "\"",
      [0x201D].pack("U") => "\"",
      [0x201E].pack("U") => "\"",
      [0x2033].pack("U") => "\"",
      [0x2026].pack("U") => "...",
      [0x00A0].pack("U") => " "
    }
    replacements.each { |from, to| body.gsub!(from, to) }
    body.gsub!("PokÃƒÂ©mon", "Pokemon")
    body.gsub!("PokÃƒÂ©gear", "Pokegear")
    body.gsub!("Ã¢â‚¬â„¢", "'")
    body.gsub!("Ã¢â‚¬Ëœ", "'")
    body.gsub!("Ã¢â‚¬Å“", "\"")
    body.gsub!("Ã¢â‚¬ï¿½", "\"")
    body.gsub!("Ã¢â‚¬Â�", "\"")
    body.gsub!("Ã¢â‚¬Â¦", "...")
    body.gsub!("Ã‚", "")
    return body
  rescue
    return text.to_s
  end

  def apply_void_common_text_replacements(body)
    result = normalize_void_text_glyphs(body)
    player = void_host_player_name
    result.gsub!(/\{(?:player|player_name|trainer|trainer_name)\}/i, player)
    result.gsub!(/\{(?:c|character|char)\}/i, void_default_rival_name(2))
    result.gsub!(/\{(?:rival|rival1|rival1_name|r1|r1_name)\}/i, void_default_rival_name(1))
    result.gsub!(/\{(?:rival2|rival2_name|r2|r2_name)\}/i, void_default_rival_name(2))
    result.gsub!(/\{(?:rival3|rival3_name|r3|r3_name)\}/i, void_default_rival_name(3))
    result.gsub!(/\{(?:d_s|default_subject|default_rival_subject)\}/i, void_dialog_dynamic_subject)
    result.gsub!(/\{(?:d|default_rival)\}/i, void_default_rival_name(1))
    result.gsub!(/\{([A-Za-z0-9_]+:[^{}|]*\|[^{}]*)\}/) { void_dialog_token_value($1) || "" }
    result.gsub!(/\{([A-Za-z0-9_]+)\}/) { void_dialog_token_value($1) || $& }
    result = normalize_void_possessive_text(result)
    return result
  rescue
    return body.to_s
  end

  def prepare_void_message_text(text, map_id = nil)
    source = text.to_s
    return source if source.empty?
    trailer = source[/\001+\z/].to_s
    body = trailer.empty? ? source.dup : source[0, source.length - trailer.length]
    stripped = body.strip
    if stripped[/\A(?:pbSetDialoguePortrait|pbSetPlayerDialoguePortrait|pbSetRivalDialoguePortrait|pbClearDialoguePortrait|pbPortraitMessage|pbPlayerPortraitMessage|pbRivalPortraitMessage|VoidCharacterPortrait\.)\b/i]
      return trailer
    end
    player = void_host_player_name
    body.gsub!(/\{(?:player|player_name|trainer|trainer_name)\}/i, player)
    body.gsub!(/\{(?:c|character|char)\}/i, void_default_rival_name(2))
    body.gsub!(/\{(?:rival|rival1|rival1_name|r1|r1_name)\}/i, void_default_rival_name(1))
    body.gsub!(/\{(?:rival2|rival2_name|r2|r2_name)\}/i, void_default_rival_name(2))
    body.gsub!(/\{(?:rival3|rival3_name|r3|r3_name)\}/i, void_default_rival_name(3))
    body.gsub!(/\{(?:d|default_rival)\}/i, void_default_rival_name(1))
    body = apply_void_common_text_replacements(body)
    body.gsub!("PokÃ©mon", "Pokemon")
    body.gsub!("PokÃ©gear", "Pokegear")
    body.gsub!("â€™", "'")
    body.gsub!("â€œ", "\"")
    body.gsub!("â€�", "\"")
    body.gsub!("â€¦", "...")
    body.gsub!("Â", "")
    body.gsub!(/\{[A-Za-z0-9_]+_portrait\}/i, "")
    body.gsub!(/\\s\[([^\|\]]+)\|([^\]]+)\]/i) { $1.to_s }
    {
      "they" => "they", "them" => "them", "their" => "their", "theirs" => "theirs",
      "themself" => "themself", "are" => "are", "were" => "were", "have" => "have",
      "do" => "do"
    }.each do |token, value|
      body.gsub!(/\\#{token}/i) do |match|
        first = match[1, 1].to_s
        first == first.upcase ? value.capitalize : value
      end
    end
    body.gsub!(/<\/?(?:fs|c2|c3|ac|al|ar|b|i|u)[^>]*>/i, "")
    return "#{body}#{trailer}"
  rescue => e
    log("[void] message text normalization failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return text.to_s
  end

  def prepare_void_rendered_message_text(text, map_id = nil)
    source = text.to_s
    return source if source.empty?
    trailer = source[/\001+\z/].to_s
    body = trailer.empty? ? source.dup : source[0, source.length - trailer.length]
    stripped = body.strip
    if stripped[/\A(?:pbSetDialoguePortrait|pbSetPlayerDialoguePortrait|pbSetRivalDialoguePortrait|pbClearDialoguePortrait|pbPortraitMessage|pbPlayerPortraitMessage|pbRivalPortraitMessage|VoidCharacterPortrait\.)\b/i]
      return trailer
    end
    body.gsub!("PokÃ©mon", "Pokemon")
    body.gsub!("PokÃ©gear", "Pokegear")
    body.gsub!("â€™", "'")
    body.gsub!("â€œ", "\"")
    body.gsub!("â€�", "\"")
    body.gsub!("â€¦", "...")
    body.gsub!("Â", "")
    body = apply_void_common_text_replacements(body)
    # Host pbMessageDisplay prepends a colour tag based on the active
    # windowskin. Void's imported dark portrait windowskin can report bad
    # colour pixels in the host renderer, making otherwise valid text invisible.
    body = force_void_message_text_color(body)
    return "#{body}#{trailer}"
  rescue => e
    log("[void] rendered message text normalization failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return text.to_s
  end

  def imported_message_text_blank?(text)
    body = text.to_s.dup
    body.gsub!(/<[^>]*>/, "")
    body.gsub!(/\\[A-Za-z]+(?:\[[^\]]*\])?/, "")
    body.gsub!(/\\[.!^|]/, "")
    body.gsub!(/[\x00-\x1F\s]+/, "")
    return body.empty?
  rescue
    return text.to_s.empty?
  end

  def void_message_text_blank?(text)
    body = text.to_s
    body = body.gsub(/<[^>]*>/, "")
    body = body.gsub(/\\[A-Za-z]+\[[^\]]*\]/, "")
    body = body.gsub(/\\[A-Za-z]/, "")
    return body.strip.empty?
  rescue
    return text.to_s.strip.empty?
  end

  def prepare_void_message_window_for_text!(msgwindow, text = nil)
    return false if !msgwindow
    normalize_void_message_window!(msgwindow) if respond_to?(:normalize_void_message_window!)
    apply_void_message_text_colors!(msgwindow) if respond_to?(:apply_void_message_text_colors!)
    if msgwindow.respond_to?(:letterbyletter=)
      msgwindow.letterbyletter = true
    else
      msgwindow.instance_variable_set(:@letterbyletter, true)
    end
    if defined?(pbSetSystemFont) && msgwindow.respond_to?(:contents)
      contents = (msgwindow.contents rescue nil)
      pbSetSystemFont(contents) if contents
    end
    if !text.nil? && void_message_text_blank?(text)
      dispose_void_textbox_backdrop!(msgwindow) if respond_to?(:dispose_void_textbox_backdrop!)
    else
      update_void_textbox_backdrop!(msgwindow) if respond_to?(:update_void_textbox_backdrop!)
    end
    apply_void_message_text_colors!(msgwindow) if respond_to?(:apply_void_message_text_colors!)
    return true
  rescue => e
    log("[void] message window text prep failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def void_light_message_text_colors
    if defined?(MessageConfig)
      main = defined?(MessageConfig::LIGHT_TEXT_MAIN_COLOR) ? MessageConfig::LIGHT_TEXT_MAIN_COLOR : nil
      shadow = defined?(MessageConfig::LIGHT_TEXT_SHADOW_COLOR) ? MessageConfig::LIGHT_TEXT_SHADOW_COLOR : nil
      return [main, shadow] if main && shadow
    end
    return [Color.new(248, 248, 248), Color.new(72, 80, 88)] if defined?(Color)
    return [nil, nil]
  rescue
    return [nil, nil]
  end

  def void_message_window_text_colors(msgwindow)
    # Void's portrait message skin can be classified like a light host skin even
    # though its message body is dark. Normal body text must therefore use light
    # host colors rather than whatever the imported windowskin reports.
    colors = void_light_message_text_colors
    return colors if colors[0] && colors[1]
    if defined?(getDefaultTextColors) && msgwindow && msgwindow.respond_to?(:windowskin)
      colors = getDefaultTextColors(msgwindow.windowskin) rescue nil
      return colors if colors.is_a?(Array) && colors.length >= 2 && colors[0] && colors[1]
    end
    return [nil, nil]
  rescue
    return [nil, nil]
  end

  def void_message_color_tag
    colors = void_light_message_text_colors
    if colors[0] && colors[1] && defined?(shadowc3tag)
      return shadowc3tag(colors[0], colors[1])
    end
    return "<c3=F8F8F8,485058>"
  rescue
    return "<c3=F8F8F8,485058>"
  end

  def force_void_message_text_color(text)
    body = text.to_s
    return body if body.strip.empty?
    body.gsub!(/<\/?c(?:[23])?(?:=[^>]*)?>/i, "")
    return "#{void_message_color_tag}#{body}"
  rescue
    return text.to_s
  end

  def void_host_speech_frame
    candidates = [
      "Graphics/Windowskins/speech void",
      "Graphics/Windowskins/SpeechShow",
      "Graphics/Windowskins/Window",
      "Graphics/Windowskins/Windowskin"
    ]
    if respond_to?(:resolve_runtime_path_for_expansion) && respond_to?(:pokemon_void_expansion_ids)
      pokemon_void_expansion_ids.each do |expansion_id|
        candidates.each do |candidate|
          resolved = resolve_runtime_path_for_expansion(expansion_id, candidate, [".png"])
          return resolved if resolved && (!respond_to?(:runtime_file_exists?) || runtime_file_exists?(resolved))
        end
      end
    end
    if respond_to?(:resolve_runtime_path)
      candidates.each do |candidate|
        resolved = resolve_runtime_path(candidate, [".png"])
        return resolved if resolved && (!respond_to?(:runtime_file_exists?) || runtime_file_exists?(resolved))
      end
    end
    return candidates[0]
  rescue
    return "Graphics/Windowskins/speech void"
  end

  def void_textbox_picture_path
    candidates = [
      "Graphics/Pictures/void_textbox",
      "Graphics/Pictures/VoidTextbox",
      "Graphics/Pictures/void textbox"
    ]
    if respond_to?(:resolve_runtime_path_for_expansion) && respond_to?(:pokemon_void_expansion_ids)
      pokemon_void_expansion_ids.each do |expansion_id|
        candidates.each do |candidate|
          resolved = resolve_runtime_path_for_expansion(expansion_id, candidate, [".png"])
          return resolved if resolved && (!respond_to?(:runtime_file_exists?) || runtime_file_exists?(resolved))
        end
      end
    end
    if respond_to?(:resolve_runtime_path)
      candidates.each do |candidate|
        resolved = resolve_runtime_path(candidate, [".png"])
        return resolved if resolved && (!respond_to?(:runtime_file_exists?) || runtime_file_exists?(resolved))
      end
    end
    return nil
  rescue
    return nil
  end

  def dispose_void_textbox_backdrop!(msgwindow)
    return false if !msgwindow || !msgwindow.respond_to?(:instance_variable_get)
    sprite = msgwindow.instance_variable_get(:@tef_void_textbox_backdrop)
    return true if !sprite
    bitmap = (sprite.bitmap rescue nil)
    sprite.dispose if sprite.respond_to?(:dispose) && !(sprite.disposed? rescue false)
    bitmap.dispose if bitmap && bitmap.respond_to?(:dispose) && !(bitmap.disposed? rescue false)
    msgwindow.instance_variable_set(:@tef_void_textbox_backdrop, nil)
    msgwindow.instance_variable_set(:@tef_void_textbox_backdrop_path, nil)
    return true
  rescue => e
    log("[void] textbox backdrop cleanup failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def update_void_textbox_backdrop!(msgwindow)
    return false if !msgwindow || !defined?(Sprite) || !defined?(Bitmap)
    path = void_textbox_picture_path
    return false if path.to_s.empty?
    sprite = msgwindow.instance_variable_get(:@tef_void_textbox_backdrop) if msgwindow.respond_to?(:instance_variable_get)
    old_path = msgwindow.instance_variable_get(:@tef_void_textbox_backdrop_path) if msgwindow.respond_to?(:instance_variable_get)
    if sprite && (sprite.disposed? rescue false)
      sprite = nil
    end
    if !sprite || old_path != path
      dispose_void_textbox_backdrop!(msgwindow)
      viewport = (msgwindow.viewport rescue nil)
      sprite = Sprite.new(viewport)
      sprite.bitmap = Bitmap.new(path)
      msgwindow.instance_variable_set(:@tef_void_textbox_backdrop, sprite)
      msgwindow.instance_variable_set(:@tef_void_textbox_backdrop_path, path)
    end
    bitmap = (sprite.bitmap rescue nil)
    width = bitmap && bitmap.respond_to?(:width) ? bitmap.width : 0
    height = bitmap && bitmap.respond_to?(:height) ? bitmap.height : 0
    if defined?(Graphics)
      graphics_width = (Graphics.width rescue 0).to_i
      graphics_height = (Graphics.height rescue 0).to_i
      sprite.x = graphics_width > width ? ((graphics_width - width) / 2) : 0
      sprite.y = graphics_height > height ? (graphics_height - height) : 0
    else
      sprite.x = 0
      sprite.y = (msgwindow.y rescue 0)
    end
    sprite.z = [(msgwindow.z rescue 99999).to_i - 1, 0].max if sprite.respond_to?(:z=)
    sprite.visible = (msgwindow.visible rescue true) if sprite.respond_to?(:visible=)
    msgwindow.opacity = 0 if msgwindow.respond_to?(:opacity=)
    msgwindow.back_opacity = 0 if msgwindow.respond_to?(:back_opacity=)
    msgwindow.contents_opacity = 255 if msgwindow.respond_to?(:contents_opacity=)
    return true
  rescue => e
    log("[void] textbox backdrop skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def apply_void_message_text_colors!(msgwindow)
    colors = void_message_window_text_colors(msgwindow)
    return false if !msgwindow || !colors[0] || !colors[1]
    msgwindow.instance_variable_set(:@baseColor, colors[0])
    msgwindow.instance_variable_set(:@shadowColor, colors[1])
    if msgwindow.respond_to?(:contents)
      contents = (msgwindow.contents rescue nil)
      if contents && contents.respond_to?(:font) && contents.font && contents.font.respond_to?(:color=)
        contents.font.color = colors[0]
      end
    end
    return true
  rescue => e
    log("[void] message text color fallback failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def prime_void_message_color_ivars!(msgwindow)
    colors = void_message_window_text_colors(msgwindow)
    return false if !msgwindow || !colors[0] || !colors[1]
    msgwindow.instance_variable_set(:@baseColor, colors[0])
    msgwindow.instance_variable_set(:@shadowColor, colors[1])
    return true
  rescue
    return false
  end

  def apply_void_host_message_skin!(msgwindow)
    return false if !msgwindow
    prime_void_message_color_ivars!(msgwindow) if respond_to?(:prime_void_message_color_ivars!)
    return true if !msgwindow.respond_to?(:setSkin)
    skin = void_host_speech_frame
    return false if skin.to_s.empty?
    if msgwindow.instance_variable_get(:@tef_void_message_skin) != skin
      prime_void_message_color_ivars!(msgwindow) if respond_to?(:prime_void_message_color_ivars!)
      arity = msgwindow.method(:setSkin).arity rescue 1
      if arity == 1
        msgwindow.setSkin(skin)
      else
        msgwindow.setSkin(skin, false)
      end
      msgwindow.instance_variable_set(:@tef_void_message_skin, skin)
    end
    apply_void_message_text_colors!(msgwindow) if respond_to?(:apply_void_message_text_colors!)
    return true
  rescue => e
    apply_void_message_text_colors!(msgwindow) if respond_to?(:apply_void_message_text_colors!)
    log("[void] host message skin fallback skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def normalize_void_message_window!(msgwindow)
    return false if !msgwindow
    apply_void_host_message_skin!(msgwindow) if respond_to?(:apply_void_host_message_skin!)
    if msgwindow.respond_to?(:visible=)
      msgwindow.visible = true
    else
      msgwindow.instance_variable_set(:@visible, true)
    end
    if msgwindow.respond_to?(:opacity=)
      msgwindow.opacity = 255
    else
      msgwindow.instance_variable_set(:@opacity, 255)
    end
    if msgwindow.respond_to?(:back_opacity=)
      msgwindow.back_opacity = 255
    else
      msgwindow.instance_variable_set(:@back_opacity, 255)
    end
    if msgwindow.respond_to?(:contents_opacity=)
      msgwindow.contents_opacity = 255
    else
      msgwindow.instance_variable_set(:@contents_opacity, 255)
    end
    if defined?(Graphics)
      if msgwindow.respond_to?(:z=)
        msgwindow.z = 99999
      else
        msgwindow.instance_variable_set(:@z, 99999)
      end
    end
    apply_void_message_text_colors!(msgwindow) if respond_to?(:apply_void_message_text_colors!)
    return true
  rescue => e
    log("[void] message window normalization failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def reset_void_message_state!
    reset_speechbubble_state! if respond_to?(:reset_speechbubble_state!)
    if defined?($PokemonTemp) && $PokemonTemp
      temp = $PokemonTemp
      temp.speechbubble_bubble = nil if temp.respond_to?(:speechbubble_bubble=)
      temp.speechbubble_talking = nil if temp.respond_to?(:speechbubble_talking=)
      temp.speechbubble_alwaysDown = false if temp.respond_to?(:speechbubble_alwaysDown=)
      temp.speechbubble_alwaysUp = false if temp.respond_to?(:speechbubble_alwaysUp=)
      temp.speechbubble_outofrange = false if temp.respond_to?(:speechbubble_outofrange=)
      temp.speechbubble_arrow = nil if temp.respond_to?(:speechbubble_arrow=)
      temp.speechbubble_vp = nil if temp.respond_to?(:speechbubble_vp=)
    end
    if defined?($game_system) && $game_system
      $game_system.message_position = 2 if $game_system.respond_to?(:message_position=)
      $game_system.message_frame = 0 if $game_system.respond_to?(:message_frame=)
    end
    return true
  rescue => e
    log("[void] message state reset failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def prepare_new_project_text(text, map_id = nil)
    result = text.to_s
    if respond_to?(:anil_active_now?) && anil_active_now?(map_id) && respond_to?(:anil_translate_text)
      result = anil_translate_text(result, map_id)
    elsif realidea_active_now?(map_id)
      result = realidea_translate_text(result, map_id)
    elsif opalo_active_now?(map_id)
      result = opalo_translate_text(result, map_id)
    end
    result = cleanup_imported_message_text(result, map_id) if new_project_active_now?(map_id)
    result = prepare_void_message_text(result, map_id) if respond_to?(:void_active_now?) && void_active_now?(map_id)
    return result
  rescue
    return text.to_s
  end

  def prepare_new_project_commands(commands, map_id = nil)
    return commands if !commands
    void_commands = respond_to?(:void_active_now?) && void_active_now?(map_id)
    return Array(commands).map do |entry|
      prepared = prepare_new_project_text(entry, map_id)
      prepared = prepared.gsub(/\A\s*<c[23]=[^>]*>/i, "") if void_commands
      prepared
    end
  rescue
    return commands
  end

  def host_player_name_for_expansion
    name = ($Trainer.name rescue nil).to_s.strip
    return name if !name.empty?
    return "Player"
  rescue
    return "Player"
  end

  def empyrean_metadata
    expansion = active_project_expansion_id(empyrean_expansion_ids) || EMPYREAN_EXPANSION_ID
    state = state_for(expansion) rescue nil
    return nil if !state || !state.respond_to?(:metadata)
    state.metadata = {} if state.metadata.nil? && state.respond_to?(:metadata=)
    return state.metadata if state.metadata.is_a?(Hash)
    return nil
  rescue
    return nil
  end

  def new_project_metadata(expansion_id = nil)
    expansion = expansion_id.to_s
    expansion = current_new_project_expansion_id if expansion.empty?
    return nil if expansion.to_s.empty?
    state = state_for(expansion) rescue nil
    return nil if !state || !state.respond_to?(:metadata)
    state.metadata = {} if state.metadata.nil? && state.respond_to?(:metadata=)
    return state.metadata if state.metadata.is_a?(Hash)
    return nil
  rescue
    return nil
  end

  def new_project_player_visual_state(trainer = nil)
    trainer ||= ($Trainer rescue nil)
    return nil if !trainer
    state = {}
    NEW_PROJECT_HOST_PLAYER_VISUAL_KEYS.each do |key|
      state[key] = trainer.send(key) if trainer.respond_to?(key)
    end
    if defined?($game_player) && $game_player
      state["character_name"] = ($game_player.instance_variable_get(:@character_name) rescue nil)
      state["default_character_name"] = ($game_player.instance_variable_get(:@defaultCharacterName) rescue nil)
      state["charset_data"] = ($game_player.charsetData rescue nil) if $game_player.respond_to?(:charsetData)
    end
    return state
  rescue => e
    log("[travel] player visual snapshot failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def capture_host_player_visual_state_for_expansion!(expansion_id = nil, reason = "entry", force = false)
    expansion = canonical_new_project_id(expansion_id || current_new_project_expansion_id)
    return false if expansion.to_s.empty?
    return false if !expansion_id_in_list?(expansion, new_project_identity_expansion_ids)
    meta = new_project_metadata(expansion)
    return false if !meta
    return true if !force && meta["host_player_visual_state"].is_a?(Hash)
    state = new_project_player_visual_state
    return false if !state.is_a?(Hash) || state.empty?
    meta["host_player_visual_state"] = state
    meta["host_player_visual_state_reason"] = reason.to_s
    meta["host_player_visual_state_at"] = timestamp_string if respond_to?(:timestamp_string)
    log("[#{expansion}] captured host player visuals for #{reason}") if respond_to?(:log)
    return true
  rescue => e
    log("[travel] host player visual capture failed for #{expansion_id.inspect}: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def host_player_visual_state_for_expansion(expansion_id = nil)
    expansion = canonical_new_project_id(expansion_id || current_new_project_expansion_id)
    meta = new_project_metadata(expansion)
    state = meta["host_player_visual_state"] if meta
    return state if state.is_a?(Hash)
    return nil
  rescue
    return nil
  end

  def restore_host_player_visual_state_for_expansion!(expansion_id = nil, reason = "runtime", scene = nil)
    expansion = canonical_new_project_id(expansion_id || current_new_project_expansion_id)
    state = host_player_visual_state_for_expansion(expansion)
    trainer = $Trainer rescue nil
    if trainer && state.is_a?(Hash)
      NEW_PROJECT_HOST_PLAYER_VISUAL_KEYS.each do |key|
        next if !state.has_key?(key)
        trainer.instance_variable_set("@#{key}", state[key])
      end
    end
    apply_host_player_visuals!("#{expansion} #{reason}") if respond_to?(:apply_host_player_visuals!)
    if scene && scene.respond_to?(:reset_player_sprite)
      scene.reset_player_sprite
    elsif defined?($scene) && $scene && $scene.respond_to?(:reset_player_sprite)
      $scene.reset_player_sprite
    end
    return true
  rescue => e
    log("[#{expansion_id || "new_project"}] host player visual restore failed after #{reason}: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def new_project_visuals_changed_from_host?(expansion_id = nil)
    state = host_player_visual_state_for_expansion(expansion_id)
    return false if !state.is_a?(Hash)
    trainer = $Trainer rescue nil
    if trainer
      NEW_PROJECT_HOST_PLAYER_VISUAL_KEYS.each do |key|
        next if !state.has_key?(key) || !trainer.respond_to?(key)
        return true if trainer.send(key) != state[key]
      end
    end
    if defined?($game_player) && $game_player
      expected_name = state["character_name"].to_s
      current_name = ($game_player.instance_variable_get(:@character_name) rescue "").to_s
      current_name = ($game_player.character_name rescue current_name).to_s if current_name.empty?
      return true if !expected_name.empty? && !current_name.empty? && current_name != expected_name
    end
    return true if defined?($game_player) && $game_player && $game_player.respond_to?(:hasGraphicsOverride?) &&
                   $game_player.hasGraphicsOverride?
    return false
  rescue
    return false
  end

  def infinity_suppress_player_visual_assignment?(_field = nil, _value = nil)
    return false if @infinity_restoring_host_visuals
    return infinity_active_now? if respond_to?(:infinity_active_now?)
    return false
  rescue
    return false
  end

  def infinity_note_suppressed_player_visual_assignment!(field, value)
    @infinity_suppressed_visual_assignments ||= {}
    key = "#{field}=#{value.inspect}"
    return if @infinity_suppressed_visual_assignments[key]
    @infinity_suppressed_visual_assignments[key] = true
    log("[infinity] suppressed imported player visual #{key} to preserve host player sprite") if respond_to?(:log)
  rescue
  end

  def infinity_restore_host_player_visuals!(reason = "runtime", scene = nil)
    return false if !infinity_active_now?
    @infinity_restoring_host_visuals = true
    result = restore_host_player_visual_state_for_expansion!(INFINITY_EXPANSION_ID, reason, scene)
    log("[infinity] restored host player visuals after #{reason}") if result && respond_to?(:log)
    return result
  rescue => e
    log("[infinity] host player visual restore failed after #{reason}: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  ensure
    @infinity_restoring_host_visuals = false
  end

  def infinity_player_visuals_need_restore?
    return false if !infinity_active_now?
    return new_project_visuals_changed_from_host?(INFINITY_EXPANSION_ID)
  rescue
    return false
  end

  def infinity_repair_lab_stair_landing!(reason = "transfer")
    return false if !defined?($game_map) || !$game_map || !defined?($game_player) || !$game_player
    return false if !infinity_lab_map?($game_map.map_id)
    if defined?($game_temp) && $game_temp
      return false if $game_temp.respond_to?(:player_transferring) && $game_temp.player_transferring
      return false if $game_temp.respond_to?(:transition_processing) && $game_temp.transition_processing
      return false if $game_temp.respond_to?(:message_window_showing) && $game_temp.message_window_showing
    end
    return false if $game_player.respond_to?(:move_route_forcing) && $game_player.move_route_forcing
    return false if defined?(pbMapInterpreterRunning?) && pbMapInterpreterRunning?
    landing = infinity_lab_stair_landing_for($game_player.x, $game_player.y)
    return false if !landing
    target_x, target_y, direction = landing
    $game_player.unlock if $game_player.respond_to?(:unlock)
    $game_player.cancelMoveRoute if $game_player.respond_to?(:cancelMoveRoute)
    $game_player.moveto(target_x, target_y) if $game_player.respond_to?(:moveto)
    if $game_player.respond_to?(:direction=)
      $game_player.direction = direction
    else
      case integer(direction, 2)
      when 4 then $game_player.turn_left if $game_player.respond_to?(:turn_left)
      when 6 then $game_player.turn_right if $game_player.respond_to?(:turn_right)
      when 8 then $game_player.turn_up if $game_player.respond_to?(:turn_up)
      else $game_player.turn_down if $game_player.respond_to?(:turn_down)
      end
    end
    $game_player.through = false if $game_player.respond_to?(:through=)
    $game_player.transparent = false if $game_player.respond_to?(:transparent=)
    $game_player.straighten if $game_player.respond_to?(:straighten)
    $game_map.need_refresh = true if $game_map.respond_to?(:need_refresh=)
    if defined?($game_temp) && $game_temp
      $game_temp.player_transferring = false if $game_temp.respond_to?(:player_transferring=)
      $game_temp.transition_processing = false if $game_temp.respond_to?(:transition_processing=)
      $game_temp.transition_name = "" if $game_temp.respond_to?(:transition_name=)
    end
    log("[infinity] repaired lab stair landing #{reason}: #{$game_player.x},#{$game_player.y}") if respond_to?(:log)
    return true
  rescue => e
    log("[infinity] lab stair landing repair failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def infinity_after_transfer_repair!(_previous_map_id = nil, reason = "transfer")
    return false if !infinity_active_now?
    fixed = false
    fixed = infinity_restore_host_player_visuals!(reason) || fixed if infinity_player_visuals_need_restore?
    return fixed
  rescue => e
    log("[infinity] post-transfer repair failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def infinity_runtime_watchdog_update!(scene = nil)
    return false if !infinity_active_now?
    @infinity_visual_watchdog_frame = integer(@infinity_visual_watchdog_frame, 0) + 1
    fixed = infinity_repair_lab_stair_landing!("idle_watchdog")
    return fixed if (@infinity_visual_watchdog_frame % INFINITY_VISUAL_WATCHDOG_FRAMES) != 0
    fixed = infinity_restore_host_player_visuals!("watchdog", scene) || fixed if infinity_player_visuals_need_restore?
    return fixed
  rescue => e
    log("[infinity] watchdog failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def new_project_deep_clone(value)
    return nil if value.nil?
    return Marshal.load(Marshal.dump(value))
  rescue
    if value.is_a?(Array)
      return value.map { |entry| new_project_deep_clone(entry) }
    end
    if value.is_a?(Hash)
      cloned = {}
      value.each { |key, entry| cloned[new_project_deep_clone(key)] = new_project_deep_clone(entry) }
      return cloned
    end
    begin
      return value.clone
    rescue
      return value
    end
  end

  def new_project_party_isolation_expansion_id(expansion_id = nil)
    expansion = expansion_id.to_s
    expansion = current_new_project_expansion_id if expansion.empty?
    expansion = canonical_new_project_id(expansion)
    return nil if expansion.to_s.empty?
    return expansion if NEW_PROJECT_PARTY_ISOLATION_IDS.map { |id| canonical_new_project_id(id) }.include?(expansion)
    return nil
  rescue
    return nil
  end

  def new_project_party_session(expansion_id = nil)
    expansion = new_project_party_isolation_expansion_id(expansion_id)
    return nil if expansion.to_s.empty?
    meta = new_project_metadata(expansion)
    return nil if !meta
    meta["party_session"] = {} if !meta["party_session"].is_a?(Hash)
    return meta["party_session"]
  rescue
    return nil
  end

  def new_project_party_session_active?(expansion_id = nil)
    session = new_project_party_session(expansion_id)
    return !!(session && session["active"])
  rescue
    return false
  end

  def activate_new_project_party_session!(expansion_id = nil, reason = "entry")
    expansion = new_project_party_isolation_expansion_id(expansion_id)
    return false if expansion.to_s.empty?
    return false if !defined?($Trainer) || !$Trainer || !$Trainer.respond_to?(:party)
    session = new_project_party_session(expansion)
    return false if !session
    if session["active"]
      session["expansion_party_snapshot"] = new_project_deep_clone($Trainer.party)
      return true
    end
    session["host_party_snapshot"] ||= new_project_deep_clone($Trainer.party)
    expansion_party = session["expansion_party_snapshot"]
    expansion_party = [] if !expansion_party.is_a?(Array)
    $Trainer.party = new_project_deep_clone(expansion_party)
    $player = $Trainer if defined?($player)
    session["active"] = true
    session["last_reason"] = reason.to_s
    session["updated_at"] = timestamp_string if respond_to?(:timestamp_string)
    log("[#{expansion}] activated isolated party session for #{reason}; host_party_preserved=#{Array(session["host_party_snapshot"]).length}, expansion_party=#{Array($Trainer.party).length}") if respond_to?(:log)
    return true
  rescue => e
    log("[new_project] party session activation failed for #{expansion_id}: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def save_new_project_party_session!(expansion_id = nil, reason = "runtime")
    expansion = new_project_party_isolation_expansion_id(expansion_id)
    return false if expansion.to_s.empty?
    return false if !defined?($Trainer) || !$Trainer || !$Trainer.respond_to?(:party)
    session = new_project_party_session(expansion)
    return false if !session || !session["active"]
    session["expansion_party_snapshot"] = new_project_deep_clone($Trainer.party)
    session["last_reason"] = reason.to_s
    session["updated_at"] = timestamp_string if respond_to?(:timestamp_string)
    return true
  rescue => e
    log("[new_project] party session save failed for #{expansion_id}: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def restore_new_project_host_party!(expansion_id = nil, reason = "return")
    expansion = new_project_party_isolation_expansion_id(expansion_id)
    return false if expansion.to_s.empty?
    return false if !defined?($Trainer) || !$Trainer || !$Trainer.respond_to?(:party)
    session = new_project_party_session(expansion)
    return false if !session || !session["active"]
    session["expansion_party_snapshot"] = new_project_deep_clone($Trainer.party)
    host_party = session["host_party_snapshot"]
    if host_party.is_a?(Array)
      $Trainer.party = new_project_deep_clone(host_party)
      $player = $Trainer if defined?($player)
      session.delete("host_party_snapshot")
    end
    session["active"] = false
    session["last_reason"] = reason.to_s
    session["updated_at"] = timestamp_string if respond_to?(:timestamp_string)
    log("[#{expansion}] restored host party after #{reason}; host_party=#{Array($Trainer.party).length}, saved_expansion_party=#{Array(session["expansion_party_snapshot"]).length}") if respond_to?(:log)
    return true
  rescue => e
    log("[new_project] host party restore failed for #{expansion_id}: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def restore_all_new_project_host_parties!(reason = "host context")
    restored = false
    NEW_PROJECT_PARTY_ISOLATION_IDS.each do |expansion_id|
      restored = restore_new_project_host_party!(expansion_id, reason) || restored
    end
    return restored
  rescue
    return false
  end

  def ensure_new_project_party_can_receive_gift!(reason = "gift")
    expansion = new_project_party_isolation_expansion_id
    return false if expansion.to_s.empty?
    return save_new_project_party_session!(expansion, reason) if new_project_party_session_active?(expansion)
    return false
  rescue => e
    log("[new_project] gift party guard failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def new_project_banked_gift_expansion_id(expansion_id = nil)
    expansion = expansion_id.to_s
    expansion = current_new_project_expansion_id if expansion.empty?
    expansion = canonical_new_project_id(expansion)
    return nil if expansion.to_s.empty?
    return expansion if NEW_PROJECT_BANKED_GIFT_IDS.map { |id| canonical_new_project_id(id) }.include?(expansion)
    return nil
  rescue
    return nil
  end

  def record_new_project_banked_gift!(expansion_id, pokemon, box, source)
    context = current_runtime_context if respond_to?(:current_runtime_context)
    context = {} if !context.is_a?(Hash)
    map_id = integer(context[:map_id], 0)
    map_id = integer($game_map.map_id, 0) if map_id <= 0 && defined?($game_map) && $game_map
    event_id = integer(context[:event_id], 0)
    @new_project_banked_gift = {
      :expansion_id => canonical_new_project_id(expansion_id),
      :pokemon      => pokemon,
      :box          => integer(box, -1),
      :map_id       => map_id,
      :event_id     => event_id,
      :source       => source.to_s
    }
    meta = new_project_metadata(expansion_id)
    if meta
      meta["last_banked_gift"] = {
        "species"    => (pokemon.species rescue nil).to_s,
        "name"       => (pokemon.name rescue nil).to_s,
        "box"        => integer(box, -1),
        "map_id"     => map_id,
        "event_id"   => event_id,
        "source"     => source.to_s,
        "updated_at" => (timestamp_string if respond_to?(:timestamp_string))
      }
    end
    return @new_project_banked_gift
  rescue => e
    log("[new_project] banked gift record failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def current_new_project_banked_gift_pokemon
    gift = @new_project_banked_gift
    return nil if !gift.is_a?(Hash) || !gift[:pokemon]
    expansion = new_project_banked_gift_expansion_id
    return nil if expansion.to_s.empty?
    return nil if canonical_new_project_id(gift[:expansion_id]).to_s != expansion.to_s
    context = current_runtime_context if respond_to?(:current_runtime_context)
    return nil if !context.is_a?(Hash)
    context_map_id = integer(context[:map_id], 0)
    context_event_id = integer(context[:event_id], 0)
    return nil if integer(gift[:map_id], 0) > 0 && context_map_id > 0 && integer(gift[:map_id], 0) != context_map_id
    return nil if integer(gift[:event_id], 0) > 0 && context_event_id > 0 && integer(gift[:event_id], 0) != context_event_id
    return gift[:pokemon]
  rescue
    return nil
  end

  def resolve_new_project_gift_species_ref(pkmn)
    return pkmn if pkmn.nil?
    return pkmn if defined?(Pokemon) && pkmn.is_a?(Pokemon)
    expansion = current_new_project_expansion_id if respond_to?(:current_new_project_expansion_id)
    expansion = current_map_expansion_id if expansion.to_s.empty? && respond_to?(:current_map_expansion_id)
    return pkmn if expansion.to_s.empty?
    canonical_expansion = canonical_new_project_id(expansion) if respond_to?(:canonical_new_project_id)
    canonical_expansion = expansion if canonical_expansion.to_s.empty?
    resolved = nil
    resolved = resolve_expansion_species(canonical_expansion, pkmn) if respond_to?(:resolve_expansion_species)
    if pokemon_void_expansion_ids.include?(canonical_expansion.to_s) && pkmn.respond_to?(:to_sym)
      resolved = POKEMON_VOID_SPECIES_ALIASES[pkmn.to_sym] if resolved.nil? || resolved == pkmn
    end
    data = GameData::Species.try_get(resolved) rescue nil
    return data.species if data && data.respond_to?(:species)
    return resolved if resolved
    return pkmn
  rescue => e
    log("[new_project] gift species resolution failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return pkmn
  end

  def bank_new_project_gift_pokemon_if_needed!(pkmn, level = 1, see_form = true, dont_randomize = false, variable_to_save = nil, source = "gift")
    expansion = new_project_banked_gift_expansion_id
    return nil if expansion.to_s.empty?
    return nil if !defined?($Trainer) || !$Trainer || !$Trainer.respond_to?(:party_full?)
    return nil if !$Trainer.party_full?
    return nil if !defined?($PokemonStorage) || !$PokemonStorage || !$PokemonStorage.respond_to?(:pbStoreCaught)
    return nil if defined?(pbBoxesFull) && pbBoxesFull?
    pokemon = resolve_new_project_gift_species_ref(pkmn)
    pokemon = Pokemon.new(pokemon, level) if defined?(Pokemon) && !pokemon.is_a?(Pokemon)
    return false if !pokemon
    tryRandomizeGiftPokemon(pokemon, dont_randomize) if defined?(tryRandomizeGiftPokemon)
    species_name = (pokemon.speciesName rescue nil) || (pokemon.name rescue nil) || pokemon.to_s
    silent_source = source.to_s[/Silent/]
    pbMessage(_INTL("{1} obtained {2}!\\me[Pkmn get]\\wtnp[20]\1", $Trainer.name, species_name)) if !silent_source &&
                                                                                                      defined?(pbMessage) &&
                                                                                                      defined?(_INTL)
    if $Trainer.respond_to?(:pokedex) && $Trainer.pokedex
      $Trainer.pokedex.register(pokemon) if see_form && $Trainer.pokedex.respond_to?(:register)
      $Trainer.pokedex.set_seen(pokemon.species) if $Trainer.pokedex.respond_to?(:set_seen) && pokemon.respond_to?(:species)
      $Trainer.pokedex.set_owned(pokemon.species) if $Trainer.pokedex.respond_to?(:set_owned) && pokemon.respond_to?(:species)
    end
    pokemon.record_first_moves if pokemon.respond_to?(:record_first_moves)
    box = $PokemonStorage.pbStoreCaught(pokemon)
    return false if integer(box, -1) < 0
    pbSet(variable_to_save, pokemon) if variable_to_save && defined?(pbSet)
    record_new_project_banked_gift!(expansion, pokemon, box, source)
    log("[#{expansion}] banked full-party gift #{species_name.inspect} in box #{box} via #{source}") if respond_to?(:log)
    return true
  rescue => e
    log("[new_project] banked gift handling failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def reconcile_new_project_party_session_for_current_map!(reason = "map context")
    map_expansion = current_map_expansion_id if respond_to?(:current_map_expansion_id)
    expansion = map_expansion.to_s.empty? ? nil : new_project_party_isolation_expansion_id(map_expansion)
    if expansion.to_s.empty?
      return restore_all_new_project_host_parties!(reason)
    end
    return save_new_project_party_session!(expansion, reason) if new_project_party_session_active?(expansion)
    return false
  rescue => e
    log("[new_project] party session reconcile failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def new_project_handle_boundary_party_session!(previous_expansion, current_expansion)
    previous_id = previous_expansion.to_s.empty? ? nil : new_project_party_isolation_expansion_id(previous_expansion)
    current_id = current_expansion.to_s.empty? ? nil : new_project_party_isolation_expansion_id(current_expansion)
    if !current_id.to_s.empty?
      return reconcile_new_project_party_session_for_current_map!("entry boundary")
    end
    return restore_new_project_host_party!(previous_id, "expansion boundary") if !previous_id.to_s.empty?
    return false
  rescue => e
    log("[new_project] party boundary handling failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def ensure_player_global!
    if defined?($Trainer) && $Trainer
      $player = $Trainer if !defined?($player) || $player.nil?
    end
    return $player if defined?($player)
    return nil
  rescue
    return nil
  end

  def empyrean_log_once(key, message)
    @empyrean_log_once ||= {}
    return if @empyrean_log_once[key]
    @empyrean_log_once[key] = true
    log(message) if respond_to?(:log)
  rescue
  end

  def empyrean_host_female?
    trainer = $Trainer rescue nil
    return false if !trainer
    return true if trainer.respond_to?(:female?) && trainer.female?
    return false if trainer.respond_to?(:male?) && trainer.male?
    gender = trainer.gender if trainer.respond_to?(:gender)
    return true if defined?(GENDER_FEMALE) && gender == GENDER_FEMALE
    return false
  rescue
    return false
  end

  def host_player_female?
    return host_player_gender_symbol == :female
  end

  def host_player_gender_symbol
    trainer = $Trainer rescue nil
    return :unknown if !trainer
    return :female if trainer.respond_to?(:female?) && trainer.female?
    return :male if trainer.respond_to?(:male?) && trainer.male?
    gender = trainer.gender if trainer.respond_to?(:gender)
    return :female if defined?(GENDER_FEMALE) && gender == GENDER_FEMALE
    return :male if defined?(GENDER_MALE) && gender == GENDER_MALE
    return :neutral
  rescue
    return :unknown
  end

  def host_player_male?
    return host_player_gender_symbol != :female
  rescue
    return true
  end

  def host_player_charset_name
    trainer = $Trainer rescue nil
    visual_state = host_player_visual_state_for_expansion if respond_to?(:host_player_visual_state_for_expansion)
    if visual_state.is_a?(Hash)
      state_id = integer(visual_state["character_ID"], -1)
      if defined?(GameData::Metadata) && state_id >= 0
        meta = GameData::Metadata.get_player(state_id) rescue nil
        charset_name = pbGetPlayerCharset(meta, 1, trainer, true) if meta && defined?(pbGetPlayerCharset)
        return charset_name.to_s if charset_name && !charset_name.to_s.empty?
        return meta[1].to_s if meta.respond_to?(:[]) && meta[1] && !meta[1].to_s.empty?
      end
      state_name = visual_state["character_name"].to_s
      return state_name if !state_name.empty?
    end
    if defined?(GameData::Metadata) && trainer
      meta = GameData::Metadata.get_player(trainer.character_ID) rescue nil
      charset = 1
      charset_name = pbGetPlayerCharset(meta, charset, trainer, true) if meta && defined?(pbGetPlayerCharset)
      return charset_name.to_s if charset_name && !charset_name.to_s.empty?
      return meta[1].to_s if meta.respond_to?(:[]) && meta[1] && !meta[1].to_s.empty?
    end
    name = ($game_player.character_name rescue "").to_s
    return name if !name.empty?
    return nil
  rescue
    return nil
  end

  def apply_host_player_visuals!(label = "new_project")
    return false if !$game_player
    $game_player.removeGraphicsOverride if $game_player.respond_to?(:removeGraphicsOverride)
    $game_player.instance_variable_set(:@defaultCharacterName, "") if $game_player.instance_variable_defined?(:@defaultCharacterName)
    $game_player.charsetData = nil if $game_player.respond_to?(:charsetData=)
    charset_name = host_player_charset_name
    if charset_name && !charset_name.empty?
      $game_player.character_name = charset_name if $game_player.respond_to?(:character_name=)
      $game_player.instance_variable_set(:@character_name, charset_name)
    end
    $game_player.through = false if $game_player.respond_to?(:through=)
    $game_player.transparent = false if $game_player.respond_to?(:transparent=)
    $game_player.calculate_bush_depth if $game_player.respond_to?(:calculate_bush_depth)
    $game_player.refresh if $game_player.respond_to?(:refresh)
    $game_player.straighten if $game_player.respond_to?(:straighten)
    $game_map.need_refresh = true if defined?($game_map) && $game_map
    log("[#{label}] preserved host player visuals #{charset_name.inspect}") if respond_to?(:log) && charset_name
    return true
  rescue => e
    log("[#{label}] host player visual sync failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def host_gender_choice_index(commands)
    list = Array(commands).map { |entry| entry.to_s }
    return nil if list.empty?
    female = host_player_female?
    female_index = list.index { |entry| entry[/female|girl|woman|chica|mujer|right|derecha/i] }
    male_index = list.index { |entry| entry[/male|boy|man|chico|hombre|left|izquierda/i] }
    if female
      return female_index if !female_index.nil?
      return 1 if list.length == 2
    else
      return male_index if !male_index.nil?
      return 0
    end
    return 0
  rescue
    return nil
  end

  def plausible_rival_name?(name)
    text = name.to_s.strip
    return false if text.empty?
    normalized = text.downcase.gsub(/[^a-z0-9]+/, " ").strip
    return false if normalized.empty?
    generic_prompts = [
      "rival",
      "your rival",
      "the rival",
      "my rival",
      "rival name",
      "rival s name",
      "your rival name",
      "your rival s name",
      "rival nickname",
      "rival s nickname",
      "your rival nickname",
      "your rival s nickname",
      "name",
      "nickname",
      "trainer",
      "player"
    ]
    return false if generic_prompts.include?(normalized)
    return false if normalized =~ /\Arival\s*\d*\z/
    return false if normalized =~ /\A(?:your\s+|the\s+|my\s+)?rival(?:\s+s)?\s+(?:name|nickname)\z/
    return true
  rescue
    return false
  end

  def host_game_variable_value(variable_id)
    identifier = integer(variable_id, 0)
    return nil if identifier <= 0 || !defined?($game_variables) || !$game_variables
    if $game_variables.respond_to?(:tef_compat_original_get, true)
      return $game_variables.send(:tef_compat_original_get, identifier)
    end
    return $game_variables[identifier]
  rescue
    return nil
  end

  def name_from_trainer_like_object(object)
    return nil if object.nil?
    [:real_name, :name, :trainer_name, :full_name].each do |method_name|
      next if !object.respond_to?(method_name)
      value = object.send(method_name) rescue nil
      return value.to_s.strip if plausible_rival_name?(value)
    end
    [:@real_name, :@name, :@trainer_name].each do |ivar|
      next if !object.instance_variable_defined?(ivar)
      value = object.instance_variable_get(ivar) rescue nil
      return value.to_s.strip if plausible_rival_name?(value)
    end
    return nil
  rescue
    return nil
  end

  def host_rival_name_for_expansion
    candidates = []
    if defined?(VAR_RIVAL_NAME)
      rival_var = VAR_RIVAL_NAME rescue nil
      candidates << host_game_variable_value(rival_var) if rival_var
      candidates << (pbGet(rival_var) rescue nil) if rival_var && defined?(pbGet)
    end
    if defined?(Settings) && Settings.const_defined?(:RIVAL_NAMES)
      Array(Settings::RIVAL_NAMES).each do |entry|
        rival_var = entry.is_a?(Array) ? entry[1] : nil
        candidates << host_game_variable_value(rival_var) if rival_var
      end
    end

    trainer = ($Trainer rescue nil)
    candidates << name_from_trainer_like_object(trainer.rival) if trainer && trainer.respond_to?(:rival)
    candidates << name_from_trainer_like_object(trainer.rival_trainer) if trainer && trainer.respond_to?(:rival_trainer)
    [:@rival_name, :@rivalName].each do |ivar|
      candidates << trainer.instance_variable_get(ivar) if trainer && trainer.instance_variable_defined?(ivar)
    end

    global = ($PokemonGlobal rescue nil)
    [:@rival_name, :@rivalName].each do |ivar|
      candidates << global.instance_variable_get(ivar) if global && global.instance_variable_defined?(ivar)
    end
    battled = global.battledTrainers if global && global.respond_to?(:battledTrainers)
    if battled
      if defined?(BATTLED_TRAINER_RIVAL_KEY)
        rival_record = battled[BATTLED_TRAINER_RIVAL_KEY] rescue nil
        candidates << name_from_trainer_like_object(rival_record)
      end
      if battled.respond_to?(:each_value)
        battled.each_value do |entry|
          type_text = ""
          [:trainer_type, :type, :id].each do |method_name|
            type_text = entry.send(method_name).to_s if entry && entry.respond_to?(method_name)
            break if !type_text.empty?
          end
          candidates << name_from_trainer_like_object(entry) if type_text[/rival/i]
        end
      end
    end

    candidates.each do |candidate|
      text = candidate.to_s.strip
      return text if plausible_rival_name?(text)
    end
    return nil
  rescue => e
    log("[travel] host rival name lookup failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def expansion_rival_name(slot = nil)
    meta = new_project_metadata
    key = slot.nil? ? "rival_name" : "rival_name_#{slot}"
    stored = meta[key].to_s.strip if meta
    name = host_rival_name_for_expansion
    if slot.nil? && plausible_rival_name?(name)
      meta[key] = name if meta
      return name
    end
    return stored if plausible_rival_name?(stored)
    name = slot.nil? ? "Blue" : "Rival #{slot}" if !plausible_rival_name?(name)
    meta[key] = name if meta
    return name
  rescue
    return "Blue"
  end

  def normalize_choice_text(text)
    normalized = text.to_s.downcase
    normalized.gsub!(/\\[a-z]+\[[^\]]*\]/i, "")
    normalized.gsub!(/<[^>]+>/, "")
    normalized.gsub!(/[^\p{Alnum}\s]+/u, " ")
    normalized.gsub!(/\s+/, " ")
    normalized.strip!
    return normalized
  rescue
    return text.to_s.downcase
  end

  def choice_index_matching(commands, pattern)
    Array(commands).each_with_index do |entry, index|
      return index if entry.to_s[pattern]
    end
    return nil
  rescue
    return nil
  end

  def decades_cancel_choice_index(commands)
    list = Array(commands)
    return nil if list.empty?
    return choice_index_matching(list, /\Acancel\z/i) ||
           choice_index_matching(list, /cancel|back|never mind|no/i) ||
           4
  rescue
    return nil
  end

  def decades_battle_mode_map?(map_id = nil)
    return integer(decades_current_local_map_id(map_id), 0) == DECADES_BATTLE_MODE_LOCAL_MAP_ID
  rescue
    return false
  end

  def decades_battle_mode_choice_index(previous_message, commands, map_id = nil)
    return nil if !decades_active_now?(map_id)
    list = Array(commands)
    return nil if list.empty?
    text = normalize_choice_text(previous_message)
    joined = normalize_choice_text(list.join(" "))
    if joined[/begin story mode/] && joined[/begin battle mode/]
      record_release_shim_hit("decades_battle_mode", "startup", "forced_story_mode_npc") if respond_to?(:record_release_shim_hit)
      log("[decades] routed Battle Mode prompt to Story Mode") if respond_to?(:log)
      return choice_index_matching(list, /begin story mode/i) || choice_index_matching(list, /story mode/i) || 0
    end
    battle_prompt = text[/battle mode|level format|cup|challenge battle|deluxe battle/] ||
                    joined[/smogon cup|vgc cup|nfe cup|starter cup|level format|begin battle mode|battle mode|cup.*lvl/] ||
                    (decades_battle_mode_map?(map_id) && joined[/cancel/])
    return nil if !battle_prompt && !decades_battle_mode_map?(map_id)
    choice = decades_cancel_choice_index(list)
    if !choice.nil?
      record_release_shim_hit("decades_battle_mode", "trainer_battle", "cancelled_unsupported_menu") if respond_to?(:record_release_shim_hit)
      log("[decades] cancelled unsupported Battle Mode choice #{list.inspect}") if respond_to?(:log)
    end
    return choice
  rescue => e
    log("[decades] battle mode auto choice failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def decades_title_menu_choice_index(previous_message, commands, map_id = nil)
    return nil if !decades_active_now?(map_id)
    list = Array(commands)
    return nil if list.empty?
    text = normalize_choice_text(previous_message)
    joined = normalize_choice_text(list.join(" "))
    title_prompt = text[/\btitle\b|\btitles\b|honorific|epithet|moniker|memento|mark\b|ribbon/] ||
                   joined[/\btitle\b|\btitles\b|honorific|epithet|moniker|memento|mark\b|ribbon/]
    return nil if !title_prompt
    choice = decades_cancel_choice_index(list)
    if !choice.nil?
      record_release_shim_hit("decades_title_menu", "menu_settings", "cancelled_unsupported_menu") if respond_to?(:record_release_shim_hit)
      log("[decades] cancelled unsupported title menu #{list.inspect}") if respond_to?(:log)
    end
    return choice
  rescue => e
    log("[decades] title menu auto choice failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def decades_startup_map?(map_id = nil)
    map = integer(map_id, 0)
    map = $game_map.map_id if map <= 0 && defined?($game_map) && $game_map
    expansion = active_project_expansion_id(decades_expansion_ids, map)
    return false if expansion.nil?
    local_map = local_map_id_for(expansion, map) rescue map
    return [DECADES_INTRO_LOCAL_MAP_ID, 32].include?(integer(local_map, 0))
  rescue
    return false
  end

  def decades_startup_auto_choice_index(previous_message, commands, map_id = nil, _event_id = nil)
    list = Array(commands)
    return nil if list.empty?
    text = normalize_choice_text(previous_message)
    joined = normalize_choice_text(list.join(" "))
    battle_choice = decades_battle_mode_choice_index(previous_message, list, map_id)
    return battle_choice if !battle_choice.nil?
    title_choice = decades_title_menu_choice_index(previous_message, list, map_id)
    return title_choice if !title_choice.nil?
    return nil if !decades_startup_map?(map_id)
    if text[/game mode/] && joined[/story mode/] && joined[/battle mode/]
      record_release_shim_hit("decades_battle_mode", "startup", "forced_story_mode") if respond_to?(:record_release_shim_hit)
      log("[decades] forced Story Mode from intro game-mode prompt") if respond_to?(:log)
      return choice_index_matching(list, /story mode/i) || 0
    end
    if joined[/begin story mode/] && joined[/begin battle mode/]
      record_release_shim_hit("decades_battle_mode", "startup", "forced_story_mode_npc") if respond_to?(:record_release_shim_hit)
      log("[decades] routed startup NPC to Story Mode instead of unsupported Battle Mode") if respond_to?(:log)
      return choice_index_matching(list, /begin story mode/i) || choice_index_matching(list, /story mode/i) || 0
    end
    if text[/emulator speed up|delta speed up/]
      decades_clear_speedup_punishment!(:auto_choice) if respond_to?(:decades_clear_speedup_punishment!)
      return choice_index_matching(list, /i decide/i) || 0
    end
    if text[/spamming speed up|speed up.*fun/]
      decades_clear_speedup_punishment!(:auto_choice) if respond_to?(:decades_clear_speedup_punishment!)
      return choice_index_matching(list, /not all the time/i) || [list.length - 1, 0].max
    end
    if (text[/starter/] && joined[/starter/]) ||
       joined[/random starters.*mono|all starters.*vgc starters.*random starters/]
      record_release_shim_hit("decades_starter_setup", "startup", "random_single_story") if respond_to?(:record_release_shim_hit)
      return choice_index_matching(list, /random starters/i) ||
             choice_index_matching(list, /vgc starters/i) ||
             choice_index_matching(list, /all starters/i) ||
             0
    end
    if text[/how many.*starter/] || joined[/singles.*doubles.*triples.*full team/]
      record_release_shim_hit("decades_starter_count", "startup", "single") if respond_to?(:record_release_shim_hit)
      return choice_index_matching(list, /(?:\A1\b|singles)/i) || 0
    end
    if text[/type.*specialize|specialize.*type/] ||
       joined[/mono bug|mono dark|mono dragon|mono electric|bug.*dark.*dragon.*electric|fairy.*fighting.*fire.*flying|ghost.*grass.*ground.*ice|normal.*poison.*psychic.*rock|steel.*water/]
      record_release_shim_hit("decades_monotype_setup", "startup", "first_type") if respond_to?(:record_release_shim_hit)
      return 0
    end
    if text[/pss|storage.*clear|clear.*storage|cleared/] && joined[/\byes\b/] && joined[/\bno\b/]
      record_release_shim_hit("decades_storage_cleanup", "startup", "preserve_host_storage") if respond_to?(:record_release_shim_hit)
      return choice_index_matching(list, /\Ano\b/i) || 1
    end
    if text[/where.*beatha region|where.*quoak region|where.*region/] ||
       joined[/mantic city|martic city|boulevard city|penumbra city|cherryhill city|shimmer coast|obsidian peak|apterygota city|bulwark city|virga city|lucid city|circuit city|noxious city|sylph city|revenant city|draco|iron city|crystal city|stratos city/]
      record_release_shim_hit("decades_region_start", "startup", "first_route") if respond_to?(:record_release_shim_hit)
      return 0
    end
    return nil
  rescue => e
    log("[decades] startup auto choice failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def new_project_auto_choice_index(previous_message, commands, map_id = nil, _event_id = nil)
    return nil if !new_project_identity_active_now?(map_id)
    list = Array(commands)
    return nil if list.empty?
    text = normalize_choice_text(previous_message)
    joined = normalize_choice_text(list.join(" "))
    if hollow_woods_active_now?(map_id) &&
       text[/difficulty|game mode|settings/] &&
       joined[/\byes\b/] &&
       joined[/\bno\b/]
      hollow_woods_apply_game_mode_defaults!(:intro_prompt)
      return choice_index_matching(list, /\Ano\z/i) || 1
    end
    decades_choice = decades_startup_auto_choice_index(previous_message, list, map_id, _event_id)
    return decades_choice if !decades_choice.nil?
    if text[/difficulty|dificultad/] || joined[/standard.*adept.*unfair|normal.*hard|easy.*normal/]
      return choice_index_matching(list, /standard|normal/i) || 0
    end
    if text[/randomizer|randomize|aleatori|inverse|special mode|nuzlocke|bosses.*canon|canon teams/] ||
       joined[/randomizer|randomize|inverse|canon/]
      return choice_index_matching(list, /\Ano\z/i) || choice_index_matching(list, /canon/i) || 0
    end
    expansion = nil
    if integer(map_id, 0) > 0 && respond_to?(:current_map_expansion_id)
      map_expansion = current_map_expansion_id(map_id)
      expansion = map_expansion.to_s if expansion_id_in_list?(map_expansion, new_project_expansion_ids)
    end
    expansion ||= active_project_expansion_id(new_project_expansion_ids, map_id)
    local_map = expansion ? (local_map_id_for(expansion, map_id) rescue integer(map_id, 0)) : integer(map_id, 0)
    intro_map = [1, 156].include?(integer(local_map, 0))
    if text[/boy|girl|gender|male|female|chico|chica|hombre|mujer/] ||
       joined[/male.*female/] ||
       (intro_map && joined[/left.*right|izquierda.*derecha/])
      return host_gender_choice_index(list)
    end
    if text[/appearance|look|aspecto/] && list.length > 0
      return host_gender_choice_index(list) || 0
    end
    if text[/are you sure|are you certain|is that correct|is that your name|so you re|ese es tu nombre|seguro|correcto|cierto/]
      return choice_index_matching(list, /^yes$/i) || choice_index_matching(list, /^s/i) || 0
    end
    if text[/do you need help|help choices|need help|info needed/]
      return choice_index_matching(list, /no info/i)
    end
    return nil
  rescue => e
    log("[travel] auto choice failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def empyrean_apply_gender_selection!
    selection = host_player_female? ? 1 : 0
    $game_variables[1] = selection if defined?($game_variables) && $game_variables
    $game_switches[63] = (selection == 0) if defined?($game_switches) && $game_switches
    meta = new_project_metadata || empyrean_metadata
    if meta
      meta["intro_gender_selection"] = selection
      meta["intro_gender"] = host_player_gender_symbol.to_s
      meta["intro_name"] = host_player_name_for_expansion
    end
    return selection
  rescue
    return 0
  end

  def realidea_apply_gender_selection!
    male_player = host_player_male?
    selection = male_player ? 0 : 1
    rival_name = male_player ? "Fatima" : "Dante"
    $game_switches[70] = male_player if defined?($game_switches) && $game_switches
    $game_variables[89] = rival_name if defined?($game_variables) && $game_variables
    meta = new_project_metadata(REALIDEA_EXPANSION_ID) || new_project_metadata
    if meta
      meta["intro_gender_selection"] = selection
      meta["intro_gender"] = host_player_gender_symbol.to_s
      meta["intro_name"] = host_player_name_for_expansion
      meta["realidea_player_male_switch_70"] = male_player
      meta["rival_name"] = rival_name
    end
    return selection
  rescue
    return host_player_female? ? 1 : 0
  end

  def apply_new_project_gender_selection!(map_id = nil)
    return realidea_apply_gender_selection! if realidea_active_now?(map_id)
    return empyrean_apply_gender_selection!
  rescue
    return host_player_female? ? 1 : 0
  end

  def empyrean_apply_skin_selection!(selection = 0)
    value = integer(selection, 0)
    value = 0 if value < 0
    $game_variables[1] = value if defined?($game_variables) && $game_variables
    meta = new_project_metadata || empyrean_metadata
    meta["intro_skin_selection"] = value if meta
    return value
  rescue
    return 0
  end

  def new_project_apply_skin_selection!(selection = 0, map_id = nil)
    value = integer(selection, 0)
    value = 0 if value < 0
    expansion = current_new_project_expansion_id(map_id)
    meta = new_project_metadata(expansion) || new_project_metadata || empyrean_metadata
    meta["intro_skin_selection"] = value if meta
    meta["intro_skin_source"] = expansion.to_s if meta && !expansion.to_s.empty?
    $game_variables[1] = value if defined?($game_variables) && $game_variables
    reset_gadir_deluxe_intro_recovery_counter!(meta) if expansion_id_in_list?(expansion, gadir_deluxe_expansion_ids)
    return value
  rescue
    return 0
  end

  def empyrean_intro_sprites_ready!
    empyrean_log_once(:intro_sprites, "[empyrean] calcIntroSprites shimmed; using host-safe intro selection sprites")
    return true
  rescue
    return true
  end

  def set_expansion_level_cap(level)
    value = integer(level, 0)
    meta = new_project_metadata || empyrean_metadata
    meta["level_cap"] = value if meta
    return value
  rescue
    return level
  end

  def realidea_active_now?(map_id = nil)
    return current_new_project_expansion_id(map_id).to_s == REALIDEA_EXPANSION_ID
  rescue
    return false
  end

  def realidea_picture_frame
    frame = integer(($game_variables[97] rescue 0), 0)
    frame = 0 if frame < 0
    return frame
  rescue
    return 0
  end

  def realidea_show_picture(number, path, opacity = 255, blend_type = 0, x = 0, y = 0)
    return true if !realidea_active_now?
    return false if !defined?($game_screen) || !$game_screen || !$game_screen.respond_to?(:pictures)
    picture_id = integer(number, 0)
    return false if picture_id <= 0
    picture = $game_screen.pictures[picture_id] rescue nil
    return false if !picture || !picture.respond_to?(:show)
    picture.show(path.to_s, 0, x, y, 100, 100, opacity, blend_type)
    return true
  rescue => e
    log("[realidea] picture helper failed for #{path}: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def realidea_gif(number, folder, delay = "0.13s", opacity = 255, blend_type = 0, x = 0, y = 0)
    frame = realidea_picture_frame
    folder_name = folder.to_s.gsub("\\", "/").sub(/\A\/+/, "")
    return realidea_show_picture(number, "/#{folder_name}/frame_#{frame}_delay-#{delay}", opacity, blend_type, x, y)
  end

  def realidea_haya_picture(kind)
    frame = realidea_picture_frame
    name = kind.to_s == "parpadeando" ? "Haya Parpadeando" : "Haya Hablando"
    return realidea_show_picture(2, "/Hayaya/#{name}#{frame}", 255, 0)
  end

  def new_project_dependent_events
    return nil if !defined?($PokemonTemp) || !$PokemonTemp || !$PokemonTemp.respond_to?(:dependentEvents)
    return $PokemonTemp.dependentEvents
  rescue
    return nil
  end

  def new_project_primary_dependent_event(event_name = nil)
    dependent_events = new_project_dependent_events
    return nil if dependent_events.nil?
    if !event_name.nil? && !event_name.to_s.empty?
      named_event = dependent_events.getEventByName(event_name.to_s) rescue nil
      return named_event if named_event
    end
    if dependent_events.respond_to?(:realEvents)
      events = dependent_events.realEvents rescue nil
      return events[0] if events.is_a?(Array) && events[0]
    end
    if dependent_events.instance_variable_defined?(:@realEvents)
      events = dependent_events.instance_variable_get(:@realEvents)
      return events[0] if events.is_a?(Array) && events[0]
    end
    return nil
  rescue => e
    log("[travel] dependent lookup failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def new_project_source_event_for_dependency(event_id = nil, event_name = "Dependent")
    if event_id && integer(event_id, 0) > 0 && defined?($game_map) && $game_map && $game_map.respond_to?(:events)
      event = $game_map.events[integer(event_id, 0)] rescue nil
      return event if event
    end
    if !event_name.to_s.empty? && defined?($game_map) && $game_map && $game_map.respond_to?(:events)
      target_name = event_name.to_s.downcase
      event = ($game_map.events.values.compact.find { |candidate| candidate.name.to_s.downcase == target_name } rescue nil)
      return event if event
    end
    return nil
  rescue
    return nil
  end

  def new_project_follow_event(event_id, event_name = "Dependent", follows_player = true)
    return false if !new_project_active_now?
    dependent_events = new_project_dependent_events
    source_event = new_project_source_event_for_dependency(event_id, event_name)
    if dependent_events && source_event
      begin
        existing = new_project_primary_dependent_event(event_name)
        if existing.nil? && dependent_events.respond_to?(:addEvent)
          dependent_events.addEvent(source_event, event_name.to_s, nil)
          existing = new_project_primary_dependent_event(event_name)
        end
        existing ||= source_event
        existing.follows_player = follows_player if existing.respond_to?(:follows_player=)
        existing.through = false if existing.respond_to?(:through=)
        existing.transparent = false if existing.respond_to?(:transparent=)
        source_event.erase if source_event.respond_to?(:erase) && existing != source_event
        $game_map.need_refresh = true if defined?($game_map) && $game_map
        log("[travel] bridged follower #{event_name.inspect} from event #{event_id.inspect}") if respond_to?(:log)
        return true
      rescue => e
        log("[travel] follower bridge failed: #{e.class}: #{e.message}") if respond_to?(:log)
      end
    end
    return false
  end

  def new_project_following_move_route(commands, wait_complete = false)
    return nil if !new_project_active_now?
    dependent_events = new_project_dependent_events
    if dependent_events && dependent_events.respond_to?(:SetMoveRoute)
      return dependent_events.SetMoveRoute(commands, wait_complete) rescue nil
    end
    event = new_project_primary_dependent_event("Dependent") || new_project_primary_dependent_event
    return nil if !event
    route = pbMoveRoute(event, Array(commands).compact, wait_complete) if defined?(pbMoveRoute)
    return route
  rescue => e
    log("[travel] FollowingMoveRoute bridge failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  SOULSTONES_STARTER_SPECIES = [
    :BULBASAUR, :CHARMANDER, :SQUIRTLE,
    :CHIKORITA, :CYNDAQUIL, :TOTODILE,
    :TREECKO, :TORCHIC, :MUDKIP,
    :TURTWIG, :CHIMCHAR, :PIPLUP,
    :SNIVY, :TEPIG, :OSHAWOTT,
    :CHESPIN, :FENNEKIN, :FROAKIE,
    :ROWLET, :LITTEN, :POPPLIO,
    :GROOKEY, :SCORBUNNY, :SOBBLE,
    :SPRIGATITO, :FUECOCO, :QUAXLY
  ].freeze unless const_defined?(:SOULSTONES_STARTER_SPECIES)

  SOULSTONES2_MINING_TOTAL_WEIGHT = 1_000 unless const_defined?(:SOULSTONES2_MINING_TOTAL_WEIGHT)

  def soulstones_party
    trainer = $Trainer rescue nil
    return [] if !trainer
    return trainer.pokemonParty if trainer.respond_to?(:pokemonParty)
    return trainer.pokemon_party if trainer.respond_to?(:pokemon_party)
    return trainer.party if trainer.respond_to?(:party)
    return []
  rescue
    return []
  end

  def soulstones_species_symbol(species)
    return nil if species.nil?
    if defined?(GameData::Species) && GameData::Species.respond_to?(:try_get)
      data = GameData::Species.try_get(species) rescue nil
      return data.species if data && data.respond_to?(:species)
    end
    return species.to_sym if species.respond_to?(:to_sym)
    return species
  rescue
    return species
  end

  def soulstones_has_starter?
    starters = SOULSTONES_STARTER_SPECIES
    soulstones_party.each do |pokemon|
      next if !pokemon || (pokemon.respond_to?(:egg?) && pokemon.egg?)
      species = pokemon.respond_to?(:species) ? pokemon.species : pokemon
      return true if starters.include?(soulstones_species_symbol(species))
    end
    return false
  rescue => e
    log("[soulstones] starter check failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def soulstones2_ensure_mining_storage!
    return nil if !$Trainer
    if $Trainer.respond_to?(:miningRocks)
      rocks = $Trainer.miningRocks rescue nil
      $Trainer.miningRocks = [] if !rocks.is_a?(Array) && $Trainer.respond_to?(:miningRocks=)
      return $Trainer.miningRocks rescue nil
    end
    $Trainer.instance_variable_set(:@miningRocks, []) if $Trainer.respond_to?(:instance_variable_set)
    return $Trainer.instance_variable_get(:@miningRocks) if $Trainer.respond_to?(:instance_variable_get)
    return nil
  rescue
    return nil
  end

  def soulstones2_generate_mining_stone!
    rocks = soulstones2_ensure_mining_storage!
    return false if !rocks.is_a?(Array)
    numitems = 3 + rand(3)
    rolls = []
    numitems.times { rolls << rand(SOULSTONES2_MINING_TOTAL_WEIGHT) }
    rocks << [numitems, rolls]
    return true
  rescue => e
    log("[soulstones2] mining stone generation failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def soulstones2_prerandomize_mining_stones!(count = 50)
    rocks = soulstones2_ensure_mining_storage!
    return false if !rocks.is_a?(Array)
    rocks.clear
    [integer(count, 50), 1].max.times { soulstones2_generate_mining_stone! }
    return true
  rescue => e
    log("[soulstones2] mining prerandomizer failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end
end

if defined?(PokemonSystem)
  class PokemonSystem
    def current_menu_theme
      value = @tef_new_project_current_menu_theme
      if defined?(TravelExpansionFramework) &&
         TravelExpansionFramework.respond_to?(:new_project_metadata) &&
         TravelExpansionFramework.respond_to?(:new_project_active_now?) &&
         TravelExpansionFramework.new_project_active_now?
        meta = TravelExpansionFramework.new_project_metadata
        value = meta["current_menu_theme"] if meta && meta.has_key?("current_menu_theme")
      end
      return TravelExpansionFramework.integer(value, 0) if defined?(TravelExpansionFramework) &&
                                                          TravelExpansionFramework.respond_to?(:integer)
      return value.to_i
    rescue
      return 0
    end unless method_defined?(:current_menu_theme)

    def current_menu_theme=(value)
      normalized = if defined?(TravelExpansionFramework) && TravelExpansionFramework.respond_to?(:integer)
                     TravelExpansionFramework.integer(value, 0)
                   else
                     value.to_i
                   end
      @tef_new_project_current_menu_theme = normalized
      if defined?(TravelExpansionFramework) &&
         TravelExpansionFramework.respond_to?(:new_project_metadata) &&
         TravelExpansionFramework.respond_to?(:new_project_active_now?) &&
         TravelExpansionFramework.new_project_active_now?
        expansion = TravelExpansionFramework.current_new_project_expansion_id if TravelExpansionFramework.respond_to?(:current_new_project_expansion_id)
        meta = TravelExpansionFramework.new_project_metadata(expansion)
        meta["current_menu_theme"] = normalized if meta
        TravelExpansionFramework.log("[#{expansion || "new_project"}] stored imported menu theme #{normalized}") if TravelExpansionFramework.respond_to?(:log)
      end
      return normalized
    rescue
      @tef_new_project_current_menu_theme = 0
      return 0
    end unless method_defined?(:current_menu_theme=)

    def difficulty
      value = @tef_new_project_difficulty
      if defined?(TravelExpansionFramework) &&
         TravelExpansionFramework.respond_to?(:new_project_metadata) &&
         TravelExpansionFramework.respond_to?(:new_project_active_now?) &&
         TravelExpansionFramework.new_project_active_now?
        meta = TravelExpansionFramework.new_project_metadata
        if meta
          value = meta["difficulty"] if meta.has_key?("difficulty")
          value = meta["difficulty_mode"] if value.nil? && meta.has_key?("difficulty_mode")
        end
      end
      return TravelExpansionFramework.integer(value, 0) if defined?(TravelExpansionFramework) &&
                                                          TravelExpansionFramework.respond_to?(:integer)
      return value.to_i
    rescue
      return 0
    end unless method_defined?(:difficulty)

    def difficulty=(value)
      normalized = if defined?(TravelExpansionFramework) && TravelExpansionFramework.respond_to?(:integer)
                     TravelExpansionFramework.integer(value, 0)
      else
        value.to_i
      end
      @tef_new_project_difficulty = normalized
      if defined?($game_variables) && $game_variables
        $game_variables[242] = normalized
        current_min = ($game_variables[243] rescue nil)
        $game_variables[243] = normalized if current_min.nil? || normalized < current_min.to_i
      end
      if defined?(TravelExpansionFramework) &&
         TravelExpansionFramework.respond_to?(:new_project_metadata) &&
         TravelExpansionFramework.respond_to?(:new_project_active_now?) &&
         TravelExpansionFramework.new_project_active_now?
        expansion = TravelExpansionFramework.current_new_project_expansion_id if TravelExpansionFramework.respond_to?(:current_new_project_expansion_id)
        meta = TravelExpansionFramework.new_project_metadata(expansion)
        if meta
          meta["difficulty"] = normalized
          meta["difficulty_mode"] = normalized
        end
        if TravelExpansionFramework.respond_to?(:log)
          TravelExpansionFramework.log("[#{expansion || "new_project"}] stored imported difficulty #{normalized}")
        end
      end
      if defined?($Trainer) && $Trainer
        $Trainer.selected_difficulty = normalized if $Trainer.respond_to?(:selected_difficulty=)
        if $Trainer.respond_to?(:lowest_difficulty=)
          lowest = ($Trainer.lowest_difficulty rescue nil)
          $Trainer.lowest_difficulty = normalized if lowest.nil? || normalized < lowest.to_i
        end
        $Trainer.difficulty_mode = normalized if $Trainer.respond_to?(:difficulty_mode=)
      end
      return normalized
    rescue
      @tef_new_project_difficulty = 0
      return 0
    end unless method_defined?(:difficulty=)
  end
end

if TravelExpansionFramework.respond_to?(:resolve_runtime_path)
  class << TravelExpansionFramework
    alias tef_new_projects_original_resolve_runtime_path resolve_runtime_path unless method_defined?(:tef_new_projects_original_resolve_runtime_path)

    def resolve_runtime_path(logical_path, extensions = [])
      override = nil
      if !@tef_opalo_picture_override_resolving && respond_to?(:opalo_picture_override_path)
        begin
          @tef_opalo_picture_override_resolving = true
          override = opalo_picture_override_path(logical_path, extensions)
        rescue Exception => e
          log("[opalo] skipped unsafe picture override for #{logical_path.inspect}: #{e.class}: #{e.message}") if respond_to?(:log)
          override = nil
        ensure
          @tef_opalo_picture_override_resolving = false
        end
      end
      if override
        log_runtime_asset_once(TravelExpansionFramework::OPALO_EXPANSION_ID, :compat_picture, logical_path, override) if respond_to?(:log_runtime_asset_once)
        return override
      end
      return tef_new_projects_original_resolve_runtime_path(logical_path, extensions)
    end
  end
end

if defined?(Scene_Map)
  class Scene_Map
    attr_accessor :eye_of_truth_time unless method_defined?(:eye_of_truth_time)
    alias tef_new_projects_original_update update unless method_defined?(:tef_new_projects_original_update)

    def update(*args)
      result = tef_new_projects_original_update(*args)
      TravelExpansionFramework.opalo_repair_starter_room_state!(($game_map.map_id rescue nil), "scene_update") if defined?(TravelExpansionFramework) &&
                                                                                                                   TravelExpansionFramework.respond_to?(:opalo_repair_starter_room_state!)
      if defined?(TravelExpansionFramework) &&
         TravelExpansionFramework.opalo_active_now? &&
         respond_to?(:eye_of_truth_time) &&
         @eye_of_truth_time.to_i > 0
        @eye_of_truth_time = @eye_of_truth_time.to_i - 1
      end
      TravelExpansionFramework.gadir_deluxe_intro_recovery_update!(self) if defined?(TravelExpansionFramework) &&
                                                                            TravelExpansionFramework.respond_to?(:gadir_deluxe_intro_recovery_update!)
      TravelExpansionFramework.gadir_deluxe_home_recovery_update!(self) if defined?(TravelExpansionFramework) &&
                                                                           TravelExpansionFramework.respond_to?(:gadir_deluxe_home_recovery_update!)
      TravelExpansionFramework.infinity_runtime_watchdog_update!(self) if defined?(TravelExpansionFramework) &&
                                                                          TravelExpansionFramework.respond_to?(:infinity_runtime_watchdog_update!)
      TravelExpansionFramework.void_scene_runtime_repair_update!(self) if defined?(TravelExpansionFramework) &&
                                                                          TravelExpansionFramework.respond_to?(:void_scene_runtime_repair_update!)
      return result
    end
  end
end

if defined?(Game_Event)
  class Game_Event
    alias tef_new_projects_original_refresh refresh unless method_defined?(:tef_new_projects_original_refresh)
    alias tef_new_projects_original_update update unless method_defined?(:tef_new_projects_original_update)

    def refresh
      TravelExpansionFramework.opalo_repair_starter_room_state!(@map_id, "event_refresh") if defined?(TravelExpansionFramework) &&
                                                                                            TravelExpansionFramework.respond_to?(:opalo_repair_starter_room_state!)
      result = tef_new_projects_original_refresh
      TravelExpansionFramework.apply_opalo_lens_event_state!(self, true) if defined?(TravelExpansionFramework)
      TravelExpansionFramework.void_repair_runtime_event!(self, @map_id, "event_refresh") if defined?(TravelExpansionFramework) &&
                                                                                             TravelExpansionFramework.respond_to?(:void_repair_runtime_event!)
      return result
    end

    def update
      result = tef_new_projects_original_update
      TravelExpansionFramework.apply_opalo_lens_event_state!(self, false) if defined?(TravelExpansionFramework)
      TravelExpansionFramework.void_repair_runtime_event!(self, @map_id, "event_update") if defined?(TravelExpansionFramework) &&
                                                                                            TravelExpansionFramework.respond_to?(:void_repair_runtime_event!)
      return result
    end
  end
end

def pbLensOfTruth
  if defined?(TravelExpansionFramework) && TravelExpansionFramework.opalo_active_now?
    if defined?($scene) && $scene && $scene.respond_to?(:eye_of_truth_time) && $scene.eye_of_truth_time.to_i > 0
      pbMessage(_INTL("The Lens is already being used.")) if defined?(pbMessage)
      return false
    end
    TravelExpansionFramework.activate_opalo_lens_of_truth!
    return true
  end
  return true
end unless defined?(pbLensOfTruth)

GOLD_ID = 0 unless defined?(GOLD_ID)
DIFFICULTY_EASY = -1 unless defined?(DIFFICULTY_EASY)
DIFFICULTY_NORMAL = 0 unless defined?(DIFFICULTY_NORMAL)
DIFFICULTY_EXTREME = 1 unless defined?(DIFFICULTY_EXTREME)
AE_PLAYER_CHARACTER = "player_character" unless defined?(AE_PLAYER_CHARACTER)
AE_GYM = "gym" unless defined?(AE_GYM)
AE_KATA = "kata" unless defined?(AE_KATA)
AE_QUEST = "quest" unless defined?(AE_QUEST)
AE_STARTER = "starter" unless defined?(AE_STARTER)

def calcIntroSprites(*_args)
  return TravelExpansionFramework.empyrean_intro_sprites_ready! if TravelExpansionFramework.new_project_identity_active_now?
  return true
end unless defined?(calcIntroSprites)

def calcPlayerSprites(*_args)
  return true if TravelExpansionFramework.new_project_identity_active_now?
  return true
end unless defined?(calcPlayerSprites)

def giveDefaultClothing(*_args)
  return true if TravelExpansionFramework.new_project_identity_active_now?
  return true
end unless defined?(giveDefaultClothing)

def trackAnalyticsEvent(*_args)
  return nil
end unless defined?(trackAnalyticsEvent)

def setDifficultyVar(value)
  TravelExpansionFramework.ensure_player_global!
  $game_variables[242] = value if defined?($game_variables) && $game_variables
  meta = TravelExpansionFramework.new_project_metadata || (TravelExpansionFramework.empyrean_metadata if TravelExpansionFramework.empyrean_active_now?)
  meta["difficulty"] = value if meta
  return value
end unless defined?(setDifficultyVar)

def setDifficulty(value)
  mapped = case value
           when 0 then DIFFICULTY_EASY
           when 1 then DIFFICULTY_NORMAL
           when 2 then DIFFICULTY_EXTREME
           else value
           end
  return setDifficultyVar(mapped)
end unless defined?(setDifficulty)

def getDifficulty
  return $game_variables[242] if defined?($game_variables) && $game_variables
  return DIFFICULTY_NORMAL
end unless defined?(getDifficulty)

def getMinDifficulty
  return $game_variables[243] if defined?($game_variables) && $game_variables
  return DIFFICULTY_NORMAL
end unless defined?(getMinDifficulty)

def isDifficultyEasy?
  return getDifficulty == DIFFICULTY_EASY
end unless defined?(isDifficultyEasy?)

def isDifficultyNormal?
  return getDifficulty == DIFFICULTY_NORMAL
end unless defined?(isDifficultyNormal?)

def isDifficultyExtreme?
  return getDifficulty == DIFFICULTY_EXTREME
end unless defined?(isDifficultyExtreme?)

def setSkintone(value)
  return TravelExpansionFramework.new_project_apply_skin_selection!(value) if TravelExpansionFramework.new_project_identity_active_now?
  return value
end unless defined?(setSkintone)

def skintone
  meta = TravelExpansionFramework.new_project_metadata
  return meta["intro_skin_selection"] if meta && meta.has_key?("intro_skin_selection")
  return 0
end unless defined?(skintone)

def isPlayerMale?
  return TravelExpansionFramework.host_player_male? if TravelExpansionFramework.new_project_identity_active_now?
  trainer = $Trainer rescue nil
  return true if !trainer
  return trainer.male? if trainer.respond_to?(:male?)
  return false if trainer.respond_to?(:female?) && trainer.female?
  return true
end unless defined?(isPlayerMale?)

def pbUpdateMax(level)
  return TravelExpansionFramework.set_expansion_level_cap(level)
end unless defined?(pbUpdateMax)

def gif(numero, carpeta)
  return TravelExpansionFramework.realidea_gif(numero, carpeta, "0.13s", 255, 0, 0, 0)
end unless defined?(gif)

def talismannormal(numero, carpeta)
  return TravelExpansionFramework.realidea_gif(numero, carpeta, "0.2s", 255, 0, -10, 0)
end unless defined?(talismannormal)

def talismanotro(numero, carpeta)
  return TravelExpansionFramework.realidea_gif(numero, carpeta, "0.08s", 255, 0, -10, 0)
end unless defined?(talismanotro)

def gifdisco(numero, carpeta)
  return TravelExpansionFramework.realidea_gif(numero, carpeta, "0.04s", 70, 1, 0, 0)
end unless defined?(gifdisco)

def gifhayahablando
  return TravelExpansionFramework.realidea_haya_picture("hablando")
end unless defined?(gifhayahablando)

def gifhayaparpadeando
  return TravelExpansionFramework.realidea_haya_picture("parpadeando")
end unless defined?(gifhayaparpadeando)

if defined?(Player)
  class Player
    def difficulty_mode
      if defined?(TravelExpansionFramework) && TravelExpansionFramework.new_project_identity_active_now?
        meta = TravelExpansionFramework.new_project_metadata
        return meta["difficulty_mode"] if meta && meta.has_key?("difficulty_mode")
      end
      return @difficulty_mode if instance_variable_defined?(:@difficulty_mode)
      return selected_difficulty if respond_to?(:selected_difficulty) && !selected_difficulty.nil?
      return 0
    rescue
      return 0
    end unless method_defined?(:difficulty_mode)

    def difficulty_mode=(value)
      if defined?(TravelExpansionFramework) && TravelExpansionFramework.new_project_identity_active_now?
        meta = TravelExpansionFramework.new_project_metadata
        meta["difficulty_mode"] = value if meta
      end
      @difficulty_mode = value
      self.selected_difficulty = value if respond_to?(:selected_difficulty=)
      return value
    rescue
      return value
    end unless method_defined?(:difficulty_mode=)

    def pokemon_count
      party_value = party if respond_to?(:party)
      return Array(party_value).length
    rescue
      return 0
    end unless method_defined?(:pokemon_count)

    if method_defined?(:outfit=)
      alias tef_infinity_original_outfit_set outfit= unless method_defined?(:tef_infinity_original_outfit_set)

      def outfit=(value)
        if defined?(TravelExpansionFramework) &&
           TravelExpansionFramework.respond_to?(:infinity_suppress_player_visual_assignment?) &&
           TravelExpansionFramework.infinity_suppress_player_visual_assignment?(:outfit, value)
          TravelExpansionFramework.infinity_note_suppressed_player_visual_assignment!(:outfit, value) if TravelExpansionFramework.respond_to?(:infinity_note_suppressed_player_visual_assignment!)
          return @outfit
        end
        return tef_infinity_original_outfit_set(value) if respond_to?(:tef_infinity_original_outfit_set, true)
        @outfit = value
      rescue
        @outfit = value
      end
    end
  end
end

module TravelExpansionFramework
  module_function

  def resolve_character_popup_event(event_ref = nil, fallback_event_id = nil)
    return $game_player if event_ref.to_s == "Player" && defined?($game_player)
    return nil if !defined?($game_map) || !$game_map || !$game_map.respond_to?(:events)
    ref = event_ref
    ref = fallback_event_id if ref.nil? || ref.to_s.empty?
    if ref.is_a?(Integer) || ref.to_s[/\AEV0*(\d+)\z/i]
      event_id = ref.is_a?(Integer) ? ref : $1.to_i
      event = $game_map.events[event_id] rescue nil
      return event if event
    end
    name = ref.to_s
    $game_map.events.values.each do |event|
      return event if event.respond_to?(:name) && event.name.to_s == name
    end
    return $game_player if defined?($game_player) && $game_player
    return nil
  rescue
    return nil
  end

  def show_character_popup(label, event_ref = nil, fallback_event_id = nil)
    event = resolve_character_popup_event(event_ref, fallback_event_id)
    return true if !event
    animation_id = if defined?(Settings) && Settings.const_defined?(:EXCLAMATION_ANIMATION_ID)
      Settings::EXCLAMATION_ANIMATION_ID
    else
      3
    end
    if defined?(pbExclaim) && [:P_EXCLAMATION, "P_EXCLAMATION"].include?(label)
      pbExclaim(event, animation_id) rescue nil
    elsif defined?($scene) && $scene && $scene.respond_to?(:spriteset) &&
          $scene.spriteset && $scene.spriteset.respond_to?(:addUserAnimation)
      x = event.respond_to?(:x) ? event.x : 0
      y = event.respond_to?(:y) ? event.y : 0
      $scene.spriteset.addUserAnimation(animation_id, x, y, true, 1)
    end
    return true
  rescue => e
    log("[empyrean] characterPopup #{label.inspect}/#{event_ref.inspect} skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def play_expansion_cry(species_ref, volume = 50, pitch = 100)
    expansion = current_new_project_expansion_id if respond_to?(:current_new_project_expansion_id)
    expansion = current_runtime_expansion_id if expansion.to_s.empty? && respond_to?(:current_runtime_expansion_id)
    species = resolve_expansion_species(expansion, species_ref) if respond_to?(:resolve_expansion_species)
    species ||= species_ref
    if defined?(getID) && defined?(PBSpecies)
      species = getID(PBSpecies, species) rescue species
    elsif defined?(GameData) && GameData.const_defined?(:Species)
      data = GameData::Species.try_get(species) rescue nil
      species = data.species if data && data.respond_to?(:species)
    end
    return pbPlayCry(species, volume, pitch) if defined?(pbPlayCry)
    if defined?(pbCryFile) && defined?(pbSEPlay)
      cry = pbCryFile(species) rescue nil
      pbSEPlay(cry, volume, pitch) if cry
    end
    return true
  rescue => e
    log("[empyrean] playCry #{species_ref.inspect} skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end
end

def activar(event, swtch = "A", value = true)
  map_id = @map_id if instance_variable_defined?(:@map_id)
  map_id = ($game_map.map_id rescue 0) if map_id.nil? || map_id.to_i <= 0
  switch_name = swtch.nil? ? "A" : swtch.to_s
  switch_name = "A" if switch_name.empty?
  $game_self_switches[[map_id, event, switch_name]] = value if defined?($game_self_switches) && $game_self_switches
  $game_map.need_refresh = true if defined?($game_map) && $game_map
  return true
end unless defined?(activar)

def skipToHour(hour)
  meta = TravelExpansionFramework.new_project_metadata
  meta["requested_skip_hour"] = hour if meta
  return true
end unless defined?(skipToHour)

def weather(type = :None, power = 0, duration = 0)
  $game_screen.weather(type, power, duration) if defined?($game_screen) && $game_screen && $game_screen.respond_to?(:weather)
  return true
rescue
  return true
end unless defined?(weather)

def pbPlayCrySpecies(pokemon, form = 0, volume = 90, pitch = nil)
  species = pokemon
  if defined?(GameData) && GameData.const_defined?(:Species)
    data = GameData::Species.try_get(species) rescue nil
    data ||= GameData::Species.try_get(species.to_s.upcase.to_sym) rescue nil
    species = data.species if data && data.respond_to?(:species)
    if GameData::Species.respond_to?(:play_cry_from_species)
      return GameData::Species.play_cry_from_species(species, form, volume, pitch) rescue nil
    end
  end
  return pbPlayCry(species, form, volume, pitch) if defined?(pbPlayCry)
  return playCry(species) if defined?(playCry)
  return nil
end unless defined?(pbPlayCrySpecies)

def playCry(species, volume = 50, pitch = 100)
  return TravelExpansionFramework.play_expansion_cry(species, volume, pitch) if defined?(TravelExpansionFramework) &&
                                                                               TravelExpansionFramework.respond_to?(:play_expansion_cry)
  return true
end unless defined?(playCry)

def characterPopup(label, event_ref = nil)
  return TravelExpansionFramework.show_character_popup(label, event_ref) if defined?(TravelExpansionFramework) &&
                                                                           TravelExpansionFramework.respond_to?(:show_character_popup)
  return true
end unless defined?(characterPopup)

def chrp(label, event_ref = nil)
  return characterPopup(label, event_ref)
end unless defined?(chrp)

def chrp1(event_ref = nil)
  return characterPopup(:P_EXCLAMATION, event_ref)
end unless defined?(chrp1)

def pbShuffleDex(*_args)
  return true
end unless defined?(pbShuffleDex)

def pbShuffleDexTrainers(*_args)
  return true
end unless defined?(pbShuffleDexTrainers)

def pbWatchTV(*args)
  if defined?(TravelExpansionFramework)
    return TravelExpansionFramework.watch_imported_tv!(*args) if TravelExpansionFramework.respond_to?(:imported_tv_event?) &&
                                                                 TravelExpansionFramework.imported_tv_event?
    return TravelExpansionFramework.hollow_woods_watch_tv!(*args) if TravelExpansionFramework.respond_to?(:hollow_woods_active_now?) &&
                                                                     TravelExpansionFramework.hollow_woods_active_now? &&
                                                                     TravelExpansionFramework.respond_to?(:hollow_woods_watch_tv!)
  end
  return true
end unless defined?(pbWatchTV)

alias tef_decades_original_pbHeadbutt pbHeadbutt if defined?(pbHeadbutt) && !defined?(tef_decades_original_pbHeadbutt)
def pbHeadbutt(event = nil, *args)
  if defined?(TravelExpansionFramework) && TravelExpansionFramework.respond_to?(:decades_headbutt!)
    handled = TravelExpansionFramework.decades_headbutt!(event, *args)
    return handled if !handled.nil?
  end
  return tef_decades_original_pbHeadbutt(event, *args) if defined?(tef_decades_original_pbHeadbutt)
  return false
end

def pbCheckRoaming(*args)
  return TravelExpansionFramework.infinity_check_roaming!(nil, *args) if defined?(TravelExpansionFramework) &&
                                                                         TravelExpansionFramework.respond_to?(:infinity_check_roaming!)
  return false
end unless defined?(pbCheckRoaming)

def pbHasStarters?
  return TravelExpansionFramework.soulstones_has_starter? if defined?(TravelExpansionFramework) &&
                                                             TravelExpansionFramework.respond_to?(:soulstones_has_starter?)
  return false
end unless defined?(pbHasStarters?)

def prerandomizeMiningStones
  return TravelExpansionFramework.soulstones2_prerandomize_mining_stones! if defined?(TravelExpansionFramework) &&
                                                                            TravelExpansionFramework.respond_to?(:soulstones2_prerandomize_mining_stones!)
  return false
end unless defined?(prerandomizeMiningStones)

def generateOneStone
  return TravelExpansionFramework.soulstones2_generate_mining_stone! if defined?(TravelExpansionFramework) &&
                                                                       TravelExpansionFramework.respond_to?(:soulstones2_generate_mining_stone!)
  return false
end unless defined?(generateOneStone)

def useAirDragonite
  if !defined?(PokemonRegionMap_Scene) || !defined?(PokemonRegionMapScreen)
    pbMessage(_INTL("Dragonite cannot find a safe route right now.")) if defined?(pbMessage)
    return false
  end
  scene = PokemonRegionMap_Scene.new(-1, false)
  screen = PokemonRegionMapScreen.new(scene)
  $PokemonTemp.flydata = screen.pbStartFlyScreen
  if !$PokemonTemp.flydata
    pbMessage(_INTL("No worries. Feel free to come back anytime.")) if defined?(pbMessage)
    return false
  end
  target = {
    :map_id    => $PokemonTemp.flydata[0],
    :x         => $PokemonTemp.flydata[1],
    :y         => $PokemonTemp.flydata[2],
    :direction => 2
  }
  map_name = TravelExpansionFramework.map_display_name(target[:map_id]) if defined?(TravelExpansionFramework) &&
                                                                           TravelExpansionFramework.respond_to?(:map_display_name)
  map_name ||= ($game_map.name rescue "your destination")
  if defined?(pbHiddenMoveAnimation) && !pbHiddenMoveAnimation(nil)
    pbMessage(_INTL("Alright, buckle up {1}! Dragonite and I are taking you to {2}.", $Trainer.name, map_name)) if defined?(pbMessage)
  end
  $PokemonTemp.flydata = nil
  if defined?(TravelExpansionFramework) && TravelExpansionFramework.respond_to?(:safe_transfer_to_anchor)
    return TravelExpansionFramework.safe_transfer_to_anchor(target, {
      :source    => :soulstones_air_dragonite,
      :immediate => true
    })
  end
  pbFadeOutIn {
    pbCancelVehicles if defined?(pbCancelVehicles)
    pbSEPlay("PRSFX- Gust") if defined?(pbSEPlay)
    $game_temp.player_new_map_id = target[:map_id]
    $game_temp.player_new_x = target[:x]
    $game_temp.player_new_y = target[:y]
    $game_temp.player_new_direction = 2
    $scene.transfer_player if $scene && $scene.respond_to?(:transfer_player)
    $game_map.autoplay if $game_map && $game_map.respond_to?(:autoplay)
    $game_map.refresh if $game_map && $game_map.respond_to?(:refresh)
  }
  pbEraseEscapePoint if defined?(pbEraseEscapePoint)
  return true
rescue => e
  TravelExpansionFramework.log("[soulstones] Air Dragonite failed safely: #{e.class}: #{e.message}") if defined?(TravelExpansionFramework) &&
                                                                                                      TravelExpansionFramework.respond_to?(:log)
  pbMessage(_INTL("Dragonite cannot find a safe route right now.")) if defined?(pbMessage)
  return false
end unless defined?(useAirDragonite)

if defined?(Trainer)
  class Trainer
    def default_battlebelt
      return {
        :med1   => [:NONE, 0, "None"],
        :med2   => [:NONE, 0, "None"],
        :combat => [:NONE, 0, "None"]
      }
    end unless method_defined?(:default_battlebelt)

    def normalize_battlebelt!
      @battlebelt = default_battlebelt if !@battlebelt.is_a?(Hash)
      defaults = default_battlebelt
      defaults.each do |slot, value|
        @battlebelt[slot] = value if !@battlebelt[slot].is_a?(Array) || @battlebelt[slot].length < 3
      end
      @beltbag = PokemonBag.new if (!@beltbag || !@beltbag.is_a?(PokemonBag)) && defined?(PokemonBag)
      @bagup = nil if !instance_variable_defined?(:@bagup)
      return @battlebelt
    end unless method_defined?(:normalize_battlebelt!)

    def battlebelt
      normalize_battlebelt! if respond_to?(:normalize_battlebelt!)
      return @battlebelt
    end unless method_defined?(:battlebelt)

    def battlebelt=(value)
      @battlebelt = value.is_a?(Hash) ? value : default_battlebelt
      normalize_battlebelt! if respond_to?(:normalize_battlebelt!)
      return @battlebelt
    end unless method_defined?(:battlebelt=)

    def beltbag
      normalize_battlebelt! if respond_to?(:normalize_battlebelt!)
      return @beltbag
    end unless method_defined?(:beltbag)

    def beltbag=(value)
      @beltbag = value
      return @beltbag
    end unless method_defined?(:beltbag=)

    def bagup
      @bagup = nil if !instance_variable_defined?(:@bagup)
      return @bagup
    end unless method_defined?(:bagup)

    def bagup=(value)
      @bagup = value
      return @bagup
    end unless method_defined?(:bagup=)

    def reset_battlebelt
      @battlebelt = default_battlebelt
      @beltbag = PokemonBag.new if defined?(PokemonBag)
      @bagup = nil
      $usingbelt = false
      return @battlebelt
    end unless method_defined?(:reset_battlebelt)

    def miningRocks
      @miningRocks ||= []
      return @miningRocks
    end unless method_defined?(:miningRocks)

    def miningRocks=(value)
      @miningRocks = value.is_a?(Array) ? value : []
      return @miningRocks
    end unless method_defined?(:miningRocks=)
  end
end

unless defined?(::GameMode_Scene)
  class ::GameMode_Scene
    def pbStartScene(*_args)
      return true
    end

    def pbMain(*_args)
      return 0
    end

    def pbEndScene(*_args)
      return true
    end

    def pbUpdate(*_args)
      return true
    end

    def update(*args)
      return pbUpdate(*args)
    end
  end
end

unless defined?(::GameModeScreen)
  class ::GameModeScreen
    def initialize(scene = nil)
      @scene = scene
    end

    def pbStartScreen(*_args)
      if defined?(TravelExpansionFramework) &&
         TravelExpansionFramework.respond_to?(:hollow_woods_apply_game_mode_defaults!)
        TravelExpansionFramework.hollow_woods_apply_game_mode_defaults!(:game_mode_screen)
      end
      @scene.pbStartScene if @scene && @scene.respond_to?(:pbStartScene)
      @scene.pbEndScene if @scene && @scene.respond_to?(:pbEndScene)
      return 0
    rescue => e
      TravelExpansionFramework.log("[hollow_woods] game mode screen skipped safely: #{e.class}: #{e.message}") if defined?(TravelExpansionFramework) &&
                                                                                                                  TravelExpansionFramework.respond_to?(:log)
      return 0
    end
  end
end

if defined?(TravelExpansionFramework) &&
   TravelExpansionFramework.respond_to?(:hollow_woods_apply_game_mode_defaults!)
  TravelExpansionFramework.hollow_woods_apply_game_mode_defaults!(:load)
end

def pbPCSettings(*args)
  if defined?(TravelExpansionFramework) &&
     TravelExpansionFramework.respond_to?(:hollow_woods_apply_game_mode_defaults!)
    TravelExpansionFramework.hollow_woods_apply_game_mode_defaults!(:pc_settings)
  end
  if defined?(pbFadeOutIn)
    pbFadeOutIn {
      scene = ::GameMode_Scene.new
      screen = ::GameModeScreen.new(scene)
      screen.pbStartScreen(*args)
      pbUpdateSceneMap if defined?(pbUpdateSceneMap)
    }
  else
    screen = ::GameModeScreen.new(::GameMode_Scene.new)
    screen.pbStartScreen(*args)
  end
  return true
end unless defined?(pbPCSettings)

module PBDayNight
  class << self
    def tef_infinity_shift_hour(time = nil)
      time = pbGetTimeNow if time.nil? && defined?(pbGetTimeNow)
      time = Time.now if time.nil?
      return time.hour if time.respond_to?(:hour)
      return time.to_i % 24
    rescue
      return 12
    end unless method_defined?(:tef_infinity_shift_hour)

    def isShift1?(time = nil)
      hour = tef_infinity_shift_hour(time)
      return hour >= 0 && hour < 4
    end unless method_defined?(:isShift1?)

    def isShift2?(time = nil)
      hour = tef_infinity_shift_hour(time)
      return hour >= 4 && hour < 8
    end unless method_defined?(:isShift2?)

    def isShift3?(time = nil)
      hour = tef_infinity_shift_hour(time)
      return hour >= 8 && hour < 12
    end unless method_defined?(:isShift3?)

    def isShift4?(time = nil)
      hour = tef_infinity_shift_hour(time)
      return hour >= 12 && hour < 16
    end unless method_defined?(:isShift4?)

    def isShift5?(time = nil)
      hour = tef_infinity_shift_hour(time)
      return hour >= 16 && hour < 20
    end unless method_defined?(:isShift5?)

    def isShift6?(time = nil)
      hour = tef_infinity_shift_hour(time)
      return hour >= 20 && hour < 24
    end unless method_defined?(:isShift6?)

    def reset
      @dayNightToneLastUpdate = nil
      @cachedTone = nil
      return true
    end unless method_defined?(:reset)
  end
end

module TravelExpansionFramework
  unless const_defined?(:SafeStatsProxy)
    class SafeStatsProxy
      def initialize(source = nil)
        @source = source
        @values = {}
      end

      def method_missing(name, *args, &block)
        return @source.__send__(name, *args, &block) if @source && @source.respond_to?(name)
        text = name.to_s
        if text[-1, 1] == "="
          key = text[0...-1]
          @values[key] = args[0]
          return args[0]
        end
        if text.start_with?("set_")
          @values[text] = args
          return true
        end
        return @values[text] if @values.key?(text)
        return 0
      end

      def respond_to_missing?(_name, _include_private = false)
        return true
      end
    end
  end

  def self.ensure_stats_proxy!
    return $stats if defined?($stats) && $stats
    $stats = SafeStatsProxy.new
    record_release_shim_hit("$stats", "save_load", "safe_proxy") if respond_to?(:record_release_shim_hit)
    log("[stats] created safe stats proxy for imported counter calls") if respond_to?(:log)
    return $stats
  rescue => e
    log("[stats] safe stats proxy failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end

  def self.followers_bridge_call(method_name, *args)
    name = method_name.to_s
    record_release_shim_hit("Followers.#{name}", "follower_system", "safe_noop") if respond_to?(:record_release_shim_hit)
    if defined?(FollowingPkmn) && FollowingPkmn.respond_to?(method_name)
      return FollowingPkmn.public_send(method_name, *args)
    end
    if defined?($PokemonTemp) && $PokemonTemp && $PokemonTemp.respond_to?(:dependentEvents) &&
       $PokemonTemp.dependentEvents && $PokemonTemp.dependentEvents.respond_to?(:refresh_sprite)
      $PokemonTemp.dependentEvents.refresh_sprite(false) rescue nil
    end
    return true
  rescue => e
    log("[followers] #{name} skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def self.decades_scaling_party
    party = nil
    party = $player.party if defined?($player) && $player && $player.respond_to?(:party)
    party = $Trainer.party if (party.nil? || party.empty?) && defined?($Trainer) && $Trainer && $Trainer.respond_to?(:party)
    return Array(party).compact.reject { |pkmn| pkmn.respond_to?(:egg?) && pkmn.egg? }
  rescue
    return []
  end

  def self.decades_max_level
    max_level = GameData::GrowthRate.max_level if defined?(GameData) && GameData.const_defined?(:GrowthRate)
    max_level = 100 if max_level.nil? || max_level.to_i <= 0
    return max_level.to_i
  rescue
    return 100
  end

  def self.decades_clamp_level(level, minimum = 1)
    value = integer(level, minimum)
    value = minimum if value < minimum
    max_level = decades_max_level
    value = max_level if value > max_level
    return value
  rescue
    return minimum
  end

  def self.decades_badge_count
    badges = nil
    badges = $player.badges if defined?($player) && $player && $player.respond_to?(:badges)
    badges = $Trainer.badges if badges.nil? && defined?($Trainer) && $Trainer && $Trainer.respond_to?(:badges)
    return badges.count(true) if badges.is_a?(Array)
    return badges.to_i if badges.respond_to?(:to_i)
    return 0
  rescue
    return 0
  end

  def self.decades_base_scaled_level
    party = decades_scaling_party
    level = nil
    if !party.empty?
      level = Object.new.send(:pbBalancedLevel, party) - 2 if Object.private_method_defined?(:pbBalancedLevel) ||
                                                              Object.method_defined?(:pbBalancedLevel)
      if level.nil?
        total = party.inject(0) { |sum, pkmn| sum + (pkmn.respond_to?(:level) ? pkmn.level.to_i : 1) }
        level = (total.to_f / party.length.to_f).round
      end
    end
    level ||= 5 + (decades_badge_count * 5)
    return decades_clamp_level(level, 5)
  rescue => e
    log("[decades] level scaling fallback used: #{e.class}: #{e.message}") if respond_to?(:log)
    return 5
  end

  def self.decades_effective_battle_level(original_level = nil)
    original = integer(original_level, 0)
    scaled = defined?(::AutomaticLevelScaling) && ::AutomaticLevelScaling.respond_to?(:getScaledLevel) ? ::AutomaticLevelScaling.getScaledLevel : decades_base_scaled_level
    return decades_clamp_level([original, scaled].max, 1) if original > 0
    return decades_clamp_level(scaled, 1)
  rescue
    return [integer(original_level, 5), 5].max
  end

  def self.decades_scale_pokemon_object!(pokemon, target_level = nil)
    return pokemon if pokemon.nil? || !pokemon.respond_to?(:level)
    new_level = decades_effective_battle_level(target_level || pokemon.level)
    return pokemon if pokemon.level.to_i >= new_level
    pokemon.level = new_level if pokemon.respond_to?(:level=)
    pokemon.calc_stats if pokemon.respond_to?(:calc_stats)
    return pokemon
  rescue => e
    log("[decades] pokemon level scale skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return pokemon
  end

  def self.decades_scale_trainer_party!(trainer)
    return trainer if !decades_active_now?
    party = trainer.party if trainer && trainer.respond_to?(:party)
    party = Array(party).compact
    return trainer if party.empty?
    original_average = party.inject(0) { |sum, pkmn| sum + (pkmn.respond_to?(:level) ? pkmn.level.to_i : 1) }
    original_average = (original_average.to_f / party.length.to_f).round
    base_level = decades_base_scaled_level
    party.each do |pkmn|
      next if pkmn.nil? || !pkmn.respond_to?(:level)
      difference = pkmn.level.to_i - original_average
      decades_scale_pokemon_object!(pkmn, base_level + difference)
    end
    record_release_shim_hit("AutomaticLevelScaling.trainer_party", "trainer_battle", "party_scaled") if respond_to?(:record_release_shim_hit)
    return trainer
  rescue => e
    log("[decades] trainer party scaling skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return trainer
  end

  def self.decades_scale_trainer_battle_args!(args)
    return args if !decades_active_now?
    scaled_args = Array(args)
    scaled_args.each do |arg|
      decades_scale_trainer_party!(arg) if arg && arg.respond_to?(:party)
    end
    return scaled_args
  rescue => e
    log("[decades] trainer battle arg scaling skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return args
  end

  def self.scale_imported_trainer_battle_args!(args)
    scaled_args = args
    scaled_args = decades_scale_trainer_battle_args!(scaled_args) if respond_to?(:decades_scale_trainer_battle_args!)
    return scaled_args
  rescue => e
    log("[trainer] imported trainer battle arg scaling skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return args
  end

  def self.decades_wild_battle_pairs(args)
    raw = Array(args).dup
    raw.pop if raw.last.is_a?(Hash)
    return [[raw[0], nil], 1] if raw.length == 1
    if raw.all? { |entry| entry.respond_to?(:species) && entry.respond_to?(:level) }
      return [raw.map { |entry| [entry, nil] }, 1]
    end
    outcome_var = 1
    if raw.length >= 7 && raw[2].is_a?(Numeric) && !raw[3].is_a?(Numeric)
      outcome_var = integer(raw[2], 1)
      raw = [raw[0], raw[1], raw[3], raw[4], raw[5], raw[6]]
    end
    pairs = []
    raw.each_slice(2) do |species, level|
      next if species.nil?
      pairs << [species, level]
    end
    return [pairs, outcome_var]
  rescue
    return [[], 1]
  end

  def self.call_overworld_battle_method(method_name, *args)
    return Object.new.send(method_name, *args) if Object.private_method_defined?(method_name) ||
                                                 Object.method_defined?(method_name)
    return Kernel.send(method_name, *args) if defined?(Kernel) && Kernel.respond_to?(method_name)
    return true
  rescue => e
    log("[decades] #{method_name} failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def self.start_host_wild_battle(*args)
    pairs, outcome_var = decades_wild_battle_pairs(args)
    return true if pairs.empty?
    case pairs.length
    when 1
      species, level = pairs[0]
      return call_overworld_battle_method(:pbWildBattleCore, species) if species.respond_to?(:species) && species.respond_to?(:level)
      return call_overworld_battle_method(:pbWildBattle, species, integer(level, 5), outcome_var)
    when 2
      return call_overworld_battle_method(:pbDoubleWildBattle, pairs[0][0], integer(pairs[0][1], 5),
                                          pairs[1][0], integer(pairs[1][1], 5), outcome_var)
    else
      return call_overworld_battle_method(:pbTripleWildBattle, pairs[0][0], integer(pairs[0][1], 5),
                                          pairs[1][0], integer(pairs[1][1], 5),
                                          pairs[2][0], integer(pairs[2][1], 5), outcome_var)
    end
  rescue => e
    log("[wild_battle] host fallback skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def self.start_decades_wild_battle(*args)
    pairs, outcome_var = decades_wild_battle_pairs(args)
    return true if pairs.empty?
    scaled = pairs.map do |species, level|
      if species.respond_to?(:species) && species.respond_to?(:level)
        [decades_scale_pokemon_object!(species, level), nil]
      else
        [species, decades_effective_battle_level(level)]
      end
    end
    record_release_shim_hit("WildBattle.start", "encounters", "decades_scaled") if respond_to?(:record_release_shim_hit)
    case scaled.length
    when 1
      species, level = scaled[0]
      return call_overworld_battle_method(:pbWildBattleCore, species) if level.nil?
      return call_overworld_battle_method(:pbWildBattle, species, level, outcome_var)
    when 2
      return call_overworld_battle_method(:pbDoubleWildBattle, scaled[0][0], scaled[0][1] || scaled[0][0].level,
                                          scaled[1][0], scaled[1][1] || scaled[1][0].level, outcome_var)
    else
      return call_overworld_battle_method(:pbTripleWildBattle, scaled[0][0], scaled[0][1] || scaled[0][0].level,
                                          scaled[1][0], scaled[1][1] || scaled[1][0].level,
                                          scaled[2][0], scaled[2][1] || scaled[2][0].level, outcome_var)
    end
  rescue => e
    log("[decades] WildBattle.start skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end
end

Object.const_set(:Followers, Module.new) unless Object.const_defined?(:Followers, false)

class << Followers
  def follow_into_door(*args)
    return TravelExpansionFramework.followers_bridge_call(:follow_into_door, *args) if defined?(TravelExpansionFramework) &&
                                                                                       TravelExpansionFramework.respond_to?(:followers_bridge_call)
    return true
  end unless method_defined?(:follow_into_door)

  def follow_out_door(*args)
    return TravelExpansionFramework.followers_bridge_call(:follow_out_door, *args) if defined?(TravelExpansionFramework) &&
                                                                                     TravelExpansionFramework.respond_to?(:followers_bridge_call)
    return true
  end unless method_defined?(:follow_out_door)

  def refresh(*args)
    return TravelExpansionFramework.followers_bridge_call(:refresh, *args) if defined?(TravelExpansionFramework) &&
                                                                             TravelExpansionFramework.respond_to?(:followers_bridge_call)
    return true
  end unless method_defined?(:refresh)

  def hide(*args)
    return TravelExpansionFramework.followers_bridge_call(:hide, *args) if defined?(TravelExpansionFramework) &&
                                                                          TravelExpansionFramework.respond_to?(:followers_bridge_call)
    return true
  end unless method_defined?(:hide)

  def show(*args)
    return TravelExpansionFramework.followers_bridge_call(:show, *args) if defined?(TravelExpansionFramework) &&
                                                                          TravelExpansionFramework.respond_to?(:followers_bridge_call)
    return true
  end unless method_defined?(:show)

  def method_missing(name, *args, &block)
    return TravelExpansionFramework.followers_bridge_call(name, *args) if defined?(TravelExpansionFramework) &&
                                                                         TravelExpansionFramework.respond_to?(:followers_bridge_call)
    return true
  end

  def respond_to_missing?(_name, _include_private = false)
    return true
  end
end

Object.const_set(:TrashCans, Module.new) unless Object.const_defined?(:TrashCans, false)

class << TrashCans
  def pbTrashEncounter(*args)
    if defined?(TravelExpansionFramework) &&
       TravelExpansionFramework.respond_to?(:decades_trash_encounter!) &&
       TravelExpansionFramework.decades_gatehouse_trash_event?
      return TravelExpansionFramework.decades_trash_encounter!(*args)
    elsif defined?(TravelExpansionFramework)
      TravelExpansionFramework.record_release_shim_hit("TrashCans.pbTrashEncounter", "encounters", "safe_empty") if TravelExpansionFramework.respond_to?(:record_release_shim_hit)
      pbMessage(_INTL("There's nothing interesting inside.")) if defined?(pbMessage)
    end
    return false
  rescue
    return false
  end unless method_defined?(:pbTrashEncounter)

  def method_missing(name, *_args, &_block)
    if defined?(TravelExpansionFramework)
      TravelExpansionFramework.record_release_shim_hit("TrashCans.#{name}", "encounters", "safe_noop") if TravelExpansionFramework.respond_to?(:record_release_shim_hit)
    end
    return false
  end

  def respond_to_missing?(_name, _include_private = false)
    return true
  end
end

unless defined?(Difficulty)
  class Difficulty
    attr_accessor :fixed_increase, :random_increase

    def initialize(fixed_increase: 0, random_increase: 0)
      @fixed_increase = fixed_increase.to_i
      @random_increase = random_increase.to_i
    end
  end
end

unless defined?(LevelScalingSettings)
  module LevelScalingSettings
    TRAINER_VARIABLE = 98 unless const_defined?(:TRAINER_VARIABLE)
    WILD_VARIABLE = 98 unless const_defined?(:WILD_VARIABLE)
    PROPORTIONAL_SCALING = true unless const_defined?(:PROPORTIONAL_SCALING)
    ONLY_SCALE_IF_HIGHER = true unless const_defined?(:ONLY_SCALE_IF_HIGHER)
    ONLY_SCALE_IF_LOWER = false unless const_defined?(:ONLY_SCALE_IF_LOWER)
    SAVE_TRAINER_PARTIES = false unless const_defined?(:SAVE_TRAINER_PARTIES)
    USE_MAP_LEVEL_FOR_WILD_POKEMON = false unless const_defined?(:USE_MAP_LEVEL_FOR_WILD_POKEMON)
    AUTOMATIC_EVOLUTIONS = false unless const_defined?(:AUTOMATIC_EVOLUTIONS)
    INCLUDE_NON_NATURAL_EVOLUTIONS = true unless const_defined?(:INCLUDE_NON_NATURAL_EVOLUTIONS)
    INCLUDE_PREVIOUS_STAGES = true unless const_defined?(:INCLUDE_PREVIOUS_STAGES)
    INCLUDE_NEXT_STAGES = true unless const_defined?(:INCLUDE_NEXT_STAGES)
    DEFAULT_FIRST_EVOLUTION_LEVEL = 30 unless const_defined?(:DEFAULT_FIRST_EVOLUTION_LEVEL)
    DEFAULT_SECOND_EVOLUTION_LEVEL = 50 unless const_defined?(:DEFAULT_SECOND_EVOLUTION_LEVEL)
    NATURAL_EVOLUTION_METHODS = [:Level, :LevelMale, :LevelFemale, :LevelDay, :LevelNight].freeze unless const_defined?(:NATURAL_EVOLUTION_METHODS)
    DIFFICULTIES = {
      1 => Difficulty.new(fixed_increase: -3, random_increase: 3),
      2 => Difficulty.new(random_increase: 2),
      3 => Difficulty.new(fixed_increase: 3, random_increase: 3),
      4 => Difficulty.new,
      5 => Difficulty.new(fixed_increase: -2, random_increase: 5),
      6 => Difficulty.new,
      7 => Difficulty.new(fixed_increase: -100)
    }.freeze unless const_defined?(:DIFFICULTIES)
  end
end

unless defined?(AutomaticLevelScaling)
  class AutomaticLevelScaling
    @selected_difficulty = LevelScalingSettings::DIFFICULTIES[4]
    @settings = {
      :temporary => false,
      :automatic_evolutions => LevelScalingSettings::AUTOMATIC_EVOLUTIONS,
      :include_non_natural_evolutions => LevelScalingSettings::INCLUDE_NON_NATURAL_EVOLUTIONS,
      :include_previous_stages => LevelScalingSettings::INCLUDE_PREVIOUS_STAGES,
      :include_next_stages => LevelScalingSettings::INCLUDE_NEXT_STAGES,
      :first_evolution_level => LevelScalingSettings::DEFAULT_FIRST_EVOLUTION_LEVEL,
      :second_evolution_level => LevelScalingSettings::DEFAULT_SECOND_EVOLUTION_LEVEL,
      :proportional_scaling => LevelScalingSettings::PROPORTIONAL_SCALING,
      :only_scale_if_higher => LevelScalingSettings::ONLY_SCALE_IF_HIGHER,
      :only_scale_if_lower => LevelScalingSettings::ONLY_SCALE_IF_LOWER,
      :save_trainer_parties => LevelScalingSettings::SAVE_TRAINER_PARTIES,
      :use_map_level_for_wild_pokemon => LevelScalingSettings::USE_MAP_LEVEL_FOR_WILD_POKEMON,
      :update_moves => false
    }
    @previous_trainer_parties = {}

    class << self
      def difficulty=(id)
        @selected_difficulty = LevelScalingSettings::DIFFICULTIES[id.to_i] || LevelScalingSettings::DIFFICULTIES[4] || Difficulty.new
        return @selected_difficulty
      rescue
        @selected_difficulty = Difficulty.new
      end

      def settings
        return @settings ||= {}
      end

      def getScaledLevel
        level = TravelExpansionFramework.decades_base_scaled_level
        difficulty = @selected_difficulty || Difficulty.new
        level += difficulty.fixed_increase.to_i
        random = difficulty.random_increase.to_i
        level += random < 0 ? rand(random..0) : rand(random + 1) if random != 0
        level = TravelExpansionFramework.decades_clamp_level(level, 1)
        @last_scaled_level = level
        TravelExpansionFramework.record_release_shim_hit("AutomaticLevelScaling.getScaledLevel", "trainer_battle", level.to_s) if defined?(TravelExpansionFramework) &&
                                                                                                                                  TravelExpansionFramework.respond_to?(:record_release_shim_hit)
        return level
      rescue => e
        TravelExpansionFramework.log("[decades] AutomaticLevelScaling.getScaledLevel failed safely: #{e.class}: #{e.message}") if defined?(TravelExpansionFramework) &&
                                                                                                                                 TravelExpansionFramework.respond_to?(:log)
        return 5
      end

      def getMapLevel(map_id)
        if defined?($PokemonGlobal) && $PokemonGlobal
          $PokemonGlobal.map_levels = {} if $PokemonGlobal.respond_to?(:map_levels=) && !$PokemonGlobal.respond_to?(:map_levels)
          map_levels = $PokemonGlobal.map_levels if $PokemonGlobal.respond_to?(:map_levels)
          if map_levels.respond_to?(:[])
            map_levels[map_id] = getScaledLevel if !map_levels.key?(map_id)
            return map_levels[map_id]
          end
        end
        return getScaledLevel
      rescue
        return getScaledLevel
      end

      def shouldScaleLevel?(previous_level, new_level)
        return false if settings[:only_scale_if_higher] && previous_level.to_i > new_level.to_i
        return false if settings[:only_scale_if_lower] && previous_level.to_i < new_level.to_i
        return true
      rescue
        return true
      end

      def battledTrainer?(trainer_id)
        return @previous_trainer_parties.key?(trainer_id)
      rescue
        return false
      end

      def scaleToPreviousTrainerParty(trainer)
        trainer.party = @previous_trainer_parties[trainer.key] if trainer && trainer.respond_to?(:party=) && @previous_trainer_parties.key?(trainer.key)
        return trainer
      rescue
        return trainer
      end

      def savePreviousTrainerParty(trainer_key, party)
        @previous_trainer_parties[trainer_key] = party
        return true
      rescue
        return true
      end

      def setTemporarySetting(setting, value)
        settings[:temporary] = true
        normalized = setting.to_s.gsub(/([a-z])([A-Z])/, "\\1_\\2").downcase.to_sym
        settings[normalized] = value
        return true
      rescue
        return true
      end

      def setSettings(values = nil, **kwargs)
        merged = values.is_a?(Hash) ? values : kwargs
        merged.each { |key, value| settings[key.to_sym] = value } if merged
        settings[:temporary] = false if merged.nil? || !merged.key?(:temporary)
        return true
      rescue
        return true
      end

      def setNewLevel(pokemon, difference_from_average = 0)
        return TravelExpansionFramework.decades_scale_pokemon_object!(pokemon, getScaledLevel + difference_from_average.to_i)
      end

      def setNewStage(pokemon)
        return pokemon.scaleEvolutionStage if pokemon && pokemon.respond_to?(:scaleEvolutionStage)
        return pokemon
      rescue
        return pokemon
      end

      def getPossibleEvolutions(pokemon)
        return pokemon.getPossibleEvolutions if pokemon && pokemon.respond_to?(:getPossibleEvolutions)
        return []
      rescue
        return []
      end

      def getEvolutionLevel(pokemon, possible_evolutions = nil, evolution_stage = 0)
        return pokemon.getEvolutionLevel(evolution_stage.to_i > 0) if pokemon && pokemon.respond_to?(:getEvolutionLevel)
        return evolution_stage.to_i > 0 ? settings[:second_evolution_level] : settings[:first_evolution_level]
      rescue
        return 30
      end
    end
  end

  def new_project_quest_key(quest)
    return nil if quest.nil?
    value = quest
    value = quest.id if quest.respond_to?(:id)
    value = value.name if value.respond_to?(:name) && !value.is_a?(Symbol)
    text = value.to_s.strip
    return nil if text.empty?
    return text
  rescue
    return quest.to_s
  end

  def new_project_quest_state(expansion_id = nil)
    expansion = expansion_id.to_s
    expansion = current_new_project_expansion_id.to_s if expansion.empty? && respond_to?(:current_new_project_expansion_id)
    expansion = "new_project" if expansion.empty?
    meta = new_project_metadata(expansion) if respond_to?(:new_project_metadata)
    if meta.is_a?(Hash)
      meta["quest_shim"] = {} if !meta["quest_shim"].is_a?(Hash)
      store = meta["quest_shim"]
    else
      @new_project_quest_fallback ||= {}
      @new_project_quest_fallback[expansion] ||= {}
      store = @new_project_quest_fallback[expansion]
    end
    store["active"] = [] if !store["active"].is_a?(Array)
    store["completed"] = [] if !store["completed"].is_a?(Array)
    store["stages"] = {} if !store["stages"].is_a?(Hash)
    return store
  rescue
    @new_project_quest_fallback ||= {}
    @new_project_quest_fallback["new_project"] ||= { "active" => [], "completed" => [], "stages" => {} }
    return @new_project_quest_fallback["new_project"]
  end

  def new_project_start_quest!(quest = nil, *args)
    if respond_to?(:release_activate_quest!)
      return release_activate_quest!(quest, nil, true, *args)
    end
    key = new_project_quest_key(quest)
    return true if key.nil?
    store = new_project_quest_state
    store["active"] << key if !store["active"].include?(key) && !store["completed"].include?(key)
    store["stages"][key] = integer(args[0], 0) if args && !args.empty? && respond_to?(:integer)
    log("[quest] started #{key}") if respond_to?(:log)
    return true
  rescue => e
    log("[quest] start skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def new_project_complete_quest!(quest = nil, *args)
    if respond_to?(:release_complete_quest!)
      return release_complete_quest!(quest, true, *args)
    end
    key = new_project_quest_key(quest)
    return true if key.nil?
    store = new_project_quest_state
    store["active"].delete(key)
    store["completed"] << key if !store["completed"].include?(key)
    log("[quest] completed #{key}") if respond_to?(:log)
    return true
  rescue => e
    log("[quest] completion skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def new_project_quest_stage(quest = nil)
    return release_quest_stage(quest) if respond_to?(:release_quest_stage)
    key = new_project_quest_key(quest)
    return 0 if key.nil?
    store = new_project_quest_state
    return integer(store["stages"][key], 0) if respond_to?(:integer)
    return store["stages"][key].to_i
  rescue
    return 0
  end

  def new_project_quest_started?(quest = nil)
    return release_quest_started?(quest) if respond_to?(:release_quest_started?)
    key = new_project_quest_key(quest)
    return false if key.nil?
    store = new_project_quest_state
    return store["active"].include?(key) || store["completed"].include?(key) || store["stages"].has_key?(key)
  rescue
    return false
  end

  def new_project_quest_completed?(quest = nil)
    return release_quest_completed?(quest) if respond_to?(:release_quest_completed?)
    key = new_project_quest_key(quest)
    return false if key.nil?
    return new_project_quest_state["completed"].include?(key)
  rescue
    return false
  end

  def void_rival_charset_name(rival_slot = nil)
    slot = rival_slot.to_i
    slot = 1 if slot <= 0
    candidates = case slot
    when 1
      ["trainer_RONAN", "trainer_PECAN", "1_RIVAL_CHAMPION", "trainer_SEREN", "trainer_Ronan", "RIVAL_RONAN"]
    when 2
      ["trainer_NYA", "trainer_SEREN", "trainer_PECAN", "1_RIVAL_CHAMPION", "trainer_NIA", "trainer_Nia", "RIVAL_NIA"]
    when 3
      ["trainer_SEREN", "trainer_NYA", "trainer_PECAN", "1_RIVAL_CHAMPION", "trainer_Seren", "RIVAL_SEREN"]
    else
      ["trainer_NYA", "trainer_RONAN", "trainer_SEREN", "trainer_PECAN", "1_RIVAL_CHAMPION"]
    end
    candidates.each do |name|
      resolved = nil
      begin
        resolved = resolve_runtime_path_for_expansion(POKEMON_VOID_EXPANSION_ID, "Graphics/Characters/#{name}", [".png", ".PNG"]) if respond_to?(:resolve_runtime_path_for_expansion)
      rescue
        resolved = nil
      end
      begin
        resolved ||= pbResolveBitmap("Graphics/Characters/#{name}") if defined?(pbResolveBitmap)
      rescue
        resolved ||= nil
      end
      return name if resolved
    end
    return candidates[0]
  rescue
    return "trainer_NYA"
  end

  def void_apply_event_charset!(event, charset)
    return false if !event || charset.to_s.empty?
    event.character_name = charset if event.respond_to?(:character_name=)
    if event.respond_to?(:instance_variable_set)
      event.instance_variable_set(:@character_name, charset)
      event.instance_variable_set(:@tef_void_forced_character_name, charset)
      event.instance_variable_set(:@tile_id, 0)
      event.instance_variable_set(:@character_hue, 0)
      event.instance_variable_set(:@opacity, 255)
      event.instance_variable_set(:@transparent, false)
      event.instance_variable_set(:@erased, false)
    end
    return true
  rescue => e
    log("[void] event charset apply failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def void_runtime_event_id(event)
    return nil if !event
    return event.id if event.respond_to?(:id)
    raw_event = event.instance_variable_get(:@event) if event.respond_to?(:instance_variable_get)
    return raw_event.id if raw_event && raw_event.respond_to?(:id)
    return event.instance_variable_get(:@id) if event.respond_to?(:instance_variable_get)
    return nil
  rescue
    return nil
  end

  def void_runtime_event_map_id(event, fallback = nil)
    return fallback if !event
    return event.map_id if event.respond_to?(:map_id)
    return event.instance_variable_get(:@map_id) if event.respond_to?(:instance_variable_get)
    return fallback
  rescue
    return fallback
  end

  def void_runtime_event_commands(event)
    return [] if !event || !event.respond_to?(:instance_variable_get)
    list = event.instance_variable_get(:@list)
    return list if list.is_a?(Array)
    page = void_runtime_event_current_page(event)
    return page.list if page && page.respond_to?(:list) && page.list.is_a?(Array)
    return []
  rescue
    return []
  end

  def void_runtime_event_current_page(event)
    return nil if !event || !event.respond_to?(:instance_variable_get)
    page = event.instance_variable_get(:@page)
    return page if page
    raw_event = event.instance_variable_get(:@event)
    page_index = event.instance_variable_get(:@page_index)
    if raw_event && raw_event.respond_to?(:pages) && raw_event.pages
      if !page_index.nil?
        page = raw_event.pages[page_index.to_i]
        return page if page
      end
      return raw_event.pages.last
    end
    return nil
  rescue
    return nil
  end

  def void_event_page_condition_met?(event, page, map_id = nil)
    return false if !event || !page || !page.respond_to?(:condition)
    condition = page.condition
    return true if !condition
    if condition.switch1_valid
      if event.respond_to?(:switchIsOn?)
        return false if !event.switchIsOn?(condition.switch1_id)
      elsif defined?($game_switches)
        return false if !$game_switches[condition.switch1_id]
      end
    end
    if condition.switch2_valid
      if event.respond_to?(:switchIsOn?)
        return false if !event.switchIsOn?(condition.switch2_id)
      elsif defined?($game_switches)
        return false if !$game_switches[condition.switch2_id]
      end
    end
    if condition.variable_valid && defined?($game_variables)
      return false if $game_variables[condition.variable_id].to_i < condition.variable_value.to_i
    end
    if condition.self_switch_valid
      map = map_id || void_runtime_event_map_id(event, ($game_map.map_id rescue nil))
      event_id = void_runtime_event_id(event)
      return false if !defined?($game_self_switches) ||
                      $game_self_switches[[map.to_i, event_id.to_i, condition.self_switch_ch]] != true
    end
    return true
  rescue
    return false
  end

  def void_runtime_event_all_commands(event)
    commands = []
    raw_event = event.instance_variable_get(:@event) if event && event.respond_to?(:instance_variable_get)
    if raw_event && raw_event.respond_to?(:pages) && raw_event.pages
      raw_event.pages.each do |page|
        commands.concat(page.list) if page && page.respond_to?(:list) && page.list.is_a?(Array)
      end
    end
    commands.concat(void_runtime_event_commands(event))
    return commands.compact
  rescue
    return void_runtime_event_commands(event)
  end

  def void_runtime_event_trigger(event)
    return nil if !event || !event.respond_to?(:instance_variable_get)
    trigger = event.instance_variable_get(:@trigger)
    return trigger if !trigger.nil?
    page = void_runtime_event_current_page(event)
    return page.trigger if page && page.respond_to?(:trigger)
    return nil
  rescue
    return nil
  end

  def void_runtime_event_empty_graphic?(event)
    return false if !event || !event.respond_to?(:instance_variable_get)
    character_name = event.respond_to?(:character_name) ? event.character_name : event.instance_variable_get(:@character_name)
    tile_id = event.respond_to?(:tile_id) ? event.tile_id : event.instance_variable_get(:@tile_id)
    return character_name.to_s.empty? && tile_id.to_i <= 0
  rescue
    return false
  end

  def void_runtime_event_name(event)
    return "" if !event
    return event.name.to_s if event.respond_to?(:name)
    raw_event = event.instance_variable_get(:@event) if event.respond_to?(:instance_variable_get)
    return raw_event.name.to_s if raw_event && raw_event.respond_to?(:name)
    return event.instance_variable_get(:@event_name).to_s if event.respond_to?(:instance_variable_get)
    return ""
  rescue
    return ""
  end

  def void_local_map_id(map_id = nil)
    map = integer(map_id || ($game_map.map_id rescue 0), 0)
    expansion = current_void_expansion_id(map) if respond_to?(:current_void_expansion_id)
    if respond_to?(:local_map_id_for)
      local = local_map_id_for(expansion || POKEMON_VOID_EXPANSION_ID, map) rescue nil
      return integer(local, map) if local
    end
    return map - 48000 if map >= 48000 && map < 49000
    return map
  rescue
    return integer(map_id, 0)
  end

  def void_game_switch_on?(switch_id)
    return false if !defined?($game_switches) || !$game_switches
    return $game_switches[integer(switch_id, 0)] == true
  rescue
    return false
  end

  def void_player_has_running_shoes?
    player_obj = ($player rescue nil)
    trainer_obj = ($Trainer rescue nil)
    [player_obj, trainer_obj].compact.each do |player|
      return true if player.respond_to?(:has_running_shoes) && player.has_running_shoes
      return true if player.respond_to?(:instance_variable_get) && player.instance_variable_get(:@has_running_shoes) == true
    end
    return false
  rescue
    return false
  end

  def void_force_event_through!(event)
    return false if !event
    previous = event.respond_to?(:through) ? event.through : (event.instance_variable_get(:@through) rescue nil)
    event.through = true if event.respond_to?(:through=)
    event.instance_variable_set(:@through, true) if event.respond_to?(:instance_variable_set)
    return previous != true
  rescue
    return false
  end

  def void_event_command_text(command)
    params = command.respond_to?(:parameters) ? command.parameters : (command.instance_variable_get(:@parameters) rescue [])
    return Array(params).map { |param| param.to_s }.join("\n")
  rescue
    return ""
  end

  def void_move_route_sets_opacity_zero?(route)
    return false if !route || !route.respond_to?(:list)
    route.list.any? do |move_command|
      code = move_command.respond_to?(:code) ? move_command.code : (move_command.instance_variable_get(:@code) rescue nil)
      next false if code.to_i != 42
      params = move_command.respond_to?(:parameters) ? move_command.parameters : (move_command.instance_variable_get(:@parameters) rescue [])
      integer(Array(params)[0], 255) <= 0
    end
  rescue
    return false
  end

  def void_command_calls_clear_rival_graphic?(command, event_id)
    return false if event_id.to_i <= 0
    text = void_event_command_text(command)
    text.scan(/pbVoidClearRivalGraphic\s*\(\s*(-?\d+)/i) do |target|
      return true if integer(Array(target)[0], 0) == event_id.to_i
    end
    return false
  rescue
    return false
  end

  def void_map_script_clears_rival_graphic?(event_id, map_id = nil)
    return false if event_id.to_i <= 0 || !defined?($game_map) || !$game_map || !$game_map.respond_to?(:events)
    map = map_id || ($game_map.map_id rescue nil)
    $game_map.events.each_value do |candidate|
      raw_event = candidate.instance_variable_get(:@event) if candidate && candidate.respond_to?(:instance_variable_get)
      pages = raw_event && raw_event.respond_to?(:pages) ? raw_event.pages : []
      pages.each do |page|
        next if !void_event_page_condition_met?(candidate, page, map)
        next if !page.respond_to?(:list) || !page.list.is_a?(Array)
        return true if page.list.any? { |command| void_command_calls_clear_rival_graphic?(command, event_id) }
      end
    end
    return false
  rescue
    return false
  end

  def void_current_page_clears_rival_graphic?(event)
    event_id = void_runtime_event_id(event).to_i
    return false if event_id <= 0
    void_runtime_event_commands(event).any? { |command| void_command_calls_clear_rival_graphic?(command, event_id) }
  rescue
    return false
  end

  def void_current_page_completion_stub?(event)
    page = void_runtime_event_current_page(event)
    return false if !page || !page.respond_to?(:condition)
    condition = page.condition
    return false if !condition || !(condition.self_switch_valid rescue false)
    text = void_runtime_event_commands(event).map { |command| void_event_command_text(command) }.join("\n")
    return false if text =~ /pbSetRivalDialoguePortrait|pbVoidApplyRivalGraphic|pbWalkCharacterTo|pbMessage|\bRival\b|rival/i
    return true
  rescue
    return false
  end

  def void_runtime_event_hidden_by_current_page?(event)
    opacity = event.respond_to?(:opacity) ? event.opacity : event.instance_variable_get(:@opacity)
    return true if !opacity.nil? && opacity.to_i <= 0
    return true if void_current_page_clears_rival_graphic?(event)
    return true if void_current_page_completion_stub?(event)
    trigger = void_runtime_event_trigger(event).to_i
    return false if trigger != 4
    void_runtime_event_commands(event).any? do |command|
      code = command.respond_to?(:code) ? command.code : (command.instance_variable_get(:@code) rescue nil)
      next false if code.to_i != 209
      params = command.respond_to?(:parameters) ? command.parameters : (command.instance_variable_get(:@parameters) rescue [])
      void_move_route_sets_opacity_zero?(Array(params)[1])
    end
  rescue
    return false
  end

  def void_invisible_transfer_event?(event)
    return false if !void_runtime_event_empty_graphic?(event)
    trigger = void_runtime_event_trigger(event).to_i
    return false if ![1, 2].include?(trigger)
    void_runtime_event_commands(event).any? do |command|
      code = command.respond_to?(:code) ? command.code : (command.instance_variable_get(:@code) rescue nil)
      code.to_i == 201
    end
  rescue
    return false
  end

  def void_repair_transfer_event_passability!(event, map_id = nil)
    return false if !event
    map = (map_id || void_runtime_event_map_id(event, ($game_map.map_id rescue nil))).to_i
    return false if !void_active_now?(map)
    return false if !void_invisible_transfer_event?(event)
    event.through = true if event.respond_to?(:through=)
    event.instance_variable_set(:@through, true) if event.respond_to?(:instance_variable_set)
    return true
  rescue => e
    log("[void] transfer event passability repair failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def void_repair_running_shoes_event_passability!(event, map_id = nil)
    return false if !event
    map = (map_id || void_runtime_event_map_id(event, ($game_map.map_id rescue nil))).to_i
    return false if !void_active_now?(map)
    return false if void_local_map_id(map) != 3
    event_id = void_runtime_event_id(event).to_i
    name = void_runtime_event_name(event)
    active_story = void_game_switch_on?(76) || void_game_switch_on?(176) ||
                   void_game_switch_on?(101) || void_player_has_running_shoes?
    return false if !active_story
    should_repair = (event_id == 23 && name =~ /give running shoes/i) ||
                    (event_id == 22 && name =~ /\bmom\b/i)
    return false if !should_repair
    changed = void_force_event_through!(event)
    if changed
      @void_running_shoes_passability_log ||= {}
      key = "#{map}:#{event_id}"
      if !@void_running_shoes_passability_log[key]
        @void_running_shoes_passability_log[key] = true
        log("[void] made running-shoes event #{event_id} passable after #{name.inspect}") if respond_to?(:log)
      end
    end
    return changed
  rescue => e
    log("[void] running-shoes event passability repair failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def void_rival_graphic_store_key(map_id, event_id)
    "#{integer(map_id, 0)}:#{integer(event_id, 0)}"
  rescue
    "#{map_id}:#{event_id}"
  end

  def void_rival_graphic_cleared?(map_id, event_id)
    store = void_rival_graphic_store
    return false if !store.is_a?(Hash)
    data = store[void_rival_graphic_store_key(map_id, event_id)]
    return data.is_a?(Hash) && data["cleared"] == true
  rescue
    return false
  end

  def void_reapply_rival_graphic_for_event!(event, map_id = nil)
    return false if !event
    event_id = void_runtime_event_id(event).to_i
    return false if event_id <= 0
    map = (map_id || void_runtime_event_map_id(event, ($game_map.map_id rescue nil))).to_i
    return false if !void_active_now?(map)
    store = void_rival_graphic_store
    data = store[void_rival_graphic_store_key(map, event_id)] if store.is_a?(Hash)
    return false if !data.is_a?(Hash)
    return false if data["cleared"] == true
    charset = data["charset"]
    return false if charset.to_s.empty?
    return void_apply_event_charset!(event, charset)
  rescue => e
    log("[void] rival graphic reapply failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def void_rival_slot_from_setup_commands(event_id)
    return 0 if event_id.to_i <= 0 || !defined?($game_map) || !$game_map || !$game_map.respond_to?(:events)
    map_id = ($game_map.map_id rescue nil)
    $game_map.events.each_value do |candidate|
      raw_event = candidate.instance_variable_get(:@event) if candidate && candidate.respond_to?(:instance_variable_get)
      pages = raw_event && raw_event.respond_to?(:pages) ? raw_event.pages : []
      pages.each do |page|
        next if !void_event_page_condition_met?(candidate, page, map_id)
        next if !page.respond_to?(:list) || !page.list.is_a?(Array)
        text = page.list.map { |command| void_event_command_text(command) }.join("\n")
        text.scan(/pbVoidApplyRivalGraphic\s*\(\s*(-?\d+)\s*(?:,\s*(-?\d+))?/i) do |target, slot|
          next if integer(target, 0) != event_id.to_i
          parsed = integer(slot, 1)
          return parsed > 0 ? parsed : 1
        end
      end
    end
    return 0
  rescue
    return 0
  end

  def void_inferred_rival_slot_for_event(event)
    event_id = void_runtime_event_id(event).to_i
    setup_slot = void_rival_slot_from_setup_commands(event_id)
    return setup_slot if setup_slot > 0
    raw_event = event.instance_variable_get(:@event) if event && event.respond_to?(:instance_variable_get)
    event_name = raw_event && raw_event.respond_to?(:name) ? raw_event.name.to_s : ""
    event_name = event.instance_variable_get(:@event_name).to_s if event_name.empty? && event.respond_to?(:instance_variable_get)
    return 2 if event_name =~ /cultist.*rival|rival.*cultist/i
    return void_current_rival_slot if event_name =~ /rival/i
    return 0
  rescue
    return 0
  end

  def void_repair_inferred_rival_graphic!(event, map_id = nil)
    return false if !event
    map = (map_id || void_runtime_event_map_id(event, ($game_map.map_id rescue nil))).to_i
    return false if !void_active_now?(map)
    return false if !void_runtime_event_empty_graphic?(event)
    return false if void_runtime_event_hidden_by_current_page?(event)
    event_id = void_runtime_event_id(event).to_i
    return false if event_id <= 0
    return false if void_map_script_clears_rival_graphic?(event_id, map)
    return false if void_rival_graphic_cleared?(map, event_id)
    slot = void_inferred_rival_slot_for_event(event)
    return false if slot.to_i <= 0
    charset = void_rival_charset_name(slot)
    return false if charset.to_s.empty?
    store = void_rival_graphic_store
    if store.is_a?(Hash)
      key = void_rival_graphic_store_key(map, event_id)
      store[key] ||= {}
      store[key].delete("cleared")
      store[key]["target_event_id"] = event_id
      store[key]["live_event_id"] = event_id
      store[key]["rival_slot"] = slot
      store[key]["charset"] = charset
    end
    changed = void_apply_event_charset!(event, charset)
    if changed
      @void_inferred_rival_graphic_log ||= {}
      log_key = "#{map}:#{event_id}:#{charset}"
      if !@void_inferred_rival_graphic_log[log_key]
        @void_inferred_rival_graphic_log[log_key] = true
        log("[void] repaired inferred rival graphic #{charset.inspect} on event #{event_id}") if respond_to?(:log)
      end
    end
    return changed
  rescue => e
    log("[void] inferred rival graphic repair failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def void_repair_runtime_event!(event, map_id = nil, _reason = "event")
    changed = false
    changed = true if void_repair_running_shoes_event_passability!(event, map_id)
    changed = true if void_repair_transfer_event_passability!(event, map_id)
    changed = true if void_reapply_rival_graphic_for_event!(event, map_id)
    changed = true if void_repair_inferred_rival_graphic!(event, map_id)
    return changed
  rescue
    return false
  end

  def void_prepare_map_runtime!(game_map = nil, reason = "map_setup")
    map = game_map || (defined?($game_map) ? $game_map : nil)
    return false if !map || !map.respond_to?(:events)
    map_id = map.respond_to?(:map_id) ? map.map_id : (map.instance_variable_get(:@map_id) rescue nil)
    return false if !void_active_now?(map_id)
    repaired = 0
    map.events.each_value do |event|
      repaired += 1 if void_repair_runtime_event!(event, map_id, reason)
    end
    log("[void] repaired #{repaired} runtime map event(s) for #{reason}") if repaired > 0 && respond_to?(:log)
    return repaired > 0
  rescue => e
    log("[void] map runtime repair skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def void_scene_runtime_repair_update!(_scene = nil)
    return false if !defined?($game_map) || !$game_map
    map_id = ($game_map.map_id rescue nil)
    return false if !void_active_now?(map_id)
    frame = (Graphics.frame_count rescue nil)
    tick = frame ? frame.to_i : (Time.now.to_f * 10).to_i
    @void_scene_runtime_repair_ticks ||= {}
    last = integer(@void_scene_runtime_repair_ticks[map_id], -9999)
    return false if tick - last < 15
    @void_scene_runtime_repair_ticks[map_id] = tick
    return void_prepare_map_runtime!($game_map, "scene_update")
  rescue => e
    log("[void] scene runtime repair skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def void_walk_character_event(character_ref, fallback_event_id = nil)
    return character_ref if character_ref && character_ref.respond_to?(:x) && character_ref.respond_to?(:y)
    return $game_player if integer(character_ref, 0) == -1 && defined?($game_player)
    return nil if !defined?($game_map) || !$game_map || !$game_map.respond_to?(:events)
    [character_ref, fallback_event_id].each do |raw_id|
      event_id = integer(raw_id, 0)
      next if event_id <= 0
      event = ($game_map.events[event_id] rescue nil)
      return event if event
    end
    return nil
  rescue
    return nil
  end

  def void_walk_character_to!(character_ref, target_x, target_y, wait = false, skippable = false, fallback_event_id = nil)
    record_release_shim_hit("pbWalkCharacterTo", "story_transfer", "#{character_ref.inspect},#{target_x.inspect},#{target_y.inspect}") if respond_to?(:record_release_shim_hit)
    character = void_walk_character_event(character_ref, fallback_event_id)
    return true if !character
    x = integer(target_x, character.x)
    y = integer(target_y, character.y)
    return true if character.x.to_i == x && character.y.to_i == y

    commands = []
    dx = x - character.x.to_i
    dy = y - character.y.to_i
    if defined?(PBMoveRoute)
      dx.abs.times { commands << (dx > 0 ? PBMoveRoute::Right : PBMoveRoute::Left) }
      dy.abs.times { commands << (dy > 0 ? PBMoveRoute::Down : PBMoveRoute::Up) }
    end

    if commands.length > 0 && defined?(pbMoveRoute)
      pbMoveRoute(character, commands, false)
    elsif character.respond_to?(:moveto)
      character.moveto(x, y)
      return true
    end

    if wait
      limit = [commands.length * 24 + 120, 240].max
      while limit > 0
        route_forcing = character.instance_variable_get(:@move_route_forcing) rescue false
        break if character.x.to_i == x && character.y.to_i == y &&
                 (!character.respond_to?(:moving?) || !character.moving?) &&
                 !route_forcing
        if defined?(pbUpdateSceneMap)
          pbUpdateSceneMap
        elsif defined?($game_map) && $game_map && $game_map.respond_to?(:update)
          $game_map.update
        end
        Graphics.update if defined?(Graphics)
        Input.update if defined?(Input)
        limit -= 1
      end
      character.moveto(x, y) if (character.x.to_i != x || character.y.to_i != y) && character.respond_to?(:moveto) && !skippable
    end
    return true
  rescue => e
    log("[void] pbWalkCharacterTo skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def void_rival_graphic_event(target_event_id = nil, fallback_event_id = nil)
    return nil if !defined?($game_map) || !$game_map || !$game_map.respond_to?(:events)
    [target_event_id, fallback_event_id].each do |raw_id|
      event_id = integer(raw_id, 0)
      next if event_id <= 0
      event = ($game_map.events[event_id] rescue nil)
      return event if event
    end
    return nil
  rescue
    return nil
  end

  def void_rival_graphic_store
    meta = new_project_metadata(POKEMON_VOID_EXPANSION_ID) if respond_to?(:new_project_metadata)
    if meta.is_a?(Hash)
      meta["void_rival_graphics"] = {} if !meta["void_rival_graphics"].is_a?(Hash)
      return meta["void_rival_graphics"]
    end
    @void_rival_graphic_fallback ||= {}
    return @void_rival_graphic_fallback
  rescue
    @void_rival_graphic_fallback ||= {}
    return @void_rival_graphic_fallback
  end

  def void_apply_rival_graphic!(target_event_id = nil, rival_slot = nil, fallback_event_id = nil, *args)
    record_release_shim_hit("pbVoidApplyRivalGraphic", "story_transfer", "#{target_event_id.inspect},#{rival_slot.inspect}") if respond_to?(:record_release_shim_hit)
    event = void_rival_graphic_event(target_event_id, fallback_event_id)
    charset = void_rival_charset_name(rival_slot)
    store = void_rival_graphic_store
    map_id = ($game_map.map_id rescue 0)
    requested_event_id = integer(target_event_id, 0)
    live_event_id = event ? void_runtime_event_id(event).to_i : requested_event_id
    live_event_id = requested_event_id if live_event_id <= 0
    key = void_rival_graphic_store_key(map_id, live_event_id)
    store[key] ||= {}
    store[key].delete("cleared")
    store[key]["target_event_id"] = target_event_id
    store[key]["live_event_id"] = live_event_id
    store[key]["fallback_event_id"] = fallback_event_id
    store[key]["rival_slot"] = rival_slot
    store[key]["extra_args"] = Array(args).map { |arg| arg.to_s }
    store[key]["charset"] = charset
    requested_key = void_rival_graphic_store_key(map_id, requested_event_id)
    store[requested_key] = store[key] if requested_event_id > 0 && requested_key != key
    if event
      previous = event.respond_to?(:character_name) ? event.character_name : (event.instance_variable_get(:@character_name) rescue nil)
      store[key]["previous_charset"] = previous if !store[key].has_key?("previous_charset")
      void_apply_event_charset!(event, charset)
      log("[void] applied rival graphic #{charset.inspect} to event #{target_event_id.inspect}") if respond_to?(:log)
    else
      log("[void] noted rival graphic #{charset.inspect} without a live event #{target_event_id.inspect}") if respond_to?(:log)
    end
    return true
  rescue => e
    log("[void] rival graphic request skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def void_clear_rival_graphic!(target_event_id = nil, fallback_event_id = nil, *args)
    record_release_shim_hit("pbVoidClearRivalGraphic", "story_transfer", "#{target_event_id.inspect}") if respond_to?(:record_release_shim_hit)
    event = void_rival_graphic_event(target_event_id, fallback_event_id)
    store = void_rival_graphic_store
    map_id = ($game_map.map_id rescue 0)
    requested_event_id = integer(target_event_id, 0)
    live_event_id = event ? void_runtime_event_id(event).to_i : requested_event_id
    live_event_id = requested_event_id if live_event_id <= 0
    key = void_rival_graphic_store_key(map_id, live_event_id)
    data = store[key].is_a?(Hash) ? store[key] : nil
    store[key] ||= {}
    store[key]["cleared"] = true
    store[key]["target_event_id"] = target_event_id
    store[key]["live_event_id"] = live_event_id
    requested_key = void_rival_graphic_store_key(map_id, requested_event_id)
    if requested_event_id > 0 && requested_key != key
      store[requested_key] ||= {}
      store[requested_key]["cleared"] = true
      store[requested_key]["target_event_id"] = target_event_id
      store[requested_key]["live_event_id"] = live_event_id
    end
    previous = data.is_a?(Hash) ? data["previous_charset"] : nil
    if event && !previous.to_s.empty?
      void_apply_event_charset!(event, previous)
    elsif event
      event.character_name = "" if event.respond_to?(:character_name=)
      event.instance_variable_set(:@character_name, "") if event.respond_to?(:instance_variable_set)
      event.instance_variable_set(:@tile_id, 0) if event.respond_to?(:instance_variable_set)
    elsif event && event.respond_to?(:refresh)
      event.refresh
    end
    log("[void] cleared rival graphic for event #{target_event_id.inspect}") if respond_to?(:log)
    return true
  rescue => e
    log("[void] rival graphic cleanup skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end
end

Object.const_set(:WildBattle, Module.new) unless Object.const_defined?(:WildBattle, false)

class << WildBattle
  alias tef_new_projects_original_start start if method_defined?(:start) && !method_defined?(:tef_new_projects_original_start)

  def start(*args)
    if defined?(TravelExpansionFramework) &&
       TravelExpansionFramework.respond_to?(:decades_active_now?) &&
       TravelExpansionFramework.decades_active_now?
      return TravelExpansionFramework.start_decades_wild_battle(*args)
    end
    return tef_new_projects_original_start(*args) if respond_to?(:tef_new_projects_original_start, true)
    return TravelExpansionFramework.start_host_wild_battle(*args) if defined?(TravelExpansionFramework) &&
                                                                    TravelExpansionFramework.respond_to?(:start_host_wild_battle)
    return true
  rescue => e
    TravelExpansionFramework.log("[wild_battle] start skipped safely: #{e.class}: #{e.message}") if defined?(TravelExpansionFramework) &&
                                                                                                   TravelExpansionFramework.respond_to?(:log)
    return true
  end
end

if defined?(Events) && Events.respond_to?(:onWildPokemonCreate) && Events.respond_to?(:onTrainerPartyLoad) &&
   !$tef_decades_level_scaling_hooks_installed
  Events.onWildPokemonCreate += proc { |_sender, event_args|
    next if !defined?(TravelExpansionFramework) ||
            !TravelExpansionFramework.respond_to?(:decades_active_now?) ||
            !TravelExpansionFramework.decades_active_now?
    pokemon = Array(event_args)[0]
    TravelExpansionFramework.decades_scale_pokemon_object!(pokemon) if TravelExpansionFramework.respond_to?(:decades_scale_pokemon_object!)
  }

  Events.onTrainerPartyLoad += proc { |_sender, trainer|
    next if !defined?(TravelExpansionFramework) ||
            !TravelExpansionFramework.respond_to?(:decades_active_now?) ||
            !TravelExpansionFramework.decades_active_now?
    TravelExpansionFramework.decades_scale_trainer_party!(trainer) if TravelExpansionFramework.respond_to?(:decades_scale_trainer_party!)
  }

  $tef_decades_level_scaling_hooks_installed = true
end

class << Object
  alias tef_new_projects_original_const_missing const_missing unless method_defined?(:tef_new_projects_original_const_missing)

  def const_missing(name)
    if defined?(TravelExpansionFramework) &&
       TravelExpansionFramework.bare_species_constant_resolution_active? &&
       TravelExpansionFramework.respond_to?(:resolve_pb_species_constant_name)
      species = TravelExpansionFramework.resolve_pb_species_constant_name(name) rescue nil
      return const_set(name, species) if species
    end
    return tef_new_projects_original_const_missing(name) if respond_to?(:tef_new_projects_original_const_missing, true)
    raise NameError, "uninitialized constant Object::#{name}"
  end
end

def pbStartQuest(quest = nil, *args)
  return TravelExpansionFramework.new_project_start_quest!(quest, *args) if defined?(TravelExpansionFramework) &&
                                                                            TravelExpansionFramework.respond_to?(:new_project_start_quest!)
  return true
rescue
  return true
end unless defined?(pbStartQuest)

def pbCompleteQuest(quest = nil, *args)
  return TravelExpansionFramework.new_project_complete_quest!(quest, *args) if defined?(TravelExpansionFramework) &&
                                                                               TravelExpansionFramework.respond_to?(:new_project_complete_quest!)
  return true
rescue
  return true
end unless defined?(pbCompleteQuest)

def pbQuestStatus(quest = nil, *_args)
  return TravelExpansionFramework.new_project_quest_stage(quest) if defined?(TravelExpansionFramework) &&
                                                                    TravelExpansionFramework.respond_to?(:new_project_quest_stage)
  return 0
rescue
  return 0
end unless defined?(pbQuestStatus)

def pbQuestStarted?(quest = nil, *_args)
  return TravelExpansionFramework.new_project_quest_started?(quest) if defined?(TravelExpansionFramework) &&
                                                                       TravelExpansionFramework.respond_to?(:new_project_quest_started?)
  return false
rescue
  return false
end unless defined?(pbQuestStarted?)

def pbQuestComplete?(quest = nil, *_args)
  return TravelExpansionFramework.new_project_quest_completed?(quest) if defined?(TravelExpansionFramework) &&
                                                                         TravelExpansionFramework.respond_to?(:new_project_quest_completed?)
  return false
rescue
  return false
end unless defined?(pbQuestComplete?)

def pbQuestKnown?(quest = nil, *_args)
  return pbQuestStarted?(quest)
rescue
  return false
end unless defined?(pbQuestKnown?)

def pbSetRivalDialoguePortrait(rival_slot = nil, *args)
  return TravelExpansionFramework.void_set_rival_dialogue_portrait!(rival_slot, nil, *args) if defined?(TravelExpansionFramework) &&
                                                                                               TravelExpansionFramework.respond_to?(:void_set_rival_dialogue_portrait!)
  return true
rescue
  return true
end unless defined?(pbSetRivalDialoguePortrait)

def pbVoidApplyRivalGraphic(target_event_id = nil, rival_slot = nil, *args)
  return TravelExpansionFramework.void_apply_rival_graphic!(target_event_id, rival_slot, nil, *args) if defined?(TravelExpansionFramework) &&
                                                                                                       TravelExpansionFramework.respond_to?(:void_apply_rival_graphic!)
  return true
rescue
  return true
end unless defined?(pbVoidApplyRivalGraphic)

def pbVoidClearRivalGraphic(target_event_id = nil, *args)
  return TravelExpansionFramework.void_clear_rival_graphic!(target_event_id, nil, *args) if defined?(TravelExpansionFramework) &&
                                                                                           TravelExpansionFramework.respond_to?(:void_clear_rival_graphic!)
  return true
rescue
  return true
end unless defined?(pbVoidClearRivalGraphic)

def pbWalkCharacterTo(character_ref, target_x, target_y, wait = false, skippable = false)
  return TravelExpansionFramework.void_walk_character_to!(character_ref, target_x, target_y, wait, skippable, nil) if defined?(TravelExpansionFramework) &&
                                                                                                                      TravelExpansionFramework.respond_to?(:void_walk_character_to!)
  return true
rescue
  return true
end unless defined?(pbWalkCharacterTo)

if defined?(pbSetPokemonCenter) && !defined?(tef_new_projects_original_pbSetPokemonCenter)
  alias tef_new_projects_original_pbSetPokemonCenter pbSetPokemonCenter
end

def pbSetPokemonCenter(*args)
  TravelExpansionFramework.ensure_stats_proxy! if defined?(TravelExpansionFramework) &&
                                                  TravelExpansionFramework.respond_to?(:ensure_stats_proxy!)
  return send(:tef_new_projects_original_pbSetPokemonCenter, *args) if respond_to?(:tef_new_projects_original_pbSetPokemonCenter, true)
  return true
end

if defined?(pbChangePlayer) && !defined?(tef_new_projects_original_pbChangePlayer)
  alias tef_new_projects_original_pbChangePlayer pbChangePlayer
end

def pbChangePlayer(id, *args)
  if TravelExpansionFramework.new_project_identity_active_now?
    TravelExpansionFramework.apply_new_project_gender_selection!
    expansion = TravelExpansionFramework.current_new_project_expansion_id || "new_project"
    if expansion.to_s == TravelExpansionFramework::INFINITY_EXPANSION_ID && TravelExpansionFramework.respond_to?(:infinity_restore_host_player_visuals!)
      TravelExpansionFramework.infinity_restore_host_player_visuals!("pbChangePlayer")
    else
      TravelExpansionFramework.apply_host_player_visuals!(expansion)
    end
    TravelExpansionFramework.empyrean_log_once(:change_player, "[travel] ignored expansion intro pbChangePlayer(#{id.inspect}) to preserve host player identity")
    return true
  end
  return send(:tef_new_projects_original_pbChangePlayer, id, *args) if respond_to?(:tef_new_projects_original_pbChangePlayer, true)
  return false
end

if defined?(pbTrainerName) && !defined?(tef_new_projects_original_pbTrainerName)
  alias tef_new_projects_original_pbTrainerName pbTrainerName
end

def pbTrainerName(name = nil, outfit = 0)
  if TravelExpansionFramework.new_project_identity_active_now?
    chosen_name = TravelExpansionFramework.host_player_name_for_expansion
    meta = TravelExpansionFramework.new_project_metadata || TravelExpansionFramework.empyrean_metadata
    meta["intro_requested_name"] = name.to_s if meta && !name.nil?
    meta["intro_name"] = chosen_name if meta
    $PokemonTemp.begunNewGame = true if defined?($PokemonTemp) && $PokemonTemp && $PokemonTemp.respond_to?(:begunNewGame=)
    TravelExpansionFramework.empyrean_log_once(:trainer_name, "[travel] expansion intro trainer name reused host name #{chosen_name.inspect}")
    return chosen_name
  end
  return send(:tef_new_projects_original_pbTrainerName, name, outfit) if respond_to?(:tef_new_projects_original_pbTrainerName, true)
  return name.to_s
end

if defined?(pbAddDependency) && !defined?(tef_new_projects_original_pbAddDependency)
  alias tef_new_projects_original_pbAddDependency pbAddDependency
end

def pbAddDependency(event_id, event_name = "Dependent", common_event = nil, *args)
  if TravelExpansionFramework.new_project_active_now?
    return true if TravelExpansionFramework.new_project_follow_event(event_id, event_name, false)
  end
  if respond_to?(:tef_new_projects_original_pbAddDependency, true)
    return send(:tef_new_projects_original_pbAddDependency, event_id, event_name, common_event, *args)
  end
  return false
end

if defined?(pbPokemonFollow) && !defined?(tef_new_projects_original_pbPokemonFollow)
  alias tef_new_projects_original_pbPokemonFollow pbPokemonFollow
end

def pbPokemonFollow(event_id, event_name = "Dependent")
  if TravelExpansionFramework.new_project_active_now?
    return true if TravelExpansionFramework.new_project_follow_event(event_id, event_name, true)
  end
  if respond_to?(:tef_new_projects_original_pbPokemonFollow, true)
    return send(:tef_new_projects_original_pbPokemonFollow, event_id, event_name)
  end
  return false
end

if defined?(pbFancyMoveTo) && !defined?(tef_new_projects_original_pbFancyMoveTo)
  alias tef_new_projects_original_pbFancyMoveTo pbFancyMoveTo
end

def pbFancyMoveTo(follower, newX, newY, leader = :__tef_missing__)
  if leader == :__tef_missing__ && TravelExpansionFramework.new_project_active_now?
    leader = ($game_player rescue nil) || follower
    TravelExpansionFramework.log("[travel] bridged 3-arg pbFancyMoveTo for #{TravelExpansionFramework.current_new_project_expansion_id}") if TravelExpansionFramework.respond_to?(:log)
  end
  if respond_to?(:tef_new_projects_original_pbFancyMoveTo, true)
    return send(:tef_new_projects_original_pbFancyMoveTo, follower, newX, newY, leader)
  end
  return false
end

if defined?(FollowingMoveRoute) && !defined?(tef_new_projects_original_FollowingMoveRoute)
  alias tef_new_projects_original_FollowingMoveRoute FollowingMoveRoute
end

def FollowingMoveRoute(commands, waitComplete = false)
  if TravelExpansionFramework.new_project_active_now?
    route = TravelExpansionFramework.new_project_following_move_route(commands, waitComplete)
    return route if route
  end
  if respond_to?(:tef_new_projects_original_FollowingMoveRoute, true)
    return send(:tef_new_projects_original_FollowingMoveRoute, commands, waitComplete)
  end
  return nil
end

if defined?(pbGetDependency) && !defined?(tef_new_projects_original_pbGetDependency)
  alias tef_new_projects_original_pbGetDependency pbGetDependency
end

def pbGetDependency(eventName)
  existing = nil
  existing = send(:tef_new_projects_original_pbGetDependency, eventName) if respond_to?(:tef_new_projects_original_pbGetDependency, true)
  return existing if existing
  if TravelExpansionFramework.new_project_active_now?
    event = TravelExpansionFramework.new_project_primary_dependent_event(eventName)
    event ||= TravelExpansionFramework.new_project_primary_dependent_event("Dependent")
    event ||= TravelExpansionFramework.new_project_primary_dependent_event
    return event if event
  end
  return existing
rescue
  return nil
end

if defined?(_INTL) && !defined?(tef_new_projects_original__INTL)
  alias tef_new_projects_original__INTL _INTL
end

if defined?(_MAPINTL) && !defined?(tef_new_projects_original__MAPINTL)
  alias tef_new_projects_original__MAPINTL _MAPINTL
end

if defined?(pbAddPokemon) && !defined?(tef_new_projects_original_pbAddPokemon)
  alias tef_new_projects_original_pbAddPokemon pbAddPokemon
end

def pbAddPokemon(pkmn, level = 1, see_form = true, dontRandomize = false, variableToSave = nil)
  pkmn = TravelExpansionFramework.resolve_new_project_gift_species_ref(pkmn) if TravelExpansionFramework.respond_to?(:resolve_new_project_gift_species_ref)
  if TravelExpansionFramework.respond_to?(:bank_new_project_gift_pokemon_if_needed!)
    handled = TravelExpansionFramework.bank_new_project_gift_pokemon_if_needed!(pkmn, level, see_form, dontRandomize, variableToSave, "pbAddPokemon")
    return handled if !handled.nil?
  end
  result = tef_new_projects_original_pbAddPokemon(pkmn, level, see_form, dontRandomize, variableToSave)
  TravelExpansionFramework.save_new_project_party_session!(nil, "pbAddPokemon") if TravelExpansionFramework.respond_to?(:save_new_project_party_session!)
  return result
end

if defined?(pbAddPokemonSilent) && !defined?(tef_new_projects_original_pbAddPokemonSilent)
  alias tef_new_projects_original_pbAddPokemonSilent pbAddPokemonSilent
end

def pbAddPokemonSilent(pkmn, level = 1, see_form = true)
  pkmn = TravelExpansionFramework.resolve_new_project_gift_species_ref(pkmn) if TravelExpansionFramework.respond_to?(:resolve_new_project_gift_species_ref)
  if TravelExpansionFramework.respond_to?(:bank_new_project_gift_pokemon_if_needed!)
    handled = TravelExpansionFramework.bank_new_project_gift_pokemon_if_needed!(pkmn, level, see_form, false, nil, "pbAddPokemonSilent")
    return handled if !handled.nil?
  end
  result = tef_new_projects_original_pbAddPokemonSilent(pkmn, level, see_form)
  TravelExpansionFramework.save_new_project_party_session!(nil, "pbAddPokemonSilent") if TravelExpansionFramework.respond_to?(:save_new_project_party_session!)
  return result
end

if defined?(pbAddToParty) && !defined?(tef_new_projects_original_pbAddToParty)
  alias tef_new_projects_original_pbAddToParty pbAddToParty
end

def pbAddToParty(pkmn, level = 1, see_form = true, dontRandomize = false)
  pkmn = TravelExpansionFramework.resolve_new_project_gift_species_ref(pkmn) if TravelExpansionFramework.respond_to?(:resolve_new_project_gift_species_ref)
  if TravelExpansionFramework.respond_to?(:bank_new_project_gift_pokemon_if_needed!)
    handled = TravelExpansionFramework.bank_new_project_gift_pokemon_if_needed!(pkmn, level, see_form, dontRandomize, nil, "pbAddToParty")
    return handled if !handled.nil?
  end
  result = tef_new_projects_original_pbAddToParty(pkmn, level, see_form, dontRandomize)
  TravelExpansionFramework.save_new_project_party_session!(nil, "pbAddToParty") if TravelExpansionFramework.respond_to?(:save_new_project_party_session!)
  return result
end

if defined?(pbAddToPartySilent) && !defined?(tef_new_projects_original_pbAddToPartySilent)
  alias tef_new_projects_original_pbAddToPartySilent pbAddToPartySilent
end

def pbAddToPartySilent(pkmn, level = nil, see_form = true)
  pkmn = TravelExpansionFramework.resolve_new_project_gift_species_ref(pkmn) if TravelExpansionFramework.respond_to?(:resolve_new_project_gift_species_ref)
  if TravelExpansionFramework.respond_to?(:bank_new_project_gift_pokemon_if_needed!)
    handled = TravelExpansionFramework.bank_new_project_gift_pokemon_if_needed!(pkmn, level || 1, see_form, false, nil, "pbAddToPartySilent")
    return handled if !handled.nil?
  end
  result = tef_new_projects_original_pbAddToPartySilent(pkmn, level, see_form)
  TravelExpansionFramework.save_new_project_party_session!(nil, "pbAddToPartySilent") if TravelExpansionFramework.respond_to?(:save_new_project_party_session!)
  return result
end

if defined?(Player)
  class Player
    alias tef_new_projects_original_last_party last_party unless method_defined?(:tef_new_projects_original_last_party)

    def last_party
      if defined?(TravelExpansionFramework) && TravelExpansionFramework.respond_to?(:current_new_project_banked_gift_pokemon)
        gift = TravelExpansionFramework.current_new_project_banked_gift_pokemon
        return gift if gift
      end
      return tef_new_projects_original_last_party
    end
  end
end

if defined?(Trainer)
  class Trainer
    alias tef_new_projects_original_last_party last_party unless method_defined?(:tef_new_projects_original_last_party)

    def last_party
      if defined?(TravelExpansionFramework) && TravelExpansionFramework.respond_to?(:current_new_project_banked_gift_pokemon)
        gift = TravelExpansionFramework.current_new_project_banked_gift_pokemon
        return gift if gift
      end
      return tef_new_projects_original_last_party
    end
  end
end

def _INTL(*arg)
  if TravelExpansionFramework.new_project_active_now?
    template = TravelExpansionFramework.prepare_new_project_text(arg[0].to_s, ($game_map.map_id rescue nil))
    return TravelExpansionFramework.format_translation_text(template, arg[1..-1])
  end
  return send(:tef_new_projects_original__INTL, *arg) if respond_to?(:tef_new_projects_original__INTL, true)
  return TravelExpansionFramework.format_translation_text(arg[0].to_s, arg[1..-1])
end

def _MAPINTL(mapid, *arg)
  source = arg[0].to_s
  translated = nil
  if respond_to?(:tef_new_projects_original__MAPINTL, true)
    translated = send(:tef_new_projects_original__MAPINTL, mapid, *arg)
  end
  imported_local_map = TravelExpansionFramework.new_project_active_now? &&
                       TravelExpansionFramework.integer(mapid, 0) > 0 &&
                       TravelExpansionFramework.integer(mapid, 0) < 1000
  if imported_local_map || TravelExpansionFramework.new_project_active_now?(mapid)
    if !source.empty? && (translated.nil? || TravelExpansionFramework.imported_message_text_blank?(translated))
      translated = TravelExpansionFramework.format_translation_text(source, arg[1..-1])
    end
    return TravelExpansionFramework.prepare_new_project_text(translated.to_s, mapid)
  end
  return translated if !translated.nil?
  return TravelExpansionFramework.format_translation_text(source, arg[1..-1])
rescue
  return TravelExpansionFramework.format_translation_text(source, arg[1..-1]) rescue source
end

if defined?(pbCreateMessageWindow) && !defined?(tef_new_projects_original_pbCreateMessageWindow)
  alias tef_new_projects_original_pbCreateMessageWindow pbCreateMessageWindow
end

def pbCreateMessageWindow(viewport = nil, skin = nil)
  map_id = ($game_map.map_id rescue nil)
  void_message = TravelExpansionFramework.respond_to?(:void_active_now?) &&
                 TravelExpansionFramework.void_active_now?(map_id)
  if void_message && skin.nil? && TravelExpansionFramework.respond_to?(:void_host_speech_frame)
    skin = TravelExpansionFramework.void_host_speech_frame
  end
  msgwindow = tef_new_projects_original_pbCreateMessageWindow(viewport, skin)
  if void_message
    TravelExpansionFramework.reset_void_message_state! if TravelExpansionFramework.respond_to?(:reset_void_message_state!)
    TravelExpansionFramework.normalize_void_message_window!(msgwindow) if TravelExpansionFramework.respond_to?(:normalize_void_message_window!)
  end
  return msgwindow
end

if defined?(pbDisposeMessageWindow) && !defined?(tef_new_projects_original_pbDisposeMessageWindow)
  alias tef_new_projects_original_pbDisposeMessageWindow pbDisposeMessageWindow
end

def pbDisposeMessageWindow(msgwindow)
  TravelExpansionFramework.dispose_void_textbox_backdrop!(msgwindow) if defined?(TravelExpansionFramework) &&
                                                                        TravelExpansionFramework.respond_to?(:dispose_void_textbox_backdrop!)
  return tef_new_projects_original_pbDisposeMessageWindow(msgwindow)
end

if defined?(pbMessage) && !defined?(tef_new_projects_original_pbMessage)
  alias tef_new_projects_original_pbMessage pbMessage
end

def pbMessage(message, commands = nil, cmdIfCancel = 0, skin = nil, defaultCmd = 0, &block)
  TravelExpansionFramework.ensure_player_global! if TravelExpansionFramework.new_project_identity_active_now?
  if TravelExpansionFramework.new_project_active_now?
    map_id = ($game_map.map_id rescue nil)
    message = TravelExpansionFramework.prepare_new_project_text(message, map_id)
    commands = TravelExpansionFramework.prepare_new_project_commands(commands, map_id) if commands
  end
  if commands && TravelExpansionFramework.new_project_active_now?
    auto_choice = TravelExpansionFramework.new_project_auto_choice_index(message, commands, ($game_map.map_id rescue nil), nil)
    if !auto_choice.nil?
      TravelExpansionFramework.log("[travel] auto-selected intro choice #{auto_choice} for #{Array(commands).inspect}") if TravelExpansionFramework.respond_to?(:log)
      return auto_choice
    end
  end
  return tef_new_projects_original_pbMessage(message, commands, cmdIfCancel, skin, defaultCmd, &block)
end

if defined?(pbMessageDisplay) && !defined?(tef_new_projects_original_pbMessageDisplay)
  alias tef_new_projects_original_pbMessageDisplay pbMessageDisplay
end

def pbMessageDisplay(msgwindow, message, letterbyletter = true, commandProc = nil, withSound = true, &block)
  void_message = false
  if TravelExpansionFramework.new_project_active_now?
    map_id = ($game_map.map_id rescue nil)
    void_message = TravelExpansionFramework.respond_to?(:void_active_now?) &&
                   TravelExpansionFramework.void_active_now?(map_id)
    message = TravelExpansionFramework.prepare_new_project_text(message, map_id)
    if void_message
      TravelExpansionFramework.reset_void_message_state! if TravelExpansionFramework.respond_to?(:reset_void_message_state!)
      TravelExpansionFramework.normalize_void_message_window!(msgwindow) if TravelExpansionFramework.respond_to?(:normalize_void_message_window!)
      letterbyletter = true
    end
  end
  ret = nil
  begin
    ret = tef_new_projects_original_pbMessageDisplay(msgwindow, message, letterbyletter, commandProc, withSound, &block)
  ensure
    if void_message && defined?(TravelExpansionFramework) &&
       TravelExpansionFramework.respond_to?(:dispose_void_textbox_backdrop!)
      TravelExpansionFramework.dispose_void_textbox_backdrop!(msgwindow)
    end
  end
  return ret
end

if defined?(pbMessageChooseNumber) && !defined?(tef_new_projects_original_pbMessageChooseNumber)
  alias tef_new_projects_original_pbMessageChooseNumber pbMessageChooseNumber
end

def pbMessageChooseNumber(message, params, &block)
  message = TravelExpansionFramework.prepare_new_project_text(message, ($game_map.map_id rescue nil)) if TravelExpansionFramework.new_project_active_now?
  return tef_new_projects_original_pbMessageChooseNumber(message, params, &block)
end

if defined?(pbMessageFreeText) && !defined?(tef_new_projects_original_pbMessageFreeText)
  alias tef_new_projects_original_pbMessageFreeText pbMessageFreeText
end

def pbMessageFreeText(message, currenttext, passwordbox, maxlength, width = 240, &block)
  if TravelExpansionFramework.new_project_identity_active_now?
    if message.to_s[/rival/i]
      return TravelExpansionFramework.expansion_rival_name
    end
    if message.to_s[/what do you wish to be called|tell me.*name|what is your name|call sign|nombre|llam/i]
      return TravelExpansionFramework.host_player_name_for_expansion
    end
  elsif TravelExpansionFramework.empyrean_active_now? && message.to_s[/what do you wish to be called/i]
    return TravelExpansionFramework.host_player_name_for_expansion
  end
  message = TravelExpansionFramework.prepare_new_project_text(message, ($game_map.map_id rescue nil)) if TravelExpansionFramework.new_project_active_now?
  return tef_new_projects_original_pbMessageFreeText(message, currenttext, passwordbox, maxlength, width, &block)
end

if defined?(pbShowCommands) && !defined?(tef_new_projects_original_pbShowCommands)
  alias tef_new_projects_original_pbShowCommands pbShowCommands
end

def pbShowCommands(msgwindow, commands = nil, cmdIfCancel = 0, defaultCmd = 0, x_offset = nil, y_offset = nil, &block)
  commands = TravelExpansionFramework.prepare_new_project_commands(commands, ($game_map.map_id rescue nil)) if TravelExpansionFramework.new_project_active_now? && commands
  if commands && TravelExpansionFramework.new_project_active_now?
    auto_choice = TravelExpansionFramework.new_project_auto_choice_index(nil, commands, ($game_map.map_id rescue nil), nil)
    if !auto_choice.nil?
      TravelExpansionFramework.log("[travel] auto-selected command list choice #{auto_choice} for #{Array(commands).inspect}") if TravelExpansionFramework.respond_to?(:log)
      return auto_choice
    end
  end
  return TravelExpansionFramework.pb_show_commands_compatible(
    self,
    :tef_new_projects_original_pbShowCommands,
    msgwindow,
    commands,
    cmdIfCancel,
    defaultCmd,
    x_offset,
    y_offset,
    &block
  )
end

if defined?(pbShowCommandsWithHelp) && !defined?(tef_new_projects_original_pbShowCommandsWithHelp)
  alias tef_new_projects_original_pbShowCommandsWithHelp pbShowCommandsWithHelp
end

def pbShowCommandsWithHelp(msgwindow, commands, help, cmdIfCancel = 0, defaultCmd = 0)
  if TravelExpansionFramework.new_project_active_now?
    map_id = ($game_map.map_id rescue nil)
    commands = TravelExpansionFramework.prepare_new_project_commands(commands, map_id)
    help = TravelExpansionFramework.prepare_new_project_commands(help, map_id)
  end
  return tef_new_projects_original_pbShowCommandsWithHelp(msgwindow, commands, help, cmdIfCancel, defaultCmd)
end

unless defined?(AnimatedText)
  class AnimatedText
    def initialize(text, *_args)
      @text = text.to_s
      @shown = false
    end

    def start
      return true if @shown
      @shown = true
      pbMessage(@text) if TravelExpansionFramework.new_project_identity_active_now? && !@text.empty?
      return true
    end

    def update
      return true
    end

    def dispose
      @shown = true
      return true
    end
  end
end

unless defined?(GenderSelection)
  class GenderSelection
    def initialize(_text = nil)
      TravelExpansionFramework.apply_new_project_gender_selection! if TravelExpansionFramework.new_project_identity_active_now?
      $genderSelection = self if defined?($genderSelection)
    end

    def restart
      TravelExpansionFramework.apply_new_project_gender_selection! if TravelExpansionFramework.new_project_identity_active_now?
      return true
    end

    def start
      return true
    end

    def end
      dispose
    end

    def dispose
      $genderSelection = nil if defined?($genderSelection)
      return true
    end
  end
end

unless defined?(PokemonGenderSelection)
  class PokemonGenderSelection
    attr_reader :selected_gender

    def initialize(*_args)
      @selected_gender = TravelExpansionFramework.apply_new_project_gender_selection!
      TravelExpansionFramework.apply_host_player_visuals!(TravelExpansionFramework.current_new_project_expansion_id || "new_project")
      @close = 1
    end

    def input
      return true
    end

    def main_method
      return true
    end

    def continue
      return true
    end

    def dispose
      return true
    end
  end
end

if defined?(Interpreter) && defined?(PokemonGenderSelection)
  class Interpreter
    PokemonGenderSelection = ::PokemonGenderSelection unless const_defined?(:PokemonGenderSelection)
  end
end

unless defined?(SkintoneSelection)
  class SkintoneSelection
    def initialize(_text = nil)
      TravelExpansionFramework.new_project_apply_skin_selection!(0) if TravelExpansionFramework.new_project_identity_active_now?
      $skinSelection = self if defined?($skinSelection)
    end

    def restart
      TravelExpansionFramework.new_project_apply_skin_selection!(0) if TravelExpansionFramework.new_project_identity_active_now?
      return true
    end

    def start
      return true
    end

    def end
      dispose
    end

    def dispose
      $skinSelection = nil if defined?($skinSelection)
      return true
    end
  end
end

unless defined?(DiegoWTsStarterSelection)
  class DiegoWTsStarterSelection
    attr_reader :selected_species

    def initialize(*species)
      @selected_species = TravelExpansionFramework.hollow_woods_choose_starter!(*species) if defined?(TravelExpansionFramework) &&
                                                                                             TravelExpansionFramework.respond_to?(:hollow_woods_choose_starter!)
    end
  end
end

if defined?(Interpreter) && defined?(DiegoWTsStarterSelection)
  class Interpreter
    DiegoWTsStarterSelection = ::DiegoWTsStarterSelection unless const_defined?(:DiegoWTsStarterSelection)
  end
end

class Interpreter
  Followers = ::Followers if defined?(::Followers) && !const_defined?(:Followers)
  TrashCans = ::TrashCans if defined?(::TrashCans) && !const_defined?(:TrashCans)
  AutomaticLevelScaling = ::AutomaticLevelScaling if defined?(::AutomaticLevelScaling) && !const_defined?(:AutomaticLevelScaling)
  WildBattle = ::WildBattle if defined?(::WildBattle) && !const_defined?(:WildBattle)
  GameMode_Scene = ::GameMode_Scene if defined?(::GameMode_Scene) && !const_defined?(:GameMode_Scene)
  GameModeScreen = ::GameModeScreen if defined?(::GameModeScreen) && !const_defined?(:GameModeScreen)

  def pbStartQuest(quest = nil, *args)
    return TravelExpansionFramework.new_project_start_quest!(quest, *args) if defined?(TravelExpansionFramework) &&
                                                                              TravelExpansionFramework.respond_to?(:new_project_start_quest!)
    return true
  rescue
    return true
  end unless method_defined?(:pbStartQuest)

  def pbCompleteQuest(quest = nil, *args)
    return TravelExpansionFramework.new_project_complete_quest!(quest, *args) if defined?(TravelExpansionFramework) &&
                                                                                 TravelExpansionFramework.respond_to?(:new_project_complete_quest!)
    return true
  rescue
    return true
  end unless method_defined?(:pbCompleteQuest)

  def pbQuestStatus(quest = nil, *_args)
    return TravelExpansionFramework.new_project_quest_stage(quest) if defined?(TravelExpansionFramework) &&
                                                                      TravelExpansionFramework.respond_to?(:new_project_quest_stage)
    return 0
  rescue
    return 0
  end unless method_defined?(:pbQuestStatus)

  def pbQuestStarted?(quest = nil, *_args)
    return TravelExpansionFramework.new_project_quest_started?(quest) if defined?(TravelExpansionFramework) &&
                                                                         TravelExpansionFramework.respond_to?(:new_project_quest_started?)
    return false
  rescue
    return false
  end unless method_defined?(:pbQuestStarted?)

  def pbQuestComplete?(quest = nil, *_args)
    return TravelExpansionFramework.new_project_quest_completed?(quest) if defined?(TravelExpansionFramework) &&
                                                                           TravelExpansionFramework.respond_to?(:new_project_quest_completed?)
    return false
  rescue
    return false
  end unless method_defined?(:pbQuestComplete?)

  def pbQuestKnown?(quest = nil, *_args)
    return pbQuestStarted?(quest)
  rescue
    return false
  end unless method_defined?(:pbQuestKnown?)

  def pbSetRivalDialoguePortrait(rival_slot = nil, *args)
    return TravelExpansionFramework.void_set_rival_dialogue_portrait!(rival_slot, @event_id, *args) if defined?(TravelExpansionFramework) &&
                                                                                                       TravelExpansionFramework.respond_to?(:void_set_rival_dialogue_portrait!)
    return true
  rescue
    return true
  end unless method_defined?(:pbSetRivalDialoguePortrait)

  def pbVoidApplyRivalGraphic(target_event_id = nil, rival_slot = nil, *args)
    return TravelExpansionFramework.void_apply_rival_graphic!(target_event_id, rival_slot, @event_id, *args) if defined?(TravelExpansionFramework) &&
                                                                                                                TravelExpansionFramework.respond_to?(:void_apply_rival_graphic!)
    return true
  rescue
    return true
  end unless method_defined?(:pbVoidApplyRivalGraphic)

  def pbVoidClearRivalGraphic(target_event_id = nil, *args)
    return TravelExpansionFramework.void_clear_rival_graphic!(target_event_id, @event_id, *args) if defined?(TravelExpansionFramework) &&
                                                                                                   TravelExpansionFramework.respond_to?(:void_clear_rival_graphic!)
    return true
  rescue
    return true
  end unless method_defined?(:pbVoidClearRivalGraphic)

  def pbWalkCharacterTo(character_ref, target_x, target_y, wait = false, skippable = false)
    return TravelExpansionFramework.void_walk_character_to!(character_ref, target_x, target_y, wait, skippable, @event_id) if defined?(TravelExpansionFramework) &&
                                                                                                                              TravelExpansionFramework.respond_to?(:void_walk_character_to!)
    return true
  rescue
    return true
  end unless method_defined?(:pbWalkCharacterTo)

  alias tef_new_projects_original_command_102 command_102 unless method_defined?(:tef_new_projects_original_command_102)
  alias tef_new_projects_original_command_111 command_111 unless method_defined?(:tef_new_projects_original_command_111)
  alias tef_new_projects_original_command_121 command_121 if method_defined?(:command_121) &&
                                                             !method_defined?(:tef_new_projects_original_command_121)
  alias tef_new_projects_original_command_223 command_223 if method_defined?(:command_223) &&
                                                             !method_defined?(:tef_new_projects_original_command_223)
  alias tef_new_projects_original_execute_script execute_script unless method_defined?(:tef_new_projects_original_execute_script)

  def tef_new_projects_previous_message
    index = @index.to_i - 1
    while index >= 0
      command = @list[index] rescue nil
      break if !command
      code = command.code rescue command.instance_variable_get(:@code)
      params = command.parameters rescue command.instance_variable_get(:@parameters)
      return Array(params)[0].to_s if [101, 401].include?(code)
      index -= 1
    end
    return nil
  rescue
    return nil
  end

  def command_102
    @branch ||= {}
    map_id = (@map_id rescue ($game_map.map_id rescue nil))
    if TravelExpansionFramework.new_project_active_now?(map_id)
      TravelExpansionFramework.ensure_player_global! if TravelExpansionFramework.respond_to?(:ensure_player_global!)
      command_record = (@list[@index] rescue nil)
      params = command_record.parameters rescue (command_record.instance_variable_get(:@parameters) rescue nil)
      commands = Array(params)[0]
      cmd_if_cancel = Array(params)[1] || 0
      indent = command_record.indent rescue (command_record.instance_variable_get(:@indent) rescue 0)
      commands = TravelExpansionFramework.prepare_new_project_commands(commands, map_id) if commands &&
                                                                                            TravelExpansionFramework.respond_to?(:prepare_new_project_commands)
      selected = TravelExpansionFramework.new_project_auto_choice_index(
        tef_new_projects_previous_message,
        commands,
        map_id,
        (@event_id rescue nil)
      )
      auto_selected = !selected.nil?
      if selected.nil?
        if Array(commands).empty?
          selected = cmd_if_cancel.to_i rescue 0
        else
          @message_waiting = true
          selected = pbShowCommands(nil, commands, cmd_if_cancel)
        end
      end
      @message_waiting = false
      @branch[indent] = selected
      Input.update rescue nil
      if auto_selected
        TravelExpansionFramework.log("[travel] auto-selected command_102 choice #{selected} for #{Array(commands).inspect}") if TravelExpansionFramework.respond_to?(:log)
      end
      return true
    end
    return tef_new_projects_original_command_102
  rescue NoMethodError => e
    if e.message.to_s[/undefined method `\[\]'|undefined method \[\]/]
      begin
        @branch ||= {}
        command_record = (@list[@index] rescue nil)
        indent = command_record.indent rescue (command_record.instance_variable_get(:@indent) rescue 0)
        @message_waiting = false
        @branch[indent] = 0
        Input.update rescue nil
        TravelExpansionFramework.log("[travel] recovered command_102 from missing branch/list on imported map: #{e.message}") if TravelExpansionFramework.respond_to?(:log)
        return true
      end
    end
    raise
  end

  def command_111
    params = @parameters rescue nil
    params = @list[@index].parameters rescue params
    if defined?(TravelExpansionFramework) &&
       TravelExpansionFramework.respond_to?(:decades_speedup_punishment_branch?) &&
       TravelExpansionFramework.decades_speedup_punishment_branch?(
         params,
         (@map_id rescue ($game_map.map_id rescue nil)),
         (@event_id rescue nil)
       )
      TravelExpansionFramework.decades_clear_speedup_punishment!(:conditional_branch)
    end
    return tef_new_projects_original_command_111
  end

  def command_121
    params = @parameters rescue nil
    params = @list[@index].parameters rescue params
    result = tef_new_projects_original_command_121
    if defined?(TravelExpansionFramework) &&
       TravelExpansionFramework.respond_to?(:decades_speedup_punishment_assignment?) &&
       TravelExpansionFramework.decades_speedup_punishment_assignment?(
         params,
         (@map_id rescue ($game_map.map_id rescue nil))
       )
      TravelExpansionFramework.decades_clear_speedup_punishment!(:switch_assignment)
    end
    return result
  end if method_defined?(:tef_new_projects_original_command_121)

  def command_223
    params = @parameters rescue nil
    params = @list[@index].parameters rescue params
    tone = Array(params)[0]
    if defined?(TravelExpansionFramework) &&
       TravelExpansionFramework.respond_to?(:gadir_deluxe_intro_dark_tone_command?) &&
       TravelExpansionFramework.gadir_deluxe_intro_dark_tone_command?(
         tone,
         (@event_id rescue nil),
         (@map_id rescue ($game_map.map_id rescue nil))
       )
      TravelExpansionFramework.gadir_deluxe_recover_intro_dark_tone!(
        (@event_id rescue nil),
        (@map_id rescue ($game_map.map_id rescue nil))
      )
      return true
    end
    return tef_new_projects_original_command_223 if respond_to?(:tef_new_projects_original_command_223, true)
    return true
  end

  def execute_script(script)
    if TravelExpansionFramework.new_project_identity_active_now?((@map_id rescue nil))
      TravelExpansionFramework.ensure_player_global!
      TravelExpansionFramework.ensure_stats_proxy! if TravelExpansionFramework.respond_to?(:ensure_stats_proxy!)
    end
    prepared_script = script
    if TravelExpansionFramework.respond_to?(:decades_prepare_event_script)
      prepared_script = TravelExpansionFramework.decades_prepare_event_script(
        prepared_script,
        (@map_id rescue nil),
        (@event_id rescue nil)
      )
    end
    return tef_new_projects_original_execute_script(prepared_script)
  end

  def activar(event, swtch = "A", value = true)
    map_id = @map_id if instance_variable_defined?(:@map_id)
    map_id = ($game_map.map_id rescue 0) if map_id.nil? || map_id.to_i <= 0
    switch_name = swtch.nil? ? "A" : swtch.to_s
    switch_name = "A" if switch_name.empty?
    $game_self_switches[[map_id, event, switch_name]] = value if defined?($game_self_switches) && $game_self_switches
    $game_map.need_refresh = true if defined?($game_map) && $game_map
    return true
  end

  def Activar(event, swtch = "A", value = true)
    return activar(event, swtch, value)
  end

  def pbUpdateMax(level)
    return TravelExpansionFramework.set_expansion_level_cap(level)
  end

  def gif(numero, carpeta)
    return TravelExpansionFramework.realidea_gif(numero, carpeta, "0.13s", 255, 0, 0, 0)
  end

  def talismannormal(numero, carpeta)
    return TravelExpansionFramework.realidea_gif(numero, carpeta, "0.2s", 255, 0, -10, 0)
  end

  def talismanotro(numero, carpeta)
    return TravelExpansionFramework.realidea_gif(numero, carpeta, "0.08s", 255, 0, -10, 0)
  end

  def gifdisco(numero, carpeta)
    return TravelExpansionFramework.realidea_gif(numero, carpeta, "0.04s", 70, 1, 0, 0)
  end

  def gifhayahablando
    return TravelExpansionFramework.realidea_haya_picture("hablando")
  end

  def gifhayaparpadeando
    return TravelExpansionFramework.realidea_haya_picture("parpadeando")
  end

  def skipToHour(hour)
    meta = TravelExpansionFramework.new_project_metadata
    meta["requested_skip_hour"] = hour if meta
    return true
  end

  def weather(type = :None, power = 0, duration = 0)
    $game_screen.weather(type, power, duration) if defined?($game_screen) && $game_screen && $game_screen.respond_to?(:weather)
    return true
  rescue
    return true
  end

  def pbPCSettings(*args)
    if defined?(TravelExpansionFramework) &&
       TravelExpansionFramework.respond_to?(:hollow_woods_apply_game_mode_defaults!)
      TravelExpansionFramework.hollow_woods_apply_game_mode_defaults!(:interpreter_pc_settings)
    end
    scene = ::GameMode_Scene.new if defined?(::GameMode_Scene)
    screen = ::GameModeScreen.new(scene) if defined?(::GameModeScreen)
    screen.pbStartScreen(*args) if screen && screen.respond_to?(:pbStartScreen)
    pbUpdateSceneMap if respond_to?(:pbUpdateSceneMap)
    return true
  rescue => e
    TravelExpansionFramework.log("[hollow_woods] interpreter pc settings skipped safely: #{e.class}: #{e.message}") if defined?(TravelExpansionFramework) &&
                                                                                                                       TravelExpansionFramework.respond_to?(:log)
    return true
  end

  def pbWatchTV(*args)
    if defined?(TravelExpansionFramework)
      return TravelExpansionFramework.watch_imported_tv!(*args) if TravelExpansionFramework.respond_to?(:imported_tv_event?) &&
                                                                   TravelExpansionFramework.imported_tv_event?(nil, @event_id)
      return TravelExpansionFramework.hollow_woods_watch_tv!(*args) if TravelExpansionFramework.respond_to?(:hollow_woods_active_now?) &&
                                                                       TravelExpansionFramework.hollow_woods_active_now? &&
                                                                       TravelExpansionFramework.respond_to?(:hollow_woods_watch_tv!)
    end
    return true
  end

  def pbCheckRoaming(*args)
    return TravelExpansionFramework.infinity_check_roaming!(@event_id, *args) if defined?(TravelExpansionFramework) &&
                                                                                TravelExpansionFramework.respond_to?(:infinity_check_roaming!)
    return false
  end

  def isBridgeOn
    return false if !defined?($PokemonGlobal) || !$PokemonGlobal
    return $PokemonGlobal.respond_to?(:bridge) && $PokemonGlobal.bridge.to_i > 0
  rescue
    return false
  end

  def pbBridgeOn(height = 2, *_args)
    return TravelExpansionFramework.empyrean_set_bridge_height!(height) if defined?(TravelExpansionFramework) &&
                                                                           TravelExpansionFramework.respond_to?(:empyrean_set_bridge_height!)
    $PokemonGlobal.bridge = height if defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.respond_to?(:bridge=)
    return true
  rescue
    return true
  end

  def pbBridgeOff(*_args)
    return TravelExpansionFramework.empyrean_clear_bridge_height! if defined?(TravelExpansionFramework) &&
                                                                     TravelExpansionFramework.respond_to?(:empyrean_clear_bridge_height!)
    $PokemonGlobal.bridge = 0 if defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.respond_to?(:bridge=)
    return true
  rescue
    return true
  end

  def characterPopup(label, event_ref = nil, *_args)
    return TravelExpansionFramework.show_character_popup(label, event_ref, @event_id) if defined?(TravelExpansionFramework) &&
                                                                                         TravelExpansionFramework.respond_to?(:show_character_popup)
    return true
  end

  def chrp(label, event_ref = nil)
    return characterPopup(label, event_ref)
  end

  def chrp1(event_ref = nil)
    return characterPopup(:P_EXCLAMATION, event_ref)
  end

  def playCry(species, volume = 50, pitch = 100)
    return TravelExpansionFramework.play_expansion_cry(species, volume, pitch) if defined?(TravelExpansionFramework) &&
                                                                                 TravelExpansionFramework.respond_to?(:play_expansion_cry)
    return true
  end

  def pbPlayCrySpecies(pokemon, form = 0, volume = 90, pitch = nil)
    return ::Kernel.pbPlayCrySpecies(pokemon, form, volume, pitch) if ::Kernel.respond_to?(:pbPlayCrySpecies)
    return pbPlayCry(pokemon, form, volume, pitch) if respond_to?(:pbPlayCry)
    return nil
  rescue
    return nil
  end

  def pbShuffleDex(*_args)
    return true
  end

  def pbShuffleDexTrainers(*_args)
    return true
  end

  def pbPokemonFollow(_event_id, _event_name = "Dependent")
    if defined?(TravelExpansionFramework) &&
       TravelExpansionFramework.respond_to?(:insurgence_expansion_id?) &&
       TravelExpansionFramework.insurgence_expansion_id?
      return TravelExpansionFramework.insurgence_follow_event(_event_id, _event_name, true)
    end
    if TravelExpansionFramework.new_project_identity_active_now?((@map_id rescue nil))
      return TravelExpansionFramework.new_project_follow_event(_event_id, _event_name, true)
    end
    return false
  end

  def pbAddDependency(event_id, event_name = "Dependent", common_event = nil, *args)
    if defined?(TravelExpansionFramework) &&
       TravelExpansionFramework.respond_to?(:insurgence_expansion_id?) &&
       TravelExpansionFramework.insurgence_expansion_id?
      return true if TravelExpansionFramework.insurgence_follow_event(event_id, event_name, false)
    end
    if TravelExpansionFramework.new_project_identity_active_now?((@map_id rescue nil))
      return true if TravelExpansionFramework.new_project_follow_event(event_id, event_name, false)
    end
    return send(:tef_new_projects_original_pbAddDependency, event_id, event_name, common_event, *args) if respond_to?(:tef_new_projects_original_pbAddDependency, true)
    return false
  end

  def pbChangePlayer(id, *args)
    if TravelExpansionFramework.new_project_identity_active_now?((@map_id rescue nil))
      TravelExpansionFramework.apply_new_project_gender_selection!((@map_id rescue nil))
      expansion = TravelExpansionFramework.current_new_project_expansion_id(@map_id) || "new_project"
      if expansion.to_s == TravelExpansionFramework::INFINITY_EXPANSION_ID && TravelExpansionFramework.respond_to?(:infinity_restore_host_player_visuals!)
        TravelExpansionFramework.infinity_restore_host_player_visuals!("interpreter pbChangePlayer")
      else
        TravelExpansionFramework.apply_host_player_visuals!(expansion)
      end
      return true
    end
    return send(:tef_new_projects_original_pbChangePlayer, id, *args) if respond_to?(:tef_new_projects_original_pbChangePlayer, true)
    return false
  end

  def pbTrainerName(name = nil, outfit = 0)
    if TravelExpansionFramework.new_project_identity_active_now?((@map_id rescue nil))
      chosen_name = TravelExpansionFramework.host_player_name_for_expansion
      meta = TravelExpansionFramework.new_project_metadata
      meta["intro_requested_name"] = name.to_s if meta && !name.nil?
      meta["intro_name"] = chosen_name if meta
      $PokemonTemp.begunNewGame = true if defined?($PokemonTemp) && $PokemonTemp && $PokemonTemp.respond_to?(:begunNewGame=)
      return chosen_name
    end
    return send(:tef_new_projects_original_pbTrainerName, name, outfit) if respond_to?(:tef_new_projects_original_pbTrainerName, true)
    return name.to_s
  end

  def startCharacterSelection(*_args)
    TravelExpansionFramework.record_release_shim_hit("startCharacterSelection", "startup", "zero") if defined?(TravelExpansionFramework) &&
                                                                                                      TravelExpansionFramework.respond_to?(:record_release_shim_hit)
    return 0
  rescue
    return 0
  end

  def pbCharacterSelect(*args)
    return TravelExpansionFramework.decades_character_select!(*args) if defined?(TravelExpansionFramework) &&
                                                                       TravelExpansionFramework.respond_to?(:decades_character_select!)
    return true
  rescue
    return true
  end

  def setSkintone(value)
    return TravelExpansionFramework.new_project_apply_skin_selection!(value, (@map_id rescue nil))
  end

  def skintone
    meta = TravelExpansionFramework.new_project_metadata
    return meta["intro_skin_selection"] if meta && meta.has_key?("intro_skin_selection")
    return 0
  rescue
    return 0
  end

  def isPlayerMale?
    return !TravelExpansionFramework.host_player_female?
  end

  def setDifficultyVar(value)
    TravelExpansionFramework.ensure_player_global!
    $game_variables[242] = value if defined?($game_variables) && $game_variables
    meta = TravelExpansionFramework.new_project_metadata
    meta["difficulty"] = value if meta
    return value
  end

  def trackAnalyticsEvent(*args)
    return nil
  end

  def giveDefaultClothing(*args)
    return true
  end

  def calcPlayerSprites(*args)
    return true
  end

  def calcIntroSprites(*args)
    return TravelExpansionFramework.empyrean_intro_sprites_ready! if TravelExpansionFramework.new_project_identity_active_now?
    return true
  end
end

if defined?(Game_Map)
  class Game_Map
    alias tef_empyrean_original_setup setup unless method_defined?(:tef_empyrean_original_setup)
    alias tef_empyrean_original_playerPassable? playerPassable? unless method_defined?(:tef_empyrean_original_playerPassable?)

    def setup(map_id)
      result = tef_empyrean_original_setup(map_id)
      TravelExpansionFramework.opalo_repair_starter_room_state!(map_id, "map_setup") if defined?(TravelExpansionFramework) &&
                                                                                       TravelExpansionFramework.respond_to?(:opalo_repair_starter_room_state!)
      TravelExpansionFramework.void_prepare_map_runtime!(self, "map_setup") if defined?(TravelExpansionFramework) &&
                                                                              TravelExpansionFramework.respond_to?(:void_prepare_map_runtime!)
      if defined?(TravelExpansionFramework) &&
         TravelExpansionFramework.respond_to?(:empyrean_map?) &&
         TravelExpansionFramework.respond_to?(:empyrean_prepare_bridge_cache!) &&
         TravelExpansionFramework.empyrean_map?(map_id)
        TravelExpansionFramework.empyrean_prepare_bridge_cache!(self)
      end
      return result
    end

    def playerPassable?(x, y, d, self_event = nil)
      if defined?(TravelExpansionFramework) &&
         TravelExpansionFramework.respond_to?(:empyrean_map?) &&
         TravelExpansionFramework.respond_to?(:empyrean_prepare_bridge_for_step!) &&
         TravelExpansionFramework.empyrean_map?(@map_id)
        TravelExpansionFramework.empyrean_prepare_bridge_for_step!(self, x, y, d)
      end
      result = tef_empyrean_original_playerPassable?(x, y, d, self_event)
      return true if !result &&
                     defined?(TravelExpansionFramework) &&
                     TravelExpansionFramework.respond_to?(:empyrean_bridge_step_passable?) &&
                     TravelExpansionFramework.empyrean_bridge_step_passable?(self, x, y, d)
      return result
    end
  end
end
