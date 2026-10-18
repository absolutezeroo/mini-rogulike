class_name AmbienceDef
extends Resource
## How a floor sounds and feels besides its tiles: footsteps, echo, background sounds,
## things floating in the air, fog. Set on a DungeonTheme.

@export_group("Steps")
## The hero's footsteps on this ground.
@export var footstep: AudioStream
## Footprints left behind (alpha 0 = none).
@export var footprint_color: Color = Color(0, 0, 0, 0.22)

@export_group("Sound")
## Looping background (wind, distant fire...).
@export var bed: AudioStream
@export var bed_volume_db: float = -16.0
## Played now and then somewhere around the hero (water drops, whispers, rumbles...).
@export var one_shots: Array[AudioStream] = []
## Seconds between two of them (random in this range).
@export var one_shot_every: Vector2 = Vector2(4.0, 9.0)
@export var one_shot_volume_db: float = -8.0
## Echo of every world sound (0-1).
@export_range(0.0, 1.0) var reverb_room_size: float = 0.4
@export_range(0.0, 1.0) var reverb_wet: float = 0.12

@export_group("Air")
## Particles floating around the hero (dust, wisps, embers).
@export var particles: PackedScene
## Drifting fog over the floor. Empty = none.
@export var fog: Texture2D
@export var fog_color: Color = Color(1, 1, 1, 0.06)
@export var fog_speed: Vector2 = Vector2(6, 2)
