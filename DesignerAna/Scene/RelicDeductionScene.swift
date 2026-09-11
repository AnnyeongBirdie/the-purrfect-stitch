//
//  RelicDeductionScene.swift
//  DesignerAna
//
//  Cinematic scene triggered once after all four relics are collected.
//  The tailor reflects on the relic deduction, then heads to Aurora's
//  chamber — a mandatory stop before the castle. Renamed from
//  TailorChoiceScene 2026-09-09: this used to branch A/B (Aurora vs.
//  straight to the castle), but going to Aurora first is now mandatory —
//  otherwise Daphne is never told she can return once she levels up (see
//  AuroraChamberScene). With the branch gone, "choice" no longer described
//  what this scene does.
//
//  Speaker layout:
//    left → 재봉사 다프네 (inner monologue — talking to herself)
//

import SpriteKit
import UIKit

class RelicDeductionScene: SKScene {

    // MARK: - Public properties set before presentScene

    var completedOrder: Order?
    /// When true (launched from StorybookScene), each scene in the chain
    /// returns to StorybookScene on exit instead of FrontShopScene.
    var isReplayMode = false
    /// Page index within the replay chapter (4) to return to. Set by StorybookScene.
    /// Page 1 as of Phase 7b's storybook restructure (task 9) — page 0 is
    /// now the opening (DaphneBecomesTailorScene), which didn't share this
    /// chapter before.
    var replayReturnPage = 1

    // MARK: - Beat data

    private let beats: [String] = [
        "보랏빛 지팡이, 그림 붓, 팔레트, 그리고 왕실 가족 초상화...\n모두 던전에서 찾은 보물들인데, 왕실의 물건들 같아.",
        "혹시 없어진 에스텔 공주님과 관련있을까? 단서일지도 몰라. 꼭 갖다드려야겠어.",
        "그런데... 왕궁은 그냥 들어갈 수 없는데...\n먼저 오로라 선생님을 찾아가 봐야겠어. 분명 좋은 방법을 알려주실 거야!"
    ]

    // MARK: - State

    private var beatIndex = 0
    private var proceeding = false   // guards against double-tap once the exit fires

    // MARK: - HUD

    private var hud: NarrativeHUD!

    // MARK: - Scene setup

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        setupBackdrop()
        setupTailor()
        setupRelicOrbit()
        setupHUD(safeBottom: view.safeAreaInsets.bottom)
    }

    private func setupBackdrop() {
        let bg = SKSpriteNode(imageNamed: "WizardAssistant_Dungeon")
        bg.position = .zero
        bg.size = size
        bg.zPosition = 0
        addChild(bg)
    }

    private func setupTailor() {
        let tailor = SKSpriteNode(imageNamed: "Tailor")
        let targetHeight: CGFloat = 240
        if tailor.size.height > 0 { tailor.setScale(targetHeight / tailor.size.height) }
        tailor.position = CGPoint(x: 0, y: -size.height * 0.08)
        tailor.zPosition = 10
        addChild(tailor)
    }

    // MARK: - Relic orbit

    private func setupRelicOrbit() {
        let center = CGPoint(x: 0, y: -size.height * 0.08)
        let rx = size.width * 0.18
        let ry = size.height * 0.18

        let relics: [(DungeonItem, CGFloat)] = [
            (.purpleScepter,       0),
            (.paintBrush,          .pi / 2),
            (.palette,             .pi),
            (.royalFamilyPortrait, 3 * .pi / 2)
        ]

        for (item, startAngle) in relics {
            let initPos = CGPoint(
                x: center.x + cos(startAngle) * rx,
                y: center.y + sin(startAngle) * ry
            )
            let orbitAction = makeOrbitAction(startAngle: startAngle, center: center, rx: rx, ry: ry)

            // ── Layered gold halo (Daphne's warm gold #FFD54F) ────────────
            // Outer soft halo
            let outerGlow = SKShapeNode(circleOfRadius: 34)
            outerGlow.fillColor   = UIColor(red: 1.00, green: 0.88, blue: 0.45, alpha: 0.18)
            outerGlow.strokeColor = .clear
            outerGlow.zPosition   = 7
            outerGlow.position    = initPos
            addChild(outerGlow)
            outerGlow.run(orbitAction)

            // Mid ring with stroke edge
            let midGlow = SKShapeNode(circleOfRadius: 24)
            midGlow.fillColor   = UIColor(red: 1.00, green: 0.84, blue: 0.31, alpha: 0.55)
            midGlow.strokeColor = UIColor(red: 1.00, green: 0.95, blue: 0.65, alpha: 0.80)
            midGlow.lineWidth   = 2.5
            midGlow.zPosition   = 8
            midGlow.position    = initPos
            addChild(midGlow)
            midGlow.run(orbitAction)
            // Breathing pulse
            midGlow.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.30, duration: 0.7),
                .fadeAlpha(to: 1.00, duration: 0.7)
            ])))

            // Inner bright core
            let innerGlow = SKShapeNode(circleOfRadius: 13)
            innerGlow.fillColor   = UIColor(red: 1.00, green: 0.97, blue: 0.80, alpha: 0.75)
            innerGlow.strokeColor = .clear
            innerGlow.zPosition   = 9
            innerGlow.position    = initPos
            addChild(innerGlow)
            innerGlow.run(orbitAction)

            // Relic sprite — small enough that the halo ring shows around it
            let sprite = SKSpriteNode(imageNamed: item.rawValue)
            if sprite.size.width > 0 { sprite.setScale(26 / sprite.size.width) }
            sprite.zPosition = 10
            sprite.position  = initPos
            addChild(sprite)
            sprite.run(orbitAction)
        }
    }

    private func makeOrbitAction(startAngle: CGFloat, center: CGPoint,
                                  rx: CGFloat, ry: CGFloat) -> SKAction {
        let duration: TimeInterval = 6.0
        return SKAction.repeatForever(
            SKAction.customAction(withDuration: duration) { node, elapsed in
                let angle = startAngle + (elapsed / CGFloat(duration)) * .pi * 2
                node.position = CGPoint(
                    x: center.x + cos(angle) * rx,
                    y: center.y + sin(angle) * ry
                )
            }
        )
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
            ],
            sceneSize: size,
            safeBottom: safeBottom
        )

        hud.revealAll(activeSpeaker: "재봉사 다프네")
        hud.show(speaker: "재봉사 다프네", text: beats[0])
    }

    // MARK: - Beat advancement

    private func advanceBeat() {
        guard beatIndex < beats.count - 1 else {
            // Last beat read — proceed to Aurora's chamber on the next tap.
            proceedToAurora()
            return
        }
        beatIndex += 1
        hud.show(speaker: "재봉사 다프네", text: beats[beatIndex])
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !proceeding else { return }
        advanceBeat()
    }

    // MARK: - Exit — Aurora's chamber is now mandatory (owner request
    // 2026-09-09): the old A/B choice let a player skip straight to the
    // castle, but Aurora is the one who tells Daphne she can come back once
    // she levels up — skipping her meant the player never heard that line.

    private func proceedToAurora() {
        guard !proceeding else { return }
        proceeding = true

        run(.wait(forDuration: 0.3)) { [weak self] in self?.routeToAurora() }
    }

    private func routeToAurora() {
        guard let view = self.view else { return }

        if isReplayMode {
            // Replay mode: one scene at a time — return to the exact storybook page.
            let storybook = StorybookScene(size: size)
            // Chapter index 4 is the unified story chapter — unchanged by the
            // Phase 7b page-index migration (task 9), which only shifted page
            // numbers within it. See CLAUDE.md's page-index migration table.
            storybook.replayReturnChapter = 4
            storybook.replayReturnPage    = replayReturnPage
            storybook.scaleMode = .resizeFill
            view.presentScene(storybook, transition: SKTransition.crossFade(withDuration: 0.5))
            return
        }

        let aurora = AuroraChamberScene()
        aurora.scaleMode = .resizeFill
        aurora.completedOrder = completedOrder
        view.presentScene(aurora, transition: SKTransition.crossFade(withDuration: 0.6))
    }
}
