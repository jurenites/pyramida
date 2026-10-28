> The current playable economy supersedes the earlier shell-building limitations below. See [Pyramida research and foundation](PYRAMIDA_RESEARCH.md) for production, commands, population and persistence.

# Vertical settlement prototype — v0.1.0

The default F5 scene is now `scenes/settlement/Terraces.tscn`. The older flat-world prototype remains available in `scenes/Main.tscn` with F6. Its missing shader dependencies have been recovered, and its sawmill blueprint once again declares the workshop recipe expected by its existing tests.

## Try it

Choose one of three settlement slots when the game opens. An empty slot offers Easy, Normal and Hard, with **Normal** as the only enabled choice. Selecting an existing slot continues its saved settlement. A new game starts with only a Stockpile, two adults and one child. The stockpile holds 18 timber and 5 food. Place the first buildings yourself; no terraces, stairs, wells, gardens or construction orders are prebuilt. Children wander and eat independently, cannot be selected for work, and become adults after three simulation days. Pausing also pauses growth; saving preserves age and appearance.

- Click an adult resident to inspect their current job, cargo, distance travelled, and route.
- Click the well, tree, garden, stockpile, or platform to inspect it.
- Use the top-right housing, industry and structure tabs. **B** collapses the build menu. Choose a building and click a valid preview; **Esc** cancels placement and clears selection while play continues.
- Placement automatically follows the ground, deck or building roof under the cursor. **R** turns buildings through four orientations. **Q / E** selects cutaway floor 0–8; it does not change the placement height.
- A platform needs support directly below. A ladder is a freestanding 1×1×1 building with its own support frame. It can stand on clear ground or a floor before an upper landing exists. An adjacent deck or roof one level higher enables bidirectional diagonal travel; the neighbouring deck stays intact.
- **Remove stairs** operates at the stair's lower floor. Removing a clear staircase disconnects routes; workers keep carried goods. Queue replacement stairs and stranded builders can redirect their timber to restore access.
- New stockpiles request a four-log buffer from reachable stocked piles. All transfers require workers to walk and carry the goods.
- Gardens receive water from the well, grow, produce food, and are harvested into storage. Residents walk to stored food to eat. Depleted trees regrow.
- **WASD** pans, **right-drag** or **middle-drag** orbits, and the wheel zooms.
- **C** hides architecture above the chosen floor. The speed button cycles 1×, 2×, 4×; there is no gameplay pause. **Esc** deselects everything without saving or leaving play.
- The toolbar exit saves and returns to settlement selection. Within menus, Esc goes back from a submenu and resumes from the main menu.
- Saving is automatic every 30 seconds of real play time, after construction clicks, on opening the menu, changing slots, leaving the application, and quitting normally. F5/F9 are no longer manual save/load shortcuts. In the Godot editor, F5 still runs the project.
- Settings contain only Fullscreen and Show delivery routes; both persist automatically.
- A fresh settlement uses an empty slot. Existing slots are never reset or overwritten by the new-game flow.

Saves live in `user://settlements/slot_1.json` through `slot_3.json`. Each slot stores Normal difficulty, the complete world snapshot, camera, cutaway and simulation speed. Atomic replacement retains the previous valid save as `.bak`; an unreadable primary automatically falls back to that backup. If neither file is readable, the slot stays unavailable and its files stay intact. Failed writes block switching/quitting and display an error so unsaved progress is not silently discarded.

The original `user://terraces_save.json` imports into empty slot 1 on first regular launch, preserving the original file. The world snapshot remains version 3 with versions 1 and 2 migration; slot metadata has its own format version. Display preferences are in `user://settlements/settings.cfg`. Showcase/gallery and automated capture scenes are previews that do not write player slots.

Run `tools/settlement/capture_menu.gd` with graphical Godot for five actual UI-state screenshots, using disposable saves under `/tmp`. Menu tests exercise isolated slots, automatic progress writes, pause/input gating, backup recovery, invalid saves, failed writes and legacy import.

### A second storey

1. Complete the opening platform.
2. Choose Platform and hover the decks at `(0,1,0)` and `(1,1,0)` to snap new floors directly above them. Workers can raise these from below.
3. Add an approach platform at `(0,1,2)`. Hover the lower deck; build stairs at `(0,1,1)`, facing towards `(0,2,0)` (rotate with R).
4. Once connected, place a garden on the second-storey platform and a stockpile on the first-storey extension.

The `--showcase` launch option performs this sequence through the same construction API and worker simulation. It also builds a log shed, crop plot, windmill and two stacked houses through worker deliveries. Open `scenes/settlement/BuildingShowcase.tscn` with F6 for the same playable demonstration. It does not spawn completed buildings directly.

## Map and stacking contract

The world contains **1,681 ground cells (41 × 41, 82 × 82 metres)**, compared with the previous 99 cells. This is a larger bounded map, not infinite streaming. Camera panning/zooming and save validation use the expanded bounds. Groves and decorative scenery extend into the new land.

Roof-bearing buildings end at exactly **2.4 metres**, matching the floor interval and `RoofSocket` marker. A house on another house starts at that roof. A platform has 2.4-metre posts, so its deck is one further floor above the supporting roof. Crops, wells, mills and other non-structural props cannot support floors. Placement checks reject occupied spaces, unsupported floors and intersections with existing decks or queued construction. Transparent plans never count as support. Hidden cutaway buildings do not intercept the picking ray.

Construction still uses prototype timber costs rather than the original game's multi-resource economy. Roads and walls are currently visual buildings; they do not accelerate or block pathfinding. Roofs add walkable surfaces, but citizens still need actual stair connections to reach another elevation.

## Architecture and ownership

| Module | Responsibility |
| --- | --- |
| `world_model.gd` | World state, construction rules, growth, topology changes, simulation tick |
| `navigation.gd` | Distinct 3D floor identities, same-floor connections, explicit stair links, weighted route search |
| `inventory.gd` | Stock, bounded capacity, exclusive reservations, physical pickup |
| `job_system.gd` | Source/destination selection, carrying, construction, meals, harvesting, restocking, recovery from disconnected routes |
| `main_menu.gd` | Modal navigation, slot and difficulty selection, minimal display settings |
| `save_slots.gd` | Atomic autosaves, previous-save recovery, legacy import and settings persistence |
| `save_codec.gd` | Versioned JSON, validation, shared inventory identity and in-flight job restoration |
| `world_view.gd` | World meshes, colliders for inspection, growth presentation, routes and cutaway |
| `worker_view.gd` | Articulated walking, work poses, selection ring, cargo attachment |
| `asset_library.gd` | Cached editable scene loading and preview material replacement |
| `camera_rig.gd` | Camera movement only |
| `hud.gd`, `text.gd` | Interface and translation mapping; English content stays in `localization/ui_text.csv` |
| `settlement.gd` | Scene composition, player input, session lifecycle, autosave triggers and capture helpers |
| `data/settlement/catalog.gd` | Construction costs, asset sizes, access markers and future utility ports |

The simulation is independent of the scene tree and renderer. Tests advance it with fixed time steps. The scheduler is stateless: jobs live in worker/world state, so there is one saveable source of truth.

Material reservations do not decrement inventory. Pickup transfers one unit to a worker. Arrival plus labour installs or stores it. Roofs do not become walkable until construction completes; a floor never connects to another elevation simply because they overlap. Removing stairs does not grant an emergency route through walls.

The earlier `AppliedLabour` helper is reused. The original object assets, blueprint format, Blender extension, citizens and streaming prototype remain intact as reference/compatibility assets. The new default scene uses the replacement kit and new vertical simulation; the old 5,718-line coordinator has not been silently rewritten.

## Art kit

`data/settlement/` contains 33 original editable models, each delivered as a `.tscn` and a `.glb`:

- Four featureless citizen outfits (shorts, dress, one-shoulder robe, separate top and skirt) and named head, limb and cargo pivots.
- Timber platform, stairwell landing, support frame and staircase.
- Timber storage rack, raised garden and stone well.
- Olive tree, palm, limestone and loose log.
- Courtyard house, saw workshop, bed, table, bench and terracotta urn.
- The remaining reference building types: hay field, windmill, road, school, pantry, log shed, hay barn, mine camp, masonry and workshop.
- Food crate and water bucket carried by citizens.

The visual language uses clipped stone corners, bevelled timber, visible cut ends and joinery, faceted foliage, muted indigo/terracotta clothing, and illustrated 3D rendering: flat materials, antialiased shapes, and thin uneven contours with a separate readable UI. Ladders span their whole cell from lower edge to opposite upper edge. Residents approach from lower cell A, climb through ladder cell B, and leave onto elevated cell C. A and C must both have surfaces before the ladder connects them. With 2 m cells and 2.4 m levels, the slope is approximately 50 degrees. The internal `stairs` identifier remains compatible with existing saves. Access and water-port markers are included in the asset files.

Open `scenes/settlement/AssetGallery.tscn` and press F6 to inspect the kit. All 13 housing and industry building types can be queued, constructed, inspected and saved. Wells, crop plots and storage connect to the existing hauling loop. Houses, schools and workshops are constructible shells; room needs and production recipes are explicitly labelled as unimplemented in their menu descriptions. Beds and tables remain visual groundwork. Citizens use articulated rigid mesh pivots, not a skinned skeletal rig.

Regenerate the assets only when intentionally replacing their authored geometry:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/pyramida-assets.log --script tools/settlement/generate_assets.gd
```

The generator overwrites the corresponding TSCN/GLB outputs. Blender edits should be preserved separately or adopted into the generator/import workflow before regenerating.

## Verification

```sh
python3 tools/settlement/run_checks.py
```

The runner checks both exit codes and script-error output, because Godot can return exit code zero after a GDScript error. Set `GODOT_BIN` if Godot is installed elsewhere.

Coverage includes overlapping floors, both stair directions, removal/reconnection, competing resource reservations, actual upstairs delivery, resource conservation, harvesting and meals, a second storey, replacement-stair recovery, nearest stockpile selection, restocking, mid-delivery save/load, UI actions, persisted files, mesh normals, citizen pivots and asset anchors. It also runs the existing blueprint, OBJ-runtime, applied-labour, building-gameplay and Python Blender-codec tests.

On this Mac, the Metal backend intermittently omitted UI glyphs/icons in the expanded showcase; the same scene rendered correctly with Vulkan. The project therefore selects Vulkan on macOS while keeping Forward+ and the existing Windows driver choice. This is a verified workaround on the development machine, not a claim about all Metal hardware.

Rendered evidence is in `artifacts/terraces-prototype.png`, `artifacts/terraces-expanded.png` and `artifacts/asset-gallery.png`. These are engine screenshots, not concept art.

## Deliberate boundaries and next refactoring steps

This is a small build-and-logistics experiment. It does not yet implement room classification, utility-network simulation, lifts, structural stress, free rotation, editable voxel terrain, or survival penalties. Generated mountains, seasonal surface water and slowly replenishing wells are playable; food demand and tree regrowth are deliberately simple. Agents use small visual lane offsets rather than a full collision/queue simulation. The new map is bounded; the older world streamer has not been transplanted into it.

Only stairs can currently be demolished; other placements cannot yet be cancelled. Construction previews show progress counts rather than individual installed parts. These are follow-up interaction improvements before a larger content expansion.

Recommended next steps, in order:

1. Playtest placement, route readability and travel-time decisions. Adjust cell dimensions and citizen scale before producing a large asset library.
2. Add safe cancellation/demolition with explicit material recovery and support dependencies.
3. Generalise the explicit stair connector into stairs/lift/ladder traversal with occupancy and queues.
4. Add room volumes and furniture-based room capabilities using the existing asset access markers.
5. Implement one water network from the well's `WaterOut` to garden `WaterIn`. Compare hauling water against building infrastructure.
6. Bring streaming into the new model after save identifiers and multi-floor spatial ownership are stable.
7. Retire old coordinator sections only after their replacements have matching behaviour tests. Avoid another single script accumulating world, input, rendering and UI concerns.

## Performance and cargo asset update

Navigation now caches bounded source searches, architecture is reconciled incrementally, and ground tiles use a shared instance batch. See [measurements and validation](PERFORMANCE.md) and [the user-confirmed game references](DESIGN_DIRECTION.md).

Two additional original models, `food_crate` and `water_bucket`, are integrated into citizen carrying. Both have editable `.tscn` and `.glb` files in `data/settlement/`. Regenerate only these additions with `--script tools/settlement/generate_cargo_assets.gd`; this leaves the base building kit untouched. Render their preview with `--script tools/settlement/capture_cargo.gd` using a graphical Godot run. The resulting engine screenshot is `artifacts/cargo-assets.png`.

## Segmented living and dead trees

Trees now lose one visible trunk section for each of their three harvested logs, ending in a rooted stump. Living trees have green crowns and retain the 45-second regrowth cycle; dead trees have bare forks and do not regrow. Inspection shows remaining logs out of three, and picking bounds shrink after each cut. See [tree behavior, editable models and verification](TREE_ASSETS.md) and `artifacts/tree-harvest-stages.png`.

## Mountains and seasonal water

New settlements now generate seeded Perlin mountains up to ten blocks high, eroded terraces, a narrow canyon stream, small rain puddles, and a trail to the peak. Citizens carry collected buckets to storage. See [generation, collection, save compatibility and validation](WORLD_GENERATION.md).

## Earlier-app parity audit — 18 October 2026

The current entry point (`Startup.tscn` → `Terraces.tscn`) uses a separate vertical world model, scheduler, renderer and input coordinator. It did not migrate all behavior from `scenes/Main.tscn` / `scripts/main.gd`. The older app remains available. Shared foundations already included applied labour, gameplay timing settings, palette and localization.

| Existing behavior | Current integration |
| --- | --- |
| Ground-aligned north compass and reset view | Reuses `scripts/compass_widget.gd` directly, following the vertical camera's orientation and saved simulation daylight. Click restores the default angle and zoom at the current location. |
| Rotating day/night dial | Extracted the original dial into `scripts/day_night_widget.gd`; both apps now call the same widget. The vertical HUD also shows simulation minutes/seconds until the next dawn or dusk. Speed changes advance the same clock faster; menu suspension freezes it. |
| Select citizens and give jobs | The vertical model keeps its own saveable role API. Single selection, Shift-click, drag selection, dropdown group assignments and right-click work orders are covered by regression checks. Entity commands now use the clicked floor and include planned buildings; construction chooses reachable work surfaces. Explicit production roles no longer stop at automatic stock buffers. Storage capacity and material requirements still apply. |
| Streaming and editable terrain | The current settlement streams deterministic chunks and supports saved one-metre Dig/Fill surface edits. Exposed cube faces have thin contours; height changes update collision and navigation. |
| Older citizen command overlays and sleep behavior | Not fully migrated. The current role picker and autonomous child/needs system are distinct implementations. |

Before replacing another existing interaction, inspect its older implementation, reuse independent components, and test equivalent behavior against the vertical model. Do not assume a feature survived merely because its old script is still present. `legacy_features_test.gd` covers the restored controls, clock and compass alongside the existing simulation, save and multi-floor suites.

## Quiet settlement sound — 18 October 2026

`soundscape.gd` observes citizen travel, actual tree-cutting labour, saved rain state and the simulation clock. It owns no simulation state. Six soft sandy footsteps and five woody chopping impacts have random selection without immediate repeats, slight pitch/level differences, spatial panning and distance falloff. Children have a shorter stride. A bounded voice pool and real-time cooldowns keep large groups and 4× play from becoming excessively loud. Offscreen work does not crowd the mix.

Each ambience type and the bell has three original variations. Daytime wind arrives in occasional soft gusts while it is dry. Rain starts with separate droplets and blends over about three real seconds into a softened white-noise bed; droplets remain faint underneath. These beds loop with blended seams and stop when rain ends. Noon is phase 0.25 of the saved day (sunrise is phase 0), triggering one gentle bell. Loading a save, changing settlements or resuming a menu does not replay a missed bell. Menus and the structure editor silence game audio; game speed changes event timing without speeding up sample pitch.

The 23 original synthesized WAV assets are in `assets/audio/settlement/`; `tools/settlement/generate_audio.py` is the deterministic source, using only Python's standard library. Regenerate only when intentionally replacing the kit. Quiet mix constants are at the top of `soundscape.gd`. The existing gameplay action catalog references the same movement/chopping files; other legacy action-audio placeholders remain outside this addition.

`audio_test.gd` verifies distinct samples, non-repetition, movement and labour gating, rain transitions, day-only wind, noon crossings, reload/menu behavior, and actual quiet spatial output reaching the audio mixer.

## Citizen exploration and fog — 18 October 2026

The original persistent circular reveal algorithm is shared through `scripts/exploration_mask.gd`. Every citizen, including children, reveals a 10-metre neighbourhood as they move. Discovered land stays visible; camera motion reveals nothing. Sight uses horizontal world columns, so upper floors remain distinct for navigation but share exploration with the ground below. This is exploration fog, without line-of-sight occlusion or a second darkness layer over previously explored land.

`exploration.gd` owns the sparse half-metre discovery mask in simulation state. Saves store its cells, and older saves initialize discovery around current citizens and established construction. The camera uses a moving mask window, so discovery also works beyond the starting region as chunks stream in. Its texture changes only with new exploration, a different settlement, or a different camera window. Separate exploration revisions avoid rebuilding terrain as people walk.

`fog_view.gd` replaces the older flat fog plane with a depth-aware opaque contour over actual terrain, including hills and cliffs, using the original fog colour. Hidden resources, structures, water sources and scenery have no visible meshes or inspection colliders. Transparent plans in explored areas remain visible. The home screen's world preview stays fully visible and does not explore the playable world.

A right-click into fog gives selected citizens a movement order, never a hidden resource job; arriving reveals nearby land. Unexplored natural resources are excluded from automatic harvesting, and building previews require explored ground. Route overlays stop at unknown land. The interface gains no instruction panels or permanent text. `exploration_test.gd` covers discovery, persistence, migration, hidden commands, inspection, cutaway and switching worlds. Engine captures: `artifacts/fog-opening.png` and `artifacts/fog-explored.png`.

## Sand terrain tools — 21 October 2026

The two cube buttons beside the construction categories select **Dig** (minus) and **Fill** (plus). Left-click changes one 1 × 1 × 1 m grid cell immediately; the active tool remains selected for repeated edits. The translucent cube and its twelve-edge outline show the affected volume, and blocked edits use the existing warning colour. Escape or right-click returns to inspection. Tooltips carry the labels; the bottom instruction panel remains hidden.

`terrain_editor.gd` owns sparse `surface_edits`, independent of disposable meshes. Dig lowers an exposed column by one metre; Fill raises it by one metre. The first edit squares the shallow natural soil relief to the integer grid. Fill can target a pit's exposed inner wall when its floor is hidden by the isometric view; Dig can target an exposed side of the column's top cube. Only the current surface cube can change: tunnels, overhangs, floating cubes, sand physics and resource jobs are outside this implementation. Edited surface heights range from −36 to +36 m. Natural sloped cells, explicit terrain connectors, water sources, occupied footprints, construction plans and citizens reject editing. Fog and unloaded cells also block edits.

Changed columns replace walking surfaces and invalidate affected terrain chunks and neighbouring walls. Sharp exposed sand faces receive thin contours without changing their uniform sand fill. Equal-height adjoining cells retain a continuous surface. Terrain edits persist through autosave, reload, and chunk unloading; old saves default to no surface edits. The terrain edit and toolbar tests cover model changes, volume queries, picking, real input dispatch, collision, navigation, streaming and persistence.
