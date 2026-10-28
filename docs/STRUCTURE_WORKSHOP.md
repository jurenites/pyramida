# Blueprint asset editor

**Roof coverings:** Assets includes **Ceramic roof tile** (a tapered terracotta barrel tile, 0.28 × 0.46 m) and **Metal roof sheet** (a 1 × 1.4 m charcoal sheet with raised edge seams, initially pitched 25°). Insert, duplicate and rotate these pieces to layer roof coverings at different angles. Ceramic rows can overlap at approximately 0.34 m spacing along their length. Edit each piece independently or group a roof section for reuse. Sources are `data/settlement/ceramic_roof_tile.tscn` and `metal_roof_sheet.tscn`, with matching GLBs. Regenerate only these models with `Godot --headless --path . --script tools/settlement/generate_assets.gd -- ceramic_roof_tile metal_roof_sheet`.

**F2 / Blueprints** opens one asset editor directly from the game or menu. The settlement pauses and resumes in place. The separate Layout gallery is no longer part of this entry flow. The editor also runs from `scenes/settlement/StructureWorkshop.tscn`.

The left library has separate **Assets**, **Buildings**, and **Prefabs** views, starting with Assets. Logs, a single plank, hay, bushes, trees, palm, raw stone, stone blocks, rock, the existing wall cooler/dish models and pipe segments belong to Assets. Schools, houses and other construction types belong to Buildings. Search within the selected view, then choose **Edit** (or double-click) to open the source meshes. **Insert** places an independent instance in the current assembly. Buildings currently open as their individual authored meshes; the confirmed design direction is to author them from reusable asset instances, such as logs arranged into a building. Existing mesh parts are not automatically converted into shared log/stone references. Older workspaces classify known buildings into the Buildings view on load while retaining their contents. The whole interface uses the shared game font, size and UI point system.

## Volumes and editing

**Volume** sets width X, height Y and depth Z in grid cells. One cell is one metre, matching `WorldGrid.CELL_SIZE`; the usual room occupies 2×2 horizontal cells and is two metres high. `2 × 2 × 2` and `1 × 2 × 2` are independent occupied-space contracts, not automatic mesh scaling. Fractional dimensions are supported. The teal wireframe shows the authored cuboid. Pivot offsets move its origin relative to the mesh. **Overlap m** defaults to 0.05 metres; geometry beyond this allowance receives a translucent red overlay, clipped to the actual out-of-bounds fragments. Red entries in the parts list identify affected parts. Show bounds also reveals the selected prefab instance's own volume.

Select a part in the viewport or parts list. The top-right **Move** controls nudge it along X/Y/Z in 0.05 m steps; drag the matching coloured arrows in the scene to move along one world axis. **Size** exposes face and corner nodes: face nodes resize one local dimension, while corners scale proportionally, keeping the opposite face or corner fixed. Dragging snaps to 0.05 m and creates one undo step; Escape cancels the gesture. Mesh resizing leaves the authored occupied-space volume unchanged so overflow remains visible. You can also drag a part along its horizontal plane or use the **Part** inspector for exact X/Y/Z, rotation and scale. Copy, remove, undo and redo are available beside the parts list. Right/middle drag orbits, Shift + right/middle drag pans, the wheel or −/+ buttons zoom, and Fit frames the model. Surface snap seats inserted components against the picked face using their occupied volume; wall-mounted components face the wall normal. Height-plane placement is available when Surface snap is off.

**+ Part** and **+ Prefab** start empty documents. **Store asset** adds the current design to this workspace's reusable library; **Save** writes the workspace to disk. Switching assets retains drafts. Inserting creates a link to the component source. Updating that source updates its existing instances, including nested prefab instances, while retaining their placement and orientation. Saved links contain the source ID rather than copied mesh parts. Older asset-reference snapshots become links when opened; explicitly local groups remain independent. Double-click a linked instance in the parts list or choose **Edit instance** to edit its shared source and occupied volume; returning updates all its instances. Source editing shows the complete source; instance timber colours and the example's hidden intermediate roofs remain instance overrides. Ordinary groups still edit only their own children. **← Prefab** commits the edit back into its parent without flattening it. Nested edits, bounds, library drafts and undo state all retain their correct component context. Undo history is session-only; document state persists.

**Village example** (also saved as `data/structures/asset-prefab-example.pyrstructure`) loads a three-level assembly with repeated room components, explicitly placed ladders and landing decks, a floor-mounted sawmill, timber storage, wall equipment and connected-looking pipe segments. Every instance remains editable. This is an asset-authoring example: pipe flow, utility effects, city generation and live settlement prefab placement are not implemented by the editor. The older volume/access simulation drafts remain readable; the Assets button returns to the asset workspace when one is opened.

## Blender and game use

**Source** reveals the selected shipped asset's GLB (or TSCN when no GLB exists) in the file manager. **Export** writes the current edited component or prefab as a GLB that Blender can import. **Import** reads a GLB back into the current draft, retaining the authored occupied volume and allowing undo. GLB exchange preserves metre scale and transforms. Export/import is explicit: changing a reference GLB does not overwrite the separately authored game TSCN automatically.

Imported mesh resources are stored under `user://blueprint_meshes/`. The `.pyrstructure` workspace references those resources; when moving work to another computer, include that folder or exchange the model as GLB. Source model paths are visible on hover in the inspector.

For existing building types, **Apply to game** persists the visual appearance for current and future instances. It retains the settlement's existing construction recipes, collision footprints, entrance markers, storage and navigation. Occupied-space contracts are editor metadata; changing them does not silently rewrite live placement rules. **Original** restores the shipped model and its editor volume into the draft and is undoable.

**Save / Open** store all library entries, prefab links, nested edit scopes, transforms, mount types, dimensions and overlap margins in `workspace.authoring` and `workspace.parts` inside the existing readable `.pyrstructure` document. Defaults and older files remain supported. Invalid imported document metadata leaves the current work intact. Save uses a temporary file and rename. The normal save location is `user://structures/workshop.pyrstructure`; Save as allows another location.

Run `tests/settlement/asset_links_test.gd`, `tests/settlement/asset_workbench_test.gd`, `structure_parts_test.gd`, `building_appearance_test.gd`, and `structure_workshop_test.gd` for authoring, Blender round trips, game appearance and F2 integration. `tools/settlement/capture_asset_workbench.gd` renders the editor, overflow example and prefab into `/tmp/pyramida-asset-*.png`. Utility source scenes and GLBs can be regenerated with `tools/settlement/generate_authoring_utilities.gd`.

## Earlier volume/access workspace reference

The following documents the retained earlier file format and study tools. Its Pieces/Rooms/Map controls and Layout detour describe the previous interface, not the default asset editor above.

## Build with individual game pieces

Choose **Pieces** in F2 to construct with individual **Log**, **Plank**, and **Hay** pieces. The palette also contains the settlement building models. All use the same shared game scenes and materials at their original metre scale; Plank extracts one actual board from the three-board cargo asset. The Rooms tab now uses shared house, log-shed and workshop models instead of stand-in cubes.

Click to place a piece against the visible surface; use Remove or Delete on the selected piece, or Shift-click the touched piece to erase it. Placement snaps along the surface in 0.05 m increments and seats the actual rotated mesh against it. R/Y rotates 90°; X and Z tilt 45° (Shift+T and T). Tilt logs upright for posts, turn boards for floors or walls, and lay tilted hay bundles across a roof. Surface snap can be turned off to use the Height plane; Q/E adjusts that plane by 0.05 m and F resumes surface snapping. Select a piece to adjust X/Y/Z, rotate, copy or remove it. Right or middle drag orbits, the wheel zooms, and Fit recentres the view.

The **Building** selector opens every standard building, including **Well**, **Ladder**, **Pile**, and **Platform**, as its individual original mesh components. Click a component to move, rotate, copy or remove it, or use **Add piece** to add logs, planks, hay or other assets. Switching buildings keeps each unsaved draft; Undo/Redo and Save/Open retain the selected building and the other drafts. **Original** restores the shipped appearance into the current draft and is undoable. **Cabin** remains a separate custom example.

**Apply to game** saves the selected building's appearance for all instances of that type, including existing buildings and future construction, across launches. Appearance files live separately in `user://building_appearances/`; source TSCN/GLB assets, recipes, collision footprints, entrance markers, capacity and navigation remain unchanged. Save/Open stores the editable workspace; applying is a separate explicit action. To revert a game appearance, choose **Original**, then **Apply to game**. Optional roof/deck visibility, crop growth and connected pile corners continue to follow gameplay.

**Cabin** loads an undoable example made entirely from these individual pieces; **Clear** starts an empty piece building. Piece edits share Undo/Redo, Save/Open and F2 pause/resume with the workshop. Files retain each asset identifier, position and orientation in optional `workspace.parts`, and the active tab in `workspace.piece_editing`; older documents remain valid. Piece construction is saved alongside the existing Rooms/Map drafts and does not automatically convert into room occupancy, structural/access simulation or a live settlement recipe. Intersecting joints are allowed.

Run `tests/settlement/building_appearance_test.gd` for standard model components, draft switching, persisted appearances and validation. Run `tests/settlement/structure_parts_test.gd` for shared-mesh identity, rotated picking, actual viewport placement, editing, history and persistence checks. `tools/settlement/capture_structure_parts.gd` renders the cabin to `/tmp/pyramida-blueprint-pieces.png`.

## Sculpt a building

Choose a starting shape (L, T, stepped tower, courtyard, cellar house or single unit), or edit the current draft. Each square on the Grid tab is one occupied world unit, with X/Z as horizontal coordinates and Y as elevation. The 3D workspace uses normalized unit cubes; these are logical world units, not a replacement for the settlement's metre scale.

- In 3D, hover a roof to preview the next unit above it; hover a side to extend sideways. Left-click places it. The cursor picks actual occupied units, so holes in an irregular footprint remain holes. Erase/Shift-click and the brace tool target the touched unit itself. The Grid tab still edits its chosen level directly.
- **Auto** is on by default: the cursor chooses height from the visible surface. **Q / E** locks one level below/above the current cursor level; the **Level** field also locks height. This plane passes through existing buildings for underground and interior editing/repainting. **F** or **Auto** restores surface snapping. Ground is **0**; negative layers extend underground. Available levels are **−6 through 12**, with X/Z between **−12 and 12**.
- Change the plan centre to edit beyond its visible 9×9 window.
- Select stone, timber or clay to paint a unit's appearance. These are workshop material tags, not settlement resource recipes.
- **R** rotates the shape by 90 degrees. **Right or middle drag** orbits; the wheel zooms. **Fit view** recentres the camera. **Slice** hides units above the current layer and locks that level; hidden units cannot intercept cursor picking.
- Undo/Redo restores geometry, braces, work settings and assembly edits. Shortcuts are **Ctrl/Cmd+Z**, **Ctrl/Cmd+Shift+Z**, or **Ctrl/Cmd+Y**.

The summary distinguishes occupied volume, footprint area and bounding dimensions. For example, an L-shaped building can occupy three units inside a 2×1×2 bounding box. The empty fourth unit remains available for another building.

## Stack and brace

Switch to **Map** and use the **Advanced → Move** tab. Hover an existing roof to position the draft on it; **left-click in 3D** or **Place** snapshots it into the test assembly. The preview never intercepts its own cursor ray. You can also position the draft with X/Y/Z offsets or the Grid tab and rotate with R. The next position comes from the hovered surface rather than incrementing a global layer. The occupied unit nearest the local origin is the placement anchor, preserving ground-level pivots for cellar shapes. Copies may have different shapes, materials and rotations.

Occupied units must not overlap. A unit needs a supported unit directly below it, or a diagonal brace from a supported lower neighbour. Units at or below ground use assumed earth bearings in this authoring model. This tests support topology, not weight, soil strength or collapse physics. Pedestrian access is checked separately, as described below.

To add a manual brace, select the **brace icon**, pick an occupied lower unit, move one layer up, then pick its horizontally adjacent upper unit. The upper endpoint must belong to the draft; the lower one may belong to an already placed building. A brace rises one level and spans one tile along X or Z. Shift-click its upper endpoint in brace mode to remove braces ending there.

**Auto-brace** adds braces only where real supported lower neighbours exist. It will not invent foundations beneath floating buildings. Remaining unsupported units stay red and placement is blocked. Removing a placed bearing is blocked if another building depends on it.

Use the selection arrow to click a placed building, or choose it in the assembly list. The copy icon copies it into the sculpt editor. Editing that draft leaves the placed instance intact. **Example** demonstrates a below-ground cellar, a stone L-shaped base, a clay T-shaped hall with two diagonal braces, and a timber upper floor.

## Move, connect and furnish

**Vary** creates an undoable irregular shape with a material variation and an extra upper room. **Map** places snapshots and joins them when a door connects to another building. Select an existing building and use the four-way arrow or **M** to move it. Hover a surface and click to commit; **R** rotates. Escape or Cancel returns it to its original location. Moves preserve doors, ladders and utility placement, and cannot leave another building unsupported. The original remains saved until a valid move commits.

The door tool places an entrance on the clicked wall. Red door glows and a short speech bubble request access. Reachability starts at the virtual map boundary, crosses clear ground and exposed roofs, and changes floors only on explicit ladders. The ladder tool adds a wall ladder from its base to the next floor; Shift-click removes it. Stacking never creates an implicit connection. Sidewalk equipment occupies walking space. These are blueprint access checks, not live citizen pathfinding in the colony.

Placement and moves require every building's entrance to remain reachable. A door facing an adjacent building's wall creates a bidirectional passage into that room; the neighbouring building does not need a matching door. Door-connected rooms merge into one building on placement, movement or entrance editing: two single rooms become one 1×2 footprint. Selection, copy, move, rotation, removal, undo and save operate on that whole building. Internal walls disappear, while exterior entrances, utilities, ladders and total work are retained. Connected rooms on the same floor can share an exterior entrance, but a sealed group cannot provide its own access. Walls touching without a door, vertical stacking and braces never create a passage. The preview evaluates the proposed assembly before placement. Removing a building or ladder, changing a door or adding sidewalk equipment cannot cut off existing access. Older saved assemblies still open for repair, and sculpt drafts can remain incomplete.

Select **AC** or **dish** to place an accessory on the clicked wall. The **Wall / Sidewalk** selector chooses a facade mount or a unit standing at the foot of that wall; the horizontal position follows the click. Shift-click with the matching tool removes accessories of that kind from that face. Doorways, covered faces, unsupported sidewalk placements and overlapping equipment are rejected.

**Upgrade AC / Upgrade dish** chooses a random clear facade location for the selected building (or the sculpt draft). Each upgrade installs once. Its exact position persists through rotation, moves, saving, undo and redo; it never rerolls on load. Connected buildings without AC can request it through a local speech bubble. Accessories currently provide authoring detail, not cooling, power or utility-network simulation.

## Construction work

The **Work** tab controls work per occupied unit, work per brace and preview worker count:

`total work = occupied units × unit work + braces × brace work`

One work unit is one worker-second. The preview estimate divides total work by the number of workers, assuming uninterrupted parallel work. It excludes walking, hauling, resource delivery, fatigue and access constraints. The blueprint saves the unit and brace work budgets; the workspace also remembers the preview worker count.

## Save and load

**Save** writes the draft and assembly to `user://structures/workshop.pyrstructure` by default. **Save as…** chooses a project or other folder; **Open…** reads an existing file. Ctrl/Cmd+S saves, Ctrl/Cmd+Shift+S opens Save as, and Ctrl/Cmd+O opens a file.

Files are readable JSON with format `pyramida-structure-workshop`, version 1. Each blueprint contains its name, a sparse `cells` list (`at: [x, y, z]`, material), a `braces` list (from/to coordinates), `work_per_cell`, and `work_per_brace`. Optional `door`, `utilities` and `ladders` arrays store wall-cell coordinates and cardinal facade directions. Utilities also save kind, mount and exact local offset. Older files receive a deterministic door. Assembly entries snapshot those same fields in placed coordinates. An optional `workspace` object remembers the draft placement, rotation, mode, active layer, automatic/manual height mode and preview worker count. Braces may refer to a preceding assembly entry as their bearing. Imports validate coordinates, material tags, duplicate cells, work ranges, assembly overlap, attachment clearance and complete-assembly support (independent of list order) before replacing current work. Saves use a temporary file and rename.

The last default save reopens automatically. Returning to the settlement retains unsaved edits in memory, but quitting the application requires saving first. Open, presets and the example are undoable. Invalid imports preserve the current workspace. Maximums are 2,048 units/braces per blueprint and 64 placed buildings.

The checked-in example is `data/structures/stacking-example.pyrstructure`. The old `.pyrbuilding` part/OBJ editor remains a separate format; this workshop does not silently reinterpret or overwrite those assets.

## Validation

Run `python3 tools/settlement/run_checks.py`, or run `tests/settlement/structure_workshop_test.gd` with headless Godot. The cursor suite checks roof/side snapping, gaps, ghost exclusion, cutaways, underground and interior overrides, and real camera/mouse/keyboard input. The structure suite covers sparse occupancy, rotation, below-ground coordinates, support propagation, cross-building braces, work accounting, JSON validation, undo/redo, file round trips and settlement pause/resume.

The access/movement/utility regression suite is `tests/settlement/blueprint_life_test.gd`; `tools/settlement/capture_blueprint_map.gd` renders the updated player workspace to `artifacts/blueprint-map.png`.

Render both workshop views with `tools/settlement/capture_structure_workshop.gd`. This also refreshes the checked-in stacking example. Screenshots are written to `artifacts/structure-workshop.png` and `artifacts/structure-workshop-cellar.png`.

To launch the full game directly into its debug editor on this Mac:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/alexanderilivanov/Projects/pyramida -- --structure-editor
```

The editor runs as an overlay within the same game process. F2, Escape or Back closes it and returns to the previous game/menu state.

Reusable game props appear in **Assets**, including Stick, Bed, Bench, Table, Urn, Food crate, Water bucket and Pottery. Construction corners instantiate `data/settlement/stick.tscn`, the same source exposed by the asset editor; the short branchless marker remains unchanged in shape and size.
