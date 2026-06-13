# frozen_string_literal: true

# Keeps the title/save-select screen responsive. The normal load screen path can
# do network checks and full save validation before the first menu is visible;
# those are safer after the player has actually selected a save.
module TitleLoadPerformance
  LOG_DIR = File.expand_path("./Logs")
  LOG_PATH = File.join(LOG_DIR, "title_load_performance.log")

  @in_title_startup = false
  @skip_logged = {}

  class << self
    attr_accessor :in_title_startup

    def log(message)
      Dir.mkdir(LOG_DIR) unless Dir.exist?(LOG_DIR)
      File.open(LOG_PATH, "ab") { |file| file.write("[#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}] #{message}\n") }
    rescue
      nil
    end

    def log_skip_once(name)
      return if @skip_logged[name]
      @skip_logged[name] = true
      log("skipped #{name} during title startup")
    end

    def title_startup?
      @in_title_startup == true
    end

    def fast_save_preview(file_path)
      return {} if !file_path || !File.file?(file_path)
      raw = SaveData.get_data_from_file(file_path)
      raw = SaveData.to_hash_format(raw) if raw.is_a?(Array)
      return {} unless raw.is_a?(Hash)
      return {} unless raw[:player] && raw[:map_factory]
      raw
    rescue => e
      log("fast preview failed for #{file_path}: #{e.class}: #{e.message}")
      {}
    end
  end
end

if defined?(SaveData)
  module SaveData
    class << self
      alias title_load_perf_original_get_newest_save_slot get_newest_save_slot unless method_defined?(:title_load_perf_original_get_newest_save_slot)

      def get_newest_save_slot
        slots = respond_to?(:display_slots) ? display_slots : (AUTO_SLOTS + MANUAL_SLOTS)
        candidates = slots.find_all { |slot| File.file?(get_full_path(slot)) }
        return nil if candidates.empty?
        candidates.max_by { |slot| File.mtime(get_full_path(slot)) rescue Time.at(0) }
      rescue => e
        TitleLoadPerformance.log("mtime newest-slot fallback after #{e.class}: #{e.message}") if defined?(TitleLoadPerformance)
        title_load_perf_original_get_newest_save_slot
      end
    end
  end
end

if defined?(PokemonLoadScreen)
  module TitleLoadPerformanceScreenPatch
    def pbStartLoadScreen(*args)
      TitleLoadPerformance.in_title_startup = true if defined?(TitleLoadPerformance)
      super
    ensure
      TitleLoadPerformance.in_title_startup = false if defined?(TitleLoadPerformance)
    end

    def load_save_file(file_path, preview = false)
      if preview && defined?(TitleLoadPerformance)
        preview_data = TitleLoadPerformance.fast_save_preview(file_path)
        return preview_data if preview_data.is_a?(Hash) && !preview_data.empty?
      end
      super
    end
  end

  PokemonLoadScreen.prepend(TitleLoadPerformanceScreenPatch)
end

if defined?(updateHttpSettingsFile)
  alias title_load_perf_original_updateHttpSettingsFile updateHttpSettingsFile unless defined?(title_load_perf_original_updateHttpSettingsFile)
  def updateHttpSettingsFile(*args)
    if defined?(TitleLoadPerformance) && TitleLoadPerformance.title_startup?
      TitleLoadPerformance.log_skip_once("updateHttpSettingsFile")
      return nil
    end
    title_load_perf_original_updateHttpSettingsFile(*args)
  end
end

if defined?(updateCreditsFile)
  alias title_load_perf_original_updateCreditsFile updateCreditsFile unless defined?(title_load_perf_original_updateCreditsFile)
  def updateCreditsFile(*args)
    if defined?(TitleLoadPerformance) && TitleLoadPerformance.title_startup?
      TitleLoadPerformance.log_skip_once("updateCreditsFile")
      return nil
    end
    title_load_perf_original_updateCreditsFile(*args)
  end
end

if defined?(updateCustomDexFile)
  alias title_load_perf_original_updateCustomDexFile updateCustomDexFile unless defined?(title_load_perf_original_updateCustomDexFile)
  def updateCustomDexFile(*args)
    if defined?(TitleLoadPerformance) && TitleLoadPerformance.title_startup?
      TitleLoadPerformance.log_skip_once("updateCustomDexFile")
      return nil
    end
    title_load_perf_original_updateCustomDexFile(*args)
  end
end

if defined?(updateOnlineCustomSpritesFile)
  alias title_load_perf_original_updateOnlineCustomSpritesFile updateOnlineCustomSpritesFile unless defined?(title_load_perf_original_updateOnlineCustomSpritesFile)
  def updateOnlineCustomSpritesFile(*args)
    if defined?(TitleLoadPerformance) && TitleLoadPerformance.title_startup?
      TitleLoadPerformance.log_skip_once("updateOnlineCustomSpritesFile")
      return nil
    end
    title_load_perf_original_updateOnlineCustomSpritesFile(*args)
  end
end

if defined?(find_newer_available_version)
  alias title_load_perf_original_find_newer_available_version find_newer_available_version unless defined?(title_load_perf_original_find_newer_available_version)
  def find_newer_available_version(*args)
    if defined?(TitleLoadPerformance) && TitleLoadPerformance.title_startup?
      TitleLoadPerformance.log_skip_once("find_newer_available_version")
      return nil
    end
    title_load_perf_original_find_newer_available_version(*args)
  end
end

if defined?(checkEnableSpritesDownload)
  alias title_load_perf_original_checkEnableSpritesDownload checkEnableSpritesDownload unless defined?(title_load_perf_original_checkEnableSpritesDownload)
  def checkEnableSpritesDownload(*args)
    if defined?(TitleLoadPerformance) && TitleLoadPerformance.title_startup?
      TitleLoadPerformance.log_skip_once("checkEnableSpritesDownload")
      return nil
    end
    title_load_perf_original_checkEnableSpritesDownload(*args)
  end
end
