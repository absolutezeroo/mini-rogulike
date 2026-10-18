class_name World
extends Node2D
## Everything that exists on the current floor: map, walls, actors, items, projectiles, effects.
## Also the gateway other systems use to spawn things and query the level.

signal stairs_reached

const MONSTER_SCENE := preload("res://src/entities/monster/monster.tscn")
const PICKUP_SCENE := preload("res://src/entities/pickup/item_pickup.tscn")
const PROJECTILE_SCENE := preload("res://src/entities/projectile/projectile.tscn")
const STAIRS_SCENE := preload("res://src/entities/stairs/stairs.tscn")
const ARENA_SCENE := preload("res://src/world/boss_arena.tscn")

var map: DungeonMap
var theme: DungeonTheme
var player: Player
var depth := 1
var rng := RandomNumberGenerator.new()
## Boss floors only: the arena and its boss (null on normal floors).
var arena: BossArena

var _content: ContentDB
var _astar := AStarGrid2D.new()

@onready var _view: DungeonView = $DungeonView
@onready var _walls: StaticBody2D = $Walls
@onready var _entities: Node2D = $Entities
@onready var _projectiles: Node2D = $Projectiles
@onready var _effects: Node2D = $Effects


# --- Floor lifecycle ---------------------------------------------------------

func build_floor(new_depth: int, content: ContentDB) -> void:
	clear_floor()
	depth = new_depth
	_content = content
	var boss := content.dungeon.boss_for_depth(depth)
	if boss:
		map = DungeonGenerator.generate_arena(content.dungeon, rng)
	else:
		map = DungeonGenerator.generate(content.dungeon, rng)
	theme = content.dungeon.theme_for_depth(depth)
	_view.show_map(map, theme)
	_build_walls()
	_build_pathfinding()
	if boss:
		# No stairs until the boss is dead: the arena spawns them.
		arena = ARENA_SCENE.instantiate() as BossArena
		_entities.add_child(arena)
		arena.setup(self, boss)
	else:
		spawn_stairs(map.stairs_cell)
		FloorPopulator.populate(self, content, depth)


## Removes everything from the floor except the player.
func clear_floor() -> void:
	arena = null
	for layer: Node in [_entities, _projectiles, _effects, _walls]:
		for child in layer.get_children():
			if child != player:
				layer.remove_child(child)
				child.queue_free()


func place_player(new_player: Player) -> void:
	player = new_player
	player.world = self
	if player.get_parent() == null:
		_entities.add_child(player)
	player.global_position = map.cell_to_world(map.start_cell)
	player.camera.reset_smoothing()


# --- Spawning ----------------------------------------------------------------

func spawn_monster(def: MonsterDef, at: Vector2) -> Monster:
	var monster := MONSTER_SCENE.instantiate() as Monster
	monster.world = self
	monster.setup(def, depth, _content.dungeon)
	monster.position = at
	_entities.add_child(monster)
	return monster


func spawn_item(item: ItemDef, at: Vector2, armed: bool = true) -> ItemPickup:
	var pickup := PICKUP_SCENE.instantiate() as ItemPickup
	pickup.setup(item, armed)
	pickup.position = at
	_entities.add_child.call_deferred(pickup)  # may be called from physics callbacks
	return pickup


## Fires a volley. Spread is spread evenly; 360 degrees makes a full ring.
## The shooter's perks can change the volley first (extra projectiles...).
func fire_projectiles(shooter: Actor, direction: Vector2, spec: ProjectileSpec) -> void:
	shooter.perks.modify_projectiles(shooter, spec)
	for i in spec.count:
		var angle := 0.0
		if spec.spread_degrees >= 360.0:
			angle = 360.0 * i / spec.count
		elif spec.count > 1:
			angle = lerpf(-spec.spread_degrees * 0.5, spec.spread_degrees * 0.5, float(i) / (spec.count - 1))
		var shot_direction := direction.rotated(deg_to_rad(angle))
		var projectile := PROJECTILE_SCENE.instantiate() as Projectile
		projectile.setup(shooter, shot_direction, spec)
		projectile.position = shooter.global_position + shot_direction * (shooter.radius * 0.5)
		_projectiles.add_child.call_deferred(projectile)


func spawn_stairs(cell: Vector2i) -> Stairs:
	var stairs := STAIRS_SCENE.instantiate() as Stairs
	if theme:
		stairs.texture = theme.stairs_texture()
	stairs.position = map.cell_to_world(cell)
	stairs.reached.connect(func() -> void: stairs_reached.emit())
	stairs.z_index = -1
	_entities.add_child(stairs)
	return stairs


func spawn_vfx(node: Node2D) -> void:
	_effects.add_child(node)


func spawn_floating_text(at: Vector2, text: String, color: Color) -> void:
	spawn_vfx(FloatingText.create(at, text, color))


# --- Queries -----------------------------------------------------------------

## Living actors that are enemies of `faction`.
func get_hostiles(faction: Actor.Faction) -> Array[Actor]:
	var result: Array[Actor] = []
	if faction == Actor.Faction.PLAYER:
		for node in get_tree().get_nodes_in_group("monsters"):
			var monster := node as Actor
			if monster and not monster.is_dead and monster.is_inside_tree():
				result.append(monster)
	elif player and not player.is_dead:
		result.append(player)
	return result


func has_line_of_sight(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, Layers.WORLD)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Path between two world positions, as a list of cell centres (empty if unreachable).
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := map.world_to_cell(from)
	var goal := map.world_to_cell(to)
	if not map.is_floor(start) or not map.is_floor(goal):
		return PackedVector2Array()
	return _astar.get_point_path(start, goal)


## A walkable point about `distance` away from `center`, in sight of it (or `center` itself).
func find_open_point_near(center: Vector2, distance: float) -> Vector2:
	for attempt in 10:
		var point := center + Vector2.from_angle(rng.randf() * TAU) * distance
		if map.is_floor(map.world_to_cell(point)) and has_line_of_sight(center, point):
			return point
	return center


func monster_count() -> int:
	return get_hostiles(Actor.Faction.PLAYER).size()


# --- Building ----------------------------------------------------------------

## Collision for the walls: one rectangle per horizontal run of wall cells.
func _build_walls() -> void:
	var ts := float(map.tile_size)
	for y in map.height:
		var x := 0
		while x < map.width:
			if not map.is_wall_edge(Vector2i(x, y)):
				x += 1
				continue
			var run_start := x
			while x < map.width and map.is_wall_edge(Vector2i(x, y)):
				x += 1
			var shape := RectangleShape2D.new()
			shape.size = Vector2((x - run_start) * ts, ts)
			var collision := CollisionShape2D.new()
			collision.shape = shape
			collision.position = Vector2((run_start + x) * 0.5 * ts, (y + 0.5) * ts)
			_walls.add_child(collision)


func _build_pathfinding() -> void:
	_astar.region = Rect2i(0, 0, map.width, map.height)
	_astar.cell_size = Vector2(map.tile_size, map.tile_size)
	_astar.offset = Vector2(map.tile_size, map.tile_size) * 0.5
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for y in map.height:
		for x in map.width:
			if not map.is_floor(Vector2i(x, y)):
				_astar.set_point_solid(Vector2i(x, y))

