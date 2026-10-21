class_name RarityLookDef
extends Resource
## How a rarity shows wherever its item is (docs/vfx.md, "Rarity"): on the ground (ItemPickup,
## LootShine), in a slot (ItemSlot) and worn by the hero (the rig's shader: a trim on the armor
## and the weapon). One per rarity in data/items/rarity_looks.tres, read by ItemRarity.look().
## Each step up adds to the one below, so the language reads as a ladder: Common is plain,
## Magic catches the light now and then, Rare pulses gold, Epic burns with a purple aura, motes
## and a pillar of light seen across the room.

## Its ramp (core to edge), bits and motion, as an element's (the halo, the light, the motes and
## the shader's steps take it): `color()` is the rarity's color (ItemRarity.COLORS).
@export var element: VfxElementDef

@export_group("On the ground")
## Seconds of rest between two glints running over the item (each takes about a second; 0: none).
@export var glint_every: float = 0.0
## Seconds between two rings pulsing out on the floor around it (0: none).
@export var pulse_every: float = 0.0
## A stepped oval of its color breathing on the floor under it.
@export var aura: bool = false
## Motes rising around it at once (0: none). Fewer effects: none.
@export_range(0, 12) var motes: int = 0
## Art pixels of the pillar of light standing on it (0: none), seen from across the room.
@export_range(0, 64) var pillar: int = 0
## A stepped halo of added light around the item (GlowHalo). Fewer effects: none.
@export var halo: bool = false
## A light on the floor in its color (LightField level; 0: none), so it shows in a dark room.
@export_range(0, 15) var light_level: int = 0

@export_group("In a slot")
## A band of light sweeping over the icon now and then (bag, shop, forge).
@export var sheen: bool = false

@export_group("Worn")
## The trim the rig's shader paints on a worn piece (armor, the weapon in hand or on the back):
## 0 none; 1 its rim in the rarity's color; 2 and its brightest pixels gilded.
@export_range(0, 2) var trim: int = 0
## Seconds between two glints sweeping across a worn piece (0: none). Fewer effects: none.
@export var sweep_every: float = 0.0


## The rarity's main color.
func color() -> Color:
	return element.color() if element else Color.WHITE
