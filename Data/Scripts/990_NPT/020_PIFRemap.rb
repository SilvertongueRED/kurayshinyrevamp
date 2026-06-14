#==============================================================================
# 990_NPT — PIF <-> Fork sprite-id remap (canonical map, in-engine)
# File: 020_PIFRemap.rb
#
# PIF / PIF-Hoenn renumbered dex 502-572 differs from the fork's NPT ids at and
# above 553 (PIF spends 4 dex slots on Castform's weather forms; the fork spends
# one, then ordering diverges). 502-552 and all base mons 1-501 are identical.
#
# This module is the single in-engine source of truth for translating between
# PIF sprite ids and fork/NPT ids. It is data-only (no patching), so it is
# MP-safe and cannot break boot. The offline converter (convert_pif_pack.py)
# uses the same table to rename incoming PIF packs to fork numbering, with the
# PIF sprite as the main and any existing AFI/KIF sprite kept as a selectable alt.
#
# Keyed by SPECIES identity, so it extends cleanly as PIF ships new months:
# add the new PIF id -> fork id pair here (and to convert_pif_pack.py) for any
# id whose fork mapping is not identity.
#==============================================================================

module PIFRemap
  # PIF dex id => fork/NPT id. Only divergent entries; anything not listed
  # (incl. 1-552 and every base mon) is identity.
  PIF_TO_FORK = {
    553 => 1038,  # Castform (Sunny)   -> fork CASTFORM_1
    554 => 1039,  # Castform (Rainy)   -> fork CASTFORM_2
    555 => 1040,  # Castform (Snowy)   -> fork CASTFORM_3
    556 => 553,   # Tropius
    557 => 581,   # Chingling
    558 => 554,   # Chimecho
    559 => 555,   # Spheal
    560 => 556,   # Sealeo
    561 => 557,   # Walrein
    562 => 558,   # Clamperl
    563 => 559,   # Huntail
    564 => 560,   # Gorebyss
    565 => 561,   # Relicanth
    566 => 1109,  # Noibat   (registered in 021_PIFGapSpecies.rb)
    567 => 1110,  # Noivern  (registered in 021_PIFGapSpecies.rb)
    568 => 687,   # Tynamo
    569 => 688,   # Eelektrik
    570 => 689,   # Eelektross
    571 => 737,   # Skrelp
    572 => 738,   # Dragalge
  }.freeze
  FORK_TO_PIF = PIF_TO_FORK.invert.freeze

  # PIF sprite id -> fork/NPT id (identity outside the divergent set).
  def self.pif_to_fork(id)
    PIF_TO_FORK.fetch(id.to_i, id.to_i)
  end

  # Fork/NPT id -> PIF sprite id (identity outside the divergent set).
  def self.fork_to_pif(id)
    FORK_TO_PIF.fetch(id.to_i, id.to_i)
  end

  # True if this fork id maps to a different PIF id (i.e. needs remapping).
  def self.divergent_fork?(id)
    FORK_TO_PIF.key?(id.to_i)
  end

  # Translate a PIF custom-sprite filename ("H.B[alt].png") into fork numbering.
  # Returns the original string if it is not a fusion filename.
  def self.translate_filename(name)
    m = name.to_s.match(/\A(\d+)\.(\d+)([a-z]?)\.png\z/i)
    return name unless m
    "#{pif_to_fork(m[1])}.#{pif_to_fork(m[2])}#{m[3]}.png"
  end
end

echoln "[990_NPT] PIFRemap loaded (#{PIFRemap::PIF_TO_FORK.size} divergent ids; 1-552 identity)"
