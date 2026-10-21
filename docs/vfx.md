# Visual effects: the style guide

How every effect in the Well is drawn, so that frost reads as frost wherever it comes from and a
spark never looks pasted onto the art. Read this before making or fixing an effect; the
`vfx` skill (`.claude/skills/vfx/`) walks through the work step by step.

The games this guide learns from (Dead Cells, Blasphemous, Hyper Light Drifter, Enter the
Gungeon) published no VFX bible. Their coherence comes from one constraint held without
exception: **every effect is born at the game's resolution and never rescaled**. Ours is: one
art pixel is 2 world units, and every effect lives on that grid, in its element's ramp, with
its element's shapes.

## 1. The pixel grid

The art is 16x16 pixel art drawn at 2x (`ActorRig`'s Visual node, scale 2): **1 art pixel =
2 world units** (3 screen pixels at the camera's 1.5 zoom). An effect whose pixels are smaller
(a "mixel"), stretched by 6.9x, or turned 37 degrees is a different game pasted over ours.

- **Positions and sizes snap to 2 units.** `PixelDraw.snap(v)`, `PixelDraw.snap_length(r)`.
- **Sheets are drawn at whole, even sizes**: `texel` 2 for a sheet authored at one art pixel per
  texel (all of ours). Never 0.4x, 0.95x, 2.5x, 6.875x. `SheetVfx` snaps any wanted size to the
  nearest even one (`PixelDraw.sheet_scale`); that is a safety net, not a design: 4x and 6x
  are chunky. A big effect is **composed** of many pieces at 2x (`ComposedVfx`, a nova of 30
  crystals) or **authored bigger**, never stretched.
- **No free rotation of pixel art.** A round thing (an orb, a spinning star, a ring) is drawn
  as it is. A long thing that points somewhere (a shard, an arrow) is **drawn in 16 directions**
  (`VfxSheetDef.Orient.ROWS`: the frost shard), or at worst turned to the nearest of 16 angles
  (`SNAPPED`: old arrows and slashes). Never `rotation = direction.angle()`.
- **No smooth shapes, no alpha gradients.** No `draw_circle`, `draw_arc`, alpha fades or
  `color.lerp` in an effect. Use stepped rings and discs of whole pixels
  (`PixelDraw.ring/disc/line/bit`) and fade by **ordered dithering** (a 4x4 Bayer matrix: each
  pixel fully there or gone): `PixelDraw.dither()` for `_draw()` code, the `dither_fade` shader
  for sprites. Alpha in a sheet is 1-bit (0 or 255).
- **Additive light only for emissive cores**, from the ramp's darker steps (it brightens without
  burning to white): projectile halos of plain dots, the level up's light. Sparks, dust, blood,
  smoke: opaque ramp colors, normal blending.

## 2. Readability (a phone screen in a busy fight)

Visual weight follows gameplay weight. From most to least contrast:

1. **The hero**: outlined, always the most readable thing.
2. **Enemy threats**: telegraphs and enemy shots. Warm "danger" rims (`TelegraphView`, the red
   warning ring of a death burst), solid edges a little larger than the hitbox. An enemy shot
   must not look like the hero's: same element, but the enemy's carries the danger language
   (warning, bigger silhouette); the hero's own effects are briefer and sparser.
3. **The hero's damage effects**: novas, shards, slashes. Short, they never hide a monster or
   a telegraph for long (Frost Nova's inner ring is sparse on purpose).
4. **Ambient**: dust, mist, wisps: the least saturated.

Shape doubles color, always: about 8% of men see red and green alike. Each element has its own
silhouette and particle shape (section 4), so a colorblind player still tells frost from storm.
No more than 3 flashes a second; one screen shake source, capped.

## 3. Timing

- **The main action happens in the first quarter** of an effect's life, then it erodes. A nova
  reaches its edge in 0.12 s and lives 0.6 s.
- **An impact flash: 2-3 frames at full strength, no fade-in** (a hit has no anticipation),
  then down the ramp. `ImpactVfx.FLASH_TIME` = 2 frames.
- **Dissipation, never vanishing**: a sheet's last frame lingers and dithers away
  (`VfxSheetDef.linger`), particles go down their ramp then dither out, a shot at the end of its
  range breaks into a few bits. Nothing disappears on its last frame.
- **Telegraphs last at least 0.25 s plus the time to react** (about 15 frames + the dodge's
  start-up); they grow brighter and more solid as the hit comes, their edge is crisp.
- **A status shows exactly while it lasts**: rime grows when the chill lands and breaks into
  chips when it ends.
- Sheets play at 12-20 fps without interpolation (the hand-animated look); small motes may move
  every frame, on the grid.

## 4. Palette and elements

Each element owns **one ramp of 3-5 colors**, from a bright core to a dark edge, defined once in
`data/vfx/elements/<id>.tres` (`VfxElementDef.ramp`), plus a `residue` (what it leaves in the
air) and a `mark` (what it leaves on the floor). Everything the element draws takes these colors
only: shaders get them as uniforms (`blast.gdshader`), sprites are authored on them or painted in
them (`VfxRamp`), `_draw()` code picks steps with `element.shade(t)` (never a blend).

- **Bright core, dark edge.** The core is the rare near-white pixel of the screen; the dark edge
  outlines the effect on bright floors (the desert). **No pure white or black**, except a
  one-frame flash core. **Shadow is the one inverted**: a dark core and a bright edge, so the
  void has an identity in a world already violet and black.
- **One dominant hue per effect**, at most one secondary (a hit's sparks in what the monster is
  made of, the flash in the blow's element).
- `accent` names the ramp step used as the element's main color (lights, body tint, damage
  numbers). `Palette.FROST` and `Palette.FIRE` equal frost's and fire's accents (a test keeps
  them so).
- **Shadow and arcane are two elements.** The game has both a sorcerer's shadow (ink, the
  shadow staff, Shadow Step) and arcane magic (Arcane Bolt, the arcane synergy); arcane is a
  bright magenta magic with runes and orbits, shadow a dark smoke pulled inward.

### Element identity

| Element | Ramp (core → edge) | Shape language | Bit | Motion | Residue / mark |
|---|---|---|---|---|---|
| fire | `fff6d8 ffe18d ffad5d e46d3a 8f3e56` | licking teardrops, white-hot base, embers rising and dying | TEARDROP | RISE | smoke `3b3643` / scorch |
| frost | `ebf8ff 8feff1 79b8ce 4a72a8 2c3560` | angular faceted shards irregular in size and angle, crystals that grow and shatter, cold mist sinking. **Never a radial symmetric star** (that is a shuriken) | DIAMOND (angular chip) | FALL | mist `c8e4f0` / rime |
| water | `e3f1f5 71ddee 3da6bd 2d697b 1b3a46` | drops, splashes, ripples on the ground | DROP | FALL | spray / puddle |
| poison | `e6f7a0 9bd64a 5f9e3a 3c6644 2e2440` | bubbles that swell and pop, drips, clouds that sink and crawl | RING | SINK | murky gas `5f7160` / puddle |
| storm | `f4f0ff c9b8ff 8f73e6 4b3a99 251c4f` | jagged forks, crosses, flicker (1-3 frames on, then afterglow) | CROSS | OUTWARD | none / scorch |
| holy | `fffbe8 ffe18d f1c471 bd7959 61372e` | rays, rings, columns from above, slow motes of light | MOTE | FALL | none |
| shadow | `150d1f 3b2346 7a3a7e d24a86` | swirls, smoke, a ring that collapses, dithered edges, pulled inward | MOTE | CONVERGE | smoke `2a1f33` / stain |
| arcane | `ffe6fa f07ad8 b048c0 6a2a8a 2e1446` | runes, orbits, 4-point glints, spirals | GLINT | ORBIT | none |
| blood | `ff9b8f e0394c a3162c 5a0a1e` | drops, spurts, ballistic arcs, stains that stay | DROP | FALL | none / stain |
| spirit | `f0fff8 b8f5dc 6fd6b4 3b8f86 234b52` | wisps, hollow rings, pale flames curling up, flicker | MOTE | RISE | ectoplasm |
| earth | `f5e6c4 d2b37d a3754e 6b5040 3b3238` | rock spikes, chunks flung on arcs, dust clouds, cracks | SQUARE | FALL | dust `c8b08a` / cracks |
| physical | `f2eaf1 c7c7c7 8c8c8c 4e484a` | steel: crescent arcs, short streaks along the blow, sparks | SQUARE | OUTWARD | none |

Mood (docs/lexicon.md): the Well is dark, so only emissive cores get the screen's rare bright,
saturated pixels; smoke, blood and ash stay in the muted ramps of the floors.

### Element kits

The kit's slots (`VfxElementDef`): `projectile` (its shot), `impact` (a shot landing), `piece`
(one piece of its novas, waves and trails, composed by `ComposedVfx`), `claw` (a creature's
blow), `blast` (its explosion, at 2x; a wider blast adds a ring of its pieces), `slow_look`
(the look of a body it slows, a `StatusLookDef`), `impact_sound`. Missing
slots fall back to code that still speaks the element (a burst in its ramp, a ring with its
bits on the rim).

| Element | Projectile | Impact | On the body | Nova / area | Telegraph | Sound family |
|---|---|---|---|---|---|---|
| fire (**done**) | `fire_bolt.png`: a white-hot ball, three tongues licking back and up, 16 directions; `fire_ray.png` for the eye beam | `fire_impact.png`: tongues out and up, flames breaking off, embers, dark smoke; `fire_blast.png` for explosions | `fire_flicker.png` flames rising, embers, warm tint, a burst when it catches | `fire_lick.png`: licks rising, curling, sinking to smoke, in rings, arcs (Flame Arc) and at a blast's edge | warm rim, embers creeping in | crackle (`flames`) |
| frost (**done**) | `frost_shard.png`: a faceted shard drawn in 16 directions, chips trailing | `frost_impact.png`: shards cracking outward, biggest early, chips falling, mist | rime growing on the edges (`frost_rime.png`), ice chips falling, cold mist at the feet, 45% cold tint | `frost_crystal.png`: crystals growing from the ground in a ring, then shattering | the shared danger rim; frost chips inside | cracking ice, glassy chime |
| water | a drop (energy orb painted water) | splash, droplets, a ripple | drips (none yet) | ripples (`water_ripples.png`) | danger rim | splash |
| poison | a venom drop (orb painted poison) | bubbles bursting, a sinking cloud | bubbles, a haze sinking at the feet, green tint | a cloud crawling out | danger rim, bubbles inside | squelch, hiss |
| storm | a crackling spark, flickering | a jagged fork, crosses | small arcs jumping off the body | forks around a ring | crisp flicker | crack, zap |
| holy | a mote of light with rays | rays, a ring of light | short ray halo (never permanent) | a column, a ring of rays | rays converging | chime, bell |
| shadow | a dark knot with a bright rim, smoke behind | a ring collapsing inward | darkened silhouette, filaments sucked in | a dark ring imploding | the ground dims | whisper, low thrum |
| arcane | a glinting orb, runes orbiting | a ring of runes | glyphs orbiting | a rune circle | runes lighting up | chime, hum |
| blood | none (claws, spurts) | spurt, drops that stay | short spurts on each tick | spray in a fan | danger rim | wet impact |
| spirit | a pale wisp curling | a hollow ring, wisps rising | pale flicker | a ring of wisps | pale rim | sigh, chime |
| earth (**done**) | `earth_clod.png`: a lumpy clod tumbling (round: redrawn, never turned); `earth_swirl.png` for Sandstorm | `earth_impact.png`: chunks on arcs, dust rolling low; `earth_burst.png` for blasts: cracks, slabs and chunks thrown up, a wide dust cloud, cracks that stay a moment | none (sand slows without a look) | `earth_spike.png`: rock spikes thrusting up, cracking, crumbling into rubble | cracks spreading | crumble (`crumble`) |
| physical | arrows, kunai, shurikens (drawn, not glowing) | short streaks along the blow, sparks in the target's material | none | crescent arcs (`SwingVfx`) | lines and arcs | swish, clang |

## 5. The code

| What | Where | Use |
|---|---|---|
| `VfxElementDef` | `src/definitions/vfx/vfx_element_def.gd`, `data/vfx/elements/*.tres` | ramp, residue, mark, bit, motion, emissive, kit sheets. `VfxElementDef.named(&"frost")`, `.core() .color() .edge() .shade(t)`, `or_color(element, color)` for old content |
| `VfxSheetDef` | `src/definitions/vfx/vfx_sheet_def.gd` (sub-resources of an element) | texture, frames (0 = square), orient (NONE / ROWS / SNAPPED), directions, variants, fps, loop, texel, recolor, anchor, linger. `VfxSheetDef.from_texture(tex, frames)`, `columns/cell_size/slices_evenly` (the one frame slicer) |
| `element` exports | `WeaponDef`, `ProjectileEffect`, `DamageAreaEffect`, `DashStrikeEffect`, `OnHitStatus.slow_element`, passives (`element`, `shard_element`, `crit_element`, `blast_element`), `DeathBurstTrait` | gameplay data points to an element instead of free colors; `HitInfo.element` carries it to the hit's flash |
| `PixelDraw` | `src/vfx/pixel_draw.gd` | `snap`, `snap_length`, `sheet_scale`, `dither`, `pixel`, `ring`, `disc`, `line`, `bit` (an element's particle shape), `sheet` (draw a frame of a VfxSheetDef on the grid) |
| `VfxRamp` | `src/vfx/vfx_ramp.gd` | `recolor(texture, ramp)`: palette swap by luminance, cached (a sheet with `recolor` on is painted in its element's ramp) |
| `Vfx` | `src/vfx/vfx.gd` | `hit(..., element)`, `pop(world, at, element, radius, direction)`, `nova(world, at, radius, element)`, `arc(world, at, radius, facing, element)`, `trail(world, from, to, element)`, `explosion(world, at, radius, element, pieces)` |
| `SheetVfx` | `src/vfx/sheet_vfx.gd` | `play(sheet, at, direction, element)`, `create(texture, ...)` (legacy: snapped), `.in_element(e)`, lingering dither |
| `ComposedVfx` | `src/vfx/composed_vfx.gd` | `ring(at, radius, element)`, `arc(at, radius, facing, element)` (a sweep across the front: an area with `fx_follow_aim` and no sheet), `line(from, to, element)`: any size from pieces at 2x |
| `ImpactVfx`, `RingVfx`, `BlastVfx` | `src/vfx/` | a hit's flash, a ring, a burst: all in an element's ramp and bits |
| `StatusLookDef`, `StatusFx` | `data/vfx/status_looks/`, `src/vfx/status_fx.gd` | particle, motes (EMBER, BUBBLE, CHIP), crust (rime), mist, burst, all at texel 2 in the element's ramp |
| Tools | `tools/vfx/` | `vfxkit.py` (palette-locked drawing), `recolor.py` (palette swap to a file), `check.py` (palette, hard alpha, whole cells), `frost.py`, `fire.py`, `earth.py` (the kits, rebuildable) |

Which slow shows what: a slow carries an element (`StatusSet.apply_slow(..., element)`, frost
when none is given, none for the ground's own). Only an element with a `slow_look` shows on the
body: frost (and the cold of a frostbound floor) grows rime; sand, ink, spores and wails slow
without looking like ice.

## 6. Adding or fixing an effect

1. **Pick the element** (section 4). Not sure? It is what the player would name it. A new
   element is a new file in `data/vfx/elements/` listed in `data/vfx/elements.tres`.
2. **Point the data at it**: `element` on the weapon, effect or passive; `slow_element` on a
   slowing `OnHitStatus`. Drop free colors and borrowed sprites (no shuriken for frost).
3. **Reuse the kit**: a shot without a texture is the element's projectile; an area without a
   sheet is its nova; a dash leaves its pieces. Only add a texture when the shot is a *thing*
   (an arrow, a coin).
4. **New art**: draw it on the ramp at 1 art pixel per texel with `tools/vfx/vfxkit.py` (or by
   hand, then `tools/vfx/recolor.py` and touch up), hard alpha, frames in a row, directions or
   variants in rows. Big effects: a piece to compose, not a big sheet to stretch.
   `python3 tools/vfx/check.py <png> <element> --cell WxH`. Commit the `.png.import` Godot makes.
5. **Wire it** as a `VfxSheetDef` sub-resource of the element (frames, orient, fps, anchor,
   linger) or of the content; set frames explicitly for any non-square sheet.
6. **Test**: `tests/suites/vfx_tests.gd` (run by the unit suite) checks every element, every
   sheet's slicing and scale, and the frost kit; add the checks your element needs (its users
   point at it, none borrows another element's art).
7. **Look at it** (section 7) and fix until it passes the review.
8. **Docs**: the element's row here, and docs/design/presentation.md if the player sees it
   differently.

## 7. Review checklist

Screenshot it in the game at 1540x720 (the debug panel, or a probe scene in `_tool/` like the
`vfx` skill's), and a 4x nearest-neighbour crop. Then, for each frame:

- [ ] Its pixels are the size of the characters' pixels (no mixels, no 1-unit lines).
- [ ] Only its ramp's colors (+ residue): `check.py` on its sheets; no alpha gradient on screen.
- [ ] Its silhouette reads in one frame, and **reads as its element without color** (squint, or
      look at it in grey: is frost still faceted, storm still forked?).
- [ ] Nothing rotated off the 16 directions; round things not rotated at all.
- [ ] The main action is in the first quarter; the flash lasts 2-3 frames; it dissipates
      instead of vanishing.
- [ ] Its size and noise match its gameplay weight; it never hides a telegraph or an enemy shot.
- [ ] It reads on the darkest biome (the crypt) and the brightest (the desert).
- [ ] An enemy's version is told apart from the hero's at a glance.
- [ ] One dominant hue.

## 8. Where each element stands

Frost is the reference kit, done in full. The foundation (grid helpers, ramps, palette swap,
slicer, element exports) serves the others; what each still needs:

- **Fire** (done, `tools/vfx/fire.py`): every fire shot, Flame Arc (licks sweeping across the
  front), Fire Touch's burning claw, the eye beam's rays, Blazing Roll, the Inferno family, the
  burn look, the campfire, flame vents and braziers (`FlameVfx`). Ghost Flame stays fire (the
  Ghost Lantern, the Ember Heart); the moths, the Moss Heart and the Sand Drummer shoot their own
  element (spirit, holy, poison, earth: those kits may still lack a projectile). Left: candles
  still burn with particles; `fireball.png`, `fire_flames.png`, `flame.png` and `explosion.png`
  are unused.
- **Poison**: `energyball` painted poison is a placeholder (Poison Spit uses it); author a venom
  drop, a bubble-burst impact, a puddle/cloud `piece`; point venom_spit, toxic_bloom, acid_spit,
  poison_fang, jade_fang (still a blood claw) and spore_cloud's area at `poison`.
- **Storm**: Thunder's `thunder.png` (frames now cut right) can be painted storm with
  `in_element`; author a spark projectile for Spark Wand / Spark Nova (cyan orbs today), a fork
  `piece`; point Thunder, Spark, Shock Roll, Gale, chain lightning (`element` export), the Storm
  synergy at `storm`. Decide whether storm stays violet or goes yellow-white (then holy must move).
- **Holy**: `holy_circle.png` at 5.6x and `magic_circle.png` (Vfx.magic, now 2x) need composing
  or bigger frames; unused `magic_spark.png` and `shield.png` fit holy; Smite, Holy Light, Holy
  Shield, heals and buffs.
- **Shadow / arcane**: no purple art exists. Arcane Bolt uses `energyball` painted arcane (a
  placeholder); author an arcane rune ring and a shadow smoke knot; point shadow_staff, the
  Sorcerer's volley, ink_bolt (still a cyan orb) and Shadow Step (a grey kunai) at their
  element; the arcane synergy's dots are still smooth.
- **Blood**: claws (`clawdouble.png`) are fine as blood; give them `element = blood` so hits
  drop blood bits; Battle Cry's magic circle, vampiric elites, pact chunks.
- **Spirit**: spirit_touch is a warm claw, Wailing Ring a cyan orb, soul_moth a fireball;
  author a wisp projectile; the ward bubble and soul wisps already use the spirit ramp.
- **Earth / sand** (done, `tools/vfx/earth.py`): Rock Spike and Fissure paint `rock_spike.png`
  in earth at 2x, Ground Slam is a ring of spikes, Quake and Sundering Blow burst the ground,
  every boss's stomp (`Combat.shockwave`) and a trapped chest are dust and rubble (the powder
  keg stays fire), Sand Breath throws clods, the Sand Drummer a clod that slows, Sandstorm
  whirls. Left: no earth claw yet; `sandball.png` is unused.
- **Physical**: the default swing `trail_color` is pale blue (reads icy): give steel its own
  `trail_color` or derive it from `physical`; Cleave, Lash, Whirlwind, Flurry, Iaido, Piercing
  Thrust sheets are drawn at 4x-6x (compose or author bigger); arrows and kunai turn on 16
  snapped angles (draw 16 directions to stop the shear); the CPU particle scenes
  (`src/vfx/particles/*.tscn`) still scale continuously (make them whole art pixels).
- **Everyone**: `SwingVfx`/`TelegraphView` shader grids turn with their aim; the actor's
  afterimage and props' `draw_circle` code (chests, pickups, heat sources, pact rooms) are
  still smooth; sounds per element are not wired (`impact_sound` is empty everywhere).
