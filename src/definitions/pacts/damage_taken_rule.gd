class_name DamageTakenRule
extends PactRule
## Lose no more than a share of your max Health in the whole fight. 0: take no damage at all
## (the Untouched). Any damage counts: blows, shots, traps, burns, falls; a ward that soaks a
## blow whole keeps the rule.

## Share of the hero's max Health (when the fight begins) that may be lost. 0: none.
@export_range(0.0, 0.9, 0.05) var allowed_share := 0.0

var _lost := 0
var _allowed := 0


func describe(player: Player) -> String:
	if allowed_share <= 0.0:
		return tr("Take no damage until the last foe falls.")
	return tr("Lose no more than %d Health in all until the last foe falls.") % allowed(player)


func status_text() -> String:
	if allowed_share <= 0.0:
		return tr("Untouched") if not is_broken else tr("Touched")
	return tr("Health lost: %d / %d") % [_lost, _allowed]


## The Health that may be lost, for this hero.
func allowed(player: Player) -> int:
	return roundi(player.get_max_hp() * allowed_share) if player else 0


func _on_begin() -> void:
	_lost = 0
	_allowed = allowed(_player)
	_player.damaged.connect(_on_damaged)


func _on_finish() -> void:
	if _player and _player.damaged.is_connected(_on_damaged):
		_player.damaged.disconnect(_on_damaged)


func _on_damaged(amount: int) -> void:
	if amount <= 0:
		return
	_lost += amount
	if _lost > _allowed:
		_break()
