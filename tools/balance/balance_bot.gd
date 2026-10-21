class_name BalanceBot
extends RefCounted
## A bot playing the hero through the real input actions (like the touch controls do), one
## physics frame at a time (step()). Two styles:
## - FACE_TANK: walks into attack range of its target and holds attack, uses the weapon's skills
##   (and the learned spell) whenever they are ready; never rolls, never drinks. What a player
##   does who ignores the boss' patterns.
## - KITE: keeps its target at the weapon's range (melee: the edge of its reach) and attacks
##   whenever in reach (attacks don't root the hero), even while stepping aside. It reads each
##   threat as a player would: steps out of a swing's reach or a skill's circle, off a leap's
##   line, sideways from shots heading its way, off blinking arena cells and live traps; it
##   rolls only when the blow lands within the roll's invulnerability (late, not early), and
##   only where the whole roll is solid ground (no pit, crack or wall). It holds the hit that
##   would set off a boss' shockwave when its roll isn't ready. A decent player, not a perfect one.

enum Style { FACE_TANK, KITE }

const STYLE_NAMES := { "face_tank": Style.FACE_TANK, "kite": Style.KITE }
const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"attack",
	&"skill_1", &"skill_2", &"skill_3", &"skill_4", &"quick_item"]
## Shots closer than this, heading at the hero, are dodged.
const SHOT_ALERT := 120.0
## A wind-up this far along (0..1) makes the kite bot roll.
const ROLL_AT_TELEGRAPH := 0.55
const REPATH_FRAMES := 15

var style: Style = Style.FACE_TANK
var player: Player
var world: World
## Who it fights (a boss); null: the nearest monster.
var focus: Monster
## When above 0: stand this far from the target (centre to centre) whatever the weapon (the lab
## measures extra projectiles at 64, 128, 256 px).
var hold_distance := 0.0
## The same for every bot made while it is above 0 (the compound checks set it around a measure).
static var hold_override := 0.0
## Skill presses and rolls, for the logs.
var skills_used := 0
var rolls := 0

var _hazards: Array[Vector2i] = []
var _hazard_timer := 0
var _path := PackedVector2Array()
var _path_timer := 0
var _pressed := {}
## Released this frame: not pressed again before the next one (a press and a release in the
## same frame is no press at all for Input.is_action_just_pressed).
var _released := {}


static func create(style_name: String, hero: Player, in_world: World, boss: Monster = null) -> BalanceBot:
	var bot := BalanceBot.new()
	bot.style = STYLE_NAMES.get(style_name, Style.FACE_TANK)
	bot.player = hero
	bot.world = in_world
	bot.focus = boss
	return bot


## Lets go of every action (call when the fight ends).
static func release_all() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func step() -> void:
	if player == null or player.is_dead:
		release_all()
		return
	# Skill buttons are read as "just pressed": let go every other frame.
	_released = _pressed.duplicate()
	for action: StringName in _pressed.keys():
		Input.action_release(action)
	_pressed.clear()
	var target := _target()
	if target == null:
		_move(Vector2.ZERO)
		Input.action_release(&"attack")
		return
	if style == Style.FACE_TANK:
		_face_tank(target)
	else:
		_kite(target)


func _target() -> Monster:
	if is_instance_valid(focus) and not focus.is_dead:
		return focus
	var best: Monster = null
	var best_distance := INF
	for actor in world.get_hostiles(player.faction):
		var monster := actor as Monster
		if monster == null:
			continue
		var distance := player.global_position.distance_to(monster.global_position)
		if distance < best_distance:
			best = monster
			best_distance = distance
	return best


# --- Styles ----------------------------------------------------------------------------

func _face_tank(target: Monster) -> void:
	var distance := player.global_position.distance_to(target.global_position)
	var wanted := _wanted_distance(target)
	if distance > wanted:
		_move(_way_to(target.global_position))
	elif (hold_distance > 0.0 or hold_override > 0.0) and distance < wanted * 0.85:
		_move(_safe_direction(target.global_position.direction_to(player.global_position)))
	else:
		_move(Vector2.ZERO)
	_hold_attack(distance <= _attack_reach(target))
	_use_skills(distance, target)


func _kite(target: Monster) -> void:
	var to_target := target.global_position - player.global_position
	var distance := to_target.length()
	# A boss answers a streak of hits with a shockwave: with no roll ready to get through it,
	# hold the last hit until the streak runs out (what a player learns after one blast).
	var hold_fire := target.is_boss() and target._shockwave_after > 0 and target._streak_time > 0.0 \
		and target._hit_streak >= target._shockwave_after - 1 and not player.skills.is_ready(0)
	var in_reach := distance <= _attack_reach(target) and not hold_fire
	var threat := _threat()
	if threat.danger:
		_move(_safe_direction(threat.away))
		if threat.urgent and player.skills.is_ready(0):
			var roll := _roll_direction(threat.away)
			if roll != Vector2.ZERO:
				_move(roll)  # the roll goes where the hero moves
				if _press(&"skill_1"):
					rolls += 1
		# Attacks don't root the hero: keep hitting while stepping aside if in reach.
		_hold_attack(in_reach)
		return
	if hold_fire:
		# Side hits (chains, shards, thorns) can still finish the streak: wait outside the ring.
		var ring := (target.def as BossDef).shockwave_radius + target.radius + player.radius + 10.0
		_move(_safe_direction(-to_target.normalized()) if distance < ring else Vector2.ZERO)
		_hold_attack(false)
		return
	var wanted := _wanted_distance(target)
	if distance > wanted:
		_move(_way_to(target.global_position))
	elif _is_ranged() and distance < wanted * 0.6:
		_move(_safe_direction(-to_target.normalized()))
	else:
		_move(Vector2.ZERO)
	_hold_attack(in_reach)
	_use_skills(distance, target)


# --- Reading the fight -------------------------------------------------------------------

## { danger, urgent, away }: something about to hit the hero, and which way is out. `urgent`:
## it lands within the roll's invulnerability (a decent player rolls through it, not before).
func _threat() -> Dictionary:
	var away := Vector2.ZERO
	var urgent := false
	var here := player.global_position
	for actor in world.get_hostiles(player.faction):
		var monster := actor as Monster
		if monster == null:
			continue
		var offset := here - monster.global_position
		var distance := offset.length()
		var direction := offset.normalized() if distance > 0.1 else Vector2.DOWN
		# A boss' shockwave ring (it answers too many hits in a row, and roars into a phase):
		# the cooldown is set to 3 s when the ring appears, the blast follows 0.35-0.45 s later.
		if monster.is_boss() and monster._shockwave_cooldown > 2.5:
			var ring := (monster.def as BossDef).shockwave_radius + monster.radius + player.radius + 20.0
			if distance < ring:
				away += direction * 2.0
				urgent = urgent or monster._shockwave_cooldown <= 2.75
			continue
		if monster.telegraph <= 0.0:
			continue
		var skill := monster.casting_skill()
		if skill == null:
			# A swing: step out of reach; roll through it if still in reach as it lands.
			var reach := monster.attack_range(player)
			if distance < reach + 30.0:
				away += direction * (1.0 + monster.telegraph)
				urgent = urgent or (monster.telegraph >= 0.75 and distance < reach + 10.0)
			continue
		match _skill_kind(skill):
			"area":
				var radius := _area_reach(skill) + player.radius + 20.0
				if distance < radius:
					away += direction * (1.0 + monster.telegraph)
					urgent = urgent or (monster.telegraph >= 0.75 and distance < radius - 15.0)
			"dash":
				# Aimed at where the hero stood when the cast began: step off that line.
				var side := monster.facing.orthogonal()
				if side.dot(offset) < 0.0:
					side = -side
				if distance < 420.0:
					away += side * 1.5
					urgent = urgent or (monster.telegraph >= 0.85 and absf(offset.dot(monster.facing.orthogonal())) < 70.0)
			"shots":
				# A ring or a fan leaves the caster: close, roll through it as it is let go.
				if distance < 170.0:
					urgent = urgent or monster.telegraph >= 0.85
	for node in world.get_node("Projectiles").get_children():
		var shot := node as Projectile
		if shot == null or shot._done or (shot._faction == Actor.Faction.PLAYER and not shot._hits_everyone):
			continue
		var offset := here - shot.global_position
		var along := offset.dot(shot._direction)
		if along <= -player.radius or along > SHOT_ALERT * 2.5:
			continue
		var miss := absf(offset.cross(shot._direction))
		if miss > player.radius + shot._spec.radius + 10.0:
			continue
		var time_to_hit := maxf(along, 0.0) / maxf(shot._spec.speed, 1.0)
		var side := shot._direction.orthogonal()
		if side.dot(offset) < 0.0:
			side = -side
		away += side * 1.5
		urgent = urgent or time_to_hit < 0.15
	# The arena's warnings (cells about to crumble or grow spikes) and live traps.
	for cell in _hazard_cells():
		var offset := here - world.map.cell_to_world(cell)
		if offset.length() < world.map.tile_size * 1.2:
			away += offset.normalized() if offset.length() > 0.1 else Vector2.DOWN
	return { "danger": away != Vector2.ZERO, "urgent": urgent, "away": away.normalized() }


## What a monster's skill does, for dodging: "area" (a circle around or in front of it),
## "dash" (a leap or rush along its aim), "shots" (projectiles), "" (summons, buffs).
static func _skill_kind(skill: SkillDef) -> String:
	if skill.telegraph_radius > 0.0:
		return "area"
	for effect in skill.effects:
		if effect is DashStrikeEffect or effect is DashEffect:
			return "dash"
	for effect in skill.effects:
		if effect is DamageAreaEffect:
			return "area"
		if effect is ProjectileEffect:
			return "shots"
	return ""


## How far a skill's circle reaches from its caster.
static func _area_reach(skill: SkillDef) -> float:
	var reach := skill.telegraph_radius
	for effect in skill.effects:
		var area := effect as DamageAreaEffect
		if area:
			reach = maxf(reach, area.offset + area.radius)
	return reach


## Cells to keep off: the arena's blinking warnings, traps that are warning or striking.
## (Read every few frames: walking the tree each frame is slow.)
func _hazard_cells() -> Array[Vector2i]:
	_hazard_timer -= 1
	if _hazard_timer > 0:
		return _hazards
	_hazard_timer = 6
	_hazards.clear()
	for node in world.get_node("Effects").get_children():
		if node is CellWarning:
			_hazards.append_array((node as CellWarning)._cells)
	for node in world.get_node("Entities").get_children():
		if node is Trap and (node as Trap).phase != Trap.Phase.IDLE:
			_hazards.append(world.map.world_to_cell((node as Trap).global_position))
	return _hazards


## The way to roll: close to `wanted`, and the whole roll on solid ground (no pit, crack, wall).
## ZERO when there is no safe roll.
func _roll_direction(wanted: Vector2) -> Vector2:
	var here := player.global_position
	var best := Vector2.ZERO
	var best_score := -INF
	for i in 16:
		var direction := Vector2.from_angle(i * TAU / 16.0)
		var safe := true
		for step: float in [40.0, 80.0, 120.0, 160.0]:
			var probe := here + direction * step
			if not world.is_solid_ground(probe) or world.nav.is_blocked(world.map.world_to_cell(probe)) or not world.has_line_of_sight(here, probe):
				safe = false
				break
		if not safe:
			continue
		var score := direction.dot(wanted)
		if score > best_score:
			best_score = score
			best = direction
	return best


func _is_ranged() -> bool:
	var weapon := player.get_weapon()
	return weapon != null and weapon.kind == WeaponDef.Kind.RANGED


## How far the weapon's hit reaches against `target` (centre to centre).
func _attack_reach(target: Actor) -> float:
	var weapon := player.get_weapon()
	if weapon == null:
		return 0.0
	if weapon.kind == WeaponDef.Kind.MELEE:
		return player.radius + weapon.reach + target.radius
	return weapon.reach * 0.9


## Where the bot stands: melee in reach (with a little margin), ranged at a safe part of its range.
func _wanted_distance(target: Actor) -> float:
	if hold_distance > 0.0:
		return hold_distance
	if hold_override > 0.0:
		return hold_override
	var weapon := player.get_weapon()
	if weapon == null:
		return player.radius + target.radius
	if weapon.kind == WeaponDef.Kind.MELEE:
		return player.radius + target.radius + weapon.reach * 0.6
	if style == Style.FACE_TANK:
		return minf(weapon.reach * 0.5, 180.0)
	return minf(weapon.reach * 0.65, 260.0)


func _use_skills(distance: float, target: Actor) -> void:
	var reach := maxf(_attack_reach(target) + 60.0, 140.0) if not _is_ranged() else _attack_reach(target)
	if distance > reach:
		return
	for i in range(1, player.skills.skills.size()):
		if player.skills.skills[i] and player.skills.is_ready(i) and _press(StringName("skill_%d" % (i + 1))):
			skills_used += 1  # presses (a press on cooldown or out of reach does nothing)
			return  # one a frame, like thumbs


# --- Moving -----------------------------------------------------------------------------

## Straight at `point` when the way is clear and solid, else along the path.
func _way_to(point: Vector2) -> Vector2:
	var here := player.global_position
	if world.has_line_of_sight(here, point) and _solid_line(here, point):
		_path.clear()
		return here.direction_to(point)
	_path_timer -= 1
	if _path_timer <= 0 or _path.is_empty():
		_path = world.find_path(here, point)
		_path_timer = REPATH_FRAMES
	while _path.size() > 0 and here.distance_to(_path[0]) < 12.0:
		_path.remove_at(0)
	return here.direction_to(_path[0]) if _path.size() > 0 else here.direction_to(point)


func _solid_line(from: Vector2, to: Vector2) -> bool:
	var steps := ceili(from.distance_to(to) / 16.0)
	for i in range(1, steps):
		if not world.is_solid_ground(from.lerp(to, float(i) / steps)):
			return false
	return true


## The direction closest to `wanted` that doesn't run into a wall, a hole or cracked floor.
func _safe_direction(wanted: Vector2) -> Vector2:
	if wanted == Vector2.ZERO:
		return Vector2.ZERO
	var here := player.global_position
	var best := wanted
	var best_score := -INF
	for i in 16:
		var direction := Vector2.from_angle(i * TAU / 16.0)
		var score := direction.dot(wanted)
		var probe := here + direction * 56.0
		if not world.is_solid_ground(probe) or not world.has_line_of_sight(here, probe) or world.nav.is_blocked(world.map.world_to_cell(probe)):
			score -= 3.0
		if score > best_score:
			best_score = score
			best = direction
	return best


func _move(direction: Vector2) -> void:
	_strength(&"move_left", maxf(-direction.x, 0.0))
	_strength(&"move_right", maxf(direction.x, 0.0))
	_strength(&"move_up", maxf(-direction.y, 0.0))
	_strength(&"move_down", maxf(direction.y, 0.0))


## Attacks in reach: taps the attack button (a frame down, a frame up), as fast as the weapon
## swings. Holding it would charge the weapon's charged attack instead: the measures keep to
## basic attacks.
func _hold_attack(on: bool) -> void:
	if on:
		_press(&"attack")
	elif not _pressed.has(&"attack"):
		Input.action_release(&"attack")


## Presses a button for one frame. False when it was let go this very frame (next frame then).
func _press(action: StringName) -> bool:
	if _released.has(action):
		return false
	Input.action_press(action)
	_pressed[action] = true
	return true


static func _strength(action: StringName, value: float) -> void:
	if value > 0.01:
		Input.action_press(action, value)
	else:
		Input.action_release(action)
