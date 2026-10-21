class_name NoConsumableRule
extends PactRule
## Use nothing from the belt or the bag during the fight: no potion, no bomb, no scroll.

func describe(_player_now: Player) -> String:
	return tr("Use no potion, bomb or scroll until the last foe falls.")


func status_text() -> String:
	return tr("Fasting") if not is_broken else tr("Fast broken")


func _on_begin() -> void:
	_player.consumable_used.connect(_on_used)


func _on_finish() -> void:
	if _player and _player.consumable_used.is_connected(_on_used):
		_player.consumable_used.disconnect(_on_used)


func _on_used(_item: ItemDef) -> void:
	_break()
