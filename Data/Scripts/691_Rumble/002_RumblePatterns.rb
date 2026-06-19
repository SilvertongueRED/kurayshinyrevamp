#===============================================================================
# Controller Vibration / Rumble  -  PATTERN LIBRARY
#-------------------------------------------------------------------------------
# Every pattern is an Array of [ low(0..1), high(0..1), duration_ms ] steps.
# LOW = heavy/low-freq motor, HIGH = light/high-freq buzz. Designed two-motor,
# TemTem-inspired: each effect is a little choreographed sequence, not a buzz.
# The global intensity slider scales all of these at write time.
#===============================================================================
module Haptics
  module Patterns
    module_function

    #--- tiny builders ---------------------------------------------------------
    def gap(ms);                 [[0.0, 0.0, ms]]; end
    def hit(lo, hi, ms);         [[lo, hi, ms]];   end
    def rep(seq, n);             out = []; n.times { out.concat(seq) }; out; end
    # linear ramp split into `steps` slices
    def ramp(lo0, lo1, hi0, hi1, ms, steps = 6)
      steps = 1 if steps < 1
      slice = ms.to_f / steps
      out = []
      (0...steps).each do |i|
        t = (i + 1).to_f / steps
        out << [lo0 + (lo1 - lo0) * t, hi0 + (hi1 - hi0) * t, slice]
      end
      out
    end

    #===========================================================================
    # MOVE TYPE SIGNATURES
    # lo/hi are the headline levels; :motif chooses the rhythm/feel.
    #===========================================================================
    TYPE_FX = {
      :NORMAL   => { :lo => 0.70, :hi => 0.40, :motif => :thump   },
      :FIRE     => { :lo => 0.50, :hi => 0.85, :motif => :stutter },
      :WATER    => { :lo => 0.75, :hi => 0.30, :motif => :wave    },
      :ELECTRIC => { :lo => 0.30, :hi => 0.95, :motif => :zap     },
      :GRASS    => { :lo => 0.40, :hi => 0.50, :motif => :flutter },
      :ICE      => { :lo => 0.55, :hi => 0.70, :motif => :shiver  },
      :FIGHTING => { :lo => 0.95, :hi => 0.40, :motif => :double  },
      :POISON   => { :lo => 0.55, :hi => 0.45, :motif => :bubble  },
      :GROUND   => { :lo => 1.00, :hi => 0.20, :motif => :quake   },
      :FLYING   => { :lo => 0.30, :hi => 0.55, :motif => :gust    },
      :PSYCHIC  => { :lo => 0.55, :hi => 0.60, :motif => :warble  },
      :BUG      => { :lo => 0.30, :hi => 0.60, :motif => :skitter },
      :ROCK     => { :lo => 0.95, :hi => 0.50, :motif => :slam    },
      :GHOST    => { :lo => 0.50, :hi => 0.30, :motif => :phase   },
      :DRAGON   => { :lo => 0.90, :hi => 0.70, :motif => :roar    },
      :DARK     => { :lo => 0.80, :hi => 0.30, :motif => :strike  },
      :STEEL    => { :lo => 0.70, :hi => 0.80, :motif => :clang   },
      :FAIRY    => { :lo => 0.30, :hi => 0.70, :motif => :sparkle }
    }
    DEFAULT_FX = { :lo => 0.70, :hi => 0.40, :motif => :thump }

    def fx_for(type)
      key = type
      key = type.id   if type.respond_to?(:id)
      key = key.to_sym if key.respond_to?(:to_sym)
      return TYPE_FX[key] || DEFAULT_FX
    end

    # Build a motif at a given strength scale (incoming hit = 1.0, outgoing = ~0.6)
    def motif(name, lo, hi, s)
      lo *= s; hi *= s
      case name
      when :thump
        hit(lo, hi, 90) + gap(28) + hit(lo * 0.5, hi * 0.4, 60)
      when :stutter   # fire: crackling buzz then a flare
        rep(hit(lo * 0.4, hi, 38) + gap(24), 4) + hit(lo, hi * 0.5, 80)
      when :wave      # water: a rolling swell
        ramp(0.15, lo, 0.05, hi, 170, 5) + ramp(lo, 0.1, hi, 0.0, 150, 5)
      when :zap       # electric: sharp staccato spikes
        rep(hit(0.2, hi, 22) + gap(18), 5) + hit(0.0, hi, 45)
      when :flutter   # grass: soft rustle
        rep(hit(lo * 0.3, hi * 0.6, 34) + gap(30), 3) + hit(lo * 0.4, hi * 0.3, 50)
      when :shiver    # ice: brittle tick then a cold shiver
        hit(0.3, hi, 50) + rep(hit(lo, 0.18, 42) + hit(lo * 0.55, 0.08, 42), 3)
      when :double    # fighting: two hard punches
        hit(lo, hi, 80) + gap(55) + hit(lo, hi, 95)
      when :bubble    # poison: irregular blips
        hit(lo, 0.2, 60) + gap(40) + hit(lo * 0.7, 0.3, 45) + gap(70) + hit(lo * 0.5, 0.2, 55)
      when :quake     # ground: deep building rumble
        ramp(0.3, lo, 0.05, 0.2, 240, 6) + hit(lo, 0.2, 150) + ramp(lo, 0.0, 0.2, 0.0, 130, 4)
      when :gust      # flying: light airy swell
        hit(0.2, hi, 60) + hit(0.12, hi * 0.6, 80) + hit(0.0, hi * 0.25, 70)
      when :warble    # psychic: oscillating low<->high
        rep(hit(lo, 0.1, 70) + hit(0.1, hi, 70), 2)
      when :skitter   # bug: many tiny ticks
        rep(hit(0.12, hi, 26) + gap(26), 6)
      when :slam      # rock: huge slam + debris
        hit(lo, hi, 110) + gap(38) + hit(0.2, hi * 0.5, 40) + hit(0.1, hi * 0.3, 45)
      when :phase     # ghost: eerie faint fade in/out
        ramp(0.0, lo, 0.0, hi * 0.5, 200, 5) + ramp(lo, 0.0, hi * 0.5, 0.0, 220, 5)
      when :roar      # dragon: building roar
        ramp(0.3, lo, 0.2, hi, 320, 7) + hit(lo, hi, 200)
      when :strike    # dark: sharp hit, abrupt cut
        hit(lo, hi, 70) + gap(8)
      when :clang     # steel: metallic ring
        hit(lo, hi, 60) + hit(0.2, hi, 50) + hit(0.1, hi * 0.7, 60) + hit(0.0, hi * 0.4, 65)
      when :sparkle   # fairy: light triplets
        rep(hit(0.1, hi, 40) + gap(38), 3) + hit(0.2, hi * 0.6, 60)
      else
        hit(lo, hi, 90)
      end
    end

    # You USED a move of this type: a quick wind-up, then a lighter motif.
    def outgoing(type)
      fx = fx_for(type)
      ramp(0.0, fx[:lo] * 0.4, 0.0, fx[:hi] * 0.4, 70, 3) +
        motif(fx[:motif], fx[:lo], fx[:hi], 0.55)
    end

    # Your Pokemon got HIT by a move of this type: full-strength impact.
    def incoming(type)
      fx = fx_for(type)
      motif(fx[:motif], fx[:lo], fx[:hi], 1.0)
    end

    #===========================================================================
    # ENCOUNTER CUES  (each distinct)
    #===========================================================================
    # Friendly two-ping "!" for an ordinary wild Pokemon.
    def wild
      hit(0.5, 0.5, 70) + gap(60) + hit(0.5, 0.45, 70)
    end

    # Alpha: an ominous boss growl that builds, then three heavy beats.
    def alpha
      ramp(0.2, 1.0, 0.05, 0.55, 300, 6) + hit(1.0, 0.6, 120) + gap(90) +
        rep(hit(1.0, 0.7, 95) + gap(75), 3)
    end

    # Swarm: a low undercurrent crawling with many little high-freq skitters.
    def swarm
      hit(0.4, 0.0, 50) + rep(hit(0.3, 0.85, 30) + hit(0.2, 0.0, 24), 8)
    end

    # Trainer: a confident rising "eye-contact" challenge, ending on a snap.
    def trainer
      ramp(0.2, 0.7, 0.0, 0.2, 200, 5) + gap(40) + hit(0.35, 0.95, 80)
    end

    # Gym Leader / E4 / Champion: a grand escalating fanfare with a big finish.
    def gym_leader
      hit(0.5, 0.4, 90) + gap(80) +
        hit(0.7, 0.55, 95) + gap(80) +
        hit(0.9, 0.7, 105) + gap(90) +
        hit(1.0, 0.95, 280)
    end

    #===========================================================================
    # OVERWORLD
    #===========================================================================
    def step_walk;  hit(0.32, 0.0, 55); end                                  # soft tick
    def step_run;   hit(0.5, 0.16, 45) + gap(22) + hit(0.32, 0.10, 35); end  # quick double
    def step_bike;  hit(0.0, 0.22, 40); end                                  # faint purr
    def step_surf;  hit(0.28, 0.0, 95); end                                  # gentle wave

    #===========================================================================
    # SETTINGS TEST  -  showcases both motors + current intensity
    #===========================================================================
    def test
      ramp(0.0, 1.0, 0.0, 0.0, 320, 8) + gap(120) +
        ramp(0.0, 0.0, 0.0, 1.0, 320, 8) + gap(120) +
        hit(1.0, 1.0, 240)
    end
  end
end
