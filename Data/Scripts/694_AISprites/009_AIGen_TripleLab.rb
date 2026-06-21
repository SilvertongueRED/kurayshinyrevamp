#===============================================================================
# 694_AISprites - 009_AIGen_TripleLab.rb
# Expanded triple fusions: combine ANY three un-fused Pokemon into a triple
# fusion (the way Colress's machine does in the late game), with the sprite
# AI-generated from the three components.
#
# Two pieces:
#   1. A FAIL-SAFE sprite hook so a player-made triple (which the engine stores
#      as a :ZAPMOLTICUNO-based TripleFusion carrying its 3 component species)
#      renders from those 3 components instead of the shared placeholder sprite.
#   2. The "Triple Fusion Lab" flow (pick any 3 un-fused party Pokemon -> clone
#      -> AI-generate the sprite -> create the triple), reachable from Options ->
#      "Triple Fusion Lab", and from the real Colress machine via the global
#      pbColressTripleFusionLab (drop that one line in the Colress event).
#
# Everything is guarded: on ANY failure it falls back to vanilla behaviour, so a
# missing model / odd Pokemon can never crash sprite loading or the menu.
#===============================================================================
module AIGen
  module_function

  # A "component triple" is a TripleFusion-like Pokemon that carries its own
  # three component species (species1/species2/species3).
  def component_triple?(pokemon)
    return false unless pokemon
    pokemon.respond_to?(:species1) && pokemon.respond_to?(:species2) &&
      pokemon.respond_to?(:species3) &&
      pokemon.species1 && pokemon.species2 && pokemon.species3
  rescue Exception
    false
  end

  # [n1,n2,n3] numeric dex ids of the three components (head, body, third), or nil.
  def triple_component_numbers(pokemon)
    return nil unless component_triple?(pokemon)
    n1 = (getDexNumberForSpecies(pokemon.species1) rescue nil)
    n2 = (getDexNumberForSpecies(pokemon.species2) rescue nil)
    n3 = (getDexNumberForSpecies(pokemon.species3) rescue nil)
    (n1 && n2 && n3) ? [n1, n2, n3] : nil
  end

  # Resolvable sprite path for a component triple: a premade special sprite for
  # this exact trio wins (matches a hand-made/registered combo); otherwise the
  # AI-generated one. nil for back sprites (AI sprites are front only) or when
  # nothing is on disk yet.
  def component_triple_resolved_file(pokemon, back = false)
    return nil if back
    nums = triple_component_numbers(pokemon)
    return nil unless nums
    n1, n2, n3 = nums
    premade = "Graphics/Battlers/special/#{n1}.#{n2}.#{n3}"
    r = (pbResolveBitmap(premade) rescue nil)
    return r if r
    (AIGen::Store.triple_main_sprite_path(n1, n2, n3) rescue nil)
  end

  # Build the animated bitmap with the wrapper the active battle UI expects.
  def build_triple_bitmap(file, args = [])
    if defined?(BitmapEBDX) && (respond_to?(:pbCheckPokemonBitmapFiles, true))
      scale = args[1]
      speed = (args.length > 2 ? args[2] : nil) || 2
      begin
        return BitmapEBDX.new(file, scale, speed)
      rescue Exception
        # fall through to the vanilla wrapper
      end
    end
    AnimatedBitmap.new(file)
  end
end

#-- 1. Sprite hook ------------------------------------------------------------
# Alias the active object-level loader (vanilla Gen2 or EBDX, whichever is in
# effect) and short-circuit ONLY for component triples that have a resolved
# sprite. Any error or miss -> the original loader runs unchanged.
class Object
  unless private_method_defined?(:aigen_orig_pbLoadPokemonBitmapSpecies) ||
         method_defined?(:aigen_orig_pbLoadPokemonBitmapSpecies)
    if private_method_defined?(:pbLoadPokemonBitmapSpecies) ||
       method_defined?(:pbLoadPokemonBitmapSpecies)
      alias_method :aigen_orig_pbLoadPokemonBitmapSpecies, :pbLoadPokemonBitmapSpecies

      def pbLoadPokemonBitmapSpecies(pokemon, species, *args)
        begin
          if AIGen.enabled?
            real = pokemon.respond_to?(:pokemon) ? pokemon.pokemon : pokemon
            if AIGen.component_triple?(real)
              back = args[0]
              file = AIGen.component_triple_resolved_file(real, back)
              if file
                bmp = AIGen.build_triple_bitmap(file, args)
                return bmp if bmp
              end
            end
          end
        rescue Exception => e
          (AIGen.log("triple sprite hook: #{e.message}") rescue nil)
        end
        aigen_orig_pbLoadPokemonBitmapSpecies(pokemon, species, *args)
      end
    end
  end
end

#-- 2. Triple Fusion Lab flow -------------------------------------------------
module AIGen
  module TripleLab
    module_function

    def party
      return $Trainer.party if defined?($Trainer) && $Trainer && $Trainer.respond_to?(:party)
      return $player.party  if defined?($player) && $player && $player.respond_to?(:party)
      []
    end

    # Un-fused, non-egg party members eligible to become triple components.
    def eligible_members
      out = []
      (party || []).each do |pk|
        next if pk.nil?
        next if (pk.egg? rescue false)
        dn = (getDexNumberForSpecies(pk.species) rescue nil)
        next unless dn && dn >= 1 && dn <= Settings::NB_POKEMON   # base, not fused/triple
        out << pk
      end
      out
    end

    def run(context = :menu)
      unless AIGen.enabled?
        (pbMessage(_INTL("AI Fusion Sprites are turned off.\nTurn them on in Options to use the Triple Fusion Lab.")) rescue nil)
        return
      end
      pool = eligible_members
      if pool.length < 3
        pbMessage(_INTL("Colress's machine needs three un-fused Pokémon in your party.\nYou currently have {1} eligible.", pool.length))
        return
      end

      chosen = []
      slot_labels = [_INTL("the HEAD"), _INTL("the BODY"), _INTL("the THIRD part")]
      3.times do |slot|
        cmds = pool.map { |pk| pk.name }
        cmds << _INTL("Cancel")
        idx = pbMessage(_INTL("Choose {1}:", slot_labels[slot]), cmds, cmds.length)
        return if idx.nil? || idx < 0 || idx >= pool.length   # Cancel
        chosen << pool[idx]
        pool.delete_at(idx)                                   # no reusing the same Pokemon
      end

      s1, s2, s3 = chosen[0].species, chosen[1].species, chosen[2].species
      n1 = getDexNumberForSpecies(s1); n2 = getDexNumberForSpecies(s2); n3 = getDexNumberForSpecies(s3)
      return unless pbConfirmMessage(_INTL(
        "Fuse {1}, {2} and {3} into a triple fusion?\nThe three Pokémon are cloned, so you keep them.",
        chosen[0].name, chosen[1].name, chosen[2].name))

      # Generate the sprite (compositor always; neural if trained). The triple is
      # still created if generation fails -- it just uses a placeholder until you
      # generate one from the Pokédex sprite page.
      sprite_ok = false
      begin
        if AIGen::Launcher.ensure_running(8)
          pbMessage(_INTL("Colress's machine scans the three Pokémon...")) rescue nil
          path = AIGen.generate_triple(n1, n2, n3)
          sprite_ok = !path.nil?
        end
      rescue Exception => e
        AIGen.log("TripleLab generate error: #{e.message}")
      end
      sprite_ok ||= !!(AIGen::Store.human_triple?(n1, n2, n3) rescue false)
      unless sprite_ok
        return unless pbConfirmMessage(_INTL(
          "The sprite generator isn't running, so this triple will use a placeholder sprite for now.\nCreate it anyway?"))
      end

      level = ([chosen[0].level, chosen[1].level, chosen[2].level].max rescue 50)
      level = 50 if level.nil? || level <= 0
      created = (addNewTripleFusion(s1, s2, s3, level) rescue false)
      if created
        pbMessage(_INTL("The machine hums... a brand-new triple fusion takes shape!")) if sprite_ok
      else
        pbMessage(_INTL("The machine couldn't finish (are your Boxes full?)."))
      end
    rescue Exception => e
      AIGen.log("TripleLab.run error: #{e.message}")
      (pbMessage(_INTL("The Triple Fusion Lab hit a snag and was cancelled.")) rescue nil)
    end
  end
end

# Global entry point. Drop this single line into the real Colress-machine event
# (Event command -> Script: pbColressTripleFusionLab) to wire the in-world NPC.
def pbColressTripleFusionLab
  AIGen::TripleLab.run(:colress)
end

#-- Auto-sprite ANY triple at creation ----------------------------------------
# The real Colress machine event (Map356) builds triples via the top-level
# addNewTripleFusion(poke1,poke2,poke3,level). Hook it so any triple WITHOUT a
# premade special sprite (i.e. a non-canon trio) gets an AI sprite generated
# automatically -- so the in-world machine "just works" for new combos, the same
# as the Triple Fusion Lab. Canon trios (which already ship art) are left alone.
class Object
  unless private_method_defined?(:aigen_orig_addNewTripleFusion) ||
         method_defined?(:aigen_orig_addNewTripleFusion)
    if private_method_defined?(:addNewTripleFusion) || method_defined?(:addNewTripleFusion)
      alias_method :aigen_orig_addNewTripleFusion, :addNewTripleFusion

      def addNewTripleFusion(pokemon1, pokemon2, pokemon3, level = 1)
        result = aigen_orig_addNewTripleFusion(pokemon1, pokemon2, pokemon3, level)
        begin
          if result && AIGen.enabled?
            n1 = (getDexNumberForSpecies(pokemon1) rescue nil)
            n2 = (getDexNumberForSpecies(pokemon2) rescue nil)
            n3 = (getDexNumberForSpecies(pokemon3) rescue nil)
            if n1 && n2 && n3 &&
               n1 <= Settings::NB_POKEMON && n2 <= Settings::NB_POKEMON && n3 <= Settings::NB_POKEMON &&
               !(AIGen::Store.human_triple?(n1, n2, n3) rescue false) &&
               !(AIGen::Store.triple_main_sprite_path(n1, n2, n3) rescue nil)
              AIGen.generate_triple(n1, n2, n3) if (AIGen::Launcher.ensure_running(6) rescue false)
            end
          end
        rescue Exception => e
          (AIGen.log("addNewTripleFusion hook: #{e.message}") rescue nil)
        end
        result
      end
    end
  end
end

# (Access to the Lab now lives in the Fuse prompt -> Triple, and the Map356
# machine via pbColressTripleFusionLab. The old Options-menu button was removed.)
