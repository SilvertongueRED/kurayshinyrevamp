module AutoplayBot
  MOD_ID = "autoplay_bot" unless const_defined?(:MOD_ID)
  ROOT = File.expand_path(File.dirname(__FILE__)) unless const_defined?(:ROOT)
  DATA_DIR = File.join(ROOT, "data") unless const_defined?(:DATA_DIR)
  GUIDE_DIR = File.join(DATA_DIR, "guides") unless const_defined?(:GUIDE_DIR)
  CACHE_DIR = File.join(DATA_DIR, "cache") unless const_defined?(:CACHE_DIR)
  LOG_DIR = File.join(ROOT, "logs") unless const_defined?(:LOG_DIR)
  STATE_FILE = File.join(DATA_DIR, "state.json") unless const_defined?(:STATE_FILE)
  CACHE_FILE = File.join(CACHE_DIR, "world_index.json") unless const_defined?(:CACHE_FILE)
  LOG_FILE = File.join(LOG_DIR, "autoplay_bot.log") unless const_defined?(:LOG_FILE)

  DEFAULT_SETTINGS = {
    "enabled" => true,
    "autostart" => false,
    "pause_key" => "F5",
    "overlay_mode" => "compact_hud",
    "auto_choose_exclusive" => true,
    "route_profile" => "current_save",
    "automation_scope" => "wild_capture_focus",
    "prime_objective" => "living_dex_all_fusions",
    "completion_scope" => "all_available_game_content",
    "guide_pack" => "default",
    "dex_copy_goal" => "flexible_two",
    "rare_policy" => "defer",
    "nickname_policy" => "smart",
    "trainer_capture_policy" => "respect_game",
    "team_strategy" => "smart_safe",
    "fusion_strategy" => "recommend_safe",
    "fusion_collection_goal" => "own_each_seen_fusion",
    "recovery_policy" => "soft_recover",
    "training_after_loss" => true,
    "frontier_explore" => true,
    "safe_mode" => true,
    "local_discovery" => true,
    "local_discovery_radius" => "nearby",
    "autonomy_profile" => "collector_opportunistic",
    "map_clear_policy" => "queue_opportunistic",
    "collector_intensity" => "high_bounded",
    "adaptive_planner_budget" => "low_lag_burst",
    "resource_autonomy" => "legit_shop_flow",
    "hunt_completion" => "base_plus_seen_fusions",
    "hunt_unlock_strategy" => "hunt_first_conservative",
    "hunt_zone_budget" => "bounded",
    "world_coverage" => true,
    "story_unlock_priority" => true,
    "world_backtrack_policy" => "quick_route",
    "rocket_ball_wild_policy" => "never",
    "min_standard_balls" => 15,
    "min_heal_items" => 5,
    "repeatable_battle_policy" => "hybrid_learning",
    "farming_policy" => "need_based",
    "max_farm_cycles_per_objective" => 3,
    "min_money_reserve" => 1000,
    "resource_overlay_detail" => "normal",
    "self_improvement_logging" => true,
    "menu_idle_escape" => true,
    "menu_idle_escape_frames" => 600,
    "max_objective_retries" => 3,
    "planner_budget" => "low_lag",
    "allow_debug_escape" => false
  } unless const_defined?(:DEFAULT_SETTINGS)

  module Config
    module_function

    def settings
      raw = {}
      if defined?($mod_manager_settings) && $mod_manager_settings
        raw = $mod_manager_settings[AutoplayBot::MOD_ID] || {}
      end
      merged = {}
      AutoplayBot::DEFAULT_SETTINGS.each { |k, v| merged[k] = v }
      raw.each { |k, v| merged[k.to_s] = v } if raw.respond_to?(:each)
      merged
    end

    def get(key, fallback = nil)
      value = settings[key.to_s]
      value.nil? ? fallback : value
    end

    def enabled?
      get("enabled") != false
    end

    def autostart?
      get("autostart") == true
    end

    def guide_pack_path
      pack = get("guide_pack").to_s
      pack = "default" if pack.empty?
      File.join(AutoplayBot::GUIDE_DIR, "#{pack}.json")
    end

    def automation_scope
      value = get("automation_scope", "wild_capture_focus").to_s
      valid = ["wild_capture_focus", "story_explorer"]
      valid.include?(value) ? value : "wild_capture_focus"
    rescue
      "wild_capture_focus"
    end

    def wild_capture_focus?
      automation_scope == "wild_capture_focus"
    rescue
      true
    end

    def prime_objective
      value = get("prime_objective", "living_dex_all_fusions").to_s
      valid = ["living_dex_all_fusions", "base_living_dex", "story_clear"]
      valid.include?(value) ? value : "living_dex_all_fusions"
    rescue
      "living_dex_all_fusions"
    end

    def prime_collection?
      prime_objective != "story_clear"
    rescue
      true
    end

    def completion_scope
      value = get("completion_scope", "all_available_game_content").to_s
      valid = ["all_available_game_content", "main_story_plus_dex", "current_region"]
      valid.include?(value) ? value : "all_available_game_content"
    rescue
      "all_available_game_content"
    end

    def button_constant(name)
      return nil unless defined?(Input)
      return name if name.is_a?(Integer)
      label = name.to_s.upcase
      return nil unless Input.const_defined?(label)
      Input.const_get(label)
    rescue
      nil
    end

    def pause_button
      button_constant(get("pause_key")) || (defined?(Input::F5) ? Input::F5 : nil)
    end

    def overlay_mode
      value = get("overlay_mode", "compact_hud").to_s
      valid = ["compact_hud", "classic_window", "off"]
      valid.include?(value) ? value : "compact_hud"
    rescue
      "compact_hud"
    end

    def overlay_enabled?
      overlay_mode != "off"
    rescue
      true
    end

    def compact_hud_overlay?
      overlay_mode == "compact_hud"
    rescue
      true
    end

    def auto_choose_exclusive?
      value = get("auto_choose_exclusive", true)
      mode = get("exclusive_choice_mode", nil)
      return mode.to_s != "manual_pause" unless mode.nil? || mode.to_s.empty?
      return false if value == false
      return false if value.to_s.downcase == "false"
      true
    end

    def pause_on_exclusive_choices?
      !auto_choose_exclusive?
    end

    def copy_goal
      get("dex_copy_goal") == "one_each" ? 1 : 2
    end

    def rare_policy
      get("rare_policy").to_s
    end

    def nickname_policy
      policy = get("nickname_policy", "smart").to_s
      ["smart", "always", "never"].include?(policy) ? policy : "smart"
    rescue
      "smart"
    end

    def trainer_capture_policy
      policy = get("trainer_capture_policy", "respect_game").to_s
      valid = ["respect_game", "off", "force_rocket_balls", "force_all_balls"]
      valid.include?(policy) ? policy : "respect_game"
    rescue
      "respect_game"
    end

    def team_strategy
      value = get("team_strategy", "smart_safe").to_s
      ["smart_safe", "store_only", "off"].include?(value) ? value : "smart_safe"
    rescue
      "smart_safe"
    end

    def team_strategy?
      team_strategy != "off"
    rescue
      true
    end

    def fusion_strategy
      value = get("fusion_strategy", "recommend_safe").to_s
      ["recommend_safe", "off"].include?(value) ? value : "recommend_safe"
    rescue
      "recommend_safe"
    end

    def fusion_strategy?
      fusion_strategy != "off"
    rescue
      true
    end

    def fusion_collection_goal
      value = get("fusion_collection_goal", "own_each_seen_fusion").to_s
      valid = ["own_each_seen_fusion", "track_only", "off"]
      valid.include?(value) ? value : "own_each_seen_fusion"
    rescue
      "own_each_seen_fusion"
    end

    def fusion_collection?
      prime_objective == "living_dex_all_fusions" && fusion_collection_goal != "off"
    rescue
      true
    end

    def recovery_policy
      policy = get("recovery_policy", "soft_recover").to_s
      ["soft_recover", "manual_pause"].include?(policy) ? policy : "soft_recover"
    rescue
      "soft_recover"
    end

    def soft_recovery?
      recovery_policy == "soft_recover"
    rescue
      true
    end

    def training_after_loss?
      value = get("training_after_loss", true)
      value != false && value.to_s.downcase != "false"
    rescue
      true
    end

    def frontier_explore?
      value = get("frontier_explore", true)
      value != false && value.to_s.downcase != "false"
    rescue
      true
    end

    def safe_mode?
      value = get("safe_mode", true)
      value != false && value.to_s.downcase != "false"
    rescue
      true
    end

    def local_discovery?
      value = get("local_discovery", true)
      value != false && value.to_s.downcase != "false"
    rescue
      true
    end

    def local_discovery_radius
      value = get("local_discovery_radius", "nearby").to_s
      ["nearby", "room", "wide"].include?(value) ? value : "nearby"
    rescue
      "nearby"
    end

    def local_discovery_distance
      return 16 if collector_heavy? && collector_opportunistic?
      case local_discovery_radius
      when "wide" then 14
      when "room" then 10
      else 7
      end
    rescue
      7
    end

    def local_discovery_path_limit
      return 36 if collector_heavy? && collector_opportunistic?
      case local_discovery_radius
      when "wide" then 32
      when "room" then 24
      else 18
      end
    rescue
      18
    end

    def autonomy_profile
      value = get("autonomy_profile", "collector_opportunistic").to_s
      ["collector_opportunistic", "story_guided", "minimal"].include?(value) ? value : "collector_opportunistic"
    rescue
      "collector_opportunistic"
    end

    def collector_opportunistic?
      autonomy_profile == "collector_opportunistic"
    rescue
      true
    end

    def map_clear_policy
      value = get("map_clear_policy", "queue_opportunistic").to_s
      ["queue_opportunistic", "story_first", "clear_before_leave"].include?(value) ? value : "queue_opportunistic"
    rescue
      "queue_opportunistic"
    end

    def opportunistic_map_clear?
      map_clear_policy == "queue_opportunistic" || map_clear_policy == "clear_before_leave"
    rescue
      true
    end

    def collector_intensity
      value = get("collector_intensity", "high_bounded").to_s
      ["high_bounded", "normal", "minimal"].include?(value) ? value : "high_bounded"
    rescue
      "high_bounded"
    end

    def collector_heavy?
      collector_intensity == "high_bounded"
    rescue
      true
    end

    def adaptive_planner_budget
      value = get("adaptive_planner_budget", "low_lag_burst").to_s
      ["low_lag_burst", "strict_low_lag", "balanced_burst"].include?(value) ? value : "low_lag_burst"
    rescue
      "low_lag_burst"
    end

    def resource_autonomy
      value = get("resource_autonomy", "legit_shop_flow").to_s
      ["legit_shop_flow", "strict_inputs_only", "pragmatic_helper"].include?(value) ? value : "legit_shop_flow"
    rescue
      "legit_shop_flow"
    end

    def hunt_completion
      value = get("hunt_completion", "base_plus_seen_fusions").to_s
      valid = ["base_plus_seen_fusions", "base_species_only", "all_seen_fusions"]
      valid.include?(value) ? value : "base_plus_seen_fusions"
    rescue
      "base_plus_seen_fusions"
    end

    def hunt_base_plus_seen_fusions?
      hunt_completion == "base_plus_seen_fusions" || hunt_completion == "all_seen_fusions"
    rescue
      true
    end

    def hunt_unlock_strategy
      value = get("hunt_unlock_strategy", "hunt_first_conservative").to_s
      valid = ["hunt_first_conservative", "manual_unlocks", "full_story_explorer"]
      valid.include?(value) ? value : "hunt_first_conservative"
    rescue
      "hunt_first_conservative"
    end

    def hunt_first_unlocks?
      hunt_unlock_strategy == "hunt_first_conservative"
    rescue
      true
    end

    def manual_hunt_unlocks?
      hunt_unlock_strategy == "manual_unlocks"
    rescue
      false
    end

    def hunt_zone_budget
      value = get("hunt_zone_budget", "bounded").to_s
      valid = ["bounded", "patient", "quick_sample"]
      valid.include?(value) ? value : "bounded"
    rescue
      "bounded"
    end

    def hunt_encounter_budget
      case hunt_zone_budget
      when "patient" then 36
      when "quick_sample" then 12
      else 24
      end
    rescue
      24
    end

    def world_coverage?
      value = get("world_coverage", true)
      value != false && value.to_s.downcase != "false"
    rescue
      true
    end

    def story_unlock_priority?
      value = get("story_unlock_priority", true)
      value != false && value.to_s.downcase != "false"
    rescue
      true
    end

    def world_backtrack_policy
      value = get("world_backtrack_policy", "quick_route").to_s
      valid = ["quick_route", "nearby_only", "off"]
      valid.include?(value) ? value : "quick_route"
    rescue
      "quick_route"
    end

    def quick_world_backtrack?
      world_backtrack_policy == "quick_route"
    rescue
      true
    end

    def rocket_ball_wild_policy
      value = get("rocket_ball_wild_policy", "never").to_s
      ["never", "allow_if_only_ball"].include?(value) ? value : "never"
    rescue
      "never"
    end

    def rocket_ball_wild_allowed?
      rocket_ball_wild_policy == "allow_if_only_ball"
    rescue
      false
    end

    def min_standard_balls
      value = get("min_standard_balls", 15).to_i
      [[value, 1].max, 99].min
    rescue
      15
    end

    def min_heal_items
      value = get("min_heal_items", 5).to_i
      [[value, 0].max, 99].min
    rescue
      5
    end

    def repeatable_battle_policy
      value = get("repeatable_battle_policy", "hybrid_learning").to_s
      ["hybrid_learning", "guide_flags_first", "script_heuristics_first"].include?(value) ? value : "hybrid_learning"
    rescue
      "hybrid_learning"
    end

    def farming_policy
      value = get("farming_policy", "need_based").to_s
      ["need_based", "aggressive_grind", "minimal_fallback"].include?(value) ? value : "need_based"
    rescue
      "need_based"
    end

    def max_farm_cycles_per_objective
      value = get("max_farm_cycles_per_objective", 3).to_i
      [[value, 1].max, 10].min
    rescue
      3
    end

    def min_money_reserve
      value = get("min_money_reserve", 1000).to_i
      [[value, 0].max, 100_000].min
    rescue
      1000
    end

    def resource_overlay_detail
      value = get("resource_overlay_detail", "normal").to_s
      ["off", "normal", "verbose"].include?(value) ? value : "normal"
    rescue
      "normal"
    end

    def self_improvement_logging?
      value = get("self_improvement_logging", true)
      value != false && value.to_s.downcase != "false"
    rescue
      true
    end

    def menu_idle_escape?
      value = get("menu_idle_escape", true)
      value != false && value.to_s.downcase != "false"
    rescue
      true
    end

    def menu_idle_escape_frames
      value = get("menu_idle_escape_frames", 600).to_i
      [[value, 180].max, 1800].min
    rescue
      600
    end

    def max_objective_retries
      value = get("max_objective_retries", 3).to_i
      [[value, 1].max, 10].min
    rescue
      3
    end

    def planner_budget
      value = get("planner_budget", "low_lag").to_s
      ["low_lag", "balanced", "aggressive"].include?(value) ? value : "low_lag"
    rescue
      "low_lag"
    end

    def path_node_budget(default_value = 2400)
      case planner_budget
      when "aggressive" then [default_value.to_i, 12_000].max
      when "balanced" then [default_value.to_i, 6_000].max
      else [default_value.to_i, 2_400].min
      end
    rescue
      default_value.to_i
    end

    def adaptive_path_node_budget(default_value = 2400, context = nil)
      base = path_node_budget(default_value)
      return base if adaptive_planner_budget == "strict_low_lag"
      return base if planner_budget != "low_lag"
      burst = case adaptive_planner_budget
              when "balanced_burst" then 4_800
              else 3_200
              end
      allowed = ["transfer", "event", "item", "npc", "healer", "recovery", "stuck", "cleanup"]
      return base unless allowed.include?(context.to_s)
      [[default_value.to_i, burst].min, base].max
    rescue
      path_node_budget(default_value)
    end

    def scan_budget
      case planner_budget
      when "aggressive" then 3
      when "balanced" then 2
      else 1
      end
    rescue
      1
    end

    def scan_interval_frames
      case planner_budget
      when "aggressive" then 30
      when "balanced" then 60
      else 90
      end
    rescue
      90
    end
  end
end
