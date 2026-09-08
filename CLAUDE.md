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
needs a running scene or simulator interaction. 35 tests across:
`StoreTests` (per-customer keying isolation, `resetCustomerSide()`, the
per-customer migration's one-shot/idempotent behavior, one-shot flags),
`MagicTests` (`add(_:)`'s threshold-crossing logic), `FrontShopStateTests`
(an exhaustive truth table for `accepts(_:)` — every state×input pair, not a
sample), `GarmentNamingTests` (all 9 clothing×color asset-name combinations),
`TailorIdentityTests` (`Tailor.identity(for:)` / `haloScale(for:)`),
`CodablePersistenceTests` (round-trips plus a hand-written old-format JSON
blob to directly verify the "old saves still decode" comments in
`ActiveOrder`/`Order.swift`), and `AuroraChamberSceneTests` (a regression
test for the shipped "off by 300 마력" dialogue bug — see Phase 7 below;
`AuroraChamberScene.closingLine(forMagicPoints:)` was pulled out of
`didMove(to:)` specifically to make that branch testable in isolation).

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
                     TailorChoiceScene → AuroraChamberScene → PrincessAnaScene
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

The tailor shop has three functional spaces, each with a deliberate POV. The shop **front**'s ordering flow (`FrontShopScene`) is third-person customer POV as of Phase 6b — the player picks a customer avatar in settings, and that avatar is rendered on screen as a visible NPC the shopkeeper (Polaris) actually talks to; the player's taps still drive the NPC's choices, but the player watches rather than being addressed directly as the customer. This was a deliberately scoped flip: `SettingsScene`, `RiddleScene`, and `DressingRoomScene` were explicitly left alone (see Phase 6b) — they're meta/utility screens (avatar picker, riddle minigame, wardrobe browser), not narrative "customer talks to shopkeeper" moments, so they don't carry a customer-POV framing at all. The **back room** (workshop) is tailor POV — the player watches the tailor work and sees both the customer's deposit reference (💰 냥) and the tailor's growth tracker (🐾 마력) in the HUD. The **basement** is the four dungeons (fabric cabinet, sewing, buttons, mannequin boss); plus Phase 5's `TailorChoiceScene`, `AuroraChamberScene`, `PrincessAnaScene`, and `DaphneBecomesTailorScene` scenes. All basement scenes are tailor POV.

| Space | Scenes | POV |
|---|---|---|
| Shop front — ordering flow | `FrontShopScene` | Customer NPC, third-person (player watches, still drives the taps) |
| Shop front — utility screens | `SettingsScene`, `RiddleScene`, `DressingRoomScene`, `StorybookScene` | Not narrative POV — meta/utility UI, unaffected by 6b |
| Back room | `BackRoomScene` (HUD column top-to-bottom: 💰 냥, then 그만할래 quit button, then 🐾 마력 at the bottom — do not place anything between 💰 and 그만할래, or between 그만할래 and 🐾) | Tailor |
| Basement (dungeons) | `MinigameNode`, `BossMinigameNode`, and Phase 5: `TailorChoiceScene`, `AuroraChamberScene`, `PrincessAnaScene`, `DaphneBecomesTailorScene` | Tailor |

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

`Model/` has fourteen files; scene-specific state still lives inside each scene class.

| Type | Key fields |
|---|---|
| `Order` (struct) | `clothingType: ClothingType`, `depositAmount: Int`, `fabricColor: FabricColor` |
| `ClothingType` / `FabricColor` (enums) | `String`-raw, `Codable`, `CaseIterable`; live in `Order.swift`. Korean raw values, kept identical to the old `String` model so `Codable` persistence stays byte-compatible. Helpers: `displayName`, `assetFragment` / `assetSuffix`, and `FabricColor.palette`. |
| `FrontShopState` (enum) | seven cases, drives UI in FrontShopScene. `ShopInput` + `FrontShopState.accepts(_:)` — a single exhaustive `switch self` — gate which buttons each state accepts. |
| `MinigameStation` family | `MinigameStation` enum (4 cases) + `MinigameConfig` struct + helper enums (`EnemyKind`, `DefeatMechanism`, `MonsterBehavior`, `HazardKind`). Drives stations 1–3; the boss does not flow through `MinigameConfig`. Daphne-specific (platformer) — Phase 7 plans a parallel puzzle-minigame config family for Ana, not yet built. |
| `Wallet` (singleton) | `balance: Int` — **customer-side** 냥. 0 on a fresh install and on every 새 손님 reset. Persisted via `Store.loadWalletBalance` / `saveWalletBalance`. Currently one flat global balance, not per-customer — Phase 7 plans to re-key this per customer identity (see Currency & economy below), not yet built. |
| `Magic` (singleton) | `points: Int` — **tailor-side** 마력 (cat wizarding XP, 🐾), specifically Daphne's wizard-taught magic. Monotonically grows via `add(_:)`. Persists across 새 손님; tied to the tailor's wizard-apprentice growth arc. Phase 7's Tailor Identity system plans a separate fairy-taught currency for Ana with her own name/thresholds — not a generalization of this type, a distinct one — not yet built. |
| `ActiveOrder` (struct, Codable) | Crash-recovery snapshot: `clothingType`, `fabricColor`, `depositAmount`, `backRoomStateName`, `savedAt`. Saved on every `BackRoomState` transition; cleared on completion or quit. Uses Swift's synthesized `Decodable` which silently ignores unknown keys — old saves with the removed `earnedMinigameRewards` field decode cleanly. |
| `DungeonItem` (enum) | `String`-raw, `Codable`, `CaseIterable`. Four cases: `purpleScepter`, `paintBrush`, `palette`, `royalFamilyPortrait`. Each maps to a dungeon seed via `dungeonSeed`. Used by `Store.loadCollectedRelics()` / `saveCollectedRelics(_:)`. Daphne-specific ("relics"); Ana's era reuses this exact same 4-slot mechanic renamed to "clues" (Phase 7, not yet built) rather than a new collection system. |
| `Riddle` (struct, Codable) | `question`, `choices[4]`, `answer`, `reward` (default 15냥). `RiddleBank.load()` tries `Documents/riddles.json` first (parent-editable), falls back to 15 hardcoded defaults. |
| `SoundManager` (singleton) | `isMuted: Bool` (UserDefaults), `play(_ filename: String)`, `stop(_ filename: String)`, `stopAll()`. Backed by an `AVAudioPlayer` pool keyed by filename — multiple concurrent plays of the same cue are pooled, and `stop(_:)` cancels every in-flight copy. All SFX route through this — silent no-op when muted; `toggleMute()` also calls `stopAll()`. |
| `ProfileManager` (singleton) | `selectedIndex: Int` (UserDefaults), 9 cat avatars in `avatars` array with asset name + Korean display name. `advance()` / `retreat()` cycle selection. `GodmotherCat` and `WizardCat` removed in v2 migration — NPC-only assets now. This is the customer roster; there is no equivalent "tailor roster" type yet — Phase 7's Tailor Identity system is the planned analog for Daphne/Ana (and eventually the rest of the royal family), not yet built. |
| `FinishedGarment` (struct, Codable) | A saved wardrobe trophy: clothing type, fabric color, completion date. `Store.loadGarments()` / `saveGarments(_:)`. |
| `GarmentNaming` (enum, namespace) | Maps `(ClothingType, FabricColor)` → the `Mannequin_{ClothingType}_{FabricColor}` asset name shown on the mannequin and in the wardrobe. |
| `Layout` (enum, namespace) | Positioning math shared across scenes — e.g. `frontShopCharacters(in:)` computes the customer/shopkeeper/mannequin composition in `FrontShopScene`. |
| `UserDefaultsStore` (`Store`, enum namespace) | Every load/save function and `UserDefaultsKey` string constant in one place — the single seam all persistence flows through. (One inaccuracy in its own header comment: `ProfileManager` and `SoundManager` actually read/write `UserDefaults.standard` directly rather than through here — no key collision, just worth knowing before assuming this file is exhaustive.) |

`currentOrder: Order?` is an instance var on `FrontShopScene`. Currency state: `Wallet.shared.balance` (customer 냥) and `Magic.shared.points` (tailor 마력) — both singletons, read directly from any scene, no property handoff needed.

### Known gaps / in-progress state

- **📋 `GAME_VOCABULARY.md` needs a refresh — instructions for whichever session does it.** This file is gitignored/local-only (owner-local reference, never tracked in git — confirmed via `.gitignore` and git history), so it's invisible to any session running in a worktree (like this one) and can only be edited from the owner's main checkout, likely in a Cowork session per the owner's plan. Things confirmed or changed in the 2026-09-03 session that likely need reflecting there:
  - The shopkeeper has a real name, **Polaris** (폴라레스) — established in `DaphneBecomesTailorScene`, where she's explicitly Aurora's *younger* sister (she calls Aurora "언니"; Aurora calls her "나의 동생").
  - `SecondPrincessCat` = Ana (confirmed, `PrincessAnaScene.swift:124`); `FirstPrincessCat` is presumed to be Estelle (not yet confirmed by the owner, currently only used as a storybook illustration) and is slated for a Phase 7 visual reveal.
  - Estelle's fate (Phase 7, planned): fell through a portal, Alice-in-Wonderland style, into modern-day Korea — specifically Gwanghwamun Square (광화문광장). If the vocabulary doc tracks world/setting concepts, this introduces "modern-day Korea" as a place the story can reach, which is a significant departure from the fairy-tale kingdom setting. As of 2026-09-04 this is no longer a live scene tease but a storybook epilogue, unlocked once Ana solves her detective mystery.
  - **2026-09-04 additions, all still design-stage (not built) — same caveat as below, don't backfill vocabulary entries until the code lands, but the lore itself is confirmed by the owner:**
    - Polaris is characterized as a sharp, deliberate deal-maker — established via the drafted Daphne/Aurora/Polaris/Ana handoff scene, worth keeping consistent wherever she negotiates.
    - Daphne's magic is wizard-taught (under Aurora); Ana's is fairy-taught (under her godmother Flora) — explicitly two different magic traditions with two different teachers, not one system reskinned. Ana's currency/terminology not yet named by the owner.
    - World lore: the number of dungeons is canonically **unknown** — stated explicitly as intentional headroom for infinite future expansion, not an oversight. The four physical stations (fabric/sewing/buttons/mannequin) are the current shop's set, not necessarily a hard ceiling.
    - **All four royal family members may eventually become tailors** (King and Queen confirmed as future possibilities, alongside Daphne and Ana already in motion) — each tailor's minigame style is tied to their characterization (action vs. thought-driven, established so far), not assigned arbitrarily.
  - Whatever ends up documented for Phase 7's planned mechanics (Daphne's 150-마력 stomp→magic-sleep interaction — **now shipped** as the ✨ magic-light ability, so this one's actually ready to document, not a placeholder) once the rest actually get built — they don't exist yet, so don't backfill vocabulary entries for those until the code lands.
  - General pass: confirm the doc's monster/mechanic descriptions still match current code (this session found and fixed unrelated staleness in CLAUDE.md itself — e.g. `Order`'s fields were still described as `String` months after they became enums, and the Scene Flow diagram still described the pre-Phase-6a `.sks` loading a full session after that shipped — so drift of this kind is plausible here too).
- **⚠️ Remove all `#if DEBUG` triple-tap dev shortcuts before shipping.** All are `#if DEBUG`-gated (won't build into a release/TestFlight archive) but are flagged here as a deliberate pre-ship checklist item since they mutate real persisted state, not just a view-only cheat. Six exist, all triple-tap-in-a-corner: `SettingsScene.swift:381` (top of `touchesBegan` — triple-tap anywhere clears collected relics + relic-quest state, for re-testing the Phase 5 quest from scratch), `MinigameNode.swift:562` and `BossMinigameNode.swift:918` (triple-tap the upper-right of the dungeon arena — instantly completes the current station/boss, added because the boss fight's two-button mechanic can't be tested on the Simulator, which has no simultaneous multi-touch), `StorybookScene.swift:987` (triple-tap the ToC's top-right corner — marks the relic quest complete via `Store.saveRelicQuestComplete()` to unlock chapter 5 "장면 다시 보기" for story-content preview without playing the dungeons), `BackRoomScene.swift:413` (triple-tap the bottom-right corner, clear of the HUD — cycles `Store.saveCurrentTailor(_:)` through the roster, added so Ana's `BackRoomScene` presence and scale could be tested before the real handoff scene existed; now that `TailorHandoffScene` is shipped this is a testing convenience rather than the only way to reach Ana, but it's still handy for skipping the 300-마력 grind), and **added 2026-09-06:** `MinigameNode.swift` and `BossMinigameNode.swift` (triple-tap the upper-left of the dungeon arena, the mirror corner of the instant-complete shortcut — adds 50 마력 through the real `Magic.add(_:)` path, so the 150/300 level-up VFX fires exactly like a genuine reward; added so the level-up VFX could be tested without grinding or reinstalling, and reusable for 300 once that's built). Search `tapCount >= 3` to find all of them.
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

Effectively complete — a full sound pass across every scene. *(Correction: this used to call itself "the v1 release gate," which was wrong — nothing has shipped. See "v1 ship gate & final sprint" after Phase 7b below for what shipping actually requires and what the current alpha-testing status really is.)*

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

### Phase 7 — split into 7a (v1) and 7b (v2) on 2026-09-08

Phase 7 was one phase describing two eras. By 2026-09-08 everything in Daphne's half had shipped and nothing in Ana's half had started, so the phase was cut along that seam rather than carried forward as one open-ended block. This is the scope reduction `ASSESSMENT.md` recommended (Lane B, item 10 — "cut Phase 7 to a shippable v1") and the owner confirmed the line on 2026-09-08: **v1 ships the protagonist swap; Ana's puzzle dungeons are v2.**

| Phase 7 item | Lane | Status |
|---|---|---|
| Ending sequencing rule (Magic ≥ 300 gated on relic quest) | 7a / v1 | shipped |
| 150 마력 magic-sleep ability | 7a / v1 | shipped |
| In-dungeon level-up VFX (150 + 300) | 7a / v1 | shipped |
| `TailorHandoffScene` (300 마력 handoff) | 7a / v1 | shipped |
| Tailor Identity **foundation** (roster, persistence, per-tailor height + style) | 7a / v1 | shipped |
| Ana as the working tailor after the handoff | 7a / v1 | shipped |
| Status HUD redesign (two panels) | 7a / v1 | shipped |
| Ana's puzzle-minigame node types (sudoku, spot-the-difference, …) | 7b / v2 | not started |
| Ana's own fairy-taught currency (name + thresholds) | 7b / v2 | not started — owner to name |
| Clue collection (relics → clues for Ana's era) | 7b / v2 | not started |
| Estelle storybook epilogue | 7b / v2 | not started |
| Daphne potion-cooking side quest | 7b / v2 | not designed |
| King/Queen as playable tailors | 7b / v2 | lore only |

**The v1 reading of "Ana's quest begins," stated plainly so it isn't re-litigated:** Ana takes over the shop and is the visible working tailor, and her dungeon runs launch Daphne's platformer minigames under the hood. That is a coherent ending for v1 — the handoff scene is the payoff — and it is deliberately *not* the full "Ana plays puzzles" vision. Confirmed by the owner 2026-09-08. **Do not treat the platformer-under-Ana situation as a v1 bug**, and do not file it as one.

### Phase 7a — Daphne's arc conclusion & the tailor handoff (v1 — shipped)

Continues the Phase 5 relics-quest storyline. **All of 7a is shipped as of 2026-09-08** — the prose below was written while it was still in design and is kept because the decisions, gotchas and rejected alternatives in it are load-bearing; read "shipped" markers per-item rather than assuming the framing is still forward-looking. **Revised 2026-09-04** — the owner rescripted the back half of this phase via artifact comments on the "One Gate, Six Endings" flowchart; what follows supersedes the original separate-scenes plan below. The original six-way naming and the collision it was solving are kept here as context since the *rule* it produced is still load-bearing.

**Ending sequencing (locked, 2026-09-03; content revised 2026-09-04).** Two systems compete for the same moment — a dungeon order finishing and the player returning to the shop: the relics quest (Ending 1, shipped) and Daphne's Magic-point thresholds. The locked rule: **the Magic ≥ 300 chain may only fire once `Store.loadRelicQuestComplete() == true`.** If `Magic.points` crosses 300 before the relics quest resolves, it just stays dormant, rechecked on every subsequent order completion — same mechanism already planned for "wait until no order is in progress," just with one more condition. This isn't only a UI-collision fix: it's a narrative-causality requirement, since everything past this gate assumes Daphne has already found and delivered all of Estelle's relics before her own "graduation" arc begins. The 150-마력 ability unlock stays independent of this whole gate — it's a passive unlock with no scene, checked on every dungeon load, nothing competes with it for screen time.

**Dialogue bug found + fixed (2026-09-06):** the dormant-gate case above has a narrative side effect the gate rule itself doesn't cover — `AuroraChamberScene` (part of the relics-quest completion chain, fires *before* `Store.saveRelicQuestComplete()` is set in `PrincessAnaScene`'s outro) has Aurora comment on the tailor's current 마력 total and, unconditionally, tell Daphne to "come back once you're stronger" (좀 더 강해지면 공부를 마치러 돌아오렴). If the player reached 300 마력 *before* finishing the relics quest, that line is contradicted almost immediately — the 300 handoff chain unblocks and fires on the very next order completion once this scene's chain ends. Fixed with a one-off branch on `Magic.shared.points >= 300` in `didMove(to:)`: at ≥300 the closing clause swaps to an acknowledging line ("이미 충분히 강해졌구나. 곧 다시 만나게 될 것 같은 예감이 드는구나") instead of the "not ready yet" one. Deliberately scoped narrow — a single branch on this one line, not a broader multi-tier dialogue system — per the owner's explicit call to stop scope-creeping polish here: three bigger items (Ana's puzzle-minigame dungeons, the JSON educational-content ship-gate item, plus the not-yet-scoped Estelle epilogue and a mentioned Daphne potion-cooking side quest) are still ahead of this for shipping.

**150 마력 — Daphne levels up.** Her dungeon-minigame defeat interaction changes from a stomp jump to a magic-based "put to sleep" action — pays off the Fairy Godmother's existing lore in `PrincessAnaScene` (beat 12) that defeating a monster only puts it to sleep, doesn't harm it. **Shipped** as the ✨ magic-light ability (`MinigameNode`/`BossMinigameNode`). **Confirmed needed by a fresh-install device playtest (2026-09-05):** from a new player's perspective, nothing signals that Daphne has leveled up at 150 — the ability just becomes available with no visible moment marking the threshold.

**In-dungeon level-up VFX — shipped 2026-09-06, both thresholds** (`playLevelUpVFX(at:threshold:)` in both `MinigameNode.swift`/`BossMinigameNode.swift`, duplicated per this codebase's existing convention for these two sibling classes; the 150 pass referenced the sample in `_ReferenceSamples/level_up.jpg` plus a Pinterest reference board, both reviewed with the owner first). `Magic.add(_:)` returns `MagicLevelUpThreshold?` (`.levelOne` = 150, `.levelTwo` = 300, `nil` if neither was crossed by that call) instead of a plain `Bool` — a single call can only ever cross one threshold, since real reward sizes (≤50) can't jump the 150-point gap between them. All 4 real reward call sites (paw pickup + chest reward, both files) plus both debug shortcuts route through one `handleLevelUp(_:)` dispatcher per file: `.levelOne` plays the small VFX and pops the ✨ ability button in live (with a little overshoot); `.levelTwo` plays a bigger VFX only — the button is already unlocked, so 300 doesn't re-trigger it. Composition, confirmed correct on-device after two rounds of owner feedback on the 150 pass: a **straight** gold light pillar (not a cone — a fanned/coned shape was tried first, matching an earlier HTML mockup, but read oddly once tested against Daphne's actual sprite standing in it, so it was reverted to a straight beam), half-width 26pt (34pt for 300) rising from a `heroFootOffset` of 42pt below `hero.position` (her sprite's center — 22, half her physics-body height, landed at her knees on device and was increased; still an estimate, no documented padding value for the hero sprite the way Monster/Boss/BossAdd have), plus a ground ring that grows in sync with the pillar's rise (120×30pt at 150, 170×40pt at 300 — widened proportionally *more* than the pillar itself, not just matched to it) and rising gold sparks (8 at 150, 14 at 300, rising further and taking longer to fully fade). The 300 version scales up the whole composition — taller pillar (220pt vs 140pt), longer rise (0.6s vs 0.4s) and hold (1.0s vs 0.5s) — same shape, bigger and slower, not a new design. Gold-only palette, matching Daphne's wizard-magic-is-yellow rule (see `MAGIC.md`). The pre-existing `#if DEBUG` triple-tap shortcut (upper-left of the dungeon arena, mirroring the pre-existing upper-right instant-complete shortcut) adds 50 마력 through the real `Magic.add(_:)` path — same shortcut serves both thresholds now, no new one needed. Still open: the Tailor Status HUD's own ✨ level-up indicator (a separate, not-yet-built piece — see Status HUD redesign below).

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

**Tailor Identity system (model-layer concept, designed 2026-09-04 — foundation shipped, some pieces still open).** `TailorIdentity.swift` exists: a roster type (mirrors `ProfileManager.avatars`) with `daphne` and `ana`, keyed by stable string id, with `Store.loadCurrentTailor()` / `saveCurrentTailor(_:)` persistence. **The owner confirmed all four royal family members may eventually become tailors** (King and Queen too, per world lore that the number of dungeons is canonically unknown — this game is built to keep expanding), so the roster must stay extensible, not hardcoded to two — current shape supports that. Each tailor entry carries: display name, sprite asset, a per-tailor `renderedHeight` (in points — Daphne renders at 70% of Ana's height for a shorter, chibi/younger look; Ana's height is the preserved reference since it already read correctly against the back room's furniture), and their own minigame style. Not yet built, and **moved to Phase 7b / v2 on 2026-09-08**: Ana's own magic-point currency (still shares `Magic.shared`/마력 in code, though narratively she has her own fairy-taught magic per the lore below) and the puzzle-minigame node types. The bullets that follow are 7b design notes retained here for context — the foundation they describe is what shipped in 7a.
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

### Phase 7b — Ana's puzzle-detective era (v2 — not started)

Everything in this section is design, not code. **Nothing here blocks v1.** It all depends on the Tailor Identity foundation shipped in 7a, which was deliberately built extensible (string-keyed roster, per-tailor sprite/height/minigame-style) for exactly this.

**Not yet built, in dependency order:**

1. **Ana's currency.** Fairy-taught (from godmother Flora), with its own name and its own level-up thresholds — explicitly *not* reusing 마력's numbers or Korean terminology. In code she still shares `Magic.shared` today. **This is an owner decision and must not be invented by a session.** Everything below reads better once it is named.
2. **Puzzle-minigame node types** — sudoku, spot-the-difference, crossword, etc. New classes, *not* copies of `MinigameNode`/`BossMinigameNode`: a sudoku needs no jump physics and no D-pad (this is why the diagnostics run downgraded the duplication-extraction urgency — the argument for it assumed these would be copies, and they won't be). Physical dungeon structure stays fixed: same four stations, same firefly unlock, same entrance flow — only *which minigame class launches* changes. Deliberate, for the 8-year-old audience: change content and mechanics, never the spatial conventions they have already learned. **The owner has asked for TDD here specifically** — write the puzzle-logic tests first, and shape that logic as pure functions/types from the start rather than SKScene-embedded, which is exactly what makes the existing platformers hard to retrofit tests onto now.
3. **Clue collection** — reuses the relic mechanic exactly: same 4-slot HUD row, same collection animation (scale pop + sparkle burst + arc to slot), same sounds, same safety-net auto-pull. Only icon and name change. The 4 slots stay fixed per era regardless of how many dungeons the world lore might eventually allow.
4. **Ana-as-tailor sprite** — not yet chosen. `SecondPrincessCat` is already used for her in `PrincessAnaScene` at a tuned scale, so reusing it in `BackRoomScene` needs the same scale-matching care documented in Phase 6b's gotchas.
5. **Estelle storybook epilogue** — gated on Ana solving her mystery, which needs 1–4 first.

**Estelle reveal (reframed 2026-09-04 — was a live in-scene tease, now a storybook epilogue).** Still: Estelle fell through a portal, Alice-in-Wonderland style, into modern-day Korea, specifically Gwanghwamun Square (광화문광장), likely using the currently-unused `FirstPrincessCat` asset. What changed: this is no longer a scene that plays automatically — it becomes **an epilogue watchable in the storybook**, unlocked once Ana successfully solves her mystery as a detective (exact completion condition — how many clue-dungeons, which ones — not yet speced, depends on the Tailor Identity / puzzle-dungeon work above landing first).

**Also deferred here (was "explicitly out of scope for this phase"):** a side-quest arc for Daphne as Aurora's redeemed apprentice, post-departure — mentioned 2026-09-06 as specifically a **potion-cooking** side quest, not designed further than the name — and building out King/Queen as playable tailors. Both are confirmed future lore. **Filed away for whenever the side quest is built:** the selfie keepsake (see Phase 5's `Selfie_TailorAndPrincessAna` note above) should hang on the wall of wherever that scene turns out to be — it was disabled in `BackRoomScene` on 2026-09-06 specifically because that wall isn't the right one anymore. Whichever session builds that scene should re-wire `setupSelfieKeepsake()` (or a copy) there rather than reintroducing it in `BackRoomScene`.

### v1 ship gate & final sprint

**Ship target confirmed 2026-09-08: a real App Store submission**, not another sideload round. That decision adds an entire non-code lane no prior version of this roadmap tracked — see "Submission lane" below. Until submission, every build is still pre-ship alpha regardless of how polished any individual scene is.

**Where things stand today:** alpha testing, not a ship. Builds are sideloaded directly onto testers' physical devices — testers play, the owner watches. That is exactly why the paid Apple Developer Program enrollment was worth it (see "Signing & bundle identity" above): dev provisioning profiles last ~1 year instead of expiring every 7 days, so testers don't need a re-sideload every week. Nothing has been submitted to the App Store yet.

Two corrections worth keeping so they don't get re-lost: Phase 4 used to mislabel itself "the v1 release gate" (wrong — nothing has shipped), and gate item 2 used to bundle in the Princess Estelle teaser (the 2026-09-04 rescript decoupled that entirely — it is a 7b storybook epilogue now, so item 2 means the handoff scene only).

#### The three original gate items

1. **Daphne's 150-마력 level-up ships.** ✅ Shipped — the ✨ magic-light ability; VFX confirmed on device.
2. **Ana's quest begins — the handoff scene, Ana becomes the working tailor.** ✅ Shipped as `TailorHandoffScene`, confirmed on a fresh-install device playtest. Satisfied on the v1 reading recorded in Phase 7 above.
3. **A JSON educational-content feature is in place.** ⬜ **Open — the only original gate item still outstanding.** Scope confirmed with the owner 2026-09-08: *finish it properly*, do not redefine it away and do not cut it. The mechanism already exists and works — `RiddleBank.load()` in `Model/Riddle.swift` reads `Documents/riddles.json` and falls back to 15 hardcoded riddles (8 math, 7 Korean trivia). What is missing is **reachability, not logic**:
   - ✅ **Done 2026-09-08:** `INFOPLIST_KEY_UIFileSharingEnabled = YES` and `INFOPLIST_KEY_LSSupportsOpeningDocumentsInPlace = YES`, both build configs. Parents can now reach the app's `Documents/` folder from the Files app — this is the no-login delivery mechanism the V2 "parent-facing riddle editor" note was looking for. Note: this project sets `GENERATE_INFOPLIST_FILE = YES` and has **no `Info.plist` file to edit** — every plist key lives in `project.pbxproj` as an `INFOPLIST_KEY_*` build setting. A session looking for `Info.plist` will not find one.
   - Seed a default `riddles.json` into `Documents/` on first launch (absent-only, never overwriting a parent's edits), so a parent opening the Files app finds an editable file in the real format rather than an empty folder. Load order becomes `Documents/` → bundled resource → a small hardcoded last resort.
   - **Content decided 2026-09-08 — this replaces the shipped question set entirely.** The 15 hardcoded questions (8 arithmetic, 7 Korean trivia) were debug fixtures written to make tap-through testing fast during development; they are not the product. v1 ships **72 questions, 18 each across four categories, at Korean 3rd-grade (초등학교 3학년) level**: `addSub` 덧셈과 뺄셈, `mulDiv` 곱셈과 나눗셈, `enToKo` 영한 단어 암기, `koToEn` 한영 단어 암기. Category is a real `Riddle` field (stable ASCII id in the JSON, Korean display name resolved in code) and is shown to the player as a label in `RiddleScene` — **not** a picker, which is v2. The 영한/한영 pair deliberately reuses one word list in both directions, since repetition is the only pedagogy available without explanations.
   - **Superseded:** `RIDDLE_BANK.md`'s Music / Science / Sports / Food draft bank. Those four become **paid subject packs in v2** (science, history, music, etc., via IAP). No StoreKit or purchase plumbing in v1 — the JSON schema just has to accommodate additional pack *files* later, not additional *fields*.
   - **Declined for v1, do not re-add:** an `explanation` field or any post-answer teaching moment, and any change to the retry rule. A wrong answer shakes the bubble and the child retries, unlimited and unpenalised. The consequence is deliberate and should shape the store listing: v1 teaches through exposure and repetition, so the honest pitch is "72 questions across four subjects, free," not "teaches your child."
   - Content quality is protected mechanically rather than by review alone — the sprint adds `DesignerAnaTests` coverage that loads the *shipped* JSON and asserts four choices, exact `answer`∈`choices` string match (the comparison `handleAnswer(index:)` actually uses — whitespace here makes a question unanswerable), no duplicates, correct per-category counts, a spread of answer positions, and an arithmetic self-check that regex-parses each math question and evaluates it.
   - A short parent-facing note on the format (`question`, `choices` ×4, `answer`, optional `reward` defaulting to 15).
   - Decide the malformed-JSON behavior. Today `loadFromDocuments()` silently falls back to defaults on any decode failure — safe, but a parent who typos gets no signal their file was ignored.

#### Final-sprint code items (v1)

**A full sprint prompt for these plus the content set lives at `_Prompts/V1Sprint_prompt.md`** (gitignored, main-checkout only — invisible to worktree sessions). It carries the curriculum-verification step, the distractor design rules, the review gate, and the simulator/CI verification checklist.

All bounded, and each verified either this session or in `DIAGNOSTICS_prompt_results.md`.

- ~~**iPad orientation / full-screen validation warning**~~ — **resolved 2026-09-08 by dropping iPad, not by suppressing the warning.** The diagnostics run (§1.1, ranked #1) proposed `UIRequiresFullScreen = YES`; that key turned out to be **deprecated by Apple in September 2025** alongside iPadOS 26's new windowing system, with TN3192 as the migration note and no real replacement for apps that need a fixed full-screen aspect — sources disagree on whether it is already ignored or merely on notice. Building the v1 fix on it would have been building on sand. Instead: **`TARGETED_DEVICE_FAMILY` went `"1,2"` → `"1"` in all four configs.** The warning only ever applied to iPad, so it disappears at its source. The rationale for dropping rather than fixing: `"1,2"` was the Xcode default that nobody ever revisited — there is no iPad playtest anywhere in this project's history, no iPad-specific layout code, and no iPad simulator installed on the owner's machine, so the build claimed a device it had never been run on. `GameViewController.supportedInterfaceOrientations` was simplified in the same pass to return `[.landscapeLeft, .landscapeRight]` unconditionally: UIKit intersects that override with the plist's declared set, so both old branches (`.all` for iPad, `.allButUpsideDown` for iPhone) were dead code that only misled the reader. **Reversible** — iPad is now a deliberate v2 feature with its own QA pass (see V2 expansion ideas), not an untested claim.
- **Bundle weight — ~32.8 MB removable, measured in the real IPA.** 8 unreferenced imagesets plus doubled `GodmotherCat`/`WizardCat` (~11.6 MB), and the loose `ProfileAvatars/*.png` bypassing catalog compression (21.2 MB — move them into the asset catalog). ⚠️ **Not a pure file move:** per Phase 6b's gotcha, catalog imagesets register their PNG under the 2x slot so `texture.size()` returns half the pixel dimensions, while loose PNGs load at 1x. Moving the avatars **will change their apparent scale** — `FrontShopScene.fixCharacterLayout()` must be rechecked, not just the file paths.
- **English display name** — `INFOPLIST_KEY_CFBundleDisplayName` is Korean-only (`묘한 옷 공방`). Needed for an English-locale store listing.
- **Sprite scaling pass** — Tailor/Shopkeeper `setScale` values across `FrontShopScene`, `BackRoomScene`, `AuroraChamberScene`, `PrincessAnaScene` (long-standing, from the June 9 handoff).
- **Dialogue read-through** — `TailorHandoffScene`'s Korean lines were authored during implementation and have never had an owner pass. Plus the general narrative-scene polish pass (owner to supply the revised script).
- **`GAME_VOCABULARY.md` refresh** — long-standing; see "Known gaps" for what has drifted.
- **Texture memory** — several scenes cross 30 MB of real decompressed VRAM, measured via `assetutil` pixel-format inspection rather than inferred from file size. Not a crash today and not a submission blocker; recorded here so v1 sizing decisions are made with the number known.
- ~~`BossMinigameNode.swift:485` force-unwrap~~ — **already resolved; struck from the list 2026-09-08.** Verified by grep: zero `self!.` remain anywhere under `DesignerAna/`, and line 485 is now `scheduleNextAttack()` using `[weak self]` / `self?.`. This item had been carried on every remaining-work list since the June 13 memory analysis without anyone rechecking it.
- **`MinigameNode`/`BossMinigameNode` extraction — explicitly NOT a v1 item.** The duplication is real (27 shared function names, ~68% line match within them), but its urgency argument assumed Ana's puzzle minigames would be more copies of this scaffolding. They won't be, and they're 7b now. Worth doing on its own merits, after v1.
- **xcasset renames** — owner renames in Xcode, Claude does the code-side string replacements (rename table in the June 9 handoff). Cosmetic; first thing to cut if the sprint tightens.

#### Submission lane (new — no prior session tracked this)

None of this is code, and none of it can be started late.

- **App Store Connect app record.** Bundle ID `com.annyeongbirdie.thepurrfectstitch` is set; the paid team `VQ4643X8XU` is verified.
- **Privacy policy URL** — required for every submission. The app collects nothing and stores only local `UserDefaults`, which makes the policy short but does not make it optional.
- **Age rating questionnaire** — and, because the audience is 8-year-olds, **decide deliberately whether this lands in the Kids Category.** If it does, Apple's rules are materially stricter (no third-party analytics, a parental gate on any external link). Better decided now than discovered at review. Note this interacts with gate item 3: a parent-editable riddles file is a genuine argument for the educational positioning.
- **Screenshots** per required device size — `Screenshots/` already holds material to work from.
- **Store listing copy** — Korean and English; ties to the display-name item above.
- **Re-archive and re-run `-validate-for-store`** once the orientation fix lands. The diagnostics run proved this catches things nothing else in this project's workflow does.

#### What is explicitly NOT in v1

Ana's puzzle dungeons, her currency, clue collection, the Estelle epilogue, Daphne's potion-cooking side quest, King/Queen tailors, the `MinigameNode`/`BossMinigameNode` extraction, and **iPad support**. That is all of Phase 7b, plus the refactor and the device-family decision above. **If a session finds itself working on any of these, it is not working on v1.**

### Currency & economy

Two separate currencies with distinct economic shapes:

- **Customer's 냥 (`Wallet.shared.balance`)** — circular economy. Starts at 0냥 on a fresh install or 새 손님 reset. Depleted by front-shop deposits; replenished by dungeon chest refunds (크만할래 path) and shopkeeper riddle rewards. The wardrobe is the stamp-collection win condition. A brand-new customer starts broke and earns their way in. **Exception:** the customer handoff after the relics quest (`FrontShopScene.triggerCustomerPickerAfterSave`, set by `PrincessAnaScene`) does *not* reset wallet/wardrobe — the just-finished order's trophy is saved first, then the picker lets the player choose the next customer without wiping what was just earned. This is a deliberate judgment call (wiping immediately after a save would feel like a bug), not a full 새 손님 reset — worth revisiting if it reads as inconsistent with the "new customer starts broke" rule.
- **Tailor's 마력 (`Magic.shared.points`, 🐾)** — expansive economy, specifically Daphne's wizard-taught magic. Monotonically grows from dungeon chest rewards (10 / 20 / 30 / 50 마력 at cabinet / sewing / buttons / boss). Never decreases: 그만할래 refunds the customer's full deposit to `Wallet` but `Magic` is untouched (it's monotonic — no rollback needed). Tied to the tailor's wizard-apprentice growth arc and Aurora mentorship dialogue. **Not shared with Ana** — Phase 7's Tailor Identity system gives her a separate fairy-taught currency with her own name and thresholds, not yet built.

**그만할래 quit dialog** (back room): single confirm + cancel. Customer gets a full deposit refund (`Wallet.shared.balance += depositAmount`); 마력 earned during the session stays in `Magic.shared.points`.

**새 손님 reset** (button in SettingsScene): calls `Store.resetCustomerSide()`, which zeroes `Wallet`, empties the wardrobe, clears badge counters, clears the active order, and clears the `customer.selected` sticky flag. Tailor-side state — `Magic.shared.points`, future relics, dungeon progress, and the global storybook — is untouched. After reset, the app re-routes to the first-launch customer picker.

**Persistence schema:** flat `UserDefaults` keys; no per-customer namespacing. Only one customer is "alive" at a time, identified by `customer.selected` (holds the avatar asset-name string, e.g. `"ChefCat"`). The shopkeeper riddle still credits `Wallet.shared.balance` — it's shopkeeper-driven, customer-side. **Planned change (Phase 7, not yet built):** re-key both `Wallet.balance` and the wardrobe by customer identity (e.g. `wallet.balance.<customerAssetName>`) so each avatar persona keeps their own separate economy and trophy case — confirmed direction as of 2026-09-04 ("the wardrobe is theirs, not the shop's"), assessed as a contained change given `Wallet`'s small read/write surface and this file's existing clean seam. Side effect once built: a *returning* customer (picked again after being away) would keep their old balance/wardrobe rather than starting broke — a real feature (recurring customers with persistent progress), not just an implementation detail.

**Minigame rewards (shipped):** 10 / 20 / 30 / 50 마력 awarded on chest open at cabinet / sewing / buttons / boss — credited directly to `Magic.shared.add()` in `MinigameNode` and `BossMinigameNode`.

### V2 expansion ideas (post-roadmap)

Captured here so they're not lost; not planned for current phases.

- **Adaptive difficulty easing for station minigames.** Track death count per minigame attempt and reduce hazard density after N deaths (fewer chasms, slower monsters, longer safe gaps in button rain) so kids don't get stuck. Auto-reset to default difficulty on success. The 냥 reward should not scale down with eased difficulty — the easing exists to keep play sessions positive, not to discourage skill development.

- **Guardian reframe for the mannequin level (visual seed already in place).** The boss-on-chest reveal animation that plays on boss defeat in `BossMinigameNode` was deliberately planted as a seed for a future "guardian" iteration of the same level: replace the fight with a puzzle where the player lures a giant dust monster off the chest into a trap, rather than damaging it. Educational angle — observation and planning over reflexes. The visual continuity (boss-on-chest at defeat) makes the reframe feel like a deepening of the same level rather than a contradiction.

- **Per-customer wallet and wardrobe (not yet built).** Currently `Wallet.shared.balance` and the wardrobe are flat/global — one "current customer" slot, no namespacing (see Persistence schema above). Considered in a 2026-09-03 session: re-key both by customer identity (e.g. `wallet.balance.<customerAssetName>`) so each of the 9 avatar personas has their own separate economy and trophy case, rather than a new customer inheriting whatever the previous one earned. Owner confirmed the wardrobe should follow the same per-customer model as the wallet ("the wardrobe is theirs, not the shop's") — both move together, not just the wallet. Assessed as a contained change: `Wallet`'s read/write surface is small (`FrontShopScene` payment, `BackRoomScene`'s 그만할래 refund, `RiddleScene`'s reward), and `Store.swift` already isolates all persistence behind clean load/save functions. Side effect worth knowing: this makes 새 손님 mostly redundant for a *returning* customer — a previously-used persona picked again later would keep their own old balance/wardrobe rather than starting broke, which is a meaningfully different feature (recurring customers with persistent progress) than exists today. Not yet scoped or implemented.
- **iPad support (dropped from v1 on 2026-09-08 — see the v1 ship gate for the full rationale).** `TARGETED_DEVICE_FAMILY` is `"1"` (iPhone only). Bringing iPad back is a real piece of work, not a flag flip, and it now has to be done Apple's way rather than with `UIRequiresFullScreen` — that key is deprecated and has no direct replacement for fixed-aspect apps. What it would take: adopt `UIWindowScene.sizeRestrictions` (a preference, not a guarantee — the system makes a best-effort attempt only, and it can be `nil` on older iPadOS with Stage Manager), then make the scenes actually survive being resized. That last part is the expensive half: every scene in this codebase positions nodes with hand-tuned absolute values and fraction-of-`size` math, plus the per-sprite transparent-padding table, all tuned against a phone aspect ratio. Budget a real layout pass and a real iPad playtest, not a build-setting change. Apple's TN3192 is the migration note to start from.
- **Parent-facing riddle editor, without a login gate.** ⚠️ **Partly promoted to v1 on 2026-09-08 — read the v1 ship gate's item 3 first.** The owner confirmed the ship gate's JSON educational-content criterion is met by *reachability*: Files-app sharing (`UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace`) plus a seeded default `riddles.json`, which is the "share-sheet/Files-app import flow" candidate below and honours the no-login constraint. **What stays a V2 idea is the in-app editor UI**, not the capability. `RiddleBank.load()` already supports a parent-editable `Documents/riddles.json` override (falls back to 15 hardcoded defaults). What's still unsolved: parents currently have no interface to actually create/edit that file. The owner deliberately wants to avoid an account/login system — for a kids' educational app, that opens data-retention and privacy-law questions (COPPA-adjacent) they'd rather not take on. Needs a no-login delivery mechanism: candidates floated include a share-sheet/Files-app import flow, an iCloud Drive drop folder, or an in-app editable list UI with no account at all. Not scoped or decided — flagged here so the constraint (no login) and the goal (parent-editable riddles) aren't lost before this gets designed properly.

## Closing handoff procedure

At session end, when updating `DesignerAna_handoff.md` (the "closing handoff"), **stamp the date by running `bash date` and using that value** — do not infer the date from file timestamps, previous handoffs, or memory. The handoff date must reflect the session it documents. We made this mistake once (handoff dated May 29 for work done June 2), which caused confusion at the next session's start.

If a closing handoff doesn't happen (the owner closes the laptop unexpectedly), the owner has committed to returning to the same Cowork session next time rather than opening a new one — so the absence of a closing handoff unambiguously defines the session's status. A fresh session is the signal that a proper closing handoff was written; a resumed session is the signal that it wasn't.
