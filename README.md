# New experiment: Block City

Select **Block City Demo → Run** in Godot Project Manager (import `demos/block_city/project.godot` once on other machines), or run `./tools/block_city/play.sh`, for the separate coloured-box city-building demo: small flat pieces with editable draw weights, a 3×3 lot with supported overhangs, direct pole-to-floor hanging wires and an Escape menu. Building types and the economy are deferred. The existing Pyramida startup and saves are unchanged.

See the [play guide, design, shape table and market evaluation](docs/block_city/README.md). Run `python3 tools/block_city/run_checks.py` for its focused checks. In Godot, open `scenes/block_city/BlockCity.tscn` and press F6.

---

# Peaceful Pyramida foundation

The playable settlement now has a working food and materials economy: berries, irrigated grain, bread milling, plank sawing, limestone mining and masonry. Houses support population growth; schools, workshops, pantries and roads have simulation effects. Select or box-select adults, assign jobs in the inspector, or right-click resources and workplaces. No alien storyline, enemies or weapons are active.

Trees, dead trees and palms disappear when the final log is harvested, freeing the ground immediately. Partial trunks remain harvestable; no decorative stumps remain. Older stumps are cleared when saves and map chunks load.

The current visual direction uses featureless citizens, flat colour shapes, and a full-resolution antialiased world with fine irregular outlines. The world stays 3D; an illustrated material and edge pass replaces the reduced-resolution pixel look. Day/night tint affects the world while the interface remains sharp.

Read [the reference research, source links, exact scope and play guide](docs/PYRAMIDA_RESEARCH.md). New recipes are prototype tuning, not claims about the original game's exact numbers. Existing saves migrate, including old timber-only plans. **V** inspects and **Esc** clears selection and cancels placement without saving or leaving play. Play continues at **1×**, **2×**, or **4×**; Space does not pause.

Run `python3 tools/settlement/run_checks.py` for the regression suite. `tools/settlement/verify_progression.gd` tests the full economy from the normal starting inventory through village construction and dressed-stone production.

---

# Vertical settlement prototype — v0.1.0

**F5 opens the settlement selector.** Choose an empty slot and Normal difficulty, or continue an existing settlement. **Esc** clears selection and cancels placement; progress saves automatically and Settings contains only fullscreen and route visibility. New settlements start with one Stockpile (18 timber and 5 food), two adults and one child. There are no prebuilt terraces, stairs, wells, gardens or queued buildings. Adults carry resources and construct what you place; the child wanders and eats independently, cannot be selected for work, and becomes an adult after three simulation days. Growth and clothing survive saving. Citizens have slimmer rounded bodies, short pill-shaped limbs without fingers, heads without facial features, and solid-color shorts, dresses, top-and-skirt outfits or one-shoulder robes. The scene uses a 33-model 3D kit with articulated citizens and editable GLB exports. The compact peach build menu follows the supplied Figma reference and includes 13 housing and industry building types, plus platforms, stairs, stockpiles and gardens. Placement snaps to ground, decks and completed roofs across a 41 × 41 cell world.

Press **F2 / Blueprints** for the [unified asset editor](docs/STRUCTURE_WORKSHOP.md): edit primitives, component parts and prefabs, set occupied grid volumes and overlap margins, and exchange GLBs with Blender.

See [the playable guide, architecture and refactoring notes](docs/VERTICAL_PROTOTYPE.md). Open `scenes/settlement/AssetGallery.tscn` with F6 to inspect the new models. Open `scenes/settlement/BuildingShowcase.tscn` with F6 for a worked settlement with stacked houses, a windmill, a shed and fields, constructed through the real hauling simulation. Run `python3 tools/settlement/run_checks.py` for the focused simulation, scene and compatibility checks.

Edit [game_settings.cfg](game_settings.cfg) in the project root for game tuning. One file contains named sections for general settings, construction, gathering and production, followed by the older prototype's settings. All time values use simulation seconds, written with a decimal point (`3.0`, `360.0`); item counts stay integers (`1`, `12`). Multiplier settings use percentage changes: `+50%` means 1.5×, `0%` means unchanged, and `-90%` means 0.1×. Write a percentage as the entire unquoted value; references to it use the resolved multiplier. Existing numeric multipliers remain supported. Values support arithmetic and references, such as `berry_regrowth_seconds = day_seconds * 2`; local names, general constants and qualified names such as `general.day_seconds` work regardless of line order. Change values, save and restart the game. Comments explain units and examples. Future exports must include `game_settings.cfg` in Godot's non-resource export filter.

The earlier prototype remains in `scenes/Main.tscn`. The documentation below describes that older scene; it is retained for migration reference.

---

# Foundation Prototype

A clean-room, peaceful vertical-settlement prototype built in Godot 4.7.1.

It is not a finished game or a reuse of Sokpop's code or art. The current slice proves the core physical loop with original Blender-editable prop meshes, citizens, renewable bushes, trees, desert resources, physical logs, carrying, and four-log support construction.

This README describes current runtime behaviour. When documentation and code disagree, code and passing tests are authoritative; future design belongs in explicitly deferred sections.

## Run

Open [project.godot](project.godot) in Godot 4.7.1 and press **F6** or **F5**.

## Test

Run the content contracts headlessly:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --log-file /tmp/pyramida-content-contract.log --path . --script tests/content_contract_test.gd
```

Run the reusable labour contracts headlessly:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --rendering-driver dummy --log-file /tmp/pyramida-applied-labour-test.log --path . --script tests/applied_labour_test.gd
```

Run the Citizen command-overlay contracts headlessly:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --rendering-driver dummy --log-file /tmp/pyramida-citizen-command-overlay-test.log --path . --script tests/citizen_command_overlay_test.gd
```

The suite requires English wording for every UI text key and every registered
Citizen action, plus at least one loadable audio stream for every action. The
audio contract still identifies unfinished legacy action categories. Movement and
chopping now have original variations; the vertical settlement also has quiet
wind, rain and a noon bell (see `docs/VERTICAL_PROTOTYPE.md`).

## Controls

- Click a citizen to select it and enter Citizen Mode. Citizens have selection priority over overlapping resources. Selection uses an exact two-pixel solid white screen-space circle projected from a 16-sided world circle whose radius is 66% of the previous selection radius (`0.3168` instead of `0.48` World Units). Citizen Mode remains active while at least one Citizen is selected and provides the context for movement and work assignments; a dedicated Citizen task menu remains deliberately unresolved.
- Left-drag a rectangle to select every citizen inside it. A single selected Citizen has no count badge; the red RTS count badge appears for groups of two or more. A one-digit badge is exactly 18×18 and circular; larger counts retain the 18-pixel height and circular end caps while expanding only horizontally. Right-clicking routes every selected Citizen independently into a compact slot inside the same clicked World Unit, with a distinct compact lane through intermediate World Units so two Citizens never deliberately share one walking coordinate.
- Left-click revealed ground to deselect citizens and select that surface World Unit with one continuous white rectangle around its top surface. Selecting a non-Citizen world object draws separate four-edge white frames around the top and bottom of its visible bounds. Vertical connecting bars are intentionally hidden.
- With one or more citizens selected, right-click a living Tree, Dead Tree, or Palm to assign persistent Woodcutting. Each remaining Log segment is one independent resumable work slot: `Tree 3/3` can accept three Citizens, `Tree 2/3` can accept two, and `Tree 1/3` can accept one. Every assigned Citizen walks to a distinct available side, takes an axe from their pocket, and performs exactly three visible chops over three seconds. Each completed slot removes one top segment and drops one faceted physical Log. The completing Citizen picks up that Log, returns it to the starting Pile, then chooses the nearest visible Tree with a free segment. If the selected group exceeds the clicked Tree’s available slots, overflow Citizens choose the nearest visible Trees with free segments. Interruption preserves that segment’s elapsed labour, leaves its bar visible for two simulation seconds, then hides it until an actor resumes the same slot.
- Every applied-labour job uses one 8-pixel-high horizontal, left-to-right world bar: a 4-pixel coloured interior plus the shared two-pixel cursor-width outline above and below. Its corners are subtly rounded. The coloured fill is clipped to that interior and the white outline is drawn last, so progress never covers the border. The complete bar tilts around its centre by up to two degrees toward the screen side occupied by the directional sun, reversing its lean as the sun crosses to the opposite side. Width represents required labour at eight pixels per second: three seconds uses 24 pixels and six seconds uses 48 pixels. Longer work therefore has a proportionally longer bar rather than reusing one bar shape with a slower fill.
- Right-click a berry bush to assign persistent gathering with the same applied-labour bar used for tree cutting. The Citizen harvests one `Calories`, visibly carries three red berries to the Pile, stores them, and chooses the nearest visible harvestable Bush. The green harvested Bush remains in the world and restores its berries after two game days: 720 simulation seconds, or 720 real seconds only at `1×` speed.
- The open Pile cannot store Water. Right-clicking a cactus currently reports `Water needs a vessel` and leaves the cactus untouched until pottery, a bottle, or another Water vessel exists.
- Right-click ground to move the selected citizen. The citizen walks through World-Unit centres using all eight surface neighbours, including diagonal connections. Trees, Dead Trees, Palms, and Stumps retain pointer interaction but do not block Citizen movement. A Cactus is also passable, while its high routing cost makes A* prefer a reasonable route around it. Limestone and player-authored Soil Blocks are hard blockers; the implicit generated Sand surface remains walkable. Future Warehouse Doors are passable while their three invisible wall faces are hard blockers. The movement preview reads as `O-------●`: the selected Citizen's two-pixel selection circle, one uninterrupted two-pixel white screen-space line projected from the world route, and one destination dot. Intermediate navigation nodes have no dots. Projecting one joined polyline after routing prevents diagonal segments from becoming dashed depth-rendered patches. A blocked, disconnected, unknown, or outside target normally resolves to the closest reachable World Unit. A Citizen whose starting World Unit has no legal exit instead waits two simulation seconds and uses an explicit emergency route that may phase through the surrounding obstacle; this guarantees eventual recovery without making ordinary walls optional during normal pathfinding.
- Work orders produce a compact white icon bubble above the assigned citizen: a Log for Tree work, berries for Food, a Water drop for Cactus collection, and a hammer for construction. Movement uses the selected Citizen's white outlined contact shadow and route preview without a speech bubble. Buildings and separate Utility devices use gray bubbles with black text instead. Identical group messages merge into one counted bubble, and solid world geometry hides bubbles for actors who are not actually visible.
- Move the camera independently with **WASD** and zoom continuously with the mouse wheel or trackpad scroll. The current bird's-eye view is the maximum zoom-out (`34` orthographic World Units high), while the earlier close view is the maximum zoom-in (`17` World Units high). Hold and drag the right mouse button horizontally to rotate through 360 degrees and vertically to tilt up to ten degrees above or below the default isometric elevation. The camera cannot approach a ground-parallel view. The bottom-right 72-pixel raised compass has a triple-height dark side wall, deeply recessed red North and metallic South needles, and a 50%-transparent sun reflection. Clicking it smoothly restores default yaw, elevation, and `34`-World-Unit zoom over half a second while preserving the current map focus. Manual camera rotation or scrolling interrupts that transition immediately. Hover or keyboard focus renders a fixed-width white silhouette from the current 3D viewing angle rather than drawing a circular UI border.
- Hover the rounded, hard-pixel custom cursor over world geometry to see its name as plain black text above the scene. Near a screen edge, this label moves to the cursor side facing the screen centre: right of the left edge, left of the right edge, below the top edge, and above the bottom edge. Native control tooltips use square black panels with hard white borders instead of smooth rounded corners. A bottom Building-menu tooltip opens above its button; other button tooltips also reverse direction whenever their normal placement would leave the viewport. All UI keeps the earlier vector font face but rasterizes glyphs at four times the prior density without antialiasing or subpixel positioning, then samples them with nearest filtering. This keeps the font’s pixel edges while giving letters enough source pixels to match the retro-rendered 3D scene. A selected non-Citizen object receives separate fixed-screen-width white frames around the top and bottom of its bounds; the four vertical connecting bars are hidden. Selected Sand receives one continuous four-edge rectangle on the chosen World Unit’s top surface. Press **F3** to add or remove development-only state details from the hover text.
- A hover name waits for two seconds of stable pointer position and then fades in. The small selected-citizen badge follows the cursor.
- Moving citizens into fog permanently reveals a four-World-Unit area on the 0.5×0.5 Sub-Unit grid. Every right-click whose cursor position is still inside fog creates only a `Walk` order, even when the ray intersects a hidden Tree or another collidable object; arriving and revealing that object never converts the existing order into work. The logical mask remains binary; linear sampling is used only to locate a thresholded diagonal or rounded contour, so rendered fragments are still either exact fog colour or fully absent. An isolated hidden one-World-Unit hole surrounded by revealed cardinal neighbours is revealed automatically.
- Press **B** or click the Building icon to enter Building Mode. Structure contains Support, Platform, and Sawmill. Support consumes four Logs; Platform consumes four Logs plus four Planks; Sawmill consumes ten Logs. Every carried material requires three seconds of visible Citizen labour before it becomes one installed building part. Construction Sites retain the four outward corner stakes and show their remaining asset parts as a 50%-opaque gray plan. Pile is free under Storage and places its four corner stones immediately without a Construction Site.
- Select a player- or settlement-built Support and press **Backspace** to remove it and immediately drop each installed Log as a loose Physical Resource inside the former Support World Unit. The same key cannot erase naturally generated Trees, Palms, bushes, cacti, stones, or loose resources; those objects shake to refuse the shortcut and continue to require their normal Citizen work.
- Selecting an unfinished Support Construction Site shows a compact `↻ R` tooltip directly beneath it. Press **R** to rotate the planned Building one quarter-turn clockwise while construction remains incomplete. Installing the final Log hides this option and permanently locks the completed Support at its last construction-stage orientation.
- Press **Esc**, right-click without dragging, or click empty ground to leave Building Mode. Unfinished plan geometry is hidden outside Building Mode, while installed construction remains visible.
- The transparent top-left Population indicator uses the shared `Icon Number`: a black Citizen icon and the total number of living Citizens. It uses the fixed Standard form, whose 44×44 icon matches the Building and Quit toolbar buttons and never changes with camera zoom. Hovering its icon shows `Population`; it is not the selected-unit counter. Clicking the icon cycles through every living Citizen in spawn order and wraps from the last back to the first. Each click smoothly focuses that Citizen at the 17-World-Unit maximum zoom without changing the player's current yaw or elevation. Camera travel scales from 0.1 seconds for a nearby Citizen to 0.5 seconds for a Citizen at least one maximum-zoom screen away.
- The transparent top-right toolbar contains simulation speed, Building, Greenery, Landscape, and Quit controls. Click `1×`, `2×`, or `4×` to cycle simulation time without accelerating camera input, tooltips, or speech-bubble reading time. Durations remain continuous simulation seconds, so a three-second job takes 1.5 real seconds at `2×` and 0.75 real seconds at `4×`; job durations do not need to be divisible by two or four.
- The hollow five-edge Building icon enters or leaves Edit Mode. Its black house contour uses an exact two-pixel solid stroke; this reduction applies only to the Building icon. Its roof slightly overhangs the vertical walls and replaces any horizontal ceiling edge. Hover or keyboard focus adds the shared two-pixel white outline; active Building Mode fills the icon. Its complete 44×44 rectangular area is clickable and opens a square tooltip beneath the button rather than over it. The same full-area tooltip rule applies to every toolbar and bottom-catalog button.
- The Tree icon directly beside Building enters Greenery Mode. Click a Bush or rooted Tree Stump to select it, then click a revealed empty World Unit to move and re-root it while preserving its deterministic visual offset and growth state. Piles, Buildings, resources, excavation, fog, and unloaded ground reject relocation. Right-click, Escape, selecting Citizens, or switching to Building Mode leaves Greenery Mode.
- The outlined dirt-pile-and-shovel icon beside Greenery enters Landscape Mode and fills with colour while active. Its bottom menu exposes `Remove soil block` and `Add soil block`. Remove deletes an existing player-added Soil Block or removes the clicked flat base cube as a one-World-Unit pit. Add restores a removed base cube, places one cube on ordinary exposed Sand, or attaches a cube to the exposed face of another Soil Block. Terrain changes are immediate sparse runtime deltas rather than Citizen jobs. Blocks may occupy heights `0` through `255`; fog, unloaded cells, occupied surface cells, and height `256` reject placement. Right-click, Escape, selecting Citizens, or switching modes closes Landscape Mode.
- Clicking the Building icon enters persistent Building Mode and reveals the categorized two-row menu. Structure offers Support, Platform, and Sawmill; Storage offers the playable free Pile plus the future Warehouse. `Remove building` erases player Buildings and player-placed Piles directly.
- Hold **Alt** while clicking to use the exact raycast object instead of citizen selection priority. During Support placement, a normal click places once and ends repeated placement; **Ctrl-click** places one and keeps Support placement active.
- Press **F2** to enter the developer Building Constructor. Human-readable Version 2 `.pyrbuilding` files preserve logical Sub-Units, physical parts, recipes, and workshop processes. Every official Building has a neighboring `.obj` whose named parts provide runtime vertices. The local Blender extension round-trips `.pyrbuilding`; standard Wavefront import/export edits `.obj`. See [BUILDING_BLUEPRINT_FORMAT.md](BUILDING_BLUEPRINT_FORMAT.md).
- On first launch, a translucent blank-keyboard lesson shows recognizable key proportions without printing or prescribing any key values. Any key dismisses it; **F1** reopens it later.
- A muted gray build stamp beside the bottom-right compass displays the prototype version, current Git commit hash, and the application time of the latest chat batch in GMT+3. Each applied batch increments the final component of the `0.0.x` prototype version.

The initial world includes one Pile occupying a 2×2 footprint of four World Units. Four small stones mark the convex outer corners, and its six stored starting Logs remain visibly distributed inside, so the first Support can be built immediately after explicit citizen assignment. The footprint is stored as occupied cells rather than only width and depth: later expansion may create connected non-rectangular Piles. Boundary stones are recalculated from the shape, so the five-cell example has five convex-corner stones while a complete 3×2 rectangle has four. The first implementation has no capacity limit or Pile-expansion UI. A selected Pile reports each stored resource through a Compact Icon Number with fixed icon and typography sizes. A generic resource-count store accepts later resource families without requiring separate storage Building types; current visuals cover Logs and Calories, while Water is rejected without a vessel. Citizens visibly carry harvested berries to the nearest accessible part of the Pile before one `Calories` is stored. Trees grow in separated forest patches with clear areas and standalone specimens between them. Living Trees can begin at 1, 1.5, 2, 2.5, or 3 World Units. Partially cut trunks keep their remaining logs; the final cut removes the tree entirely. Dead Trees retain thicker low-poly top branches but have no greenery. Trunks enter the ground without exposed roots or a flared base. Living and dead trunks stay close to the shared 0.23 m log diameter, with only slight width variation and taper. Dense seeded forests contain more dead trees and allow adjacent trunks, with clearings between stands. Every completed three-chop job removes one top Log segment and drops one loose cardinal-axis Log before the assigned Citizen carries it to the Pile. Lower segments remain standing, without moving replacement crown geometry downward, until the last segment removes the tree. Palm trees use a darker bent two-to-three-World-Unit trunk with two irregular five-leaf layers. Each elongated low-poly leaf has a rounded width profile and increasing sag toward its tip. Cacti are no taller than a citizen and each stores one Water. Limestone formations occur in square desert patches and may reach three World Units. Their horizontal tops always use the exact current Sand colour, while vertical faces use three hard sunlight bands derived from `#EEBF8A`. Each living Tree crown and Berry Bush deterministically selects one of five closely related exact green hex colours, making dense patches readable without gradients. Each Berry Bush combines three slightly varied solid-green lobes using its selected colour. Its ten berries are batched camera-facing raster dots rather than ten separate sphere meshes.

At sunset every Citizen pauses walking or applied labour and lies horizontally on the ground in a sleeping pose. Routes, carried resources, persistent work assignments, and partial target-owned labour remain intact. At sunrise Citizens stand up and resume the exact interrupted route or work; an assigned gatherer with no currently available target retries the assignment after waking.

Cloud geometry and its terrain-shadow calculation are currently disabled so the opening view and fog-of-war navigation remain clear. The implementation is retained for a later, occasional weather or rain system.

One day lasts 360 simulation seconds: 360 real seconds at `1×`, 180 at `2×`, or 90 at `4×`. The centred top navigation shows a rotating half-day/half-night wheel beneath a fixed sun marker and a `Day 1` counter. Morning gradually changes through light blue into yellow Day colour; evening changes from yellow through red into blue Night colour. Sun energy, sky, fog, terrain, and shadow colours interpolate through these stages rather than changing at one horizon frame.

Limestone uses a pale sand-adjacent colour in daylight. During the cycle it follows the terrain hue toward a readable blue-gray at Night, with restrained self-light preventing it from becoming an unrelated near-black silhouette.

## Current source structure

```text
scenes/Main.tscn                 Runtime scene
scripts/main.gd                  Runtime orchestration, input, orders, and world setup
scripts/world_generation_profile.gd  Persisted seed, generator algorithm/version, and QA fingerprint
scripts/terrain_block.gd         Sparse player-added World Unit terrain cube
scripts/building_catalog.gd      Building families, footprints, recipes, and availability
scripts/citizen_command_overlay.gd  Citizen selection, routes, and target presentation
scripts/applied_labour.gd        Actor-independent accumulated labour state
scripts/labour_progress_bar.gd   Duration-scaled horizontal labour presentation
scripts/compass_widget.gd        Compass rendering, interaction, and sun reflection
scripts/toolbar_icon_renderer.gd  Procedural toolbar icon rendering
scripts/ui_visual_tokens.gd      Shared UI typography, dimensions, and stroke tokens
shaders/*.gdshader              Native terrain, fog, grass, object, compass, and screen shaders
scripts/gameplay_action_catalog.gd  Citizen action text and audio contracts
scripts/game_palette.gd          Authoritative construction and landscape colours
scripts/grass_renderer.gd        Chunked GPU-instanced grass billboards and wind shader
scripts/world_streamer.gd        16×16 chunk addressing and deterministic surface generation
scripts/citizen.gd               Citizen movement and carrying presentation
scripts/world_item.gd            Trees, palms, cacti, bushes, stones, and physical logs
scripts/obj_asset.gd             Cached named-part Wavefront OBJ runtime reader
data/props/*.obj                 Three Blender-editable variants of current physical world props
data/buildings/*.{pyrbuilding,obj} Paired Building semantics and named runtime geometry
scripts/pile_storage.gd          Starting shared Log and Calories storage Building
scripts/icon_number.gd           Shared Full Scale and Compact icon-plus-integer UI
scripts/construction_inspector.gd Selected-site name, total labour, and material UI
scripts/construction_progress.gd Mixed-material construction duration calculation
scripts/support_construction_site.gd  Four-log Support Construction Site
scripts/ui_text_catalog.gd        Player-facing text lookup and length validation
scripts/world_unit.gd            8-Sub-Unit / face-Anchor Node data model
scripts/building_blueprint*.gd   Versioned Building Constructor data, editor, and renderer
scripts/building_blueprint_obj_exporter.gd Blender-compatible OBJ/MTL generation from logical assets
tools/blender_pyrbuilding/       Blender extension for direct .pyrbuilding round trips
tools/package_blender_extension.py Reproducible local extension ZIP packaging
localization/ui_text.csv         English UI text, stable keys, and character limits
tests/content_contract_test.gd   Headless English-text and action-audio contracts
tests/applied_labour_test.gd     Resume, actor handoff, timing, and bar geometry contracts
tests/citizen_command_overlay_test.gd  Citizen command-overlay geometry contracts
tests/world_streaming_test.gd    Generation, x=1000 travel, fog, unload, and restoration contracts
tests/icon_number_test.gd        Icon scaling and fixed-number typography contracts
tests/construction_progress_test.gd Mixed-material duration and bar-width contracts
tests/building_rotation_stage_test.gd Construction-only rotation and completion lock
tests/selection_outline_geometry_test.gd Exact World Unit/Sub-Unit selection edges under rotation
tests/greenery_mode_test.gd     Greenery toolbar state and Bush relocation contracts
tests/landscape_mode_test.gd    Landscape toolbar and sparse add/remove terrain contracts
tests/building_catalog_test.gd  Path, Storage, Livable, and Structure definition contracts
tests/road_navigation_weight_test.gd Weighted Road route and walking-speed contracts
tests/tree_regrowth_test.gd     Three-day Stump and Tree growth cadence
tests/obj_asset_runtime_test.gd OBJ part names, Support anchors, prop loading, and berry state
tests/building_blueprint_test.gd Version 2 round trip, official assets, recipes, and OBJ export
tests/test_pyrbuilding_codec.py Blender codec validation and coordinate round-trip contracts
tests/building_asset_gameplay_test.gd Platform, Sawmill conversion, and free Pile contracts
GAME_DESIGN_FOUNDATION.md        Editable design decisions
GLOSSARY.md                      Canonical project terms and descriptions
WORLD_STREAMING_AND_PERSISTENCE.md  Semi-infinite generation, discovery, streaming, and save contract
```

Player-facing text belongs in `localization/ui_text.csv`, not in gameplay scripts. Every text key contains at least two underscore-separated words. The catalog uses Godot's native `keys,en` translation columns. Metadata columns begin with `_`, so Godot ignores the metadata during translation import while the runtime validator still reads the planned character limit, interface location, and translator note. Additional locale columns can extend the same stable keys later.

## Deliberate current limits

- No copied visual assets, sounds, code, or original game content.
- Current orders use an event-driven weighted eight-neighbour A* grid. Limestone, trees, dead trees, palms, cacti, and bushes block their World Unit; work routes terminate at a reachable adjacent cell, and diagonals cannot cut through two blocked corners. Ordinary traversable ground costs `1.35`, while a registered completed Road costs `1.0`; routes prefer a reasonably nearby Road and Citizens walk `1.35×` faster over its cells.
- The surface world is horizontally semi-infinite and streamed as deterministic 16×16 World Unit chunks. The earlier 64×64 layout remains only as the origin content fixture; it no longer clamps Citizens, the camera, fog, grass, terrain, or navigation. Loaded rings follow Citizens and the viewed area, while distant chunks unload without allocating the rectangle between them.
- Horizontal Citizen movement expands chunk-local discovery at every height. Untouched streamed resources regenerate from a persisted world identity containing the seed, immutable generator version, algorithm ID, chunk size, and QA fingerprint. Generator version 2 uses stable SHA-256 coordinate hashing and fixed-point seeded habitat fields instead of linear modulo placement, preventing diagonal Tree and Cactus bands while producing the same base world on every machine. Changed entities retain an in-memory overlay and removed generated entities retain tombstones across unload/reload. Persisting those sparse deltas to disk, the 0–255 underground column system, biome latitude, and forecasted outside settlements remain the next phases described in [WORLD_STREAMING_AND_PERSISTENCE.md](WORLD_STREAMING_AND_PERSISTENCE.md).
- Grass uses one upright camera-facing two-triangle billboard per tuft, six tufts per grass World Unit, 8×8 MultiMesh chunks, shader-cut four-blade silhouettes, per-tuft variation, GPU wind, and fog-aware visibility without casting shadows. Tuft positions use a scrambled two-dimensional Halton low-discrepancy set with independent per-tile permutation, mirroring, axis swap, and shift, preventing repeated diagonal rows while keeping coverage even. Bush and grass occupancy is mutually exclusive per World Unit: existing bushes are passed into grass generation as exclusions, while a later bush-generation pass refuses grass-claimed units. Generated grass starts fully grown, with the tallest blades reaching roughly half a citizen's height. Future spreading growth belongs only on patch edges. Individual grass transforms are deliberately not save data.
- Bush surfaces use solid unshaded palette colours while continuing to cast shadows. Grass uses its solid unshaded palette colour but never casts a shadow.
- Directional soft-shadow filtering is disabled. The terrain shader thresholds shadow coverage into one binary result: exact surface colour when lit or exact `FOG_AND_SHADOW` colour when shadowed. Overlapping shadow casters therefore cannot accumulate into darker layers.
- Living and Dead Tree trunks and loose Logs use exactly two wood colours selected from face direction and explicitly cast geometric shadows. Loose horizontal Logs therefore retain a contact shadow on the terrain. Citizens do not cast long dynamic body shadows; each Citizen owns a small opaque circular contact disc that remains compact through morning and evening because it represents ground contact rather than sun direction.
- Tree and physical-log variation is persistent world state: `permanent_detail_seed` selects one of three neighboring OBJ variants and a future save must retain that seed even though grass can be regenerated.
- Reusable physical props and Building meshes are Blender-editable OBJ assets. Collision, materials, resource state, wind sway, and construction logic remain code/data concerns. Dynamic terrain chunks, fog contours, grass MultiMeshes, selection outlines, progress bars, and UI remain engine-generated because their geometry is derived from changing simulation or screen state. Citizens require a later rigged `.glb` migration; flattening articulated animation into OBJ would discard joints and animation.
- Snow terrain, pine forests, the full-log snow cabin, and Cloth production are design contracts only; those biome and crafting systems are not playable yet.
- MSAA, screen-space AA, and TAA are disabled; a nearest-sampled 2×2 full-screen filter produces the deliberate retro-pixel 3D presentation.
- Support, Platform, Sawmill, and Pile are placeable. Path, Warehouse, and Livable forms remain visible but disabled.
- Multi-level structural dependency checks, Support-to-Platform upgrades, Livable House conversion, and free drag relocation are specified in [GAME_DESIGN_FOUNDATION.md](GAME_DESIGN_FOUNDATION.md) but are not yet playable in this flat Support-only slice.
- No disk save/load path exists. The current top-right `Quit` button exits immediately and does not preserve the runtime-only world overlay.
- Landscape Mode currently stacks solid Soil Blocks to height `255`, but Citizen navigation still operates on the surface plane. Height-zero blocks obstruct that navigation; stairs, climbing, unsupported-block falling, recovered Soil resources, deeper voxel excavation, chunk unloading of authored blocks, and disk persistence are deferred.
- Utilities, caves, deeper multi-level excavation, rooms, and autonomous settlements remain deferred until this core loop is evaluated.

The vertical settlement scene now includes [seeded mountains, canyons and small rainwater sources](docs/WORLD_GENERATION.md). Start a new empty save slot to see generated terrain; existing saves retain their ground.

### Blueprints: irregular buildings

Press **F2** or choose **Blueprints** in the settlement building menu to sculpt and vary sparse 3D shapes, stack and move buildings on a virtual map, connect entrances with ladders, and place AC units or dishes manually or through automatic upgrades. Inaccessible doors request access through speech bubbles. Advanced controls include diagonal braces and construction work settings. The workshop pauses the settlement and saves separate `.pyrstructure` authoring files. Start with **Example**. See [the workshop guide](docs/STRUCTURE_WORKSHOP.md) for controls, file format and the boundary between this sandbox and settlement simulation.
