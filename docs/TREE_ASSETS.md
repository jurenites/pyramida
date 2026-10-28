# Living and dead trees

The vertical settlement now uses tall faceted trunks with plain ground entries, forked branches and three removable log sections. Living trees have a simple green crown; dead trees have bare forks. These are original editable meshes following the visual direction requested for [Sokpop's Pyramida](https://sokpop.itch.io/pyramida).

## Harvesting

Each full tree contains exactly three logs. Reserving a log does not change the standing tree. A completed cutting job transfers one log into a citizen's cargo and removes the highest remaining trunk section:

`3 logs → 2 logs → 1 log → removed`

The living crown belongs to the uppermost section, so it disappears on the first cut and never moves down onto a shorter trunk. The remaining top shows exposed end grain. Picking bounds shrink with the remaining geometry. The short base stays the same width as the trunk and disappears with the final log; it is not a fourth resource.

Once chopped, living and dead trees keep their remaining trunk sections until citizens finish cutting them. The final log removes the tree entirely; legacy exhausted stumps are cleared on load. New worlds contain both kinds. Older saves without an explicit kind default to living trees and retain their remaining logs and reservations. Legacy regrowth timers remain loadable but are inactive.

## Assets and code

- `data/settlement/tree.tscn` and `tree.glb`: living tree.
- `data/settlement/dead_tree.tscn` and `dead_tree.glb`: dead tree.
- `tools/settlement/tree_geometry.gd`: shared authored geometry used by both generators.
- `tools/settlement/generate_tree_assets.gd`: regenerate only the two tree assets.
- `scripts/settlement/tree_view.gd`: update section visibility and picking bounds when log count changes.
- `tests/settlement/tree_test.gd`: physical delivery of exactly three logs, concurrent reservations, all harvest stages, saved type/count, GLB nodes, collision height and permanent harvest stages across save/load.

The full base-kit generator also produces these tree models. Tree-only regeneration leaves building and cargo files intact:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/settlement/generate_tree_assets.gd
```

Run the focused contracts with `--script tests/settlement/tree_test.gd`. The existing simulation and incremental-rendering suites also pass with the replacement models.

`artifacts/tree-harvest-stages.png` is an engine-rendered preview of both models at all four harvest states. Reproduce it with a graphical Godot run using `--script tools/settlement/capture_trees.gd`.

## Procedural nature generator

The TSCN/GLB models remain editable reference assets. In the settlement, trees and
palms now build individual geometry through `scripts/settlement/nature_generator.gd`.
The three log sections share exact ring vertices at their joints; branches and
crowns grow from that skeleton. Harvesting removes sections without rerolling the
surviving geometry. Picking bounds follow the visible generated mesh.

Living and dead trunks use the shared timber stock's 0.23 m diameter, with only
±3% seeded width variation and 6% total taper across the three sections. The base
continues that width slightly below the soil without exposed roots or a flare.
Palms also have a plain ground entry, retaining their existing upper taper and
lean. The editable living/dead reference assets use the same stock width.

Open **`scenes/settlement/NatureGenerator.tscn`** in Godot and run the current scene
(F6). Change Seed, Trunk lean, Joint bend, Palm lean or Branch min/max, then press
Generate to compare five examples of each family. Runtime preview changes are
local to that preview. To change game defaults, edit the root's Profile resource
in the Inspector and save `data/settlement/nature_profile.tres`; Generate also
works in the editor. Height and crown variation are exposed on that resource.

Angles are degrees: trunk lean is measured from vertical; joint bend limits the
change between neighbouring trunk directions, including the upright base;
branch min/max bound each branch's angle from vertical. Palms use their own lean
limit. Default tree lean is 16°, palm lean 28°, joint bend 9°, branches 28–55°.
A zero joint bend gives an upright trunk. Profiles preserve the three-log economy.

Each plant saves a small `appearance_seed` derived from world seed and its original
cell. Replanting and collected bush payloads carry that seed. Older saves acquire
it deterministically; dormant chunks preserve it. Bushes sample continuous outline
variation instead of seven repeated meshes, with a bounded 128-entry mesh cache.
Stone already uses seeded, volume-based outcrop generation; the preview uses that
same generator without changing resource capacities or mining geometry.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/settlement/NatureGenerator.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/settlement/nature_generator_test.gd
```

Add `-- --capture-nature` to the preview command to save
`artifacts/nature-generator.png` and exit. The focused test covers 100 unique
skeletons per family, angle bounds, harvesting, bounds, saved identities,
streaming and collected bushes.
