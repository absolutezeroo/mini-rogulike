class_name PerkSet
extends RefCounted
## The perks an actor collected during the run, with their stack counts, and the families they
## woke (SynergyDef: three different perks of a family). Adds up their stats and forwards
## gameplay events to their passives, the awakened families' and the worn gear's affixes'
## (ItemAffixDef.passives) included.

signal changed
## A family just woke: its bonus is on from now.
signal synergy_awakened(synergy: SynergyDef)


## One collected perk, or something else granting passives (an awakened family, an affix on
## worn gear: `perk` null, `granted` set, 1 stack).
class Entry:
	var perk: PerkDef
	var synergy: SynergyDef
	var granted: Array[Passive] = []
	var stacks: int = 1
	## Run state for the passives (charges, counters...).
	var memory := {}
	## Worn gear only: which affix or rune (and which of identical ones) it comes from.
	var gear_key := ""
	## Worn gear only: "rune:<id>" or "affix:<id>" (what heals, for the balance tools).
	var gear_tag: StringName = &""

	func passives() -> Array[Passive]:
		return perk.passives if perk else granted

	## Who this entry is, for Actor.heal_source: "perk:<id>", "family:<id>", "rune:<id>"...
	## Only read by the balance tools (tools/balance/).
	func source_tag() -> StringName:
		if perk:
			return StringName("perk:%s" % perk.id)
		if synergy:
			return StringName("family:%s" % synergy.id)
		return gear_tag


var entries: Array[Entry] = []
## The awakened families, in the order they woke.
var _awake: Array[Entry] = []
## Affixes of the worn gear that do something (see set_gear()).
var _gear: Array[Entry] = []
## Collected perks, awakened families and gear together (what the events go through).
var _all: Array[Entry] = []


func add(perk: PerkDef) -> void:
	var entry := get_entry(perk)
	if entry:
		entry.stacks = mini(entry.stacks + 1, perk.max_stacks)
	else:
		entry = Entry.new()
		entry.perk = perk
		entries.append(entry)
	_refresh_synergies(true)
	changed.emit()


func get_entry(perk: PerkDef) -> Entry:
	for entry in entries:
		if entry.perk == perk:
			return entry
	return null


func stacks_of(perk: PerkDef) -> int:
	var entry := get_entry(perk)
	return entry.stacks if entry else 0


func can_take(perk: PerkDef) -> bool:
	return stacks_of(perk) < perk.max_stacks


func clear() -> void:
	entries.clear()
	_refresh_synergies(false)
	changed.emit()


# --- Families (SynergyDef) ----------------------------------------------------

## Different perks of `synergy` collected.
func pieces_of(synergy: SynergyDef) -> int:
	var count := 0
	for entry in entries:
		if entry.perk.synergies.has(synergy):
			count += 1
	return count


func is_awake(synergy: SynergyDef) -> bool:
	return _awake.any(func(entry: Entry) -> bool: return entry.synergy == synergy)


func awakened() -> Array[SynergyDef]:
	var result: Array[SynergyDef] = []
	for entry in _awake:
		result.append(entry.synergy)
	return result


## Every family the collected perks belong to (awake or not), first met first.
func families() -> Array[SynergyDef]:
	var result: Array[SynergyDef] = []
	for entry in entries:
		for synergy in entry.perk.synergies:
			if synergy and not result.has(synergy):
				result.append(synergy)
	return result


## Taking `perk` (not owned yet) would wake `synergy`.
func would_complete(perk: PerkDef, synergy: SynergyDef) -> bool:
	return stacks_of(perk) == 0 and not is_awake(synergy) and pieces_of(synergy) + 1 >= synergy.pieces


## Wakes the families that have enough pieces (they never fall asleep again during a run,
## but a cleared or reloaded set starts over). `announce`: tell who listens.
func _refresh_synergies(announce: bool) -> void:
	if entries.is_empty():
		_awake.clear()
	for synergy in families():
		if not is_awake(synergy) and pieces_of(synergy) >= synergy.pieces:
			var entry := Entry.new()
			entry.synergy = synergy
			entry.granted = synergy.passives
			_awake.append(entry)
			if announce:
				synergy_awakened.emit(synergy)
	_rebuild_all()


func _rebuild_all() -> void:
	_all = entries.duplicate()
	_all.append_array(_awake)
	_all.append_array(_gear)


## The affixes and runes of what the actor wears: those with passives join the events (two
## items with the same affix, two identical runes, count twice).
## Counters carry over (the 3 hits towards a Spark rune's lightning survive swapping a helmet).
func set_gear(affixes: Array[ItemAffixDef], runes: Array[RuneDef] = []) -> void:
	# The run state of what was worn, by source and occurrence (two identical runes: two entries).
	var kept := {}
	for entry in _gear:
		kept[entry.gear_key] = entry.memory
	_gear.clear()
	var granting: Array = []
	granting.append_array(affixes)
	granting.append_array(runes)
	var seen := {}
	for source: Resource in granting:
		var passives: Array = source.get("passives") if source else []
		if passives.is_empty():
			continue
		var occurrence: int = seen.get(source, 0)
		seen[source] = occurrence + 1
		var entry := Entry.new()
		entry.granted = passives
		entry.gear_key = "%d:%d" % [source.get_instance_id(), occurrence]
		entry.gear_tag = StringName("%s:%s" % ["rune" if source is RuneDef else "affix", source.get("id")])
		entry.memory = kept.get(entry.gear_key, {})
		_gear.append(entry)
	_rebuild_all()


## For save files: [{ perk, stacks, memory }].
func to_data() -> Array:
	return entries.map(func(entry: Entry) -> Dictionary:
		return { "perk": RunSave.ref(entry.perk), "stacks": entry.stacks, "memory": _lasting(entry.memory) })


## What of a passive's memory lasts beyond this session: keys starting with "_" hold frame
## numbers (the engine's frame counter starts over when the game does), they are not saved.
static func _lasting(memory: Dictionary) -> Dictionary:
	var result := {}
	for key: Variant in memory:
		if not str(key).begins_with("_"):
			result[key] = memory[key]
	return result


func load_data(data: Array) -> void:
	entries.clear()
	for saved: Dictionary in data:
		var perk := RunSave.load_ref(saved.get("perk")) as PerkDef
		if perk == null:
			continue
		var entry := Entry.new()
		entry.perk = perk
		entry.stacks = int(saved.get("stacks", 1))
		entry.memory = saved.get("memory", {})
		entries.append(entry)
	_awake.clear()
	_refresh_synergies(false)
	changed.emit()


func total_bonuses() -> StatBlock:
	var total := StatBlock.new()
	for entry in entries:
		if entry.perk.bonuses:
			total = total.plus(entry.perk.bonuses.times(entry.stacks))
	for entry in _awake:
		if entry.synergy.bonuses:
			total = total.plus(entry.synergy.bonuses)
	return total


# --- Events (called by Actor and World) --------------------------------------

func modify_outgoing_hit(owner: Actor, target: Actor, hit: HitInfo) -> void:
	for entry in _all:
		for passive in entry.passives():
			passive.modify_outgoing_hit(owner, target, hit, entry)


func on_hit_dealt(owner: Actor, target: Actor, hit: HitInfo, damage: int) -> void:
	var outer := Actor.heal_source  # balance tools: who heals (see Actor.healed); restored after
	for entry in _all:
		Actor.heal_source = entry.source_tag()
		for passive in entry.passives():
			passive.on_hit_dealt(owner, target, hit, damage, entry)
	Actor.heal_source = outer


func on_damaged(owner: Actor, hit: HitInfo, damage: int) -> void:
	var outer := Actor.heal_source  # balance tools: who heals (see Actor.healed); restored after
	for entry in _all:
		Actor.heal_source = entry.source_tag()
		for passive in entry.passives():
			passive.on_damaged(owner, hit, damage, entry)
	Actor.heal_source = outer


func on_kill(owner: Actor, victim: Actor) -> void:
	var outer := Actor.heal_source  # balance tools: who heals (see Actor.healed); restored after
	for entry in _all:
		Actor.heal_source = entry.source_tag()
		for passive in entry.passives():
			passive.on_kill(owner, victim, entry)
	Actor.heal_source = outer


func on_skill_used(owner: Actor, skill: SkillDef) -> void:
	var outer := Actor.heal_source  # balance tools: who heals (see Actor.healed); restored after
	for entry in _all:
		Actor.heal_source = entry.source_tag()
		for passive in entry.passives():
			passive.on_skill_used(owner, skill, entry)
	Actor.heal_source = outer


func on_dash(owner: Actor) -> void:
	for entry in _all:
		for passive in entry.passives():
			passive.on_dash(owner, entry)


func modify_projectiles(owner: Actor, spec: ProjectileSpec) -> void:
	for entry in _all:
		for passive in entry.passives():
			passive.modify_projectiles(owner, spec, entry)


func on_floor_started(owner: Actor) -> void:
	for entry in _all:
		for passive in entry.passives():
			passive.on_floor_started(owner, entry)


func on_died(owner: Actor) -> void:
	for entry in _all:
		for passive in entry.passives():
			passive.on_died(owner, entry)


func prevent_death(owner: Actor) -> bool:
	for entry in _all:
		for passive in entry.passives():
			if passive.prevent_death(owner, entry):
				return true
	return false
