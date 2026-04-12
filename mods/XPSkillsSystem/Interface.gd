extends "res://Scripts/Interface.gd"

var skillsButton: Button
var skillsUI: Control
var skillsXPLabel: Label
var skillRows: Array = []
var skillNames = ["Vitality", "Endurance", "Pack Mule", "Hunger Resist", "Thirst Resist", "Iron Will", "Regeneration", "Cold Resistance", "Stealth", "Recoil Control", "Athleticism", "Scavenger"]
var skillKeys = ["xpHealth", "xpStamina", "xpCarry", "xpHunger", "xpThirst", "xpMental", "xpRegen", "xpColdRes", "xpStealth", "xpRecoil", "xpSpeed", "xpScavenger"]
var skillMax = [10, 10, 10, 10, 10, 10, 5, 10, 10, 10, 5, 5]
var skillCostBase = [25, 25, 20, 20, 20, 20, 50, 20, 25, 25, 30, 30]
var skillDescs = ["+5 Max HP", "-10% Stamina Drain", "+2kg Carry Weight", "-8% Hunger Drain", "-8% Thirst Drain", "-8% Mental Drain", "+0.2 HP/sec Regen", "-8% Cold Drain", "-5% AI Hearing Range", "-5% Weapon Recoil", "+4% Movement Speed", "+5% Loot Chance (better at higher levels)"]
var skillsBuilt = false
var skillDescLabels: Array = []
var _xp_refresh_timer: float = 0.0
var _skills_vbox: VBoxContainer
var _skill_row_panels: Array = []

func _process(delta):
    if skillsUI and skillsUI.visible:
        _xp_refresh_timer += delta
        if _xp_refresh_timer >= 0.5:
            _xp_refresh_timer = 0.0
            UpdateSkillsUI()

func Open():
    if !skillsBuilt:
        var xp_mod = Engine.get_meta("XPMain", null)
        if xp_mod:
            skillMax = xp_mod.cfg_max_levels
            skillCostBase = xp_mod.cfg_cost_bases
        BuildSkillsUI()
        skillsBuilt = true
    RefreshSkillDescs()
    super()

func HideAllTools():
    super()
    if skillsUI: skillsUI.hide()

func DisableTools():
    super()
    if skillsButton: skillsButton.disabled = true

func EnableTools():
    super()
    if skillsButton: skillsButton.disabled = false

func LoadDefaultTool(tool: int):
    super(tool)
    if skillsButton: skillsButton.set_pressed_no_signal(false)

func UpdateStats(updateLabels: bool):
    await get_tree().physics_frame

    currentInventoryCapacity = 0.0
    currentInventoryWeight = 0.0
    currentInventoryValue = 0.0
    currentEquipmentValue = 0.0
    currentContainerWeight = 0.0
    currentContainerValue = 0.0
    currentEquipmentWeight = 0.0
    currentEquipmentValue = 0.0
    currentEquipmentInsulation = 0.0
    currentSupplyValue = 0.0
    inventoryWeightPercentage = 0.0

    for equipmentSlot in equipment.get_children():
        if equipmentSlot is Slot && equipmentSlot.get_child_count() != 0:
            currentEquipmentWeight += equipmentSlot.get_child(0).Weight()
            currentEquipmentValue += equipmentSlot.get_child(0).Value()
            currentInventoryCapacity += equipmentSlot.get_child(0).slotData.itemData.capacity
            currentEquipmentInsulation += equipmentSlot.get_child(0).slotData.itemData.insulation

    currentInventoryCapacity += baseCarryWeight
    var xp_mod = Engine.get_meta("XPMain", null)
    if xp_mod:
        currentInventoryCapacity += xp_mod.get_level(2) * xp_mod.cfg_carry_per_level
    insulationMultiplier = 1.0 - (currentEquipmentInsulation / 100.0)
    character.insulation = insulationMultiplier

    for element in inventoryGrid.get_children():
        currentInventoryWeight += element.Weight()
        currentInventoryValue += element.Value()

    if currentInventoryWeight > currentInventoryCapacity:
        if !gameData.overweight:
            character.Overweight(true)
    else:
        character.Overweight(false)

    var combinedWeight = currentInventoryWeight + currentEquipmentWeight

    if combinedWeight > 20:
        character.heavyGear = true
    else:
        character.heavyGear = false

    if container:
        for element in containerGrid.get_children():
            currentContainerWeight += element.Weight()
            currentContainerValue += element.Value()

    if trader:
        for element in supplyGrid.get_children():
            currentSupplyValue += element.Value()

    if updateLabels:
        inventoryWeightPercentage = currentInventoryWeight / currentInventoryCapacity
        inventoryCapacity.text = str("%.1f" % currentInventoryCapacity)
        inventoryWeight.text = str("%.1f" % currentInventoryWeight)
        inventoryValue.text = str(int(round(currentInventoryValue)))

        if inventoryWeightPercentage > 1: inventoryWeight.modulate = Color.RED
        elif inventoryWeightPercentage >= 0.5: inventoryWeight.modulate = Color.YELLOW
        else: inventoryWeight.modulate = Color.GREEN

        equipmentCapacity.text = str(int(round(currentInventoryCapacity))) + "kg"
        equipmentValue.text = str(int(round(currentEquipmentValue)))
        equipmentInsulation.text = str(int(round(currentEquipmentInsulation)))

        if currentEquipmentInsulation <= 25: equipmentInsulation.modulate = Color.RED
        elif currentEquipmentInsulation > 25 && currentEquipmentInsulation <= 50: equipmentInsulation.modulate = Color.YELLOW
        else: equipmentInsulation.modulate = Color.GREEN

        if container:
            containerWeight.text = str("%.1f" % currentContainerWeight)
            containerValue.text = str(int(round(currentContainerValue)))
        if trader:
            supplyValue.text = str(int(round(currentSupplyValue)))

# --- Skills UI ---

func BuildSkillsUI():
    Engine.set_meta("XPInterface", self)
    var buttonsContainer = $Tools / Buttons / Margin / Buttons
    skillsButton = Button.new()
    skillsButton.text = "Skills"
    skillsButton.toggle_mode = true
    skillsButton.focus_mode = Control.FOCUS_NONE
    skillsButton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    skillsButton.size_flags_vertical = Control.SIZE_EXPAND_FILL
    buttonsContainer.add_child(skillsButton)
    buttonsContainer.move_child(skillsButton, buttonsContainer.get_child_count() - 2)
    skillsButton.pressed.connect(_on_skills_pressed)

    skillsUI = Control.new()
    skillsUI.name = "Skills"
    skillsUI.offset_left = 0
    skillsUI.offset_top = 0
    skillsUI.offset_right = 512
    skillsUI.offset_bottom = 704
    $Tools.add_child(skillsUI)
    skillsUI.hide()

    var bg = ColorRect.new()
    bg.color = Color(0.08, 0.08, 0.08, 0.95)
    bg.offset_right = 512
    bg.offset_bottom = 704
    skillsUI.add_child(bg)

    var margin = MarginContainer.new()
    margin.offset_right = 512
    margin.offset_bottom = 704
    margin.add_theme_constant_override("margin_left", 16)
    margin.add_theme_constant_override("margin_right", 16)
    margin.add_theme_constant_override("margin_top", 16)
    margin.add_theme_constant_override("margin_bottom", 16)
    skillsUI.add_child(margin)

    var scroll = ScrollContainer.new()
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    margin.add_child(scroll)

    _skills_vbox = VBoxContainer.new()
    _skills_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _skills_vbox.add_theme_constant_override("separation", 10)
    scroll.add_child(_skills_vbox)

    var header = HBoxContainer.new()
    header.add_theme_constant_override("separation", 16)
    _skills_vbox.add_child(header)

    var titleLabel = Label.new()
    titleLabel.text = "SKILLS"
    titleLabel.add_theme_font_size_override("font_size", 20)
    titleLabel.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
    header.add_child(titleLabel)

    skillsXPLabel = Label.new()
    skillsXPLabel.text = "XP: 0"
    skillsXPLabel.add_theme_font_size_override("font_size", 16)
    skillsXPLabel.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
    skillsXPLabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    skillsXPLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    header.add_child(skillsXPLabel)

    var sep = HSeparator.new()
    sep.custom_minimum_size.y = 4
    _skills_vbox.add_child(sep)

    _build_skill_rows()


func _build_skill_rows():
    var xp_mod = Engine.get_meta("XPMain", null)
    skillRows.clear()
    skillDescLabels.clear()
    for i in skillNames.size():
        if xp_mod and not xp_mod.is_skill_enabled(i):
            skillRows.append(null)
            skillDescLabels.append(null)
            continue
        var rowPanel = PanelContainer.new()
        rowPanel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        var stylebox = StyleBoxFlat.new()
        stylebox.bg_color = Color(0.12, 0.12, 0.12, 0.8)
        stylebox.set_corner_radius_all(4)
        stylebox.content_margin_left = 10
        stylebox.content_margin_right = 10
        stylebox.content_margin_top = 6
        stylebox.content_margin_bottom = 6
        rowPanel.add_theme_stylebox_override("panel", stylebox)
        _skills_vbox.add_child(rowPanel)

        var row = HBoxContainer.new()
        row.add_theme_constant_override("separation", 10)
        rowPanel.add_child(row)

        var nameLabel = Label.new()
        nameLabel.text = skillNames[i]
        nameLabel.custom_minimum_size.x = 120
        nameLabel.add_theme_font_size_override("font_size", 14)
        nameLabel.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
        row.add_child(nameLabel)

        var levelLabel = Label.new()
        levelLabel.text = "0/" + str(skillMax[i])
        levelLabel.custom_minimum_size.x = 42
        levelLabel.add_theme_font_size_override("font_size", 14)
        levelLabel.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
        levelLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        row.add_child(levelLabel)

        var descLabel = Label.new()
        descLabel.text = skillDescs[i]
        descLabel.add_theme_font_size_override("font_size", 12)
        descLabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        descLabel.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
        row.add_child(descLabel)
        skillDescLabels.append(descLabel)

        var upgradeBtn = Button.new()
        upgradeBtn.text = "+" + str(skillCostBase[i]) + " XP"
        upgradeBtn.custom_minimum_size.x = 90
        upgradeBtn.custom_minimum_size.y = 30
        upgradeBtn.focus_mode = Control.FOCUS_NONE
        upgradeBtn.pressed.connect(_on_skill_upgrade.bind(i))
        row.add_child(upgradeBtn)

        skillRows.append({"level": levelLabel, "button": upgradeBtn, "index": i})
        _skill_row_panels.append(rowPanel)


func RebuildSkills():
    if not skillsBuilt or not _skills_vbox:
        return
    for panel in _skill_row_panels:
        if panel and is_instance_valid(panel):
            panel.queue_free()
    _skill_row_panels.clear()
    _build_skill_rows()
    RefreshSkillDescs()
    UpdateSkillsUI()


func RefreshSkillDescs():
    var xp_mod = Engine.get_meta("XPMain", null)
    if !xp_mod or skillDescLabels.size() < 12: return
    var descs = [
        "+" + str(xp_mod.cfg_hp_per_level) + " Max HP",
        "-" + str(int(xp_mod.cfg_stamina_reduce * 100)) + "% Stamina Drain",
        "+" + str(xp_mod.cfg_carry_per_level) + "kg Carry Weight",
        "-" + str(int(xp_mod.cfg_hunger_reduce * 100)) + "% Hunger Drain",
        "-" + str(int(xp_mod.cfg_thirst_reduce * 100)) + "% Thirst Drain",
        "-" + str(int(xp_mod.cfg_mental_reduce * 100)) + "% Mental Drain",
        "+" + str(xp_mod.cfg_regen_per_level) + " HP/sec Regen",
        "-" + str(int(xp_mod.cfg_coldres_reduce * 100)) + "% Cold Drain",
        "-" + str(int(xp_mod.cfg_stealth_reduce * 100)) + "% AI Hearing Range",
        "-" + str(int(xp_mod.cfg_recoil_reduce * 100)) + "% Weapon Recoil",
        "+" + str(int(xp_mod.cfg_speed_bonus * 100)) + "% Movement Speed",
        "+" + str(int(xp_mod.cfg_scavenger_chance * 100)) + "% Extra Loot Chance"
    ]
    for i in descs.size():
        if skillDescLabels[i] != null:
            skillDescLabels[i].text = descs[i]


func _on_skills_pressed() -> void:
    HideAllTools()
    skillsUI.show()
    eventsButton.set_pressed_no_signal(false)
    craftingButton.set_pressed_no_signal(false)
    notesButton.set_pressed_no_signal(false)
    mapButton.set_pressed_no_signal(false)
    casetteButton.set_pressed_no_signal(false)
    skillsButton.set_pressed_no_signal(true)
    UpdateSkillsUI()
    PlayClick()

func _on_skill_upgrade(index: int):
    var xp_mod = Engine.get_meta("XPMain", null)
    if !xp_mod: return

    var currentLevel = GetSkillLevel(index)
    if currentLevel >= skillMax[index]:
        PlayError()
        return

    var cost = skillCostBase[index] * (currentLevel + 1)
    if xp_mod.xp < cost:
        PlayError()
        return

    xp_mod.xp -= cost
    SetSkillLevel(index, currentLevel + 1)
    xp_mod.SaveXP()
    UpdateSkillsUI()
    UpdateStats(true)
    PlayClick()

func GetSkillLevel(index: int) -> int:
    var xp_mod = Engine.get_meta("XPMain", null)
    if !xp_mod: return 0
    match index:
        0: return xp_mod.xpHealth
        1: return xp_mod.xpStamina
        2: return xp_mod.xpCarry
        3: return xp_mod.xpHunger
        4: return xp_mod.xpThirst
        5: return xp_mod.xpMental
        6: return xp_mod.xpRegen
        7: return xp_mod.xpColdRes
        8: return xp_mod.xpStealth
        9: return xp_mod.xpRecoil
        10: return xp_mod.xpSpeed
        11: return xp_mod.xpScavenger
    return 0

func SetSkillLevel(index: int, value: int):
    var xp_mod = Engine.get_meta("XPMain", null)
    if !xp_mod: return
    match index:
        0: xp_mod.xpHealth = value
        1: xp_mod.xpStamina = value
        2: xp_mod.xpCarry = value
        3: xp_mod.xpHunger = value
        4: xp_mod.xpThirst = value
        5: xp_mod.xpMental = value
        6: xp_mod.xpRegen = value
        7: xp_mod.xpColdRes = value
        8: xp_mod.xpStealth = value
        9: xp_mod.xpRecoil = value
        10: xp_mod.xpSpeed = value
        11: xp_mod.xpScavenger = value

func UpdateSkillsUI():
    if !skillsXPLabel: return
    var xp_mod = Engine.get_meta("XPMain", null)
    if !xp_mod: return
    skillsXPLabel.text = "XP: " + str(xp_mod.xp) + "  (Total: " + str(xp_mod.xpTotal) + ")"
    for row in skillRows:
        if row == null:
            continue
        var i = row.index
        var level = GetSkillLevel(i)
        row.level.text = str(level) + "/" + str(skillMax[i])
        var nextCost = skillCostBase[i] * (level + 1)
        if level >= skillMax[i]:
            row.button.text = "MAX"
            row.button.disabled = true
        else:
            row.button.text = "+" + str(nextCost) + " XP"
            row.button.disabled = xp_mod.xp < nextCost
