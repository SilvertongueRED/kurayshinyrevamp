#===============================================================================
# options_to_json / options_load_json  (MISSING-METHOD FIX)
#
# These two helpers are referenced by:
#   * the options preset save/load feature  (016_UI/015_UI_Options.rb)
#   * the multiplayer "Sync ALL settings"   (659_Multiplayer/002_UI/010_MultiplayerOptions.rb)
# ...but they were never defined anywhere in the loaded scripts, so both
# features raised NoMethodError. "Sync ALL settings" silently sent an empty
# payload and then crashed the receiver; option presets failed to save/load.
#
# Implemented generically over $PokemonSystem's instance variables so they
# automatically cover every option, and stay cross-version safe:
#   - only JSON/eval-safe primitive values are serialized
#   - on load, only keys that already exist on the receiver are applied,
#     so extra fork-only options coming from a peer are harmlessly ignored.
#
# NOTE: network data always arrives here as an already-parsed Hash (via
# MiniJSON.parse), never as a String, so eval is only ever used on local,
# trusted .kro preset files.
#===============================================================================

def options_json_safe_value?(v)
  case v
  when Integer, Float, String, TrueClass, FalseClass, NilClass
    true
  when Array
    v.all? { |e| options_json_safe_value?(e) }
  when Hash
    v.all? { |k, val| (k.is_a?(String) || k.is_a?(Symbol) || k.is_a?(Integer)) && options_json_safe_value?(val) }
  else
    false
  end
end

# Returns a Hash (string keys) of all serializable $PokemonSystem option values.
def options_to_json
  return {} unless defined?($PokemonSystem) && $PokemonSystem
  result = {}
  $PokemonSystem.instance_variables.each do |ivar|
    value = $PokemonSystem.instance_variable_get(ivar)
    next unless options_json_safe_value?(value)
    result[ivar.to_s.delete_prefix("@")] = value
  end
  result
end

# Restores option values from a Hash (or an eval-able Hash string as stored in
# the .kro preset files). Only applies keys that already exist on $PokemonSystem.
def options_load_json(data)
  return unless defined?($PokemonSystem) && $PokemonSystem
  data = (eval(data) rescue nil) if data.is_a?(String)
  return unless data.is_a?(Hash)
  existing = $PokemonSystem.instance_variables
  data.each do |key, value|
    ivar = "@#{key}".to_sym
    next unless existing.include?(ivar)
    next unless options_json_safe_value?(value)
    $PokemonSystem.instance_variable_set(ivar, value)
  end
  $PokemonSystem
end
