# Challenge level design bible

Lessons from playtesting packs 1–3. Use this before adding levels past 60, and before rewriting a level that “should work.”

The engine does not care about the intended line. Radial gravity, pairwise fusion, and live radii will play the board for you — usually by winning, losing, or supernova-ing on load.

JSON in `assets/levels/` does **not** reload on hot restart. Full `flutter run` after every pack edit.

---

## Physics you must design against

Gravity is always toward the origin. Acceleration is `40 × (atomicMass / 4)`:

| Element | Radius | Accel | Notes |
|:--|--:|--:|:--|
| H | 14 | 10 | Almost a pin. Hits do not move heavies. |
| He | 18 | 40 | The only climber. |
| C | 23 | 120 | |
| O | 28 | 160 | |
| Ne | 34 | 200 | |
| Mg | 41 | 240 | Same-tier inert |
| Si | 49 | 280 | |
| S | 58 | 320 | Same-tier inert |
| Ar | 68 | 400 | Same-tier inert |
| Ca | 80 | 400 | Same-tier inert. Huge. A core Ca eats any “gap shot.” |
| Fe | 94 | 560 | Helium-inert. `Fe+Fe` is supernova, not a merge. |

Chamber radius is 320. `radiusFrac` is a fraction of that. Inert bump impulse (180) is negligible against Ca/Fe mass. Linear damping is 0.4 — things still arrive at the origin, they just do it with less bounce.

Nothing “arrives at the same time.” The first body sits on the origin and waits. Timing puzzles that need simultaneous arrival do not exist in this bottle.

**Carbons on a free `Fe` creep together.** The core wobbles, and bodies on its surface drift toward each other. A 30° pair merges in about 10 s, and 40–55° pairs merge somewhere between 15 and 70 s. Pairs 60° or more apart stayed put for 90 s. Close-pair eliminate levels live on this. Treat the timing as noisy, not as a fuse.

**A loss is judged once the last shot settles.** A creep merge that would have come after it does not count. "Wait for the pair" only works while you still hold a shot.

**`H` and `He` cannot force a merge on demand.** An `H` landing next to the pair does not reliably close a 30° gap, and `He` on carbon is oxygen. To pair carbons when *you* choose, fire carbon at carbon: `C` ammo merges on contact.

**An `H` pin holds two opposite `C` forever, but not three.** Knock the pin with an inert heavy (`O`) and they collapse into `Mg`. Almost any oxygen shot does it, so the pin needs a gate to be a challenge.

Verify a new board with `test/level_sim_harness.dart`: one line that wins, and no free win from waiting.

---

## Fusion (what actually happens)

Pairwise only. No three-body.

- `H+H → He`
- `He+He → C`
- `He + heavy → next rung`, **except** `He+Fe` which is inert
- Same-tier skip two rungs: `C+C→Mg`, `O+O→S`, `Ne+Ne→Ca`, `Si+Si→Fe`
- `Mg`, `S`, `Ar`, `Ca` self-pairs are inert
- `Fe+Fe` detonates
- `H` is inert to everything except `H`

`noSameTier` blocks **heavy** self-pairs only. Fuel still works: `H+H` and `He+He` stay legal. Do not design a “no hydrogen pairing” puzzle with that flag.

Seeded bodies do **not** count as produced. A produce-Ca goal is not already met because a Ca is sitting on the board.

---

## Don'ts (burned in playtest)

**Do not let gravity play the level.** If two same-tier mergeables can fall into each other, they will, on load, before the first shot. If a produce or occupancy goal can complete from that, the level is free. If a `neverProduce` fires from that, the level is an instant fail.

**Do not use occupancy (`boardUnder`) as the only goal** unless something on the board *prevents* the collapse, and the player still has to shoot. The engine already refuses occupancy wins before the first shot — that is a seatbelt, not a puzzle.

**Do not put the target, or a pairing hydrogen, in a ring gap.** That is the spawn, not a later slide. Trapped Target’s 6 Ar around Fe left O and H sitting in an open door — two H to He to Ne, no puzzle. Cover the target at the origin, or put a face on the same ray as the shot.

**Do not put iron next to iron** — not as a ring around an iron post, and not as a ring around a post that *becomes* iron (`Ar+He→Ca`, `Ca+He→Fe`). Load supernova, or a mid-line supernova that **brooms the board**. An empty bottle plus leftover hydrogen is a win.

**Do not pay “produce N helium” with a hydrogen queue.** Two Chances with a neon cage and ten `H` is free: they pair in open space and never use a door. The goal has to live *in* the cage (capture oxygen, etc.).

**Do not put silicon around an iron post unless the broom is the puzzle.** `Si+Si→Fe`, then `Fe+Fe` supernova. Oxygen at `radiusFrac` 0.36 sits at 115 — just outside `kVaporizeRadius` 112 — so the default blast *pushes* it instead of deleting it. A leftover O plus helium is a free neon. If the line is boom-then-ladder, set `rules.supernovaClears` so the whole blast radius ejects, and give a helium queue that can rebuild (`He+He→C`, `He+C→O`, `He+O→Ne`). If the line is thread-the-door, use `noSameTier` so the cage cannot detonate.

**Do not put calcium at the origin and call a gap a window.** Calcium is so large that a shot from the opposite hemisphere still hits it. Finale died on this twice.

**Do not use `He+Ca` walls when the goal is produce-Fe.** Grazing the wall *is* the goal. Walls and the target must yield **different** products, or the wall must be Fe (helium-inert) and far enough that a new Fe post cannot touch it.

**Do not cork hydrogen on carbon** (or any helium-capturable) expecting the helium to fall inward. The `He` is born on that body and captures immediately.

**Do not cork two bodies in an outer V** against gravity with a waist narrower than the product. Gravity presses them into the dimple. They never go around. They never go through.

**Do not spawn hydrogen overlapping a heavy.** The solver ejects the light body. On Second Door the H overlapped the outer Ca and floated to the rim — the staggered doors became a free shot. Seat it on the post (`Fe` radius + `H` radius) so gravity holds it in.

**Do not give two `H` when the intended shot is `He` past a carbon.** The player will `H+H→He` on the way in and capture whatever you were protecting. If the line is helium-only, the queue is helium-only.

**Do not design “remember the order, two shots, done” and call it a finale.** Memory is not pressure. A finale needs more than one job still in conflict after the first correct shot.

**Do not run the same trick across four levels.** Spark → Higher Up → No Shortcuts is a family: pair, pair with a pin, then the pin without the shortcut. A neon clone of that pair (`Compound Interest` / `Taxed`) is not a new level. After the family, invert or leave (hit the pin, make the twin, wait, dump, park).

**Do not use a hydrogen pin when the queue is hydrogen.** Empty Half: `H` pin + seeded `He` + two `H` is Pin Is Fuel. One shot into the pin makes helium on top of helium, and gravity scores carbon. The pin and the queue cannot be the same merge. Use lead, and put a hungry oxygen on the other half so pairing at the hub is neon.

**Do not ask helium to sit on a hydrogen pin between two oxygens.** Don’t Go In: `H` is radius 14, oxygen rests at 42, helium on the pin at 32. Distance to oxygen is 53, and they touch at 46 — six pixels of “lane.” Every real shot grazes neon. Lead (40) opens a real equator; iron (94) makes the same shot free. Use lead.

**Do not leave spare fuel “for forgiveness” on a produce-only goal.** Extra `H` or `He` becomes a bypass. Cut the queue to the intended line. Budget equals sequence length.

**Do not hide a rule that can end the run.** `neverProduce`, `maxOfElement`, `maxTotalProduced`, and `noSameTier` go on the HUD under RULES and on the level-select line. The fail card names the rule. `maxBodies` is a pile seatbelt — keep it off the HUD unless the cap *is* the puzzle.

**Do not put a rule on a level if it is not the puzzle.** Helium-on-helium is carbon on every helium queue. That does not earn a `neverProduce C` unless waiting is the challenge. If the player can ignore the rule and still play the intended line, delete it.

**Do not hang `neverProduce` on a one-shot produce.** Park It / Poison / Gap Is Iron / Caged / Two Bites: miss the target and the budget already fails the goal. The HUD is just **Produce X**. Keep `neverProduce O` on Narrow Window and Threading — those levels *are* the graze, and they teach it. Keep it on Hold Your Fire: two helium, graze then climb would otherwise still win.

**Climbing one post until the HUD lights up is not Challenge.** Argon in an empty bottle with two helium is Classic. The wait between captures is only a puzzle when a face, a twin, a blast, or a second job is already on the board. If the intended line is `He` on the same body N times, rewrite the seed. Pack 1 may teach capture, stop, knock, and `noSameTier` in the first four levels. From Caged on, every board needs a miss that is already on the screen.

**Do not cap argon with a static carbon inside a window the carbon fills.** Hold Your Fire’s first window: carbon sitting on argon, arc ±27°, helium+carbon wider than the rim. Sliding to the edge cannot clear. If the face should *gate* the window, it has to move.

**A seed `orbit` is a pendulum, not a 360.** `sweepDeg` ≤ 180, on `placement: "point"` only. Kinematic — gravity does not pull it, and quiet-board settle ignores it (otherwise the run never ends). Radius must clear the *grown* core (`Ar→Ca→Fe`). The window half-width must be smaller than `asin((faceRadius + He) / R)` or it never closes. The sweep half-width must exceed window half-width + that blocked angle or it never opens. Short period. Do not put this on four levels in a row.

**Do not `neverProduce` a miss that the shot budget is meant to pay for.** Trapped Target: helium on a cage neon makes magnesium. That is a spent shot and a worse slit, not an instant fail at 1/3. Spare helium means they can miss. `neverProduce` is for a line that is already on the screen (Threading: never produce O) so a graze is the puzzle, not a surprise.

---

## Dos (patterns that survived)

**Hydrogen pin.** A light `H` at or near the origin keeps same-tier heavies from meeting. They fall onto the pin, not onto each other. Cheap, honest, works.

**Inert post + ring of something that cannot merge with it.** `Fe` post + `Ca` ring keeps gaps open (`Ca+Ca` inert, `He+Fe` inert). `Ar` post + non-iron ring is the climb version. Never `Fe` post + `Fe` ring.

**Lead hub (`Pb`) for a small center.** Seed-only. Helium does not climb it. Two leads do not supernova. Radius 40 vs iron 94, so a neon cage can sit close enough that opposite hydrogens are slits, not doors. Iron as a hub makes Two Chances free. A carbon cap on the same ray as the oxygen does nothing — side shots still see the full disc. Do not put lead in the injector. Lead is a static body: it never moves, so off-origin lead works as a fixed peg, and bodies resting on it settle. On a lead hub, calcium rests at 120 and iron at 134. Calcium and iron touch when they are less than about 86° apart. Two irons touch at 88° and stay apart at about 92°. Bodies seeded overlapping on lead push apart on load and stay apart, because nothing slides them back together, and hydrogen or helium can't bump them. To make the player knock two bodies together, give a carbon knocker in the queue (inert with oxygen, heavy enough). It has to land just behind a body, on its outer side (Rationed, Compounded: twin oxygens 70° apart on lead, knock from 5–40° behind either one). Neon knocks too easily.

**When a merge product must stay against a neighbor, use `fixed` and `absorbMerges`.** A dynamic iron core jiggles, so resting bodies walk apart. A midpoint spawn plus the incoming push and the inert bump carries the product away. `"fixed": true` on a seed body makes it static. `rules.absorbMerges` spawns the product where the heavier body sat and turns off the inert bump. A static core has no restoring force sideways: anything knocked rolls around it, so cradle climbing bodies with lead pegs.

**A patrol is absorbed into its target.** When an orbiting body merges, the product spawns where the target was, not at the midpoint. Before this rule, a helium arriving from outside dropped each new silicon about 13° outward.

**Challenge supernovas are deterministic.** The blast is symmetric, with a hard vaporize edge at 112 and a push out to 240. The same shot always gives the same chain, so whether the player wins never depends on blast luck.

**Let the ammo carry the rule.** Four hydrogens can make at most two heliums. Don't show a rule that the queue already enforces.

**Fire-all-shots levels need a tight arc.** The leftover shots have to be placed apart, and a wide arc makes that free. The HUD says "Fire all N shots."

**Face body + `neverProduce` on the graze — and show it.** Threading: carbon on the window face, helium-only queue, `neverProduce O` on the HUD. The window is real because missing it makes oxygen, and the player can read that before they fire.

**Sequential helium captures as “timing.”** You cannot sync arrivals. You *can* require two separate `He` hits on a post (`Ar→Ca→Fe`) with `neverProduce C`. Fire both too soon and the heliums meet. Wait for the first capture, then send the second. That is the only timing this gravity allows.

**Opposite jobs, tiny budget.** Two seeded `H` in opposite gaps, queue `H, H`, one shot each. Same-window twice wastes the second shot. Forces the board, not the queue.

**Walls must not produce the goal.** If the goal is `Fe`, cheeks cannot be `Ca`. If the goal is `Ne`, cheeks cannot be `O`. Graze fail (`neverProduce` the wall’s climb product) is how a slim window earns its name.

**Produce-only wins on create.** A later capture must not void a goal that already landed. Occupancy still waits for settle, and not before the first shot.

**Cap the queue to remaining budget.** Leftover sequence after the last legal shot is a lie on the HUD.

**Hold the board after win/fail** before the end card. Players need to see *why*.

**Budget loss waits for a quiet board, not the shot clock.** A tap hydrogen takes ~2s to cross the chamber. If settle is “1.2s since last shot,” Iron Wall’s second helium still makes the iron — after the run has already been called lost. Quiet = nothing moving faster than `challengeSettleSpeed` (50) for `challengeSettleSeconds` (3.0). The 3 seconds is for slow slides: a knocked oxygen creeps into its twin at 20–40. Don't lower the speed bar instead, because bodies on a dynamic iron core jitter at 10–35 forever and the run would never end. Produce-only still wins the instant the element is created.

---

## Goal / constraint checklist (run this on paper)

1. What happens if the player never fires? If that wins or loses, rewrite the seed.
2. What happens if everything falls to the origin? Name the pairwise contacts. Legal merge, inert rest, or supernova?
3. If the post climbs (`+He`), does it become something that detonates or shortcuts against the ring?
4. Can `H+H` or `He+He` skip the intended target?
5. Does any wall body yield the goal element when grazed by `He`?
6. Is the shot budget exactly the intended line, with no leftover hydrogen?
7. Does an injection arc still mean anything after bodies drift for one second?
8. Is iron used as scenery, product, or both? It cannot be both in contact.
9. If a constraint can end the run, is it on the HUD and the fail card? If a miss should spend a shot, it is not `neverProduce`.

---

## Radii cheat (will they overlap?)

Centers must be at least `r1 + r2` apart. Origin post vs ring:

`radiusFrac * 320 >= postRadius + ringRadius + a few pixels`

When the post **climbs**, recompute with the new radius. `Ar(68)→Ca(80)→Fe(94)` is a common trap: a ring that cleared argon does not clear iron.

---

## Verified-ish motifs (steal these, don’t invent new physics)

| Motif | Why it works |
|:--|:--|
| `H` pin + same-tier ring | Stops AFK self-merge |
| `Fe` post + `Ca`/`Ar` ring | Gaps stay; no supernova |
| `Pb` hub + two O with Ne clamshells, He×3, produce 2 Ne, `noSameTier` | Two Chances: polar C caps leave the O open from the side. Cheeks must block the equator. He+C on a face makes a new open oxygen — cheeks are Ne. `noSameTier` so the new Ne does not eat a cheek into Ca |
| Fe post + 6 Si, `supernovaClears`, He×4, `neverProduce S` | Deadbolt broom deletes O; rebuild Ne from He, or thread the door first |
| `He` queue + face `C` + `neverProduce O` | Real window |
| Opposite seeded `H`, budget 2, climb post, `neverProduce C` | Two doors + stagger |
| Target at origin, 3 Ne sitting on it, He queue, `noSameTier` | Ne shell; miss grows Mg and costs a shot; `noSameTier` so the new Ne does not become Ca |
| Produce-only + tiny fuel | No broom-then-farm |
| `noSameTier` on a heavy-ladder | Blocks skip, keeps `H+H`/`He+He` |
| Same board, hit the pin (`H+H` at origin → `He+O`) | Inverts Higher Up. One family, then stop. |
| `C` + `O` on a pin, `He` the carbon, knock `O+O`, `neverProduce Ne` | Make the twin, then the trick they already know |
| Sweeping `C` on `orbit` across a tight `injectionArc`, two `He`, `neverProduce O`+`C` | Hold Your Fire. Window closed at center, open at the ends. Second helium waits for the next gap *and* the first capture. `He+He` is still carbon. |
| `H` pin between two `Ca`, sweeping `C` gating a top-only `injectionArc`, one `H` | Park It. Thread hydrogen to the core hydrogen (about ±8° of lane). `H+H→He`, then `He+Ca→Fe`. Helium ammo makes calcium a barn door. Keep both calciums or the pin is not in the middle. |
| Two `C` on `orbit` around `Pb`, opposite phase, `He`×2, eliminate C | Clean Slate. Orbit as a moving *target*, not a gate. Lead the shot; turnarounds are the slow part. A miss parks on the lead. |
| Two `C` on `Pb`, 60° apart, queue `He`, `H` | Poison. Park the helium on the lead away from them, then knock. At 38° they already touch on load — Mg before the first shot. |
| `C` sweeps only the oxygen face; calcium is a static second job | One Each. Do not clamp the injector to the oxygen — that blocks the calcium. |
| `H` pin between two `C`, `He` patrolling on `orbit` above it, top `injectionArc`, one `O`, `neverProduce Ne` | Housekeeping. The pin holds forever. Oxygen knocks it and the carbons collapse to Mg. Time the oxygen between patrol passes; touching the helium makes neon. |
| `Fe` + real pair 30° apart + decoy pair 60° apart, `He`×2 | Don't Look Away. The decoy never merges. Helium the decoys, then let the real pair creep together before spending the last shot. |
| `Fe` + `Ca` on the face + three `C` 70° apart, `He`×2 | The Last One. Three carbons, two helium, no pairs: impossible without the blast. `He+Ca→Fe`, `Fe+Fe` knocks carbons together and clears the rest. Second helium cleans up. |
| `C` swinging high above `Fe` (0.6) + `O`, queue `C`, `He`, produce Ne + eliminate C | Two Bites. You carry the partner. A carbon that misses lands on the iron, below the swing, and is stranded. |
| `Fe` + two `C` 38° apart at the top, two `He` patrols closing in from the outer sides, queue `C`×2, supernova 1, `neverProduce O` | Let It Ride. Make both magnesiums before the heliums arrive (about 4 s). Each patrol turns its magnesium into silicon in place, the silicons touch and make iron, and the iron on the core detonates. Aiming the two shots inward makes the silicons spawn too close and shove apart. |
| `Fe` + `Ca` (0.55) + `C` sweeping above it, `H`×4, supernova 1 | First Light. Pair hydrogens on the calcium between carbon passes. Hydrogen that touches the carbon is wasted. |
| `Pb` + `Fe` at 0/176/268 + `Ca` at 88, one `He`, supernova 2 | Chain Reaction. Lead keeps the irons apart. Only a square hit on the calcium chains through the lead. A glance gives one blast. |
| Chain board + `C` sweeping the rim above the `Ca`, `H`×2, supernova 1 | Rim Runner. Both hydrogens must pass the sweeper and meet on the calcium. |
| `Pb` + `Fe`/`Ca` pairs at 0/88 and 180/268, two sweeping `C` guards, `He`×2, supernova 2 | Two Points of Light. The first shot is timing-gated. The blast takes the lead, then find the calcium that's left. |
| `Fe` + two `Mg` at 72°/108° + `Pb` pegs at 35°/145° (0.42) + sweeping `C` guard, `He`×2, supernova 1 | Two Is Enough. `He+Mg→Si`, `Si+Si→Fe`. Without the pegs, the first silicon grows and shoves the other magnesium away, so the silicons never meet. The pegs fence the pair, and the guard is the challenge. |
| `Fe` + two `C` on mirrored `orbit`s, `H`×4, eliminate C | Vanishing Act. The carbons can't be hit directly. Pair hydrogen into a helium where a carbon will sweep through it. |
| `Ar` core + four `Pb` pegs (0.52) + `C` at 105, `H`×2, arc 90/50, produce Ca | Rationed Cage. Pair at the far edge of the gap (66–72°). Helium near the carbon makes oxygen. |
| Dump `He` on `Pb`/`Fe`, then knock | Helium is poison; the hub is the sink |
| Two `Ca`, two `He`, `maxOf Fe` 1 | Climb one, park the extra helium on the iron |
| `Pb` + `O` vs seeded `He`, two `H`, `neverProduce Ne` | Empty Half: pair on the helium's side. Hub pairing corks `He+O` |
| `fixed` Fe core + `C` 0°/0.366 and `O` 25°/0.381 (resting in contact) + `Ar` 180° cradled by `Pb` pegs at 136°/224° (0.42) + `C` guard sweeping the argon (0.83, sweep 70, period 3), 6`H`, produce S + supernova, `neverProduce Ne`/`C`, `supernovaClears`, `absorbMerges` | Pack-3 Everything. Any helium that reaches the carbon makes sulfur; one that touches the oxygen first makes neon. The climbs only pass the guard at its turnarounds (about 1 in 3 timings). |

If a new level needs a behavior that is not in this table, it probably needs a seed rewrite, not a new rule in code.
