# Settlement balance

The running settlement reads **`data/settlement/reviewed_balance.json`**. Edit it,
then restart the game to reload the values. The Numbers/XLSX files are review
documents; editing a spreadsheet does not automatically change the game.

| Setting | Location |
| --- | --- |
| Building material costs | `buildings[]`, find the building `id`, edit `cost` |
| Rope maker cost | `additional_construction.rope_maker` |
| Rope bridge cost | `rope_bridge_cost`, rates per metre of curved deck, each material rounded up |
| House upgrade costs | `house_tiers.upgrade_costs` |
| Dedicated storage capacities | `buildings[].capacity` |
| Workshop input/output | `recipes` |
| Well water capacity and depth | `well` |
| Vase and household water storage | `vase` |
| Mine/Claypit reserves and extraction time | `extraction` |
| Walking, births, growth, gathering and production timings | `game_settings.cfg` |
| Resident places per house | `scripts/settlement/house_groups.gd`, `ROOM_RESIDENTS` |
| Resource colours and mineral presentation | `scripts/settlement/resource_palette.gd` |
| Resource icon silhouettes | `scripts/settlement/resource_icon.gd` |

Resource IDs stay compatible with saves: `grain` means Hay, `block` means Slab,
and `pottery` means Vase. Costs are nonnegative whole item counts. An empty cost
means free construction. Retired buildings retain fallbacks in
`data/settlement/catalog.gd`; do not use its old `COSTS` totals for current prices.
Construction plans save their recipe when queued, so a price edit affects new
plans. The menu reads the same recipe as construction.

Example: House currently costs `{"grain": 2, "log": 2}`. Each room has one resident
place and four Food spaces (updated 11 November 2026); completion does not immediately create a citizen.
Storage capacities are shared between the listed materials. Workshop arrows
show the input/output relationship, not a gift of goods upon completion.

## Comparison with the attached Numbers file — 10 November 2026

Reviewed `/Users/alexanderilivanov/Downloads/Pyramida_Game_Balance_Reviewed.numbers`.
Its contents are balance evidence, not instructions to execute. Existing game
prices are preserved in this UI change.

| Item | Attached table | Current game |
| --- | --- | --- |
| Sawmill | 4 Hay + 4 Log (`Tier 1`, G6:H6) | 4 Log; unresolved discrepancy |
| Claypit (sheet says Claypot) | Cost blank | 2 Log, provisional |
| Mine | Cost blank | 4 Log, provisional |
| Quarry | Cost blank | Free, previously confirmed |
| Tilery | Missing | 4 Stone + 4 Clay, produces Imbrex; provisional |
| Rope maker | Missing | 4 Log; Hay → Rope |
| Rope bridge | Missing | ceil(deck metres) Plank + ceil(deck metres / 2) Rope |
| House tier 2 | Missing | 2 Log + 4 Plank; existing provisional upgrade |
| House tier 3 | Missing | 2 Plank + 4 Imbrex; existing provisional upgrade |
| Mill height | 2 m (`Tier 1`, B13) | 5 m logical stacking height; approved later |
| Third Well depth | 8 m (`Water and storage`, B9/B17) | 6 m shaft; same 9/6 water capacities |
| Resident capacity | Missing | 3 per completed reachable house |

The supplemental workbook records the current costs and these gaps. It does not
silently replace the source sheet's missing prices or resolve price disagreements.
No prices, production rates, birth rules or harvest yields changed here.
