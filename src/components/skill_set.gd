class_name SkillSet
extends RefCounted
## The skills of an actor and their cooldowns.

var skills: Array[SkillDef] = []
var _cooldowns := PackedFloat32Array()


func set_skills(list: Array[SkillDef]) -> void:
	skills = list.duplicate()
	_cooldowns.resize(skills.size())
	_cooldowns.fill(0.0)


func tick(delta: float) -> void:
	for i in _cooldowns.size():
		_cooldowns[i] = maxf(_cooldowns[i] - delta, 0.0)


func is_ready(index: int) -> bool:
	return index >= 0 and index < skills.size() and _cooldowns[index] <= 0.0


## 1 right after use, 0 when ready. Used by the HUD.
func cooldown_ratio(index: int) -> float:
	if index < 0 or index >= skills.size() or skills[index].cooldown <= 0.0:
		return 0.0
	return _cooldowns[index] / skills[index].cooldown


func try_use(index: int, user: Actor, aim: Vector2) -> bool:
	if not is_ready(index):
		return false
	_cooldowns[index] = skills[index].cooldown
	skills[index].activate(user, aim)
	return true
