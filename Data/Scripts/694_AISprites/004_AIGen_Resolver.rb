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

  # Parse [s1, s2, s3] (strings) from a special-sprite path like
  # ".../special/144.145.146" (with or without a trailing alt letter / .png).
  # Returns nil if it is not a triple-component path (e.g. "special/000",
  # "invisible", "cardboard").
  def self.triple_components_from_path(path)
    return nil unless path
    base = File.basename(path.to_s.sub(/\.png\z/i, ""))
    m = base.match(/\A(\d+)\.(\d+)\.(\d+)[a-z]?\z/i)
    m ? [m[1], m[2], m[3]] : nil
  end
end

# Hook the triple-fusion sprite resolver. The game maps a triple's dex number to
# a hand-made "Graphics/Battlers/special/<s1>.<s2>.<s3>" path via the top-level
# (Object-private) kuray_global_triples. When NO premade sprite exists there
# (most chosen triples), supersede the placeholder with an AI-generated triple if
# one is on disk. Fully inert until AI triple files exist.
class Object
  unless method_defined?(:aigen_orig_kuray_global_triples) ||
         private_method_defined?(:aigen_orig_kuray_global_triples)
    if method_defined?(:kuray_global_triples) || private_method_defined?(:kuray_global_triples)
      alias_method :aigen_orig_kuray_global_triples, :kuray_global_triples

      def kuray_global_triples(dexNum)
        original = aigen_orig_kuray_global_triples(dexNum)
        return original unless AIGen.enabled?
        # Only step in when the premade special sprite does NOT resolve.
        return original if (pbResolveBitmap(original) rescue nil)
        comps = AIGen.triple_components_from_path(original)
        return original unless comps
        ai = (AIGen::Store.triple_main_sprite_path(*comps) rescue nil)
        ai ? ai : original
      rescue Exception
        (begin; aigen_orig_kuray_global_triples(dexNum); rescue Exception; nil; end)
      end
    end
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
