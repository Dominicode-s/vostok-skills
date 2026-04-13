# XP & Skills System — Changelog

### v2.1.0
- **Compatibility with Patty's Profiles** — XP/skill state is now saved per-profile at `user://XPData_<profile>.cfg`. Each profile keeps its own progression, death reset only affects the active profile, and switching profiles in the menu reloads the correct state on next game start. First-time Patty install automatically migrates existing `XPData.cfg` into the active profile
- **Container Search XP now supports fractional values** (0.1–5.0 in 0.1 steps) — the MCM slider has been moved to a Float control, and partial XP accumulates across containers (e.g. 0.3 per container awards 1 XP every ~4 containers searched). Progress persists across sessions
- **Fixed trader task XP being re-awarded on every visit** — `Loader.LoadTrader()` clears and repopulates `tasksCompleted` on interaction, which looked like a delta to our poll. Per-trader completion counts are now persisted in `XPData.cfg`, seeded from `user://Traders.tres` on each menu→game transition (so existing progression is never miscounted), and only genuine new completions award XP
- **Fixed crash on zone transition when Athleticism is leveled** — speed bonus no longer writes to Controller during scene teardown (`isTransitioning`/`isCaching`), and now captures the real base walk/sprint speeds on first contact instead of hardcoded values, so it composes with mods that modify movement speed
- **Fixed missing kill XP with HellmAI** — kill detection now uses a 3-second pending-kill grace window, so physics/process frame timing mismatches and HellmAI's heavier death pipeline no longer drop kills. Fire window extended from 500ms to 2000ms. Detection broadened to track any AI class exposing `dead` + `Death()` (no longer requires `boss`)
- **Fixed boot crash with MCM + certain autoload orders** — script overrides are now installed via `call_deferred`, so other autoloads finish their own `_ready` before we reload and take over the base Interface/Character scripts
- **Fixed boot crash caused by stale pre-v2.0 marker file** — `XPSkillsMarker.tres` is now force-rewritten on load with a clean `Resource`, so old markers that referenced deleted override scripts can no longer fail to load
- Fixed missing frostbite damage in Character.gd override — the base game's `-delta/10` frostbite HP bleed was omitted, so frostbite was cosmetic while this mod was active
- Fixed cold resistance being double-applied (both the Character.gd override and a Main.gd compensator were running)
- Fixed null dereference in Scavenger loot duplication when a source item had partially-populated `slotData`
- Fixed unbounded growth of the awarded-containers cache — all per-session tracking state is now cleared when returning to the main menu

### v2.0.0
- **Major compatibility improvement** — removed 4 of 6 script overrides to eliminate conflicts with popular mods
- Kill XP, search XP, trade XP, task XP, and speed bonus now use polling-based detection instead of `take_over_path`
- Fixes conflicts with HellmAI, Faction Warfare, LootFloorFix, Trader Improvements, Weapons Spawn with Mag and Ammo, and other mods
- Moved Scavenger loot system from LootContainer.gd to Main.gd
- Removed trade XP hook from Interface.gd (now handled in Main.gd)
- Deleted override files: AI.gd, LootContainer.gd, Trader.gd, Controller.gd
- Remaining overrides: Character.gd (health/vitals) and Interface.gd (Skills UI)
- Known limitation: Stealth skill (AI hearing reduction) cannot work without AI.gd override

### v1.6.0
- Sync skill levels to gameData fields for mod compatibility — HP, stamina, carry weight, hunger, thirst, mental, and regen now work even if another mod overrides Character.gd
- Fixed Recoil Control skill not applying — weapon rigs are preloaded so script override was too late; now modifies recoil data values directly when weapons are equipped
- Removed Recoil.gd script override (replaced by data modification approach)
- Added safety clamp on recoil multiplier to prevent inverted recoil at extreme config values

### v1.5.2
- Fixed kills not awarding XP — `isFiring` timing race condition in game's physics frame
- Kill detection now checks `Input.is_action_pressed("fire")` for reliable same-frame attribution

### v1.5.1
- Fixed XP/skills persisting across new games — starting a new character now properly resets mod XP
- Uses a `.tres` marker file that the game's save wipe automatically cleans on new game

### v1.5.0
- Changed all MCM Float sliders to Int — values now shown as whole numbers (e.g. 8% instead of 0.08)
- Existing MCM settings will reset to defaults on first launch

### v1.4.1
- Fixed AI-on-AI kills (Faction Warfare) incorrectly awarding XP to the player
- Added grenade kill attribution — grenade kills now properly award XP
- Kill detection uses `isFiring` for gun kills and grenade throw tracking with a time window

### v1.4.0
- New skill: Scavenger — chance to find extra loot when opening containers (5% per level, max 25%)
- Added per-skill enable/disable toggles in MCM — disabled skills are hidden from the UI
- Disabled skills preserve invested points — re-enabling restores them
- All skill effects now respect enabled state (toggling off a skill stops its bonuses)

### v1.3.2
- Fixed skills not applying (Vitality HP, etc.) — reverted super() call in Character.gd that conflicted with base game initialization

### v1.3.1
- Added null guards in LootContainer.gd to prevent crashes
- Added super() calls in Character.gd and Recoil.gd overrides
- Set focus_mode to NONE on injected buttons

### v1.3.0
- Added modworkshop update checking support

### v1.0.0
- Initial release
- XP earned from looting, kills, and exploration
- Skill tree with passive bonuses (recoil, stamina, carry weight, etc.)
- Persistent XP and skills across sessions
- MCM config support
