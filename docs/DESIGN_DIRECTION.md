# Pyramida design direction

Confirmed by the user on 16 October 2026. These references describe desired mechanics and visual qualities, not permission to copy another game's code or assets. This document guides refactoring; it does not claim every referenced system is playable.

| Reference | Desired quality | Current foundation / next implementation |
| --- | --- | --- |
| Oxygen Not Included | Devices connected with pipes, tubes and cords | Asset access markers and water ports exist. Add explicit typed ports, connections and network simulation separately from rendering. |
| Oxygen Not Included | Furniture determines room functions: tables and chairs for dining, beds for sleeping | Furniture models exist. Room volumes, enclosure detection and capability rules remain to be implemented. A building name alone must not grant room functions. |
| Timberborn | Stacked construction with connected entrances; skyscrapers and bunkers | Distinct floor surfaces, explicit bidirectional stairs and physical hauling work. Preserve vertical access as a graph; do not infer a connection merely because buildings overlap. |
| Minecraft | Spatial subdivision and streamed chunks | The older prototype has a world streamer. The vertical prototype is bounded. Bring chunk ownership into the model only after vertical entity identity and persistence are stable. |
| Pyramida | Simple recognizable silhouettes and broad colour shapes | Updated 18 October: featureless citizens and an illustrated 3D world, with full-resolution antialiasing and thin, slightly irregular contours. The original pixel presentation remains available for comparison. |
| Cloud Gardens | Plant growth and tending form a visible part of the game | Gardens grow when watered. Once chopped, trees retain their remaining sections permanently; citizens can finish chopping them, and the final log removes the tree completely. Expand growth stages, plant variety and tending interactions. |
| All Will Fall | Optional structural load and failure | Research only. If adopted, expose beam capacity and load clearly and make failure recoverable. Do not introduce unexplained collapse. |
| ShantyTown | Buildings stacked into lived-in structures with managed accessories | Stacking and original architecture assets provide the base. Accessories should have attachment points, access needs and utility connections. |

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

Normal play starts at 1×, with optional 2× and 4× speeds. There is no gameplay pause or Space-bar pause; decisions happen while the settlement runs. Esc deselects all citizens and objects and cancels placement or drag selection. It never saves, exits, opens the menu or pauses gameplay. The toolbar exit remains the explicit way to save and return to settlement selection. The separate structure authoring workspace also suspends the settlement. All play speeds use the same fixed simulation steps; slow frames retain pending time and catch up in bounded batches without skipping work, movement, needs or resource updates.

## Code boundaries

Player-assigned construction stays in the citizen's saved memory until the entire chosen building is complete. Resource trips, meals and temporary route interruptions preserve that assignment; a new player order replaces it. After completion, the citizen remains a builder and can choose other construction automatically.

Simulation state stays in `scripts/settlement/world_model.gd`; job state remains saveable, and renderer caches are disposable. `navigation.gd` owns route searches and topology invalidation. `world_view.gd` reconciles persistent entity views, `scenery_view.gd` owns static terrain presentation, and `worker_view.gd` owns articulated characters and cargo.

Future room classification, utility networks, structural analysis and chunk ownership should each receive their own simulation module with explicit inputs and saved identifiers. Do not add these systems to the input coordinator or infer gameplay state from scene-tree meshes. Utility connection graphs and walking graphs must remain separate: a pipe connection is not a walkable route.

Original assets remain editable TSCN/GLB files. Geometry, dimensions, access markers and utility ports belong to asset contracts; resource counts, room capabilities, load and jobs belong to simulation data.

## Starting family and citizen silhouettes

Confirmed 18 October 2026: a new settlement has only a Stockpile, two adult citizens and one child. The child is an autonomous NPC until adulthood; the current tuning is three simulation days. Age and clothing identity persist in saves, and old saves retain their existing adults. Citizens follow the rounded Pyramida reference: slimmer bodies and short pill-shaped arms and legs with straight sides and hemispherical ends, no fingers, and simple solid-color clothing. Supported outfits are men’s shorts and one-shoulder diagonal robes, and women’s dresses or separate tops and skirts.

## Pyramida foundation priority — 18 October 2026

The latest user request makes Sokpop Pyramida's core village economy the immediate reference. See [the sourced research and implemented scope](PYRAMIDA_RESEARCH.md). Build from physical gathering, farming, milling, sawing, mining, masonry, housing growth. Keep existing vertical construction, but defer the broader utility/room/structural systems above until this foundation is evaluated. Exclude the alien storyline. Enemies, zombies and weapons remain unimplemented while the user decides about combat. Confirmed later on 18 October: remove the Ancient monument construction site and all pyramid-building objectives. This game develops its own identity; Sokpop Pyramida remains a reference, not a blueprint for its goals. Existing saves retire monument work while preserving carried materials. Do not add a replacement objective or goal display without asking the user.

## Illustrated rendering exploration — 18 October 2026

User screenshots establish featureless heads: no eyes, nose or mouth. Hair and clothing distinguish citizens; limbs remain short capsules. The active presentation uses unshaded solid colours, a warm paper ground, full logical viewport resolution with 4× MSAA, and a thin colour-boundary contour pass with a small static irregularity. The effect applies only to the 3D viewport, leaving GUI text, hit testing and simulation unchanged. Day/night uses a saved-time tint on the world pass. Set `illustrated = false` on the settlement root before launch to compare the previous lit, reduced-resolution presentation.

Shoulders blend into the torso, with arm pivots embedded in the shoulder and rounded hand ends. Citizens remain articulated 3D meshes, presented like flat cutouts in eight camera-relative directions; side views turn slightly toward the camera. Distance-driven steps, arm swings and a subtle body bob interpolate between simulation ticks and freeze when paused. Carrying holds the arms around the cargo. Same-level walking supports four cardinal and four diagonal tile connections, with both neighbouring cardinal tiles required for a diagonal so walkers cannot cut across unsupported corners. Cliff and building-floor travel still requires explicit connectors; natural gravel slopes are walkable.

The simplified ragdoll treatment uses two capsule sections per limb, with hidden elbow and knee pivots. Constrained angular springs give forearms and shins a little delayed follow-through: elbows bend forward, knees fold backward, and the joints settle when movement stops. This is a driven visual puppet, not a falling or collision-driven physics body. It preserves navigation, child scaling and the cargo socket. Carrying and work gestures use bent elbows; pause freezes spring momentum and relocation resets it.

## Selection markers — 18 October 2026

Selection lives on the object's floor plane, projected with the isometric camera. Living entities other than selected citizens (bushes, trees, and future animals) use circles; citizen selection uses the body contours specified below. Buildings and other nonliving objects use only four short rectangular corner brackets around their footprint, never a full-height bounding outline. Give each bracket a subtly rounded bend, including construction-site selection, so the four chevrons feel softer while retaining their open shape and 4-point stroke. Hover uses these same object-specific floor shapes, replacing the sand-cell rectangle and showing the object title above it. Hover preserves the current selection and adds no work bars or resource rows; an already selected object keeps one outline. Markers are translucent GUI strokes visible through all 3D geometry. Preserve the selected floor elevation and keep the interface free of explanatory text.

Updated 21 October: unselected citizens and kids behind buildings show only their concealed silhouette edges in muted warm grey (#C5BCA8), at 95% opacity and the shared 4-point width. Selection switches to the yellow outline around the entire character, including exposed body edges, and remains visible when no building is in front. Follow the actual animated body and child scale; keep the interior hollow. Selected citizens have no circle at their feet. Cursor hits inside a person's body select that person through the building, while empty space still selects the building. Hover and click share this geometry. Kids remain inspectable NPCs. Preserve existing hover names, selected labels and work bars without adding instructions.

## Shared UI point — 18 October 2026

Follow [the UI point guideline](UI_GUIDELINES.md). One point is one logical UI pixel, scaled only by display density. Solid UI strokes use 4 points; padding, gaps, dividers and component sizes share that unit. Selection markers use a single translucent yellow (`#FFC471`) 4-point stroke. Tree selection circles are half their previous diameter, and citizen navigation trails use the same yellow.

## Home screen world preview — 18 October 2026

Each launch and return from a settlement offers a freshly generated world behind the menu. Show its seed discreetly in the bottom-right corner. Menu navigation preserves that preview, and New Game starts the exact unplayed world shown after the existing slot and difficulty selection. Continue restores its saved settlement. The preview remains paused and creates no save until New Game is confirmed.

Updated 21 October: hide Continue entirely until a playable save exists, without a disabled button or empty home-menu row. Title the slot selection page Select slot and distinguish clickable New game entries with warm terracotta text. Keep Play, the first slot and Sand aligned as Continue appears or disappears.

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

## Bush foliage depth and density — 18 October 2026

The later screenshot references supersede the three-lobed canopy treatment: each bush is one distinct, slightly irregular rounded blob in a single muted sage green. Vary the outline and green subtly between bushes, consistently by seed and cell. Depth comes from loose overlaps between neighbouring whole blobs, not three interlocking colour panels inside every bush. Retain readable individual silhouettes and irregular colony outlines; avoid a fused mound or repeated clover shape. Apply this to existing saves without relocating resources. Keep the approved red berry dots and stock behaviour unchanged.


## Construction relocation — 18 October 2026

Select a completed building and press **M** or the **Move** button in the separate top-center selection menu to choose its destination. A valid click queues a destination ghost while the original remains in place. A constructor walks to the source and dismantles it; its original saved construction recipe becomes physical parts reserved exclusively for that move. Constructors haul and install those pieces at the new site. A different constructor can continue interrupted work. Stored contents, crop state, orientation choices and destination offset survive reconstruction. Source and destination remain reserved until completion. Buildings supporting another floor or occupied elevated access cannot be moved until cleared.

The same button and shortcut show **Replant** for bushes, full trees, remaining harvestable trunks. A constructor uproots, carries and replants the same plant, preserving berries, capacity, growth time and remaining trunk sections. Escape or right-click cancels destination placement before queuing. Jobs, packed contents, exclusive materials and partial labour survive saves; both ends remain loaded during streaming. Use existing selection-only progress bars, with no persistent instructions or goal display.

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

All UI text uses the previous Pyramida title size of 22 points. The Pyramida title grows to 32 points. Keep only these two sizes throughout the game, including menus, counters, tooltips and Blueprint controls. This supersedes the earlier instruction to preserve text sizes when enlarging icons.

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

Provide Dig and Fill tools on the existing one-metre terrain grid. Each click removes or adds a 1 × 1 × 1 m surface cube, with a volume preview and concise toolbar controls. Keep terrain changes saved and reflected in collision and navigation. Thin exposed-face contours make cuts readable while retaining the uniform sand colour. The current surface-column scope and protected placements are documented in `VERTICAL_PROTOTYPE.md`.


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
