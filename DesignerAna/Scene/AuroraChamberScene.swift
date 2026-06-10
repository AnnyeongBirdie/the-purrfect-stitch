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

    // MARK: - Public properties forwarded from TailorChoiceScene

    var completedOrder: Order?
    /// Forwarded from TailorChoiceScene; causes the scene to return to
    /// StorybookScene on exit instead of chaining to PrincessAnaScene.
    var isReplayMode = false
    /// Page index within the replay chapter (4) to return to. Set by StorybookScene.
    var replayReturnPage = 1

    // MARK: - Beat data

    private struct Beat {
        let speaker: String
        let text: String
    }

    // 9 beats (indices 0-8). The riddle question is injected at beatIndex 5,
    // between indices 4 and 5 — see advanceBeat().
    // beats[2] is updated at runtime in didMove(to:) to inject the tailor's magic point total.
    private var beats: [Beat] = [
        Beat(speaker: "마법사 오로라",  text: "어머나! 오랜만이구나, 작은 아이야. 잘 지냈니? ✨"),
        Beat(speaker: "재봉사 다프네",  text: "선생님! 그동안 많이 보고 싶었어요. 드릴 말씀이 있어요."),
        Beat(speaker: "마법사 오로라",  text: "호호, 알고 있단다. 네가 얼마나 훌륭한 재봉사가 됐는지… 선생님은 정말 자랑스럽구나.\n마법 실력도 녹슬지 않았고! 마력도 이만큼 올랐구나. 좀더 강해지면 공부를 마치러 돌아오렴."),
        Beat(speaker: "재봉사 다프네",  text: "네, 선생님. 하지만 지금은 아직 어려운 문제들이 많아서, 조금만 더 연습해 보려고 해요.\n그런데, 선생님. 요즘은 다른 문제로 도움이 필요해서 왔어요."),
        Beat(speaker: "마법사 오로라",  text: "그래, 도와주마. 그런데 먼저 — 아직 머리가 잘 돌아가는지 볼까?"),
        // index 5 is praise shown after the riddle
        Beat(speaker: "마법사 오로라",  text: "그래! 역시 내 제자야. 똑똑하구나. 🌟"),
        Beat(speaker: "재봉사 다프네",  text: "선생님! 이 왕실 물건으로 보이는 것들을 어떻게 해야할까요? 왕과 왕비님은 뵙기 어려울거 같아요."),
        Beat(speaker: "마법사 오로라",  text: "아나 공주님께 그 보물들을 가져가렴. 공주님이 분명 알고 계실 거야."),
        Beat(speaker: "마법사 오로라",  text: "자, 내가 마법으로 보내줄게! ✨"),
    ]

    // Logical beat index. Values:
    //   0-4  → beats[0-4]
    //   5    → riddle question shown (custom text from RiddleBank)
    //   5.5  → riddle choices visible (tracked by riddleChoicesVisible flag)
    //   6-9  → beats[5-8]  (offset by 1 due to injected riddle)
    //   10   → teleport
    private var beatIndex = 0

    // MARK: - Riddle state

    private var riddleChoicesVisible = false
    private var teleporting = false
    private var currentRiddle: Riddle = RiddleBank.load().randomElement() ?? RiddleBank.load()[0]

    // MARK: - HUD

    private var hud: NarrativeHUD!

    // MARK: - Character sprites (scene dressing — behind HUD, zPosition 5)

    private var auroraSprite: SKSpriteNode!
    private var tailorSprite: SKSpriteNode!

    // MARK: - Scene setup

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        // Inject the tailor's current magic point total into Aurora's beat 2 text.
        // Replace Store.magicPoints with the actual accessor once confirmed.
        let mp = Magic.shared.points
        beats[2] = Beat(
            speaker: "마법사 오로라",
            text: "호호, 알고 있단다. 네가 얼마나 훌륭한 재봉사가 됐는지… 선생님은 정말 자랑스럽구나. 마법 실력도 녹슬지 않았고! 마력도 \(mp)만큼 올랐구나. 좀 더 강해지면 공부를 마치러 돌아오렴."
        )

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

    // MARK: - Character sprites setup

    private func setupCharacters() {
        let tailorHeight: CGFloat = 240
        let adultHeight:  CGFloat = 310

        let aurora = SKSpriteNode(imageNamed: "WizardCat")
        if aurora.size.height > 0 { aurora.setScale(adultHeight / aurora.size.height) }
        aurora.position = CGPoint(x: -size.width * 0.13, y: -size.height * 0.15)
        aurora.zPosition = 5
        addChild(aurora)
        auroraSprite = aurora

        let tailor = SKSpriteNode(imageNamed: "Tailor")
        if tailor.size.height > 0 { tailor.setScale(tailorHeight / tailor.size.height) }
        tailor.position = CGPoint(x: size.width * 0.13, y: -size.height * 0.15)
        tailor.zPosition = 5
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
        case 1, 2, 3, 4:
            // beats[0-4]
            hud.show(speaker: beats[beatIndex].speaker, text: beats[beatIndex].text)

        case 5:
            // Show riddle question as Aurora's dialogue; next tap reveals choices.
            hud.show(speaker: "마법사 오로라", text: currentRiddle.question)

        case 6...9:
            // beats[5-8] — offset by 1 due to injected riddle
            let arrayIdx = beatIndex - 1
            hud.show(speaker: beats[arrayIdx].speaker, text: beats[arrayIdx].text)

        case 10:
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
                self.beatIndex = 6
                self.hud.show(speaker: self.beats[5].speaker, text: self.beats[5].text)
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

        if isReplayMode {
            // Replay mode: return to the exact storybook page instead of chaining.
            let storybook = StorybookScene(size: size)
            storybook.replayReturnChapter = 4
            storybook.replayReturnPage    = replayReturnPage
            storybook.scaleMode = .resizeFill
            view.presentScene(storybook, transition: SKTransition.crossFade(withDuration: 0.5))
            return
        }

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

        // beatIndex == 5: question is shown; next tap reveals choices
        if beatIndex == 5 && !riddleChoicesVisible {
            showRiddleChoices()
            return
        }

        advanceBeat()
    }
}
