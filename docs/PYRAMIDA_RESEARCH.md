> **Direction update — 18 October 2026:** The Ancient monument and pyramid-building objective have been removed. Older saves retire monument jobs and retain carried blocks. The monument descriptions and results below are historical research/implementation notes, superseded by `DESIGN_DIRECTION.md`.

# Pyramida: reference research and playable foundation

Research date: 18 October 2026. Reference: **Sokpop S09: pyramida**, by Sokpop Collective. This is a reconstruction of publicly documented behaviour, not an inspection of the original executable or source. The current Godot project uses its own code and editable meshes.

## Direction for this project

The immediate foundation is a small village whose people visibly gather, carry, build and process goods. Food, travel distance, labour and settlement growth should drive decisions. The latest request excludes the alien storyline and leaves enemies and weapons out of this pass. The monument is therefore a communal construction project. Finishing it leaves the settlement playable.

Vertical construction, the existing generated landscape, the starting stockpile and original character assets remain. Pipes, elaborate room classification, structural collapse and other earlier reference-game ideas are deferred until this core is satisfying.

## What the evidence establishes

### Official scope and presentation

Sokpop describes a village survival game starting at a town centre, expanding through farming, milling, housing and mining, and discovering oases, wildlife and ancient ruins. The advertised scope is five collectible resources, more than ten jobs, more than twenty structures, a day/night cycle, roughly four-plus hours, and three save slots. These are feature counts, not a complete specification of every recipe. [Official itch.io page](https://sokpop.itch.io/pyramida), [Steam store](https://store.steampowered.com/app/1390010/pyramida/).

The official images show pale sand, terracotta structures, sparse vegetation, small rounded citizens, an angled camera and blue nights. Readable silhouettes matter more than realistic detail. These browser observations do not establish the original rendering implementation. [Official visual references](https://sokpop.itch.io/pyramida).

### Controls and physical goods

Sokpop's replies confirm left-click and box selection, right-click orders, and a modifier that forces walking instead of work. Tools and unlocked capabilities affect available actions. The developer also explains that wood normally goes to a log shed, or can be used while carried, and that a drop command exists. [Developer replies on the main page](https://sokpop.itch.io/pyramida), [earlier discussion](https://sokpop.itch.io/pyramida/comments?before=26).

Storage is local. A developer reply specifically describes placing a shed near a sawmill so its worker deposits planks nearby. The same reply says general transfers between storages were considered but not implemented. Thus automatic stock redistribution in our prototype is an existing convenience, not evidence of original-game behaviour. [Developer logistics reply](https://sokpop.itch.io/pyramida/comments?after=8).

### Production and settlement progression

The detailed community strategy guide describes the opening family as two adults and one child. Its suggested sequence connects a log shed, irrigated crops, hay storage, housing, sawmill and windmill, then mining, masonry and improvements. The food chain is harvested hay/grain to bread at a mill; timber becomes planks; raw stone is shaped for advanced construction and the pyramid. Roads reduce hauling time. The author recommends two farmers and a baker as a sustainable food team, but that staffing ratio is player advice rather than an official balance guarantee. [Community strategy guide](https://steamcommunity.com/sharedfiles/filedetails/?id=2690190555).

The achievement guide independently discusses beginning with log and hay storage, a child maturing around day three, progressing to mining, and completing the objective with a small workforce. Its vegan and pacifist routes make a useful case for preserving a food-and-construction game without adding hunting or weapons. It does not establish that the original offers a fully peaceful mode. [Achievement guide](https://steamcommunity.com/sharedfiles/filedetails/?id=2379603843).

### Verified improvement effects

A direct developer answer gives unusually useful numbers: pantries add 50 food capacity to an initial 100, workshops speed applied work to 1.5 times normal, and schools double childhood growth speed. Multiple pantries are explicitly supported. The answer does not clearly establish stacking rules for multiple workshops or schools; our non-stacking rule is an implementation choice. [Developer answer about improvements](https://sokpop.itch.io/pyramida/comments?before=41).

Wells irrigate farms, and a patch explicitly corrected unfinished wells providing irrigation. This is why only completed wells count in our simulation. [Developer explanation](https://sokpop.itch.io/pyramida), [v1.2 patch notes](https://sokpop.itch.io/pyramida/devlog/167698/v12-important-osx-fix-wells).

### Lessons from the original's failure cases

The v1.5 notes address expensive road pathfinding, overly frequent enemy pathfinding and a configurable road preference. This reinforces keeping navigation searches cached and invalidating them when topology changes. Our road routes compare travel cost, and idle workers retry on a revision change or a short interval. [v1.5 patch notes](https://sokpop.itch.io/pyramida/devlog/171663/v15-lagfreeze-fixes-more).

Players reported raw and processed goods competing for storage and workers waiting with cargo. The developer notes that builders can already have reserved stone a mason is trying to collect. Reservations therefore must be distinct from consumption, and a failed delivery must retain its cargo. [Discussion of milling, masonry and reservations](https://sokpop.itch.io/pyramida/comments?before=56).

The Steam-release announcement confirms achievements and a new trailer. I used the store, developer discussions, patch notes, guides and official images; I have not claimed to watch a complete playthrough or verify frame-by-frame timings. [Release announcement](https://sokpop.itch.io/pyramida/devlog/170068/pyramida-now-on-steam).

## What changed in this repository

| System | Earlier settlement | Implemented foundation |
| --- | --- | --- |
| Gathering | Timber and watered garden food | Berry gathering and finite limestone deposits, with visible stock |
| Crops | Hay field directly yielded food | Hay fields yield grain; gardens retain their earlier direct-food role |
| Irrigation | Every plot needed a carried bucket | Same-floor completed wells and adjacent wet surface sources irrigate fields; other plots need hauling |
| Bread | Mill was a model | A baker fetches grain, works at the mill and carries bread to storage |
| Timber | All construction used logs | Sawyers produce planks; new advanced plans have saved material recipes |
| Stone | Mine and masonry were models | Mine camp enables mining; masons dress raw stone into blocks |
| Storage | Every store accepted everything | Log sheds accept timber/planks, hay barns grain, pantries food, mine camps stone/blocks; stockpiles remain general |
| Population | Fixed family of three | Houses add capacity; sustained food reserves permit children; saves and rendering support up to 30 residents |
| Improvements | Schools/workshops had no simulation effect | School doubles maturation, workshop multiplies applied work by 1.5, pantry stores 50 food |
| Commands | Selection primarily inspected workers | Box selection, persistent job choices, right-click work/move orders, and explicit idle/explorer role |
| Roads | Decorative paving | Faster walking and route selection using road travel cost |
| Objective | None | Explore to discover ruins, then physically deliver and install 40 blocks; continue after completion |
| Feedback | Few resource counts and generic descriptions | Resource counts, day/night, changing goals, working descriptions, job selector, irrigation and monument progress |
| Persistence | Three fixed workers and three resource types | Version 4 saves preserve all resources, population, jobs, claims, deposits and monument; older plans retain old recipes |

Construction, production and harvesting all use the existing physical movement and labour systems. No timers create planks, meals or monument blocks directly in storage. Grain and raw stone cannot be eaten. Reassigning a worker releases outstanding claims and preserves goods already picked up.

## Explicit adaptations and remaining differences

These are **our tuning**, not recovered original values: one grain becomes three food; processing takes four, five or six seconds; each house adds three places; growth requires 120 seconds of adequate reserves; nearby wells cover a two-cell square on their floor; the monument needs forty blocks. The starting stockpile remains 18 timber and 5 food as previously requested. It is not the original town-centre layout or the original 100-point communal food bar.

The current seven inventory types include water and food. They should not be presented as a verified reconstruction of the store's advertised five resources. The original's exact resource taxonomy, full building list, costs, work durations, crop yields, birth conditions, and map-generation rules remain unverified.

Hunger now slows applied work after a prolonged shortage; this pass does not reproduce the original's communal meal bell or colony-ending starvation. Berry regeneration and renewable trees soften scarcity. A planned structure does not grant a completed-building bonus. Automatic workers maintain limited buffers to avoid grain blocking every storage slot; dedicated roles remain available when the player wants finer control.

Discovery currently reveals the monument when a citizen approaches. There is no general fog-of-war system in the settlement scene. The existing mountain landscape and vertical platforms/ladders are preserved, rather than replacing the world with the original's flatter composition. The new resource and monument meshes are original TSCN/GLB assets. The monument is an original three-by-three-cell stepped model, not a reconstruction of the original's dimensions or ending animation.

Excluded in this pass: alien visitor, spacecraft, comet-ending narrative, skeletons/zombies, hunting, bows, weapons, defensive towers and combat. The legacy save codec recognizes retired combat-building names only to remove them safely when loading older saves.

## How to play this foundation

1. Start or continue a slot. Build a log shed and a hay field beside water; a well gives more reliable irrigation.
2. Add a hay barn, sawmill and windmill. Workers will gather and process automatically, or select them and choose Farmer/Baker/Sawyer in the job selector.
3. Add housing once food production works. A pantry provides dedicated food storage. Children consume food and become workers later; a school accelerates maturation.
4. Build a mine camp and masonry. Raw limestone is carried into storage, then dressed into blocks.
5. Select a citizen and right-click ground northwest of the starting area. Ground orders make the citizen an idle explorer until reassigned. When ruins are found, select them and begin restoration, or right-click them with selected workers. **M** centres the discovered monument.
6. Use **Automatic** to return workers to general village tasks. **V** returns to inspection, right-click cancels a building tool, and **Esc** deselects everything and cancels placement without saving or leaving play. Gameplay runs continuously at 1×, 2×, or 4×; Space does not pause.

The end-to-end proof is `tools/settlement/verify_progression.gd`: it begins with the normal starting stock, queues real construction, walks to discover the ruins, runs actual hauling/processing, and checks completion plus save/reload. It exports a separate demonstration snapshot under `artifacts/`; it does not overwrite a player save. Focused economic contracts live in `tests/settlement/economy_test.gd` and are included in `tools/settlement/run_checks.py`.

## Verification record

- All 21 regression suites passed, covering the new economy and the existing terrain, navigation, ladders, placement, rendering, UI scaling, menus, saves and asset contracts.
- The economy suite adds 62 checks, including recipes, physical input consumption, irrigation completion rules, resource-specific stores, population saves, cancellation without lost cargo, monument installation, actor creation and road preference.
- The final end-to-end run completed 13 catalogue buildings plus a stockpile, grew from three to six residents, restored all forty monument blocks, and reloaded successfully after 2,928 simulation seconds. Buildings were constructed through the real job system using the normal starting stock.
- Native Vulkan screenshots were inspected on the available Apple M1 Pro: `artifacts/peaceful-opening.png`, `artifacts/peaceful-village.png`, and `artifacts/peaceful-monument.png`. These depict this implementation, not the original game.
