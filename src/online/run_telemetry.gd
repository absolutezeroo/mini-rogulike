class_name RunTelemetry
extends RefCounted
## What the gameplay statistics learn of one run while it is played (Telemetry makes one at
## Events.run_started): it listens to the hero's signals and the Events bus, counts, and when the
## run ends makes the "run_end" event's props (summary()). Boss fights, perk choices, purchases
## and pacts become events of their own as they happen (`pending`, sent with the run's end). It
## never changes the game and the game never asks it anything: without consent nothing it counts
## leaves the device (Telemetry decides). Its counts go into the run's save (to_data(), kept in
## RunState.telemetry) and come back with it (bind()), so a resumed run's end covers the whole
## run, under the same run id. Plain data and signal handlers, no node.

## The hero's skill slot of the roll (Player: slot 0).
const ROLL_SLOT := 0

var run: RunState
var player: Player
## A random id grouping this run's events (not the device's: a new one each run, kept through
## its resumes).
var run_id := ""
## How many times the run was picked up again from its save.
var resumes := 0
## Resumed from a save without the counts (made before they were saved): they miss what came
## before.
var partial := false
## Events made during the run, waiting for its end: {name, props, timestamp}.
var pending: Array[Dictionary] = []

var _counts := {}
## The devices used during the run (InputDevice.Kind names).
var _inputs := {}
var _potion_ratios: Array[float] = []
## A heal from an item in progress: its id -> Health it gave (Actor.healed comes before
## consumable_used: the ratio before drinking is found from it).
var _item_heals := {}
var _last_gold := 0
var _last_spend := 0
## The boss fight going on: {boss, start, dmg_in, hits, potions, monster}; empty: none.
var _boss := {}
## Every signal it listens to, and how: [Signal, Callable] (unbind() lets go of them all).
var _connections: Array[Array] = []


## Follows `new_run` and its hero (Events.run_started).
func bind(new_run: RunState, new_player: Player) -> void:
	run = new_run
	player = new_player
	run_id = Crypto.new().generate_random_bytes(6).hex_encode()
	if run.time > 0.0:
		# A run picked up again: its counts so far, from the save.
		partial = not from_data(run.telemetry)
		resumes += 1
	_last_gold = player.gold
	_inputs[_device_name()] = true
	_connect(player.skill_used, _on_skill_used)
	_connect(player.consumable_used, _on_consumable_used)
	_connect(player.healed, _on_healed)
	_connect(player.charged_attack, func(_attack: ChargedAttackDef) -> void: add("charged"))
	_connect(player.gold_changed, _on_gold_changed)
	_connect(player.dismantled, func(items: Array[ItemDef], _gold: int) -> void: add("dismantled", items.size()))
	_connect(player.item_dropped, func(_item: ItemDef) -> void: add("dropped"))
	_connect(Events.actor_damaged, _on_damaged)
	_connect(Events.hit_dodged, _on_dodged)
	_connect(Events.secret_found, func(_room: Node2D) -> void: add("secrets"))
	_connect(Events.boss_started, _on_boss_started)
	_connect(Events.boss_defeated, func(boss: Variant) -> void: _end_boss(boss as Monster if is_instance_valid(boss) else null, "won"))
	_connect(Events.perks_offered, _on_perks_offered)
	_connect(Events.perk_chosen, _on_perk_chosen)
	_connect(Events.perk_banished, func(perk: PerkDef) -> void: _event(&"perk_banished", { "perk": String(perk.id) }))
	_connect(Events.item_bought, _on_item_bought)
	_connect(Events.pact_ended, _on_pact_ended)
	_connect(Events.stat_counted, _on_stat_counted)
	_connect(InputDevice.changed, func() -> void: _inputs[_device_name()] = true)
	# The Deeps and the Threshold: their own nodes in the Game (found by their group).
	var tree := player.get_tree() if player.is_inside_tree() else null
	if tree:
		var abyss := tree.get_first_node_in_group(Abyss.GROUP) as Abyss
		if abyss:
			_connect(abyss.opened, func(_abyss: AbyssDef) -> void: add("deeps"))
		var threshold := tree.get_first_node_in_group(Threshold.GROUP) as Threshold
		if threshold:
			_connect(threshold.opened, func(_trial: ThresholdDef, _needed: int, _seconds: float) -> void: add("threshold"))


## Stops listening (the run is over, or another began).
func unbind() -> void:
	for connection: Array in _connections:
		var sig: Signal = connection[0]
		if is_instance_valid(sig.get_object()) and sig.is_connected(connection[1]):
			sig.disconnect(connection[1])
	_connections.clear()


func _connect(sig: Signal, callable: Callable) -> void:
	sig.connect(callable)
	_connections.append([sig, callable])


## What the run's save keeps of the counts (RunState.telemetry; JSON).
func to_data() -> Dictionary:
	return {
		"run": run_id,
		"resumes": resumes,
		"partial": partial,
		"counts": _counts.duplicate(),
		"inputs": _inputs.keys(),
		"potion_ratios": _potion_ratios.duplicate(),
	}


## Takes back the counts of to_data() (a resumed run); false if `data` holds none (an older
## save, a damaged one): the counts start from zero.
func from_data(data: Dictionary) -> bool:
	var counts: Variant = data.get("counts")
	var id: Variant = data.get("run")
	if not counts is Dictionary or not id is String or (id as String).is_empty():
		return false
	run_id = id
	resumes = int(data.get("resumes", 0))
	partial = bool(data.get("partial", false))
	_counts.clear()
	for key: Variant in counts:
		var value: Variant = (counts as Dictionary)[key]
		if (value is float or value is int) and key is String:
			_counts[key] = float(value)
	var inputs: Variant = data.get("inputs", [])
	if inputs is Array:
		for device: Variant in inputs:
			_inputs[str(device)] = true
	var ratios: Variant = data.get("potion_ratios", [])
	if ratios is Array:
		for ratio: Variant in ratios:
			if ratio is float or ratio is int:
				_potion_ratios.append(float(ratio))
	return true


## Adds `amount` to the count `key`.
func add(key: String, amount: float = 1.0) -> void:
	_counts[key] = float(_counts.get(key, 0.0)) + amount


func count(key: String) -> float:
	return float(_counts.get(key, 0.0))


# --- Listening ------------------------------------------------------------------

func _on_skill_used(index: int) -> void:
	if index == ROLL_SLOT:
		add("rolls")
		return
	if index >= 0 and index < player.skills.skills.size() and player.skills.skills[index]:
		add("skill.%s.uses" % player.skills.skills[index].id)


func _on_healed(amount: int, source: StringName) -> void:
	if String(source).begins_with("item:"):
		_item_heals[String(source).trim_prefix("item:")] = amount


func _on_consumable_used(item: ItemDef) -> void:
	var id := String(item.id)
	add("potion.%s" % id)
	if item is ConsumableDef and PlayerPack.heals(item as ConsumableDef):
		add("potions")
		var before := player.hp - int(_item_heals.get(id, 0))
		_potion_ratios.append(clampf(float(before) / player.get_max_hp(), 0.0, 1.0))
		if not _boss.is_empty():
			add("potions_boss")
			_boss.potions = int(_boss.potions) + 1
	_item_heals.erase(id)


func _on_gold_changed(gold: int) -> void:
	if gold > _last_gold:
		add("gold_earned", gold - _last_gold)
	elif gold < _last_gold:
		_last_spend = _last_gold - gold
		add("gold_spent", _last_spend)
	_last_gold = gold


func _on_damaged(actor: Actor, hit: HitInfo, damage: int) -> void:
	if not is_instance_valid(player):
		return
	if actor == player:
		add("hits_taken")
		add("dmg_in", damage)
		add("dmg_in.%s" % element_of(hit), damage)
		add("src_in.%s" % source_of(hit, false), damage)
		if hit.cause == &"trap":
			add("trap_hits")
		if not _boss.is_empty():
			_boss.dmg_in = int(_boss.dmg_in) + damage
			_boss.hits = int(_boss.hits) + 1
		return
	if hit.source != player or actor is Player:
		return
	add("dmg_out", damage)
	add("dmg_out.%s" % element_of(hit), damage)
	var kind := source_of(hit, true)
	add("src_out.%s" % kind, damage)
	if String(hit.via).begins_with("skill:"):
		add("skill.%s.dmg" % String(hit.via).trim_prefix("skill:"), damage)
	if hit.is_crit:
		add("crits")
	if damage > count("biggest_hit"):
		_counts["biggest_hit"] = float(damage)


func _on_dodged(actor: Actor, _hit: HitInfo) -> void:
	if actor == player:
		add("dodged")


func _on_boss_started(boss: Monster) -> void:
	if not _boss.is_empty():
		_end_boss(null, "next_form")  # (a boss rising in its next form: the fallen one is over)
	_boss = { "boss": String(boss.def.id) if boss.def else "", "start": run.time, "dmg_in": 0, "hits": 0, "potions": 0, "monster": boss }


## The fight is over: its event. `boss`: the one that fell (null: whichever is fought).
## `outcome`: won, died, left, next_form.
func _end_boss(boss: Monster, outcome: String) -> void:
	if _boss.is_empty():
		return
	var monster: Monster = _boss.monster if is_instance_valid(_boss.monster) else null
	if boss != null and monster != null and boss != monster:
		return  # (another boss fell: not the one fought)
	_event(&"boss", {
		"boss": _boss.boss,
		"time": "%.1f" % (run.time - float(_boss.start)),
		"dmg_in": _boss.dmg_in,
		"hits_taken": _boss.hits,
		"phase": monster.phase_index() if monster else 0,
		"outcome": outcome,
		"potions": _boss.potions,
	})
	_boss = {}


func _on_perks_offered(perks: Array) -> void:
	var ids := PackedStringArray()
	for perk: Variant in perks:
		if perk is PerkDef:
			ids.append(String((perk as PerkDef).id))
	_event(&"perk_offered", { "perks": ",".join(ids) })


func _on_perk_chosen(perk: PerkDef) -> void:
	_event(&"perk_picked", { "perk": String(perk.id), "stacks": player.perks.stacks_of(perk) if is_instance_valid(player) else 1 })


func _on_item_bought(item: ItemDef) -> void:
	_event(&"purchase", { "item": _base_id(item), "rarity": ItemRarity.of(item), "price": _last_spend })


func _on_pact_ended(pact: PactRoom) -> void:
	_event(&"pact", { "pact": String(pact.def.id) if pact.def else "", "outcome": "kept" if pact.outcome == PactRoom.Outcome.KEPT else "broken" })


func _on_stat_counted(stat: String, amount: int) -> void:
	match stat:
		"abyss_escapes":
			add("deeps_escaped", amount)
		"thresholds":
			add("threshold_won", amount)


## An event of the run (sent with its end).
func _event(event_name: StringName, props: Dictionary) -> void:
	props["run"] = run_id
	props["depth"] = run.depth if run else 0
	pending.append({ "name": event_name, "props": props, "timestamp": Telemetry.now_ms() })


# --- The run's end ----------------------------------------------------------------

## The "run_end" event's props (before TelemetryDef.sanitize()), from `summary` (the run as the
## leaderboards see it) and what was counted. `left`: the player left the run, saved, without it
## ending (quit to the title, the app closed): result "abandoned" (or "victory" after a win),
## quit 1; the run may be resumed and end later under the same run id, with every count since
## its start (the dashboard keeps each run id's latest run_end). `final` false: a draft that
## changes nothing here (the app put away, which may come back): a boss fight going on stays open.
func summary(ended: RunSummary, left := false, final := true) -> Dictionary:
	var dead := is_instance_valid(player) and player.is_dead
	var result := "death"
	if ended.won and not dead:
		result = "victory"
	elif left:
		result = "abandoned"
	var props := {
		"run": run_id,
		"resumed": resumes,
		"partial": 1 if partial else 0,
		"quit": 1 if left else 0,
		"os": OS.get_name(),
		"screen": "%dx%d" % [DisplayServer.screen_get_size().x, DisplayServer.screen_get_size().y] if DisplayServer.get_name() != "headless" else "0x0",
		"input": _device_name(),
		"inputs": ",".join(PackedStringArray(_inputs.keys())),
		"diff": String(ended.difficulty),
		"asc": ended.ascension,
		"daily": 1 if ended.daily_day >= 0 else 0,
		"official": 1 if ended.daily_official else 0,
		"oath": String(run.oath.id) if run and run.oath else "",
		"depth": ended.depth,
		"result": result,
		"time": "%.1f" % (run.run_time() if run else ended.time),
		"kills": ended.kills,
		"bosses": ended.bosses,
		"souls": run.souls_awarded if run else 0,
	}
	if is_instance_valid(player):
		props["level"] = player.level
		if player.is_dead:
			props["cause"] = String(player.death_cause)
			props["killer"] = String(player.killer_def.id) if player.killer_def else ""
			props["death_floor"] = ended.depth
		_build(props)
		_left_over(props)
	if not _boss.is_empty() and final:
		_end_boss(null, "died" if dead else "left")
	for key: String in _counts:
		props[key] = roundi(_counts[key])
	var taken := count("hits_taken")
	var dodged := count("dodged")
	props["dodge_rate"] = "%.2f" % (dodged / (dodged + taken)) if dodged + taken > 0 else "0"
	if not _potion_ratios.is_empty():
		var total := 0.0
		for ratio in _potion_ratios:
			total += ratio
		props["potion_health"] = "%.2f" % (total / _potion_ratios.size())
	props["floor_times"] = _floor_times()
	for key in ["rolls", "dodged", "hits_taken", "dmg_out", "dmg_in", "crits", "charged", "secrets", "trap_hits", "deeps", "deeps_escaped", "threshold", "threshold_won", "gold_earned", "gold_spent", "dismantled", "dropped", "potions", "potions_boss", "biggest_hit"]:
		if not props.has(key):
			props[key] = 0
	return props


## The build as the run ends: the weapon (id, rarity, element, runes, affixes), the armor, the
## awakened families, relics and perks (id:level), the skills.
func _build(props: Dictionary) -> void:
	var weapon := player.get_weapon()
	if weapon:
		props["weapon"] = _base_id(weapon)
		props["weapon_rarity"] = weapon.rarity
		props["weapon_element"] = String(weapon.element.id) if weapon.element else ""
		props["weapon_runes"] = _ids(weapon.runes)
		props["weapon_affixes"] = _ids(weapon.affixes)
	var armor_runes := PackedStringArray()
	for slot in [EquipmentDef.Slot.HEAD, EquipmentDef.Slot.BODY]:
		var piece := player.equipment.get_item(slot) as EquipmentDef
		props["head" if slot == EquipmentDef.Slot.HEAD else "body"] = _base_id(piece) if piece else ""
		if piece:
			for rune in piece.runes:
				armor_runes.append(String(rune.id))
	props["armor_runes"] = ",".join(armor_runes)
	var sets := PackedStringArray()
	for synergy in player.perks.awakened():
		sets.append(String(synergy.id))
	props["sets"] = ",".join(sets)
	var relics := PackedStringArray()
	var perks := PackedStringArray()
	for entry in player.perks.entries:
		if entry.perk == null:
			continue
		if entry.perk.rarity == PerkDef.Rarity.RARE:
			relics.append(String(entry.perk.id))
		else:
			perks.append("%s:%d" % [entry.perk.id, entry.stacks])
	props["relics"] = ",".join(relics)
	props["perks"] = ",".join(perks)
	var skills := PackedStringArray()
	for skill in player.skills.skills:
		if skill:
			skills.append(String(skill.id))
	# (not "skills": Talo's data export fills a column with the first prop whose key ends its
	# name, and "kills" sorts first; no key may end another one, privacy_tests)
	props["skill_ids"] = ",".join(skills)


## The build of `hero` as _build() writes it (weapon, armor, sets, relics, perks, skills): the
## feedback form's run details (FeedbackInfo) use it too.
static func build_of(hero: Player) -> Dictionary:
	var props := {}
	if hero == null or not is_instance_valid(hero):
		return props
	var reader := RunTelemetry.new()
	reader.player = hero
	reader._build(props)
	return props


## The consumables still carried (bag and belt): "left.<id>" = how many.
func _left_over(props: Dictionary) -> void:
	var left := {}
	for item in player.inventory.items:
		if item is ConsumableDef:
			left[String(item.id)] = int(left.get(String(item.id), 0)) + 1
	for i in player.belt.slots.size():
		var item := player.belt.item_at(i)
		if item:
			left[String(item.id)] = int(left.get(String(item.id), 0)) + player.belt.count_at(i)
	for id: String in left:
		props["left.%s" % id] = left[id]


## Seconds spent on each floor, in order ("41.2,63.0,...").
func _floor_times() -> String:
	if run == null:
		return ""
	var times := PackedStringArray()
	var before := 0.0
	for split in run.splits:
		if split > 0.0:
			times.append("%.1f" % maxf(split - before, 0.0))
			before = split
	times.append("%.1f" % maxf(run.time - before, 0.0))
	return ",".join(times)


## What a hit was made of, by its element's id ("plain" without one).
static func element_of(hit: HitInfo) -> String:
	return String(hit.element.id) if hit.element and hit.element.id != &"" else "plain"


## Where a hit came from: the kind of what acted (HitInfo.via's "skill", "perk", "rune", "item"
## ...), else a damage over time ("status"), what hurt without a monster (HitInfo.cause: "trap",
## "fall", "blast"...), else the weapon (the hero's) or a monster.
static func source_of(hit: HitInfo, outgoing: bool) -> String:
	var via := String(hit.via)
	if not via.is_empty():
		return via.get_slice(":", 0)
	if hit.is_tick:
		return "status"
	if hit.cause != &"":
		return String(hit.cause)
	if hit.is_secondary:
		return "other"
	return "weapon" if outgoing else "monster"


func _device_name() -> String:
	return String(InputDevice.Kind.keys()[InputDevice.kind]).to_lower()


## An item's id (a rolled piece of gear: its base's).
static func _base_id(item: ItemDef) -> String:
	if item is EquipmentDef and (item as EquipmentDef).base_item:
		return String((item as EquipmentDef).base_item.id)
	return String(item.id) if item else ""


static func _ids(list: Array) -> String:
	var ids := PackedStringArray()
	for thing: Variant in list:
		if thing is Resource and "id" in thing:
			ids.append(String(thing.id))
	return ",".join(ids)
