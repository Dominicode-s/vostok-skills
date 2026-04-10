extends "res://Scripts/Character.gd"

var xp_mod = null

func _ready():
    xp_mod = Engine.get_meta("XPMain", null)

func Health(delta):
    if gameData.starvation && !gameData.isDead:
        gameData.health -= delta / 10

    if gameData.dehydration && !gameData.isDead:
        gameData.health -= delta / 10

    if gameData.insanity && !gameData.isDead:
        gameData.health -= delta / 10

    if gameData.bleeding && !gameData.isDead:
        gameData.health -= delta / 5

    if gameData.fracture && !gameData.isDead:
        gameData.health -= delta / 5

    if gameData.burn && !gameData.isDead:
        gameData.health -= delta / 5

    if gameData.rupture && !gameData.isDead:
        gameData.health -= delta

    if gameData.headshot && !gameData.isDead:
        gameData.health -= delta

    # XP: Passive health regen
    if xp_mod and xp_mod.xpRegen > 0 and !gameData.isDead and gameData.health > 0:
        var maxHP = 100.0 + xp_mod.xpHealth * xp_mod.cfg_hp_per_level
        if gameData.health < maxHP:
            gameData.health += delta * xp_mod.xpRegen * xp_mod.cfg_regen_per_level

    if gameData.health <= 0 && !gameData.isDead && !gameData.decor:
        Death()

func Energy(delta):
    if !gameData.starvation:
        var hungerMult = 1.0
        if xp_mod: hungerMult = 1.0 - (xp_mod.xpHunger * xp_mod.cfg_hunger_reduce)
        gameData.energy -= (delta / 30.0) * hungerMult

    if gameData.energy <= 0 && !gameData.starvation:
        Starvation(true)
    elif gameData.energy > 0 && gameData.starvation:
        Starvation(false)

func Hydration(delta):
    if !gameData.dehydration:
        var thirstMult = 1.0
        if xp_mod: thirstMult = 1.0 - (xp_mod.xpThirst * xp_mod.cfg_thirst_reduce)
        gameData.hydration -= (delta / 20.0) * thirstMult

    if gameData.hydration <= 0 && !gameData.dehydration:
        Dehydration(true)
    elif gameData.hydration > 0 && gameData.dehydration:
        Dehydration(false)

func Mental(delta):
    if gameData.heat:
        gameData.mental += delta / 4.0

    elif !gameData.insanity:
        var mentalMult = 1.0
        if xp_mod: mentalMult = 1.0 - (xp_mod.xpMental * xp_mod.cfg_mental_reduce)
        if (gameData.overweight
        || gameData.dehydration
        || gameData.starvation
        || gameData.bleeding
        || gameData.fracture
        || gameData.burn
        || gameData.frostbite
        || gameData.poisoning
        || gameData.rupture
        || gameData.headshot):
            gameData.mental -= (delta / 5.0) * mentalMult
        else:
            gameData.mental -= (delta / 35.0) * mentalMult

    if gameData.mental <= 0 && !gameData.insanity:
        Insanity(true)
    elif gameData.mental > 0 && gameData.insanity:
        Insanity(false)

func Stamina(delta):
    var staminaMult = 1.0
    if xp_mod: staminaMult = 1.0 - (xp_mod.xpStamina * xp_mod.cfg_stamina_reduce)

    if gameData.bodyStamina > 0 && (gameData.isRunning || gameData.overweight || (gameData.isSwimming && gameData.isMoving)):
        if gameData.overweight || gameData.starvation || gameData.dehydration:
            gameData.bodyStamina -= delta * 4.0 * staminaMult
        else:
            gameData.bodyStamina -= delta * 2.0 * staminaMult

    elif gameData.bodyStamina < 100:
        if gameData.starvation || gameData.dehydration:
            gameData.bodyStamina += delta * 5.0
        else:
            gameData.bodyStamina += delta * 10.0

    if gameData.armStamina > 0 && ((gameData.primary || gameData.secondary) && (gameData.weaponPosition == 2 || gameData.isAiming || gameData.isCanted || gameData.isInspecting || gameData.overweight) || (gameData.isSwimming && gameData.isMoving)):
        if gameData.overweight || gameData.starvation || gameData.dehydration:
            gameData.armStamina -= delta * 4.0 * staminaMult
        else:
            gameData.armStamina -= delta * 2.0 * staminaMult

    elif gameData.armStamina < 100:
        if gameData.starvation || gameData.dehydration:
            gameData.armStamina += delta * 10.0
        else:
            gameData.armStamina += delta * 20.0

func Clamp():
    var maxHP = 100.0
    if xp_mod: maxHP += xp_mod.xpHealth * xp_mod.cfg_hp_per_level
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

func Temperature(delta):
    if gameData.season == 1 || gameData.shelter || gameData.tutorial || gameData.heat:
        gameData.temperature += delta
    elif gameData.season == 2:
        var coldMult = 1.0
        if xp_mod: coldMult = 1.0 - (xp_mod.xpColdRes * xp_mod.cfg_coldres_reduce)

        if !gameData.frostbite:
            if gameData.isSubmerged:
                gameData.temperature -= (delta * 8.0) * insulation * coldMult
            elif gameData.isWater:
                gameData.temperature -= (delta * 4.0) * insulation * coldMult
            elif gameData.indoor:
                gameData.temperature -= (delta / 10.0) * insulation * coldMult
            else:
                gameData.temperature -= (delta / 5.0) * insulation * coldMult

    if gameData.temperature <= 0 && !gameData.frostbite:
        Frostbite(true)
    elif gameData.temperature > 0 && gameData.frostbite:
        Frostbite(false)
