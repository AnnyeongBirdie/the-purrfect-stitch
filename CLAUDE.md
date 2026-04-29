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

`readyForTransition` is defined in the enum but is never assigned anywhere.

**BackRoomScene** uses a private nested `BackRoomState` enum with this linear progression:
`waitingForCabinetTap → walkingToCabinet → choosingFabric → waitingForSewing → walkingToSewing → sewing → waitingForButtons → walkingToButtons → addingButtons → waitingForMannequin → walkingToMannequin → completed`

### Model layer

`Model/` has two files and is otherwise thin — all scene-specific state lives inside each scene class:

| Type | Key fields |
|---|---|
| `Order` (struct) | `clothingType: String`, `depositAmount: Int` |
| `FrontShopState` (enum) | six cases, drives UI in FrontShopScene |

`playerMoney: Int` (starts at 200냥) and `currentOrder: Order?` are instance vars on `FrontShopScene`, not persisted across launches.

### Known gaps / in-progress state

- The `Order` chosen in `FrontShopScene` is **never forwarded to `BackRoomScene`** — the back room always crafts a pink dress regardless of what was ordered.
- Fabric selection in the back room only advances on `pinkFabric`; blue and yellow display a retry message.
- `BackRoomScene` has visible debug overlays (colored semi-transparent boxes) on the sewing station, button station, and mannequin zone — these are `fillColor`/`strokeColor` set directly in `setupSewingStationZone()`, `setupButtonZone()`, and `setupMannequinZone()`.
- `FrontShopScene` uses `GameScene.sks` for its node layout (background, shopkeeper, mannequin). `BackRoomScene` builds everything in code.
