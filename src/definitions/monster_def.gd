class_name MonsterDef
extends ContentDef
## Everything that makes a monster type: stats, weapon, skills, behaviour and rewards.

@export var stats: StatBlock
## Monsters attack with a regular weapon, just like the player.
@export var weapon: WeaponDef
@export var skills: Array[SkillDef] = []

@export_group("Body")
@export var radius: float = 12.0
## Animations: idle_/walk_/attack_/hit_ + down, up, left, right, and "dead". Missing ones fall back.
@export var frames: SpriteFrames
## Moves the sprite so its feet stand on the actor's position (art pixels).
@export var frames_offset: Vector2 = Vector2(0, -7)
## Height of the sprite above the feet, in world pixels (for damage numbers and emotes).
@export var head_height: float = 34.0
## Flies over holes and quicksand (bats, ghosts...).
@export var flies: bool = false
## What it leaves on the floor when hit or killed (blood, slime, ink...). Alpha 0: nothing
## (spirits, flames, skulls).
@export var splat_color: Color = Color(0.42, 0.05, 0.08, 0.85)
## How much of the knockback it ignores: 0 = pushed around freely, 1 = never moves.
## Bosses stand their ground, so no weapon can keep them away from you.
@export_range(0.0, 1.0, 0.05) var knockback_resistance: float = 0.0

## Special ways it fights: a shield, stealing gold, bursting or splitting when it dies...
## (see src/definitions/monster_traits/).
@export var traits: Array[MonsterTrait] = []

@export_group("Behaviour")
## Distance at which the monster notices the player (needs line of sight).
@export var detect_radius: float = 260.0
## Telegraph time before each attack: the player's window to dodge.
@export var attack_windup: float = 0.35
## Pause after attacking.
@export var attack_recovery: float = 0.3
## Ranged monsters back off when the player is closer than this. 0 = always close in.
@export var keep_distance: float = 0.0

@export_group("Sounds")
## Leave empty to use the defaults from the SoundBank.
@export var hurt_sound: AudioStream
@export var death_sound: AudioStream

@export_group("Rewards")
@export var xp_reward: int = 5
@export var loot: LootTable
