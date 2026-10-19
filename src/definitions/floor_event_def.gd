class_name FloorEventDef
extends ContentDef
## A floor that is not like the others: haunted, a treasure vault, a swarm, pitch dark...
## Announced when you arrive. Some normal floors get one (DungeonConfig.floor_event_chance),
## never the first floor nor boss floors. Listed in content_db.tres > Floor Events.
## `display_name` is the banner, `description` the line in the log, `color` both.

@export_group("Monsters")
## Multiplies how many monsters each room gets.
@export var monster_count: float = 1.0
@export var monster_hp: float = 1.0
@export var monster_damage: float = 1.0
## Added to the chance for each monster to be an elite.
@export_range(0.0, 1.0) var elite_chance_bonus: float = 0.0

@export_group("Floor")
## Multiplies the darkness (below 1 = darker).
@export var light: float = 1.0
@export_range(0, 10) var extra_chests: int = 0
@export_range(0, 10) var extra_hazards: int = 0
@export_range(0, 4) var extra_encounters: int = 0
## The merchant is always there.
@export var merchant: bool = false

@export_group("Climate")
## Body temperature change per second on the whole floor (see DungeonConfig > Temperature
## and BodyTemperature). Usually 0: the cold is in a zone (cold_zone).
@export var temperature: float = 0.0
## A zone of the floor gripped by it: `zone_rooms` rooms next to each other get this
## (frozen rooms: ice, snow, the cold creeping in).
@export var zone: HeatSourceDef
@export_range(0, 10) var zone_rooms: int = 0
## Campfires (or anything that brings the temperature back to normal), placed in the zone's
## rooms (one each, up to `warm_spot_count`).
@export var warm_spot: HeatSourceDef
@export_range(0, 10) var warm_spot_count: int = 0
## Multiplies the floor's light color (a cold blue, a red glow...).
@export var tint: Color = Color.WHITE
## Replaces the act's ambience (snow falling, wind...).
@export var ambience: AmbienceDef

@export_group("Rewards")
## Multiplies all the gold that drops.
@export var gold: float = 1.0
## Multiplies the quality of everything that drops (see LootRoller).
@export var loot_quality: float = 1.0
