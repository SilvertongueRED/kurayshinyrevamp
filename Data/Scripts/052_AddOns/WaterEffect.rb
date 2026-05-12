PUDDLE_ANIMATION_ID = 22
Events.onStepTakenFieldMovement += proc { |_sender, e|
  event = e[0] # Get the event affected by field movement
  next if event != $game_player
  if $scene.is_a?(Scene_Map)
    event.each_occupied_tile do |x, y|
      mapTerrainTag = if defined?(kuray_fast_field_terrain_tag)
                         kuray_fast_field_terrain_tag(event, x, y, false)
                       else
                         $MapFactory.getTerrainTag(event.map.map_id, x, y, false)
                       end
      if $PokemonGlobal.surfing
        if isWaterTerrain?(mapTerrainTag) #&& $PokemonGlobal.stepcount % 2 ==0
          $scene.spriteset.addUserAnimation(PUDDLE_ANIMATION_ID, event.x, event.y, true, 0)
        end
      else
        tag_id = mapTerrainTag.respond_to?(:id_number) ? mapTerrainTag.id_number : mapTerrainTag
        if tag_id == 16 #puddle
          pbSEPlay("puddle", 100) if event == $game_player && !$PokemonGlobal.surfing #only play sound effect in puddle
          $scene.spriteset.addUserAnimation(PUDDLE_ANIMATION_ID, event.x, event.y, true, 0)
        end
      end
    end
  end
}

def isWaterTerrain?(tag)
  tag = tag.id_number if tag.respond_to?(:id_number)
  return [5, 6, 17, 7, 9, 16].include?(tag)
end
