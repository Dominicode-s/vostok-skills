# XP & Skills System — Changelog

### v2.5.3
- **Character.gd overrides now chain `super()`** for `Energy`, `Hydration`, `Mental`, `Stamina`, `Temperature`, and `Clamp`. Previously all six were full replacements, which silently dropped any other Character.gd-overriding mod's logic (e.g., an injuries rework mod layered on top).
- **Math preserved exactly at default MCM values.** The rewrites use two techniques:
  - **Scaled-delta** (Energy / Hydration / Mental / Temperature): zero out `gameData.xp<Stat>` so base's built-in `(1 - xp<Stat> × 0.08)` multiplier becomes 1.0, then pass `delta × (1 − skill_bonus)` to super. Net drain = `delta × skill_bonus / N`, identical to the old full-replacement formula.
  - **Injection** (Stamina / Clamp): inject the equivalent `xp<Stat>` level into `gameData` across the super call so base's own multiplier produces our desired bonus. Slight precision loss possible if you use custom MCM multipliers; defaults are exact.
- `_ready()` deliberately still skips `super()` — base `Character._ready()` re-initializes survival stats and would wipe our setup (documented gotcha in the modding guide).

### v2.5.2
- **Fixed Interface.gd CHAIN BROKEN warning** when stacked with Cash System / Secure Container. Two override fixes:
  - `_process(delta)` now calls `super(delta)` so mods layered on top of XP still get their `_process` invoked.
  - `UpdateStats(updateLabels)` rewritten from a full-replacement into a delta-style override. Now calls `super(updateLabels)` first (letting the base game + any intermediate mod compute their version), then adds only the skill-based carry-weight bonus on top and re-evaluates overweight + capacity labels. Prior to this, fully replacing the base method silently dropped any other Interface.gd mod's `UpdateStats` logic.
- No behavioural change for a solo XP install — same capacity math, same label output.

### v2.5.1
- **Book textures shrunk by ~22 MB** (VMZ payload), no visual change:
  - Icon PNGs pre-resampled to 128×256 on disk. The mod's runtime loader was already calling `Image.INTERPOLATE_LANCZOS` to resample every icon to that exact target, so shipping at source resolution (720×1456) was pure waste. The on-disk result is bit-equivalent to what the game was computing at load time.
  - Cover PNGs downscaled from 1024×1024 → 512×512. Covers wrap a small in-hand book model and sample well below 1:1 at normal grip distance, so the visual result is indistinguishable.
  - All PNGs recompressed with max DEFLATE + palette quantization where lossless.

### v2.5.0
- **New: 9 dedicated skill books, covering all 13 skills.** Each book is a fresh item built at runtime (Cash-mod pattern) — vanilla Literature books are no longer repurposed. Books spawn as **Rare civilian loot** and can be read for XP into one or two skills:
  - **Fitness Manual** → Pack Mule *(solo)*
  - **Athletic Training Guide** → Athleticism *(solo)*
  - **Meditations** → Iron Will *(solo)*
  - **Art of Moving Unseen** → Stealth *(solo)*
  - **Scavenger's Almanac** → Scavenger *(solo)*
  - **Field Medical Handbook** → Vitality + Regeneration *(dual)*
  - **Wilderness Survival Primer** → Hunger Resist + Thirst Resist *(dual)*
  - **Combat Marksmanship** → Recoil Control + Composure *(dual)*
  - **Arctic Field Guide** → Cold Resistance + Endurance *(dual)*
- **XP + auto-level mechanic unchanged from v2.4.** Solo books grant the MCM-configured base XP (default 200) to one skill's pool; dual books grant `base × 60%` total split 50/50. The pool auto-levels the skill whenever it covers the next cost; surplus at max-level is discarded so the save file doesn't carry stranded XP forever. Pool state persists in `XPData.cfg → [skillbook_pool]`, wiped on death reset / new game alongside everything else.
- **Real cover + inventory icon art for all 9 books.** Covers ship as 1024×1024 PNGs that get mapped onto the vanilla `MS_Book.obj` mesh; icons ship as 720×1456 PNGs resampled to 128×256 for the inventory grid. Procedurally tinted placeholders are still generated as fallback if any PNG is missing from `mods/XPSkillsSystem/Books/`. Cover/icon files are picked up automatically — no code changes needed to swap art.
- **Disabled-skill XP fallback.** Reading a book whose listed skill(s) are turned off in MCM used to be a no-op. Now the portion of a book's XP that would go to a disabled skill is redirected to the general spendable XP pool instead. A solo book with its skill disabled gives full base XP to general XP; a dual book with one slot disabled splits half into the enabled pool and half into general XP. `xpTotal` (lifetime counter) still reflects the full amount either way.
- **Boot-time performance.**
  - On-disk resources are cached in `user://XPSkillsBookCache.cfg`. First launch (and any launch where the source PNGs change — tracked by size+mtime) regenerates all 9 books from source; subsequent launches skip the ~18 PNG decodes + ~27 disk writes and load the cached `.tres` files directly.
  - Pickup scenes (the bulky part — they pull in the 1024×1024 cover texture) are **lazy-loaded** on first use rather than at boot. Most sessions never pay the cover-decoding cost because loot containers store `SlotData` references, not pickup instances; the scene only loads when a book is actually dropped, placed, or respawned in a shelter.
  - Fixed an initial bug where `ItemData.tres` was embedding the full icon bitmap inline (~550 KB per book) because the in-memory `ImageTexture` hadn't been bound to its saved file. `take_over_path` now registers the icon properly so `ItemData.tres` shrinks to a ~2 KB ext_resource reference.
  - Cache format version is baked into the signature so future on-disk layout changes invalidate stale caches automatically.
  - First boot is still ~3–5 seconds of regen (unavoidable — PNG decode, image resize, disk writes for 27 files). Every boot after that should be sub-second until art is updated. Further optimization possible (deferring icon loads, persisting the catalog to `.cfg`) — not pursued in v2.5; room to revisit if boot feels heavy.
- **Drop / Place fixes.** Base `Interface.Drop` and `Interface.ContextPlace` both call `Database.get(item.file)` and `queue_free` the item if the lookup fails — which would silently delete any custom mod item. Both are now overridden to route `XPSkillbook_*` files through our catalogued pickup scene (mirrors the Cash mod pattern). Non-skillbook items still delegate to `super` so other mods in the override chain keep working.
- **Horizontal scrollbar on the Skills panel removed.** Long skill descriptions ("+5% Loot Chance (better at higher levels)") were pushing the row wider than the container width, forcing a horizontal scrollbar on the `ScrollContainer`. Fixed by disabling horizontal scroll on the container and enabling `clip_text = true` on description labels — full text now shows as a tooltip on hover instead.
- **Shelter persistence.** Base `LoadShelter` skips any pickup whose `file` isn't in `Database` (prints "File missing"), so books dropped in the Cabin or Tent would vanish on reload. We re-instantiate them ourselves after `LoadShelter` finishes (same pattern the Cash mod uses).
- **Removed: v2.4 vanilla-book ItemData patching.** The four base-game Literature books (`Book_Children`, `Book_Cooking`, `Book_Fishing`, `Book_Religion`) are no longer touched; they revert to their vanilla unusable behavior. Players who had v2.4 accumulated `skillbook_pool` progress will carry it forward into v2.5 — the pool keys (`pack_mule`, `hunger_resist`, etc.) didn't change.
- **Trader stock: Generalist carries skill books.** Each book is flagged `generalist = true` so it enters the Generalist trader's rotating supply bucket alongside civilian loot rolls. Books also carry the `grandma = true` flag for forward-compat if/when the base game wires up Grandma as a stocking trader (`Trader.gd:FillTraderBucket()` doesn't currently read that flag).
- Exposed in MCM: **Enable Skill Books** toggle, **Skill Book Base XP**, **Dual-Skill Book Multiplier (%)**. Disabling removes books from new loot rolls and disables the Read action; existing world/inventory books persist but become inert until re-enabled.
- Compatibility: we only append to `res://Loot/LT_Master.tres` (removing only our own entries on toggle-off), and our pickup scenes reuse vanilla assets, so other mods editing the loot table or book items are unaffected. Consume remains intercepted through the `Character.gd` override chain via `super(item)`.
- **Thanks:** to **DSGG1994** for the skill-books concept (readable books that grant XP toward specific skills, with the solo-vs-dual XP split), and to **Sr Rinite** for the RPG-flavored direction — skill-pool accumulators, auto-leveling, and the broader "perks / legendary stats" framing that motivated moving beyond flat XP rewards.

### v2.4.0 (superseded by v2.5.0)
- Skill Books v1 — repurposed the four vanilla Literature books as readable trainers. Replaced by v2.5's dedicated items so vanilla books stay vanilla. Concept: **DSGG1994**. RPG-style per-skill XP pool + auto-level mechanic: **Sr Rinite**.
- **Fixed: new-game XP reset not firing on some fresh starts (community report).** Previously the new-game detector relied solely on `user://XPSkillsMarker.tres` being deleted by the base game's `FormatSave()`. Any `SaveXP()` call between `FormatSave` and our menu→game transition check recreated the marker and masked the new-game signal, leaving skill levels from the previous run intact. We now also check `Character.tres.initialSpawn` — set `true` by `Loader.NewGame()` and only cleared by `Loader.SaveCharacter()`, so it reliably flags the fresh-start window regardless of marker races. Either signal now triggers the XP + prestige wipe.

### v2.3.0
- **New skill: Composure** — reduces camera shake when taking damage, similar to an aim-punch modifier. Each level trims 10% off the rotation `Damage.gd` applies to the camera rig on hit, maxing out at 50% reduction after 5 levels. Prestigable like any other skill (2% per rank, cap 10).
- Applied non-intrusively — no new script override. Main.gd caches the hit-shake `Node3D` via the existing `node_added` hook and scales `rotation` in a `_physics_process` with `process_physics_priority = 10`, so Damage.gd's own computation runs first and ours scales the result. Mods that *do* override `res://Scripts/Damage.gd` (e.g. aim-punch modifier) continue to work — our dampener just scales whatever rotation that override produced.
- Exposed in MCM: **Enable Composure** toggle, **Composure Shake Reduce Per Level (%)**, and **Prestige Composure per Rank (%)**.
- No migration needed — new skill defaults to level 0, so existing saves behave identically until the player spends XP on it.

### v2.2.4
- **Rebalanced prestige Regen bonus to match v2.2.3's lowered base regen.** When base regen dropped from 0.20 to 0.02 HP/s per skill level, the old prestige regen default of +0.05 HP/s per rank became wildly strong relative to a skill level (~250% instead of the intended ~25%). Prestige Regen default is now 0.005 HP/s per rank, matching the ~25% of a skill level ratio that the other prestige stats (Vitality, Pack Mule, etc.) use.
- Prestige Regen MCM entry is now a Float slider with 0.001 HP/s precision (range 0.000–0.100), consistent with the base regen slider from v2.2.3.
- Migration: the stale Int entry for `cfg_prestige_regen` is automatically erased from the saved MCM config on load, same pattern as the v2.2.3 migration for base regen.

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
