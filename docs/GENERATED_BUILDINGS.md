# Generated building plans

Updated 10 November 2026: **normal Home placement is the primary integration**.
Door-connected and stacked Homes assemble the shared modular appearance while
retaining their existing addresses, residents, household stores, paid tiers and
construction jobs. Covered roofs disappear; exposed lower roofs in a stack become
open terraces. Upper construction still needs ordinary paid stairs and structural
support. Wall-only contact does not open a doorway.

Select a completed Home and use **Utilities** to queue its stove, lamps and rain
collection. The hover cost uses actual resources. Click each lamp's ceramic valve
to commission its paid gas connection; later clicks close/open the same valve.
The chimney shows fuel and accepts an extra log delivery. Builders automatically
refuel a connected stove when its fuel is low. A blocked exhaust stops gas supply.
The barrel uses normal water collection; its drain valve disconnects/reconnects runoff.

Housing → Building plan remains available alongside Home as an additive seeded
layout option. The separate prototype is a regression/inspection fixture.
`tools/settlement/play_home_assembly.sh` opens the normal-Home example on a temporary
practice map without touching player saves.

The shared generator produces 4–8 connected 2 × 2 × 2 m enclosed rooms, uncovered
roof terraces, reciprocal doorways and a staircase. Layout, upper footprint,
terrace perimeter, windows and roof profile vary deterministically. Main-game
plans use the existing room construction jobs, material deliveries, navigation,
beds and settlement saves. Beds go into leaf rooms; circulation rooms stay clear.
Terraces provide outdoor access and do not count as enclosed bedrooms. Main-game
plans use supported grid-aligned upper rooms; the fixture additionally exercises
the projecting balcony and one-/two-metre support transitions.

## Objects and actions

Nothing is added merely to suggest activity. No AC unit, plant pot, table or chair
is included without a corresponding simulation purpose.

| Object | Purpose / action | Connection and cost |
| --- | --- | --- |
| Enclosed room | Shelter; connect rooms through doors | Existing room-shell job, 2 Log per module |
| Open terrace | Outdoor circulation on an exposed roof | Existing frame job, 4 Log per module; supported by lower room |
| Stair | Reach the next storey | Existing stair job, 3 Log; physical navigation edges |
| Bed | Sleeping place | Existing bed job, 2 Log; depends on its room and accessible doorway |
| Posts, beams, roof, boards, railings | Structure, weather cover, floor and edge boundary | Components owned by their room; current job recipes are abstract, not per-piece bills |
| Brick stove + exhaust | Burn Log to supply connected gas lamps; obstruction stops supply | 56 ordinary Brick + 2 Pottery + 1 initial Log; 120 simulation seconds per Log |
| Interior/exterior lamp pair | Illuminate the room and its entrance | 2 Pottery + 1 Log per Home/room; initial 35-second charge expires without supply |
| Gas connection | Connect the stove to a lamp pair | Pottery: one per started 2 m of routed pipe; separate builder job |
| Gutters, downpipes, container | Collect exposed roof/terrace rain into town inventory | 12 Plank + 2 Rope + Pottery: 2 plus one per started 2 m of gutter/pipe run; capacity 24 Water |

Rain produces 0.25 Water per connected 4 m² catchment per simulation second.
Dry weather and disconnected pipes produce none; full containers track overflow.
The initial installation records paid catchments. Later roof additions are not
silently granted free gutters. Additional rooms can receive paid lamps through
Utilities. These are provisional balance values, not a new production economy.

The main town uses brick stoves and stove-fed gas lamps. It does not gain an Iron
production chain. The inspection demo retains its always-visible **Upgrade · 6
metal** button, disabled until its fixture stock is sufficient. Its temporary
metal supply is not town inventory. Installed town utility networks currently
prevent moving/removing their attached Home assembly; salvage and rerouting are
not implemented. A blocked chimney is visible and stops supply, but has no pipe
rerouting editor yet.

## Materials and persistent exemplars

`material_exemplars.gd` reads the existing `reviewed_brick.tscn` (0.45 × 0.20 ×
0.25 m) and canonical Timber plank source (0.70 × 0.055 × 0.22 m). The masonry
stove and chimney use ordinary, unscaled bricks: four per hollow bonded course.
Chipped corners derive from that stock mesh; there is no special stove brick.
Cut boards around a shaft are fitted construction pieces. Existing palette
constants identify the materials.

Town → building ID → room UID → component slot supplies identity. Each generated
room saves its explicit cell geometry plus generator version, seed, source room,
rotation and an exemplar record `{v, seed, overrides}`. A stable slot hash chooses
one of 64 variants per stock type. Overrides persist a particular changed piece.
No mesh vertices are serialized. An empty exemplar record measured 31–34 UTF-8
JSON bytes for the tested seeds, before containing-room metadata. Records are
currently repeated per room, not per brick. Overrides add only changed slots.

Variant definitions and slot naming are a versioned asset contract: preserve v1
when adding later generators, or migrate explicitly. Do not silently reroll a
saved component. This is persistent generated identity, not an infinitely unique
mesh for every brick. A shared bounded variant library keeps geometry reusable.

## Measured scene inventory and detail

The capture script writes `artifacts/settlement/modular-object-inventory.json`.
Counts describe the generated building subtree, excluding the plinth, environment,
interface and service supply props. Mesh resources count actual distinct Godot
mesh objects, not gameplay nouns, and render nodes are not GPU draw-call counts.

| Seed | Rooms | Gross terrace m² | Brick instances | Stock plank instances | Physical mesh instances | Distinct mesh resources |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 4 | 9 | 56 | 206 | 545 | 285 |
| 1 | 6 | 9 | 56 | 265 | 697 | 378 |
| 2 | 8 | 9 | 56 | 326 | 848 | 468 |
| 4 | 7 | 5 | 56 | 258 | 728 | 416 |

The older inspection fixture has six utility categories: stove, exhaust, lantern, socket, grid
terminal and material supply; two lantern instances and one of each other kind,
plus one interior light per room. Decorative props: zero. Structural geometry is
still numerous: this is a measured baseline, not a town-scale performance claim.
The separate main-game capture writes its own inventory report.
Its eight-room example currently contains 708 physical mesh instances, 409 mesh
resources and 300 stock planks across 472 render nodes, including functional beds
and stair supports. These are renderer counts, not 409 individually saved assets.

Bricks and full stock planks are MultiMesh batches grouped by material variant and
transparency. Chipped meshes are created lazily when a 2 cm feature projects to
at least 1.25 pixels. The shared cache is bounded at 63 derived variants per type.
The distant fixture replaces board decks with flat surfaces and omits interior
lights. Main-game rendering currently switches stock mesh detail; it does not yet
use the fixture's full coarse geometry. Simulation and saved identity survive LOD
changes. Region-based lazy loading of the global room site is not implemented.

## Verification

- `tests/settlement/generated_building_test.gd`: 48 seed/rotation placements,
  overlap rejection, actual job costs and worker completion, leaf-room beds,
  normal save/load, stable overrides, stock bounds and detail changes.
- `tests/settlement/modular_house_test.gd`: support/window clearance and exhaust,
  upgrade accounting, battery expiry and shared generation rules.
- `tools/settlement/capture_generated_building.gd`: the actual Housing action,
  placement, House coexistence, worker completion, cancellation and screenshots.
- `tools/settlement/capture_modular_house.gd`: four silhouettes, masonry/metal,
  night lighting, charge/reconnection, distant detail and object inventory.

The separate scene is retained as a regression and utility inspection fixture.
The main game and fixture share the generator/material geometry; maintaining two
independent economies or two save systems is not the intended architecture.

## Normal Home integration checks

`home_assembly_test.gd` constructs normal Homes and their reinforcement with real
workers, builds stairs and an upper Home, checks interior access, material-backed
utility jobs, rainfall and JSON persistence. `room_utilities_test.gd` additionally
checks gas expiry, exhaust blockage, capacity, actual citizen collection and
stable render geometry during fuel ticks. `capture_home_assembly.gd` renders day
and night and writes `assembled-homes-inventory.json`; its counts supersede older
fixture measurements for that scene.

A one-metre unloaded balcony uses slim horizontal joists. Diagonal/grounded heavy
supports are reserved for a projecting occupied room. Native Home roofs retain
physical thatch, planks or curved clay tiles in the official material colours.

## Bounded irregular stacking

New ordinary Homes on completed Homes use a versioned deterministic nudge of
16–34 cm per axis, clamped to ±40 cm relative to their logical address. Adjacent
Homes on the same floor align their offsets to preserve wall/door interfaces.
Two-metre height remains fixed. This is bounded irregular stacking, not unrestricted
free placement. Existing saves retain their actual offsets. Copies preserve each
room's relative offset. Projecting occupied corners add one Log to the House quote
and receive short diagonal supports; a light threshold joins the terrace entrance.
The regular grid-based Building plan adapter remains compatible with older plans.

Main construction rows are now 44 points tall, showing miniature and name. Costs
and benefits appear in the hover tooltip. Planned shells use opaque materials;
the standard outline/tint identifies the active preview. Inspection cutaways omit
ceiling fixtures in the revealed rooms.

## Main-town neighborhood practice

Run `tools/settlement/play_home_neighborhood.sh` to open three ordinary Home
assemblies: a compact stack, an L-shaped terrace and a wider two-room upper floor.
Their 13 Homes use mixed hay/plank/tile roofs, saved off-grid upper offsets,
short load-bearing braces, accessible terrace stairs, brick stoves, connected
gas lamps and roof drains feeding collectible water containers. Three wells
show the 3/2/1 location-dependent rain yield. The compact Housing menu starts open.

This is a prebuilt fixture in the actual settlement scene. Initial construction
labour is skipped, but normal validated plans and completion paths deduct every
installed recipe from fixture stock. Subsequent player construction uses the
normal workers, materials and simulation. Saves use a separate temporary practice
directory, leaving ordinary town saves intact. `--check` runs the fixture headless
and verifies assembly count, upstairs access, yields and JSON save/load.
