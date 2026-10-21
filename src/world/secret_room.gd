class_name SecretRoom
extends Node2D
## A room hidden behind a cracked wall (its SecretRoomPlan, made by the generator). The crack
## (CrackedWall) stands on the cliff face; when it breaks, the rock crumbles, the passage and the
## room become floor (World.open_cells()), show on the minimap, and the reward appears: one of
## DungeonConfig.secret_rewards, drawn from the floor's seed, or the hidden floor's key
## (HiddenFloorDef) in the acts that hide it.
## Saved with the floor (World.spent_data()): a broken wall stays broken, a looted room stays empty.

enum State { HIDDEN, OPEN, LOOTED }

## Close enough to hear it whisper, in pixels.
const WHISPER_DISTANCE := 150.0

var plan: SecretRoomPlan
var state := State.HIDDEN
## The reward drawn for it (null: none fits), and the key when it holds the key instead.
var reward: SecretRewardDef
var key: ItemDef
var crack: CrackedWall

var _world: World
var _rng := RandomNumberGenerator.new()
var _key_roll := 1.0
var _spawned: Array[Node] = []
var _whisper_in := 2.0
var _check_in := 0.0


## One for each secret room the floor's map plans (World.build_floor()).
static func spawn_all(world: World) -> Array[SecretRoom]:
	var result: Array[SecretRoom] = []
	var config := world.config()
	if config.cracked_wall == null:
		return result
	for i in world.map.secrets.size():
		var room := SecretRoom.new()
		room.name = "SecretRoom%d" % i
		world.add_entity(room)
		room.setup(world, world.map.secrets[i], i)
		result.append(room)
	return result


## What a save keeps: each room's state (and whether it held the key), in the map's order.
static func states(rooms: Array[SecretRoom]) -> Array:
	return rooms.map(func(room: SecretRoom) -> Array: return [room.state, room.key != null])


## A saved floor built again: rooms opened (or looted) stay so.
static func restore(rooms: Array[SecretRoom], saved: Array) -> void:
	for i in mini(rooms.size(), saved.size()):
		var entry: Variant = saved[i]
		if not entry is Array or (entry as Array).size() < 2:
			continue
		var saved_state := int(entry[0])
		if saved_state >= State.OPEN and rooms[i].state == State.HIDDEN:
			rooms[i].open(true, saved_state == State.LOOTED, bool(entry[1]))


func setup(world: World, room_plan: SecretRoomPlan, index: int) -> void:
	_world = world
	plan = room_plan
	position = plan.crack_position(world.map)
	# Its own stream from the floor's seed: the same reward whenever the floor is built.
	_rng.seed = hash("secret-room-%d-%d" % [world.rng.seed, index])
	_key_roll = _rng.randf()
	reward = ContentDB.pick_from(world.config().secret_rewards, world.depth, _rng) as SecretRewardDef
	crack = (load("res://src/entities/prop/cracked_wall.tscn") as PackedScene).instantiate() as CrackedWall
	crack.world = world
	crack.setup(_sized(world.config().cracked_wall, Vector2i(plan.crack.size(), 1) if plan.direction.y != 0 else Vector2i(1, plan.crack.size())))
	crack.facing = -Vector2(plan.direction)
	crack.position = position
	crack.z_index = -1  # on the rock, under whoever walks by
	world.add_entity(crack)
	# (Deferred: a shot breaks it from a physics callback, where the walls can't be rebuilt.)
	crack.broken.connect(func(_prop: Prop) -> void: open.call_deferred())


## The crack's PropDef as wide as the passage.
static func _sized(def: PropDef, footprint: Vector2i) -> PropDef:
	if def.footprint == footprint:
		return def
	var wide := def.duplicate() as PropDef
	wide.footprint = footprint
	return wide


## Breaks through: the passage and the room become floor, the reward appears. `quiet`: a resumed
## floor (no fanfare, not counted again); `looted`: its reward was already taken (`held_key`: it
## was the key, nothing is left).
func open(quiet: bool = false, looted: bool = false, held_key: bool = false) -> void:
	if state != State.HIDDEN:
		return
	state = State.LOOTED if looted else State.OPEN
	if is_instance_valid(crack) and not crack.is_broken:
		crack.queue_free()
	_world.open_cells(plan.cells())
	var revealed: Array[Vector2i] = []
	revealed.append_array(_world.fog.reveal_rect(plan.room.grow(1)))
	revealed.append_array(_world.fog.reveal_rect(plan.passage_rect()))
	_world.cells_changed.emit(revealed)
	FloorPopulator.place_lights(_world, _world.config(), plan.room, _reserved())
	var middle := plan.room.get_center()
	if looted:
		if held_key:
			key = _world.config().hidden_floor.key if _world.config().hidden_floor else null
		elif reward:
			reward.place_spent(_world, middle)
	else:
		key = _world.config().hidden_floor.key_for(_world) if _world.config().hidden_floor else null
		if key and _key_roll < _world.config().hidden_floor.key_chance:
			_spawned = [_world.spawn_item(key, _world.map.cell_to_world(middle))]
		else:
			key = null
			if reward:
				_spawned = reward.place(_world, middle, _rng)
	if quiet:
		return
	var at := plan.crack_position(_world.map)
	var out := -Vector2(plan.direction)  # toward the room it opened from
	Sfx.play_world(_world.config().cracked_wall.break_sound, at)
	Sfx.play_world(Sfx.bank.gate, at, -4.0)
	Events.screen_shake.emit(0.45)
	for i in 3:
		Vfx.dust(_world, at + out * (20.0 + i * 6.0) + out.orthogonal() * randf_range(-14.0, 14.0), 1.6)
	Vfx.burst(_world, Vfx.DEATH_CHUNKS, at + out * 18.0, _world.config().cracked_wall.debris_color, out, 1.4)
	_world.add_debris(at + out * 30.0, _chips(), 1.6, out)
	Vfx.magic(_world, _world.map.cell_to_world(middle), Palette.GOLD)
	if reward and key == null:
		_world.spawn_floating_text(_world.map.cell_to_world(middle) + Vector2(0, -30), tr(reward.display_name), Palette.GOLD)
	Events.log_message(tr("The wall gives way: a hidden room."), Palette.GOLD)
	Events.secret_found.emit(self)


## The cells the room's lights must leave free: where the reward stands.
func _reserved() -> Dictionary:
	var taken := {}
	var middle := plan.room.get_center()
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			taken[middle + Vector2i(dx, dy)] = true
	return taken


func _chips() -> ImpactMaterialDef:
	var chips := ImpactMaterialDef.new()
	var color := Color(_world.config().cracked_wall.debris_color, 1.0)
	chips.debris_colors = PackedColorArray([color, color.darkened(0.3), color.lightened(0.2)])
	chips.debris_count = 14
	return chips


func _process(delta: float) -> void:
	if _world == null or _world.player == null or not is_instance_valid(_world.player):
		return
	match state:
		State.HIDDEN:
			# Now and then, close to it, a breath of air through the rock.
			_whisper_in -= delta
			if _whisper_in <= 0.0:
				_whisper_in = randf_range(4.0, 7.0)
				var whisper := _world.config().secret_whisper
				if whisper and global_position.distance_to(_world.player.global_position) <= WHISPER_DISTANCE:
					Sfx.play_world(whisper, global_position, -14.0)
		State.OPEN:
			_check_in -= delta
			if _check_in <= 0.0:
				_check_in = 0.5
				if is_claimed():
					state = State.LOOTED


## The hero took what it held (the key picked up, the chest opened...).
func is_claimed() -> bool:
	if key:
		return _spawned.all(func(node: Node) -> bool: return not is_instance_valid(node) or node.is_queued_for_deletion())
	return reward == null or reward.is_claimed(_spawned)
