#===============================================================================
# 694_AISprites - 007_AIGen_PickerActions.rb
# Folds every sprite action into ONE combined menu that opens from the picker's
# "Use: Sprite options" button (Input::USE). There is no longer a separate RUN /
# Input::ACTION menu -- pbSpriteOptionsMenu offers:
#   * Use this sprite       -> apply the displayed sprite (closes the picker)
#   * Generate New Sprite    -> make an AI sprite, then Keep / Use / Delete / Retry
#   * Regenerate / Delete    (when the selected sprite is already an AI one)
#   * Share this sprite to Discord  (folds in the 693 DiscordShare action)
#   * Delete sprite / Open sprite folder  (when the summary_sprite_tools mod
#                                          provides those local-sprite helpers)
# The summary_sprite_tools mod's manage_selected_sprite delegates here, and the
# base/052 picker reaches the same menu through its USE handler, so the single
# USE button owns all sprite options on every fork copy.
#===============================================================================
class PokemonPokedexInfo_Scene
  def aigen_picker_fusion_ids
    return nil unless @species
    dexn = (getDexNumberForSpecies(@species) rescue nil)
    return nil unless dexn && dexn > NB_POKEMON
    body = (getBodyID(@species) rescue nil)
    return nil unless body
    head = (getHeadID(@species, body) rescue nil)
    return nil unless head
    [head, body]
  end

  def aigen_picker_triple_ids
    return nil unless @species
    dexn = (getDexNumberForSpecies(@species) rescue nil)
    return nil unless dexn && (isTripleFusion?(dexn) rescue false)
    AIGen.triple_components_from_path((kuray_global_triples(dexn) rescue nil))
  end

  def aigen_ensure_model
    if AIGen::Launcher.ensure_running(30)
      AIGen.log("ensure_model: sidecar reachable")
      return true
    end
    AIGen.log("ensure_model: sidecar NOT reachable (launchable?=#{(AIGen::Launcher.launchable? rescue '?')})")
    pbMessage(_INTL("The AI sprite model isn't running.\nStart the sidecar and try again."))
    false
  end

  def aigen_picker_refresh(select_path = nil)
    @available = pbGetAvailableForms
    @available = [] unless @available.is_a?(Array)
    idx = select_path ? @available.index(select_path) : nil
    @selected_index = idx if idx
    @selected_index = 0 if @selected_index.nil? || @selected_index >= @available.size
    update_displayed
  end

  def aigen_picker_share_discord
    return unless defined?(DiscordSpriteShare)
    DiscordSpriteShare.share_from_scene(self)
  rescue Exception => e
    AIGen.log("discord share error: #{e.message}")
    (pbMessage(_INTL("Couldn't share that sprite.")) rescue nil)
  end

  #---------------------------------------------------------------------------
  # The single combined sprite-options menu. Returns true if the picker should
  # close (the player applied a sprite via "Use this sprite"); false otherwise.
  # Invoked by the summary_sprite_tools mod's manage_selected_sprite (USE button)
  # and usable as a drop-in for the base picker's USE handler too.
  #---------------------------------------------------------------------------
  def pbSpriteOptionsMenu(brief = false)
    Input.update
    ai_on = (AIGen.enabled? rescue false)
    trip  = ai_on ? aigen_picker_triple_ids : nil
    ids   = (ai_on && !trip) ? aigen_picker_fusion_ids : nil
    sel   = (@available && @selected_index) ? @available[@selected_index] : nil
    sel_is_ai = (ai_on && sel && AIGen::Store.ai_path?(sel)) rescue false
    AIGen.log("sprite-options menu: species=#{(@species rescue nil).inspect} " \
              "fusion_ids=#{ids.inspect} triple=#{trip.inspect} sel_is_ai=#{sel_is_ai}") rescue nil

    cmds = []; acts = []
    cmds << _INTL("Use this sprite"); acts << :use
    if trip || ids
      cmds << _INTL("Generate New Sprite"); acts << :gen
      if sel_is_ai
        cmds << _INTL("Regenerate this AI sprite"); acts << :regen
        cmds << _INTL("Delete this AI sprite");     acts << :delai
      end
    end
    cmds << _INTL("Share this sprite to Discord"); acts << :discord
    if respond_to?(:selected_sprite_deletable?) && (selected_sprite_deletable? rescue false)
      cmds << _INTL("Delete sprite"); acts << :del
    end
    if respond_to?(:open_selected_sprite_directory)
      cmds << _INTL("Open sprite folder"); acts << :folder
    end
    cmds << _INTL("Cancel"); acts << :cancel

    choice = pbShowCommands(nil, cmds, -1)
    return false if choice < 0
    case acts[choice]
    when :use     then return (select_sprite(brief) if respond_to?(:select_sprite))
    when :gen     then trip ? aigen_picker_generate_flow_triple(trip) : aigen_picker_generate_flow(ids)
    when :regen   then trip ? aigen_picker_regen_triple(trip, sel)    : aigen_picker_regen(ids, sel)
    when :delai   then aigen_picker_delete(sel)
    when :discord then aigen_picker_share_discord
    when :del     then (delete_selected_sprite if respond_to?(:delete_selected_sprite))
    when :folder  then (open_selected_sprite_directory if respond_to?(:open_selected_sprite_directory))
    else
    end
    return false
  rescue Exception => e
    AIGen.log("pbSpriteOptionsMenu error: #{e.class}: #{e.message}\n#{(e.backtrace || [])[0, 8].join("\n")}") rescue nil
    (pbMessage(_INTL("Sprite action hit an error and was skipped.")) rescue nil)
    return false
  end

  #---------------------------------------------------------------------------
  # Single-fusion AI flows.
  #---------------------------------------------------------------------------
  def aigen_picker_generate_flow(ids)
    AIGen.log("=== Generate New Sprite chosen; ids=#{ids.inspect} ===")
    return unless ids
    head, body = ids
    return unless aigen_ensure_model
    path = AIGen.generate(head, body)
    unless path
      AIGen.log("generate_flow: AIGen.generate returned nil -> 'model returned nothing'")
      pbMessage(_INTL("Couldn't generate a sprite (the model returned nothing)."))
      return
    end
    aigen_picker_refresh(path)
    pbMessage(_INTL("Generated a new sprite with {1}!", AIGen::MODEL_NAME))
    aigen_post_generate_menu(path) { |letter| AIGen.regenerate(head, body, letter) }
  end

  def aigen_picker_regen(ids, sel)
    return unless ids && sel
    head, body = ids
    return unless aigen_ensure_model
    letter = AIGen::Store.letter_from_path(sel)
    path = AIGen.regenerate(head, body, letter)
    if path
      aigen_picker_refresh(path)
      pbMessage(_INTL("Regenerated the AI sprite!"))
    else
      pbMessage(_INTL("Couldn't regenerate (the model returned nothing)."))
    end
  end

  def aigen_picker_delete(sel)
    return unless sel
    if AIGen::Store.delete(sel)
      if defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.alt_sprite_substitutions
        $PokemonGlobal.alt_sprite_substitutions.delete_if { |_k, v| v == sel }
      end
      aigen_picker_refresh
      pbMessage(_INTL("Deleted the AI sprite."))
    else
      pbMessage(_INTL("Couldn't delete that sprite."))
    end
  end

  #---------------------------------------------------------------------------
  # Triple-fusion AI flows.
  #---------------------------------------------------------------------------
  def aigen_picker_generate_flow_triple(trip)
    return unless trip
    s1, s2, s3 = trip
    AIGen.log("=== Generate New Sprite chosen (triple); s=#{s1}.#{s2}.#{s3} ===")
    return unless aigen_ensure_model
    path = AIGen.generate_triple(s1, s2, s3)
    if path
      aigen_picker_refresh(path)
      pbMessage(_INTL("Generated a new sprite with {1}!", AIGen::MODEL_NAME))
      aigen_post_generate_menu(path) { |letter| AIGen.regenerate_triple(s1, s2, s3, letter) }
    else
      AIGen.log("triple generate_flow: generate_triple returned nil -> 'model returned nothing'")
      pbMessage(_INTL("Couldn't generate a triple sprite (the model returned nothing)."))
    end
  end

  def aigen_picker_regen_triple(trip, sel)
    return unless trip && sel
    s1, s2, s3 = trip
    return unless aigen_ensure_model
    letter = AIGen::Store.letter_from_path(sel)
    path = AIGen.regenerate_triple(s1, s2, s3, letter)
    if path
      aigen_picker_refresh(path)
      pbMessage(_INTL("Regenerated the AI sprite!"))
    else
      pbMessage(_INTL("Couldn't regenerate (the model returned nothing)."))
    end
  end

  # Apply `path` as this fusion's active main-sprite substitution (same effect
  # as confirming the sprite normally in the picker), pointing the picker at it.
  def aigen_picker_use_sprite(path)
    return unless path
    if @available.is_a?(Array)
      idx = @available.index(path)
      @selected_index = idx if idx
    end
    if respond_to?(:swap_main_sprite)
      swap_main_sprite
    else
      set_alt_sprite_substitution(dexNum(@species), path, @formIndex)
    end
    update_displayed if respond_to?(:update_displayed)
  rescue Exception => e
    AIGen.log("use_sprite error: #{e.class}: #{e.message}")
    (set_alt_sprite_substitution(dexNum(@species), path, @formIndex) rescue nil)
  end

  # Follow-up menu shown right after a fresh "Generate New Sprite". Lets the
  # player Keep Sprite (leave it saved + selected, not applied), Use Sprite
  # (apply it as this fusion's sprite now), Delete Sprite, or Retry (regenerate
  # the sprite IN PLACE with a fresh seed, then re-open this same menu). `path`
  # is the freshly generated sprite; the block takes the current slot letter and
  # returns the new path (or nil) -- single vs triple supply different regen calls.
  def aigen_post_generate_menu(path)
    loop do
      choice = pbMessage(_INTL("What would you like to do with this sprite?"),
        [_INTL("Keep Sprite"), _INTL("Use Sprite"), _INTL("Delete Sprite"), _INTL("Retry")], 1)
      case choice
      when 0   # Keep Sprite -- stays saved + selected in the picker, not applied
        pbMessage(_INTL("Kept the new sprite. You can pick it from the list anytime."))
        return
      when 1   # Use Sprite -- apply it as this fusion's active sprite now
        aigen_picker_use_sprite(path)
        pbMessage(_INTL("Now using the new sprite!"))
        return
      when 2   # Delete Sprite
        aigen_picker_delete(path)
        return
      when 3   # Retry -- regenerate in place (fresh seed), then re-open this menu
        return unless aigen_ensure_model
        letter = AIGen::Store.letter_from_path(path)
        newp = yield(letter)
        if newp
          path = newp
          aigen_picker_refresh(path)
          pbMessage(_INTL("Generated a new sprite with {1}!", AIGen::MODEL_NAME))
        else
          pbMessage(_INTL("Couldn't generate a new sprite (the model returned nothing)."))
        end
      else
        return
      end
    end
  end
end
