#===============================================================================
#  EBDX Menu Option - Adds toggle to Multiplayer Options menu
#===============================================================================
#  Reopens MultiplayerOptScene to add "EBDX Battle Visuals" option.
#  This does NOT modify the original file.
#===============================================================================

if defined?(MultiplayerOptScene)
  class MultiplayerOptScene
    alias ebdx_original_pbGetOptions pbGetOptions unless method_defined?(:ebdx_original_pbGetOptions)
    def pbGetOptions(inloadscreen = false)
      options = ebdx_original_pbGetOptions(inloadscreen)

      # Add EBDX toggle option. Turning EBDX ON auto-disables GhostBattle
      # Classic+ visuals (mutually exclusive). The getter reads the EFFECTIVE
      # value, so while Ghost visuals are active this correctly shows "Off".
      options << EnumOption.new(_INTL("EBDX Visuals"),
        [_INTL("Off"), _INTL("On")],
        proc { $PokemonSystem.mp_ebdx_enabled || 0 },
        proc { |value|
          $PokemonSystem.mp_ebdx_enabled = value
          if value == 1 && $PokemonSystem.respond_to?(:mp_ghost_visuals_enabled=)
            $PokemonSystem.mp_ghost_visuals_enabled = 0
          end
        },
        ["Use standard KIF battle visuals",
         "Use Elite Battle DX enhanced visuals (local only)"]
      )

      # GhostBattle Classic+ visuals toggle -- only shown when that mod is
      # installed. Turning it ON auto-disables EBDX; turning BOTH off gives the
      # plain vanilla battle UI. All runtime (no restart / no uninstall needed).
      if defined?(GhostVisualsBridge) && GhostVisualsBridge.mod_present?
        options << EnumOption.new(_INTL("Ghost Battle Visuals"),
          [_INTL("Off"), _INTL("On")],
          proc { $PokemonSystem.mp_ghost_visuals_enabled || 0 },
          proc { |value|
            $PokemonSystem.mp_ghost_visuals_enabled = value
            if value == 1 && $PokemonSystem.respond_to?(:mp_ebdx_enabled=)
              $PokemonSystem.mp_ebdx_enabled = 0
            end
          },
          ["Use standard / EBDX battle visuals",
           "Use GhostBattle Classic+ battle visuals (turns EBDX off)"]
        )
      end

      return options
    end
  end
end
