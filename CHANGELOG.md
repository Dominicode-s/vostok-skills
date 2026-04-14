# XP & Skills System — Changelog

### v2.2.3
- **Regen slider is now a granular Float slider with 0.01 HP/s precision.** Previously it was an integer slider in "×0.1 HP/s" steps, which meant the lowest non-zero setting was 0.1 HP/s per level — too fast for players who wanted a gentle passive trickle. You can now set anything from 0.00 (disabled) to 2.00 HP/s per Regeneration skill level, in 0.01 increments.
- **Default regen lowered from 0.2 to 0.02 HP/s per level.** Fully maxed Regeneration (skill level 5) now passively heals 0.10 HP/s — roughly 17 minutes to heal 100 HP. Players who preferred the old aggressive regen can simply crank the slider back up.
- Migration: any existing `Int` entry for `cfg_regen_per_level` in your saved MCM config is automatically erased on load, so the new Float default applies cleanly without a leftover phantom value from the old schema.
- Cosmetic: the Skills UI description line for Regeneration now renders the value as "+0.02 HP/sec Regen" (two decimal places) instead of relying on raw `str()` which could show float-precision noise.

### v2.2.2
- **Compatibility with mods that override Character.gd's Health() function** (e.g. injuries-system-rework) — our `Health()` no longer reimplements the damage block line-for-line. It now calls `super(delta)` to delegate damage to whatever is next in the override chain (base game, or another mod sitting between us and the base). This means other mods' custom damage tuning (bleeding timers, fracture-while-running, rupture/headshot behaviour, etc.) actually runs when both mods are installed together, instead of being silently skipped because our non-super reimplementation was blocking them.
- To avoid double-applied regen, `gameData.xpRegen` is temporarily zeroed across the `super()` call so the base game's hardcoded `xpRegen * 0.2` regen block short-circuits — our own configurable `cfg_regen_per_level` + prestige regen is then applied once, after super, exactly as before.
- No behaviour change in vanilla (no other Character.gd mod installed): all base damage conditions still apply via super → base, and our regen + prestige bonus runs on top just like in v2.2.1.

### v2.2.1
- Fixed prestige ranks persisting into a new game. The new-game detection path (marker file wiped by FormatSave) was only calling ResetXP, which preserves prestige by design so it survives regular death. New game is unambiguous so it now also clears prestige_counts and deletes the XPPrestige file regardless of the "Reset Prestige on Death" toggle.

### v2.2.0
- **Added: Prestige system** — once every enabled skill is at its max level, a new Prestige button appears at the bottom of the Skills panel. Clicking it opens a picker modal where you choose one stat; confirming wipes all XP and skill levels in exchange for a permanent rank in that stat that stacks additively on top of the regular skill tree.
- Prestige bonuses are separate from skill levels: they don't get baked into your skill count, they're a permanent baseline that everything else builds on top of. A Vitality prestige rank 3 character with Vitality skill level 10 gets +15 HP from skill (10 × 5) + 9 HP from prestige (3 × 3) = +24 HP on top of the 100 base.
- **Vitality (max HP) is uncapped** — keep prestiging it as much as you want. Every other skill caps at 10 prestige ranks by default to keep late-game balance sane.
- Stored separately at `user://XPPrestige_<profile>.cfg` so death reset and ResetXP don't touch prestige. Profile-aware (follows Patty's Profiles just like XPData does). Works across map/shelter transitions.
- Each skill row now shows a **✦N** badge next to its level when that skill has prestige ranks.
- New MCM options: enable/disable prestige, per-stat bonus magnitudes, shared cap for non-Vitality skills, and a hardcore "Reset Prestige on Death" toggle.

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
