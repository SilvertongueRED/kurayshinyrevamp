#===============================================================================
# Fork fix: Overworld weather + time-of-day VISUAL reconciler
#-------------------------------------------------------------------------------
# Symptom this fixes:
#   The engine weather STATE is correct (the overworld weather box reads
#   $game_screen.weather_type and shows e.g. Storm, EBDX battles inherit it,
#   rain/thunder audio plays) but the OVERWORLD shows no rain particles and no
#   storm darkening, and the day/night tint can look stuck. The state is right;
#   the on-screen animation/tint just fails to track it (a stalled RPG::Weather
#   fade, a weather viewport left stale after an overworld-zoom Graphics.resize,
#   or a stale day/night tone cache).
#
# What it does (purely client-side, additive, all heavily guarded):
#   * RPG::Weather watchdog: every frame it compares the live weather animation
#     to $game_screen.weather_type. If they disagree for longer than a normal
#     fade should take (~7s), it force-sets the animation instantly so the
#     visual can NEVER get permanently stuck behind the real weather. It also
#     keeps the weather viewport sized to the live screen (overworld-zoom safe).
#   * Day/night tint: re-applies a FRESHLY computed day/night tone to the map
#     renderer each frame on outdoor maps, so the tint always matches the
#     current in-game clock instead of a cached value.
#
# Multiplayer: a squad member's leader-synced weather already lands in
#   $game_screen via MPEnvSync (005_Coop/029_EnvSync.rb), and the leader stamps
#   :wx/:wpow/:tod into the relayed SYNC. Because this watchdog drives the
#   VISUAL from $game_screen, the leader's weather/time now reliably RENDERS on
#   members too. No server-relayed fork message is required (official-server-safe).
#===============================================================================

module OverworldEnvVisualFix
  # How long (real seconds) a visible weather mismatch may persist before we
  # stop waiting for the smooth fade and snap the animation to match. A normal
  # RPG::Weather fade completes in ~5s, so 7s only ever triggers on a true stall.
  FORCE_AFTER_SECONDS = 7.0
end

#-------------------------------------------------------------------------------
# 1) Overworld weather animation watchdog
#-------------------------------------------------------------------------------
if defined?(RPG) && defined?(RPG::Weather)
  class RPG::Weather
    attr_reader :viewport unless method_defined?(:viewport)

    unless method_defined?(:owenv_update)
      alias_method :owenv_update, :update
      def update
        owenv_update
        owenv_reconcile_to_screen
      rescue
        # Never let the watchdog break the base animation update.
        nil
      end
    end

    def owenv_reconcile_to_screen
      # (a) Keep our private viewport sized to the live screen. Overworld zoom
      #     uses Graphics.resize_screen, which does NOT resize this viewport
      #     (it's created once at spriteset build time), so particles can end up
      #     clipped to a stale rectangle after a zoom change.
      if @viewport && @viewport.respond_to?(:rect) && @viewport.rect &&
         (@viewport.rect.width != Graphics.width || @viewport.rect.height != Graphics.height)
        @viewport.rect.set(0, 0, Graphics.width, Graphics.height)
      end

      return unless defined?($game_screen) && $game_screen
      desired = ($game_screen.weather_type rescue :None)
      desired = :None if desired.nil? || desired == 0
      desired = (GameData::Weather.get(desired).id rescue desired)

      if @type == desired
        @owenv_mismatch_t = 0.0
        return
      end

      # The visible animation type differs from the engine weather. Give the
      # normal smooth fade a grace window, then force it so it can't stick.
      dt = (Graphics.delta_s rescue (1.0 / 60.0))
      @owenv_mismatch_t = (@owenv_mismatch_t || 0.0) + dt
      if @owenv_mismatch_t >= OverworldEnvVisualFix::FORCE_AFTER_SECONDS
        self.type = desired                              # instant; clears a stuck fade
        max = (($game_screen.weather_max rescue 0)).to_i # matches power set by caller
        self.set_max(max, desired) if respond_to?(:set_max)
        @owenv_mismatch_t = 0.0
      end
    rescue
      nil
    end
  end
end

#-------------------------------------------------------------------------------
# 2) Day/night tint freshness on outdoor maps
#-------------------------------------------------------------------------------
# pbDayNightTint already runs every frame from Scene_Map#updateSpritesets, but
# it reads PBDayNight.getTone, which is cached and only recomputed on an
# interval. With the accelerated in-game clock that cache can lag the real time
# of day. We re-apply a freshly computed tone right after the engine's pass so
# the overworld tint always matches the current clock. Same condition the engine
# uses (outdoor maps + TIME_SHADING), so behaviour is unchanged otherwise.
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
