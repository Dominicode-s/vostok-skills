extends Node

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
    overrideScript("res://mods/XPSkillsSystem/Character.gd")
    overrideScript("res://mods/XPSkillsSystem/Interface.gd")
    overrideScript("res://mods/XPSkillsSystem/LootContainer.gd")
    overrideScript("res://mods/XPSkillsSystem/AI.gd")
    overrideScript("res://mods/XPSkillsSystem/Trader.gd")
    overrideScript("res://mods/XPSkillsSystem/Recoil.gd")
    overrideScript("res://mods/XPSkillsSystem/Controller.gd")

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

func is_skill_enabled(index: int) -> bool:
    if index < 0 or index >= skill_ids.size():
        return false
    return cfg_skill_enabled.get(skill_ids[index], true)

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
    _config.set_value("Float", "cfg_hp_per_level", {
        "name" = "HP Per Level",
        "tooltip" = "Max HP bonus per Vitality level",
        "default" = 5.0, "value" = 5.0,
        "minRange" = 1.0, "maxRange" = 25.0,
        "menu_pos" = 19
    })
    _config.set_value("Float", "cfg_stamina_reduce", {
        "name" = "Stamina Drain Reduce",
        "tooltip" = "Stamina drain reduction per Endurance level (fraction, e.g. 0.10 = 10%)",
        "default" = 0.10, "value" = 0.10,
        "minRange" = 0.01, "maxRange" = 0.20,
        "menu_pos" = 20
    })
    _config.set_value("Float", "cfg_carry_per_level", {
        "name" = "Carry Weight Per Level",
        "tooltip" = "Extra carry weight (kg) per Pack Mule level",
        "default" = 2.0, "value" = 2.0,
        "minRange" = 0.5, "maxRange" = 10.0,
        "menu_pos" = 21
    })
    _config.set_value("Float", "cfg_hunger_reduce", {
        "name" = "Hunger Drain Reduce",
        "tooltip" = "Hunger drain reduction per Hunger Resist level (fraction)",
        "default" = 0.08, "value" = 0.08,
        "minRange" = 0.01, "maxRange" = 0.20,
        "menu_pos" = 22
    })
    _config.set_value("Float", "cfg_thirst_reduce", {
        "name" = "Thirst Drain Reduce",
        "tooltip" = "Thirst drain reduction per Thirst Resist level (fraction)",
        "default" = 0.08, "value" = 0.08,
        "minRange" = 0.01, "maxRange" = 0.20,
        "menu_pos" = 23
    })
    _config.set_value("Float", "cfg_mental_reduce", {
        "name" = "Mental Drain Reduce",
        "tooltip" = "Mental drain reduction per Iron Will level (fraction)",
        "default" = 0.08, "value" = 0.08,
        "minRange" = 0.01, "maxRange" = 0.20,
        "menu_pos" = 24
    })
    _config.set_value("Float", "cfg_regen_per_level", {
        "name" = "Regen Per Level",
        "tooltip" = "HP/sec passive regeneration per Regeneration level",
        "default" = 0.2, "value" = 0.2,
        "minRange" = 0.1, "maxRange" = 2.0,
        "menu_pos" = 25
    })
    _config.set_value("Float", "cfg_coldres_reduce", {
        "name" = "Cold Resist Reduce",
        "tooltip" = "Temperature loss reduction per Cold Resistance level (fraction, e.g. 0.08 = 8%)",
        "default" = 0.08, "value" = 0.08,
        "minRange" = 0.01, "maxRange" = 0.20,
        "menu_pos" = 26
    })
    _config.set_value("Float", "cfg_stealth_reduce", {
        "name" = "Stealth Hearing Reduce",
        "tooltip" = "AI hearing range reduction per Stealth level (fraction, e.g. 0.05 = 5%)",
        "default" = 0.05, "value" = 0.05,
        "minRange" = 0.01, "maxRange" = 0.15,
        "menu_pos" = 27
    })
    _config.set_value("Float", "cfg_recoil_reduce", {
        "name" = "Recoil Reduce Per Level",
        "tooltip" = "Weapon recoil reduction per Recoil Control level (fraction, e.g. 0.05 = 5%)",
        "default" = 0.05, "value" = 0.05,
        "minRange" = 0.01, "maxRange" = 0.15,
        "menu_pos" = 28
    })
    _config.set_value("Float", "cfg_speed_bonus", {
        "name" = "Speed Bonus Per Level",
        "tooltip" = "Movement speed increase per Athleticism level (fraction, e.g. 0.04 = 4%)",
        "default" = 0.04, "value" = 0.04,
        "minRange" = 0.01, "maxRange" = 0.10,
        "menu_pos" = 29
    })
    _config.set_value("Float", "cfg_scavenger_chance", {
        "name" = "Scavenger Chance Per Level",
        "tooltip" = "Chance to find extra loot per Scavenger level (fraction, e.g. 0.05 = 5%)",
        "default" = 0.05, "value" = 0.05,
        "minRange" = 0.01, "maxRange" = 0.15,
        "menu_pos" = 30
    })

    if !FileAccess.file_exists(MCM_FILE_PATH + "/config.ini"):
        DirAccess.open("user://").make_dir(MCM_FILE_PATH)
        _config.save(MCM_FILE_PATH + "/config.ini")
    else:
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
    cfg_hp_per_level = _mcm_val(config, "Float", "cfg_hp_per_level", cfg_hp_per_level)
    cfg_stamina_reduce = _mcm_val(config, "Float", "cfg_stamina_reduce", cfg_stamina_reduce)
    cfg_carry_per_level = _mcm_val(config, "Float", "cfg_carry_per_level", cfg_carry_per_level)
    cfg_hunger_reduce = _mcm_val(config, "Float", "cfg_hunger_reduce", cfg_hunger_reduce)
    cfg_thirst_reduce = _mcm_val(config, "Float", "cfg_thirst_reduce", cfg_thirst_reduce)
    cfg_mental_reduce = _mcm_val(config, "Float", "cfg_mental_reduce", cfg_mental_reduce)
    cfg_regen_per_level = _mcm_val(config, "Float", "cfg_regen_per_level", cfg_regen_per_level)
    cfg_coldres_reduce = _mcm_val(config, "Float", "cfg_coldres_reduce", cfg_coldres_reduce)
    cfg_stealth_reduce = _mcm_val(config, "Float", "cfg_stealth_reduce", cfg_stealth_reduce)
    cfg_recoil_reduce = _mcm_val(config, "Float", "cfg_recoil_reduce", cfg_recoil_reduce)
    cfg_speed_bonus = _mcm_val(config, "Float", "cfg_speed_bonus", cfg_speed_bonus)
    cfg_scavenger_chance = _mcm_val(config, "Float", "cfg_scavenger_chance", cfg_scavenger_chance)

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
