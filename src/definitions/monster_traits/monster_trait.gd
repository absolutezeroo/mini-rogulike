class_name MonsterTrait
extends Resource
## A special way a kind of monster fights: a shield, stealing gold, bursting when it dies,
## splitting into smaller ones... Listed in MonsterDef.traits, the monster calls these hooks.
## One trait resource is shared by every monster of that kind: keep per-monster values in
## `monster.trait_state(self)`, never in the trait itself.


## Once, when the monster is set up.
func on_spawn(_monster: Monster) -> void:
	pass


## Every physics frame, while alive.
func update(_monster: Monster, _delta: float) -> void:
	pass


## Changes where the monster walks (`direction` from its AI).
func steer(_monster: Monster, direction: Vector2) -> Vector2:
	return direction


## False to stop the monster from attacking for now.
func can_attack(_monster: Monster) -> bool:
	return true


## Last say on the damage of a hit, after armor.
func incoming_damage(_monster: Monster, _hit: HitInfo, damage: int) -> int:
	return damage


## The monster just hurt the hero.
func on_hit_player(_monster: Monster, _player: Player) -> void:
	pass


## The monster died. `fell`: down a hole (nothing comes out of it).
## `rewards`: false for summoned monsters (they give nothing).
func on_died(_monster: Monster, _killer: Actor, _fell: bool, _rewards: bool) -> void:
	pass


## Drawn under the monster's body (see MonsterOverlay).
func draw_under(_monster: Monster, _canvas: CanvasItem) -> void:
	pass


## A line for the bestiary.
func describe() -> String:
	return ""
