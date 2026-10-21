class_name PocketWorld
extends World
## A World built for a while beside the one the hero stands in (SubWorld moves him in and out):
## the Threshold's limbo (ThresholdWorld), the Deeps (AbyssWorld). No stairs, no seal; the hero
## is taken in and let go, never placed as on a new floor (no "new floor" perk wakes up).


## Shows `new_map` in `new_theme` under `lighting` (null: the theme's), its walls, paths and fog;
## nothing on it yet. `content`, `depth` and `rng` must be set before.
func show_place(new_map: DungeonMap, new_theme: DungeonTheme, lighting: LightingDef, tint: Color, content: ContentDB) -> void:
	floor_event = null
	curse = null
	biome = null
	route = null
	arena_plan = null
	next_routes.clear()
	opened_chests.clear()
	bought.clear()
	_content = content
	theme = new_theme
	map = new_map
	rules = FloorRules.make(content.dungeon, difficulty, null, depth)
	_view.show_map(map, theme)
	lights.setup(map, lighting if lighting else (theme.lighting if theme else null), tint)
	_view.mist.bind_light(lights)
	_pits.setup(map.tile_size)
	fog.reset(map)
	stairs_cells.clear()
	WallBuilder.build(map, _walls)
	nav.build(map)
	seal.clear()


## The hero arrives, at `at` (the map's start by default).
func take_in(hero: Player, at: Vector2 = Vector2.INF) -> void:
	player = hero
	hero.world = self
	if hero.get_parent():
		hero.get_parent().remove_child(hero)
	_entities.add_child(hero)
	hero.global_position = map.cell_to_world(map.start_cell) if at == Vector2.INF else at
	hero.reset_safe_position()
	hero.camera.reset_smoothing()


## The hero leaves: out of the tree here, nothing else changed.
func let_go(hero: Player) -> void:
	if hero.get_parent() == _entities:
		_entities.remove_child(hero)
	player = null
