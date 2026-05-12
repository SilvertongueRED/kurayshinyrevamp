# Autoplay Dex Bot

This managed KIF/PIF mod adds a pausable autoplay runtime for route exploration,
battle automation, and dex collection tracking.

## Controls

- Press the configured pause key, default `F6`, to start, pause, or resume.
- When paused, virtual input is cleared and the player can take over normally.
- If the bot gets stuck or sees an unknown gate, it pauses and logs the reason.

## Data

- Runtime state: `Mods/autoplay_bot/data/state.json`
- Generated world cache: `Mods/autoplay_bot/data/cache/world_index.json`
- Logs: `Mods/autoplay_bot/logs/autoplay_bot.log`
- Guide pack: `Mods/autoplay_bot/data/guides/default.json`

The guide pack can be expanded with walkthrough-derived story objectives. The
bot also scans map transfers, trainers, item rewards, gift/static Pokemon, and
wild observations from the active save.
