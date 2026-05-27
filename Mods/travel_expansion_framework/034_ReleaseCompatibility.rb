module TravelExpansionFramework
  RELEASE_COMPATIBILITY_VERSION = "2026.05-rc1" unless const_defined?(:RELEASE_COMPATIBILITY_VERSION)
  RELEASE_COMPATIBILITY_FILENAME = "release_compatibility_manifest.json" unless const_defined?(:RELEASE_COMPATIBILITY_FILENAME)
  RELEASE_SHIM_CATALOG_FILENAME = "release_shim_catalog.json" unless const_defined?(:RELEASE_SHIM_CATALOG_FILENAME)

  RELEASE_COMPATIBILITY_CATEGORIES = [
    "startup",
    "story_transfer",
    "trainer_battle",
    "item_handlers",
    "town_map",
    "follower_system",
    "bridge_passability",
    "encounters",
    "dex",
    "menu_settings",
    "save_load_recovery"
  ].freeze unless const_defined?(:RELEASE_COMPATIBILITY_CATEGORIES)

  RELEASE_WORLD_DISPLAY_NAMES = {
    "reborn"             => "Pokemon Reborn",
    "xenoverse"         => "Pokemon Xenoverse",
    "insurgence"        => "Pokemon Insurgence",
    "pokemon_uranium"   => "Pokemon Uranium",
    "opalo"             => "Pokemon Opalo",
    "empyrean"          => "Pokemon Empyrean",
    "realidea"          => "Pokemon Realidea",
    "soulstones"        => "Pokemon Soulstones",
    "soulstones2"       => "Pokemon Soulstones 2",
    "anil"              => "Pokemon Anil / Indigo",
    "bushido"           => "Pokemon Bushido",
    "darkhorizon"       => "Pokemon Dark Horizon",
    "infinity"          => "Pokemon Infinity",
    "solar_eclipse"     => "Pokemon Solar Eclipse",
    "vanguard"          => "Pokemon Vanguard",
    "pokemon_z"         => "Pokemon Z",
    "chaos_in_vesita"   => "Pokemon Chaos in Vesita",
    "deserted"          => "Pokemon Deserted",
    "gadir_deluxe"      => "Pokemon Gadir Deluxe",
    "hollow_woods"      => "Pokemon Hollow Woods",
    "keishou"           => "Pokemon Keishou",
    "unbreakable_ties"  => "Pokemon Unbreakable Ties",
    "decades"           => "Pokemon Decades",
    "rejuvenation"      => "Pokemon Rejuvenation",
    "pokemon_void"      => "Pokemon Void"
  }.freeze unless const_defined?(:RELEASE_WORLD_DISPLAY_NAMES)

  RELEASE_REQUIRED_SHIMS = {
    "reborn"            => ["startup", "story_transfer", "trainer_battle", "town_map", "menu_settings", "save_load_recovery"],
    "xenoverse"         => ["startup", "story_transfer", "trainer_battle", "item_handlers", "save_load_recovery"],
    "insurgence"        => ["startup", "story_transfer", "trainer_battle", "follower_system", "menu_settings", "save_load_recovery"],
    "pokemon_uranium"   => ["startup", "story_transfer", "trainer_battle", "encounters", "save_load_recovery"],
    "opalo"             => ["startup", "story_transfer", "trainer_battle", "encounters", "save_load_recovery"],
    "empyrean"          => ["startup", "story_transfer", "trainer_battle", "bridge_passability", "encounters", "save_load_recovery"],
    "realidea"          => ["startup", "story_transfer", "trainer_battle", "menu_settings", "save_load_recovery"],
    "soulstones"        => ["startup", "story_transfer", "trainer_battle", "item_handlers", "encounters", "save_load_recovery"],
    "soulstones2"       => ["startup", "story_transfer", "trainer_battle", "item_handlers", "encounters", "save_load_recovery"],
    "anil"              => ["startup", "story_transfer", "trainer_battle", "item_handlers", "town_map", "follower_system", "dex", "menu_settings", "save_load_recovery"],
    "bushido"           => ["startup", "story_transfer", "trainer_battle", "menu_settings", "save_load_recovery"],
    "darkhorizon"       => ["startup", "story_transfer", "trainer_battle", "item_handlers", "menu_settings", "save_load_recovery"],
    "infinity"          => ["startup", "story_transfer", "trainer_battle", "follower_system", "menu_settings", "save_load_recovery"],
    "solar_eclipse"     => ["startup", "story_transfer", "trainer_battle", "follower_system", "menu_settings", "save_load_recovery"],
    "vanguard"          => ["startup", "story_transfer", "trainer_battle", "menu_settings", "save_load_recovery"],
    "pokemon_z"         => ["startup", "story_transfer", "trainer_battle", "menu_settings", "save_load_recovery"],
    "chaos_in_vesita"   => ["startup", "story_transfer", "trainer_battle", "save_load_recovery"],
    "deserted"          => ["startup", "story_transfer", "trainer_battle", "save_load_recovery"],
    "gadir_deluxe"      => ["startup", "story_transfer", "trainer_battle", "menu_settings", "save_load_recovery"],
    "hollow_woods"      => ["startup", "story_transfer", "trainer_battle", "item_handlers", "menu_settings", "save_load_recovery"],
    "keishou"           => ["startup", "story_transfer", "trainer_battle", "item_handlers", "town_map", "bridge_passability", "encounters", "menu_settings", "save_load_recovery"],
    "unbreakable_ties"  => ["startup", "story_transfer", "trainer_battle", "menu_settings", "save_load_recovery"],
    "decades"           => ["startup", "story_transfer", "trainer_battle", "item_handlers", "town_map", "follower_system", "encounters", "menu_settings", "save_load_recovery"],
    "rejuvenation"      => ["startup", "story_transfer", "trainer_battle", "item_handlers", "town_map", "follower_system", "bridge_passability", "encounters", "dex", "menu_settings", "save_load_recovery"],
    "pokemon_void"      => ["startup", "story_transfer", "trainer_battle", "item_handlers", "town_map", "follower_system", "bridge_passability", "encounters", "dex", "menu_settings", "save_load_recovery"]
  }.freeze unless const_defined?(:RELEASE_REQUIRED_SHIMS)

  RELEASE_KNOWN_RISKS = {
    "reborn"            => ["story flags after scripted crashes", "map transfer interpreter staleness"],
    "empyrean"          => ["bridge passability and over/under bridge state"],
    "soulstones"        => ["helper methods and edge map connections"],
    "soulstones2"       => ["helper methods and starter setup"],
    "anil"              => ["native menus, town map language, follower/photo helpers, and transfer release"],
    "bushido"           => ["battle scripting setup and party ownership reset"],
    "darkhorizon"       => ["EliteBattle setup and trainer wrappers"],
    "infinity"          => ["day-night helper methods and roaming checks"],
    "solar_eclipse"     => ["intro setting menus and trainer-card setup"],
    "vanguard"          => ["early Destiny intro switch handoff and stale battle-state cleanup"],
    "hollow_woods"      => ["game-mode screens, starter selection, and quest helpers"],
    "keishou"           => ["native item handlers, charm/crafting/storage, town map routing, bridge and encounter tags"],
    "decades"           => ["Deluxe Battle Kit rules, form trader screens, battle-mode bag helpers, follower setup, and tip cards"],
    "rejuvenation"      => ["Reborn/Rejuv quest flags, field effects, dependent followers, cave/surf transfers, password entry, berry plants, and Day Care helpers"],
    "pokemon_void"      => ["packaged Essentials v21 archive, plugin scripts, compiled species data, custom fakemon graphics, and early story bootstrap"]
  }.freeze unless const_defined?(:RELEASE_KNOWN_RISKS)

  RELEASE_SMOKE_ROUTE = [
    "enter from PC or travel terminal",
    "complete first required dialogue",
    "trigger one map transfer",
    "open menu and town map",
    "run one wild battle and one trainer battle",
    "save, quit, reload, and return home"
  ].freeze unless const_defined?(:RELEASE_SMOKE_ROUTE)

  RELEASE_GENERIC_SHIM_CATALOG = {
    "pbZoomIn"                  => { "category" => "map_visual",       "default" => "true",  "note" => "Visual zoom request is ignored safely." },
    "pbZoomOut"                 => { "category" => "map_visual",       "default" => "true",  "note" => "Visual zoom request is ignored safely." },
    "pbWatchTV"                 => { "category" => "item_handlers",    "default" => "true",  "note" => "TV flavor event is acknowledged." },
    "pbCheckRoaming"            => { "category" => "encounters",       "default" => "false", "note" => "Unsupported roaming check fails closed." },
    "pbHasStarters?"            => { "category" => "startup",          "default" => "party_present", "note" => "Starter ownership is inferred from host party." },
    "pbStoryModeSetup"          => { "category" => "startup",          "default" => "true",  "note" => "Imported story-mode bootstrap is acknowledged without bulk mutating the host save." },
    "pbStoryModeGiveDummyStarters" => { "category" => "startup",       "default" => "true",  "note" => "Imported dummy starters are skipped so the host party is preserved." },
    "pbStoryModeRemoveDummyStarters" => { "category" => "startup",     "default" => "true",  "note" => "Imported dummy starter cleanup is skipped so the host party is preserved." },
    "pbStoryModeTrainerItemSuite" => { "category" => "item_handlers",  "default" => "true",  "note" => "Imported bulk key-item suite is skipped until a world-specific safe grant is certified." },
    "pbClearAllPokemonSetup"     => { "category" => "startup",          "default" => "true",  "note" => "Imported all-Pokemon cleanup is skipped to protect host PC/storage." },
    "pbAllPokemonSetup5"         => { "category" => "startup",          "default" => "true",  "note" => "Imported all-Pokemon PC fill is skipped to protect host save size and storage." },
    "pbAllPokemonSetup30"        => { "category" => "startup",          "default" => "true",  "note" => "Imported all-Pokemon PC fill is skipped to protect host save size and storage." },
    "pbAllPokemonSetup50"        => { "category" => "startup",          "default" => "true",  "note" => "Imported all-Pokemon PC fill is skipped to protect host save size and storage." },
    "pbAllPokemonSetup100"       => { "category" => "startup",          "default" => "true",  "note" => "Imported all-Pokemon PC fill is skipped to protect host save size and storage." },
    "pbOptimisedPartyQuickStart5" => { "category" => "startup",         "default" => "true",  "note" => "Imported stock challenge team is skipped so the host party is preserved." },
    "pbOptimisedPartyQuickStart30" => { "category" => "startup",        "default" => "true",  "note" => "Imported stock challenge team is skipped so the host party is preserved." },
    "pbOptimisedPartyQuickStart50" => { "category" => "startup",        "default" => "true",  "note" => "Imported stock challenge team is skipped so the host party is preserved." },
    "pbOptimisedPartyQuickStart100" => { "category" => "startup",       "default" => "true",  "note" => "Imported stock challenge team is skipped so the host party is preserved." },
    "pbBattleModeSetup5"       => { "category" => "trainer_battle",     "default" => "true",  "note" => "Decades Battle Mode setup is acknowledged safely; Story Mode is the release path." },
    "pbBattleModeSetup30"      => { "category" => "trainer_battle",     "default" => "true",  "note" => "Decades Battle Mode setup is acknowledged safely; Story Mode is the release path." },
    "pbBattleModeSetup50"      => { "category" => "trainer_battle",     "default" => "true",  "note" => "Decades Battle Mode setup is acknowledged safely; Story Mode is the release path." },
    "pbBattleModeSetup100"     => { "category" => "trainer_battle",     "default" => "true",  "note" => "Decades Battle Mode setup is acknowledged safely; Story Mode is the release path." },
    "prerandomizeMiningStones"  => { "category" => "startup",          "default" => "true",  "note" => "Mining pre-randomization is skipped safely." },
    "useAirDragonite"           => { "category" => "story_transfer",   "default" => "false", "note" => "Unsupported ride shortcut fails closed." },
    "pbHealingMachine"          => { "category" => "item_handlers",    "default" => "heal_party", "note" => "Host party heal fallback." },
    "pbXDPC"                    => { "category" => "item_handlers",    "default" => "host_pc", "note" => "External PC terminal opens the host PC UI." },
    "pbPokeMartWorker"          => { "category" => "item_handlers",    "default" => "host_mart", "note" => "External mart worker opens a safe host mart inventory." },
    "characterPopup"            => { "category" => "story_transfer",   "default" => "true",  "note" => "Popup marker is skipped safely." },
    "getCompletedQuests"        => { "category" => "menu_settings",    "default" => "array", "note" => "Quest list is host-local until native quest bridge is certified." },
    "getActiveQuests"           => { "category" => "menu_settings",    "default" => "array", "note" => "Quest list is host-local until native quest bridge is certified." },
    "pbRandomItem"              => { "category" => "item_handlers",    "default" => "nil",   "note" => "Unsupported random pickup gives no item." },
    "pbEncounter"               => { "category" => "encounters",       "default" => "false", "note" => "Imported scripted encounter requests are mapped to host encounter tables." },
    "EncounterTypes"            => { "category" => "encounters",       "default" => "host_symbols", "note" => "Legacy encounter constants map to host EncounterType symbols." },
    "pbUnlockRecipe"            => { "category" => "item_handlers",    "default" => "true",  "note" => "Imported recipe unlocks are recorded when a world bridge supports recipes." },
    "pbLockRecipe"              => { "category" => "item_handlers",    "default" => "true",  "note" => "Imported recipe locks are recorded when a world bridge supports recipes." },
    "pbGetRecipes"              => { "category" => "item_handlers",    "default" => "array", "note" => "Imported recipe lists fall back to an empty compatible list." },
    "pbItemCrafter"             => { "category" => "item_handlers",    "default" => "true",  "note" => "Imported crafting screens use the world bridge when available, otherwise fail closed." },
    "pbFormTrader"              => { "category" => "item_handlers",    "default" => "true",  "note" => "Imported form trader requests are acknowledged safely until the native screen is certified." },
    "pbFormTraderPC"            => { "category" => "item_handlers",    "default" => "host_pc", "note" => "Imported PC form trader opens the host PC fallback." },
    "pbDumpOutAllItems"         => { "category" => "item_handlers",    "default" => "true",  "note" => "Imported battle-mode bag clear is skipped to protect the shared host save." },
    "pbJumpInAllItems"          => { "category" => "item_handlers",    "default" => "true",  "note" => "Imported battle-mode bag fill alias is skipped to protect the shared host save." },
    "pbPumbInAllItems"          => { "category" => "item_handlers",    "default" => "true",  "note" => "Imported battle-mode bag fill is skipped to protect the shared host save." },
    "pbRemoveBagClutter"        => { "category" => "item_handlers",    "default" => "true",  "note" => "Imported bag cleanup is skipped unless a world-specific adapter owns it." },
    "pbRemoveStoryModeBagClutter" => { "category" => "item_handlers",  "default" => "true",  "note" => "Imported story-mode bag cleanup is skipped to preserve host inventory." },
    "pbShowTipCard"             => { "category" => "menu_settings",    "default" => "true",  "note" => "Imported tip-card scenes are acknowledged safely." },
    "pbSetDialoguePortrait"     => { "category" => "menu_settings",    "default" => "true",  "note" => "Void dialogue portrait state is acknowledged without loading the native portrait UI." },
    "pbSetPlayerDialoguePortrait" => { "category" => "menu_settings",  "default" => "true",  "note" => "Void player dialogue portrait state is acknowledged without replacing the host player UI." },
    "pbSetRivalDialoguePortrait" => { "category" => "menu_settings",   "default" => "true",  "note" => "Void rival portrait state is acknowledged without loading the native portrait UI." },
    "pbClearDialoguePortrait"   => { "category" => "menu_settings",    "default" => "true",  "note" => "Void dialogue portrait state is cleared safely." },
    "pbPortraitMessage"         => { "category" => "menu_settings",    "default" => "portrait_message", "note" => "Void portrait messages are shown through the host message box." },
    "pbPlayerPortraitMessage"   => { "category" => "menu_settings",    "default" => "portrait_message", "note" => "Void player portrait messages are shown through the host message box." },
    "pbRivalPortraitMessage"    => { "category" => "menu_settings",    "default" => "portrait_message", "note" => "Void rival portrait messages are shown through the host message box." },
    "pbVoidRivalPortrait"       => { "category" => "menu_settings",    "default" => "empty_string", "note" => "Void rival portrait lookups return no portrait until the native UI is certified." },
    "pbVoidCharacterSetup"      => { "category" => "startup",          "default" => "void_character_setup", "note" => "Void character setup writes safe startup variables while preserving the host player identity." },
    "pbVoidCharacterSelect"     => { "category" => "startup",          "default" => "true",  "note" => "Void character selection is skipped to preserve host player identity." },
    "pbVoidCharSel"             => { "category" => "startup",          "default" => "zero",  "note" => "Void compact character selection returns a safe default choice." },
    "pbVoidCharacterCustomization" => { "category" => "startup",       "default" => "true",  "note" => "Void character customization is skipped to preserve host player identity." },
    "pbVoidCharCustomize"       => { "category" => "startup",          "default" => "true",  "note" => "Void compact character customization is skipped to preserve host player identity." },
    "pbApplyVoidCompositedPlayerSprite" => { "category" => "startup",  "default" => "true",  "note" => "Void generated player sprites are ignored so the host outfit remains stable." },
    "pbWalkCharacterTo"         => { "category" => "story_transfer",   "default" => "true",  "note" => "Void scripted pathfinding requests are acknowledged safely until certified." },
    "pbPlayerGender"            => { "category" => "menu_settings",    "default" => "zero",  "note" => "Void player gender lookups return a neutral host-safe default." },
    "pbPlayerPronouns"          => { "category" => "menu_settings",    "default" => "hash",  "note" => "Void player pronoun lookups return an empty host-safe token map." },
    "pbVoidRivalName"           => { "category" => "story_transfer",   "default" => "void_rival_name", "note" => "Void rival names use safe release defaults until native rival setup is certified." },
    "pbVoidRivalPronoun"        => { "category" => "story_transfer",   "default" => "void_rival_pronoun", "note" => "Void rival pronouns use safe release defaults until native rival setup is certified." },
    "pbVoidRivalTrainerType"    => { "category" => "trainer_battle",   "default" => "empty_string", "note" => "Void rival trainer type lookups fail closed until native trainer data is certified." },
    "pbVoidRivalCharset"        => { "category" => "story_transfer",   "default" => "empty_string", "note" => "Void rival charset lookups fail closed without replacing map graphics." },
    "pbVoidRivalStarter"        => { "category" => "startup",          "default" => "starter_species", "note" => "Void rival starter lookups use a valid host species fallback." },
    "pbVoidRivalStarterFromVariable" => { "category" => "startup",     "default" => "starter_species", "note" => "Void rival starter variable lookups use a valid host species fallback." },
    "pbVoidRivalStarterVersion" => { "category" => "startup",          "default" => "zero",  "note" => "Void rival starter version lookups use the first safe release version." },
    "pbVoidRivalStarterVersionFromVariable" => { "category" => "startup", "default" => "zero", "note" => "Void rival starter version variable lookups use the first safe release version." },
    "pbVoidRivalBattle"         => { "category" => "trainer_battle",   "default" => "true",  "note" => "Void rival battle helpers fail closed until native trainer mapping is certified." },
    "pbVoidRivalBattleFromVariable" => { "category" => "trainer_battle", "default" => "true", "note" => "Void rival battle helpers fail closed until native trainer mapping is certified." },
    "pbVoidRivalBattleStage"    => { "category" => "trainer_battle",   "default" => "true",  "note" => "Void rival staged battle helpers fail closed until native trainer mapping is certified." },
    "pbVoidRivalBattleStageFromVariable" => { "category" => "trainer_battle", "default" => "true", "note" => "Void rival staged battle helpers fail closed until native trainer mapping is certified." },
    "pbVoidRivalBattleStageVersion" => { "category" => "trainer_battle", "default" => "zero", "note" => "Void rival staged battle version lookups use the first safe release version." },
    "pbVoidRivalBattleStageVersionFromVariable" => { "category" => "trainer_battle", "default" => "zero", "note" => "Void rival staged battle version variable lookups use the first safe release version." },
    "pbVoidApplyRivalGraphic"   => { "category" => "story_transfer",   "default" => "true",  "note" => "Void rival graphic swaps are skipped to preserve host/player graphics." },
    "pbVoidClearRivalGraphic"   => { "category" => "story_transfer",   "default" => "true",  "note" => "Void rival graphic cleanup is acknowledged safely." },
    "pbStartQuest"              => { "category" => "menu_settings",    "default" => "true",  "note" => "Void quest starts are mirrored only into host-safe release metadata." },
    "pbCompleteQuest"           => { "category" => "menu_settings",    "default" => "true",  "note" => "Void quest completions are mirrored only into host-safe release metadata." },
    "pbQuestStatus"             => { "category" => "menu_settings",    "default" => "zero",  "note" => "Void quest status reads return a safe inactive stage until bridged." },
    "pbQuestStarted?"           => { "category" => "menu_settings",    "default" => "false", "note" => "Void quest started checks fail closed until bridged." },
    "pbQuestComplete?"          => { "category" => "menu_settings",    "default" => "false", "note" => "Void quest completion checks fail closed until bridged." },
    "pbQuestKnown?"             => { "category" => "menu_settings",    "default" => "false", "note" => "Void quest known checks fail closed until bridged." },
    "pbFishing"                 => { "category" => "encounters",       "default" => "false", "note" => "Void fishing helper fails closed until native encounter mapping is certified." },
    "pbVoidFishingMinigame"     => { "category" => "encounters",       "default" => "false", "note" => "Void fishing minigame fails closed until certified." },
    "pbVoidFishingSuccessCue"   => { "category" => "encounters",       "default" => "true",  "note" => "Void fishing success cues are acknowledged safely." },
    "pbVoidFishingChooseEncounter" => { "category" => "encounters",    "default" => "nil",   "note" => "Void fishing encounter choice returns no encounter until mapped." },
    "pbVoidFishingSeaTransition" => { "category" => "encounters",      "default" => "false", "note" => "Void fishing sea transition fails closed until certified." },
    "pbExclaim"                 => { "category" => "story_transfer",   "default" => "true",  "note" => "Void exclamation animation requests are acknowledged safely." },
    "pbTurnTowardEvent"         => { "category" => "story_transfer",   "default" => "true",  "note" => "Void event-facing helper is acknowledged safely." },
    "pbCharacterSelect"         => { "category" => "startup",          "default" => "true",  "note" => "Imported character selector is skipped to preserve host player identity." },
    "startCharacterSelection"   => { "category" => "startup",          "default" => "zero",  "note" => "Imported character selection returns the first safe host-compatible choice." },
    "pbPokemonSelection"        => { "category" => "startup",          "default" => "starter_species", "note" => "Imported modular starter selection returns a rotating host-compatible starter species." },
    "pbGrantRandomPokemonSilent" => { "category" => "startup",         "default" => "true",  "note" => "Imported random starter helpers choose a valid host species when possible." },
    "pbGrantRandomPokemon"      => { "category" => "startup",          "default" => "true",  "note" => "Imported random starter helpers choose a valid host species when possible." },
    "pbGetRandomPokemon"        => { "category" => "startup",          "default" => "starter_species", "note" => "Imported random starter lookup returns a valid host species." },
    "colorQuest"                => { "category" => "menu_settings",    "default" => "first_arg", "note" => "Rejuvenation quest color labels pass through safely." },
    "advanceQuestSilent"        => { "category" => "menu_settings",    "default" => "true",  "note" => "Imported quest advancement is mirrored into the host-safe quest metadata." },
    "advanceQuestToStage"       => { "category" => "menu_settings",    "default" => "true",  "note" => "Imported quest stage updates are mirrored into the host-safe quest metadata." },
    "activateQuestSilent"       => { "category" => "menu_settings",    "default" => "true",  "note" => "Imported silent quest activation is mirrored into the host-safe quest metadata." },
    "completeQuestSilent"       => { "category" => "menu_settings",    "default" => "true",  "note" => "Imported silent quest completion is mirrored into the host-safe quest metadata." },
    "getQuestStage"             => { "category" => "menu_settings",    "default" => "zero",  "note" => "Imported quest stage checks read the host-safe quest metadata." },
    "pbFieldDamage"             => { "category" => "encounters",       "default" => "true",  "note" => "Unsupported Rejuvenation field damage ticks are skipped safely." },
    "pbCaveEntrance"            => { "category" => "story_transfer",   "default" => "true",  "note" => "Imported cave-entrance visual/audio hooks are acknowledged safely." },
    "pbCaveExit"                => { "category" => "story_transfer",   "default" => "true",  "note" => "Imported cave-exit visual/audio hooks are acknowledged safely." },
    "pbSetEscapePoint"          => { "category" => "story_transfer",   "default" => "true",  "note" => "Imported escape-point bookkeeping is kept out of canonical host save location." },
    "pbEraseEscapePoint"        => { "category" => "story_transfer",   "default" => "true",  "note" => "Imported escape-point cleanup is acknowledged safely." },
    "pbTransferSurfing"         => { "category" => "story_transfer",   "default" => "true",  "note" => "Imported surfing transfer helper falls back to the guarded transfer path when available." },
    "pbTransferUnderwater"      => { "category" => "story_transfer",   "default" => "true",  "note" => "Imported underwater transfer helper falls back to the guarded transfer path when available." },
    "pbTransferLavaSurfing"     => { "category" => "story_transfer",   "default" => "true",  "note" => "Imported lava-surf transfer helper falls back to the guarded transfer path when available." },
    "pbTransferWithTransition"  => { "category" => "story_transfer",   "default" => "true",  "note" => "Imported scripted transfer helpers route through the guarded transfer path while preserving story state." },
    "pbCancelVehicles"          => { "category" => "story_transfer",   "default" => "true",  "note" => "Imported vehicle state is cleared without changing host canonical travel state." },
    "characterRestore"          => { "category" => "story_transfer",   "default" => "true",  "note" => "Imported character restore hooks are acknowledged safely." },
    "characterSwitch"           => { "category" => "story_transfer",   "default" => "true",  "note" => "Imported character switch hooks are acknowledged safely." },
    "characterSwtich"           => { "category" => "story_transfer",   "default" => "true",  "note" => "Misspelled imported character switch hook is acknowledged safely." },
    "pbRefreshCustomDuel"       => { "category" => "trainer_battle",   "default" => "true",  "note" => "Imported custom duel refresh is acknowledged safely." },
    "pbStartCustomDuel"         => { "category" => "trainer_battle",   "default" => "true",  "note" => "Imported custom duel start is acknowledged safely until certified." },
    "pbEndCustomDuel"           => { "category" => "trainer_battle",   "default" => "true",  "note" => "Imported custom duel cleanup is acknowledged safely." },
    "pbRentReturn"              => { "category" => "trainer_battle",   "default" => "true",  "note" => "Imported rental-party cleanup is skipped to preserve host party/storage." },
    "pbInfoBox"                 => { "category" => "menu_settings",    "default" => "true",  "note" => "Imported info boxes are acknowledged safely." },
    "pbSlotMachine"             => { "category" => "item_handlers",    "default" => "false", "note" => "Unsupported casino minigame fails closed." },
    "pbRoulette"                => { "category" => "item_handlers",    "default" => "false", "note" => "Unsupported casino minigame fails closed." },
    "pbVoltorbFlip"             => { "category" => "item_handlers",    "default" => "false", "note" => "Unsupported casino minigame fails closed." },
    "pbLottery"                 => { "category" => "item_handlers",    "default" => "false", "note" => "Unsupported lottery minigame fails closed." },
    "pbSetLotteryNumber"        => { "category" => "item_handlers",    "default" => "true",  "note" => "Imported lottery seed bookkeeping is skipped safely." },
    "pbBerryPlant"              => { "category" => "item_handlers",    "default" => "true",  "note" => "Imported berry plant handler is acknowledged safely until a native bridge owns it." },
    "pbPickBerry"               => { "category" => "item_handlers",    "default" => "true",  "note" => "Imported berry pickup handler is acknowledged safely until a native bridge owns it." },
    "pbPushThisBoulder"         => { "category" => "story_transfer",   "default" => "true",  "note" => "Imported boulder helper is acknowledged safely." },
    "pbPartialHeal"             => { "category" => "item_handlers",    "default" => "heal_party", "note" => "Imported partial heal uses the host party heal fallback." },
    "pbDayCareGetDeposited"     => { "category" => "item_handlers",    "default" => "array", "note" => "Imported Day Care reads from an empty host-safe deposit list until bridged." },
    "pbDayCareDeposited"        => { "category" => "item_handlers",    "default" => "zero",  "note" => "Imported Day Care reports no deposited Pokemon until bridged." },
    "pbDayCareGetCompatibility" => { "category" => "item_handlers",    "default" => "zero",  "note" => "Imported Day Care compatibility fails closed." },
    "pbDayCareDeposit"          => { "category" => "item_handlers",    "default" => "true",  "note" => "Imported Day Care deposit is skipped to protect host party." },
    "pbDayCareWithdraw"         => { "category" => "item_handlers",    "default" => "true",  "note" => "Imported Day Care withdraw is skipped until a host-safe bridge owns it." },
    "pbDayCareChoose"           => { "category" => "item_handlers",    "default" => "nil",   "note" => "Imported Day Care chooser returns no selected Pokemon until bridged." },
    "pbDayCareGenerateEgg"      => { "category" => "item_handlers",    "default" => "true",  "note" => "Imported Day Care egg generation is skipped safely." },
    "pbDayCareChooseOffspringBall" => { "category" => "item_handlers", "default" => "nil",   "note" => "Imported Day Care offspring-ball selection fails closed until bridged." },
    "pbSetEventTime"            => { "category" => "story_transfer",   "default" => "true",  "note" => "Imported event timer bookkeeping is acknowledged safely." },
    "pbCaveEntranceEx"          => { "category" => "story_transfer",   "default" => "true",  "note" => "Imported cave transition visual helper is acknowledged safely." },
    "PokemonSelection.restore"  => { "category" => "startup",          "default" => "true",  "note" => "Imported starter-selection restore hook is acknowledged safely." },
    "MessageConfig.pbSetSpeechFrame" => { "category" => "menu_settings", "default" => "true", "note" => "Imported speech frame setting is acknowledged without leaking UI skins." },
    "pbBattleChallenge"        => { "category" => "trainer_battle",    "default" => "host_safe_challenge", "note" => "Imported battle challenge state uses a host-safe inert challenge wrapper." },
    "pbBattleChallengeBattle"  => { "category" => "trainer_battle",    "default" => "true",  "note" => "Imported Battle Frontier cup battles are acknowledged safely until certified." },
    "pbHasEligible?"           => { "category" => "trainer_battle",    "default" => "true",  "note" => "Imported challenge eligibility checks allow the shared host party through safely." },
    "pbEntryScreen"            => { "category" => "trainer_battle",    "default" => "true",  "note" => "Imported challenge party entry screens are bypassed to protect the host party." },
    "pbInChallenge?"           => { "category" => "trainer_battle",    "default" => "false", "note" => "Host save is not treated as being inside an imported challenge facility." },
    "pbPokeCupRules"           => { "category" => "trainer_battle",    "default" => "challenge_rules", "note" => "Imported cup rules use a host-safe rule placeholder." },
    "pbPikaCupRules"           => { "category" => "trainer_battle",    "default" => "challenge_rules", "note" => "Imported cup rules use a host-safe rule placeholder." },
    "pbPrimeCupRules"          => { "category" => "trainer_battle",    "default" => "challenge_rules", "note" => "Imported cup rules use a host-safe rule placeholder." },
    "pbFancyCupRules"          => { "category" => "trainer_battle",    "default" => "challenge_rules", "note" => "Imported cup rules use a host-safe rule placeholder." },
    "pbLittleCupRules"         => { "category" => "trainer_battle",    "default" => "challenge_rules", "note" => "Imported cup rules use a host-safe rule placeholder." },
    "pbStrictLittleCupRules"   => { "category" => "trainer_battle",    "default" => "challenge_rules", "note" => "Imported cup rules use a host-safe rule placeholder." },
    "pbWriteCup"               => { "category" => "trainer_battle",    "default" => "true",  "note" => "Imported generated cup writes are skipped to protect host data." },
    "pbGenerateChallenge"      => { "category" => "trainer_battle",    "default" => "true",  "note" => "Imported generated cup data is not persisted into the host save." },
    "setBattleRule"             => { "category" => "trainer_battle",   "default" => "record_imported", "note" => "Imported Deluxe Battle Kit rules are recorded when harmless, otherwise ignored safely." },
    "ChallengeModes.start"      => { "category" => "menu_settings",    "default" => "true",  "note" => "Imported challenge-mode setup is acknowledged with host-safe defaults." },
    "TrainerBattle.start"       => { "category" => "trainer_battle",   "default" => "true",  "note" => "Last-resort trainer wrapper prevents crashes." },
    "LevelCapsEX.enabled?"      => { "category" => "menu_settings",    "default" => "false", "note" => "Unsupported level-cap plugin is treated as disabled." },
    "FollowingPkmn.active?"     => { "category" => "follower_system",  "default" => "false", "note" => "Follower system reports inactive unless a world bridge owns it." },
    "Player#expall"             => { "category" => "menu_settings",    "default" => "host_exp_all", "note" => "Imported Exp All player flag maps to the host Exp All item state." },
    "NilClass#quantity"         => { "category" => "item_handlers",    "default" => "zero",  "note" => "Missing item storage queries fail closed." }
  }.freeze unless const_defined?(:RELEASE_GENERIC_SHIM_CATALOG)

  module_function

  def release_compatibility_manifest_path
    return File.join(framework_root, RELEASE_COMPATIBILITY_FILENAME)
  end

  def release_shim_catalog_path
    return File.join(framework_root, RELEASE_SHIM_CATALOG_FILENAME)
  end

  def release_world_ids
    ids = RELEASE_WORLD_DISPLAY_NAMES.keys
    ids = ids + registry(:expansions).keys.map { |id| id.to_s } if respond_to?(:registry)
    return ids.uniq.sort
  rescue
    return RELEASE_WORLD_DISPLAY_NAMES.keys.sort
  end

  def release_world_display_name(expansion_id)
    id = expansion_id.to_s
    manifest = manifest_for(id) rescue nil
    return manifest[:name].to_s if manifest && manifest[:name] && !manifest[:name].to_s.empty?
    return RELEASE_WORLD_DISPLAY_NAMES[id] || id.split("_").map { |part| part.capitalize }.join(" ")
  end

  def release_default_world_profile(expansion_id)
    id = expansion_id.to_s
    manifest = manifest_for(id) rescue nil
    source = external_projects[id] rescue nil
    installed = !manifest.nil? || !source.nil?
    active = expansion_active?(id) rescue false
    required = Array(RELEASE_REQUIRED_SHIMS[id])
    required = RELEASE_COMPATIBILITY_CATEGORIES if required.empty?
    return {
      "id"                    => id,
      "display_name"          => release_world_display_name(id),
      "status"                => "release_candidate",
      "installed"             => installed,
      "active"                => active,
      "required_categories"   => required,
      "known_risks"           => Array(RELEASE_KNOWN_RISKS[id]),
      "last_verified_smoke_route" => RELEASE_SMOKE_ROUTE,
      "host_first"            => true,
      "host_battle_ui_locked" => true,
      "fail_closed"           => true
    }
  rescue => e
    log("[release] default profile failed for #{expansion_id}: #{e.class}: #{e.message}") if respond_to?(:log)
    return {
      "id"                    => id,
      "display_name"          => id,
      "status"                => "release_candidate",
      "installed"             => false,
      "active"                => false,
      "required_categories"   => RELEASE_COMPATIBILITY_CATEGORIES,
      "known_risks"           => [],
      "last_verified_smoke_route" => RELEASE_SMOKE_ROUTE,
      "host_first"            => true,
      "host_battle_ui_locked" => true,
      "fail_closed"           => true
    }
  end

  def release_default_compatibility_manifest
    worlds = {}
    release_world_ids.each { |id| worlds[id] = release_default_world_profile(id) }
    return {
      "schema_version" => 1,
      "version"       => RELEASE_COMPATIBILITY_VERSION,
      "generated_by"  => FRAMEWORK_MOD_ID,
      "worlds"        => worlds,
      "safety_rules"  => [
        "host save data stays authoritative",
        "canonical location updates only after a valid loaded map and released player state",
        "missing worlds and missing assets rescue to host home and keep dormant metadata",
        "host dex shadow is merged from party and PC instead of reset by imported setup",
        "host battle UI remains locked unless a world UI is certified"
      ]
    }
  end

  def release_hash_get(hash, key)
    return nil if !hash.is_a?(Hash)
    return hash[key] if hash.has_key?(key)
    symbol = key.to_s.to_sym
    return hash[symbol] if hash.has_key?(symbol)
    return nil
  end

  def normalize_release_world_profile(expansion_id, raw_profile)
    profile = release_default_world_profile(expansion_id)
    return profile if !raw_profile.is_a?(Hash)
    raw_profile.each_pair do |key, value|
      text_key = key.to_s
      next if text_key.empty?
      profile[text_key] = value
    end
    profile["id"] = expansion_id.to_s
    profile["display_name"] = normalize_string(profile["display_name"], release_world_display_name(expansion_id))
    profile["status"] = normalize_string(profile["status"], "release_candidate")
    profile["required_categories"] = Array(profile["required_categories"]).map { |category| category.to_s }.uniq
    profile["required_categories"] = RELEASE_COMPATIBILITY_CATEGORIES if profile["required_categories"].empty?
    profile["known_risks"] = Array(profile["known_risks"]).map { |risk| risk.to_s }.reject { |risk| risk.empty? }
    profile["last_verified_smoke_route"] = Array(profile["last_verified_smoke_route"]).map { |step| step.to_s }.reject { |step| step.empty? }
    profile["last_verified_smoke_route"] = RELEASE_SMOKE_ROUTE if profile["last_verified_smoke_route"].empty?
    profile["installed"] = !manifest_for(expansion_id).nil? rescue profile["installed"] == true
    profile["active"] = expansion_active?(expansion_id) rescue profile["active"] == true
    profile["host_first"] = profile["host_first"] != false
    profile["host_battle_ui_locked"] = profile["host_battle_ui_locked"] != false
    profile["fail_closed"] = profile["fail_closed"] != false
    return profile
  end

  def normalize_release_compatibility_manifest(raw)
    manifest = release_default_compatibility_manifest
    return manifest if !raw.is_a?(Hash)
    version = release_hash_get(raw, "version")
    manifest["version"] = normalize_string(version, RELEASE_COMPATIBILITY_VERSION)
    raw_worlds = release_hash_get(raw, "worlds")
    if raw_worlds.is_a?(Array)
      raw_worlds.each do |entry|
        next if !entry.is_a?(Hash)
        id = normalize_string(release_hash_get(entry, "id"), "")
        next if id.empty?
        manifest["worlds"][id] = normalize_release_world_profile(id, entry)
      end
    elsif raw_worlds.is_a?(Hash)
      raw_worlds.each_pair do |id, entry|
        manifest["worlds"][id.to_s] = normalize_release_world_profile(id.to_s, entry)
      end
    end
    release_world_ids.each do |id|
      manifest["worlds"][id] = normalize_release_world_profile(id, manifest["worlds"][id])
    end
    return manifest
  end

  def release_compatibility_manifest
    raw = safe_json_parse(release_compatibility_manifest_path)
    return normalize_release_compatibility_manifest(raw)
  rescue => e
    log("[release] compatibility manifest read failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return release_default_compatibility_manifest
  end

  def refresh_release_compatibility!
    manifest = release_compatibility_manifest
    table = registry(:release_compatibility)
    table.clear
    manifest["worlds"].each_pair { |id, profile| table[id.to_s] = profile }
    root = ensure_save_root rescue nil
    if root && root.respond_to?(:release_manifest_version=)
      root.release_manifest_version = manifest["version"]
    end
    return table
  rescue => e
    log("[release] refresh failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return {}
  end

  def release_world_profile(expansion_id)
    id = expansion_id.to_s
    refresh_release_compatibility! if registry(:release_compatibility).empty?
    return registry(:release_compatibility)[id] || release_default_world_profile(id)
  rescue
    return release_default_world_profile(expansion_id)
  end

  def release_world_status(expansion_id)
    return release_world_profile(expansion_id)["status"].to_s
  rescue
    return "release_candidate"
  end

  def release_world_release_candidate?(expansion_id)
    status = release_world_status(expansion_id)
    return status == "release_candidate" || status == "verified"
  end

  def release_required_shims(expansion_id)
    return Array(release_world_profile(expansion_id)["required_categories"])
  rescue
    return []
  end

  def release_known_risks(expansion_id)
    return Array(release_world_profile(expansion_id)["known_risks"])
  rescue
    return []
  end

  def release_smoke_route(expansion_id)
    return Array(release_world_profile(expansion_id)["last_verified_smoke_route"])
  rescue
    return RELEASE_SMOKE_ROUTE
  end

  def release_deep_copy(value)
    case value
    when Hash
      copy = {}
      value.each_pair { |key, entry| copy[key] = release_deep_copy(entry) }
      return copy
    when Array
      return value.map { |entry| release_deep_copy(entry) }
    else
      return value
    end
  rescue
    return value
  end

  def release_default_shim_catalog
    return {
      "schema_version" => 1,
      "version"       => RELEASE_COMPATIBILITY_VERSION,
      "shims"         => release_deep_copy(RELEASE_GENERIC_SHIM_CATALOG)
    }
  end

  def normalize_release_shim_catalog(raw)
    catalog = release_default_shim_catalog
    return catalog if !raw.is_a?(Hash)
    version = release_hash_get(raw, "version")
    catalog["version"] = normalize_string(version, RELEASE_COMPATIBILITY_VERSION)
    raw_shims = release_hash_get(raw, "shims")
    if raw_shims.is_a?(Hash)
      raw_shims.each_pair do |name, entry|
        next if !entry.is_a?(Hash)
        normalized = {}
        entry.each_pair { |key, value| normalized[key.to_s] = value }
        normalized["category"] = normalize_string(normalized["category"], "missing_api")
        normalized["default"] = normalize_string(normalized["default"], "true")
        catalog["shims"][name.to_s] = normalized
      end
    end
    return catalog
  end

  def release_shim_catalog
    table = registry(:release_shims)
    return table if !table.empty?
    raw = safe_json_parse(release_shim_catalog_path)
    catalog = normalize_release_shim_catalog(raw)
    table.clear
    catalog["shims"].each_pair { |name, entry| table[name.to_s] = entry }
    return table
  rescue => e
    log("[release] shim catalog read failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return release_deep_copy(RELEASE_GENERIC_SHIM_CATALOG)
  end

  def release_shim_entry(name)
    return release_shim_catalog[name.to_s] || RELEASE_GENERIC_SHIM_CATALOG[name.to_s]
  rescue
    return nil
  end

  def release_current_context_expansion_id
    id = current_runtime_expansion_id if respond_to?(:current_runtime_expansion_id)
    id = current_expansion_id if (id.nil? || id.to_s.empty?) && respond_to?(:current_expansion_id)
    id = current_map_expansion_id if (id.nil? || id.to_s.empty?) && respond_to?(:current_map_expansion_id)
    id = HOST_EXPANSION_ID if id.nil? || id.to_s.empty?
    return id.to_s
  rescue
    return HOST_EXPANSION_ID
  end

  def release_shim_hit_store
    @release_shim_hit_counts ||= {}
    return @release_shim_hit_counts
  end

  def record_release_shim_hit(name, category = nil, disposition = nil, expansion_id = nil)
    entry = release_shim_entry(name) || {}
    category ||= entry["category"] || "missing_api"
    disposition ||= entry["default"] || "true"
    expansion_id ||= release_current_context_expansion_id
    key = [expansion_id.to_s, category.to_s, name.to_s, disposition.to_s].join("|")
    store = release_shim_hit_store
    store[key] = integer(store[key], 0) + 1
    root = ensure_save_root rescue nil
    if root && root.respond_to?(:release_shim_hits)
      root.release_shim_hits ||= {}
      root.release_shim_hits[expansion_id.to_s] ||= {}
      root.release_shim_hits[expansion_id.to_s][name.to_s] = store[key]
    end
    if store[key] == 1 || (store[key] % 25) == 0
      log("[release] shim #{name} used in #{expansion_id} category=#{category} disposition=#{disposition} count=#{store[key]}") if respond_to?(:log)
    end
    return store[key]
  rescue => e
    log("[release] shim hit record failed for #{name}: #{e.class}: #{e.message}") if respond_to?(:log)
    return 0
  end

  def release_default_value(default_name, args = [])
    case default_name.to_s
    when "true"
      return true
    when "false"
      return false
    when "nil"
      return nil
    when "zero"
      return 0
    when "array"
      return []
    when "hash"
      return {}
    when "first_arg"
      return args[0]
    when "empty_string"
      return ""
    when "portrait_message"
      return release_portrait_message(args[0], *Array(args[1..-1]))
    when "void_character_setup"
      return release_void_character_setup(*args)
    when "void_rival_name"
      slot = integer(args[0], 1)
      return ["Ronan", "Nia", "Seren"][slot - 1] || "Rival"
    when "void_rival_pronoun"
      key = args[1].respond_to?(:to_sym) ? args[1].to_sym : args[1]
      pronouns = {
        :subject => "they",
        :object => "them",
        :possessive_adjective => "their",
        :possessive_pronoun => "theirs",
        :reflexive => "themself",
        :be_present => "are",
        :be_past => "were",
        :have_present => "have",
        :do_present => "do"
      }
      return pronouns[key] || pronouns[:subject]
    when "party_present"
      party = ($Trainer.party rescue [])
      return Array(party).compact.length > 0
    when "heal_party"
      release_heal_party!
      return true
    when "host_pc"
      release_open_host_pc!
      return true
    when "host_mart"
      release_open_host_mart!
      return true
    when "host_exp_all"
      return release_host_exp_all_enabled?
    when "starter_species"
      return early_build_imported_starter(args[0], args[2] || args[1]) if respond_to?(:early_build_imported_starter)
      return early_pick_imported_starter(args[0], args[2] || args[1]) if respond_to?(:early_pick_imported_starter)
      return release_random_available_species([
        :BULBASAUR, :CHARMANDER, :SQUIRTLE, :PIKACHU, :EEVEE,
        :CHIKORITA, :CYNDAQUIL, :TOTODILE, :TREECKO, :TORCHIC, :MUDKIP
      ])
    when "host_safe_challenge"
      return early_battle_challenge if respond_to?(:early_battle_challenge)
      return true
    when "challenge_rules"
      return EarlyChallengeRules.new if const_defined?(:EarlyChallengeRules)
      return true
    else
      return true
    end
  rescue
    return true
  end

  def release_void_character_setup(*args)
    record_release_shim_hit("pbVoidCharacterSetup", "startup", "host_identity")
    variable_ids = Array(args).flatten.compact
    variable_ids.each do |raw_id|
      variable_id = integer(raw_id, 0)
      next if variable_id <= 0
      $game_variables[variable_id] = 1 if defined?($game_variables) && $game_variables
    end
    apply_host_player_visuals!("pokemon_void") if respond_to?(:apply_host_player_visuals!)
    log("[release] Void character setup preserved host identity #{variable_ids.inspect}") if respond_to?(:log)
    return true
  rescue => e
    log("[release] Void character setup skipped safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def release_portrait_message(message = nil, *args)
    record_release_shim_hit("pbPortraitMessage", "menu_settings", "host_message")
    text = message.to_s
    return true if text.empty?
    begin
      return Kernel.send(:pbMessage, text) if defined?(Kernel) && Kernel.respond_to?(:pbMessage, true)
      return Object.new.send(:pbMessage, text) if Object.respond_to?(:private_method_defined?) && Object.private_method_defined?(:pbMessage)
    rescue => e
      log("[release] portrait message fallback failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    end
    return true
  rescue => e
    log("[release] portrait message failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def release_species_available?(species)
    candidate = species.respond_to?(:species) ? species.species : species
    return false if candidate.nil?
    candidate = candidate.to_sym if candidate.respond_to?(:to_sym)
    return !GameData::Species.try_get(candidate).nil? if defined?(GameData::Species) && GameData::Species.respond_to?(:try_get)
    return true if !defined?(GameData::Species) || !GameData::Species.respond_to?(:exists?)
    return GameData::Species.exists?(candidate)
  rescue
    return false
  end

  def release_random_available_species(species_pool, fallback = :PIKACHU)
    pool = Array(species_pool).flatten.compact
    pool = [fallback] if pool.empty?
    shuffled = pool.sort_by { rand }
    chosen = shuffled.find { |entry| release_species_available?(entry) }
    chosen ||= fallback if release_species_available?(fallback)
    return chosen
  rescue
    return fallback
  end

  RELEASE_IMPORTED_BATTLE_RULE_FLAGS = {
    "single"              => ["size", "single"],
    "1v1"                 => ["size", "1v1"],
    "1v2"                 => ["size", "1v2"],
    "2v1"                 => ["size", "2v1"],
    "1v3"                 => ["size", "1v3"],
    "3v1"                 => ["size", "3v1"],
    "double"              => ["size", "double"],
    "2v2"                 => ["size", "2v2"],
    "2v3"                 => ["size", "2v3"],
    "3v2"                 => ["size", "3v2"],
    "triple"              => ["size", "triple"],
    "3v3"                 => ["size", "3v3"],
    "alwayscapture"       => ["captureSuccess", true],
    "nevercapture"        => ["captureSuccess", false],
    "tutorialcapture"     => ["captureTutorial", true],
    "autobattle"          => ["autoBattle", true],
    "towerbattle"         => ["internalBattle", false],
    "inversebattle"       => ["inverseBattle", true],
    "nobag"               => ["noBag", true],
    "disablepokeballs"    => ["disablePokeBalls", true],
    "forcecatchintoparty" => ["forceCatchIntoParty", true],
    "canlose"             => ["canLose", true],
    "cannotlose"          => ["canLose", false],
    "canrun"              => ["canRun", true],
    "cannotrun"           => ["canRun", false],
    "roamerflees"         => ["roamerFlees", true],
    "noexp"               => ["expGain", false],
    "nomoney"             => ["moneyGain", false],
    "nopartner"           => ["noPartner", true],
    "switchstyle"         => ["switchStyle", true],
    "setstyle"            => ["switchStyle", false],
    "anims"               => ["battleAnims", true],
    "noanims"             => ["battleAnims", false],
    "wildmegaevolution"   => ["wildBattleMode", :mega],
    "internalbattle"      => ["internalBattle", false],
    "inverse"             => ["inverseBattle", true]
  }.freeze unless const_defined?(:RELEASE_IMPORTED_BATTLE_RULE_FLAGS)

  RELEASE_IMPORTED_BATTLE_RULE_VALUES = {
    "terrain"           => "defaultTerrain",
    "weather"           => "defaultWeather",
    "environment"       => "environment",
    "environ"           => "environment",
    "backdrop"          => "backdrop",
    "battleback"        => "backdrop",
    "base"              => "base",
    "outcome"           => "outcomeVar",
    "outcomevar"        => "outcomeVar",
    "raidstylecapture"  => "raidStyleCapture",
    "setslidesprite"    => "slideSpriteStyle",
    "databoxstyle"      => "databoxStyle",
    "battleintrotext"   => "battleIntroText",
    "opponentwintext"   => "opposingWinText",
    "opponentlosetext"  => "opposingLoseText",
    "tempplayer"        => "tempPlayer",
    "tempbag"           => "tempBag",
    "tempparty"         => "tempParty",
    "battlebgm"         => "battleBGM",
    "victorybgm"        => "victoryBGM",
    "captureme"         => "captureME",
    "lowhealthbgm"      => "lowHealthBGM",
    "editwildpokemon"   => "editWildPokemon",
    "editwildpokemon2"  => "editWildPokemon2",
    "editwildpokemon3"  => "editWildPokemon3",
    "nomegaevolution"   => "noMegaEvolution",
    "midbattlescript"   => "midbattleScript",
    "wildbattlemode"    => "wildBattleMode",
    "capturesuccess"    => "captureSuccess",
    "capturetutorial"   => "captureTutorial",
    "battleanims"       => "battleAnims"
  }.freeze unless const_defined?(:RELEASE_IMPORTED_BATTLE_RULE_VALUES)

  def release_battle_rule_key(rule)
    return rule.to_s.downcase
  rescue
    return ""
  end

  def release_battle_rules_hash
    temp = defined?($PokemonTemp) ? $PokemonTemp : nil
    temp = defined?($game_temp) ? $game_temp : temp if !temp || !temp.respond_to?(:battleRules)
    return nil if !temp
    return temp.battleRules if temp.respond_to?(:battleRules)
    return temp.battle_rules if temp.respond_to?(:battle_rules)
    return nil
  rescue
    return nil
  end

  def release_record_imported_battle_rule!(rule, value = nil, has_value = false)
    key = release_battle_rule_key(rule)
    rules = release_battle_rules_hash
    return false if key.empty? || !rules.respond_to?(:[]=)
    if RELEASE_IMPORTED_BATTLE_RULE_FLAGS.has_key?(key)
      storage_key, storage_value = RELEASE_IMPORTED_BATTLE_RULE_FLAGS[key]
      rules[storage_key] = storage_value
      record_release_shim_hit("setBattleRule", "trainer_battle", key)
      return true
    end
    if RELEASE_IMPORTED_BATTLE_RULE_VALUES.has_key?(key)
      rules[RELEASE_IMPORTED_BATTLE_RULE_VALUES[key]] = value if has_value
      record_release_shim_hit("setBattleRule", "trainer_battle", has_value ? key : "#{key}:missing_value")
      return true
    end
    return false
  rescue => e
    log("[release] imported battle rule #{rule.inspect} failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def release_safe_set_battle_rule!(*args)
    pending = nil
    handled = false
    args.each do |arg|
      if pending
        handled = release_record_imported_battle_rule!(pending, arg, true) || handled
        pending = nil
        next
      end
      key = release_battle_rule_key(arg)
      if RELEASE_IMPORTED_BATTLE_RULE_VALUES.has_key?(key)
        pending = key
        next
      end
      handled = release_record_imported_battle_rule!(key, nil, false) || handled
    end
    record_release_shim_hit("setBattleRule", "trainer_battle", "#{pending}:missing_value") if pending
    return handled
  rescue => e
    log("[release] setBattleRule fallback failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def release_safe_stub(name, default_name = nil, category = nil, *args)
    entry = release_shim_entry(name) || {}
    default_name ||= entry["default"] || "true"
    category ||= entry["category"] || "missing_api"
    record_release_shim_hit(name, category, default_name)
    return release_default_value(default_name, args)
  end

  def release_interpreter_method_shim_name?(name)
    return true if [
      "activateQuest", "activateQuestSilent", "advanceQuestSilent",
      "advanceQuestToStage", "completeQuest", "completeQuestSilent",
      "getQuestStage", "getCurrentStage", "getActiveQuests",
      "getCompletedQuests", "colorQuest", "pbStartQuest",
      "pbCompleteQuest", "pbQuestStatus", "pbQuestStarted?",
      "pbQuestComplete?", "pbQuestKnown?"
    ].include?(name.to_s)
    return !release_shim_entry(name.to_s).nil?
  rescue
    return false
  end

  def release_interpreter_method_shim(name, *args)
    text = name.to_s
    case text
    when "activateQuest", "activateQuestSilent"
      return {
        :handled => true,
        :value => release_activate_quest!(args[0], nil, text == "activateQuestSilent", *args[1..-1])
      }
    when "advanceQuestSilent"
      return { :handled => true, :value => release_advance_quest!(args[0], nil, *args[1..-1]) }
    when "advanceQuestToStage"
      return { :handled => true, :value => release_advance_quest!(args[0], args[1], *args[2..-1]) }
    when "completeQuest", "completeQuestSilent"
      return {
        :handled => true,
        :value => release_complete_quest!(args[0], text == "completeQuestSilent", *args[1..-1])
      }
    when "getQuestStage", "getCurrentStage"
      return { :handled => true, :value => release_quest_stage(args[0]) }
    when "pbStartQuest"
      return { :handled => true, :value => release_activate_quest!(args[0], nil, true, *args[1..-1]) }
    when "pbCompleteQuest"
      return { :handled => true, :value => release_complete_quest!(args[0], true, *args[1..-1]) }
    when "pbQuestStatus"
      return { :handled => true, :value => release_quest_stage(args[0]) }
    when "pbQuestStarted?", "pbQuestKnown?"
      return { :handled => true, :value => release_quest_started?(args[0]) }
    when "pbQuestComplete?"
      return { :handled => true, :value => release_quest_completed?(args[0]) }
    when "getActiveQuests"
      return { :handled => true, :value => release_quest_store(:active) }
    when "getCompletedQuests"
      return { :handled => true, :value => release_quest_store(:completed) }
    when "colorQuest"
      record_release_shim_hit("colorQuest", "menu_settings", "first_arg")
      return { :handled => true, :value => args[0] }
    end
    entry = release_shim_entry(name.to_s)
    return nil if !entry.is_a?(Hash)
    category = entry["category"] || "missing_api"
    default_name = entry["default"] || "true"
    value = release_safe_stub(name.to_s, default_name, category, *args)
    return { :handled => true, :value => value }
  rescue => e
    log("[release] interpreter shim #{name} failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return { :handled => true, :value => true }
  end

  def release_unlock_recipe!(recipe_id = nil, *args)
    if respond_to?(:keishou_unlock_recipe) &&
       (!respond_to?(:keishou_active_now?) || keishou_active_now? ||
        (respond_to?(:keishou_recipe_record_for) && keishou_recipe_record_for(recipe_id)))
      return keishou_unlock_recipe(recipe_id)
    end
    return release_safe_stub("pbUnlockRecipe", "true", "item_handlers", recipe_id, *args)
  rescue => e
    log("[release] pbUnlockRecipe failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def release_lock_recipe!(recipe_id = nil, *args)
    if respond_to?(:keishou_lock_recipe) &&
       (!respond_to?(:keishou_active_now?) || keishou_active_now? ||
        (respond_to?(:keishou_recipe_record_for) && keishou_recipe_record_for(recipe_id)))
      return keishou_lock_recipe(recipe_id)
    end
    return release_safe_stub("pbLockRecipe", "true", "item_handlers", recipe_id, *args)
  rescue => e
    log("[release] pbLockRecipe failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def release_recipe_ids_for_flag(flag = nil, *args)
    if respond_to?(:keishou_recipe_ids_for_flag) &&
       (!respond_to?(:keishou_active_now?) || keishou_active_now?)
      return keishou_recipe_ids_for_flag(flag)
    end
    record_release_shim_hit("pbGetRecipes", "item_handlers", "array")
    return []
  rescue => e
    log("[release] pbGetRecipes failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return []
  end

  def release_item_crafter(stock = nil, speech1 = nil, speech2 = nil, *args)
    if respond_to?(:keishou_craft_from_recipe_list) &&
       (!respond_to?(:keishou_active_now?) || keishou_active_now?)
      return keishou_craft_from_recipe_list(stock, speech1, speech2)
    end
    return release_safe_stub("pbItemCrafter", "true", "item_handlers", stock, speech1, speech2, *args)
  rescue => e
    log("[release] pbItemCrafter failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def release_heal_party!
    if defined?(pbHealAll)
      pbHealAll
      return true
    end
    party = ($Trainer.party rescue [])
    Array(party).compact.each do |pokemon|
      if pokemon.respond_to?(:heal)
        pokemon.heal
        next
      end
      if pokemon.respond_to?(:totalhp) && pokemon.respond_to?(:hp=)
        pokemon.hp = pokemon.totalhp rescue nil
      end
      pokemon.status = nil if pokemon.respond_to?(:status=)
      pokemon.statusCount = 0 if pokemon.respond_to?(:statusCount=)
    end
    return true
  rescue => e
    log("[release] heal party fallback failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def release_open_host_pc!
    if defined?(pbPokeCenterPC)
      pbPokeCenterPC
      return true
    end
    if defined?(PokemonStorageScene) && defined?(PokemonStorageScreen) && defined?($PokemonStorage) && $PokemonStorage
      pbFadeOutIn {
        scene = PokemonStorageScene.new
        screen = PokemonStorageScreen.new(scene, $PokemonStorage)
        screen.pbStartScreen(0)
      }
      return true
    end
    return true
  rescue => e
    log("[release] host PC fallback failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def release_item_exists?(item)
    return GameData::Item.exists?(item) if defined?(GameData::Item) && GameData::Item.respond_to?(:exists?)
    return !GameData::Item.get(item).nil? if defined?(GameData::Item) && GameData::Item.respond_to?(:get)
    return true
  rescue
    return false
  end

  def release_default_mart_stock
    badges = 0
    if defined?($Trainer) && $Trainer
      badges = integer($Trainer.badge_count, 0) if $Trainer.respond_to?(:badge_count)
      badges = integer($Trainer.numbadges, badges) if badges <= 0 && $Trainer.respond_to?(:numbadges)
    end
    stock = case badges
            when 0
              [:POTION, :ANTIDOTE, :POKEBALL]
            when 1
              [:POTION, :ANTIDOTE, :PARLYZHEAL, :BURNHEAL, :ESCAPEROPE, :REPEL, :POKEBALL]
            when 2..5
              [:SUPERPOTION, :ANTIDOTE, :PARLYZHEAL, :BURNHEAL, :ESCAPEROPE, :SUPERREPEL, :POKEBALL]
            when 6..9
              [:SUPERPOTION, :ANTIDOTE, :PARLYZHEAL, :BURNHEAL, :ESCAPEROPE, :SUPERREPEL, :POKEBALL, :GREATBALL]
            else
              [:POKEBALL, :GREATBALL, :ULTRABALL, :SUPERREPEL, :MAXREPEL, :ESCAPEROPE, :FULLHEAL, :HYPERPOTION]
            end
    stock.find_all { |item| release_item_exists?(item) }
  rescue => e
    log("[release] default mart stock build failed: #{e.class}: #{e.message}") if respond_to?(:log)
    [:POTION, :ANTIDOTE, :POKEBALL].find_all { |item| release_item_exists?(item) }
  end

  def release_open_host_mart!(stock = nil, speech = nil, cantsell = false)
    stock = release_default_mart_stock if !stock.is_a?(Array) || stock.empty?
    stock = stock.find_all { |item| release_item_exists?(item) }
    stock = [:POTION, :POKEBALL].find_all { |item| release_item_exists?(item) } if stock.empty?
    if Kernel.respond_to?(:pbPokemonMart)
      Kernel.pbPokemonMart(stock, speech, cantsell)
      return true
    end
    if Object.private_method_defined?(:pbPokemonMart) || Object.method_defined?(:pbPokemonMart)
      Object.new.send(:pbPokemonMart, stock, speech, cantsell)
      return true
    end
    if defined?(pbPokemonMart)
      pbPokemonMart(stock, speech, cantsell)
      return true
    end
    if Kernel.respond_to?(:pbMessage)
      Kernel.pbMessage("The Poke Mart service is not available right now.")
    elsif defined?(pbMessage)
      pbMessage("The Poke Mart service is not available right now.")
    end
    return true
  rescue => e
    log("[release] host mart fallback failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def release_truthy?(value)
    return true if value == true
    return false if value == false || value.nil?
    return value != 0 if value.is_a?(Numeric)
    text = value.to_s.strip.downcase
    return true if ["1", "true", "on", "yes", "enabled"].include?(text)
    return false if ["0", "false", "off", "no", "disabled"].include?(text)
    return !text.empty?
  rescue
    return false
  end

  def release_host_exp_all_enabled?
    return false if !defined?($PokemonBag) || !$PokemonBag
    if release_item_exists?(:EXPALL) && $PokemonBag.pbHasItem?(:EXPALL)
      return true
    end
    if release_item_exists?(:EXPALLOFF) && $PokemonBag.pbHasItem?(:EXPALLOFF)
      return false
    end
    return false
  rescue
    return false
  end

  def release_set_host_exp_all!(enabled)
    enabled = release_truthy?(enabled)
    record_release_shim_hit("Player#expall", "menu_settings", enabled ? "true" : "false")
    return enabled if !defined?($PokemonBag) || !$PokemonBag
    exp_all_exists = release_item_exists?(:EXPALL)
    exp_all_off_exists = release_item_exists?(:EXPALLOFF)
    if enabled
      if exp_all_exists && exp_all_off_exists && $PokemonBag.pbHasItem?(:EXPALLOFF)
        $PokemonBag.pbChangeItem(:EXPALLOFF, :EXPALL)
      elsif exp_all_exists && !$PokemonBag.pbHasItem?(:EXPALL)
        $PokemonBag.pbStoreItem(:EXPALL, 1)
      end
    elsif exp_all_exists && exp_all_off_exists && $PokemonBag.pbHasItem?(:EXPALL)
      $PokemonBag.pbChangeItem(:EXPALL, :EXPALLOFF)
    end
    return enabled
  rescue => e
    log("[release] host Exp All bridge failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return enabled
  end

  def release_quest_store(key)
    return [] if !defined?($PokemonGlobal) || !$PokemonGlobal
    ivar = key == :completed ? :@tef_completed_quests : :@tef_active_quests
    $PokemonGlobal.instance_variable_set(ivar, []) if !$PokemonGlobal.instance_variable_defined?(ivar)
    value = $PokemonGlobal.instance_variable_get(ivar)
    value = [] if !value.is_a?(Array)
    $PokemonGlobal.instance_variable_set(ivar, value)
    return value
  rescue
    return []
  end

  def release_quest_stage_store
    return {} if !defined?($PokemonGlobal) || !$PokemonGlobal
    ivar = :@tef_quest_stages
    $PokemonGlobal.instance_variable_set(ivar, {}) if !$PokemonGlobal.instance_variable_defined?(ivar)
    value = $PokemonGlobal.instance_variable_get(ivar)
    value = {} if !value.is_a?(Hash)
    $PokemonGlobal.instance_variable_set(ivar, value)
    return value
  rescue
    return {}
  end

  def release_activate_quest!(quest, stage = nil, silent = false, *_args)
    active = release_quest_store(:active)
    active << quest if !quest.nil? && !active.include?(quest)
    if !quest.nil? && !stage.nil?
      release_quest_stage_store[quest] = integer(stage, 0)
    end
    record_release_shim_hit(silent ? "activateQuestSilent" : "activateQuest", "menu_settings", "host_quest_store")
    return true
  rescue => e
    log("[release] quest activation failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def release_advance_quest!(quest, stage = nil, *_args)
    active = release_quest_store(:active)
    active << quest if !quest.nil? && !active.include?(quest)
    release_quest_stage_store[quest] = integer(stage, 0) if !quest.nil? && !stage.nil?
    record_release_shim_hit(stage.nil? ? "advanceQuestSilent" : "advanceQuestToStage", "menu_settings", "host_quest_store")
    return true
  rescue => e
    log("[release] quest advance failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def release_complete_quest!(quest, silent = false, *_args)
    completed = release_quest_store(:completed)
    completed << quest if !quest.nil? && !completed.include?(quest)
    active = release_quest_store(:active)
    active.delete(quest)
    record_release_shim_hit(silent ? "completeQuestSilent" : "completeQuest", "menu_settings", "host_quest_store")
    return true
  rescue => e
    log("[release] quest completion failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    return true
  end

  def release_quest_stage(quest)
    return integer(release_quest_stage_store[quest], 0)
  rescue
    return 0
  end

  def release_quest_started?(quest)
    return false if quest.nil?
    return true if release_quest_store(:active).include?(quest)
    return true if release_quest_store(:completed).include?(quest)
    return release_quest_stage_store.has_key?(quest)
  rescue
    return false
  end

  def release_quest_completed?(quest)
    return false if quest.nil?
    return release_quest_store(:completed).include?(quest)
  rescue
    return false
  end

  def release_constant_fallback(name)
    text = name.to_s
    record_release_shim_hit("constant #{text}", "missing_constant", "fallback")
    return ::TrainerBattle if text == "TrainerBattle" && defined?(::TrainerBattle)
    return ::BattleScripting if text == "BattleScripting" && defined?(::BattleScripting)
    return ::PartyPicture if text == "PartyPicture" && defined?(::PartyPicture)
    return ::ChangeSpeed if text == "ChangeSpeed" && defined?(::ChangeSpeed)
    return ::GenderPickSelection if text == "GenderPickSelection" && defined?(::GenderPickSelection)
    return ::GameMode_Scene if text == "GameMode_Scene" && defined?(::GameMode_Scene)
    return ::GameModeScreen if text == "GameModeScreen" && defined?(::GameModeScreen)
    return ::DiegoWTsStarterSelection if text == "DiegoWTsStarterSelection" && defined?(::DiegoWTsStarterSelection)
    return ::ChallengeModes if text == "ChallengeModes" && defined?(::ChallengeModes)
    return ::LevelCapsEX if text == "LevelCapsEX" && defined?(::LevelCapsEX)
    return ::EncounterTypes if text == "EncounterTypes" && defined?(::EncounterTypes)
    return ::PokemonSelection if text == "PokemonSelection" && defined?(::PokemonSelection)
    return ::MessageConfig if text == "MessageConfig" && defined?(::MessageConfig)
    return ::PokemonEntryScene if text == "PokemonEntryScene" && defined?(::PokemonEntryScene)
    return ::PokemonEntry if text == "PokemonEntry" && defined?(::PokemonEntry)
    return early_random_all_types_pool if text == "RANDOM_ALL_TYPES" && respond_to?(:early_random_all_types_pool)
    return [:BULBASAUR, :CHARMANDER, :SQUIRTLE, :PIKACHU, :EEVEE] if text == "RANDOM_ALL_TYPES"
    return :DrewQuest if text == "DrewQuest"
    return nil
  rescue
    return nil
  end

  def release_encounter_type_symbol(encounter_type)
    return nil if encounter_type.nil?
    return encounter_type if defined?(GameData::EncounterType) &&
                             GameData::EncounterType.respond_to?(:exists?) &&
                             GameData::EncounterType.exists?(encounter_type)
    if encounter_type.is_a?(Integer)
      legacy_map = {
        0  => :Land,
        1  => :Cave,
        2  => :Water,
        3  => :OldRod,
        4  => :GoodRod,
        5  => :SuperRod,
        6  => :RockSmash,
        7  => :HeadbuttLow,
        8  => :HeadbuttHigh,
        9  => :LandMorning,
        10 => :LandDay,
        11 => :LandNight,
        12 => :BugContest,
        13 => :Land
      }
      return legacy_map[encounter_type] || :Land
    end
    key = encounter_type.to_s.split("::").last.to_s.downcase.gsub(/[^a-z0-9]+/, "")
    return nil if key.empty?
    aliases = {
      "land"          => :Land,
      "grass"         => :Land,
      "landmorning"   => :LandMorning,
      "landday"       => :LandDay,
      "landnight"     => :LandNight,
      "landafternoon" => :LandAfternoon,
      "landevening"   => :LandEvening,
      "land1"         => :Land1,
      "land2"         => :Land2,
      "land3"         => :Land3,
      "cave"          => :Cave,
      "cavemorning"   => :CaveMorning,
      "caveday"       => :CaveDay,
      "cavenight"     => :CaveNight,
      "caveafternoon" => :CaveAfternoon,
      "caveevening"   => :CaveEvening,
      "water"         => :Water,
      "surf"          => :Water,
      "watermorning"  => :WaterMorning,
      "waterday"      => :WaterDay,
      "waternight"    => :WaterNight,
      "oldrod"        => :OldRod,
      "goodrod"       => :GoodRod,
      "superrod"      => :SuperRod,
      "rocksmash"     => :RockSmash,
      "headbuttlow"   => :HeadbuttLow,
      "headbutthigh"  => :HeadbuttHigh,
      "bugcontest"    => :BugContest
    }
    return aliases[key] if aliases[key]
    return encounter_type.to_sym if encounter_type.respond_to?(:to_sym)
    return nil
  rescue
    return nil
  end

  def release_encounter_type_candidates(encounter_type)
    primary = release_encounter_type_symbol(encounter_type)
    candidates = []
    candidates << primary if primary
    if respond_to?(:expansion_compatible_encounter_types)
      Array(expansion_compatible_encounter_types(primary)).each { |type| candidates << type }
    end
    family = expansion_encounter_type_family(primary) if primary && respond_to?(:expansion_encounter_type_family)
    family ||= begin
      data = GameData::EncounterType.try_get(primary) rescue nil
      data.respond_to?(:type) ? data.type : nil
    end
    case family
    when :land, :contest
      candidates += [:Land, :LandMorning, :LandDay, :LandNight, :LandAfternoon, :LandEvening, :Land1, :Land2, :Land3, :Cave]
    when :cave
      candidates += [:Cave, :CaveMorning, :CaveDay, :CaveNight, :CaveAfternoon, :CaveEvening, :Land]
    when :water
      candidates += [:Water, :WaterMorning, :WaterDay, :WaterNight, :WaterAfternoon, :WaterEvening]
    when :fishing
      candidates += [:OldRod, :GoodRod, :SuperRod]
    else
      candidates += [:Land, :Cave, :Water]
    end
    current_type = $PokemonEncounters.encounter_type rescue nil
    candidates << current_type if current_type
    candidates.compact.uniq.find_all do |type|
      defined?(GameData::EncounterType) &&
        GameData::EncounterType.respond_to?(:exists?) &&
        GameData::EncounterType.exists?(type)
    end
  rescue
    [:Land, :Cave, :Water]
  end

  def release_trigger_encounter!(encounter_type = nil, *_args)
    return false if !defined?($PokemonEncounters) || !$PokemonEncounters
    if $PokemonEncounters.respond_to?(:tef_expansion_ensure_current_map_table!)
      $PokemonEncounters.tef_expansion_ensure_current_map_table! rescue nil
    end
    candidates = release_encounter_type_candidates(encounter_type)
    candidates.each do |type|
      encounter = $PokemonEncounters.choose_wild_pokemon(type) rescue nil
      next if !encounter
      encounter = EncounterModifier.trigger(encounter) if defined?(EncounterModifier)
      next if !encounter
      $PokemonTemp.encounterType = type if defined?($PokemonTemp) && $PokemonTemp && $PokemonTemp.respond_to?(:encounterType=)
      record_release_shim_hit("pbEncounter", "encounters", type.to_s)
      return pbConfiguredWildBattle(type, encounter) if defined?(pbConfiguredWildBattle)
      return pbWildBattle(encounter[0], encounter[1]) if defined?(pbWildBattle)
      return true
    end
    log("[release] scripted encounter failed closed for #{encounter_type.inspect} on map #{$game_map.map_id rescue 'n/a'}") if respond_to?(:log)
    record_release_shim_hit("pbEncounter", "encounters", "false")
    return false
  rescue => e
    log("[release] scripted encounter failed safely: #{e.class}: #{e.message}") if respond_to?(:log)
    record_release_shim_hit("pbEncounter", "encounters", "false")
    return false
  end

  def release_capture_bookkeeping_depth
    @release_capture_bookkeeping_depth ||= 0
  end

  def release_fast_capture_bookkeeping?
    return release_capture_bookkeeping_depth > 0
  rescue
    return false
  end

  def with_release_fast_capture_bookkeeping
    @release_capture_bookkeeping_depth = release_capture_bookkeeping_depth + 1
    return yield if block_given?
  ensure
    @release_capture_bookkeeping_depth = [release_capture_bookkeeping_depth - 1, 0].max
  end

  def release_autosave_enabled?
    return false if !defined?($Trainer) || !$Trainer || !$Trainer.respond_to?(:save_slot) || !$Trainer.save_slot
    return false if !defined?($game_switches) || !$game_switches
    autosave_switch = defined?(AUTOSAVE_ENABLED_SWITCH) ? AUTOSAVE_ENABLED_SWITCH : 48
    return $game_switches[autosave_switch] == true
  rescue
    return false
  end

  def release_scene_busy_for_autosave?
    return true if !defined?($scene) || !$scene.is_a?(Scene_Map)
    if defined?($game_temp) && $game_temp
      return true if $game_temp.in_battle rescue false
      return true if $game_temp.in_menu rescue false
      return true if $game_temp.message_window_showing rescue false
      return true if $game_temp.player_transferring rescue false
      return true if $game_temp.transition_processing rescue false
    end
    if defined?($game_system) && $game_system &&
       $game_system.respond_to?(:map_interpreter) &&
       $game_system.map_interpreter &&
       $game_system.map_interpreter.respond_to?(:running?)
      return true if $game_system.map_interpreter.running?
    end
    return false
  rescue
    return true
  end

  def release_request_deferred_autosave!(delay_frames = 18)
    return false if !defined?(DeferredAutosave) || !DeferredAutosave.respond_to?(:request)
    return false if !release_autosave_enabled?
    DeferredAutosave.request(delay_frames)
    record_release_shim_hit("DeferredAutosave.request", "save_load_recovery", "deferred")
    return true
  rescue => e
    log("[release] deferred autosave request failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return false
  end

  def write_release_index_report!
    refresh_release_compatibility! if registry(:release_compatibility).empty?
    report = {
      "generated_at"       => timestamp_string,
      "framework_version"  => VERSION,
      "manifest_version"   => RELEASE_COMPATIBILITY_VERSION,
      "host_first"         => true,
      "host_battle_ui_locked" => true,
      "worlds"             => registry(:release_compatibility),
      "shim_hits"          => release_shim_hit_store
    }
    return write_json_report("release_compatibility_index.json", report) if respond_to?(:write_json_report)
    return nil
  rescue => e
    log("[release] index report failed: #{e.class}: #{e.message}") if respond_to?(:log)
    return nil
  end
end

def pbZoomIn(*args)
  return TravelExpansionFramework.release_safe_stub("pbZoomIn", "true", "map_visual", *args)
end unless defined?(pbZoomIn)

def pbZoomOut(*args)
  return TravelExpansionFramework.release_safe_stub("pbZoomOut", "true", "map_visual", *args)
end unless defined?(pbZoomOut)

def pbWatchTV(*args)
  return TravelExpansionFramework.release_safe_stub("pbWatchTV", "true", "item_handlers", *args)
end unless defined?(pbWatchTV)

def pbCheckRoaming(*args)
  return TravelExpansionFramework.release_safe_stub("pbCheckRoaming", "false", "encounters", *args)
end unless defined?(pbCheckRoaming)

def pbFieldDamage(*args)
  return TravelExpansionFramework.release_safe_stub("pbFieldDamage", "true", "encounters", *args)
end unless defined?(pbFieldDamage)

def pbCaveEntranceEx(*args)
  return TravelExpansionFramework.release_safe_stub("pbCaveEntranceEx", "true", "story_transfer", *args)
end unless defined?(pbCaveEntranceEx)

def pbCaveEntrance(*args)
  return TravelExpansionFramework.release_safe_stub("pbCaveEntrance", "true", "story_transfer", *args)
end unless defined?(pbCaveEntrance)

def pbCaveExit(*args)
  return TravelExpansionFramework.release_safe_stub("pbCaveExit", "true", "story_transfer", *args)
end unless defined?(pbCaveExit)

def pbSetEscapePoint(*args)
  return TravelExpansionFramework.release_safe_stub("pbSetEscapePoint", "true", "story_transfer", *args)
end unless defined?(pbSetEscapePoint)

def pbEraseEscapePoint(*args)
  return TravelExpansionFramework.release_safe_stub("pbEraseEscapePoint", "true", "story_transfer", *args)
end unless defined?(pbEraseEscapePoint)

def pbSetEventTime(*args)
  return TravelExpansionFramework.release_safe_stub("pbSetEventTime", "true", "story_transfer", *args)
end unless defined?(pbSetEventTime)

def characterRestore(*args)
  return TravelExpansionFramework.release_safe_stub("characterRestore", "true", "story_transfer", *args)
end unless defined?(characterRestore)

def characterSwitch(*args)
  return TravelExpansionFramework.release_safe_stub("characterSwitch", "true", "story_transfer", *args)
end unless defined?(characterSwitch)

def characterSwtich(*args)
  return TravelExpansionFramework.release_safe_stub("characterSwtich", "true", "story_transfer", *args)
end unless defined?(characterSwtich)

def pbRefreshCustomDuel(*args)
  return TravelExpansionFramework.release_safe_stub("pbRefreshCustomDuel", "true", "trainer_battle", *args)
end unless defined?(pbRefreshCustomDuel)

def pbStartCustomDuel(*args)
  return TravelExpansionFramework.release_safe_stub("pbStartCustomDuel", "true", "trainer_battle", *args)
end unless defined?(pbStartCustomDuel)

def pbEndCustomDuel(*args)
  return TravelExpansionFramework.release_safe_stub("pbEndCustomDuel", "true", "trainer_battle", *args)
end unless defined?(pbEndCustomDuel)

def pbRentReturn(*args)
  return TravelExpansionFramework.release_safe_stub("pbRentReturn", "true", "trainer_battle", *args)
end unless defined?(pbRentReturn)

def pbInfoBox(*args)
  return TravelExpansionFramework.release_safe_stub("pbInfoBox", "true", "menu_settings", *args)
end unless defined?(pbInfoBox)

def pbSlotMachine(*args)
  return TravelExpansionFramework.release_safe_stub("pbSlotMachine", "false", "item_handlers", *args)
end unless defined?(pbSlotMachine)

def pbRoulette(*args)
  return TravelExpansionFramework.release_safe_stub("pbRoulette", "false", "item_handlers", *args)
end unless defined?(pbRoulette)

def pbVoltorbFlip(*args)
  return TravelExpansionFramework.release_safe_stub("pbVoltorbFlip", "false", "item_handlers", *args)
end unless defined?(pbVoltorbFlip)

def pbLottery(*args)
  return TravelExpansionFramework.release_safe_stub("pbLottery", "false", "item_handlers", *args)
end unless defined?(pbLottery)

def pbSetLotteryNumber(*args)
  return TravelExpansionFramework.release_safe_stub("pbSetLotteryNumber", "true", "item_handlers", *args)
end unless defined?(pbSetLotteryNumber)

def pbBerryPlant(*args)
  return TravelExpansionFramework.release_safe_stub("pbBerryPlant", "true", "item_handlers", *args)
end unless defined?(pbBerryPlant)

def pbPickBerry(*args)
  return TravelExpansionFramework.release_safe_stub("pbPickBerry", "true", "item_handlers", *args)
end unless defined?(pbPickBerry)

def pbPushThisBoulder(*args)
  return TravelExpansionFramework.release_safe_stub("pbPushThisBoulder", "true", "story_transfer", *args)
end unless defined?(pbPushThisBoulder)

def pbPartialHeal(*args)
  return TravelExpansionFramework.release_safe_stub("pbPartialHeal", "heal_party", "item_handlers", *args)
end unless defined?(pbPartialHeal)

def pbDayCareDeposited(*args)
  return TravelExpansionFramework.release_safe_stub("pbDayCareDeposited", "zero", "item_handlers", *args)
end unless defined?(pbDayCareDeposited)

def pbDayCareGetDeposited(*args)
  return TravelExpansionFramework.release_safe_stub("pbDayCareGetDeposited", "array", "item_handlers", *args)
end unless defined?(pbDayCareGetDeposited)

def pbDayCareGetCompatibility(*args)
  return TravelExpansionFramework.release_safe_stub("pbDayCareGetCompatibility", "zero", "item_handlers", *args)
end unless defined?(pbDayCareGetCompatibility)

def pbDayCareDeposit(*args)
  return TravelExpansionFramework.release_safe_stub("pbDayCareDeposit", "true", "item_handlers", *args)
end unless defined?(pbDayCareDeposit)

def pbDayCareWithdraw(*args)
  return TravelExpansionFramework.release_safe_stub("pbDayCareWithdraw", "true", "item_handlers", *args)
end unless defined?(pbDayCareWithdraw)

def pbDayCareChoose(*args)
  return TravelExpansionFramework.release_safe_stub("pbDayCareChoose", "nil", "item_handlers", *args)
end unless defined?(pbDayCareChoose)

if !defined?(pbDayCareGenerateEgg) && defined?(Kernel)
  module Kernel
    def pbDayCareGenerateEgg(*args)
      return TravelExpansionFramework.release_safe_stub("pbDayCareGenerateEgg", "true", "item_handlers", *args)
    end unless method_defined?(:pbDayCareGenerateEgg)
    module_function :pbDayCareGenerateEgg if method_defined?(:pbDayCareGenerateEgg) && !respond_to?(:pbDayCareGenerateEgg)
  end
end

def pbDayCareChooseOffspringBall(*args)
  return TravelExpansionFramework.release_safe_stub("pbDayCareChooseOffspringBall", "nil", "item_handlers", *args)
end unless defined?(pbDayCareChooseOffspringBall)

module EncounterTypes
  Land          = :Land unless const_defined?(:Land)
  Land1         = :Land1 unless const_defined?(:Land1)
  Land2         = :Land2 unless const_defined?(:Land2)
  Land3         = :Land3 unless const_defined?(:Land3)
  LandMorning   = :LandMorning unless const_defined?(:LandMorning)
  LandDay       = :LandDay unless const_defined?(:LandDay)
  LandNight     = :LandNight unless const_defined?(:LandNight)
  LandAfternoon = :LandAfternoon unless const_defined?(:LandAfternoon)
  LandEvening   = :LandEvening unless const_defined?(:LandEvening)
  Cave          = :Cave unless const_defined?(:Cave)
  CaveMorning   = :CaveMorning unless const_defined?(:CaveMorning)
  CaveDay       = :CaveDay unless const_defined?(:CaveDay)
  CaveNight     = :CaveNight unless const_defined?(:CaveNight)
  CaveAfternoon = :CaveAfternoon unless const_defined?(:CaveAfternoon)
  CaveEvening   = :CaveEvening unless const_defined?(:CaveEvening)
  Water         = :Water unless const_defined?(:Water)
  WaterMorning  = :WaterMorning unless const_defined?(:WaterMorning)
  WaterDay      = :WaterDay unless const_defined?(:WaterDay)
  WaterNight    = :WaterNight unless const_defined?(:WaterNight)
  WaterAfternoon = :WaterAfternoon unless const_defined?(:WaterAfternoon)
  WaterEvening  = :WaterEvening unless const_defined?(:WaterEvening)
  OldRod        = :OldRod unless const_defined?(:OldRod)
  GoodRod       = :GoodRod unless const_defined?(:GoodRod)
  SuperRod      = :SuperRod unless const_defined?(:SuperRod)
  RockSmash     = :RockSmash unless const_defined?(:RockSmash)
  HeadbuttLow   = :HeadbuttLow unless const_defined?(:HeadbuttLow)
  HeadbuttHigh  = :HeadbuttHigh unless const_defined?(:HeadbuttHigh)
  BugContest    = :BugContest unless const_defined?(:BugContest)
  Names = [
    Land, Cave, Water, OldRod, GoodRod, SuperRod, RockSmash,
    HeadbuttLow, HeadbuttHigh, LandMorning, LandDay, LandNight,
    BugContest
  ].freeze unless const_defined?(:Names)
  EnctypeDensities = Array.new(13, 0).freeze unless const_defined?(:EnctypeDensities)
  EnctypeChances = Array.new(13) { [] }.freeze unless const_defined?(:EnctypeChances)
  EnctypeCompileDens = Array.new(13, 0).freeze unless const_defined?(:EnctypeCompileDens)
end unless defined?(EncounterTypes)

alias tef_release_original_pbEncounter pbEncounter if method_defined?(:pbEncounter) && !method_defined?(:tef_release_original_pbEncounter)
def pbEncounter(encounter_type = nil, *args)
  if defined?(TravelExpansionFramework) && TravelExpansionFramework.respond_to?(:release_trigger_encounter!)
    return TravelExpansionFramework.release_trigger_encounter!(encounter_type, *args)
  end
  return tef_release_original_pbEncounter(encounter_type, *args) if respond_to?(:tef_release_original_pbEncounter, true)
  return false
rescue => e
  TravelExpansionFramework.log("[release] pbEncounter failed safely: #{e.class}: #{e.message}") if defined?(TravelExpansionFramework) &&
                                                                                                  TravelExpansionFramework.respond_to?(:log)
  return false
end

def pbHasStarters?
  return TravelExpansionFramework.release_safe_stub("pbHasStarters?", "party_present", "startup")
end unless defined?(pbHasStarters?)

def prerandomizeMiningStones(*args)
  return TravelExpansionFramework.release_safe_stub("prerandomizeMiningStones", "true", "startup", *args)
end unless defined?(prerandomizeMiningStones)

def useAirDragonite(*args)
  return TravelExpansionFramework.release_safe_stub("useAirDragonite", "false", "story_transfer", *args)
end unless defined?(useAirDragonite)

def pbHealingMachine(*args)
  return TravelExpansionFramework.release_safe_stub("pbHealingMachine", "heal_party", "item_handlers", *args)
end unless defined?(pbHealingMachine)

def pbXDPC(*args)
  return TravelExpansionFramework.release_safe_stub("pbXDPC", "host_pc", "item_handlers", *args)
end unless defined?(pbXDPC)

def pbPokeMartWorker(*args)
  return TravelExpansionFramework.release_safe_stub("pbPokeMartWorker", "host_mart", "item_handlers", *args)
end unless defined?(pbPokeMartWorker)

def characterPopup(label, event_ref = nil, *args)
  return TravelExpansionFramework.release_safe_stub("characterPopup", "true", "story_transfer", label, event_ref, *args)
end unless defined?(characterPopup)

def getCompletedQuests
  TravelExpansionFramework.record_release_shim_hit("getCompletedQuests", "menu_settings", "array") if defined?(TravelExpansionFramework)
  return TravelExpansionFramework.release_quest_store(:completed)
end unless defined?(getCompletedQuests)

def getActiveQuests
  TravelExpansionFramework.record_release_shim_hit("getActiveQuests", "menu_settings", "array") if defined?(TravelExpansionFramework)
  return TravelExpansionFramework.release_quest_store(:active)
end unless defined?(getActiveQuests)

def completeQuest(quest)
  return TravelExpansionFramework.release_complete_quest!(quest, false)
end unless defined?(completeQuest)

def activateQuest(quest)
  return TravelExpansionFramework.release_activate_quest!(quest, nil, false)
end unless defined?(activateQuest)

def activateQuestSilent(quest, *args)
  return TravelExpansionFramework.release_activate_quest!(quest, nil, true, *args)
end unless defined?(activateQuestSilent)

def advanceQuestSilent(quest, *args)
  return TravelExpansionFramework.release_advance_quest!(quest, nil, *args)
end unless defined?(advanceQuestSilent)

def advanceQuestToStage(quest, stage = nil, *args)
  return TravelExpansionFramework.release_advance_quest!(quest, stage, *args)
end unless defined?(advanceQuestToStage)

def completeQuestSilent(quest, *args)
  return TravelExpansionFramework.release_complete_quest!(quest, true, *args)
end unless defined?(completeQuestSilent)

def getQuestStage(quest)
  return TravelExpansionFramework.release_quest_stage(quest)
end unless defined?(getQuestStage)

def colorQuest(color = nil, *_args)
  TravelExpansionFramework.record_release_shim_hit("colorQuest", "menu_settings", "first_arg") if defined?(TravelExpansionFramework) &&
                                                                                                  TravelExpansionFramework.respond_to?(:record_release_shim_hit)
  return color
rescue
  return nil
end unless defined?(colorQuest)

def pbRandomItem(*args)
  return TravelExpansionFramework.release_safe_stub("pbRandomItem", "nil", "item_handlers", *args)
end unless defined?(pbRandomItem)

def pbUnlockRecipe(recipe_id = nil, *args)
  return TravelExpansionFramework.release_unlock_recipe!(recipe_id, *args)
end unless defined?(pbUnlockRecipe)

def pbLockRecipe(recipe_id = nil, *args)
  return TravelExpansionFramework.release_lock_recipe!(recipe_id, *args)
end unless defined?(pbLockRecipe)

def pbGetRecipes(flag = nil, *args)
  return TravelExpansionFramework.release_recipe_ids_for_flag(flag, *args)
end unless defined?(pbGetRecipes)

def pbItemCrafter(stock = nil, speech1 = nil, speech2 = nil, *args)
  return TravelExpansionFramework.release_item_crafter(stock, speech1, speech2, *args)
end unless defined?(pbItemCrafter)

def pbFormTrader(*args)
  return TravelExpansionFramework.release_safe_stub("pbFormTrader", "true", "item_handlers", *args)
end unless defined?(pbFormTrader)

def pbFormTraderPC(*args)
  return TravelExpansionFramework.release_safe_stub("pbFormTraderPC", "host_pc", "item_handlers", *args)
end unless defined?(pbFormTraderPC)

def pbStoryModeSetup(*args)
  if defined?($player) && $player
    $player.has_running_shoes = true if $player.respond_to?(:has_running_shoes=)
    $player.has_pokegear = true if $player.respond_to?(:has_pokegear=)
    $player.has_pokedex = true if $player.respond_to?(:has_pokedex=)
    $player.seen_storage_creator = true if $player.respond_to?(:seen_storage_creator=)
  end
  return TravelExpansionFramework.release_safe_stub("pbStoryModeSetup", "true", "startup", *args)
rescue => e
  TravelExpansionFramework.log("[release] pbStoryModeSetup failed safely: #{e.class}: #{e.message}") if defined?(TravelExpansionFramework) &&
                                                                                                       TravelExpansionFramework.respond_to?(:log)
  return true
end unless defined?(pbStoryModeSetup)

def pbStoryModeGiveDummyStarters(*args)
  return TravelExpansionFramework.release_safe_stub("pbStoryModeGiveDummyStarters", "true", "startup", *args)
end unless defined?(pbStoryModeGiveDummyStarters)

def pbStoryModeRemoveDummyStarters(*args)
  return TravelExpansionFramework.release_safe_stub("pbStoryModeRemoveDummyStarters", "true", "startup", *args)
end unless defined?(pbStoryModeRemoveDummyStarters)

def pbStoryModeTrainerItemSuite(*args)
  return TravelExpansionFramework.release_safe_stub("pbStoryModeTrainerItemSuite", "true", "item_handlers", *args)
end unless defined?(pbStoryModeTrainerItemSuite)

def pbClearAllPokemonSetup(*args)
  return TravelExpansionFramework.release_safe_stub("pbClearAllPokemonSetup", "true", "startup", *args)
end unless defined?(pbClearAllPokemonSetup)

def pbAllPokemonSetup5(*args)
  return TravelExpansionFramework.release_safe_stub("pbAllPokemonSetup5", "true", "startup", *args)
end unless defined?(pbAllPokemonSetup5)

def pbAllPokemonSetup30(*args)
  return TravelExpansionFramework.release_safe_stub("pbAllPokemonSetup30", "true", "startup", *args)
end unless defined?(pbAllPokemonSetup30)

def pbAllPokemonSetup50(*args)
  return TravelExpansionFramework.release_safe_stub("pbAllPokemonSetup50", "true", "startup", *args)
end unless defined?(pbAllPokemonSetup50)

def pbAllPokemonSetup100(*args)
  return TravelExpansionFramework.release_safe_stub("pbAllPokemonSetup100", "true", "startup", *args)
end unless defined?(pbAllPokemonSetup100)

def pbOptimisedPartyQuickStart5(*args)
  return TravelExpansionFramework.release_safe_stub("pbOptimisedPartyQuickStart5", "true", "startup", *args)
end unless defined?(pbOptimisedPartyQuickStart5)

def pbOptimisedPartyQuickStart30(*args)
  return TravelExpansionFramework.release_safe_stub("pbOptimisedPartyQuickStart30", "true", "startup", *args)
end unless defined?(pbOptimisedPartyQuickStart30)

def pbOptimisedPartyQuickStart50(*args)
  return TravelExpansionFramework.release_safe_stub("pbOptimisedPartyQuickStart50", "true", "startup", *args)
end unless defined?(pbOptimisedPartyQuickStart50)

def pbOptimisedPartyQuickStart100(*args)
  return TravelExpansionFramework.release_safe_stub("pbOptimisedPartyQuickStart100", "true", "startup", *args)
end unless defined?(pbOptimisedPartyQuickStart100)

def pbBattleModeSetup5(*args)
  return TravelExpansionFramework.release_safe_stub("pbBattleModeSetup5", "true", "trainer_battle", *args)
end unless defined?(pbBattleModeSetup5)

def pbBattleModeSetup30(*args)
  return TravelExpansionFramework.release_safe_stub("pbBattleModeSetup30", "true", "trainer_battle", *args)
end unless defined?(pbBattleModeSetup30)

def pbBattleModeSetup50(*args)
  return TravelExpansionFramework.release_safe_stub("pbBattleModeSetup50", "true", "trainer_battle", *args)
end unless defined?(pbBattleModeSetup50)

def pbBattleModeSetup100(*args)
  return TravelExpansionFramework.release_safe_stub("pbBattleModeSetup100", "true", "trainer_battle", *args)
end unless defined?(pbBattleModeSetup100)

def pbDumpOutAllItems(*args)
  return TravelExpansionFramework.release_safe_stub("pbDumpOutAllItems", "true", "item_handlers", *args)
end unless defined?(pbDumpOutAllItems)

def pbJumpInAllItems(*args)
  return TravelExpansionFramework.release_safe_stub("pbJumpInAllItems", "true", "item_handlers", *args)
end unless defined?(pbJumpInAllItems)

def pbPumbInAllItems(*args)
  return TravelExpansionFramework.release_safe_stub("pbPumbInAllItems", "true", "item_handlers", *args)
end unless defined?(pbPumbInAllItems)

def pbRemoveBagClutter(*args)
  return TravelExpansionFramework.release_safe_stub("pbRemoveBagClutter", "true", "item_handlers", *args)
end unless defined?(pbRemoveBagClutter)

def pbRemoveStoryModeBagClutter(*args)
  return TravelExpansionFramework.release_safe_stub("pbRemoveStoryModeBagClutter", "true", "item_handlers", *args)
end unless defined?(pbRemoveStoryModeBagClutter)

def pbShowTipCard(*args)
  return TravelExpansionFramework.release_safe_stub("pbShowTipCard", "true", "menu_settings", *args)
end unless defined?(pbShowTipCard)

module VoidCharacterPortrait
  def self.set(*args); true; end
  def self.set_player(*args); true; end
  def self.clear; true; end
  def self.active?; false; end
  def self.show_for_current_message
    yield if block_given?
    return true
  end
end unless defined?(VoidCharacterPortrait)

def pbSetDialoguePortrait(*args)
  return TravelExpansionFramework.release_safe_stub("pbSetDialoguePortrait", "true", "menu_settings", *args)
end unless defined?(pbSetDialoguePortrait)

def pbSetPlayerDialoguePortrait(*args)
  return TravelExpansionFramework.release_safe_stub("pbSetPlayerDialoguePortrait", "true", "menu_settings", *args)
end unless defined?(pbSetPlayerDialoguePortrait)

def pbSetRivalDialoguePortrait(*args)
  return TravelExpansionFramework.release_safe_stub("pbSetRivalDialoguePortrait", "true", "menu_settings", *args)
end unless defined?(pbSetRivalDialoguePortrait)

def pbClearDialoguePortrait(*args)
  return TravelExpansionFramework.release_safe_stub("pbClearDialoguePortrait", "true", "menu_settings", *args)
end unless defined?(pbClearDialoguePortrait)

def pbPortraitMessage(message = nil, *args)
  return TravelExpansionFramework.release_portrait_message(message, *args)
end unless defined?(pbPortraitMessage)

def pbPlayerPortraitMessage(message = nil, *args)
  return TravelExpansionFramework.release_portrait_message(message, *args)
end unless defined?(pbPlayerPortraitMessage)

def pbRivalPortraitMessage(message = nil, *args)
  return TravelExpansionFramework.release_portrait_message(message, *args)
end unless defined?(pbRivalPortraitMessage)

def pbVoidCharacterSetup(*args)
  return TravelExpansionFramework.release_safe_stub("pbVoidCharacterSetup", "void_character_setup", "startup", *args)
end unless defined?(pbVoidCharacterSetup)

def pbStartQuest(quest, *args)
  return TravelExpansionFramework.release_activate_quest!(quest, nil, true, *args)
end unless defined?(pbStartQuest)

def pbCompleteQuest(quest, *args)
  return TravelExpansionFramework.release_complete_quest!(quest, true, *args)
end unless defined?(pbCompleteQuest)

def pbQuestStatus(quest, *_args)
  return TravelExpansionFramework.release_quest_stage(quest)
end unless defined?(pbQuestStatus)

def pbQuestStarted?(quest, *_args)
  return TravelExpansionFramework.release_quest_started?(quest)
end unless defined?(pbQuestStarted?)

def pbQuestComplete?(quest, *_args)
  return TravelExpansionFramework.release_quest_completed?(quest)
end unless defined?(pbQuestComplete?)

def pbQuestKnown?(quest, *_args)
  return TravelExpansionFramework.release_quest_started?(quest)
end unless defined?(pbQuestKnown?)

def startCharacterSelection(*args)
  TravelExpansionFramework.record_release_shim_hit("startCharacterSelection", "startup", "zero") if defined?(TravelExpansionFramework) &&
                                                                                                    TravelExpansionFramework.respond_to?(:record_release_shim_hit)
  return 0
rescue
  return 0
end unless defined?(startCharacterSelection)

def pbCharacterSelect(*args)
  return TravelExpansionFramework.release_safe_stub("pbCharacterSelect", "true", "startup", *args)
end unless defined?(pbCharacterSelect)

def pbPokemonSelection(list = nil, must_choose = true, settings = nil)
  if defined?(TravelExpansionFramework) && TravelExpansionFramework.respond_to?(:early_build_imported_starter)
    return TravelExpansionFramework.early_build_imported_starter(list, settings || must_choose)
  elsif defined?(TravelExpansionFramework) && TravelExpansionFramework.respond_to?(:early_pick_imported_starter)
    return TravelExpansionFramework.early_pick_imported_starter(list, settings || must_choose)
  end
  return TravelExpansionFramework.release_safe_stub("pbPokemonSelection", "starter_species", "startup", list, must_choose, settings)
rescue
  return :PIKACHU
end unless defined?(pbPokemonSelection)

alias pbTipCard pbShowTipCard if defined?(pbShowTipCard) && !defined?(pbTipCard)

def pbGrantRandomPokemonSilent(pokemon_array, level = 5)
  species = TravelExpansionFramework.release_random_available_species(pokemon_array)
  return TravelExpansionFramework.release_safe_stub("pbGrantRandomPokemonSilent", "true", "startup", pokemon_array, level) if species.nil?
  TravelExpansionFramework.record_release_shim_hit("pbGrantRandomPokemonSilent", "startup", "grant_host_species") if defined?(TravelExpansionFramework)
  return pbAddPokemonSilent(species, level) if defined?(pbAddPokemonSilent)
  return pbAddPokemon(species, level) if defined?(pbAddPokemon)
  return true
rescue => e
  TravelExpansionFramework.log("[release] pbGrantRandomPokemonSilent failed safely: #{e.class}: #{e.message}") if defined?(TravelExpansionFramework) &&
                                                                                                                TravelExpansionFramework.respond_to?(:log)
  return true
end unless defined?(pbGrantRandomPokemonSilent)

def pbGrantRandomPokemon(pokemon_array, level = 5)
  species = TravelExpansionFramework.release_random_available_species(pokemon_array)
  return true if species.nil?
  return pbAddPokemon(species, level) if defined?(pbAddPokemon)
  return pbAddPokemonSilent(species, level) if defined?(pbAddPokemonSilent)
  return true
rescue => e
  TravelExpansionFramework.log("[release] pbGrantRandomPokemon failed safely: #{e.class}: #{e.message}") if defined?(TravelExpansionFramework) &&
                                                                                                          TravelExpansionFramework.respond_to?(:log)
  return true
end unless defined?(pbGrantRandomPokemon)

def pbGetRandomPokemon(pokemon_array)
  return TravelExpansionFramework.release_random_available_species(pokemon_array)
end unless defined?(pbGetRandomPokemon)

def pbApplyBattleRule(rule, _value_type = nil, set_value = true, *_args)
  return TravelExpansionFramework.release_safe_set_battle_rule!(rule, set_value)
end unless defined?(pbApplyBattleRule)

alias tef_release_original_setBattleRule setBattleRule if Object.private_method_defined?(:setBattleRule) &&
                                                          !Object.private_method_defined?(:tef_release_original_setBattleRule)
def setBattleRule(*args)
  begin
    return tef_release_original_setBattleRule(*args) if respond_to?(:tef_release_original_setBattleRule, true)
  rescue => e
    if defined?(TravelExpansionFramework) &&
       TravelExpansionFramework.respond_to?(:release_safe_set_battle_rule!) &&
       TravelExpansionFramework.release_safe_set_battle_rule!(*args)
      TravelExpansionFramework.log("[release] setBattleRule shimmed #{args.inspect}: #{e.class}: #{e.message}") if TravelExpansionFramework.respond_to?(:log)
      return true
    end
    raise e
  end
  return TravelExpansionFramework.release_safe_set_battle_rule!(*args) if defined?(TravelExpansionFramework) &&
                                                                          TravelExpansionFramework.respond_to?(:release_safe_set_battle_rule!)
  return true
end

DrewQuest = :DrewQuest unless defined?(DrewQuest)

module Settings
end unless defined?(Settings)

if defined?(Settings) && Settings.respond_to?(:const_defined?)
  {
    :MONEY_MODIFIER        => 5501,
    :EXP_MODIFIER          => 5502,
    :CATCH_MODIFIER        => 5503,
    :PLAYER_IVS           => 5504,
    :OPPONENT_IVS         => 5505,
    :TRAINER_AI           => 5506,
    :PLAYER_DAMAGE_OUTPUT => 5507,
    :ENEMY_DAMAGE_OUTPUT  => 5508,
    :OPPONENT_LEVEL_MOD   => 5509,
    :OPPONENT_EVS         => 5510
  }.each_pair do |name, value|
    Settings.const_set(name, value) if !Settings.const_defined?(name)
  end
  Settings.const_set(:CUSTOMSETTINGS, []) if !Settings.const_defined?(:CUSTOMSETTINGS)
end

if defined?(PokemonSystem)
  class PokemonSystem
    def current_menu_theme
      @current_menu_theme ||= 0
      return @current_menu_theme
    end unless method_defined?(:current_menu_theme)

    def current_menu_theme=(value)
      @current_menu_theme = value
    end unless method_defined?(:current_menu_theme=)

    def difficulty
      @difficulty ||= 0
      return @difficulty
    end unless method_defined?(:difficulty)

    def difficulty=(value)
      @difficulty = value
    end unless method_defined?(:difficulty=)

    def daytone
      @daytone ||= 0
      return @daytone
    end unless method_defined?(:daytone)

    def daytone=(value)
      @daytone = value
    end unless method_defined?(:daytone=)

    def mystery_gift_unlocked
      @mystery_gift_unlocked ||= false
      return @mystery_gift_unlocked
    end unless method_defined?(:mystery_gift_unlocked)

    def mystery_gift_unlocked=(value)
      @mystery_gift_unlocked = value == true
    end unless method_defined?(:mystery_gift_unlocked=)

    if method_defined?(:pokedex=) && !method_defined?(:tef_release_original_pokedex_writer)
      alias tef_release_original_pokedex_writer pokedex=

      def pokedex=(value)
        TravelExpansionFramework.rebuild_host_dex_shadow_from_storage! if defined?(TravelExpansionFramework) &&
                                                                          TravelExpansionFramework.respond_to?(:rebuild_host_dex_shadow_from_storage!)
        tef_release_original_pokedex_writer(value)
        TravelExpansionFramework.restore_host_dex_shadow_to_player! if defined?(TravelExpansionFramework) &&
                                                                       TravelExpansionFramework.respond_to?(:restore_host_dex_shadow_to_player!)
        return value
      end
    end
  end
end

if defined?(Player)
  class Player
    def tef_release_list_attr(name)
      ivar = "@#{name}"
      instance_variable_set(ivar, []) if !instance_variable_defined?(ivar) || !instance_variable_get(ivar).is_a?(Array)
      return instance_variable_get(ivar)
    end unless method_defined?(:tef_release_list_attr)

    def owned
      return tef_release_list_attr(:owned)
    end unless method_defined?(:owned)

    def owned=(value)
      @owned = value.is_a?(Array) ? value : Array(value)
    end unless method_defined?(:owned=)

    def battlebelt
      return tef_release_list_attr(:battlebelt)
    end unless method_defined?(:battlebelt)

    def battlebelt=(value)
      @battlebelt = value.is_a?(Array) ? value : Array(value)
    end unless method_defined?(:battlebelt=)

    def difficulty
      @difficulty ||= 0
      return @difficulty
    end unless method_defined?(:difficulty)

    def difficulty=(value)
      @difficulty = value
    end unless method_defined?(:difficulty=)

    def wallpaper
      @wallpaper ||= 0
      return @wallpaper
    end unless method_defined?(:wallpaper)

    def wallpaper=(value)
      @wallpaper = value
    end unless method_defined?(:wallpaper=)

    def tera_charged
      @tera_charged ||= false
      return @tera_charged
    end unless method_defined?(:tera_charged)

    def tera_charged=(value)
      @tera_charged = value == true
    end unless method_defined?(:tera_charged=)

    def mystery_gift_unlocked
      @mystery_gift_unlocked ||= false
      return @mystery_gift_unlocked
    end unless method_defined?(:mystery_gift_unlocked)

    def mystery_gift_unlocked=(value)
      @mystery_gift_unlocked = value == true
    end unless method_defined?(:mystery_gift_unlocked=)

    def expall
      if defined?(TravelExpansionFramework) &&
         TravelExpansionFramework.respond_to?(:release_host_exp_all_enabled?)
        return TravelExpansionFramework.release_host_exp_all_enabled?
      end
      return @tef_release_expall == true
    end unless method_defined?(:expall)

    def expall=(value)
      enabled = if defined?(TravelExpansionFramework) &&
                   TravelExpansionFramework.respond_to?(:release_set_host_exp_all!)
                  TravelExpansionFramework.release_set_host_exp_all!(value)
                else
                  value == true
                end
      @tef_release_expall = enabled == true
      return @tef_release_expall
    end unless method_defined?(:expall=)
  end
end

if defined?(Player::Pokedex)
  class Player::Pokedex
    alias tef_release_original_set_seen_for_capture set_seen unless method_defined?(:tef_release_original_set_seen_for_capture)
    alias tef_release_original_set_owned_for_capture set_owned unless method_defined?(:tef_release_original_set_owned_for_capture)

    def set_seen(species, should_refresh_dexes = true)
      should_refresh_dexes = false if defined?(TravelExpansionFramework) &&
                                      TravelExpansionFramework.respond_to?(:release_fast_capture_bookkeeping?) &&
                                      TravelExpansionFramework.release_fast_capture_bookkeeping?
      return tef_release_original_set_seen_for_capture(species, should_refresh_dexes)
    end

    def set_owned(species, should_refresh_dexes = true)
      should_refresh_dexes = false if defined?(TravelExpansionFramework) &&
                                      TravelExpansionFramework.respond_to?(:release_fast_capture_bookkeeping?) &&
                                      TravelExpansionFramework.release_fast_capture_bookkeeping?
      return tef_release_original_set_owned_for_capture(species, should_refresh_dexes)
    end
  end
end

if defined?(PokeBattle_Battle) && PokeBattle_Battle.method_defined?(:pbRecordAndStoreCaughtPokemon)
  class PokeBattle_Battle
    alias tef_release_original_pbRecordAndStoreCaughtPokemon_for_capture pbRecordAndStoreCaughtPokemon unless method_defined?(:tef_release_original_pbRecordAndStoreCaughtPokemon_for_capture)

    def pbRecordAndStoreCaughtPokemon(*args)
      started_at = Time.now
      result = nil
      if defined?(TravelExpansionFramework) &&
         TravelExpansionFramework.respond_to?(:with_release_fast_capture_bookkeeping)
        result = TravelExpansionFramework.with_release_fast_capture_bookkeeping do
          tef_release_original_pbRecordAndStoreCaughtPokemon_for_capture(*args)
        end
      else
        result = tef_release_original_pbRecordAndStoreCaughtPokemon_for_capture(*args)
      end
      elapsed = Time.now - started_at
      if elapsed > 1.0 && defined?(TravelExpansionFramework) && TravelExpansionFramework.respond_to?(:log)
        count = @caughtPokemon.length rescue "n/a"
        TravelExpansionFramework.log("[release] catch completion took #{format('%.3f', elapsed)}s after fast capture bookkeeping; remaining=#{count}")
      end
      return result
    end
  end
end

if defined?(Kernel) && Kernel.respond_to?(:tryAutosave)
  module Kernel
    class << self
      alias tef_release_original_tryAutosave_for_scene_safety tryAutosave unless method_defined?(:tef_release_original_tryAutosave_for_scene_safety)

      def tryAutosave(*args)
        if defined?(TravelExpansionFramework) &&
           TravelExpansionFramework.respond_to?(:release_scene_busy_for_autosave?) &&
           TravelExpansionFramework.release_scene_busy_for_autosave?
          if TravelExpansionFramework.respond_to?(:release_request_deferred_autosave!) &&
             TravelExpansionFramework.release_request_deferred_autosave!(18)
            return false
          end
        end
        return tef_release_original_tryAutosave_for_scene_safety(*args)
      end
    end
  end
end

module ChallengeModes
end unless defined?(ChallengeModes)

class << ChallengeModes
  def start(*args)
    TravelExpansionFramework.record_release_shim_hit("ChallengeModes.start", "menu_settings", "true") if defined?(TravelExpansionFramework) &&
                                                                                                         TravelExpansionFramework.respond_to?(:record_release_shim_hit)
    return true
  rescue
    return true
  end unless method_defined?(:start)
end if defined?(ChallengeModes)

module LevelCapsEX
end unless defined?(LevelCapsEX)

class << LevelCapsEX
  def enabled?
    TravelExpansionFramework.record_release_shim_hit("LevelCapsEX.enabled?", "menu_settings", "false") if defined?(TravelExpansionFramework)
    return false
  end unless method_defined?(:enabled?)

  def toggle
    TravelExpansionFramework.record_release_shim_hit("LevelCapsEX.toggle", "menu_settings", "false") if defined?(TravelExpansionFramework)
    return false
  end unless method_defined?(:toggle)
end

module PokemonSelection
end unless defined?(PokemonSelection)

class << PokemonSelection
  def restore(*args)
    TravelExpansionFramework.release_safe_stub("PokemonSelection.restore", "true", "startup", *args) if defined?(TravelExpansionFramework) &&
                                                                                                        TravelExpansionFramework.respond_to?(:release_safe_stub)
    return true
  rescue
    return true
  end unless method_defined?(:restore)
end if defined?(PokemonSelection)

module MessageConfig
end unless defined?(MessageConfig)

class << MessageConfig
  def pbSetSpeechFrame(*args)
    TravelExpansionFramework.release_safe_stub("MessageConfig.pbSetSpeechFrame", "true", "menu_settings", *args) if defined?(TravelExpansionFramework) &&
                                                                                                                   TravelExpansionFramework.respond_to?(:release_safe_stub)
    return true
  rescue
    return true
  end unless method_defined?(:pbSetSpeechFrame)
end if defined?(MessageConfig)

class PokemonEntryScene
  def initialize(*_args)
  end
end unless defined?(PokemonEntryScene)

class PokemonEntry
  def initialize(scene = nil)
    @scene = scene
  end

  def pbStartScreen(*args)
    TravelExpansionFramework.record_release_shim_hit("PokemonEntry.pbStartScreen", "startup", "empty_string") if defined?(TravelExpansionFramework) &&
                                                                                                                 TravelExpansionFramework.respond_to?(:record_release_shim_hit)
    initial_text = args[3]
    return initial_text.to_s if initial_text && !initial_text.to_s.empty?
    mode = args[4].to_i rescue -1
    return ($Trainer.name rescue "Player").to_s if mode == 1
    return ""
  rescue
    return ""
  end
end unless defined?(PokemonEntry)

Object.const_set(:RANDOM_ALL_TYPES, TravelExpansionFramework.early_random_all_types_pool) if defined?(TravelExpansionFramework) &&
                                                                                            TravelExpansionFramework.respond_to?(:early_random_all_types_pool) &&
                                                                                            !Object.const_defined?(:RANDOM_ALL_TYPES, false)

if defined?(Interpreter) && defined?(RANDOM_ALL_TYPES) && !Interpreter.const_defined?(:RANDOM_ALL_TYPES, false)
  Interpreter.const_set(:RANDOM_ALL_TYPES, RANDOM_ALL_TYPES)
end

module FollowingPkmn
end unless defined?(FollowingPkmn)

module FollowingPkmn
  def self.active?
    TravelExpansionFramework.record_release_shim_hit("FollowingPkmn.active?", "follower_system", "false") if defined?(TravelExpansionFramework)
    return false
  end unless respond_to?(:active?)

  def self.toggle_off(*_args)
    return true
  end unless respond_to?(:toggle_off)
end

class TrainerBattle
  def self.start(*args)
    return pbTrainerBattle(args[0], args[1]) if defined?(pbTrainerBattle) && args.length >= 2
    return TravelExpansionFramework.release_safe_stub("TrainerBattle.start", "true", "trainer_battle", *args)
  rescue => e
    TravelExpansionFramework.log("[release] TrainerBattle.start fallback failed safely: #{e.class}: #{e.message}") if defined?(TravelExpansionFramework) &&
                                                                                                                    TravelExpansionFramework.respond_to?(:log)
    return true
  end
end unless defined?(TrainerBattle)

module BattleScripting
end unless defined?(BattleScripting)

class << BattleScripting
  def tef_release_scripts
    @tef_release_scripts ||= {}
    return @tef_release_scripts
  end unless method_defined?(:tef_release_scripts)

  def setInScript(key, value)
    tef_release_scripts[key.to_s] = value
    TravelExpansionFramework.record_release_shim_hit("BattleScripting.setInScript", "trainer_battle", "true") if defined?(TravelExpansionFramework)
    return true
  end unless method_defined?(:setInScript)

  def getInScript(key)
    return tef_release_scripts[key.to_s]
  end unless method_defined?(:getInScript)
end

class ChangeSpeed
  def initialize(*_args)
  end

  def pbChangeSpeed(value = 0)
    TravelExpansionFramework.record_release_shim_hit("ChangeSpeed.pbChangeSpeed", "menu_settings", value.to_s) if defined?(TravelExpansionFramework)
    return true
  end
end unless defined?(ChangeSpeed)

class PartyPicture
  def initialize(*args)
    TravelExpansionFramework.record_release_shim_hit("PartyPicture.new", "follower_system", "true") if defined?(TravelExpansionFramework)
    @args = args
  end

  def dispose
    return true
  end
end unless defined?(PartyPicture)

class GenderPickSelection
  def self.show(*args)
    TravelExpansionFramework.record_release_shim_hit("GenderPickSelection.show", "menu_settings", "true") if defined?(TravelExpansionFramework)
    return true
  end
end unless defined?(GenderPickSelection)

class GameMode_Scene
  def initialize(*_args)
  end
end unless defined?(GameMode_Scene)

class GameModeScreen
  def initialize(scene = nil)
    @scene = scene
  end

  def pbStartScreen(*_args)
    TravelExpansionFramework.record_release_shim_hit("GameModeScreen.pbStartScreen", "menu_settings", "true") if defined?(TravelExpansionFramework)
    return true
  end
end unless defined?(GameModeScreen)

class DiegoWTsStarterSelection
  def initialize(*starters)
    @starters = starters
  end

  def pbStartScreen(*_args)
    TravelExpansionFramework.record_release_shim_hit("DiegoWTsStarterSelection.pbStartScreen", "startup", "true") if defined?(TravelExpansionFramework)
    return true
  end
end unless defined?(DiegoWTsStarterSelection)

module EliteBattle
end unless defined?(EliteBattle)

class << EliteBattle
  def InitializeSpecies(*args)
    TravelExpansionFramework.record_release_shim_hit("EliteBattle.InitializeSpecies", "startup", "true") if defined?(TravelExpansionFramework)
    return true
  end unless method_defined?(:InitializeSpecies)
end

module Kernel
  def doLegendEntrance(*args)
    TravelExpansionFramework.record_release_shim_hit("Kernel.doLegendEntrance", "story_transfer", "true") if defined?(TravelExpansionFramework)
    return true
  end unless method_defined?(:doLegendEntrance)

  def self.tef_release_object_call(name, *args)
    if Object.private_method_defined?(name) || Object.method_defined?(name)
      return Object.new.send(name, *args)
    end
    return nil
  rescue
    return nil
  end unless respond_to?(:tef_release_object_call)

  def self.pbReceiveItem(item, quantity = 1, *args)
    result = tef_release_object_call(:pbReceiveItem, item, quantity, *args)
    return result if !result.nil?
    result = tef_release_object_call(:pbAddItem, item, quantity, *args)
    return result if !result.nil?
    if defined?($PokemonBag) && $PokemonBag && $PokemonBag.respond_to?(:pbStoreItem)
      return $PokemonBag.pbStoreItem(item, quantity)
    end
    return TravelExpansionFramework.release_safe_stub("Kernel.pbReceiveItem", "true", "item_handlers", item, quantity, *args)
  rescue
    return true
  end unless respond_to?(:pbReceiveItem)

  def self.pbItemBall(item, quantity = 1, *args)
    result = tef_release_object_call(:pbItemBall, item, quantity, *args)
    return result if !result.nil?
    return pbReceiveItem(item, quantity, *args) if respond_to?(:pbReceiveItem)
    return TravelExpansionFramework.release_safe_stub("Kernel.pbItemBall", "true", "item_handlers", item, quantity, *args)
  rescue
    return true
  end unless respond_to?(:pbItemBall)

  def self.pbAddDependency2(event_id, event_name = "Dependent", common_event = nil, *args)
    result = tef_release_object_call(:pbAddDependency2, event_id, event_name, common_event, *args)
    return result if !result.nil?
    result = tef_release_object_call(:pbAddDependency, event_id, event_name, common_event, *args)
    return result if !result.nil?
    return TravelExpansionFramework.release_safe_stub("Kernel.pbAddDependency2", "true", "follower_system", event_id, event_name, common_event, *args)
  rescue
    return true
  end unless respond_to?(:pbAddDependency2)

  def self.pbRemoveDependency2(*args)
    result = tef_release_object_call(:pbRemoveDependency2, *args)
    return result if !result.nil?
    return TravelExpansionFramework.release_safe_stub("Kernel.pbRemoveDependency2", "true", "follower_system", *args)
  rescue
    return true
  end unless respond_to?(:pbRemoveDependency2)

  def self.pbNoticePlayer(*args)
    result = tef_release_object_call(:pbNoticePlayer, *args)
    return result if !result.nil?
    return TravelExpansionFramework.release_safe_stub("Kernel.pbNoticePlayer", "true", "story_transfer", *args)
  rescue
    return true
  end unless respond_to?(:pbNoticePlayer)

  def self.pbRockSmashRandomEncounter(*args)
    result = tef_release_object_call(:pbRockSmashRandomEncounter, *args)
    return result if !result.nil?
    return TravelExpansionFramework.release_safe_stub("Kernel.pbRockSmashRandomEncounter", "false", "encounters", *args)
  rescue
    return false
  end unless respond_to?(:pbRockSmashRandomEncounter)

  def self.pbUpdateVehicle(*args)
    result = tef_release_object_call(:pbUpdateVehicle, *args)
    return result if !result.nil?
    return TravelExpansionFramework.release_safe_stub("Kernel.pbUpdateVehicle", "true", "story_transfer", *args)
  rescue
    return true
  end unless respond_to?(:pbUpdateVehicle)

  def self.pbCancelVehicles(*args)
    result = tef_release_object_call(:pbCancelVehicles, *args)
    return result if !result.nil?
    return TravelExpansionFramework.release_safe_stub("pbCancelVehicles", "true", "story_transfer", *args)
  rescue
    return true
  end unless respond_to?(:pbCancelVehicles)

  def self.pbTransferSurfing(*args)
    result = tef_release_object_call(:pbTransferSurfing, *args)
    return result if !result.nil?
    return TravelExpansionFramework.release_safe_stub("pbTransferSurfing", "true", "story_transfer", *args)
  rescue
    return true
  end unless respond_to?(:pbTransferSurfing)

  def self.pbTransferUnderwater(*args)
    result = tef_release_object_call(:pbTransferUnderwater, *args)
    return result if !result.nil?
    return TravelExpansionFramework.release_safe_stub("pbTransferUnderwater", "true", "story_transfer", *args)
  rescue
    return true
  end unless respond_to?(:pbTransferUnderwater)

  def self.pbTransferLavaSurfing(*args)
    result = tef_release_object_call(:pbTransferLavaSurfing, *args)
    return result if !result.nil?
    return TravelExpansionFramework.release_safe_stub("pbTransferLavaSurfing", "true", "story_transfer", *args)
  rescue
    return true
  end unless respond_to?(:pbTransferLavaSurfing)

  def self.pbSetPokemonCenter(*args)
    result = tef_release_object_call(:pbSetPokemonCenter, *args)
    return result if !result.nil?
    return true
  rescue
    return true
  end unless respond_to?(:pbSetPokemonCenter)

  def self.pbPokeMartWorker(*args)
    return TravelExpansionFramework.release_safe_stub("pbPokeMartWorker", "host_mart", "item_handlers", *args)
  end unless respond_to?(:pbPokeMartWorker)
end

class NilClass
  def quantity(*_args)
    TravelExpansionFramework.record_release_shim_hit("NilClass#quantity", "item_handlers", "zero") if defined?(TravelExpansionFramework)
    return 0
  end unless method_defined?(:quantity)

  def mystery_gift_unlocked
    TravelExpansionFramework.record_release_shim_hit("NilClass#mystery_gift_unlocked", "menu_settings", "false") if defined?(TravelExpansionFramework)
    return false
  end unless method_defined?(:mystery_gift_unlocked)
end

if defined?(Interpreter)
  class Interpreter
    TrainerBattle = ::TrainerBattle if defined?(::TrainerBattle) && !const_defined?(:TrainerBattle, false)
    BattleScripting = ::BattleScripting if defined?(::BattleScripting) && !const_defined?(:BattleScripting, false)
    PartyPicture = ::PartyPicture if defined?(::PartyPicture) && !const_defined?(:PartyPicture, false)
    ChangeSpeed = ::ChangeSpeed if defined?(::ChangeSpeed) && !const_defined?(:ChangeSpeed, false)
    GenderPickSelection = ::GenderPickSelection if defined?(::GenderPickSelection) && !const_defined?(:GenderPickSelection, false)
    GameMode_Scene = ::GameMode_Scene if defined?(::GameMode_Scene) && !const_defined?(:GameMode_Scene, false)
    GameModeScreen = ::GameModeScreen if defined?(::GameModeScreen) && !const_defined?(:GameModeScreen, false)
    DiegoWTsStarterSelection = ::DiegoWTsStarterSelection if defined?(::DiegoWTsStarterSelection) && !const_defined?(:DiegoWTsStarterSelection, false)
    ChallengeModes = ::ChallengeModes if defined?(::ChallengeModes) && !const_defined?(:ChallengeModes, false)
    LevelCapsEX = ::LevelCapsEX if defined?(::LevelCapsEX) && !const_defined?(:LevelCapsEX, false)
    EncounterTypes = ::EncounterTypes if defined?(::EncounterTypes) && !const_defined?(:EncounterTypes, false)
    PokemonSelection = ::PokemonSelection if defined?(::PokemonSelection) && !const_defined?(:PokemonSelection, false)
    MessageConfig = ::MessageConfig if defined?(::MessageConfig) && !const_defined?(:MessageConfig, false)
    PokemonEntryScene = ::PokemonEntryScene if defined?(::PokemonEntryScene) && !const_defined?(:PokemonEntryScene, false)
    PokemonEntry = ::PokemonEntry if defined?(::PokemonEntry) && !const_defined?(:PokemonEntry, false)
    DrewQuest = ::DrewQuest if defined?(::DrewQuest) && !const_defined?(:DrewQuest, false)

    def activateQuest(quest, color = nil, *args)
      return TravelExpansionFramework.release_activate_quest!(quest, nil, false, color, *args)
    end

    def activateQuestSilent(quest, color = nil, *args)
      return TravelExpansionFramework.release_activate_quest!(quest, nil, true, color, *args)
    end

    def advanceQuestSilent(quest, stage = nil, *args)
      return TravelExpansionFramework.release_advance_quest!(quest, stage, *args)
    end

    def advanceQuestToStage(quest, stage = nil, *args)
      return TravelExpansionFramework.release_advance_quest!(quest, stage, *args)
    end

    def completeQuest(quest, *args)
      return TravelExpansionFramework.release_complete_quest!(quest, false, *args)
    end

    def completeQuestSilent(quest, *args)
      return TravelExpansionFramework.release_complete_quest!(quest, true, *args)
    end

    def getQuestStage(quest)
      return TravelExpansionFramework.release_quest_stage(quest)
    end

    def getCurrentStage(quest)
      return TravelExpansionFramework.release_quest_stage(quest)
    end

    def getActiveQuests
      return TravelExpansionFramework.release_quest_store(:active)
    end

    def getCompletedQuests
      return TravelExpansionFramework.release_quest_store(:completed)
    end

    def colorQuest(color = nil, *_args)
      TravelExpansionFramework.record_release_shim_hit("colorQuest", "menu_settings", "first_arg") if defined?(TravelExpansionFramework) &&
                                                                                                        TravelExpansionFramework.respond_to?(:record_release_shim_hit)
      return color
    rescue
      return nil
    end

    def pbUnlockRecipe(recipe_id = nil, *args)
      return TravelExpansionFramework.release_unlock_recipe!(recipe_id, *args)
    end unless method_defined?(:pbUnlockRecipe)

    def pbLockRecipe(recipe_id = nil, *args)
      return TravelExpansionFramework.release_lock_recipe!(recipe_id, *args)
    end unless method_defined?(:pbLockRecipe)

    def pbGetRecipes(flag = nil, *args)
      return TravelExpansionFramework.release_recipe_ids_for_flag(flag, *args)
    end unless method_defined?(:pbGetRecipes)

    def pbItemCrafter(stock = nil, speech1 = nil, speech2 = nil, *args)
      return TravelExpansionFramework.release_item_crafter(stock, speech1, speech2, *args)
    end unless method_defined?(:pbItemCrafter)

    def pbFormTrader(*args)
      return TravelExpansionFramework.release_safe_stub("pbFormTrader", "true", "item_handlers", *args)
    end unless method_defined?(:pbFormTrader)

    def pbFormTraderPC(*args)
      return TravelExpansionFramework.release_safe_stub("pbFormTraderPC", "host_pc", "item_handlers", *args)
    end unless method_defined?(:pbFormTraderPC)

    def pbStoryModeSetup(*args)
      if defined?($player) && $player
        $player.has_running_shoes = true if $player.respond_to?(:has_running_shoes=)
        $player.has_pokegear = true if $player.respond_to?(:has_pokegear=)
        $player.has_pokedex = true if $player.respond_to?(:has_pokedex=)
        $player.seen_storage_creator = true if $player.respond_to?(:seen_storage_creator=)
      end
      return TravelExpansionFramework.release_safe_stub("pbStoryModeSetup", "true", "startup", *args)
    rescue => e
      TravelExpansionFramework.log("[release] pbStoryModeSetup failed safely: #{e.class}: #{e.message}") if defined?(TravelExpansionFramework) &&
                                                                                                           TravelExpansionFramework.respond_to?(:log)
      return true
    end unless method_defined?(:pbStoryModeSetup)

    def pbStoryModeGiveDummyStarters(*args)
      return TravelExpansionFramework.release_safe_stub("pbStoryModeGiveDummyStarters", "true", "startup", *args)
    end unless method_defined?(:pbStoryModeGiveDummyStarters)

    def pbStoryModeRemoveDummyStarters(*args)
      return TravelExpansionFramework.release_safe_stub("pbStoryModeRemoveDummyStarters", "true", "startup", *args)
    end unless method_defined?(:pbStoryModeRemoveDummyStarters)

    def pbStoryModeTrainerItemSuite(*args)
      return TravelExpansionFramework.release_safe_stub("pbStoryModeTrainerItemSuite", "true", "item_handlers", *args)
    end unless method_defined?(:pbStoryModeTrainerItemSuite)

    def pbClearAllPokemonSetup(*args)
      return TravelExpansionFramework.release_safe_stub("pbClearAllPokemonSetup", "true", "startup", *args)
    end unless method_defined?(:pbClearAllPokemonSetup)

    def pbAllPokemonSetup5(*args)
      return TravelExpansionFramework.release_safe_stub("pbAllPokemonSetup5", "true", "startup", *args)
    end unless method_defined?(:pbAllPokemonSetup5)

    def pbAllPokemonSetup30(*args)
      return TravelExpansionFramework.release_safe_stub("pbAllPokemonSetup30", "true", "startup", *args)
    end unless method_defined?(:pbAllPokemonSetup30)

    def pbAllPokemonSetup50(*args)
      return TravelExpansionFramework.release_safe_stub("pbAllPokemonSetup50", "true", "startup", *args)
    end unless method_defined?(:pbAllPokemonSetup50)

    def pbAllPokemonSetup100(*args)
      return TravelExpansionFramework.release_safe_stub("pbAllPokemonSetup100", "true", "startup", *args)
    end unless method_defined?(:pbAllPokemonSetup100)

    def pbOptimisedPartyQuickStart5(*args)
      return TravelExpansionFramework.release_safe_stub("pbOptimisedPartyQuickStart5", "true", "startup", *args)
    end unless method_defined?(:pbOptimisedPartyQuickStart5)

    def pbOptimisedPartyQuickStart30(*args)
      return TravelExpansionFramework.release_safe_stub("pbOptimisedPartyQuickStart30", "true", "startup", *args)
    end unless method_defined?(:pbOptimisedPartyQuickStart30)

    def pbOptimisedPartyQuickStart50(*args)
      return TravelExpansionFramework.release_safe_stub("pbOptimisedPartyQuickStart50", "true", "startup", *args)
    end unless method_defined?(:pbOptimisedPartyQuickStart50)

    def pbOptimisedPartyQuickStart100(*args)
      return TravelExpansionFramework.release_safe_stub("pbOptimisedPartyQuickStart100", "true", "startup", *args)
    end unless method_defined?(:pbOptimisedPartyQuickStart100)

    def pbBattleModeSetup5(*args)
      return TravelExpansionFramework.release_safe_stub("pbBattleModeSetup5", "true", "trainer_battle", *args)
    end unless method_defined?(:pbBattleModeSetup5)

    def pbBattleModeSetup30(*args)
      return TravelExpansionFramework.release_safe_stub("pbBattleModeSetup30", "true", "trainer_battle", *args)
    end unless method_defined?(:pbBattleModeSetup30)

    def pbBattleModeSetup50(*args)
      return TravelExpansionFramework.release_safe_stub("pbBattleModeSetup50", "true", "trainer_battle", *args)
    end unless method_defined?(:pbBattleModeSetup50)

    def pbBattleModeSetup100(*args)
      return TravelExpansionFramework.release_safe_stub("pbBattleModeSetup100", "true", "trainer_battle", *args)
    end unless method_defined?(:pbBattleModeSetup100)

    def pbDumpOutAllItems(*args)
      return TravelExpansionFramework.release_safe_stub("pbDumpOutAllItems", "true", "item_handlers", *args)
    end unless method_defined?(:pbDumpOutAllItems)

    def pbJumpInAllItems(*args)
      return TravelExpansionFramework.release_safe_stub("pbJumpInAllItems", "true", "item_handlers", *args)
    end unless method_defined?(:pbJumpInAllItems)

    def pbPumbInAllItems(*args)
      return TravelExpansionFramework.release_safe_stub("pbPumbInAllItems", "true", "item_handlers", *args)
    end unless method_defined?(:pbPumbInAllItems)

    def pbRemoveBagClutter(*args)
      return TravelExpansionFramework.release_safe_stub("pbRemoveBagClutter", "true", "item_handlers", *args)
    end unless method_defined?(:pbRemoveBagClutter)

    def pbRemoveStoryModeBagClutter(*args)
      return TravelExpansionFramework.release_safe_stub("pbRemoveStoryModeBagClutter", "true", "item_handlers", *args)
    end unless method_defined?(:pbRemoveStoryModeBagClutter)

    def pbShowTipCard(*args)
      return TravelExpansionFramework.release_safe_stub("pbShowTipCard", "true", "menu_settings", *args)
    end unless method_defined?(:pbShowTipCard)

    def pbSetDialoguePortrait(*args)
      return TravelExpansionFramework.release_safe_stub("pbSetDialoguePortrait", "true", "menu_settings", *args)
    end unless method_defined?(:pbSetDialoguePortrait)

    def pbSetPlayerDialoguePortrait(*args)
      return TravelExpansionFramework.release_safe_stub("pbSetPlayerDialoguePortrait", "true", "menu_settings", *args)
    end unless method_defined?(:pbSetPlayerDialoguePortrait)

    def pbSetRivalDialoguePortrait(*args)
      return TravelExpansionFramework.release_safe_stub("pbSetRivalDialoguePortrait", "true", "menu_settings", *args)
    end unless method_defined?(:pbSetRivalDialoguePortrait)

    def pbClearDialoguePortrait(*args)
      return TravelExpansionFramework.release_safe_stub("pbClearDialoguePortrait", "true", "menu_settings", *args)
    end unless method_defined?(:pbClearDialoguePortrait)

    def pbPortraitMessage(message = nil, *args)
      return TravelExpansionFramework.release_portrait_message(message, *args)
    end unless method_defined?(:pbPortraitMessage)

    def pbPlayerPortraitMessage(message = nil, *args)
      return TravelExpansionFramework.release_portrait_message(message, *args)
    end unless method_defined?(:pbPlayerPortraitMessage)

    def pbRivalPortraitMessage(message = nil, *args)
      return TravelExpansionFramework.release_portrait_message(message, *args)
    end unless method_defined?(:pbRivalPortraitMessage)

    def pbVoidCharacterSetup(*args)
      return TravelExpansionFramework.release_safe_stub("pbVoidCharacterSetup", "void_character_setup", "startup", *args)
    end unless method_defined?(:pbVoidCharacterSetup)

    def pbStartQuest(quest, *args)
      return TravelExpansionFramework.release_activate_quest!(quest, nil, true, *args)
    end unless method_defined?(:pbStartQuest)

    def pbCompleteQuest(quest, *args)
      return TravelExpansionFramework.release_complete_quest!(quest, true, *args)
    end unless method_defined?(:pbCompleteQuest)

    def pbQuestStatus(quest, *_args)
      return TravelExpansionFramework.release_quest_stage(quest)
    end unless method_defined?(:pbQuestStatus)

    def pbQuestStarted?(quest, *_args)
      return TravelExpansionFramework.release_quest_started?(quest)
    end unless method_defined?(:pbQuestStarted?)

    def pbQuestComplete?(quest, *_args)
      return TravelExpansionFramework.release_quest_completed?(quest)
    end unless method_defined?(:pbQuestComplete?)

    def pbQuestKnown?(quest, *_args)
      return TravelExpansionFramework.release_quest_started?(quest)
    end unless method_defined?(:pbQuestKnown?)

    def startCharacterSelection(*args)
      TravelExpansionFramework.record_release_shim_hit("startCharacterSelection", "startup", "zero") if defined?(TravelExpansionFramework) &&
                                                                                                        TravelExpansionFramework.respond_to?(:record_release_shim_hit)
      return 0
    rescue
      return 0
    end unless method_defined?(:startCharacterSelection)

    def pbCharacterSelect(*args)
      return TravelExpansionFramework.release_safe_stub("pbCharacterSelect", "true", "startup", *args)
    end unless method_defined?(:pbCharacterSelect)

    def pbPokemonSelection(list = nil, must_choose = true, settings = nil)
      return Object.new.send(:pbPokemonSelection, list, must_choose, settings) if Object.private_method_defined?(:pbPokemonSelection)
      return TravelExpansionFramework.release_safe_stub("pbPokemonSelection", "starter_species", "startup", list, must_choose, settings)
    rescue
      return :PIKACHU
    end unless method_defined?(:pbPokemonSelection)

    def pbGrantRandomPokemonSilent(pokemon_array, level = 5)
      return Object.new.send(:pbGrantRandomPokemonSilent, pokemon_array, level) if Object.private_method_defined?(:pbGrantRandomPokemonSilent)
      return true
    end unless method_defined?(:pbGrantRandomPokemonSilent)

    def pbGrantRandomPokemon(pokemon_array, level = 5)
      return Object.new.send(:pbGrantRandomPokemon, pokemon_array, level) if Object.private_method_defined?(:pbGrantRandomPokemon)
      return true
    end unless method_defined?(:pbGrantRandomPokemon)

    def pbGetRandomPokemon(pokemon_array)
      return TravelExpansionFramework.release_random_available_species(pokemon_array)
    end unless method_defined?(:pbGetRandomPokemon)

    def pbApplyBattleRule(rule, value_type = nil, set_value = true, *args)
      return TravelExpansionFramework.release_safe_set_battle_rule!(rule, set_value)
    end unless method_defined?(:pbApplyBattleRule)

    def setBattleRule(*args)
      return TravelExpansionFramework.release_safe_set_battle_rule!(*args)
    end unless method_defined?(:setBattleRule)

    alias tef_release_original_method_missing method_missing unless method_defined?(:tef_release_original_method_missing)

    def method_missing(name, *args, &block)
      if defined?(TravelExpansionFramework) &&
         TravelExpansionFramework.respond_to?(:release_interpreter_method_shim)
        shim = TravelExpansionFramework.release_interpreter_method_shim(name, *args)
        return shim[:value] if shim && shim[:handled]
      end
      return tef_release_original_method_missing(name, *args, &block) if respond_to?(:tef_release_original_method_missing, true)
      super
    end

    def respond_to_missing?(name, include_private = false)
      if defined?(TravelExpansionFramework) &&
         TravelExpansionFramework.respond_to?(:release_interpreter_method_shim_name?) &&
         TravelExpansionFramework.release_interpreter_method_shim_name?(name)
        return true
      end
      return super
    end
  end

  class << Interpreter
    alias tef_release_original_const_missing const_missing unless method_defined?(:tef_release_original_const_missing)

    def const_missing(name)
      fallback = TravelExpansionFramework.release_constant_fallback(name) if defined?(TravelExpansionFramework) &&
                                                                            TravelExpansionFramework.respond_to?(:release_constant_fallback)
      return const_set(name, fallback) if fallback
      return tef_release_original_const_missing(name) if respond_to?(:tef_release_original_const_missing, true)
      raise NameError, "uninitialized constant Interpreter::#{name}"
    end
  end
end

class << Object
  alias tef_release_original_const_missing const_missing unless method_defined?(:tef_release_original_const_missing)

  def const_missing(name)
    fallback = TravelExpansionFramework.release_constant_fallback(name) if defined?(TravelExpansionFramework) &&
                                                                          TravelExpansionFramework.respond_to?(:release_constant_fallback)
    return const_set(name, fallback) if fallback
    return tef_release_original_const_missing(name) if respond_to?(:tef_release_original_const_missing, true)
    raise NameError, "uninitialized constant Object::#{name}"
  end
end

# Late safety net for quest APIs. Some imported intro scripts evaluate inside
# Interpreter after earlier guarded helpers were bypassed by partial definitions.
def pbStartQuest(quest = nil, *args)
  if defined?(TravelExpansionFramework) && TravelExpansionFramework.respond_to?(:release_activate_quest!)
    return TravelExpansionFramework.release_activate_quest!(quest, nil, true, *args)
  end
  return true
rescue
  return true
end

def pbCompleteQuest(quest = nil, *args)
  if defined?(TravelExpansionFramework) && TravelExpansionFramework.respond_to?(:release_complete_quest!)
    return TravelExpansionFramework.release_complete_quest!(quest, true, *args)
  end
  return true
rescue
  return true
end

def pbQuestStatus(quest = nil, *_args)
  return TravelExpansionFramework.release_quest_stage(quest) if defined?(TravelExpansionFramework) &&
                                                                TravelExpansionFramework.respond_to?(:release_quest_stage)
  return 0
rescue
  return 0
end

def pbQuestStarted?(quest = nil, *_args)
  return TravelExpansionFramework.release_quest_started?(quest) if defined?(TravelExpansionFramework) &&
                                                                   TravelExpansionFramework.respond_to?(:release_quest_started?)
  return false
rescue
  return false
end

def pbQuestComplete?(quest = nil, *_args)
  return TravelExpansionFramework.release_quest_completed?(quest) if defined?(TravelExpansionFramework) &&
                                                                     TravelExpansionFramework.respond_to?(:release_quest_completed?)
  return false
rescue
  return false
end

def pbQuestKnown?(quest = nil, *_args)
  return pbQuestStarted?(quest)
rescue
  return false
end

if defined?(Interpreter)
  class Interpreter
    def pbStartQuest(quest = nil, *args)
      return TravelExpansionFramework.release_activate_quest!(quest, nil, true, *args) if defined?(TravelExpansionFramework) &&
                                                                                         TravelExpansionFramework.respond_to?(:release_activate_quest!)
      return true
    rescue
      return true
    end

    def pbCompleteQuest(quest = nil, *args)
      return TravelExpansionFramework.release_complete_quest!(quest, true, *args) if defined?(TravelExpansionFramework) &&
                                                                                    TravelExpansionFramework.respond_to?(:release_complete_quest!)
      return true
    rescue
      return true
    end

    def pbQuestStatus(quest = nil, *_args)
      return TravelExpansionFramework.release_quest_stage(quest) if defined?(TravelExpansionFramework) &&
                                                                    TravelExpansionFramework.respond_to?(:release_quest_stage)
      return 0
    rescue
      return 0
    end

    def pbQuestStarted?(quest = nil, *_args)
      return TravelExpansionFramework.release_quest_started?(quest) if defined?(TravelExpansionFramework) &&
                                                                       TravelExpansionFramework.respond_to?(:release_quest_started?)
      return false
    rescue
      return false
    end

    def pbQuestComplete?(quest = nil, *_args)
      return TravelExpansionFramework.release_quest_completed?(quest) if defined?(TravelExpansionFramework) &&
                                                                         TravelExpansionFramework.respond_to?(:release_quest_completed?)
      return false
    rescue
      return false
    end

    def pbQuestKnown?(quest = nil, *_args)
      return pbQuestStarted?(quest)
    rescue
      return false
    end
  end
end

TravelExpansionFramework.refresh_release_compatibility! if defined?(TravelExpansionFramework) &&
                                                          TravelExpansionFramework.respond_to?(:refresh_release_compatibility!)
TravelExpansionFramework.write_release_index_report! if defined?(TravelExpansionFramework) &&
                                                       TravelExpansionFramework.respond_to?(:write_release_index_report!)
