class_name ContentDef
extends Resource
## Base class for content that can appear in the dungeon (monsters and items).
## Every concrete piece of content is a .tres file under res://data/.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String

@export_group("Look")
## Character drawn on the entity until real sprites are added.
@export var glyph: String = "?"
@export var color: Color = Color.WHITE

@export_group("Spawning")
## First dungeon depth where this can spawn.
@export_range(1, 99) var min_depth: int = 1
## Relative spawn chance. 0 = never spawns on its own (loot or starting gear only).
@export_range(0, 1000) var spawn_weight: int = 10
