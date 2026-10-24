class_name SoulTreeDef
extends Resource
## The Tree of Souls, the shrine's upgrades: four branches (a fantasy each), nodes bought with
## souls, forks where taking one side shuts the other, feats that open some nodes, and at the end
## of each branch an oath (a way to start a run). Every node's effect is an UpgradeDef, so the
## run reads them all through ShrineUpgrades. The tree can be reset every `reset_runs` runs:
## every soul spent comes back.

## The branches' names, colors and what they are about, in column order (two columns each).
@export var branches: PackedStringArray = []
@export var branch_colors: PackedColorArray = []
@export var branch_texts: PackedStringArray = []
## (A fork is saved on one side only, the file can't hold a loop: the other side is linked here,
## weakly, so the two don't keep each other alive.)
@export var nodes: Array[SoulNodeDef] = []:
	set(value):
		nodes = value
		for node in nodes:
			if node and node.excludes:
				node.excludes.link_partner(node)
## Souls to reset the tree (0: free: every soul spent comes back).
@export var reset_cost: int = 0
## Runs to finish (deaths or wins, daily runs too) before the tree can be reset again: a new
## path is earned, not tried on a whim (Profile.runs_since_reset).
@export_range(0, 20) var reset_runs: int = 3
## A run counts toward the reset only once it reached this floor: giving up at once from the
## pause menu, three times over, must not buy a new tree.
@export_range(1, 12) var reset_min_depth: int = 2


func find(id: StringName) -> SoulNodeDef:
	for node in nodes:
		if node and node.id() == id:
			return node
	return null


## Souls spent on the tree (what a reset gives back).
func spent() -> int:
	var total := 0
	for node in nodes:
		if node and node.upgrade:
			for level in mini(node.level(), node.max_level()):
				total += node.upgrade.cost_for_level(level)
	return total


func oaths() -> Array[OathDef]:
	var result: Array[OathDef] = []
	for node in nodes:
		if node and node.oath:
			result.append(node.oath)
	return result


## Oaths whose node was bought.
func open_oaths() -> Array[OathDef]:
	var result: Array[OathDef] = []
	for node in nodes:
		if node and node.oath and node.is_owned():
			result.append(node.oath)
	return result


func columns() -> int:
	var widest := 0
	for node in nodes:
		if node:
			widest = maxi(widest, node.cell.x + 1)
	return widest


func rows() -> int:
	var deepest := 0
	for node in nodes:
		if node:
			deepest = maxi(deepest, node.cell.y + 1)
	return deepest
