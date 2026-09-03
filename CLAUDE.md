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

### Signing & bundle identity

- **Bundle ID:** `com.annyeongbirdie.thepurrfectstitch` (set June 2026, renamed from the earlier `com.JustRunItLab.DesignerAna` to consolidate under the owner's **AnnyeongBirdie** branding — matching the GitHub repo `the-purrfect-stitch`, GitHub profile, and velog blog). `JustRunItLab` was an abandoned working name used nowhere else.
- **Signing:** Automatic. As of June 2026 the project signs under the owner's **paid Apple Developer Program** team (enrolled to lift the free Personal Team's 7-day provisioning-profile expiry — dev profiles now last ~1 year). Switching teams in Xcode rewrites `DEVELOPMENT_TEAM` in `project.pbxproj`; the old Personal Team ID was `VQ4643X8XU`.
- **No project rename.** The Xcode project, scheme, and source folder remain `DesignerAna` — only the bundle ID changed. A full rename to match the repo is deliberately deferred (high regression risk; revisit only during dedicated structural work). Expect a naming split: project `DesignerAna`, repo `the-purrfect-stitch`, bundle `com.annyeongbirdie.thepurrfectstitch`, display name 묘한 옷 공방.
- **No Apple secrets in the repo.** Certificates/keys live in the Mac Keychain; provisioning profiles live on Apple's servers. The repo holds no credentials to rotate. Never commit `.p12`, `.cer`, `.mobileprovision`, or a secrets-bearing `ExportOptions.plist`.
- Changing the bundle ID resets `UserDefaults` (it's namespaced by bundle ID), so test devices lose saved wardrobe/progress on the next install — expected and harmless for test builds.

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

`GameViewController` checks `Store.loadSelectedCustomer()` at launch: if `nil` (first launch or post-새 손님 reset), it presents `SettingsScene` in `isFirstLaunchPicker = true` mode; otherwise it loads `FrontShopScene` directly.

Side-scenes (DressingRoomScene, RiddleScene, SettingsScene) all set `scene.suppressEntryBell = true` before presenting FrontShopScene on return, so the shop bell only plays on genuine entries (app launch, back-room completion, first-launch picker start), not on return from navigation.

### Three functional spaces + POV map

The tailor shop has three functional spaces, each with a deliberate POV. The shop **front** is customer POV — the player picks a customer in settings and that customer pays for and receives orders. The **back room** (workshop) is tailor POV — the player watches the tailor work and sees both the customer's deposit reference (💰 냥) and the tailor's growth tracker (🐾 마력) in the HUD. The **basement** is the four dungeons (fabric cabinet, sewing, buttons, mannequin boss); plus Phase 5's `TailorChoiceScene`, `AuroraChamberScene`, `PrincessAnaScene`, and `DaphneBecomesTailorScene` scenes. All basement scenes are tailor POV.

| Space | Scenes | POV |
|---|---|---|
| Shop front | `FrontShopScene`, `SettingsScene`, `RiddleScene`, `DressingRoomScene` | Customer (player) |
| Back room | `BackRoomScene` (HUD column top-to-bottom: 💰 냥, then 그만할래 quit button, then 🐾 마력 at the bottom — do not place anything between 💰 and 그만할래, or between 그만할래 and 🐾) | Tailor |
| Basement (dungeons) | `MinigameNode`, `BossMinigameNode`, and Phase 5: `TailorChoiceScene`, `AuroraChamberScene`, `PrincessAnaScene` | Tailor |

### Back room HUD layout convention

The back room HUD is split by ownership: **tailor-side elements anchor to the top-left; customer-side elements anchor to the top-right.** This design language must be preserved for all future HUD additions.

| Side | Elements | Position |
|---|---|---|
| Top-left (tailor) | 🐾 마력 counter, relic slot row | `size.width * -0.36`, upper portion |
| Top-right (customer) | 💰 냥 counter | `size.width * 0.36`, upper portion |
| Center | 그만할래 quit button | `size.width * 0.36` x, between the two counters |

New back-room UI that belongs to the tailor (dungeon progress, quest state, keepsakes) goes top-left. New UI that belongs to the customer's order goes top-right. Do not add elements between 💰 and 그만할래, or between 그만할래 and 🐾 on the right column.

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
| `ActiveOrder` (struct, Codable) | Crash-recovery snapshot: `clothingType`, `fabricColor`, `depositAmount`, `backRoomStateName`, `savedAt`. Saved on every `BackRoomState` transition; cleared on completion or quit. Uses Swift's synthesized `Decodable` which silently ignores unknown keys — old saves with the removed `earnedMinigameRewards` field decode cleanly. |
| `DungeonItem` (enum) | `String`-raw, `Codable`, `CaseIterable`. Four cases: `purpleScepter`, `paintBrush`, `palette`, `royalFamilyPortrait`. Each maps to a dungeon seed via `dungeonSeed`. Used by `Store.loadCollectedRelics()` / `saveCollectedRelics(_:)`. |
| `Riddle` (struct, Codable) | `question`, `choices[4]`, `answer`, `reward` (default 15냥). `RiddleBank.load()` tries `Documents/riddles.json` first (parent-editable), falls back to 15 hardcoded defaults. |
| `SoundManager` (singleton) | `isMuted: Bool` (UserDefaults), `play(_ filename: String)`, `stop(_ filename: String)`, `stopAll()`. Backed by an `AVAudioPlayer` pool keyed by filename — multiple concurrent plays of the same cue are pooled, and `stop(_:)` cancels every in-flight copy. All SFX route through this — silent no-op when muted; `toggleMute()` also calls `stopAll()`. |
| `ProfileManager` (singleton) | `selectedIndex: Int` (UserDefaults), 9 cat avatars in `avatars` array with asset name + Korean display name. `advance()` / `retreat()` cycle selection. `GodmotherCat` and `WizardCat` removed in v2 migration — NPC-only assets now. |

`currentOrder: Order?` is an instance var on `FrontShopScene`. Currency state: `Wallet.shared.balance` (customer 냥) and `Magic.shared.points` (tailor 마력) — both singletons, read directly from any scene, no property handoff needed.

### Known gaps / in-progress state

- **📋 `GAME_VOCABULARY.md` needs a refresh — instructions for whichever session does it.** This file is gitignored/local-only (owner-local reference, never tracked in git — confirmed via `.gitignore` and git history), so it's invisible to any session running in a worktree (like this one) and can only be edited from the owner's main checkout, likely in a Cowork session per the owner's plan. Things confirmed or changed in the 2026-09-03 session that likely need reflecting there:
  - The shopkeeper has a real name, **Polaris** (폴라레스) — established in `DaphneBecomesTailorScene`, where she's explicitly Aurora's *younger* sister (she calls Aurora "언니"; Aurora calls her "나의 동생").
  - `SecondPrincessCat` = Ana (confirmed, `PrincessAnaScene.swift:124`); `FirstPrincessCat` is presumed to be Estelle (not yet confirmed by the owner, currently only used as a storybook illustration) and is slated for a Phase 7 visual reveal.
  - Estelle's fate (Phase 7, planned): fell through a portal, Alice-in-Wonderland style, into modern-day Korea — specifically Gwanghwamun Square (광화문광장). If the vocabulary doc tracks world/setting concepts, this introduces "modern-day Korea" as a place the story can reach, which is a significant departure from the fairy-tale kingdom setting.
  - Whatever ends up documented for Phase 7's planned mechanics (Daphne's 150-마력 stomp→magic-sleep interaction change, the 300-마력 Wizard's Chamber placeholder) once those are actually built — they don't exist yet, so don't backfill vocabulary entries for them until the code lands.
  - General pass: confirm the doc's monster/mechanic descriptions still match current code (this session found and fixed unrelated staleness in CLAUDE.md itself — e.g. `Order`'s fields were still described as `String` months after they became enums — so drift of this kind is plausible here too).
- **⚠️ Remove all `#if DEBUG` triple-tap dev shortcuts before shipping.** All are `#if DEBUG`-gated (won't build into a release/TestFlight archive) but are flagged here as a deliberate pre-ship checklist item since they mutate real persisted state, not just a view-only cheat. Four exist, all triple-tap-in-a-corner: `SettingsScene.swift:381` (top of `touchesBegan` — triple-tap anywhere clears collected relics + relic-quest state, for re-testing the Phase 5 quest from scratch), `MinigameNode.swift:562` and `BossMinigameNode.swift:918` (triple-tap the upper-right of the dungeon arena — instantly completes the current station/boss, added because the boss fight's two-button mechanic can't be tested on the Simulator, which has no simultaneous multi-touch), and `StorybookScene.swift:987` (triple-tap the ToC's top-right corner — marks the relic quest complete via `Store.saveRelicQuestComplete()` to unlock chapter 5 "장면 다시 보기" for story-content preview without playing the dungeons). Search `tapCount >= 3` to find all of them.
- **Finished-garment trophy sprites are placeholders.** The 9 `Mannequin_{ClothingType}_{FabricColor}` images (`GarmentNaming.swift:25`) shown on the mannequin at `showingFinishedGarment` and stored in the wardrobe are stand-ins, not final art — the intended final garment-on-mannequin sprites were meant to be generated via a ChatGPT image-gen subscription that ran out before that work happened. Revisit once that subscription (or another art source) is available again; until then, treat these 9 assets as temporary.
- *(Resolved — Phase 6a)* `FrontShopScene` used to load its node layout from `GameScene.sks` (background, shopkeeper, mannequin); it's now built in code like every other scene, via `setupSceneNodes()` in `FrontShopScene.swift`, and the `.sks` file is deleted. All 8 `FrontShopScene(fileNamed: "GameScene")` call sites now use `FrontShopScene(size:)` instead. One gotcha hit during the conversion: `FrontShopScene` never set `anchorPoint = (0.5, 0.5)` itself — the `.sks` file supplied that implicitly — so the fresh `SKScene(size:)` default of `(0,0)` silently shifted every center-based coordinate (`x: 0` for the shopkeeper, `frame.midX`/`midY`, etc.) toward the bottom-left until the anchor point was set explicitly at the top of `didMove(to:)`, matching every other programmatic scene in the codebase.
- *(Resolved)* `Order.clothingType` / `Order.fabricColor` are now the `ClothingType` / `FabricColor` enums, and `FrontShopScene`'s `if currentState == .case` guards now route through the exhaustive `FrontShopState.accepts(_:)` switch — restoring compile-time exhaustiveness. The stringly-typed switches in `GarmentNaming`, `BackRoomScene` (halo shades), and `DressingRoomScene` were converted to the enums in the same pass.

## Roadmap

### Phase 1 — Initial prototype (shipped)
Fixed pink-dress flow. Fabric and button choices in the back room were hardcoded; the `Order` from the front shop was not forwarded. Cleanup work removed the dead `readyForTransition` enum case and the visible debug overlays on back-room zones.

### Phase 2 — Game loop expansion (shipped)

The NPC shopkeeper guides the player through three ordering steps in sequence:
1. Pick clothing type (dress, shirt, pants)
2. Pick fabric color (pink, blue, yellow)
3. Pay deposit

`Order` carries `clothingType: String`, `fabricColor: String`, and `depositAmount: Int` *(stale — since retyped to the `ClothingType`/`FabricColor` enums; see Model layer above)*. The back room uses `clothingType` and `fabricColor` to produce the correct finished garment and to theme all four minigames.

- **Phase 2a — Fabric color (shipped):** Front shop asks for fabric color after clothing pick (`choosingFabricColor` state). `Order` carries `fabricColor: String`, forwarded to `BackRoomScene` via the `order` property. Used for minigame theming, halo color, and the finished-garment image name.
- **Phase 2b — Clothing type (shipped):** Front shop asks for clothing type, `Order` carries it, back room produces the matching garment.
- **Phase 2c — Button type (cancelled):** Dropped — button type choice doesn't add meaningful player agency at this stage of the game.

### Phase 3 — Station minigames
Each station (fabric cabinet, sewing station, button station, mannequin) gates progress with a Super Mario–style platformer minigame. The player navigates a small dungeon, defeats a monster, and reaches a treasure chest containing the needed item (fabric, thread, buttons, finished dress) before that station unlocks.

**Shipped:** fabric cabinet (station 1, tutorial — stationary monster, no hazards), sewing station (station 2 — pacing monster, scissor-blade hazards to jump over), button station (station 3 — pacing monster on the right side of the arena, falling-button hazards from the ceiling), mannequin station (station 4 — boss fight via `BossMinigameNode`; three telegraphed attacks, 3 HP, boss-on-chest reveal). All station-specific behavior for stations 1–3 lives in `MinigameConfig` (level seed, `MonsterBehavior`, `HazardKind`, theming); shared mechanics live in `MinigameNode`. The mannequin boss uses a sibling `BossMinigameNode` with its own bespoke attack loop.

### Phase 4 — Audio pass

Effectively complete — a full sound pass across every scene. *(Correction: this used to call itself "the v1 release gate," which was wrong — nothing has shipped. See "App Store ship gate" after Phase 7 below for what shipping actually requires and what the current alpha-testing status really is.)*

All 28 SFX are sourced and bundled in `DesignerAna/SoundEffects/`. **23 are wired in code**; the remaining 5 sit on disk for revival — 2 retired (`sfx_wardrobe_sparkle`, `sfx_wardrobe_open` — the dress nav icon now uses the standard `sfx_button_tap` and the firefly badge was removed), and 3 un-wired pending review (`sfx_dungeon_fanfare`, `sfx_land`, `sfx_tailor_walk` — each felt repetitive or unnecessary in owner playtests). Per-SFX status, source filenames, and re-wire hints all live in `SOUND_INVENTORY.md` (git-tracked, at the repo root).

`SoundManager` was refactored mid-Phase-4 from `SKAction.playSoundFileNamed` to an `AVAudioPlayer` pool with a `stop(_:)` API. This was needed because the original SKAction-based approach could not cancel in-flight audio — long cues (footstep loops, boss attack telegraphs) were bleeding into the next scene when the SKAction sequence ended but the audio file kept playing. Boss-attack telegraphs now stop on defeat / hero death / reset via `stopBossAttackSFX()` in `BossMinigameNode`.

### Phase 5 — Relics Quest (shipped)

A meta-quest layered onto the existing dungeon loop. The tailor collects four of Princess Estelle's relics: Purple Scepter (fabric cabinet) → Paint Brushes (sewing) → Palette (buttons) → Royal Family Portrait (boss). Estelle's purple color signature drives the **in-dungeon relic glow tint** (collection sparkles and HUD arc). The **relic handoff halos** in `PrincessAnaScene` (`animateRelicHandoff`) use Daphne's warm gold (#FFD54F) — reflecting that she is the one doing the giving, not Estelle.

**Shipped (June 4 session):**
- `DungeonItem` enum + `Store.loadCollectedRelics()` / `saveCollectedRelics(_:)` persistence.
- HUD relic row: four slots top-left of the back room (tailor-side), left of the 🐾 counter. Persists across launches. Stays visible permanently as a keepsake after quest completes.
- In-dungeon relic spawning in `MinigameNode` (seeds 1–3) and `BossMinigameNode` (seed 4). Walk-over collection: scale pop + sparkle burst + arc animation to HUD slot. Safety net auto-pull if the chest is opened before the relic is collected.
- `CatPaw` breadcrumb trails in all four dungeons. Each paw awards 1 마력 on contact and disappears. Seeds 1–3: 10 paws per level along the path to the relic. Boss: 8 paws scattered across the arena floor and platforms. Portrait relic bobs on the upper stepping stone from the start of the boss fight (walk-over collection, not auto-collect).

**Shipped (later June sessions):**
- `TailorChoiceScene` — fires once from `BackRoomScene` (`presentTailorChoiceScene()`, gated on all four relics collected): cinematic relic deduction + A/B choice, then routes onward.
- `AuroraChamberScene` — Aurora the wizard mentor, riddle gate, fade transition to the final scene. Built on the shared `NarrativeHUD` (bust-up portraits + dialogue panel).
- `PrincessAnaScene` — final scene: relics handed to Ana via the orbit/float handoff animation, godmother reveal, curse story. Saves the quest-complete flag (`Store.saveRelicQuestComplete()`) on the outro.
- `DaphneBecomesTailorScene` — backstory cutscene (Aurora, Polaris, Daphne), reached from the storybook.
- Back-room selfie keepsake (`Selfie_TailorAndPrincessAna`) appears on the wall once the quest is complete (`setupSelfieKeepsake()` in `BackRoomScene`, gated on `Store.loadRelicQuestComplete()`).
- `NarrativeHUD` shared dialogue component (bust-up `Portrait_*` assets) used by all narrative scenes; storybook replay routing returns each replayed scene to the correct chapter/page.

**Full design spec** in `RELICS.md` (gitignored — owner-local). NPC sprites (`WizardCat`, `GodmotherCat`) are xcassets-only — removed from the player-selectable carousel in the ProfileManager 11→9 reduction.

### Phase 6 — Front-shop structural refactor (in progress)

Two structural changes to `FrontShopScene`, tackled together since both touch the same scene.

**6a — SKS → programmatic layout (shipped).** `FrontShopScene` used to load its node layout from `GameScene.sks`; it now builds it in code via `setupSceneNodes()`, matching every other scene. See the "Known gaps" entry above for the anchor-point gotcha hit during the conversion.

**6b — Front-shop POV flip (shopkeeper ↔ customer, third person).** Currently the shopkeeper addresses the player directly, as if the player *is* the customer — no customer character is ever rendered on screen; `ProfileManager.shared.selectedDisplayName` only ever appears as text in the greeting (`FrontShopScene.swift`), never as a sprite. Target: the player watches a visible NPC customer interact with the shopkeeper, the same POV relationship the tailor already has with Princess Ana / the fairy godmother in the Phase 5 narrative scenes.

Design decisions settled for this pass — do not re-litigate without owner sign-off, both alternatives below were explicitly considered and rejected:
- **Interaction model stays input-driven, not a cutscene.** A no-input "full cutscene" version (NPC order randomized, no player taps at all during the ordering flow) was proposed and rejected as too large a departure from the existing loop. `FrontShopState`, `ShopInput`, and the exhaustive `accepts(_:)` switch (`FrontShopState.swift:44`) are unchanged. The player still taps to choose clothing type, fabric color, and pay the deposit — those taps now drive a visible on-screen NPC customer (reuse the `ProfileManager.shared.selectedAssetName` avatar sprite, the same one picked in `SettingsScene`) who visibly performs the action, while the shopkeeper's dialogue addresses that NPC instead of the camera/player.
- **Scope is FrontShopScene's ordering flow only.** Extending the customer-NPC treatment to `RiddleScene` (and further to `SettingsScene` + `DressingRoomScene`) was considered and rejected — those three stay exactly as they are (shopkeeper riddle minigame, avatar/reset menu, wardrobe browser). Only `greeting → choosingClothing → choosingFabricColor → reviewingOrder → awaitingPayment → sendingOrder → showingFinishedGarment` gets the customer-NPC treatment.
- Order generation (still player-chosen, not randomized) and the `showingFinishedGarment` trophy-claim tap are unaffected — nothing about *who decides* changes, only *who the shopkeeper is visibly talking to*.
- **Kept the speech-bubble dialogue UI; did not adopt `NarrativeHUD`.** Reusing the Phase 5 narrative component (bust-up portraits + dialogue panel) for visual consistency with Ana/the godmother scenes was considered and rejected on two concrete grounds: (1) `NarrativeHUD`'s portraits only exist for the Phase 5 cast (`Portrait_Ana`, `Portrait_Aurora`, `Portrait_Daphne`, `Portrait_Flora`, `Portrait_Polaris`) — there's no bust-up art for the shopkeeper or any of the 9 `ProfileManager` avatars, so reuse would mean producing 10 new portrait assets, not just reusing code; (2) `NarrativeHUD` is shaped for sequential dialogue lines plus an occasional short multiple-choice fork (`showChoices`), not the front shop's per-state spatial buttons (clothing rack row, fabric swatches, a whole order-review sheet, a payment panel) — forcing that flow through NarrativeHUD would be a bigger rewrite than the POV change calls for. The POV consistency the flip is after is conceptual (player watches two characters interact), not a literal shared UI component.
- **Dialogue audit turned out to be a non-issue.** None of `FrontShopScene`'s existing lines (`showGreeting`, `handleChoice`, `handleFabricColorChoice`, `handleConfirmOrder`, `handleCancelOrder`, `handlePayment`, `showCompletionGreeting`) use an explicit second-person pronoun (no "당신"/"너") — Korean politeness endings drop the subject, so lines like "안녕하세요, {name}님! 어떤 옷을 만들어 드릴까요?" already read correctly whether the shopkeeper is addressing the camera or an on-screen NPC. No text rewrites were needed; the POV change is purely about *rendering* the customer, not rewording dialogue.

**Shipped (implementation):**
- Customer NPC sprite (`ProfileManager.shared.selectedAssetName`, named `"customerNPC"`) added in `setupSceneNodes()`, positioned in `fixCharacterLayout()` via a repurposed slot in `Layout.frontShopCharacters` — the tuple used to return an unused `wardrobe: CGPoint` (documented as "wardrobe on the left" but never actually consumed anywhere); renamed to `customer` and aligned to the same `baseY` as shopkeeper/mannequin instead of its old y-offset. Final composition: customer (left) — shopkeeper (centre) — mannequin (right), mirroring mannequin's spread on the opposite side.
- Fades in (`SKAction.fadeIn`) on every load rather than only on a fresh greeting, so the entrance reads consistently across all 8 entry paths (finished-garment return, relaunch dialog, etc.) without branching per case.
- Reaction cue: `bounceCustomerReaction()` (a small scale-pulse) plays on clothing choice, fabric choice, and the completion greeting. `showPaymentCoinFlourish()` hops a small `NyangCoin` sprite from customer to shopkeeper on successful payment, then fades it out — reuses an existing asset (previously only used as a storybook illustration), no new art needed. "Walk to rack" and "hold up fabric swatch" from the original open list were dropped — the avatar art is a single static pose per character with no such frames, and animating a walk/prop-hold convincingly wasn't worth the added complexity for what a scale-pulse already sells adequately.
- **Shopkeeper's scale corrected 0.25 → 0.32** (matches the tailor's reference scale in `BackRoomScene`) in the same pass, per the owner's flagged mismatch during 6a QA — folded in here since the customer NPC's arrival required recomputing this composition anyway.

**Two scale gotchas hit while wiring up the customer sprite** — both are `FrontShopScene.swift` / `fixCharacterLayout()` specifics worth knowing before touching character scale in this scene again:
1. `Shopkeeper.imageset`/`Tailor.imageset` register their PNG under the **2x** slot in `Contents.json`, so `texture.size()` returns *half* the pixel dimensions in points. The loose `ProfileAvatars/*.png` files (customer avatars) have no such registration and load at full pixel size in points (1x). Applying the same scale multiplier to both is not the same apparent size — the customer rendered at ~2x the intended height until this was caught.
2. `SKSpriteNode.size`, once `.setScale()` has been called, reads back as the *already-scaled* size, not the original texture size — so computing a second sprite's scale as `referenceSprite.size.height * referenceSprite.yScale` double-applies the scale. Correct target height is just `referenceSprite.size.height` alone. Caught via a temporary debug print comparing `shopkeeper.size`/`yScale` against the computed customer scale — the customer was rendering at ~1/3 the intended height before this fix.

Interactive QA passed (owner tap-through, full flow to trophy claim) — bounce/coin-flourish cues confirmed firing correctly end-to-end.

### Phase 7 — Daphne's arc conclusion & Ana's introduction (planned / in design)

Continues the Phase 5 relics-quest storyline. **Not yet built** — captured here so the direction survives a session boundary. Several pieces below are explicitly still fluid ("maybe") rather than locked, and are flagged as such.

**Ending sequencing (locked, 2026-09-03).** Six distinct trigger points compete for the same moment — a dungeon order finishing and the player returning to the shop — and were numbered to reason about precisely: **Ending 1** Relics Quest Ending (shipped), **Ending 2** Daphne's Level-Up / 150 마력 (shipped, independent — see below), **Ending 3** Wizard's Chamber Summons / 300 마력 (placeholder), **Ending 4** Daphne's Farewell ("maybe"), **Ending 5** Ana Becomes Tailor (timing open), **Ending 6** Estelle Reveal (placement open). The locked rule: **Ending 3 (and everything chained after it — 4, 5, 6) may only fire once `Store.loadRelicQuestComplete() == true`.** If `Magic.points` crosses 300 before the relics quest resolves, the summon just stays dormant, rechecked on every subsequent order completion — same mechanism already planned for "wait until no order is in progress," just with one more condition. This isn't only a UI-collision fix: it's a narrative-causality requirement, since Endings 3–6 assume Daphne has already found and delivered all of Estelle's relics before her own "graduation" arc begins. Ending 2 stays independent of this whole gate — it's a passive ability unlock with no scene, checked on every dungeon load, nothing competes with it for screen time. Still open, not yet decided: whether Ending 4 ships at all this phase, Ending 5's exact trigger ("sometime after" isn't code), and whether Ending 6 rides along with Ending 5 or lands separately.

**Trigger chain, gated on `Magic.shared.points` (🐾 마력):**
- **150 마력 — Daphne levels up.** Her dungeon-minigame defeat interaction changes from a stomp jump to a magic-based "put to sleep" action. This isn't a new concept out of nowhere — the Fairy Godmother already establishes in `PrincessAnaScene` (beat 12) that defeating a monster only puts it to sleep, doesn't harm it ("재봉사님이 몬스터를 물리치면, 몬스터는 잠시 잠드는 것뿐이에요"); this makes that lore literal in the mechanic instead of just narration. Not yet speced: the actual input/animation for the new interaction, and whether it fully replaces the stomp or is an alternative.
- **300 마력 — "Aurora summons Daphne to the Wizard's Chamber."** Build a **placeholder/stub only** for this pass — full content is intentionally deferred, not part of this phase.
  - This doesn't fire the instant the threshold is crossed if a garment order is in progress — Daphne must finish that order and it must be saved to the wardrobe (`handleSaveTrophy()` in `FrontShopScene`) first. Needs a persisted "magic threshold crossed, awaiting order completion" flag distinct from the summon itself.
- **On the next front-shop load after that wardrobe save — Daphne's farewell scene.** *(Design still "maybe," not locked.)* Returns to the front shop, but this time Daphne stands there with 폴라레스 Polaris — the shopkeeper's actual name, established in `DaphneBecomesTailorScene` where she's explicitly Aurora's *younger* sister (Polaris calls Aurora "언니"; Aurora calls Polaris "나의 동생"). A speech bubble shows Aurora's teleport incantation; Daphne disappears; Polaris wishes her well studying under her "tough older sister" Aurora.
- **Sometime after that — Princess Ana visits the shop.** Pays off the promise at the very end of `PrincessAnaScene` (beat 18: "이제 저도 모험을 할 때가 된거 같아요... 나중에 가게로 찾아 갈게요"). Polaris tells Ana that Daphne redeemed herself and returned to the tower, that the shop needs a new tailor, and Ana volunteers — motivated by wanting more clues about her missing older sister ("에스텔 언니"). Exact staging/scene structure not yet speced. Delivery target: a new storybook chapter/scene chain, the same way Phase 5's chain was delivered — narrative-only, does **not** change who the player controls in `BackRoomScene` (Daphne's sprite/mechanics stay as-is; this is a story beat, not a protagonist swap).

**Estelle reveal (visual tease, not text-only).** Estelle didn't just vanish into the dungeon — she fell through a portal, Alice-in-Wonderland style, into modern-day Korea, specifically Gwanghwamun Square (광화문광장). Likely uses the currently-unused `FirstPrincessCat` asset (so far only an illustration in the storybook's royal-family chapter, `StorybookScene.swift:128`) — presumed to be Estelle given `SecondPrincessCat` is confirmed as Ana's sprite (`PrincessAnaScene.swift:124`). Exact staging not yet speced.

**Explicitly out of scope for this phase:** a side-quest arc for Daphne as Aurora's redeemed apprentice, post-departure — the owner is still designing this separately.

### App Store ship gate

**Current status is alpha testing, not a ship.** The owner has an Apple Developer Program account and sideloads builds directly onto testers' physical devices (see "Signing & bundle identity" above — that's specifically why the paid team was worth enrolling in: dev provisioning profiles last ~1 year instead of expiring every 7 days, so testers don't need a re-sideload every week). Testers play; the owner watches. Nothing has been submitted to the App Store. Phase 4 used to mislabel itself "the v1 release gate" — that was stale/wrong and has been corrected above.

**The actual gate for an App Store submission, as an educational app, is all three of:**
1. Phase 7's Daphne level-up ships (150 마력 — the stomp → magic-sleep mechanic).
2. Phase 7's Ana quest begins (the shop handoff scene) with the Princess Estelle teaser (FirstPrincessCat).
3. A JSON-file educational-content feature is in place — likely realized by the existing `RiddleBank.load()` / parent-editable `Documents/riddles.json` mechanism (see Model layer above), though that connection hasn't been explicitly confirmed by the owner yet and shouldn't be treated as satisfying this criterion without checking.

Until all three are true, treat every build as pre-ship alpha, regardless of how polished any individual scene is.

### Currency & economy

Two separate currencies with distinct economic shapes:

- **Customer's 냥 (`Wallet.shared.balance`)** — circular economy. Starts at 0냥 on a fresh install or 새 손님 reset. Depleted by front-shop deposits; replenished by dungeon chest refunds (크만할래 path) and shopkeeper riddle rewards. The wardrobe is the stamp-collection win condition. A brand-new customer starts broke and earns their way in. **Exception:** the customer handoff after the relics quest (`FrontShopScene.triggerCustomerPickerAfterSave`, set by `PrincessAnaScene`) does *not* reset wallet/wardrobe — the just-finished order's trophy is saved first, then the picker lets the player choose the next customer without wiping what was just earned. This is a deliberate judgment call (wiping immediately after a save would feel like a bug), not a full 새 손님 reset — worth revisiting if it reads as inconsistent with the "new customer starts broke" rule.
- **Tailor's 마력 (`Magic.shared.points`, 🐾)** — expansive economy. Monotonically grows from dungeon chest rewards (10 / 20 / 30 / 50 마력 at cabinet / sewing / buttons / boss). Never decreases: 그만할래 refunds the customer's full deposit to `Wallet` but `Magic` is untouched (it's monotonic — no rollback needed). Tied to the tailor's wizard-apprentice growth arc and v2 Aurora mentorship dialogue.

**그만할래 quit dialog** (back room): single confirm + cancel. Customer gets a full deposit refund (`Wallet.shared.balance += depositAmount`); 마력 earned during the session stays in `Magic.shared.points`.

**새 손님 reset** (button in SettingsScene): calls `Store.resetCustomerSide()`, which zeroes `Wallet`, empties the wardrobe, clears badge counters, clears the active order, and clears the `customer.selected` sticky flag. Tailor-side state — `Magic.shared.points`, future relics, dungeon progress, and the global storybook — is untouched. After reset, the app re-routes to the first-launch customer picker.

**Persistence schema:** flat `UserDefaults` keys; no per-customer namespacing. Only one customer is "alive" at a time, identified by `customer.selected` (holds the avatar asset-name string, e.g. `"ChefCat"`). The shopkeeper riddle still credits `Wallet.shared.balance` — it's shopkeeper-driven, customer-side.

**Minigame rewards (shipped):** 10 / 20 / 30 / 50 마력 awarded on chest open at cabinet / sewing / buttons / boss — credited directly to `Magic.shared.add()` in `MinigameNode` and `BossMinigameNode`.

### V2 expansion ideas (post-roadmap)

Captured here so they're not lost; not planned for current phases.

- **Adaptive difficulty easing for station minigames.** Track death count per minigame attempt and reduce hazard density after N deaths (fewer chasms, slower monsters, longer safe gaps in button rain) so kids don't get stuck. Auto-reset to default difficulty on success. The 냥 reward should not scale down with eased difficulty — the easing exists to keep play sessions positive, not to discourage skill development.

- **Guardian reframe for the mannequin level (visual seed already in place).** The boss-on-chest reveal animation that plays on boss defeat in `BossMinigameNode` was deliberately planted as a seed for a future "guardian" iteration of the same level: replace the fight with a puzzle where the player lures a giant dust monster off the chest into a trap, rather than damaging it. Educational angle — observation and planning over reflexes. The visual continuity (boss-on-chest at defeat) makes the reframe feel like a deepening of the same level rather than a contradiction.

- **Per-customer wallet and wardrobe (not yet built).** Currently `Wallet.shared.balance` and the wardrobe are flat/global — one "current customer" slot, no namespacing (see Persistence schema above). Considered in a 2026-09-03 session: re-key both by customer identity (e.g. `wallet.balance.<customerAssetName>`) so each of the 9 avatar personas has their own separate economy and trophy case, rather than a new customer inheriting whatever the previous one earned. Owner confirmed the wardrobe should follow the same per-customer model as the wallet ("the wardrobe is theirs, not the shop's") — both move together, not just the wallet. Assessed as a contained change: `Wallet`'s read/write surface is small (`FrontShopScene` payment, `BackRoomScene`'s 그만할래 refund, `RiddleScene`'s reward), and `Store.swift` already isolates all persistence behind clean load/save functions. Side effect worth knowing: this makes 새 손님 mostly redundant for a *returning* customer — a previously-used persona picked again later would keep their own old balance/wardrobe rather than starting broke, which is a meaningfully different feature (recurring customers with persistent progress) than exists today. Not yet scoped or implemented.
- **Parent-facing riddle editor, without a login gate.** `RiddleBank.load()` already supports a parent-editable `Documents/riddles.json` override (falls back to 15 hardcoded defaults) — this is the mechanism named in the "App Store ship gate" section above as the likely JSON educational-content feature. What's still unsolved: parents currently have no interface to actually create/edit that file. The owner deliberately wants to avoid an account/login system — for a kids' educational app, that opens data-retention and privacy-law questions (COPPA-adjacent) they'd rather not take on. Needs a no-login delivery mechanism: candidates floated include a share-sheet/Files-app import flow, an iCloud Drive drop folder, or an in-app editable list UI with no account at all. Not scoped or decided — flagged here so the constraint (no login) and the goal (parent-editable riddles) aren't lost before this gets designed properly.

## Closing handoff procedure

At session end, when updating `DesignerAna_handoff.md` (the "closing handoff"), **stamp the date by running `bash date` and using that value** — do not infer the date from file timestamps, previous handoffs, or memory. The handoff date must reflect the session it documents. We made this mistake once (handoff dated May 29 for work done June 2), which caused confusion at the next session's start.

If a closing handoff doesn't happen (the owner closes the laptop unexpectedly), the owner has committed to returning to the same Cowork session next time rather than opening a new one — so the absence of a closing handoff unambiguously defines the session's status. A fresh session is the signal that a proper closing handoff was written; a resumed session is the signal that it wasn't.
