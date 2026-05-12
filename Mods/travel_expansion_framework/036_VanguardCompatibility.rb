#===============================================================================
# Vanguard early-story safety
#===============================================================================

module TravelExpansionFramework
  VANGUARD_EXPANSION_ID = "vanguard" unless const_defined?(:VANGUARD_EXPANSION_ID)
  VANGUARD_LEGACY_EXPANSION_IDS = ["pokemon_vanguard"] unless const_defined?(:VANGUARD_LEGACY_EXPANSION_IDS)

  VANGUARD_INTRO_COMPLETED_SWITCH = 59 unless const_defined?(:VANGUARD_INTRO_COMPLETED_SWITCH)
  VANGUARD_WAKING_UP_SWITCH       = 60 unless const_defined?(:VANGUARD_WAKING_UP_SWITCH)
  VANGUARD_MEET_DESTINY_SWITCH    = 61 unless const_defined?(:VANGUARD_MEET_DESTINY_SWITCH)
  VANGUARD_PICK_STARTER_SWITCH    = 62 unless const_defined?(:VANGUARD_PICK_STARTER_SWITCH)
  VANGUARD_FIND_DESTINY_SWITCH    = 63 unless const_defined?(:VANGUARD_FIND_DESTINY_SWITCH)
  VANGUARD_BACK_HOME_SWITCH       = 66 unless const_defined?(:VANGUARD_BACK_HOME_SWITCH)
  VANGUARD_TO_ACADEMY_SWITCH      = 68 unless const_defined?(:VANGUARD_TO_ACADEMY_SWITCH)
  VANGUARD_ROUTE_2_SWITCH         = 69 unless const_defined?(:VANGUARD_ROUTE_2_SWITCH)
  VANGUARD_LATE_HOUSE_SWITCH      = 97 unless const_defined?(:VANGUARD_LATE_HOUSE_SWITCH)
  VANGUARD_LATE_DESTINY_SWITCH    = 105 unless const_defined?(:VANGUARD_LATE_DESTINY_SWITCH)
  VANGUARD_LATE_FLIGHT_SWITCH     = 106 unless const_defined?(:VANGUARD_LATE_FLIGHT_SWITCH)

  VANGUARD_DESTINY_HOUSE_MAP = 81 unless const_defined?(:VANGUARD_DESTINY_HOUSE_MAP)
  VANGUARD_OCEIA_CITY_MAPS   = [76, 200] unless const_defined?(:VANGUARD_OCEIA_CITY_MAPS)
  VANGUARD_OCEIA_LAB_MAP     = 83 unless const_defined?(:VANGUARD_OCEIA_LAB_MAP)
  VANGUARD_EARLY_STORY_MAPS  = ([VANGUARD_DESTINY_HOUSE_MAP, VANGUARD_OCEIA_LAB_MAP] + VANGUARD_OCEIA_CITY_MAPS).freeze unless const_defined?(:VANGUARD_EARLY_STORY_MAPS)

  module_function

  def vanguard_expansion_ids
    return ([VANGUARD_EXPANSION_ID] + Array(VANGUARD_LEGACY_EXPANSION_IDS)).uniq
  end

  def vanguard_active_now?(map_id = nil)
    target_map_id = integer(map_id || ($game_map.map_id rescue 0), 0)
    if target_map_id > 0 && respond_to?(:current_map_expansion_id)
      return true if expansion_id_in_list?(current_map_expansion_id(target_map_id), vanguard_expansion_ids)
      return false
    end
    if respond_to?(:active_project_expansion_id)
      return !active_project_expansion_id(vanguard_expansion_ids, map_id).nil?
    end
    return false
  rescue
    return false
  end

  def vanguard_current_expansion_id(map_id = nil)
    target_map_id = integer(map_id || ($game_map.map_id rescue 0), 0)
    if target_map_id > 0 && respond_to?(:current_map_expansion_id)
      map_expansion = current_map_expansion_id(target_map_id)
      return canonical_new_project_id(map_expansion) if expansion_id_in_list?(map_expansion, vanguard_expansion_ids)
      return nil
    end
    return active_project_expansion_id(vanguard_expansion_ids, map_id) if respond_to?(:active_project_expansion_id)
    return VANGUARD_EXPANSION_ID if vanguard_active_now?(map_id)
    return nil
  rescue
    return nil
  end

  def vanguard_local_map_id(map_id = nil)
    target_map_id = integer(map_id || ($game_map.map_id rescue 0), 0)
    expansion = vanguard_current_expansion_id(target_map_id)
    return local_map_id_for(expansion, target_map_id) if expansion && respond_to?(:local_map_id_for)
    return target_map_id
  rescue
    return integer(map_id || ($game_map.map_id rescue 0), 0)
  end

  def vanguard_story_switch?(switch_id)
    return false if !defined?($game_switches) || !$game_switches
    return $game_switches[integer(switch_id, 0)] ? true : false
  rescue
    return false
  end

  def vanguard_set_switch!(switch_id, value)
    return false if !defined?($game_switches) || !$game_switches
    identifier = integer(switch_id, 0)
    return false if identifier <= 0
    previous = $game_switches[identifier] ? true : false
    next_value = value ? true : false
    return false if previous == next_value
    $game_switches[identifier] = next_value
    return true
  rescue
    return false
  end

  def vanguard_later_story_started?
    return true if vanguard_story_switch?(VANGUARD_PICK_STARTER_SWITCH)
    return true if vanguard_story_switch?(VANGUARD_FIND_DESTINY_SWITCH)
    return true if vanguard_story_switch?(VANGUARD_BACK_HOME_SWITCH)
    return true if vanguard_story_switch?(VANGUARD_TO_ACADEMY_SWITCH)
    return true if vanguard_story_switch?(VANGUARD_ROUTE_2_SWITCH)
    return true if vanguard_story_switch?(VANGUARD_LATE_HOUSE_SWITCH)
    return true if vanguard_story_switch?(VANGUARD_LATE_DESTINY_SWITCH)
    return true if vanguard_story_switch?(VANGUARD_LATE_FLIGHT_SWITCH)
    return false
  rescue
    return false
  end

  def vanguard_map_interpreter_running?
    interpreter = nil
    if defined?($game_system) && $game_system && $game_system.respond_to?(:map_interpreter)
      interpreter = $game_system.map_interpreter
    elsif defined?($game_map) && $game_map && $game_map.respond_to?(:interpreter)
      interpreter = $game_map.interpreter
    end
    return interpreter && interpreter.respond_to?(:running?) && interpreter.running?
  rescue
    return false
  end

  def vanguard_log_once(key, message)
    @vanguard_log_once ||= {}
    token = key.to_s
    return false if @vanguard_log_once[token]
    @vanguard_log_once[token] = true
    log(message) if respond_to?(:log)
    return true
  rescue
    return false
  end

  def vanguard_scene_map?
    return defined?($scene) && defined?(Scene_Map) && $scene.is_a?(Scene_Map)
  rescue
    return false
  end

  def vanguard_clear_stale_battle_state!(reason = "runtime")
    return false if !vanguard_active_now?
    return false if !vanguard_scene_map?
    changed = false
    if defined?($game_temp) && $game_temp && $game_temp.respond_to?(:in_battle) && $game_temp.in_battle
      $game_temp.in_battle = false if $game_temp.respond_to?(:in_battle=)
      changed = true
    end
    if defined?($PokemonSystem) && $PokemonSystem &&
       $PokemonSystem.respond_to?(:is_in_battle) &&
       $PokemonSystem.respond_to?(:is_in_battle=) &&
       $PokemonSystem.is_in_battle
      $PokemonSystem.is_in_battle = false
      changed = true
    end
    if changed
      $PokemonTemp.clearBattleRules if defined?($PokemonTemp) && $PokemonTemp && $PokemonTemp.respond_to?(:clearBattleRules)
      new_project_release_player_controls!(false, false) if respond_to?(:new_project_release_player_controls!) &&
                                                            !vanguard_map_interpreter_running?
      map_id = integer(($game_map.map_id rescue 0), 0)
      vanguard_log_once("battle_state|#{map_id}|#{reason}", "[vanguard] cleared stale battle state on map #{map_id} via #{reason}")
    end
    return changed
  rescue => e
    log("[vanguard] stale battle-state cleanup failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def vanguard_release_idle_controls!(reason = "runtime")
    return false if !vanguard_active_now? || !vanguard_scene_map? || vanguard_map_interpreter_running?
    local_map = vanguard_local_map_id
    return false if !VANGUARD_EARLY_STORY_MAPS.include?(integer(local_map, 0))
    return false if defined?($game_temp) && $game_temp &&
                    $game_temp.respond_to?(:message_window_showing) &&
                    $game_temp.message_window_showing
    stuck = false
    stuck = true if defined?($game_system) && $game_system &&
                    $game_system.respond_to?(:menu_disabled) &&
                    $game_system.menu_disabled
    if defined?($game_temp) && $game_temp
      stuck = true if $game_temp.respond_to?(:player_transferring) && $game_temp.player_transferring
      stuck = true if $game_temp.respond_to?(:transition_processing) && $game_temp.transition_processing
      stuck = true if $game_temp.respond_to?(:in_menu) && $game_temp.in_menu
      stuck = true if $game_temp.respond_to?(:menu_calling) && $game_temp.menu_calling
    end
    return false if !stuck
    new_project_release_player_controls!(false, true) if respond_to?(:new_project_release_player_controls!)
    map_id = integer(($game_map.map_id rescue 0), 0)
    vanguard_log_once("controls|#{map_id}|#{reason}", "[vanguard] released stale early-story controls on map #{map_id} via #{reason}")
    return true
  rescue => e
    log("[vanguard] idle control release failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def vanguard_refresh_map_events!
    if defined?($game_map) && $game_map
      $game_map.need_refresh = true if $game_map.respond_to?(:need_refresh=)
      if $game_map.respond_to?(:events) && $game_map.events.respond_to?(:each_value)
        $game_map.events.each_value { |event| event.refresh if event && event.respond_to?(:refresh) } rescue nil
      end
    end
    return true
  rescue
    return false
  end

  def vanguard_repair_intro_story_state!(map_id = nil, reason = "runtime")
    target_map_id = integer(map_id || ($game_map.map_id rescue 0), 0)
    return false if target_map_id <= 0 || !vanguard_active_now?(target_map_id)
    local_map = vanguard_local_map_id(target_map_id)
    return false if !VANGUARD_EARLY_STORY_MAPS.include?(integer(local_map, 0))
    changed = false
    if !vanguard_later_story_started?
      if integer(local_map, 0) == VANGUARD_DESTINY_HOUSE_MAP
        changed = vanguard_set_switch!(VANGUARD_INTRO_COMPLETED_SWITCH, true) || changed
        if !vanguard_story_switch?(VANGUARD_MEET_DESTINY_SWITCH)
          changed = vanguard_set_switch!(VANGUARD_WAKING_UP_SWITCH, true) || changed
        end
      elsif VANGUARD_OCEIA_CITY_MAPS.include?(integer(local_map, 0)) ||
            integer(local_map, 0) == VANGUARD_OCEIA_LAB_MAP
        changed = vanguard_set_switch!(VANGUARD_INTRO_COMPLETED_SWITCH, true) || changed
        changed = vanguard_set_switch!(VANGUARD_WAKING_UP_SWITCH, false) || changed
        changed = vanguard_set_switch!(VANGUARD_MEET_DESTINY_SWITCH, true) || changed
      end
    end
    if changed
      vanguard_refresh_map_events!
      vanguard_log_once("story|#{target_map_id}|#{local_map}|#{reason}",
                        "[vanguard] repaired early story state on map #{target_map_id} (local #{local_map}) via #{reason}")
    end
    vanguard_clear_stale_battle_state!(reason)
    vanguard_release_idle_controls!(reason)
    return changed
  rescue => e
    log("[vanguard] intro story repair failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def vanguard_runtime_update!
    return false if !vanguard_active_now?
    return vanguard_repair_intro_story_state!(($game_map.map_id rescue nil), "scene_update")
  rescue
    return false
  end
end

if defined?(Game_Map)
  class Game_Map
    alias tef_vanguard_original_setup setup unless method_defined?(:tef_vanguard_original_setup)

    def setup(map_id)
      result = tef_vanguard_original_setup(map_id)
      TravelExpansionFramework.vanguard_repair_intro_story_state!(map_id, "map_setup") if defined?(TravelExpansionFramework) &&
                                                                                          TravelExpansionFramework.respond_to?(:vanguard_repair_intro_story_state!)
      return result
    end
  end
end

if defined?(Scene_Map)
  class Scene_Map
    alias tef_vanguard_original_update update unless method_defined?(:tef_vanguard_original_update)

    def update(*args)
      result = tef_vanguard_original_update(*args)
      TravelExpansionFramework.vanguard_runtime_update! if defined?(TravelExpansionFramework) &&
                                                           TravelExpansionFramework.respond_to?(:vanguard_runtime_update!)
      return result
    end
  end
end
