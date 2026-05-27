# frozen_string_literal: true

module GBAPlayer
  module PokegearMobile
    module_function

    def phone_available?
      return false unless defined?($PokemonGlobal) && $PokemonGlobal
      numbers = $PokemonGlobal.phoneNumbers
      return false unless numbers
      numbers.any? { |num| num.is_a?(Array) ? num[0] : num }
    rescue
      false
    end

    def rematches_available?
      defined?(TravelExpansionFramework) &&
        TravelExpansionFramework.respond_to?(:phone_rematch_menu_available?) &&
        TravelExpansionFramework.phone_rematch_menu_available?
    rescue
      false
    end

    def tutor_net_available?
      defined?(PokemonTutorNet_Scene) && defined?(PokemonTutorNetScreen)
    end

    def build_commands
      commands = []
      indices = {}
      indices[:map] = commands.length
      commands << ["map", _INTL("Map")]
      if phone_available?
        indices[:phone] = commands.length
        commands << ["phone", _INTL("Phone")]
      end
      if rematches_available?
        indices[:rematches] = commands.length
        commands << ["phone", _INTL("Rematches")]
      end
      indices[:gba] = commands.length
      commands << ["phone", _INTL("GBA Player")]
      indices[:jukebox] = commands.length
      commands << ["jukebox", _INTL("Jukebox")]
      if tutor_net_available?
        indices[:tutornet] = commands.length
        commands << ["tutornet", _INTL("Tutor.net")]
      end
      [commands, indices]
    end

    def handle_command(cmd, indices)
      if indices[:map] == cmd
        pbShowMap(-1, false)
      elsif indices[:phone] == cmd
        pbFadeOutIn { PokemonPhoneScene.new.start }
      elsif indices[:rematches] == cmd
        pbFadeOutIn { PokemonPhoneRematchScene.new.start }
      elsif indices[:gba] == cmd
        pbFadeOutIn { GBAPlayer.open_mobile_menu }
        if defined?(GBAPlayer::WalkalongOverlay) && GBAPlayer::WalkalongOverlay.active?
          return :close_pokegear
        end
      elsif indices[:jukebox] == cmd
        pbFadeOutIn {
          scene = PokemonJukebox_Scene.new
          screen = PokemonJukeboxScreen.new(scene)
          screen.pbStartScreen
        }
      elsif indices[:tutornet] == cmd
        pbFadeOutIn {
          scene = PokemonTutorNet_Scene.new
          screen = PokemonTutorNetScreen.new(scene)
          screen.pbStartScreen
        }
      end
    end
  end
end

if defined?(PokemonPokegearScreen)
  class PokemonPokegearScreen
    alias gba_player_original_pbStartScreen pbStartScreen unless method_defined?(:gba_player_original_pbStartScreen)

    def pbStartScreen(*_args)
      if defined?(TravelExpansionFramework) &&
         TravelExpansionFramework.respond_to?(:quick_phone_rematch_pokegear_access!)
        TravelExpansionFramework.quick_phone_rematch_pokegear_access!
      end
      commands, indices = GBAPlayer::PokegearMobile.build_commands
      @scene.pbStartScene(commands)
      loop do
        cmd = @scene.pbScene
        break if cmd < 0
        result = GBAPlayer::PokegearMobile.handle_command(cmd, indices)
        break if result == :close_pokegear
      end
      @scene.pbEndScene
    end
  end
end
