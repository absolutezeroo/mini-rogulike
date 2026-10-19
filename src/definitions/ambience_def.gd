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

@export_group("Atmosphere")
## Color grading of the whole picture: shadows pulled toward one color, highlights toward
## another (white = unchanged), by `grade_strength`.
@export var grade_shadows: Color = Color.WHITE
@export var grade_highlights: Color = Color.WHITE
@export_range(0.0, 1.0) var grade_strength: float = 0.0
@export_range(0.0, 2.0) var saturation: float = 1.12
@export_range(0.5, 1.5) var contrast: float = 1.06
## Bright things (fire, lights, gold) bleed a little glow around them.
@export_range(0.0, 1.0) var bloom: float = 0.0
## The air trembles (heat), in art pixels.
@export_range(0.0, 3.0) var heat_haze: float = 0.0
## Shafts of light falling from above (alpha 0 = none): angle from straight down, how many.
@export var rays_color: Color = Color(1.0, 0.95, 0.8, 0.0)
@export_range(-60.0, 60.0) var rays_angle: float = 25.0
@export_range(0.0, 1.0) var rays_density: float = 0.2
## Light dancing on everything as if reflected by water (alpha 0 = none).
@export var caustics_color: Color = Color(0.7, 0.95, 1.0, 0.0)
## Low mist creeping over the floor (alpha 0 = none).
@export var mist_color: Color = Color(0.8, 0.85, 1.0, 0.0)
@export var mist_speed: Vector2 = Vector2(8, 3)
## Shadows of leaves drifting over the floor (0 = none).
@export_range(0.0, 1.0) var canopy: float = 0.0
