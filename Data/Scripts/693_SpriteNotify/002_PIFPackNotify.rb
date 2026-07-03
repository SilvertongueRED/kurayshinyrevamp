#===============================================================================
# PIF Monthly Pack — "New Sprite Available" Popup  (693_SpriteNotify)
#-------------------------------------------------------------------------------
# The game already re-downloads PIF's online custom-sprite manifest
# (Data/sprites/CUSTOM_SPRITES) every time it boots, via updateOnlineCustomSpritesFile
# (052_AddOns/HttpCalls.rb) -- gated on the "Download data" option. That manifest
# is just a flat list of filenames PIF's servers currently have; individual sprite
# PNGs are still fetched lazily, one at a time, the first time a fusion is viewed
# (download_custom_sprite / download_autogen_sprite).
#
# This file adds a genuine "hey, this is new" popup on top of that pipeline:
#
#  1) Every boot, BEFORE the manifest is overwritten, we snapshot the old list.
#     After the refresh, we diff old vs new and stash any newly-added filenames
#     into a small pending-list file (Data/sprites/pif_pending_new.txt). First
#     boot ever (no prior manifest) is skipped so we don't flag the entire
#     existing library as "new".
#
#  2) When the player opens the Pokedex "Sprites" page for a fusion
#     (PokemonPokedexInfo_Scene#pbGetAvailableForms, in 052_AddOns/
#     UI_Pokedex_SpritesPage.rb), we check whether any pending filename belongs
#     to that exact head/body pair. If so we show a one-time pbMessage popup and
#     remove those entries from the pending list -- so it only ever fires once,
#     and only once you actually look at the fusion it belongs to, exactly like
#     the base sprite-download already only happens per-fusion, on demand.
#
# Divergent Hoenn+ ids (502-572, where the fork's NPT numbering splits from
# PIF's) are translated fork-id -> PIF-id via 990_NPT/020_PIFRemap.rb before
# checking the manifest, since the manifest itself is PIF-numbered. This file
# does not touch the actual download path at all (that's still 009_SpritePacks
# -> PIFRemapDownload -> HttpCalls, unmodified), so newly-flagged sprites for
# those divergent species still get correctly remapped/renamed to fork numbering
# by PIFRemapDownload.rb exactly as before -- this is purely a notification
# layer on top.
#
# Additive / alias-based; degrades to a silent no-op if anything is missing.
#===============================================================================

module PIFPackNotify
  PENDING_FILE    = "Data/sprites/pif_pending_new.txt"
  FUSION_LINE_RE  = /\A(\d+)\.(\d+)([a-z]?)\.png\z/i

  module_function

  def parse_manifest(path)
    set = {}
    return set unless File.exist?(path)
    File.foreach(path) do |line|
      line = line.strip
      next if line.empty?
      set[line] = true if FUSION_LINE_RE.match?(line)
    end
    set
  rescue
    {}
  end

  def load_pending
    h = {}
    return h unless File.exist?(PENDING_FILE)
    File.foreach(PENDING_FILE) do |line|
      line = line.strip
      h[line] = true unless line.empty?
    end
    h
  rescue
    {}
  end

  def save_pending(hash)
    Dir.mkdir("Data/sprites") unless Dir.exist?("Data/sprites")
    File.open(PENDING_FILE, "wb") { |f| f.write(hash.keys.join("\n")) }
  rescue
  end

  # Diff two manifest snapshots and merge any newly-added fusion filenames into
  # the persistent pending list. Skips entirely if there was no prior manifest
  # to diff against (first-ever boot).
  def diff_and_merge!(old_set, new_set, had_old_file)
    return unless had_old_file
    added = new_set.keys - old_set.keys
    return if added.empty?
    pending = load_pending
    added.each { |f| pending[f] = true }
    save_pending(pending)
    echoln "[PIFPackNotify] #{added.size} new custom sprite(s) detected in this pack refresh."
  rescue => e
    echoln "[PIFPackNotify] diff_and_merge! error: #{e.class}: #{e.message}"
  end

  # Pops (removes + returns) any pending filenames for this PIF-numbered head/body
  # pair, across all alt letters. Empty array if none.
  def pop_pending_for(pif_head, pif_body)
    pending = load_pending
    return [] if pending.empty?
    re = /\A#{Regexp.escape(pif_head.to_s)}\.#{Regexp.escape(pif_body.to_s)}[a-z]?\.png\z/i
    matches = pending.keys.select { |f| f =~ re }
    return [] if matches.empty?
    matches.each { |f| pending.delete(f) }
    save_pending(pending)
    matches
  rescue => e
    echoln "[PIFPackNotify] pop_pending_for error: #{e.class}: #{e.message}"
    []
  end
end

# --- Snapshot + diff the manifest on every refresh (title-screen boot) -------
alias _pifpacknotify_orig_updateOnlineCustomSpritesFile updateOnlineCustomSpritesFile
def updateOnlineCustomSpritesFile
  had_old = File.exist?(Settings::CUSTOM_SPRITES_FILE_PATH)
  old_set = had_old ? PIFPackNotify.parse_manifest(Settings::CUSTOM_SPRITES_FILE_PATH) : {}
  result = _pifpacknotify_orig_updateOnlineCustomSpritesFile
  begin
    if result
      new_set = PIFPackNotify.parse_manifest(Settings::CUSTOM_SPRITES_FILE_PATH)
      PIFPackNotify.diff_and_merge!(old_set, new_set, had_old)
    end
  rescue => e
    echoln "[PIFPackNotify] refresh-hook error: #{e.class}: #{e.message}"
  end
  result
end

# --- Popup when viewing a fusion's Sprites page that has pending news --------
if defined?(PokemonPokedexInfo_Scene) && PokemonPokedexInfo_Scene.method_defined?(:pbGetAvailableForms)
  class PokemonPokedexInfo_Scene
    alias _pifpacknotify_orig_pbGetAvailableForms pbGetAvailableForms
    def pbGetAvailableForms(species = nil)
      result = _pifpacknotify_orig_pbGetAvailableForms(species)
      begin
        chosen_species = species != nil ? species : @species
        dex_num = getDexNumberForSpecies(chosen_species)
        if dex_num && dex_num > NB_POKEMON
          body_id = getBodyID(chosen_species)
          head_id = getHeadID(chosen_species, body_id)
          pif_head = (defined?(PIFRemap) ? PIFRemap.fork_to_pif(head_id) : head_id)
          pif_body = (defined?(PIFRemap) ? PIFRemap.fork_to_pif(body_id) : body_id)
          matches = PIFPackNotify.pop_pending_for(pif_head, pif_body)
          if !matches.empty?
            pbMessage(_INTL("A new official PIF custom sprite is now available for this fusion! Check the sprites below."))
          end
        end
      rescue => e
        echoln "[PIFPackNotify] popup-hook error: #{e.class}: #{e.message}"
      end
      result
    end
  end
end

echoln "[693_SpriteNotify] PIFPackNotify loaded (new-sprite popup, per-fusion, shown once)"
