# Connected-room inspection scene

Run `tools/settlement/play_modular_house.sh`, or run
`scenes/settlement/ModularHousePrototype.tscn` in Godot. `GODOT_BIN` overrides
the executable. The scene never opens or writes player saves.

The generator is also used by **Housing → Building plan** in the main game.
See [the object/material ledger, persistence and integration limits](GENERATED_BUILDINGS.md).
The scene remains a compact fixture for supports, exhaust and lighting.

## Inspection

- Right/middle drag orbits; wheel zooms; existing camera movement keys pan.
- **Generate** changes the deterministic room layout, upper footprint, terrace,
  windows, roof slopes and material shades. Rooms remain 2 × 2 × 2 m.
- **Exterior** cycles lower and upper cutaways. **Upper room** removes/restores
  the upper rooms and recalculates the exposed terrace.
- The brick stove and hollow chimney use ordinary canonical bricks. Floors and
  roofs reserve a shaft only where the chimney actually passes through.
- **Upgrade · 6 metal** is always visible, disabled until affordable.
  Click the supply twice, then use it. This spends the fixture
  stock and replaces masonry equipment with a metal stove and pipe exhaust.
- After upgrading, the exhaust control compares straight and exterior routes.
  Room obstruction produces a local coral marker and stops smoke. The exterior
  route follows the building bounds and attaches to an upper roof. New generated
  layouts keep the first room's roof open, so its straight outlet is normally
  clear; the original offset-room obstruction remains a regression test.
- **Sun · moving / Day / Night** previews the shared sun and physical interior
  lights. Exterior lanterns illuminate the stair and projecting balcony.
- Lights start with 35 seconds of charge, dimming over the last five. Click the
  lower wall socket to connect a visible cable to the fixture terminal. Changing
  layout, cutaway or equipment does not refill charge. Disconnecting resumes the
  remaining charge; Reset starts a new fixture.
- Hover a roof tile for **Open terrace** and gross outdoor area. This does not
  grant indoor housing capacity or subtract the chimney footprint.
- **Reset** restores the fixture and camera. Escape restores the exterior view.

The old Overhang control is hidden while generated layouts use aligned upper
rooms. The spatial rules still test one-metre diagonal braces and two-metre
pillars with a tie. An unloaded one-metre balcony has horizontal joists, without heavy diagonal
braces or grounded anchors. Those supports appear only when it carries a room. Windows reserve support and shaft clearance before being emitted.
These are gameplay thresholds, not structural engineering simulation.

## Shared implementation

`modular_house_rules.gd` owns layout, exposed roof tiles, supports and exhaust
checks. `modular_house_generator.gd` owns facades and roof profiles.
`modular_house_view.gd` consumes those records. `material_exemplars.gd` supplies
stock-based persistent variants and batched geometry. The main-game adapter
queues existing construction jobs rather than reproducing the fixture economy.

`modular_house_services.gd` holds only fixture charge and upgrade stock. There is
no main-game heat, smelting or electricity network in this scene, and its exhaust
route is procedural bounding-box routing, not a general pipe pathfinder. No
nonfunctional tables, chairs, plants or AC props are included. The real game's
beds are created separately through actual bed construction jobs.

## Checks

Run `Godot --headless --path . --script tests/settlement/modular_house_test.gd`
for spatial/service checks and
`Godot --headless --path . --script tests/settlement/generated_building_test.gd`
for layout integration, workers and save/load.

`Godot --path . --script tools/settlement/capture_modular_house.gd` captures four
layouts, metal equipment, night and distant views, checks charge/reconnection,
and writes `artifacts/settlement/modular-object-inventory.json`.
`tools/settlement/capture_generated_building.gd` captures and checks the actual
main-game placement and worker construction without touching player saves.

Updated 10 November: Generate shifts the upper storey slightly in both horizontal
axes while keeping rooms on that storey aligned with one another. Inside views
omit ceiling fixtures in the revealed rooms, retaining exterior lanterns. The
main Home tool uses its own persisted bounded offsets and paid support geometry.
