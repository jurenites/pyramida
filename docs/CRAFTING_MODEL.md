# Resources and crafting model

Design draft · 6 November 2026

The economy uses reusable definitions for resources, sources, actions, workplaces and recipes. A recipe connects those definitions: **one source or material → one action at a suitable workplace → one output resource type**. Processing workplaces default to one worker and no required power. Future power uses a separate connection. Its worker delivers the input, spends time performing the task at the machine, then carries the completed material to a suitable store or a construction site that needs it. Workers carry one resource type at a time. Buildings expose their purpose through their shape and equipment.

The active roster, sizes, construction costs and six fixed recipes are loaded from [reviewed_balance.json](../data/settlement/reviewed_balance.json), transcribed from the reviewed Numbers workbook. Internal save names `grain`, `block` and `pottery` mean Hay, Slab and Vase. Bread represents Food.

## Current reviewed rules

Twenty buildings are available. Each workplace has one purpose and one operator; power is deferred. Quarry is free and buffers four Stone. Claypit requires a Puddle. Claypit's 2 Log cost and Mine's 4 Log cost are provisional balancing choices: their spreadsheet cells are blank. Natural grass supplies Hay before the first Field, avoiding a construction loop.

Shed stores Log + Plank (8 total); Barn Hay + Flour (8); Depot Stone + Slab (18); Brickyard Clay + Brick (18). Sawmill buffers four items. Other conversion workplaces temporarily buffer one input and one output; that default is provisional. Ore has no dedicated store. House accepts Food and up to three Vases, with one Water per Vase. Legacy household Log/Hay remains usable but receives no new deliveries.

Missing, full or unreachable storage leaves physical, saveable goods on the ground. Producers can deliver cargo to a construction site without changing occupation. Delivered goods wait for Builder installation. Cancellation leaves those goods recoverable.

| Well depth | On Puddle | Within 2 m | Farther away |
| --- | ---: | ---: | ---: |
| 2 m | 3 | 2 | 1 |
| 4 m | 6 | 3 | 3 |
| 6 m | 9 | 6 | 6 |

Distance uses metre-grid rings, including diagonals, at the same elevation. Place another Well on the same cell to deepen it, up to three stages. Deepening adds empty capacity. Hover shows the shaft and actual water level. Wells do not evaporate; rainfall refills them. A new Well transfers water from its Puddle, without duplicating it. Excess water in older saves is preserved.

Claypit/Mine subsoil reserves (240 Clay / 120 Ore) and work times (4 / 6 seconds) are adjustable provisional values. Quarry uses existing finite mountain stock. Processing times remain in `game_settings.cfg`; reviewed recipes currently convert one item into one item. `general.day_seconds` controls the existing cycle. Sleeping, nightly meals and washing remain future work.

Editable derived models are `data/settlement/reviewed_*.tscn`. Regenerate them with `tools/settlement/generate_reviewed_assets.gd` after changing dimensions. Placement and navigation read reviewed dimensions directly. House and Shed source models are retained; the new pieces reuse the project's timber, workshop equipment and roof style.

## Pearls currency proposal

Updated 11 November 2026: **Pearls**, obtained from shrimp growing at the reef, are the proposed reef currency. Pearl-producing shrimp are a fictional ecology rule for the game. No sharks. A subsequent clarification leaves gold coins and diamonds open as additional high-value trading elements, with valuable underground discoveries encouraging deeper mining. Pearls are not necessarily the only currency or valuable resource. This updates the settlement economy proposal only; it does not change runtime resources, save identifiers or the separate block-city economy prototype.

Pearls provide monetary value for future exchanges. Whether Pearls, gold coins and diamonds are separate goods, currencies or items exchanged for a shared value remains undecided. Shrimp growth, access, harvesting, whether collection consumes a shrimp, replenishment, yields, storage and spending remain open, as do underground deposits and any gold processing or coin production. Do not assume automatic income, prices, taxes or a starting Pearl balance. The earlier `money` draft key below is retained as a reference, not a newly approved runtime resource ID. See the [first island proposal](FIRST_ISLAND_PROPOSAL.md#pearls-as-currency).

## Earlier concept notes

The following sections are historical proposals. Current reviewed rules above take precedence, including Mine → Ore, Quarry → Stone and dedicated storage.

| Concept | Meaning | Example |
| --- | --- | --- |
| Resource | Something that can be counted, stored, carried or supplied | Log, Flour, Electricity |
| Source | A world entity from which a worker obtains a resource | Tree → Log |
| Action | Reusable work behavior | Gather, Saw, Fire |
| Recipe | One particular input-to-output relationship | Log → Saw → Plank |
| Building | A placed space, structure or specialized workplace | Sawmill |
| Utility | Equipment installed inside, outside or on a structure | Bed, Sink, Transformer |
| Service | A useful effect supplied by equipment | Sleep, cooling, light |
| Storage | A capacity and acceptance rule provided by an object | Hay storage |

Keep stable internal IDs separate from visible words. Changing `chop` to “Cut” in the interface must not change saved resource or recipe identities. Use short nouns wherever clear: **Log, Plank, Stone, Slab, Clay, Brick, Pot, Hay, Flour, Food**. `berries` remains a natural plural label; `natural_gas` can display **Gas**, with its full identity retained in the data.

One input means exactly one material type, not necessarily one unit. One output means one result type, not necessarily one unit. For example, a future balanced recipe may consume several logs and produce several planks while satisfying both rules. There are no secondary loot rolls, sawdust stacks or simultaneous hay-and-grain harvests in this draft.

Power is a machine service connection, not a second recipe ingredient. The material-processing interface has one input resource and one output resource; there is no list of extra operating ingredients. Power alone does not execute the recipe: the assigned worker must perform the work at the machine.

Construction, utility operation, delivery and eating are separate from material-processing recipes. They need not pretend to produce an inventory item. A building may require several construction materials, delivered in separate trips.

## 2. Resource groups

### Shared consumables

| ID | Visible name and icon | Purpose | Representation |
| --- | --- | --- | --- |
| `food` | Food · bread silhouette | Feeding villagers | Stored food units, shown numerically |
| `water` | Water · droplet | Drinking; other uses declared separately | Stored liquid, shown numerically |
| `money` (earlier draft key) | Pearls, with a pearl icon proposed | Future exchange operations; sourced from reef shrimp | Currency balance; physical storage rules remain open |

“Food 25” and “Water 15” illustrate the display, not starting quantities. Food and Water must ultimately reach the villagers who use them. Pearls are the proposed reef currency; possible later gold coins and diamonds keep the wider trade economy open. Currency presentation, harvesting and spending rules remain undecided; this draft does not introduce rent, taxes or automatic earnings.

**Proposed accounting rule:** storage delivery consumes Berries and credits Food in the receiving store in one transaction. Baking outputs Food directly; Bread is its visual model, never another inventory balance. The original item is no longer present. The displayed Food total sums those stores; it is not a second spendable copy. Food conversion ratios remain unset and can differ by input.

The user's revised rule allows food delivery to any storage. Model this as a shared food compartment alongside each store's specialist compartment: a Hay store can accept Hay and a Berries or Food delivery without accepting Stone. The allocation of capacity between compartments is an open design choice. This supersedes the older houses-only food-storage direction for the proposed economy.

The simplest initial interpretation loses the Berries origin after deposit. If food variety later matters, preserve batches behind the aggregate Food display instead; do not count both an item and its converted Food value. Goods still in cargo are not yet deposited Food. A global total does not bypass walking access, reservations or local availability.

### Energy resources

| ID | Name | Physical form | Storage concept |
| --- | --- | --- | --- |
| `electricity` | Electricity | Network supply | Later battery capacity |
| `natural_gas` | Gas | Gas supply | Later compatible tank |
| `log` | Log | Carried solid | Log storage |
| `charcoal` | Charcoal | Carried solid | Fuel storage |
| `oil` | Oil | Liquid fuel | Later compatible tank |

These are exactly five energy resource identities. **Log is also a construction material and the input to Plank production.** It has one definition and one inventory balance, with multiple tags. Energy and material views may both refer to it, but cannot each spend the same log.

Stored amount and delivery rate are different values. Electricity available in a battery is not the same as the power currently reaching a device. Gas and oil similarly need compatible storage and delivery. Units, network throughput and conversion efficiencies are not balanced yet. Shared Water used for drinking and industrial Water also refer to the same resource; reserving it for one use makes that amount unavailable to the other.

### Physical materials and food intermediates

The review vocabulary is Berries, Hay, Log, Plank, Stone, Slab, Concrete, Clay, Brick, Pot, Flour and Food. Berries become Food on deposit. Bread is a Food model. Grain is omitted from the provisional early chain; Flour remains a reviewable intermediate. Pot's eventual use remains undecided, so it is a stored crafted item rather than an automatically consumed commodity.

**Provisional early chain:** both wild Grass and the placed Field yield Hay. Mill converts Hay to Flour; Bakery bakes Flour into Food. A sack is a visual representation of cargo, not an additional resource consumed by the recipe. Clay tiles and metal roofing need material choices described below.

## 3. Sources and production chains

There are five natural source families: **Bush, Grass, Tree, Mountain and Dirt**. A dead tree is a Tree variant, not a sixth source family. The Hay field is a player-built cultivated source, outside that natural list.

### Gathering

| Source | Shared internal action | Suggested visible verb | Single output | Workplace |
| --- | --- | --- | --- | --- |
| Bush | Gather | Gather | Berries | At the bush |
| Grass | Gather | Cut | Hay | At the grass |
| Tree, including dead tree | Gather | Chop | Log | At the tree |
| Mountain | Gather | Mine | Stone | Proposed mining workplace; requirement undecided |
| Dirt | Gather | Dig | Clay | At the dirt |
| Field | Gather | Harvest | Hay | Placed 4 × 4 × 1 m field |

One gathering implementation can share approach, reservation, work, source depletion and cargo creation. Each recipe supplies its animation, visible verb and output. Source depletion/regrowth is a source policy; it must not be inferred from the verb. The field's planting, growth and irrigation cycle remains separate from its harvest recipe.

For the mining workplace, **Mine** is a short proposed name. It could be a worker base connected to a Mountain target. Its footprint, placement and whether it is mandatory are unresolved. Keep the requirement explicitly unresolved in data rather than treating a missing building ID as permission to mine freely.

### Processing

| Input | Visible action | Output | Specialized workplace | Decision status |
| --- | --- | --- | --- | --- |
| Log | Saw | Plank | Sawmill · 2 × 2 × 2 m | Proposed size; user favors a distinct placeable building |
| Stone | Cut | Slab | Masonry · 2 × 2 × 2 m | Requested chain |
| Stone | Crush | Concrete | Crusher · size undecided | Chain requested; workplace name proposed |
| Clay | Fire | Brick | Kiln · 2 × 2 × 2 m | Requested chain; Kiln mandatory |
| Clay | Make | Pot | Pottery · 2 × 2 × 2 m, with Sink | Requested chain; Pot use undecided |
| Hay | mill | Flour | Mill | Review chain |
| Flour | bake | Food | Bakery | Bread model |

`Make` is the player's simple pottery verb. It is distinct from the Kiln's `Fire` action. Shared low-level processing code does not require every workplace to display the same verb.

**Concrete naming decision:** the requested Stone → Crush → Concrete chain treats Concrete as a dry construction material. Record it as a deliberate game abstraction. A more detailed vocabulary would call the crushed output Aggregate and introduce a binder/mixing step, but that extra chain is not adopted here. In the requested simpler model, construction consumes stored Concrete and Water at the construction site; no carried “wet concrete” output is needed. Water quantities and the construction-mixing rule remain to be specified.

### One building, one fixed purpose

Each specialized production building has exactly one `primary_action_id`. A recipe requiring that building must use that action. Sawmill performs Saw; Masonry performs Cut; Kiln performs Fire. Crushing therefore belongs to a separate Crusher rather than silently adding a second action to Masonry.

Each workplace has one fixed recipe and purpose, with no in-game recipe selector. Kiln makes Brick; Tiler makes Tile. Blacksmith makes Tool; a separate proposed Forge makes Sheet. Fuel-specific generators are separate proposed building types, not a fuel selector on a shared Generator. The Mine extracts Stone; the proposed Quarry extracts Ore. Reuse action code, equipment assets and animations behind those fixed building identities. Recipe editing belongs in the design spreadsheet/configuration before implementation, not in the player’s building UI.

Utility functions, storage delivery and maintenance do not count as additional production actions. A Sink installed in Pottery supplies a service; it does not make Pottery a second water-production building. The mapping governs workstations, not every activity that happens in a multi-room building.

## 4. Buildings, shapes and roofs

Use one-word building labels. Square brackets mark class names in review tables; verbs are lowercase. Tier 1–3 upgrades retain the same product. Their rates and costs remain unset; merging buildings is only an idea, not an adopted rule. Shed stores Log and Plank, with a 1 × 2 × 1 m body excluding the roof and a matching placement footprint/origin.

Only the existing 2 × 2 × 2 m House is retained. The 2 × 3 × 2 and 3 × 3 × 2 house variants are excluded for now.

Confirmed roster exclusions: Stockpile (Pile) is removed from the planned game. School is omitted for now because it has no defined gameplay purpose. Existing runtime entries remain reference data pending implementation. Dedicated stores and loose material drops are separate concepts; their behavior is not changed by this decision.

All dimensions below are **width × depth × height in metres**. Store named dimensions; coordinates use `[x, y, z]` with y up. One 1 × 1 × 1 m cube is the spatial unit, not a tiny inhabitable building.

| Module | Intended role |
| --- | --- |
| 1 × 1 × 1 m | Shape cell; ramp module with 1 m rise |
| 1 × 2 × 1 m | Shed; Log and Plank storage, roof excluded |
| 2 × 2 × 1 m | Low platform |
| 2 × 2 × 2 m | Basic inhabitable room; standard specialized workplace |
| 4 × 4 × 1 m | Hay field; largest footprint in the current list |

Rooms can have protrusions and irregular footprints assembled from the 1 m cells. Keep occupied cells separate from the enclosing dimensions: an empty corner of an L-shaped room is not solid merely because it lies inside the bounding box. Additional adjacent rooms form a building assembly while retaining their own identities. A storage utility inside a room provides storage function; a reachable Bed provides sleeping function.

The earlier elongated hall is not required by this new catalogue. The spoken “4 by 2 by 1 by 2” has four numbers, so its exact old geometry is not inferred or deleted here. It remains a clarification for future implementation.

The user's “ladders with inner ramps” are stair assemblies: two 1 m-rise ramps plus the required landings connect to a 2 m upper level. Keep true vertical ladders a separate movement type. Preserve the already agreed 2 × 2 m stair prefabs, entrance/exit endpoints, shaft openings and headroom rules in the measurement document. Stacking two volumes does not create a walking connection.

### Automatic roofs and progression

| Tier | Covering | Material relationship |
| --- | --- | --- |
| 1 | Hay roof | Hay |
| 2 | Plank roof | Plank |
| 3 | Clay tile roof | Imbrex, fired from Clay at Tilery |

Roofs are generated automatically on exposed building tops. Roof tier and appearance are independent of room dimensions and function. Optional visual adjustment can choose compatible styles without requiring manual roof placement. Joined rooms and upper floors change exposed roof coverage; preserve shelter until replacement construction completes.

House progression stops at three tiers. New Houses start at Tier 1; older saves without a tier retain Tier 3. Tier 2 adds Log braces and supports upper buildings; Tier 1 does not. Select a House and use ↑ to queue a paid upgrade through the normal worker delivery/construction system. Supplies and residents remain in place. Provisional costs are 2 Log + 4 Plank for Tier 2 and 2 Plank + 4 Imbrex for Tier 3, editable in `data/settlement/reviewed_balance.json`. Tilery (2 X 3 X 2) exclusively fires 1 Clay into 1 Imbrex. Its provisional construction cost is 4 Stone + 4 Clay and batch time is 6 seconds. Assign one Tiler. It buffers 2 Clay and 2 Imbrex; overflow uses the existing ground-drop/direct-construction delivery rules. Imbrex has a physical curved cargo mesh matching the roof tiles. Longer roof life, leakage, weather effects and drainage remain future work.

### Power structures

Future-only concepts: generators, Watermill and energy-conversion buildings are deferred from the active building review. Windmill and Watermill can capture environmental power. The Watermill requires suitable water placement. A separate Mill provisionally performs Hay → Flour, potentially mounted above and connected to the power structure. Merely placing it on top must not grant power without a valid mechanical connection.

Represent their initial output as a **mechanical-drive service**, not a sixth energy resource. Electricity requires a generator stage if that option is adopted. This separates the spinning structure from the grain-processing equipment while keeping one production action per workplace. Exact sizes, mounting points and shared versus dedicated machinery are open.

Transformer and electric Pole belong to utilities/infrastructure even if they occupy substantial space. They distribute or adapt electricity; they do not create it. A powered-looking mesh is not evidence of a live supply.

## 5. Utilities and services

Utilities can be placed inside a room, attached to an exterior wall or located outside, according to their placement contracts. Each needs a footprint, access area and any service ports. The placements below are starting proposals except where the user explicitly specifies inside/outside.

| Utility | Placement or variants | Purpose or dependency |
| --- | --- | --- |
| Bed | Inside | Required for Sleep and sleeping comfort |
| Sink | Inside; required in Pottery | Water-related service; active water/drain requirements need definition |
| AC | Inside and outside units | Cooling; pairing and connection rules undecided |
| Coffee machine | Inside | Drink preparation; recipe and inputs undecided |
| Antenna | Exterior attachment | Signal reception; service model undecided |
| TV | Inside | Comfort/entertainment; exact requirements undecided |
| Light | Inside or suitable attachment | Illumination; electric variant uses electricity |
| Freezer | Inside | Food preservation; exact spoilage rules undecided |
| Stove | Log, Gas and Electric variants | Cooking/heat role to specify; each variant uses its named energy source |
| Transformer | Outside or service space | Electrical network equipment |
| Pole | Outside | Electrical network support/distribution |

A utility can share the same work/recipe system later if it processes materials. It does not need to become a building to do so. For example, a future coffee recipe can target a Coffee machine workstation. Keep that extension separate from the first specialized-building catalogue. Likewise, the bakery workplace might eventually be a room containing a Stove; that is an open packaging choice, not two required baking steps.

Pot remains a resource until its role is chosen. Installing a Pot as equipment should transfer one inventory item into a placed utility, not duplicate it. Possible roles are a reusable vessel, water capacity, or packaging consumed by a recipe. None is enabled in this draft.

## 6. Proposed missing chains

### Blacksmith

The requested Blacksmith is a distinctive 2 × 2 × 2 m building. Its inputs and products are not yet confirmed. A small extension that gives it useful work is:

```text
Mountain [ore-bearing variant] → Mine → Ore
Ore → Smelt at Smelter → Iron
Iron → Forge at Blacksmith → Tool
Iron → Forge at Forge → Sheet
Sheet → metal roof construction
```

All five lines are proposals. Ore-bearing Mountain remains a variant of one of the five natural source families. Mine targets Stone and the separate proposed Quarry targets Ore. Neither has a resource selector. Smelter is an additional proposed building because Smelt and Forge are different actions. Tool can improve work or unlock later recipes; it must not be required to obtain the first materials needed to construct its own production chain. Tool wear and consumption are undecided. Forge is a separate proposed workplace with its own fixed purpose. Sheet is an optional way to represent metal roofing; direct use of Iron would remove that extra recipe.

### Energy conversion

| Proposed input | Action | Single output | Workplace idea | Unresolved part |
| --- | --- | --- | --- | --- |
| Log | Char | Charcoal | Charcoal burner | Yield, heat requirement, footprint |
| Oil | Convert | Gas | Converter | Intended gas identity, process and loss model |
| Log, Charcoal, Gas or Oil, chosen one per recipe | Generate | Electricity | Compatible Generator variant | Which fuels, efficiency, throughput and storage |

Oil → Gas is retained as an optional game abstraction, not a settled physical recipe. Do not assign a real-world conversion ratio or silently call every gas “natural gas.” The final fuel naming and process require a decision. Gas and Oil acquisition are also missing from the five-source catalogue; no extraction chain is invented as confirmed content.

**Current machine rule:** one worker, one material input type and one output type. No machine requires power for now; building-specific power requirements will be decided later. Power supply and consumption belong to the machine/service model. The worker brings the material, works at the machine for the required time, and carries away the result. There are no extra fuel or water ingredients in a material recipe.

A fuel-burning power source may consume Log, Charcoal, Gas or Oil upstream; that is a separate supply operation, not another input delivered with the material to every connected machine. If power requirements are later enabled, power must be available and charged through that supply, without charging for the same fuel again at the machine. Which machines accept electricity, mechanical drive or another power service, and their demands, remain undecided. The required Sink in Pottery remains equipment; its water-service behavior is still to be defined without silently expanding the recipe to a second material input.

Losses reduce useful output; they need not create an extra carried waste item. Compare efficiency in compatible energy units after units are chosen, not by comparing raw log, gas and electricity counts. Wind or water drive can power a generator through a service connection without adding an inventory resource.

## 7. JSON organisation

The [example catalogue](examples/crafting_catalog.example.json) stores definitions once and refers to them by ID. It covers the requested chains and marked proposals. It deliberately uses `runtime_enabled: false`; `null` numeric values mean **undecided**, never zero, free or unlimited.

| Registry | Stores | Reused by |
| --- | --- | --- |
| `resources` | Name, tags, physical form, counting unit | Inventories, recipes, construction and displays |
| `sources` | Natural/cultivated family and variants | Gathering recipes and placed source instances |
| `actions` | Behavior family and default verb | Recipes and workplaces |
| `buildings` | Kind, dimensions, primary action, required utilities and machine power connection | Placement and recipe workplace requirements |
| `utilities` | Equipment variants, placement and services | Rooms, workplace requirements and networks |
| `recipes` | Input, action, workplace, single output and worker effort | Work orders |
| `deposit_rules` | Automatic resource conversion at delivery | Storage acceptance |
| `roof_tiers` | Ordered covering choices and material IDs | Automatic roof generation |

For example, the full catalogue expresses sawing as:

```json
{
  "id": "saw_plank",
  "status": "requested",
  "primary_input": {"kind": "resource", "id": "log", "amount": null},
  "action_id": "saw",
  "display_verb": "Saw",
  "workplace": {"kind": "building", "id": "sawmill"},
  "output": {"resource_id": "plank", "amount": null},
  "work_units": null
}
```

`output` is a single object, not an array. It makes the one-result rule structural. The same `log` definition is referenced by sawing, charcoal production and a log-fuel generator recipe. Building records do not repeat the recipe's input/output lists. Validate the fixed recipe by matching the workplace ID and primary action; reject multiple recipes bound to one workplace type.

The standalone snippet includes `id` for readability. In the catalogue, object keys are IDs and records do not duplicate that field. `primary_input.kind` is either `resource` or `source`; a cultivated field refers to a cultivated source record. A building's `source_id` identifies the cultivated source it hosts.

`workplace.kind` is `source`, `building`, or `unresolved`. An unresolved mining workplace names its candidate rather than defaulting to unrestricted gathering. Each workplace defaults to `worker_slots: 1` and `power_connection.required: false`. Power services and demand remain deferred. A workplace’s `fixed_recipe_id` selects its sole recipe in configuration. `recipe_selection_in_game` is always false. A recipe inherits power requirements through its workplace reference; it does not duplicate power as an ingredient. Before enabling a machine recipe, settle its quantities and worker effort; a power contract is needed only if power is later required. Gathering at a natural source is distinct from working a powered machine.

The catalogue also records the confirmed `worker_cycle`: deliver input → work at machine → collect output → deliver output. Its physical-output destinations are suitable storage and construction sites; Stockpile buildings are excluded. Proposed generators that output network electricity follow their supply model rather than asking a worker to carry Electricity.

Statuses distinguish **requested**, **proposed**, and **unresolved** concepts. They describe design agreement, not implementation. Recipe metadata records unresolved packaging and semantics without forcing them into a renderer or worker script.

### Definition versus saved state

The catalogue describes types. Save files describe instances: source remaining yield, building ID and position, installed utilities, inventory contents, active recipe ID, reservations, work completed, and cargo. Do not put changing stock counts in a resource definition.

Worker cargo is one resource ID plus an amount. A job references a recipe ID, its assigned worker, specific source/workplace instances, and a destination kind and instance ID. The same worker owns the delivery–work–return cycle. Store the current phase, reserved output quantity and destination demand so reloading does not restart completed work. Reserving a Log for a generator prevents a sawmill from claiming it. If an input is already consumed into work in progress, persist that state so loading cannot consume it twice or refund it and still produce an output.

### Citizen assignment

The player can assign a citizen to work at a specific workplace or source. That assignment chooses the building’s fixed job, never a recipe. The assigned citizen repeats the delivery, work and output-delivery cycle while materials and destination capacity are available (and power only if later required). Preserve the assignment through meals and temporary shortages; another player assignment or removal of the target ends it. Worker slots default to one; assignment gesture and reassignment handling remain to be designed.

Current settlement controls assign an occupation and move the citizen to the clicked location; the scheduler can subsequently choose another matching workplace. Persistent workplace binding is therefore a planned change. Construction-site assignments already retain a specific plan target.

### Work lifecycle and accounting

1. Assign a worker to a recipe at a reachable workplace. Confirm its required equipment. No power connection is required for now.
2. Reserve the input batch and a destination for its output: space in a suitable store, or matching unmet material demand at a construction site. Reserve output buffer capacity at the machine as needed.
3. The worker picks up the one input material type, carries it to the machine, and delivers it. Input quantity may require more than one trip; resource types are never mixed in cargo.
4. The worker spends time performing the task at the machine. Work progresses while the worker is working. If power is later required, its availability also gates progress. Power use belongs to the connected supply, not to another recipe ingredient.
5. Complete the batch once, creating only the output material type. The worker picks up that output; input and finished output are not carried together.
6. The worker carries the result to the reserved store or construction site. Direct construction delivery does not require an intermediate storage visit. Material delivery satisfies the site’s material requirement; it does not itself finish construction work. Apply Berries → Food only at accepted storage delivery, without a separate timed production job.

Proposed interruption policy: losing the worker (or power, if later required) pauses progress and preserves the batch; restoring both resumes it without charging for the material again. If the destination disappears, fills up or no longer needs the material, retain the output and find a new valid destination without discarding or duplicating it. Destination priority and whether a different worker may take over remain open. Full output capacity must block new work or retain a finite workplace output batch. Cancellation, recovery of partially processed input and the exact power-demand model still need policies before implementation. Food withdrawal and drinking reduce actual inventory once; an installed Bed supplies Sleep without consuming a bed each night.

### Validation before loading an executable catalogue

- Every referenced ID exists, and IDs remain stable through label changes.
- Each recipe has one primary input and exactly one output resource type.
- Each specialized producer has one primary action and one fixed recipe; reject a second recipe bound to the same workplace. No in-game recipe selection is exposed.
- Every executable quantity and work value is valid and non-null; unresolved workplace requirements block activation. Deferred power does not block an unpowered workplace.
- Material recipes contain no additional operating-ingredient list. Machine work requires an active worker; connected power is optional until explicitly enabled.
- Physical output can be reserved and delivered to storage or a construction site, with no mandatory storage detour and no duplicated demand claims.
- Source recipes target supported source variants; the provisional field produces only Hay.
- Requested dependencies are explicit: Brick requires Kiln; Pot requires Pottery and its Sink; sleeping capacity requires a reachable Bed.
- Duplicate tags do not create duplicate balances. Deposit rules cannot repeatedly convert already credited Food.
- Units and physical forms are compatible with containers, cargo and network ports.
- Construction sizes, occupancy, service ports and walking connections are independently valid.
- The first food, water and construction loop has no circular tool, material or energy prerequisite.

## 8. Moving to a spreadsheet later

Use one sheet per registry: Resources, Sources, Actions, Buildings, Utilities, Recipes, DepositRules and RoofTiers. Store IDs in reference columns; keep icons and editable labels separate. Resources such as Log appear once in Resources, even when several recipe rows refer to them.

Recipes can flatten to `id`, `status`, `input_kind`, `input_id`, `input_amount`, `action_id`, `display_verb`, `workplace_kind`, `workplace_id`, `output_id`, `output_amount`, `work_units` and `notes`. Machine power belongs in workplace columns or a PowerConnections child sheet keyed by workplace ID: required service, compatible connection and work demand. Do not add power as a second recipe ingredient. Destination and worker-cycle state belong to saved jobs, not recipe rows. Blank numeric cells export as `null` and fail activation until balanced.

Editing a row should change a definition, not saved stock. Export validates references and builds versioned JSON. A later migration layer maps old save IDs and work in progress to the new catalogue explicitly.

## 9. Decisions before implementation

The one-material-input, one-material-output rule is confirmed. Defaults are one worker and no required power; future power uses a separate connection. The highest-impact remaining decisions are machine power types and demands, whether Concrete remains the simplified dry mix, and whether the Blacksmith proposal warrants Ore, Iron, Smelter and Sheet. Pot's purpose, water transport beyond the first island's direct puddle drinking, Gas/Oil sources, Pearl harvesting and spending, storage capacities, all yields and work times also remain open.

The current settlement economy defines `sawmill: log → plank`, `windmill: grain → food`, and `masonry: stone → block` in `scripts/settlement/economy.gd`. The proposed model adds physical Berries or Food delivery, separates Hay from Grain and Flour from Food, and uses Slab instead of the old Block result. These need reviewed migrations; changing labels or overwriting resource IDs is insufficient. The revised schema does not claim those changes already exist.

A useful first implementation would prove one complete gathering-and-storage path and one processing path with reservations and save/reload: Bush → Berries → Food and Tree → Log → Sawmill → Plank. The provisional Hay → Flour → Food chain follows once the workplace decisions are settled. This ordering is a proposal for subsequent work, not a request to implement now.
