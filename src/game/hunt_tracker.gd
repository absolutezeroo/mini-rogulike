class_name HuntTracker
extends Node
## Watches the run for the bestiary challenges (HuntChallenge): how each monster was slain
## (an elite, pushed into a hole, a crit, with what weapon, untouched...), kill streaks, and
## each boss fight (how long, potions drunk, HP lost). A challenge met is done for good and
## paid in souls (Profile). Owned by the Game; pauses with it (its clock too).

var player: Player
var content: ContentDB

## Seconds of play (stops while paused).
var _clock := 0.0
## Recent kill times by monster id (streaks).
var _kill_times := {}
## The boss fight: when it started (-1: none), HP lost and consumables used since.
var _fight_start := -1.0
var _fight_hp_lost := 0
var _fight_potions := 0

const STREAK_MEMORY := 12


func _ready() -> void:
	Events.monster_killed.connect(_on_monster_killed)
	Events.boss_started.connect(func(_boss: Monster) -> void:
		_fight_start = _clock
		_fight_hp_lost = 0
		_fight_potions = 0)
	Events.depth_changed.connect(func(_depth: int) -> void:
		_fight_start = -1.0
		_kill_times.clear())


func bind(new_player: Player) -> void:
	player = new_player
	_fight_start = -1.0
	_kill_times.clear()
	player.damaged.connect(func(amount: int) -> void:
		if _fight_start >= 0.0:
			_fight_hp_lost += amount)
	player.consumable_used.connect(func(_item: ItemDef) -> void:
		if _fight_start >= 0.0:
			_fight_potions += 1)


func _physics_process(delta: float) -> void:
	_clock += delta


## How `monster` was just slain, for HuntChallenge.met().
func kill_context(monster: Monster) -> Dictionary:
	var times: Array = _kill_times.get(monster.def.id, [])
	var weapon: WeaponDef = player.get_weapon() if player else null
	var base: WeaponDef = weapon
	if weapon and weapon.base_item is WeaponDef:
		base = weapon.base_item as WeaponDef
	var max_hp := maxi(player.get_max_hp(), 1) if player else 1
	return {
		"elite": monster.is_elite(),
		"pushed_in": monster.has_fallen() and _by_hero(monster.last_attacker),
		"crit": monster.last_hit != null and monster.last_hit.is_crit and _by_hero(monster.last_hit.source),
		"weapon": weapon,
		"weapon_base": base,
		"untouched": player != null and monster.noticed_frame >= 0 and player.last_hurt_frame < monster.noticed_frame,
		"kill_times": times,
		"now": _clock,
		"fight_time": (_clock - _fight_start) if monster.is_boss() and _fight_start >= 0.0 else -1.0,
		"potions_in_fight": _fight_potions,
		"hp_lost_in_fight": float(_fight_hp_lost) / max_hp,
	}


## `who` is the hero (and still there: `is` on a freed instance is an error).
static func _by_hero(who: Object) -> bool:
	return is_instance_valid(who) and who is Player


func _on_monster_killed(monster: Monster) -> void:
	if player == null or not is_instance_valid(player) or player.is_dead or content == null or content.bestiary == null:
		return
	if monster.world != player.world or not _by_hero(monster.last_attacker):
		return  # slain by something else (a trap, another monster)
	var times: Array = _kill_times.get(monster.def.id, [])
	times.append(_clock)
	if times.size() > STREAK_MEMORY:
		times.pop_front()
	_kill_times[monster.def.id] = times
	var kill := kill_context(monster)
	for challenge in content.bestiary.challenges_for(monster.def):
		if Profile.is_challenge_done(monster.def.id, challenge.id) or not challenge.met(kill):
			continue
		if Profile.complete_challenge(monster.def.id, challenge.id, challenge.souls):
			Events.hunt_challenge_done.emit(monster.def, challenge)
