extends "res://Scripts/Character.gd"

var xp_mod = null

func _ready():
    xp_mod = Engine.get_meta("XPMain", null)

func Health(delta):
    var saved_xp_regen = gameData.xpRegen
    gameData.xpRegen = 0
    super(delta)
    gameData.xpRegen = saved_xp_regen

    if xp_mod and !gameData.isDead and gameData.health > 0:
        var regen_rate = xp_mod.get_level(6) * xp_mod.cfg_regen_per_level + xp_mod.prestige_regen_bonus()
        if regen_rate > 0.0:
            var maxHP = 100.0 + xp_mod.get_level(0) * xp_mod.cfg_hp_per_level + xp_mod.prestige_hp_bonus()
            if gameData.health < maxHP:
                gameData.health += delta * regen_rate

func Energy(delta):
    if xp_mod == null or gameData.starvation:
        super(delta)
        return
    var bonus: float = xp_mod.get_level(3) * xp_mod.cfg_hunger_reduce + xp_mod.prestige_hunger_bonus()
    var before: float = gameData.energy
    super(delta)
    var drained: float = before - gameData.energy
    if drained > 0.0:
        gameData.energy = before - drained * (1.0 - bonus)

func Hydration(delta):
    if xp_mod == null or gameData.dehydration:
        super(delta)
        return
    var bonus: float = xp_mod.get_level(4) * xp_mod.cfg_thirst_reduce + xp_mod.prestige_thirst_bonus()
    var before: float = gameData.hydration
    super(delta)
    var drained: float = before - gameData.hydration
    if drained > 0.0:
        gameData.hydration = before - drained * (1.0 - bonus)

func Mental(delta):
    if xp_mod == null or gameData.heat or gameData.insanity:
        super(delta)
        return
    var bonus: float = xp_mod.get_level(5) * xp_mod.cfg_mental_reduce + xp_mod.prestige_mental_bonus()
    var before: float = gameData.mental
    super(delta)
    var drained: float = before - gameData.mental
    if drained > 0.0:
        gameData.mental = before - drained * (1.0 - bonus)

# Stamina: scale drain, leave regen unscaled.
func Stamina(delta):
    if xp_mod == null:
        super(delta)
        return
    var bonus: float = xp_mod.get_level(1) * xp_mod.cfg_stamina_reduce + xp_mod.prestige_stamina_bonus()
    var body_before: float = gameData.bodyStamina
    var arm_before: float = gameData.armStamina
    super(delta)
    var body_drained: float = body_before - gameData.bodyStamina
    var arm_drained: float = arm_before - gameData.armStamina
    if body_drained > 0.0:
        gameData.bodyStamina = body_before - body_drained * (1.0 - bonus)
    if arm_drained > 0.0:
        gameData.armStamina = arm_before - arm_drained * (1.0 - bonus)

# Clamp: full replacement — max HP can be higher than base.
func Clamp():
    var maxHP = 100.0
    if xp_mod:
        maxHP += xp_mod.get_level(0) * xp_mod.cfg_hp_per_level + xp_mod.prestige_hp_bonus()
    gameData.health = clampf(gameData.health, 0, maxHP)
    gameData.energy = clampf(gameData.energy, 0, 100)
    gameData.hydration = clampf(gameData.hydration, 0, 100)
    gameData.mental = clampf(gameData.mental, 0, 100)
    gameData.temperature = clampf(gameData.temperature, 0, 100)
    gameData.cat = clampf(gameData.cat, 0, 100)
    gameData.bodyStamina = clampf(gameData.bodyStamina, 0, 100)
    gameData.armStamina = clampf(gameData.armStamina, 0, 100)
    gameData.oxygen = clampf(gameData.oxygen, 0, 100)

func Death():
    if xp_mod and xp_mod.cfg_death_resets:
        xp_mod.ResetXP()
    super()

func Consume(item: ItemData):
    super(item)
    if xp_mod:
        xp_mod.award_skillbook_xp(item)

func Temperature(delta):
    var is_regenerating: bool = gameData.season == 1 or gameData.shelter or gameData.tutorial or gameData.heat
    if xp_mod == null or is_regenerating:
        super(delta)
        return
    var bonus: float = xp_mod.get_level(7) * xp_mod.cfg_coldres_reduce + xp_mod.prestige_coldres_bonus()
    super(delta * (1.0 - bonus))

