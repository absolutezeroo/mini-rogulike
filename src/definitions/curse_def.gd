class_name CurseDef
extends ContentDef
## The Well curses a whole floor: frozen, burning, lightless... Announced on arrival by the
## curse card (CurseCard). Some floors get one, more often on harder difficulties
## (DifficultyDef.curse_chance); never the first floor nor boss floors. A cursed floor has no
## floor event. Listed in content_db.tres > Curses.
## `display_name` is the curse's name, `description` the short rule, `color` its color.

## What the Well does, in the story's words (on the curse card).
@export_multiline var lore: String

@export_group("Climate")
## Body temperature change per second everywhere on the floor (BodyTemperature):
## below 0 freezes, above 0 burns.
@export var temperature: float = 0.0
## What brings the temperature back to normal (campfires, oases): one in the first room, then
## this many more in other rooms (random between the two). Few: the hero has to push on.
@export var warm_spot: HeatSourceDef
@export var spot_count: Vector2i = Vector2i(2, 3)
## Laid over every room, just for the look (ice...). Its `heat` should be 0.
@export var room_look: HeatSourceDef

@export_group("Darkness")
## The whole floor in the dark, but around the hero.
@export var darkness: DarkRoomDef

@export_group("Look")
## Multiplies the floor's light color.
@export var tint: Color = Color.WHITE
## Replaces the act's ambience (snow falling, embers...).
@export var ambience: AmbienceDef

@export_group("Rewards")
## Braving a curse pays: better loot, more gold.
@export var loot_quality: float = 1.3
@export var gold: float = 1.2
