class_name LootEntry
extends Resource
## One possible drop in a LootTable.

@export var item: ItemDef
@export_range(1, 1000) var weight: int = 10
