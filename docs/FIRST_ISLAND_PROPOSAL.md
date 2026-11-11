# First island concept and resource budget proposal

Status: design proposal, updated 11 November 2026. Rooftop rain collection, resource-built vessels and the first person's salvaged vase are approved for implementation. The rest of the first-island scenario remains a proposal. Basic spear fishing, reef expansion and newcomers arriving by boat are the selected direction. Fishing shelter costs, underground resources and detailed balancing remain open.

## Opening scene

One person wakes up in the morning on a sandy beach after a shipwreck far away. There is no damaged boat waiting to be repaired on this island. Whether the distant wreck is visible is undecided.

The island can be cartoonishly small, with a rounded, gently domed surface, almost like the exposed half of a sphere. Exact geometry remains a visual exploration. Keep usable space for the person, a small hut and a few natural resources. Start without buildings. One palm is the preferred simple image; up to three remains an option if the eventual resource balance needs them. A couple of young bushes could visibly mature during the opening cycles.

The first experience is about making a small place habitable, learning to direct the person, gather supplies and build shelter. It should feel forgiving. Hunger can make the person weak; starvation should not turn the learning level into a life-or-death countdown. No sharks.

The starting island should remain a viable home throughout the game, with expansion over its surrounding reef. Leaving is optional. The long-term design must provide renewable supplies or another dependable way to obtain essential materials; the complete resource loops are still to be designed.

## Daily needs and recovery

Use one Food and one Water per person per day. For the single starting person, one unit of either resource is one day of that supply. Keep budgeting in whole days and whole items.

Food shortage causes a recoverable weak condition. Its exact work penalty, onset and recovery timing remain undecided. Define the water-shortage response alongside water collection, keeping the same forgiving intent. Weakness must leave the person able to obtain supplies and recover.

The timing of eating and drinking within the day remains open. These are proposed consumption rules, not a description of the current simulation.

## Opening resource budget

Separate essential needs, building materials and supplies arriving later. Exact starting quantities depend on rain timing, fish availability and gathering work.

| Resource or allowance | Budget basis | Status |
| --- | --- | --- |
| Food consumption | 1 per person per day | User-selected proposal rule |
| Water consumption | 1 per person per day | User-selected proposal rule |
| Initial Food reserve | Suggested 3 Food for 3 days alone | Working allowance to review after fishing design |
| Salvaged vase | 1 droplet of storage, initially filled | Confirmed starter item; first rain timing remains to balance |
| First hut | Current House reference cost: 2 Logs and 2 Hay | Budget reference; hut form and final recipe remain open |
| Palm timber | Finite harvest from 1 palm, or up to 3 if needed | Yield and required tree count to be checked |
| Young bushes | Supplementary Food as they mature | Count, first harvest and regrowth timing unresolved |
| Washed-up materials | Small amounts of useful salvage, including Planks | Starting amounts and arrival limits unresolved |
| Coconut or planting material | A possible route to replacement palms | Fruit production, planting and growth unresolved |
| Basic drinking and fishing | Use the salvaged vase and an automatically available spear | No puddle or vessel-production chain required to start |
| Fishing shelter | Small optional workplace improving fishing | Cost, rod benefit and exact operation remain open |
| Reef expansion | Supports bearing on the shallow seabed | Use existing depth-sensitive foundation costs as a reference; level quantities remain open |
| Pearls | Currency obtained from shrimp growing at the reef | Starting quantity, harvesting, yield and spending remain open |
| Travel and arrivals | Visiting boats can bring newcomers | No boat-repair allowance or mandatory escape recipe |

The suggested three-day Food reserve is a testing baseline. The first person receives a visible salvaged vase holding one droplet. Before a roof exists, the uncovered salvaged vessel catches rain directly. First rain must arrive before a water shortage prevents learning or recovery; the opening no longer depends on a puddle.

For reference, the current House costs 2 Logs and 2 Hay and provides one resident place and four Food spaces. Its household Water capacity depends on Vases. The opening uses the salvaged vase, with no Well or pottery-production prerequisite. See [current balance sources](BALANCE.md).

## The sea as a source of supplies

Waves can bring resources onto the beach over time. Examples include loose Planks and a coconut that could grow into a palm. Some arrivals can be random; their chances can also respond to what the player needs.

A palm could regrow coconuts while standing. A coconut could then be planted to grow a replacement tree for more timber. This is a possible renewable wood loop, not an approved rule that a chopped trunk automatically grows back. Decide whether coconuts also provide Food or Water before counting either benefit in the budget. Planting conditions on the sandy island need a clear answer too.

Salvage should arrive visibly through the water and become collectable at the shore. Keep the route from arrival to use understandable, including whether anything floating beyond reach eventually washes ashore.

## Quiet assistance during learning

Use a simple, silent director to keep the first level engaging and recoverable. The user referenced RimWorld as an analogy for shaping events, rather than proposing a speaking narrator or a full simulation of that game's systems.

The director can consider current supplies, what has been built, the player's current construction or activity, and which missing resource prevents progress. It can then increase the chance of useful salvage arriving. A player short of Planks might receive a Plank from the next suitable wave; someone without a way to replace a palm might receive planting material.

Proposed boundaries for this assistance:

- Count usable supplies and material already available nearby before deciding something is missing.
- Respond to observable player actions. If the intended objective is unclear, favour basic recoverability rather than choosing a construction project for them.
- Give the person something to collect or use. Keep the gathering and building actions meaningful.
- Space out arrivals and limit quantities so the beach does not become an unlimited stockpile.
- Avoid a prolonged shortage that prevents learning. Exact delays, chance adjustments and any guaranteed fallback remain to be designed.
- Withhold hostile encounters and disasters during this first learning scenario.

This assistance is scoped to the first level. How it changes or recedes later remains open. It needs no narrator panel, persistent goal text or progress count. Teach through visible waves, salvage, growth, carrying and construction, using concise existing labels where needed.

## Rooftop rain collection

Confirmed on 11 November: roof runoff is the main water source. A complete rain event contributes one droplet per exposed 2 x 2 m roof area actually served by a gutter and a connected downhill pipe. Eight such roofs with half their area connected yield four droplets in total. Fractional runoff accumulates, survives saves, and becomes available Water when it reaches a full droplet. Full receivers overflow without creating additional stored water.

Vases hold one droplet, plank barrels hold two, and the default Well holds three. The first person's salvaged vase starts filled and catches one droplet per full shower while uncovered and without a connected roof supply. This is the opening fallback, not a requirement to construct a production chain. Puddles are not generated as the starting supply in new settlements; existing saved water remains intact.

Use the building or room Rain tool to place containers in free gaps, fit half-round gutters on low roof edges, and draw editable pipes around walls to receivers. Clay stock is 0.25 m across, using the 0.23 m structural Log as the scale reference. Each 0.25 m gutter section serves 0.5 square metres of roof; touching sections share a downhill outlet. Show socket collars, curved elbows, mounting brackets and visible water in open channels and at spouts. Junctions combine roof branches into shared drains, and a 2 x 2 m basin holds 24 droplets. Connected and stacked buildings retain exposed catchments only; a covered lower roof cannot collect rain again. Existing one-metre fittings retain their saved connections and paid materials.

Initial implementation recipes are 2 Clay for a vase, 6 Planks for a barrel, 1 Clay per quarter-metre gutter, 2 Clay for a junction, 24 Clay plus 12 Stone for a basin, and 1 Clay per metre of pipe rounded up. Builders deliver these materials. Redrawing a pipe reuses its paid Clay and charges only for an extension. Containers can move with their stored water; dismantled fittings return their paid materials as physical salvage. These recipe quantities and the larger basin's capacity are tuning choices; the user-confirmed vase, barrel and Well capacities and rain-area rule are fixed. Uncovered constructed floors and spills become damp, slow walking and occasionally interrupt deliveries with a brief slip recovery; the surface dries afterward without creating collectible puddles. Keep controls concise and the water level visible in the vessel, without a production configuration panel.

## Spear fishing and the optional shelter

Basic fishing is available before construction. A simple spear is assumed to be carried by the person and appears when fishing starts. Do not add a tool inventory, durability, axe-production chain or spear-crafting prerequisite to this action.

Fish are actual swimming creatures, not marked fishing spots. The person approaches a reachable shore position and throws at a fish within range. Retrieval must be visible and feasible from that position; a catch must not require an unplanned swim into deep water. Exact targeting, animation and retrieval remain to be designed.

Proposed interaction: right-click a fish to begin working that stretch of shore, then continue while food is needed and fish are available. One catch yielding one Food and allowing the person to eat it before a store exists are working suggestions. Catch duration, success rate, range, yield and fish replenishment remain open. Prefer visible time spent approaching and waiting over repeated random failures that prevent recovery. Basic fishing must leave the first person time for other work.

The optional fishing shelter improves an existing ability rather than unlocking the first meal. Explore a tiny roof on posts, a rod support and a basket, with no residential function. Rods could reach farther and reduce pursuit time. Equipment appears automatically during work rather than being separately managed. The exact benefit and whether equipment is picked up at the shelter remain open.

The fishing shelter has no selected construction price. Do not treat the previously suggested 2 Logs and 1 Hay as approved. Its eventual recipe must be obtainable before the shelter exists, without circular workshop requirements. Cooking and fuel requirements remain open; the current opening budget includes no mandatory cooking fire.

## Reef expansion and underground resources

Surround the tiny island with shallow reef where Supports can bear on the seabed. Extend connected platforms to create room for workplaces, homes and potentially soil beds. The existing foundation direction makes shallow water economical and deep water increasingly expensive. A reef is a submerged bearing, not free walkable land.

Fish and growing reef shrimp give the shallows a resource role as well as a construction role. How building above them affects access, habitat and harvesting remains open. Keep the starting island viable as a long-term settlement rather than a disposable tutorial map.

Underground resources are exploratory. A quarry entrance could connect to vertical shafts and horizontal passages, with workers travelling and hauling below the island. Resource types, reserves, yields, digging costs, access, behaviour below sea level and any soil suitable for planting are all undecided. Do not assume unlimited stone, fertile soil from all excavated rock, or safe dry tunnels under the ocean. No underground yield is included in the opening budget.

Small fitted rotations of connected building or shaft modules are a visual possibility. Preserve continuous floors, doorways and structural connections; arbitrary independent rotations are not an approved placement rule.

## Pearls as currency

Use **Pearls** as the proposed reef currency, obtained from shrimp growing there as part of the game's fictional ecology. No sharks. The later clarification keeps possible gold coins and diamonds open as additional high-value trading elements; Pearls need not be the game's only valuable resource. Rare underground finds could encourage deeper mining, but no deposits, yields or production chain are selected.

Pearls are the monetary value used for future exchanges, not another daily survival need. Decide how shrimp mature, how Pearls are collected, whether collection consumes the shrimp, and how the source replenishes. Growth time, yield, carrying, storage, prices and spending uses remain open. A reef does not automatically credit the settlement with currency merely by existing.

Whether Pearls, gold coins and diamonds act as separate trade goods, currencies or items exchanged for a common value remains open. Keep this as an economy proposal: no runtime currency, resource IDs, icons or balances change in this pass. See the [crafting model](CRAFTING_MODEL.md).

## Newcomers and a continuous world

New people arrive by visiting boat, and the player can choose to welcome them into the settlement. This provides population growth without requiring a family tree or descendants of a single starting pair. Arrival timing, boat behaviour, acceptance interaction and settlement requirements remain open. At the proposed daily rates, accepting a second person raises demand to two Food and two Water each day.

A bottle message could attract a visit. A visiting boat could also offer passage elsewhere. These are optional story and travel ideas, not a mandatory rescue ending. The first visit may mark the end of the introductory phase while play continues on the same island. Repairing a boat stranded beside the character remains excluded.

Keep islands in one continuous world, with distant terrain streamed as the player travels and visited settlements preserved. Deeper sea and longer distances make Supports and bridges costly between faraway islands, while nearby connections can remain useful. Travel, boat ownership and boarding still need design. Do not establish swimming or a boat carried in a pocket as the solution.

No final victory condition is selected. Staying and expanding the starting home should remain possible; distant islands can offer different opportunities without erasing it.

## Working title exploration

Prefer a future title containing Village or Town, with less interest in Farm or World. Avoid tying the whole game to Pearls or a reef: another learning scenario could have a harsher environment that is not a reef. Naming is deferred without urgency. Earlier candidates and preliminary searches remain in [game naming notes](GAME_NAME_CANDIDATES.md); no title or branding change is selected.

Next design work: balance rain and spear fishing, define the shelter's concrete benefit before its cost, decide shrimp and Pearl harvesting, and establish renewable supplies for continued reef expansion. Keep underground resources and the final goal open.
