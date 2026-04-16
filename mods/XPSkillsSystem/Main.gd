extends Node

var gameData = preload("res://Resources/GameData.tres")

# New-game detection — marker file is wiped by FormatSave() on new game
var _prev_menu: bool = false

# Kill Attribution
const GRENADE_WINDOW_MS: int = 6000
const FIRE_WINDOW_MS: int = 2000
const KILL_GRACE_MS: int = 3000
var last_grenade_time: int = 0
var _last_fire_time: int = 0
var _prev_grenade1: bool = false
var _prev_grenade2: bool = false

# Compat — AI death polling for kill XP (no AI.gd override needed)
var _tracked_ai: Array = []
var _pending_kills: Array = []

# Compat — Container tracking for search XP (no LootContainer.gd override)
var _awarded_containers: Dictionary = {}
var _prev_interface: bool = false

# Compat — Trade tracking (no Interface.gd trade hook needed)
var _trade_btn: Button = null
var _trade_connected: bool = false

# Compat — Task tracking (no Trader.gd override needed)
# Persisted per-trader completed-task counts, keyed by traderData.name.
# Loader.LoadTrader() clears + repopulates tasksCompleted on interaction,
# so an in-memory baseline would treat every re-populate as fresh completions.
var _tracked_traders: Array = []
var cfg_trader_task_counts: Dictionary = {}

# Compat — Patty's Profiles: records the XPData path we last loaded. When
# _get_xp_data_path() starts returning a different path, we reload state.
# Stays as the legacy path when Patty isn't installed, so the comparison
# never fires and the compat layer is fully dormant.
var _last_xp_path: String = ""

# Compat — Speed bonus (no Controller.gd override needed)
# Base speeds are captured on first Controller contact so we amplify whatever
# the game (or another mod) set as the real base, rather than hardcoded guesses.
var _controller_ref: Node = null
var _controller_base_walk: float = 2.5
var _controller_base_sprint: float = 5.0

# Scavenger SFX
var _sfx_search: AudioStreamMP3
var _sfx_door: AudioStreamMP3

# Composure — cache the hit-shake Node3D (runs res://Scripts/Damage.gd) so we
# can dampen its rotation in _physics_process without overriding the script.
var _damage_node: Node3D = null

# Recoil — weapon rigs are preloaded in Database.gd so take_over_path can't
# replace the script. Instead we modify recoil data values when equipped.

# XP State
var xp: int = 0
var xpTotal: int = 0
var xpHealth: int = 0
var xpStamina: int = 0
var xpCarry: int = 0
var xpHunger: int = 0
var xpThirst: int = 0
var xpMental: int = 0
var xpRegen: int = 0
var xpColdRes: int = 0
var xpStealth: int = 0
var xpRecoil: int = 0
var xpSpeed: int = 0
var xpScavenger: int = 0
var xpComposure: int = 0

# Config — XP rewards
var cfg_xp_container: float = 1.0
var cfg_xp_kill: int = 25
var cfg_xp_boss: int = 100
var cfg_xp_trade: int = 10
var cfg_xp_task: int = 50

# Container XP fraction accumulator — persists progress when the per-search
# reward is fractional (e.g. 0.3), so every ~3–4 containers grants 1 XP.
var _container_xp_fraction: float = 0.0

# Config — Death behavior
var cfg_death_resets: bool = true

# Config — Skill bonuses per level
var cfg_hp_per_level: float = 5.0
var cfg_stamina_reduce: float = 0.10
var cfg_carry_per_level: float = 2.0
var cfg_hunger_reduce: float = 0.08
var cfg_thirst_reduce: float = 0.08
var cfg_mental_reduce: float = 0.08
var cfg_regen_per_level: float = 0.02
var cfg_coldres_reduce: float = 0.08
var cfg_stealth_reduce: float = 0.05
var cfg_recoil_reduce: float = 0.05
var cfg_speed_bonus: float = 0.04
var cfg_scavenger_chance: float = 0.05
var cfg_shake_reduce: float = 0.10

# Config — Skill max levels
var cfg_max_levels: Array = [10, 10, 10, 10, 10, 10, 5, 10, 10, 10, 5, 5, 5]

# Config — Skill cost bases
var cfg_cost_bases: Array = [25, 25, 20, 20, 20, 20, 50, 20, 25, 25, 30, 30, 25]

# Config — Skill enabled toggles (index matches skill order)
var skill_ids: Array = ["vitality", "endurance", "pack_mule", "hunger_resist", "thirst_resist", "iron_will", "regeneration", "cold_resistance", "stealth", "recoil_control", "athleticism", "scavenger", "composure"]
var cfg_skill_enabled: Dictionary = {
	"vitality": true, "endurance": true, "pack_mule": true,
	"hunger_resist": true, "thirst_resist": true, "iron_will": true,
	"regeneration": true, "cold_resistance": true, "stealth": true,
	"recoil_control": true, "athleticism": true, "scavenger": true,
	"composure": true
}

# ─── Prestige ─────────────────────────────────────────────────
# Permanent bonuses earned by wiping all XP + skill levels. Unlocked
# when every enabled skill is at its max level. Each prestige rank
# adds a small additive bonus ON TOP of the skill tree (not baked
# into effective skill level). Stored separately at
# user://XPPrestige_<profile>.cfg so death / ResetXP don't wipe it
# (unless cfg_prestige_reset_on_death is on).

var cfg_prestige_enabled: bool = true
var cfg_prestige_reset_on_death: bool = false

# Per-skill permanent bonus magnitudes (per prestige rank).
# Roughly half the strength of a skill level so combined they're
# meaningful but not absurd. All exposed in MCM.
var cfg_prestige_hp: float = 3.0        # Vitality: +3 max HP
var cfg_prestige_stamina: float = 0.03  # Endurance: -3% drain
var cfg_prestige_carry: float = 1.0     # Pack Mule: +1 kg
var cfg_prestige_hunger: float = 0.02   # Hunger: -2% drain
var cfg_prestige_thirst: float = 0.02   # Thirst: -2% drain
var cfg_prestige_mental: float = 0.02   # Iron Will: -2% drain
var cfg_prestige_regen: float = 0.005   # Regen: +0.005 HP/s (25% of a skill level at default base regen)
var cfg_prestige_coldres: float = 0.02  # Cold Resist: -2% drain
var cfg_prestige_stealth: float = 0.02  # Stealth: -2% (no-op, kept for consistency)
var cfg_prestige_recoil: float = 0.02   # Recoil: -2% recoil
var cfg_prestige_speed: float = 0.01    # Athleticism: +1% speed
var cfg_prestige_scavenger: float = 0.02  # Scavenger: +2% loot chance
var cfg_prestige_composure: float = 0.02  # Composure: -2% camera shake

# Per-skill prestige rank caps. -1 = unlimited (only Vitality by default).
# Order matches skill_ids.
var cfg_prestige_caps: Array = [-1, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10]

# Runtime prestige state — skill_id -> rank count.
var prestige_counts: Dictionary = {}

# MCM integration
var _mcm_helpers = null
const MCM_FILE_PATH = "user://MCM/XPSkillsSystem"
const MCM_MOD_ID = "XPSkillsSystem"

func _ready():
    Engine.set_meta("XPMain", self)
    # Run _physics_process AFTER Damage.gd's so our Composure dampening scales
    # the rotation it just wrote. process_physics_priority: higher = later.
    process_physics_priority = 10
    # Rewrite any pre-v2.0 marker with a clean Resource. Older versions may
    # have saved a custom resource referencing override scripts that v2.0+
    # deleted, which caused script-load crashes on boot.
    _migrate_marker_file()
    _mcm_helpers = _try_load_mcm()
    if _mcm_helpers:
        _register_mcm()
    else:
        LoadConfig()
    LoadXP()
    # Install script overrides on the next frame so every other autoload has
    # finished its own _ready first. Calling reload()/take_over_path() inline
    # during autoload init can race with mods that already resolved the base
    # script (MCM in particular).
    call_deferred("_install_overrides")
    get_tree().node_added.connect(_on_node_added)

func _install_overrides():
    # Only Interface.gd and Character.gd overrides are kept.
    # Interface.gd: Skills UI tab, carry weight, button integration.
    # Character.gd: Health bonus (max HP), regen, vitals drain reduction, death reset.
    # All other overrides replaced with compat polling in _process().
    overrideScript("res://mods/XPSkillsSystem/Interface.gd")
    overrideScript("res://mods/XPSkillsSystem/Character.gd")

func _migrate_marker_file():
    if FileAccess.file_exists("user://XPSkillsMarker.tres"):
        var marker = Resource.new()
        ResourceSaver.save(marker, "user://XPSkillsMarker.tres")

# --- Patty's Profiles compat ---
# Patty stores per-profile copies of .tres files in user://profiles/<name>/,
# but .cfg files are shared across profiles. We key XPData.cfg by profile so
# each profile gets its own XP/skill state. With no Patty installed, falls
# back to user://XPData.cfg.

func _get_active_profile() -> String:
    if !FileAccess.file_exists("user://profiles/active_profile.cfg"):
        return ""
    var cfg = ConfigFile.new()
    if cfg.load("user://profiles/active_profile.cfg") != OK:
        return ""
    return str(cfg.get_value("profiles", "active", ""))

func _get_xp_data_path() -> String:
    var profile = _get_active_profile()
    if profile.is_empty():
        return "user://XPData.cfg"
    return "user://XPData_" + profile + ".cfg"

func _copy_file_bytes(src: String, dst: String):
    var f_in = FileAccess.open(src, FileAccess.READ)
    if !f_in:
        return
    var data = f_in.get_buffer(f_in.get_length())
    f_in.close()
    var f_out = FileAccess.open(dst, FileAccess.WRITE)
    if !f_out:
        return
    f_out.store_buffer(data)
    f_out.close()

func _process(delta):
    # Detect menu→game transition to check for new game
    if _prev_menu and !gameData.menu:
        # Patty Profiles compat: if the active profile changed while the
        # player was in the menu, reload state from the new profile's file.
        # Zero cost without Patty — the path never changes so this is a
        # single string compare.
        if _get_xp_data_path() != _last_xp_path:
            LoadXP()
        if !FileAccess.file_exists("user://XPSkillsMarker.tres"):
            ResetXP()
            # New game wipes prestige too. ResetXP alone only wipes prestige
            # when the hardcore "reset on death" toggle is on, because it
            # also runs on regular death. New game is unambiguous so we
            # always clear prestige here regardless of that toggle.
            prestige_counts.clear()
            var pp = _get_prestige_path()
            if FileAccess.file_exists(pp):
                DirAccess.remove_absolute(ProjectSettings.globalize_path(pp))
            print("[XP Skills] New game detected — XP and prestige reset")
        _ensure_marker()
        # Seed trader baselines from the authoritative save file. Must happen
        # after LoadXP (so profile-switched counts are respected) and after
        # ResetXP (so new games start with zero baselines rather than stale
        # ones). No-ops for traders already present in cfg_trader_task_counts.
        _sync_trader_baselines_from_save()
    # Detect game→menu transition: drop all per-session caches so a new run
    # starts with a clean slate (fixes stale node refs and container leak).
    if !_prev_menu and gameData.menu:
        _reset_session_state()
    _prev_menu = gameData.menu

    # Keep gameData fields in sync so base game code uses our levels
    # even if another mod stomped our Character.gd override
    if !gameData.menu:
        _sync_to_gamedata()

    # Track grenade throws for kill attribution
    var g1 = gameData.grenade1 if "grenade1" in gameData else false
    var g2 = gameData.grenade2 if "grenade2" in gameData else false
    if (_prev_grenade1 and !g1) or (_prev_grenade2 and !g2):
        last_grenade_time = Time.get_ticks_msec()
    _prev_grenade1 = g1
    _prev_grenade2 = g2

    # Track fire input for kill attribution (semi-auto fire window)
    if Input.is_action_pressed("fire") or ("isFiring" in gameData and gameData.isFiring):
        _last_fire_time = Time.get_ticks_msec()

    # Track state transitions (must update before early returns)
    var _interface_just_opened = gameData.interface and !_prev_interface
    _prev_interface = gameData.interface

    if gameData.menu or gameData.shelter:
        return

    # --- Compat XP tracking (replaces script overrides) ---

    # Kill XP — poll tracked AI nodes for death
    _track_kills()

    # Container XP — detect container open via interface state
    if _interface_just_opened and !gameData.isTrading:
        _check_container_xp.call_deferred()

    # Trade XP — connect to Accept button when trading
    if gameData.isTrading and !_trade_connected:
        _connect_trade_button()

    # Task XP — monitor trader task completions
    _track_tasks()

    # Speed bonus — set Controller walk/sprint speeds
    _apply_speed_bonus()

    # Cold resistance is applied inside Character.gd Temperature() override.
    # No Main.gd compensation needed — running both was double-applying it.

func is_player_kill() -> bool:
    if Input.is_action_pressed("fire"):
        return true
    if gameData.isFiring:
        return true
    # Semi-auto fire window — button may be released before death is detected
    if _last_fire_time > 0 and (Time.get_ticks_msec() - _last_fire_time) <= FIRE_WINDOW_MS:
        return true
    if last_grenade_time > 0 and (Time.get_ticks_msec() - last_grenade_time) <= GRENADE_WINDOW_MS:
        return true
    return false

func overrideScript(path: String):
    var script = load(path)
    if !script:
        push_warning("XPSkillsSystem: Failed to load " + path)
        return
    script.reload()
    var parent = script.get_base_script()
    if !parent:
        push_warning("XPSkillsSystem: No base script for " + path)
        return
    script.take_over_path(parent.resource_path)

func _on_node_added(node: Node):
    # Recoil reduction on weapon equip
    if node is Node3D and node.name == "Recoil" and node.has_method("ApplyRecoil"):
        _apply_recoil_reduction.call_deferred(node)
        return

    # Composure — cache the camera hit-shake node so _physics_process can
    # scale its rotation without needing a Damage.gd override.
    if node is Node3D:
        var s: Script = node.get_script()
        if s and s.resource_path == "res://Scripts/Damage.gd":
            _damage_node = node
            return

    # AI tracking for kill XP — broadened detection for modded AI classes
    # that may not declare `boss` (e.g. custom factions).
    if "dead" in node and node.has_method("Death"):
        if node not in _tracked_ai:
            _tracked_ai.append(node)
        return

    # Trader tracking for task XP. We don't capture a baseline here because
    # tasksCompleted isn't yet populated — LoadTrader() fills it on interaction.
    # The real baseline lives in cfg_trader_task_counts (persisted in XPData.cfg).
    if "tasksCompleted" in node and "traderData" in node:
        _tracked_traders.append(weakref(node))
        return

func _apply_recoil_reduction(node: Node):
    if !is_instance_valid(node) or !"data" in node or !node.data:
        return
    var level = get_level(9)
    var prestige_reduction = prestige_recoil_bonus()
    if level <= 0 and prestige_reduction <= 0.0:
        return
    var mult = maxf(1.0 - (level * cfg_recoil_reduce) - prestige_reduction, 0.05)
    # Duplicate so we don't modify the shared weapon template resource
    node.data = node.data.duplicate()
    node.data.verticalRecoil *= mult
    node.data.horizontalRecoil *= mult
    node.data.kick *= mult

func is_skill_enabled(index: int) -> bool:
    if index < 0 or index >= skill_ids.size():
        return false
    return cfg_skill_enabled.get(skill_ids[index], true)

# --- Compat: Kill XP (replaces AI.gd override) ---

func _track_kills():
    # Step 1: drain freshly-dead AI into the pending bucket, keep the living.
    var now = Time.get_ticks_msec()
    var still_alive: Array = []
    for ai in _tracked_ai:
        if !is_instance_valid(ai):
            continue
        if ai.dead:
            _pending_kills.append({"ref": ai, "died_at": now})
        else:
            still_alive.append(ai)
    _tracked_ai = still_alive

    # Step 2: re-check is_player_kill() every frame within a grace window,
    # so a single-frame miss (physics vs process divergence, HellMAI's heavier
    # death pipeline, etc.) doesn't permanently lose the kill.
    if _pending_kills.is_empty():
        return
    var still_pending: Array = []
    for pk in _pending_kills:
        var ai = pk.ref
        if !is_instance_valid(ai):
            continue
        if is_player_kill():
            var is_boss: bool = ai.boss if "boss" in ai else false
            var xpReward = cfg_xp_boss if is_boss else cfg_xp_kill
            xp += xpReward
            xpTotal += xpReward
            SaveXP()
        elif (now - pk.died_at) < KILL_GRACE_MS:
            still_pending.append(pk)
    _pending_kills = still_pending

# --- Compat: Container/Search XP (replaces LootContainer.gd override) ---

func _check_container_xp():
    var ui = get_tree().current_scene.get_node_or_null("/root/Map/Core/UI")
    if !ui:
        return
    var iface = ui.get_node_or_null("Interface")
    if !iface or !"container" in iface or !iface.container:
        return
    var cid = iface.container.get_instance_id()
    if cid in _awarded_containers:
        return
    _awarded_containers[cid] = true
    # Accumulate fractional rewards so values like 0.3 actually work:
    # search ~4 containers = +1 XP. Whole-number configs award instantly.
    _container_xp_fraction += cfg_xp_container
    var whole: int = int(floor(_container_xp_fraction))
    if whole > 0:
        xp += whole
        xpTotal += whole
        _container_xp_fraction -= float(whole)
    SaveXP()
    # Scavenger skill — bonus loot from containers. Prestige grants a
    # permanent baseline chance even at skill level 0.
    if get_level(11) > 0 or prestige_scavenger_bonus() > 0.0:
        get_tree().create_timer(0.1).timeout.connect(_try_scavenge.bind(iface, ui))

func _try_scavenge(iface, ui_manager):
    var chance = get_level(11) * cfg_scavenger_chance + prestige_scavenger_bonus()
    if randf() >= chance:
        return
    if iface == null or !is_instance_valid(iface):
        return
    if !"containerGrid" in iface or iface.containerGrid == null:
        return
    if !"container" in iface or !iface.container:
        return
    var level = get_level(11)
    var roll = randf()
    var bonus_item = _try_loot_pool_spawn(level, roll, iface)
    if bonus_item:
        _show_scavenge_notify(ui_manager, bonus_item)
        return
    # Fallback: duplicate an existing container item
    var items = []
    for child in iface.containerGrid.get_children():
        if "slotData" in child:
            items.append(child)
    if items.is_empty():
        return
    var source_item = items[randi() % items.size()]
    if !source_item.slotData or !source_item.slotData.itemData:
        return
    var item_name = str(source_item.slotData.itemData.name)
    var dupe_data = source_item.slotData.duplicate()
    if !dupe_data or !dupe_data.itemData:
        return
    if dupe_data.itemData.stackable:
        dupe_data.amount = 1
    if iface.AutoStack(dupe_data, iface.containerGrid) or iface.Create(dupe_data, iface.containerGrid, true):
        _show_scavenge_notify(ui_manager, item_name)

func _try_loot_pool_spawn(level: int, roll: float, iface) -> String:
    if level <= 2:
        return ""
    # Access loot buckets from the current container
    var container = iface.container if "container" in iface else null
    if !container:
        return ""
    var commonBucket = container.commonBucket if "commonBucket" in container else []
    var rareBucket = container.rareBucket if "rareBucket" in container else []
    var legendaryBucket = container.legendaryBucket if "legendaryBucket" in container else []
    var bucket: Array = []
    if level == 3:
        if roll < 0.30 and commonBucket.size() > 0:
            bucket = commonBucket
    elif level == 4:
        if roll < 0.20 and rareBucket.size() > 0:
            bucket = rareBucket
        elif roll < 0.50 and commonBucket.size() > 0:
            bucket = commonBucket
    elif level >= 5:
        if roll < 0.10 and legendaryBucket.size() > 0:
            bucket = legendaryBucket
        elif roll < 0.35 and rareBucket.size() > 0:
            bucket = rareBucket
        elif roll < 0.60 and commonBucket.size() > 0:
            bucket = commonBucket
    if bucket.is_empty():
        return ""
    var item_data = bucket.pick_random()
    var new_slot = SlotData.new()
    new_slot.itemData = item_data
    if item_data.defaultAmount != 0:
        new_slot.amount = randi_range(1, item_data.defaultAmount)
    if item_data.type == "Weapon" or item_data.subtype == "Light" or item_data.subtype == "NVG":
        new_slot.condition = randi_range(25, 100)
    if iface.AutoStack(new_slot, iface.containerGrid) or iface.Create(new_slot, iface.containerGrid, true):
        return item_data.name
    return ""

func _load_scavenge_sfx():
    if _sfx_search:
        return
    var base = "res://mods/XPSkillsSystem/sounds"
    var f = FileAccess.open(base + "/search.mp3", FileAccess.READ)
    if f:
        _sfx_search = AudioStreamMP3.new()
        _sfx_search.data = f.get_buffer(f.get_length())
        f.close()
    f = FileAccess.open(base + "/door.mp3", FileAccess.READ)
    if f:
        _sfx_door = AudioStreamMP3.new()
        _sfx_door.data = f.get_buffer(f.get_length())
        f.close()

func _show_scavenge_notify(ui_manager, item_name: String):
    _load_scavenge_sfx()
    var sfx = _sfx_search
    if _sfx_door and randf() < 0.002:
        sfx = _sfx_door
    if sfx:
        var player = AudioStreamPlayer.new()
        player.stream = sfx
        player.volume_db = 0.0
        get_tree().root.add_child(player)
        player.play()
        player.finished.connect(player.queue_free)
    var label = Label.new()
    label.text = "⭐ Scavenger: +1 " + item_name
    label.add_theme_font_size_override("font_size", 16)
    label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.anchors_preset = Control.PRESET_CENTER_TOP
    label.offset_top = 60
    label.z_index = 100
    ui_manager.add_child(label)
    var tween = label.create_tween()
    tween.tween_property(label, "modulate:a", 0.0, 1.5).set_delay(1.0)
    tween.tween_callback(label.queue_free)

# --- Compat: Trade XP (replaces Interface.gd trade hook) ---

func _connect_trade_button():
    var ui = get_tree().current_scene.get_node_or_null("/root/Map/Core/UI")
    if !ui:
        return
    var iface = ui.get_node_or_null("Interface")
    if !iface:
        return
    var btn = iface.get_node_or_null("Deal/Panel/Buttons/Accept")
    if btn and btn is Button:
        if !btn.pressed.is_connected(_on_trade_accept):
            btn.pressed.connect(_on_trade_accept)
        _trade_btn = btn
        _trade_connected = true

func _on_trade_accept():
    xp += cfg_xp_trade
    xpTotal += cfg_xp_trade
    SaveXP()

# --- Compat: Task XP (replaces Trader.gd override) ---

func _track_tasks():
    var still_valid: Array = []
    var awarded := false
    for wref in _tracked_traders:
        var trader = wref.get_ref()
        if !trader or !is_instance_valid(trader):
            continue
        still_valid.append(wref)
        # traderData may load slightly after the node is added; skip until ready
        if !("traderData" in trader) or trader.traderData == null:
            continue
        var key: String = str(trader.traderData.name)
        if key.is_empty():
            continue
        var current_count: int = trader.tasksCompleted.size()
        # First sight: seed the baseline. _sync_trader_baselines_from_save() has
        # already run on menu→game to seed historical counts from Traders.tres,
        # so this only fires for truly new traders or new games.
        if not cfg_trader_task_counts.has(key):
            cfg_trader_task_counts[key] = current_count
            continue
        var baseline: int = cfg_trader_task_counts[key]
        if current_count > baseline:
            var completed = current_count - baseline
            xp += cfg_xp_task * completed
            xpTotal += cfg_xp_task * completed
            cfg_trader_task_counts[key] = current_count
            awarded = true
        # Never ratchet the baseline DOWN here. On zone reload the trader is
        # re-instantiated with an empty tasksCompleted until LoadTrader() runs,
        # which would otherwise look like "save wiped" and re-award history
        # on the next repopulate. New games are handled by ResetXP().
    _tracked_traders = still_valid
    if awarded:
        SaveXP()

func _sync_trader_baselines_from_save():
    # Read user://Traders.tres (the base game's authoritative task list) and
    # seed cfg_trader_task_counts for any trader not already tracked. Fixes
    # the first-install scenario where a player has historical trader progress
    # that we'd otherwise miscount once LoadTrader() repopulates tasksCompleted.
    # Uses has() so fresher in-session values are never overwritten.
    if !FileAccess.file_exists("user://Traders.tres"):
        return
    var save = load("user://Traders.tres")
    if save == null:
        return
    # Duck-type instead of `is TraderSave` — the class_name registry may not
    # be ready yet, and any future save format adding new trader sections
    # shouldn't break us either.
    for trader_name in ["Generalist", "Doctor", "Gunsmith", "Grandma"]:
        if cfg_trader_task_counts.has(trader_name):
            continue
        var prop = trader_name.to_lower()
        if prop in save and save.get(prop) is Array:
            cfg_trader_task_counts[trader_name] = save.get(prop).size()

# --- Compat: Speed bonus (replaces Controller.gd override) ---

func _apply_speed_bonus():
    var level = get_level(10)
    var prestige_bonus = prestige_speed_bonus()
    if level <= 0 and prestige_bonus <= 0.0:
        return
    # Never touch the Controller mid-scene-load — is_instance_valid can return
    # true during teardown, and writing to a half-freed node crashes. Users
    # reported this as the athleticism zone-transition CTD.
    if "isTransitioning" in gameData and gameData.isTransitioning:
        return
    if "isCaching" in gameData and gameData.isCaching:
        return
    var bonus = 1.0 + (level * cfg_speed_bonus) + prestige_bonus
    if _controller_ref and is_instance_valid(_controller_ref) and _controller_ref.is_inside_tree():
        _controller_ref.sprintSpeed = _controller_base_sprint * bonus
        _controller_ref.walkSpeed = _controller_base_walk * bonus
        return
    # Stale or first-contact — lazy re-lookup.
    _controller_ref = null
    var scene = get_tree().current_scene
    if !scene:
        return
    var ctrl = scene.get_node_or_null("/root/Map/Core/Controller")
    if ctrl and ctrl.is_inside_tree() and "sprintSpeed" in ctrl and "walkSpeed" in ctrl:
        _controller_ref = ctrl
        # Capture the REAL base speeds before we modify them, so compatible mods
        # that bump base speed (or the game applying injury/state penalties)
        # stack correctly with ours instead of being stomped.
        _controller_base_walk = ctrl.walkSpeed
        _controller_base_sprint = ctrl.sprintSpeed
        ctrl.sprintSpeed = _controller_base_sprint * bonus
        ctrl.walkSpeed = _controller_base_walk * bonus

func _reset_session_state():
    # Drop all per-run caches. Called on entering the main menu so the next
    # run starts clean — prevents stale Node refs across Map reloads and
    # caps _awarded_containers growth.
    _awarded_containers.clear()
    _pending_kills.clear()
    _tracked_ai.clear()
    _tracked_traders.clear()
    _controller_ref = null
    _trade_btn = null
    _trade_connected = false
    _damage_node = null

# --- Compat: Composure (reduces camera shake on hits) ---

func _physics_process(_delta):
    # Scale down the rotation Damage.gd just wrote when the player has
    # Composure skill or prestige ranks. We run after Damage.gd thanks to
    # process_physics_priority, so rotation already holds this frame's value.
    if gameData.menu or gameData.shelter:
        return
    if not gameData.damage and not gameData.impact:
        return
    var level = get_level(12)
    var prestige_bonus = prestige_composure_bonus()
    if level <= 0 and prestige_bonus <= 0.0:
        return
    if not _damage_node or not is_instance_valid(_damage_node):
        return
    var mult = maxf(1.0 - (level * cfg_shake_reduce) - prestige_bonus, 0.05)
    _damage_node.rotation *= mult

func get_level(index: int) -> int:
    if not is_skill_enabled(index):
        return 0
    match index:
        0: return xpHealth
        1: return xpStamina
        2: return xpCarry
        3: return xpHunger
        4: return xpThirst
        5: return xpMental
        6: return xpRegen
        7: return xpColdRes
        8: return xpStealth
        9: return xpRecoil
        10: return xpSpeed
        11: return xpScavenger
        12: return xpComposure
    return 0

# ─── Prestige helpers ─────────────────────────────────────────

func get_prestige_count(skill_index: int) -> int:
    if skill_index < 0 or skill_index >= skill_ids.size():
        return 0
    return int(prestige_counts.get(skill_ids[skill_index], 0))

func get_prestige_cap(skill_index: int) -> int:
    if skill_index < 0 or skill_index >= cfg_prestige_caps.size():
        return 10
    return int(cfg_prestige_caps[skill_index])

func can_prestige_skill(skill_index: int) -> bool:
    # A skill can receive more prestige ranks if its cap is unlimited (-1)
    # or if its current rank count is below the cap.
    var cap = get_prestige_cap(skill_index)
    if cap < 0:
        return true
    return get_prestige_count(skill_index) < cap

func is_prestige_available() -> bool:
    # Unlocked when every ENABLED skill is at its max level, and at least
    # one skill is enabled. Returns false if the prestige feature itself
    # is disabled in MCM.
    if not cfg_prestige_enabled:
        return false
    var has_enabled := false
    for i in skill_ids.size():
        if is_skill_enabled(i):
            has_enabled = true
            if get_level(i) < cfg_max_levels[i]:
                return false
    return has_enabled

func do_prestige(skill_index: int) -> bool:
    # Sanity checks — callers (UI) should already verify these, but be
    # defensive since prestige is destructive.
    if not is_prestige_available():
        return false
    if skill_index < 0 or skill_index >= skill_ids.size():
        return false
    if not can_prestige_skill(skill_index):
        return false
    # Wipe all XP and stored skill levels. _zero_xp_state clears the XP
    # state but NOT prestige_counts, which is the whole point.
    _zero_xp_state()
    var sid: String = skill_ids[skill_index]
    prestige_counts[sid] = int(prestige_counts.get(sid, 0)) + 1
    SaveXP()
    _save_prestige()
    _sync_to_gamedata()
    return true

# Per-skill additive prestige bonuses. Callers (Character.gd, Interface.gd,
# and Main.gd's own compat polling) add these to the skill-tree bonus so
# prestige is a permanent baseline that stacks on top of leveling.

func prestige_hp_bonus() -> float:
    return get_prestige_count(0) * cfg_prestige_hp

func prestige_stamina_bonus() -> float:
    return get_prestige_count(1) * cfg_prestige_stamina

func prestige_carry_bonus() -> float:
    return get_prestige_count(2) * cfg_prestige_carry

func prestige_hunger_bonus() -> float:
    return get_prestige_count(3) * cfg_prestige_hunger

func prestige_thirst_bonus() -> float:
    return get_prestige_count(4) * cfg_prestige_thirst

func prestige_mental_bonus() -> float:
    return get_prestige_count(5) * cfg_prestige_mental

func prestige_regen_bonus() -> float:
    return get_prestige_count(6) * cfg_prestige_regen

func prestige_coldres_bonus() -> float:
    return get_prestige_count(7) * cfg_prestige_coldres

func prestige_stealth_bonus() -> float:
    return get_prestige_count(8) * cfg_prestige_stealth

func prestige_recoil_bonus() -> float:
    return get_prestige_count(9) * cfg_prestige_recoil

func prestige_speed_bonus() -> float:
    return get_prestige_count(10) * cfg_prestige_speed

func prestige_scavenger_bonus() -> float:
    return get_prestige_count(11) * cfg_prestige_scavenger

func prestige_composure_bonus() -> float:
    return get_prestige_count(12) * cfg_prestige_composure

func _get_prestige_path() -> String:
    var profile = _get_active_profile()
    if profile.is_empty():
        return "user://XPPrestige.cfg"
    return "user://XPPrestige_" + profile + ".cfg"

func _save_prestige():
    var cfg = ConfigFile.new()
    for sid in prestige_counts.keys():
        cfg.set_value("prestige", sid, prestige_counts[sid])
    cfg.save(_get_prestige_path())

func _load_prestige():
    prestige_counts.clear()
    var cfg = ConfigFile.new()
    if cfg.load(_get_prestige_path()) != OK:
        return
    if cfg.has_section("prestige"):
        for key in cfg.get_section_keys("prestige"):
            prestige_counts[key] = int(cfg.get_value("prestige", key, 0))

# --- MCM Integration ---

func _try_load_mcm():
    if ResourceLoader.exists("res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres"):
        return load("res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres")
    return null

func _register_mcm():
    var _config = ConfigFile.new()

    var skill_names_display = ["Vitality", "Endurance", "Pack Mule", "Hunger Resist", "Thirst Resist", "Iron Will", "Regeneration", "Cold Resistance", "Stealth", "Recoil Control", "Athleticism", "Scavenger", "Composure"]
    var menu_pos = 1
    for i in skill_ids.size():
        _config.set_value("Bool", "cfg_skill_" + skill_ids[i], {
            "name" = "Enable " + skill_names_display[i],
            "tooltip" = "Show " + skill_names_display[i] + " in the Skills menu",
            "default" = true, "value" = true,
            "menu_pos" = menu_pos
        })
        menu_pos += 1

    _config.set_value("Float", "cfg_xp_container", {
        "name" = "Container Search XP",
        "tooltip" = "XP earned per container (fractional values supported — e.g. 0.3 awards 1 XP per ~4 containers searched)",
        "default" = 1.0, "value" = 1.0,
        "minRange" = 0.0, "maxRange" = 5.0, "step" = 0.1,
        "menu_pos" = 13
    })
    _config.set_value("Int", "cfg_xp_kill", {
        "name" = "Enemy Kill XP",
        "tooltip" = "XP earned per enemy kill",
        "default" = 25, "value" = 25,
        "minRange" = 0, "maxRange" = 200,
        "menu_pos" = 14
    })
    _config.set_value("Int", "cfg_xp_boss", {
        "name" = "Boss Kill XP",
        "tooltip" = "XP earned per boss kill",
        "default" = 100, "value" = 100,
        "minRange" = 0, "maxRange" = 500,
        "menu_pos" = 15
    })
    _config.set_value("Int", "cfg_xp_trade", {
        "name" = "Trade XP",
        "tooltip" = "XP earned when completing a trade",
        "default" = 10, "value" = 10,
        "minRange" = 0, "maxRange" = 100,
        "menu_pos" = 16
    })
    _config.set_value("Int", "cfg_xp_task", {
        "name" = "Task Complete XP",
        "tooltip" = "XP earned when completing a task",
        "default" = 50, "value" = 50,
        "minRange" = 0, "maxRange" = 500,
        "menu_pos" = 17
    })
    _config.set_value("Bool", "cfg_death_resets", {
        "name" = "Death Resets XP",
        "tooltip" = "Reset all XP and skill levels on death",
        "default" = true, "value" = true,
        "menu_pos" = 18
    })
    _config.set_value("Int", "cfg_hp_per_level", {
        "name" = "HP Per Level",
        "tooltip" = "Max HP bonus per Vitality level",
        "default" = 5, "value" = 5,
        "minRange" = 1, "maxRange" = 25,
        "menu_pos" = 19
    })
    _config.set_value("Int", "cfg_stamina_reduce", {
        "name" = "Stamina Drain Reduce (%)",
        "tooltip" = "Stamina drain reduction per Endurance level (10 = 10% per level)",
        "default" = 10, "value" = 10,
        "minRange" = 1, "maxRange" = 20,
        "menu_pos" = 20
    })
    _config.set_value("Int", "cfg_carry_per_level", {
        "name" = "Carry Weight Per Level (kg)",
        "tooltip" = "Extra carry weight (kg) per Pack Mule level",
        "default" = 2, "value" = 2,
        "minRange" = 1, "maxRange" = 10,
        "menu_pos" = 21
    })
    _config.set_value("Int", "cfg_hunger_reduce", {
        "name" = "Hunger Drain Reduce (%)",
        "tooltip" = "Hunger drain reduction per Hunger Resist level (8 = 8% per level)",
        "default" = 8, "value" = 8,
        "minRange" = 1, "maxRange" = 20,
        "menu_pos" = 22
    })
    _config.set_value("Int", "cfg_thirst_reduce", {
        "name" = "Thirst Drain Reduce (%)",
        "tooltip" = "Thirst drain reduction per Thirst Resist level (8 = 8% per level)",
        "default" = 8, "value" = 8,
        "minRange" = 1, "maxRange" = 20,
        "menu_pos" = 23
    })
    _config.set_value("Int", "cfg_mental_reduce", {
        "name" = "Mental Drain Reduce (%)",
        "tooltip" = "Mental drain reduction per Iron Will level (8 = 8% per level)",
        "default" = 8, "value" = 8,
        "minRange" = 1, "maxRange" = 20,
        "menu_pos" = 24
    })
    _config.set_value("Float", "cfg_regen_per_level", {
        "name" = "Regen HP/s per Level",
        "tooltip" = "Passive HP regen per Regeneration skill level. Granular (0.01 steps) so you can tune it to taste. Default 0.02 means fully maxed Regen (skill 5) = 0.10 HP/s — about 17 minutes to heal from 0 to 100. Set to 0 to disable regen entirely.",
        "default" = 0.02, "value" = 0.02,
        "minRange" = 0.0, "maxRange" = 2.0, "step" = 0.01,
        "menu_pos" = 25
    })
    _config.set_value("Int", "cfg_coldres_reduce", {
        "name" = "Cold Resist Reduce (%)",
        "tooltip" = "Temperature loss reduction per Cold Resistance level (8 = 8% per level)",
        "default" = 8, "value" = 8,
        "minRange" = 1, "maxRange" = 20,
        "menu_pos" = 26
    })
    _config.set_value("Int", "cfg_stealth_reduce", {
        "name" = "Stealth Hearing Reduce (%)",
        "tooltip" = "AI hearing range reduction per Stealth level (5 = 5% per level)",
        "default" = 5, "value" = 5,
        "minRange" = 1, "maxRange" = 15,
        "menu_pos" = 27
    })
    _config.set_value("Int", "cfg_recoil_reduce", {
        "name" = "Recoil Reduce Per Level (%)",
        "tooltip" = "Weapon recoil reduction per Recoil Control level (5 = 5% per level)",
        "default" = 5, "value" = 5,
        "minRange" = 1, "maxRange" = 15,
        "menu_pos" = 28
    })
    _config.set_value("Int", "cfg_speed_bonus", {
        "name" = "Speed Bonus Per Level (%)",
        "tooltip" = "Movement speed increase per Athleticism level (4 = 4% per level)",
        "default" = 4, "value" = 4,
        "minRange" = 1, "maxRange" = 10,
        "menu_pos" = 29
    })
    _config.set_value("Int", "cfg_scavenger_chance", {
        "name" = "Scavenger Chance Per Level (%)",
        "tooltip" = "Chance to find extra loot per Scavenger level (5 = 5% per level)",
        "default" = 5, "value" = 5,
        "minRange" = 1, "maxRange" = 15,
        "menu_pos" = 30
    })
    _config.set_value("Int", "cfg_shake_reduce", {
        "name" = "Composure Shake Reduce Per Level (%)",
        "tooltip" = "Camera shake reduction when taking damage per Composure level (10 = 10% per level). Fully maxed at 5 levels reduces hit shake by 50%.",
        "default" = 10, "value" = 10,
        "minRange" = 1, "maxRange" = 20,
        "menu_pos" = 30.5
    })

    # ─── Prestige ───
    _config.set_value("Bool", "cfg_prestige_enabled", {
        "name" = "Enable Prestige",
        "tooltip" = "When ON, a 'Prestige' button appears at the bottom of the Skills panel once every enabled skill is maxed. Clicking it lets you wipe all XP and skill levels in exchange for a permanent bonus to one chosen stat.",
        "default" = true, "value" = true,
        "menu_pos" = 31
    })
    _config.set_value("Bool", "cfg_prestige_reset_on_death", {
        "name" = "Reset Prestige on Death",
        "tooltip" = "Hardcore option: when ON, dying wipes your prestige ranks along with your XP and skill levels. Default OFF (prestige is permanent).",
        "default" = false, "value" = false,
        "menu_pos" = 32
    })
    _config.set_value("Int", "cfg_prestige_hp", {
        "name" = "Prestige Max HP per Rank",
        "tooltip" = "Permanent max HP gained per Vitality prestige rank.",
        "default" = 3, "value" = 3,
        "minRange" = 0, "maxRange" = 20,
        "menu_pos" = 33
    })
    _config.set_value("Int", "cfg_prestige_stamina", {
        "name" = "Prestige Stamina Reduce per Rank (%)",
        "tooltip" = "Permanent stamina drain reduction per Endurance prestige rank.",
        "default" = 3, "value" = 3,
        "minRange" = 0, "maxRange" = 10,
        "menu_pos" = 34
    })
    _config.set_value("Int", "cfg_prestige_carry", {
        "name" = "Prestige Carry Weight per Rank (kg)",
        "tooltip" = "Permanent carry weight bonus per Pack Mule prestige rank.",
        "default" = 1, "value" = 1,
        "minRange" = 0, "maxRange" = 10,
        "menu_pos" = 35
    })
    _config.set_value("Int", "cfg_prestige_hunger", {
        "name" = "Prestige Hunger Reduce per Rank (%)",
        "tooltip" = "Permanent hunger drain reduction per Hunger Resist prestige rank.",
        "default" = 2, "value" = 2,
        "minRange" = 0, "maxRange" = 10,
        "menu_pos" = 36
    })
    _config.set_value("Int", "cfg_prestige_thirst", {
        "name" = "Prestige Thirst Reduce per Rank (%)",
        "tooltip" = "Permanent thirst drain reduction per Thirst Resist prestige rank.",
        "default" = 2, "value" = 2,
        "minRange" = 0, "maxRange" = 10,
        "menu_pos" = 37
    })
    _config.set_value("Int", "cfg_prestige_mental", {
        "name" = "Prestige Mental Reduce per Rank (%)",
        "tooltip" = "Permanent mental drain reduction per Iron Will prestige rank.",
        "default" = 2, "value" = 2,
        "minRange" = 0, "maxRange" = 10,
        "menu_pos" = 38
    })
    _config.set_value("Float", "cfg_prestige_regen", {
        "name" = "Prestige Regen HP/s per Rank",
        "tooltip" = "Permanent passive HP regen per Regeneration prestige rank. Stacks additively on top of the skill tree. Default 0.005 means one prestige rank ≈ 25% of a skill level at the default base regen rate, matching the other prestige stats.",
        "default" = 0.005, "value" = 0.005,
        "minRange" = 0.0, "maxRange" = 0.1, "step" = 0.001,
        "menu_pos" = 39
    })
    _config.set_value("Int", "cfg_prestige_coldres", {
        "name" = "Prestige Cold Resist per Rank (%)",
        "tooltip" = "Permanent cold drain reduction per Cold Resistance prestige rank.",
        "default" = 2, "value" = 2,
        "minRange" = 0, "maxRange" = 10,
        "menu_pos" = 40
    })
    _config.set_value("Int", "cfg_prestige_stealth", {
        "name" = "Prestige Stealth per Rank (%)",
        "tooltip" = "Permanent AI hearing reduction per Stealth prestige rank. Note: Stealth is currently a no-op since v2.0 dropped the AI.gd override.",
        "default" = 2, "value" = 2,
        "minRange" = 0, "maxRange" = 10,
        "menu_pos" = 41
    })
    _config.set_value("Int", "cfg_prestige_recoil", {
        "name" = "Prestige Recoil Reduce per Rank (%)",
        "tooltip" = "Permanent weapon recoil reduction per Recoil Control prestige rank.",
        "default" = 2, "value" = 2,
        "minRange" = 0, "maxRange" = 10,
        "menu_pos" = 42
    })
    _config.set_value("Int", "cfg_prestige_speed", {
        "name" = "Prestige Speed per Rank (%)",
        "tooltip" = "Permanent movement speed bonus per Athleticism prestige rank.",
        "default" = 1, "value" = 1,
        "minRange" = 0, "maxRange" = 5,
        "menu_pos" = 43
    })
    _config.set_value("Int", "cfg_prestige_scavenger", {
        "name" = "Prestige Scavenger per Rank (%)",
        "tooltip" = "Permanent extra loot chance per Scavenger prestige rank.",
        "default" = 2, "value" = 2,
        "minRange" = 0, "maxRange" = 10,
        "menu_pos" = 44
    })
    _config.set_value("Int", "cfg_prestige_composure", {
        "name" = "Prestige Composure per Rank (%)",
        "tooltip" = "Permanent camera shake reduction per Composure prestige rank.",
        "default" = 2, "value" = 2,
        "minRange" = 0, "maxRange" = 10,
        "menu_pos" = 44.5
    })
    _config.set_value("Int", "cfg_prestige_cap", {
        "name" = "Prestige Rank Cap (non-Vitality)",
        "tooltip" = "Maximum prestige ranks any non-Vitality skill can accumulate. Vitality (Max HP) is always uncapped.",
        "default" = 10, "value" = 10,
        "minRange" = 1, "maxRange" = 50,
        "menu_pos" = 45
    })

    if !FileAccess.file_exists(MCM_FILE_PATH + "/config.ini"):
        DirAccess.open("user://").make_dir_recursive(MCM_FILE_PATH)
        _config.save(MCM_FILE_PATH + "/config.ini")
    else:
        # Migrate: cfg_regen_per_level (v2.2.3) and cfg_prestige_regen
        # (v2.2.4) both switched from Int sliders to granular Float sliders
        # and lowered their defaults. Strip the stale Int entries so MCM
        # doesn't keep the old values and overwrite our new defaults on
        # next save.
        var _saved = ConfigFile.new()
        if _saved.load(MCM_FILE_PATH + "/config.ini") == OK:
            var changed := false
            for stale_key in ["cfg_regen_per_level", "cfg_prestige_regen"]:
                if _saved.has_section_key("Int", stale_key):
                    _saved.erase_section_key("Int", stale_key)
                    changed = true
            if changed:
                _saved.save(MCM_FILE_PATH + "/config.ini")
        _mcm_helpers.CheckConfigurationHasUpdated(MCM_MOD_ID, _config, MCM_FILE_PATH + "/config.ini")
        _config.load(MCM_FILE_PATH + "/config.ini")

    _apply_mcm_config(_config)

    _mcm_helpers.RegisterConfiguration(
        MCM_MOD_ID,
        "XP & Skills System",
        MCM_FILE_PATH,
        "Configure XP rewards, skill bonuses, and gameplay settings",
        {"config.ini" = _on_mcm_save}
    )

func _on_mcm_save(config: ConfigFile):
    _apply_mcm_config(config)
    var ui = Engine.get_meta("XPInterface", null)
    if ui:
        ui.RebuildSkills()

func _mcm_val(config: ConfigFile, section: String, key: String, fallback):
    var entry = config.get_value(section, key, null)
    if entry == null or not entry is Dictionary:
        return fallback
    return entry.get("value", fallback)

func _apply_mcm_config(config: ConfigFile):
    for sid in skill_ids:
        var key = "cfg_skill_" + sid
        if config.has_section_key("Bool", key):
            cfg_skill_enabled[sid] = _mcm_val(config, "Bool", key, cfg_skill_enabled.get(sid, true))
    cfg_xp_container = float(_mcm_val(config, "Float", "cfg_xp_container", cfg_xp_container))
    cfg_xp_kill = _mcm_val(config, "Int", "cfg_xp_kill", cfg_xp_kill)
    cfg_xp_boss = _mcm_val(config, "Int", "cfg_xp_boss", cfg_xp_boss)
    cfg_xp_trade = _mcm_val(config, "Int", "cfg_xp_trade", cfg_xp_trade)
    cfg_xp_task = _mcm_val(config, "Int", "cfg_xp_task", cfg_xp_task)
    cfg_death_resets = _mcm_val(config, "Bool", "cfg_death_resets", cfg_death_resets)
    cfg_hp_per_level = float(_mcm_val(config, "Int", "cfg_hp_per_level", 5))
    cfg_stamina_reduce = _mcm_val(config, "Int", "cfg_stamina_reduce", 10) / 100.0
    cfg_carry_per_level = float(_mcm_val(config, "Int", "cfg_carry_per_level", 2))
    cfg_hunger_reduce = _mcm_val(config, "Int", "cfg_hunger_reduce", 8) / 100.0
    cfg_thirst_reduce = _mcm_val(config, "Int", "cfg_thirst_reduce", 8) / 100.0
    cfg_mental_reduce = _mcm_val(config, "Int", "cfg_mental_reduce", 8) / 100.0
    cfg_regen_per_level = float(_mcm_val(config, "Float", "cfg_regen_per_level", cfg_regen_per_level))
    cfg_coldres_reduce = _mcm_val(config, "Int", "cfg_coldres_reduce", 8) / 100.0
    cfg_stealth_reduce = _mcm_val(config, "Int", "cfg_stealth_reduce", 5) / 100.0
    cfg_recoil_reduce = _mcm_val(config, "Int", "cfg_recoil_reduce", 5) / 100.0
    cfg_speed_bonus = _mcm_val(config, "Int", "cfg_speed_bonus", 4) / 100.0
    cfg_scavenger_chance = _mcm_val(config, "Int", "cfg_scavenger_chance", 5) / 100.0
    cfg_shake_reduce = _mcm_val(config, "Int", "cfg_shake_reduce", 10) / 100.0
    # Prestige
    cfg_prestige_enabled = _mcm_val(config, "Bool", "cfg_prestige_enabled", cfg_prestige_enabled)
    cfg_prestige_reset_on_death = _mcm_val(config, "Bool", "cfg_prestige_reset_on_death", cfg_prestige_reset_on_death)
    cfg_prestige_hp = float(_mcm_val(config, "Int", "cfg_prestige_hp", 3))
    cfg_prestige_stamina = _mcm_val(config, "Int", "cfg_prestige_stamina", 3) / 100.0
    cfg_prestige_carry = float(_mcm_val(config, "Int", "cfg_prestige_carry", 1))
    cfg_prestige_hunger = _mcm_val(config, "Int", "cfg_prestige_hunger", 2) / 100.0
    cfg_prestige_thirst = _mcm_val(config, "Int", "cfg_prestige_thirst", 2) / 100.0
    cfg_prestige_mental = _mcm_val(config, "Int", "cfg_prestige_mental", 2) / 100.0
    cfg_prestige_regen = float(_mcm_val(config, "Float", "cfg_prestige_regen", cfg_prestige_regen))
    cfg_prestige_coldres = _mcm_val(config, "Int", "cfg_prestige_coldres", 2) / 100.0
    cfg_prestige_stealth = _mcm_val(config, "Int", "cfg_prestige_stealth", 2) / 100.0
    cfg_prestige_recoil = _mcm_val(config, "Int", "cfg_prestige_recoil", 2) / 100.0
    cfg_prestige_speed = _mcm_val(config, "Int", "cfg_prestige_speed", 1) / 100.0
    cfg_prestige_scavenger = _mcm_val(config, "Int", "cfg_prestige_scavenger", 2) / 100.0
    cfg_prestige_composure = _mcm_val(config, "Int", "cfg_prestige_composure", 2) / 100.0
    # Rebuild caps array from the single non-Vitality cap slider. Vitality
    # stays uncapped (-1); every other slot uses the MCM value.
    var shared_cap = int(_mcm_val(config, "Int", "cfg_prestige_cap", 10))
    cfg_prestige_caps = [-1]
    for _i in range(skill_ids.size() - 1):
        cfg_prestige_caps.append(shared_cap)

# --- Fallback config (used when MCM is not installed) ---

func LoadConfig():
    var cfg = ConfigFile.new()
    if cfg.load("user://XPConfig.cfg") == OK:
        cfg_xp_container = float(cfg.get_value("xp_rewards", "container", 1.0))
        cfg_xp_kill = cfg.get_value("xp_rewards", "kill", 25)
        cfg_xp_boss = cfg.get_value("xp_rewards", "boss", 100)
        cfg_xp_trade = cfg.get_value("xp_rewards", "trade", 10)
        cfg_xp_task = cfg.get_value("xp_rewards", "task", 50)
        cfg_death_resets = cfg.get_value("gameplay", "death_resets_xp", true)
        cfg_hp_per_level = cfg.get_value("bonuses", "hp_per_level", 5.0)
        cfg_stamina_reduce = cfg.get_value("bonuses", "stamina_reduce", 0.10)
        cfg_carry_per_level = cfg.get_value("bonuses", "carry_per_level", 2.0)
        cfg_hunger_reduce = cfg.get_value("bonuses", "hunger_reduce", 0.08)
        cfg_thirst_reduce = cfg.get_value("bonuses", "thirst_reduce", 0.08)
        cfg_mental_reduce = cfg.get_value("bonuses", "mental_reduce", 0.08)
        cfg_regen_per_level = cfg.get_value("bonuses", "regen_per_level", 0.02)
        cfg_coldres_reduce = cfg.get_value("bonuses", "coldres_reduce", 0.08)
        cfg_stealth_reduce = cfg.get_value("bonuses", "stealth_reduce", 0.05)
        cfg_recoil_reduce = cfg.get_value("bonuses", "recoil_reduce", 0.05)
        cfg_speed_bonus = cfg.get_value("bonuses", "speed_bonus", 0.04)
        cfg_scavenger_chance = cfg.get_value("bonuses", "scavenger_chance", 0.05)
        cfg_shake_reduce = cfg.get_value("bonuses", "shake_reduce", 0.10)
        for sid in skill_ids:
            cfg_skill_enabled[sid] = cfg.get_value("toggles", sid, true)
        var ml = cfg.get_value("skills", "max_levels", "10,10,10,10,10,10,5,10,10,10,5,5,5")
        var cb = cfg.get_value("skills", "cost_bases", "25,25,20,20,20,20,50,20,25,25,30,30,25")
        cfg_max_levels = _parse_int_list(ml, [10, 10, 10, 10, 10, 10, 5, 10, 10, 10, 5, 5, 5])
        cfg_cost_bases = _parse_int_list(cb, [25, 25, 20, 20, 20, 20, 50, 20, 25, 25, 30, 30, 25])
    else:
        SaveConfig()

func SaveConfig():
    var cfg = ConfigFile.new()
    cfg.set_value("xp_rewards", "container", cfg_xp_container)
    cfg.set_value("xp_rewards", "kill", cfg_xp_kill)
    cfg.set_value("xp_rewards", "boss", cfg_xp_boss)
    cfg.set_value("xp_rewards", "trade", cfg_xp_trade)
    cfg.set_value("xp_rewards", "task", cfg_xp_task)
    cfg.set_value("gameplay", "death_resets_xp", cfg_death_resets)
    cfg.set_value("bonuses", "hp_per_level", cfg_hp_per_level)
    cfg.set_value("bonuses", "stamina_reduce", cfg_stamina_reduce)
    cfg.set_value("bonuses", "carry_per_level", cfg_carry_per_level)
    cfg.set_value("bonuses", "hunger_reduce", cfg_hunger_reduce)
    cfg.set_value("bonuses", "thirst_reduce", cfg_thirst_reduce)
    cfg.set_value("bonuses", "mental_reduce", cfg_mental_reduce)
    cfg.set_value("bonuses", "regen_per_level", cfg_regen_per_level)
    cfg.set_value("bonuses", "coldres_reduce", cfg_coldres_reduce)
    cfg.set_value("bonuses", "stealth_reduce", cfg_stealth_reduce)
    cfg.set_value("bonuses", "recoil_reduce", cfg_recoil_reduce)
    cfg.set_value("bonuses", "speed_bonus", cfg_speed_bonus)
    cfg.set_value("bonuses", "scavenger_chance", cfg_scavenger_chance)
    cfg.set_value("bonuses", "shake_reduce", cfg_shake_reduce)
    for sid in skill_ids:
        cfg.set_value("toggles", sid, cfg_skill_enabled[sid])
    var ml = ",".join(cfg_max_levels.map(func(v): return str(v)))
    var cb = ",".join(cfg_cost_bases.map(func(v): return str(v)))
    cfg.set_value("skills", "max_levels", ml)
    cfg.set_value("skills", "cost_bases", cb)
    cfg.save("user://XPConfig.cfg")

func _parse_int_list(s, fallback: Array) -> Array:
    if s is Array: return s
    var parts = str(s).split(",")
    var result = []
    for p in parts:
        result.append(int(p.strip_edges()))
    if result.size() != fallback.size(): return fallback
    return result

func SaveXP():
    var path = _get_xp_data_path()
    var cfg = ConfigFile.new()
    cfg.set_value("xp", "xp", xp)
    cfg.set_value("xp", "xpTotal", xpTotal)
    cfg.set_value("xp", "xpHealth", xpHealth)
    cfg.set_value("xp", "xpStamina", xpStamina)
    cfg.set_value("xp", "xpCarry", xpCarry)
    cfg.set_value("xp", "xpHunger", xpHunger)
    cfg.set_value("xp", "xpThirst", xpThirst)
    cfg.set_value("xp", "xpMental", xpMental)
    cfg.set_value("xp", "xpRegen", xpRegen)
    cfg.set_value("xp", "xpColdRes", xpColdRes)
    cfg.set_value("xp", "xpStealth", xpStealth)
    cfg.set_value("xp", "xpRecoil", xpRecoil)
    cfg.set_value("xp", "xpSpeed", xpSpeed)
    cfg.set_value("xp", "xpScavenger", xpScavenger)
    cfg.set_value("xp", "xpComposure", xpComposure)
    cfg.set_value("xp", "container_fraction", _container_xp_fraction)
    for trader_name in cfg_trader_task_counts.keys():
        cfg.set_value("trader_task_counts", trader_name, cfg_trader_task_counts[trader_name])
    cfg.save(path)
    _sync_to_gamedata()
    _ensure_marker()

func _sync_to_gamedata():
    # Mirror our skill levels to the game's built-in XP fields so that even if
    # another mod overrides Character.gd / Interface.gd (stomping our override),
    # the base game code still picks up the correct values for HP cap, stamina,
    # carry weight, hunger, thirst, mental, and regen.
    gameData.xp = xp
    gameData.xpTotal = xpTotal
    gameData.xpHealth = get_level(0)
    gameData.xpStamina = get_level(1)
    gameData.xpCarry = get_level(2)
    gameData.xpHunger = get_level(3)
    gameData.xpThirst = get_level(4)
    gameData.xpMental = get_level(5)
    gameData.xpRegen = get_level(6)

func LoadXP():
    var path = _get_xp_data_path()
    # First-time Patty Profiles migration: if the profile-specific file
    # doesn't exist yet but a legacy user://XPData.cfg does, pull it forward
    # so existing progression isn't lost. Delete the legacy afterwards so
    # subsequent new profiles start clean instead of inheriting the first
    # profile's data on every LoadXP.
    if path != "user://XPData.cfg" and !FileAccess.file_exists(path) and FileAccess.file_exists("user://XPData.cfg"):
        _copy_file_bytes("user://XPData.cfg", path)
        DirAccess.remove_absolute(ProjectSettings.globalize_path("user://XPData.cfg"))
    # Zero in-memory state before loading so switching to a profile with no
    # saved file leaves us cleanly at zero instead of carrying the previous
    # profile's XP/skill levels.
    _zero_xp_state()
    var cfg = ConfigFile.new()
    if cfg.load(path) == OK:
        xp = cfg.get_value("xp", "xp", 0)
        xpTotal = cfg.get_value("xp", "xpTotal", 0)
        xpHealth = cfg.get_value("xp", "xpHealth", 0)
        xpStamina = cfg.get_value("xp", "xpStamina", 0)
        xpCarry = cfg.get_value("xp", "xpCarry", 0)
        xpHunger = cfg.get_value("xp", "xpHunger", 0)
        xpThirst = cfg.get_value("xp", "xpThirst", 0)
        xpMental = cfg.get_value("xp", "xpMental", 0)
        xpRegen = cfg.get_value("xp", "xpRegen", 0)
        xpColdRes = cfg.get_value("xp", "xpColdRes", 0)
        xpStealth = cfg.get_value("xp", "xpStealth", 0)
        xpRecoil = cfg.get_value("xp", "xpRecoil", 0)
        xpSpeed = cfg.get_value("xp", "xpSpeed", 0)
        xpScavenger = cfg.get_value("xp", "xpScavenger", 0)
        xpComposure = cfg.get_value("xp", "xpComposure", 0)
        _container_xp_fraction = float(cfg.get_value("xp", "container_fraction", 0.0))
        if cfg.has_section("trader_task_counts"):
            for trader_name in cfg.get_section_keys("trader_task_counts"):
                cfg_trader_task_counts[trader_name] = cfg.get_value("trader_task_counts", trader_name, 0)
    _last_xp_path = path
    # Prestige lives in its own file so it survives ResetXP. Load it here
    # so the active profile's prestige ranks are in memory for Character.gd
    # and the UI to read.
    _load_prestige()
    _sync_to_gamedata()

func _zero_xp_state():
    xp = 0
    xpTotal = 0
    xpHealth = 0
    xpStamina = 0
    xpCarry = 0
    xpHunger = 0
    xpThirst = 0
    xpMental = 0
    xpRegen = 0
    xpColdRes = 0
    xpStealth = 0
    xpRecoil = 0
    xpSpeed = 0
    xpScavenger = 0
    xpComposure = 0
    _container_xp_fraction = 0.0
    cfg_trader_task_counts.clear()

func ResetXP():
    _zero_xp_state()
    var path = _get_xp_data_path()
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    # Prestige normally survives death. The MCM hardcore toggle opts in to
    # also wiping prestige on every death reset.
    if cfg_prestige_reset_on_death:
        prestige_counts.clear()
        var pp = _get_prestige_path()
        if FileAccess.file_exists(pp):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(pp))
    _sync_to_gamedata()

func _ensure_marker():
    if !FileAccess.file_exists("user://XPSkillsMarker.tres"):
        var marker = Resource.new()
        ResourceSaver.save(marker, "user://XPSkillsMarker.tres")
