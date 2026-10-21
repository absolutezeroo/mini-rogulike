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
- **VFX** (the style guide, its rules and every element's kit: [docs/vfx.md](../vfx.md)): every
  effect speaks its **element** (`VfxElementDef`, `data/vfx/elements/`: a ramp of 3-5 colors, a
  particle shape, a direction of motion, a kit of sheets), on the art's 2-unit pixel grid, never
  stretched or freely turned, fading by dithering. Frost is faceted ice shards drawn in 16
  directions, cracking impacts, novas of crystals growing then shattering, rime on chilled
  bodies; fire licks up, poison bubbles and sinks. Storm is violet-white lightning: ball-lightning
  sparks, crackles on the ground, Thunder's bolt from the sky, chain lightning forking from body
  to body, all flickering (strike, off, strike again). Holy is light from above: Smite's column,
  rings of thin shafts, Holy Shield's ring rising into a halo, and the holy sigil drawn by every
  heal, buff, learned skill and level up (in the heal's own color when it isn't holy). Shadow
  shots (Sorcerer, Octopus ink, Shaman hex) are dark knots with a burning rim that collapse
  inward; Shadow Step bursts into shadow and leaves smoke. Arcane is a diamond glint with motes
  orbiting it. Hand-drawn sprite-sheet effects
  (slashes, claws, explosions, smoke, "!" emote when a monster spots you) plus
  pixel particles for hits, dust and sparkles
  (`src/vfx/particles/*.tscn`, edit them in the inspector; `pixel_particles.gdshader` keeps them
  whole art pixels on the grid, their fades dithered), dash afterimages (dithered, in the dash's
  element; plain rushes like a beast's Charge also kick up dust), animated projectiles,
  squash on hit, popping damage numbers, red vignette when hurt or low on HP.
- **Atmosphere** (`AmbienceDef` > Atmosphere, one per biome and curse): the whole picture takes
  the biome's colors (`screen.gdshader`: shadows and highlights graded toward two tints,
  saturation, contrast), bright things **bloom** (a flat rim of light one art pixel wide around
  them, never a blur), the air **trembles** with heat in the ruins and the desert (rows of pixels
  sliding by whole pixels). Glowing effects (fire, frost, holy, storm, arcane, poison, spirit)
  keep most of their own colors under the biome's grading (the emissive mask), so frost stays
  cyan in the warm ruins. Over the floor, in
  world space (`AtmosphereLayer`, `atmosphere.gdshader`, dithered on the art's grid): **shafts of
  light** falling from cracks above (garden, temple, library, cave, desert), **leaf shadows**
  drifting in the garden, **mist** creeping over the crypt and the flooded caverns, **water light**
  dancing on the floor of the flooded caverns.
- **Attack effects** (shaders, all on the art's pixel grid, quantized in world space so a
  diagonal blow has the same pixels as a straight one): a melee swing draws a crescent at the
  weapon's reach and arc (`SwingVfx`, `swing.gdshader`) in steel (the `physical` ramp: a
  near-white cutting edge, greys behind, thinning out in dithered pixels) or in the weapon's
  element; a monster's carries a red warning rim. A thrust draws a streak. Slash skills and heavy
  monster blows are `SlashDef`s (`data/vfx/slashes/`): Cleave's double crescent, Whirlwind's and
  Lash's spins, Flurry's stabs ending on a cross, Iaido Dash's razor line, Piercing Thrust's
  lunge, the cyclops' clubs and the tengu's blade. Claws and bites keep their sheets (a weapon
  shows its arc or its sheet, never both: `WeaponDef.shows_arc()`). Hits flash for two frames
  and throw the blow's element's bits away from it (`ImpactVfx`: ice chips falling, embers
  rising; a plain blow throws short streaks), plus the bits of what the monster is made of
  (blood drops, bone chips, slime, sparks off armor, spirit motes, leaf chips); a crit also cuts
  a cross over the target. Blasts ripple the picture (`ShockwaveVfx`, a stamp of the screen pass).
  Monster warnings (`TelegraphView`, `telegraph.gdshader`): zone, cone, line or the lanes of a
  fan or ring of shots (so the gaps read), with crawling hazard stripes and a solid rim, filling
  up from the monster as the attack comes, flashing just before it lands; every monster shot
  and dash now warns (lanes, line). Shots leave a glowing streak.
- **Light, space and screen** (docs/vfx.md, "Shaders"): glowing cores have a stepped **halo**
  (two flat bands of added light in their element's darker steps, sparser on bright floors):
  fire's heart in braziers and campfires, magic shots, Smite's column foot, Thunder's strike, a
  glint on some Frost Nova crystals. Space bends in one screen pass: **heat** trembles above
  fires and rings of flame, a **cold shimmer** catches facets of the picture through a Frost Nova,
  shadow and arcane shots **pull** rings of the picture toward them, blasts send a **shockwave**.
  Braziers' and campfires' flames have **tongues** climbing through them, poison clouds **churn**
  with a glowing rim and holes the floor shows through (gas, not bushes), Smite's column
  **shimmers**, Thunder **flashes** the whole screen for one frame (at most 3 a second; Options >
  Screen flashes turns it off). The holy sigil, arcane glyphs and the pact's circle **draw
  themselves** stroke by stroke and burn out. Fewer effects drops the halos' outer band, the
  heat, cold and pull (shockwaves stay) and the bloom.
- **Layers** (docs/vfx.md, 2b): flat effects (sigils, rings, telegraphs, crackles, mist at the
  feet, elite auras) lie under every body; upright ones (ice crystals, rays and columns of
  light, bolts, smoke, dust) sort with the bodies by their base, so the hero stands among a
  Frost Nova's crystals and a crystal hides a monster behind it; shots, hits, blades and bursts
  are over everyone.
- **Shots and blasts**: magic shots (fireballs, bolts, spells) are their element's shot (the
  frost shard, drawn in 16 directions; round orbs are never turned), light the dark in its
  color, leave a trail of its bits and land in its language (`Vfx.pop`: the element's impact
  sheet, or a burst in its ramp); a shot at the end of its range breaks up instead of vanishing.
  Plain things (shurikens, arrows, feathers, coins: `projectile_glow` / `ProjectileEffect.glow`
  0) just fly: arrows, kunai, the thrown spear and the Crimson Tengu's crimson feathers are drawn
  in 16 directions (`data/vfx/sheets/`), shurikens and coins spin as they are. Explosions are their element's blast sheet at 2x (fire: a white-hot ball whose
  tongues lick out and up into dark smoke and embers; earth: the ground cracking open, chunks
  thrown up, a dust cloud rolling low, cracks that stay a moment), ringed by its pieces when
  wider than the sheet (flame licks, rock spikes), or a burst drawn by a shader in its ramp
  (`BlastVfx`) for the elements without one; a ripple and a mark on the floor (a scorch for
  fire). A boss's stomp is the ground bursting, whatever the boss is made of, and a trapped
  chest bursts apart in grit and dust (crates and barrels break the same way); powder kegs and
  bombs are fire.
- **Little details**: fights leave **splats** on the floor (`SplatLayer`, `World.add_splat`): blood,
  green slime, purple ink, bone dust, in each monster's `splat_color` (blood is the blood
  element's dark red; spirits and flames leave none), fading after a while. A glob of venom leaves
  a small puddle where it bursts, a wound a stain (`VfxElementDef.impact_mark`). What drinks blood
  shows it: a vampiric elite's hits, the Leech Rune, Vampirism and the Vampiric affix, Bloodlust's
  kills draw a few drops out of the victim into the drinker (`BloodDrainVfx`); Executioner's
  finishing blows and Bloodrage's wounded blows land in blood. **Plants sway** in a breeze and **bend** away from whoever walks
  through them (`DecorRuleDef.sway`, `SceneKey.sway`). Shallow water **glints** (`GroundLayerDef.shimmer`).
  Braziers and candles **burn** (`PropDef.flame`; a brazier with the fire kit's flames, like
  campfires and flame vents). The HP bars keep a pale **trail** of what a hit
  cost, then drain it; they glow when healed. Each biome has its **air**: fireflies in the garden,
  sand gusts in the desert, mist over the flooded caverns, dust in the library and the tomb.
  Gameplay code spawns them in one line through `Vfx` (`Vfx.hit(...)`, `Vfx.explosion(...)`).
- **Statuses on the body** (`StatusFx`, one per actor; looks in `data/vfx/status_looks/`,
  `StatusLookDef`, each in its element's ramp, on the body's pixel grid): a **burning** body
  throws small flames and embers and catches fire in a burst with a crackle; a **poisoned** one
  splashes as the venom takes, then bubbles (bubbles that swell and pop) and leaks a murky haze
  that sinks at its feet; a **wailed** one (a spirit's slow) flickers with small pale flames; a **chilled** one grows rime on its edges
  (it breaks into falling chips when the chill ends), sheds ice chips and breathes cold mist at
  its feet, with a burst of shards when it takes hold. Only frost and the cold show as frost:
  sand, ink, spores and quicksand slow without it, a wail with its own pale flicker (`OnHitStatus.slow_element`). The body
  itself is painted by the rig's shader in the status's element (`BodyLook`, docs/vfx.md
  section 9): heat crawling up the lower rim of a burning body, rime creeping in from the edges
  of a chilled one as the chill lasts (a hard chill freezes it over, a glint sweeping across), a
  green wave rising up a poisoned one on each tick, a pale flicker and a see-through rim on a
  wailed one; a storm hit crackles over the body for a frame or two. The particles are the
  accent. With **Fewer effects** the shader leaves the statuses alone and the body takes a steady
  45% tint of the status's color instead. Their ticks show in the status's color. Drawn by hand
  over the body, 24 bits at most each, and asleep when nothing is on it.
- **Deaths by element** (`DeathLookDef`, `data/vfx/deaths/`, one per element): a monster goes the
  way the blow that killed it was made (a burn's last tick counts): fire burns it to ash from the
  feet up, frost freezes it then shatters it into pieces of its own art, poison and water melt
  it into a puddle, storm and arcane flash it and scatter it in sparks, holy lifts it away as
  light, shadow sucks it into a dark point, spirit thins it into rising wisps, earth crumbles
  it; a plain blow or blood dissolves it pixel by pixel with its chunks, as before.
- **Elites** wear a rim of their rank's color around the body (one art pixel, a second dithered
  on the beat), on top of their aura at the feet.
- **SFX**: the `Sfx` autoload plays every sound. Weapons have attack and hit sounds, monsters hurt
  and death sounds, skills and consumables a use sound; everything else comes from
  `data/audio/sound_bank.tres`. Each sound is an `AudioStreamRandomizer` listing its variations.
  Each floor theme has its own music.
  - **Buses** (`default_bus_layout.tres`), one per slider in Options:

    | Slider | Bus | What plays there | Call |
    |---|---|---|---|
    | General | Master | everything (a limiter at -1 dB on it) | |
    | Music | Music | the floor's or the boss's music | `Sfx.play_music` |
    | Interface | UI | menus, buttons, jingles (level up, stairs, a boss slain, game over, the knell, a curse's card) | `Sfx.play_ui` |
    | Combat | Combat | the fight: weapons, hits and what monsters are made of, cries, skills, spells, potions and bombs, shots, explosions, statuses, traps going off, deaths | `Sfx.play_at` |
    | Ambience | World + Ambience | the place: footsteps, distant sounds, doors and gates, chests opening, gold and pickups, crates breaking, crumbling floors, quicksand, fires, the forge, falls; the background loop and the heartbeat (Ambience) | `Sfx.play_world` |

    Combat and World send to the SFX bus, which holds the room's reverb (set per floor by the
    ambience), then to Master. A trap is a fight sound (it hurts you), a chest or a door is the
    place's. A unit check (`tests/suites/sound_tests.gd`) holds every scene's player and every bank
    sound to its bus.
  - **The mix** (`SoundMixDef`, `data/audio/sound_mix.tres`): busy fights used to clip (two dozen
    hot sounds at once, the Master peaking near +10 dB) and some sounds were shrill. Now: each bus
    sits a little under its slider (Combat -3 dB, Interface -2, World -1, Music -4: the fights lost about 10 dB of loudness when they stopped clipping, so the music comes down with them), a hard limiter on Master
    (ceiling -1 dB), a soft compressor on Combat, a high-shelf cut over 6.5 kHz on Combat (-6 dB)
    and Interface (-3 dB); random pitch goes up 6% at most (pitched up, sounds turn shrill);
    16 combat voices, 8 world, 6 interface; the same sound at most 3 at once and twice within
    40 ms, the repeat 5 dB quieter (a swing through a pack: a couple of hits, not ten); past 6
    combat voices each new one a bit quieter (down to -6 dB); when the pool is full a nearer sound
    replaces the farthest. Fight sounds fade with distance faster than the place's. `trims` lowers
    sounds that came in too loud or too bright (hits, the player's hurt, roars, slashes, spikes,
    arrows, gates, the forge, the knell...); what monsters are made of sits 7 to 10 dB under the
    cry (`ImpactMaterialDef.volume_db`), and the deepest reverbs are drier (wet 0.2, the limbo 0.3).
- **The Threshold** (a second life's trial, see builds.md; `ThresholdDef` > Place and Look,
  `data/threshold/`): on the killing blow the floor freezes, a **knell** tolls (a bell made for the
  game, `assets/audio/sfx/world/knell.ogg`) and the picture drains to cold grey-blue at once; the
  hero's body fades and sinks while a pale soul, a wisp in the spirit's ramp, is dragged down out
  of it (`Threshold.SinkingSoul`),
  then a night-blue veil falls. Under it the limbo: an oval of pale stone in thick mist (its own
  `DungeonTheme`, light ramp from night blue to pale blue, `LightingDef` ambient 10), ghost wisps,
  drifting fog and low mist, a strong cold grading with little saturation and a slow pulsing
  vignette (`limbo_ambience.tres`), whispers and spirit sighs in a long reverb, the boss music.
  Spectres rise out of a hollow ring of pale flames (the spirit element): the act's monsters blended 60% toward pale blue
  (`ActorRig.pallor`, under the hit flash) and a little see-through. Won, the bell again and a
  pale veil, and the hero is back with the feather's golden burst; lost, the bell and a dark veil.
- **Hit stop**: a few frames of freeze on impacts (`HitStop.freeze(seconds)`).
- **Light**: in steps, tile by tile (see [Lights](#lights)): the hero's torch, room lanterns, braziers,
  campfires, glowing shots and explosions light up each floor's own darkness.
- **Shaders**: everything stays on the art's pixel grid. The rig shader flashes actors when hit,
  paints their statuses and an elite's rim, and takes monsters away in the element that killed
  them (computed in the sprite's own texels); light falls off in flat steps, tile by tile
  (`LightField`); a full-screen shader (`ScreenFx` in `game.tscn`) adds a dithered vignette,
  a bit of contrast and saturation, and splits the colors by whole pixels when the hero takes a big hit.
- **Ambience** (`AmbienceDef`, `data/dungeon/ambience/`, set on each floor theme): footsteps that sound
  like the floor (dull in the caves, echoing in the crypt, crunchy in the ruins) and footprints that
  fade, a looping background (wind, storm), random distant sounds around the hero (drops, whispers,
  chains, roars), the SFX bus reverb of the place, floating particles (dust, ghost wisps, embers) and
  drifting pixel fog. Played by `Ambience` (`src/world/ambience.tscn`): the loop on the Ambience bus,
  footsteps and distant sounds on the World bus (both under the Ambience slider).
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
  particles are drawn above it (z 4 and up) and shine on their own; effects on the floor or
  standing on it are under it and a glowing one brings its own light (`VfxLayer.light_up`; a
  monster's warning a red one).

## Animations

Animations are **frame by frame**, like in Zelda-style RPGs: every character has a drawing for each
direction (down, up, left, right) and each pose, and the weapon is drawn *in the hand* for each
attack frame. Nothing is rotated or moved by code, so the weapon never floats or goes through the body.

Every actor (player and monsters) has a **rig**: `src/entities/rig/actor_rig.tscn`.

```
Rig                  at the actor's feet
└── Visual           body shader (flash.gdshader: flash, statuses, rim, deaths), scaled 2x (units = art pixels)
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
Rendering > Textures > Default Texture Filter). Effects and shaders stay on the art's pixel grid:
the rules (whole-pixel sizes, 16 directions at most, dithering instead of alpha, one ramp per
element) are in [docs/vfx.md](../vfx.md), the tools in `tools/vfx/`.
