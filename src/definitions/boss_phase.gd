class_name BossPhase
extends Resource
## A stage of a boss fight, entered when the boss falls to `hp_ratio` of its HP.

@export_range(0.0, 1.0, 0.01) var hp_ratio: float = 0.5
## Shown above the boss when the phase starts.
@export var message: String = "ENRAGED!"
## Added to the boss' stats for the rest of the fight.
@export var bonuses: StatBlock
## Replaces the boss' skills. Empty = keep the current ones.
@export var skills: Array[SkillDef] = []
## Multiplies the attack wind-up: below 1 = less time to dodge.
@export_range(0.2, 2.0, 0.05) var windup_multiplier: float = 1.0
## Body tint for the rest of the fight.
@export var tint: Color = Color.WHITE
