#==============================================================================
#  FORK DIAGNOSTIC (temporary) - non-EBDX battle freeze capture
#------------------------------------------------------------------------------
#  Symptom being chased:
#    With "Vanilla UI" or "Ghost Battle Visuals" selected (i.e. EBDX OFF), the
#    battle UI renders only the backdrop, no battlers / databoxes / command box,
#    and freezes; afterwards the overworld renders black (tilemap gone, sprites
#    present) until a map change or the next EBDX battle. EBDX ON works fine.
#
#  Both non-EBDX modes use the BASE PokeBattle_Scene (the EBDX scene is a
#  subclass that shadows the base methods), so the failure is in the base-scene
#  + GhostBattle Classic+ render path. The freeze means an exception is being
#  raised and swallowed somewhere, so no Ruby backtrace reaches the user.
#
#  WHAT THIS FILE DOES (purely additive, removable):
#    * Wraps the base-scene start/update methods, the battler-sprite methods and
#      the databox methods. On ANY exception it appends a full backtrace to
#      Logs/ghost_vanilla_crash.log and then RE-RAISES, so behaviour is
#      unchanged - this only observes.
#    * Tees the engine's pbPrintException so any unrescued error is also logged.
#    * Loads last (filename sorts after the GhostBattle mod and the
#      zzz_ghost_ebdx_bridge shim) so it wraps the FINAL assembled methods.
#
#  It is inert / harmless on installs without the GhostBattle mod or EBDX.
#  DELETE this file once the root cause is fixed.
#==============================================================================

module GhostVanillaDiag
  LOG = "Logs/ghost_vanilla_crash.log"
  @seen = {}

  def self.reset_seen
    @seen = {}
  end

  def self.context
    ebdx  = (defined?(EBDXToggle) && EBDXToggle.enabled?) rescue "?"
    ghost = (defined?(GhostVisualsBridge) && GhostVisualsBridge.ghost_active?) rescue "?"
    bgui  = ($PokemonSystem.instance_variable_get(:@battlegui) rescue "?")
    ebon  = ($PokemonSystem.mp_ebdx_enabled rescue "?")
    "EBDX.enabled?=#{ebdx} ghost_active?=#{ghost} @battlegui=#{bgui} mp_ebdx_enabled=#{ebon}"
  end

  def self.log(tag, e)
    sig = "#{tag}|#{e.class}|#{e.message}"
    return if @seen[sig]      # de-dupe so a per-frame error doesn't spam the log
    @seen[sig] = true
    begin
      File.open(LOG, "a") do |f|
        f.puts("==== #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}  [#{tag}] ====")
        f.puts("  ctx: #{context}")
        f.puts("  #{e.class}: #{e.message}")
        bt = (e.backtrace || [])
        bt[0, 30].each { |line| f.puts("    #{line}") }
        f.puts("    ... (#{bt.length - 30} more frames)") if bt.length > 30
        f.puts("")
      end
    rescue
      nil
    end
    (MultiplayerDebug.info("GVDIAG", "#{tag}: #{e.class}: #{e.message}") rescue nil) if defined?(MultiplayerDebug)
  end

  # Wrap each named instance method of klass in a log+re-raise guard, once.
  def self.guard(klass, methods, tag_prefix, reset_first = nil)
    return unless klass
    methods.each do |m|
      next unless klass.method_defined?(m) || klass.private_method_defined?(m)
      ali = "gvdiag_#{m}".to_sym
      next if klass.method_defined?(ali) || klass.private_method_defined?(ali)
      klass.send(:alias_method, ali, m)
      reset = (m == reset_first)
      klass.send(:define_method, m) do |*args, &blk|
        GhostVanillaDiag.reset_seen if reset
        begin
          send(ali, *args, &blk)
        rescue Exception => e
          GhostVanillaDiag.log("#{tag_prefix}##{m}", e)
          raise
        end
      end
    end
  end
end

#------------------------------------------------------------------------------
# Base battle scene (NOT the EBDX subclass - it overrides these without super,
# so these guards only ever fire on the vanilla / Ghost-Classic+ path).
#------------------------------------------------------------------------------
if defined?(PokeBattle_Scene)
  GhostVanillaDiag.guard(PokeBattle_Scene,
    [:pbStartBattle, :pbInitSprites, :pbFrameUpdate, :pbUpdate],
    "Scene", :pbStartBattle)
end

#------------------------------------------------------------------------------
# Battler sprites (GhostBattle reopens this class - glow sprites, x=/y=, etc.)
#------------------------------------------------------------------------------
if defined?(PokemonBattlerSprite)
  GhostVanillaDiag.guard(PokemonBattlerSprite,
    [:initialize, :update, :setPokemonBitmap, :pbSetPosition],
    "BattlerSprite")
end

#------------------------------------------------------------------------------
# Databoxes (GhostBattle reopens PokemonDataBox heavily for Classic+)
#------------------------------------------------------------------------------
if defined?(PokemonDataBox)
  GhostVanillaDiag.guard(PokemonDataBox,
    [:initialize, :refresh, :update, :draw],
    "DataBox")
end

#------------------------------------------------------------------------------
# Tee the engine exception printer: anything that reaches the Essentials error
# screen (i.e. is NOT swallowed) gets logged too, with its backtrace.
#------------------------------------------------------------------------------
if defined?(pbPrintException)
  unless defined?(gvdiag_orig_pbPrintException)
    alias gvdiag_orig_pbPrintException pbPrintException
    def pbPrintException(e)
      GhostVanillaDiag.log("pbPrintException(unrescued)", e) rescue nil
      gvdiag_orig_pbPrintException(e)
    end
  end
end

(MultiplayerDebug.info("GVDIAG", "Ghost/Vanilla battle crash-logger active -> #{GhostVanillaDiag::LOG}") rescue nil) if defined?(MultiplayerDebug)
