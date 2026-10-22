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
## The shockwave's damage as a share of the boss' power (0: the dungeon's small blast, about a
## trap's). It is the price of standing in its face: telegraphed, rolled through by a player who
## watches, taken every time by one who doesn't.
@export_range(0.0, 3.0, 0.05) var shockwave_power: float = 0.0
## Seconds it can't be hurt while it roars into a new phase.
@export var phase_roar_time: float = 1.2
## A boss too big for the screen (the Maw): the view leans this share of the way toward its
## middle while it fights, so the hero and it both stay on screen (0: the view stays on the hero).
@export_range(0.0, 1.0, 0.05) var camera_lean: float = 0.0
## Relics offered when it dies (0 = none).
@export_range(0, 5) var relic_choices: int = 3
## Souls flying out of it when it dies, back to the hero's lantern (a common monster frees one).
@export_range(1, 40) var soul_wisps: int = 12

@export_group("Words")
## Spoken when it wakes (under its name's banner), and when it falls. Empty: silent. Wardens
## and keepers speak in docs/lore.md's voice; the Maw never says "I".
@export var waking_line: String
@export var dying_line: String

@export_group("Two forms")
## Where it waits in its arena: (0.5, 0.5) is the middle, (0.5, 0) the top wall's middle.
@export var arena_anchor: Vector2 = Vector2(0.5, 0.5)
## Its body stays where it fell (its death animation played to the end, never dissolved): a
## body the story still needs (the next form takes it, or it is what is left at the end).
@export var body_stays: bool = false
## When it falls, this one rises in the same arena (BossArena): no relic, no stairs, the boss
## bar passes to it. Only the last form's death ends the fight.
@export var next_boss: BossDef
## Seconds between its fall and the next form taking the fight (the arena darkens and shakes).
@export_range(0.5, 6.0, 0.1) var rise_time: float = 2.4
## With `body_stays`: how far its body moves once its death is played (world units; the Maw's
## last frame leaves Tôma standing in its empty mouth, then he is set down on the ground).
@export var settle_offset: Vector2 = Vector2.ZERO


## The last form of this boss (itself when it has no next one).
func last_form() -> BossDef:
	var form := self
	var guard := 0
	while form.next_boss and guard < 8:
		form = form.next_boss
		guard += 1
	return form


## This boss and the forms that follow it, in order.
func forms() -> Array[BossDef]:
	var result: Array[BossDef] = [self]
	while result.back().next_boss and result.size() < 8:
		result.append(result.back().next_boss)
	return result
