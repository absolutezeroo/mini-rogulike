class_name RunFacts
extends Resource
## What is known of a run as it ends (or of none: at the shrine), for the dialogue: who or what
## killed the hero, where, at what level, how long, what he carried, what the run did. It is the
## `subject` the dialogue's conditions read (KillerCondition, CauseCondition, PlaceCondition,
## RunMarkCondition...; the story's own conditions read the Profile and ignore it), and it fills
## the {codes} of the lines (codes()). Built once by the Game when the run ends (of_death(),
## of_victory()); tests stage one by hand. Names are kept as English keys, translated in codes().

## How the hero died, as the dialogue's conditions name it.
const CAUSES := [&"monster", &"shockwave", &"trap", &"fall", &"burn", &"poison", &"cold", &"heat",
	&"quicksand", &"blast", &"altar", &"giving_up", &"unknown"]

## The run was won (the victory screen); false for a death.
var won := false
## The ending chosen at the bottom of the Well (EndingDef id), "" if none.
var ending: StringName = &""
var depth := 1
## The act (1 for Act I), 0 on no act.
var act := 0
## The act's title (English key), and the floor's world (its biome's name).
var act_title := ""
var biome := ""
## Where it ended, as the end screen says it: the act's, the hidden floor's, the bottom's or the
## Deeps' name (English key).
var place := ""
var level := 1
var seconds := 0.0
var kills := 0
var bosses_slain := 0
## What killed the hero: a monster's id and name (English key), and what kind it was.
var killer_id: StringName = &""
var killer_name := ""
var killer_boss := false
var killer_elite := false
## It fights from afar (a shooting weapon, or it keeps its distance).
var killer_ranged := false
## How (CAUSES): a monster's blow, a boss's shockwave, a trap, a fall, a burn's last tick...
var cause: StringName = &"unknown"
## Died down in the Deeps (under the holes); died after losing the trial of the Threshold.
var in_deeps := false
var threshold_lost := false
var hidden_floor := false
var finale := false
## The floor's curse (CurseDef id and name), "" if none; the floor's event (FloorEventDef id).
var curse_id: StringName = &""
var curse_name := ""
var event_id: StringName = &""
## The run's difficulty (DifficultyDef id: easy, normal, hard, nightmare) and its ascension.
var difficulty_id: StringName = &""
var ascension := 0
## What the run did (RunState.marks: "bought", "drank", "rolled", "cursed", "oath"...).
var marks := {}
## Healing potions still carried (belt and bag), armor pieces worn, the weapon in hand.
var potions_left := 0
var armor_worn := 0
var weapon_name := ""
## The warden drawn for the act it ended in (its name, English key), "" if none.
var boss_name := ""


## The hero just died (`player.is_dead`): the facts of his death, read at once (the world may
## change during the pause before the end screen).
static func of_death(run: RunState, player: Player, content: ContentDB, floor_world: World, in_the_deeps: bool = false) -> RunFacts:
	var facts := _of_run(run, player, content, floor_world)
	facts.won = false
	facts.in_deeps = in_the_deeps
	if in_the_deeps and content and content.dungeon.abyss:
		facts.place = content.dungeon.abyss.display_name
	facts.cause = player.death_cause if player else &"unknown"
	var killer: MonsterDef = player.killer_def if player else null
	if killer:
		facts.killer_id = killer.id
		facts.killer_name = killer.display_name
		facts.killer_boss = killer is BossDef
		facts.killer_elite = player.killer_was_elite
		var weapon := killer.weapon
		facts.killer_ranged = killer.keep_distance > 0.0 or (weapon != null and weapon.kind != WeaponDef.Kind.MELEE)
	elif player and not player.killed_by.is_empty() and facts.cause == &"monster":
		facts.killer_name = player.killed_by
	return facts


## The run was won (`ending`: the one chosen at the bottom of the Well, or null).
static func of_victory(run: RunState, player: Player, content: ContentDB, floor_world: World, chosen: EndingDef = null) -> RunFacts:
	var facts := _of_run(run, player, content, floor_world)
	facts.won = true
	facts.cause = &"unknown"
	facts.ending = chosen.id if chosen else &""
	return facts


static func _of_run(run: RunState, player: Player, content: ContentDB, floor_world: World) -> RunFacts:
	var facts := RunFacts.new()
	if run:
		facts.depth = run.depth
		facts.seconds = run.run_time()
		facts.kills = run.kills
		facts.bosses_slain = run.bosses_slain
		facts.hidden_floor = run.hidden_floor
		facts.finale = run.finale
		facts.marks = run.marks.duplicate()
		facts.threshold_lost = run.marks.has("threshold_lost")
		if run.difficulty:
			facts.difficulty_id = run.difficulty.id
			facts.ascension = run.difficulty.ascension
		if content:
			facts.place = run.place_name_key(content)
			var index := content.dungeon.act_index(run.depth)
			if index >= 0:
				facts.act = index + 1
				facts.act_title = content.dungeon.acts[index].title
				if index < run.bosses.size() and run.bosses[index]:
					facts.boss_name = run.bosses[index].display_name
	if floor_world:
		if floor_world.biome:
			facts.biome = floor_world.biome.display_name
		if floor_world.curse:
			facts.curse_id = floor_world.curse.id
			facts.curse_name = floor_world.curse.display_name
		if floor_world.floor_event:
			facts.event_id = floor_world.floor_event.id
	if player:
		facts.level = player.level
		facts.potions_left = player.healing_carried()
		for slot in [EquipmentDef.Slot.HEAD, EquipmentDef.Slot.BODY]:
			if player.equipment.get_item(slot):
				facts.armor_worn += 1
		var weapon := player.get_weapon()
		facts.weapon_name = weapon.display_name if weapon else ""
	return facts


## The run did `mark` (RunState.marks).
func has_mark(mark: String) -> bool:
	return marks.has(mark)


## The {codes} of the dialogue's lines, translated: {killer}, {floor}, {act}, {biome},
## {place}, {level}, {time}, {kills}, {curse}, {weapon}, {boss}.
func codes() -> Dictionary:
	return {
		"killer": TranslationServer.tr(killer_name) if not killer_name.is_empty() else TranslationServer.tr("The dark"),
		"floor": str(depth),
		"act": TranslationServer.tr(act_title),
		"biome": TranslationServer.tr(biome),
		"place": TranslationServer.tr(place),
		"level": str(level),
		"time": TimeText.of(seconds, 0),
		"kills": str(kills),
		"curse": TranslationServer.tr(curse_name),
		"weapon": TranslationServer.tr(weapon_name),
		"boss": TranslationServer.tr(boss_name),
	}
