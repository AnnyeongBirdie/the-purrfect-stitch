//
//  AuroraChamberScene.swift
//  DesignerAna
//
//  Phase 5 — Path A. Aurora (WizardCat) greets the tailor, poses a riddle,
//  then teleports them to Princess Ana's room via a purple swirling halo.
//

import SpriteKit
import UIKit

class AuroraChamberScene: SKScene {

    // MARK: - Public property forwarded from TailorChoiceScene

    var completedOrder: Order?

    // MARK: - Beat data

    private struct Beat {
        let speaker: String
        let text: String
    }

    private let beats: [Beat] = [
        Beat(speaker: "오로라",  text: "어머나! 오랜만이구나, 작은 아이야. 잘 지냈니? ✨"),
        Beat(speaker: "재봉사",  text: "선생님! 그동안 많이 보고 싶었어요. 드릴 말씀이 있어요."),
        Beat(speaker: "오로라",  text: "호호, 알고 있단다. 네가 얼마나 훌륭한 재봉사가 됐는지… 선생님은 정말 자랑스럽구나. 마법 실력도 녹슬지 않았고!"),
        Beat(speaker: "오로라",  text: "그래, 도와주마. 그런데 먼저 — 아직 머리가 잘 돌아가는지 볼까?"),
        // index 4: praise (shown after correct riddle answer)
        Beat(speaker: "오로라",  text: "그래! 역시 내 제자야. 똑똑하구나. 🌟"),
        Beat(speaker: "오로라",  text: "아나 공주님께 그 보물들을 가져가렴. 공주님이 분명 알고 계실 거야."),
        Beat(speaker: "오로라",  text: "자, 내가 마법으로 보내줄게! ✨"),
    ]

    // beatIndex starts at 0 (shown at setup); advanceBeat() increments before dispatch.
    // beatIndex 4 = riddle panel; riddle correct sets beatIndex to 5 = beats[4].
    // Mapping: beatArrayIndex = beatIndex <= 3 ? beatIndex : beatIndex - 1
    private var beatIndex = 0

    // MARK: - State

    private var riddlePanelVisible = false
    private var teleporting = false
    private var currentRiddle: Riddle = RiddleBank.load()[0]

    // MARK: - Node references

    private var auroraSprite: SKSpriteNode!
    private var tailorSprite: SKSpriteNode!
    private var dialoguePanel: SKShapeNode!
    private var speakerLabel: SKLabelNode!
    private var textLabel: SKLabelNode!
    private var tapHintLabel: SKLabelNode!
    private var riddlePanel: SKShapeNode!

    // MARK: - Layout constants

    private var bubbleW: CGFloat { min(size.width * 0.72, 460) }
    private var panelY: CGFloat { -size.height * 0.34 }

    // MARK: - Scene setup

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        setupBackdrop()
        setupCharacters()
        setupDialogueBubble()
        setupRiddlePanel()
        showBeat(0)
    }

    private func setupBackdrop() {
        let bg = SKSpriteNode(imageNamed: "Wizard_Chamber")
        bg.position = .zero
        bg.size = size
        bg.zPosition = 0
        addChild(bg)
    }

    private func setupCharacters() {
        let aurora = SKSpriteNode(imageNamed: "WizardCat")
        aurora.size = CGSize(width: 100, height: 150)
        aurora.position = CGPoint(x: -size.width * 0.30, y: -size.height * 0.08)
        aurora.zPosition = 10
        addChild(aurora)
        auroraSprite = aurora

        let tailor = SKSpriteNode(imageNamed: "Tailor")
        tailor.size = CGSize(width: 90, height: 135)
        tailor.position = CGPoint(x: size.width * 0.30, y: -size.height * 0.08)
        tailor.zPosition = 10
        addChild(tailor)
        tailorSprite = tailor
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

    // MARK: - Riddle panel

    private func setupRiddlePanel() {
        let panelH: CGFloat = 180
        let panel = SKShapeNode(
            rect: CGRect(x: -bubbleW / 2, y: -panelH / 2, width: bubbleW, height: panelH),
            cornerRadius: 20
        )
        panel.fillColor = UIColor(red: 0.98, green: 0.95, blue: 0.85, alpha: 0.93)
        panel.strokeColor = UIColor(red: 0.45, green: 0.25, blue: 0.10, alpha: 1.0)
        panel.lineWidth = 2
        panel.position = CGPoint(x: 0, y: panelY)
        panel.zPosition = 20
        panel.isHidden = true
        addChild(panel)
        riddlePanel = panel

        // Question label
        let question = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        question.fontSize = 14
        question.fontColor = .black
        question.numberOfLines = 0
        question.preferredMaxLayoutWidth = bubbleW - 48
        question.horizontalAlignmentMode = .center
        question.verticalAlignmentMode = .center
        question.position = CGPoint(x: 0, y: panelH * 0.17)
        question.zPosition = 21
        question.text = currentRiddle.question
        riddlePanel.addChild(question)

        // 2×2 answer buttons
        let btnW = bubbleW * 0.44
        let btnH: CGFloat = 40
        let fillColor = UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 1.0)
        let positions: [CGPoint] = [
            CGPoint(x: -bubbleW * 0.24, y: -panelH * 0.13),
            CGPoint(x:  bubbleW * 0.24, y: -panelH * 0.13),
            CGPoint(x: -bubbleW * 0.24, y: -panelH * 0.38),
            CGPoint(x:  bubbleW * 0.24, y: -panelH * 0.38),
        ]
        for i in 0..<4 {
            let btn = SKShapeNode(
                rect: CGRect(x: -btnW / 2, y: -btnH / 2, width: btnW, height: btnH),
                cornerRadius: 10
            )
            btn.fillColor = fillColor
            btn.strokeColor = UIColor.brown
            btn.lineWidth = 2
            btn.position = positions[i]
            btn.zPosition = 21
            btn.name = "ans_\(i)"

            let lbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
            lbl.fontSize = 13
            lbl.fontColor = .white
            lbl.verticalAlignmentMode = .center
            lbl.horizontalAlignmentMode = .center
            lbl.text = currentRiddle.choices[i]
            lbl.name = "ans_\(i)"
            btn.addChild(lbl)

            riddlePanel.addChild(btn)
        }
    }

    // MARK: - Beat display

    private func beatArrayIndex(for index: Int) -> Int {
        index <= 3 ? index : index - 1
    }

    private func showBeat(_ index: Int) {
        let arrayIdx = beatArrayIndex(for: index)
        guard arrayIdx < beats.count else { return }
        let beat = beats[arrayIdx]
        speakerLabel.text = beat.speaker
        textLabel.text = beat.text
    }

    // MARK: - Riddle panel show / hide

    private func showRiddlePanel() {
        dialoguePanel.isHidden = true
        speakerLabel.isHidden = true
        textLabel.isHidden = true
        tapHintLabel.isHidden = true
        riddlePanel.isHidden = false
        riddlePanelVisible = true
    }

    private func hideRiddlePanel() {
        riddlePanel.isHidden = true
        riddlePanelVisible = false
        dialoguePanel.isHidden = false
        speakerLabel.isHidden = false
        textLabel.isHidden = false
        tapHintLabel.isHidden = false
    }

    // MARK: - Beat advancement

    private func advanceBeat() {
        beatIndex += 1

        switch beatIndex {
        case 1...3:
            showBeat(beatIndex)
        case 4:
            showRiddlePanel()
        case 5...7:
            showBeat(beatIndex)
        case 8:
            startTeleport()
        default:
            break
        }
    }

    // MARK: - Riddle answer handling

    private func handleAnswer(_ name: String) {
        guard let indexStr = name.split(separator: "_").last,
              let idx = Int(indexStr),
              idx < currentRiddle.choices.count else { return }

        let chosen = currentRiddle.choices[idx]
        let isCorrect = chosen == currentRiddle.answer

        // Find the tapped button node
        let btn = riddlePanel.children.first { $0.name == name } as? SKShapeNode
        let flashColor: UIColor = isCorrect
            ? UIColor(red: 0.20, green: 0.75, blue: 0.35, alpha: 1.0)
            : UIColor(red: 0.85, green: 0.25, blue: 0.20, alpha: 1.0)
        let originalColor = UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 1.0)

        btn?.run(.sequence([
            .run { btn?.fillColor = flashColor },
            .wait(forDuration: 0.35),
            .run { btn?.fillColor = originalColor }
        ]))

        if isCorrect {
            run(.sequence([
                .wait(forDuration: 0.45),
                .run { [weak self] in
                    guard let self else { return }
                    self.hideRiddlePanel()
                    self.beatIndex = 5
                    self.showBeat(5)
                }
            ]))
        }
    }

    // MARK: - Teleport sequence

    private func startTeleport() {
        teleporting = true
        SoundManager.shared.play("sfx_halo_expand.mp3")

        let halo = SKShapeNode(circleOfRadius: 8)
        halo.fillColor = UIColor(red: 0.55, green: 0.18, blue: 0.80, alpha: 0.8)
        halo.strokeColor = .clear
        halo.position = auroraSprite.position
        halo.zPosition = 30
        addChild(halo)

        let targetScale = max(size.width, size.height) / 2 / 8   // fill screen: half longest dimension ÷ initial radius
        let expand = SKAction.scale(to: targetScale, duration: 0.9)
        expand.timingMode = .easeIn
        let spin = SKAction.rotate(byAngle: .pi * 2, duration: 0.9)

        halo.run(.sequence([
            .group([expand, spin]),
            .run { [weak self] in self?.exitToNextScene() }
        ]))

        let fade = SKAction.fadeAlpha(to: 0, duration: 0.5)
        auroraSprite.run(fade)
        tailorSprite.run(fade)
    }

    private func exitToNextScene() {
        guard let view = self.view else { return }
        let ana = PrincessAnaScene()
        ana.scaleMode = .resizeFill
        ana.completedOrder = completedOrder
        view.presentScene(ana, transition: SKTransition.crossFade(withDuration: 0.6))
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !teleporting, let touch = touches.first else { return }
        let loc = touch.location(in: self)
        let name = nodes(at: loc).compactMap { $0.name }.first

        if riddlePanelVisible {
            switch name {
            case "ans_0", "ans_1", "ans_2", "ans_3":
                handleAnswer(name!)
            default:
                break
            }
            return
        }

        advanceBeat()
    }
}
