#===============================================================================
# 694_AISprites - AI Fusion Sprite system (engine spine)
# 001_AIGen_Config.rb
#
# Goal: when no human-made custom sprite exists for a fusion, prefer a sprite
# made by our bundled on-device model over the low-quality Japeal autogen.
#
# Everything here is INERT until AI sprite files actually exist on disk (or the
# local model sidecar is running), so it is safe to ship before the model does.
#===============================================================================
module AIGen
  # Label shown as the "creator" in the Pokedex sprite picker.
  MODEL_NAME       = "KIF NeuralFusion"

  # Default on/off when a save has no preference yet.
  ENABLED_DEFAULT  = true

  #-- On-device generation sidecar -------------------------------------------
  # The bundled model runs as a local process that serves over localhost. The
  # engine talks to it with the same HTTPLite path used for autogen downloads.
  # If it is not running, all calls fail fast and no-op.
  BACKEND_HOST     = "127.0.0.1"
  BACKEND_PORT     = 8760
  HEALTH_PATH      = "/health"          # GET -> 200 when model is ready
  GENERATE_PATH    = "/generate"        # GET ?head=H&body=B[&seed=S] -> PNG bytes

  #-- Storage ----------------------------------------------------------------
  # Mirrors the indexed custom-battler layout but in its own root so AI sprites
  # are trivial to find, credit, and delete without touching human work.
  ROOT_FOLDER      = "Graphics/AIGenerated/"
  INDEXED_FOLDER   = "Graphics/AIGenerated/indexed/"

  # Alternate-sprite letters (same convention the game uses for customs).
  ALT_LETTERS      = ("a".."z").to_a

  # Master toggle. Reads the per-save setting if present, else the default.
  def self.enabled?
    return ENABLED_DEFAULT unless defined?($PokemonSystem) && $PokemonSystem
    return ENABLED_DEFAULT unless $PokemonSystem.respond_to?(:ai_sprites_enabled)
    val = $PokemonSystem.ai_sprites_enabled
    return ENABLED_DEFAULT if val.nil?
    val != 0 && val != false
  end

  def self.log(msg)
    begin
      echoln("[AIGen] #{msg}")
    rescue
      # echoln may be unavailable very early in boot; ignore.
    end
  end
end

# Per-save toggle storage (defaults to nil -> ENABLED_DEFAULT for old saves).
class PokemonSystem
  attr_accessor :ai_sprites_enabled
end
