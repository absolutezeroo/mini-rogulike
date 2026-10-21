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
- **Shaders and particles quantize in world space.** A shader that draws a shape (a swing, a
  telegraph, a blast) takes the art pixel its fragment falls in on the world's grid
  (`MODEL_MATRIX * VERTEX`, like `frozen_ground.gdshader`), and turns the shape with a uniform,
  never the node. Particle scenes use `pixel_particles.gdshader` (corners snapped to the grid,
  fades dithered): even sizes in steps, no spin, `Gradient` interpolation CONSTANT.
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

## 2b. Layers: under, among or over the actors

Every effect is on one of three layers (`VfxLayer`, `src/vfx/vfx_layer.gd`). Flat things on the
floor must never draw over the hero's feet, and a crystal must hide a monster standing behind it:

| Layer | What | Where it draws | Examples |
|---|---|---|---|
| `GROUND` | flat on the floor | z -1: under every actor, over the floor's marks (splats -8, footprints -5) | `Vfx.magic` sigil, `RingVfx` rings, telegraphs (`TelegraphView`, `CellWarning`), storm's crackles, mist at a body's feet, level-up rings, elite auras, afterimages |
| `STANDING` | upright, rooted on the floor | z 0 in the world's y-sorted Entities, sorted by its **base** (the bottom of its frame) | frost crystals, holy rays, shadow smoke, arcane runes, Smite's column, Thunder's bolt, dust puffs |
| `AIR` | in flight or on a body | z 5-6: over every actor and over the floor's light | shots, impacts, hit flashes and bits, blade arcs (`SwingVfx`), bursts, beams, halos (Holy Shield), the crit cross, sparks, smoke, damage numbers |

- A sheet says its layer: `VfxSheetDef.layer` (AIR when it doesn't say: shots, impacts, claws
  and halos need nothing). **A nova `piece`, a `strike` or a sigil must say GROUND or STANDING**
  (the vfx tests check every element's piece). `SheetVfx.play` / `ComposedVfx` read it; code
  that draws by hand calls `VfxLayer.apply(node, layer)`; `World.spawn_vfx` puts a standing
  effect among the actors. A plain texture played with `SheetVfx.create` is AIR unless
  `.on_layer(...)` says otherwise.
- A standing sheet's node sits at its base and draws its frame above it (`base_offset()`:
  half its height plus its `anchor`). A composed nova of standing pieces is one node per piece
  (`ComposedVfx.StandingPiece`); its wave edge and residue lie on the ground.
- GROUND and STANDING are under the floor's light (`LightField.Z` = 3), lit with the room like
  the floor and the actors. An emissive one lights itself (`VfxLayer.light_up`: a light in its
  core color while it lives), so a frost nova or a holy column keeps its colors in a dim room;
  a telegraph carries a red light (`TelegraphView.add_light`). Matter (blood, earth, steel)
  takes the room's light.
- A status on a body (`StatusFx`) is on the body (its crust, flames, bubbles sort with it); its
  mist at the feet is GROUND.

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
| storm | `f4f0ff c9b8ff 8f73e6 4b3a99 251c4f` | electric violet-white: jagged forks of straight runs and sharp knees, flicker (1-3 frames on, a frame off with the afterglow, a second strike), never a plus | FORK | OUTWARD | none / scorch |
| holy | `fffbe8 ffe18d f1c471 bd7959 61372e` | rays, rings, columns from above, slow motes of light; the **4-point glint is holy's alone** | GLINT | FALL | none |
| shadow | `150d1f 3b2346 7a3a7e d24a86` | swirls, smoke, a ring that collapses, dithered edges, pulled inward | MOTE | CONVERGE | smoke `2a1f33` / stain |
| arcane | `ffe6fa f07ad8 b048c0 6a2a8a 2e1446` | runes, orbits, diamond glints (rhombi, hollow or filled), spirals | RUNE | ORBIT | none |
| blood | `ff9b8f e0394c a3162c 5a0a1e` | drops, spurts, ballistic arcs, stains that stay | DROP | FALL | none / stain |
| spirit | `f0fff8 b8f5dc 6fd6b4 3b8f86 234b52` | wisps, hollow rings, pale flames curling up, flicker | MOTE | RISE | ectoplasm |
| earth | `f5e6c4 d2b37d a3754e 6b5040 3b3238` | rock spikes, chunks flung on arcs, dust clouds, cracks | SQUARE | FALL | dust `c8b08a` / cracks |
| physical | `f2eaf1 c7c7c7 8c8c8c 4e484a` | steel: crescent arcs, short streaks along the blow, sparks | SQUARE | OUTWARD | none |

Mood (docs/lexicon.md): the Well is dark, so only emissive cores get the screen's rare bright,
saturated pixels; smoke, blood and ash stay in the muted ramps of the floors.

### Element kits

The kit's slots (`VfxElementDef`): `projectile` (its shot), `impact` (a shot landing), `piece`
(one piece of its novas, waves and trails, composed by `ComposedVfx`), `claw` (a creature's
blow), `slow_look` (the look of a body it slows, a `StatusLookDef`), `impact_sound`. Missing
slots fall back to code that still speaks the element (a burst in its ramp, a ring with its
bits on the rim).

| Element | Projectile | Impact | On the body | Nova / area | Telegraph | Sound family |
|---|---|---|---|---|---|---|
| fire | a ball with a licking tail, embers behind | `BlastVfx` ball of fire, smoke, scorch | small flames rising, embers, warm tint | ring of flame licks | warm rim, embers creeping in | whoosh, crackle |
| frost (**done**) | `frost_shard.png`: a faceted shard drawn in 16 directions, chips trailing | `frost_impact.png`: shards cracking outward, biggest early, chips falling, mist | rime growing on the edges (`frost_rime.png`), ice chips falling, cold mist at the feet, 45% cold tint | `frost_crystal.png`: crystals growing from the ground in a ring, then shattering | the shared danger rim; frost chips inside | cracking ice, glassy chime |
| water | a drop (energy orb painted water) | splash, droplets, a ripple | drips (none yet) | ripples (`water_ripples.png`) | danger rim | splash |
| poison | a venom drop (orb painted poison) | bubbles bursting, a sinking cloud | bubbles, a haze sinking at the feet, green tint | a cloud crawling out | danger rim, bubbles inside | squelch, hiss |
| storm (**done**) | `storm_spark.png`: ball lightning, arcs leaping off it at uneven angles, flickering | `storm_impact.png`: forks out, off, a second strike, broken tips | small arcs jumping off the body (none yet) | `storm_fork.png`: crackles on the ground around a ring; Thunder's `storm_bolt.png` falls from the sky on top (`DamageAreaEffect.strike`); chain lightning is a jagged `BeamVfx` | crisp flicker | crack, zap |
| holy (**done**) | none needed (no holy shot) | the hit's 4-point glints | short ray halo (none yet) | `holy_ray.png`: a sparse ring of thin shafts; Smite's `holy_column.png` falls on the target; Holy Shield's `holy_aegis.png` rises into a halo; heals and buffs draw `holy_sigil.png` (Vfx.magic, recolored for other colors) | rays converging | chime, bell |
| shadow (**done**) | `shadow_knot.png`: a dark knot, a burning broken rim, smoke curling in (all shadow shots are enemy threats) | `shadow_impact.png`: a ring collapsing inward, a puff | darkened silhouette, filaments sucked in (none yet) | `shadow_smoke.png`: smoke curling up and drawn back in (Shadow Step's trail) | the ground dims | whisper, low thrum |
| arcane (**done**) | `arcane_missile.png`: a diamond glint, three motes on a tilted orbit (behind ones darker) | `arcane_impact.png`: rune-diamonds turning outward | glyphs orbiting (none yet) | `arcane_rune.png`: glyphs lighting over the ground | runes lighting up | chime, hum |
| blood | none (claws, spurts) | spurt, drops that stay | short spurts on each tick | spray in a fan | danger rim | wet impact |
| spirit | a pale wisp curling | a hollow ring, wisps rising | pale flicker | a ring of wisps | pale rim | sigh, chime |
| earth | a rock or a ball of sand | chunks on arcs, dust | dust trickling | rock spikes, dust ring | cracks spreading | thud, crumble |
| physical (**done**) | `arrow`, `kunai`, `spear`, the tengu's `feather` drawn in 16 rows (shurikens and coins spin as they are) | short streaks along the blow; the bits of the target's material (blood drops, bone chips, slime, sparks off armor, spirit motes, leaf chips); a crit cuts the `cutx` cross | none | steel crescents, spins and thrusts (`SlashDef` + `SwingVfx`), an enemy's with a red rim; plain rushes kick up dust | lines, cones and lanes | swish, clang |

## 5. The code

| What | Where | Use |
|---|---|---|
| `VfxElementDef` | `src/definitions/vfx/vfx_element_def.gd`, `data/vfx/elements/*.tres` | ramp, residue, mark, bit, motion, emissive, kit sheets. `VfxElementDef.named(&"frost")`, `.core() .color() .edge() .shade(t)`, `or_color(element, color)` for old content |
| `VfxSheetDef` | `src/definitions/vfx/vfx_sheet_def.gd` (sub-resources of an element) | texture, frames (0 = square), orient (NONE / ROWS / SNAPPED), directions, variants, fps, loop, texel, recolor, anchor, linger. `VfxSheetDef.from_texture(tex, frames)`, `columns/cell_size/slices_evenly` (the one frame slicer) |
| `element` exports | `WeaponDef`, `ProjectileEffect`, `DamageAreaEffect` (+ `strike`: a sheet of its own at 2x on the area's middle), `DashStrikeEffect`, `DashEffect` (a burst and a trail), `HealEffect` / `BuffEffect` (the sigil's ramp; `BuffEffect.sheet` follows the user), `ChainLightningPassive` (a forked `BeamVfx`), `OnHitStatus.slow_element`, passives (`element`, `shard_element`, `crit_element`, `blast_element`), `DeathBurstTrait` | gameplay data points to an element instead of free colors; `HitInfo.element` carries it to the hit's flash |
| `PixelDraw` | `src/vfx/pixel_draw.gd` | `snap`, `snap_length`, `sheet_scale`, `dither`, `pixel`, `ring`, `disc`, `arc`, `line`, `polyline`, `polygon`, `bit` (an element's particle shape), `sheet` (draw a frame of a VfxSheetDef on the grid) |
| `VfxLayer` | `src/vfx/vfx_layer.gd` | `Layer.GROUND / STANDING / AIR` (section 2b), `apply(node, layer)`, `of(node)`, `light_up(node, element, reach)`; `VfxSheetDef.layer` |
| `SlashDef`, `SwingVfx` | `src/definitions/vfx/slash_def.gd`, `data/vfx/slashes/`, `src/vfx/swing_vfx.gd` | a blade's blow drawn by `swing.gdshader`: CRESCENT / SPIN / THRUST, arc, thickness, strokes, reach_scale, jitter, `finisher` sheet; on `WeaponDef.slash`, `DamageAreaEffect.slash`, `DashStrikeEffect.slash`. `SwingVfx.slash(world, look, at, aim, reach, element, danger)` |
| Things in flight | `data/vfx/sheets/` (`arrow`, `kunai`, `spear`, `feather`), `tools/vfx/physical.py` | 16-row sheets: `ProjectileEffect.sheet`, `WeaponDef.projectile_sheet` (the `texture` stays the item's picture) |
| `ImpactMaterialDef` | `data/materials/` | `spark_bit`, `spark_motion`, `sparks_element()`: a hit's bits in what the target is made of (`Vfx.hit(..., material)`) |
| `VfxRamp` | `src/vfx/vfx_ramp.gd` | `recolor(texture, ramp)`: palette swap by luminance, cached (a sheet with `recolor` on is painted in its element's ramp) |
| `Vfx` | `src/vfx/vfx.gd` | `hit(..., element, material)` (a crit cuts `CRIT_CROSS`), `dust_trail(world, from, to, duration)`, `pop(world, at, element, radius, direction)`, `nova(world, at, radius, element)`, `trail(world, from, to, element)`, `explosion(world, at, radius, element)` |
| `SheetVfx` | `src/vfx/sheet_vfx.gd` | `play(sheet, at, direction, element)` (on the sheet's layer), `create(texture, ...)` (legacy: snapped, AIR), `.in_element(e)`, `.on_layer(l)`, lingering dither |
| `ComposedVfx` | `src/vfx/composed_vfx.gd` | `ring(at, radius, element)`, `line(from, to, element)`: any size from pieces at 2x |
| `ImpactVfx`, `RingVfx`, `BlastVfx` | `src/vfx/` | a hit's flash (`ImpactVfx.sparks`: bits only), a ring (GROUND), a burst: all in an element's ramp and bits |
| `TelegraphView` | `src/vfx/telegraph_view.gd`, `telegraph.gdshader` | CIRCLE, CONE, LINE, LANES (one per shot of a fan or ring); `show_skill(skill, angle, progress, body_radius)` picks the shape from the skill (radius, shots, dash, area) |
| Particles | `src/vfx/particles/`, `src/vfx/ambient/`, `pixel_particles.gdshader(.inc)` | materials `pixel_particles` (dither per art pixel), `_motes` (whole motes come and go), `_glow` (added light, stepped brightness) |
| `StatusLookDef`, `StatusFx` | `data/vfx/status_looks/`, `src/vfx/status_fx.gd` | particle, motes (EMBER, BUBBLE, CHIP), crust (rime), mist, burst, all at texel 2 in the element's ramp |
| Tools | `tools/vfx/` | `vfxkit.py` (palette-locked drawing), `recolor.py` (palette swap to a file), `check.py` (palette, hard alpha, whole cells), `strokes.py` (lines, jagged paths, rims, glints, rhombi, ellipses), one rebuildable script per kit: `frost.py`, `storm.py`, `holy.py`, `shadow.py`, `arcane.py` |

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
   linger, **layer**) or of the content; set frames explicitly for any non-square sheet.
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
- [ ] On its layer (section 2b): nothing flat draws over the hero's feet; an upright thing hides
      who stands behind it and is hidden by who stands in front.
- [ ] The main action is in the first quarter; the flash lasts 2-3 frames; it dissipates
      instead of vanishing.
- [ ] Its size and noise match its gameplay weight; it never hides a telegraph or an enemy shot.
- [ ] It reads on the darkest biome (the crypt) and the brightest (the desert).
- [ ] An enemy's version is told apart from the hero's at a glance.
- [ ] One dominant hue.

## 8. Where each element stands

Frost is the reference kit, done in full. The foundation (grid helpers, ramps, palette swap,
slicer, element exports) serves the others; what each still needs:

- **Fire**: author a fire projectile (the warm `fireball.png` works, but its tail ignores the
  flight direction: draw 16 directions or a tail-less ball), an impact sheet, a flame-lick
  `piece` for Fire Wave / fire rings / Blazing Roll; `flame_arc` uses an untinted
  `circularslash` at 6x (author or compose); the burn look's `flame.png` burst is 25x30 (fine at
  2x). Point Fireball, Fire Wave, Ember Tome, fire_breath, fire_ring, solar_flare, ignite,
  kindling, inferno, pyre, of_embers, blazing_roll at `fire`.
- **Poison**: `energyball` painted poison is a placeholder (Poison Spit uses it); author a venom
  drop, a bubble-burst impact, a puddle/cloud `piece`; point venom_spit, toxic_bloom, acid_spit,
  poison_fang, jade_fang (still a blood claw) and spore_cloud's area at `poison`.
- **Storm** (done): stays electric violet-white (holy owns gold); the Storm synergy, Thunder,
  its tome, Spark Wand, Spark Nova, Thunderclap, Shock Roll, Frenzy wear the storm's color.
  Thunder, Spark Wand/Nova, chain lightning (synergy, Spark Rune, Thundering), Thunderclap,
  Shock Roll and the Gale Rune are storm. Left: arcs on a shocked body (no shock status yet);
  `thunder.png` and the skill icons are unused/untouched art.
- **Holy** (done): Smite, Holy Light, Holy Shield, holy heals; `Vfx.magic` is the holy sigil
  for every heal, buff, learned skill, level up and sealed room (holy for gold, painted in the
  caller's color otherwise). `holy_circle.png`, `magic_spark.png`, `shield.png` (a flame-like
  wave) are unused; `magic_circle.png` is only the pact sigil (pact_room, 2.25x/1.5x).
- **Shadow** (done): shadow_staff (Sorcerer), its Volley, the Octopus's Ink Bolt and Ink Ring,
  the Shaman's Hex Bolt fire the shadow knot; Shadow Step bursts into shadow, leaves smoke and
  its kunai land in shadow. Left: curses have no effects of their own.
- **Arcane** (done): Arcane Bolt and the Arcane synergy's ring fire the arcane missile; the
  arcane perks wear its color. Left: no arcane area or charge-up uses the rune piece yet.
- **Blood**: claws (`clawdouble.png`) are fine as blood; give them `element = blood` so hits
  drop blood bits; Battle Cry's magic circle, vampiric elites, pact chunks.
- **Spirit**: spirit_touch is a warm claw, Wailing Ring a cyan orb, soul_moth a fireball;
  author a wisp projectile; the ward bubble and soul wisps already use the spirit ramp.
- **Earth / sand**: `rock_spike.png` is lava-orange and drawn at 1.8x-4.3x (author earth
  colors, compose Ground Slam); Quake and Sundering Blow should set `element = earth` on their
  explosive area (the blast then becomes dust); sandball has a fire-orange halo color; Sand
  Breath and Sandstorm slow as earth already (no frost).
- **Physical** (done): blades swing steel (or their element's) arcs on the grid; Cleave, Lash,
  Whirlwind, Flurry (its last stab the `cutx` cross), Iaido Dash, Piercing Thrust and the
  monsters' club, demon club and tengu blade are `SlashDef`s; arrows, kunai, the thrown spear
  and the Crimson Tengu's feathers are drawn in 16 rows; hits throw their material's bits.
  Left: Shadow Step's kunai still uses the old snapped `kunai.png` (shadow's to repoint at
  `data/vfx/sheets/kunai.tres`), arrow traps turn `arrow.png` by quarter turns only (exact),
  the slime slam and body slam play `circularslash` unturned at 2x.
- **Everyone** (done): swings and telegraphs quantize in world space; monster shots warn with
  their lanes, dashes with their line; plain rushes leave dust and dithered afterimages in the
  dash's element; particles snap to the grid; props, pickups, auras, the pact sigil, stairs'
  seal and heat sources draw with `PixelDraw`; the trap's peek is at 2x; fog texels are art
  pixels; every effect is on a layer (section 2b). Left: sounds per element are not wired
  (`impact_sound` is empty everywhere); the actor's debug fallback body (no sprite) is smooth;
  fire, earth, poison, blood and spirit sheets get their layer when their kits land (a sheet
  that says nothing is AIR: their nova pieces must say GROUND or STANDING).
