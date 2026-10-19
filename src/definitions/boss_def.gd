class_name BossDef
extends MonsterDef
## A boss guards the arena on the last floor of its act (see ActDef).
## It sleeps until the player walks into its arena, then the exits close.
## As it loses HP it goes through its phases: stronger, faster, new attack patterns. Entering
## one, it roars (untouchable for a moment) and throws the hero off with a shockwave. Hit it
## too many times in a row and it does the same: no standing still and hitting forever.

## Shown under the name when the fight starts, e.g. "Guardian of the Ruins".
@export var title: String
## Face shown next to the boss health bar.
@export var portrait: Texture2D
## Played during the fight. Empty = SoundBank.boss_music.
@export var music: AudioStream
## Arenas it fights in (one picked per fight; empty: the dungeon's, DungeonConfig.arenas).
@export var arenas: Array[ArenaDef] = []
## In order of decreasing hp_ratio (usually two: at two thirds and one third of its HP).
@export var phases: Array[BossPhase] = []
## Hits taken in a row (each less than `streak_gap` seconds after the last) before it answers
## with a shockwave. 0 = never.
@export_range(0, 30) var shockwave_after_hits: int = 8
@export var streak_gap: float = 1.5
## The shockwave: how far it reaches (beyond the boss' body), how hard it pushes.
@export var shockwave_radius: float = 140.0
@export var shockwave_knockback: float = 700.0
## Seconds it can't be hurt while it roars into a new phase.
@export var phase_roar_time: float = 1.2
## Relics offered when it dies (0 = none).
@export_range(0, 5) var relic_choices: int = 3
## Souls flying out of it when it dies, back to the hero's lantern (a common monster frees one).
@export_range(1, 40) var soul_wisps: int = 12
