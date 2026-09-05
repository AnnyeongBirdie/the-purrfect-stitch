//
//  TailorHandoffScene.swift
//  DesignerAna
//
//  Phase 7 — the 300-마력 handoff scene. Presented from FrontShopScene right
//  after a finished garment is saved to the wardrobe (see FrontShopScene's
//  handleSaveTrophy — the gate deliberately lives there, not in
//  BackRoomScene, so the sequence reads as "Daphne's order is saved, THEN
//  she leaves" rather than implying Ana finished a dress she never touched).
//  Reuses DaphneBecomesTailorScene's exact 2-slot format and backdrop.
//
//  Story (locked 2026-09-04 rescript, see CLAUDE.md):
//    Act 1 — Aurora, Polaris and Daphne at the shop. Aurora acknowledges
//      Daphne's growth, Polaris thanks her, Daphne asks to return to her
//      apprenticeship, Aurora agrees and teleports them both out.
//    Act 2 — Polaris, now tailor-less, wonders what to do about the
//      dungeon. Princess Ana visits, offers her fairy-taught magic in
//      exchange for full dungeon access to search for her sister Estelle.
//      Polaris agrees, reading it as a good business deal.
//    Outro — switches the active tailor to Ana and hands off to the
//    existing customer-picker flow.
//
//  Background:  Tailorshop_Background (front shop)
//  Speakers (NarrativeHUD has only two portrait slots — left/right — no
//  third centered portrait; a third speaker always shares an existing slot
//  with another character, swapped in/out via hideSpeaker/revealSpeaker.
//  This is the pattern DaphneBecomesTailorScene actually ships with, even
//  though its own header comment still describes an abandoned centered-
//  portrait idea — don't trust that comment, trust the SpeakerConfig slots):
//    left  → 마법사 오로라 (Aurora), then 아나 공주 (Ana) reuses the same
//            slot once Aurora has left
//    right → 가게 주인 폴라레스 (Polaris) and 재봉사 다프네 (Daphne) share
//            this slot, swapped depending on who's part of the active
//            exchange — Polaris while she isn't, Daphne while she is
//

import SpriteKit
import UIKit

class TailorHandoffScene: SKScene {

    // MARK: - Beat data

    private struct Beat {
        let speaker: String
        let text: String
    }

    // Beats 0-10. Beat 2 swaps Daphne into the shared right slot; beat 3
    // triggers the Aurora/Daphne teleport-out on the next tap; beat 5
    // triggers Ana's entrance on the next tap.
    private let beats: [Beat] = [
        // 0
        Beat(speaker: "마법사 오로라", text: "다프네, 마력이 정말 많이 늘었더구나. 대견하다."),
        // 1
        Beat(speaker: "가게 주인 폴라레스", text: "다프네, 그동안 손님들 응대하느라 애 많이 썼어요. 정말 고마웠어요."),
        // 2 — Daphne swaps into the shared right slot (Polaris swaps out)
        Beat(speaker: "재봉사 다프네", text: "선생님, 저 이제 다시 견습 마법사로 돌아가도 될까요? 아직 배우고 싶은 게 많아요."),
        // 3 — teleport-out fires on the next tap after this beat is shown
        Beat(speaker: "마법사 오로라", text: "물론이지. 자, 우리 다시 돌아가자꾸나."),
        // 4 — shown after the teleport completes (Polaris swaps back in)
        Beat(speaker: "가게 주인 폴라레스", text: "언니, 잘 가요! 다프네도 잘 지내렴!"),
        // 5 — Ana's entrance fires on the next tap after this beat is shown
        Beat(speaker: "가게 주인 폴라레스", text: "...그나저나, 몬스터 소굴이 되어버린 지하는 이제 어떻게 하지?"),
        // 6 — shown after Ana's entrance completes
        Beat(speaker: "가게 주인 폴라레스", text: "어머, 아나 공주님 아니세요? 직접 주문을 하러 오시다니, 하인을 보내신 게 아니고요?"),
        // 7
        Beat(speaker: "아나 공주", text: "저는 제 어린 친구 다프네 때문에 왔어요. 그리고... 사라진 저희 언니, 에스텔 공주님 때문이기도 하고요."),
        // 8
        Beat(speaker: "가게 주인 폴라레스", text: "다프네는 다시 마법 공부를 하러 돌아갔답니다. 그래서 지금 이 던전을 다룰 재봉사가 없어요."),
        // 9
        Beat(speaker: "아나 공주", text: "제 요정 대모님, 플로라님께 배운 마법이 있어요. 그 마법을 이곳에서 쓸 테니, 대신 던전을 자유롭게 드나들게 해주시겠어요? 언니를 찾고 싶어요."),
        // 10 — outro fires on next tap
        Beat(speaker: "가게 주인 폴라레스", text: "좋아요, 아주 좋은 거래로군요."),
    ]

    // MARK: - State

    private var beatIndex = 0

    /// Set after beat 3; next tap triggers the Aurora/Daphne teleport-out.
    private var readyForTeleport = false
    /// Blocks taps while the teleport-out is playing.
    private var waitingForTeleport = false
    /// Set after beat 5; next tap triggers Ana's entrance.
    private var readyForAna = false
    /// Blocks taps while Ana is fading in.
    private var waitingForAna = false
    /// Guards against double-exit.
    private var exiting = false

    // MARK: - HUD

    private var hud: NarrativeHUD!

    // MARK: - Character sprites (zPosition 5/6, behind HUD at 50)

    private var auroraSprite:  SKSpriteNode!
    private var polarisSprite: SKSpriteNode!
    private var daphneSprite:  SKSpriteNode!
    private var anaSprite:     SKSpriteNode!

    // MARK: - Scene setup

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        setupBackdrop()
        setupCharacters()
        setupHUD(safeBottom: view.safeAreaInsets.bottom)
    }

    private func setupBackdrop() {
        let bg = SKSpriteNode(imageNamed: "Tailorshop_Background")
        bg.position  = .zero
        bg.size      = size
        bg.zPosition = 0
        addChild(bg)
    }

    // MARK: - Character sprites

    private func setupCharacters() {
        let tailorH: CGFloat = 240
        let adultH:  CGFloat = 310

        // Aurora — left side, facing right toward Polaris. Present from the
        // start (no magic entrance here — she's already visiting the shop).
        let aurora = SKSpriteNode(imageNamed: "WizardCat")
        if aurora.size.height > 0 { aurora.setScale(adultH / aurora.size.height) }
        aurora.xScale  *= -1
        aurora.position = CGPoint(x: -size.width * 0.22, y: -size.height * 0.10)
        aurora.zPosition = 5
        addChild(aurora)
        auroraSprite = aurora

        // Polaris — right side, unchanged position for the entire scene.
        let polaris = SKSpriteNode(imageNamed: "Shopkeeper")
        if polaris.size.height > 0 { polaris.setScale(adultH / polaris.size.height) }
        polaris.position = CGPoint(x: size.width * 0.22, y: -size.height * 0.15)
        polaris.zPosition = 5
        addChild(polaris)
        polarisSprite = polaris

        // Daphne — center, present from the start; leaves with Aurora.
        let daphne = SKSpriteNode(imageNamed: "Tailor")
        if daphne.size.height > 0 { daphne.setScale(tailorH / daphne.size.height) }
        daphne.position  = CGPoint(x: 0, y: -size.height * 0.15)
        daphne.zPosition = 6
        addChild(daphne)
        daphneSprite = daphne

        // Ana — reuses Aurora's vacated left position; hidden until she visits.
        let ana = SKSpriteNode(imageNamed: "SecondPrincessCat")
        if ana.size.height > 0 { ana.setScale(adultH / ana.size.height) }
        ana.xScale  *= -1   // face right toward Polaris (default art faces left)
        ana.position = CGPoint(x: -size.width * 0.22, y: -size.height * 0.10)
        ana.zPosition = 5
        ana.alpha    = 0
        addChild(ana)
        anaSprite = ana
    }

    // MARK: - HUD setup

    private func setupHUD(safeBottom: CGFloat) {
        hud = NarrativeHUD()
        hud.zPosition = 50
        addChild(hud)

        hud.configure(
            speakers: [
                SpeakerConfig(
                    name: "마법사 오로라",
                    portraitAsset: "Portrait_Aurora",
                    slot: .left,
                    nameColor: UIColor(red: 0.37, green: 0.78, blue: 0.72, alpha: 1.0)
                ),
                SpeakerConfig(
                    name: "가게 주인 폴라레스",
                    portraitAsset: "Portrait_Polaris",
                    slot: .right,
                    nameColor: UIColor(red: 0.91, green: 0.63, blue: 0.63, alpha: 1.0)
                ),
                SpeakerConfig(
                    name: "재봉사 다프네",
                    portraitAsset: "Portrait_Daphne",
                    slot: .right,     // shares the right slot with Polaris; swapped in for her line
                    nameColor: UIColor(red: 1.0, green: 0.84, blue: 0.31, alpha: 1.0)
                ),
                SpeakerConfig(
                    name: "아나 공주",
                    portraitAsset: "Portrait_Ana",
                    slot: .left,     // shares Aurora's slot; she's gone by the time Ana enters
                    nameColor: UIColor(red: 0.30, green: 0.72, blue: 0.48, alpha: 1.0)
                ),
            ],
            sceneSize: size,
            safeBottom: safeBottom
        )

        // Only Aurora and Polaris start revealed — Daphne shares Polaris's
        // slot and is swapped in only once she actually speaks (beat 2).
        hud.revealSpeakers(["마법사 오로라", "가게 주인 폴라레스"], activeSpeaker: "마법사 오로라")
        hud.show(speaker: beats[0].speaker, text: beats[0].text)
    }

    // MARK: - Aurora/Daphne teleport-out

    private func performTeleportOut() {
        waitingForTeleport = true
        let auroraColor = UIColor(red: 0.60, green: 0.30, blue: 0.90, alpha: 1.0)
        spawnSparkles(at: auroraSprite.position, color: auroraColor)
        spawnSparkles(at: daphneSprite.position, color: auroraColor)

        hud.hideSpeaker(named: "마법사 오로라")
        hud.hideSpeaker(named: "재봉사 다프네")

        auroraSprite.run(.fadeOut(withDuration: 0.8))
        daphneSprite.run(.fadeOut(withDuration: 0.8)) { [weak self] in
            guard let self else { return }
            self.waitingForTeleport = false
            self.beatIndex = 4
            // Polaris swaps back into the right slot now that Daphne's gone.
            self.hud.revealSpeaker(named: "가게 주인 폴라레스")
            self.hud.show(speaker: self.beats[4].speaker, text: self.beats[4].text)
        }
    }

    // MARK: - Ana entrance

    private func enterAna() {
        waitingForAna = true
        anaSprite.run(.fadeIn(withDuration: 0.8)) { [weak self] in
            guard let self else { return }
            self.hud.revealSpeaker(named: "아나 공주")
            self.waitingForAna = false
            self.beatIndex = 6
            self.hud.show(speaker: self.beats[6].speaker, text: self.beats[6].text)
        }
    }

    // MARK: - Sparkles helper

    private func spawnSparkles(at position: CGPoint, color: UIColor) {
        for i in 0..<10 {
            let spark = SKShapeNode(circleOfRadius: 4)
            spark.fillColor   = color
            spark.strokeColor = .clear
            spark.position    = position
            spark.zPosition   = 20
            addChild(spark)
            let angle  = CGFloat(i) / 10 * .pi * 2
            let radius = CGFloat.random(in: 35...65)
            let target = CGPoint(
                x: position.x + cos(angle) * radius,
                y: position.y + sin(angle) * radius
            )
            spark.run(.sequence([
                .move(to: target, duration: 0.40),
                .fadeOut(withDuration: 0.25),
                .removeFromParent()
            ]))
        }
    }

    // MARK: - Beat advancement

    private func advanceBeat() {
        beatIndex += 1
        guard beatIndex < beats.count else {
            startOutro()
            return
        }

        if beatIndex == 2 {
            // Daphne swaps into the shared right slot for her line.
            hud.hideSpeaker(named: "가게 주인 폴라레스")
            hud.revealSpeaker(named: "재봉사 다프네")
        }

        hud.show(speaker: beats[beatIndex].speaker, text: beats[beatIndex].text)

        switch beatIndex {
        case 3:
            readyForTeleport = true
        case 5:
            readyForAna = true
        default:
            break
        }
    }

    // MARK: - Outro

    private func startOutro() {
        exiting = true
        guard let view = self.view else { return }

        // The garment was already saved to the wardrobe before this scene
        // was presented (see FrontShopScene.handleSaveTrophy) — this scene
        // only needs to flip the active tailor and hand off to the picker.
        Store.saveCurrentTailor("ana")

        let picker = SettingsScene(size: self.size)
        picker.scaleMode = .resizeFill
        picker.isFirstLaunchPicker = true
        view.presentScene(picker, transition: SKTransition.crossFade(withDuration: 0.6))
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !exiting, touches.first != nil else { return }

        // Block during animated transitions.
        if waitingForTeleport || waitingForAna { return }

        // Beat 3: trigger the teleport-out on the player's tap.
        if readyForTeleport {
            readyForTeleport = false
            performTeleportOut()
            return
        }

        // Beat 5: trigger Ana's entrance on the player's tap.
        if readyForAna {
            readyForAna = false
            enterAna()
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
