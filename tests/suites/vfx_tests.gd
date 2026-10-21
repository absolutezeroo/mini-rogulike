class_name VfxTests
extends TestSuite
## Effects, no game running (run by the unit suite): the elements' data, the pixel grid rules,
## the frame slicer, the palette swap, and which slows show frost (docs/vfx.md).

## Every resource under these folders is checked for sheets that slice and scales on the grid.
const DATA_DIRS: Array[String] = ["res://data/skills", "res://data/items/weapons", "res://data/perks", "res://data/runes", "res://data/affixes", "res://data/monsters", "res://data/vfx"]


func run() -> void:
	_test_elements()
	_test_frame_slicer()
	_test_palette_swap()
	_test_pixel_grid()
	_test_slow_looks()
	_test_data_sheets()
	_test_frost_kit()
	_test_fire_kit()
	_test_earth_kit()


## Each element: an id, a ramp of 3 to 5 colors from a bright core to a dark edge (shadow turned
## inside out), its kit's sheets cut into whole frames at a whole even texel size.
func _test_elements() -> void:
	var all := VfxElementDef.all()
	check(all.size() >= 12, "vfx: the twelve elements are listed (%d)" % all.size())
	var ids := {}
	for element in all:
		check(element != null and element.id != &"", "vfx: an element has an id")
		if element == null:
			continue
		check(not ids.has(element.id), "vfx: element %s listed once" % element.id)
		ids[element.id] = true
		check(element.ramp.size() >= 3 and element.ramp.size() <= 5, "vfx: %s has a ramp of 3 to 5 colors (%d)" % [element.id, element.ramp.size()])
		check(element.accent >= 0 and element.accent < element.ramp.size(), "vfx: %s's accent is a step of its ramp" % element.id)
		var bright := element.core().get_luminance()
		var dark := element.edge().get_luminance()
		if element.id == &"shadow":
			check(bright < dark, "vfx: shadow is the inside-out one (dark core, bright edge)")
		else:
			check(bright > dark, "vfx: %s goes from a bright core to a dark edge" % element.id)
		for color in element.ramp:
			check(color.a == 1.0, "vfx: %s's ramp is opaque" % element.id)
		for sheet: VfxSheetDef in [element.projectile, element.impact, element.piece, element.claw, element.blast]:
			if sheet:
				_check_sheet(sheet, "%s's kit" % element.id)
		if element.slow_look != &"":
			check(StatusFx.LOOKS.look(element.slow_look) != null, "vfx: %s's slow look %s exists" % [element.id, element.slow_look])
	for id: StringName in [&"fire", &"frost", &"water", &"poison", &"storm", &"holy", &"shadow", &"arcane", &"blood", &"spirit", &"earth", &"physical"]:
		check(VfxElementDef.named(id) != null, "vfx: the %s element exists" % id)
	# Every file in the folder is in the list (an unlisted element can't be found by id).
	var listed := 0
	for file in DirAccess.get_files_at("res://data/vfx/elements"):
		if file.ends_with(".tres"):
			listed += 1
	check(listed == all.size(), "vfx: every element file is listed in data/vfx/elements.tres (%d files, %d listed)" % [listed, all.size()])
	check(Palette.FROST.to_html(false) == VfxElementDef.named(&"frost").color().to_html(false), "vfx: Palette.FROST is the frost element's color")
	check(Palette.FIRE.to_html(false) == VfxElementDef.named(&"fire").color().to_html(false), "vfx: Palette.FIRE is the fire element's color")
	# Old content giving only a color gets a ramp of its own hue, not fire's bands.
	var made := VfxElementDef.or_color(null, Color("80ed99"))
	check(made.ramp.size() == 4 and made.color().to_html(false) != VfxElementDef.named(&"fire").color().to_html(false), "vfx: a plain color makes a ramp of its own hue")


func _check_sheet(sheet: VfxSheetDef, what: String) -> void:
	check(sheet.texture != null, "vfx: %s sheet has a texture" % what)
	if sheet.texture == null:
		return
	var size := sheet.frame_size()
	check(size.x * sheet.frame_count() == sheet.texture.get_width() and size.y * sheet.rows() == sheet.texture.get_height(), "vfx: %s sheet (%s) cuts into whole frames" % [what, sheet.texture.resource_path])
	check(sheet.texel >= 2 and sheet.texel % 2 == 0, "vfx: %s sheet is drawn at a whole even texel size (%d)" % [what, sheet.texel])


## Frames in a row: square by default, and a strip of non-square frames cut by its count (the
## 144x10 ice strip is 8 frames of 18x10, not one bar).
func _test_frame_slicer() -> void:
	var strip := ImageTexture.create_from_image(Image.create(144, 10, false, Image.FORMAT_RGBA8))
	check(VfxSheetDef.columns(strip, 8) == 8 and VfxSheetDef.cell_size(strip, 8) == Vector2i(18, 10), "slicer: 144x10 in 8 frames is 18x10 each")
	check(VfxSheetDef.columns(strip, 0) == 1, "slicer: a strip that isn't whole squares is one frame unless told (so data must say)")
	check(not VfxSheetDef.slices_evenly(strip, 0) and VfxSheetDef.slices_evenly(strip, 8) and not VfxSheetDef.slices_evenly(strip, 7), "slicer: says when a count cuts whole frames")
	var orb := ImageTexture.create_from_image(Image.create(64, 16, false, Image.FORMAT_RGBA8))
	check(VfxSheetDef.columns(orb, 0) == 4 and VfxSheetDef.cell_size(orb, 0) == Vector2i(16, 16), "slicer: 64x16 is 4 square frames")
	var long_shot := VfxSheetDef.from_texture(strip, 8)
	check(long_shot.orient == VfxSheetDef.Orient.SNAPPED and long_shot.directions == 16, "slicer: a long shot turns, snapped to 16 directions")
	var round_shot := VfxSheetDef.from_texture(orb)
	check(round_shot.orient == VfxSheetDef.Orient.NONE and round_shot.angle_for(Vector2(1, 1)) == 0.0, "slicer: a round orb is never turned")
	check(is_equal_approx(long_shot.angle_for(Vector2.from_angle(0.3)), TAU / 16.0), "slicer: a turned sheet snaps to the nearest 22.5 degrees")
	check(VfxSheetDef.direction_index(Vector2.RIGHT, 16) == 0 and VfxSheetDef.direction_index(Vector2.DOWN, 16) == 4 and VfxSheetDef.direction_index(Vector2.UP, 16) == 12, "slicer: directions go clockwise from the right")
	var rows := VfxSheetDef.new()
	rows.texture = ImageTexture.create_from_image(Image.create(32, 256, false, Image.FORMAT_RGBA8))
	rows.frames = 2
	rows.orient = VfxSheetDef.Orient.ROWS
	rows.directions = 16
	check(rows.frame_size() == Vector2i(16, 16) and rows.region(1, Vector2.DOWN) == Rect2(16, 64, 16, 16), "slicer: a drawn direction is a row (down: the fifth)")
	var variants := VfxSheetDef.new()
	variants.texture = ImageTexture.create_from_image(Image.create(128, 72, false, Image.FORMAT_RGBA8))
	variants.frames = 8
	variants.variants = 3
	check(variants.frame_size() == Vector2i(16, 24) and variants.region(2, Vector2.RIGHT, 1) == Rect2(32, 24, 16, 24), "slicer: rows of variants")


## The palette swap paints every opaque pixel in the ramp's exact colors, brightest to core,
## darkest to edge, and makes alpha hard.
func _test_palette_swap() -> void:
	var image := Image.create(4, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color.WHITE)
	image.set_pixel(1, 0, Color(0.5, 0.9, 0.95))
	image.set_pixel(2, 0, Color(0.3, 0.5, 0.6, 0.8))
	image.set_pixel(3, 0, Color(1, 1, 1, 0.2))
	var poison := VfxElementDef.named(&"poison")
	var out := VfxRamp.recolor_image(image, poison.ramp)
	check(out.get_pixel(0, 0).to_html(false) == poison.core().to_html(false), "palette swap: the brightest shade takes the core")
	check(out.get_pixel(2, 0).to_html(false) == poison.edge().to_html(false), "palette swap: the darkest shade takes the edge")
	check(out.get_pixel(1, 0).to_html(false) in Array(poison.ramp).map(func(c: Color) -> String: return c.to_html(false)), "palette swap: the shades between take ramp colors")
	check(out.get_pixel(2, 0).a == 1.0 and out.get_pixel(3, 0).a == 0.0, "palette swap: alpha is hard")


func _test_pixel_grid() -> void:
	check(PixelDraw.snap(Vector2(3.1, -2.9)) == Vector2(4, -2), "grid: positions snap to the 2-unit art pixel")
	check(PixelDraw.sheet_scale(6.875) == 6.0 and PixelDraw.sheet_scale(1.78) == 2.0 and PixelDraw.sheet_scale(0.4) == 2.0, "grid: sheet scales snap to whole even sizes, 2 at least")
	var on := 0
	for y in 4:
		for x in 4:
			if PixelDraw.dither(Vector2i(x, y), 0.5):
				on += 1
	check(on == 8 and not PixelDraw.dither(Vector2i(1, 1), 0.0) and PixelDraw.dither(Vector2i(1, 1), 1.0), "grid: dithering at 50% keeps half the pixels, all or none at the ends")
	# Legacy calls with stretched sizes land on whole texels.
	var texture := load("res://assets/fx/magic_circle.png") as Texture2D
	for size: float in [2.5, 3.75, 6.875, 1.5, 5.3]:
		var vfx := SheetVfx.create(texture, Vector2(3, 3), 0.7, size)
		check(vfx.sheet.texel % 2 == 0 and vfx.sheet.texel >= 2, "grid: a sheet wanted at %.2fx is drawn at %dx (whole art pixels)" % [size, vfx.sheet.texel])
		check(vfx.position == PixelDraw.snap(vfx.position), "grid: a sheet effect sits on the grid")
		check(is_equal_approx(fmod(vfx.sheet.angle_for(Vector2.from_angle(0.7)), TAU / 16.0), 0.0), "grid: a turned sheet snaps to 16 directions")
		vfx.free()


## A slow shows frost only when frost (or the cold) causes it: sand, ink, spores, a wail and
## the ground slow without rime.
func _test_slow_looks() -> void:
	var frost := StatusSet.new()
	frost.apply_slow(0.4, 2.0)
	check(frost.active_ids().has(&"slow") and frost.tint().a > 0.0, "slow look: a hit's slow is frost by default (rime, a cold tint)")
	var sand := StatusSet.new()
	sand.apply_slow(0.4, 2.0, &"hit", VfxElementDef.named(&"earth"))
	check(sand.is_slowed() and not sand.active_ids().has(&"slow") and sand.tint().a == 0.0, "slow look: sand slows without frost")
	var ground := StatusSet.new()
	ground.apply_slow(0.5, 0.2, StatusSet.GROUND_SLOW)
	check(ground.is_slowed() and ground.active_ids().is_empty(), "slow look: quicksand shows nothing")
	var cold := StatusSet.new()
	cold.apply_slow(0.3, 0.2, &"cold")
	check(cold.active_ids().has(&"slow"), "slow look: the cold of a frostbound floor shows frost")
	var both := StatusSet.new()
	both.apply_slow(0.4, 2.0, &"hit", VfxElementDef.named(&"shadow"))
	both.apply_slow(0.2, 2.0, &"hit", VfxElementDef.named(&"frost"))
	check(both.active_ids().has(&"slow"), "slow look: frost on a body already inked still shows")
	# The content: what isn't frost says so.
	for path: String in ["res://data/items/weapons/monster/sand_breath.tres", "res://data/skills/boss/sandstorm.tres", "res://data/skills/monster/ink_ring.tres", "res://data/skills/boss/wailing_ring.tres", "res://data/skills/boss/wailing_ring_fierce.tres", "res://data/skills/monster/spore_cloud.tres", "res://data/items/weapons/monster/water_jet.tres"]:
		for status in _statuses(load(path)):
			if status.slow > 0.0:
				check(status.slow_element != null and status.slow_element.slow_look == &"", "slow look: %s slows without frost" % path.get_file())


## Every sheet the data points to cuts into whole frames, and every scale is whole art pixels.
func _test_data_sheets() -> void:
	for resource in _all_resources():
		var where := resource.resource_path.get_file()
		for effect in _effects_of(resource):
			if effect is ProjectileEffect and (effect as ProjectileEffect).texture:
				var shot := effect as ProjectileEffect
				check(VfxSheetDef.slices_evenly(shot.texture, shot.texture_frames), "sheets: %s's shot %s cuts into whole frames" % [where, shot.texture.resource_path.get_file()])
			elif effect is DamageAreaEffect and (effect as DamageAreaEffect).fx:
				var area := effect as DamageAreaEffect
				check(VfxSheetDef.slices_evenly(area.fx, area.fx_frames), "sheets: %s's area sheet cuts into whole frames" % where)
				var frame := VfxSheetDef.cell_size(area.fx, area.fx_frames)
				var vfx := SheetVfx.create(area.fx, Vector2.ZERO, 0.0, area.radius * 2.0 / maxi(frame.x, frame.y), 16.0, frame.x)
				check(vfx.sheet.texel % 2 == 0, "sheets: %s's area sheet is drawn at a whole even scale" % where)
				vfx.free()
			elif effect is DashStrikeEffect and (effect as DashStrikeEffect).fx:
				var dash := effect as DashStrikeEffect
				var vfx := SheetVfx.create(dash.fx, Vector2.ZERO, 0.4, maxf(dash.distance, 40.0) / dash.fx.get_height())
				check(vfx.sheet.texel % 2 == 0, "sheets: %s's dash sheet is drawn at a whole even scale" % where)
				vfx.free()
		if resource is WeaponDef:
			var weapon := resource as WeaponDef
			if weapon.projectile_texture:
				check(VfxSheetDef.slices_evenly(weapon.projectile_texture, weapon.projectile_frames), "sheets: %s's shot cuts into whole frames" % where)
			check(not (weapon.shows_arc() and weapon.attack_fx), "sheets: %s draws its swing's arc or a sheet, not a sheet it would never show" % where)
		if resource is StatusLookDef:
			var look := resource as StatusLookDef
			for pair: Array in [[look.particle, look.particle_frames], [look.burst, look.burst_frames], [look.crust, look.crust_frames]]:
				if pair[0]:
					check((pair[0] as Texture2D).get_width() % int(pair[1]) == 0, "sheets: %s's sheets cut into whole frames" % where)
			check(look.texel % 2 == 0, "sheets: %s is drawn at a whole even scale" % where)
	var campfire := load("res://data/hazards/campfire.tres") as HeatSourceDef
	check(VfxSheetDef.cell_size(campfire.flames, campfire.flame_frames) == Vector2i(8, 12), "sheets: the campfire's flames are 8x12, not squares cut across two flames")
	var thunder := load("res://data/skills/player/thunder.tres") as SkillDef
	var bolt := thunder.effects[0] as DamageAreaEffect
	check(VfxSheetDef.cell_size(bolt.fx, bolt.fx_frames) == Vector2i(20, 28), "sheets: Thunder's bolts are 20x28 frames")


## Frost is the reference kit: every frost user is frost, none shoots a shuriken.
func _test_frost_kit() -> void:
	var frost := VfxElementDef.named(&"frost")
	check(frost.projectile and frost.impact and frost.piece and frost.claw and frost.slow_look == &"slow", "frost: its kit is full (shot, impact, nova piece, claw, chilled look)")
	check(frost.projectile.orient == VfxSheetDef.Orient.ROWS and frost.projectile.directions == 16, "frost: the shard is drawn in 16 directions, never rotated")
	var look := StatusFx.LOOKS.look(&"slow")
	check(look.element == frost and look.crust != null and look.mist_rate > 0.0 and look.particle == null, "frost: the chilled look is rime and cold mist, no snowflake")
	var staff := load("res://data/items/weapons/stick.tres") as WeaponDef
	check(staff.element == frost and staff.projectile_texture == null, "frost: the Frost Staff fires the frost shard")
	check(staff.on_hit != null and staff.on_hit.slow > 0.0, "frost: the Frost Staff's shards chill")
	var users := {
		"res://data/skills/player/ice_shards.tres": "projectile", "res://data/skills/player/frost_nova.tres": "area",
		"res://data/skills/boss/frost_breath.tres": "projectile", "res://data/skills/boss/frost_breath_fierce.tres": "projectile",
		"res://data/skills/boss/hailstorm.tres": "projectile", "res://data/skills/boss/hailstorm_fierce.tres": "projectile",
		"res://data/skills/boss/glacial_dive.tres": "dash", "res://data/skills/boss/glacial_dive_fierce.tres": "dash",
	}
	for path: String in users:
		for effect in _effects_of(load(path)):
			var element: VfxElementDef = effect.get("element")
			check(element == frost, "frost: %s is frost" % path.get_file())
			if effect is ProjectileEffect:
				check((effect as ProjectileEffect).texture == null, "frost: %s shoots the frost shard (no other sprite)" % path.get_file())
			if effect is DamageAreaEffect:
				check((effect as DamageAreaEffect).fx == null, "frost: %s is the nova of crystals, not a stretched sheet" % path.get_file())
	var shards := load("res://data/perks/common/ice_shards.tres") as PerkDef
	check((shards.passives[0] as KillBurstPassive).shard_element == frost, "frost: the Ice Shards perk throws the same shards as the skill")
	for path: String in ["res://data/perks/common/cold_snap.tres", "res://data/perks/common/iron_skin.tres", "res://data/runes/shatter.tres"]:
		check((load(path) as Resource).get("passives")[0].get("element") == frost, "frost: %s's wave is frost" % path.get_file())
	check((load("res://data/perks/synergies/frost.tres") as SynergyDef).passives[0].get("crit_element") == frost, "frost: the Frost synergy freezes in frost")
	check((load("res://data/perks/common/thunderclap.tres") as PerkDef).passives[0].get("element") == VfxElementDef.named(&"storm"), "storm: Thunderclap's wave is the storm, not frost")
	check((load("res://data/items/weapons/monster/water_jet.tres") as WeaponDef).element == VfxElementDef.named(&"water"), "water: the Kappa's jet is water, not ice")
	var fang := load("res://data/items/weapons/monster/frost_fang.tres") as WeaponDef
	check(fang.element == frost and fang.attack_fx == null, "frost: the Azure Wyrm's Frost Fang strikes with frost claws, not blood")
	var skull := load("res://data/monsters/frost_skull.tres") as MonsterDef
	check(skull.weapon.element == frost, "frost: the Frost Skull bites with frost")
	check((skull.traits[0] as DeathBurstTrait).element == frost, "frost: the Frost Skull bursts into a ring of ice")
	# No frost user anywhere shoots a shuriken.
	for resource in _all_resources():
		var shuriken := "shuriken"
		if resource is WeaponDef and (resource as WeaponDef).element == frost and (resource as WeaponDef).projectile_texture:
			check(not (resource as WeaponDef).projectile_texture.resource_path.contains(shuriken), "frost: %s shoots no shuriken" % resource.resource_path.get_file())
		for effect in _effects_of(resource):
			if effect is ProjectileEffect and (effect as ProjectileEffect).element == frost and (effect as ProjectileEffect).texture:
				check(not (effect as ProjectileEffect).texture.resource_path.contains(shuriken), "frost: %s shoots no shuriken" % resource.resource_path.get_file())


## Fire: a full kit (a ball licking back in 16 directions, a burst, licks for novas and arcs, a
## burning claw, an explosion), and every fire user on it: no borrowed fireball.png, no white
## slash for the Flame Arc, no eye beam that is a fireball.
func _test_fire_kit() -> void:
	var fire := VfxElementDef.named(&"fire")
	check(fire.projectile and fire.impact and fire.piece and fire.claw and fire.blast and fire.impact_sound, "fire: its kit is full (shot, impact, licks, claw, explosion, sound)")
	check(fire.projectile.orient == VfxSheetDef.Orient.ROWS and fire.projectile.directions == 16, "fire: the fireball is drawn in 16 directions, its tail never rotated")
	for sheet: VfxSheetDef in [fire.projectile, fire.impact, fire.piece, fire.claw, fire.blast]:
		check(sheet.texture.resource_path.begins_with("res://assets/fx/fire/"), "fire: %s is fire's own art" % sheet.texture.resource_path.get_file())
	var look := StatusFx.LOOKS.look(&"burn")
	check(look.element == fire and look.particle.resource_path.begins_with("res://assets/fx/fire/") and look.burst.resource_path.begins_with("res://assets/fx/fire/"), "fire: a burning body throws the kit's flames")
	check(look.particle.get_width() == look.particle_frames * 8, "fire: the burn's flames are cut 8 wide (12 frames)")
	var shots: Array[String] = ["res://data/skills/player/fireball.tres", "res://data/skills/player/fire_wave.tres",
		"res://data/skills/boss/fire_ring.tres", "res://data/skills/boss/fire_ring_fierce.tres", "res://data/skills/boss/solar_flare.tres",
		"res://data/skills/boss/solar_flare_fierce.tres", "res://data/skills/boss/eye_beam.tres", "res://data/skills/boss/eye_beam_fierce.tres"]
	for path in shots:
		for effect in _effects_of(load(path)):
			var shot := effect as ProjectileEffect
			check(shot.element == fire and shot.texture == null, "fire: %s shoots fire, not a borrowed sprite" % path.get_file())
	var scroll := (load("res://data/items/consumables/fire_scroll.tres") as ConsumableDef).effects[0] as ProjectileEffect
	check(scroll.element == fire and scroll.texture == null, "fire: the Scroll of Fire shoots fire")
	for path: String in ["res://data/skills/boss/eye_beam.tres", "res://data/skills/boss/eye_beam_fierce.tres"]:
		for effect in _effects_of(load(path)):
			var ray := (effect as ProjectileEffect).sheet
			check(ray != null and ray.orient == VfxSheetDef.Orient.ROWS and ray.directions == 16 and ray.frame_size().x > fire.projectile.frame_size().x, "fire: the Demon Cyclops' eye shoots long rays drawn in 16 directions, not fireballs")
			if ray:
				_check_sheet(ray, "the eye beam's")
	for path: String in ["res://data/items/weapons/book.tres", "res://data/items/weapons/monster/fire_breath.tres", "res://data/items/weapons/monster/ghost_flame.tres"]:
		var weapon := load(path) as WeaponDef
		check(weapon.element == fire and weapon.projectile_texture == null, "fire: %s shoots fire" % path.get_file())
	var touch := load("res://data/items/weapons/monster/fire_touch.tres") as WeaponDef
	check(touch.element == fire and touch.attack_fx == null, "fire: the Flame Spirit strikes with a burning claw")
	for path: String in ["res://data/skills/boss/flame_arc.tres", "res://data/skills/boss/flame_arc_fierce.tres"]:
		for effect in _effects_of(load(path)):
			var area := effect as DamageAreaEffect
			check(area.element == fire and area.fx == null and area.fx_follow_aim, "fire: %s sweeps fire licks across its front, not a white slash" % path.get_file())
	check((load("res://data/perks/common/blazing_roll.tres") as PerkDef).passives[0].get("element") == fire, "fire: Blazing Roll leaves a ring of fire")
	for path: String in ["res://data/perks/common/ignite.tres", "res://data/perks/common/kindling.tres"]:
		check((load(path) as PerkDef).passives[0].get("element") == fire, "fire: %s is fire" % path.get_file())
	check((load("res://data/runes/ember.tres") as Resource).get("passives")[0].get("element") == fire, "fire: the Ember rune is fire")
	check((load("res://data/perks/synergies/inferno.tres") as SynergyDef).passives[0].get("blast_element") == fire, "fire: the Inferno synergy bursts in fire")
	for path: String in ["res://data/runes/pyre.tres", "res://data/affixes/of_embers.tres"]:
		check((load(path) as Resource).get("passives")[0].get("blast_element") == fire, "fire: %s bursts in fire" % path.get_file())
	# The dungeon's own flames are the kit's: the campfire, the flame vent, the brazier.
	check((load("res://data/hazards/campfire.tres") as HeatSourceDef).flames.resource_path.begins_with("res://assets/fx/fire/"), "fire: the campfire burns with the kit's flames")
	check((load("res://data/hazards/flame_vent.tres") as TrapDef).active_sheet.resource_path.begins_with("res://assets/fx/fire/"), "fire: the flame vent roars with the kit's column of fire")
	check((load("res://data/props/furniture/brazier.tres") as PropDef).flame.resource_path == "res://src/vfx/flame_vfx.tscn", "fire: a brazier burns with the kit's flames, not soft particles")
	# What only borrowed the fireball isn't fire: a spirit, moss, gold and sand shoot their own.
	var own := {"soul_moth": &"spirit", "moss_heart": &"poison", "gilded_moth": &"holy", "sand_drummer": &"earth"}
	for id: String in own:
		var weapon := (load("res://data/monsters/%s.tres" % id) as MonsterDef).weapon
		check(weapon.element == VfxElementDef.named(own[id]) and weapon.projectile_texture == null, "fire: the %s shoots %s, not fire" % [id, own[id]])
		check(weapon.on_hit == null or weapon.on_hit.burn_damage == 0, "fire: the %s doesn't set you burning" % id)


## Earth: rock spikes, a clod, the ground bursting in dust and rubble; its explosions are dust
## and chunks in its ramp, never fire bands; every earth user on it.
func _test_earth_kit() -> void:
	var earth := VfxElementDef.named(&"earth")
	var fire := VfxElementDef.named(&"fire")
	check(earth.projectile and earth.impact and earth.piece and earth.blast and not earth.emissive, "earth: its kit is full (a clod, an impact, spikes, the ground bursting), and it doesn't glow")
	for sheet: VfxSheetDef in [earth.projectile, earth.impact, earth.piece, earth.blast]:
		check(sheet.texture.resource_path.begins_with("res://assets/fx/earth/"), "earth: %s is earth's own art" % sheet.texture.resource_path.get_file())
	check(earth.blast.linger >= 0.5, "earth: the cracks of a burst stay a moment")
	check(earth.slow_look == &"", "earth: sand slows without frost's rime")
	# Explosion sheets are drawn in their own ramp: no fire band in the ground bursting.
	for element: VfxElementDef in [earth, fire]:
		var allowed: Array = Array(element.ramp).map(func(c: Color) -> String: return c.to_html(false))
		allowed.append(Color(element.residue, 1.0).to_html(false))
		var stray := {}
		var image := element.blast.texture.get_image()
		for y in image.get_height():
			for x in image.get_width():
				var c := image.get_pixel(x, y)
				if c.a > 0.0 and not allowed.has(c.to_html(false)):
					stray[c.to_html(false)] = true
		check(stray.is_empty(), "%s: its explosion sheet is drawn in its ramp only (%s)" % [element.id, ", ".join(stray.keys())])
	for color in earth.ramp:
		check(not fire.ramp.has(color), "earth: no step of its ramp is a fire color")
	for path: String in ["res://data/skills/boss/quake.tres", "res://data/skills/boss/quake_fierce.tres", "res://data/skills/player/sundering_blow.tres"]:
		for effect in _effects_of(load(path)):
			var area := effect as DamageAreaEffect
			check(area.explosive and area.element == earth, "earth: %s bursts the ground (earth), not a fireball" % path.get_file())
	for path: String in ["res://data/skills/player/rock_spike.tres", "res://data/skills/player/fissure.tres", "res://data/skills/player/ground_slam.tres"]:
		for effect in _effects_of(load(path)):
			var area := effect as DamageAreaEffect
			check(area.element == earth, "earth: %s is earth (its rock spikes painted in earth, not lava)" % path.get_file())
			if area.fx:
				var frame := VfxSheetDef.cell_size(area.fx, area.fx_frames)
				check(PixelDraw.sheet_scale(area.radius * 2.0 / maxi(frame.x, frame.y)) == 2.0, "earth: %s's spikes are drawn at the art's 2x" % path.get_file())
	var slam := _effects_of(load("res://data/skills/player/ground_slam.tres"))[0] as DamageAreaEffect
	check(slam.fx == null, "earth: Ground Slam is a ring of spikes composed at 2x, not one sheet at 4x")
	var breath := load("res://data/items/weapons/monster/sand_breath.tres") as WeaponDef
	check(breath.element == earth and breath.projectile_texture == null, "earth: Sand Breath throws clods of sand, no orange halo")
	for effect in _effects_of(load("res://data/skills/boss/sandstorm.tres")):
		var gust := effect as ProjectileEffect
		check(gust.element == earth and gust.texture != null and gust.texture.resource_path.begins_with("res://assets/fx/earth/"), "earth: Sandstorm blows whirls of sand")


# --- Helpers -------------------------------------------------------------------

var _cache: Array[Resource] = []


func _all_resources() -> Array[Resource]:
	if _cache.is_empty():
		for dir in DATA_DIRS:
			_collect(dir)
	return _cache


func _collect(dir: String) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_collect(dir.path_join(sub))
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".tres"):
			var resource := load(dir.path_join(file))
			if resource:
				_cache.append(resource)


## The effects of a skill (and of a perk's skill-like passives: none here).
func _effects_of(resource: Resource) -> Array:
	if resource is SkillDef:
		return (resource as SkillDef).effects.filter(func(e: Effect) -> bool: return e != null)
	return []


## The OnHitStatus of a skill's effects or a weapon.
func _statuses(resource: Resource) -> Array[OnHitStatus]:
	var found: Array[OnHitStatus] = []
	if resource is WeaponDef and (resource as WeaponDef).on_hit:
		found.append((resource as WeaponDef).on_hit)
	for effect in _effects_of(resource):
		var status: OnHitStatus = effect.get("status")
		if status:
			found.append(status)
	return found
