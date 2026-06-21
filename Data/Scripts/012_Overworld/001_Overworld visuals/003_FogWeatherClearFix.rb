#===============================================================================
# Fork fix: overworld WEATHER fog — sane opacity + auto-clear   (2026-06-20)
#-------------------------------------------------------------------------------
# Two related fixes for the :Fog weather, both done by aliasing RPG::Weather's
# #set_fog (the only place weather touches the map fog plane).
#
# 1) OPACITY CAP. The base engine sets $game_map.fog_opacity = 40 * weather_power
#    (so ~120-160 at the power fog is set with here). Combined with KIF's dense,
#    near-opaque white "fog_tile" texture that whites out the whole screen. We cap
#    the WEATHER fog's plane opacity to a light, see-through haze. Only the weather
#    fog ("fog_tile") is capped; a map's own tileset fog keeps its real opacity.
#    Tune OWENV_WEATHER_FOG_MAX_OPACITY if you want it thicker/thinner.
#
# 2) AUTO-CLEAR. set_fog only ever SETS fog; for any non-fog weather (fog_name nil)
#    it returns early WITHOUT clearing, so the "fog_tile" overlay would linger until
#    the next map transfer. When the new weather has no fog of its own AND the map
#    is currently showing the weather fog, we restore the map's ORIGINAL tileset fog
#    (the exact inverse of what the weather overwrote): removes lingering weather fog
#    instantly, and is safe for maps with their own built-in fog (it puts the tileset
#    fog back rather than blanking it). Never touches a non-weather fog.
#
# Purely client-side and additive; no change to how regular/map fog otherwise works.
#===============================================================================
if defined?(RPG) && defined?(RPG::Weather)
  class RPG::Weather
    unless method_defined?(:owenv_fogclear_set_fog)
      alias_method :owenv_fogclear_set_fog, :set_fog

      # The graphic the :Fog weather uses (resolved once; literal fallback).
      OWENV_WEATHER_FOG_GRAPHIC     = (GameData::Weather.get(:Fog).fog_name rescue "fog_tile")
      # Max plane opacity (0-255) for the weather fog. ~160 (engine default) = whiteout
      # with this texture; 48 reads as a light, see-through fog.
      OWENV_WEATHER_FOG_MAX_OPACITY = 48

      def set_fog(weather_type)
        # --- AUTO-CLEAR: restore the map's own fog when leaving fog weather ---
        begin
          wdata   = (GameData::Weather.get(weather_type) rescue nil)
          new_fog = wdata && wdata.fog_name
          if new_fog.nil? && defined?($game_map) && $game_map &&
             $game_map.fog_name == OWENV_WEATHER_FOG_GRAPHIC
            ts = ($data_tilesets[$game_map.tileset_id] rescue nil)
            $game_map.fog_name    = ts ? ts.fog_name    : ""
            $game_map.fog_opacity = ts ? ts.fog_opacity : 0
            $game_map.fog_sx      = ts ? ts.fog_sx      : 0
            $game_map.fog_sy      = ts ? ts.fog_sy      : 0
          end
        rescue
          begin
            if defined?($game_map) && $game_map &&
               $game_map.fog_name == OWENV_WEATHER_FOG_GRAPHIC
              $game_map.fog_name = ""
              $game_map.fog_opacity = 0
            end
          rescue
          end
        end

        # Let the engine set the fog (graphic + 40*power opacity) as normal.
        owenv_fogclear_set_fog(weather_type)

        # --- OPACITY CAP: thin the dense weather fog down to a readable haze ---
        begin
          if defined?($game_map) && $game_map &&
             $game_map.fog_name == OWENV_WEATHER_FOG_GRAPHIC &&
             $game_map.fog_opacity.to_i > OWENV_WEATHER_FOG_MAX_OPACITY
            $game_map.fog_opacity = OWENV_WEATHER_FOG_MAX_OPACITY
          end
        rescue
        end
      end
    end
  end
end
