class_name MonsterDrops
extends RefCounted
## What a slain monster pays the hero (Monster.drops): its XP, its loot table, a rank's extra
## drops and trophy, runes and gold, all landing at its loot_origin(). Summons pay nothing, a
## monster fallen down a hole only its XP (Monster._on_died() decides which). Every roll is on the
## floor's dice (World.rng), in the order the floor's seed expects.

## XP times this (a rank's: MonsterRankDef.xp_multiplier).
var xp_multiplier := 1
## Random items dropped beside its loot table (a rank's: MonsterRankDef.bonus_drops).
var bonus_drops := 0

var _monster: Monster


func _init(monster: Monster) -> void:
	_monster = monster


## Its XP to the hero who slew it (or pushed it into a hole).
func pay_xp(killer: Actor) -> void:
	if killer is Player:
		(killer as Player).gain_xp(_monster.def.xp_reward * xp_multiplier)


## Everything it pays when slain: XP, loot, a rank's extras, runes and gold.
func pay_all(killer: Actor) -> void:
	var monster := _monster
	var world := monster.world
	pay_xp(killer)
	var config := world.config()
	var rank := monster.rank
	var quality := monster.brain.loot_quality(config) if monster.brain else (rank.loot_quality if rank else 1.0)
	var drop_at := origin()
	if monster.def.loot:
		for item in monster.def.loot.roll(world.rng, world.rules.loot_chance()):
			var offset := Vector2.from_angle(world.rng.randf() * TAU) * world.rng.randf_range(4.0, 14.0)
			world.spawn_loot(item, drop_at + offset, quality)
	for i in bonus_drops:
		var item := world.pick_random_item()
		if item:
			world.spawn_loot(item, drop_at + Vector2.from_angle(world.rng.randf() * TAU) * world.rng.randf_range(6.0, 16.0), quality)
	if rank and not monster.is_boss() and killer is Player and world.boons.elite_magic_drop:
		world.drop_trophy(drop_at + Vector2.from_angle(world.rng.randf() * TAU) * 12.0)
	# Runes: always from a boss, often from elites and up, rarely from the others.
	var rune_at := drop_at + Vector2.from_angle(world.rng.randf() * TAU) * world.rng.randf_range(8.0, 18.0)
	if monster.is_boss():
		for i in config.boss_runes:
			world.drop_rune(rune_at + Vector2(i * 14.0, 0))
	else:
		world.drop_rune(rune_at, config.ranked_rune_chance if rank else config.rune_chance)
	_drop_gold()


func _drop_gold() -> void:
	var monster := _monster
	var world := monster.world
	var config := world.config()
	var multiplier := config.boss_gold_multiplier if monster.is_boss() else 1.0
	if monster.rank:
		multiplier *= monster.rank.gold_multiplier
	if multiplier > 1.0 or world.rng.randf() < config.gold_drop_chance:
		world.spawn_gold(origin(), config.gold_for_kill(world.depth, multiplier, world.rng))


## Where what it drops lands: its feet, or in front of a huge body (MonsterDef.loot_offset), on
## open ground the hero can reach.
func origin() -> Vector2:
	var monster := _monster
	if monster.def.loot_offset == Vector2.ZERO:
		return monster.global_position
	var at := monster.global_position + monster.def.loot_offset
	return at if monster.world.is_solid_ground(at) else monster.world.find_open_point_near(at, 32.0)
