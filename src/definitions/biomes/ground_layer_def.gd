class_name GroundLayerDef
extends Resource
## A ground spread over part of a floor (sand, moss, a carpet of leaves...): one 16 px tile of
## the material repeated, with a darker rim, in organic patches. Where it goes is noise, pushed
## toward the walls (sand drifts, moss) or away from them; how much of the floor it covers is
## `coverage`. Drawn by GroundLayer; decor can grow only on it (DecorRuleDef.only_on).

@export var texture: Texture2D
## The material's tile in `texture` (16x16), and an optional second one mixed in.
@export var tile: Rect2i = Rect2i(16, 16, 16, 16)
@export var tile_alt: Rect2i = Rect2i()
## The rim around the patches.
@export var edge_color: Color = Color(0.5, 0.35, 0.2)
## Part of the floor covered.
@export_range(0.0, 1.0) var coverage: float = 0.3
## Size of the patches: small = many little ones, big = a few wide ones.
@export_range(0.02, 0.5) var noise_scale: float = 0.1
## Toward the walls (> 0) or the middle of the rooms (< 0).
@export_range(-1.0, 1.0) var wall_bias: float = 0.0
## How ragged the edges are.
@export_range(0.0, 1.0) var roughness: float = 0.35
