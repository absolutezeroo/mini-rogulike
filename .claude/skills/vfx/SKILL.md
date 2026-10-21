---
name: vfx
description: Make or fix a visual effect in Le Puits des Âmes coherently - a shot, an impact, a nova, a slash, a status on a body, an element's whole kit (fire, frost, poison, storm, holy, shadow, arcane, blood, spirit, earth, water, physical). Covers the pixel grid rules, element ramps and shapes, drawing pixel art on a ramp with tools/vfx, palette swaps, wiring the data, screenshots and review. Use for any request about effects looking wrong, incoherent, blurry, or like the wrong element.
---

# Visual effects

Read docs/vfx.md first: the grid rules (section 1), the readability order (2), timing (3), the
element tables (4), the code (5), and "Where each element stands" (8) for what is left to do.
The bar is Dead Cells / Blasphemous: hand-made pixels at the art's size, one language per element.

## 1. Know what you are fixing

- Find every user of the effect: `grep -rn "<sheet or color>" data src`. List the content per
  element (a skill's effects, a weapon's shot, a passive's wave, a status, a monster trait).
- Take "before" screenshots (section 6) so you can compare.

## 2. Pick the element and fill its kit

- The element is what a player would call it. Its file: `data/vfx/elements/<id>.tres`
  (`VfxElementDef`): `ramp` (3-5 colors, core to edge, never pure white or black), `accent`,
  `residue`, `mark`, `bit`, `motion`, `emissive`, and the kit sheets as `VfxSheetDef`
  sub-resources: `projectile`, `impact`, `piece` (composed into novas, waves, dash trails),
  `claw`, plus `slow_look` (a status look id) and `impact_sound`.
- Shape before color: frost is faceted and angular, fire licks up, poison bubbles and sinks,
  storm forks and flickers, holy rays, shadow converges in smoke, arcane orbits with runes. A
  radial symmetric star is nobody's (it reads as a shuriken). Check the element's row in
  docs/vfx.md and keep to it; if you must change the language, change the doc too.

## 3. Point the data at the element

- `element` on `WeaponDef`, `ProjectileEffect`, `DamageAreaEffect`, `DashStrikeEffect`,
  `DeathBurstTrait`; on passives `element` / `shard_element` / `crit_element` / `blast_element`;
  `slow_element` on any slowing `OnHitStatus` that is not frost (frost is the default).
- Remove what the element replaces: a borrowed `texture` (a shot without one is the element's
  projectile), an area's `fx` (without one it is the element's nova), free `color`s.
- A non-square sheet always says its frame count (`texture_frames`, `projectile_frames`,
  `fx_frames`; 1 for a single sprite). `tests/suites/vfx_tests.gd` fails otherwise.
- Edit `.tres` by hand carefully (keep `[ext_resource]` ids; no `uid=`), or with the inspector.

## 4. Draw new pixel art (on the ramp, at the art's size)

- `tools/vfx/vfxkit.py`: `Element.load(id)`, `Sheet(cell=(w, h), frames, rows)`, cells of ramp
  indices (0 = core ... last = edge, `RESIDUE`), `fill_polygon`, `rotate`, `outline`, `clean`,
  `sheet.save(path, element)`, `sheet.preview(path, element)` (zoomed on a dark and a light
  floor). `tools/vfx/frost.py` is the worked example: facets lit from the top left by their
  normal, a near-white tip, the dark edge as outline, shapes rendered per direction instead of
  rotated, near-vertical rows mirrored from near-horizontal ones, stubs shaved.
- One art pixel per texel, hard alpha, frames in a row, directions (`Orient.ROWS`, 16, row 0
  pointing right, clockwise) or variants in rows. A big effect is a small piece composed many
  times (`ComposedVfx`), never a sheet stretched to the radius.
- Reusing art in another element: set `recolor = true` on its `VfxSheetDef` (painted at runtime by
  `VfxRamp`), or bake a file: `python3 tools/vfx/recolor.py <in.png> <element> <out.png> --preview <x6.png>`
  then touch it up.
- Always: `python3 tools/vfx/check.py <png> <element> --cell WxH` (palette, hard alpha, whole
  cells). Open the preview image and look at it; iterate until it reads at a glance.
- Put the art in `assets/fx/<element>/`, run `godot --headless --import` to make its `.import`,
  and commit both.

## 5. Code: use the helpers, never smooth shapes

- In `_draw()`: `PixelDraw.snap / snap_length / pixel / ring / disc / line / bit / sheet` and
  `PixelDraw.dither(cell, amount)` to fade. No `draw_circle`, `draw_arc`, alpha fades,
  `color.lerp`; colors from `element.shade(t)` / `.core()` / `.color()` / `.edge()`.
- Spawning: `Vfx.hit(..., element)`, `Vfx.pop(world, at, element, radius, direction)`,
  `Vfx.nova(world, at, radius, element)`, `Vfx.trail(world, from, to, element)`,
  `Vfx.explosion(world, at, radius, element)`, `SheetVfx.play(sheet, at, direction, element)`.
  Old content with only a color: `VfxElementDef.or_color(null, color)`.
- Sheets: whole even `texel` (2), `linger` for dissipation (the `dither_fade` shader), never
  `rotation = angle` on pixel art (ROWS or SNAPPED).
- Layers (docs/vfx.md 2b): give every sheet that lies on the floor `layer = GROUND` and every
  upright one (a crystal, a column, a spike) `layer = STANDING` (sorted with the actors by the
  bottom of its frame); AIR (the default) is for shots, impacts, halos. Hand-drawn nodes:
  `VfxLayer.apply(node, layer)`. Nothing flat may draw over the hero's feet.
- Shaders quantize in world space (`MODEL_MATRIX * VERTEX`, the shape turned by a uniform);
  particle scenes use the `pixel_particles` materials (even sizes, no spin, constant ramps).
- Shaders (docs/vfx.md 5b): include `assets/shaders/fx.gdshaderinc` (cell on the world's grid,
  `bayer`, `noise`, `stepped_time`, the emissive mask); move pixels up/down the ramp
  (`uniform vec4 ramp[5]`, `ramp_index`), never blend; time at 12-20 fps. A sheet picks one with
  `VfxSheetDef.look` (SHIMMER, GAS, RUNE, FLAME), `flash_frames`, `halo`/`halo_at`; code uses
  `FxLook`. A glow is `GlowHalo.attach` (one light per glow, never a second LightSource). Bent
  space is a `DistortionStamp` (HEAT, COLD, PULL, SHOCK; `VfxElementDef.distortion`): never a
  new node reading the screen, only `screen.gdshader` does (a test checks it). New shader: add it
  to `FxLook.ALL` (warmed at load) and to fewer effects' cuts if it costs.
- Lessons: a uniform 50% dither of added light reads as a screen door, a halo is flat bands
  with a checker only on their edge; additive light over a bright floor washes out (halos are
  sparser there); a halo drawn over its own core whitens it (draw it behind:
  `show_behind_parent`); pixels added outside a sheet's silhouette overwrite the copies that
  overlap it; bloom inside bright shapes dots them (bleed only into darker pixels); gas that is
  only darker reads as bushes, gas needs a bright rim and holes. In a canvas shader `COLOR`
  already holds the texel: `texture(TEXTURE, UV) * COLOR` squares the colors (much darker);
  check a shader's output against the sheet's own colors (count them in a crop).
- New behaviour goes in a small class or the element data, not in `Actor`/`Monster`/`World`.

## 5b. On a body: the rig's shader, not another node

- A status's look on the body, an elite's rim, a death: `assets/shaders/flash.gdshader` (one
  shader, uniforms as flags; each rig has its own material already), driven by `BodyLook`
  (`rig.look`). Read docs/vfx.md section 9 first.
- Work in the sprite's texel space (`local` from `VERTEX`, `floor(local)` = the art pixel), bound
  every neighbour read by `frame_rect` (frames are packed edge to edge in AtlasTextures), take
  colors from the `ramps` texture (`ramp(row, step)`, `luma_step` to repaint a sprite color),
  fade with the Bayer dither, step `TIME`. `TEXTURE` can't go into a function: use the macros.
- A new status look: `StatusLookDef.body` (HEAT, RIME, WAVE, FLICKER) or a new one (a uniform,
  a case in `BodyLook.show_statuses`, a block in the shader's busy path, the cheap-path test at
  the top of `fragment()`), and thin its particles: the shader is the base, particles the accent.
- A new death: a `DeathLookDef` in `data/vfx/deaths/` (style, timing, chunks, burst, shards,
  motes, piece, mark) pointed to by the element's `death`; a new style is a case in the shader
  (keep `DeathLookDef.Style` in step) and maybe a piece in `DeathFx`/`DeathPiecesVfx`.
- Pitfalls: the node's modulate multiplies after the shader (set it white for exact ramp
  colors); the room's warm light turns near-white beige (use the mid steps for cold things);
  `Image.set_pixel` truncates (round colors to 8 bits yourself); `AtlasTexture.get_rid()` is
  its atlas's (don't cache by RID per frame).
- Perf: keep the plain branch cheap (no reads beyond the texel), test the busy path with
  a bench in `_tool/` (gitignored: 30 rigs at the game zoom, statuses on or off, the render
  time measured with `viewport_set_measure_render_time`) under xvfb.

## 6. Look at it (headless tests can't)

- Copy `_tool/vfx_probe.gd` / `.tscn` if it exists (`_tool/` is gitignored), or write one like
  it: instantiate `res://src/game/game.tscn`, make the hero invincible, spawn dormant monsters
  with huge Health, apply skills with `effect.apply(user, aim)`, fire with
  `world.fire_projectiles`, apply statuses, and save `get_viewport().get_texture().get_image()`
  every few frames plus a 4x nearest crop around the effect.
- Run: `timeout 300 xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 res://_tool/<probe>.tscn -- <outdir>`
  (window 1540x720, the tester's phone ratio). Write into your own folder of the scratchpad.
- Read the images yourself. Go through the review checklist of docs/vfx.md section 7 for each
  frame: pixel size, ramp only, silhouette reads as the element in grey, 16 directions at most,
  first quarter, dissipation, weight, dark and bright biomes, enemy vs hero. Iterate.
- Biomes: `world.forced_biome = load("res://data/biomes/<id>.tres")` then
  `game.debug_enter_floor(2)`: shoot the crypt (dark), buried_city (the desert, bright),
  burning_ruins (warm grade, heat) and underground_garden (green floor). llvmpipe is slow: one
  biome per run, runs in the background.

## 7. Tests, texts, docs

- `godot --headless --fixed-fps 60 res://tests/run_tests.tscn -- --only=unit,title` (the unit
  suite runs `tests/suites/vfx_tests.gd`): add checks for your element (its users point at it,
  its kit is filled, nothing borrows another element's art, sheets slice and scale). Then the
  full run (`--only=game`, `--only=tutorial`) before calling it done. Never weaken a check.
- A changed rule or number (a weapon that now chills) changes its description text, then
  `python3 tools/i18n/extract.py`, the French (the `translate` skill), the docs/design/ page and
  a docs/balance-log.md entry.
- Update docs/vfx.md: the element's rows, and "Where each element stands" (what you did, what
  is left).

Report: the element(s), the art made (paths), the content now pointing at them, the tests, the
screenshot paths (before/after), and what you could not check (the phone screen, outdoors, the
feel in motion).
