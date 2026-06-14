#==============================================================================
# PIF <-> Fork Sprite Auto-Download Remap  (ships to ALL fork users)
# File: Data/Scripts/052_AddOns/PIFRemapDownload.rb
#
# PIF auto-downloads each missing custom sprite on demand from its live repo
# (Settings::CUSTOM_SPRITES_REPO_URL), gated by the "Download data" option
# ($PokemonSystem.download_sprites). For Hoenn+ ids 553-572 the fork's numbering
# differs from PIF's, so a plain download would fetch the WRONG species' art.
#
# This hooks that same auto-download path: when a missing sprite involves a
# divergent id, it requests the PIF-numbered sprite from the live repo and saves
# it under the correct FORK filename. Every user automatically gets up-to-date
# official PIF art at the right numbers, no manual packs, no input.
#
# Also adds:
#   * Options -> "PIF Sprite Auto-Fix"  : master toggle (On by default).
#   * Options -> "Refresh PIF Sprites"  : on-demand re-download of your party's
#                                         divergent sprites (picks up upstream fixes).
#   * Automatic refresh of your party's divergent sprites about every 2 months
#     (the "every other monthly pack" cadence) so fixes propagate with no input.
#
# Client-side only; no multiplayer impact.
#==============================================================================

PIFREMAP_REFRESH_FILE     = "Data/sprites/pif_last_refresh.txt"
PIFREMAP_REFRESH_INTERVAL = 60 * 24 * 3600   # ~2 months, in seconds

# --- Setting (nil-safe; defaults ON for existing saves) ----------------------
class PokemonSystem
  attr_writer :pif_auto_sprites unless method_defined?(:pif_auto_sprites=)
  unless method_defined?(:pif_auto_sprites)
    def pif_auto_sprites
      v = instance_variable_defined?(:@pif_auto_sprites) ? @pif_auto_sprites : nil
      v.nil? ? 0 : v   # 0 = On (default), 1 = Off
    end
  end
end
$PokemonSystem.pif_auto_sprites = 0 if $PokemonSystem && $PokemonSystem.instance_variable_get(:@pif_auto_sprites).nil?

# --- Add KIF toggle + refresh button to the Options menu ---------------------
class PokemonOption_Scene
  alias _pifremap_orig_pbGetOptions pbGetOptions
  def pbGetOptions(inloadscreen = false)
    options = _pifremap_orig_pbGetOptions(inloadscreen)
    options << EnumOption.new(
      _INTL("PIF Sprite Auto-Fix"),
      [_INTL("On"), _INTL("Off")],
      proc { $PokemonSystem.pif_auto_sprites },
      proc { |value| $PokemonSystem.pif_auto_sprites = value },
      _INTL("Auto-download official PIF sprites for Hoenn+ Pokemon at the correct fork numbers (needs Download data On).")
    )
    options << ButtonOption.new(
      _INTL("Refresh PIF Sprites"),
      proc {
        if pifremap_active?
          n = pifremap_refresh_party
          pbMessage(_INTL("Refreshed {1} party sprite(s) with the latest official PIF art.", n))
        else
          pbMessage(_INTL("Turn on 'Download data' and 'PIF Sprite Auto-Fix' first."))
        end
      },
      _INTL("Re-download your party's Hoenn+ sprites to pick up upstream fixes. Runs automatically about every 2 months too."),
      _INTL("Refresh")
    )
    options
  end
end

# --- Helpers -----------------------------------------------------------------
def pifremap_active?
  return false unless defined?(PIFRemap)
  return false unless $PokemonSystem && $PokemonSystem.pif_auto_sprites == 0
  downloadAllowed?()
rescue
  false
end

# Download the PIF-numbered custom sprite and save it under the FORK filename.
def pifremap_download_custom(fork_head, fork_body, alt_letter = "")
  return nil unless downloadAllowed?()
  return nil if requestRateExceeded?(Settings::CUSTOMSPRITES_RATE_LOG_FILE,
                                     Settings::CUSTOMSPRITES_ENTRIES_RATE_TIME_WINDOW,
                                     Settings::CUSTOMSPRITES_RATE_MAX_NB_REQUESTS)
  ph = PIFRemap.fork_to_pif(fork_head)
  pb = PIFRemap.fork_to_pif(fork_body)
  dest_dir = "#{Settings::CUSTOM_BATTLERS_FOLDER_INDEXED}#{fork_head}"
  Dir.mkdir(dest_dir) unless Dir.exist?(dest_dir)
  dest = "#{dest_dir}/#{fork_head}.#{fork_body}#{alt_letter}.png"
  return dest if pbResolveBitmap(dest)
  url = "#{Settings::CUSTOM_SPRITES_REPO_URL}#{ph}.#{pb}#{alt_letter}.png"
  begin
    response = HTTPLite.get(url)
    if response && response[:status] == 200
      File.open(dest, "wb") { |file| file.write(response[:body]) }
      echoln "[PIFRemap] #{ph}.#{pb}#{alt_letter} (PIF) -> #{fork_head}.#{fork_body}#{alt_letter} (fork)"
      return dest
    end
  rescue MKXPError, Errno::ENOENT
  end
  nil
end

# Force a re-download (used by refresh): delete the local copy first so the
# latest official art is fetched, bypassing the bundled .pak.
def pifremap_force_refresh(fork_head, fork_body, alt_letter = "")
  return false unless PIFRemap.divergent_fork?(fork_head.to_i) ||
                      (fork_body.to_i > 0 && PIFRemap.divergent_fork?(fork_body.to_i))
  dest = "#{Settings::CUSTOM_BATTLERS_FOLDER_INDEXED}#{fork_head}/#{fork_head}.#{fork_body}#{alt_letter}.png"
  File.delete(dest) if File.exist?(dest)
  !pifremap_download_custom(fork_head.to_i, fork_body.to_i, alt_letter.to_s).nil?
rescue
  false
end

# Refresh the divergent sprites for the player's current party (bounded + fast).
def pifremap_refresh_party
  return 0 unless pifremap_active?
  return 0 unless $Trainer && $Trainer.respond_to?(:party) && $Trainer.party
  n = 0
  $Trainer.party.each do |pkmn|
    next unless pkmn
    begin
      next unless pkmn.respond_to?(:isFusion?) && pkmn.isFusion?
      fused = getDexNumberForSpecies(pkmn)
      body  = getBodyID(fused)
      head  = getHeadID(fused, body)
      next unless PIFRemap.divergent_fork?(head.to_i) || PIFRemap.divergent_fork?(body.to_i)
      n += 1 if pifremap_force_refresh(head, body, "")
    rescue
      next
    end
  end
  n
end

def pifremap_mark_refreshed!
  Dir.mkdir("Data/sprites") unless Dir.exist?("Data/sprites")
  File.write(PIFREMAP_REFRESH_FILE, Time.now.to_i.to_s)
rescue
end

def pifremap_refresh_due?
  if File.exist?(PIFREMAP_REFRESH_FILE)
    last = File.read(PIFREMAP_REFRESH_FILE).to_i
    return (Time.now.to_i - last) >= PIFREMAP_REFRESH_INTERVAL
  end
  pifremap_mark_refreshed!   # first run: initialize, not due
  false
rescue
  false
end

# --- Hook the on-demand custom-sprite downloader -----------------------------
alias _pifremap_orig_download_custom download_custom_sprite
def download_custom_sprite(head_id, body_id, spriteformBody_suffix = "", spriteformHead_suffix = "", alt_letter = "")
  if spriteformBody_suffix.to_s.empty? && spriteformHead_suffix.to_s.empty? &&
     pifremap_active? &&
     (PIFRemap.divergent_fork?(head_id.to_i) || PIFRemap.divergent_fork?(body_id.to_i))
    return pifremap_download_custom(head_id.to_i, body_id.to_i, alt_letter.to_s)
  end
  _pifremap_orig_download_custom(head_id, body_id, spriteformBody_suffix, spriteformHead_suffix, alt_letter)
end

# --- Automatic ~2-month refresh (once per session, in the overworld) ---------
class Scene_Map
  alias _pifremap_orig_update update
  def update(*args)
    _pifremap_orig_update(*args)
    unless $pifremap_session_checked
      $pifremap_session_checked = true
      begin
        if pifremap_active? && pifremap_refresh_due?
          pifremap_refresh_party
          pifremap_mark_refreshed!
        end
      rescue
      end
    end
  end
end

echoln "[052_AddOns] PIFRemapDownload loaded (auto-fix + refresh; toggle/button in Options)"
