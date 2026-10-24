class_name CombatRulesDef
extends Resource
## The game's core combat numbers (`data/combat/combat_rules.tres`, read through `Combat.RULES`):
## how hard a critical hit lands, how much a hit varies, how armor bites, how far a skill's
## cooldown can be cut. The most important balance numbers in the game, in data so a balance
## pass never touches code (docs/balance.md).

## A critical hit's damage multiplier, before the attacker's own bonus (Actor.crit_damage_bonus:
## the Oath of the Edge, perks).
@export_range(1.0, 4.0, 0.05) var crit_multiplier: float = 1.75
## Every hit (not a side effect's: Combat.make_secondary_hit) deals its amount times a random
## factor within 1 - this and 1 + this.
@export_range(0.0, 0.5, 0.01) var damage_variance: float = 0.15
## Armor with diminishing returns: a hit of A against D armor deals A x A / (A + this x D)
## (Combat.mitigate). 1: about D points off a much bigger hit, half of a hit the armor's size,
## never harmless.
@export_range(0.1, 4.0, 0.05) var armor_weight: float = 1.0
## Cooldown reduction (StatBlock.cooldown_reduction) counts up to this share (SkillSet): past it,
## more is wasted.
@export_range(0.0, 0.9, 0.05) var max_cooldown_reduction: float = 0.5
## How hard a delayed blast (a skull's fuse, a bomb's: Combat.delayed_blast) pushes what it hits.
@export var delayed_blast_knockback: float = 260.0
