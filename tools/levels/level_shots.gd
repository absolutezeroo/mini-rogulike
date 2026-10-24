extends Node
## Screenshots of the floors' identity (a tool: not exported).
## xvfb-run -a godot --rendering-driver opengl3 --resolution WxH --fixed-fps 60 res://tools/levels/level_shots.tscn -- <outdir> <tag> <plan>
## <plan>: comma-separated biome:shape[:set][:map] (shape = a file of data/biomes/shapes/ or,
## with :set, of data/biomes/set_pieces/; :map adds the whole floor on the big map), or
## biome:map (the big map of a floor of the biome), or biome:ceiling (the hero under the ceiling,
## then a little way off).

var out := ""
var tag := ""
var game: Game


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	tag = args[1]
	Profile.save_path = ""
	Profile.reset()
	Profile.seen_intro = true
	Settings.path = ""
	Settings.tutorial_hints = false
	Settings.boss_stories = Settings.STORIES_OFF
	Settings.language = "fr"
	Settings.apply()
	RunSave.path = "user://probe_level_run.json"
	RunSave.erase()
	Sfx.enabled = false
	DirAccess.make_dir_recursive_absolute(out)
	InputDevice.use(InputDevice.Kind.TOUCH)
	await _frames(5)
	game = (load("res://src/game/game.tscn") as PackedScene).instantiate() as Game
	game.show_act_cards = false
	get_tree().root.add_child(game)
	await _frames(60)
	game.player.invincible = true
	for item in args[2].split(","):
		var parts := item.split(":")
		await _shoot(parts[0], parts[1], parts.has("set"), parts.size() > 2 and parts.has("map"))
	get_tree().quit()


## `with_map`: the whole floor on the big map too, after the room.
func _shoot(biome_id: String, what: String, set_piece: bool, with_map: bool = false) -> void:
	var biome: BiomeDef = load("res://data/biomes/%s.tres" % biome_id)
	var act := 0
	for a in game.content.dungeon.acts.size():
		if game.content.dungeon.acts[a].biomes.has(biome):
			act = a
	var depth := game.content.dungeon.first_depth(act) + 1
	var forced := biome.duplicate() as BiomeDef
	var shape: RoomShapeDef = null
	if what != "map" and what != "ceiling":
		shape = load("res://data/biomes/%s/%s.tres" % ["set_pieces" if set_piece else "shapes", what])
		if set_piece:
			forced.set_pieces = [shape] as Array[RoomShapeDef]
			forced.set_piece_chance = 1.0
		else:
			forced.room_shapes = [shape] as Array[RoomShapeDef]
			forced.plain_weight = 0
	game.world.overrides.biome = forced
	await game.debug.enter_floor(depth)
	var world := game.world
	await _frames(5)
	for monster in world.get_hostiles(Actor.Faction.PLAYER):
		(monster as Monster).dormant = true
	var map := world.map
	var spot := map.cell_to_world(map.start_cell)
	if shape:
		for i in map.rooms.size():
			if map.plan(i).shape == shape:
				spot = map.cell_to_world(map.heart(i)) + Vector2(0, 40)
				break
	elif what == "ceiling":
		spot = _under_ceiling(world, spot)
	game.player.global_position = spot if what == "ceiling" else world.nearest_free_point(spot)
	game.player.camera.reset_smoothing()
	await _frames(40)
	if what == "map":
		world.reveal_all()
		game.hud.get_node("%FullMap").visible = true
		await _frames(10)
	await _shot("%s_%s" % [biome_id, what])
	if what == "ceiling":
		game.player.global_position = world.nearest_free_point(game.player.global_position + Vector2(0, 110))
		await _frames(30)
		await _shot("%s_%s_away" % [biome_id, what])
	if what == "map":
		game.hud.get_node("%FullMap").visible = false
	if with_map:
		world.reveal_all()
		game.hud.get_node("%FullMap").visible = true
		await _frames(10)
		await _shot("%s_%s_map" % [biome_id, what])
		game.hud.get_node("%FullMap").visible = false


## A point under a ceiling piece, if the floor has one.
func _under_ceiling(world: World, fallback: Vector2) -> Vector2:
	var layer := world.ceiling
	if layer == null:
		return fallback
	# The hero under a piece hanging from a wall, the most of them around.
	var best := fallback
	var best_count := -1
	for one in layer.laid:
		var count := layer.laid.filter(func(o: CeilingLayer.Laid) -> bool: return o.under.distance_to(one.under) < 400.0).size()
		if one.def.where != CeilingPieceDef.Where.TOP_WALL:
			count += 100  # something hanging over the room's middle shows the fade best
		var spot := one.under + Vector2(0, -6)
		if one.def.height > 0.0:
			spot = one.under + Vector2(0, -one.def.height + 22.0)
		if count > best_count and world.is_free_cell(world.map.world_to_cell(spot)):
			best_count = count
			best = spot
	return best


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s_%s.png" % [out, tag, shot_name])
	print("shot ", shot_name)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
