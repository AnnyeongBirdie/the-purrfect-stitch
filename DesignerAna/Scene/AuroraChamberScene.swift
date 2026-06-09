//
//  AuroraChamberScene.swift
//  DesignerAna
//
//  Phase 5 — Path A. Aurora (WizardCat) greets the tailor, poses a riddle,
//  then transitions them to Princess Ana's room.
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

    // 7 beats (indices 0-6). The riddle question is injected at beatIndex 4
    // between indices 3 and 4 — see advanceBeat().
    private let beats: [Beat] = [
        Beat(speaker: "마법사 오로라",  text: "어머나! 오랜만이구나, 작은 아이야. 잘 지냈니? ✨"),
        Beat(speaker: "재봉사 다프네",  text: "선생님! 그동안 많이 보고 싶었어요. 드릴 말씀이 있어요."),
        Beat(speaker: "마법사 오로라",  text: "호호, 알고 있단다. 네가 얼마나 훌륭한 재봉사가 됐는지… 선생님은 정말 자랑스럽구나. 마법 실력도 녹슬지 않았고!"),
        Beat(speaker: "마법사 오로라",  text: "그래, 도와주마. 그런데 먼저 — 아직 머리가 잘 돌아가는지 볼까?"),
        // index 4 is praise shown after the riddle
        Beat(speaker: "마법사 오로라",  text: "그래! 역시 내 제자야. 똑똑하구나. 🌟"),
        Beat(speaker: "마법사 오로라",  text: "아나 공주님께 그 보물들을 가져가렴. 공주님이 분명 알고 계실 거야."),
        Beat(speaker: "마법사 오로라",  text: "자, 내가 마법으로 보내줄게! ✨"),
    ]

    // Logical beat index. Values:
    //   0-3  → beats[0-3]
    //   4    → riddle question shown (custom text from RiddleBank)
    //   4.5  → riddle choices visible (tracked by riddleChoicesVisible flag)
    //   5-7  → beats[4-6]
    //   8    → teleport
    private var beatIndex = 0

    // MARK: - Riddle state

    private var riddleChoicesVisible = false
    private var teleporting = false
    private var currentRiddle: Riddle = RiddleBank.load().randomElement() ?? RiddleBank.load()[0]

    // MARK: - HUD

    private var hud: NarrativeHUD!

    // MARK: - Character sprites (scene dressing, separate from HUD portraits)

    private var auroraSprite: SKSpriteNode!
    private var tailorSprite: SKSpriteNode!

    // MARK: - Scene setup

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        setupBackdrop()
        setupCharacters()
        setupHUD(safeBottom: view.safeAreaInsets.bottom)
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
        if aurora.size.width > 0 { aurora.setScale(100 / aurora.size.width) }
        aurora.position = CGPoint(x: -size.width * 0.30, y: -size.height * 0.08)
        aurora.zPosition = 10
        addChild(aurora)
        auroraSprite = aurora

        let tailor = SKSpriteNode(imageNamed: "Tailor")
        if tailor.size.width > 0 { tailor.setScale(90 / tailor.size.width) }
        tailor.position = CGPoint(x: size.width * 0.30, y: -size.height * 0.08)
        tailor.zPosition = 10
        addChild(tailor)
        tailorSprite = tailor
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
                    // Aurora — mint-blue #5EC8B8
                    nameColor: UIColor(red: 0.37, green: 0.78, blue: 0.72, alpha: 1.0)
                ),
                SpeakerConfig(
                    name: "재봉사 다프네",
                    portraitAsset: "Portrait_Daphne",
                    slot: .right,
                    // Tailor — warm gold #FFD54F
                    nameColor: UIColor(red: 1.0, green: 0.84, blue: 0.31, alpha: 1.0)
                ),
            ],
            sceneSize: size,
            safeBottom: safeBottom
        )

        hud.revealAll(activeSpeaker: "마법사 오로라")
        hud.show(speaker: "마법사 오로라", text: beats[0].text)
    }

    // MARK: - Beat advancement

    private func advanceBeat() {
        beatIndex += 1

        switch beatIndex {
        case 1, 2, 3:
            // beats[0-3]
            hud.show(speaker: beats[beatIndex].speaker, text: beats[beatIndex].text)

        case 4:
            // Show riddle question as Aurora's dialogue; next tap reveals choices.
            hud.show(speaker: "마법사 오로라", text: currentRiddle.question)

        case 5...7:
            // beats[4-6] — offset by 1 due to injected riddle
            let arrayIdx = beatIndex - 1
            hud.show(speaker: beats[arrayIdx].speaker, text: beats[arrayIdx].text)

        case 8:
            startTeleport()

        default:
            break
        }
    }

    // MARK: - Riddle choice display

    private func showRiddleChoices() {
        riddleChoicesVisible = true
        hud.showChoices(currentRiddle.choices)
    }

    // MARK: - Riddle answer handling

    private func handleAnswer(_ name: String) {
        guard let indexStr = name.split(separator: "_").last,
              let idx = Int(indexStr),
              idx < currentRiddle.choices.count else { return }

        let chosen = currentRiddle.choices[idx]
        let isCorrect = chosen == currentRiddle.answer

        hud.flashChoiceResult(at: idx, correct: isCorrect)

        if isCorrect {
            run(.wait(forDuration: 0.45)) { [weak self] in
                guard let self else { return }
                self.hud.hideChoices()
                self.riddleChoicesVisible = false
                self.beatIndex = 5
                self.hud.show(speaker: self.beats[4].speaker, text: self.beats[4].text)
            }
        }
    }

    // MARK: - Transition to Princess Ana's room

    private func startTeleport() {
        // Using a simple fade transition.
        // TODO: design a proper transition effect that fits Aurora's mint-blue color signature.
        teleporting = true
        run(.wait(forDuration: 0.4)) { [weak self] in self?.exitToNextScene() }
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
        let nodeName = nodes(at: loc).compactMap { $0.name }.first

        if riddleChoicesVisible {
            switch nodeName {
            case "choice_0", "choice_1", "choice_2", "choice_3":
                handleAnswer(nodeName!)
            default:
                break
            }
            return
        }

        // beatIndex == 4: question is shown; next tap reveals choices
        if beatIndex == 4 && !riddleChoicesVisible {
            showRiddleChoices()
            return
        }

        advanceBeat()
    }
}
