class_name GearLookTests
extends TestSuite
## What gear shows of itself (run by the unit suite, in the tree): the rarity looks, the elements
## a weapon carries (ItemLook), loot on the ground by rarity (LootShine), slots, and the hero's
## weapon at rest (ActorRig): docs/vfx.md "Rarity and runes", "The weapon at rest".


func run() -> void:
	_test_rarity_looks()
	_test_carried_elements()
	_test_ground_loot()
	_test_back_weapons()
	_test_rig_gear()


func _weapon(id: String) -> WeaponDef:
	return load("res://data/items/weapons/%s.tres" % id) as WeaponDef


func _affix(id: String) -> ItemAffixDef:
	return load("res://data/affixes/%s.tres" % id) as ItemAffixDef


func _rune(id: String) -> RuneDef:
	return load("res://data/runes/%s.tres" % id) as RuneDef


func _only(found: Array[VfxElementDef], element: VfxElementDef) -> bool:
	return found.size() == 1 and found[0] == element


## A look per rarity, in the rarity's own color, each step adding to the one below.
func _test_rarity_looks() -> void:
	for rarity in ItemRarity.NAMES.size():
		var look := ItemRarity.look(rarity)
		check(look != null and look.element != null and look.element.ramp.size() >= 3, "rarity: %s has a look with a ramp" % ItemRarity.NAMES[rarity])
		if look == null or look.element == null:
			continue
		check(look.color().to_html(false) == ItemRarity.COLORS[rarity].to_html(false), "rarity: %s's look is its color (%s)" % [ItemRarity.NAMES[rarity], ItemRarity.COLORS[rarity].to_html(false)])
		check(look.element.core().get_luminance() > look.element.edge().get_luminance(), "rarity: %s's ramp goes from a bright core to a dark edge" % ItemRarity.NAMES[rarity])
	var common := ItemRarity.look(ItemRarity.COMMON)
	check(common.trim == 0 and common.pillar == 0 and common.glint_every == 0.0 and not common.aura, "rarity: Common lies plain")
	check(ItemRarity.look(ItemRarity.MAGIC).glint_every > 0.0 and ItemRarity.look(ItemRarity.MAGIC).trim > 0, "rarity: Magic glints and is trimmed when worn")
	check(ItemRarity.look(ItemRarity.RARE).pulse_every > 0.0, "rarity: Rare pulses on the floor")
	var epic := ItemRarity.look(ItemRarity.EPIC)
	check(epic.aura and epic.motes > 0 and epic.pillar > 0 and epic.sheen and epic.sweep_every > 0.0, "rarity: Epic has an aura, motes, a pillar of light, a sheen in the bag and a glint when worn")
	for rarity in range(1, ItemRarity.NAMES.size()):
		var below := ItemRarity.look(rarity - 1)
		var look := ItemRarity.look(rarity)
		check(look.trim >= below.trim and look.light_level >= below.light_level and look.pillar >= below.pillar, "rarity: %s shows at least as much as %s" % [ItemRarity.NAMES[rarity], ItemRarity.NAMES[rarity - 1]])


## The elements a weapon carries come from its data: its own element, the statuses its hits
## leave, its affixes' and runes' passives. A plain weapon carries none.
func _test_carried_elements() -> void:
	var fire := VfxElementDef.named(&"fire")
	var frost := VfxElementDef.named(&"frost")
	check(ItemLook.elements(_weapon("katana")).is_empty(), "elements: a plain katana carries none")
	check(_only(ItemLook.elements(_weapon("stick")), frost), "elements: the Frost Staff carries frost")
	var burning := LootRoller.make(_weapon("katana"), ItemRarity.MAGIC, [_affix("burning")]) as WeaponDef
	check(ItemLook.elements(burning).has(fire), "elements: a Burning katana carries fire")
	var ember := LootRoller.make(_weapon("katana"), ItemRarity.COMMON, [], [_rune("ember")]) as WeaponDef
	check(_only(ItemLook.elements(ember), fire), "elements: an Ember Rune is fire")
	var cases := {
		"frozen": &"frost", "venomous": &"poison", "shocking": &"storm", "vampiric": &"blood", "of_embers": &"fire",
	}
	for affix: String in cases:
		var item := LootRoller.make(_weapon("sai"), ItemRarity.MAGIC, [_affix(affix)]) as WeaponDef
		check(ItemLook.elements(item).has(VfxElementDef.named(cases[affix])), "elements: a %s weapon carries %s" % [affix, cases[affix]])
	var plain := LootRoller.make(_weapon("sai"), ItemRarity.RARE, [_affix("sharp"), _affix("of_the_bear")]) as WeaponDef
	check(ItemLook.elements(plain).is_empty(), "elements: bonuses alone carry no element (Sharp, of the Bear)")
	for rune: RuneDef in CONTENT.runes:
		check(ItemLook.rune_element(rune) != null, "elements: the %s shows as an element" % rune.id)
	var runes := {"spark_rune": &"storm", "rime_rune": &"frost", "leech_rune": &"blood", "echo_rune": &"arcane", "pyre_rune": &"fire"}
	for rune: RuneDef in CONTENT.runes:
		if runes.has(String(rune.id)):
			check(ItemLook.rune_element(rune) == VfxElementDef.named(runes[String(rune.id)]), "elements: the %s is %s" % [rune.id, runes[String(rune.id)]])
	check(ItemLook.swing_element(ember, true) == fire, "elements: the hero's katana with an Ember Rune swings in fire")
	check(ItemLook.swing_element(ember, false) == null and ItemLook.swing_element(_weapon("katana"), true) == null, "elements: a plain blade and monsters' blows swing in steel")


func _pickup(item: ItemDef) -> ItemPickup:
	var pickup := (load("res://src/entities/pickup/item_pickup.tscn") as PackedScene).instantiate() as ItemPickup
	pickup.setup(item, false)
	add_child(pickup)
	return pickup


func _parts(pickup: ItemPickup) -> Dictionary:
	var parts := {}
	for child in pickup.get_children():
		if child is LootShine:
			parts[(child as LootShine).part] = VfxLayer.of(child as LootShine)
		elif child is GlowHalo:
			parts[&"halo"] = child
		elif child is LightSource:
			parts[&"light"] = child
	return parts


## Loot on the ground shows its rarity with the right parts, each on its layer; fewer effects
## keeps what tells the rarity and drops the motes and the halo.
func _test_ground_loot() -> void:
	var fewer := Settings.fewer_effects
	Settings.fewer_effects = false
	var base := _weapon("katana")
	var by_rarity: Array[Dictionary] = []
	for rarity in ItemRarity.NAMES.size():
		var item: ItemDef = base if rarity == ItemRarity.COMMON else LootRoller.make(base, rarity, [])
		var dropped := _pickup(item)
		by_rarity.append(_parts(dropped))
		dropped.free()
	check(by_rarity[ItemRarity.COMMON].is_empty(), "ground: a Common item lies plain (no shine, no light)")
	check(by_rarity[ItemRarity.MAGIC].is_empty(), "ground: a Magic item only glints (drawn on its icon)")
	check(by_rarity[ItemRarity.RARE].has(LootShine.Part.PULSE) and by_rarity[ItemRarity.RARE].has(&"light") and not by_rarity[ItemRarity.RARE].has(LootShine.Part.BEAM), "ground: a Rare item pulses gold with a small light, no pillar")
	var epic := by_rarity[ItemRarity.EPIC]
	check(epic.has(LootShine.Part.AURA) and epic.has(LootShine.Part.BEAM) and epic.has(LootShine.Part.MOTES) and epic.has(&"halo") and epic.has(&"light"), "ground: an Epic item has an aura, a pillar of light, motes, a halo and a light")
	check(epic.get(LootShine.Part.BEAM) == VfxLayer.Layer.STANDING, "ground: the pillar of light stands among the actors (STANDING)")
	check(epic.get(LootShine.Part.AURA) == VfxLayer.Layer.GROUND and by_rarity[ItemRarity.RARE].get(LootShine.Part.PULSE) == VfxLayer.Layer.GROUND, "ground: the aura and the pulse lie on the floor (GROUND)")
	Settings.fewer_effects = true
	var pickup := _pickup(LootRoller.make(base, ItemRarity.EPIC, []))
	var few := _parts(pickup)
	pickup.free()
	check(few.has(LootShine.Part.BEAM) and few.has(LootShine.Part.AURA), "ground: fewer effects keeps an Epic item's pillar and aura (they tell its rarity)")
	check(not few.has(LootShine.Part.MOTES) and not few.has(&"halo") and few.size() < epic.size(), "ground: fewer effects drops the motes and the halo (%d parts instead of %d)" % [few.size(), epic.size()])
	Settings.fewer_effects = fewer


## Every weapon the hero can hold has a look at rest: its own small sprite, at the in-hand size.
func _test_back_weapons() -> void:
	var count := 0
	for file in DirAccess.get_files_at("res://data/items/weapons/"):
		if not file.ends_with(".tres"):
			continue
		var weapon := load("res://data/items/weapons/" + file) as WeaponDef
		if weapon == null:
			continue
		count += 1
		check(weapon.back_sprite != null, "back: %s has a look at rest (back_sprite)" % weapon.id)
		if weapon.back_sprite:
			var size := weapon.back_sprite.get_size()
			check(size.x <= 14 and size.y <= 14, "back: %s at rest is small, like the weapon in hand (%dx%d, at most 14)" % [weapon.id, size.x, size.y])
			check(weapon.back_sprite.resource_path.begins_with("res://assets/weapons/back/"), "back: %s's sprite is in assets/weapons/back/" % weapon.id)
	check(count >= 16, "back: every player weapon checked (%d)" % count)
	check(_weapon("book").back_kind == WeaponDef.BackKind.HIP and _weapon("katana").back_kind == WeaponDef.BackKind.SLUNG, "back: the tome hangs at the hip, the katana is slung across the back")


func _rig(hero: bool) -> ActorRig:
	var rig := (load("res://src/entities/rig/actor_rig.tscn") as PackedScene).instantiate() as ActorRig
	add_child(rig)
	rig.setup(load("res://data/visuals/hero.tres") as SpriteFrames, Vector2(0, -8))
	rig.carries_weapon = hero
	return rig


## The hero's weapon at rest: behind him, in front when he turns his back, hidden while the
## weapon is in hand and once dead; monsters carry nothing. His worn gear and weapon wear their
## rarity and elements in their own copies of the body shader, which follow the body's flash.
func _test_rig_gear() -> void:
	var shader: Shader = load("res://assets/shaders/flash.gdshader")
	var uniforms := shader.get_shader_uniform_list().map(func(u: Dictionary) -> String: return u.name)
	for param_name: String in ["trim", "trim_row", "trim_hem", "trim_sweep", "imbue", "imbue_row"]:
		check(uniforms.has(param_name), "rig: the body shader has its %s uniform (worn gear)" % param_name)
	var rig := _rig(true)
	var katana := LootRoller.make(_weapon("katana"), ItemRarity.EPIC, [_affix("burning")], [_rune("ember")]) as WeaponDef
	rig.set_weapon(katana)
	rig._process(0.016)
	var back := rig.back_weapon()
	check(back != null and rig.shows_back_weapon(), "rig: the hero carries his weapon on his back at rest")
	if back == null:
		rig.free()
		return
	for facing: StringName in [&"down", &"left", &"right", &"up"]:
		rig.direction = facing
		rig._update_back()
		var behind := back.get_index() < rig.body.get_index()
		if facing == &"up":
			check(back.get_index() > rig.body.get_index(), "rig: facing up (his back to us), the weapon is in front of the body")
		else:
			check(behind, "rig: facing %s, the weapon is behind the body" % facing)
		check(rig.weapon_aura().get_index() == back.get_index() + 1, "rig: facing %s, the element's motes are drawn right after the weapon" % facing)
	rig.direction = &"right"
	rig._update_back()
	var right_flip := back.flip_h
	rig.direction = &"left"
	rig._update_back()
	check(right_flip != back.flip_h, "rig: the weapon at rest is mirrored as he turns from right to left")
	rig.play_attack(katana, Vector2.DOWN, 0.4)
	check(not rig.shows_back_weapon() and rig.weapon.visible, "rig: while attacking the weapon is in hand, not on the back")
	rig._end_attack()
	check(rig.shows_back_weapon(), "rig: after the attack it goes back on his back")
	var material := rig.weapon_material()
	check(material != null and rig.weapon.material == material and back.material == material, "rig: the weapon in hand and at rest wear one material of their own")
	check(int(material.get_shader_parameter(&"trim")) > 0 and float(material.get_shader_parameter(&"trim_sweep")) > 0.0, "rig: an Epic weapon is trimmed and glints")
	check(float(material.get_shader_parameter(&"imbue")) > 0.0 and int(material.get_shader_parameter(&"imbue_row")) == BodyLook.row(VfxElementDef.named(&"fire")), "rig: a burning weapon licks with fire along its rim")
	check(rig.weapon_aura().elements.has(VfxElementDef.named(&"fire")), "rig: a burning weapon throws fire's motes")
	rig.play_hurt()
	rig._process(0.016)
	check(float(material.get_shader_parameter(&"flash_amount")) == 1.0, "rig: the weapon flashes with the body when he is hit")
	rig.set_weapon(_weapon("katana"))
	check(float(material.get_shader_parameter(&"imbue")) == 0.0 and int(material.get_shader_parameter(&"trim")) == 0 and rig.weapon_aura().elements.is_empty(), "rig: a plain katana shows no element and no trim")
	var helm := LootRoller.make(load("res://data/items/armors/iron_helm.tres"), ItemRarity.RARE, []) as ArmorDef
	rig.set_wear(EquipmentDef.Slot.HEAD, helm.wear_frames, helm.wear_color, helm.rarity)
	var worn := rig.wear_material(EquipmentDef.Slot.HEAD)
	check(worn != null and int(worn.get_shader_parameter(&"trim")) > 0 and bool(worn.get_shader_parameter(&"trim_hem")), "rig: a Rare helm wears its rarity's trim on its brim")
	check(rig.wear_material(EquipmentDef.Slot.BODY) == null, "rig: no body armor, no material of its own")
	var fewer := Settings.fewer_effects
	Settings.fewer_effects = true
	rig.set_weapon(katana)
	rig._process(0.016)
	check(float(material.get_shader_parameter(&"trim_sweep")) == 0.0, "rig: fewer effects stops the worn glint")
	Settings.fewer_effects = fewer
	rig._process(0.016)
	rig.play_death()
	check(not rig.shows_back_weapon(), "rig: a dead hero carries nothing on his back")
	rig.free()
	var monster := _rig(false)
	monster.set_weapon(_weapon("hammer"))
	monster._process(0.016)
	check(monster.back_weapon() == null and monster.weapon_material() == null, "rig: monsters carry no weapon at rest and keep one material")
	monster.free()
