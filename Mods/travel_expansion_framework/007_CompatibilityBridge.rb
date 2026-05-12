module TravelExpansionFramework
  module_function

  def runtime_context_stack
    @runtime_context_stack ||= []
    return @runtime_context_stack
  end

  def runtime_data_cache
    @runtime_data_cache ||= {}
    return @runtime_data_cache
  end

  def current_runtime_context
    return runtime_context_stack.last
  end

  def current_runtime_expansion_id
    context = current_runtime_context
    return nil if !context.is_a?(Hash)
    expansion_id = context[:expansion_id].to_s
    return nil if expansion_id.empty?
    return expansion_id
  end

  def with_runtime_context(expansion_id, extra = nil)
    expansion = expansion_id.to_s
    return yield if expansion.empty?
    context = {}
    parent = current_runtime_context
    if parent.is_a?(Hash)
      parent.each_pair { |key, value| context[key] = value }
    end
    context[:expansion_id] = expansion
    if extra.is_a?(Hash)
      extra.each_pair { |key, value| context[key.to_sym] = value }
    end
    runtime_context_stack << context
    result = yield
    return result
  ensure
    runtime_context_stack.pop if runtime_context_stack.length > 0
  end

  def expansion_runtime_store(expansion_id, key)
    state = state_for(expansion_id)
    return {} if state.nil?
    metadata = state.respond_to?(:metadata) ? state.metadata : nil
    if !metadata.is_a?(Hash)
      metadata = {}
      state.metadata = metadata if state.respond_to?(:metadata=)
      state.instance_variable_set(:@metadata, metadata) if state.respond_to?(:instance_variable_set)
    end
    runtime_state = metadata["runtime_state"]
    if !runtime_state.is_a?(Hash)
      runtime_state = {}
      metadata["runtime_state"] = runtime_state
    end
    store = runtime_state[key.to_s]
    if !store.is_a?(Hash)
      store = {}
      runtime_state[key.to_s] = store
    end
    return store
  rescue => e
    log("Compatibility runtime store failed for #{expansion_id.inspect}/#{key.inspect}: #{e.class}: #{e.message}") if respond_to?(:log)
    return {}
  end

  def expansion_switch_value(expansion_id, switch_id)
    identifier = integer(switch_id, 0)
    return false if identifier <= 0
    store = expansion_runtime_store(expansion_id, :switches)
    return store[identifier] == true
  end

  def set_expansion_switch_value(expansion_id, switch_id, value)
    identifier = integer(switch_id, 0)
    return false if identifier <= 0
    store = expansion_runtime_store(expansion_id, :switches)
    new_value = value ? true : false
    changed = (store[identifier] != new_value)
    store[identifier] = new_value
    return changed
  end

  def expansion_variable_value(expansion_id, variable_id)
    identifier = integer(variable_id, 0)
    return 0 if identifier <= 0
    store = expansion_runtime_store(expansion_id, :variables)
    return store[identifier] if store.has_key?(identifier)
    return 0
  end

  def set_expansion_variable_value(expansion_id, variable_id, value)
    identifier = integer(variable_id, 0)
    return false if identifier <= 0
    store = expansion_runtime_store(expansion_id, :variables)
    changed = (!store.has_key?(identifier) || store[identifier] != value)
    store[identifier] = value
    return changed
  end

  def expansion_data_root(expansion_id)
    info = external_projects[expansion_id.to_s]
    data_root = info[:data_root].to_s if info.is_a?(Hash)
    return data_root if !data_root.to_s.empty?
    manifest = manifest_for(expansion_id)
    return nil if !manifest
    sample_path = manifest_map_source_path(manifest, 1)
    if !sample_path.to_s.empty?
      return File.dirname(sample_path)
    end
    first_map = manifest[:map_files].is_a?(Array) ? manifest[:map_files].first : nil
    return File.dirname(first_map[:path]) if first_map && first_map[:path]
    return nil
  end

  def expansion_data_path(expansion_id, filename)
    root = expansion_data_root(expansion_id)
    return nil if root.to_s.empty?
    return runtime_path_join(root, filename)
  end

  def load_expansion_data_file(expansion_id, cache_key, filename)
    expansion = expansion_id.to_s
    return nil if expansion.empty?
    cache = runtime_data_cache[expansion] ||= {}
    return cache[cache_key] if cache.has_key?(cache_key)
    path = expansion_data_path(expansion, filename)
    if path.to_s.empty? || !runtime_file_exists?(path)
      cache[cache_key] = nil
      return nil
    end
    cache[cache_key] = load_marshaled_runtime(path)
    return cache[cache_key]
  rescue => e
    log("Compatibility data load failed for #{expansion} #{filename}: #{e.message}")
    cache[cache_key] = nil if cache
    return nil
  end

  def expansion_system_data(expansion_id)
    return load_expansion_data_file(expansion_id, :system, "System.rxdata")
  end

  def expansion_common_events(expansion_id)
    return load_expansion_data_file(expansion_id, :common_events, "CommonEvents.rxdata")
  end

  def expansion_tilesets(expansion_id)
    return load_expansion_data_file(expansion_id, :tilesets, "Tilesets.rxdata")
  end

  def expansion_map_infos(expansion_id)
    return load_expansion_data_file(expansion_id, :map_infos, "MapInfos.rxdata")
  end

  def expansion_tileset_for_map(map_id, map_data = nil)
    expansion_id = current_map_expansion_id(map_id)
    return nil if expansion_id.nil? || expansion_id.empty?
    map = map_data || load_map_data(map_id)
    return nil if !map || !map.respond_to?(:tileset_id)
    tilesets = expansion_tilesets(expansion_id)
    return nil if !tilesets.respond_to?(:[])
    return tilesets[integer(map.tileset_id, 0)]
  rescue => e
    log("External tileset resolution failed for map #{map_id}: #{e.message}")
    return nil
  end

  def expansion_map_display_name(map_id)
    expansion_id = current_map_expansion_id(map_id)
    return nil if expansion_id.nil? || expansion_id.empty?
    map_infos = expansion_map_infos(expansion_id)
    return nil if !map_infos.respond_to?(:[])
    local_id = local_map_id_for(expansion_id, map_id)
    return nil if local_id <= 0
    map_info = map_infos[local_id]
    return nil if !map_info
    return map_info.name if map_info.respond_to?(:name)
    return map_info[:name] if map_info.is_a?(Hash)
    return nil
  rescue => e
    log("External map name resolution failed for map #{map_id}: #{e.message}")
    return nil
  end

  def switch_name_for(expansion_id, switch_id)
    expansion = expansion_id.to_s
    identifier = integer(switch_id, 0)
    if !expansion.empty? && identifier > 0
      system_data = expansion_system_data(expansion)
      if system_data && system_data.respond_to?(:switches)
        begin
          name = system_data.switches[identifier]
          return name if !name.nil?
        rescue
        end
      end
    end
    return $data_system.switches[identifier] if defined?($data_system) && $data_system && $data_system.respond_to?(:switches)
    return nil
  rescue
    return nil
  end

  def expansion_switch_active?(expansion_id, switch_id)
    result = with_runtime_context(expansion_id) { expansion_switch_value(expansion_id, switch_id) }
    return result ? true : false
  end

  def expansion_virtual_map_id(expansion_id, local_map_id)
    manifest = manifest_for(expansion_id)
    return nil if !manifest
    local_id = integer(local_map_id, 0)
    return nil if local_id <= 0
    virtual_id = integer(manifest[:map_block][:start], 0) + local_id
    return virtual_id if current_map_expansion_id(virtual_id).to_s == expansion_id.to_s
    return virtual_id if !expansion_map_entry(virtual_id).nil?
    return nil
  end

  def local_map_id_for(expansion_id, map_id)
    manifest = manifest_for(expansion_id)
    return integer(map_id, 0) if !manifest
    target = integer(map_id, 0)
    start_id = integer(manifest[:map_block][:start], 0)
    size = integer(manifest[:map_block][:size], 0)
    return target if target <= 0 || start_id <= 0 || size <= 0
    return target if target < start_id || target >= start_id + size
    return target - start_id
  end

  def translate_expansion_map_id(expansion_id, map_id)
    expansion = expansion_id.to_s
    return integer(map_id, 0) if expansion.empty?
    target = integer(map_id, 0)
    return target if target <= 0
    return target if current_map_expansion_id(target).to_s == expansion
    translated = expansion_virtual_map_id(expansion, target)
    return translated || target
  end

  def find_expansion_common_event(expansion_id, common_event_id)
    common_events = expansion_common_events(expansion_id)
    return nil if common_events.nil?
    identifier = integer(common_event_id, 0)
    return nil if identifier <= 0
    return common_events[identifier] if common_events.respond_to?(:[])
    return nil
  rescue
    return nil
  end

  def install_external_common_events_for(game_map)
    return if !game_map
    expansion_id = current_map_expansion_id(game_map.map_id)
    return if expansion_id.nil? || expansion_id.to_s.empty?
    common_events = expansion_common_events(expansion_id)
    return if !common_events.respond_to?(:each_with_index)
    current = game_map.instance_variable_get(:@common_events)
    current = {} if !current.is_a?(Hash)
    common_events.each_with_index do |common_event, index|
      next if index <= 0 || !common_event
      key = "tef:#{expansion_id}:#{index}"
      current[key] = ExternalCommonEventRunner.new(expansion_id, index)
    end
    game_map.instance_variable_set(:@common_events, current)
  end

  class ExternalCommonEventRunner
    def initialize(expansion_id, common_event_id)
      @expansion_id = expansion_id.to_s
      @common_event_id = common_event_id
      @interpreter = nil
      refresh
    end

    def common_event
      return TravelExpansionFramework.find_expansion_common_event(@expansion_id, @common_event_id)
    end

    def name
      event = common_event
      return event.name if event && event.respond_to?(:name)
      return "Common Event #{@common_event_id}"
    end

    def trigger
      event = common_event
      return event.trigger if event && event.respond_to?(:trigger)
      return 0
    end

    def switch_id
      event = common_event
      return event.switch_id if event && event.respond_to?(:switch_id)
      return 0
    end

    def list
      event = common_event
      return event.list if event && event.respond_to?(:list)
      return nil
    end

    def switchIsOn?(id)
      switch_name = TravelExpansionFramework.switch_name_for(@expansion_id, id)
      return false if !switch_name
      if switch_name[/^s\:/]
        return eval($~.post_match)
      end
      result = TravelExpansionFramework.with_runtime_context(@expansion_id) { $game_switches[id] }
      return result ? true : false
    end

    def refresh
      if self.trigger == 2 && switchIsOn?(self.switch_id)
        @interpreter ||= Interpreter.new
      else
        @interpreter = nil
      end
    end

    def update
      return if @interpreter.nil?
      if !@interpreter.running?
        event_list = self.list
        return if !event_list
        TravelExpansionFramework.with_runtime_context(@expansion_id, {
          :map_id          => ($game_map ? $game_map.map_id : 0),
          :common_event_id => @common_event_id
        }) do
          @interpreter.setup(event_list, 0, ($game_map ? $game_map.map_id : nil))
        end
      end
      TravelExpansionFramework.with_runtime_context(@expansion_id, {
        :map_id          => ($game_map ? $game_map.map_id : 0),
        :common_event_id => @common_event_id
      }) do
        @interpreter.update
      end
    end
  end
end

class Game_Switches
  alias tef_compat_original_get []
  alias tef_compat_original_set []=

  def [](switch_id)
    expansion_id = TravelExpansionFramework.current_runtime_expansion_id
    expansion_id = TravelExpansionFramework.current_map_expansion_id if expansion_id.nil? || expansion_id.empty?
    return tef_compat_original_get(switch_id) if expansion_id.nil? || expansion_id.empty?
    return TravelExpansionFramework.expansion_switch_value(expansion_id, switch_id)
  end

  def []=(switch_id, value)
    expansion_id = TravelExpansionFramework.current_runtime_expansion_id
    expansion_id = TravelExpansionFramework.current_map_expansion_id if expansion_id.nil? || expansion_id.empty?
    return tef_compat_original_set(switch_id, value) if expansion_id.nil? || expansion_id.empty?
    changed = TravelExpansionFramework.set_expansion_switch_value(expansion_id, switch_id, value)
    $game_map.need_refresh = true if changed && $game_map
    return value
  end
end

class Game_Variables
  alias tef_compat_original_get []
  alias tef_compat_original_set []=

  def [](variable_id)
    expansion_id = TravelExpansionFramework.current_runtime_expansion_id
    expansion_id = TravelExpansionFramework.current_map_expansion_id if expansion_id.nil? || expansion_id.empty?
    return tef_compat_original_get(variable_id) if expansion_id.nil? || expansion_id.empty?
    return TravelExpansionFramework.expansion_variable_value(expansion_id, variable_id)
  end

  def []=(variable_id, value)
    expansion_id = TravelExpansionFramework.current_runtime_expansion_id
    expansion_id = TravelExpansionFramework.current_map_expansion_id if expansion_id.nil? || expansion_id.empty?
    return tef_compat_original_set(variable_id, value) if expansion_id.nil? || expansion_id.empty?
    changed = TravelExpansionFramework.set_expansion_variable_value(expansion_id, variable_id, value)
    $game_map.need_refresh = true if changed && $game_map
    return value
  end
end

class Game_Event
  alias tef_compat_original_refresh refresh
  alias tef_compat_original_switchIsOn? switchIsOn?

  def switchIsOn?(id)
    expansion_id = TravelExpansionFramework.current_runtime_expansion_id || TravelExpansionFramework.current_map_expansion_id(@map_id)
    return tef_compat_original_switchIsOn?(id) if expansion_id.nil? || expansion_id.empty?
    switch_name = TravelExpansionFramework.switch_name_for(expansion_id, id)
    return tef_compat_original_switchIsOn?(id) if switch_name.nil?
    if switch_name[/^s\:/]
      return eval($~.post_match)
    end
    return $game_switches[id]
  end

  def refresh
    expansion_id = TravelExpansionFramework.current_map_expansion_id(@map_id)
    return tef_compat_original_refresh if expansion_id.nil? || expansion_id.empty?
    TravelExpansionFramework.with_runtime_context(expansion_id, {
      :map_id   => @map_id,
      :event_id => @id,
      :event    => self
    }) do
      tef_compat_original_refresh
    end
  end
end

class Game_Map
  alias tef_compat_original_setup setup

  def setup(map_id)
    tef_compat_original_setup(map_id)
    TravelExpansionFramework.install_external_common_events_for(self)
  end
end

class Interpreter
  attr_reader :tef_expansion_id

  alias tef_compat_original_setup setup
  alias tef_compat_original_update update
  alias tef_compat_original_setup_starting_event setup_starting_event
  alias tef_compat_original_pbCommonEvent pbCommonEvent
  alias tef_compat_original_command_if command_if
  alias tef_compat_original_command_111 command_111
  alias tef_compat_original_command_411 command_411
  alias tef_compat_original_command_117 command_117
  alias tef_compat_original_command_122 command_122
  alias tef_compat_original_command_201 command_201 unless method_defined?(:tef_compat_original_command_201)

  def tef_ensure_branch_state!
    return if @branch.is_a?(Hash)
    @branch = {}
    if defined?(TravelExpansionFramework) && TravelExpansionFramework.respond_to?(:log)
      TravelExpansionFramework.log("[interpreter] repaired missing branch state for map #{@map_id}, event #{@event_id}")
    end
  rescue
    @branch = {}
  end

  def setup(list, event_id, map_id = nil)
    tef_compat_original_setup(list, event_id, map_id)
    tef_ensure_branch_state!
    forced_expansion = TravelExpansionFramework.current_runtime_expansion_id
    @tef_expansion_id = if integer(event_id, 0) > 0
                           TravelExpansionFramework.current_map_expansion_id(@map_id)
                        elsif !forced_expansion.nil? && !forced_expansion.empty?
                          forced_expansion
                        else
                          nil
                        end
  end

  def update
    tef_ensure_branch_state!
    if TravelExpansionFramework.respond_to?(:interpreter_stale_for_current_map?) &&
       TravelExpansionFramework.interpreter_stale_for_current_map?(self)
      TravelExpansionFramework.clear_interpreter_state!(self, "stale interpreter update") if TravelExpansionFramework.respond_to?(:clear_interpreter_state!)
      return false
    end
    expansion_id = @tef_expansion_id
    expansion_id = TravelExpansionFramework.current_map_expansion_id if (expansion_id.nil? || expansion_id.empty?) && @main
    return tef_compat_original_update if expansion_id.nil? || expansion_id.empty?
    TravelExpansionFramework.with_runtime_context(expansion_id, {
      :map_id      => @map_id,
      :event_id    => @event_id,
      :interpreter => self
    }) do
      tef_compat_original_update
    end
  end

  def setup_starting_event
    $game_map.refresh if $game_map && $game_map.need_refresh
    if $game_temp.common_event_id > 0
      setup($data_common_events[$game_temp.common_event_id].list, 0)
      $game_temp.common_event_id = 0
      return
    end
    if $game_map
      for event in $game_map.events.values
        next if !event.starting
        if event.trigger < 3
          event.lock
          event.clear_starting
        end
        setup(event.list, event.id, event.map.map_id)
        return
      end
    end
    expansion_id = TravelExpansionFramework.current_map_expansion_id
    if !expansion_id.nil? && !expansion_id.empty?
      common_events = TravelExpansionFramework.expansion_common_events(expansion_id)
      if common_events.respond_to?(:each_with_index)
        common_events.each_with_index do |common_event, index|
          next if index <= 0 || !common_event || common_event.trigger != 1
          next if !TravelExpansionFramework.expansion_switch_active?(expansion_id, common_event.switch_id)
          TravelExpansionFramework.with_runtime_context(expansion_id, {
            :map_id          => ($game_map ? $game_map.map_id : 0),
            :common_event_id => index
          }) do
            setup(common_event.list, 0, ($game_map ? $game_map.map_id : nil))
          end
          return
        end
      end
    end
    tef_compat_original_setup_starting_event
  end

  def pbCommonEvent(id)
    expansion_id = @tef_expansion_id || TravelExpansionFramework.current_runtime_expansion_id
    common_event = TravelExpansionFramework.find_expansion_common_event(expansion_id, id)
    if common_event.nil?
      if !expansion_id.nil? && !expansion_id.empty?
        TravelExpansionFramework.log("Missing expansion common event #{id} for #{expansion_id}; host fallback was blocked.")
        return
      end
      return tef_compat_original_pbCommonEvent(id)
    end
    if $game_temp.in_battle
      TravelExpansionFramework.with_runtime_context(expansion_id, {
        :map_id          => @map_id,
        :event_id        => @event_id,
        :common_event_id => id
      }) do
        $game_system.battle_interpreter.setup(common_event.list, 0, @map_id)
      end
      return
    end
    interp = Interpreter.new
    TravelExpansionFramework.with_runtime_context(expansion_id, {
      :map_id          => @map_id,
      :event_id        => @event_id,
      :common_event_id => id
    }) do
      interp.setup(common_event.list, 0, @map_id)
      loop do
        Graphics.update
        Input.update
        interp.update
        pbUpdateSceneMap
        break if !interp.running?
      end
    end
  end

  def command_if(value)
    tef_ensure_branch_state!
    return tef_compat_original_command_if(value)
  end

  def command_111
    tef_ensure_branch_state!
    if (@tef_expansion_id.nil? || @tef_expansion_id.empty?) || @parameters[0] != 0
      return tef_compat_original_command_111
    end
    switch_name = TravelExpansionFramework.switch_name_for(@tef_expansion_id, @parameters[1])
    result = false
    if switch_name && switch_name[/^s\:/]
      result = (eval($~.post_match) == (@parameters[2] == 0))
    else
      result = ($game_switches[@parameters[1]] == (@parameters[2] == 0))
    end
    @branch[@list[@index].indent] = result
    if @branch[@list[@index].indent]
      @branch.delete(@list[@index].indent)
      return true
    end
    return command_skip
  end

  def command_411
    tef_ensure_branch_state!
    return tef_compat_original_command_411
  end

  def command_117
    common_event = TravelExpansionFramework.find_expansion_common_event(@tef_expansion_id, @parameters[0])
    if common_event.nil?
      if !@tef_expansion_id.nil? && !@tef_expansion_id.empty?
        TravelExpansionFramework.log("Missing expansion common event #{@parameters[0]} for #{@tef_expansion_id}; host fallback was blocked.")
        return true
      end
      return tef_compat_original_command_117
    end
    @child_interpreter = Interpreter.new(@depth + 1)
    TravelExpansionFramework.with_runtime_context(@tef_expansion_id, {
      :map_id          => @map_id,
      :event_id        => @event_id,
      :common_event_id => @parameters[0]
    }) do
      @child_interpreter.setup(common_event.list, @event_id, @map_id)
    end
    return true
  end

  def command_122
    if (@tef_expansion_id.nil? || @tef_expansion_id.empty?) || !(@parameters[3] == 7 && @parameters[4] == 0)
      return tef_compat_original_command_122
    end
    value = TravelExpansionFramework.local_map_id_for(@tef_expansion_id, $game_map.map_id)
    for i in @parameters[0]..@parameters[1]
      case @parameters[2]
      when 0
        next if $game_variables[i] == value
        $game_variables[i] = value
      when 1
        next if $game_variables[i] >= 99_999_999
        $game_variables[i] += value
      when 2
        next if $game_variables[i] <= -99_999_999
        $game_variables[i] -= value
      when 3
        next if value == 1
        $game_variables[i] *= value
      when 4
        next if value == 1 || value == 0
        $game_variables[i] /= value
      when 5
        next if value == 1 || value == 0
        $game_variables[i] %= value
      end
      $game_variables[i] = 99_999_999 if $game_variables[i] > 99_999_999
      $game_variables[i] = -99_999_999 if $game_variables[i] < -99_999_999
      $game_map.need_refresh = true if $game_map
    end
    return true
  end

  def command_201
    source_map_id = integer(@map_id, ($game_map ? $game_map.map_id : 0))
    if defined?(tef_compat_original_command_201)
      raw_target_map_id = if @parameters[0] == 0
        integer(@parameters[1], 0)
      else
        integer($game_variables[@parameters[1]], 0)
      end
      source_expansion = @tef_expansion_id.to_s
      source_expansion = TravelExpansionFramework.current_runtime_expansion_id.to_s if source_expansion.empty?
      source_expansion = TravelExpansionFramework.current_map_expansion_id(source_map_id).to_s if source_expansion.empty? && source_map_id > 0
      target_expansion = TravelExpansionFramework.current_map_expansion_id(raw_target_map_id).to_s
      return tef_compat_original_command_201 if source_expansion.empty? && target_expansion.empty?
    end
    return true if $game_temp.in_battle
    return false if $game_temp.player_transferring ||
                    $game_temp.message_window_showing ||
                    $game_temp.transition_processing
    if @parameters[0] == 0
      target_map_id = @parameters[1]
      target_x = @parameters[2]
      target_y = @parameters[3]
      target_direction = @parameters[4]
    else
      target_map_id = $game_variables[@parameters[1]]
      target_x = $game_variables[@parameters[2]]
      target_y = $game_variables[@parameters[3]]
      target_direction = @parameters[4]
    end
    transfer_expansion = @tef_expansion_id.to_s
    transfer_expansion = source_expansion if transfer_expansion.empty? && defined?(source_expansion)
    target_map_id = TravelExpansionFramework.translate_expansion_map_id(transfer_expansion, target_map_id)
    resume_index = nil
    if TravelExpansionFramework.respond_to?(:rewrite_infinity_lab_stair_transfer)
      rewrite = TravelExpansionFramework.rewrite_infinity_lab_stair_transfer(
        source_map_id,
        (@event_id rescue nil),
        (@index rescue nil),
        (@list rescue nil),
        target_map_id,
        target_x,
        target_y,
        target_direction
      )
      if rewrite.is_a?(Hash)
        target_map_id = rewrite[:map_id] if rewrite.has_key?(:map_id)
        target_x = rewrite[:x] if rewrite.has_key?(:x)
        target_y = rewrite[:y] if rewrite.has_key?(:y)
        target_direction = rewrite[:direction] if rewrite.has_key?(:direction)
        resume_index = rewrite[:resume_index]
      end
    end
    queued = TravelExpansionFramework.safe_transfer_to_anchor({
      :map_id    => target_map_id,
      :x         => target_x,
      :y         => target_y,
      :direction => target_direction
    }, {
      :source            => :story_transfer,
      :expansion_id      => transfer_expansion,
      :allow_story_state => true,
      :immediate         => false,
      :auto_rescue       => false
    })
    if !queued
      $game_temp.player_transferring = false if $game_temp.respond_to?(:player_transferring=)
      return false
    end
    @index += 1
    @index = resume_index if resume_index && integer(resume_index, -1) >= 0
    if @parameters[5] == 0
      Graphics.freeze
      $game_temp.transition_processing = true
      $game_temp.transition_name = ""
    end
    if TravelExpansionFramework.respond_to?(:decades_story_region_transfer?) &&
       TravelExpansionFramework.decades_story_region_transfer?(
         source_map_id,
         (@event_id rescue nil),
         target_map_id
       )
      TravelExpansionFramework.decades_note_story_region_transfer!(target_map_id, "event #{@event_id rescue "?"}") if TravelExpansionFramework.respond_to?(:decades_note_story_region_transfer!)
      @index = @list.length if @list.respond_to?(:length)
    end
    return false
  end

  private

  def integer(value, fallback = 0)
    return TravelExpansionFramework.integer(value, fallback)
  end
end

module TravelExpansionFramework
  EARLY_RELEASE_STUB_METHODS = [
    :pbStoryModeSetup,
    :pbStoryModeGiveDummyStarters,
    :pbStoryModeRemoveDummyStarters,
    :pbStoryModeTrainerItemSuite,
    :pbClearAllPokemonSetup,
    :pbAllPokemonSetup5,
    :pbAllPokemonSetup30,
    :pbAllPokemonSetup50,
    :pbAllPokemonSetup100,
    :pbOptimisedPartyQuickStart5,
    :pbOptimisedPartyQuickStart30,
    :pbOptimisedPartyQuickStart50,
    :pbOptimisedPartyQuickStart100,
    :pbBattleModeSetup5,
    :pbBattleModeSetup30,
    :pbBattleModeSetup50,
    :pbBattleModeSetup100,
    :pbDumpOutAllItems,
    :pbJumpInAllItems,
    :pbPumbInAllItems,
    :pbRemoveBagClutter,
    :pbRemoveStoryModeBagClutter,
    :pbShowTipCard,
    :pbFormTrader,
    :pbFormTraderPC,
    :pbCharacterSelect,
    :pbPokemonSelection,
    :pbGrantRandomPokemonSilent,
    :pbGrantRandomPokemon,
    :pbGetRandomPokemon,
    :pbApplyBattleRule,
    :setBattleRule,
    :pbBattleChallenge,
    :pbBattleChallengeBattle,
    :pbHasEligible?,
    :pbEntryScreen,
    :pbInChallenge?,
    :pbPokeCupRules,
    :pbPikaCupRules,
    :pbPrimeCupRules,
    :pbFancyCupRules,
    :pbLittleCupRules,
    :pbStrictLittleCupRules,
    :pbBattleTowerRules,
    :pbBattlePalaceRules,
    :pbBattleArenaRules,
    :pbBattleFactoryRules,
    :pbWriteCup,
    :pbGenerateChallenge
  ].freeze unless const_defined?(:EARLY_RELEASE_STUB_METHODS)

  class EarlyChallengeRules
    attr_accessor :ruleset

    def initialize(*_args)
      @ruleset = self
      @rules = []
    end

    def copy; return self.class.new; end
    def setRuleset(rule = nil); @ruleset = rule || self; return self; end
    def setBattleType(*args); @rules << [:battle_type, args]; return self; end
    def setLevelAdjustment(*args); @rules << [:level_adjustment, args]; return self; end
    def setNumber(*args); @rules << [:number, args]; return self; end
    def setDoubleBattle(*args); @rules << [:double, args]; return self; end
    def addPokemonRule(*args); @rules << [:pokemon_rule, args]; return self; end
    def addLevelRule(*args); @rules << [:level_rule, args]; return self; end
    def addSubsetRule(*args); @rules << [:subset_rule, args]; return self; end
    def addTeamRule(*args); @rules << [:team_rule, args]; return self; end
    def addBattleRule(*args); @rules << [:battle_rule, args]; return self; end
    def hasValidTeam?(_team = nil); return true; end
    def hasRegistrableTeam?(_team = nil); return true; end
    def canRegisterTeam?(_team = nil); return true; end
    def isValid?(_team = nil, _error = nil); return true; end
    def isPokemonValid?(_pkmn = nil); return true; end
    def suggestedNumber; return 3; end
    def suggestedLevel; return 50; end
    def number; return 3; end
    def name; return "Imported Cup"; end
  end unless const_defined?(:EarlyChallengeRules)

  class EarlyBattleChallengeType
    def saveWins(_challenge = nil); return true; end
  end unless const_defined?(:EarlyBattleChallengeType)

  class EarlyBattleChallenge
    attr_reader :currentChallenge

    def initialize
      @currentChallenge = -1
      @rules = EarlyChallengeRules.new
      @types = {}
    end

    def set(id = nil, _numrounds = nil, rules = nil)
      @currentChallenge = id || -1
      @rules = rules || EarlyChallengeRules.new
      return true
    end

    def register(id = nil, *_args)
      @currentChallenge = id || -1
      return true
    end

    def start(*_args); @currentChallenge = 0 if @currentChallenge == -1; return true; end
    def pbStart(_challenge = nil); return true; end
    def pbEnd; @currentChallenge = -1; return true; end
    def pbBattle; return true; end
    def pbInChallenge?; return false; end
    def pbInProgress?; return false; end
    def pbResting?; return false; end
    def rules; return @rules || EarlyChallengeRules.new; end
    def extra; return nil; end
    def decision; return 0; end
    def wins; return 0; end
    def swaps; return 0; end
    def battleNumber; return 0; end
    def nextTrainer; return 0; end
    def pbGoOn; return true; end
    def pbAddWin; return true; end
    def pbCancel; @currentChallenge = -1; return true; end
    def pbRest; return true; end
    def pbMatchOver?; return true; end
    def pbGoToStart; return true; end
    def setDecision(_value); return true; end
    def setParty(_value); return true; end
    def data; return self; end
    def getCurrentWins(_challenge = nil); return 0; end
    def getPreviousWins(_challenge = nil); return 0; end
    def getMaxWins(_challenge = nil); return 0; end
    def getCurrentSwaps(_challenge = nil); return 0; end
    def getPreviousSwaps(_challenge = nil); return 0; end
    def getMaxSwaps(_challenge = nil); return 0; end
    def ensureType(id); @types[id] ||= EarlyBattleChallengeType.new; return @types[id]; end
  end unless const_defined?(:EarlyBattleChallenge)

  EARLY_STARTER_POOLS = {
    "Final_Starters" => [
      :BULBASAUR, :CHARMANDER, :SQUIRTLE, :PIKACHU, :EEVEE,
      :CHIKORITA, :CYNDAQUIL, :TOTODILE, :TREECKO, :TORCHIC, :MUDKIP,
      :TURTWIG, :CHIMCHAR, :PIPLUP, :SNIVY, :TEPIG, :OSHAWOTT,
      :CHESPIN, :FENNEKIN, :FROAKIE, :ROWLET, :LITTEN, :POPPLIO
    ],
    "Final_Mono_Bug" => [:CATERPIE, :WEEDLE, :PARAS, :VENONAT, :SCYTHER, :PINSIR, :LEDYBA, :SPINARAK, :YANMA, :PINECO, :SHUCKLE, :HERACROSS],
    "Final_Mono_Dark" => [:MURKROW, :HOUNDOUR, :SNEASEL, :UMBREON, :POOCHYENA, :CARVANHA, :SABLEYE, :ABSOL],
    "Final_Mono_Dragon" => [:DRATINI, :HORSEA, :TRAPINCH, :BAGON, :GIBLE, :AXEW],
    "Final_Mono_Electric" => [:PIKACHU, :MAGNEMITE, :VOLTORB, :ELECTABUZZ, :MAREEP, :ELEKID, :SHINX],
    "Final_Mono_Fairy" => [:CLEFAIRY, :JIGGLYPUFF, :TOGEPI, :SNUBBULL, :RALTS, :AZURILL],
    "Final_Mono_Fighting" => [:MANKEY, :MACHOP, :TYROGUE, :MAKUHITA, :MEDITITE, :RIOLU],
    "Final_Mono_Fire" => [:CHARMANDER, :VULPIX, :GROWLITHE, :PONYTA, :MAGBY, :HOUNDOUR, :TORCHIC],
    "Final_Mono_Flying" => [:PIDGEY, :SPEAROW, :ZUBAT, :DODUO, :HOOTHOOT, :TAILLOW],
    "Final_Mono_Ghost" => [:GASTLY, :MISDREAVUS, :SHUPPET, :DUSKULL, :SABLEYE],
    "Final_Mono_Grass" => [:BULBASAUR, :ODDISH, :BELLSPROUT, :CHIKORITA, :TREECKO, :TURTWIG],
    "Final_Mono_Ground" => [:SANDSHREW, :DIGLETT, :CUBONE, :PHANPY, :TRAPINCH, :BALTOY],
    "Final_Mono_Ice" => [:SEEL, :SHELLDER, :SWINUB, :SMOOCHUM, :SNORUNT, :SPHEAL],
    "Final_Mono_Normal" => [:RATTATA, :EEVEE, :MEOWTH, :DODUO, :SENTRET, :ZIGZAGOON],
    "Final_Mono_Poison" => [:EKANS, :ZUBAT, :ODDISH, :VENONAT, :GRIMER, :KOFFING, :GULPIN],
    "Final_Mono_Psychic" => [:ABRA, :DROWZEE, :NATU, :RALTS, :MEDITITE, :SPOINK],
    "Final_Mono_Rock" => [:GEODUDE, :ONIX, :OMANYTE, :KABUTO, :AERODACTYL, :LARVITAR, :NOSEPASS],
    "Final_Mono_Steel" => [:MAGNEMITE, :SKARMORY, :MAWILE, :ARON, :BELDUM],
    "Final_Mono_Water" => [:SQUIRTLE, :PSYDUCK, :POLIWAG, :TENTACOOL, :SLOWPOKE, :KRABBY, :HORSEA, :TOTODILE, :MUDKIP, :PIPLUP]
  }.freeze unless const_defined?(:EARLY_STARTER_POOLS)

  module_function

  def early_species_available?(species)
    candidate = species.respond_to?(:species) ? species.species : species
    candidate = candidate.to_sym if candidate.respond_to?(:to_sym)
    return false if candidate.nil?
    return !GameData::Species.try_get(candidate).nil? if defined?(GameData::Species) && GameData::Species.respond_to?(:try_get)
    return true if !defined?(GameData::Species) || !GameData::Species.respond_to?(:exists?)
    return GameData::Species.exists?(candidate)
  rescue
    return false
  end

  def early_imported_starter_pool(list_id = nil)
    return list_id if list_id.is_a?(Array)
    pools = const_defined?(:EARLY_STARTER_POOLS) ? EARLY_STARTER_POOLS : {}
    key = list_id.to_s
    return early_random_all_types_pool if key == "RANDOM_ALL_TYPES"
    return pools[key] if pools.key?(key)
    return pools["Final_Starters"] || [:BULBASAUR, :CHARMANDER, :SQUIRTLE, :PIKACHU, :EEVEE]
  rescue
    return [:BULBASAUR, :CHARMANDER, :SQUIRTLE, :PIKACHU, :EEVEE]
  end

  def early_random_all_types_pool
    pools = const_defined?(:EARLY_STARTER_POOLS) ? EARLY_STARTER_POOLS : {}
    pool = []
    pools.each do |key, values|
      next unless key.to_s == "Final_Starters" || key.to_s.start_with?("Final_Mono_")
      pool.concat(Array(values))
    end
    pool = [:BULBASAUR, :CHARMANDER, :SQUIRTLE, :PIKACHU, :EEVEE] if pool.empty?
    return pool.compact.uniq
  rescue
    return [:BULBASAUR, :CHARMANDER, :SQUIRTLE, :PIKACHU, :EEVEE]
  end

  def early_pick_imported_starter(list_id = nil, _settings = nil)
    pool = Array(early_imported_starter_pool(list_id)).flatten.compact
    fallback_pool = Array(early_imported_starter_pool("Final_Starters")).flatten.compact
    pool = fallback_pool if pool.empty?
    key = list_id.is_a?(Array) ? "array:#{pool.length}" : list_id.to_s
    @early_imported_starter_offsets ||= Hash.new(0)
    offset = @early_imported_starter_offsets[key].to_i
    chosen = nil
    pool.length.times do |index|
      candidate = pool[(offset + index) % pool.length]
      if early_species_available?(candidate)
        chosen = candidate
        break
      end
    end
    if chosen.nil?
      fallback_pool.length.times do |index|
        candidate = fallback_pool[(offset + index) % fallback_pool.length]
        if early_species_available?(candidate)
          chosen = candidate
          break
        end
      end
    end
    chosen ||= :PIKACHU
    @early_imported_starter_offsets[key] = offset + 1
    record_release_shim_hit("pbPokemonSelection", "startup", "starter_species") if respond_to?(:record_release_shim_hit)
    log("[release] imported starter selection #{key.empty? ? "default" : key} => #{chosen}") if respond_to?(:log)
    return chosen
  rescue => e
    log("[release] imported starter selection failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return :PIKACHU
  end

  def early_imported_starter_settings(settings = nil)
    return settings if settings.is_a?(Hash)
    case settings.to_s
    when "STARTER"
      return { :level => 5, :pokeball => :CHERISHBALL }
    when "FAMILY"
      return { :level => 5, :pokeball => :LOVEBALL }
    else
      return { :level => 5 }
    end
  rescue
    return { :level => 5 }
  end

  def early_build_imported_starter(list_id = nil, settings = nil)
    species = early_pick_imported_starter(list_id, settings)
    options = early_imported_starter_settings(settings)
    level = integer(options[:level], 5) rescue 5
    if defined?(Pokemon)
      pokemon = Pokemon.new(species, level) rescue nil
      if pokemon
        pokemon.poke_ball = options[:pokeball] if options[:pokeball] && pokemon.respond_to?(:poke_ball=)
        return pokemon
      end
    end
    return species
  rescue => e
    log("[release] imported starter build failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return :PIKACHU
  end

  def early_random_available_species(species_pool, fallback = :PIKACHU)
    pool = Array(species_pool).flatten.compact
    pool = early_random_all_types_pool if pool.empty?
    shuffled = pool.sort_by { rand }
    chosen = shuffled.find { |entry| early_species_available?(entry) }
    chosen ||= fallback if early_species_available?(fallback)
    return chosen || fallback
  rescue
    return fallback
  end

  def early_release_default_value(default_name, args = [])
    return release_default_value(default_name, args) if respond_to?(:release_default_value)
    case default_name.to_s
    when "false" then return false
    when "nil" then return nil
    when "array" then return []
    when "zero" then return 0
    when "party_present"
      party = nil
      party = $player.party if defined?($player) && $player && $player.respond_to?(:party)
      party = $Trainer.party if party.nil? && defined?($Trainer) && $Trainer && $Trainer.respond_to?(:party)
      return party.respond_to?(:length) && party.length > 0
    else
      return true
    end
  rescue
    return true
  end

  def early_release_stub(name, default_name = "true", category = "missing_api", *args)
    return release_safe_stub(name, default_name, category, *args) if respond_to?(:release_safe_stub)
    log("[release] early shim #{name} => #{default_name}") if respond_to?(:log)
    return early_release_default_value(default_name, args)
  rescue
    return true
  end

  def early_battle_challenge
    @early_battle_challenge ||= EarlyBattleChallenge.new
    return @early_battle_challenge
  rescue
    return EarlyBattleChallenge.new
  end

  module EarlyInterpreterStubs
    def pbStoryModeSetup(*args)
      if defined?($player) && $player
        $player.has_running_shoes = true if $player.respond_to?(:has_running_shoes=)
        $player.has_pokegear = true if $player.respond_to?(:has_pokegear=)
        $player.has_pokedex = true if $player.respond_to?(:has_pokedex=)
        $player.seen_storage_creator = true if $player.respond_to?(:seen_storage_creator=)
      end
      TravelExpansionFramework.decades_grant_story_mode_kit!(:pbStoryModeSetup) if TravelExpansionFramework.respond_to?(:decades_grant_story_mode_kit!)
      return TravelExpansionFramework.early_release_stub("pbStoryModeSetup", "true", "startup", *args)
    rescue
      return true
    end

    def pbStoryModeGiveDummyStarters(*args)
      return TravelExpansionFramework.early_release_stub("pbStoryModeGiveDummyStarters", "true", "startup", *args)
    end

    def pbStoryModeRemoveDummyStarters(*args)
      return TravelExpansionFramework.early_release_stub("pbStoryModeRemoveDummyStarters", "true", "startup", *args)
    end

    def pbStoryModeTrainerItemSuite(*args)
      TravelExpansionFramework.decades_grant_story_mode_kit!(:pbStoryModeTrainerItemSuite) if TravelExpansionFramework.respond_to?(:decades_grant_story_mode_kit!)
      return TravelExpansionFramework.early_release_stub("pbStoryModeTrainerItemSuite", "true", "item_handlers", *args)
    end

    def pbClearAllPokemonSetup(*args)
      return TravelExpansionFramework.early_release_stub("pbClearAllPokemonSetup", "true", "startup", *args)
    end

    def pbAllPokemonSetup5(*args)
      return TravelExpansionFramework.early_release_stub("pbAllPokemonSetup5", "true", "startup", *args)
    end

    def pbAllPokemonSetup30(*args)
      return TravelExpansionFramework.early_release_stub("pbAllPokemonSetup30", "true", "startup", *args)
    end

    def pbAllPokemonSetup50(*args)
      return TravelExpansionFramework.early_release_stub("pbAllPokemonSetup50", "true", "startup", *args)
    end

    def pbAllPokemonSetup100(*args)
      return TravelExpansionFramework.early_release_stub("pbAllPokemonSetup100", "true", "startup", *args)
    end

    def pbOptimisedPartyQuickStart5(*args)
      return TravelExpansionFramework.early_release_stub("pbOptimisedPartyQuickStart5", "true", "startup", *args)
    end

    def pbOptimisedPartyQuickStart30(*args)
      return TravelExpansionFramework.early_release_stub("pbOptimisedPartyQuickStart30", "true", "startup", *args)
    end

    def pbOptimisedPartyQuickStart50(*args)
      return TravelExpansionFramework.early_release_stub("pbOptimisedPartyQuickStart50", "true", "startup", *args)
    end

    def pbOptimisedPartyQuickStart100(*args)
      return TravelExpansionFramework.early_release_stub("pbOptimisedPartyQuickStart100", "true", "startup", *args)
    end

    def pbBattleModeSetup5(*args)
      return TravelExpansionFramework.early_release_stub("pbBattleModeSetup5", "true", "trainer_battle", *args)
    end

    def pbBattleModeSetup30(*args)
      return TravelExpansionFramework.early_release_stub("pbBattleModeSetup30", "true", "trainer_battle", *args)
    end

    def pbBattleModeSetup50(*args)
      return TravelExpansionFramework.early_release_stub("pbBattleModeSetup50", "true", "trainer_battle", *args)
    end

    def pbBattleModeSetup100(*args)
      return TravelExpansionFramework.early_release_stub("pbBattleModeSetup100", "true", "trainer_battle", *args)
    end

    def pbDumpOutAllItems(*args)
      return TravelExpansionFramework.early_release_stub("pbDumpOutAllItems", "true", "item_handlers", *args)
    end

    def pbJumpInAllItems(*args)
      TravelExpansionFramework.decades_grant_story_mode_kit!(:pbJumpInAllItems) if TravelExpansionFramework.respond_to?(:decades_grant_story_mode_kit!)
      return TravelExpansionFramework.early_release_stub("pbJumpInAllItems", "true", "item_handlers", *args)
    end

    def pbPumbInAllItems(*args)
      TravelExpansionFramework.decades_grant_story_mode_kit!(:pbPumbInAllItems) if TravelExpansionFramework.respond_to?(:decades_grant_story_mode_kit!)
      return TravelExpansionFramework.early_release_stub("pbPumbInAllItems", "true", "item_handlers", *args)
    end

    def pbRemoveBagClutter(*args)
      return TravelExpansionFramework.early_release_stub("pbRemoveBagClutter", "true", "item_handlers", *args)
    end

    def pbRemoveStoryModeBagClutter(*args)
      return TravelExpansionFramework.early_release_stub("pbRemoveStoryModeBagClutter", "true", "item_handlers", *args)
    end

    def pbShowTipCard(*args)
      return TravelExpansionFramework.early_release_stub("pbShowTipCard", "true", "menu_settings", *args)
    end

    def pbFormTrader(*args)
      return TravelExpansionFramework.early_release_stub("pbFormTrader", "true", "item_handlers", *args)
    end

    def pbFormTraderPC(*args)
      return TravelExpansionFramework.early_release_stub("pbFormTraderPC", "host_pc", "item_handlers", *args)
    end

    def pbCharacterSelect(*args)
      return TravelExpansionFramework.early_release_stub("pbCharacterSelect", "true", "startup", *args)
    end

    def pbPokemonSelection(list = nil, must_choose = true, settings = nil)
      return TravelExpansionFramework.early_build_imported_starter(list, settings || must_choose)
    rescue
      return :PIKACHU
    end

    def pbGrantRandomPokemonSilent(pokemon_array, level = 5)
      TravelExpansionFramework.early_release_stub("pbGrantRandomPokemonSilent", "true", "startup", pokemon_array, level)
      species = TravelExpansionFramework.early_random_available_species(pokemon_array)
      return pbAddPokemonSilent(species, level) if defined?(pbAddPokemonSilent)
      return pbAddPokemon(species, level) if defined?(pbAddPokemon)
      return true
    rescue => e
      TravelExpansionFramework.log("[release] early pbGrantRandomPokemonSilent failed safely: #{e.class}: #{e.message}") if TravelExpansionFramework.respond_to?(:log)
      return true
    end

    def pbGrantRandomPokemon(pokemon_array, level = 5)
      TravelExpansionFramework.early_release_stub("pbGrantRandomPokemon", "true", "startup", pokemon_array, level)
      species = TravelExpansionFramework.early_random_available_species(pokemon_array)
      return pbAddPokemon(species, level) if defined?(pbAddPokemon)
      return pbAddPokemonSilent(species, level) if defined?(pbAddPokemonSilent)
      return true
    rescue => e
      TravelExpansionFramework.log("[release] early pbGrantRandomPokemon failed safely: #{e.class}: #{e.message}") if TravelExpansionFramework.respond_to?(:log)
      return true
    end

    def pbGetRandomPokemon(pokemon_array)
      return TravelExpansionFramework.early_random_available_species(pokemon_array)
    rescue
      return :PIKACHU
    end

    def pbApplyBattleRule(rule, _value_type = nil, set_value = true, *_args)
      return TravelExpansionFramework.release_safe_set_battle_rule!(rule, set_value) if TravelExpansionFramework.respond_to?(:release_safe_set_battle_rule!)
      return TravelExpansionFramework.early_release_stub("pbApplyBattleRule", "record_imported", "trainer_battle", rule, set_value)
    end

    def setBattleRule(*args)
      return TravelExpansionFramework.release_safe_set_battle_rule!(*args) if TravelExpansionFramework.respond_to?(:release_safe_set_battle_rule!)
      return TravelExpansionFramework.early_release_stub("setBattleRule", "record_imported", "trainer_battle", *args)
    end

    def pbBattleChallenge(*_args)
      return TravelExpansionFramework.early_battle_challenge
    end

    def pbBattleChallengeBattle(*_args)
      return pbBattleChallenge.pbBattle
    end

    def pbHasEligible?(*_args)
      return true
    end

    def pbEntryScreen(*_args)
      return true
    end

    def pbInChallenge?(*_args)
      challenge = pbBattleChallenge
      return challenge.pbInChallenge? if challenge.respond_to?(:pbInChallenge?)
      return false
    rescue
      return false
    end

    def pbPokeCupRules(double = false); return TravelExpansionFramework::EarlyChallengeRules.new(double); end
    def pbPikaCupRules(double = false); return TravelExpansionFramework::EarlyChallengeRules.new(double); end
    def pbPrimeCupRules(double = false); return TravelExpansionFramework::EarlyChallengeRules.new(double); end
    def pbFancyCupRules(double = false); return TravelExpansionFramework::EarlyChallengeRules.new(double); end
    def pbLittleCupRules(double = false); return TravelExpansionFramework::EarlyChallengeRules.new(double); end
    def pbStrictLittleCupRules(double = false); return TravelExpansionFramework::EarlyChallengeRules.new(double); end
    def pbBattleTowerRules(double = false, openlevel = false); return TravelExpansionFramework::EarlyChallengeRules.new(double, openlevel); end
    def pbBattlePalaceRules(double = false, openlevel = false); return TravelExpansionFramework::EarlyChallengeRules.new(double, openlevel); end
    def pbBattleArenaRules(openlevel = false); return TravelExpansionFramework::EarlyChallengeRules.new(openlevel); end
    def pbBattleFactoryRules(double = false, openlevel = false); return TravelExpansionFramework::EarlyChallengeRules.new(double, openlevel); end

    def pbWriteCup(*args)
      return TravelExpansionFramework.early_release_stub("pbWriteCup", "true", "trainer_battle", *args)
    end

    def pbGenerateChallenge(*args)
      return TravelExpansionFramework.early_release_stub("pbGenerateChallenge", "true", "trainer_battle", *args)
    end
  end unless const_defined?(:EarlyInterpreterStubs)
end

Object.const_set(:RANDOM_ALL_TYPES, TravelExpansionFramework.early_random_all_types_pool) unless Object.const_defined?(:RANDOM_ALL_TYPES, false)

if defined?(Interpreter) && !Interpreter.const_defined?(:RANDOM_ALL_TYPES, false)
  Interpreter.const_set(:RANDOM_ALL_TYPES, Object.const_get(:RANDOM_ALL_TYPES))
end

class BattleChallenge < TravelExpansionFramework::EarlyBattleChallenge
end unless defined?(BattleChallenge)

class PokemonChallengeRules < TravelExpansionFramework::EarlyChallengeRules
end unless defined?(PokemonChallengeRules)

class PokemonRuleSet < TravelExpansionFramework::EarlyChallengeRules
end unless defined?(PokemonRuleSet)

class Object
  include TravelExpansionFramework::EarlyInterpreterStubs unless ancestors.include?(TravelExpansionFramework::EarlyInterpreterStubs)
  TravelExpansionFramework::EARLY_RELEASE_STUB_METHODS.each do |method_name|
    private method_name if method_defined?(method_name) || private_method_defined?(method_name)
  end
end

if defined?(Interpreter)
  class Interpreter
    include TravelExpansionFramework::EarlyInterpreterStubs unless ancestors.include?(TravelExpansionFramework::EarlyInterpreterStubs)
  end
end
