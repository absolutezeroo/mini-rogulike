class_name CeilingDef
extends Resource
## What hangs over a biome's rooms (BiomeDef.ceiling): roots and vines in the Well's throat,
## chains and bones in the Ossuary, banners and censers in the Pyre Temple, broken arches and
## sand trickling in the Kingdom of Dust, stalactites in the caves. Every piece is a picture in
## one atlas (one draw call a chunk), laid along the walls and over the rooms by CeilingDresser,
## drawn over the actors by CeilingLayer, and dithered away around the hero and any monster
## under it (gameplay stays readable: docs/vfx.md, 2b).

## Every piece's picture, in one image.
@export var atlas: Texture2D
@export var pieces: Array[CeilingPieceDef] = []
## The pieces' shadows on the floor (a flat dark, never a gradient).
@export var shadow_color: Color = Color(0.02, 0.0, 0.04, 0.28)
## Around a body the ceiling is gone within `clear_radius` (world units, from the body's outline),
## and comes back by ordered dithering over the next `fade_band`.
@export_range(4.0, 120.0) var clear_radius: float = 22.0
@export_range(2.0, 120.0) var fade_band: float = 26.0
## Scales every piece's density and per-room cap (a sparse biome, a thick one).
@export_range(0.0, 4.0) var density_scale: float = 1.0
