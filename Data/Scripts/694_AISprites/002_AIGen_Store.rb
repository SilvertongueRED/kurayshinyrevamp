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

    def ensure_dir(head_id, spriteform_head = nil)
      dir = head_dir(head_id, spriteform_head)
      begin
        require 'fileutils'
        FileUtils.mkdir_p(dir)
      rescue
        acc = ""
        dir.split("/").each do |seg|
          next if seg.nil? || seg.empty?
          acc += seg + "/"
          Dir.mkdir(acc) unless Dir.exist?(acc)
        end
      end
      dir
    end

    def save_png_bytes(bytes, head_id, body_id, spriteform_body = nil, spriteform_head = nil, letter = "")
      ensure_dir(head_id, spriteform_head)
      path = sprite_path(head_id, body_id, spriteform_body, spriteform_head, letter)
      File.open(path, "wb") { |f| f.write(bytes) }
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
        true
      rescue
        false
      end
    end

    def ai_path?(path)
      !!(path && path.include?(AIGen::ROOT_FOLDER))
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
  end
end
