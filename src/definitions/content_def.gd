class_name ContentDef
extends Resource
## Base class for content that can appear in the dungeon (monsters and items).
## Every concrete piece of content is a .tres file under res://data/.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String

@export_group("Look")
## Sprite used in the world and in menus (16x16 pixel art, drawn at 2x).
@export var icon: Texture2D
## Multiplies the icon colors, to make variants out of one sprite.
@export var icon_tint: Color = Color.WHITE
## Fallback character drawn when there is no icon.
@export var glyph: String = "?"
## Accent color: names in menus, glows, messages.
@export var color: Color = Color.WHITE

@export_group("Spawning")
## First dungeon depth where this can spawn.
@export_range(1, 99) var min_depth: int = 1
## Relative spawn chance. 0 = never spawns on its own (loot or starting gear only).
@export_range(0, 1000) var spawn_weight: int = 10
