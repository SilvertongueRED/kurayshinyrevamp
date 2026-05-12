module TravelExpansionFramework
  WATER_EFFECT_PLAYER_ONLY = true unless const_defined?(:WATER_EFFECT_PLAYER_ONLY)
  WATER_EFFECT_FRAME_DELAY = 4 unless const_defined?(:WATER_EFFECT_FRAME_DELAY)

  module_function

  def water_effect_frame_bitmaps(picture = nil)
    picture = picture.to_s
    picture = "Graphics/Pictures/water" if picture.empty?
    @water_effect_frame_bitmaps ||= {}
    return @water_effect_frame_bitmaps[picture] if @water_effect_frame_bitmaps[picture]
    source = BitmapCache.load_bitmap(picture)
    return [] if !source || source.height <= 0
    frame_size = source.height
    frame_count = source.width / frame_size
    frame_count = 1 if frame_count <= 0
    width = frame_size * 2
    height = frame_size * 2
    frames = []
    frame_count.times do |i|
      bitmap = Bitmap.new(width, height)
      bitmap.stretch_blt(Rect.new(0, 0, width, height), source, Rect.new(i * frame_size, 0, frame_size, frame_size))
      frames.push(bitmap)
    end
    @water_effect_frame_bitmaps[picture] = frames
    return frames
  rescue => e
    log("[water_effect] frame cache failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return []
  end

  def optimize_water_effect_spriteset!(spriteset)
    return false if !spriteset || !defined?(WaterAnim)
    water_sprites = spriteset.instance_variable_get(:@waterSprites) rescue nil
    return false if !water_sprites.is_a?(Array)
    kept = []
    water_sprites.each do |effect|
      event = effect.instance_variable_get(:@event) rescue nil
      if event == $game_player
        kept.push(effect)
      else
        effect.dispose if effect && effect.respond_to?(:dispose)
      end
    end
    if kept.empty?
      player_sprite = spriteset.instance_variable_get(:@playersprite) rescue nil
      viewport = spriteset.instance_variable_get(:@viewport1) rescue nil
      map = spriteset.instance_variable_get(:@map) rescue $game_map
      kept.push(WaterAnim.new(player_sprite, $game_player, viewport, map)) if player_sprite && defined?($game_player) && $game_player
    end
    spriteset.instance_variable_set(:@waterSprites, kept)
    spriteset.instance_variable_set(:@tef_water_effect_optimized, true)
    map_id = ($game_map.map_id rescue nil)
    @water_effect_logged_maps ||= {}
    if !@water_effect_logged_maps[map_id]
      @water_effect_logged_maps[map_id] = true
      log("[water_effect] optimized puddle/water rings to player-only cached renderer on map #{map_id}") if respond_to?(:log)
    end
    return true
  rescue => e
    log("[water_effect] spriteset optimization failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end
end

if defined?(WaterAnim)
  class WaterAnim
    alias tef_water_effect_original_initialize initialize unless method_defined?(:tef_water_effect_original_initialize)
    alias tef_water_effect_original_dispose dispose unless method_defined?(:tef_water_effect_original_dispose)

    def initialize(sprite, event, viewport = nil, map = nil)
      @rsprite = sprite
      @event = event
      @map = map
      @disposed = false
      @viewport = viewport
      @wateranim = false
      @frame = 0
      @frames = TravelExpansionFramework::WATER_EFFECT_FRAME_DELAY
      @currentIndex = 0
      picture = defined?(WATERPICTURE) ? WATERPICTURE : "Graphics/Pictures/water"
      @tef_frame_bitmaps = TravelExpansionFramework.water_effect_frame_bitmaps(picture)
      @actualBitmap = @tef_frame_bitmaps[0] if @tef_frame_bitmaps && !@tef_frame_bitmaps.empty?
      @tef_fast_water_effect = true
      update
    rescue => e
      TravelExpansionFramework.log("[water_effect] fast WaterAnim init failed, falling back: #{e.class}: #{e.message}") if defined?(TravelExpansionFramework) &&
                                                                                                                          TravelExpansionFramework.respond_to?(:log)
      @tef_fast_water_effect = false
      tef_water_effect_original_initialize(sprite, event, viewport, map)
    end

    def dispose
      return tef_water_effect_original_dispose if @tef_fast_water_effect == false
      return if @disposed
      @sprite.bitmap = nil if @sprite && !@sprite.disposed?
      @sprite.dispose if @sprite && !@sprite.disposed?
      @sprite = nil
      @disposed = true
      @wateranim = false
    rescue
      @disposed = true
      @wateranim = false
    end

    def createWaterAnim(x2, y2)
      return if @wateranim || !@rsprite
      return if @rsprite.respond_to?(:disposed?) && @rsprite.disposed?
      frames = @tef_frame_bitmaps || []
      return if frames.empty?
      @sprite = Sprite.new(@viewport)
      @sprite.bitmap = frames[@currentIndex] || frames[0]
      @sprite.x = x2
      @sprite.y = y2
      pbDayNightTint(@sprite) if defined?(pbDayNightTint)
      @wateranim = true
    end

    def updateAnim
      return if !@wateranim || !@sprite || @sprite.disposed?
      frames = @tef_frame_bitmaps || []
      return if frames.empty?
      @frame += 1
      return if @frame < @frames && @sprite.bitmap
      @currentIndex += 1
      @currentIndex = 0 if @currentIndex >= frames.length
      @frame = 0
      @sprite.bitmap = frames[@currentIndex] || frames[0]
    end

    def tef_water_effect_in_water?
      return true if defined?($game_switches) && $game_switches && $game_switches[525]
      tag = nil
      if @event == $game_player && defined?($game_map) && $game_map && !$game_map.valid?($game_player.x, $game_player.y)
        info = getTileIdFromNewMap rescue nil
        tag = info[0].terrain_tag(info[1], info[2]) if info.is_a?(Array) && info[0]
      end
      map = @event.respond_to?(:map) ? @event.map : $game_map
      tag = map.terrain_tag(@event.x, @event.y) if tag.nil? && map && @event
      puddle_tag = defined?(WBTERRAINTAG) ? WBTERRAINTAG : 16
      return tag == puddle_tag
    rescue
      return false
    end

    def update
      return if disposed?
      return if !$scene || !defined?(Scene_Map) || !$scene.is_a?(Scene_Map)
      return if !@rsprite || (@rsprite.respond_to?(:disposed?) && @rsprite.disposed?)
      if TravelExpansionFramework::WATER_EFFECT_PLAYER_ONLY && @event != $game_player
        @sprite.dispose if @sprite && !@sprite.disposed?
        @sprite = nil
        @wateranim = false
        return
      end
      updateAnim
      in_water = tef_water_effect_in_water?
      if !in_water
        @sprite.dispose if @sprite && !@sprite.disposed?
        @sprite = nil
        @wateranim = false
        return
      end
      width = @rsprite.src_rect.width
      height = @rsprite.src_rect.height
      x = @rsprite.x - @rsprite.ox
      y = @rsprite.y - @rsprite.oy
      createWaterAnim(x, y)
      return if !@sprite || @sprite.disposed?
      @sprite.update
      @sprite.x = x + width / 2
      @sprite.y = (defined?($game_switches) && $game_switches && $game_switches[525]) ? (y + height - 20) : (y + height)
      @sprite.visible = @rsprite.visible
      @sprite.ox = @sprite.bitmap.width / 2 if @sprite.bitmap
      @sprite.oy = @sprite.bitmap.height - 4 if @sprite.bitmap
      @sprite.z = (defined?($game_switches) && $game_switches && $game_switches[525]) ? 500 : @rsprite.z
    rescue => e
      TravelExpansionFramework.log("[water_effect] update failed safely: #{e.class}: #{e.message}") if defined?(TravelExpansionFramework) &&
                                                                                                       TravelExpansionFramework.respond_to?(:log)
    end
  end
end

if defined?(Spriteset_Map)
  class Spriteset_Map
    alias tef_water_effect_original_initialize initialize unless method_defined?(:tef_water_effect_original_initialize)

    def initialize(map = nil)
      tef_water_effect_original_initialize(map)
      TravelExpansionFramework.optimize_water_effect_spriteset!(self) if defined?(TravelExpansionFramework) &&
                                                                         TravelExpansionFramework.respond_to?(:optimize_water_effect_spriteset!)
    end
  end
end
