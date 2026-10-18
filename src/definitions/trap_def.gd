class_name TrapDef
extends ContentDef
## A floor trap that hurts anyone on it (player and monsters alike: lure them in!).
## Cycle: idle > warning (the danger peeks out) > active (hurts) > idle again.

enum Trigger {
	## Runs on its own timer. Traps placed together share a rhythm.
	TIMED,
	## Waits until someone steps on it, then warns and fires.
	STEP,
}

@export var trigger: Trigger = Trigger.TIMED
## Drawn all the time (holes in the floor, a vent, a pressure plate...).
@export var base_texture: Texture2D
## Drawn while armed with STEP traps once pressed (e.g. the pressed plate). Optional.
@export var pressed_texture: Texture2D
## Frames in a row: the danger itself (spikes, flames). Played during the active phase.
@export var active_sheet: Texture2D
@export_range(1, 64) var active_frames: int = 1
@export var active_fps: float = 12.0

@export_group("Timing")
@export var idle_time: float = 1.6
@export var warning_time: float = 0.45
@export var active_time: float = 0.7

@export_group("Damage")
## Damage on each actor caught, once per activation. Grows with depth (DungeonConfig).
@export var damage: int = 6
## Burn applied on top (damage per tick for 3 s). 0 = none.
@export var burn_damage: int = 0
@export var knockback: float = 120.0
@export var sound: AudioStream
