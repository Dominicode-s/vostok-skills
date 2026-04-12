extends Node

var gameData = preload("res://Resources/GameData.tres")

# New-game detection — marker file is wiped by FormatSave() on new game
var _prev_menu: bool = false

# Kill Attribution
const GRENADE_WINDOW_MS: int = 6000
const FIRE_WINDOW_MS: int = 500
var last_grenade_time: int = 0
var _last_fire_time: int = 0
var _prev_grenade1: bool = false
var _prev_grenade2: bool = false

# Compat — AI death polling for kill XP (no AI.gd override needed)
var _tracked_ai: Array = []

# Compat — Container tracking for search XP (no LootContainer.gd override)
var _awarded_containers: Dictionary = {}
var _prev_interface: bool = false

# Compat — Trade tracking (no Interface.gd trade hook needed)
var _trade_btn: Button = null
var _trade_connected: bool = false

# Compat — Task tracking (no Trader.gd override needed)
var _tracked_traders: Array = []

# Compat — Speed bonus (no Controller.gd override needed)
var _controller_ref = null
const BASE_WALK_SPEED: float = 2.5
const BASE_SPRINT_SPEED: float = 5.0

# Scavenger SFX
var _sfx_search: AudioStreamMP3
var _sfx_door: AudioStreamMP3

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

# Config — XP rewards
var cfg_xp_container: int = 1
var cfg_xp_kill: int = 25
var cfg_xp_boss: int = 100
var cfg_xp_trade: int = 10
var cfg_xp_task: int = 50

# Config — Death behavior
var cfg_death_resets: bool = true

# Config — Skill bonuses per level
var cfg_hp_per_level: float = 5.0
var cfg_stamina_reduce: float = 0.10
var cfg_carry_per_level: float = 2.0
var cfg_hunger_reduce: float = 0.08
var cfg_thirst_reduce: float = 0.08
var cfg_mental_reduce: float = 0.08
var cfg_regen_per_level: float = 0.2
var cfg_coldres_reduce: float = 0.08
var cfg_stealth_reduce: float = 0.05
var cfg_recoil_reduce: float = 0.05
var cfg_speed_bonus: float = 0.04
var cfg_scavenger_chance: float = 0.05

# Config — Skill max levels
var cfg_max_levels: Array = [10, 10, 10, 10, 10, 10, 5, 10, 10, 10, 5, 5]

# Config — Skill cost bases
var cfg_cost_bases: Array = [25, 25, 20, 20, 20, 20, 50, 20, 25, 25, 30, 30]

# Config — Skill enabled toggles (index matches skill order)
var skill_ids: Array = ["vitality", "endurance", "pack_mule", "hunger_resist", "thirst_resist", "iron_will", "regeneration", "cold_resistance", "stealth", "recoil_control", "athleticism", "scavenger"]
var cfg_skill_enabled: Dictionary = {
	"vitality": true, "endurance": true, "pack_mule": true,
	"hunger_resist": true, "thirst_resist": true, "iron_will": true,
	"regeneration": true, "cold_resistance": true, "stealth": true,
	"recoil_control": true, "athleticism": true, "scavenger": true
}

# MCM integration
var _mcm_helpers = null
const MCM_FILE_PATH = "user://MCM/XPSkillsSystem"
const MCM_MOD_ID = "XPSkillsSystem"

func _ready():
    Engine.set_meta("XPMain", self)
    _mcm_helpers = _try_load_mcm()
    if _mcm_helpers:
        _register_mcm()
    else:
        LoadConfig()
    LoadXP()
    # Only Interface.gd and Character.gd overrides are kept.
    # Interface.gd: Skills UI tab, carry weight, button integration.
    # Character.gd: Health bonus (max HP), regen, vitals drain reduction, death reset.
    # All other overrides replaced with compat polling in _process().
    overrideScript("res://mods/XPSkillsSystem/Interface.gd")
    overrideScript("res://mods/XPSkillsSystem/Character.gd")
    get_tree().node_added.connect(_on_node_added)

func _process(delta):
    # Detect menu→game transition to check for new game
    if _prev_menu and !gameData.menu:
        if !FileAccess.file_exists("user://XPSkillsMarker.tres"):
            ResetXP()
            print("[XP Skills] New game detected — XP reset")
        _ensure_marker()
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

    # Cold resistance — compensate base game temperature drain
    _apply_cold_resistance(delta)

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

    # AI tracking for kill XP
    if "dead" in node and "boss" in node and node.has_method("Death"):
        if node not in _tracked_ai:
            _tracked_ai.append(node)
        return

    # Trader tracking for task XP
    if "tasksCompleted" in node and "traderData" in node:
        _tracked_traders.append({"ref": weakref(node), "count": node.tasksCompleted.size()})
        return

func _apply_recoil_reduction(node: Node):
    if !is_instance_valid(node) or !"data" in node or !node.data:
        return
    var level = get_level(9)
    if level <= 0:
        return
    var mult = maxf(1.0 - (level * cfg_recoil_reduce), 0.05)
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
    var still_alive: Array = []
    for ai in _tracked_ai:
        if !is_instance_valid(ai):
            continue
        if ai.dead:
            if is_player_kill():
                var xpReward = cfg_xp_boss if ai.boss else cfg_xp_kill
                xp += xpReward
                xpTotal += xpReward
                SaveXP()
        else:
            still_alive.append(ai)
    _tracked_ai = still_alive

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
    xp += cfg_xp_container
    xpTotal += cfg_xp_container
    SaveXP()
    # Scavenger skill — bonus loot from containers
    if get_level(11) > 0:
        get_tree().create_timer(0.1).timeout.connect(_try_scavenge.bind(iface, ui))

func _try_scavenge(iface, ui_manager):
    var chance = get_level(11) * cfg_scavenger_chance
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
    var item_name = str(source_item.slotData.itemData.name) if source_item.slotData else "Item"
    var dupe_data = source_item.slotData.duplicate()
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
    for entry in _tracked_traders:
        var trader = entry.ref.get_ref()
        if !trader or !is_instance_valid(trader):
            continue
        var current_count = trader.tasksCompleted.size()
        if current_count > entry.count:
            var completed = current_count - entry.count
            xp += cfg_xp_task * completed
            xpTotal += cfg_xp_task * completed
            SaveXP()
            entry.count = current_count
        still_valid.append(entry)
    _tracked_traders = still_valid

# --- Compat: Speed bonus (replaces Controller.gd override) ---

func _apply_speed_bonus():
    var level = get_level(10)
    if level <= 0:
        return
    if _controller_ref and is_instance_valid(_controller_ref):
        var bonus = 1.0 + (level * cfg_speed_bonus)
        _controller_ref.sprintSpeed = BASE_SPRINT_SPEED * bonus
        _controller_ref.walkSpeed = BASE_WALK_SPEED * bonus
        return
    # Lazily find Controller node
    var ctrl = get_tree().current_scene.get_node_or_null("/root/Map/Core/Controller")
    if ctrl and "sprintSpeed" in ctrl and "walkSpeed" in ctrl:
        _controller_ref = ctrl
        var bonus = 1.0 + (level * cfg_speed_bonus)
        ctrl.sprintSpeed = BASE_SPRINT_SPEED * bonus
        ctrl.walkSpeed = BASE_WALK_SPEED * bonus

# --- Compat: Cold resistance (replaces Character.gd Temperature override) ---

func _apply_cold_resistance(delta):
    var level = get_level(7)
    if level <= 0:
        return
    # Base game doesn't have cold resistance — compensate by adding back
    # the portion of temperature drain that our skill should prevent.
    # Base drain: (delta * rate) * insulation. We add back: drain * (level * cfg_coldres_reduce)
    if "season" in gameData and gameData.season == 2 and !gameData.shelter and !gameData.heat:
        if "frostbite" in gameData and !gameData.frostbite:
            var character = get_tree().current_scene.get_node_or_null("/root/Map/Core/Controller/Character")
            var ins = character.insulation if character and "insulation" in character else 1.0
            var base_drain = 0.0
            if "isSubmerged" in gameData and gameData.isSubmerged:
                base_drain = (delta * 8.0) * ins
            elif "isWater" in gameData and gameData.isWater:
                base_drain = (delta * 4.0) * ins
            elif "indoor" in gameData and gameData.indoor:
                base_drain = (delta / 10.0) * ins
            else:
                base_drain = (delta / 5.0) * ins
            var reduction = base_drain * (level * cfg_coldres_reduce)
            gameData.temperature += reduction

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
    return 0

# --- MCM Integration ---

func _try_load_mcm():
    if ResourceLoader.exists("res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres"):
        return load("res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres")
    return null

func _register_mcm():
    var _config = ConfigFile.new()

    var skill_names_display = ["Vitality", "Endurance", "Pack Mule", "Hunger Resist", "Thirst Resist", "Iron Will", "Regeneration", "Cold Resistance", "Stealth", "Recoil Control", "Athleticism", "Scavenger"]
    var menu_pos = 1
    for i in skill_ids.size():
        _config.set_value("Bool", "cfg_skill_" + skill_ids[i], {
            "name" = "Enable " + skill_names_display[i],
            "tooltip" = "Show " + skill_names_display[i] + " in the Skills menu",
            "default" = true, "value" = true,
            "menu_pos" = menu_pos
        })
        menu_pos += 1

    _config.set_value("Int", "cfg_xp_container", {
        "name" = "Container Search XP",
        "tooltip" = "XP earned when searching containers",
        "default" = 1, "value" = 1,
        "minRange" = 0, "maxRange" = 50,
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
    _config.set_value("Int", "cfg_regen_per_level", {
        "name" = "Regen Per Level (×0.1 HP/s)",
        "tooltip" = "HP/sec passive regeneration per Regeneration level (2 = 0.2 HP/s per level)",
        "default" = 2, "value" = 2,
        "minRange" = 1, "maxRange" = 20,
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

    if !FileAccess.file_exists(MCM_FILE_PATH + "/config.ini"):
        DirAccess.open("user://").make_dir_recursive(MCM_FILE_PATH)
        _config.save(MCM_FILE_PATH + "/config.ini")
    else:
        # Migrate: remove stale Float section from older versions
        var _saved = ConfigFile.new()
        _saved.load(MCM_FILE_PATH + "/config.ini")
        if _saved.has_section("Float"):
            _saved.erase_section("Float")
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
    cfg_xp_container = _mcm_val(config, "Int", "cfg_xp_container", cfg_xp_container)
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
    cfg_regen_per_level = _mcm_val(config, "Int", "cfg_regen_per_level", 2) / 10.0
    cfg_coldres_reduce = _mcm_val(config, "Int", "cfg_coldres_reduce", 8) / 100.0
    cfg_stealth_reduce = _mcm_val(config, "Int", "cfg_stealth_reduce", 5) / 100.0
    cfg_recoil_reduce = _mcm_val(config, "Int", "cfg_recoil_reduce", 5) / 100.0
    cfg_speed_bonus = _mcm_val(config, "Int", "cfg_speed_bonus", 4) / 100.0
    cfg_scavenger_chance = _mcm_val(config, "Int", "cfg_scavenger_chance", 5) / 100.0

# --- Fallback config (used when MCM is not installed) ---

func LoadConfig():
    var cfg = ConfigFile.new()
    if cfg.load("user://XPConfig.cfg") == OK:
        cfg_xp_container = cfg.get_value("xp_rewards", "container", 1)
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
        cfg_regen_per_level = cfg.get_value("bonuses", "regen_per_level", 0.2)
        cfg_coldres_reduce = cfg.get_value("bonuses", "coldres_reduce", 0.08)
        cfg_stealth_reduce = cfg.get_value("bonuses", "stealth_reduce", 0.05)
        cfg_recoil_reduce = cfg.get_value("bonuses", "recoil_reduce", 0.05)
        cfg_speed_bonus = cfg.get_value("bonuses", "speed_bonus", 0.04)
        cfg_scavenger_chance = cfg.get_value("bonuses", "scavenger_chance", 0.05)
        for sid in skill_ids:
            cfg_skill_enabled[sid] = cfg.get_value("toggles", sid, true)
        var ml = cfg.get_value("skills", "max_levels", "10,10,10,10,10,10,5,10,10,10,5,5")
        var cb = cfg.get_value("skills", "cost_bases", "25,25,20,20,20,20,50,20,25,25,30,30")
        cfg_max_levels = _parse_int_list(ml, [10, 10, 10, 10, 10, 10, 5, 10, 10, 10, 5, 5])
        cfg_cost_bases = _parse_int_list(cb, [25, 25, 20, 20, 20, 20, 50, 20, 25, 25, 30, 30])
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
    cfg.save("user://XPData.cfg")
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
    var cfg = ConfigFile.new()
    if cfg.load("user://XPData.cfg") == OK:
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
    _sync_to_gamedata()

func ResetXP():
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
    if FileAccess.file_exists("user://XPData.cfg"):
        DirAccess.remove_absolute(ProjectSettings.globalize_path("user://XPData.cfg"))
    _sync_to_gamedata()

func _ensure_marker():
    if !FileAccess.file_exists("user://XPSkillsMarker.tres"):
        var marker = Resource.new()
        ResourceSaver.save(marker, "user://XPSkillsMarker.tres")
