# Building measurements and progression

Current Tier 1 dimensions are authoritative in [reviewed_balance.json](../data/settlement/reviewed_balance.json), in width X depth X height order. Earlier room variants below remain proposals.

30 October 2026. Design proposal based on the user's building sketches. Metric units and the requested scope are recorded below; rules labelled as proposals still need playtesting or a design decision. The first room-construction milestone now implements the 2 m module conversion; broader progression rules remain proposals.

Implementation update: the Building demo v0.7.0 now includes both confirmed stair prefabs and connections to adjacent rooms, halls and exposed roofs. See [the demo controls and implemented scope](block_city/README.md#stair-prefabs--v070). One demo cell maps explicitly to 2×2×2 m in the main settlement room editor. The U-turn stair, frame infill, worker construction and upstairs bed access are integrated; broader room-size and economy proposals below remain future work. Semi-automatic choice of stair arrangement is not yet implemented.

## Metric construction units

One World Unit is a 1 × 1 × 1 m cube. A Sub-Unit is 0.5 × 0.5 × 0.5 m: eight fit inside a World Unit. Use metres for dimensions and reserve “room” for an architectural space, rather than a measurement unit.

Write human-readable dimensions as **width × depth × height**. Machine coordinates use **[x, y, z]**, with y up. Prefer named dimensions in data to prevent swapping depth and height.

| Element | Requested dimensions or rule |
| --- | --- |
| World cube | 1 × 1 × 1 m |
| Equipment subdivision | 0.5 × 0.5 × 0.5 m |
| Door | 2 m clear height; width remains a design choice |
| Smallest inhabitable room module | 2 × 2 × 2 m |
| Other room modules | Independent integer dimensions, initially 2–4 m on each axis |
| Small vertical connector | 1 × 1 m footprint, 1 m rise |
| Compact stair assembly | 2 × 2 m footprint, 2 m rise |
| Larger stair assembly | Six-cell arrangement to clarify; candidate below |

The 2 m minimum is a game abstraction. It does not promise that a bed, sink, freezer, table and clear circulation all fit into the smallest room. Furniture footprints, interaction spaces, door swings if simulated, and walking clearance determine whether a particular arrangement works.

**Open decision:** whether room dimensions describe usable interior or the exterior shell. Proposed starting convention: nominal usable space, thin shared boundary walls, and floor/ceiling thickness abstracted at the module boundary. This allows a 2 m door and 2 m storey to coexist without subtracting a lintel and slab from headroom. If physical thickness is required, the storey pitch must accommodate it explicitly. Decorative geometry must not silently obstruct navigation.

The settlement already uses 1 m horizontal cells and 1 m elevation increments in `scripts/settlement/world_grid.gd`, with 2 m reference rooms and storeys. Older prose calls those cells “half-room” cells. The new wording does not shrink assets or double saved coordinates. Block City retains room-sized cells; the settlement adapter multiplies them by two around the construction-site origin, without scaling existing world entities. The 0.5 m equipment grid remains a proposed finer authoring layer, not a claim about current world placement.

## Rooms, flats and buildings

A room is a bounded space with doors, furniture and service connections. Its usable equipment grants its functions: a reachable bed provides sleeping capacity; a working sink requires water and drainage; a freezer requires electricity. A name or material tier alone grants none of these functions.

A flat groups connected rooms behind a shared entrance. Treat the flat as a destination branch: public routes do not pass through someone's home to reach a different flat. Internal rooms may connect in a chain or through a private hall. Workshops, storage and public buildings need their own access rules rather than inheriting residential privacy.

A building groups one or more rooms, circulation, structural parts and utilities. A one-room hut is already a building. Open stockpiles, frames and platforms remain valid construction entities without becoming enclosed habitable rooms.

Placing a whole building queues its rooms and components as one construction plan, with internal dependencies. Copying it reproduces geometry, furniture specifications and internal connections. It does not duplicate residents, stored resources, construction work, or links to external suppliers. A copied plan exposes the entrances and utility ports that must connect at its new site.

## Roofs and support

Generate the roof from the exposed top boundary of the room assembly. Covering part of a lower building removes only the covered roof area; uncovered terraces retain their cap. Roof appearance follows the footprint and material family.

Preserve the existing construction sequence: an upper plan can request supports, but a lower shelter keeps its weather cover until the replacement upper floor is complete. Cancelling the plan removes unused generated supports. Removing the upper structure restores the exposed lower cap.

Support beams are generated where needed and checked against occupied space, doorways, stairs and service routes. Automatic placement does not imply unlimited unsupported spans. Keep the current simple support rules initially; structural stress and collapse remain optional. Support generation must not create walking edges. A resident reaches an upper floor only through a valid connector.

Existing automatic roof/support resource and labour rules remain in force. Whether generated structural components eventually contribute to a building's material bill is a separate economy decision.

## Stairs and entrance landings

Use distinct names for a stair with treads and a vertical ladder. The requested clockwise stair arrangements are interpreted here as stairs; ladder climbing can retain separate movement and carrying rules.

Every connector has a lower endpoint, an upper endpoint, facing directions, rise, traversable surface and clearance volume. The entrance “rug” marks a landing at the door threshold. Connect to its actual position and facing, not merely to an occupied neighbouring cell. A threshold needs a usable landing; a door cannot open directly onto a steep flight without turning space.

A 1 × 1 × 1 m stair module rises 1 m across a 1 m footprint. Its occupied geometry fits that module, while the person above it needs additional clearance. A 2 m-rise assembly similarly does not fit inside a closed box whose ceiling is at 2 m. Reserve the shaft opening and headroom above each tread and landing, including the upper arrival space. A 2 m clear envelope is the proposed initial rule.

### Confirmed compact stair with a half turn

The user confirmed this arrangement on 30 October 2026. It is a prefabricated stair occupying one room-sized logical cube in the Building demo. Under the metric description its footprint is 2 × 2 m and its rise is 2 m; it is not one 1 m World Unit. Keep the prefab available alongside individual stair and platform pieces.

Top view, north at the top. Each entry is one square metre. Heights are walking-surface elevations in metres, relative to the base. `S^0` climbs north from 0 to 1; `Sv1` climbs south from 1 to 2. `P1` is a platform at height 1.

```text
          north
       west   east
       P1  -> P1
        ^      v
       S^0    Sv1
        ^      v
     entry 0  exit 2
          south
```

The path is stair → platform → platform → stair, clockwise around four cells. Entry is at the bottom-left corner at height 0; exit is at the bottom-right corner at height 2. Both ports lie on the same exterior side, at different positions and heights. The walker enters facing north and leaves facing south: a 180-degree change in travel direction.

There is no additional upper platform inside this prefab: it ends at the second flight. Its footprint stays 2 × 2 m, not 2 × 3 m. The exit meets a usable room entrance landing, separately placed platform or walkable roof at height 2; that receiving surface belongs to the destination, not an extra row of the stair prefab. A visible roof or a nearby wall alone does not establish access. An unfinished stair may await its destination, but its upper endpoint is not a usable connection until the receiving surface is present and reachable. Repeating it vertically must also validate access between each exit and the next entrance; stacking bounding boxes alone is insufficient. The confirmed arrangement defines the intended route; detailed mesh clearance still needs validation.

### Confirmed quarter turn layout

The user's corrected quarter-turn layout also occupies a 2 × 2 m footprint and rises 2 m. It has one intermediate platform at 1 m and one upper platform at 2 m, both within the four-cell footprint:

```text
Platform 1m    Stair 1→2m

Stair 0→1m     Platform 2m
```

| Position in top view | Element |
| --- | --- |
| Bottom-left | Stair rising from 0 to 1 m |
| Top-left | Platform at 1 m |
| Top-right | Stair rising from 1 to 2 m |
| Bottom-right | Platform at 2 m |

The intended sequence is bottom-left stair → top-left platform → top-right stair → bottom-right upper platform. This correction replaces the earlier diagonal-cell interpretation. The intended entry-to-exit travel turn is 90 degrees. The cell arrangement is confirmed design intent; exact tread directions, transitions into the upper platform, exit face and body clearance still need to be authored and checked in 3D. Do not add an external platform row to either confirmed prefab.

### Proposed adaptable exit

The user requests semi-automatic changes to the exit direction using these stair arrangements.

Proposed interaction: place the lower stair entrance, then target the receiving room threshold, platform edge or walkable roof edge. Use that target's position, height and approach direction to select a compatible authored stair arrangement. Keep the existing entrance fixed while previewing the internal change and upper endpoint; changing an exit is different from rotating the whole prefab.

A small set of validated arrangements can provide the semi-automatic behavior before any general stair generator is needed. Check continuous walking surfaces, body clearance, support and interference with neighbouring construction for each candidate. If no arrangement fits the available space, leave the destination unconnected and require an additional landing or a larger footprint. Do not assume every exit position is achievable inside 2 × 2 m. For an already built stair, a changed arrangement becomes a reconstruction plan rather than instantly moving occupied steps or deleting a live route. These interaction and reconstruction rules are proposals.

### Separate larger clockwise candidate

The earlier six-sub-block idea is a separate, unresolved larger option. It does not describe either confirmed 2 × 2 m prefab and is not a required extension of them. One interpretation is a 2 × 3 m footprint:

```text
       P1  -> P1
        ^      v
       S^0    Sv1
        ^      v
       G0     P2
     entry   exit
```

The last cell has a ground surface at height 0 and an upper platform at height 2: the proposed meaning of “double-platform.” The main ascent uses the upper platform; the lower surface is separately addressable. If “double-platform” means two adjacent cells at the same height, the footprint must change. Physical slab thickness also affects clearance under the upper platform. Keep this unresolved until the user identifies the intended interpretation.

## Describing voxel structures in text

For quick conversation, send top-view grids with surface heights and stair directions as above. For solid voxel shapes, send one x/z grid per y layer, lowest first. Use `#` for solid, `.` for empty, and give dimensions and cell size. Layers describe occupied volume; doors and passage connectivity need separate face or endpoint records.

For mixed-height surfaces, use a surface table. It avoids confusing a platform at height 2 with two solid cubes beneath it:

| ID | x | z | Kind | Low y | High y | Uphill direction |
| --- | --- | --- | --- | --- | --- | --- |
| A | 0 | 1 | Stair | 0 | 1 | North |
| B | 0 | 0 | Platform | 1 | 1 | — |
| C | 1 | 0 | Platform | 1 | 1 | — |
| D | 1 | 1 | Stair | 1 | 2 | South |

This equivalent JSON is an interchange example for discussion, not an existing game file format:

```json
{
  "units": "metres",
  "cell_size_m": 1,
  "axes": {"x": "east", "y": "up", "z": "south"},
  "footprint": {"width_m": 2, "depth_m": 2},
  "rise_m": 2,
  "clearance_above_surface_m": 2,
  "surfaces": [
    {"id": "A", "kind": "stair", "cell_xz": [0, 1], "from_y": 0, "to_y": 1, "uphill": "north"},
    {"id": "B", "kind": "platform", "cell_xz": [0, 0], "y": 1},
    {"id": "C", "kind": "platform", "cell_xz": [1, 0], "y": 1},
    {"id": "D", "kind": "stair", "cell_xz": [1, 1], "from_y": 1, "to_y": 2, "uphill": "south"}
  ],
  "route": ["A", "B", "C", "D"],
  "ports": [
    {"id": "entry", "position_xyz": [0.5, 0, 2], "outward": "south"},
    {"id": "exit", "position_xyz": [1.5, 2, 2], "outward": "south"}
  ]
}
```

Cell positions identify their northwest corner. A cell spans one metre east and south. Ports lie at the centre of the respective south edges. Rotate cells, ports, directions, geometry and clearance together. Platforms describe walking surfaces; their supporting geometry is a separate layer. At equipment scale the same notation uses `cell_size_m: 0.5`.

## Walking and service graphs

Use doors, landings, stair endpoints and room access points as walking-graph nodes. Add an edge only for an actual traversable connection. A room with multiple doors needs the internal costs between those doors; collapsing the entire room to a zero-cost node would distort distances.

Proposed edge weights are travel time: walking distance divided by movement speed, plus stair/climb time and, later, lift wait and travel time. All weights must be nonnegative. Compute shortest paths from building entrances and cache the resulting access distances. With multiple entrances, a virtual source with zero-cost entrance links gives the nearest entrance distance.

An entrance-distance cache helps accessibility and estimates; it cannot answer every bed-to-work or delivery trip. Keep local paths inside rooms and endpoint-to-endpoint searches for those trips. Refresh affected caches when a doorway, furniture obstruction, stair, access permission or relevant travel cost changes. Do not rebuild a whole city's paths for decorative edits.

Power, water, drainage, coolant, ventilation and signal each have typed ports and separate networks. A wire never grants walking access. Room and building summaries can aggregate service demand, but actual devices and connections remain editable and retain saved identities.

## Proposed technology progression

Materials, production capabilities and room functions are separate axes. A stone exterior can house modern equipment. Earlier structures remain useful when their capacity and services meet demand.

| Stage | Construction palette | Proposed enabling production | New decisions |
| --- | --- | --- | --- |
| Shelter | Sticks, leaves, rough logs | Gathering and hand assembly | Dry sleeping space, basic access and open stockpiles |
| Earth and timber | Earth walls, logs, simple clay products | Prepared earth and timber; small kiln for fired products | More durable enclosure and sheltered storage |
| Carpentry | Planks, beams, joined frames | Sawing and improved tools | Repeatable rooms, stairs and larger assemblies |
| Masonry | Stone and brick | Mining, dressing stone, firing bricks and binder production | Durable walls and heavier construction |
| Industry | Reinforced concrete, steel and sheet cladding | Metal processing, binder production and improved power/tools | Larger structures, service shafts and lifts |
| Advanced systems | Composite panels, glass and optional polymer components | Advanced manufacturing, energy and service networks | Automation and dense, serviced buildings |

This is a proposed gameplay sequence, not a mandatory historical chronology. Stone and timber can develop in parallel. Keep plastic as a possible component material; do not make “plastic house” the automatic superior successor to concrete. Cyberpunk and utopian cities remain possible art/technology branches, without committing to both.

Avoid a bootstrap dependency in which the first earth house requires a blacksmith or electrical supply that itself requires that house. Proposed early tools can be hand-made; a forge later improves tooling or unlocks a specific recipe. Electricity becomes necessary for devices that use it, such as the freezer, powered machinery, AC and lifts.

Storage is one continuing function across eras: open marked pile → covered pile → enclosed warehouse → warehouse with specialized services. Keep the current stone pile markers; the user's stick enclosure is a possible future variant. Metal sheeting changes the shell, while cooling or automation needs actual installed equipment. Track capacity, access and resource suitability separately from appearance.

## Proposed merging rules

1. **Join spaces:** adjacent compatible rooms may share a wall opening when the player connects them. Touching walls alone do not grant access, utilities or a higher tier.
2. **Group an assembly:** connected rooms become a named flat or building plan while retaining individual room, furniture and port identities. A group can later be edited or separated.
3. **Upgrade construction:** deliver materials and perform replacement work on the shell or equipment. Preserve occupants, inventories and links where compatible, and identify access/service interruptions before work starts.

For example, two huts can become one connected dwelling after a doorway is built. Adding a kitchen requires reachable furniture and its services. Replacing the walls with stone is a separate construction job. None of these actions produces a free room or duplicates resources.

## Management scales and automation

| Level | Player focus | Proposed automation boundary |
| --- | --- | --- |
| 0 | Equipment and 0.5 m subdivisions | Standard devices work by default; the player may edit ports and routed connections |
| 1 | Furniture and an individual room | Furnish from a pattern, then adjust individual objects |
| 2 | Neighbouring and stacked simple buildings | Construct the settlement from reusable rooms and explicit connectors |
| 3 | Flats and multi-storey buildings | Generate or copy assemblies, then inspect and alter their internals |
| 4 | Streets and the city | Place buildings and manage shared access, services and supply |
| 5 | Multiple cities | Manage exchanges and regional service limits; whole-city blueprints are not required |

These are simultaneous scales of attention, not six mandatory technology unlocks. As the settlement grows, standard construction should handle ordinary details automatically while allowing the player to inspect a particular room or coolant connection.

A building generator takes a footprint, height limits, required functions, entrance positions, material capabilities and available service connections. It places circulation first, rooms second, furniture and service routes third. Validate support, headroom, access, furnishing space and service feasibility before returning a plan. A saved seed makes a generated design repeatable. Failed constraints produce an incomplete or rejected proposal, never silently disconnected rooms.

Copying or generating a building creates a resource bill and construction jobs. The player can edit individual connections or accept a valid standard layout. Scaling to the city should aggregate unchanged building demand and route summaries; detailed local state remains available when needed.

Cars remain outside the proposed scope. A personal transit pass could eventually give residents access to connected lifts, pedestrian routes and metro-like infrastructure. The pass represents access; travel still requires stations, working connections and travel time. Freight and passenger logistics need separate rules, and are deferred.

## First implementation slice

Start with metric room volumes, the small connector, one validated clockwise stair, entrance alignment and roofs/supports that respond to stacking. Demonstrate 2 × 2 × 2, 2 × 3 × 2 and 4 × 4 × 3 m rooms without changing the world scale.

Then furnish one accessible sleeping room and connect it through a hall and stair to a second room. Verify an entrance-distance cache against actual paths, including a blocked doorway. Save, reload, rotate and copy the assembly while preserving endpoint identities and requiring a fresh construction bill. Only after this loop works should generation and a small material upgrade chain extend it.

Detailed stair geometry and clearance, the separate six-cell stair, exact wall thickness, doorway width, material costs, production rates, lift capacity and future-city style remain open. Keep persistent goals and the bottom instruction panel hidden. Future feedback belongs on selected objects or in the existing world interactions, with the shared UI point system; this proposal introduces no new in-game display.
