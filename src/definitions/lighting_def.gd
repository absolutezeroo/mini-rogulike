class_name LightingDef
extends Resource
## How a floor is lit, in steps like the art (see LightField): light comes in levels, from 0
## (pitch dark) to 15 (full light). A lamp of level 12 lights its tile 12, the next tiles 11,
## then 10..., around corners but not through walls; each level is one flat band of color.

## Light everywhere, lamps or not (0 = black away from any light, 15 = broad daylight).
@export_range(0, 15) var ambient_level: int = 6
## Color of each level, from 0 (left) to 15 (right): the light changes color as it fades
## (warm by the flame, dusky further out, cold in the dark). White = the art as drawn.
@export var ramp: Gradient
## How much a lamp's own color shows in its glow, strongest by the lamp (0 = not at all).
@export_range(0.0, 1.0) var tint_strength: float = 0.4


## The color of a light level.
func color_of(level: int) -> Color:
	if ramp == null:
		return Color.WHITE
	return Color(ramp.sample(clampf(level / float(LightField.MAX_LEVEL), 0.0, 1.0)), 1.0)
