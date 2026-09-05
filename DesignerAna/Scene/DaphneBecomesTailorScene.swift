//
//  DaphneBecomesTailorScene.swift
//  DesignerAna
//
//  Backstory scene: how Daphne was hired at the tailor shop.
//  Triggered from the storybook (Chapter 4, page "재봉사 가게") via the
//  "새로운 재봉사 고용" button. Always returns to StorybookScene on exit.
//
//  Background:  Tailorshop_Background (front shop)
//  Speakers (NarrativeHUD only has two portrait slots — left/right; a third
//  speaker always shares an existing slot with another character instead of
//  getting a centered portrait of her own):
//    left  → 마법사 오로라  (Aurora / WizardCat)
//    right → 가게 주인 폴라레스  (Polaris / Shopkeeper) and 재봉사 다프네
//            (Daphne — hidden until beat 10) share this slot, swapped via
//            hideSpeaker/revealSpeaker
//
//  Scene flow:
//    1. Aurora teleports in with a purple magic entrance (automatic on load).
//    2. Aurora and Polaris exchange 10 beats.
//    3. Beat 10: Aurora calls Daphne → readyForDaphne = true.
//    4. Next tap: Daphne appears at center with sparkles.
//    5. Three-way dialogue until beat 15.
//    6. Exit returns to StorybookScene at the stored chapter/page.
//

import SpriteKit
import UIKit

class DaphneBecomesTailorScene: SKScene {

    // MARK: - Navigation return destination (set by StorybookScene)

    /// Chapter index (0-based) to return to when the scene exits.
    var returnChapterIndex: Int = 3
    /// Page index within that chapter to return to.
    var returnPageIndex:    Int = 0

    // MARK: - Beat data

    private struct Beat {
        let speaker: String
        let text:    String
    }

    // Beats 0-15. Beat 10 triggers Daphne's entrance on the following tap.
    private let beats: [Beat] = [
        // 0
        Beat(speaker: "마법사 오로라",    text: "폴라리스 안녕, 옷을 주문하러 왔어."),
        // 1
        Beat(speaker: "가게 주인 폴라레스", text: "언니, 지금은 그럴 수 없어요."),
        // 2
        Beat(speaker: "마법사 오로라",    text: "아니 왜, 무슨 일이 있니?"),
        // 3
        Beat(speaker: "가게 주인 폴라레스", text: "가게 지하에 몬스터들이 나타나서 옷감, 실, 단추… 아무것도 꺼낼 수가 없어요. \n재봉사가 더 이상 못하겠다고 그만 뒀다고요."),
        // 4
        Beat(speaker: "마법사 오로라",    text: "아… 불쌍한 나의 동생."),
        // 5
        Beat(speaker: "가게 주인 폴라레스", text: "언니가 마법으로 해결해주세요. 이럴 땐 나도 마법을 할 수 있다면 얼마나 좋을까…"),
        // 6
        Beat(speaker: "마법사 오로라",    text: "나에게 더 좋은 수가 있어!"),
        // 7
        Beat(speaker: "가게 주인 폴라레스", text: "그게 뭔데요?"),
        // 8
        Beat(speaker: "마법사 오로라",    text: "내 지각쟁이 조수를 보내줄게. 아직 배울 게 많지만 내 밑에서 배워서 마법을 제법 쓸 줄 알아.\n여기서 일하면서 몬스터들도 다루고 마력도 키워서 돌아오라고 시킬게."),
        // 9
        Beat(speaker: "가게 주인 폴라레스", text: "언니의 조수가 과연 여기서 일을 하고 싶을까요?"),
        // 10 — Daphne entrance fires on the next tap after this beat is shown
        Beat(speaker: "마법사 오로라",    text: "그건 걱정마, 그 아이가 늦는 이유는 맨날 네 가게 앞에서 옷 구경해서 그런단다. \n다프네, 이리 오렴!"),
        // 11 — shown after Daphne's entrance completes
        Beat(speaker: "재봉사 다프네",    text: "앗 선생님! 오늘은 지각 안 했어요. 갑자기 강제 소환을 하시다니요! \n그리고 제가 왜 이런 복장을 하고 있는거죠?"),
        // 12
        Beat(speaker: "마법사 오로라",    text: "매일같이 지각을 했으니 앞으로 여기서 재봉사로 일 좀 해야겠다. 네가 좋아하는 곳이니 불만 없겠지?"),
        // 13
        Beat(speaker: "재봉사 다프네",    text: "아 하하하… 네…"),
        // 14
        Beat(speaker: "가게 주인 폴라레스", text: "좋아요! 만나서 반가워요, 다프네."),
        // 15 — outro fires on next tap
        Beat(speaker: "재봉사 다프네",    text: "잘 부탁드립니다, 폴라리스 부인."),
    ]

    // MARK: - State

    private var beatIndex = 0

    /// Blocks taps while Aurora's entrance magic is playing.
    private var waitingForAuroraEntrance = true
    /// Set after beat 10; next tap triggers Daphne's appearance.
    private var readyForDaphne = false
    /// Blocks taps while Daphne is fading in.
    private var waitingForDaphne = false
    /// Guards against double-exit.
    private var exiting = false

    // MARK: - HUD

    private var hud: NarrativeHUD!

    // MARK: - Character sprites (zPosition 5, behind HUD at 50)

    private var auroraSprite:  SKSpriteNode!
    private var polarisSprite: SKSpriteNode!
    private var daphneSprite:  SKSpriteNode!

    // MARK: - Scene setup

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        setupBackdrop()
        setupCharacters()
        setupHUD(safeBottom: view.safeAreaInsets.bottom)
        runAuroraEntrance()
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

        // Aurora — left side, facing right toward Polaris
        let aurora = SKSpriteNode(imageNamed: "WizardCat")
        if aurora.size.height > 0 { aurora.setScale(adultH / aurora.size.height) }
        aurora.xScale  *= -1                                          // face right
        aurora.position = CGPoint(x: -size.width * 0.22, y: -size.height * 0.10)
        aurora.zPosition = 5
        aurora.alpha    = 0                                           // starts invisible — entrance reveals her
        addChild(aurora)
        auroraSprite = aurora

        // Polaris — right side, facing left (default orientation)
        let polaris = SKSpriteNode(imageNamed: "Shopkeeper")
        if polaris.size.height > 0 { polaris.setScale(adultH / polaris.size.height) }
        polaris.position = CGPoint(x: size.width * 0.22, y: -size.height * 0.15)
        polaris.zPosition = 5
        addChild(polaris)
        polarisSprite = polaris

        // Daphne — center, hidden until Aurora calls her
        let daphne = SKSpriteNode(imageNamed: "Tailor")
        if daphne.size.height > 0 { daphne.setScale(tailorH / daphne.size.height) }
        daphne.position  = CGPoint(x: 0, y: -size.height * 0.15)
        daphne.zPosition = 6    // in front of Aurora and Polaris when centered
        daphne.alpha     = 0
        addChild(daphne)
        daphneSprite = daphne
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
                    // Aurora — mint-blue
                    nameColor: UIColor(red: 0.37, green: 0.78, blue: 0.72, alpha: 1.0)
                ),
                SpeakerConfig(
                    name: "가게 주인 폴라레스",
                    portraitAsset: "Portrait_Polaris",
                    slot: .right,
                    // Polaris — soft rose
                    nameColor: UIColor(red: 0.91, green: 0.63, blue: 0.63, alpha: 1.0)
                ),
                SpeakerConfig(
                    name: "재봉사 다프네",
                    portraitAsset: "Portrait_Daphne",
                    slot: .right,     // shares the right slot with Polaris; swapped in on Daphne's entrance
                    // Daphne — warm gold
                    nameColor: UIColor(red: 1.0, green: 0.84, blue: 0.31, alpha: 1.0)
                ),
            ],
            sceneSize: size,
            safeBottom: safeBottom
        )

        // Reveal Aurora and Polaris at scene start; Daphne stays hidden.
        // (Active speaker deliberately not set here — Aurora entrance callback sets it.)
        hud.revealSpeakers(["마법사 오로라", "가게 주인 폴라레스"], activeSpeaker: "가게 주인 폴라레스")
    }

    // MARK: - Aurora entrance (purple sparkles + fade-in)

    private func runAuroraEntrance() {
        // Purple sparkle burst at Aurora's position
        spawnSparkles(at: auroraSprite.position, color: UIColor(red: 0.60, green: 0.30, blue: 0.90, alpha: 1.0))

        auroraSprite.run(.fadeIn(withDuration: 1.5)) { [weak self] in
            guard let self else { return }
            self.waitingForAuroraEntrance = false
            self.hud.setActiveSpeaker(named: "마법사 오로라")
            self.hud.show(speaker: self.beats[0].speaker, text: self.beats[0].text)
        }
    }

    // MARK: - Daphne entrance

    private func enterDaphne() {
        waitingForDaphne = true
        spawnSparkles(at: daphneSprite.position, color: UIColor(red: 1.0, green: 0.84, blue: 0.31, alpha: 1.0))

        daphneSprite.run(.fadeIn(withDuration: 0.8)) { [weak self] in
            guard let self else { return }
            // Daphne shares the right slot with Polaris — swap Polaris out, Daphne in.
            self.hud.hideSpeaker(named: "가게 주인 폴라레스")
            self.hud.revealSpeaker(named: "재봉사 다프네")
            self.waitingForDaphne = false
            self.beatIndex = 11
            self.hud.show(speaker: self.beats[11].speaker, text: self.beats[11].text)
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
            startExit()
            return
        }
        hud.show(speaker: beats[beatIndex].speaker, text: beats[beatIndex].text)

        switch beatIndex {
        case 10:
            // Aurora calls Daphne — next tap triggers her entrance.
            readyForDaphne = true
        case 14:
            // Polaris greets Daphne — flip Daphne to face right toward Polaris.
            daphneSprite.xScale *= -1
            // Swap Daphne out, Polaris back in the right slot.
            hud.hideSpeaker(named: "재봉사 다프네")
            hud.revealSpeaker(named: "가게 주인 폴라레스")
        case 15:
            // Daphne has the last word — swap back.
            hud.hideSpeaker(named: "가게 주인 폴라레스")
            hud.revealSpeaker(named: "재봉사 다프네")
        default:
            break
        }
    }

    // MARK: - Exit

    private func startExit() {
        exiting = true
        guard let view = self.view else { return }
        let storybook = StorybookScene(size: size)
        storybook.replayReturnChapter = returnChapterIndex
        storybook.replayReturnPage    = returnPageIndex
        storybook.scaleMode           = .resizeFill
        view.presentScene(storybook, transition: SKTransition.crossFade(withDuration: 0.5))
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !exiting, touches.first != nil else { return }

        // Block during animated transitions.
        if waitingForAuroraEntrance || waitingForDaphne { return }

        // Beat 10: trigger Daphne's entrance on the player's tap.
        if readyForDaphne {
            readyForDaphne = false
            enterDaphne()
            return
        }

        // Last beat: exit.
        if beatIndex == beats.count - 1 {
            startExit()
            return
        }

        advanceBeat()
    }
}
