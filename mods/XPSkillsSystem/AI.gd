extends "res://Scripts/AI.gd"

func Death(direction, force):
    super(direction, force)
    var xp_mod = Engine.get_meta("XPMain", null)
    if xp_mod:
        var xpReward = xp_mod.cfg_xp_boss if boss else xp_mod.cfg_xp_kill
        xp_mod.xp += xpReward
        xp_mod.xpTotal += xpReward
        xp_mod.SaveXP()

func Hearing():
    var runRange = 20.0
    var walkRange = 5.0
    var xp_mod = Engine.get_meta("XPMain", null)
    if xp_mod and xp_mod.get_level(8) > 0:
        var mult = 1.0 - (xp_mod.get_level(8) * xp_mod.cfg_stealth_reduce)
        runRange *= mult
        walkRange *= mult
    if (playerDistance3D < runRange && gameData.isRunning) || (playerDistance3D < walkRange && gameData.isWalking):
        if currentState != State.Ambush:
            lastKnownLocation = playerPosition
        if currentState == State.Wander || currentState == State.Guard || currentState == State.Patrol:
            Decision()
