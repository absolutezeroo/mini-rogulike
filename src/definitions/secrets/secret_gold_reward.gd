class_name SecretGoldReward
extends SecretRewardDef
## A hoard of coins on the secret room's floor (more the deeper; the floor's gold rules apply).

@export var gold: Vector2i = Vector2i(30, 50)
@export var gold_per_depth: float = 6.0
## Piles it is spread in.
@export_range(1, 12) var piles: int = 6


func place(world: World, cell: Vector2i, rng: RandomNumberGenerator) -> Array[Node]:
	var result: Array[Node] = []
	var amount := roundi(world.rules.gold(rng.randi_range(gold.x, gold.y) + gold_per_depth * world.depth) * world.boons.gold_scale)
	var center := world.map.cell_to_world(cell)
	for i in piles:
		var share := floori(float(amount) / piles) + (1 if i < amount % piles else 0)
		if share <= 0:
			continue
		var at := center + Vector2.from_angle(TAU * i / piles) * rng.randf_range(10.0, 30.0)
		var coin := GoldPickup.create(at, share, world)
		world.add_entity(coin)
		result.append(coin)
	return result
