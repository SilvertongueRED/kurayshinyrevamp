# frozen_string_literal: true

# Fallback loader for installs where the managed mod state was built before
# zzz_gba_player had a valid mod id. The managed loader remains the primary path.
unless defined?(GBAPlayer)
  root = File.expand_path("zzz_gba_player", __dir__)
  [
    "001_ConfigAndBridge.rb",
    "002_Gen3SaveParser.rb",
    "003_ItemAndMenus.rb",
    "004_PlayerShell.rb",
    "005_WalkalongOverlay.rb",
    "006_PokegearMobile.rb"
  ].each do |script|
    path = File.join(root, script)
    load path if File.exist?(path)
  end
end
