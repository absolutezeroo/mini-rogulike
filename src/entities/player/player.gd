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
signal gold_changed(gold: int)

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
## Invulnerable this long after climbing out of a hole.
const FALL_INVULNERABILITY := 1.0

var def: PlayerDef
var inventory: Inventory
## Potions, bombs, scrolls: stacked in their own slots, out of the bag.
var belt := Belt.new()
var level := 1
var xp := 0
## Skill taught by the last tome read (last skill button).
var learned_skill: SkillDef
## Coins found during this run (spent at the merchant).
var gold := 0
## Cold floors and hot ground (see BodyTemperature).
var temperature := BodyTemperature.new()

var _move_direction := Vector2.ZERO
var _aim_hold := 0.0
var _step_timer := 0.0
var _left_foot := false
## Where the hero climbs back out after falling into a hole: the last solid ground stood on.
var _safe_position := Vector2.ZERO

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
	collision_mask = Layers.WORLD | Layers.MONSTERS | Layers.WATER

	base_stats = def.base_stats.duplicate()
	inventory = Inventory.new(def.inventory_size)
	for item in def.starting_equipment:
		equipment.equip(item)
	for item in def.starting_items:
		store(item)
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
	for i in range(1, Belt.SLOTS):
		if Input.is_action_just_pressed("belt_%d" % (i + 1)):
			use_belt(i)


func _update_footsteps(delta: float) -> void:
	if _move_direction.length() < 0.3 or is_dashing():
		_step_timer = 0.0
		return
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = STEP_INTERVAL
		var ambience := world.theme.ambience if world.theme else null
		var step_sound := ambience.footstep if ambience and ambience.footstep else Sfx.bank.footstep
		Sfx.play_at(step_sound, global_position, -10.0)
		var feet := global_position + Vector2(0, _feet_y())
		Vfx.dust(world, feet, 0.6)
		if ambience and ambience.footprint_color.a > 0.0:
			# Left, right, left... on each side of the path.
			_left_foot = not _left_foot
			var side := _move_direction.orthogonal().normalized() * (3.0 if _left_foot else -3.0)
			world.spawn_vfx(FootprintVfx.create(feet + side, _move_direction, ambience.footprint_color))


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

## Puts an item away: consumables on the belt if there is room, everything else (and the
## overflow) in the bag. False if neither has room.
func store(item: ItemDef) -> bool:
	return belt.add(item) or inventory.add(item)


func can_store(item: ItemDef) -> bool:
	return belt.can_add(item) or not inventory.is_full()


## Called when walking over an item. Returns false if it could not be taken.
func pick_up(item: ItemDef) -> bool:
	if item is EquipmentDef and equipment.get_item(item.slot) == null:
		equipment.equip(item)
		Events.log_message("Equipped %s" % item.display_name, item.color)
		_pickup_feedback(item, Sfx.bank.equip)
		return true
	if store(item):
		Events.log_message("Picked up %s" % item.display_name, item.color)
		_pickup_feedback(item, Sfx.bank.pickup)
		return true
	Events.log_message("Inventory full!", Palette.DANGER)
	return false


func _pickup_feedback(item: ItemDef, sound: AudioStream) -> void:
	if item is EquipmentDef and (item as EquipmentDef).rarity == ItemRarity.EPIC:
		Events.stat_counted.emit("epics", 1)
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
		Events.log_message("Inventory full!", Palette.DANGER)
		return
	inventory.add(equipment.unequip(slot))


func drop_item(item: ItemDef) -> void:
	if inventory.remove(item):
		world.spawn_item(item, global_position, false)


## Uses the item in belt slot `index` (the buttons next to the skills).
func use_belt(index: int) -> void:
	if is_dead or belt.item_at(index) == null:
		return
	var item := belt.take(index)
	item.use(self, get_aim_direction(SKILL_AIM_RANGE))
	Events.log_message("Used %s" % item.display_name, item.color)


## Belt slot 1 (the quick item key).
func use_quick_item() -> void:
	use_belt(0)


## Moves a consumable from the bag to the belt (or back). False if there is no room.
func move_to_belt(item: ItemDef) -> bool:
	if not belt.can_add(item) or not inventory.remove(item):
		return false
	belt.add(item)
	return true


func move_to_bag(index: int) -> bool:
	if belt.item_at(index) == null or inventory.is_full():
		return false
	inventory.add(belt.take(index))
	return true


# --- Progression -------------------------------------------------------------

func gain_xp(amount: int) -> void:
	if is_dead or hp <= 0:
		return  # a kill landing after the hero's own death (a projectile, a burn...)
	xp += amount
	while xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		level += 1
		if def.level_bonus:
			base_stats = base_stats.plus(def.level_bonus)
		invalidate_stats()
		hp = get_max_hp()
		health_changed.emit(hp, get_max_hp())
		Events.log_message("Level up! You are now level %d" % level, Palette.GOLD)
		world.spawn_floating_text(head_position() + Vector2(0, -10), "LEVEL UP", Palette.GOLD)
		Vfx.magic(world, global_position, Palette.GOLD)
		Sfx.play_ui(Sfx.bank.level_up)
		leveled_up.emit(level)
	xp_changed.emit(xp, xp_to_next_level(), level)


# --- Gold -------------------------------------------------------------------

func add_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)


## Returns false (and spends nothing) if there is not enough.
func spend_gold(amount: int) -> bool:
	if amount > gold:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


# --- Saving -----------------------------------------------------------------

## Everything about the hero a saved run needs (see RunSave).
func save_state() -> Dictionary:
	var gear := {}
	for slot: EquipmentDef.Slot in EquipmentDef.Slot.values():
		var item := equipment.get_item(slot)
		if item:
			gear[str(slot)] = LootRoller.to_data(item)
	return {
		"level": level,
		"xp": xp,
		"hp": hp,
		"base_stats": base_stats.to_dict(),
		"equipment": gear,
		"inventory": inventory.items.map(LootRoller.to_data),
		"belt": belt.to_data(),
		"gold": gold,
		"perks": perks.to_data(),
		"learned_skill": RunSave.ref(learned_skill),
	}


## Puts the hero back as saved (after setup()).
func load_state(data: Dictionary) -> void:
	level = int(data.get("level", 1))
	xp = int(data.get("xp", 0))
	base_stats = StatBlock.from_dict(data.get("base_stats", {}))
	for slot: EquipmentDef.Slot in EquipmentDef.Slot.values():
		equipment.unequip(slot)
	var gear: Dictionary = data.get("equipment", {})
	for key: String in gear:
		var item := LootRoller.from_data(gear[key]) as EquipmentDef
		if item:
			equipment.equip(item)
	inventory.items.clear()
	gold = int(data.get("gold", 0))
	for saved_item: Variant in data.get("inventory", []):
		var item := LootRoller.from_data(saved_item)
		if item:
			inventory.add(item)
	belt.load_data(data.get("belt", []))
	perks.load_data(data.get("perks", []))
	learned_skill = RunSave.load_ref(data.get("learned_skill")) as SkillDef
	_rebuild_skills(0.0)
	invalidate_stats()
	hp = clampi(int(data.get("hp", get_max_hp())), 1, get_max_hp())
	health_changed.emit(hp, get_max_hp())
	xp_changed.emit(xp, xp_to_next_level(), level)
	gold_changed.emit(gold)


# --- Holes ------------------------------------------------------------------

## Call after moving the hero to a new floor.
func reset_safe_position() -> void:
	_safe_position = global_position


func _check_ground() -> void:
	super._check_ground()
	if is_grounded() and world.is_solid_ground(global_position):
		_safe_position = global_position


## Climbs back out where the hero last stood safely, hurt.
func _on_fell(pit: PitDef) -> void:
	if is_dead:
		return  # killed during the fall: the body stays down there
	global_position = _safe_position
	_recover_from_fall()
	Vfx.puff(world, global_position)
	Events.log_message("You fell into a hole!", Palette.DANGER)
	_invulnerable_time = 0.0
	killed_by = "a fall"  # if this is what kills the hero
	take_hit(Combat.make_secondary_hit(null, maxi(1, roundi(get_max_hp() * pit.fall_damage))))
	if not is_dead:
		killed_by = ""
		_invulnerable_time = FALL_INVULNERABILITY


## Abandoning the run (pause menu): dead now, no perk or relic can save it.
func give_up() -> void:
	if is_dead:
		return
	killed_by = "giving up"
	hp = 0
	health_changed.emit(hp, get_max_hp())
	die(null)


# --- Hooks -------------------------------------------------------------------

func _on_damaged(hit: HitInfo, damage: int) -> void:
	damaged.emit(damage)
	if hit.source is Monster and is_instance_valid(hit.source):
		(hit.source as Monster).on_hit_player(self)
	if hit.is_tick:
		return
	_invulnerable_time = HIT_INVULNERABILITY
	if damage > 0 and world.rng.randf() < 0.6:
		world.add_splat(global_position + Vector2(0, 3), Palette.BLOOD.darkened(0.35), 0.35, hit.knockback.normalized())
	HitStop.freeze(0.08)
	camera.shake(clampf(float(damage) / get_max_hp() * 3.0, 0.25, 0.8))


func _on_died(_killer: Actor) -> void:
	Events.log_message("You died.", Palette.DANGER)
	camera.shake(1.0)
	Vfx.death(world, global_position, def.color)


func _hurt_sound(_hit: HitInfo) -> AudioStream:
	return Sfx.bank.player_hurt


func _death_sound() -> AudioStream:
	return Sfx.bank.player_death


func _hit_spark_color(_hit: HitInfo) -> Color:
	return Palette.BLOOD


func _tick_timers(delta: float) -> void:
	super._tick_timers(delta)
	temperature.update(self, delta)


## How many of `item` the hero carries (belt and bag).
func carried_count(item: ItemDef) -> int:
	return belt.count_of(item) + inventory.items.count(item)


func _body_modulate() -> Color:
	var color := super._body_modulate() * temperature.tint()
	# Blink while invulnerable after a hit (but not during a dash).
	if _invulnerable_time > 0.0 and not is_dashing() and not is_dead:
		if int(_invulnerable_time * 20.0) % 2 == 0:
			color.a = 0.35
	if is_dashing():
		color = Color(1.6, 1.6, 1.8, 0.7)
	return color
