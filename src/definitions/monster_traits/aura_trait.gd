class_name AuraTrait
extends MonsterTrait
## Wears an aura as the hero does (AuraDef, AuraVfx): the Nameless Keeper keeps the one the hero
## he was wore. For the look alone: it changes nothing of the fight.

@export var aura: AuraDef


func on_spawn(monster: Monster) -> void:
	var vfx := AuraVfx.make(aura, monster.head_height - 4.0, monster.radius)
	if vfx:
		vfx.wear_on(monster, Vector2(0, monster.radius * 0.7 + 1.0))
		monster.died.connect(func(_actor: Actor) -> void:
			if is_instance_valid(vfx):
				vfx.hide(), CONNECT_ONE_SHOT)
