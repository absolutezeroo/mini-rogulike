class_name WinUnlock
extends CosmeticUnlock
## Opened by a won descent: on `difficulty` (a DifficultyDef id), or on any one when empty.

@export var difficulty: StringName = &""


func is_met() -> bool:
	if difficulty.is_empty():
		return Profile.victories > 0 or Profile.wins.values().any(func(count: Variant) -> bool: return int(count) > 0)
	return int(Profile.wins.get(String(difficulty), 0)) > 0


func describe() -> String:
	if difficulty.is_empty():
		return TranslationServer.tr("Win a descent.")
	var def := _difficulty()
	var shown := TranslationServer.tr(def.display_name) if def else String(difficulty)
	return TranslationServer.tr("Win a descent on {difficulty}.").format({ "difficulty": shown })


func _difficulty() -> DifficultyDef:
	var path := "res://data/difficulties/%s.tres" % difficulty
	return load(path) as DifficultyDef if ResourceLoader.exists(path) else null
