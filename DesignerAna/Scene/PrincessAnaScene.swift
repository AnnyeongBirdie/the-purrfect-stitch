//
//  PrincessAnaScene.swift
//  DesignerAna
//
//  Phase 5 final narrative scene. The tailor delivers the four relics to
//  Princess Ana, the Fairy Godmother reveals the curse story, then the
//  tailor returns home. Quest-complete flag is saved on exit.
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
        Beat(speaker: "아나",   text: "어머! 재봉사님, 안녕하세요! 오늘은 어떤 일로 오셨어요? 😊"),
        Beat(speaker: "재봉사", text: "공주님, 던전에서 이걸 찾았어요. 공주님께 드리고 싶었어요."),
        Beat(speaker: "아나",   text: "어머... 이건 에스텔 언니의 보랏빛 지팡이잖아요! 어디서 찾으셨어요?"),
        Beat(speaker: "재봉사", text: "원단 보관장 던전에서요. 그리고 이것도요..."),
        Beat(speaker: "아나",   text: "그림 붓이에요! 언니가 항상 갖고 다니던 거예요. 😢"),
        Beat(speaker: "재봉사", text: "재봉틀 던전에서 찾았어요. 그리고... 팔레트도요."),
        Beat(speaker: "아나",   text: "언니 물건들이 왜 던전에 있었던 걸까요... 마지막으로 이건 뭔가요?"),
        Beat(speaker: "재봉사", text: "왕실 가족 초상화예요. 보스 던전 깊은 곳에 있었어요."),
        Beat(speaker: "아나",   text: "이건... 이건 우리 가족 초상화예요. 그런데 여기 이 작은 달팽이는..."),
        Beat(speaker: "아나",   text: "로즈예요. 우리 가족의 반려 달팽이였는데, 어느 날 갑자기 사라졌어요. 대모 할머니! 와주세요!"),
        Beat(speaker: "대모",   text: "왔단다, 아나야. 재봉사님, 드디어 오셨군요. ✨"),
        Beat(speaker: "대모",   text: "로즈는... 저주를 받았어요. 그 저주가 로즈를 털실 몬스터로 만들었지요."),
        Beat(speaker: "대모",   text: "왕실 가족도 함께 저주를 받아, 로즈의 존재를 모두 잊어버렸답니다."),
        Beat(speaker: "대모",   text: "먼지 몬스터들은 나쁜 존재가 아니에요. 저주받은 존재들에게 안식처를 주는 거랍니다."),
        Beat(speaker: "대모",   text: "재봉사님이 몬스터를 물리치면, 몬스터는 잠시 잠드는 것뿐이에요. 상처를 입히는 게 아니랍니다."),
        Beat(speaker: "아나",   text: "그럼 언니는... 로즈를 찾으러 던전에 갔던 거군요."),
        Beat(speaker: "대모",   text: "그렇단다. 에스텔은 용감한 아이였어. 이 보물들은 그 증거지요."),
        Beat(speaker: "아나",   text: "재봉사님, 정말 감사해요. 언니의 물건들을 찾아주셔서요. 🤍"),
        Beat(speaker: "아나",   text: "어서 가게로 돌아가세요. 기다리는 손님이 있을 거예요. 또 놀러 올게요!"),
    ]

    // MARK: - State

    private var beatIndex = 0
    private var godmotherEntered = false
    private var godmotherExited = false
    private var outroStarted = false

    // MARK: - Node references

    private var tailorSprite: SKSpriteNode!
    private var anaSprite: SKSpriteNode!
    private var godmotherSprite: SKSpriteNode?
    private var dialoguePanel: SKShapeNode!
    private var speakerLabel: SKLabelNode!
    private var textLabel: SKLabelNode!
    private var tapHintLabel: SKLabelNode!

    // MARK: - Layout constants

    private var bubbleW: CGFloat { min(size.width * 0.72, 460) }
    private var panelY: CGFloat { -size.height * 0.34 }

    // MARK: - Beat intercept conditions

    private var currentBeatIsGodmotherEntrance: Bool { beatIndex == 9 }
    private var currentBeatIsGodmotherExit: Bool     { beatIndex == 16 }
    private var currentBeatIsOutro: Bool              { beatIndex == 18 }

    // MARK: - Scene setup

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        setupBackdrop()
        setupCharacters()
        setupDialogueBubble()
        updateDialogue()
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
        tailor.size = CGSize(width: 90, height: 135)
        tailor.position = CGPoint(x: -size.width * 0.30, y: -size.height * 0.08)
        tailor.zPosition = 10
        addChild(tailor)
        tailorSprite = tailor

        let ana = SKSpriteNode(imageNamed: "SecondPrincessCat")
        ana.size = CGSize(width: 100, height: 150)
        ana.position = CGPoint(x: size.width * 0.30, y: -size.height * 0.08)
        ana.zPosition = 10
        addChild(ana)
        anaSprite = ana
    }

    // MARK: - Dialogue bubble

    private func setupDialogueBubble() {
        let panel = SKShapeNode(
            rect: CGRect(x: -bubbleW / 2, y: -48, width: bubbleW, height: 96),
            cornerRadius: 20
        )
        panel.fillColor = UIColor(red: 0.98, green: 0.95, blue: 0.85, alpha: 0.93)
        panel.strokeColor = UIColor(red: 0.45, green: 0.25, blue: 0.10, alpha: 1.0)
        panel.lineWidth = 2
        panel.position = CGPoint(x: 0, y: panelY)
        panel.zPosition = 20
        addChild(panel)
        dialoguePanel = panel

        let speaker = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        speaker.fontSize = 12
        speaker.fontColor = UIColor(red: 0.45, green: 0.25, blue: 0.10, alpha: 1.0)
        speaker.horizontalAlignmentMode = .center
        speaker.position = CGPoint(x: 0, y: panelY + 30)
        speaker.zPosition = 21
        addChild(speaker)
        speakerLabel = speaker

        let body = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        body.fontSize = 14
        body.fontColor = .black
        body.numberOfLines = 0
        body.preferredMaxLayoutWidth = bubbleW - 48
        body.verticalAlignmentMode = .center
        body.horizontalAlignmentMode = .center
        body.position = CGPoint(x: 0, y: panelY - 4)
        body.zPosition = 21
        addChild(body)
        textLabel = body

        let hint = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        hint.fontSize = 12
        hint.fontColor = UIColor(red: 0.45, green: 0.25, blue: 0.10, alpha: 0.85)
        hint.text = "▶ 탭하세요"
        hint.horizontalAlignmentMode = .center
        hint.position = CGPoint(x: 0, y: panelY - 64)
        hint.zPosition = 21
        addChild(hint)
        tapHintLabel = hint
    }

    // MARK: - Dialogue update

    private func updateDialogue() {
        guard beatIndex < beats.count else { return }
        let beat = beats[beatIndex]
        speakerLabel.text = beat.speaker
        textLabel.text = beat.text
    }

    // MARK: - Beat advancement

    private func advanceBeat() {
        beatIndex += 1
        updateDialogue()

        switch beatIndex {
        case 2: animateRelicHandoff(.purpleScepter)
        case 4: animateRelicHandoff(.paintBrush)
        case 6: animateRelicHandoff(.palette)
        case 8: animateRelicHandoff(.royalFamilyPortrait)
        case 9:
            run(.sequence([
                .wait(forDuration: 0.3),
                .run { [weak self] in self?.enterGodmother() }
            ]))
        default: break
        }
    }

    // MARK: - Relic handoff animation

    private func animateRelicHandoff(_ item: DungeonItem) {
        let sprite = SKSpriteNode(imageNamed: item.assetName)
        sprite.size = CGSize(width: 36, height: 36)
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
        gm.size = CGSize(width: 100, height: 150)
        gm.position = CGPoint(x: 0, y: -size.height * 0.08)
        gm.zPosition = 11
        gm.alpha = 0
        addChild(gm)
        godmotherSprite = gm

        spawnSparkles(at: gm.position)

        gm.run(.fadeIn(withDuration: 0.5)) { [weak self] in
            self?.godmotherEntered = true
            self?.advanceBeat()
        }
    }

    // MARK: - Godmother exit

    private func exitGodmother() {
        godmotherSprite?.run(.sequence([
            .fadeOut(withDuration: 0.5),
            .removeFromParent(),
            .run { [weak self] in
                self?.godmotherExited = true
                self?.beatIndex = 17
                self?.updateDialogue()
            }
        ]))
    }

    // MARK: - Sparkles

    private func spawnSparkles(at position: CGPoint) {
        for i in 0..<8 {
            let spark = SKShapeNode(circleOfRadius: 4)
            spark.fillColor = UIColor(red: 0.55, green: 0.18, blue: 0.80, alpha: 1.0)
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
        guard !outroStarted, touches.first != nil else { return }
        handleTap()
    }

    private func handleTap() {
        if currentBeatIsGodmotherEntrance && !godmotherEntered { return }
        if currentBeatIsGodmotherExit && !godmotherExited {
            exitGodmother()
            return
        }
        if currentBeatIsOutro {
            outroStarted = true
            startOutro()
            return
        }
        advanceBeat()
    }
}
