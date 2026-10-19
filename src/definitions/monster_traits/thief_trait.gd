class_name ThiefTrait
extends MonsterTrait
## Snatches gold when it hits the hero, then runs away for a while. Slain, it drops what it
## took with interest; lost down a hole (or summoned), the hero simply gets it back.

## Gold taken per hit: `steal` + `steal_per_depth` per floor (never more than the hero has).
@export var steal: int = 6
@export var steal_per_depth: float = 1.0
## Seconds running away after a theft (no attacks meanwhile).
@export var flee_time: float = 3.5
## Dropped when slain: what it took x `interest` + `bonus`.
@export var interest: float = 1.5
@export var bonus: int = 5


## Gold the monster carries.
func stolen(monster: Monster) -> int:
	return monster.trait_state(self).get("stolen", 0)


func is_fleeing(monster: Monster) -> bool:
	return monster.trait_state(self).get("flee", 0.0) > 0.0


func update(monster: Monster, delta: float) -> void:
	var state := monster.trait_state(self)
	state.flee = maxf(state.get("flee", 0.0) - delta, 0.0)


func steer(monster: Monster, direction: Vector2) -> Vector2:
	if is_fleeing(monster) and is_instance_valid(monster.target):
		return monster.target.global_position.direction_to(monster.global_position)
	return direction


func can_attack(monster: Monster) -> bool:
	return not is_fleeing(monster)


func on_hit_player(monster: Monster, player: Player) -> void:
	if player.gold <= 0:
		return
	var amount := mini(steal + roundi(monster.world.depth * steal_per_depth), player.gold)
	player.spend_gold(amount)
	var state := monster.trait_state(self)
	state.stolen = stolen(monster) + amount
	state.flee = flee_time
	monster.world.spawn_floating_text(player.head_position(), "-%d gold" % amount, Palette.GOLD)
	Sfx.play_at(Sfx.bank.coin, monster.global_position, 0.0, 0.7)


func on_died(monster: Monster, _killer: Actor, fell: bool, rewards: bool) -> void:
	var amount := stolen(monster)
	if amount <= 0:
		return
	var world := monster.world
	if fell or not rewards:
		if world.player and not world.player.is_dead:
			world.player.add_gold(amount)
			world.spawn_floating_text(world.player.head_position(), "+%d gold" % amount, Palette.GOLD)
	else:
		world.spawn_gold(monster.global_position, roundi(amount * interest) + bonus)
	monster.trait_state(self).stolen = 0


func describe() -> String:
	return "Steals gold and runs. Slay it to get it back."
