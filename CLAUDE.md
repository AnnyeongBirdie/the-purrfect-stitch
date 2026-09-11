# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Open `DesignerAna.xcodeproj` in Xcode and run on an iOS Simulator or device. There is no linting setup. **A test target exists as of 2026-09-07** — `DesignerAnaTests` (see "Test target" below).

From the command line:
```bash
# Build for simulator — prefer an explicit UDID (see below) over
# 'platform=iOS Simulator,name=iPhone 16e': that name-based form has
# repeatedly failed with an ambiguous-destination error/timeout on this
# machine (confirmed across multiple sessions), even though the simulator
# is genuinely installed.
xcodebuild -project DesignerAna.xcodeproj -scheme DesignerAna \
  -destination 'id=<simulator-udid>' build

# Find available simulator UDIDs
xcrun simctl list devices available

# Clean build
xcodebuild -project DesignerAna.xcodeproj -scheme DesignerAna clean

# Run the test suite (same destination-UDID caveat as above)
xcodebuild -project DesignerAna.xcodeproj -scheme DesignerAna \
  -destination 'id=<simulator-udid>' test
```

### Test target

`DesignerAnaTests` (added 2026-09-07) covers the Model layer's pure logic — the
cheapest, highest-signal place to test in a SpriteKit game, since none of it
needs a running scene or simulator interaction. 44 tests across:
`StoreTests` (per-customer keying isolation, `resetCustomerSide()`, the
per-customer migration's one-shot/idempotent behavior, one-shot flags),
`MagicTests` (`add(_:)`'s threshold-crossing logic), `FrontShopStateTests`
(an exhaustive truth table for `accepts(_:)` — every state×input pair, not a
sample), `GarmentNamingTests` (all 9 clothing×color asset-name combinations),
`TailorIdentityTests` (`Tailor.identity(for:)` / `haloScale(for:)`),
`CodablePersistenceTests` (round-trips plus a hand-written old-format JSON
blob to directly verify the "old saves still decode" comments in
`ActiveOrder`/`Order.swift`), `AuroraChamberSceneTests` (a regression
test for the shipped "off by 300 마력" dialogue bug — see Phase 7 below;
`AuroraChamberScene.closingLine(forMagicPoints:)` was pulled out of
`didMove(to:)` specifically to make that branch testable in isolation), and
`RiddleContentTests` (added 2026-09-08 — loads the *shipped bundled*
`riddles.json` via `Bundle.main`, not a fixture, and mechanically proves
every one of the 200 v1 questions is answerable and every arithmetic
question is arithmetically correct; see the v1 ship gate's item 3).

**Test-isolation gotcha, worth knowing before adding more `Store`-touching
tests:** the test bundle is hosted inside the real `DesignerAna.app` process
(`TEST_HOST`/`BUNDLE_LOADER`, the standard way to test an app target rather
than a framework), so `Store`'s `UserDefaults.standard` calls read/write the
**same** UserDefaults domain as whatever's actually been played on that
simulator — including this project's own extensive manual playtesting
history. `StoreTests`' `setUp`/`tearDown` explicitly clears every key it
touches, **including the `"_none"` per-customer fallback slot** (used when
no customer is selected) — omitting that one specifically caused two real
test failures the first time this suite ran, from leftover real playtest
data in that exact slot. `Wallet.shared.balance` also reads through
whichever customer is *currently* selected — reading it right after
`Store.resetCustomerSide()` (which clears the selection) resolves to the
unrelated `"_none"` slot, not the customer whose data was just wiped; the
reset test re-selects that customer before checking their balance because
of this.

No CI wiring for `xcodebuild analyze` or SwiftLint/SwiftFormat exists —
`.github/workflows/build.yml` (added 2026-09-07) just builds and runs this
test target on every push/PR to `main`.

- Swift 5.0, iOS 26.2 deployment target, **iPhone only** (`TARGETED_DEVICE_FAMILY = "1"`, set 2026-09-08 — see the v1 ship gate for why iPad was dropped)
- No CocoaPods, SPM packages, or external dependencies
- Installed simulators on this machine: **iPhone 16e** (preferred default) and iPhone 17. iPhone 16 is *not* installed — do not target it.

### Signing & bundle identity

- **Bundle ID:** `com.annyeongbirdie.thepurrfectstitch` (set June 2026, renamed from the earlier `com.JustRunItLab.DesignerAna` to consolidate under the owner's **AnnyeongBirdie** branding — matching the GitHub repo `the-purrfect-stitch`, GitHub profile, and velog blog). `JustRunItLab` was an abandoned working name used nowhere else.
- **Signing:** Automatic. June 2026: owner enrolled in the **paid Apple Developer Program**, lifting the free Personal Team's 7-day provisioning-profile expiry (paid dev profiles last ~1 year). **Verified done** — Xcode's Signing & Capabilities no longer shows the "(Personal Team)" suffix next to the owner's name. `DEVELOPMENT_TEAM` in `project.pbxproj` is `VQ4643X8XU` in all four configs and stays that way: enrolling the *same Apple ID* that held the free Personal Team upgrades it in place, retaining the same Team ID rather than minting a new one. So this value is now the **paid** Team ID, and the ID being unchanged is expected — not a sign the switch didn't take.
- **No project rename.** The Xcode project, scheme, and source folder remain `DesignerAna` — only the bundle ID changed. A full rename to match the repo is deliberately deferred (high regression risk; revisit only during dedicated structural work). Expect a naming split: project `DesignerAna`, repo `the-purrfect-stitch`, bundle `com.annyeongbirdie.thepurrfectstitch`, display name 묘한 옷 공방.
- **No Apple secrets in the repo.** Certificates/keys live in the Mac Keychain; provisioning profiles live on Apple's servers. The repo holds no credentials to rotate. Never commit `.p12`, `.cer`, `.mobileprovision`, or a secrets-bearing `ExportOptions.plist`.
- Changing the bundle ID resets `UserDefaults` (it's namespaced by bundle ID), so test devices lose saved wardrobe/progress on the next install — expected and harmless for test builds.

## Architecture

This is an iOS SpriteKit game — a Korean-language tailor-shop simulation. The player takes a clothing order in the front shop, pays a deposit, then crafts the garment in the back room and returns it to the customer.

### Scene flow

```
GameViewController
  └─ TitleScene
       └─ FrontShopScene (built programmatically — see Phase 6a)
            │  ⚙ nav  → crossFade → SettingsScene    → crossFade → FrontShopScene
            │  💰 nav  → crossFade → RiddleScene      → crossFade → FrontShopScene
            │  👗 nav  → crossFade → DressingRoomScene → crossFade → FrontShopScene
            │  📖 nav  → crossFade → StorybookScene    → crossFade → FrontShopScene
            │  pays deposit → fade transition
            └─ BackRoomScene (built programmatically)
                 │  dress placed on mannequin → crossFade transition
                 │
                 │  (normal completion)
                 ├─ FrontShopScene (reloaded)
                 │       with shouldShowFinishedGarment = true
                 │
                 └─ (4th relic collected — Phase 5, fires once)
                     RelicDeductionScene → AuroraChamberScene → PrincessAnaScene
                       └─ FrontShopScene, shouldShowFinishedGarment = true
                            + triggerCustomerPickerAfterSave = true
                            └─ (trophy saved) → SettingsScene (customer-picker
                               mode, isFirstLaunchPicker = true) → FrontShopScene
                               (new customer)
```

Scene-to-scene communication is a plain property set on the destination before `presentScene()`. There is no shared coordinator or persistent storage across launches.

`GameViewController` always opens `TitleScene`, which shows two buttons: "이야기 소개" (storybook) and "바로 시작하기" (jump to the shop). Tapping the shop button calls `goToShop()`, which checks `Store.loadSelectedCustomer()` and routes to `SettingsScene` in `isFirstLaunchPicker = true` mode if `nil` (first launch or post-새 손님 reset), otherwise straight to `FrontShopScene` — this routing is gated behind the tap, not automatic on scene load. **Added 2026-09-05:** the shop button itself is locked (dimmed, 🔒, tap is a no-op) until `Store.loadHasOpenedStorybook()` is true, set the moment "이야기 소개" is tapped — a first-time player should meet the world/cast (including the veiled "???" mystery character in chapter 6, see Storybook spoiler veiling below) before jumping straight into play. Confirmed via device playtest: renders locked on a fresh install, unlocks permanently after the storybook is opened once.

Side-scenes (DressingRoomScene, RiddleScene, SettingsScene, StorybookScene) all set `scene.suppressEntryBell = true` before presenting FrontShopScene on return, so the shop bell only plays on genuine entries (app launch, back-room completion, first-launch picker start), not on return from navigation.

### Three functional spaces + POV map

The tailor shop has three functional spaces, each with a deliberate POV. The shop **front**'s ordering flow (`FrontShopScene`) is third-person customer POV as of Phase 6b — the player picks a customer avatar in settings, and that avatar is rendered on screen as a visible NPC the shopkeeper (Polaris) actually talks to; the player's taps still drive the NPC's choices, but the player watches rather than being addressed directly as the customer. This was a deliberately scoped flip: `SettingsScene`, `RiddleScene`, and `DressingRoomScene` were explicitly left alone (see Phase 6b) — they're meta/utility screens (avatar picker, riddle minigame, wardrobe browser), not narrative "customer talks to shopkeeper" moments, so they don't carry a customer-POV framing at all. The **back room** (workshop) is tailor POV — the player watches the tailor work and sees both the customer's deposit reference (💰 냥) and the tailor's growth tracker (🐾 마력) in the HUD. The **basement** is the four dungeons (fabric cabinet, sewing, buttons, mannequin boss); plus Phase 5's `RelicDeductionScene`, `AuroraChamberScene`, `PrincessAnaScene`, and `DaphneBecomesTailorScene` scenes. All basement scenes are tailor POV.

| Space | Scenes | POV |
|---|---|---|
| Shop front — ordering flow | `FrontShopScene` | Customer NPC, third-person (player watches, still drives the taps) |
| Shop front — utility screens | `SettingsScene`, `RiddleScene`, `DressingRoomScene`, `StorybookScene` | Not narrative POV — meta/utility UI, unaffected by 6b |
| Back room | `BackRoomScene` (HUD column top-to-bottom: 💰 냥, then 그만할래 quit button, then 🐾 마력 at the bottom — do not place anything between 💰 and 그만할래, or between 그만할래 and 🐾) | Tailor |
| Basement (dungeons) | `MinigameNode`, `BossMinigameNode`, and Phase 5: `RelicDeductionScene`, `AuroraChamberScene`, `PrincessAnaScene`, `DaphneBecomesTailorScene` | Tailor |

### Back room HUD layout convention

The back room HUD is split by ownership: **tailor-side elements anchor to the top-left; customer-side elements anchor to the top-right.** This design language must be preserved for all future HUD additions.

| Side | Elements | Position |
|---|---|---|
| Top-left (tailor) | Tailor Status HUD panel: tailor name, 🐾 마력 bubble, ✨ level-up badge, relic slot row | `size.width * -0.36`, upper portion |
| Top-right (customer) | Customer Status HUD panel: customer name, 💰 냥 bubble, ordered garment type + color | `size.width * 0.36`, upper portion |
| Independent | 그만할래 quit button | `(0, 100)` — not nested in either panel |

New back-room UI that belongs to the tailor (dungeon progress, quest state, keepsakes) goes top-left, inside the Tailor Status HUD panel. New UI that belongs to the customer's order goes top-right, inside the Customer Status HUD panel.

**Status HUD redesign — shipped 2026-09-06** (`BackRoomScene.swift`, `setupHUDCounters()`/`setupStatusPanels()`/`updateLevelUpBadge()`). Replaced the old loose-elements layout described above (which this table used to document) with two translucent grouped panel backgrounds (`SKShapeNode`, `zPosition` 15, drawn behind everything else) sized to bound each side's actual elements:
- **Tailor panel:** the 🐾 bubble grew from one line to two (`statusBubbleSize`, 150×56pt) to fit `tailorIdentity.displayName` above the existing counter text, its **top edge kept at the same 8pt inset as before** so it only grows downward — the relic row underneath is deliberately left untouched at its old absolute position, since `MinigameNode`/`BossMinigameNode`'s relic-fly-to-slot-HUD target math (`collectRelic`/`collectPortrait`) duplicates that same Y formula independently in those two files; moving the row would need updating three files in lockstep, so instead only the bubble above it changed. The panel background bounds the bubble + relic row + the ✨ badge's reserved space (see below).
- **✨ level-up badge:** appears once `Magic.shared.points >= 150`, including live mid-run the same way the in-dungeon ✨ ability button does (`updateHUDCounters()` calls `updateLevelUpBadge()` after every station/boss completion). Sits **beside** the 🐾 bubble rather than literally "between" the counter and relic row as originally phrased — there's only a 6pt gap between them, not enough room, and moving the relic row to make room hits the same three-file duplication problem above. Flashes (pop-in + 3 pulses) only the very first time it appears, gated by `Store.loadLevelUpBadgeFlashed()` (mirrors `tailorHandoffShown`'s one-shot pattern) — every later `BackRoomScene` load just shows it statically. **Important:** the tailor panel's background reserves the badge's space *unconditionally* at setup, even if `Magic.points < 150` and the badge doesn't exist yet — since the panel is drawn once and the badge can appear later mid-run, not reserving space up front would have it render outside the already-fixed panel edge.
- **Customer panel:** the 💰 bubble similarly grew to two/three lines — customer name, 💰 counter, and (when `order != nil`) the ordered garment's color + type (`\(order.fabricColor.displayName) \(order.clothingType.displayName)`).
- **그만할래 moved to an independent placement** at `(0, 100)` — not nested in either panel, per the original design intent. **Gotcha hit during this session:** an initial attempt placed it at `(0, size.height*0.44 - 10)`, which collided visually with `instructionLabel` (`(0, 150)`) on-device — both sat in the same x=0 column at nearly the same height. Moved further down to clear it.

**Verified in the simulator (2026-09-06):** both panels render cleanly with no overlap at `Magic.points < 150` (no badge yet) — confirmed via screenshot after the `그만할래` collision above was found and fixed. **Not yet verified:** the badge's live mid-run appearance (`Magic.points` crossing 150 *during* a dungeon visit, then returning to `BackRoomScene`) — the simulator's synthetic triple-tap for the in-dungeon debug shortcut didn't reliably register (same documented tapCount friction as the 150/300 VFX work), so this specific path needs an owner device playtest to confirm the reserved-space fix actually holds up live, not just reasoned through.

### State machines

**FrontShopScene** uses the `FrontShopState` enum (in `Model/`):
`greeting → choosingClothing → choosingFabricColor → reviewingOrder → awaitingPayment → sendingOrder`
Plus `showingFinishedGarment` — entered on return from the back room with a completed garment; all nav icons are blocked and dimmed in this state until the trophy is saved to the wardrobe.

**BackRoomScene** uses a private nested `BackRoomState` enum with this linear progression:
`waitingForCabinetTap → walkingToCabinet → waitingForSewing → walkingToSewing → waitingForButtons → walkingToButtons → waitingForMannequin → walkingToMannequin → finalCheck → completed`

The fabric cabinet, sewing station, and button station each gate on a platformer minigame (`MinigameNode` + `MinigameConfig`) — the tap walks the tailor over, then `presentMinigame` hands control to a station-specific config; the minigame's completion callback advances the state. The mannequin station uses `BossMinigameNode` (a sibling to `MinigameNode`, not routed through `MinigameConfig`) — on boss defeat the state advances to `.finalCheck`, the brief beat between the chest opening and the dress appearing on the mannequin, before the scene transitions back to the front shop.

### Tailor halo

A vertical pill-shaped halo behind the tailor sprite in `BackRoomScene` provides ambient visual feedback. Its color tracks `order?.fabricColor` and **deepens in shade with each station cleared** (light after fabric → medium after sewing → dark after buttons), pulsing via alpha breathing throughout. At completion, the pulse stops and the halo expands to fill the screen before the scene transitions back to the front shop. The three shades per color are hand-tuned `UIColor` values centralized as `haloLight` / `haloMedium` / `haloDark` computed properties.

**Scales per tailor (fixed 2026-09-06).** The halo's base size (70×200pt pill) was tuned by eye against Ana's reference height/silhouette. Once Daphne's Tailor Identity scale shipped (she renders at 70% of Ana's height — see Tailor Identity system below), the same fixed-size halo visibly stuck out past her shorter, narrower sprite instead of reading as "glowing from within" — owner feedback after seeing it on-device. Fixed via `Tailor.haloScale(for:)` (`TailorIdentity.swift`), which returns `renderedHeight / anaReferenceHeight` (1.0 for Ana, 0.70 for Daphne); `BackRoomScene.haloBaseSize` applies that scale to the halo's width/height, and `showTailorHalo` scales `cornerRadius`/`lineWidth`/`glowWidth` proportionally too so the pill shape and stroke weight stay consistent at the smaller size. The full-screen "halo expands to cover everything" animation in `placeDressOnMannequin` used to divide by a hardcoded `70` to compute its target scale — that assumed Ana's halo width and under-expanded Daphne's smaller one, so it now divides by `haloBaseSize.width` instead.

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

`Model/` has fifteen files; scene-specific state still lives inside each scene class.

| Type | Key fields |
|---|---|
| `Order` (struct) | `clothingType: ClothingType`, `depositAmount: Int`, `fabricColor: FabricColor` |
| `ClothingType` / `FabricColor` (enums) | `String`-raw, `Codable`, `CaseIterable`; live in `Order.swift`. Korean raw values, kept identical to the old `String` model so `Codable` persistence stays byte-compatible. Helpers: `displayName`, `assetFragment` / `assetSuffix`, and `FabricColor.palette`. |
| `FrontShopState` (enum) | seven cases, drives UI in FrontShopScene. `ShopInput` + `FrontShopState.accepts(_:)` — a single exhaustive `switch self` — gate which buttons each state accepts. |
| `MinigameStation` family | `MinigameStation` enum (4 cases) + `MinigameConfig` struct + helper enums (`EnemyKind`, `DefeatMechanism`, `MonsterBehavior`, `HazardKind`). Drives stations 1–3; the boss does not flow through `MinigameConfig`. Daphne-specific (platformer) — Phase 7 plans a parallel puzzle-minigame config family for Ana, not yet built. |
| `Wallet` (singleton) | `balance: Int` — **customer-side** 냥. 0 on a fresh install and on every 새 손님 reset. Persisted via `Store.loadWalletBalance` / `saveWalletBalance`. **Per-customer since `7b2d173` (2026-09-04)** — keys are suffixed by the selected customer via `perCustomerKey()`; see Currency & economy below. Deliberately holds **no in-memory cache**: the getter reads through to `Store` on every access, because the active customer can change mid-session (새 손님, the post-relics-quest handoff) without a relaunch, and a cached value would go stale exactly then. |
| `Magic` (singleton) | `points: Int` — **tailor-side** 마력 (cat wizarding XP, 🐾), specifically Daphne's wizard-taught magic. Grows via `add(_:)` (dungeon rewards) and **can be spent via `spend(_:)`** (2026-09-10 — the ✨ ability now costs 10 마력 per cast, floored at 0; see Currency & economy). No longer strictly monotonic. Persists across 새 손님; tied to the tailor's wizard-apprentice growth arc. Phase 7's Tailor Identity system plans a separate fairy-taught currency for Ana with her own name/thresholds — not a generalization of this type, a distinct one — not yet built. |
| `ActiveOrder` (struct, Codable) | Crash-recovery snapshot: `clothingType`, `fabricColor`, `depositAmount`, `backRoomStateName`, `savedAt`. Saved on every `BackRoomState` transition; cleared on completion or quit. Uses Swift's synthesized `Decodable` which silently ignores unknown keys — old saves with the removed `earnedMinigameRewards` field decode cleanly. |
| `DungeonItem` (enum) | `String`-raw, `Codable`, `CaseIterable`. Four cases: `purpleScepter`, `paintBrush`, `palette`, `royalFamilyPortrait`. Each maps to a dungeon seed via `dungeonSeed`. Used by `Store.loadCollectedRelics()` / `saveCollectedRelics(_:)`. Daphne-specific ("relics"); Ana's era reuses this exact same 4-slot mechanic renamed to "clues" (Phase 7, not yet built) rather than a new collection system. |
| `Riddle` (struct, Codable) | `question`, `choices[4]`, `answer`, `reward` (default 5냥 as of the 2026-09-10 economy retune — was 15냥), `category: RiddleCategory` (default `.addSub` if omitted/unparseable — a parent's file that drops or misspells it still loads). `RiddleCategory` is a 4-case ASCII-id enum (`addSub`/`mulDiv`/`enToKo`/`koToEn`) with a Korean `displayName` resolved in code, not stored in the JSON. `RiddleBank.load()` tries `Documents/riddles.json` first (parent-editable, seeded there absent-only on first launch via `seedDocumentsIfNeeded()`), then the bundled `riddles.json` (the shipped 200-question v1 content set), then a tiny 8-question hardcoded last resort only reachable if the bundle itself is missing/corrupt. A `Documents/riddles.json` decode failure logs via `os_log` (subsystem `com.annyeongbirdie.thepurrfectstitch`, category `RiddleBank`) and falls back silently — there is still no visible in-app signal to the parent (filed as a v2 candidate). |
| `SoundManager` (singleton) | `isMuted: Bool` (UserDefaults), `play(_ filename: String)`, `stop(_ filename: String)`, `stopAll()`. Backed by an `AVAudioPlayer` pool keyed by filename — multiple concurrent plays of the same cue are pooled, and `stop(_:)` cancels every in-flight copy. All SFX route through this — silent no-op when muted; `toggleMute()` also calls `stopAll()`. |
| `ProfileManager` (singleton) | `selectedIndex: Int` (UserDefaults), 9 cat avatars in `avatars` array with asset name + Korean display name. `advance()` / `retreat()` cycle selection. `GodmotherCat` and `WizardCat` removed in v2 migration — NPC-only assets now. This is the customer roster; there is no equivalent "tailor roster" type yet — Phase 7's Tailor Identity system is the planned analog for Daphne/Ana (and eventually the rest of the royal family), not yet built. |
| `FinishedGarment` (struct, Codable) | A saved wardrobe trophy: clothing type, fabric color, completion date. `Store.loadGarments()` / `saveGarments(_:)`. |
| `GarmentNaming` (enum, namespace) | Maps `(ClothingType, FabricColor)` → the `Mannequin_{ClothingType}_{FabricColor}` asset name shown on the mannequin and in the wardrobe. |
| `Layout` (enum, namespace) | Positioning math shared across scenes — e.g. `frontShopCharacters(in:)` computes the customer/shopkeeper/mannequin composition in `FrontShopScene`. |
| `UserDefaultsStore` (`Store`, enum namespace) | Every load/save function and `UserDefaultsKey` string constant in one place — the single seam all persistence flows through. (One inaccuracy in its own header comment: `ProfileManager` and `SoundManager` actually read/write `UserDefaults.standard` directly rather than through here — no key collision, just worth knowing before assuming this file is exhaustive.) |

`currentOrder: Order?` is an instance var on `FrontShopScene`. Currency state: `Wallet.shared.balance` (customer 냥) and `Magic.shared.points` (tailor 마력) — both singletons, read directly from any scene, no property handoff needed.

### Known gaps / in-progress state

- **📋 `GAME_VOCABULARY.md` needs a refresh — instructions for whichever session does it.** This file is gitignored/local-only (owner-local reference, never tracked in git — confirmed via `.gitignore` and git history), so it's invisible to any session running in a worktree (like this one) and can only be edited from the owner's main checkout, likely in a Cowork session per the owner's plan. Things confirmed or changed in the 2026-09-03 session that likely need reflecting there:
  - The shopkeeper has a real name, **Polaris** (폴라리스) — established in `DaphneBecomesTailorScene`, where she's explicitly Aurora's *younger* sister (she calls Aurora "언니"; Aurora calls her "나의 동생"). **Spelling normalised 2026-09-09:** the name shipped as 폴라레스 in 28 places and 폴라리스 in 2, and the two outliers were the correct ones — 폴라리스 is the standard transliteration of "Polaris" and half the deliberate Polaris/Aurora star-naming pair. All 28 were changed to match.
  - `SecondPrincessCat` = Ana (confirmed, `PrincessAnaScene.swift:124`); `FirstPrincessCat` is presumed to be Estelle (not yet confirmed by the owner, currently only used as a storybook illustration) and is slated for a Phase 7 visual reveal.
  - Estelle's fate (Phase 7, planned): fell through a portal, Alice-in-Wonderland style, into modern-day Korea — specifically Gwanghwamun Square (광화문광장). If the vocabulary doc tracks world/setting concepts, this introduces "modern-day Korea" as a place the story can reach, which is a significant departure from the fairy-tale kingdom setting. As of 2026-09-04 this is no longer a live scene tease but a storybook epilogue, unlocked once Ana solves her detective mystery.
  - **2026-09-04 additions, all still design-stage (not built) — same caveat as below, don't backfill vocabulary entries until the code lands, but the lore itself is confirmed by the owner:**
    - Polaris is characterized as a sharp, deliberate deal-maker — established via the drafted Daphne/Aurora/Polaris/Ana handoff scene, worth keeping consistent wherever she negotiates.
    - Daphne's magic is wizard-taught (under Aurora); Ana's is fairy-taught (under her godmother Flora) — explicitly two different magic traditions with two different teachers, not one system reskinned. Ana's currency/terminology not yet named by the owner.
    - World lore: the number of dungeons is canonically **unknown** — stated explicitly as intentional headroom for infinite future expansion, not an oversight. The four physical stations (fabric/sewing/buttons/mannequin) are the current shop's set, not necessarily a hard ceiling.
    - **All four royal family members may eventually become tailors** (King and Queen confirmed as future possibilities, alongside Daphne and Ana already in motion) — each tailor's minigame style is tied to their characterization (action vs. thought-driven, established so far), not assigned arbitrarily.
  - Whatever ends up documented for Phase 7's planned mechanics (Daphne's 150-마력 stomp→magic-sleep interaction — **now shipped** as the ✨ magic-light ability, so this one's actually ready to document, not a placeholder) once the rest actually get built — they don't exist yet, so don't backfill vocabulary entries for those until the code lands.
  - General pass: confirm the doc's monster/mechanic descriptions still match current code (this session found and fixed unrelated staleness in CLAUDE.md itself — e.g. `Order`'s fields were still described as `String` months after they became enums, and the Scene Flow diagram still described the pre-Phase-6a `.sks` loading a full session after that shipped — so drift of this kind is plausible here too).
- **⚠️ Remove all `#if DEBUG` triple-tap dev shortcuts before shipping.** ⚠️ **This also gates the economy calibration pass** — see "Every number in this section is provisional" under Currency & economy. The shortcuts make the real earning curve unobservable, so removing them is step 1 of tuning the game's economy, not just a hygiene item. All are `#if DEBUG`-gated (they cannot build into a release/TestFlight archive) but are flagged here as a deliberate pre-ship checklist item since they mutate real persisted state, not just a view-only cheat. **Cited by corner and behavior, not line number — the line numbers in this entry drifted twice and the diagnostics run flagged them as structurally guaranteed to recur. `grep -rn "tapCount >= 3" DesignerAna/` is the durable index; there are seven hits across six files.** (1) `SettingsScene` — triple-tap anywhere clears collected relics + relic-quest state, for re-testing the Phase 5 quest from scratch. (2) `MinigameNode` and (3) `BossMinigameNode` — triple-tap the **upper-right** of the dungeon arena instantly completes the current station/boss, added because the boss fight's two-button mechanic can't be tested on the Simulator (no simultaneous multi-touch). (4) `MinigameNode` and (5) `BossMinigameNode` — triple-tap the **upper-left**, the mirror corner, adds 마력 through the real `Magic.add(_:)` path so the level-up VFX fires exactly like a genuine reward, without grinding or reinstalling. **Phase 7b raises this grant from +50 to +250** alongside the 150/300 → 500/1000 threshold retune, so playtesting stays as fast without leaving a constant that must be reverted before shipping. (6) `StorybookScene` — triple-tap the ToC's top-right corner marks the relic quest complete via `Store.saveRelicQuestComplete()`, unlocking chapter 5's 장면 다시 보기 for story-content preview without playing the dungeons. (7) `BackRoomScene` — triple-tap the bottom-right corner, clear of the HUD, cycles `Store.saveCurrentTailor(_:)` through the roster; added so Ana's `BackRoomScene` presence and scale could be tested before the real handoff scene existed. Now that `TailorHandoffScene` ships it's a convenience rather than the only route to Ana, but it stays the fastest way to reach her without grinding to the handoff threshold — Phase 7b leans on it heavily.
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

### Phase 3 — Station minigames (shipped)
Each station (fabric cabinet, sewing station, button station, mannequin) gates progress with a Super Mario–style platformer minigame. The player navigates a small dungeon, defeats a monster, and reaches a treasure chest containing the needed item (fabric, thread, buttons, finished dress) before that station unlocks.

**Shipped:** fabric cabinet (station 1, tutorial — stationary monster, no hazards), sewing station (station 2 — pacing monster, scissor-blade hazards to jump over), button station (station 3 — pacing monster on the right side of the arena, falling-button hazards from the ceiling), mannequin station (station 4 — boss fight via `BossMinigameNode`; three telegraphed attacks, 3 HP, boss-on-chest reveal). All station-specific behavior for stations 1–3 lives in `MinigameConfig` (level seed, `MonsterBehavior`, `HazardKind`, theming); shared mechanics live in `MinigameNode`. The mannequin boss uses a sibling `BossMinigameNode` with its own bespoke attack loop.

### Phase 4 — Audio pass

Effectively complete — a full sound pass across every scene. *(Correction: this used to call itself "the v1 release gate," which was wrong — nothing has shipped. See "v1 ship gate & final sprint" after Phase 7c below for what shipping actually requires and what the current alpha-testing status really is.)*

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
- `RelicDeductionScene` (renamed from `TailorChoiceScene` 2026-09-09) — fires once from `BackRoomScene` (`presentRelicDeductionScene()`, gated on all four relics collected): cinematic relic deduction, then routes onward to `AuroraChamberScene`. **The A/B choice (Aurora vs. straight to the castle) was removed 2026-09-09** — owner call: going to Aurora first is now mandatory, since she's the one who tells Daphne she can come back once she levels up, and the old choice let a player skip that line entirely.
- `AuroraChamberScene` — Aurora the wizard mentor, riddle gate, fade transition to the final scene. Built on the shared `NarrativeHUD` (bust-up portraits + dialogue panel).
- `PrincessAnaScene` — final scene: relics handed to Ana via the orbit/float handoff animation, godmother reveal, curse story. Saves the quest-complete flag (`Store.saveRelicQuestComplete()`) on the outro. **Fixed 2026-09-05:** Ana's sprite was positioned at `-size.height * 0.15`, clipping her feet off the bottom edge — moved to `-size.height * 0.08` to match where Flora stands (`enterGodmother()`), the correct reference for this scene's adult-height characters. **Added 2026-09-06 — souvenir selfie-gift beat** (new beat 18, between the old beats 17 and 18/now-19): Ana gifts Daphne the framed `Selfie_TailorAndPrincessAna` keepsake via her own fairy magic, `animateSelfieGift()`. Deliberately a different visual language from `animateRelicHandoff`'s gold orbit-then-float (Daphne's wizard magic) and `spawnSparkles`' silver radial burst (Flora's) — uses Ana's own established emerald green (#4CB87A, her `nameColor` in this scene's `SpeakerConfig`) and, per owner direction ("think of Tinker Bell"), a continuously-spawned trailing comet tail behind the moving light rather than a static halo or one-shot burst. Direction is reversed from the relics (Ana → Daphne, not Daphne → Ana). Gated by `selfieGiftInFlight` the same way `activeRelicAnimations` gates the relic handoffs, so taps can't skip past it mid-flight.

  **Two fixes after a full owner playthrough (2026-09-06):**
  1. **"Off by one beat" dialogue timing (`animateRelicHandoff` + `animateSelfieGift`, both fixed the same way).** Both functions used to fire their target's reaction line via `hud.show(...)` at the exact moment the item *launched*, not when it *arrived* — so Ana (and, for the selfie, Ana narrating "here, take this") appeared to recognize/hand over the item before it visually reached her/Daphne. Both animations now take an `onArrival: @escaping () -> Void` closure, called from inside the action sequence right after the float (or float+trail group) completes — not at the very end of the full sequence, which still includes a settle-pause and fade-out after arrival. `advanceBeat()` was restructured around a new `showCurrentBeat()` helper: beats with an animation (2, 4, 6, 8, 18) pass `{ [weak self] in self?.showCurrentBeat() }` as the completion instead of calling `showCurrentBeat()` immediately; every other beat still shows its text immediately as before. If a future beat gets its own travel animation, follow this same pattern rather than showing text at launch.
  2. **Comet tail was "barely visible."** The first pass's trail particles reused `anaGreen` at a small radius (2–4pt) with no stroke — blended into the backdrop. Fixed the same way the 150/300 마력 level-up VFX's sparks were fixed earlier this session: a distinct, brighter trail color (not the halo's own color) — `UIColor(0.55, 0.95, 0.75)`, a light saturated mint — plus a white stroke, a bigger radius (5–9pt), a longer fade/shrink (0.6s, up from 0.4s) so more particles overlap on screen at once, and a shorter spawn interval (0.025s, up from 0.04s) for a denser trail.
- `DaphneBecomesTailorScene` — backstory cutscene (Aurora, Polaris, Daphne), reached from the storybook.
- ~~Back-room selfie keepsake (`Selfie_TailorAndPrincessAna`) appears on the wall once the quest is complete~~ — **disabled 2026-09-06.** `setupSelfieKeepsake()` still exists in `BackRoomScene` (unwired, kept as reference) but its call site is commented out. Owner decided Daphne's tailor backroom is the wrong wall for it: since the selfie is now a physical keepsake Daphne receives (via the beat above), it should follow *her*, not stay behind in Polaris's shop once she leaves to become Ana's era. **Not yet decided/built — filed away for the Daphne potion-cooking side-quest work:** the selfie should hang on the wall of wherever Daphne resumes her wizard-magic training under Aurora (the still-undesigned post-`TailorHandoffScene` scene this side quest would live in — see Phase 7's "explicitly out of scope for this phase" note). Whichever session builds that scene should re-wire `setupSelfieKeepsake()` (or a copy of it) there instead of reintroducing it in `BackRoomScene`.
- `NarrativeHUD` shared dialogue component (bust-up `Portrait_*` assets) used by all narrative scenes; storybook replay routing returns each replayed scene to the correct chapter/page.
- **Storybook spoiler veiling (added 2026-09-04):** Rose's identity/curse is a `PrincessAnaScene` reveal, so `StorybookScene` hides her ahead of it in two places until `Store.loadRelicQuestComplete()`: chapter 6's "로즈" character-bio page swaps to a "???" mystery placeholder, and chapter 4's family-portrait page overlays a "❓" badge over her (the small snail in the foreground of `RoyalFamilyPortrait.png`) via `addRoseSpoilerCover(to:)`. That badge's position is an estimated fraction of the source art, not pixel-measured — nudge the two constants in `addRoseSpoilerCover` if it drifts off her once art changes.

**Full design spec** in `RELICS.md` (gitignored — owner-local). NPC sprites (`WizardCat`, `GodmotherCat`) are xcassets-only — removed from the player-selectable carousel in the ProfileManager 11→9 reduction.

### Phase 6 — Front-shop structural refactor (shipped)

Two structural changes to `FrontShopScene`, tackled together since both touch the same scene.

**6a — SKS → programmatic layout (shipped).** `FrontShopScene` used to load its node layout from `GameScene.sks`; it now builds it in code via `setupSceneNodes()`, matching every other scene. See the "Known gaps" entry above for the anchor-point gotcha hit during the conversion.

**6b — Front-shop POV flip (shopkeeper ↔ customer, third person) — shipped.** Before this phase, the shopkeeper addressed the player directly, as if the player *is* the customer — no customer character was ever rendered on screen; `ProfileManager.shared.selectedDisplayName` only ever appeared as text in the greeting (`FrontShopScene.swift`), never as a sprite. Now the player watches a visible NPC customer interact with the shopkeeper, the same POV relationship the tailor already has with Princess Ana / the fairy godmother in the Phase 5 narrative scenes.

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

### Phase 7 — split into 7a / 7b (v1) and 7c (v2) on 2026-09-08

Phase 7 was one phase describing two eras. By 2026-09-08 everything in Daphne's half had shipped and nothing in Ana's half had started, so the phase was cut along that seam rather than carried forward as one open-ended block. **Revised later the same day:** the seam turned out not to be era-shaped. Ana needs a *playable* era and an ending in v1 — that is 7b, below — while only her puzzle-detective rework is genuinely v2 (7c). **Lanes are contiguous: 7a and 7b are v1, 7c is v2.** This is the scope reduction `ASSESSMENT.md` recommended (Lane B, item 10 — "cut Phase 7 to a shippable v1") and the owner confirmed the line on 2026-09-08: **v1 ships the protagonist swap; Ana's puzzle dungeons are v2.**

| Phase 7 item | Lane | Status |
|---|---|---|
| Ending sequencing rule (Magic ≥ 300 gated on relic quest) | 7a / v1 | shipped |
| 150 마력 magic-sleep ability | 7a / v1 | shipped |
| In-dungeon level-up VFX (150 + 300) | 7a / v1 | shipped |
| `TailorHandoffScene` (300 마력 handoff) | 7a / v1 | shipped |
| Tailor Identity **foundation** (roster, persistence, per-tailor height + style) | 7a / v1 | shipped |
| Ana as the working tailor after the handoff | 7a / v1 | shipped |
| Status HUD redesign (two panels) | 7a / v1 | shipped |
| Ana rendered as the dungeon hero, her own scale/foot-offset math | 7b / v1 | **shipped 2026-09-10** — live inconsistency resolved |
| Ana's fairy magic VFX in the dungeons (green comet tail, not Daphne's gold) | 7b / v1 | **shipped 2026-09-10** |
| Ana starts with the ✨ ability unlocked, no level-up needed | 7b / v1 | **shipped 2026-09-10** |
| Daphne threshold retune 150→500, 300→1000 | 7b / v1 | **shipped 2026-09-10** |
| 3000 마력 ending gate + free-play state | 7b / v1 | **shipped 2026-09-10** |
| Non-destructive 손님 바꾸기 (data model already shipped) | 7b / v1 | **shipped 2026-09-10** |
| Storybook restructure + mandatory opening | 7b / v1 | **shipped 2026-09-10** |
| Estelle epilogue — **the v1 final ending**, not a storybook unlock | 7b / v1 | **shipped 2026-09-10, real art** — dialogue still placeholder, see gate item 4 |
| King/Queen narrative interlude at 1500 마력 (task 8 — owner-added, not in the original sprint prompt) | 7b / v1 | **shipped 2026-09-10** — not yet on-device verified |
| Ana dungeon-scale calibration pass (she reads bigger than the boss; hazards/monsters never tuned against her size) | 7b / v1 | **⚠️ still open — see gate item 4** |
| Ana's puzzle-minigame node types (sudoku, spot-the-difference, …) | 7c / v2 | not started |
| Ana's own fairy-taught currency (name + thresholds) | 7c / v2 | not started — owner to name |
| Clue collection (relics → clues for Ana's era) | 7c / v2 | not started |
| Daphne potion-cooking side quest | 7c / v2 | not designed |
| King/Queen as playable tailors | 7c / v2 | lore only (the 1500-마력 interlude above is a narrative cameo, not this) |

**⚠️ 2026-09-10 status note, read before trusting any "shipped" row above as verified:** every Phase 7b row marked shipped above passed build + the full test suite at commit time, but almost none of it has been confirmed on a real device — this session ran almost entirely into the same simulator small-element tap-precision friction documented throughout Phase 7b and below (small UI elements specifically; large central buttons register fine). Treat "shipped" here as "code-complete and mechanically verified," not "device-confirmed," until the owner plays it through. The 30 commits that did this work are also **not yet pushed to GitHub** — see the 2026-09-10 closing handoff in `DesignerAna_handoff.md` for the exact branch state.

**The v1 reading of "Ana's quest begins," stated plainly so it isn't re-litigated:** Ana takes over the shop and is the visible working tailor, and her dungeon runs launch Daphne's platformer minigames under the hood. That is a coherent ending for v1 — the handoff scene is the payoff — and it is deliberately *not* the full "Ana plays puzzles" vision. Confirmed by the owner 2026-09-08. **Do not treat the platformer-under-Ana situation as a v1 bug**, and do not file it as one.

### Phase 7a — Daphne's arc conclusion & the tailor handoff (v1 — shipped)

Continues the Phase 5 relics-quest storyline. **All of 7a is shipped as of 2026-09-08** — the prose below was written while it was still in design and is kept because the decisions, gotchas and rejected alternatives in it are load-bearing; read "shipped" markers per-item rather than assuming the framing is still forward-looking. **Revised 2026-09-04** — the owner rescripted the back half of this phase via artifact comments on the "One Gate, Six Endings" flowchart; what follows supersedes the original separate-scenes plan below. The original six-way naming and the collision it was solving are kept here as context since the *rule* it produced is still load-bearing.

**Ending sequencing (locked, 2026-09-03; content revised 2026-09-04).** Two systems compete for the same moment — a dungeon order finishing and the player returning to the shop: the relics quest (Ending 1, shipped) and Daphne's Magic-point thresholds. The locked rule: **the Magic ≥ 300 chain may only fire once `Store.loadRelicQuestComplete() == true`.** If `Magic.points` crosses 300 before the relics quest resolves, it just stays dormant, rechecked on every subsequent order completion — same mechanism already planned for "wait until no order is in progress," just with one more condition. This isn't only a UI-collision fix: it's a narrative-causality requirement, since everything past this gate assumes Daphne has already found and delivered all of Estelle's relics before her own "graduation" arc begins. The 150-마력 ability unlock stays independent of this whole gate — it's a passive unlock with no scene, checked on every dungeon load, nothing competes with it for screen time.

**Dialogue bug found + fixed (2026-09-06):** the dormant-gate case above has a narrative side effect the gate rule itself doesn't cover — `AuroraChamberScene` (part of the relics-quest completion chain, fires *before* `Store.saveRelicQuestComplete()` is set in `PrincessAnaScene`'s outro) has Aurora comment on the tailor's current 마력 total and, unconditionally, tell Daphne to "come back once you're stronger" (좀 더 강해지면 공부를 마치러 돌아오렴). If the player reached 300 마력 *before* finishing the relics quest, that line is contradicted almost immediately — the 300 handoff chain unblocks and fires on the very next order completion once this scene's chain ends. Fixed with a one-off branch on `Magic.shared.points >= 300` in `didMove(to:)`: at ≥300 the closing clause swaps to an acknowledging line ("이미 충분히 강해졌구나. 곧 다시 만나게 될 것 같은 예감이 드는구나") instead of the "not ready yet" one. Deliberately scoped narrow — a single branch on this one line, not a broader multi-tier dialogue system — per the owner's explicit call to stop scope-creeping polish here: three bigger items (Ana's puzzle-minigame dungeons, the JSON educational-content ship-gate item, plus the not-yet-scoped Estelle epilogue and a mentioned Daphne potion-cooking side quest) are still ahead of this for shipping.

**150 마력 — Daphne levels up.** Her dungeon-minigame defeat interaction changes from a stomp jump to a magic-based "put to sleep" action — pays off the Fairy Godmother's existing lore in `PrincessAnaScene` (beat 12) that defeating a monster only puts it to sleep, doesn't harm it. **Shipped** as the ✨ magic-light ability (`MinigameNode`/`BossMinigameNode`). **Confirmed needed by a fresh-install device playtest (2026-09-05):** from a new player's perspective, nothing signals that Daphne has leveled up at 150 — the ability just becomes available with no visible moment marking the threshold.

**In-dungeon level-up VFX — shipped 2026-09-06, both thresholds** *(⚠️ the numbers 150 and 300 throughout this block become **500** and **1000** in Phase 7b — they were testing conveniences. The VFX itself, its two sizes, and the `handleLevelUp(_:)` dispatch are unaffected; only the trigger points move.)* (`playLevelUpVFX(at:threshold:)` in both `MinigameNode.swift`/`BossMinigameNode.swift`, duplicated per this codebase's existing convention for these two sibling classes; the 150 pass referenced the sample in `_ReferenceSamples/level_up.jpg` plus a Pinterest reference board, both reviewed with the owner first). `Magic.add(_:)` returns `MagicLevelUpThreshold?` (`.levelOne` = 150, `.levelTwo` = 300, `nil` if neither was crossed by that call) instead of a plain `Bool` — a single call can only ever cross one threshold, since real reward sizes (≤50) can't jump the 150-point gap between them. All 4 real reward call sites (paw pickup + chest reward, both files) plus both debug shortcuts route through one `handleLevelUp(_:)` dispatcher per file: `.levelOne` plays the small VFX and pops the ✨ ability button in live (with a little overshoot); `.levelTwo` plays a bigger VFX only — the button is already unlocked, so 300 doesn't re-trigger it. Composition, confirmed correct on-device after two rounds of owner feedback on the 150 pass: a **straight** gold light pillar (not a cone — a fanned/coned shape was tried first, matching an earlier HTML mockup, but read oddly once tested against Daphne's actual sprite standing in it, so it was reverted to a straight beam), half-width 26pt (34pt for 300) rising from a `heroFootOffset` of 42pt below `hero.position` (her sprite's center — 22, half her physics-body height, landed at her knees on device and was increased; still an estimate, no documented padding value for the hero sprite the way Monster/Boss/BossAdd have), plus a ground ring that grows in sync with the pillar's rise (120×30pt at 150, 170×40pt at 300 — widened proportionally *more* than the pillar itself, not just matched to it) and rising gold sparks (8 at 150, 14 at 300, rising further and taking longer to fully fade). The 300 version scales up the whole composition — taller pillar (220pt vs 140pt), longer rise (0.6s vs 0.4s) and hold (1.0s vs 0.5s) — same shape, bigger and slower, not a new design. Gold-only palette, matching Daphne's wizard-magic-is-yellow rule (see `MAGIC.md`). The pre-existing `#if DEBUG` triple-tap shortcut (upper-left of the dungeon arena, mirroring the pre-existing upper-right instant-complete shortcut) adds 50 마력 through the real `Magic.add(_:)` path — same shortcut serves both thresholds now, no new one needed. Still open: the Tailor Status HUD's own ✨ level-up indicator (a separate, not-yet-built piece — see Status HUD redesign below).

**Confirmed via device playtest (2026-09-06):** both thresholds fire correctly via the debug shortcut. **Sparkle visibility fix (same session):** the rising sparks originally used the same `levelUpGold` fill as the pillar/ring, so they nearly disappeared against those same-hued semi-transparent shapes — owner feedback: "the sparkle is relatively less visible." Fixed with a distinct `levelUpSparkColor` (a near-white warm gold, `#FFF7D9`-ish) plus a white stroke, a larger radius (3–6pt at 150, 4–7pt at 300, up from 2–4pt), and a quick scale-up pop-in (0.3→1.0 over 0.15s) so each spark reads as a distinct twinkle rather than a same-colored dot blending into the pillar behind it.

**300 마력 — the handoff scene (rescripted 2026-09-04, replaces the old separate Wizard's-Chamber/Farewell/Ana-visits beats).** **Shipped** as `TailorHandoffScene.swift`, gated in `FrontShopScene.handleSaveTrophy()` — deliberately *not* in `BackRoomScene`, and deliberately *after* the wardrobe save (`Magic.shared.points >= 300 && Store.loadRelicQuestComplete() && !Store.loadTailorHandoffShown() && Store.loadCurrentTailor() == Tailor.defaultID`, mirroring the relic-deduction gate's one-shot pattern with its own `tailor.handoffShown` flag). Firing before the save (the first cut of this) let the handoff dialogue conclude with Ana established as tailor and *then* show the trophy — reading as if Ana finished a dress she never touched. The correct sequence is save → dialogue → new customer. One merged narrative scene, reusing `DaphneBecomesTailorScene`'s exact format — three speakers in Act 1 (Aurora fixed on the `left` `NarrativeHUD` slot; Polaris and Daphne *share* the `right` slot, swapped via `hideSpeaker`/`revealSpeaker` depending on who's part of the active exchange), then Ana takes over Aurora's vacated `left` slot for Act 2 once Aurora+Daphne teleport out. **`NarrativeHUD` has only two portrait slots, left and right — never a third centered portrait** (a bust covering the middle of the scene reads badly); the first cut of this scene used a since-removed `centerElevated` slot by mistake, following a stale comment on `DaphneBecomesTailorScene` that described that same abandoned idea rather than the shared-slot pattern it actually ships with — both the dead slot and the stale comments are now cleaned up. The Korean dialogue below was drafted as beats (story outline, reviewed 2026-09-04); the actual scripted lines were authored during implementation and haven't had a separate owner pass yet — worth a read-through. Beats implemented:
1. Aurora acknowledges Daphne has leveled up well.
2. Polaris thanks Daphne for her good customer service.
3. Daphne asks if she can return to her original position (apprentice under Aurora).
4. Aurora agrees and teleports herself and Daphne out of Polaris's shop.
5. Polaris bids them farewell, then wonders to herself what to do about the now-untended, monster-infested dungeon.
6. Princess Ana visits.
7. Polaris greets her with surprise, asking if she's really here to place an order herself rather than send a servant.
8. Ana explains she's here about her young friend Daphne, and about her own missing sister, Princess Estelle.
9. Polaris explains Daphne returned to her wizarding studies, leaving the shop without a tailor who can handle the dungeon.
10. Ana offers her own magical ability — taught by her fairy godmother Flora — in exchange for full access to the dungeon to search for Estelle.
11. Polaris agrees, reading it as a good business deal. (Polaris is characterized as a sharp deal-maker generally — keep this trait consistent wherever she negotiates.)

**Confirmed via fresh-install device playtest (2026-09-05):** the gate/sequencing/HUD fixes above all hold up on real hardware — handoff scene didn't appear until 300 마력 was actually reached, trophy saved before the dialogue played, no second trophy prompt, straight to the customer picker, Ana confirmed as the working tailor once a new order is placed. One gap noted from a new player's perspective: nothing marks 300 마력 as a threshold *before* the handoff scene explains it after the fact — a bigger visual level-up effect the instant the counter crosses 300 (parallel to the 150-마력 VFX above) was suggested. **Now shipped** as part of the 300-마력 in-dungeon level-up VFX above (same commit as the 150 VFX's `handleLevelUp` refactor) — not yet confirmed on real hardware.

End of scene triggers the existing customer-picker handoff — **shipped**, `TailorHandoffScene.startOutro()` calls `Store.saveCurrentTailor("ana")` then presents `SettingsScene(isFirstLaunchPicker: true)` directly (the trophy was already saved and the picker shown before this scene ever launched, so there's nothing left to re-forward — no `completedOrder`/`shouldShowFinishedGarment` round-trip through a fresh `FrontShopScene` the way `PrincessAnaScene`'s outro needs). Once the new customer places an order and the player proceeds to the back room, **Ana is there as the working tailor** — not a story beat layered on top of Daphne still being the protagonist (as originally planned), but an actual protagonist swap for her era. `BackRoomScene.setupTailor()` already read `Store.loadCurrentTailor()` before this session (from the Tailor Identity foundation commit); the handoff scene is what actually flips it via real gameplay instead of only the `#if DEBUG` triple-tap-cycle shortcut (`BackRoomScene.swift`, still present for testing — cycles the roster without needing to grind to 300 마력).

**Tailor Identity system (model-layer concept, designed 2026-09-04 — foundation shipped, some pieces still open).** `TailorIdentity.swift` exists: a roster type (mirrors `ProfileManager.avatars`) with `daphne` and `ana`, keyed by stable string id, with `Store.loadCurrentTailor()` / `saveCurrentTailor(_:)` persistence. **The owner confirmed all four royal family members may eventually become tailors** (King and Queen too, per world lore that the number of dungeons is canonically unknown — this game is built to keep expanding), so the roster must stay extensible, not hardcoded to two — current shape supports that. Each tailor entry carries: display name, sprite asset, a per-tailor `renderedHeight` (in points — Daphne renders at 70% of Ana's height for a shorter, chibi/younger look; Ana's height is the preserved reference since it already read correctly against the back room's furniture), and their own minigame style. Not yet built, and **moved to Phase 7c / v2 on 2026-09-08**: Ana's own magic-point currency (in v1 she shares `Magic.shared`/마력 outright — see Currency & economy — though narratively she has her own fairy-taught magic per the lore below) and the puzzle-minigame node types. The bullets that follow are 7c design notes retained here for context — the foundation they describe is what shipped in 7a, and Phase 7b is what makes it actually playable.
- **Minigame style is keyed to the tailor's characterization, not a global setting.** Daphne is action-driven → the existing Mario-style platformers (`MinigameNode`/`BossMinigameNode`), unchanged. Ana is thoughts-driven → puzzle games (sudoku, spot-the-difference, crossword, etc. — new node types, not yet built). Confirmed explicitly **not retroactive**: Daphne's four stations stay platformers; only Ana's dungeon runs use puzzles.
- **Physical structure stays completely fixed regardless of which tailor is active** — same four station locations (fabric cabinet, sewing station, button station, mannequin), same firefly unlock effect, same dungeon-entrance flow in `BackRoomScene`. Only which minigame class launches at each station changes. Deliberate choice for the 8-year-old audience: change content and mechanics, never the spatial/navigational conventions they've already learned.
- **Clue collection (Ana's era) reuses the relic-collection mechanic exactly** — same 4-slot HUD row, same collection animation (scale pop + sparkle burst + arc to slot), same sounds, same safety-net auto-pull. Only the icon/name changes (relics → clues); not a new mechanic. This directly answered the "is the dungeon count now unbounded" question raised by the lore detail above — it isn't a blocker, since the collection UI stays a fixed 4 slots per era regardless of how many dungeons might exist someday.
- **Magic currencies are per-tailor, not shared.** Daphne's is wizard-taught magic (🐾 마력, `Magic.shared` — unchanged, still hers specifically, not generalized). Ana's magic is fairy-taught (from godmother Flora) and needs **its own separate currency/name and its own level-up thresholds** — explicitly not reusing 마력's numbers or Korean terminology. Not yet named or numbered; owner to decide, not to be invented here.
- Sprite asset for Ana-as-tailor not yet chosen — `SecondPrincessCat` is already used for her in `PrincessAnaScene` at a specific tuned scale; reusing it in `BackRoomScene` needs the same scale-matching care documented in Phase 6b's gotchas above. King/Queen sprites already exist (`KingCat.imageset`, `QueenCat.imageset`, currently storybook-illustration-only) if that roster entry is ever built out.

**Status HUD redesign (artifact comment, 2026-09-04 — shipped 2026-09-06).** Restructures `BackRoomScene`'s HUD into two translucent grouped panels instead of loose individual elements, directly motivated by needing to represent *whichever* tailor/customer is currently active. See the "Back room HUD layout convention" section above for the full shipped implementation, gotchas, and what's still unverified (the ✨ badge's live mid-run appearance — not yet confirmed on-device). Original spec, largely as shipped:
- **Tailor Status HUD** (top-left, translucent so the back room stays visible underneath): wraps the magic-point HUD and the relic/clue HUD into one panel; adds a new **level-up indicator** in the same visual style but with ✨ instead of 🐾 — flashes a few times the first time it appears (i.e., the first time `Magic.points` crosses 150) to draw attention; displays the current tailor's name. Shipped with one deviation from spec: the badge sits *beside* the 🐾 bubble, not literally *between* it and the relic row — not enough vertical room without a riskier cross-file layout change (see above).
- **Customer Status HUD** (top-right, same panel style): wraps the wallet HUD; displays the current customer's name and the ordered garment's type + color.
- 그만할래 is explicitly called out as independent of both HUDs and needs its own placement, not nested inside either panel. Shipped as specced.
- Owner flagged a fallback if either panel reads as too crowded after testing: collapse it into a dropdown-style menu instead of an always-open panel. Not needed yet — first on-device look (pending) will tell.

### Phase 7b — Ana's era & the ending (v1 — shipped 2026-09-10, prose below kept for its reasoning)

**This is the "ending sprint," decided 2026-09-08 and executed 2026-09-10 in a single Claude Code session.** 7a shipped the *handoff* — Ana takes over the shop and `BackRoomScene` renders her. This phase made her era actually playable and gave the game an ending. **All numbered items below (1–10) are shipped** — the prose was written while still in design and is kept because the decisions, gotchas, and rejected alternatives in it are load-bearing, the same convention Phase 7a's header above uses; read the ✅/status markers per item rather than the surrounding framing. **Two things this phase's sprint prompt did not originally cover, both handled the same session:** an owner-added King/Queen narrative interlude (item 11, new), and **the Ana dungeon-scale calibration pass remains genuinely open** — see item 11a and gate item 4 below, and do not confuse the vertical-position bugfixes this sprint made (foot-sink, projectile hitboxes, halo width) with that still-open, different problem.

**⚠️ The live inconsistency this phase was written to fix is now resolved.** `Store.loadCurrentTailor()` used to be read in exactly one gameplay place (`BackRoomScene`) while `MinigameNode`/`BossMinigameNode` hardcoded Daphne's sprite — so a player in Ana's era saw her in the back room and Daphne in every dungeon. **Fixed 2026-09-10** (item 1 below) — both files now route through `Tailor.identity(for:)`.

**1. Ana as the dungeon hero.** ✅ **Shipped 2026-09-10 (`8274e77`).** Route the hero sprite through `Tailor.identity(for: Store.loadCurrentTailor())` in both minigame files instead of the hardcoded asset name. ⚠️ **This drags in retuning, not just a string swap:** `footOffset = 40` (`MinigameNode:806`, `BossMinigameNode:1269`) and `heroFootOffset = 42` (`MinigameNode:1396`, `BossMinigameNode:1544`) are both commented "retune when Tailor sprite changes," and Ana renders taller than Daphne (Daphne is 70% of Ana's `renderedHeight` — see the Tailor Identity notes in 7a). Expect to derive both offsets from the identity's height rather than leaving them as literals. The transparent-padding rule in "Sprite PNG transparent-padding rule" above applies, and there is still no documented padding value for the hero sprite the way Monster/Boss/BossAdd have — measure it on device.

**2. Ana starts with the ✨ ability already unlocked.** ✅ **Shipped 2026-09-10 (`8274e77`).** No level-up gate in her era: she arrives from `PrincessAnaScene` with fairy-taught magic she already knows how to use. Today the gate is a bare literal, `guard Magic.shared.points >= 150` — and **there are three of them, not two**: `MinigameNode:551` and `BossMinigameNode:421` (the ability gate), plus `BackRoomScene:442` (the ✨ level-up badge in the Tailor Status HUD). The third was found 2026-09-09; the first draft of the sprint prompt named only the first two, which would have left Ana's HUD badge following Daphne's threshold and silently changed when it appears once item 5's retune lands. Use `grep -rn "points >= 150" DesignerAna/` as the index rather than these line numbers. Gate on **tailor identity**, not incidentally on her starting point total — she happens to start at 1000 and would pass the numeric check anyway, but relying on that is the kind of accidental correctness that breaks the moment a number moves.

**3. Her magic looks like *hers*.** ✅ **Shipped 2026-09-10 (`8274e77`).** The mechanic is unchanged — small monsters are defeated, the boss falls asleep and must then be stomped to be defeated — but the visual language is Ana's fairy magic, not Daphne's wizard gold. **Do not invent a new effect: the recipe already exists and is device-proven.** `PrincessAnaScene.animateSelfieGift()` has Ana's continuously-spawned trailing comet tail — her emerald `#4CB87A` for the light itself, a brighter mint `UIColor(0.55, 0.95, 0.75)` for the trail particles with a white stroke, radius 5–9pt, 0.6s fade/shrink, 0.025s spawn interval. Port that, per the "think of Tinker Bell" direction. This also means the gold-only palette rule in `MAGIC.md` is now **per tailor**, not global: Daphne's magic is yellow, Ana's is green. Update `MAGIC.md` when this lands.

**4. Relics in Ana's Status HUD.** ✅ **Verified 2026-09-10, no code needed.** She should show all four, since Daphne hands them to her in `PrincessAnaScene` — confirmed by reading `BackRoomScene`'s relic HUD setup/update functions: no tailor-conditional logic exists at all, so this already worked before the sprint started.

**5. Magic thresholds retuned — 150/300 were testing conveniences.** ✅ **Shipped 2026-09-10 (`88ff1a6`).** They were picked to make the level-up chain reachable in a short playtest, not as a real progression curve. Ship values: **`levelOne` 150 → 500, `levelTwo` 300 → 1000** in `MagicLevelUpThreshold` (`Model/Magic.swift`). **Decided 2026-09-08: change them now, not before shipping.** The alternative — keep 150/300 for testing convenience and revert at the end — puts "change two constants back" on the same pre-ship checklist that has carried "remove the `#if DEBUG` triple-tap shortcuts" for months, and that is how a debug build reaches the App Store. Instead, **raise the debug shortcut's grant from +50 to +250 마력** so playtesting stays exactly as fast with nothing to revert. The shortcut is `#if DEBUG`-gated and so cannot ship by accident; a mis-set constant can.

⚠️ Two knock-on effects of the retune, both in `Magic.swift`:
- `add(_:)`'s doc comment reasons that "real reward sizes (≤50) can't jump the 150-point gap" between thresholds. At 500/1000 the gap is 500 — the reasoning still holds, but the comment names the old numbers and must be updated or it becomes exactly the kind of stale doc this project keeps finding.
- The type's own comment calls these "Daphne's two hand-picked wizard-apprentice growth thresholds." That stays true — they remain Daphne's — but Ana's era now also runs on `Magic.shared`, so say so explicitly.

**6. Ana's progression: 1000 → 3000, continuous.** ✅ **Shipped 2026-09-10 (`88ff1a6`)** — `Magic.hasReachedEnding(points:tailorID:)` added, tested, and (once item 7 below existed to gate) wired into `FrontShopScene.handleSaveTrophy()`. Ana does not get a separate currency in v1 — she keeps accumulating `Magic.shared`, picking up where Daphne's arc ended. With Daphne's `levelTwo` handoff at 1000, the counter simply continues: Daphne 0→1000, handoff, Ana 1000→3000. No reset, no migration, one counter. (Her own fairy-taught currency with its own name and numbers stays 7c — see the Tailor Identity notes in 7a. This is the pragmatic v1 shortcut, deliberately taken.)

⚠️ **The 3000 gate cannot use `MagicLevelUpThreshold`.** `Magic.add(_:)` returns a threshold only when a call *crosses* it, and Ana starts at 1000 — already past both. Check `Magic.shared.points >= 3000` directly at the gate site instead.

**7. The ending — Estelle's epilogue.** ✅ **Built and wired 2026-09-10 (`962794e`, `7b44d9d`), real art 2026-09-10 (`e39930b`). ⚠️ Dialogue is still placeholder — see gate item 4.** Fires **after the wardrobe save**, gated in `FrontShopScene.handleSaveTrophy()`, mirroring `TailorHandoffScene`'s one-shot pattern with its own persisted flag. The sequence is save → epilogue → game complete, for exactly the reason 7a records for the handoff: firing before the save let the dialogue conclude and *then* show the trophy, reading as if the tailor finished a dress she never touched.

**Designed 2026-09-09 — no longer a stub.** The owner designed the scene in a Cowork session; the full beat spec lives in `_Prompts/EndingSprint_prompt.md` task 7. Shape:

- **Format:** a `NarrativeHUD` dialogue scene, same as every other narrative scene. `TailorHandoffScene` is the closest model. ⚠️ It changes backdrop **twice**, which no existing scene does — that seam needs deliberate handling.
- **Act 1 — Ana's hideout** (new backdrop, Ana's transmorphed dungeon room; the dungeon reshaped itself to fit its new tailor). Her magic peaks, a portal opens, and she glimpses Estelle alive somewhere impossible. She calls out; Estelle does not hear. **The portal is a window, not a door** — Ana cannot follow, and the scene leaves her behind.
- **Act 2 — 경복궁** (new backdrop). **POV shifts to Estelle and does not shift back.** She is **human now**, in her medieval princess dress, believing she has found a palace like home. A palace guard asks for her ticket; she has none and does not understand the question. He explains that visitors in 한복 enter free, hers is not 한복, and escorts her out.
- **Act 3 — 광화문광장** (new backdrop). Put out onto the square, she starts sketching the cars and crowds — the callback to her storybook profile, which has her carrying far more art supplies than she needs. **Closing image: behind her, unseen, a small snail slides slowly out of frame.** `SnailPet_Rose`, no dialogue, no highlight, no camera move. An attentive child notices; nobody is told.
- **The ending is a tease, not a resolution** (owner's call). The child learns Estelle is alive and where. Rose, the curse and any rescue stay 7c. No reunion, no curse explanation, and Estelle does not recognise Rose.

**Two worldbuilding rules this scene establishes, neither of them yet in `GAME_VOCABULARY.md`:**
1. **Everyone in the kingdom is a cat; crossing over makes you human.** This is why Estelle is human on the other side.
2. **Outside the kingdom the curse has no hold**, which is why Rose is a snail again rather than the dungeon yarn monster. One rule doing both jobs.

**Five new assets are needed and none exist yet** — backdrops for Ana's transmorphed dungeon, 경복궁 and 광화문광장, plus full-body and bust-up art for human Estelle and the guard. `SnailPet_Rose` and `Portrait_Ana` already exist. The sprint is sequenced so every other task lands first and this scene is built last against named assets, with flat placeholders if art is still outstanding — it must not block.

**This supersedes the 2026-09-04 decision** that made Estelle's reveal a storybook epilogue unlocked once Ana solves her detective mystery. That framing made the ending depend on the entire puzzle-dungeon system (7c) and so pushed it out of v1 entirely. As of 2026-09-08 it is the **final ending scene of v1**, reached at 3000 마력. The storybook-unlock idea is not dead — it is a reasonable v2 *replay* route once 7c exists — but it is no longer what gates the ending. Core content is unchanged — Estelle fell through a portal, Alice-in-Wonderland style, into modern-day Korea, specifically Gwanghwamun Square (광화문광장) — but it is now a designed three-act scene rather than a one-line premise; see above. Note the `FirstPrincessCat` asset **is not** what the scene uses: Estelle is human on that side of the portal, so she needs her own new art.

**9. Non-destructive customer switching.** ✅ **Shipped 2026-09-10 (`1963536`), on-device verified.** Free play needs this, and it is smaller than it looks: **per-customer wallet and wardrobe already ship** (`7b2d173`, 2026-09-04 — see Currency & economy). The data model is done and correct. What is missing is a way to reach it. Today the only route to another customer is 새 손님, which calls `Store.resetCustomerSide()` *first* — so a child who switches from Chef Cat to Hunter Cat loses Chef Cat's trophies before she ever gets to Hunter Cat, and coming back finds an empty wardrobe.

Add a **손님 바꾸기** button to `SettingsScene` beside 새 손님, calling the picker with no reset. `FrontShopScene.transitionToCustomerHandoff()` already does exactly this (`isFirstLaunchPicker = true`, no reset) for the post-relics-quest handoff — reuse that path rather than writing a new one.

⚠️ Three things that are actual design work, unlike the button:
- **The picker opens on avatar index 0**, not on the current customer. A child switching away and back should see her own cat highlighted. Sync `ProfileManager.selectedIndex` from `Store.loadSelectedCustomer()` before presenting.
- **`order.active` is NOT per-customer** — it is a flat key. Switch mid-order and the new customer inherits the previous one's in-progress order. **Decided 2026-09-09: block, do not clear.** 손님 바꾸기 renders dimmed and inert while an order is live, with a short reason line beneath it (`주문을 끝내면 바꿀 수 있어요.`, wording to confirm) — matching how the carousel arrows already dim at alpha 0.35 rather than disappearing, so the screen keeps its shape between visits.
- **새 손님's meaning gets murky** once switching exists. Its confirmation reads 지금까지 모은 옷과 냥은 사라져요 — accurate for the *current* customer's slot (confirmed by reading `resetCustomerSide()`, which clears only that slot plus the active order and the selected-customer flag), but it reads as "everything." **Owner-approved copy, decided 2026-09-09** — the destructive button is renamed so it says what it does, and the pair is verb-shaped and parallel:

  | Element | Copy |
  |---|---|
  | Switch button | `손님 바꾸기` |
  | Destructive button (was `새 손님`) | `이 손님 처음부터` |
  | Confirm title | `이 손님을 처음부터 다시 시작할까요?` |
  | Line 1 | `이 손님이 모은 옷과 냥이 모두 사라져요.` |
  | Line 2 | `다른 손님들의 것은 그대로 남아요.` |
  | Line 3 | `(재봉사의 마력과 이야기책도 그대로예요.)` |
  | Confirm | `예, 처음부터 할래요` |
  | Cancel | `아니요, 취소` |

  ⚠️ **Line 3 also fixes a live typo.** The shipped string at `SettingsScene.swift:302` reads **재단사**의 마력 — the only occurrence of 재단사 anywhere in the codebase, against roughly sixty uses of 재봉사, and it is player-facing. Found 2026-09-09.

**8. Free play after the ending.** ✅ **Shipped 2026-09-10 (`e504ba4` built the badge ahead of its trigger; `962794e` wired the trigger via the epilogue's outro).** The game is over, and the player can keep running the loop — select customer → place order → make garment → save trophy — **without accruing more 마력**. Needs a persisted "game complete" flag; the cleanest seam is an early return in `Magic.add(_:)` so a single place stops accrual rather than every call site learning about the end state. **Decided 2026-09-09: the HUD keeps showing the final total and gains a completion mark.** Reuse the existing ✨ level-up badge's visual style and placement approach in `BackRoomScene` (`levelUpBadgeNode`, around line 442) rather than inventing a second badge idiom — the panel already has a convention for exactly this. Glyph is the owner's call; 👑 is the suggestion. **Do not replace the number** — she earned it. Confirm the dungeons, relic row and trophy flow all still behave with `Magic` static, and that neither the level-up VFX nor the ✨ badge re-fires.

**10. Storybook restructure, and the opening scene becomes mandatory.** ✅ **Shipped 2026-09-10 (`d184483`), on-device verified for the lock/unlock states and the automatic first-play opening.** Added 2026-09-09, after the code was actually inspected. Not in any earlier version of this phase.

The game's story scenes have three different homes and one has none. `DaphneBecomesTailorScene` — the opening, how Daphne was hired — is an **action button on a lore page** (chapter 4 `묘한 옷공방과 던전`, index 3, page 0). `TailorChoiceScene` / `AuroraChamberScene` / `PrincessAnaScene` are replay buttons in chapter 5 (`장면 다시 보기`, index 4). **`TailorHandoffScene` has no storybook entry at all** — a gap that predates this sprint. The epilogue has nowhere to go.

And **the opening is entirely optional.** `TitleScene` locks `바로 시작하기` behind `Store.loadHasOpenedStorybook()`, but "opened" only means the child tapped `이야기 소개` once — she can start playing having never learned why the shop needs a tailor.

- **One story chapter, in narrative order.** Chapter 5 is replaced by a single chapter holding: opening → `재봉사의 선택` → `마법사 오로라의 방` → `아나 공주의 비밀` → `TailorHandoffScene` (new entry) → the epilogue. The `actionButtonLabel`/`actionSceneName` pair comes off chapter 4's `재봉사 가게` page (`StorybookScene.swift:214–215`); the lore page itself stays. Chapter title is the owner's call — `장면 다시 보기` no longer fits once one of these is required viewing.
- ⚠️ **Page indices shift and existing routing depends on them.** The three replay scenes carry `replayReturnPage` 0/1/2 with `replayReturnChapter = 4`; inserting the opening at index 0 makes them 1/2/3. `DaphneBecomesTailorScene` defaults to `returnChapterIndex = 3, returnPageIndex = 0` and needs both updated. This is the most likely place for the task to break quietly.
- **Unreached scenes render locked and unnamed** — greyed, 🔒, `???` title, no play button. She sees more story exists without learning what it is. Follows the precedent of the veiled `???` mystery character already in the cast chapter. Per-page unlock conditions should reuse existing flags (`loadRelicQuestComplete()`, `loadTailorHandoffShown()`, the new game-complete flag, a new opening-shown flag) wherever possible.
- **The opening plays automatically on first launch**, after the customer picker and before the front shop — she chooses her cat, then learns why the shop needs a tailor, then starts. `DaphneBecomesTailorScene` currently *always* returns to `StorybookScene`; it needs an explicit second exit mode rather than one inferred from its return indices. One-shot flag so it never auto-plays again; rewatchable from the storybook forever.
- `TitleScene`'s existing 🔒 lock stays — it gates a different moment and the two compose (title → 이야기 소개 → 바로 시작하기 → picker → opening → shop). Worth confirming on device that it does not read as two gates in a row to a child.

**11. King/Queen narrative interlude at 1500 마력.** ✅ **Shipped 2026-09-10 (`34f280e`, `a0be666`). Owner-added mid-sprint — not in the original `_Prompts/EndingSprint_prompt.md`, so this item exists only here.** A small domestic-beat scene in Ana's bedroom (`KingQueenScene.swift`, reuses `PrincessAna_Room`): the King and Queen notice both daughters have quietly drifted away and neither has explained why. Ana and Estelle do not appear on screen. Dialogue is owner-provided verbatim (12 beats, alternating 왕비/왕) — **not** a placeholder gap the way items 7's epilogue or `TailorHandoffScene`'s lines are.

Gated in `FrontShopScene.handleSaveTrophy()` between the tailor-handoff gate (1000 마력) and the ending gate (3000 마력) — checked on every trophy save rather than at the moment 1500 is crossed, satisfying the owner's spec that it must still fire if crossed mid-dungeon. `Portrait_King`/`Portrait_Queen` real art shipped in the same commit, the last two placeholder portraits in the game now real. Inserted into the unified story chapter as page 5, shifting the epilogue to page 6 — `storyChapterPageUnlocked(_:)` and its test coverage both updated.

**Not yet on-device verified** — hit the same simulator small-element tap friction as the rest of this sprint (see the status note on the Phase 7 table above).

**11a. ⚠️ Ana dungeon-scale calibration — still open, not part of this sprint.** Raised by the owner during this session's device-test feedback rounds, *before* the ending sprint's remaining tasks were executed: "Princess Ana in the dungeon is too big relative to the hazards and monsters. In fact, she's even bigger than the boss... the dungeons were never calibrated to Ana in the first place." Explicitly deferred by the owner to its own dedicated pass, not bundled into this sprint. **Do not confuse this with item 1 above** — item 1's `TailorIdentity`-routing work and this session's foot-sink/projectile-hitbox/halo-width fixes all touched Ana's *vertical positioning* (where her feet land, where hazards register against her), which is now correct; her *scale relative to hazards, monsters, and the boss* is a separate, still-untouched problem. The progress tracker's 100%-reached-at-3000-with-no-recalibration issue (`ProgressTrackerHUD`, see "Known gaps" and the 2026-09-10 handoff) is also explicitly filed under this same future pass, per the owner's own words.

### Phase 7c — Ana's puzzle-detective era (v2 — not started)

Everything in this section is design, not code. **Nothing here blocks v1.** It all depends on the Tailor Identity foundation shipped in 7a and extended in 7b, which was deliberately built extensible (string-keyed roster, per-tailor sprite/height/minigame-style) for exactly this.

**Not yet built, in dependency order:**

1. **Ana's currency.** Fairy-taught (from godmother Flora), with its own name and its own level-up thresholds — explicitly *not* reusing 마력's numbers or Korean terminology. In code she still shares `Magic.shared` today. **This is an owner decision and must not be invented by a session.** Everything below reads better once it is named.
2. **Puzzle-minigame node types** — sudoku, spot-the-difference, crossword, etc. New classes, *not* copies of `MinigameNode`/`BossMinigameNode`: a sudoku needs no jump physics and no D-pad (this is why the diagnostics run downgraded the duplication-extraction urgency — the argument for it assumed these would be copies, and they won't be). Physical dungeon structure stays fixed: same four stations, same firefly unlock, same entrance flow — only *which minigame class launches* changes. Deliberate, for the 8-year-old audience: change content and mechanics, never the spatial conventions they have already learned. **The owner has asked for TDD here specifically** — write the puzzle-logic tests first, and shape that logic as pure functions/types from the start rather than SKScene-embedded, which is exactly what makes the existing platformers hard to retrofit tests onto now.
3. **Clue collection** — reuses the relic mechanic exactly: same 4-slot HUD row, same collection animation (scale pop + sparkle burst + arc to slot), same sounds, same safety-net auto-pull. Only icon and name change. The 4 slots stay fixed per era regardless of how many dungeons the world lore might eventually allow.
4. **Ana-as-tailor sprite** — not yet chosen. `SecondPrincessCat` is already used for her in `PrincessAnaScene` at a tuned scale, so reusing it in `BackRoomScene` needs the same scale-matching care documented in Phase 6b's gotchas.
5. ~~**Estelle storybook epilogue**~~ — **moved to v1 on 2026-09-08; see 7b item 7.** It is now the final ending scene, reached at 3000 마력, rather than a storybook unlock gated on the detective mystery. What could still belong here in v2 is a *replay* route through the storybook once 1–4 exist.

**Estelle reveal — ⚠️ superseded 2026-09-08, kept for the history.** (Reframed 2026-09-04 from a live in-scene tease to a storybook epilogue; that framing is what 7b item 7 replaced, because it made the ending depend on the whole puzzle-dungeon system and so pushed it out of v1.) Still: Estelle fell through a portal, Alice-in-Wonderland style, into modern-day Korea, specifically Gwanghwamun Square (광화문광장), likely using the currently-unused `FirstPrincessCat` asset. What changed: this is no longer a scene that plays automatically — it becomes **an epilogue watchable in the storybook**, unlocked once Ana successfully solves her mystery as a detective (exact completion condition — how many clue-dungeons, which ones — not yet speced, depends on the Tailor Identity / puzzle-dungeon work above landing first).

**Also deferred here (was "explicitly out of scope for this phase"):** a side-quest arc for Daphne as Aurora's redeemed apprentice, post-departure — mentioned 2026-09-06 as specifically a **potion-cooking** side quest, not designed further than the name — and building out King/Queen as playable tailors. Both are confirmed future lore. **Filed away for whenever the side quest is built:** the selfie keepsake (see Phase 5's `Selfie_TailorAndPrincessAna` note above) should hang on the wall of wherever that scene turns out to be — it was disabled in `BackRoomScene` on 2026-09-06 specifically because that wall isn't the right one anymore. Whichever session builds that scene should re-wire `setupSelfieKeepsake()` (or a copy) there rather than reintroducing it in `BackRoomScene`.

### v1 ship gate & final sprint

**⚠️ Updated 2026-09-10: the ending sprint (gate item 4) is now code-complete, not still "the one sprint standing between here and submission."** It ran 2026-09-10 in a single Claude Code session, following the education-content sprint (gate item 3, shipped 2026-09-08) exactly in the sequence the owner chose. What remains before submission is real, but it is verification and review work, not a build sprint — see gate item 4's own status note for the specific list (dialogue review gates, on-device confirmation, the still-open Ana dungeon-scale pass, the economy calibration pass, and pushing the 30-commit branch). Both sprint prompts are gitignored, main-checkout only: `_Prompts/EducationSprint_prompt.md` and `_Prompts/EndingSprint_prompt.md`.

**Ship target confirmed 2026-09-08: a real App Store submission**, not another sideload round. That decision adds an entire non-code lane no prior version of this roadmap tracked — see "Submission lane" below. Until submission, every build is still pre-ship alpha regardless of how polished any individual scene is.

**Where things stand today:** alpha testing, not a ship. Builds are sideloaded directly onto testers' physical devices — testers play, the owner watches. That is exactly why the paid Apple Developer Program enrollment was worth it (see "Signing & bundle identity" above): dev provisioning profiles last ~1 year instead of expiring every 7 days, so testers don't need a re-sideload every week. Nothing has been submitted to the App Store yet.

Two corrections worth keeping so they don't get re-lost: Phase 4 used to mislabel itself "the v1 release gate" (wrong — nothing has shipped), and gate item 2 used to bundle in the Princess Estelle teaser. The 2026-09-04 rescript decoupled that entirely, making it a storybook epilogue — and then 2026-09-08 brought it back as the **v1 final ending** under gate item 4 (Phase 7b), reached at 3000 마력 rather than through the detective mystery. Item 2 still means the handoff scene only; the ending is item 4.

#### The gate items — three original, plus one added 2026-09-08

1. **Daphne's 150-마력 level-up ships.** ✅ Shipped — the ✨ magic-light ability; VFX confirmed on device.
2. **Ana's quest begins — the handoff scene, Ana becomes the working tailor.** ✅ Shipped as `TailorHandoffScene`, confirmed on a fresh-install device playtest. **⚠️ Necessary but no longer sufficient, as of 2026-09-08.** The handoff makes Ana the tailor in `BackRoomScene` only; her dungeons still render Daphne and the game has no ending at all. Both are v1 — see gate item 4.
3. **A JSON educational-content feature is in place.** ✅ **Shipped 2026-09-08, revised same day after owner on-device playtesting.** The first pass (72 questions, 18/category, reviewed and approved before commit) shipped, then the owner tested it on a real device and found the arithmetic pitched at a difficulty that doesn't work for mental (no pen-and-paper) play on a phone — see the revision below. Content calls made with her explicit sign-off: "hello" was dropped from the vocab list (안녕's hi/bye ambiguity broke the 한영 direction) in favor of "thank you"; math ships exact-division-only (see the remainder note below); and, after playtesting, 덧셈/뺄셈 moved from 3-digit to 2-digit numbers and 곱셈 moved from mixed-digit multiplication to straight 구구단 facts — both because they're meant to be solved in your head on a phone screen, not on paper, and 3-digit vertical carrying and un-memorized two-digit multiplication don't work that way. **Current shipped set: 200 questions, 50 per category.** What shipped:
   - `INFOPLIST_KEY_UIFileSharingEnabled = YES` and `INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace = YES` were already done as of the previous session — unchanged here.
   - `riddles.json` is a real bundled resource now (`DesignerAna/riddles.json`, picked up automatically by the file-system-synchronized group — confirmed present in the built `.app` and loadable, not just referenced in the pbxproj). `RiddleBank.seedDocumentsIfNeeded()` (called from `AppDelegate.didFinishLaunchingWithOptions`) copies it into `Documents/` on first launch, absent-only. Load order is now `Documents/` → bundled `riddles.json` → an 8-question hardcoded last resort (trimmed down from the old 15, since it's genuinely last-resort now, not the default). Verified on-device: deleting `Documents/riddles.json` and relaunching re-seeds it byte-identical; writing malformed JSON there and relaunching logs the decode error via `os_log` and falls back cleanly to the bundled 200-question set (no crash, no empty quiz).
   - **Content shipped: 200 questions, 50 per category** — `addSub` 덧셈과 뺄셈, `mulDiv` 곱셈과 나눗셈, `enToKo` 영한 단어 암기, `koToEn` 한영 단어 암기. Curriculum ranges were originally verified against web sources (Khan Academy Korean 3학년 course pages, 충북수학, 3학년 English word-list references) as a starting point, but **the owner's own on-device playtest overrode the curriculum-grade mapping on two of the four categories** — a legitimate call, since "matches the 3학년 textbook" and "solvable in your head on a phone screen without paper" are different constraints, and this app only needs the second one:
     - **덧셈과 뺄셈** is now **2-digit ± 2-digit** (tens-place), not the original 3-digit ± 3-digit. 3-digit vertical addition/subtraction needs pen-and-paper column tracking that a phone quiz can't offer; 2-digit still exercises 받아올림/받아내림 (carrying/borrowing) without needing that scaffold. Distractors: a no-carry/no-borrow digit-wise slip, an off-by-one, and an off-by-ten — all scaled to the smaller 2-digit range (the original 3-digit set additionally used an off-by-hundred distractor, dropped since it no longer fits the range).
     - **곱셈** is now **straight 구구단 facts, both factors 2–12, never 1단** (e.g. `7 × 8 = ?`, `11 × 11 = ?`) — not the original mix that reached (두 자리)×(두 자리) like `15 × 12`. Multiplying two un-memorized two-digit numbers vertically in your head isn't realistic for this age group without paper; 2단–12단 is exactly the range Korean 3rd graders are expected to have memorized (or be memorizing). **나눗셈 is unchanged from the first pass** — still exact-division-only (see the remainder note below), still confirmed working well by the owner, now drawn from the same 2–12 fact space as the retuned multiplication set for consistency. One content-generation bug caught and fixed before shipping: digit-reversal distractors on quotients ending in 0 (e.g. reversing "10") degenerate to a single digit ("1"), producing a distractor so out of scale it's not a real distractor — fixed by falling back to an off-by-ten distractor whenever the quotient is a multiple of ten.
     - **나눗셈 does include remainders in the 3-2 curriculum** (몇십몇÷몇 나머지 있음) per the sources, but v1 still ships **exact-division-only** — unchanged scope call, because a "5 … 나머지 3"-style choice risks not fitting the fixed-width 4-button layout and this wasn't verified live; revisit once the format is device-confirmed.
     - **영한/한영 unchanged in approach, expanded in size:** still one shared word list reused in both directions (each word checked for a single unambiguous 3학년-level translation — "hello" was dropped for "thank you" once its 안녕=hi/bye double meaning made the 한영 direction genuinely ambiguous), now **50 words instead of 18** — animals, family, food, colors, school objects, simple verbs, nature, body parts, and adjectives, each grouped so a question's 3 distractors are drawn from the same semantic field and part of speech.
   - `RiddleCategory.displayName` renders as a small muted label in `RiddleScene.fillBubble(riddle:number:)`, directly above the question text (not a picker — that's v2). Confirmed on-device across all four categories: no clipping at the bubble's fixed width, no collision with the 💰 counter or the reward hint (now `+5냥` as of the 2026-09-10 retune below).
   - **Superseded:** `RIDDLE_BANK.md`'s Music / Science / Sports / Food draft bank — unchanged conclusion from before, still v2 paid packs.
   - **Declined for v1, not added:** an `explanation` field, any post-answer teaching moment, or a change to the unlimited-retry rule.
   - `DesignerAnaTests/RiddleContentTests.swift` (9 tests, loads the *shipped* bundled JSON via `Bundle.main` — the test host is the real app process, so this is the actual production path, not a fixture) mechanically checks: 200 total across exactly 50-per-category, 4 choices per question, exact `answer`∈`choices` string match, no duplicate choices within a question, no leading/trailing whitespace anywhere, positive reward, no duplicate questions in the set, an arithmetic self-check (regex-parses and evaluates all 100 math questions — 0 skipped), and answer-position distribution across all four button slots (perfectly even 50/50/50/50 across the full set by design, not by chance).
   - **Decided 2026-09-09: no parent-facing note, and editability is not a v1 feature.** Files-app reachability (`Documents/riddles.json` via `UIFileSharingEnabled`) is real and stays, but it doesn't make the file *editable by an ordinary parent* — tapping a `.json` in the Files app opens a read-only Quick Look preview, not an editor; actually changing it needs a Mac or a third-party text editor app. That gap is real enough that the owner chose not to market or document editability for v1 rather than write a note pointing parents at a workflow that mostly doesn't work for them. **The store listing should not claim "add your own questions."** Full scoping for an actual in-app editor (two sub-options, effort estimates, the v2-monetization design wrinkle) is preserved in the gitignored, owner-local `RIDDLE_EDITOR_V2.md` (repo root, same convention as `RELICS.md`/`RIDDLE_BANK.md`/`MAGIC.md` — **not** in `_InternMode/`, which is reserved for teaching cheatsheets, not design docs) for whenever V2 planning revisits this — see the V2 ideas entry below.

4. **Ana's era is playable and the game has an ending.** 🟡 **Code-complete 2026-09-10, not yet fully verified — see Phase 7b above for the full item-by-item breakdown.** Every numbered item shipped: Ana rendered as the dungeon hero with her own scale/foot-offset math, her own fairy-magic VFX, the ✨ ability unlocked from the start of her era, the 150/300 → 500/1000 threshold retune, the 3000 마력 ending gate with the three-act Estelle epilogue, the post-ending free-play state, the storybook restructure that gives every story scene one home and makes the opening mandatory, and (owner-added mid-sprint) a new King/Queen interlude at 1500 마력. **What's still genuinely open, in order of how much it blocks shipping:**
   - **Two dialogue review gates.** `EstelleEpilogueScene`'s every line is explicitly placeholder (stated in `962794e`'s own commit message) — do not ship as final. `TailorHandoffScene`'s lines have the same outstanding gap since Phase 7a. (`KingQueenScene`'s dialogue is owner-provided verbatim and does *not* need this — don't conflate the three.)
   - **Almost none of this sprint's work is confirmed on a real device.** Build + the full test suite passed at every commit, but live verification hit the same simulator small-element tap-precision friction across nearly every scene touched — documented per-commit rather than glossed over. The owner's own device playthrough is the real verification step still outstanding.
   - **The Ana dungeon-scale calibration pass is a separate, still-untouched problem** (item 11a in Phase 7b above) — don't treat this sprint as having closed it.
   - **The economy calibration pass is still blocked** on removing the `#if DEBUG` shortcuts, unchanged from before this sprint — see Currency & Economy below.
   - **30 commits are sitting on `claude/ending-sprint`, unpushed, no PR** — see the 2026-09-10 entry in `DesignerAna_handoff.md`.

#### Final-sprint code items (v1)

**A full sprint prompt for these plus the content set lives at `_Prompts/EducationSprint_prompt.md`** (gitignored, main-checkout only — invisible to worktree sessions). It carries the curriculum-verification step, the distractor design rules, the review gate, and the simulator/CI verification checklist. The ending sprint has its own prompt at `_Prompts/EndingSprint_prompt.md`.

All bounded, and each verified either this session or in `DIAGNOSTICS_prompt_results.md`.

- ~~**iPad orientation / full-screen validation warning**~~ — **resolved 2026-09-08 by dropping iPad, not by suppressing the warning.** The diagnostics run (§1.1, ranked #1) proposed `UIRequiresFullScreen = YES`; that key turned out to be **deprecated by Apple in September 2025** alongside iPadOS 26's new windowing system, with TN3192 as the migration note and no real replacement for apps that need a fixed full-screen aspect — sources disagree on whether it is already ignored or merely on notice. Building the v1 fix on it would have been building on sand. Instead: **`TARGETED_DEVICE_FAMILY` went `"1,2"` → `"1"` in all four configs.** The warning only ever applied to iPad, so it disappears at its source. The rationale for dropping rather than fixing: `"1,2"` was the Xcode default that nobody ever revisited — there is no iPad playtest anywhere in this project's history, no iPad-specific layout code, and no iPad simulator installed on the owner's machine, so the build claimed a device it had never been run on. `GameViewController.supportedInterfaceOrientations` was simplified in the same pass to return `[.landscapeLeft, .landscapeRight]` unconditionally: UIKit intersects that override with the plist's declared set, so both old branches (`.all` for iPad, `.allButUpsideDown` for iPhone) were dead code that only misled the reader. **Reversible** — iPad is now a deliberate v2 feature with its own QA pass (see V2 expansion ideas), not an untested claim.
- **Bundle weight — ~32.8 MB removable, measured in the real IPA.** 8 unreferenced imagesets plus doubled `GodmotherCat`/`WizardCat` (~11.6 MB), and the loose `ProfileAvatars/*.png` bypassing catalog compression (21.2 MB — move them into the asset catalog). ⚠️ **Not a pure file move:** per Phase 6b's gotcha, catalog imagesets register their PNG under the 2x slot so `texture.size()` returns half the pixel dimensions, while loose PNGs load at 1x. Moving the avatars **will change their apparent scale** — `FrontShopScene.fixCharacterLayout()` must be rechecked, not just the file paths.
- ~~**English display name**~~ — **done 2026-09-08.** `INFOPLIST_KEY_CFBundleDisplayName` stays Korean-only as the base/default value (unlocalized devices still get `묘한 옷 공방`), and a new `DesignerAna/InfoPlist.xcstrings` string catalog adds `en` → "The Purrfect Stitch" / `ko` → `묘한 옷 공방` localizations (with `ko` added to `knownRegions`). Verified in the built `.app`: `en.lproj/InfoPlist.strings` and `ko.lproj/InfoPlist.strings` both compiled with the correct values.
- **Sprite scaling pass** — Tailor/Shopkeeper `setScale` values across `FrontShopScene`, `BackRoomScene`, `AuroraChamberScene`, `PrincessAnaScene` (long-standing, from the June 9 handoff). **Skipped this session** — it's an owner judgement call needing before/after screenshots per scene, and the education-content sprint's scope was already large; left for a dedicated pass.
- **Bundle weight (~32.8 MB removable)** — **skipped this session**, deliberately, per the sprint prompt's own escape hatch: moving the loose `ProfileAvatars/*.png` into the asset catalog risks the exact 1x-vs-2x scale gotcha that already broke `FrontShopScene`'s customer-NPC composition once (Phase 6b), and re-verifying that composition wasn't in scope alongside the content set. The 11.6 MB unreferenced-asset deletion (unused imagesets, doubled `GodmotherCat`/`WizardCat`) is still fair game for a future session without touching the avatars.
- **Dialogue read-through** — `TailorHandoffScene`'s Korean lines were authored during implementation and have never had an owner pass. **`EstelleEpilogueScene`'s lines (added 2026-09-10) are in the same state** — explicitly placeholder, per its own commit message. Plus the general narrative-scene polish pass (owner to supply the revised scripts). `KingQueenScene`'s dialogue does not need this — it's owner-provided verbatim.
- **⚠️ Ana dungeon-scale calibration pass (added 2026-09-10, owner's call, explicitly deferred).** Ana reads bigger than the boss and was never calibrated against the dungeon hazards/monsters — see Phase 7b item 11a above for the full note and why it's distinct from this sprint's vertical-positioning fixes.
- ~~**`GAME_VOCABULARY.md` refresh**~~ — **done 2026-09-09.** Audited section by section against the codebase: ten stale claims corrected (including the file's own corrupted H1, a self-contradicting avatar count, and a NarrativeHUD layout description that predated Phase 5), eight new sections added for systems it had no vocabulary for at all, and an **Audit trail** section at the bottom recording what was re-verified, what was added, and what was deliberately *not* checked.
- **⚠️ Economy calibration pass** — **added 2026-09-09, owner's call.** Deposits, riddle reward, chest 마력 rewards, breadcrumb value, level-up thresholds and the 3000 ending gate are all provisional and have never been tuned against real play. The pass is gated on removing the `#if DEBUG` shortcuts first, because those make the earning curve unobservable. Full detail and the fixed ordering are under Currency & economy. **Do not tune these piecemeal before then.**
- **Texture memory** — several scenes cross 30 MB of real decompressed VRAM, measured via `assetutil` pixel-format inspection rather than inferred from file size. Not a crash today and not a submission blocker; recorded here so v1 sizing decisions are made with the number known.
- ~~`BossMinigameNode.swift:485` force-unwrap~~ — **already resolved; struck from the list 2026-09-08.** Verified by grep: zero `self!.` remain anywhere under `DesignerAna/`, and line 485 is now `scheduleNextAttack()` using `[weak self]` / `self?.`. This item had been carried on every remaining-work list since the June 13 memory analysis without anyone rechecking it.
- **`MinigameNode`/`BossMinigameNode` extraction — explicitly NOT a v1 item.** The duplication is real (27 shared function names, ~68% line match within them), but its urgency argument assumed Ana's puzzle minigames would be more copies of this scaffolding. They won't be, and they're 7c now. Worth doing on its own merits, after v1.
- **xcasset renames** — owner renames in Xcode, Claude does the code-side string replacements (rename table in the June 9 handoff). Cosmetic; first thing to cut if the sprint tightens.

#### Submission lane (new — no prior session tracked this)

None of this is code, and none of it can be started late.

- **App Store Connect app record.** Bundle ID `com.annyeongbirdie.thepurrfectstitch` is set; the paid team `VQ4643X8XU` is verified.
- **Privacy policy URL** — required for every submission. The app collects nothing and stores only local `UserDefaults`, which makes the policy short but does not make it optional.
- **Age rating questionnaire** — and, because the audience is 8-year-olds, **decide deliberately whether this lands in the Kids Category.** If it does, Apple's rules are materially stricter (no third-party analytics, a parental gate on any external link). Better decided now than discovered at review. The educational positioning should rest on the shipped 200-question content set itself, not on editability — see gate item 3's 2026-09-09 decision not to market or document parent editing for v1.
- **Screenshots** per required device size — `Screenshots/` already holds material to work from.
- **Store listing copy** — Korean and English; ties to the display-name item above.
- **Re-archive and re-run `-validate-for-store`** once the orientation fix lands. The diagnostics run proved this catches things nothing else in this project's workflow does.

#### What is explicitly NOT in v1

Ana's **puzzle** dungeons, her separate currency, clue collection, Daphne's potion-cooking side quest, King/Queen tailors, the `MinigameNode`/`BossMinigameNode` extraction, and **iPad support**. That is all of Phase 7c, plus the refactor and the device-family decision above. **Note what is no longer on this list:** the Estelle epilogue moved into v1 on 2026-09-08 as the final ending (designed in full on 2026-09-09), and Ana's era being *playable* — her sprite, her VFX, her ability — is Phase 7b and firmly in v1. Only her puzzle-genre rework is deferred. **If a session finds itself working on any of these, it is not working on v1.**

### Currency & economy

Two separate currencies with distinct economic shapes:

- **Customer's 냥 (`Wallet.shared.balance`)** — circular economy. Starts at 0냥 on a fresh install or 새 손님 reset. Depleted by front-shop deposits; replenished by dungeon chest refunds (크만할래 path) and shopkeeper riddle rewards. The wardrobe is the stamp-collection win condition. A brand-new customer starts broke and earns their way in. **Exception:** the customer handoff after the relics quest (`FrontShopScene.triggerCustomerPickerAfterSave`, set by `PrincessAnaScene`) does *not* reset wallet/wardrobe — the just-finished order's trophy is saved first, then the picker lets the player choose the next customer without wiping what was just earned. This is a deliberate judgment call (wiping immediately after a save would feel like a bug), not a full 새 손님 reset — worth revisiting if it reads as inconsistent with the "new customer starts broke" rule.
- **Tailor's 마력 (`Magic.shared.points`, 🐾)** — expansive economy, specifically Daphne's wizard-taught magic. Grows from dungeon chest rewards (10 / 20 / 30 / 50 마력 at cabinet / sewing / buttons / boss). 그만할래 refunds the customer's full deposit to `Wallet` but `Magic` is untouched (no rollback on quitting a station). Tied to the tailor's wizard-apprentice growth arc and Aurora mentorship dialogue. **Revised 2026-09-08 — in v1 Ana *does* share this counter.** Her era continues it rather than resetting: Daphne 0→1000 (her `levelTwo` handoff), then Ana 1000→3000 (the ending gate), one continuous total. A separate fairy-taught currency with her own name and thresholds stays Phase 7c — the shared counter is a deliberate v1 shortcut, not the end state. Accrual stops once the game is complete (see 7b item 8). **⚠️ No longer purely monotonic as of 2026-09-10** — `Magic.spend(_:)` deducts 10 마력 (floored at 0) every time the ✨ ability is cast in a dungeon (`MinigameNode.castMagicLight(at:)` / `BossMinigameNode.castMagicLightAtBoss()`), an owner-requested cost for using magic to defeat monsters. The ability is never blocked for lack of magic — it always fires, and points just floor at 0 — so this doesn't gate anything, it only means the total can fall as well as rise. `spend(_:)` is gated on `!Store.loadGameComplete()` the same way `add(_:)` is, so it can't perturb the frozen post-ending total either.

**그만할래 quit dialog** (back room): single confirm + cancel. Customer gets a full deposit refund (`Wallet.shared.balance += depositAmount`); 마력 earned during the session stays in `Magic.shared.points`.

**새 손님 reset** (button in SettingsScene): calls `Store.resetCustomerSide()`, which zeroes `Wallet`, empties the wardrobe, clears badge counters, clears the active order, and clears the `customer.selected` sticky flag. Tailor-side state — `Magic.shared.points`, future relics, dungeon progress, and the global storybook — is untouched. After reset, the app re-routes to the first-launch customer picker.

**Persistence schema — ⚠️ corrected 2026-09-08, this section claimed the opposite for four days.** Wallet and wardrobe are **per-customer**, and have been since `7b2d173` (2026-09-04, "Make wallet and wardrobe per-customer"). Every one of these keys is suffixed with the selected customer via `perCustomerKey(base) = "\(base).\(loadSelectedCustomer() ?? "_none")"`: `wallet.balance`, `wardrobe.garments`, `wardrobe.garmentCount`, `wardrobe.lastSeenCount`. The `_none` fallback keeps calls made before any customer is selected in an isolated, harmless slot rather than crashing. `Store.runPerCustomerMigrationIfNeeded()` (called from `Wallet`'s initialiser) copies pre-existing flat values into the current customer's slot once, never overwriting. `customer.selected` still holds the avatar asset-name string (e.g. `"ChefCat"`) and is what the suffix resolves from. The shopkeeper riddle credits `Wallet.shared.balance`, which now lands in the active customer's slot.

**Still global, deliberately or otherwise:** `magic.points` (tailor-side — correct, it follows the tailor, not the customer), all relic/quest/tailor flags (tailor-side — correct), and **`order.active`** (⚠️ *not* per-customer — see the switch-customer gap below).

**What this means in play:** a returning customer picked again later keeps their own balance and trophy case rather than starting broke. Recurring customers with persistent progress is a real, shipped feature.

**⚠️ The gap is the UI, not the data.** There is no non-destructive way to *switch* customers in normal play. `SettingsScene`'s avatar carousel is inert outside picker mode — `guard isFirstLaunchPicker else { return }` at both arrow cases, rendered at alpha 0.35 to signal it — so the only route to another customer is 새 손님, which calls `Store.resetCustomerSide()` and wipes the current customer's slot *before* handing off to the picker. So the persistence works and is unreachable: switch away from Chef Cat and her trophies are already gone. **The non-destructive path already exists in code** — `FrontShopScene.transitionToCustomerHandoff()` presents the picker with `isFirstLaunchPicker = true` and no reset — it is simply only reachable from the post-relics-quest handoff. Exposing it from `SettingsScene` is the whole feature; see Phase 7b.

**Minigame rewards (shipped):** 10 / 20 / 30 / 50 마력 awarded on chest open at cabinet / sewing / buttons / boss — credited directly to `Magic.shared.add()` in `MinigameNode` and `BossMinigameNode`.

#### ⚠️ Every number in this section is provisional — economy calibration is a deliberate pass, after the debug aids come out (owner's call, 2026-09-09)

**None of the game's economic constants have ever been tuned against real play.** They were chosen to make testing fast — to reach a threshold in a short session, to afford a deposit without grinding, to see a VFX fire on demand. That is the right way to build, and the wrong way to ship.

The numbers this covers, all of them:

| Constant | Current value | Where |
|---|---|---|
| Deposits | 드레스 60냥 · 셔츠/바지 45냥 (retuned 2026-09-10, was 50/30/40) | `Order.depositAmount`, set at the call site |
| Riddle reward | +5냥 per correct answer, 10 questions per round, one retry then a reveal (retuned 2026-09-10, was 15냥/≤3 questions/unlimited retries) | `Riddle.reward`, `RiddleScene` |
| Chest 마력 rewards | 10 / 20 / 30 / 50 | `MinigameConfig` per station |
| Breadcrumb paw | +1마력, 10 per dungeon / 8 in the boss arena | `MinigameNode` |
| Level-up thresholds | **500 / 1000** (retuned 2026-09-10, Phase 7b item 5 — was 150/300) | `MagicLevelUpThreshold` |
| Ending gate | 3000 마력 (Phase 7b item 6, shipped 2026-09-10) | `Magic.hasReachedEnding(_:_:)` |

**⚠️ The deposit and riddle-reward retune above happened 2026-09-10, ahead of the full calibration pass and while the `#if DEBUG` shortcuts are still present.** Owner justification, from the commit that made it: a real device playthrough showed unlimited quiz retries let a kid mash answers rather than learn, and the old 15냥/≤3-question round covered a whole deposit too easily. This is exactly the kind of direct-play-driven correction the ordering below says is fine ("changes forced by a bug are fine; changes made on feel wait for the pass") — but it is also two numbers changed together outside the debug-shortcuts-removed precondition, so treat it as a real but partial data point for the eventual full pass, not evidence the pass is done or that the ordering below no longer applies to everything else in this table.

**Why it cannot be done yet, and this is the whole point:** the `#if DEBUG` triple-tap shortcuts make the real earning curve unobservable. The upper-left grant hands out 마력 directly (+50 today, +250 after Phase 7b), the upper-right shortcut completes a station instantly, and the `BackRoomScene` roster cycle jumps straight to Ana. **Nobody has ever played this game's actual economy end to end** — every playthrough so far has short-circuited it somewhere. Tuning numbers against a session that used any of those aids would be tuning against a fiction.

**So the order is fixed:**

1. Remove the `#if DEBUG` triple-tap shortcuts (already a standing pre-ship item — see Build & Run).
2. Play the game through, genuinely, start to ending, with no aids.
3. **Then** recalibrate all of the above in one deliberate pass, against how long things actually took and how they actually felt.
4. Re-verify, and only then treat the numbers as final.

**Until step 3, do not tune these piecemeal.** A one-off adjustment to a single constant — "the deposit feels steep," "the boss reward feels small" — made without the full curve in view is how an economy ends up locally sensible and globally wrong. Changes forced by a *bug* are fine; changes made on *feel* wait for the pass.

⚠️ **This qualifies, but does not undo, the 2026-09-08 threshold decision.** Moving 150/300 → 500/1000 now rather than "reverting before shipping" is still right — a constant that must be changed back is exactly how a debug build reaches the App Store. But 500/1000 is a **better provisional value, not a measured one.** It is a starting point for the calibration pass, not its conclusion. The same is true of the 3000 ending gate: nobody has yet played the distance between 1000 and 3000.

**For the store listing and any parent-facing copy:** session length and "how long is this game" claims should wait for the calibration pass too. Right now nobody actually knows.

### V2 expansion ideas (post-roadmap)

Captured here so they're not lost; not planned for current phases.

- **Adaptive difficulty easing for station minigames.** Track death count per minigame attempt and reduce hazard density after N deaths (fewer chasms, slower monsters, longer safe gaps in button rain) so kids don't get stuck. Auto-reset to default difficulty on success. The 냥 reward should not scale down with eased difficulty — the easing exists to keep play sessions positive, not to discourage skill development.

- **Guardian reframe for the mannequin level (visual seed already in place).** The boss-on-chest reveal animation that plays on boss defeat in `BossMinigameNode` was deliberately planted as a seed for a future "guardian" iteration of the same level: replace the fight with a puzzle where the player lures a giant dust monster off the chest into a trap, rather than damaging it. Educational angle — observation and planning over reflexes. The visual continuity (boss-on-chest at defeat) makes the reframe feel like a deepening of the same level rather than a contradiction.

- ~~**Per-customer wallet and wardrobe**~~ — **shipped 2026-09-04 in `7b2d173`; struck from V2 on 2026-09-08.** This entry described it as unbuilt for four days after it landed. See Currency & economy above for what actually exists. What remains is the non-destructive customer-switch UI, which is v1 (Phase 7b), not a V2 idea.
- **iPad support (dropped from v1 on 2026-09-08 — see the v1 ship gate for the full rationale).** `TARGETED_DEVICE_FAMILY` is `"1"` (iPhone only). Bringing iPad back is a real piece of work, not a flag flip, and it now has to be done Apple's way rather than with `UIRequiresFullScreen` — that key is deprecated and has no direct replacement for fixed-aspect apps. What it would take: adopt `UIWindowScene.sizeRestrictions` (a preference, not a guarantee — the system makes a best-effort attempt only, and it can be `nil` on older iPadOS with Stage Manager), then make the scenes actually survive being resized. That last part is the expensive half: every scene in this codebase positions nodes with hand-tuned absolute values and fraction-of-`size` math, plus the per-sprite transparent-padding table, all tuned against a phone aspect ratio. Budget a real layout pass and a real iPad playtest, not a build-setting change. Apple's TN3192 is the migration note to start from.
- **Parent-facing riddle editor, without a login gate.** ⚠️ **Reversed 2026-09-09 — read the v1 ship gate's item 3 first.** The 2026-09-08 framing ("reachability is enough") didn't survive a closer look: Files-app sharing (`UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`) makes `Documents/riddles.json` *reachable*, but tapping a `.json` in the Files app opens a read-only Quick Look preview, not an editor — actually editing it needs a Mac or a third-party text editor app, which isn't "any parent can do this." **Decision: v1 does not market or document parent editability at all** — the 200-question set is the whole pitch, and reachability stays as an unadvertised bonus for the rare technical parent, not a claimed feature. Building a real editor (raw-text or a structured form) was scoped in detail — two sub-options, effort estimates, and the forward-compatibility wrinkle with v2's paid-pack file model (an editor must write to its own `custom.json`, never a purchased pack's file) — and preserved in `RIDDLE_EDITOR_V2.md` (gitignored, repo root, main-checkout only — invisible to worktree sessions, same convention as `RIDDLE_BANK.md`/`GAME_VOCABULARY.md`; deliberately **not** in `_InternMode/`, which is reserved for teaching cheatsheets, not forward-looking design docs) for whenever V2 planning revisits this. The owner still wants no account/login system regardless of which option is chosen — that constraint is unchanged and carries into that document.

## Intern Mode

The owner is learning Swift/Xcode as she goes and periodically asks for a plain-English, no-jargon
explanation of how something in this codebase actually works — Swift language features, the app's
architecture, persistence, whatever the current topic is. When that happens (she may call it "Intern Mode"
explicitly, or just ask "explain this like I'm new to Swift"):

1. **Explain it in plain terms in the conversation first**, assuming no prior Swift/Xcode background — she's
   picking this up as she goes, not brushing up on something she already knows.
2. **Then save it.** Write a persistent cheatsheet to `_InternMode/How Does It Work - <Subject>.md`
   (gitignored, main-checkout only — same convention as `RIDDLE_BANK.md`/`GAME_VOCABULARY.md`, invisible to
   worktree sessions). Follow the format of the existing files there: an `# How Does It Work: <Subject>`
   title (colon in the heading is fine; the *filename* uses `" - "` instead, since colons are awkward in
   filenames), then an italicized context line — `*Intern-mode cheatsheet. Written <date via `bash date`>,
   covering ...*` — then the explanation, then usually a one-sentence summary at the end.
3. **This is for her to re-study later, not for the codebase or future Claude sessions.** Don't treat it as
   project documentation, don't assume a future session has read it, and don't let it drift out of sync with
   the code — if she asks about the same topic again after something changed, write a fresh or updated
   cheatsheet rather than trusting the old one's details are still accurate.

Existing entries as of 2026-09-09: `How Does It Work - Testing.md` (the `DesignerAnaTests` target,
`@testable import`, `XCTestCase`) and `How Does It Work - Data Storage and Swift Types.md` (`struct` vs
`class` vs `enum`, the enum-as-namespace pattern `RiddleBank`/`Store` use, the singleton pattern
`Wallet`/`Magic`/`ProfileManager` use, and why this app has no database — plus when SwiftData would actually
start to matter for V2).

**`_InternMode/` is scoped strictly to "how does X currently work" teaching cheatsheets — not design docs,
proposals, or anything forward-looking.** Feature brainstorms, options-considered writeups, and V2 planning
notes belong at the repo root as their own gitignored `ALL_CAPS.md` file instead, the same convention as
`RELICS.md`/`RIDDLE_BANK.md`/`MAGIC.md` (e.g. `RIDDLE_EDITOR_V2.md` for the parent-editor scoping — see the
V2 ideas list below). This distinction exists because a planning doc sitting next to teaching cheatsheets
reads ambiguously to a future session skimming the folder — it could be mistaken for documentation of
something that already exists rather than something explicitly not yet built.

## Closing handoff procedure

At session end, when updating `DesignerAna_handoff.md` (the "closing handoff"), **stamp the date by running `bash date` and using that value** — do not infer the date from file timestamps, previous handoffs, or memory. The handoff date must reflect the session it documents. We made this mistake once (handoff dated May 29 for work done June 2), which caused confusion at the next session's start.

If a closing handoff doesn't happen (the owner closes the laptop unexpectedly), the owner has committed to returning to the same Cowork session next time rather than opening a new one — so the absence of a closing handoff unambiguously defines the session's status. A fresh session is the signal that a proper closing handoff was written; a resumed session is the signal that it wasn't.
