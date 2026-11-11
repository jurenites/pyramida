# Town — Glossary

Terminology game specific only (no need to explain some basics), this document subordinate to code and tests.
Definitions provide names for implemented and deferred concepts; they do not claim that every entry is playable. [README.md](README.md) is the current behaviour summary. If terminology prose conflicts with code, update the prose rather than restoring obsolete behaviour.
The glossary favours explicit repetition over pronouns when repetition makes the subject easier to follow. A definition may repeat the complete term within one sentence or paragraph instead of replacing the complete term with “it” or another ambiguous reference.
Glossary terminology is written for design discussion and implementation clarity. Player-facing labels are separate and deliberately shorter. [localization/ui_text.csv](localization/ui_text.csv) is the authoritative catalog for player-facing English, text keys, character limits, interface locations, and translation guidance.

## Anchor Node

An `Anchor Node` is a structural attachment point at the centre of one Sub-Unit side. Every Anchor Node belongs to one specific Sub-Unit and one specific side direction. Two opposing Anchor Nodes may share the same physical position, but each Anchor Node keeps a separate identity.

## Building

A `Building` is a constructed entity assembled from physical resources. A Building may contain smaller groups such as Levels, Flats, or Rooms, but a Building does not require every possible group. A completed Building remains visible outside Building Mode.

## Building Blueprint

A `Building Blueprint` is a versioned, human-readable definition of a Building's logical parts, transforms, materials, resources, Sub-Unit occupancy, Cosmetic Variants, and future grouping. An official Building Blueprint may bind each part ID to a same-named object in a neighboring Blender-editable OBJ. The Building Blueprint remains authoritative for meaning while the OBJ is authoritative for vertices. A Building Blueprint is not a flattened mesh.

## Building Mode

`Building Mode` is the player interaction mode for placing Construction Sites and inspecting unfinished construction. Building Mode reveals the planned geometry of every revealed unfinished Construction Site. Leaving Building Mode hides unfinished planned geometry while installed construction remains visible.

## Capacity Grade

`Capacity Grade` describes the service capacity of a Utility segment or Utility device. Capacity Grade uses the values 1×, 2×, 3×, and 4× when the Utility family supports those values. Capacity Grade does not require proportional visual size growth.

## Chunk

A `Chunk` is an addressed horizontal region used for world generation, discovery storage, streaming, and save indexing. A Chunk does not imply that every vertical cell in the region is generated, materialized, or stored.

## Citizen

A `Citizen` is a person living and working in the simulated settlement. A Citizen follows direct player orders in the current prototype. A Citizen can move, gather, reserve, carry, build, and perform other implemented work.

## Elevator

An `Elevator` is a deferred Building that transports Citizens between Floors through an Elevator Shaft. Elevator route cost includes the walk to the Elevator, predicted waiting time, travel time, and the walk from the destination Floor.

## Elevator Car

An `Elevator Car` is the moving, occupiable part of an Elevator. The standard one-World-Unit Elevator Car has a provisional capacity of four Citizens. A full Elevator Car completes onboard destination requests but does not stop only to collect additional waiting Citizens.

## Elevator Shaft

An `Elevator Shaft` is the reserved vertical construction space in which an Elevator Car moves. An Elevator Shaft occupies one World Unit in width and depth and spans at least two World Units vertically.

## Floor

A `Floor` is a traversable vertical level that may be connected to other Floors by terrain, stairs, ladders, or a later Elevator. A Floor is a navigation concept and does not require a complete enclosed Building Level.

## Cloth

`Cloth` is the canonical source-agnostic textile resource. Cloth may originate from cotton, linen, or wool, while every downstream recipe consumes Cloth rather than a separate resource for each origin.

## Construction Site

A `Construction Site` is a placed, unfinished Building location. A Construction Site records the selected Building type, position, orientation, required physical resources, delivered physical resources, per-resource installation labour, and completion state. Selecting a Construction Site enters Building Mode, outlines the complete future bounds, displays remaining planned geometry in 50%-opaque gray, and shows a three-line Construction Inspector above the site. The Construction Inspector contains the Building name, one total-labour progress bar, and one Full Scale Icon Number per required material. A selected Construction Site may be rotated while unfinished; installing its final material removes rotation and locks the completed Building at that orientation. A Construction Site replaces each planned component with its installed Physical Resource as work progresses.

## Cord Path Point

A `Cord Path Point` is a shape-control point used by a flexible cord. A Cord Path Point may guide sag or bending through free space. A Cord Path Point does not provide structural attachment and does not replace an Anchor Node or Utility Port.

## Discovery Mask

A `Discovery Mask` is a binary record of horizontal Sub-Unit areas revealed by Citizens. The current mask survives chunk unload/reload only within the running session; disk persistence and underground discovery are not implemented.

## Cosmetic Variant

A `Cosmetic Variant` is one of at least three visual forms available to a placeable Building or tile. Changing a Cosmetic Variant changes appearance without changing function, collision, capacity, occupancy, connection points, material cost, or construction time.

## Forecast Ring

The deferred `Forecast Ring` is a planned streaming region beyond visible presentation where terrain and future outside-settlement state could be prepared before a Citizen reaches them. The current streamer has only a presentation radius.

## Generator Version

A `Generator Version` identifies an immutable deterministic world-generation algorithm. A save retains the Generator Version so untouched coordinates continue to produce the same base world after newer generators are released.

## Hard Surface

A `Hard Surface` is a walkable form of the Surface construction family. A Hard Surface may act as a floor, road, platform, ceiling, terrace, or roof according to context. A Hard Surface may support construction above the Hard Surface.

## Greenery Mode

`Greenery Mode` is the player mode opened by the Tree icon beside the Building icon. It allows one Bush or rooted Tree Stump to be selected and re-rooted into a revealed, loaded, unoccupied World Unit. Re-rooting preserves the object's Permanent Detail Seed, resource cooldown, and growth timer. Greenery Mode does not relocate standing Trees, loose Logs, or terrain.

## Landscape Mode

`Landscape Mode` is the direct World Unit terrain-editing mode opened by the dirt-pile-and-shovel icon. Its Remove Soil tool removes an authored Soil Block or one flat base cube. Its Add Soil tool restores that base cube or places a new Soil Block against a valid exposed face. The current prototype stores only changed coordinates and does not allocate complete underground columns.

## Icon Number

An `Icon Number` is the shared interface element that pairs one object icon with an integer or an installed/required fraction. A Standard Icon Number remains fixed at the same 44×44 icon size as the Building and Quit toolbar buttons. A Full Scale Icon Number changes only the icon from 1× at maximum camera zoom-out to 2× at maximum camera zoom-in, preserving the represented Physical Resource or world object's apparent scale; the number font size remains fixed. A Compact Icon Number keeps both icon size and number font size fixed for dense summaries. Population uses a Standard Icon Number, selected Construction Site materials use Full Scale Icon Numbers, and each selected-Pile resource uses a Compact Icon Number.

## Permanent Detail Seed

A `Permanent Detail Seed` is deterministic data used to reproduce safe visual variation for a persistent world element. A Permanent Detail Seed may control details such as log bend, plank spacing, colour variation, wear, or idle-motion phase. A Permanent Detail Seed must not change logical geometry.

## Path

A `Path` is a Building family containing Road, Bridge, and Tunnel forms. Citizens do not require a Path to navigate. Instead every traversable surface has a travel cost, and a completed Path may offer a lower cost or connect elevations that ordinary ground cannot connect.

## Road

A `Road` is a one-World-Unit Hard Surface made from four material-specific surface components, such as four wooden Planks. A Road has a lower traversal cost and a corresponding higher Citizen walking speed. A wooden Road constructed above a four-Log Support combines with it as a Support Platform.

## Pile

A `Pile` is the first shared Storage Building. The starting Pile occupies a 2×2 footprint of four World Units. Its shape is represented by occupied cells so later connected expansion may form non-rectangular footprints. Small stones mark convex outer boundary vertices; straight joins and concave notches do not receive stones. A Pile uses a generic resource-count store so later resource families do not require a new Building type; the current visuals specifically represent Logs and Calories. Citizens carry collected Logs and Calories to the nearest accessible part of the Pile, and construction withdraws Logs from the Pile. An open Pile cannot store Water without a vessel. The current prototype has no capacity limit or expansion interface.

## Player-Facing Label

A `Player-Facing Label` is text displayed inside the game interface. A Player-Facing Label should normally use one short noun for an object or one short verb for an action. A Player-Facing Label does not need to repeat the complete design term when the interface context already identifies the subject.

## Physical Resource

A `Physical Resource` is a resource represented by a persistent world object while the Physical Resource is loose, reserved, carried, or installed. A Physical Resource preserves relevant identity and material provenance across those states.

## Emergency Escape

`Emergency Escape` is the anti-entrapment fallback used only when a Citizen's current World Unit has no legal neighbouring exit. After a short visible delay, the Citizen may cross one or more Hard Blockers to recover from an otherwise permanent prison. Future multi-level navigation may express the same rule by crawling, climbing, controlled falling, or another physical recovery action.

## Hard Blocker

A `Hard Blocker` is a World Unit or Building face that normal Citizen navigation cannot cross. Limestone, player-authored Soil Blocks at the walking level, and a Warehouse wall are Hard Blockers. A Warehouse Door is not a Hard Blocker.

## Soft Obstacle

A `Soft Obstacle` remains physically passable but has a higher route-search cost than normal ground. A Cactus is a Soft Obstacle: Citizens prefer to walk around it but may cross its World Unit when that is the practical route.

## RTS Unit Mode

`RTS Unit Mode` is the player interaction mode entered by selecting one or more Citizens. RTS Unit Mode supports Citizen selection and movement orders. RTS Unit Mode uses a fully rounded count badge for the selected Citizen count.

## Soft Cover

A `Soft Cover` is a non-walkable form of the Surface construction family. A Soft Cover may use cloth, hay, or another light material. A Soft Cover provides shade and permits construction above the Soft Cover.

## Sparse World Delta

A `Sparse World Delta` records a persistent difference from the deterministic base world, such as excavated terrain, a placed Building, changed entity state, or a tombstone for a removed generated entity. Unchanged base terrain is not a Sparse World Delta.

## Soil Block

A `Soil Block` is one player-authored solid terrain cube occupying exactly one World Unit at an integer height from `0` through `255`. It is distinct from the implicit generated base surface and from a carried Physical Resource. A Soil Block has collision and may be attached to any exposed face of another Soil Block.

## Sub-Unit

A `Sub-Unit` is one of eight equal construction volumes inside a World Unit. Every Sub-Unit has an edge length equal to one half of a World Unit. Every Sub-Unit owns six Anchor Nodes, with one Anchor Node centred on each Sub-Unit side.

## Text Key

A `Text Key` is a stable machine-readable name used by code to request a Player-Facing Label. Every Text Key contains at least two complete words separated by underscores, such as `exit_button_text` or `exit_button_tooltip_text`. A Text Key remains stable when the displayed English or another translation changes.

## Support

A `Support` is a Building made from four installed corner logs. A Support permits construction above the Support. A Support may result from direct construction or from reconstructing a Pergola and returning the Pergola's Soft Cover material.

## Surface

A `Surface` is a construction family that covers an area and permits construction above the Surface. The Surface family contains Hard Surface and Soft Cover forms. Walkability depends on the selected Surface form.

## Utility Port

A `Utility Port` is a functional connection point owned by a Building, tool, or Utility device. A Utility Port connects compatible Utility services. A Utility Port remains separate from structural Anchor Nodes and flexible Cord Path Points.

## World Unit

A `World Unit` is a 1×1×1 m construction space (updated 30 October 2026). Every World Unit contains exactly eight 0.5×0.5×0.5 m Sub-Units arranged as 2×2×2. A room is an architectural space spanning multiple World Units; its minimum proposed module is 2×2×2 m. Older room-relative prototype coordinates require explicit conversion rather than reinterpretation. See [building measurements](docs/BUILDING_MEASUREMENTS.md).
