class_name ImpactMaterialDef
extends Resource
## What a monster is made of (flesh, bone, slime, armor, spirit, plant): a hit on it sounds like
## it (`sound`, played over its cry), its sparks take its color, and when it dies it leaves
## chips of itself on the floor that stay for the whole floor (SplatLayer.add_debris).
## In data/materials/, set on MonsterDef.material.

@export var display_name: String = ""
## Played over the hurt sound on every direct hit.
@export var sound: AudioStream
@export var volume_db: float = -4.0
## Sparks of a hit (crits keep theirs).
@export var spark_color: Color = Color.WHITE
## Chips left where it died, picked at random among these colors.
@export var debris_colors: PackedColorArray = PackedColorArray([Color(0.4, 0.1, 0.1)])
## How many, for a monster of normal size (bigger ones leave more).
@export var debris_count: int = 6
