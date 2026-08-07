# Bottled Star — Core Mechanics

**Studio:** Daddoo Dev  
**Stack:** Flutter + Flame + forge2d (`flame_forge2d`)  
**Status:** Milestone 1 playable — near-production tester build in progress

---

## 0. Naming and branding

**Name: Bottled Star.** From the phrase fusion researchers use for what a tokamak is trying to be — a star, held in a container.

Two-field strategy so the name works in both places it has to live:

| Field | Value | Why |
|:--|:--|:--|
| App Store / Play listing title | Star in a Bottle | More evocative and more searchable; 30-char limit gives room |
| `CFBundleDisplayName` (iOS) | Bottled Star | 12 chars — fits under the icon without truncation |
| Android manifest `android:label` | Bottled Star | Same |
| Linux `APPLICATION_ID` | `pro.daddoodev.bottledstar` | Dev playtest only — not a ship surface |
| Bundle ID / package | `pro.daddoodev.bottledstar` | Locked — no `com.example` leftovers |
| Domain | `bottledstar.app` | The one people would actually type |

iOS clips icon labels at roughly 12 characters. "Star in a Bottle" is 16 and would render as "Star in a Bo…" on every home screen, which is why the short form owns the launcher.

**Clearance still outstanding.** Web searches came back clean for both variants — no games under either name — but that is a smoke test, not clearance. Before any store listing or bundle ID is registered:

- [ ] Direct App Store search, both variants
- [ ] Direct Play Store search, both variants
- [ ] USPTO TESS lookup
- [ ] Steam search, if a desktop port is ever on the table
- [ ] Domain availability for `bottledstar.app`

---

## 0b. Locked product decisions (Jul 2026)

Decisions for the near-production tester build. Treat these as constraints unless explicitly reopened.

| Decision | Choice | Notes |
|:--|:--|:--|
| Ship target | **Mobile** (iOS + Android) | No desktop/web ship plan |
| Dev playtest | Linux (and other desktop) OK | Mouse + keyboard so desktop testing works while developing |
| Orientation | Portrait | Locked on iOS/Android manifests |
| Visual bar | Production-feel, not prototype placeholders | Warm lantern glow, glossy nuclei, merge flashes, rim warning |
| Audio | **None for now** | Silent build; SFX later |
| Persistence | Local high score + peak element + run count | `shared_preferences`; no cloud |
| Codex | **Deferred** | Design in §9 stands; do not build yet |
| Analytics / crash | **None for now** | No Sentry/Firebase until asked |
| Helium-rule mitigation | **Inert bump feedback shipped** | Soft shove + ripple on non-merges; energetic helium look also on |
| Injection contents | **Suika-style weighted queue** | Unlock by highest element this run; cap at neon; H/He weighted high |
| Same-tier fusion | **Shipped** | C+C→Mg, O+O→S, Ne+Ne→Ca, Si+Si→Fe; Mg/S/Ar/Ca self still inert |
| Signing / store delivery | **Keystore + Play API ready** — ASC / Codemagic wiring next | See §0c. Secrets never in git. |
| Quality bar | Play as if production | No placeholder art, no stub UI, no “spike-only” presentation |
| Typography | Space Grotesk + Fraunces | Bundled OFL faces in `assets/fonts/` — no runtime network fetch |

---

## 0c. Android release signing (non-secret)

Generated locally Aug 2026. File is gitignored (`*.jks`, `*.keystore`). Passwords live in the password manager + Codemagic secure vars only.

| Field | Value |
|:--|:--|
| Keystore file | `bottled-star-upload.jks` (repo root, ignored) |
| Store type | JKS |
| Alias | `bottledstar` |
| Key alg | RSA 2048 |
| Validity | 10000 days |
| Package / applicationId | `pro.daddoodev.bottledstar` |
| DN | `CN=Shawn McPeek, OU=Bottled Star, O=Daddoo Dev, L=Firestone, ST=CO, C=US` |

Codemagic vars: `CM_KEYSTORE_PATH` (set by Codemagic when the keystore is uploaded), `CM_KEYSTORE_PASSWORD`, `CM_KEY_ALIAS=bottledstar`, `CM_KEY_PASSWORD`.

**Android release signing is wired in `android/app/build.gradle.kts`.** Release builds use the `release` signing config (Codemagic env or local `android/key.properties`). Debug signing is never used for release.

This project has **no flavors** and **no `lib/main_prod.dart`**. Codemagic Android/iOS/Web build arguments must be empty or only `--release` — do not pass `--flavor …` or `-t lib/main_prod.dart`.

Local release key.properties (gitignored), path relative to `android/`:

```
storePassword=<keystore password>
keyPassword=<key password>
keyAlias=bottledstar
storeFile=../bottled-star-upload.jks
```

## 0d. Google Play publishing (non-secret)

Service account created Aug 2026 for Codemagic → Play uploads. JSON key is gitignored; full JSON contents live in Codemagic as secure env `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS`.

| Field | Value |
|:--|:--|
| Cloud / Firebase project | `bottled-star` |
| Service account email | `codemagic-play@bottled-star.iam.gserviceaccount.com` |
| Local key file (ignored) | `bottled-star-10dbe909c7b2.json` |
| Codemagic env | `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` |
| Play package | `pro.daddoodev.bottledstar` |
| Play Android Developer API | Enabled / connected |
| Play Console permissions | Granted to the service account email |

Still needed: App Store Connect API key (`.p8`) if not done; Codemagic workflow — Mode Release, AAB, **clear flavor/main_prod args**.

### Explicitly out of scope for this build

- Codex screen
- Audio / music
- Analytics, crash reporting, remote config
- Desktop/web store presence
- Helium injection powerups (as a separate mechanic — He can already appear in the normal queue once unlocked)
- Injecting anything above neon (Mg+ stays merge-only)
- Mg/S/Ar/Ca same-tier merges (not on ladder as products)

---

## 1. Pitch

A drop-and-merge physics game set inside a circular fusion chamber. You inject hydrogen from the rim; gravity pulls everything toward the center. Hydrogen fuses into helium, helium fuses into carbon, and from there helium is the reagent that levels everything else up the periodic ladder.

The player never gets a chemistry lesson. They learn the order elements are built in the same way a Suika player learns cherry-grape-orange: by playing.

**The name is the art direction.** A star, held in a container. That means the chamber should read as a warm glowing object you are keeping contained — not a cold laboratory readout. Warm interior light, a visible physical rim that feels like it is holding something in, dark space outside. Closer to a lantern than an instrument panel. Every UI decision that could go either "sterile lab" or "contained star" should go toward the star.

---

## 2. Core loop

1. Aim the injector around the rim, choose power, fire a hydrogen nucleus.
2. Hydrogen settles into the pile. Two touching hydrogen merge into helium.
3. Helium is light and drifts outward toward the rim.
4. Player steers helium into either another helium (making carbon, opening a new ladder) or into an existing heavy tile (pushing it up one rung).
5. Heavy elements sink toward the core and stop being a problem.
6. Run ends when the pile breaches the containment rim.

The tension is helium contention. Every helium can do exactly one of two jobs, and choosing wrong crowds the rim.

---

## 3. The ladder

Eleven tiers. Iron is terminal.

| Tier | Symbol | Name | Radius (world units) | Atomic mass | Score on create |
|-----:|:-------|:-----|---------------------:|------------:|----------------:|
| 0 | H | Hydrogen | 14 | 1 | 0 |
| 1 | He | Helium | 18 | 4 | 1 |
| 2 | C | Carbon | 23 | 12 | 3 |
| 3 | O | Oxygen | 28 | 16 | 6 |
| 4 | Ne | Neon | 34 | 20 | 10 |
| 5 | Mg | Magnesium | 41 | 24 | 15 |
| 6 | Si | Silicon | 49 | 28 | 21 |
| 7 | S | Sulfur | 58 | 32 | 28 |
| 8 | Ar | Argon | 68 | 40 | 36 |
| 9 | Ca | Calcium | 80 | 40 | 45 |
| 10 | Fe | Iron | 94 | 56 | 100 |

Radii grow at roughly 1.18× per tier. Chamber inner radius is 320, so a full-size iron nucleus is about 29% of the chamber diameter.

Titanium and chromium sit between calcium and iron in reality. They are deliberately omitted to hold the ladder at eleven tiers. This is the same license Suika takes turning a cherry into a grape.

---

## 4. Merge rules

Two rules. No exceptions, no timers, no special cases.

**Rule 1 — Hydrogen and helium self-pair.**
```
H  + H  -> He
He + He -> C
```

**Rule 2 — Helium levels up anything at carbon or above (except iron).**
```
He + C  -> O
He + O  -> Ne
He + Ne -> Mg
He + Mg -> Si
He + Si -> S
He + S  -> Ar
He + Ar -> Ca
He + Ca -> Fe
```

**Rule 3 — Same-tier fusion (skips two rungs).** Piece radii unchanged.
```
C  + C  -> Mg
O  + O  -> S
Ne + Ne -> Ca
Si + Si -> Fe
```

**Mg+Mg, S+S, Ar+Ar, Ca+Ca stay inert** — their summed masses are not on the ladder.

**Precedence:** when a body could same-tier-merge and helium-capture in the same frame, resolve **same-tier first**. One merge per body per frame (consumed set). Resting pairs are scanned geometrically after each step (and on load) so hot reload still fires merges.

**Scoring note:** C→O→Ne→Mg via helium scores 31; C+C→Mg scores 15. Fast route pays less — leave it unless testers abandon helium entirely.

**Iron + iron → supernova (mid-run).** Two irons in contact detonate: both removed, large score bonus, radial shockwave (equal impulse — light nuclei flung farther). No manual trigger. Iron sinks to the core, so a second iron will find the first; the decision is whether to *complete* a second iron given rim state. Sink time is the readable fuse. Do not add a player-fired detonation.

**Known limitation:** same-tier fusion does not reduce chamber pressure (radii unchanged). If the chamber still clogs after playtests, raise chamber radius next — not artwork.

### Known design risk

Players arriving from Suika will instinctively try to collide two same-tier tiles above helium. C/O/Ne/Si now work; Mg/S/Ar/Ca still do not. Helium remains the reagent for single-step climbs.

Mitigations already shipped:
- **Visual** — helium energetic treatment.
- **Feedback** — inert bump when non-merging tiles collide.
- **Same-tier fusion** — C/O/Ne/Si pairs (this task).

Do not add Mg/S/Ar/Ca self-merges without a ladder extension.

---

## 5. Chamber and physics

### Radial gravity

There is no global gravity vector. Each body receives a per-tick force directed at the chamber center.

**Critical detail:** applying `F = mass * g` gives every body identical acceleration, exactly like real gravity, and produces **no sorting at all**. To make heavy nuclei sink and light ones rise, acceleration must scale with density:

```dart
// Applied per body, every physics tick
final toCenter = (chamberCenter - body.position);
final dir = toCenter.normalized();
final relativeDensity = tier.atomicMass / referenceAtomicMass; // ref = He (4)
final accel = gravityStrength * relativeDensity;
body.applyForce(dir * (body.mass * accel));
```

This is a buoyancy model dressed as gravity. Hydrogen (mass 1) accelerates inward at 0.25× the helium rate; iron (mass 56) at 14×. Under contact pressure, dense bodies displace light ones toward the rim.

Set `fixture.density` from a separate visual/collision tuning value, not from `atomicMass` — otherwise iron becomes so heavy it behaves like a wall and the pile stops flowing. Keep Box2D densities within roughly a 4× spread and let `relativeDensity` in the force term do the sorting work.

### Containment

- Chamber is a static `ChainShape` circle approximated with 64+ segments. A single large circle fixture will let fast-moving small bodies tunnel out.
- Inner radius: 320 world units.
- Enable bullet mode on injected hydrogen only. Everything else can be a normal body.

### Recommended starting values

| Parameter | Value | Notes |
|:----------|------:|:------|
| `gravityStrength` | 40.0 | Tune first; drives entire pacing |
| `referenceAtomicMass` | 4.0 | Helium |
| Restitution (all tiles) | 0.15 | Low — pile should settle, not bounce |
| Friction (all tiles) | 0.35 | Higher friction = more stable stacking |
| Linear damping | 0.4 | Prevents perpetual jitter in packed piles |
| Chamber radius | 320 | |
| Injection power range | 300–900 | Impulse magnitude (mapped to launch speed in code) |
| Injector cooldown | 400 ms | Rate limit; also the reload beat |

Tunables live in `lib/game/constants.dart`.

---

## 6. Input model

The injector is a visible element that orbits the outside of the rim.

- **Drag anywhere** — rotates the injector around the circumference. Angular position maps directly to drag angle relative to chamber center, so the injector tracks the thumb.
- **Hold** — charges power. Show a fill indicator on the injector itself, not a separate HUD bar.
- **Release** — fires along the inward radius at the charged power.

**Desktop dev controls** (not a ship surface — for playtesting on Linux/etc. while building):

- **A / D or ← / →** — rotate injector
- **Space** — hold to charge, release to fire
- **R / Enter / Space** — restart after containment loss

Power matters because it controls penetration depth. Low power drops hydrogen onto the surface of the pile near the rim. High power drives it through the loose outer material toward denser regions. This is the primary skill expression and it should be tuned so that both extremes are useful.

Portrait orientation. Chamber centered, injector orbiting, score above.

### Injection queue (Suika-style)

Not hydrogen-only forever. Show **NOW** and **NEXT** under the chamber. The injector chip also shows the loaded element.

| Rule | Detail |
|:--|:--|
| Start pool | `{H}` only |
| Unlock | When this run first creates an element, that tier joins the pool |
| Hard cap | Neon — never inject Mg / Si / … / Fe |
| Weights | H 10 · He 7 · C 4 · O 3 · Ne 2 — keeps helium contention central |
| Advance | On fire: shoot NOW, NOW ← NEXT, roll a new NEXT from the current pool |

Creating higher elements mid-run expands future rolls only; the already-queued NEXT is not rewritten.

---

## 7. Fail state

The run ends when any nucleus’s **rim pressure accumulator** reaches the limit.

Geometric rim test (not Box2D contacts): `distance + radius >= chamberRadius - epsilon`.

| Constant | Value | Role |
|:--|--:|:--|
| `kRimFillRate` | 1.0 /s | Pressure while touching |
| `kRimDrainRate` | 0.6 /s | Pressure while clear |
| `kRimPressureLimit` | 2.0 | Run ends |

Fill > drain so jittering contact still accumulates. Grazers rebound and drain. No at-rest velocity gate.

Board pressure is the max per-body pressure, exponentially smoothed into rim brightness (calm amber → critical orange, stroke + blur). Above ~0.75 pressure the rim pulses slowly (~2 Hz).

**Supernova shockwaves leave the accumulator running** — pinning fuel into the rim after a blast can end the run. That risk is intentional.

### Run endings

Same loss condition; card/cinematic branch on peak tier this run:

| Peak | Ending |
|:--|:--|
| Below iron | **White dwarf** — quiet vent, remnant point, understated card |
| Iron reached | **Supernova** — compress, flash, break rim, seed heavy elements (Au, Ag, …), card |

Skip allowed after 1.5 s. Physics stops for the cinematic; motion is animated directly. Last ending type is persisted.

---

## 8. Scoring

- Award the "score on create" value from the ladder table each time a tile is created by merging.
- Chain bonus: if a merge triggers a cascade, multiply subsequent merges in that chain by `1 + (0.5 × chainDepth)`.
- Mid-run iron supernova awards `kSupernovaScore` (500), independent of chain multiplier.
- Persist locally: high score, highest element reached, total runs, last ending type.
- Still designed, not yet persisted: per-element first-discovery timestamps (belongs with Codex).

Highest element reached is the more meaningful progression stat and should be the one surfaced most prominently. "You got to silicon" is a better brag than a number.

---

## 9. Codex

**Status: deferred** — keep the design, do not implement until after Milestone 1 playtests.

Opt-in only. A grid of eleven slots, locked and silhouetted until the player creates that element for the first time.

On unlock, each entry gets: symbol, name, atomic number, one short paragraph on where it actually forms in stars and one on where the player encounters it in daily life (neon in signs, calcium in bone, iron in blood).

**No tooltips, no tutorial popups, no "did you know" interruptions during play.** The codex is a room the curious can walk into. Everyone else finishes the game having absorbed the element order and never reads a word of it.

---

## 10. Build order

**Spike 1 — Radial sort** ✅ folded into Milestone 1  
Circular chain-shape container, radial gravity with density-scaled force. Load-bearing assumption: pile must visibly stratify. Revisit design if Box2D jams into a disordered lattice after tuning friction, damping, and `gravityStrength`.

**Spike 2 — Injection feel** ✅ folded into Milestone 1  
Orbiting injector, drag-to-aim, hold-to-charge, fire. Charge fill lives on the injector.

**Spike 3 — Merge system** ✅ folded into Milestone 1  
Contact listener, deferred merge resolution after `world.stepDt`, inert bump for non-merges.

**Milestone 1 — Playable loop** ✅ in codebase  
Full ladder, fail state, score, local high score, production-feel glow art (not “ugly spike art”). Owner self-tests first; later Play internal / TestFlight for other testers.

**Watch in playtests (do not skip):**

1. Does the pile stratify (heavy core / light rim)?
2. Is the helium rule obvious within ~30 seconds without tutorial text?
3. Are both low and high injection power useful?
4. Does rim pressure (jitter-tolerant accumulator) feel fair?
5. Does completing a second iron feel like a real risk near a hot rim?

**Shipped after Milestone 1:**

- Rim pressure accumulator + continuous glow
- Mid-run iron+iron supernova + shockwave
- White dwarf / supernova ending cinematics + cards

**Next (not started):**

- Audio pass (merge, fire, rim warning, supernova impact)
- Codex (§9)
- Localised rim heating (optional arc brightening)
- Physics/feel tuning (`kBlastImpulse` especially)
- Store listing assets; Codemagic + ASC delivery (keystore + Play API ready — §0c/§0d)
- Analytics only if explicitly requested

---

## 11. Open questions

- Do testers still use the helium route once same-tier fusion exists, or does C+C dominate?
- Is neon the right injection cap, or should the pool reach magnesium?
- Is eleven tiers the right run length on mobile? Suika sessions run 3–8 minutes; this should target the same.
- Does a run still stall out around the second iron (pressure / clog)?
- Does the pile need a settle-assist nudge to prevent permanent jams, or does damping handle it?
- Is `kBlastImpulse` high enough that crowded-rim supernovas can lose the run?
- When audio lands: how loud/present should rim-warning and supernova be?

---

## 12. Code map

| Area | Path |
|:--|:--|
| App entry / theme | `lib/main.dart`, `lib/theme/` |
| Game + input | `lib/game/bottled_star_game.dart` |
| Physics world | `lib/game/systems/bottled_star_world.dart` |
| Merge queue | `lib/game/systems/merge_system.dart` |
| Injection queue | `lib/game/systems/injection_queue.dart` |
| Ending cinematics | `lib/game/systems/ending_controller.dart` |
| Scores | `lib/game/systems/score_store.dart` |
| Chamber / nuclei / injector | `lib/game/components/` |
| Ladder + merge rules | `lib/game/element_tier.dart` |
| Tunables | `lib/game/constants.dart` |
| Type system | `lib/theme/game_fonts.dart` + `assets/fonts/` |
| HUD / endings | `lib/ui/game_screen.dart` |
| Design source of truth | this file |
