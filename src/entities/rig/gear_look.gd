class_name GearLook
extends RefCounted
## How the gear an actor wears is composed on its body (ActorRig.gear): the worn pieces' own
## copies of the body shader (a rarity's trim, the element an affix carries, a hem of teeth),
## and for the hero (`ActorRig.carries_weapon`) his weapon at rest (slung on his back or at his
## hip, bobbing with the body), its trim, its elements on the blade and their motes (WeaponAura).
## The rig picks the animations and says when the weapon is in hand; this lays the layers out
## (docs/vfx.md, "Rarity and runes" and "The weapon at rest").

## Where a weapon at rest sits per kind and facing (art pixels from the feet): the middle of its
## sprite, whether it is mirrored (a slung sprite's top end is at its top right: over his right
## shoulder seen from the front, so on the left seen from the back) and whether it is in front of
## the body. Tuned on screenshots of the 15-pixel hero (docs/vfx.md).
class BackPlace:
	var center: Vector2
	var flip: bool
	var front: bool

	func _init(at: Vector2, mirrored: bool, in_front: bool) -> void:
		center = at
		flip = mirrored
		front = in_front


## BackPlace by WeaponDef.BackKind, then by direction (made once: _places()).
static var _back_places: Dictionary[WeaponDef.BackKind, Dictionary] = {}

var _rig: ActorRig
## The weapon shown at rest (null until the hero carries one) and the motes of its elements.
var _back: Sprite2D
var _aura: WeaponAura
## The material the weapon wears, in hand and at rest (one: the two never show together).
var _weapon_material: ShaderMaterial
## The weapon dressed last (its sprite at rest, where it sits).
var _weapon_def: WeaponDef
## The worn pieces that wear their own copy of the body shader, and their rarity.
var _wear_materials: Dictionary[EquipmentDef.Slot, ShaderMaterial] = {}
var _wear_rarity: Dictionary[EquipmentDef.Slot, int] = {}
## Settings.fewer_effects when it was last dressed (it cuts the glint).
var _fewer := false
## Where the weapon at rest was last put (update_back() moves it only when one of these changed).
var _placed := false
var _placed_corner := Vector2.ZERO
var _placed_flip := false
var _placed_front := false
var _placed_texture: Texture2D


func _init(rig: ActorRig) -> void:
	_rig = rig


## Whether the weapon at rest shows now (not while it is in hand, nor once dead).
func shows_back_weapon() -> bool:
	return _back != null and _back.visible


## The weapon at rest (null for a rig that carries none).
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


## The worn piece on `slot`'s layer: above Common its rarity's trim, `carried` (an element it
## carries, or null) glittering on that trim, and with `teeth` a hem of steel points. `worn`:
## false when the slot is empty (its layer then shows nothing).
func dress_wear(slot: EquipmentDef.Slot, layer: AnimatedSprite2D, worn: bool, rarity: int, carried: VfxElementDef, teeth: bool) -> void:
	_wear_rarity[slot] = rarity if worn else ItemRarity.COMMON
	if (rarity > ItemRarity.COMMON or carried or teeth) and not _wear_materials.has(slot):
		_wear_materials[slot] = _own_material(layer, false)
		_wear_materials[slot].set_shader_parameter(&"trim_hem", true)
	if _wear_materials.has(slot):
		var slot_material := _wear_materials[slot]
		_set_trim(slot_material, _wear_rarity[slot])
		slot_material.set_shader_parameter(&"imbue", 1.0 if carried else 0.0)
		if carried:
			slot_material.set_shader_parameter(&"imbue_row", BodyLook.row(carried))
		slot_material.set_shader_parameter(&"teeth", teeth)
		if teeth:
			slot_material.set_shader_parameter(&"teeth_row", BodyLook.row(VfxElementDef.named(&"physical")))


## Fewer effects was switched since it was dressed (the glint goes or comes back): true once.
func fewer_changed() -> bool:
	if _fewer == Settings.fewer_effects:
		return false
	_fewer = Settings.fewer_effects
	return true


## The worn pieces' trims again (fewer effects switched).
func retrim_wear() -> void:
	for slot: EquipmentDef.Slot in _wear_materials:
		_set_trim(_wear_materials[slot], _wear_rarity.get(slot, ItemRarity.COMMON))


## The weapon's look for the hero: its sprite at rest, its rarity's trim and its elements, on the
## in-hand frames and at rest alike. The rig places it after (update_back()).
func dress_weapon(def: WeaponDef) -> void:
	var rig := _rig
	if _back == null:
		_back = Sprite2D.new()
		_back.name = "WeaponBack"
		_back.centered = false
		_back.visible = false
		rig.squash_node.add_child(_back)
		_aura = WeaponAura.new()
		rig.squash_node.add_child(_aura)
		_weapon_material = _own_material(rig.weapon, true)
		_back.use_parent_material = false
		_back.material = _weapon_material
	_weapon_def = def
	_back.texture = def.back_sprite if def else null
	_set_trim(_weapon_material, ItemRarity.of(def) if def else ItemRarity.COMMON)
	var carried := ItemLook.elements(def) if def else ([] as Array[VfxElementDef])
	_weapon_material.set_shader_parameter(&"imbue", 0.0 if carried.is_empty() else 1.0)
	if not carried.is_empty():
		_weapon_material.set_shader_parameter(&"imbue_row", BodyLook.row(carried[0]))
	if carried.size() > ItemLook.MOST:
		carried.resize(ItemLook.MOST)
	_aura.set_elements(carried)
	_placed = false


## Places the weapon at rest for the facing and the body's frame (it bobs with the body), or
## hides it: `allowed` false while the weapon is in hand, winding up, once dead (the rig knows).
func update_back(allowed: bool) -> void:
	if _back == null:
		return
	var rig := _rig
	var shown := allowed and _back.texture != null
	_back.visible = shown
	if not shown:
		_placed = false
		_aura.visible = rig.weapon.visible  # in hand: placed by fit_weapon_frame()
		return
	var def := _weapon_def
	var places := _places(def.back_kind)
	var place: BackPlace = places.get(rig.direction, places[&"down"])
	var offset := def.back_offset * Vector2(-1.0 if place.flip else 1.0, 1.0)
	var size := _back.texture.get_size()
	var corner := (place.center + offset - size * 0.5).floor() + Vector2(0.0, BodyTops.bob(rig.body))
	if _placed and corner == _placed_corner and place.flip == _placed_flip and place.front == _placed_front and _back.texture == _placed_texture:
		return
	_placed = true
	_placed_corner = corner
	_placed_flip = place.flip
	_placed_front = place.front
	_placed_texture = _back.texture
	_back.position = corner
	_back.flip_h = place.flip
	rig.squash_node.move_child(_back, rig.squash_node.get_child_count() - 1 if place.front else 0)
	_weapon_material.set_shader_parameter(&"frame_rect", Vector4(corner.x, corner.y, size.x, size.y))
	_follow_with_aura(_back)


## The in-hand weapon's frame for its shader (its quad in local art pixels), and the aura's.
func fit_weapon_frame() -> void:
	var weapon := _rig.weapon
	if _weapon_material == null or not weapon.visible or weapon.sprite_frames == null:
		return
	var texture := weapon.sprite_frames.get_frame_texture(weapon.animation, weapon.frame)
	if texture == null:
		return
	var size := texture.get_size()
	var corner := weapon.offset - size * 0.5
	_weapon_material.set_shader_parameter(&"frame_rect", Vector4(corner.x, corner.y, size.x, size.y))
	_follow_with_aura(weapon)


## The aura is drawn right after the weapon shown (behind the body with it), born on its pixels.
func _follow_with_aura(shown: CanvasItem) -> void:
	var squash := _rig.squash_node
	_aura.visible = true
	squash.move_child(_aura, shown.get_index() + (1 if _aura.get_index() > shown.get_index() else 0))
	if shown == _back:
		_aura.set_source(_back.texture, _back.position, _back.flip_h)
		return
	var weapon := _rig.weapon
	var texture := weapon.sprite_frames.get_frame_texture(weapon.animation, weapon.frame) if weapon.sprite_frames else null
	if texture:
		_aura.set_source(texture, weapon.offset - texture.get_size() * 0.5, false)


## A copy of the body shader for `layer` (its own uniforms: the trim), following the body's.
func _own_material(layer: CanvasItem, own_frame: bool) -> ShaderMaterial:
	var trim_material := ShaderMaterial.new()
	trim_material.shader = (_rig.visual.material as ShaderMaterial).shader
	layer.use_parent_material = false
	layer.material = trim_material
	_rig.look.follow(trim_material, own_frame)
	return trim_material


## `rarity`'s trim on `trim_material` (nothing for Common); fewer effects cuts the glint.
static func _set_trim(trim_material: ShaderMaterial, rarity: int) -> void:
	var rarity_look := ItemRarity.look(rarity) if rarity > ItemRarity.COMMON else null
	var trim := rarity_look.trim if rarity_look else 0
	trim_material.set_shader_parameter(&"trim", trim)
	if trim > 0:
		trim_material.set_shader_parameter(&"trim_row", BodyLook.row(rarity_look.element))
	var sweep := rarity_look.sweep_every if rarity_look and not Settings.fewer_effects else 0.0
	trim_material.set_shader_parameter(&"trim_sweep", sweep if trim > 0 else 0.0)


## The places of a weapon at rest of `kind`, by direction.
static func _places(kind: WeaponDef.BackKind) -> Dictionary:
	if _back_places.is_empty():
		_back_places[WeaponDef.BackKind.SLUNG] = {
			&"down": BackPlace.new(Vector2(6, -14), false, false),
			&"up": BackPlace.new(Vector2(-4, -12), true, true),
			&"left": BackPlace.new(Vector2(6, -13), false, false),
			&"right": BackPlace.new(Vector2(-6, -13), true, false),
		}
		_back_places[WeaponDef.BackKind.HIP] = {
			&"down": BackPlace.new(Vector2(7, -4), false, true),
			&"up": BackPlace.new(Vector2(-7, -4), true, true),
			&"left": BackPlace.new(Vector2(2, -4), false, false),
			&"right": BackPlace.new(Vector2(-2, -4), true, true),
		}
	return _back_places[kind]
