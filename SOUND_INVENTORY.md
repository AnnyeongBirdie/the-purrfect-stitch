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

| SFX | Plays on | Sourced | Wired | Source file |
|---|---|---|---|---|
| `sfx_shop_bell` | Scene load on genuine entries (app launch, back-room return) | yes | yes | `dragon-studio-bell-ring-390294` |
| `sfx_button_tap` | All choice buttons (clothing, color, confirm) | yes | partial — every scene **except** `RiddleScene` and `DressingRoomScene` | `freesound_community-ui-click-97915` |
| `sfx_order_stamp` | Order confirmed | yes | yes | `freesound_community-stamp-102627` |
| `sfx_coin_pay` | Deposit paid | yes | yes | `freesound_crunchpixstudio-drop-coin-384921` |
| `sfx_transition_fade` | Scene transitions | yes | yes | `dheerajakam4jor-swoosh-sound-effect-for-fight-scenes-or-transitions-3-149888` |

## Back room — ambient / walking

| SFX | Plays on | Sourced | Wired | Source file |
|---|---|---|---|---|
| `sfx_tailor_walk` | Two-step footstep loop while the tailor walks to a station | no | no | — |
| `sfx_station_unlock` | Small sparkle / "ding" when a station becomes ready | no | no | — |
| `sfx_halo_expand` | Sustained warm bloom as the halo fills the screen at completion | no | no | — |
| `sfx_wardrobe_sparkle` | Soft shimmer for the fireflies on the wardrobe badge | no | no | — |

## Minigame — movement

| SFX | Plays on | Sourced | Wired | Source file |
|---|---|---|---|---|
| `sfx_jump` | Hero jump (light boing / spring) | no | no | — |
| `sfx_land` | Hero landing (soft thud) | no | no | — |
| `sfx_hero_hurt` | Hero death — short, gentle sting (this is for kids) | no | no | — |

## Minigame — combat & progression

| SFX | Plays on | Sourced | Wired | Source file |
|---|---|---|---|---|
| `sfx_monster_stomp` | Monster defeated (satisfying pop / squish) | no | no | — |
| `sfx_dungeon_fanfare` | Short ~2s dungeon entry jingle ("보물 던전에 입장!") | no | no | — |
| `sfx_chest_open` | Treasure chest opens (creak + sparkle) | no | no | — |
| `sfx_coin_earn` | Ascending coin jingle for the "+X냥" pop-up | no | no | — |
| `sfx_station_complete` | Short celebration sting after a station clears | no | no | — |

## Boss fight — station 4

| SFX | Plays on | Sourced | Wired | Source file |
|---|---|---|---|---|
| `sfx_boss_telegraph_slam` | Low rumble for the red slam-pad warning | no | no | — |
| `sfx_boss_slam_impact` | Heavy thud when the boss drops | no | no | — |
| `sfx_boss_telegraph_sweep` | Electric / windy charge-up for the sweep | no | no | — |
| `sfx_boss_sweep_fire` | Sweep projectile whoosh | no | no | — |
| `sfx_boss_summon` | Mystical shimmer when minions spawn | no | no | — |
| `sfx_boss_hit` | Solid impact when the boss takes damage | no | no | — |
| `sfx_boss_shield` | Clank / block when hit outside the vulnerability window | no | no | — |
| `sfx_boss_defeat` | Celebratory fanfare — the climax of the whole game | no | no | — |

## Wardrobe / dressing room

| SFX | Plays on | Sourced | Wired | Source file |
|---|---|---|---|---|
| `sfx_trophy_save` | Warm "saved" sound when a garment is stored | no | no | — |
| `sfx_wardrobe_open` | Cabinet-open creak for the dressing-room transition | no | no | — |
| `sfx_trophy_tap` | Soft tap for the trophy tap-to-enlarge feature | no | no | — |

---

## Summary

| | Count |
|---|---|
| Total SFX needed | 28 |
| Sourced | 5 |
| Fully wired | 4 |
| Outstanding to source | 23 |

**Wiring gap:** `sfx_button_tap` is sourced but not yet called in
`RiddleScene` or `DressingRoomScene`. Rather than wire that one gap in
isolation, each scene is wired completely — button taps plus its own
SFX — once its full sound set is sourced.
