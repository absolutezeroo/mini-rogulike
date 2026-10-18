extends Node
## Generates perks, bosses (+ their weapons, skills, animations) and the new sounds,
## then registers them in content_db.tres, dungeon_config.tres and sound_bank.tres.

const A := "res://assets/"


func _ready() -> void:
	var sounds := _sounds()
	var perks := _perks()
	var bosses := _bosses(sounds)
	var db: ContentDB = load("res://data/content_db.tres")
	db.perks = perks
	ResourceSaver.save(db, db.resource_path)
	var dungeon: DungeonConfig = db.dungeon
	dungeon.bosses = bosses
	dungeon.boss_every = 3
	ResourceSaver.save(dungeon, dungeon.resource_path)
	print("PROGRESSION BUILT")
	get_tree().quit()


func save(res: Resource, path: String) -> Resource:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	res.take_over_path(path)
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("save failed %s %d" % [path, err])
	return res


func tex(path: String) -> Texture2D:
	return load(A + path)


func stats(hp := 0, atk := 0, def := 0, speed := 0.0, crit := 0.0, attack_speed := 0.0) -> StatBlock:
	var s := StatBlock.new()
	s.max_hp = hp
	s.attack = atk
	s.defense = def
	s.move_speed = speed
	s.crit_chance = crit
	s.attack_speed = attack_speed
	return s


# --- Sounds --------------------------------------------------------------------

func sound(id: String, files: Array, pitch: float = 1.0) -> AudioStreamRandomizer:
	var r := AudioStreamRandomizer.new()
	for i in files.size():
		r.add_stream(i, load(A + "audio/" + files[i]))
	r.random_pitch = pitch
	r.random_volume_offset_db = 1.0
	return save(r, "res://data/audio/%s.tres" % id)


func _sounds() -> Dictionary:
	var bank: SoundBank = load("res://data/audio/sound_bank.tres")
	bank.perk_chosen = sound("perk_chosen", ["sfx/magic/perk.ogg"], 1.0)
	bank.boss_roar = sound("boss_roar", ["sfx/creatures/roar.ogg"], 1.05)
	bank.gate = sound("gate", ["sfx/world/gate.ogg"], 1.05)
	bank.boss_defeated = sound("boss_defeated", ["jingles/victory.ogg"], 1.0)
	bank.boss_music = load(A + "audio/music/boss.ogg")
	ResourceSaver.save(bank, bank.resource_path)
	return {
		"slime": load("res://data/audio/slime.tres"),
		"hit_heavy": load("res://data/audio/hit_heavy.tres"),
		"slash": load("res://data/audio/slash.tres"),
		"slash_heavy": load("res://data/audio/slash_heavy.tres"),
		"whoosh": load("res://data/audio/whoosh.tres"),
		"magic": load("res://data/audio/magic.tres"),
		"bolt": load("res://data/audio/bolt.tres"),
		"fireball": load("res://data/audio/fireball.tres"),
		"explosion": load("res://data/audio/explosion.tres"),
		"buff": load("res://data/audio/buff.tres"),
		"spirit": load("res://data/audio/spirit.tres"),
		"death": load("res://data/audio/death.tres"),
		"roar": bank.boss_roar,
	}


# --- Perks -------------------------------------------------------------------

func perk(id: String, name: String, desc: String, color: String, rarity: PerkDef.Rarity, max_stacks: int, weight: int,
		bonuses: StatBlock, passives: Array[Passive] = []) -> PerkDef:
	var p := PerkDef.new()
	p.id = StringName(id)
	p.display_name = name
	p.description = desc
	p.icon = tex("ui/perks/%s.png" % id)
	p.color = Color(color)
	p.rarity = rarity
	p.max_stacks = max_stacks
	p.weight = weight
	p.bonuses = bonuses
	p.passives = passives
	return save(p, "res://data/perks/%s/%s.tres" % ["common" if rarity == PerkDef.Rarity.COMMON else "relics", id])


func _perks() -> Array[PerkDef]:
	var C := PerkDef.Rarity.COMMON
	var R := PerkDef.Rarity.RARE
	var list: Array[PerkDef] = []
	list.append(perk("vitality", "Vitality", "", "#ff6b6b", C, 5, 10, stats(15)))
	list.append(perk("strength", "Strength", "", "#ef476f", C, 5, 10, stats(0, 2)))
	list.append(perk("iron_skin", "Iron Skin", "", "#adb5bd", C, 4, 8, stats(0, 0, 1)))
	list.append(perk("swiftness", "Swiftness", "", "#4fd1c5", C, 3, 7, stats(0, 0, 0, 15)))
	list.append(perk("precision", "Precision", "", "#ffd166", C, 4, 8, stats(0, 0, 0, 0, 0.06)))
	list.append(perk("frenzy", "Frenzy", "", "#f4a261", C, 4, 8, stats(0, 0, 0, 0, 0, 0.12)))

	var vampirism := HealOnKillPassive.new()
	vampirism.heal_per_stack = 2
	list.append(perk("vampirism", "Vampirism", "Slaying an enemy heals 2 HP per level.", "#b5179e", C, 3, 7, null, [vampirism]))

	var thorns := ThornsPassive.new()
	thorns.damage_per_stack = 4
	list.append(perk("thorns", "Thorns", "Enemies that hit you up close take 4 damage per level.", "#c9a227", C, 3, 6, stats(0, 0, 1), [thorns]))

	var ignite := BurnOnHitPassive.new()
	ignite.damage_per_stack = 2
	list.append(perk("ignite", "Ignite", "Your hits set enemies on fire: 2 damage per level every half second, for 3 s.", "#ff8c42", C, 3, 7, null, [ignite]))

	var thunder := CritShockwavePassive.new()
	list.append(perk("thunderclap", "Thunderclap", "Critical hits release a shockwave around the target.", "#8ecae6", C, 3, 6, stats(0, 0, 0, 0, 0.03), [thunder]))

	var shock_roll := DashShockwavePassive.new()
	list.append(perk("shock_roll", "Shock Roll", "Rolling releases a shockwave that hurts and pushes enemies away.", "#9ad1d4", C, 3, 6, null, [shock_roll]))

	var fortune := LootOnKillPassive.new()
	fortune.chance_per_stack = 0.12
	list.append(perk("fortune", "Fortune", "Slain monsters have a 12% chance per level to drop extra loot.", "#80ed99", C, 3, 5, null, [fortune]))

	var phoenix := CheatDeathPassive.new()
	list.append(perk("phoenix_feather", "Phoenix Feather", "Survive a killing blow once per level: back to half HP with a blast.", "#ffd166", R, 2, 10, null, [phoenix]))

	var multishot := ExtraProjectilesPassive.new()
	list.append(perk("multishot", "Multishot", "Everything you shoot fires 1 more projectile per level, fireballs included.", "#7ad3ff", R, 2, 10, null, [multishot]))

	var execute := ExecutePassive.new()
	list.append(perk("executioner", "Executioner", "+60% damage per level against enemies below 35% HP.", "#e63946", R, 2, 10, null, [execute]))

	list.append(perk("guardian_ring", "Guardian Ring", "", "#a8dadc", R, 1, 10, stats(25, 0, 3)))
	list.append(perk("war_banner", "War Banner", "", "#f77f00", R, 1, 10, stats(0, 4, 0, 0, 0.1, 0.1)))
	return list


# --- Bosses ------------------------------------------------------------------

func boss_weapon(id: String, name: String, color: String, damage: int, cooldown: float, reach: float, arc: float,
		knockback: float, fx: String, sounds: Array) -> WeaponDef:
	var w := WeaponDef.new()
	w.id = StringName(id)
	w.display_name = name
	w.glyph = name.substr(0, 1)
	w.color = Color(color)
	w.spawn_weight = 0
	w.kind = WeaponDef.Kind.MELEE
	w.attack_animation = WeaponDef.AttackAnimation.SMASH
	w.damage = damage
	w.cooldown = cooldown
	w.reach = reach
	w.arc_degrees = arc
	w.knockback = knockback
	w.attack_fx = tex("fx/%s.png" % fx)
	w.attack_sound = sounds[0]
	w.hit_sound = sounds[1] if sounds.size() > 1 else null
	return save(w, "res://data/items/weapons/monster/%s.tres" % id)


func skill(id: String, name: String, color: String, cooldown: float, effects: Array[Effect], snd: AudioStream,
		cast_time: float, min_range: float, max_range: float, telegraph := 0.0) -> SkillDef:
	var s := SkillDef.new()
	s.id = StringName(id)
	s.display_name = name
	s.color = Color(color)
	s.cooldown = cooldown
	s.effects = effects
	s.sound = snd
	s.cast_time = cast_time
	s.ai_min_range = min_range
	s.ai_max_range = max_range
	s.telegraph_radius = telegraph
	return save(s, "res://data/skills/boss/%s.tres" % id)


func ring(count: int, speed: float, flat: int, multiplier: float, texture: String, color: String, spread := 360.0) -> ProjectileEffect:
	var e := ProjectileEffect.new()
	e.count = count
	e.spread_degrees = spread
	e.speed = speed
	e.flat_damage = flat
	e.damage_multiplier = multiplier
	e.radius = 7
	e.max_distance = 520
	e.knockback = 140
	e.texture = tex("projectiles/%s.png" % texture)
	e.color = Color(color)
	return e


func summon(monster_ids: Array, count: int, max_alive: int) -> SummonEffect:
	var e := SummonEffect.new()
	var list: Array[MonsterDef] = []
	for id in monster_ids:
		list.append(load("res://data/monsters/%s.tres" % id))
	e.monsters = list
	e.count = count
	e.max_alive = max_alive
	return e


func phase(ratio: float, message: String, bonuses: StatBlock, skills: Array[SkillDef], windup: float, tint: Color) -> BossPhase:
	var p := BossPhase.new()
	p.hp_ratio = ratio
	p.message = message
	p.bonuses = bonuses
	p.skills = skills
	p.windup_multiplier = windup
	p.tint = tint
	return p


## One horizontal strip per animation (assets/characters/bosses/<id>/<anim>.png), square-ish cells.
func boss_frames(id: String, cell: Vector2i, anims: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim: String in anims:
		var sheet := tex("characters/bosses/%s/%s.png" % [id, anim])
		var fps: float = anims[anim][0]
		var loop: bool = anims[anim][1]
		frames.add_animation(anim)
		frames.set_animation_speed(anim, fps)
		frames.set_animation_loop(anim, loop)
		for i in sheet.get_width() / cell.x:
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(i * cell.x, 0, cell.x, cell.y)
			frames.add_frame(anim, frame)
	return save(frames, "res://data/visuals/bosses/%s.tres" % id)


func loot(rolls: int, entries: Dictionary) -> LootTable:
	var table := LootTable.new()
	table.drop_chance = 1.0
	table.rolls = rolls
	for path in entries:
		var entry := LootEntry.new()
		entry.item = load("res://data/items/%s.tres" % path)
		entry.weight = entries[path]
		table.entries.append(entry)
	return table


func boss(id: String, name: String, title: String, desc: String, color: String, frames: SpriteFrames, offset: Vector2,
		head: float, s: StatBlock, weapon: WeaponDef, skills: Array[SkillDef], phases: Array[BossPhase],
		radius: float, windup: float, recovery: float, xp: int, table: LootTable, sounds: Array) -> BossDef:
	var b := BossDef.new()
	b.id = StringName(id)
	b.display_name = name
	b.title = title
	b.description = desc
	b.color = Color(color)
	b.glyph = name.substr(0, 1)
	b.spawn_weight = 0
	b.frames = frames
	b.frames_offset = offset
	b.head_height = head
	b.icon = frames.get_frame_texture(&"idle", 0)
	b.portrait = tex("characters/bosses/%s/portrait.png" % id)
	b.stats = s
	b.weapon = weapon
	b.skills = skills
	b.phases = phases
	b.radius = radius
	b.attack_windup = windup
	b.attack_recovery = recovery
	b.detect_radius = 900
	b.xp_reward = xp
	b.loot = table
	b.hurt_sound = sounds[0]
	b.death_sound = sounds[1]
	return save(b, "res://data/monsters/bosses/%s.tres" % id)


func _bosses(snd: Dictionary) -> Array[BossDef]:
	var enraged := Color(1.0, 0.72, 0.72)
	var list: Array[BossDef] = []

	# --- King Slime (floor 3): slams, rains slime, then splits into smaller slimes.
	var slime_slam := boss_weapon("slime_slam", "Royal Slam", "#7ad3ff", 9, 1.6, 40, 360, 320, "circularslash", [snd.whoosh, snd.hit_heavy])
	var slime_rain := skill("slime_rain", "Slime Rain", "#7ad3ff", 5.0, [ring(10, 230, 4, 0.5, "energyball", "#7ad3ff")], snd.slime, 0.8, 0, 420)
	var slime_storm := skill("slime_storm", "Slime Storm", "#7ad3ff", 4.0, [ring(16, 260, 4, 0.5, "energyball", "#7ad3ff")], snd.slime, 0.7, 0, 420)
	var split := skill("slime_split", "Split", "#80ed99", 9.0, [summon(["slime"], 3, 6)], snd.slime, 0.8, 0, 600)
	var slime_phases: Array[BossPhase] = [
		phase(0.5, "SPLITS!", stats(0, 1, 0, 30), [slime_storm, split], 0.8, enraged),
	]
	var slime_skills: Array[SkillDef] = [slime_rain]
	list.append(boss("king_slime", "King Slime", "Ruler of the Wet Ruins", "A huge slime that bounces, slams and splits.",
		"#7ad3ff", boss_frames("king_slime", Vector2i(62, 52), { "idle": [6.0, true], "cast": [12.0, false] }),
		Vector2(0, -20), 50, stats(300, 0, 2, 60), slime_slam, slime_skills, slime_phases, 26, 0.6, 0.5, 60,
		loot(3, { "consumables/greater_health_potion": 4, "armors/chain_mail": 2, "weapons/axe": 2, "weapons/book": 1 }),
		[snd.slime, snd.death]))

	# --- Demon Cyclops (floor 6): heavy club, fire eye beam, ground quake, calls skeletons, goes berserk.
	var demon_club := boss_weapon("demon_club", "Demon Club", "#ef476f", 13, 1.7, 44, 160, 380, "slashdoublecurved", [snd.slash_heavy, snd.hit_heavy])
	var eye_beam := skill("eye_beam", "Eye Beam", "#ff6b35", 4.0, [ring(5, 380, 6, 0.6, "fireball", "#ff6b35", 50.0)], snd.fireball, 0.6, 100, 460)
	var quake_effect := DamageAreaEffect.new()
	quake_effect.radius = 130
	quake_effect.damage_multiplier = 1.0
	quake_effect.flat_damage = 8
	quake_effect.knockback = 380
	quake_effect.explosive = true
	var quake := skill("quake", "Quake", "#ef476f", 6.0, [quake_effect], snd.explosion, 0.9, 0, 120, 130)
	var call_skeletons := skill("call_skeletons", "Call the Dead", "#e0e1dd", 12.0, [summon(["skeleton"], 2, 6)], snd.spirit, 0.7, 0, 600)
	var cyclops_phases: Array[BossPhase] = [
		phase(0.55, "CALLS THE DEAD!", stats(0, 3, 0, 20), [eye_beam, quake, call_skeletons], 0.85, enraged),
		phase(0.2, "BERSERK!", stats(0, 2, 0, 40, 0.0, 0.4), [], 0.7, Color(1.0, 0.55, 0.55)),
	]
	var cyclops_skills: Array[SkillDef] = [eye_beam, quake]
	list.append(boss("demon_cyclops", "Demon Cyclops", "Warden of the Deep Cave", "A horned giant with a burning eye.",
		"#ef476f", boss_frames("demon_cyclops", Vector2i(50, 50), { "idle": [6.0, true], "walk": [8.0, true] }),
		Vector2(0, -18), 70, stats(380, 0, 3, 70), demon_club, cyclops_skills, cyclops_phases, 22, 0.65, 0.5, 120,
		loot(3, { "consumables/greater_health_potion": 4, "armors/plate_armor": 2, "weapons/hammer": 2, "armors/shadow_cloak": 2 }),
		[snd.hit_heavy, snd.death]))

	# --- Crimson Tengu (floor 9): fast blade, dashes at you, feather storms, summons spirits.
	var tengu_blade := boss_weapon("tengu_blade", "Tengu Blade", "#e63946", 12, 1.1, 50, 150, 260, "slashcurved", [snd.slash, snd.hit_heavy])
	var dash_effect := DashEffect.new()
	dash_effect.distance = 230
	dash_effect.duration = 0.16
	var tengu_dash := skill("tengu_dash", "Gale Step", "#e63946", 3.5, [dash_effect], snd.whoosh, 0.0, 120, 380)
	var feathers := skill("feather_storm", "Feather Storm", "#e63946", 5.0, [ring(12, 300, 5, 0.5, "shuriken", "#e63946")], snd.magic, 0.9, 0, 460)
	var feathers_big := skill("feather_tempest", "Feather Tempest", "#e63946", 4.0, [ring(20, 330, 5, 0.5, "shuriken", "#e63946")], snd.magic, 0.8, 0, 460)
	var call_spirits := skill("call_spirits", "Spirit Call", "#9ad1d4", 11.0, [summon(["spirit"], 2, 5)], snd.spirit, 0.7, 0, 600)
	var tengu_phases: Array[BossPhase] = [
		phase(0.5, "TAKES FLIGHT!", stats(0, 2, 0, 30, 0.05), [feathers_big, tengu_dash, call_spirits], 0.75, enraged),
	]
	var tengu_skills: Array[SkillDef] = [feathers, tengu_dash]
	list.append(boss("crimson_tengu", "Crimson Tengu", "Master of the Forgotten Crypt", "A winged swordsman. Fast, precise, merciless.",
		"#e63946", boss_frames("crimson_tengu", Vector2i(82, 82), { "idle": [8.0, true], "walk": [12.0, true], "cast": [15.0, false], "intro": [10.0, false] }),
		Vector2(0, -18), 70, stats(420, 0, 3, 95, 0.1), tengu_blade, tengu_skills, tengu_phases, 20, 0.5, 0.4, 200,
		loot(3, { "consumables/greater_health_potion": 4, "weapons/stick": 2, "armors/plate_armor": 2, "weapons/hammer": 1 }),
		[snd.hit_heavy, snd.death]))
	return list
