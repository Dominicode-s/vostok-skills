extends "res://Scripts/Controller.gd"

var _base_sprint_speed = 5.0
var _base_walk_speed = 2.5

func _physics_process(delta):
    var xp_mod = Engine.get_meta("XPMain", null)
    if xp_mod and xp_mod.xpSpeed > 0:
        var bonus = 1.0 + (xp_mod.xpSpeed * xp_mod.cfg_speed_bonus)
        sprintSpeed = _base_sprint_speed * bonus
        walkSpeed = _base_walk_speed * bonus
    else:
        sprintSpeed = _base_sprint_speed
        walkSpeed = _base_walk_speed
    super(delta)
