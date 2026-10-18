class_name ActorRig
extends Node2D
## Visual body of an actor: sprite, hand and weapon, animated by two AnimationPlayers.
##
##   Rig (this, at the actor's feet)
##   ├── Visual           flips left/right, holds the flash shader, scaled 2x (pixel art units)
##   │   └── Squash       squash & stretch on hits (code)
##   │       ├── Body     the character sprite        <- BodyAnimator: idle, walk, dash, lunge, windup, death
##   │       └── Aim      turned toward the target while attacking (code)
##   │           └── Hand <- WeaponAnimator: rest, slash, thrust, smash, shoot (+ windup_* poses)
##   │               └── Weapon (sprite)
##   ├── BodyAnimator
##   └── WeaponAnimator
##
## The Actor only says what happens (walking, attacking toward X, got hit, died);
## the rig decides how it looks. Animations are edited in the editor's Animation panel.

const SQUASH_TIME := 0.12
const FLASH_TIME := 0.1
const AIM_RETURN_SPEED := 10.0
const ATTACK_ANIMATIONS := {
	WeaponDef.AttackAnimation.SLASH: &"slash",
	WeaponDef.AttackAnimation.THRUST: &"thrust",
	WeaponDef.AttackAnimation.SMASH: &"smash",
	WeaponDef.AttackAnimation.SHOOT: &"shoot",
}

var _flip := 1.0
var _attacking := false
var _locked_body := false  # lunge / death own the body animation
var _flash := 0.0
var _squash := 0.0
var _has_weapon_icon := false

@onready var visual: Node2D = $Visual
@onready var squash_node: Node2D = $Visual/Squash
@onready var body: Sprite2D = $Visual/Squash/Body
@onready var aim: Node2D = $Visual/Squash/Aim
@onready var hand: Node2D = $Visual/Squash/Aim/Hand
@onready var weapon: Sprite2D = $Visual/Squash/Aim/Hand/Weapon
@onready var body_animator: AnimationPlayer = $BodyAnimator
@onready var weapon_animator: AnimationPlayer = $WeaponAnimator


func _ready() -> void:
	weapon_animator.animation_finished.connect(_on_weapon_animation_finished)
	body_animator.animation_finished.connect(_on_body_animation_finished)
	body_animator.play(&"idle")
	weapon_animator.play(&"rest")


func setup(texture: Texture2D, tint: Color) -> void:
	body.texture = texture
	body.self_modulate = tint


func set_weapon(def: WeaponDef) -> void:
	_has_weapon_icon = def != null and def.icon != null
	weapon.visible = _has_weapon_icon
	if _has_weapon_icon:
		weapon.texture = def.icon
		weapon.self_modulate = def.icon_tint


## Called every frame by the actor.
func update_state(facing: Vector2, speed: float, dashing: bool, delta: float) -> void:
	if not _attacking:
		if facing.x < -0.1:
			_flip = -1.0
		elif facing.x > 0.1:
			_flip = 1.0
		aim.rotation = lerp_angle(aim.rotation, 0.0, minf(AIM_RETURN_SPEED * delta, 1.0))
	visual.scale = Vector2(2.0 * _flip, 2.0)

	if _locked_body:
		return
	var wanted := &"dash" if dashing else (&"walk" if speed > 20.0 else &"idle")
	if body_animator.current_animation != wanted:
		body_animator.play(wanted, 0.08)


## Plays the weapon's attack animation toward `direction`, fitted into `duration` seconds.
func play_attack(def: WeaponDef, direction: Vector2, duration: float) -> void:
	_face(direction)
	if not _has_weapon_icon:
		_lunge()
		return
	_attacking = true
	var animation: StringName = ATTACK_ANIMATIONS.get(def.attack_animation, &"slash")
	var length := weapon_animator.get_animation(animation).length
	weapon_animator.play(animation, -1, maxf(1.0, length / maxf(duration, 0.05)))


## Holds the anticipation pose while a monster winds up (the attack follows).
func play_windup(def: WeaponDef, direction: Vector2, duration: float) -> void:
	_face(direction)
	if not _has_weapon_icon:
		_locked_body = true
		body_animator.play(&"windup", -1, 1.0)
		get_tree().create_timer(duration, false).timeout.connect(func() -> void:
			if body_animator.current_animation == &"windup":
				_locked_body = false)
		return
	_attacking = true
	var pose: StringName = &"windup_" + String(ATTACK_ANIMATIONS.get(def.attack_animation, &"slash"))
	var length := weapon_animator.get_animation(pose).length
	weapon_animator.play(pose, -1, maxf(1.0, length / maxf(duration, 0.05)))


func play_death() -> void:
	_locked_body = true
	_attacking = false
	weapon.visible = false
	body_animator.play(&"death")


func flash() -> void:
	_flash = FLASH_TIME


func squash() -> void:
	_squash = SQUASH_TIME


## Sprite currently shown for the body (used for afterimages).
func body_sprite() -> Sprite2D:
	return body


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	_squash = maxf(_squash - delta, 0.0)
	var t := _squash / SQUASH_TIME
	squash_node.scale = Vector2(1.0 + 0.25 * t, 1.0 - 0.2 * t)
	(visual.material as ShaderMaterial).set_shader_parameter("flash_amount", 1.0 if _flash > 0.0 else 0.0)


func _face(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	if direction.x < -0.1:
		_flip = -1.0
	elif direction.x > 0.1:
		_flip = 1.0
	visual.scale = Vector2(2.0 * _flip, 2.0)
	# Flipped space: mirror the direction so "forward" (+x) points at the target.
	aim.rotation = Vector2(direction.x * _flip, direction.y).angle()


func _lunge() -> void:
	_locked_body = true
	body_animator.play(&"lunge")


func _on_weapon_animation_finished(animation: StringName) -> void:
	if String(animation).begins_with("windup_"):
		return  # hold the pose until the attack plays
	_attacking = false
	weapon_animator.play(&"rest", 0.1)


func _on_body_animation_finished(animation: StringName) -> void:
	if animation == &"death":
		return
	_locked_body = false
