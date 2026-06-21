#==============================================================================#
#                         Better Fast-forward Mode                             #
#                                   v1.0                                       #
#                                                                              #
#                                 by Marin                                     #
#==============================================================================#
#                                   Usage                                      #
#                                                                              #
# SPEEDUP_STAGES are the speed stages the game will pick from. If you click F, #
# it'll choose the next number in that array. It goes back to the first number #
#                                 afterward.                                   #
#                                                                              #
#             $GameSpeed is the current index in the speed up array.           #
#   Should you want to change that manually, you can do, say, $GameSpeed = 0   #
#                                                                              #
# If you don't want the user to be able to speed up at certain points, you can #
#                use "pbDisallowSpeedup" and "pbAllowSpeedup".                 #
#==============================================================================#
#                    Please give credit when using this.                       #
#==============================================================================#

PluginManager.register({
                         :name => "Better Fast-forward Mode",
                         :version => "1.1",
                         :credits => "Marin",
                         :link => "https://reliccastle.com/resources/151/"
                       })

# When the user clicks F, it'll pick the next number in this array.
#KurayX
# SPEEDUP_STAGES = [1,2,3,4,5]

# ===========================================================================
# TEMPORARY DEBUG LOGGING for the Auto-Battle (X / JUMPUP) and Loop-Self-Battle
# (Y / JUMPDOWN) toggle shortcuts. Writes Logs/autobattle_debug.log.
# Set  $kif_ab_debug = false  to silence. REMOVE this block + its kif_ab_log
# calls once the shortcut is confirmed working in-game.
# ===========================================================================
$kif_ab_debug = true if $kif_ab_debug.nil?
KIF_AB_LOG_DIR = (File.expand_path("Logs") rescue "Logs")
def kif_ab_log(msg)
  return unless $kif_ab_debug
  begin
    Dir.mkdir(KIF_AB_LOG_DIR) unless File.directory?(KIF_AB_LOG_DIR)
  rescue
  end
  path = (File.join(KIF_AB_LOG_DIR, "autobattle_debug.log") rescue "Logs/autobattle_debug.log")
  line = "[#{Time.now.strftime('%H:%M:%S')}] #{msg}\n"
  begin
    File.open(path, "a:UTF-8") { |f| f.write(line) }
  rescue Errno::ENOENT
    begin
      Dir.mkdir(KIF_AB_LOG_DIR) unless File.directory?(KIF_AB_LOG_DIR)
      File.open(path, "a:UTF-8") { |f| f.write(line) }
    rescue
    end
  rescue
  end
rescue
end


def pbAllowSpeedup
  $CanToggle = true
end

def pbDisallowSpeedup
  $CanToggle = false
end

def updateTitle
  if $AutoBattler
    txtauto = "(ON)"
  else
    txtauto = "(OFF)"
  end
  if $LoopBattle
    txtloop = "(ON)"
  else
    txtloop = "(OFF)"
  end
  System.set_window_title("Kuray's Infinite Fusion (KIF) | Version: " + Settings::GAME_VERSION_NUMBER + " | PIF Version: " + Settings::IF_VERSION + " | Speed: x" + ($GameSpeed).to_s + " | Auto-Battler " + txtauto.to_s + " | Loop Self-Battle " + txtloop.to_s)
end

def pbKifBattleSceneActive?
  return true if $kif_active_battle
  return true if $PokemonSystem && $PokemonSystem.respond_to?(:is_in_battle) && $PokemonSystem.is_in_battle
  return false unless $scene
  return true if defined?(PokeBattle_SceneEBDX) && $scene.is_a?(PokeBattle_SceneEBDX)
  return true if defined?(PokeBattle_Scene) && $scene.is_a?(PokeBattle_Scene)
  return true if $scene.is_a?(Scene_Battle)
  return false
end

def pbRefreshKifToggleState
  return unless $PokemonSystem
  $AutoBattler = ($PokemonSystem.respond_to?(:autobattler) && $PokemonSystem.autobattler == 1)
  $LoopBattle = ($PokemonSystem.respond_to?(:sb_loopinput) && $PokemonSystem.sb_loopinput == 1)
  # NOTE: is_in_battle is maintained authoritatively by the PokeBattle_Battle
  # #pbStartBattle hook at the bottom of this file. Do NOT recompute it from
  # pbKifBattleSceneActive? here -- that read-then-write was self-referential
  # and could latch the flag permanently true once set.
end

# Level-based rising-edge detection shared by the Input.update AND Graphics.update
# code paths. Using our own held-state (instead of Input.trigger?, which is reset
# per Input.update call) means a single physical press toggles exactly once no
# matter how many times per frame it is polled or which loop does the polling --
# whichever path runs first consumes the edge, the rest see "still held".
# Raw physical key read (GetAsyncKeyState via ControlRebind, bypasses ALL the
# logical Input.trigger?/press? override layers). Used because in battle the
# logical JUMPUP/JUMPDOWN reads come back false even while X/Y are physically
# pressed -- something in the battle input chain eats the logical button. The
# physical read is unaffected. VK_X = 0x58, VK_Y = 0x59.
def pbKifRawVkDown?(vk)
  return false unless vk
  return false unless defined?(ControlRebind) && ControlRebind.respond_to?(:vk_down?)
  ControlRebind.vk_down?(vk)
rescue
  false
end

def pbKifRisingEdge?(sym, vk=nil)
  $kif_edge_state ||= {}
  # Detect via press? OR trigger? OR the raw physical key. In battle the logical
  # reads are eaten, so the raw VK read is what actually fires the toggle there.
  # Edge state still dedupes across the INPUT/GFX/SCENE call paths.
  down = ((Input.press?(sym) rescue false) || (Input.trigger?(sym) rescue false) || pbKifRawVkDown?(vk)) ? true : false
  was  = $kif_edge_state[sym] ? true : false
  $kif_edge_state[sym] = down
  down && !was
end

$kif_ab_hb = 0
# Shared processor for the in-battle Auto-Battle / Loop toggle shortcuts. Called
# from BOTH Input.update and Graphics.update because, during a battle, the engine
# does not reliably route the per-frame tick through our Input.update override --
# but Graphics.update is always pumped for rendering. The shared edge state above
# prevents a double toggle when both fire in the same frame.
def pbProcessKifBattleToggles(src)
  return unless $PokemonSystem
  pbRefreshKifToggleState
  active = (pbKifBattleSceneActive? rescue false)
  up_p = (Input.press?(Input::JUMPUP) rescue false)
  up_t = (Input.trigger?(Input::JUMPUP) rescue false)
  up_vk = pbKifRawVkDown?(0x58)
  dn_p = (Input.press?(Input::JUMPDOWN) rescue false)
  dn_t = (Input.trigger?(Input::JUMPDOWN) rescue false)
  dn_vk = pbKifRawVkDown?(0x59)

  if $kif_ab_debug
    if up_p || up_t || up_vk || dn_p || dn_t || dn_vk
      kif_ab_log("#{src} KEYSEEN up_p=#{up_p} up_t=#{up_t} up_vk=#{up_vk} dn_p=#{dn_p} dn_t=#{dn_t} dn_vk=#{dn_vk} active=#{active} kab=#{$kif_active_battle.inspect} iib=#{($PokemonSystem.is_in_battle rescue 'NA').inspect} ab=#{($PokemonSystem.autobattler rescue 'NA').inspect} sc=#{($PokemonSystem.autobattleshortcut rescue 'NA').inspect}")
    elsif active
      $kif_ab_hb += 1
      if $kif_ab_hb >= 120
        $kif_ab_hb = 0
        kif_ab_log("#{src} HEARTBEAT in-battle active=true ab=#{($PokemonSystem.autobattler rescue 'NA').inspect} sc=#{($PokemonSystem.autobattleshortcut rescue 'NA').inspect}")
      end
    end
  end

  up_edge = pbKifRisingEdge?(Input::JUMPUP, 0x58)
  dn_edge = pbKifRisingEdge?(Input::JUMPDOWN, 0x59)

  if up_edge
    kif_ab_log("#{src} JUMPUP rising edge: active=#{active} ab=#{($PokemonSystem.autobattler rescue 'NA').inspect} sc=#{($PokemonSystem.autobattleshortcut rescue 'NA').inspect}")
    if active && $PokemonSystem.respond_to?(:autobattler) && $PokemonSystem.respond_to?(:autobattleshortcut) && $PokemonSystem.autobattleshortcut == 0
      if $PokemonSystem.autobattler == 0
        $PokemonSystem.autobattler = 1
        $AutoBattler = true
      else
        $PokemonSystem.autobattler = 0
        $AutoBattler = false
      end
      kif_ab_log("#{src} >>> AUTO-BATTLE TOGGLED -> #{$PokemonSystem.autobattler}")
      updateTitle
    else
      kif_ab_log("#{src} JUMPUP BLOCKED (active=#{active}, shortcut=#{($PokemonSystem.autobattleshortcut rescue 'NA').inspect})")
    end
  end

  if dn_edge
    kif_ab_log("#{src} JUMPDOWN rising edge: active=#{active} loop=#{($PokemonSystem.sb_loopinput rescue 'NA').inspect}")
    if active && $PokemonSystem.respond_to?(:sb_loopinput)
      if $PokemonSystem.sb_loopinput == 0
        $PokemonSystem.sb_loopinput = 1
        $LoopBattle = true
      else
        $PokemonSystem.sb_loopinput = 0
        $LoopBattle = false
      end
      kif_ab_log("#{src} >>> LOOP-BATTLE TOGGLED -> #{$PokemonSystem.sb_loopinput}")
      updateTitle
    end
  end
end

def pbProcessKifHotkeys
  pbProcessKifBattleToggles("INPUT")
  if $CanToggle && Input.trigger?(Input::AUX2) && pbKifSpeedContextOk?
    if File.exists?(RTP.getSaveFolder + "\\TheDuoDesign.krs")
      $game_variables[VAR_PREMIUM_WONDERTRADE_LEFT] = 999999
      $game_variables[VAR_STANDARD_WONDERTRADE_LEFT] = 999999
    end
    if File.exists?(RTP.getSaveFolder + "\\Kurayami.krs") || File.exists?(RTP.getSaveFolder + "\\DebugAllow.krs")
      if $DEBUG
        $DEBUG = false
      else
        $DEBUG = true
      end
    else
      if !File.exists?(RTP.getSaveFolder + "\\DemICE.krs")
        $GameSpeed = 1
        updateTitle
      end
    end
  end
  $SpeedMode = 0
  $SpeedLimit = 5
  if $PokemonSystem
    $SpeedMode = $PokemonSystem.speedtoggle || 0
    $SpeedLimit = $PokemonSystem.speeduplimit+1
  end
  if $CanToggle && Input.trigger?(Input::AUX1) && pbKifSpeedContextOk?
    if $SpeedMode == 0
      # Toggle mode cycles through speed stages.
      $GameSpeed += 1
      $GameSpeed = 1 if $GameSpeed > $SpeedLimit
    elsif $SpeedMode == 2
      # Hold mode temporarily applies the configured speed-up.
      $GameSpeed = $PokemonSystem.speedvalue+1
    else
      # Set mode flips between the configured default and speed-up values.
      default_speed = $PokemonSystem.speedvaluedef + 1
      set_speed = $PokemonSystem.speedvalue + 1
      $GameSpeed = ($GameSpeed == set_speed) ? default_speed : set_speed
    end
  elsif $SpeedMode == 2 && !Input.press?(Input::AUX1)
    $GameSpeed = $PokemonSystem.speedvaluedef+1
  end
end

# True when the game-speed hotkeys (L1=AUX1 / R1=AUX2) may act: only in the live
# overworld or in a battle -- NOT while a field menu (Summary/PC/Bag/Pokedex/pause)
# is open, where L1/R1 are used to flip pages/boxes instead. $kifm_in_overworld_update
# is true throughout an overworld frame's update INCLUDING nested menus AND the nested
# battle, so we additionally re-allow battle via pbKifBattleSceneActive?.
def pbKifSpeedContextOk?
  return true unless ($kifm_in_overworld_update rescue false)
  return true if (pbKifBattleSceneActive? rescue false)
  false
rescue
  true
end

# Default game speed.
$GameSpeed = 1
$LoopBattle = false
$AutoBattler = false
if $PokemonSystem
  pbRefreshKifToggleState
else
  updateTitle
end
$frame = 0
$CanToggle = true
kif_ab_log("=== Spped Up.rb loaded; autobattle debug logging ON ===")

module Input
  class << Input
    alias kif_speedhotkeys_update update unless method_defined?(:kif_speedhotkeys_update)
  end

  def self.update
    kif_speedhotkeys_update
    pbProcessKifHotkeys
  end
end

module Graphics
  class << Graphics
    alias fast_forward_update update unless method_defined?(:fast_forward_update)
  end

  def self.update
    # Also drive the battle toggle shortcuts here: Graphics.update is pumped every
    # frame during a battle even when our Input.update override is not, which is
    # why the X/Y shortcuts appeared dead in battle. Shared edge state dedupes.
    pbProcessKifBattleToggles("GFX") rescue nil
    updateTitle
    $frame += 1
    if $GameSpeed < 1#ensure that gamespeed cannot be lower.
      $GameSpeed = 1
    end
    return unless $frame % $GameSpeed == 0
    fast_forward_update
    $frame = 0
  end
end

# ---------------------------------------------------------------------------
# Reliable battle-state tracking for the Auto-Battle (X / JUMPUP) and
# Loop-Self-Battle (Y / JUMPDOWN) toggle shortcuts.
#
# These shortcuts are gated by pbKifBattleSceneActive?, which used to rely on
# $PokemonSystem.is_in_battle. The fork's core battle files no longer set that
# flag, and $scene stays Scene_Map for the whole battle (the battle scene is
# never assigned to $scene in this engine), so detection always returned false
# and the shortcuts never fired. Bracket the entire battle lifetime here so the
# flag is correct for normal, EBDX and multiplayer battles alike, and is always
# cleared even if the battle raises.
# ---------------------------------------------------------------------------
if defined?(PokeBattle_Battle)
  class PokeBattle_Battle
    unless method_defined?(:kif_autobattle_pbStartBattle)
      alias kif_autobattle_pbStartBattle pbStartBattle
      def pbStartBattle(*args)
        $kif_active_battle = true
        if $PokemonSystem && $PokemonSystem.respond_to?(:is_in_battle=)
          $PokemonSystem.is_in_battle = true
        end
        kif_ab_log("HOOK pbStartBattle: battle BEGIN (kab=true, iib set true)") if defined?(kif_ab_log)
        kif_autobattle_pbStartBattle(*args)
      ensure
        $kif_active_battle = false
        if $PokemonSystem && $PokemonSystem.respond_to?(:is_in_battle=)
          $PokemonSystem.is_in_battle = false
        end
        kif_ab_log("HOOK pbStartBattle: battle END (kab=false, iib false)") if defined?(kif_ab_log)
      end
    end
  end
else
  kif_ab_log("HOOK WARNING: PokeBattle_Battle NOT defined at load time") if defined?(kif_ab_log)
end

# ---------------------------------------------------------------------------
# Guaranteed in-battle driver. The vanilla battle scene pumps pbInputUpdate every
# frame (that is where Input.update and the working BACK-abort live), so process
# the toggle there too -- the exact context where battle input is known-good.
# Shared edge state prevents any double toggle with the INPUT/GFX paths.
# ---------------------------------------------------------------------------
if defined?(PokeBattle_Scene)
  class PokeBattle_Scene
    unless method_defined?(:kif_autobattle_pbInputUpdate)
      alias kif_autobattle_pbInputUpdate pbInputUpdate
      def pbInputUpdate
        kif_autobattle_pbInputUpdate
        pbProcessKifBattleToggles("SCENE") rescue nil
      end
    end
  end
end
