# ... Town

Working title for a cozy town-building management game. The current generated cottage icon is a temporary placeholder. The final icon will use an actual in-game 3D model once the visual style is defined; the current direction is moving toward ShantyTown's assembled, lived-in architecture.

# Rope bridges

## Generated building plans

In the main game, choose **Housing → Building plan** to generate and rotate a
connected room layout. Workers build its rooms, terrace, stairs and beds through
the existing construction system. House remains available. See the
[object/material ledger and save/detail design](docs/GENERATED_BUILDINGS.md).


Run `tools/settlement/play_modular_house.sh` to inspect joined rooms, automatic
supports, a usable roof terrace and an obstructable chimney without opening a
settlement save. See [controls and scope](docs/MODULAR_HOUSE_PROTOTYPE.md).

## Main-game Supports and Greece islands

The main menu now previews the latest island landscape, and **Fields**, the first new-game choice, starts that exact world. New **Fields** games start on a Greece-inspired island map with surrounding small islands, mountain shelves, sandy shores and turquoise saltwater. Existing saves keep their original generator and coastline. New small islands are generated from the world seed as varied headlands, coves, twin-summit saddles and bluffs. Coast contours, aspect ratios, elevations, shelf widths and exposed sides vary; the sheltered side has terraces/beaches while continuous rock faces meet the sea on the other side. These are generated solids rather than scaled copies of a mountain. The main island now varies its proportions, rotation, bays, cliff orientation, plateau heights and peak count with the seed. Unequal adjoining coastal blocks surround the protected village; exposed cliffs meet the sea without a continuous beach rim. Touching shelves at the same elevation form one continuous surface rather than separate radial arms. Unequal 2 m shelves and a 4 m overlook now break up the middle, while deeper bays reach closer to the first house. The connected lowland retains space for early buildings and a full-size field; stairs unlock nearby upper plots, making terrace and rooftop expansion useful. The lowest land stands 0.65 m above the rendered sea, with small animated foam patches at the shore and rocks. Small blue wavelets travel downwind, softening in sheltered bays; short surf packets roll toward land and leave foam that fades after impact. Translucent shallows reveal submerged rock and a sandy bed, fading into opaque deep water. New maps have fewer seabed-rooted rocks beside coastal cliffs and two finite inland stone patches below exposed rock faces, with citizen access and room for a nearby Quarry. Full, visible puddles provide reachable freshwater near the starting family. New Normal (Sand) games roll their own island seed and use dry sand and warm rock. New games generate fresh layouts; saved seeds reproduce the same terrain. In both landscapes, the third terrace at 6 m and higher levels have bare rock surfaces and no generated grass. Start a new Fields or Sand game to see the new terrain; existing settlements keep their saved landscape.

New version-23 islands use dipping strata, gently folded grassy uplands and taller broad mountain crowns connected to inclined cliffs. Thin exposed shelf bands merge into the cliff, while soil fades into rock below higher faces and across the mountain foothills. Irregular rock faces and embedded ledges remain instead of separate pointed peaks. Gentle relief supports walking; construction still needs a level footing. Wide terraces and the protected village remain buildable. Sparse decorative stones emerge beside cliffs or remain submerged; they have no collectible Stone inventory and do not create walking steps. Usable quarry deposits stay on land.

A continuous shallow shelf follows the main coastline, broad beside beaches and narrow below cliffs, before fading into deep water. Its width varies along the coast, with seeded deeper channels crossing selected beach shelves. Turquoise water reveals irregular sandy patches, while submerged rock fades into the same deeper-water tone as the seabed. Smaller islands keep only a narrow submerged edge, without detached reef ovals. Beaches, the physical seabed, collision and foundation pricing share the same depth profile, and submerged sand blends across the mesh join. Shallows support ordinary pier construction. Shore contact has been checked at 15 cm below and above mean water level; automatic tides remain future work. The menu and both new-game landscapes use this generator. Earlier worlds keep their saved terrain and channels, while receiving the improved water and underwater material colours.

**Support** placement supports small structural rotations: **[ / ]** adjust by 2° up to ±15°, **Shift** allows continuous positioning within the current metre address, and **R** changes plank direction. Neighboring groups share compatible logs within a 15 cm corner tolerance, with the older building retaining its position and posts. New beams fit to those logs. Rotated overlaps and unsupported feet are rejected. Shared-log owners cannot be removed while another group depends on them. Deck gaps do not automatically become walking routes. These fields persist through construction and saving.

New Fields and Sand maps use closed irregular terrain solids with wide asymmetric terraces, inclined cliffs and broad rocky shoulders. Aim Support at an exposed cliff to excavate through construction. Completed modules cut their actual positioned/rotated volume; two stacked modules provide citizen headroom. Previewing or cancelling an unstarted plan removes no rock. Excavation survives demolition, saving and streaming. The sea has continuous coastal shallows that broaden beside beaches and narrow beneath cliffs. Existing worlds retain their terrain. Resource recovery from excavated rock remains future work. Previews: [Greece islands](artifacts/settlement/greece-islands.png), [main-game fitted Supports](artifacts/settlement/main-support-fitting.png), [generated main island](artifacts/settlement/main-generated-island.png), [Support excavation](artifacts/settlement/main-support-excavation.png).

## Terrain construction sandbox

Run `./tools/terrain_sandbox/play.sh`, or open `scenes/terrain_sandbox/TerrainSandbox.tscn` in Godot and press F6. This separate prototype has an irregular plateau, high ridge, fractured fin and natural overhangs. Excavation belongs to Support construction; there is no freeform tunnel tool.

With **Support** active, click a terrace or exposed cliff to place a **1×1×1 m** module. Construction clears only that footprint. Adjacent modules share frame parts within a group no larger than **2×2×2 m**. A horizontal pair loses the intermediate legs and crossbeam; a vertical pair loses the lower deck and waist-high beams so a citizen can pass through. Larger arrangements retain separate group identities. Where groups touch, the older building owns one shared corner post; the newer frame fits its bearings to that log instead of adding a duplicate leg. Coincident boundary beams also keep their older owner.

Default positioning uses one-metre sockets. New placements within 0.16 m of a free neighbor socket snap to the existing structure, without moving it. Hold **Shift** for 0.1 m horizontal positioning without automatic attachment, including deliberate gaps. Within-group joining still requires exact faces. Between separate groups, corner offsets up to 0.15 m can share an existing post when the facing modules have the same floor height. Only the newer bearing endpoints adapt: neither building moves, and deck gaps remain visible. Larger offsets, different floor heights and diagonal corner-only contacts retain independent posts. This fitting rule also applies during Shift placement; Shift disables placement snapping, not structural fitting. Each module needs rock below its posts or another module directly below. No remote construction inside unexposed rock.

Decks use visibly separated, staggered stock boards over exposed Log bearings, with posts projecting above the deck. Plank direction varies deterministically by 90°; press **R** during placement to choose the other direction. This rotates the boards, not the structural footprint. Use **[ / ]** for small structural rotations up to ±15°; fitted beams and excavation rotate with the module. General wall fitting, interior part manipulation and stairs between separate floors remain separate work.

**Undo** or Cmd/Ctrl+Z reverses the last prototype placement and its excavation, restoring exposed frame parts; it is editor history, not a production dismantling rule. **Reset** restores the original scene; Esc leaves placement. Right/middle drag orbits, the wheel zooms and WASD pans. No permanent instruction panel is shown.

Construction persists separately in `user://support-groups-terrain-sandbox.json` (version 5; version 4 grouped Supports load without rotation). Earlier Support, two-metre-bay and freeform-cut files remain untouched and are not imported or resized. Main-game terrain and saves are unchanged. This bounded CSG prototype supports 128 modules and completes construction immediately. Worker excavation, recovered resources, hauling, settlement navigation and large-world streaming remain integration work.

Previews: [Supports above the mountain](artifacts/settlement/support-mountain.png), [constructed passage](artifacts/settlement/support-excavation.png). Focused checks: `tests/terrain_sandbox/volume_test.gd` and `tests/terrain_sandbox/interaction_test.gd`.

## Rope bridge prototype

Run `./tools/settlement/play_rope_bridge.sh`, or open `scenes/settlement/RopeBridgePrototype.tscn` and press F6. This separate scenario uses the real settlement production, construction, navigation and carrying simulation without loading or saving player settlements.

Two terraces stand at 2 m and 5 m. Workers turn supplied Hay into Rope, deliver Rope and Planks to the queued bridge, then carry Logs uphill to the empty Shed and return across the bridge. Buildings remain grid-aligned. The supplied stocks and completed workplaces are prototype fixtures.

**Bridge** lets you click two supported surfaces to place freely positioned ends; the preview shows the span's material cost. **Remove bridge** cancels a plan or removes the latest completed, unoccupied span. **Reset** restarts the supplied scenario. Escape cancels placement; the existing camera pan, rotate and zoom controls work. No instruction panel or goal counter is added.

Rope maker is also available in the normal construction menu: a fixed 1 Hay → 1 Rope recipe, four seconds per batch, with a four-Log construction cost. Hay retains its existing internal `grain` resource ID. These are provisional values; production tuning lives in `[production.rope_maker]` in `game_settings.cfg`. A bridge costs one Plank per metre of curved deck and one Rope per two metres, each rounded up. The default crossing costs 8 Planks and 4 Rope. Both producer unlocks are required to queue it, but current stock may be zero.

The prototype and main game share bridge geometry, construction, routing, rendering and save support. Spans are limited to 2–24 m horizontal distance and a maximum local grade of 0.75, with supported landings, room for both anchors and terrain/building/span clearance checks. The graph counts the curved deck and landing approaches; a planned bridge grants no navigation. Crossings use one-at-a-time traffic. Citizens finish crossing before accepting a new movement/work assignment, and occupied bridges cannot be removed. Moving, completed-span removal and construction cancellation preserve physical salvage. Same-height intersections and overlapping rails are rejected; overpasses require vertical clearance. Bridge anchors must fit on their supporting surface. Rope sway and load simulation remain later work.

See [the live prototype capture](artifacts/settlement/rope-bridge-prototype.png). Main-game captures: [first post pair](artifacts/settlement/rope-bridge-main-first-pair.png), [automatic log hauling](artifacts/settlement/rope-bridge-main-hauling.png), [rooftop landings](artifacts/settlement/rope-bridge-main-roofs.png). Focused checks: `rope_bridge_test.gd`, `rope_bridge_runtime_test.gd`, `rope_bridge_main_test.gd` and `rope_bridge_edit_test.gd` under `tests/settlement`.

---

# Main-game construction

Run the main project with F5 and enter a settlement. Use the regular construction categories to place buildings with defined roles, such as a house or log shed. The experimental **Rooms** toolbar entry and shape menu have been removed from normal gameplay.

The room editor, shared shapes and worker-construction integration are retained for future reuse. Existing room layouts remain compatible with saved settlements. For development only, `./tools/settlement/play_rooms.sh` opens the isolated room-construction prototype without overwriting player saves.

See [the retained prototype scope](docs/VERTICAL_PROTOTYPE.md#room-construction-milestone) and [metric measurements](docs/BUILDING_MEASUREMENTS.md).

---

# New experiment: Block City

Select **Block City Demo → Run** in Godot Project Manager (import `demos/block_city/project.godot` once on other machines), or run `./tools/block_city/play.sh`, for the separate coloured-box city-building demo: small flat pieces with editable draw weights, a 3×3 lot with supported overhangs, direct pole-to-floor hanging wires and an Escape menu. Building types and the economy are deferred. The existing main-game startup and saves are unchanged.

See the [play guide, design, shape table and market evaluation](docs/block_city/README.md). Run `python3 tools/block_city/run_checks.py` for its focused checks. In Godot, open `scenes/block_city/BlockCity.tscn` and press F6.

---

# Town economy

The playable settlement now has a working food and materials economy: berries, irrigated grain, bread milling, plank sawing, limestone mining and masonry. Houses support population growth; schools, workshops, pantries and roads have simulation effects. Select or box-select adults, assign jobs in the inspector, or right-click resources and workplaces. No alien storyline, enemies or weapons are active.

Trees, dead trees and palms disappear when the final log is harvested, freeing the ground immediately. Partial trunks remain harvestable; no decorative stumps remain. Older stumps are cleared when saves and map chunks load.

The current visual direction uses featureless citizens, flat colour shapes, and a full-resolution antialiased world with fine, straight outlines. The world stays 3D; an illustrated material and edge pass replaces the reduced-resolution pixel look. Day/night tint affects the world while the interface remains sharp.

Recipes are prototype tuning for this town-building game. Existing saves migrate, including old timber-only plans. **V** inspects and **Esc** clears selection and cancels placement without saving or leaving play. Play continues at **1×**, **2×**, or **4×**; Space does not pause.

Run `python3 tools/settlement/run_checks.py` for the regression suite. `tools/settlement/verify_progression.gd` tests the full economy from the normal starting inventory through village construction and dressed-stone production.

---

# Vertical settlement prototype — v0.1.0

**F5 opens the settlement selector.** Choose an empty slot and Normal difficulty, or continue an existing settlement. **Esc** clears selection and cancels placement; progress saves automatically and Settings contains only fullscreen and route visibility. New settlements start with one completed house, two adults and one child. The house holds five meals and accepts gathered berries; there is no starting pile or loose timber. Builders can harvest raw materials for the first storage buildings. There are no prebuilt terraces, stairs, wells, gardens or queued buildings. Adults carry resources and construct what you place; the child wanders and eats independently, cannot be selected for work, and becomes an adult after three simulation days. Growth and clothing survive saving. Citizens have slimmer rounded bodies, short pill-shaped limbs without fingers, heads without facial features, and solid-color shorts, dresses, top-and-skirt outfits or one-shoulder robes. The scene uses a 33-model 3D kit with articulated citizens and editable GLB exports. The compact peach build menu follows the supplied Figma reference and includes 13 housing and industry building types, plus platforms, stairs, stockpiles and gardens. Placement snaps to ground, decks and completed roofs across a 41 × 41 cell world.

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
