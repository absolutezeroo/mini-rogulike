class_name SoulNodeDef
extends Resource
## A node of the Tree of Souls (SoulTreeDef), bought at the shrine with souls. What it does is
## its `upgrade` (UpgradeDef: stats, a head start, perk choices, new items, run rules); the node
## says where it sits and what opens it: the nodes before it, a feat, and the one it shuts.

## Where it sits: the column (0-7: two per branch) and the row (0 = the branch's root).
@export var cell: Vector2i
## Its branch's index in SoulTreeDef.branches.
@export_range(0, 3) var branch: int = 0
@export var upgrade: UpgradeDef
## Opened once ANY of these has a level (empty: a branch's root, open from the start).
@export var requires: Array[SoulNodeDef] = []
## A feat to have done first (an achievement), or null.
@export var feat: AchievementDef
## The other side of a fork: buying one shuts the other (until the tree is reset).
@export var excludes: SoulNodeDef
## A capstone: it opens this oath (a way to start a run, chosen before it).
@export var oath: OathDef

## The node whose `excludes` points here (SoulTreeDef links it).
var _partner: WeakRef


func link_partner(other: SoulNodeDef) -> void:
	_partner = weakref(other)


## The other side of its fork, whichever side saved it (null: not a fork).
func partner() -> SoulNodeDef:
	if excludes:
		return excludes
	return _partner.get_ref() as SoulNodeDef if _partner else null


func id() -> StringName:
	return upgrade.id if upgrade else &""


func display_name() -> String:
	if oath:
		return oath.display_name
	return upgrade.display_name if upgrade else "?"


func level() -> int:
	return Profile.level_of(upgrade) if upgrade else 0


func max_level() -> int:
	return upgrade.max_level if upgrade else 1


func is_owned() -> bool:
	return level() > 0


func is_maxed() -> bool:
	return level() >= max_level()


## Its parents allow it (any one owned), whatever the souls.
func is_reachable() -> bool:
	return requires.is_empty() or requires.any(func(node: SoulNodeDef) -> bool: return node != null and node.is_owned())


func is_feat_done() -> bool:
	return feat == null or Profile.achievements.has(String(feat.id))


## The other side of its fork was taken.
func is_shut() -> bool:
	var other := partner()
	return other != null and other.is_owned() and not is_owned()


## Can be bought now (souls aside).
func is_open() -> bool:
	return not is_maxed() and not is_shut() and is_reachable() and is_feat_done()


func next_cost() -> int:
	return upgrade.cost_for_level(level()) if upgrade else 0


## Why it can't be bought, in plain words ("" when it can, souls aside).
func blocker() -> String:
	if is_maxed():
		return ""
	if is_shut():
		return "You took %s instead (reset the tree to change)." % partner().display_name()
	if not is_reachable():
		var names := PackedStringArray()
		for node in requires:
			if node:
				names.append(node.display_name())
		return "Needs %s first." % " or ".join(names)
	if not is_feat_done():
		return "Feat: %s" % feat.description
	return ""
