# Town — Foundation Specification

Status: design direction, subordinate to the current code and tests.

This document records agreed direction, not implementation status. [README.md](README.md), current code, and passing tests describe what is playable now. If this document conflicts with code, update this document; do not reintroduce removed behaviour merely to satisfy old prose. [GLOSSARY.md](GLOSSARY.md) records canonical terminology.

[WORLD_STREAMING_AND_PERSISTENCE.md](WORLD_STREAMING_AND_PERSISTENCE.md) governs the active semi-infinite world work. Its first surface milestone now provides 16×16 streaming chunks, deterministic seeded resources, chunk fog and grass, unbounded horizontal Citizen/camera movement, connected loaded-region navigation, unloading, and runtime state overlays. North/south biome latitude, disk-backed sparse saves, underground visibility, and forecasted outside-settlement simulation remain subsequent milestones.

## 1. Target first-playable scope

Biophilic design is an approach to architecture
The target first playable is a peaceful, vegetarian construction sandbox focused on gathering, crafting and growing a town, with original code and assets. This section is a roadmap; it does not claim every listed item is implemented.

Include first:

- Citizens with `Idle`, `Walk`, `Carry`, `Sleep`, and `FreeFall` states.
- Renewable bushes or wild crops that produce a single `Calories` resource.
- Bushes occupy one World Unit, have a small bounded deterministic offset, display ten berries, and grow in deterministic irregular patches rather than as independently scattered points.
- Trees that can be planted and cut into physical logs. The generator makes separated irregular forest patches, clear land, and one or two standalone Trees between forests rather than a uniform repeating scatter. Living Trees may initially appear as 1, 1.5, 2, 2.5, or 3-World-Unit growth stages. A fully cut rooted Stump regrows a one-World-Unit living Tree after three game days, then gains one World Unit per three-day step up to the strict three-World-Unit limit. A living Tree is a connected vertical stack with one log segment per World Unit and slight inherited deviation between segments. Roots cover the trunk entry at ground level. Internal caps between trunk segments are not rendered. Only the top segment has three or four branches plus smaller twigs branching from them. Several solid-green low-poly forms make its crown, with more crown forms on taller Trees. Trunk, branches, and crown sway as one connected assembly. Dead Trees use the connected trunk and top branches without greenery. Cutting is timed work shown by a reusable world-anchored Progress Bar. One completed work action removes the top visible segment and its crown, drops exactly one faceted physical Log built with the same tapered geometry as the trunk, and leaves the lower trunk without moving a replacement crown down.
- Palm Trees with a darker slightly bent connected trunk, a two-to-three-World-Unit height, and two irregular five-leaf layers. Palm leaves vary in angle, length, width, curvature, and starting height. Each elongated low-poly leaf has a rounded width profile and increasing downward sag toward the tip rather than forming one symmetric flower shape.
- Human-height cacti that store exactly one `Water` resource each.
- Square limestone formation patches with individual formations from one to three World Units tall.
- Logs and planks that remain physical world objects while loose, reserved, carried, or installed in a building.
- Player orders to gather, move, reserve, build, and reconstruct.
- Simple surfaces, supports, walls, rooms, and spatial storage.
- Construction Sites placed in the world.
- One starting Pile with a 2×2 footprint of four World Units, marked by small stones at its four convex outer corners and containing the six opening Logs. Its footprint is an explicit set of occupied cells, ready for a later expansion interface and connected non-rectangular shapes. A convex boundary vertex receives one stone; a concave notch does not, so a five-cell irregular footprint uses five stones while a 3×2 rectangle uses four. The current Pile has unlimited prototype capacity. Citizens carry harvested Calories and cut Logs to the nearest accessible footprint cell. Construction consumes Logs from the Pile. Water cannot enter an open Pile until a pottery or bottle vessel exists.
- Day/night directional light and a small number of dynamic local lights.
- Event-driven navigation and an early citizen-count stress test.
- A machine-readable observation and command interface.
- Runtime-session fog-of-war is revealed in a four-World-Unit area around every Citizen. A right-click whose cursor position is unrevealed always assigns `Walk`, even if its ray intersects a hidden object. Discovery is partitioned into streamed 16×16 chunks on a 0.5×0.5 grid; no fixed world-sized 128×128 mask remains. Coverage and rendered fog are binary. Disk persistence is not implemented.
- GPU-instanced grass rendered in 8×8 World-Unit chunks, using one upright camera-facing two-triangle billboard per tuft. A hard-cut shader draws four slightly capped blades on each plane and provides per-tuft variation and wind without creating separate blade geometry. Grass never casts a shadow. Scrambled two-dimensional Halton placement plus per-tile permutation, mirroring, axis swap, and shift prevent repeated diagonal rows without sacrificing even coverage. Bushes and grass claim mutually exclusive World Units: whichever greenery type already occupies a unit excludes the other, so grass never renders through a bush. Initial patches spawn fully grown with a maximum height near half the citizen's height. New growth may occur only along existing patch edges.
- Cloud geometry and its cellular terrain-shadow implementation are retained but currently disabled, keeping the opening view and fog-of-war navigation unobstructed. Clouds may return later as occasional weather or a source of rain rather than a constant opening-state effect.

Exclude from the first playable version:

- Combat, skeleton enemies, arrows, hunting, bulls, and antelopes.
- Traveler story, alien, aircraft, and vehicles.
- Individual food recipes and named dairy products.
- Thirst, integer health, prisons, and social-conflict simulation.
- Apocalypse and final-ending triggers.
- Full utilities, groundwater, caves, genetics, autonomous outside cities, and dynamic structural failure simulation.

These exclusions reduce the first implementation; they do not prohibit compatible foundations for later expansion.

## 2. Spatial glossary

### 2.1 World Unit

`World Unit` is the standard 1×1×1 construction space.

One World Unit contains exactly:

```text
2 × 2 × 2 Sub-Units = 8 Sub-Units
```

Updated 30 October 2026: one World Unit is 1 × 1 × 1 m, and each Sub-Unit is 0.5 × 0.5 × 0.5 m. A minimum room module is 2 × 2 × 2 m, rather than one World Unit. See [building measurements and progression](docs/BUILDING_MEASUREMENTS.md) for dimensions, remaining shell/clearance decisions, and the distinction from older room-relative prototype coordinates. This terminology update does not rescale existing assets or saves.

### 2.2 Sub-Unit

`Sub-Unit` is one of the eight equal volumes inside a World Unit. Its edge length is one half of a World Unit.

Sub-Unit coordinates inside a World Unit are integers:

```text
x: 0 or 1
y: 0 or 1
z: 0 or 1
```

Buildings and utilities may occupy one, several, or all eight Sub-Units.

### 2.3 Anchor Node

Each Sub-Unit has six sides. Each side has exactly one `Anchor Node`, positioned at the centre of that side.

```text
one Sub-Unit = six sides = six owned Anchor Nodes
one World Unit = eight Sub-Units = 48 owned Anchor Nodes
```

Two adjacent Sub-Units each retain their own Anchor Node on the shared side. The two opposing Anchor Nodes occupy the same face-centre position and may connect to each other, but they do not become one identity.

```text
48 logical Anchor Node identities
36 distinct face-centre positions inside one isolated World Unit
```

World Units have the same paired relationship at their boundaries. Anchor identity is based on the owning Sub-Unit's global coordinate plus its side direction. Coincident opposing Anchor Nodes form a connection pair.

Anchor Nodes are for solid, face-based attachment and alignment. They are not the path points of a free-hanging electrical cord.

### 2.4 Utility Port and Cord Path Point

`Utility Port` is a functional connection point belonging to a building, tool, or utility device.

`Cord Path Point` is a point belonging only to a flexible free-hanging cord path. A cord can sag or bend through Cord Path Points without creating structural Anchor Nodes.

This keeps structural attachment, functional connection, and flexible cord shape as separate concepts.

## 3. Construction and unrestricted stacking

The placement system does not forbid construction because a space is considered unsupported. Everything may have construction placed above it. The game should preserve player freedom instead of using structural validation as a placement boundary.

Supports, pillars, material strength, sway, and possible future failure may influence appearance or simulation later, but they do not prevent the player from placing a Construction Site.

### 3.1 Surface construction family

`Surface` is one construction family with two forms:

| Form | Walkable | May have construction above | Provides shade |
|---|---:|---:|---:|
| Hard Surface | Yes | Yes | Yes |
| Soft Cover | No by itself | Yes | Yes |

A Hard Surface may act as a floor, road, platform, ceiling, terrace, or roof according to context. Its material may be plank, stone, marble, concrete, or glass.

A Soft Cover may be cloth, hay, or another light material. A pergola is a Soft Cover combined with four corner logs.

#### Path Building family

The Building menu separates `Path` from Structure, Storage, and Livable construction. Every traversable surface exposes a movement cost even though Citizens never require a Road to navigate. Ordinary ground has cost `1.35`; a completed Road has cost `1.0`. A* therefore prefers a reasonably nearby Road, and Citizen movement over its segments is `1.35×` the ordinary-ground speed. A one-World-Unit wooden Road contains four Planks. Placing those four Planks as a Road above an existing four-Log Support reuses both structures and produces the same eight-part recipe as a Support Platform.

Rope Bridge and Suspension Bridge are draggable cardinal Path forms. The first endpoint and final endpoint are both included, so their minimum footprint is `2×1×1`. A Rope Bridge visually sags by as much as half a World Unit near its centre; this is deterministic presentation motion rather than unrestricted rigid-body physics. A Suspension Bridge remains tensioned and may rise slightly at its centre. Both are normal-speed Path surfaces once vertical route following exists. Their exact material quantities scale with resolved length and must be derived from final geometry instead of guessed here.

A Tunnel is also a minimum `2×1×1` draggable Path. It is a composite Construction Site instruction: remove each crossed Stone or Soil cube, retain the desired Path void, and install the Support geometry required to keep the cube above represented. The player could issue those operations separately, but Tunnel exists to avoid repeating the same excavation and Support clicks. Bridge height-following, tunnel excavation sequencing, and multi-level navigation are required before these entries become playable.

#### Storage Building family

The free Pile is a `2×2×1` surface footprint delimited by boundary stones. Its later resizing continues to use connected occupied cells, including non-rectangular shapes. Warehouse is a `1×1×1` Storage Building with one Door, three logically closed sides, and a covered interior. Its provisional recipe matches the Support Platform: four Logs and four Planks, with those Planks forming its hard floor/cover geometry. Adjacent Warehouse units whose Doors face the shared side merge into one logical Storage Building without changing their physical World Units.

#### Livable Building family

The first Small Livable unit occupies `1×1×1` and requires four Logs plus eight Planks. A standalone upper edge adds an automatic roof whose separate recipe is four Logs plus four Hay; when another compatible level covers it, contextual roof handling may reuse or return those materials. Adjacent Livable units connect when their Doors face the shared side, producing a single larger interior such as `2×1×1` without inventing a separate Building type. Grass collection produces Hay through three seconds of Citizen labour. Cactus collection remains three seconds of labour but Water still requires a vessel before it can enter Storage.

### 3.2 Pergola reconstruction

A completed pergola can be reconstructed into a `Support` building:

```text
Pergola = four corner logs + Soft Cover
Support = four corner logs
```

During this reconstruction:

- The Soft Cover material is extracted and returned as a physical resource.
- The four corner logs remain installed.
- Construction already placed above remains in place.
- The resulting Support continues to permit construction above.

Reconstruction should reuse installed components whenever their material and destination remain compatible.

### 3.3 Direct deletion and structural preservation

`Backspace` is the direct removal command for a selected constructed Building, regardless of whether the player or another settlement created it. Naturally generated Trees, Palms, plants, stone formations, and loose resources are excluded: a direct deletion attempt shakes the selected object and leaves it intact, because their normal Citizen work must still be used.

When the selected Building has no construction depending on it from above, it collapses and disappears. When occupied construction above depends on the selected World Unit, removing the lower Building must preserve that upper structure:

- Functional extras of the removed Building disappear, including walls, room enclosure, and its living condition.
- The removed World Unit is replaced by four vertical corner Support poles.
- Construction above remains in place and supported.
- If the replacement cannot be resolved without invalid geometry, deletion is refused and the selected Building shakes.

The present flat Support-only prototype implements direct removal, immediate return of every installed Log as a loose Physical Resource inside the removed World Unit, and natural-object refusal. Dependency replacement waits for multi-level occupancy and component data.

### 3.4 Incremental building upgrades

Building upgrades reuse every compatible installed component and request only the missing resources. They create a Construction Site on the existing Building rather than charging for or rebuilding its complete recipe.

The first upgrade chain is:

```text
Support
  + four Planks
  -> Support Platform

Support Platform
  + missing enclosure and roof components
  -> Livable House
```

The Support-to-Platform Construction Site uses the same four short branch assignment handles at the corners of its ground footprint, even when the cube being upgraded is elevated. A Livable House conversion may request hay or finished roof tiles according to the chosen roof recipe; raw clay does not substitute for tiles. Its exact wall and roof quantities must be derived from the final geometry instead of invented in advance.

This upgrade chain is a design contract until Planks, roof resources, component recipes, and multi-level construction are playable.

### 3.5 Free relocation of constructed cubes

Moving an already constructed Building cube is a direct layout operation and requires no Citizen labor:

1. Select the Building.
2. Click and drag it to a destination.
3. While holding it, use `<` and `>` to move the destination one vertical level down or up.
4. Release to place it at the resolved World Unit, including a level that replaces compatible existing structure.

The interaction should feel like arranging physical blocks on a table. Placement collision and replacement rules must be resolved before the drop commits; an invalid drop returns the cube to its origin without consuming resources. This remains deferred until the prototype has vertical Building occupancy.

### 3.6 Selected-building hotkey hints

A selected unfinished Construction Site shows a compact hard-pixel tooltip beneath its projected footprint. The rotation hint contains only a clockwise circular-arrow icon and the `R` key. Pressing `R` rotates the planned Building clockwise by one quarter-turn. `Shift+R` performs the same action counterclockwise, but the modifier is intentionally absent from this immediate hint; advanced players may discover it or inspect it later in configurable controls. Installing the final required material hides the rotation hint and locks the completed Building at its last construction-stage orientation. Selecting a completed Building never restores the rotation option.

### 3.7 Persistent Edit Mode and deconstruction control

Clicking the top-toolbar Building icon enters persistent Building Mode and leaves that icon in its filled state. The bottom Building menu ends with a `Remove building` tool whose icon is a dotted outline of the standard five-edge Building form. There is no separate top-toolbar removal control. Clicking `Remove building` activates a persistent removal tool without requiring a Building to be selected first. Hovering a removable Building temporarily presents its currently installed geometry as a 50%-opaque brown removal ghost with no shadow, showing the space that will become empty after the click. Brown belongs to removal; gray remains reserved for a future Construction Site plan. Clicking the brown Building removes it immediately and drops every installed Physical Resource on the floor inside the same World Unit. Resources merely reserved or carried toward an unfinished Construction Site return through their existing Citizen cancellation path and are not duplicated. `Backspace` on a selected Building invokes the same guarded removal and resource-return operation. Leaving Building Mode clears its hover ghost and restores the hollow Building icon.

### 3.8 Greenery Mode and re-rooting

The top toolbar places a Tree icon directly beside the Building icon. It enters Greenery Mode without exposing a separate bottom catalog. A player selects one Bush or rooted Tree Stump, then clicks a revealed, loaded, empty World Unit to move and re-root it. Relocation preserves the Permanent Detail Seed, Berry cooldown, Tree type, and growth timer. It cannot target fog, unloaded terrain, Piles, Buildings, other resources, or excavated ground. Moving generated greenery records removal of the seeded original and retains the relocated object as player-authored runtime state, preventing a duplicate from appearing when its source chunk reloads. Disk persistence remains deferred.

### 3.9 Landscape Mode and Soil Blocks

The top toolbar places an outlined dirt-pile-and-shovel icon beside Greenery. It fills with colour while Landscape Mode is active and opens a two-tool bottom menu. `Remove soil block` removes either an authored Soil Block or the clicked implicit base terrain cube. `Add soil block` restores a removed base cube, places a Soil Block on ordinary exposed Sand, or attaches one to the exposed face of an authored Soil Block. The vertical coordinate contract is `0` through `255`.

Landscape edits are immediate and stored only as sparse changed coordinates: untouched terrain continues to come from the deterministic base world, and the runtime does not allocate a 256-cube column at every horizontal coordinate. Added Soil Blocks have collision and a height-zero block obstructs surface navigation. Structural falling, recovered Soil Physical Resources, Citizen excavation labour, multi-level underground excavation, vertical Citizen traversal, authored-block chunk unloading, and disk persistence remain later systems. The retained `ExcavationSite` experiment is not exposed through the current player menus.

## 4. Building appearance system

Building appearance has two independent sources of variation:

1. Player-cycled `Cosmetic Variant`.
2. Contextual vertical appearance such as ground base, middle level, and roof level.

### 4.1 Cosmetic Variant

Every placeable building or tile must provide at least three appearance variants:

```text
Variant 1 → Variant 2 → Variant 3 → Variant 1
```

Placing the same building over a compatible completed building cycles the Cosmetic Variant immediately.

Cycling a completed building:

- Uses no resources.
- Creates no Construction Site.
- Creates no citizen job.
- Has no construction delay.
- Does not change functionality, collision, capacity, occupancy, or connection points.

### 4.2 Permanent Detail Seed

Each built element receives a deterministic `Permanent Detail Seed`. It may adjust safe visual details such as:

- Log bend or rotation.
- Plank spacing and small offsets.
- Wear, colour variation, and minor surface irregularity.
- Idle-motion phase.

The seed does not alter logical geometry. Mesh replacement must be atomic, and generated parts must avoid duplicate coplanar surfaces so cosmetic cycling does not produce z-fighting.

### 4.3 Persistent ground-base appearance

When a building is first completed directly above soil, it receives:

```text
has_ground_base = true
```

This value remains true even if the soil is later excavated or replaced. The building keeps the visual history of having been built at ground level.

Ground-base treatments may include pavement, a plinth, arches, different lower walls, larger or more open windows, or other lower-level details. Every ground-base treatment still supports the three Cosmetic Variants.

### 4.4 Middle and top appearance

Contextual appearance is layered rather than stored as one mutually exclusive building type:

- `Ground Base`: persistent historical treatment assigned at completion.
- `Middle`: used for repeated levels that have construction both below and above.
- `Top`: used for the highest occupied level below an exposed roof.
- `Roof Form`: for example flat or diagonal.

A one-storey building may show both its persistent Ground Base and its Top/Roof treatment. A four-storey building may resolve visually as:

```text
Level 4: Top + Roof Form
Level 3: Middle
Level 2: Middle
Level 1: Ground Base
```

Middle and Top roles may update when construction is added or removed above. `has_ground_base` does not update.

The final visual resolver therefore uses approximately:

```text
building family
+ material
+ has_ground_base
+ current vertical context
+ roof form
+ Cosmetic Variant
+ Permanent Detail Seed
```

### 4.5 Initial colour palette

These are the authoritative starting colours for landscape and early construction. Runtime states may derive lighter or darker versions from them, but individual visual scripts should not substitute unrelated hard-coded colours. Presentation uses binary coverage: a pixel may be fully present or fully absent, never fractionally transparent.

| Use | Hex colour | Code constant |
|---|---|---|
| Wooden roof | `#A85C5C` | `WOODEN_ROOF` |
| Logs used for roofs and early supports | `#E08160` | `ROOF_LOG` |
| Home entrance and doorway | `#7F4645` | `HOME_DOORWAY` |
| Sand surface | `#FEF1CF` | `SAND_SURFACE` |
| Bushes | `#799369` | `BUSHES` |
| Grass | `#93B580` | `GRASS` |
| Hay field | `#FFC471` | `HAY_FIELD` |
| Cactus | `#B1C070` | `CACTUS` |
| Palm trunk | `#8F523E` | `PALM_TRUNK` |
| Palm upper leaves | `#4F713B` | `PALM_LEAF_LIGHT` |
| Palm lower leaves | `#284735` | `PALM_LEAF_DARK` |
| Limestone top | Same current colour as Sand | `LIMESTONE` aliases `SAND_SURFACE` |
| Limestone side reference | `#EEBF8A` | `LIMESTONE_SIDE` |
| Pine wood | `#8B5E45` | `PINE_WOOD` |
| Fog and standard-surface shadow | `#9D9580` | `FOG_AND_SHADOW` |
| Clouds | `#FFFFFF` | `CLOUD` |
| Citizen skin | `#3A1F1F` | `CITIZEN_SKIN` |
| Woman clothing | `#E18074` | `WOMAN_CLOTHING` |
| Metal tools | `#4B7781` | `TOOL_METAL` |
| Hair | `#000000` | `HAIR` |

Bushes, living Tree crowns, and grass use unshaded solid-colour materials, so their green surfaces do not receive smooth lighting gradients. Each living Tree crown or Bush deterministically selects one complete-object colour from the closely related exact-hex `GREENERY_VARIANTS` palette; this adds separation inside dense greenery without runtime randomness or additional save data. Bushes retain geometric cast shadows; grass communicates volume through its silhouette and never casts a shadow.

Sand, greenery, and snow surfaces share `FOG_AND_SHADOW` as the authoritative shadow colour. Fog uses that exact colour as well. Directional soft-shadow filtering is disabled. Standard terrain materials threshold the DirectionalLight attenuation: each fragment resolves to exact surface colour or exact `FOG_AND_SHADOW`, never a feathered or accumulated intermediate. World geometry feeds this binary shadow result, so overlapping casters cannot multiply darkness. The retained terrain shader also supports cellular cloud shadows, but that path is currently disabled with the hidden cloud layer. Living and Dead Tree trunks and loose Logs explicitly cast geometric shadows. Their wood shader thresholds face direction into exactly two colours: `ROOF_LOG` and one derived darker form. Citizens use a separate opaque circular contact disc and do not cast stretched dynamic body shadows; the disc remains circular at morning and evening because it represents contact with the ground rather than the sun's projected direction.

The presentation intentionally uses a low-resolution retro-3D treatment: 3D and screen-space anti-aliasing are disabled, and the completed frame is sampled in hard 2×2 nearest-neighbour pixel blocks. Pixel colours must remain distinct rather than being softened across edges.

### 4.6 In-game Building Constructor

The long-term asset workflow includes an in-game `Building Constructor`; it is not dependent on the player or developer operating an external 3D modelling tool.

- The game begins with authored Building shapes that establish its visual identity.
- A player may later open one of those Buildings and edit its physical composition down to World-Unit and Sub-Unit placement.
- A custom construction can be saved as a reusable prefabricated Building.
- Its recipe is derived from the actual physical parts placed in the constructor. If the design contains seven Logs and five Planks, every constructed instance reserves and consumes exactly seven Logs and five Planks.
- Saving a prefab stores logical parts, transforms, material types, ports, and grouping. It does not flatten the result into an opaque decorative mesh.
- Editing a prefab must preserve the distinction between changing the reusable definition and customizing only one placed instance.

An experimental Building Constructor is entered with `F2`. It edits canonical Sub-Units, supports Block, Log, and Plank parts, switches between gray edit mode and material preview, derives a resource recipe, and reads or writes human-readable Version 2 `.pyrbuilding` JSON. That file is authoritative for Building meaning; a neighboring named-part OBJ is authoritative for editable runtime vertices. Multiple World Units and multiple logical parts inside one Sub-Unit are supported by the format. Free endpoint manipulation inside the game, nested grouping, and player-facing sandbox access remain deferred.

## 5. Citizen movement and animation

The implemented Citizen presentation states are:

```text
Idle
Walk
Carry
Sleep
```

`FreeFall`, `StairsUp`, and `StairsDown` remain deferred until matching movement exists:

```text
FreeFall
StairsUp
StairsDown
```

The initial citizen silhouette has legs occupying approximately half the full body height, with the torso beginning at the hips and the head above it. Each arm has upper-arm and forearm segments joined at an elbow, and each leg has thigh and lower-leg segments joined at a knee. The woman body uses a symmetric guitar silhouette with broad hips, narrow waist, and smaller upper torso; it does not use separate breast meshes. The man body uses an inverted-pear silhouette with shoulders wider than hips. Skin and limbs use solid unshaded `CITIZEN_SKIN`, hair is solid black, men wear yellow shorts, and women wear `WOMAN_CLOTHING` skirts. Future held metal tools use `TOOL_METAL`. Citizens have no default hat; future profession appearance must not leak into the neutral citizen model.

Citizen selection has priority over overlapping world resources. A click selects one citizen, a left-button drag selects every citizen inside the screen rectangle, and empty-ground click deselects all. Every selected Citizen displays an exact two-pixel solid `#FFFFFF` screen-space line projected from a 16-sided horizontal world circle. Its `0.3168`-World-Unit radius is 66% of the previous `0.48` radius. The overlay renders above world geometry so pale terrain, grass, and nearby plants cannot hide it at Town zoom. Selected non-Citizen objects use separate white frames around the top and bottom of their visual bounds; the four vertical connecting bars are intentionally hidden so a tall Tree does not read as a wireframe cage. A group movement order routes every selected Citizen independently into a compact non-overlapping slot inside the same clicked World Unit. Compact lane offsets also separate intermediate route points so Citizens do not deliberately occupy one walking coordinate.

Selecting one or more Citizens enters `Citizen Mode`, parallel to the explicit state used for Building interaction. Citizen Mode remains active while its selection is nonempty and is the context in which right-click movement and work assignments are interpreted. Clearing selection returns to Command Mode, while selecting a Building transfers to Building Mode. The exact future Citizen task menu is deliberately unresolved. One selected Citizen has no numerical badge. For two or more selected Citizens, a red fully rounded badge written conceptually as `(3)` shows the selected count. A one-digit count is exactly 18×18: its horizontal and vertical minimum dimensions are identical, so it cannot become a vertical pill. Multi-digit counts retain the 18-pixel height and circular end caps while expanding only horizontally. The rounded-rectangle badge written conceptually as `[3]` is reserved for goods, building materials, or building quantities and must not be reused as the citizen-selection badge.

The Building icon and `B` key enter or leave persistent Building Mode and reveal a bottom-centred Building menu. Its first row orders Path, Storage, Livable, then the retained Structure family; its second row shows that family's Building entries followed by `Remove building`. Structure currently exposes the playable Support. Path displays Road, Rope Bridge, Suspension Bridge, and Tunnel; Storage displays Pile and Warehouse; Livable displays Small Home. These new family entries remain visibly disabled until their physical resources, generic Construction Site labour, and required navigation layers exist. The Support entry uses a hard-pixel miniature of the actual completed four-post structure on one isometrically projected Sand World Unit, framed like the closest permitted world-camera view rather than represented by an abstract glyph. Choosing Support begins placement and displays a 50%-opaque completed-Support preview snapped to the pointer before the click commits. Gray means that all four horizontal 0.5×0.5 footprint quadrants fit. If placement is invalid, the Support and each obstructed quadrant turn red without displaying a world-space explanation label. Preview and click use the same placement evaluation. The four footprint quadrants describe the bottom faces of four Sub-Units; they do not redefine the canonical eight-Sub-Unit volume of a World Unit. The current Support Construction Site creates four short faceted wooden assignment stakes beyond its footprint corners immediately on placement. Each stake is planted into the terrain, rises more than 0.3 World Units, and leans farther outward. They use the same trunk colour, hard facets, two-tone wood shader, and shadow behaviour as Trees, loose Logs, and installed Support posts. These stakes remain visible outside Building Mode until construction finishes, so the player can select a citizen and right-click the site to assign that specific citizen. Selecting the unfinished site enters Building Mode, reveals the bottom Building menu, restores every uninstalled post as a 50%-opaque gray plan, and applies the shared white selection outline to the complete future bounds rather than only the short stakes or already-installed Logs. Placement never recruits the nearest citizen automatically. Installed construction remains visible in every mode. Empty-ground click, Escape, or a right-button click without a camera drag leaves Building Mode; holding and dragging the right mouse button rotates the camera instead of cancelling.

The older Citizen-driven `ExcavationSite` experiment remains retained but is not exposed in the player Building catalog. The playable Landscape Mode now performs direct World Unit addition and removal for prototyping. Whether later Citizen excavation produces a carried Soil Physical Resource remains deliberately undecided, so direct Landscape editing currently creates no material output.

With one or more Citizens selected, right-clicking a living Tree, Dead Tree, or Palm assigns persistent Woodcutting. Every remaining physical Log segment exposes one independent resumable work slot, so `Tree 3/3` accepts at most three simultaneous Citizens, `Tree 2/3` accepts two, and `Tree 1/3` accepts one. Each assigned Citizen walks to an available neighbouring World Unit, faces the target, produces a low-poly axe from their pocket, and makes exactly three visible chop arcs over three seconds. The slots do not combine their applied seconds into one accelerated job: every completed slot removes one highest remaining segment and creates one loose faceted Log. The completing Citizen picks up that Log, returns it to the Pile, and chooses the nearest visible Tree with a free segment. When the selected group exceeds the clicked Tree’s free slots, remaining Citizens select the nearest visible Trees with free Log segments. Each segment retains target-owned interruption and resume state. Simultaneous slot bars are vertically offset rather than occupying the same pixels. The applied-labour bar is eight pixels high: a four-pixel coloured interior plus a two-pixel white outline above and below matching the custom cursor. It fills horizontally from left to right and uses small rounded corners rather than a sharp rectangle. The coloured fill is confined to the inner rectangle and the white outline is drawn last, so even completed labour cannot cover the border. The entire bar pivots around its centre and leans by at most two degrees toward the screen side occupied by the directional sun; its lean reverses as the sun moves to the opposite side. Its width is eight pixels per required simulation second, so a three-second job is 24 pixels wide and a six-second job is 48 pixels wide. A three-segment Tree advances through `Tree 3/3`, `Tree 2/3`, and `Tree 1/3`; only the third completed slot replaces the final segment with the short rooted stump. Removing the original top also removes its crown, branches, or Palm leaves without generating replacement top geometry on the lower trunk. Harvested lower trunks do not resume growth until fully cut into a Stump. That Stump then regrows at the three-day cadence. Each drop direction is deterministic and selects the Log's cardinal axis; continuous falling-body physics is deferred.

Bush gathering uses the same persistent assignment contract. The Citizen works beside the target for three seconds while the shared applied-labour bar fills, carries a three-red-berry representation back to the Pile, stores one `Calories`, and chooses the nearest visible harvestable Bush. Applied labour belongs to the target and work kind rather than to the actor or tool: interruption preserves the accumulated seconds, keeps the bar visible for two simulation seconds, then hides it until any actor resumes the same job from its remaining time. A completed bush harvest hides every red berry dot while retaining the green bush and starts a two-game-day regrowth timer. With the current 360-simulation-second Day, berry regrowth takes 720 simulation seconds. Cacti retain one stored `Water`, but collection is blocked until a vessel exists because an open Pile cannot store Water. Separating collected food from eating is deferred.

A right-click on one Support Construction Site assigns persistent construction. The Citizen withdraws one Log at a time from the Pile, installs it, and continues through the nearest visible unfinished Support sites. Completing every site ends the assignment successfully. Finding no stored Log clears the construction assignment and switches the Citizen to `Idle` with the material-shortage status.

The selected unfinished Construction Site displays a three-line Construction Inspector above its complete planned form. The first line is the Building name. The second is one total-labour progress bar. The third is a horizontal list of Full Scale Icon Numbers formatted as installed/required, such as a Log icon followed by `1/4`. Each material defines its own installation seconds. Total labour is the sum of `required quantity × installation seconds` for every recipe material, and the shared eight-pixels-per-second bar scale determines width. A four-Log Support therefore requires `4 × 3 = 12` seconds and receives a 96-pixel bar. For comparison, `2 Hay × 2 seconds + 3 Stone × 4 seconds` is 16 seconds and receives a 128-pixel bar. Installed materials contribute their complete installation time; partially applied active jobs contribute their retained partial seconds. While the site remains selected, its aggregate bar replaces every per-Citizen progress bar targeting that site without changing how Citizen labour is applied.

Night pauses execution rather than deleting intent. At sunset each Citizen interrupts applied labour, pauses any route, hides active tool motion, and lies horizontally on the ground with a small breathing movement. Current cargo, route, persistent work assignment, and target-owned partial labour remain intact. At sunrise the Citizen stands, resumes the interrupted route or labour, or searches again for the next target belonging to the persistent assignment.

Every traversable surface World Unit exposes eight movement neighbours: north, north-east, east, south-east, south, south-west, west, and north-west. When both target coordinates differ, the route uses a direct diagonal centre-to-centre step instead of alternating cardinal steps into a ladder pattern.

Citizen collision is a navigation policy separate from the interaction hitbox used to click a world object. Living and Dead Trees, Palm Trees, and Stumps are passable. Cacti are passable Soft Obstacles with travel cost `3.0`, so A* avoids them when a reasonable alternative exists but can cross them when necessary. Limestone, Bushes, excavated void cells, surface-level player-authored Soil Blocks, Piles, and future Warehouse wall faces are Hard Blockers. The implicit generated Sand surface and future Warehouse Door face are passable. A path is requested only when an order changes. Work orders still choose a reachable neighbouring World Unit when the target itself should not be occupied. Diagonal movement is rejected when it would cut between two blocking corners. Navigation is constrained by the connected loaded-chunk region rather than a fixed world edge. Its weighted-cell contract is implemented now: normal ground costs `1.35`, Road costs `1.0`, and Road walking speed uses the inverse ratio; Soft Obstacle cost affects route choice without changing physical walking speed.

Normal collision must never create a permanent Citizen prison. If a requested order starts from a World Unit with no legal neighbour, normal A* first reports the enclosure. The Citizen then waits two simulation seconds and follows an Emergency Escape route that is allowed to phase through the enclosing blocker. This narrow fallback applies only to an actually enclosed starting position, not to an ordinary route separated by a wall. It represents later context-sensitive crawling, climbing down, controlled falling, or phasing until multi-level landscape navigation can choose the physical recovery animation. The current flat prototype implements phasing and records `emergency_escape` on the task. No completed Road is player-placeable until the Plank resource chain and generic construction labour are implemented.

The Town Mode camera begins centred on the first citizen but is independent after that point. Its default orthographic view is the maximum zoom-out and shows 34 World Units vertically, twice the 17-World-Unit original close view. Mouse-wheel and trackpad scroll continuously select a framing between those exact limits; no farther zoom-out is permitted. Zoom is handled before ordinary UI input so a non-scrolling interface Control cannot swallow the camera command. WASD pans across the playable area at a speed proportional to the current zoom; selection and movement do not force the camera to follow a citizen. Clicking the Population icon is an explicit exception: successive clicks cycle through every living Citizen in spawn order, wrap from the last to the first, and smoothly focus the target at the 17-World-Unit maximum zoom while retaining current yaw and elevation. Transition duration scales linearly by world distance from 0.1 seconds nearby to 0.5 seconds at one maximum-zoom screen width or farther. Holding and dragging the right mouse button horizontally rotates it through 360 degrees. Vertical right-button drag changes elevation by at most ten degrees above or below the default isometric elevation, never near enough to become parallel with the ground. The bottom-right compass remains physically parallel to the ground and renders at a 72-pixel diameter. Its darker cylindrical side wall is three times the earlier height, and the `WOMAN_CLOTHING` North and `TOOL_METAL` South triangles sit substantially below the raised rim. Its 50%-transparent white sun reflection spans the compass diameter, widens toward roughly one third of the face near morning and evening, and narrows near midday. Hover or keyboard focus uses the current 3D viewing direction and surface normals to generate a fixed-width white silhouette; it must not substitute a circular 2D border. Clicking the compass preserves the current world focus and uses a half-second cubic ease-in/ease-out transition along the shortest yaw path to restore default yaw, elevation, and 34-World-Unit zoom. Manual pan, rotation, or zoom cancels an active camera transition immediately. Normal depth testing, rather than a manual z-index override, determines whether a tree or Building is in front from the current view.

One Day lasts 360 simulation seconds: 360 real seconds at `1×`, 180 at `2×`, or 90 at `4×`. The sun travels from the eastern horizon through overhead noon to the western horizon, then below the world for the night half. A top-centred rotating wheel has a yellow Day half, an empty Night half with no moon, and a fixed sun marker above it. The Day counter increments after every complete cycle. Morning gradually changes from light blue to the yellowish Day palette. Evening gradually changes from the Day palette through red to the blue Night palette. Sun energy, sky, fog, terrain, and shadow colours interpolate through these stages instead of changing at one horizon frame.

Limestone remains visually related to its surrounding sand: it is a slightly darker pale sand colour by Day and follows the active terrain hue into blue-gray at Night. A restrained night emission floor preserves its form when direct sun is absent without making it appear self-luminous.

The current surface is horizontally streamed without a fixed Citizen or camera boundary. Navigation remains limited to the connected loaded-chunk region; an unreachable or not-yet-loaded destination resolves to the nearest reachable loaded cell or reports that no route exists.

Each locomotion animation stores its reference speed and stride length. Animation playback derives from actual path movement so an animated step covers approximately the same world distance every time.

Citizens may traverse most natural terrain. Traversal normally changes cost rather than acting as a binary prohibition:

- Flat ground: normal speed.
- Moderate slope: slower.
- Shallow water or irrigation channel: passable but slower.
- Loose soil: slower.
- Enormous or near-vertical cliff: blocked.
- Missing supporting surface: FreeFall.

Stairs and bridges improve movement but are not mandatory for every small elevation or shallow channel.

### 5.1 Deferred elevators and crowd movement

An `Elevator` is a later Building and is not part of the first playable scope. An Elevator requires an `Elevator Shaft` that occupies one World Unit in width and depth and spans at least two World Units vertically. The minimum useful Elevator connects the first and second Floors; a taller Elevator may connect additional Floors.

Elevator routing is based on estimated arrival time rather than vertical distance alone. A Citizen may keep walking or use nearby stairs or a ladder when that route is expected to arrive sooner. A Citizen may instead use an Elevator when walking to another vertical route would take longer. The estimate must include walking to the Elevator, waiting for the Elevator Car, riding, and walking from the destination Floor. Route planning must not assume that entering an Elevator is instantaneous.

Using an Elevator requires explicit simulation state:

1. A Citizen walks to the call position for the current Floor.
2. The Citizen requests the Elevator and waits if the Elevator Car is elsewhere.
3. The Elevator Car arrives if it can accept the request.
4. The Citizen boards when capacity is available.
5. The Elevator Car travels to the requested Floor and the Citizen exits.

The standard one-World-Unit Elevator Car has a provisional capacity of four Citizens, corresponding to four standing Sub-Unit positions across its floor. When the Elevator Car is full, it does not stop merely to collect more waiting Citizens. A full Elevator must still complete the destination stops requested by Citizens already inside it. Waiting Citizens retain their request for later service. Scheduling details beyond these rules remain deferred until the Elevator is prototyped and stress-tested.

Citizen bodies do not form permanent navigation obstacles for one another. Citizens may temporarily pass through or occupy the same Sub-Unit so a dense crowd cannot deadlock pathfinding or overwhelm the navigation service. If many idle Citizens occupy the same destination, a low-frequency crowd-settling process gradually moves them into comfortable nearby free Sub-Units. This makes even an accidental stack of 100 Citizens recover by spreading over time rather than requiring 100 simultaneous collision-driven path calculations.

A group movement order places every selected Citizen inside the one clicked destination World Unit, using compact distinct surface slots so they do not finish on one identical point. Every Citizen receives an independent A* route from its own current position. The command does not preserve the starting formation as parallel destination World-Unit offsets. Temporary overlap remains an emergency safeguard, not the normal result of a group order.

Horizontal moving carts may later reuse parts of the stop, capacity, queue, and boarding model. They remain an alternative transport direction rather than a committed Building family.

## 6. LLM observation and control interface

The LLM does not require a continuous 3D video feed. Its authoritative view is structured text data.

### 6.1 Observation rate

Default LLM observation rate:

```text
0.5 observations per second = one observation package every 2 real seconds
```

This rate is independent of rendering FPS and simulation tick rate. An automated test may instead pause the simulation and advance an explicit number of ticks after each command.

Each observation package contains either:

- A requested regional or layered snapshot.
- A delta since the previous acknowledged observation.
- Recent events and command results.

Periodic checksums and full snapshots allow the client to recover if it misses a delta.

### 6.2 Required readable state

The interface must expose stable Entity IDs and sufficient information to reason about:

- Terrain, cliffs, slopes, caves, and empty space.
- World Unit and Sub-Unit occupancy.
- Buildings, Construction Sites, materials, and completion state.
- Citizens, current actions, carried resources, and destinations.
- Loose and reserved physical resources.
- Anchor Nodes, Utility Ports, ladders, supports, doors, and routes.
- Utility networks when those systems are implemented.

Cells reference Entity IDs; entity details are stored once rather than copied into every cell.

### 6.3 Required command input

The first command vocabulary should support:

```text
query_region
query_layer
query_entity
query_route
place_construction_site
place_ladder
place_support
connect_buildings
cancel_construction_site
set_job_priority
advance_ticks
```

A placement command needs explicit coordinates and orientation. A high-level command may request a result, but the LLM must be able to inspect the proposed plan before confirming it.

Example shape:

```json
{
  "command": "place_construction_site",
  "building_type": "support.basic.wood",
  "origin_world_unit": [12, 4, -8],
  "occupied_sub_units": [[0, 0, 0], [0, 1, 0]],
  "rotation_quarters": 1,
  "cosmetic_variant": 2
}
```

The interface is also the foundation for automated QA, headless stress tests, and later autonomous outside settlements.

## 7. Utility capacity and visual scaling

`Capacity Grade` is written as 1×, 2×, 3×, or 4×. It describes how much service a utility segment or device can carry or provide. It does not always mean that the visible object becomes two, three, or four times wider.

Each utility family defines its own allowed grades and visual growth rule:

| Utility family | Allowed grades | Visual growth | Colour |
|---|---|---|---|
| Flexible electrical or signal cord | 1×, 2×, 3×, 4× | Remains thin; higher grades become only slightly thicker | Black |
| Cold-air ventilation duct | 1×, 2×, 4× | Cross-section grows substantially; 2× is rectangular and 4× may fill one Sub-Unit | Silver metallic |
| Natural-gas pipe | 1×, 2×, 3×, 4× | Circular diameter grows with grade | Yellow |
| Water pipe | 1×, 2×, 3×, 4× | Circular diameter grows with grade | Not assigned yet |
| Drainage pipe | 1×, 2×, 3×, 4× | Circular diameter grows with grade | Blue |

The Black Cord is a line or small bundle, not a large pipe. A 2× Black Cord occupies almost the same space as a 1× cord, with only enough extra thickness to communicate its greater capacity. A 3× or 4× cord continues the same restrained growth instead of expanding like a ventilation duct.

Ventilation intentionally skips 3× because filling three quarters of a square cross-section produces an unwanted L-shaped form. Its visual progression is:

```text
1× small duct → 2× rectangular duct → 4× full square duct
```

Gas, water, and drainage use continuously larger circular diameters. Their visual diameter curve is configurable and need not follow a physically exact area calculation, but each grade must remain recognisable.

Flexible Black Cords use Utility Ports and Cord Path Points. They do not consume or create structural Anchor Nodes merely because they sag through free space.

### 7.1 Satellite dish

The `Satellite Dish` is a later Utility device for televisions. It may mount on a wall or roof.

```text
1× Satellite Dish = capacity for 1 television
2× Satellite Dish = capacity for 2 televisions
4× Satellite Dish = capacity for 4 televisions
```

Each connected television consumes one unit of dish capacity. The larger dish variants may visibly grow, but their mount and cable connections remain separate Utility Ports.

The Satellite Dish is recorded for future compatibility and is not part of the first playable scope.

### 7.2 Connection state without persistent panels

Copied flats and prefabricated Buildings must communicate missing Utility connections in the world itself. The game should not require a persistent needs panel for every room.

Shared rules:

- A connected, actively working Utility is visually `Alive`: its expected motion runs and its material uses the normal bright colour.
- A disconnected or unpowered Utility is visually quieter and darker.
- Hover text names the missing input, such as `Missing electricity` or `Missing cold air`, but the physical cue remains understandable without hovering.
- Diagnostic effects occur at restrained intervals. A fault must not resemble a fully working continuous flow.
- Copying a flat preserves its required Utility Ports. At the destination, only unsatisfied ports display their local connection request.

Family-specific cues:

| Utility | Working cue | Missing or disconnected cue |
|---|---|---|
| Cold-air outlet | A small paper strip lifts and streams in the outlet airflow | The strip hangs flat with only occasional subtle ambient movement comparable to grass |
| Water pipe | Normal contained motion at an active device | A restrained water droplet at the open or missing connection point |
| Electricity | Powered tools are brighter and visibly active | An occasional short zap at the unsatisfied electrical connection, never a continuous working effect |
| Fridge, AC, and other machines | Bright normal colour plus device-specific vibration or motion | Darkened material, reduced motion, and hover text naming the missing Utility |

The paper strip, droplet, and zap are presentation components driven by one authoritative connection state. They must not implement their own connection logic.

### 7.3 Minimal global controls

The normal game view uses no opaque top navigation background. A Population indicator occupies the top-left corner, while compact controls occupy the top-right. Design terminology remains precise in this specification, while player-facing labels use the shorter text recorded in the UI text catalog:

An `Icon Number` is the shared icon-plus-number control used for quantities and installed/required fractions. Its Standard form remains fixed at the same 44×44 icon size as the Building and Quit toolbar controls, independently of camera zoom. Its Full Scale form keeps the icon visually tied to world scale: the icon is 1× at the 34-World-Unit maximum zoom-out, grows continuously to 2× at the 17-World-Unit maximum zoom-in, and leaves the number font unchanged. Its Compact form leaves both icon and number typography at smaller fixed UI sizes. The Population indicator uses Standard, selected Construction Site materials use Full Scale, and every selected-Pile resource card uses Compact. New icon-plus-quantity readouts must reuse this component rather than assembling separate icon and label controls.

- A black Citizen silhouette followed by a number reports the total simulated Population through a fixed Standard Icon Number. Its 44×44 icon matches the Building and Quit toolbar buttons and never responds to world-camera zoom. The icon uses the player-facing tooltip `Population`; it is distinct from the selected-Citizen badge. Activating it focuses and cycles through Citizens without changing selection.
- A text control cycles simulation speed through `1×`, `2×`, and `4×` and uses the player-facing tooltip `Simulation speed`.
- A hollow five-edge Building icon toggles Building Mode and uses the player-facing tooltip `Build`. Its black contour alone uses an exact two-pixel solid stroke. Its two roof edges slightly overhang the two vertical walls, its bottom closes the silhouette, and it has no horizontal ceiling edge. Hover and keyboard focus add the shared white outline; active Building Mode fills the silhouette black.
- A cross-shaped control uses the player-facing tooltip `Quit`. The current control exits immediately. No disk save/load path exists, so runtime world changes are not preserved after quitting.

Simulation speed scales authoritative world time, Citizen movement, labour progress, plant regrowth, and environmental motion. Camera input, hover delays, onboarding, and speech-message visibility continue at real UI time. Durations are floating-point simulation seconds and have no divisibility requirement: a three-second job is still exact at every speed, taking 1.5 real seconds at `2×` and 0.75 real seconds at `4×`.

The Quit cross has a solid black interior made from two slightly unequal rounded strokes, giving it a hand-drawn form. It has no white resting outline; hover or keyboard focus adds the shared white stroke. Every toolbar or Building-menu button reserves a complete rectangular hit area independently of its icon's opaque pixels. Its square tooltip prefers its normal side but reverses toward the screen centre before crossing a viewport edge. Bottom Building-menu tooltips therefore appear above their buttons. The custom cursor is a friendly rounded arrow with a solid black interior and solid white outline and defines the application-wide outline-width standard. The fixed sun marker uses this same border width, while the larger Day/Night wheel retains the visually equivalent black perimeter. These controls contain no antialiasing or semi-transparent edge pixels. World-object names appear as plain black text after a short stable hover, without a dark tooltip panel. Within the edge threshold, the label occupies the cursor side facing the centre: right at the left edge, left at the right edge, below at the top, and above at the bottom. Corner decisions combine both axes. Native control tooltips use square black panels with hard white borders and no smooth corner radius. UI text retains the earlier vector fallback font source but rasterizes it at four times the previous density while disabling font antialiasing, subpixel positioning, and filtered glyph sampling. Selecting a non-Citizen world object draws separate four-edge frames around the top and bottom of its visible bounds; vertical connectors are intentionally hidden. Selecting revealed ground draws one continuous four-edge rectangle around only the chosen World Unit’s top surface. Selection thickness is recalculated from camera distance to preserve the shared cursor-width appearance. Citizen selection instead uses its white contact-shadow perimeter. Normal hover content names only the hovered entity or surface. Development-only values such as entity ID, coordinates, seed, state, and capacity belong to a separately toggled debug layer and must not leak into the default tooltip.

The general shape-language rule is to avoid very sharp exposed edges. Terrain, buildings, vegetation, citizens, controls, and other world objects use softened, rounded, faceted, or slightly irregular corners appropriate to their material. Tools held by citizens are the deliberate exception: their working edges may remain visibly sharp.

The selected-citizen count is an 18×18 circle attached beside the cursor rather than a fixed screen-corner panel, and it appears only for groups of two or more. Multiple digits may widen this badge but cannot increase its height. The movement preview reads as `O-------●`: the Citizen's exact two-pixel selection circle, one continuous two-pixel exact-white screen-space polyline projected from the remaining world route, and one larger destination dot. Intermediate pathfinding nodes have no circular markers. The first segment follows the moving Citizen. A single joined projected line prevents diagonal movement from breaking into dashed depth-rendered patches under the nearest-pixel pass. A blocked, disconnected, unknown, or unloaded target resolves to the closest reachable cell in the connected loaded region; if no route exists, the Citizen reports that state.

### 7.4 Actor speech bubbles and message bus

Citizens and future world actors communicate immediate intent or an unresolved condition through one shared `Actor Message Bus`. Actors submit a semantic message ID; they do not construct or position UI themselves. The message catalog defines the icon, optional very short text, priority, initial delay, visible duration, queue lifetime, repeat interval, maximum repeat interval, and whether identical messages may cluster. This is notification infrastructure, not a hard-coded desire or dialogue simulation.

The normal Citizen bubble is a compact, approximately half-original-scale, fully opaque white, black-outlined 2D card with black text and a code-drawn icon. A Building or separate Utility element uses the same bubble geometry with a fully opaque gray background and black text, allowing the player to distinguish a Citizen need or confirmation from equipment asking for a connection. The actor category comes from the speaker rather than from the message: Citizens identify themselves explicitly, while generic non-Citizen world actors default to the Utility treatment. The bubble is projected above its actor's head and always faces the player. It ignores pointer input and is drawn above ordinary world geometry, but it is hidden when the actor is outside the camera view, behind the camera, or occluded from the camera by solid terrain, Limestone, a Tree, or a Building. Another small speaking actor does not count as a solid occluder.

Visible bubbles are screen-space packed with an eight-pixel gap. When their desired rectangles overlap, later bubbles move upward until they are separate. A maximum of three message groups may be visible at once. Queue ordering is priority-first and then oldest-first. Pending messages have a time-to-live and are discarded if they become stale before they can be shown.

Identical clusterable conditions use a caller-supplied scope such as a Room, Building, or Utility network. Twelve citizens in one Room asking for Water therefore produce one Water icon with `×12`, not twelve simultaneous bubbles. Each later reminder advances to another still-affected actor. The initial persistent-need timing is two seconds before display, four seconds visible, and eight seconds before the first reminder. Continued reminders back off to 16, 32, and at most 64 seconds. A simulation system must refresh a condition while it remains true; if refresh stops because the condition was solved, its message expires without separate UI cleanup.

Work-order confirmations use a separate one-shot profile: nearly immediate appearance, approximately two seconds visible, no repetition, and a short queue lifetime. Implemented confirmations are a Log for cutting or gathering Wood, three red circles with no green stems for Food, a Water drop for Cactus collection, and a hammer for construction. Movement deliberately has no speech bubble; the selected Citizen's outlined contact shadow and route preview confirm the movement order. A Plank icon and message definition are prepared for the later Plank task without implementing that resource chain yet. This lets the player verify which work order was understood without reading a sentence. Rare literal speech may use a very short localized phrase such as `OK`, `Bye`, or `Yay`, but icons remain the default.

The bus accepts any `Node3D` with a speech anchor, so Buildings and Utilities can later report a missing connection through the same queue, clustering, priority, expiry, and occlusion rules. Prepared persistent message definitions include Water, Food, excessive heat, fresh air, and disconnected Utility. Those definitions do not create needs by themselves; their owning simulations must decide when the condition exists.

### 7.5 First-launch learning mode and Building hotkeys

On first launch, a translucent blank-keyboard overlay shows key proportions without prescribing key values. Any key dismisses it and stores completion locally; `F1` reopens it.

Building interaction contract:

| Input | Result |
|---|---|
| Building icon or `B` | Open or close the building menu without selecting a Building type |
| Support icon | Select Support placement and close the building menu |
| `Alt` + left click | Select the exact collider under the cursor, bypassing higher-priority grouped or citizen selection |
| Selected Building type + left click | Place one Construction Site, then close that Building-type placement selection |
| Selected Building type + `Ctrl` + left click | Place one Construction Site and keep that Building type active for another copy |
| Selected citizen + right-click Support site | Assign persistent construction across that site and then the nearest visible unfinished sites while the Pile contains Logs |
| Selected Citizen group + right-click Tree | Fill that Tree’s remaining Log work slots, then assign overflow Citizens to the nearest visible Trees with free segments |
| Draggable Building family + left drag | Fill the crossed World Units with the selected Road, Bridge, or Fence family according to that family's stretch rules |
| `]` | Move selection to the containing upper group |
| `[` | Return through selection history toward the previously selected smaller child |

Grouping follows the Figma-like layer model. A hierarchy may be `Building → Level → Flat → Room`, but missing groups are not invented; a correctly authored Building may legitimately jump directly from `Building` to `Room`. Draggable families and bracket navigation are activated only after those construction families and persistent group identities exist.

### 7.6 Player-facing text catalog

Design terminology and player-facing language are separate layers. Design documentation and code may use a precise term such as `Construction Site`, while the ordinary world tooltip may display the shorter noun `Support`. Player-facing object labels should normally use one short noun. Player-facing action labels should normally use one short verb.

Every player-facing string uses a stable text key containing at least two underscore-separated words. The authoritative table is `localization/ui_text.csv`. The table follows Godot's native localization CSV structure and stores planning metadata in underscore-prefixed columns that Godot ignores during translation import.

Every catalog row records a planned character limit. The English text is validated when the catalog loads, and formatted runtime text is checked again after dynamic values are inserted. A later UI verification pass must also measure rendered glyph width because equal character counts do not guarantee equal pixel widths across languages or fonts.

## 8. Simulation and rendering boundary

Godot is the engine and presentation layer. The authoritative simulation must not be encoded only in scene-tree nodes.

Keep these concepts separate:

- Simulation: IDs, coordinates, occupancy, resources, jobs, paths, reservations, and construction state.
- Presentation: meshes, animation, lights, shadows, particles, sound, and selection visuals.
- Interface: player commands and the LLM snapshot/delta protocol.

Important rules:

- Do not calculate a complete A* path for every citizen on every rendered frame.
- Request paths when a job or destination changes or a route becomes invalid.
- Run simulation at a lower fixed rate and interpolate visible movement.
- Batch repeated geometry and rebuild only affected chunks.
- Visual idle motion must not continuously invalidate collision or navigation.
- Optimise only after repeatable profiling identifies a bottleneck.

### 8.1 Persistence contract for generated detail

Generated visual detail is split by gameplay significance:

- Individual grass blade and tuft transforms are presentation-only. Do not serialize them. Rebuild them from patch occupancy and runtime variation rules when a world loads.
- Every tree, Palm Tree, cactus, stone formation, loose log, reserved log, carried log, and installed construction log has persistent identity. Save its `Permanent Detail Seed` or its resolved transform so reloading does not visibly move or rotate it.
- Tree and Palm Tree segment count, inherited bend, resource state, and origin material are persistent simulation data.
- Citizen body traits are persistent citizen data and later form part of the genetic appearance system; they must not be rerolled on load.

The save format should prefer a compact seed where the generation algorithm is stable. If changing that algorithm could move an existing important object, store the resolved transform or preserve a generator-version field.

### 8.2 Canonical Cloth resource

`Cloth` is one source-agnostic crafting resource. Construction and downstream manufacturing consume `Cloth`, not separate cotton-cloth, linen-cloth, or wool-cloth item types.

Its upstream source depends on biome:

| Biome / difficulty | Source | Acquisition direction |
|---|---|---|
| Greenery / easy | Cotton | Grow and collect |
| Sand / normal | Linen | Grow and collect |
| Snow / hard | Wool | Sheep grows wool; collect it at a cutting station |

Source provenance may remain metadata for visuals or trade, but it must not multiply otherwise identical downstream recipes.

## 9. Current code boundary

The current implementation is the structure documented in [README.md](README.md). It includes World Unit/Sub-Unit data, streamed surface chunks, Citizen movement and work, runtime-only discovery/state overlays, Support construction, excavation, and an experimental Building Constructor.

Anchor registries beyond the World Unit model, utilities, Pergola reconstruction, upgrades, vertical Building context, disk persistence, and an LLM observation/command service are not implemented. Earlier proposed service paths are intentionally omitted so they are not mistaken for the current architecture.

## 10. Deferred design notes

Keep these visible without implementing them in the first milestone:

### 10.1 Nomadic playthrough direction

A later playthrough may begin with two citizens travelling away from the standard starting area. They craft two pairs of boots, gather resources while moving, and carry progression mainly as knowledge instead of hauling a permanent stockpile of construction materials. The group may settle for several cycles to build temporary research facilities and grow its family, then continue the journey. World goals should encourage exploration and relocation rather than requiring every playthrough to become a permanent settlement.

- Logical voxel terrain with smoothed hills, rounded exposed soil corners, and preserved vertical cliffs.
- Loose soil settling at approximately 45 degrees.
- Four Loose Soil World Units compressed into one stable Compacted Earth World Unit.
- Saturated solid soil that seeps into newly excavated empty cells.
- Two snapped camera modes: Town Mode and Sub-Unit Detail Mode.
- All Buildings may have harmless visual Idle Motion; AC units vibrate more strongly and tall buildings may sway slightly.
- Dynamic sun, fire, and selected artificial lights cast real-time shadows without pre-baked shadow maps.
- Caves, autonomous outside cities, family genetics, ageing, services, utilities, fire, and large marble construction projects.
- Snow terrain uses denser tree availability than the sand prototype. Its Pine Tree produces visually distinct `PINE_WOOD` logs. Log material and biome of origin remain attached to the physical resource, so pine logs may be transported and used in a desert settlement.
- The first snowy dwelling is a full log cabin rather than the light eight-log/four-plank building concept. Its provisional budget is approximately 16 logs; the exact count must be derived from the final cabin geometry before becoming a recipe.
- Cotton, linen, and wool production are deferred, but all three must resolve to the canonical `Cloth` resource defined in section 8.2.
- Elevator Buildings, Elevator Shafts, multi-Floor route-time comparison, call queues, four-Citizen Car capacity, and crowd-settling behavior follow section 5.1 and remain deferred until multi-level navigation exists.

## 11. Sound design asset backlog

The game needs original audio assets for these initial sound events. The names below are provisional event identifiers rather than filenames or implementation details.

### System

- `clicking_a_menu_button_sound`: play when the player clicks a menu button.

### Notification

- `starting_new_day_sound`: play when a new Day begins.

### Action

- `chop_tree_sample_1_sound`
- `chop_tree_sample_2_sound`
- `chop_tree_sample_3_sound`

The three Tree-chopping samples provide variation for repeated chopping actions.

### Surrounding

- `cricket_sound`: enable during the evening.
- `frog_sound`: eligible to play while a Water resource is nearby; consecutive plays must be at least four seconds apart.

### Soundtrack

- `soundtrack_1_audio`: first soundtrack asset.
