class_name BalanceBot
extends RefCounted
## A bot playing the hero through the real input actions (like the touch controls do), one
## physics frame at a time (step()). The styles:
## - FACE_TANK: walks into attack range of its target and holds attack, uses the weapon's skills
##   (and the learned spell) whenever they are ready; never rolls. What a player
##   does who ignores the boss' patterns.
## - KITE: keeps its target at the weapon's range (melee: the edge of its reach) and attacks
##   whenever in reach (attacks don't root the hero), even while stepping aside. It reads each
##   threat as a player would: steps out of a swing's reach or a skill's circle, off a leap's
##   line, sideways out of a fan's cone, sideways from shots heading its way, off blinking arena
##   cells, live traps and a wyrm's burning coils, and stays out of a cast's later blows (a
##   wider second ring, a second volley) until they have landed; it rolls only when the blow
##   lands within the roll's invulnerability (late, not early), over holes if need be but only
##   to land on solid ground with nothing in the way. It never walks into a hole or cracked
##   floor it can see, nor dashes (a skill that carries it) into one. It holds the hit that
##   would set off a boss' shockwave when its roll isn't ready. A decent player, not a perfect one.
## - PLAYER ("player"): the kite bot with a human's reaction time (REACTION): a threat (a wind-up,
##   a shot, a shockwave's ring) is only answered once it has been there that long, so short
##   wind-ups and fast shots land. An average player, for the gauntlet.
## No bot drinks, except while `drink_below` is set (the gauntlet, which hands out potions).

enum Style { FACE_TANK, KITE }

const STYLE_NAMES := { "face_tank": Style.FACE_TANK, "kite": Style.KITE, "player": Style.KITE }
## Seconds before the "player" bot answers what it sees (a visual reaction on a phone, with the
## decision: about 0.25-0.35 s for an average player).
const REACTION := 0.3
## In the Deeps, monsters farther than this are left alone: the bot makes for the Dawn Breach.
const DEEPS_FIGHT_RANGE := 110.0
## Frames between two potions (the first one's heal shows first).
const DRINK_WAIT := 45
const ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"attack",
	&"skill_1", &"skill_2", &"skill_3", &"skill_4", &"quick_item"]
## Shots closer than this, heading at the hero, are dodged.
const SHOT_ALERT := 120.0
## A wind-up this far along (0..1) makes the kite bot roll.
const ROLL_AT_TELEGRAPH := 0.55
const REPATH_FRAMES := 15
## The kite bot keeps this much room (px) between itself and a wyrm's coils.
const COIL_MARGIN := 14.0
## Steps (px) at which the way ahead is probed for holes, and how far ahead (a few frames'
## walk at the hero's speed, 170 a second): a player walks around a hole he sees.
const HOLE_STEP := 6.0
const HOLE_LOOKAHEAD := 30.0
## Points (px) along a roll checked for what would stop it; from ROLL_LANDING on, the ground
## must hold (the Roll goes 150 px; its end, give or take a step).
const ROLL_PROBES: Array[float] = [40.0, 80.0, 120.0, 135.0, 150.0, 165.0]
const ROLL_LANDING := 135.0
## A dashing skill is used only when the ground holds this far around where it ends.
const DASH_LANDING_MARGIN := 32.0
## Seconds after a cast's last delayed blow is due that the bot still keeps out of its way.
const FOLLOW_UP_MARGIN := 0.15

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
## Below this share of max Health, every bot made while it is above 0 drinks what is in the
## belt's first slot (the quick item key; the gauntlet gives it potions). 0: bots never drink.
static var drink_below := 0.0
## Skill presses and rolls, for the logs.
var skills_used := 0
var rolls := 0
## Potions drunk (drink_below), for the logs.
var drinks := 0
var _drink_wait := 0
## Seconds before a threat is answered (0: at once; the "player" style: REACTION).
var reaction := 0.0
## Threat key -> the physics frame it was first seen (reaction).
var _seen := {}

## Monster id -> { skill, aim } of the cast it is making (seen by the bot).
var _casting := {}
## Monster id -> { skill, aim, until (physics frame) }: a cast let go whose later blows are due.
var _follow_ups := {}

var _hazards: Array[Vector2i] = []
## Physics frame the hazard cells were last read (every few frames: walking the tree is slow).
var _hazard_frame := -100
var _path := PackedVector2Array()
var _path_timer := 0
var _pressed := {}
## Released this frame: not pressed again before the next one (a press and a release in the
## same frame is no press at all for Input.is_action_just_pressed).
var _released := {}


static func create(style_name: String, hero: Player, in_world: World, boss: Monster = null) -> BalanceBot:
	var bot := BalanceBot.new()
	bot.style = STYLE_NAMES.get(style_name, Style.FACE_TANK)
	if style_name == "player":
		bot.reaction = REACTION
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
	if is_instance_valid(player.world) and player.world != world:
		# He crossed into another world (the Deeps, the Threshold): play there.
		world = player.world
		_path.clear()
		_hazards.clear()
		_hazard_frame = -100
	# Skill buttons are read as "just pressed": let go every other frame.
	_released = _pressed.duplicate()
	for action: StringName in _pressed.keys():
		Input.action_release(action)
	_pressed.clear()
	_drink()
	var target := _target()
	var deeps := world as AbyssWorld
	if deeps and is_instance_valid(deeps.door) and (target == null or player.global_position.distance_to(target.global_position) > DEEPS_FIGHT_RANGE):
		# The Deeps (a fall): make for the Dawn Breach, fighting only what comes close (as the
		# Deeps' own probe did, balance-log "The Deeps").
		_move(_way_to(deeps.door.global_position))
		if not _pressed.has(&"attack"):
			Input.action_release(&"attack")
		return
	if target == null:
		_move(Vector2.ZERO)
		Input.action_release(&"attack")
		return
	if style == Style.FACE_TANK:
		_face_tank(target)
	else:
		_kite(target)


## A potion when Health runs low (drink_below), not two in a row.
func _drink() -> void:
	if drink_below <= 0.0 or player.belt.count_at(0) <= 0:
		return
	_drink_wait -= 1
	if _drink_wait > 0 or player.hp >= player.get_max_hp() * drink_below:
		return
	if _press(&"quick_item"):
		drinks += 1
		_drink_wait = DRINK_WAIT


func _target() -> Monster:
	if is_instance_valid(focus) and not focus.is_dead and focus.is_inside_tree():
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
				_steer(roll)  # the roll goes where the hero moves (over holes: it lands on solid ground)
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
		# A wyrm's burning coils (WyrmBody), always in sight: step off them as off a live trap.
		var coils := _coils(monster)
		if coils:
			var near := WyrmBody.TOUCH_RADIUS + player.radius + COIL_MARGIN
			for point in coils.segment_points():
				var off := here - point
				if off.length() < near:
					away += (off.normalized() if off.length() > 0.1 else direction) * 1.5
		# A boss' shockwave ring (it answers too many hits in a row, and roars into a phase):
		# the cooldown is set to 3 s when the ring appears, the blast follows 0.35-0.45 s later.
		if monster.is_boss() and monster._shockwave_cooldown > 2.5:
			var ring := (monster.def as BossDef).shockwave_radius + monster.radius + player.radius + 20.0
			if distance < ring and _noticed("ring%d" % monster.get_instance_id()):
				away += direction * 2.0
				urgent = urgent or monster._shockwave_cooldown <= 2.75
			continue
		if reaction > 0.0 and monster.is_boss():
			_seen.erase("ring%d" % monster.get_instance_id())  # the next ring is seen afresh
		var id := monster.get_instance_id()
		if monster.telegraph <= 0.0:
			_seen.erase(id)
			# A cast just let go: its later blows (a wider ring, a second volley, a second leg)
			# come where its warning showed, until its longest delay has passed: keep out, even
			# while it warns of its next move.
			_note_follow_up(monster)
		var later: Dictionary = _follow_ups.get(id, {})
		if not later.is_empty() and Engine.get_physics_frames() < int(later.until):
			var pending: Array = _skill_threat(later.skill, later.aim, 0.0, offset, distance, direction)
			away += pending[0]
		if monster.telegraph <= 0.0:
			continue
		if not _noticed(id):
			continue
		var skill := monster.casting_skill()
		if skill == null:
			# A swing: step out of reach; roll through it if still in reach as it lands.
			var reach := monster.attack_range(player)
			if distance < reach + 30.0:
				away += direction * (1.0 + monster.telegraph)
				urgent = urgent or (monster.telegraph >= 0.75 and distance < reach + 10.0)
			continue
		_casting[id] = { "skill": skill, "aim": monster.facing }
		var threat := _skill_threat(skill, monster.facing, monster.telegraph, offset, distance, direction)
		away += threat[0]
		urgent = urgent or threat[1]
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
		if not _noticed(shot.get_instance_id()):
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
	# Cracked floor (or a warned cell) under the hero's feet: off it before it gives way.
	if player.is_grounded() and not _firm(here):
		var firm := world.nearest_free_point(here)
		if firm.distance_to(here) > 1.0:
			away += here.direction_to(firm) * 3.0
	return { "danger": away != Vector2.ZERO, "urgent": urgent, "away": away.normalized() }


## [away, urgent] for a skill cast toward `aim` from `offset` (hero - caster), `progress` of its
## warning (0..1; 0 for a follow-up blow after the cast).
func _skill_threat(skill: SkillDef, aim: Vector2, progress: float, offset: Vector2, distance: float, direction: Vector2) -> Array:
	var away := Vector2.ZERO
	var urgent := false
	match _skill_kind(skill):
		"area":
			var radius := _area_reach(skill) + player.radius + 20.0
			if distance < radius:
				away += direction * (1.0 + progress)
				urgent = progress >= 0.75 and distance < radius - 15.0
		"dash":
			# Aimed at where the hero stood when the cast began: step off that line.
			var side := aim.orthogonal()
			if side.dot(offset) < 0.0:
				side = -side
			if distance < 420.0:
				away += side * 1.5
				urgent = progress >= 0.85 and absf(offset.dot(aim.orthogonal())) < 70.0
		"shots":
			# A fan: step out of its cone sideways while it is warned (its lanes are drawn), as
			# a player does; the shots' own sides cancel out once they fly around the hero.
			var fan := _fan(skill)
			if fan and distance < fan.max_distance + 40.0:
				var half := deg_to_rad(fan.spread_degrees * 0.5) + atan2(player.radius + fan.radius + 8.0, maxf(distance, 1.0))
				if absf(aim.angle_to(offset)) < half:
					var side := aim.orthogonal()
					if side.dot(offset) < 0.0:
						side = -side
					away += side * 1.5
			# A ring or a fan leaves the caster: close, roll through it as it is let go.
			urgent = distance < 170.0 and progress >= 0.85
	return [away, urgent]


## The first fan of shots a skill throws (spread under a full ring), or null.
static func _fan(skill: SkillDef) -> ProjectileEffect:
	for effect in skill.effects:
		var shots := effect as ProjectileEffect
		if shots and shots.count > 1 and shots.spread_degrees > 0.0 and shots.spread_degrees < 360.0:
			return shots
	return null


## When the cast a monster was seen making has let go, remembers its later blows (effects with a
## delay) until the last one lands.
func _note_follow_up(monster: Monster) -> void:
	var id := monster.get_instance_id()
	if not _casting.has(id):
		return
	var cast: Dictionary = _casting[id]
	_casting.erase(id)
	var last := 0.0
	for effect in (cast.skill as SkillDef).effects:
		last = maxf(last, effect.delay)
	if last > 0.0:
		_follow_ups[id] = { "skill": cast.skill, "aim": cast.aim,
			"until": Engine.get_physics_frames() + roundi((last + FOLLOW_UP_MARGIN) * Engine.physics_ticks_per_second) }


## A monster's wyrm body (its burning coils), if it has one.
static func _coils(monster: Monster) -> WyrmBody:
	for child in monster.get_children():
		if child is WyrmBody:
			return child as WyrmBody
	return null


## Whether the threat `key` has been seen for the bot's reaction time (always, without one).
func _noticed(key: Variant) -> bool:
	if reaction <= 0.0:
		return true
	var now := Engine.get_physics_frames()
	if _seen.size() > 400:
		_seen.clear()  # shots long gone: their ids pile up
	if not _seen.has(key):
		_seen[key] = now
	return now - int(_seen[key]) >= roundi(reaction * Engine.physics_ticks_per_second)


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
	var now := Engine.get_physics_frames()
	if now - _hazard_frame < 6:
		return _hazards
	_hazard_frame = now
	_hazards.clear()
	for node in world.get_node("Effects").get_children():
		if node is CellWarning:
			_hazards.append_array((node as CellWarning)._cells)
	for node in world.get_node("Entities").get_children():
		if node is Trap and (node as Trap).phase != Trap.Phase.IDLE:
			_hazards.append(world.map.world_to_cell((node as Trap).global_position))
	return _hazards


## The way to roll: close to `wanted`, nothing in the way (a wall or a prop would stop the roll
## short), and landing on solid ground. A roll carries the hero over holes (PitDef), as a player
## knows: only where it ends matters. ZERO when there is no safe roll.
func _roll_direction(wanted: Vector2) -> Vector2:
	var here := player.global_position
	var best := Vector2.ZERO
	var best_score := -INF
	for i in 16:
		var direction := Vector2.from_angle(i * TAU / 16.0)
		var safe := true
		for step: float in ROLL_PROBES:
			var probe := here + direction * step
			if world.nav.is_blocked(world.map.world_to_cell(probe)) or not world.has_line_of_sight(here, probe) \
					or (step >= ROLL_LANDING and not world.is_solid_ground(probe)):
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
		if player.skills.skills[i] and player.skills.is_ready(i) and _lands_safe(player.skills.skills[i]) and _press(StringName("skill_%d" % (i + 1))):
			skills_used += 1  # presses (a press on cooldown or out of reach does nothing)
			return  # one a frame, like thumbs


## A skill that carries the hero (Iaido Dash, a charge) is used only when it lands him on solid
## ground: a player sees the hole behind the boss before dashing through it.
func _lands_safe(skill: SkillDef) -> bool:
	var aim := player.get_aim_direction(Player.SKILL_AIM_RANGE)
	var here := player.global_position
	for effect in skill.effects:
		var length := 0.0
		if effect is DashStrikeEffect and (effect as DashStrikeEffect).moves:
			length = (effect as DashStrikeEffect).distance
		elif effect is DashEffect:
			length = (effect as DashEffect).distance
		if length <= 0.0:
			continue
		var end := here + aim * length
		var wall := world.get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(here, end, Layers.WORLD))
		if not wall.is_empty():
			end = here + aim * maxf(here.distance_to(wall.position) - player.radius - 2.0, 0.0)
		# Around the end too: a dash that meets the boss' body slides along it.
		var side := aim.orthogonal() * DASH_LANDING_MARGIN
		for point: Vector2 in [end, end + side, end - side, end + aim * DASH_LANDING_MARGIN, end - aim * DASH_LANDING_MARGIN]:
			if not _firm(point):
				return false
	return true


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
		if not _walkable(direction, 56.0) or not world.has_line_of_sight(here, probe) or world.nav.is_blocked(world.map.world_to_cell(probe)):
			score -= 3.0
		if score > best_score:
			best_score = score
			best = direction
	return best


## Whether walking `distance` along `direction` keeps the hero's feet on solid ground, step by
## step (a hole of one cell lies between two probes 56 px apart: a player sees it and walks
## around it).
func _walkable(direction: Vector2, distance: float) -> bool:
	var here := player.global_position
	var at := HOLE_STEP
	while at <= distance:
		if not _firm(here + direction * at):
			return false
		at += HOLE_STEP
	return true


## Ground that holds and stays: no hole, no cracked floor, not a cell the arena warns about
## (it is about to give way or grow spikes).
func _firm(point: Vector2) -> bool:
	return world.is_solid_ground(point) and not _hazard_cells().has(world.map.world_to_cell(point))


## Moves (the stick): never straight into a hole or cracked floor the hero can see a few steps
## ahead; around it when there is a way, else it stops. A blow can still throw him in.
func _move(direction: Vector2) -> void:
	if direction != Vector2.ZERO and player.is_grounded() and _firm(player.global_position) \
			and not _walkable(direction.normalized(), HOLE_LOOKAHEAD):
		var around := _safe_direction(direction)
		direction = around if _walkable(around, HOLE_LOOKAHEAD) else Vector2.ZERO
	_steer(direction)


func _steer(direction: Vector2) -> void:
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
