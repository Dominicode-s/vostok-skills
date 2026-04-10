extends "res://Scripts/Trader.gd"

func CompleteTask(taskData: TaskData):
    super(taskData)
    var xp_mod = Engine.get_meta("XPMain", null)
    if xp_mod:
        xp_mod.xp += xp_mod.cfg_xp_task
        xp_mod.xpTotal += xp_mod.cfg_xp_task
        xp_mod.SaveXP()
