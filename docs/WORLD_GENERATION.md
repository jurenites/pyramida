# Mountain terrain and seasonal water

Start a **new settlement in an empty slot** to generate the new map. Existing saves retain their terrain. Explore outward to find the buttes; WASD pans at the current absolute camera height. Inspect a blue puddle or stream and click **Collect water**. Citizens scoop one bucket per trip and bring it to storage; gardeners can also draw directly from reachable sources.

## Generation

`scripts/settlement/world_generator.gd` samples mostly flat desert with sparse Utah-style sandstone buttes. A level opening supports the starting family and stockpile. Five separated formations surround the initial region; coordinate-seeded patches continue into streamed regions. Each has a resistant flat-topped column, broad horizontal rock strata, and a diagonal gravel apron. The apron uses four saved corner heights per terrain cell, with small gravel chips inside those cells.

A room remains the **1×1 design reference** (2×2 asset metres). A terrain cell and placement step are **0.5×0.5** (1×1 metre), one quarter of a room footprint. `world_grid.gd` owns these dimensions. Floor spacing remains 2.4 m; the house's entrance stays centered on its front wall in all four orientations. New rooms may be placed at half-room offsets; overlapping footprints or unsupported edges are rejected, including on roofs. Gravel slopes are nonbuildable and not walkable; flat summits require player-built elevation access.

The opening loads 96×96 half-room cells in 16-cell chunks. Sampling uses absolute coordinates and neighbor halos, so terrain and debris match across chunk boundaries. Nature uses coordinate-hash priorities for resource clearance and a continuous seeded forest mask for dense tree stands separated by open ground. This remains a height field, not a cave/overhang or digging system.

## Vegetation patches

Living and dead trees form dense seeded stands in both Normal desert and Easy
coastal worlds. Adjacent cells can both contain trees, while stone and bush
clearance, water exclusions and the central starting clearing remain intact.
Dead trees make up approximately 40% of desert candidates and 25% of coastal
candidates. The continuous mask includes sparse isolated trees between forests
and uses a halo so region generation and independently loaded chunks agree.
Existing saved tree positions and harvested inventories remain unchanged; the
new placement applies to new worlds and previously unvisited chunks.


Grass reuses the original renderer's connected patch mask, shifted by the world seed, and grows in the starting clearing. Water, slopes, resource footprints, construction and unexplored ground suppress visible tufts. Bush colonies use the original three irregular outlines, rotated around seeded world-space anchors, with two-metre spacing for the current assets. Neighbouring anchors keep colonies continuous across streamed chunk boundaries.

New settlements start with four reachable colonies and a clear central construction area. The same 32 starting food is divided among their bushes. Existing saves retain their resource positions, quantities and regrowth; loading never replants harvested bushes. Newly generated chunks receive the colony layout, while decorative grass is rebuilt from the seed. This update does not change the terrain generator version or saved geometry.

`tests/settlement/vegetation_test.gd` checks connectivity, seed variation, chunk seams and order, starting supply and access, save preservation, fog and occupied-footprint exclusion.

## Day and night

The original six-minute day/night cycle is restored using `day_seconds` under `[general]` in the root `game_settings.cfg`. The sun crosses east to west and casts moving shadows; dawn, sunset and night use the original environment palette. Night retains soft ambient light for building and navigation. Lighting follows saved simulation time, so pause, game speed and loading a slot also control the sun.

## Small water inventories

- Puddles hold **3 buckets**; each narrow stream section holds **2**.
- A shower begins after 90 simulation seconds and lasts 16 seconds, repeating every 120 seconds.
- Rain restores one bucket per source every four seconds, up to capacity.
- Dry puddles lose one unreserved bucket every 35 seconds; streams lose one every 120 seconds.
- A citizen's reserved bucket cannot evaporate while they travel. Collected water leaves the source only at pickup.
- Wells hold six buckets and replenish one every 30 seconds, replacing the old per-tick refill.
- Rain is visible; the resource bar shows stored water and the next shower. Dry beds remain selectable.

This models shallow seasonal sources, not water pressure, river discharge, reservoirs or flooding. A stream's capacity is per section, so exploring farther provides more water at the cost of travel.

## Rendering and persistence

`terrain_mesh.gd` batches terrain caps, sloped gravel and exposed rock faces into chunk meshes with matching collision. There is a single rendered cap per cell. Trees and resources avoid the sloping aprons. Construction raycasts snap to the half-room grid and the model validates the complete building footprint.

Save format 5 records `grid_version = 2`, actual surface cells, gravel corner heights, seed, generator version, streaming state, source inventories and weather. Formats 1–4 migrate room-grid addresses to half-grid addresses while retaining building sizes, citizen world positions and shared inventories. Loading retains saved terrain instead of rerunning the new generator.

Run `python3 tools/settlement/run_checks.py`. `half_grid_test.gd` checks five seeds, mostly-flat proportions, clear openings, gravel detail, partial overlaps, complete roof support, centered rotated entrances, ladder travel, JSON roundtrips and old-save migration. Runtime terrain tests also raycast an actual gravel slope and tower face. Generate an unobstructed terrain preview with:

```sh
Godot --path . --script tools/settlement/capture_world.gd
```

Preview: `artifacts/world-generation.png`.

## Godot editor preview

`Terraces.tscn` builds its live world when the game starts. It now also instances `EditorWorld.tscn`, a serialized visual reference of the default seed, so the editor 3D workspace has terrain and settlement geometry before pressing Play. You can open `EditorWorld.tscn` directly to inspect it. This preview removes itself at runtime and does not replace saved settlements.

The preview is generated output: edit asset scenes in `data/settlement/` or the world generator to change the game, then regenerate the visual reference with `Godot --headless --path . --script tools/settlement/generate_editor_preview.gd`. Editing preview geometry alone does not change the live world. Use F5 to run the project; F6 on the editor-only preview intentionally has no game.

## Streaming and stable vegetation

New settlements stream 16×16 terrain cells (16×16 m) around the camera footprint. Camera zoom, pitch and window aspect determine the requested area, with a prefetch margin and one-chunk retention buffer. Terrain values are generated one chunk at a time on Godot's worker pool; model changes, collision and rendering are applied on the main thread. Switching settlements discards pending results from the previous seed. Navigation updates only changed ground cells and their neighbours, retaining constructed links.

The opening region, citizens, their full routes, buildings, construction sites, water orders and reserved inventories keep their chunks active. Other distant chunks release their terrain, collision, vegetation meshes and live inventories. Their compact resource records remain in the save: harvested timber, berries, stone, water and regrowth progress never reset merely because a chunk reloads. Dormant natural resources stop ticking until the chunk becomes active again; they do not simulate offscreen weather or regrowth catch-up. Settlements remain active regardless of the camera.

Trees use a continuous world-coordinate forest mask with adjacent cardinal and diagonal placements inside stands; bush colonies and connected grass patches also use absolute coordinates and the settlement seed. Placement excludes water, sloping gravel and resource overlap. Rendering uses the generated placements and stable per-cell grass transforms, rather than a separate random scenery pass. Arriving neighbours do not rebuild existing terrain or reroll plants. The fog texture follows the visible camera area instead of allocating a world-sized image.

This is a **semi-infinite** streamed height field with a practical horizontal limit of approximately ±16 km. Live memory follows active chunks and built settlements; save size grows with visited chunks and exploration history. It does not include caves, voxel digging, background simulation of dormant chunks or a floating-origin system. Existing saves without streaming metadata retain their recorded landscape and do not acquire newly generated terrain; start a new settlement to use streaming. The home-screen preview still becomes the exact starting world of New Game.

`chunk_stream_test.gd` checks region/chunk equality, negative coordinates, habitat exclusions, cross-border resource spacing, dormant saves, pinned jobs, bounded residency and incremental navigation parity. `chunk_visual_test.gd` checks stable mesh identity, grass transforms on reload, border geometry, distant fog and pending generation during a world switch. `tools/settlement/capture_streaming.gd` captures the home screen and neighbouring distant chunks using temporary save slots.

## Easy Greece landscape

The saved `difficulty` selects `normal` (the existing desert; default for older saves) or `easy` (`greece_landscape.gd`). Easy samples a continuous coast and low hills in absolute world coordinates, leaving the home clearing flat. Ocean cells have no ground/navigation/collision, and complete ocean chunks remain loaded for water rendering. Stream-state validation checks the coastal land mask rather than expecting 256 ground cells per chunk. The same choice travels through asynchronous chunk requests and slot persistence.

Easy meadows use six grass cutouts per eligible cell; Normal retains four. `settlement_grass.gdshader` bends tapered triangle blades with spatial wind gusts, camera-facing orientation and anchored roots. `scenery_view.gd` places each root on navigation's exact terrain triangle and disables shadow casting. The ocean uses one clipped, animated plane per coastal/sea chunk, without water inventories or colliders. Freshwater puddles retain their existing mechanics. The existing depth-aware exploration fog covers both land and sea.

Run `tests/settlement/greece_test.gd` for deterministic chunk seams, meadow coverage, gentle slopes, sea exclusion, saves and streaming. Run it with desktop rendering as well to inspect actual MultiMesh root transforms (the headless dummy renderer does not retain them). `tools/settlement/capture_greece.gd` produces the coast and grass previews.
