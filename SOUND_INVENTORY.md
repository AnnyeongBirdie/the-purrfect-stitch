# Sound Inventory — DesignerAna

Tracks every sound effect the game needs, where it plays, and its
sourcing + wiring status. This is the working file for **Phase 4 —
Audio pass** in the roadmap (`CLAUDE.md`). Audio is a **v1 release
gate**: v1 ships with working sound.

All SFX route through `SoundManager.shared.play(_:on:)`. Bundled MP3s
live in `DesignerAna/SoundEffects/` (tracked). Raw, un-renamed source
downloads are staged in `_RawAssets/SoundEffects/` (local-only, not
tracked).

**Status legend**

- Sourced — a royalty-free MP3 exists and is renamed into `DesignerAna/SoundEffects/`.
- Wired — `SoundManager` is actually called at the right moment in code.

Sourcing royalty-free MP3s is the current blocker and is owner-driven.

---

## Front shop — ambient / UI

| SFX | Plays on | Sourced | Wired | Source file | Note |
|---|---|---|---|---|---|
| `sfx_shop_bell` | Scene load on genuine entries (app launch, back-room return) | yes | yes | `dragon-studio-bell-ring-390294` | - |
| `sfx_button_tap` | All choice buttons (clothing, color, confirm) | yes | yes | `freesound_community-ui-click-97915` | - |
| `sfx_order_stamp` | Order confirmed | yes | yes | koiroylers-correct-356013 | ✅ owner swapped to a shorter clip after device playtest (previous puyopuyo winner was ~6s — too long). |
| `sfx_coin_pay` | Deposit paid | yes | yes | `freesound_crunchpixstudio-drop-coin-384921` | - |
| `sfx_transition_fade` | Scene transitions | yes | yes | floraphonic-marimba-bloop-3-188151 | ✅ new clip swapped in. |

## Back room — ambient / walking

| SFX | Plays on | Sourced | Wired | Source file | Note |
|---|---|---|---|---|---|
| `sfx_tailor_walk` | (un-wired) was: footstep when the tailor walks | yes | no — un-wired (owner felt watching the tailor travel is enough; no audio needed) | freesounds123-walking-on-wood-363349 | ✅ `play` calls + the `stop` cleanups removed from both `moveTailor` variants and from `presentMinigame`/`presentBossMinigame` in `BackRoomScene`. MP3 kept in `SoundEffects/`. |
| `sfx_station_unlock` | Small sparkle / "ding" when a station becomes ready | yes | yes | floraphonic-90s-game-ui-6-185099 | - |
| `sfx_halo_expand` | Sustained warm bloom as the halo fills the screen at completion | yes | yes | yodguard-healing-magic-6-378666 | - |
| `sfx_wardrobe_sparkle` | (retired) was: soft shimmer for the fireflies on the wardrobe badge | yes | no — retired (fireflies removed, no replacement cue) | freesound_community-birdfish-happy-loop-6199 | ✅ `spawnWardrobeSparkle()` + its call site deleted from `FrontShopScene`. MP3 kept in `SoundEffects/` in case the cue is revived. |

## Minigame — movement

| SFX | Plays on | Sourced | Wired | Source file | Note |
|---|---|---|---|---|---|
| `sfx_jump` | Hero jump (light boing / spring) | yes | yes | freesound_community-cartoon-jump-6462 | - |
| `sfx_land` | Hero landing (soft thud) | yes | no — un-wired (owner felt the thump was unnecessary) | freesound_community-thump-2-79980 | ✅ Removed the `play` calls in both `MinigameNode` and `BossMinigameNode` update loops. MP3 kept in `SoundEffects/`. |
| `sfx_hero_hurt` | Hero death — short, gentle sting (this is for kids) | yes | yes | universfield-error-08-206492 | ✅ owner swapped clip after device playtest. |

## Minigame — combat & progression

| SFX | Plays on | Sourced | Wired | Source file | Note |
|---|---|---|---|---|---|
| `sfx_monster_stomp` | Monster defeated (satisfying pop / squish) | yes | yes | musheran-cartoon-sad-face-squish-385356 | - |
| `sfx_dungeon_fanfare` | Short ~2s dungeon entry jingle ("보물 던전에 입장!") | yes | no — un-wired pending a better clip (repetitive on replay) | pwlpl-countdown-beep-377323 | - |
| `sfx_chest_open` | Treasure chest opens (creak + sparkle) | yes | yes | litupsubway-ui-open-sfx-513358 | - |
| `sfx_coin_earn` | Ascending coin jingle for the "+X냥" pop-up | yes | yes | 49447089-game-start-317318 | - |
| `sfx_station_complete` | Short celebration sting after a station clears | yes | yes | doubleducks-11l-game_complete_notifi-1749489486836-360350 | ⚠️ new sound switched for testing |

## Boss fight — station 4

| SFX | Plays on | Sourced | Wired | Source file | Note |
|---|---|---|---|---|---|
| `sfx_boss_telegraph_slam` | Low rumble for the red slam-pad warning | yes | yes | freesound_community-machine-whir-69490 | ✅ Cut by `stopBossAttackSFX()` on boss defeat / hero death / reset (now possible thanks to the `SoundManager` → `AVAudioPlayer` refactor). |
| `sfx_boss_slam_impact` | Heavy thud when the boss drops | yes | yes | dragon-studio-heavy-boulder-thud-515257 | - |
| `sfx_boss_telegraph_sweep` | Electric / windy charge-up for the sweep | yes | yes | freesound_community-low-hum-32-hz-94656 | - |
| `sfx_boss_sweep_fire` | Sweep projectile whoosh | yes | yes | gregorquendel-designed-fire-winds-swoosh-04-116788 | - |
| `sfx_boss_summon` | Mystical shimmer when minions spawn | yes | yes | koiroylers-mystical-355968 | - |
| `sfx_boss_hit` | Solid impact when the boss takes damage | yes | yes | creatorshome-pop-cartoon-328167 | - |
| `sfx_boss_shield` | Clank / block when hit outside the vulnerability window | yes | yes | freesound_community-dropping_aluminum_ingots3-105968 | - |
| `sfx_boss_defeat` | Celebratory fanfare — the climax of the whole game | yes | yes | freesound_community-fanfare-46385 | - |

## Wardrobe / dressing room

| SFX | Plays on | Sourced | Wired | Source file | Note |
|---|---|---|---|---|---|
| `sfx_trophy_save` | Warm "saved" sound when a garment is stored | yes | yes | floraphonic-marimba-win-b-1-209678 | - |
| `sfx_wardrobe_open` | (retired) was: cabinet-open creak for the dressing-room transition | yes | no — un-wired (the dress nav button's standard `sfx_button_tap` is the only cue for opening here) | soundreality-opening-door-411632 | ✅ `play` call removed from `DressingRoomScene.didMove`. MP3 kept in `SoundEffects/`. |
| `sfx_trophy_tap` | Soft tap for the trophy tap-to-enlarge feature | yes | yes | soundshelfstudio-ui-tap-light-513023 | - |

---

## Summary

| | Count |
|---|---|
| Total SFX needed (in code) | 23 |
| Sourced | 28 |
| Fully wired | 23 |
| Retired | 2 (`sfx_wardrobe_sparkle`, `sfx_wardrobe_open`) |
| Un-wired pending review | 3 (`sfx_dungeon_fanfare`, `sfx_land`, `sfx_tailor_walk`) |

**SoundManager refactor — done this session.** `SoundManager` now wraps
`AVAudioPlayer` instead of `SKAction.playSoundFileNamed`, with a pool of
in-flight players keyed by filename. New API: `play(_:)` (no longer takes
`on: SKNode`), `stop(_:)`, `stopAll()`. `stop(_:)` is wired into two leak
spots that the old API couldn't reach: footstep audio at minigame entry
and on walk completion (`BackRoomScene`), and the boss attack telegraphs
on defeat / hero death / reset via `stopBossAttackSFX()` in
`BossMinigameNode`. `toggleMute()` now also calls `stopAll()`.

**Un-wired pending review (3):**

- `sfx_dungeon_fanfare` — un-wired in an earlier session (repetitive on
  replay). Re-wire by adding `SoundManager.shared.play("sfx_dungeon_fanfare.mp3")`
  back into `buildDungeon()` in `MinigameNode` once a replacement is chosen.
- `sfx_land` — un-wired (owner felt the thump was unnecessary). Re-wire
  in the landing branch of `update()` in both `MinigameNode` and
  `BossMinigameNode` if reconsidered.
- `sfx_tailor_walk` — un-wired (owner felt watching the tailor travel
  is enough). Re-wire by re-introducing `play("sfx_tailor_walk.mp3")` in
  one or both `moveTailor` variants in `BackRoomScene`.

**Retired (2):**

- `sfx_wardrobe_sparkle` — the fireflies-on-dress-icon visual was removed
  alongside the sound. `spawnWardrobeSparkle()` deleted from `FrontShopScene`.
- `sfx_wardrobe_open` — the dressing-room entry now uses the standard nav-button
  `sfx_button_tap`, matching settings/wallet/storybook.

Both retired MP3s are still on disk in `SoundEffects/` in case either cue
is revived. The "in code" total in the count table excludes retired and
un-wired entries.
