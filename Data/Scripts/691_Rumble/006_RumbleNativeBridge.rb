#===============================================================================
# Controller Vibration / Rumble  -  NATIVE DUALSENSE BRIDGE (Steam Input)
#-------------------------------------------------------------------------------
# Additive layer. If the engine was built with the KIF Steam Input patch it
# exposes a `SteamHaptics` Ruby module (see (Source)/SteamInputPatch/). When that
# module is present AND Steam reports a live controller, rumble is routed through
# the Steamworks Steam Input API instead of XInput. That path:
#   * sees the REAL controller type even while Steam Input disguises it as Xbox,
#     so a DualSense is correctly detected as a DualSense (k_ESteamInputType=13);
#   * drives the two main motors PLUS the trigger motors (rumble_ex);
#   * can set the DualSense lightbar colour.
#
# If `SteamHaptics` is absent (stock exe) or unavailable, EVERYTHING falls back
# to the existing XInput backend unchanged - non-DualSense pads keep working
# exactly as before. This file is safe to ship before the engine is patched.
#===============================================================================
module Haptics
  # ESteamInputType -> our symbol
  SI_TYPE = {
    1 => :steam, 2 => :xbox, 3 => :xbox, 4 => :generic, 5 => :dualshock4,
    8 => :switch, 9 => :switch, 10 => :switch, 12 => :ps3,
    13 => :dualsense, 14 => :steamdeck
  }

  def self.native_available?
    return false unless defined?(SteamHaptics)
    v = (SteamHaptics.available? rescue false)
    return v ? true : false
  end

  # Real controller kind, even through Steam Input (native), else best XInput guess.
  def self.controller_kind
    if native_available?
      t = (SteamHaptics.controller_type rescue 0)
      return SI_TYPE[t] || (t == 0 ? :unknown : :other)
    end
    # ensure the XInput backend is probed so a connected pad is reported
    (ready? rescue nil)
    return :xinput if (@backend_ok && @pad_index)
    return :unknown
  end

  def self.dualsense?
    controller_kind == :dualsense
  end

  def self.lightbar_on?
    s = system
    return true unless s
    v = (s.rumble_lightbar rescue nil)
    return v.nil? ? true : (v == 0)
  end

  def self.clamp16(x)
    x = (x.respond_to?(:round) ? x.round : x.to_i)
    x = 0 if x < 0
    x = 65535 if x > 65535
    return x
  end

  # DualSense lightbar (no-op unless native + DualSense + lightbar enabled).
  def self.led(r, g, b)
    return unless native_available? && lightbar_on?
    return unless dualsense?
    SteamHaptics.led(r, g, b) rescue nil
  end

  def self.led_reset
    return unless native_available?
    SteamHaptics.led_reset rescue nil
  end
end

#-------------------------------------------------------------------------------
# Override the backend-facing primitives to prefer the native path.
#-------------------------------------------------------------------------------
module Haptics
  class << self
    unless method_defined?(:_native_orig_ready?) || private_method_defined?(:_native_orig_ready?)
      alias_method :_native_orig_ready?, :ready?
      def ready?
        return true if native_available?
        return _native_orig_ready?
      end
    end

    unless method_defined?(:_native_orig_set_motors) || private_method_defined?(:_native_orig_set_motors)
      alias_method :_native_orig_set_motors, :set_motors
      def set_motors(low01, high01)
        unless native_available?
          _native_orig_set_motors(low01, high01)
          return
        end
        # Native Steam Input is up (real controller TYPE is known, lightbar works),
        # but the actual motor RUMBLE must prefer the XInput virtual pad whenever one
        # is present. Under Steam Input's default gamepad template the controller is
        # exposed as a virtual XInput device and Steam forwards XInput rumble to the
        # physical DualSense, whereas ISteamInput TriggerVibration is a no-op in
        # gamepad-emulation mode (the shipped, non-recompiled exe). Routing rumble at
        # SteamHaptics only is exactly why it stopped vibrating the moment native
        # DETECTION started working - so drive the motors through XInput here.
        init_backend unless @init_done
        scan_pad(@pad_index.nil?) if @backend_ok
        if @backend_ok && !@pad_index.nil?
          @native_lo = nil          # XInput motor state is sticky -> no re-assert
          @native_hi = nil
          _native_orig_set_motors(low01, high01)
          return
        end
        # No XInput pad to drive (e.g. truly native build, pad seen only via Steam
        # Input): fall back to the Steamworks haptic API directly.
        scale = intensity.to_f / 100.0
        lo = clamp16(low01.to_f  * scale * 65535.0)
        hi = clamp16(high01.to_f * scale * 65535.0)
        @native_lo = lo
        @native_hi = hi
        if dualsense?
          trig = clamp16(hi * 0.55)
          (SteamHaptics.rumble_ex(lo, hi, trig, trig) rescue (SteamHaptics.rumble(lo, hi) rescue nil))
        else
          SteamHaptics.rumble(lo, hi) rescue nil
        end
      end
    end

    unless method_defined?(:_native_orig_tick) || private_method_defined?(:_native_orig_tick)
      alias_method :_native_orig_tick, :tick
      def tick
        if native_available?
          SteamHaptics.run_frame rescue nil    # keep handles / connection fresh
          if @active
            t = now_ms
            advance_step(t) if t >= @step_end
            # Re-assert each frame so a sustained step doesn't decay on the
            # Steam side (TriggerVibration is a momentary event).
            if @active && @native_lo
              trig = clamp16((@native_hi || 0) * 0.55)
              if dualsense? || controller_kind == :xbox
                (SteamHaptics.rumble_ex(@native_lo, @native_hi, trig, trig) rescue nil)
              else
                (SteamHaptics.rumble(@native_lo, @native_hi) rescue nil)
              end
            end
          end
        else
          _native_orig_tick
        end
      end
    end
  end
end

#-------------------------------------------------------------------------------
# Lightbar accents (DualSense only). Move type -> colour; battle kind -> colour.
#-------------------------------------------------------------------------------
module Haptics
  TYPE_LED = {
    :NORMAL=>[200,200,200], :FIRE=>[255,60,0],   :WATER=>[0,110,255],  :ELECTRIC=>[255,220,0],
    :GRASS=>[60,200,40],    :ICE=>[120,220,255],  :FIGHTING=>[200,40,40],:POISON=>[150,40,200],
    :GROUND=>[180,120,40],  :FLYING=>[150,200,255],:PSYCHIC=>[255,60,160],:BUG=>[150,200,30],
    :ROCK=>[170,140,80],    :GHOST=>[90,40,140],  :DRAGON=>[80,60,220],  :DARK=>[70,50,90],
    :STEEL=>[140,160,180],  :FAIRY=>[255,140,200]
  }
  CUE_LED = {
    :wild=>[0,180,40], :alpha=>[255,0,0], :swarm=>[150,0,200], :trainer=>[255,120,0], :gym_leader=>[255,200,0]
  }

  def self.led_for_type(type)
    key = type
    key = type.id if type.respond_to?(:id)
    key = key.to_sym if key.respond_to?(:to_sym)
    c = TYPE_LED[key]
    led(c[0], c[1], c[2]) if c
  end

  def self.led_for_cue(kind)
    c = CUE_LED[kind]
    led(c[0], c[1], c[2]) if c
  end
end

# Move-type lightbar: wrap the battle entry points (type is known there).
if defined?(Haptics::Battle)
  module Haptics
    module Battle
      class << self
        unless method_defined?(:_native_obm) || private_method_defined?(:_native_obm)
          alias_method :_native_obm, :on_move_animation
          def on_move_animation(battle, move, user, targets)
            _native_obm(battle, move, user, targets)
            if Haptics.category_on?(:battle) && (user && (user.pbOwnedByPlayer? rescue false))
              Haptics.led_for_type(move_type(move)) rescue nil
            end
          end
        end
        unless method_defined?(:_native_od) || private_method_defined?(:_native_od)
          alias_method :_native_od, :on_damage
          def on_damage(battler, eff = 0)
            _native_od(battler, eff)
            if Haptics.category_on?(:battle) && (battler && (battler.pbOwnedByPlayer? rescue false))
              Haptics.led_for_type(@last_type || :NORMAL) rescue nil
            end
          end
        end
      end
    end
  end
end

# Encounter lightbar: re-classify lightly (same rules as the rumble cue).
if defined?(Haptics::Encounter)
  module Haptics
    module Encounter
      class << self
        unless method_defined?(:_native_obs) || private_method_defined?(:_native_obs)
          alias_method :_native_obs, :on_battle_start
          def on_battle_start(battle)
            _native_obs(battle)
            return unless Haptics.category_on?(:encounters)
            return unless Haptics.dualsense?
            begin
              if (battle.trainerBattle? rescue false)
                opp = (battle.instance_variable_get(:@opponent) rescue nil)
                Haptics.led_for_cue(gym_leader?(opp) ? :gym_leader : :trainer)
              elsif (battle.wildBattle? rescue false)
                foes = (battle.instance_variable_get(:@party2) rescue nil)
                foes = (foes.is_a?(Array) ? foes.compact : [])
                kind = if alpha?(foes) then :alpha
                       elsif foes.length >= 3 || (foes.length == 2 && same_species?(foes)) then :swarm
                       else :wild end
                Haptics.led_for_cue(kind)
              end
            rescue
            end
          end
        end
      end
    end
  end
end

# Restore the lightbar to the player's default when a battle ends.
if defined?(PokeBattle_Battle)
  class PokeBattle_Battle
    if method_defined?(:pbEndBattle) && !method_defined?(:_native_orig_pbEndBattle)
      alias_method :_native_orig_pbEndBattle, :pbEndBattle
      def pbEndBattle(*args, &blk)
        r = _native_orig_pbEndBattle(*args, &blk)
        Haptics.led_reset rescue nil
        r
      end
    end
  end
end
