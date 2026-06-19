#===============================================================================
# PC Sprite Notifications  (693_SpriteNotify)
#-------------------------------------------------------------------------------
# Two linked features for the Pokemon Storage (PC):
#
#  1) A small, non-blocking "!" badge appears on the top-right corner of any
#     Pokemon in a PC box (or the party panel) when a NEW custom sprite has been
#     brought in for that Pokemon through the Custom Sprite Importer
#     (Options -> KIF Settings -> Import Custom Sprites, folder 692).
#
#  2) Selecting that Pokemon in the PC now offers a "Sprites" option that jumps
#     straight to its Pokedex Sprites entry so you can preview / pick a
#     different sprite. Opening that entry clears the "!" badge for that mon AND
#     immediately reloads its PC icon so the newly-chosen sprite shows at once.
#
# The badge is driven STRICTLY by the importer: the importer stamps a key for
# each successfully installed sprite into $PokemonGlobal.importer_new_sprites,
# and the badge clears once you open the Sprites page for that Pokemon. So a "!"
# only ever means "you imported a sprite for this one and haven't looked yet".
#
# Implementation is entirely additive (aliases / a new launcher) so it is safe
# across forks and degrades to a no-op if any piece is missing.
#===============================================================================

#-------------------------------------------------------------------------------
# Persistent store of "Pokemon with freshly-imported sprites you haven't seen".
# Keys: "head.body" for fusions, "<dexnum>" for single/base species.
#-------------------------------------------------------------------------------
class PokemonGlobalMetadata
  attr_accessor :importer_new_sprites
end

#-------------------------------------------------------------------------------
# Key helpers (top-level so the storage UI + importer can reach them).
#-------------------------------------------------------------------------------
def csi_sprite_key_for_pokemon(pokemon)
  return nil if !pokemon
  return nil if pokemon.respond_to?(:egg?) && pokemon.egg?
  species = pokemon.species
  return nil if !species
  dex = getDexNumberForSpecies(species)
  return nil if !dex || dex <= 0
  if isFusion(dex)
    body = getBodyID(species)
    head = getHeadID(species, body)
    return "#{head}.#{body}"
  end
  return "#{dex}"
rescue
  return nil
end

def csi_has_new_sprite?(pokemon)
  return false if !defined?($PokemonGlobal) || !$PokemonGlobal
  return false if !$PokemonGlobal.respond_to?(:importer_new_sprites)
  map = $PokemonGlobal.importer_new_sprites
  return false if !map || map.empty?
  key = csi_sprite_key_for_pokemon(pokemon)
  return false if !key
  return map[key] ? true : false
rescue
  return false
end

def csi_mark_new_sprite(key)
  return if !key
  return if !defined?($PokemonGlobal) || !$PokemonGlobal
  $PokemonGlobal.importer_new_sprites ||= {}
  $PokemonGlobal.importer_new_sprites[key.to_s] = true
rescue
end

def csi_clear_new_sprite(pokemon)
  return if !defined?($PokemonGlobal) || !$PokemonGlobal
  return if !$PokemonGlobal.respond_to?(:importer_new_sprites)
  return if !$PokemonGlobal.importer_new_sprites
  key = csi_sprite_key_for_pokemon(pokemon)
  return if !key
  $PokemonGlobal.importer_new_sprites.delete(key)
rescue
end

#-------------------------------------------------------------------------------
# The "!" badge graphic. Drawn once into a shared prototype bitmap; each box
# icon blits a copy so disposing one icon never harms the others.
#-------------------------------------------------------------------------------
module CSISpriteNotify
  BADGE_SIZE     = 20   # px (square)
  BADGE_OFFSET_X = 26   # relative to the icon's left edge (top-right corner)
  BADGE_OFFSET_Y = -4

  module_function

  def badge_proto
    return @proto if @proto && !@proto.disposed?
    sz = BADGE_SIZE
    bmp = Bitmap.new(sz, sz)
    cx = sz / 2.0
    cy = sz / 2.0
    r  = 8.5
    (0...sz).each do |yy|
      (0...sz).each do |xx|
        dx = xx + 0.5 - cx
        dy = yy + 0.5 - cy
        d  = Math.sqrt(dx * dx + dy * dy)
        next if d > r
        if d >= r - 1.6
          bmp.set_pixel(xx, yy, Color.new(60, 0, 0, 255))      # dark outline
        else
          bmp.set_pixel(xx, yy, Color.new(232, 48, 48, 255))   # red fill
        end
      end
    end
    begin
      pbSetSystemFont(bmp) if defined?(pbSetSystemFont)
      bmp.font.size = 16 if bmp.font
      bmp.font.bold = true if bmp.font && bmp.font.respond_to?(:bold=)
      if bmp.font
        bmp.font.color = Color.new(60, 0, 0, 255)
        bmp.draw_text(1, -1, sz, sz, "!", 1)
        bmp.font.color = Color.new(255, 255, 255, 255)
        bmp.draw_text(0, -2, sz, sz, "!", 1)
      end
    rescue
    end
    @proto = bmp
    return bmp
  end
end

#-------------------------------------------------------------------------------
# Attach a follow-along badge sprite to every PC / party box icon.
# Additive: aliases the live PokemonBoxIcon (the PokemonStorage/UI version).
#-------------------------------------------------------------------------------
if defined?(PokemonBoxIcon)
  class PokemonBoxIcon
    unless private_method_defined?(:_csi_orig_initialize)
      alias_method :_csi_orig_initialize, :initialize
      def initialize(pokemon, viewport = nil)
        _csi_orig_initialize(pokemon, viewport)
        begin
          @csi_badge = BitmapSprite.new(CSISpriteNotify::BADGE_SIZE, CSISpriteNotify::BADGE_SIZE, viewport)
          @csi_badge.visible = false
          @csi_badge.z = 50
          proto = CSISpriteNotify.badge_proto
          @csi_badge.bitmap.blt(0, 0, proto, proto.rect) if proto && @csi_badge.bitmap
          @csi_key = csi_sprite_key_for_pokemon(@pokemon)
        rescue
          @csi_badge = nil
        end
      end
    end

    unless method_defined?(:_csi_orig_refresh)
      alias_method :_csi_orig_refresh, :refresh
      def refresh(fusion_enabled = true)
        _csi_orig_refresh(fusion_enabled)
        begin
          @csi_key = csi_sprite_key_for_pokemon(@pokemon)
        rescue
        end
      end
    end

    unless method_defined?(:_csi_orig_update)
      alias_method :_csi_orig_update, :update
      def update
        _csi_orig_update
        begin
          return if !@csi_badge || @csi_badge.disposed?
          show = false
          if !@startRelease && self.visible && @csi_key
            map  = (defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.respond_to?(:importer_new_sprites)) ? $PokemonGlobal.importer_new_sprites : nil
            show = (map && map[@csi_key]) ? true : false
          end
          @csi_badge.visible = show
          if show
            @csi_badge.viewport = self.viewport
            @csi_badge.x = self.x + CSISpriteNotify::BADGE_OFFSET_X
            @csi_badge.y = self.y + CSISpriteNotify::BADGE_OFFSET_Y
            @csi_badge.z = self.z + 50
            @csi_badge.opacity = self.opacity
          end
        rescue
        end
      end
    end

    unless method_defined?(:_csi_orig_dispose)
      alias_method :_csi_orig_dispose, :dispose
      def dispose
        begin
          if @csi_badge && !@csi_badge.disposed?
            @csi_badge.bitmap.dispose if @csi_badge.bitmap && !@csi_badge.bitmap.disposed?
            @csi_badge.dispose
          end
        rescue
        end
        @csi_badge = nil
        _csi_orig_dispose
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Have the Custom Sprite Importer stamp a "new sprite" flag on each successful
# install. We wrap the importer's install_alt (which is what run actually calls);
# it returns the destination path on success or nil on failure.
#-------------------------------------------------------------------------------
if defined?(CustomSpriteImporter)
  module CustomSpriteImporter
    class << self
      if respond_to?(:install_alt) && !respond_to?(:_csi_orig_install_alt)
        alias_method :_csi_orig_install_alt, :install_alt
        def install_alt(src, head, body)
          result = _csi_orig_install_alt(src, head, body)
          begin
            if result
              key = body ? "#{head}.#{body}" : "#{head}"
              csi_mark_new_sprite(key)
            end
          rescue
          end
          return result
        end
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Reload every currently-displayed PC / party icon that shares this Pokemon's
# sprite key, so a freshly-chosen sprite shows at once and its "!" badge clears.
# (Visible change requires "big" icon mode; small generated icons are unchanged
# by the engine, but the badge still clears.)
#-------------------------------------------------------------------------------
def csi_refresh_pc_icons(scene, pokemon)
  return if !scene || !scene.respond_to?(:sprites)
  sprites = (scene.sprites rescue nil)
  return if !sprites
  target_key = csi_sprite_key_for_pokemon(pokemon)
  return if !target_key

  fusion_flag = true
  begin
    box = sprites["box"]
    fusion_flag = box.isFusionEnabled if box && box.respond_to?(:isFusionEnabled)
  rescue
  end

  icons = []
  begin
    box = sprites["box"]
    if box && box.respond_to?(:getPokemon) && defined?(PokemonBox)
      (0...PokemonBox::BOX_SIZE).each { |i| icons << (box.getPokemon(i) rescue nil) }
    end
  rescue
  end
  begin
    party = sprites["boxparty"]
    if party && party.respond_to?(:getPokemon)
      (0...Settings::MAX_PARTY_SIZE).each { |i| icons << (party.getPokemon(i) rescue nil) }
    end
  rescue
  end
  begin
    arrow = sprites["arrow"]
    if arrow && arrow.respond_to?(:heldPokemon)
      held = (arrow.heldPokemon rescue nil)
      icons << held if held
    end
  rescue
  end

  icons.each do |ic|
    next if !ic
    next if ic.respond_to?(:disposed?) && ic.disposed?
    next if !ic.respond_to?(:pokemon) || !ic.pokemon
    begin
      next if csi_sprite_key_for_pokemon(ic.pokemon) != target_key
      begin
        ic.refresh(fusion_flag)
      rescue
        (ic.refresh rescue nil)
      end
    rescue
    end
  end
end

#-------------------------------------------------------------------------------
# Launcher: open a Pokemon's Pokedex Sprites entry to pick a sprite, then clear
# its badge and reload its PC icon. Mirrors what pbDexEntry does for new catches.
# `scene` is the live PokemonStorageScene (optional) used for the icon refresh.
#-------------------------------------------------------------------------------
def pbOpenSpritesPageForPokemon(pokemon, scene = nil)
  return if !pokemon
  if pokemon.respond_to?(:egg?) && pokemon.egg?
    (pbMessage(_INTL("Eggs don't have a sprite to choose yet!")) rescue nil)
    return
  end
  species = pokemon.species
  return if !species

  alts = []
  begin
    if defined?(PokedexUtils) && PokedexUtils.respond_to?(:pbGetAvailableAlts)
      alts = PokedexUtils.pbGetAvailableAlts(species, 0)
    end
  rescue
    alts = []
  end
  alts = [] if !alts.is_a?(Array)
  alts = alts.compact

  if alts.empty?
    (pbMessage(_INTL("No sprites are available for this Pokémon right now.")) rescue nil)
    csi_clear_new_sprite(pokemon)
    csi_refresh_pc_icons(scene, pokemon)
    return
  end

  dex_scene = PokemonPokedexInfo_Scene.new
  started   = false
  begin
    started = dex_scene.pbStartSpritesSelectSceneBrief(species, alts)
    dex_scene.pbSelectSpritesSceneBrief if started
  rescue => e
    (echoln("[SpriteNotify] sprites page error: #{e.class}: #{e.message}") rescue nil)
  ensure
    begin
      dex_scene.pbEndScene if started
    rescue
    end
  end

  csi_clear_new_sprite(pokemon)         # remove the "!" notification
  csi_refresh_pc_icons(scene, pokemon)  # reload PC icon(s) to show the pick
end
