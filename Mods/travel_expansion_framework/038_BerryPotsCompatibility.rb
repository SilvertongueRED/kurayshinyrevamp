if defined?(TravelExpansionFramework)
  module TravelExpansionFramework
    module_function

    BERRY_POTS_ITEM_NAME = "BERRYPOTS" unless const_defined?(:BERRY_POTS_ITEM_NAME)
    BERRY_POTS_SOURCE_EXPANSIONS = [
      "keishou",
      "pokemon_keishou",
      "solar_eclipse",
      "vanguard"
    ].freeze unless const_defined?(:BERRY_POTS_SOURCE_EXPANSIONS)
    BERRY_POTS_LEGACY_EXPANSIONS = (
      BERRY_POTS_SOURCE_EXPANSIONS + ["darkhorizon", "infinity"]
    ).freeze unless const_defined?(:BERRY_POTS_LEGACY_EXPANSIONS)
    BERRY_POTS_DEFAULT_COUNT = 4 unless const_defined?(:BERRY_POTS_DEFAULT_COUNT)
    BERRY_POTS_SOLAR_COUNT = 6 unless const_defined?(:BERRY_POTS_SOLAR_COUNT)
    BERRY_POTS_MAX_COUNT = 10 unless const_defined?(:BERRY_POTS_MAX_COUNT)
    BERRY_POTS_WATERING_CANS = [
      :SPRAYDUCK,
      :SQUIRTBOTTLE,
      :WAILMERPAIL,
      :SPRINKLOTAD
    ].freeze unless const_defined?(:BERRY_POTS_WATERING_CANS)

    def berry_pots_now
      return pbGetTimeNow.to_i if defined?(pbGetTimeNow)
      return Time.now.to_i
    rescue
      return Time.now.to_i
    end

    def berry_pots_source_for_item(item)
      raw = item.respond_to?(:id) ? item.id : item
      value = raw.to_s.downcase
      return "solar_eclipse" if value.include?("solar_eclipse")
      BERRY_POTS_SOURCE_EXPANSIONS.each do |expansion|
        return expansion if value.include?(expansion)
      end
      active = active_item_lookup_expansion_id if respond_to?(:active_item_lookup_expansion_id)
      return active.to_s if BERRY_POTS_SOURCE_EXPANSIONS.include?(active.to_s)
      return "keishou"
    rescue
      return "keishou"
    end

    def berry_pots_default_count_for_item(item = nil)
      return BERRY_POTS_SOLAR_COUNT if berry_pots_source_for_item(item) == "solar_eclipse"
      return BERRY_POTS_DEFAULT_COUNT
    rescue
      return BERRY_POTS_DEFAULT_COUNT
    end

    def berry_pots_empty_slot
      [0, nil, 0, berry_pots_now, 0, 0, 0, nil]
    end

    def berry_pots_normalize_slot(slot)
      now = berry_pots_now
      return berry_pots_empty_slot if slot.nil? || slot == 0 || slot == []
      if slot.is_a?(Array) && slot.length >= 8
        stage = slot[0].to_i
        return berry_pots_empty_slot if stage <= 0 || slot[1].nil?
        return [
          stage.clamp(0, 5),
          slot[1],
          [slot[2].to_i, 0].max,
          slot[3].to_i > 0 ? slot[3].to_i : now,
          slot[4].to_i.clamp(0, 100),
          [slot[5].to_i, 0].max,
          [slot[6].to_i, 0].max,
          slot[7]
        ]
      end
      if slot.is_a?(Array) && slot.length >= 5
        berry = slot[0]
        stage = slot[1].to_i
        return berry_pots_empty_slot if stage <= 0 || berry.nil?
        watered = slot[3].to_i > 0
        return [
          stage.clamp(0, 5),
          berry,
          0,
          slot[2].to_i > 0 ? slot[2].to_i : now,
          watered ? 100 : 0,
          0,
          watered ? 0 : 1,
          slot[4]
        ]
      end
      return berry_pots_empty_slot
    rescue
      return berry_pots_empty_slot
    end

    def berry_pots_count(default_count = nil)
      return default_count.to_i.clamp(1, BERRY_POTS_MAX_COUNT) if !defined?($PokemonGlobal) || !$PokemonGlobal
      current = $PokemonGlobal.berrypot_count if $PokemonGlobal.respond_to?(:berrypot_count)
      current = current.to_i
      current = default_count.to_i if current <= 0 && default_count.to_i > 0
      current = BERRY_POTS_DEFAULT_COUNT if current <= 0
      current = current.clamp(1, BERRY_POTS_MAX_COUNT)
      $PokemonGlobal.berrypot_count = current if $PokemonGlobal.respond_to?(:berrypot_count=)
      return current
    rescue
      return BERRY_POTS_DEFAULT_COUNT
    end

    def berry_pots_state(default_count = nil)
      return [] if !defined?($PokemonGlobal) || !$PokemonGlobal
      count = berry_pots_count(default_count)
      pots = $PokemonGlobal.berrypots if $PokemonGlobal.respond_to?(:berrypots)
      pots = [] if !pots.is_a?(Array)
      0.upto(count - 1) do |i|
        pots[i] = berry_pots_normalize_slot(pots[i])
        berry_pots_update_slot!(pots[i])
      end
      pots = pots[0, count]
      $PokemonGlobal.berrypots = pots if $PokemonGlobal.respond_to?(:berrypots=)
      return pots
    rescue => e
      log("[berrypots] state recovery failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
      return []
    end

    def berry_pots_set_count(count)
      return false if !defined?($PokemonGlobal) || !$PokemonGlobal
      count = count.to_i.clamp(1, BERRY_POTS_MAX_COUNT)
      $PokemonGlobal.berrypot_count = count if $PokemonGlobal.respond_to?(:berrypot_count=)
      berry_pots_state(count)
      return true
    rescue => e
      log("[berrypots] count update failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
      return false
    end

    def berry_pots_plant_data(berry)
      return nil if !defined?(GameData::BerryPlant)
      return GameData::BerryPlant.try_get(berry) if GameData::BerryPlant.respond_to?(:try_get)
      return GameData::BerryPlant.get(berry)
    rescue
      return nil
    end

    def berry_pots_hours_per_stage(berry)
      data = berry_pots_plant_data(berry)
      hours = data.hours_per_stage if data && data.respond_to?(:hours_per_stage)
      hours = 3 if hours.to_i <= 0
      return hours.to_i
    rescue
      return 3
    end

    def berry_pots_drying_per_hour(berry)
      data = berry_pots_plant_data(berry)
      drying = data.drying_per_hour if data && data.respond_to?(:drying_per_hour)
      drying = 15 if drying.to_i <= 0
      return drying.to_i
    rescue
      return 15
    end

    def berry_pots_update_slot!(slot)
      slot = berry_pots_normalize_slot(slot)
      return slot if slot[0].to_i <= 0 || slot[1].nil?
      now = berry_pots_now
      elapsed = [now - slot[3].to_i, 0].max
      return slot if elapsed <= 0
      berry = slot[1]
      time_per_stage = [berry_pots_hours_per_stage(berry) * 3600, 1].max
      old_hours = slot[2].to_i / 3600
      slot[2] = [slot[2].to_i + elapsed, 0].max
      slot[3] = now
      if slot[0].to_i < 5
        slot[0] = (1 + (slot[2].to_i / time_per_stage)).clamp(1, 5)
        new_hours = [slot[2].to_i / 3600, time_per_stage * 4 / 3600].min
        hour_ticks = [new_hours - old_hours, 0].max
        hour_ticks.times do
          if slot[4].to_i > 0
            slot[4] = [slot[4].to_i - berry_pots_drying_per_hour(berry), 0].max
          else
            slot[6] = slot[6].to_i + 1
          end
        end
      end
      return slot
    rescue
      return slot
    end

    def berry_pots_item_data(item)
      return nil if item.nil? || !defined?(GameData::Item)
      return GameData::Item.try_get(item) if GameData::Item.respond_to?(:try_get)
      return GameData::Item.get(item)
    rescue
      return nil
    end

    def berry_pots_item_name(item, quantity = 1)
      data = berry_pots_item_data(item)
      return item.to_s if data.nil?
      if quantity.to_i != 1 && data.respond_to?(:name_plural)
        return data.name_plural
      end
      return data.name if data.respond_to?(:name)
      return data.id.to_s
    rescue
      return item.to_s
    end

    def berry_pots_available_berries
      return [] if !defined?($PokemonBag) || !$PokemonBag || !defined?(GameData::Item)
      found = {}
      pockets = $PokemonBag.instance_variable_get(:@pockets) if $PokemonBag.respond_to?(:instance_variable_get)
      Array(pockets).each do |pocket|
        Array(pocket).each do |slot|
          next if !slot || slot[1].to_i <= 0
          data = berry_pots_item_data(slot[0])
          next if !data || !data.respond_to?(:is_berry?) || !data.is_berry?
          quantity = $PokemonBag.pbQuantity(data.id) rescue slot[1].to_i
          found[data.id] = [data, quantity.to_i] if quantity.to_i > 0
        end
      end
      if found.empty? && GameData::Item.respond_to?(:each)
        GameData::Item.each do |data|
          next if !data.respond_to?(:is_berry?) || !data.is_berry?
          quantity = $PokemonBag.pbQuantity(data.id) rescue 0
          found[data.id] = [data, quantity.to_i] if quantity.to_i > 0
        end
      end
      return found.values.sort_by { |entry| entry[0].name.to_s }
    rescue => e
      log("[berrypots] berry list failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
      return []
    end

    def berry_pots_choose_berry
      berries = berry_pots_available_berries
      if berries.empty?
        pbMessage(_INTL("You do not have any Berries that can be planted.")) if defined?(pbMessage)
        return nil
      end
      commands = berries.map { |data, qty| _INTL("{1} x{2}", data.name, qty) }
      commands << _INTL("Cancel")
      choice = pbMessage(_INTL("Which Berry do you want to plant?"), commands, commands.length)
      return nil if choice.nil? || choice < 0 || choice >= berries.length
      return berries[choice][0].id
    rescue => e
      log("[berrypots] berry choice failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
      return nil
    end

    def berry_pots_watering_can
      return nil if !defined?($PokemonBag) || !$PokemonBag
      BERRY_POTS_WATERING_CANS.each do |item|
        data = berry_pots_item_data(item)
        next if !data
        return data.id if ($PokemonBag.pbQuantity(data.id) rescue 0) > 0
      end
      return nil
    rescue
      return nil
    end

    def berry_pots_yield(slot)
      data = berry_pots_plant_data(slot[1])
      minimum = data && data.respond_to?(:minimum_yield) ? data.minimum_yield.to_i : 2
      maximum = data && data.respond_to?(:maximum_yield) ? data.maximum_yield.to_i : 5
      minimum = 1 if minimum <= 0
      maximum = minimum if maximum < minimum
      return [maximum - slot[6].to_i, minimum].max
    rescue
      return 2
    end

    def berry_pots_stage_name(slot)
      case slot[0].to_i
      when 0 then _INTL("Empty")
      when 1 then _INTL("Planted")
      when 2 then _INTL("Sprouted")
      when 3 then _INTL("Growing")
      when 4 then _INTL("Blooming")
      else _INTL("Ready")
      end
    end

    def berry_pots_summary(slot, index)
      slot = berry_pots_update_slot!(slot)
      return _INTL("Pot {1}: Empty", index + 1) if slot[0].to_i <= 0 || slot[1].nil?
      return _INTL("Pot {1}: {2} ({3})", index + 1, berry_pots_item_name(slot[1]), berry_pots_stage_name(slot))
    rescue
      return _INTL("Pot {1}: Empty", index + 1)
    end

    def berry_pots_describe_slot(slot)
      slot = berry_pots_update_slot!(slot)
      if slot[0].to_i <= 0 || slot[1].nil?
        pbMessage(_INTL("It's soft, earthy soil.")) if defined?(pbMessage)
        return
      end
      berry = berry_pots_item_name(slot[1])
      case slot[0].to_i
      when 1
        pbMessage(_INTL("A {1} was planted here.", berry)) if defined?(pbMessage)
      when 2
        pbMessage(_INTL("The {1} has sprouted.", berry)) if defined?(pbMessage)
      when 3
        pbMessage(_INTL("The {1} plant is growing bigger.", berry)) if defined?(pbMessage)
      when 4
        pbMessage(_INTL("This {1} plant is in bloom!", berry)) if defined?(pbMessage)
      else
        qty = berry_pots_yield(slot)
        pbMessage(_INTL("There are {1} {2}.", qty, berry_pots_item_name(slot[1], qty))) if defined?(pbMessage)
      end
    rescue
    end

    def berry_pots_plant_in_slot!(pots, index)
      berry = berry_pots_choose_berry
      return false if berry.nil?
      if !$PokemonBag.pbDeleteItem(berry, 1)
        pbMessage(_INTL("That Berry could not be planted.")) if defined?(pbMessage)
        return false
      end
      pots[index] = [1, berry, 0, berry_pots_now, 100, 0, 0, nil]
      pbMessage(_INTL("The {1} was planted in the soft, earthy soil.", berry_pots_item_name(berry))) if defined?(pbMessage)
      return true
    rescue => e
      log("[berrypots] planting failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
      pbMessage(_INTL("That Berry could not be planted.")) if defined?(pbMessage)
      return false
    end

    def berry_pots_water_slot!(slot)
      can = berry_pots_watering_can
      if can.nil?
        pbMessage(_INTL("You need a watering can to water Berries.")) if defined?(pbMessage)
        return false
      end
      slot[4] = 100
      pbMessage(_INTL("{1} watered the plant.", $Trainer ? $Trainer.name : "You")) if defined?(pbMessage)
      pbMessage(_INTL("There! All happy!")) if defined?(pbMessage)
      return true
    rescue => e
      log("[berrypots] watering failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
      return false
    end

    def berry_pots_pick_slot!(pots, index)
      slot = berry_pots_update_slot!(pots[index])
      return false if slot[0].to_i < 5 || slot[1].nil?
      qty = berry_pots_yield(slot)
      berry = slot[1]
      if $PokemonBag.respond_to?(:pbCanStore?) && !$PokemonBag.pbCanStore?(berry, qty)
        pbMessage(_INTL("Too bad... The Bag is full.")) if defined?(pbMessage)
        return false
      end
      if !$PokemonBag.pbStoreItem(berry, qty)
        pbMessage(_INTL("The Berries could not be added to the Bag.")) if defined?(pbMessage)
        return false
      end
      pbMEPlay("Berry Obtained") if defined?(pbMEPlay)
      pbMessage(_INTL("You picked the {1} {2}.", qty, berry_pots_item_name(berry, qty))) if defined?(pbMessage)
      pots[index] = berry_pots_empty_slot
      return true
    rescue => e
      log("[berrypots] picking failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
      return false
    end

    def berry_pots_manage_slot!(pots, index)
      slot = berry_pots_update_slot!(pots[index])
      if slot[0].to_i <= 0 || slot[1].nil?
        commands = [_INTL("Plant Berry"), _INTL("Cancel")]
        choice = pbMessage(_INTL("It's soft, earthy soil."), commands, commands.length)
        return berry_pots_plant_in_slot!(pots, index) if choice == 0
        return false
      end

      loop do
        berry_pots_describe_slot(slot)
        commands = []
        commands << _INTL("Pick Berries") if slot[0].to_i >= 5
        commands << _INTL("Water")
        commands << _INTL("Dig Up")
        commands << _INTL("Cancel")
        choice = pbMessage(_INTL("What do you want to do?"), commands, commands.length)
        command = commands[choice] if choice && choice >= 0 && choice < commands.length
        case command
        when _INTL("Pick Berries")
          return berry_pots_pick_slot!(pots, index)
        when _INTL("Water")
          berry_pots_water_slot!(slot)
        when _INTL("Dig Up")
          if !defined?(pbConfirmMessage) || pbConfirmMessage(_INTL("Remove this plant from the pot?"))
            pots[index] = berry_pots_empty_slot
            pbMessage(_INTL("The soil returned to its soft and earthy state.")) if defined?(pbMessage)
            return true
          end
        else
          return false
        end
        pots[index] = slot
      end
    rescue => e
      log("[berrypots] pot menu failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
      return false
    end

    def open_berry_pots!(item = nil)
      default_count = berry_pots_default_count_for_item(item)
      pots = berry_pots_state(default_count)
      if pots.empty?
        pbMessage(_INTL("The Berry Pots cannot be opened right now.")) if defined?(pbMessage)
        return false
      end
      record_release_shim_hit("BerryPots", "item_handlers", berry_pots_source_for_item(item)) if respond_to?(:record_release_shim_hit)
      loop do
        pots.each_index { |i| berry_pots_update_slot!(pots[i]) }
        commands = pots.each_with_index.map { |slot, i| berry_pots_summary(slot, i) }
        commands << _INTL("Cancel")
        choice = pbMessage(_INTL("Berry Pots"), commands, commands.length)
        break if choice.nil? || choice < 0 || choice >= pots.length
        berry_pots_manage_slot!(pots, choice)
        $PokemonGlobal.berrypots = pots if defined?($PokemonGlobal) && $PokemonGlobal.respond_to?(:berrypots=)
      end
      return true
    rescue => e
      log("[berrypots] failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
      pbMessage(_INTL("The Berry Pots cannot be opened right now.")) if defined?(pbMessage)
      return false
    end

    def receive_berry_pots!(count = 1)
      current = berry_pots_count(BERRY_POTS_DEFAULT_COUNT)
      new_count = [current + count.to_i, BERRY_POTS_MAX_COUNT].min
      berry_pots_set_count(new_count)
      return true
    rescue => e
      log("[berrypots] receive pots failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
      return false
    end

    def berry_pots_item_aliases
      aliases = [:BERRYPOTS]
      BERRY_POTS_LEGACY_EXPANSIONS.each do |expansion|
        if respond_to?(:imported_item_runtime_symbol)
          runtime = imported_item_runtime_symbol(expansion, BERRY_POTS_ITEM_NAME) rescue nil
          aliases << runtime if runtime
        end
      end
      if defined?(GameData::Item::DATA) && GameData::Item::DATA.is_a?(Hash)
        GameData::Item::DATA.each_value do |data|
          next if !data.respond_to?(:id)
          aliases << data.id if data.id.to_s.upcase.end_with?("BERRYPOTS")
        end
      end
      return aliases.compact.uniq
    rescue
      return [:BERRYPOTS, :TEF_DARKHORIZON_BERRYPOTS]
    end

    def register_berry_pots_item_handlers!
      return false if !defined?(ItemHandlers)
      berry_pots_item_aliases.each do |symbol|
        ItemHandlers::UseFromBag.add(symbol, proc { |item|
          TravelExpansionFramework.open_berry_pots!(item)
          next 1
        })
        ItemHandlers::UseInField.add(symbol, proc { |item|
          TravelExpansionFramework.open_berry_pots!(item)
          next 1
        })
      end
      return true
    rescue => e
      log("[berrypots] item handler registration failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
      return false
    end

    class << self
      if method_defined?(:known_imported_item_origin_id) &&
         !method_defined?(:tef_berry_pots_original_known_imported_item_origin_id)
        alias tef_berry_pots_original_known_imported_item_origin_id known_imported_item_origin_id
      end

      def known_imported_item_origin_id(item_identifier)
        normalized = normalized_imported_item_name(item_identifier) rescue item_identifier.to_s.upcase.gsub(/[^\w]+/, "")
        if normalized == BERRY_POTS_ITEM_NAME
          active = active_item_lookup_expansion_id rescue nil
          return active.to_s if BERRY_POTS_SOURCE_EXPANSIONS.include?(active.to_s)
          cached = imported_item_origin_cache[normalized] rescue nil
          return cached.to_s if BERRY_POTS_SOURCE_EXPANSIONS.include?(cached.to_s)
          BERRY_POTS_SOURCE_EXPANSIONS.each do |expansion|
            catalog = generic_pbs_item_catalog(expansion) rescue nil
            return expansion if catalog.is_a?(Hash) && catalog.has_key?(normalized)
          end
          return "keishou"
        end
        if respond_to?(:tef_berry_pots_original_known_imported_item_origin_id)
          return tef_berry_pots_original_known_imported_item_origin_id(item_identifier)
        end
        return nil
      end

      if method_defined?(:ensure_external_item_registered) &&
         !method_defined?(:tef_berry_pots_original_ensure_external_item_registered)
        alias tef_berry_pots_original_ensure_external_item_registered ensure_external_item_registered
      end

      def ensure_external_item_registered(expansion_id, item_identifier)
        result = nil
        if respond_to?(:tef_berry_pots_original_ensure_external_item_registered)
          result = tef_berry_pots_original_ensure_external_item_registered(expansion_id, item_identifier)
        end
        normalized = normalized_imported_item_name(item_identifier) rescue item_identifier.to_s.upcase.gsub(/[^\w]+/, "")
        register_berry_pots_item_handlers! if normalized == BERRY_POTS_ITEM_NAME ||
                                             result.to_s.upcase.end_with?("BERRYPOTS")
        return result
      end
    end

    register_berry_pots_item_handlers!
  end
end

if defined?(PokemonGlobalMetadata)
  class PokemonGlobalMetadata
    attr_accessor :berrypots unless method_defined?(:berrypots)
    attr_accessor :berrypot_count unless method_defined?(:berrypot_count)
    attr_accessor :berrypots_can unless method_defined?(:berrypots_can)
  end
end

def pbBerryPots
  return TravelExpansionFramework.open_berry_pots! if defined?(TravelExpansionFramework)
  return false
end unless defined?(pbBerryPots)

def pbReceivePots(count = 1)
  return TravelExpansionFramework.receive_berry_pots!(count) if defined?(TravelExpansionFramework)
  return false
end unless defined?(pbReceivePots)
