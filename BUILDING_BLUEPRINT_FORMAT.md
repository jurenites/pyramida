# Building Blueprint Format

Status: Version 2 implementation, subordinate to `scripts/building_blueprint.gd` and its tests.

The Building Constructor saves human-readable `.pyrbuilding` JSON. A blueprint remains a collection of logical physical parts; it is never flattened into one decorative mesh. Version 2 is authoritative for recipes, Sub-Unit occupancy, resource kinds, construction order, and workshop processes. An official Building may have a neighboring `.obj` whose named objects provide the editable runtime vertices for those same part IDs.

## Version 2 scope

- Bounds are positive whole `World Unit` dimensions. Support, Platform, and Sawmill are `1×1×1`; Pile is `2×1×2`.
- Every World Unit contains the canonical eight `Sub-Units` (`2×2×2`).
- Multiple logical parts may share a Sub-Unit when a structure such as the ten-Log Sawmill needs it. IDs remain unique.
- Supported part kinds are `Block`, `Log`, and `Plank`.
- Supported orientations are `x`, `y`, and `z`.
- Supported materials are Wood, Limestone, Marble, and Concrete.
- Decorative parts consume no construction resource. This is how the Pile's four marker stones remain free.
- A recipe may be derived from physical parts or explicitly declared.
- Workshop recipes may store physical inputs, outputs, and work seconds. A Sawmill process can therefore encode `1 Log → 1 Plank` in `3` seconds without requiring Blender-only metadata.
- `visual_variant` is `0`, `1`, or `2` and changes appearance without changing function or recipe.

Every part stores its identity, kind, material, source resource, Sub-Unit address, orientation, visual variant, and explicit geometry. Logs store start/end points and radii. Blocks and Planks store centre, size, and rotation. Explicit geometry lets later constructor tools add endpoint dragging, diagonal parts, and overhangs without changing the basic file model.

For derived recipes, each non-decorative part contributes one resource and its stored `resource` must match its kind and material. The included [Four Log Support](data/buildings/four_log_support.pyrbuilding) therefore produces `{ "log": 4 }`, while [Platform](data/buildings/platform.pyrbuilding) produces `{ "log": 4, "plank": 4 }`.

## Blender round trip

Build the local Blender extension:

```sh
python3 -B tools/package_blender_extension.py
```

This creates `dist/pyramida_building_tools-0.1.0.zip`. In Blender 4.2 or newer, use **Edit → Preferences → Get Extensions → Install from Disk**, choose that ZIP, and enable **Town Building Tools** if Blender does not enable it automatically.

Use **File → Import → Town Building (.pyrbuilding)** when changing logical parts, resource metadata, Sub-Unit placement, or recipes. Every Log, Plank, or Block remains a separate Blender object with Town metadata. The **Town** panel can snap selected parts to the half-World-Unit Sub-Unit grid. Export with **File → Export → Town Building (.pyrbuilding)**, then regenerate the neighboring OBJ.

Town/Godot uses Y-up coordinates while Blender uses Z-up. The extension converts coordinates in both directions. One Town World Unit equals one Blender metre; one Sub-Unit is `0.5 m` on each axis.

## Runtime OBJ geometry

Official Building pairs sit at the same level, for example `four_log_support.pyrbuilding` and `four_log_support.obj`. The OBJ object names must exactly match the `.pyrbuilding` part IDs. Godot uses the OBJ vertices while the blueprint decides which resource each named part consumes and when it becomes visible during construction.

In Blender use **File → Import → Wavefront (.obj)**, edit vertices without renaming required objects, then **File → Export → Wavefront (.obj)** over the same file. **File → Open** is only for `.blend` files and reports that OBJ is unsupported. OBJ cannot carry recipes or construction semantics, so geometry-only edits never replace the neighboring blueprint.

To reset Building geometry from `.pyrbuilding`, run:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --rendering-driver dummy --path . --script tools/export_official_building_assets.gd --log-file /tmp/pyramida-obj-export.log
```

## Development workflow

1. Run the main game and press `F2` to enter the Building Constructor.
2. Left-click one of the eight Sub-Units to place or replace the active part. Right-click removes it.
3. Use `1`, `2`, and `3` for Block, Log, and Plank; `M` changes material; `R` changes axis; `V` changes the visual variant; `Y` switches between the lower and upper four Sub-Units.
4. `Tab` switches between gray edit mode and the actual material preview.
5. `Ctrl+S` saves to `user://blueprints/developer_world_unit.pyrbuilding`. `Ctrl+Shift+S` opens Save As, and `Ctrl+O` imports an existing `.pyrbuilding` file.
6. An approved file and its matching named-part OBJ may be placed under `res://data/buildings/` and shipped as an official prefab.

Runtime construction reads paired concerns: `.pyrbuilding` supplies meaning and the neighboring OBJ supplies vertices. The same part IDs bind them. Export presets must include `data/buildings/*.pyrbuilding`, `data/buildings/*.obj`, and `data/props/*.obj`; these files are loaded through `FileAccess` and must not be omitted merely because Godot also creates imported mesh caches.
