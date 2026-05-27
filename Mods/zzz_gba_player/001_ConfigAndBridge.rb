# frozen_string_literal: true

module GBAPlayer
  ROOT = File.expand_path("Mods/zzz_gba_player")
  CONFIG_PATH = File.join(ROOT, "config.json")
  HISTORY_PATH = File.join(ROOT, "import_history.json")
  LOG_PATH = File.join(ROOT, "launch.log")
  MIRROR_RUNTIME = File.join(ROOT, "mirror_runtime")
  ROM_EXTENSIONS = [".gba", ".gb", ".gbc", ".zip"]
  SAVE_EXTENSIONS = [".sav", ".srm", ".sa1"]
  MGBA_SDL_KEY_CONFIG = {
    "keyRight"  => "108",
    "keyDown"   => "107",
    "keyR"      => "115",
    "keyL"      => "97",
    "keyB"      => "122",
    "keyUp"     => "105",
    "keySelect" => "8",
    "keyLeft"   => "106",
    "keyA"      => "120",
    "keyStart"  => "13"
  }
  EMULATOR_EXE_NAMES = [
    "mGBA.exe",
    "mgba-sdl.exe",
    "mgba.exe",
    "mgba-qt.exe",
    "visualboyadvance-m.exe",
    "VBA-M.exe"
  ]
  MIRROR_EMULATOR_EXE_NAMES = [
    "mgba-sdl.exe",
    "mGBA.exe",
    "mgba.exe",
    "mgba-qt.exe"
  ]
  POKEMON_ROM_CODES = {
    "AXVE" => "Ruby",
    "AXPE" => "Sapphire",
    "BPEE" => "Emerald",
    "BPRE" => "FireRed",
    "BPGE" => "LeafGreen",
    "AXVJ" => "Ruby",
    "AXPJ" => "Sapphire",
    "BPEJ" => "Emerald",
    "BPRJ" => "FireRed",
    "BPGJ" => "LeafGreen",
    "AXVP" => "Ruby",
    "AXPP" => "Sapphire",
    "BPEP" => "Emerald",
    "BPRP" => "FireRed",
    "BPGP" => "LeafGreen"
  }

  class << self
    attr_reader :bridge_error
  end

  def self.intl(text, *args)
    return _INTL(text.to_s.dup, *args) if defined?(_INTL)
    result = text.to_s.dup
    args.each_with_index { |arg, i| result.gsub!("{#{i + 1}}", arg.to_s) }
    result
  end

  def self.default_config
    {
      "rom_roots" => ["Mods/zzz_gba_player/ROMs"],
      "save_roots" => ["Mods/zzz_gba_player/Saves", "Mods/zzz_gba_player/ROMs"],
      "emulator_path" => "",
      "emulator_search_roots" => ["Mods/zzz_gba_player/Emulator"],
      "emulator_args" => "{rom}",
      "emulator_volume_percent" => 25,
      "bridge_backend" => "mirror",
      "native_core_enabled" => false,
      "libretro_core_path" => "Mods/zzz_gba_player/native/corehost/cores/mgba_libretro.dll",
      "native_frame_fps" => 30,
      "native_audio_buffer_ms" => 240,
      "display_mode" => "pip",
      "mirror_embed" => true,
      "mirror_lock_aspect" => true,
      "mirror_fps" => 30,
      "walkalong_size" => "large",
      "walkalong_screen_width" => 180,
      "walkalong_position" => "top_right",
      "walkalong_x" => nil,
      "walkalong_y" => nil,
      "walkalong_pocketed" => false,
      "keymap" => {
        "up" => "I",
        "down" => "K",
        "left" => "J",
        "right" => "L",
        "a" => "U",
        "b" => "O",
        "l" => "Y",
        "r" => "P",
        "start" => "H",
        "select" => "G",
        "stop" => "F12",
        "toggle_size" => "F11"
      },
      "species_overrides" => {},
      "move_overrides" => {},
      "item_overrides" => {},
      "favorites" => [],
      "last_rom" => ""
    }
  end

  def self.ensure_directories
    Dir.mkdir(ROOT) unless Dir.exist?(ROOT)
    Dir.mkdir(File.join(ROOT, "ROMs")) unless Dir.exist?(File.join(ROOT, "ROMs"))
    Dir.mkdir(File.join(ROOT, "Saves")) unless Dir.exist?(File.join(ROOT, "Saves"))
    Dir.mkdir(File.join(ROOT, "Emulator")) unless Dir.exist?(File.join(ROOT, "Emulator"))
    Dir.mkdir(File.join(ROOT, "native")) unless Dir.exist?(File.join(ROOT, "native"))
    Dir.mkdir(MIRROR_RUNTIME) unless Dir.exist?(MIRROR_RUNTIME)
  end

  def self.config
    ensure_directories
    @config ||= begin
      loaded = {}
      if File.exist?(CONFIG_PATH)
        loaded = parse_json(File.read(CONFIG_PATH))
        loaded = {} unless loaded.is_a?(Hash)
      end
      deep_merge(default_config, loaded)
    end
  end

  def self.reload_config
    @config = nil
    config
  end

  def self.write_config
    ensure_directories
    File.open(CONFIG_PATH, "wb") { |f| f.write(pretty_json(config)) }
  end

  def self.parse_json(text)
    if defined?(ModManager::JSON)
      ModManager::JSON.parse(text)
    else
      require "json"
      JSON.parse(text)
    end
  rescue
    {}
  end

  def self.pretty_json(value)
    if defined?(ModManager::JSON)
      ModManager::JSON.dump(value)
    else
      require "json"
      JSON.pretty_generate(value)
    end
  rescue
    value.inspect
  end

  def self.deep_merge(base, overlay)
    merged = base.clone
    overlay.each do |key, value|
      if merged[key].is_a?(Hash) && value.is_a?(Hash)
        merged[key] = deep_merge(merged[key], value)
      else
        merged[key] = value
      end
    end
    merged
  end

  def self.absolute_path(path)
    return "" if path.nil? || path.to_s.empty?
    path = path.to_s
    if path[/\A[A-Za-z]:[\\\/]/] || path.start_with?("\\\\", "/", "\\")
      File.expand_path(path)
    else
      File.expand_path(path)
    end
  end

  def self.windows_path(path)
    absolute_path(path).gsub("/", "\\")
  end

  def self.cmd_quote(text)
    "\"" + text.to_s.gsub('"', '\"') + "\""
  end

  def self.rom_roots
    Array(config["rom_roots"]).map { |root| absolute_path(root) }
  end

  def self.save_roots
    roots = Array(config["save_roots"]).map { |root| absolute_path(root) }
    rom_roots.each { |root| roots << root }
    roots.uniq
  end

  def self.discover_roms
    discover_files(rom_roots, ROM_EXTENSIONS)
  end

  def self.discover_saves
    discover_files(save_roots, SAVE_EXTENSIONS)
  end

  def self.discover_files(roots, extensions)
    roots = Array(roots).compact
    files = []
    roots.each do |root|
      next if root.empty? || !Dir.exist?(root)
      Dir[File.join(root, "**", "*")].each do |path|
        next unless File.file?(path)
        files << File.expand_path(path) if extensions.include?(File.extname(path).downcase)
      end
    end
    files.uniq.sort_by { |path| path.downcase }
  end

  def self.label_for_path(path)
    path = File.expand_path(path)
    base_root = (rom_roots + save_roots).select { |root| path.downcase.start_with?(root.downcase) }
                                .max_by(&:length)
    label = if base_root
              path[(base_root.length + 1)..-1] || File.basename(path)
            else
              File.basename(path)
            end
    label.gsub("\\", "/")
  end

  def self.rom_label(path)
    info = gba_rom_header(path)
    title = friendly_rom_title(info)
    return title if title && !title.empty?
    title = version_from_filename(File.basename(path, File.extname(path)))
    title.empty? ? label_for_path(path) : title
  end

  def self.gba_rom_header(path)
    return nil unless File.extname(path).downcase == ".gba"
    return nil unless File.file?(path) && File.size(path) >= 0xB0
    header = File.binread(path, 32, 0xA0)
    {
      :title => clean_header_text(header.byteslice(0, 12)),
      :code => clean_header_text(header.byteslice(12, 4))
    }
  rescue
    nil
  end

  def self.clean_header_text(text)
    text.to_s.delete("\0").gsub(/[^A-Za-z0-9 _-]/, "").strip
  end

  def self.friendly_rom_title(info)
    return nil unless info
    code = info[:code].to_s.upcase
    return POKEMON_ROM_CODES[code] if POKEMON_ROM_CODES[code]
    title = info[:title].to_s.strip
    return nil if title.empty?
    normalized = title.upcase.gsub(/\s+/, " ")
    return "Emerald" if normalized.include?("POKEMON EMER")
    return "FireRed" if normalized.include?("FIRERED") || normalized.include?("FIRE RED")
    return "LeafGreen" if normalized.include?("LEAFGREEN") || normalized.include?("LEAF GREEN")
    return "Sapphire" if normalized.include?("SAPP")
    return "Ruby" if normalized.include?("RUBY")
    title.gsub(/\APOKEMON\s*/i, "").gsub(/\s*VERSION\z/i, "").strip
  end

  def self.version_from_filename(name)
    text = name.to_s.gsub(/[_-]+/, " ")
    return "Emerald" if text[/emerald/i]
    return "FireRed" if text[/fire\s*red/i] || text[/firered/i]
    return "LeafGreen" if text[/leaf\s*green/i] || text[/leafgreen/i]
    return "Sapphire" if text[/sapphire/i]
    return "Ruby" if text[/ruby/i]
    shortened = text.sub(/\A\s*pokemon\s*/i, "").sub(/\s*version.*\z/i, "").strip
    shortened.empty? ? "" : shortened
  end

  def self.load_history
    return {} unless File.exist?(HISTORY_PATH)
    parsed = parse_json(File.read(HISTORY_PATH))
    parsed.is_a?(Hash) ? parsed : {}
  rescue
    {}
  end

  def self.write_history(history)
    File.open(HISTORY_PATH, "wb") { |f| f.write(pretty_json(history)) }
  end

  def self.log(message)
    ensure_directories
    File.open(LOG_PATH, "ab") { |f| f.write("[#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}] #{message}\n") }
  rescue
    nil
  end

  def self.favorite?(path)
    Array(config["favorites"]).map { |item| absolute_path(item).downcase }.include?(absolute_path(path).downcase)
  end

  def self.set_last_rom(path)
    config["last_rom"] = absolute_path(path)
    write_config
  end

  def self.display_mode
    mode = config["display_mode"].to_s.downcase
    mode == "pip" ? "pip" : "overlay"
  end

  def self.toggle_display_mode
    config["display_mode"] = display_mode == "overlay" ? "pip" : "overlay"
    write_config
    config["display_mode"]
  end

  def self.emulator_volume_percent
    raw = config.key?("emulator_volume_percent") ? config["emulator_volume_percent"] : config["emulator_volume"]
    volume = raw.to_i
    volume = 25 if volume <= 0 && raw.to_s.strip.empty?
    [[volume, 0].max, 200].min
  rescue
    25
  end

  def self.mgba_volume_value
    ((emulator_volume_percent * 256) / 100.0).round
  end

  def self.mirror_fps
    fps = config["mirror_fps"].to_i
    fps = 30 if fps <= 0
    [[fps, 10].max, 60].min
  rescue
    30
  end

  def self.native_frame_fps
    fps = config["native_frame_fps"].to_i
    fps = mirror_fps if fps <= 0
    [[fps, 10].max, 60].min
  rescue
    30
  end

  def self.native_audio_buffer_ms
    ms = config["native_audio_buffer_ms"].to_i
    ms = 240 if ms <= 0
    [[ms, 60].max, 600].min
  rescue
    240
  end

  def self.bridge_backend
    backend = config["bridge_backend"].to_s.downcase
    ["auto", "native", "mirror"].include?(backend) ? backend : "auto"
  end

  def self.toggle_bridge_backend
    order = ["mirror", "native", "auto"]
    config["bridge_backend"] = order[(order.index(bridge_backend).to_i + 1) % order.length]
    write_config
    config["bridge_backend"]
  end

  def self.native_core_enabled?
    backend = bridge_backend
    return false if backend == "mirror"
    return true if backend == "native"
    config["native_core_enabled"] == true
  rescue
    false
  end

  def self.native_core_helper_path
    File.join(ROOT, "native", "corehost", "publish", "GBAPlayerCoreHost.exe")
  end

  def self.libretro_core_path
    configured = config["libretro_core_path"].to_s.strip
    configured = "Mods/zzz_gba_player/native/corehost/cores/mgba_libretro.dll" if configured.empty?
    absolute_path(configured)
  end

  def self.native_core_available?
    File.file?(native_core_helper_path) && File.file?(libretro_core_path)
  rescue
    false
  end

  def self.native_core_status
    if File.file?(native_core_helper_path) && File.file?(libretro_core_path)
      "Native core bridge installed but experimental. Backend: #{bridge_backend}."
    elsif File.file?(native_core_helper_path)
      "Native core helper installed, but mgba_libretro.dll is missing. Backend: #{bridge_backend}."
    else
      nil
    end
  end

  def self.bridge_available?
    return @bridge_available unless @bridge_available.nil?
    @bridge_available = false
    @bridge_error = nil
    begin
      require File.join(ROOT, "native", "gba_player_bridge")
    rescue Exception => e
      @bridge_error = e.message
      begin
        require "gba_player_bridge"
      rescue Exception => e2
        @bridge_error = e2.message
      end
    end
    @bridge_available = defined?(GBAPlayerBridge) &&
                        GBAPlayerBridge.respond_to?(:open_rom) &&
                        GBAPlayerBridge.respond_to?(:close)
  end

  def self.bridge_status
    if bridge_available?
      if GBAPlayerBridge.respond_to?(:status)
        GBAPlayerBridge.status.to_s
      else
        "Native bridge loaded."
      end
    else
      native = native_core_status
      emulator = detected_emulator_path
      if emulator
        mirror = detected_mirror_emulator_path || emulator
        if bridge_backend == "mirror" || !native_core_enabled?
          suffix = native ? " Native core is installed but disabled." : ""
          "Using stable v1 mirror with #{File.basename(mirror)}.#{suffix}"
        else
          native || "Native bridge not installed. In-game mirror will use #{File.basename(mirror)}."
        end
      else
        "Native bridge not installed. Put mGBA.exe in Mods/zzz_gba_player/Emulator or set emulator_path in config.json."
      end
    end
  end

  def self.open_rom(path, mode = nil)
    path = absolute_path(path)
    return false unless File.file?(path)
    log("open_rom #{path}")
    mode = (mode || display_mode).to_s
    if bridge_available?
      result = GBAPlayerBridge.open_rom(path, mode, config)
      if result
        set_last_rom(path)
        return true
      end
    end
    result = launch_external_emulator(path)
    set_last_rom(path) if result
    result
  rescue Exception => e
    pbMessage(intl("The GBA Player could not open that ROM.\n{1}", e.message)) if defined?(pbMessage)
    false
  end

  def self.close
    GBAPlayerBridge.close if bridge_available?
  rescue
    nil
  end

  def self.launch_external_emulator(path)
    emulator = detected_emulator_path
    if emulator
      launch_with_configured_emulator(emulator, path)
    else
      pbMessage(intl("No GBA emulator was found.\nPut mGBA.exe in:\n{1}\nor set emulator_path in config.json.", File.join(ROOT, "Emulator"))) if defined?(pbMessage)
      false
    end
  end

  def self.detected_emulator_path
    configured = config["emulator_path"].to_s.strip
    configured_path = absolute_path(configured)
    return configured_path if !configured.empty? && File.file?(configured_path)
    emulator_candidates.find { |path| File.file?(path) }
  end

  def self.detected_mirror_emulator_path
    configured = detected_emulator_path
    if configured
      sibling_sdl = File.join(File.dirname(configured), "mgba-sdl.exe")
      return sibling_sdl if File.file?(sibling_sdl)
    end
    emulator_candidates(MIRROR_EMULATOR_EXE_NAMES).find { |path| File.file?(path) }
  end

  def self.emulator_candidates(names = EMULATOR_EXE_NAMES)
    candidates = []
    Array(config["emulator_search_roots"]).each do |root|
      root = absolute_path(root)
      names.each { |exe| candidates << File.join(root, exe) }
      names.each { |exe| candidates.concat(Dir[File.join(root, "**", exe)]) } if Dir.exist?(root)
    end
    names.each { |exe| candidates << File.join(ROOT, "Emulator", exe) }
    ["ProgramFiles", "ProgramFiles(x86)", "LOCALAPPDATA"].each do |env_key|
      base = ENV[env_key]
      next if !base || base.empty?
      names.each do |exe|
        candidates << File.join(base, "mGBA", exe)
        candidates << File.join(base, exe)
      end
    end
    ENV["PATH"].to_s.split(File::PATH_SEPARATOR).each do |dir|
      names.each { |exe| candidates << File.join(dir, exe) }
    end
    candidates.map { |path| File.expand_path(path) }.uniq
  end

  def self.launch_with_configured_emulator(emulator, path)
    ensure_mgba_sdl_config(emulator)
    args_template = config["emulator_args"].to_s
    args_template = "{rom}" if args_template.empty?
    emulator_path = absolute_path(emulator)
    rom_path = absolute_path(path)
    workdir = File.dirname(emulator_path)
    if args_template == "{rom}"
      command = "cmd.exe /c start \"GBA Player\" /D #{cmd_quote(windows_path(workdir))} #{cmd_quote(windows_path(emulator_path))} -C volume=#{mgba_volume_value} -C mute=0 #{cmd_quote(windows_path(rom_path))}"
    else
      args = args_template.gsub("{rom}", cmd_quote(windows_path(rom_path)))
      command = "cmd.exe /c start \"GBA Player\" /D #{cmd_quote(windows_path(workdir))} #{cmd_quote(windows_path(emulator_path))} #{args}"
    end
    log("launch command #{command}")
    ok = system(command)
    log("launch result #{ok.inspect}")
    !!ok
  end

  def self.mirror_helper_path
    File.join(ROOT, "native", "mirror", "publish", "GBAPlayerMirror.exe")
  end

  def self.start_native_core(path, rect = nil)
    ensure_directories
    path = absolute_path(path)
    return false unless native_core_enabled?
    return false unless File.file?(native_core_helper_path)
    return false unless File.file?(libretro_core_path)
    if !File.file?(path)
      pbMessage(intl("ROM file not found.")) if defined?(pbMessage)
      return false
    end
    stop_mirror
    legacy_frame_path = File.join(MIRROR_RUNTIME, "frame.bmp")
    Dir[File.join(MIRROR_RUNTIME, "frame.*.png")].each { |file| File.delete(file) rescue nil }
    [mirror_frame_path, legacy_frame_path, mirror_status_path, mirror_command_path].each do |file|
      File.delete(file) if File.exist?(file)
    rescue
      nil
    end
    File.open(mirror_command_path, "wb") { |f| f.write("") }
    args = [
      native_core_helper_path,
      "--core", libretro_core_path,
      "--rom", path,
      "--frame", mirror_frame_path,
      "--command", mirror_command_path,
      "--status", mirror_status_path,
      "--save-dir", File.join(ROOT, "Saves"),
      "--system-dir", File.join(ROOT, "native", "corehost", "system"),
      "--fps", native_frame_fps.to_s,
      "--volume-percent", emulator_volume_percent.to_s,
      "--audio-buffer-ms", native_audio_buffer_ms.to_s
    ]
    pid = Process.spawn(*args)
    Process.detach(pid) if Process.respond_to?(:detach)
    @mirror_pid = pid
    @mirror_rom = path
    set_last_rom(path)
    log("native core start pid=#{pid} rom=#{path}")
    20.times do
      sleep(0.05)
      state = mirror_status["state"].to_s
      return true if state == "starting" || state == "ready"
      if state == "error"
        log("native core reported error #{mirror_status.inspect}")
        return false
      end
    end
    true
  rescue Exception => e
    log("native core start failed #{e.class}: #{e.message}")
    false
  end

  def self.mirror_frame_path
    File.join(MIRROR_RUNTIME, "frame.png")
  end

  def self.current_mirror_frame_path
    path = mirror_status["frame_path"].to_s
    return absolute_path(path) if !path.empty?
    mirror_frame_path
  rescue
    mirror_frame_path
  end

  def self.mirror_command_path
    File.join(MIRROR_RUNTIME, "commands.txt")
  end

  def self.mirror_status_path
    File.join(MIRROR_RUNTIME, "status.txt")
  end

  def self.mirror_available?
    File.file?(mirror_helper_path)
  end

  def self.mirror_host_pid
    Process.pid.to_i
  rescue
    0
  end

  def self.mirror_logical_size
    if defined?(Graphics)
      [Graphics.width.to_i, Graphics.height.to_i]
    else
      [0, 0]
    end
  rescue
    [0, 0]
  end

  def self.mirror_embed_enabled?
    config["mirror_embed"] != false
  end

  def self.mirror_lock_aspect?
    config["mirror_lock_aspect"] != false
  end

  def self.start_mirror(path, rect = nil)
    ensure_directories
    path = absolute_path(path)
    emulator = detected_mirror_emulator_path
    if !File.file?(path)
      pbMessage(_INTL("ROM file not found.")) if defined?(pbMessage)
      return false
    end
    if !emulator
      pbMessage(_INTL("No GBA emulator was found.")) if defined?(pbMessage)
      return false
    end
    if !mirror_available?
      pbMessage(_INTL("The in-game mirror helper is missing.")) if defined?(pbMessage)
      return false
    end
    ensure_mgba_sdl_config(emulator)
    stop_mirror
    legacy_frame_path = File.join(MIRROR_RUNTIME, "frame.bmp")
    Dir[File.join(MIRROR_RUNTIME, "frame.*.png")].each { |file| File.delete(file) rescue nil }
    [mirror_frame_path, legacy_frame_path, mirror_status_path, mirror_command_path].each do |file|
      File.delete(file) if File.exist?(file)
    rescue
      nil
    end
    File.open(mirror_command_path, "wb") { |f| f.write("") }
    args = [
      mirror_helper_path,
      "--emulator", emulator,
      "--rom", path,
      "--frame", mirror_frame_path,
      "--command", mirror_command_path,
      "--status", mirror_status_path,
      "--width", "240",
      "--height", "160",
      "--fps", mirror_fps.to_s,
      "--volume", mgba_volume_value.to_s,
      "--volume-percent", emulator_volume_percent.to_s
    ]
    if mirror_embed_enabled?
      logical_w, logical_h = mirror_logical_size
      rect ||= [0, 0, 240, 160]
      args.concat([
        "--embed",
        "--host-pid", mirror_host_pid.to_s,
        "--rect", rect[0].to_i.to_s, rect[1].to_i.to_s, rect[2].to_i.to_s, rect[3].to_i.to_s,
        "--logical-width", logical_w.to_s,
        "--logical-height", logical_h.to_s
      ])
      args << (mirror_lock_aspect? ? "--lock-aspect" : "--free-aspect")
    else
      args << "--no-embed"
    end
    pid = Process.spawn(*args)
    Process.detach(pid) if Process.respond_to?(:detach)
    @mirror_pid = pid
    @mirror_rom = path
    set_last_rom(path)
    log("mirror start pid=#{pid} rom=#{path}")
    true
  rescue Exception => e
    log("mirror start failed #{e.class}: #{e.message}")
    pbMessage(intl("The in-game mirror could not start.\n{1}", e.message)) if defined?(pbMessage)
    false
  end

  def self.stop_mirror
    return false if !File.exist?(mirror_command_path)
    File.open(mirror_command_path, "ab") { |f| f.write("quit\n") }
    log("mirror stop requested")
    true
  rescue
    false
  end

  def self.send_mirror_button(button)
    return false if !File.exist?(mirror_command_path)
    File.open(mirror_command_path, "ab") { |f| f.write("tap #{button}\n") }
    true
  rescue
    false
  end

  def self.send_mirror_hold(button, milliseconds = 90)
    return false if !File.exist?(mirror_command_path)
    duration = [[milliseconds.to_i, 35].max, 500].min
    File.open(mirror_command_path, "ab") { |f| f.write("hold #{button} #{duration}\n") }
    true
  rescue
    false
  end

  def self.send_mirror_key_down(button)
    return false if !File.exist?(mirror_command_path)
    File.open(mirror_command_path, "ab") { |f| f.write("down #{button}\n") }
    true
  rescue
    false
  end

  def self.send_mirror_key_up(button)
    return false if !File.exist?(mirror_command_path)
    File.open(mirror_command_path, "ab") { |f| f.write("up #{button}\n") }
    true
  rescue
    false
  end

  def self.send_mirror_pause(paused = true)
    return false if !File.exist?(mirror_command_path)
    File.open(mirror_command_path, "ab") { |f| f.write(paused ? "pause\n" : "resume\n") }
    true
  rescue
    false
  end

  def self.send_mirror_volume(percent)
    return false if !File.exist?(mirror_command_path)
    volume = [[percent.to_i, 0].max, 100].min
    File.open(mirror_command_path, "ab") { |f| f.write("volume #{volume}\n") }
    true
  rescue
    false
  end

  def self.send_mirror_rect(rect)
    return false if !File.exist?(mirror_command_path)
    logical_w, logical_h = mirror_logical_size
    x, y, w, h = rect
    line = "rect #{x.to_i} #{y.to_i} #{w.to_i} #{h.to_i} #{logical_w.to_i} #{logical_h.to_i}\n"
    File.open(mirror_command_path, "ab") { |f| f.write(line) }
    true
  rescue
    false
  end

  def self.ensure_mgba_sdl_config(emulator)
    return false if emulator.to_s.empty?
    return false unless File.basename(emulator).downcase.include?("mgba")
    config_path = File.join(File.dirname(absolute_path(emulator)), "config.ini")
    lines = File.exist?(config_path) ? File.readlines(config_path) : []
    output = []
    in_section = false
    seen_section = false
    seen_keys = {}
    lines.each do |line|
      stripped = line.strip
      if stripped.start_with?("[") && stripped.end_with?("]")
        if in_section
          MGBA_SDL_KEY_CONFIG.each do |key, value|
            output << "#{key}=#{value}\n" unless seen_keys[key]
          end
        end
        in_section = stripped.casecmp("[gba.input.SDLB]").zero?
        seen_section ||= in_section
        seen_keys = {} if in_section
        output << line
        next
      end
      if in_section && stripped.include?("=")
        key = stripped.split("=", 2)[0]
        if MGBA_SDL_KEY_CONFIG.key?(key)
          output << "#{key}=#{MGBA_SDL_KEY_CONFIG[key]}\n"
          seen_keys[key] = true
          next
        end
      end
      output << line
    end
    if in_section
      MGBA_SDL_KEY_CONFIG.each do |key, value|
        output << "#{key}=#{value}\n" unless seen_keys[key]
      end
    elsif !seen_section
      output << "\n" unless output.empty? || output[-1].to_s.end_with?("\n")
      output << "[gba.input.SDLB]\n"
      MGBA_SDL_KEY_CONFIG.each { |key, value| output << "#{key}=#{value}\n" }
    end
    new_text = output.join
    return true if File.exist?(config_path) && File.read(config_path) == new_text
    File.open(config_path, "wb") { |f| f.write(new_text) }
    true
  rescue Exception => e
    log("mGBA SDL config repair failed #{e.class}: #{e.message}")
    false
  end

  def self.mirror_status
    return {} unless File.exist?(mirror_status_path)
    status = {}
    File.read(mirror_status_path).each_line do |line|
      key, value = line.strip.split("=", 2)
      status[key] = value if key && value
    end
    status
  rescue
    {}
  end

  def self.mirror_running?
    state = mirror_status["state"].to_s
    state == "ready"
  end
end
