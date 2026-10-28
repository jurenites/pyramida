# Block City — current direction

User-confirmed revision, 24 October 2026. This supersedes the initial economy-driven demo documented in [the v1 archive](DESIGN_V1_ARCHIVE.md).

The immediate question is whether placing coloured 3D rooms and connecting their floors feels clear and interesting. Building types, needs, currency, service counts, upgrades, lot purchases and the win condition are deferred. Colours carry visual identity only. There is no production switch, power-load allocation, transformer upgrade or forecast purchase in this version.

## Interaction

Construction is the normal state. There is no Inspect/Place toggle. Left-click or Space commits the outlined landing, then the next room becomes available immediately. R only rotates around the vertical axis; tipping is removed from input and the model. Only the current piece is shown as a coloured miniature; hide the next-piece label and preview. Show the actual solid body and door at its landing position, with no floating ceiling copy. Shape names and building names are not displayed. Incoming shapes are all one cube high. Most draws are 1×1, 1×2, 1×3 and 2×2 footprints; 2×3 rectangles and elevator shafts are rarer; both L shapes are retired. Relative weights in `balance.json` are actual draw odds among currently fitting shapes, not preference scores that force equal representation. Stable seeded draws preserve undo/save behavior. See [shape tuning](SHAPES.md) for defaults.

Q/E animate 90-degree camera turns over 0.35 seconds. Repeated presses accumulate turns; right-drag takes over immediately for free orbit, with scroll-wheel zoom. Camera controls remain available during room-drop animations. Pole and door interactions take priority over mouse placement; clicking the piece previews does not build.

The top-right X icon opens a small Resume / New Game / Quit menu and blocks world input. Escape deselects the current piece and cancels pending wiring; it never opens the menu. This applies only to Block City; the original Pyramida settlement retains its own controls. No title, resource counters, permanent tool sidebar, lower instruction panel or goal display is added.

Room surfaces, including doorways, select existing construction for relocation when no supply piece is held. Existing saved exterior routes remain supported; new routes come from corridors and stairs. The corridor/stair experiment remains independent of electricity. Undo rolls back either connection or placement as a whole action. Basement placement remains available on B without adding a persistent toolbar.

## Lot and context

One room cell is the geometric unit. The ground foundation is 3×3. Cells at heights 1–8 may project one tile beyond its edge when supported. Ground and basement construction stay inside the foundation. At least one column must be directly supported; a diagonal brace can reach one neighbouring primary column, including a directly grounded column of the new room. Load-bearing columns must run uninterrupted to the ground. Cantilevered cells cannot carry another room or support a second chained beam. The outer one-cell boundary also prevents successive buildings extending two tiles into the street.

The layout, from inside to outside, is plot → one-cell pedestrian passage → road. The front road is three cells wide; left, right and rear are one-cell alleys. Grey surrounding buildings are assembled from the same one-unit cells with varied 2×3, 3×2, 2×2 and 3×3 footprints. Some upper floors step inward; every cell has direct support below it. Muted windows and roof surfaces add simple detail without gameplay behavior. Heights reach three cells. Roads continue through one additional ring of city blocks around the playable area, enclosing the grey neighbours with outer cross streets. The wide front road continues across the full grid; its lane dashes stop at junctions. Road surfaces meet without overlapping and have separate elevations from the surrounding ground to avoid coplanar flicker.

## Direct power cables

The pole stands at the front-left passage corner and has an attachment height of 4.5 cells. Click the pole to start a connection. A subsequent wall-edge click picks an exterior socket on that cell's floor. Mouse picking chooses the frontmost actual cell, not a floor guessed from screen height. The socket is 0.82 units above the cell floor, just outside its selected side.

Both the direct sight line and the hanging cable must clear all occupied cells. Hidden wall faces, internal shared faces and underground targets are rejected. The rendered cable and clearance test use the same 24-segment sagging curve. The curve is a deterministic geometric approximation, not a physics rope simulation. Connections store their cell and side, independently of meshes. New construction cannot intersect the physical curve at its final position. Overhead wires do not reserve an entire vertical drop column; direct sight-line clearance applies when creating a cable.

A wire energizes the connected horizontal component of touching cells on its target floor. Power does not travel vertically or jump gaps. Other floors require visible cables from the pole or an existing powered building socket. This is a simple floor-connection experiment, not an electrical capacity, voltage or production simulation. Connected cells show a brighter top surface and cable endpoints use teal sockets. Invalid pending connections turn red.

## Open questions

- Does the player recognize the pole as clickable without a text instruction?
- Are wall sockets easy enough to target at every camera angle?
- Is direct visibility a useful placement decision, or an irritating restriction?
- Is one cable per connected floor the right granularity?
- Should support and routes create the eventual objective, or should an additional economy be introduced after this interaction is understood?

No market success or player retention is inferred from completing software tests. Block’hood remains the closest reference to exceed in clarity and lasting spatial decisions, not a template for adding more disconnected systems.

## Interior circulation and views — 24 October 2026

The 1×1 and 1×2 supply pieces are hall/corridor modules. Their joined cells have no internal partition; facing corridor openings connect horizontally. Ordinary rooms connect through authored entrances: each piece draws one entrance when selected. Long rooms restrict that choice to a long side; R rotates the stored entrance with the footprint. Access propagates from street-facing entrances or existing exterior access paths through this explicit graph, independently of electricity.

A new single-cell staircase uses two five-step flights and a rear half-height landing. Enter at one front corner, turn 180 degrees, and return to the opposite front corner one floor higher. The occupied footprint is one cell. Rotate the entire stair and its ports with R. A corridor at the upper side landing connects to the stair, as does a hall or stair directly above through an actual floor opening. An ordinary floor cannot cap the stair shaft. A topmost stair is excluded if its upper landing would exceed the city height limit. The staircase currently participates in access logic; there are no simulated pedestrians.

Rooms are architectural shells with floors, perimeter walls, open doorways and exterior window apertures. Green thresholds and jambs identify connected entries; entrances awaiting a connection use yellow frames and exterior doormats. Both mat colors are depth-tested and hidden by walls and floors. The landing preview uses the same shell as placed construction. Stairwell roofs remain open. One icon-only button at bottom-right cycles roofed → roofless/full walls → low walls. Mode changes never alter occupied cells, access, support, electrical connections or saves. Stacked upper floors still conceal interiors beneath them; this is a roof/wall toggle, not a floor selector.

The camera fits projected scene bounds (roads, neighbours, visible construction and pole/basement) into the current logical viewport, with padding for corner controls. Resize and orbit preserve a relative scroll zoom of 0.82–1.30 times the fitted span. This allows about 22% magnification over the default fit without extreme close-ups. The standalone demo minimum window size is 800×600; shared UI point sizes remain unchanged.


## Roof placement, wiring and visibility — 24 October 2026

Ray-pick placed room cells before the ground. Hovering a room snaps the candidate to the level immediately above that cell; validate support, occupancy and cable clearance at the final location. Ground placement retains the normal landing search. Door actions only run while the held piece is put aside, so entry clicks cannot steal placement clicks.

Short right-click deselects the current piece and cancels a pending wire without consuming the supply. The current-piece thumbnail toggles placement and dims while deselected. Right-drag continues to orbit. Clicking the pole also puts the piece aside. Visible existing wall sockets show teal circles in this state; clicking one starts a daisy cable from that exact endpoint. Successful wiring leaves the piece aside for further connections. Click the thumbnail to resume construction.

Daisy cables store source cell/normal as optional fields in the existing v2 save format. Missing source fields mean the pole, preserving older saves. Power propagates from pole-fed cables through same-floor touching cells and explicit outgoing links. Chains never generate power independently. Validate physical cable clearance and rooted source references when loading; undo remains one action per link.

Neighbour buildings fade to 8% opacity and stop casting shadows when camera-to-playable-volume rays intersect their bounds. Re-evaluate on camera rotation, resize and construction changes; leave clear neighbors opaque. This presentation change never changes placement, wiring or access geometry.


## Neutral halls and room cutouts — 24 October 2026

Call the individual colored modules rooms. Both 1×1 and 1×2 halls ignore their supply color and use neutral gray, with an open floor and exactly four supports at the footprint corners. Unconnected sides keep the open scaffold and there is no roof. Physically connected sides gain neutral doorway walls and an actual opening; frames are green only when that entrance is reachable from the sidewalk, otherwise yellow. Keep entrance/access status colors and electrical markers. The corner thumbnail uses the same open four-column silhouette. Existing saved halls receive this visual treatment automatically.

A held hall normally targets the roof of the room beneath the cursor, stacking on the next level without moving or replacing the lower room. Hold Shift to explicitly target the occupied level and cut into it. In that mode, click or Space replaces only cells under the hall footprint, retaining the same grid occupancy and support beneath rooms above. Existing halls and stairs are protected from replacement. Empty cells covered by a partial cut still require legal footprint, structural support, clear paths and physical cable clearance.

Split the surviving room into face-connected sections, keeping its original color and shape provenance. Give each section an entrance on its new hall boundary; remove obsolete exterior access routes when their door moves. Remove fully replaced room records and reindex the remaining records. Electrical endpoints remain attached to their occupied cells. Preview the cut geometry and resulting access without mutating the saved state. Hall insertion is immediate rather than a falling animation. One undo restores the whole pre-cut room arrangement, doors, routes, connections and supply. Save the resulting geometry through the existing v2 format.


## First-room placement and entrance feedback — 24 October 2026

Keep the first room in each depth view wholly within the foundation footprint. Clamp its anchor using the rotated shape extents before previewing or placing, and reset explicit floor targeting. This prevents the upper-floor overhang allowance from leaving an unsupported first preview at y=1 near a lot edge. Rotation and keyboard movement use the same clamp. Later rooms keep their existing support and roof/cut targeting rules.

Entrance status uses green for street/hall access and yellow while a connection is still needed, including inward-facing ground doors. Missing access never prohibits structurally valid placement. Use the same colors for placed and preview mats/frames; invalid placement previews show a pending yellow entry. Keep room materials and the shared yellow selection outline unchanged by placement validity, removing the previous red invalid-volume outline. This supersedes earlier red/amber entrance styling.


## Economy and plumbing experiment — 25 October 2026

The user has reopened economy, residents, plumbing, lifts and progression planning. Keep the existing color/shape construction save intact while testing the separate `EconomyLab.tscn`. The experiment is now archived from the construction menu after the 25 October playtest. The lab uses money and residents only, with water/drain throughput as service constraints, icon-led teaching, reversible monthly accounting, and monthly accounting retained for developer comparison only. See [the proposal, actual balance runs, limitations and progression plan](ECONOMY_PROPOSAL.md). This is an experiment, not a replacement for the construction demo or a claim that late-game balance is solved.


## Construction focus after the economy playtest — 25 October 2026

Construction remains the active game. Do not introduce monthly-advance controls, Builder/Creative/Sprint mode selection, or exploded floors into its play flow. Its X menu offers Resume / New Game / Quit. Keep the toilet silhouette as a reference for future plumbing integration, without adding a disconnected bathroom feature now. The earlier lab source remains available for developer comparison; floor selection now places 1 below 2 below 3 and its exploded view and mode menu are removed.

Halls stack on room roofs by default; Shift explicitly requests a room cut. Stairs use the same neutral concrete as the earlier lab, with yellow step edges, three solid walls without window apertures, and depth-tested mats at the lower front-left entrance and upper front-right exit. Rotating the stair rotates both mats with its flights. All room mats use their 3D geometry only; remove the screen-space duplicate so concealed entrances do not show through walls or floors. Existing room colors and saved occupied cells are unchanged.


## Open stair passages — 25 October 2026

Build each flight from thin, wall-supported concrete treads and a thin rear turning slab, rather than solid blocks filled to the floor. Reserve a full-width front landing at the storey plane so the upper exit can cross to the next stair's entrance. Stop the central divider short of both turning spaces. A hall or stair above keeps the shaft open, including the rear turn's headroom; only narrow side ledges and the front landing remain at the floor plane. Preserve the neutral walls, yellow tread edges, entrance mats, occupied cells and saved connections. Geometry tests check a small body volume through three aligned stacked stairs in all four orientations; this demo still has no simulated pedestrian movement.


## Debug construction palette and local placement diagnostics — 25 October 2026

Expose all configured shapes as a compact, icon-only palette on the right, with short hover labels. Choosing a shape repeats it until another is selected or New Game resets the choice. Respect room rotation, depth mode, deselection and menu gating; palette clicks must never also place into the scene. Keep controls inside the minimum 800×600 viewport and use a scroll container for future additions. This palette is explicitly requested for debugging, not a proposed final resource/build menu.

Placement plans carry per-cell issues for occupied cells, reserved walking paths, boundary/height limits, blocked stair exits, cable intersections, protected hall/stair cuts, missing support and load on a cantilever. Preserve the attempted footprint even when clearance fails. Support validation returns all invalid base cells instead of stopping at its first error. Render a coral outline only around those cells, with a local cause symbol and a short explanation on marker hover. For structural errors, point to the exact empty or weak support cell below (above in basement mode). Valid cells remain yellow and room surfaces retain their normal appearance. Rejected placement makes no saved changes and emits no top-left error text. No structural rules have been relaxed; identical supported 1×3 rooms stack in all four orientations.


## Long-side entrances and completed corridor doorways — 25 October 2026

Every ordinary room has one entrance chosen from its exposed perimeter when its card is drawn. Elongated 1×2, 1×3 and 2×3 rooms use either long side; squares can use any exterior face. Store the chosen local door and normal on the card, rotate both with the body, and persist the world door on placement. Palette selection and each successful repeated placement draw a new choice; previews, rotations, view toggles, deselection and undo do not reroll it. Existing room records use their saved single doorway. Cut remnants keep their authored doorway toward the hall.

Halls already expose every perimeter edge logically. Draw neutral wall sections with door openings wherever those edges meet the sidewalk, another matching room/corridor/stair port, or an exterior access path. Preserve four corner pillars and open edges elsewhere. Do not create partitions inside a multi-cell corridor. Match doorway geometry and doormats to these exact ports in placed rooms and previews. Green indicates that the particular connection is usable from the sidewalk; an isolated connected pair can remain yellow. An isolated upper hall has no misleading single-door marker. Ordinary room door clicks may request an exterior access path from any of its entry positions.

Existing saves retain their cells and saved doorway. Queue cards persist their randomly selected local entry; old cards without entry data retain their authored default. Ports and meshes derive from the same single doorway. Invalid saved card entrances are rejected before changing live state.


## Supported hall platforms and comparable shape icons — 25 October 2026

For testing, allow halls to snap beside a selected wall at its storey, with outside ground-level placements lifted to the first permitted overhang level. A hall no longer needs an occupied cell directly beneath part of its footprint if every unsupported base cell has a diagonal brace terminating on a genuinely grounded column. Such braced hall cells can carry vertical room stacks. They do not become anchors for further diagonal braces. Ordinary room cantilevers remain unable to carry a new storey. Keep bounds, ceiling, cable, access and stair-shaft checks. Show twin diagonal brackets at cell sides beneath the hall floor so they stay clear of the central doorway. Save the existing brace endpoints; recompute vertical support on load.

room_domino is a colored 1×2×1 room distinct from the corridor. Both L variants are now hidden and have zero supply weight. Preserve placed L geometry for save compatibility, but migrate queued L cards to small squares. Long rooms draw one entrance on a long face.

All thumbnails project their geometry through a single shared unit scale based on card size and the largest footprint. Center shapes without independently zooming them. Show stairs as two flights inside a one-cell cutaway shell, not an oversized staircase symbol. A one-cell hall and a one-cell stair occupy the same reference volume; a 1×3 room contains three such cubes.


## Escape deselection and X menu — 25 October 2026

Escape clears the held construction preview, selected-room marker, hall-cut modifier and pending wire/source/target, while preserving placed rooms and the supply. It also ends camera dragging/turning. Handle it before focused UI can consume it. Repeated Escape never opens a menu. If a menu is open, Escape closes it and leaves construction deselected. Remove the palette selection border while no piece is held.

Use an icon-only X button at the top right to open Resume / New Game / Quit. Clicking it must not place a room or quit directly. Keep its 48-point target and 4-point strokes separate from the hand thumbnail and debug palette, including compact Retina viewports. No new persistent labels or instruction panels.


## Elevator shaft and single-entry room revision — 25 October 2026

An elevator section occupies one cube and has one floor doorway. Contiguous sections in the same column join their access graph, even when individual floor doors face different directions. Halls connect at matching side ports. No section may bridge a missing floor or infer electricity from walking access. Neutral walls, paired metal doors, a call button, a central suspension cable, an aligned rear cable and one concrete-gray counterweight per continuous stack, and open floor rings distinguish the shaft. Only the bottom of each contiguous stack has a resting platform; upper centers contain only the suspension cable. The palette uses the same unit-cube projection as other pieces. Passenger travel, scheduling and power-dependent lift operation remain future mechanics.


## Stable placement plane and centered rotation — 25 October 2026

A roof, open hall interior, or hall attachment to a colored room sidewall acquires a horizontal placement plane at the target storey. An exposed roof immediately updates the plane to that surface, including a lower roof next to a taller tower. Open hall interiors select the cell above the pointed hall. Empty cells and ordinary room sidewalls retain the current plane. Keep unsupported previews at the requested position and let ordinary per-cell support feedback explain invalid placement. Do not search another floor to make a room fit. Unacquired ground placement remains at ground level; basement selection keeps its existing behavior.

Alt temporarily reacquires the plane from the pointed roof or ground. A new piece, successful placement, deselection, depth change or undo releases transient aiming state. Shift retains explicit hall cutting. Escape and focus loss clear held modifiers. No new persistent UI or instruction overlay is introduced.

R rotates around the footprint center. Retain the exact pivot across repeated rotations, resolving odd/even dimensions with a consistent half-cell grid snap so four turns cannot drift. Carry the resulting cursor offset into subsequent motion and clicks. Arrow/WASD nudges preserve the active floor. Preview and commit must use identical cells, orientation and height; unsupported clicks leave construction and the selected plane unchanged.


## Elevator landing doors and parked cabin — 25 October 2026

Each built shaft section has a dedicated wide doorway, paired sliding leaves, call button and its existing floor-specific connection mat. Bottom doors retract beside the opening to reveal the parked cabin; upper landing doors remain closed. The access graph still connects each landing through contiguous shaft sections, independent of visual door state. Missing shaft sections break vertical access.

The bottom section contains a complete neutral cabin: floor, side/back lining, handrails, control buttons and a yellow threshold. Roofed view includes its ceiling; roofless and low-wall modes reveal the interior. No upper floor contains a duplicate cabin or platform. Preview and placed geometry use the same floor-door arrangement; saving retains geometry and derives the bottom cabin on reload. The cabin remains stationary pending passenger/motion mechanics.


## Release detached previews onto ground — 25 October 2026

Correct the overly persistent floor lock: once a raised footprint has neither occupied cells directly below nor a valid support solution, check whether the pointer sees bare ground. If the same piece can be placed at that ground projection, release the plane and show it at ground height. Keep the rotation cursor offset, and commit exactly those displayed cells on click. Preserve partly supported overhangs, valid side brackets, empty-gap positioning, direct lower-roof targeting, explicit Alt retargeting and Shift cutting. Never make an invalid ground target valid by bypassing fit checks.


## Direct room relocation — 25 October 2026

Room-body selection enters a reversible move preview using the existing solid room and yellow selection outline. No toolbar or extra buttons. Hide the source mesh while previewing, but preserve live model and saved state until commit. Retain the exact current cell shape, including cut fragments; normalize that geometry and its doorway for horizontal rotation. Mouse motion uses the current placement plane and cursor offset. R rotates, click/Space commits, Escape or short right-click cancels, and Z cancels a pending move or undoes a completed move. Palette selection switches back to building new pieces.

Preview and commit share one relocation plan. Exclude source occupancy and its old exterior path from collision checks, then validate all resulting rooms in support order. Recompute support braces, reject orphaned upper construction, and transform attached incoming/outgoing cable sockets with the room. Reject cable obstruction or buried/internal sockets. A changed doorway clears its obsolete exterior route; matching room/hall access is recalculated. Preserve room ID, supply queues, draw counts and turn; checkpoint the final rooms/cables together as one undo action. Source geometry remains saveable throughout a pending move. Keep socket/pole wiring interactions; ordinary doorway clicks now select the room rather than buying an exterior path.


## Whole-room selection outline — 25 October 2026

Outline the union of selected room cells in both construction and relocation previews. Project each occupied cube to a convex polygon and union those polygons into a single screen contour. Draw only that perimeter, so cube divisions, inner creases and hidden back edges never cross through the room. Preserve visible concave boundaries instead of replacing the shape with a bounding box. Keep the existing yellow 4-point stroke and the separate coral invalid-cell diagnostics.


## Parent doors and weighted room routes — 25 October 2026

An ordinary room retains one authored entrance. When that door points into another colored room, derive a matching opening in the parent wall, so entry does not require two randomly drawn doors to coincide. Stair/elevator floor doors can also open matching entries into colored rooms. Halls retain their explicit exposed-edge ports; merely placing a hall beside a blank room wall does not create arbitrary openings. Draw one solid threshold and connection node per shared doorway. All geometry, access and navigation use the same reciprocal ports.

Resolve colored-room parent chains from authored door targets; inherit the terminal parent’s color. For cycles, use the lowest room ID in the cycle as the stable color source. Preview the inherited color, commit all resulting colors with placement/relocation, and restore them with undo. Circulation pieces remain neutral. Incoming children may add multiple reciprocal openings to a parent, superseding the earlier single-total-opening rule.

The route graph uses occupied cell centers and stair top landings. Horizontal transitions inside a room or through a matching doorway cost 1. Stair rises cost 1 each. Every pair of floors within one contiguous elevator shaft has a direct cost-2 edge, avoiding a repeated charge at intermediate floors. A missing shaft section breaks that ride. Existing saved exterior paths remain traversable. Use Dijkstra’s algorithm; there are no diagonal wall shortcuts or implied vertical links through ordinary rooms.

The main entrance is the first room by stable ID with an unblocked street-facing ground port. Its interior tile starts at distance 0. The destination is the selected room’s authored entry cell. Thus one/two/three stair rises cost 1/2/3, while each nonzero elevator ride costs 2, plus any horizontal approach and exit steps. Separate buildings without a path from this main entry have no route cost, even if they have their own sidewalk door.

For the selected room only, show a cyan route with solid node dots and one small numeric total above the destination. Placement mechanics remain unchanged. Escape hides the display; unselected rooms introduce no text. Main and destination openings stay physical, depth-tested geometry. Route overlay intentionally exposes the graph through the building so it can be understood without an exploded view.


## Backspace room removal — 25 October 2026

Delete the selected source room with Backspace, whether it is under a move preview or remains selected after placement of a move. New supply previews are not deletion targets. Use one model checkpoint for the removed room, its exterior path, incident cable edges and orphaned downstream edges; preserve other cable roots, supply, turn and draw counts. Reindex room IDs and recalculate remaining support braces. Reject deletion if remaining rooms lose structural support and display existing local issue markers. Commit and autosave atomically; clear selection/route/preview. Escape remains cancellation, Z restores the deletion, and no button or confirmation UI is added.


## Exposed roof and hall targeting correction — 25 October 2026

Open halls have no roof mesh, so aiming at their floor/interior selects the cell directly above that hall rather than requesting side attachment. Pointing at any exposed roof changes the active storey immediately, even below a nearby taller stack. Empty gaps keep the previous plane; direct surfaces take priority over old issue badges. Keep the surface projection offset separate from the rotation/nudge offset so repeated mouse targeting cannot undo centered rotation. Side platforms remain available on colored room walls, and Shift still requests a hall cut. No new controls or UI.
