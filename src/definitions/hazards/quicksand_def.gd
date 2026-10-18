class_name QuicksandDef
extends HazardDef
## A pool of quicksand (or mud, or tar): anyone wading in is slowed down a lot, and starts
## sinking (taking damage) if they stay too long. Monsters too. Flying monsters and rolls skim over.

## Frames in a row (square, 32x32 = a pool of 2x2 cells), looped.
@export var sheet: Texture2D
@export var fps: float = 6.0
## Speed lost while in it (0.6 = 60% slower).
@export_range(0.0, 0.9, 0.05) var slow: float = 0.6
## Seconds in it before sinking starts to hurt.
@export var sink_delay: float = 1.2
## Damage every `tick_interval` once sinking. Grows with depth.
@export var damage: int = 2
@export var tick_interval: float = 0.5
@export var sink_sound: AudioStream
## Pools per group (random between the two).
@export_range(1, 6) var pools_min: int = 1
@export_range(1, 6) var pools_max: int = 3


func place(world: World, room: Rect2i, taken: Dictionary) -> void:
	for i in world.rng.randi_range(pools_min, pools_max):
		var rect := find_free_rect(world, room, taken, Vector2i(2, 2))
		if rect.size == Vector2i.ZERO:
			return
		take_rect(taken, rect)
		world.spawn_quicksand(self, rect)
