#===============================================================================
# 694_AISprites - 003_AIGen_Backend.rb
# Client for the bundled on-device generation sidecar (localhost HTTP).
# Generation is ONLY ever triggered by explicit user action (a Generate button),
# never during sprite resolution, so battles never block on the model.
#===============================================================================
module AIGen
  module Backend
    module_function

    def base_url
      "http://#{AIGen::BACKEND_HOST}:#{AIGen::BACKEND_PORT}"
    end

    @available = nil

    # Is the local model sidecar up? Cached per-session; pass true to recheck.
    def available?(recheck = false)
      return @available if !recheck && !@available.nil?
      @available = begin
        hp = base_url + AIGen::HEALTH_PATH
        resp = HTTPLite.get(hp)
        ok = !!(resp && resp[:status] == 200)
        AIGen.log("health probe #{hp} -> status #{resp ? resp[:status] : 'nil'} (#{ok ? 'UP' : 'DOWN'})")
        ok
      rescue Exception => e
        # HTTPLite raises MKXPError, which subclasses Exception (NOT
        # StandardError), so a bare `rescue` misses it and the game crashes
        # whenever the sidecar is down. Catch broadly: this is just a probe.
        AIGen.log("health probe error: #{e.class}: #{e.message}")
        false
      end
      @available
    end

    def reset_availability
      @available = nil
    end

    # Raw PNG bytes for the fusion head_id(head)/body_id(body), or nil.
    def fetch(head_id, body_id, seed = nil)
      unless AIGen.enabled?
        AIGen.log("fetch #{head_id}.#{body_id} SKIPPED: AIGen disabled in options")
        return nil
      end
      unless available?
        AIGen.log("fetch #{head_id}.#{body_id} SKIPPED: sidecar not reachable at #{base_url}#{AIGen::HEALTH_PATH}")
        return nil
      end
      url = base_url + AIGen::GENERATE_PATH + "?head=#{head_id}&body=#{body_id}"
      url += "&seed=#{seed}" if seed
      AIGen.log("fetch GET #{url}")
      begin
        resp = HTTPLite.get(url)
        if resp && resp[:status] == 200 && resp[:body] && !resp[:body].empty?
          AIGen.log("fetch OK #{head_id}.#{body_id}: #{resp[:body].bytesize} bytes")
          return resp[:body]
        end
        AIGen.log("generate failed (status #{resp ? resp[:status] : 'nil'}, body #{(resp && resp[:body]) ? resp[:body].bytesize : 0} bytes) for #{head_id}.#{body_id}")
        nil
      rescue Exception => e
        AIGen.log("generate error: #{e.class}: #{e.message}")
        nil
      end
    end

    # Raw PNG bytes for a TRIPLE fusion s1(head)/s2(body)/s3(third), or nil.
    def fetch_triple(s1, s2, s3, seed = nil)
      unless AIGen.enabled?
        AIGen.log("fetch_triple #{s1}.#{s2}.#{s3} SKIPPED: AIGen disabled in options")
        return nil
      end
      unless available?
        AIGen.log("fetch_triple #{s1}.#{s2}.#{s3} SKIPPED: sidecar not reachable at #{base_url}#{AIGen::HEALTH_PATH}")
        return nil
      end
      url = base_url + AIGen::GENERATE_PATH + "?head=#{s1}&body=#{s2}&third=#{s3}"
      url += "&seed=#{seed}" if seed
      AIGen.log("fetch_triple GET #{url}")
      begin
        resp = HTTPLite.get(url)
        if resp && resp[:status] == 200 && resp[:body] && !resp[:body].empty?
          AIGen.log("fetch_triple OK #{s1}.#{s2}.#{s3}: #{resp[:body].bytesize} bytes")
          return resp[:body]
        end
        AIGen.log("triple generate failed (status #{resp ? resp[:status] : 'nil'}, body #{(resp && resp[:body]) ? resp[:body].bytesize : 0} bytes) for #{s1}.#{s2}.#{s3}")
        nil
      rescue Exception => e
        AIGen.log("triple generate error: #{e.class}: #{e.message}")
        nil
      end
    end
  end

  #-- Placeholder rejection --------------------------------------------------
  # Reject the old dev stub (and any flat placeholder) so it can never be served
  # as a real fusion sprite. The stub is a near-uniform filled disc: one color
  # over ~90%+ of the opaque pixels, only a few distinct colors. Real model
  # output has shading/outlines and many colors. On ANY detector error we keep
  # the file -- never block a genuine sprite on a faulty probe.
  PLACEHOLDER_DOMINANT_FRAC = 0.85
  PLACEHOLDER_MAX_COLORS    = 12

  def self.looks_like_placeholder?(path)
    real = ((pbResolveBitmap(path) rescue nil) || path)
    real = real + ".png" unless real.to_s.downcase.end_with?(".png")
    return false unless (File.exist?(real) rescue false)
    bmp = (Bitmap.new(real) rescue nil)
    return false unless bmp
    begin
      w = bmp.width; h = bmp.height
      return false if w <= 0 || h <= 0
      step_x = [w / 24, 1].max
      step_y = [h / 24, 1].max
      counts = Hash.new(0)
      opaque = 0
      y = 0
      while y < h
        x = 0
        while x < w
          c = (bmp.get_pixel(x, y) rescue nil)
          if c && c.alpha > 8
            counts[[(c.red.to_i >> 3), (c.green.to_i >> 3), (c.blue.to_i >> 3)]] += 1
            opaque += 1
          end
          x += step_x
        end
        y += step_y
      end
      return false if opaque < 16
      frac = counts.values.max.to_f / opaque
      decision = (frac >= PLACEHOLDER_DOMINANT_FRAC && counts.size <= PLACEHOLDER_MAX_COLORS)
      AIGen.log("placeholder check #{path}: opaque=#{opaque} colors=#{counts.size} dominant=#{(frac * 100).round(1)}% -> #{decision ? 'PLACEHOLDER (will discard)' : 'ok'}")
      decision
    ensure
      bmp.dispose rescue nil
    end
  rescue
    false
  end

  # After saving generated bytes, discard the file if it is a flat placeholder
  # so resolution falls back to the normal sprite. Returns the path when kept,
  # nil when discarded.
  def self.keep_or_discard_generated(path)
    return path unless path
    if looks_like_placeholder?(path)
      AIGen.log("discarded placeholder sprite #{path}")
      Store.delete(path)
      Store.forget_bitmap(path)
      return nil
    end
    path
  end

  # Generate one AI sprite for fusion (head,body). Saves to the next free slot.
  # Returns the saved path, or nil on any failure (model down, etc).
  def self.generate(head_id, body_id, spriteform_body = nil, spriteform_head = nil, seed = nil)
    AIGen.log("generate request head=#{head_id} body=#{body_id} seed=#{seed.inspect}")
    bytes = Backend.fetch(head_id, body_id, seed)
    unless bytes
      AIGen.log("generate ABORT #{head_id}.#{body_id}: backend returned no bytes")
      return nil
    end
    letter = Store.next_free_letter(head_id, body_id, spriteform_body, spriteform_head)
    if letter.nil?
      AIGen.log("generate ABORT #{head_id}.#{body_id}: no free slot (all 27 letters in use)")
      return nil
    end
    path = Store.save_png_bytes(bytes, head_id, body_id, spriteform_body, spriteform_head, letter)
    AIGen.log("generate wrote #{path} (letter #{letter.inspect})")
    path = keep_or_discard_generated(path)
    if path
      AIGen.log("saved #{path}")
    else
      AIGen.log("generate ABORT #{head_id}.#{body_id}: file rejected as placeholder")
    end
    path
  end

  # Both fusion directions: A-head/B-body and B-head/A-body. Returns [pathAB, pathBA].
  def self.generate_both(a_id, b_id, seed = nil)
    [generate(a_id, b_id, nil, nil, seed), generate(b_id, a_id, nil, nil, seed)]
  end

  # Regenerate an AI sprite IN PLACE, overwriting the file at `letter`
  # (default "" = the main sprite) instead of allocating a new slot. Uses a
  # fresh random seed so the model yields a different image, then drops the old
  # bitmap from the engine cache so the new one is re-read from disk.
  # Returns the saved path, or nil on any failure.
  def self.regenerate(head_id, body_id, letter = "", spriteform_body = nil, spriteform_head = nil, seed = nil)
    seed ||= rand(1_000_000)
    AIGen.log("regenerate request head=#{head_id} body=#{body_id} letter=#{letter.inspect} seed=#{seed}")
    bytes = Backend.fetch(head_id, body_id, seed)
    unless bytes
      AIGen.log("regenerate ABORT #{head_id}.#{body_id}: backend returned no bytes")
      return nil
    end
    path = Store.save_png_bytes(bytes, head_id, body_id, spriteform_body, spriteform_head, letter)
    Store.forget_bitmap(path)
    path = keep_or_discard_generated(path)
    if path
      AIGen.log("regenerated #{path}")
    else
      AIGen.log("regenerate ABORT #{head_id}.#{body_id}: file rejected as placeholder")
    end
    path
  end

  # Generate one AI sprite for the TRIPLE fusion (s1 head, s2 body, s3 third).
  # Saves to the next free slot. Returns the saved path, or nil on any failure.
  def self.generate_triple(s1, s2, s3, seed = nil)
    AIGen.log("generate_triple request #{s1}.#{s2}.#{s3} seed=#{seed.inspect}")
    bytes = Backend.fetch_triple(s1, s2, s3, seed)
    unless bytes
      AIGen.log("generate_triple ABORT #{s1}.#{s2}.#{s3}: backend returned no bytes")
      return nil
    end
    letter = Store.triple_next_free_letter(s1, s2, s3)
    if letter.nil?
      AIGen.log("generate_triple ABORT #{s1}.#{s2}.#{s3}: no free slot (all 27 letters in use)")
      return nil
    end
    path = Store.save_triple_png_bytes(bytes, s1, s2, s3, letter)
    AIGen.log("generate_triple wrote #{path} (letter #{letter.inspect})")
    path = keep_or_discard_generated(path)
    if path
      AIGen.log("saved triple #{path}")
    else
      AIGen.log("generate_triple ABORT #{s1}.#{s2}.#{s3}: file rejected as placeholder")
    end
    path
  end

  # Regenerate a TRIPLE AI sprite in place (default "" = main), fresh seed.
  def self.regenerate_triple(s1, s2, s3, letter = "", seed = nil)
    seed ||= rand(1_000_000)
    AIGen.log("regenerate_triple request #{s1}.#{s2}.#{s3} letter=#{letter.inspect} seed=#{seed}")
    bytes = Backend.fetch_triple(s1, s2, s3, seed)
    unless bytes
      AIGen.log("regenerate_triple ABORT #{s1}.#{s2}.#{s3}: backend returned no bytes")
      return nil
    end
    path = Store.save_triple_png_bytes(bytes, s1, s2, s3, letter)
    Store.forget_bitmap(path)
    path = keep_or_discard_generated(path)
    if path
      AIGen.log("regenerated triple #{path}")
    else
      AIGen.log("regenerate_triple ABORT #{s1}.#{s2}.#{s3}: file rejected as placeholder")
    end
    path
  end
end
