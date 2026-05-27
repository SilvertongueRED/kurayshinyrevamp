# frozen_string_literal: true

module GBAPlayer
  module Gen3SaveParser
    SECTION_SIZE = 0x1000
    SECTION_DATA_SIZE = 0x0F80
    SAVE_SLOT_SIZE = SECTION_SIZE * 14
    SIGNATURE = 0x08012025
    SECTION_CHECKSUM_SIZES = [
      3884, 3968, 3968, 3968, 3848,
      3968, 3968, 3968, 3968, 3968,
      3968, 3968, 3968, 2000
    ]
    SUBSTRUCTURE_ORDERS = %w[
      GAEM GAME GEAM GEMA GMAE GMEA
      AGEM AGME AEGM AEMG AMGE AMEG
      EGAM EGMA EAGM EAMG EMGA EMAG
      MGAE MGEA MAGE MAEG MEGA MEAG
    ]
    STAT_KEYS = [:HP, :ATTACK, :DEFENSE, :SPEED, :SPECIAL_ATTACK, :SPECIAL_DEFENSE]
    NATURE_IDS = [
      :HARDY, :LONELY, :BRAVE, :ADAMANT, :NAUGHTY,
      :BOLD, :DOCILE, :RELAXED, :IMPISH, :LAX,
      :TIMID, :HASTY, :SERIOUS, :JOLLY, :NAIVE,
      :MODEST, :MILD, :QUIET, :BASHFUL, :RASH,
      :CALM, :GENTLE, :SASSY, :CAREFUL, :QUIRKY
    ]
    BALL_IDS = {
      1 => :MASTERBALL,
      2 => :ULTRABALL,
      3 => :GREATBALL,
      4 => :POKEBALL,
      5 => :SAFARIBALL,
      6 => :NETBALL,
      7 => :DIVEBALL,
      8 => :NESTBALL,
      9 => :REPEATBALL,
      10 => :TIMERBALL,
      11 => :LUXURYBALL,
      12 => :PREMIERBALL
    }

    module_function

    def parse(path, config = GBAPlayer.config)
      path = GBAPlayer.absolute_path(path)
      raise "Save file not found." unless File.file?(path)
      bytes = File.binread(path)
      slot = best_slot(bytes)
      raise "No complete valid Gen 3 save slot was found." unless slot
      trainer = trainer_info(slot[:sections][0])
      party = parse_party(slot, trainer, config)
      boxes = parse_boxes(slot, trainer, config)
      {
        :path => path,
        :fingerprint => save_fingerprint(bytes, slot[:save_index]),
        :save_index => slot[:save_index],
        :trainer => trainer,
        :current_box => boxes[:current_box],
        :party => party,
        :boxes => boxes[:boxes],
        :warnings => slot[:warnings] + party_warnings(party) + box_warnings(boxes[:boxes])
      }
    end

    def best_slot(bytes)
      slots = []
      [0, SAVE_SLOT_SIZE].each do |offset|
        next if bytes.bytesize < offset + SAVE_SLOT_SIZE
        slot = read_slot(bytes, offset)
        slots << slot if slot && slot[:valid]
      end
      slots.sort_by { |slot| slot[:save_index] }.last
    end

    def read_slot(bytes, offset)
      sections = {}
      save_indices = []
      warnings = []
      14.times do |i|
        section = bytes.byteslice(offset + i * SECTION_SIZE, SECTION_SIZE)
        section_id = le16(section, 0x0FF4)
        checksum = le16(section, 0x0FF6)
        signature = le32(section, 0x0FF8)
        save_index = le32(section, 0x0FFC)
        next if section_id.nil? || section_id > 13
        next unless signature == SIGNATURE
        expected = section_checksum(section, section_id)
        if expected != checksum
          warnings << "Section #{section_id} checksum failed."
          next
        end
        sections[section_id] = section.byteslice(0, SECTION_DATA_SIZE)
        save_indices << save_index
      end
      return nil unless sections.length == 14
      {
        :valid => true,
        :sections => sections,
        :save_index => most_common(save_indices) || save_indices.max || 0,
        :warnings => warnings
      }
    end

    def section_checksum(section, section_id)
      size = SECTION_CHECKSUM_SIZES[section_id] || SECTION_DATA_SIZE
      sum = 0
      offset = 0
      while offset < size
        sum = (sum + le32(section, offset).to_i) & 0xFFFFFFFF
        offset += 4
      end
      ((sum & 0xFFFF) + (sum >> 16)) & 0xFFFF
    end

    def trainer_info(section0)
      return { :name => "GBA", :gender => 2, :id => 0 } unless section0
      {
        :name => decode_gen3_text(section0.byteslice(0, 7), "GBA"),
        :gender => section0.getbyte(8).to_i,
        :id => le32(section0, 0x0A).to_i,
        :time_played => {
          :hours => le16(section0, 0x0E).to_i,
          :minutes => section0.getbyte(0x10).to_i,
          :seconds => section0.getbyte(0x11).to_i
        }
      }
    end

    def parse_party(slot, trainer, config)
      section1 = slot[:sections][1]
      return [] unless section1
      offsets = [
        [0x0234, 0x0238, "R/S/E"],
        [0x0034, 0x0038, "FR/LG"]
      ]
      best = []
      offsets.each do |count_offset, list_offset, game_label|
        count = count_offset == 0x0034 ? section1.getbyte(count_offset).to_i : le32(section1, count_offset).to_i
        next if count < 0 || count > 6
        parsed = []
        count.times do |i|
          raw = section1.byteslice(list_offset + i * 100, 100)
          next unless raw && raw.bytesize == 100
          entry = parse_record(raw, trainer, config, "Party", nil, i, game_label)
          parsed << entry if entry
        end
        best = parsed if parsed.length > best.length
      end
      best
    end

    def parse_boxes(slot, trainer, config)
      data = +""
      5.upto(13) do |section_id|
        section = slot[:sections][section_id]
        data << section.to_s.byteslice(0, SECTION_CHECKSUM_SIZES[section_id]).to_s
      end
      current_box = le32(data, 0).to_i
      current_box = 0 if current_box < 0 || current_box > 13
      boxes = Array.new(14) { [] }
      14.times do |box|
        30.times do |slot_index|
          offset = 4 + ((box * 30) + slot_index) * 80
          raw = data.byteslice(offset, 80)
          next unless raw && raw.bytesize == 80
          entry = parse_record(raw, trainer, config, "Box #{box + 1}", box, slot_index, nil)
          boxes[box] << entry if entry
        end
      end
      { :current_box => current_box, :boxes => boxes }
    end

    def parse_record(raw, trainer, config, source, box_index, slot_index, game_label)
      return nil if raw.bytes.all? { |byte| byte == 0 }
      pid = le32(raw, 0).to_i
      ot_id = le32(raw, 4).to_i
      return nil if pid == 0 && ot_id == 0
      decrypted = decrypted_payload(raw, pid, ot_id)
      return nil unless decrypted
      stored_checksum = le16(raw, 0x1C).to_i
      actual_checksum = pokemon_checksum(decrypted)
      warnings = []
      if stored_checksum != actual_checksum
        warnings << "Pokemon checksum failed."
        return warning_entry(raw, source, box_index, slot_index, warnings)
      end
      sub = reordered_substructures(decrypted, pid)
      fields = extract_fields(raw, sub, pid, ot_id, trainer)
      pokemon = build_pokemon(fields, config, warnings)
      return warning_entry(raw, source, box_index, slot_index, warnings) unless pokemon
      apply_party_stats(pokemon, raw) if raw.bytesize >= 100
      {
        :source => source,
        :box_index => box_index,
        :slot_index => slot_index,
        :game => game_label,
        :pokemon => pokemon,
        :name => pokemon.name,
        :species_raw => fields[:species_raw],
        :species_id => pokemon.species,
        :level => pokemon.level,
        :pid => pid,
        :ot_id => ot_id,
        :duplicate_key => duplicate_key(pid, ot_id, fields[:species_raw]),
        :warnings => warnings
      }
    rescue Exception => e
      warning_entry(raw, source, box_index, slot_index, ["Could not parse Pokemon record: #{e.message}"])
    end

    def warning_entry(raw, source, box_index, slot_index, warnings)
      {
        :source => source,
        :box_index => box_index,
        :slot_index => slot_index,
        :pokemon => nil,
        :name => "Skipped",
        :species_raw => le16(raw, 0x20).to_i,
        :level => 0,
        :pid => le32(raw, 0).to_i,
        :ot_id => le32(raw, 4).to_i,
        :duplicate_key => nil,
        :warnings => warnings
      }
    end

    def decrypted_payload(raw, pid, ot_id)
      key = pid ^ ot_id
      encrypted = raw.byteslice(0x20, 48)
      return nil unless encrypted && encrypted.bytesize == 48
      out = "".b
      12.times do |i|
        value = le32(encrypted, i * 4).to_i ^ key
        out << [value & 0xFFFFFFFF].pack("V")
      end
      out
    end

    def pokemon_checksum(bytes)
      sum = 0
      0.step(46, 2) { |i| sum = (sum + le16(bytes, i).to_i) & 0xFFFF }
      sum
    end

    def reordered_substructures(decrypted, pid)
      order = SUBSTRUCTURE_ORDERS[pid % 24]
      parts = {}
      order.chars.each_with_index do |letter, index|
        parts[letter] = decrypted.byteslice(index * 12, 12)
      end
      parts
    end

    def extract_fields(raw, sub, pid, ot_id, trainer)
      growth = sub["G"]
      attacks = sub["A"]
      evs = sub["E"]
      misc = sub["M"]
      iv_word = le32(misc, 4).to_i
      origins = le16(misc, 2).to_i
      pp_bonuses = growth.getbyte(8).to_i
      {
        :pid => pid,
        :ot_id => ot_id,
        :nickname => decode_gen3_text(raw.byteslice(8, 10), ""),
        :language => le16(raw, 0x12).to_i,
        :ot_name => decode_gen3_text(raw.byteslice(0x14, 7), trainer[:name]),
        :markings => raw.getbyte(0x1B).to_i,
        :species_raw => le16(growth, 0).to_i,
        :held_item_raw => le16(growth, 2).to_i,
        :exp => le32(growth, 4).to_i,
        :pp_bonuses => [
          pp_bonuses & 0x03,
          (pp_bonuses >> 2) & 0x03,
          (pp_bonuses >> 4) & 0x03,
          (pp_bonuses >> 6) & 0x03
        ],
        :friendship => growth.getbyte(9).to_i,
        :moves_raw => [le16(attacks, 0).to_i, le16(attacks, 2).to_i, le16(attacks, 4).to_i, le16(attacks, 6).to_i],
        :move_pp => [attacks.getbyte(8).to_i, attacks.getbyte(9).to_i, attacks.getbyte(10).to_i, attacks.getbyte(11).to_i],
        :evs => {
          :HP => evs.getbyte(0).to_i,
          :ATTACK => evs.getbyte(1).to_i,
          :DEFENSE => evs.getbyte(2).to_i,
          :SPEED => evs.getbyte(3).to_i,
          :SPECIAL_ATTACK => evs.getbyte(4).to_i,
          :SPECIAL_DEFENSE => evs.getbyte(5).to_i
        },
        :pokerus => misc.getbyte(0).to_i,
        :met_location => misc.getbyte(1).to_i,
        :met_level => origins & 0x7F,
        :origin_game => (origins >> 7) & 0x0F,
        :ball_raw => (origins >> 11) & 0x0F,
        :ot_gender => (origins >> 15) & 0x01,
        :ivs => {
          :HP => iv_word & 0x1F,
          :ATTACK => (iv_word >> 5) & 0x1F,
          :DEFENSE => (iv_word >> 10) & 0x1F,
          :SPEED => (iv_word >> 15) & 0x1F,
          :SPECIAL_ATTACK => (iv_word >> 20) & 0x1F,
          :SPECIAL_DEFENSE => (iv_word >> 25) & 0x1F
        },
        :egg => ((iv_word >> 30) & 1) == 1,
        :ability_index => (iv_word >> 31) & 1
      }
    end

    def build_pokemon(fields, config, warnings)
      species_id = resolve_species(fields[:species_raw], config, warnings)
      return nil unless species_id
      pokemon = Pokemon.new(species_id, 1, nil, false, false)
      pokemon.personalID = fields[:pid] if pokemon.respond_to?(:personalID=)
      pokemon.owner = Pokemon::Owner.new(fields[:ot_id], fields[:ot_name], fields[:ot_gender], gen3_language(fields[:language]))
      pokemon.exp = fields[:exp]
      pokemon.level
      pokemon.nature = NATURE_IDS[fields[:pid] % 25] if GameData::Nature.exists?(NATURE_IDS[fields[:pid] % 25])
      pokemon.ability_index = fields[:ability_index] if pokemon.respond_to?(:ability_index=)
      STAT_KEYS.each do |stat|
        pokemon.iv[stat] = fields[:ivs][stat].to_i
        pokemon.ev[stat] = fields[:evs][stat].to_i
      end
      apply_moves(pokemon, fields, config, warnings)
      apply_item(pokemon, fields[:held_item_raw], config, warnings)
      apply_origin(pokemon, fields)
      nickname = fields[:nickname].to_s.strip
      pokemon.name = nickname if use_nickname?(pokemon, nickname)
      pokemon.steps_to_hatch = pokemon.species_data.hatch_steps if fields[:egg]
      pokemon.pokerus = fields[:pokerus]
      pokemon.markings = fields[:markings]
      pokemon.happiness = fields[:friendship]
      pokemon.calc_stats
      pokemon.heal
      pokemon
    rescue Exception => e
      warnings << "Could not construct Pokemon: #{e.message}"
      nil
    end

    def resolve_species(raw_id, config, warnings)
      override = mapping_value(config["species_overrides"], raw_id)
      if override
        data = resolve_data_id(GameData::Species, override, "species", warnings)
        return data ? data.id : nil
      end
      national = gen3_index_to_national(raw_id)
      unless national
        warnings << "Unknown Gen 3 species index #{raw_id}; add species_overrides to import it."
        return nil
      end
      data = resolve_data_id(GameData::Species, national, "species", warnings)
      data ? data.id : nil
    end

    def gen3_index_to_national(raw_id)
      return raw_id if raw_id >= 1 && raw_id <= 251
      return raw_id - 25 if raw_id >= 277 && raw_id <= 411
      return 201 if raw_id >= 413 && raw_id <= 439
      nil
    end

    def apply_moves(pokemon, fields, config, warnings)
      moves = []
      fields[:moves_raw].each_with_index do |raw_id, index|
        next if raw_id.nil? || raw_id <= 0
        move_id = mapping_value(config["move_overrides"], raw_id) || raw_id
        move_data = resolve_data_id(GameData::Move, move_id, "move", warnings)
        next unless move_data
        move = Pokemon::Move.new(move_data.id)
        move.ppup = fields[:pp_bonuses][index].to_i
        move.pp = fields[:move_pp][index].to_i
        moves << move
      end
      pokemon.moves = moves[0, 4]
      pokemon.record_first_moves if pokemon.respond_to?(:record_first_moves)
      if pokemon.moves.empty?
        pokemon.reset_moves if pokemon.respond_to?(:reset_moves)
      end
    end

    def apply_item(pokemon, raw_id, config, warnings)
      return if raw_id.nil? || raw_id <= 0
      item_id = mapping_value(config["item_overrides"], raw_id) || raw_id
      item_data = resolve_data_id(GameData::Item, item_id, "held item", warnings, true)
      pokemon.item = item_data.id if item_data
    end

    def apply_origin(pokemon, fields)
      pokemon.obtain_method = fields[:egg] ? 1 : 0
      pokemon.obtain_map = 0
      pokemon.obtain_text = "GBA Player"
      pokemon.obtain_level = [fields[:met_level].to_i, 1].max
      pokemon.poke_ball = BALL_IDS[fields[:ball_raw]] || :POKEBALL
      pokemon.timeReceived = Time.now
    end

    def apply_party_stats(pokemon, raw)
      pokemon.calc_stats
      current_hp = le16(raw, 86).to_i
      pokemon.hp = current_hp if current_hp > 0
    rescue
      nil
    end

    def use_nickname?(pokemon, nickname)
      return false if nickname.empty?
      species_name = pokemon.speciesName.to_s
      nickname.upcase != species_name.upcase
    end

    def resolve_data_id(klass, id, label, warnings, optional = false)
      resolved = id
      resolved = id.to_i if id.is_a?(String) && id[/\A\d+\z/]
      resolved = id.to_s.upcase.to_sym if id.is_a?(String) && id !~ /\A\d+\z/
      data = klass.respond_to?(:try_get) ? klass.try_get(resolved) : nil
      if !data && !optional
        warnings << "Unknown #{label} #{id}; skipped."
      elsif !data && optional
        warnings << "Unknown #{label} #{id}; held item was skipped."
      end
      data
    end

    def mapping_value(mapping, raw_id)
      return nil unless mapping.is_a?(Hash)
      mapping[raw_id.to_s] || mapping[raw_id] || mapping[raw_id.to_i]
    end

    def gen3_language(raw)
      case raw.to_i
      when 1 then 1
      when 2 then 2
      when 3 then 3
      when 4 then 4
      when 5 then 5
      when 7 then 7
      else 2
      end
    end

    def party_warnings(entries)
      warnings_from_entries(entries, "Party")
    end

    def box_warnings(boxes)
      warnings = []
      boxes.each { |entries| warnings.concat(warnings_from_entries(entries, nil)) }
      warnings
    end

    def warnings_from_entries(entries, prefix)
      warnings = []
      entries.each do |entry|
        next if !entry[:warnings] || entry[:warnings].empty?
        label = prefix || entry[:source]
        warnings.concat(entry[:warnings].map { |warning| "#{label} slot #{entry[:slot_index].to_i + 1}: #{warning}" })
      end
      warnings
    end

    def duplicate_key(pid, ot_id, species_raw)
      "#{pid.to_i.to_s(16)}-#{ot_id.to_i.to_s(16)}-#{species_raw.to_i}"
    end

    def save_fingerprint(bytes, save_index)
      hash = 2166136261
      bytes.each_byte do |byte|
        hash ^= byte
        hash = (hash * 16777619) & 0xFFFFFFFF
      end
      "#{bytes.bytesize}-#{save_index}-#{hash.to_s(16)}"
    end

    def most_common(values)
      counts = Hash.new(0)
      values.each { |value| counts[value] += 1 }
      counts.max_by { |pair| pair[1] }&.first
    end

    def le16(bytes, offset)
      return nil if !bytes || offset + 1 >= bytes.bytesize
      bytes.getbyte(offset).to_i | (bytes.getbyte(offset + 1).to_i << 8)
    end

    def le32(bytes, offset)
      return nil if !bytes || offset + 3 >= bytes.bytesize
      bytes.getbyte(offset).to_i |
        (bytes.getbyte(offset + 1).to_i << 8) |
        (bytes.getbyte(offset + 2).to_i << 16) |
        (bytes.getbyte(offset + 3).to_i << 24)
    end

    def decode_gen3_text(bytes, fallback = "")
      return fallback if !bytes
      chars = []
      bytes.each_byte do |byte|
        break if byte == 0xFF
        next if byte == 0x00
        chars << decode_gen3_char(byte)
      end
      text = chars.join.strip
      text.empty? ? fallback : text
    end

    def decode_gen3_char(byte)
      return (byte - 0xA1).to_s if byte >= 0xA1 && byte <= 0xAA
      return (65 + byte - 0xBB).chr if byte >= 0xBB && byte <= 0xD4
      return (97 + byte - 0xD5).chr if byte >= 0xD5 && byte <= 0xEE
      case byte
      when 0xAB then "!"
      when 0xAC then "?"
      when 0xAD then "."
      when 0xAE then "-"
      when 0xB8 then ","
      when 0xBA then "/"
      when 0xF0 then ":"
      else ""
      end
    end
  end
end
