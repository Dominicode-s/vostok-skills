extends "res://Scripts/Character.gd"

var xp_mod = null

func _ready():
    xp_mod = Engine.get_meta("XPMain", null)

func Health(delta):
    # Delegate the damage block to whatever is next in the Character.gd
    # chain (the base game by default, or another mod like injuries system
    # rework that does its own `Health()` damage tuning). We zero
    # gameData.xpRegen across super() so the base game's hardcoded
    # `xpRegen * 0.2` regen block short-circuits — otherwise it would
    # double-apply alongside our configurable regen below. Everything else
    # in the base Health() (damage conditions, Death() trigger) still runs.
    var saved_xp_regen = gameData.xpRegen
    gameData.xpRegen = 0
    super(delta)
    gameData.xpRegen = saved_xp_regen

    # XP: passive health regen. Prestige bonuses add to both max HP and the
    # per-second regen rate on top of skill-tree bonuses, so a player with
    # Regen skill 0 but Regen prestige 2 still gets a slow trickle.
    if xp_mod and !gameData.isDead and gameData.health > 0:
        var regen_rate = xp_mod.get_level(6) * xp_mod.cfg_regen_per_level + xp_mod.prestige_regen_bonus()
        if regen_rate > 0.0:
            var maxHP = 100.0 + xp_mod.get_level(0) * xp_mod.cfg_hp_per_level + xp_mod.prestige_hp_bonus()
            if gameData.health < maxHP:
                gameData.health += delta * regen_rate

# All stat-drain overrides follow the community wiki's canonical chain
# pattern: call super() first to let the whole chain (base + any mod
# between us and base) do its thing, then adjust the delta it produced
# by our skill-based multiplier. No shared-state mutation — we never
# touch gameData.xp<Stat> across the super call, which avoids the
# timing + save-race hazards that injection has.

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
    # Heat branch in base is a regen (+delta/4) not a drain, and the
    # insanity branch is its own thing — neither should get scaled.
    if xp_mod == null or gameData.heat or gameData.insanity:
        super(delta)
        return
    var bonus: float = xp_mod.get_level(5) * xp_mod.cfg_mental_reduce + xp_mod.prestige_mental_bonus()
    var before: float = gameData.mental
    super(delta)
    var drained: float = before - gameData.mental
    if drained > 0.0:
        gameData.mental = before - drained * (1.0 - bonus)

# Stamina has both drain (scale by our multiplier) and regen (unscaled).
# The scaled-diff trick handles both automatically: if super regenerated
# stamina (delta positive), we don't apply the reducer.
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

# Clamp is a full replacement — the canonical "super-first then modify"
# pattern only works when our modification TIGHTENS what super did. Our
# max HP is LOOSER than base's (`100 + xpHealth*5`) whenever the player
# has prestige ranks or a non-default cfg_hp_per_level, and a post-super
# clampf can't raise health above the value base just clamped it down
# to. Full replacement is the correct move here; chain compat loss for
# Clamp specifically is acceptable (no known mod overrides it).
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
    # super() so mods sitting between us and the base game still run.
    super(item)
    if xp_mod:
        xp_mod.award_skillbook_xp(item)

# Temperature: base has no xp-based multiplier, so we scale delta only in
# the cold-drain branch. Regen branches (indoor/shelter/heat) pass through
# super with unscaled delta.
func Temperature(delta):
    var is_regenerating: bool = gameData.season == 1 or gameData.shelter or gameData.tutorial or gameData.heat
    if xp_mod == null or is_regenerating:
        super(delta)
        return
    var bonus: float = xp_mod.get_level(7) * xp_mod.cfg_coldres_reduce + xp_mod.prestige_coldres_bonus()
    super(delta * (1.0 - bonus))

