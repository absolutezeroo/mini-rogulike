class_name AbyssDef
extends Resource
## The Deeps (FR les Tréfonds): where the hero goes when he falls into a hole on a floor. Instead
## of climbing out hurt, he sinks deeper into the Well, into a small dark maze where demons crawl
## out of the dark in waves while he looks for the Dawn Breach, a standing rift of light. Reaching
## it brings him back to the last safe spot by the hole, his Health as he left the Deeps, with a
## gift if he was quick. Dying down there is dying. The floor waits frozen meanwhile (SubWorld).
## Not on boss floors, the hidden floor or from the Threshold (the old rule there: lose Health and
## climb out). Run by `Abyss`, hosted in an `AbyssWorld`. Data: data/abyss/abyss.tres, set in
## `DungeonConfig` > Abyss.

@export var display_name: String = "The Deeps"
## Said in the log on the way in (the Well's voice).
@export_multiline var lore: String
## The way out's name (the card's rule and the log).
@export var door_name: String = "The Dawn Breach"

@export_group("Rules")
## The fall's cost on landing down there, a share of max Health (the Deeps are the real cost).
@export_range(0.0, 0.5, 0.01) var fall_damage: float = 0.05
## Seconds he can't be hurt once back on his floor.
@export_range(0.0, 5.0) var return_grace: float = 1.5
## Back from the Deeps, the hole he fell through closes behind him (rubble fills it): stepping
## out by its edge must not drop him straight back in.
@export var seal_hole: bool = true
## Out within this many seconds (plus `quick_time_per_act` each later act): the dawn's gift.
@export_range(5.0, 300.0) var quick_time: float = 40.0
@export_range(0.0, 60.0) var quick_time_per_act: float = 5.0
## The gift: gold (`gift_gold` + `gift_gold_per_act` each act, scaled like any gold), and one
## roll of `gift_loot` (an item at the spot he comes back to).
@export_range(0, 500) var gift_gold: int = 12
@export_range(0, 200) var gift_gold_per_act: int = 8
@export var gift_loot: LootTable

@export_group("Place")
## The maze: this many rooms of `room_size` cells (random between x and y), chained by corridors
## `corridor_width` wide, in a map of `size` cells.
@export var size: Vector2i = Vector2i(44, 36)
@export_range(2, 12) var rooms: int = 6
@export var room_size: Vector2i = Vector2i(6, 9)
@export_range(1, 5) var corridor_width: int = 2
## Holes in some rooms (falling in there: the old rule, lose Health and climb out), placed like a
## floor's hazards, never cutting the way to the door off.
@export var hazards: Array[HazardDef] = []
@export_range(0, 6) var hazard_groups: int = 2
## Its tiles and walls.
@export var theme: DungeonTheme
## Its light (null: the theme's), and the floor's dressing taken from a biome (grounds and decor,
## never its scenes).
@export var lighting: LightingDef
@export var light_tint: Color = Color.WHITE
@export var dressing: BiomeDef
## The hero's torch down there (its level; the floor's is 12): he sees little.
@export_range(1, 15) var torch_level: int = 8
## Its sound and look: grading, fog, embers in the air.
@export var ambience: AmbienceDef
@export var music: AudioStream

@export_group("Demons")
## Who comes (each from its `min_depth`, by `spawn_weight`); none of them lives on the floors.
@export var monsters: Array[MonsterDef] = []
## Seconds after the veil lifts before the first wave.
@export_range(0.0, 30.0) var first_wave: float = 3.0
## Seconds between waves (less each later act, `wave_every_per_act`, never under 3 s).
@export_range(1.0, 60.0) var wave_every: float = 9.0
@export_range(0.0, 10.0) var wave_every_per_act: float = 1.0
## Demons in the first wave; each wave brings `wave_growth` more, each act `wave_size_per_act`.
@export_range(1, 12) var wave_size: int = 2
@export_range(0.0, 4.0) var wave_growth: float = 0.5
@export_range(0, 6) var wave_size_per_act: int = 1
## Demons up at once at most (plus `alive_per_act` each act): a wave waits for room.
@export_range(1, 30) var max_alive: int = 6
@export_range(0, 6) var alive_per_act: int = 1
## They crawl out of the dark between these many cells from the hero (never on top of him)...
@export var spawn_cells: Vector2i = Vector2i(6, 11)
## ...this share of each wave on the way ahead of him, toward the door (the rest anywhere around):
## outrunning them is not a way out.
@export_range(0.0, 1.0) var ahead_share: float = 0.5
## Demons already waiting in each room but the first (random between x and y; asleep until they
## see him), so the way to the door is a fight from the start.
@export var room_demons: Vector2i = Vector2i(1, 2)
## Chance each demon of a wave is an elite.
@export_range(0.0, 1.0) var elite_chance: float = 0.05
## A watchman by the door from act `warden_act` (0 = Act I) on; null: none.
@export var warden: MonsterDef
@export_range(0, 10) var warden_act: int = 2

@export_group("Look")
## The name and counters on screen, and the log.
@export var color: Color = Color(0.95, 0.42, 0.32)
## The veil drawn over the screen on the way down, and the dawn's on the way back up.
@export var veil_color: Color = Color(0.05, 0.01, 0.02)
@export var return_veil_color: Color = Color(1.0, 0.92, 0.72)
## Seconds of each fade.
@export_range(0.1, 2.0) var fade_time: float = 0.5
## How bright the door shines on the floor around it (a light level), seen from far in the dark.
@export_range(1, 15) var door_light: int = 13
## A light runs ahead along the way to the door when the veil lifts, then again every this many
## seconds (0: only at the start).
@export_range(0.0, 60.0) var guide_every: float = 20.0


## Seconds he has for the dawn's gift when he falls on `depth`.
func quick_time_for(depth: int, config: DungeonConfig) -> float:
	return quick_time + quick_time_per_act * act_of(depth, config)


## Gold of the dawn's gift on `depth` (before the floor's gold rules).
func gift_gold_for(depth: int, config: DungeonConfig) -> int:
	return gift_gold + gift_gold_per_act * act_of(depth, config)


## Seconds between waves on `depth`.
func wave_every_for(depth: int, config: DungeonConfig) -> float:
	return maxf(3.0, wave_every - wave_every_per_act * act_of(depth, config))


## Demons in wave `index` (0: the first) on `depth`.
func wave_size_for(index: int, depth: int, config: DungeonConfig) -> int:
	return wave_size + floori(wave_growth * index) + wave_size_per_act * act_of(depth, config)


## Demons up at once at most on `depth`.
func max_alive_for(depth: int, config: DungeonConfig) -> int:
	return max_alive + alive_per_act * act_of(depth, config)


## Whether the warden stands by the door on `depth`.
func has_warden(depth: int, config: DungeonConfig) -> bool:
	return warden != null and act_of(depth, config) >= warden_act


## A demon for a wave on `depth`: by weight, from its `min_depth` on (the first one if none is
## old enough).
func pick_monster(depth: int, rng: RandomNumberGenerator) -> MonsterDef:
	var picked := ContentDB.pick_from(monsters, depth, rng) as MonsterDef
	if picked == null and not monsters.is_empty():
		picked = monsters[0]
	return picked


## The act `depth` is in (0: Act I; the endless floors count as the last act and on).
func act_of(depth: int, config: DungeonConfig) -> int:
	return maxi(config.act_index(depth), 0) if config else 0
