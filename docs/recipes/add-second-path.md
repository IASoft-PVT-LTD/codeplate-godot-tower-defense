# Add a second path (more spawns)

Use when the user wants enemies to come from more than one cave: two or more spawns, each with its own path to the shared goal, and waves that say which path each group takes.

Routes are part of the core, so this is a map edit and a wave edit, no code. Route 0 is `S` (spawn) and `P` (path). Route 1 is `R` (spawn) and `Q` (path); both are already in `content/legend.json`. Each route is traced on its own, so paths may run side by side (leave one empty cell between them); they only meet at the goal `G`. A map without `R` or `Q` is a one-route map and plays as before.

0. **Ask which level gets the second road.** Don't add one to an existing level unless the user names it; a new level is the safe default. If a level has to change, say what changes and why before you do it (rule 5 in `AGENTS.md`).
1. **Draw the map.** Put one `R` where the second enemy cave is and a `Q` path from it to `G`. The path must not fork and must reach `G` without touching route 0's cells. Example, `content/levels/level_07.txt` (20 columns):
   ```
   ..R...........T.....
   ..Q.........b.......
   ..QQQQQQQ.........B.
   ........Q.....~.....
   ........QQQQQQQQQQQQ
   .T.................Q
   SPPPPP.............Q
   .....P....m........Q
   .....PPPPPPPPPPPPPPG
   L..........g.......L
   ```
   Every row the same width, as with any map (`docs/content.md`). The checks name the route, row and column of a mistake ("route 1: the path stops at row 3 col 5").
2. **Say which route each group walks.** In the level's `.json`, give a wave group `"route": 1`. A group without `"route"` walks route 0. Alternate routes between groups so both roads need towers:
   ```json
   {"enemy": "grunt", "count": 8, "gap": 1.2, "route": 1}
   ```
   Splitters keep their route: what a splitter splits into walks on from where it died. Flyers fly straight from their route's cave to the goal.
3. **More routes.** For a third road add two letters to `content/legend.json` with `"route": 2` (a spawn and a path letter) and use them the same way. Routes are numbered 0, 1, 2 without gaps; a wave naming a route the map lacks is a content error.
4. **Let it be fair.** The balance bot covers every route when it picks cells. Run `tools/balance.gd -- level=level_07` and adjust `start_gold` and the waves until the bot wins with at least `bot_min_lives` of its lives and the idle run loses (`docs/recipes/tune-balance.md`).
5. **Caves.** Every spawn cell gets a cave. Frame N of `assets/tiles/spawn.png` is used for route N when the strip has that many frames; otherwise the frames repeat.

## Verify

1. Run the checks. `test_every_level_is_fair` and the map validation cover the new level; `test_a_second_route_walks_its_own_path` in `checks/tests/test_battle.gd` shows how to check a route on a small made-up map. Copy its style if you add a rule.
2. Run `tools/balance.gd` and tell the user how the new level plays.
3. Take `screen=battle level=7 wave=4 wait=1` and look: a cave at each spawn, enemies on both roads, towers covering both.
