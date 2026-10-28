# Pyramida — Future Ideas

Status: exploratory design notes. These ideas are not part of the first playable version and do not override the current code, tests, or foundation specification.

This document is a holding place for possible long-term systems that could make vertical and underground construction meaningful while preserving a believable, recoverable settlement world.

## 1. Environmental pressure: buried and snow-covered buildings

### Core idea

At night, occasional severe weather may move sand or snow across the settlement. A strong wind or sand dune can cover part of a universal construction block, such as roughly half of one block's height. Over time, buildings appear to sink into the landscape unless the player excavates them or continues construction upward.

The same broad pressure could work in a snow biome: snow accumulation gradually buries lower floors and forces the settlement to build upward, maintain access, and keep important functions above the expected snow line.

### Why it could motivate underground construction

- A buried lower level can remain useful as protected storage, a workshop, a shelter, or a passage.
- The player may deliberately excavate downward instead of constantly clearing the surface.
- The pyramid can become a meaningful deep-time landmark: its lower structure may be buried far below the current sand level and uncovered through excavation.
- Vertical construction becomes an adaptation to the environment rather than only an aesthetic choice.

### Constraints and unresolved questions

- Weather should probably be occasional, seasonal, or forecastable rather than happening every night. Constant burial would turn routine gathering into maintenance and could erase the settlement faster than it can develop.
- Sand and snow should accumulate in manageable layers with clear thresholds, not instantly invalidate buildings.
- The player needs readable warnings, such as a forecast, wind direction, accumulation markers, and a visible “buried access” state.
- Buildings should be recoverable: shovel, excavation, raised entrances, vents, stairwells, and maintenance routes should restore access without rebuilding the whole structure.
- A buried building may need to remain structurally intact while its doors, windows, fires, and routes become blocked.

### Resource and ecology problem

If sand or snow covers bushes every night, harvesting becomes implausible and frustrating. If trees become fully buried after only a few storms, the settlement loses its wood source and the world raises an important question: how did those trees grow there in the first place?

Possible resolutions:

- Storms are intermittent and severe only during defined weather events.
- Mature trees have deeper roots and a protected growth zone; they can become dormant or partially buried without disappearing immediately.
- Sand and snow drift around vegetation instead of uniformly covering every tile.
- The player can establish windbreaks, groves, fences, terraces, or snow sheds that protect resource patches.
- Buried vegetation can be cleared, transplanted, or harvested before the storm arrives.
- Some biomes use different pressures: sand burial in deserts, snow load and blocked entrances in cold regions.

This system should create planning decisions, not remove the basic food and wood loops.

## 2. Settlement land and competing development

### Core idea

Limit uncontrolled one-story sprawl through land ownership rather than an artificial building-height rule. The initial settlement contains “city land” and an NPC-controlled parcel. The NPC develops its own empire inside or beside the town.

To expand, the player must purchase or otherwise acquire the adjacent plot first. Ownership can extend across a road, creating a reason to negotiate, trade, compete, or plan around another settlement.

### Natural dividers

The world should contain natural and civic dividers that prevent one infinite, uninterrupted building mass:

- Roads and alleys.
- Open courtyards and plazas.
- Water channels or drainage cuts.
- Cliffs, dunes, rocks, and biome boundaries.
- Parks, protected groves, and undeveloped reserve land.
- NPC borders and purchased plots.

These dividers can preserve readable districts without preventing the player from building a connected vertical city.

### Cross-road connectivity

Buildings on opposite sides of a road may still connect through elevated or underground passages and corridors. The road remains a meaningful public boundary at ground level while the player can create a more complex three-dimensional town above and below it.

Important questions:

- Who owns a passage crossing another parcel?
- Does a passage require a permit, a fee, or an agreement with the NPC owner?
- Can a public road be bridged without blocking traffic or sunlight?
- Are underground connections safer from weather but more expensive to excavate?

## 3. Fire, utilities, and separated buildings

### Core idea

Fires create pressure to separate buildings. Stoves, furnaces, electrical networks, and water pipes become valuable but dangerous infrastructure. A fire can jump to a neighboring building when structures are too close and there is no gap or firebreak.

This encourages the player to make distinct buildings instead of one continuous block, while corridors, utility lines, and covered passages preserve functional connectivity.

### Fire-prevention choices

- Leave a gap between buildings.
- Build firebreak walls or courtyards.
- Add sprinklers and water storage.
- Separate kitchens, workshops, generators, and sleeping areas.
- Use safer building materials.
- Install valves, circuit breakers, chimneys, vents, and drainage.
- Keep emergency corridors accessible.

The player should be able to trade compactness for safety and maintenance cost.

### Recovery and rebuilding

Fire should be serious but not permanently punitive. A destroyed building should leave a recognizable foundation, ash, and salvageable remains. The player should be able to place the same blueprint on the cleared footprint and rebuild it with a predictable recipe.

Potential recovery flow:

1. Extinguish or contain the fire.
2. Clear ash and unsafe debris.
3. Salvage surviving materials.
4. Reapply the original building blueprint.
5. Reconnect utilities after inspection.

Blueprint identity is important: reconstruction should restore the same building layout, orientation, and utility ports where possible, rather than forcing the player to remember every block manually.

### Fire behavior to investigate

- Fire spreads by adjacency, combustible material, heat, and wind.
- A real gap, fireproof wall, or wet barrier can stop spread.
- Smoke and heat can make an interior unsafe before visible flames arrive.
- Sprinklers reduce spread and damage but require water pressure and maintenance.
- Fire should not randomly destroy an entire settlement without warning or a plausible chain of causes.

## 4. How these systems could reinforce one another

The strongest version combines the systems as interacting pressures:

```text
weather burial -> blocked lower access -> need for excavation or upward growth
land ownership -> bounded districts -> value of vertical and underground connections
fire risk -> separated buildings -> value of passages, courtyards, and utility planning
blueprints and salvage -> affordable recovery -> experimentation remains safe
```

The shared design goal is to make verticality, underground space, land planning, and infrastructure meaningful without making ordinary resource gathering impossible or turning setbacks into irreversible loss.

## 5. Candidate order for future prototyping

1. Prototype recoverable sand or snow accumulation on a small test map.
2. Add forecastable weather windows and protected resource patches.
3. Test land parcels, roads, and an NPC development boundary.
4. Test cross-road passages and underground access.
5. Add localized fire spread between simple separate buildings.
6. Add sprinklers, firebreaks, salvage, and blueprint reconstruction.
7. Revisit the buried pyramid as a long-term exploration landmark.

## 6. Design guardrails

- These systems should remain optional future expansion, not requirements for the opening prototype.
- Resource renewal must remain believable under weather pressure.
- The player should receive warnings and planning time before major environmental events.
- Damage, burial, and ownership disputes need reversible recovery paths.
- Vertical and underground construction should be rewarded by strategy, not forced by an opaque height cap.
- Separate buildings should be useful even when no fire occurs, through privacy, specialized workflows, zoning, and district identity.

## Optional small learning goals

Deferred by the user on 2026-10-18. Do not display tutorial milestones or next-target prompts in the current game. The HUD objective and completion message have been removed.

Keep the idea for a future onboarding discussion: offer one small, achievable goal at a time so players learn through actions and modest achievements. Revisit only if playtesting shows that players need guidance; this mechanic may never be needed. Object inspection and contextual actions are separate from tutorial milestones.
