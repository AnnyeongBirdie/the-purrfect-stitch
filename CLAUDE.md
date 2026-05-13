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
       │  pays deposit → fade transition
       └─ BackRoomScene (built programmatically)
            │  dress placed on mannequin → crossFade transition
            └─ FrontShopScene (reloaded from GameScene.sks)
                 with shouldShowFinishedDress = true
```

Scene-to-scene communication is a plain property set on the destination before `presentScene()`. There is no shared coordinator, singleton, or persistent storage.

### State machines

**FrontShopScene** uses the `FrontShopState` enum (in `Model/`):
`greeting → choosingClothing → choosingFabricColor → reviewingOrder → awaitingPayment → sendingOrder`

**BackRoomScene** uses a private nested `BackRoomState` enum with this linear progression:
`waitingForCabinetTap → walkingToCabinet → waitingForSewing → walkingToSewing → waitingForButtons → walkingToButtons → waitingForMannequin → walkingToMannequin → finalCheck → completed`

The fabric cabinet, sewing station, and button station each gate on a platformer minigame (`MinigameNode` + `MinigameConfig`) — the tap walks the tailor over, then `presentMinigame` hands control to a station-specific config; the minigame's completion callback advances the state. The mannequin station uses `BossMinigameNode` (a sibling to `MinigameNode`, not routed through `MinigameConfig`) — on boss defeat the state advances to `.finalCheck`, the brief beat between the chest opening and the dress appearing on the mannequin, before the scene transitions back to the front shop.

### Tailor halo

A vertical pill-shaped halo behind the tailor sprite in `BackRoomScene` provides ambient visual feedback. Its color tracks `order?.fabricColor` and **deepens in shade with each station cleared** (light after fabric → medium after sewing → dark after buttons), pulsing via alpha breathing throughout. At completion, the pulse stops and the halo expands to fill the screen before the scene transitions back to the front shop. The three shades per color are hand-tuned `UIColor` values centralized as `haloLight` / `haloMedium` / `haloDark` computed properties.

### zPosition convention

Characters and props live in zPosition 0–15 (e.g., the tailor sprite is at 10, its halo at 8). Reserve **zPosition 50+** for back-room overlays — minigame scenes, dialogs, and modal UI introduced in Phase 3. This keeps gameplay layers cleanly separable from interactive overlays.

### Model layer

`Model/` has two files and is otherwise thin — all scene-specific state lives inside each scene class:

| Type | Key fields |
|---|---|
| `Order` (struct) | `clothingType: String`, `depositAmount: Int`, `fabricColor: String` |
| `FrontShopState` (enum) | five cases, drives UI in FrontShopScene |

`playerMoney: Int` (starts at 200냥) and `currentOrder: Order?` are instance vars on `FrontShopScene`, not persisted across launches.

### Known gaps / in-progress state

- `FrontShopScene` uses `GameScene.sks` for its node layout (background, shopkeeper, mannequin). `BackRoomScene` builds everything in code.
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

### Currency & economy — active work

- **Wallet:** `playerMoney: Int` on `FrontShopScene`, starting at 200냥, depleted by deposits. Already implemented.
- **Earning paths:**
  - **Minigame rewards (next):** award 냥 on completing each station minigame. The reward amount and display are TBD; see design notes below.
  - **Riddle fallback (later):** when the wallet runs low, the NPC shopkeeper offers simple math or trivia questions and awards 냥 for correct answers. Question content sourced from external curriculum, TBD.
- **Design constraint:** wallet, deposits, minigame rewards, and riddle rewards must share a single currency system — no duplicated transaction logic across scenes. `playerMoney` lives on `FrontShopScene`; the back room receives it via a property set before `presentScene()`, the same pattern used for `order`.

### V2 expansion ideas (post-roadmap)

Captured here so they're not lost; not planned for current phases.

- **Adaptive difficulty easing for station minigames.** Track death count per minigame attempt and reduce hazard density after N deaths (fewer chasms, slower monsters, longer safe gaps in button rain) so kids don't get stuck. Auto-reset to default difficulty on success. The 냥 reward should not scale down with eased difficulty — the easing exists to keep play sessions positive, not to discourage skill development.
