# Block City — construction lab

Updated 24 October 2026. The playable demo now focuses on coloured shapes, supports and direct connections. Building uses, the economy, lot progression, forecast purchases, hold/refit, tipping and switch controls have been removed from the active version.

## Run

Open Godot Project Manager, select **Block City Demo**, and click **Run**. Its editor also runs the demo with **F5**. On another machine, import `demos/block_city/project.godot` once.

The Terminal launcher remains available:

```sh
./tools/block_city/play.sh
```

Inside the original Pyramida project, open `scenes/block_city/BlockCity.tscn` and press **F6**; F5 there still starts Pyramida. The standalone entry shares the original source and balance files through relative links, and uses the same existing demo save on macOS.

## Play

- Move the pointer to position the room. **Left-click** or **Space** places it. Clicking the pole keeps its wiring action. Aim at an exposed roof to choose its floor, including a lower ledge beside a taller tower. Aim into an open hall to stack directly above that hall. Slide across empty gaps on the chosen level; **Alt** can explicitly retarget the ground. **R** rotates around the footprint center; arrow keys/WASD nudge on the current floor.
- The first room snaps wholly inside the 3×3 foundation at ground level, including at lot edges and after rotation. Its normal colors are preserved; entrance status appears on the green/yellow mat.
- Point at an existing building to snap the new piece onto its roof. Overhead cables do not block the drop path; the final building must still leave the physical cable clear.
- **Short right-click** puts the held piece aside. Click the top-right piece thumbnail to pick it up again (or click it to toggle placement). A dim thumbnail means it is put aside. Right-drag still orbits.
- **R** rotates horizontally. Rooms never tip over.
- The top-right preview shows only the current coloured room. The next shape and its label are hidden. The world preview shows the solid building and door at the landing position.
- Click the **pole’s top circle**, then one of the four small wall targets to install a transformer. Each pole supplies at most **three heavy feeds**, shown by three pips while wiring. Heavy spans hang and sway gently.
- Continue clicking wall targets to add fuse boxes. Local cables follow wall borders and turn 90-degree corners automatically, with small clips keeping them fixed. Across disconnected buildings, a clear service span hangs instead. Each box powers its own room, not every touching room. Thin interior leads terminate at service outlets; appliance loads are not simulated yet.
- Click an existing box to continue wiring from it. **Drag the box** to move its attachment and reroute both incoming and outgoing connections. **Backspace** removes the selected box and its dependent branch; **Z** undoes. **Escape** or a short right-click puts wiring aside. The four targets sit beside the windows, not in their center. Existing saved center sockets remain usable and can be dragged to these new positions. Older saves with more than three pole feeds remain readable, but cannot add a feed until below the limit.
- Connected halls and internal stairs provide access automatically. Doormats are physical, depth-tested geometry and disappear behind walls and floors. Connected entrances have green doorframes and doormats; entrances that still need a connection are yellow. Inward-facing doors are a connection hint, not a reason to reject placement. With the piece put aside, click built geometry to select it; use the top-left Move button to reposition or rotate the selection. Halls and stairs provide pedestrian access independently of electricity; ground doors facing the sidewalk connect automatically.
- The **bottom-right view icon** cycles roofs on → roofs off/full walls → low-wall cutaway. It changes both placed rooms and the landing preview.
- **1×1 and 1×2 hall pieces are neutral gray**, shown as an open floor with four corner columns, without a roof. Unconnected sides keep that scaffold; sides joined to the sidewalk or a matching entrance become gray doorway walls. Green frames mark reachable connections. Their thumbnail shows the unfinished structure. Hover over a colored room and click to stack the hall on its roof without changing the room below. Hold **Shift** to explicitly cut the hall into the occupied level instead; that preview shows the cut and surviving room sections, with entrances facing the hall. Existing halls and stairs cannot be overwritten. **Z** undoes the whole cut, including the original doors and supply. Matching door openings connect halls to rooms. Every colored room has one randomly selected entrance. Long rooms draw its position on either long side; squares use any exterior face. The door stays fixed while aiming or rotating and is redrawn for each new piece from the palette. A **one-cell stair piece** shows its two flights inside a one-cube cutaway thumbnail; R rotates its entrance. It uses neutral concrete walls without windows, yellow step edges, and two doormats at its lower entrance and upper exit. It rises one floor with two flights and a 180° turn. Join its upper landing to a corridor beside it, or place a corridor/stair directly above to create a floor opening. Ordinary rooms cannot seal its shaft.
- **Escape** deselects the current piece and cancels wiring. The **X icon at the top right** opens Resume / New Game / Quit. Escape closes an open menu and leaves the piece deselected. Construction input is blocked while the menu is open.
- **Z** undoes the last placement or connection. **Q/E** animate quarter-turns around the scene. Hold **right-click** and drag to orbit freely; middle-drag also works. Scroll up for a gentle close-up and down to zoom out. The camera automatically fits the scene to the window size and proportions, retaining your relative zoom; the demo supports windows down to 800×600. Arrow keys/WASD also position rooms. B retains the basement view, with reverse placement; direct pole wires cannot pass through the ground.

The foundation is exactly 3×3. Above ground level, supported rooms may extend one cell over the surrounding pedestrian passage. Two-cell overhangs and unsupported rooms are invalid. A one-cell-wide passage separates the plot from a three-cell-wide front road and one-cell-wide side/rear alleys. The roads extend through one additional ring of surrounding city blocks, with connected outer streets. Neighbouring grey buildings use the same cell size, varied footprints, supported upper setbacks, and simple window/roof details. They reach three cells tall without overhangs. Foreground neighbors fade when they obscure the playable volume, and return to solid when the camera moves clear. Incoming rooms are mostly flat 1×1, 1×2, 1×3 and 2×2 footprints, with occasional 2×3 rectangles and elevator shafts. R rotates each variant. Edit the relative `weight` values in `data/block_city/balance.json` to control frequency; see [shape tuning](SHAPES.md). Ordinary room overhangs cannot support another layer. For testing, a hall attached by beams to a grounded wall can support rooms directly above it; beams cannot chain from another braced hall. Existing placed rooms stay intact on load, so use X → New Game to start entirely with flat pieces.

## Saves and checks

Actions autosave to `user://block_city_v2.json`. If that file does not exist, compatible 3×3 layouts from v1 are imported, keeping their cells, colours and pedestrian paths. Old wall-routed electricity, money and switches are not imported. The original v1 file is never changed. Expanded old layouts that do not fit this 3×3 experiment are left in the old save rather than cropped.

```sh
python3 tools/block_city/run_checks.py
```

Checks cover yaw-only geometry, one-cell overhangs, line of sight, the actual sagging cable curve, per-floor power, separate access routes, save/load/migration, roof picking, pole-to-wall and daisy-chain mouse interaction, chain save/load/undo, neighbor fading, deselection, green/yellow entrance mats and grounded first-room edge snapping, neutral hall geometry, partial/full room cuts, split entrances, default roof stacking and explicit Shift-cut, cut undo and save/load, Escape deselection, X-menu input gating, and eight varied placement runs. These checks establish behavior, not human playtest results.

## Files

- [Current design and constraints](DESIGN.md)
- [Shape coordinates and editing](SHAPES.md)
- [Market research](MARKET.md)
- [Archived first experiment](DESIGN_V1_ARCHIVE.md)
- `data/block_city/balance.json`: geometry, colours and scene dimensions
- `scripts/block_city/model.gd`: placement, access and connection state
- `scripts/block_city/cable.gd`: common curve and obstruction tests
- `scripts/block_city/neighbourhood.gd`: street layout
- `scripts/block_city/game.gd`: input, menu and primitive rendering

Screenshots of this version are `artifacts/block_city/flat-opening.png`, `flat-cables.png` and `flat-menu.png`. Earlier screenshots and progression transcripts refer to the archived v1 experiment.


## Debug shape palette and placement feedback

The right-side palette shows every configured buildable shape, including halls, stairs and elevator shafts. Click a shape to keep placing it repeatedly; R still rotates it, the current-piece thumbnail or a short right-click sets it aside. New Game restores normal weighted supply until another debug shape is selected. The palette reads `balance.json` rather than maintaining a separate shape list. Compact windows use the highlighted palette item in place of the duplicate hand thumbnail; right-click still sets it aside.

Placement errors stay in the scene. Only offending cells have coral outlines; valid cells retain the usual yellow outline and room materials stay unchanged. A broken-column marker points to the missing support or the overhang below. Other markers indicate occupied/path cells, cables, blocked stair exits and footprint/height limits. Hover a marker for a brief cause. No placement error is sent to the top-left text area. In particular, an aligned 1×3 room can stack on another; a cantilevered ordinary room below cannot carry a further storey. A braced hall platform is the testing exception.

## Economy and plumbing lab

This earlier experiment is archived from the game flow after the 25 October playtest; the construction demo is the active direction. For development comparison only, run `./tools/block_city/play_economy.sh` from the project root. This is an isolated, session-only Godot experiment; it never reads or overwrites your construction save. Escape → Construction Demo returns to the saved construction game.

The first home, blue street-to-bathroom supply, brown bathroom-to-street drain and sun/month button reveal the first working household. The remaining icon tools then become available. The house, plant, toilet and cross select home placement, garden placement, bathroom relocation and removal/refund. The floor numbers select the edited floor; **+** adds a floor. With removal selected, **−** refunds the top floor and its contents, and the lift/street icons refund purchased upgrades. Click matching service circles to join adjacent floors. The pipe-expansion icon by the road manhole expands capacity; the elevator icon beside the structure adds a lift. Hover tool icons for concise costs. **Enter** advances its experimental accounting month, **Z** undoes, and the usual Q/E, drag and scroll camera controls remain. Floor numbers run top-to-bottom with 1 at the bottom. Exploded view and mode selection have been removed. Monthly accounting remains only in this developer experiment; it is not part of the construction game.

Read [the economy proposal](ECONOMY_PROPOSAL.md) for taps, converters, sinks, phase balance, player styles, townhouse progression and current limits. Tune `data/block_city/economy_lab.json`. The tests regenerate `artifacts/block_city/economy-balance.json`; screenshots are `economy-first-step.png` and `economy-dollhouse.png`.


## Side platforms and icon scale

Hold a hall and point at a room's side wall to place it beside that wall. A raised hall gets diagonal support brackets where a grounded column can carry it, and rooms may then stack directly above it. Outside the foundation, keep the same one-cell overhang limit; side platforms cannot extend through chains of beams. Roof targeting and Shift-to-cut remain available.

The palette includes a separate colored **1×2×1 room**, alongside the open 1×2 corridor. L rooms are removed from the palette and random supply. **R** rotates the held piece and its entrance. Every icon uses the same cube scale. A 1×3×1 room occupies three unit cubes, while a hall or stair occupies one; individual cube edges remain the same size. The stair thumbnail shows the actual flights inside that volume.

Long rooms no longer retain old short-end doors. Existing saved rooms keep their geometry; if access depended exclusively on an old end-door path, reconnect it to a long-side opening.

## Elevator shafts

Select the elevator icon in the side palette. Each piece occupies **1×1×1**; stack sections directly above one another to link floors, then connect a hall to the door on each floor. R turns the entry. The central suspension cable extends up from the parked cabin. The rear cable runs only from the shaft top to the raised counterweight, with no rope hanging below it. A concrete-gray counterweight sits near the top of each continuous shaft, opposite the cabin at the bottom. Gaps break access. Every shaft floor has paired elevator doors and a connection mat. A complete cabin sits at the bottom, with its doors open; upper landing doors stay closed. Passenger motion and lift power operation are not yet simulated.

Pointing at an exposed roof immediately chooses the level above it; a taller neighboring stack does not lock the height. Open hall interiors also select the cell directly above them. Placement keeps its chosen floor across empty gaps and ordinary sidewalls while the footprint still touches support or uses valid brackets. Moving a completely detached room onto clear, buildable ground releases the raised floor and grounds the preview automatically. Other invalid positions retain local cell warnings. Selecting another piece, putting it aside, or successfully placing it releases the floor choice. For mixed odd/even dimensions, rotation snaps within half a cell of the center and four turns return to the original footprint.

## Moving existing rooms

Press **Escape** to put the current supply piece aside, then click a built room. Its selection outline appears without extra buttons. Move the pointer to reposition it, press **R** to rotate, and click or press **Space** to place it again. **Escape** or a short right-click cancels; **Z** undoes a completed move. Moving preserves the room's actual shape, color and doorway without consuming the next piece. Attached cable endpoints follow the room if their paths remain clear. Moves cannot strand supported upper rooms. Existing cable sockets still start wiring when clicked.

## Connected rooms and distance

Point a room’s doorway into another colored room to connect them: the parent wall gains a matching opening, and the child takes its parent’s color. A solid threshold marks the joint. Halls, stairs and lifts stay neutral.

Select a built room to see the shortest route from the main entrance and its numeric cost. The entrance starts at **0**; walking one cube costs **1**, each stair rise costs **1**, and an elevator ride costs **2** regardless of height. Walking to and from the lift still counts. A broken shaft provides no shortcut. Escape clears the selection and route.

**Backspace** removes the selected built room, including during a move preview. **Z** restores it and its cables. Remove supported upper rooms first; blocked removal highlights the cubes that would lose support. No selection means Backspace does nothing.


Surrounding blocks now have complete pedestrian paving, crossings across the narrow streets near junctions, and matching window openings. The wide main road has no crossing. Gray buildings come from a connected room generator; see [generator conditions and preview](GENERATOR.md). Run `./tools/block_city/generate_building.sh --seed=42 --preview` from the project folder to inspect a separate generated building without changing your construction save.


While holding a room, the **bottom-left Up / Down arrows** select a floor. Placement stays on that floor even underneath higher rooms; upper stories fade to 8% opacity. The selected floor persists for the next piece and across palette changes. **Escape** puts the room aside, clears the floor lock and restores full opacity. Picking up another piece then uses automatic roof targeting again. Height/depth limits, support and collision rules still apply. The arrows also work while moving an existing room and within basement mode.


Facades distinguish the ground floor, middle storeys and exposed top: tall ground-floor glazing, larger framed entrances, smooth same-color base relief, and a light cornice/window treatment at the top. Gray neighbors use the same proportions. The styling changes the model details, not room size or placement rules; low-wall view still removes upper trim and glazing.


An uncovered stair gains a compact concrete rooftop access enclosure in roofed view: offset half-width housing, small door, raised sill and a solid weather cap. It disappears in cutaway views or when another level is built directly above. The room footprint and stair connections stay unchanged.


To remove a cable node, put the room aside, click its socket (the selected ring turns yellow), then press **Backspace**. Its incoming wire and dependent daisy-chain branch are removed; rooms and independent connections remain. **Z** restores the whole branch.


Exposed elevators now finish with a square concrete rooftop machine room and service door. Switch to a cutaway view to see the motor, cable drum and ropes. Extending the shaft moves this housing to its new top; building a room directly above removes it. Halls automatically receive concrete roofs in roofed view, only where there is no occupied cell above.


Room and hall roofs join into a continuous concrete surface at each height. A low concrete rim follows the outside outline, including inset corners, without internal dividers between adjacent cells. Both the roof and its rim disappear in cutaway views.


The bottom-right version label identifies the demo release, starting at **v0.1.0**. Its single source is `scripts/block_city/demo_version.gd`; increment the patch for fixes and minor version for new gameplay features. The top-right FPS counter refreshes twice per second.


## Hierarchical editor — v0.2.0

The demo starts with an empty hand. Click a building to select it; click again to select its floor, then a nested group, then the room. The top-left breadcrumb buttons return to a larger scope. Selection only highlights geometry.

- **Shift-click** toggles individual rooms. **Command-G / Ctrl-G** groups the selection; groups can nest and survive saves.
- **Move**, **Copy**, and **Delete** apply to the full selected scope. Copy starts directly above the source, one selection-height higher. Move or Copy enters placement; **R** rotates the entire selection, the floor arrows change height, and click or **Space** commits. **Escape** cancels.
- **Backspace** deletes the current selection. **Z** undoes a complete move, copy, delete, or grouping in one step.
- Copies preserve room geometry, doors and independent group nesting. Utility feeds remain with the original; wire new copies separately. Moves carry existing attachment points and validate their routes.
- Buildings are connected room components; floors derive from room heights. Groups live in each room's ordered `groups` ancestry, so room-index changes do not break membership. A group spanning floors or buildings appears above those scopes.

All edits preserve the existing support, occupancy, staircase and height restrictions. Invalid edits show the affected cells and make no partial changes.

## Land purchases — v0.3.0

The neighborhood has nine parcels in a 3×3 arrangement; each parcel provides a 3×3 construction footprint. The center is owned initially. Hover over an unowned plot or its gray building and click **+ Purchase**. Purchase is free, including across roads, and clears that plot to flat land. The former side roads immediately beside the central lot are now pedestrian paving; the wide front road and remaining streets stay in place.

Ownership is saved with construction. Old saves start with central ownership. Z undoes a purchase (after undoing later construction); New Game resets to the center parcel. All room placement and editing rules, basements and one-cell upper-floor overhangs apply per owned plot. Ground-level roads and sidewalks cannot be built on. Separate buildings use their own main sidewalk entrance for route distances.

Parcel coordinates and stable IDs are defined in `scripts/block_city/land.gd`; ownership and purchase transactions live in `model.gd`. `land_test.gd` and `land_interaction_test.gd` cover expanded placement, editor validation, purchase hover, demolition, save compatibility and undo.

## Surface tools and responsive construction — v0.4.0

The bottom-left lightning, pipe and vent icons select a drawing brush. Hold the left mouse button and drag across room faces, roof tiles, cutaway floors or owned ground. A face outline shows the exact target. The path fills intermediate tiles and turns shared-edge corners; dragging backward retracts the preview. Release commits the entire stroke; Escape cancels, Z undoes and Backspace removes the hovered tile of the selected network. UI, menus and camera drags cannot commit a stroke. Soft pentatonic notes accompany newly snapped tiles.

The electrical brush joins existing lines anywhere on the same face tile and can extend power from a room supplied by the existing pole/transformer system. Unpowered electrical joints are amber. Pipe and vent networks are saved route geometry, with no water/air simulation yet. Room moves transform attached routes; connections that no longer share a physical edge are removed. Room deletion removes incident routes. Copy currently duplicates rooms/groups only, not utilities.

While holding a room: arrows translate on the current floor; 1–9 select floors; `,` / `<` step down, `.` / `>` step up; F cycles the entrance; R rotates. Stairs and elevator sections align with matching sections below until manually overridden. The held geometry is visible through walls, with opaque green/yellow/red door status. Built mats remain depth-tested. Manual floor selection also works while drawing utilities.

Construction writes physical occupancy immediately, then runs room-access, power, color and future-supply analysis on a separate thread using an immutable snapshot. Later edits invalidate old results. Scene refresh keeps unchanged neighbors/rooms and spreads feedback redraws across frames. The measured nine-parcel fixture dropped from ~18.8 seconds for the model placement to ~2 ms; this is a headless commit measurement, not a claim about GPU frame rate. Future-placement checks also stop at the first legal option instead of collecting every legal placement.

Implementation: `surface_picker.gd`, `utility_network.gd`, `utility_view.gd`, `utility_button.gd`, `analysis_worker.gd`. Focused checks: `utility_test.gd` and `construction_controls_test.gd`, plus the existing placement, power, editor and save suites.

## Concrete and lighting — v0.4.1

All room types and their palette/held previews use concrete gray. Powered rooms have warm yellow window glow. Both cutaway views reveal ceiling fixtures and soft floor lighting; removing the power supply extinguishes them, and undo restores them. Saved type/color IDs remain intact. Lighting uses emissive glazing and lightweight shader pools, without adding dynamic shadow lights per room. `lighting_test.gd` covers supply, separate floors, drawn-wire propagation, disconnection, undo and cutaway lighting.

## Sidewalk purchases and floating city — v0.5.0

Hover an unowned sidewalk tile and use **+ Purchase** to acquire a free 3×3 section. Sections can overlap existing ownership to fill the narrow gaps between lots. Already owned cells are kept, new ground becomes buildable, and overlapping purchases do not duplicate ground meshes. Gray buildings touched by a purchase are cleared; player rooms remain. Interior roads stay public and cannot be purchased. The first nine parcel IDs are unchanged, preserving old construction saves; new sidewalk IDs, placement and undo are saved normally.

The outer road ring is removed, shrinking the map by one tile on each edge. Its 17×19-tile surface now floats over exposed soil strata and bedrock. The front cutaway shows foundation piles, metro tracks and a stationary carriage; tunnel openings continue through both ends of the section. These are visual details only. `terrain_view.gd` owns the cutaway geometry, while `land.gd` shares the map bounds, retained streets and parcel definitions. `floating_land_test.gd` checks sidewalk coverage, road exclusion, bounds, save/load and undo.


### v0.6.0 — transformer and small poles

The new pole palette piece has half the original mast height and three terminals: one input and two outputs. The starter transformer beside the lot has a preconnected input and three outputs. With an empty hand, click an output terminal, then another pole or a room wall socket. Escape deselects; Backspace on a selected equipment terminal removes that cable branch. Pole movement carries its connections; copying produces an unpowered pole. The cabinet occupies its ground tile; poles reserve their headroom and cannot support rooms.


### v0.6.2 — moving transformers and parallel feeds

Click the transformer body, then Move. Click/Space places it; Escape cancels; Z undoes. All attached cables follow. Each pole terminal can now take an input or output, so all three transformer feeds can connect to one pole. Cables share a parallel curve and match terminal order automatically. Existing cords no longer block room placement or movement.
