extends "res://Scripts/Recoil.gd"

func ApplyRecoil():
    super()
    var recoilMult = 1.0
    var xp_mod = Engine.get_meta("XPMain", null)
    if xp_mod and xp_mod.get_level(9) > 0:
        recoilMult = 1.0 - (xp_mod.get_level(9) * xp_mod.cfg_recoil_reduce)
    if gameData.firemode == 1:
        currentRotation = Vector3(-data.verticalRecoil * recoilMult, randf_range(-data.horizontalRecoil * recoilMult, data.horizontalRecoil * recoilMult), 0.0)
    else:
        currentRotation = Vector3(-data.verticalRecoil / 2 * recoilMult, randf_range(-data.horizontalRecoil * recoilMult, data.horizontalRecoil * recoilMult), 0.0)
    currentKick = Vector3(0.0, 0.0, -data.kick * recoilMult)
