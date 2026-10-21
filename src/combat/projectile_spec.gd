class_name ProjectileSpec
extends RefCounted
## Everything needed to fire projectiles. Built from a ranged WeaponDef or a ProjectileEffect.

var damage: int = 1
var speed: float = 400.0
var radius: float = 5.0
var max_distance: float = 400.0
var count: int = 1
var spread_degrees: float = 0.0
var pierce: int = 0
var knockback: float = 100.0
var explosion_radius: float = 0.0
var color := Color.WHITE
var texture: Texture2D
## Frames in a row of `texture` (0 = square frames).
var texture_frames: int = 0
## Drawn in flight instead of `texture` (and the element's own shot): a sheet drawn in 16
## directions rather than turned (an arrow, a kunai, the Demon Cyclops' rays of fire).
var sheet: VfxSheetDef
## What it is made of: its look in flight and where it lands, its hits' flash (VfxElementDef).
## Without a texture, the element's own projectile sheet is drawn.
var element: VfxElementDef
## Statuses left on the enemies hit (burn, slow...).
var status: OnHitStatus
## Fired by a passive (shards out of a body, a family's ring of bolts): its hits are secondary
## (HitInfo.is_secondary): they trigger no on-hit perk, so effects can't feed each other.
var secondary: bool = false
## Magic shots (fireballs, bolts) glow in their color, light up the dark and burst on impact;
## 0 for plain things (shurikens, arrows).
var glow: float = 1.0
## An exploding shot (`explosion_radius`) bursts into its element's nova (a ring of ice crystals)
## instead of a blast: the Frost Staff's charged shard shattering.
var nova_burst: bool = false
## A glow around it even when it is drawn from a sheet (a charged shot, heavier than the others).
var halo: bool = false
## A plain thing (an arrow, a shuriken) shot by a weapon that carries an element: it flies in
## it (its matter riding the shot, a trail of its bits, a glow if it shines) without being
## made of it (`element` stays null: the arrow is still an arrow).
var look_element: VfxElementDef
## A second element the weapon carries: a few of its bits in the trail.
var second_element: VfxElementDef
## The element its hits land in when it has no `element` (a Burning bow's arrows: fire).
var hit_element: VfxElementDef
