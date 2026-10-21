class_name ActorRig
extends Node2D
## Visual body of an actor, animated frame by frame like a classic 2D RPG.
##
##   Rig (this, at the actor's feet)
##   └── Visual        body shader (flash.gdshader: hit flash, statuses, elite rim, deaths; driven
##       │             by `look`, a BodyLook), scaled 2x (units inside = art pixels)
##       └── Squash    squash & stretch on hits, lunges
##           ├── Body       AnimatedSprite2D: idle_/walk_/attack_/hit_/dash_ + down/up/left/right, dead,
##           │              and for bosses cast (telegraphed skills) and intro (wakes up)
##           ├── BodyArmor  AnimatedSprite2D: worn body armor, same animation and frame as Body
##           ├── Helmet     AnimatedSprite2D: worn helmet, same animation and frame as Body
##           ├── Weapon     AnimatedSprite2D: the weapon in hand, attack_<dir>, synced frame by frame
##           ├── WeaponBack Sprite2D: the hero's weapon at rest (WeaponDef.back_sprite), added in code
##           └── WeaponAura the elements his weapon carries (WeaponAura), right after the weapon shown
##
## Sprites are drawn per direction (no mirroring, no free rotation): the weapon sits in the hand
## of each attack frame and is drawn behind the body when facing up, exactly like in Zelda-likes.
## Armor layers (paper doll) copy the body's animation and frame every frame, so they can never drift.
## The hero (`carries_weapon`) shows his weapon at rest, slung on his back or at his hip, behind
## the body but in front when he turns his back to us; his gear above Common and a weapon
## carrying an element wear their own copies of the body shader (`trim`, `imbue`) that follow the
## body's (BodyLook.follow): docs/vfx.md, "Rarity and runes" and "The weapon at rest".
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
## A ghost's washed-out look (the spectres of the Threshold): the body blended this much toward
## `pallor_color` for good, under the hit flash.
var pallor := 0.0
var pallor_color := Color.WHITE
## What the body shader paints on it (statuses, an elite's rim, its death).
var look: BodyLook
## Shows the weapon at rest and the gear's rarity and elements (the hero; monsters don't).
var carries_weapon := false

## Where a weapon at rest sits per kind and facing: the middle of its sprite (art pixels from
## the feet), whether it is mirrored (a slung sprite's top end is at its top right: over his
## right shoulder seen from the front, so on the left seen from the back) and whether it is in
## front of the body. Tuned on screenshots of the 15-pixel hero (docs/vfx.md).
const BACK_PLACES := {
	WeaponDef.BackKind.SLUNG: {
		&"down": [Vector2(6, -14), false, false],
		&"up": [Vector2(-4, -12), true, true],
		&"left": [Vector2(6, -13), false, false],
		&"right": [Vector2(-6, -13), true, false],
	},
	WeaponDef.BackKind.HIP: {
		&"down": [Vector2(7, -4), false, true],
		&"up": [Vector2(-7, -4), true, true],
		&"left": [Vector2(2, -4), false, false],
		&"right": [Vector2(-2, -4), true, true],
	},
}

var _back: Sprite2D
var _aura: WeaponAura
var _weapon_material: ShaderMaterial
var _wear_materials := {}  # Slot -> ShaderMaterial
var _wear_rarity := {}  # Slot -> rarity
var _fewer := false
var _back_key := []
static var _tops := {}  # a body frame -> the top row of its art (for the bob)

@onready var visual: Node2D = $Visual
@onready var squash_node: Node2D = $Visual/Squash
@onready var body: AnimatedSprite2D = $Visual/Squash/Body
@onready var weapon: AnimatedSprite2D = $Visual/Squash/Weapon
@onready var body_armor: AnimatedSprite2D = $Visual/Squash/BodyArmor
@onready var helmet: AnimatedSprite2D = $Visual/Squash/Helmet


func _ready() -> void:
	body.animation_finished.connect(_on_body_animation_finished)
	weapon.visible = false
	look = BodyLook.new(visual.material as ShaderMaterial)
	body.frame_changed.connect(_fit_frame)
	body.animation_changed.connect(_fit_frame)
	weapon.frame_changed.connect(_fit_weapon_frame)


func setup(frames: SpriteFrames, offset: Vector2) -> void:
	body.sprite_frames = frames
	for sprite: AnimatedSprite2D in [body, body_armor, helmet, weapon]:
		sprite.offset = offset
	_play(&"idle")
	_fit_frame()


## Shows (or hides, with null frames) the armor worn on `slot` (HEAD or BODY); above Common the
## piece wears its rarity's trim (RarityLookDef.trim, a glint sweeping across an Epic one).
func set_wear(slot: EquipmentDef.Slot, frames: SpriteFrames, color: Color, rarity: int = ItemRarity.COMMON) -> void:
	var layer := helmet if slot == EquipmentDef.Slot.HEAD else body_armor
	layer.sprite_frames = frames
	layer.self_modulate = color
	layer.visible = frames != null
	_wear_rarity[slot] = rarity if frames else ItemRarity.COMMON
	if rarity > ItemRarity.COMMON and not _wear_materials.has(slot):
		_wear_materials[slot] = _own_material(layer, false)
		(_wear_materials[slot] as ShaderMaterial).set_shader_parameter(&"trim_hem", true)
	if _wear_materials.has(slot):
		_set_trim(_wear_materials[slot], _wear_rarity[slot])
	_sync_layers()


## The weapon in hand (and for the hero at rest: its sprite on his back, its rarity's trim and
## the elements it carries).
func set_weapon(def: WeaponDef) -> void:
	_weapon_def = def
	if not _attacking:
		weapon.visible = false
	if carries_weapon:
		_dress_weapon()


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
		_fit_weapon_frame()
	_update_back()
	# The sheet effect, unless the swing draws its own arc (see Vfx.swing: a weapon shows one
	# or the other, WeaponDef.shows_arc()). A creature's blow without a sheet of its own strikes
	# with its element's claw (Frost Fang: claws of ice). A shot has neither: the shot leaves
	# the hand and nothing else covers the shooter (a staff of frost doesn't claw).
	if def and def.kind == WeaponDef.Kind.MELEE and not def.shows_arc():
		if def.attack_fx:
			# A blow all around (a body slam's ring) is round: drawn as it is, never turned.
			var round_blow := def.arc_degrees >= 359.0
			_spawn_fx(def.attack_fx, Vector2.ZERO if round_blow else aim, 0.0 if round_blow else deg_to_rad(def.attack_fx_rotation), def.element)
		elif def.element and def.element.claw:
			var at := Vector2(0, -CHEST_HEIGHT) + aim.normalized() * FX_DISTANCE
			add_child(SheetVfx.play(def.element.claw, at, aim, def.element))


## Charging the weapon's charged attack (`def`; null: not any more): the weapon held up in the
## hand, on the first frame of its attack toward the way the body faces (behind the body
## facing up), while the body walks or stands as usual. An attack under way keeps its frames.
func show_charge(def: WeaponDef) -> void:
	if _attacking or _dead:
		return
	var shown := def != null and def.attack_frames != null and def.attack_frames.has_animation(StringName("attack_" + direction))
	if not shown:
		weapon.visible = false
		return
	var animation := StringName("attack_" + direction)
	if weapon.sprite_frames != def.attack_frames or weapon.animation != animation or not weapon.visible:
		weapon.sprite_frames = def.attack_frames
		weapon.animation = animation
		weapon.frame = 0
		weapon.pause()
		weapon.visible = true
		squash_node.move_child(weapon, 0 if direction == &"up" else squash_node.get_child_count() - 1)


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


## Telegraph before a monster skill: the "cast" animation fitted to `duration`, or the wind-up pose.
func play_cast(aim: Vector2, duration: float) -> void:
	if _dead or body.sprite_frames == null:
		return
	var animation := _animation_for(&"cast")
	if animation == &"":
		play_windup(aim, duration)
		return
	direction = direction_name(aim)
	_winding_up = true
	body.stop()
	body.play(animation, maxf(0.1, _length(body.sprite_frames, animation) / maxf(duration, 0.05)))


## A boss waking up in its arena ("intro" animation, if it has one).
func play_intro() -> void:
	if _dead or body.sprite_frames == null or _animation_for(&"intro") == &"":
		return
	_winding_up = true
	_play(&"intro", 1.0, true)


## Hit (by `element`: a storm hit crackles over the body).
func play_hurt(element: VfxElementDef = null) -> void:
	look.hit(element)
	_flash = FLASH_TIME
	_squash = SQUASH_TIME
	_hurt = HURT_TIME


func play_death() -> void:
	_dead = true
	_attacking = false
	weapon.visible = false
	_update_back()
	if not _play(&"dead", 1.0, true):
		# No death frames: fall over.
		var tween := create_tween()
		tween.tween_property(squash_node, "rotation", -PI / 2.0, 0.25)


## Goes as `death` says in `element`'s ramp (the body shader's death), then `finished` is
## called (monster deaths; what flies off it: DeathFx).
func dissolve(death: DeathLookDef, element: VfxElementDef, finished: Callable) -> void:
	look.die(death, element)
	var tween := create_tween()
	tween.tween_interval(death.delay)
	tween.tween_method(look.set_dying, 0.0, 1.0, death.duration)
	tween.tween_callback(finished)


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
	look.set_shared(&"flash_amount", 1.0 if _flash > 0.0 else pallor)
	if pallor > 0.0:
		look.set_shared(&"flash_color", Color.WHITE if _flash > 0.0 else pallor_color)
	_sync_layers()
	if carries_weapon:
		if _fewer != Settings.fewer_effects:
			_fewer = Settings.fewer_effects
			_dress_weapon()
			for slot: EquipmentDef.Slot in _wear_materials:
				_set_trim(_wear_materials[slot], _wear_rarity.get(slot, ItemRarity.COMMON))
		_update_back()


## Armor layers show the same animation and frame as the body (hidden if they don't have it).
func _sync_layers() -> void:
	var layered := false
	for layer: AnimatedSprite2D in [body_armor, helmet]:
		if layer.sprite_frames == null:
			continue
		var shown := layer.sprite_frames.has_animation(body.animation)
		layer.visible = shown
		layered = layered or shown
		if shown:
			if layer.animation != body.animation:
				layer.animation = body.animation
			layer.frame = body.frame
	look.layered = layered


## The shader's idea of the body's frame (its quad in the sprite's local space, art pixels), so
## its heights, edges and deaths are measured on the frame shown, never reading the next frame
## of the sheet.
func _fit_frame() -> void:
	if body.sprite_frames == null or not body.sprite_frames.has_animation(body.animation):
		return
	var texture := body.sprite_frames.get_frame_texture(body.animation, body.frame)
	if texture == null:
		return
	var size := texture.get_size()
	var corner := body.offset - (size / 2.0 if body.centered else Vector2.ZERO)
	look.set_frame(Rect2(corner, size))


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


func _spawn_fx(sheet: Texture2D, aim: Vector2, extra_rotation: float, element: VfxElementDef = null) -> void:
	var at := Vector2(0, -CHEST_HEIGHT) + aim.normalized() * FX_DISTANCE
	add_child(SheetVfx.create(sheet, at, aim.angle() + extra_rotation, 2.0, 18.0).in_element(element))


func _end_attack() -> void:
	_attacking = false
	weapon.visible = false
	_update_back()


func _on_body_animation_finished() -> void:
	var animation := String(body.animation)
	if animation.begins_with("attack"):
		_end_attack()
	elif animation.begins_with("cast") or animation.begins_with("intro"):
		_winding_up = false


# --- The hero's gear: the weapon at rest, rarity, elements ------------------------------------

## Whether the weapon at rest shows now (not while it is in hand, nor once dead).
func shows_back_weapon() -> bool:
	return _back != null and _back.visible


## The weapon at rest (null for a rig that carries none), and the motes of its elements.
func back_weapon() -> Sprite2D:
	return _back


func weapon_aura() -> WeaponAura:
	return _aura


## The material the weapon wears (in hand and at rest), null before the hero carries one.
func weapon_material() -> ShaderMaterial:
	return _weapon_material


## The material of a worn piece's layer (HEAD or BODY), null while it shares the body's.
func wear_material(slot: EquipmentDef.Slot) -> ShaderMaterial:
	return _wear_materials.get(slot)


## A copy of the body shader for `layer` (its own uniforms: the trim), following the body's.
func _own_material(layer: CanvasItem, own_frame: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = (visual.material as ShaderMaterial).shader
	layer.use_parent_material = false
	layer.material = material
	look.follow(material, own_frame)
	return material


## `rarity`'s trim on `material` (nothing for Common); fewer effects cuts the glint.
func _set_trim(material: ShaderMaterial, rarity: int) -> void:
	var rarity_look := ItemRarity.look(rarity) if rarity > ItemRarity.COMMON else null
	var trim := rarity_look.trim if rarity_look else 0
	material.set_shader_parameter(&"trim", trim)
	if trim > 0:
		material.set_shader_parameter(&"trim_row", BodyLook.row(rarity_look.element))
	var sweep := rarity_look.sweep_every if rarity_look and not Settings.fewer_effects else 0.0
	material.set_shader_parameter(&"trim_sweep", sweep if trim > 0 else 0.0)


## The weapon's look for the hero: its sprite at rest, its rarity's trim and its elements, on the
## in-hand frames and at rest alike (one material: the two never show together).
func _dress_weapon() -> void:
	if _back == null:
		_back = Sprite2D.new()
		_back.name = "WeaponBack"
		_back.centered = false
		_back.visible = false
		squash_node.add_child(_back)
		_aura = WeaponAura.new()
		squash_node.add_child(_aura)
		_weapon_material = _own_material(weapon, true)
		_back.use_parent_material = false
		_back.material = _weapon_material
	var def := _weapon_def
	_back.texture = def.back_sprite if def else null
	_set_trim(_weapon_material, ItemRarity.of(def) if def else ItemRarity.COMMON)
	var carried := ItemLook.elements(def) if def else ([] as Array[VfxElementDef])
	_weapon_material.set_shader_parameter(&"imbue", 0.0 if carried.is_empty() else 1.0)
	if not carried.is_empty():
		_weapon_material.set_shader_parameter(&"imbue_row", BodyLook.row(carried[0]))
	if carried.size() > ItemLook.MOST:
		carried.resize(ItemLook.MOST)
	_aura.set_elements(carried)
	_back_key = []
	_update_back()


## Places the weapon at rest for the facing and the body's frame (it bobs with the body), or
## hides it while the weapon is in hand, while winding up and once dead.
func _update_back() -> void:
	if _back == null:
		return
	var shown := carries_weapon and _back.texture != null and not _attacking and not _winding_up and not _dead and body.visible
	_back.visible = shown
	if not shown:
		_back_key = []
		_aura.visible = weapon.visible  # in hand: placed by _fit_weapon_frame
		return
	var def := _weapon_def
	var places: Dictionary = BACK_PLACES[def.back_kind]
	var place: Array = places.get(direction, places[&"down"])
	var flip: bool = place[1]
	var front: bool = place[2]
	var offset := def.back_offset * Vector2(-1.0 if flip else 1.0, 1.0)
	var size := _back.texture.get_size()
	var corner := ((place[0] as Vector2) + offset - size * 0.5).floor() + Vector2(0.0, _bob())
	var key := [corner, flip, front, _back.texture]
	if key == _back_key:
		return
	_back_key = key
	_back.position = corner
	_back.flip_h = flip
	squash_node.move_child(_back, squash_node.get_child_count() - 1 if front else 0)
	_weapon_material.set_shader_parameter(&"frame_rect", Vector4(corner.x, corner.y, size.x, size.y))
	_follow_with_aura(_back)


## The aura is drawn right after the weapon shown (behind the body with it), born on its pixels.
func _follow_with_aura(shown: CanvasItem) -> void:
	_aura.visible = true
	squash_node.move_child(_aura, shown.get_index() + (1 if _aura.get_index() > shown.get_index() else 0))
	if shown == _back:
		_aura.set_source(_back.texture, _back.position, _back.flip_h)
		return
	var texture := weapon.sprite_frames.get_frame_texture(weapon.animation, weapon.frame) if weapon.sprite_frames else null
	if texture:
		_aura.set_source(texture, weapon.offset - texture.get_size() * 0.5, false)


## The in-hand weapon's frame for its shader (its quad in local art pixels), and the aura's.
func _fit_weapon_frame() -> void:
	if _weapon_material == null or not weapon.visible or weapon.sprite_frames == null:
		return
	var texture := weapon.sprite_frames.get_frame_texture(weapon.animation, weapon.frame)
	if texture == null:
		return
	var size := texture.get_size()
	var corner := weapon.offset - size * 0.5
	_weapon_material.set_shader_parameter(&"frame_rect", Vector4(corner.x, corner.y, size.x, size.y))
	_follow_with_aura(weapon)


## How far the body's art is lowered on this frame from its animation's first (art pixels): the
## weapon at rest moves with it, so it never floats while he breathes or walks.
func _bob() -> float:
	var frames := body.sprite_frames
	if frames == null or not frames.has_animation(body.animation) or frames.get_frame_count(body.animation) == 0:
		return 0.0
	return float(_top_of(frames.get_frame_texture(body.animation, body.frame)) - _top_of(frames.get_frame_texture(body.animation, 0)))


static func _top_of(texture: Texture2D) -> int:
	if texture == null:
		return 0
	if not _tops.has(texture):
		var image := texture.get_image()
		if image and image.is_compressed():
			image.decompress()
		_tops[texture] = image.get_used_rect().position.y if image else 0
	return _tops[texture]
