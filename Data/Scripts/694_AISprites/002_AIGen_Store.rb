#===============================================================================
# 694_AISprites - 002_AIGen_Store.rb
# File store for AI-generated fusion sprites.
# Layout: Graphics/AIGenerated/indexed/<head>/<head>.<body>[letter].png
#===============================================================================
module AIGen
  module Store
    module_function

    def fusion_basename(head_id, body_id, spriteform_body = nil, spriteform_head = nil, letter = "")
      fb = spriteform_body ? "_#{spriteform_body}" : ""
      fh = spriteform_head ? "_#{spriteform_head}" : ""
      "#{head_id}#{fh}.#{body_id}#{fb}#{letter}"
    end

    def head_dir(head_id, spriteform_head = nil)
      fh = spriteform_head ? "_#{spriteform_head}" : ""
      "#{AIGen::INDEXED_FOLDER}#{head_id}#{fh}/"
    end

    def sprite_path(head_id, body_id, spriteform_body = nil, spriteform_head = nil, letter = "")
      head_dir(head_id, spriteform_head) +
        fusion_basename(head_id, body_id, spriteform_body, spriteform_head, letter) + ".png"
    end

    # All AI sprites for this fusion as resolvable paths, main first then a,b,c...
    def list(head_id, body_id, spriteform_body = nil, spriteform_head = nil)
      ret = []
      ([""] + AIGen::ALT_LETTERS).each do |letter|
        p = sprite_path(head_id, body_id, spriteform_body, spriteform_head, letter)
        r = (pbResolveBitmap(p) rescue nil)
        ret << p if r
      end
      ret
    end

    # Resolvable path of the AI "main" sprite (or first alt), else nil.
    def main_sprite_path(head_id, body_id, spriteform_body = nil, spriteform_head = nil)
      list(head_id, body_id, spriteform_body, spriteform_head).first
    end

    def exist?(head_id, body_id, spriteform_body = nil, spriteform_head = nil, letter = "")
      !!((pbResolveBitmap(sprite_path(head_id, body_id, spriteform_body, spriteform_head, letter)) rescue nil))
    end

    # Lowest unused slot: "" (main) first, then a..z. nil when all 27 are taken.
    def next_free_letter(head_id, body_id, spriteform_body = nil, spriteform_head = nil)
      return "" unless exist?(head_id, body_id, spriteform_body, spriteform_head, "")
      AIGen::ALT_LETTERS.each do |l|
        return l unless exist?(head_id, body_id, spriteform_body, spriteform_head, l)
      end
      nil
    end

    # Extract the alt-letter ("","a".."z") from a stored AI sprite path so a
    # selected sprite can be regenerated in place.
    def letter_from_path(path)
      return "" unless path
      base = File.basename(path.to_s.sub(/\.png\z/i, ""))
      m = base.match(/([a-z])\z/)
      m ? m[1] : ""
    end

    # Recursive mkdir WITHOUT requiring the fu lib -- it is absent from this
    # engine's embedded Ruby, so require raises LoadError, which is NOT a
    # StandardError; a bare rescue misses it and the sprite save crashed. Plain
    # Dir.mkdir per path segment, relative to the game root.
    def mkdir_p_safe(dir)
      return dir if dir.nil? || dir.empty?
      nd = dir.gsub("\\", "/")
      acc = nd.start_with?("/") ? "/" : ""
      nd.split("/").each do |seg|
        next if seg.nil? || seg.empty?
        acc += seg + "/"
        (Dir.mkdir(acc) rescue nil) unless Dir.exist?(acc)
      end
      dir
    rescue Exception
      dir
    end

    def ensure_dir(head_id, spriteform_head = nil)
      mkdir_p_safe(head_dir(head_id, spriteform_head))
    end

    def save_png_bytes(bytes, head_id, body_id, spriteform_body = nil, spriteform_head = nil, letter = "")
      ensure_dir(head_id, spriteform_head)
      path = sprite_path(head_id, body_id, spriteform_body, spriteform_head, letter)
      begin
        File.open(path, "wb") { |f| f.write(bytes) }
      rescue Exception => e
        (AIGen.log("save_png_bytes ERROR writing #{path}: #{e.class}: #{e.message}") rescue nil)
        raise
      end
      path
    end

    # Delete an AI sprite. Refuses to touch anything outside the AI folder.
    def delete(path)
      return false unless path
      real = ((pbResolveBitmap(path) rescue nil) || path)
      return false unless real.include?(AIGen::ROOT_FOLDER)
      real = real + ".png" unless real.downcase.end_with?(".png")
      begin
        File.delete(real) if File.exist?(real)
        forget_bitmap(path)
        true
      rescue
        false
      end
    end

    def ai_path?(path)
      !!(path && path.include?(AIGen::ROOT_FOLDER))
    end

    # Drop a path from the engine bitmap cache so a freshly overwritten or
    # deleted file is re-read from disk (or stops showing a stale image)
    # instead of serving the old cached bitmap.
    def forget_bitmap(path)
      return unless path && defined?(RPG::Cache) && RPG::Cache.respond_to?(:aigen_forget)
      RPG::Cache.aigen_forget(path)
    rescue
    end

    # Does a human-made custom exist for this fusion? (custom always beats AI)
    def human_custom?(head_id, body_id, spriteform_body = nil, spriteform_head = nil)
      fh = spriteform_head ? "_#{spriteform_head}" : ""
      fb = spriteform_body ? "_#{spriteform_body}" : ""
      base = "#{head_id}#{fh}.#{body_id}#{fb}"
      dir  = "#{Settings::CUSTOM_BATTLERS_FOLDER_INDEXED}#{head_id}#{fh}/"
      return true if (pbResolveBitmap(dir + base + ".png") rescue nil)
      AIGen::ALT_LETTERS.each do |l|
        return true if (pbResolveBitmap(dir + base + l + ".png") rescue nil)
      end
      false
    end

    #-- Triple fusions ---------------------------------------------------------
    # Mirror the game's Graphics/Battlers/special/<s1>.<s2>.<s3>[letter].png layout
    # but under the AI root, so generated triples are easy to find/credit/delete.
    def triple_folder
      "#{AIGen::ROOT_FOLDER}special/"
    end

    def triple_basename(s1, s2, s3, letter = "")
      "#{s1}.#{s2}.#{s3}#{letter}"
    end

    def triple_sprite_path(s1, s2, s3, letter = "")
      triple_folder + triple_basename(s1, s2, s3, letter) + ".png"
    end

    # All AI sprites for this triple as resolvable paths, main first then a,b,c...
    def triple_list(s1, s2, s3)
      ret = []
      ([""] + AIGen::ALT_LETTERS).each do |letter|
        path = triple_sprite_path(s1, s2, s3, letter)
        ret << path if (pbResolveBitmap(path) rescue nil)
      end
      ret
    end

    def triple_main_sprite_path(s1, s2, s3)
      triple_list(s1, s2, s3).first
    end

    def triple_exist?(s1, s2, s3, letter = "")
      !!((pbResolveBitmap(triple_sprite_path(s1, s2, s3, letter)) rescue nil))
    end

    def triple_next_free_letter(s1, s2, s3)
      return "" unless triple_exist?(s1, s2, s3, "")
      AIGen::ALT_LETTERS.each do |l|
        return l unless triple_exist?(s1, s2, s3, l)
      end
      nil
    end

    def ensure_triple_dir
      mkdir_p_safe(triple_folder)
    end

    def save_triple_png_bytes(bytes, s1, s2, s3, letter = "")
      ensure_triple_dir
      path = triple_sprite_path(s1, s2, s3, letter)
      begin
        File.open(path, "wb") { |f| f.write(bytes) }
      rescue Exception => e
        (AIGen.log("save_triple_png_bytes ERROR writing #{path}: #{e.class}: #{e.message}") rescue nil)
        raise
      end
      path
    end

    # Does a premade (official/human) triple sprite exist? It always beats AI.
    def human_triple?(s1, s2, s3)
      base = "Graphics/Battlers/special/#{s1}.#{s2}.#{s3}"
      return true if (pbResolveBitmap(base + ".png") rescue nil)
      AIGen::ALT_LETTERS.each do |l|
        return true if (pbResolveBitmap(base + l + ".png") rescue nil)
      end
      false
    end
  end
end

# Cache invalidation helper used by the AI sprite store so regenerated files
# (same path, fresh bytes) are re-read from disk instead of served stale, and
# deleted files stop showing. Reopens the engine bitmap cache (loaded much
# earlier in 007_Objects and windows/001_RPG_Cache.rb).
module RPG
  module Cache
    def self.aigen_forget(path)
      return unless path
      stripped = path.sub(/\.png\z/i, "")
      withext  = path.downcase.end_with?(".png") ? path : path + ".png"
      [path, stripped, withext].uniq.each do |k|
        @cache.delete(k) if @cache.is_a?(Hash) && @cache.include?(k)
      end
    rescue
    end
  end
end
