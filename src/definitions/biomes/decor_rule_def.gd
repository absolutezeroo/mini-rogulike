class_name DecorRuleDef
extends Resource
## Small things lying around (16 px pieces, drawn at 2x, nothing to bump into): grass, pebbles,
## bones, books... Never spread evenly: noise makes them gather in clusters, and they can keep
## close to the walls (debris) or grow only on a ground (grass on moss).

@export var pieces: Array[Texture2D] = []
## Pieces per floor cell, on average.
@export_range(0.0, 1.0) var density: float = 0.05
## 0: anywhere; 1: only in tight clusters.
@export_range(0.0, 1.0) var clumping: float = 0.6
## Toward the walls (> 0) or the middle of the rooms (< 0).
@export_range(-1.0, 1.0) var wall_bias: float = 0.0
## Only on this ground (null: anywhere).
@export var only_on: GroundLayerDef
## Size of the clusters.
@export_range(0.02, 0.5) var noise_scale: float = 0.15
