#===============================================================================
# Controller Vibration / Rumble  -  SETTINGS
#-------------------------------------------------------------------------------
# Adds a "Controller Vibration" page under  Options -> KIF Settings  with:
#   * Controller Vibration  (master On/Off)
#   * Vibration Intensity   (0..100 slider)
#   * Battle Vibration      (On/Off)
#   * Overworld Vibration   (On/Off)  - steps / running
#   * Encounter Vibration   (On/Off)  - wild / alpha / swarm / trainer / leader
#   * DualSense Lightbar    (On/Off)  - only does anything on a native DualSense
#   * Test Vibration        (button, also reports the detected controller)
# Stored on $PokemonSystem; old saves read nil and fall back to the defaults.
#===============================================================================
class PokemonSystem
  attr_accessor :rumble_master         # 0 = On, 1 = Off
  attr_accessor :rumble_intensity      # 0..100
  attr_accessor :rumble_cat_battle     # 0 = On, 1 = Off
  attr_accessor :rumble_cat_overworld  # 0 = On, 1 = Off
  attr_accessor :rumble_cat_encounters # 0 = On, 1 = Off
  attr_accessor :rumble_lightbar       # 0 = On, 1 = Off
  attr_accessor :speaker_master        # 0 = On, 1 = Off  (controller speaker)
  attr_accessor :speaker_volume        # 0..100

  unless method_defined?(:_rumble_orig_initialize)
    alias_method :_rumble_orig_initialize, :initialize
    def initialize
      _rumble_orig_initialize
      @rumble_master         = 0
      @rumble_intensity      = 70
      @rumble_cat_battle     = 0
      @rumble_cat_overworld  = 0
      @rumble_cat_encounters = 0
      @rumble_lightbar       = 0
      @speaker_master        = 0
      @speaker_volume        = 100
    end
  end
end

#-------------------------------------------------------------------------------
# Dedicated options sub-screen.
#-------------------------------------------------------------------------------
class RumbleOptionsScene < PokemonOption_Scene
  def getDefaultDescription
    return _INTL("Controller vibration & DualSense speaker output.")
  end

  def pbStartScene(inloadscreen = false)
    super
    @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Controller Vibration / Speaker"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["textbox"].text = getDefaultDescription
    pbFadeInAndShow(@sprites) { pbUpdate }
  end

  def rumble_detected_label
    return _INTL("Vibration unavailable on this system") unless defined?(Haptics)
    kind = (Haptics.controller_kind rescue :unknown)
    native = (Haptics.native_available? rescue false)
    names = {
      :dualsense => _INTL("DualSense"), :dualshock4 => _INTL("DualShock 4"),
      :xbox => _INTL("Xbox / XInput"), :switch => _INTL("Switch (native)"),
      :steamdeck => _INTL("Steam Deck (native)"), :steam => _INTL("Steam Controller"),
      :generic => _INTL("Generic gamepad"), :ps3 => _INTL("PS3"), :other => _INTL("Controller"),
      :xinput => _INTL("Xbox / XInput"), :unknown => _INTL("No controller detected")
    }
    if kind == :unknown
      d = (Haptics::HID.diagnostics rescue {})
      return d[:error] ? _INTL("No controller detected ({1})", d[:error].to_s) : _INTL("No controller detected")
    end
    base = names[kind] || _INTL("Controller")
    hid  = (Haptics.hid_direct? rescue false)
    conn = (Haptics.hid_connection rescue nil)
    if native
      return _INTL("Detected: {1} via Steam Input", base)
    elsif hid
      return _INTL("Detected: {1} via direct {2}", base, (conn == :bt ? _INTL("Bluetooth") : _INTL("USB")))
    else
      return _INTL("Detected: {1}", base)
    end
  end

  def pbGetOptions(inloadscreen = false)
    options = []
    options << EnumOption.new(_INTL("Controller Vibration"), [_INTL("On"), _INTL("Off")],
      proc { v = $PokemonSystem.rumble_master; v.nil? ? 0 : v },
      proc { |value|
        $PokemonSystem.rumble_master = value
        Haptics.stop if value != 0
      },
      _INTL("Master switch for all controller rumble.")
    )
    options << SliderOption.new(_INTL("Vibration Intensity"), 0, 100, 5,
      proc { v = $PokemonSystem.rumble_intensity; v.nil? ? 70 : v },
      proc { |value| $PokemonSystem.rumble_intensity = value },
      _INTL("How strong the rumble motors are driven (0-100%).")
    )
    options << EnumOption.new(_INTL("Battle Vibration"), [_INTL("On"), _INTL("Off")],
      proc { v = $PokemonSystem.rumble_cat_battle; v.nil? ? 0 : v },
      proc { |value| $PokemonSystem.rumble_cat_battle = value },
      _INTL("Rumble when your Pokemon use moves or get hit (varies by type).")
    )
    options << EnumOption.new(_INTL("Overworld Vibration"), [_INTL("On"), _INTL("Off")],
      proc { v = $PokemonSystem.rumble_cat_overworld; v.nil? ? 0 : v },
      proc { |value| $PokemonSystem.rumble_cat_overworld = value },
      _INTL("Gentle step pulses while walking, quicker pulses while running.")
    )
    options << EnumOption.new(_INTL("Encounter Vibration"), [_INTL("On"), _INTL("Off")],
      proc { v = $PokemonSystem.rumble_cat_encounters; v.nil? ? 0 : v },
      proc { |value| $PokemonSystem.rumble_cat_encounters = value },
      _INTL("Distinct cues for wild, alpha, swarm, trainer and gym-leader battles.")
    )
    options << EnumOption.new(_INTL("DualSense Lightbar"), [_INTL("On"), _INTL("Off")],
      proc { v = $PokemonSystem.rumble_lightbar; v.nil? ? 0 : v },
      proc { |value| $PokemonSystem.rumble_lightbar = value; Haptics.led_reset if value != 0 },
      _INTL("Tint the DualSense lightbar by move type / battle (native DualSense only).")
    )
    options << EnumOption.new(_INTL("Controller Speaker"), [_INTL("On"), _INTL("Off")],
      proc { v = $PokemonSystem.speaker_master; v.nil? ? 0 : v },
      proc { |value| $PokemonSystem.speaker_master = value },
      _INTL("Play Pokemon cries and Pokedex voice-over through the DualSense's built-in speaker when you are not on headphones (USB connection only).")
    )
    options << SliderOption.new(_INTL("Speaker Volume"), 0, 100, 5,
      proc { v = $PokemonSystem.speaker_volume; v.nil? ? 100 : v },
      proc { |value| $PokemonSystem.speaker_volume = value },
      _INTL("Loudness of cries / voice-over sent to the controller speaker.")
    )
    options << ButtonOption.new(_INTL("Test Controller Speaker"),
      proc {
        begin
          msg = (defined?(ControllerSpeaker) ? ControllerSpeaker.test : _INTL("Controller speaker support is unavailable."))
          pbMessage(msg) if defined?(pbMessage)
        rescue
        end
      },
      _INTL("Check detection and play a test cry through the controller speaker."),
      _INTL("Test")
    )
    options << ButtonOption.new(_INTL("Test Vibration"),
      proc {
        (Haptics::HID.test_probe! rescue nil)   # force a fresh raw-HID probe + log line each press
        Haptics.test
        begin
          pbMessage(_INTL("Testing vibration...\n{1}.", rumble_detected_label)) if defined?(pbMessage)
        rescue
        end
      },
      _INTL("Play a short test pattern and show the detected controller."),
      _INTL("Test")
    )
    return options
  end
end

#-------------------------------------------------------------------------------
# Add the entry to  Options -> KIF Settings.
#-------------------------------------------------------------------------------
if defined?(KurayOptionsScene)
  class KurayOptionsScene
    unless method_defined?(:_rumble_orig_pbGetOptions)
      alias_method :_rumble_orig_pbGetOptions, :pbGetOptions
      def pbGetOptions(inloadscreen = false)
        options = _rumble_orig_pbGetOptions(inloadscreen)
        begin
          btn = ButtonOption.new(_INTL("Controller Vibration / Speaker"),
            proc {
              pbFadeOutIn {
                scene  = RumbleOptionsScene.new
                screen = PokemonOptionScreen.new(scene)
                screen.pbStartScreen
              }
            },
            _INTL("Rumble feedback plus DualSense speaker output for cries."),
            _INTL("Open"))
          idx = options.index { |o| o.respond_to?(:name) && o.name == _INTL("Others") }
          idx ? options.insert(idx + 1, btn) : options << btn
        rescue
        end
        return options
      end
    end
  end
end
