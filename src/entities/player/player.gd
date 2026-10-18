class_name Player
extends Actor
## The hero. Reads input (keyboard, gamepad or the on-screen controls, which all
## go through the same Input actions), auto-aims, and owns inventory and XP.

signal xp_changed(xp: int, xp_needed: int, level: int)

const HIT_INVULNERABILITY := 0.6
const AIM_HOLD_TIME := 0.35         ## Keep facing the aim direction this long after attacking.
const MELEE_AIM_ASSIST := 70.0      ## Extra auto-aim distance beyond melee reach.
const SKILL_AIM_RANGE := 520.0
const SKILL_COUNT := 3

var def: PlayerDef
var inventory: Inventory
var level := 1
var xp := 0

var _move_direction := Vector2.ZERO
var _aim_hold := 0.0

@onready var camera: GameCamera = $Camera


func setup(player_def: PlayerDef) -> void:
	def = player_def
	faction = Faction.PLAYER
	free_on_death = false
	display_name = def.display_name
	body_color = def.color
	sprite = def.sprite
	set_body_radius(def.radius)
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.MONSTERS

	base_stats = def.base_stats.duplicate()
	inventory = Inventory.new(def.inventory_size)
	for item in def.starting_equipment:
		equipment.equip(item)
	for item in def.starting_items:
		inventory.add(item)
	skills.set_skills(def.skills)
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

	if Input.is_action_pressed("attack") and can_attack():
		attack(get_aim_direction(_auto_aim_range()))
		_aim_hold = AIM_HOLD_TIME

	for i in mini(skills.skills.size(), SKILL_COUNT):
		if Input.is_action_just_pressed("skill_%d" % (i + 1)):
			use_skill(i)

	if Input.is_action_just_pressed("quick_item"):
		use_quick_item()


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


# --- Items -------------------------------------------------------------------

## Called when walking over an item. Returns false if it could not be taken.
func pick_up(item: ItemDef) -> bool:
	if item is EquipmentDef and equipment.get_item(item.slot) == null:
		equipment.equip(item)
		Events.log_message("Equipped %s" % item.display_name, item.color)
		return true
	if inventory.add(item):
		Events.log_message("Picked up %s" % item.display_name, item.color)
		return true
	Events.log_message("Inventory full!", Color("ff6b6b"))
	return false


func use_item(item: ItemDef) -> void:
	if is_dead or not inventory.items.has(item):
		return
	if item is ConsumableDef:
		inventory.remove(item)
		item.use(self, get_aim_direction(SKILL_AIM_RANGE))
		Events.log_message("Used %s" % item.display_name, item.color)
	elif item is EquipmentDef:
		inventory.remove(item)
		var previous := equipment.equip(item)
		if previous:
			inventory.add(previous)
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
		world.spawn_vfx(RingVfx.create(global_position, 70.0, Color("ffd166")))
	xp_changed.emit(xp, xp_to_next_level(), level)


# --- Hooks -------------------------------------------------------------------

func _on_damaged(_hit: HitInfo, damage: int) -> void:
	_invulnerable_time = HIT_INVULNERABILITY
	camera.shake(clampf(float(damage) / get_max_hp() * 3.0, 0.25, 0.8))


func _on_died(_killer: Actor) -> void:
	Events.log_message("You died.", Color("ff6b6b"))
	camera.shake(1.0)


func _body_modulate() -> Color:
	var color := super._body_modulate()
	# Blink while invulnerable after a hit (but not during a dash).
	if _invulnerable_time > 0.0 and not is_dashing() and not is_dead:
		if int(_invulnerable_time * 20.0) % 2 == 0:
			color.a = 0.35
	if is_dashing():
		color = Color(1.6, 1.6, 1.8, 0.7)
	return color
