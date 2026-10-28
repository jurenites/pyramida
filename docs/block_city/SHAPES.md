# Shape supply and tuning

Edit **`data/block_city/balance.json`**. Each entry under `shapes` has a `weight` alongside its `id`, occupied `cells` and `door`. Restart after editing. Start a New Game to clear already queued pieces from an existing save.

Dimensions below are **width × depth × height**. Coordinates inside the JSON are `[x, height, depth]`.

| ID | Dimensions | Weight | Base draw chance |
| --- | --- | ---: | ---: |
| cube (hall) | 1×1×1 | 20 | 18.18% |
| domino (hall) | 1×2×1 | 25 | 22.73% |
| room_domino | 1×2×1 | 8 | 7.27% |
| bar | 1×3×1 | 20 | 18.18% |
| small_square | 2×2×1 | 18 | 16.36% |
| rectangle | 2×3×1 | 5 | 4.55% |
| flat_l / flat_l_mirror | retired; existing saves only | 0 | 0% |
| elevator | 1×1×1 shaft section | 4 | 3.64% |
| stairs | 1×1×1 U-turn stair | 10 | 9.09% |

Weights are relative: chance = weight / sum of eligible weights. These defaults total 110; the listed percentages apply when every enabled shape fits. Set a weight to **0** to stop future draws of that shape; increase it to get more of that shape. There is no finite inventory or quota. The director excludes shapes with no legal landing, then draws from the remaining weights. When nothing fits, placement remains blocked. It does not force rare pieces to catch up to common ones.

`supply.starting_shape` selects the first piece for a fresh game (currently `small_square`); it is independent of the draw weights. `supply.seed` changes the deterministic draw sequence. Undo and save/reload preserve the supply rather than rerolling it. Surface and basement have separate queues; upcoming pieces are currently hidden in the UI.

All authored cells have height zero and pieces only rotate horizontally. Shapes contain one to six distinct, face-connected cells. The door must occupy a cell with a clear outward face in the configured `normal` (default `[0,0,-1]`). `long_side_door` restricts the randomly selected entrance to either long face of an elongated room. Each ordinary room has one authored entrance (incoming room connections can add reciprocal openings), stored as local `door` and `normal` on its supply card, then as world coordinates when placed. Square rooms draw from all exterior faces. A new palette selection or successful placement draws a fresh door; cursor motion, rotation, view changes, deselection, undo and reload preserve the held choice. Rotation carries the door with the body. The landing preview uses the same door geometry as the placed room; there is no floating ceiling preview.

Existing saved rooms keep their occupied cells. The old tall shapes remain retired from new draws. A supported one-cell overhang is allowed. Ordinary room overhangs cannot carry another storey. In the current test, a hall with a brace reaching a grounded column can carry vertical stacks; it cannot anchor another cantilever.

Run `python3 tools/block_city/run_checks.py` after editing. Checks cover shape geometry, weighted selection, fit filtering, preview/door consistency, support, saves and controls. These are software checks, not evidence of human playtest quality.

`role` assigns circulation behavior: `hall` on cube/domino, `stairs` on the stair piece, `elevator` on shaft sections; absent means an ordinary room. Hall cells connect horizontally through matching openings. Stairs add a one-floor link; stacked hall cells alone do not. Door orientation rotates with the piece. Stairs need space below the height limit for their upper landing.

Elevators occupy one cube per floor. Stack sections in the same column to connect their floor entrances; a missing section breaks the route. Shafts have neutral walls, split metal doors, continuous rails and an open core, with one complete parked cabin at the base of each contiguous stack, with open bottom doors and closed upper landing doors. This construction prototype has no moving passengers, lift scheduling or power requirement. L shapes are hidden and disabled; existing placed L rooms remain, while old queued L cards become 2×2 rooms.
