class_name PactRoom
extends AmbushRoom
## A pact door: a dead-end room sealed behind a marked door (crimson spikes, a stele in the
## doorway, a sigil of blood and gold on the floor, candles inside). Walking up to it shows the
## pact (PactDef: its rule, its reward, its cost; PactPanel). Swearing it lowers the stele and
## opens the door; walking in seals it and the waves come, as in an ambush (AmbushRoom).
## The rule (a copy of PactDef.rule) is watched until the last foe falls: kept, a choice of
## relics (the Game queues it on Events.pact_ended); broken, part of the hero's max Health is
## lost for the rest of the run at once, and the fight goes on until the room opens.
## One per floor at most, never on the first floor nor a boss floor (DungeonConfig > Pacts);
## the room is picked so that sealing it cuts nothing else off (find_room()).

enum Outcome { NONE, KEPT, BROKEN, SPENT }

## The pact opens from this close to the door's middle, and again only after walking away.
const OPEN_DISTANCE := 60.0
const REARM_DISTANCE := 110.0
## The door is noticed (and drawn on the minimap) from this far, in sight.
const SEE_DISTANCE := 300.0
const CRIMSON := Color(0.86, 0.16, 0.2)
const SIGIL_GOLD := Color(1.0, 0.8, 0.38)
const ALTAR: Texture2D = preload("res://assets/props/altar.png")
const RINGS: Texture2D = preload("res://assets/fx/magic_circle.png")

var def: PactDef
## Sworn (the door opened for the hero). Stays true once the fight is over.
var accepted := false
var outcome := Outcome.NONE
## The hero has seen the door (it shows on the minimap).
var seen := false
## The rule being watched (a copy of def.rule), from the moment the door seals.
var rule: PactRule
## Max Health the broken pact took.
var hp_lost := 0
## The room's opening (cells just outside it), its middle cell and the way out of the room.
var door_cells: Array[Vector2i] = []
var door_cell := Vector2i.ZERO
var outward := Vector2i.DOWN

var _armed := true
var _time := 0.0
var _see_timer := 0.0
## 0: the stele stands in the doorway; 1: it has sunk into the floor.
var _sink := 0.0
var _altar: Node2D
var _sigil: Node2D
var _glow: LightSource


# --- Choosing the room ------------------------------------------------------------

## A generator of its own for the pact (seeded from the floor's): rolling for it leaves the rest
## of the floor as it was, and the same seed (a daily run) gives the same pact.
static func floor_rng(rng: RandomNumberGenerator) -> RandomNumberGenerator:
	var own := RandomNumberGenerator.new()
	own.seed = hash("%d-pact" % rng.seed)
	return own


## The pact of this floor, if it gets one: { "room": index in map.rooms, "pact": PactDef },
## or empty. Never on the first floor nor a boss floor; `excluded`: rooms already given away.
static func plan(world: World, config: DungeonConfig, depth: int, excluded: Array[int]) -> Dictionary:
	if depth <= 1 or config.boss_for_depth(depth) != null or config.pacts.is_empty():
		return {}
	var rng := floor_rng(world.rng)
	if rng.randf() >= config.pact_chance:
		return {}
	var pact := ContentDB.pick_from(config.pacts, depth, rng) as PactDef
	if pact == null or pact.rule == null:
		return {}
	var index := find_room(world.map, rng, excluded, config.corridor_width + 3)
	return { "room": index, "pact": pact } if index >= 0 else {}


## A room that can be sealed without cutting anything off: not the first, no stairs in or by
## it, one opening on one side (at most `widest` cells) and the rest of the floor still joined
## without it. -1 if none.
static func find_room(map: DungeonMap, rng: RandomNumberGenerator, excluded: Array[int], widest: int) -> int:
	var order: Array = range(1, map.rooms.size())
	RandomUtils.shuffle(order, rng)
	var reachable := -1
	for i: int in order:
		var room := map.rooms[i]
		if excluded.has(i) or room.grow(1).has_point(map.start_cell) \
				or map.exit_cells().any(func(c: Vector2i) -> bool: return room.grow(1).has_point(c)):
			continue
		var door := door_of(map, room)
		if door.is_empty() or door.size() > widest or not _one_side(room, door):
			continue
		if reachable < 0:
			reachable = _flood(map, Rect2i(), []).size()
		var blocked := 0
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				if map.is_floor(Vector2i(x, y)):
					blocked += 1
		# Sealed (the room and its opening), the rest of the floor must stay one piece.
		if _flood(map, room, door).size() == reachable - blocked - door.size():
			return i
	return -1


## The floor cells just outside `room`: its openings.
static func door_of(map: DungeonMap, room: Rect2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var ring := room.grow(1)
	for y in range(ring.position.y, ring.end.y):
		for x in range(ring.position.x, ring.end.x):
			var cell := Vector2i(x, y)
			if not room.has_point(cell) and map.is_floor(cell):
				cells.append(cell)
	return cells


## All the cells on one side of the room, in one unbroken row (a single door).
static func _one_side(room: Rect2i, door: Array[Vector2i]) -> bool:
	var first := door[0]
	var vertical := first.x == room.position.x - 1 or first.x == room.end.x
	var horizontal := first.y == room.position.y - 1 or first.y == room.end.y
	if vertical == horizontal:
		return false  # a corner
	var along: Array[int] = []
	for cell in door:
		if (vertical and cell.x != first.x) or (horizontal and cell.y != first.y):
			return false
		along.append(cell.y if vertical else cell.x)
	along.sort()
	return along[-1] - along[0] == along.size() - 1


## The floor cells reachable from the start without entering `room` or `door`.
static func _flood(map: DungeonMap, room: Rect2i, door: Array[Vector2i]) -> Dictionary:
	var seen_cells := {}
	var queue: Array[Vector2i] = [map.start_cell]
	seen_cells[map.start_cell] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + step
			if seen_cells.has(next) or not map.is_floor(next) or room.has_point(next) or door.has(next):
				continue
			seen_cells[next] = true
			queue.append(next)
	return seen_cells


# --- Setting up -------------------------------------------------------------------

## The door seals at once; candles (`light`) light it from inside when there is room for them.
func setup_pact(world: World, pact_room: Rect2i, pact: PactDef, light: PropDef, taken: Dictionary) -> void:
	setup(world, pact_room)
	def = pact
	y_sort_enabled = true  # the stele stands among the actors
	door_cells = _gates.get_cells()
	if door_cells.is_empty():
		door_cells = [room.get_center()]
	door_cell = door_cells[door_cells.size() / 2]
	var first := door_cells[0]
	if first.y == room.position.y - 1:
		outward = Vector2i.UP
	elif first.y == room.end.y:
		outward = Vector2i.DOWN
	elif first.x == room.position.x - 1:
		outward = Vector2i.LEFT
	else:
		outward = Vector2i.RIGHT
	_gates.close(true)
	_gates.modulate = Color(1.0, 0.5, 0.45)  # crimson spikes
	var ts := float(world.map.tile_size)
	_sigil = Node2D.new()
	_sigil.name = "Sigil"
	_sigil.z_index = -1  # on the floor, under whoever walks on it
	_sigil.position = front()
	_sigil.add_to_group("pact_doors")
	_sigil.draw.connect(_draw_sigil)
	add_child(_sigil)
	_altar = Node2D.new()
	_altar.name = "Stele"
	_altar.position = world.map.cell_to_world(door_cell) + Vector2(0, ts * 0.3)
	_altar.draw.connect(_draw_altar)
	add_child(_altar)
	_glow = LightSource.new()
	_glow.color = Color(1.0, 0.4, 0.32)
	_glow.level = 11
	_glow.position = world.map.cell_to_world(door_cell)
	add_child(_glow)
	if light:
		_place_candles(light, taken)


## Where the hero stands to read the pact: on the floor just outside the door's middle.
func front() -> Vector2:
	var map := _world.map
	var outside := door_cell + outward
	var middle := map.cell_to_world(door_cell)
	return map.cell_to_world(outside) if map.is_floor(outside) else middle + Vector2(outward) * map.tile_size * 0.6


## Candles on the two floor cells inside the room on either side of the door.
func _place_candles(light: PropDef, taken: Dictionary) -> void:
	var along := Vector2i(absi(outward.y), absi(outward.x))
	var ends: Array[Vector2i] = [door_cells[0] - along, door_cells[-1] + along]
	for end in ends:
		var cell := end - outward  # one step into the room
		if room.has_point(cell) and not taken.has(cell) and _world.is_free_cell(cell):
			_world.spawn_prop(light, cell)
			taken[cell] = true


# --- The pact -----------------------------------------------------------------------

## Not sworn yet nor spent: it can still be offered.
func is_open_offer() -> bool:
	return not accepted and outcome == Outcome.NONE


## The hero swore the pact: the stele sinks and the door opens. The fight begins inside.
func accept() -> void:
	if not is_open_offer():
		return
	accepted = true
	_gates.open()
	create_tween().tween_property(self, "_sink", 1.0, 0.8).set_trans(Tween.TRANS_SINE)
	Vfx.dust(_world, _world.map.cell_to_world(door_cell), 1.4)
	Events.screen_shake.emit(0.25)
	Events.log_message(tr("The pact is sworn. Walk in: the door seals behind you."), def.color)


## For a save: 1 once sworn (a resumed run never offers it again), 0 before.
func save_code() -> int:
	return 1 if accepted else 0


## A resumed run, on a floor where the pact was already sworn: the door stands open, the room
## empty; no fight, no reward, no cost (a broken pact's cost is already in the hero's save).
func set_spent() -> void:
	accepted = true
	outcome = Outcome.SPENT
	state = State.CLEARED
	_sink = 1.0
	_gates.open(true)
	_glow.level = 6


func start() -> void:
	if state != State.WAITING:
		return
	_begin_fight()
	rule = def.rule.duplicate() as PactRule
	rule.broken.connect(_on_rule_broken)
	rule.begin(_world.player)
	Events.pact_started.emit(self)


func _wants_start() -> bool:
	return accepted and outcome == Outcome.NONE and super._wants_start()


func _wave_count() -> int:
	return def.waves


func _wave_size() -> int:
	return def.foes_per_wave(_world.depth)


func _spawns_elite() -> bool:
	if def.elite_share > 0.0:
		return _world.rng.randf() < def.elite_share
	return super._spawns_elite()


func _on_rule_broken() -> void:
	if outcome != Outcome.NONE:
		return
	outcome = Outcome.BROKEN
	var player := _world.player
	if player and not player.is_dead:
		hp_lost = def.max_hp_lost(player)
		player.base_stats.max_hp -= hp_lost
		player.invalidate_stats()
		Vfx.burst(_world, Vfx.DEATH_CHUNKS, player.global_position + Vector2(0, -10), Palette.BLOOD)
		_world.spawn_floating_text(player.head_position(), tr("-%d max Health") % hp_lost, Palette.DANGER)
	Sfx.play_ui(Sfx.bank.boss_roar, -8.0)  # the Well takes its due
	Events.screen_shake.emit(0.4)
	Events.log_message(tr("The pact is broken: %d max Health lost for the rest of the run.") % hp_lost, Palette.DANGER)
	Events.pact_broken.emit(self)


## The last foe fell: the door opens; a kept pact pays in relics (the Game offers them).
func _finish() -> void:
	state = State.CLEARED
	_gates.open()
	if rule:
		rule.finish()
	if outcome == Outcome.NONE:
		outcome = Outcome.KEPT
		var at := _world.map.cell_to_world(_reward_cell())
		Vfx.magic(_world, at, SIGIL_GOLD)
		Vfx.burst(_world, Vfx.SPARKLES, at + Vector2(0, -16), def.color, Vector2.UP, 1.6)
		_world.flash_light(at, SIGIL_GOLD, 320.0)
		Events.screen_shake.emit(0.35)
		Sfx.play_ui(Sfx.bank.boss_defeated)
		Events.log_message(tr("The pact is kept. A relic answers the oath."), Palette.GOLD)
	else:
		Events.log_message(tr("The last foe falls. The door opens, and the room keeps its relic."), Palette.DANGER)
	_glow.level = 6
	Events.pact_ended.emit(self)


# --- Each frame -----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_time += delta
	if _sigil:
		_sigil.queue_redraw()
	if _altar and _sink < 1.0:
		_altar.queue_redraw()
	var player := _world.player
	if player == null or player.is_dead:
		return
	if not seen:
		_see_timer -= delta
		if _see_timer <= 0.0:
			_see_timer = 0.25
			_look_for(player)
	if is_open_offer():
		var distance := player.global_position.distance_to(_world.map.cell_to_world(door_cell))
		if _armed and distance <= OPEN_DISTANCE:
			_armed = false
			Events.pact_requested.emit(self)
		elif distance >= REARM_DISTANCE:
			_armed = true
		return
	super._physics_process(delta)
	if state == State.FIGHTING and rule:
		rule.tick(delta)


## The hero sees the door: the room and its door go on the minimap.
func _look_for(player: Player) -> void:
	var at := front()
	if player.global_position.distance_to(at) > SEE_DISTANCE or not _world.has_line_of_sight(player.global_position, at):
		return
	seen = true
	var revealed := _world.fog.reveal_rect(room.grow(1))
	if not revealed.is_empty():
		_world.cells_changed.emit(revealed)


# --- Look -------------------------------------------------------------------------

## The sigil on the floor before the door: a crimson ring, a gold one and a seven-pointed star,
## slowly turning; dim once sworn, gold once kept, ash once broken.
func _draw_sigil() -> void:
	var color := CRIMSON
	var gold := SIGIL_GOLD
	var strength := 0.75 + 0.25 * sin(_time * 2.4)
	match outcome:
		Outcome.KEPT:
			color = SIGIL_GOLD
			strength = 0.8
		Outcome.BROKEN, Outcome.SPENT:
			color = Color(0.35, 0.3, 0.32)
			gold = Color(0.5, 0.45, 0.42)
			strength = 0.5
		_:
			if accepted:
				strength = 0.55 + 0.15 * sin(_time * 6.0)
	_sigil.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.6))
	_sigil.draw_circle(Vector2.ZERO, 34.0, Color(color, 0.18 * strength))
	_sigil.draw_texture_rect_region(RINGS, Rect2(-36, -36, 72, 72), Rect2(32, 0, 32, 32), Color(color, 0.9 * strength))
	_sigil.draw_texture_rect_region(RINGS, Rect2(-24, -24, 48, 48), Rect2(96, 0, 32, 32), Color(gold, strength))
	var points := PackedVector2Array()
	var turn := _time * 0.35
	for i in 8:
		points.append(Vector2.from_angle(turn + TAU * float(i * 3 % 7) / 7.0 - PI / 2.0) * 21.0)
	_sigil.draw_polyline(points, Color(gold, 0.85 * strength), 2.0)
	_sigil.draw_set_transform(Vector2.ZERO)


## The stele in the doorway, sinking once the pact is sworn; a crimson glow breathes around it
## while the pact waits.
func _draw_altar() -> void:
	if _sink >= 1.0:
		return
	var fade := 1.0 - _sink
	var drop := _sink * 30.0
	if is_open_offer():
		var glow := 0.7 + 0.3 * sin(_time * 3.0)
		_altar.draw_circle(Vector2(0, -16), 26.0, Color(CRIMSON, 0.22 * glow))
		_altar.draw_circle(Vector2(0, -16), 16.0, Color(CRIMSON.lightened(0.2), 0.25 * glow))
	_altar.draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.35))
	_altar.draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.4 * fade))
	_altar.draw_set_transform(Vector2.ZERO)
	_altar.draw_texture_rect(ALTAR, Rect2(-20, -38 + drop, 40, 40), false, Color(0.8, 0.42, 0.42, fade))
	if is_open_offer():
		# A gold glint on the stele's face.
		var glint := 0.6 + 0.4 * sin(_time * 4.0)
		_altar.draw_circle(Vector2(0, -24), 3.0, Color(SIGIL_GOLD, glint))
