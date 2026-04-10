extends "res://Scripts/LootContainer.gd"

var xp_awarded = false

func Interact():
    if !locked:
        var UIManager = get_tree().current_scene.get_node("/root/Map/Core/UI")
        UIManager.OpenContainer(self)
        ContainerAudio()
        if !xp_awarded:
            xp_awarded = true
            var xp_mod = Engine.get_meta("XPMain", null)
            if xp_mod:
                xp_mod.xp += xp_mod.cfg_xp_container
                xp_mod.xpTotal += xp_mod.cfg_xp_container
                xp_mod.SaveXP()
