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
## A perk or relic was chosen.
@export var perk_chosen: AudioStream
## A freed soul reaches the hero's lantern.
@export var soul: AudioStream

@export_group("Monsters")
@export var monster_hurt: AudioStream
@export var monster_death: AudioStream
@export var monster_alert: AudioStream

@export_group("Combat")
@export var projectile_impact: AudioStream
@export var explosion: AudioStream

@export_group("Items")
@export var pickup: AudioStream
## Gold picked up, bought or sold.
@export var coin: AudioStream
@export var equip: AudioStream

@export_group("World")
@export var stairs: AudioStream
@export var game_over: AudioStream
## Someone drops into a hole.
@export var fall: AudioStream
## The exits of an ambush room slam shut.
@export var ambush: AudioStream

@export_group("Bosses")
## The boss wakes up when you enter its arena.
@export var boss_roar: AudioStream
## Spikes rising or falling across the arena exits.
@export var gate: AudioStream
@export var boss_defeated: AudioStream
## Played while fighting a boss (looped).
@export var boss_music: AudioStream

@export_group("Interface")
@export var ui_click: AudioStream
@export var ui_open: AudioStream
@export var ui_close: AudioStream
