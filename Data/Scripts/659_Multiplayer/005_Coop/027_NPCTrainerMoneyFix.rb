#===============================================================================
# Coop NPCTrainer money accessor fix
#===============================================================================
# In coop battles, remote allies (and, on a JOINING client, the initiator) are
# placed on the player's side as NPCTrainer objects. On the joining client,
# pbPlayer (player-side trainer index 0) is the initiator NPCTrainer rather than
# the real $Trainer.
#
# Several end-of-battle paths read pbPlayer.money -- notably the
# travel_expansion_framework pbGainMoney patch
# (Mods/travel_expansion_framework/030_KeishouCharmStorageCompatibility.rb).
# NPCTrainer has no money accessor by default, so this raised:
#     NoMethodError: undefined method `money' for #<NPCTrainer ...>
# right after EXP was awarded, which left the battle scene undisposed and froze
# the joining player on the battle UI (only the multiplayer overlay responded).
#
# The PvP BattleCore already works around this by defining money/money= on its
# opponent NPCTrainer instance. This patch covers EVERY coop NPCTrainer build
# site (wild + trainer battles) in one place by giving the NPCTrainer class a
# safe money accessor (default 0). Guarded with `unless method_defined?` so we
# never clobber an existing definition, and per-instance singleton definitions
# (like PvP's) still take precedence.
#===============================================================================
if defined?(NPCTrainer)
  class NPCTrainer
    unless method_defined?(:money)
      def money
        @money ||= 0
      end
    end

    unless method_defined?(:money=)
      def money=(value)
        @money = value
      end
    end
  end
end
