# Pyramida — Future Ideas

Status: exploratory design notes. These ideas are not part of the first playable version and do not override the current code, tests, or foundation specification.

This document is a holding place for possible long-term systems that could make vertical and underground construction meaningful while preserving a believable, recoverable settlement world.

## Settlement life, room editing and cutaways — 7 November 2026

The user asked to save the discussion as conceptual direction only. [The direction entry](docs/DESIGN_DIRECTION.md#conceptual-settlement-loop-room-editing-and-cutaways--7-november-2026) records the references and constraints. No implementation is assigned. The next design work should focus on room editing and cutaways before expanding survival or logistics systems.

The proposed loop is to maintain a small community, improve its homes and utilities, and use the resulting time and resilience to expand vertically. Test whether improvements make citizens' lives visibly better and whether height creates worthwhile access and carrying decisions. Avoid making every comfort improvement merely trigger higher production quotas.

Ideas retained for later testing, with no chosen mechanics or tuning:

- Hunger: a recurring supply obligation that competes with construction effort. Investigate consequences that preserve a practical route back to food production.
- Nighttime danger: potentially unsafe journeys or incapacitating enemies inspired by the original Pyramida as described by the user. Shelter, recovery, warning and whether combat is needed remain open. Unaided recovery by morning and faster recovery in a bed were examples, not decisions.
- Pneumatic delivery: potentially a playful pipe-based way to move goods. Evaluate whether it supports vertical living or removes useful carrying and distance decisions. No conveyor belts or goods-delivery vehicles; physical citizen hauling remains the baseline.

Room editing and cutaway interaction questions to resolve next:

1. Entry and scope: how does a player select a buried room and enter or leave interior editing? Compare editing interiors of recognizable ready-made buildings with the retained room-editor capabilities, without restoring the general construction toolbar by default.
2. Placement: how should floor and wall attachment, rotation, equipment footprint and operating space appear? Show the actual entrance-to-use-position route and the obstruction that prevents use. Decide how to prevent accidental placement on another storey.
3. Visibility: explore a local cutaway that removes the selected room's roof and obstructing geometry above or in front, retains enough surrounding structure for orientation, and restores the city on exit. Compare room focus with floor focus; whole-city transparency is not the assumed solution.
4. Connections: explore revealing only the selected pipe network, including source and destination, with clear continuation markers where it crosses the cutaway boundary. Decide how to follow it to another room or floor without losing the original context.
5. Readability: can a newcomer identify a blocked bed, inaccessible device or disconnected pipe and correct it through direct manipulation and visual feedback? Preserve concise contextual labels, shared UI point rules and hidden instructions/goals.

A household, food source, upstairs living space, editable interior and one water connection were suggested as a possible later evaluation scene. This is not an approved prototype task. Resolve the interaction design first; hunger, nighttime danger and pneumatic delivery need not be included in that exploration.

### Bedroom walkthrough: retained concept — 7 November 2026

The user considers this a promising direction and asked to keep it. It remains conceptual, with no gameplay, UI or prototype implementation authorized. Scenario: a middle-floor bedroom in a three-storey house is hidden behind a taller building; the player moves its bed, checks downstairs and returns.

1. Reveal the target. Select an exposed roof or wall if available. If the house is fully concealed, use a temporary section view and lower its cut height through the surrounding cluster until real floors and rooms are visible. Revealing geometry is a viewing action, not selection or demolition. Avoid cycling blindly through hidden object names.
2. Establish the working area. Hover outlines an exposed room; clicking selects it and identifies its building. Hold that building's cutaway stable, including necessary foreground occlusion removal, even when the cursor leaves the room. Do not jump or automatically zoom the camera on entry.
3. Select the bedroom. Remove upper storeys from view, retain solid lower storeys and shorten camera-facing walls while preserving corners and doorways. Keep neighboring rooms and stairs visible with quieter emphasis. Selecting another room on the same floor changes selection without changing the cutaway or camera; hovering alone never changes cut geometry.
4. Move the bed deliberately. Select the bed and choose Move. Reserve its original position until confirmation and restore it on cancellation. Preview footprint, operating clearance and the actual blocked doorway or access route. Keep the active floor fixed during placement; cross-floor transfers require a separate deliberate action. For wall-mounted equipment, temporarily reveal hidden attachment walls as targetable construction surfaces.
5. Inspect downstairs. After confirming or cancelling placement, switch the viewing level using a contextual floor selector whose final form remains undecided. Preserve horizontal camera position, angle and zoom, with a short vertical cutaway transition. Keep the stairwell as a spatial landmark. Do not automatically select a downstairs room; remember the upstairs selection.
6. Return upstairs. Restore the remembered bedroom/object selection. Each visited floor can retain its selection during the inspection session. Do not scatter ghost outlines of hidden selections through the building. Use actual usable levels within the selected building for floor navigation, including uneven or offset structures.
7. Leave inspection. Resolve any unfinished placement, then restore the complete exterior and pre-inspection camera position. Reopening the building returns to its last inspected floor. Exact back-action sequencing and persistence beyond the current session remain to be specified.

The main distinction is revealing a place versus working in it: discovery may cut through a crowded area, but selection should establish a stable editing view. Compare a local neighborhood cut with a wider horizontal slice for initial discovery before choosing the scope. Also resolve contextual floor-selector appearance and input bindings without adding persistent instructions or goal displays. These are next design questions, not an implementation queue.

### Floor tools and household scope: proposal — 10 November 2026

The user has now authorized implementing House → Floor → Room selection in the main game; see [the selection direction](docs/DESIGN_DIRECTION.md#house-floor-and-room-selection--10-november-2026). The camera and utility interactions below remain proposals. A ready-made building can be treated as a furnished room module in a larger household, with function determined by its equipment. Future mixed-purpose modules need persistent household ownership independent of their room role, stairs, pipe networks or temporary disconnection. The current implementation groups connected House modules for inspection and retains their physical addresses; it does not implement this broader ownership model.

Keep the orthographic world camera on entering inspection. At floor scope, hold a local section through the selected household: remove its upper storeys, keep lower storeys solid, shorten camera-facing walls and retain stair/door landmarks. Occluding neighbors may need a limited foreground cut, without making the entire settlement transparent. Hover never moves the section. A compact contextual up/down control visits actual usable floors without changing horizontal camera position, angle or zoom. Preserve the remembered room/object on each floor and restore the exterior on exit. A separate deliberate top-view action could help precise placement; automatic rotation is not proposed.

Treat floor construction as shared circulation and services. A stair preview includes its flights, destination landing, floor opening and walking clearance. A lift preview aligns one shaft through the chosen levels and shows each proposed landing; validate the entire shaft and every opening before committing any part. These are spatial placements in the world, without a building configuration panel. Floor selection defines the working context, while a connector tool may deliberately span several floors.

Room construction places or moves equipment with a visible footprint, door access and operating clearance. Furniture stays locked to its starting floor until confirmed or cancelled. Walls shortened by the cutaway remain available as explicit ghost attachment surfaces when placing wall-mounted equipment. Installing a bed or workshop device changes the room's capabilities while preserving the household to which it belongs.

Pipe placement starts at a typed port and snaps along eligible floors or walls. Reveal the selected network with source, destination and continuation marks at the section boundary. An explicit vertical-connector action can extend the route to another floor while retaining the original endpoint; ordinary floor browsing must never silently move an unfinished placement. Validate connection type and obstruction before committing the complete route. Keep walking and utility graphs independent, and make disconnected equipment visibly inactive rather than adding a persistent diagnostic panel.

## ISLANDERS terraces and scarce buildable land — 7 November 2026

Reference: [ISLANDERS on Steam](https://store.steampowered.com/app/1046030/ISLANDERS/). The user likes the low-poly modelling of terraced mountains surrounded by water, the overall visual style and the interesting building designs. Keep these qualities as inspiration for our own terrain and architecture.

Explore water-bounded mountains with limited buildable terraces as a natural way to make land scarce. Revisit when designing terrain generation, coastlines, buildable footprints, vertical expansion or building silhouettes. The terrain proposal remains exploratory; it does not commit us to ISLANDERS' casual city-building loop or schedule a terrain rewrite.

The accompanying direction is a truly 3D environment, with buildings that communicate their purpose and activity visually. Avoid complex building settings, production sliders and shift-scheduling interfaces. Preserve the existing clean UI and fixed-purpose workplaces; the confirmed constraint is also recorded in `docs/DESIGN_DIRECTION.md`.

Concept illustration: [Pyramida mountain terraces and rope bridges](artifacts/concepts/mountain-terraces-rope-bridges-2026-11-07.png), generated with the built-in image tool using the project's building roster, connected-building and citizen screenshots as references. [Exact generation prompt](artifacts/concepts/mountain-terraces-rope-bridges-2026-11-07.prompt.txt). This is an art exploration, not a validated playable layout; bridge gradients, access to every outcrop and construction geometry still need in-engine validation.

## Grid buildings, free bridges and readable logistics — 7 November 2026

Prototype follow-up: the user explicitly requested implementation of Rope production from Hay and Rope-and-Plank bridges as frequent shortcuts between elevated tower levels. The [isolated live prototype](README.md#rope-bridge-prototype) now exercises construction, free endpoints, hauling and saves. The architecture below remains a broader proposal; the first version connects existing floor-cell identities with continuous bridge paths and permits one span per landing-cell pair, without migrating the whole graph to new node identities.

User-confirmed constraints and future wishes:

- Keep buildings and stacking on the grid for now. Slight stacking offsets remain an idea to revisit, with shared walls/structural elements, clipping, overlapping surfaces and awkward triangular rooms explicitly unresolved.
- Future rope bridges can run diagonally with endpoints at different elevations, independently of the building grid. Their endpoints must still attach to valid walkable landings.
- Citizens should find routes across usable terrain, floors, accessible roofs and bridges without requiring a road connection at every building entrance. Resource management and physical transport are the focus.
- Retain the user's “wilmoth warehouse” reference as supplied, with the exact title unverified. The interesting quality is visually recognizable resource shapes and their organization. Log → Plank is the explicit raw-to-processed example; processing consumes production effort. Whether dedicated stores should universally hold exactly two related resource types remains open.

Suggested implementation approach, not an assigned implementation task:

1. Extend the existing surface graph with explicit bridge landing nodes at continuous world positions, using stable identities independent of integer grid coordinates. Preserve separate identities for overlapping floors and connect landings only to their actual accessible surface, with clearance checks rather than nearest-cell attachment across walls or elevations.
2. Store each bridge's supported endpoints and a sampled deck curve. The same curve determines visible planks, citizen motion and travel length. Validate the whole span for local slope (including sag near landings), width, headroom, collision, anchor support and length. A curved bridge must not be costed or traversed as a straight teleport between its ends.
3. Search the combined graph using travel-time costs, including actual bridge length, speed and any deliberately introduced slope or waiting cost. The current navigation code already uses a weighted search over surfaces, stairs and room connections; roads provide a cost discount rather than defining all walkable surfaces. Arbitrary bridges require extending route representation and movement, not just adding a visual mesh. A* is an optional optimization with a valid lower-bound heuristic, not a prerequisite.
4. Keep routes cached; invalidate affected connectivity when a bridge, landing or supporting surface changes. Define removal behavior for occupied bridges. If narrow bridges need one-way-at-a-time reservations, treat that as a separate traffic rule; do not assume shortest-path search alone prevents collisions or deadlocks. Visual sway can remain independent of a stable walking curve initially.
5. Prototype two terraces at unequal heights, each with a building entrance, and one diagonal bridge. Verify walking and carrying in both directions without roads, a blocked landing, an alternate route and safe handling of bridge removal. Keep optional flat-roof walking limited to roofs designed for access, with stairs/doors and adequate clearance.

[Godot's NavigationLink3D](https://docs.godotengine.org/en/stable/classes/class_navigationlink3d.html) provides a related endpoint-link concept with direction and traversal costs if a navigation-mesh approach is evaluated later. It is not currently the project's custom graph, and a link alone does not provide bridge geometry or curve-following movement.

For storage, a possible visual treatment is fixed bays for related forms: round-ended Logs beside rectangular Planks in the Shed; rough Stone beside cut Slabs in the stone store. Let the visible stacks communicate contents and available space. The logistics decision can come from where stores, producers and consumers sit and how long carrying takes. Exact bay capacities, allocation, additional processing tiers and generalization to other material families remain undecided; no player sliders or new interface are implied.

## Scene-building references to revisit — 6 November 2026

The user asked to retain the references discussed on 27–28 October as ideas, bring them back occasionally when relevant, and let future design choices gradually move toward compatible solutions. These are exploratory preferences, not an implementation queue or a commitment to combine every mechanic. Scene creation is the main attraction in these references; collecting resources is not the quality the user wants to borrow.

| Reference | What the user likes / wants to explore | Useful moment to revisit |
| --- | --- | --- |
| Midnight Moments (title as supplied by the user; exact reference unverified) | Building by placing individual cubes feels like drawing. Preserve that freedom while providing actual interior structure, rooms and connections rather than solid building masses with exterior decoration alone. | Building geometry, room authoring, interiors and cutaway views. |
| [High Above](https://store.steampowered.com/app/3535760/High_Above/) | Appealing furniture and decorative models, flexible placement that does not feel rigidly bound to a grid, automatically generated tiled roofs, and fog that makes the bottom level less visible. Adapt these concepts to our own styling. | Furniture placement, editor interaction, roof generation and atmospheric rendering. |
| [Cube & Seek](https://store.steampowered.com/app/3433080/) | Charming miniature building and fan models and their aesthetic treatment. Borrow the clarity and character of small models for scenes the player creates. | Asset proportions, building details, small animated machinery and scene composition. |
| [Laysara: Summit Kingdom](https://store.steampowered.com/app/1823950/Laysara_Summit_Kingdom/) | Mountain construction and a stronger sense of height and verticality. Explore buildings on mountain ledges and tunnels inside the mountain. | Terrain, vertical access, excavation and connections between interior and exterior spaces. |

The user also proposed poisonous gases covering the lower world as a possible reason to build high on mountains. The game behind this gas recollection was not identified in this discussion; do not attribute this mechanic to Laysara. The design direction separately records Above: Colonies of the Mist, identified by the user on 30 October, as a related reference for hazardous lowlands and hilltop connections. Gas behavior, consequences and any survival pressure remain undecided.

Possible adaptations discussed by the assistant include gentle optional furniture snapping, roofs that adapt to building outlines, cliffside rooms, bridges, lifts, ventilation shafts, and a cutaway view of furnished mountain tunnels. These are suggestions, not user-confirmed implementation requirements. The two-peak scene with a home, bridge and tunnel was a suggested prototype, not an assigned task.

When a related design decision arises, briefly resurface the relevant reference and explain the concrete connection. Prefer small compatible steps within the current task; discuss substantial changes to setting, mechanics or art direction before treating them as settled. Keep our own visual identity and the existing clean-UI rules. Revisit naturally during project work rather than issuing recurring calendar reminders.

## 1. Environmental pressure: buried and snow-covered buildings

### Core idea

At night, occasional severe weather may move sand or snow across the settlement. A strong wind or sand dune can cover part of a universal construction block, such as roughly half of one block's height. Over time, buildings appear to sink into the landscape unless the player excavates them or continues construction upward.

The same broad pressure could work in a snow biome: snow accumulation gradually buries lower floors and forces the settlement to build upward, maintain access, and keep important functions above the expected snow line.

### Why it could motivate underground construction

- A buried lower level can remain useful as protected storage, a workshop, a shelter, or a passage.
- The player may deliberately excavate downward instead of constantly clearing the surface.
- The pyramid can become a meaningful deep-time landmark: its lower structure may be buried far below the current sand level and uncovered through excavation.
- Vertical construction becomes an adaptation to the environment rather than only an aesthetic choice.

### Constraints and unresolved questions

- Weather should probably be occasional, seasonal, or forecastable rather than happening every night. Constant burial would turn routine gathering into maintenance and could erase the settlement faster than it can develop.
- Sand and snow should accumulate in manageable layers with clear thresholds, not instantly invalidate buildings.
- The player needs readable warnings, such as a forecast, wind direction, accumulation markers, and a visible “buried access” state.
- Buildings should be recoverable: shovel, excavation, raised entrances, vents, stairwells, and maintenance routes should restore access without rebuilding the whole structure.
- A buried building may need to remain structurally intact while its doors, windows, fires, and routes become blocked.

### Resource and ecology problem

If sand or snow covers bushes every night, harvesting becomes implausible and frustrating. If trees become fully buried after only a few storms, the settlement loses its wood source and the world raises an important question: how did those trees grow there in the first place?

Possible resolutions:

- Storms are intermittent and severe only during defined weather events.
- Mature trees have deeper roots and a protected growth zone; they can become dormant or partially buried without disappearing immediately.
- Sand and snow drift around vegetation instead of uniformly covering every tile.
- The player can establish windbreaks, groves, fences, terraces, or snow sheds that protect resource patches.
- Buried vegetation can be cleared, transplanted, or harvested before the storm arrives.
- Some biomes use different pressures: sand burial in deserts, snow load and blocked entrances in cold regions.

This system should create planning decisions, not remove the basic food and wood loops.

## 2. Settlement land and competing development

### Core idea

Limit uncontrolled one-story sprawl through land ownership rather than an artificial building-height rule. The initial settlement contains “city land” and an NPC-controlled parcel. The NPC develops its own empire inside or beside the town.

To expand, the player must purchase or otherwise acquire the adjacent plot first. Ownership can extend across a road, creating a reason to negotiate, trade, compete, or plan around another settlement.

### Natural dividers

The world should contain natural and civic dividers that prevent one infinite, uninterrupted building mass:

- Roads and alleys.
- Open courtyards and plazas.
- Water channels or drainage cuts.
- Cliffs, dunes, rocks, and biome boundaries.
- Parks, protected groves, and undeveloped reserve land.
- NPC borders and purchased plots.

These dividers can preserve readable districts without preventing the player from building a connected vertical city.

### Cross-road connectivity

Buildings on opposite sides of a road may still connect through elevated or underground passages and corridors. The road remains a meaningful public boundary at ground level while the player can create a more complex three-dimensional town above and below it.

Important questions:

- Who owns a passage crossing another parcel?
- Does a passage require a permit, a fee, or an agreement with the NPC owner?
- Can a public road be bridged without blocking traffic or sunlight?
- Are underground connections safer from weather but more expensive to excavate?

## 3. Fire, utilities, and separated buildings

### Core idea

Fires create pressure to separate buildings. Stoves, furnaces, electrical networks, and water pipes become valuable but dangerous infrastructure. A fire can jump to a neighboring building when structures are too close and there is no gap or firebreak.

This encourages the player to make distinct buildings instead of one continuous block, while corridors, utility lines, and covered passages preserve functional connectivity.

### Fire-prevention choices

- Leave a gap between buildings.
- Build firebreak walls or courtyards.
- Add sprinklers and water storage.
- Separate kitchens, workshops, generators, and sleeping areas.
- Use safer building materials.
- Install valves, circuit breakers, chimneys, vents, and drainage.
- Keep emergency corridors accessible.

The player should be able to trade compactness for safety and maintenance cost.

### Recovery and rebuilding

Fire should be serious but not permanently punitive. A destroyed building should leave a recognizable foundation, ash, and salvageable remains. The player should be able to place the same blueprint on the cleared footprint and rebuild it with a predictable recipe.

Potential recovery flow:

1. Extinguish or contain the fire.
2. Clear ash and unsafe debris.
3. Salvage surviving materials.
4. Reapply the original building blueprint.
5. Reconnect utilities after inspection.

Blueprint identity is important: reconstruction should restore the same building layout, orientation, and utility ports where possible, rather than forcing the player to remember every block manually.

### Fire behavior to investigate

- Fire spreads by adjacency, combustible material, heat, and wind.
- A real gap, fireproof wall, or wet barrier can stop spread.
- Smoke and heat can make an interior unsafe before visible flames arrive.
- Sprinklers reduce spread and damage but require water pressure and maintenance.
- Fire should not randomly destroy an entire settlement without warning or a plausible chain of causes.

## 4. How these systems could reinforce one another

The strongest version combines the systems as interacting pressures:

```text
weather burial -> blocked lower access -> need for excavation or upward growth
land ownership -> bounded districts -> value of vertical and underground connections
fire risk -> separated buildings -> value of passages, courtyards, and utility planning
blueprints and salvage -> affordable recovery -> experimentation remains safe
```

The shared design goal is to make verticality, underground space, land planning, and infrastructure meaningful without making ordinary resource gathering impossible or turning setbacks into irreversible loss.

## 5. Candidate order for future prototyping

1. Prototype recoverable sand or snow accumulation on a small test map.
2. Add forecastable weather windows and protected resource patches.
3. Test land parcels, roads, and an NPC development boundary.
4. Test cross-road passages and underground access.
5. Add localized fire spread between simple separate buildings.
6. Add sprinklers, firebreaks, salvage, and blueprint reconstruction.
7. Revisit the buried pyramid as a long-term exploration landmark.

## 6. Design guardrails

- These systems should remain optional future expansion, not requirements for the opening prototype.
- Resource renewal must remain believable under weather pressure.
- The player should receive warnings and planning time before major environmental events.
- Damage, burial, and ownership disputes need reversible recovery paths.
- Vertical and underground construction should be rewarded by strategy, not forced by an opaque height cap.
- Separate buildings should be useful even when no fire occurs, through privacy, specialized workflows, zoning, and district identity.

## Optional small learning goals

Deferred by the user on 2026-10-18. Do not display tutorial milestones or next-target prompts in the current game. The HUD objective and completion message have been removed.

Keep the idea for a future onboarding discussion: offer one small, achievable goal at a time so players learn through actions and modest achievements. Revisit only if playtesting shows that players need guidance; this mechanic may never be needed. Object inspection and contextual actions are separate from tutorial milestones.


## Dedicated tree planting workplace — 7 November 2026

Consider a dedicated workplace whose assigned citizen plants Trees and Palms, inspired by the forestry workflow the user described in Timberborn. This would give planting a visible occupation and building instead of a Nature construction category. Seed supply, planting area, species choice and the building's form are still undecided. Keep this conceptual; no new workplace or configuration panel is requested yet.

## Drifting ice and seasonal coast changes — 10 November 2026

The user proposed large floating icebergs or flat ice sheets around the islands for a later iteration. They could drift with wind/current and shrink over time to make seasonal change visible. Building on an ice sheet is undecided; it may remain a landscape feature only. Explore scale, movement, gradual melting and how they frame the islands before deciding on moving construction, citizen navigation, transport or failure rules. No iceberg gameplay is implemented or authorized as part of the current shoreline/wave change.
