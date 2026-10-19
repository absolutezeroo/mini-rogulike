class_name SceneKey
extends Resource
## What a symbol of a SceneDef's plan stands for: a prop (a random one of `props`), a piece of
## decor, a carpet (a framed floor under every cell of the symbol) or a pond (water over them).

enum Kind { PROP, DECOR, CARPET, POND }

@export var symbol: String = "x"
@export var kind: Kind = Kind.PROP
## PROP: one of them, picked for each (all the same footprint: its cells all carry the symbol).
@export var props: Array[PropDef] = []
## DECOR: one of them on each cell.
@export var pieces: Array[Texture2D] = []
## CARPET: 3x3 tiles (corners, edges, middle) stretched over the symbol's cells.
@export var carpet: Texture2D
@export var carpet_region: Rect2i = Rect2i(0, 0, 48, 48)
## POND: water (a HeatSourceDef with a pond) over the symbol's cells.
@export var pond: HeatSourceDef
## Chance for each to be there (a fallen shelf, a missing grave...): otherwise bare floor.
@export_range(0.0, 1.0) var chance: float = 1.0


## Stands in the way (props, water): must never cut a room in two.
func blocks() -> bool:
	return kind == Kind.PROP or kind == Kind.POND
