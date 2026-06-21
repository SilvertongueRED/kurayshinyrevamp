#===============================================================================
# Discord Sprite Share  (shared-webhook edition)
#-------------------------------------------------------------------------------
# Adds "Share this sprite to Discord" to the unified sprite-options menu
# (Pokedex Sprites page / picker -> USE button -> pbSpriteOptionsMenu, see
# 694_AISprites/007_AIGen_PickerActions.rb). One button press uploads the
# currently displayed sprite straight to the KIF sprite channel:
#     https://discord.com/channels/1121345297352753243/1398834563203072090
#
# WHY A WEBHOOK (and not "log in with Discord"):
#   Discord's API does NOT allow posting a message with a player's OAuth login
#   token -- only a webhook or a bot can post. A webhook needs ZERO permissions
#   from the people posting through it, so a single shared webhook lets every
#   player share with no setup, no login, fully from a controller.
#
# ------------------------------------------------------------------------------
# WHERE THE WEBHOOK COMES FROM (admin sets it ONCE; players do NOTHING):
#
#   The game reads the webhook from the fork's own repo, so you ROTATE IT THE
#   SAME WAY YOU PUSH ANY OTHER CONFIG -- edit one file, push, done:
#
#       Data/sprite_share_webhook.txt   (tracked in the repo, NOT git-ignored)
#
#   It is fetched live from:
#       REMOTE_WEBHOOK_SRC (raw.githubusercontent ... /main/Data/sprite_share_webhook.txt)
#   and cached locally (6 h TTL) so rotating the file rolls out to everyone
#   without a game update. The same shipped file is also read locally, so the
#   feature still works offline / on first run.
#
#   ONE-TIME setup:
#     1) Make the webhook (needs Manage-Webhooks on the channel, i.e. you/admin):
#          Discord -> the sprite channel -> Edit Channel -> Integrations ->
#          Webhooks -> New Webhook -> name it -> Copy URL.
#     2) Put it in  Data/sprite_share_webhook.txt  and push.
#        STRONGLY RECOMMENDED: base64-encode it first (the game auto-decodes).
#        A raw webhook URL sitting in a public repo is detected by GitHub/Discord
#        secret-scanners and auto-revoked; base64 dodges that. Make the value:
#            ruby   -> require "base64"; puts Base64.strict_encode64(ENV["W"])
#            bash    -> printf %s "<webhook-url>" | base64 -w0
#        Paste the base64 string as the only meaningful line in the file.
#     To rotate later: replace the webhook, regenerate base64, push. (On a 401/
#     403/404 the stale cache is auto-dropped so clients re-fetch immediately.)
#
#   Alternatives (any ONE overrides the repo file; see resolution order below):
#     * Paste a webhook straight into SHARED_WEBHOOK below (ships in the files).
#     * Point REMOTE_WEBHOOK_SRC / CustomSpriteImport/sprite_share_src.txt /
#       Settings::SPRITE_SHARE_WEBHOOK_SRC_URL at a secret Gist instead of the repo.
#     * Old per-machine file CustomSpriteImport/discord_webhook.txt still works.
#
# Implementation: uses the engine's own HTTPLite HTTPS client (the same one that
# downloads sprites) -- no external tools, no console window.
#===============================================================================
module DiscordSpriteShare
  # --- Target channel (display only; the webhook itself decides the real channel)
  CHANNEL_URL = "https://discord.com/channels/1121345297352753243/1398834563203072090"

  # === ADMIN CONFIG ===========================================================
  # Direct shared webhook (optional). Leave "" to use the repo file / remote src.
  SHARED_WEBHOOK     = ""
  # Live source the game fetches the webhook from. Defaults to the fork's repo
  # file so you rotate via a normal git push. Point it at a secret Gist RAW url
  # instead if you'd rather keep it out of the repo. Leave "" to disable fetch.
  REMOTE_WEBHOOK_SRC = "https://raw.githubusercontent.com/SilvertongueRED/kurayshinyrevamp/main/Data/sprite_share_webhook.txt"
  # ============================================================================

  # Files.
  REPO_WEBHOOK_FILE = "Data/sprite_share_webhook.txt"                 # shipped in repo (tracked); offline fallback
  SHARED_CACHE_FILE = "CustomSpriteImport/discord_webhook_shared.txt" # fetched-webhook cache (git-ignored)
  SRC_OVERRIDE_FILE = "CustomSpriteImport/sprite_share_src.txt"       # optional local source-url override (git-ignored)
  WEBHOOK_FILE      = "CustomSpriteImport/discord_webhook.txt"        # legacy per-machine webhook (git-ignored)

  CACHE_TTL_SECONDS = 6 * 3600   # re-check the remote source at most this often

  WEBHOOK_RE   = %r{\Ahttps://([a-z0-9.-]+\.)?discord(app)?\.com/api/webhooks/\d+/\S+\z}i
  WEBHOOK_SCAN = %r{https://(?:[a-z0-9.-]+\.)?discord(?:app)?\.com/api/webhooks/\d+/[A-Za-z0-9_.\-]+}i

  module_function

  #---------------------------------------------------------------------------
  # Webhook resolution.  Priority:
  #   1) SHARED_WEBHOOK constant (direct)
  #   2) live remote source (repo file by default) + local cache
  #   3) shipped in-repo file Data/sprite_share_webhook.txt (offline / first run)
  #   4) legacy per-machine CustomSpriteImport/discord_webhook.txt
  # Returns a valid webhook URL string, or nil.
  #---------------------------------------------------------------------------
  def webhook_url
    # 1) direct constant
    w = clean_webhook(SHARED_WEBHOOK)
    return w if w

    # 2) remote source (+ cache)
    src = remote_source
    if src && !src.empty?
      cached = read_cache_if_fresh
      return cached if cached
      fetched = fetch_remote_webhook(src)
      return fetched if fetched
      stale = read_cache_any           # remote failed -> use stale cache if present
      return stale if stale
    else
      cached = read_cache_any          # no remote now, but a prior cache may exist
      return cached if cached
    end

    # 3) shipped in-repo file (works offline / before first fetch)
    w = repo_webhook
    return w if w

    # 4) legacy per-machine file
    legacy_webhook
  end

  # Resolve the remote source URL: (local override file) > (Settings constant) > (module constant).
  def remote_source
    if File.file?(SRC_OVERRIDE_FILE)
      s = (File.read(SRC_OVERRIDE_FILE).strip rescue "")
      return s unless s.empty?
    end
    if defined?(Settings) && defined?(Settings::SPRITE_SHARE_WEBHOOK_SRC_URL)
      s = Settings::SPRITE_SHARE_WEBHOOK_SRC_URL.to_s.strip
      return s unless s.empty?
    end
    REMOTE_WEBHOOK_SRC.to_s.strip
  end

  def clean_webhook(str)
    s = str.to_s.strip
    return nil if s.empty?
    return s if s =~ WEBHOOK_RE
    nil
  end

  # Pull a webhook URL out of arbitrary text: direct, embedded (JSON/quoted), or base64.
  # Pull a webhook URL out of arbitrary text: direct, embedded (JSON/quoted), or
  # base64. A config file may carry "#" comment lines / blank lines alongside the
  # value. base64 is decoded only over the JOINED non-comment content, never over
  # individual wrapped lines (a partial decode could yield a truncated webhook).
  def extract_webhook(text)
    return nil if text.nil?
    raw = text.to_s
    # 1) whole blob: direct URL or one embedded in JSON / quotes
    w = scan_plain(raw); return w if w
    # 2) a raw URL on its own line, ignoring "#" comments and blanks
    raw.each_line do |line|
      l = line.strip
      next if l.empty? || l.start_with?("#")
      w = scan_plain(l); return w if w
    end
    # 3) base64 over the joined non-comment content (handles single- or multi-line
    #    base64, with or without comment lines above it)
    body = raw.each_line.reject { |l| t = l.strip; t.empty? || t.start_with?("#") }.join
    scan_b64(body)
  end

  # direct webhook, or one embedded in JSON / quotes
  def scan_plain(str)
    s = str.to_s.strip
    return s if s =~ WEBHOOK_RE
    s[WEBHOOK_SCAN]
  end

  # base64-decode then look for a webhook (core String#unpack; no `require`,
  # which mkxp-z's embedded Ruby can choke on)
  def scan_b64(str)
    dec = (str.to_s.gsub(/\s+/, "").unpack("m")[0] rescue nil)
    return nil unless dec
    scan_plain(dec.to_s)
  end

  def repo_webhook
    return nil unless File.file?(REPO_WEBHOOK_FILE)
    extract_webhook((File.read(REPO_WEBHOOK_FILE) rescue nil))
  end

  def read_cache_if_fresh
    return nil unless File.file?(SHARED_CACHE_FILE)
    begin
      age = Time.now - File.mtime(SHARED_CACHE_FILE)
      return nil if age > CACHE_TTL_SECONDS
    rescue
      # if mtime is unreadable, fall through and use the cache
    end
    extract_webhook((File.read(SHARED_CACHE_FILE) rescue nil))
  end

  def read_cache_any
    return nil unless File.file?(SHARED_CACHE_FILE)
    extract_webhook((File.read(SHARED_CACHE_FILE) rescue nil))
  end

  def write_cache(url)
    begin
      Dir.mkdir("CustomSpriteImport") unless File.directory?("CustomSpriteImport")
      File.open(SHARED_CACHE_FILE, "w") { |f| f.write(url) }
    rescue => e
      echoln("[DiscordShare] cache write failed: #{e.message}")
    end
  end

  def fetch_remote_webhook(src)
    return nil unless src =~ %r{\Ahttps?://}i
    begin
      headers = { "User-Agent" => "KIF-Fork-SpriteShare/2.0", "Pragma" => "no-cache" }
      ret = HTTPLite.get(src, headers)
      return nil unless ret.is_a?(Hash) && ret[:status] == 200
      url = extract_webhook(ret[:body])
      return nil unless url
      write_cache(url)
      url
    rescue => e
      echoln("[DiscordShare] remote source fetch failed: #{e.class}: #{e.message}")
      nil
    end
  end

  def legacy_webhook
    return nil unless File.file?(WEBHOOK_FILE)
    clean_webhook((File.read(WEBHOOK_FILE) rescue nil))
  end

  #---------------------------------------------------------------------------
  # Admin fallback: paste a webhook by hand (stored in the legacy per-machine file).
  #---------------------------------------------------------------------------
  def set_webhook_interactive
    u = (pbEnterText(_INTL("Paste the Discord webhook URL\n(Channel > Integrations > Webhooks):"), 0, 250, "") rescue "")
    u = (u || "").strip
    return nil if u.empty?
    unless u =~ WEBHOOK_RE
      pbMessage(_INTL("That doesn't look like a Discord webhook URL.\nIt should start with https://discord.com/api/webhooks/"))
      return nil
    end
    begin
      Dir.mkdir("CustomSpriteImport") unless File.directory?("CustomSpriteImport")
      File.open(WEBHOOK_FILE, "w") { |f| f.write(u) }
      pbMessage(_INTL("Saved. The webhook is stored only on this PC and is not shared in the game files."))
    rescue
      pbMessage(_INTL("Couldn't save the webhook file. You can paste the URL into\n{1}\nmanually instead.", WEBHOOK_FILE))
      return nil
    end
    u
  end

  #---------------------------------------------------------------------------
  # Label / names.
  #---------------------------------------------------------------------------
  def species_name(id)
    return "?" if id.nil?
    sp = (GameData::Species.try_get(id) rescue nil)
    return sp ? sp.real_name : id.to_s
  end

  # Returns [content_string, upload_filename] for the given species + sprite path.
  def build_label(species, path)
    dex = (getDexNumberForSpecies(species) rescue 0)
    if dex && dex > NB_POKEMON
      body_id = (getBodyID(species) rescue nil)
      head_id = (getHeadID(species, body_id) rescue nil)
      head    = species_name(head_id)
      body    = species_name(body_id)
      upload  = (head_id && body_id) ? "#{head_id}.#{body_id}.png" : File.basename(path)
      label   = _INTL("**{1}** (head) / **{2}** (body) fusion", head, body)
    else
      label  = _INTL("**{1}**", species_name(dex))
      upload = File.basename(path)
    end
    [label, upload]
  end

  #---------------------------------------------------------------------------
  # JSON + multipart helpers.
  #---------------------------------------------------------------------------
  def json_escape(str)
    str.to_s.gsub(/[\\"]/) { |m| "\\#{m}" }.gsub("\n", "\\n").gsub("\r", "").gsub("\t", "\\t")
  end

  def json_payload(content, username = nil)
    parts = ['"content":"' + json_escape(content) + '"']
    u = sanitize_username(username)
    parts << '"username":"' + json_escape(u) + '"' if u
    parts << '"allowed_mentions":{"parse":[]}'
    "{" + parts.join(",") + "}"
  end

  # Discord webhook display-name override: 1-80 chars, can't be "clyde"/"discord".
  def sanitize_username(name)
    s = name.to_s.strip
    return nil if s.empty?
    s = s[0, 80]
    s = "#{s}." if %w[clyde discord].include?(s.downcase)
    s
  end

  # POSTs the file at file_path to the webhook. Returns [ok?, status, body].
  def post_sprite(url, file_path, upload_name, content, author = nil)
    data = File.binread(file_path)
    boundary = "----KIFShare#{Time.now.to_i}#{rand(1_000_000)}"
    nl = "\r\n"
    body = "".b
    body << ("--#{boundary}#{nl}").b
    body << ("Content-Disposition: form-data; name=\"payload_json\"#{nl}").b
    body << ("Content-Type: application/json#{nl}#{nl}").b
    body << json_payload(content, author).b
    body << nl.b
    body << ("--#{boundary}#{nl}").b
    body << ("Content-Disposition: form-data; name=\"files[0]\"; filename=\"#{upload_name}\"#{nl}").b
    body << ("Content-Type: image/png#{nl}#{nl}").b
    body << data
    body << nl.b
    body << ("--#{boundary}--#{nl}").b

    host = (url =~ %r{\Ahttps?://([^/]+)} ? $1 : "discord.com")
    headers = {
      "Host"           => host,
      "Content-Length" => body.bytesize.to_s,
      "User-Agent"     => "KIF-Fork-SpriteShare/2.0"
    }
    ret = HTTPLite.post_body(url, body, "multipart/form-data; boundary=#{boundary}", headers)
    if ret.is_a?(Hash)
      status = ret[:status]
      ok = [200, 201, 204].include?(status)
      return [ok, status, ret[:body]]
    end
    [false, -1, ret.to_s]
  rescue => e
    echoln("[DiscordShare] post error: #{e.class}: #{e.message}")
    [false, -1, e.message]
  end

  #---------------------------------------------------------------------------
  # Main entry, called from the sprite-options menu.
  #---------------------------------------------------------------------------
  def share_sprite(sprite_path, species)
    if !sprite_path || !File.file?(sprite_path)
      pbMessage(_INTL("Couldn't find the sprite file to share."))
      return
    end

    url = webhook_url
    unless url
      # No shared webhook resolved. Players normally never reach this -- it means
      # an admin hasn't published the KIF channel webhook yet. Offer a paste.
      if pbConfirmMessage(_INTL("Sprite sharing isn't set up on this copy yet.\n\nAn admin needs to publish the KIF channel webhook (see the\nnotes in 693_DiscordShare). Enter a webhook URL now?"))
        url = set_webhook_interactive
      end
      return unless url
    end

    label, upload_name = build_label(species, sprite_path)
    ai = pbConfirmMessage(_INTL("Is this an AI-generated sprite (made with our AI model)?"))
    content = label.dup
    content << "\n\u{1F916} AI-generated sprite" if ai

    # Attribution: reuse the Discord account the player linked via the Multiplayer
    # menu, if any (mirrored by DiscordIdentity). Fall back to the in-game trainer
    # name so the post is always attributed to someone recognisable.
    (DiscordIdentity.refresh_from_mp rescue nil) if defined?(DiscordIdentity)
    discord_name = (defined?(DiscordIdentity) ? (DiscordIdentity.display_name rescue nil) : nil)
    author = discord_name || ($Trainer.name rescue nil)

    preview = content.gsub("**", "")
    as_line = author ? _INTL("\n\nPosting as: {1}", author) : ""
    hint    = discord_name ? "" : _INTL("\n(Link Discord in the Multiplayer menu to post under your Discord name.)")
    return unless pbConfirmMessage(_INTL("Post this sprite to the KIF Discord?\n\n{1}{2}{3}", preview, as_line, hint))

    ok, status, resp = post_sprite(url, sprite_path, upload_name, content, author)
    if ok
      pbMessage(_INTL("Posted to the KIF Discord!"))
    elsif status == 401 || status == 403 || status == 404
      # The shared webhook may have been rotated/deleted -> drop the stale cache
      # so the next share re-fetches a fresh one from the remote source.
      (File.delete(SHARED_CACHE_FILE) if File.file?(SHARED_CACHE_FILE)) rescue nil
      pbMessage(_INTL("Discord rejected the webhook (status {1}).\nIt may have been rotated. Try sharing again in a moment.", status.to_s))
    else
      pbMessage(_INTL("Couldn't post to Discord (status {1}).\nCheck your internet connection and try again.", status.to_s))
      echoln("[DiscordShare] response body: #{resp}")
    end
  end

  # Pull current sprite + species out of the pokedex/picker scene and share it.
  def share_from_scene(scene)
    avail = scene.instance_variable_get(:@available)
    return if !avail || avail.empty?
    sel = scene.instance_variable_get(:@selected_index) || 0
    sel = 0 if sel < 0 || sel >= avail.length
    path = avail[sel]
    species = scene.instance_variable_get(:@species)
    share_sprite(path, species)
  end
end

#===============================================================================
# Sharing to Discord is offered inside the unified "Use: Sprite options" menu
# (694_AISprites/007_AIGen_PickerActions.rb -> pbSpriteOptionsMenu, which calls
# DiscordSpriteShare.share_from_scene). Fully controller-driven: USE -> select
# "Share this sprite to Discord" -> confirm.
#===============================================================================
