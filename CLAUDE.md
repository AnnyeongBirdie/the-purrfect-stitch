# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Open `DesignerAna.xcodeproj` in Xcode and run on an iOS Simulator or device. There is no test target and no linting setup.

From the command line:
```bash
# Build for simulator
xcodebuild -project DesignerAna.xcodeproj -scheme DesignerAna \
  -destination 'platform=iOS Simulator,name=iPhone 16e' build

# Clean build
xcodebuild -project DesignerAna.xcodeproj -scheme DesignerAna clean
```

- Swift 5.0, iOS 26.2 deployment target, supports iPhone + iPad
- No CocoaPods, SPM packages, or external dependencies
- Installed simulators on this machine: **iPhone 16e** (preferred default) and iPhone 17. iPhone 16 is *not* installed — do not target it.

## Architecture

This is an iOS SpriteKit game — a Korean-language tailor-shop simulation. The player takes a clothing order in the front shop, pays a deposit, then crafts the garment in the back room and returns it to the customer.

### Scene flow

```
GameViewController
  └─ FrontShopScene (loaded from GameScene.sks)
       │  ⚙ nav  → crossFade → SettingsScene  → crossFade → FrontShopScene
       │  💰 nav  → crossFade → RiddleScene    → crossFade → FrontShopScene
       │  👗 nav  → crossFade → DressingRoomScene → crossFade → FrontShopScene
       │  pays deposit → fade transition
       └─ BackRoomScene (built programmatically)
            │  dress placed on mannequin → crossFade transition
            └─ FrontShopScene (reloaded from GameScene.sks)
                 with shouldShowFinishedGarment = true
```

Scene-to-scene communication is a plain property set on the destination before `presentScene()`. Currency state lives in a `Wallet.shared` singleton, read directly from both scenes. There is no shared coordinator or persistent storage across launches.

Side-scenes (DressingRoomScene, RiddleScene, SettingsScene) all set `scene.suppressEntryBell = true` before presenting FrontShopScene on return, so the shop bell only plays on genuine entries (app launch, back-room completion), not on return from navigation.

### State machines

**FrontShopScene** uses the `FrontShopState` enum (in `Model/`):
`greeting → choosingClothing → choosingFabricColor → reviewingOrder → awaitingPayment → sendingOrder`

**BackRoomScene** uses a private nested `BackRoomState` enum with this linear progression:
`waitingForCabinetTap → walkingToCabinet → waitingForSewing → walkingToSewing → waitingForButtons → walkingToButtons → waitingForMannequin → walkingToMannequin → finalCheck → completed`

The fabric cabinet, sewing station, and button station each gate on a platformer minigame (`MinigameNode` + `MinigameConfig`) — the tap walks the tailor over, then `presentMinigame` hands control to a station-specific config; the minigame's completion callback advances the state. The mannequin station uses `BossMinigameNode` (a sibling to `MinigameNode`, not routed through `MinigameConfig`) — on boss defeat the state advances to `.finalCheck`, the brief beat between the chest opening and the dress appearing on the mannequin, before the scene transitions back to the front shop.

### Tailor halo

A vertical pill-shaped halo behind the tailor sprite in `BackRoomScene` provides ambient visual feedback. Its color tracks `order?.fabricColor` and **deepens in shade with each station cleared** (light after fabric → medium after sewing → dark after buttons), pulsing via alpha breathing throughout. At completion, the pulse stops and the halo expands to fill the screen before the scene transitions back to the front shop. The three shades per color are hand-tuned `UIColor` values centralized as `haloLight` / `haloMedium` / `haloDark` computed properties.

### Sprite PNG transparent-padding rule

All character PNGs have transparent space at the bottom of their bounding box — the illustrated feet do not extend to the sprite's mathematical bottom edge. When placing any character sprite on a floor or platform, always compensate:

```
node.position.y = surfaceTop + (halfHeight - padding)
```

**Per-character padding values (verified on device):**
| Sprite | Size | halfHeight | Padding | Position offset |
|--------|------|-----------|---------|----------------|
| Monster | 60×90 | 45 | 20 pt | surfaceTop + 25 |
| Boss | 130×195 | 97 | 30 pt | surfaceTop + 67 |
| BossAdd | 56×58 | 29 | 20 pt | surfaceTop + 9 |

Without this offset the character will appear to float above the surface. **This rule applies every time a character is positioned on a floor or platform — in both Cowork sessions and Claude Code sessions.**

### zPosition convention

Characters and props live in zPosition 0–15 (e.g., the tailor sprite is at 10, its halo at 8). Reserve **zPosition 50+** for back-room overlays — minigame scenes, dialogs, and modal UI introduced in Phase 3. This keeps gameplay layers cleanly separable from interactive overlays.

### Minigame hero movement & collision (kinematic)

In both `MinigameNode` and `BossMinigameNode` the hero's vertical movement is **fully kinematic** — her physics body has `affectedByGravity = false` and `collisionBitMask = none`, and `update()` integrates a hand-rolled `heroVelY` each frame (gravity, jump launch, one-way platform landing, floor). The physics engine never moves the hero. Horizontal movement is likewise a manual `position.x` step.

Because a kinematically-positioned body does not reliably trigger SpriteKit's contact delegate, **all gameplay collisions are manual AABB overlap checks in `update()`** — monster and boss stomps, hazards (scissor blades, falling buttons, the boss sweep projectile), and summon adds. `didBegin(_:)` is retained but effectively vestigial. Stomp vs. hit is decided by whether the hero is descending (`heroVelY < threshold`).

Jump feel is controlled by three constants at the top of each minigame file: `jumpPeakFraction`, `timeToApex`, `descentMultiplier`. The boss's vulnerable / telegraph / hit states are shown with a `bossAura` halo node (an SKShapeNode behind the emoji), not by colourising the sprite.

### Model layer

`Model/` has seven files; scene-specific state still lives inside each scene class.

| Type | Key fields |
|---|---|
| `Order` (struct) | `clothingType: String`, `depositAmount: Int`, `fabricColor: String` |
| `FrontShopState` (enum) | six cases, drives UI in FrontShopScene |
| `MinigameStation` family | `MinigameStation` enum (4 cases) + `MinigameConfig` struct + helper enums (`EnemyKind`, `DefeatMechanism`, `MonsterBehavior`, `HazardKind`). Drives stations 1–3; the boss does not flow through `MinigameConfig`. |
| `Wallet` (singleton) | `balance: Int` (starts at 200냥, not persisted across launches) |
| `Riddle` (struct, Codable) | `question`, `choices[4]`, `answer`, `reward` (default 15냥). `RiddleBank.load()` tries `Documents/riddles.json` first (parent-editable), falls back to 15 hardcoded defaults. |
| `SoundManager` (singleton) | `isMuted: Bool` (UserDefaults), `play(_ filename: String, on: SKNode)`. All SFX route through this — silent no-op when muted. |
| `ProfileManager` (singleton) | `selectedIndex: Int` (UserDefaults), 11 cat avatars in `avatars` array with asset name + Korean display name. `advance()` / `retreat()` cycle selection. |

`currentOrder: Order?` is an instance var on `FrontShopScene`. Currency state is `Wallet.shared.balance` — same value read from both scenes, no property handoff needed.

### Known gaps / in-progress state

- `FrontShopScene` uses `GameScene.sks` for its node layout (background, shopkeeper, mannequin). `BackRoomScene` builds everything in code. A conversion to fully programmatic was considered alongside the layout fixes following the wardrobe + persistence ship at commit `2be2344`, but deferred — the regression risk wasn't worth the consistency win while that work was still settling. Revisit when another structural change is already on the table.
- State checks in `FrontShopScene` use `if currentState == .case` guards instead of exhaustive switches; this loses Swift's compile-time exhaustiveness check.
- `Order.fabricColor` and `Order.clothingType` are typed as `String` rather than enum. Couples with the if-guards concern; both will likely be refactored together.

## Roadmap

### Phase 1 — Initial prototype (shipped)
Fixed pink-dress flow. Fabric and button choices in the back room were hardcoded; the `Order` from the front shop was not forwarded. Cleanup work removed the dead `readyForTransition` enum case and the visible debug overlays on back-room zones.

### Phase 2 — Game loop expansion (shipped)

The NPC shopkeeper guides the player through three ordering steps in sequence:
1. Pick clothing type (dress, shirt, pants)
2. Pick fabric color (pink, blue, yellow)
3. Pay deposit

`Order` carries `clothingType: String`, `fabricColor: String`, and `depositAmount: Int`. The back room uses `clothingType` and `fabricColor` to produce the correct finished garment and to theme all four minigames.

- **Phase 2a — Fabric color (shipped):** Front shop asks for fabric color after clothing pick (`choosingFabricColor` state). `Order` carries `fabricColor: String`, forwarded to `BackRoomScene` via the `order` property. Used for minigame theming, halo color, and the finished-garment image name.
- **Phase 2b — Clothing type (shipped):** Front shop asks for clothing type, `Order` carries it, back room produces the matching garment.
- **Phase 2c — Button type (cancelled):** Dropped — button type choice doesn't add meaningful player agency at this stage of the game.

### Phase 3 — Station minigames
Each station (fabric cabinet, sewing station, button station, mannequin) gates progress with a Super Mario–style platformer minigame. The player navigates a small dungeon, defeats a monster, and reaches a treasure chest containing the needed item (fabric, thread, buttons, finished dress) before that station unlocks.

**Shipped:** fabric cabinet (station 1, tutorial — stationary monster, no hazards), sewing station (station 2 — pacing monster, scissor-blade hazards to jump over), button station (station 3 — lunging monster, falling-button hazards from the ceiling), mannequin station (station 4 — boss fight via `BossMinigameNode`; three telegraphed attacks, 3 HP, boss-on-chest reveal). All station-specific behavior for stations 1–3 lives in `MinigameConfig` (level seed, `MonsterBehavior`, `HazardKind`, theming); shared mechanics live in `MinigameNode`. The mannequin boss uses a sibling `BossMinigameNode` with its own bespoke attack loop.

### Phase 4 — Audio pass

In progress. A full sound pass across every scene, and a **v1 release gate** — v1 ships with working sound. The `SoundManager` singleton and the settings mute toggle already shipped (commit `b256239`), so Phase 4 is purely content sourcing and wiring, with no new infrastructure.

The game needs 28 sound effects in total. The five front-shop UI/ambient SFX are sourced and bundled in `DesignerAna/SoundEffects/`; the remaining 23 — back room, minigame movement, minigame combat, boss fight, and wardrobe — are not yet sourced. Sourcing royalty-free MP3s is the current blocker and is owner-driven. Per-SFX sourced-vs-wired status is tracked in `SOUND_INVENTORY.md` (git-tracked, at the repo root).

Wiring lags sourcing. `RiddleScene` and `DressingRoomScene` do not yet play button taps even though `sfx_button_tap` is available; rather than wire that one gap on its own, each scene is wired completely — button taps plus its own SFX — once its full sound set is sourced. This absorbs what was previously tracked as a standalone "sound-wiring gap" cleanup item.

### Currency & economy

- **Wallet:** `Wallet.shared.balance: Int`, starting at 200냥 per launch (not persisted), depleted by deposits in the front shop. Read directly from both scenes — no property handoff between scenes.
- **Earning paths:**
  - **Minigame rewards (shipped):** 10 / 20 / 30 / 50 냥 awarded on chest open at cabinet / sewing / buttons / boss respectively. Shown as a gold pop-up rising from the chest; tracked in the back-room wallet HUD.
  - **Riddle fallback (later):** when the wallet runs low, the NPC shopkeeper offers simple math or trivia questions and awards 냥 for correct answers. Question content sourced from external curriculum, TBD.
- **Design constraint:** wallet, deposits, minigame rewards, and riddle rewards share a single currency system (`Wallet.shared`) — no duplicated transaction logic across scenes.
- **Not yet persisted:** the wallet resets to 200냥 on every launch. Persistence (likely UserDefaults + Codable) will be bundled with the wardrobe persistence work.

### V2 expansion ideas (post-roadmap)

Captured here so they're not lost; not planned for current phases.

- **Adaptive difficulty easing for station minigames.** Track death count per minigame attempt and reduce hazard density after N deaths (fewer chasms, slower monsters, longer safe gaps in button rain) so kids don't get stuck. Auto-reset to default difficulty on success. The 냥 reward should not scale down with eased difficulty — the easing exists to keep play sessions positive, not to discourage skill development.

- **Guardian reframe for the mannequin level (visual seed already in place).** The boss-on-chest reveal animation that plays on boss defeat in `BossMinigameNode` was deliberately planted as a seed for a future "guardian" iteration of the same level: replace the fight with a puzzle where the player lures a giant dust monster off the chest into a trap, rather than damaging it. Educational angle — observation and planning over reflexes. The visual continuity (boss-on-chest at defeat) makes the reframe feel like a deepening of the same level rather than a contradiction.
