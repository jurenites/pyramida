# Connected building generator

The generator creates real room records using the construction demo's shapes, door rules, stairs and cell graph. It reserves a street entrance and a hall spine, packs rooms around them with a seeded bounded search, and checks that every occupied cell is reachable from the main entrance. Floors have direct support; there are no overhangs. The top floor can step back by one column. Neighbor buildings use these generated layouts, with neutral exterior materials and the same window apertures as playable rooms.

From the project folder:

```sh
./tools/block_city/generate_building.sh --seed=42 --width=3 --depth=3 --floors=3 --preview
```

The preview opens separately, uses the normal orbit/view controls, and does not load or save your construction game. Close its window when finished. Omit `--preview` for a headless JSON export. The default output is `artifacts/block_city/generated-building.json`; use `--out=/absolute/path.json` to keep separate variants. An existing file at the chosen output path is replaced.

Defaults live in `data/block_city/building_presets.json`. Command-line values override them:

| Condition | Accepted values |
| --- | --- |
| `--seed=42` | Integer; identical conditions and seed reproduce the same layout |
| `--width=3`, `--depth=3` | 2–6 cells |
| `--floors=3` | 1–9 floors |
| `--top_setback=true` | `true` / `false`; removes the far column on the top floor when width > 2 |
| `--max_room_cells=6` | 2–6 cells per ordinary room |
| `--min_rooms=1` | Minimum number of ordinary rooms; halls/stairs do not count |
| `--allowed_shapes=room_domino,small_square` | Comma-separated active ordinary room IDs |

Available ordinary shapes: `room_domino`, `bar`, `small_square`, `rectangle`. Halls and stairs remain available for circulation. Long-room doors stay on a long side. The requested minimum is a validation threshold, not a guarantee that the bounded search finds every possible solution; an unsatisfied constraint returns an error and writes no output. This is a first prefab generator with a fixed circulation strategy, not an exhaustive architectural solver. Electricity, furnishing and plumbing are not generated.

Exports contain conditions, complete room geometry/doors and the validation result, including reachable cell and room counts. They do not replace player saves. `neighbour_footprints` controls surrounding blocks (2×3, 3×2 and 3×3 are supported); neighboring floors continue to use `street.neighbour_height` in the balance file. Restart the demo after changing these defaults because neighborhood layouts are cached during play. Neighborhood footprints are clamped to the surrounding blocks; an unsatisfiable neighbor preset falls back to a validated 3×3 layout and reports the rejected conditions in the developer log.

The streets preserve a one-cell sidewalk around every block. Zebra crossings join these paths across narrow roads near intersections. No crossing traverses the wide main road, so the opposite front row intentionally remains a separate pedestrian component.
