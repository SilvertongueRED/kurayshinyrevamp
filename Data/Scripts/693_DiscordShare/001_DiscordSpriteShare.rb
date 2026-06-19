#===============================================================================
# Discord Sprite Share
#-------------------------------------------------------------------------------
# Adds a "Share to Discord" action to the Pokedex SPRITES page (the page where
# you cycle a fusion's alternate sprites, Page 3 / @page == 3).
#
# While viewing a sprite, press the RUN / ACTION button to upload the currently
# displayed sprite straight to the KIF Discord channel:
#     https://discord.com/channels/1121345297352753243/1319822654252912702
#
# The post is labelled with the two Pokemon that make up the fusion (head/body)
# and, if you confirm it, an "AI-generated" tag (for sprites made with our AI
# model). Others can drag the posted .png straight into their own game.
#
# SETUP (one time, per machine):
#   1) In Discord, on that channel: Edit Channel -> Integrations -> Webhooks ->
#      New Webhook -> Copy Webhook URL.
#   2) Paste that URL into a plain-text file at the game root:
#         CustomSpriteImport/discord_webhook.txt
#      (or use the in-game prompt the first time you press Share).
#   The webhook URL is stored ONLY in that local file, which is git-ignored so
#   it is never pushed to the public repo.
#
# Implementation notes:
#   * Uses the engine's own HTTPLite client (the same HTTPS client that already
#     downloads sprites) to POST multipart/form-data to the Discord webhook.
#     No external tools, no console window.
#   * Hooks PokemonPokedexInfo_Scene#pbUpdate (polled every frame by the sprites
#     page loop) and only acts when @page == 3, so it never interferes with the
#     rest of the Pokedex.
#===============================================================================
module DiscordSpriteShare
  WEBHOOK_FILE = "CustomSpriteImport/discord_webhook.txt"
  CHANNEL_URL  = "https://discord.com/channels/1121345297352753243/1319822654252912702"
  WEBHOOK_RE   = %r{\Ahttps://([a-z0-9.-]+\.)?discord(app)?\.com/api/webhooks/\d+/\S+\z}i

  module_function

  #---------------------------------------------------------------------------
  # Webhook URL handling (local, never committed).
  #---------------------------------------------------------------------------
  def webhook_url
    return nil unless File.file?(WEBHOOK_FILE)
    u = (File.read(WEBHOOK_FILE) rescue nil)
    return nil if !u
    u = u.strip
    return nil if u.empty?
    return nil unless u =~ WEBHOOK_RE
    u
  end

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

  def json_payload(content)
    '{"content":"' + json_escape(content) + '","allowed_mentions":{"parse":[]}}'
  end

  # POSTs the file at file_path to the webhook. Returns [ok?, status, body].
  def post_sprite(url, file_path, upload_name, content)
    data = File.binread(file_path)
    boundary = "----KIFShare#{Time.now.to_i}#{rand(1_000_000)}"
    nl = "\r\n"
    body = "".b
    body << ("--#{boundary}#{nl}").b
    body << ("Content-Disposition: form-data; name=\"payload_json\"#{nl}").b
    body << ("Content-Type: application/json#{nl}#{nl}").b
    body << json_payload(content).b
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
      "User-Agent"     => "KIF-Fork-SpriteShare/1.0"
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
  # Main entry, called from the sprites page.
  #---------------------------------------------------------------------------
  def share_sprite(sprite_path, species)
    if !sprite_path || !File.file?(sprite_path)
      pbMessage(_INTL("Couldn't find the sprite file to share."))
      return
    end

    url = webhook_url
    unless url
      if pbConfirmMessage(_INTL("No Discord webhook is set up yet.\n\nCreate one on the KIF sprite channel, then paste it into\n{1}\nor enter it now. Enter it now?", WEBHOOK_FILE))
        url = set_webhook_interactive
      end
      return unless url
    end

    label, upload_name = build_label(species, sprite_path)
    ai = pbConfirmMessage(_INTL("Is this an AI-generated sprite (made with our AI model)?"))
    content = label.dup
    content << "\n\u{1F916} AI-generated sprite" if ai

    preview = content.gsub("**", "")
    return unless pbConfirmMessage(_INTL("Post this sprite to the KIF Discord?\n\n{1}", preview))

    ok, status, resp = post_sprite(url, sprite_path, upload_name, content)
    if ok
      pbMessage(_INTL("Posted to the KIF Discord!"))
    elsif status == 401 || status == 403 || status == 404
      pbMessage(_INTL("Discord rejected the webhook (status {1}).\nThe URL may be wrong or the webhook was deleted.\nUpdate {2} and try again.", status.to_s, WEBHOOK_FILE))
    else
      pbMessage(_INTL("Couldn't post to Discord (status {1}).\nCheck your internet connection and the webhook URL.", status.to_s))
      echoln("[DiscordShare] response body: #{resp}")
    end
  end

  # Pull current sprite + species out of the pokedex scene and share it.
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
# Hook the Pokedex sprites page (Page 3). pbUpdate is polled every frame by both
# the page-navigation loop and the alt-cycling loop, so this catches the RUN /
# ACTION button on the sprites page without touching any other behaviour.
#===============================================================================
if defined?(PokemonPokedexInfo_Scene)
  class PokemonPokedexInfo_Scene
    unless method_defined?(:_dss_orig_pbUpdate)
      alias_method :_dss_orig_pbUpdate, :pbUpdate
      def pbUpdate(*args)
        _dss_orig_pbUpdate(*args)
        begin
          if @page == 3 && !@_dss_busy && Input.trigger?(Input::ACTION)
            @_dss_busy = true
            DiscordSpriteShare.share_from_scene(self)
            @_dss_busy = false
          end
        rescue => e
          @_dss_busy = false
          echoln("[DiscordShare] #{e.class}: #{e.message}")
        end
        true
      end
    end

    # Add an on-screen hint to the sprites page (only if the sprites-page add-on
    # provides showSpriteCredits to hang it on).
    if method_defined?(:showSpriteCredits) && !method_defined?(:_dss_orig_showSpriteCredits)
      alias_method :_dss_orig_showSpriteCredits, :showSpriteCredits
      def showSpriteCredits(filename, generated_sprite = false)
        _dss_orig_showSpriteCredits(filename, generated_sprite)
        begin
          return if !@creditsOverlay
          hint = _INTL("Press RUN: Share to Discord")
          pbDrawTextPositions(@creditsOverlay,
            [[hint, 8, 2, 0, Color.new(248, 248, 248), Color.new(104, 104, 104)]])
        rescue
        end
      end
    end
  end
end
