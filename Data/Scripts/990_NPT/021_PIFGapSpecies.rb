#==============================================================================
# 990_NPT — PIF Parity Gap Species
# File: 021_PIFGapSpecies.rb
#
# WHY
# ───
# PIF / PIF-Hoenn (April-2026 build, dex 502-572) includes two species the
# fork's NPT registration never added: Noibat (PIF 566) and Noivern (PIF 567).
# Without them the PIF sprite pack's 566/567 fusions have no home in the fork.
# We register them at the first free NPT ids (1109, 1110 — max used was 1108,
# NB_POKEMON is 1201) so nothing renumbers and no existing id moves.
#
# The PIF<->fork sprite map (020_PIFRemap.rb / convert_pif_pack.py) routes
# PIF 566 -> 1109 and 567 -> 1110.
#
# MULTIPLAYER NOTE
# ────────────────
# NPTVersion::CURRENT_VERSION is intentionally NOT bumped: the MP handshake
# compares NPT *version strings*, and the server-side integrity hash covers
# 659_Multiplayer (not 990_NPT). Keeping the version string preserves
# compatibility with the official KIFM server. These two species are additive
# and only referenced when actually owned/used.
#==============================================================================

module NPT
  def self.register_pif_gap_species
    return if defined?(@pif_gap_done) && @pif_gap_done

    # ── Noibat (PIF 566 -> NPT 1109) ─────────────────────────────────────────
    GameData::Species.register({
      id:        :NOIBAT,
      id_number: 1109,
      name:          "Noibat",
      form_name:     nil,
      category:      "Sound Wave",
      pokedex_entry: "It emits ultrasonic waves from its ears to locate ripe fruit in the dark caves and forests where it lives.",
      type1: :FLYING,
      type2: :DRAGON,
      base_stats: { HP: 40, ATTACK: 30, DEFENSE: 35, SPECIAL_ATTACK: 45, SPECIAL_DEFENSE: 40, SPEED: 55 },
      evs:         { SPEED: 1 },
      base_exp:    49,
      growth_rate: :Medium,
      gender_ratio: :Female50Percent,
      catch_rate:   190,
      happiness:    70,
      egg_groups:   [:Flying, :Dragon],
      hatch_steps:  21,
      incense:      nil,
      abilities:        [:FRISK, :INFILTRATOR],
      hidden_abilities: [:TELEPATHY],
      moves: [[1, :SUPERSONIC], [1, :TACKLE], [1, :LEER], [1, :GUST], [1, :ABSORB], [6, :BITE],
              [12, :WINGATTACK], [18, :AGILITY], [24, :AIRCUTTER], [30, :ROOST], [36, :SCREECH],
              [42, :LEECHLIFE], [48, :AIRSLASH], [54, :RAZORWIND], [60, :TAILWIND], [66, :HURRICANE]],
      tutor_moves: [:TACKLE, :GUST, :BITE, :AGILITY, :ROOST, :AIRSLASH, :TAILWIND, :DRAGONPULSE,
                    :HURRICANE, :AIRCUTTER, :SWIFT, :SUPERSONIC, :SCREECH, :DRAGONCLAW],
      egg_moves:   [:WINGATTACK, :SUPERSONIC, :SCREECH, :LEECHLIFE, :RAZORWIND, :TAILWIND],
      wild_item_common: nil, wild_item_uncommon: nil, wild_item_rare: nil,
      evolutions: [[:NOIVERN, :Level, 48, false]],
      height:     5, weight: 80, color: :Purple, shape: :Winged, habitat: nil, generation: 6,
      back_sprite_x: 0, back_sprite_y: 0, front_sprite_x: 0, front_sprite_y: 0,
      front_sprite_altitude: 0, shadow_x: 0, shadow_size: 2,
    })

    # ── Noivern (PIF 567 -> NPT 1110) ────────────────────────────────────────
    GameData::Species.register({
      id:        :NOIVERN,
      id_number: 1110,
      name:          "Noivern",
      form_name:     nil,
      category:      "Sound Wave",
      pokedex_entry: "A nocturnal Pokémon. The ultrasonic waves it blasts from its ears are powerful enough to crush boulders.",
      type1: :FLYING,
      type2: :DRAGON,
      base_stats: { HP: 85, ATTACK: 70, DEFENSE: 80, SPECIAL_ATTACK: 97, SPECIAL_DEFENSE: 80, SPEED: 123 },
      evs:         { SPEED: 2 },
      base_exp:    187,
      growth_rate: :Medium,
      gender_ratio: :Female50Percent,
      catch_rate:   45,
      happiness:    70,
      egg_groups:   [:Flying, :Dragon],
      hatch_steps:  21,
      incense:      nil,
      abilities:        [:FRISK, :INFILTRATOR],
      hidden_abilities: [:TELEPATHY],
      moves: [[1, :BOOMBURST], [1, :DRAGONPULSE], [1, :SUPERSONIC], [1, :TACKLE], [1, :LEER],
              [1, :GUST], [1, :BITE], [1, :WINGATTACK], [1, :AGILITY], [24, :AIRCUTTER], [30, :ROOST],
              [36, :SCREECH], [42, :LEECHLIFE], [48, :AIRSLASH], [54, :RAZORWIND], [60, :TAILWIND],
              [66, :HURRICANE], [72, :BOOMBURST]],
      tutor_moves: [:TACKLE, :GUST, :BITE, :AGILITY, :ROOST, :AIRSLASH, :TAILWIND, :DRAGONPULSE,
                    :HURRICANE, :AIRCUTTER, :SWIFT, :SCREECH, :DRAGONCLAW, :DRACOMETEOR, :BOOMBURST],
      egg_moves:   [:WINGATTACK, :SUPERSONIC, :SCREECH, :LEECHLIFE, :RAZORWIND, :TAILWIND],
      wild_item_common: nil, wild_item_uncommon: nil, wild_item_rare: nil,
      evolutions: [[:NOIBAT, :Level, 48, true]],
      height:     15, weight: 850, color: :Purple, shape: :Winged, habitat: nil, generation: 6,
      back_sprite_x: 0, back_sprite_y: 0, front_sprite_x: 0, front_sprite_y: 0,
      front_sprite_altitude: 0, shadow_x: 0, shadow_size: 3,
    })

    @pif_gap_done = true
    echoln "[990_NPT] PIF gap species registered: Noibat(1109), Noivern(1110)"
  rescue => e
    echoln "[990_NPT] WARNING: PIF gap species registration failed: #{e}"
  end

  # Re-register after each Species.load, riding the existing register_all_species hook.
  class << self
    unless method_defined?(:_pif_orig_register_all_species) || private_method_defined?(:_pif_orig_register_all_species)
      alias_method :_pif_orig_register_all_species, :register_all_species
      def register_all_species
        _pif_orig_register_all_species
        @pif_gap_done = false
        register_pif_gap_species
      end
    end
  end
end

# ── Split-names for fusion display ──────────────────────────────────────────
if defined?(NPT) && NPT.respond_to?(:register_split_name)
  NPT.register_split_name(1109, "Noi", "bat")    # Noibat
  NPT.register_split_name(1110, "Noi", "vern")   # Noivern
end

# ── PBSpecies aliases (legacy compatibility) ────────────────────────────────
module PBSpecies
  NOIBAT  = :NOIBAT  unless const_defined?(:NOIBAT)
  NOIVERN = :NOIVERN unless const_defined?(:NOIVERN)
end
