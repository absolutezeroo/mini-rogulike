class_name DebugCheats
extends RefCounted
## The debug panel's cheats (DebugPanel, debug builds only): what they are set to, and the one
## question each gameplay hook asks. Static: the hooks live in Actor, Monster, Player, SkillSet,
## HitStop and the camera, which share no owner, and a cheat lasts the run (across floors, the
## Deeps and the Threshold, the panel closed); the Game resets everything when a run begins.
##
## Everything is off by default, and only the panel turns things on (`set_*` refuse outside a
## debug build), so a release export and the tests (unless one sets a cheat) play the real rules.
##
## A run that used a cheat that changes the fight (or the gallery) is a **debug run**
## (`mark_run()`): nothing it does is kept. The profile is saved as it was, then held (Profile.held:
## nothing written) and read back from its file when the run ends (`end_run()`), dropping the souls,
## kills, records and achievements the run gave; the run itself is never saved (Game._save_run()).

## A damage step that kills at once (DAMAGE_STEPS).
const ONE_SHOT := -1.0
## The damage the hero deals: times these (the last one, ONE_SHOT: whatever is left of the target's
## Health).
const DAMAGE_STEPS: Array[float] = [1.0, 2.0, 5.0, 10.0, ONE_SHOT]
## The damage the hero takes: times these (a step down is more Armor; at least 1 a blow: nothing
## hurts is god mode's).
const ARMOR_STEPS: Array[float] = [1.0, 0.5, 0.25, 0.1]
## The hero's move speed: times these.
const SPEED_STEPS: Array[float] = [1.0, 1.5, 2.0, 3.0]
## The game's speed (Engine.time_scale, under the hit stops: HitStop).
const TIME_STEPS: Array[float] = [1.0, 0.25, 0.5, 2.0]
## The camera's zoom: times these (below 1: farther out, more of the floor on screen).
const ZOOM_STEPS: Array[float] = [1.0, 0.75, 0.5, 0.35]

## Monsters never notice the hero, and forget him if they had (Monster.notice_target()).
static var invisible := false
## Monsters think no more: no step, no blow, no spell, no shockwave (Monster.ai_frozen()).
static var no_ai := false
## The hero's skills (the roll too) are ready again at once (SkillSet.try_use()).
static var no_cooldowns := false
static var damage_step := 0
static var armor_step := 0
static var speed_step := 0
static var time_step := 0
static var zoom_step := 0
## What only shows (DebugOverlay, DebugShapes): bodies, reaches and sight; the frame rate and counts.
static var show_shapes := false
static var show_stats := false
## Every floor at its brightest, no dark corner (World.relight()): only the view, not a debug run.
static var full_light := false
## Every floor's map seen as it begins (Game._enter_floor()): it shows where the stairs, the boss,
## the secrets are, so it makes a debug run.
static var reveal_maps := false
## This run used a cheat that changes the fight, or the gallery: nothing of it is kept.
static var debug_run := false


## Debug builds only (running from the editor, a debug export): elsewhere every setter refuses.
static func available() -> bool:
	return OS.is_debug_build()


## Everything off, the run a real one again (a new run; tests cleaning up). Ends a debug run
## first (the profile is read back from its file).
static func reset() -> void:
	end_run()
	invisible = false
	no_ai = false
	no_cooldowns = false
	damage_step = 0
	armor_step = 0
	speed_step = 0
	time_step = 0
	zoom_step = 0
	show_shapes = false
	show_stats = false
	full_light = false
	reveal_maps = false


## This run is a debug run from now on (see the class doc). The profile is saved first: what the
## run earned before the cheat is kept.
static func mark_run() -> void:
	if debug_run or not available():
		return
	debug_run = true
	Profile.save_profile()
	Profile.held = true


## The debug run is over: the profile drops what it gave (read back from its file).
static func end_run() -> void:
	if not debug_run:
		return
	debug_run = false
	Profile.held = false
	Profile.load_profile()


# --- The panel's setters ------------------------------------------------------------------

static func set_invisible(on: bool) -> void:
	if available():
		invisible = on
		if on:
			mark_run()


static func set_no_ai(on: bool) -> void:
	if available():
		no_ai = on
		if on:
			mark_run()


static func set_no_cooldowns(on: bool) -> void:
	if available():
		no_cooldowns = on
		if on:
			mark_run()


static func set_reveal_maps(on: bool) -> void:
	if available():
		reveal_maps = on
		if on:
			mark_run()


## Only the view: not a debug run.
static func set_full_light(on: bool) -> void:
	if available():
		full_light = on


## The next step of `steps` after `current` (wrapping): what the panel's step buttons do.
static func next_step(current: int, steps: Array[float]) -> int:
	return posmod(current + 1, steps.size())


static func set_damage_step(step: int) -> void:
	if available():
		damage_step = clampi(step, 0, DAMAGE_STEPS.size() - 1)
		if damage_step > 0:
			mark_run()


static func set_armor_step(step: int) -> void:
	if available():
		armor_step = clampi(step, 0, ARMOR_STEPS.size() - 1)
		if armor_step > 0:
			mark_run()


static func set_speed_step(step: int) -> void:
	if available():
		speed_step = clampi(step, 0, SPEED_STEPS.size() - 1)
		if speed_step > 0:
			mark_run()


## Only the view and the clock: not a debug run.
static func set_time_step(step: int) -> void:
	if available():
		time_step = clampi(step, 0, TIME_STEPS.size() - 1)


static func set_zoom_step(step: int) -> void:
	if available():
		zoom_step = clampi(step, 0, ZOOM_STEPS.size() - 1)


# --- What the hooks ask ------------------------------------------------------------------

## Can a monster notice (and keep after) `actor`? Not the hero while invisible.
static func can_be_noticed(actor: Actor) -> bool:
	return not (invisible and actor is Player)


## Do monsters think? Not with No AI.
static func ai_frozen() -> bool:
	return no_ai


## A hit's damage after armor, for the cheats (Actor.take_hit()): the hero's blows times the damage
## step (ONE_SHOT: all of the target's Health and ward), the blows he takes times the armor step.
static func scale_damage(hit: HitInfo, target: Actor, damage: int) -> int:
	if damage <= 0:
		return damage
	if target is Player:
		return maxi(1, roundi(damage * ARMOR_STEPS[armor_step])) if armor_step > 0 else damage
	if damage_step > 0 and is_instance_valid(hit.source) and hit.source is Player:
		var factor := DAMAGE_STEPS[damage_step]
		return maxi(damage, target.hp + target.ward) if factor == ONE_SHOT else roundi(damage * factor)
	return damage


## The hero's move speed factor (Player.get_move_speed()).
static func speed_factor() -> float:
	return SPEED_STEPS[speed_step]


## A skill's cooldown for `user` (SkillSet.try_use()): none for the hero with No cooldowns.
static func cooldown(user: Actor, seconds: float) -> float:
	return 0.0 if no_cooldowns and user is Player else seconds


## The game's speed when nothing slows it (HitStop).
static func time_scale() -> float:
	return TIME_STEPS[time_step]


## The camera's zoom factor (GameCamera).
static func zoom() -> float:
	return ZOOM_STEPS[zoom_step]


## What is on, in a few words (the overlay's line): "" when nothing.
static func summary() -> String:
	var parts := PackedStringArray()
	if invisible:
		parts.append("invisible")
	if no_ai:
		parts.append("no AI")
	if no_cooldowns:
		parts.append("no cooldowns")
	if damage_step > 0:
		parts.append("damage %s" % step_text(DAMAGE_STEPS, damage_step))
	if armor_step > 0:
		parts.append("taken %s" % step_text(ARMOR_STEPS, armor_step))
	if speed_step > 0:
		parts.append("speed %s" % step_text(SPEED_STEPS, speed_step))
	if time_step > 0:
		parts.append("time %s" % step_text(TIME_STEPS, time_step))
	if zoom_step > 0:
		parts.append("zoom %s" % step_text(ZOOM_STEPS, zoom_step))
	if full_light:
		parts.append("full light")
	if reveal_maps:
		parts.append("maps revealed")
	return ", ".join(parts)


## "x5", "x0.25", "one-shot".
static func step_text(steps: Array[float], step: int) -> String:
	var value := steps[step]
	if value == ONE_SHOT:
		return "one-shot"
	return "x%d" % roundi(value) if is_equal_approx(value, roundf(value)) else "x%s" % String.num(value, 2)
