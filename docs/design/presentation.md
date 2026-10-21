# Look, sound and feel

## Game feel

- **Weight of a blow**: every hit you land pushes the camera a few pixels along the blow, a shot
  recoils it back, a hit taken knocks it away (`GameCamera.kick`, `Events.camera_kick`, springing
  back in real time, apart from the shake; both follow the Screen shake option). A killing blow
  stops the world a moment longer; killing an elite or better slows it down for a beat
  (`HitStop.slow`).
- **What monsters are made of** (`ImpactMaterialDef`, `data/materials/`: flesh, bone, slime,
  armor, spirit, plant; `MonsterDef.material`): a hit sounds like it (a punch in flesh, a dry knock
  on bone, a squelch, a clang on armor, a chime on spirits, played over the monster's cry), its
  sparks take its color, and when it dies it flings **chips** of itself that land and stay for the
  whole floor (`SplatLayer.add_debris`): bone shards, slime drops, bits of armor. Broken crates and
  barrels leave their splinters too. Sounds: Kenney "Impact Sounds" (CC0).
- **VFX**: hand-drawn sprite-sheet effects (slashes, claws, explosions, smoke, magic circles,
  "!" emote when a monster spots you) plus pixel particles for hits, dust and sparkles
  (`src/vfx/particles/*.tscn`, edit them in the inspector), dash afterimages, animated projectiles,
  squash on hit, popping damage numbers, red vignette when hurt or low on HP.
- **Atmosphere** (`AmbienceDef` > Atmosphere, one per biome and curse): the whole picture takes
  the biome's colors (`screen.gdshader`: shadows and highlights graded toward two tints,
  saturation, contrast), bright things **bloom** (fire, gold, lights), the air **trembles** with
  heat in the ruins and the desert (rows of pixels sliding by whole pixels). Over the floor, in
  world space (`AtmosphereLayer`, `atmosphere.gdshader`, dithered on the art's grid): **shafts of
  light** falling from cracks above (garden, temple, library, cave, desert), **leaf shadows**
  drifting in the garden, **mist** creeping over the crypt and the flooded caverns, **water light**
  dancing on the floor of the flooded caverns.
- **Attack effects** (shaders, all on the art's pixel grid): a melee swing draws a crescent at the
  weapon's reach and arc (`SwingVfx`, `swing.gdshader`: white cutting edge, the weapon's
  `trail_color` behind, thinning out in dithered pixels), a thrust a streak; claws and bites keep
  their sheets. Hits pop a sharp star (`ImpactVfx`, bigger on crits). Blasts ripple the picture
  (`ShockwaveVfx`, `shockwave.gdshader`). Monster warnings (`TelegraphView`, `telegraph.gdshader`):
  zone, cone or line with crawling hazard stripes and a solid rim, filling up from the monster as
  the attack comes, flashing just before it lands. Shots leave a glowing streak.
- **Shots and blasts**: magic shots (fireballs, bolts, spells) glow in their color (a pulsing
  halo, `ProjectileHalo`, and a light in the dark), leave a glowing streak and burst on impact
  (`Vfx.pop`); plain things (shurikens, arrows, feathers, coins: `projectile_glow` /
  `ProjectileEffect.glow` 0) just fly. Explosions are a ball of fire drawn by a shader
  (`BlastVfx`, `blast.gdshader`: white-hot heart, flame bands, licking edges, smoke) with a
  ripple, fire and smoke particles and a scorch mark left on the floor.
- **Little details**: fights leave **splats** on the floor (`SplatLayer`, `World.add_splat`): blood,
  green slime, purple ink, bone dust, in each monster's `splat_color` (spirits and flames leave
  none), fading after a while. **Plants sway** in a breeze and **bend** away from whoever walks
  through them (`DecorRuleDef.sway`, `SceneKey.sway`). Shallow water **glints** (`GroundLayerDef.shimmer`).
  Braziers and candles **burn** (`PropDef.flame`). The HP bars keep a pale **trail** of what a hit
  cost, then drain it; they glow when healed. Each biome has its **air**: fireflies in the garden,
  sand gusts in the desert, mist over the flooded caverns, dust in the library and the tomb.
  Gameplay code spawns them in one line through `Vfx` (`Vfx.hit(...)`, `Vfx.explosion(...)`).
- **Statuses on the body** (`StatusFx`, one per actor; looks in `data/vfx/status_looks/`,
  `StatusLookDef`): a **burning** body throws small flames and embers with a warm glow, and catches
  fire in a burst with a crackle; a **poisoned** one bubbles and puffs green smoke; a **slowed** one
  sheds frost, with an ice burst when it takes hold (quicksand slows without frost: the ground is no status). Their ticks show in the status's color (orange,
  green). Drawn by hand over the body, 24 bits at most each, and asleep when nothing is on it.
- **SFX**: the `Sfx` autoload plays world sounds (positional) and UI sounds. Weapons have attack and hit
  sounds, monsters hurt and death sounds, skills and consumables a use sound; everything else comes
  from `data/audio/sound_bank.tres`. Each sound is an `AudioStreamRandomizer` listing its variations.
  Buses: Master > SFX, UI, Music, Ambience (`default_bus_layout.tres`). Each floor theme has its own music.
- **The Threshold** (a second life's trial, see builds.md; `ThresholdDef` > Place and Look,
  `data/threshold/`): on the killing blow the floor freezes, a **knell** tolls (a bell made for the
  game, `assets/audio/sfx/world/knell.ogg`) and the picture drains to cold grey-blue at once; the
  hero's body fades and sinks while a pale soul is dragged down out of it (`Threshold.SinkingSoul`),
  then a night-blue veil falls. Under it the limbo: an oval of pale stone in thick mist (its own
  `DungeonTheme`, light ramp from night blue to pale blue, `LightingDef` ambient 10), ghost wisps,
  drifting fog and low mist, a strong cold grading with little saturation and a slow pulsing
  vignette (`limbo_ambience.tres`), whispers and spirit sighs in a long reverb, the boss music.
  Spectres rise in a puff of mist: the act's monsters blended 60% toward pale blue
  (`ActorRig.pallor`, under the hit flash) and a little see-through. Won, the bell again and a
  pale veil, and the hero is back with the feather's golden burst; lost, the bell and a dark veil.
- **Hit stop**: a few frames of freeze on impacts (`HitStop.freeze(seconds)`).
- **Light**: in steps, tile by tile (see [Lights](#lights)): the hero's torch, room lanterns, braziers,
  campfires, glowing shots and explosions light up each floor's own darkness.
- **Shaders**: everything stays on the art's pixel grid. The rig shader flashes actors when hit and
  dissolves monsters pixel by pixel when they die; light falls off in flat steps, tile by tile
  (`LightField`); a full-screen shader (`ScreenFx` in `game.tscn`) adds a dithered vignette,
  a bit of contrast and saturation, and splits the colors by whole pixels when the hero takes a big hit.
- **Ambience** (`AmbienceDef`, `data/dungeon/ambience/`, set on each floor theme): footsteps that sound
  like the floor (dull in the caves, echoing in the crypt, crunchy in the ruins) and footprints that
  fade, a looping background (wind, storm), random distant sounds around the hero (drops, whispers,
  chains, roars), the SFX bus reverb of the place, floating particles (dust, ghost wisps, embers) and
  drifting pixel fog. Played by `Ambience` (`src/world/ambience.tscn`) on the Ambience bus.
  Big monsters and bosses shake the ground when they walk. Under 30% HP a heartbeat plays and the
  music gets muffled (a low-pass filter on the Music bus). The screen fades to black on the stairs.

## Lights

Light comes in levels, from 0 (pitch dark) to 15 (full light), like in block games: a lantern of
level 13 lights its tile 13, the next tiles 12, then 11... (`LightField`, `src/world/lighting/`).
It spreads around corners but walls stop it; cliff faces catch it, and the mist on the plateau
above glows near the lamps, fading twice as fast (see Mist over the walls). Each level is one flat band of color, and the color changes as the light fades
(warm by the flame, dusky further out, cold in the dark).

- **Lights** are `LightSource` nodes (`color`, `level`): lanterns and furniture (`PropDef.light_level`),
  campfires and oases (`HeatSourceDef.light_level`), the hero's torch (level 12), glowing shots and
  flashes (`relative`: counted above the floor's own light, so they show even in daylight).
- **Each theme** has its `LightingDef` (`data/dungeon/lighting/`): `ambient_level` (the light away
  from any lamp: 5 in the crypt, 9 in the desert) and `ramp`, the color of each level. Difficulty,
  curses and events (darkness, the Blood Moon) lower the floor's light and tint it, less and less
  near the lamps.
- **How**: lights that stay put are spread once per floor on the CPU, half a tile per cell, all at
  once, brightest first. Moving ones (up to 24 near the hero) are added every frame by a shader
  (`light_cells.gdshader`, walls checked along the way) into a small viewport, one pixel per cell,
  stretched over the floor and multiplied with it: no light ever gets brighter than the art, so
  bright floors (the desert) never burn white. Sparks, slashes, floating text and the ambient
  particles are drawn above it (z 4 and up) and shine on their own.

## Animations

Animations are **frame by frame**, like in Zelda-style RPGs: every character has a drawing for each
direction (down, up, left, right) and each pose, and the weapon is drawn *in the hand* for each
attack frame. Nothing is rotated or moved by code, so the weapon never floats or goes through the body.

Every actor (player and monsters) has a **rig**: `src/entities/rig/actor_rig.tscn`.

```
Rig                  at the actor's feet
└── Visual           flash shader, scaled 2x (units = art pixels)
    └── Squash       squash & stretch on hits
        ├── Body       AnimatedSprite2D: the character (SpriteFrames from the data)
        ├── BodyArmor  AnimatedSprite2D: worn body armor, same animation and frame as Body
        ├── Helmet     AnimatedSprite2D: worn helmet, same animation and frame as Body
        └── Weapon     AnimatedSprite2D: the weapon in hand, same animation and frame as Body
```

The animations live in `SpriteFrames` resources in `data/visuals/`, named `<pose>_<direction>`:

| Animation | When |
|---|---|
| `idle_*`, `walk_*` | standing, moving |
| `attack_*` | attacking (sped up to fit the weapon's attack speed) |
| `dash_*` | rolling |
| `hit_*` | taking a hit |
| `dead` | dying |
| `cast`, `intro` | bosses: telegraphed skill, waking up |

A missing animation falls back to a simpler one (`attack_left` > `attack`), and creatures with no
attack pose lunge instead. Monsters freeze in their attack pose and shake during their wind-up,
so you can see the strike coming.

**Weapons**: each `WeaponDef` has `attack_frames` (a SpriteFrames with `attack_down/up/left/right`).
The sheets in `assets/weapons/attack/` are 64x64 cells, one column per direction, one row per frame,
drawn so the handle sits in the hero's hand on that frame. The weapon is drawn behind the body when
facing up. `attack_fx` is the slash effect played in front of the actor.

**Armor (paper doll)**: what you wear shows on the hero. Each `ArmorDef` has `wear_frames`, a layer
with the same animations as the hero, and a `wear_color`. The layers copy the body's animation and
frame every frame, so they can't drift. The layer sheets (`assets/characters/hero/wear/`) are grayscale
and were made from the hero's own frames (hood and outfit pixels), so one style serves many armors:

| Style (`data/visuals/wear/`) | Slot | Used by |
|---|---|---|
| hood | head | Leather Cap |
| helm | head | Iron Helm |
| tunic | body | Leather Armor, Shadow Cloak |
| mail | body | Chain Mail |
| plate | body | Plate Armor |

A new armor = pick a style and a color in the inspector.

To tweak an animation, open a file in `data/visuals/` and use the SpriteFrames panel
(add frames, change the speed, toggle loop). The actor scripts never touch animations directly:
they call `rig.play_attack()`, `rig.play_hurt()`, etc.

## Pixel art

The art is 16x16 pixel art drawn at 2x in the world, with nearest filtering (Project Settings >
Rendering > Textures > Default Texture Filter). Effects and shaders stay on the art's pixel grid.
