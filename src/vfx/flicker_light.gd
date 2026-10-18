class_name FlickerLight
extends PointLight2D
## A light that breathes like a flame: slow, slightly irregular changes of brightness.

## Energy around which it flickers (set this instead of `energy`).
@export var base_energy: float = 1.0
## 0 = steady, 0.2 = lively torch.
@export_range(0.0, 0.5) var flicker: float = 0.1

var _seed := 0.0


func _ready() -> void:
	_seed = randf() * 100.0


func _process(_delta: float) -> void:
	if not enabled:
		return
	var t := Time.get_ticks_msec() * 0.001 + _seed
	energy = base_energy * (1.0 + flicker * (0.6 * sin(t * 7.3) + 0.4 * sin(t * 13.1)))
