---
name: minigame-station
description: Use this skill when building, modifying, or extending a station minigame in DesignerAna's BackRoomScene — adding a new station (sewing, button, mannequin), refactoring shared minigame mechanics in MinigameNode, or changing per-station hazards / monsters / treasure. Do NOT use for FrontShopScene work, asset-only changes, or back-room logic outside the minigame overlay.
---

# Minigame Station Recipe

This skill encodes how DesignerAna's station minigames are structured so the second, third, and fourth stations can be built without rediscovering the architecture. The fabric cabinet shipped first as proof of concept; everything below was derived from that implementation.

Read these files before doing anything: `CLAUDE.md` (project overview), `Scene/MinigameNode.swift`, `Model/MinigameStation.swift`, `Scene/BackRoomScene.swift`.

## Project context

iOS SpriteKit game, Swift 5, iOS 26.2 deployment target. Preferred simulator is **iPhone 16e** (iPhone 16 is *not* installed — do not target it). No CocoaPods, SPM packages, or external dependencies. See `CLAUDE.md` for the broader architecture — especially the scene flow, the state machines in `FrontShopScene` and `BackRoomScene`, the tailor halo, and the zPosition convention (gameplay 0–15, overlays 50+).

## Architecture

Three pieces collaborate:

- **`MinigameStation` enum + `MinigameConfig` struct** in `Model/MinigameStation.swift` — declares which stations exist and the per-station knobs.
- **`MinigameNode`** in `Scene/MinigameNode.swift` — an `SKNode` (zPosition 50) that hosts the entire minigame: hero, hazards, monster, treasure chest, virtual D-pad. Reads its config and renders accordingly. Fires a completion callback when the player retrieves the treasure.
- **`BackRoomScene`** in `Scene/BackRoomScene.swift` — when the player taps a station, instead of advancing the state machine directly, present a `MinigameNode` over the scene. The completion callback advances the existing state to the same place a successful station tap used to go.

`MinigameNode` uses a `ContactBridge` shim because the node is an `SKNode`, not an `SKScene`, but `physicsWorld.contactDelegate` requires `SKPhysicsContactDelegate`.

## Shared mechanics (every station has these)

- **Hero** — controllable sprite with horizontal movement (`heroSpeed: 160` pts/sec) and jump (impulse derived from `sceneH` at runtime in `setup(in:)`).
- **D-pad** — three buttons (left, right, jump). Place left + right clustered in the **bottom-left** corner; jump in the **bottom-right** corner; semi-transparent so the play area shows through. Do not center the buttons (the current centered placement crowds the play area; corner-split is the standard mobile platformer pattern).
- **Monster defeat** — two paths: stomp from above (Mario-style), or proximity tap when adjacent (`proximityRange: 60` pts).
- **Treasure chest** — appears after monster defeat; contacting or tapping it fires the completion callback with the `MinigameStation` value. `BackRoomScene` uses this to unlock the station's pick (fabric color, button type, etc.).
- **Death handling** — kid-friendly. If the hero contacts the monster without defeating it, falls down a chasm, etc., briefly show a short Korean retry message and reset hero + monster + chest to starting state. **No lives, no 냥 loss, no kick-out to front shop.**
- **Scene size at runtime** — never hardcode dimensions; `setup(in:)` reads `scene.size` and computes everything from there.

## Per-station variations (what `MinigameConfig` exposes)

Each station gets a unique theme and hazard pattern; mechanics stay the same. Knobs:

- **Hazard type and pattern** — a thematic obstacle on a fixed axis.
  - Fabric cabinet: ground chasms / fissures to jump over.
  - Sewing station: scissor-blade obstacles to jump over (single minigame — the "cut + sew" two-minigame split was considered and rejected as adding complexity without clear gameplay value).
  - Button station: buttons fall from the ceiling to dodge.
  - Mannequin: boss arena — see "Boss exception" below.
- **Monster behavior** — difficulty curves across stations: static for the fabric cabinet (tutorial), pacing back-and-forth for sewing, brief lunges for button, full telegraphed attack patterns for mannequin.
- **Monster sprite** — currently a placeholder (purple square + 👾 emoji). Real art will replace it; nothing else depends on the placeholder.
- **Theming** — background colors, hero costume tint, particle effects. Should echo the front-shop fabric color when relevant.
- **Treasure contents** — fabric, thread, buttons, finished dress. Drives the completion-callback handling in `BackRoomScene`.

### Boss exception

The mannequin station is the climax and may use bespoke gameplay (boss fight with telegraphed attack patterns, or multiple smaller monsters). If `MinigameConfig` starts to bend awkwardly to accommodate it, introduce a sibling `BossMinigameNode` instead of forcing the boss through the same config.

## Recipe for adding a new station

1. **Confirm the design** — hazard concept, monster behavior, what the treasure unlocks. Cross-reference "Per-station variations" above.
2. **(If this is station 2) Refactor first.** The fabric cabinet's `MinigameNode` was written as a single-station implementation. Before adding the sewing station, extract the station-specific bits (hazard layout, monster behavior) into config-driven hooks so the third and fourth stations are pure additions. This is the explicit Phase 3 learning goal — don't skip it.
3. **Extend `MinigameStation` enum** — add the new case in `Model/MinigameStation.swift`.
4. **Add a `MinigameConfig` instance** — wire in art, hazard pattern, monster behavior.
5. **Gate the station tap in `BackRoomScene`** — replace the existing station-tap handler's "advance state" with "present `MinigameNode` with this station's config; advance state in the completion callback".
6. **Verify death/respawn** — confirm hero death routes back to minigame start, not back to front shop.
7. **Build** — `xcodebuild -project DesignerAna.xcodeproj -scheme DesignerAna -destination 'platform=iOS Simulator,name=iPhone 16e' build`. Look for `** BUILD SUCCEEDED **`.
8. **Manual test in iPhone 16e simulator** — play through: front-shop order → back room → tap the new station → clear the minigame → confirm the existing state machine advances correctly to the next station.
9. **Update `CLAUDE.md`** — add the new station to the `BackRoomScene` state machine section if its progression changes anything.

## Coding conventions

- Korean-language UI strings inline; no localization layer yet.
- `Order.fabricColor` and `Order.clothingType` are typed as `String`. If you introduce a new typed field for the minigame, prefer enum-from-the-start to avoid the same refactor debt.
- One logical change per commit; commit message body should explain "why" not just "what".
- Scene-specific state stays inside the scene class. `Model/` holds only cross-scene types.
- zPosition: gameplay 0–15, overlays (minigames, modals) 50+.

## What's NOT in scope for this skill

- **Adaptive easing** (auto-reducing hazard count after N deaths) is a v2 idea — see `CLAUDE.md` "V2 expansion ideas".
- FrontShopScene order flow changes.
- Asset creation (image generation, sound design).
- Persistence of `playerMoney` across launches.
