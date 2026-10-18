extends Node
## Headless test suite. Run from a terminal at the project root:
##   godot --headless --fixed-fps 60 res://tests/run_tests.tscn
## Unit checks first, then a bot plays the real game for a while.
## Exit code is the number of failed checks (0 = all good).

var CONTENT: ContentDB  # loaded at runtime: preloading here would load the whole game at parse time
var GAME_SCENE: PackedScene

var _failures := 0
var _checks := 0


func _ready() -> void:
	# Without a sound card, playbacks are never released; keep the output clean.
	Sfx.enabled = false
	CONTENT = load("res://data/content_db.tres")
	GAME_SCENE = load("res://src/game/game.tscn")
	_test_stat_block()
	_test_combat_rules()
	_test_content()
	_test_generation()
	_test_inventory_and_equipment()
	await _test_gameplay()
	print("\n%d checks, %d failed" % [_checks, _failures])
	Sfx.stop_all()
	HitStop.reset()
	await _frames(2)
	get_tree().quit(_failures)


func check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)


# --- Unit tests --------------------------------------------------------------

func _test_stat_block() -> void:
	var a := StatBlock.new()
	a.max_hp = 10
	a.attack = 2
	var b := StatBlock.new()
	b.attack = 3
	b.defense = 1
	var sum := a.plus(b)
	check(sum.max_hp == 10 and sum.attack == 5 and sum.defense == 1, "StatBlock.plus adds every stat")
	check(a.attack == 2, "StatBlock.plus does not modify its operands")
	check(b.describe() == "+3 ATK  +1 DEF", "StatBlock.describe: got '%s'" % b.describe())


func _test_combat_rules() -> void:
	check(Combat.mitigate(10, 3) == 7, "defense removes damage")
	check(Combat.mitigate(2, 50) == 1, "a hit always deals at least 1")


func _test_content() -> void:
	check(CONTENT.player != null and CONTENT.dungeon != null, "content db has player and dungeon config")
	check(CONTENT.monsters.size() >= 5, "content db lists monsters")
	var ids := {}
	for monster in CONTENT.monsters:
		check(monster.weapon != null, "%s has a weapon" % monster.id)
		check(monster.stats != null and monster.stats.max_hp > 0, "%s has HP" % monster.id)
		check(not ids.has(monster.id), "duplicate id %s" % monster.id)
		ids[monster.id] = true
	for item in CONTENT.items:
		check(not item.display_name.is_empty(), "%s has a name" % item.id)
		check(not ids.has(item.id), "duplicate id %s" % item.id)
		ids[item.id] = true
	var rng := RandomNumberGenerator.new()
	for depth in range(1, 8):
		check(CONTENT.pick_monster(depth, rng) != null, "a monster can spawn at depth %d" % depth)
		check(CONTENT.pick_item(depth, rng) != null, "an item can spawn at depth %d" % depth)
	check(CONTENT.pick_monster(1, rng).min_depth == 1, "depth filter respected")
	check(CONTENT.sounds != null, "content db has a sound bank")
	for property in CONTENT.sounds.get_property_list():
		if property.type == TYPE_OBJECT and property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			check(CONTENT.sounds.get(property.name) != null, "sound bank: %s is set" % property.name)
	for item in CONTENT.items:
		if item is WeaponDef:
			check(item.attack_sound != null, "%s has an attack sound" % item.id)
		check(item.icon != null, "%s has an icon" % item.id)
	for monster in CONTENT.monsters:
		check(monster.icon != null, "%s has a sprite" % monster.id)


func _test_generation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in 100:
		var map := DungeonGenerator.generate(CONTENT.dungeon, rng)
		check(map.rooms.size() >= 4, "enough rooms (%d)" % map.rooms.size())
		var reachable := _flood(map, map.start_cell)
		for room in map.rooms:
			check(reachable.has(room.get_center()), "room %s reachable" % room)
		check(reachable.has(map.stairs_cell), "stairs reachable")
		check(map.start_cell != map.stairs_cell, "stairs not on start")
		# Border must stay solid so nothing can leave the map.
		for x in map.width:
			check(not map.is_floor(Vector2i(x, 0)) and not map.is_floor(Vector2i(x, map.height - 1)), "closed border")
			break


func _flood(map: DungeonMap, from: Vector2i) -> Dictionary:
	var seen := { from: true }
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + dir
			if map.is_floor(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen


func _test_inventory_and_equipment() -> void:
	var inventory := Inventory.new(2)
	var potion: ItemDef = load("res://data/items/consumables/health_potion.tres")
	check(inventory.add(potion) and inventory.add(potion), "inventory accepts items")
	check(not inventory.add(potion), "inventory refuses items when full")
	check(inventory.grouped().size() == 1 and inventory.grouped()[0].count == 2, "identical items are grouped")

	var equipment := Equipment.new()
	var cap: EquipmentDef = load("res://data/items/armors/leather_cap.tres")
	var helm: EquipmentDef = load("res://data/items/armors/iron_helm.tres")
	check(equipment.equip(cap) == null, "equip into empty slot")
	check(equipment.equip(helm) == cap, "equip returns the replaced item")
	check(equipment.total_bonuses().defense == helm.bonuses.defense, "bonuses come from equipped items")


# --- Gameplay (bot) ----------------------------------------------------------

func _test_gameplay() -> void:
	var game := GAME_SCENE.instantiate()
	add_child(game)
	await _frames(5)
	var world: World = game.world
	var player: Player = game.player
	check(player != null and player.world == world, "player spawned in world")
	check(world.monster_count() > 0, "monsters spawned (%d)" % world.monster_count())
	check(player.get_weapon() != null, "player starts with a weapon")

	await _test_projectiles(world, player)

	var kills := [0]
	var depth_changes := [0]
	Events.monster_killed.connect(func(_m: Monster) -> void: kills[0] += 1)
	Events.depth_changed.connect(func(_d: int) -> void: depth_changes[0] += 1)

	# Every consumable must work without errors.
	player.hp = 10
	for item in CONTENT.items:
		if item is ConsumableDef:
			player.inventory.add(item)
			player.use_item(item)
	check(player.hp > 10, "potions heal")
	await _frames(30)

	# Equip / unequip / drop round trip.
	var bow: WeaponDef = load("res://data/items/weapons/magic_wand.tres")
	check(player.pick_up(bow), "pick up a bow")
	player.use_item(bow)
	check(player.get_weapon() == bow, "bow equipped")
	check(player.inventory.items.size() > 0, "old weapon went to the bag")
	player.unequip(EquipmentDef.Slot.WEAPON)
	check(player.get_weapon() == null, "weapon unequipped")
	player.use_item(load("res://data/items/weapons/katana.tres"))
	check(player.get_weapon() != null, "re-equipped a weapon")
	var count := player.inventory.items.size()
	player.drop_item(bow)
	check(player.inventory.items.size() == count - 1, "dropped item left the bag")
	await _frames(5)

	# Animations: frame-by-frame attack in the aimed direction, weapon in hand synced with the body.
	var rig := player.rig
	check(rig != null and rig.visible, "player has a visible rig")
	player._attack_cooldown = 0.0
	player.attack(Vector2.LEFT)
	check(rig.direction == &"left", "the rig turns toward the attack")
	check(rig.body.animation == &"attack_left", "the body plays attack_left (got %s)" % rig.body.animation)
	check(rig.weapon.visible and rig.weapon.animation == &"attack_left", "the katana is drawn in hand, synced")
	await _frames(40)
	check(not rig.weapon.visible, "the weapon is put away after the attack")
	check(String(rig.body.animation).begins_with("idle") or String(rig.body.animation).begins_with("walk"), "back to idle/walk")
	player._attack_cooldown = 0.0
	player.attack(Vector2.UP)
	check(rig.weapon.get_index() < rig.body.get_index(), "facing up: weapon drawn behind the body")
	await _frames(40)
	var rat := world.spawn_monster(load("res://data/monsters/rat.tres"), player.global_position + Vector2(200, 0))
	await _frames(1)
	check(rat.rig.body.animation.begins_with("idle") or rat.rig.body.animation.begins_with("walk"), "monsters animate")
	rat.attack(Vector2.LEFT)
	check(not rat.rig.weapon.visible, "a bite shows no weapon sprite")
	rat.queue_free()
	var spear: WeaponDef = load("res://data/items/weapons/lance.tres")
	player.inventory.add(spear)
	player.use_item(spear)
	player._attack_cooldown = 0.0
	player.attack(Vector2.RIGHT)
	check(rig.weapon.visible and rig.weapon.animation == &"attack_right", "the lance has baked attack frames")
	player.use_item(load("res://data/items/weapons/katana.tres"))
	await _frames(30)

	# Inventory screen opens, lists items, uses them, pauses, and closes.
	player.inventory.add(load("res://data/items/armors/leather_cap.tres"))
	game.open_inventory()
	await _frames(2)
	check(get_tree().paused, "inventory pauses the game")
	var grid: GridContainer = game.inventory_panel.get_node("%ItemGrid")
	check(grid.get_child_count() > 0, "inventory lists items")
	(grid.get_child(grid.get_child_count() - 1) as Button).pressed.emit()
	(game.inventory_panel.get_node("%UseButton") as Button).pressed.emit()
	check(player.equipment.get_item(EquipmentDef.Slot.HEAD) != null, "equip from the inventory screen")
	game.inventory_panel.close()
	await _frames(2)
	check(not get_tree().paused, "closing the inventory resumes the game")

	# Touch controls feed the same input actions as keyboard and gamepad.
	var screen := get_viewport().get_visible_rect().size
	_touch(0, Vector2(200, screen.y - 200), true)
	_drag(0, Vector2(290, screen.y - 200))
	await _frames(2)
	check(Input.get_vector("move_left", "move_right", "move_up", "move_down").x > 0.5, "joystick drag moves right")
	var attack_button: ActionButton = game.hud.get_node("%AttackButton")
	_touch(1, attack_button.global_position, true)
	await _frames(2)
	check(Input.is_action_pressed("attack"), "attack button presses attack (while moving: multi-touch)")
	_touch(1, attack_button.global_position, false)
	_touch(0, Vector2(290, screen.y - 200), false)
	await _frames(2)
	check(not Input.is_action_pressed("attack"), "attack released")
	check(Input.get_vector("move_left", "move_right", "move_up", "move_down") == Vector2.ZERO, "joystick released")
	var bag: Button = game.hud.get_node("%BagButton")
	_touch(0, bag.get_global_rect().get_center(), true)
	await _frames(1)
	_touch(0, bag.get_global_rect().get_center(), false)
	await _frames(2)
	check(game.inventory_panel.visible, "tapping the bag button opens the inventory")
	game.inventory_panel.close()
	await _frames(2)

	# Play: hunt monsters for a while (god mode so the run lasts).
	player.base_stats.defense = 999
	player.invalidate_stats()
	await _bot_play(game, 60 * 40)
	print("bot: %d kills, level %d, depth %d" % [kills[0], player.level, game.depth])
	check(kills[0] >= 5, "bot killed monsters (%d)" % kills[0])
	check(player.level > 1, "player gained levels")

	# Stairs take you deeper.
	var depth_before: int = game.depth
	player.global_position = world.map.cell_to_world(world.map.stairs_cell)
	await _frames(10)
	check(game.depth == depth_before + 1, "stairs lead to the next depth")
	check(depth_changes[0] >= 1, "depth_changed emitted")
	check(world.monster_count() > 0, "new floor populated")

	# Death and restart.
	player.base_stats.defense = 0
	player.invalidate_stats()
	var hit := HitInfo.new()
	hit.amount = 99999
	player._invulnerable_time = 0.0
	player.take_hit(hit)
	check(player.is_dead, "player can die")
	await get_tree().create_timer(1.5).timeout
	check(game.game_over_panel.visible, "game over screen shown")
	game.start_run()
	await _frames(5)
	check(game.player != player and not game.player.is_dead, "restart creates a fresh player")
	check(game.depth == 1, "restart goes back to depth 1")

	# A second bot run on the fresh character at higher depths, mortal this time.
	# Monsters must be able to hurt a player who just stands there.
	var victim: Player = game.player
	var hp_before := victim.hp
	var skeleton: MonsterDef = load("res://data/monsters/skeleton.tres")
	game.world.spawn_monster(skeleton, victim.global_position + Vector2(40, 0))
	await _frames(60 * 4)
	check(victim.hp < hp_before, "monsters damage the player")

	game.depth = 4
	game._enter_floor()
	await _bot_play(game, 60 * 20)
	print("bot (depth 4, mortal): hp %d/%d, dead=%s" % [game.player.hp, game.player.get_max_hp(), game.player.is_dead])
	game.queue_free()
	await _frames(2)


## Projectiles must stop on walls and hurt enemies.
func _test_projectiles(world: World, player: Player) -> void:
	var map := world.map
	var start := map.world_to_cell(player.global_position)
	# Closest wall in a straight line from the player.
	var best_dir := Vector2i.ZERO
	var best_distance := 999
	for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var distance := 1
		while map.is_floor(start + dir * distance):
			distance += 1
		if distance < best_distance:
			best_distance = distance
			best_dir = dir
	var wall_cell := start + best_dir * best_distance
	var wall_center := map.cell_to_world(wall_cell)

	var spec := ProjectileSpec.new()
	spec.speed = 400.0
	spec.max_distance = 5000.0
	world.fire_projectiles(player, Vector2(best_dir), spec)
	var crossed := false
	for i in 120:
		await get_tree().physics_frame
		for shot in world.get_node("Projectiles").get_children():
			var past: float = ((shot as Node2D).global_position - wall_center).dot(Vector2(best_dir))
			crossed = crossed or past > map.tile_size * 0.5
	check(not crossed, "projectiles stop on walls")
	check(world.get_node("Projectiles").get_child_count() == 0, "projectile removed after hitting a wall")

	# Shoot a monster standing in the open.
	var free_dir := -best_dir
	var target := world.spawn_monster(load("res://data/monsters/slime.tres"), player.global_position + Vector2(free_dir) * 60.0)
	var hp_before := target.hp
	spec.damage = 5
	world.fire_projectiles(player, Vector2(free_dir), spec)
	await _frames(20)
	check(target.hp < hp_before, "projectiles damage enemies")
	target.queue_free()
	await _frames(2)


func _bot_play(game: Node, frames: int) -> void:
	var path_timer := 0
	var path := PackedVector2Array()
	for frame in frames:
		var player: Player = game.player
		var world: World = game.world
		if player.is_dead:
			break
		var target := _nearest_monster(world, player)
		var direction := Vector2.ZERO
		if target:
			var distance := player.global_position.distance_to(target.global_position)
			if world.has_line_of_sight(player.global_position, target.global_position):
				direction = player.global_position.direction_to(target.global_position)
				if distance < 40.0:
					direction = direction.orthogonal() * 0.5  # circle around while fighting
			else:
				path_timer -= 1
				if path_timer <= 0:
					path = world.find_path(player.global_position, target.global_position)
					path_timer = 20
				while path.size() > 0 and player.global_position.distance_to(path[0]) < 10.0:
					path.remove_at(0)
				if path.size() > 0:
					direction = player.global_position.direction_to(path[0])
		_set_move(direction)
		_set_action(&"attack", target != null)
		_set_action(&"skill_%d" % (frame / 30 % 3 + 1), frame % 30 == 0)
		_set_action(&"quick_item", player.hp < player.get_max_hp() / 3 and frame % 20 == 0)
		await get_tree().physics_frame
	_set_move(Vector2.ZERO)
	for action: StringName in [&"attack", &"skill_1", &"skill_2", &"skill_3", &"quick_item"]:
		Input.action_release(action)


func _nearest_monster(world: World, player: Player) -> Actor:
	var best: Actor = null
	var best_distance := INF
	for monster in world.get_hostiles(player.faction):
		var distance := player.global_position.distance_to(monster.global_position)
		if distance < best_distance:
			best = monster
			best_distance = distance
	return best


func _set_move(direction: Vector2) -> void:
	_set_strength(&"move_left", maxf(-direction.x, 0.0))
	_set_strength(&"move_right", maxf(direction.x, 0.0))
	_set_strength(&"move_up", maxf(-direction.y, 0.0))
	_set_strength(&"move_down", maxf(direction.y, 0.0))


func _set_strength(action: StringName, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _set_action(action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)


## Positions are in game (viewport) coordinates; converted to window coordinates like a real screen.
func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = get_viewport().get_final_transform() * at
	event.pressed = pressed
	Input.parse_input_event(event)


func _drag(index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = get_viewport().get_final_transform() * at
	Input.parse_input_event(event)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
