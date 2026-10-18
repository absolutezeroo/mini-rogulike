class_name RandomUtils
## Small helpers around RandomNumberGenerator.


## Picks one entry using integer weights (same index as `entries`).
## Entries with a weight of 0 or less are never picked. Returns null if nothing can be picked.
static func pick_weighted(entries: Array, weights: PackedInt32Array, rng: RandomNumberGenerator) -> Variant:
	var total := 0
	for weight in weights:
		total += maxi(weight, 0)
	if total <= 0:
		return null

	var roll := rng.randi_range(1, total)
	for i in entries.size():
		roll -= maxi(weights[i], 0)
		if roll <= 0:
			return entries[i]
	return entries.back()
