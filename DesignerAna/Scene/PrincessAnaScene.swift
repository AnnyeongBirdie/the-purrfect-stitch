//
//  PrincessAnaScene.swift
//  DesignerAna
//
//  Phase 5 final narrative scene. The tailor delivers the four relics to
//  Princess Ana, the Fairy Godmother reveals the curse story, then the
//  tailor returns home. Quest-complete flag is saved on exit.
//
//  Speaker triangle layout:
//    left  → 재봉사 (Tailor)
//    right → 아나 (Princess Ana)
//    centerElevated → 대모 (Fairy Godmother) — appears at beat 9
//

import SpriteKit
import UIKit

class PrincessAnaScene: SKScene {

    // MARK: - Public property forwarded from AuroraChamberScene / TailorChoiceScene

    var completedOrder: Order?

    // MARK: - Beat data

    private struct Beat {
        let speaker: String
        let text: String
    }

    private let beats: [Beat] = [
        // 0
        Beat(speaker: "아나 공주",   text: "어머! 재봉사님, 안녕하세요! 오늘은 어떤 일로 오셨어요? 😊"),
        // 1
        Beat(speaker: "재봉사 다프네", text: "공주님, 던전에서 이걸 찾았어요. 공주님께 드리고 싶었어요."),
        // 2 — relic 1 handoff fires
        Beat(speaker: "아나 공주",   text: "어머... 이건 에스텔 언니의 보랏빛 지팡이잖아요! 어디서 찾으셨어요?"),
        // 3
        Beat(speaker: "재봉사 다프네", text: "원단 보관장 던전에서요. 그리고 이것도요..."),
        // 4 — relic 2 handoff fires
        Beat(speaker: "아나 공주",   text: "그림 붓이에요! 언니가 항상 갖고 다니던 거예요. 😢"),
        // 5
        Beat(speaker: "재봉사 다프네", text: "재봉틀 던전에서 찾았어요. 그리고... 팔레트도요."),
        // 6 — relic 3 handoff fires
        Beat(speaker: "아나 공주",   text: "언니 물건들이 왜 던전에 있었던 걸까요... 마지막으로 이건 뭔가요?"),
        // 7
        Beat(speaker: "재봉사 다프네", text: "왕실 가족 초상화예요. 보스 던전 깊은 곳에 있었어요."),
        // 8 — relic 4 handoff fires
        Beat(speaker: "아나 공주",   text: "이건... 이건 우리 가족 초상화예요. 그런데 여기 이 작은 달팽이는..."),
        // 9 — Godmother entrance fires; taps blocked until waitingForGodmother == false
        Beat(speaker: "아나 공주",   text: "로즈예요. 우리 가족의 반려 달팽이였는데, 어느 날 갑자기 사라졌어요. 대모 할머니! 와주세요!"),
        // 10 — Godmother's first line (shown after entrance completes)
        Beat(speaker: "요정 대모 플로라",   text: "왔단다, 아나야. 재봉사님, 드디어 오셨군요. ✨"),
        Beat(speaker: "요정 대모 플로라",   text: "로즈는... 저주를 받았어요. 그 저주가 로즈를 털실 몬스터로 만들었지요."),
        Beat(speaker: "요정 대모 플로라",   text: "왕실 가족도 함께 저주를 받아, 로즈의 존재를 모두 잊어버렸답니다."),
        Beat(speaker: "요정 대모 플로라",   text: "먼지 몬스터들은 나쁜 존재가 아니에요. 저주받은 존재들에게 안식처를 주는 거랍니다."),
        Beat(speaker: "요정 대모 플로라",   text: "재봉사님이 몬스터를 물리치면, 몬스터는 잠시 잠드는 것뿐이에요. 상처를 입히는 게 아니랍니다."),
        Beat(speaker: "아나 공주",   text: "그럼 언니는... 로즈를 찾으러 던전에 갔던 거군요."),
        // 16 — Godmother exit fires when tapped
        Beat(speaker: "요정 대모 플로라",   text: "그렇단다. 에스텔은 용감한 아이였어. 이 보물들은 그 증거지요."),
        // 17 — shown after Godmother exits
        Beat(speaker: "아나 공주",   text: "재봉사님, 정말 감사해요. 언니의 물건들을 찾아주셔서요. 🤍"),
        // 18 — outro triggers on tap
        Beat(speaker: "아나 공주",   text: "어서 가게로 돌아가세요. 기다리는 손님이 있을 거예요. 또 놀러 올게요!"),
    ]

    // MARK: - State

    private var beatIndex = 0

    // Godmother entrance — blocks all taps until the fade-in + callback complete.
    private var waitingForGodmother = false
    // Godmother exit — blocks taps during the 0.5 s fade-out.
    private var waitingForGodmotherExit = false
    private var godmotherExited = false

    private var outroStarted = false

    // MARK: - HUD

    private var hud: NarrativeHUD!

    // MARK: - Character sprites (scene dressing)

    private var tailorSprite: SKSpriteNode!
    private var anaSprite: SKSpriteNode!
    private var godmotherSprite: SKSpriteNode?

    // MARK: - Scene setup

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        setupBackdrop()
        setupCharacters()
        setupHUD(safeBottom: view.safeAreaInsets.bottom)
    }

    private func setupBackdrop() {
        let bg = SKSpriteNode(imageNamed: "PrincessAna_Room")
        bg.position = .zero
        bg.size = size
        bg.zPosition = 0
        addChild(bg)
    }

    private func setupCharacters() {
        let tailor = SKSpriteNode(imageNamed: "Tailor")
        if tailor.size.width > 0 { tailor.setScale(90 / tailor.size.width) }
        tailor.position = CGPoint(x: -size.width * 0.30, y: -size.height * 0.08)
        tailor.zPosition = 10
        addChild(tailor)
        tailorSprite = tailor

        let ana = SKSpriteNode(imageNamed: "SecondPrincessCat")
        if ana.size.width > 0 { ana.setScale(100 / ana.size.width) }
        ana.position = CGPoint(x: size.width * 0.30, y: -size.height * 0.08)
        ana.zPosition = 10
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
                    name: "재봉사 다프네",
                    portraitAsset: "Portrait_Daphne",
                    slot: .left,
                    // Tailor — warm gold #FFD54F
                    nameColor: UIColor(red: 1.0, green: 0.84, blue: 0.31, alpha: 1.0)
                ),
                SpeakerConfig(
                    name: "아나 공주",
                    portraitAsset: "Portrait_Ana",
                    slot: .right,
                    // Princess Ana — emerald green #4CB87A
                    nameColor: UIColor(red: 0.30, green: 0.72, blue: 0.48, alpha: 1.0)
                ),
                SpeakerConfig(
                    name: "요정 대모 플로라",
                    portraitAsset: "Portrait_Flora",
                    slot: .centerElevated,
                    // Fairy Godmother — silver #B8C2D6
                    nameColor: UIColor(red: 0.72, green: 0.76, blue: 0.84, alpha: 1.0)
                ),
            ],
            sceneSize: size,
            safeBottom: safeBottom
        )

        // Reveal only Tailor and Ana at scene start; Godmother stays hidden until beat 9.
        hud.revealSpeakers(["재봉사 다프네", "아나 공주"], activeSpeaker: "아나 공주")

        hud.show(speaker: "아나 공주", text: beats[0].text)
    }

    // MARK: - Beat advancement

    private func advanceBeat() {
        beatIndex += 1
        guard beatIndex < beats.count else { return }

        hud.show(speaker: beats[beatIndex].speaker, text: beats[beatIndex].text)

        switch beatIndex {
        case 2: animateRelicHandoff(.purpleScepter)
        case 4: animateRelicHandoff(.paintBrush)
        case 6: animateRelicHandoff(.palette)
        case 8: animateRelicHandoff(.royalFamilyPortrait)
        case 9:
            // Block taps during godmother entrance sequence.
            waitingForGodmother = true
            run(.wait(forDuration: 0.3)) { [weak self] in self?.enterGodmother() }
        default:
            break
        }
    }

    // MARK: - Relic handoff animation

    private func animateRelicHandoff(_ item: DungeonItem) {
        let sprite = SKSpriteNode(imageNamed: item.assetName)
        if sprite.size.width > 0 { sprite.setScale(36 / sprite.size.width) }
        sprite.position = CGPoint(
            x: tailorSprite.position.x + 30,
            y: tailorSprite.position.y + 60
        )
        sprite.zPosition = 15
        addChild(sprite)

        let target = CGPoint(
            x: anaSprite.position.x - 30,
            y: anaSprite.position.y + 60
        )
        let arc = SKAction.move(to: target, duration: 0.5)
        arc.timingMode = .easeInEaseOut
        sprite.run(.sequence([
            arc,
            .wait(forDuration: 0.3),
            .fadeOut(withDuration: 0.2),
            .removeFromParent()
        ]))
    }

    // MARK: - Godmother entrance

    private func enterGodmother() {
        let gm = SKSpriteNode(imageNamed: "GodmotherCat")
        if gm.size.width > 0 { gm.setScale(100 / gm.size.width) }
        gm.position = CGPoint(x: 0, y: -size.height * 0.08)
        gm.zPosition = 11
        gm.alpha = 0
        addChild(gm)
        godmotherSprite = gm

        spawnSparkles(at: gm.position)

        gm.run(.fadeIn(withDuration: 0.5)) { [weak self] in
            guard let self else { return }
            self.waitingForGodmother = false
            self.beatIndex = 10
            // Reveal Godmother portrait and update dialogue simultaneously.
            self.hud.revealSpeaker(named: "요정 대모 플로라")
            self.hud.show(speaker: self.beats[10].speaker, text: self.beats[10].text)
        }
    }

    // MARK: - Godmother exit

    private func exitGodmother() {
        waitingForGodmotherExit = true

        hud.hideSpeaker(named: "요정 대모 플로라")
        godmotherSprite?.run(.sequence([
            .fadeOut(withDuration: 0.5),
            .removeFromParent()
        ])) { [weak self] in
            guard let self else { return }
            self.waitingForGodmotherExit = false
            self.godmotherExited = true
            self.beatIndex = 17
            self.hud.show(speaker: self.beats[17].speaker, text: self.beats[17].text)
        }
    }

    // MARK: - Sparkles

    private func spawnSparkles(at position: CGPoint) {
        for i in 0..<8 {
            let spark = SKShapeNode(circleOfRadius: 4)
            spark.fillColor = UIColor(red: 0.72, green: 0.76, blue: 0.84, alpha: 1.0) // silver
            spark.strokeColor = .clear
            spark.position = position
            spark.zPosition = 20
            addChild(spark)
            let angle = CGFloat(i) / 8 * .pi * 2
            let target = CGPoint(
                x: position.x + cos(angle) * 50,
                y: position.y + sin(angle) * 50
            )
            spark.run(.sequence([
                .move(to: target, duration: 0.35),
                .fadeOut(withDuration: 0.2),
                .removeFromParent()
            ]))
        }
    }

    // MARK: - Outro

    private func startOutro() {
        outroStarted = true
        Store.saveRelicQuestComplete()
        guard let view = self.view else { return }
        guard let next = FrontShopScene(fileNamed: "GameScene") else { return }
        next.scaleMode = .resizeFill
        next.shouldShowFinishedGarment = true
        next.finishedGarmentImageName = garmentImageName(for: completedOrder)
        next.completedOrder = completedOrder
        next.suppressEntryBell = true
        view.presentScene(next, transition: SKTransition.crossFade(withDuration: 0.8))
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !outroStarted else { return }
        guard touches.first != nil else { return }

        // Block during animated transitions.
        if waitingForGodmother || waitingForGodmotherExit { return }

        // Beat 16: Godmother exit on first tap.
        if beatIndex == 16 && !godmotherExited {
            exitGodmother()
            return
        }

        // Beat 18: outro.
        if beatIndex == 18 {
            startOutro()
            return
        }

        advanceBeat()
    }
}
