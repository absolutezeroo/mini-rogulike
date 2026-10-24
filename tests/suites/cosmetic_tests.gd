class_name CosmeticTests
extends TestSuite
## The Wardrobe (CosmeticDef, AuraDef, Wardrobe, AuraVfx, WardrobePanel; docs/design/progression.md
## "The Wardrobe", docs/vfx.md "Auras"). Rules and data (run_unit(), from the unit suite): every
## cosmetic's data, what opens each, what the profile keeps and reads back, an aura's parts on
## the hero and their layers, fewer effects, the Nameless Keeper wearing the hero's. The title
## (run_title()): the Wardrobe's rows and buttons, the hero by the Well dressed in what is worn.

const PLAYER: PackedScene = preload("res://src/entities/player/player.tscn")


func run_unit() -> void:
	var saved_worn := Profile.worn.duplicate()
	var saved_wins := Profile.wins.duplicate()
	var saved_victories := Profile.victories
	var saved_fewer := Settings.fewer_effects
	_test_data()
	_test_unlocks()
	_test_profile()
	await _test_on_the_hero()
	_test_keeper()
	Profile.worn = saved_worn
	Profile.wins = saved_wins
	Profile.victories = saved_victories
	Settings.fewer_effects = saved_fewer


func run_title() -> void:
	var saved_worn := Profile.worn.duplicate()
	var saved_wins := Profile.wins.duplicate()
	var saved_victories := Profile.victories
	await _test_wardrobe()
	Profile.worn = saved_worn
	Profile.wins = saved_wins
	Profile.victories = saved_victories


func _auras() -> Array[CosmeticDef]:
	return CONTENT.cosmetics_of(CosmeticDef.Slot.AURA)


## Every cosmetic: an id of its own, a name and words translated, an aura's colors and sizes
## that read (the ground glow under the hero's width, nothing bigger than a room's cell or two).
func _test_data() -> void:
	var auras := _auras()
	check(auras.size() >= 3, "three auras at least: divine, dark, demonic (%d)" % auras.size())
	var ids := {}
	for cosmetic in CONTENT.cosmetics:
		check(cosmetic != null and not cosmetic.id.is_empty() and not ids.has(cosmetic.id), "%s: an id of its own" % (cosmetic.id if cosmetic else &"?"))
		ids[cosmetic.id] = true
		check(not cosmetic.display_name.is_empty() and not cosmetic.description.is_empty(), "%s: a name and its words" % cosmetic.id)
		var aura := cosmetic as AuraDef
		if aura == null:
			continue
		check(aura.element != null and not aura.element.ramp.is_empty(), "%s: its colors from an element's ramp" % aura.id)
		check(aura.radius >= 12.0 and aura.radius <= 32.0 and aura.squash < 1.0, "%s: an oval at the feet, about the hero's width (%.0f)" % [aura.id, aura.radius])
		check(aura.density <= 0.7, "%s: sparse enough for the floor and a telegraph to read through (%.2f)" % [aura.id, aura.density])
		check(aura.halo_outer == 0.0 or aura.halo_outer > aura.halo_inner, "%s: its halo's outer band beyond its inner one" % aura.id)
		check(aura.motes <= 12, "%s: a few motes, not a cloud (%d)" % [aura.id, aura.motes])
	# The demonic one keeps away from the danger red (telegraphs, a monster's warning rim).
	var demonic := CONTENT.get_cosmetic(&"aura_demonic") as AuraDef
	if demonic:
		var bright := demonic.element.shade(demonic.bright_shade)
		check(bright.v < 0.75, "the demonic aura's brightest is a dark crimson, not the danger red (%s)" % bright)


## What opens each: one won descent; one on Keeper; one on Nightmare. Said in a sentence.
func _test_unlocks() -> void:
	Profile.wins = {}
	Profile.victories = 0
	check(_auras().all(func(c: CosmeticDef) -> bool: return not c.is_open()), "a new profile: every aura locked")
	check(_auras().all(func(c: CosmeticDef) -> bool: return not c.unlock_text().is_empty()), "each says what opens it")
	Profile.wins = { "easy": 1 }
	check(CONTENT.get_cosmetic(&"aura_divine").is_open() and not CONTENT.get_cosmetic(&"aura_dark").is_open(), "a won descent (Pilgrim): the divine aura")
	Profile.wins = { "normal": 1 }
	check(CONTENT.get_cosmetic(&"aura_dark").is_open() and not CONTENT.get_cosmetic(&"aura_demonic").is_open(), "won on Keeper: the dark aura too")
	Profile.wins = { "nightmare": 1 }
	check(CONTENT.get_cosmetic(&"aura_demonic").is_open(), "won on Nightmare: the demonic aura")
	check(CONTENT.get_cosmetic(&"aura_dark").unlock_text() == "Win a descent on Keeper.", "the condition named with the difficulty's name: %s" % CONTENT.get_cosmetic(&"aura_dark").unlock_text())


## The profile keeps the one worn, by id, through a save; a locked one is never put on, and one
## worn that is no longer open reads as none.
func _test_profile() -> void:
	Profile.wins = {}
	Profile.worn = {}
	var divine := CONTENT.get_cosmetic(&"aura_divine")
	check(not Wardrobe.wear(divine) and Wardrobe.aura(CONTENT) == null, "a locked aura can't be worn")
	Profile.wins = { "easy": 1 }
	check(Wardrobe.wear(divine) and Wardrobe.aura(CONTENT) == divine and Profile.worn.get("aura") == "aura_divine", "an open one is worn, kept by its id")
	var data: Dictionary = JSON.parse_string(JSON.stringify({ "worn": Profile.worn }))
	check(str((data.worn as Dictionary).get("aura")) == "aura_divine", "it goes through the save as text")
	Profile.wins = {}
	check(Wardrobe.aura(CONTENT) == null and Profile.worn.get("aura") == "aura_divine", "no longer open: worn as nothing, the profile left as it was")
	Profile.wins = { "easy": 1 }
	Profile.worn = { "aura": "no_such_aura" }
	check(Wardrobe.aura(CONTENT) == null, "an aura the game no longer has: none")
	Wardrobe.take_off(CosmeticDef.Slot.AURA)
	check(not Profile.worn.has("aura"), "taken off")


## On the hero: behind his sprites, the glow on the GROUND layer under every body, its halo and
## motes; with fewer effects the glow alone. Worn again: one aura, never two.
func _test_on_the_hero() -> void:
	var player := PLAYER.instantiate() as Player
	player.process_mode = Node.PROCESS_MODE_DISABLED  # (a hero out of a world: nothing moves)
	add_child(player)
	player.setup(CONTENT.player)
	Settings.fewer_effects = false
	for cosmetic in _auras():
		player.wear_aura(cosmetic as AuraDef)
		await _frames(2)
		var aura := player.aura
		check(aura != null and aura.get_parent() == player and VfxLayer.is_behind_body(aura), "%s: on the hero, behind his sprites" % cosmetic.id)
		check(aura.ground != null and VfxLayer.of(aura.ground) == VfxLayer.Layer.GROUND and aura.ground.z_index == VfxLayer.GROUND_Z and not aura.ground.z_as_relative, "%s: its glow on the ground, under every body and over the floor's marks" % cosmetic.id)
		check(aura.get_node_or_null("Halo") != null, "%s: a halo behind him" % cosmetic.id)
		var count := player.get_children().filter(func(n: Node) -> bool: return n is AuraVfx and not n.is_queued_for_deletion()).size()
		check(count == 1, "%s: one aura at a time (%d)" % [cosmetic.id, count])
	Settings.fewer_effects = true
	player.wear_aura(_auras()[0] as AuraDef)
	await _frames(2)
	check(player.aura.ground != null and player.aura.get_node_or_null("Halo") == null and not player.aura.is_processing(), "fewer effects: the glow alone, still (no halo, no motes)")
	Settings.fewer_effects = false
	player.wear_aura(null)
	await _frames(1)
	check(player.aura == null and player.get_children().all(func(n: Node) -> bool: return not n is AuraVfx or n.is_queued_for_deletion()), "none worn: none on him")
	player.queue_free()


## The Nameless Keeper wears the aura the hero he was wore (in his snapshot).
func _test_keeper() -> void:
	var template := CONTENT.dungeon.finale.keeper if CONTENT.dungeon.finale else null
	if template == null:
		return
	var snapshot := KeeperSnapshot.new({ "version": 1, "level": 15, "gear": [], "aura": "aura_dark" })
	var keeper := template.build(snapshot, CONTENT)
	var worn := keeper.traits.filter(func(t: MonsterTrait) -> bool: return t is AuraTrait)
	check(worn.size() == 1 and (worn[0] as AuraTrait).aura.id == &"aura_dark", "the Nameless Keeper wears the hero's aura")
	var bare := template.build(KeeperSnapshot.new({ "version": 1, "level": 15, "gear": [] }), CONTENT)
	check(not bare.traits.any(func(t: MonsterTrait) -> bool: return t is AuraTrait), "none worn: none on him (an older snapshot too)")


## The Wardrobe: a row per aura and "No aura"; Wear on the open ones, Worn on the one worn,
## the locked ones dimmed with what opens them; wearing one dresses the preview and the hero
## by the Well.
func _test_wardrobe() -> void:
	Profile.wins = { "easy": 1 }
	Profile.victories = 1
	Profile.worn = {}
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(2)
	check(title.get_node_or_null("%WardrobeButton") is Button, "the title has a Wardrobe button")
	check(title.hero_aura == null, "nothing worn: the hero by the Well has no aura")
	(title.get_node("%WardrobeButton") as Button).pressed.emit()
	await _frames(2)
	var panel := title.wardrobe
	check(panel.visible, "it opens the Wardrobe")
	var rows := panel.get_node("%Rows") as VBoxContainer
	check(rows.get_child_count() == _auras().size() + 1, "a row per aura and No aura (%d)" % rows.get_child_count())
	var wear := panel.get_node_or_null("%Wear_aura_divine") as Button
	check(wear != null and not wear.disabled and panel.get_node_or_null("%Wear_aura_dark") == null, "Wear on the open aura, none on a locked one")
	var texts := " ".join(_texts(rows))
	check(texts.contains("Locked: Win a descent on Keeper."), "a locked one says what opens it")
	wear.pressed.emit()
	await _frames(2)
	check(Wardrobe.aura(CONTENT) != null and Wardrobe.aura(CONTENT).id == &"aura_divine", "Wear: worn, kept in the profile")
	var worn := panel.get_node_or_null("%Wear_aura_divine") as Button
	check(worn != null and worn.disabled and worn.text == "Worn", "its button says Worn")
	check(panel.get_node("%Preview").find_children("*", "AuraVfx", true, false).size() == 1, "the preview's hero wears it")
	panel.close()
	await _frames(2)
	check(title.hero_aura != null and title.hero_aura.def.id == &"aura_divine", "closed: the hero by the Well wears it")
	title.queue_free()
	await _frames(1)


## Every label's text under `root`.
func _texts(root: Node) -> Array:
	return root.find_children("*", "Label", true, false).map(func(n: Node) -> String: return (n as Label).text)
