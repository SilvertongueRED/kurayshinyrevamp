#===============================================================================
# Controller Speaker  -  route Pokemon cries / Pokedex voice-over to the
# DualSense built-in speaker.
#-------------------------------------------------------------------------------
# The DualSense (and DualShock 4) exposes its built-in speaker to Windows as an
# ordinary audio-output endpoint named "Wireless Controller" / "DualSense
# Wireless Controller" (USB only - the speaker is not available over Bluetooth).
# mkxp-z / RGSS can only play sound effects through the *default* output device,
# so we shell out to the bundled helper  kif_speaker.exe  which decodes the clip
# and renders it to that specific endpoint.
#
# Behaviour (auto-detect):
#   * Master toggle ON  (default) and a DualSense speaker is present and the
#     default output device does NOT look like headphones  ->  cries + Pokedex
#     voice-over come out of the controller speaker (instead of the normal mix).
#   * Headphones detected, no controller, toggle OFF, or helper missing  ->  the
#     sound plays the normal way through the default device.  Fully fail-safe:
#     every step is rescued and degrades to the original behaviour.
#
# Settings live on PokemonSystem (see 005_RumbleOptions.rb):
#   speaker_master  (0 = On, 1 = Off)      speaker_volume  (0..100)
#===============================================================================
module ControllerSpeaker
  EXE_CANDIDATES   = ["kif_speaker.exe", "Data/kif_speaker.exe"].freeze
  PROBE_INTERVAL_S = 8.0
  CRY_RE = /Cries\//i      # every cry resolves to "Cries/<SPECIES>"
  VO_RE  = /dex_/i         # Pokedex voice-over files are named dex_*

  @exe_checked      = false
  @exe_path         = nil
  @probe_path       = nil
  @last_probe_spawn = -1.0e9
  @probe_have       = false
  @ds_present       = false
  @def_headph       = false
  @ds_name          = ""
  @def_name         = ""

  def self.now_s; Time.now.to_f; end

  #--- settings (defensive: nil / old save -> sensible default) ----------------
  def self.system; defined?($PokemonSystem) ? $PokemonSystem : nil; end

  def self.enabled?
    s = system
    return false unless s
    v = (s.speaker_master rescue nil)
    v.nil? ? true : (v == 0)            # 0 = On (default On)
  end

  def self.volume
    s = system
    return 100 unless s
    v = (s.speaker_volume rescue nil)
    v = 100 if v.nil?
    v = 0   if v < 0
    v = 100 if v > 100
    v
  end

  #--- game root / helper discovery --------------------------------------------
  def self.game_root
    @game_root ||= (Dir.pwd rescue ".")
  end

  def self.exe_path
    return @exe_path if @exe_checked
    @exe_checked = true
    EXE_CANDIDATES.each do |rel|
      begin
        abs = File.expand_path(rel, game_root)
        if File.file?(abs)
          @exe_path = abs
          break
        end
      rescue
      end
    end
    @exe_path
  end

  def self.available?
    !exe_path.nil?
  end

  def self.probe_file
    @probe_path ||= begin
      File.expand_path("Logs/kif_speaker_probe.txt", game_root)
    rescue
      "kif_speaker_probe.txt"
    end
  end

  def self.ensure_logs_dir
    begin
      dir = File.dirname(probe_file)
      Dir.mkdir(dir) unless File.directory?(dir)
    rescue
    end
  end

  #--- non-blocking spawn ------------------------------------------------------
  def self.spawn_detached(*args)
    exe = exe_path
    return false unless exe
    a = args.map { |x| x.to_s }
    begin
      pid = Process.spawn(exe, *a,
                          :in => File::NULL, :out => File::NULL, :err => File::NULL)
      Process.detach(pid) rescue nil
      return true
    rescue
      # Last-ditch: run it on a worker thread so the game loop never blocks.
      begin
        cmd = %Q{"#{exe}" } + a.map { |x| %Q{"#{x}"} }.join(" ")
        Thread.new { system(cmd) rescue nil }
        return true
      rescue
        return false
      end
    end
  end

  #--- probe (throttled, asynchronous) -----------------------------------------
  def self.maybe_probe
    return unless exe_path
    read_probe                         # pick up any result already on disk
    t = now_s
    return if (t - @last_probe_spawn) < PROBE_INTERVAL_S
    @last_probe_spawn = t
    ensure_logs_dir
    spawn_detached("probe", probe_file)
  end

  def self.read_probe
    begin
      return unless File.file?(probe_file)
      txt = File.read(probe_file) rescue nil
      return unless txt
      @ds_present = (txt[/dualsense_present=(\d)/, 1] == "1")
      @def_headph = (txt[/default_is_headphones=(\d)/, 1] == "1")
      @ds_name    = (txt[/dualsense_name=(.*)/, 1] || "").strip
      @def_name   = (txt[/default_name=(.*)/, 1] || "").strip
      @probe_have = true
    rescue
    end
  end

  def self.ds_present?;  @ds_present;  end
  def self.headphones?;  @def_headph;  end
  def self.ds_name;      @ds_name;     end
  def self.default_name; @def_name;    end

  #--- routing decision --------------------------------------------------------
  def self.route?
    return false unless enabled?
    return false unless exe_path
    maybe_probe
    return false unless @probe_have
    return false unless @ds_present
    return false if @def_headph        # auto-detect: skip while on headphones
    true
  end

  def self.device_substr; "Wireless Controller"; end

  #--- playback ----------------------------------------------------------------
  def self.play_path(abs_path, vol100, pitch = 100)
    return false unless abs_path
    eff = ((vol100.to_f) * volume.to_f / 100.0).round
    eff = 0 if eff < 0
    eff = 100 if eff > 100
    pit = pitch.to_i
    pit = 100 if pit <= 0
    spawn_detached("play", device_substr, abs_path, eff, pit)
  end

  # Resolve an SE name ("Cries/ABRA", "Pokedex/dex_X", possibly "Audio/SE/..")
  # to an absolute, on-disk file path. nil if it cannot be found on disk.
  def self.resolve(name)
    n = name.to_s
    return nil if n == ""
    n = n.sub(/\AAudio\/SE\//i, "")     # the engine resolver re-adds this prefix
    begin
      rel = pbResolveAudioSE(n)
      return nil unless rel
      abs = File.expand_path(rel, game_root)
      return File.file?(abs) ? abs : nil
    rescue
      nil
    end
  end

  def self.route_audiofile(af)
    return false unless af && af.respond_to?(:name)
    path = resolve(af.name)
    return false unless path
    play_path(path, (af.volume rescue 100), (af.pitch rescue 100))
  end

  def self.route_name(name, vol, pitch)
    path = resolve(name)
    return false unless path
    play_path(path, (vol || 100), (pitch || 100))
  end

  #--- name classification -----------------------------------------------------
  def self.name_of(param)
    return nil if param.nil?
    return param if param.is_a?(String)
    return (param.name rescue nil) if param.respond_to?(:name)
    nil
  end

  def self.cry_name?(n); !!(n.to_s =~ CRY_RE); end
  def self.vo_name?(n);  !!(n.to_s =~ VO_RE);  end

  #--- settings "Test" button --------------------------------------------------
  # Synchronously refreshes detection, then force-plays a sample cry to the
  # controller speaker (bypassing the headphone gate so the user can verify the
  # hardware).  Returns a human-readable status string for pbMessage.
  def self.test
    return _INTL("Speaker helper not installed (kif_speaker.exe is missing).") unless exe_path
    ensure_logs_dir
    begin
      pid = Process.spawn(exe_path, "probe", probe_file,
                          :out => File::NULL, :err => File::NULL)
      deadline = now_s + 2.5
      loop do
        done = (Process.waitpid(pid, Process::WNOHANG) rescue true)
        break if done
        break if now_s > deadline
        sleep 0.05
      end
    rescue
    end
    read_probe
    unless @probe_have
      return _INTL("Could not read controller-speaker detection results.")
    end
    unless @ds_present
      return _INTL("No controller speaker detected.\nConnect a DualSense by USB (the speaker is not available over Bluetooth).")
    end
    sample = nil
    ["Cries/PIKACHU", "Cries/EEVEE", "Cries/BULBASAUR", "Cries/RATTATA"].each do |nm|
      sample = resolve(nm)
      break if sample
    end
    if sample
      play_path(sample, 100, 100)
    end
    name = (@ds_name.nil? || @ds_name == "") ? _INTL("controller") : @ds_name
    if @def_headph
      _INTL("Playing a test cry on the {1}.\nHeadphones are detected on your default output, so cries will normally stay on the default device.", name)
    else
      _INTL("Playing a test cry on the {1}.\nCries and voice-over will play here.", name)
    end
  end
end

#-------------------------------------------------------------------------------
# Hook 1: pbSEPlay  -  catches EVERY Pokemon cry. All cries resolve to a
# "Cries/<SPECIES>" SE and are played through pbSEPlay (battle scene cry via
# setSE, EBDX scene, the animation player, and the GameData::Species.play_cry*
# methods all funnel here).  When routing is active the cry is sent to the
# controller speaker INSTEAD of the default mix.
#-------------------------------------------------------------------------------
class Object
  unless method_defined?(:_spk_orig_pbSEPlay) || private_method_defined?(:_spk_orig_pbSEPlay)
    alias_method :_spk_orig_pbSEPlay, :pbSEPlay
    def pbSEPlay(param, volume = nil, pitch = nil)
      begin
        if ControllerSpeaker.enabled?
          nm = ControllerSpeaker.name_of(param)
          if nm && ControllerSpeaker.cry_name?(nm) && ControllerSpeaker.route?
            af = pbResolveAudioFile(param, volume, pitch)
            return if af && ControllerSpeaker.route_audiofile(af)
          end
        end
      rescue
      end
      _spk_orig_pbSEPlay(param, volume, pitch)
    end
  end
end

#-------------------------------------------------------------------------------
# Hook 2: Audio.se_play  -  catches the Pokedex voice-over mod (files named
# dex_*) which plays directly through Audio.se_play, and any stray direct cry
# playback.  Only "dex_" and "Cries/" names are ever intercepted.
#-------------------------------------------------------------------------------
module Audio
  class << self
    unless method_defined?(:_spk_orig_se_play)
      alias_method :_spk_orig_se_play, :se_play
      def se_play(name, volume = 100, pitch = 100, *rest)
        begin
          if ControllerSpeaker.enabled? &&
             (ControllerSpeaker.vo_name?(name) || ControllerSpeaker.cry_name?(name)) &&
             ControllerSpeaker.route?
            return if ControllerSpeaker.route_name(name, volume, pitch)
          end
        rescue
        end
        _spk_orig_se_play(name, volume, pitch, *rest)
      end
    end
  end
end
