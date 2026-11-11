# Performance refactoring — 16 October 2026

## Changes

- Navigation builds one weighted shortest-path tree per source and reuses it for destination queries. A binary min-heap replaces the linear frontier scan. The cache holds at most 32 sources and is cleared on every topology rebuild, including stair removal. Routes returned to callers are independent arrays; unreachable targets also reuse the cached search.
- The world renderer reconciles entities by stable kind/cell or plan ID. Resource pickups update visible stock and progress text without destroying unrelated meshes, materials or picking colliders. A changed stair landing replaces only that platform's visual variant.
- Ground tiles share one `MultiMesh`, mesh and material. Per-tile colors retain variation. Static terrain, lighting and scenery now live in `scenery_view.gd`.
- Tree-crown and collider references are cached. Stockpile logs form a small reusable visibility pool. Route drawing reuses its `ImmediateMesh` resource. Cutaway visibility changes only when the selected level or mode changes; new nodes immediately inherit it.
- Food and water now use distinct original cargo assets. `generate_cargo_assets.gd` regenerates these models without overwriting the building kit.

## Measured scope

Godot 4.7.1, Apple M1 Pro, headless CPU benchmark. Baseline files were copied before this refactor. Measurements below are one comparative run; they are workload timings, **not overall FPS claims**.

| Workload | Before | After |
| --- | ---: | ---: |
| 160 route requests, one source, 40 destinations repeated four times, 1,681 cells | 2,328.069 ms | 16.687 ms |
| 40 inventory changes plus world-view sync, unchanged architecture | 198.654 ms | 6.086 ms |

Route distance checksums matched exactly at 6,544 world units. A separate earlier navigation run measured 1,480.797 ms vs 11.962 ms. Cold searches and many unique sources benefit less: the cached approach searches the whole reachable component on a miss. The fixed 32-source bound limits retained memory; the current prototype remains a bounded map, not a streamed world.

Run the current routing workload:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/settlement/benchmark.gd
```

For a comparison, preserve earlier scripts outside the checkout and pass `-- --baseline=/absolute/path/navigation.gd --view-baseline=/absolute/path/world_view.gd`. The script reports timings and checksums as JSON. Visual sync timings exclude initial scene setup and GPU rendering.

## Regression checks

`tests/settlement/navigation_test.gd` checks weighted routes against Godot's native AStar3D, cache isolation, bounded storage, negative results and topology invalidation. `tests/settlement/rendering_test.gd` checks persistent scene identity, stock presentation, landing replacement, cutaway picking, instantiated ground, cargo sockets and actual GLB parsing. The shared runner includes both alongside simulation, scene, building and legacy compatibility suites:

```sh
python3 tools/settlement/run_checks.py
```

See [the confirmed design direction](DESIGN_DIRECTION.md) for the intended room, utility, vertical construction, vegetation and spatial systems. Those future systems should preserve these simulation/presentation boundaries.

## Visual verification

The initial Forward+/Metal default-scene capture is preserved in `artifacts/refactor-preview.png`. Subsequent expanded-showcase verification found intermittent missing UI glyphs/icons with Metal on the development Mac; Vulkan rendered that scene correctly. The project now selects Vulkan on macOS while retaining Forward+. See [the playable guide](VERTICAL_PROTOTYPE.md) for this machine-specific workaround. The earlier default-scene capture does not establish Metal showcase compatibility.

All 10 suites in the shared runner passed after gameplay integration. The measurements above are headless CPU timings and do not compare graphics backends. The standalone cargo preview is `artifacts/cargo-assets.png`.

An explicit `--rendering-method gl_compatibility` override showed clipped terrain highlights in the integrated SubViewport scene; it is not the validated visual target. Use the project's default renderer when evaluating the art. Compatibility-renderer color parity remains follow-up work.

## Citizen freezes on streamed worlds — 18 October 2026

The earlier source cache still completed a full Dijkstra search on every cache miss. After half-grid terrain and streaming, a short trip could explore thousands of unrelated tiles. The simulation already uses 20 fixed ticks per simulation second; changing the rendering frame rate would not fix this search cost.

Navigation now retains an unfinished search frontier and advances it only until the requested destination is settled. Later destinations resume that same shortest-path tree. Road weights, deterministic tie ordering, diagonal clearance, ladders, and terrain connectors are preserved. Connectivity components reject unreachable islands and roofs without starting a search. Chunk additions merge components locally; removals and structural rebuilds recompute connectivity. Topology changes still invalidate route caches, and the 32-source memory bound remains.

Citizen goal selection and blocked-job retries share a budget of two decisions per simulation tick. The longest-waiting citizens take priority, including under constant world changes. Unsuccessful decisions wait approximately 1–1.2 simulation seconds; inventory, navigation, exploration, or hunger changes can wake them after a 0.25-second minimum. Full storage and disconnected deliveries use the same retry policy. Movement, labour, and needs continue on every fixed tick. Direct player orders bypass the autonomous decision delay, and committed routes clear retry state. Scheduling timestamps remain in the existing citizen save records; older saves use defaults.

One headless Godot 4.7.1 comparison on the development Mac, using the same six-citizen fixture for 60 simulation seconds (1,200 ticks, 8,281 walkable cells):

| CPU workload | Before | After |
| --- | ---: | ---: |
| Total simulation time | 2,236.839 ms | 244.621 ms |
| Worst simulation tick | 612.672 ms | 11.414 ms |
| Six cold nearby route requests, 10,202 surfaces | 1,018.290 ms | 3.822 ms |
| Six cold disconnected route requests | 1,192.915 ms | 0.007 ms |
| Full navigation rebuild, 10,202 surfaces | 25.888 ms | 41.234 ms |

Both simulations completed 13 deliveries and 6 meals. Local-route distance checksums matched at 22.970562 world units. These are CPU workload timings, not rendered FPS or a guarantee that all game stalls are eliminated. Connectivity adds work to full rebuilds; chunk additions use local component unions. Distant connected destinations can still require a large search. Initial world generation, rendering, autosaves, and GPU frame pacing are outside this benchmark.

Run the reproducible workload with:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/settlement/benchmark_citizens.gd
```

Optional `-- --baseline-navigation=/absolute/navigation.gd --baseline-model=/absolute/world_model.gd` compares preserved scripts. The baseline model must preload its preserved job system to compare both changes together. Preserve its other dependencies at the desired comparison revision when comparing across unrelated gameplay changes.

`tests/settlement/citizen_performance_test.gd` checks expanded-node bounds instead of machine-dependent timing thresholds, road costs against native AStar3D, incremental connectivity across bridge load/unload, decision budgets, 30-citizen fairness, immediate construction orders, continuous movement, and recovery from full storage without losing cargo. The tree reservation test allows two scheduler ticks for three citizens to claim work while retaining its resource-conservation and harvest-stage checks.

## Greenery and frame profiling — 20 October 2026

Grass was already an unshaded, camera-facing flat cutout with shadow casting disabled. The most obvious measured hitch was streaming: each new chunk rescanned soil-cut samples in every existing chunk. General inventory revisions also scanned every grass cell. These checks now follow terrain/soil revisions and chunk-local footprints. Existing grass buffers survive unrelated inventory and construction changes. Fog changes, levelling, new chunks, removal and switching worlds still invalidate the relevant views.

Unchanged entity visibility/picking and mature-tree scale no longer get written every frame. Streaming reuses its required-chunk set and skips pending-chunk sorting when its synchronous load budget is zero. Terrain connectivity reuses the cardinal slope checks when testing diagonals; route costs and path search behavior are unchanged.

Grass shares its blade vertices (15 instead of 27 per tuft) and converts its constant colour in the vertex shader. Density, triangles, wind, fog exclusion, footprint clearing and shadow settings are preserved. No new HUD or gameplay speed settings were added.

Godot 4.7.1, seed 1409, three starting citizens. Each rendered sample covers 180 frames after warmup, at the home, inland and shore camera positions. CPU frame work excludes engine/render submission and GPU time. Streaming is measured separately. These are individual development-machine runs, not a guaranteed FPS increase:

| Workload | Before | After |
| --- | ---: | ---: |
| Fields rendered CPU work, mean across three locations | 2.894 ms/frame | 1.636 ms/frame |
| Sand rendered CPU work, mean across three locations | 3.542 ms/frame | 1.738 ms/frame |
| Fields chunk view update, mean of three chunk arrivals | 80.523 ms | 23.857 ms |
| Sand chunk view update, mean of three chunk arrivals | 66.767 ms | 24.100 ms |
| Fields grass check on unrelated inventory revision | 2.343 ms | 0.034 ms |

Rendered elapsed times remained around 17 ms/frame; CPU savings do not translate directly into FPS on a paced display. GPU samples and timings vary with system load. New terrain geometry, grass uploads and navigation integration still cost time: Fields integration averaged 25.834 ms after the changes, so exploration can still hitch. Full raw comparison data is in [performance-2026-10-20.json](../artifacts/performance-2026-10-20.json).

Enable play-session diagnostics without adding UI:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --profile-performance
```

Every five seconds, the console prints a JSON summary and flushes it to `user://performance-<timestamp>.jsonl`. The console prints the absolute file path. On macOS the usual directory is `~/Library/Application Support/Godot/app_userdata/Pyramida/`. Logging is disabled by default.

Reports include mean/max CPU time and call counts for simulation, citizens, plants, economy, water, streaming integration, terrain, entities, grass, animation, visibility, fog, camera, HUD, hover, audio and autosave. They also contain frame mean/p95/max, simulation backlog, world size, engine physics time, draw calls and measured viewport CPU/GPU time. Scopes are nested and inclusive: do not sum parent and child totals. Renderer counters/GPU time are last-frame samples; zero on a headless or unsupported renderer is not evidence that rendering is free.

Reproduce the workloads from the project directory:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/pyramida-cpu.log --script tools/settlement/benchmark_frame.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . --log-file /tmp/pyramida-render.log --script tools/settlement/benchmark_frame.gd -- --rendered
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/pyramida-scenery.log --script tools/settlement/benchmark_scenery.gd
```

These tools use generated worlds and do not load or modify player saves. The rendered benchmark also saves a verification image to `/tmp/pyramida-performance-grass.png`. Run benchmarks sequentially without other test processes for more useful comparisons.

Validation passed: the new scenery-cache regression, chunk visuals, chunk persistence, soil surfaces/collisions, Greece generation/save/menu, day cycle and slope navigation. A logging smoke check verified JSON output, flush, reset and disabled behavior. Rendered frames were inspected for the grass appearance. Two carrier-recovery assertions in `citizen_performance_test.gd` and four roof-ray assertions in `runtime_test.gd` fail in both the preserved pre-change checkout and this version; they remain separate existing failures.

## Construction selection and established-world stalls — 6 November 2026

The reported triggers were selecting a building to construct and citizens starting path searches. Replaying the latest local settlement (three citizens, ten buildings, two plans, 132 loaded chunks and 33,792 ground cells) reproduced both. Player saves were read only; write measurements used scratch copies.

### Confirmed construction-mode cause and fix

`world_view.gd` treated entering/leaving construction mode like changing the asset library: it freed **every entity view**, then regenerated all trees, rocks, bushes, buildings and picking bodies. Only construction sites need to switch between staged geometry and a finished preview. Planning changes now replace only `plan:` views; normal reconciliation still handles merged platforms and roof coverage. Appearance edits still invalidate all assets.

A sequential headless Godot 4.7.1 run on Apple M1 Pro measured:

| CPU operation in the saved world | Before | After |
| --- | ---: | ---: |
| Select House for construction | 1,438.438 ms | 50.332 ms |
| Return to Inspect | 1,485.665 ms | 52.611 ms |

These are single-operation CPU timings, not rendered FPS. Switching still reconciles the world and can miss a frame; it no longer reconstructs the whole landscape.

### Other rendering work fixed

Inventory reconciliation reset fog-hidden entities to visible and restored picking, only to hide them again in the visibility pass. It also reset every entity's transform before positioning it again. The visibility pass now owns visibility/picking, and unchanged positions and rotations remain untouched. Plan IDs still update their cell/picking metadata when retargeted.

Mature trees and bushes no longer participate in per-frame growth updates. They synchronize on model revisions, while growing seedlings remain in small animation lists; maturity applies the final scale and leaves the list. Harvesting continues to refresh tree sections.

A separate rendered Vulkan replay, 180 frames per phase after warmup, measured the general rendering changes before the construction-mode fix:

| Mean script CPU work per frame | Before | After |
| --- | ---: | ---: |
| Paused settlement | 9.305 ms | 4.164 ms |
| Normal speed | 13.000 ms | 6.872 ms |
| 4× speed | 20.563 ms | 9.335 ms |

Normal-speed observed maximum frame time fell from 360.322 to 218.868 ms; 4× fell from 585.220 to 97.641 ms. These short samples are not guarantees: CPU work, display pacing and GPU measurements differ, and unrelated system load affects timings. Streaming was disabled for stable comparison.

### Remaining measured stalls at the initial investigation

The saving and navigation follow-up below addresses the first two findings.

- **Synchronous path searches:** in the normal-speed headless replay, 23 uncached search advances took 171.967 ms total; the worst citizen tick took 187.580 ms. Individual search advances peaked at 15.289 ms. The two-decisions-per-tick scheduler does not bound the number of route queries inside a decision. Source/destination comparisons can run multiple searches in one tick. `navigation.search` now exposes this cost in opt-in performance logs. A future fix needs a work budget for route requests/search expansion, while preserving route costs, reservations and direct orders.
- **Synchronous autosave:** the scratch first write took 243.770 ms and the subsequent backup-preserving write took 562.117 ms. Periodic saves and explicit build/command saves still use the synchronous path, including snapshot creation, encoding, validation of the previous save and disk IO. These stalls are not fixed by the renderer changes.
- **Grass reveals:** fresh-game rendered samples also showed grass updates around 37 ms. Streaming, terrain generation and large navigation rebuilds remain outside the stable saved-world frame comparison.

Raw measurements: [performance-2026-11-06.json](../artifacts/performance-2026-11-06.json). Reproduce against any slot without writing to it:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/settlement/benchmark_saved_world.gd -- --save=/absolute/path/to/slot.json --construction --measure-save
```

Omit `--headless` and add `--rendered` after `--` for rendered frame timing. `--measure-save` writes only a unique temporary slot and removes it afterward. The replay pauses for construction switches, then runs sequential paused/normal/4× samples with fixed simulation steps. Opt-in `view.reconcile.*` scopes separate entity categories.

### Validation for this change

Passed: `scenery_performance_test` (including new no-visibility-churn, seedling-growth, harvest and construction-toggle identity checks), `construction_planning_test` (1,078 checks), `rendering_test` (56 checks), `timber_motion_test`, `timber_continuity_test`, `chunk_visual_test` and `navigation_test`.

Broader checks were not all green: `planting_test` failed “Grass is physically cut, carried and stored”; `citizen_performance_test` failed the two carrier-recovery assertions also noted in the 20 October performance investigation above; `relocation_test` exceeded a 180-second limit without reporting results. No pathfinding algorithm, simulation, save format or autosave behavior was changed in this investigation. Those failures/timeouts remain unresolved; the passing targeted checks do not establish that the entire project suite passes.

## Background saves and retained journeys — 6 November 2026

The confirmed saving policy is now five real-time minutes during gameplay, plus fresh saves on menu return, settlement switching and exit. Construction actions and focus changes no longer save. Periodic saves copy a consistent snapshot on the main thread, then encode, preserve the backup and write on a worker thread while gameplay continues. Inventory identities, reservations, labour progress and route arrays are frozen with the snapshot. Menu/exit writes wait for any periodic write and then save the latest state; deletion drains the writer so a late write cannot recreate a deleted slot. The version-5 save format is unchanged.

The graph was already shared and citizens already retained routes. Two avoidable invalidations are removed: blueprint edits no longer rebuild navigation, and streamed terrain invalidates only cached searches whose visited cells or tentative frontier touch the affected area. Unfinished blueprints remain passable, including planned platform merges. Platform merge work waits while a citizen occupies or is stepping onto the lower deck that completion will remove. Actual construction completion and terrain/structure changes still update navigation. Citizens check their next edge and detour if it becomes blocked; a new player destination replaces their route.

The worst measured citizen tick came from testing pairs of perimeter access cells around solid buildings, including a building-to-itself query. Search now stops immediately for a zero-length connection and skips pairs whose horizontal distance cannot improve the best physical route already found. This preserves the existing route comparison and road-weighted search behavior.

Sequential headless Godot 4.7.1 runs replayed the same saved world for 400 ticks of 0.05 simulation seconds, replacing only navigation with the preserved pre-change version for the baseline:

| Replay measurement | Before | After |
| --- | ---: | ---: |
| Maximum simulation tick | 190.423 ms | 26.231 ms |
| 95th-percentile simulation tick | 17.100 ms | 2.412 ms |
| Search advances | 43 | 15 |
| Nodes expanded | 6,671 | 962 |
| Total measured search time | 221.714 ms | 32.863 ms |

Both replays produced the same final snapshot SHA-256. These are simulation CPU measurements, not rendered FPS or a guarantee for every destination. Long uncached searches and actual topology rebuilds remain synchronous; bounded search work remains a possible next step if profiling finds further spikes.

Two scratch background writes measured 72.005 / 54.492 ms for main-thread snapshot capture and 294.514 / 589.679 ms total completion time (first write / backup-preserving write). The main loop advanced 25 / 66 frames while the worker was running. Snapshot capture can still miss several frames on this large world; moving encoding and disk work off-thread does not make capture free. No player save was modified.

Raw results: [performance-2026-11-06-save-navigation.json](../artifacts/performance-2026-11-06-save-navigation.json). Reproduce with:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/settlement/benchmark_journeys.gd -- --save=/absolute/path/to/slot.json --measure-save
```

The optional `--baseline-navigation=/absolute/path/to/preserved/navigation.gd` runs the same replay with an earlier navigation implementation. Save measurements use a unique temporary directory and remove it afterward.

Validation passed for background saving, retained journeys, weighted navigation/cache behavior, construction actions, loading/exit, slot deletion, menus, Greece save/load, slopes, chunk streaming and the room editor. The platform-tier regression also verifies that an unfinished merge remains walkable and waits for residents on or entering its lower deck. The two previously documented carrier-recovery assertions in `citizen_performance_test.gd` still fail; this is not a fully green project suite.

## Final-log and salvage cleanup stalls — 7 November 2026

The generated six-citizen benchmark reproduced a roughly 570 ms simulation tick. Per-tick scopes identified two full-map navigation rebuilds: chopping the final log of a tree, and deleting an emptied salvage pile. Neither operation needs to reconstruct the loaded world's terrain graph.

Final-log removal now refreshes the cleared cell and its eight neighbours, restores existing connector edges, joins the affected connectivity components and invalidates only searches touching that area. Streaming and tree clearance share the edge-refresh and component-union helpers. Terrain data and distant searches remain intact. Overlapping legacy objects and connector endpoints whose links may have been omitted retain the full rebuild fallback, so clearing a tree cannot erase another object's blocker or leave a ladder disconnected. Empty salvage cleanup changes the model revision without rebuilding navigation; the structure was already removed at dismantling completion.

The citizen performance suite's six failures were stale fixtures/expectations: first-tier Houses now need Hay as well as Logs, anonymous legacy piles accept no new deliveries, and full storage deliberately leaves recoverable goods on the floor. Tests now supply the current House recipe and verify bounded idle retries, cargo conservation, wakeup after storage space opens, physical recovery and unchanged navigation during empty-pile cleanup. New cases compare local clearance against a full rebuilt graph, preserve distant search caches, invalidate newly shortened detours, retain ladder/ramp/bridge edges and protect overlapping obstacles.

Sequential headless Godot 4.7.1 runs used seed 1409, six citizens, 9,227 navigation surfaces and 1,200 fixed 0.05-second ticks. The baseline preserved the previous navigation, model and deconstruction implementations. Both runs normalize cloned citizens' household allocations before timing, and produce the **same full saved-state SHA-256**, 19 deliveries and six meals.

| Simulation CPU measurement | Before | After |
| --- | ---: | ---: |
| Maximum tick | 570.008 ms | 65.683 ms |
| 99th-percentile tick | 38.380 ms | 22.514 ms |
| Total work over 60 simulated seconds | 4,453.701 ms | 2,135.946 ms |
| New cached source searches | 56 | 46 |

These are development-machine CPU timings, not rendered FPS. Long uncached path searches still dominate the remaining spikes; general topology rebuilds, streaming integration, grass reveals and main-thread save capture remain separate work. No path-search algorithm, job policy, save format or UI changed.

Raw results, source fingerprints and validation: [performance-2026-11-07-simulation.json](../artifacts/performance-2026-11-07-simulation.json).

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/settlement/benchmark_citizens.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/settlement/benchmark_citizens.gd -- --profile-ticks
```

The optional `--profile-ticks` reports inclusive scopes for the five slowest ticks. The benchmark also reports a saved-state checksum; snapshot encoding is outside the measured simulation loop. The existing baseline-script arguments remain available. It generates its own world and does not read or write player saves.

Passed: citizen performance, weighted navigation, retained journeys, slope navigation, chunk streaming, citizen reassignment, stump removal (including final-log save/load and view cleanup), and background saving. `git diff --check` passed for the changed implementation and tests. The broader deconstruction suite still fails on legacy fixtures, including an unbuildable Pantry followed by access to its missing inventory; that first failure was reproduced with the preserved pre-change model/navigation/deconstruction code. The rest of that suite was not established as passing, and the full project suite was not run. The updated focused cargo-recovery regression and existing citizen-reassignment suite cover salvage cleanup for this change.
