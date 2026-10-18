class_name ActDef
extends Resource
## A chapter of the run: a few floors with one look, one set of monsters and a boss at the end.
## The run is the list of acts in DungeonConfig.acts; beating the last boss wins it.

@export var title: String = "Act"
## Shown under the title when the act begins.
@export var subtitle: String = ""
@export var theme: DungeonTheme
## Floors in this act. The last one is the boss arena.
@export_range(1, 10) var floors: int = 3
## Monsters met on the act's floors (their spawn_weight decides how often).
@export var monsters: Array[MonsterDef] = []
@export var boss: BossDef
