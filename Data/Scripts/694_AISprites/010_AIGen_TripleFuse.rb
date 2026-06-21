#===============================================================================
# 694_AISprites - 010_AIGen_TripleFuse.rb
# Triple fusion through the normal Fuse prompt (party AND PC). When you pick
# "Fuse" on an un-fused Pokemon you're asked Double or Triple. Triple lets you
# pick two more un-fused Pokemon (from your party or any box), shows a preview of
# all three plus the resulting sprite, then fuses them into one triple fusion.
#
# Cost (per the chosen splicer type): 3 DNA Splicers / 2 Super Splicers /
# 1 Infinite Splicer. The three Pokemon are consumed (triples can't be unfused).
#
# Every step is guarded: the three Pokemon are only ever removed AFTER the triple
# is successfully built, and any error aborts cleanly without consuming anything.
#===============================================================================
module AIGen
  module TripleFuse
    module_function

    # 3 regular / 2 perfect(super) / 1 infinite
    TRIPLE_COST = { DNASPLICERS: 3, SUPERSPLICERS: 2,
                    INFINITESPLICERS: 1, INFINITESPLICERS2: 1 }

    def eligible_mon?(pk)
      return false unless pk
      return false if (pk.egg? rescue false)
      dn = (getDexNumberForSpecies(pk.species) rescue nil)
      !!(dn && dn >= 1 && dn <= Settings::NB_POKEMON)
    rescue Exception
      false
    end
    def eligible_first?(pk); eligible_mon?(pk); end

    def each_box_slot
      st = (defined?($PokemonStorage) ? $PokemonStorage : nil)
      return unless st
      nb = (st.maxBoxes rescue 0)
      nb.times do |b|
        mp = (st.maxPokemon(b) rescue 30)
        mp.times do |i|
          pk = (st[b, i] rescue nil)
          yield(b, i, pk) if pk
        end
      end
    rescue Exception
    end

    # [[pokemon, "label", location], ...] of all eligible mons except `exclude`.
    def eligible_pool(exclude = [])
      pool = []
      (($Trainer.party rescue []) || []).each_with_index do |pk, i|
        next unless eligible_mon?(pk)
        next if exclude.any? { |e| e.equal?(pk) }
        pool << [pk, _INTL("Party"), [:party, i]]
      end
      each_box_slot do |b, i, pk|
        next unless eligible_mon?(pk)
        next if exclude.any? { |e| e.equal?(pk) }
        pool << [pk, _INTL("Box {1}", b + 1), [:box, b, i]]
      end
      pool
    end

    def ask_double_triple(pokemon)
      return :double unless eligible_first?(pokemon)
      cmds = [_INTL("Double"), _INTL("Triple"), _INTL("Cancel")]
      c = pbMessage(_INTL("Fuse {1} as a Double or Triple fusion?", pokemon.name), cmds, cmds.length)
      return :double if c == 0
      return :triple if c == 1
      nil
    end

    # Returns the splicer item symbol to use for a TRIPLE (enough in bag), asking
    # only when more than one type qualifies. nil = cancel / not enough.
    def select_splicer
      dq  = ($PokemonBag.pbQuantity(:DNASPLICERS) rescue 0)
      sq  = ($PokemonBag.pbQuantity(:SUPERSPLICERS) rescue 0)
      iq  = ($PokemonBag.pbQuantity(:INFINITESPLICERS) rescue 0)
      iq2 = ($PokemonBag.pbQuantity(:INFINITESPLICERS2) rescue 0)
      avail = []
      avail << [:SUPERSPLICERS, _INTL("Super Splicers (need 2, have {1})", sq)] if sq >= 2
      avail << [:DNASPLICERS,   _INTL("DNA Splicers (need 3, have {1})", dq)]   if dq >= 3
      avail << [(iq2 > 0 ? :INFINITESPLICERS2 : :INFINITESPLICERS),
                _INTL("Infinite Splicer (need 1)")]                            if iq2 > 0 || iq > 0
      if avail.empty?
        pbMessage(_INTL("A triple fusion needs 3 DNA Splicers, 2 Super Splicers, or 1 Infinite Splicer."))
        return nil
      end
      return avail[0][0] if avail.length == 1
      cmds = avail.map { |a| a[1] } + [_INTL("Cancel")]
      c = pbMessage(_INTL("Use which splicers?"), cmds, cmds.length)
      return nil if c.nil? || c < 0 || c >= avail.length
      avail[c][0]
    end

    def consume_splicer(item)
      return if item == :INFINITESPLICERS || item == :INFINITESPLICERS2
      n = TRIPLE_COST[item] || 1
      ($PokemonBag.pbDeleteItem(item, n) rescue nil)
    end

    # Eligible mons grouped by location: [[group_label, [[pokemon, loc], ...]], ...]
    # Party first, then each box (using the box's name if it has one). Empty
    # groups are omitted; `exclude` mons (already chosen / the first) are skipped.
    def eligible_groups(exclude = [])
      groups = []
      party_items = []
      (($Trainer.party rescue []) || []).each_with_index do |pk, i|
        next unless eligible_mon?(pk)
        next if exclude.any? { |e| e.equal?(pk) }
        party_items << [pk, [:party, i]]
      end
      groups << [_INTL("Party"), party_items] unless party_items.empty?
      st = (defined?($PokemonStorage) ? $PokemonStorage : nil)
      if st
        nb = (st.maxBoxes rescue 0)
        nb.times do |b|
          box_items = []
          mp = (st.maxPokemon(b) rescue 30)
          mp.times do |i|
            pk = (st[b, i] rescue nil)
            next unless pk && eligible_mon?(pk)
            next if exclude.any? { |e| e.equal?(pk) }
            box_items << [pk, [:box, b, i]]
          end
          next if box_items.empty?
          nm = (st[b].respond_to?(:name) ? st[b].name : nil) rescue nil
          label = (nm && !nm.to_s.empty?) ? nm.to_s : _INTL("Box {1}", b + 1)
          groups << [label, box_items]
        end
      end
      groups
    end

    # Pick one mon via group -> member. Returns [pokemon, loc], :cancel, or :none.
    def pick_one(exclude, slot_label)
      loop do
        groups = eligible_groups(exclude)
        return :none if groups.empty?
        gcmds = groups.map { |gl, items| _INTL("{1} ({2})", gl, items.length) }
        gcmds << _INTL("Cancel")
        gi = pbMessage(_INTL("Where is {1}?", slot_label), gcmds, gcmds.length)
        return :cancel if gi.nil? || gi < 0 || gi >= groups.length
        items = groups[gi][1]
        mcmds = items.map { |pk, _loc| pk.name }
        mcmds << _INTL("Back")
        mi = pbMessage(_INTL("Choose {1}:", slot_label), mcmds, mcmds.length)
        next if mi.nil? || mi < 0 || mi >= items.length    # Back -> re-pick the group
        return items[mi]
      end
    end

    def pick_two_more(first)
      picks = []
      2.times do |n|
        res = pick_one([first] + picks.map { |p| p[0] }, _INTL("Pokémon {1} of 2", n + 1))
        return nil if res == :cancel
        if res == :none
          pbMessage(_INTL("There aren't enough other un-fused Pokémon to fuse."))
          return nil
        end
        picks << res
      end
      picks
    end

    # Best-effort: make sure an AI/premade sprite exists for this trio. Returns the
    # resolvable sprite path (or nil).
    def ensure_sprite(n1, n2, n3)
      premade = ("Graphics/Battlers/special/#{n1}.#{n2}.#{n3}")
      r = (pbResolveBitmap(premade) rescue nil)
      return r if r
      ai = (AIGen::Store.triple_main_sprite_path(n1, n2, n3) rescue nil)
      return ai if ai
      if (AIGen.enabled? rescue false) && (AIGen::Launcher.ensure_running(8) rescue false)
        (AIGen.generate_triple(n1, n2, n3) rescue nil)
      end
      (AIGen::Store.triple_main_sprite_path(n1, n2, n3) rescue nil)
    end

    def preview_confirm(mons, sprite_file)
      vp = nil; made = []
      begin
        vp = Viewport.new(0, 0, Graphics.width, Graphics.height); vp.z = 99999
        if sprite_file
          rb = (AnimatedBitmap.new(pbResolveBitmap(sprite_file)) rescue nil)
          if rb && rb.bitmap
            s = Sprite.new(vp); s.bitmap = rb.bitmap
            s.x = Graphics.width / 2 - rb.bitmap.width / 2
            s.y = Graphics.height / 2 - rb.bitmap.height / 2 - 24
            made << [s, rb]
          end
        end
        mons.each_with_index do |pk, i|
          bm = (pbLoadPokemonBitmap(pk) rescue nil)
          if bm && bm.bitmap
            s = Sprite.new(vp); s.bitmap = bm.bitmap; s.zoom_x = s.zoom_y = 0.55
            s.x = (Graphics.width * (i + 1) / 4) - (bm.bitmap.width * 0.275).to_i
            s.y = Graphics.height - (bm.bitmap.height * 0.55).to_i - 28
            made << [s, bm]
          end
        end
        (Graphics.frame_reset rescue nil)
      rescue Exception => e
        (AIGen.log("triple preview build: #{e.message}") rescue nil)
      end
      ok = (pbConfirmMessage(_INTL("Fuse {1}, {2} and {3} into a triple fusion?",
              mons[0].name, mons[1].name, mons[2].name)) rescue false)
      made.each { |s, b| (s.dispose rescue nil); (b.dispose rescue nil) }
      (vp.dispose rescue nil)
      ok
    end

    def remove_everywhere(pk)
      party = ($Trainer.party rescue nil)
      if party
        i = party.index { |x| x && x.equal?(pk) }
        if i; party.delete_at(i); return true; end
      end
      done = false
      each_box_slot { |b, idx, o| if !done && o.equal?(pk); ($PokemonStorage[b, idx] = nil rescue nil); done = true; end }
      done
    end

    def replace_everywhere(old, neu)
      party = ($Trainer.party rescue nil)
      if party
        i = party.index { |x| x && x.equal?(old) }
        if i; party[i] = neu; return true; end
      end
      done = false
      each_box_slot { |b, idx, o| if !done && o.equal?(old); ($PokemonStorage[b, idx] = neu rescue nil); done = true; end }
      done
    end

    def refresh_scene(scene)
      return unless scene
      (scene.pbHardRefresh rescue nil)
      (scene.pbRefresh rescue nil)
      inner = (scene.instance_variable_get(:@scene) rescue nil)
      if inner; (inner.pbHardRefresh rescue nil); (inner.pbRefresh rescue nil); end
    end

    # Orchestrate a triple fuse starting from `first`. `scene` is whatever owns the
    # refresh (party screen / storage screen).
    def run(first, scene)
      unless eligible_first?(first)
        pbMessage(_INTL("{1} can't start a triple fusion.", (first.name rescue "That Pokémon")))
        return
      end
      item = select_splicer
      return unless item
      picks = pick_two_more(first)
      return unless picks
      mons = [first, picks[0][0], picks[1][0]]
      sp = mons.map { |m| m.species }
      n  = sp.map { |x| getDexNumberForSpecies(x) }
      return unless n.all?
      sprite_file = ensure_sprite(n[0], n[1], n[2])
      return unless preview_confirm(mons, sprite_file)

      level = (mons.map { |m| m.level }.max rescue 50)
      level = 50 if level.nil? || level.to_i <= 0
      triple = (TripleFusion.new(sp[0], sp[1], sp[2], level) rescue nil)
      if triple.nil?
        pbMessage(_INTL("Something went wrong and the fusion was cancelled."))
        return
      end
      (triple.calc_stats rescue nil)

      # MUTATE last: remove the two extras, then put the triple in the first's slot.
      remove_everywhere(picks[0][0])
      remove_everywhere(picks[1][0])
      unless replace_everywhere(first, triple)
        # safety net: never lose the triple
        ($PokemonStorage.pbStoreCaught(triple) rescue (($Trainer.party << triple) rescue nil))
      end
      consume_splicer(item)
      refresh_scene(scene)
      pbMessage(_INTL("The three Pokémon were fused into {1}!", triple.name))
    rescue Exception => e
      (AIGen.log("TripleFuse.run error: #{e.message}") rescue nil)
      (pbMessage(_INTL("The triple fusion hit a snag and was cancelled.")) rescue nil)
    end
  end
end

#-- Hook the party Fuse entry (covers 005 / NPT / QA mod: all call this) --------
if defined?(PokemonPartyScreen)
  class ::PokemonPartyScreen
    unless method_defined?(:aigen_orig_pbPartyFuseWithSplicer)
      if method_defined?(:pbPartyFuseWithSplicer)
        alias_method :aigen_orig_pbPartyFuseWithSplicer, :pbPartyFuseWithSplicer
        def pbPartyFuseWithSplicer(pokemon)
          begin
            if pokemon && AIGen::TripleFuse.eligible_first?(pokemon)
              choice = AIGen::TripleFuse.ask_double_triple(pokemon)
              return if choice.nil?
              if choice == :triple
                AIGen::TripleFuse.run(pokemon, @scene)
                return
              end
            end
          rescue Exception => e
            (AIGen.log("party fuse hook: #{e.message}") rescue nil)
          end
          aigen_orig_pbPartyFuseWithSplicer(pokemon)
        end
      end
    end
  end
end

#-- Hook the PC Fuse entry (the first, un-held selection) -----------------------
if defined?(PokemonStorageScreen)
  class ::PokemonStorageScreen
    unless method_defined?(:aigen_orig_pbFuseFromPC)
      if method_defined?(:pbFuseFromPC)
        alias_method :aigen_orig_pbFuseFromPC, :pbFuseFromPC
        def pbFuseFromPC(selected, heldpoke)
          begin
            if heldpoke.nil?
              first = (@storage[selected[0], selected[1]] rescue nil)
              if first && AIGen::TripleFuse.eligible_first?(first)
                choice = AIGen::TripleFuse.ask_double_triple(first)
                return if choice.nil?
                if choice == :triple
                  AIGen::TripleFuse.run(first, self)
                  return
                end
              end
            end
          rescue Exception => e
            (AIGen.log("pc fuse hook: #{e.message}") rescue nil)
          end
          aigen_orig_pbFuseFromPC(selected, heldpoke)
        end
      end
    end
  end
end
