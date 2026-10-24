class_name NamelessKeeperDef
extends BossDef
## The Nameless Keeper (« Le Gardien Sans Nom »): the hero of a run that ended in "take his place",
## waiting at the bottom of the Well of the next runs instead of Tôma and the Maw (FinaleDef.keeper,
## docs/design/monsters.md "The Nameless Keeper"). This resource is his template: his name, his
## look (the hero's frames, darkened by his traits), his stats before the hero's level, his phases
## (their messages, bonuses, wind-ups; their skills are his own, the lantern's) and the numbers
## below. build() makes the boss of one snapshot (KeeperSnapshot): a copy wearing the hero's
## weapon and armor (WornGearTrait), using the hero's skills as boss skills (telegraphed, on a
## boss' cooldowns), carrying the perks of `kept_perks` the hero had (PerkTrait), his health from
## the hero's level. The floor's rules scale it as any boss (depth, difficulty, ascension).

@export_group("From the hero")
## The hero's level that gives the template's health; each level above or below adds or takes
## `health_per_level` of it, between `health_scale_min` and `health_scale_max` times.
@export_range(1, 60) var reference_level: int = 15
@export_range(0.0, 0.1, 0.005) var health_per_level: float = 0.02
@export_range(0.3, 1.0, 0.05) var health_scale_min: float = 0.8
@export_range(1.0, 3.0, 0.05) var health_scale_max: float = 1.3
## His blow, before the floor's rules: the weapon's damage and his attack together come to this
## (a hero's weapon is made for the hero's own attack, which grows with his levels), plus
## `power_per_rarity` for each step of the weapon above Common.
@export_range(1, 60) var blow_power: int = 16
@export_range(0, 10) var power_per_rarity: int = 1
## With a ranged weapon he keeps this far from the hero (MonsterDef.keep_distance).
@export var ranged_keep_distance: float = 170.0

@export_group("His skills")
## The hero's skills he uses (his weapon's first, then the tome's), at most.
@export_range(0, 6) var max_skills: int = 3
## Warnings before each kind of skill (seconds on Keeper before the phases' wind-ups): a dive
## (a dash strike along a line), a circle (an area), shots, anything else (a buff, a blink).
@export var dive_cast_time: float = 0.75
@export var area_cast_time: float = 0.8
@export var shot_cast_time: float = 0.65
@export var other_cast_time: float = 0.5
## Where his AI uses each kind of skill (MonsterDef's ai_min_range / ai_max_range, in pixels from
## the hero): a dive from `dive_min_range` out to its own distance plus `dive_range_margin` (it
## lands on him); shots up to their reach, at most `shot_max_range` (from within the screen); a
## circle out to its offset and radius plus `area_range_margin` (the hero at its edge); anything
## else (a buff, a blink) from `other_max_range` in.
@export var dive_min_range: float = 50.0
@export var dive_range_margin: float = 30.0
@export var shot_max_range: float = 360.0
@export var area_range_margin: float = 20.0
@export var other_max_range: float = 260.0
## His cooldowns are the hero's times this (a boss doesn't cast as often as a hero).
@export_range(1.0, 4.0, 0.05) var cooldown_scale: float = 1.6
## A dive's band at most this wide (readable: docs/design/monsters.md, Bosses).
@export var dive_width_max: float = 20.0
## Heals in the hero's skills (Holy Light, Smite) are left out: a boss never heals itself.
@export var keeps_heals: bool = false
## A boss' slows never chain into a lock (balance-log 2026-10-23): each lasts this long at most,
## and at most `max_slow_sources` things slow (his weapon counts); later skills lose their slow.
@export var max_slow_seconds: float = 2.0
@export_range(0, 4) var max_slow_sources: int = 2

@export_group("His relics")
## The hero's perks and relics that come with him (the ones that make sense on a boss: what his
## blows do, what hurts those who strike him); the others stay with the hero.
@export var kept_perks: Array[PerkDef] = []
## Their levels, at most.
@export_range(1, 5) var max_perk_stacks: int = 2

@export_group("The record")
## Over the list of the Keepers freed, on his chronicle's page (records()).
@export var records_title: String = "Keepers freed"
## A Keeper freed: "{weapon}, level {level}  -  {date}".
@export var record_line: String = "{weapon}, level {level}  -  {date}"


## The boss of `snapshot` (a KeeperSnapshot's data): a copy of this template, his own.
func build(snapshot: KeeperSnapshot, content: ContentDB) -> NamelessKeeperDef:
	var keeper := duplicate() as NamelessKeeperDef
	keeper.stats = stats.duplicate() if stats else StatBlock.new()
	var held := snapshot.weapon(content)
	if held:
		keeper.weapon = held
	if keeper.weapon and keeper.weapon.kind == WeaponDef.Kind.RANGED:
		keeper.keep_distance = ranged_keep_distance
	var rarity := (keeper.weapon as EquipmentDef).rarity if keeper.weapon else ItemRarity.COMMON
	var damage := keeper.weapon.damage if keeper.weapon else 0
	keeper.stats.attack = maxi(blow_power + power_per_rarity * maxi(rarity - ItemRarity.COMMON, 0) - damage, 0)
	var scale := clampf(1.0 + health_per_level * (snapshot.level() - reference_level), health_scale_min, health_scale_max)
	keeper.stats.max_hp = roundi(keeper.stats.max_hp * scale)
	# His title on the boss bar: the pseudonym he played under, or the template's ("Who You Were").
	var known_as := snapshot.pseudonym()
	if not known_as.is_empty():
		keeper.title = known_as
	# His skills: the hero's, made a boss' (warned, slower), then his own (the lantern's).
	var carried := ItemLook.passive_elements(keeper.weapon)
	var slowing := 1 if keeper.weapon and keeper.weapon.on_hit and keeper.weapon.on_hit.slow > 0.0 else 0
	var own: Array[SkillDef] = []
	for skill in snapshot.skills(content):
		if own.size() >= max_skills:
			break
		var made := boss_skill(skill, carried, slowing < max_slow_sources)
		if made:
			own.append(made)
			if slows(made):
				slowing += 1
	var opening: Array[SkillDef] = own.slice(0, mini(own.size(), 2))
	keeper.skills = opening + skills
	var his_phases: Array[BossPhase] = []
	for phase in phases:
		var copy := phase.duplicate() as BossPhase
		copy.skills = own + phase.skills
		his_phases.append(copy)
	keeper.phases = his_phases
	# His gear and relics, worn as the hero wore them (traits of his own: there is one of him).
	keeper.traits = traits.duplicate()
	var gear := WornGearTrait.new()
	gear.pieces = snapshot.armor(content)
	keeper.traits.append(gear)
	var relics := PerkTrait.new()
	for entry in snapshot.perks(content):
		var perk: PerkDef = entry.perk
		if kept_perks.has(perk):
			for i in mini(int(entry.stacks), mini(max_perk_stacks, perk.max_stacks)):
				relics.perks.append(perk)
	if not relics.perks.is_empty():
		keeper.traits.append(relics)
	return keeper


## A hero's skill as he uses it: a copy warned like a boss' (its cast time by kind, its circle
## or line), on a boss' cooldown, within the readability rules (a dive's band no wider than
## `dive_width_max`, never slowing), dressed in the elements his weapon carries, and with no heal
## (unless `keeps_heals`); its slows `max_slow_seconds` at most, none unless `may_slow`. Null if
## nothing is left of it.
func boss_skill(skill: SkillDef, carried: Array[VfxElementDef] = [], may_slow: bool = true) -> SkillDef:
	if skill == null:
		return null
	var made := skill.duplicate() as SkillDef
	var effects: Array[Effect] = []
	for effect in skill.effects:
		if effect == null or (effect is HealEffect and not keeps_heals):
			continue
		effects.append(_tame_slow(_boss_effect(effect, carried), may_slow))
	if effects.is_empty():
		return null
	made.effects = effects
	made.cooldown = skill.cooldown * cooldown_scale
	# Warned and cast by the kind of its first effect (Effect.telegraph_kind()).
	var first := effects[0]
	made.telegraph_radius = 0.0
	match first.telegraph_kind():
		Effect.Telegraph.DIVE:
			made.cast_time = dive_cast_time
			made.ai_min_range = dive_min_range
			made.ai_max_range = first.ai_reach() + dive_range_margin
		Effect.Telegraph.SHOT:
			made.cast_time = shot_cast_time
			made.ai_min_range = 0.0
			made.ai_max_range = minf(first.ai_reach(), shot_max_range)
		Effect.Telegraph.AREA:
			made.cast_time = area_cast_time
			made.ai_min_range = 0.0
			made.ai_max_range = first.ai_reach() + area_range_margin
			var areas := effects.filter(func(e: Effect) -> bool: return e.telegraph_kind() == Effect.Telegraph.AREA)
			if areas.size() > 1:
				# Several blows: the warning is one circle around him that holds them all.
				var reach := 0.0
				for blow: Effect in areas:
					reach = maxf(reach, blow.warning_reach())
				made.telegraph_radius = reach
		_:
			made.cast_time = other_cast_time
			made.ai_min_range = 0.0
			made.ai_max_range = other_max_range
	made.cast_animation = &"cast"
	return made


## One effect of a hero's skill as his: a dive narrowed to a band his body could cross and
## never slowing; dressed in the elements he carries.
func _boss_effect(effect: Effect, carried: Array[VfxElementDef]) -> Effect:
	return effect.as_boss_skill(carried, dive_width_max)


## `effect` with its slow kept within the rules: `max_slow_seconds` at most, none without
## `may_slow` (a copy when it changes; the hero's skill stays as it is).
func _tame_slow(effect: Effect, may_slow: bool) -> Effect:
	var status := effect.hit_status()
	if status == null or status.slow <= 0.0:
		return effect
	if may_slow and status.slow_duration <= max_slow_seconds:
		return effect
	var tamed := status.duplicate() as OnHitStatus
	if may_slow:
		tamed.slow_duration = max_slow_seconds
	else:
		tamed.slow = 0.0
	return effect.with_hit_status(tamed)  # (a copy keeping its dressing)


## Something in `skill` slows the hero.
static func slows(skill: SkillDef) -> bool:
	return skill.effects.any(func(effect: Effect) -> bool:
		var status := effect.hit_status() if effect else null
		return status != null and status.slow > 0.0)


## The Keepers freed so far, newest first, one line each (his chronicle's page).
func records(content: ContentDB) -> PackedStringArray:
	var lines := PackedStringArray()
	for entry: Variant in Profile.keepers_freed:
		if not entry is Dictionary:
			continue
		var freed := KeeperSnapshot.new(entry as Dictionary)
		var held := freed.weapon_name(content)
		lines.append(tr(record_line).format({
			"weapon": held if not held.is_empty() else "?",
			"level": freed.level(),
			"date": Time.get_date_string_from_unix_time(freed.date()),
		}))
	return lines


func records_heading() -> String:
	return records_title
