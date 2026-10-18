class_name Player
extends Actor
## The hero. Reads input (keyboard, gamepad or the on-screen controls, which all
## go through the same Input actions), auto-aims, and owns inventory and XP.

signal xp_changed(xp: int, xp_needed: int, level: int)
## Emitted once per level gained (the game then offers a perk).
signal leveled_up(level: int)
## The hero lost HP (screen effects listen to this).
signal damaged(amount: int)
## The skill buttons changed (new weapon, new spell learned).
signal skills_changed

const HIT_INVULNERABILITY := 0.6
const AIM_HOLD_TIME := 0.35         ## Keep facing the aim direction this long after attacking.
const MELEE_AIM_ASSIST := 70.0      ## Extra auto-aim distance beyond melee reach.
const SKILL_AIM_RANGE := 520.0
## Skill buttons: innate skills (the roll), then the weapon's skills, then the learned spell.
## Slots without a skill stay empty (null), so a skill never jumps to another button.
const WEAPON_SKILL_SLOTS := 2
const SKILL_COUNT := 4
## New skills start on this cooldown when the weapon is swapped (no free casts by swapping).
const SWAP_COOLDOWN := 1.5
const STEP_INTERVAL := 0.3

var def: PlayerDef
var inventory: Inventory
var level := 1
var xp := 0
## Skill taught by the last tome read (last skill button).
var learned_skill: SkillDef

var _move_direction := Vector2.ZERO
var _aim_hold := 0.0
var _step_timer := 0.0

@onready var camera: GameCamera = $Camera


func setup(player_def: PlayerDef) -> void:
	def = player_def
	faction = Faction.PLAYER
	free_on_death = false
	display_name = def.display_name
	body_color = def.color
	frames = def.frames
	frames_offset = def.frames_offset
	set_body_radius(def.radius)
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.MONSTERS

	base_stats = def.base_stats.duplicate()
	inventory = Inventory.new(def.inventory_size)
	for item in def.starting_equipment:
		equipment.equip(item)
	for item in def.starting_items:
		inventory.add(item)
	_rebuild_skills(0.0)
	equipment.changed.connect(_rebuild_skills.bind(SWAP_COOLDOWN))
	invalidate_stats()
	hp = get_max_hp()


func xp_to_next_level() -> int:
	return def.xp_to_next_level(level)


# --- Input -------------------------------------------------------------------

func _think(delta: float) -> void:
	_aim_hold = maxf(_aim_hold - delta, 0.0)
	_move_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _move_direction != Vector2.ZERO and _aim_hold <= 0.0:
		facing = _move_direction.normalized()
	_update_footsteps(delta)

	if Input.is_action_pressed("attack") and can_attack():
		attack(get_aim_direction(_auto_aim_range()))
		_aim_hold = AIM_HOLD_TIME

	for i in mini(skills.skills.size(), SKILL_COUNT):
		if skills.skills[i] and Input.is_action_just_pressed("skill_%d" % (i + 1)):
			use_skill(i)

	if Input.is_action_just_pressed("quick_item"):
		use_quick_item()


func _update_footsteps(delta: float) -> void:
	if _move_direction.length() < 0.3 or is_dashing():
		_step_timer = 0.0
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = STEP_INTERVAL
		Sfx.play_at(Sfx.bank.footstep, global_position, -12.0)
		Vfx.dust(world, global_position + Vector2(0, _feet_y()), 0.6)


func _get_desired_velocity() -> Vector2:
	return _move_direction * get_move_speed()


func get_move_direction() -> Vector2:
	return _move_direction


## Direction to the closest visible enemy in range, or the current facing.
func get_aim_direction(max_range: float) -> Vector2:
	var target := get_aim_target(max_range)
	if target:
		return global_position.direction_to(target.global_position)
	return facing


func get_aim_target(max_range: float) -> Actor:
	var best: Actor = null
	var best_distance := max_range
	for enemy in world.get_hostiles(faction):
		var distance := global_position.distance_to(enemy.global_position) - enemy.radius
		if distance < best_distance and world.has_line_of_sight(global_position, enemy.global_position):
			best = enemy
			best_distance = distance
	return best


func _auto_aim_range() -> float:
	var weapon := get_weapon()
	if weapon == null:
		return 0.0
	if weapon.kind == WeaponDef.Kind.MELEE:
		return radius + weapon.reach + MELEE_AIM_ASSIST
	return weapon.reach


func use_skill(index: int) -> void:
	var aim := get_aim_direction(SKILL_AIM_RANGE)
	if skills.try_use(index, self, aim):
		facing = aim
		_aim_hold = AIM_HOLD_TIME


# --- Skills ------------------------------------------------------------------

## Innate skills + the weapon's skills + the learned spell, each in its own slot.
func _rebuild_skills(new_skill_cooldown: float) -> void:
	var list: Array[SkillDef] = []
	list.append_array(def.innate_skills)
	var weapon := get_weapon()
	for i in WEAPON_SKILL_SLOTS:
		list.append(weapon.skills[i] if weapon and i < weapon.skills.size() else null)
	list.append(learned_skill)
	list.resize(mini(list.size(), SKILL_COUNT))
	skills.replace(list, new_skill_cooldown)
	skills_changed.emit()


## Puts a skill in the learned slot (replacing the previous one).
func learn_skill(skill: SkillDef) -> void:
	learned_skill = skill
	_rebuild_skills(0.0)
	Events.log_message("Learned %s!" % skill.display_name, skill.color)
	Vfx.magic(world, global_position, skill.color)
	Sfx.play_ui(Sfx.bank.level_up)


# --- Items -------------------------------------------------------------------

## Called when walking over an item. Returns false if it could not be taken.
func pick_up(item: ItemDef) -> bool:
	if item is EquipmentDef and equipment.get_item(item.slot) == null:
		equipment.equip(item)
		Events.log_message("Equipped %s" % item.display_name, item.color)
		_pickup_feedback(item, Sfx.bank.equip)
		return true
	if inventory.add(item):
		Events.log_message("Picked up %s" % item.display_name, item.color)
		_pickup_feedback(item, Sfx.bank.pickup)
		return true
	Events.log_message("Inventory full!", Color("ff6b6b"))
	return false


func _pickup_feedback(item: ItemDef, sound: AudioStream) -> void:
	Sfx.play_at(sound, global_position)
	Vfx.sparkles(world, global_position, item.color)


func use_item(item: ItemDef) -> void:
	if is_dead or not inventory.items.has(item):
		return
	if item is ConsumableDef:
		inventory.remove(item)
		item.use(self, get_aim_direction(SKILL_AIM_RANGE))
		Events.log_message("Used %s" % item.display_name, item.color)
	elif item is SkillTomeDef:
		inventory.remove(item)
		learn_skill((item as SkillTomeDef).skill)
	elif item is EquipmentDef:
		inventory.remove(item)
		var previous := equipment.equip(item)
		if previous:
			inventory.add(previous)
		Sfx.play_ui(Sfx.bank.equip)
		Events.log_message("Equipped %s" % item.display_name, item.color)


func unequip(slot: EquipmentDef.Slot) -> void:
	if equipment.get_item(slot) == null:
		return
	if inventory.is_full():
		Events.log_message("Inventory full!", Color("ff6b6b"))
		return
	inventory.add(equipment.unequip(slot))


func drop_item(item: ItemDef) -> void:
	if inventory.remove(item):
		world.spawn_item(item, global_position, false)


func use_quick_item() -> void:
	var item := inventory.first_consumable()
	if item:
		use_item(item)


# --- Progression -------------------------------------------------------------

func gain_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		level += 1
		if def.level_bonus:
			base_stats = base_stats.plus(def.level_bonus)
		invalidate_stats()
		hp = get_max_hp()
		health_changed.emit(hp, get_max_hp())
		Events.log_message("Level up! You are now level %d" % level, Color("ffd166"))
		world.spawn_floating_text(head_position() + Vector2(0, -10), "LEVEL UP", Color("ffd166"))
		Vfx.magic(world, global_position, Color("ffd166"))
		Sfx.play_ui(Sfx.bank.level_up)
		leveled_up.emit(level)
	xp_changed.emit(xp, xp_to_next_level(), level)


# --- Hooks -------------------------------------------------------------------

func _on_damaged(_hit: HitInfo, damage: int) -> void:
	damaged.emit(damage)
	_invulnerable_time = HIT_INVULNERABILITY
	HitStop.freeze(0.08)
	camera.shake(clampf(float(damage) / get_max_hp() * 3.0, 0.25, 0.8))


func _on_died(_killer: Actor) -> void:
	Events.log_message("You died.", Color("ff6b6b"))
	camera.shake(1.0)
	Vfx.death(world, global_position, def.color)


func _hurt_sound(_hit: HitInfo) -> AudioStream:
	return Sfx.bank.player_hurt


func _death_sound() -> AudioStream:
	return Sfx.bank.player_death


func _hit_spark_color(_hit: HitInfo) -> Color:
	return Color("e84537")


func _body_modulate() -> Color:
	var color := super._body_modulate()
	# Blink while invulnerable after a hit (but not during a dash).
	if _invulnerable_time > 0.0 and not is_dashing() and not is_dead:
		if int(_invulnerable_time * 20.0) % 2 == 0:
			color.a = 0.35
	if is_dashing():
		color = Color(1.6, 1.6, 1.8, 0.7)
	return color
