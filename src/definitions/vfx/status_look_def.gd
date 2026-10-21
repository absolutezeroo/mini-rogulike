class_name StatusLookDef
extends Resource
## How a status shows on whoever has it (StatusFx): burning bodies throw small flames and
## embers, poisoned ones bubble, slowed ones shed frost. A burst when it starts (and a sound),
## a glow while it lasts, and the color of its damage numbers. One per status id, listed in
## data/vfx/status_looks.tres.

enum Mote { NONE, EMBER, BUBBLE }

## The status: a damage-over-time id (&"burn", &"poison") or &"slow".
@export var status: StringName

@export_group("While it lasts")
## A small animated sheet (frames in a row) spawned over the body, rising or falling.
@export var particle: Texture2D
@export_range(1, 32) var particle_frames: int = 1
## Spawned per second.
@export var particle_rate: float = 8.0
@export var particle_life: float = 0.5
## Pixels per second, up (negative: they fall).
@export var particle_rise: float = 18.0
@export var particle_scale: float = 1.0
@export var particle_tint: Color = Color.WHITE
## Tiny things around it (embers rising, bubbles popping), per second; NONE for none.
@export var mote: Mote = Mote.NONE
@export var mote_rate: float = 6.0
@export var mote_color: Color = Color.WHITE
## A soft glow on the body (alpha 0: none).
@export var glow: Color = Color(1, 1, 1, 0)

@export_group("When it starts")
@export var burst: Texture2D
@export_range(1, 32) var burst_frames: int = 1
@export var burst_time: float = 0.4
@export var burst_scale: float = 1.0
@export var burst_tint: Color = Color.WHITE
@export var sound: AudioStream
@export var sound_db: float = -8.0

@export_group("Numbers")
## The color of the damage it deals (its ticks).
@export var text_color: Color = Color.WHITE
