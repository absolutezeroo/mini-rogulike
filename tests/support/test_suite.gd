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
## around it: no hole, no cracked floor, nothing blocking. A cramped random floor may have no
## such spot: then the widest margin it has (down to 1), rather than no cell at all. `away_from`:
## points it keeps `away` px from too (bodies standing there: the nav grid doesn't know them).
func _open_cell_near(world: World, point: Vector2, margin: int, away_from: Array[Vector2] = [], away: float = 0.0) -> Vector2i:
	for wanted in range(margin, 0, -1):
		var cell := _open_cell_with_margin(world, point, wanted, away_from, away)
		if cell != Vector2i(-1, -1):
			return cell
	check(false, "found open floor for a test")
	return Vector2i(-1, -1)


func _open_cell_with_margin(world: World, point: Vector2, margin: int, away_from: Array[Vector2] = [], away: float = 0.0) -> Vector2i:
	var origin := world.map.world_to_cell(point)
	var best := Vector2i(-1, -1)
	var best_distance := INF
	for y in range(margin, world.map.height - margin):
		for x in range(margin, world.map.width - margin):
			var cell := Vector2i(x, y)
			var distance := Vector2(cell - origin).length()
			if distance < 3.0 or distance >= best_distance:
				continue
			var at := world.map.cell_to_world(cell)
			if away_from.any(func(other: Vector2) -> bool: return other.distance_to(at) < away):
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
	return best


## A body of `radius` fits at `at`: nothing on the world's physics layer overlaps it there (a
## wall's or a prop's shape may reach into a free cell). One put down overlapping one is stuck in it.
func _body_fits(world: World, at: Vector2, radius: float) -> bool:
	var shape := CircleShape2D.new()
	shape.radius = radius + 1.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, at)
	query.collision_mask = Layers.WORLD
	return world.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## Nothing on the world's physics layer (walls, and the props a line of sight goes past) between
## `from` and `to`: what dashes and shots stop at.
func _clear_ray(world: World, from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, Layers.WORLD)
	return world.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## A lane for a test that moves something in a straight line (a dash, a charge, a shot): the free
## floor point closest to `near` from which `length` px along one of the four ways is solid ground
## all along (no hole, nothing blocking a cell) and clear of walls and props. [point, direction],
## or [] when the floor has none (then a failed check says so).
func _clear_lane(world: World, near: Vector2, length: float) -> Array:
	var origin := world.map.world_to_cell(near)
	var cells: Array[Vector2i] = []
	for y in range(origin.y - 20, origin.y + 21):
		for x in range(origin.x - 20, origin.x + 21):
			var cell := Vector2i(x, y)
			if world.map.in_bounds(cell) and world.is_free_cell(cell) and world.is_solid_ground(world.map.cell_to_world(cell)):
				cells.append(cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - origin).length_squared() < (b - origin).length_squared())
	for cell in cells:
		var from := world.map.cell_to_world(cell)
		for dir: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
			var whole := true
			for step in range(0, int(length) + 1, 8):
				var point := from + dir * step
				if not world.is_solid_ground(point) or world.nav.is_blocked(world.map.world_to_cell(point)):
					whole = false
					break
			if whole and _clear_ray(world, from, from + dir * length):
				return [from, dir]
	check(false, "found a clear lane of %d px for a test" % roundi(length))
	return []


## A free floor point `near`..`far` cells from `from` (the hero), where nothing acts on a body by
## itself: no heat source (fire, frost, water) reaching it, no quicksand or trap, no monster near.
## For a test that watches a body's statuses or looks: the floor must not add its own.
func _quiet_point(world: World, from: Vector2, near: int = 6, far: int = 14) -> Vector2:
	var tile := float(world.map.tile_size)
	for point in _free_points_away(world, from, near, far, 40):
		var quiet := true
		for node in get_tree().get_nodes_in_group("heat_sources"):
			var source := node as HeatSource
			if source.area.grow(source.def.reach + tile * 3.0).has_point(point - source.global_position):
				quiet = false
		for group: String in ["quicksand", "traps", "crumbling_floors"]:
			for node in get_tree().get_nodes_in_group(group):
				if (node as Node2D).global_position.distance_to(point) < tile * 5.0:
					quiet = false
		for monster in world.get_hostiles(Actor.Faction.PLAYER):
			if monster.global_position.distance_to(point) < tile * 6.0:
				quiet = false
		if quiet:
			return point
	check(false, "found a quiet spot for a test")
	return world.find_open_point_near(from, near * tile)


## The free floor point nearest to `near` with no breakable prop within `radius` (a blast there
## would break one: the floor would change). `near` itself when none is found.
func _point_without_props(world: World, near: Vector2, radius: float) -> Vector2:
	var origin := world.map.world_to_cell(near)
	var props := world.get_breakable_props()
	var best := near
	var best_distance := INF
	for y in range(origin.y - 20, origin.y + 21):
		for x in range(origin.x - 20, origin.x + 21):
			var cell := Vector2i(x, y)
			var distance := Vector2(cell - origin).length()
			if distance >= best_distance or not world.map.in_bounds(cell) or not world.is_free_cell(cell):
				continue
			var point := world.map.cell_to_world(cell)
			if props.all(func(prop: Prop) -> bool: return prop.global_position.distance_to(point) > radius + Prop.SIZE):
				best = point
				best_distance = distance
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


## `actor` at rest in the middle of a free cell (the nearest): no dash, no knockback, no key held,
## nothing to push him out of. For a test that compares where he stands before and after (a step
## he was still sliding, or a wall he overlapped, would move him in between).
func _stand_still(world: World, actor: Actor) -> void:
	actor.global_position = world.nearest_free_point(actor.global_position)
	_set_move(Vector2.ZERO)
	actor._dash_time = 0.0
	actor._knockback = Vector2.ZERO
	actor.velocity = Vector2.ZERO
	await _frames(2)


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


## What stands on a floor: its actors, props, chests, stairs, gold and loot... Not the passing
## effects among them (World.spawn_vfx() puts standing dust, sparks and columns of light there,
## and they come and go by themselves), nor what is on its way out (the bodies of monsters slain
## a moment ago go when their death has played). `loot` off: no gold nor items either (when a
## gift may fall). Instance id -> what it is (named now: it may be freed by the time it is missed).
func _floor_things(world: World, loot: bool = true) -> Dictionary:
	var found := {}
	for node in world.get_node("Entities").get_children():
		if Vfx.is_cosmetic(node) or node.is_queued_for_deletion() or (node is Actor and (node as Actor).is_dead):
			continue
		if not loot and (node is GoldPickup or node is ItemPickup):
			continue
		var script := node.get_script() as Script
		found[node.get_instance_id()] = "%s (%s)" % [node.name, script.get_global_name() if script and script.get_global_name() != &"" else node.get_class()]
	return found


## What came and went between two _floor_things(): "" when nothing did.
func _things_diff(before: Dictionary, after: Dictionary) -> String:
	var gone := before.keys().filter(func(id: int) -> bool: return not after.has(id)).map(func(id: int) -> String: return before[id])
	var came := after.keys().filter(func(id: int) -> bool: return not before.has(id)).map(func(id: int) -> String: return after[id])
	if gone.is_empty() and came.is_empty():
		return ""
	return "(gone: %s; came: %s)" % [", ".join(gone), ", ".join(came)]


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
		var world: World = player.world  # (his floor, or the Deeps he fell into: he fights there)
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
		# Taps (holding would charge the weapon's charged attack): a frame down, a frame up.
		_set_action(&"attack", target != null and frame % 2 == 0)
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
	# A finger: the touch controls are out (a key pressed before, a "tap" sent as Space, put
	# them away for the action bar).
	InputDevice.use(InputDevice.Kind.TOUCH)
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


## Waits `count` physics steps. One a frame with --fixed-fps 60: 1/60 s of real time each, hit
## stop or not (a hit stop or a slow motion scales the steps' delta, not their number: the world
## moves less in them).
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


## Holes dug by the tests ([world, cell]), filled again by _fill_holes() (a hole left behind would
## take the hero into the Deeps in a later test).
var _dug: Array = []


## A hole by the hero and a walk into it: he stands on safe ground two cells away first. Returns
## where he stood (where a climb out puts him back). Nothing may push him off the hole before he
## drops: no one stands by it (put down on the hole against a body, he would be shoved out of
## it), and nothing can strike him until he lands (a blow's push, or its damage added to the
## fall's). The fall's own cost still lands: Player.take_fall() lifts that first.
func _walk_into_hole(world: World, player: Player, margin: int = 3) -> Vector2:
	var others: Array[Vector2] = []
	for actor in world.get_actors():
		if actor != player:
			others.append(actor.global_position)
	var hole := _open_cell_near(world, player.global_position, margin, others, world.map.tile_size * 4.0)
	world.add_pit(hole, load("res://data/hazards/pit.tres"))
	_dug.append([world, hole])
	var safe := world.map.cell_to_world(hole + Vector2i.LEFT * 2)
	player.global_position = safe
	player._invulnerable_time = 10.0
	await _stand_still(world, player)
	player._invulnerable_time = 10.0
	player.global_position = world.map.cell_to_world(hole)
	return safe


## Why a walk into a hole at `hole_at` didn't take the hero down (for a failed check's message).
func _fall_state(game: Game, hole_at: Vector2) -> String:
	var player := game.player
	var world := player.world
	return "abyss %s, falling %s, dead %s, paused %s, menu %s, his world the floor %s, pit there %s, %d px from it, at %s" % [
		Abyss.State.keys()[game.abyss.state], player.is_falling, player.is_dead, get_tree().paused, game.is_menu_open(),
		world == game.world, world.pit_under(hole_at) != null, roundi(player.global_position.distance_to(hole_at)), player.global_position]


## Waits until the hero is down in the Deeps (the veil lifted). False if he never got there.
func _until_deeps(game: Game, seconds: float = 4.0) -> bool:
	for i in int(seconds * 60.0):
		if game.abyss.is_searching():
			return true
		await _frames(1)
	return game.abyss.is_searching()


## Waits until the hero is back up from the Deeps. False if he never came back.
func _until_out_of_deeps(game: Game, seconds: float = 4.0) -> bool:
	for i in int(seconds * 60.0):
		if not game.abyss.is_open():
			return true
		await _frames(1)
	return not game.abyss.is_open()


## The hero steps into the Dawn Breach and comes back up. False if he never came back.
func _escape_deeps(game: Game) -> bool:
	var depths := game.abyss.depths
	if depths == null or depths.door == null:
		return false
	game.player.global_position = depths.door.global_position
	return await _until_out_of_deeps(game)


## Up to `count` free floor points between `near` and `far` cells from `from`, spread apart.
func _free_points_away(world: World, from: Vector2, near: int, far: int, count: int) -> Array[Vector2]:
	var origin := world.map.world_to_cell(from)
	var found: Array[Vector2] = []
	for y in range(origin.y - far, origin.y + far + 1):
		for x in range(origin.x - far, origin.x + far + 1):
			var cell := Vector2i(x, y)
			var distance := Vector2(cell - origin).length()
			if distance < near or distance > far or not world.map.in_bounds(cell) or not world.is_free_cell(cell):
				continue
			var point := world.map.cell_to_world(cell)
			if found.all(func(other: Vector2) -> bool: return other.distance_to(point) > 128.0):
				found.append(point)
				if found.size() >= count:
					return found
	return found


## Fills the holes the tests dug (and `more` cells of `world`), as solid floor again.
func _fill_holes(world: World = null, more: Array[Vector2i] = []) -> void:
	for cell in more:
		_dug.append([world, cell])
	for dug: Array in _dug:
		if not is_instance_valid(dug[0]):
			continue  # (the Deeps it was dug in are gone)
		var where := dug[0] as World
		if where.map == null:
			continue
		var cell: Vector2i = dug[1]
		where._pits._pits.erase(cell)
		where._pits.queue_redraw()
		where.set_cell_blocked(cell, false)
	_dug.clear()
