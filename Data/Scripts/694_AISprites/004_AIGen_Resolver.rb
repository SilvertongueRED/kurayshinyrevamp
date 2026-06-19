#===============================================================================
# 694_AISprites - 004_AIGen_Resolver.rb
# Hook the fusion sprite resolver so AI sprites supersede Japeal autogen, while
# human customs and explicit user choices still win. Fully inert until AI files
# exist: with none on disk, this always returns the original result.
#===============================================================================
module AIGen
  # True if the player explicitly picked a sprite for this fusion (any source);
  # we must respect that choice and not override it.
  def self.user_substitution_active?(head_id, body_id, spriteform_body = nil, spriteform_head = nil)
    return false unless defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.alt_sprite_substitutions
    dex = (getSpeciesIdForFusion(head_id, body_id) rescue nil)
    return false unless dex
    fs = ""
    fs += "_#{spriteform_body}" if spriteform_body
    fs += "_#{spriteform_head}" if spriteform_head
    val = $PokemonGlobal.alt_sprite_substitutions[dex.to_s + fs]
    return false unless val
    !!((pbResolveBitmap(val) rescue nil))
  end
end

class Object
  unless method_defined?(:aigen_orig_get_fusion_sprite_path) ||
         private_method_defined?(:aigen_orig_get_fusion_sprite_path)
    alias_method :aigen_orig_get_fusion_sprite_path, :get_fusion_sprite_path
  end

  def get_fusion_sprite_path(head_id, body_id, spriteform_body = nil, spriteform_head = nil)
    original = aigen_orig_get_fusion_sprite_path(head_id, body_id, spriteform_body, spriteform_head)
    return original unless AIGen.enabled?
    return original unless body_id            # base/unfused sprites: leave alone
    # Respect an explicit user choice (custom, AI, or even Japeal on purpose).
    return original if AIGen.user_substitution_active?(head_id, body_id, spriteform_body, spriteform_head)
    # Human custom always beats AI.
    return original if original && original.include?(Settings::CUSTOM_BATTLERS_FOLDER)
    return original if AIGen::Store.human_custom?(head_id, body_id, spriteform_body, spriteform_head)
    # `original` is now Japeal autogen / local-generated / default placeholder.
    ai = AIGen::Store.main_sprite_path(head_id, body_id, spriteform_body, spriteform_head)
    return ai if ai
    original
  rescue
    # Never let the AI layer break sprite loading.
    aigen_orig_get_fusion_sprite_path(head_id, body_id, spriteform_body, spriteform_head)
  end
end
