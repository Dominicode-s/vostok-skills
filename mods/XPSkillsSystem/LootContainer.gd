extends "res://Scripts/LootContainer.gd"

var xp_awarded = false

func Interact():
    if !locked:
        var UIManager = get_tree().current_scene.get_node_or_null("/root/Map/Core/UI")
        if !UIManager: return
        UIManager.OpenContainer(self)
        ContainerAudio()
        if !xp_awarded:
            xp_awarded = true
            var xp_mod = Engine.get_meta("XPMain", null)
            if xp_mod:
                xp_mod.xp += xp_mod.cfg_xp_container
                xp_mod.xpTotal += xp_mod.cfg_xp_container
                xp_mod.SaveXP()
                if xp_mod.get_level(11) > 0:
                    _try_scavenge.call_deferred(xp_mod, UIManager)

func _try_scavenge(xp_mod, ui_manager):
    var chance = xp_mod.get_level(11) * xp_mod.cfg_scavenger_chance
    if randf() >= chance:
        return
    var container_grid = ui_manager.containerGrid
    if container_grid == null:
        return
    var items = []
    for child in container_grid.get_children():
        if child is Item:
            items.append(child)
    if items.is_empty():
        return
    var source_item = items[randi() % items.size()]
    var dupe = source_item.duplicate()
    dupe.position = Vector2.ZERO
    if ui_manager.AutoPlace(dupe, container_grid, null, false):
        pass
    else:
        dupe.queue_free()
