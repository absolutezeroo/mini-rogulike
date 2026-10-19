class_name SkillSet
extends RefCounted
## The skills of an actor and their cooldowns. A slot may be empty (null).

const MAX_COOLDOWN_REDUCTION := 0.6

var skills: Array[SkillDef] = []
var _cooldowns := PackedFloat32Array()
## Length of the cooldown currently running in each slot (for the HUD pie).
var _durations := PackedFloat32Array()


func set_skills(list: Array[SkillDef]) -> void:
	replace(list, 0.0)


## Swaps the skill list (new weapon, new spell). Skills kept from the old list keep their
## cooldown; new ones start with `new_skill_cooldown` (so swapping weapons can't skip cooldowns).
func replace(list: Array[SkillDef], new_skill_cooldown: float) -> void:
	var old := {}
	for i in skills.size():
		old[skills[i]] = [_cooldowns[i], _durations[i]]
	skills = list.duplicate()
	_cooldowns.resize(skills.size())
	_durations.resize(skills.size())
	for i in skills.size():
		var kept: Array = old.get(skills[i], [new_skill_cooldown, new_skill_cooldown])
		_cooldowns[i] = kept[0]
		_durations[i] = kept[1]


func tick(delta: float) -> void:
	for i in _cooldowns.size():
		_cooldowns[i] = maxf(_cooldowns[i] - delta, 0.0)


func is_ready(index: int) -> bool:
	return index >= 0 and index < skills.size() and skills[index] != null and _cooldowns[index] <= 0.0


## 1 right after use, 0 when ready. Used by the HUD.
func cooldown_ratio(index: int) -> float:
	if index < 0 or index >= skills.size() or _durations[index] <= 0.0:
		return 0.0
	return _cooldowns[index] / _durations[index]


## Ready again at once (an echoing perk).
func reset_cooldown(skill: SkillDef) -> void:
	var index := skills.find(skill)
	if index >= 0:
		_cooldowns[index] = 0.0


func try_use(index: int, user: Actor, aim: Vector2) -> bool:
	if not is_ready(index):
		return false
	var reduction := clampf(user.get_stats().cooldown_reduction, 0.0, MAX_COOLDOWN_REDUCTION)
	_durations[index] = skills[index].cooldown * (1.0 - reduction)
	_cooldowns[index] = _durations[index]
	skills[index].activate(user, aim)
	user.perks.on_skill_used(user, skills[index])
	return true
