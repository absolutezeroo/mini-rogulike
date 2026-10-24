class_name FinaleDef
extends Resource
## The bottom of the Well (DungeonConfig.finale): the run's true last floor, once the profile has
## won `victories_needed` times. Until then the last act's boss wins the run (the first ending).
## Afterwards that boss no longer ends it: its arena opens a single way down, to one floor of
## its own (a start room and an arena, `biome`), where `boss` waits with its next forms
## (BossDef.next_boss). The last form's fall wins the run, and the hero chooses an ending.
## The floor keeps the depth of the boss floor before it (RunState.finale), like the hidden floor.

@export var id: StringName
## Its name: the card, the banner, the sign over the way down.
@export var title: String
## Over the title on its card.
@export var subtitle: String
## Its card's line of story.
@export_multiline var lore: String
## Wins the profile needs (any difficulty) before the last act's boss leads here.
@export_range(1, 99) var victories_needed: int = 1

@export_group("The floor")
## Its look and light.
@export var biome: BiomeDef
## The arena's size and shape (ArenaDef; null: the boss' own or the dungeon's).
@export var arena: ArenaDef
## Waits in the arena; its next forms rise there when it falls.
@export var boss: BossDef
## Waits instead of `boss` and its forms while a Nameless Keeper waits (a hero who took the
## keeper's place: Profile.keeper, built for the run, RunState.keeper_boss). His fall is the last.
@export var keeper: NamelessKeeperDef
## Lamps along the arena's walls (the dungeon's room light); 0: the hero's lantern alone.
@export_range(0, 6) var arena_lights: int = 0

@export_group("The end")
## Chosen when the last form falls (the EndingPanel), in the panel's order.
@export var endings: Array[EndingDef] = []
## Over the choice: what is left when the last form falls.
@export var choice_title: String
@export_multiline var choice_lore: String
## The line over the choice when the Nameless Keeper fell (empty: `choice_lore`).
@export_multiline var keeper_choice_lore: String
@export var color: Color = Color(0.78, 0.66, 1.0)


## The way down to it is open: the profile has won enough runs.
func is_open() -> bool:
	return Profile.total_wins() >= victories_needed


## The boss whose fall wins the run.
func final_boss() -> BossDef:
	return boss.last_form() if boss else null


## Everything that may wait at the bottom: the boss and its forms, then the Nameless Keeper (his
## template). The bestiary, the soundtrack and the debug lists show them all.
func all_bosses() -> Array[BossDef]:
	var result: Array[BossDef] = []
	if boss:
		result = boss.forms()
	if keeper and not result.has(keeper):
		result.append(keeper)
	return result


## The line over the choice (after the Nameless Keeper: his own, if there is one).
func choice_lore_for(keeper_fell: bool) -> String:
	return keeper_choice_lore if keeper_fell and not keeper_choice_lore.is_empty() else choice_lore


func get_ending(ending_id: StringName) -> EndingDef:
	for ending in endings:
		if ending and ending.id == ending_id:
			return ending
	return null


## Its title card, as an act's (ActCard shows acts).
func as_act() -> ActDef:
	var act := ActDef.new()
	act.title = title
	act.subtitle = subtitle
	act.lore = lore
	if biome:
		act.biomes = [biome]
	act.floors = 1
	return act


## The sign over the way down to it (a lone way, named).
func route() -> FloorRoute:
	var way := FloorRoute.new()
	way.biome = biome
	return way
