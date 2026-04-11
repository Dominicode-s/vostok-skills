extends "res://Scripts/LootContainer.gd"

var xp_awarded = false
var _sfx_search: AudioStreamMP3
var _sfx_door: AudioStreamMP3

func _load_sfx():
    if _sfx_search: return
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
                    get_tree().create_timer(0.1).timeout.connect(_try_scavenge.bind(xp_mod, UIManager))

func _try_scavenge(xp_mod, ui_manager):
    var chance = xp_mod.get_level(11) * xp_mod.cfg_scavenger_chance
    if randf() >= chance:
        return
    var iface = ui_manager.interface
    if iface == null or iface.containerGrid == null:
        return
    var level = xp_mod.get_level(11)
    var roll = randf()
    var bonus_item = _try_loot_pool_spawn(level, roll, iface)
    if bonus_item:
        _show_scavenge_notify(ui_manager, bonus_item)
        return
    # Fallback: duplicate an existing container item
    var items = []
    for child in iface.containerGrid.get_children():
        if child is Item:
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
    # Level 1-2: always duplicate (return empty to fall through)
    if level <= 2:
        return ""
    var bucket: Array = []
    var tier := ""
    if level == 3:
        # 30% common
        if roll < 0.30 and commonBucket.size() > 0:
            bucket = commonBucket
            tier = "Common"
    elif level == 4:
        # 30% common, 20% rare
        if roll < 0.20 and rareBucket.size() > 0:
            bucket = rareBucket
            tier = "Rare"
        elif roll < 0.50 and commonBucket.size() > 0:
            bucket = commonBucket
            tier = "Common"
    elif level >= 5:
        # 25% common, 25% rare, 10% legendary
        if roll < 0.10 and legendaryBucket.size() > 0:
            bucket = legendaryBucket
            tier = "Legendary"
        elif roll < 0.35 and rareBucket.size() > 0:
            bucket = rareBucket
            tier = "Rare"
        elif roll < 0.60 and commonBucket.size() > 0:
            bucket = commonBucket
            tier = "Common"
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

func _show_scavenge_notify(ui_manager, item_name: String):
    _load_sfx()
    var sfx = _sfx_search
    if _sfx_door and randf() < 0.002:
        sfx = _sfx_door  # who put this here???
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
