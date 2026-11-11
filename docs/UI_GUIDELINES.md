# UI point guideline

Confirmed 18 October 2026. All UI measurements use a shared **point**: 1 point equals 1 logical UI pixel. Display density scales the entire UI once; at 2× density, 1 point occupies 2 physical pixels. Window resizing and camera zoom do not change UI point sizes. This is the game's UI unit, not the print measurement of 1/72 inch.

## Lines and spacing

- Solid UI lines are **4 points** thick: panel borders, icon strokes, selection circles and corner brackets, focus indicators, progress-bar borders, and dividers. Use a single stroke, without a thicker backing outline. Selection markers use yellow `#FFC471` and retain their translucent x-ray appearance. Tree selection circles use half their previous diameter. Citizen navigation trails use the same `#FFC471` yellow.
- Padding is the empty space inside a component's border. “Padding 1 point” means 1 point on each side unless a side is named. It does not include the border's own 4 points.
- A gap is the empty space between components. “Vertical gap 1 point” means 1 point between stacked items; “horizontal gap 1 point” means 1 point between side-by-side items.
- A divider is a 4-point solid line. Its surrounding gap is separate: a horizontal divider with a 1-point gap above and below occupies 6 points in total.
- All other UI dimensions use multiples of this same unit. Existing comfortable layouts remain: for example, panel padding is 8 points horizontally and 5 points vertically; toolbar buttons are 40 × 40 points. A request for a 1-point unit does not make every spacing value 1.

## Implementation

Use `UIVisualTokens.POINT`, `LINE_WIDTH`, `PADDING_UNIT`, and `GAP_UNIT`. Shared panel padding uses `PANEL_PADDING_X` and `PANEL_PADDING_Y`. Express component spacing as a count multiplied by the shared unit. `DisplayScale` handles monitor density; do not multiply individual UI measurements by monitor scale. Game icon viewports and geometry use their compact base size, reduced by 50% from the earlier enlarged version. Procedural icons use GAME_ICON_SCALE for geometry and retain LINE_WIDTH for strokes. Building and speed SVGs rasterize at their viewBox dimensions with 4-unit source strokes, producing 4-point visible strokes. Panel padding and borders retain their existing sizes.

These measurements apply to the GUI, including world-anchored selection and progress overlays. Three-dimensional model dimensions and the illustrated world's contour effect keep their separate rendering contracts. Keep the bottom instruction panel hidden and communicate through concise labels and visual feedback.

## Resource bar

Building icons are solid coloured isometric miniatures in the existing 34-point slots, with no decorative outline. Their editable SVGs live in `assets/ui/buildings/` and are generated from the shared palette by `tools/settlement/generate_building_icons.gd`. Draw them at their native size; any strokes use the shared four-point width. Well object hover and selection show only the name and one Water current/capacity row, without a rain-rate line. Home capacity is one resident and four Food per room.

Resources use solid coloured miniatures from `settlement/resource_icon.gd`, sharing the material palette with the world. Keep log/board silhouettes long and berries small; minerals differ by profile as well as colour. Construction menu rows show only the building miniature and name. Show material costs, capacity gains or input → output in the building’s hover tooltip; do not repeat those lines in the list. Storage quantities describe one shared capacity. Selected workplaces may show the same chain; hidden instructions/goals remain unchanged.

Keep the resource bars' paper background and padding, without an outer outline. Place the top bar flush against the top-left viewport corner, with no outer gap. Start with the day/night counter, then population, food and water; coins belong after water when currency is implemented. Materials appear in a vertical right sidebar: logs, hay (the current `grain` resource), planks, stone, masonry blocks, pottery, then any other materials. Hide the sidebar until at least one material is discovered. Keep construction menus beside it without overlap.

Home placement previews highlight the existing population/capacity count in the palette’s timber colour and briefly scale it up. Its capacity includes completed Homes, queued new Homes and the valid placement preview; upgrades and moves add no capacity. Keep the actual resident count unchanged. Placement, cancellation and completion pulse the same counter, with built/planned/preview amounts available on hover. Well placement shows the local water yield per four seconds of rain (3 on a puddle, 2 nearby, 1 elsewhere, multiplied by well units); object hover shows only stored Water/current capacity.

Reserve three digits of width for the day, and three digits on each side of the top-bar resource and population `current/capacity` readouts. Reserve a further three digits for the food demand `−N`. Keep that top-bar reserved space when showing single digits. The right material sidebar instead fits its widest currently visible icon-and-number row plus the standard panel padding, expanding or shrinking as the displayed numbers change; do not reserve unused digits there. Icons stay before their values; do not display leading zeroes or placeholder characters.

Symbols have no decorative frames. Hide each resource, including water, until the settlement first obtains it in storage or citizen cargo; natural deposits alone do not reveal it. Starting supplies are already obtained. After discovery, keep its count visible even at zero. Save this history per settlement, and start a new history for each new game. Hidden entries take no space in the bar. At narrow window widths, wrap the top-bar entries onto another row; keep menus below the occupied bar. Construction lists scroll vertically when their contents exceed the available height.

## Idle citizens

Keep the citizen detail text and job dropdown hidden. Reuse the total population counter, with the person icon on the left and the value on the right. Adults count as idle after three continuous simulation seconds with no active job, movement or cargo. Player-directed travel is busy until arrival. Unassigned adults display Willager, regardless of appearance, instead of Idle; assigned occupations and Kid labels stay unchanged. Busy citizens leave the queue immediately. Always show population / completed housing capacity; include the idle count in the existing population hover tooltip. The person icon stays borderless in every state, without a wrapping selection outline. Clicking the person icon cycles through idle adults in citizen order, selecting exactly one and bringing them into view. Assignment uses the existing right-click workplace/resource commands. Recompute the queue on each click, skip busy citizens, wrap at the end, and reset the cursor and idle delay when switching settlements.

## Day and night

The first top-bar readout pairs a stationary sun or crescent in a 32 × 32-point slot with `Day N`. Keep the same day number through the night and increment it at dawn. Under the label, a short two-part strip shows warm daylight on the left and blue night on the right; a small vertical marker follows the full cycle. Use 4-point strokes and an 8-point track height, with a 2-point gap below the label. Reserve enough label width for `Day 999` so the other counters do not shift. No rotating outer ring, separate central dial or numeric countdown. Cool the UI paper and sand toward blue at dusk, preserving yellow selection outlines. Other resource readouts remain icon then number.

## Object names and selection

Completed house selection drills down on successive clicks: whole joined structure, clicked floor, clicked room. Use House, Floor and Room in the existing world label, with resident/food totals scoped to that selection. Draw the usual four-point footprint brackets on each selected level; keep hover from duplicating brackets or names inside the selection. Same-floor room switching keeps room scope; another storey starts at floor scope, and another house starts at structure scope. No automatic camera movement, cutaway, floor-number label or persistent hierarchy panel. Move, Copy and Remove operate on the selected scope; Upgrade appears only for a single selected room.

Round each footprint bracket's bend with a subtle curve, including construction-site selection and hover. Keep the four separate open brackets and the shared 4-point stroke; soften the bend over at most 6 points along each arm, capped at half the arm length for small footprints.

Hovering an inspectable world object replaces the sand tile marker with its own floor outline and shows its name above it on a transparent background. Living objects use circles, except selected citizens and kids, whose entire animated body has a hollow yellow outline with no foot circle. Buildings and other nonliving objects use rectangular corner brackets matching their footprint. Use the same `#FFC471` 4-point stroke as selection. Hover never selects the object, adds resource rows or shows construction progress. Avoid doubling the outline when hovering an already selected object. Selecting keeps the name visible with a black background and adds essential resource rows: icon first, then current/capacity, such as a log icon and `3/3` or a berry icon and `2/3`. Use actual inventory capacity, including older saves. Children display “Kid” and can be inspected without receiving adult work orders. Show object information only in the label above the object; do not duplicate its name or resource rows in the top-left corner. Keep existing contextual actions such as water collection available. Omit floor numbers, resource label sentences, regrowth explanations and building descriptions. Labels follow the object, respect hidden world entities and remain within the logical viewport. Bottom instructions and persistent goals remain hidden.

Selected workplaces also show the existing person icon followed by the number of citizens assigned to that building, including `0` when unstaffed. Count saved workplace assignments through meals, supply trips and idle gaps. Put this row before inventory rows, using the same styling as house residents; hover remains name-only.

Unselected citizens behind buildings show only their concealed body edges in muted warm grey `#C5BCA8` at 95% opacity. Selected citizens use the shared yellow 4-point body contour over both visible and concealed edges. Keep the selected contour when the citizen is fully exposed.

## Sand tile hover

Hovering revealed, flat sand outlines exactly one 0.5×0.5 terrain cell with a closed four-sided rectangle, projected from its real floor plane through the current camera. Use the shared yellow selection colour and 4-point stroke. Hide it over objects, fog, unloaded ground, sloped terrain, UI, menus, camera rotation and drag selection. The marker follows terrain cells rather than the larger 1×1 room footprint.

## Construction placement

Building placement replaces the roaming hover marker with a full-volume outline: all eight corners of a cuboid and the actual exterior edges of irregular Blueprint shapes. Keep the shared translucent yellow 4-point stroke visible through geometry. Follow preview rotation, floor and placement offset; clear the outline on cancellation or when the cursor leaves the world view. Ordinary building selection stays flat. Building previews and planned shells are opaque and depth-tested; distinguish placement with the existing outline and valid/invalid tint, without revealing overlapping internal geometry. Hide objects above a cutaway rather than leaving translucent remnants.

## Selected-building actions

Settings offers an opt-in Debug mode. Builders then construct without consuming materials. For the current debugging phase, selected ordinary construction sites show a purple, 4-point-bordered wand-and-sparks button beside Move and Delete, with `Finish · Debug` on hover, even when Debug mode is off. Finish completes only the selected site immediately, without materials or citizen labour, once its supporting structure exists. The temporary shortcut is controlled by `SHOW_DEBUG_FINISH` in `scripts/settlement/hud.gd` so it can be hidden later; it stays hidden for planting, relocation or removal jobs.

Keep Move, Copy and Remove together in the top-center selection menu. Copy uses two overlapping rectangular sheets; Remove uses a bin. Show `Copy · C` and `Remove · Backspace` only on hover, reflecting customized bindings. Ordinary construction sites offer Move and Delete from the moment they are placed, even before delivery or building starts. Delete reuses the bin icon and shows `Delete · Backspace` on hover. Backspace deletes the inspected construction plan or queues dismantling of a completed building. R retains rotation during placement and removal during inspection. The menu hides on deselection and for relocation, removal or salvage sites; plants retain Move/Replant only. Center the entire visible action group and avoid overlap with the resource and top-right toolbars.

Fully harvested trees and palms disappear immediately, with no stump or removal action. Seedlings and trunks with remaining logs retain Replant.

## Menu positioning

Menu actions start 160 points from the top, centered horizontally, with a reserved heading area. The home menu order is Continue, Play, Settings, then Quit. Hide Continue entirely until a playable save exists. Reserve one blank action row above the save slots and difficulty choices only when Continue is available so Play, the first New game slot and Sand share the same click area. Reserve one action row between Settings and Quit so Quit shares the slot page Back button’s exact click area, both with and without Continue. Leaving gameplay through the toolbar X opens the title screen. The slot page is titled Select slot; empty New game slots use warm terracotta text and remain clickable. Page headings and differing content heights must not recenter the action list. Recalculate hover after page changes and layout updates, including when the cursor stays still. Difficulty order is Sand, Fields, then disabled Snow; hover labels are Normal, Easy and Coming soon.

## Cursor

Keep the custom cursor visible throughout the game, including over clickable controls, text fields and resize handles. Do not switch to a system hand or other cursor shape.

## Typography

Use exactly two font sizes: **22 points** for all UI text, and **32 points** for the game title. Use `UIVisualTokens.UI_FONT_SIZE` and `TITLE_FONT_SIZE`; labels, values, menus, tooltips and Blueprint controls all share the ordinary size. Measure reserved counter widths at that size and let construction rows expand to fit their labels. Display density scales typography once with the rest of the UI.

## Nature planting menu

Offer only Tree seed and Palm seed. Do not show vegetables, bushes or vines, including collected inventory entries. Preserve existing plants and saved orders. Keep planting feedback visual and concise, with no additional instruction panel or goal display.


## Speech bubbles

Speech bubbles contain one icon and no text, count or persistent instruction. Use the editable 32-point SVGs in `assets/ui/desires/`, with 8-point padding. People and buildings share one request queue in the active view: four seconds visible, one second quiet, and a minimum twenty-four-second repeat delay. Remove resolved requests; preserve each building's turn even when many buildings need the same service. Selection never bypasses the queue.
