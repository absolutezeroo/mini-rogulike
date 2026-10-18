class_name SoundBank
extends Resource
## Sounds for game events that do not belong to one piece of content.
## Content can override some of them (a weapon's hit sound, a monster's death sound...).
## Tip: use an AudioStreamRandomizer to get variations and random pitch for free.

@export_group("Player")
@export var player_hurt: AudioStream
@export var player_death: AudioStream
@export var footstep: AudioStream
@export var level_up: AudioStream

@export_group("Monsters")
@export var monster_hurt: AudioStream
@export var monster_death: AudioStream
@export var monster_alert: AudioStream

@export_group("Combat")
@export var projectile_impact: AudioStream
@export var explosion: AudioStream

@export_group("Items")
@export var pickup: AudioStream
@export var equip: AudioStream

@export_group("World")
@export var stairs: AudioStream
@export var game_over: AudioStream

@export_group("Interface")
@export var ui_click: AudioStream
@export var ui_open: AudioStream
@export var ui_close: AudioStream
