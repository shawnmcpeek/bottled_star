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

**Do not put free iron in a lane.** Iron falls to the core and becomes a wall. Every radial shot hits it. “Gap between two irons” is a lie once they drift.

**Do not put iron next to iron** — not as a ring around an iron post, and not as a ring around a post that *becomes* iron (`Ar+He→Ca`, `Ca+He→Fe`). Load supernova, or a mid-line supernova that **brooms the board**. An empty bottle plus leftover hydrogen is a win.

**Do not pay “produce N helium” with a long hydrogen queue.** After any clear (supernova, capture chain, collapse) the leftover `H` just makes `He` in open space.

**Do not put calcium at the origin and call a gap a window.** Calcium is so large that a shot from the opposite hemisphere still hits it. Finale died on this twice.

**Do not use `He+Ca` walls when the goal is produce-Fe.** Grazing the wall *is* the goal. Walls and the target must yield **different** products, or the wall must be Fe (helium-inert) and far enough that a new Fe post cannot touch it.

**Do not cork hydrogen on carbon** (or any helium-capturable) expecting the helium to fall inward. The `He` is born on that body and captures immediately.

**Do not cork two bodies in an outer V** against gravity with a waist narrower than the product. Gravity presses them into the dimple. They never go around. They never go through.

**Do not spawn hydrogen overlapping a heavy.** The solver ejects the light body. On Second Door the H overlapped the outer Ca and floated to the rim — the staggered doors became a free shot. Seat it on the post (`Fe` radius + `H` radius) so gravity holds it in.

**Do not give two `H` when the intended shot is `He` past a carbon.** The player will `H+H→He` on the way in and capture whatever you were protecting. If the line is helium-only, the queue is helium-only.

**Do not design “remember the order, two shots, done” and call it a finale.** Memory is not pressure. A finale needs more than one job still in conflict after the first correct shot.

**Do not leave spare fuel “for forgiveness” on a produce-only goal.** Extra `H` or `He` becomes a bypass. Cut the queue to the intended line. Budget equals sequence length.

---

## Dos (patterns that survived)

**Hydrogen pin.** A light `H` at or near the origin keeps same-tier heavies from meeting. They fall onto the pin, not onto each other. Cheap, honest, works.

**Inert post + ring of something that cannot merge with it.** `Fe` post + `Ca` ring keeps gaps open (`Ca+Ca` inert, `He+Fe` inert). `Ar` post + non-iron ring is the climb version. Never `Fe` post + `Fe` ring.

**Face body + `neverProduce` on the graze.** Threading: carbon on the window face, helium-only queue, `neverProduce O`. The window is real because missing it makes oxygen.

**Sequential helium captures as “timing.”** You cannot sync arrivals. You *can* require two separate `He` hits on a post (`Ar→Ca→Fe`) with `neverProduce C`. Fire both too soon and the heliums meet. Wait for the first capture, then send the second. That is the only timing this gravity allows.

**Opposite jobs, tiny budget.** Two seeded `H` in opposite gaps, queue `H, H`, one shot each. Same-window twice wastes the second shot. Forces the board, not the queue.

**Walls must not produce the goal.** If the goal is `Fe`, cheeks cannot be `Ca`. If the goal is `Ne`, cheeks cannot be `O`. Graze fail (`neverProduce` the wall’s climb product) is how a slim window earns its name.

**Produce-only wins on create.** A later capture must not void a goal that already landed. Occupancy still waits for settle, and not before the first shot.

**Cap the queue to remaining budget.** Leftover sequence after the last legal shot is a lie on the HUD.

**Hold the board after win/fail** before the end card. Players need to see *why*.

**Budget loss waits for a quiet board, not the shot clock.** A tap hydrogen takes ~2s to cross the chamber. If settle is “1.2s since last shot,” Iron Wall’s second helium still makes the iron — after the run has already been called lost. Quiet = nothing moving faster than `challengeSettleSpeed`. Produce-only still wins the instant the element is created.

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
| `He` queue + face `C` + `neverProduce O` | Real window |
| Opposite seeded `H`, budget 2, climb post, `neverProduce C` | Two doors + stagger |
| Produce-only + tiny fuel | No broom-then-farm |
| `noSameTier` on a heavy-ladder | Blocks skip, keeps `H+H`/`He+He` |

If a new level needs a behavior that is not in this table, it probably needs a seed rewrite, not a new rule in code.
