# Town design direction

Confirmed by the user on 16 October 2026. These references describe desired mechanics and visual qualities, not permission to copy another game's code or assets. This document guides refactoring; it does not claim every referenced system is playable.

| Reference | Desired quality | Current foundation / next implementation |
| --- | --- | --- |
| Oxygen Not Included | Devices connected with pipes, tubes and cords | Asset access markers and water ports exist. Add explicit typed ports, connections and network simulation separately from rendering. |
| Oxygen Not Included | Furniture determines room functions: tables and chairs for dining, beds for sleeping | Furniture models exist. Room volumes, enclosure detection and capability rules remain to be implemented. A building name alone must not grant room functions. |
| Timberborn | Stacked construction with connected entrances; skyscrapers and bunkers | Distinct floor surfaces, explicit bidirectional stairs and physical hauling work. Preserve vertical access as a graph; do not infer a connection merely because buildings overlap. |
| Minecraft | Spatial subdivision and streamed chunks | The older prototype has a world streamer. The vertical prototype is bounded. Bring chunk ownership into the model only after vertical entity identity and persistence are stable. |
| Pyramida | Simple recognizable silhouettes and broad colour shapes | Updated 18 October: featureless citizens and an illustrated 3D world, with full-resolution antialiasing and thin, straight contours (updated 30 October: remove the noisy edge distortion). The original pixel presentation remains available for comparison. |
| Cloud Gardens | Plant growth and tending form a visible part of the game | Gardens grow when watered. Once chopped, trees retain their remaining sections permanently; citizens can finish chopping them, and the final log removes the tree completely. Expand growth stages, plant variety and tending interactions. |
| All Will Fall | Optional structural load and failure | Research only. If adopted, expose beam capacity and load clearly and make failure recoverable. Do not introduce unexplained collapse. |
| ShantyTown | Buildings stacked into lived-in structures with managed accessories | Stacking and original architecture assets provide the base. Accessories should have attachment points, access needs and utility connections. |
| [Above: Colonies of the Mist](https://store.steampowered.com/app/3783980/Above_Colonies_of_the_Mist/) | Colonies on high hills or mountains, hazardous lowlands, and suspended bridges connecting hilltops | Reference identified by the user on 30 October 2026. Keep for future landscape and connection design; possible tidal flooding is an exploratory adaptation, not an implementation commitment. |

## Exploration cloud cover, 11 November 2026

Replace the flat unexplored-map fill with moving cloud cover, following the user's Nova Roma reference. Clouds surround discovered land and retreat as citizens reveal more of the map, with the partly transparent edge specified below. Keep discovered land permanently visible and preserve saved exploration. Unknown resources remain hidden and cannot be inspected or built on. Retain whole-tree reveal at the exploration edge and fully visible menu previews. Add no persistent exploration counter or instruction UI.

Follow-up: replace the procedural screen overlay with actual three-dimensional clusters of low-poly spheres. Broad white lobes and subtle shaded polygon faces form rounded cloud banks. Each lobe independently shrinks toward a tiny sphere and becomes translucent before disappearing; do not dissolve a Perlin-noise texture or slice a flat mask through the cloud shapes. Keep cloud placement stable in world space and across camera movement. Cloud motion and discovery transitions follow simulation time.

In the island landscape, a citizen reaching an island reveals its complete coastline and a small surrounding water margin. The occupied starting island is clear from the beginning. Other islands stay undiscovered until reached; visited islands stay revealed after departure and save/load. Existing saves retain their explored cells and reveal their currently occupied islands. Retain local circular discovery in landscapes without island coastlines. Cloud geometry itself surrounds the revealed area; unknown resources remain hidden and unpickable even during cloud transitions. Fully visible menu previews remain unchanged.

Landscape engineering and Timberborn-style flowing water were requested as integration ideas; those systems are not implemented by this visual change.

Cloud-shape refinement: avoid a blanket of equal-sized balls. Build varied larger silhouettes from broad rounded bodies, taller lobes and smaller trailing puffs, with different group sizes, proportions and orientations. Place the cloud boundary farther beyond the discovered shoreline, leaving open water around the island and a partly transparent fringe as the camera approaches the outer area. Keep deeper cloud groups denser. Use gentle bounded movement along the sea's wind direction, with different group headings and speeds; lobes in a group move together. This visual margin does not discover neighbouring islands or resources. Preserve the existing island discovery and shrink-and-fade transition.

## First island learning scenario proposal, 11 November 2026

The user requested a written [first island concept and resource budget proposal](FIRST_ISLAND_PROPOSAL.md), with no implementation yet. One person wakes in the morning on a cartoonishly small, rounded sandy island after a shipwreck far away. Start without buildings; exclude the suggested damaged boat waiting on the beach. The proposed needs are one Food and one Water per person per day, with recoverable weakness instead of a life-or-death learning scenario.

Explore useful supplies washing ashore, possible coconut and palm renewal, and a silent director that adjusts resource arrival chances to help the player recover from shortages while withholding hostile encounters and disasters during learning. Follow-up selected direct drinking from a rain-filled puddle without a Well or fuel, basic spear fishing without a building or tool inventory, expansion on Supports over the shallow reef, and newcomers arriving by boat whom the player can welcome. Keep the starting island viable for continued settlement in a continuous world. The fishing shelter improves fishing; its cost and detailed benefit remain open. Underground resources, starting quantities, detailed balancing and the final goal remain undecided. No sharks. This proposal does not replace the existing main-game start or authorize gameplay or UI implementation.

## Pearls currency and naming exploration, 11 November 2026

Pearls obtained from shrimp growing at the reef are the proposed reef currency, as part of the game's fictional ecology. The later clarification leaves gold coins and diamonds open as additional high-value trading elements; valuable underground discoveries could motivate deeper mining. Their relationship to Pearls, harvesting, renewal, yields, storage, prices and spending uses remain open. Update the economy documentation only; preserve runtime identifiers, saves and existing prototype economies. See the [crafting model](CRAFTING_MODEL.md#pearls-currency-proposal).

Prefer a title containing Village or Town, with less interest in Farm or World. Avoid centring the game's identity on one resource or environment: the reef is a starting scenario, and a future learning scenario could have a harsher setting that is not a reef. Naming is deferred without urgency. Earlier candidates and preliminary web checks remain in [game naming notes](GAME_NAME_CANDIDATES.md). No final name is selected and no branding change is authorized.

## Roof runoff and small water vessels, 11 November 2026

The user approved rooftop rain as the main water source, replacing the puddle-dependent opening. Give the first person a filled salvaged vase. One complete shower contributes one droplet per connected 2 x 2 m roof area; half of eight roofs yields four droplets. Vase, barrel and default Well capacities are one, two and three droplets. Preserve fractional runoff across frames and saves, enforce capacity and overflow, and never count a catchment twice.

Place resource-built clay vases and plank barrels in real free spaces between connected buildings and on piers. Add a Rain tool to building selection and room editing for half-round low-eave gutters and player-routed downhill pipes. Exposed roof slope and the actually connected gutter length determine capture. Show flowing runoff, disconnected spill and the receiver's water level. Builders pay the fitting materials; moving preserves water and removal recovers paid materials. The salvaged starter vase catches rain directly until connected to a roof, allowing the opening without puddles, a kiln or a sawmill. New settlement water generation follows this direction; preserve existing saves and stored water. See [the updated first-island proposal](FIRST_ISLAND_PROPOSAL.md) for the wider scenario, which remains separate from the existing main-game start.

Follow-up: use the structural Log (0.23 m diameter) as the utility scale reference. Clay pipes and half-round gutters are 0.25 m across, with visible bores, socket collars, curved elbows and fastening brackets under the low roof edge. Place gutters as individual 0.25 m sections; touching sections share a downhill outlet. Pipes remain editable routes with visible direction previews, adjustable bend height and reusable paid Clay. Several roof branches can join into a shared drain, feeding one or several collection sites. A 2 x 2 m clay-lined basin is the current larger receiver, holding 24 droplets and costing 24 Clay plus 12 Stone; these are initial tuning values. Preserve the existing vase, barrel and Well capacities.

Rain exposure should reward covering rooms and walkways and draining roofs. Uncovered constructed floors, uncollected eaves and overflowing receivers become damp, slow walking and occasionally make citizens sit down after slipping before resuming their delivery. This uses surface wetness and a short recoverable delay, not collectible puddles or permanent injury. The current tuning reaches 35 percent slower walking at full wetness, a 1.4 second recovery after prolonged slippery travel, and gradual drying after rain. Show ceramic joints, water moving through open gutters, spouts pouring into vessels, ripples and subtle wet floor sheen. Keep the mechanics in the world models and behaviour rather than a persistent explanation panel.

Further rain-detail correction: keep the roof droplets for the user to inspect before deciding whether to remove them. Close exposed gutter ends with ceramic end walls and use enclosed L outlets at the end of a run or T outlets at an intermediate takeoff. Keep joined section seams open internally. Downpipes can end at a ground outlet; uncaught flow wets its landing, while a vase, barrel or basin placed directly under the spout collects that same runoff. Moving the container leaves the fixed outlet in place. Barrels have curved plank staves, a wider belly, narrower mouth and base, and fitted hoops, using the same colour and illustration treatment as the existing plank stock.

## Support piers and wet timber, 11 November 2026

Support can be placed over the sea. Following the user's lower-pier correction, its deck sits 0.15 m above the actual water level. Adjacent water Supports make one flat, wider platform. Keep integer spatial addresses while rendering, picking and navigation use the real deck height. Short visible plank landings connect nearby accessible shore surfaces; never connect to higher dry decks across an invisible vertical gap. Buildings stand directly on the lowered deck. Propagate that bearing height through construction previews, completed models, roof sockets, stacked floors and walking paths while retaining integer addresses. Require the whole footprint to bear at one physical height. Keep actual doorway thresholds and one- or two-metre stairs with matching lower and upper landings; stacking alone does not create a route. Save/load must retain these derived heights and connections. Extend each post down to the actual seabed, including rotated and offset shoreline placements. Keep the ordinary two-Log frame price and add whole Logs for each post's reach below the waterline, using the existing rigid timber length. Use the same cost for construction, moves, saves and recovery. A moved frame recovers its original paid timber and needs additional supply for deeper foundations.

Show the longer posts in placement previews, construction and completed structures. Darken submerged wood with a short damp transition at the actual sea level; keep the deck and dry timber colours. Preserve fitted bearings, connected deck navigation and normal construction access from shore or completed floors. Keep costs in the existing menu/selection presentation and add no instruction panel or persistent goal display.

Follow-up confirmed 11 November: deep water must be economically unattractive for blanket Support construction. The underwater surcharge now grows quadratically per post: for `n` whole submerged Log lengths, charge `n + 2 * max(0, n - 1)^2` Logs, plus the ordinary two-Log frame. Four equally submerged posts cost 6 Logs at 0.75 m, 90 at 3 m and 226 at 5 m. Preserve previously paid construction materials and recover only what was paid; newly placed and moved foundations use the new depth price.

New generator-version-18 worlds have seeded, broad reef shelves near the islands, including two potential village sites by the main island. Their cores stay roughly 0.5 to 0.84 m underwater, with irregular sloping edges returning to deep sea. These are actual submerged bearings shared by terrain, collision, timber pricing and rendering. Pale turquoise water and the visible shallow bed reveal economical places to build a village on poles. Reefs provide no free walking surface; players choose whether to extend a pier and build there. Preserve earlier generator versions and their existing foundations when loading saves.

## Building miniatures and room capacity — 11 November 2026

Building-menu symbols use solid coloured isometric miniatures that share the resource palette. Show recognizable architectural purpose: open timber stores and their cargo, oven rooms with chimneys, the Mill's white sails, a shallow blue Well opening, and a suspended plank bridge. Keep the existing 34-point slot and icon/name-only rows; costs and benefits stay in their hover tooltip. The Housing and Structure category symbols use the same miniatures. Action symbols retain their existing treatment.

Each 2 × 2 × 2 m Home room now provides **one resident place and four Food spaces**, superseding the earlier three residents/twelve Food rule. Count joined rooms and floors by those values: four rooms provide four places and sixteen Food spaces. New-game Food must fit the four-item limit. Preserve existing citizens and already stored supplies when loading older saves; extra residents need additional housing and overfilled legacy food prevents new deliveries until space is available.

Well hover and selection show only its name and one Water current/capacity row. Remove the rain-rate line from those object tooltips. Keep the existing rain simulation and placement-preview behavior. The Stacked Homes practice map must remove its temporary construction funding inventory before play and start with small supplies in real stores, respecting both shared and per-resource capacities.

## Town identity — 10 November 2026

The game has grown beyond its original monument-building inspiration. Use **... Town** as a provisional title, as suggested by the user; the final name is undecided. The intended icon subject is a cozy roofed building whose room core is 2 × 2 × 2 m, readable at small sizes.

Follow-up: the generated cottage icon does not depict an actual building in the game. The user found it irrelevant, generic and too visibly AI-generated. Treat it only as a temporary placeholder, not an approved architectural or visual reference. Its cream walls, terracotta roof, chimney and lit window do not establish requirements for game buildings. Once the overall style guidelines are defined, replace it with a render of an actual in-game 3D model using the game's established materials and presentation. Do not generate another invented cottage as the final icon or redesign buildings to match this placeholder.

The current visual direction is moving toward **ShantyTown**, building on the existing reference for stacked, assembled, lived-in architecture. This is an evolving direction; the overall styling is not yet settled. Develop the game's own models and visual language before finalizing branding.

Remove the old name and monument imagery from active player-facing branding. Earlier reference research below records provenance, not the current game identity or a mandate to reproduce another game's goals. Preserve existing save directories, deterministic generation seeds and serialized format identifiers for compatibility. Do not add a tagline, goal display, instruction panel or new menu content.

## Connected-room buildings — 10 November 2026

Confirmed follow-up: **add generated building plans alongside existing Houses**. Generate different connected 2 × 2 × 2 m room layouts, exact two-metre storeys, upper footprints and open roof terraces. Entrances join directly through shared walls. Reserve structural and chimney space before placing windows; supports must never pass through openings. Slight colour differences stay within the official material palette. ShantyTown and High Above inform assembled architecture and inhabited rooftops, not copied assets.

Every visible object needs a role, a cost and connections. Do not add nonfunctional AC units, pots or furniture to imply activity. Existing bricks and planks are canonical stock; make masonry equipment from ordinary bricks. Stable seeded corner variations and sparse saved overrides preserve a component's identity without storing individual mesh data. Render detail according to projected size; retain semantic state independently. The hierarchy is component/utility → room → building → town.

Material availability should unlock building upgrades without a research tree. Ore, processed metal and manufactured equipment must have distinct roles in one economy. The inspection scene demonstrates a brick stove/chimney becoming metal equipment and routed pipes. Its six-piece metal supply remains a test source; this pass does not implement smelting or connect stove upgrades to the settlement economy.

Warm window light and exterior lanterns reward construction, then finite initial charge dims and expires to communicate missing utility work. The inspection scene has physical lights, a socket and a visible cable to a test terminal. Charge and resource amounts are provisional. Main-game generated plans currently integrate rooms, terraces, stairs, real beds, labour, construction materials, navigation and saves; power and stove utilities remain in the fixture.

Keep `ModularHousePrototype.tscn` as a visual regression and utility inspection scene sharing the generator and stock geometry with the main game. It now generates layouts rather than showing only the original fixed arrangement. Remove demonstration furniture without gameplay roles. One-metre braces and pillars beyond that reach remain provisional support rules. Existing House construction is retained. See [implementation, object ledger, persistence and limits](GENERATED_BUILDINGS.md) and [fixture controls](MODULAR_HOUSE_PROTOTYPE.md).

## Main-game fitted Supports and Greece islands — 10 November 2026

The user requested slight relative Support rotation, older-building priority, main-game integration and a Greece-like map with water, shorelines, small islands and mountains. Supports remain metre modules; new completed structures record bounded group identity, construction order, position offsets and a small yaw. A shared world-space assembly fits only newer bearing endpoints to older logs within 0.15 m. Rotation does not merge separate group identities. Keep projecting posts, visible bearings and varied plank direction. Use actual fitted timber for picking. Protect an owning module from removal/relocation while a neighboring group borrows its logs. Moving the newer module gives it fresh destination ownership; saves preserve all these fields.

During new Support placement, `[` and `]` adjust structural yaw by 2°, limited to ±15°. Shift allows continuous cursor positioning within the current metre address instead of snapping the visible model to its centre. Keep the existing quarter-turn R action for board direction. Validate rotated footprint overlap and each footing; do not silently rotate or move existing structures. Moving existing construction preserves its recorded angle. The main simulation retains its established alternating two-metre floor/deck rhythm, occupancy protection and explicit stair access. Navigation follows the saved deck centre and rejects seams without a continuous citizen-width strip; a shared post never grants a route across an open gap. Internal spatial addresses remain integers. This is a Support-specific placement extension, not arbitrary-angle wall/building editing.

New Fields (Easy/Greece) worlds use generator version 6: a supplied flat starting island, smaller surrounding islands, uneven mountain shelves, sandy shorelines and turquoise sea. Shared shore vertices follow the continuous coastline rather than square-cell steps. Shore water has a deterministic seabed, shallow foundations remain distinct from deep water, and saltwater is not drinking inventory. Sea rendering uses the same shore-distance field, including western/southern coastlines. Save and streaming preserve the selected generator; version-4 Greece coasts and version-5 Sand worlds keep their original geometry. New Sand retains the existing terrace algorithm.

Follow-up confirmed 10 November: bring the sandbox’s irregular solids and Support excavation into the main game. New Fields worlds now use generator version 7, with the same closed polygon plateau, ridge and fractured fin geometry shared with the sandbox. Flat shelves are broad on selected sides, disappear into steep cliffs elsewhere, and project beyond narrow supporting rock. Preserve multiple exposed walking elevations within a column. Keep the supplied starting clearing, smaller surrounding islands, sandy sheltered edges, and a narrow turquoise shallow-water band; remove the repeating sea rings. Existing version-4/6 Fields and Sand worlds retain their original terrain.

Support construction removes its actual one-metre positioned/rotated volume only at completion, through normal worker/material construction. Aim at an exposed rock face; buried remote sites are rejected. A pair stacked to two metres gives citizen clearance, while single-metre openings do not. Navigation tests the actual opening and its connection to outside ground, including off-grid offsets and surviving rock slivers. Rendered geometry, picking, collision and the solid query share the same source. Excavation survives timber removal, save/load and chunk unloading; cancelling an unstarted blueprint does not excavate. Keep existing Support joining, ownership, costs, and clean UI. Separate excavation labour stages, resource yields, flooding, collapse and underground visibility tools remain unspecified future work; do not invent material rewards.

### Seeded island variety and generator choice — 10 November 2026

The user approved the overall island direction but rejected the smaller islands as copies of one mountain. Generate distinctive shapes automatically: wide terraces on one side, cliffs dropping directly into water on the other. New Fields maps use generator version 8; version 7 remains available for existing saves, including its excavation records. Keep the supplied main-island clearing and the accepted main mountain in this pass.

Small-island generation combines four varied forms—elongated headlands, indented coves, twin summits separated by a saddle, and compact bluffs—with independently seeded coastline vertices, aspect ratios, orientations, heights and shelf widths. Pin exposed contour vertices across heights to create continuous sea cliffs, widen shelves and beaches on the sheltered flank, and apply localized undercuts. Each map uses every form once, with seeded ordering and geometry. This is an independent GDScript contour/solid generator, using the existing shared mesh, collision, navigation and construction-excavation pipeline. No new controls or persistent UI. Validate closed solids, actual sea cliffs, flat shelf area, multiple seeds, deterministic chunk generation and old-save compatibility.

Generator research used primary sources:

| Candidate | Fit for this game |
| --- | --- |
| [Voxel Tools](https://github.com/Zylann/godot_voxel), [graph generators](https://voxel-tools.readthedocs.io/en/latest/generators/) | The closest external runtime candidate: editable volumetric terrain supports caves and overhangs. It supplies a terrain backend; our terrace/coast shaping rules would still need implementation, along with migration of the current simulation and saves. Retain as a candidate for a broader volumetric-world redesign. |
| [Terrain3D](https://terrain3d.readthedocs.io/en/stable/docs/introduction.html) | Efficient editable height-based terrain. A heightmap cannot represent the multiple elevations required by our overhangs and tunnels without additional geometry; see [Godot’s heightmap limitations](https://docs.godotengine.org/en/stable/classes/class_heightmapshape3d.html). |
| [Tivolt’s low-poly terracing method](https://arxiv.org/abs/2505.09350) | Relevant visual/algorithmic research using irregular vertices and terraces; its published implementation is Unity/C# and height-based. Reviewed as a reference, not imported or claimed as the implementation used here. |

Selected approach: generate new contour solids directly in Godot. It addresses island variety while retaining the already functioning construction excavation and exact flat building elevations. No external generator dependency was added.

### Generated main island — 10 November 2026

The user rejected the main island's flat round foundation with a separate mountain. New Fields worlds use generator version 9: the same seeded contour-solid generator now constructs the main island, including several bays, unequal headlands and independently shaped coastal terrace regions. Raised shelves share the coastline so exposed walls drop straight into water; inland edges vary independently in width and bend, with genuine projecting lips. Split shelf tips must retain a bearing on the rock below. Protect the starting house, workers and resources within an accessible lowland, and retain sheltered shore access. This supersedes the version-8 decision to keep the old main mountain.

Keep versions 7 and 8 available for existing saves and future streamed chunks. Support construction, excavation, collision, navigation and water foundations use the same generated solids. Do not reshape established settlements or add terrain controls, instructions or other persistent UI.

### Broken coastal shelves and erosion stone — 10 November 2026

The user rejected the version-9 main island's long parallel steps. Version 10 replaces the island-wide terrace strips with separate coastal masses: offset broad plateaus, smaller headlands, narrow fractured peaks fitted to supporting shelves, deeper intervening bays and local overhanging lips. Keep the starting lowland and use actual closed solids for terrain, navigation, construction and excavation. Prior versions retain their saved terrain and stone geometry.

Add a narrow muted water-contact colour band that fades into the sea, including around emergent coastal rocks. Coastal rock groups grow from the seabed beside exposed cliffs. They are terrain outcrops, not floating props or new mining inventories. Inland finite Stone deposits become low, fractured boulder groups rather than stacked block pillars. Rendering, collision, occupation and mining share their shape; depletion removes the corresponding volume while preserving finite goods and reservations.

Place usable deposits through geological rules: below exposed cliff faces, on sufficiently broad dry lowland, with space for a nearby Quarry within its existing eight-metre work range. Validate citizen routes and an available quarry footprint; recheck access after all patches are placed. Fresh erosion patches suppress generated vegetation locally. This is seeded cliff-foot/talus placement, not a simulation of hydraulic erosion. No random fallback deposits on unrelated flat ground, resource yields from Support excavation, new panels or permanent controls.

### Raised shoreline and wind-driven sea — 10 November 2026

The user wants the lowest land to read clearly above the water and visible waves travelling with the wind. Set the rendered sea to -0.65 m beneath the zero-metre walking floor, replacing the almost flush -0.18 m surface. This raises the apparent shoreline by 0.47 m without moving saved terrain, buildings, citizens or excavation. Move the contact band and coastal-rock waterline contours to the same sea level. Existing logical water-foundation volumes remain intact.

Use short, broken wave crests and broad surface shading, advected together along one consistent wind vector at 1.25 m/s. Keep the low-poly palette, a narrow water-contact band and calm readable shores. This is animated surface shading, not simulated water displacement or buoyancy. Wind parameters are internal; do not add a control panel. The water continues its ambient animation with the rendering clock, like vegetation.

Retain the user's large drifting icebergs/flat ice sheets as a later direction: seasonal shrinking or melting could reveal changes around the island. Building on ice is explicitly undecided. Do not implement ice buildings, moving navigation, seasonal hazards or resource systems from this exploratory suggestion; see FUTURE_IDEAS.md.

### Sheltered bays, surf and clear shallows — 10 November 2026

The user selected [Sandcastle](https://store.steampowered.com/app/3216520/Sandcastle/) as the water reference: waves responding to coastlines, small foam patches at rocks, calmer bays and semitransparent water. Use its clear shallows and soft surf as visual direction within our illustrated palette.

Main-game solid islands now bake a world-space distance/exposure field from their actual concave coast polygons and emergent rock waterlines. Upwind fetch and surrounding land reduce wave shading in coves and behind headlands. The field rebuilds only when the layout or configured wind changes. Short foam pulses travel toward the coast and break around rocks, replacing the static contact-colour strip. Depth-buffer contact also catches opaque structures at the water surface.

Depth-dependent alpha reveals submerged rock and a sloping sandy bed with restrained moving light; distant water becomes opaque before the bed boundary. The bed is a smooth visual approximation of the existing one-metre-plus-shore-distance/6 foundation profile, not a new collider or change to Support footing rules. Saves, walking floors, excavation, water inventories and terrain generation remain unchanged. These are shoreline-aware rendering effects, not wave displacement, tides, refraction, erosion, fluid simulation or buoyancy. No new controls or persistent UI.

### Small rolling waves, fewer rocks and visible starting water — 10 November 2026

The user rejected long white wave lines. Offshore wavelets now use short, low-contrast blue highlights. Near land, localized packets roll toward the coast along its distance field. Each packet arrives, produces a brief foam patch, then disperses completely before the next arrival. Keep sheltered bays calmer and shallow water translucent; foam is not a permanent outline.

New version-11 Fields maps retain version-10 island landforms but reduce emergent coast rocks from three per group to two, with one group per island. The main island has two accessible geological quarry patches instead of four. Preserve older generators, existing saved deposits and their finite inventory; do not remove rocks supporting an established settlement.

Starting puddles already exist and contain water, but solid islands' flat soil samples caused their hollow-clipped water mesh to be empty. On these islands, render the existing puddle as a shallow visible surface above the land cap; Sand keeps its actual hollow mesh. Verify a full reachable puddle near the starting citizens across seeds, and collection/delivery once a storage vase is available. Do not add starting goods, perpetual water, new controls or tutorial text.

### Island menu and visible house floors — 10 November 2026

The user requested the new landscape on the main menu and in gameplay, and flagged the apparent missing floor in the example house. Generate the latest Fields islands for the launch/return preview and direct normal game launch. Frame the main island and surrounding water in the menu. Fields is now the first landscape choice, retaining the aligned Play → first slot → first landscape flow; Sand remains available. Fields starts the exact offered, unplayed preview. Continue preserves each saved settlement's terrain and camera; gallery/showcase fixtures retain their intended landscape. No new labels or panels.

Ordinary assembled houses now place their actual plank floors at the existing 0.06 m walking height, instead of underneath the opaque land cap. Reuse the same board stock and room geometry for ground and raised houses, without moving building addresses, walls or citizens. The detailed board batches and simplified floor agree on their top surface. Other room prototypes keep their own existing floor settings.

### Compact village land and upward expansion — 10 November 2026

The user wants uneven terraces and bays near the starting village, enough opening build space, and a reason to build upwards. New Fields maps use generator version 12. Replace the large protected flat square with a smaller irregular village clearing, deepen the main island's bays, and add unequal local 2 m shelves with a smaller 4 m overlook. Keep the starting house, citizens, timber and reachable freshwater clear of rock. Older saves retain their selected generator.

Use land scarcity and convenient upper surfaces as the incentive: keep flatter lowland pockets available for larger footprints and cultivation, while ordinary stairs make nearby terraces useful for houses and workshops. Existing rooftop construction and Supports offer further expansion without consuming more ground. Do not add elevation bonuses, forced goals, tutorials, taxes or a replacement progress display. Verify usable upper building plots after stair construction, enough connected early building plots, space for a full-size hay field, two accessible quarry sites, and save/load on the new terrain.

### Connected coastline and blended shelves — 11 November 2026

The user rejected the star-shaped main island with separate arms. New Fields maps use generator version 13: replace the five regularly spaced deep cuts with two unequal coves on adjacent flanks, a shallow indentation on the opposite coast, and seeded broad contour variation. Keep a continuous backshore instead of isolated radial headlands. Overlapping terraces at the same elevation are united before constructing their closed solids, so they share a continuous cap and outer cliff rather than internal walls. Retain irregular shelf widths, narrow peaks, overhangs and the compact protected village.

Preserve starting timber, reachable freshwater, opening building and field space, and stair access to useful upper plots. Quarry patches still require erosion at an exposed cliff foot, dry space and actual citizen/building access. On the new coast, protect ten metres around the actual starting house instead of excluding an origin-centred square that can discard valid cliff feet. Keep two finite quarry patches and sparse coastal rocks. Check coast connectivity/compactness and merged shelves across seeds; existing saves retain their previous terrain generator. No new controls or goal UI.

### Dry islands and bare upper terraces, 11 November 2026

New Normal (Sand) games use the connected solid island generator in version 14, with sandy lower surfaces and warm exposed rock. Fields retains green lower shelves. In both landscapes, the third two-metre terrace (6 m above starting ground) and higher surfaces are bare rock with no generated grass. Retain the existing coastline, overhangs, construction excavation, translucent sea, freshwater and two reachable quarry patches. Normal uses its existing vegetation mix without a grass carpet. Existing desert and island saves keep their saved generator and landscape.

Hide the Stove fuel countdown and add-log hover text, including its empty tooltip container. Keep stove interaction and visible activity. The user requires no em dashes, emojis or bullet-dot separators in responses or new UI text.

### Green terrain elevation, 11 November 2026

Fields terrain uses richer green near sea level and progressively lighter green
on raised grassy shelves. Colour follows world height so flat surfaces at the same
elevation share a shade, making a raised terrace distinguishable from lower ground
behind it. Keep sandy shores, dry islands and bare upper rock unchanged. Try this
colour separation first; terrain outlines remain a fallback if needed.

### Broader terrace bases, 11 November 2026

New island worlds use generator version 16. Terrace walls taper inward from a
broader base to a narrower flat top, replacing the repeated narrow neck and
projecting cap that made the land look like mushrooms. Keep irregular outlines,
unequal shelves and vertical sea cliffs where the coastline pins the wall.
Fit mountain peaks to the actual smaller caps. Existing saves retain their
generator geometry and construction positions. This supersedes the earlier
direction to give every generated shelf a projecting lip.

### Dipping strata and blended mountain foothills, 11 November 2026

The user rejected hair-thin green lines between cliff layers and terrain that always runs parallel to sea level. New generator version 23 allows diagonal strata and gently curved grassy uplands, with a softer soil-to-mountain transition and taller broad crowns. Preserve the protected starting village, nearby level construction terraces and reachable quarries. Do not return to detached narrow fins.

On exposed small-island flanks, intermediate contours interpolate along the sloping cliff instead of forming a thin horizontal annulus. Seeded tilt and gentle curvature carry through the upper profiles while beach and submerged feet stay fixed. Main-island foothills begin farther inland, rise continuously instead of snapping to half-metre bands, and blend grass into bare rock before six metres. Higher broad crowns remain connected to submerged mountain feet. A world-space soil-clearance field removes thin green rims beside higher cliffs without subdividing solid meshes; this survives Support CSG cuts. Gentle ground relief records four corners plus a sampled centre for walking and persistence, while uneven ground still requires a level construction footing. Older generator versions retain their geometry and surface treatment. No new controls or persistent UI.

### Turquoise reef, sandy patches and deeper channels, 11 November 2026

The user rejected the white, even coastal band and the bright polygon pedestal beneath steep islands. Sea shading now uses a more saturated turquoise tint with less pale reef highlighting, while retaining transparency near shore. World-space warped sand patches interrupt the darker seabed. Submerged sand and rock converge toward the same dark teal at depth, with increased water absorption hiding the hard material edge at a rocky island's underwater foot. These visual changes also apply to existing island worlds; freshwater shading remains unchanged.

New generator-version-22 worlds vary the coastal shelf width more strongly and add seeded, gently bending deeper channels across selected beach shelves. Channels begin beyond the immediate beach, preserving continuous near-shore access and other shallow sites for piers. They are physical depth changes shared by visible geometry, collision and foundation cost, not painted stripes. Validate their depth against adjacent shelf samples, retain buildable shallow areas, and preserve saved worlds through version 21 without reshaping their terrain. No added UI, resource patches or isolated satellite reefs.

### Fractured slopes and a continuous coastal reef, 11 November 2026

The user rejected the remaining smooth rock ramp and the detached shallow-water ovals. New generator-version-21 worlds divide the rocky flank into irregular fracture faces with bounded height variation and low ledges embedded in the parent slope. Their uphill sides remain buried; no narrow peaks or freestanding fins return. Keep broad usable terraces on the sheltered side, existing village clearance and inward-leaning sea cliffs. Preserve small joining triangles so added fracture cuts remain closed for collision and Support excavation.

Replace detached reef sites with one continuous submerged shelf following the main island. Its width varies with the seeded coastline and exposure: broad along sandy beaches, narrow beneath mountain cliffs, then rolling down into deeper sea. The island's real submerged apron and offshore bed meet at the same heights. Rendering, collision and foundation pricing share that profile. Small islands keep a narrow ordinary underwater foot without extra reef patches; leave enough water between islands for the main reef to taper away. Shallow shelf areas remain available for physical piers and buildings, without free walking surfaces or new resource inventories.

Blend the submerged beach's sand colour into the offshore seabed and keep moving underwater light subtle, avoiding a visible material ring at the mesh join. Decorative water stones remain separate from collectible quarry deposits. Existing worlds through version 20 retain their saved terrain and reefs. This supersedes the earlier two-detached-reef-sites direction. No new UI or controls.

### Continuous rocky mountain shoulders, 11 November 2026

The user rejected flat stepped mountains topped with thin shark-fin shapes. New version-20 islands remove the separate peak meshes. Broad upper shoulders grow from the submerged cliff foot, taper inward, and finish in wide uneven crowns. Scale setbacks to each clipped footprint so small coastal fragments cannot collapse into narrow teeth. The exposed side remains steep, while the sheltered side retreats toward a wider usable terrace.

The main four-metre bench stays flat on its sheltered side and rises into a continuous rocky back along intersecting geological folds. Split the geometry at each slope transition so the building terrace remains exactly flat and all rock edges remain closed for collision and Support excavation. Use lighter upward-facing rock facets to show the slopes, without new surface textures or UI. Preserve the starting village, upper stair access, dry sand mode, water rocks, reef sites and sloping beaches. Existing saves through version 19 keep their original terrain. This supersedes the earlier elongated-blade direction.

### Sculpted mountain levels and decorative water stone, 11 November 2026

The user requested natural-looking stones in the water for scenery only, outside ordinary citizen gathering, and another pass toward the supplied ISLANDERS terrain reference. New Fields and Sand islands use generator version 19. Keep a broad usable middle bench, then raise offset coastal masses on selected sides with unequal heights and footprints. Elongated fractured blades have narrow, sloping crests instead of repeated cone peaks. Preserve inward cliff slopes, tall exposed sea walls, the sloped submerged beach, protected village opening, usable stair landings and both shallow reef building sites.

Seed small clusters beside exposed rock coasts, checking farther inland to account for inclined cliffs. Include a dominant exposed slab, a smaller fragment and a submerged stone with wide buried feet and compressed broken crowns. Fit them to the physical seabed, vary their spacing, and include exposed outlines in the existing wave-contact field. They are decorative terrain solids, not finite Stone deposits. Do not create walking surfaces, gathering jobs, inventories or additional quarry deposits on them. Keep two reachable quarry deposits on land. Preserve the terrain and seeded geometry of saves through version 18. No new UI or gathering mechanic.

### Inclined cliffs and submerged beaches, 11 November 2026

The user rejected perfectly vertical terrace walls and a raised step at the beach. New island worlds use generator version 17 in both main-game modes and the menu preview. Closed terrace solids now lean inward from a submerged foot to their cap, including exposed sea cliffs. Strict contour validation checks both triangles of each side face so concave corners cannot silently fall back to vertical walls. Keep tall exposed cliffs, unequal shelves, narrow peaks, separated islands and the protected starting village with freshwater, timber, quarry access, a full field and usable upper plots.

Beaches slope from the dry zero-metre floor through the mean waterline at -0.65 m to submerged island bases at -4 m. The offshore floor continues from those bases and supplies both visible geometry and collision; material and foundation queries sample the same physical bed profile. Clip the offshore mesh outside island bases so it cannot overlap beach slopes or make jagged depth seams. Water alpha fades at thin contact with land. Keep walking cells off steep cliff crossings and below-water beach corners, and preserve their sloped shapes through saving.

Check beach contact at water levels -0.8, -0.65 and -0.5 m. This prepares the geometry for a small future tide; automatic tides, flooding and floating structures are not implemented. Support excavation still cuts the terrain through construction. Saved worlds through version 16 retain their original generator and landscape. No new controls or persistent UI.

### Unique island layouts and uninterrupted sea cliffs, 11 November 2026

The user identified that Sand reused the Fields layout and requested much stronger ISLANDERS-inspired variety, especially coastlines where roughly half the land rises directly from water into tall cliffs. Version 15 replaces the main island's fixed plateau positions with seeded proportions, rotation, bay placement and width, cliff orientation, uneven adjoining coastal blocks at different heights, displaced shoulders and one to three rock blades. Preserve a protected opening village and its timber, freshwater, farm space and usable stair expansion. Retain the existing rock-only rule at 6 m and above.

Pin exposed shelf edges to the actual coast and extend their solid walls below sea level. Beach width becomes zero along those tall cliff edges; only sheltered shores retain sand. Smaller islands vary their size and position and move outward when necessary to retain a water gap. These are deterministic contour solids shared by rendering, navigation, foundations and Support excavation, not erosion simulation or copied game assets.

New games choose fresh seeds. Fields starts its offered preview; choosing Sand rolls its own seed rather than recolouring that preview. A saved seed recreates the same island, and Continue never reshapes an existing settlement. Preserve generators through version 14. Verify significant silhouette variation, closed geometry, tall shore cliffs, starting resource clearance, separate islands, reachable quarry sites, field space, stairs, excavation and save/load.

## Freeform terrain and tunnels sandbox — 10 November 2026

The user rejected the gridded terrace result as looking like OpenTTD. Terrain should have distinctive irregular low-poly outlines and broad authored facets without visible cell steps. It must support removing material below the surface while retaining rock overhead, including actual tunnels with floors, ceilings and side walls. A single height per horizontal column is insufficient for this direction.

The user chose a playable isolated sandbox before replacing main Sand terrain. `scenes/terrain_sandbox/TerrainSandbox.tscn` uses closed polygon landforms, real collision, Undo and separate sandbox persistence. Shelves have unequal widths/heights, independent contours and offset crowns. The initial two-point freeform tunnel brush was superseded by Support construction below. Keep the warm palette, concise toolbar and four-point preview strokes. No instruction panel, goal display or building-configuration UI.

Follow-up: the user rejected the evenly layered pyramid and supplied an ISLANDERS screenshot as a shape reference. Use an asymmetric composition: a broad plateau beside a much narrower high ridge and fractured fin, wide low benches on selected flanks, and steep uninterrupted cliffs where those benches disappear. Include real overhangs with exposed undersides and air beneath them, both on the main plateau and a smaller high ledge. Author independent polygon profiles instead of shrinking copies of one contour. Retain the sandbox's existing palette; the screenshot is visual inspiration, not a request to copy assets or add its surrounding ocean, buildings or vegetation.

Construction follow-up: the user explicitly removed freeform tunnel carving. Buildings, particularly Supports, must define excavation. A Support may stand on a mountain surface or clear its own occupied volume inside it, leaving actual structural frames. Extend this structure to form interior passages; terrain is not edited with an independent arbitrary brush. The first construction experiment reused one-metre Supports and alternating decks; the size experiment below supersedes that sandbox behavior. Keep building alignment separate from irregular natural terrain.

Joining correction: the user clarified that **individual Supports remain 1×1×1 m**, with automatic removal of shared elements only within combined structures bounded by **2×2×2 m**. This supersedes the provisional two-metre single-bay experiment. A horizontal metre pair loses the intermediate legs and bearing; a vertical metre pair loses its middle deck and waist-high crossbars. Larger arrangements retain separate group identities and supporting boundary legs, with coincident/nearby legs shared under the follow-up rule below. Assign a new module to the oldest adjacent group it fits without exceeding the bound; never merge or repartition existing groups just because another module is added. Keep per-module records and deterministic group identity through saves and Undo.

Use the user's ShantyTown pier screenshots as timber arrangement references: visible Log bearings, separated and staggered rigid stock boards, slight irregularity and upright posts protruding above exposed decks. Seed a 0° or 90° board direction per module and persist explicit overrides; R switches that direction before placement. Do not randomly rotate structural footprints. The user is exploring arbitrary building angles and a convenient finer interior editor; arbitrary whole-building rotation and general wall trimming are not implemented here. Angled construction must eventually use actual face alignment and clearance, not remove walls merely because centres are close.

Placement favors existing construction: snap only the new proposal to an existing one-metre face socket within a provisional 0.16 m tolerance, oldest first on equal distance. Hold Shift for 0.1 m horizontal positioning without magnetic attachment. Exact aligned faces may merge parts within a bounded group; slight offsets between separate groups use the shared-post fitting rule below. Never move an existing building to accommodate a later plan. Keep these rules in the isolated sandbox; no main-game dimensions, construction stages or wall system are migrated. Version 4 records use `support-groups-terrain-sandbox.json`; preserve earlier files without resizing their structures.

Shared boundary posts follow-up: the user explicitly requested removing double legs between separate 2×2×2 groups while keeping their identities and giving the existing building priority. Keep the older group's corner log unchanged; omit the newer duplicate and fit its bearing endpoints to the older log. Deduplicate an exactly coincident boundary beam after fitting, also retaining its older owner. For slight off-grid mismatch, provisionally accept a horizontal corner offset up to 0.15 m on facing modules at the same floor height. This is geometric fitting, independent of placement snapping: neither building transform, footprint, deck nor excavation moves. Deck gaps remain real and do not imply a navigation connection. Larger offsets, differing floor levels and diagonal-only contact retain separate supports. Use the same fitted geometry for rendering and collision; save/load reconstructs ownership deterministically from original construction/group order. No arbitrary rotations or wall-fitting system is introduced.

The isolated sandbox now places Supports immediately, with physical voids limited to their footprints, foundation/overlap checks, actual timber picking and saved structure records. It provides no worker labour or resource rewards. Recovering resources while workers excavate for construction is the intended next exploration; exact yields, work stages and hauling behaviour remain unimplemented and unspecified. Do not mint resources simply by previewing or placing sandbox modules. Undo reverses prototype history, not an approved rule that dismantling buildings refills mountains.

This supersedes the earlier grid-sampled terraces as the desired landscape direction. The later version-7 main-game integration above now shares the polygon terrain and construction excavation as well as Support fitting. The sandbox remains an immediate-placement inspection fixture; settlement costs, workers, navigation and permanent excavation live in the main simulation.

## Faceted sandstone terraces — 10 November 2026

The user requested implementing the ISLANDERS-inspired terrain direction: replace the Minecraft-like square stone formations and small mountains with low-poly terraces. Retain the warm sandstone palette and open settlement clearing. Natural stone deposits use connected, chamfered shelves with level tops and broad shaded rock facets; retain their logical mining volume, resource amounts, reservations and support rules. Loose Stone cargo and dressed Slabs keep their existing models.

New Sand worlds have three broad terraces at 2, 4 and 6 metres with sloping faceted shoulders. Rendering, collision and navigation share the same sampled surfaces; flat terraces remain buildable, shoulders do not. Elevation still needs explicit access. Do not add surrounding oceans, green terrace caps or new goal/instruction UI as part of this change. This supersedes the tall single-column butte silhouette and the earlier exploration-only status of this visual direction.

Existing saves retain their saved land and generator version, including future chunk generation, so built settlements and dormant resources are not relocated. The new stone silhouette also applies to existing volume-based quarry deposits without changing inventory quantities.

## Resource shapes and construction benefits — 10 November 2026

Use distinct, solid coloured resource silhouettes in construction costs, material categories, stock counters and selected-object readouts. Match the world's material palette: full-length brown logs and narrow light boards, golden tied hay, a blue water drop, pale stone/slabs, flattened clay, rectangular brick, dark faceted ore, a flour sack, terracotta vase and curved Imbrex, rope coil and bread. Keep berries small relative to the log reference; food remains one inventory resource. Natural harvestable Grass shifts from sage green toward golden hay, retaining its geometry, wind and finite yield. Clay and Ore should also differ in world profile, rather than being identical recoloured rocks.

Each construction card shows negative material quantities and a compact benefit: resident places, water/storage capacity, gathered material or an input → output chain. Houses provide space for later births; workshops require their inputs and work. Storage capacity is shared by its resource pair. Wells show the possible shallow capacity range in the menu and retain exact location-dependent capacity at placement. Selected completed workplaces show their resource chain; ordinary hover stays name-only. Keep existing discovery, unlocks, point sizes and hidden goals/instructions. Do not introduce a permanent label over every building or a configuration panel.

Keep current game prices while recording discrepancies against the attached Numbers table, including the missing Sawmill Hay charge. `docs/BALANCE.md` identifies the authoritative settings and current gaps; spreadsheets are review copies, not automatically loaded game configuration.

## House, floor and room selection — 10 November 2026

The user requested the demo's three-stage hierarchy in the main game and explicitly approved implementing selection. Clicking a completed house first selects the whole joined structure across its levels. Clicking a specific level next selects that floor; clicking a room on that floor selects that room. Further same-floor clicks select sibling rooms without restarting. Clicking another floor selects that floor; clicking another house starts at its whole structure. Empty-ground clicks and Esc retain their existing deselection behavior. Selection does not move the camera or enter interior editing.

For the current house modules, one inspection household includes existing same-floor doorway joins plus aligned houses stacked directly at the two-metre storey interval on a supporting house tier. A touching wall, a gap, a pipe or a nearby stair does not merge separate houses. Grouping never creates pedestrian access: stairs and entrances still determine reachability. Physical room addresses, residents and inventory locations remain intact through saves. Same-floor roof and post sharing keeps its existing grouping. Mixed-purpose buildings and explicit persistent household ownership beyond this connected house grouping remain future model work.

Keep the existing yellow, four-point floor brackets, drawing each selected level's footprint at its own elevation. The object label uses House, Floor or Room without floor numbers or a new permanent panel. Resident and food totals follow the selected scope. Move, Copy and Remove use exactly that scope, retain normal support/access restrictions, and never silently widen a room selection to the whole house. A stack whose lower floors support upper construction still cannot be relocated or dismantled as a unit under the current job rules. Copy keeps the existing construction rules; selecting a stack does not bypass the need for valid destination supports or unlock higher house tiers. Upgrade is available only when one room is selected.

This supersedes the selection-only portion of the earlier concept-only direction. Local dollhouse cutaways, interior placement and new utility systems remain interaction design work. Proposed next direction: keep the current orthographic camera on entry; reveal the active floor by removing upper geometry and shortening camera-facing walls; preserve solid lower floors and nearby stairs as landmarks. Keep viewed floor separate from selected room and lock an active placement to its floor. Floor-level construction should host shared stairs, lift landings/shafts and utility routes, while room-level construction hosts furniture and equipment. These tools and their exact controls are proposals, not implemented features or newly exposed menus.

## Puddle assignments and fewer Sand rain hollows — 7 November 2026

Assigning an adult citizen to a Puddle means repeatedly collecting its water and physically carrying it to a reachable compatible store, including a House with free water vessels. Keep the selected source through meals and save/load; wait when it is dry or storage is unavailable, and resume when water or capacity returns. A different work or movement order clears the assignment and releases uncollected reservations. If storage fills during a delivery, retain the carried water and try another compatible store rather than dropping it as loose supplies. Preserve the existing household pottery/vessel capacity rules and the separate general water-collection action. No new work panel or instructions.

Generate fewer rain-collecting hollows on Sand terrain. Initial tuning retains a deterministic 25% of eligible natural soil hollows, shared by initial generation and new streamed chunks. Keep the guaranteed opening Puddle, existing generated water sources and streams, Easy terrain density, rain behavior, and water already present in saves unchanged.

## Alternating Support decks and citizen escape — 7 November 2026

The user clarified that a vertical column of metre-sized Supports should retain walking decks on every second module: modules 2, 4, 6, etc., or modules 1, 3, 5, etc. A solitary Support keeps its deck. Placing Support on an existing open frame restores that deck immediately for free and shifts that column's deck pattern; preserve the chosen pattern through saves. Aiming at the frame's side targets restoration, with a deck-only ghost; aiming at its top still stacks a new module. Decks directly beneath Stair stay absent. Rendering, walking surfaces and headroom must use the same rule. Protect occupied changing floors, active crossings and attached bridge landings. Later stacked modules must not block construction merely because a builder stands on a retained floor. No new configuration panel or persistent instructions.

If construction strands a citizen on a roof or disconnected surface, allow a recovery climb up or down a clear ledge of at most two metres to regain settlement access. Use continuous movement, preserve cargo and save/reload progress, and resume or safely release the previous job. Reject obstructed climbs and larger drops; ordinary routing continues to use existing stairs, slopes and bridges. Side-mounted balconies and general terrain/building attachment remain design work, outside this implementation.

## Housing enables births — 7 November 2026

Completed, reachable housing with spare resident places is sufficient for children to arrive. Remove the food-reserve requirement: births continue even with empty food stores. Keep the 120-simulation-second interval, three places per completed house, existing population limit, reachable house-access spawn, and childhood maturation. Preserve earned birth progress in existing saves. Food gathering, storage and eating keep their existing rules. This supersedes the food-gated birth rule in the 19 October residents section; add no UI panels or instructions.

## Construction menu resource groups — 7 November 2026

Group current construction choices by resource family and purpose. Log contains Sawmill for the Log → Plank chain. Storage contains Shed, Barn, Depot and Brickyard, keeping dedicated stores together. Clay contains Claypit, Pottery, Kiln and Tilery. Hay contains Field, Mill, Bakery and Rope maker. Stone contains Quarry, Masonry and Mine. Retain Housing for House and Well, Structure for Support, Stair, Road and Rope bridge, and Nature for Tree seed and Palm seed. Each choice appears once; group by building purpose rather than every material in its construction cost. The current Mill is the windmill used by the hay-to-food chain; do not reintroduce the legacy Windmill as a second menu entry.

Use the existing compact category toolbar and building lists, with resource or storage icons and short group labels. Preserve producer-completion unlocks, zero-stock planning, resource discovery and hidden instructions/goals. This changes menu organization only.

## Conceptual settlement loop, room editing and cutaways — 7 November 2026

Saved at the user's request as conceptual direction only, without implementation. Aim for an approachable, semi-casual vertical settlement game in which a small community improves its everyday life. Stacking provides space; usable interiors, access and utilities should give that space purpose. Explore the tension between maintaining daily life and spending the same citizens' time on expansion and improvements. Better living conditions should have visible benefits, potentially saving carrying time, improving recovery and allowing leisure, rather than merely increasing production demands. These are design hypotheses, not approved balance rules or a new victory objective.

Use [Whiskerwood](https://store.steampowered.com/app/2489330/Whiskerwood/) as a reference for terrain, settlement growth and citizens' needs, and [Space Haven](https://store.steampowered.com/app/979110/Space_Haven/) for functional interiors and arrangements that affect daily life. Preserve our three-dimensional vertical world and readable building behaviour. Do not turn the game into a conveyor-belt factory or add goods-delivery vehicles. Citizens remain the baseline carriers of solid goods; utility pipes fit the direction. Pneumatic delivery remains an idea to test, not a committed transport system.

Keep hunger and nighttime danger, including the original Pyramida's incapacitating enemies described by the user, as ideas to test. Neither combat nor a new hunger/recovery loop is approved for implementation here. Explore readable consequences and recovery paths so a setback does not leave every citizen unable to restore essential supplies. Exact night routines, enemies, penalties and recovery rules remain undecided.

The next design focus is how room editing and cutaways would work in a densely stacked city. Explore floor- and wall-mounted equipment, operating clearance, reachable entrances and utility connections as a small spatial puzzle. Study room selection, local cutaways, placement feedback and tracing a selected pipe between levels while preserving orientation. Ready-to-place buildings with editable interiors are a candidate accessible entry point; this does not reopen the general room-construction toolbar removed on 6 November. Keep the current runtime, UI and saves unchanged. No replacement goal display, instruction panel or complex building configuration is authorized.

See [the concept questions and ideas to test](../FUTURE_IDEAS.md#settlement-life-room-editing-and-cutaways--7-november-2026). Work next on the interaction design, not an implementation or prototype build.

Follow-up: the user endorsed retaining the bedroom walkthrough as a promising conceptual direction, not a final control specification or implementation request. Separate revealing a hidden place from editing it. Select a visible part of a building when possible; for a fully concealed target, explore a temporary section view that reveals actual rooms before selection. Once selected, keep the building's cutaway stable, with upper storeys removed, lower storeys solid, camera-facing walls shortened and neighboring rooms/stairs available as orientation cues. Hover previews boundaries without changing geometry. Preserve camera position and angle on entry; floor changes preserve horizontal position, angle and zoom. The viewed floor and editing selection are separate: switching floors does not move equipment or automatically select a new room. Remember room/object selections per floor during inspection and restore them on return. Lock placement to its active floor until confirmed or cancelled. Restore the exterior and pre-inspection camera when leaving, and remember the building's last inspected floor for reopening. Exact controls, selection-memory lifetime beyond a session and the initial section's scope (local neighborhood versus wider horizontal slice) remain open. See [the retained walkthrough](../FUTURE_IDEAS.md#bedroom-walkthrough-retained-concept--7-november-2026).

## ISLANDERS inspiration, spatial depth and self-explanatory buildings — 7 November 2026

Keep [ISLANDERS](https://store.steampowered.com/app/1046030/ISLANDERS/) as a future visual and terrain reference. The user particularly likes its low-poly mountain terraces surrounded by water, appealing style and distinctive buildings. Explore limited buildable terraces and surrounding water as a natural source of land scarcity. This is inspiration for future terrain work, not an immediate implementation task or a decision to adopt its casual city-building loop. See [the saved idea and revisit triggers](../FUTURE_IDEAS.md#islanders-terraces-and-scarce-buildable-land--7-november-2026).

Continue moving toward a truly three-dimensional environment with meaningful depth and elevation. Oxygen Not Included remains a reference for connected devices and functional interiors, not a target for the world's side-on presentation.

Buildings should speak for themselves: make their purpose and activity legible through shape, equipment and visible behaviour. Avoid complex building configuration interfaces, production sliders and player-configured shift schedules. Preserve fixed-purpose workplaces and communicate mechanics through the world, with only essential concise UI. This is a continuing design constraint; keep instructions and goal displays hidden.

## Rope production and elevated bridge prototype — 7 November 2026

The user requested a playable rope bridge between terraces at different heights, with free endpoint placement and citizens carrying Logs across without roads. Keep ordinary buildings and stacking on the grid. Add a fixed-purpose Rope maker that processes Hay into Rope; hanging bridges consume Rope and Planks. Bridges should be a commonly useful logistics shortcut between levels of separate towers, avoiding unnecessary descent and ascent.

The isolated prototype now implements the production/construction/hauling chain, continuous bridge curves, road-independent navigation, same-height elevated-deck connections, endpoint validation and save/load. Rope maker and the free endpoint bridge tool are now integrated into the normal building catalogue; the separate prototype remains available for focused testing. Initial tuning is 4 Logs to build the Rope maker, 1 Hay → 1 Rope over 4 seconds, and bridge costs of 1 Plank/metre plus 1 Rope/2 metres, rounded up. These values are provisional, not user-approved final balance. Preserve visible rope-making equipment and resource shapes instead of a recipe selector or settings panel. See [prototype scope and launch instructions](../README.md#rope-bridge-prototype).

## Main-game rope bridges and endpoint editing — 7 November 2026

The user requested the bridge tool in the normal Structure tab alongside platforms/supports and stairs. Keep two posts visible immediately when placing the starting end. The second pair faces the first, and both ends remain freely placed on supported terrace or rooftop surfaces while ordinary buildings stay on the grid. Expose only the span preview, essential cost or validation feedback and existing contextual actions.

Selecting either post pair or the deck selects the entire bridge. Move chooses either endpoint and its new landing independently; the other endpoint stays fixed. Validate the new span before replacing the original. Recover construction materials into physical salvage and rebuild the moved connection, requesting extra materials when its length increases. Remove deletes the whole span and both pairs together. Protect occupied crossings and attached supports. Validate lateral intersections, vertical clearance, terrain, building volumes, anchor support, slope and span limits. Completed spans automatically join the shared navigation graph for road-independent resource carrying; unfinished spans grant no walking access. Attached roofs render a flat plank landing deck so their walking surface matches the model; restore ordinary roofing when the last attached span is removed. Keep the goal and instruction panels hidden.

## Grid buildings, free rope bridges and road-independent logistics — 7 November 2026

Keep building construction and stacking on the current grid. The user likes less rigid placement and slight offsets between stacked buildings as a future possibility, but explicitly defers it after earlier difficulties. Revisit only with a coherent solution for shared walls and structural elements, surface clipping, overlap and unwanted narrow or triangular rooms. This does not reopen free building placement now.

Rope bridges have freely placed endpoints on valid supported surfaces, arbitrary horizontal direction and different start/end elevations. Citizens should walk between building entrances across connected usable ground, floors, suitable roofs and suspended bridges without requiring a player-built road to every building. Height overlap alone never establishes access. Validate bridge slope, sag, clearance, landing access and supported span limits. Preserve the existing shared navigation graph and journey caching.

Resource management and physical logistics remain central. The user referenced “wilmoth warehouse” (title as supplied, unverified) for organizing resources by recognizable shape. Keep Log → Plank as the explicit example of increasing processing level through production effort. Explore resource-family storage with visually distinct raw and processed forms; Shed already groups Log and Plank. The user remains unsure whether exactly two resource types per dedicated store is a general solution: do not impose that limit on every store or add sorting/configuration UI.

See [future bridge and logistics notes](../FUTURE_IDEAS.md#grid-buildings-free-bridges-and-readable-logistics--7-november-2026). The bridge prototype and main-game tool above implement this connection type; broader free building placement and storage-family rules remain exploratory.

## Construction availability through completed producers — 7 November 2026

A building unlocks once the settlement has completed producers for every processed or extracted material type in its construction cost. Producer completion is the trigger; the first output item is not required. Logs, hay and stone can be gathered directly and form the starting construction tier, alongside buildings with no material cost. Derive subsequent availability from construction costs and producer outputs rather than a fixed building prerequisite list; gathering, production and storage buildings follow the same rule. For example, completing a Sawmill unlocks plank-cost buildings, and completing Masonry unlocks slab-cost buildings. Preserve unlocks after spending materials or removing the producer, save the history per settlement and start fresh for each new game.

Hide locked buildings from the existing construction lists. Once unlocked, allow plans with any current stock, including zero; workers deliver the required quantities and finish construction later. Preserve existing buildings and queued plans when loading older settlements, recover unlocks from completed producers, and allow relocation. Debug mode exposes all building types. Resource-bar visibility still requires actual acquisition and retains its separate discovery history. Keep instructions and goals hidden and add no unlock announcements or replacement displays.

## Clear day and night readout — 7 November 2026

Replace the rotating day/night ring with a stationary sun or crescent beside `Day N`. Keep the total day number unchanged at dusk and increment it at dawn. A short strip below the label separates warm daylight and blue night, with a marker moving through the saved cycle. Keep the readout first in the resource bar and the bar flush to the top-left corner. Preserve the shared 4-point strokes, 22-point text and three-digit number reservation. This supersedes the earlier rotating arc direction; do not add a separate central clock or numeric countdown.

## Seed placement and tree-only Nature menu — 6 November 2026

The Nature planting menu offers only Tree seed and Palm seed. Remove vegetables, bushes and vines from that menu, including discovered or collected entries; retain existing plants, saved orders and collected inventory. This supersedes the earlier collected-root and bush menu direction.

Tree, palm and legacy vegetable/grass seeds require soil at their planting spot, without a room-sized clear area or checks for level neighbouring tiles. Nearby plants do not impose spacing; the same root spot remains reserved. Allow uneven natural ground and isolated soil tiles. Reject buildings, roofs, bare platforms, water and rock at the root spot. Keep actual building footprints and queued construction protected. Workers still physically travel to plant the seeds.

## Trees at the exploration edge — 6 November 2026

Keep trees entirely hidden while any part of their visible crown or trunk footprint remains covered by unexplored fog. Reveal the complete tree only when that footprint is clear, including the fog mask's filtered edge. Hidden trees cannot intercept picking. Keep the fog contour on the terrain rather than slicing or colouring partially revealed trees; preserve cutaway and fully visible menu previews.

## Saving and citizen journeys — 6 November 2026

Autosave every five real-time minutes during gameplay, with encoding and disk writes in the background. Save the latest state when returning to the menu, switching settlements or exiting. Building placement, movement, deletion and other construction actions must not trigger saves; changing application focus must not trigger one either.

Citizens share a navigation graph and retain their route for a journey. Walking through successive cells does not rebuild the graph or recalculate the route. A new player destination replaces the journey; an actual obstruction requires a new route. Blueprint placement, movement and cancellation reserve construction space but leave pedestrian access open until construction changes the physical world. Update navigation when walkable terrain or completed structures change, retaining unaffected local search caches when distant terrain streams in. Arrival alone does not require a graph rebuild; a new destination starts the next route request.

## Reference ideas to revisit — 6 November 2026

The user asked to keep Midnight Moments, High Above, Cube & Seek and Laysara as exploratory references and occasionally resurface them during relevant project work. See [the saved ideas and revisit triggers](../FUTURE_IDEAS.md#scene-building-references-to-revisit--6-november-2026). Favor compatible gradual steps toward expressive scene building, real interiors, miniature architectural details, flexible furniture placement, adaptive tiled roofs, atmospheric lower levels, mountain verticality and interior tunnels. Poisonous lowland gas is a possible setting idea, with behavior undecided. These preferences guide future discussions; they do not schedule implementation or replace current confirmed requirements. Bring up the relevant idea when it helps a concrete design decision, and keep substantial changes explicit.

## Cursor and resource bars — 6 November 2026

Preserve the black-and-white cursor's blunt arrow silhouette and rounded tips, using an antialiased vector path instead of an enlarged pixel grid. Keep its native pointer responsiveness, logical size and click hotspot.

The top resource bar sits flush against the top-left viewport corner, with no outer gap. It begins with the day/night counter, then population, food and water; future currency belongs here after water. The 11 November proposal replaces Coins with Pearls. Move logs, hay, planks, stone and all other construction materials or consumables into a vertical sidebar on the right. Preserve resource discovery and zero-count persistence, and keep construction menus clear of the sidebar. Currency remains planned, without adding a simulated balance or new UI in the proposal pass. Keep instructions and goals hidden.

## Hay fields, watering and retained assets — 6 November 2026

Retain the wooden food-crate model for future use and mark it **Unused** in the asset library and source-scene metadata. Berry carrying continues to use bare hands.

Hay fields follow the real terrain surface, including uneven soil, without levelling only one corner. Soil, border timber and individual stalk clumps fit the local heights automatically. Replace the continuous rectangular yellow crop slab with visible stalks; preserve four independently harvestable quarters. Each quarter keeps its own growth and water state, so a cut quarter can regrow while other quarters remain ripe.

Allow supported buildings to occupy hay-field quarters, including the field's original anchor. A quarter touched by a building footprint or overhead platform produces no hay, receives no rain and does not grow. Clear its standing crop and progress when covered. Preserve the rest of the field, its layout and its construction materials through saves and building removal; uncovered quarters can be watered and grown again. This supersedes the earlier ten-percent shade-growth rule for hay fields only.

Manual crop watering requires a worker to fetch and carry water from a reachable puddle, well or stored supply, then spend the existing watering labour. A nearby well does not grant hay fields free water. Rain waters exposed crops through the same moisture state as manual watering; cover blocks rainfall. One delivered bucket waters the field's open, unripe quarters for their next growth cycle. Keep existing resource identities and the clean UI.

## Berry carrying — 6 November 2026

Gatherers carry collected berries loose in their bare hands, with both hands held together beneath the fruit. Do not spawn a wooden box, basket or other container for berry hauling. Preserve the rounded, fingerless citizen silhouettes and existing gathering and delivery mechanics.

## Starting household — 6 November 2026

New games begin with one completed house, two adults and one child, with no other buildings or queued construction. Replace the supplied starting pile with the house; retain the five opening meals in its twelve-food inventory, but no loose starting logs. The family lives in this house and gathered berries can be delivered there immediately. Existing saves keep their buildings and supplies. Logs still require a wooden shed under the dedicated-storage rules below; builders can harvest raw logs or stone for reachable construction when no stored materials exist, so the first shed or pile does not require pre-existing storage. Keep the existing UI without instructions or a replacement goal display.

## Role-specific construction — 6 November 2026

Remove the experimental Rooms toolbar entry and its shape-building menu from normal settlement play. Players construct buildings with defined roles, such as houses and sheds, through the existing construction categories. The room editor, room geometry and integration remain retained for later reuse in the isolated development prototype; do not expose them as another main-game construction mode. Preserve existing saved room layouts. This supersedes the player-facing editor entry described in the 30 October room-construction milestone below.

## Resource and crafting design revision — 6 November 2026

Water/storage clarification: the active spreadsheet contains only the seven Tier 1 crafting buildings plus Shed, Depot and Well. Pottery makes Vases; Water is held in those Vases. A House stores up to three Vases, representing three days of water consumption. Per-vase water units and per-citizen allocation remain unspecified. Puddle is a natural rain-filled source, not a building. A Well prevents evaporation and has initial capacity 3 on a Puddle, 2 one cube away and 1 two cubes away. Building another Well on the same Well represents digging deeper, with the stated example 1/1 → 1/2 (stored water / capacity): the upgrade increases capacity, not the stored amount. Maximum digging depth is 3 m. Capacity at maximum depth, other-distance upgrades, distance measurement, refill rates and behavior beyond two cubes remain to be balanced. This records future design and does not claim the current water system already implements it.

Tier 1 review: concentrate on Field, Sawmill, Masonry, Mill, Bakery, Kiln and Pottery for the first crafting chains. Defer Concrete production (formerly Crusher; replacement name undecided), metalwork including Blacksmith, Smelter, Forge and ore extraction, and the general Warehouse. Use dedicated storage: Shed holds Log and Plank; an open 3 × 3 × 2 m stone store holds Stone and Slab. Pottery produces reusable Vases for carrying/storing Water; vessel capacity, filling and availability rules remain unbalanced. Keep one output per production building. Review a nightly routine for sleeping, recovery, washing, eating and drinking that avoids routine midday work interruptions. Shorter nights and player activity at night remain open; expose day and night durations as separate planned balance parameters. Existing runtime `game_settings.cfg` general.day_seconds controls the current 360-second cycle, not an implemented separate night routine.

Latest building review: spreadsheet tables start on row 1, with no title/date/explanation rows. Use lowercase action verbs and provisional square brackets for class names, such as `bake [Food]`. Prefer single-word building labels: `Kiln` replaces `Brick kiln`. Bread is the visual model of Food, not a separately stored resource. The provisional early food chain is Hay → Flour → Food, with Grain omitted for now; the intermediate Flour step remains reviewable. Defer generators, Watermill and other energy-conversion buildings from the active building review. Explore Tier 1–3 upgrades that retain each building’s purpose; rates and costs remain unbalanced, and merging identical buildings is not confirmed. Keep House at 2 × 2 × 2 m. Target Shed at 1 × 2 × 1 m excluding its roof, align its placement footprint and origin to that size, and allow it to store both Log and Plank. These are design targets for later model/runtime work.

Confirmed review simplification: retain only the existing 2 × 2 × 2 m House; exclude 2 × 3 × 2 and 3 × 3 × 2 house variants for now. Planned workplaces default to one worker and no power requirement. Decide power requirements later; this supersedes the earlier requirement that every processing machine must already have a power connection. Review spreadsheets put names first, combine dimensions as W X D X H, omit IDs, footprint, worker-slot and power columns, and use plain uncoloured tables. Separate missing buildings from current implementations and distinguish requested additions from suggestions.

Confirmed building-roster review: remove the Stockpile (Pile) building from the planned game and omit School for now because it has no defined gameplay purpose. These are pre-implementation design decisions. Keep current-runtime inventory records as historical references; review remaining storage destinations separately without assuming removal of dedicated stores or loose resource drops.

The user revised the future economy around three shared consumables (Food, Water, Money), five energy resources (Electricity, Gas, Log, Charcoal, Oil), five natural source families (Bush, Grass, Tree, Mountain, Dirt), and single-output production. Hay from wild Grass is separate from Grain harvested at a placed 4 × 4 × 1 m field. Workers carry one resource type at a time. Berries and Bread become Food on storage delivery. Specialized production buildings correspond to one action each; room functions still depend on installed equipment, including a Bed for sleeping. Roofs remain automatic, progressing through Hay, Plank, clay Tile and Metal coverings.

See [Resources and crafting model](CRAFTING_MODEL.md) for the full requested catalogue, updated metric room sizes, proposed reusable JSON definitions, and explicitly unresolved decisions. The document distinguishes requested relationships from proposals for blacksmithing, energy conversion, Concrete semantics, operating costs and workplace names. This revision supersedes earlier planning where those concepts conflict, including the draft mind map and houses-only food-storage rule, but does not claim runtime implementation, migrate saves or authorize new UI. The immediate deliverable is documentation before implementation.

Confirmed machine workflow: power arrives through a separate connection. Each material-processing recipe still takes exactly one resource type and produces exactly one resource type. The worker brings the material, spends time working at the powered machine, then carries the completed resource to a pile/store or directly to a construction site that needs it. Power is not a second recipe ingredient; connected power alone does not replace worker effort.

Confirmed fixed-purpose workplaces: each production building has one fixed recipe and output. Do not provide a building recipe/output selector in the game UI. Different products require separately named workplace types, even when they share an action or model. The player can assign a citizen to a specific workplace or source; preserve that assignment through repeated work cycles and temporary interruptions. The review spreadsheet is for developer balancing before implementation, not an in-game building configuration panel.

## Hilltop colonies and tidal lowlands — 30 October 2026

The user identified Above: Colonies of the Mist as the reference for colonies on high hills or mountains above a dangerous lower zone. Suspended bridges from one hill to another are a particularly appealing connection concept. The game's Steam description confirms vertical colonies above toxic mist and connections between settlements using bridges and ziplines; these are reference features, not automatically adopted mechanics.

For our game, consider sea level rising and falling twice per in-game day as an alternative to poisonous gas. Repeated flooding could make the lowlands unsuitable for permanent habitation and damage or destroy buildings there, while citizens might be able to swim. Tidal range and timing, swimming behavior, and the rules for flood damage or destruction remain undecided. This is a future design possibility to retain alongside the reference, not a request to implement it now or replace the current terrain generation.

## Metric building measurements and progression — 30 October 2026

Use a 1 × 1 × 1 m World Unit and eight 0.5 × 0.5 × 0.5 m Sub-Units for finer equipment work. The user specifies a 2 m entrance clearance and a minimum 2 × 2 × 2 m room module, with independent room dimensions such as 2 × 3 × 2 and 4 × 4 × 3 m. This supersedes room-as-unit language for future design dimensions, without rescaling current assets or saved coordinates. Whether module dimensions mean usable interior or exterior shell remains to be clarified.

The requested direction includes roofs fitted to exposed room tops, automatic supports when stacking, 1 m-rise connectors aligned to entrance landings, reusable clockwise stair assemblies, flats composed of rooms, whole-building placement and generation, and management from equipment through multiple cities. See [building measurements and progression](BUILDING_MEASUREMENTS.md) for geometry, text/JSON notation, access graph, merging rules and implementation sequence. New automation rules remain proposals; this entry does not claim runtime implementation.

The user confirmed the standard 2 × 2 m stair with a 2 m rise: bottom-left flight 0→1 m, top-left and top-right platforms at 1 m, then bottom-right flight 1→2 m. Entry and exit occupy opposite corners of the same exterior side, producing a 180-degree travel turn. Preserve it as a prefab like the Building demo's one-logical-cube stair, while distinguishing that room-sized cube from a 1 m World Unit. It ends at the second flight with no extra upper platform row; the footprint is not 2 × 3 m. Its upper exit connects to a separate destination such as a room landing, platform or walkable roof at 2 m.

The user also confirmed the corrected 90-degree layout within 2 × 2 m: bottom-left flight 0→1 m, top-left platform at 1 m, top-right flight 1→2 m, and bottom-right platform at 2 m. The upper platform is inside this prefab. These cell assignments replace the earlier diagonal-cell interpretation. Semi-automatic selection of the exit arrangement is requested; detailed tread geometry, endpoint directions and clearance still require 3D validation.

The technology scope is reopened for exploration from sticks and leaves through earth, timber, masonry and possibly industrial or futuristic buildings. Ancient materials remain the starting palette. Modern endpoints, plastic construction, economy recipes and transit-pass logistics are undecided. Cars remain out of scope. This planning update does not replace the construction-first prototype or introduce new goal/instruction UI.

## Constraints and undecided questions

- Stone deposits use the mountain's sandstone palette. Updated 21 October: natural stone is a filled, connected mass, with mostly upright broad faces, stepped shoulders and slightly angled caps. Updated again 21 October: each intact block has six flat faces and eight geometric corner vertices. Remove bevels and extra clipped corner faces; vary the existing corners visibly to break repetition, while keeping adjacent blocks joined. Use shared uneven grid intersections and planar angled faces; avoid a nearly uniform skew that still reads as a Minecraft stack. Merge mining subdivisions into simple remaining cuboids for rendering. Remove the earlier independently leaning, tapered columns and diagonal cutouts. The logical volume uses joined 1 × 1 × 1 m sections, reducing the usual three-section formations to roughly 3 m tall; the maximum remains three 2 m storeys (6 m). Houses retain their separate 2 × 2 m scale. Keep the non-cubic visual silhouette separate from occupied cells and build support. Mining removes small regions top-down without shrinking the whole formation; one cubic metre yields nine stones (updated 21 October 2026). Build checks follow the remaining logical volume, and supported surfaces become available as mining clears them. Existing stone quantities and reservations survive; old volume saves retain their mined fraction in the new silhouette. Finished masonry and rough carried/stored raw stones keep their distinct existing shapes.

- Use ancient construction materials and techniques, particularly stone and timber. Modern-looking accessory references express connection and management ideas; the final technology palette is not settled.
- No conveyor belts. Potential logistics include hauling, vacuum tubes, monorails and lifts. Vehicle transport is not currently expected.
- Vertical and underground space are central. Avoid turning the design into a flat city builder.
- Confirmed 18 October: a one-room building is the 1×1 reference. Terrain and horizontal placement use 0.5×0.5 cells (one quarter of its footprint). Smaller gravel and surface details live inside those cells. Arbitrary rotation and free placement remain separate future work.
- Free rotation must preserve authored entrance transforms, collision clearance and connection tolerances. Display geometry must not decide connectivity on its own.
- Structural stress is optional. It must not become a prerequisite for the core construction and logistics loop.

## UI communication rule — 18 October 2026

Keep the game UI clean. Teach mechanics through gameplay and visual feedback, not explanatory paragraphs or persistent control instructions. Use only concise labels and essential values where needed. The bottom instruction panel stays hidden. Construction progress bars appear only above the selected construction site; deselection hides them immediately while construction continues. A selected citizen actively building shows their own current work application bar. Selecting their construction site shows the total construction bar instead and hides its builders’ personal bars. Unselected builders and citizens still travelling to the site show no construction work bar. Apply this rule to all future UI work.

Eating never shows a progress bar, including for selected citizens. Meal timing and behaviour stay unchanged.

Delivering materials to storage is immediate on arrival, without applied work or a progress bar. Materials delivered to construction sites or production buildings such as sawmills still require work to install or convert them. Storage capacity and access still govern delivery.

The persistent goal line, including completion messages and goal progress counts, stays hidden. The user will choose a different goal presentation. Ask before introducing a replacement or other unrequested UI content.

People are named by their current occupation in hover and selection labels: Lumber, Gatherer, Gardener, Builder, Baker, Sawyer, Miner, Mason or Hauler. Assigned occupations remain visible during meals, travel and waiting; automatic workers use their active job, falling back to Willager when unassigned, regardless of appearance. Children are always Kid. Do not use Citizen in player-facing UI; it remains an internal development term. School work and the Scholar occupation are a future idea, not part of this naming change.

## Continuous play — 18 October 2026

Normal play starts at 1×, with optional 2× and 4× speeds. There is no gameplay pause or Space-bar pause; decisions happen while the settlement runs. Esc deselects all citizens and objects and cancels placement or drag selection. It never saves, exits, opens the menu or pauses gameplay. The toolbar X remains the explicit way to save and return to the title screen. The separate structure authoring workspace also suspends the settlement. All play speeds use the same fixed simulation steps; slow frames retain pending time and catch up in bounded batches without skipping work, movement, needs or resource updates.

## Code boundaries

Player-assigned construction stays in the citizen's saved memory until the entire chosen building is complete. Resource trips, meals and temporary route interruptions preserve that assignment; a new player order replaces it. After completion, the citizen remains a builder and can choose other construction automatically.

Confirmed 6 November 2026: a new player job can immediately interrupt delivery of unrelated cargo. Leave that cargo as recoverable goods at the citizen's current location, preserving quantities and any relocation ownership. Keep useful carried construction materials and apply them to the assigned site. Empty-handed builders choose the nearest reachable source of the needed material before walking to the site; if stored material is unavailable, gather a suitable raw material and bring it directly to construction. Do not make a preliminary empty-handed site visit or an unnecessary storage detour.

Simulation state stays in `scripts/settlement/world_model.gd`; job state remains saveable, and renderer caches are disposable. `navigation.gd` owns route searches and topology invalidation. `world_view.gd` reconciles persistent entity views, `scenery_view.gd` owns static terrain presentation, and `worker_view.gd` owns articulated characters and cargo.

Future room classification, utility networks, structural analysis and chunk ownership should each receive their own simulation module with explicit inputs and saved identifiers. Do not add these systems to the input coordinator or infer gameplay state from scene-tree meshes. Utility connection graphs and walking graphs must remain separate: a pipe connection is not a walkable route.

Original assets remain editable TSCN/GLB files. Geometry, dimensions, access markers and utility ports belong to asset contracts; resource counts, room capabilities, load and jobs belong to simulation data.

## Citizen motion reference — 6 November 2026

The user supplied `Untitled.mov` showing a walking woman, a walking man (including his back as he moves away), and a running child. Ignore the game's diagonal screen distortion. The requested movement has an exaggerated bent-knee lift above the hip, a soft landing and rounded, chibi character even in adults. Use the rear view to judge alternating body weight and arm movement; do not interpret the distortion as anatomical deformation.

Adult walking and child running are stored separately in `data/settlement/citizen_walk.tres` and `citizen_run.tres`. Each pose records cycle fraction, thigh angle and knee angle; the opposite leg follows half a cycle later. Stride length controls distance-driven playback, with separate arm swing, sway, lean and running lift. The existing knee/elbow springs provide follow-through. Supporting capsule geometry sets body height. This is a hand-authored interpretation of the footage, not extracted motion capture. Preserve pause, relocation resets, child scaling, carrying and work overrides. The isolated `tools/settlement/capture_reference_walk.gd` preview shows adult front/rear walking and the child run; it adds no gameplay UI.

The user rejected the first animation preview and confirmed the body direction: **small round head, broad belly, short limbs, close to the supplied clip**. This supersedes the earlier slimmer-body direction. Rebuild the body as a joined rounded surface with smooth shoulders. Skin and clothing regions share mesh boundaries, joint weights and an eleven-bone skeleton; omit hidden body geometry under outfits. Remove the expanding-skirt workaround. Preserve featureless faces, four outfits, clothing identity and child scaling. Walking, carrying, work gestures, mouse picking and occlusion outlines must follow the same posed mesh.

The user is interested in gravity, believable balance and possible ragdoll reactions. Full physical character control, active ragdoll walking, cloth simulation and destructible block buildings are not implemented by this geometry revision. Building destruction remains an exploratory question rather than an approved gameplay feature.

## Starting family and citizen silhouettes

Confirmed 18 October 2026: a new settlement has only a Stockpile, two adult citizens and one child. The child is an autonomous NPC until adulthood; the current tuning is three simulation days. Age and clothing identity persist in saves, and old saves retain their existing adults. Citizens follow the rounded Pyramida reference: slimmer bodies and short pill-shaped arms and legs with straight sides and hemispherical ends, no fingers, and simple solid-color clothing. Supported outfits are men’s shorts and one-shoulder diagonal robes, and women’s dresses or separate tops and skirts.

## Pyramida foundation priority — 18 October 2026

The latest user request makes Sokpop Pyramida's core village economy the immediate reference. See [the sourced research and implemented scope](PYRAMIDA_RESEARCH.md). Build from physical gathering, farming, milling, sawing, mining, masonry, housing growth. Keep existing vertical construction, but defer the broader utility/room/structural systems above until this foundation is evaluated. Exclude the alien storyline. Enemies, zombies and weapons remain unimplemented while the user decides about combat. Confirmed later on 18 October: remove the Ancient monument construction site and all pyramid-building objectives. This game develops its own identity; Sokpop Pyramida remains a reference, not a blueprint for its goals. Existing saves retire monument work while preserving carried materials. Do not add a replacement objective or goal display without asking the user.

## Illustrated rendering exploration — 18 October 2026

User screenshots establish featureless heads: no eyes, nose or mouth. Hair and clothing distinguish citizens; limbs remain short capsules. The active presentation uses unshaded solid colours, a warm paper ground, full logical viewport resolution with 4× MSAA, and a thin colour-boundary contour pass sampling the original image coordinates. The 30 October direction removes the static noisy distortion so straight architectural edges remain straight. The effect applies only to the 3D viewport, leaving GUI text, hit testing and simulation unchanged. Day/night uses a saved-time tint on the world pass. Set `illustrated = false` on the settlement root before launch to compare the previous lit, reduced-resolution presentation.

Shoulders blend into the torso, with arm pivots embedded in the shoulder and rounded hand ends. Citizens remain articulated 3D meshes, presented like flat cutouts in eight camera-relative directions; side views turn slightly toward the camera. Distance-driven steps, arm swings and a subtle body bob interpolate between simulation ticks and freeze when paused. Carrying holds the arms around the cargo. Same-level walking supports four cardinal and four diagonal tile connections, with both neighbouring cardinal tiles required for a diagonal so walkers cannot cut across unsupported corners. Cliff and building-floor travel still requires explicit connectors; natural gravel slopes are walkable.

The joined citizen surface is bound to an eleven-bone skeleton with hidden elbow and knee pivots. Constrained angular springs give forearms and shins a little delayed follow-through: elbows bend forward, knees fold backward, and the joints settle when movement stops. This is a driven visual puppet, not a falling or collision-driven physics body. It preserves navigation, child scaling and the cargo socket. Carrying and work gestures use bent elbows; pause freezes spring momentum and relocation resets it.

## Selection markers — 18 October 2026

Selection lives on the object's floor plane, projected with the isometric camera. Living entities other than selected citizens (bushes, trees, and future animals) use circles; citizen selection uses the body contours specified below. Buildings and other nonliving objects use only four short rectangular corner brackets around their footprint, never a full-height bounding outline. Give each bracket a subtly rounded bend, including construction-site selection, so the four chevrons feel softer while retaining their open shape and 4-point stroke. Hover uses these same object-specific floor shapes, replacing the sand-cell rectangle and showing the object title above it. Hover preserves the current selection and adds no work bars or resource rows; an already selected object keeps one outline. Markers are translucent GUI strokes visible through all 3D geometry. Preserve the selected floor elevation and keep the interface free of explanatory text.

Updated 21 October: unselected citizens and kids behind buildings show only their concealed silhouette edges in muted warm grey (#C5BCA8), at 95% opacity and the shared 4-point width. Selection switches to the yellow outline around the entire character, including exposed body edges, and remains visible when no building is in front. Follow the actual animated body and child scale; keep the interior hollow. Selected citizens have no circle at their feet. Cursor hits inside a person's body select that person through the building, while empty space still selects the building. Hover and click share this geometry. Kids remain inspectable NPCs. Preserve existing hover names, selected labels and work bars without adding instructions.

## Shared UI point — 18 October 2026

Follow [the UI point guideline](UI_GUIDELINES.md). One point is one logical UI pixel, scaled only by display density. Solid UI strokes use 4 points; padding, gaps, dividers and component sizes share that unit. Selection markers use a single translucent yellow (`#FFC471`) 4-point stroke. Tree selection circles are half their previous diameter, and citizen navigation trails use the same yellow.

## Home screen world preview — 18 October 2026

Each launch and return from a settlement offers a freshly generated world behind the menu. Show its seed discreetly in the bottom-right corner. Menu navigation preserves that preview, and New Game starts the exact unplayed world shown after the existing slot and difficulty selection. Continue restores its saved settlement. The preview remains paused and creates no save until New Game is confirmed.

Updated 21 October: hide Continue entirely until a playable save exists, without a disabled button or empty home-menu row. Title the slot selection page Select slot and distinguish clickable New game entries with warm terracotta text. Keep Play, the first slot and Sand aligned as Continue appears or disappears.

Updated 6 November: leaving gameplay through the toolbar X saves the settlement and opens the first screen with the working game title. On Select slot, Back occupies the exact same click area as Quit on the title screen, so the player can click Back and then Quit without moving the cursor. Preserve the aligned Play → first slot → Sand sequence, with and without Continue.

## Flat desert and half-room terrain — 18 October 2026

New worlds begin on broad flat land, with small separated patches of Utah-style sandstone buttes. Each patch has a diagonal gravel/talus apron below a tall intact rock column with a level top. Preserve open space between formations; do not restore a continuous ring of mountains around the settlement.

The room is the size reference: 1×1 building footprint, 0.5×0.5 terrain cells and half-unit horizontal placement. Existing 2 m-wide assets retain their physical dimensions and centered front entrance; the finer grid does not shrink buildings or citizens. Floor spacing is now 2.0 m (updated by the shorter-building direction below). Building overlap and support checks cover the entire footprint, including terrain at its edges. Sloping gravel is nonbuildable but walkable: clicked movement orders follow the actual triangular ground surface up and down the apron. Travelling citizens never count as idle; after arrival the existing three-second idle delay applies. Cliffs still require explicit ladders.

New saves record half-grid addresses and gravel corner heights. Older room-grid addresses migrate horizontally while keeping citizens' world positions, resources, building dimensions and elapsed work. Existing landscapes are loaded from saved heights rather than replaced by the new butte generator.

## Semi-infinite exploration — 18 October 2026

New worlds generate and stream chunks as the camera and citizens move. Keep trees, bushes and grass consistent with the seed and absolute coordinates across chunk edges, unload/reload and saves. Preserve harvested resources and active jobs. Use the confirmed flat desert, isolated buttes and half-room grid; keep the generated home preview as the starting world. Streaming adds no persistent instructions, goal display or other UI.

## Extendable piles — 18 October 2026

A pile is one room-sized 1×1 ground plot (2×2 half-room terrain cells), marked by small stones at its corners. New plots cost one stone and require physical delivery and construction. Adjacent same-floor plots join along their touching edges: a two-plot rectangle or a filled rectangular block has only four outer corner stones. Irregular extensions keep their actual perimeter turns; diagonal contact and different floors remain separate. Selection and inventory readouts cover the connected pile, with 32 capacity per plot. Goods and reservations retain their physical per-plot addresses for hauling and save compatibility. Existing two-timber construction plans retain their saved cost.

## Shorter buildings and automatic roofs — 18 October 2026

Building floors are 2.0 m high, down from 2.4 m, while room width stays 2 m. Housing, storage buildings, wells and production buildings all provide an upper construction surface. Houses and storage buildings receive their natural timber/earth roofs automatically, with no separate resources, labour or roof plan. Open workplaces, wells and windmills keep their own silhouette; a supporting frame and deck appear only when an upper building is planned (or an upper access connector needs a landing). Cancelling that plan removes unused supports. There is no invisible walkable roof on a bare open workplace. Completing another building above removes the covered lower roof and puts the cap on the new top floor. Half-grid offset stacks keep uncovered roof sections. Roads, crop beds and loose stockpiles remain outdoor surfaces. Ladders still provide explicit vertical access; adding a roof never creates a walking connection between floors. Saved citizen heights migrate with the floor spacing.

## Cursor placement variation — 18 October 2026

Buildings can be nudged continuously up to 0.18 m from their tile center in each horizontal direction, following the cursor on the placement floor. The preview, construction site, completed model, collider and selection all use that same offset. Each floor can have its own offset; rotation does not rotate the stored displacement. Construction plans and completed buildings save the exact displacement; older saves default to centered placement. Logical tile identity, occupancy, material delivery and explicit ladder links remain on the half-room grid. Roads, ladders, platforms, crop beds and joined stockpiles retain their connected grid geometry. Do not randomly reroll offsets on load.

## Bush berries and replanting — 18 October 2026

Natural bushes start at 3/3 berries. Picking removes one berry without reducing capacity. Every two complete simulation day/night cycles, a growing or partly harvested bush adds one berry; young bushes also gain one capacity slot, up to three. Thus a replanted bush starts at 1/1, can become 0/1 after picking, then 1/2 after two cycles and 2/3 after two more if left alone. A mature empty bush refills one berry at a time, every two cycles. A full mature bush does not bank refill time. Capacity and partial growth time persist across saves and streaming. Older saved inventories retain their stock and capacity until explicitly replanted.

Show one exterior red berry dot per berry physically on the bush; reservations do not remove dots until pickup, and empty bushes have none. Keep current/capacity in the existing selected-object readout. Selecting a bush exposes the toolbar Replant action described below. Relocation preserves its berries, capacity and partial growth time. No persistent instructions or goal display.

## Tree foliage curves — 6 November 2026

Living tree crowns use smooth, rounded contours like the approved bushes, removing the visibly polygonal edges. Preserve their existing clustered crown arrangement, seeded proportions, green colour and harvesting behaviour.

## Bush foliage depth and density — 18 October 2026

The later screenshot references supersede the three-lobed canopy treatment: each bush is one distinct, slightly irregular rounded blob in a single muted sage green. Vary the outline and green subtly between bushes, consistently by seed and cell. Depth comes from loose overlaps between neighbouring whole blobs, not three interlocking colour panels inside every bush. Retain readable individual silhouettes and irregular colony outlines; avoid a fused mound or repeated clover shape. Apply this to existing saves without relocating resources. Keep the approved red berry dots and stock behaviour unchanged.


## Construction relocation — 18 October 2026

Select a completed building and press **M** or the **Move** button in the separate top-center selection menu to choose its destination. A valid click queues a destination ghost while the original remains in place. A constructor walks to the source and dismantles it; its original saved construction recipe becomes physical parts reserved exclusively for that move. Constructors haul and install those pieces at the new site. A different constructor can continue interrupted work. Stored contents, crop state, orientation choices and destination offset survive reconstruction. Source and destination remain reserved until completion. Buildings supporting another floor or occupied elevated access cannot be moved until cleared.

The same button and shortcut show **Replant** for bushes, full trees, remaining harvestable trunks. A constructor uproots, carries and replants the same plant, preserving berries, capacity, growth time and remaining trunk sections. Escape or right-click cancels destination placement before queuing. Jobs, packed contents, exclusive materials and partial labour survive saves; both ends remain loaded during streaming. Use existing selection-only progress bars, with no persistent instructions or goal display.

Updated 7 November: keep the existing source building's selection controls visible while its move is queued and it remains standing. Move edits that order's destination, retaining its identity, builder assignment and dismantling progress. Confirming a valid replacement releases the old destination; cancelling placement leaves the previous order intact. Copy remains available; Remove stays visible but disabled while the move owns the source. Preserve existing placement and structural checks, with no additional panel or instructions.

## Rounded bush volume and shadows — 18 October 2026

Raise the individual bush blobs into full three-dimensional bun shapes: a rounded dome, broad shoulders and a low flattened underside resting on the ground. Keep subtle outline and sage-green variations. Updated later on 18 October: each bush has its own deterministic shade of green as a flat, unshaded solid fill, with no lighting gradients or received shadows across the foliage. Preserve the rounded geometry and shadows cast onto the ground. The illustrated terrain retains its painted paper palette while receiving subdued directional-light shadows. Preserve the red berry dot size and count, repositioning dots onto the raised crown.

Bush foliage is half its original width, depth and height so it stays proportionate to trees. Keep berry dots readable at their existing size, positioned on the smaller crown. Bush foliage and berry dots retain their authored flat colours throughout morning, evening and night; exempt them from the illustrated day/night colour grading while keeping the rest of the world graded.

Bushes occupy one small land tile. Allow replanting on immediately adjacent tiles, with crowns touching or slightly overlapping, and generate new colonies at one-tile spacing. Existing saved bushes keep their positions and growth state.

## Rising sun and long shadows — 18 October 2026

Preserve the rising and setting sun as a defining visual feature. Trees, buildings, bushes and people cast clear, long ground shadows at dawn and dusk; those shadows shorten toward noon and reverse across the day. Keep the illustrated flat foliage and painted terrain palette. Sun movement follows saved simulation time, and ground shadows fade smoothly at the horizon. Shadow coverage must reach the terrain from the offset isometric camera, including zoomed-out views.

Updated later on 18 October: cap low-sun ground shadow length at four times the caster's height above the receiving ground to prevent extremely stretched parallel streaks. Keep the existing clock-driven horizon fade.


## Sand tile hover — 18 October 2026

Hovering bare, revealed sand shows a complete isometric rectangle around the actual 0.5×0.5 generated terrain cell, using its true floor elevation and the current camera projection. It is a measuring cue with no label or persistent grid. Selection outlines, citizen circles, drag-selection borders and citizen paths use `#FFC471`. The tile outline uses the same shared 4-point stroke.


## Player blueprint workspace — 18 October 2026

Rework the former Debug mode as **Blueprints**, integrated through the existing F2 overlay and styled like the main game: sand and paper colours, the shared font and point measurements, yellow floor brackets and illustrated world rendering. Keep a large virtual map with advanced numeric/grid/work controls tucked away. Sculpt irregular predefined shapes, vary them, stack independent copies and move existing buildings without losing their details.

The user's ShantyTown reference emphasizes lived-in irregularity and optional manual detail. Give buildings explicit facade doors. Structural support alone never implies pedestrian access: exposed roofs and explicit ladders form the blueprint walking graph. Inaccessible doors glow red and request access with an icon-only, world-anchored speech bubble, following the queued desires direction below. Keep requests local to the building; no replacement goal display or instruction panel.

AC units and satellite dishes are now explicitly requested blueprint accessories, superseding the earlier deferral for this authoring workspace. Allow precise manual wall/sidewalk placement or a one-click upgrade that chooses a clear facade position with saved random variation. Upgrades are idempotent; saving, undo and reloading must preserve exact attachments. Doorways remain clear. This is an authoring/access preview; live settlement utility consumption, power networks and spawning custom blueprint buildings into the colony remain separate work.

## Selection action menu — 18 October 2026

Keep selected-building actions in their own top-center menu, separate from the top-right construction categories, speed and exit buttons. Show it only while a selection offers an action. Move/Replant uses a rectangle with an arrow pointing out through its right edge, drawn with the shared 4-point stroke. Keep the menu horizontally centered when resizing; if the resource bar occupies that space, place it immediately below the bar. Use the existing concise hover tooltip without adding a title or instructions.


## Citizen spacing and obstacle clearance — 18 October 2026

Kids and adults may briefly cross through one another while travelling. They must walk to separate reachable resting spots after sharing an arrival point, and prefer distinct access cells when working around the same obstacle. Solid buildings, trunks and deposits block pedestrian routes; jobs and deliveries use their perimeter while roads, crop beds and open piles remain usable. Preserve explicit floor and ladder connections. If construction encloses a resident, walk them out on their current floor and resume their saved work and cargo. Do not add UI instructions or goal displays.

## Larger game icons — 18 October 2026

Double the width and height of in-game UI icon viewports and geometry, including resource, construction, selection-action, day/night, speed and compass icons. Keep visible outlines at 4 points and preserve text size. Expand buttons and list rows to fit; reposition menus as needed to avoid overlapping the resource bar. The selection-action menu stays at the top center.


## Construction placement volume — 18 October 2026

While placing or moving a building, hide the free-roaming ground/object hover marker and outline the preview's full three-dimensional volume. A single cuboid shows all twelve edges and eight corners; irregular Blueprint pieces follow their exposed shape, including concave turns and height changes, without internal coplanar seams or a rectangular envelope across empty cells. Use translucent yellow x-ray strokes at the shared 4-point width. Ordinary selected buildings retain flat floor brackets. No additional labels or instructions.


## Local childhood games — 18 October 2026

Nearby kids occasionally play tag, running in loose circles after one another. Use local separation, alignment, cohesion and pursuit steering, constrained to walkable navigation edges. The catcher runs 0.2 world units per second faster than the other players and passes the role on contact, with a short grace period before another tag. Keep each small game within six world units of its starting point; distant groups and disconnected floors do not influence one another. Kids take breaks and leave play for meals or adulthood. Preserve round progress, catcher and rest timing in saves. Communicate through movement, without adding UI labels or instructions.


## House entrance carpet — 18 October 2026

The main house has a thin dark burgundy carpet covering its entire floor, wall to wall and up to every threshold. Joined rooms retain continuous rug coverage across their shared floor. Inward-facing walls are dark warm brown, keeping the exterior plaster colours unchanged. Together they make the entrance read as a dark recess with a subtle reddish tone. The cloth receives real shadows and the existing day/night lighting and colour grading; keep it matte and inside the house footprint.

## Copy and worker deconstruction — 18 October 2026

The top-center selection menu offers Move, Copy and Remove for completed buildings. Copy uses overlapping rectangles and **C** starts normal construction placement with the selected type and orientation; the new building requires its normal materials and labour. Copy never duplicates stored goods. Remove uses a bin icon and **R** queues a deconstruction site on the existing building. While placing a building, R still rotates the preview. C retains cutaway toggling when no copyable building is selected.

Updated 21 October: **Backspace** also removes the inspected building or construction plan, with its own configurable shortcut and concise hover hint. Deleting a plan immediately cancels construction and removes its construction geometry; builders stop working on it, while delivered materials remain recoverable. Completed buildings retain worker dismantling. Keep R's existing behavior and keep persistent instructions hidden.

Removal keeps the original building until a constructor reaches it and finishes dismantling. Recover the exact saved construction recipe as visible physical parts, including older recipes, and preserve stored contents. Builders haul the recovered pieces into available storage; full storage leaves them at the site. Other construction can also fetch recovered materials directly, so removing the last stockpile does not prevent rebuilding storage. Partial work, reservations and unhauled materials survive saves and interruption. Reject duplicate removal and protect upper structures and occupied vertical access. A selected removal site uses the existing work bar; after dismantling, its remaining material counts replace construction progress. Keep controls icon-only with concise hover labels, the enlarged icon geometry and 4-point strokes. No bottom instructions or persistent goals.

## Visible construction stages — 18 October 2026

Queued construction on natural ground or rock starts with four small upright sticks at the footprint corners. Confirmed 21 October: remove their side branches and halve their length while retaining their width. Omit these markers when building on another building or deck; platform markers use the supporting base below their deck. Replace the full translucent destination model with solid pieces earned by actual building work: vertical timber posts first, horizontal beams next, then walls and fittings, and roof panels last. Reveal individual pieces one at a time, with real ground shadows. Enclosed buildings use a temporary timber frame that becomes enclosed by their authored walls; open workplaces, ladders, platforms and surface plots reveal their own appropriate components without acquiring an unwanted finished roof.

Stages derive from installed materials plus current applied labour, so waiting for delivery makes no progress and saved construction resumes at the same appearance. Preserve construction recipes, duration, placement offsets, rotation and navigation. Each ground marker disappears as soon as a constructed post, wall or foundation reaches its own corner; unfinished corners keep their sticks. Derive this from the actual revealed pieces, including active labour and saved progress, rather than hiding all markers at a fixed overall percentage. This is the first refinement toward clearer construction stages; the wider sequence needs further work. A relocation destination uses the same ground-only markers and only builds after source dismantling. Removal and replanting retain their existing visuals. Keep progress bars selection-only and add no stage labels, instructions or persistent goals.


## Hay fields, soil beds and skylight — 18 October 2026

A hay field covers exactly 2×2 small world tiles (2 m square). Its saved grid address is the first tile, with a fixed half-tile visual offset so its border, collider, selection and placement preview align with all four tiles. Existing centered fields retain their saved position. A soil garden bed covers one small tile (1 m square), costs one timber and remains a separate foundation. Replace the old garden entry in the construction menu with Soil garden bed; keep existing legacy gardens and their saved crop progress. Four adjoining completed soil beds on the same floor support a hay field on a roof, platform or other supported floor. Flat natural sand is also valid; bare rock, slopes and bare roofs cannot directly receive a new hay field. Beds supporting a field or its construction plan cannot be moved or dismantled. Removing or moving the field leaves its foundations behind.

Updated 21 October: fields use a continuous solid golden crop surface at adult knee height, with sparse line-like spikelets. Low wooden perimeter planks remain. Use six pegs along each side: four intermediate pegs and one at each endpoint. The four corners are shared, giving twenty distinct pegs around an isolated field. Keep small variations in spacing, outward offset, lean and height, with each corner peg anchored to its corner. Keep every peg just outside the 4 × 4 metre footprint so standing hay cannot swallow it. Each map position has a distinct deterministic arrangement, reconstructed from the saved world seed and cell across reloads and view rebuilds. Shared-edge hiding still applies. Each harvested quarter exposes flat, opaque, pale muted soil; watering gradually raises the crop surface again. Harvest remains the existing `grain` resource internally for save, cargo, storage and windmill compatibility, but its visible name is **Hay**. The existing farmer occupation is **Grass gatherer**, and assigned gatherers continue cutting and hauling while storage has capacity. Keep existing irrigation and physical hauling.

Growing crops and berry bushes check the sky above their actual positions. Completed overhead roofs, floors and solid terrain reduce covered growth to 10%; partial field coverage averages the four planted tiles. Construction ghosts do not shade. This measures overhead exposure throughout the simulation rather than camera-dependent rendered shadows; the current day/night cycle does not additionally halt growth. Cache exposure until the world structure changes. Saved growth survives reload. Artificial lighting is future work through the shared crop-light calculation. No persistent instructions, goals or extra readouts.

## Two font sizes — 18 October 2026

All UI text uses the ordinary size of 22 points. The game title grows to 32 points. Keep only these two sizes throughout the game, including menus, counters, tooltips and Blueprint controls. This supersedes the earlier instruction to preserve text sizes when enlarging icons.

## Green grass and Easy Greece coast — 18 October 2026

Grass has saturated green, sharply triangular blades presented as upright camera-facing cutouts. Shared travelling gusts and small local flutter bend the tips while roots stay planted. Grass casts no shadows. Keep chunk batching, stable seeded placement, fog exclusion and clear construction/resource footprints.

Enable the existing Easy choice as a Greece-inspired coastal landscape: broad green meadows, low gentle rolling hills, a sandy shore and turquoise animated sea. Keep a flat, supplied opening for the family. Grass follows the actual hillside surface. The sea is nonwalkable scenery, separate from freshwater supplies. Normal retains its desert formations. New Easy settlements use the offered seed with the coastal generator; their landscape choice persists through saves, streaming and reloads. This adds no instruction panel or goal display. Economy recipes and timings remain shared between modes.

## Compact game icons — 18 October 2026

Reduce all game UI icon widths and heights by 50% from the enlarged version: resource, construction, selection actions, day/night, speed and compass. This supersedes the earlier larger-icon direction. Keep strokes at 4 points and text unchanged. Toolbar buttons return to 40 × 40 points; tighten construction rows while preserving space for their labels and costs. Keep the selection menu at the top center.

## Platforms over low buildings — 18 October 2026

Platforms can cover Piles and other low plots (roads, hay fields, soil beds and gardens). Either can be built first, including overlapping construction plans on the two floors. The lower plot remains usable and the completed deck supports upper construction. Posts still require support across their footprint; full-height buildings, ladders and natural obstacles retain their collision checks. A covering platform does not create a vertical walking connection or make the pile itself a structural support. Preserve inventories, physical hauling and saved construction progress.

## Borderless person icon — 18 October 2026

Keep the top-bar person icon free of a wrapping border or persistent selected appearance, including when adults are idle. Retain the population counts and click-to-cycle behavior.

## Smaller sun and moon — 18 October 2026

Reduce the day/night icon slot from 40 to 32 points and tighten the surrounding cycle arc from a 17-point to a 13-point radius. Reduce the sun and crescent geometry to 75% while keeping shared 4-point strokes and the existing day/night timing.


## House-relative farming dimensions — 18 October 2026

This supersedes the earlier small-tile farming dimensions. A standard house has a nominal 2 × 2 metre footprint; the minimum terrain cell remains 1 × 1 metre. Hay fields are now 4 × 4 metres, twice a house in each horizontal direction (four house footprints, or sixteen minimum terrain tiles by area). Soil garden beds are 2 × 2 metres each, so four adjoining beds still support one field. New fields are centered between the four bed centers, with a fixed (1, 0, 1) metre offset from the first bed address; existing saved field centers remain unchanged. Soil beds require support across the same footprint as a house. Wooden borders, crop density, collisions, previews and selection match the enlarged area. Sunlight averages sixteen samples across each hay field; fully covered growth remains 10%.


## Individual Blueprint construction — 18 October 2026

F2 Blueprints must use the same 3D assets as the main game. Provide individual logs and planks, explicitly confirmed instead of wall/floor sections, plus hay for roofing. The Pieces workspace uses original game meshes and materials at game scale, with surface placement, rotation and tilt, precise repositioning, undo and saved transforms. Keep controls concise and retain the existing room/map workspace and older files. No persistent instructions, goal text or goal counter.

## Blueprint entrance validation — 18 October 2026

In the Blueprint assembly workspace, reject placement when a building has no reachable entrance, and preserve access to existing buildings when placing or moving another. A door facing another building's wall creates a passage between their rooms. The connected group must still reach an exterior entrance; a sealed loop is inaccessible. Same-floor room connections follow doors, and floor changes still require explicit ladders. Show access through the existing door feedback and concise placement status. This direction applies to Blueprint assembly, not settlement navigation or individual decorative pieces.

## Custom settlement hotkeys — 18 October 2026

Settings contains a Hotkeys page with short action descriptions. Click a key and press a replacement; reject duplicate bindings and modifier chords, and let Esc cancel capture. Save changes across launches and provide Reset to defaults for all settlement keys. List fixed Esc and mouse gestures here as concise reference rows. Esc retains deselection/cancellation during play and menu navigation; Tab retains UI focus navigation. Blueprint authoring retains its separate editor controls. Keep references inside Settings and hover tooltips; do not add persistent controls, bottom instructions or goal displays to gameplay.

## Construction-site actions — 18 October 2026

Selected construction sites offer Move and Delete in the existing top-center action menu, including newly placed sites with no deliveries or building work. Reuse the arrow and bin icons with concise hover labels and existing Move/Remove hotkeys. Moving retains the plan's identity, progress and builder assignments. Confirmed 21 October: deleting immediately removes the construction shell and markers in gameplay and planning mode, releases incoming reservations, and leaves installed materials plus deliveries already being worked on as loose resources at the site. Materials still travelling stay with their carrier. Loose resources have no stockpile shell or reserved building footprint; another building can be planned directly over them and reuse them through normal hauling. Preserve quantities and reservations across cancellation, repeated replacement, saving and loading. Relocation and dismantling jobs retain their existing lifecycle. Keep the bottom instructions and persistent goals hidden.

## Placement through trees — 18 October 2026

During construction placement, trees are transparent to cursor picking. Continue the cursor ray through trees to the actual ground, roof or platform behind them instead of snapping to a tree's cell or canopy. Preserve normal tree inspection and work orders, and retain tree footprint collision checks for the proposed building location.


## Door-connected houses and Blueprint camera — 18 October 2026

Join door-connected rooms in both Blueprint Map and the live settlement. Two adjoining one-room houses become one 1×2 building with one perimeter and no internal separating wall; touching side walls, diagonal contact and different floors alone do not join. In the settlement, align new adjoining houses to the existing placement offset. Keep physical room addresses, construction recipes, labour, housing capacity and salvage for simulation and save compatibility; selection, copy, move and remove act on the connected house. In Blueprint Map, coalesce connected instances, preserving exterior entrances, attachments, work totals and undo/save behavior. Retain Blueprint entrance validation before merging.

Right-drag orbits the Blueprint camera with the main game's direction and sensitivity, in both room/map and piece editing. It never erases geometry or cancels a move. Middle-drag remains available; R rotates the placed draft or selected piece. Use explicit Remove/Delete, the Erase tool or Shift-click for deletion, and Escape/Cancel for a move. Keep gesture references in hover help and the existing controls dialog. No persistent instructions or goal display.


## Standard buildings in Blueprints — 18 October 2026

The Blueprint editor exposes the standard buildings, including Well, Ladder, Pile and Platform, for editing their appearance. Open their actual individual mesh components at game scale, retaining the log cabin as a custom sample. Keep the building choice and edit controls concise. Applied visual changes preserve gameplay recipes, dimensions, access and jobs; saved drafts remain editable and original appearances can be restored.

## Quarter-by-quarter hay harvest — 18 October 2026

Each hay field grows four wheat (the existing `grain` resource). Citizens work on one quarter at a time: completing its applied labour clears that entire quarter and yields one bundle to haul. The other three quarters remain standing, then two, then one, until the field is bare. Preserve the exact cut quarters and unfinished work through saves. Watering and regrowth restore the whole field for the next harvest; vegetable gardens and grass patches retain their existing yield. Communicate harvest progress through the crops themselves without extra UI.

Hay fields do not cast shadows: disable shadow casting on their geometry, including the crop blades, to remove sharp, pointy shadows.

Adjacent hay fields on the same floor hide their shared wooden planks and pegs, including only the touching portion of partially aligned edges. Keep the outer perimeter and restore exposed borders when a neighbour is removed or moved. Soil meets across the seam; harvest quarters, inventories and selection remain per field.


## Vine trees — 18 October 2026

Add vine trees as plantable flora beside completed buildings. Growth is earned over time, climbing and branching sideways along the existing quarter-room grid. Curved stems and irregular green leaves soften the grid; keep entrances clear and follow saved building placement offsets. Rain is sufficient in the default difficulty. Prolonged lack of water withers the leaves and eventually leaves dry woody stems; watering can rescue a living vine. Save water reserves, health and growth. Dedicated citizen watering and replanting are future difficulty work. Communicate plant condition visually without persistent instructions or a new goal display.


## Seed planting — 18 October 2026

Nature is a building mode in the top-right toolbar, alongside Housing, Industry and Structure. Its sprout icon opens the seed placement list for vegetables, trees, berry bushes, grass, palms and vines. Use Nature for the category heading and hover label. These are worker orders: an adult reaches the chosen spot and spends three seconds sowing before a small plant appears. Seeds are freely available in this prototype; no seed inventory or new resource counter is introduced. Trees and palms root on level natural ground; vegetables and grass also grow on completed soil beds. Existing hay fields retain their larger footprint and farming behavior.

Tree and palm seedlings grow visibly over 96 and 120 simulation seconds, respectively, then provide three physical logs. Harvested sections do not grow back; the final log removes the entire tree. Bush shoots take 24 seconds to reach 1/1 berries, then follow the established two-day berry cycle. Vegetables use the existing watering and food harvest loop; a one-cell grass patch grows in 24 seconds, can be cut into Hay, and regrows from short stubble. Overhead cover retains the shared 10% growth rule. Plant species, partial growth and sowing work survive saves; streamed trees and bushes catch up when reloaded. Moving crops leaves their soil foundations in place and preserves harvest without creating timber. Keep growth visible in plant silhouettes, using only the existing selection readouts and work bars. No persistent instructions or goal display.


## Radial vine growth — 18 October 2026

Vine trees also grow diagonally across supported quarter-grid wall squares. Several competing tips spread within a gradually expanding radius, forming an uneven branching fan inspired by slime mold. Established stems thicken as they support more branches; new tips remain slender. Preserve door clearance, attached wall support, rainfall and drought behavior, and existing vine saves. Growth may wrap corners through supported edges, but diagonal branches must never bridge entrances or empty space. Keep this behavior visual, without additional UI.


## Collected vine roots — 18 October 2026

This supersedes unlimited vine seeds and the wall-adjacent planting restriction. Wild vine roots can be collected by an adult through the selected plant’s Collect root action. Hide vines in Nature until the first collection, then show the available count in brackets and keep the option disabled at (0). Only vine roots are limited; all other seeds remain unlimited. Sowing reserves one root immediately, cancellation returns it, and collecting a planted living vine recovers one root. Save counts, discovery, collection work and reservations.

Vine roots follow the cursor continuously on level natural ground, using only a small root clearance rather than a whole terrain-cell footprint. Preserve the exact root position through previews, planting, rendering, picking and saves. A nearby wall is optional at planting; existing gradual autonomous growth finds nearby completed walls and spreads around supported corners while keeping doors clear. Keep rainfall/drought behavior and communicate growth visually.

## Closer trees and complete harvesting — updated 21 October 2026

Generated trees may grow closer together, including diagonal neighbouring terrain cells, in both landscapes. Preserve dry, level ground and clearance around rocks and bush colonies. Every object shown on the game map should support interaction. Living trees, dead trees and palms disappear completely when their final log is harvested, immediately clearing their construction and navigation obstruction. Leave no decorative stump or extra removal action. Clear exhausted stumps from older saves and streamed chunks as they load. Keep carried logs intact and preserve removal through saves and chunk streaming. Seedlings and trees with remaining logs retain their existing planting and harvesting behavior.

Vines remain wild, undomesticated flora. Collection recovers an existing living root; it never produces renewable seeds or extra plants. They need no farming job or manual tending in the default climate. An adult may also be ordered to collect a wild root by right-clicking it.


## Rainwater wells and utility buildings — 18 October 2026

Sand has one guaranteed opening rain puddle instead of three, and one quarter of the previous scattered puddle frequency. Fields retain their existing water distribution. Wells occupy a minimum terrain tile and can be built directly over a rain puddle or on other supported level ground. Rain yield is three droplets on a puddle, two one tile away (including diagonals), and one farther away; one is the minimum yield, not a water construction cost.

Each constructed well adds three storage. A full 3/3 puddle becomes a first well holding 3/6; rain fills the remaining capacity. Dry ground begins empty, with four capacity. Existing stored water does not evaporate or refill during dry weather. Placing another well on the same well, or relocating another well onto it, merges its storage units: +3 capacity per incoming unit. Relocation consumes the source, retains its water and construction materials, and leaves any excess water as haulable buckets. Merged capacity and relocation progress survive saves.

The first well is a simple surface hole, the second has raised masonry, and the third has a roof; later merges keep the roofed silhouette and add storage. A room constructed around a well becomes Waterworks, with an open utility frontage and visible water, rather than housing. It retains the well's water and collection function, adds no citizen capacity, and moves or dismantles together with the utility. Use the existing object tooltip for water current/capacity and existing Move/Copy/Remove and Collect actions; no upgrade panel, persistent instructions or goal display.


## Collected bushes and prepared soil — 18 October 2026

Bushes are semi-domesticated: wild bushes are finite existing plants that can be brought back to the village, never grown from unlimited seeds. Move on a selected bush queues an adult to uproot it. After collection, the existing bush becomes available in Nature as Berry bush (n); hide the option until first collection and keep it dimmed and disabled at (0). Right-click harvesting remains berry gathering.

Replant only on completed, unoccupied soil garden beds (prepared farmland), including beds on accessible elevated floors. Bare sand, grass and bare platforms are unsuitable; active crops cannot share their plot with a bush. The entire bush plot must be supported by prepared soil. Reserve one collected bush per planting order and return that same bush if the order is deleted. Preserve berries, capacity, maturity and partial growth time through uprooting, storage, replanting, saves and streaming. Uprooting does not reproduce bushes or refresh their berries; growth resumes after replanting. Keep the soil foundation when collecting a planted bush and prevent removing soil under a bush or reserved planting. Previously saved seed orders may finish, but no new unlimited bush orders can be created. Other unlimited seeds and collected wild vines retain their rules.

## Natural grass around construction — 18 October 2026

Updated 19 October: hide natural grass within building footprints, without bare padding outside them. Keep grass beneath platforms and ladders/stairs and beneath elevated buildings. Clear a construction footprint once materials are installed; restore natural cover when the structure is removed. Remove Grass completely from the Nature menu and reject new grass sowing orders, including copying an old grass patch. Retain existing saved grass patches and orders for compatibility.


## Water foundations and vertical terrain — 18 October 2026

Confirmed: allow a settlement to grow over water on supporting platforms near shore. Posts must reach solid bottom; water itself is not structural support. Preserve vertically expandable terrain and volumetric water on the square grid, with deeper excavation and underground discoveries as the intended direction. A well disconnected from its supporting earth must stop producing water, while retaining already stored buckets.

Current foundation: coastal saltwater resolves into three-dimensional cells above a deterministic seabed, with negative depths sampled on demand and sparse material changes preserved in saves. Existing one-floor timber posts support decks at shore elevation in shallow water; construction proceeds from accessible shore or completed decks. Deep water rejects these short posts. Buildings can occupy completed decks. Well recharge checks the earth directly beneath the well; the existing rain and storage rules otherwise remain. Saltwater does not become drinking-water inventory.

Still to implement: player excavation jobs and controls, underground terrain rendering and discoveries, water flow into excavated cavities, longer foundations, and full vertical chunk streaming. The sparse volume model does not itself enable these gameplay systems or lift the current building-height limit. No new persistent UI, instructions or goals.


## Stone volume and half-storey foundations — 18 October 2026

The physical world grid is 1 metre horizontally and vertically. A standard house remains 2×2 metres with a 2-metre storey; it can begin on a supported 1-metre elevation and stack another room at 3 metres. Preserve saved buildings' physical elevations when converting old two-metre height addresses. Terrain generation retains its existing physical cliff heights. Ladders connect explicitly to either one- or two-metre landings and match that rise visually.

Natural stone uses the filled-volume direction above, superseding the earlier tapered faces. Logical sections join without gaps, while slight corner offsets and cap angles vary their silhouette without bevels or additional faces. Capacity is rounded occupied logical volume × 9 (updated 21 October 2026): each 1 × 1 × 1 metre cube yields nine stones. Existing saved deposits retain their goods and reservations; new deposits use the reduced yield. Mining cuts half-metre regions into progressively smaller remnants; the selected object's existing current/capacity label reflects the resulting stock. Saved quantities reconstruct the same remaining geometry. Empty regions stop obstructing construction and navigation, including regions away from the deposit centre. A level logical support plane can carry a footprint independently of the decorative contour. Keep mining away from rock beneath existing or planned buildings and residents through the full six-metre height. Do not add structural collapse or a new UI panel.

## Windmill scale — 18 October 2026

The windmill is 6 m tall on a 2 × 2 m footprint, with a roughly 2 m diameter sail assembly near the top. Building height is not limited to one room level. Preserve the village plaster, timber and terracotta palette. Its occupied volume spans three storeys and its upper construction socket is at 6 m.


## Sawmill working conditions — 18 October 2026

Sawmills can stand on completed supported floors. New sawmills begin as simple crossed timber sawhorses (tier 1). Placing another sawmill on that workplace builds the existing saw bench (tier 2); placing a house around the tier 2 bench creates a dedicated open-front timber saw shed with a roof and plank stacks (tier 3), retaining its industrial function and adding no housing. The bench remains visible inside the shed. Each completed upgrade improves production speed; plans alone give no bonus. Initial tuning is 0.75×, 1× and 1.5× the former sawmill rate. Existing saved sawmills retain tier 2. Preserve tiers and invested materials when saving or relocating. Other industrial buildings should receive their own recognizable architecture when their upgrades are introduced. No new persistent panels, instructions or goals.

## Half-height platforms — 18 October 2026

New platforms start at Tier 1: 1 m tall on a 2 × 2 m footprint, half a standard house storey. Building a second aligned Tier 1 above it automatically combines the pair into a Tier 2 platform, 2 × 2 × 2 m, with continuous supports and only the upper deck. Preserve both platforms’ materials in the merged object. Clear an occupied lower deck before merging; reserve it during construction. Existing full-height saved platforms remain Tier 2.

## Three-stage open mill — 18 October 2026

User reference screenshots replace the enclosed plaster windmill tower. Tier 1 is a simple circular grinding stone. Tier 2 adds a long manual lever and requires two operators present to grind. Tier 3 adds four long timber posts, an exposed central drive shaft and a small upper gear housing with a steep triangular terracotta roof and linen sails. Preserve the narrow 6 m tall silhouette, roughly 2 × 2 m footprint and 2 m sail assembly. The mill keeps its placed heading; only the sails, shaft mechanism and runner rotate, never the building toward the wind. Reapplying the mill tool upgrades the same object through three stages. Existing complete mills load as Tier 3.

## Millstone wheels and shorter windmill — 19 October 2026

All three mill tiers use two stacked circular stone wheels with actual central grain holes; the upper wheel turns during milling while the lower wheel stays fixed. Tier 1 includes a timber chair. Tier 3 has a substantially lower open frame (roof peak about 3.6 m) and sails three times their previous size, roughly 6 m across. Keep the hub just above 3 m so the enlarged sails clear the ground throughout rotation. The six-metre vertical clearance remains for the swept sail envelope, not the tower height.

## Uneven soil and construction levelling — 19 October 2026

Natural soil should vary within the one-metre world layer, with small hollows that collect rain. Logical cell identity, physical surface height and structural support are separate: a thin soil covering remains material, but crossing a percentage threshold does not turn it into a level building foundation. Keep the existing larger slopes and level sandstone tops. Digging removes the uneven surface down to an exact grid plane.

Confirmed: construction includes levelling automatically. The initial implementation adds seeded Perlin relief, up to 0.44 m above the logical floor, using shared corner samples and a centre sample. Freshwater bowls can dip 0.08 m below that plane so a neighbouring levelled edge does not erase their visible basin. Geometry, collision and walking use the same triangular surface. The first installed construction material cuts the foundation's terrain cells to the grid; adjacent cells share the lowered corners. Cuts persist after cancellation, demolition, save/load and streaming. Keep natural grass around construction, clearing only the building footprint as specified below, and add no controls, instruction panels or goal UI. Existing saves without soil relief retain their original terrain.

Natural closed hollows begin dry and refill through the existing rain/bucket system; their horizontal water surface is clipped to the actual bowl and shrinks as water is collected or evaporates. Previously generated freshwater sources retain their inventories. This is local rain collection, not a complete runoff, erosion or underground flood simulation. Separate player excavation jobs and deeper terrain rendering remain future work. Standard building floor finishes receive 8 mm of physical clearance above their support plane to avoid coplanar flicker; logical floors and stacking sockets stay on the metre grid.


## Residents, food reserves and dedicated storage — 19 October 2026

The top population counter shows actual citizens / completed housing capacity. Each completed room has three places; the starting family does not add invisible housing. Assign residents to individual rooms and preserve their homes through saving and relocation. Selecting a house reports only the residents and capacity of its connected rooms, plus their combined food inventory. Empty, partly occupied and full single-room homes read 0/3, 1/3 and 3/3. Keep idle selection on the person icon and move its idle count into the existing hover tooltip.

Top resource values use current/capacity. Food also shows the population's meal demand as −N: one food per citizen per hunger interval (30 simulation seconds before travel/eating time). Automatic food production targets three meals per resident, allowing a two-meal reserve to support births. Birth progress takes 120 fed simulation seconds with a reachable vacant home; temporary food shortages pause it instead of resetting it. Children spawn at reachable house access and retain the existing maturation rules.

Logs go only to wooden sheds, hay/grain only to hay barns, and food to houses (12 food per room). Piles hold stone, blocks, planks and collected water. Remove Pantry from new construction choices; existing pantries and starting/legacy pile supplies remain usable until consumed or physically transferred to the appropriate stores. Do not delete or duplicate saved supplies or active reservations. Legacy goods contribute only their occupied amount to capacity until transferred, rather than granting new storage for forbidden goods. Mixed pile resources share the pile's capacity. Existing saves gain house food stores and resident assignments. Keep instructions and goals hidden.

## Small log rain shelter — 19 October 2026

The log shed uses the supplied open four-post shelter references: a 1 × 2 m model, a frame about 1 m high and a single sloping, overlapping-course terracotta roof reaching 1.5 m. Keep it inexpensive (three logs) and accept logs only. Arrange stored logs beneath the canopy. This lightweight pitched shelter does not provide a new walkable roof.

## Joining Tier 1 hay shelters — 19 October 2026

Tier 1 hay barns are 1 × 2 m open timber shelters reaching 1.5 m, with three triangular slopes forming half a pyramid. The apex lies on the open joining side. Adjacent matching halves automatically face each other, forming a pointed four-sided pyramid over a 2 × 2 m pair. Share the two posts on their common edge and omit redundant seam rafters; removing either half restores the remaining standalone supports. Each shelter costs three logs and retains its own grain storage.

## Three-tier stone storage — 19 October 2026

Dedicated stone storage has a 3 × 3 m footprint and reaches 2 m. Tier 1 has four vertical posts and no horizontal frame beams, holding 32 raw stones. Tier 2 adds the horizontal timber frame, remains roofless and holds 64 stones. Tier 3 retains that capacity and adds plank side walls and a flat timber roof with one front entrance. Lower tiers can be serviced from all four sides; the enclosed tier uses only its rotated front entrance. All tiers provide upper construction support at 2 m. Reapplying the storage tool upgrades it while preserving inventory, reservations and invested materials. Existing mixed stockpiles remain available.

Stone-storage floors use dark brown timber so the pale stored stones remain readable.

The log-shed roof falls across its short 1 m side; the overlapping roof courses run along the 2 m length. Keep the footprint and total height unchanged.

Tier 3 stone storage has open sides and rear, each with one central vertical timber support instead of plank infill. Retain the entrance-side wall and doorway, flat roof and single service entrance.

Quarried raw stone uses closed, chunky rectangular fracture blocks with chipped corners and broad pale faces. Avoid rounded boulders or hollow pot silhouettes. Preserve outward shading normals and Godot-clockwise exterior faces in stored and carried raw-stone meshes.


## Pottery warehouse — 19 October 2026

A compact Small warehouse is the third tier of a stone-corner Pile: reapply the Pile tool to create an open pottery rack, then reapply it to construct the enclosed warehouse. The warehouse is also available directly in Industry. It is a 1 × 1 × 1 metre timber building with a flat slatted top, braced sides, shelves and one front entrance; no pitched roof. Its upper surface supports only its actual one-cell footprint and needs explicit vertical access. The existing wider ground pile remains compatible with saved layouts and joined-pile outlines.

Confirmed resource specialization: this warehouse holds only pottery—small clay pots intended for food preservation—with no resource picker. The intermediate rack is also pottery-only. Piles can hold pottery alongside their existing goods. Existing contents and reservations survive conversion; haulers move incompatible legacy goods to suitable storage. Capacities are 32 for a pile, 48 for a rack, and 64 for the warehouse. Current construction tuning uses two logs and two planks for the rack, then ten planks and six finished stone blocks for the warehouse. Bricks and roof tiles are not yet resources.

Pottery has a saved resource identity, clay-pot cargo and storage visuals, and appears in the existing resource bar only after acquisition. Pottery manufacture and actual food preservation remain future production mechanics; do not silently convert food into pottery or grant stored pots a food effect. Keep instructions and goals hidden.

## Full-scale Blueprints layout sandbox — 19 October 2026

Blueprints opens a separate building-layout sandbox with every current construction type and its authored tiers at actual metre scale. Keep the original parts/room editor accessible through Edit parts. The gallery supports drag movement, duplication, quarter-turn rotation, deletion, undo/redo, camera zoom/orbit/pan, and numeric height/position edits. Free, half-metre and metre placement snaps are experiments against a fixed 1 m grid; do not change settlement placement or road connectivity rules until the user chooses a direction. Footprint outlines and teal authored entrance markers make alignment visible. Preserve layouts and camera state separately from settlement saves and pause the settlement throughout this workspace. Do not introduce a tutorial or persistent control list.


## Unified Blueprint asset authoring — 20 October 2026

The user's clarified direction replaces the separate Layout gallery entry with one in-game asset editor, similar in purpose to a simplified Blender/Figma workspace. Use the standard game font. A searchable library contains original primitives, editable components and prefab assemblies. Open existing buildings to edit their actual mesh parts; expose their source files for Blender and support explicit model exchange.

Occupied grid dimensions are authored separately from the rendered mesh (for example 2×2×2 or 1×2×2). Show the occupied volume; permit a small adjustable overlap and highlight geometry beyond that allowance in translucent red. Wall and floor utilities carry their own occupied volume and mount metadata. Prefabs compose repeatable components across levels with explicit ladders, landings and utility/pipe placements. Editing an instance retains its hierarchy. Keep the distinction between asset authoring and live simulation: future city generation, utility networks and live prefab placement require explicit simulation integration; appearances must not silently redefine navigation or construction contracts.

Blueprint numeric step buttons use tenths (0.1), preserving untouched source precision. Manually typed numeric values retain their extra decimal places through refresh, undo/redo and saving; explicit numeric coordinates bypass placement snapping, including for buildings and multi-selection. Stepping resumes at the next tenth in the chosen direction. Hide the large XYZ movement rays on selection. Face mode edits any one of the six sides with its opposite side fixed, using compact face handles and 0.1 m inward/outward nudges. This is one-sided resizing; retain rectangular wall geometry. Edited and duplicated windmill sails retain their attachment to the existing rotor and follow its animation and tier visibility.

Angle mode shows a selectable sphere around the selected part or assembly. A point on the sphere chooses an axis through the mesh bounds' centre; that centre remains fixed during rotation. Provide a 0.1° angle input, X/Y/Z shortcuts and an axis flip, with a compact axis and angle arc visible only in this mode. Preserve imported transforms, component hierarchy, occupied-space metadata, undo/redo and saved geometry.

## Assets, building assemblies and utility connections — 21 October 2026

Keep Assets and Buildings in separate library views. Logs, stones and equipment are reusable assets; a school or house is a building assembled from instances of assets arranged into its shape. Preserve the identity, transform and hierarchy of those instances so individual pieces remain editable. Prefabs compose reusable arrangements of buildings and assets. A building must not be classified as a loose asset merely because both have a 3D model. Existing buildings currently expose authored mesh parts; converting those source meshes into shared log/stone asset instances is separate authoring work, not accomplished by changing the library classification.

Future equipment tools include AC units and satellite dishes. Equipment tiers belong to the asset: AC Tier 2 has a distinct, slightly larger 3D model. Indoor and outdoor AC units mount on walls and connect to one another with coolant tubes. Tubes are extendable routed assets that attach along walls and can pass through a wall; they are not just a row of decorative pipe meshes. AC equipment also needs a power wire to an electrical outlet. A satellite dish connects to a TV by a signal cable and to an electrical outlet by a power wire.

Save explicit endpoint identities, connection types and routed paths independently of rendered geometry. Keep power, signal and coolant connections distinct from pedestrian navigation. Wall mounts, wall penetrations and model tiers must retain their connection relationships through editing and saving; appearance alone never establishes a working connection.

Many devices, tubes and wires should accumulate visibly along walls, creating the crowded, lived-in village feeling. Highlight the inspected wire or tube and its connected endpoints so the player can follow its entire route among overlapping connections. Communicate through the objects and selection feedback, with concise labels only; keep instruction panels and persistent goals hidden. These networks, tiered equipment models and connection-tracing interactions are confirmed future gameplay, not features implemented by the current authoring previews.


## Blueprint origin and snapped construction — 21 October 2026

Blueprint floor squares measure 2 × 2 metres. Mark the fixed workspace origin (0, 0, 0) with a small floor dot and concise coordinate label, visible through the model. Building pivots retain their floor-centre convention; camera framing and selection never relocate the origin. Inside a component, coordinates refer to that component's editing space.

Restore exact grid placement for new game construction and building/prefab assemblies in Blueprints. Both use the existing 1 m horizontal and vertical sockets within the 2 m room module, including negative coordinates. Preserve authored mounting offsets, field anchors, saved deviations and upgrade/join alignment. Loose assets and mesh parts retain 0.1 m editing, including surface mounting. Existing saved geometry must not shift merely on opening. Small cursor-driven deviations and a Shift precision modifier are future work. Keep diagnostic coordinates in Blueprints and keep gameplay instructions and goals hidden.

## Fixed construction stock and placed models — 21 October 2026

Logs and planks are the physical scale reference for construction. Reuse the original hauled log (0.9 m trunk, uniform 0.23 m diameter from end to end; no cone-shaped taper) and individual sawn plank (0.70 × 0.055 × 0.22 m). Build longer members and broader timber surfaces from repeated pieces, with overlapping joints; do not widen logs beyond the trees or stretch boards. Small fasteners and fittings remain separate details. Stone, plaster, cloth and terracotta keep their material identities.

Placed building instances retain their authored dimensions and orientation. Blueprints must lock Size, Face and numeric scale for whole buildings, logs, planks and assemblies containing these; translation, rotation and duplication remain available. Source non-timber mesh authoring remains editable. Saved instance scale must not bypass the lock. This supersedes whole-building resizing and the joined facade/post changes: neighbouring buildings leave each other's shells intact. Completed neighbours above/below still change floor and roof presentation, including partial roof coverage. Explicit upgrades use authored variants assembled from the same stock, rather than stretching the placed model. Preserve simulation footprints, access, costs, inventory and save identities.

Timber has three selectable visual palettes: regular tree (warm brown), palm (deeper brown), and dead tree (weathered grey-brown). All three reuse identical log and plank geometry at the fixed stock dimensions. Planks and exposed log ends use matching lighter wood colours, while logs retain darker bark. Blueprints allows choosing a palette for individual timber parts or an assembly, mixing colours within a building for accents. Preserve these choices through copying, undo/redo, saved blueprints and applied building appearances. These are visual choices; they do not introduce separate harvested resources.


## Log length editing — 21 October 2026

Restore Size, Face and numeric length scaling for individual logs in Blueprints, as cutting stock shorter. Only the log's local length axis is editable, with two end handles and the opposite end held fixed. Keep its diameter unchanged and cap length at the original stock length. Rotation and tilt do not change this constraint. Preserve cuts through duplication, grouping, undo/redo and saved appearances. Planks, whole buildings and assemblies containing multiple pieces retain their size locks; this is the exception to the log resizing restriction above. Reuse existing controls without adding instructions or goal displays.

## Blueprint Escape behaviour — 21 October 2026

Escape deselects the current object and keeps Blueprints open, including inside a nested component. It cancels an active transform preview or insertion; repeated Escape with nothing selected does not exit. Return to the game through the close button or F2.

## Blueprint Parts selection and height — 21 October 2026

Selecting an object in the 3D workspace immediately selects and reveals its corresponding Parts row. Shift-click adds objects to the current selection in the scene and Parts list, retaining previously selected objects, including when clicking them again. Keep all selected rows highlighted together. The Parts list fills the remaining sidebar height and grows with taller windows; preserve its scroll position while editing the same selection.


## Blueprint rotation applied to scene elements — 21 October 2026

Angle mode rotates the selected scene element live when dragging its X, Y or Z ring, keeping that axis fixed throughout the gesture and the mesh centre stationary. Ring drags snap to 15° increments; numeric angles retain manually entered precision through Rotate, with 0.1° step buttons. The axis shortcuts show the selected axis, and dragging inside the sphere away from a ring uses that axis. This supersedes the sphere gesture that only selected a free axis without turning the object. Preserve dimensions, imported transforms, hierarchy, undo/redo and saved orientation; Escape cancels the rotation and deselects without closing Blueprints.


## Blueprint multi-selection — 21 October 2026

Shift-click adds or removes individual layers from the selection in both the Parts list and the 3D viewport. Selected layers move together on X/Y/Z and rotate around their combined mesh centre, preserving their spacing, individual dimensions, imported transforms and nested hierarchy. Treat this as a shared selection without rewriting the saved component hierarchy. Disable Size, Face and numeric scale whenever multiple layers are selected. This supersedes Shift-click deletion in asset authoring; Remove/Delete remains available. Show selected rows and shared yellow outlines without adding persistent instructions or goals.


## Blueprint axis labels — 21 October 2026

Use Z for height and Y for depth throughout Blueprint controls, rotation shortcuts, face labels and coordinate tooltips. X stays width. Axis colours follow the displayed names: X red, Y green, Z blue. This is a UI naming convention; retain Godot's internal Y-up coordinates, saved transforms and imported geometry.

In Move mode, show small axis arrows at the selected object's mesh centre (or the combined centre of a selection). Keep each arrow within 40 logical UI points of the centre at every camera zoom, with the shared 4-point strokes. Dragging a shaft or arrowhead moves only along that axis, using metre steps for buildings/prefabs and tenths for loose parts. Preserve spacing in groups, undo/redo and cancellation. This replaces the hidden movement handles without restoring the former large XYZ rays; keep the centre free for ordinary dragging.

## Blueprint grouping — 21 October 2026

Ctrl+Shift+G (also Command+Shift+G) ungroups selected groups by one level, preserving their members' visible transforms and nested contents. Keep the released parts selected and make ungrouping one undoable action, including inside an open group.

Command-G (Ctrl-G on other keyboards) turns multiple selected 3D objects into a persistent Group layer in Parts. Clicking any member selects the group; dragging moves its members together. Preserve their exact positions, orientation, dimensions, metadata and nested components when grouping. Double-click or Edit instance opens the group for individual edits. Grouping is one undoable action and survives saving/reloading. Keep building/prefab movement on metre steps and loose-part movement on tenths. Ordinary multi-selection remains temporary until explicitly grouped. Use the existing Parts list and selection visuals without adding persistent instructions or goals.


## Finished-layout construction planning — 21 October 2026

While a construction tool is held, show queued buildings at their finished shape and allow subsequent placement on their planned roofs and decks. Two vertically aligned 1 m platforms preview as one tier-2 platform with a single deck at 2 m, aligned with a standard house roof. Hide the disappearing intermediate deck and reflect planned roof coverage. Returning to inspection restores the actual construction stages.

Future buildings use semitransparent finished geometry, including their complete visible top roof, without solid shadows. Completed floors remain opaque. When a future second floor covers an existing first floor, hide the covered first-floor roof and show the future roof on the translucent upper floor. Preserve exposed lower roof sections in offset stacks; cancellation restores the existing roof and completion makes the new floor solid.

Plans remain construction orders with their existing materials, labour and identities. Builders wait for completed support and real access; projected floors never become pedestrian navigation. Moving or deleting support leaves dependent plans waiting until valid support is restored. Recalculate the finished layout from saved plans, including after cancellation or reload. Communicate through the models and existing placement outline, without new panels, instructions or persistent goals.

## Blueprint library, building variants and replaceable groups — 21 October 2026

Replace the shared Assets/Buildings/Prefabs category dropdown with separate sections: Prefabs at the top, one Building chosen through a Select input, and Assets always available below. Asset search affects only Assets. Keep Parts available beneath the library and let it fill extra window height.

Connected two-room and two-level layouts belong to the House family as named building variants, rather than being classified as Prefabs. Other building families use the same arrangement. Save a variant as an independent editable snapshot, with Original and named variants in the building's variant selector. Keep unrelated collections in Prefabs. Preserve family identity, metre placement, fixed building dimensions, hierarchy and workspace persistence. Variant authoring does not change live settlement connectivity or construction recipes.

Select source groups such as Roof or named groups through the existing Parts area. Group selected pieces, name the group, and store the selection as a reusable Asset. Replace a selected part/group with a stored component, including authored window-wall or balcony-wall alternatives. Keep its floor-centre anchor and orientation; retain the replacement's authored dimensions rather than stretching it. Preserve the slot name, nested hierarchy, undo/redo and save/load. New window or balcony geometry must be authored as an asset; naming a group does not generate its geometry. No persistent instructions or goal display.


## Blueprint area selection and mesh edges — 21 October 2026

Drag from empty space in the 3D workspace to select every object whose projected mesh intersects the rectangle, including objects behind others. Shift-drag adds to the current selection. Release finishes the selection, including outside the viewport; Escape cancels it and deselects. Preserve existing object dragging, axis tools, Parts selection and grouping.

Only selected objects show yellow shape outlines. Follow actual transformed mesh edges, including tilted faces, ends, corners and curved silhouettes; omit coplanar triangulation diagonals and axis-aligned enclosing boxes. Groups retain their members’ shapes. Keep the shared translucent 4-point stroke and the current monochrome presentation. The user will prepare and group sections of House as the guiding reference for future buildings; preserve that source until it is ready.

## Linked components and game props — 21 October 2026

Prefab instances reference their component source rather than storing independent copies of its meshes. Changes to the original House or a named component propagate through existing and nested instances while preserving placement, orientation and hierarchy. Editing a linked instance edits its shared source; ordinary local groups remain local. Save references and component definitions once, retain undo/redo, reject circular references, and migrate older asset-reference snapshots on opening. Named building variants remain independently authored sources; an instance links to its chosen variant.

Include reusable non-building game props in Assets. The short branchless construction-corner Stick is a shared 3D asset used by the actual construction markers and available for other assemblies. Existing furniture and cargo models also belong in Assets, separate from Buildings. Keep the existing concise interface without new instructions or goal displays.

## Procedural nature — 21 October 2026

Trees, palms, bushes and natural stone should vary through generators rather than repeat identical assets. Keep a consistent family silhouette while constraining trunk lean, changes of direction and branch angles. Generate individual tree and palm geometry from a stable seed, with varied height, crown size and palm fronds. Updated 21 October: living and dead trunks stay nearly uniform in diameter, close to the shared 0.23 m logs. Remove exposed roots and flared bases so trunks enter the ground as simple sticks. Pack more trees, including more dead trees, into dense forest patches with open ground between them. Retain existing rounded bush silhouettes and sandstone outcrop geometry. Shape identity survives saving, streaming and moving a plant. Authoring controls belong in the separate nature generator preview; preserve the clean gameplay UI and existing resource/harvest rules.


## Queued icon desires — 21 October 2026

People and buildings communicate desires through icons alone, without bubble text or counters. Heat uses rising warm waves, thirst a water drop, a blocked or disconnected entrance a door with a cross, and missing required electrical service a lightning bolt. Keep these concepts distinct. Each building owns its own requirements and service state: one disconnected building does not stand in for every other building.

Show one request at a time, with a quiet gap between bubbles. Give each pending owner/need a turn before repeating old requests; re-evaluating a need must not restart its turn or duplicate it. Clear resolved needs and removed speakers immediately. Off-screen requests wait without taking a visible slot. A selected building does not monopolize the queue. The current tuning is a two-second initial delay, four-second display, one-second gap and at least twenty-four seconds before repeating.

Keep icons as separate editable SVG assets in `assets/ui/desires/`, selected through `speech_icon_library.gd`. The icon slot is 32 logical points with 4-point source strokes and 8-point padding. A rasterized 3D asset can replace a texture later without changing the queue or simulation state.

Current implementation: Blueprint entrance requests come from its existing walking graph. Saved `desires` dictionaries accept `hot`, `thirsty`, `requires_electricity` and `electricity_connected` booleans; missing parameters do not create a request. The live settlement shares the queue presentation for person/building parameters. Heat, thirst and electrical service still require their future simulation producers; merely adding AC or a wire mesh must not claim that these needs are satisfied. The queue is disposable presentation state, while desires persist with their owners. Keep the bottom panel and persistent goal display hidden.

## Handmade building variation — 21 October 2026

Placed buildings may deviate subtly from their source models, with corner and part positions varying by at most ±0.1 m. Break up repeated walkway planks and paving stones with individually varied ends and alignment. Use smaller deviations on thin pieces and structural joints. Keep timber stock dimensions, level walking surfaces, logical footprints and access sockets intact. Variation is deterministic per world and placement, shared by placement previews, construction and completed buildings, and reconstructed on reload. Keep source models editable and exact in Blueprints; add no gameplay controls or explanatory UI.


## Blueprint explicit editing and local library — 21 October 2026

Select assets, prefabs, buildings and variants without entering their editor. Open them through Edit; use Edit instance to enter a selected assembly. Double-clicking in the library, Parts list or viewport keeps the current editing scope. Expose the existing house roof face as a reusable Roof face asset, retaining its source mesh, material and dimensions. Label local reuse actions Add to library and Add part to library; this is the workspace library, with no model store or purchases. Save persists the workspace to disk. Keep explanatory details in concise hover tooltips.


## Blueprint corner-aligned placement — 21 October 2026

Put the fixed (0, 0, 0) origin at a grid intersection, superseding the half-tile offset in Blueprint authoring. Retain the 2 × 2 m major squares with quiet 1 m subdivisions. Snap building and prefab occupied-volume corners to the metre grid, accounting for rotation and authored volume offsets, rather than snapping their source pivots. Two 1 × 2 × 2 m building modules can sit side by side in one 2 × 2 m square and on either side of a supporting roof. Dragging uses the same corner alignment. New default building footprints use whole metre cells, independently of the slightly inset facade bounds. Preserve existing saved/source transforms, precise numeric overrides and loose-part surface placement; this changes Blueprint placement only.

## Reusable roof coverings — 21 October 2026

Add Ceramic roof tile and Metal roof sheet to Blueprint Assets. The Italian-inspired ceramic piece is a hollow, tapered terracotta barrel tile, suitable for overlapping rows at independently authored angles. The Japanese-inspired metal piece is a simple charcoal sheet with restrained raised seams and a shallow single slope. Both are editable, rotatable reusable geometry with separate TSCN/GLB sources; they do not add resource recipes or change existing building roofs automatically.


## Uniform sunlit sand — 21 October 2026

Uneven soil keeps its physical relief, collision and water hollows, but all exposed sand uses the same sunlit sand colour. Do not darken individual soil triangles according to their slope: this reveals the triangulation as false shadow patches. Real cast shadows and the shared day/night tint remain responsible for darkening the ground; preserve the separate sandstone strata and coastal vegetation palette.


## Direct sand editing — 21 October 2026

Updated 7 November 2026: hide the Dig and Fill terrain buttons from normal gameplay. The user wants landscape modification handled differently; the replacement interaction is undecided. Keep the existing terrain-editing implementation and saved terrain changes for development and compatibility, without exposing replacement controls. The retained tools operate on one-metre surface cubes with collision/navigation updates; their scope is documented in `VERTICAL_PROTOTYPE.md`.


## Block City construction lab — 24 October 2026

The separate Block City demo now tests coloured upright room shapes before assigning building uses or an economy. Hide the title, plot/resource counters, building names and permanent tool sidebar. Show only coloured current/next pieces. Remove tipping, inspect mode, forecast purchase, lot purchase and on/off controls. Escape opens Resume / New Game / Quit in this demo; the settlement retains its existing Escape behavior.

Keep the 3×3 foundation. Permit a supported one-cell upper overhang above a one-cell pedestrian passage. Beyond that passage, use a three-cell-wide front road and one-cell side/rear alleys. Surround the lot with grey buildings assembled from the same cell-sized cubes, three cells high.

A corner power pole is a direct world action: click it, then a visible exterior wall edge on the desired floor. Draw a hanging string-like cable. Reject blocked sight lines and cable intersections; energize connected cells on that floor only. Keep pedestrian access and stairs separate, with direct door interaction. Building types, production switches, economy and further lot progression are deferred. See [the current lab design](block_city/DESIGN.md).

Block City mouse/camera follow-up: left-click and Space both place rooms; pole and door clicks retain their direct actions. R rotates the room. Q/E animate quarter-turns, right-drag orbits freely, and the scroll wheel zooms. Keep these controls out of persistent UI text.

Block City flat-shape follow-up: incoming rooms are one cube high. Replace the 2×2 square with a 2×3 rectangle; retain four-cell L shapes with mirrored and rotated variants, removing T and multi-storey pieces. Vary grey neighbour footprints around the previous 3×3×3 mass, with simple details and directly supported upper floors rather than overhangs.

Block City street-grid follow-up: extend the roads through one extra ring of surrounding city blocks beyond the playable area. Continue the wide front road and connect the side/rear streets to an outer grid around the grey buildings.

Block City easier-supply and preview follow-up: hide the Next label and upcoming shape. Show a solid landing-position building with its correctly rotated door; remove the floating ceiling ghost. Add flat 1×1, 1×2, 1×3 and 2×2 footprints, favor them over the L shapes, and expose relative draw weights in the balance JSON. Prevent cantilevered cubes from becoming load-bearing columns for further construction.

Block City interiors follow-up: make the 1×1 and 1×2 modules corridors and add a 1×1×1 U-turn stair that connects adjacent levels, with a 180-degree reversal between the two flights. Show exterior windows and real doorway openings. Provide a single icon-only corner control cycling roofed, roofless/full-wall and low-wall cutaway views; keep all text labels and other controls hidden.

Block City pole targeting follow-up: only the visible circle at the pole top activates wiring. Keep its target size fixed in logical UI points. The shaft is click-through so it never prevents building placement behind the pole.

Block City responsive-camera follow-up: automatically frame the scene for resized window proportions. Keep gentle scroll zoom available, cap close-ups, preserve relative zoom through resizing, and keep corner controls inside the viewport.


Block City roof/wiring follow-up: snap new pieces onto the room roof beneath the cursor. Only the final occupied volume must clear existing cables; an overhead wire must not block the whole drop column. Mark disconnected entrances with red doorframes and exterior doormats. Fade foreground grey neighbors that obscure the playable volume. Short right-click puts the current piece aside; its corner thumbnail toggles placement. While deselected, click existing powered cable sockets to daisy-link another visible building floor. Preserve horizontal-only passive power spread and require explicit cables between floors.


Block City hall-cutout follow-up: individual colored modules are rooms. Make 1×1 and 1×2 halls neutral gray with an open floor and four corner support columns, including their thumbnail and preview. Allow a hall to replace only the overlapping cells of a colored room at the targeted level, preserving the surviving sections and opening their entrances onto the hall. Preview the actual cut; support and existing electrical connections remain intact. Protect halls/stairs from overwrite. Hold Shift for roof stacking; one undo restores the complete original arrangement.


Block City first-room feedback follow-up: snap the first room completely onto the foundation at ground level for every rotation, preventing an unsupported floating preview at the lot edge. Keep the room's actual appearance and the shared yellow preview outline. Use green entrance mats for sidewalk/hall access and yellow for an inward-facing or otherwise unconnected entry; this supersedes the prior red disconnected-entry styling. An unconnected door is a hint for future access, not a placement prohibition.


## Block City economy planning lab — 25 October 2026

Explore a minimal economy with at most three resources, using money and residents in the first experiment. Tie rent and move-in to functioning services. Test water supply and sewage through a street manhole, with cheaper aligned wet-room stacks and viable, more expensive offset routes. Teach through world ports, flow arrows, room states and a short action sequence, not instruction paragraphs or goal counters. Provide distinct creative and timed-development motivations. Keep this prototype separate from the existing construction save. An exploded dollhouse view may separate floors visually without moving their physical coordinates; real floor movement and townhouse-scale authoring require a later validated transaction design. The current demo's Escape menu may offer the separate Economy Lab.


## Block City construction-first revision — 25 October 2026

The latest playtest rejects exploded views, manual month advancement and Builder/Creative/Sprint choices as the game direction. Focus on the Construction Demo. Remove the Economy Lab entry from its Escape menu; keep that earlier experiment only as developer reference. Do not add those economy controls to construction. Any retained floor selector must place 1 at the bottom, then 2 above it and 3 above 2.

This supersedes the earlier default hall-cut behavior: halls stack above the room under the cursor without moving or replacing existing rooms. Shift explicitly requests a same-level hall cut. Doormats are ordinary world geometry, hidden by obstructing walls and floors, with no x-ray overlay. Stairs use neutral concrete walls with no windows, the lab's yellow step edges, and two mats at their lower entrance and upper exit. Preserve the liked toilet silhouette as a reference for later connected plumbing work, without introducing an unrequested placement tool now.


Block City stair passage correction: stacked stairs must have visible, physically clear passages. Use thin concrete treads and turning slabs, an open shaft through the next floor, and a clear intermediate landing between the exit below and entrance above. No solid concrete infill under flights or divider across the turning/transfer route. Keep the one-cell footprint, neutral walls and yellow step edges.


Block City debugging follow-up: show all buildable shape elements in an icon palette on the right, selectable for repeated placement. Replace generic corner placement errors such as Support with exact invalid-cell outlines, local visual cause markers and concise hover explanations. Keep room materials intact. Distinguish missing support from trying to stack on a cantilever, and identify overlaps, blocked access/stair exits, cables and boundary limits locally. This explicitly requested debug palette is an exception to the earlier hidden-tools constraint; no tutorial or persistent goal text is introduced.


Block City entrance-flexibility follow-up: provide the 1×3 and 2×3 room footprints with three entrance positions along a long side, rotating with the room. Corridors connect along every exposed cell edge, not just one authored door. Turn actual sidewalk and matching-room connections into proper doorway openings with neutral gray wall sections. Outline each reachable doorway green; keep an unused opening yellow even when another door in that room is connected. Unconnected hall edges keep the corner-pillar scaffold. Preserve the tight 3×3 construction challenge while making its remaining corridor strip usable.


Block City platform-testing follow-up: halls may attach at room sidewalls with visible diagonal brackets and support rooms stacked above them. Keep direct grounded beam anchors, one-cell plot overhang limits and no beam chains. Add a colored 1×2×1 room distinct from corridors. Show only one L in the palette; M mirrors it and R remains rotation. Remove legacy short-end doors from intact 1×3 rooms so their entrances are consistently on a long side. Make all shape thumbnails use identical unit-cube scale, with the staircase drawn inside one cube rather than as an enlarged glyph.


Block City Escape/menu revision: Escape deselects the held room and cancels wiring instead of opening the main menu. Put an icon-only X at the top right for Resume / New Game / Quit; do not use a hamburger icon or quit immediately on X. Escape may close an already open menu, leaving the piece deselected. Keep the X separate from the debug palette at every supported viewport size.


Block City single-entry/elevator revision: add a buildable 1×1×1 elevator shaft section with a floor door and an open core, connecting contiguous sections vertically. Each newly drawn ordinary room has exactly one randomly selected exterior entrance; long rooms keep the choice on a long side. Store that choice through preview, rotation, placement, undo and saving. Halls retain all meaningful connections, and stairs retain their lower/upper entries. Remove both L room variants from the palette and random supply for now, preserving placed saved rooms. No extra instructional UI.


Block City placement-plane revision: aiming at a roof chooses its construction level. Keep that level while shifting the room over empty or unsupported cells, even when lower floors are visible beneath the cursor. Show existing local support feedback without dropping or automatically relocating the room. Alt explicitly retargets another level; a new piece or deselection releases the plane. Rotate around the footprint center with stable grid rounding, preserve cursor offset after rotation, and keep keyboard nudges on the same floor. Retain hall sidewall supports and Shift cutting without adding persistent UI.


Block City elevator-door follow-up: each shaft storey has an explicit landing entrance with paired sliding doors and a connection mat, linked vertically like circulation through stairs. Show a complete elevator cabin parked at the bottom of each contiguous shaft, with open doors at that floor and closed doors above. Preserve open shaft cores, neutral walls, and existing green/yellow access feedback; do not add explanatory UI.


Block City ground-stick correction: the placement plane must not strand a fully detached room above bare ground. If no footprint cell touches support below and there is no valid supporting bracket, release the raised plane when the cursor points to visible, buildable ground and place the preview on that ground. Preserve the selected storey for partly supported footprints, valid side platforms and gaps over lower visible construction. Unsupported or obstructed positions remain invalid; do not relax structural rules.


Block City direct room editing: with no supply piece held, click a built room to select it for moving, then move the cursor, rotate with R and click to place it again. Use the existing selection outline only; add no action buttons or instruction panel. Escape cancels and restores the source room. Preserve exact carved geometry, doorway and color, keep supply unchanged, and make a committed move one undo transaction. Reject moves that overlap, strand other rooms or obstruct attached cables. Cable sockets retain their wiring action; room body/door clicks select the room.


Block City whole-room outline: construction and relocation selections follow the combined room volume. Merge projected cell silhouettes into the room’s overall screen contour. Remove cube divisions, interior creases and hidden back edges, while retaining visible concavities. Keep the shared 4-point stroke. Existing local invalid-cell diagnostics remain separate from the room selection.


Block City parent-room connections and route costs: an authored room doorway facing another colored room opens a reciprocal doorway in that wall and inherits the parent room’s color. Preserve neutral halls, stairs and elevators. Show a solid shared threshold and connection node. Keep one authored entrance per room; incoming child connections may create additional reciprocal openings. Calculate shortest paths through the cell graph from the oldest room’s valid ground-level main entrance. Start at distance zero, charge 1 per horizontal cube step, 1 per stair rise, and 2 for an entire elevator ride between any floors of a contiguous shaft. Show the selected room’s route and one numeric cost only; no explanatory panel or goal display.


Block City Backspace removal: Backspace removes the selected built room, including while it is being moved. Add no button or confirmation panel. Remove its attached/orphaned cable branches, keep unrelated construction and supply intact, and make the whole deletion reversible with Z. Preserve existing support rules: show affected unsupported cubes instead of deleting a room that would leave upper construction floating. Ignore Backspace without a built-room selection or while the menu is open.


Block City exposed-roof targeting correction: pointing into an open hall stacks the next piece directly above that hall. An exposed lower roof must immediately select its own level, even beside a taller tower; this supersedes the earlier rule that lower visible roofs could not change the placement plane. Keep the current level while shifting over empty gaps and ordinary sidewalls. Preserve centered rotation, keyboard nudging, side platforms on colored room walls, Shift cutting, and ground fallback. Add no UI.


Block City neighborhood and generation follow-up: extend pedestrian paving around surrounding blocks, and connect it with crosswalks at narrow-road intersections. Do not cross the wide main road; no dog is requested. Gray neighbors use the same window apertures, proportions and sills as playable rooms. Generate their varied shapes from actual connected room layouts with a street entrance, hall/stair circulation, direct support and no overhangs. Provide a developer tool with editable seed, footprint, height, shape and room-count conditions, validated reachability, JSON export and a separate preview; no additional game UI.


Block City manual floor selection: add two icon-only up/down buttons while holding a new or moved room, with Up above Down. Selecting a floor forces the placement plane and prevents roofs, ground or Alt from retargeting it. Fade rooms above that floor to 8% opacity and disable their shadows; keep the selected and lower floors solid. Preserve structural/collision checks, rotation and Shift cutting. Keep the chosen floor across ordinary placements and palette changes; deselecting/Escape, depth changes, undo or starting a new game restore automatic targeting. Keep controls bounded to buildable floors and hidden outside construction.


Block City stair model refinement: remove the isolated dark horizontal rear bar. When a stair cell has another occupied level directly above, extend neutral concrete pillars at all four corners to the full storey height, aligned with hall corner supports. Preserve the open flights and turning/transfer landings in every rotation and view mode.


Block City elevator suspension model: replace the four dark corner rails with a central vertical suspension cable and a second cable behind the cabin. Add one concrete-gray block counterweight at the upper end of each continuous shaft while its cabin rests at the bottom. Keep cable positions aligned to the bottom cabin even when landing doors rotate on other floors. Keep the one-cube footprint and floor access unchanged.


Block City facade hierarchy: preserve the one-cube storey dimensions but make ground-level exterior openings visually larger, with near-full-height glazing and wider, taller entrances in layered painted surrounds. Give the base smooth same-color plinth and shallow horizontal relief detailing, not stone blocks or a stone texture. Keep middle storeys restrained. The highest exposed room in each column gains slightly different window trim and a subtle cornice; recalculate after construction changes. Apply the same facade language to neutral neighbors. Keep circulation interiors, doorway connectivity, view modes and placement bounds intact.


Block City rooftop stair exit: in roofed view, finish an uncovered top stair with a small concrete access enclosure about half a tile wide, offset over the returning flight. Include a miniature framed door, raised threshold, solid cap and a low covered shoulder over the other half of the opening. Preserve turning/exit headroom. Roofless and low-wall views expose the stairs; adding an occupied level directly above removes the rooftop enclosure automatically. This is architectural detailing, not a new room or water simulation.


Block City cable-node deletion: with the held room put aside, clicking an existing cable socket selects it for wiring and marks its ring yellow. Backspace removes that socket connection and any downstream cable branches that depend on it, preserving rooms and independent connections. Z restores the entire branch in one step. Clear cable selection after deletion; ignore deletion for the pole, an absent selection or an open menu.


Block City stationary elevator rope correction: with the cabin parked at the bottom and counterweight raised, keep the central hoist rope extended and show only the short rear rope between the shaft top and counterweight top. Remove all rear rope geometry beneath the counterweight.


Block City elevator rooftop machinery and hall roofs: finish each exposed elevator shaft with a square concrete service housing, wider than the stair rooftop enclosure, with a framed service door and weather cap. Include the motor, horizontal cable drum and continuous rope routing; cutaway views expose the machinery. Remove the housing when another occupied cell is built directly above. Exposed hall cells gain neutral concrete slabs in roofed view; hide these slabs in both cutaway views and beneath occupied cells. Keep existing footprints and connections.


Block City continuous concrete roofs: adjacent ordinary rooms and halls at the same height share a neutral concrete roof finish with full-tile slabs and no cube gaps. Add a small raised concrete rim only along the outside boundary, including inset corners, never between neighboring occupied cells. Omit rims beneath upper rooms and hide both slabs and rims in cutaway views. Preserve room colors on the walls, footprints and placement behavior.


Block City wall-mounted power distribution: cap new pole connections at three heavy feeds. A pole-to-wall connection installs a local transformer; further connections install smaller fuse boxes with thinner exterior wires. Supply only the room containing each connected box rather than automatically spreading through touching rooms. Offer four wall attachment positions beside the windows, two high and two low. Route local wires along exposed wall edges, around convex and inset corners, with clips; allow clear hanging service spans across separate structures. Loose cables sway gently with fixed endpoints. Show thin interior feeds to service outlets without adding an appliance simulation. Click a box to continue wiring, drag it to relocate its connection and downstream references, Backspace to remove its branch, and Z to undo. Use small square targets and a three-feed visual beside the pole while wiring; add no text panel or toolbar. Preserve legacy saved wires, including grandfathered extra feeds, while preventing new feeds beyond the cap.


Block City version and performance readouts: show the demo version at bottom right beside the view control, and live FPS at top right beside the menu control. Keep both compact, anchored during window resizing and click-through. Update FPS twice per second. Maintain the demo-specific release number in scripts/block_city/demo_version.gd, starting at 0.1.0; bump it for subsequent demo changes so screenshots identify the build. These are requested diagnostic labels; goals and the bottom instruction panel remain hidden.


Block City editor-first hierarchy (v0.2.0): begin with an empty hand. Clicking built geometry selects its connected building, clicking again selects that floor, then any nested user group, then the individual room. Selecting never starts movement. Shift-click toggles individual rooms for multi-selection. Command-G (Ctrl-G on other keyboards) groups that selection; persist group ancestry on room records so nested units survive save/load, renumbering and undo. Groups spanning floors sit above their floor children; groups spanning disconnected buildings sit above their building children. Show contextual Move, Copy and Delete buttons at top left, with compact clickable hierarchy breadcrumbs below. No persistent instructions or goal panel.

Move and Copy explicitly pick up the selected room, floor, group or building; R rotates the entire unit, floor arrows choose its height, and click/Space commits atomically. Copy begins one selection-height above its source. Escape cancels previews. Copy retains individual room models, entrances, colors and independent nested groups, but does not duplicate utility feeds. Move preserves and reroutes attached cables. Validate all rooms, remaining supports, stairs, occupancy, bounds and cables before any edit commits. Delete acts on the complete selection and prunes dependent wiring, with local visual feedback if support prevents it. Every commit or grouping is one undo step. Keep supply placement available through the shape palette and hide the in-hand thumbnail outside placement.

Block City land purchases (v0.3.0): replace the roads immediately left and right of the starting lot with pedestrian paving, keeping the sidewalks, wide front road and other streets. Use the nine existing city blocks as a 3×3 grid of parcels, each with a 3×3 buildable footprint. The center parcel starts owned. Hovering an unowned footprint or its gray building reveals a compact plus icon and Purchase button with a plot outline. Purchase is free in this prototype, may cross a road, removes that parcel's gray building and reveals flat buildable land. Sidewalks and roads remain public and unbuildable at ground level. Persist ownership, migrate existing saves to central ownership, and undo purchases as one transaction. Placement, basements, room editing and entrance routing must work on each purchased parcel. Keep all other plots unchanged and show no permanent purchase panel.

Block City face-aware construction and utility brushes (v0.4.0): target the nearest visible logical tile face, distinguishing wall, roof, interior floor and owned ground. Cutaway roofs and manually faded upper floors do not capture the cursor. Provide three compact icon tools for electricity, pipes and vents; drag across surfaces to snap to tiles, interpolate skipped cells, turn shared-edge corners and join existing routes without targeting connection endpoints. Release commits one stroke, Escape cancels, Z undoes the complete stroke, and Backspace removes the hovered utility tile. Use gentle synthesized pentatonic placement notes. Keep networks separate and persist them. Electricity extends existing supplied-room power through the drawn network; amber joints indicate unsupplied electrical segments. Pipes and vents currently author routes only, without water or airflow simulation. Utilities move with supporting rooms where connections remain physically adjacent; removing supports prunes attached segments.

Block City construction responsiveness: commit physical occupancy, support and collision immediately. Avoid exhaustive future-placement enumeration on the input path. Retain unchanged neighborhood and room geometry, remove the input-blocking landing animation, and compute access, power, connection colors and future supply on an isolated background snapshot. Use precomputed cable polylines in the worker, never shared mutable routing caches. Discard stale revisions after subsequent construction; queue changed feedback meshes across frames. Keep two supply cards available while the valid future supply is calculated. Background jobs must not modify scene nodes or change newer player edits.

Block City held-room controls: only the held preview uses see-through materials; keep built geometry depth-tested. Retain room colors and show opaque door mats in front of preview walls: green connected, yellow awaiting access, red blocked placement or doorway. F cycles permitted entrance positions without rotating or reshaping the room (including held single-room moves/copies); halls retain their multiple entries. R remains rotation. Arrow keys move the held footprint on its current grid level; 1–9 select floors 1–9, and comma/less-than or period/greater-than step down/up, with no basement hotkeys. New stair/elevator sections inherit the direction of the matching section directly below; explicit rotation or entrance cycling overrides that alignment for the held piece.

Block City concrete and electrical lighting (v0.4.1): hide room-type colors throughout placed rooms, held previews and palette icons; all room roles share the neutral concrete finish. Preserve type/color IDs in saved construction. Use warm yellow emissive windows to indicate actual electrical supply. Roofless and low-wall views show small ceiling fixtures and soft warm light pools on powered floors, replacing the cyan floor-square indicator. Unpowered rooms stay unlit, and disconnecting/undoing electrical routes updates the lighting through the background analysis. Use lightweight emissive materials and bounded floor pools instead of per-room shadow-casting lights; keep status doormats and utility colors meaningful.

Block City sidewalk infill and floating ground (v0.5.0): allow free 3×3 purchases over pedestrian paving, using the same hover outline and + Purchase control as building lots. Additional parcels may overlap already owned ground so narrow sidewalk strips can be acquired; reject purchases with no new land. Keep the original nine parcel IDs and coordinates for saved games. Newly purchased paving supports normal room construction, and any gray neighbor touched by the purchase is demolished. Preserve player-built rooms. Retain the interior streets and prohibit buying them. Ground tiles are drawn once even when purchases overlap; public entrance access follows the remaining unowned paving.

Remove the one-tile outer road ring on all four edges. The remaining city is a bounded 17×19-tile floating block with no infinite ground plane. Show layered soil and bedrock, a front cross-section exposing concrete support piles, and a metro tunnel with rails and a stationary carriage. These are architectural scene details, not a transit simulation or new basement controls. Keep all details within the ground section and frame its bottom as well as the buildings; lower the starting camera slightly so the cutaway is visible. Existing basement cutaway behavior remains available.


Block City concrete hierarchy (v0.5.1): use three shared neutral concrete base shades: light walls (#c5c8c3), darker columns and foundation piles (#a5aaa4), and darkest floors, stair treads, landings and roof decks (#858b85). Apply the same floor finish to halls and elevator platforms. Preserve architectural trim, yellow stair edges, entrance status colors and powered lighting.


Block City purchase interaction (v0.5.2): offer land purchases only with an empty hand. Picking up a room, floor or building for placement, movement or copying immediately hides both the Purchase control and parcel outline; construction clicks must never purchase land. Restore purchase hover after deselecting.


Block City power equipment (v0.6.0): add a placeable half-height electricity pole to the palette, with a 1×1 footprint and three reserved height cells for its 2.25-unit mast. It has three terminals total: one incoming supply and two onward connections. A pole is equipment, never a walk-through room or structural support. Add a starter 1×1×1 transformer beside the initial lot, supplied by one fixed heavy cable from the tall pole, with three independently selectable output terminals. The fixed input consumes one of the tall pole’s three feeds. Click an output, then a small pole terminal or room wall socket; supplied poles relay power through their free terminals. Equipment connections save, move, delete and undo with their supporting pole; copies start unpowered. Keep existing saves and legacy feeds; migrate the starter transformer onto nearby clear paving if its default location is occupied. No additional text panel.


Block City compact elevator headhouse (v0.6.1): reduce the rooftop machinery enclosure to half its previous height (0.42 tiles above the shaft), with a narrower 0.70×0.84 roof footprint. Scale the service door and motor down and use a smaller circular cable drum. Keep the deck at the shaft top, guide the ropes into the smaller drum without moving the existing cabin or counterweight suspension, and preserve all roof/cutaway view behavior.


Block City movable transformer and parallel feeds (v0.6.2): clicking the transformer body selects it; use the existing Move action to pick it up. Move onto clear owned land, public paving or supported owned roofs, preserving its service input and every output cable; Escape cancels and Z undoes. Keep occupied cells and roads protected. A small pole may accept all three transformer outputs on its three terminals, with terminal order aligned to the crossarm and a shared parallel cable curve to avoid crossings. After connecting one feed, select the next free transformer output automatically. Room construction and movement no longer reject cable intersections or covered wall sockets; retain the electrical graph through placement, editing, save/load and undo.


Block City sibling selection (v0.7.1): retain shared selection ancestors when clicking a different floor in an already selected building. Switch directly to the clicked floor, keeping the building breadcrumb, then continue to its group or room on subsequent clicks. A genuinely different building starts at its building scope. Preserve Shift multi-selection, explicit Move/Copy, and group nesting. Building membership remains unchanged pending a separate decision about connections between buildings.


Block City persistent building ownership (v0.8.0): assign each room a saved building identity independent of pedestrian or utility connections. Connecting two buildings with a hall never merges them; building and floor selection follow ownership, with floors limited to their building. New construction inherits overlapping frame ownership when carving, then the structure directly above/below, then neighboring rooms; an active selected-building context resolves ambiguous neighbors. Detached starts create new identities. Hall-only structures retain one identity across storeys, and rooms extending their frame join it. Moves and cuts preserve ownership; floor copies join their destination structure, while whole-building copies receive new identities. Preserve nested user groups, cross-building physical access, wiring and undo. Infer legacy ownership in recorded room order without merging existing identities. Keep identity numbers internal and add no controls or labels. Replacing hall cells with room interiors is a possible future framing mechanic, not part of this identity change.


Block City editable hall-frame infill (v0.9.0): ordinary rooms may replace only covered hall cells, retaining uncovered fragments, building ownership, frame beams and support for all floors above. Cutaway hall-floor targeting fills that storey; roof targeting continues stacking. Explicit floor selection permits infill beneath existing upper floors. The editor Move and Copy actions use the same atomic replacement; Undo restores all frame pieces and utilities. Do not overwrite ordinary rooms, stairs or elevators, or combine two building identities inside one new room. Preserve cable endpoints and utility routes on retained surfaces; prune surfaces made internal by the new footprint. Keep inherited frame-bearing cells in saves and transform them with editor moves/copies.

Block City utility feedback (v0.9.0): empty universal pipes use neutral metal, round fittings and capped endpoints. Joined strokes form T junctions without duplicating geometry. Vent placement uses a quiet synthesized sheet-metal buckling/impact timbre cycling Do–Re–Mi–Fa–Sol–La–Si. No additional persistent UI. Fluid source equipment, automatic content coloring, trunk diameter changes and alternative access markings remain design proposals pending their interaction design; do not imply pressure or temperature simulation.


Main-game room construction milestone (30 October 2026): confirmed conversion is one demo cell = 2×2×2 m, while existing settlement coordinates remain metres. Bring shared hierarchical room editing into the settlement, with material hauling and labour constructing a two-storey hall frame, partial room infill, a 180° stair and an upstairs bed. Reuse the two-flight stair geometry and its turning landing; keep the upper shaft physically open and route citizens through actual door apertures. Plans reserve space but provide no walking floors until built. Retain physical frames during infill and building ownership through connections. Keep the compact palette and explicit editing actions, without bottom instructions or goal displays. Initial integration uses timber/plaster finishes and timber costs; completed structural relocation/demolition, utility simulation, furniture copying and sleeping needs remain deferred.


Original Pyramida color grading (30 October 2026): use [Page 1 / Colours](https://www.figma.com/design/YiwkIgayo25iH8SOpRaGyO/pyramida?node-id=110-122) of the user's Figma reference as the palette source. Preserve cream sand #FEF1CF, peach cast shadows #EABEA4, warm timber #7F4645 / #AF644B / #E08160, sandstone #EEBF8A, muted greens and blue accents #6CAACA. Room-editor shells use the main game's flat-color rendering so ambient lighting cannot turn them dark gray-green. Midday preserves authored swatches; dusk transitions through peach and night maps cream to the reference slate blue #6A758D without the former extra blue wash. Keep straight antialiased contours and the existing geometry and UI layout.


## Timber continuity from tree to building — 6 November 2026

Harvestable trunk sections, carried logs, stored logs and structural poles reuse the same stock geometry and brown bark material (#986A4B). Exposed cut wood and sawn boards share #D1A775. These natural timber defaults replace the orange default timber swatches; explicitly selected Blueprint wood accents remain available. Stone, plaster, cloth and terracotta retain their own materials.

Keep the confirmed stock dimensions: 0.90 m of bark, 0.23 m uniform diameter, 0.918 m total including end-grain discs; a board is 0.70 × 0.055 × 0.22 m. Living, dead and palm trees each contain three rigid harvestable log sections. Vary lean at section joints, branches and crowns, rather than stretching, bending or tapering the usable stock. Height variation affects crown branches. Seedling growth remains visual until maturity.

Each cut removes one existing visible section from the top; the same mesh resources and materials appear in the citizen's hands and storage. Harvesting still delivers three resource units and removes the exhausted tree. Construction repeats full stock with overlapping joints; deliberate shorter cuts in the Blueprint editor remain supported. Cargo and piles keep full-size logs and boards. The three-board cargo bundle instances one shared board mesh. Keep the current inventory and save formats, without adding resource species or persistent UI.

## Moving timber, common markers and dedicated storage — 6 November 2026

The actual detached log section travels into the citizen's hands and then into a storage slot. Retain its scene object, mesh, material and full stock dimensions across both transfers. Strip crown/branches at cutting, and leave remaining trunk sections untouched. Pause freezes transfers; simultaneous cutters retain distinct pieces. Simulation inventory changes once at cutting/delivery, while animation is presentation only. Saves record the authoritative inventory and resume with logs in their saved hands or store, without replaying transfers. The existing twelve-log pile display limit remains; overflow pieces arrive into the pile and are hidden within its aggregate stock.

Use one authored wooden stake (`data/settlement/stick.tscn`) for construction corners and field-edge markers, with the same brown timber palette. Placement and rotation can vary; do not stretch the stake. Keep stakes entirely outside crops and remove shared internal field borders. The user's manually authored house and log shed are the visual standards. Preserve their shapes and constituent pieces. A completed upper storey hides the lower roof, including the log shed's authored canopy; exposed roofs return after removing the upper storey. More building-face and edge variation remains a later design task.

Remove the general stone-edged stockpile from gameplay construction. Keep old stored supplies recoverable and save-compatible, rendered as loose supplies without the retired border stones; they accept no new deliveries. Start with one house, not separate resource piles. Household storage accepts food, logs, hay and water, with twelve food spaces, twelve log spaces, four hay spaces and four water spaces. Reserving these spaces prevents fuel/hay from displacing food. Log sheds and hay barns remain dedicated stores. Sawmills, masonry shops and mills provide their own relevant input/output buffers, each reserving half its inventory capacity for output. Mineral storage accepts raw stone and cut blocks; pottery uses its existing dedicated racks/warehouses. Old workshops gain empty output buffers on loading without altering existing supplies. Do not introduce a replacement universal stockpile.

## Physical timber placement — 6 November 2026

Continue the same scene-object transfer from dedicated storage into construction. A builder lifts the actual deposited log, carries it, then rotates and places it into an existing full-stock position in the authored timber frame. Replace that position's original geometry so there is no duplicate pole. Preserve the tree section's bark/end meshes, material and rigid dimensions; preserve the house and log shed's authored shape. Installed pieces survive the transition from plan to completed building and appearance rebuilds. Multiple builders use distinct pieces and positions; accelerated simulation still animates pickup before placement. Pause freezes transfers. Keep construction recipes, labour and inventory authoritative and unchanged; saving records the material's current logical ownership without replaying an animation on load. This applies to authored full-stock timber members; shortened Blueprint pieces and the separate room-editor shell keep their existing construction visuals. Add no UI.

## Physical timber recovery — 6 November 2026

Dismantling reverses timber placement. Keep the authored building visible during dismantling work, then leave recoverable logs at their frame positions until a citizen lifts them out. Preserve installed scene objects through removal, carrying, delivery to a log shed and subsequent construction. For pre-existing authored models, detach their individual timber meshes or separate a rigid member from its shared batch without changing its dimensions or material. Recover only the recorded construction recipe; stored contents are additional goods, never extra structural refunds. Full storage leaves salvage available at the site. Multiple haulers take distinct pieces, and pause freezes extraction. Save/load reconstructs only unhauled pieces at their original frame positions and retains carried inventory without replaying delivery. Keep the existing dismantling labour, support checks, dedicated storage rules and clean UI.


## Reviewed Tier 1 roster and gathering — 6 November 2026

Use `Pyramida_Game_Balance_Reviewed.numbers`, transcribed in `data/settlement/reviewed_balance.json`. One fixed purpose and one operator per workplace; power remains deferred. Include Mine for Ore; defer School, general Warehouse, metals processing and generators. Quarry is free and buffers four Stone. Claypit requires a Puddle. Its 2 Log cost and Mine's 4 Log cost are provisional choices where sheet cells are blank. Harvestable natural grass supplies the first Field's Hay.

Dedicated stores pair Log/Plank, Hay/Flour, Stone/Slab and Clay/Brick. House accepts Food, Vases and Water; legacy Log/Hay remains usable. A Vase holds one Water and a House accepts three Vases. Well capacities at depths 2/4/8 m are 3/6/9 on a Puddle and 1/3/6 away. A shallow Well within 2 m holds two. The user confirmed deeper off-Puddle Wells use the anywhere capacities, three and six. Deepening creates empty capacity; Wells do not evaporate.

Missing or full storage must not stop gathering: leave recoverable goods on the floor. A producer can deliver cargo to construction without becoming a Builder, then resume its occupation. Delivery stages material; a Builder installs it. Preserve loose goods, staged goods and reservations through save/load and cancellation. Repurpose this project's models using the authored House and Log Shed as visual standards, with metre-grid dimensions and shared full-stock timber. Keep the existing compact UI.


## Well placement and Mill silhouette — 6 November 2026

Show a single capacity number above the Well placement preview: 3 on a Puddle, 2 within the nearby distance ring, and 1 farther away. Deepening previews the resulting capacity. Hide the number on invalid placement, over menus and when another tool is selected. Well construction inspection also shows expected Water capacity; finished Wells retain their current/capacity readout.

Restore the former windmill's tower and moving sails for the Tier 1 Mill, replacing the recent covered hand-mill model. Keep Hay → Flour and its construction costs. Reserve 6 m of height for the original tall silhouette; its base footprint remains 3 X 3. Keep the derived model editable in Blueprints.


### Sparse interactive grass (2026-11-06)

- Grass follows the reference screenshots: narrow pointed sage-green blades in loose, irregular clumps with bare ground between them.
- Remove the decorative grass blanket in both landscapes. The natural blade style belongs only to selectable, harvestable Grass resources; do not add cosmetic grass elsewhere.
- Keep the three existing opening Grass sources and their Hay yield/regrowth rules. Use individual triangle leaves with independently varied width, height, lean, colour, and root position. Vary patch outlines deterministically by world seed and position; never repeat a three-leaf/claw stamp.
- Grass stock is shown by whole leaves: 3/3 = 15, 2/3 = 10, 1/3 = 5, 0/3 = no visible leaves or picking target. Harvesting never shortens the remaining leaves. The existing regrowth timer restores the full patch when ready; keep saved stock and growth progress.
- All leaves in a patch sway together. Sample one broad, smoothly changing Perlin wind field at the patch centre so direction and phase vary gently across the map, without independent leaf flutter (7 November 2026).
- Double Grass's visual scale, including blade height, width and patch spread. Keep roots grounded on the terrain beneath each leaf and enlarge selection bounds accordingly. Preserve the fifteen-leaf full patch, harvest yield, regrowth, colours and shared wind behaviour (7 November 2026).
- This replaces the older decorative-grass coverage direction. Cultivated Fields remain a separate crop.


### Finite natural grass — 7 November 2026

Edge placement follow-up, 11 November 2026: each natural grass patch stays on its
own terrain level. Leaves may follow neighbouring soil on that level, but must
not snap up or down to another terrace. At an edge, extend the owning surface
under the leaves; a cliff wall may partially hide the patch.

Natural Grass supplies its existing three Hay bundles once. After the final harvest, the spot stays empty permanently, including after rain, save/load and streaming; stop the former regrowth timer, including pending regrowth in older saves. Keep the exhausted patch as hidden saved harvest history, without a picking target or occupied construction footprint. Legacy grass sowing orders may complete one initial growth cycle; harvested patches never refill. This supersedes the natural-grass regrowth rules above. Cultivated Hay fields retain their watering and quarter-regrowth cycle.

### Golden grass fields without horizontal edging — 7 November 2026

Replace the Hay field's repeating three-stalk stamps with taller individual pointed blades using the same grass geometry and shared wind style as natural Grass, in warm golden yellow. Use dense, irregular seeded coverage with varied blade height, width, lean and colour; avoid repeating rows and clump patterns. Mature blades are about 0.55–0.95 m tall. Batch the blades per harvest quarter, retain terrain-grounded roots, and preserve quarter harvesting, growth, watering and saved state. Disable shadow casting on every field part, including newly generated terrain-fitted crop meshes, soil and upright markers. Remove all horizontal wooden edging; retain the existing vertical pegs and their shared-edge hiding. Apply the new appearance to previews and authored assets as well as gameplay. This supersedes the older flat crop canopy and wooden perimeter planks.

## Barn roof and modular slopes — 7 November 2026

Barn retains its 1 X 2 X 1 m storage body, Hay/Flour capacity and construction cost. Replace the Shed-like roof with the user’s four-sided pointed reference: the peak meets the adjoining House wall, with sloping hips over an open timber frame. Two editable oblique corner pieces form the roof, rising another metre above the body. House remains 2 X 2 X 2; placing Barn’s long side beside it forms a 2 X 3 footprint. Rotate Barn to face the wall; placement snaps to the flush half-metre anchor, and collision, ground support and saved placement retain that offset. Existing free-standing Barn positions remain unchanged.

Blueprints exposes Roof corner (1 X 1 X 1 oblique pyramid, apex above a corner), Roof wedge (1 X 1 X 1), Roof long wedge (1 X 2 X 1, high edge along the 2 m side), and Roof fat wedge (1 X 2 footprint, actual rise 0.5 m). Dimensions here are width X depth X height. All have smooth slopes, can rotate and stack as separate pieces, and survive Blueprint save/load. These are authoring parts, not additional construction jobs or building recipes.


## Depot frame and physical storage — 7 November 2026

Use the user’s depot.svg and isometric frame reference for Depot: an open timber frame on a square base, 3 X 3 X 2 m. Keep the reviewed cost (3 Plank, 3 Stone) and 18-item shared capacity for Stone and Slab. Arrange cargo in two layers of nine positions, each a 3 X 3 grid. The latest reference removes the middle shelf, shelf bearers and middle rails. Items stack directly on the actual height of the item below in each of the nine columns. If a lower item is collected, the upper one settles onto the raised pad; inventory quantities and assigned columns remain unchanged. The base is a solid 0.16 m raised pad with the same sand colour as the surrounding ground, peach-coloured exposed edges, and real cast/received shadows; it is not wooden decking. Each delivery fills the first empty position; pickups remove the last occupied position for that resource. Other columns stay in place, including across save/load and relocation; vertical positions follow the remaining supporting items. Existing inventory quantities remain authoritative; older saves without positions receive them on load. Legacy excess stock is preserved rather than discarded.

Depot posts, upper rails and the sand pad are individually named editable components. Use F2 → Buildings → Depot → Edit, select a part, then move or rotate with the existing Blueprint controls; stock timber keeps its rigid dimensions; Apply to game saves the appearance. Storage positions and the 18-item capacity remain gameplay rules, independent of visual frame edits. No building recipe selector or persistent instructions are added.


### Male silhouette and walking study — 7 November 2026

Use the user's six standing/walking screenshots as the current male reference: round head with a clearly exposed narrow neck; shoulders slope into short outstretched arms; a compact broad torso above wide shorts with two distinct leg openings; short exposed lower legs and simple feet. Preserve the silhouette without adding facial detail. The walking reference has a pronounced bent-knee lift, a tucked trailing lower leg, and a soft planted step. Review one male study from front, side, three-quarter and rear before extending the redesign to the citizen family. The isolated `reference_man.tscn` study is not yet the live population asset. Ragdoll physics are not required for this authored walk.


### Low-poly male and separate clothing — 7 November 2026

The male reference study uses low-poly geometry with flat normals. Shorts must be a separate removable mesh, with their own waistband and hems, rigged to the same skeleton. Keep the complete featureless body editable; when dressed, mask the covered body faces to prevent hidden skin breaking through clothing. Check the exposed body against the garment throughout the high-knee walk. This supersedes the body-material-only clothing approach for this study; the live citizen family still awaits silhouette review.


### Slim brick torso and simple limbs — 7 November 2026

For the male study, replace the bulging belly/chest with a slim, shallow torso: approximately half the previous depth, straight vertical sides, broad flat shoulders, and small bevels at the corners. Use simple rounded sausage arms. Legs end in rounded bean-like caps with no separate feet, heels or toes, including during the raised-knee pose. Keep the low-poly construction and independently removable shorts. This supersedes the earlier broad-belly interpretation of the male reference.


## Adjacent building connections — 7 November 2026

Join adjacent matching buildings first; defer editable width controls. Assemble wider structures from repeated, rigid Log and Plank components. Keep low-poly geometry, solid colours, no textures, the existing day/night colour grading and slightly sharper shared sun shadows. Depot’s source frame now uses the common timber stock.

Completed Houses connect on the same floor when a doorway faces the neighbouring room’s wall. Connected rooms open their common walls and share a timber portal; wall-only contact leaves separate Houses. This supersedes the earlier instruction to retain walls between joined Houses. Default Depot, Shed, Barn and Brickyard modules share posts and beams at full-edge connections. Shed and Barn need matching rotation; corners alone and different floors do not connect. Removing a neighbour restores the exposed frame or wall. Each storage module retains its own capacity, cargo positions and construction cost. Roof forms remain those of their individual modules. Manually saved storage Blueprint appearances are preserved and excluded from automatic frame replacement for now.


### Grounded normal walk — 7 November 2026

Reanimate the approved male study with ordinary short steps, replacing the parade-like knee lift. Use a stance phase tied to forward travel so the support leg does not slide, a low swing arc and continuous ground contact. Coordinate opposite arm swings with small spring-driven shoulder/torso twists and head follow-through. Ground the rounded leg ends from their actual vertices; avoid whole-body floating or large vertical bounce. Keep the flat low-poly body, simple rounded limbs and separate shorts. This is still the isolated male study, pending population integration.

## Shared House roofs — 7 November 2026

A door-to-wall connection forms wings of one building, rather than merging roofs of unrelated neighbouring Houses. Preserve each wing’s ridge direction. A perpendicular wing extends its ridge through the connecting wall to the main ridge, creating one continuous T- or L-shaped roof. Join the intersecting slopes with diagonal concave valleys; never drop the branch ridge to the eaves at the connection. Keep gable ends and fascia only on the outer boundary, without internal vertical roof faces or doubled caps. Use the shared unit wedges and corner slopes, with inverse corner surfaces at concave intersections, plus rigid Plank ridge trim. Do not choose roof direction from the longer side of the combined footprint. Keep the clay palette and simple shadows. This replaces the earlier parallel-roof demonstration as the reference for connected Houses.

Generate roof sections from completed, exposed room tiles so upper floors hide lower sections. Connections work independently of individual door rotations, rebuild after removal and reconstruct from saved room positions. Hide authored roof pieces, including Blueprint assemblies, only while joined; restore them when a House stands alone. Keep authored appearance files, construction costs and room capacities unchanged. No roof configuration UI is added.


### Relaxed arms and fuller side profile — 7 November 2026

Bring the male study's arms down close to the ribs in both standing and walking. Use a slightly stronger forward swing, a smaller back swing, and delayed, smoothly bending elbows so the hands follow the shoulders naturally. Retain enough shoulder/arm clearance to avoid the separate waistband. Increase torso depth from 0.15 m to 0.216 m, keeping the straight front silhouette and bevelled brick form; fit the independent shorts to that depth. Keep the same polygon count, grounded leg motion and subtle torso/head response.


### Softer shoulders, bending elbows and short wrap — 7 November 2026

Soften the male study's brick silhouette with wider corner bevels and a rounded shoulder transition, preserving its compact depth and low-poly construction. Bend each forearm around the actual diagonal elbow hinge; blend the skin across the joint and let flexion follow the shoulder with a slight delay. Keep the arms close to the sides. Replace the long shorts silhouette with a shorter dhoti-inspired wrap, high thigh hems and a simple overlapping diagonal front fold. Clothing remains independently removable with a complete editable body underneath. The short hems follow the upper thighs rather than the knees. Retain grounded walking, the existing eleven-bone rig and fewer than 1,000 total triangles. This remains the isolated male study.


### Narrower male study — 7 November 2026

Reduce the male study's torso, hip and wrap width by 12%, moving the shoulders and arms inward to match. Keep the round head, arm thickness, torso depth, rounded corners, short wrap and current elbow/grounded walking motion. Use the same mesh topology and skeleton.


### Short neck and clearer step bounce — 7 November 2026

Shorten the male study's neck by lowering the head and neck tip 0.028 m, retaining its round head size. Emphasise each walking step with a gentle downward settle at landing and upward lift over the support leg: the torso moves vertically through the spine, and the head follows with a smaller delayed rise/fall. Keep foot targets grounded and leave the root height tied to the leg ends. Stop the bob when standing. Preserve the narrower body, rounded shoulders, elbow bends and separate short wrap.


### Woman and child studies — 7 November 2026

Extend the approved male shape and motion into two isolated reference studies. The woman follows the supplied screenshots with dark shoulder-length hair, a coral diagonal hairband, a coral top with open underarms, and a separate short skirt. Keep the featureless round head, short neck, rounded low-poly body, articulated capsule arms and grounded step bounce. The child has short dark hair, plain yellow shorts, 70% adult scale and a slightly larger head relative to the body, with a quicker 0.72-second stride. Each complete character remains below 1,000 triangles on the same eleven-bone rig. Clothing and hair are separate meshes; keep complete editable bodies beneath masked clothing. These scenes extend the review studies and do not replace the live population assets yet.


### Woman: no headband, solid clothing interiors — 7 November 2026

Remove the woman's coral headband. Keep her dark hair unchanged. Close the top's open edges against the body with coral rims and render the skirt's inner faces in the same coral colour, preventing pale background slivers from showing through the clothing during walking. Preserve the existing outfit silhouette and motion.

## Shared House posts and construction cost — 7 November 2026

A connected House group owns one post at each unique corner: two rooms use six posts; the four-room T uses ten. Replace duplicate authored corner posts and per-doorway post pairs with shared rigid Log members. Keep standalone authored frames intact. At three-way corners seat the post in the notch, close the plaster-to-round-post gaps with small wall-end blocks, and keep doorway floor strips inside the walls. These fixes remove the exposed dark interior strips without hiding shadows globally.

The four posts share the existing House Log budget. Charge only the proportion needed for new corners, rounded up to whole Logs; keep Hay unchanged. With the reviewed 2 Log + 2 Hay recipe, reusing two existing posts costs 1 Log + 2 Hay. Count completed, aligned Houses in a door-connected group; separate neighbours, other floors and buildings being moved do not provide a discount. Untouched queued sites can receive the discount after their supporting neighbour completes; do not change prices once material is reserved, delivered or installed. Protect the reused completed supports until the dependent site finishes or is cancelled, using the existing support restriction. Cancellation releases that dependency. Record the actual paid recipe for saves, moves and dismantling; never refund duplicate shared timber. Do not retroactively refund existing buildings. Existing plan material readouts display the reduced amount; add no UI.


### Approved family in the live game — 7 November 2026

Use the reviewed man, woman and child models for live citizens, including existing settlements. Adult appearance IDs 0/2 use the man; 1/3 use the woman. Childhood selects the smaller child model independently of the saved adult appearance, restoring the adult model when growth completes. Keep saved appearance/colour fields and simulation rules intact. The default household uses orange, coral and yellow clothing; retain the other saved colour slots. Preserve the woman's dark hair without a headband and coral clothing interiors.

Live locomotion shares the approved grounded gait, elbow hinges and torso/head bounce. Blend to standing and freeze all spring motion when paused. Limit visible cadence to 1.5 times the reference rate at compressed world travel speeds; this keeps the motion readable but does not provide exact world-space foot locking above that rate. Keep movement speed and gameplay timing unchanged. Carrying and building gestures use the new hinges, with cargo positioned from the skinned hands. Picking and occlusion include each independent clothing/hair mesh. Future action-animation refinements can be reviewed in the game.

## Procedural roof planes and soft building shadows — 7 November 2026

Generate Home roofs from thin triangle planes, including standalone Houses. Replace the fixed authored roof in the live game without changing its saved Blueprint source. Keep the authored roof’s ridge-to-eave plank pattern: approximately three strips per metre, alternating under/over laps, small angular deviations, modest colour differences and uneven exposed ends. Ridge caps are thin planes too; omit solid roof sides, undersides and gable-end roof blocks. Use overlapping coverage, preserve T/L intersections, and suppress overhang into covered upper-floor cells. Appearance is deterministic from world seed, floor and roof coordinates: reconstruct on topology changes and save/load, but do not reshuffle or regenerate every frame. This supersedes restoration of the authored standalone roof and the rigid solid ridge-cap detail above. Walls, shared posts and construction costs remain unchanged.

Buildings receive real shadows from other buildings, their roofs and shared frames while retaining the flat painted palette. Use shadow-only painted materials rather than adding glossy or textured shading. Fade their shadow contribution with the existing daylight cycle and preserve the world colour grading. Ground and building shadows use a filtered 4096 directional shadow map, a wider blur and a small angular sun size for softer edges. This supersedes the earlier sharper-sun setting. Keep transparent previews, emissive pieces and ungraded vegetation on their existing material paths.

## Authored roof components and timber clearance — 7 November 2026

Reuse Home's existing solid `Roof/Cap2` rectangular panel and Shed's beveled `Canopy/RoofCourse0`, rather than new flat component assets. These are the pieces used in the user's saved Blueprints; they are distinct from the small inventory Plank. Arrange physical copies ridge-to-eave with stable, modest length/angle/colour variation and alternating laps. Cut copies at shared roof valleys and boundaries, retaining their thickness and closing cut edges. Home keeps two slopes over its 2 X 2 footprint with a 1 m rise; Shed keeps one slope over 1 X 2 with a 1 m rise and frame clearance. Retain shared T/L roof topology and rigid Plank ridge trim. Preserve the user's saved authoring files. This supersedes the flat-plane roof implementation above.

Logs must remain underneath the physical roof. Seat obstructing rigid pieces lower, overlapping the upper stock where needed; do not stretch Logs or let their ends poke through the covering. Refit when connected geometry changes and retain stable placement during inventory updates. Backlit interiors retain an even ambient shade; only sun-facing surfaces receive direct sunlight and filtered cast shadows. Keep soft ground shadows and shadows from neighbouring buildings. Use filtered shadows with angular contact-hardening disabled: the latter produced grainy samples on small beam surfaces.

Buildings visibly use Log frames, worked Plank parts and pale mud/hay wall infill. Construction recipes use at most two material types; tier prices are deliberate balancing values, not a charge for every visible part. Keep the reviewed costs, including the two-material House recipe and free Quarry; add no third wall ingredient or new UI.

## Open Stair and connected Supports — 7 November 2026

Replace the solid Stair blocks with five individual stock Plank steps on two diagonal Log rails, with upright Log supports at the high end. Keep its 1 X 1 X 1 metre footprint and rise, existing direction mapping, navigation link and construction price. Remove the solid base and riser filling. The user confirmed that “filled in” means completing the Log frame, not adding walls: a completed Support directly above Stair adds the missing upright Logs and perimeter bearing beams while leaving the steps open and omitting a deck over Stair itself. Removing the upper Support restores the lighter frame.

Support remains a 1 X 1 X 1 module with a stock Plank deck and Log frame. Adjacent modules create longer structures, including a 1 X 2 group joined to another module to form 1 X 3. Keep one post per exposed shared corner; omit the beam across an internal module boundary and omit fully internal posts. Rebuild exposed boundaries when a module is removed, including rotated layouts. Preserve individual module costs, placements and saved identities; no new width controls or building type are introduced.

Stair can structurally carry the Support directly above its actual one-metre cell without adding an invisible walkable cap. Stack placement snaps by one metre, builders can work from the accessible level below, and loaded supporting structures remain protected from removal. Planned metre-sized Supports provide only their exact footprint, not a larger room-sized platform. Source scenes remain editable in Blueprints; completed runtime frames are reconstructed from their neighbours.

### Bench-like Support joins and spaced planks — 7 November 2026

Remove the intermediate upright posts along straight shared boundaries, not just the duplicate beams. A rectangular 1 X 2 or 1 X 3 Support group has four legs at its outer ends; retain posts at concave turns of an L-shaped group. Restore exposed corner posts when a neighbour is removed. This supersedes retaining a post at every exposed module junction above. Keep the existing removal protection, costs and structural footprints.

The top uses visibly separated stock Planks, with modest individual yaw, tiny tilt and staggered ends. Keep the timber dimensions rigid. Use three 22 cm rows spaced 34 cm apart per metre module, so the gaps remain readable from the game camera. Seed the variation by world and cell; inventory changes do not move the planks. Apply the same top treatment to the Support source scene used in Blueprints. Navigation continues to treat the bench top as its existing logical support surface.

### Open stacked Support decks and stair headroom — 7 November 2026

When a completed Support or Stair sits directly above a Support, omit the lower Support's plank deck and its intermediate horizontal beams. Keep its upright frame and structural support. Two stacked Supports leave a walk-through opening beneath the top deck. A Stair / Support / Stair column with both flights facing the same direction has no deck across the middle, so citizens can pass through the lower flight; omit that flight's crossbars at its entrance and exit while retaining its side bearings. Keep the one-metre modules and each flight's separate, real lower and upper landings. Do not infer a connection between floors merely from a vertical stack.

Use the same completed-building rule for visible decks and walking surfaces. Plans alone do not remove a floor or open a passage. Restore the deck when its upper module is removed, and protect citizens using a floor or passage during construction and removal. Preserve individual module identities, costs, rotations, saved layouts and existing protection for loaded structures. Apply the geometry in Arrange as well as gameplay, without additional UI.

### Taller Mill with a plank propeller — 7 November 2026

The current reviewed Mill occupies 3 X 3 X 5 metres, including the entire rotating propeller sweep. Raise the tower itself and give the rotor a maximum radius of 1.5 m; position its hub so the highest swept tip reaches exactly 5 m. Replace the oversized rotor, its Log frames and linen panels with four open, slatted blades made only from thin sawn Plank pieces. Each cut fits within the existing 70 X 22 X 5.5 cm Plank stock; use narrow plank spines, outer rails, slats and a compact wooden hub. Keep the tower's Log structure and millstones, animation, Hay-to-Flour recipe and 4 Plank + 4 Stone cost. Seat the gearbox beneath the pitched roof so it does not protrude through the covering. Update selection dimensions and the roof socket to the five-metre height. This revises the reviewed Mill; the legacy three-tier windmill remains a separate saved building type.

### Larger white Mill blades — 7 November 2026

Broaden the propeller's blade faces from 38 to 60 cm and use overlapping white-painted plank slats, retaining the thin wooden frame. This replaces the open bare-wood slats. Keep the approved 3 X 3 X 5 envelope and full rotation clearance; the larger blade area provides a stronger white silhouette without widening the reserved footprint. Preserve the white paint through asset palette preparation and runtime shadow materials.

### Double-size white fan — 7 November 2026

Double each Mill blade's length and width in the rotor plane, not just its filled area. Retain white plank faces, the approved tower/axle height, and the original thin stock thickness. Assemble more small plank cuts to make the larger blades; do not scale the entire Mill or stretch the stock. The complete fan sweep is now about 6 m across and reaches about 6.5 m above ground. Reserve 6 X 3 X 7 grid clearance and update the selection/roof socket accordingly. This supersedes the 3 X 3 X 5 limit for the reviewed Mill. Keep its production, animation and construction price unchanged.

### Narrow Mill blades and base footprint — 7 November 2026

Use only the current Mill's 3 X 3 metre base footprint for horizontal placement checks, without reserving extra space for the rotating blades. Halve each blade's short side while retaining its current length, white plank faces and stock thickness. Keep the tower, axle height, seven-metre vertical reservation, animation, recipe and construction price unchanged. This supersedes the six-metre-wide placement reservation and doubled blade width above.

### Plank Barn and enclosed ovens — 7 November 2026

Keep Barn's approved pointed roof silhouette, but replace its large flat triangle panels with overlapping pieces of the original Shed roof plank. Seed small variations by world and placement. Bakery and Kiln ovens sit inside 2 X 3 X 2 metre plaster-and-log rooms, with doors and windows. Bakery uses a bundled Hay roof; Kiln uses original Home roof planks. Chimneys pass through their roofs. Keep recipes and costs unchanged.

### Well stages and hover cutaway — 7 November 2026

Well depths are 2, 4 and 6 metres; this supersedes the earlier 8-metre third stage. Stage one is a ground opening with a low stone rim. Stage two has roughly half-metre stone walls and no canopy or uprights. Stage three retains the full roofed Well. Placing another Well on the same cell deepens it, up to three stages. Preserve water and approved Puddle-distance capacities; deepening does not grant free water.

Only while hovering a completed Well, display its underground cylinder through the terrain, with metre rings and a blue water volume proportional to actual stored water. Hide the cutaway when leaving the Well, entering placement/editor mode or opening a menu. The cutaway is visual, adds no collider and does not excavate terrain. Existing concise placement capacity numbers remain unchanged.

### Flat stone roads and shaded Masonry — 7 November 2026

Road follow-up: the user rejected the tiny flat polygon paving because it read as a texture. Use a few shallow 3D pieces per metre tile, derived directly from the existing quarried Stone mesh and sandstone palette. Preserve its chipped corners and broad low-poly faces, with subtle sandy colour variation. The user rejected the evenly paired placement: pack mixed large and smaller stones at freely varied angles and positions, with irregular sand gaps and slight tilt. Sink 50–70% of each stone into the sand, leaving only a shallow top and edge exposed. Use a stable world/cell seed; keep whole blocks separated and inside their tile, and batch them into one mesh with real shadows. No textures or separate stone physics. This supersedes the flat tessellation. Keep Road costs and route behaviour unchanged.

Masonry remains a 3 X 3 workplace for Stone → Slab. Replace its roofed workshop with an open Depot-like structure: a small raised sand-coloured central pad and stone workbench, four stock Log uprights forming two pi-shaped frames, and an off-white cloth canopy with a shallow sag. Leave the surrounding ground open. Keep its crafting action, buffers and construction costs unchanged.


### Two-hand log grip and connected arm roots — 7 November 2026

Carried logs use two explicit grip points underneath the rigid timber. Solve both upper arms and forearms toward those points; both hands sit below the underside and support the weight while walking, turning and the torso bobs. This replaces the rejected overhand grip. Carry the timber across the chest/waist and account for its authored 0.12 m mesh-centre offset. The log socket follows the torso's orientation as well as position. Preserve timber dimensions and the existing pickup/deposit transfers; other cargo retains its existing carrying gestures.

Keep the arm roots buried in and bound to the torso, blending their weights into the shoulder rather than letting arm rotation pull the caps away from the body. Fill out the elbow bend with the existing rings. Apply this to man, woman and child without increasing polygon or bone counts. Clothing remains separate and must clear exposed skin through walking, carrying and building poses.

### Claypit as a bordered puddle — 7 November 2026

Replace the tall mining frame and rectangular floor with a shallow, irregular puddle basin. Use a low faceted clay bank, a darker wet inner slope, scattered sandstone edging, two existing Log pieces along the rear bank and a few visible clay lumps. Keep the front bank low and open for work. Solid colours, low-poly geometry and shadows only; no textures. Preserve the 3 X 3 footprint, construction cost, Clay extraction and Puddle-only placement rule.

The basin displays water from the underlying Puddle inventory, shrinking and lowering as water is removed or evaporates and returning with rain. Hide the duplicate natural Puddle mesh/picking while Claypit occupies it; restore that presentation when Claypit is removed. Preserve the underlying water inventory and all hydrology rules. The shallow model uses a low picking volume rather than the former tall invisible frame.

### Building arrangement sandbox — 7 November 2026

Provide a visual workspace for arranging the current building models together, accessible through Blueprints → Arrange and the standalone BuildingLayoutSandbox scene. Use the game's orthographic camera angle with Iso reset, orbit, pan, zoom and an optional nearest-neighbour Pixel rendering mode. Keep the toolbar and library sharp in Pixel mode. Show only current building families and the three Well stages; preserve older sandbox files separately.

Double-click a library building to add it, drag to move it, or drag onto another building to stack at its logical top. Shift-drag retains height. Support rotation, duplication, delete, undo/redo, coordinate adjustment, optional grid/labels and an undoable empty workspace. Reuse current procedural roof and frame joining for the arrangement, including hiding covered House roofs. Save arrangements and viewing mode independently of settlement saves and asset Blueprints. No construction costs, workers or simulation run in this workspace.

### Material colours and three House tiers — 7 November 2026

Claypit is a shallow natural excavation, not a bathtub. Its water is opaque muddy clay-brown. Keep the irregular low bank and visible stock materials. Colours identify materials: golden Hay, brown Planks, reddish fired Clay. Barn, Shed and Kiln plank roofs use wood colours.

Keep each material's base colour consistent across carried resources, staged stock and completed structures. Rope bridges reuse the existing Tree Plank swatch from `timber_palette.gd` for deck boards, anchor posts and rooftop landing decks; their recipe contains Planks and Rope, so the posts must not suggest a different Log material. Bridge ropes and carried Rope coils share one fibre colour. Apply the normal painted-material shading and day/night grading to these procedural models, avoiding unrelated lighting that makes Planks look olive or metallic. Do not invent a separate palette for each building.

Keep House's triangular roof silhouette and procedural joining across three tiers: Hay, Planks, red clay tiles. New Houses start at Tier 1. Tier 2 adds Log braces and allows building above; Tier 3 retains that support and replaces the covering with red tiles. Existing Houses without saved tier metadata remain Tier 3 for compatibility. Expose all three models in Arrange. No fourth tier or metal roof at this stage.

Upgrade the selected House with the concise ↑ action, or place House on the existing House cell. Workers deliver and install materials while the existing House stays occupied. Preserve supplies, residents, orientation and placement; block moving during the upgrade and prevent duplicate upgrades. Provisional editable costs are 2 Log + 4 Plank for Tier 2 and 2 Plank + 4 Brick for Tier 3. Brick represents fired clay without adding another resource. These quantities and the Tier 2 stacking threshold are first-pass balancing choices, not user-approved final balance.


### First-pass activity accents — 7 November 2026

Fill stationary animation gaps with small breathing and head-look motions, reaching gestures during harvesting/water collection/watering and pickup/deposit job phases, a repeating eating gesture, and alternating workshop hand movements. Vary idle timing by citizen identity. Blend these accents out during walking and preserve the two-hand log grip. Pause freezes the activity clock and all poses. Retain existing building/chopping gestures. Add a modest uphill/downhill torso lean from actual travel grade; this is a presentation placeholder, not per-foot terrain IK or a ladder-climbing implementation. No additional UI or gameplay timing changes.

### Physical thatch and Imbrex — 7 November 2026

Tier 1 must read as thick thatch: stagger short, tapered straw clusters in overlapping courses with uneven fringes and small seeded angle/length differences. Do not recolour full-length roof planks to represent Hay. Tier 2 retains the approved Plank geometry. Tier 3 uses short, hollow, curved low-poly Imbrex tiles in overlapping courses and curved ridge caps. Maintain the triangular roof envelope and joined T-junctions. Use solid colours and geometry only.

Add the single-purpose Tilery: Clay → fire → Imbrex, with one assignable Tiler. Its 2 X 3 X 2 plaster-and-Log room reuses the kiln construction and has a shaping bench with curved tile samples. Provisional cost: 4 Stone + 4 Clay; 6 seconds per 1:1 batch; 2 input and 2 output buffer slots. Imbrex is visible when carried, dropped or staged. Replace Brick with Imbrex in newly queued Tier 3 House upgrades (2 Plank + 4 Imbrex). Existing queued plans keep their saved costs. This supersedes the previous decision not to introduce a tile resource. No recipe selector or extra storage building.


### Ramp and ladder foot contact — 7 November 2026

Ground the approved family models with independent two-bone leg IK on natural terrain, sampling the same triangle heights as navigation. Keep a supporting foot planted in world space while the opposite foot lifts, and adjust pelvis height without stretching the limbs. Correct contact against the actual rounded leg-end vertices; the models still have no toes or separate shoe/ankle geometry.

For the existing inclined standalone ladders, use the authored 1 m and 2 m rung mesh positions and top heights, not the navigation slope as a pretend solid surface. Align the citizen with the connector, remove personal spacing offsets there, alternate support on the rungs and increase swing clearance. Preserve the approach and landing, child scale, underhand cargo grip, pause and relocation resets. Keep simulation routes, travel speed, construction geometry and UI unchanged. At compressed travel speeds a leg may replant when it reaches its limit; this is not a change to simulation speed. This pass covers natural ramps and standalone inclined ladders; authored indoor stair paths retain their existing animation until their treads have equivalent contact data.


### Indoor stair contact and citizen world scale — 7 November 2026

Use the existing indoor U-turn staircase's actual prefab tread footprints and heights for both ascending and descending foot placement. Include its middle landing and the adjacent room floor tops. Derive contact data from the same Stair geometry as rendering, rebuild it with room navigation, and select the active connector so feet cannot snap to the floor below or the other flight. Align walking with travel through the turn and advance the stepping cycle by tread spacing. Preserve routes, construction dimensions and simulation travel speed.

Increase live citizen scale by 50%: the authored adult becomes approximately 1.4 m tall next to a 2 m storey, and children remain 70% of the adult scale. Preserve the approved proportions, clothing, polygon counts and animations. Carried goods retain their original world dimensions; move the hands farther apart along the same Log while maintaining the underhand contact and clothing clearance. This applies to the population, not to the older isolated sculpting studies.

Both the outdoor inclined structures and indoor flights are stairs. Existing code sometimes calls the outdoor connector a ladder; no vertical ladder is implemented in this pass. Vertical ladders remain a future option.


### Continuous stone roads, vine moves and building stacks — 7 November 2026

Completed Roads use multiple individual low-poly quarry stones, with nine visible pieces in each one-metre tile. Sample their arrangement in world space so adjoining Roads form continuous paving through straight sections, bends and junctions. Fit stones to the actual ground and refresh exposed edges when neighboring roads are built or removed. Keep the construction cost at one Stone per tile.

Select a living Vine and use Move to choose its new root position. A citizen uproots, carries and replants that same root; health and water are retained, and branches regrow against the new surroundings. Remove the Nature construction category, including the Tree and Palm seed buttons. Preserve existing plants, seed orders and old collected-root saves. A dedicated tree planter workplace remains a future design idea, not an implemented or configured building.

Sheds can stack on Sheds, and roof-bearing buildings support upper construction using their own footprint, orientation and roof height. Planned and completed stacks share these checks. Covered Shed canopies disappear; uppermost canopies remain. Keep required support buildings protected from relocation while they carry upper construction. The current Mill uses its 3 X 3 base and a five-metre socket above the main pitched roof, with a visible bearing frame when stacked. Ignore blade clearance for placement for now. This replaces the earlier seven-metre Mill reservation without changing the tower, axle, blade length or narrowed blade width.

Anchor the Mill's name tooltip above its stationary visible body. Exclude the spinning rotor from both the anchor height and projected silhouette, for hover and selection. The camera and building orientation may change the projected position; blade rotation must not.


### Connected normal Homes and functional services — 10 November 2026

Normal Home placements should produce the modular demo appearance when connected
through an entry or stacked. Retain actual Home identities, inhabitants, stores,
construction costs and paid support tiers. Use the shared seeded facade/material
components beyond the old Blueprint silhouette. Covered roofs disappear and
exposed lower roofs become usable terraces; upper rooms require real access.
Keep physical hay, planks and curved clay tiles with the official material palette.
The additive Building plan remains available, but a separate tool/prototype must
not be required to obtain connected Home assemblies.

Integrate brick stove/chimney, stove-fed gas lamps and roof rain collection with
actual worker jobs, material consumption, connections and persistence. Replace
roof-edge decorative logs with gutters and downpipes delivering to a real water
container. Keep inspection and actions concise in the existing selection toolbar
and on visible fixtures. No electric generator or Iron production chain is implied.

A flat balcony projecting one metre with no occupied room/load above uses light
joists, without heavy diagonal braces or ground pillars. Room-bearing overhangs
retain structural support. In the inspection demo, the brick-to-metal stove
upgrade button stays visible and shows its cost, disabled when unaffordable.


### Small stacking irregularities and quiet build menus — 10 November 2026

New Homes stacked on Homes receive deterministic horizontal offsets rather than
perfectly aligned silhouettes. Keep 2 × 2 × 2 m rooms and exactly 2 m storeys;
use bounded small offsets, preserve them in the existing placement state, and
keep same-floor door connections aligned. Fit short diagonal supports underneath
projecting occupied corners, reserve window clearance, and include their timber
in construction costs. Connect terrace entrances with light threshold decks.
Selection, copying, navigation, chimney obstruction and rain pipes must follow
these physical room positions. The inspection generator also varies upper-room
positions; existing saved placements do not reroll.

Build menus show miniatures and names only. Move costs and benefits into hover
tooltips. Use opaque, depth-tested building previews so internal overlaps stay
hidden; keep existing placement outlines and validity colours. Revealed dollhouse
rooms hide their ceiling fixture and its suspended supply line, while exterior
lamps remain visible. Do not add persistent instructions or goal displays.

### Construction feedback in existing counters — 10 November 2026

Confirmed: show the result of the current building action at the existing numeric
readout. A Home previews three additional housing places (for example 9 → 12),
with a brief pulse and palette colour; retain that forecast while construction is
queued and confirm it on completion. Do not count housing places as instant new
residents. Keep built/planned/preview distinctions in the counter tooltip. Wells
show their actual location-dependent yield in placement and hover tooltips: three,
two or one water per four seconds of rain for one unit. No extra persistent panel.

### Rounded puddles and shared water colour — 11 November 2026

Round the natural puddle rim, including the corners of soil-following rain pools.
Use the shoreline's turquoise base swatch for freshwater, collected-water
miniatures and utility water so the resource reads consistently. Keep the sea's
depth, waves and transparency; keep muddy Claypit water clay-brown. Preserve
puddle inventories, collection, evaporation, rainfall and saved locations.

### Puddle and Well recognition — 11 November 2026

For the shoreline comparison, natural flat-ground puddles are flush, asymmetrical
water patches that shrink without leaving a pale ring. Use the sea’s shallow-water
shader with calm water and no surf; keep the submerged bed inside the water outline.
Remove the raised circular rim: the regular stone ring and dark shaft belong to the Well. Keep
the shared water swatch, existing inventories and rounded soil-hollow boundaries.
Use the real island town with ordinary Homes and both shallow and roofed Wells
for comparison; no permanent labels or explanatory panels.

### Physical puddle basins and flat lamp lighting, 11 November 2026

Replace painted puddle patches on solid island terrain with shallow 18 cm bowls.
The deterministic outline and bowl profile drive the terrain cut, real collision,
walking height and water surface. Keep the basin after it dries. As water is
collected or evaporates, lower its level and shrink its outline inside the bowl;
rain refills it. Reconstruct bowls from saved puddle locations and the world seed,
without saving meshes or adding resource inventories. Existing soil hollows remain
physical soil geometry. Building a Well or Claypit replaces the natural bowl.

Reduce the Well shaft depths to one-third: approximately 0.67, 1.33 and 2 metres.
Keep above-ground Well stages, capacity and construction costs unchanged.

Generated Home shells, roofs, timber and utility models use the same flat painted
materials as other buildings. Only directional sunlight changes their shading,
with actual occluder shadows. Local lamps do not create gradients or orange pools
on walls and floors. Keep the powered lamp itself warm and readable at night;
charge and gas connections still control its glow. This supersedes the realistic
point-light wash used by the earlier prototype.

### Lighter outdoor stairs, 11 November 2026

Match the open stair silhouette from the connected-Home prototype. Replace the
old two-metre stair's four-post scaffold, cross-braces and wide rails with a
90 cm open flight, ordinary plank treads and paired split-Log side bearings.
Keep just the high-end bearing posts. Split Logs lengthwise at their canonical
length and diameter instead of shrinking the world's stock meshes. Give the
one-metre rise variant five 20 cm steps and the two-metre variant ten. Preserve
landing sockets, reserved footprints, routes, construction costs and custom
appearance overrides. The metre Stair also uses split-Log flight bearings and
slimmer unloaded posts; retain its full load-bearing frame when carrying Support.
Keep editable source scenes and runtime height variants consistent.

### Mixed buildings use the Home assembly system, 11 November 2026

Extend the ordinary Home construction behaviour to existing workplaces and storage.
Use real catalogue footprints and roof socket heights, including 2 by 3 metre
workplaces and one-metre storage modules. Door-to-wall contact joins enclosed
rooms; open workplaces share their accessible edges. Wall-only and corner-only
contact do not open enclosed rooms. Share coincident posts and bearing beams,
rebuild exposed walls after removal, and replace covered roofs with usable terrace
strips around the upper footprint. Planned upper construction opens the required
lower terrace so builders can reach it using real stairs.

Keep ovens, saws, pottery wheels, benches, cargo, inventories, workers and production
at their existing building addresses. Wells, extraction sites and tall machinery
retain their purpose-specific models and roof sockets. Construction recipes and
capacity remain authoritative. Do not turn a workplace into housing or install free
household utilities. Home offsets can now follow workplace roof bearings; occupied
corners that project beyond the bearing use the existing paid short-brace rule.
An unloaded terrace uses light decking and rails.

The common shell uses the Home material palette, ordinary stock timber and existing
roof coverings. Workplace material exemplars save only their version, seed and
sparse overrides, retain their seed when moved, and use the shared zoom detail
system. Reconstruct connections from saved building poses instead of saving meshes.
Mixed-room paths pass through the rendered portals and avoid central work equipment.
Home chimney obstruction and rain routing account for workplace envelopes too.
Keep the current compact building menu and functional room identities.


### Mixed-building walking clearance, 11 November 2026

Open workplaces provide through passages wherever the retained equipment leaves
room for a citizen. Enclosed workplaces use their visible door openings. Rotate
and offset those paths with the actual model, and share them with normal work,
hauling and household journeys. One-metre storage shelters do not count as rooms
with adult headroom. Use the source floor height for workplace feet and the same
stock geometry for cargo collision and rendering. Keep distinct reachable working
positions in open workshops when space permits.

Short thresholds can join the different catalogue footprint sizes across gaps up
to 0.76 metres. Ovens sit back from side doorways; the Tilery moulding bench and its
tile samples turn together against the side wall. Keep their recipes and production.
Stairs and bridge landings open real terraces and matching railing gates. Citizens
stay clear of the physical diagonal brace stock and pass through upper doorways
before turning across a terrace. Removing a connection restores the exposed shell.

Depot handovers happen from the perimeter. A delivery waits while someone is
crossing the storage aisle, then places the carried item without changing costs or
capacity. Stored material changes refresh the walking routes. No new configuration
panel or tutorial text is introduced.


### Wide open windows, 11 November 2026

Generated Homes and connected workplace shells use 90 cm wide open windows,
with a simple outer timber frame and sill. Remove the central vertical divider
and leave the aperture unglazed so the interior is visible through it. Keep
seeded placement variation within 30 cm of the wall centre and preserve the
existing clearance checks for supports and stove shafts.

### Overhang support thresholds and hover preview, 11 November 2026

Measure unsupported projection along each horizontal axis from the real roof
bearing. Up to and including 0.5 m adds no support members. Beyond 0.5 m use
45-degree diagonal braces, retaining them between 1 m and 1.5 m; at 1.5 m and
above use vertical posts down to actual terrain, a deck or a lower roof. Never
terminate a post in empty space. Small offsets no longer add a timber surcharge;
required larger supports consume the number of ordinary Log pieces they use.

Route supports around existing window apertures and door approaches. Preserve the
wide, unglazed windows rather than moving or closing them to make room for a brace.
If no clear support arrangement fits, reject the placement. Include the physical
timber bounds in walking clearance, keeping the space between posts traversable.
The ordinary Home hover preview uses a private prospective world and the same
assembly and support geometry as the completed building. It updates as the target
changes without adding a new configuration panel or changing the real town.


### Horizontal wall shades, 11 November 2026

Remove random wall colours from generated Homes and connected workplace shells.
Use one shared warm wall colour from the official palette, shaded uniformly by
two-metre storey: the lowest levels are darkest and each higher level is lighter.
Rooms at the same level use the same base shade regardless of their seed or kind.
Keep real sunlight shadows, material identities and seeded building shapes. Apply
the same rule to the prototype, hover preview and completed town buildings.

### Blocky terrace railings, 11 November 2026

Use the supplied Cube & Seek reference for simple timber silhouettes and visible
overlapping joints. Following the visual review, terraces use low rectangular
"O" frames with a top rail, bottom rail and sparse upright posts, rather than
the earlier tall "Pi" silhouette. Keep the frames about 0.68 m high and
approximately one metre wide. Use lightly chamfered timber 0.065 m thick, similar
to the doorway trim, with contrasting end grain. Rails extend past their posts.
Give short panels stable angle variation up to five degrees in either direction,
small height differences, and a mixture of shared posts, overlapping joints and narrow gaps.
The overall run still follows the straight terrace edge. Occasional displaced
lower rails form a worn N shape while the upper safety rail stays intact. These
are seeded construction variations, not a simulated deterioration timer.
Keep the existing wood palette and horizontal building shades.

Safety railings are automatic and free as part of the terrace. Preserve stair,
bridge and doorway openings, omit rails between connected terraces, and account
for the actual timber width in walking clearance. Regenerate rails from the deck
layout in the main game, placement preview and prototype, without extra save data
or a separate construction recipe.
Call these automatic fences; do not introduce a manually placed Fence tool.

### Slightly rotated Homes, 11 November 2026

Give ordinary Homes a stable yaw between zero and five degrees, derived from the
world seed and building address. Neighbouring Homes can differ by up to five
degrees. Apply this to exposed walls, corner posts, bearings, floors, roofs and
terrace fences in the main game and placement preview. Keep shared doorway walls
fitted at their common seam, and close the small floor/deck gaps with timber
connections. Stairs retain their placement and open onto the rotated terrace.

Use the same transformed doorway and terrace positions for walking. Rotate roof
utility attachment points with the Home. Support attachments can shift within the
corner timber to clear openings; keep the existing placement-offset thresholds
and actual stock costs. Nearby rotated roof bearings can carry a corner. Preserve
material colours, house capacities and existing saved construction records. Yaw
needs no separately saved meshes or new control in the building menu.

### Terrace edge fences and fitted plank floors, 11 November 2026

Keep each automatic fence run on one outer deck edge. Never merge adjacent sides
into a diagonal across their corner, and leave the timber seams between connected
terraces open for walking. Preserve the stair and doorway openings. Small timber
irregularities stay within the edge strip, not across the usable terrace.

Use the supplied Caravan SandWitch reference for visible wooden construction
without a texture. Walkable roof floors continue the Support decking's timber
language, using the official sawn Plank colour. Group the floor into exact one-metre
square patches, each with five parallel strips. Align stock joints inside each
patch rather than staggering rows like brickwork; neighbouring patches can turn
their board direction. Make chipped top edges and roughly 30 mm height differences
visible, while the solid sides continue to meet without gaps through the floor.
Cut pieces from canonical 0.7 by 0.22 by 0.055 m Plank stock without stretching it.
Their solid sides meet without holes through the walking surface. Clip the floor
to the fenced footprint and keep utility shaft openings clear. Geometry variation
is seeded and cached, with no per-board mesh data added to saves or new costs.

### Readable timber and uneven thatch, 11 November 2026

Keep timber edges readable in direct sunlight. Planks and stair treads use stronger
side-face shading and directional face response, retaining actual sun shadow maps
and the existing wood palette. Do not introduce glossy shading or local lamp
gradients on building walls. Verify preview captures with the sun lighting updated
from the same simulation time as the colour grading.

Hay roofs use long, overlapping low-poly sheaves with uneven raised ridges, tapered
ends, varied bundle heights and a rough eave, inspired by the supplied reference.
Keep the Hay palette and a continuous straw bed below the bundles. Cut both the
bed and covering around the real chimney opening. Apply this to generated Home
and workplace hay roofs; clay tile geometry, recipes and utility behaviour remain
unchanged. Regenerate seeded roof geometry rather than saving individual sheaves.

### Scarcity, reuse and outside requests, 11 November 2026

Set aside the earlier expansive waste and litter proposal. This small settlement
has scarce manufactured materials, so people keep, repair and repurpose useful
objects. Do not introduce disposable cans, discarded transparent glass bottles
or ambient rubbish to make the town look occupied. The available vessels are
clay pottery, with practical storage and carrying roles.

Keep preparing and sending requests to outside settlements as a future direction:
offer goods for sale, request needed materials, or invite additional settlers.
The communication carrier and delivery rules remain undecided. Do not assume
clay vases serve as floating message bottles, or implement a waste economy or
messaging system from this proposal alone.
