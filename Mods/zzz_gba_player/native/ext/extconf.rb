# frozen_string_literal: true

require "mkmf"

dir_config("mgba")

has_mgba_header = have_header("mgba/core/core.h")
unless has_mgba_header
  warn "libmgba headers were not found. Install mGBA development headers or pass --with-mgba-dir."
end

have_library("mgba")
$defs << "-DGBA_PLAYER_WITH_MGBA" if has_mgba_header
create_makefile("gba_player_bridge")
