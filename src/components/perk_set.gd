class_name PerkSet
extends RefCounted
## The perks an actor collected during the run, with their stack counts.
## Adds up their stats and forwards gameplay events to their passives.

signal changed


## One collected perk.
class Entry:
	var perk: PerkDef
	var stacks: int = 1
	## Run state for the perk's passives (charges, cooldowns...).
	var memory := {}


var entries: Array[Entry] = []


func add(perk: PerkDef) -> void:
	var entry := get_entry(perk)
	if entry:
		entry.stacks = mini(entry.stacks + 1, perk.max_stacks)
	else:
		entry = Entry.new()
		entry.perk = perk
		entries.append(entry)
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
	changed.emit()


## For save files: [{ perk, stacks, memory }].
func to_data() -> Array:
	return entries.map(func(entry: Entry) -> Dictionary:
		return { "perk": RunSave.ref(entry.perk), "stacks": entry.stacks, "memory": entry.memory })


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
	changed.emit()


func total_bonuses() -> StatBlock:
	var total := StatBlock.new()
	for entry in entries:
		if entry.perk.bonuses:
			total = total.plus(entry.perk.bonuses.times(entry.stacks))
	return total


# --- Events (called by Actor and World) --------------------------------------

func modify_outgoing_hit(owner: Actor, target: Actor, hit: HitInfo) -> void:
	for entry in entries:
		for passive in entry.perk.passives:
			passive.modify_outgoing_hit(owner, target, hit, entry)


func on_hit_dealt(owner: Actor, target: Actor, hit: HitInfo, damage: int) -> void:
	for entry in entries:
		for passive in entry.perk.passives:
			passive.on_hit_dealt(owner, target, hit, damage, entry)


func on_damaged(owner: Actor, hit: HitInfo, damage: int) -> void:
	for entry in entries:
		for passive in entry.perk.passives:
			passive.on_damaged(owner, hit, damage, entry)


func on_kill(owner: Actor, victim: Actor) -> void:
	for entry in entries:
		for passive in entry.perk.passives:
			passive.on_kill(owner, victim, entry)


func on_skill_used(owner: Actor, skill: SkillDef) -> void:
	for entry in entries:
		for passive in entry.perk.passives:
			passive.on_skill_used(owner, skill, entry)


func on_dash(owner: Actor) -> void:
	for entry in entries:
		for passive in entry.perk.passives:
			passive.on_dash(owner, entry)


func modify_projectiles(owner: Actor, spec: ProjectileSpec) -> void:
	for entry in entries:
		for passive in entry.perk.passives:
			passive.modify_projectiles(owner, spec, entry)


func on_died(owner: Actor) -> void:
	for entry in entries:
		for passive in entry.perk.passives:
			passive.on_died(owner, entry)


func prevent_death(owner: Actor) -> bool:
	for entry in entries:
		for passive in entry.perk.passives:
			if passive.prevent_death(owner, entry):
				return true
	return false
