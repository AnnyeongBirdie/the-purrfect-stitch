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

Scene-to-scene communication is a plain property set on the destination before `presentScene()`. There is no shared coordinator or persistent storage across launches.

Side-scenes (DressingRoomScene, RiddleScene, SettingsScene) all set `scene.suppressEntryBell = true` before presenting FrontShopScene on return, so the shop bell only plays on genuine entries (app launch, back-room completion), not on return from navigation.

### Three functional spaces + POV map

The tailor shop has three functional spaces, each with a deliberate POV. The shop **front** is customer POV — the player picks a customer in settings and that customer pays for and receives orders. The **back room** (workshop) is tailor POV — the player watches the tailor work and sees both the customer's deposit reference (💰 냥) and the tailor's growth tracker (🐾 마력) in the HUD. The **basement** is the four dungeons (fabric cabinet, sewing, buttons, mannequin boss); plus Phase 5's `WizardAssistant_Dungeon`, `Wizard_Chamber`, and `PrincessAna_Room` scenes. All basement scenes are tailor POV.

| Space | Scenes | POV |
|---|---|---|
| Shop front | `FrontShopScene`, `SettingsScene`, `RiddleScene`, `DressingRoomScene` | Customer (player) |
| Back room | `BackRoomScene` | Tailor |
| Basement (dungeons) | `MinigameNode`, `BossMinigameNode`, and Phase 5: `TailorChoiceScene`, `AuroraChamberScene`, `PrincessAnaScene` | Tailor |

### State machines

**FrontShopScene** uses the `FrontShopState` enum (in `Model/`):
`greeting → choosingClothing → choosingFabricColor → reviewingOrder → awaitingPayment → sendingOrder`
Plus `showingFinishedGarment` — entered on return from the back room with a completed garment; all nav icons are blocked and dimmed in this state until the trophy is saved to the wardrobe.

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
| `Order` (struct) | `clothingType: ClothingType`, `depositAmount: Int`, `fabricColor: FabricColor` |
| `ClothingType` / `FabricColor` (enums) | `String`-raw, `Codable`, `CaseIterable`; live in `Order.swift`. Korean raw values, kept identical to the old `String` model so `Codable` persistence stays byte-compatible. Helpers: `displayName`, `assetFragment` / `assetSuffix`, and `FabricColor.palette`. |
| `FrontShopState` (enum) | seven cases, drives UI in FrontShopScene. `ShopInput` + `FrontShopState.accepts(_:)` — a single exhaustive `switch self` — gate which buttons each state accepts. |
| `MinigameStation` family | `MinigameStation` enum (4 cases) + `MinigameConfig` struct + helper enums (`EnemyKind`, `DefeatMechanism`, `MonsterBehavior`, `HazardKind`). Drives stations 1–3; the boss does not flow through `MinigameConfig`. |
| `Wallet` (singleton) | `balance: Int` — **customer-side** 냥. 0 on a fresh install and on every 새 손님 reset. Persisted via `Store.loadWalletBalance` / `saveWalletBalance`. |
| `Magic` (singleton) | `points: Int` — **tailor-side** 마력 (cat wizarding XP, 🐾). Monotonically grows via `add(_:)`. Persists across 새 손님; tied to the tailor's wizard-apprentice growth arc and v2 expansion. |
| `Riddle` (struct, Codable) | `question`, `choices[4]`, `answer`, `reward` (default 15냥). `RiddleBank.load()` tries `Documents/riddles.json` first (parent-editable), falls back to 15 hardcoded defaults. |
| `SoundManager` (singleton) | `isMuted: Bool` (UserDefaults), `play(_ filename: String)`, `stop(_ filename: String)`, `stopAll()`. Backed by an `AVAudioPlayer` pool keyed by filename — multiple concurrent plays of the same cue are pooled, and `stop(_:)` cancels every in-flight copy. All SFX route through this — silent no-op when muted; `toggleMute()` also calls `stopAll()`. |
| `ProfileManager` (singleton) | `selectedIndex: Int` (UserDefaults), 11 cat avatars in `avatars` array with asset name + Korean display name. `advance()` / `retreat()` cycle selection. |

`currentOrder: Order?` is an instance var on `FrontShopScene`. Currency state: `Wallet.shared.balance` (customer 냥) and `Magic.shared.points` (tailor 마력) — both singletons, read directly from any scene, no property handoff needed.

### Known gaps / in-progress state

- `FrontShopScene` uses `GameScene.sks` for its node layout (background, shopkeeper, mannequin). `BackRoomScene` builds everything in code. A conversion to fully programmatic was considered alongside the layout fixes following the wardrobe + persistence ship at commit `2be2344`, but deferred — the regression risk wasn't worth the consistency win while that work was still settling. Revisit when another structural change is already on the table.
- *(Resolved)* `Order.clothingType` / `Order.fabricColor` are now the `ClothingType` / `FabricColor` enums, and `FrontShopScene`'s `if currentState == .case` guards now route through the exhaustive `FrontShopState.accepts(_:)` switch — restoring compile-time exhaustiveness. The stringly-typed switches in `GarmentNaming`, `BackRoomScene` (halo shades), and `DressingRoomScene` were converted to the enums in the same pass.

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

Effectively shipped — a full sound pass across every scene, and the **v1 release gate**.

All 28 SFX are sourced and bundled in `DesignerAna/SoundEffects/`. **23 are wired in code**; the remaining 5 sit on disk for revival — 2 retired (`sfx_wardrobe_sparkle`, `sfx_wardrobe_open` — the dress nav icon now uses the standard `sfx_button_tap` and the firefly badge was removed), and 3 un-wired pending review (`sfx_dungeon_fanfare`, `sfx_land`, `sfx_tailor_walk` — each felt repetitive or unnecessary in owner playtests). Per-SFX status, source filenames, and re-wire hints all live in `SOUND_INVENTORY.md` (git-tracked, at the repo root).

`SoundManager` was refactored mid-Phase-4 from `SKAction.playSoundFileNamed` to an `AVAudioPlayer` pool with a `stop(_:)` API. This was needed because the original SKAction-based approach could not cancel in-flight audio — long cues (footstep loops, boss attack telegraphs) were bleeding into the next scene when the SKAction sequence ended but the audio file kept playing. Boss-attack telegraphs now stop on defeat / hero death / reset via `stopBossAttackSFX()` in `BossMinigameNode`.

### Phase 5 — Relics Quest (planned, designed)

The next major feature — a meta-quest layered onto the existing dungeon loop. Across the four dungeons the tailor collects four of Princess Estelle's relics: Purple Scepter (fabric cabinet) → Paint Brushes (sewing) → Palette (buttons) → Royal Family Portrait (boss). The mapping is canonical per the storybook restructure (commit `6de95f9`); Estelle's purple color signature drives the relic glow tint.

**Mechanic.** Designer-placed walk-over pickups, one per level, with 1냥 breadcrumb-coin trails leading the player to each relic so beelining doesn't lose it. Chest 냥 rewards drop proportionally so per-level totals stay at 10 / 20 / 30 / 50. Safety net: if the player opens the chest without collecting the relic, it auto-pulls to the hero with the standard pickup animation. Picked-up relics fly to a new HUD icon row left of the 냥 counter.

**Narrative payoff.** After the 4th relic, a cinematic `TailorChoiceScene` triggers (backdrop `WizardAssistant_Dungeon.png`, the four relics circled around the tailor). A/B branch: Option A opens `AuroraChamberScene` — the tailor's former wizard mentor, an odd-eyed white cat using the existing `WizardCat` avatar art, who gates her advice on a `RiddleBank` riddle before magically teleporting the tailor to the palace. Option B skips Aurora. Both paths converge at `PrincessAnaScene` (backdrop `PrincessAna_Room.png`), where Ana receives the relics one by one, the portrait reveal summons her fairy godmother (existing `GodmotherCat` avatar art), and the godmother delivers the curse story behind the dust + yarn monsters — including the framing that defeated monsters *fall asleep, not killed*, and return when they wake. That framing aligns with the existing respawn behaviour and preserves the gameplay loop after the quest completes.

**Working spec.** `RELICS.md` at the repo root (gitignored — owner-local). All decided directions and remaining open questions live there. Five cross-cutting opens still need resolving before code: breadcrumb count (uniform vs scaled), Tailor's Choice revisit mechanism, Aurora's riddle source (random vs pinned), post-quest HUD persistence, and NPC sprite overlap with `ProfileManager` avatars.

**Scope estimate.** ~600–900 lines across a new `DungeonItem` enum in `Model/`, `Store` extensions for `loadCollectedRelics()` / `saveCollectedRelics(_:)`, relic + breadcrumb spawn / collection in `MinigameNode` and `BossMinigameNode`, the HUD icon row in `BackRoomScene`, three new scene classes, and the trigger plumbing from the boss outro into the Tailor's Choice scene. Backdrops staged in `_RawAssets/SpriteArt/`.

### Currency & economy

Two separate currencies with distinct economic shapes:

- **Customer's 냥 (`Wallet.shared.balance`)** — circular economy. Starts at 0냥 on a fresh install or 새 손님 reset. Depleted by front-shop deposits; replenished by dungeon chest refunds (크만할래 path) and shopkeeper riddle rewards. The wardrobe is the stamp-collection win condition. A brand-new customer starts broke and earns their way in.
- **Tailor's 마력 (`Magic.shared.points`, 🐾)** — expansive economy. Monotonically grows from dungeon chest rewards (wiring lands in Economy refactor #2). Never decreases: the tailor "learns from her mistakes" — 그만할래 retains earned 마력 while refunding the customer's deposit. Tied to the tailor's wizard-apprentice growth arc and v2 Aurora mentorship dialogue.

**새 손님 reset** (UI in Settings, wired in Economy refactor #2): calls `Store.resetCustomerSide()`, which zeroes `Wallet`, empties the wardrobe, clears badge counters, clears the active order, and clears the `customer.selected` sticky flag. Tailor-side state — `Magic.shared.points`, future relics, dungeon progress, and the global storybook — is untouched.

**Persistence schema:** flat `UserDefaults` keys; no per-customer namespacing. Only one customer is "alive" at a time, identified by `customer.selected` (holds the avatar asset-name string, e.g. `"ChefCat"`). The shopkeeper riddle still credits `Wallet.shared.balance` — it's shopkeeper-driven, customer-side.

**Minigame rewards (current):** 10 / 20 / 30 / 50 냥 awarded on chest open at cabinet / sewing / buttons / boss. These still flow to `Wallet` until Economy refactor #2 reroutes them to `Magic`.

### V2 expansion ideas (post-roadmap)

Captured here so they're not lost; not planned for current phases.

- **Adaptive difficulty easing for station minigames.** Track death count per minigame attempt and reduce hazard density after N deaths (fewer chasms, slower monsters, longer safe gaps in button rain) so kids don't get stuck. Auto-reset to default difficulty on success. The 냥 reward should not scale down with eased difficulty — the easing exists to keep play sessions positive, not to discourage skill development.

- **Guardian reframe for the mannequin level (visual seed already in place).** The boss-on-chest reveal animation that plays on boss defeat in `BossMinigameNode` was deliberately planted as a seed for a future "guardian" iteration of the same level: replace the fight with a puzzle where the player lures a giant dust monster off the chest into a trap, rather than damaging it. Educational angle — observation and planning over reflexes. The visual continuity (boss-on-chest at defeat) makes the reframe feel like a deepening of the same level rather than a contradiction.

## Closing handoff procedure

At session end, when updating `DesignerAna_handoff.md` (the "closing handoff"), **stamp the date by running `bash date` and using that value** — do not infer the date from file timestamps, previous handoffs, or memory. The handoff date must reflect the session it documents. We made this mistake once (handoff dated May 29 for work done June 2), which caused confusion at the next session's start.

If a closing handoff doesn't happen (the owner closes the laptop unexpectedly), the owner has committed to returning to the same Cowork session next time rather than opening a new one — so the absence of a closing handoff unambiguously defines the session's status. A fresh session is the signal that a proper closing handoff was written; a resumed session is the signal that it wasn't.
