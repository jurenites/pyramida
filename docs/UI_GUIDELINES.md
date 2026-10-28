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

Keep the resource bar's paper background and padding, without an outer outline.

Reserve three digits of width for the day, and three digits on each side of every resource and population `current/capacity` readout. Reserve a further three digits for the food demand `−N`. Keep the reserved space when showing single digits. Icons stay before their values and do not shift when counts change within those widths; do not display leading zeroes or placeholder characters.

Symbols have no decorative frames. Hide each resource, including water, until the settlement first obtains it in storage or citizen cargo; natural deposits alone do not reveal it. Starting supplies are already obtained. After discovery, keep its count visible even at zero. Save this history per settlement, and start a new history for each new game. Hidden entries take no space in the bar. At narrow window widths, wrap resource entries onto another row; keep menus below the occupied bar. Construction lists scroll vertically when their contents exceed the available height.

## Idle citizens

Keep the citizen detail text and job dropdown hidden. Reuse the total population counter, with the person icon on the left and the value on the right. Adults count as idle after three continuous simulation seconds with no active job, movement or cargo. Player-directed travel is busy until arrival. Unassigned adults display Willager, regardless of appearance, instead of Idle; assigned occupations and Kid labels stay unchanged. Busy citizens leave the queue immediately. Always show population / completed housing capacity; include the idle count in the existing population hover tooltip. The person icon stays borderless in every state, without a wrapping selection outline. Clicking the person icon cycles through idle adults in citizen order, selecting exactly one and bringing them into view. Assignment uses the existing right-click workplace/resource commands. Recompute the queue on each click, skip busy citizens, wrap at the end, and reset the cursor and idle delay when switching settlements.

## Day and night

All top-bar resource readouts use icon then number, including water. The day count uses a sun during daytime and a moon at night, with a compact rotating cycle arc around the icon. Its slot is 32 × 32 points, the arc radius is 13 points, and the inner symbols use 75% of their previous size; strokes remain 4 points. Keep this in the resource bar; no separate central dial or daylight countdown. Cool the UI paper and sand toward blue at dusk, preserving yellow selection outlines.

## Object names and selection

Round each footprint bracket's bend with a subtle curve, including construction-site selection and hover. Keep the four separate open brackets and the shared 4-point stroke; soften the bend over at most 6 points along each arm, capped at half the arm length for small footprints.

Hovering an inspectable world object replaces the sand tile marker with its own floor outline and shows its name above it on a transparent background. Living objects use circles, except selected citizens and kids, whose entire animated body has a hollow yellow outline with no foot circle. Buildings and other nonliving objects use rectangular corner brackets matching their footprint. Use the same `#FFC471` 4-point stroke as selection. Hover never selects the object, adds resource rows or shows construction progress. Avoid doubling the outline when hovering an already selected object. Selecting keeps the name visible with a black background and adds essential resource rows: icon first, then current/capacity, such as a log icon and `3/3` or a berry icon and `2/3`. Use actual inventory capacity, including older saves. Children display “Kid” and can be inspected without receiving adult work orders. Show object information only in the label above the object; do not duplicate its name or resource rows in the top-left corner. Keep existing contextual actions such as water collection available. Omit floor numbers, resource label sentences, regrowth explanations and building descriptions. Labels follow the object, respect hidden world entities and remain within the logical viewport. Bottom instructions and persistent goals remain hidden.

Unselected citizens behind buildings show only their concealed body edges in muted warm grey `#C5BCA8` at 95% opacity. Selected citizens use the shared yellow 4-point body contour over both visible and concealed edges. Keep the selected contour when the citizen is fully exposed.

## Sand tile hover

Hovering revealed, flat sand outlines exactly one 0.5×0.5 terrain cell with a closed four-sided rectangle, projected from its real floor plane through the current camera. Use the shared yellow selection colour and 4-point stroke. Hide it over objects, fog, unloaded ground, sloped terrain, UI, menus, camera rotation and drag selection. The marker follows terrain cells rather than the larger 1×1 room footprint.

## Construction placement

Building placement replaces the roaming hover marker with a full-volume outline: all eight corners of a cuboid and the actual exterior edges of irregular Blueprint shapes. Keep the shared translucent yellow 4-point stroke visible through geometry. Follow preview rotation, floor and placement offset; clear the outline on cancellation or when the cursor leaves the world view. Ordinary building selection stays flat.

## Selected-building actions

Settings offers an opt-in Debug mode. Builders then construct without consuming materials. Selected ordinary construction sites show a purple, 4-point-bordered wand-and-sparks button beside Move and Delete, with `Finish · Debug` on hover. Finish completes the selected site immediately once its supporting structure exists; it stays hidden during normal play and for planting, relocation or removal jobs.

Keep Move, Copy and Remove together in the top-center selection menu. Copy uses two overlapping rectangular sheets; Remove uses a bin. Show `Copy · C` and `Remove · Backspace` only on hover, reflecting customized bindings. Ordinary construction sites offer Move and Delete from the moment they are placed, even before delivery or building starts. Delete reuses the bin icon and shows `Delete · Backspace` on hover. Backspace deletes the inspected construction plan or queues dismantling of a completed building. R retains rotation during placement and removal during inspection. The menu hides on deselection and for relocation, removal or salvage sites; plants retain Move/Replant only. Center the entire visible action group and avoid overlap with the resource and top-right toolbars.

Fully harvested trees and palms disappear immediately, with no stump or removal action. Seedlings and trunks with remaining logs retain Replant.

## Menu positioning

Menu actions start 160 points from the top, centered horizontally, with a reserved heading area. The home menu order is Continue, Play, Settings, then Quit. Hide Continue entirely until a playable save exists. Reserve one blank action row above the save slots and difficulty choices only when Continue is available so Play, the first New game slot and Sand share the same click area. The slot page is titled Select slot; empty New game slots use warm terracotta text and remain clickable. Page headings and differing content heights must not recenter the action list. Recalculate hover after page changes and layout updates, including when the cursor stays still. Difficulty order is Sand, Fields, then disabled Snow; hover labels are Normal, Easy and Coming soon.

## Cursor

Keep the custom cursor visible throughout the game, including over clickable controls, text fields and resize handles. Do not switch to a system hand or other cursor shape.

## Typography

Use exactly two font sizes: **22 points** for all UI text (the former Pyramida title size), and **32 points** for the **Pyramida** title. Use `UIVisualTokens.UI_FONT_SIZE` and `TITLE_FONT_SIZE`; labels, values, menus, tooltips and Blueprint controls all share the ordinary size. Measure reserved counter widths at that size and let construction rows expand to fit their labels. Display density scales typography once with the rest of the UI.

## Collected wild roots

Vines appear in Nature only after the first root is collected. Show the remaining count in brackets beside the name; keep the row visible and dimmed/disabled at (0). Other seeds remain unlimited. Use the existing selected-plant action for Collect root; no additional resource bar, instruction panel or goal display.

Bushes use the same discovered/remaining-count menu behavior as wild roots, labelled Berry bush (n). The selected bush’s existing Move action collects it for later planting; show no seed terminology or extra instruction panel.


## Speech bubbles

Speech bubbles contain one icon and no text, count or persistent instruction. Use the editable 32-point SVGs in `assets/ui/desires/`, with 8-point padding. People and buildings share one request queue in the active view: four seconds visible, one second quiet, and a minimum twenty-four-second repeat delay. Remove resolved requests; preserve each building's turn even when many buildings need the same service. Selection never bypasses the queue.
