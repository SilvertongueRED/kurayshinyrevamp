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
        resp = HTTPLite.get(base_url + AIGen::HEALTH_PATH)
        !!(resp && resp[:status] == 200)
      rescue
        false
      end
      @available
    end

    def reset_availability
      @available = nil
    end

    # Raw PNG bytes for the fusion head_id(head)/body_id(body), or nil.
    def fetch(head_id, body_id, seed = nil)
      return nil unless AIGen.enabled?
      return nil unless available?
      url = base_url + AIGen::GENERATE_PATH + "?head=#{head_id}&body=#{body_id}"
      url += "&seed=#{seed}" if seed
      begin
        resp = HTTPLite.get(url)
        if resp && resp[:status] == 200 && resp[:body] && !resp[:body].empty?
          return resp[:body]
        end
        AIGen.log("generate failed (status #{resp ? resp[:status] : 'nil'}) for #{head_id}.#{body_id}")
        nil
      rescue => e
        AIGen.log("generate error: #{e.message}")
        nil
      end
    end
  end

  # Generate one AI sprite for fusion (head,body). Saves to the next free slot.
  # Returns the saved path, or nil on any failure (model down, etc).
  def self.generate(head_id, body_id, spriteform_body = nil, spriteform_head = nil, seed = nil)
    bytes = Backend.fetch(head_id, body_id, seed)
    return nil unless bytes
    letter = Store.next_free_letter(head_id, body_id, spriteform_body, spriteform_head)
    return nil if letter.nil?
    path = Store.save_png_bytes(bytes, head_id, body_id, spriteform_body, spriteform_head, letter)
    AIGen.log("saved #{path}")
    path
  end

  # Both fusion directions: A-head/B-body and B-head/A-body. Returns [pathAB, pathBA].
  def self.generate_both(a_id, b_id, seed = nil)
    [generate(a_id, b_id, nil, nil, seed), generate(b_id, a_id, nil, nil, seed)]
  end
end
