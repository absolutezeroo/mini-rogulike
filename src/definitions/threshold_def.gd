class_name ThresholdDef
extends Resource
## The trial of the Threshold, a limbo between life and death. A second life (CheatDeathPassive:
## the Phoenix Feather, Death Denied) no longer heals the hero in place: the killing blow pulls
## him there instead, while the floor waits frozen. He must slay `kills_for()` spectres before
## `time_for()` seconds run out; then he comes back where he fell, healed by the passive. If the
## time runs out or he falls in there, he dies for real. Run by `Threshold`, hosted in a
## `ThresholdWorld`. Data: data/threshold/threshold.tres (named by the passive's `trial`).

@export var display_name: String = "The Threshold"
## Said in the log on the way in (the Well's voice).
@export_multiline var lore: String

@export_group("Rules")
## Spectres to slay in the first act; each later act asks for `kills_per_act` more.
@export_range(1, 50) var kills: int = 8
@export_range(0, 10) var kills_per_act: int = 2
## Seconds to do it in the first act; each later act gives `time_per_act` more.
@export_range(5.0, 120.0) var time_limit: float = 25.0
@export_range(0.0, 30.0) var time_per_act: float = 6.0
## The hero's Health inside, as a share of his max Health (he came from 0: he must be able to fight).
@export_range(0.05, 1.0) var hero_health: float = 0.6
## Seconds he can't be hurt once back on the floor (monsters frozen mid-swing around him).
@export_range(0.0, 5.0) var return_grace: float = 1.0

@export_group("Spectres")
## Who comes: these, or (empty) the monsters of the act the hero fell in.
@export var monsters: Array[MonsterDef] = []
## Spectres standing at once; the next one rises `spawn_every` seconds after a gap opens.
@export_range(1, 12) var alive_at_once: int = 4
@export_range(0.1, 5.0) var spawn_every: float = 0.7
## Their Health, as a share of the same monster on the floor.
@export_range(0.1, 2.0) var monster_health: float = 0.7
## They rise at least this many cells from the hero.
@export_range(1, 12) var spawn_distance: int = 5
## How they look: blended this much toward `spectral_color`, and this see-through.
@export var spectral_color: Color = Color(0.78, 0.9, 1.0)
@export_range(0.0, 1.0) var spectral_pallor: float = 0.5
@export_range(0.2, 1.0) var spectral_alpha: float = 0.82

@export_group("Place")
## The shape of the limbo (its size, shape and pillars; its changes are not used).
@export var arena: ArenaDef
## Its tiles and walls (null: the floor's own).
@export var theme: DungeonTheme
## Its light (null: the theme's).
@export var lighting: LightingDef
@export var light_tint: Color = Color.WHITE
## Its sound and look: grading, fog, mist, the wisps in the air.
@export var ambience: AmbienceDef
@export var music: AudioStream
## The bell: on the way in, and when the trial ends.
@export var knell: AudioStream
## Cells of mist kept around the arena.
@export_range(4, 20) var margin: int = 10

@export_group("Look")
## The trial's name and counters on screen.
@export var color: Color = Color(0.72, 0.86, 1.0)
## The veil drawn over the screen on the way in, and on the way back to life.
@export var veil_color: Color = Color(0.03, 0.04, 0.09)
@export var return_veil_color: Color = Color(0.85, 0.92, 1.0)
## Seconds of each fade.
@export_range(0.1, 2.0) var fade_time: float = 0.55
## Seconds the hero's soul takes to sink before the veil falls.
@export_range(0.0, 2.0) var sink_time: float = 0.45


## Spectres to slay when the hero falls on `depth`.
func kills_for(depth: int, config: DungeonConfig) -> int:
	return kills + kills_per_act * _act(depth, config)


## Seconds he has when he falls on `depth`.
func time_for(depth: int, config: DungeonConfig) -> float:
	return time_limit + time_per_act * _act(depth, config)


## A spectre for the limbo: from `monsters`, or the act's own (null if there is none).
func pick_monster(content: ContentDB, depth: int, rng: RandomNumberGenerator) -> MonsterDef:
	if not monsters.is_empty():
		return monsters[rng.randi_range(0, monsters.size() - 1)]
	return content.pick_monster(depth, rng)


func _act(depth: int, config: DungeonConfig) -> int:
	return maxi(config.act_index(depth), 0) if config else 0
