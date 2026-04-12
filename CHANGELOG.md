# XP & Skills System — Changelog

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
