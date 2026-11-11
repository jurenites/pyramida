# Town — Semi-Infinite World, Streaming, and Persistence

Status: current surface-streaming summary plus an explicitly planned persistence model. Code and passing tests are authoritative.

Only the “Implemented surface milestone” list below describes current behaviour. Sections describing disk saves, vertical columns, biome latitude, Forecast rings, and outside settlements are future contracts, not existing systems.

The original 64×64 generated layout remains the origin regression fixture, but it is no longer a movement, camera, fog, grass, ground, or navigation boundary.

Implemented surface milestone:

- Deterministic versioned generation addressed by signed integer chunk coordinates.
- 16×16 World Unit ground and fog chunks loaded within the current fixed presentation radius around Citizens and the camera.
- No horizontal Citizen or camera clamp.
- Navigation limited to the connected loaded-chunk component instead of a world-sized rectangle.
- Per-chunk fog images with persistent sparse discovery coordinates.
- Per-chunk grass candidate creation and disposal.
- Deterministic resource entities outside the origin fixture.
- A persisted `world_generation_profile.json` identity containing the seed, immutable generator version, algorithm identifier, chunk size, and reproducibility fingerprint.
- Generator version 2 uses a stable SHA-256 coordinate avalanche plus fixed-point seeded habitat fields, removing the diagonal resource bands produced by the earlier linear coordinate formula without making permanent placement depend on CPU floating-point rounding.
- Distant chunk unloading, regenerated untouched entities, in-memory state overlays for changed entities, and removal tombstones.
- Sparse runtime Landscape deltas for authored Soil Blocks and removed implicit base cubes, without allocating full `16×16×256` voxel arrays.

The generation identity is persisted, but the changed-world state overlay is still runtime-only. Landscape edits remain materialized for the current session and are not yet unloaded with distant chunks. The current `Quit` button exits without serializing chunk deltas; there is no complete Save-and-Quit implementation yet.

This document defines a horizontally unbounded world with a fixed vertical range. The player does not choose a map width when starting a game. The explored world becomes only as large as the player makes it through Citizen movement.

## 1. Coordinate contract

Design discussion names the axes by meaning:

```text
east     horizontal east/west coordinate
north    horizontal north/south coordinate
height   vertical coordinate, from 0 through 255
```

Godot maps these values as follows:

```text
design (east, north, height) → Godot Vector3(x, y, z) = (east, height, north)
```

World persistence must not rely on floating-point positions as identity. A World Unit, Sub-Unit, chunk, entity, or terrain change uses integer coordinates and a persistent ID.

The horizontal coordinates use signed 64-bit integers. The game is therefore practically unbounded east, west, north, and south while remaining compatible with finite files, finite memory, and finite play time. Height is deliberately bounded to 256 World Units.

## 2. Biome latitude

Biome is primarily determined by the north coordinate. East/west travel may vary local terrain inside the same broad latitude, but does not reverse the climate order.

From far north to far south, the order is:

```text
Northern Snow / hard
Northern Greenery / easy
Central Sand / normal
Southern Greenery / easy
Southern Snow / hard
```

The Snow regions continue outward indefinitely. The Sand and Greenery bands have configurable widths in the world-generation profile. Boundaries are transition regions rather than perfectly straight lines: deterministic low-frequency noise may move the local boundary north or south while preserving the global order.

The starting position belongs to the Central Sand band. Exact band widths, transition widths, resource tables, and temperature rules remain tuning data rather than save-format assumptions.

## 3. Horizontal chunks and vertical columns

The world is divided into horizontal chunks. A provisional chunk covers 16×16 World Units across east/north. The chunk size is configuration owned by the generator profile and must be fixed for an existing save.

A chunk is an address and a streaming unit, not proof that all of its terrain exists in memory. Each horizontal cell in a chunk identifies a vertical column from height 0 through 255.

Three different states must remain separate:

1. `Known by seed`: the game can reproduce the base result for a coordinate.
2. `Discovered`: a Citizen has revealed the horizontal area to the player.
3. `Materialized`: simulation or rendering currently needs concrete terrain or entities in memory.

An undiscovered or unloaded chunk consumes no scene nodes and needs no full voxel array in the save.

## 4. Deterministic base world

The untouched world is a pure query:

```text
base value = generator(world seed, generator version, integer coordinate, query kind)
```

The generator must support random access. Generating one chunk must not depend on which neighbouring chunk was visited first or on a shared random-number stream. Separate salted deterministic queries select biome variation, surface height, geology, vegetation, water, city candidates, and permanent visual detail.

A world identity record is created at the beginning and records the world seed, generator version, algorithm identifier, chunk size, and a short fingerprint. Released generator versions are immutable for existing saves. A later generator may be used for new games, but loading an old game must preserve its old base world. QA can reproduce the base world from this identity without copying every untouched entity into the save.

Generated terrain and entities are not copied into the save merely because they were rendered. The save owns only discovery state, persistent simulation state, and differences from the generated base.

## 5. Discovery at every height

Fog discovery is horizontally driven. A Citizen moving north, south, east, or west reveals new horizontal territory whether the Citizen is at height 1, 150, or 255.

The current four-World-Unit reveal radius is stored on the 0.5×0.5 Sub-Unit grid and partitioned by chunk instead of one world-sized texture. The running session currently keeps sparse revealed-cell Dictionaries; compressed masks and all-visible sentinels are planned disk-format optimizations, not implemented storage.

Horizontal discovery does not mean complete underground knowledge. It allows the game to generate and show the surface, open air, and other features that are visibly exposed from the discovered area. Covered underground cells remain unmaterialized and absent from the save until digging, a cave opening, a cutaway view, or another later visibility rule exposes them.

If an underground cell is first exposed on Day 200, its untouched base material is generated from the original world seed and coordinate. World age may affect entities or processes, but must not silently change the coordinate's original geology.

## 6. Planned sparse save model

The save is a sparse overlay over the deterministic base world. It does not contain a rectangular copy of every explored chunk and does not contain untouched hidden underground voxels.

The save header contains at least:

- Save-format version.
- World seed and immutable generator version.
- Outside-settlement simulation-rule version.
- Generator profile, including chunk size and biome-band parameters.
- Current authoritative simulation tick and Day.
- Persistent ID allocator state.

Per discovered chunk, save only the applicable records:

- Compressed binary discovery mask.
- Terrain deltas: excavated, placed, replaced, or otherwise changed cells.
- Persistent entities whose current state differs from the base result.
- Player-created entities, Buildings, loose resources, jobs, reservations, and ownership state.
- Removed generated entities as tombstones so a harvested Tree does not return after loading.
- Coarse outside-settlement state and its last simulated tick when that region has entered simulation.

An empty discovered surface with no changes therefore costs approximately one compressed discovery mask and one chunk index entry, not 16×16×256 voxel records.

Generated grass blades, cloud positions, bird flock formations, and other presentation-only detail are rebuilt rather than saved. If birds later gain persistent nests, injuries, ownership, cargo, or other gameplay state, those particular entities cross the boundary into sparse persistent data.

## 7. Planned disk-save lifecycle

Normal loading needs the current authoritative state, not every action since Day 1. The persistence path uses:

1. A compact snapshot containing the sparse state described above.
2. A short append-only change journal written after the snapshot.
3. Periodic compaction that folds the journal into a new snapshot only after the new file has been verified.

This preserves recent changes safely without making every save grow forever. A complete lifetime replay or player-visible historical chronicle is a separate optional feature; it must not be required to load an ordinary game.

A save operation writes to a temporary file, validates its header and chunk index, then atomically replaces the previous primary save while retaining at least one recoverable previous snapshot.

## 8. Planned streaming rings

Streaming uses multiple configurable distances around relevant Citizens rather than one `loaded/not loaded` boundary:

| Ring | Purpose | Typical state |
|---|---|---|
| Presentation | Rendered terrain, entities, animation, and audio | Concrete scene nodes and meshes |
| Detailed simulation | Citizens, jobs, collisions, construction, and exact local processes | Full authoritative entity state |
| Coarse simulation | Nearby outside settlements and slow regional processes | Aggregated ledgers and scheduled events |
| Forecast | Prepare chunks or settlements before a moving Citizen can reach them | Asynchronous generation/materialization queue |
| Dormant | Everything farther away | Seed only, or a saved coarse summary if previously activated |

The initial outside-settlement coarse-simulation radius is provisionally 100 World Units. This is a tuning value, not a constant embedded in the save format.

The Forecast ring must be larger than the Presentation ring. It predicts required chunks from every Citizen's position, current route, and maximum travel speed. Generation and loading are queued before entry. A Citizen may not enter an unready chunk; if preparation falls behind, simulation slows or pauses at the safe boundary rather than exposing missing terrain or inventing nondeterministic data.

## 9. Planned outside settlements and world age

The seed may define potential outside-settlement sites without instantiating every city in the infinite world. A site begins detailed or coarse simulation only after entering the configured simulation or Forecast ring.

The system must distinguish:

- `Base site`: immutable seeded location and starting conditions.
- `Coarse state`: population/resource/construction summaries at a recorded tick.
- `Detailed state`: concrete Citizens, Buildings, inventories, and jobs needed near the player.

On first activation, a site's coarse state catches up from its seeded founding tick to the current authoritative world tick. Catch-up uses deterministic aggregate time steps rather than replaying every Citizen action from every survived Day. The result must depend on the site seed, world time, simulation-rule version, and any previously saved interaction—not on frame rate or how quickly the player travelled there.

Coarse simulation then advances periodically under a fixed work budget. It does not run once for every infinite site and does not wait until the player crosses the city boundary. The Forecast ring activates and catches up candidate sites early enough that their state is ready before presentation. If forecast work cannot finish in time, the safe-boundary rule from section 8 applies.

When a previously simulated region is far away, detailed state may be reduced to a validated coarse summary plus exceptional persistent entities. Restoring detail must produce a state consistent with that summary; it must not reroll the settlement from the world seed.

The exact decisions made by outside settlements, their construction rules, and whether the player can disable or change their simulation are deliberately deferred. This document defines when and how their state is prepared and persisted, not their behavioural doctrine.

## 10. Planned configuration boundaries

The following values belong in named world-streaming and simulation profiles so later playtests can change them without rewriting persistence code:

- Horizontal chunk width.
- Surface discovery radius.
- Presentation, detailed-simulation, coarse-simulation, and Forecast radii.
- Maximum chunk generation work per frame or simulation tick.
- Coarse simulation cadence and work budget.
- Sand, Greenery, Snow, and transition-band widths.
- Save-journal compaction threshold.

Values that affect generated base truth are copied into the save's generator profile and cannot change mid-playthrough without migration. Performance values such as render distance and per-frame work budget may change at runtime.

## 11. Next implementation milestone

The first build slice is complete:

- Introduced 16×16 horizontal chunk addresses and ownership.
- Added a versioned, random-access world seed query.
- Streamed a small surface-only chunk ring around every Citizen and the viewed area.
- Removed the fixed Citizen and camera boundary while keeping unready gaps non-navigable.
- Partitioned fog discovery, grass, and navigation by loaded chunks.
- Kept the existing 64×64 generated layout as the origin regression fixture.

Underground materialization, outside-city behaviour, and complete save-journal compaction are not prerequisites for proving this first semi-infinite traversal slice.

### 11.1 Remaining implementation sequence

1. Persist the existing runtime terrain/entity deltas and tombstones to disk, with save/load round-trip tests.
2. Add snapshot validation, a short journal, atomic replacement, and previous-save recovery before introducing Save-and-Quit.
3. Add biome latitude and transition generation.
4. Add underground materialization only when cells become visible.
5. Add configurable simulation and Forecast rings with placeholder outside-settlement summaries before implementing city behaviour.

## 12. Target acceptance checks

1. Travelling east for 1,000 World Units does not allocate a 2,000-World-Unit-wide rectangular world.
2. Visiting chunks in different orders produces byte-equivalent base generation for the same seed, generator version, and coordinates.
3. A Citizen moving horizontally at heights 1, 150, and 255 expands discovery and streaming by the same horizontal rule.
4. Revealing a surface does not serialize all 256 cells below each revealed column.
5. Digging into an untouched cell after many Days produces the same base geology as the same seed and coordinate in a fresh diagnostic query.
6. Removing a generated Tree, saving, unloading, and loading does not respawn the Tree.
7. Building in one cell stores the change without serializing unchanged neighbouring cells.
8. An explored but unchanged empty chunk has a small bounded save cost.
9. A future outside settlement is prepared in the Forecast ring before it becomes visible.
10. Changing presentation distance or simulation work budget does not change generated world truth.
11. A failed or interrupted save leaves either the prior valid snapshot or the new valid snapshot recoverable.
