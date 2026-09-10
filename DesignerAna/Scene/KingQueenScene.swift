//
//  KingQueenScene.swift
//  DesignerAna
//
//  Task 8 — a narrative interlude in Ana's bedroom (reusing PrincessAnaScene's
//  backdrop): the King and Queen, alone, noticing both their daughters have
//  quietly drifted away — Estelle off chasing inspiration, Ana moonlighting
//  at the tailor shop — and neither girl has told them why. A small domestic
//  beat, not a plot-advancing one; Ana and Estelle do not appear on screen.
//
//  Presented from FrontShopScene right after a finished garment is saved to
//  the wardrobe, at 1500 마력 in Ana's era (see
//  FrontShopScene.handleSaveTrophy() — the gate lives there, not in
//  BackRoomScene, same reasoning as the Daphne→Ana handoff and the Estelle
//  epilogue: firing before the save would let this scene conclude and THEN
//  show the trophy, reading as if the tailor finished a dress she never
//  touched. This also satisfies the owner's spec that the scene must play
//  even if 1500 is crossed mid-dungeon — the gate is checked on every
//  trophy save, not at the moment the threshold is crossed.).
//
//  Reuses NarrativeHUD, the same shape as every other narrative scene;
//  AuroraChamberScene/PrincessAnaScene are the closest model — two speakers,
//  no mid-scene backdrop change, no title slate (this isn't a structural
//  story marker the way the opening/handoff/epilogue are).
//
//  Background: PrincessAna_Room (reused, not a new asset)
//  Speakers (NarrativeHUD has only two portrait slots — left/right):
//    left  → 왕비 (Queen) — speaks first
//    right → 왕 (King)
//

import SpriteKit
import UIKit

class KingQueenScene: SKScene {

    // MARK: - Navigation (set by StorybookScene for a replay)

    var isReplayMode = false
    /// Page index within the unified story chapter (4) to return to.
    var replayReturnPage = 5

    // MARK: - Beat data

    private struct Beat {
        let speaker: String
        let text: String
    }

    // Beats 0-11, alternating 왕비/왕 throughout — owner-provided dialogue,
    // verbatim.
    private let beats: [Beat] = [
        Beat(speaker: "왕비", text: "여보, 에스텔이 또 집을 비운 지 꽤 됐어요."),
        Beat(speaker: "왕",   text: "이번에는 어디 갔는지 알아요?"),
        Beat(speaker: "왕비", text: "그림 도구를 전부 챙겨 갔더라고요. 아마 영감을 찾으러 간 모양이에요."),
        Beat(speaker: "왕",   text: "흠… 왕궁에는 영감이 그렇게 없나?"),
        Beat(speaker: "왕비", text: "십 대 소녀에게 왕궁이란… 아마 영감보다는 잔소리가 많은 곳이겠죠."),
        Beat(speaker: "왕",   text: "그건 인정하오. 그런데 아나도 요즘 이상하던데. 재봉사 가게에서 아르바이트를 한다면서?"),
        Beat(speaker: "왕비", text: "네. 돈이 필요한 것도 아닌데 말이에요. 용돈도 충분히 주고 있는데!"),
        Beat(speaker: "왕",   text: "혹시 돈을 모아서 왕궁을 사려는 건 아닐까?"),
        Beat(speaker: "왕비", text: "설마요. 우리 딸들이 왕궁에서 도망치는 데는 익숙해도, 왕궁을 사서 들어올 아이들은 아니잖아요."),
        Beat(speaker: "왕",   text: "허허! 역시 우리 딸들이군. 하나는 영감을 찾아 떠나고, 하나는 바느질을 배우러 가고…"),
        Beat(speaker: "왕비", text: "그리고 둘 다 우리가 어디 있는지 굳이 알려주지 않고요."),
        Beat(speaker: "왕",   text: "……우리가 부모가 맞긴 한 거요?"),
    ]

    // MARK: - State

    private var beatIndex = 0
    private var exiting = false

    // MARK: - HUD

    private var hud: NarrativeHUD!

    // MARK: - Scene setup

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        setupBackdrop()
        setupCharacters()
        setupHUD(safeBottom: view.safeAreaInsets.bottom)
    }

    private func setupBackdrop() {
        let bg = SKSpriteNode(imageNamed: "PrincessAna_Room")
        bg.position  = .zero
        bg.size      = size
        bg.zPosition = 0
        addChild(bg)
    }

    // MARK: - Character sprites

    private func setupCharacters() {
        // Both KingCat/QueenCat art is drawn front-facing (verified by eye —
        // neither needs an xScale flip to "face" the other the way profile-
        // posed sprites elsewhere in this codebase do).
        let adultH: CGFloat = 310

        let queen = SKSpriteNode(imageNamed: "QueenCat")
        if queen.size.height > 0 { queen.setScale(adultH / queen.size.height) }
        queen.position  = CGPoint(x: -size.width * 0.15, y: -size.height * 0.12)
        queen.zPosition = 5
        addChild(queen)

        let king = SKSpriteNode(imageNamed: "KingCat")
        if king.size.height > 0 { king.setScale(adultH / king.size.height) }
        king.position  = CGPoint(x: size.width * 0.15, y: -size.height * 0.12)
        king.zPosition = 5
        addChild(king)
    }

    // MARK: - HUD setup

    private func setupHUD(safeBottom: CGFloat) {
        hud = NarrativeHUD()
        hud.zPosition = 50
        addChild(hud)

        hud.configure(
            speakers: [
                // Colors match GAME_VOCABULARY.md's established Character
                // Color Signatures table — sapphire for the King, ruby for
                // the Queen — not invented for this scene.
                SpeakerConfig(
                    name: "왕비",
                    portraitAsset: "Portrait_Queen",
                    slot: .left,
                    nameColor: UIColor(red: 0.75, green: 0.13, blue: 0.25, alpha: 1.0)
                ),
                SpeakerConfig(
                    name: "왕",
                    portraitAsset: "Portrait_King",
                    slot: .right,
                    nameColor: UIColor(red: 0.10, green: 0.32, blue: 0.69, alpha: 1.0)
                ),
            ],
            sceneSize: size,
            safeBottom: safeBottom
        )

        hud.revealAll(activeSpeaker: "왕비")
        hud.show(speaker: beats[0].speaker, text: beats[0].text)
    }

    // MARK: - Beat advancement

    private func advanceBeat() {
        beatIndex += 1
        guard beatIndex < beats.count else {
            startExit()
            return
        }
        hud.show(speaker: beats[beatIndex].speaker, text: beats[beatIndex].text)
    }

    // MARK: - Exit

    private func startExit() {
        exiting = true

        if isReplayMode {
            // Replay mode: return to the exact storybook page.
            guard let view = self.view else { return }
            let storybook = StorybookScene(size: size)
            // Chapter index 4 is the unified story chapter.
            storybook.replayReturnChapter = 4
            storybook.replayReturnPage    = replayReturnPage
            storybook.scaleMode = .resizeFill
            view.presentScene(storybook, transition: SKTransition.crossFade(withDuration: 0.5))
            return
        }

        // Not a story-advancing scene — no trophy/customer handoff to
        // forward, unlike TailorHandoffScene/EstelleEpilogueScene. The
        // trophy this order earned was already saved before this scene was
        // presented (see FrontShopScene.handleSaveTrophy()), so a fresh
        // FrontShopScene simply resumes normal play — its own didMove()
        // finds no active order and no finished-garment flag, and falls
        // through to the ordinary "choosingClothing" greeting, exactly what
        // would have happened if this scene hadn't fired at all.
        guard let view = self.view else { return }
        let shop = FrontShopScene(size: self.size)
        shop.scaleMode = self.scaleMode
        shop.suppressEntryBell = true
        view.presentScene(shop, transition: SKTransition.crossFade(withDuration: 0.6))
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !exiting, touches.first != nil else { return }

        if beatIndex == beats.count - 1 {
            startExit()
            return
        }

        advanceBeat()
    }
}
