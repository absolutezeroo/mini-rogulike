class_name TestSuite
extends Node
## Base of the test suites (tests/suites/): checks, waiting, and helpers to set scenes up
## (free cells, clearing monsters, a bot that plays...). Run them with tests/run_tests.tscn.

## Totals of every suite (printed by the runner).
static var checks := 0
static var failures := 0

var CONTENT: ContentDB  # loaded at runtime: preloading would load the whole game at parse time
var GAME_SCENE: PackedScene


func _init() -> void:
	CONTENT = load("res://data/content_db.tres")
	GAME_SCENE = load("res://src/game/game.tscn")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


## Every text under `root` that leaves the font's grid (Fonts): a size not in Fonts.SIZES, or a
## Label's outline other than one font pixel (or none). Empty when all is whole.
func _off_grid_texts(root: Node) -> Array[String]:
	var found: Array[String] = []
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "Control", true, false))
	for node in nodes:
		if not (node is Label or node is Button or node is RichTextLabel):
			continue
		var control := node as Control
		var key := &"normal_font_size" if node is RichTextLabel else &"font_size"
		var font_size := control.get_theme_font_size(key)
		if not Fonts.SIZES.has(font_size):
			found.append("%s: size %d" % [root.get_path_to(node), font_size])
		elif node is Label or node is RichTextLabel:
			var outline := control.get_theme_constant(&"outline_size")
			if outline != 0 and outline != Fonts.outline_size(font_size):
				found.append("%s: outline %d at %d" % [root.get_path_to(node), outline, font_size])
	return found


func _perk(id: String) -> PerkDef:
	for perk in CONTENT.perks:
		if perk.id == StringName(id):
			return perk
	push_error("no perk " + id)
	return null


func _upgrade(id: String) -> UpgradeDef:
	for upgrade in CONTENT.upgrades:
		if upgrade.id == StringName(id):
			return upgrade
	push_error("no upgrade " + id)
	return null


## The floor cell closest to `point` (but not under it) with `margin` cells of open floor all
## around it: no hole, no cracked floor, nothing blocking.
func _open_cell_near(world: World, point: Vector2, margin: int) -> Vector2i:
	var origin := world.map.world_to_cell(point)
	var best := Vector2i(-1, -1)
	var best_distance := INF
	for y in range(margin, world.map.height - margin):
		for x in range(margin, world.map.width - margin):
			var cell := Vector2i(x, y)
			var distance := Vector2(cell - origin).length()
			if distance < 3.0 or distance >= best_distance:
				continue
			var ok := true
			for dy in range(-margin, margin + 1):
				for dx in range(-margin, margin + 1):
					var near := cell + Vector2i(dx, dy)
					if not world.is_solid_ground(world.map.cell_to_world(near)) or world.nav.is_blocked(near):
						ok = false
						break
				if not ok:
					break
			if ok:
				best = cell
				best_distance = distance
	check(best != Vector2i(-1, -1), "found open floor for a test")
	return best


func _solid_point_in(world: World, rect: Rect2i) -> Vector2:
	for attempt in 50:
		var cell := world.map.random_cell_in(rect, world.rng, 0)
		var point := world.map.cell_to_world(cell)
		if world.is_solid_ground(point) and not world.nav.is_blocked(cell):
			return point
	return world.map.cell_to_world(rect.get_center())


func _gold_on_floor(world: World) -> int:
	var total := 0
	for node in world.get_node("Entities").get_children():
		if node is GoldPickup and not node.is_queued_for_deletion():
			total += (node as GoldPickup).amount
	return total


func _open_cell_in(world: World, room: Rect2i) -> Vector2i:
	for y in range(room.position.y + 1, room.end.y - 1):
		for x in range(room.position.x + 1, room.end.x - 1):
			var cell := Vector2i(x, y)
			if world.is_solid_ground(world.map.cell_to_world(cell)) and not world.nav.is_blocked(cell):
				return cell
	return room.get_center()


## Removes the floor's monsters (they wander in and spoil a test that needs the hero alone).
func _clear_monsters(world: World) -> void:
	for other in world.get_hostiles(Actor.Faction.PLAYER):
		if is_instance_valid(other):
			other.queue_free()
	await _frames(1)


func _count_monsters(world: World, id: StringName) -> int:
	var count := 0
	for m in world.get_hostiles(Actor.Faction.PLAYER):
		if m is Monster and is_instance_valid(m) and (m as Monster).def.id == id:
			count += 1
	return count


func _count_footprints(world: World) -> int:
	return world.get_tree().get_nodes_in_group(&"footprints").size()


func _bot_play(game: Game, frames: int) -> void:
	var path_timer := 0
	var path := PackedVector2Array()
	var unreachable: Array[Actor] = []  # no path to them (across water...): hunt others
	var chased: Actor = null
	var chase_frames := 0
	for frame in frames:
		var player: Player = game.player
		var world: World = game.world
		if player.is_dead:
			break
		if game.perk_panel.visible:
			# A perk choice: take the first card, like a player tapping it.
			await get_tree().create_timer(0.2, true).timeout
			game.perk_panel.choose(0)
			await get_tree().physics_frame
			continue
		if game.pending_offers() > 0 and not game.is_menu_open() and await _tap_offers(game):
			continue  # level ups wait behind the perk button: tapped, like a player
		var target := _nearest_monster(world, player, unreachable)
		# Chasing the same one for 10 s without killing it: out of reach somehow, hunt another.
		if target == chased:
			chase_frames += 1
			if chase_frames > 600 and target:
				unreachable.append(target)
				chase_frames = 0
		else:
			chased = target
			chase_frames = 0
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
					if path.is_empty():
						unreachable.append(target)
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


func _nearest_monster(world: World, player: Player, skip: Array[Actor] = []) -> Actor:
	var best: Actor = null
	var best_distance := INF
	for monster in world.get_hostiles(player.faction):
		if skip.has(monster):
			continue
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


## Taps the HUD's Interact button like a finger. False if it isn't showing (nothing in reach).
func _tap_interact(game: Game) -> bool:
	await _frames(2)  # (it follows what the hero stands by, each physics frame)
	var button := game.hud.get_node("%InteractButton") as InteractButton
	if not button.is_visible_in_tree():
		return false
	_touch(7, button.global_position, true)
	await _frames(2)
	_touch(7, button.global_position, false)
	await _frames(2)
	return true


## Taps the HUD's perk button (choices waiting) like a finger. False if it isn't showing.
func _tap_offers(game: Game) -> bool:
	var button := game.hud.get_node("%OffersButton") as OffersButton
	if not button.is_visible_in_tree():
		return false
	var at := button.get_global_rect().get_center()
	_touch(7, at, true)
	await _frames(1)
	_touch(7, at, false)
	await _frames(2)
	return true


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


# --- The Threshold (second lives) --------------------------------------------

## A killing blow on the hero, struck by `source` (null: the dungeon).
func _killing_blow(player: Player, source: Actor = null) -> void:
	player._invulnerable_time = 0.0
	var blow := HitInfo.new()
	blow.amount = 99999
	blow.source = source
	player.take_hit(blow)


## Waits until the trial of the Threshold is on (the veil lifted). False if it never came.
func _until_trial(game: Game, seconds: float = 4.0) -> bool:
	for i in int(seconds * 60.0):
		if game.threshold.is_fighting():
			return true
		await _frames(1)
	return game.threshold.is_fighting()


## Waits until the hero is home from the Threshold (won or lost). False if he never came back.
func _until_home(game: Game, seconds: float = 4.0) -> bool:
	for i in int(seconds * 60.0):
		if not game.threshold.is_open():
			return true
		await _frames(1)
	return not game.threshold.is_open()


## Slays every spectre as it rises until the trial is won, then waits for the hero to be home.
## (He can't be hurt meanwhile: the trial is the test, not the fight.)
func _win_trial(game: Game) -> bool:
	var threshold := game.threshold
	var player := game.player
	var was_invincible := player.invincible
	player.invincible = true
	if not threshold.is_fighting():
		await _until_trial(game)
	for i in 60 * 20:
		if not threshold.is_fighting():
			break
		for spectre in threshold.limbo.get_hostiles(Actor.Faction.PLAYER):
			spectre.die(player)
		await _frames(1)
	player.invincible = was_invincible
	return await _until_home(game)
