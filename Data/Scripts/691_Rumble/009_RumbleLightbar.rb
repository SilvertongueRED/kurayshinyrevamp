#===============================================================================
# Controller Vibration / Rumble  -  DUALSENSE LIGHTBAR ENGINE  + delayed cues
#-------------------------------------------------------------------------------
# Adds a stateful lightbar manager on top of the native Steam Input LED primitive
# (Haptics.led, 006). The DualSense lightbar is a SINGLE RGB zone (hardware: it
# cannot show two colours at once), so "two Pokemon = two halves" is approximated
# by following whichever battler you are CURRENTLY choosing a command/move for
# (grass mon -> green, then water mon -> blue), per the design.
#
# Behaviour:
#   * NEUTRAL base = the active battler's primary-type colour. While choosing a
#     command for a given battler the base switches to that battler's type.
#   * TAKE DAMAGE  -> brief RED flash, then back to the type base.
#   * FAINT        -> solid RED, held until the next prompt/action (command menu,
#                     send-out, or battle end) clears it.
#   * HEAL / healed-> brief GREEN flash + a soft "pulse" vibration during it.
#   * LOW HP (<=25%)-> slow RED glow fading in/out + a weak pulsing vibration.
#   * OVERWORLD MENU-> lightbar = the first party member's type colour.
#
# Everything is gated to (native Steam Input) + DualSense + the lightbar option,
# so non-DualSense / non-native setups are completely unaffected.
#
# Also hosts the small DELAYED-CUE queue used to time the pokeball-open rumble to
# the ball actually bursting open (~0.8s after the throw), one cue per ball.
#===============================================================================

module Haptics
  class << self
    # --- delayed rumble cues (frame-pumped) ---------------------------------
    def play_delayed(pattern, delay_ms, category = nil, priority = 2)
      return unless master_on?
      return if category && !category_on?(category)
      return if pattern.nil? || pattern.empty?
      @delayed_cues ||= []
      @delayed_cues << [now_ms + delay_ms.to_f, pattern, category, priority]
    end

    def pump_delayed
      return unless @delayed_cues && !@delayed_cues.empty?
      t = now_ms
      due = @delayed_cues.select { |e| t >= e[0] }
      return if due.empty?
      @delayed_cues.reject! { |e| t >= e[0] }
      due.each { |e| (play(e[1], e[2], e[3]) rescue nil) }
    end

    # native Steam-Input DualSense with the lightbar option enabled?
    def lightbar_active?
      (native_available? rescue false) && (dualsense? rescue false) && (lightbar_on? rescue false)
    end
  end

  # The old fire-and-forget LED helpers (006) are superseded by the stateful
  # Lightbar manager below; neutralise them so move-type / encounter-cue colours
  # never fight the base/flash model.
  def self.led_for_type(_type); end
  def self.led_for_cue(_kind);  end

  #---------------------------------------------------------------------------
  module Lightbar
    NEUTRAL = [40, 40, 52]
    RED     = [225, 0, 0]
    GREEN   = [40, 215, 60]

    @base        = nil
    @special     = nil      # :faint
    @flash_rgb   = nil
    @flash_until = 0.0
    @lowhp       = false
    @lowhp_next  = 0.0
    @lowhp_check = 0.0
    @battle      = nil
    @in_battle   = false
    @ow_rgb      = nil
    @applied     = nil
    @last_led    = 0.0

    class << self
      def now_ms; Time.now.to_f * 1000.0; end

      def type_color(type)
        key = type
        key = type.id   if type.respond_to?(:id)
        key = key.to_sym if key.respond_to?(:to_sym)
        (defined?(Haptics::TYPE_LED) ? Haptics::TYPE_LED[key] : nil) || [120, 120, 130]
      end

      def battler_type(b)
        return :NORMAL unless b
        t = nil
        tp = (b.pbTypes(false) rescue nil)
        t = tp[0] if tp.is_a?(Array) && !tp.empty?
        t ||= (b.type1 rescue nil)
        t ||= (b.pokemon.type1 rescue nil)
        t || :NORMAL
      end

      # ---- battle / context events ----
      def on_battle_begin(battle)
        @battle = battle; @in_battle = true
        @special = nil; @flash_rgb = nil; @lowhp = false
        @base = first_player_type_color
        @applied = nil
      end

      def on_battle_end
        @in_battle = false; @battle = nil
        @special = nil; @flash_rgb = nil; @lowhp = false; @base = nil
        (Haptics.led_reset rescue nil); @applied = :reset
      end

      def set_active_battler(b)
        return unless b
        @base = type_color(battler_type(b))
        @special = nil if @special == :faint   # a living mon is choosing -> clear faint hold
      end

      def refresh_base
        @base = first_player_type_color if @in_battle
      end

      def on_faint(_b = nil); @special = :faint; end
      def clear_faint;        @special = nil if @special == :faint; end

      def flash_damage
        @flash_rgb = RED; @flash_until = now_ms + 260
        clear_faint
      end

      def flash_heal
        @flash_rgb = GREEN; @flash_until = now_ms + 430
      end

      def enter_overworld_menu; @ow_rgb = first_party_type_color; @applied = nil; end
      def exit_overworld_menu;  @ow_rgb = nil; (Haptics.led_reset rescue nil); @applied = :reset; end

      def first_player_active
        return nil unless @battle
        bs = (@battle.battlers rescue nil)
        return nil unless bs
        bs.each do |b|
          next unless b
          next unless (b.pbOwnedByPlayer? rescue false)
          next if (b.fainted? rescue true)
          return b
        end
        nil
      end

      def first_player_type_color
        b = first_player_active
        b ? type_color(battler_type(b)) : NEUTRAL
      end

      def first_party_type_color
        party = ($Trainer.party rescue nil)
        return NEUTRAL unless party.is_a?(Array) && party[0]
        type_color((party[0].type1 rescue :NORMAL))
      end

      # ---- per-frame ----
      def tick
        return unless (Haptics.lightbar_active? rescue false)
        now = now_ms
        update_lowhp(now) if @in_battle
        rgb = compute(now)
        apply(rgb, now) unless rgb.nil?
        if @in_battle && @lowhp && (@flash_rgb.nil? || now >= @flash_until) && now >= @lowhp_next
          @lowhp_next = now + 1300
          (Haptics.play(Haptics::Patterns.low_hp_pulse, :battle, 1) rescue nil)
        end
      end

      def compute(now)
        return @flash_rgb if @flash_rgb && now < @flash_until
        if @in_battle
          return RED if @special == :faint
          if @lowhp
            ph = (Math.sin(now / 520.0) * 0.5 + 0.5)   # slow 0..1
            v  = (30 + ph * 200).to_i
            return [v, 0, 0]
          end
          return @base || NEUTRAL
        else
          return @ow_rgb   # nil unless an overworld menu is open
        end
      end

      def update_lowhp(now)
        return if now < @lowhp_check
        @lowhp_check = now + 250
        low = false
        bs = (@battle ? (@battle.battlers rescue nil) : nil)
        if bs
          bs.each do |x|
            next unless x && (x.pbOwnedByPlayer? rescue false)
            next if (x.fainted? rescue true)
            hp = (x.hp rescue 0); thp = (x.totalhp rescue 0)
            if thp > 0 && hp > 0 && hp <= (thp / 4.0)
              low = true; break
            end
          end
        end
        @lowhp = low
      end

      def apply(rgb, now)
        return if rgb.nil?
        key = [clamp(rgb[0]), clamp(rgb[1]), clamp(rgb[2])]
        return if @applied == key
        return if (now - @last_led) < 30           # cap LED writes ~33/s for smooth glow
        @applied = key; @last_led = now
        (Haptics.led(key[0], key[1], key[2]) rescue nil)
      end

      def clamp(x); x = x.to_i; x = 0 if x < 0; x = 255 if x > 255; x; end
    end
  end
end

#-------------------------------------------------------------------------------
# Per-frame pump: delayed cues + lightbar state. Independent Graphics.update
# wrapper so it runs every frame regardless of the rumble tick override chain.
#-------------------------------------------------------------------------------
module Graphics
  class << self
    unless respond_to?(:_lb_orig_update)
      alias_method :_lb_orig_update, :update
      def update(*a, &b)
        _lb_orig_update(*a, &b)
        (Haptics.pump_delayed rescue nil)
        (Haptics::Lightbar.tick rescue nil)
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Battle begin / end -> set + clear the lightbar context.
#-------------------------------------------------------------------------------
if defined?(Haptics::Encounter)
  module Haptics
    module Encounter
      class << self
        unless method_defined?(:_lb_on_battle_start) || private_method_defined?(:_lb_on_battle_start)
          alias_method :_lb_on_battle_start, :on_battle_start
          def on_battle_start(battle)
            _lb_on_battle_start(battle)
            (Haptics::Lightbar.on_battle_begin(battle) rescue nil)
          end
        end
      end
    end
  end
end

if defined?(Haptics::Battle)
  module Haptics
    module Battle
      class << self
        unless method_defined?(:_lb_on_send_out) || private_method_defined?(:_lb_on_send_out)
          alias_method :_lb_on_send_out, :on_send_out
          def on_send_out(scene, send_outs)
            _lb_on_send_out(scene, send_outs)
            (Haptics::Lightbar.clear_faint rescue nil)
            (Haptics::Lightbar.refresh_base rescue nil)
          end
        end
      end
    end
  end
end

# NOTE: the battle-end reset is hung off pbStartBattle (which brackets the WHOLE
# battle on PokeBattle_Battle) via an ensure, NOT pbEndBattle (that is a SCENE
# method, absent on the battle class) nor pbEndOfBattle (coop/NPT redefine it
# after 691, which would drop the alias). This is name-agnostic and always fires.
if defined?(PokeBattle_Battle) && PokeBattle_Battle.method_defined?(:pbStartBattle)
  class PokeBattle_Battle
    unless method_defined?(:_lb_orig_pbStartBattle)
      alias_method :_lb_orig_pbStartBattle, :pbStartBattle
      def pbStartBattle(*a, &b)
        begin
          _lb_orig_pbStartBattle(*a, &b)
        ensure
          (Haptics::Lightbar.on_battle_end rescue nil)
        end
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Scene hooks (base + EBDX). pbHPChanged drives damage(red)/heal(green+pulse),
# pbFaintBattler drives the solid-red hold, pbCommandMenu sets the active-battler
# base colour. Only wrap the class that actually OWNS each method so an inherited
# definition is never double-wrapped.
#-------------------------------------------------------------------------------
_lb_scene_classes = []
_lb_scene_classes << PokeBattle_Scene     if defined?(PokeBattle_Scene)
_lb_scene_classes << PokeBattle_SceneEBDX if defined?(PokeBattle_SceneEBDX)

_lb_scene_classes.each do |klass|
  klass.class_eval do
    owns = lambda do |name|
      method_defined?(name) && (instance_method(name).owner == self)
    end

    if owns.call(:pbHPChanged) && !method_defined?(:_lb_orig_pbHPChanged)
      alias_method :_lb_orig_pbHPChanged, :pbHPChanged
      def pbHPChanged(battler, oldHP, showAnim = false, *extra, &blk)
        begin
          if battler && (battler.pbOwnedByPlayer? rescue false)
            if battler.hp < oldHP
              Haptics::Lightbar.flash_damage
            elsif battler.hp > oldHP
              Haptics::Lightbar.flash_heal
              Haptics.play(Haptics::Patterns.heal_pulse, :battle, 2) if Haptics.category_on?(:battle)
            end
          end
        rescue
        end
        _lb_orig_pbHPChanged(battler, oldHP, showAnim, *extra, &blk)
      end
    end

    if owns.call(:pbFaintBattler) && !method_defined?(:_lb_orig_pbFaintBattler)
      alias_method :_lb_orig_pbFaintBattler, :pbFaintBattler
      def pbFaintBattler(battler, *extra, &blk)
        (Haptics::Lightbar.on_faint(battler) rescue nil) if battler && (battler.pbOwnedByPlayer? rescue false)
        _lb_orig_pbFaintBattler(battler, *extra, &blk)
      end
    end

    if owns.call(:pbCommandMenu) && !method_defined?(:_lb_orig_pbCommandMenu)
      alias_method :_lb_orig_pbCommandMenu, :pbCommandMenu
      def pbCommandMenu(idxBattler, *extra, &blk)
        begin
          b = (@battle.battlers[idxBattler] rescue nil)
          Haptics::Lightbar.set_active_battler(b) if b
        rescue
        end
        _lb_orig_pbCommandMenu(idxBattler, *extra, &blk)
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Overworld pause menu -> lightbar shows the lead party member's type colour.
#-------------------------------------------------------------------------------
if defined?(PokemonPauseMenu)
  class PokemonPauseMenu
    if method_defined?(:pbStartPokemonMenu) && !method_defined?(:_lb_orig_pbStartPokemonMenu)
      alias_method :_lb_orig_pbStartPokemonMenu, :pbStartPokemonMenu
      def pbStartPokemonMenu(*a, &b)
        (Haptics::Lightbar.enter_overworld_menu rescue nil)
        begin
          _lb_orig_pbStartPokemonMenu(*a, &b)
        ensure
          (Haptics::Lightbar.exit_overworld_menu rescue nil)
        end
      end
    end
  end
end
