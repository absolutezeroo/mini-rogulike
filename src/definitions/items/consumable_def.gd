class_name ConsumableDef
extends ItemDef
## A single-use item. Runs its effects, exactly like a skill does.

@export var effects: Array[Effect] = []
@export var sound: AudioStream


func get_type_label() -> String:
	return tr("Consumable")


## Taken from the bag and used (PlayerPack.consume()).
func use_from_bag(player: Player) -> void:
	player.inventory.remove(self)
	player.pack.consume(self)


func use(user: Actor, aim: Vector2) -> void:
	Sfx.play_at(sound, user.global_position)
	# Its heals and hits are credited to it (Actor.healed, HitInfo.via), delayed ones too.
	Actor.with_source(StringName("item:%s" % id), func() -> void: Effect.apply_all(effects, user, aim))
