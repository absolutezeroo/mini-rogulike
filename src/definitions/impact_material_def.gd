class_name ImpactMaterialDef
extends Resource
## What a monster is made of (flesh, bone, slime, armor, spirit, plant): a hit on it sounds like
## it (`sound`, played over its cry), its sparks take its color and shape, and when it dies it
## leaves chips of itself on the floor that stay for the whole floor (SplatLayer.add_debris).
## In data/materials/, set on MonsterDef.material.

@export var display_name: String = ""
## Played over the hurt sound on every direct hit.
@export var sound: AudioStream
@export var volume_db: float = -4.0
## Sparks of a hit: the brightest pixel of its bits (its first frames).
@export var spark_color: Color = Color.WHITE
## Chips left where it died, picked at random among these colors. They are also the steps its
## hit's bits go down as they fall (brightest first).
@export var debris_colors: PackedColorArray = PackedColorArray([Color(0.4, 0.1, 0.1)])
## How many, for a monster of normal size (bigger ones leave more).
@export var debris_count: int = 6
## The shape of a hit's bits (PixelDraw.bit): blood drops, bone chips, slime blobs, the steel
## sparks off armor, a spirit's motes, leaf chips.
@export var spark_bit: VfxElementDef.Bit = VfxElementDef.Bit.SQUARE
## Which way they go: drops and chips fall, sparks fly out, motes rise.
@export var spark_motion: VfxElementDef.Motion = VfxElementDef.Motion.OUTWARD

var _sparks: VfxElementDef


## Its hits' bits as an element (ImpactVfx.sparks): a ramp from `spark_color` down its debris
## colors (brightest first), its bit and motion; matter, it doesn't shine.
func sparks_element() -> VfxElementDef:
	if _sparks == null:
		_sparks = VfxElementDef.new()
		_sparks.id = StringName("material_" + display_name.to_lower())
		var steps: Array[Color] = []
		for color in debris_colors:
			steps.append(Color(color, 1.0))
		steps.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() > b.get_luminance())
		steps.push_front(Color(spark_color, 1.0))
		_sparks.ramp = PackedColorArray(steps.slice(0, 5))
		_sparks.accent = 1
		_sparks.bit = spark_bit
		_sparks.motion = spark_motion
		_sparks.emissive = false
	return _sparks
