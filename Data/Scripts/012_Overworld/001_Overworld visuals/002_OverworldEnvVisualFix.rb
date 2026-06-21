#===============================================================================
# Fork fix: Overworld weather + time-of-day VISUAL reconciler   (v4 2026-06-19)
#-------------------------------------------------------------------------------
# ROOT CAUSE (found via Logs/weather_debug.log across two test runs):
#   Graphics.delta_s returns ~0 in the overworld in this build. The base
#   RPG::Weather fade advances @fade_time by Graphics.delta_s, so with delta_s==0
#   the None->weather fade NEVER finalizes (log showed anim_type=None,
#   fading=true forever while the engine wanted HeavyRain pow=9), particles never
#   ramp in (@new_max stays 0), AND the previous watchdog's own grace timer --
#   which also used delta_s -- never elapsed, so it never forced (0 FORCE lines).
#   Particle MOTION also uses delta_s, so even a forced weather would sit frozen.
#
# FIX (this file):
#   0) Graphics.delta_s safety net: when the engine value is <= 0, synthesize a
#      real per-frame delta from a wall clock (cached per Graphics.frame_count so
#      every call within a frame agrees). No-op whenever delta_s already works.
#      This alone lets the normal fade finish and the rain actually fall.
#   1) A FRAME-COUNTED watchdog (independent of delta_s) that hard-snaps the
#      animation to the engine weather if it still isn't showing after ~4s --
#      belt-and-suspenders in case the delta_s patch can't install.
#   2) Day/night tint freshness (unchanged from before).
#   Logs (rate-limited) any update-chain exception + a ~1/sec state snapshot
#   (now including the delta_s values) to Logs/weather_debug.log. LOG_ENABLED
#   const -- set false to mute once confirmed.
#
# MP: leader-synced weather lands in $game_screen via MPEnvSync; this drives the
# VISUAL from $game_screen so it renders on members too. Official-server-safe.
#===============================================================================

module OverworldEnvVisualFix
  # Frames the animation may disagree with the engine weather before we snap it.
  # ~4s at 60fps. Frame-based so it works even if delta_s is broken.
  FORCE_AFTER_FRAMES = 240

  LOG_ENABLED = true   # Logs/weather_debug.log; set false to silence.

  @seen           = {}
  @last_state_log = nil

  module_function

  def log(msg, dedup_key = nil)
    return unless LOG_ENABLED
    if dedup_key
      return if @seen[dedup_key]
      @seen[dedup_key] = true
    end
    begin
      Dir.mkdir("Logs") unless (Dir.respond_to?(:exist?) ? Dir.exist?("Logs") : File.directory?("Logs"))
    rescue
    end
    begin
      File.open("Logs/weather_debug.log", "a") { |f| f.puts("[#{Time.now.strftime('%H:%M:%S')}] #{msg}") }
    rescue
    end
  end

  def maybe_log_state(w)
    return unless LOG_ENABLED
    now = (Graphics.frame_count rescue 0).to_f
    return if @last_state_log && (now - @last_state_log) < 60
    @last_state_log = now
    begin
      gs   = $game_screen
      vis  = w.owenv_visible_particle_count
      wt   = (w.instance_variable_get(:@weatherTypes) || {})
      cur  = wt[w.type]
      bmps = (cur && cur[1]) ? cur[1].length : -1
      raw  = (Graphics.respond_to?(:owenv_orig_delta_s) ? (Graphics.owenv_orig_delta_s rescue '?') : 'n/a')
      log("STATE gs_type=#{gs.weather_type rescue '?'} gs_pow=#{gs.weather_power rescue '?'} " \
          "gs_max=#{gs.weather_max rescue '?'} | anim_type=#{w.type} anim_max=#{w.max} " \
          "fading=#{w.instance_variable_get(:@fading)} vis=#{vis} bmps=#{bmps} " \
          "ds=#{Graphics.delta_s rescue '?'} raw_ds=#{raw}")
    rescue => e
      log("STATE log err #{e.class}: #{e.message}", "statelogerr")
    end
  end
end

#-------------------------------------------------------------------------------
# 0) Graphics.delta_s = real per-frame wall-clock seconds   (THE root-cause fix)
#-------------------------------------------------------------------------------
# In this build Graphics.delta_s == Graphics.delta / 1_000_000, and Graphics.delta
# reports near-ZERO frame *processing* time on most frames (it only spikes on a
# hitch) -- NOT the real time elapsed since the previous frame. Weather particle
# motion is `particle_delta * delta_s`, so with delta_s ~= 0 the rain sat frozen,
# and on the rare big-delta frame every particle jumped at once (the "all the
# raindrops in one diagonal line sliding across the screen" look). delta_s is
# consumed almost entirely by the weather system (plus a few UI timers that also
# want real elapsed seconds), so redefine it to a stable, clamped wall-clock
# delta measured ONCE per rendered frame.
if defined?(Graphics)
  begin
    # Keep a handle on the engine original purely so the debug log can still
    # record the (broken) raw value for comparison; our delta_s never calls it.
    unless Graphics.respond_to?(:owenv_orig_delta_s)
      class << Graphics
        alias_method :owenv_orig_delta_s, :delta_s
      end
    end
    class << Graphics
      def delta_s
        # One value per rendered frame, reused for every call within that frame
        # so all particles advance by the SAME amount (no shearing into a line).
        fc = (frame_count rescue 0)
        if @owenv_ds_frame != fc
          now = Time.now.to_f
          if @owenv_ds_wall && now > @owenv_ds_wall
            dt = now - @owenv_ds_wall
          else
            dt = 1.0 / 60.0
          end
          # Stay out of both danger zones: never ~0 (frozen) and never a giant
          # hitch (teleport). Floor ~120fps, ceiling ~15fps.
          dt = 1.0 / 120.0 if dt < 1.0 / 120.0
          dt = 1.0 / 15.0  if dt > 1.0 / 15.0
          @owenv_ds_val   = dt
          @owenv_ds_wall  = now
          @owenv_ds_frame = fc
        end
        @owenv_ds_val || (1.0 / 60.0)
      end
    end
  rescue
    # If redefining the method fails, the frame-counted watchdog below still
    # makes weather visible (just not smoothly animated).
  end
end

#-------------------------------------------------------------------------------
# 1) Overworld weather animation watchdog (frame-counted; delta_s-independent)
#-------------------------------------------------------------------------------
if defined?(RPG) && defined?(RPG::Weather)
  class RPG::Weather
    attr_reader :viewport unless method_defined?(:viewport)

    unless method_defined?(:owenv_update)
      alias_method :owenv_update, :update
      def update
        begin
          owenv_update
        rescue => e
          OverworldEnvVisualFix.log(
            "UPDATE raised #{e.class}: #{e.message} @ #{(e.backtrace && e.backtrace.first) || '?'}",
            "upd_#{e.class}_#{e.message}")
        end
        begin
          owenv_reconcile_to_screen
        rescue => e
          OverworldEnvVisualFix.log("RECONCILE raised #{e.class}: #{e.message}", "rec_#{e.class}_#{e.message}")
        end
        OverworldEnvVisualFix.maybe_log_state(self) rescue nil
      end
    end

    def owenv_visible_particle_count
      c = 0
      (@sprites || []).each { |s| c += 1 if s && s.visible && ((s.opacity rescue 0).to_i > 0) }
      c
    rescue
      0
    end

    def owenv_reconcile_to_screen
      if @viewport && @viewport.respond_to?(:rect) && @viewport.rect &&
         (@viewport.rect.width != Graphics.width || @viewport.rect.height != Graphics.height)
        @viewport.rect.set(0, 0, Graphics.width, Graphics.height)
      end

      return unless defined?($game_screen) && $game_screen
      desired = ($game_screen.weather_type rescue :None)
      desired = :None if desired.nil? || desired == 0
      desired = (GameData::Weather.get(desired).id rescue desired)

      if desired == :None
        healthy = (@type == :None) || owenv_visible_particle_count == 0
      else
        wdata           = (GameData::Weather.get(desired) rescue nil)
        needs_particles = (wdata && wdata.respond_to?(:has_particles?)) ? wdata.has_particles? : true
        healthy = (@type == desired) && (!needs_particles || owenv_visible_particle_count > 0)
      end

      if healthy
        @owenv_mismatch_frames = 0
        return
      end

      # Count FRAMES of disagreement (not delta_s seconds -- delta_s may be 0).
      @owenv_mismatch_frames = (@owenv_mismatch_frames || 0) + 1
      if @owenv_mismatch_frames >= OverworldEnvVisualFix::FORCE_AFTER_FRAMES
        OverworldEnvVisualFix.log(
          "FORCE -> #{desired} (was type=#{@type} vis=#{owenv_visible_particle_count} max=#{@max} fading=#{@fading})")
        self.type = desired
        if desired == :None
          self.set_max(0, desired) if respond_to?(:set_max)
        else
          m = 0
          m = get_max_sprites(($game_screen.weather_power rescue 0), desired) if respond_to?(:get_max_sprites)
          m = ($game_screen.weather_max rescue 0).to_i if m <= 0
          m = RPG::Weather::MAX_SPRITES if m <= 0
          self.set_max(m, desired) if respond_to?(:set_max)
        end
        @owenv_mismatch_frames = 0
      end
    end
  end
end

#-------------------------------------------------------------------------------
# 1b) Pale-particle opacity boost (Snow / Blizzard / Sandstorm visibility)
#-------------------------------------------------------------------------------
# These weather types use near-white particle art (~RGB 224,232,240) AND a screen
# tone that BRIGHTENS the overworld (Snow/Blizzard add a positive grey tone;
# Sandstorm an orange one). The base engine draws every weather particle at a flat
# opacity of 100/255 (~39%) -- fine for Rain, whose light-blue drops sit on a tone
# that DARKENS the screen so they keep contrast, but it makes the pale snow/sand
# flakes effectively invisible against their own brightened backdrop. Symptom: the
# lighting + weather HUD change but "no snow falls". Re-render these particles at
# (near) full opacity so the flakes actually show. Particle DENSITY still scales
# with intensity via @max; only per-flake opacity changes here. Rain / Storm /
# HeavyRain / Wind keep the engine default (they already read fine, and Wind
# deliberately flickers its own opacity).
if defined?(RPG) && defined?(RPG::Weather)
  class RPG::Weather
    unless defined?(OWENV_PALE_PARTICLE_OPACITY)
      OWENV_PALE_PARTICLE_OPACITY  = 235
      OWENV_OPAQUE_PARTICLE_TYPES  = [:Snow, :Blizzard, :Sandstorm]
    end

    unless method_defined?(:owenv_reset_sprite_position)
      alias_method :owenv_reset_sprite_position, :reset_sprite_position
      def reset_sprite_position(sprite, index, is_new_sprite = false)
        owenv_reset_sprite_position(sprite, index, is_new_sprite)
        # Only a freshly-placed, visible particle gets the boost; invisible
        # (recycled-out) sprites are left as the base method set them.
        return unless sprite && sprite.visible
        wt = is_new_sprite ? @target_type : @type
        if OWENV_OPAQUE_PARTICLE_TYPES.include?(wt)
          sprite.opacity = OWENV_PALE_PARTICLE_OPACITY
        end
      rescue
        nil
      end
    end
  end
end

#-------------------------------------------------------------------------------
# 2) Day/night tint freshness on outdoor maps
#-------------------------------------------------------------------------------
if defined?(Scene_Map)
  class Scene_Map
    unless method_defined?(:owenv_updateSpritesets)
      alias_method :owenv_updateSpritesets, :updateSpritesets
      def updateSpritesets(refresh = false)
        owenv_updateSpritesets(refresh)
        owenv_refresh_daynight_tint
        self
      rescue
        owenv_updateSpritesets(refresh) rescue nil
      end
    end

    def owenv_refresh_daynight_tint
      return unless defined?(Settings) && Settings::TIME_SHADING
      return unless defined?(PBDayNight)
      mr = (@map_renderer rescue nil)
      return unless mr && mr.respond_to?(:tone) && mr.tone
      return unless defined?($game_map) && $game_map
      md = (GameData::MapMetadata.try_get($game_map.map_id) rescue nil)
      return unless md && md.outdoor_map
      PBDayNight.sheduleToneRefresh if PBDayNight.respond_to?(:sheduleToneRefresh)
      t = PBDayNight.getTone
      mr.tone.set(t.red, t.green, t.blue, t.gray) if t
    rescue
      nil
    end
  end
end
