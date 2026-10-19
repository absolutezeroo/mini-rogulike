class_name SynergyDef
extends Resource
## A family of perks and relics: Inferno, Frost, Blood, Storm, Arcane... Perks name their
## families (PerkDef.synergies); holding `pieces` different perks of one family wakes its bonus,
## a change in how you play rather than more numbers. The perk screen shows how close you are
## and which card would complete a family.

@export var id: StringName
@export var display_name: String
## What the awakened bonus does (shown on cards, the HUD and the codex).
@export_multiline var description: String
@export var icon: Texture2D
@export var color: Color = Color.WHITE
## Different perks of the family needed to wake the bonus.
@export_range(2, 6) var pieces: int = 3

@export_group("Bonus")
@export var bonuses: StatBlock
@export var passives: Array[Passive] = []
