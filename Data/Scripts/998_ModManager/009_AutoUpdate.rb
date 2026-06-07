#==============================================================================
# Mod Manager - Auto-Update On Launch                      [009_AutoUpdate.rb]
#==============================================================================
# On launch, checks every installed managed mod (from the KIF-Mods/mods repo)
# against its remote version. Any mod whose repo copy is newer is downloaded in
# place using the SAME tested path the Mod Browser uses (GitHub.download_mod),
# then the player is told which mods updated and the game restarts hands-free to
# load the new files.
#
# Safety:
#   * Toggle in the Mod Manager footer ("Auto-Upd: ON/OFF"). Default ON.
#     Persisted to mod_autoupdate.txt in the game folder.
#   * Runs at most once per launch (at the load screen, before you pick a save).
#   * Offline-safe: if the repo can't be reached it silently skips and you boot
#     normally. Every path is rescued so it can never block or crash startup.
#   * Only touches managed mods from KIF-Mods/mods. Big external installs
#     (Multiplayer, NPT) live in other repos and keep their own update flows.
#   * Dev mods (ModDev/) are never auto-updated.
#==============================================================================

module ModAutoUpdate
  CONFIG_BASENAME = "mod_autoupdate.txt"
  @ran = false

  module_function

  def config_path
    File.join(Dir.pwd, CONFIG_BASENAME)
  rescue
    CONFIG_BASENAME
  end

  # Default ON: only OFF when the file explicitly says "0".
  def enabled?
    p = config_path
    return true unless File.exist?(p)
    File.read(p).strip != "0"
  rescue
    true
  end

  def set_enabled(on)
    File.open(config_path, "w") { |f| f.write(on ? "1" : "0") }
    true
  rescue
    false
  end

  def github_module
    return ModManager::GitHub if defined?(ModManager::GitHub)
    return GitHub if defined?(GitHub)
    nil
  rescue
    nil
  end

  def remote_version_for(folder)
    gh = github_module
    return nil unless gh && defined?(gh::RAW_BASE)
    url = "#{gh::RAW_BASE}#{folder}/mod.json"
    raw = (pbDownloadToString(url) rescue nil)
    return :neterr if raw.nil? || raw.to_s.empty?
    json = (ModManager::JSON.parse(raw) rescue nil)
    return nil unless json.is_a?(Hash)
    v = json["version"]
    v.nil? ? nil : v.to_s
  rescue
    nil
  end

  # Returns [{:name, :from, :to}, ...] for mods that were updated.
  def check_and_update
    updated = []
    return updated unless defined?(ModManager) && ModManager.respond_to?(:registry)
    gh = github_module
    return updated unless gh && gh.respond_to?(:download_mod)

    reg = (ModManager.registry rescue {})
    any_ok = false
    reg.each_value do |info|
      next unless info && info.folder_path && !info.folder_path.to_s.empty?
      next if (info.is_dev? rescue false)
      folder = File.basename(info.folder_path.to_s)
      next if folder.nil? || folder.empty?

      remote = remote_version_for(folder)
      if remote == :neterr
        # Repo unreachable. If nothing has fetched yet, assume offline and bail.
        break unless any_ok
        next
      end
      any_ok = true
      next unless remote
      next unless (ModManager.compare_versions(remote, info.version.to_s) rescue 0) > 0

      if gh.download_mod(folder)
        updated << { :name => (info.name rescue folder), :from => info.version.to_s, :to => remote }
        echoln("[ModAutoUpdate] Updated #{info.name} #{info.version} -> #{remote}") rescue nil
      end
    end
    updated
  rescue => e
    echoln("[ModAutoUpdate] check failed: #{e.class}: #{e.message}") rescue nil
    []
  end

  def restart_game
    exe = ["Game.exe", "Game-z.exe", "Game-compatibility.exe"].find { |e| File.file?(e) }
    if exe
      begin
        Process.spawn(File.join(Dir.pwd, exe))
      rescue
        (system("start \"\" \"#{exe}\"") rescue nil)
      end
    end
    exit
  rescue
    exit
  end

  def run_once
    return if @ran
    @ran = true
    return unless enabled?
    return unless defined?(ModManager)

    updated = check_and_update
    return if updated.nil? || updated.empty?

    list = updated.map { |u| "- #{u[:name]}  (#{u[:from]} -> #{u[:to]})" }.join("\n")
    (pbMessage(_INTL("Mod update{1} installed:\n{2}\n\nThe game will now restart to apply the changes.",
                     (updated.length == 1 ? "" : "s"), list)) rescue nil)
    restart_game
  rescue => e
    echoln("[ModAutoUpdate] run_once failed: #{e.class}: #{e.message}") rescue nil
    nil
  end
end

#------------------------------------------------------------------------------
# Hook: run the check at the load/title screen (loads after 007_TitleHook so the
# alias chain is 009 -> 007 -> 659/MultiSaves -> original).
#------------------------------------------------------------------------------
if defined?(PokemonLoadScreen)
  class PokemonLoadScreen
    unless method_defined?(:_mod_autoupd_pbStartLoadScreen)
      alias _mod_autoupd_pbStartLoadScreen pbStartLoadScreen
      def pbStartLoadScreen
        ModAutoUpdate.run_once rescue nil
        _mod_autoupd_pbStartLoadScreen
      end
    end
  end
end
