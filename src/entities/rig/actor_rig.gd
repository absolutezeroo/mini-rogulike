class_name ActorRig
extends Node2D
## Visual body of an actor, animated frame by frame like a classic 2D RPG.
##
##   Rig (this, at the actor's feet)
##   └── Visual        flash shader, scaled 2x (units inside = art pixels)
##       └── Squash    squash & stretch on hits, lunges
##           ├── Body    AnimatedSprite2D: idle_/walk_/attack_/hit_/dash_ + down/up/left/right, dead
##           └── Weapon  AnimatedSprite2D: the weapon in hand, attack_<dir>, synced frame by frame
##
## Sprites are drawn per direction (no mirroring, no free rotation): the weapon sits in the hand
## of each attack frame and is drawn behind the body when facing up, exactly like in Zelda-likes.
## Slash effects are separate sprite sheets played in front of the actor.
## The Actor only says what happens; the rig decides how it looks.

const DIRECTIONS: Array[StringName] = [&"down", &"up", &"left", &"right"]
const SQUASH_TIME := 0.12
const FLASH_TIME := 0.1
const HURT_TIME := 0.25
const CHEST_HEIGHT := 14.0  # world pixels above the feet
const FX_DISTANCE := 16.0

var direction: StringName = &"down"
var _attacking := false
var _winding_up := false
var _dead := false
var _flash := 0.0
var _squash := 0.0
var _hurt := 0.0
var _weapon_def: WeaponDef

@onready var visual: Node2D = $Visual
@onready var squash_node: Node2D = $Visual/Squash
@onready var body: AnimatedSprite2D = $Visual/Squash/Body
@onready var weapon: AnimatedSprite2D = $Visual/Squash/Weapon


func _ready() -> void:
	body.animation_finished.connect(_on_body_animation_finished)
	weapon.visible = false


func setup(frames: SpriteFrames, offset: Vector2) -> void:
	body.sprite_frames = frames
	body.offset = offset
	weapon.offset = offset
	_play(&"idle")


func set_weapon(def: WeaponDef) -> void:
	_weapon_def = def
	if not _attacking:
		weapon.visible = false


static func direction_name(vector: Vector2) -> StringName:
	if absf(vector.x) >= absf(vector.y):
		return &"right" if vector.x > 0.0 else &"left"
	return &"down" if vector.y > 0.0 else &"up"


## Called every frame by the actor.
func update_state(facing: Vector2, speed: float, dashing: bool, delta: float) -> void:
	_hurt = maxf(_hurt - delta, 0.0)
	if _dead or _attacking or _winding_up or body.sprite_frames == null:
		return
	if facing != Vector2.ZERO:
		direction = direction_name(facing)
	if dashing and _play(&"dash"):
		return
	if _hurt > 0.0 and _play(&"hit"):
		return
	if speed > 20.0:
		if not _play(&"walk"):
			_play(&"idle")
	elif not _play(&"idle"):
		_play(&"walk", 0.4)


## Attack toward `aim`, fitted into `duration` seconds.
func play_attack(def: WeaponDef, aim: Vector2, duration: float) -> void:
	if _dead or body.sprite_frames == null:
		return
	direction = direction_name(aim)
	_winding_up = false
	_attacking = true
	var animation := _animation_for(&"attack")
	var speed := 1.0
	if animation != &"":
		speed = maxf(1.0, _length(body.sprite_frames, animation) / maxf(duration, 0.05))
		body.stop()
		body.play(animation, speed)
	else:
		_lunge(aim)
		get_tree().create_timer(0.25, false).timeout.connect(_end_attack)

	if def and def.attack_frames and def.attack_frames.has_animation(StringName("attack_" + direction)):
		weapon.sprite_frames = def.attack_frames
		weapon.visible = true
		weapon.stop()
		weapon.play(StringName("attack_" + direction), speed)
		# Behind the body when facing up (we see the back), in front otherwise.
		squash_node.move_child(weapon, 0 if direction == &"up" else squash_node.get_child_count() - 1)
	if def and def.attack_fx:
		_spawn_fx(def.attack_fx, aim, deg_to_rad(def.attack_fx_rotation))


## Telegraph before a monster attack: hold the attack pose and tremble.
func play_windup(aim: Vector2, duration: float) -> void:
	if _dead or body.sprite_frames == null:
		return
	direction = direction_name(aim)
	_winding_up = true
	if _play(&"attack", 1.0, true):
		body.pause()
	var tween := create_tween()
	var steps := maxi(2, int(duration / 0.05))
	for i in steps:
		tween.tween_property(body, "position", Vector2(-1.0 if i % 2 == 0 else 1.0, 0.0), 0.05)
	tween.tween_property(body, "position", Vector2.ZERO, 0.02)
	tween.tween_callback(func() -> void: _winding_up = false)


func play_hurt() -> void:
	_flash = FLASH_TIME
	_squash = SQUASH_TIME
	_hurt = HURT_TIME


func play_death() -> void:
	_dead = true
	_attacking = false
	weapon.visible = false
	if not _play(&"dead", 1.0, true):
		# No death frames: fall over.
		var tween := create_tween()
		tween.tween_property(squash_node, "rotation", -PI / 2.0, 0.25)


## Texture and transform of what the body shows right now (for afterimages).
func current_frame() -> Texture2D:
	if body.sprite_frames == null or body.animation == &"":
		return null
	return body.sprite_frames.get_frame_texture(body.animation, body.frame)


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	_squash = maxf(_squash - delta, 0.0)
	var t := _squash / SQUASH_TIME
	squash_node.scale = Vector2(1.0 + 0.25 * t, 1.0 - 0.2 * t)
	(visual.material as ShaderMaterial).set_shader_parameter("flash_amount", 1.0 if _flash > 0.0 else 0.0)


# --- Helpers -----------------------------------------------------------------

## "walk" -> "walk_left" if it exists, else "walk", else "".
func _animation_for(base: StringName) -> StringName:
	var frames := body.sprite_frames
	if frames == null:
		return &""
	var directed := StringName(String(base) + "_" + String(direction))
	if frames.has_animation(directed):
		return directed
	if frames.has_animation(base):
		return base
	return &""


func _play(base: StringName, speed: float = 1.0, restart: bool = false) -> bool:
	var animation := _animation_for(base)
	if animation == &"":
		return false
	if restart or body.animation != animation or not body.is_playing():
		body.play(animation, speed)
	return true


static func _length(frames: SpriteFrames, animation: StringName) -> float:
	var total := 0.0
	for i in frames.get_frame_count(animation):
		total += frames.get_frame_duration(animation, i)
	return total / maxf(frames.get_animation_speed(animation), 0.001)


func _lunge(aim: Vector2) -> void:
	var forward := aim.normalized() * 5.0
	var tween := create_tween()
	tween.tween_property(squash_node, "position", -forward * 0.4, 0.06)
	tween.tween_property(squash_node, "position", forward, 0.06)
	tween.tween_property(squash_node, "position", Vector2.ZERO, 0.12)


func _spawn_fx(sheet: Texture2D, aim: Vector2, extra_rotation: float) -> void:
	var at := Vector2(0, -CHEST_HEIGHT) + aim.normalized() * FX_DISTANCE
	add_child(SheetVfx.create(sheet, at, aim.angle() + extra_rotation, 2.0, 18.0))


func _end_attack() -> void:
	_attacking = false
	weapon.visible = false


func _on_body_animation_finished() -> void:
	if String(body.animation).begins_with("attack"):
		_end_attack()
