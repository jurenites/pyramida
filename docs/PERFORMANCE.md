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
