class_name BossDef
extends MonsterDef
## A boss guards the arena on the last floor of its act (see ActDef).
## It sleeps until the player walks into its arena, then the exits close.
## As it loses HP it goes through its phases: stronger, faster, new skills.

## Shown under the name when the fight starts, e.g. "Guardian of the Ruins".
@export var title: String
## Face shown next to the boss health bar.
@export var portrait: Texture2D
## Played during the fight. Empty = SoundBank.boss_music.
@export var music: AudioStream
## In order of decreasing hp_ratio.
@export var phases: Array[BossPhase] = []
## Relics offered when it dies (0 = none).
@export_range(0, 5) var relic_choices: int = 3
## Souls flying out of it when it dies, back to the hero's lantern (a common monster frees one).
@export_range(1, 40) var soul_wisps: int = 12
