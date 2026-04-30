# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Open `DesignerAna.xcodeproj` in Xcode and run on an iOS Simulator or device. There is no test target and no linting setup.

From the command line:
```bash
# Build for simulator
xcodebuild -project DesignerAna.xcodeproj -scheme DesignerAna \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Clean build
xcodebuild -project DesignerAna.xcodeproj -scheme DesignerAna clean
```

- Swift 5.0, iOS 26.2 deployment target, supports iPhone + iPad
- No CocoaPods, SPM packages, or external dependencies

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
`greeting → choosingClothing → reviewingOrder → awaitingPayment → sendingOrder`

**BackRoomScene** uses a private nested `BackRoomState` enum with this linear progression:
`waitingForCabinetTap → walkingToCabinet → choosingFabric → waitingForSewing → walkingToSewing → sewing → waitingForButtons → walkingToButtons → addingButtons → waitingForMannequin → walkingToMannequin → completed`

### Model layer

`Model/` has two files and is otherwise thin — all scene-specific state lives inside each scene class:

| Type | Key fields |
|---|---|
| `Order` (struct) | `clothingType: String`, `depositAmount: Int` |
| `FrontShopState` (enum) | five cases, drives UI in FrontShopScene |

`playerMoney: Int` (starts at 200냥) and `currentOrder: Order?` are instance vars on `FrontShopScene`, not persisted across launches.

### Known gaps / in-progress state

- The `Order` chosen in `FrontShopScene` is **never forwarded to `BackRoomScene`** — the back room always crafts a pink dress regardless of what was ordered.
- Fabric selection in the back room only advances on `pinkFabric`; blue and yellow display a retry message.
- `BackRoomScene` has visible debug overlays (colored semi-transparent boxes) on the sewing station, button station, and mannequin zone — these are `fillColor`/`strokeColor` set directly in `setupSewingStationZone()`, `setupButtonZone()`, and `setupMannequinZone()`.
- `FrontShopScene` uses `GameScene.sks` for its node layout (background, shopkeeper, mannequin). `BackRoomScene` builds everything in code.

## Roadmap

### Phase 1 — Current prototype
Fixed pink-dress flow. Fabric and button choices in the back room are hardcoded; the `Order` from the front shop is never forwarded.

### Phase 2 — Game loop expansion
- Pass `Order` from `FrontShopScene` into `BackRoomScene` via the existing property-set pattern.
- Support multiple clothing types (dress, shirt, pants) and fabric colors (pink, blue, yellow).
- Fabric and button selections in the back room must match what the customer ordered.

### Phase 3 — Station minigames
Each station (fabric cabinet, sewing station, button station, mannequin) gates progress with a Super Mario–style platformer minigame. The player navigates a small dungeon, defeats a monster, and reaches a treasure chest containing the needed item (fabric, thread, buttons, finished dress) before that station unlocks.

### Currency & economy (cross-cutting)
- **Wallet:** `playerMoney: Int` on `FrontShopScene`, starting at 200냥, depleted by deposits. Already implemented.
- **Earning paths to add:**
  - Bonus 냥 for completing each station minigame (Phase 3).
  - Riddle fallback: when the wallet runs low at the front shop, the NPC shopkeeper offers simple math or trivia questions (sourced from external curriculum content, TBD) and awards 냥 for correct answers.
- **Design constraint:** wallet, deposits, minigame rewards, and riddle rewards must share a single currency system — no duplicated transaction logic across scenes.
