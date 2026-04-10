# XP & Skills System — Changelog

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
