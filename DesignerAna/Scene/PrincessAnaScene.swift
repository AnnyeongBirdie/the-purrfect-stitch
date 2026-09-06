//
//  PrincessAnaScene.swift
//  DesignerAna
//
//  Phase 5 final narrative scene. The tailor delivers the four relics to
//  Princess Ana, the Fairy Godmother reveals the curse story, then the
//  tailor returns home. Quest-complete flag is saved on exit.
//
//  Speaker layout:
//    left  → 재봉사 (Tailor), swaps to 대모 (Fairy Godmother) from beat 9 onwards
//    right → 아나 (Princess Ana)
//

import SpriteKit
import UIKit

class PrincessAnaScene: SKScene {

    // MARK: - Public properties forwarded from AuroraChamberScene / TailorChoiceScene

    var completedOrder: Order?
    /// When true, startOutro() returns to StorybookScene instead of FrontShopScene.
    var isReplayMode = false
    /// Page index within the replay chapter (4) to return to. Set by StorybookScene.
    var replayReturnPage = 2

    // MARK: - Beat data

    private struct Beat {
        let speaker: String
        let text: String
    }

    private let beats: [Beat] = [
        // 0
        Beat(speaker: "아나 공주",   text: "어머! 꼬마 재봉사님, 안녕하세요! 오늘은 어떤 일로 오셨어요? 😊"),
        // 1
        Beat(speaker: "재봉사 다프네", text: "공주님, 던전에서 이걸 찾았어요. 공주님께 드리고 싶었어요."),
        // 2 — relic 1 handoff fires
        Beat(speaker: "아나 공주",   text: "어머... 이건 에스텔 언니의 보랏빛 지팡이잖아요! 어디서 찾으셨어요?"),
        // 3
        Beat(speaker: "재봉사 다프네", text: "역시 에스텔 공주님의 물건이었군요. 원단 보관장 던전에서 찾았어요. 그리고 이것도요..."),
        // 4 — relic 2 handoff fires
        Beat(speaker: "아나 공주",   text: "그림 붓이에요! 언니가 항상 갖고 다니던 거예요. 😢"),
        // 5
        Beat(speaker: "재봉사 다프네", text: "재봉틀 던전에서 찾았어요. 그리고... 팔레트도요."),
        // 6 — relic 3 handoff fires
        Beat(speaker: "아나 공주",   text: "언니 물건들이 왜 던전에 있었던 걸까요... 마지막으로 이건 뭔가요?"),
        // 7
        Beat(speaker: "재봉사 다프네", text: "왕실 가족 초상화예요. 보스 던전 깊은 곳에 있었어요."),
        // 8 — relic 4 handoff fires
        Beat(speaker: "아나 공주",   text: "이건... 이건 우리 가족 초상화예요. 그런데 여기 이 작은 달팽이는 누구일 까요?"),
        // 9 — Godmother entrance fires; taps blocked until waitingForGodmother == false
        Beat(speaker: "아나 공주",   text: "로즈예요. 우리 가족의 반려 달팽이였는데, 어느 날 갑자기 사라졌어요. 요정 대모님! 와주세요!"),
        // 10 — Godmother's first line (shown after entrance completes)
        Beat(speaker: "요정 대모 플로라",   text: "나를 불렀니, 아나? 어머 꼬마 재봉사님도 오셨군요. 에스텔의 물건을 다 찾으셨나 보내요! ✨"),
        Beat(speaker: "요정 대모 플로라",   text: "로즈는... 저주를 받았어요. 그 저주가 로즈를 털실 몬스터로 만들었지요."),
        Beat(speaker: "요정 대모 플로라",   text: "왕실 가족도 함께 저주를 받아, 로즈의 존재를 모두 잊어버렸답니다."),
        Beat(speaker: "요정 대모 플로라",   text: "먼지 몬스터들은 나쁜 존재가 아니에요. 저주받은 존재들에게 안식처를 주는 거랍니다."),
        Beat(speaker: "요정 대모 플로라",   text: "재봉사님이 몬스터를 물리치면, 몬스터는 잠시 잠드는 것뿐이에요. 상처를 입히는 게 아니랍니다."),
        Beat(speaker: "아나 공주",   text: "그럼 언니는... 로즈를 찾으러 던전에 갔던 거군요."),
        // 16 — Godmother exit fires when tapped
        Beat(speaker: "요정 대모 플로라",   text: "그렇단다. 에스텔은 용감한 아이였어. 이 보물들은 그 증거지요."),
        // 17 — shown after Godmother exits
        Beat(speaker: "아나 공주",   text: "꼬마 재봉사님, 정말 감사해요. 언니의 물건들을 찾아주셔서요. 🤍"),
        // 18 — souvenir selfie-gift handoff fires (Ana → Daphne, fairy magic)
        Beat(speaker: "아나 공주",   text: "아 참, 이거 받으세요! 우리 둘이 함께 찍은 사진이에요. 제 마법으로 보내드릴게요! ✨"),
        // 19 — outro triggers on tap
        Beat(speaker: "아나 공주",   text: "이제 저도 모험을 할 때가 된거 같아요. 도움이 필요하면 제가 나중에 가게로 찾아 갈게요!\n어서 가게로 돌아가세요. 기다리는 손님이 있을 거예요. "),
    ]

    // MARK: - State

    private var beatIndex = 0

    // Godmother entrance — set true after beat 9; entrance fires on the next tap.
    private var readyForGodmother = false
    // Blocks all taps during the fade-in animation.
    private var waitingForGodmother = false
    // Godmother exit — blocks taps during the 0.5 s fade-out.
    private var waitingForGodmotherExit = false
    private var godmotherExited = false

    private var outroStarted = false
    /// Tracks in-flight relic animations; taps are blocked while this is > 0.
    private var activeRelicAnimations = 0
    /// Blocks taps while the souvenir selfie-gift animation is in flight.
    private var selfieGiftInFlight = false

    // MARK: - HUD

    private var hud: NarrativeHUD!

    // MARK: - Character sprites (scene dressing — behind HUD, zPosition 5)

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

    // MARK: - Character sprites setup

    private func setupCharacters() {
        let tailorHeight: CGFloat = 240
        let adultHeight:  CGFloat = 310

        let tailor = SKSpriteNode(imageNamed: "Tailor")
        if tailor.size.height > 0 { tailor.setScale(tailorHeight / tailor.size.height) }
        tailor.xScale *= -1   // face right toward Ana and the Godmother
        tailor.position = CGPoint(x: -size.width * 0.22, y: -size.height * 0.15)
        tailor.zPosition = 5
        addChild(tailor)
        tailorSprite = tailor

        let ana = SKSpriteNode(imageNamed: "SecondPrincessCat")
        if ana.size.height > 0 { ana.setScale(adultHeight / ana.size.height) }
        // Same y as Flora (enterGodmother(), below) — Ana's old -0.15 let her
        // feet clip the bottom edge; -0.08 matches where Flora stands.
        ana.position = CGPoint(x: size.width * 0.22, y: -size.height * 0.08)
        ana.zPosition = 5
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
                    slot: .left,        // shares left slot with Daphne; portrait-swapped on beat 9
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

        // Beats 2/4/6/8/18 are a character reacting to an item that's still
        // mid-flight — showing that line at tap-time (when the item launches)
        // read as recognizing it before it arrived. Owner feedback after a
        // full playthrough: "off by one beat." Fixed by deferring hud.show()
        // for these specific beats until the animation's completion callback
        // fires (right as the item reaches its target), instead of showing
        // it unconditionally here. Every other beat is unaffected.
        switch beatIndex {
        case 2: animateRelicHandoff(.purpleScepter) { [weak self] in self?.showCurrentBeat() }
        case 4: animateRelicHandoff(.paintBrush)    { [weak self] in self?.showCurrentBeat() }
        case 6: animateRelicHandoff(.palette)       { [weak self] in self?.showCurrentBeat() }
        case 8: animateRelicHandoff(.royalFamilyPortrait) { [weak self] in self?.showCurrentBeat() }
        case 9:
            // Player needs to read Ana's summons first; entrance fires on the next tap.
            readyForGodmother = true
            showCurrentBeat()
        case 18: animateSelfieGift { [weak self] in self?.showCurrentBeat() }
        default:
            showCurrentBeat()
        }
    }

    private func showCurrentBeat() {
        hud.show(speaker: beats[beatIndex].speaker, text: beats[beatIndex].text)
    }

    // MARK: - Relic handoff animation

    private func animateRelicHandoff(_ item: DungeonItem, onArrival: @escaping () -> Void) {
        activeRelicAnimations += 1

        // ── Phase 1: orbit around Daphne's hands/chest ────────────────────
        let orbitCenter = CGPoint(x: tailorSprite.position.x,
                                  y: tailorSprite.position.y + 55)
        let rx: CGFloat = 54
        let ry: CGFloat = 32

        // Container holds glow layers + relic and travels as one object.
        let container = SKNode()
        container.position = CGPoint(x: orbitCenter.x + rx, y: orbitCenter.y)
        container.zPosition = 15  // above sprites (5), below HUD (50)
        addChild(container)

        // ── Layered gold halo (Daphne's warm gold #FFD54F) ────────────────
        // Outer soft halo — wide, very translucent
        let outerGlow = SKShapeNode(circleOfRadius: 34)
        outerGlow.fillColor   = UIColor(red: 1.00, green: 0.88, blue: 0.45, alpha: 0.18)
        outerGlow.strokeColor = .clear
        container.addChild(outerGlow)

        // Mid ring with a visible stroke for a halo "edge"
        let midGlow = SKShapeNode(circleOfRadius: 24)
        midGlow.fillColor   = UIColor(red: 1.00, green: 0.84, blue: 0.31, alpha: 0.55)
        midGlow.strokeColor = UIColor(red: 1.00, green: 0.95, blue: 0.65, alpha: 0.80)
        midGlow.lineWidth   = 2.5
        container.addChild(midGlow)

        // Inner bright core — small, high-alpha
        let innerGlow = SKShapeNode(circleOfRadius: 13)
        innerGlow.fillColor   = UIColor(red: 1.00, green: 0.97, blue: 0.80, alpha: 0.75)
        innerGlow.strokeColor = .clear
        container.addChild(innerGlow)

        // Breathing pulse on the mid glow so the halo visibly shimmers
        let breathe = SKAction.sequence([
            .fadeAlpha(to: 0.30, duration: 0.7),
            .fadeAlpha(to: 1.00, duration: 0.7)
        ])
        midGlow.run(.repeatForever(breathe))

        // ── Relic sprite — small enough that the halo ring shows around it ──
        let relicSprite = SKSpriteNode(imageNamed: item.assetName)
        if relicSprite.size.width > 0 { relicSprite.setScale(26 / relicSprite.size.width) }
        relicSprite.zPosition = 2
        container.addChild(relicSprite)

        // ── Phase 2: float to Ana's hands/chest ───────────────────────────
        let target = CGPoint(x: anaSprite.position.x - 30,
                             y: anaSprite.position.y + 55)

        // Tester feedback: the handoff felt slow across all 4 relics. Cut the
        // loop from ~1.6 revolutions to 1, and scaled orbitDuration down by
        // the same ratio so the circling speed reads the same as before —
        // just one lap instead of one-and-a-half, not a slow-motion single lap.
        let orbitDuration: TimeInterval = 1.375
        let revolutions:   CGFloat      = 1.0

        let orbitAction = SKAction.customAction(withDuration: orbitDuration) { node, elapsed in
            let angle = (elapsed / CGFloat(orbitDuration)) * .pi * 2 * revolutions
            node.position = CGPoint(x: orbitCenter.x + cos(angle) * rx,
                                    y: orbitCenter.y + sin(angle) * ry)
        }

        let floatMove = SKAction.move(to: target, duration: 1.3)
        floatMove.timingMode = .easeInEaseOut

        container.run(.sequence([
            orbitAction,
            floatMove,
            // Arrival — Ana's recognition line fires here, not at launch.
            .run { onArrival() },
            .wait(forDuration: 0.25),
            .fadeOut(withDuration: 0.25),
            .run { [weak self] in self?.activeRelicAnimations -= 1 },
            .removeFromParent()
        ]))
    }

    // MARK: - Selfie-gift animation (Ana → Daphne, fairy magic)

    // Ana's own fairy-magic effect for the souvenir handoff — a distinct
    // visual language from animateRelicHandoff's gold (Daphne's wizard
    // magic, orbit-then-float, matching MAGIC.md's yellow=wizard rule) and
    // from spawnSparkles' silver (Flora the godmother's, radial one-shot
    // burst). Ana's color is her established emerald green (#4CB87A — the
    // same nameColor used for her in this scene's NarrativeHUD config
    // above), and the moving light leaves a continuously-spawned trailing
    // comet tail behind it (Tinker Bell-style) rather than a static halo or
    // a burst — reads as a different kind of magic, not just a recolor.
    private func animateSelfieGift(onArrival: @escaping () -> Void) {
        selfieGiftInFlight = true
        let anaGreen = UIColor(red: 0.30, green: 0.72, blue: 0.48, alpha: 1.0)
        // Brighter, lighter mint used only for the trail particles — plain
        // anaGreen read as "barely visible" on device (owner feedback after
        // a full playthrough); a lighter, more saturated highlight plus a
        // white stroke gives each spark contrast against the backdrop,
        // matching the fix already proven for the level-up VFX's sparks.
        let trailColor = UIColor(red: 0.55, green: 0.95, blue: 0.75, alpha: 1.0)

        // ── Phase 1: a quick gathering flourish near Ana ───────────────────
        let orbitCenter = CGPoint(x: anaSprite.position.x - 30, y: anaSprite.position.y + 55)
        let rx: CGFloat = 40
        let ry: CGFloat = 22

        let container = SKNode()
        container.position = CGPoint(x: orbitCenter.x + rx, y: orbitCenter.y)
        container.zPosition = 15  // above sprites (5), below HUD (50)
        addChild(container)

        let outerGlow = SKShapeNode(circleOfRadius: 30)
        outerGlow.fillColor   = anaGreen.withAlphaComponent(0.18)
        outerGlow.strokeColor = .clear
        container.addChild(outerGlow)

        let midGlow = SKShapeNode(circleOfRadius: 20)
        midGlow.fillColor   = anaGreen.withAlphaComponent(0.55)
        midGlow.strokeColor = UIColor(red: 0.75, green: 0.95, blue: 0.85, alpha: 0.80)
        midGlow.lineWidth   = 2.5
        container.addChild(midGlow)

        let innerGlow = SKShapeNode(circleOfRadius: 11)
        innerGlow.fillColor   = UIColor(red: 0.85, green: 1.00, blue: 0.92, alpha: 0.80)
        innerGlow.strokeColor = .clear
        container.addChild(innerGlow)

        midGlow.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.30, duration: 0.5),
            .fadeAlpha(to: 1.00, duration: 0.5)
        ])))

        // ── The keepsake itself — reuses the existing Selfie asset, no new
        // art needed (same one BackRoomScene used to hang on the wall) ─────
        let selfieSprite = SKSpriteNode(imageNamed: "Selfie_TailorAndPrincessAna")
        if selfieSprite.size.width > 0 { selfieSprite.setScale(38 / selfieSprite.size.width) }
        selfieSprite.zPosition = 2
        container.addChild(selfieSprite)

        // ── Phase 2: float to Daphne, trailing a comet tail the whole way ──
        let target = CGPoint(x: tailorSprite.position.x, y: tailorSprite.position.y + 55)

        let orbitDuration: TimeInterval = 0.8
        let orbitAction = SKAction.customAction(withDuration: orbitDuration) { node, elapsed in
            let angle = (elapsed / CGFloat(orbitDuration)) * .pi * 2
            node.position = CGPoint(x: orbitCenter.x + cos(angle) * rx,
                                    y: orbitCenter.y + sin(angle) * ry)
        }

        let floatDuration: TimeInterval = 1.1
        let floatMove = SKAction.move(to: target, duration: floatDuration)
        floatMove.timingMode = .easeInEaseOut

        // Each trail particle spawns at the container's live position and
        // just fades/shrinks in place — a trailing streak behind the light,
        // not a radial burst (that look is reserved for spawnSparkles() /
        // animateRelicHandoff's language elsewhere in this scene). Bigger,
        // brighter, longer-lived, and spawned more often than the first pass
        // — that version was confirmed "barely visible" on-device.
        let spawnTrailParticle = SKAction.run { [weak self, weak container] in
            guard let self, let container else { return }
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 5...9))
            particle.fillColor = trailColor
            particle.strokeColor = UIColor.white.withAlphaComponent(0.7)
            particle.lineWidth = 1
            particle.position = container.position
            particle.zPosition = 14
            self.addChild(particle)
            particle.run(.sequence([
                .group([
                    .fadeOut(withDuration: 0.6),
                    .scale(to: 0.15, duration: 0.6)
                ]),
                .removeFromParent()
            ]))
        }
        let tickInterval: TimeInterval = 0.025
        let trail = SKAction.repeat(.sequence([spawnTrailParticle, .wait(forDuration: tickInterval)]),
                                    count: Int(floatDuration / tickInterval))

        container.run(.sequence([
            orbitAction,
            .group([floatMove, trail]),
            // Arrival — Ana's "here, take this" line fires here, not at
            // launch (same off-by-one-beat fix as animateRelicHandoff).
            .run { onArrival() },
            .wait(forDuration: 0.3),
            .fadeOut(withDuration: 0.3),
            .run { [weak self] in self?.selfieGiftInFlight = false },
            .removeFromParent()
        ]))
    }

    // MARK: - Godmother entrance

    private func enterGodmother() {
        // Spawn full-body sprite at center and fade it in.
        // Once it's fully visible, swap Daphne's portrait for Flora's in the left slot.
        let gm = SKSpriteNode(imageNamed: "GodmotherCat")
        let adultHeight: CGFloat = 310
        if gm.size.height > 0 { gm.setScale(adultHeight / gm.size.height) }
        gm.position = CGPoint(x: 0, y: -size.height * 0.08)
        gm.zPosition = 5
        gm.alpha = 0
        addChild(gm)
        godmotherSprite = gm

        spawnSparkles(at: gm.position)

        gm.run(.fadeIn(withDuration: 0.9)) { [weak self] in
            guard let self else { return }
            self.waitingForGodmother = false
            self.beatIndex = 10
            self.hud.hideSpeaker(named: "재봉사 다프네")
            self.hud.revealSpeaker(named: "요정 대모 플로라")
            self.hud.show(speaker: self.beats[10].speaker, text: self.beats[10].text)
        }
    }

    // MARK: - Godmother exit

    private func exitGodmother() {
        waitingForGodmotherExit = true
        hud.hideSpeaker(named: "요정 대모 플로라")
        godmotherSprite?.run(.fadeOut(withDuration: 0.5))

        run(.wait(forDuration: 0.9)) { [weak self] in
            guard let self else { return }
            self.godmotherSprite?.removeFromParent()
            self.godmotherSprite = nil
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
        guard let view = self.view else { return }

        if isReplayMode {
            // Return to the exact storybook page without re-saving quest state.
            let storybook = StorybookScene(size: size)
            storybook.replayReturnChapter = 4
            storybook.replayReturnPage    = replayReturnPage
            storybook.scaleMode = .resizeFill
            view.presentScene(storybook, transition: SKTransition.crossFade(withDuration: 0.6))
            return
        }

        Store.saveRelicQuestComplete()
        let next = FrontShopScene(size: self.size)
        next.scaleMode = .resizeFill
        next.shouldShowFinishedGarment = true
        next.finishedGarmentImageName = garmentImageName(for: completedOrder)
        next.completedOrder = completedOrder
        next.suppressEntryBell = true
        // Ana promises a customer will be waiting but doesn't say who — she's
        // a princess, she wasn't told. Once this trophy is saved, hand off to
        // the customer picker instead of resuming with the same customer.
        next.triggerCustomerPickerAfterSave = true
        view.presentScene(next, transition: SKTransition.crossFade(withDuration: 0.8))
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !outroStarted else { return }
        guard touches.first != nil else { return }

        // Beat 9 flag: player has read Ana's summons, now trigger godmother entrance.
        if readyForGodmother {
            readyForGodmother = false
            waitingForGodmother = true
            enterGodmother()
            return
        }

        // Block during animated transitions and while relics/selfie are in flight.
        if waitingForGodmother || waitingForGodmotherExit { return }
        if activeRelicAnimations > 0 || selfieGiftInFlight { return }

        // Beat 16: Godmother exit on first tap.
        if beatIndex == 16 && !godmotherExited {
            exitGodmother()
            return
        }

        // Beat 19: outro.
        if beatIndex == 19 {
            startOutro()
            return
        }

        advanceBeat()
    }
}
