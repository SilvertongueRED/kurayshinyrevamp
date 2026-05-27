# Kuray Infinite Fusion (KIF)

Kuray Infinite Fusion (KIF) is a fork of Infinite Fusion, which adds countless new features, including infinite colors for shinies, mods support (people can create mods and load them from a "Mods" folder), a powerful AI (thanks to DemICE), and more!

Kuray Infinite Fusion (KIF) is community-based and community-focused, it's made by the community, for the community, allowing anyone to easily create new features for Infinite Fusion and to have a better experience overall.

The original Pokemon Infinite Fusion (PIF) has been created by Chardub/Frogman, using Pokemon Essential.

Kuray Infinite Fusion (KIF) is standalone, which means, you do not need Pokemon Infinite Fusion (PIF), and you should NOT install KIF on top of a PIF game.

Please remember that the backbone of KIF (which is PIF) is still being developed and maintained by Chardub/Frogman, if PIF dies, KIF is very likely to die as well.

This Github allows you to see the game (open-source), but also to contribute to the development of this project with pull-requests, and download the latest release to stay up-to-date.

# Experimental Full Tester Build

This checkout now reflects the current local merged tester build rather than the older lighter public package. It includes the current KIF/PIF merge work, the Custom Species Framework stack, the modded multiplayer files, travel expansion support pieces, the GBA Player scaffold, and the current packaged mod set from this install.

This is a human-directed, AI-assisted experimental upgrade build. It is meant to help testers inspect the real source/content changes and install the current tester build more easily.

## Important Warnings

- This is not an official stable upstream build.
- It may break progression, conflict with future upstream changes, or corrupt saves.
- Your saves do **not** live inside the game folder. They live under `%APPDATA%\kurayinfinitefusion`, so using a separate install folder alone does not fully isolate save risk.
- `player_identity_bedroom`, `custom_species_framework`, imported species content, the modded multiplayer stack, and the experimental `zzz_gba_player` scaffold are included in this tester build.
- This GitHub checkout now mirrors the current experimental tester code, data, mod, and installer-tooling content from the live workspace.
- The release assets are still the easiest player path because they provide the one-click installer, the full sprite-heavy playable package, checksums, and the split portable archive fallback.

## Current Install Path

- Release page: [2026-05-12 Full Current Tester Build (Experimental)](https://github.com/this-is-neat/kurayshinyrevamp/releases/tag/2026-05-12-full-current)
- Direct installer: [PIF-player-build-20260527-full-current-WebSetup.exe](https://github.com/this-is-neat/kurayshinyrevamp/releases/download/2026-05-12-full-current/PIF-player-build-20260527-full-current-WebSetup.exe)
- Portable archive fallback: download all `PIF-player-build-20260527-full-current.7z.001` release parts from the same release page, then extract the first part.
- Release notes and checksums in-repo: [`Releases/2026-05-12-full-current/README.md`](./Releases/2026-05-12-full-current/README.md)

# Official Links
Website: https://www.kurayinfinitefusion.com/

Discord: https://discord.gg/kuray-hub-1121345297352753243 | https://discord.gg/vZUCRxDTPe

Twitter: https://twitter.com/kuray_hub

Reddit: https://www.reddit.com/r/kurayhub/

Github: https://github.com/kurayamiblackheart/kurayshinyrevamp *(You are here!)*

YouTube: https://www.youtube.com/@kuraylab

Twitch: https://www.twitch.tv/kurayamiblackheart


Pokemon Infinite Fusion (PIF) Github: https://github.com/infinitefusion/infinitefusion-e18

Pokemon Infinite Fusion (PIF) Discord: https://discord.gg/infinitefusion

Pokemon Essential Github: https://github.com/Maruno17/pokemon-essentials


**If you've been banned from our Discord (the Kuray Hub), you can fill this form to ask for an unban, or informations about the ban:** https://forms.gle/TPCprf38ANmYNB5T8

-----------------------------------------------

# Installation
_The repo now mirrors the current experimental install content, but the recommended player path is still the release installer: [PIF-player-build-20260527-full-current-WebSetup.exe](https://github.com/this-is-neat/kurayshinyrevamp/releases/download/2026-05-12-full-current/PIF-player-build-20260527-full-current-WebSetup.exe)._

_If Windows blocks the installer, use the portable archive fallback from the same release page by downloading all `PIF-player-build-20260527-full-current.7z.001` parts and extracting the first part._

_The current one-click install/reinstall notes and checksums are in [`Releases/2026-05-12-full-current/README.md`](./Releases/2026-05-12-full-current/README.md)._

_Text instruction on how to Install KIF are available on our Discord: https://discord.gg/UFxQkUZeyE_

__Google Docs of the game (OBSOLETE, but some informations are still useful):__ https://docs.google.com/document/d/1O6pKKL62dbLcapO0c2zDG2UI-eN6uatYlt_0GSk1dbE/edit

# List of Constant Features

- **Modding support** **| by DEMICE**
- Game's Speed up to **x10** & displayed on the title **| by REIZOD**
- No double-confirmation for unfusing **| by REIZOD**
- Revamped Gender Icons **| by REIZOD**
- IV/EVs in Pokemon's Summary **| by LUMINATRON**
- Pokemon can relearn Pre-Evolution moves **| by REIZOD**
- Quick Surf is now Quick Field Moves **| by REIZOD**
- 161 more PC backgrounds **| by REIZOD**
- Transgender stone works with genderless, male and female **| by REIZOD**
- Endgame challenge & Powerful AI by DemICE, now opponents fight for real! **| by DEMICE**
- Infinite Save Files, new backup file created at each save **| by DEMICE**
- Custom Fusion Icons support **| by REIZOD**
- Self-Battle *(battle your own Pokemons from your PC/"Battlers" folder/Team !)* **| by REIZOD, TRAPSTARR & DEMICE**
- Shiny Finder.exe *(a program created by Reïzod which allows you to quickly see all the shiny possibilities of a .png sprite)* **| by REIZOD**
- Auto-updater *(thanks to HungryPickle)*, the game will check for update by itself, and if there is an update, will ask you whether you want to update or not (when launching the game), if you press yes, it will update without you having to do anything, and it will automatically restart, all updated! **| By HUNGRYPICKLE**
- Brought back the feature that allowed in PIF to breed fused Pokemons. Before PIF 6.0, it was possible to do this in the base game of PIF. Now it's KIF-exclusive. **| by REIZOD**
- A tool that allows you to install all the sprites *(autogen and custom)* from PIF's gitlab servers, so that you can have all the sprites that have been made for the game locally on your computer! Running this tool may take a few hours, please only run it overnight, or when you can let it run for a long time. There's more than 200 000 small sprites involved, so it takes a while to move them and organize them on the computer. You can also manually access those sprites from the gitlab servers yourself by following those links: https://gitlab.com/pokemoninfinitefusion/autogen-fusion-sprites *(autogen)* & https://gitlab.com/pokemoninfinitefusion/customsprites *(custom)* **| by REIZOD**
- Mystery Gift *(KIF distributes mystery gifts, to be informed on ongoing distributions and their passwords, please join the Discord server)* **| by REIZOD**
- Patches a lot of PIF bugs, making the game more stable.

# List of Optional Features (you can turn them ON/OFF and/or configure/customize them!)

- Shiny Animations Toggle **| by REIZOD**
- Shiny Revamp *(using a system built from scratch doing channels shifting on top of hue shifting for very complex color manipulations, **37 964 160 000 shiny combinations** on all sprites, also using black, grey and white as color. Two shinies are different now, you can have a Black Charmander and a Blue Charmander, generated Pokemons have their own shiny data!)* | *There's 3 modes to choose from, the default one has 360 possible shinies *(only uses hue shifting)*, the second one is the normal mode, with hue shifting and channels shifting, with 622 080 possible shinies, the third one is the most advanced color manipulations one, with over 37 billions possible shinies.* **| by REIZOD**
- 1v1/2v2/3v3 Wild Battles **| by REIZOD**
- 1v1/2v2/3v3 Trainer Battles **| by REIZOD**
- Shiny Icons **| by REIZOD**
- Export/Export All/Import One Random/Import All Pokemons *(from/to .json & .png files, store your Pokemons on your computer&share them to other players! You can even store their appearence (sprite) too! Possibility to export the shiny .png sprite of a Shiny Pokemon as well!)* **| by REIZOD**
- Lock Evolution *(prevents a Pokemon from evolving until manually unlocked on an evo-locked Pokemon)* **| by REIZOD**
- Choose/Re-roll Shiny Colors *(DEBUG only)* **| by REIZOD**
- Shiny Dye Fusing **| by JUSTANOTHERU5ER**
- Shiny Preview on Fusions, and Fusion Preview *(no black/green silhouettes)* **| by REIZOD**
- Robust Level Caps *(customizable system, from Smart Exp Points, to Locked Exp Points, to obtaining Rare Candies when exceeding the cap instead of levelling up)* **| by REIZOD & HUNGRYPICKLE**
- Buy more PC boxes *(infinite)* **| by REIZOD**
- Gamble to transform Pokemon into Shiny/Change its Shiny Colors **| by REIZOD**
- Sort Pokemons in PC, sort a single box/all boxes *(options: Specie Name, Name, Dex Number, Level, HP, Atk, Def, SpA, SpD, Spe, Caught Date, Shiny, OT (Original Trainer's name), Gender, Ability, Nature, Held Item, First Type, Second Type, Caught Map (Map ID), Happiness, Exp, Markings, Total IVs (sum of IVs), Total EVs (sum of EVs))* **| by REIZOD**
- Multi-Select in PC **| by SYLVI**
- Change Game's Font **| by REIZOD**
- Pokemons' Sprites as Icons *(in team and PC boxes)* **| by SYLVI**
- Individual Custom Sprites *(can have 2 Eevees with different sprites, all sprites availables are being used giving more uniqueness to each Pokemon)* **| by REIZOD**
- Kuray Shop *(buy items/HM/etc unobtainable otherwises (rare candie, masterball, transgender/mist stones, ...))* **| by REIZOD**
- Dynamic Self-Fusions stat boosts *(the Pokemons with the worst base stats gets the most boost from a self-fusion)*, you can turn this feature on/off in the options. **| by REIZOD** 
- ~~Blacklisting/Rarity/Re-roll/Reset systems for sprites | by REIZOD~~ *(Abandoned, will have to be re-done)*
- PC & Instant Heal from menu **| by REIZOD**
- ~~Per-Save File/Global feature system | by SYLVI~~ *(Not working)*
- Change Shiny Odds from options menu **| by REIZOD**
- Pokemons added to Pokedex when catching/evolving fusions **| by TRAPSTARR**
- Consumables Items recovered after battle **| by TRAPSTARR**
- Configurable ExpAll redistribution. **| by HUNGRYPICKLE**
- Types Icons in-battle *(various sets of icons to choose from)* **| by TRAPSTARR & MIRASEIN & FAIRYGODMOTHER**
- Auto-Battle **| by REIZOD & TRAPSTARR**
- Trainers use Shinies *(can be configured so that the Trainers can have shinies constantly, or only for their Ace, or never, if the feature is activated, the Shiny Wild odds will make it possible for the trainers to have random shinies as well. This feature goes well with the Rocket Mode, which allows you to catch trainers' Pokemons)* **| by TRAPSTARR**
- Damage Variance deactivatable **| by DEMICE**
- Option to unfuse traded Pokemons *(can be turned ON/OFF in the Options Menu)* **| by REIZOD**
- Quicksave Feature **| by DEMICE**
- Dark Battle GUI & More battle GUI to choose from **| by TRAPSTARR & MIRASEIN**
- Option to enable/disable the sprite selection in Pokedex when catching a new Pokemon **| by REIZOD**
- Option to enable/disable the prompt that asks you if you wish to nickname a newly obtained Pokemon **| by REIZOD**
- Option to enable/disable the prompt that asks you if you wish to add a newly obtained Pokemon in your team or send it to PC **| by REIZOD**
- Option to skip the intro cutscene when launching the game *(Open a batch console (you can do so by pressing WIN+R and entering "cmd" in the box), then execute this code: ``echo:Y>"%appdata%\kurayinfinitefusion\NoIntro.krs"``. Breakdown: The code will create a file named "NoIntro.krs" in your savefile directory. When this file exists, the intro cutscene will always be skipped at launch, launching the game faster.)* **| by REIZOD**
- Ability to decompile and recompile the game entirely *(PIF does not allow you to decompile their database, but KIF allows you to do so)* - PLEASE, do not use this utility feature if you do not know what you're doing. It is available in the debug options menu. **| by REIZOD**
- Brought back the feature that allowed in PIF to breed legendaries Pokemon, and any Pokemon, if the Pokemon that was unbreedable was the head in the fusion *(for example, a Mew head with a Pikachu head fusion, can breed if this feature is activated in the options)* before PIF 6.0, it was possible to do this in the base game of PIF. Now it's a KIF-exclusive option. **| by REIZOD**
- Poison Overworld Config, allows you to make it so that Pokemons with certain abilities are immune to Poison in the Overworld *(can configure it so that they even heal from Overworld Poison, this feature is disabled by default)* **| by BLUEWUPPO**
- Modern Hail feature *(optional)* **| by BLUEWUPPO**
- Bug Type Buff feature *(optional)* **| by BLUEWUPPO**
- Ice Type Buff feature *(optional)* **| by BLUEWUPPO**
- Frostbite instead of Frozen feature *(optional)* **| by BLUEWUPPO**
- Drowsy instead of Asleep feature *(optional)* **| by BLUEWUPPO**
- Add Event Moves to the Battle Factory Egg Move Tutor **| by HUNGRYPICKLE & REKT1029**
- Brought back the dominant typing for fusions that were in PIF before PIF 6.0, it is now a KIF-exclusive option. **| by DEMICE**
- Ability to adjust the base stats spread for fused Pokemons. **| by HUNGRYPICKLE**
- Tutor.net, allows you to teach TMs that you've already obtained to your Pokemons, also registers move tutors, all your move teaching in one menu! **| by DEMICE**
- Added a "Metronome Madness" challenge *(forces Pokemons to use the move Metronome)*. **| by REIZOD**
- Added a "Letdown" challenge *(sometimes, a Pokemon will use Splash instead of the move it was supposed to use)*. **| by REIZOD**
- Added a "Berserker" challenge *(all the stats of the enemy will raise, the frequency depends on the difficulty you've choosen on this challenge)* **| by REIZOD**
- Ability to choose how the speed-up works *(choose between Toggling the speed-up value, or only speeding up when you hold the button)* **| by REIZOD**
- Shiny Cache System *(optimizes performances when displaying shinies from KIF, also allows you to access all the shinies .png from the "Cache" folder)*, because of the massive performance boost, the cache is turned on by default. **| by REIZOD**
- Create and Load options presets, to quickly change between game configurations! **| by REIZOD**
- Exempt boxes from the "Sort All Pokemons" feature. **| by REIZOD**
- Exempt boxes from the "Export All Pokemons" feature. **| by REIZOD**
- No-EVs Mode: This mode disable EVs, forcing all Pokemons to have 0 EVs *(it is non-destructive, so if you disable it again, the EVs your Pokemons had beforehand will be saved, this mode simply ignores the EVs of the Pokemons during stats calculations, it applies retroactively to every Pokemons, including enemies, it will also show "0" as EVs in the Pokemons' summaries)*. **| by REIZOD**
- Max IVs Mode: This mode forces all Pokemons to have 31 IVs *(it is also non-destructive, it does not overwrite the real IVs of Pokemons, it just ignores their real IVs and use the value "31" in all calculations regarding IVs as long as the mode is activated, it applies retroactively and to enemies as well, just like the No-EVs Mode)*. **| by REIZOD**
- Added an option to display the level of the Pokemons in battle when using No Level Mode aka Base Stats Mode (warning: the levels of the Pokemons do not impact their stats in this mode!), that option may be helpful for moves such as Seismic Toss, etc. **| by REIZOD**
- Added a Rocket Mode, which is disabled by default. If enabled, you can catch the Pokemons of other trainers. You can configure it to work only on Rocket Ball or for every balls. If activated, Rocket Balls will appear in the Kuray Shop right at the start of the game. **| by REIZOD**
- Added a Trainer Exp. Boost modifier. By default in PIF/KIF, the exp. boost from defeating a trainer's Pokemon is +50%. You can change that boost now. **| by REIZOD**
- Added EVs Train Mode *(When you turn this new option ON, the enemies Pokemons will never yield their Pokemon's species EVs. However, the held Power-items will continue to give 4 of their respective EVs to your Pokemons. It's a QoL that allows you to utilize Power Anklet (Speed), Power Band (Special Defense), Power Belt (Defense), Power Bracer (Attack), Power Lens (Special Attack) and Power Weight (HP) to EVs train without having the EVs yields of the enemies Pokemons interfering with your EVs training.)* **| by REIZOD**
- Added Auto-Battle Shortcut *(Enabled by default. If disabled, the shortcut keybind to toggle Auto-Battle ON/OFF during battles will be disabled)* **| by REIZOD**
- Added Auto-Battle Shiny Stop *(Disabled by default. If enabled, the Auto-Battle will automatically turn itself OFF if a wild Shiny pokemon is encountered)* **| by REIZOD**
- K-Eggs (Kuray Eggs)*, available in the Kuray Shop. Those items can be used from the Bag to spawn a random Pokémon (a Fire K-Egg will give you a random Fire Pokémon, etc). K-Eggs uses the Catch Rate of Pokémon as their rarity (the lower the catch rate, the rarer the Pokémon in K-Eggs). K-Eggs are 10 times more likely to be shiny than wild encounters. You can customize the K-Eggs system in the Options.* **| by REIZOD**
