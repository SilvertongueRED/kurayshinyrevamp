#===============================================================================
# Discord Identity (shared with the Multiplayer Discord link)
#-------------------------------------------------------------------------------
# The sprite-share feature stamps each Discord post with the player's real
# Discord display name. That name can only come from Discord's OAuth, which is
# handled by the KIFM multiplayer server (it holds the app secret). So instead of
# a second login, we REUSE the link the player already made from the Multiplayer
# menu ("Link Discord Account").
#
# The MP client (MultiplayerClient) receives "DISCORD_NAME:<name>" from the
# server on every authenticated connect and stores it in @discord_display_name.
# 003_Client.rb is hooked to call DiscordIdentity.remember whenever that arrives,
# so the name is persisted to disk and available to sprite-share even offline /
# in later sessions. refresh_from_mp also grabs it live if the client is up.
#
# Nothing here performs any login itself; it only mirrors the existing MP link.
#===============================================================================
module DiscordIdentity
  STORE_FILE = "CustomSpriteImport/discord_identity.txt"  # per-machine, git-ignored

  module_function

  # Persist the linked Discord display name (+ optional snowflake id).
  def remember(name, id = nil)
    name = name.to_s.strip
    return if name.empty?
    begin
      Dir.mkdir("CustomSpriteImport") unless File.directory?("CustomSpriteImport")
      File.open(STORE_FILE, "w") do |f|
        f.puts "name=#{name}"
        f.puts "id=#{id.to_s.strip}" unless id.to_s.strip.empty?
      end
    rescue
    end
  end

  # If the MP client is connected and knows the name, mirror it to disk.
  def refresh_from_mp
    return unless defined?(MultiplayerClient)
    n = (MultiplayerClient.instance_variable_get(:@discord_display_name) rescue nil)
    remember(n) if n && !n.to_s.strip.empty?
  rescue
  end

  def stored
    return {} unless File.file?(STORE_FILE)
    h = {}
    (File.readlines(STORE_FILE) rescue []).each do |line|
      k, v = line.strip.split("=", 2)
      h[k] = v if k && v
    end
    h
  rescue
    {}
  end

  # Best Discord display name, or nil if the player hasn't linked.
  def display_name
    refresh_from_mp
    n = stored["name"]
    (n && !n.strip.empty?) ? n : nil
  end

  def linked?
    !display_name.nil?
  end
end
