class_name EncounterOutcome
extends Resource
## What happens after a choice. Everything is optional and adds up.

enum Gift { NONE, PERK, RELIC }

@export_range(0, 100) var weight: int = 10
@export_multiline var text: String = ""
@export var color: Color = Color.WHITE
## Fractions of the hero's max HP healed / lost.
@export_range(0.0, 1.0, 0.05) var heal_ratio: float = 0.0
@export_range(0.0, 1.0, 0.05) var damage_ratio: float = 0.0
@export var gold: int = 0
## Greater than 0: an item drops, rolled with this quality (see LootRoller).
@export var item_quality: float = 0.0
## A choice of perks (or of relics) right after.
@export var gift: Gift = Gift.NONE
## Monsters of the act appearing around the hero.
@export_range(0, 6) var monsters: int = 0
@export var elite_monsters: bool = false
## Anything else (buffs...), applied to the hero.
@export var effects: Array[Effect] = []


func apply(player: Player, at: Vector2) -> void:
	var world := player.world
	if heal_ratio > 0.0:
		player.heal(roundi(player.get_max_hp() * heal_ratio))
		Vfx.magic(world, player.global_position, Palette.HEAL)
	if damage_ratio > 0.0:
		var price := Combat.make_secondary_hit(null, roundi(player.get_max_hp() * damage_ratio))
		price.unavoidable = true
		player.take_hit(price)
	if gold > 0:
		world.spawn_gold(at, gold)
	if item_quality > 0.0:
		var item := world.pick_random_item()
		for attempt in 10:
			if item is EquipmentDef:
				break
			item = world.pick_random_item()
		if item:
			world.spawn_loot(item, at + Vector2(0, 28), item_quality)
	match gift:
		Gift.PERK:
			Events.perk_offer_requested.emit(PerkDef.Rarity.COMMON, "A gift", "Choose an upgrade")
		Gift.RELIC:
			Events.perk_offer_requested.emit(PerkDef.Rarity.RARE, "Relic", "Choose a relic")
	if monsters > 0:
		(func() -> void:
			for i in monsters:
				var def := world.pick_monster()
				if def == null:
					return
				var monster := world.spawn_monster(def, world.find_open_point_near(at, 60.0))
				if elite_monsters:
					world.make_elite(monster)
				monster.target = player
				Vfx.puff(world, monster.global_position)
		).call_deferred()
	Effect.apply_all(effects, player, Vector2.DOWN)
