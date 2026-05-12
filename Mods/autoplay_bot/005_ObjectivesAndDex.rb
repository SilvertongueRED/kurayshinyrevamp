module AutoplayBot
  def self.helper(name, *args)
    receiver = Object.new
    return receiver.send(name, *args) if receiver.respond_to?(name, true)
    nil
  rescue
    nil
  end

  module GuidePack
    module_function

    def data
      load! unless @loaded
      @data
    end

    def load!
      path = AutoplayBot::Config.guide_pack_path
      @data = File.exist?(path) ? AutoplayBot::JSON.parse(File.read(path)) : default_data
      @data = default_data unless @data.is_a?(Hash)
      @loaded = true
      @data
    rescue => e
      @data = default_data
      @loaded = true
      AutoplayBot.log("guide load failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      @data
    end

    def default_data
      { "version" => 1, "name" => "Empty", "objectives" => [] }
    end

    def objectives
      data["objectives"].is_a?(Array) ? data["objectives"] : []
    end

    def objective(id)
      objectives.find { |obj| obj["id"].to_s == id.to_s }
    end

    def first_objective
      objectives.first
    end
  end

  module DexTracker
    module_function

    def copy_goal
      desired = AutoplayBot::Config.copy_goal.to_i
      return 1 if desired <= 1
      storage_room? ? desired : 1
    end

    def storage_room?
      return false unless defined?($PokemonStorage) && $PokemonStorage
      return !$PokemonStorage.full? if $PokemonStorage.respond_to?(:full?)
      true
    rescue
      false
    end

    def state_ready?
      defined?(AutoplayBot::State) &&
        (!AutoplayBot::State.respond_to?(:loaded?) || AutoplayBot::State.loaded?)
    rescue
      false
    end

    def frame_count
      Graphics.frame_count rescue 0
    end

    def invalidate_live_counts!
      @live_counts_cache = nil
      @live_counts_cache_frame = nil
    rescue
      nil
    end

    def pokemon_species(pokemon_or_species)
      return nil if pokemon_or_species.nil?
      return pokemon_or_species.species if pokemon_or_species.respond_to?(:species)
      pokemon_or_species
    end

    def species_key(species)
      return nil if species.nil?
      if defined?(GameData::Species)
        data = GameData::Species.get(species) rescue nil
        return data.id.to_s if data && data.respond_to?(:id)
      end
      species.to_s
    end

    def species_name(species)
      return species_key(species).to_s if species.nil?
      if defined?(GameData::Species)
        data = GameData::Species.get(species) rescue nil
        if data
          return data.real_name.to_s if data.respond_to?(:real_name) && data.real_name
          return data.name.to_s if data.respond_to?(:name) && data.name
          return data.id.to_s if data.respond_to?(:id)
        end
      end
      species.to_s
    rescue
      species.to_s
    end

    def base_species_for(pokemon_or_species)
      species = pokemon_species(pokemon_or_species)
      return [] if species.nil?
      if AutoplayBot.helper(:species_is_fusion, species)
        body_id = AutoplayBot.helper(:getBodyID, species)
        head_id = AutoplayBot.helper(:getHeadID, species, body_id)
        return [species_key(body_id), species_key(head_id)].compact.uniq
      end
      [species_key(species)].compact
    rescue
      [species_key(species)].compact
    end

    def fusion_key_for(pokemon_or_species)
      return nil unless defined?(AutoplayBot::Config) && AutoplayBot::Config.fusion_collection?
      species = pokemon_species(pokemon_or_species)
      return nil if species.nil?
      return nil unless AutoplayBot.helper(:species_is_fusion, species)
      body_id = AutoplayBot.helper(:getBodyID, species)
      head_id = AutoplayBot.helper(:getHeadID, species, body_id)
      head_key = species_key(head_id)
      body_key = species_key(body_id)
      return nil if head_key.to_s.empty? || body_key.to_s.empty?
      "#{head_key}+#{body_key}"
    rescue
      nil
    end

    def fusion_record_info(pokemon_or_species, map_id = nil)
      species = pokemon_species(pokemon_or_species)
      {
        "map" => map_id || (defined?($game_map) && $game_map ? $game_map.map_id : nil),
        "species" => species_key(species),
        "label" => species_name(species)
      }
    rescue
      {}
    end

    def add_counts_from(counts, pokemon)
      return unless pokemon
      base_species_for(pokemon).each do |key|
        counts[key] = counts[key].to_i + 1
      end
    end

    def live_counts
      frame = frame_count
      if @live_counts_cache && @live_counts_cache_frame &&
         frame.to_i - @live_counts_cache_frame.to_i < 90
        return @live_counts_cache
      end
      counts = {}
      if defined?($Trainer) && $Trainer && $Trainer.respond_to?(:party)
        $Trainer.party.each { |pkmn| add_counts_from(counts, pkmn) }
      end
      if defined?($PokemonStorage) && $PokemonStorage && $PokemonStorage.respond_to?(:boxes)
        $PokemonStorage.boxes.each do |box|
          next unless box && box.respond_to?(:each)
          box.each { |pkmn| add_counts_from(counts, pkmn) }
        end
      end
      @live_counts_cache = counts
      @live_counts_cache_frame = frame
      counts
    rescue => e
      AutoplayBot.log("dex count failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      counts || {}
    end

    def owned_by_pokedex?(species_key)
      return false unless defined?($Trainer) && $Trainer && $Trainer.respond_to?(:owned?)
      $Trainer.owned?(species_key.to_sym) || $Trainer.owned?(species_key.to_s)
    rescue
      false
    end

    def desired_count_for(_species_key)
      copy_goal
    end

    def live_count_for(species_key)
      live_counts[species_key.to_s].to_i
    rescue
      0
    end

    def shiny_pokemon?(pokemon_or_species)
      pokemon = pokemon_or_species
      pokemon = pokemon.pokemon if pokemon.respond_to?(:pokemon)
      return false unless pokemon
      return true if pokemon.respond_to?(:shiny?) && pokemon.shiny?
      return true if pokemon.respond_to?(:fakeshiny?) && pokemon.fakeshiny?
      if defined?(CounterfeitShinies) && CounterfeitShinies.respond_to?(:render_shiny_in_ui?)
        return true if CounterfeitShinies.render_shiny_in_ui?(pokemon)
      end
      false
    rescue
      false
    end

    def duplicate_needed_for?(pokemon_or_species)
      return true if shiny_pokemon?(pokemon_or_species)
      counts = live_counts
      base_species_for(pokemon_or_species).any? do |key|
        counts[key].to_i < desired_count_for(key)
      end
    rescue
      false
    end

    def overstocked_for?(pokemon_or_species)
      return false if shiny_pokemon?(pokemon_or_species)
      keys = base_species_for(pokemon_or_species)
      return false if keys.empty?
      counts = live_counts
      keys.all? { |key| counts[key].to_i >= duplicate_cap_for(key) }
    rescue
      false
    end

    def duplicate_cap_for(species_key)
      desired_count_for(species_key)
    rescue
      1
    end

    def refresh_storage_counts!(reason = "refresh", full_plan = false)
      invalidate_live_counts!
      counts = live_counts
      if full_plan &&
         defined?(AutoplayBot::TeamBuilder) &&
         AutoplayBot::TeamBuilder.respond_to?(:record_roster_plan!)
        AutoplayBot::TeamBuilder.record_roster_plan!("dex #{reason}")
      end
      counts
    rescue
      {}
    end

    def needed_for?(pokemon_or_species)
      return true if shiny_pokemon?(pokemon_or_species)
      return true if fusion_needed_for?(pokemon_or_species)
      duplicate_needed_for?(pokemon_or_species)
    end

    def hard_needed_for?(pokemon_or_species)
      return true if shiny_pokemon?(pokemon_or_species)
      return true if fusion_needed_for?(pokemon_or_species)
      counts = live_counts
      base_species_for(pokemon_or_species).any? do |key|
        counts[key].to_i < 1 && !owned_by_pokedex?(key)
      end
    end

    def fusion_needed_for?(pokemon_or_species)
      return false unless defined?(AutoplayBot::Config) && AutoplayBot::Config.fusion_collection?
      return false if AutoplayBot::Config.fusion_collection_goal == "track_only"
      key = fusion_key_for(pokemon_or_species)
      return false unless key
      return false unless state_ready?
      return true unless defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:fusion_owned?)
      !AutoplayBot::State.fusion_owned?(key)
    rescue
      false
    end

    def observe_pokemon(pokemon_or_species, map_id = nil, level = nil)
      return unless state_ready?
      species = pokemon_species(pokemon_or_species)
      level ||= pokemon_or_species.level if pokemon_or_species.respond_to?(:level)
      map_id ||= (defined?($game_map) && $game_map ? $game_map.map_id : 0)
      fusion_key = fusion_key_for(species)
      AutoplayBot::State.record_fusion_seen(fusion_key, fusion_record_info(species, map_id)) if fusion_key && AutoplayBot::State.respond_to?(:record_fusion_seen)
      base_species_for(species).each do |key|
        AutoplayBot::State.observe_encounter(map_id, key, level)
      end
      if defined?(AutoplayBot::DexHuntPlanner) &&
         AutoplayBot::DexHuntPlanner.respond_to?(:record_observed_pokemon)
        AutoplayBot::DexHuntPlanner.record_observed_pokemon(pokemon_or_species, map_id, level)
      end
    end

    def record_caught_pokemon(pokemon_or_species)
      invalidate_live_counts!
      return unless state_ready?
      AutoplayBot.log("dex: caught priority shiny #{species_name(pokemon_species(pokemon_or_species))}") if shiny_pokemon?(pokemon_or_species) && defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      record_owned_fusion(pokemon_or_species)
      base_species_for(pokemon_or_species).each do |key|
        AutoplayBot::State.record_catch(key)
      end
      if defined?(AutoplayBot::DexHuntPlanner) &&
         AutoplayBot::DexHuntPlanner.respond_to?(:record_caught_pokemon)
        AutoplayBot::DexHuntPlanner.record_caught_pokemon(pokemon_or_species)
      end
      AutoplayBot::MissionControl.update_snapshot!("catch") if defined?(AutoplayBot::MissionControl)
    end

    def record_owned_fusion(pokemon_or_species)
      fusion_key = fusion_key_for(pokemon_or_species)
      return false unless state_ready?
      return false unless fusion_key && defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:record_fusion_owned)
      AutoplayBot::State.record_fusion_owned(fusion_key, fusion_record_info(pokemon_or_species))
      true
    rescue
      false
    end

    def record_count_delta(before_counts, after_counts)
      invalidate_live_counts!
      return unless state_ready?
      before_counts ||= {}
      after_counts ||= {}
      after_counts.each do |key, count|
        gained = count.to_i - before_counts[key].to_i
        gained.times { AutoplayBot::State.record_catch(key) } if gained > 0
      end
      AutoplayBot::MissionControl.update_snapshot!("roster delta") if defined?(AutoplayBot::MissionControl)
    end

    def collection_snapshot
      bucket = state_ready? ? AutoplayBot::State.save_bucket : {}
      counts = live_counts
      observed_species = {}
      (bucket["observed_encounters"] || {}).each_value do |species_map|
        next unless species_map.respond_to?(:each_key)
        species_map.each_key { |key| observed_species[key.to_s] = true }
      end
      caught = bucket["caught_species"] || {}
      fusion_seen = bucket["fusion_seen"] || {}
      fusion_owned = bucket["fusion_owned"] || {}
      {
        "mission" => (defined?(AutoplayBot::Config) ? AutoplayBot::Config.prime_objective : "living_dex_all_fusions"),
        "scope" => (defined?(AutoplayBot::Config) ? AutoplayBot::Config.completion_scope : "all_available_game_content"),
        "base_owned" => counts.count { |_key, count| count.to_i > 0 },
        "base_registered" => caught.count { |_key, count| count.to_i > 0 },
        "base_observed" => observed_species.length,
        "base_duplicate_ready" => counts.count { |_key, count| count.to_i >= copy_goal },
        "base_duplicate_needed" => counts.count { |_key, count| count.to_i > 0 && count.to_i < copy_goal },
        "fusion_seen" => fusion_seen.length,
        "fusion_owned" => fusion_owned.count { |_key, entry| entry && entry["count"].to_i > 0 },
        "copy_goal" => copy_goal,
        "storage_room" => storage_room?
      }
    rescue => e
      AutoplayBot.log("collection snapshot failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      {}
    end
  end

  module MissionControl
    module_function

    def state_ready?
      defined?(AutoplayBot::State) &&
        (!AutoplayBot::State.respond_to?(:loaded?) || AutoplayBot::State.loaded?)
    rescue
      false
    end

    def tick
      return unless defined?(AutoplayBot::Config) && AutoplayBot::Config.prime_collection?
      return unless state_ready?
      frame = (Graphics.frame_count rescue 0).to_i
      @last_snapshot_frame ||= -9999
      return if frame - @last_snapshot_frame.to_i < 600
      @last_snapshot_frame = frame
      update_snapshot!("periodic")
    rescue => e
      AutoplayBot.log("mission tick failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    end

    def update_snapshot!(reason = "update")
      return unless state_ready? && AutoplayBot::State.respond_to?(:record_prime_directive)
      snapshot = AutoplayBot::DexTracker.collection_snapshot
      snapshot["reason"] = reason.to_s
      AutoplayBot::State.record_prime_directive(snapshot)
      snapshot
    rescue => e
      AutoplayBot.log("mission snapshot failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      nil
    end

    def summary
      return "Dex mission" unless state_ready?
      snapshot = AutoplayBot::State.prime_directive if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:prime_directive)
      snapshot ||= {}
      base = snapshot["base_owned"].to_i
      observed = snapshot["base_observed"].to_i
      fusion = snapshot["fusion_owned"].to_i
      fusion_seen = snapshot["fusion_seen"].to_i
      scope = snapshot["scope"].to_s
      label = scope.empty? ? "all" : scope.gsub("_", " ")
      "Dex #{base}/#{observed} Fuse #{fusion}/#{fusion_seen} #{label}"
    rescue
      "Dex mission"
    end
  end

  module TeamBuilder
    VALUABLE_STATUS_MOVES = {
      "SPORE" => 60,
      "SLEEPPOWDER" => 48,
      "HYPNOSIS" => 42,
      "THUNDERWAVE" => 46,
      "STUNSPORE" => 36,
      "WILLOWISP" => 44,
      "TOXIC" => 44,
      "LEECHSEED" => 42,
      "SWORDSDANCE" => 46,
      "DRAGONDANCE" => 54,
      "NASTYPLOT" => 46,
      "CALMMIND" => 44,
      "QUIVERDANCE" => 58,
      "BULKUP" => 40,
      "PROTECT" => 28,
      "DETECT" => 26,
      "ROOST" => 44,
      "RECOVER" => 46,
      "SOFTBOILED" => 46,
      "SYNTHESIS" => 38,
      "MOONLIGHT" => 38,
      "MORNINGSUN" => 38,
      "AQUARING" => 26
    } unless const_defined?(:VALUABLE_STATUS_MOVES)
    FIELD_UTILITY_MOVES = {
      "CUT" => 18,
      "FLASH" => 12,
      "ROCKSMASH" => 14,
      "SURF" => 24,
      "STRENGTH" => 18,
      "WATERFALL" => 18,
      "FLY" => 12,
      "DIG" => 8,
      "SWEETSCENT" => 12,
      "FALSESWIPE" => 34
    } unless const_defined?(:FIELD_UTILITY_MOVES)
    HIGH_VALUE_ABILITIES = {
      "INTIMIDATE" => 34,
      "LEVITATE" => 28,
      "STURDY" => 22,
      "MAGICGUARD" => 34,
      "HUGEPOWER" => 46,
      "PUREPOWER" => 46,
      "TECHNICIAN" => 22,
      "SPEEDBOOST" => 42,
      "MOXIE" => 34,
      "REGENERATOR" => 38,
      "PRANKSTER" => 28,
      "DRIZZLE" => 30,
      "DROUGHT" => 30,
      "SANDSTREAM" => 22,
      "SNOWWARNING" => 18
    } unless const_defined?(:HIGH_VALUE_ABILITIES)

    module_function

    def score_pokemon(pokemon)
      return 0 unless pokemon
      score = pokemon.respond_to?(:level) ? pokemon.level.to_i * 12 : 0
      score += pokemon.respond_to?(:totalhp) ? pokemon.totalhp.to_i : 0
      score += pokemon.respond_to?(:attack) ? pokemon.attack.to_i : 0
      score += pokemon.respond_to?(:spatk) ? pokemon.spatk.to_i : 0
      score += pokemon.respond_to?(:defense) ? pokemon.defense.to_i / 2 : 0
      score += pokemon.respond_to?(:spdef) ? pokemon.spdef.to_i / 2 : 0
      score += pokemon.respond_to?(:speed) ? pokemon.speed.to_i : 0
      score += move_score(pokemon)
      score += hp_status_score(pokemon)
      score += ability_score(pokemon)
      score += field_utility_score(pokemon)
      score += species_strategy_score(pokemon)
      score += capture_utility_score(pokemon)
      score
    rescue
      0
    end

    def move_score(pokemon)
      return 0 unless pokemon.respond_to?(:moves) && pokemon.moves
      pokemon.moves.compact.inject(0) do |sum, move|
        sum + score_move_for_pokemon(pokemon, move)
      end
    rescue
      0
    end

    def move_forget_index(pokemon, move_to_learn = nil)
      return 0 unless pokemon && pokemon.respond_to?(:moves) && pokemon.moves
      move_count = pokemon.moves.length
      return 0 if move_count <= 0
      new_move = build_move(move_to_learn)
      entries = []
      pokemon.moves.each_with_index do |move, index|
        next unless move
        score = score_move_for_pokemon(pokemon, move)
        score -= duplicate_move_penalty(pokemon, move, index, new_move)
        entries << [index, score, move_name(move)]
      end
      choice = entries.sort_by { |entry| [entry[1], entry[0]] }.first
      index = choice ? choice[0].to_i : 0
      AutoplayBot.status("moves: forget #{move_name(pokemon.moves[index])}") if defined?(AutoplayBot)
      AutoplayBot.log("move learn: forgetting slot #{index} #{move_name(pokemon.moves[index])} for #{move_name(new_move)}") if AutoplayBot.respond_to?(:log)
      index
    rescue => e
      AutoplayBot.log("move forget choice failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      0
    end

    def build_move(move)
      return nil if move.nil?
      return move if move.respond_to?(:id) && move.respond_to?(:base_damage)
      return Pokemon::Move.new(move) if defined?(Pokemon::Move)
      move
    rescue
      move
    end

    def duplicate_move_penalty(pokemon, move, index, new_move = nil)
      return 0 unless move
      penalty = 0
      move_type = move_type_key(move)
      move_role = damaging_move?(move) ? "damage" : "status"
      comparable = pokemon.moves.each_with_index.map { |known, i| [known, i] }
      comparable << [new_move, -1] if new_move
      comparable.each do |other, other_index|
        next unless other
        next if other_index == index
        next unless move_type_key(other) == move_type
        next unless (damaging_move?(other) ? "damage" : "status") == move_role
        penalty += 18 if score_move_for_pokemon(pokemon, other) >= score_move_for_pokemon(pokemon, move)
      end
      penalty
    rescue
      0
    end

    def score_move_for_pokemon(pokemon, move)
      return 0 unless move
      return 0 unless move_has_pp?(move)
      base = move.respond_to?(:base_damage) ? move.base_damage.to_i : 0
      if base > 0
        accuracy = move.respond_to?(:accuracy) ? move.accuracy.to_i : 100
        accuracy = 100 if accuracy <= 0
        score = base * [accuracy, 100].min / 100
        score += 12 if stab_move?(pokemon, move)
        score += 8 if move.respond_to?(:priority) && move.priority.to_i > 0
        score += 8 if healing_drain_move?(move)
        score += 6 if useful_secondary_effect?(move)
        score -= 10 if move.respond_to?(:total_pp) && move.total_pp.to_i > 0 && move.total_pp.to_i <= 5
        score -= low_pp_penalty(move)
        return [score, 1].max
      end
      [status_move_value(move) - low_pp_penalty(move), 1].max
    rescue
      0
    end

    def status_move_value(move)
      key = move_id_key(move)
      return VALUABLE_STATUS_MOVES[key].to_i if VALUABLE_STATUS_MOVES[key]
      return 22 if move.respond_to?(:statusMove?) && move.statusMove?
      10
    rescue
      10
    end

    def damaging_move?(move)
      move && move.respond_to?(:base_damage) && move.base_damage.to_i > 0
    rescue
      false
    end

    def stab_move?(pokemon, move)
      type = move_type_key(move)
      return false if type.to_s.empty?
      pokemon_types(pokemon).any? { |pkmn_type| pkmn_type.to_s == type.to_s }
    rescue
      false
    end

    def pokemon_types(pokemon)
      return [] unless pokemon
      types = pokemon.types if pokemon.respond_to?(:types)
      return types.compact.map { |type| type.to_s } if types && types.respond_to?(:map)
      out = []
      out << pokemon.type1 if pokemon.respond_to?(:type1)
      out << pokemon.type2 if pokemon.respond_to?(:type2)
      if out.empty? && pokemon.respond_to?(:species_data) && pokemon.species_data
        data = pokemon.species_data
        out << data.type1 if data.respond_to?(:type1)
        out << data.type2 if data.respond_to?(:type2)
      end
      out.compact.map { |type| type.to_s }
    rescue
      []
    end

    def move_type_key(move)
      type = move.type if move.respond_to?(:type)
      type ||= move.type_id if move.respond_to?(:type_id)
      type.to_s
    rescue
      ""
    end

    def move_id_key(move)
      id = move.id if move.respond_to?(:id)
      id ||= move.name if move.respond_to?(:name)
      id.to_s.upcase.gsub(/[^A-Z0-9]/, "")
    rescue
      ""
    end

    def move_name(move)
      return "new move" unless move
      return move.name.to_s if move.respond_to?(:name) && move.name
      return move.id.to_s if move.respond_to?(:id)
      move.to_s
    rescue
      "move"
    end

    def healing_drain_move?(move)
      move_id_key(move) =~ /DRAIN|ABSORB|GIGA|LEECHLIFE|HORNLEECH|PARABOLICCHARGE/
    rescue
      false
    end

    def useful_secondary_effect?(move)
      key = move_id_key(move)
      key =~ /BITE|FANG|PUNCH|BEAM|BOLT|SCALD|BUBBLE|WATERPULSE|ANCIENTPOWER|SILVERWIND|OMINOUSWIND|ROCKSLIDE|IRONHEAD|EXTRASENSORY|SHADOWBALL|PSYCHIC/
    rescue
      false
    end

    def best_party_indexes
      return [] unless defined?($Trainer) && $Trainer && $Trainer.respond_to?(:party)
      scored = []
      $Trainer.party.each_with_index { |pkmn, i| scored << [i, score_pokemon(pkmn)] if pkmn }
      scored.sort_by { |entry| -entry[1] }.map { |entry| entry[0] }
    end

    def best_party_for_selection(min = 1, max = 6, accept_fainted = false, ableproc = nil)
      return [] unless defined?($Trainer) && $Trainer && $Trainer.respond_to?(:party)
      min = [min.to_i, 1].max
      max = [[max.to_i, min].max, 6].min
      candidates = []
      $Trainer.party.compact.each do |pkmn|
        next unless selectable_for_challenge?(pkmn, accept_fainted, ableproc)
        candidates << pkmn
      end
      chosen = candidates.sort_by { |pkmn| -score_pokemon(pkmn) }.first(max)
      return [] if chosen.length < min
      chosen
    rescue => e
      AutoplayBot.log("team selection failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      []
    end

    def selectable_for_challenge?(pokemon, accept_fainted = false, ableproc = nil)
      return false unless pokemon
      return false if pokemon.respond_to?(:egg?) && pokemon.egg?
      unless accept_fainted
        return false if pokemon.respond_to?(:fainted?) && pokemon.fainted?
        return false if pokemon.respond_to?(:hp) && pokemon.hp.to_i <= 0
      end
      return ableproc.call(pokemon) if ableproc
      true
    rescue
      false
    end

    def tick
      return unless defined?(AutoplayBot::Config) && AutoplayBot::Config.team_strategy?
      frame = (Graphics.frame_count rescue 0).to_i
      @last_team_tick_frame = -9999 if @last_team_tick_frame.nil?
      return if frame - @last_team_tick_frame.to_i < 900
      @last_team_tick_frame = frame
      record_roster_plan!("periodic")
    rescue => e
      AutoplayBot.log("team builder tick failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    end

    def request_training_rotation!(reason = "requested")
      @training_rotation_requested = reason.to_s
    rescue
      nil
    end

    def maybe_rotate_training_lead!(reason = "overworld")
      return false unless defined?(AutoplayBot::Config) && AutoplayBot::Config.team_strategy?
      return false if AutoplayBot::Config.team_strategy == "store_only"
      return false unless defined?($Trainer) && $Trainer && $Trainer.respond_to?(:party)
      frame = (Graphics.frame_count rescue 0).to_i
      force = !!@training_rotation_requested
      unless force
        @last_training_rotation_check_frame ||= -9999
        return false if frame - @last_training_rotation_check_frame.to_i < training_rotation_check_frames
      end
      @last_training_rotation_check_frame = frame
      party = Array($Trainer.party).compact
      return false if party.length < 2
      lead = party[0]
      target = training_target_level(party)
      lead_score = training_priority_score(lead, 0, party, target)
      choices = []
      party.each_with_index do |pkmn, index|
        next if index <= 0
        score = training_priority_score(pkmn, index, party, target)
        choices << [index, score, pkmn] if score > -9000
      end
      choice = choices.sort_by { |entry| [-entry[1].to_i, entry[0].to_i] }.first
      @training_rotation_requested = nil
      return false unless choice
      margin = force ? 20 : training_rotation_margin(lead, party, target)
      return false if choice[1].to_i < lead_score.to_i + margin.to_i
      return false unless swap_party_slots!(0, choice[0], "training #{reason}")
      true
    rescue => e
      @training_rotation_requested = nil
      AutoplayBot.log("training lead rotation failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def training_rotation_check_frames
      speed = defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.respond_to?(:game_speed_multiplier) ? AutoplayBot::Runtime.game_speed_multiplier : 1
      return 90 if speed.to_i >= 7
      return 120 if speed.to_i >= 3
      180
    rescue
      180
    end

    def training_target_level(party)
      levels = Array(party).map { |pkmn| pokemon_level(pkmn) }.select { |level| level > 0 }.sort
      return 1 if levels.empty?
      median = levels[(levels.length - 1) / 2].to_i
      max = levels[-1].to_i
      [[median + 1, max - 2, 8].max, max].min
    rescue
      8
    end

    def training_rotation_margin(lead, party, target)
      return 20 unless training_lead_usable?(lead)
      return 30 if overtrained_for_party?(lead, party, target)
      70
    rescue
      70
    end

    def training_priority_score(pokemon, index, party, target)
      return -9999 unless training_lead_usable?(pokemon)
      level = pokemon_level(pokemon)
      score = 0
      deficit = target.to_i - level.to_i
      score += deficit * 55 if deficit > 0
      score += 140 if evolution_ready_now?(pokemon)
      score += 95 if near_level_evolution?(pokemon, 3)
      score += 40 if usable_damaging_move_count(pokemon) > 0
      score += [[score_pokemon(pokemon) / 12, 0].max, 90].min
      score += hp_training_bonus(pokemon)
      score -= index.to_i * 2
      score
    rescue
      -9999
    end

    def training_lead_usable?(pokemon)
      return false unless pokemon
      return false if egg_or_shadow?(pokemon)
      return false if pokemon.respond_to?(:fainted?) && pokemon.fainted?
      return false if pokemon.respond_to?(:hp) && pokemon.hp.to_i <= 0
      return false if hp_ratio_for_training(pokemon) < 0.28
      usable_damaging_move_count(pokemon) > 0 || evolution_ready_now?(pokemon)
    rescue
      false
    end

    def overtrained_for_party?(pokemon, party, target)
      pokemon_level(pokemon) >= target.to_i + 2 &&
        Array(party).any? { |pkmn| training_lead_usable?(pkmn) && pokemon_level(pkmn) < target.to_i }
    rescue
      false
    end

    def pokemon_level(pokemon)
      pokemon.respond_to?(:level) ? pokemon.level.to_i : 0
    rescue
      0
    end

    def hp_ratio_for_training(pokemon)
      return 1.0 unless pokemon.respond_to?(:hp) && pokemon.respond_to?(:totalhp)
      total = [pokemon.totalhp.to_i, 1].max
      pokemon.hp.to_i.to_f / total.to_f
    rescue
      1.0
    end

    def hp_training_bonus(pokemon)
      ratio = hp_ratio_for_training(pokemon)
      return -120 if ratio < 0.35
      return -35 if ratio < 0.55
      (ratio * 30).round
    rescue
      0
    end

    def usable_damaging_move_count(pokemon)
      return 0 unless pokemon && pokemon.respond_to?(:moves) && pokemon.moves
      pokemon.moves.compact.count { |move| damaging_move?(move) && move_has_pp?(move) }
    rescue
      0
    end

    def evolution_ready_now?(pokemon)
      return false unless pokemon && pokemon.respond_to?(:check_evolution_on_level_up)
      result = pokemon.check_evolution_on_level_up(false) rescue nil
      !!result
    rescue
      false
    end

    def near_level_evolution?(pokemon, window = 3)
      return false unless pokemon
      level = pokemon_level(pokemon)
      data = pokemon.respond_to?(:species_data) ? pokemon.species_data : nil
      return false unless data && data.respond_to?(:get_evolutions)
      Array(data.get_evolutions(true)).any? do |evo|
        method = evo[1].to_s.upcase rescue ""
        param = evo[2].to_i rescue 0
        method.include?("LEVEL") && param > level && param <= level + window.to_i
      end
    rescue
      false
    end

    def swap_party_slots!(left, right, reason = "rotate")
      return false unless defined?($Trainer) && $Trainer && $Trainer.respond_to?(:party)
      party = $Trainer.party
      return false unless party && party[left.to_i] && party[right.to_i]
      party[left.to_i], party[right.to_i] = party[right.to_i], party[left.to_i]
      $Trainer.party = party if $Trainer.respond_to?(:party=)
      lead = party[left.to_i]
      AutoplayBot.status("team: lead #{pokemon_label(lead)}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:status)
      AutoplayBot.log("team rotation #{reason}: lead #{pokemon_label(lead)} from slot #{right}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      true
    rescue => e
      AutoplayBot.log("party slot swap failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def hp_status_score(pokemon)
      score = 0
      if pokemon.respond_to?(:hp) && pokemon.respond_to?(:totalhp)
        total = [pokemon.totalhp.to_i, 1].max
        ratio = pokemon.hp.to_i.to_f / total.to_f
        score += (ratio * 45).round
        score -= 80 if pokemon.hp.to_i <= 0
      end
      status = pokemon.status if pokemon.respond_to?(:status)
      score += 18 if status == :NONE || status.nil? || status.to_s == "NONE"
      score -= 25 unless status == :NONE || status.nil? || status.to_s == "NONE"
      score
    rescue
      0
    end

    def ability_score(pokemon)
      key = ability_key(pokemon)
      return HIGH_VALUE_ABILITIES[key].to_i if HIGH_VALUE_ABILITIES[key]
      0
    rescue
      0
    end

    def field_utility_score(pokemon)
      return 0 unless pokemon.respond_to?(:moves) && pokemon.moves
      pokemon.moves.compact.inject(0) do |sum, move|
        key = move_id_key(move)
        sum + FIELD_UTILITY_MOVES[key].to_i
      end
    rescue
      0
    end

    def species_strategy_score(pokemon)
      score = 0
      score += 22 if fused_pokemon?(pokemon)
      score += 180 if shiny_pokemon?(pokemon)
      score += 18 if species_keys_for(pokemon).length > 1
      score
    rescue
      0
    end

    def capture_utility_score(pokemon)
      return 0 unless pokemon.respond_to?(:moves) && pokemon.moves
      pokemon.moves.compact.inject(0) do |sum, move|
        key = move_id_key(move)
        value =
          if ["FALSESWIPE", "HOLDBACK"].include?(key)
            80
          elsif ["SPORE", "SLEEPPOWDER", "HYPNOSIS", "GRASSWHISTLE", "LOVELYKISS", "SING"].include?(key)
            62
          elsif ["THUNDERWAVE", "STUNSPORE", "GLARE", "WILLOWISP", "TOXIC"].include?(key)
            42
          elsif ["SUPERFANG", "NATURESMADNESS"].include?(key)
            34
          else
            0
          end
        sum + value
      end
    rescue
      0
    end

    def shiny_pokemon?(pokemon)
      return AutoplayBot::DexTracker.shiny_pokemon?(pokemon) if defined?(AutoplayBot::DexTracker) && AutoplayBot::DexTracker.respond_to?(:shiny_pokemon?)
      pokemon.respond_to?(:shiny?) && pokemon.shiny?
    rescue
      false
    end

    def move_has_pp?(move)
      return true unless move && move.respond_to?(:pp)
      pp = move.pp
      return true if pp.nil?
      total = move.respond_to?(:total_pp) ? move.total_pp : nil
      total = move.totalpp if total.nil? && move.respond_to?(:totalpp)
      total = 0 if total.nil?
      return true if pp.to_i < 0 || total.to_i <= 0
      pp.to_i > 0
    rescue
      true
    end

    def low_pp_penalty(move)
      return 0 unless move && move.respond_to?(:pp)
      total = move.respond_to?(:total_pp) ? move.total_pp.to_i : 0
      total = move.totalpp.to_i if total <= 0 && move.respond_to?(:totalpp)
      return 0 if total <= 0
      pp = move.pp.to_i
      return 45 if pp <= 0
      return 24 if pp == 1
      return 12 if pp == 2
      return 6 if pp <= 4 && total >= 8
      0
    rescue
      0
    end

    def ability_key(pokemon)
      ability = pokemon.ability_id if pokemon.respond_to?(:ability_id)
      ability ||= pokemon.ability if pokemon.respond_to?(:ability)
      ability = ability.id if ability.respond_to?(:id)
      ability.to_s.upcase.gsub(/[^A-Z0-9]/, "")
    rescue
      ""
    end

    def fused_pokemon?(pokemon)
      return pokemon.isFusion? if pokemon.respond_to?(:isFusion?)
      return pokemon.is_fusion? if pokemon.respond_to?(:is_fusion?)
      species_keys_for(pokemon).length > 1
    rescue
      false
    end

    def pokemon_label(pokemon)
      return "Pokemon" unless pokemon
      return pokemon.name.to_s if pokemon.respond_to?(:name) && pokemon.name
      return pokemon.speciesName.to_s if pokemon.respond_to?(:speciesName)
      return pokemon.species.to_s if pokemon.respond_to?(:species)
      "Pokemon"
    rescue
      "Pokemon"
    end

    def species_label(pokemon)
      return pokemon.speciesName.to_s if pokemon.respond_to?(:speciesName)
      species = pokemon.species if pokemon.respond_to?(:species)
      species = species.id if species.respond_to?(:id)
      species.to_s
    rescue
      ""
    end

    def species_key(pokemon)
      species = pokemon.species if pokemon.respond_to?(:species)
      species = pokemon.id if species.nil? && pokemon.respond_to?(:id)
      species = species.id if species.respond_to?(:id)
      species.to_s.upcase
    rescue
      ""
    end

    def species_keys_for(pokemon)
      if defined?(AutoplayBot::DexTracker) && AutoplayBot::DexTracker.respond_to?(:base_species_for)
        keys = AutoplayBot::DexTracker.base_species_for(pokemon) rescue []
        return keys.compact.map(&:to_s).uniq unless keys.empty?
      end
      key = species_key(pokemon)
      key.empty? ? [] : [key]
    rescue
      []
    end

    def max_party_size
      return Settings::MAX_PARTY_SIZE if defined?(Settings) && Settings.const_defined?(:MAX_PARTY_SIZE)
      6
    rescue
      6
    end

    def roster_entries(include_objects = false)
      entries = []
      if defined?($Trainer) && $Trainer && $Trainer.respond_to?(:party)
        $Trainer.party.each_with_index do |pkmn, index|
          entries << roster_entry(pkmn, "party", -1, index, include_objects) if pkmn
        end
      end
      if defined?($PokemonStorage) && $PokemonStorage
        max_boxes = $PokemonStorage.maxBoxes rescue 0
        max_boxes = [[max_boxes.to_i, 0].max, 60].min
        (0...max_boxes).each do |box|
          max_slots = $PokemonStorage.maxPokemon(box) rescue 30
          max_slots = [[max_slots.to_i, 0].max, 60].min
          (0...max_slots).each do |slot|
            pkmn = $PokemonStorage[box, slot] rescue nil
            entries << roster_entry(pkmn, "box", box, slot, include_objects) if pkmn
          end
        end
      end
      entries
    rescue => e
      AutoplayBot.log("roster scan failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      entries || []
    end

    def roster_entry(pokemon, source, box, index, include_object = false)
      entry = {
        "id" => "#{source}:#{box}:#{index}",
        "source" => source.to_s,
        "box" => box.to_i,
        "index" => index.to_i,
        "label" => pokemon_label(pokemon),
        "species" => species_label(pokemon),
        "base_species" => species_keys_for(pokemon),
        "level" => (pokemon.level.to_i rescue 0),
        "score" => score_pokemon(pokemon),
        "types" => pokemon_types(pokemon),
        "roles" => role_tags(pokemon)
      }
      entry["pokemon"] = pokemon if include_object
      entry
    rescue
      { "id" => "#{source}:#{box}:#{index}", "source" => source.to_s, "box" => box.to_i, "index" => index.to_i, "score" => 0 }
    end

    def public_entry(entry)
      out = {}
      entry.each { |key, value| out[key] = value unless key == "pokemon" }
      out
    rescue
      entry
    end

    def role_tags(pokemon)
      tags = []
      stats = {
        "physical" => (pokemon.attack.to_i rescue 0),
        "special" => (pokemon.spatk.to_i rescue 0),
        "speed" => (pokemon.speed.to_i rescue 0),
        "bulk" => ((pokemon.totalhp.to_i rescue 0) + (pokemon.defense.to_i rescue 0) + (pokemon.spdef.to_i rescue 0))
      }
      tags << stats.sort_by { |_key, value| -value }.first[0] rescue nil
      pokemon.moves.compact.each do |move|
        tags << "capture" if move_id_key(move) =~ /FALSESWIPE|SPORE|SLEEP|HYPNOSIS|THUNDERWAVE|STUNSPORE/
        tags << "priority" if move.respond_to?(:priority) && move.priority.to_i > 0
        tags << "setup" if VALUABLE_STATUS_MOVES[move_id_key(move)].to_i >= 40
      end if pokemon.respond_to?(:moves) && pokemon.moves
      tags << "shiny" if shiny_pokemon?(pokemon)
      tags.compact.uniq.first(5)
    rescue
      []
    end

    def record_roster_plan!(reason = "update")
      return unless defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:record_team_plan)
      entries = roster_entries(true)
      plan = team_plan(reason, entries)
      AutoplayBot::State.record_team_plan(plan)
      AutoplayBot::State.record_storage_snapshot(storage_snapshot(reason, entries, plan)) if AutoplayBot::State.respond_to?(:record_storage_snapshot)
      frame = (Graphics.frame_count rescue 0).to_i
      @last_team_plan_log = -9999 if @last_team_plan_log.nil?
      if reason.to_s != "periodic" || frame - @last_team_plan_log.to_i >= 1800
        @last_team_plan_log = frame
        AutoplayBot.log("team plan #{reason}: #{team_plan_summary(plan)}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      end
      plan
    rescue => e
      AutoplayBot.log("team plan failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      nil
    end

    def inspect_party_and_storage!(reason = "check")
      entries = roster_entries(true)
      plan = team_plan(reason, entries)
      snapshot = storage_snapshot(reason, entries, plan)
      AutoplayBot::State.record_team_plan(plan) if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:record_team_plan)
      AutoplayBot::State.record_storage_snapshot(snapshot) if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:record_storage_snapshot)
      AutoplayBot.status("team: party #{snapshot["party_count"]} pc #{snapshot["pc_count"]}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:status)
      AutoplayBot.log("storage check #{reason}: #{storage_snapshot_summary(snapshot)}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      { "plan" => plan, "storage" => snapshot }
    rescue => e
      AutoplayBot.log("party/pc check failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      nil
    end

    def team_plan(reason = "update", entries = nil)
      entries ||= roster_entries(true)
      best = entries.sort_by { |entry| [-entry["score"].to_i, entry["source"] == "party" ? 0 : 1, entry["index"].to_i] }.first(max_party_size)
      best = protect_team_roles(best, entries)
      best_ids = {}
      best.each { |entry| best_ids[entry["id"]] = true }
      party_entries = entries.select { |entry| entry["source"] == "party" }
      {
        "reason" => reason.to_s,
        "party" => party_entries.map { |entry| public_entry(entry) },
        "recommended_party" => best.map { |entry| public_entry(entry) },
        "keep_party" => party_entries.select { |entry| best_ids[entry["id"]] }.map { |entry| public_entry(entry) },
        "box_from_party" => party_entries.reject { |entry| best_ids[entry["id"]] }.map { |entry| public_entry(entry) },
        "promote_from_pc" => best.select { |entry| entry["source"] == "box" }.map { |entry| public_entry(entry) },
        "coverage" => coverage_profile(best),
        "fusion_recommendations" => fusion_recommendations(entries)
      }
    rescue => e
      AutoplayBot.log("team plan build failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      { "reason" => reason.to_s, "party" => [], "recommended_party" => [] }
    end

    def protect_team_roles(best, entries)
      best = Array(best).compact
      best = ensure_best_contains(best, best_shiny_entries(entries))
      best = ensure_best_contains(best, [best_capture_helper_entry(entries)])
      best.first(max_party_size)
    rescue
      Array(best).compact.first(max_party_size)
    end

    def ensure_best_contains(best, candidates)
      Array(candidates).compact.each do |candidate|
        next if candidate.nil? || candidate["id"].nil?
        next if best.any? { |entry| entry["id"] == candidate["id"] }
        if best.length < max_party_size
          best << candidate
          next
        end
        replace_at = replaceable_team_slot(best, candidate)
        best[replace_at] = candidate if replace_at
      end
      best
    rescue
      best
    end

    def replaceable_team_slot(best, candidate)
      candidate_score = candidate["score"].to_i
      choices = best.each_with_index.map do |entry, index|
        protected = shiny_pokemon?(entry["pokemon"]) || Array(entry["roles"]).include?("capture")
        [protected ? 1 : 0, entry["score"].to_i, index, entry]
      end.sort_by { |row| [row[0], row[1], row[2]] }
      row = choices.first
      return nil unless row
      return row[2] if row[0].to_i == 0 && candidate_score >= row[1].to_i - 35
      nil
    rescue
      nil
    end

    def best_shiny_entries(entries)
      Array(entries).select { |entry| shiny_pokemon?(entry["pokemon"]) }
                    .sort_by { |entry| [-entry["score"].to_i, entry["source"] == "party" ? 0 : 1, entry["index"].to_i] }
                    .first(max_party_size)
    rescue
      []
    end

    def best_capture_helper_entry(entries)
      Array(entries).select { |entry| Array(entry["roles"]).include?("capture") }
                    .sort_by { |entry| [-entry["score"].to_i, entry["source"] == "party" ? 0 : 1, entry["index"].to_i] }
                    .first
    rescue
      nil
    end

    def storage_snapshot(reason = "check", entries = nil, plan = nil)
      entries ||= roster_entries(true)
      plan ||= team_plan(reason, entries)
      party_entries = entries.select { |entry| entry["source"] == "party" }
      pc_entries = entries.select { |entry| entry["source"] == "box" }
      box_summary = pc_box_summary
      species_counts = species_counts(entries)
      duplicate_goal = defined?(AutoplayBot::DexTracker) ? AutoplayBot::DexTracker.copy_goal : 1
      duplicate_ready = species_counts.count { |_key, count| count.to_i >= duplicate_goal.to_i }
      duplicate_short = species_counts.count { |_key, count| count.to_i > 0 && count.to_i < duplicate_goal.to_i }
      {
        "reason" => reason.to_s,
        "party_count" => party_entries.length,
        "party_able" => party_entries.count { |entry| pokemon_able_for_snapshot?(entry["pokemon"]) },
        "pc_count" => pc_entries.length,
        "total_owned_roster" => entries.length,
        "box_occupancy" => box_summary,
        "species_count" => species_counts.length,
        "duplicate_goal" => duplicate_goal,
        "duplicate_ready" => duplicate_ready,
        "duplicate_short" => duplicate_short,
        "recommended_party" => Array(plan["recommended_party"]).first(6),
        "promote_from_pc" => Array(plan["promote_from_pc"]).first(6),
        "box_from_party" => Array(plan["box_from_party"]).first(6),
        "fusion_recommendations" => Array(plan["fusion_recommendations"]).first(5),
        "capture_helpers" => capture_helper_entries(entries).first(8)
      }
    rescue => e
      AutoplayBot.log("storage snapshot failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      { "reason" => reason.to_s, "party_count" => 0, "pc_count" => 0 }
    end

    def pc_box_summary
      summary = { "boxes" => 0, "occupied" => 0, "capacity" => 0, "per_box" => [] }
      return summary unless defined?($PokemonStorage) && $PokemonStorage
      max_boxes = $PokemonStorage.maxBoxes rescue 0
      max_boxes = [[max_boxes.to_i, 0].max, 80].min
      summary["boxes"] = max_boxes
      (0...max_boxes).each do |box|
        max_slots = $PokemonStorage.maxPokemon(box) rescue 30
        max_slots = [[max_slots.to_i, 0].max, 80].min
        occupied = 0
        (0...max_slots).each do |slot|
          occupied += 1 if ($PokemonStorage[box, slot] rescue nil)
        end
        summary["occupied"] += occupied
        summary["capacity"] += max_slots
        summary["per_box"] << { "box" => box, "occupied" => occupied, "capacity" => max_slots } if occupied > 0
      end
      summary
    rescue
      { "boxes" => 0, "occupied" => 0, "capacity" => 0, "per_box" => [] }
    end

    def pokemon_able_for_snapshot?(pokemon)
      return false unless pokemon
      return pokemon.able? if pokemon.respond_to?(:able?)
      return pokemon.hp.to_i > 0 if pokemon.respond_to?(:hp)
      true
    rescue
      false
    end

    def capture_helper_entries(entries)
      Array(entries).select { |entry| Array(entry["roles"]).include?("capture") }
                    .sort_by { |entry| [entry["source"] == "party" ? 0 : 1, -entry["score"].to_i] }
                    .map { |entry| public_entry(entry) }
    rescue
      []
    end

    def storage_snapshot_summary(snapshot)
      box = snapshot["box_occupancy"] || {}
      promote = Array(snapshot["promote_from_pc"]).first(2).map { |entry| entry["label"] }.join(", ")
      text = "party #{snapshot["party_count"]}/#{max_party_size}, pc #{snapshot["pc_count"]}, boxes #{box["occupied"]}/#{box["capacity"]}"
      text += "; promote #{promote}" unless promote.empty?
      text
    rescue
      "storage unavailable"
    end

    def team_plan_summary(plan)
      recommended = Array(plan["recommended_party"]).first(6).map { |entry| entry["label"] }.join(", ")
      promote = Array(plan["promote_from_pc"]).first(3).map { |entry| entry["label"] }.join(", ")
      text = recommended.empty? ? "no party" : "party #{recommended}"
      text += "; promote #{promote}" unless promote.empty?
      text
    rescue
      "unavailable"
    end

    def coverage_profile(entries)
      counts = {}
      Array(entries).each do |entry|
        Array(entry["types"]).each { |type| counts[type.to_s] = counts[type.to_s].to_i + 1 }
      end
      counts
    rescue
      {}
    end

    def fusion_recommendations(entries = nil)
      return [] unless defined?(AutoplayBot::Config) && AutoplayBot::Config.fusion_strategy?
      entries ||= roster_entries(true)
      counts = species_counts(entries)
      candidates = entries.select { |entry| entry["pokemon"] && !egg_or_shadow?(entry["pokemon"]) && !fused_pokemon?(entry["pokemon"]) }
                          .sort_by { |entry| -entry["score"].to_i }.first(14)
      recs = []
      candidates.each_with_index do |left, i|
        candidates.each_with_index do |right, j|
          next if j <= i
          keys = species_keys_for(left["pokemon"]) + species_keys_for(right["pokemon"])
          next unless safe_fusion_species_use?(keys, counts)
          score = fusion_pair_score(left, right)
          recs << {
            "body" => public_entry(left),
            "head" => public_entry(right),
            "score" => score,
            "reason" => fusion_pair_reason(left, right)
          }
        end
      end
      recs.sort_by { |entry| -entry["score"].to_i }.first(5)
    rescue
      []
    end

    def species_counts(entries)
      counts = {}
      Array(entries).each do |entry|
        species_keys_for(entry["pokemon"]).each { |key| counts[key] = counts[key].to_i + 1 }
      end
      counts
    rescue
      {}
    end

    def safe_fusion_species_use?(species_keys, counts)
      needed = {}
      Array(species_keys).each { |key| needed[key.to_s] = needed[key.to_s].to_i + 1 }
      needed.all? { |key, count| counts[key].to_i > count.to_i }
    rescue
      false
    end

    def fusion_pair_score(left, right)
      score = (left["score"].to_i + right["score"].to_i) / 2
      score += (Array(left["types"]) | Array(right["types"])).length * 18
      score += ((Array(left["roles"]) | Array(right["roles"])).length - (Array(left["roles"]) & Array(right["roles"])).length) * 12
      level_gap = (left["level"].to_i - right["level"].to_i).abs
      score -= [level_gap * 4, 80].min
      score
    rescue
      0
    end

    def fusion_pair_reason(left, right)
      shared = Array(left["roles"]) & Array(right["roles"])
      types = (Array(left["types"]) | Array(right["types"])).join("/")
      roles = ((Array(left["roles"]) | Array(right["roles"])) - shared).first(3).join(", ")
      text = types.empty? ? "safe duplicate fusion candidate" : "safe duplicate fusion candidate with #{types} coverage"
      text += " and #{roles} roles" unless roles.empty?
      text
    rescue
      "safe duplicate fusion candidate"
    end

    def pending_caught_storage_choice(labels)
      return nil unless defined?(AutoplayBot::Config) && AutoplayBot::Config.team_strategy?
      return nil unless @pending_caught
      store = labels.index { |label| label =~ /box|storage|store|send/i }
      add = labels.index { |label| label =~ /party|team|add/i }
      return nil unless store || add
      decision = should_add_caught_to_party?(@pending_caught) ? "add" : "store"
      chosen = decision == "add" ? (add || store) : (store || add)
      record_storage_decision(@pending_caught, decision, "full party prompt")
      chosen
    rescue
      nil
    end

    def should_add_caught_to_party?(pokemon)
      return false unless pokemon
      return false if egg_or_shadow?(pokemon)
      return false unless defined?(AutoplayBot::Config) && AutoplayBot::Config.team_strategy?
      return false if AutoplayBot::Config.team_strategy == "store_only"
      party = defined?($Trainer) && $Trainer && $Trainer.respond_to?(:party) ? $Trainer.party.compact : []
      return true if party.length < max_party_size
      worst = weakest_party_entry
      return false unless worst
      caught_score = score_pokemon(pokemon) + party_type_gap_bonus(pokemon, party)
      caught_score += 45 if shiny_pokemon?(pokemon)
      caught_score >= worst["score"].to_i + 70
    rescue
      false
    end

    def party_type_gap_bonus(pokemon, party)
      present = {}
      Array(party).each { |pkmn| pokemon_types(pkmn).each { |type| present[type.to_s] = true } }
      missing = pokemon_types(pokemon).count { |type| !present[type.to_s] }
      missing * 35
    rescue
      0
    end

    def weakest_party_entry(ableproc = nil, accept_fainted = true)
      return nil unless defined?($Trainer) && $Trainer && $Trainer.respond_to?(:party)
      candidates = []
      $Trainer.party.each_with_index do |pkmn, index|
        next unless selectable_for_challenge?(pkmn, accept_fainted, ableproc)
        candidates << roster_entry(pkmn, "party", -1, index, true)
      end
      candidates.sort_by { |entry| [entry["score"].to_i, entry["index"].to_i] }.first
    rescue
      nil
    end

    def swap_out_party_index(ableproc = nil, allow_ineligible = false)
      return nil unless @pending_caught
      entry = weakest_party_entry(ableproc, allow_ineligible)
      return nil unless entry
      record_storage_decision(@pending_caught, "swap_out_slot_#{entry["index"]}", "caught upgrade")
      entry["index"].to_i
    rescue
      nil
    end

    def selection_for_context(min = 1, max = 6, accept_fainted = false, ableproc = nil)
      if @pending_caught && min.to_i <= 1 && max.to_i <= 2
        index = swap_out_party_index(ableproc, accept_fainted)
        return [($Trainer.party[index] rescue nil)].compact if index
      end
      best_party_for_selection(min, max, accept_fainted, ableproc)
    rescue
      []
    end

    def with_pending_caught(pokemon)
      old = @pending_caught
      @pending_caught = pokemon
      yield
    ensure
      @pending_caught = old
    end

    def caught_storage_context?
      !!@pending_caught
    rescue
      false
    end

    def record_storage_decision(pokemon, decision, reason)
      return unless defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:record_storage_decision)
      AutoplayBot::State.record_storage_decision({
        "pokemon" => pokemon_label(pokemon),
        "species" => species_label(pokemon),
        "score" => score_pokemon(pokemon),
        "decision" => decision.to_s,
        "reason" => reason.to_s
      })
    rescue
      nil
    end

    def egg_or_shadow?(pokemon)
      return true if pokemon.respond_to?(:egg?) && pokemon.egg?
      return true if pokemon.respond_to?(:isShadow?) && pokemon.isShadow?
      false
    rescue
      false
    end
  end

  module BattlePolicy
    BALL_PRIORITY = [
      :QUICKBALL,
      :ULTRABALL,
      :DUSKBALL,
      :TIMERBALL,
      :NETBALL,
      :GREATBALL,
      :FUSIONBALL,
      :POKEBALL,
      :PREMIERBALL,
      :MASTERBALL
    ] unless const_defined?(:BALL_PRIORITY)
    RESERVED_TRAINER_BALLS = [
      :ROCKETBALL
    ] unless const_defined?(:RESERVED_TRAINER_BALLS)
    TRAINER_ROCKET_BALL_PRIORITY = [
      :ROCKETBALL
    ] unless const_defined?(:TRAINER_ROCKET_BALL_PRIORITY)
    HEAL_ITEMS = [
      [:ORANBERRY, 10],
      [:POTION, 20],
      [:BERRYJUICE, 20],
      [:SWEETHEART, 20],
      [:SUPERPOTION, 50],
      [:FRESHWATER, 50],
      [:SODAPOP, 60],
      [:LEMONADE, 80],
      [:MOOMOOMILK, 100],
      [:HYPERPOTION, 200],
      [:MAXPOTION, 9999],
      [:FULLRESTORE, 9999]
    ] unless const_defined?(:HEAL_ITEMS)
    REVIVE_ITEMS = [
      :REVIVE,
      :REVIVALHERB,
      :MAXREVIVE
    ] unless const_defined?(:REVIVE_ITEMS)
    STATUS_ITEMS = {
      :SLEEP => [:AWAKENING, :CHESTOBERRY, :BLUEFLUTE, :FULLHEAL, :LUMBERRY, :LAVACOOKIE, :OLDGATEAU, :FULLRESTORE],
      :POISON => [:ANTIDOTE, :PECHABERRY, :FULLHEAL, :LUMBERRY, :LAVACOOKIE, :OLDGATEAU, :FULLRESTORE],
      :BURN => [:BURNHEAL, :RAWSTBERRY, :FULLHEAL, :LUMBERRY, :LAVACOOKIE, :OLDGATEAU, :FULLRESTORE],
      :PARALYSIS => [:PARALYZEHEAL, :PARLYZHEAL, :CHERIBERRY, :FULLHEAL, :LUMBERRY, :LAVACOOKIE, :OLDGATEAU, :FULLRESTORE],
      :FROZEN => [:ICEHEAL, :ASPEARBERRY, :FULLHEAL, :LUMBERRY, :LAVACOOKIE, :OLDGATEAU, :FULLRESTORE]
    } unless const_defined?(:STATUS_ITEMS)
    CAPTURE_STATUS_MOVES = [
      "SPORE",
      "SLEEPPOWDER",
      "HYPNOSIS",
      "DARKVOID",
      "GRASSWHISTLE",
      "SING",
      "LOVELYKISS",
      "YAWN",
      "THUNDERWAVE",
      "STUNSPORE",
      "GLARE",
      "WILLOWISP"
    ] unless const_defined?(:CAPTURE_STATUS_MOVES)
    CAPTURE_WEAKENING_MOVES = [
      "FALSESWIPE",
      "HOLD BACK",
      "HOLDBACK",
      "SUPERFANG",
      "NATURESMADNESS"
    ] unless const_defined?(:CAPTURE_WEAKENING_MOVES)
    CAPTURE_RISKY_ATTACKS = [
      "SELFDESTRUCT",
      "EXPLOSION",
      "FINALGAMBIT",
      "MEMENTO",
      "PERISHSONG",
      "STRUGGLE",
      "DRAGONRAGE",
      "SONICBOOM",
      "NIGHTSHADE",
      "SEISMICTOSS"
    ] unless const_defined?(:CAPTURE_RISKY_ATTACKS)

    module_function

    def state_ready?
      defined?(AutoplayBot::State) &&
        (!AutoplayBot::State.respond_to?(:loaded?) || AutoplayBot::State.loaded?)
    rescue
      false
    end

    def try_register_turn(battle, idx_battler, ai = nil, first_action = true)
      AutoplayBot::State.set_runtime_mode("battle") if state_ready? && AutoplayBot::State.respond_to?(:set_runtime_mode)
      observe_battle(battle, idx_battler)
      return true if try_register_catch(battle, idx_battler, first_action, ai)
      return true if try_register_wild_escape(battle, idx_battler, first_action)
      return true if try_register_survival_item(battle, idx_battler, first_action)
      return true if try_register_status_item(battle, idx_battler, first_action)
      return true if try_register_revive_item(battle, idx_battler, first_action)
      return true if try_register_smart_switch(battle, idx_battler, ai)
      return true if try_register_best_move(battle, idx_battler, ai)
      false
    rescue => e
      AutoplayBot.log("battle turn policy failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def observe_battle(battle, idx_battler)
      return unless battle && battle.respond_to?(:battlers) && battle.respond_to?(:opposes?)
      battle.battlers.compact.each do |battler|
        next unless battler.respond_to?(:pokemon) && battler.pokemon
        next unless battle.opposes?(idx_battler) != battle.opposes?(battler.index)
        AutoplayBot::DexTracker.observe_pokemon(battler.pokemon) if defined?(AutoplayBot::DexTracker)
      end
    rescue
      nil
    end

    def try_register_catch(battle, idx_battler, first_action = true, ai = nil)
      return false unless battle && catch_battle_allowed?(battle)
      target = catch_target_for(battle, idx_battler)
      return false unless target
      ball = best_ball_for(target, battle)
      unless ball
        reason = trainer_capture_battle?(battle) ? trainer_capture_missing_reason : "no usable balls"
        AutoplayBot.status(reason) if defined?(AutoplayBot) && AutoplayBot.respond_to?(:status)
        AutoplayBot::State.defer_target(AutoplayBot::DexTracker.species_key(target.pokemon.species), reason) if state_ready? && target.respond_to?(:pokemon) && target.pokemon
        return false
      end
      if trainer_capture_battle?(battle)
        species_key = AutoplayBot::DexTracker.species_key(target.pokemon.species) rescue nil
        unless trainer_capture_attempt_allowed?(battle, target, species_key)
          AutoplayBot.status("trainer steal: enough from this trainer") if AutoplayBot.respond_to?(:status)
          return false
        end
      end
      return false unless can_throw_ball?(battle, idx_battler, target, ball, first_action)
      unless should_throw_ball_now?(battle, target, ball)
        return true if try_register_capture_move(battle, idx_battler, target, ai)
        return true if try_register_safe_weaken_move(battle, idx_battler, target, ai)
        unless fallback_capture_throw_allowed?(battle, target, ball)
          AutoplayBot.status("battle: weaken before #{ball}") if AutoplayBot.respond_to?(:status)
          AutoplayBot.log("battle policy: holding #{ball} until target is weakened/statused") if AutoplayBot.respond_to?(:log)
          return false
        end
      end
      shiny = shiny_target?(target)
      action = shiny ? "shiny catch" : (trainer_capture_battle?(battle) ? "trainer steal" : "catch")
      AutoplayBot.log("battle policy: #{action} throwing #{ball} at #{target.pokemon.name rescue target.pokemon.species}") if AutoplayBot.respond_to?(:log)
      AutoplayBot.status("battle: throw #{ball}") if AutoplayBot.respond_to?(:status)
      species_key = AutoplayBot::DexTracker.species_key(target.pokemon.species) rescue nil
      note_trainer_capture_attempt(battle, target, species_key, ball) if trainer_capture_battle?(battle)
      if state_ready? && defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:record_catch_attempt)
        AutoplayBot::State.record_catch_attempt(
          species_key,
          ball,
          "wild" => wild_battle?(battle),
          "trainer" => trainer_capture_battle?(battle),
          "trainer_record" => current_trainer_capture_record(battle),
          "turn" => battle_turn(battle),
          "shiny" => shiny
        )
      end
      if defined?(AutoplayBot::DexHuntPlanner) &&
         AutoplayBot::DexHuntPlanner.respond_to?(:record_capture_attempt)
        AutoplayBot::DexHuntPlanner.record_capture_attempt(target.pokemon, ball, battle)
      end
      battle.pbRegisterItem(idx_battler, ball, target.index)
      true
    rescue => e
      AutoplayBot.log("battle catch registration failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def try_register_wild_escape(battle, idx_battler, first_action = true)
      return false unless defined?(AutoplayBot::Config) && AutoplayBot::Config.wild_capture_focus?
      return false unless first_action
      return false unless wild_battle?(battle)
      return false if catch_target_for(battle, idx_battler)
      if battle.respond_to?(:pbCanRun?) && !battle.pbCanRun?(idx_battler)
        return false
      end
      return false unless battle.respond_to?(:pbRun)
      result = battle.pbRun(idx_battler, false)
      AutoplayBot.status("battle: run unneeded wild") if AutoplayBot.respond_to?(:status)
      result.to_i != 0
    rescue => e
      AutoplayBot.log("battle run failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def catch_battle_allowed?(battle)
      wild_battle?(battle) || trainer_capture_battle?(battle)
    rescue
      false
    end

    def wild_battle?(battle)
      battle && battle.respond_to?(:wildBattle?) && battle.wildBattle?
    rescue
      false
    end

    def trainer_capture_battle?(battle)
      return false unless battle && battle.respond_to?(:trainerBattle?) && battle.trainerBattle?
      trainer_capture_mode > 0
    rescue
      false
    end

    def trainer_capture_mode
      policy = AutoplayBot::Config.trainer_capture_policy
      return 0 if policy == "off"
      desired = nil
      desired = 1 if policy == "force_rocket_balls"
      desired = 2 if policy == "force_all_balls"
      if desired && defined?($PokemonSystem) && $PokemonSystem && $PokemonSystem.respond_to?(:rocketballsteal=)
        $PokemonSystem.rocketballsteal = desired
      end
      game_rocket_capture_mode
    rescue
      0
    end

    def game_rocket_capture_mode
      return 0 unless defined?($PokemonSystem) && $PokemonSystem && $PokemonSystem.respond_to?(:rocketballsteal)
      mode = $PokemonSystem.rocketballsteal.to_i
      [[mode, 0].max, 2].min
    rescue
      0
    end

    def trainer_capture_missing_reason
      case trainer_capture_mode
      when 1
        "trainer steal: buy Rocket Balls at Kuray Shop"
      when 2
        "trainer steal: no usable balls"
      else
        "trainer steal: Rocket Mode off"
      end
    rescue
      "trainer steal: no usable balls"
    end

    def catch_target_for(battle, idx_battler)
      return nil unless battle.respond_to?(:battlers)
      focus_wild = capture_focus_wild_battle?(battle)
      focus_trainer = trainer_capture_battle?(battle)
      targets = battle.battlers.compact.select do |battler|
        next false unless battler.respond_to?(:index) && battle.respond_to?(:opposes?)
        next false unless battle.opposes?(idx_battler) != battle.opposes?(battler.index)
        next false if battler.respond_to?(:fainted?) && battler.fainted?
        next false unless battler.respond_to?(:pokemon) && battler.pokemon
        next false if focus_wild && !shiny_target?(battler) && AutoplayBot::DexTracker.overstocked_for?(battler.pokemon)
        AutoplayBot::DexTracker.needed_for?(battler.pokemon) ||
          (focus_wild && wild_capture_candidate?(battler.pokemon)) ||
          (focus_trainer && trainer_capture_candidate?(battler.pokemon))
      end
      targets.sort_by do |battler|
        shiny = shiny_target?(battler)
        hard_needed = AutoplayBot::DexTracker.hard_needed_for?(battler.pokemon)
        needed = AutoplayBot::DexTracker.needed_for?(battler.pokemon)
        trainer_bonus = focus_trainer && trainer_capture_candidate?(battler.pokemon) ? 0 : 1
        [shiny ? 0 : (hard_needed ? 1 : (needed ? 2 : 3)), trainer_bonus, hp_ratio(battler)]
      end.first
    rescue
      nil
    end

    def shiny_target?(target_or_pokemon)
      pokemon = target_or_pokemon
      pokemon = pokemon.pokemon if pokemon.respond_to?(:pokemon)
      return false unless defined?(AutoplayBot::DexTracker) && AutoplayBot::DexTracker.respond_to?(:shiny_pokemon?)
      AutoplayBot::DexTracker.shiny_pokemon?(pokemon)
    rescue
      false
    end

    def capture_focus_wild_battle?(battle)
      defined?(AutoplayBot::Config) &&
        AutoplayBot::Config.respond_to?(:wild_capture_focus?) &&
        AutoplayBot::Config.wild_capture_focus? &&
        wild_battle?(battle)
    rescue
      false
    end

    def wild_capture_candidate?(pokemon)
      return false unless defined?(AutoplayBot::DexTracker)
      return true if AutoplayBot::DexTracker.shiny_pokemon?(pokemon)
      return false if AutoplayBot::DexTracker.overstocked_for?(pokemon)
      AutoplayBot::DexTracker.duplicate_needed_for?(pokemon)
    rescue
      false
    end

    def trainer_capture_candidate?(pokemon)
      return false unless pokemon && defined?(AutoplayBot::DexTracker)
      return true if AutoplayBot::DexTracker.shiny_pokemon?(pokemon)
      return true if AutoplayBot::DexTracker.needed_for?(pokemon)
      return false if AutoplayBot::DexTracker.overstocked_for?(pokemon)
      return true if pokemon.respond_to?(:isFusion?) && pokemon.isFusion?
      return true if pokemon.respond_to?(:is_fusion?) && pokemon.is_fusion?
      false
    rescue
      false
    end

    def current_trainer_capture_record(battle = nil)
      if defined?(AutoplayBot::RepeatableBattleLedger) &&
         AutoplayBot::RepeatableBattleLedger.respond_to?(:current_active_record)
        record = AutoplayBot::RepeatableBattleLedger.current_active_record(battle)
        return record if record.is_a?(Hash) && !record.empty?
      end
      nil
    rescue
      nil
    end

    def trainer_capture_attempt_allowed?(battle, target, species_key = nil)
      return true if shiny_target?(target)
      record = current_trainer_capture_record(battle)
      if record && state_ready? &&
         AutoplayBot::State.respond_to?(:trainer_rocket_capture_allowed?) &&
         !AutoplayBot::State.trainer_rocket_capture_allowed?(record)
        return false
      end
      key = trainer_capture_battle_key(battle, record)
      @trainer_capture_attempts ||= {}
      attempts = @trainer_capture_attempts[key] ||= { "total" => 0, "species" => {} }
      species = species_key.to_s
      species = "unknown" if species.empty?
      return false if attempts["total"].to_i >= trainer_capture_attempt_limit_per_battle
      return false if attempts["species"][species].to_i >= 1
      true
    rescue
      true
    end

    def note_trainer_capture_attempt(battle, target, species_key, ball)
      record = current_trainer_capture_record(battle)
      key = trainer_capture_battle_key(battle, record)
      @trainer_capture_attempts ||= {}
      attempts = @trainer_capture_attempts[key] ||= { "total" => 0, "species" => {} }
      species = species_key.to_s
      species = "unknown" if species.empty?
      attempts["total"] = attempts["total"].to_i + 1
      attempts["species"][species] = attempts["species"][species].to_i + 1
      @last_trainer_capture_context = {
        "battle_key" => key,
        "record" => record,
        "species_key" => species,
        "ball" => ball.to_s,
        "time" => Time.now.to_i
      }
      AutoplayBot::State.record_trainer_rocket_attempt(record, species, ball, "turn" => battle_turn(battle)) if record &&
                                                                                                                  state_ready? &&
                                                                                                                  AutoplayBot::State.respond_to?(:record_trainer_rocket_attempt)
    rescue
      nil
    end

    def note_caught_pokemon(pokemon)
      return unless pokemon
      ctx = @last_trainer_capture_context
      return unless ctx && Time.now.to_i - ctx["time"].to_i <= 90
      species = AutoplayBot::DexTracker.species_key(pokemon.species) rescue ctx["species_key"]
      return unless state_ready? && AutoplayBot::State.respond_to?(:record_trainer_rocket_capture)
      AutoplayBot::State.record_trainer_rocket_capture(ctx["record"], species, ctx["ball"])
    rescue
      nil
    end

    def trainer_capture_battle_key(battle, record = nil)
      base = battle ? battle.object_id.to_s : "battle"
      trainer = record && AutoplayBot::State.respond_to?(:trainer_key) ? AutoplayBot::State.trainer_key(record) : nil
      [base, trainer].compact.join(":")
    rescue
      battle ? battle.object_id.to_s : "battle"
    end

    def trainer_capture_attempt_limit_per_battle
      2
    rescue
      2
    end

    def should_throw_ball_now?(battle, target, ball)
      ball_id = ball.to_sym
      turn = battle_turn(battle)
      ratio = hp_ratio(target)
      hard_needed = AutoplayBot::DexTracker.hard_needed_for?(target.pokemon)
      shiny = shiny_target?(target)
      statused = target_statused?(target)
      return true if ball_id == :MASTERBALL
      return true if ball_id == :QUICKBALL && turn <= 1
      if shiny
        return true if statused && ratio <= 0.95
        return true if ratio <= 0.72
        return true if turn >= 3 && ratio <= 0.90
        return true if turn >= 6
        return false
      end
      if trainer_capture_battle?(battle)
        return true if statused && ratio <= 0.90
        return true if ratio <= 0.58
        return true if hard_needed && ratio <= 0.72 && turn >= 3
        return true if turn >= 8 && ratio <= 0.85
        return true if turn >= 12 && (statused || ratio <= 0.90)
        return false
      end
      if capture_focus_wild_battle?(battle)
        return true if statused && ratio <= 0.90
        return true if ratio <= 0.52
        return true if hard_needed && ratio <= 0.72 && turn >= 2
        return true if statused && hard_needed && turn >= 2
        return true if turn >= 6 && ratio <= 0.78
        return true if turn >= 10
        return false
      end
      if defined?(AutoplayBot::Config) && AutoplayBot::Config.collector_heavy?
        return true if statused && ratio <= 0.88
        return true if ratio <= 0.62
        return true if hard_needed && ratio <= 0.78 && turn >= 2
        return true if hard_needed && turn >= 6
      end
      return true if statused && ratio <= 0.82
      return true if ratio <= 0.45
      return true if hard_needed && turn >= 4 && ratio <= 0.85
      false
    rescue
      false
    end

    def fallback_capture_throw_allowed?(battle, target, ball)
      return false unless battle && target && ball
      ball_id = ball.to_sym
      turn = battle_turn(battle)
      ratio = hp_ratio(target)
      statused = target_statused?(target)
      hard_needed = AutoplayBot::DexTracker.hard_needed_for?(target.pokemon) rescue false
      shiny = shiny_target?(target)
      return true if ball_id == :MASTERBALL
      return true if ball_id == :QUICKBALL && turn <= 1
      if shiny
        return true if statused && ratio <= 0.95
        return true if ratio <= 0.76
        return true if turn >= 3 && ratio <= 0.92
        return true if turn >= 6
        return false
      end
      if trainer_capture_battle?(battle)
        return true if statused && ratio <= 0.90
        return true if ratio <= 0.58
        return true if hard_needed && ratio <= 0.72 && turn >= 3
        return true if turn >= 8 && ratio <= 0.85
        return true if turn >= 12 && (statused || ratio <= 0.90)
        return false
      end
      return true if statused && ratio <= 0.92
      return true if ratio <= 0.58
      return true if hard_needed && ratio <= 0.74 && turn >= 3
      return true if turn >= 7 && ratio <= 0.86
      return true if turn >= 12
      false
    rescue
      false
    end

    def can_throw_ball?(battle, idx_battler, target, ball, first_action = true)
      return false unless first_action
      return false unless item_exists?(ball) && poke_ball?(ball) && bag_quantity(ball) > 0
      return false if trainer_capture_battle?(battle) && !trainer_ball_capture_allowed?(battle, target, ball)
      return true unless defined?(ItemHandlers) && ItemHandlers.respond_to?(:triggerCanUseInBattle)
      ItemHandlers.triggerCanUseInBattle(ball, target.pokemon, target, nil, first_action, battle, battle.scene, false)
    rescue
      wild_battle?(battle)
    end

    def try_register_capture_move(battle, idx_battler, target, ai = nil)
      user = battle.battlers[idx_battler] rescue nil
      return false unless user && user.respond_to?(:moves)
      candidates = []
      user.moves.each_with_index do |move, index|
        next unless move
        next unless can_choose_move?(battle, idx_battler, index)
        next unless move_can_target?(battle, user, move, target)
        score = capture_move_score(ai, move, user, target)
        candidates << [index, score, move] if score > 0
      end
      choice = candidates.sort_by { |entry| [-entry[1].to_i, entry[0].to_i] }.first
      return false unless choice
      return false unless battle.pbRegisterMove(idx_battler, choice[0], false)
      battle.pbRegisterTarget(idx_battler, target.index) rescue nil
      AutoplayBot.log("battle policy: capture setup #{move_label(choice[2])} for #{target.pokemon.name rescue target.pokemon.species}") if AutoplayBot.respond_to?(:log)
      AutoplayBot.status("battle: setup #{move_label(choice[2])}") if AutoplayBot.respond_to?(:status)
      true
    rescue => e
      AutoplayBot.log("capture move registration failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def capture_move_score(ai, move, user, target)
      id = move_key(move)
      ratio = hp_ratio(target)
      shiny = shiny_target?(target)
      if CAPTURE_STATUS_MOVES.include?(id) && !target_statused?(target)
        return 0 if shiny && id == "WILLOWISP" && ratio <= 0.80
        return shiny ? (id == "WILLOWISP" ? 90 : 175) : 130
      end
      return shiny ? 165 : 125 if ["FALSESWIPE", "HOLDBACK"].include?(id) && ratio > 0.12
      return shiny ? 110 : 95 if ["SUPERFANG", "NATURESMADNESS"].include?(id) && ratio > 0.55
      return 0 unless damaging_move?(move)
      return 0 if risky_capture_attack?(move)
      return 0 if ratio <= (shiny ? 0.65 : 0.45)
      damage = capture_damage_estimate(ai, move, user, target)
      return 0 if damage <= 0
      remaining = target.hp.to_i - damage.to_i
      return 0 if remaining <= 1
      total = target.totalhp.to_f
      after_ratio = total > 0 ? (remaining.to_f / total) : 1.0
      return 0 if after_ratio <= (shiny ? 0.30 : 0.18)
      ideal = shiny ? 0.58 : (ratio > 0.75 ? 0.48 : 0.35)
      score = 70 - ((after_ratio - ideal).abs * 100).round
      score += 10 if move_power(move) <= 60
      cap = shiny ? 95 : 80
      [[score, 10].max, cap].min
    rescue
      0
    end

    def try_register_safe_weaken_move(battle, idx_battler, target, ai = nil)
      return false unless wild_battle?(battle) || trainer_capture_battle?(battle)
      ratio = hp_ratio(target)
      shiny = shiny_target?(target)
      return false if ratio <= (shiny ? 0.65 : 0.45)
      user = battle.battlers[idx_battler] rescue nil
      return false unless user && user.respond_to?(:moves)
      choices = []
      user.moves.each_with_index do |move, index|
        next unless move
        next unless can_choose_move?(battle, idx_battler, index)
        next unless move_can_target?(battle, user, move, target)
        next unless damaging_move?(move)
        next if risky_capture_attack?(move)
        power = move_power(move)
        next if power <= 0
        next unless safe_capture_power?(power, ratio)
        damage = capture_damage_estimate(ai, move, user, target)
        next if damage <= 0
        remaining = target.hp.to_i - damage.to_i
        next if remaining <= 1
        after_ratio = target.totalhp.to_f > 0 ? remaining.to_f / target.totalhp.to_f : 1.0
        next if after_ratio <= (shiny ? 0.30 : 0.18)
        ideal = shiny ? 0.58 : (ratio > 0.75 ? 0.50 : 0.34)
        score = 55 - ((after_ratio - ideal).abs * 100).round
        score -= power / 10
        score += 12 if shiny && power <= 50
        choices << [index, score, move]
      end
      choice = choices.sort_by { |entry| [-entry[1].to_i, entry[0].to_i] }.first
      return false unless choice
      return false unless battle.pbRegisterMove(idx_battler, choice[0], false)
      battle.pbRegisterTarget(idx_battler, target.index) rescue nil
      AutoplayBot.status("battle: weaken #{move_label(choice[2])}") if AutoplayBot.respond_to?(:status)
      AutoplayBot.log("battle policy: safe weaken #{move_label(choice[2])} before catch") if AutoplayBot.respond_to?(:log)
      true
    rescue => e
      AutoplayBot.log("safe weaken failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def safe_capture_power?(power, hp_ratio_value)
      return true if hp_ratio_value >= 0.78 && power <= 90
      return true if hp_ratio_value >= 0.62 && power <= 65
      return true if hp_ratio_value >= 0.48 && power <= 45
      false
    rescue
      false
    end

    def risky_capture_attack?(move)
      id = move_key(move)
      return true if CAPTURE_RISKY_ATTACKS.include?(id)
      name = move_label(move).to_s.upcase.gsub(/[^A-Z0-9]/, "")
      CAPTURE_RISKY_ATTACKS.include?(name)
    rescue
      false
    end

    def capture_damage_estimate(ai, move, user, target)
      native = nil
      native = ai.pbRoughDamage(move, user, target, 100) if ai && ai.respond_to?(:pbRoughDamage)
      if native && native.to_i > 0
        total = target.respond_to?(:totalhp) ? target.totalhp.to_i : 0
        return native.to_i if total <= 0 || native.to_i <= total * 2
      end
      power = move_power(move)
      return 0 if power <= 0
      level = battle_level(user)
      offense = physical_capture_move?(move, user) ? stat_value(user, :attack, :atk) : stat_value(user, :spatk, :special_attack)
      defense = physical_capture_move?(move, user) ? stat_value(target, :defense, :def) : stat_value(target, :spdef, :special_defense)
      offense = 1 if offense <= 0
      defense = 1 if defense <= 0
      damage = (((((2.0 * level / 5.0) + 2.0) * power.to_f * offense.to_f / defense.to_f) / 50.0) + 2.0)
      damage *= 1.5 if same_type_attack_bonus?(user, move)
      damage *= type_effectiveness(move, user, target).to_f / normal_effectiveness.to_f
      [[damage.round, 1].max, 999].min
    rescue
      move_power(move)
    end

    def physical_capture_move?(move, user = nil)
      type = move_type_symbol(move, user)
      if move.respond_to?(:physicalMove?)
        arity = move.method(:physicalMove?).arity rescue 1
        return arity == 0 ? move.physicalMove? : move.physicalMove?(type)
      end
      return move.physical? if move.respond_to?(:physical?)
      return move.physical_move? if move.respond_to?(:physical_move?)
      category = move.category if move.respond_to?(:category)
      return category.to_s.upcase.include?("PHYSICAL") if category
      true
    rescue
      true
    end

    def battle_level(battler_or_pokemon)
      return battler_or_pokemon.level.to_i if battler_or_pokemon.respond_to?(:level) && battler_or_pokemon.level.to_i > 0
      pokemon = battler_or_pokemon.pokemon if battler_or_pokemon.respond_to?(:pokemon)
      return pokemon.level.to_i if pokemon && pokemon.respond_to?(:level) && pokemon.level.to_i > 0
      5
    rescue
      5
    end

    def stat_value(battler_or_pokemon, *names)
      names.each do |name|
        return battler_or_pokemon.send(name).to_i if battler_or_pokemon.respond_to?(name) && battler_or_pokemon.send(name).to_i > 0
      end
      pokemon = battler_or_pokemon.pokemon if battler_or_pokemon.respond_to?(:pokemon)
      if pokemon
        names.each do |name|
          return pokemon.send(name).to_i if pokemon.respond_to?(name) && pokemon.send(name).to_i > 0
        end
      end
      1
    rescue
      1
    end

    def try_register_survival_item(battle, idx_battler, first_action = true)
      user = battle.battlers[idx_battler] rescue nil
      return false unless user && user.respond_to?(:pokemon) && user.pokemon
      ratio = hp_ratio(user)
      missing = user.totalhp.to_i - user.hp.to_i
      return false if missing <= 0
      pressure = incoming_pressure(battle, idx_battler)
      urgent = ratio <= 0.34 || (ratio <= 0.55 && pressure >= user.hp.to_i)
      return false unless urgent
      item = best_healing_item(battle, idx_battler, user.pokemonIndex, user, missing, first_action)
      return false unless item
      AutoplayBot.log("battle policy: using #{item} on #{user.name} hp=#{user.hp}/#{user.totalhp}") if AutoplayBot.respond_to?(:log)
      battle.pbRegisterItem(idx_battler, item, user.pokemonIndex)
      true
    rescue => e
      AutoplayBot.log("battle heal item failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def best_healing_item(battle, idx_battler, party_index, battler, missing, first_action = true)
      status = status_of(battler)
      candidates = HEAL_ITEMS.select do |item, amount|
        next false if item == :FULLRESTORE && status == :NONE && missing.to_i < 80
        next false unless bag_quantity(item) > 0
        can_use_battle_item?(battle, idx_battler, item, party_index, battler, nil, first_action)
      end
      candidates.sort_by do |item, amount|
        overheal = amount.to_i >= 9999 ? 250 : (amount.to_i - missing.to_i).abs
        status_bonus = item == :FULLRESTORE && status != :NONE ? -200 : 0
        [status_bonus + overheal, amount.to_i]
      end.first&.first
    rescue
      nil
    end

    def try_register_status_item(battle, idx_battler, first_action = true)
      user = battle.battlers[idx_battler] rescue nil
      return false unless user && user.respond_to?(:pokemon) && user.pokemon
      status = status_of(user)
      return false if status == :NONE
      return false unless status_urgent?(user, status)
      candidates = STATUS_ITEMS[status] || []
      item = candidates.find do |candidate|
        bag_quantity(candidate) > 0 &&
          can_use_battle_item?(battle, idx_battler, candidate, user.pokemonIndex, user, nil, first_action)
      end
      return false unless item
      AutoplayBot.log("battle policy: curing #{status} with #{item} on #{user.name}") if AutoplayBot.respond_to?(:log)
      battle.pbRegisterItem(idx_battler, item, user.pokemonIndex)
      true
    rescue => e
      AutoplayBot.log("battle status item failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def try_register_revive_item(battle, idx_battler, first_action = true)
      return false unless battle.respond_to?(:trainerBattle?) && battle.trainerBattle?
      user = battle.battlers[idx_battler] rescue nil
      return false unless user && hp_ratio(user) >= 0.55
      party = battle.pbParty(idx_battler) rescue []
      candidates = []
      party.each_with_index do |pkmn, i|
        next unless pkmn && pkmn.respond_to?(:fainted?) && pkmn.fainted?
        candidates << [i, AutoplayBot::TeamBuilder.score_pokemon(pkmn)]
      end
      target = candidates.sort_by { |entry| -entry[1].to_i }.first
      return false unless target
      item = REVIVE_ITEMS.find do |candidate|
        bag_quantity(candidate) > 0 &&
          can_use_battle_item?(battle, idx_battler, candidate, target[0], nil, nil, first_action)
      end
      return false unless item
      AutoplayBot.log("battle policy: reviving party slot #{target[0]} with #{item}") if AutoplayBot.respond_to?(:log)
      battle.pbRegisterItem(idx_battler, item, target[0])
      true
    rescue => e
      AutoplayBot.log("battle revive item failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def try_register_smart_switch(battle, idx_battler, ai = nil)
      user = battle.battlers[idx_battler] rescue nil
      return false unless user && battle.respond_to?(:pbCanSwitch?)
      emergency = emergency_switch?(battle, idx_battler, user, ai)
      return false unless emergency || should_switch?(battle, idx_battler, user, ai)
      return false unless switch_cooldown_ready?(battle, idx_battler) || (emergency && !has_usable_damaging_move?(battle, idx_battler))
      choice = best_switch_choice(battle, idx_battler, false, ai)
      return false unless choice
      active_score = active_switch_score(battle, idx_battler, user, ai)
      margin = choice[1].to_i - active_score.to_i
      move_score = best_current_move_score(battle, idx_battler, ai)
      return false if emergency && margin < -70 && has_usable_damaging_move?(battle, idx_battler)
      return false if !emergency && move_score >= 45 && margin < 260
      return false if !emergency && margin < 180
      AutoplayBot.log("battle policy: switching #{user.name} to #{choice[2].name rescue "slot #{choice[0]}"}") if AutoplayBot.respond_to?(:log)
      return false unless battle.pbRegisterSwitch(idx_battler, choice[0])
      remember_switch(battle, idx_battler, choice[0], (user.pokemonIndex if user.respond_to?(:pokemonIndex)))
      true
    rescue => e
      AutoplayBot.log("battle switch failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def should_switch?(battle, idx_battler, user, ai = nil)
      return true if emergency_switch?(battle, idx_battler, user, ai)
      return false unless switch_cooldown_ready?(battle, idx_battler)
      choice = best_switch_choice(battle, idx_battler, false, ai)
      return false unless choice
      choice[1].to_i - active_switch_score(battle, idx_battler, user, ai).to_i >= 180
    rescue
      false
    end

    def emergency_switch?(battle, idx_battler, user, ai = nil)
      return true if hp_ratio(user) <= 0.18
      pressure = incoming_pressure_against(battle, idx_battler, user, nil, ai)
      return true if pressure >= [user.hp.to_i, 1].max && hp_ratio(user) <= 0.45
      return true unless has_usable_damaging_move?(battle, idx_battler)
      false
    rescue
      false
    end

    def best_switch_choice(battle, idx_battler, check_lax_only = false, ai = nil, targets = nil)
      choices = switch_candidates(battle, idx_battler, check_lax_only, ai, targets, false)
      choices.sort_by { |entry| [-entry[1].to_i, entry[0].to_i] }.first
    rescue
      nil
    end

    def switch_candidates(battle, idx_battler, check_lax_only = false, ai = nil, targets = nil, allow_recent = false)
      party = battle.pbParty(idx_battler) rescue []
      choices = []
      party.each_with_index do |pkmn, i|
        next unless pkmn
        can_switch = if check_lax_only && battle.respond_to?(:pbCanSwitchLax?)
                       battle.pbCanSwitchLax?(idx_battler, i)
                     elsif battle.respond_to?(:pbCanSwitch?)
                       battle.pbCanSwitch?(idx_battler, i)
                     else
                       pkmn.respond_to?(:able?) ? pkmn.able? : true
                     end
        next unless can_switch
        next if !allow_recent && recent_switch_target?(battle, idx_battler, i)
        choices << [i, switch_score(battle, idx_battler, pkmn, ai, targets), pkmn]
      end
      choices
    rescue
      []
    end

    def best_replacement_index(battle, idx_battler, check_lax_only = false, can_cancel = false, ai = nil)
      choices = switch_candidates(battle, idx_battler, check_lax_only, ai, opposing_targets(battle, idx_battler, true), true)
      choice = choices.sort_by { |entry| [-entry[1].to_i, entry[0].to_i] }.first
      if choice
        remember_switch(battle, idx_battler, choice[0], nil)
        AutoplayBot.status("battle: send #{pokemon_label(choice[2])}") if AutoplayBot.respond_to?(:status)
        AutoplayBot.log("battle replacement: slot #{choice[0]} #{pokemon_label(choice[2])}") if AutoplayBot.respond_to?(:log)
        return choice[0].to_i
      end
      can_cancel ? -1 : nil
    rescue => e
      AutoplayBot.log("battle replacement failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      can_cancel ? -1 : nil
    end

    def switch_score(battle, idx_battler, pokemon, ai = nil, targets = nil)
      return -9999 if pokemon.respond_to?(:fainted?) && pokemon.fainted?
      return -9999 if pokemon.respond_to?(:hp) && pokemon.hp.to_i <= 0
      targets ||= opposing_targets(battle, idx_battler, true)
      score = AutoplayBot::TeamBuilder.score_pokemon(pokemon)
      score += pokemon.hp.to_i * 120 / [pokemon.totalhp.to_i, 1].max if pokemon.respond_to?(:hp) && pokemon.respond_to?(:totalhp)
      score += 80 if pokemon.respond_to?(:status) && pokemon.status == :NONE
      score += party_move_pressure(pokemon, targets) * 2
      score -= incoming_pressure_against(battle, idx_battler, pokemon, targets, ai)
      score
    rescue
      0
    end

    def active_switch_score(battle, idx_battler, user, ai = nil, targets = nil)
      pokemon = user.respond_to?(:pokemon) && user.pokemon ? user.pokemon : user
      score = switch_score(battle, idx_battler, pokemon, ai, targets)
      score += 65 if has_usable_damaging_move?(battle, idx_battler)
      score -= 90 if hp_ratio(user) <= 0.22
      score -= 45 if hp_ratio(user) <= 0.40
      score -= 40 if status_of(user) != :NONE
      score
    rescue
      80
    end

    def switch_cooldown_ready?(battle, idx_battler)
      last = last_switch_turn(battle, idx_battler)
      return true if last.nil?
      battle_turn(battle) - last.to_i >= 4
    rescue
      true
    end

    def remember_switch(battle, idx_battler, to_party_index = nil, from_party_index = nil)
      @last_switch_turns ||= {}
      @last_switch_turns[[battle.object_id, idx_battler.to_i]] = battle_turn(battle)
      @last_switch_targets ||= {}
      @last_switch_targets[[battle.object_id, idx_battler.to_i]] = {
        "turn" => battle_turn(battle),
        "to" => to_party_index.nil? ? nil : to_party_index.to_i,
        "from" => from_party_index.nil? ? nil : from_party_index.to_i
      }
    rescue
      nil
    end

    def last_switch_turn(battle, idx_battler)
      @last_switch_turns ||= {}
      @last_switch_turns[[battle.object_id, idx_battler.to_i]]
    rescue
      nil
    end

    def recent_switch_target?(battle, idx_battler, party_index)
      @last_switch_targets ||= {}
      entry = @last_switch_targets[[battle.object_id, idx_battler.to_i]]
      return false unless entry
      return false if battle_turn(battle) - entry["turn"].to_i >= 4
      entry["from"] && party_index.to_i == entry["from"].to_i
    rescue
      false
    end

    def best_current_move_score(battle, idx_battler, ai = nil)
      user = battle.battlers[idx_battler] rescue nil
      return 0 unless user && user.respond_to?(:moves)
      scores = []
      user.moves.each_with_index do |move, index|
        next unless move && can_choose_move?(battle, idx_battler, index)
        move_choices_for(battle, idx_battler, user, move, index, ai).each { |entry| scores << entry[1].to_i }
      end
      scores.max.to_i
    rescue
      0
    end

    def try_register_best_move(battle, idx_battler, ai = nil)
      user = battle.battlers[idx_battler] rescue nil
      return false unless user && user.respond_to?(:moves)
      choices = []
      user.moves.each_with_index do |move, index|
        next unless move
        next unless can_choose_move?(battle, idx_battler, index)
        choices.concat(move_choices_for(battle, idx_battler, user, move, index, ai))
      end
      if choices.empty?
        if battle.respond_to?(:pbAutoChooseMove)
          AutoplayBot.status("battle: no PP, Struggle") if AutoplayBot.respond_to?(:status)
          AutoplayBot.log("battle policy: no legal moves for battler #{idx_battler}; using native auto move/Struggle") if AutoplayBot.respond_to?(:log)
          return battle.pbAutoChooseMove(idx_battler, false)
        end
        return false
      end
      choice = choices.sort_by { |entry| [-entry[1].to_i, entry[0].to_i] }.first
      return false unless battle.pbRegisterMove(idx_battler, choice[0], false)
      battle.pbRegisterTarget(idx_battler, choice[2]) if choice[2].to_i >= 0 && battle.respond_to?(:pbRegisterTarget)
      AutoplayBot.status("battle: #{move_label(choice[3])}") if AutoplayBot.respond_to?(:status)
      true
    rescue => e
      AutoplayBot.log("battle move choice failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def move_choices_for(battle, idx_battler, user, move, index, ai = nil)
      target_data = move.pbTarget(user) rescue nil
      return [[index, battle_move_score(ai, move, user, user), -1, move]] unless target_data
      if target_data.num_targets.to_i > 1
        score = 0
        battle.battlers.compact.each do |target|
          next unless move_can_target?(battle, user, move, target)
          value = battle_move_score(ai, move, user, target)
          score += battle.opposes?(idx_battler) == battle.opposes?(target.index) ? -value : value
        end
        return score > 0 ? [[index, score, -1, move]] : []
      elsif target_data.num_targets.to_i == 0
        return [[index, battle_move_score(ai, move, user, user), -1, move]]
      end
      choices = []
      battle.battlers.compact.each do |target|
        next unless move_can_target?(battle, user, move, target)
        next if target_data.respond_to?(:targets_foe) && target_data.targets_foe && !user.opposes?(target)
        score = battle_move_score(ai, move, user, target)
        choices << [index, score, target.index, move] if score > 0
      end
      choices
    rescue
      []
    end

    def battle_move_score(ai, move, user, target)
      return 0 unless move_has_pp?(move)
      if ai && ai.respond_to?(:pbGetMoveScore)
        score = ai.pbGetMoveScore(move, user, target, 100) rescue nil
        return score.to_i if score && score.to_i > 0
      end
      if damaging_move?(move)
        damage = rough_damage(ai, move, user, target)
        base = damage > 0 ? damage : move_power(move)
        accuracy = move_accuracy(move)
        score = base.to_i * [accuracy, 100].min / 100
        score += 15 if same_type_attack_bonus?(user, move)
        score += 12 if move_priority(move) > 0
        score -= AutoplayBot::TeamBuilder.low_pp_penalty(move) if defined?(AutoplayBot::TeamBuilder)
        return [score, 1].max
      end
      score = AutoplayBot::TeamBuilder.status_move_value(move)
      score -= AutoplayBot::TeamBuilder.low_pp_penalty(move) if defined?(AutoplayBot::TeamBuilder)
      [score, 1].max
    rescue
      1
    end

    def can_choose_move?(battle, idx_battler, index)
      user = battle.battlers[idx_battler] rescue nil
      move = user.moves[index] if user && user.respond_to?(:moves)
      return false unless move && move_has_pp?(move)
      return battle.pbCanChooseMove?(idx_battler, index, false) if battle.respond_to?(:pbCanChooseMove?)
      true
    rescue
      false
    end

    def move_has_pp?(move)
      return AutoplayBot::TeamBuilder.move_has_pp?(move) if defined?(AutoplayBot::TeamBuilder)
      return true unless move && move.respond_to?(:pp)
      total = move.respond_to?(:total_pp) ? move.total_pp.to_i : 0
      total = move.totalpp.to_i if total <= 0 && move.respond_to?(:totalpp)
      return true if total <= 0
      move.pp.to_i > 0
    rescue
      true
    end

    def move_can_target?(battle, user, move, target)
      return false unless target && target.respond_to?(:index)
      target_data = move.pbTarget(user) rescue nil
      return true unless target_data && battle.respond_to?(:pbMoveCanTarget?)
      battle.pbMoveCanTarget?(user.index, target.index, target_data)
    rescue
      false
    end

    def can_use_battle_item?(battle, idx_battler, item, party_index, battler = nil, move_index = nil, first_action = true)
      return false unless item_exists?(item) && bag_quantity(item) > 0
      party = battle.pbParty(idx_battler) rescue []
      pkmn = party_index.nil? ? (battler && battler.respond_to?(:pokemon) ? battler.pokemon : nil) : party[party_index]
      battler ||= battle.pbFindBattler(party_index, idx_battler) rescue nil
      return false if battle.respond_to?(:pbCanUseItemOnPokemon?) &&
                      !battle.pbCanUseItemOnPokemon?(item, pkmn, battler, battle.scene, false)
      return true unless defined?(ItemHandlers) && ItemHandlers.respond_to?(:triggerCanUseInBattle)
      ItemHandlers.triggerCanUseInBattle(item, pkmn, battler, move_index, first_action, battle, battle.scene, false)
    rescue
      false
    end

    def best_ball_for(target, battle = nil)
      return nil unless defined?($PokemonBag) && $PokemonBag && defined?(GameData::Item)
      priority = ball_priority_for(target, battle)
      priority.find do |item|
        item_exists?(item) &&
          poke_ball?(item) &&
          bag_quantity(item) > 0 &&
          capture_ball_allowed?(battle, target, item)
      end
    rescue
      nil
    end

    def ball_priority_for(target, battle = nil)
      if trainer_capture_battle?(battle)
        return TRAINER_ROCKET_BALL_PRIORITY if trainer_capture_mode == 1
        return trainer_ball_priority(target, battle)
      end
      normal_ball_priority(target, battle)
    rescue
      normal_ball_priority(target, battle)
    end

    def trainer_ball_priority(target, battle = nil)
      (TRAINER_ROCKET_BALL_PRIORITY + normal_ball_priority(target, battle)).uniq
    rescue
      normal_ball_priority(target, battle)
    end

    def normal_ball_priority(target, battle = nil)
      priority = BALL_PRIORITY.reject { |item| reserved_trainer_ball?(item) }
      priority = priority.reject { |item| item == :QUICKBALL } if wild_battle?(battle) && battle_turn(battle) > 1
      return priority if masterball_ok?(target)
      priority.reject { |item| item == :MASTERBALL }
    rescue
      BALL_PRIORITY.reject { |item| item == :MASTERBALL || item == :ROCKETBALL }
    end

    def capture_ball_allowed?(battle, target, ball)
      if wild_battle?(battle) && reserved_trainer_ball?(ball)
        return false
      end
      return true unless trainer_capture_battle?(battle)
      trainer_ball_capture_allowed?(battle, target, ball)
    rescue
      false
    end

    def wild_capture_ball_count_without_reserved
      BALL_PRIORITY.reject { |item| reserved_trainer_ball?(item) || item == :MASTERBALL }.inject(0) do |sum, item|
        sum + bag_quantity(item).to_i
      end
    rescue
      0
    end

    def reserved_trainer_ball?(ball)
      RESERVED_TRAINER_BALLS.include?(ball.to_sym)
    rescue
      false
    end

    def trainer_ball_capture_allowed?(battle, target, ball)
      return false unless battle && target && ball
      if battle.respond_to?(:pbTrainerBallCaptureAllowed?)
        return battle.pbTrainerBallCaptureAllowed?(ball, target)
      end
      mode = trainer_capture_mode
      data = GameData::Item.get(ball) rescue nil
      return false unless data && data.respond_to?(:is_poke_ball?) && data.is_poke_ball?
      return data.respond_to?(:id) && data.id == :ROCKETBALL if mode == 1
      return true if mode == 2
      false
    rescue
      false
    end

    def masterball_ok?(target)
      return false unless target && target.respond_to?(:pokemon) && target.pokemon
      return true if shiny_target?(target)
      return false if AutoplayBot::Config.rare_policy.to_s == "defer"
      data = target.pokemon.respond_to?(:species_data) ? target.pokemon.species_data : nil
      data && data.respond_to?(:catch_rate) && data.catch_rate.to_i <= 5
    rescue
      false
    end

    def item_exists?(item)
      return false unless defined?(GameData::Item)
      return GameData::Item.exists?(item) if GameData::Item.respond_to?(:exists?)
      !!GameData::Item.get(item)
    rescue
      false
    end

    def poke_ball?(item)
      data = GameData::Item.get(item) rescue nil
      data && data.respond_to?(:is_poke_ball?) && data.is_poke_ball?
    rescue
      false
    end

    def bag_quantity(item)
      return 0 unless defined?($PokemonBag) && $PokemonBag
      return $PokemonBag.pbQuantity(item).to_i if $PokemonBag.respond_to?(:pbQuantity)
      return $PokemonBag.pbHasItem?(item) ? 1 : 0 if $PokemonBag.respond_to?(:pbHasItem?)
      0
    rescue
      0
    end

    def battle_turn(battle)
      return battle.turnCount.to_i if battle.respond_to?(:turnCount)
      0
    rescue
      0
    end

    def hp_ratio(battler_or_pokemon)
      hp = battler_or_pokemon.hp.to_f
      total = battler_or_pokemon.totalhp.to_f
      return 1.0 if total <= 0
      hp / total
    rescue
      1.0
    end

    def status_of(battler_or_pokemon)
      status = battler_or_pokemon.status if battler_or_pokemon.respond_to?(:status)
      return :NONE if status.nil?
      status
    rescue
      :NONE
    end

    def status_urgent?(battler, status)
      return true if [:SLEEP, :FROZEN].include?(status)
      return true if hp_ratio(battler) <= 0.65
      return true if [:BURN, :PARALYSIS].include?(status)
      false
    rescue
      false
    end

    def target_statused?(battler)
      status_of(battler) != :NONE
    rescue
      false
    end

    def opposing_battlers(battle, idx_battler)
      return [] unless battle && battle.respond_to?(:battlers)
      battle.battlers.compact.select do |battler|
        next false unless battler.respond_to?(:index)
        next false if battler.respond_to?(:fainted?) && battler.fainted?
        battle.opposes?(idx_battler) != battle.opposes?(battler.index)
      end
    rescue
      []
    end

    def opposing_targets(battle, idx_battler, include_pending = false)
      targets = opposing_battlers(battle, idx_battler)
      if include_pending
        pending_enemy_targets(battle, idx_battler).each do |target|
          targets << target unless targets.include?(target)
        end
      end
      targets.compact
    rescue
      []
    end

    def incoming_pressure(battle, idx_battler)
      user = battle.battlers[idx_battler] rescue nil
      incoming_pressure_against(battle, idx_battler, user)
    rescue
      0
    end

    def incoming_pressure_against(battle, idx_battler, defender, targets = nil, ai = nil)
      return 0 unless defender
      targets ||= opposing_targets(battle, idx_battler, false)
      targets.map { |foe| best_damage_against(ai, foe, defender) }.max.to_i
    rescue
      0
    end

    def best_damage_against(ai, user, target)
      return 0 unless user && user.respond_to?(:moves)
      user.moves.compact.map { |move| move_has_pp?(move) ? rough_damage(ai, move, user, target) : 0 }.max.to_i
    rescue
      0
    end

    def party_move_pressure(pokemon, targets)
      return 0 unless pokemon && pokemon.respond_to?(:moves)
      target_list = targets && !targets.empty? ? targets : [nil]
      pokemon.moves.compact.map do |move|
        next 0 unless damaging_move?(move)
        next 0 unless move_has_pp?(move)
        target_list.map { |target| offensive_move_score(move, pokemon, target) }.max.to_i
      end.max.to_i
    rescue
      0
    end

    def has_usable_damaging_move?(battle, idx_battler)
      user = battle.battlers[idx_battler] rescue nil
      return false unless user && user.respond_to?(:moves)
      user.moves.each_with_index.any? do |move, index|
        damaging_move?(move) && can_choose_move?(battle, idx_battler, index)
      end
    rescue
      false
    end

    def rough_damage(ai, move, user, target)
      if ai && ai.respond_to?(:pbRoughDamage)
        value = ai.pbRoughDamage(move, user, target, 100) rescue nil
        return value.to_i if value && value.to_i > 0
      end
      offensive_move_score(move, user, target)
    rescue
      move_power(move)
    end

    def offensive_move_score(move, user, target)
      power = move_power(move)
      return 0 if power <= 0
      score = power * type_effectiveness(move, user, target).to_f / normal_effectiveness.to_f
      score += power * 0.20 if same_type_attack_bonus?(user, move)
      score += 10 if move_priority(move) > 0
      [score.round, 1].max
    rescue
      move_power(move)
    end

    def type_effectiveness(move_or_type, user = nil, target = nil)
      return normal_effectiveness unless target && defined?(Effectiveness)
      move_type = move_or_type.is_a?(Symbol) ? move_or_type : move_type_symbol(move_or_type, user)
      return normal_effectiveness unless move_type
      if move_or_type.respond_to?(:pbCalcTypeMod) && user && target.respond_to?(:pbTypes)
        value = move_or_type.pbCalcTypeMod(move_type, user, target) rescue nil
        return value if value
      end
      types = pokemon_type_symbols(target)
      return normal_effectiveness if types.empty?
      Effectiveness.calculate(move_type, types[0], types[1], types[2])
    rescue
      normal_effectiveness
    end

    def normal_effectiveness
      return Effectiveness::NORMAL_EFFECTIVE if defined?(Effectiveness) && Effectiveness.const_defined?(:NORMAL_EFFECTIVE)
      8
    rescue
      8
    end

    def move_type_symbol(move, user = nil)
      type = nil
      type = move.pbCalcType(user) if user && move.respond_to?(:pbCalcType)
      type ||= move.type if move.respond_to?(:type)
      type ||= move.type_id if move.respond_to?(:type_id)
      type = type.id if type.respond_to?(:id)
      return nil if type.nil? || type.to_s.empty?
      type.is_a?(Symbol) ? type : type.to_s.upcase.to_sym
    rescue
      nil
    end

    def pokemon_type_symbols(pokemon)
      return [] unless pokemon
      types = pokemon.pbTypes(true) if pokemon.respond_to?(:pbTypes)
      types ||= pokemon.types if pokemon.respond_to?(:types)
      if (!types || types.empty?) && pokemon.respond_to?(:species_data) && pokemon.species_data
        data = pokemon.species_data
        types = []
        types << data.type1 if data.respond_to?(:type1)
        types << data.type2 if data.respond_to?(:type2)
        types << data.type3 if data.respond_to?(:type3)
      end
      if (!types || types.empty?) && (pokemon.respond_to?(:type1) || pokemon.respond_to?(:type2))
        types = []
        types << pokemon.type1 if pokemon.respond_to?(:type1)
        types << pokemon.type2 if pokemon.respond_to?(:type2)
        types << pokemon.type3 if pokemon.respond_to?(:type3)
      end
      Array(types).compact.map { |type| type.is_a?(Symbol) ? type : type.to_s.upcase.to_sym }.uniq
    rescue
      []
    end

    def damaging_move?(move)
      return move.damagingMove? if move.respond_to?(:damagingMove?)
      move_power(move) > 0
    rescue
      false
    end

    def move_power(move)
      return move.baseDamage.to_i if move.respond_to?(:baseDamage)
      return move.base_damage.to_i if move.respond_to?(:base_damage)
      0
    rescue
      0
    end

    def move_accuracy(move)
      value = move.accuracy if move.respond_to?(:accuracy)
      value = 100 if value.nil? || value.to_i <= 0
      value.to_i
    rescue
      100
    end

    def move_priority(move)
      return move.priority.to_i if move.respond_to?(:priority)
      0
    rescue
      0
    end

    def same_type_attack_bonus?(user, move)
      return false unless defined?(AutoplayBot::TeamBuilder)
      AutoplayBot::TeamBuilder.stab_move?(user.respond_to?(:pokemon) ? user.pokemon : user, move)
    rescue
      false
    end

    def move_key(move)
      AutoplayBot::TeamBuilder.move_id_key(move)
    rescue
      move.to_s.upcase.gsub(/[^A-Z0-9]/, "")
    end

    def move_label(move)
      AutoplayBot::TeamBuilder.move_name(move)
    rescue
      "move"
    end

    def pokemon_label(pokemon)
      return pokemon.name.to_s if pokemon.respond_to?(:name) && pokemon.name
      return pokemon.species.to_s if pokemon.respond_to?(:species)
      "Pokemon"
    rescue
      "Pokemon"
    end

    def note_pending_enemy_switch(battle, idx_battler, idx_party)
      return unless battle && idx_party && idx_party.to_i >= 0
      @pending_enemy_switches ||= {}
      @pending_enemy_switches[battle.object_id] = {
        :idx_battler => idx_battler.to_i,
        :idx_party => idx_party.to_i
      }
    rescue
      nil
    end

    def clear_pending_enemy_switch(battle)
      @pending_enemy_switches ||= {}
      @pending_enemy_switches.delete(battle.object_id) if battle
    rescue
      nil
    end

    def pending_enemy_targets(battle, idx_battler)
      @pending_enemy_switches ||= {}
      pending = @pending_enemy_switches[battle.object_id] if battle
      return [] unless pending
      enemy_idx = pending[:idx_battler].to_i
      return [] unless battle.respond_to?(:opposes?) &&
                       battle.opposes?(idx_battler) != battle.opposes?(enemy_idx)
      party = battle.pbParty(enemy_idx) rescue []
      pokemon = party[pending[:idx_party].to_i]
      pokemon ? [pokemon] : []
    rescue
      []
    end

    def battle_confirm_response(battle, message)
      text = AutoplayBot::PromptPolicy.clean(message).downcase rescue message.to_s.downcase
      if text.include?("use next")
        AutoplayBot.status("battle: use next pokemon") if AutoplayBot.respond_to?(:status)
        return true
      end
      if text.include?("will you switch")
        answer = should_accept_switch_prompt?(battle, 0)
        AutoplayBot.status(answer ? "battle: switch for matchup" : "battle: stay in") if AutoplayBot.respond_to?(:status)
        clear_pending_enemy_switch(battle) unless answer
        return answer
      end
      nil
    rescue
      nil
    end

    def should_accept_switch_prompt?(battle, idx_battler = 0)
      user = battle.battlers[idx_battler] rescue nil
      targets = pending_enemy_targets(battle, idx_battler)
      return false unless user && !targets.empty?
      choice = best_switch_choice(battle, idx_battler, false, nil, targets)
      return false unless choice
      active_score = active_switch_score(battle, idx_battler, user, nil, targets)
      margin = choice[1].to_i - active_score.to_i
      pressure = incoming_pressure_against(battle, idx_battler, user, targets)
      emergency = hp_ratio(user) <= 0.28 || (pressure >= [user.hp.to_i, 1].max && hp_ratio(user) <= 0.55)
      return true if margin >= 130
      return true if emergency && margin >= -30
      false
    rescue
      false
    end
  end

  module ShopPolicy
    BALL_TARGET = 16 unless const_defined?(:BALL_TARGET)
    GREAT_BALL_TARGET = 14 unless const_defined?(:GREAT_BALL_TARGET)
    ULTRA_BALL_TARGET = 18 unless const_defined?(:ULTRA_BALL_TARGET)
    ROCKET_BALL_TARGET = 12 unless const_defined?(:ROCKET_BALL_TARGET)
    HEAL_TARGETS = {
      :POTION => 6,
      :SUPERPOTION => 8,
      :HYPERPOTION => 6,
      :ANTIDOTE => 2,
      :PARALYZEHEAL => 2,
      :AWAKENING => 1,
      :ESCAPEROPE => 1,
      :REPEL => 3
    } unless const_defined?(:HEAL_TARGETS)

    module_function

    def restock_needed?
      return false unless defined?($PokemonBag) && $PokemonBag
      return false if trainer_money < 500
      ball_floor = configured_min_standard_balls(collector_heavy? ? 18 : 10)
      heal_floor = configured_min_heals(collector_heavy? ? 6 : 4)
      rocket_floor = collector_heavy? ? 10 : 6
      return true if standard_ball_count < ball_floor
      return true if quantity(:POTION) + quantity(:SUPERPOTION) + quantity(:HYPERPOTION) < heal_floor
      return true if trainer_capture_mode == 1 && quantity(:ROCKETBALL) < rocket_floor
      false
    rescue
      false
    end

    def handle_mart(stock, speech = nil)
      return false unless bot_shopping?
      return false unless defined?(PokemonMartAdapter) && defined?(GameData::Item)
      adapter = PokemonMartAdapter.new
      items = normalize_stock(stock)
      money_before = adapter.getMoney.to_i rescue trainer_money
      AutoplayBot::ResourcePlanner.remember_shop_stock(items) if defined?(AutoplayBot::ResourcePlanner)
      return true if items.empty?
      purchases = buy_plan(items, adapter)
      money = adapter.getMoney.to_i rescue 0
      AutoplayBot::ResourcePlanner.record_purchase(purchases, money_before, money) if defined?(AutoplayBot::ResourcePlanner)
      if purchases.empty?
        AutoplayBot.status("shop: stocked $#{money}") if defined?(AutoplayBot)
      else
        AutoplayBot.status("shop: bought #{purchase_summary(purchases)} $#{money}") if defined?(AutoplayBot)
        AutoplayBot.log("smart shop bought #{purchase_summary(purchases)}; money=#{money}") if AutoplayBot.respond_to?(:log)
      end
      true
    rescue => e
      AutoplayBot.log("smart shop failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def handle_stock(stock, label = "shop")
      handle_mart(stock, label)
    rescue
      false
    end

    def bot_shopping?
      defined?(AutoplayBot::Runtime) &&
        AutoplayBot::Runtime.respond_to?(:prompt_control?) &&
        AutoplayBot::Runtime.prompt_control?
    rescue
      false
    end

    def buy_plan(stock, adapter)
      purchases = []
      desired_items(stock).each do |item, goal|
        buy_to_goal(item, goal, adapter, purchases)
      end
      purchases
    end

    def desired_items(stock)
      desired = []
      desired << [:ROCKETBALL, target_quantity(ROCKET_BALL_TARGET)] if trainer_capture_mode == 1 && stock.include?(:ROCKETBALL)
      if stock.include?(:ULTRABALL)
        desired << [:ULTRABALL, target_quantity(ULTRA_BALL_TARGET, :ULTRABALL)]
      elsif stock.include?(:GREATBALL)
        desired << [:GREATBALL, target_quantity(GREAT_BALL_TARGET, :GREATBALL)]
      elsif stock.include?(:POKEBALL)
        desired << [:POKEBALL, target_quantity(BALL_TARGET, :POKEBALL)]
      end
      HEAL_TARGETS.each do |item, goal|
        desired << [item, target_quantity(goal, item)] if stock.include?(item)
      end
      [:DNASPLICERS, :SUPERSPLICERS, :INFINITESPLICERS, :REVERSERS, :FUSIONBALL].each do |item|
        desired << [item, target_quantity(item == :FUSIONBALL ? 8 : 3)] if stock.include?(item)
      end
      desired
    rescue
      []
    end

    def target_quantity(base_goal, item = nil)
      base = base_goal.to_i
      if [:POKEBALL, :GREATBALL, :ULTRABALL, :FUSIONBALL, :PREMIERBALL, :QUICKBALL, :DUSKBALL, :TIMERBALL, :NETBALL].include?(item)
        base = configured_min_standard_balls(base)
      end
      return base unless collector_heavy?
      extra = [:REPEL, :ESCAPEROPE].include?(item) ? 1.0 : 1.45
      [(base * extra).ceil, base + 2].max
    rescue
      base_goal.to_i
    end

    def collector_heavy?
      defined?(AutoplayBot::Config) && AutoplayBot::Config.collector_heavy?
    rescue
      false
    end

    def buy_to_goal(item, goal, adapter, purchases)
      return unless item_available?(item)
      price = adapter.getPrice(item).to_i rescue item_price(item)
      return if price <= 0
      reserve = money_reserve(adapter.getMoney.to_i)
      while quantity(item) < goal.to_i
        money = adapter.getMoney.to_i
        break if money - price < reserve
        break unless bag_can_store?(item)
        break unless adapter.addItem(item)
        adapter.setMoney(money - price)
        purchases << item
      end
    rescue => e
      AutoplayBot.log("shop item #{item} failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    end

    def normalize_stock(stock)
      return [] unless stock.respond_to?(:each)
      stock.compact.map do |item|
        data = GameData::Item.get(item) rescue nil
        data && data.respond_to?(:id) ? data.id : item
      end.compact.uniq
    rescue
      []
    end

    def item_available?(item)
      return false unless defined?(GameData::Item)
      return GameData::Item.exists?(item) if GameData::Item.respond_to?(:exists?)
      !!GameData::Item.get(item)
    rescue
      false
    end

    def item_price(item)
      data = GameData::Item.get(item) rescue nil
      data && data.respond_to?(:price) ? data.price.to_i : 0
    rescue
      0
    end

    def quantity(item)
      return 0 unless defined?($PokemonBag) && $PokemonBag
      return $PokemonBag.pbQuantity(item).to_i if $PokemonBag.respond_to?(:pbQuantity)
      return $PokemonBag.pbHasItem?(item) ? 1 : 0 if $PokemonBag.respond_to?(:pbHasItem?)
      0
    rescue
      0
    end

    def total_ball_count
      [:POKEBALL, :GREATBALL, :ULTRABALL, :FUSIONBALL, :PREMIERBALL, :QUICKBALL, :DUSKBALL, :TIMERBALL, :ROCKETBALL].inject(0) do |sum, item|
        sum + quantity(item)
      end
    rescue
      0
    end

    def standard_ball_count
      [:POKEBALL, :GREATBALL, :ULTRABALL, :FUSIONBALL, :PREMIERBALL, :QUICKBALL, :DUSKBALL, :TIMERBALL, :NETBALL].inject(0) do |sum, item|
        sum + quantity(item)
      end
    rescue
      0
    end

    def configured_min_standard_balls(fallback)
      return fallback.to_i unless defined?(AutoplayBot::Config) && AutoplayBot::Config.respond_to?(:min_standard_balls)
      [AutoplayBot::Config.min_standard_balls.to_i, fallback.to_i].max
    rescue
      fallback.to_i
    end

    def configured_min_heals(fallback)
      return fallback.to_i unless defined?(AutoplayBot::Config) && AutoplayBot::Config.respond_to?(:min_heal_items)
      [AutoplayBot::Config.min_heal_items.to_i, fallback.to_i].max
    rescue
      fallback.to_i
    end

    def bag_can_store?(item)
      return true unless defined?($PokemonBag) && $PokemonBag
      return $PokemonBag.pbCanStore?(item, 1) if $PokemonBag.respond_to?(:pbCanStore?)
      true
    rescue
      false
    end

    def money_reserve(money)
      configured = defined?(AutoplayBot::Config) ? AutoplayBot::Config.min_money_reserve : 1000
      [[money.to_i / 5, configured.to_i].max, 2000].min
    rescue
      1000
    end

    def trainer_money
      return 0 unless defined?($Trainer) && $Trainer && $Trainer.respond_to?(:money)
      $Trainer.money.to_i
    rescue
      0
    end

    def trainer_capture_mode
      if defined?(AutoplayBot::BattlePolicy) && AutoplayBot::BattlePolicy.respond_to?(:trainer_capture_mode)
        return AutoplayBot::BattlePolicy.trainer_capture_mode
      end
      0
    rescue
      0
    end

    def purchase_summary(purchases)
      counts = {}
      purchases.each { |item| counts[item] = counts[item].to_i + 1 }
      counts.map { |item, count| "#{count}x #{item}" }.join(", ")
    rescue
      "items"
    end
  end

  module ResourcePlanner
    BALL_ITEMS = [:POKEBALL, :GREATBALL, :ULTRABALL, :FUSIONBALL, :PREMIERBALL, :QUICKBALL, :DUSKBALL, :TIMERBALL, :ROCKETBALL] unless const_defined?(:BALL_ITEMS)
    HEAL_ITEMS = [:POTION, :SUPERPOTION, :HYPERPOTION, :MAXPOTION, :FULLRESTORE, :REVIVE] unless const_defined?(:HEAL_ITEMS)
    STATUS_ITEMS = [:ANTIDOTE, :PARALYZEHEAL, :AWAKENING, :BURNHEAL, :ICEHEAL, :FULLHEAL] unless const_defined?(:STATUS_ITEMS)

    module_function

    def tick
      return unless defined?(AutoplayBot::State)
      frame = (Graphics.frame_count rescue 0).to_i
      @last_snapshot_frame = -9999 if @last_snapshot_frame.nil?
      return if frame - @last_snapshot_frame.to_i < 600
      @last_snapshot_frame = frame
      AutoplayBot::State.record_resource_snapshot(snapshot) if AutoplayBot::State.respond_to?(:record_resource_snapshot)
    rescue => e
      AutoplayBot.log("resource planner tick failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    end

    def snapshot
      {
        "money" => trainer_money,
        "balls" => total_quantity(BALL_ITEMS),
        "heals" => total_quantity(HEAL_ITEMS),
        "status" => total_quantity(STATUS_ITEMS),
        "escape_rope" => quantity(:ESCAPEROPE),
        "repels" => quantity(:REPEL) + quantity(:SUPERREPEL) + quantity(:MAXREPEL),
        "rocket_balls" => quantity(:ROCKETBALL),
        "plan" => current_plan
      }
    rescue
      { "plan" => current_plan }
    end

    def current_plan
      need = []
      need << "money" if trainer_money < 500
      ball_floor = if defined?(AutoplayBot::ShopPolicy) && AutoplayBot::ShopPolicy.respond_to?(:configured_min_standard_balls)
                     AutoplayBot::ShopPolicy.configured_min_standard_balls(collector_heavy? ? 18 : 10)
                   else
                     collector_heavy? ? 18 : 10
                   end
      heal_floor = if defined?(AutoplayBot::ShopPolicy) && AutoplayBot::ShopPolicy.respond_to?(:configured_min_heals)
                     AutoplayBot::ShopPolicy.configured_min_heals(collector_heavy? ? 6 : 4)
                   else
                     collector_heavy? ? 6 : 4
                   end
      status_floor = collector_heavy? ? 3 : 2
      rocket_floor = collector_heavy? ? 10 : 6
      need << "balls" if standard_ball_count < ball_floor
      need << "healing" if total_quantity(HEAL_ITEMS) < heal_floor
      need << "status cures" if total_quantity(STATUS_ITEMS) < status_floor
      need << "rocket balls" if trainer_capture_mode == 1 && quantity(:ROCKETBALL) < rocket_floor
      {
        "need" => need,
        "restock_needed" => !need.empty? && trainer_money >= 500,
        "policy" => (defined?(AutoplayBot::Config) ? AutoplayBot::Config.resource_autonomy : "legit_shop_flow")
      }
    rescue
      { "need" => [], "restock_needed" => false, "policy" => "legit_shop_flow" }
    end

    def remember_shop_stock(stock)
      return unless defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:remember_shop_stock)
      map_id = defined?($game_map) && $game_map ? $game_map.map_id : nil
      AutoplayBot::State.remember_shop_stock(map_id, stock)
    rescue
      nil
    end

    def record_purchase(purchases, money_before, money_after)
      return unless defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:record_purchase)
      AutoplayBot::State.record_purchase(purchases, money_before, money_after)
      AutoplayBot::State.record_resource_snapshot(snapshot) if AutoplayBot::State.respond_to?(:record_resource_snapshot)
    rescue
      nil
    end

    def total_quantity(items)
      items.inject(0) { |sum, item| sum + quantity(item) }
    rescue
      0
    end

    def standard_ball_count
      if defined?(AutoplayBot::ShopPolicy) && AutoplayBot::ShopPolicy.respond_to?(:standard_ball_count)
        return AutoplayBot::ShopPolicy.standard_ball_count
      end
      total_quantity(BALL_ITEMS.reject { |item| item == :ROCKETBALL || item == :MASTERBALL })
    rescue
      0
    end

    def collector_heavy?
      defined?(AutoplayBot::Config) && AutoplayBot::Config.collector_heavy?
    rescue
      false
    end

    def quantity(item)
      return AutoplayBot::ShopPolicy.quantity(item) if defined?(AutoplayBot::ShopPolicy)
      0
    rescue
      0
    end

    def trainer_money
      return AutoplayBot::ShopPolicy.trainer_money if defined?(AutoplayBot::ShopPolicy)
      0
    rescue
      0
    end

    def trainer_capture_mode
      return AutoplayBot::ShopPolicy.trainer_capture_mode if defined?(AutoplayBot::ShopPolicy)
      0
    rescue
      0
    end
  end

  module RepeatableBattleLedger
    module_function

    def state_ready?
      defined?(AutoplayBot::State) &&
        (!AutoplayBot::State.respond_to?(:loaded?) || AutoplayBot::State.loaded?)
    rescue
      false
    end

    def note_battle_start(battle)
      return if battle.nil? || wild_battle?(battle)
      @active_battle ||= {}
      key = battle_object_id(battle)
      return if @active_battle[key]
      record = state_ready? ? current_trainer_candidate : nil
      info = battle_info(battle).merge(
        "money_before" => trainer_money,
        "objective" => current_objective_label
      )
      AutoplayBot::State.record_trainer_battle_start(record, info) if state_ready? && AutoplayBot::State.respond_to?(:record_trainer_battle_start)
      @active_battle[key] = {
        "record" => record,
        "money_before" => trainer_money,
        "started_at" => Time.now.to_i
      }
    rescue => e
      AutoplayBot.log("trainer battle start note failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    end

    def note_battle_end(battle)
      return if battle.nil? || wild_battle?(battle)
      key = battle_object_id(battle)
      active = @active_battle && @active_battle.delete(key)
      record = active && active["record"] || (state_ready? ? current_trainer_candidate : nil)
      before = active && active["money_before"]
      after = trainer_money
      info = battle_info(battle).merge(
        "money_before" => before,
        "money_after" => after,
        "money_delta" => before ? after.to_i - before.to_i : nil,
        "result" => decision_label(battle),
        "objective" => current_objective_label
      )
      AutoplayBot::State.record_trainer_battle_end(record, info) if state_ready? && AutoplayBot::State.respond_to?(:record_trainer_battle_end)
    rescue => e
      AutoplayBot.log("trainer battle end note failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    end

    def current_trainer_candidate
      return nil unless state_ready?
      return nil unless defined?(AutoplayBot::WorldScanner) && defined?($game_player) && $game_player
      map = AutoplayBot::WorldScanner.current_map_data
      trainers = map && map["trainers"].is_a?(Array) ? map["trainers"] : []
      record = trainers.min_by do |trainer|
        (trainer["x"].to_i - $game_player.x).abs + (trainer["y"].to_i - $game_player.y).abs
      end
      return nil unless record
      distance = (record["x"].to_i - $game_player.x).abs + (record["y"].to_i - $game_player.y).abs
      return nil if distance > 8
      AutoplayBot::State.note_trainer_candidate(record) if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:note_trainer_candidate)
      record
    rescue
      nil
    end

    def current_active_record(battle = nil)
      if @active_battle
        if battle
          active = @active_battle[battle_object_id(battle)]
          return active["record"] if active && active["record"].is_a?(Hash)
        end
        active = @active_battle.values.reverse.find { |entry| entry && entry["record"].is_a?(Hash) }
        return active["record"] if active
      end
      current_trainer_candidate
    rescue
      nil
    end

    def best_repeatable_for_current_map
      return nil unless state_ready? && AutoplayBot::State.respond_to?(:repeatable_battles_for_map)
      map_id = defined?($game_map) && $game_map ? $game_map.map_id : nil
      entries = AutoplayBot::State.repeatable_battles_for_map(map_id)
      entries.sort_by do |entry|
        next [99, 0] if AutoplayBot::State.respond_to?(:trainer_done_for_now?) &&
                        AutoplayBot::State.trainer_done_for_now?(entry["record"])
        reward = entry["last_reward"].to_i
        status_bonus = entry["status"].to_s == "confirmed_repeatable" ? 0 : 1
        [status_bonus, -reward]
      end.reject do |entry|
        AutoplayBot::State.respond_to?(:trainer_done_for_now?) &&
          AutoplayBot::State.trainer_done_for_now?(entry["record"])
      end.map { |entry| entry["record"] }.compact.first
    rescue
      nil
    end

    def battle_info(battle)
      {
        "map" => (defined?($game_map) && $game_map ? $game_map.map_id : nil),
        "x" => (defined?($game_player) && $game_player ? $game_player.x : nil),
        "y" => (defined?($game_player) && $game_player ? $game_player.y : nil),
        "opponents" => opponent_names(battle)
      }
    rescue
      {}
    end

    def opponent_names(battle)
      opponents = []
      raw = battle.instance_variable_get(:@opponent) if battle.instance_variable_defined?(:@opponent)
      Array(raw).compact.each do |trainer|
        if trainer.respond_to?(:name)
          opponents << trainer.name.to_s
        elsif trainer.respond_to?(:trainer_type)
          opponents << trainer.trainer_type.to_s
        end
      end
      opponents.uniq
    rescue
      []
    end

    def decision_label(battle)
      decision = battle.instance_variable_get(:@decision) if battle.instance_variable_defined?(:@decision)
      case decision.to_i
      when 1 then "win"
      when 2 then "lose"
      when 3 then "caught"
      when 4 then "draw"
      else "unknown"
      end
    rescue
      "unknown"
    end

    def wild_battle?(battle)
      battle.respond_to?(:wildBattle?) && battle.wildBattle?
    rescue
      false
    end

    def trainer_money
      defined?($Trainer) && $Trainer && $Trainer.respond_to?(:money) ? $Trainer.money.to_i : 0
    rescue
      0
    end

    def current_objective_label
      return nil unless state_ready?
      objective = AutoplayBot::State.current_objective if defined?(AutoplayBot::State)
      objective && (objective["label"] || objective["id"])
    rescue
      nil
    end

    def battle_object_id(battle)
      battle.object_id.to_s
    rescue
      "battle"
    end
  end

  module MenuTools
    LEGACY_QOL_BLOCKED_MAPS = [315, 316, 317, 318, 328, 343,
                               776, 777, 778, 779, 780, 781, 782, 783, 784,
                               722, 723, 724, 720,
                               304, 306, 307] unless const_defined?(:LEGACY_QOL_BLOCKED_MAPS)
    LEGACY_KURAY_SHOP_BLOCKED_MAPS = [315, 316, 317, 318, 328, 341] unless const_defined?(:LEGACY_KURAY_SHOP_BLOCKED_MAPS)
    ACTION_PATTERNS = {
      :pc => [/^pc$/i],
      :heal => [/heal.*pok/i],
      :kuray_shop => [/kuray.*shop/i],
      :tutor_net => [/tutor\.?\s*net/i],
      :bag => [/^bag$/i],
      :pokemon => [/^pokemon$/i, /^pok.*mon$/i]
    } unless const_defined?(:ACTION_PATTERNS)

    module_function

    def clear!
      @pending_action = nil
      @pending_reason = nil
      @pending_frame = nil
      @pending_started_at = nil
      @pause_menu_opened = false
      @pending_fallback_index = nil
      @pending_drive_frame = nil
      @pending_drive_attempts = 0
      @close_pause_menu_once = false
    rescue
      nil
    end

    def pending_action
      @pending_action
    rescue
      nil
    end

    def pending_reason
      @pending_reason
    rescue
      nil
    end

    def pending_stale?(frames = 180)
      return false unless @pending_action
      started = @pending_frame.to_i
      return false if started <= 0
      (Graphics.frame_count rescue 0).to_i - started > frames.to_i
    rescue
      false
    end

    def request(action, reason = nil)
      action = action.to_sym
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.respond_to?(:battle_transition_cooldown_active?) &&
         AutoplayBot::Runtime.battle_transition_cooldown_active?(3.0)
        AutoplayBot.status("menu: wait battle settle") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:status)
        return false
      end
      return false unless pause_menu_available_for?(action)
      return false if action_on_cooldown?(action)
      @pending_action = action
      @pending_reason = reason.to_s
      @pending_frame = (Graphics.frame_count rescue 0).to_i
      @pending_started_at = Time.now.to_f
      @pause_menu_opened = false
      @pending_fallback_index = likely_pause_command_index(action)
      @pending_drive_frame = nil
      @pending_drive_attempts = 0
      AutoplayBot.status("menu: #{action_label(action)}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:status)
      true
    rescue => e
      AutoplayBot.log("menu request failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def open_pause_menu(action, reason = nil)
      return false unless request(action, reason)
      set_last_pause_choice(@pending_fallback_index)
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      if defined?(AutoplayBot::InputQueue)
        AutoplayBot::InputQueue.tap(:BACK, 2)
        AutoplayBot::InputQueue.tap_next(:BACK, 2) if AutoplayBot::InputQueue.respond_to?(:tap_next)
      end
      true
    rescue => e
      AutoplayBot.log("open pause menu failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      clear!
      false
    end

    def choose_pause_command(commands)
      if @close_pause_menu_once
        @close_pause_menu_once = false
        return -1
      end
      action = pending_action
      unless action
        if bot_should_close_unplanned_pause_menu?
          AutoplayBot.status("menu: close unplanned") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:status)
          return -1
        end
        return nil
      end
      labels = Array(commands).map { |cmd| clean_label(cmd) }
      patterns = ACTION_PATTERNS[action] || []
      idx = labels.index { |label| patterns.any? { |pattern| label =~ pattern } }
      if idx
        @pause_menu_opened = true
        @pending_fallback_index = idx
        set_last_pause_choice(idx)
        AutoplayBot.status("menu: #{labels[idx]}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:status)
        return idx
      end
      AutoplayBot.log("menu action #{action} missing from pause menu: #{labels.join(', ')}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      note_menu_action_blocked!(action, "missing menu command")
      -1
    rescue => e
      AutoplayBot.log("pause menu choice failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      note_menu_action_blocked!(action || :unknown, "choice error")
      -1
    end

    def bot_should_close_unplanned_pause_menu?
      return false unless defined?(AutoplayBot::Runtime)
      return false unless AutoplayBot::Runtime.respond_to?(:running?) && AutoplayBot::Runtime.running?
      if AutoplayBot::Runtime.respond_to?(:human_override_active?) &&
         AutoplayBot::Runtime.human_override_active?
        return false
      end
      true
    rescue
      false
    end

    def note_menu_action_completed!(action = nil, detail = nil)
      action ||= pending_action
      cooldown_action!(action, completion_cooldown(action))
      AutoplayBot.status("menu done: #{action_label(action)}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:status)
      if detail && defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
        AutoplayBot.log("menu #{action}: #{detail}")
      end
      clear!
      @close_pause_menu_once = true
      true
    rescue
      clear!
      true
    end

    def note_menu_action_blocked!(action = nil, reason = nil)
      action ||= pending_action
      cooldown_action!(action, 900)
      AutoplayBot.status("menu blocked: #{action_label(action)}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:status)
      AutoplayBot.log("menu #{action} blocked: #{reason}") if reason && defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      clear!
      @close_pause_menu_once = true
      false
    rescue
      clear!
      false
    end

    def pending_age
      return 0 unless @pending_frame
      (Graphics.frame_count rescue 0).to_i - @pending_frame.to_i
    rescue
      0
    end

    def pending_age_seconds
      return 0.0 unless @pending_started_at
      Time.now.to_f - @pending_started_at.to_f
    rescue
      0.0
    end

    def drive_open_pause_menu!
      return false unless @pending_action
      frame = (Graphics.frame_count rescue 0).to_i
      @pending_drive_frame ||= frame
      return false if frame - @pending_drive_frame.to_i < 12
      if pending_stale?(180) || pending_age_seconds > 2.0
        note_menu_action_blocked!(@pending_action, "pause menu action timeout")
        return tap_menu_back
      end
      return false if frame - @pending_drive_frame.to_i < 30 && @pending_drive_attempts.to_i > 0
      @pending_drive_frame = frame
      @pending_drive_attempts = @pending_drive_attempts.to_i + 1
      set_last_pause_choice(@pending_fallback_index)
      AutoplayBot.status("menu: confirm #{action_label(@pending_action)}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:status)
      if defined?(AutoplayBot::InputQueue)
        AutoplayBot::InputQueue.tap(:USE, 2)
        AutoplayBot::InputQueue.tap_next(:USE, 2) if AutoplayBot::InputQueue.respond_to?(:tap_next)
      end
      true
    rescue => e
      AutoplayBot.log("pause menu drive failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      note_menu_action_blocked!(@pending_action || :unknown, "drive error")
      tap_menu_back
    end

    def tap_menu_back
      return false unless defined?(AutoplayBot::InputQueue)
      AutoplayBot::InputQueue.clear
      AutoplayBot::InputQueue.tap(:BACK, 2)
      AutoplayBot::InputQueue.tap_next(:BACK, 2) if AutoplayBot::InputQueue.respond_to?(:tap_next)
      true
    rescue
      false
    end

    def close_open_menu!(reason = nil)
      clear!
      AutoplayBot.status("menu: close #{reason}") if reason && defined?(AutoplayBot) && AutoplayBot.respond_to?(:status)
      tap_menu_back
    rescue
      false
    end

    def pause_menu_available_for?(action)
      return false unless defined?($Trainer) && $Trainer
      return false if defined?($game_system) && $game_system && $game_system.respond_to?(:menu_disabled) && $game_system.menu_disabled
      return false if action_on_cooldown?(action)
      case action.to_sym
      when :heal, :pc
        !legacy_qol_locked?
      when :kuray_shop
        !legacy_kuray_shop_locked? && !bug_contest?
      when :tutor_net
        tutor_net_available?
      else
        true
      end
    rescue
      false
    end

    def likely_pause_command_index(action)
      order = []
      if defined?($Trainer) && $Trainer
        begin
          order << :pokedex if $Trainer.has_pokedex && $Trainer.pokedex && $Trainer.pokedex.accessible_dexes.length > 0
        rescue
          nil
        end
        order << :pokemon if ($Trainer.party_count rescue 0).to_i > 0
      end
      order << :bag unless bug_contest?
      if kuray_qol_available?
        order << :pc
        order << :heal
        order << :kuray_shop unless bug_contest?
      end
      order << :tutor_net if tutor_net_available?
      order << :pokegear if defined?($Trainer) && $Trainer && ($Trainer.has_pokegear rescue false)
      order << :trainer
      order << :outfit if defined?($Trainer) && $Trainer && ($Trainer.can_change_outfit rescue false)
      order << :save unless bug_contest?
      order << :multiplayer if defined?(MultiplayerUI)
      order << :options
      order << :mod_manager if defined?(ModManager::Scene_Installed)
      order << :debug if $DEBUG
      order << :title
      idx = order.index(action.to_sym)
      idx && idx >= 0 ? idx : nil
    rescue
      nil
    end

    def set_last_pause_choice(index)
      return false unless index
      return false unless defined?($PokemonTemp) && $PokemonTemp
      $PokemonTemp.menuLastChoice = index.to_i if $PokemonTemp.respond_to?(:menuLastChoice=)
      true
    rescue
      false
    end

    def kuray_qol_available?
      defined?($PokemonSystem) && $PokemonSystem &&
        $PokemonSystem.respond_to?(:kurayqol) && $PokemonSystem.kurayqol.to_i == 1
    rescue
      false
    end

    def tutor_net_available?
      return false if bug_contest?
      return false if legacy_kuray_shop_locked?
      defined?($PokemonSystem) && $PokemonSystem &&
        $PokemonSystem.respond_to?(:tutornet) && $PokemonSystem.tutornet.to_i == 1 &&
        defined?(PokemonTutorNet_Scene) && defined?(PokemonTutorNetScreen)
    rescue
      false
    end

    def rocket_balls_available?
      defined?($PokemonSystem) && $PokemonSystem &&
        $PokemonSystem.respond_to?(:rocketballsteal) && $PokemonSystem.rocketballsteal.to_i > 0
    rescue
      false
    end

    def legacy_qol_locked?
      return false unless defined?($game_map) && $game_map
      LEGACY_QOL_BLOCKED_MAPS.include?($game_map.map_id.to_i) && !File.exist?("DemICE.krs")
    rescue
      false
    end

    def legacy_kuray_shop_locked?
      return false unless defined?($game_map) && $game_map
      LEGACY_KURAY_SHOP_BLOCKED_MAPS.include?($game_map.map_id.to_i) && !File.exist?("DemICE.krs")
    rescue
      false
    end

    def bug_contest?
      return pbInBugContest? if Object.respond_to?(:pbInBugContest?)
      AutoplayBot.helper(:pbInBugContest?) == true
    rescue
      false
    end

    def handle_kuray_shop_for_bot
      return false unless defined?(AutoplayBot::ShopPolicy)
      stock = kuray_shop_stock
      return false if stock.empty?
      AutoplayBot::ShopPolicy.handle_stock(stock, "Kuray Shop")
    rescue => e
      AutoplayBot.log("kuray shop bot handling failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def kuray_shop_stock
      stock = [
        :POKEBALL, :GREATBALL, :ULTRABALL, :PREMIERBALL, :QUICKBALL,
        :DUSKBALL, :TIMERBALL, :FUSIONBALL,
        :POTION, :SUPERPOTION, :HYPERPOTION, :MAXPOTION, :FULLRESTORE,
        :REVIVE, :ANTIDOTE, :PARALYZEHEAL, :AWAKENING, :BURNHEAL,
        :ICEHEAL, :FULLHEAL, :ESCAPEROPE, :REPEL, :SUPERREPEL, :MAXREPEL,
        :DNASPLICERS, :SUPERSPLICERS, :INFINITESPLICERS, :REVERSERS
      ]
      stock << :ROCKETBALL if rocket_balls_available?
      stock.select { |item| item_available?(item) }.uniq
    rescue
      []
    end

    def item_available?(item)
      return false unless defined?(GameData::Item)
      return GameData::Item.exists?(item) if GameData::Item.respond_to?(:exists?)
      !!GameData::Item.get(item)
    rescue
      false
    end

    def note_pc_menu_seen!
      if defined?(AutoplayBot::TeamBuilder) && AutoplayBot::TeamBuilder.respond_to?(:inspect_party_and_storage!)
        AutoplayBot::TeamBuilder.inspect_party_and_storage!("pause menu PC")
      elsif defined?(AutoplayBot::TeamBuilder) && AutoplayBot::TeamBuilder.respond_to?(:record_roster_plan!)
        AutoplayBot::TeamBuilder.record_roster_plan!("pause menu PC")
      end
      note_menu_action_completed!(:pc, "party and PC checked")
    rescue
      note_menu_action_completed!(:pc)
    end

    def note_tutor_net_seen!
      count = tutor_move_count
      detail = count > 0 ? "#{count} tutor moves visible" : "no tutor moves recorded"
      note_menu_action_completed!(:tutor_net, detail)
    rescue
      note_menu_action_completed!(:tutor_net)
    end

    def note_bag_menu_seen!
      snapshot = if defined?(AutoplayBot::ResourcePlanner) && AutoplayBot::ResourcePlanner.respond_to?(:snapshot)
                   AutoplayBot::ResourcePlanner.snapshot
                 else
                   {}
                 end
      if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:record_resource_snapshot)
        AutoplayBot::State.record_resource_snapshot(snapshot)
      end
      balls = snapshot["balls"] || "?"
      heals = snapshot["heals"] || "?"
      money = snapshot["money"] || (defined?(AutoplayBot::ShopPolicy) ? AutoplayBot::ShopPolicy.trainer_money : "?")
      note_menu_action_completed!(:bag, "bag checked: balls #{balls}, heals #{heals}, money #{money}")
    rescue
      note_menu_action_completed!(:bag)
    end

    def complete_opened_scene_action_if_ready!(scene_name = nil)
      action = pending_action
      return false unless action
      scene_name ||= defined?($scene) && $scene ? $scene.class.to_s : ""
      handled = false
      case action.to_sym
      when :bag
        handled = scene_name =~ /Bag/i
        note_bag_menu_seen! if handled
      when :pc
        handled = scene_name =~ /Storage|PC/i
        note_pc_menu_seen! if handled
      when :tutor_net
        handled = scene_name =~ /Tutor/i
        note_tutor_net_seen! if handled
      when :pokemon
        handled = (scene_name =~ /Party/i) ||
                  (scene_name =~ /Pokemon/i && scene_name !~ /PauseMenu/i)
        note_menu_action_completed!(:pokemon, "party menu seen") if handled
      end
      tap_menu_back if handled
      handled ? true : false
    rescue => e
      AutoplayBot.log("menu scene completion failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def tutor_move_count
      return 0 unless defined?($Trainer) && $Trainer && $Trainer.respond_to?(:tutorlist) && $Trainer.tutorlist
      $Trainer.tutorlist.length.to_i
    rescue
      0
    end

    def action_on_cooldown?(action)
      @action_cooldowns ||= {}
      until_frame = @action_cooldowns[action.to_sym].to_i
      (Graphics.frame_count rescue 0).to_i < until_frame
    rescue
      false
    end

    def cooldown_action!(action, frames)
      return unless action
      @action_cooldowns ||= {}
      @action_cooldowns[action.to_sym] = (Graphics.frame_count rescue 0).to_i + frames.to_i
    rescue
      nil
    end

    def completion_cooldown(action)
      case action.to_sym
      when :heal then 600
      when :kuray_shop then 1800
      when :pc then 3600
      when :bag then 1800
      when :tutor_net then 5400
      else 900
      end
    rescue
      900
    end

    def clean_label(label)
      label.to_s.gsub(/\[[^\]]+\]/, "").gsub(/\s+/, " ").strip
    rescue
      label.to_s
    end

    def action_label(action)
      case action.to_sym
      when :pc then "PC"
      when :heal then "Heal Pokemon"
      when :kuray_shop then "Kuray Shop"
      when :tutor_net then "Tutor.net"
      when :bag then "Bag"
      when :pokemon then "Pokemon"
      else action.to_s
      end
    rescue
      "menu"
    end
  end

  module PromptPolicy
    SAFE_NO_PATTERNS = [
      "delete",
      "release",
      "give up",
      "quit",
      "overwrite",
      "forget this move",
      "stop learning",
      "save the game"
    ] unless const_defined?(:SAFE_NO_PATTERNS)

    module_function

    def clean(text)
      text.to_s.gsub(/\\[A-Za-z]+\[[^\]]*\]/, "").gsub(/\s+/, " ").strip
    end

    def choose(message, commands, cmd_if_cancel = 0, default_cmd = 0)
      return default_cmd.to_i unless commands && commands.respond_to?(:map)
      labels = commands.map { |cmd| clean(cmd) }
      return default_cmd.to_i if labels.empty?
      title_choice = choose_title(labels)
      return report_choice(labels, title_choice, "title prompt") unless title_choice.nil?
      yn = choose_yes_no(message, labels)
      return report_choice(labels, yn, "yes/no prompt") unless yn.nil?
      cosmetic_choice = choose_cosmetic(message, labels, cmd_if_cancel)
      return report_choice(labels, cosmetic_choice, "cosmetic prompt") unless cosmetic_choice.nil?
      exclusive_choice = choose_exclusive(message, labels)
      return report_choice(labels, exclusive_choice, "exclusive choice") unless exclusive_choice.nil?
      sprite_choice = choose_sprite(message, labels)
      return report_choice(labels, sprite_choice, "sprite prompt") unless sprite_choice.nil?
      box_choice = choose_storage(labels)
      return report_choice(labels, box_choice, "storage prompt") unless box_choice.nil?
      shop_choice = choose_shop(labels)
      return report_choice(labels, shop_choice, "shop prompt") unless shop_choice.nil?
      move_choice = choose_move(labels)
      return report_choice(labels, move_choice, "move prompt") unless move_choice.nil?
      default = default_cmd.to_i
      default = 0 if default < 0 || default >= labels.length
      report_choice(labels, default, "default prompt")
    rescue => e
      AutoplayBot.log("prompt choice failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      cmd_if_cancel.to_i > 0 ? cmd_if_cancel.to_i - 1 : default_cmd.to_i
    end

    def report_choice(labels, choice, context)
      idx = choice.to_i
      label = labels[idx] || "option #{idx}"
      AutoplayBot.status("#{context}: #{label}") if AutoplayBot.respond_to?(:status)
      AutoplayBot.log("#{context}: #{label}") if context.to_s.include?("exclusive") && AutoplayBot.respond_to?(:log)
      idx
    rescue
      choice.to_i
    end

    def choose_title(labels)
      continue = labels.index { |label| label =~ /continue/i || label =~ /\AAuto|Manual|Legacy|Slot|\d/ }
      return continue if continue
      new_game = labels.index { |label| label =~ /new game/i }
      return new_game if new_game
      nil
    end

    def choose_yes_no(message, labels)
      yes = labels.index { |label| label =~ /\Ayes\z/i }
      no = labels.index { |label| label =~ /\Ano\z/i }
      return nil if yes.nil? || no.nil?
      text = clean(message).downcase
      return choose_nickname_yes_no(text, yes, no) if text.include?("nickname")
      return yes if text.include?("rest your pokemon") || text.include?("heal")
      return yes if text.include?("continue?")
      return yes if text.include?("delete a move") || text.include?("forget a move") || text.include?("make room")
      return yes if rocket_disguise_needed? && text =~ /rocket|outfit|uniform|clothes|clothing|disguise|change your look/
      return no if cosmetic_vendor_text?(text)
      return no if text.include?("give up on learning") || text.include?("stop learning")
      return no if SAFE_NO_PATTERNS.any? { |pattern| text.include?(pattern) }
      return no if text.include?("update now")
      yes
    end

    def cosmetic_vendor_text?(text)
      text.to_s =~ /hair|hairstyle|haircut|clothes|clothing|outfit|hat|cap|uniform|wardrobe|change your look|makeover|try.*on/
    rescue
      false
    end

    def choose_nickname_yes_no(text, yes, no)
      case AutoplayBot::Config.nickname_policy
      when "always"
        yes
      when "never"
        no
      else
        return yes if text.include?("hatched") || text.include?("starter")
        should_nickname_current_context? ? yes : no
      end
    rescue
      no
    end

    def manual_exclusive_choice?(message, commands)
      return false if AutoplayBot::Config.auto_choose_exclusive?
      labels = commands && commands.respond_to?(:map) ? commands.map { |cmd| clean(cmd) } : []
      exclusive_choice_prompt?(message, labels)
    rescue
      false
    end

    def choose_exclusive(message, labels)
      return nil unless AutoplayBot::Config.auto_choose_exclusive?
      return nil unless exclusive_choice_prompt?(message, labels)
      candidates = exclusive_choice_indexes(labels)
      return nil if candidates.empty?
      candidates[rand(candidates.length)]
    rescue
      nil
    end

    def exclusive_choice_prompt?(message, labels)
      return false unless labels && labels.length >= 2
      return false if yes_no_labels?(labels)
      text = clean(message).downcase
      return true if labels.any? { |label| starter_label?(label) }
      return true if text =~ /which one|choose (?:one|your|a)|pick (?:one|your|a)|starter/
      false
    rescue
      false
    end

    def exclusive_choice_indexes(labels)
      labels.each_index.reject { |idx| cancel_label?(labels[idx]) }
    rescue
      []
    end

    def yes_no_labels?(labels)
      labels.length == 2 &&
        labels.any? { |label| label =~ /\Ayes\z/i } &&
        labels.any? { |label| label =~ /\Ano\z/i }
    rescue
      false
    end

    def cancel_label?(label)
      label.to_s =~ /\Acancel\z|\Ano\z|\Aback\z|\Aquit\z/i
    rescue
      false
    end

    def starter_label?(label)
      label.to_s =~ /bulbasaur|charmander|squirtle|chikorita|cyndaquil|totodile|treecko|torchic|mudkip|turtwig|chimchar|piplup|snivy|tepig|oshawott|chespin|fennekin|froakie|rowlet|litten|popplio|grookey|scorbunny|sobble|sprigatito|fuecoco|quaxly/i
    rescue
      false
    end

    def choose_sprite(message, labels)
      return nil unless sprite_choice_prompt?(message, labels)
      use = labels.index { |label| label =~ /use this sprite|choose this sprite|select this sprite|set.*sprite/i }
      return use unless use.nil?
      preferred = labels.index do |label|
        label =~ /custom|artist|main|default|generated|autogen|base/i &&
          !cancel_label?(label) &&
          !destructive_sprite_label?(label)
      end
      return preferred unless preferred.nil?
      safe = labels.each_index.reject do |idx|
        cancel_label?(labels[idx]) || destructive_sprite_label?(labels[idx])
      end
      safe.first
    rescue
      nil
    end

    def sprite_choice_prompt?(message, labels)
      return false unless labels && labels.length > 0
      text = clean(message).downcase
      joined = labels.join(" ").downcase
      return true if text =~ /sprite/ && text =~ /use|choose|select|display|current|instead|variant|alt/
      return true if joined =~ /use this sprite|choose.*sprite|select.*sprite|custom sprite|autogen|generated sprite/
      false
    rescue
      false
    end

    def destructive_sprite_label?(label)
      label.to_s =~ /delete|remove|folder|open/i
    rescue
      true
    end

    def choose_storage(labels)
      team_choice = AutoplayBot::TeamBuilder.pending_caught_storage_choice(labels) if defined?(AutoplayBot::TeamBuilder)
      return team_choice unless team_choice.nil?
      store = labels.index { |label| label =~ /box|storage|send/i }
      add = labels.index { |label| label =~ /party|team/i }
      return nil unless store || add
      return add if party_needs_members? && add
      store || add
    end

    def party_needs_members?
      return false unless defined?($Trainer) && $Trainer && $Trainer.respond_to?(:party)
      $Trainer.party.compact.length < 3
    rescue
      false
    end

    def choose_shop(labels)
      return nil unless labels.any? { |label| label =~ /buy/i } && labels.any? { |label| label =~ /sell|quit|cancel/i }
      labels.index { |label| label =~ /quit|cancel/i }
    end

    def choose_cosmetic(message, labels, cmd_if_cancel = 0)
      return nil unless cosmetic_prompt?(message, labels)
      if rocket_disguise_needed?
        rocket = labels.index { |label| rocket_outfit_label?(label) }
        return rocket unless rocket.nil?
      end
      cancel = labels.index { |label| cosmetic_cancel_label?(label) }
      return cancel unless cancel.nil?
      cancel_by_button = cmd_if_cancel.to_i - 1
      return cancel_by_button if cancel_by_button >= 0 && cancel_by_button < labels.length
      labels.length - 1 if labels.length > 0
    rescue
      nil
    end

    def cosmetic_prompt?(message, labels)
      return false unless labels && labels.length >= 2
      joined = labels.join(" ").downcase
      text = clean(message).downcase
      return false if joined =~ /buy|sell|bag|pokemon|save|fight|run|storage|box/
      return true if text =~ /hair|hairstyle|haircut|clothes|clothing|outfit|hat|cap|boater|beanie|uniform|wardrobe|change your look/
      return true if joined =~ /remove hat|hairstyle|haircut|hair color|hat|cap|boater hat|nest|outfit|uniform|clothes|shirt|pants|dress/
      false
    rescue
      false
    end

    def cosmetic_cancel_label?(label)
      label.to_s =~ /\Acancel\z|\Aback\z|\Aquit\z|\Aclose\z|\Aexit\z/i
    rescue
      false
    end

    def rocket_outfit_label?(label)
      label.to_s =~ /team rocket|rocket uniform|rocket outfit|rocket clothes|rocket/i
    rescue
      false
    end

    def rocket_disguise_needed?
      context = []
      objective = AutoplayBot::State.current_objective if defined?(AutoplayBot::State)
      if objective.is_a?(Hash)
        context << objective["id"]
        context << objective["type"]
        context << objective["label"]
        context << objective["target"]
        context << objective["required_outfit"]
      end
      active_goal = AutoplayBot::State.active_goal if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:active_goal)
      if active_goal.is_a?(Hash)
        context << active_goal["kind"]
        context << active_goal["label"]
        context << active_goal["reason"]
      end
      context << (AutoplayBot.status_message if AutoplayBot.respond_to?(:status_message))
      text = context.compact.join(" ").downcase
      return true if text =~ /rocket/ && text =~ /outfit|uniform|clothes|disguise|wear|infiltrat|hideout|silph|quest|story/
      return true if guide_rocket_disguise_context?(text)
      false
    rescue
      false
    end

    def guide_rocket_disguise_context?(text)
      guide = AutoplayBot::GuidePack.data if defined?(AutoplayBot::GuidePack)
      disguises = guide && guide["quest_disguises"]
      return false unless disguises.respond_to?(:each)
      disguises.any? do |entry|
        next false unless entry.is_a?(Hash)
        outfit = [entry["required_outfit"], entry["id"], entry["name"]].compact.join(" ").downcase
        next false unless outfit.include?("rocket")
        keywords = entry["objective_keywords"] || entry["keywords"] || []
        Array(keywords).any? { |keyword| !keyword.to_s.empty? && text.include?(keyword.to_s.downcase) }
      end
    rescue
      false
    end

    def choose_move(labels)
      return nil unless labels.length >= 4
      return nil unless labels.any? { |label| label =~ /cancel|give up/i }
      labels.length - 2
    end

    def confirm(message, serious = false)
      labels = serious ? ["No", "Yes"] : ["Yes", "No"]
      idx = choose(message, labels, serious ? 1 : 2, serious ? 0 : 0)
      serious ? idx == 1 : idx == 0
    end

    def number(_message, params)
      min = params.respond_to?(:minNumber) ? params.minNumber.to_i : 1
      max = params.respond_to?(:maxNumber) ? params.maxNumber.to_i : min
      [[min, 1].max, max].min
    rescue
      1
    end

    def text_for(message, minlength, maxlength, _initial = "", _mode = 0, pokemon = nil)
      base = if pokemon
               AutoplayBot::DexTracker.species_name(pokemon.species)
             elsif clean(message).downcase.include?("name")
               "Dex"
             else
               "Auto"
             end
      name = nickname(base, maxlength.to_i)
      name = name.ljust(minlength.to_i, "A") if minlength.to_i > 0 && name.length < minlength.to_i
      name
    end

    def nickname(base, maxlength = 12)
      cleaned = base.to_s.gsub(/[^A-Za-z0-9]/, "")
      cleaned = "Dex" if cleaned.empty?
      suffixes = ["AI", "Bot", "Run", "Dex", "Ace"]
      max = maxlength.to_i > 0 ? maxlength.to_i : 12
      suffix = suffixes[(Graphics.frame_count rescue Time.now.to_i) % suffixes.length]
      raw = "#{cleaned[0, [max - suffix.length, 3].max]}#{suffix}"
      raw[0, max]
    end

    def apply_capture_nickname(pokemon)
      return false unless pokemon
      if should_nickname_pokemon?(pokemon)
        max = defined?(Pokemon::MAX_NAME_SIZE) ? Pokemon::MAX_NAME_SIZE : 16
        pokemon.name = text_for("#{pokemon_species_name(pokemon)}'s nickname?", 0, max, "", 0, pokemon)
        AutoplayBot.status("nickname: #{pokemon.name}") if AutoplayBot.respond_to?(:status)
        AutoplayBot.log("nicknamed #{pokemon_species_name(pokemon)} as #{pokemon.name}") if AutoplayBot.respond_to?(:log)
      else
        AutoplayBot.status("nickname: skipped") if AutoplayBot.respond_to?(:status)
      end
      true
    rescue => e
      AutoplayBot.log("nickname policy failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def should_nickname_pokemon?(pokemon)
      case AutoplayBot::Config.nickname_policy
      when "always"
        return true
      when "never"
        return false
      end
      return true if shiny_pokemon?(pokemon)
      return true if fusion_pokemon?(pokemon)
      return true if should_nickname_current_context?
      return true if early_party_member?
      nickname_flavor_pick?(pokemon)
    rescue
      false
    end

    def should_nickname_current_context?
      objective = AutoplayBot::State.current_objective if defined?(AutoplayBot::State)
      text = [
        objective && objective["id"],
        objective && objective["type"],
        objective && objective["label"]
      ].compact.join(" ").downcase
      text =~ /starter|gift|team|fusion|rival|brock|gym|ace/
    rescue
      false
    end

    def early_party_member?
      return false unless defined?($Trainer) && $Trainer && $Trainer.respond_to?(:party)
      $Trainer.party.compact.length < 3
    rescue
      false
    end

    def nickname_flavor_pick?(pokemon)
      key = pokemon_species_name(pokemon)
      seed = key.to_s.each_byte.inject(0) { |sum, byte| sum + byte }
      seed % 12 == 0
    rescue
      false
    end

    def shiny_pokemon?(pokemon)
      pokemon.respond_to?(:shiny?) && pokemon.shiny?
    rescue
      false
    end

    def fusion_pokemon?(pokemon)
      pokemon.respond_to?(:isFusion?) && pokemon.isFusion?
    rescue
      false
    end

    def pokemon_species_name(pokemon)
      if pokemon.respond_to?(:speciesName)
        pokemon.speciesName.to_s
      elsif pokemon.respond_to?(:species)
        AutoplayBot::DexTracker.species_name(pokemon.species)
      else
        "Dex"
      end
    rescue
      "Dex"
    end
  end

  module Director
    STARTER_ROOM_MAP_ID = 71 unless const_defined?(:STARTER_ROOM_MAP_ID)
    PLAYER_HOUSE_MAP_ID = 43 unless const_defined?(:PLAYER_HOUSE_MAP_ID)
    PALLET_RESPAWN_HOUSE_MAP_ID = 3 unless const_defined?(:PALLET_RESPAWN_HOUSE_MAP_ID)
    PALLET_TOWN_MAP_ID = 42 unless const_defined?(:PALLET_TOWN_MAP_ID)
    ROUTE_1_MAP_ID = 78 unless const_defined?(:ROUTE_1_MAP_ID)
    VIRIDIAN_CITY_MAP_ID = 79 unless const_defined?(:VIRIDIAN_CITY_MAP_ID)
    VIRIDIAN_MART_MAP_ID = 81 unless const_defined?(:VIRIDIAN_MART_MAP_ID)
    OAK_LAB_MAP_IDS = [77, 659] unless const_defined?(:OAK_LAB_MAP_IDS)
    PALLET_RIVAL_EVENT = {
      "key" => "42:3:blue",
      "event_id" => 3,
      "event_name" => "Rival Blue",
      "x" => 16,
      "y" => 10,
      "action_x" => 15,
      "action_y" => 10,
      "face_dir" => 6,
      "trigger" => 0
    } unless const_defined?(:PALLET_RIVAL_EVENT)
    OPTIONAL_TARGET_MAX_ATTEMPTS = 5 unless const_defined?(:OPTIONAL_TARGET_MAX_ATTEMPTS)
    STORY_STUCK_FRAME_LIMIT = 90 unless const_defined?(:STORY_STUCK_FRAME_LIMIT)
    ROUTE_STUCK_FRAME_LIMIT = 120 unless const_defined?(:ROUTE_STUCK_FRAME_LIMIT)
    OPTIONAL_STUCK_FRAME_LIMIT = 150 unless const_defined?(:OPTIONAL_STUCK_FRAME_LIMIT)
    VERTICAL_PROBE_FRAMES = 18 unless const_defined?(:VERTICAL_PROBE_FRAMES)
    AXIS_LOOP_WINDOW = 10 unless const_defined?(:AXIS_LOOP_WINDOW)
    AXIS_LOOP_MAX_SPAN = 8 unless const_defined?(:AXIS_LOOP_MAX_SPAN)
    PALLET_OAK_TRIGGER = { "x" => 18, "y" => 3 } unless const_defined?(:PALLET_OAK_TRIGGER)
    PALLET_ROUTE_1_EXIT = { "x" => 20, "y" => 0 } unless const_defined?(:PALLET_ROUTE_1_EXIT)
    ROUTE_1_NORTH_EXIT = { "x" => 14, "y" => 0 } unless const_defined?(:ROUTE_1_NORTH_EXIT)
    ROUTE_1_SOUTH_EXIT = { "x" => 20, "y" => 49 } unless const_defined?(:ROUTE_1_SOUTH_EXIT)
    VIRIDIAN_ROUTE_1_EXIT = { "x" => 21, "y" => 49 } unless const_defined?(:VIRIDIAN_ROUTE_1_EXIT)
    VIRIDIAN_ROUTE_2_EXIT = { "x" => 27, "y" => 0 } unless const_defined?(:VIRIDIAN_ROUTE_2_EXIT)
    ROUTE_2_SOUTH_MAP_ID = 86 unless const_defined?(:ROUTE_2_SOUTH_MAP_ID)
    VIRIDIAN_FOREST_SOUTH_GATE_MAP_ID = 88 unless const_defined?(:VIRIDIAN_FOREST_SOUTH_GATE_MAP_ID)
    VIRIDIAN_FOREST_MAP_ID = 491 unless const_defined?(:VIRIDIAN_FOREST_MAP_ID)
    VIRIDIAN_FOREST_NORTH_GATE_MAP_ID = 89 unless const_defined?(:VIRIDIAN_FOREST_NORTH_GATE_MAP_ID)
    ROUTE_2_NORTH_MAP_ID = 90 unless const_defined?(:ROUTE_2_NORTH_MAP_ID)
    PEWTER_CITY_MAP_ID = 380 unless const_defined?(:PEWTER_CITY_MAP_ID)
    PEWTER_GYM_MAP_ID = 386 unless const_defined?(:PEWTER_GYM_MAP_ID)
    PLAYER_HOUSE_MAP_IDS = [PLAYER_HOUSE_MAP_ID, PALLET_RESPAWN_HOUSE_MAP_ID] unless const_defined?(:PLAYER_HOUSE_MAP_IDS)
    PLAYER_ROOM_MAP_IDS = [STARTER_ROOM_MAP_ID, 67, 68, 69, 70, 71, 73] unless const_defined?(:PLAYER_ROOM_MAP_IDS)
    STORY_NAV_MAP_IDS = [
      STARTER_ROOM_MAP_ID,
      PLAYER_HOUSE_MAP_ID,
      PALLET_TOWN_MAP_ID,
      ROUTE_1_MAP_ID,
      VIRIDIAN_CITY_MAP_ID,
      VIRIDIAN_MART_MAP_ID,
      ROUTE_2_SOUTH_MAP_ID,
      VIRIDIAN_FOREST_SOUTH_GATE_MAP_ID,
      VIRIDIAN_FOREST_MAP_ID,
      VIRIDIAN_FOREST_NORTH_GATE_MAP_ID,
      ROUTE_2_NORTH_MAP_ID,
      PEWTER_CITY_MAP_ID,
      PEWTER_GYM_MAP_ID
    ] unless const_defined?(:STORY_NAV_MAP_IDS)
    TOWN_CLEANUP_MAP_IDS = [
      PALLET_TOWN_MAP_ID,
      VIRIDIAN_CITY_MAP_ID,
      PEWTER_CITY_MAP_ID
    ] unless const_defined?(:TOWN_CLEANUP_MAP_IDS)
    BUILDING_CLEANUP_MAP_IDS = ([VIRIDIAN_MART_MAP_ID] + OAK_LAB_MAP_IDS).uniq unless const_defined?(:BUILDING_CLEANUP_MAP_IDS)
    ROUTE_2_FOREST_GATE_TRANSFER = {
      "key" => "86:2:88:9:10",
      "event_name" => "Viridian Forest Gate",
      "x" => 16,
      "y" => 13,
      "trigger" => 1,
      "destination_map_id" => VIRIDIAN_FOREST_SOUTH_GATE_MAP_ID
    } unless const_defined?(:ROUTE_2_FOREST_GATE_TRANSFER)
    FOREST_SOUTH_GATE_NORTH_TRANSFER = {
      "key" => "88:2:491:22:40",
      "event_name" => "Viridian Forest",
      "x" => 9,
      "y" => 1,
      "trigger" => 1,
      "destination_map_id" => VIRIDIAN_FOREST_MAP_ID
    } unless const_defined?(:FOREST_SOUTH_GATE_NORTH_TRANSFER)
    FOREST_NORTH_GATE_TRANSFER = {
      "key" => "491:6:89:9:10",
      "event_name" => "North Forest Gate",
      "x" => 13,
      "y" => 6,
      "trigger" => 1,
      "destination_map_id" => VIRIDIAN_FOREST_NORTH_GATE_MAP_ID
    } unless const_defined?(:FOREST_NORTH_GATE_TRANSFER)
    FOREST_NORTH_GATE_EXIT = {
      "key" => "89:2:90:11:19",
      "event_name" => "Route 2 North",
      "x" => 9,
      "y" => 2,
      "trigger" => 1,
      "destination_map_id" => ROUTE_2_NORTH_MAP_ID
    } unless const_defined?(:FOREST_NORTH_GATE_EXIT)
    ROUTE_2_PEWTER_EXIT = { "x" => 11, "y" => 0 } unless const_defined?(:ROUTE_2_PEWTER_EXIT)
    PEWTER_GYM_TRANSFER = {
      "key" => "380:2:386:9:23",
      "event_name" => "Pewter Gym",
      "x" => 11,
      "y" => 11,
      "trigger" => 1,
      "destination_map_id" => PEWTER_GYM_MAP_ID
    } unless const_defined?(:PEWTER_GYM_TRANSFER)
    BROCK_EVENT = {
      "key" => "386:3:brock",
      "event_id" => 3,
      "event_name" => "Brock",
      "x" => 9,
      "y" => 6,
      "trigger" => 0,
      "action_x" => 9,
      "action_y" => 7,
      "face_dir" => 8
    } unless const_defined?(:BROCK_EVENT)
    VIRIDIAN_MART_TRANSFER = {
      "key" => "79:4:81:6:11",
      "event_name" => "Viridian Mart",
      "x" => 25,
      "y" => 28,
      "trigger" => 1,
      "destination_map_id" => VIRIDIAN_MART_MAP_ID
    } unless const_defined?(:VIRIDIAN_MART_TRANSFER)
    VIRIDIAN_MART_CLERK = {
      "key" => "81:2:oak_parcel",
      "event_name" => "Mart Clerk",
      "x" => 6,
      "y" => 6,
      "trigger" => 0
    } unless const_defined?(:VIRIDIAN_MART_CLERK)
    VIRIDIAN_MART_EXIT = {
      "key" => "81:exit:79",
      "event_name" => "Mart Exit",
      "x" => 6,
      "y" => 13,
      "trigger" => 1,
      "destination_map_id" => VIRIDIAN_CITY_MAP_ID
    } unless const_defined?(:VIRIDIAN_MART_EXIT)
    PALLET_LAB_TRANSFER = {
      "key" => "42:20:77:9:24",
      "event_name" => "Oak's Lab",
      "x" => 31,
      "y" => 17,
      "trigger" => 1
    } unless const_defined?(:PALLET_LAB_TRANSFER)
    OAK_EVENT = {
      "key" => "oak_lab:oak",
      "event_name" => "Professor Oak",
      "x" => 12,
      "y" => 13,
      "trigger" => 0
    } unless const_defined?(:OAK_EVENT)
    LAB_STARTER_BALL = {
      "key" => "oak_lab:starter_ball",
      "event_name" => "Starter Ball",
      "x" => 14,
      "y" => 14,
      "action_x" => 14,
      "action_y" => 16,
      "face_dir" => 8,
      "trigger" => 0
    } unless const_defined?(:LAB_STARTER_BALL)
    LAB_STARTER_BALLS = [
      { "key" => "oak_lab:starter_ball_center", "event_id" => 55, "event_name" => "Starter Ball", "x" => 14, "y" => 14, "action_x" => 14, "action_y" => 16, "face_dir" => 8, "trigger" => 0 },
      { "key" => "oak_lab:starter_ball_left", "event_id" => 54, "event_name" => "Starter Ball", "x" => 13, "y" => 14, "action_x" => 13, "action_y" => 16, "face_dir" => 8, "trigger" => 0 },
      { "key" => "oak_lab:starter_ball_right", "event_id" => 56, "event_name" => "Starter Ball", "x" => 15, "y" => 14, "action_x" => 15, "action_y" => 16, "face_dir" => 8, "trigger" => 0 }
    ] unless const_defined?(:LAB_STARTER_BALLS)
    LAB_RIVAL_BATTLE = { "x" => 12, "y" => 14 } unless const_defined?(:LAB_RIVAL_BATTLE)
    LAB_EXIT_TRANSFER = {
      "key" => "oak_lab:exit",
      "event_name" => "Lab Exit",
      "x" => 10,
      "y" => 25,
      "trigger" => 1,
      "destination_map_id" => PALLET_TOWN_MAP_ID
    } unless const_defined?(:LAB_EXIT_TRANSFER)
    BEDROOM_PC_POTION_KEY = "71:13:pc_potion" unless const_defined?(:BEDROOM_PC_POTION_KEY)
    BEDROOM_PC_EVENT = {
      "key" => BEDROOM_PC_POTION_KEY,
      "map_id" => STARTER_ROOM_MAP_ID,
      "event_id" => 13,
      "event_name" => "Bedroom PC",
      "x" => 3,
      "y" => 5,
      "trigger" => 0
    } unless const_defined?(:BEDROOM_PC_EVENT)
    STARTER_CLOTHES_EVENT = {
      "key" => "starter_house:clothes",
      "map_id" => PLAYER_HOUSE_MAP_ID,
      "event_id" => 4,
      "event_name" => "Starter Clothes",
      "x" => 7,
      "y" => 6
    } unless const_defined?(:STARTER_CLOTHES_EVENT)
    TRAINING_MAP_IDS = [
      ROUTE_1_MAP_ID,
      ROUTE_2_SOUTH_MAP_ID,
      VIRIDIAN_FOREST_MAP_ID,
      ROUTE_2_NORTH_MAP_ID
    ] unless const_defined?(:TRAINING_MAP_IDS)
    DEFAULT_TRAINING_TARGET_LEVEL = 12 unless const_defined?(:DEFAULT_TRAINING_TARGET_LEVEL)

    module_function

    def state_memory_ready?
      defined?(AutoplayBot::State) &&
        (!AutoplayBot::State.respond_to?(:loaded?) || AutoplayBot::State.loaded?)
    rescue
      false
    end

    def reset_runtime!
      @started = false
      @active_transfer = nil
      @active_event_target = nil
      @last_brock_interaction_frame = nil
      @last_pos = nil
      @stuck_frames = 0
      @trying_to_move = false
      @blocked_reason = nil
      @blocked_frames = 0
      @message_frames = 0
      @was_message_showing = false
      @dialog_settle_until_frame = nil
      @last_message_advance_frame = nil
      @map_settle_until_frame = nil
      @map_settle_started_frame = nil
      @map_settle_started_at = nil
      @map_settle_reason = nil
      @pending_activation = nil
      @last_fast_travel_frame = nil
      @target_cooldowns = {}
      @path_cache = {}
      @activation_cooldowns = {}
      @last_frontier_defer_frame = nil
      @forest_forage_cache = nil
      @active_forest_forage = nil
      @pending_forest_forage_activation = nil
      @forest_forage_attempt = nil
      @last_forest_forage_use_frame = nil
      @active_forest_npc = nil
      @local_discovery_cache = nil
      @last_farm_cycle_frame = nil
      @startup_settle_until_frame = nil
      @last_no_path_dir = nil
      @repeat_item_done_this_visit = {}
      @soft_recovery = nil
      @blackout_recovery = nil
      @position_history = []
      @last_loop_frame = nil
      @loop_recovery_until_frame = nil
      @loop_recovery_status = nil
      @loop_recovery_probe = nil
      @healing_goal = nil
      @last_map_knowledge_frame = nil
      @active_decision_goal = nil
      @decision_choice_cache = nil
      @active_route_plan = nil
      @active_route_target = nil
      @last_route_dir = nil
      @last_decision_log_frame = nil
      @last_transfer_transition = nil
      @last_menu_utility_frame = nil
      @battle_context_active = false
      @route_recalc_explore_until_frame = nil
      @route_recalc_reason = nil
      @route_recalc_origin = nil
      @observed_tile_frames = nil
      @last_observed_tile_pos = nil
      @last_observed_tile_frame = nil
      AutoplayBot::MenuTools.clear! if defined?(AutoplayBot::MenuTools) && AutoplayBot::MenuTools.respond_to?(:clear!)
    rescue
      nil
    end

    def note_blackout_start!(gameover = false)
      objective = AutoplayBot::State.current_objective if defined?(AutoplayBot::State)
      @blackout_recovery = {
        "phase" => "starting",
        "gameover" => gameover == true,
        "from_map" => current_map_id,
        "from_x" => (defined?($game_player) && $game_player ? $game_player.x : nil),
        "from_y" => (defined?($game_player) && $game_player ? $game_player.y : nil),
        "objective" => objective
      }
      @active_transfer = nil
      @active_event_target = nil
      @trying_to_move = false
      @stuck_frames = 0
      @blocked_frames = 0
      @pending_activation = nil
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      AutoplayBot.status("blackout: recovering") if defined?(AutoplayBot)
      AutoplayBot.log("blackout recovery started from #{position_label}") if AutoplayBot.respond_to?(:log)
    rescue => e
      AutoplayBot.log("blackout start note failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    end

    def note_blackout_complete!(gameover = false)
      note_blackout_start!(gameover) unless @blackout_recovery
      @blackout_recovery["phase"] = "returning"
      @blackout_recovery["return_map"] = current_map_id
      @blackout_recovery["return_x"] = (defined?($game_player) && $game_player ? $game_player.x : nil)
      @blackout_recovery["return_y"] = (defined?($game_player) && $game_player ? $game_player.y : nil)
      @blackout_recovery["gameover"] = gameover == true
      maybe_plan_training_after_blackout!
      @active_transfer = nil
      @active_event_target = nil
      @trying_to_move = false
      @stuck_frames = 0
      @blocked_frames = 0
      start_map_settle!(18, "blackout return")
      AutoplayBot::State.record_blackout(@blackout_recovery) if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:record_blackout)
      AutoplayBot::State.current_objective ||= @blackout_recovery["objective"] if defined?(AutoplayBot::State)
      AutoplayBot::State.save!(true) if defined?(AutoplayBot::State)
      AutoplayBot.status("blackout: rerouting") if defined?(AutoplayBot)
      AutoplayBot.log("blackout recovery return at #{position_label}") if AutoplayBot.respond_to?(:log)
    rescue => e
      AutoplayBot.log("blackout complete note failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    end

    def recovering_from_blackout?
      @blackout_recovery && @blackout_recovery["phase"].to_s != "done"
    rescue
      false
    end

    def tick
      @started ||= false
      setup_once unless @started
      remember_position
      handle_map_change
      if message_showing?
        @was_message_showing = true
        log_blocked("message window showing")
        @trying_to_move = false
        @message_frames = @message_frames.to_i + 1
        if @message_frames > 900
          AutoplayBot::Runtime.manual_needed("dialog did not advance for 900 frames at #{position_label}") if defined?(AutoplayBot::Runtime)
          return
        end
        advance_message_window
        return
      end
      @message_frames = 0
      return if settle_after_message_window
      unless on_map?
        log_blocked("not on map")
        return title_tick
      end
      return if settling_after_map_change?
      return unless can_act_on_map?
      return if settling_after_startup?
      return if loop_recovery_tick
      record_navigation_state
      unless runtime_performance_coast? || runtime_startup_light?
        scan_world_slowly
        update_map_knowledge_tick
        AutoplayBot::ResourcePlanner.tick if defined?(AutoplayBot::ResourcePlanner)
        AutoplayBot::TeamBuilder.tick if defined?(AutoplayBot::TeamBuilder)
        AutoplayBot::MissionControl.tick if defined?(AutoplayBot::MissionControl)
        prefer_fast_travel!
      end
      return if forest_safe_mode_tick
      return if blackout_recovery_tick
      return if soft_recovery_tick
      return if pause_menu_utility_tick
      return if heal_route_tick
      return if training_tick
      return if starter_house_tick
      return if local_discovery_tick
      return if decision_scheduler_tick
      return if early_story_tick
      objective = AutoplayBot::State.current_objective || next_objective
      AutoplayBot::State.current_objective = objective if objective
      return unless frontier_allowed_now?
      explore_current_map
    rescue => e
      AutoplayBot::Runtime.manual_needed("director failure: #{e.class}: #{e.message}") if defined?(AutoplayBot::Runtime)
    end

    def coast_tick
      @started ||= false
      setup_once unless @started
      handle_map_change
      return if movement_watchdog_tick
      frame = (Graphics.frame_count rescue 0).to_i
      @last_coast_position_frame = -9999 if @last_coast_position_frame.nil?
      if frame - @last_coast_position_frame.to_i >= 12
        @last_coast_position_frame = frame
        remember_position
      end
    rescue => e
      AutoplayBot.log("director coast failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    end

    def runtime_performance_coast?
      defined?(AutoplayBot::Runtime) &&
        AutoplayBot::Runtime.respond_to?(:performance_coast?) &&
        AutoplayBot::Runtime.performance_coast?
    rescue
      false
    end

    def runtime_startup_light?
      defined?(AutoplayBot::Runtime) &&
        AutoplayBot::Runtime.respond_to?(:startup_light?) &&
        AutoplayBot::Runtime.startup_light?
    rescue
      false
    end

    def setup_once
      @started = true
      @last_map_id = current_map_id
      @active_transfer = nil
      @active_event_target = nil
      @last_brock_interaction_frame = nil
      @last_pos = nil
      @stuck_frames = 0
      @was_message_showing = false
      @dialog_settle_until_frame = nil
      @last_message_advance_frame = nil
      @map_settle_until_frame = nil
      @map_settle_started_frame = nil
      @map_settle_started_at = nil
      @map_settle_reason = nil
      @blackout_recovery = nil
      @last_fast_travel_frame = nil
      @target_cooldowns = {}
      @path_cache = {}
      @activation_cooldowns = {}
      @last_frontier_defer_frame = nil
      @forest_forage_cache = nil
      @active_forest_forage = nil
      @pending_forest_forage_activation = nil
      @forest_forage_attempt = nil
      @last_forest_forage_use_frame = nil
      @active_forest_npc = nil
      @local_discovery_cache = nil
      @last_farm_cycle_frame = nil
      @startup_settle_until_frame = (Graphics.frame_count rescue 0).to_i + (current_map_id.to_i == VIRIDIAN_FOREST_MAP_ID ? 90 : 24)
      @last_no_path_dir = nil
      @position_history = []
      @last_loop_frame = nil
      @loop_recovery_until_frame = nil
      @loop_recovery_status = nil
      @loop_recovery_probe = nil
      @healing_goal = nil
      @last_map_knowledge_frame = nil
      @active_decision_goal = nil
      @decision_choice_cache = nil
      @active_route_plan = nil
      @active_route_target = nil
      @last_route_dir = nil
      @last_decision_log_frame = nil
      @last_transfer_transition = nil
      @soft_recovery = nil
      @last_menu_utility_frame = nil
      @battle_context_active = false
      @blocked_step_memory = {}
      @blocked_step_version = 0
      @route_recalc_explore_until_frame = nil
      @route_recalc_reason = nil
      @route_recalc_origin = nil
      @observed_tile_frames = nil
      @last_observed_tile_pos = nil
      @last_observed_tile_frame = nil
      AutoplayBot::MenuTools.clear! if defined?(AutoplayBot::MenuTools) && AutoplayBot::MenuTools.respond_to?(:clear!)
      if state_memory_ready?
        AutoplayBot::State.current_objective ||= AutoplayBot::GuidePack.first_objective
        AutoplayBot::State.clear_last_stuck_signature! if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:clear_last_stuck_signature!)
      end
      set_supervisor_mode("story")
      state_memory_ready? ? note_saved_state_route_recalc! : route_recalc!("fresh map", false)
      AutoplayBot.log("director ready at #{position_label}") if AutoplayBot.respond_to?(:log)
    end

    def clear_navigation_context!(reason = nil, keep_transfer = true)
      @pending_activation = nil
      @pending_forest_forage_activation = nil
      @forest_forage_attempt = nil
      @local_discovery_cache = nil
      @active_decision_goal = nil
      @decision_choice_cache = nil
      @active_route_plan = nil
      @active_route_target = nil
      @active_event_target = nil
      @active_forest_npc = nil
      @active_forest_forage = nil
      @forest_forage_cache = nil
      @position_history = []
      @last_no_path_dir = nil
      @last_route_dir = nil
      @loop_recovery_probe = nil
      clear_stale_player_moving_tracker!
      @trying_to_move = false
      @active_transfer = nil unless keep_transfer
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      AutoplayBot.log("navigation context cleared: #{reason}") if reason && AutoplayBot.respond_to?(:log)
    rescue
      nil
    end

    def note_battle_context_start!
      @battle_context_active = true
      clear_navigation_context!("battle start", true)
      @blocked_reason = nil
      @blocked_frames = 0
      @stuck_frames = 0
      @message_frames = 0
      @was_message_showing = false
      @dialog_settle_until_frame = nil
      @loop_recovery_until_frame = nil
      @loop_recovery_status = nil
      @loop_recovery_probe = nil
      @last_pos = nil
      set_supervisor_mode("battle")
      AutoplayBot::State.record_active_goal(nil) if state_memory_ready? && AutoplayBot::State.respond_to?(:record_active_goal)
      AutoplayBot.status("battle: starting") if defined?(AutoplayBot)
    rescue => e
      AutoplayBot.log("battle start note failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    end

    def note_battle_context_end!
      @battle_context_active = false
      clear_navigation_context!("battle end", true)
      @blocked_reason = nil
      @blocked_frames = 0
      @stuck_frames = 0
      @message_frames = 0
      @was_message_showing = false
      @dialog_settle_until_frame = nil
      @last_pos = nil
      @map_settle_until_frame = nil
      @map_settle_started_frame = nil
      @map_settle_started_at = nil
      @map_settle_reason = nil
      @path_cache = {}
      @active_route_plan = nil
      @active_route_target = nil
      set_supervisor_mode("navigation")
      AutoplayBot.status("battle: rerouting") if defined?(AutoplayBot)
      AutoplayBot.log("battle end reroute at #{position_label}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    rescue => e
      AutoplayBot.log("battle end note failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    end

    def note_human_override_start!
      @route_recalc_origin = current_live_position
      @route_recalc_explore_until_frame = nil
      clear_navigation_context!("human override start", true)
      @stuck_frames = 0
      @blocked_frames = 0
      @last_pos = nil
      AutoplayBot::State.record_active_goal(nil) if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:record_active_goal)
      set_supervisor_mode("manual_needed")
    rescue
      nil
    end

    def note_human_override_complete!(source = "player control")
      reason = source.to_s.empty? ? "player control" : source.to_s
      origin = @route_recalc_origin
      live = current_live_position
      moved = route_position_changed?(origin, live, 0)
      route_recalc!(moved ? "#{reason} moved" : "#{reason} released", true)
    rescue
      nil
    end

    def note_saved_state_route_recalc!
      previous = saved_last_position
      live = current_live_position
      reason = if previous && route_position_changed?(previous, live, 1)
                 "saved state moved"
               elsif previous
                 "saved state"
               else
                 "fresh map"
               end
      route_recalc!(reason, true)
    rescue
      nil
    end

    def route_recalc!(reason = "recalculate", prefer_explore = true)
      frame = (Graphics.frame_count rescue 0).to_i
      clear_navigation_context!("route recalc #{reason}", true)
      @path_cache = {}
      @target_cooldowns = {}
      @activation_cooldowns = {}
      @last_world_scan_frame = -9999
      @last_map_knowledge_frame = -9999
      @decision_choice_cache = nil
      @active_decision_goal = nil
      @local_discovery_cache = nil
      @last_pos = nil
      @stuck_frames = 0
      @blocked_frames = 0
      @route_recalc_reason = reason.to_s
      @route_recalc_origin = current_live_position
      @last_observed_tile_pos = nil
      @last_observed_tile_frame = nil
      if prefer_explore && route_recalc_explore_map?
        @route_recalc_explore_until_frame = frame + route_recalc_explore_frames
        set_supervisor_mode("frontier_explore")
        AutoplayBot.status("recalc: explore nearby")
      else
        @route_recalc_explore_until_frame = nil
        set_supervisor_mode("story")
        AutoplayBot.status("recalc: #{reason}")
      end
      AutoplayBot::State.record_active_goal(nil) if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:record_active_goal)
      AutoplayBot.log("route recalc #{reason} at #{position_label}") if AutoplayBot.respond_to?(:log)
    rescue => e
      AutoplayBot.log("route recalc failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    end

    def saved_last_position
      if state_memory_ready?
        return AutoplayBot::State.last_position if AutoplayBot::State.respond_to?(:last_position)
        return AutoplayBot::State.save_bucket["last_position"] if AutoplayBot::State.respond_to?(:save_bucket)
      end
      nil
    rescue
      nil
    end

    def current_live_position
      return nil unless defined?($game_player) && $game_player
      {
        "map_id" => current_map_id,
        "x" => $game_player.x,
        "y" => $game_player.y
      }
    rescue
      nil
    end

    def route_position_changed?(old_pos, new_pos, tolerance = 0)
      return false unless old_pos && new_pos
      return true if old_pos["map_id"].to_i != new_pos["map_id"].to_i
      distance = (old_pos["x"].to_i - new_pos["x"].to_i).abs + (old_pos["y"].to_i - new_pos["y"].to_i).abs
      distance > tolerance.to_i
    rescue
      false
    end

    def route_recalc_explore_map?
      return false unless defined?($game_player) && $game_player
      return false unless trainer_has_pokedex?
      return false if player_room_map?(current_map_id)
      return false if player_house_map?(current_map_id) && !starter_obtained?
      return false if OAK_LAB_MAP_IDS.include?(current_map_id.to_i) && !trainer_has_pokedex?
      true
    rescue
      false
    end

    def route_recalc_explore_frames
      return 420 if TOWN_CLEANUP_MAP_IDS.include?(current_map_id.to_i)
      return 300 if story_navigation_map?(current_map_id)
      240
    rescue
      240
    end

    def route_recalc_explore_active?
      return false unless @route_recalc_explore_until_frame
      return false unless route_recalc_explore_map?
      (Graphics.frame_count rescue 0).to_i < @route_recalc_explore_until_frame.to_i
    rescue
      false
    end

    def pathfinder_blocked_step?(map_id, x, y, dir)
      purge_blocked_step_memory
      key = blocked_step_key(map_id, x, y, dir)
      entry = @blocked_step_memory && @blocked_step_memory[key]
      if entry && transient_path_block_reason?(entry["reason"])
        @blocked_step_memory.delete(key) rescue nil
        return false
      end
      entry && entry["until"].to_i > (Graphics.frame_count rescue 0).to_i
    rescue
      false
    end

    def remember_blocked_step!(pos = nil, dir = nil, reason = "blocked")
      return unless defined?($game_player) && $game_player
      return if transient_path_block_reason?(reason)
      dir = dir.to_i
      return unless [2, 4, 6, 8].include?(dir)
      pos ||= [current_map_id, $game_player.x, $game_player.y]
      map_id = pos[0].to_i
      x = pos[1].to_i
      y = pos[2].to_i
      key = blocked_step_key(map_id, x, y, dir)
      @blocked_step_memory ||= {}
      frame = (Graphics.frame_count rescue 0).to_i
      entry = @blocked_step_memory[key] ||= { "count" => 0 }
      last_frame = entry["last_frame"].to_i
      if last_frame > 0 && frame - last_frame < blocked_step_repeat_guard_frames
        entry["count"] = [entry["count"].to_i + 1, 8].min
        entry["reason"] = reason.to_s
        entry["until"] = [entry["until"].to_i, frame + 120].max
        return
      end
      entry["last_frame"] = frame
      entry["count"] = [entry["count"].to_i + 1, 8].min
      entry["reason"] = reason.to_s
      entry["until"] = frame + blocked_step_ttl_frames(reason, entry["count"])
      @blocked_step_version = @blocked_step_version.to_i + 1
      @path_cache = {}
      @active_route_plan = nil
      AutoplayBot.status("remember block #{dir_label(dir)}") if defined?(AutoplayBot)
      if blocked_step_log_allowed?(entry, frame) && defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
        entry["last_log_frame"] = frame
        AutoplayBot.log("blocked step #{map_id}:#{x},#{y} #{dir_label(dir)} reason=#{reason} count=#{entry["count"]}")
      end
    rescue
      nil
    end

    def blocked_step_repeat_guard_frames
      10
    rescue
      10
    end

    def blocked_step_log_allowed?(entry, frame)
      count = entry && entry["count"].to_i
      return true if count <= 2
      last = entry && entry["last_log_frame"].to_i
      last <= 0 || frame.to_i - last >= 240
    rescue
      false
    end

    def blocked_step_ttl_frames(reason, count = 1)
      return 45 if transient_path_block_reason?(reason)
      base = case reason.to_s
             when "stuck" then 1800
             when "pingpong", "loop" then 1200
             when "horizontal_loop", "vertical_loop" then 900
             when "loop_edge" then 360
             else 900
             end
      base + ([count.to_i, 5].min * 300)
    rescue
      1800
    end

    def transient_path_block_reason?(reason)
      text = reason.to_s.downcase
      return true if text.include?("patrol_stalled")
      return true if text.include?("enter_stalled")
      return true if text.include?("enter_blocked")
      return true if text.include?("grass_dir_blocked")
      return true if text.include?("grass")
      return true if text.include?("fallback")
      false
    rescue
      false
    end

    def purge_blocked_step_memory
      return unless @blocked_step_memory
      frame = (Graphics.frame_count rescue 0).to_i
      @blocked_step_memory.delete_if { |_key, entry| entry["until"].to_i <= frame }
    rescue
      nil
    end

    def blocked_step_key(map_id, x, y, dir)
      "#{map_id.to_i}:#{x.to_i}:#{y.to_i}:#{dir.to_i}"
    rescue
      "0:0:0:0"
    end

    def note_forced_input_complete!(label = "prompt")
      frame = (Graphics.frame_count rescue 0).to_i
      @was_message_showing = false
      @message_frames = 0
      @last_message_advance_frame = nil
      @dialog_settle_until_frame = frame + 12
      clear_navigation_context!("forced input #{label}", true)
      AutoplayBot.status("#{label}: done") if defined?(AutoplayBot)
    rescue
      nil
    end

    def position_label
      return "no map" unless defined?($game_player) && $game_player
      "map #{current_map_id} x#{$game_player.x} y#{$game_player.y}"
    rescue
      "unknown position"
    end

    def title_tick
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      set_supervisor_mode("manual_needed")
      AutoplayBot.status("waiting: enter overworld") if defined?(AutoplayBot)
    end

    def on_map?
      defined?($scene) && defined?(Scene_Map) && $scene.is_a?(Scene_Map) &&
        defined?($game_map) && $game_map && defined?($game_player) && $game_player
    rescue
      false
    end

    def current_map_id
      defined?($game_map) && $game_map ? $game_map.map_id : nil
    end

    def set_supervisor_mode(mode)
      AutoplayBot::State.set_runtime_mode(mode) if state_memory_ready? && AutoplayBot::State.respond_to?(:set_runtime_mode)
    rescue
      nil
    end

    def record_navigation_state
      return unless state_memory_ready? && defined?($game_player) && $game_player
      AutoplayBot::State.update_last_position(current_map_id, $game_player.x, $game_player.y) if AutoplayBot::State.respond_to?(:update_last_position)
      record_game_heal_hub
      record_route_anchor
    rescue
      nil
    end

    def record_game_heal_hub
      return unless defined?($PokemonGlobal) && $PokemonGlobal && defined?(AutoplayBot::State)
      if $PokemonGlobal.respond_to?(:pokecenterMapId) && $PokemonGlobal.pokecenterMapId.to_i > 0
        AutoplayBot::State.record_heal_hub(
          $PokemonGlobal.pokecenterMapId,
          ($PokemonGlobal.pokecenterX if $PokemonGlobal.respond_to?(:pokecenterX)),
          ($PokemonGlobal.pokecenterY if $PokemonGlobal.respond_to?(:pokecenterY)),
          ($PokemonGlobal.pokecenterDirection if $PokemonGlobal.respond_to?(:pokecenterDirection)),
          "Pokemon Center"
        )
      elsif $PokemonGlobal.respond_to?(:healingSpot) && $PokemonGlobal.healingSpot
        spot = $PokemonGlobal.healingSpot
        AutoplayBot::State.record_heal_hub(spot[0], spot[1], spot[2], nil, "Healing spot") if spot.respond_to?(:[])
      end
    rescue
      nil
    end

    def record_route_anchor
      return unless defined?(AutoplayBot::State)
      case current_map_id.to_i
      when PALLET_TOWN_MAP_ID
        AutoplayBot::State.set_route_anchor(current_map_id, $game_player.x, $game_player.y, "Pallet Town")
      when VIRIDIAN_CITY_MAP_ID
        AutoplayBot::State.set_route_anchor(current_map_id, $game_player.x, $game_player.y, "Viridian City")
      when PEWTER_CITY_MAP_ID
        AutoplayBot::State.set_route_anchor(current_map_id, $game_player.x, $game_player.y, "Pewter City")
      end
    rescue
      nil
    end

    def soft_recover!(reason)
      return false unless defined?(AutoplayBot::State)
      AutoplayBot::State.record_failure_event(reason, "source" => "soft_recover") if AutoplayBot::State.respond_to?(:record_failure_event)
      objective = AutoplayBot::State.current_objective
      retries = AutoplayBot::State.increment_objective_retry(objective, reason) if AutoplayBot::State.respond_to?(:increment_objective_retry)
      if retries.to_i > AutoplayBot::Config.max_objective_retries
        objective_id = objective.is_a?(Hash) ? objective["id"] : objective
        AutoplayBot::State.add_manual_note("retry limit: #{reason}") if AutoplayBot::State.respond_to?(:add_manual_note)
        AutoplayBot.log("retry limit reached for #{objective_id}: #{reason}") if AutoplayBot.respond_to?(:log)
        return false
      end
      plan = {
        "phase" => "reroute",
        "reason" => reason.to_s,
        "objective" => objective,
        "started_at" => Time.now.to_i,
        "retries" => retries.to_i,
        "from_map" => current_map_id,
        "from_x" => (defined?($game_player) && $game_player ? $game_player.x : nil),
        "from_y" => (defined?($game_player) && $game_player ? $game_player.y : nil),
        "hub" => recovery_hub
      }
      @soft_recovery = plan
      @active_transfer = nil
      @active_event_target = nil
      @pending_activation = nil
      @trying_to_move = false
      @stuck_frames = 0
      @blocked_frames = 0
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      AutoplayBot::State.set_recovery_plan(plan) if AutoplayBot::State.respond_to?(:set_recovery_plan)
      AutoplayBot::State.add_manual_note("soft recovery: #{reason}") if AutoplayBot::State.respond_to?(:add_manual_note)
      set_supervisor_mode("recovery")
      AutoplayBot.status("recovery: #{reason}")
      true
    rescue => e
      AutoplayBot.log("soft recovery setup failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def recovery_hub
      hub = AutoplayBot::State.last_heal_hub if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:last_heal_hub)
      return hub if hub && hub["map_id"].to_i > 0
      {
        "map_id" => PALLET_TOWN_MAP_ID,
        "x" => PALLET_ROUTE_1_EXIT["x"],
        "y" => 10,
        "label" => "Pallet Town"
      }
    rescue
      { "map_id" => PALLET_TOWN_MAP_ID, "label" => "Pallet Town" }
    end

    def clear_soft_recovery!
      @soft_recovery = nil
      AutoplayBot::State.set_recovery_plan(nil) if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:set_recovery_plan)
    rescue
      nil
    end

    def soft_recovery_tick
      plan = @soft_recovery || (AutoplayBot::State.recovery_plan if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:recovery_plan))
      return false unless plan
      @soft_recovery = plan
      set_supervisor_mode("recovery")
      AutoplayBot.status("recovery: #{plan["reason"]}")

      if player_room_map?(current_map_id)
        set_objective("recovery_leave_bedroom", "recovery", "Recover from bedroom")
        transfer = room_to_house_transfer || fallback_room_to_house_transfer
        @active_transfer = transfer
        transfer ? navigate_to_transfer(transfer) : direct_step_toward(10, 5, "recovery: stairs")
        return true
      end

      if player_house_map?(current_map_id)
        set_objective("recovery_leave_home", "recovery", "Recover from home")
        return true if direct_blackout_house_exit
      end

      if training_needed_after_recovery?
        clear_soft_recovery!
        return training_tick
      end

      if story_navigation_map?(current_map_id)
        clear_soft_recovery!
        AutoplayBot.status("recovery: route rebuilt")
        return false
      end

      transfer = recovery_exit_transfer
      if transfer
        set_objective("recovery_exit_#{current_map_id}", "recovery", "Recover to route")
        @active_transfer = transfer
        navigate_to_transfer(transfer)
        return true
      end

      clear_soft_recovery!
      false
    rescue => e
      AutoplayBot.log("soft recovery tick failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      clear_soft_recovery!
      false
    end

    def pause_menu_utility_tick
      return false unless defined?(AutoplayBot::MenuTools)
      pending = AutoplayBot::MenuTools.pending_action if AutoplayBot::MenuTools.respond_to?(:pending_action)
      if pending && pewter_gym_story_locked?
        AutoplayBot::MenuTools.note_menu_action_blocked!(pending, "gym challenge priority") if AutoplayBot::MenuTools.respond_to?(:note_menu_action_blocked!)
        return false
      end
      if pending
        if AutoplayBot::MenuTools.respond_to?(:pending_stale?) && AutoplayBot::MenuTools.pending_stale?(240)
          AutoplayBot::MenuTools.note_menu_action_blocked!(pending, "pause menu did not open") if AutoplayBot::MenuTools.respond_to?(:note_menu_action_blocked!)
          return false
        end
        set_supervisor_mode("recovery")
        AutoplayBot.status("menu: waiting #{pending}") if defined?(AutoplayBot)
        return true
      end
      return false if pewter_gym_story_locked?
      return false unless can_open_pause_menu_for_bot?
      return false if menu_utility_frame_cooldown?

      if party_needs_center_heal? && AutoplayBot::MenuTools.pause_menu_available_for?(:heal)
        set_supervisor_mode("recovery")
        set_objective("pause_menu_heal_party", "heal", "Use pause menu heal")
        @last_menu_utility_frame = (Graphics.frame_count rescue 0).to_i
        return AutoplayBot::MenuTools.open_pause_menu(:heal, "party low")
      end

      if pause_menu_shop_needed?
        set_supervisor_mode("recovery")
        set_objective("pause_menu_kuray_shop", "shop", "Use Kuray Shop")
        @last_menu_utility_frame = (Graphics.frame_count rescue 0).to_i
        return AutoplayBot::MenuTools.open_pause_menu(:kuray_shop, "restock resources")
      end

      false
    rescue => e
      AutoplayBot.log("pause menu utility failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def can_open_pause_menu_for_bot?
      return false unless on_map?
      return false unless defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.running?
      return false if AutoplayBot::Runtime.respond_to?(:battle_transition_cooldown_active?) &&
                      AutoplayBot::Runtime.battle_transition_cooldown_active?(3.0)
      return false if message_showing?
      return false if defined?($game_player) && $game_player && $game_player.respond_to?(:moving?) && $game_player.moving?
      if defined?($game_temp) && $game_temp
        return false if $game_temp.in_battle || $game_temp.in_menu
        return false if $game_temp.player_transferring || $game_temp.transition_processing || $game_temp.to_title
      end
      return false if forced_map_activity?
      if Object.new.respond_to?(:pbMapInterpreterRunning?, true) && Object.new.send(:pbMapInterpreterRunning?)
        return false
      end
      true
    rescue
      false
    end

    def menu_utility_frame_cooldown?
      frame = (Graphics.frame_count rescue 0).to_i
      @last_menu_utility_frame ||= -9999
      frame - @last_menu_utility_frame.to_i < 60
    rescue
      false
    end

    def pause_menu_shop_needed?
      return false unless trainer_has_pokedex?
      return false unless defined?(AutoplayBot::ShopPolicy) && AutoplayBot::ShopPolicy.restock_needed?
      return false unless defined?(AutoplayBot::MenuTools) && AutoplayBot::MenuTools.pause_menu_available_for?(:kuray_shop)
      true
    rescue
      false
    end

    def heal_route_tick
      return false unless party_needs_center_heal?
      return false unless defined?(AutoplayBot::State)
      hub = recovery_hub
      return false unless hub && hub["map_id"].to_i > 0
      if current_map_id.to_i == hub["map_id"].to_i
        healer = current_map_healer_target
        return false unless healer
        set_supervisor_mode("recovery")
        set_objective("heal_party_#{current_map_id}", "heal", "Heal party")
        AutoplayBot.status("heal: talk to healer")
        navigate_to_event(healer)
        return true
      end
      transfer = direct_heal_hub_transfer(hub)
      return false unless transfer
      set_supervisor_mode("recovery")
      set_objective("heal_route_#{current_map_id}", "heal", "Return to healer")
      @active_transfer = transfer
      AutoplayBot.status("heal: #{transfer_label(transfer)}")
      navigate_to_transfer(transfer)
      true
    rescue => e
      AutoplayBot.log("heal route failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def party_needs_center_heal?
      return false unless defined?($Trainer) && $Trainer && $Trainer.respond_to?(:party)
      party = $Trainer.party.compact
      return false if party.empty?
      able = party.count { |pkmn| pokemon_able?(pkmn) }
      ratio = party_hp_ratio(party)
      return true if able <= 1 && party.length > 1
      return true if ratio > 0.0 && ratio < 0.42
      return true if party_has_status?(party) && ratio > 0.0 && ratio < 0.68
      return true if party_pp_pressure?(party) && ratio > 0.0 && ratio < 0.78
      false
    rescue
      false
    end

    def party_hp_ratio(party)
      totals = [0, 0]
      Array(party).each do |pkmn|
        hp = pkmn.respond_to?(:hp) ? pkmn.hp.to_i : 1
        total = pkmn.respond_to?(:totalhp) ? pkmn.totalhp.to_i : 0
        total = hp if total <= 0
        totals[0] += [[hp, 0].max, total].min
        totals[1] += total
      end
      return 1.0 if totals[1] <= 0
      totals[0].to_f / totals[1].to_f
    rescue
      1.0
    end

    def pokemon_able?(pokemon)
      return pokemon.able? if pokemon && pokemon.respond_to?(:able?)
      return pokemon.hp.to_i > 0 if pokemon && pokemon.respond_to?(:hp)
      true
    rescue
      true
    end

    def party_has_status?(party)
      Array(party).any? do |pkmn|
        next false unless pkmn && pkmn.respond_to?(:status)
        status = pkmn.status
        next false if status.nil?
        next false if status.respond_to?(:to_i) && status.to_i == 0
        status.to_s !~ /\A(?:NONE|0)?\z/i
      end
    rescue
      false
    end

    def party_pp_pressure?(party)
      able_party = Array(party).select { |pkmn| pokemon_able?(pkmn) }
      return false if able_party.empty?
      weak = able_party.count do |pkmn|
        moves = pkmn.respond_to?(:moves) ? pkmn.moves.compact : []
        next false if moves.empty?
        moves.count { |move| move.respond_to?(:pp) && move.pp.to_i > 0 } <= 1
      end
      weak >= [1, (able_party.length / 2.0).ceil].max
    rescue
      false
    end

    def direct_heal_hub_transfer(hub)
      map = AutoplayBot::WorldScanner.current_map_data if defined?(AutoplayBot::WorldScanner)
      transfers = map && map["transfers"].is_a?(Array) ? map["transfers"] : []
      candidates = transfers.select do |transfer|
        transfer["destination_map_id"].to_i == hub["map_id"].to_i ||
          [transfer["event_name"], transfer["destination_name"]].compact.join(" ") =~ /pokemon\s*center|pokecenter|center/i
      end
      scored = candidates.map do |transfer|
        include_adjacent = transfer["trigger"].to_i != 1
        path = AutoplayBot::Pathfinder.path_to(transfer["x"], transfer["y"], adaptive_budget(900, "healer"), include_adjacent)
        next nil unless path
        [path.length, transfer]
      end.compact
      best = scored.sort_by { |entry| entry[0] }.first
      if best && defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:record_heal_route)
        AutoplayBot::State.record_heal_route(current_map_id, transfer_label(best[1]), best[1], best[0])
      end
      best && best[1]
    rescue
      nil
    end

    def current_map_healer_target
      map = AutoplayBot::WorldScanner.current_map_data if defined?(AutoplayBot::WorldScanner)
      records = []
      records.concat(map["npcs"]) if map && map["npcs"].is_a?(Array)
      records.concat(map["events"]) if map && map["events"].is_a?(Array)
      candidates = unique_events(records).select { |record| healer_event_record?(record) }
      scored = candidates.map do |record|
        healer = healer_event_target(record)
        path = path_to_event_action(healer, adaptive_budget(900, "healer"))
        next nil unless path
        [path.length, healer]
      end.compact
      best = scored.sort_by { |entry| entry[0] }.first
      if best && defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:record_heal_route)
        AutoplayBot::State.record_heal_route(current_map_id, "Healer on current map", best[1], best[0])
      end
      best && best[1]
    rescue
      nil
    end

    def healer_event_record?(record)
      return false unless record.is_a?(Hash)
      text = [
        record["event_name"],
        record["name"],
        record["graphic"],
        record["comments"],
        Array(record["pages"]).map { |page| page.is_a?(Hash) ? page["script_digest"] : nil }
      ].flatten.compact.join(" ")
      text =~ /nurse|joy|heal|restore|pokemon\s*center|pokecenter/i
    rescue
      false
    end

    def healer_event_target(record)
      {
        "key" => "healer:#{current_map_id}:#{record["event_id"] || record["id"] || record["x"]}:#{record["y"]}",
        "map_id" => current_map_id,
        "event_id" => record["event_id"] || record["id"],
        "event_name" => record["event_name"] || record["name"] || "Healer",
        "x" => record["x"],
        "y" => record["y"],
        "trigger" => record["trigger"] || 0,
        "frontier_kind" => "healer",
        "frontier_key" => "healer:#{current_map_id}:#{record["event_id"] || record["id"] || record["x"]}:#{record["y"]}"
      }
    rescue
      record
    end

    def prefer_fast_travel!
      frame = (Graphics.frame_count rescue 0).to_i
      @last_fast_travel_frame = -9999 if @last_fast_travel_frame.nil?
      return if frame - @last_fast_travel_frame.to_i < 30
      @last_fast_travel_frame = frame
      return unless should_mount_bike?
      AutoplayBot.helper(:pbMountBike)
      AutoplayBot.status("travel: bike")
      AutoplayBot.log("mounted bike at #{position_label}") if AutoplayBot.respond_to?(:log)
    rescue => e
      AutoplayBot.log("bike mount failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    end

    def should_mount_bike?
      return false unless on_map?
      return false if player_house_map?(current_map_id) || player_room_map?(current_map_id)
      return false unless bike_item_owned?
      return false unless defined?($PokemonGlobal) && $PokemonGlobal
      return false if $PokemonGlobal.respond_to?(:bicycle) && $PokemonGlobal.bicycle
      return false if $PokemonGlobal.respond_to?(:surfing) && $PokemonGlobal.surfing
      return false if $PokemonGlobal.respond_to?(:diving) && $PokemonGlobal.diving
      return false if $PokemonGlobal.respond_to?(:fishing) && $PokemonGlobal.fishing
      if defined?($game_player) && $game_player
        return false if $game_player.respond_to?(:pbHasDependentEvents?) && $game_player.pbHasDependentEvents?
        if $game_player.respond_to?(:pbTerrainTag)
          terrain = $game_player.pbTerrainTag rescue nil
          return false if terrain && terrain.respond_to?(:must_walk) && terrain.must_walk
        end
      end
      AutoplayBot.helper(:pbCanUseBike?, current_map_id) == true
    rescue
      false
    end

    def bike_item_owned?
      bag_has_item?(:BICYCLE) || bag_has_item?(:RACEBIKE)
    rescue
      false
    end

    def bag_has_item?(item)
      return false unless defined?($PokemonBag) && $PokemonBag
      return $PokemonBag.pbHasItem?(item) if $PokemonBag.respond_to?(:pbHasItem?)
      return $PokemonBag.pbQuantity(item).to_i > 0 if $PokemonBag.respond_to?(:pbQuantity)
      false
    rescue
      false
    end

    def maybe_plan_training_after_blackout!
      return unless defined?(AutoplayBot::State) && AutoplayBot::Config.training_after_loss?
      objective = @blackout_recovery && @blackout_recovery["objective"]
      return unless battle_objective?(objective) || current_map_id.to_i == PEWTER_GYM_MAP_ID
      AutoplayBot::State.record_battle_loss(
        "map" => @blackout_recovery["from_map"],
        "x" => @blackout_recovery["from_x"],
        "y" => @blackout_recovery["from_y"],
        "objective" => objective,
        "reason" => "blackout"
      ) if AutoplayBot::State.respond_to?(:record_battle_loss)
      target = brock_objective?(objective) ? DEFAULT_TRAINING_TARGET_LEVEL : [party_max_level + 2, 8].max
      AutoplayBot::State.set_training_plan(
        "reason" => "battle loss",
        "objective" => objective,
        "target_level" => target,
        "started_at" => Time.now.to_i,
        "minimum_frames" => 900,
        "from_map" => @blackout_recovery["from_map"]
      ) if AutoplayBot::State.respond_to?(:set_training_plan)
    rescue => e
      AutoplayBot.log("training plan after blackout failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    end

    def battle_objective?(objective)
      return false unless objective.is_a?(Hash)
      objective["type"].to_s == "battle" || objective["id"].to_s =~ /battle|brock|gym/i || objective["label"].to_s =~ /battle|brock|gym/i
    rescue
      false
    end

    def brock_objective?(objective)
      objective.is_a?(Hash) && [objective["id"], objective["label"]].compact.join(" ") =~ /brock|pewter/i
    rescue
      false
    end

    def training_needed_after_recovery?
      plan = AutoplayBot::State.training_plan if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:training_plan)
      plan && !training_complete?(plan)
    rescue
      false
    end

    def training_tick
      plan = AutoplayBot::State.training_plan if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:training_plan)
      return false unless plan && AutoplayBot::Config.training_after_loss?
      if training_complete?(plan)
        AutoplayBot::State.clear_training_plan if AutoplayBot::State.respond_to?(:clear_training_plan)
        AutoplayBot::State.current_objective = plan["objective"] if plan["objective"]
        set_supervisor_mode("story")
        AutoplayBot.status("training: done")
        return false
      end

      set_supervisor_mode("training")
      set_objective("training_after_loss", "training", "Train before retry")
      if player_room_map?(current_map_id)
        transfer = room_to_house_transfer || fallback_room_to_house_transfer
        @active_transfer = transfer
        transfer ? navigate_to_transfer(transfer) : direct_step_toward(10, 5, "training: stairs")
        return true
      end
      if player_house_map?(current_map_id)
        return true if direct_blackout_house_exit
      end
      case current_map_id.to_i
      when PALLET_TOWN_MAP_ID
        map_edge_step(PALLET_ROUTE_1_EXIT["x"], PALLET_ROUTE_1_EXIT["y"], 8, "training Route 1")
      when ROUTE_1_MAP_ID, ROUTE_2_SOUTH_MAP_ID, VIRIDIAN_FOREST_MAP_ID, ROUTE_2_NORTH_MAP_ID
        return true if repeatable_training_tick(plan)
        training_walk(plan)
      when VIRIDIAN_CITY_MAP_ID
        map_edge_step(VIRIDIAN_ROUTE_2_EXIT["x"], VIRIDIAN_ROUTE_2_EXIT["y"], 8, "training Route 2")
      when PEWTER_GYM_MAP_ID
        transfer = recovery_exit_transfer
        if transfer
          @active_transfer = transfer
          navigate_to_transfer(transfer)
        else
          direct_step_toward(8, 23, "training: leave gym")
        end
      else
        return false unless AutoplayBot::Config.frontier_explore?
        explore_current_map
      end
      true
    rescue => e
      AutoplayBot.log("training tick failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def training_complete?(plan)
      return true if first_badge_obtained? && brock_objective?(plan["objective"])
      target = plan["target_level"].to_i
      target = DEFAULT_TRAINING_TARGET_LEVEL if target <= 0
      return true if party_max_level >= target
      return true if party_average_level >= [target - 2, 6].max && party_able_count >= 2
      false
    rescue
      false
    end

    def repeatable_training_tick(plan)
      return false unless defined?(AutoplayBot::RepeatableBattleLedger)
      return false if defined?(AutoplayBot::Config) && AutoplayBot::Config.farming_policy == "minimal_fallback" && plan["reason"].to_s != "battle loss"
      return false unless party_able_count >= 2
      if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:farm_cycle_count)
        return false if AutoplayBot::State.farm_cycle_count(plan["objective"]) >= AutoplayBot::Config.max_farm_cycles_per_objective
      end
      record = AutoplayBot::RepeatableBattleLedger.best_repeatable_for_current_map
      return false unless record
      if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:increment_farm_cycle)
        path = path_to_event_action(record, 180)
        frame = (Graphics.frame_count rescue 0).to_i
        @last_farm_cycle_frame = -9999 if @last_farm_cycle_frame.nil?
        if path && path.empty? && frame - @last_farm_cycle_frame.to_i >= 120
          @last_farm_cycle_frame = frame
          AutoplayBot::State.increment_farm_cycle(plan["objective"], "repeatable battle")
        end
      end
      set_objective("training_repeatable_battle", "training", "Train on repeatable battle")
      AutoplayBot.status("training: repeatable battle")
      navigate_to_event(record.merge(
        "frontier_kind" => "repeatable_battle",
        "frontier_key" => "repeatable:#{current_map_id}:#{record["event_id"] || record["event_name"]}"
      ))
      true
    rescue => e
      AutoplayBot.log("repeatable training failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def training_walk(plan)
      frame = (Graphics.frame_count rescue 0).to_i
      @training_started_frame ||= frame
      if frame - @training_started_frame.to_i < plan["minimum_frames"].to_i
        AutoplayBot.status("training: scouting #{party_level_label}")
      else
        AutoplayBot.status("training: leveling #{party_level_label}")
      end
      dirs = [4, 6, 8, 2]
      index = (frame / 20).to_i % dirs.length
      dir = dirs[index, dirs.length].to_a.concat(dirs[0, index].to_a).find { |candidate| direction_passable?(candidate) }
      dir ||= dirs[index]
      @trying_to_move = true
      AutoplayBot::InputQueue.hold_dir(dir, movement_hold_frames([dir, dir, dir, dir], 12))
    rescue
      AutoplayBot::InputQueue.hold_dir(4, 10) if defined?(AutoplayBot::InputQueue)
    end

    def party_max_level
      return 0 unless defined?($Trainer) && $Trainer && $Trainer.respond_to?(:party)
      $Trainer.party.compact.map { |pkmn| pkmn.respond_to?(:level) ? pkmn.level.to_i : 0 }.max.to_i
    rescue
      0
    end

    def party_average_level
      return 0 unless defined?($Trainer) && $Trainer && $Trainer.respond_to?(:party)
      levels = $Trainer.party.compact.map { |pkmn| pkmn.respond_to?(:level) ? pkmn.level.to_i : 0 }.reject { |lvl| lvl <= 0 }
      return 0 if levels.empty?
      levels.inject(0) { |sum, lvl| sum + lvl } / levels.length
    rescue
      0
    end

    def party_able_count
      return 0 unless defined?($Trainer) && $Trainer && $Trainer.respond_to?(:party)
      $Trainer.party.compact.count { |pkmn| pkmn.respond_to?(:able?) ? pkmn.able? : true }
    rescue
      0
    end

    def party_level_label
      "Lv#{party_max_level}/avg#{party_average_level}"
    rescue
      "party"
    end

    def advance_message_window
      frame = (Graphics.frame_count rescue 0).to_i
      @last_message_advance_frame = -9999 if @last_message_advance_frame.nil?
      return if frame - @last_message_advance_frame.to_i < 8
      @last_message_advance_frame = frame
      AutoplayBot.status("dialog: pressing through")
      AutoplayBot::InputQueue.tap(:USE, 1)
      AutoplayBot::InputQueue.tap_next(:USE, 1) if AutoplayBot::InputQueue.respond_to?(:tap_next)
    rescue
      nil
    end

    def settle_after_message_window
      frame = (Graphics.frame_count rescue 0).to_i
      if @was_message_showing
        @was_message_showing = false
        @dialog_settle_until_frame = frame + 10
        @last_message_advance_frame = nil
        clear_navigation_context!("dialog release", true)
        AutoplayBot.status("dialog: released")
        return true
      end
      return false unless @dialog_settle_until_frame && frame < @dialog_settle_until_frame.to_i
      AutoplayBot.status("dialog: settling")
      true
    rescue
      false
    end

    def message_showing?
      defined?($game_temp) && $game_temp && $game_temp.message_window_showing
    rescue
      false
    end

    def can_act_on_map?
      if defined?($game_temp) && $game_temp
        runtime_battle = defined?(AutoplayBot::Runtime) &&
                         AutoplayBot::Runtime.respond_to?(:battle_context?) &&
                         AutoplayBot::Runtime.battle_context?
        return battle_wait_false("battle active") if runtime_battle
        return battle_wait_false("battle active") if $game_temp.in_battle
        return blocked_false("menu active") if $game_temp.in_menu
        return blocked_false("transition active") if $game_temp.player_transferring || $game_temp.transition_processing || $game_temp.to_title
      end
      return blocked_false("cutscene active") if forced_map_activity?
      if $game_player.respond_to?(:moving?) && $game_player.moving?
        return false if movement_watchdog_tick
        return blocked_false("player moving")
      end
      clear_stale_player_moving_tracker!
      if Object.new.respond_to?(:pbMapInterpreterRunning?, true) && Object.new.send(:pbMapInterpreterRunning?)
        return blocked_false("map interpreter running")
      end
      true
    rescue => e
      blocked_false("can_act error #{e.class}: #{e.message}")
    end

    def blocked_false(reason)
      track_blocked(reason)
      log_blocked(reason)
      false
    end

    def battle_wait_false(reason)
      @blocked_reason = reason.to_s
      @blocked_frames = 0
      @stuck_frames = 0
      @trying_to_move = false
      set_supervisor_mode("battle")
      frame = (Graphics.frame_count rescue 0).to_i
      @last_battle_wait_status_frame = -9999 if @last_battle_wait_status_frame.nil?
      if frame - @last_battle_wait_status_frame.to_i >= 120
        @last_battle_wait_status_frame = frame
        AutoplayBot.status("battle: waiting")
      end
      false
    rescue
      false
    end

    def track_blocked(reason)
      if @blocked_reason.to_s == reason.to_s
        @blocked_frames = @blocked_frames.to_i + 1
      else
        @blocked_reason = reason.to_s
        @blocked_frames = 1
      end
      return unless @blocked_frames > 600
      if reason.to_s =~ /battle/i && battle_active?
        @blocked_frames = 0
        AutoplayBot.status("battle: waiting for AI")
        return
      end
      return unless reason.to_s =~ /interpreter|message|battle|menu/i
      @blocked_frames = 0
      AutoplayBot::Runtime.manual_needed("blocked by #{reason} for 600 frames at #{position_label}") if defined?(AutoplayBot::Runtime)
    rescue
      nil
    end

    def movement_watchdog_tick
      return false unless defined?($game_player) && $game_player
      return false unless $game_player.respond_to?(:moving?) && $game_player.moving?
      return false if battle_active?
      return false if defined?($game_temp) && $game_temp &&
                      ($game_temp.in_menu ||
                       $game_temp.message_window_showing ||
                       $game_temp.player_transferring ||
                       $game_temp.transition_processing ||
                       $game_temp.to_title)
      return false if forced_map_activity?
      recover_stale_player_moving!
    rescue
      false
    end

    def recover_stale_player_moving!
      return false unless defined?($game_player) && $game_player
      frame = (Graphics.frame_count rescue 0).to_i
      now = Time.now.to_f
      pos = [current_map_id, $game_player.x.to_i, $game_player.y.to_i]
      if @stale_player_moving_pos != pos
        @stale_player_moving_pos = pos
        @stale_player_moving_started_frame = frame
        @stale_player_moving_started_at = now
        return false
      end

      elapsed_frames = frame - @stale_player_moving_started_frame.to_i
      elapsed_time = now - @stale_player_moving_started_at.to_f
      return false if elapsed_frames < 45 && elapsed_time < 0.9
      if $game_player.respond_to?(:jumping?) && $game_player.jumping? &&
         elapsed_frames < 90 && elapsed_time < 1.8
        return false
      end

      snap_player_to_current_tile!
      @path_cache = {}
      @active_route_plan = nil
      @active_route_target = nil
      @decision_choice_cache = nil
      @local_discovery_cache = nil
      @loop_recovery_probe = nil
      @loop_recovery_until_frame = nil
      @loop_recovery_status = nil
      @trying_to_move = false
      @stuck_frames = 0
      @blocked_frames = 0
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      clear_stale_player_moving_tracker!
      AutoplayBot.status("recover: movement snap")
      AutoplayBot.log("stale player moving recovered at #{position_label}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      true
    rescue => e
      AutoplayBot.log("stale player moving recovery failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      clear_stale_player_moving_tracker!
      false
    end

    def snap_player_to_current_tile!
      return unless defined?($game_player) && $game_player
      if defined?(Game_Map::REAL_RES_X)
        $game_player.instance_variable_set(:@real_x, $game_player.x.to_i * Game_Map::REAL_RES_X)
      end
      if defined?(Game_Map::REAL_RES_Y)
        $game_player.instance_variable_set(:@real_y, $game_player.y.to_i * Game_Map::REAL_RES_Y)
      end
      $game_player.instance_variable_set(:@jump_count, 0) if $game_player.instance_variable_defined?(:@jump_count)
      $game_player.instance_variable_set(:@jump_distance_left, 0) if $game_player.instance_variable_defined?(:@jump_distance_left)
      $game_player.straighten if $game_player.respond_to?(:straighten)
    rescue => e
      AutoplayBot.log("player snap failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    end

    def clear_stale_player_moving_tracker!
      @stale_player_moving_pos = nil
      @stale_player_moving_started_frame = nil
      @stale_player_moving_started_at = nil
    rescue
      nil
    end

    def battle_active?
      if defined?(AutoplayBot::Runtime) && AutoplayBot::Runtime.respond_to?(:battle_context?)
        return true if AutoplayBot::Runtime.battle_context?
      end
      return true if defined?($game_temp) && $game_temp && $game_temp.in_battle
      return true if defined?($scene) && $scene && $scene.class.to_s =~ /Battle/
      false
    rescue
      false
    end

    def forced_map_activity?
      return true if defined?($PokemonTemp) && $PokemonTemp && $PokemonTemp.respond_to?(:miniupdate) && $PokemonTemp.miniupdate
      if defined?($game_player) && $game_player
        return true if $game_player.respond_to?(:move_route_forcing) && $game_player.move_route_forcing
        return true if $game_player.respond_to?(:transparent) && $game_player.transparent
      end
      return false unless defined?($game_map) && $game_map && $game_map.respond_to?(:events) && $game_map.events
      $game_map.events.values.any? do |event|
        next false unless event
        (event.respond_to?(:starting) && event.starting) ||
          (event.respond_to?(:move_route_forcing) && event.move_route_forcing)
      end
    rescue
      true
    end

    def log_blocked(reason)
      frame = Graphics.frame_count rescue 0
      @last_blocked_log_frame = -9999 if @last_blocked_log_frame.nil?
      return if frame.to_i - @last_blocked_log_frame.to_i < 120
      @last_blocked_log_frame = frame.to_i
      AutoplayBot.status("blocked: #{reason}")
      AutoplayBot.log("blocked: #{reason} at #{position_label}") if AutoplayBot.respond_to?(:log)
    rescue
      nil
    end

    def next_objective
      AutoplayBot::GuidePack.objectives.find { |obj| obj["id"].to_s != "title_start" } ||
        { "id" => "dynamic_exploration", "type" => "travel", "mode" => "scan_and_explore" }
    end

    def scan_world_slowly
      return unless defined?(AutoplayBot::WorldScanner)
      return if safe_mode? && current_map_id.to_i == VIRIDIAN_FOREST_MAP_ID
      frame = (Graphics.frame_count rescue 0).to_i
      @last_world_scan_frame = -9999 if @last_world_scan_frame.nil?
      return if frame - @last_world_scan_frame.to_i < AutoplayBot::Config.scan_interval_frames
      @last_world_scan_frame = frame
      AutoplayBot::WorldScanner.tick(AutoplayBot::Config.scan_budget)
    rescue
      nil
    end

    def forest_safe_mode_tick
      return false unless safe_mode?
      return false unless current_map_id.to_i == VIRIDIAN_FOREST_MAP_ID
      set_supervisor_mode("navigation")
      return true if forest_pickup_tick
      return true if forest_npc_tick
      set_objective("story_cross_viridian_forest", "travel", "Cross Viridian Forest")
      forest_story_route_step
      true
    rescue => e
      AutoplayBot.log("forest safe tick failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def handle_map_change
      map_id = current_map_id
      return unless map_id
      AutoplayBot::State.mark_map_seen(map_id)
      if @last_map_id && map_id != @last_map_id && @active_transfer
        previous_map_id = @last_map_id
        transfer_key = @active_transfer["key"] || (AutoplayBot::State.target_key(@active_transfer, "transfer") rescue nil)
        @last_transfer_transition = {
          "frame" => (Graphics.frame_count rescue 0).to_i,
          "from_map" => previous_map_id,
          "to_map" => map_id,
          "transfer_key" => transfer_key,
          "leaving_building" => (building_like_map_id?(previous_map_id) ||
            (story_navigation_map?(map_id) && building_transfer?(@active_transfer)))
        }
        AutoplayBot::State.mark_transfer_visited(transfer_key) if transfer_key
        if AutoplayBot::State.respond_to?(:touch_frontier)
          frontier_key = AutoplayBot::State.target_key(@active_transfer, "transfer") rescue transfer_key
          AutoplayBot::State.touch_frontier(frontier_key, true)
        end
        if AutoplayBot::State.respond_to?(:touch_cleanup_target)
          cleanup_key = AutoplayBot::State.target_key(@active_transfer, "building") rescue nil
          AutoplayBot::State.mark_target_done(cleanup_key) if cleanup_key && AutoplayBot::State.respond_to?(:mark_target_done)
          AutoplayBot::State.touch_cleanup_target(cleanup_key, true) if cleanup_key
        end
        AutoplayBot.log("visited transfer #{transfer_key}") if AutoplayBot.respond_to?(:log)
        @active_transfer = nil
      end
      if @last_map_id && map_id != @last_map_id
        @stuck_frames = 0
        @loop_recovery_until_frame = nil
        start_map_settle!(18, "map change #{map_id}")
        @repeat_item_done_this_visit = {}
        AutoplayBot::State.clear_last_stuck_signature! if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:clear_last_stuck_signature!)
        clear_navigation_context!("map change #{map_id}", true)
      end
      @last_map_id = map_id
    end

    def settling_after_map_change?
      frame = (Graphics.frame_count rescue 0).to_i
      return false unless @map_settle_until_frame
      return false if settle_gate_expired?(frame)
      label = @map_settle_reason.to_s.empty? ? "map change" : @map_settle_reason
      AutoplayBot.status("settling: #{label}")
      true
    rescue
      clear_map_settle!
      false
    end

    def start_map_settle!(frames = 18, reason = "map change")
      frame = (Graphics.frame_count rescue 0).to_i
      @map_settle_started_frame = frame
      @map_settle_until_frame = frame + [[frames.to_i, 1].max, 30].min
      @map_settle_started_at = Time.now
      @map_settle_reason = reason.to_s
    rescue
      @map_settle_until_frame = nil
    end

    def settle_gate_expired?(frame = nil)
      frame = (Graphics.frame_count rescue 0).to_i if frame.nil?
      if @map_settle_started_frame && frame < @map_settle_started_frame.to_i
        clear_map_settle!("frame reset")
        return true
      end
      if frame >= @map_settle_until_frame.to_i
        clear_map_settle!
        return true
      end
      if @map_settle_started_at && Time.now - @map_settle_started_at > 0.75
        clear_map_settle!("timeout")
        return true
      end
      false
    rescue
      clear_map_settle!
      true
    end

    def clear_map_settle!(reason = nil)
      if reason && defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
        AutoplayBot.log("settle gate cleared #{reason} at #{position_label}")
      end
      @map_settle_until_frame = nil
      @map_settle_started_frame = nil
      @map_settle_started_at = nil
      @map_settle_reason = nil
    rescue
      nil
    end

    def settling_after_startup?
      frame = (Graphics.frame_count rescue 0).to_i
      return false unless @startup_settle_until_frame && frame < @startup_settle_until_frame.to_i
      AutoplayBot.status("settling after F5")
      true
    rescue
      false
    end

    def loop_recovery_tick
      frame = (Graphics.frame_count rescue 0).to_i
      if @loop_recovery_probe
        if loop_recovery_probe_moved?(@loop_recovery_probe)
          finish_successful_loop_recovery_probe!
          return false
        end
        if player_currently_moving?
          @loop_recovery_until_frame = frame + 6
          AutoplayBot.status(@loop_recovery_status || "route: recovering")
          return true
      end
      if loop_recovery_probe_due?(@loop_recovery_probe, frame)
        return true if retry_loop_recovery_probe!(@loop_recovery_probe)
        @loop_recovery_until_frame = frame + 12
        @loop_recovery_status ||= "route: replan after probe"
        AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
        AutoplayBot.status(@loop_recovery_status || "route: replan") if defined?(AutoplayBot)
        return true
      end
    end
      unless @loop_recovery_until_frame && frame < @loop_recovery_until_frame.to_i
        finish_loop_recovery_probe! if @loop_recovery_probe
        @loop_recovery_until_frame = nil
        @loop_recovery_status = nil
        return false
      end
      AutoplayBot.status(@loop_recovery_status || "route: avoiding loop")
      true
    rescue
      false
    end

    def player_currently_moving?
      defined?($game_player) && $game_player && $game_player.respond_to?(:moving?) && $game_player.moving?
    rescue
      false
    end

    def loop_recovery_probe_moved?(probe)
      return false unless probe && defined?($game_player) && $game_player
      return true if current_map_id.to_i != probe["map_id"].to_i
      return true if $game_player.x.to_i != probe["x"].to_i
      return true if $game_player.y.to_i != probe["y"].to_i
      false
    rescue
      false
    end

    def loop_recovery_probe_due?(probe, frame = nil)
      return false unless probe
      frame = (Graphics.frame_count rescue 0).to_i if frame.nil?
      frame.to_i - probe["frame"].to_i >= loop_recovery_probe_fail_frames(probe)
    rescue
      false
    end

    def loop_recovery_probe_fail_frames(_probe = nil)
      [[estimated_tile_frames + 6, 8].max, 16].min
    rescue
      10
    end

    def finish_successful_loop_recovery_probe!
      @loop_recovery_probe = nil
      @loop_recovery_until_frame = nil
      @loop_recovery_status = nil
      @path_cache = {}
      @active_route_plan = nil
      @decision_choice_cache = nil
      @local_discovery_cache = nil
      @trying_to_move = false
      @stuck_frames = 0
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      AutoplayBot.status("recovered: replan")
    rescue
      nil
    end

    def retry_loop_recovery_probe!(probe)
      failed_dir = probe["dir"].to_i
      remember_blocked_step!([probe["map_id"], probe["x"], probe["y"]], failed_dir, "probe_failed")
      next_dir = next_loop_recovery_dir(probe)
      unless next_dir
        cool_down_active_navigation_target(probe["reason"])
        mark_active_navigation_target_failed("probe_failed #{probe["reason"]}")
        finish_loop_recovery_probe!
        @loop_recovery_until_frame = nil
        @loop_recovery_status = nil
        return false
      end
      @path_cache = {}
      @active_route_plan = nil
      @decision_choice_cache = nil
      @local_discovery_cache = nil
      @trying_to_move = true
      @last_no_path_dir = next_dir
      @last_route_dir = next_dir
      frames = quick_recovery_hold_frames(next_dir)
      remaining = loop_recovery_remaining_dirs(probe, next_dir)
      status = "recover try #{dir_label(next_dir)}"
      start_loop_recovery_probe!(next_dir, status, frames, probe["reason"], remaining)
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      AutoplayBot::InputQueue.hold_dir(next_dir, frames) if defined?(AutoplayBot::InputQueue)
      AutoplayBot.status(status)
      AutoplayBot.log("loop probe retry failed=#{dir_label(failed_dir)} next=#{dir_label(next_dir)} at #{position_label}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      true
    rescue => e
      AutoplayBot.log("loop probe retry failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def next_loop_recovery_dir(probe)
      loop_recovery_remaining_dirs(probe).find { |candidate| direction_passable?(candidate) }
    rescue
      nil
    end

    def loop_recovery_remaining_dirs(probe, used_dir = nil)
      dirs = probe && probe["fallback_dirs"].is_a?(Array) ? probe["fallback_dirs"].map(&:to_i) : []
      dirs = recovery_probe_dirs(probe && probe["reason"], nil, active_navigation_target_summary) if dirs.empty?
      blocked = [probe && probe["dir"], used_dir].compact.map(&:to_i)
      dirs.compact.map(&:to_i).select { |dir| [2, 4, 6, 8].include?(dir) && !blocked.include?(dir) }.uniq
    rescue
      []
    end

    def quick_recovery_hold_frames(dir = nil)
      [[movement_hold_frames([dir || 2], 6), 6].max, 16].min
    rescue
      8
    end

    def finish_loop_recovery_probe!
      probe = @loop_recovery_probe
      @loop_recovery_probe = nil
      return unless probe && defined?($game_player) && $game_player
      same_map = current_map_id.to_i == probe["map_id"].to_i
      same_tile = same_map &&
        $game_player.x.to_i == probe["x"].to_i &&
        $game_player.y.to_i == probe["y"].to_i
      if same_tile
        dir = probe["dir"].to_i
        remember_blocked_step!([probe["map_id"], probe["x"], probe["y"]], dir, "probe_failed")
        @path_cache = {}
        @active_route_plan = nil
        @decision_choice_cache = nil
        @local_discovery_cache = nil
        @last_no_path_dir = nil
        @last_route_dir = nil if @last_route_dir.to_i == dir
        @trying_to_move = false
        @stuck_frames = 0
        AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
        AutoplayBot.status("probe failed: avoid #{dir_label(dir)}")
        AutoplayBot.log("loop probe failed dir=#{dir_label(dir)} reason=#{probe["reason"]} at #{position_label}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      else
        @stuck_frames = 0
      end
    rescue => e
      AutoplayBot.log("loop recovery finish failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    end

    def remember_position
      return unless defined?($game_player) && $game_player
      if busy_for_stuck_tracking?
        @stuck_frames = 0
        @trying_to_move = false
        @last_pos = [current_map_id, $game_player.x, $game_player.y]
        return
      end
      pos = [current_map_id, $game_player.x, $game_player.y]
      frame = (Graphics.frame_count rescue 0).to_i
      observe_tile_timing(pos, frame)
      if @trying_to_move && @last_pos == pos
        @stuck_frames = @stuck_frames.to_i + 1
        remember_blocked_step!(pos, @last_route_dir, "stuck") if @stuck_frames == 45 && @last_route_dir
      else
        @stuck_frames = 0
      end
      @last_pos = pos
      track_position_loop(pos)
      if @stuck_frames > stuck_frame_limit
        if recovering_from_blackout?
          AutoplayBot.log("blackout recovery unstuck at map #{pos[0]} x#{pos[1]} y#{pos[2]}") if AutoplayBot.respond_to?(:log)
          @active_transfer = nil
          @trying_to_move = false
          @stuck_frames = 0
          return
        end
        handle_navigation_loop("stuck", pos)
        @stuck_frames = 0
      end
    rescue
      nil
    end

    def observe_tile_timing(pos, frame = nil)
      return unless pos
      frame = (Graphics.frame_count rescue 0).to_i if frame.nil?
      previous = @last_observed_tile_pos
      previous_frame = @last_observed_tile_frame
      if previous && previous_frame &&
         previous[0].to_i == pos[0].to_i &&
         (previous[1].to_i - pos[1].to_i).abs + (previous[2].to_i - pos[2].to_i).abs == 1
        delta = frame.to_i - previous_frame.to_i
        if delta >= 2 && delta <= 30
          @observed_tile_frames = @observed_tile_frames ?
            ((@observed_tile_frames.to_f * 3.0) + delta.to_f) / 4.0 :
            delta.to_f
        end
      end
      if !previous || previous[0].to_i != pos[0].to_i ||
         previous[1].to_i != pos[1].to_i || previous[2].to_i != pos[2].to_i
        @last_observed_tile_pos = pos
        @last_observed_tile_frame = frame.to_i
      end
    rescue
      nil
    end

    def stuck_frame_limit
      target = active_navigation_target_summary
      kind = target && target["kind"].to_s
      key = target && target["key"].to_s
      return OPTIONAL_STUCK_FRAME_LIMIT if ["item", "npc", "building", "transfer", "resource"].include?(kind)
      return STORY_STUCK_FRAME_LIMIT if kind == "route" || key =~ /oak|rival|starter|route|exit|leave|forest|brock|gym|mart/i
      objective = defined?(AutoplayBot::State) ? AutoplayBot::State.current_objective : nil
      type = objective && objective["type"].to_s
      return STORY_STUCK_FRAME_LIMIT if ["story", "battle"].include?(type)
      ROUTE_STUCK_FRAME_LIMIT
    rescue
      ROUTE_STUCK_FRAME_LIMIT
    end

    def track_position_loop(pos)
      return unless pos && @trying_to_move
      @position_history ||= []
      last = @position_history[-1]
      @position_history << pos if last != pos
      @position_history.shift while @position_history.length > 12
      return if @position_history.length < 6
      if ping_pong_loop?(@position_history.last(6))
        handle_navigation_loop("pingpong", pos)
        @position_history.clear
        return
      end
      axis_reason = axis_oscillation_loop_reason(@position_history.last(AXIS_LOOP_WINDOW))
      if axis_reason
        handle_navigation_loop(axis_reason, pos)
        @position_history.clear
        return
      end
      return if @position_history.length < 8
      recent = @position_history.last(8)
      unique = recent.uniq
      return unless unique.length <= 3
      handle_navigation_loop("loop", pos)
      @position_history.clear
    rescue
      nil
    end

    def ping_pong_loop?(recent)
      return false unless recent && recent.length >= 6
      a = recent[-1]
      b = recent[-2]
      return false if a == b
      recent[-3] == a && recent[-4] == b && recent[-5] == a && recent[-6] == b
    rescue
      false
    end

    def axis_oscillation_loop_reason(recent)
      return nil unless recent && recent.length >= 8
      same_map = recent.all? { |entry| entry && entry[0].to_i == recent[0][0].to_i }
      return nil unless same_map
      xs = recent.map { |entry| entry[1].to_i }
      ys = recent.map { |entry| entry[2].to_i }
      horizontal = ys.uniq.length == 1 && (xs.max - xs.min) <= AXIS_LOOP_MAX_SPAN
      vertical = xs.uniq.length == 1 && (ys.max - ys.min) <= AXIS_LOOP_MAX_SPAN
      return nil unless horizontal || vertical
      dirs = movement_dirs_for_positions(recent)
      if horizontal
        return nil unless dirs.include?(4) && dirs.include?(6)
        turns = direction_turn_count(dirs)
        net = (xs[-1] - xs[0]).abs
        return nil if turns < 2 && net > 1
        return nil if net > 2 && turns < 3
        return "horizontal_loop"
      end
      return nil unless dirs.include?(2) && dirs.include?(8)
      turns = direction_turn_count(dirs)
      net = (ys[-1] - ys[0]).abs
      return nil if turns < 2 && net > 1
      return nil if net > 2 && turns < 3
      "vertical_loop"
    rescue
      nil
    end

    def movement_dirs_for_positions(positions)
      dirs = []
      positions.each_cons(2) do |a, b|
        next unless a && b && a[0].to_i == b[0].to_i
        dx = b[1].to_i - a[1].to_i
        dy = b[2].to_i - a[2].to_i
        dirs << 6 if dx > 0 && dy == 0
        dirs << 4 if dx < 0 && dy == 0
        dirs << 2 if dy > 0 && dx == 0
        dirs << 8 if dy < 0 && dx == 0
      end
      dirs
    rescue
      []
    end

    def direction_turn_count(dirs)
      turns = 0
      last = nil
      dirs.each do |dir|
        turns += 1 if last && dir.to_i != last.to_i
        last = dir
      end
      turns
    rescue
      0
    end

    def handle_navigation_loop(reason, pos = nil)
      frame = (Graphics.frame_count rescue 0).to_i
      @last_loop_frame = -9999 if @last_loop_frame.nil?
      return if frame - @last_loop_frame.to_i < navigation_loop_cooldown_frames(reason)
      @last_loop_frame = frame
      pos ||= defined?($game_player) && $game_player ? [current_map_id, $game_player.x, $game_player.y] : [current_map_id, nil, nil]
      return if handle_brock_navigation_loop(reason, pos)
      return if handle_viridian_mart_exit_loop(reason, pos)
      return if handle_live_route_blocker(reason, pos)
      remember_blocked_step!(pos, @last_route_dir || @last_no_path_dir, reason)
      remember_recent_loop_edges!(reason)
      signature = navigation_loop_signature(reason, pos)
      target_summary = active_navigation_target_summary
      AutoplayBot::State.record_stuck_signature(signature, reason, target_summary) if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:record_stuck_signature)
      if starter_target_summary?(target_summary)
        retarget_starter_ball_after_loop(reason)
        return
      end
      quick_recovery_reason = ["pingpong", "loop", "horizontal_loop", "vertical_loop"].include?(reason.to_s)
      unless quick_recovery_reason
        cool_down_active_navigation_target(reason)
        mark_active_navigation_target_failed(reason)
      end
      @path_cache = {}
      @pending_activation = nil
      @pending_forest_forage_activation = nil
      @forest_forage_attempt = nil
      @local_discovery_cache = nil
      @active_decision_goal = nil
      @decision_choice_cache = nil
      @active_route_plan = nil
      @trying_to_move = false
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      if ["pingpong", "loop", "horizontal_loop", "vertical_loop"].include?(reason.to_s)
        return if route_axis_probe(reason, pos, target_summary)
        return if route_vertical_probe(reason, pos, target_summary)
        cool_down_active_navigation_target(reason)
        mark_active_navigation_target_failed(reason)
        @last_no_path_dir = nil
        @loop_recovery_until_frame = frame + 18
        @loop_recovery_status = "loop: replan #{short_text_for_status(target_summary["key"], 28)}"
        AutoplayBot.status(@loop_recovery_status)
        AutoplayBot.log("navigation #{reason} replanning target=#{target_summary["key"]} at #{position_label}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
        return
      end
      return if reason.to_s == "stuck" && route_vertical_probe(reason, pos, target_summary)
      escape_dir = navigation_escape_direction(pos, target_summary)
      if escape_dir && defined?(AutoplayBot::InputQueue)
        @trying_to_move = true
        @last_no_path_dir = escape_dir
        status = "route: avoid #{dir_label(escape_dir)}"
        dirs = recovery_probe_dirs(reason, pos, target_summary)
        frames = quick_recovery_hold_frames(escape_dir)
        start_loop_recovery_probe!(escape_dir, status, frames, reason, dirs - [escape_dir])
        AutoplayBot::InputQueue.hold_dir(escape_dir, frames)
        AutoplayBot.status("route: avoid #{dir_label(escape_dir)}")
      else
        @loop_recovery_until_frame = frame + 18
        @loop_recovery_status = "route: #{reason} flagged"
        AutoplayBot.status("route: #{reason} flagged")
      end
      AutoplayBot.log("navigation #{reason} flagged at #{position_label}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    rescue => e
      AutoplayBot.log("loop handler failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    end

    def remember_recent_loop_edges!(reason = "loop")
      return unless ["pingpong", "loop", "horizontal_loop", "vertical_loop"].include?(reason.to_s)
      recent = (@position_history || []).last(AXIS_LOOP_WINDOW)
      return unless recent && recent.length >= 2
      recent.each_cons(2) do |a, b|
        next unless a && b && a[0].to_i == b[0].to_i
        dir = direction_between_positions(a, b)
        next unless dir
        remember_loop_edge_step!(a, dir)
        remember_loop_edge_step!(b, reverse_dir(dir))
      end
    rescue
      nil
    end

    def remember_loop_edge_step!(pos = nil, dir = nil)
      return unless pos && dir
      dir = dir.to_i
      return unless [2, 4, 6, 8].include?(dir)
      map_id = pos[0].to_i
      x = pos[1].to_i
      y = pos[2].to_i
      key = blocked_step_key(map_id, x, y, dir)
      @blocked_step_memory ||= {}
      frame = (Graphics.frame_count rescue 0).to_i
      entry = @blocked_step_memory[key] ||= { "count" => 0 }
      entry["count"] = entry["count"].to_i + 1
      entry["reason"] = "loop_edge"
      entry["until"] = frame + blocked_step_ttl_frames("loop_edge", entry["count"])
      @blocked_step_version = @blocked_step_version.to_i + 1
      @path_cache = {}
      @active_route_plan = nil
    rescue
      nil
    end

    def direction_between_positions(a, b)
      dx = b[1].to_i - a[1].to_i
      dy = b[2].to_i - a[2].to_i
      return 6 if dx == 1 && dy == 0
      return 4 if dx == -1 && dy == 0
      return 2 if dy == 1 && dx == 0
      return 8 if dy == -1 && dx == 0
      nil
    rescue
      nil
    end

    def reverse_dir(dir)
      { 2 => 8, 8 => 2, 4 => 6, 6 => 4 }[dir.to_i]
    rescue
      nil
    end

    def route_axis_probe(reason, pos = nil, target = nil)
      return false unless defined?(AutoplayBot::InputQueue) && defined?($game_player) && $game_player
      dirs = axis_probe_dirs(reason, pos, target)
      dir = dirs.find { |candidate| direction_passable?(candidate) }
      return false unless dir
      @trying_to_move = true
      @last_no_path_dir = dir
      @last_route_dir = dir
      frames = quick_recovery_hold_frames(dir)
      start_loop_recovery_probe!(dir, "break #{reason}: #{dir_label(dir)}", frames, reason, dirs - [dir])
      AutoplayBot::InputQueue.clear
      AutoplayBot::InputQueue.hold_dir(dir, frames)
      AutoplayBot.status(@loop_recovery_status)
      AutoplayBot.log("axis loop probe #{reason} #{dir_label(dir)} at #{position_label}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      true
    rescue => e
      AutoplayBot.log("axis loop probe failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def start_loop_recovery_probe!(dir, status, frames, reason = nil, fallback_dirs = nil)
      frame = (Graphics.frame_count rescue 0).to_i
      @loop_recovery_until_frame = frame + [frames.to_i, 1].max
      @loop_recovery_status = status.to_s
      if defined?($game_player) && $game_player
        @loop_recovery_probe = {
          "map_id" => current_map_id,
          "x" => $game_player.x,
          "y" => $game_player.y,
          "dir" => dir.to_i,
          "reason" => reason.to_s,
          "frame" => frame,
          "fallback_dirs" => (fallback_dirs || []).map(&:to_i).select { |candidate| [2, 4, 6, 8].include?(candidate.to_i) && candidate.to_i != dir.to_i }.uniq
        }
      end
    rescue
      nil
    end

    def axis_probe_dirs(reason, pos = nil, target = nil)
      recovery_probe_dirs(reason, pos, target)
    rescue
      [8, 6, 4, 2]
    end

    def recovery_probe_dirs(reason, pos = nil, target = nil)
      pos ||= defined?($game_player) && $game_player ? [current_map_id, $game_player.x, $game_player.y] : [current_map_id, 0, 0]
      target ||= active_navigation_target_summary
      if reason.to_s == "horizontal_loop"
        vertical = vertical_probe_dirs(pos, target)
        target_x = target && target["x"]
        horizontal = if target_x && target_x.to_i != pos[1].to_i
                       target_x.to_i < pos[1].to_i ? [4, 6] : [6, 4]
                     else
                       [6, 4]
                     end
        primary_vertical = vertical.first
        other_vertical = vertical[1] || reverse_dir(primary_vertical)
        return ([primary_vertical] + horizontal + [other_vertical, 2, 8, 6, 4]).compact.uniq
      elsif reason.to_s == "vertical_loop"
        target_x = target && target["x"]
        horizontal = if target_x && target_x.to_i != pos[1].to_i
                       target_x.to_i < pos[1].to_i ? [4, 6] : [6, 4]
                     else
                       [6, 4]
                     end
        vertical = vertical_probe_dirs(pos, target)
        return (horizontal + vertical + [2, 8, 6, 4]).uniq
      end
      target_x = target && target["x"]
      horizontal = if target_x && target_x.to_i != pos[1].to_i
                     target_x.to_i < pos[1].to_i ? [4, 6] : [6, 4]
                   else
                     [6, 4]
                   end
      (vertical_probe_dirs(pos, target) + horizontal + [2, 8, 6, 4]).uniq
    rescue
      [8, 6, 4, 2]
    end

    def route_vertical_probe(reason, pos = nil, target = nil)
      return false unless defined?(AutoplayBot::InputQueue) && defined?($game_player) && $game_player
      dirs = recovery_probe_dirs(reason, pos, target)
      dir = dirs.find { |candidate| direction_passable?(candidate) }
      return false unless dir
      @trying_to_move = true
      @last_no_path_dir = dir
      @last_route_dir = dir
      frames = quick_recovery_hold_frames(dir)
      start_loop_recovery_probe!(dir, "probe #{dir_label(dir)} after #{reason}", frames, reason, dirs - [dir])
      AutoplayBot::InputQueue.clear
      AutoplayBot::InputQueue.hold_dir(dir, frames)
      AutoplayBot.status(@loop_recovery_status)
      AutoplayBot.log("route probe #{dir_label(dir)} after #{reason} at #{position_label}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      true
    rescue => e
      AutoplayBot.log("route vertical probe failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def vertical_probe_dirs(pos = nil, target = nil)
      pos ||= defined?($game_player) && $game_player ? [current_map_id, $game_player.x, $game_player.y] : [current_map_id, 0, 0]
      target ||= active_navigation_target_summary
      target_y = target && target["y"]
      vertical = if target_y && target_y.to_i != pos[2].to_i
                   target_y.to_i < pos[2].to_i ? [8, 2] : [2, 8]
                 else
                   [8, 2]
                 end
      horizontal = [4, 6]
      horizontal.reverse! if @last_route_dir.to_i == 4
      (vertical + horizontal + [8, 2, 4, 6]).uniq
    rescue
      [8, 2, 4, 6]
    end

    def navigation_loop_cooldown_frames(reason)
      case reason.to_s
      when "pingpong" then 48
      when "horizontal_loop", "vertical_loop" then 36
      when "loop" then 72
      else 96
      end
    rescue
      96
    end

    def starter_target_summary?(summary)
      return false unless OAK_LAB_MAP_IDS.include?(current_map_id.to_i)
      text = [
        summary && summary["kind"],
        summary && summary["key"],
        summary && summary["name"]
      ].compact.join(" ")
      text =~ /starter[_\s-]*ball|choose starter|starter pokemon/i
    rescue
      false
    end

    def retarget_starter_ball_after_loop(reason = "loop")
      frame = (Graphics.frame_count rescue 0).to_i
      @starter_ball_choice_key = nil
      clear_navigation_context!("starter #{reason}", true)
      @loop_recovery_until_frame = frame + 18
      @loop_recovery_status = "starter: rechoose"
      AutoplayBot.status(@loop_recovery_status) if defined?(AutoplayBot)
      AutoplayBot.log("starter target #{reason}; reselecting from #{position_label}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    rescue
      nil
    end

    def handle_live_route_blocker(reason, pos = nil)
      return false unless ["pingpong", "loop", "stuck"].include?(reason.to_s)
      route_blocker_probe_dirs(pos).each do |dir|
        return true if try_interact_with_live_route_blocker(dir, reason)
      end
      false
    rescue => e
      AutoplayBot.log("route blocker check failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def route_blocker_probe_dirs(pos = nil)
      dirs = []
      dirs << @last_route_dir
      dirs << @last_no_path_dir
      dirs << ($game_player.direction if defined?($game_player) && $game_player && $game_player.respond_to?(:direction))
      target = active_navigation_target_summary
      if target && target["x"] && target["y"] && pos
        dirs << axis_direction_from_to(pos[1], pos[2], target["x"], target["y"])
      end
      dirs += [8, 6, 4, 2]
      dirs.compact.map(&:to_i).select { |dir| [2, 4, 6, 8].include?(dir) }.uniq
    rescue
      [8, 6, 4, 2]
    end

    def axis_direction_from_to(from_x, from_y, to_x, to_y)
      dx = to_x.to_i - from_x.to_i
      dy = to_y.to_i - from_y.to_i
      return (dy > 0 ? 2 : 8) if dy != 0 && dy.abs >= dx.abs
      return (dx > 0 ? 6 : 4) if dx != 0
      return (dy > 0 ? 2 : 8) if dy != 0
      nil
    rescue
      nil
    end

    def try_interact_with_live_route_blocker(dir, reason = "blocked")
      event = live_route_blocker_in_direction(dir)
      return false unless event
      record = live_event_record(event, "npc")
      return false unless record
      key = activation_key(record)
      return false if activation_on_cooldown?(key)

      frame = (Graphics.frame_count rescue 0).to_i
      @path_cache = {}
      @pending_activation = nil
      @pending_forest_forage_activation = nil
      @forest_forage_attempt = nil
      @local_discovery_cache = nil
      @active_decision_goal = nil
      @decision_choice_cache = nil
      @active_route_plan = nil
      @active_event_target = record
      @trying_to_move = false
      @activation_cooldowns ||= {}
      @activation_cooldowns[key.to_s] = frame + 90
      mark_event_target_attempted(record)
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      if defined?(AutoplayBot::InputQueue)
        AutoplayBot::InputQueue.hold_dir(dir, 2)
        if AutoplayBot::InputQueue.respond_to?(:tap_next)
          AutoplayBot::InputQueue.tap_next(:USE, 2)
        else
          AutoplayBot::InputQueue.tap(:USE, 1)
        end
      end
      @loop_recovery_until_frame = frame + 18
      @loop_recovery_status = "route blocker: #{short_target_label(record)}"
      AutoplayBot.status(@loop_recovery_status)
      AutoplayBot.log("route blocker #{reason} dir=#{dir} event=#{record["event_id"] || record["event_name"]} at #{position_label}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      true
    rescue => e
      AutoplayBot.log("route blocker activation failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def live_route_blocker_in_direction(dir)
      return nil unless defined?($game_player) && $game_player
      dx, dy = direction_delta(dir)
      return nil if dx.to_i == 0 && dy.to_i == 0
      live_blocking_events_at($game_player.x.to_i + dx.to_i, $game_player.y.to_i + dy.to_i).find do |event|
        live_event_interactable?(event)
      end
    rescue
      nil
    end

    def live_blocking_events_at(x, y)
      return [] unless defined?($game_map) && $game_map && $game_map.respond_to?(:events) && $game_map.events
      events = $game_map.events
      values = events.respond_to?(:values) ? events.values : events
      values.compact.select do |event|
        live_event_blocks_route?(event) &&
          event.respond_to?(:x) && event.respond_to?(:y) &&
          event.x.to_i == x.to_i && event.y.to_i == y.to_i
      end
    rescue
      []
    end

    def live_event_interactable?(event)
      return false unless live_event_blocks_route?(event)
      return false if live_event_follower?(event)
      trigger = live_event_trigger(event)
      return false if trigger == 1
      return false if [3, 4].include?(trigger) && !live_event_personish?(event)
      live_event_personish?(event)
    rescue
      false
    end

    def live_event_personish?(event)
      name = live_event_name(event)
      graphic = live_event_graphic_name(event)
      text = "#{name} #{graphic}"
      return false if text =~ /door|warp|transfer|entrance|exit|sign|outdoorlight|object|item|ball|rock|tree|cut|surf|ledge|mart|center|gym|pc/i
      return true if text =~ /trainer|rival|blue|gary|leader|brock|oak|professor|mom|nurse|clerk|rocket|grunt|lass|hiker|bug|fisher|kid|boy|girl|man|woman|elder|kurt|npc/i
      return true if graphic =~ /\ABW\s*\(|\ABW(?:Boy|Girl|Man|Woman)/i
      false
    rescue
      false
    end

    def live_event_follower?(event)
      return false unless event
      text = [
        event.class.to_s,
        live_event_name(event),
        live_event_graphic_name(event)
      ].join(" ")
      return true if text =~ /follow|follower|following|dependent|companion|partner/i
      return true if event.instance_variable_defined?(:@dependent_event)
      return true if event.instance_variable_defined?(:@follower)
      return true if event.instance_variable_defined?(:@following)
      return true if event.instance_variable_defined?(:@is_follower)
      pokemon_global_dependent_event?(event)
    rescue
      false
    end

    def pokemon_global_dependent_event?(event)
      return false unless defined?($PokemonGlobal) && $PokemonGlobal
      containers = []
      [:dependentEvents, :dependent_events, :followers].each do |name|
        containers << $PokemonGlobal.send(name) if $PokemonGlobal.respond_to?(name)
      end
      containers.compact.any? { |container| dependent_container_has_event?(container, event) }
    rescue
      false
    end

    def dependent_container_has_event?(container, event)
      return false unless container
      return true if container.equal?(event)
      return true if container.respond_to?(:include?) && container.include?(event)
      if container.respond_to?(:realEvents)
        real = container.realEvents
        return true if real.respond_to?(:include?) && real.include?(event)
      end
      if container.respond_to?(:each)
        container.each do |entry|
          return true if entry.equal?(event)
          return true if entry.respond_to?(:event) && entry.event.equal?(event)
          return true if entry.respond_to?(:character) && entry.character.equal?(event)
        end
      end
      false
    rescue
      false
    end

    def live_event_blocks_route?(event)
      return false unless event
      return false if live_event_erased?(event)
      return false if live_event_through?(event)
      true
    rescue
      false
    end

    def live_event_erased?(event)
      return event.erased? if event.respond_to?(:erased?)
      return event.instance_variable_get(:@erased) == true if event.instance_variable_defined?(:@erased)
      false
    rescue
      false
    end

    def live_event_through?(event)
      return event.through == true if event.respond_to?(:through)
      return event.instance_variable_get(:@through) == true if event.instance_variable_defined?(:@through)
      false
    rescue
      false
    end

    def live_event_trigger(event)
      return event.trigger.to_i if event.respond_to?(:trigger)
      return event.instance_variable_get(:@trigger).to_i if event.instance_variable_defined?(:@trigger)
      0
    rescue
      0
    end

    def live_event_id(event)
      return event.id if event.respond_to?(:id)
      return event.instance_variable_get(:@id) if event.instance_variable_defined?(:@id)
      nil
    rescue
      nil
    end

    def live_event_graphic_name(event)
      return event.character_name.to_s if event.respond_to?(:character_name)
      return event.instance_variable_get(:@character_name).to_s if event.instance_variable_defined?(:@character_name)
      ""
    rescue
      ""
    end

    def live_event_name(event)
      return event.name.to_s if event.respond_to?(:name)
      source = event.instance_variable_get(:@event) if event.instance_variable_defined?(:@event)
      return source.name.to_s if source && source.respond_to?(:name)
      ""
    rescue
      ""
    end

    def live_event_record(event, kind = "event")
      return nil unless event && event.respond_to?(:x) && event.respond_to?(:y)
      event_id = live_event_id(event)
      x = event.x.to_i
      y = event.y.to_i
      name = live_event_name(event)
      name = "Event #{event_id || "#{x},#{y}"}" if name.to_s.empty?
      key = "live:#{current_map_id}:#{event_id || "#{x}:#{y}"}"
      record = {
        "key" => key,
        "map_id" => current_map_id,
        "event_id" => event_id,
        "event_name" => name,
        "x" => x,
        "y" => y,
        "trigger" => live_event_trigger(event),
        "graphic" => live_event_graphic_name(event)
      }
      kind = kind.to_s
      unless kind.empty?
        record["frontier_kind"] = kind
        record["frontier_key"] = "#{kind}:#{current_map_id}:#{event_id || "#{x}:#{y}"}"
      end
      record
    rescue
      nil
    end

    def handle_brock_navigation_loop(reason, pos = nil)
      return false unless current_map_id.to_i == PEWTER_GYM_MAP_ID
      return false if first_badge_obtained?
      return false unless ["pingpong", "loop", "stuck"].include?(reason.to_s)
      event = brock_event_target
      objective = defined?(AutoplayBot::State) ? AutoplayBot::State.current_objective : nil
      return false unless near_record_position?(pos, event, 6) || brock_objective?(objective)
      @path_cache = {}
      @pending_activation = nil
      @active_decision_goal = nil
      @decision_choice_cache = nil
      @active_route_plan = nil
      @active_event_target = event
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)

      path = path_to_event_action(event, adaptive_budget(1400, "brock"))
      if path && path.empty?
        AutoplayBot.status("brock: talk")
        face_or_use_transfer(event)
      elsif path && !path.empty?
        @trying_to_move = true
        AutoplayBot.status(path_status("brock route", path, path.first))
        AutoplayBot::InputQueue.hold_dir(path.first, movement_hold_frames(path)) if defined?(AutoplayBot::InputQueue)
      else
        @trying_to_move = true
        AutoplayBot.status("brock: recover path")
        direct_step_toward(event["action_x"].to_i, event["action_y"].to_i, "brock approach", 900, false)
      end
      AutoplayBot.log("brock #{reason} retarget at #{position_label}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      true
    rescue => e
      AutoplayBot.log("brock loop recovery failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def near_record_position?(pos, record, distance = 4)
      return false unless pos && record
      px = pos[1].to_i
      py = pos[2].to_i
      rx = record["x"].to_i
      ry = record["y"].to_i
      ((px - rx).abs + (py - ry).abs) <= distance.to_i
    rescue
      false
    end

    def navigation_escape_direction(pos = nil, target = nil)
      return nil unless defined?($game_player) && $game_player
      pos ||= [current_map_id, $game_player.x, $game_player.y]
      target ||= active_navigation_target_summary
      target_x = target["x"]
      target_y = target["y"]
      reverse = { 2 => 8, 8 => 2, 4 => 6, 6 => 4 }[@last_no_path_dir.to_i]
      candidates = [2, 4, 6, 8].select { |dir| direction_passable?(dir) }
      return nil if candidates.empty?
      candidates.sort_by do |dir|
        nx = pos[1].to_i + (dir == 6 ? 1 : dir == 4 ? -1 : 0)
        ny = pos[2].to_i + (dir == 2 ? 1 : dir == 8 ? -1 : 0)
        visits = (@position_history || []).count { |entry| entry[0].to_i == pos[0].to_i && entry[1].to_i == nx && entry[2].to_i == ny }
        target_distance = target_x && target_y ? (target_x.to_i - nx).abs + (target_y.to_i - ny).abs : 0
        [visits, dir == reverse ? 1 : 0, target_distance]
      end.first
    rescue
      nil
    end

    def cool_down_active_navigation_target(reason)
      record = @active_forest_forage || @active_forest_npc || @active_transfer || @active_event_target
      if !record && @active_decision_goal && @active_decision_goal["record"].is_a?(Hash)
        record = @active_decision_goal["record"]
      end
      target = @local_discovery_cache && @local_discovery_cache["target"]
      record ||= target["record"] if target.is_a?(Hash) && target["record"].is_a?(Hash)
      return unless record.is_a?(Hash)
      kind = record["frontier_kind"] || record["kind"] || (target && target["kind"]) || "target"
      key = target_cooldown_key(kind, record)
      frames = if story_critical_navigation_target?(record, kind)
                 36
               elsif ["horizontal_loop", "vertical_loop"].include?(reason.to_s)
                 60
               else
                 reason.to_s == "pingpong" ? 420 : 300
               end
      cool_down_target(key, frames)
    rescue
      nil
    end

    def story_critical_navigation_target?(record, kind = nil)
      objective = defined?(AutoplayBot::State) ? AutoplayBot::State.current_objective : nil
      objective_type = objective && objective["type"].to_s
      objective_label = objective && [objective["id"], objective["label"]].compact.join(" ")
      text = [
        kind,
        record && record["frontier_kind"],
        record && record["kind"],
        record && record["key"],
        record && record["event_name"],
        record && record["destination_name"],
        objective_label
      ].compact.join(" ")
      return true if ["story", "travel", "battle", "recovery"].include?(objective_type) &&
        text =~ /mart|route|exit|gate|forest|gym|center|oak|rival|brock|lab|stairs|house/i
      false
    rescue
      false
    end

    def navigation_loop_signature(reason, pos)
      target = active_navigation_target_summary
      [
        reason,
        pos[0],
        pos[1],
        pos[2],
        target["kind"],
        target["key"]
      ].compact.map(&:to_s).join(":")
    rescue
      "loop:#{current_map_id}"
    end

    def active_navigation_target_summary
      record = @active_forest_forage || @active_forest_npc || @active_transfer || @active_event_target
      record ||= @local_discovery_cache["target"]["record"] if @local_discovery_cache && @local_discovery_cache["target"].is_a?(Hash)
      record ||= @active_route_target if @active_route_target.is_a?(Hash)
      return { "kind" => "route", "key" => AutoplayBot.status_message } unless record.is_a?(Hash)
      {
        "kind" => record["frontier_kind"] || record["kind"] || "target",
        "key" => record["frontier_key"] || record["key"] || record["event_id"] || "#{record["x"]},#{record["y"]}",
        "map_id" => record["map_id"] || current_map_id,
        "x" => record["x"],
        "y" => record["y"],
        "name" => record["event_name"]
      }
    rescue
      { "kind" => "route", "key" => "unknown" }
    end

    def debug_overlay_lines
      target = active_navigation_target_summary
      lines = []
      if target && target["key"] && target["key"].to_s != AutoplayBot.status_message.to_s
        pieces = []
        pieces << "#{target["kind"]}:#{target["key"]}"
        pieces << "@#{target["x"]},#{target["y"]}" if target["x"] && target["y"]
        pieces << "dir #{dir_label(@last_route_dir)}" if @last_route_dir
        lines << "Target #{short_text_for_status(pieces.compact.join(" "), 58)}"
      end
      if @trying_to_move && @stuck_frames.to_i > 20
        lines << "Progress stuck #{@stuck_frames.to_i}/#{stuck_frame_limit}"
      end
      blocked = current_blocked_step_labels
      lines << "Avoid step #{blocked.join(", ")}" unless blocked.empty?
      if @loop_recovery_status && @loop_recovery_until_frame &&
         (Graphics.frame_count rescue 0).to_i < @loop_recovery_until_frame.to_i
        lines << "Recover #{short_text_for_status(@loop_recovery_status, 58)}"
      end
      if route_recalc_explore_active?
        left = [((@route_recalc_explore_until_frame.to_i - (Graphics.frame_count rescue 0).to_i) / 60), 1].max
        label = @route_recalc_reason.to_s.empty? ? "route" : @route_recalc_reason
        lines << "Recalc #{short_text_for_status(label, 34)} #{left}s"
      end
      lines
    rescue
      []
    end

    def current_blocked_step_labels
      return [] unless defined?($game_player) && $game_player
      purge_blocked_step_memory
      [2, 4, 6, 8].select do |dir|
        pathfinder_blocked_step?(current_map_id, $game_player.x, $game_player.y, dir)
      end.map { |dir| dir_label(dir) }
    rescue
      []
    end

    def short_text_for_status(text, max = 46)
      value = text.to_s.gsub(/\s+/, " ").strip
      return value if value.length <= max.to_i
      "#{value[0, [max.to_i - 3, 1].max]}..."
    rescue
      text.to_s
    end

    def mark_active_navigation_target_failed(reason)
      if @active_forest_forage
        skip_forest_forage_target(@active_forest_forage, reason)
        return
      end
      if @active_forest_npc
        AutoplayBot::State.mark_target_failed(@active_forest_npc, "navigation #{reason}", "npc") if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:mark_target_failed)
        @active_forest_npc = nil
        return
      end
      if @active_transfer
        kind = record_frontier_kind(@active_transfer, building_transfer?(@active_transfer) ? "building" : "transfer")
        if optional_interaction_target?(@active_transfer, kind)
          AutoplayBot::State.mark_target_failed(@active_transfer, "navigation #{reason}", kind) if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:mark_target_failed)
        end
        @active_transfer = nil
        return
      end
      if @active_event_target
        kind = record_frontier_kind(@active_event_target, "event")
        if optional_interaction_target?(@active_event_target, kind)
          AutoplayBot::State.mark_target_failed(@active_event_target, "navigation #{reason}", kind) if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:mark_target_failed)
        end
        @active_event_target = nil
        return
      end
      if @active_decision_goal && @active_decision_goal["record"].is_a?(Hash)
        kind = @active_decision_goal["kind"].to_s.empty? ? "target" : @active_decision_goal["kind"].to_s
        AutoplayBot::State.mark_target_failed(@active_decision_goal["record"], "navigation #{reason}", kind) if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:mark_target_failed)
        @active_decision_goal = nil
        @decision_choice_cache = nil
        @active_route_plan = nil
        return
      end
      target = @local_discovery_cache && @local_discovery_cache["target"]
      if target.is_a?(Hash) && target["record"].is_a?(Hash)
        kind = target["kind"].to_s.empty? ? "target" : target["kind"].to_s
        AutoplayBot::State.mark_target_failed(target["record"], "navigation #{reason}", kind) if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:mark_target_failed)
      end
    rescue
      nil
    end

    def busy_for_stuck_tracking?
      return true if message_showing?
      if defined?($game_temp) && $game_temp
        return true if $game_temp.in_battle || $game_temp.in_menu
        return true if $game_temp.player_transferring || $game_temp.transition_processing || $game_temp.to_title
      end
      return true if forced_map_activity?
      if Object.new.respond_to?(:pbMapInterpreterRunning?, true) && Object.new.send(:pbMapInterpreterRunning?)
        return true
      end
      false
    rescue
      false
    end

    def blackout_recovery_tick
      return false unless recovering_from_blackout?
      return false unless on_map?
      @blackout_recovery["phase"] = "returning"

      if player_room_map?(current_map_id)
        set_objective("blackout_leave_bedroom", "travel", "Recover from blackout")
        transfer = room_to_house_transfer || fallback_room_to_house_transfer
        @active_transfer = transfer
        transfer ? navigate_to_transfer(transfer) : direct_step_toward(10, 5, "blackout: stairs")
        return true
      end

      if player_house_map?(current_map_id)
        set_objective("blackout_leave_home", "travel", "Recover from blackout")
        return true if direct_blackout_house_exit
        transfer = house_to_pallet_transfer || fallback_house_to_pallet_transfer
        @active_transfer = transfer
        transfer ? navigate_to_transfer(transfer) : direct_step_toward(7, 10, "blackout: house exit")
        return true
      end

      return_map = @blackout_recovery["return_map"].to_i
      if return_map > 0 && current_map_id.to_i != return_map
        finish_blackout_recovery!
        return false
      end

      if story_navigation_map?(current_map_id)
        finish_blackout_recovery!
        return false
      end

      transfer = recovery_exit_transfer
      if transfer
        set_objective("blackout_exit_#{current_map_id}", "travel", "Recover from blackout")
        @active_transfer = transfer
        AutoplayBot.status("blackout: exit #{transfer_label(transfer)}") if defined?(AutoplayBot)
        navigate_to_transfer(transfer)
        return true
      end

      finish_blackout_recovery!
      false
    rescue => e
      AutoplayBot.log("blackout recovery tick failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      finish_blackout_recovery!
      false
    end

    def direct_blackout_house_exit
      return false unless [PALLET_RESPAWN_HOUSE_MAP_ID, PLAYER_HOUSE_MAP_ID].include?(current_map_id.to_i)
      return false unless defined?($game_player) && $game_player
      @active_transfer = fallback_house_to_pallet_transfer
      x = $game_player.x.to_i
      y = $game_player.y.to_i
      if x == 7 && y == 10
        AutoplayBot.status("blackout: exit house")
        @trying_to_move = true
        AutoplayBot::InputQueue.hold_dir(2, movement_hold_frames([2, 2], 10))
        return true
      end

      candidates = []
      candidates << (x < 7 ? 6 : 4) if x != 7
      candidates << (y < 10 ? 2 : 8) if y != 10
      candidates += [2, 4, 6, 8]
      dir = candidates.find { |candidate| direction_passable?(candidate) } || candidates.first
      return false unless dir
      AutoplayBot.status("blackout: house exit dir #{dir}")
      @trying_to_move = true
      AutoplayBot::InputQueue.hold_dir(dir, movement_hold_frames([dir, dir], 10))
      true
    rescue => e
      AutoplayBot.log("direct blackout house exit failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def finish_blackout_recovery!
      return unless @blackout_recovery
      objective = @blackout_recovery["objective"]
      @blackout_recovery["phase"] = "done"
      @active_transfer = nil
      @trying_to_move = false
      @stuck_frames = 0
      AutoplayBot::State.current_objective = objective if defined?(AutoplayBot::State)
      AutoplayBot.status("blackout: resumed") if defined?(AutoplayBot)
      label = objective && (objective["label"] || objective["id"])
      AutoplayBot.log("blackout recovery resumed objective #{label} at #{position_label}") if AutoplayBot.respond_to?(:log)
    rescue
      nil
    end

    def restore_recent_blackout_recovery
      return nil unless defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:save_bucket)
      entries = AutoplayBot::State.save_bucket["blackouts"] rescue []
      entry = entries && entries.respond_to?(:last) ? entries.last : nil
      return nil unless entry.is_a?(Hash)
      age = Time.now.to_i - entry["time"].to_i
      return nil if age < 0 || age > 3600
      return nil unless current_map_id && current_map_id.to_i == entry["return_map"].to_i
      return nil unless player_house_map?(current_map_id) || player_room_map?(current_map_id) || !story_navigation_map?(current_map_id)
      entry.merge("phase" => "returning", "restored" => true)
    rescue
      nil
    end

    def player_house_map?(map_id)
      PLAYER_HOUSE_MAP_IDS.include?(map_id.to_i)
    rescue
      false
    end

    def player_room_map?(map_id)
      PLAYER_ROOM_MAP_IDS.include?(map_id.to_i)
    rescue
      false
    end

    def room_to_house_transfer
      transfer_to_any(PLAYER_HOUSE_MAP_IDS)
    rescue
      nil
    end

    def house_to_pallet_transfer
      transfer_to_any([PALLET_TOWN_MAP_ID])
    rescue
      nil
    end

    def transfer_to_any(destinations)
      destination_ids = destinations.compact.map(&:to_i)
      return nil if destination_ids.empty?
      map = AutoplayBot::WorldScanner.current_map_data if defined?(AutoplayBot::WorldScanner)
      transfers = map && map["transfers"].is_a?(Array) ? map["transfers"] : []
      candidates = transfers.select { |transfer| destination_ids.include?(transfer["destination_map_id"].to_i) }
      candidates.min_by do |transfer|
        distance = if defined?($game_player) && $game_player
                     (transfer["x"].to_i - $game_player.x).abs + (transfer["y"].to_i - $game_player.y).abs
                   else
                     0
                   end
        [transfer["trigger"].to_i == 1 ? 0 : 1, distance]
      end
    rescue
      nil
    end

    def fallback_room_to_house_transfer
      map_id = current_map_id.to_i
      return nil unless PLAYER_ROOM_MAP_IDS.include?(map_id)
      {
        "key" => "blackout:#{map_id}:43",
        "map_id" => map_id,
        "event_id" => 1,
        "event_name" => "Bedroom stairs",
        "x" => 10,
        "y" => 5,
        "trigger" => 1,
        "destination_map_id" => PLAYER_HOUSE_MAP_ID
      }
    rescue
      nil
    end

    def fallback_house_to_pallet_transfer
      map_id = current_map_id.to_i
      return {
        "key" => "blackout:3:42",
        "map_id" => PALLET_RESPAWN_HOUSE_MAP_ID,
        "event_id" => 1,
        "event_name" => "House exit",
        "x" => 7,
        "y" => 10,
        "trigger" => 1,
        "destination_map_id" => PALLET_TOWN_MAP_ID
      } if map_id == PALLET_RESPAWN_HOUSE_MAP_ID
      return {
        "key" => "blackout:43:42",
        "map_id" => PLAYER_HOUSE_MAP_ID,
        "event_id" => 2,
        "event_name" => "House exit",
        "x" => 7,
        "y" => 10,
        "trigger" => 1,
        "destination_map_id" => PALLET_TOWN_MAP_ID
      } if map_id == PLAYER_HOUSE_MAP_ID
      nil
    rescue
      nil
    end

    def story_navigation_map?(map_id)
      STORY_NAV_MAP_IDS.include?(map_id.to_i)
    rescue
      false
    end

    def safe_mode?
      defined?(AutoplayBot::Config) && AutoplayBot::Config.safe_mode?
    rescue
      true
    end

    def optional_cleanup_allowed?
      return true unless safe_mode?
      defined?(AutoplayBot::Config) &&
        AutoplayBot::Config.collector_heavy? &&
        AutoplayBot::Config.local_discovery? &&
        AutoplayBot::Config.frontier_explore?
    rescue
      false
    end

    def local_discovery_tick
      return false unless local_discovery_allowed_now?
      scan_world_slowly
      target = current_local_discovery_target
      return false unless target
      set_supervisor_mode("frontier_explore")
      case target["kind"]
      when "item"
        collect_item_target(target["record"])
      when "npc"
        talk_to_npc_target(target["record"])
      when "building"
        enter_building_target(target["record"])
      else
        return false
      end
      true
    rescue => e
      AutoplayBot.log("local discovery failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def local_discovery_allowed_now?
      return false unless defined?(AutoplayBot::Config) && AutoplayBot::Config.local_discovery?
      return false unless AutoplayBot::Config.frontier_explore?
      return false unless trainer_has_pokedex?
      return false if current_map_id.to_i == VIRIDIAN_FOREST_MAP_ID
      return false unless defined?($game_player) && $game_player
      return true if route_recalc_explore_active?
      true
    rescue
      false
    end

    def map_clear_enabled?
      return false unless defined?(AutoplayBot::Config)
      return false unless AutoplayBot::Config.local_discovery?
      return false if AutoplayBot::Config.autonomy_profile == "minimal"
      AutoplayBot::Config.opportunistic_map_clear? || AutoplayBot::Config.map_clear_policy == "clear_before_leave"
    rescue
      false
    end

    def clear_before_leave?
      defined?(AutoplayBot::Config) && AutoplayBot::Config.map_clear_policy == "clear_before_leave"
    rescue
      false
    end

    def update_map_knowledge_tick
      return unless map_clear_enabled?
      return unless defined?(AutoplayBot::WorldScanner)
      return unless defined?($game_player) && $game_player
      frame = (Graphics.frame_count rescue 0).to_i
      @last_map_knowledge_frame = -9999 if @last_map_knowledge_frame.nil?
      return if frame - @last_map_knowledge_frame.to_i < map_knowledge_interval_frames
      @last_map_knowledge_frame = frame
      map = AutoplayBot::WorldScanner.current_map_data
      return unless map
      targets = map_cleanup_targets(map)
      summary_targets = []
      counts = {}
      targets.each do |entry|
        kind = entry["kind"]
        record = entry["record"].merge("map_id" => current_map_id)
        next if cleanup_target_done_or_failed?(record, kind)
        key = AutoplayBot::State.target_key(record, kind) rescue target_cooldown_key(kind, record)
        counts[kind] = counts[kind].to_i + 1
        summary_targets << { "key" => key, "kind" => kind, "record" => record }
        AutoplayBot::State.enqueue_cleanup_target(record, kind, cleanup_priority_for(kind, record), "map scan") if AutoplayBot::State.respond_to?(:enqueue_cleanup_target)
      end
      AutoplayBot::State.record_map_knowledge(current_map_id, {
        "name" => (map["name"] || (AutoplayBot::WorldScanner.map_name(current_map_id) rescue "")),
        "counts" => counts,
        "targets" => summary_targets
      }) if AutoplayBot::State.respond_to?(:record_map_knowledge)
    rescue => e
      AutoplayBot.log("map knowledge tick failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    end

    def map_knowledge_interval_frames
      planner = defined?(AutoplayBot::Config) ? AutoplayBot::Config.planner_budget.to_s : "low_lag"
      adaptive = defined?(AutoplayBot::Config) ? AutoplayBot::Config.adaptive_planner_budget.to_s : "low_lag_burst"
      return 90 if planner == "aggressive"
      return 120 if planner == "balanced" || adaptive == "balanced_burst"
      return 210 if adaptive == "strict_low_lag"
      return 150 if TOWN_CLEANUP_MAP_IDS.include?(current_map_id.to_i)
      180
    rescue
      180
    end

    def map_cleanup_targets(map)
      items = map && map["items"].is_a?(Array) ? map["items"] : []
      resources = map && map["field_resources"].is_a?(Array) ? map["field_resources"] : []
      statics = map && map["wild_statics"].is_a?(Array) ? map["wild_statics"] : []
      npcs = map && map["npcs"].is_a?(Array) ? map["npcs"] : []
      transfers = map && map["transfers"].is_a?(Array) ? map["transfers"] : []
      targets = []
      unique_events(items + resources + statics).each do |record|
        targets << { "kind" => "item", "record" => record } if field_item_target?(record, map)
      end
      unique_events(npcs).each do |record|
        targets << { "kind" => "npc", "record" => record }
      end
      transfers.each do |transfer|
        kind = building_transfer?(transfer) ? "building" : "transfer"
        targets << { "kind" => kind, "record" => transfer }
      end
      targets
    rescue
      []
    end

    def cleanup_priority_for(kind, record)
      distance = if defined?($game_player) && $game_player && record
                   (record["x"].to_i - $game_player.x).abs + (record["y"].to_i - $game_player.y).abs
                 else
                   20
                 end
      base = case kind.to_s
             when "item" then field_resource_target?(record) ? 8 : 10
             when "npc" then 26
             when "building" then 34
             else 55
             end
      base + [distance, 24].min
    rescue
      60
    end

    def cleanup_target_done_or_failed?(record, kind)
      return true if optional_attempt_limit_reached?(record, kind)
      case kind.to_s
      when "item"
        item_target_done?(record) || item_target_failed?(record)
      when "npc"
        npc_target_done?(record) || npc_target_failed?(record)
      when "building"
        (AutoplayBot::State.respond_to?(:target_done?) && AutoplayBot::State.target_done?(record, "building")) ||
          transfer_visited_or_failed?(record)
      when "transfer"
        transfer_visited_or_failed?(record)
      else
        false
      end
    rescue
      false
    end

    def optional_target_kind?(kind)
      ["item", "npc", "building", "transfer", "resource"].include?(kind.to_s)
    rescue
      false
    end

    def optional_interaction_target?(record, kind)
      return false unless record.is_a?(Hash)
      return false unless optional_target_kind?(kind)
      # Plain story events/transfers should keep recovering. Optional map-clear
      # work carries a cleanup/frontier kind, or arrives through these helpers.
      return true if ["item", "npc", "building"].include?(kind.to_s)
      !record["frontier_kind"].to_s.empty? || !record["frontier_key"].to_s.empty?
    rescue
      false
    end

    def optional_attempt_limit_reached?(record, kind)
      return false unless optional_interaction_target?(record, kind)
      return false unless defined?(AutoplayBot::State) &&
                          AutoplayBot::State.respond_to?(:target_attempt_count)
      if AutoplayBot::State.respond_to?(:target_failed?) &&
         AutoplayBot::State.target_failed?(record, 900, kind)
        return true
      end
      count = AutoplayBot::State.target_attempt_count(record, kind)
      return false if count < OPTIONAL_TARGET_MAX_ATTEMPTS
      defer_optional_interaction_target(record, kind, "attempt limit #{count}")
      true
    rescue
      false
    end

    def defer_optional_interaction_target(record, kind, reason = "attempt limit")
      return false unless optional_interaction_target?(record, kind)
      key = optional_interaction_key(record, kind)
      if defined?(AutoplayBot::State)
        AutoplayBot::State.mark_target_failed(record, reason, kind) if AutoplayBot::State.respond_to?(:mark_target_failed)
        AutoplayBot::State.touch_frontier(key, false, reason) if key && AutoplayBot::State.respond_to?(:touch_frontier)
        AutoplayBot::State.touch_cleanup_target(key, false, reason) if key && AutoplayBot::State.respond_to?(:touch_cleanup_target)
      end
      mark_repeat_item_done_this_visit(record) if kind.to_s == "item"
      clear_optional_interaction_runtime(record, kind)
      label = short_target_label(record)
      AutoplayBot.status("skip #{kind}: #{short_text_for_status(label, 24)}") if defined?(AutoplayBot)
      AutoplayBot.log("optional #{kind} deferred #{reason} key=#{key} at #{position_label}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      true
    rescue
      false
    end

    def optional_interaction_key(record, kind)
      return nil unless record.is_a?(Hash)
      if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:target_key)
        return AutoplayBot::State.target_key(record, kind)
      end
      [kind, record["map_id"] || current_map_id, record["key"] || record["event_id"], record["x"], record["y"]].compact.map(&:to_s).join(":")
    rescue
      nil
    end

    def record_frontier_kind(record, fallback = "target")
      kind = record.is_a?(Hash) ? record["frontier_kind"].to_s : ""
      kind.empty? ? fallback.to_s : kind
    rescue
      fallback.to_s
    end

    def same_optional_target?(left, right, kind)
      return false unless left.is_a?(Hash) && right.is_a?(Hash)
      optional_interaction_key(left, kind).to_s == optional_interaction_key(right, kind).to_s
    rescue
      false
    end

    def clear_optional_interaction_runtime(record, kind)
      if @active_forest_forage && same_optional_target?(@active_forest_forage, record, "item")
        @active_forest_forage = nil
      end
      if @active_forest_npc && same_optional_target?(@active_forest_npc, record, "npc")
        @active_forest_npc = nil
      end
      if @active_transfer && same_optional_target?(@active_transfer, record, kind)
        @active_transfer = nil
      end
      if @active_event_target && same_optional_target?(@active_event_target, record, kind)
        @active_event_target = nil
      end
      if @active_decision_goal && @active_decision_goal["record"].is_a?(Hash) &&
         same_optional_target?(@active_decision_goal["record"], record, @active_decision_goal["kind"] || kind)
        @active_decision_goal = nil
        @decision_choice_cache = nil
      end
      @local_discovery_cache = nil
      @active_route_plan = nil
      @pending_activation = nil
      @pending_forest_forage_activation = nil
      @forest_forage_attempt = nil
      @trying_to_move = false
    rescue
      nil
    end

    def decision_scheduler_tick
      return false unless map_clear_enabled?
      return false unless defined?($game_player) && $game_player
      return false unless trainer_has_pokedex?
      return false if current_map_id.to_i == VIRIDIAN_FOREST_MAP_ID && safe_mode?
      return false if pewter_gym_story_locked?
      goal = active_decision_goal
      goal = choose_decision_goal unless goal
      if goal
        record_decision_goal(goal)
        execute_decision_goal(goal)
        return true
      end
      AutoplayBot::State.record_active_goal(nil) if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:record_active_goal)
      false
    rescue => e
      AutoplayBot.log("decision scheduler failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def pewter_gym_story_locked?
      current_map_id.to_i == PEWTER_GYM_MAP_ID
    rescue
      false
    end

    def active_decision_goal
      return nil unless @active_decision_goal
      frame = (Graphics.frame_count rescue 0).to_i
      return nil if frame - @active_decision_goal["frame"].to_i > 120
      record = @active_decision_goal["record"]
      kind = @active_decision_goal["kind"]
      return nil if cleanup_target_done_or_failed?(record, kind)
      return nil if kind.to_s == "building" && recent_building_backtrack?(record)
      path = cleanup_candidate_path(record, kind)
      return nil unless path
      @active_decision_goal.merge("path_length" => path.length)
    rescue
      nil
    end

    def choose_decision_goal
      candidates = decision_goal_candidates
      return cache_decision_goal(nil) if candidates.empty?
      cached = decision_goal_cache_hit
      return cached["goal"] if cached
      scored = prioritized_decision_candidates(candidates).map do |goal|
        path = cleanup_candidate_path(goal["record"], goal["kind"])
        next nil unless path
        goal["path_length"] = path.length
        score = score_decision_goal(goal)
        next nil if score <= 0
        goal["score"] = score
        goal
      end.compact
      cache_decision_goal(scored.sort_by { |goal| [-goal["score"].to_i, goal["path_length"].to_i] }.first)
    rescue
      nil
    end

    def decision_goal_cache_hit
      cache = @decision_choice_cache
      return nil unless cache && cache["key"] == decision_choice_cache_key
      frame = (Graphics.frame_count rescue 0).to_i
      return nil if frame - cache["frame"].to_i > decision_choice_cache_frames
      cache
    rescue
      nil
    end

    def cache_decision_goal(goal)
      @decision_choice_cache = {
        "key" => decision_choice_cache_key,
        "frame" => (Graphics.frame_count rescue 0).to_i,
        "goal" => goal
      }
      goal
    rescue
      goal
    end

    def decision_choice_cache_key
      objective = AutoplayBot::State.current_objective if defined?(AutoplayBot::State)
      objective_id = objective.is_a?(Hash) ? (objective["id"] || objective["label"]) : objective
      x = defined?($game_player) && $game_player ? $game_player.x : 0
      y = defined?($game_player) && $game_player ? $game_player.y : 0
      "#{current_map_id}:#{x}:#{y}:#{objective_id}"
    rescue
      "unknown"
    end

    def decision_choice_cache_frames
      return 54 if TOWN_CLEANUP_MAP_IDS.include?(current_map_id.to_i)
      42
    rescue
      42
    end

    def prioritized_decision_candidates(candidates)
      limit = if collector_cleanup_priority?
                18
              else
                clear_before_leave? ? 14 : 8
              end
      return candidates if candidates.length <= limit
      candidates.sort_by { |goal| [cheap_goal_distance(goal), cheap_goal_rank(goal)] }.first(limit)
    rescue
      candidates
    end

    def collector_cleanup_priority?
      defined?(AutoplayBot::Config) &&
        AutoplayBot::Config.collector_heavy? &&
        AutoplayBot::Config.collector_opportunistic?
    rescue
      false
    end

    def cheap_goal_distance(goal)
      record = goal && goal["record"]
      return 999 unless record && defined?($game_player) && $game_player
      (record["x"].to_i - $game_player.x.to_i).abs + (record["y"].to_i - $game_player.y.to_i).abs
    rescue
      999
    end

    def cheap_goal_rank(goal)
      case goal && goal["kind"].to_s
      when "item" then 0
      when "npc" then 1
      when "building" then 2
      when "transfer" then 3
      else 4
      end
    rescue
      4
    end

    def decision_goal_candidates
      map = AutoplayBot::WorldScanner.current_map_data if defined?(AutoplayBot::WorldScanner)
      goals = map_cleanup_targets(map).map do |entry|
        record = entry["record"].merge("map_id" => current_map_id)
        kind = entry["kind"]
        next nil if cleanup_target_done_or_failed?(record, kind)
        next nil if kind == "transfer" && !clear_before_leave?
        next nil if kind == "building" && recent_building_backtrack?(record)
        { "kind" => kind, "record" => record, "label" => cleanup_goal_label(kind, record), "source" => "map" }
      end.compact
      cleanup = AutoplayBot::State.next_cleanup_target(current_map_id) if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:next_cleanup_target)
      if cleanup && cleanup["record"].is_a?(Hash) &&
         (cleanup["kind"].to_s != "transfer" || clear_before_leave?) &&
         !cleanup_target_done_or_failed?(cleanup["record"], cleanup["kind"])
        goals << {
          "kind" => cleanup["kind"].to_s,
          "record" => cleanup["record"],
          "label" => cleanup_goal_label(cleanup["kind"], cleanup["record"]),
          "source" => "queue",
          "queue_key" => cleanup["key"]
        }
      end
      goals.compact
    rescue
      []
    end

    def cleanup_goal_label(kind, record)
      case kind.to_s
      when "item" then item_label(record)
      when "npc" then npc_label(record)
      when "building", "transfer" then transfer_label(record)
      else short_target_label(record)
      end
    rescue
      "target"
    end

    def cleanup_candidate_path(record, kind)
      return nil unless record && record["x"] && record["y"]
      key = "cleanup_candidate:#{kind}:#{record["key"] || record["event_id"]}:#{record["x"]}:#{record["y"]}:#{$game_player.x},#{$game_player.y}"
      cached_path(key) do
        case kind.to_s
        when "building", "transfer"
          include_adjacent = record["trigger"].to_i != 1
          AutoplayBot::Pathfinder.path_to(record["x"], record["y"], adaptive_budget(1200, "cleanup"), include_adjacent)
        else
          path_to_event_action(record, adaptive_budget(1200, kind))
        end
      end
    rescue
      nil
    end

    def score_decision_goal(goal)
      record = goal["record"]
      kind = goal["kind"].to_s
      path_length = goal["path_length"].to_i
      distance = if defined?($game_player) && $game_player
                   (record["x"].to_i - $game_player.x).abs + (record["y"].to_i - $game_player.y).abs
                 else
                   path_length
                 end
      return 0 if path_length > max_cleanup_path_length(kind)
      score = case kind
              when "item" then field_resource_target?(record) ? 1120 : 1040
              when "npc" then collector_cleanup_priority? ? 900 : 650
              when "building" then collector_cleanup_priority? ? 620 : 540
              else 330
              end
      score += 170 if kind == "item" && defined?(AutoplayBot::Config) && AutoplayBot::Config.collector_heavy?
      score += 90 if kind == "npc" && collector_cleanup_priority?
      score += 80 if goal["source"].to_s == "queue"
      score += 60 if path_length <= 6
      score -= path_length * 7
      score -= distance * 2
      score -= story_pressure_penalty_for(kind, path_length)
      score
    rescue
      0
    end

    def story_pressure_penalty_for(kind, path_length)
      return 0 unless story_pressure_high?
      return 0 if clear_before_leave?
      return 0 if collector_cleanup_priority? && ["item", "npc"].include?(kind.to_s) && path_length.to_i <= 28
      return 120 if collector_cleanup_priority? && kind.to_s == "building" && path_length.to_i <= 12
      path_length.to_i > 10 ? 260 : 0
    rescue
      0
    end

    def max_cleanup_path_length(kind)
      return 40 if clear_before_leave?
      if collector_cleanup_priority?
        return 52 if kind.to_s == "item"
        return 38 if kind.to_s == "npc"
        return 24 if kind.to_s == "building"
      end
      return 34 if kind.to_s == "item" && defined?(AutoplayBot::Config) && AutoplayBot::Config.collector_heavy?
      return 26 if kind.to_s == "item"
      return 22 if kind.to_s == "npc"
      return 18 if kind.to_s == "building"
      14
    rescue
      18
    end

    def story_pressure_high?
      return false if route_recalc_explore_active?
      return true unless trainer_has_pokedex?
      return true if recovering_from_blackout?
      objective = AutoplayBot::State.current_objective if defined?(AutoplayBot::State)
      type = objective && objective["type"].to_s
      ["battle", "heal", "travel"].include?(type) && !clear_before_leave?
    rescue
      true
    end

    def execute_decision_goal(goal)
      @active_decision_goal = goal.merge("frame" => (Graphics.frame_count rescue 0).to_i)
      set_supervisor_mode(goal["kind"].to_s == "transfer" ? "frontier_explore" : "navigation")
      case goal["kind"].to_s
      when "item"
        collect_item_target(goal["record"])
      when "npc"
        talk_to_npc_target(goal["record"])
      when "building"
        enter_building_target(goal["record"])
      when "transfer"
        @active_transfer = goal["record"]
        navigate_to_transfer(goal["record"])
      else
        return false
      end
      true
    rescue => e
      AutoplayBot.log("execute decision failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def record_decision_goal(goal)
      label = goal["label"] || cleanup_goal_label(goal["kind"], goal["record"])
      AutoplayBot::State.record_active_goal({
        "kind" => goal["kind"],
        "label" => label,
        "score" => goal["score"],
        "path" => goal["path_length"],
        "source" => goal["source"]
      }) if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:record_active_goal)
      frame = (Graphics.frame_count rescue 0).to_i
      @last_decision_log_frame = -9999 if @last_decision_log_frame.nil?
      status_key = "#{goal["kind"]}:#{label}:#{goal["score"]}:#{goal["path_length"]}"
      @last_decision_status_key ||= nil
      @last_decision_status_frame ||= -9999
      if @last_decision_status_key != status_key ||
         frame - @last_decision_status_frame.to_i >= 60
        @last_decision_status_key = status_key
        @last_decision_status_frame = frame
        AutoplayBot.status("think: #{short_target_label(goal["record"])}")
        AutoplayBot::Overlay.update(true) if defined?(AutoplayBot::Overlay)
      end
      if frame - @last_decision_log_frame.to_i >= 180
        @last_decision_log_frame = frame
        AutoplayBot.log("decision: #{label} score=#{goal["score"]} path=#{goal["path_length"]}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      end
    rescue
      nil
    end

    def current_local_discovery_target
      frame = (Graphics.frame_count rescue 0).to_i
      if @local_discovery_cache &&
         @local_discovery_cache["map"].to_i == current_map_id.to_i &&
         @local_discovery_cache["x"].to_i == $game_player.x.to_i &&
         @local_discovery_cache["y"].to_i == $game_player.y.to_i &&
         frame - @local_discovery_cache["frame"].to_i < local_discovery_cache_frames
        return @local_discovery_cache["target"]
      end
      target = local_item_target || local_npc_target || local_building_target
      @local_discovery_cache = {
        "frame" => frame,
        "map" => current_map_id,
        "x" => $game_player.x,
        "y" => $game_player.y,
        "target" => target
      }
      target
    rescue
      nil
    end

    def local_discovery_cache_frames
      return 75 if TOWN_CLEANUP_MAP_IDS.include?(current_map_id.to_i)
      60
    rescue
      60
    end

    def local_item_target
      map = AutoplayBot::WorldScanner.current_map_data
      items = map && map["items"].is_a?(Array) ? map["items"] : []
      resources = map && map["field_resources"].is_a?(Array) ? map["field_resources"] : []
      statics = map && map["wild_statics"].is_a?(Array) ? map["wild_statics"] : []
      records = unique_events(items + resources + statics)
      records = records.select { |item| field_item_target?(item, map) }
      records = records.reject { |item| item_target_done?(item) || item_target_failed?(item) }
      best_local_candidate(records, "item")
    rescue
      nil
    end

    def local_npc_target
      map = AutoplayBot::WorldScanner.current_map_data
      npcs = map && map["npcs"].is_a?(Array) ? map["npcs"] : []
      records = npcs.reject { |npc| npc_target_done?(npc) || npc_target_failed?(npc) }
      best_local_candidate(records, "npc")
    rescue
      nil
    end

    def local_building_target
      map = AutoplayBot::WorldScanner.current_map_data
      transfers = map && map["transfers"].is_a?(Array) ? map["transfers"] : []
      records = transfers.select do |transfer|
        building_transfer?(transfer) && !transfer_visited_or_failed?(transfer)
      end
      best_local_candidate(records, "building")
    rescue
      nil
    end

    def best_local_candidate(records, kind)
      limit = AutoplayBot::Config.local_discovery_path_limit
      distance_limit = AutoplayBot::Config.local_discovery_distance
      scored = records.map do |record|
        next nil unless record && record["x"] && record["y"]
        distance = (record["x"].to_i - $game_player.x).abs + (record["y"].to_i - $game_player.y).abs
        next nil if distance > distance_limit
        path = local_candidate_path(record, kind)
        next nil unless path && path.length <= limit
        [path.length, distance, { "kind" => kind, "record" => record }]
      end.compact
      scored.sort_by { |entry| [entry[0], entry[1]] }.map { |entry| entry[2] }.first
    rescue
      nil
    end

    def local_candidate_path(record, kind)
      key = "local_candidate:#{kind}:#{record["key"] || record["event_id"]}:#{record["x"]}:#{record["y"]}:#{$game_player.x},#{$game_player.y}"
      cached_path(key) do
        if kind == "building"
          include_adjacent = record["trigger"].to_i != 1
          AutoplayBot::Pathfinder.path_to(record["x"], record["y"], adaptive_budget(900, "cleanup"), include_adjacent)
        else
          path_to_event_action(record, adaptive_budget(900, kind))
        end
      end
    rescue
      nil
    end

    def adaptive_budget(default_value = 2400, context = nil)
      if defined?(AutoplayBot::Config) && AutoplayBot::Config.respond_to?(:adaptive_path_node_budget)
        return AutoplayBot::Config.adaptive_path_node_budget(default_value, context)
      end
      AutoplayBot::Config.path_node_budget(default_value)
    rescue
      default_value.to_i
    end

    def frontier_allowed_now?
      return false unless AutoplayBot::Config.frontier_explore?
      return true unless safe_mode?
      if broad_frontier_deferred_map?(current_map_id)
        frame = (Graphics.frame_count rescue 0).to_i
        @last_frontier_defer_frame = -9999 if @last_frontier_defer_frame.nil?
        if frame - @last_frontier_defer_frame.to_i >= 120
          @last_frontier_defer_frame = frame
          AutoplayBot.status("safe mode: story route")
        end
        return false
      end
      true
    rescue
      false
    end

    def broad_frontier_deferred_map?(map_id)
      return true if STORY_NAV_MAP_IDS.include?(map_id.to_i)
      bounds = map_bounds
      return false unless bounds
      bounds["width"].to_i * bounds["height"].to_i > 900
    rescue
      true
    end

    def recovery_exit_transfer
      map = AutoplayBot::WorldScanner.current_map_data if defined?(AutoplayBot::WorldScanner)
      transfers = map && map["transfers"].is_a?(Array) ? map["transfers"] : []
      return nil if transfers.empty?
      transfers.sort_by do |transfer|
        dest = transfer["destination_map_id"].to_i
        story_bonus = story_navigation_map?(dest) ? 0 : 1
        same_map_penalty = dest == current_map_id.to_i ? 1 : 0
        distance = if defined?($game_player) && $game_player
                     (transfer["x"].to_i - $game_player.x).abs + (transfer["y"].to_i - $game_player.y).abs
                   else
                     0
                   end
        [story_bonus, same_map_penalty, distance]
      end.first
    rescue
      nil
    end

    def explore_current_map
      set_supervisor_mode("frontier_explore")
      item = current_map_item_target
      if item
        collect_item_target(item)
        return
      end
      npc = current_map_npc_target
      if npc
        talk_to_npc_target(npc)
        return
      end
      transfer = AutoplayBot::WorldScanner.nearest_unvisited_transfer
      unless transfer
        AutoplayBot.status("frontier: no local transfer")
        AutoplayBot::Runtime.manual_needed("no scanned transfer on map #{current_map_id}") if defined?(AutoplayBot::Runtime)
        return
      end
      AutoplayBot::State.enqueue_frontier(transfer, "transfer", 50) if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:enqueue_frontier)
      @active_transfer = transfer
      label = transfer_label(transfer)
      set_objective("explore_#{current_map_id}_#{transfer["event_id"] || transfer["key"]}", "travel", label)
      AutoplayBot.status("planning: #{label}")
      navigate_to_transfer(transfer)
    end

    def current_map_item_target
      return nil unless AutoplayBot::Config.frontier_explore?
      return nil unless defined?(AutoplayBot::WorldScanner) && defined?($game_player) && $game_player
      map = AutoplayBot::WorldScanner.current_map_data
      items = map && map["items"].is_a?(Array) ? map["items"] : []
      resources = map && map["field_resources"].is_a?(Array) ? map["field_resources"] : []
      statics = map && map["wild_statics"].is_a?(Array) ? map["wild_statics"] : []
      items = unique_events(items + resources + statics)
      items = items.select { |item| field_item_target?(item, map) }
      candidates = items.reject do |item|
        item_target_done?(item) || item_target_failed?(item)
      end
      candidates.min_by do |item|
        (item["x"].to_i - $game_player.x).abs + (item["y"].to_i - $game_player.y).abs
      end
    rescue
      nil
    end

    def field_item_target?(item, map = nil)
      return false if trainer_reward_item?(item, map)
      call = item && item["call"].to_s
      call == "pbItemBall" || call == "pbReceiveItem" || field_resource_target?(item)
    rescue
      false
    end

    def trainer_reward_item?(item, map = nil)
      return false unless item.is_a?(Hash)
      event_id = item["event_id"].to_i
      return false if event_id <= 0
      map ||= AutoplayBot::WorldScanner.current_map_data if defined?(AutoplayBot::WorldScanner)
      trainers = map && map["trainers"].is_a?(Array) ? map["trainers"] : []
      trainers.any? { |trainer| trainer.is_a?(Hash) && trainer["event_id"].to_i == event_id }
    rescue
      false
    end

    def field_resource_target?(item)
      return false unless item.is_a?(Hash)
      call = item["call"].to_s
      return true if call == "fieldResource"
      text = [item["event_name"], item["args"], item["resource_kind"], item["call"]].compact.join(" ")
      return false unless call == "pbWildBattle" || text =~ /trash|berry|mushroom|web|spider|honey|forage/i
      text =~ /spider|spinarak|ariados|\bweb\b|trash\s*can|trashcan|\btrash\b|garbage|dustbin|rubbish|berry|apricorn|mushroom|fungus|honey\s*tree|\bhoney\b|forage/i
    rescue
      false
    end

    def item_target_done?(item)
      return repeat_item_done_this_visit?(item) if repeatable_item_target?(item)
      return false unless defined?(AutoplayBot::State)
      AutoplayBot::State.respond_to?(:target_done?) &&
        AutoplayBot::State.target_done?(item, "item")
    rescue
      false
    end

    def item_target_failed?(item)
      return false unless defined?(AutoplayBot::State)
      return true if optional_attempt_limit_reached?(item, "item")
      cooldown = repeatable_item_target?(item) ? 90 : (field_resource_target?(item) ? 300 : 600)
      AutoplayBot::State.respond_to?(:target_failed?) &&
        AutoplayBot::State.target_failed?(item, cooldown, "item")
    rescue
      false
    end

    def repeatable_item_target?(item)
      return false unless current_map_id.to_i == VIRIDIAN_FOREST_MAP_ID
      return false if item.is_a?(Hash) && item.key?("repeatable_forest_item") && item["repeatable_forest_item"] == false
      return true if item.is_a?(Hash) && item["repeatable_forest_item"] == true
      return true if forest_forage_item?(item)
      text = [item["event_name"], item["args"], item["call"]].compact.join(" ")
      text =~ /mushroom|tiny\s*mushroom|big\s*mushroom|balm\s*mushroom/i
    rescue
      false
    end

    def forest_forage_item?(item)
      return false unless current_map_id.to_i == VIRIDIAN_FOREST_MAP_ID
      return false unless field_item_target?(item)
      x = item["x"].to_i
      y = item["y"].to_i
      # These events are the forest ground-forage pickups in the current map
      # data. Their scripts often expose berry/BUGGEM rewards instead of a
      # literal mushroom item name, so identify them by event placement too.
      [[44, 35], [45, 35], [10, 31], [9, 31], [19, 8], [18, 8]].include?([x, y])
    rescue
      false
    end

    def current_forest_forage_target
      return nil unless current_map_id.to_i == VIRIDIAN_FOREST_MAP_ID
      return nil unless defined?($game_player) && $game_player
      if @active_forest_forage &&
         !item_target_done?(@active_forest_forage) &&
         !item_target_failed?(@active_forest_forage) &&
         forest_forage_still_reasonable?(@active_forest_forage)
        return @active_forest_forage
      end
      @active_forest_forage = nil
      frame = (Graphics.frame_count rescue 0).to_i
      if @forest_forage_cache &&
         @forest_forage_cache["map"].to_i == current_map_id.to_i &&
         @forest_forage_cache["x"].to_i == $game_player.x.to_i &&
         @forest_forage_cache["y"].to_i == $game_player.y.to_i &&
         frame - @forest_forage_cache["frame"].to_i < 30
        return @forest_forage_cache["target"]
      end
      candidates = forest_forage_records
      candidates = candidates.reject { |item| item_target_done?(item) || item_target_failed?(item) }
      candidates = candidates.select { |item| forest_forage_direct_candidate?(item) }
      scored = candidates.map do |item|
        distance = (item["x"].to_i - $game_player.x).abs + (item["y"].to_i - $game_player.y).abs
        path = forest_forage_path(item)
        next nil unless path
        [path.length, distance, item]
      end.compact
      target = scored.sort_by { |entry| [entry[0], entry[1]] }.map { |entry| entry[2] }.first
      @forest_forage_cache = {
        "frame" => frame,
        "map" => current_map_id,
        "x" => $game_player.x,
        "y" => $game_player.y,
        "target" => target
      }
      @active_forest_forage = target if target
      target
    rescue
      nil
    end

    def forest_forage_records
      [
        forest_forage_record(40, 9, 36, "Antidote", "PBItems::ANTIDOTE", false, "pbItemBall"),
        forest_forage_record(41, 10, 25, "Potion", "PBItems::POTION", false, "pbItemBall"),
        forest_forage_record(26, 7, 25, "Pecha Berries", "PBItems::PECHABERRY", false, "pbItemBall"),
        forest_forage_record(36, 35, 7, "Antidote", "PBItems::ANTIDOTE", false, "pbItemBall"),
        forest_forage_record(42, 46, 36, "Poke Ball", "PBItems::POKEBALL", false, "pbItemBall"),
        forest_forage_record(61, 31, 10, "Ash Hat", "HAT_ASH", false, "pbReceiveItem"),
        forest_forage_record(54, 17, 21, "Pokemon egg", "VENIPEDE egg", false, "pbReceiveItem"),
        forest_forage_record(14, 44, 24, "Mushroom spot", "mushroom", true),
        forest_forage_record(15, 48, 24, "Mushroom spot", "mushroom", true),
        forest_forage_record(16, 50, 27, "Mushroom spot", "mushroom", true),
        forest_forage_record(17, 47, 28, "Mushroom spot", "mushroom", true),
        forest_forage_record(22, 44, 35),
        forest_forage_record(23, 45, 35),
        forest_forage_record(24, 10, 31),
        forest_forage_record(25, 9, 31),
        forest_forage_record(9, 19, 8),
        forest_forage_record(21, 18, 8),
        forest_forage_record(37, 59, 18, "Spider web", "Ariados web", true),
        forest_forage_record(43, 60, 18, "Spider web", "Ariados web", true)
      ]
    rescue
      []
    end

    def forest_forage_record(event_id, x, y, event_name = "Spider web", args = "web forage", repeatable = true, call = "pbReceiveItem")
      {
        "key" => "#{repeatable ? "forest_forage" : "forest_item"}:#{event_id}:#{x}:#{y}",
        "map_id" => VIRIDIAN_FOREST_MAP_ID,
        "event_id" => event_id,
        "event_name" => event_name,
        "x" => x,
        "y" => y,
        "call" => call,
        "args" => args,
        "trigger" => 0,
        "repeatable_forest_item" => repeatable
      }
    end

    def forest_forage_direct_candidate?(item)
      return false unless defined?($game_player) && $game_player
      distance = (item["x"].to_i - $game_player.x).abs + (item["y"].to_i - $game_player.y).abs
      return false if distance > forest_forage_distance_limit(item)
      path = forest_forage_path(item)
      path && path.length <= forest_forage_path_limit(item)
    rescue
      false
    end

    def forest_forage_still_reasonable?(item)
      return true if forest_forage_action_ready?(item)
      return false unless defined?($game_player) && $game_player
      distance = (item["x"].to_i - $game_player.x).abs + (item["y"].to_i - $game_player.y).abs
      return false if distance > forest_forage_distance_limit(item) + 2
      path = forest_forage_path(item)
      path && path.length <= forest_forage_path_limit(item) + 4
    rescue
      false
    end

    def forest_forage_distance_limit(item)
      return 28 if collector_cleanup_priority? && repeatable_item_target?(item)
      return 34 if collector_cleanup_priority?
      repeatable_item_target?(item) ? 18 : 24
    rescue
      18
    end

    def forest_forage_path_limit(item)
      return 42 if collector_cleanup_priority? && repeatable_item_target?(item)
      return 50 if collector_cleanup_priority?
      repeatable_item_target?(item) ? 30 : 36
    rescue
      30
    end

    def forest_forage_near_active_trainer?(item)
      return false unless defined?($game_map) && $game_map && $game_map.respond_to?(:events) && $game_map.events
      x = item["x"].to_i
      y = item["y"].to_i
      $game_map.events.values.any? do |event|
        next false unless event && event.respond_to?(:name) && event.name.to_s =~ /trainer/i
        next false unless event.respond_to?(:trigger) && event.trigger.to_i == 2
        distance = (event.x.to_i - x).abs + (event.y.to_i - y).abs rescue 999
        distance <= 7
      end
    rescue
      false
    end

    def forest_forage_path(item)
      return [] if forest_forage_action_ready?(item)
      player = defined?($game_player) && $game_player ? "#{$game_player.x},#{$game_player.y}" : "nopos"
      key = "forest_forage_path:#{item["key"] || item["event_id"]}:#{item["x"]}:#{item["y"]}:#{player}"
      cached_path(key) { path_to_event_action(item, adaptive_budget(900, "item")) }
    rescue
      nil
    end

    def repeat_item_visit_key(item)
      AutoplayBot::State.target_key(item, "item") rescue "item:#{current_map_id}:#{item["event_id"]}:#{item["x"]}:#{item["y"]}"
    end

    def repeat_item_done_this_visit?(item)
      @repeat_item_done_this_visit ||= {}
      @repeat_item_done_this_visit[repeat_item_visit_key(item)] == true
    rescue
      false
    end

    def mark_repeat_item_done_this_visit(item)
      return unless repeatable_item_target?(item)
      @repeat_item_done_this_visit ||= {}
      @repeat_item_done_this_visit[repeat_item_visit_key(item)] = true
      @forest_forage_cache = nil
      @active_forest_forage = nil
      @pending_forest_forage_activation = nil
      @forest_forage_attempt = nil
    rescue
      nil
    end

    def current_map_npc_target
      return nil unless AutoplayBot::Config.frontier_explore?
      return nil unless defined?(AutoplayBot::WorldScanner) && defined?($game_player) && $game_player
      map = AutoplayBot::WorldScanner.current_map_data
      npcs = map && map["npcs"].is_a?(Array) ? map["npcs"] : []
      candidates = npcs.reject do |npc|
        npc_target_done?(npc) || npc_target_failed?(npc)
      end
      candidates.min_by do |npc|
        (npc["x"].to_i - $game_player.x).abs + (npc["y"].to_i - $game_player.y).abs
      end
    rescue
      nil
    end

    def npc_target_done?(npc)
      return false unless defined?(AutoplayBot::State)
      AutoplayBot::State.respond_to?(:target_done?) &&
        AutoplayBot::State.target_done?(npc, "npc")
    rescue
      false
    end

    def npc_target_failed?(npc)
      return false unless defined?(AutoplayBot::State)
      return true if optional_attempt_limit_reached?(npc, "npc")
      AutoplayBot::State.respond_to?(:target_failed?) &&
        AutoplayBot::State.target_failed?(npc, 900, "npc")
    rescue
      false
    end

    def collect_item_target(item)
      key = AutoplayBot::State.target_key(item, "item") rescue "item:#{current_map_id}:#{item["event_id"]}"
      record = item.merge(
        "map_id" => current_map_id,
        "frontier_kind" => "item",
        "frontier_key" => key
      )
      AutoplayBot::State.enqueue_frontier(record, "item", 20) if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:enqueue_frontier)
      label = item_label(record)
      set_objective("item_#{current_map_id}_#{record["event_id"] || record["x"]}", "travel", label)
      AutoplayBot.status("spot item: #{label}")
      navigate_to_event(record)
    rescue => e
      AutoplayBot.log("item target failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    end

    def talk_to_npc_target(npc)
      key = AutoplayBot::State.target_key(npc, "npc") rescue "npc:#{current_map_id}:#{npc["event_id"]}"
      record = npc.merge(
        "map_id" => current_map_id,
        "frontier_kind" => "npc",
        "frontier_key" => key
      )
      AutoplayBot::State.enqueue_frontier(record, "npc", 30) if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:enqueue_frontier)
      label = npc_label(record)
      set_objective("npc_#{current_map_id}_#{record["event_id"] || record["x"]}", "story", label)
      AutoplayBot.status("spot npc: #{label}")
      navigate_to_event(record)
    rescue => e
      AutoplayBot.log("npc target failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    end

    def item_label(item)
      return resource_label(item) if field_resource_target?(item)
      name = item["event_name"].to_s
      call = item["call"].to_s
      args = item["args"].to_s
      name = call if name.empty? || name =~ /EV\d+/i
      detail = args.empty? ? "" : " #{args[0, 28]}"
      "Pick up #{name}#{detail}"
    rescue
      "Pick up item"
    end

    def resource_label(item)
      kind = item["resource_kind"].to_s
      text = [kind, item["event_name"], item["args"]].join(" ")
      return "Check spider web" if text =~ /spider|spinarak|ariados|\bweb\b/i
      return "Check trash can" if text =~ /trash|garbage|dustbin|rubbish/i
      return "Check berry spot" if text =~ /berry|apricorn/i
      return "Check mushroom spot" if text =~ /mushroom|fungus|forage/i
      return "Check honey tree" if text =~ /honey/i
      "Check field resource"
    rescue
      "Check field resource"
    end

    def npc_label(npc)
      name = npc["event_name"].to_s
      graphic = npc["graphic"].to_s
      name = graphic if name.empty? || name =~ /EV\d+/i
      name = "NPC" if name.empty?
      "Talk to #{name}"
    rescue
      "Talk to NPC"
    end

    def transfer_label(transfer)
      name = transfer["event_name"].to_s
      name = "transfer" if name.empty?
      dest = transfer["destination_map_id"] ? " -> map #{transfer["destination_map_id"]}" : ""
      verb = building_transfer?(transfer) ? "Enter" : "Explore"
      "#{verb} #{name}#{dest}"
    rescue
      "Explore current map"
    end

    def short_target_label(record)
      return "target" unless record.is_a?(Hash)
      name = record["event_name"].to_s
      name = record["destination_name"].to_s if name.empty?
      name = record["key"].to_s if name.empty?
      name = "target #{record["x"]},#{record["y"]}" if name.empty?
      name.length > 32 ? "#{name[0, 29]}..." : name
    rescue
      "target"
    end

    def building_transfer?(transfer)
      text = [transfer["event_name"], transfer["destination_name"]].compact.join(" ")
      return true if text =~ /house|home|mart|center|gym|lab|school|building|shop|store|hotel|club|museum|gate/i
      false
    rescue
      false
    end

    def building_like_map_id?(map_id)
      return false unless map_id
      name = if defined?(AutoplayBot::WorldScanner)
               AutoplayBot::WorldScanner.map_name(map_id) rescue ""
             else
               ""
             end
      return true if name.to_s =~ /house|home|mart|center|gym|lab|school|building|shop|store|hotel|club|museum|gate|room/i
      return false if story_navigation_map?(map_id)
      map_id.to_i == current_map_id.to_i && small_current_map?
    rescue
      false
    end

    def small_current_map?
      bounds = map_bounds
      bounds && bounds["width"].to_i * bounds["height"].to_i <= 900
    rescue
      false
    end

    def recent_building_backtrack?(transfer)
      return false unless transfer && @last_transfer_transition
      frame = (Graphics.frame_count rescue 0).to_i
      return false if frame - @last_transfer_transition["frame"].to_i > 720
      return false unless @last_transfer_transition["leaving_building"]
      return false unless building_transfer?(transfer)
      transfer["destination_map_id"].to_i == @last_transfer_transition["from_map"].to_i
    rescue
      false
    end

    def early_story_tick
      case current_map_id
      when PALLET_TOWN_MAP_ID
        return pallet_town_story_tick
      when ROUTE_1_MAP_ID
        return route_1_story_tick
      when VIRIDIAN_CITY_MAP_ID
        return viridian_city_story_tick
      when VIRIDIAN_MART_MAP_ID
        return viridian_mart_story_tick
      when *OAK_LAB_MAP_IDS
        return oak_lab_story_tick
      when ROUTE_2_SOUTH_MAP_ID
        return route_2_south_story_tick
      when VIRIDIAN_FOREST_SOUTH_GATE_MAP_ID
        return forest_south_gate_story_tick
      when VIRIDIAN_FOREST_MAP_ID
        return viridian_forest_story_tick
      when VIRIDIAN_FOREST_NORTH_GATE_MAP_ID
        return forest_north_gate_story_tick
      when ROUTE_2_NORTH_MAP_ID
        return route_2_north_story_tick
      when PEWTER_CITY_MAP_ID
        return pewter_city_story_tick
      when PEWTER_GYM_MAP_ID
        return pewter_gym_story_tick
      end
      false
    end

    def pallet_town_story_tick
      unless starter_obtained?
        unless game_switch?(96) || game_switch?(898)
          set_objective("starter_meet_rival", "story", "Meet rival outside")
          navigate_to_event(PALLET_RIVAL_EVENT.merge("map_id" => current_map_id))
          return true
        end
        unless game_switch?(898)
          set_objective("starter_find_professor", "story", "Find Professor Oak")
          map_edge_step(PALLET_ROUTE_1_EXIT["x"], PALLET_ROUTE_1_EXIT["y"], 8, "north road to Oak")
          return true
        end
        set_objective("starter_wait_for_oak", "story", "Wait for Professor Oak")
        map_edge_step(PALLET_ROUTE_1_EXIT["x"], PALLET_ROUTE_1_EXIT["y"], 8, "Professor Oak trigger")
        return true
      end

      if game_switch?(61) && !game_switch?(220) && !trainer_has_pokedex?
        set_objective("oak_parcel_go_viridian", "travel", "Go to Viridian Mart")
        map_edge_step(PALLET_ROUTE_1_EXIT["x"], PALLET_ROUTE_1_EXIT["y"], 8, "Route 1 north")
        return true
      end

      if game_switch?(220) && !trainer_has_pokedex?
        set_objective("oak_parcel_return_lab", "travel", "Return to Professor Oak")
        transfer = PALLET_LAB_TRANSFER.merge(
          "map_id" => current_map_id,
          "destination_map_id" => preferred_lab_map_id
        )
        @active_transfer = transfer
        navigate_to_transfer(transfer)
        return true
      end

      if trainer_has_pokedex?
        return true if optional_cleanup_allowed? && town_cleanup_tick
        set_objective("story_go_viridian", "travel", "Head toward Viridian City")
        map_edge_step(PALLET_ROUTE_1_EXIT["x"], PALLET_ROUTE_1_EXIT["y"], 8, "Route 1 north")
        return true
      end

      false
    end

    def route_1_story_tick
      if game_switch?(220) && !trainer_has_pokedex?
        set_objective("oak_parcel_return_pallet", "travel", "Return to Pallet Town")
        map_edge_step(ROUTE_1_SOUTH_EXIT["x"], ROUTE_1_SOUTH_EXIT["y"], 2, "Pallet Town south")
        return true
      end
      if game_switch?(61) || trainer_has_pokedex?
        objective_id = trainer_has_pokedex? ? "story_go_viridian" : "oak_parcel_go_viridian"
        objective_label = trainer_has_pokedex? ? "Go to Viridian City" : "Go to Viridian Mart"
        set_objective(objective_id, "travel", objective_label)
        label = trainer_has_pokedex? ? "Viridian City north" : "Viridian Mart north"
        map_edge_step(ROUTE_1_NORTH_EXIT["x"], ROUTE_1_NORTH_EXIT["y"], 8, label)
        return true
      end
      false
    end

    def viridian_city_story_tick
      if game_switch?(220) && !trainer_has_pokedex?
        set_objective("oak_parcel_return_route1", "travel", "Return to Professor Oak")
        map_edge_step(VIRIDIAN_ROUTE_1_EXIT["x"], VIRIDIAN_ROUTE_1_EXIT["y"], 2, "Route 1 south")
        return true
      end
      if game_switch?(61) && !trainer_has_pokedex?
        set_objective("oak_parcel_enter_mart", "travel", "Enter Viridian Mart")
        transfer = VIRIDIAN_MART_TRANSFER.merge("map_id" => current_map_id)
        @active_transfer = transfer
        navigate_to_transfer(transfer)
        return true
      end
      if trainer_has_pokedex?
        return true if optional_cleanup_allowed? && town_cleanup_tick
        set_objective("story_go_route2", "travel", "Head to Route 2")
        map_edge_step(VIRIDIAN_ROUTE_2_EXIT["x"], VIRIDIAN_ROUTE_2_EXIT["y"], 8, "Route 2 north")
        return true
      end
      false
    end

    def viridian_mart_story_tick
      if trainer_has_pokedex?
        return true if shop_restock_tick
        return true if optional_cleanup_allowed? && building_cleanup_tick
        set_objective("story_leave_mart", "travel", "Leave Viridian Mart")
        transfer = VIRIDIAN_MART_EXIT.merge("map_id" => current_map_id)
        @active_transfer = transfer
        viridian_mart_exit_rail!(transfer)
        return true
      end
      if game_switch?(220)
        set_objective("oak_parcel_leave_mart", "travel", "Leave Viridian Mart")
        transfer = VIRIDIAN_MART_EXIT.merge("map_id" => current_map_id)
        @active_transfer = transfer
        viridian_mart_exit_rail!(transfer)
        return true
      end
      if game_switch?(61)
        set_objective("oak_parcel_get", "story", "Get Oak's Parcel")
        event = VIRIDIAN_MART_CLERK.merge("map_id" => current_map_id)
        navigate_to_event(event)
        return true
      end
      false
    end

    def oak_lab_story_tick
      return true if trainer_has_pokedex? && optional_cleanup_allowed? && building_cleanup_tick
      if game_switch?(220) && !trainer_has_pokedex?
        set_objective("oak_parcel_deliver", "story", "Deliver Oak's Parcel")
        event = OAK_EVENT.merge("map_id" => current_map_id)
        navigate_to_event(event)
        return true
      end

      if game_switch?(51) && !game_switch?(3) && !starter_obtained?
        set_objective("oak_intro", "story", "Listen to Professor Oak")
        wait_or_interact("oak_intro", "waiting: Oak intro", OAK_EVENT)
        return true
      end

      if game_switch?(3) && !starter_obtained?
        set_objective("starter_choose_pokemon", "story", "Choose starter Pokemon")
        if AutoplayBot::Config.pause_on_exclusive_choices?
          AutoplayBot::Runtime.manual_needed("exclusive choice: choose starter Pokemon") if defined?(AutoplayBot::Runtime)
          return true
        end
        event = starter_ball_event
        navigate_to_event(event)
        return true
      end

      if starter_obtained? && game_switch?(59) && !game_switch?(52) && !game_switch?(61)
        set_objective("starter_wait_for_rival", "story", "Wait for rival")
        wait_or_interact("starter_wait_for_rival", "waiting: rival starter", OAK_EVENT)
        return true
      end

      if starter_obtained? && game_switch?(52) && !game_switch?(61)
        set_objective("starter_rival_battle", "battle", "Battle rival")
        direct_step_toward(LAB_RIVAL_BATTLE["x"], LAB_RIVAL_BATTLE["y"], "rival battle")
        return true
      end

      if starter_obtained?
        set_objective("starter_leave_lab", "travel", "Exit Oak's lab")
        transfer = LAB_EXIT_TRANSFER.merge(
          "map_id" => current_map_id,
          "key" => "#{current_map_id}:lab_exit:42"
        )
        @active_transfer = transfer
        navigate_to_transfer(transfer)
        return true
      end

      false
    end

    def route_2_south_story_tick
      return false unless trainer_has_pokedex?
      set_objective("story_enter_viridian_forest_gate", "travel", "Enter Viridian Forest gate")
      transfer = ROUTE_2_FOREST_GATE_TRANSFER.merge("map_id" => current_map_id)
      @active_transfer = transfer
      navigate_to_transfer(transfer)
      true
    end

    def forest_south_gate_story_tick
      return false unless trainer_has_pokedex?
      set_objective("story_enter_viridian_forest", "travel", "Enter Viridian Forest")
      transfer = FOREST_SOUTH_GATE_NORTH_TRANSFER.merge("map_id" => current_map_id)
      @active_transfer = transfer
      navigate_to_transfer(transfer)
      true
    end

    def viridian_forest_story_tick
      return false unless trainer_has_pokedex?
      return true if forest_pickup_tick
      set_objective("story_cross_viridian_forest", "travel", "Cross Viridian Forest")
      return true if safe_mode? && forest_story_route_step
      transfer = FOREST_NORTH_GATE_TRANSFER.merge("map_id" => current_map_id)
      @active_transfer = transfer
      navigate_to_transfer(transfer)
      true
    end

    def forest_story_route_step
      return false unless current_map_id.to_i == VIRIDIAN_FOREST_MAP_ID
      if forest_exit_ready?
        @active_transfer = FOREST_NORTH_GATE_TRANSFER.merge("map_id" => current_map_id)
        face_or_use_transfer(@active_transfer)
        @trying_to_move = false
        return true
      end
      target = forest_story_target
      AutoplayBot.status("forest route: #{target[0]},#{target[1]}")
      direct_step_toward(target[0], target[1], "forest route", 1200, false)
      true
    rescue => e
      AutoplayBot.log("forest story route failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def forest_exit_ready?
      return false unless defined?($game_player) && $game_player
      x = $game_player.x.to_i
      y = $game_player.y.to_i
      y <= 7 && x >= 12 && x <= 14
    rescue
      false
    end

    def forest_story_target
      return [13, 6] unless defined?($game_player) && $game_player
      x = $game_player.x.to_i
      y = $game_player.y.to_i
      return [43, 36] if y >= 34 && x < 36
      return [39, 29] if y >= 30 && x >= 36
      return [38, 18] if y >= 19 && x >= 36
      return [28, 18] if y >= 18 && x > 28
      return [24, 17] if y >= 17 && x > 24
      return [23, 11] if y > 11 && x >= 18
      return [18, 11] if y <= 12 && x > 18
      return [14, 16] if y < 16 && x >= 14
      return [11, 16] if y >= 16 && x > 11
      return [11, 8] if y > 8 && x <= 14
      [13, 6]
    rescue
      [13, 6]
    end

    def forest_north_gate_story_tick
      return false unless trainer_has_pokedex?
      set_objective("story_leave_viridian_forest", "travel", "Leave Viridian Forest")
      transfer = FOREST_NORTH_GATE_EXIT.merge("map_id" => current_map_id)
      @active_transfer = transfer
      navigate_to_transfer(transfer)
      true
    end

    def route_2_north_story_tick
      return false unless trainer_has_pokedex?
      set_objective("story_go_pewter", "travel", "Head to Pewter City")
      map_edge_step(ROUTE_2_PEWTER_EXIT["x"], ROUTE_2_PEWTER_EXIT["y"], 8, "Pewter City north")
      true
    end

    def pewter_city_story_tick
      return false unless trainer_has_pokedex?
      return true if optional_cleanup_allowed? && town_cleanup_tick
      return false if first_badge_obtained?
      set_objective("story_find_pewter_gym", "battle", "Find Pewter Gym")
      transfer = PEWTER_GYM_TRANSFER.merge("map_id" => current_map_id)
      @active_transfer = transfer
      navigate_to_transfer(transfer)
      true
    end

    def forest_pickup_tick
      return false unless current_map_id.to_i == VIRIDIAN_FOREST_MAP_ID
      item = safe_mode? ? current_forest_forage_target : current_map_item_target
      return false unless item
      safe_mode? ? collect_forest_forage_target(item) : collect_item_target(item)
      true
    rescue
      false
    end

    def forest_npc_tick
      return false unless current_map_id.to_i == VIRIDIAN_FOREST_MAP_ID
      return false unless AutoplayBot::Config.local_discovery?
      npc = current_forest_npc_target
      return false unless npc
      talk_to_npc_target(npc)
      true
    rescue
      false
    end

    def current_forest_npc_target
      return nil unless defined?($game_player) && $game_player
      if @active_forest_npc &&
         !npc_target_done?(@active_forest_npc) &&
         !npc_target_failed?(@active_forest_npc) &&
         forest_npc_still_reasonable?(@active_forest_npc)
        return @active_forest_npc
      end
      @active_forest_npc = nil
      candidates = forest_npc_records.reject { |npc| npc_target_done?(npc) || npc_target_failed?(npc) }
      scored = candidates.map do |npc|
        path = path_to_event_action(npc, adaptive_budget(600, "npc"))
        next nil unless path && path.length <= forest_npc_path_limit
        distance = (npc["x"].to_i - $game_player.x).abs + (npc["y"].to_i - $game_player.y).abs
        [path.length, distance, npc]
      end.compact
      target = scored.sort_by { |entry| [entry[0], entry[1]] }.map { |entry| entry[2] }.first
      @active_forest_npc = target if target
      target
    rescue
      nil
    end

    def forest_npc_records
      [
        forest_npc_record(38, 20, 37, "Kurt", "Kurt_overworld_by_Knuckles"),
        forest_npc_record(33, 38, 16, "Mushroom hunter", "BW (28)"),
        forest_npc_record(44, 64, 23, "Forest helper", "BW (82)")
      ]
    rescue
      []
    end

    def forest_npc_record(event_id, x, y, event_name, graphic = "")
      {
        "key" => "forest_npc:#{event_id}:#{x}:#{y}",
        "map_id" => VIRIDIAN_FOREST_MAP_ID,
        "event_id" => event_id,
        "event_name" => event_name,
        "graphic" => graphic,
        "x" => x,
        "y" => y,
        "trigger" => 0
      }
    end

    def forest_npc_still_reasonable?(npc)
      return true if forest_forage_action_ready?(npc)
      path = path_to_event_action(npc, adaptive_budget(600, "npc"))
      path && path.length <= forest_npc_path_limit + 6
    rescue
      false
    end

    def forest_npc_path_limit
      collector_cleanup_priority? ? 34 : 18
    rescue
      18
    end

    def collect_forest_forage_target(item)
      key = AutoplayBot::State.target_key(item, "item") rescue "item:#{current_map_id}:#{item["event_id"]}"
      record = item.merge(
        "map_id" => current_map_id,
        "frontier_kind" => "item",
        "frontier_key" => key
      )
      label = item_label(record)
      set_objective("forest_forage_#{current_map_id}_#{record["event_id"] || record["x"]}", "travel", label)
      if forest_forage_timed_out?(record)
        skip_forest_forage_target(record, "timed out")
        return
      end
      if forest_forage_action_ready?(record)
        activate_forest_forage_target(record, label)
        @trying_to_move = false
        return
      end
      path = forest_forage_path(record)
      unless path && !path.empty?
        skip_forest_forage_target(record, "blocked")
        return
      end
      dir = path.first
      AutoplayBot.status(path_status("spot item", path, dir))
      @trying_to_move = true
      AutoplayBot::InputQueue.hold_dir(dir, movement_hold_frames(path, 10))
    rescue => e
      AutoplayBot.log("forest forage failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    end

    def forest_forage_timed_out?(record)
      frame = (Graphics.frame_count rescue 0).to_i
      key = activation_key(record)
      position = defined?($game_player) && $game_player ? "#{$game_player.x},#{$game_player.y}" : "nopos"
      if !@forest_forage_attempt || @forest_forage_attempt["key"].to_s != key.to_s
        @forest_forage_attempt = {
          "key" => key,
          "started" => frame,
          "position" => position,
          "stalls" => 0
        }
        return false
      end
      if @forest_forage_attempt["position"].to_s == position.to_s
        @forest_forage_attempt["stalls"] = @forest_forage_attempt["stalls"].to_i + 1
      else
        @forest_forage_attempt["position"] = position
        @forest_forage_attempt["stalls"] = 0
      end
      return true if frame - @forest_forage_attempt["started"].to_i > 600
      @forest_forage_attempt["stalls"].to_i > 72
    rescue
      false
    end

    def skip_forest_forage_target(record, reason)
      AutoplayBot.status("forest forage: skip #{reason}")
      AutoplayBot.log("forest forage skip #{reason} target=#{record["x"]},#{record["y"]} from #{position_label}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      AutoplayBot::State.mark_target_failed(record, "forest forage #{reason}", "item") if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:mark_target_failed)
      mark_repeat_item_done_this_visit(record)
      @forest_forage_cache = nil
      @active_forest_forage = nil
      @pending_forest_forage_activation = nil
      @forest_forage_attempt = nil
      @trying_to_move = false
    rescue
      nil
    end

    def activate_forest_forage_target(record, label)
      frame = (Graphics.frame_count rescue 0).to_i
      @last_forest_forage_use_frame = -9999 if @last_forest_forage_use_frame.nil?
      return if frame - @last_forest_forage_use_frame.to_i < 12
      dir = direction_toward(record["x"].to_i, record["y"].to_i)
      key = activation_key(record)
      AutoplayBot.status("forest: #{label}")
      if @pending_forest_forage_activation &&
         @pending_forest_forage_activation["key"].to_s == key.to_s
        return if frame - @pending_forest_forage_activation["frame"].to_i < 1
        @pending_forest_forage_activation = nil
        @last_forest_forage_use_frame = frame
        mark_event_target_attempted(record)
        AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
        AutoplayBot::InputQueue.tap(:USE, 2)
        AutoplayBot::InputQueue.tap_next(:USE, 2) if AutoplayBot::InputQueue.respond_to?(:tap_next)
        if repeatable_item_target?(record)
          mark_repeat_item_done_this_visit(record)
        else
          mark_event_target_done(record)
        end
        @forest_forage_attempt = nil
        return
      end
      unless dir
        @pending_forest_forage_activation = nil
        @last_forest_forage_use_frame = frame
        mark_event_target_attempted(record)
        AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
        AutoplayBot::InputQueue.tap(:USE, 2)
        AutoplayBot::InputQueue.tap_next(:USE, 2) if AutoplayBot::InputQueue.respond_to?(:tap_next)
        if repeatable_item_target?(record)
          mark_repeat_item_done_this_visit(record)
        else
          mark_event_target_done(record)
        end
        @forest_forage_attempt = nil
        return
      end
      @pending_forest_forage_activation = {
        "key" => key,
        "dir" => dir.to_i,
        "frame" => frame
      }
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      AutoplayBot::InputQueue.hold_dir(dir, 1)
    rescue => e
      AutoplayBot.log("forest forage activation failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    end

    def forest_forage_action_ready?(record)
      return false unless defined?($game_player) && $game_player
      x = record["x"].to_i
      y = record["y"].to_i
      return true if $game_player.x.to_i == x && $game_player.y.to_i == y
      (($game_player.x.to_i - x).abs + ($game_player.y.to_i - y).abs) <= 1
    rescue
      false
    end

    def town_cleanup_tick
      return false unless optional_cleanup_allowed?
      return false unless TOWN_CLEANUP_MAP_IDS.include?(current_map_id.to_i)
      item = current_map_item_target
      if item
        collect_item_target(item)
        return true
      end
      npc = current_map_npc_target
      if npc
        talk_to_npc_target(npc)
        return true
      end
      transfer = current_map_building_transfer_target
      return false unless transfer
      enter_building_target(transfer)
      true
    rescue
      false
    end

    def building_cleanup_tick
      return false unless optional_cleanup_allowed?
      return false unless BUILDING_CLEANUP_MAP_IDS.include?(current_map_id.to_i)
      item = current_map_item_target
      if item
        collect_item_target(item)
        return true
      end
      npc = current_map_npc_target
      return false unless npc
      talk_to_npc_target(npc)
      true
    rescue
      false
    end

    def current_map_building_transfer_target
      return nil unless AutoplayBot::Config.frontier_explore?
      return nil unless defined?(AutoplayBot::WorldScanner) && defined?($game_player) && $game_player
      map = AutoplayBot::WorldScanner.current_map_data
      transfers = map && map["transfers"].is_a?(Array) ? map["transfers"] : []
      candidates = transfers.select do |transfer|
        building_transfer?(transfer) &&
          !transfer_visited_or_failed?(transfer)
      end
      candidates.min_by do |transfer|
        (transfer["x"].to_i - $game_player.x).abs + (transfer["y"].to_i - $game_player.y).abs
      end
    rescue
      nil
    end

    def transfer_visited_or_failed?(transfer)
      return false unless defined?(AutoplayBot::State)
      key = transfer["key"] || AutoplayBot::State.target_key(transfer, "transfer")
      kind = building_transfer?(transfer) ? "building" : "transfer"
      return true if optional_attempt_limit_reached?(transfer, kind)
      return true if recent_building_backtrack?(transfer)
      return true if building_transfer?(transfer) &&
                     AutoplayBot::State.respond_to?(:target_done?) &&
                     AutoplayBot::State.target_done?(transfer, "building")
      return true if AutoplayBot::State.respond_to?(:transfer_visited?) && AutoplayBot::State.transfer_visited?(key)
      return true if AutoplayBot::State.respond_to?(:target_failed?) && AutoplayBot::State.target_failed?(transfer, 900, kind)
      false
    rescue
      false
    end

    def enter_building_target(transfer)
      key = AutoplayBot::State.target_key(transfer, "building") rescue "building:#{current_map_id}:#{transfer["event_id"] || transfer["key"]}"
      record = transfer.merge(
        "map_id" => current_map_id,
        "frontier_kind" => "building",
        "frontier_key" => key
      )
      return if optional_attempt_limit_reached?(record, "building")
      AutoplayBot::State.enqueue_frontier(record, "building", 40) if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:enqueue_frontier)
      @active_transfer = record
      label = transfer_label(record)
      set_objective("building_#{current_map_id}_#{record["event_id"] || record["key"]}", "travel", label)
      AutoplayBot.status("spot building: #{label}")
      navigate_to_transfer(record)
    rescue => e
      AutoplayBot.log("building target failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    end

    def shop_restock_tick
      return false unless current_map_id.to_i == VIRIDIAN_MART_MAP_ID
      return false unless defined?(AutoplayBot::ShopPolicy) && AutoplayBot::ShopPolicy.restock_needed?
      set_objective("shop_restock_viridian", "shop", "Restock at Viridian Mart")
      navigate_to_event(VIRIDIAN_MART_CLERK.merge("map_id" => current_map_id))
      true
    rescue
      false
    end

    def pewter_gym_story_tick
      return false unless trainer_has_pokedex?
      @active_decision_goal = nil
      @decision_choice_cache = nil
      if first_badge_obtained?
        set_objective("story_leave_pewter_gym", "travel", "Leave Pewter Gym")
        transfer = recovery_exit_transfer
        if transfer
          @active_transfer = transfer
          navigate_to_transfer(transfer)
        else
          direct_step_toward(8, 23, "leave gym")
        end
        return true
      end
      set_objective("story_battle_brock", "battle", "Challenge Brock")
      event = brock_event_target
      AutoplayBot.status("brock: challenge") if defined?(AutoplayBot)
      navigate_to_event(event)
      true
    end

    def brock_event_target
      record = live_brock_event_record || scanned_brock_trainer_record || BROCK_EVENT
      record = record.merge(
        "map_id" => current_map_id,
        "event_id" => (record["event_id"] || BROCK_EVENT["event_id"]),
        "key" => (record["key"].to_s.empty? ? BROCK_EVENT["key"] : record["key"]),
        "event_name" => (record["event_name"].to_s.empty? ? "Brock" : record["event_name"]),
        "trigger" => 0
      )
      apply_brock_action_tile(record)
    rescue
      BROCK_EVENT.merge("map_id" => current_map_id)
    end

    def live_brock_event_record
      return nil unless current_map_id.to_i == PEWTER_GYM_MAP_ID
      return nil unless defined?($game_map) && $game_map && $game_map.respond_to?(:events) && $game_map.events
      event = $game_map.events[BROCK_EVENT["event_id"].to_i] rescue nil
      return nil unless event
      name = event.respond_to?(:name) ? event.name.to_s : ""
      {
        "key" => BROCK_EVENT["key"],
        "map_id" => current_map_id,
        "event_id" => BROCK_EVENT["event_id"],
        "event_name" => name.empty? ? "Brock" : name,
        "x" => event.respond_to?(:x) ? event.x : BROCK_EVENT["x"],
        "y" => event.respond_to?(:y) ? event.y : BROCK_EVENT["y"],
        "trigger" => 0,
        "call" => "pbTrainerBattle",
        "args" => "Brock"
      }
    rescue
      nil
    end

    def scanned_brock_trainer_record
      return nil unless current_map_id.to_i == PEWTER_GYM_MAP_ID
      map = AutoplayBot::WorldScanner.current_map_data if defined?(AutoplayBot::WorldScanner)
      trainers = map && map["trainers"].is_a?(Array) ? map["trainers"] : []
      trainers.find { |record| brock_event_record?(record) } ||
        trainers.find { |record| record.is_a?(Hash) && record["event_id"].to_i == BROCK_EVENT["event_id"].to_i }
    rescue
      nil
    end

    def brock_event_record?(record)
      return false unless record.is_a?(Hash)
      text = [
        record["key"],
        record["event_id"],
        record["event_name"],
        record["trainer_key"],
        record["args"],
        record["call"]
      ].compact.join(" ")
      return true if current_map_id.to_i == PEWTER_GYM_MAP_ID &&
                     record["event_id"].to_i == BROCK_EVENT["event_id"].to_i &&
                     text =~ /brock|leader/i
      text =~ /\bbrock\b/i
    rescue
      false
    end

    def apply_brock_action_tile(record)
      x = record["x"].to_i
      y = record["y"].to_i
      candidates = [
        [x, y + 1, 8],
        [x - 1, y, 6],
        [x + 1, y, 4],
        [x, y - 1, 2]
      ]
      chosen = candidates.find { |entry| brock_action_tile_open?(entry[0], entry[1]) } || candidates.first
      record.merge(
        "action_x" => chosen[0],
        "action_y" => chosen[1],
        "face_dir" => chosen[2],
        "kind" => "trainer"
      )
    rescue
      record.merge("action_x" => 9, "action_y" => 7, "face_dir" => 8, "kind" => "trainer")
    end

    def brock_action_tile_open?(x, y)
      return false unless AutoplayBot::Pathfinder.valid_tile?(x, y)
      return true if defined?($game_player) && $game_player && $game_player.x.to_i == x.to_i && $game_player.y.to_i == y.to_i
      return false if AutoplayBot::Pathfinder.event_blocks_tile?(x, y)
      true
    rescue
      false
    end

    def preferred_lab_map_id
      return 659 if game_switch?(883)
      77
    rescue
      77
    end

    def starter_ball_event
      candidates = starter_ball_candidates
      reachable = candidates.select { |event| event_reachable?(event) }
      pool = reachable.empty? ? candidates : reachable
      chosen = starter_ball_at_current_action_tile(pool) ||
               locked_random_starter_ball(pool) ||
               LAB_STARTER_BALL.merge("map_id" => current_map_id)
      if chosen && @last_starter_ball_key.to_s != chosen["key"].to_s
        @last_starter_ball_key = chosen["key"].to_s
        AutoplayBot.log("starter ball target #{chosen["key"]} at #{chosen["x"]},#{chosen["y"]}") if AutoplayBot.respond_to?(:log)
      end
      chosen
    rescue
      LAB_STARTER_BALL.merge("map_id" => current_map_id)
    end

    def starter_ball_candidates
      fixed = known_lab_starter_balls
      return fixed unless fixed.empty?
      scanned = scanned_starter_ball_events
      unique_events(fixed + scanned)
    rescue
      [LAB_STARTER_BALL.merge("map_id" => current_map_id)]
    end

    def starter_ball_at_current_action_tile(candidates)
      return nil unless defined?($game_player) && $game_player
      chosen = candidates.compact.find do |event|
        event["action_x"].to_i == $game_player.x.to_i &&
          event["action_y"].to_i == $game_player.y.to_i
      end
      if chosen
        @starter_ball_choice_key = chosen["key"].to_s
        AutoplayBot.status("starter: use nearby ball") if defined?(AutoplayBot)
      end
      chosen
    rescue
      nil
    end

    def known_lab_starter_balls
      case current_map_id.to_i
      when 77
        LAB_STARTER_BALLS.map { |event| event.merge("map_id" => current_map_id) }
      when 659
        [
          LAB_STARTER_BALL.merge(
            "key" => "oak_lab_custom:starter_ball",
            "map_id" => current_map_id,
            "event_id" => 8,
            "x" => 14,
            "y" => 14,
            "action_x" => 14,
            "action_y" => 16,
            "face_dir" => 8
          )
        ]
      else
        []
      end
    rescue
      []
    end

    def locked_random_starter_ball(candidates)
      candidates = candidates.compact
      return nil if candidates.empty?
      if @starter_ball_choice_key
        previous = candidates.find { |event| event["key"].to_s == @starter_ball_choice_key.to_s }
        return previous if previous
      end
      chosen = candidates[rand(candidates.length)]
      @starter_ball_choice_key = chosen["key"].to_s if chosen
      AutoplayBot.status("starter: random #{chosen["x"]},#{chosen["y"]}") if chosen && AutoplayBot.respond_to?(:status)
      AutoplayBot.log("exclusive choice auto-random starter #{chosen["key"]}") if chosen && AutoplayBot.respond_to?(:log)
      chosen
    rescue
      candidates.first
    end

    def scanned_starter_ball_events
      map = AutoplayBot::WorldScanner.current_map_data if defined?(AutoplayBot::WorldScanner)
      if (!map || !map["events"].is_a?(Array) || map["events"].empty?) &&
         defined?(AutoplayBot::WorldScanner) && AutoplayBot::WorldScanner.respond_to?(:scan_map)
        map = AutoplayBot::WorldScanner.scan_map(current_map_id)
      end
      events = map && map["events"].is_a?(Array) ? map["events"] : []
      events.select { |event| starter_ball_record?(event) }.map do |event|
        {
          "key" => "#{current_map_id}:starter_ball:#{event["id"]}",
          "map_id" => current_map_id,
          "event_id" => event["id"],
          "event_name" => event["name"].to_s.empty? ? "Starter Ball" : event["name"],
          "x" => event["x"],
          "y" => event["y"],
          "action_x" => event["x"],
          "action_y" => event["y"].to_i + 2,
          "face_dir" => 8,
          "trigger" => 0
        }
      end
    rescue
      []
    end

    def starter_ball_record?(event)
      return false unless event.is_a?(Hash)
      return false unless event["x"] && event["y"]
      return false unless starter_table_ball_position?(event["x"].to_i, event["y"].to_i)
      name = event["name"].to_s
      page_text = (event["pages"] || []).map { |page| page["script_digest"].to_s }.join(" ")
      name =~ /ball/i && page_text =~ /obtainStarter|Do you want to choose|pbAddPokemon/i
    rescue
      false
    end

    def starter_table_ball_position?(x, y)
      case current_map_id.to_i
      when 77
        y == 14 && x >= 13 && x <= 15
      when 659
        x == 14 && y == 14
      else
        true
      end
    rescue
      false
    end

    def unique_events(events)
      seen = {}
      events.compact.select do |event|
        key = "#{event["map_id"] || current_map_id}:#{event["x"]}:#{event["y"]}:#{event["event_id"]}"
        next false if seen[key]
        seen[key] = true
      end
    rescue
      events.compact
    end

    def event_reachable?(event)
      return false unless event && event["x"] && event["y"]
      !path_to_event_action(event, 4000).nil?
    rescue
      false
    end

    def starter_house_tick
      case current_map_id
      when *PLAYER_ROOM_MAP_IDS
        if wearing_starting_outfit?
          set_objective("starter_put_on_clothes", "story", "Put on clothes")
          apply_starter_outfit_if_owned!
          AutoplayBot.status("clothes: find outfit") unless starter_clothes_ready?
        end
        if should_check_bedroom_pc?
          set_objective("starter_bedroom_pc_potion", "story", "Check bedroom PC")
          navigate_to_event(BEDROOM_PC_EVENT.merge("map_id" => current_map_id))
          return true
        end
        set_objective("starter_leave_bedroom", "travel", "Use bedroom stairs")
        transfer = {
          "key" => "#{current_map_id}:1:43:11:5",
          "map_id" => current_map_id,
          "event_id" => 1,
          "x" => 10,
          "y" => 5,
          "trigger" => 1,
          "destination_map_id" => PLAYER_HOUSE_MAP_ID
        }
        @active_transfer = transfer
        direct_step_toward(transfer["x"].to_i, transfer["y"].to_i, "bedroom stairs")
        return true
      when *PLAYER_HOUSE_MAP_IDS
        apply_starter_outfit_if_owned! if current_map_id.to_i == PLAYER_HOUSE_MAP_ID && !starter_clothes_ready?
        if current_map_id.to_i == PLAYER_HOUSE_MAP_ID && !starter_clothes_ready?
          set_objective("starter_get_clothes", "story", "Get dressed")
          navigate_to_event(STARTER_CLOTHES_EVENT.merge("map_id" => current_map_id))
          return true
        end
        set_objective("starter_exit_house", "travel", "Exit downstairs")
        transfer = house_to_pallet_transfer || fallback_house_to_pallet_transfer
        @active_transfer = transfer
        transfer ? navigate_to_transfer(transfer) : direct_step_toward(7, 10, "house exit")
        return true
      end
      false
    end

    def should_check_bedroom_pc?
      return false unless current_map_id.to_i == STARTER_ROOM_MAP_ID
      return false if AutoplayBot::State.transfer_visited?(BEDROOM_PC_POTION_KEY)
      bedroom_pc_potion_available?
    rescue
      false
    end

    def bedroom_pc_potion_available?
      return false unless defined?($PokemonGlobal) && $PokemonGlobal
      storage = $PokemonGlobal.respond_to?(:pcItemStorage) ? $PokemonGlobal.pcItemStorage : nil
      return true if storage.nil? && defined?(PCItemStorage)
      return false unless storage && storage.respond_to?(:pbQuantity)
      storage.pbQuantity(:POTION).to_i > 0
    rescue
      false
    end

    def handle_bedroom_pc!
      return false unless current_map_id.to_i == STARTER_ROOM_MAP_ID
      return false unless should_check_bedroom_pc?
      withdraw_bedroom_pc_potion!
      true
    rescue => e
      AutoplayBot.log("bedroom PC handling failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      AutoplayBot::State.mark_transfer_visited(BEDROOM_PC_POTION_KEY) if defined?(AutoplayBot::State)
      true
    end

    def withdraw_bedroom_pc_potion!
      storage = $PokemonGlobal.pcItemStorage if $PokemonGlobal.respond_to?(:pcItemStorage)
      if storage.nil? && defined?(PCItemStorage)
        storage = PCItemStorage.new
        if $PokemonGlobal.respond_to?(:pcItemStorage=)
          $PokemonGlobal.pcItemStorage = storage
        else
          $PokemonGlobal.instance_variable_set(:@pcItemStorage, storage)
        end
      end
      withdrew = false
      if storage && storage.respond_to?(:pbQuantity) && storage.pbQuantity(:POTION).to_i > 0 &&
         defined?($PokemonBag) && $PokemonBag &&
         $PokemonBag.respond_to?(:pbCanStore?) && $PokemonBag.pbCanStore?(:POTION, 1)
        if storage.pbDeleteItem(:POTION, 1) && $PokemonBag.pbStoreItem(:POTION, 1)
          withdrew = true
        end
      end
      AutoplayBot::State.mark_transfer_visited(BEDROOM_PC_POTION_KEY)
      AutoplayBot::State.save!(true)
      if withdrew
        AutoplayBot.status("pc: withdrew Potion")
        AutoplayBot.log("withdrew Potion from bedroom PC") if AutoplayBot.respond_to?(:log)
      else
        AutoplayBot.status("pc: no Potion")
        AutoplayBot.log("bedroom PC potion unavailable or bag full") if AutoplayBot.respond_to?(:log)
      end
    rescue => e
      AutoplayBot.log("bedroom PC withdrawal failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      AutoplayBot::State.mark_transfer_visited(BEDROOM_PC_POTION_KEY) if defined?(AutoplayBot::State)
    end

    def set_objective(id, type, label)
      current = AutoplayBot::State.current_objective
      if current && current["id"].to_s == id.to_s
        set_supervisor_mode(supervisor_mode_for_type(type))
        return
      end
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      @pending_activation = nil
      @trying_to_move = false
      AutoplayBot::State.current_objective = {
        "id" => id.to_s,
        "type" => type.to_s,
        "label" => label.to_s
      }
      set_supervisor_mode(supervisor_mode_for_type(type))
      AutoplayBot.status("goal: #{label}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:status)
      AutoplayBot::Overlay.update(true) if defined?(AutoplayBot::Overlay)
      AutoplayBot.log("objective: #{label}") if AutoplayBot.respond_to?(:log)
    rescue
      nil
    end

    def supervisor_mode_for_type(type)
      case type.to_s
      when "battle" then "battle"
      when "travel" then "navigation"
      when "recovery" then "recovery"
      when "training" then "training"
      when "shop" then "shop"
      when "manual_needed" then "manual_needed"
      else "story"
      end
    rescue
      "story"
    end

    def find_transfer(from_map_id, to_map_id)
      map = AutoplayBot::WorldScanner.current_map_data
      return nil unless map && map["id"].to_i == from_map_id.to_i
      map["transfers"].find { |tr| tr["destination_map_id"].to_i == to_map_id.to_i }
    rescue
      nil
    end

    def starter_clothes_ready?
      return false unless defined?($Trainer) && $Trainer
      !wearing_starting_outfit?
    rescue
      false
    end

    def wearing_starting_outfit?
      outfit_id = starting_outfit_id
      return false if outfit_id.to_s.empty?
      if Object.new.respond_to?(:isWearingClothes, true)
        return Object.new.send(:isWearingClothes, outfit_id)
      end
      wearing_outfit_piece?($Trainer.respond_to?(:clothes) ? $Trainer.clothes : nil, outfit_id)
    rescue
      false
    end

    def apply_starter_outfit_if_owned!
      return false unless defined?($Trainer) && $Trainer
      outfit_id = default_outfit_id
      changed = false
      if outfit_owned?(trainer_outfit_collection(:unlocked_clothes), outfit_id) &&
         !wearing_outfit_piece?($Trainer.respond_to?(:clothes) ? $Trainer.clothes : nil, outfit_id)
        AutoplayBot.helper(:putOnClothes, outfit_id, true)
        unless wearing_outfit_piece?($Trainer.respond_to?(:clothes) ? $Trainer.clothes : nil, outfit_id)
          if $Trainer.respond_to?(:clothes=)
            $Trainer.clothes = outfit_id
          else
            $Trainer.instance_variable_set(:@clothes, outfit_id)
          end
          refresh_player_outfit_safely
        end
        changed = true if wearing_outfit_piece?($Trainer.respond_to?(:clothes) ? $Trainer.clothes : nil, outfit_id)
      end
      if outfit_owned?(trainer_outfit_collection(:unlocked_hats), outfit_id) &&
         !wearing_default_hat?(outfit_id)
        AutoplayBot.helper(:putOnHat, outfit_id, true, false)
        unless wearing_default_hat?(outfit_id)
          if $Trainer.respond_to?(:set_hat)
            $Trainer.set_hat(outfit_id, false)
          elsif $Trainer.respond_to?(:hat=)
            $Trainer.hat = outfit_id
          else
            $Trainer.instance_variable_set(:@hat, outfit_id)
          end
          refresh_player_outfit_safely
        end
        changed = true if wearing_default_hat?(outfit_id)
      end
      if changed
        AutoplayBot.status("clothes: wearing #{outfit_id}")
        AutoplayBot.log("applied starter outfit #{outfit_id}") if AutoplayBot.respond_to?(:log)
      end
      changed
    rescue => e
      AutoplayBot.log("starter outfit apply failed: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      false
    end

    def starting_outfit_id
      return STARTING_OUTFIT if defined?(STARTING_OUTFIT)
      "pikajamas"
    rescue
      "pikajamas"
    end

    def trainer_outfit_collection(method_name)
      return [] unless defined?($Trainer) && $Trainer && $Trainer.respond_to?(method_name)
      value = $Trainer.send(method_name)
      value.respond_to?(:each) ? value : []
    rescue
      []
    end

    def outfit_owned?(collection, outfit_id)
      return false unless collection && collection.respond_to?(:any?)
      collection.any? { |entry| same_outfit_id?(entry, outfit_id) }
    rescue
      false
    end

    def wearing_outfit_piece?(value, outfit_id)
      same_outfit_id?(value, outfit_id)
    rescue
      false
    end

    def wearing_default_hat?(outfit_id)
      return false unless defined?($Trainer) && $Trainer
      hats = []
      hats << $Trainer.hat if $Trainer.respond_to?(:hat)
      hats << $Trainer.hat2 if $Trainer.respond_to?(:hat2)
      hats.any? { |hat| same_outfit_id?(hat, outfit_id) }
    rescue
      false
    end

    def same_outfit_id?(left, right)
      left.to_s == right.to_s
    rescue
      false
    end

    def refresh_player_outfit_safely
      if defined?($game_map) && $game_map && $game_map.respond_to?(:refreshPlayerOutfit)
        $game_map.refreshPlayerOutfit
        return
      end
      receiver = Object.new
      receiver.send(:refreshPlayerOutfit) if receiver.respond_to?(:refreshPlayerOutfit, true)
    rescue
      nil
    end

    def default_outfit_id
      gender = if defined?(VAR_TRAINER_GENDER)
                 AutoplayBot.helper(:pbGet, VAR_TRAINER_GENDER)
               elsif defined?($game_variables) && $game_variables
                 $game_variables[52]
               else
                 0
               end
      female = defined?(GENDER_FEMALE) ? GENDER_FEMALE : 1
      if gender.to_i == female.to_i
        return DEFAULT_OUTFIT_FEMALE if defined?(DEFAULT_OUTFIT_FEMALE)
        return "leaf"
      end
      return DEFAULT_OUTFIT_MALE if defined?(DEFAULT_OUTFIT_MALE)
      "red"
    rescue
      "red"
    end

    def game_switch?(id)
      return false unless defined?($game_switches) && $game_switches
      $game_switches[id.to_i] == true
    rescue
      false
    end

    def game_variable(id)
      return nil unless defined?($game_variables) && $game_variables
      $game_variables[id.to_i]
    rescue
      nil
    end

    def party_count
      return 0 unless defined?($Trainer) && $Trainer && $Trainer.respond_to?(:party)
      $Trainer.party.compact.length
    rescue
      0
    end

    def trainer_has_pokedex?
      defined?($Trainer) && $Trainer && $Trainer.respond_to?(:has_pokedex) && $Trainer.has_pokedex
    rescue
      false
    end

    def first_badge_obtained?
      return true if game_switch?(4)
      return false unless defined?($Trainer) && $Trainer
      return true if $Trainer.respond_to?(:badge_count) && $Trainer.badge_count.to_i >= 1
      return false unless $Trainer.respond_to?(:badges)
      badges = $Trainer.badges
      badges && badges[0] == true
    rescue
      false
    end

    def starter_obtained?
      party_count > 0 || game_switch?(59) || game_switch?(52) || game_switch?(61) || game_switch?(220)
    rescue
      false
    end

    def wait_or_interact(id, label, event_record, wait_frames = 240)
      frame = Graphics.frame_count rescue 0
      @wait_objective_id = nil if @wait_objective_id.nil?
      if @wait_objective_id.to_s != id.to_s
        @wait_objective_id = id.to_s
        @wait_started_frame = frame.to_i
      end
      if frame.to_i - @wait_started_frame.to_i >= wait_frames.to_i
        event = event_record.merge("map_id" => current_map_id)
        AutoplayBot.status("#{label}: nudging event")
        navigate_to_event(event)
      else
        AutoplayBot.status(label)
        @trying_to_move = false
      end
    rescue
      AutoplayBot.status(label) if AutoplayBot.respond_to?(:status)
    end

    def navigate_to_transfer(transfer)
      @active_route_target = nil
      return viridian_mart_exit_rail!(transfer) if viridian_mart_exit_transfer?(transfer)
      transfer_kind = record_frontier_kind(transfer, building_transfer?(transfer) ? "building" : "transfer")
      if optional_attempt_limit_reached?(transfer, transfer_kind)
        @trying_to_move = false
        return
      end
      cooldown_key = target_cooldown_key("transfer", transfer)
      if target_on_cooldown?(cooldown_key)
        AutoplayBot.status("planning: waiting on route")
        @trying_to_move = false
        return
      end
      return if close_building_transfer_rail!(transfer)
      include_adjacent = transfer["trigger"].to_i != 1
      budget = adaptive_budget(6000, "transfer")
      path = active_route_plan_path("transfer", transfer)
      unless path
        path = cached_path(cooldown_key) do
          AutoplayBot::Pathfinder.path_to(transfer["x"], transfer["y"], budget, include_adjacent)
        end
        store_active_route_plan("transfer", transfer, path) if path
      end
      if path.nil?
        path = AutoplayBot::Pathfinder.path_to(transfer["x"], transfer["y"], budget) unless include_adjacent
        store_active_route_plan("transfer", transfer, path) if path
      end
      if path.nil?
        if starter_bedroom_transfer?(transfer)
          direct_step_toward(transfer["x"].to_i, transfer["y"].to_i, "bedroom stairs")
          return
        end
        if optional_interaction_target?(transfer, transfer_kind)
          key = optional_interaction_key(transfer, transfer_kind)
          AutoplayBot::State.mark_target_failed(transfer, "unreachable #{transfer_kind}", transfer_kind) if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:mark_target_failed)
          AutoplayBot::State.touch_frontier(key, false, "unreachable") if key && defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:touch_frontier)
        end
        cool_down_target(cooldown_key)
        AutoplayBot.log("unreachable #{transfer_kind} #{transfer["key"]}; deferring from #{position_label}") if AutoplayBot.respond_to?(:log)
        @trying_to_move = false
        return
      end
      if path.empty?
        if activation_on_cooldown?(activation_key(transfer))
          AutoplayBot.status("activate: cooldown")
          @trying_to_move = false
          return
        end
        AutoplayBot.log("activating #{transfer["key"] || transfer["event_name"]} at #{position_label}") if AutoplayBot.respond_to?(:log)
        AutoplayBot.status("enter: #{short_target_label(transfer)}")
        mark_event_target_attempted(transfer)
        face_or_use_transfer(transfer)
        @active_route_plan = nil
        @trying_to_move = false
        return
      end
      @trying_to_move = true
      log_step("transfer", transfer, path.first)
      AutoplayBot.status(path_status("path transfer", path, path.first))
      @last_route_dir = path.first
      return if try_interact_with_live_route_blocker(path.first, "transfer path")
      AutoplayBot::InputQueue.hold_dir(path.first, movement_hold_frames(path))
    end

    def close_building_transfer_rail!(transfer)
      return false unless transfer.is_a?(Hash)
      return false unless transfer["trigger"].to_i == 1
      return false unless building_transfer?(transfer)
      return false unless defined?($game_player) && $game_player
      tx = transfer["x"].to_i
      ty = transfer["y"].to_i
      distance = (tx - $game_player.x.to_i).abs + (ty - $game_player.y.to_i).abs
      return false if distance > 5

      @active_route_plan = nil
      @active_route_target = nil
      @trying_to_move = true
      if at_tile?(tx, ty)
        AutoplayBot.status("door: enter #{short_target_label(transfer)}")
        AutoplayBot.log("door rail activating #{transfer["key"] || transfer["event_name"]} at #{position_label}") if door_rail_log_due?
        face_or_use_transfer(transfer)
        @trying_to_move = false
        return true
      end

      dir = door_centering_direction(tx, ty)
      unless dir
        path = AutoplayBot::Pathfinder.path_to(tx, ty, adaptive_budget(900, "transfer"), false) rescue nil
        dir = path && !path.empty? ? path.first.to_i : direction_toward(tx, ty)
      end
      unless dir
        @trying_to_move = false
        return false
      end
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      AutoplayBot::InputQueue.hold_dir(dir, one_tile_hold_frames(dir)) if defined?(AutoplayBot::InputQueue)
      @last_route_dir = dir
      AutoplayBot.status("door: center #{dir_label(dir)}")
      AutoplayBot.log("door rail #{short_target_label(transfer)} #{dir_label(dir)} target=#{tx},#{ty} from #{position_label}") if door_rail_log_due?
      true
    rescue => e
      AutoplayBot.log("door rail failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def door_centering_direction(tx, ty)
      return nil unless defined?($game_player) && $game_player
      px = $game_player.x.to_i
      py = $game_player.y.to_i
      candidates = []
      candidates << (px < tx ? 6 : 4) if px != tx
      candidates << (py < ty ? 2 : 8) if py != ty
      # If the doorway edge rejects the first axis, immediately try another
      # axis instead of bouncing against the building facade.
      candidates += [8, 2, 4, 6]
      candidates.compact.map(&:to_i).uniq.find { |dir| direction_passable?(dir) }
    rescue
      nil
    end

    def one_tile_hold_frames(_dir = nil)
      [[estimated_tile_frames, 3].max, 10].min
    rescue
      5
    end

    def door_rail_log_due?
      frame = (Graphics.frame_count rescue 0).to_i
      @last_door_rail_log_frame ||= -9999
      return false if frame - @last_door_rail_log_frame.to_i < 80
      @last_door_rail_log_frame = frame
      true
    rescue
      false
    end

    def viridian_mart_exit_transfer?(transfer)
      return false unless transfer
      return false unless current_map_id.to_i == VIRIDIAN_MART_MAP_ID
      return false unless transfer["destination_map_id"].to_i == VIRIDIAN_CITY_MAP_ID
      transfer["y"].to_i >= 12
    rescue
      false
    end

    def handle_viridian_mart_exit_loop(reason, _pos = nil)
      return false unless viridian_mart_exit_goal_active?
      AutoplayBot.log("mart exit rail recovering #{reason} at #{position_label}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      viridian_mart_exit_rail!(@active_transfer || VIRIDIAN_MART_EXIT.merge("map_id" => current_map_id), "unstuck")
      true
    rescue
      false
    end

    def viridian_mart_exit_goal_active?
      return false unless current_map_id.to_i == VIRIDIAN_MART_MAP_ID
      return true if viridian_mart_exit_transfer?(@active_transfer)
      objective = defined?(AutoplayBot::State) ? AutoplayBot::State.current_objective : nil
      text = [objective && objective["id"], objective && objective["label"], objective && objective["type"]].compact.join(" ")
      text =~ /leave.*mart|mart.*exit|oak_parcel_leave_mart|story_leave_mart/i
    rescue
      false
    end

    def viridian_mart_exit_rail!(transfer = nil, reason = nil)
      return false unless defined?($game_player) && $game_player
      transfer ||= VIRIDIAN_MART_EXIT.merge("map_id" => current_map_id)
      @active_transfer = transfer
      @active_event_target = nil
      @active_route_plan = nil
      @active_route_target = {
        "kind" => "route",
        "key" => "viridian_mart_exit_rail",
        "x" => 6,
        "y" => 13
      }
      dir = viridian_mart_exit_direction
      unless dir
        @trying_to_move = false
        AutoplayBot.status("Mart exit: waiting")
        return true
      end
      @trying_to_move = true
      @last_route_dir = dir
      @last_no_path_dir = nil
      AutoplayBot::InputQueue.clear if defined?(AutoplayBot::InputQueue)
      frames = mart_exit_hold_frames(dir)
      AutoplayBot::InputQueue.hold_dir(dir, frames)
      suffix = reason.to_s.empty? ? "" : " #{reason}"
      AutoplayBot.status("Mart exit#{suffix}: #{dir_label(dir)}")
      true
    rescue => e
      AutoplayBot.log("mart exit rail failed: #{e.class}: #{e.message}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
      false
    end

    def viridian_mart_exit_direction
      x = $game_player.x.to_i
      y = $game_player.y.to_i
      door_columns = [5, 6, 7]
      if door_columns.include?(x)
        return 2 if y <= 13
        return 2
      end
      path = AutoplayBot::Pathfinder.find_path_to_any([[5, 13], [6, 13], [7, 13]], adaptive_budget(500, "transfer")) rescue nil
      if path && !path.empty? && path.first.to_i != 8
        return path.first.to_i
      end
      return 6 if x < 6
      return 4 if x > 6
      2
    rescue
      2
    end

    def mart_exit_hold_frames(dir)
      base = movement_hold_frames([dir, dir], 8)
      [[base, 6].max, 18].min
    rescue
      8
    end

    def starter_bedroom_transfer?(transfer)
      PLAYER_ROOM_MAP_IDS.include?(current_map_id.to_i) &&
        transfer["destination_map_id"].to_i == PLAYER_HOUSE_MAP_ID
      rescue
      false
    end

    def map_edge_step(x, y, exit_dir, label)
      @active_transfer = nil
      @active_event_target = nil
      @active_route_target = { "kind" => "route", "key" => label, "x" => x.to_i, "y" => y.to_i }
      edge_plan = plan_map_edge_step(x.to_i, y.to_i, exit_dir.to_i)
      if edge_plan && edge_plan["hold"]
        AutoplayBot.log("map edge #{label} dir=#{exit_dir} from #{position_label}") if AutoplayBot.respond_to?(:log)
        AutoplayBot.status("#{label}: exiting")
        @trying_to_move = true
        @last_route_dir = exit_dir
        AutoplayBot::InputQueue.hold_dir(exit_dir, movement_hold_frames([exit_dir, exit_dir, exit_dir], 12))
        return
      end
      if edge_plan && edge_plan["path"] && !edge_plan["path"].empty?
        dir = edge_plan["path"].first
        log_direct_step(label, dir, x, y)
        AutoplayBot.status(path_status(label, edge_plan["path"], dir))
        @trying_to_move = true
        @last_route_dir = dir
        return if try_interact_with_live_route_blocker(dir, "route path")
        AutoplayBot::InputQueue.hold_dir(dir, movement_hold_frames(edge_plan["path"], 12))
        return
      end
      direct_step_toward(x.to_i, y.to_i, label, adaptive_budget(2400, "transfer"), false)
    end

    def at_tile?(x, y)
      defined?($game_player) && $game_player &&
        $game_player.x.to_i == x.to_i &&
        $game_player.y.to_i == y.to_i
    rescue
      false
    end

    def plan_map_edge_step(x, y, exit_dir)
      return nil unless defined?($game_player) && $game_player
      return { "hold" => true } if at_tile?(x, y)
      return { "hold" => true } if at_exit_edge?(exit_dir) && edge_exit_passable?(exit_dir)
      return { "hold" => true } if near_exit_edge?(exit_dir, 4) && edge_exit_passable?(exit_dir)

      budget = adaptive_budget(2400, "transfer")
      targets = edge_exit_candidates(x, y, exit_dir, 12, false)
      path = AutoplayBot::Pathfinder.find_path_to_any(targets, budget) if targets && !targets.empty?
      return { "path" => path } if path

      targets = edge_exit_candidates(x, y, exit_dir, nil, false)
      path = AutoplayBot::Pathfinder.find_path_to_any(targets, budget) if targets && !targets.empty?
      return { "path" => path } if path

      targets = edge_exit_candidates(x, y, exit_dir, 16, true)
      path = AutoplayBot::Pathfinder.find_path_to_any(targets, budget) if targets && !targets.empty?
      return { "path" => path } if path

      targets = edge_exit_candidates(x, y, exit_dir, nil, true)
      path = AutoplayBot::Pathfinder.find_path_to_any(targets, budget) if targets && !targets.empty?
      return { "path" => path } if path
      nil
    rescue => e
      AutoplayBot.log("edge plan failed for #{x},#{y} dir=#{exit_dir}: #{e.class}: #{e.message}") if AutoplayBot.respond_to?(:log)
      nil
    end

    def edge_exit_candidates(x, y, exit_dir, radius = nil, include_approach = false)
      bounds = map_bounds
      return [] unless bounds
      xs = edge_axis_values(x, bounds["width"], radius)
      ys = edge_axis_values(y, bounds["height"], radius)
      targets = []
      case exit_dir.to_i
      when 8
        add_edge_targets(targets, xs, 0, exit_dir)
        add_edge_approach_targets(targets, xs, 1, [bounds["height"] - 1, 6].min, exit_dir) if include_approach
      when 2
        edge_y = bounds["height"] - 1
        add_edge_targets(targets, xs, edge_y, exit_dir)
        add_edge_approach_targets(targets, xs, [edge_y - 6, 0].max, edge_y - 1, exit_dir) if include_approach
      when 4
        add_edge_targets_for_y(targets, 0, ys, exit_dir)
        add_edge_approach_targets_for_y(targets, 1, [bounds["width"] - 1, 6].min, ys, exit_dir) if include_approach
      when 6
        edge_x = bounds["width"] - 1
        add_edge_targets_for_y(targets, edge_x, ys, exit_dir)
        add_edge_approach_targets_for_y(targets, [edge_x - 6, 0].max, edge_x - 1, ys, exit_dir) if include_approach
      end
      targets.uniq
    rescue
      []
    end

    def add_edge_targets(targets, xs, y, exit_dir)
      xs.each do |x|
        next unless AutoplayBot::Pathfinder.valid_tile?(x, y)
        next unless AutoplayBot::Pathfinder.passable?(x, y, exit_dir)
        targets << [x, y]
      end
    rescue
      nil
    end

    def add_edge_targets_for_y(targets, x, ys, exit_dir)
      ys.each do |y|
        next unless AutoplayBot::Pathfinder.valid_tile?(x, y)
        next unless AutoplayBot::Pathfinder.passable?(x, y, exit_dir)
        targets << [x, y]
      end
    rescue
      nil
    end

    def add_edge_approach_targets(targets, xs, y1, y2, exit_dir)
      return if y2 < y1
      xs.each do |x|
        (y1..y2).each do |y|
          next unless AutoplayBot::Pathfinder.valid_tile?(x, y)
          next unless AutoplayBot::Pathfinder.passable?(x, y, exit_dir)
          targets << [x, y]
        end
      end
    rescue
      nil
    end

    def add_edge_approach_targets_for_y(targets, x1, x2, ys, exit_dir)
      return if x2 < x1
      (x1..x2).each do |x|
        ys.each do |y|
          next unless AutoplayBot::Pathfinder.valid_tile?(x, y)
          next unless AutoplayBot::Pathfinder.passable?(x, y, exit_dir)
          targets << [x, y]
        end
      end
    rescue
      nil
    end

    def edge_axis_values(center, limit, radius = nil)
      return [] if limit.to_i <= 0
      if radius
        min = [center.to_i - radius.to_i, 0].max
        max = [center.to_i + radius.to_i, limit.to_i - 1].min
        return (min..max).to_a.sort_by { |value| (value - center.to_i).abs }
      end
      (0...limit.to_i).to_a.sort_by { |value| (value - center.to_i).abs }
    rescue
      []
    end

    def map_bounds
      return nil unless defined?($game_map) && $game_map
      width = $game_map.respond_to?(:width) ? $game_map.width.to_i : 0
      height = $game_map.respond_to?(:height) ? $game_map.height.to_i : 0
      return nil if width <= 0 || height <= 0
      { "width" => width, "height" => height }
    rescue
      nil
    end

    def at_exit_edge?(exit_dir)
      bounds = map_bounds
      return false unless bounds && defined?($game_player) && $game_player
      case exit_dir.to_i
      when 8 then $game_player.y.to_i <= 0
      when 2 then $game_player.y.to_i >= bounds["height"] - 1
      when 4 then $game_player.x.to_i <= 0
      when 6 then $game_player.x.to_i >= bounds["width"] - 1
      else false
      end
    rescue
      false
    end

    def near_exit_edge?(exit_dir, distance)
      bounds = map_bounds
      return false unless bounds && defined?($game_player) && $game_player
      case exit_dir.to_i
      when 8 then $game_player.y.to_i <= distance.to_i
      when 2 then $game_player.y.to_i >= bounds["height"] - 1 - distance.to_i
      when 4 then $game_player.x.to_i <= distance.to_i
      when 6 then $game_player.x.to_i >= bounds["width"] - 1 - distance.to_i
      else false
      end
    rescue
      false
    end

    def edge_exit_passable?(exit_dir)
      return false unless defined?($game_player) && $game_player
      AutoplayBot::Pathfinder.passable?($game_player.x, $game_player.y, exit_dir)
    rescue
      false
    end

    def direct_step_toward(x, y, label, max_nodes = 2400, allow_direct_fallback = true)
      @active_transfer = nil
      @active_event_target = nil
      @active_route_target = { "kind" => "route", "key" => label, "x" => x.to_i, "y" => y.to_i }
      cooldown_key = target_cooldown_key("direct", { "key" => label, "x" => x, "y" => y })
      if target_on_cooldown?(cooldown_key)
        AutoplayBot.status("#{label}: waiting")
        @trying_to_move = false
        return
      end
      path = begin
        cached_path(cooldown_key) do
          AutoplayBot::Pathfinder.path_to(x, y, adaptive_budget(max_nodes, "event"), false)
        end
      rescue
        nil
      end
      if path.nil? && !allow_direct_fallback
        AutoplayBot.status("#{label}: searching path")
        log_no_route_path(label, x, y)
        cool_down_target(cooldown_key)
        @trying_to_move = false
        return
      end
      dir = path && !path.empty? ? path.first : fallback_route_direction(x, y, label)
      unless dir
        AutoplayBot.log("direct step reached #{label}; pressing use at #{position_label}") if AutoplayBot.respond_to?(:log)
        AutoplayBot.status("#{label}: use")
        cool_down_target(cooldown_key, 45)
        AutoplayBot::InputQueue.tap(:USE, 1)
        return
      end
      log_direct_step(label, dir, x, y)
      AutoplayBot.status(path_status(label, path, dir))
      @trying_to_move = true
      @last_route_dir = dir
      return if try_interact_with_live_route_blocker(dir, "direct path")
      AutoplayBot::InputQueue.hold_dir(dir, movement_hold_frames(path))
    end

    def fallback_route_direction(x, y, label = nil)
      dir = best_progress_direction(x, y)
      return dir if dir
      local_direction_toward(x, y) || direction_toward(x, y)
    rescue
      direction_toward(x, y)
    end

    def guarded_route_direction(path, x, y, label)
      return nil unless path && path.respond_to?(:empty?) && !path.empty?
      return nil unless defined?($game_player) && $game_player
      path_dir = path.first.to_i
      return path_dir if route_step_improves_target?(path_dir, x, y)
      return path_dir unless route_progress_guard_enabled?(label)
      progress_dir = best_progress_direction(x, y)
      return path_dir unless progress_dir && progress_dir.to_i != path_dir
      log_route_guard(label, path_dir, progress_dir, x, y)
      progress_dir
    rescue
      nil
    end

    def route_progress_guard_enabled?(label)
      objective = defined?(AutoplayBot::State) ? AutoplayBot::State.current_objective : nil
      type = objective && objective["type"].to_s
      return true if ["story", "travel", "battle"].include?(type)
      label.to_s =~ /oak|rival|starter|route|exit|leave|forest|brock|gym|mart|stairs|house/i
    rescue
      true
    end

    def route_step_improves_target?(dir, x, y)
      return true unless defined?($game_player) && $game_player
      current = manhattan_distance($game_player.x, $game_player.y, x, y)
      dx, dy = direction_delta(dir)
      after = manhattan_distance($game_player.x.to_i + dx.to_i, $game_player.y.to_i + dy.to_i, x, y)
      after < current
    rescue
      true
    end

    def best_progress_direction(x, y)
      return nil unless defined?($game_player) && $game_player
      current = manhattan_distance($game_player.x, $game_player.y, x, y)
      reverse = { 2 => 8, 8 => 2, 4 => 6, 6 => 4 }[@last_route_dir.to_i]
      candidates = [2, 4, 6, 8].select { |dir| direction_passable?(dir) }
      candidates = candidates.select do |dir|
        dx, dy = direction_delta(dir)
        manhattan_distance($game_player.x.to_i + dx.to_i, $game_player.y.to_i + dy.to_i, x, y) < current
      end
      return nil if candidates.empty?
      candidates.min_by do |dir|
        dx, dy = direction_delta(dir)
        nx = $game_player.x.to_i + dx.to_i
        ny = $game_player.y.to_i + dy.to_i
        visits = (@position_history || []).count { |entry| entry[0].to_i == current_map_id.to_i && entry[1].to_i == nx && entry[2].to_i == ny }
        [manhattan_distance(nx, ny, x, y), visits, dir == reverse ? 1 : 0]
      end
    rescue
      nil
    end

    def manhattan_distance(ax, ay, bx, by)
      (ax.to_i - bx.to_i).abs + (ay.to_i - by.to_i).abs
    rescue
      999
    end

    def log_route_guard(label, old_dir, new_dir, x, y)
      frame = Graphics.frame_count rescue 0
      @last_route_guard_log_frame = -9999 if @last_route_guard_log_frame.nil?
      return if frame.to_i - @last_route_guard_log_frame.to_i < 90
      @last_route_guard_log_frame = frame.to_i
      AutoplayBot.status("#{label}: correct #{dir_label(new_dir)}")
      AutoplayBot.log("route guard #{label}: #{dir_label(old_dir)} -> #{dir_label(new_dir)} target=#{x},#{y} from #{position_label}") if AutoplayBot.respond_to?(:log)
    rescue
      nil
    end

    def no_path_step_toward(x, y, label)
      dir = local_direction_toward(x.to_i, y.to_i)
      unless dir
        AutoplayBot.status("#{label}: blocked")
        @trying_to_move = false
        return
      end
      AutoplayBot.status("#{label}: dir #{dir}")
      @last_no_path_dir = dir
      @last_route_dir = dir
      @trying_to_move = true
      return if try_interact_with_live_route_blocker(dir, "no path")
      AutoplayBot::InputQueue.hold_dir(dir, movement_hold_frames([dir, dir], 10))
    rescue
      @trying_to_move = false
    end

    def local_direction_toward(x, y)
      return nil unless defined?($game_player) && $game_player
      current_x = $game_player.x.to_i
      current_y = $game_player.y.to_i
      preferred = []
      dx = x.to_i - current_x
      dy = y.to_i - current_y
      if dy.abs >= dx.abs
        preferred << (dy > 0 ? 2 : 8) if dy != 0
        preferred << (dx > 0 ? 6 : 4) if dx != 0
      else
        preferred << (dx > 0 ? 6 : 4) if dx != 0
        preferred << (dy > 0 ? 2 : 8) if dy != 0
      end
      preferred += [8, 6, 4, 2]
      reverse = { 2 => 8, 8 => 2, 4 => 6, 6 => 4 }[@last_no_path_dir.to_i]
      candidates = preferred.compact.uniq.select { |dir| direction_passable?(dir) }
      candidates_without_reverse = candidates.reject { |dir| dir == reverse }
      candidates = candidates_without_reverse unless candidates_without_reverse.empty?
      candidates.min_by do |dir|
        nx = current_x + (dir == 6 ? 1 : dir == 4 ? -1 : 0)
        ny = current_y + (dir == 2 ? 1 : dir == 8 ? -1 : 0)
        [(x.to_i - nx).abs + (y.to_i - ny).abs, dir == reverse ? 1 : 0]
      end
    rescue
      nil
    end

    def log_no_route_path(label, x, y)
      frame = Graphics.frame_count rescue 0
      @last_no_route_log_frame = -9999 if @last_no_route_log_frame.nil?
      return if frame.to_i - @last_no_route_log_frame.to_i < 120
      @last_no_route_log_frame = frame.to_i
      AutoplayBot.log("no route path to #{label} target=#{x},#{y} from #{position_label}") if AutoplayBot.respond_to?(:log)
    rescue
      nil
    end

    def log_direct_step(label, dir, x, y)
      frame = Graphics.frame_count rescue 0
      @last_direct_step_log_frame = -9999 if @last_direct_step_log_frame.nil?
      return if frame.to_i - @last_direct_step_log_frame.to_i < 180
      @last_direct_step_log_frame = frame.to_i
      AutoplayBot.log("direct step #{label} dir=#{dir} target=#{x},#{y} from #{position_label}") if AutoplayBot.respond_to?(:log)
    rescue
      nil
    end

    def navigate_to_event(event_record)
      @active_route_target = nil
      @active_event_target = event_record if event_record.is_a?(Hash)
      event_kind = record_frontier_kind(event_record, "event")
      if optional_attempt_limit_reached?(event_record, event_kind)
        @trying_to_move = false
        return
      end
      cooldown_key = target_cooldown_key("event", event_record)
      if target_on_cooldown?(cooldown_key)
        AutoplayBot.status("activate: waiting")
        @trying_to_move = false
        return
      end
      path = cached_path(cooldown_key) do
        path_to_event_action(event_record, adaptive_budget(4000, event_record["frontier_kind"] || "event"))
      end
      if path.nil?
        frontier_kind = event_record["frontier_kind"].to_s
        if !frontier_kind.empty? && defined?(AutoplayBot::State)
          key = event_record["frontier_key"] || (AutoplayBot::State.target_key(event_record, frontier_kind) rescue nil)
          AutoplayBot::State.mark_target_failed(key || event_record, "unreachable #{frontier_kind}", frontier_kind) if AutoplayBot::State.respond_to?(:mark_target_failed)
          AutoplayBot::State.touch_frontier(key, false, "unreachable #{frontier_kind}") if key && AutoplayBot::State.respond_to?(:touch_frontier)
        else
          AutoplayBot::State.mark_target_failed(event_record, "unreachable event", "event") if defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:mark_target_failed)
        end
        cool_down_target(cooldown_key)
        if frontier_kind.empty?
          AutoplayBot::Runtime.manual_needed("unreachable event #{event_record["event_name"]} on map #{current_map_id}") if defined?(AutoplayBot::Runtime)
        else
          AutoplayBot.status("frontier: defer unreachable")
        end
        @trying_to_move = false
        return
      end
      if path.empty?
        if activation_on_cooldown?(activation_key(event_record))
          AutoplayBot.status("activate: cooldown")
          @trying_to_move = false
          return
        end
        AutoplayBot.log("interacting with #{event_record["event_name"]} at #{position_label}") if AutoplayBot.respond_to?(:log)
        AutoplayBot.status("interact: #{short_target_label(event_record)}")
        mark_event_target_attempted(event_record)
        face_or_use_transfer(event_record)
        @trying_to_move = false
        return
      end
      @trying_to_move = true
      log_step("event", event_record, path.first)
      AutoplayBot.status(path_status("path event", path, path.first))
      @last_route_dir = path.first
      return if try_interact_with_live_route_blocker(path.first, "event path")
      AutoplayBot::InputQueue.hold_dir(path.first, movement_hold_frames(path))
    end

    def target_cooldown_key(kind, record)
      player = defined?($game_player) && $game_player ? "#{$game_player.x},#{$game_player.y}" : "nopos"
      base = if record.is_a?(Hash)
               record["key"] || record["event_id"] || record["event_name"] || "#{record["x"]},#{record["y"]}"
             else
               record
             end
      [kind, current_map_id, base, player].compact.map(&:to_s).join(":")
    rescue
      "#{kind}:#{current_map_id}:unknown"
    end

    def target_on_cooldown?(key)
      @target_cooldowns ||= {}
      frame = (Graphics.frame_count rescue 0).to_i
      @target_cooldowns[key.to_s].to_i > frame
    rescue
      false
    end

    def cool_down_target(key, frames = 90)
      @target_cooldowns ||= {}
      @target_cooldowns[key.to_s] = (Graphics.frame_count rescue 0).to_i + frames.to_i
    rescue
      nil
    end

    def cached_path(key)
      @path_cache ||= {}
      frame = (Graphics.frame_count rescue 0).to_i
      entry = @path_cache[key.to_s]
      return entry["path"] if entry && frame - entry["frame"].to_i <= path_cache_ttl_frames
      path = yield
      @path_cache[key.to_s] = { "frame" => frame, "path" => path }
      path
    rescue
      yield
    end

    def active_route_plan_path(kind, record)
      plan = @active_route_plan
      return nil unless plan && plan["key"] == route_plan_key(kind, record)
      frame = (Graphics.frame_count rescue 0).to_i
      return nil if frame - plan["frame"].to_i > 900
      current = current_position_pair
      return nil unless current
      origin = plan["pos"].is_a?(Array) ? plan["pos"] : current
      path = plan["path"].is_a?(Array) ? plan["path"].map(&:to_i) : []
      if origin[0].to_i == current[0].to_i && origin[1].to_i == current[1].to_i
        plan["frame"] = frame
        return path
      end
      x = origin[0].to_i
      y = origin[1].to_i
      path.each_with_index do |dir, index|
        dx, dy = direction_delta(dir)
        x += dx
        y += dy
        next unless x == current[0].to_i && y == current[1].to_i
        remaining = path[(index + 1)..-1] || []
        plan["path"] = remaining
        plan["pos"] = current
        plan["frame"] = frame
        return remaining
      end
      nil
    rescue
      nil
    end

    def store_active_route_plan(kind, record, path)
      return path unless path && defined?($game_player) && $game_player
      @active_route_plan = {
        "key" => route_plan_key(kind, record),
        "pos" => current_position_pair,
        "path" => path.map(&:to_i),
        "frame" => (Graphics.frame_count rescue 0).to_i
      }
      path
    rescue
      path
    end

    def route_plan_key(kind, record)
      base = if record.is_a?(Hash)
               record["key"] || record["event_id"] || record["event_name"] || "#{record["x"]},#{record["y"]}"
             else
               record.to_s
             end
      dest = record.is_a?(Hash) ? record["destination_map_id"] : nil
      "#{current_map_id}:#{kind}:#{base}:#{record && record["x"]}:#{record && record["y"]}:#{dest}"
    rescue
      "#{current_map_id}:#{kind}:unknown"
    end

    def current_position_pair
      return nil unless defined?($game_player) && $game_player
      [$game_player.x.to_i, $game_player.y.to_i]
    rescue
      nil
    end

    def direction_delta(dir)
      case dir.to_i
      when 2 then [0, 1]
      when 4 then [-1, 0]
      when 6 then [1, 0]
      when 8 then [0, -1]
      else [0, 0]
      end
    rescue
      [0, 0]
    end

    def path_cache_ttl_frames
      return 180 if TOWN_CLEANUP_MAP_IDS.include?(current_map_id.to_i)
      120
    rescue
      120
    end

    def path_to_event_action(event_record, max_nodes = 4000)
      return nil unless event_record && event_record["x"] && event_record["y"]
      targets = event_action_targets_for(event_record)
      return nil if targets.empty?
      if defined?($game_player) && $game_player
        return [] if targets.any? { |tx, ty| tx == $game_player.x && ty == $game_player.y }
      end
      AutoplayBot::Pathfinder.find_path_to_any(targets, max_nodes)
    rescue
      nil
    end

    def event_action_targets_for(event_record)
      if event_record["action_x"] && event_record["action_y"]
        x = event_record["action_x"].to_i
        y = event_record["action_y"].to_i
        return AutoplayBot::Pathfinder.valid_tile?(x, y) ? [[x, y]] : []
      end
      if [1, 2].include?(event_record["trigger"].to_i)
        x = event_record["x"].to_i
        y = event_record["y"].to_i
        return AutoplayBot::Pathfinder.valid_tile?(x, y) ? [[x, y]] : []
      end
      if action_button_event?(event_record)
        targets = event_adjacent_action_targets(event_record["x"].to_i, event_record["y"].to_i)
        return targets unless targets.empty?
      end
      return event_adjacent_action_targets(event_record["x"].to_i, event_record["y"].to_i) if person_interaction_event?(event_record)
      event_action_targets(event_record["x"].to_i, event_record["y"].to_i)
    rescue
      []
    end

    def action_button_event?(event_record)
      return false unless event_record.is_a?(Hash)
      return false unless event_record["trigger"].to_i == 0
      text = [
        event_record["kind"],
        event_record["frontier_kind"],
        event_record["target_kind"],
        event_record["call"],
        event_record["args"],
        event_record["event_name"],
        event_record["key"]
      ].compact.join(" ")
      text =~ /item|resource|gift|static|pbReceiveItem|pbItemBall|pbPokemon|hidden|mushroom|berry|trash/i
    rescue
      false
    end

    def person_interaction_event?(event_record)
      return false unless event_record.is_a?(Hash)
      return true if event_record["trainer_key"] || event_record["call"].to_s == "pbTrainerBattle"
      return true if event_record["frontier_kind"].to_s == "npc" || event_record["kind"].to_s == "trainer"
      key = event_record["key"].to_s
      name = event_record["event_name"].to_s
      text = [key, name, event_record["args"]].compact.join(" ")
      key =~ /^npc:/ || text =~ /trainer|leader|brock|rival|professor|oak|mom|clerk/i
    rescue
      false
    end

    def event_adjacent_action_targets(x, y)
      targets = []
      AutoplayBot::Pathfinder::DIRS.each do |_dir, dx, dy|
        add_event_target(targets, x - dx, y - dy)
        counter_x = x - dx
        counter_y = y - dy
        next unless counter_tile?(counter_x, counter_y)
        add_event_target(targets, x - (dx * 2), y - (dy * 2))
      end
      targets.uniq
    rescue
      []
    end

    def event_action_targets(x, y)
      targets = []
      add_event_target(targets, x, y)
      AutoplayBot::Pathfinder::DIRS.each do |_dir, dx, dy|
        add_event_target(targets, x - dx, y - dy)
        counter_x = x - dx
        counter_y = y - dy
        next unless counter_tile?(counter_x, counter_y)
        add_event_target(targets, x - (dx * 2), y - (dy * 2))
      end
      targets.uniq
    rescue
      []
    end

    def add_event_target(targets, x, y)
      return unless AutoplayBot::Pathfinder.valid_tile?(x, y)
      return if defined?(AutoplayBot::Pathfinder) &&
                AutoplayBot::Pathfinder.respond_to?(:event_blocks_tile?) &&
                AutoplayBot::Pathfinder.event_blocks_tile?(x, y)
      targets << [x, y]
    rescue
      nil
    end

    def counter_tile?(x, y)
      return false unless defined?($game_map) && $game_map && $game_map.respond_to?(:counter?)
      $game_map.counter?(x, y)
    rescue
      false
    end

    def log_step(kind, record, dir)
      frame = Graphics.frame_count rescue 0
      @last_step_log_frame = -9999 if @last_step_log_frame.nil?
      return if frame.to_i - @last_step_log_frame.to_i < 180
      @last_step_log_frame = frame.to_i
      AutoplayBot.log("#{kind} route dir=#{dir} target=#{record["x"]},#{record["y"]} from #{position_label}") if AutoplayBot.respond_to?(:log)
    rescue
      nil
    end

    def path_status(label, path, dir)
      steps = path && path.respond_to?(:length) ? path.length.to_i : 0
      direction = dir_label(dir)
      return "#{label}: #{direction}" if steps <= 0
      "#{label}: #{steps} steps #{direction}"
    rescue
      "#{label}: dir #{dir}"
    end

    def dir_label(dir)
      case dir.to_i
      when 2 then "down"
      when 4 then "left"
      when 6 then "right"
      when 8 then "up"
      else "dir #{dir}"
      end
    rescue
      "dir #{dir}"
    end

    def movement_hold_frames(path, minimum = nil)
      return [minimum.to_i, 12].max if !path || !path.respond_to?(:each)
      first = path[0].to_i
      straight = 0
      path.each do |dir|
        break unless dir.to_i == first
        straight += 1
        break if straight >= smooth_movement_tile_cap
      end
      tiles = [[straight, 1].max, smooth_movement_tile_cap].min
      frames = (estimated_tile_frames * tiles) + (tiles > 1 ? 1 : 0)
      frames = [frames, minimum.to_i].max if minimum
      soft_min = tiles > 1 ? 8 : [estimated_tile_frames, 3].max
      [[frames, soft_min].max, 96].min
    rescue
      [minimum.to_i, 12].max
    end

    def smooth_movement_tile_cap
      speed = movement_speedup_multiplier
      if speed >= 7
        return 1 if BUILDING_CLEANUP_MAP_IDS.include?(current_map_id.to_i)
        return 1 if small_current_map?
        return 2
      elsif speed >= 3
        return 2 if BUILDING_CLEANUP_MAP_IDS.include?(current_map_id.to_i)
        return 2 if small_current_map?
        return 4 if TOWN_CLEANUP_MAP_IDS.include?(current_map_id.to_i)
        return 3
      end
      return 3 if BUILDING_CLEANUP_MAP_IDS.include?(current_map_id.to_i)
      return 4 if small_current_map?
      return 16 if TOWN_CLEANUP_MAP_IDS.include?(current_map_id.to_i)
      12
    rescue
      12
    end

    def movement_speedup_multiplier
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.respond_to?(:game_speed_multiplier)
        return AutoplayBot::Runtime.game_speed_multiplier.to_i
      end
      defined?($GameSpeed) ? $GameSpeed.to_i : 1
    rescue
      1
    end

    def estimated_tile_frames
      return 8 unless defined?($game_player) && $game_player
      speed = nil
      speed = $game_player.move_speed if $game_player.respond_to?(:move_speed)
      speed = $game_player.instance_variable_get(:@move_speed) if speed.nil? && $game_player.instance_variable_defined?(:@move_speed)
      speed = 4 if speed.nil?
      if defined?(AutoplayBot::Runtime) &&
         AutoplayBot::Runtime.respond_to?(:run_modifier_allowed?) &&
         AutoplayBot::Runtime.run_modifier_allowed?
        speed = speed.to_i + 1
      end
      speed = [[speed.to_i, 1].max, 6].min
      frames = (128.0 / (2 ** speed)).ceil
      observed = @observed_tile_frames
      frames = [frames, observed.to_f.ceil].min if observed && observed.to_f >= 2.0
      [[frames, 4].max, 16].min
    rescue
      8
    end

    def mark_event_target_done(event_record)
      frontier_kind = event_record && event_record["frontier_kind"].to_s
      return if frontier_kind.nil? || frontier_kind.empty?
      mark_repeat_item_done_this_visit(event_record) if frontier_kind == "item"
      return unless defined?(AutoplayBot::State)
      key = event_record["frontier_key"] || AutoplayBot::State.target_key(event_record, frontier_kind)
      AutoplayBot::State.mark_target_done(key) if AutoplayBot::State.respond_to?(:mark_target_done)
      AutoplayBot::State.touch_frontier(key, true) if AutoplayBot::State.respond_to?(:touch_frontier)
      AutoplayBot.log("#{frontier_kind} target complete #{key}") if AutoplayBot.respond_to?(:log)
    rescue
      nil
    end

    def face_or_use_transfer(transfer)
      dir = transfer["face_dir"] ? transfer["face_dir"].to_i : direction_toward(transfer["x"].to_i, transfer["y"].to_i)
      key = activation_key(transfer)
      if activation_on_cooldown?(key)
        AutoplayBot.status("activate: cooldown")
        return
      end
      unless dir
        @pending_activation = nil
        note_brock_interaction!(transfer) if brock_event_record?(transfer)
        mark_activation_attempt!(key, transfer)
        AutoplayBot::InputQueue.tap(:USE, 1)
        return
      end

      frame = Graphics.frame_count rescue 0
      if @pending_activation &&
         @pending_activation["key"] == key &&
         @pending_activation["dir"].to_i == dir.to_i
        if frame.to_i - @pending_activation["frame"].to_i >= 1
          @pending_activation = nil
          AutoplayBot.status("activate: use")
          AutoplayBot::InputQueue.clear
          note_brock_interaction!(transfer) if brock_event_record?(transfer)
          mark_activation_attempt!(key, transfer)
          AutoplayBot::InputQueue.tap(:USE, 2)
        else
          AutoplayBot.status("activate: ready")
        end
        return
      end

      @pending_activation = { "key" => key, "dir" => dir, "frame" => frame.to_i }
      AutoplayBot.status("activate: face #{dir}")
      AutoplayBot::InputQueue.hold_dir(dir, 1)
    end

    def note_brock_interaction!(record)
      @last_brock_interaction_frame = (Graphics.frame_count rescue 0).to_i
      @active_event_target = record if record.is_a?(Hash)
      AutoplayBot.status("brock: talk") if defined?(AutoplayBot)
      AutoplayBot.log("brock interaction at #{position_label}") if defined?(AutoplayBot) && AutoplayBot.respond_to?(:log)
    rescue
      nil
    end

    def activation_on_cooldown?(key)
      @activation_cooldowns ||= {}
      frame = (Graphics.frame_count rescue 0).to_i
      @activation_cooldowns[key.to_s].to_i > frame
    rescue
      false
    end

    def mark_activation_attempt!(key, record)
      @activation_cooldowns ||= {}
      @activation_cooldowns[key.to_s] = (Graphics.frame_count rescue 0).to_i + 45
      mark_event_target_done(record) if record.is_a?(Hash)
    rescue
      nil
    end

    def mark_event_target_attempted(event_record)
      return unless defined?(AutoplayBot::State) && AutoplayBot::State.respond_to?(:mark_target_attempted)
      frontier_kind = event_record && event_record["frontier_kind"].to_s
      kind = frontier_kind.nil? || frontier_kind.empty? ? "event" : frontier_kind
      entry = AutoplayBot::State.mark_target_attempted(event_record, "activate", kind)
      if entry && optional_interaction_target?(event_record, kind) &&
         entry["count"].to_i >= OPTIONAL_TARGET_MAX_ATTEMPTS
        AutoplayBot.status("last try #{kind}: #{short_target_label(event_record)}") if defined?(AutoplayBot)
      end
      entry
    rescue
      nil
    end

    def activation_key(record)
      [
        record["map_id"] || current_map_id,
        record["key"] || record["event_id"] || record["event_name"],
        record["x"],
        record["y"]
      ].join(":")
    rescue
      "#{current_map_id}:activation"
    end

    def direction_toward(x, y)
      return nil unless defined?($game_player) && $game_player
      dx = x - $game_player.x
      dy = y - $game_player.y
      horizontal = dx > 0 ? 6 : (dx < 0 ? 4 : nil)
      vertical = dy > 0 ? 2 : (dy < 0 ? 8 : nil)
      candidates = []
      if dy.abs >= dx.abs
        candidates << vertical if vertical
        candidates << horizontal if horizontal
      else
        candidates << horizontal if horizontal
        candidates << vertical if vertical
      end
      candidates.find { |dir| direction_passable?(dir) } || candidates.first
    end

    def direction_passable?(dir)
      return true unless defined?($game_player) && $game_player
      return false if pathfinder_blocked_step?(current_map_id, $game_player.x, $game_player.y, dir)
      return $game_player.can_move_in_direction?(dir) if $game_player.respond_to?(:can_move_in_direction?)
      return true unless $game_player.respond_to?(:passable?)
      $game_player.passable?($game_player.x, $game_player.y, dir)
    rescue
      true
    end
  end
end
