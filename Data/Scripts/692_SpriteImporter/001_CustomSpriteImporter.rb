#===============================================================================
# Custom Sprite Importer
#-------------------------------------------------------------------------------
# Adds  Options -> KIF Settings -> "Import Custom Sprites".
#
# No more hunting for dex IDs in 990_NPT/001_Registration.rb and hand-naming
# files. Instead:
#   1) Drop your own .png sprites into the  CustomSpriteImport/  folder that
#      sits in your game directory (created automatically).
#   2) Open  Options -> KIF Settings -> Import Custom Sprites.
#   3) Pick the file, then search a Pokemon by NAME (or dex number) for the
#      head and body of a fusion, or one Pokemon for a base sprite.
#
# Imported sprites are added as ALTERNATE sprites (into the game's custom-sprite
# folders) rather than overwriting the existing art, so nothing is destroyed and
# you can always switch back from the Pokedex sprite page.
#
# After you next load a save, if any Pokemon in your party has a freshly
# imported sprite available, the game asks whether you'd like to start using it.
# Say no and it stays as-is; either way you can swap sprites at any time the
# usual way (alt sprites in the Pokedex).
#===============================================================================
module CustomSpriteImporter
  INBOX     = "CustomSpriteImport"
  MANIFEST  = "CustomSpriteImport/.imported_sprites.txt"
  BATTLERS  = "Graphics/Battlers"

  module_function

  def custom_fusion_folder
    (defined?(Settings) && Settings.const_defined?(:CUSTOM_BATTLERS_FOLDER_INDEXED)) ?
      Settings::CUSTOM_BATTLERS_FOLDER_INDEXED : "Graphics/CustomBattlers/indexed/"
  end

  def custom_base_folder
    (defined?(Settings) && Settings.const_defined?(:CUSTOM_BASE_SPRITES_FOLDER)) ?
      Settings::CUSTOM_BASE_SPRITES_FOLDER : "Graphics/BaseSprites/"
  end

  def alt_letters
    if defined?(PokedexUtils) && PokedexUtils.respond_to?(:getAltLettersList)
      return PokedexUtils.getAltLettersList
    end
    ('a'..'z').to_a + ('aa'..'az').to_a
  end

  # [[id_number, real_name], ...] for every base species (form 0), incl. NPT mons.
  def species_list
    return @species_list if @species_list
    seen = {}
    arr  = []
    GameData::Species.each do |s|
      next unless s.respond_to?(:form) && s.form == 0
      n = s.id_number
      next if n.nil? || n <= 0
      next if seen[n]
      seen[n] = true
      arr.push([n, s.real_name])
    end
    arr.sort_by! { |e| e[0] }
    @species_list = arr
  end

  def ensure_inbox
    Dir.mkdir(INBOX) unless File.directory?(INBOX)
  rescue
  end

  def inbox_files
    return [] unless File.directory?(INBOX)
    Dir.entries(INBOX).select { |f|
      f =~ /\.png\z/i && File.file?("#{INBOX}/#{f}")
    }.sort
  end

  def name_for(id)
    sp = (GameData::Species.try_get(id) rescue nil)
    sp ? sp.real_name : id.to_s
  end

  # Search/pick a species by name or dex number. Returns id_number or nil.
  def pick_species(prompt)
    list = species_list
    query = ""
    begin
      query = pbEnterText(_INTL("{1}\n(type part of a name or a dex number; blank = browse all)", prompt), 0, 30, "")
    rescue
      query = ""
    end
    query = "" if query.nil?
    q = query.strip.downcase
    matches = list
    unless q.empty?
      if q =~ /\A\d+\z/
        idq = q.to_i
        matches = list.select { |e| e[0] == idq || e[1].downcase.include?(q) }
      else
        matches = list.select { |e| e[1].downcase.include?(q) }
      end
    end
    if matches.empty?
      pbMessage(_INTL("No Pokemon matched \"{1}\".", query))
      return nil
    end
    cmds = matches.map { |e| [e[0], e[1]] }
    result = pbChooseList(cmds, 0, -1, -1)   # shows "NNN: Name", returns id_number, -1 on cancel
    return nil if result.nil? || result == -1
    return result
  end

  # First alt-letter slot (a, b, c, ...) with no existing file for this fusion.
  # base==nil means a single-Pokemon base sprite.
  def next_free_alt_path(head, body)
    if body
      dir = "#{custom_fusion_folder}#{head}"
      stem = "#{head}.#{body}"
      alt_letters.each do |ltr|
        path = "#{dir}/#{stem}#{ltr}.png"
        return path unless File.exist?(path)
      end
      return "#{dir}/#{stem}_import.png"
    else
      dir = custom_base_folder.chomp("/")
      alt_letters.each do |ltr|
        path = "#{dir}/#{head}#{ltr}.png"
        return path unless File.exist?(path)
      end
      return "#{dir}/#{head}_import.png"
    end
  end

  # Copies src in as a NEW alternate sprite. Returns the destination path, or nil.
  def install_alt(src, head, body)
    dst = next_free_alt_path(head, body)
    dir = File.dirname(dst)
    Dir.mkdir(dir) unless File.directory?(dir)
    file_copy(src, dst)
    return dst
  rescue
    pbMessage(_INTL("Could not write the sprite file. Make sure the game isn't running from a read-only location."))
    return nil
  end

  #-----------------------------------------------------------------------------
  # Manifest: a plain-text record of every sprite this tool has imported, so the
  # post-load prompt knows which party members have something new to offer.
  # One record per line:  dex|head|body|path     (body blank for base sprites)
  #-----------------------------------------------------------------------------
  def manifest_records
    return [] unless File.file?(MANIFEST)
    out = []
    File.foreach(MANIFEST) do |line|
      line = line.strip
      next if line.empty?
      parts = line.split("|", 4)
      next if parts.size < 4
      dex  = parts[0].to_i
      head = parts[1].to_i
      body = (parts[2].nil? || parts[2].empty?) ? nil : parts[2].to_i
      path = parts[3]
      out << { :dex => dex, :head => head, :body => body, :path => path }
    end
    out
  rescue
    []
  end

  def record_manifest(dex, head, body, path)
    ensure_inbox
    line = "#{dex}|#{head}|#{body}|#{path}\n"
    File.open(MANIFEST, "a") { |f| f.write(line) }
  rescue
  end

  def run
    ensure_inbox
    loop do
      files = inbox_files
      if files.empty?
        pbMessage(_INTL("No sprite files found.\n\nDrop your .png sprites into the \"{1}\" folder in your game directory, then open this again.", INBOX))
        return
      end
      fcmds = []
      files.each_with_index { |f, i| fcmds.push([i, f]) }
      sel = pbChooseList(fcmds, 0, -1, 1)   # alphabetical, returns original index, -1 on cancel
      return if sel.nil? || sel == -1
      basename = files[sel]
      src = "#{INBOX}/#{basename}"

      kind = pbMessage(_INTL("How should \"{1}\" be used?", basename),
        [_INTL("Fusion (two Pokemon)"),
         _INTL("Single Pokemon (base sprite)"),
         _INTL("Cancel")], -1)
      next if kind < 0 || kind == 2

      if kind == 0
        a = pick_species(_INTL("Select the FIRST Pokemon (head):"))
        next if a.nil?
        b = pick_species(_INTL("Select the SECOND Pokemon (body):"))
        next if b.nil?
        both = pbConfirmMessage(_INTL("Use this sprite for BOTH fusion directions?\n  {1} / {2}   and   {2} / {1}\n(Recommended.)", name_for(a), name_for(b)))
        done = []
        p1 = install_alt(src, a, b)
        if p1
          record_manifest(getSpeciesIdForFusion(a, b), a, b, p1)
          done.push(p1)
        end
        if both
          p2 = install_alt(src, b, a)
          if p2
            record_manifest(getSpeciesIdForFusion(b, a), b, a, p2)
            done.push(p2)
          end
        end
        if done.empty?
          pbMessage(_INTL("Nothing was imported."))
        else
          pbMessage(_INTL("Imported as a new alternate sprite:\n{1}\n\nLoad your save (or check the Pokedex sprite page) to start using it.", done.join("\n")))
          offer_cleanup(src, basename)
        end
      else
        id = pick_species(_INTL("Select the Pokemon for this base sprite:"))
        next if id.nil?
        p = install_alt(src, id, nil)
        if p
          record_manifest(id, id, nil, p)
          pbMessage(_INTL("Imported as a new alternate sprite:\n{1}\n\nLoad your save (or check the Pokedex sprite page) to start using it.", p))
          offer_cleanup(src, basename)
        else
          pbMessage(_INTL("Nothing was imported."))
        end
      end
    end
  end

  def offer_cleanup(src, basename)
    return unless pbConfirmMessage(_INTL("Remove \"{1}\" from the inbox folder now?", basename))
    begin
      File.delete(src)
    rescue
      pbMessage(_INTL("Couldn't delete the file (it may be open elsewhere). You can remove it manually."))
    end
  end

  #-----------------------------------------------------------------------------
  # Post-load prompt: offer to apply freshly imported sprites to party members.
  #-----------------------------------------------------------------------------

  # The substitution key the sprite system uses for a given dex number (form 0).
  def substitution_id_for(dex)
    dex.to_s
  end

  # Does this party Pokemon match a manifest record?
  def pokemon_matches?(pkmn, rec)
    return false if pkmn.nil?
    dex = (getDexNumberForSpecies(pkmn) rescue nil)
    return false if dex.nil?
    return dex == rec[:dex]
  end

  def already_decided?(key)
    return false unless $PokemonGlobal
    $PokemonGlobal.csi_sprite_decisions ||= {}
    $PokemonGlobal.csi_sprite_decisions.key?(key)
  end

  def mark_decided(key, value)
    return unless $PokemonGlobal
    $PokemonGlobal.csi_sprite_decisions ||= {}
    $PokemonGlobal.csi_sprite_decisions[key] = value
  end

  # Current displayed sprite path for a dex (the one that ISN'T our import),
  # used to "pin" the choice when the player declines.
  def current_main_path(dex, imported_path)
    list = []
    begin
      sp = GameData::Species.try_get(dex)
      list = PokedexUtils.pbGetAvailableAlts(sp, 0) if sp
    rescue
      list = []
    end
    list = list.compact.reject { |p| p == imported_path }
    list.first
  end

  def offer_party_swaps
    return unless $Trainer && $Trainer.respond_to?(:party) && $Trainer.party
    recs = manifest_records
    return if recs.empty?
    $PokemonGlobal.alt_sprite_substitutions ||= {} if $PokemonGlobal

    $Trainer.party.each do |pkmn|
      next if pkmn.nil?
      next if pkmn.respond_to?(:egg?) && pkmn.egg?
      recs.each do |rec|
        next unless File.exist?(rec[:path]) rescue next
        next unless pokemon_matches?(pkmn, rec)
        subid = substitution_id_for(rec[:dex])
        key   = "#{subid}|#{rec[:path]}"
        next if already_decided?(key)

        # Already using this exact sprite? Nothing to ask.
        cur = ($PokemonGlobal.alt_sprite_substitutions[subid] rescue nil)
        if cur == rec[:path]
          mark_decided(key, true)
          next
        end

        nm = (pkmn.name rescue name_for(rec[:dex]))
        msg = _INTL("{1} has a newly imported custom sprite available.\nUse it for {1} now?\n(You can switch back anytime from the Pokedex sprite page.)", nm)
        if pbConfirmMessage(msg)
          set_alt_sprite_substitution(rec[:dex], rec[:path], 0)
          mark_decided(key, true)
        else
          # Pin the current sprite so it won't randomly flip to the new alt.
          keep = current_main_path(rec[:dex], rec[:path])
          set_alt_sprite_substitution(rec[:dex], keep, 0) if keep
          mark_decided(key, false)
        end
      end
    end
  rescue => e
    echoln("[CustomSpriteImporter] offer_party_swaps error: #{e.message}") rescue nil
  end
end

#-------------------------------------------------------------------------------
# Persisted, per-save record of which imported sprites the player has already
# been asked about (so they aren't nagged every load).
#-------------------------------------------------------------------------------
class PokemonGlobalMetadata
  attr_accessor :csi_sprite_decisions
end

#-------------------------------------------------------------------------------
# Run the party-swap prompt right after a save finishes loading.
#-------------------------------------------------------------------------------
if defined?(onLoadExistingGame)
  alias _csi_orig_onLoadExistingGame onLoadExistingGame
  def onLoadExistingGame
    _csi_orig_onLoadExistingGame
    $PokemonTemp.csi_party_check_pending = true if defined?($PokemonTemp) && $PokemonTemp
  end
end

class PokemonTemp
  attr_accessor :csi_party_check_pending
end

# Defer the actual prompting to the first overworld frame, where the message
# system is guaranteed to be live.
if defined?(Events) && Events.respond_to?(:onMapUpdate)
  Events.onMapUpdate += proc { |_sender, _e|
    if $PokemonTemp && $PokemonTemp.csi_party_check_pending
      $PokemonTemp.csi_party_check_pending = false
      CustomSpriteImporter.offer_party_swaps
    end
  }
end

#-------------------------------------------------------------------------------
# Add the entry to  Options -> KIF Settings.
#-------------------------------------------------------------------------------
if defined?(KurayOptionsScene)
  class KurayOptionsScene
    unless method_defined?(:_csi_orig_pbGetOptions)
      alias_method :_csi_orig_pbGetOptions, :pbGetOptions
      def pbGetOptions(inloadscreen = false)
        options = _csi_orig_pbGetOptions(inloadscreen)
        begin
          btn = ButtonOption.new(_INTL("Import Custom Sprites"),
            proc {
              pbFadeOutIn {
                CustomSpriteImporter.run
              }
            },
            _INTL("Add your own Pokemon / fusion sprites from the CustomSpriteImport folder."),
            _INTL("Open"))
          idx = options.index { |o| o.respond_to?(:name) && o.name == _INTL("Self-Battle & Import") }
          idx ? options.insert(idx + 1, btn) : options << btn
        rescue
        end
        return options
      end
    end
  end
end
