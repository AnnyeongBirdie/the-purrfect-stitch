//
//  EstelleEpilogueScene.swift
//  DesignerAna
//
//  Phase 7b — the v1 final ending. Presented from FrontShopScene right
//  after a finished garment is saved to the wardrobe, at 3000 마력 in
//  Ana's era (see FrontShopScene.handleSaveTrophy — the gate lives there,
//  not in BackRoomScene, for the same reason the Daphne→Ana handoff gate
//  does: firing before the save would let the epilogue conclude and THEN
//  show the trophy). Reuses NarrativeHUD, the same shape as every other
//  narrative scene; TailorHandoffScene is the closest model.
//
//  ⚠️ This is the one scene in the game that changes backdrop mid-scene —
//  twice. No other narrative scene does this; see transitionToAct2()/
//  transitionToAct3() for how the seam is handled (fade the backdrop
//  sprite out, swap its texture, fade back in — bundled with the
//  character-sprite and HUD-speaker swap for that act boundary).
//
//  ⚠️ PLACEHOLDER DIALOGUE — hard review gate (per _Prompts/
//  EndingSprint_prompt.md task 7). Every line below conveys the beat's
//  required meaning but has NOT been reviewed or rewritten by the owner.
//  Do not treat this as final, shippable dialogue — TailorHandoffScene's
//  lines have the same gap and it is still outstanding; do not create a
//  second one, least of all on the game's final scene.
//
//  All art is real and final as of 2026-09-10 — the last three placeholders
//  (PalaceGuard, Portrait_Estelle_Human, Portrait_Guard) were swapped for
//  the delivered art with no code change, same as every other asset here
//  (TailorDetective_Dungeon, Gyeongbokgung_Palace, Gwanghwamun_Square,
//  Estelle_Human).
//
//  Story (see CLAUDE.md Phase 7b task 7 for the full beat spec):
//    Act 1 — Ana's hideout (TailorDetective_Dungeon). Her magic peaks, a
//      portal opens, she glimpses Estelle alive. The portal is a window,
//      not a door — she is left behind.
//    Act 2 — 경복궁 (Gyeongbokgung_Palace). POV shifts to Estelle and does
//      not shift back. She is human now, believes she has found a palace
//      like home; a guard turns her away for lacking a 한복 and a ticket.
//    Act 3 — 광화문광장 (Gwanghwamun_Square). Put out onto the square, she
//      sketches it, because that is who she is. Closing image: an unseen
//      snail (SnailPet_Rose) slides slowly out of frame — a tease, not a
//      resolution. Rose is a snail again and Estelle is human because
//      outside the kingdom the curse has no hold — see GAME_VOCABULARY.md.
//
//  Background:  TailorDetective_Dungeon → Gyeongbokgung_Palace →
//               Gwanghwamun_Square
//  Speakers (NarrativeHUD has only two portrait slots — left/right; no
//  third centered portrait):
//    left  → 아나 공주 (Act 1 only), then 에스텔 공주 reuses the same slot
//            once Ana's part of the story ends (POV shift, never returns)
//    right → 궁궐 경비원 (Act 2 only)
//

import SpriteKit
import UIKit

class EstelleEpilogueScene: SKScene {

    // MARK: - Navigation (set by StorybookScene for a replay)

    /// When true (launched from StorybookScene), returns to StorybookScene
    /// on exit instead of freezing 마력 accrual and resuming free play.
    /// Replaying the ending must not re-trigger Store.saveGameComplete()'s
    /// side effects, the same way PrincessAnaScene's replay path skips
    /// re-saving the relics-quest-complete flag.
    var isReplayMode = false
    /// Page index within the unified story chapter (4) to return to.
    /// 6 as of 2026-09-10 — was 5 until KingQueenScene (task 8) was
    /// inserted before this page in the chapter.
    var replayReturnPage = 6

    // MARK: - Beat data

    private struct Beat {
        let speaker: String
        let text: String
    }

    // Beats 0-12. Beat 1 triggers the portal-open on the next tap; beat 5
    // triggers the Act 1→2 transition; beat 10 triggers the Act 2→3
    // transition; beat 12 (last) triggers the outro. Beats 2-3 and 6 were
    // added after an owner playthrough (2026-09-09) — see git history for
    // the original, shorter beat set.
    private let beats: [Beat] = [
        // Act 1 — Ana's hideout
        // 0
        Beat(speaker: "아나 공주",
             text: "이 던전이... 나한테 맞춰서 다시 만들어진 것 같아. 이제 여기가 진짜 내 아지트구나."),
        // 1 — portal-open fires on the next tap after this beat is shown
        Beat(speaker: "아나 공주",
             text: "마력이 점점 차오르고 있어... 뭔가 느껴져."),
        // 2 — shown after the portal finishes opening. Ana's first reaction
        // is surprise at seeing a *person* at all — everyone in the kingdom
        // is a cat, so a human is startling before recognition even starts.
        Beat(speaker: "아나 공주",
             text: "어...? 저 안에 사람이 보여! 설마... 우리 왕국엔 사람이 없는데?"),
        // 3 — recognizes her sister specifically by the curly hair and dress.
        Beat(speaker: "아나 공주",
             text: "잠깐, 저 곱슬머리랑 드레스... 어디서 많이 본 것 같은데... 언니? 에스텔 언니야?!"),
        // 4
        Beat(speaker: "아나 공주",
             text: "언니...! 살아있었구나! 그런데... 대체 어디에 있는 거야?"),
        // 5 — Act 1→2 transition fires on the next tap
        Beat(speaker: "아나 공주",
             text: "언니! 내 목소리 안 들려? ...이건 문이 아니라 창문 같아. 나는... 갈 수가 없어."),

        // Act 2 — 경복궁. POV shifts to Estelle and does not shift back.
        // 6 — the first thing Estelle notices on arrival is her own body.
        Beat(speaker: "에스텔 공주",
             text: "어? 내 손이... 이게 뭐지? 내가... 사람이 된 거야?"),
        // 7
        Beat(speaker: "에스텔 공주",
             text: "여기는... 우리 왕국의 궁궐이랑 닮았어. 혹시 내가 돌아온 걸까?"),
        // 8 — the guard's entrance fades in alongside this beat
        Beat(speaker: "궁궐 경비원",
             text: "저기요, 입장권 좀 보여주시겠어요?"),
        // 9
        Beat(speaker: "에스텔 공주",
             text: "입장권이요...? 그게 무엇인가요?"),
        // 10 — Act 2→3 transition fires on the next tap
        Beat(speaker: "궁궐 경비원",
             text: "한복을 입으신 분들은 무료로 입장하실 수 있어요. 그런데 그 옷은... 한복이 아니네요. 죄송하지만 나가주셔야 할 것 같아요."),

        // Act 3 — 광화문광장
        // 11
        Beat(speaker: "에스텔 공주",
             text: "여기는... 대체 어디지? 이렇게 많은 사람들과 이상한 것들은 처음 봐."),
        // 12 — last beat; outro (with the closing snail) fires on the next tap
        Beat(speaker: "에스텔 공주",
             text: "그래도... 이럴 때일수록 그림을 그려야겠어."),
    ]

    // MARK: - State

    private var beatIndex = 0

    /// Set after beat 1; next tap triggers the portal-open.
    private var readyForPortal = false
    /// Set after beat 5; next tap triggers the Act 1→2 transition.
    private var readyForAct2 = false
    /// Set after beat 10; next tap triggers the Act 2→3 transition.
    private var readyForAct3 = false
    /// Blocks taps while any animated transition is playing.
    private var isTransitioning = false
    /// Blocks taps while the intro/outro title slate is on screen.
    private var isShowingSlate = false
    /// Guards against double-exit.
    private var exiting = false

    // MARK: - HUD

    private var hud: NarrativeHUD!

    // MARK: - Scene nodes

    private var backdropSprite: SKSpriteNode!
    private var anaSprite: SKSpriteNode!
    private var estelleSprite: SKSpriteNode!
    private var guardSprite: SKSpriteNode!
    private var portalNode: SKNode?

    // MARK: - Scene setup

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        setupBackdrop()
        setupCharacters()
        setupHUD(safeBottom: view.safeAreaInsets.bottom)
    }

    private func setupBackdrop() {
        let bg = SKSpriteNode(imageNamed: "TailorDetective_Dungeon")
        bg.position  = .zero
        bg.size      = size
        bg.zPosition = 0
        addChild(bg)
        backdropSprite = bg
    }

    // MARK: - Character sprites

    private func setupCharacters() {
        let anaH: CGFloat = 300
        let humanH: CGFloat = 300

        // Ana — Act 1 only. Present from the start, fades out for good at
        // the Act 1→2 transition (POV shift never returns to her).
        let ana = SKSpriteNode(imageNamed: "SecondPrincessCat")
        if ana.size.height > 0 { ana.setScale(anaH / ana.size.height) }
        ana.position  = CGPoint(x: 0, y: -size.height * 0.12)
        ana.zPosition = 5
        addChild(ana)
        anaSprite = ana

        // Estelle — hidden until Act 2 begins.
        let estelle = SKSpriteNode(imageNamed: "Estelle_Human")
        if estelle.size.height > 0 { estelle.setScale(humanH / estelle.size.height) }
        estelle.position  = CGPoint(x: -size.width * 0.14, y: -size.height * 0.12)
        estelle.zPosition = 5
        estelle.alpha     = 0
        addChild(estelle)
        estelleSprite = estelle

        // Palace guard — hidden until he speaks, partway through Act 2.
        let guard_ = SKSpriteNode(imageNamed: "PalaceGuard")
        if guard_.size.height > 0 { guard_.setScale(humanH / guard_.size.height) }
        guard_.xScale  *= -1   // face left toward Estelle
        guard_.position = CGPoint(x: size.width * 0.20, y: -size.height * 0.12)
        guard_.zPosition = 5
        guard_.alpha     = 0
        addChild(guard_)
        guardSprite = guard_
    }

    // MARK: - HUD setup

    private func setupHUD(safeBottom: CGFloat) {
        hud = NarrativeHUD()
        hud.zPosition = 50
        addChild(hud)

        hud.configure(
            speakers: [
                SpeakerConfig(
                    name: "아나 공주",
                    portraitAsset: "Portrait_Ana",
                    slot: .left,
                    nameColor: UIColor(red: 0.30, green: 0.72, blue: 0.48, alpha: 1.0)
                ),
                SpeakerConfig(
                    name: "에스텔 공주",
                    portraitAsset: "Portrait_Estelle_Human",
                    slot: .left,     // reuses Ana's vacated slot once the POV shifts (Act 2+)
                    nameColor: UIColor(red: 0.55, green: 0.35, blue: 0.75, alpha: 1.0)
                ),
                SpeakerConfig(
                    name: "궁궐 경비원",
                    portraitAsset: "Portrait_Guard",
                    slot: .right,
                    nameColor: UIColor(red: 0.35, green: 0.45, blue: 0.60, alpha: 1.0)
                ),
            ],
            sceneSize: size,
            safeBottom: safeBottom
        )

        hud.revealSpeakers(["아나 공주"], activeSpeaker: "아나 공주")

        // Intro slate — signals this scene is structurally different from
        // every other narrative scene (the v1 ending), per owner request
        // after her first full playthrough.
        isShowingSlate = true
        hud.showTitleSlate(text: "에필로그") { [weak self] in
            guard let self else { return }
            self.isShowingSlate = false
            self.hud.show(speaker: self.beats[0].speaker, text: self.beats[0].text)
        }
    }

    // MARK: - Act 1 — portal open

    // Ana's fairy-magic portal — reuses the green/mint palette ported into
    // Tailor.anaPalette (TailorIdentity.swift) for her dungeon ability,
    // rather than inventing a new color language for the same magic.
    private func openPortal() {
        isTransitioning = true

        let anaGreen = UIColor(red: 0.30, green: 0.72, blue: 0.48, alpha: 1.0)
        let anaMint  = UIColor(red: 0.55, green: 0.95, blue: 0.75, alpha: 1.0)

        let portal = SKNode()
        portal.position = CGPoint(x: size.width * 0.20, y: size.height * 0.08)
        portal.zPosition = 4
        portal.setScale(0.05)
        addChild(portal)
        portalNode = portal

        let outer = SKShapeNode(ellipseOf: CGSize(width: 160, height: 220))
        outer.fillColor = anaGreen.withAlphaComponent(0.20)
        outer.strokeColor = .clear
        portal.addChild(outer)

        let mid = SKShapeNode(ellipseOf: CGSize(width: 120, height: 170))
        mid.fillColor = anaGreen.withAlphaComponent(0.45)
        mid.strokeColor = anaMint.withAlphaComponent(0.85)
        mid.lineWidth = 3
        portal.addChild(mid)

        let inner = SKShapeNode(ellipseOf: CGSize(width: 70, height: 110))
        inner.fillColor = UIColor(red: 0.90, green: 1.00, blue: 0.95, alpha: 0.85)
        inner.strokeColor = .clear
        portal.addChild(inner)

        mid.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.30, duration: 0.7),
            .fadeAlpha(to: 0.55, duration: 0.7)
        ])))

        let grow = SKAction.scale(to: 1.0, duration: 0.9)
        grow.timingMode = .easeOut
        portal.run(grow) { [weak self] in
            guard let self else { return }
            self.isTransitioning = false
            self.beatIndex = 2
            self.hud.show(speaker: self.beats[2].speaker, text: self.beats[2].text)
        }
    }

    // MARK: - Act 1→2 transition

    private func transitionToAct2() {
        isTransitioning = true
        hud.hideSpeaker(named: "아나 공주")

        let fadeOutGroup = SKAction.group([
            .fadeOut(withDuration: 0.6),
        ])
        anaSprite.run(fadeOutGroup)
        portalNode?.run(.fadeOut(withDuration: 0.6)) { [weak self] in
            self?.portalNode?.removeFromParent()
            self?.portalNode = nil
        }

        // The one seam in the whole game where a backdrop changes mid-scene:
        // fade the sprite out, swap its texture while invisible, fade back
        // in. Bundled with the character-sprite and HUD-speaker swap above
        // so the whole act boundary reads as one beat, not several.
        backdropSprite.run(.sequence([
            .fadeOut(withDuration: 0.6),
            .run { [weak self] in self?.backdropSprite.texture = SKTexture(imageNamed: "Gyeongbokgung_Palace") },
            .fadeIn(withDuration: 0.6)
        ])) { [weak self] in
            guard let self else { return }
            self.estelleSprite.run(.fadeIn(withDuration: 0.6))
            self.hud.revealSpeaker(named: "에스텔 공주")
            self.isTransitioning = false
            self.beatIndex = 6
            self.hud.show(speaker: self.beats[6].speaker, text: self.beats[6].text)
        }
    }

    // MARK: - Guard entrance (Act 2, beat 8 — quiet fade-in, no tap gate)

    private func revealGuard() {
        guardSprite.run(.fadeIn(withDuration: 0.5))
        hud.revealSpeaker(named: "궁궐 경비원")
    }

    // MARK: - Act 2→3 transition

    private func transitionToAct3() {
        isTransitioning = true
        hud.hideSpeaker(named: "궁궐 경비원")

        guardSprite.run(.fadeOut(withDuration: 0.6))
        // Estelle stays on screen — she's the one being walked out, so she
        // simply remains through the cut to the square outside.

        backdropSprite.run(.sequence([
            .fadeOut(withDuration: 0.6),
            .run { [weak self] in self?.backdropSprite.texture = SKTexture(imageNamed: "Gwanghwamun_Square") },
            .fadeIn(withDuration: 0.6)
        ])) { [weak self] in
            guard let self else { return }
            self.isTransitioning = false
            self.beatIndex = 11
            self.hud.show(speaker: self.beats[11].speaker, text: self.beats[11].text)
        }
    }

    // MARK: - Closing snail + outro

    // The tease, not the resolution — see the file header. No dialogue, no
    // highlight, no camera move: a small SnailPet_Rose drifts slowly across
    // the background and off the far edge while the last beat's text is
    // still on screen, then the scene fades to free play. Rose is a snail
    // again here (not the dungeon yarn monster) because outside the kingdom
    // the curse has no hold — see GAME_VOCABULARY.md.
    private func spawnClosingSnail() {
        let snail = SKSpriteNode(imageNamed: "SnailPet_Rose")
        let targetH: CGFloat = 34
        if snail.size.height > 0 { snail.setScale(targetH / snail.size.height) }
        snail.position  = CGPoint(x: -size.width * 0.42, y: -size.height * 0.34)
        snail.zPosition = 3   // behind Estelle (5), in front of the backdrop (0)
        snail.alpha     = 0
        addChild(snail)

        let drift = SKAction.moveBy(x: size.width * 0.5, y: 0, duration: 6.0)
        drift.timingMode = .linear
        snail.run(.sequence([
            .fadeIn(withDuration: 1.0),
            .group([drift, .sequence([.wait(forDuration: 4.5), .fadeOut(withDuration: 1.5)])]),
            .removeFromParent()
        ]))
    }

    // MARK: - Beat advancement

    private func advanceBeat() {
        beatIndex += 1
        guard beatIndex < beats.count else {
            startOutro()
            return
        }

        hud.show(speaker: beats[beatIndex].speaker, text: beats[beatIndex].text)

        switch beatIndex {
        case 1:
            readyForPortal = true
        case 5:
            readyForAct2 = true
        case 8:
            revealGuard()
        case 10:
            readyForAct3 = true
        default:
            break
        }
    }

    // MARK: - Outro

    // The closing snail plays identically in both modes (it's part of the
    // scene's own content, not a gameplay side effect), then the outro
    // slate signals the scene is ending before either destination — only
    // what happens AFTER the slate differs by mode. See finishOutro().
    private func startOutro() {
        exiting = true
        isShowingSlate = true
        spawnClosingSnail()

        run(.wait(forDuration: 2.0)) { [weak self] in
            guard let self else { return }
            self.hud.showTitleSlate(text: "이야기는 계속됩니다...") { [weak self] in
                self?.isShowingSlate = false
                self?.finishOutro()
            }
        }
    }

    private func finishOutro() {
        guard let view = self.view else { return }

        if isReplayMode {
            // Return to the exact storybook page without re-triggering the
            // real ending's side effects.
            let storybook = StorybookScene(size: size)
            storybook.replayReturnChapter = 4
            storybook.replayReturnPage    = replayReturnPage
            storybook.scaleMode = .resizeFill
            view.presentScene(storybook, transition: SKTransition.crossFade(withDuration: 0.6))
            return
        }

        // Sequence is save (already done, before this scene was presented)
        // → epilogue (this scene) → game complete. Free play begins the
        // moment this flag is set — see Magic.add(_:)'s early return and
        // BackRoomScene's 👑 completion badge.
        Store.saveGameComplete()
        let shop = FrontShopScene(size: self.size)
        shop.scaleMode = .resizeFill
        shop.suppressEntryBell = true
        view.presentScene(shop, transition: SKTransition.crossFade(withDuration: 0.8))
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !exiting, touches.first != nil else { return }

        // Block during animated transitions or the intro/outro title slate.
        if isTransitioning || isShowingSlate { return }

        // Beat 1: trigger the portal-open on the player's tap.
        if readyForPortal {
            readyForPortal = false
            openPortal()
            return
        }

        // Beat 3: trigger the Act 1→2 transition on the player's tap.
        if readyForAct2 {
            readyForAct2 = false
            transitionToAct2()
            return
        }

        // Beat 7: trigger the Act 2→3 transition on the player's tap.
        if readyForAct3 {
            readyForAct3 = false
            transitionToAct3()
            return
        }

        // Last beat: exit.
        if beatIndex == beats.count - 1 {
            startOutro()
            return
        }

        advanceBeat()
    }
}
