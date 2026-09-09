import SpriteKit

class BackRoomScene: SKScene {

    private enum BackRoomState: String {
        case waitingForCabinetTap
        case walkingToCabinet

        case waitingForSewing
        case walkingToSewing

        case waitingForButtons
        case walkingToButtons

        case waitingForMannequin
        case walkingToMannequin
        case finalCheck

        case completed
    }

    private var currentState: BackRoomState = .waitingForCabinetTap {
        didSet {
            saveActiveOrderSnapshot()
            updateStationFireflies()
        }
    }

    var order: Order?
    var resumeStateName: String?
    // (resumeEarnedRewards removed — Economy refactor #2)

    private let cabinetInteractionX: CGFloat = -180

    private var haloLight: UIColor {
        switch order?.fabricColor {
        case .blue:   return UIColor(red: 0.75, green: 0.88, blue: 1.00, alpha: 1.0)
        case .yellow: return UIColor(red: 1.00, green: 0.97, blue: 0.65, alpha: 1.0)
        default:      return UIColor(red: 1.00, green: 0.80, blue: 0.86, alpha: 1.0)  // .pink or nil
        }
    }
    private var haloMedium: UIColor {
        switch order?.fabricColor {
        case .blue:   return UIColor(red: 0.20, green: 0.50, blue: 0.95, alpha: 1.0)
        case .yellow: return UIColor(red: 0.95, green: 0.80, blue: 0.10, alpha: 1.0)
        default:      return UIColor(red: 0.95, green: 0.38, blue: 0.60, alpha: 1.0)  // .pink or nil
        }
    }
    private var haloDark: UIColor {
        switch order?.fabricColor {
        case .blue:   return UIColor(red: 0.05, green: 0.15, blue: 0.70, alpha: 1.0)
        case .yellow: return UIColor(red: 0.75, green: 0.50, blue: 0.00, alpha: 1.0)
        default:      return UIColor(red: 0.70, green: 0.05, blue: 0.28, alpha: 1.0)  // .pink or nil
        }
    }

    private var tailor: SKSpriteNode!
    private var tailorIdentity: TailorIdentity!
    private var instructionLabel: SKLabelNode!

    private var tailorHaloNode: SKShapeNode?
    private var activeMinigame: MinigameNode?

    private var activeBossMinigame: BossMinigameNode?
    private var walletLabel: SKLabelNode?
    private var magicLabel: SKLabelNode?
    // Tailor/Customer Status HUD panels (Phase 7 redesign, shipped 2026-09-06).
    // The bubbles themselves are kept as properties (not just their labels)
    // so the panel backgrounds and the ✨ badge can be positioned relative
    // to their actual frames instead of re-deriving the same layout math twice.
    private var magicBubbleNode: SKShapeNode?
    private var walletBubbleNode: SKShapeNode?
    private var levelUpBadgeNode: SKShapeNode?
    private var gameCompleteBadgeNode: SKShapeNode?
    // Panel backgrounds built by setupStatusPanels() — kept as properties
    // (added 2026-09-09) so their zPosition can be boosted while a dungeon
    // minigame is on screen; see setStatusHUDBoosted(_:) below.
    private var tailorPanelNode: SKShapeNode?
    private var customerPanelNode: SKShapeNode?
    private var instructionShadowLabel: SKLabelNode!

    // (earnedMinigameRewards removed — Economy refactor #2; dungeons now credit Magic directly)
    private var quitButton: SKShapeNode?
    private var exitDialogNode: SKNode?
    private var relicSlots: [SKShapeNode] = []

    // Per-station firefly containers — only the active station's group is
    // visible at a time (see updateStationFireflies()).
    private var fireflyGroupFabric: SKNode?
    private var fireflyGroupSewing: SKNode?
    private var fireflyGroupButtons: SKNode?
    private var fireflyGroupMannequin: SKNode?


    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = true
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        setupBackground()
        setupTailor()
        setupFabricCabinetZone()
        setupSewingStationZone()
        setupButtonZone()
        setupMannequinZone()
        setupInstructionLabel()
        setupHUDCounters()
        setupRelicHUD()
        updateRelicHUD()
        setupStatusPanels()
        setupStationFireflies()
        setupQuitButton()
        applyResumeStateIfNeeded()
        saveActiveOrderSnapshot()
        // setupSelfieKeepsake() disabled 2026-09-06 — owner decided this wall
        // is the wrong wall. The selfie should follow Daphne and hang wherever
        // she resumes her wizard-magic training (the not-yet-built scene tied
        // to her potion-cooking side quest, per CLAUDE.md's "explicitly out of
        // scope for this phase" note), not stay behind in Polaris's shop once
        // Ana becomes the working tailor. Function kept below, unwired, as a
        // reference for whichever scene ends up hanging it.
    }

    private func setupSelfieKeepsake() {
        let selfie = SKSpriteNode(imageNamed: "Selfie_TailorAndPrincessAna")
        selfie.size = CGSize(width: 72, height: 72)
        selfie.position = CGPoint(x: size.width * 0.42, y: size.height * 0.28)
        selfie.zPosition = 3
        addChild(selfie)
    }

    private func setupBackground() {
        let background = SKSpriteNode(imageNamed: "Backroom_Background")
        background.position = CGPoint(x: 0, y: 0)
        background.zPosition = 0
        background.size = self.size
        addChild(background)
    }

    private func setupTailor() {
        let identity = Tailor.identity(for: Store.loadCurrentTailor())
        let tailor = SKSpriteNode(imageNamed: identity.spriteAssetName)
        tailor.position = CGPoint(x: 0, y: -40)
        tailor.zPosition = 10
        tailor.name = "tailor"
        applyTailorScale(to: tailor, targetHeight: identity.renderedHeight)

        self.tailor = tailor
        self.tailorIdentity = identity
        addChild(tailor)
    }

    // Halo pill, tuned by eye against Ana's reference height/silhouette.
    // Scaled down by Tailor.haloScale for shorter tailors (Daphne, 0.70)
    // so it reads as "glowing from within" rather than sticking out past a
    // narrower body — owner feedback after seeing it on-device with Daphne.
    private var haloBaseSize: CGSize {
        let scale = Tailor.haloScale(for: tailorIdentity)
        return CGSize(width: 70 * scale, height: 200 * scale)
    }

    // Each tailor renders at their own intended on-screen height
    // (TailorIdentity.renderedHeight), independent of the sprite's own
    // pixel size or asset-catalog scale-slot registration (2x vs 1x) — same
    // gotcha and fix as the Phase 6b customer-NPC scale bug (see CLAUDE.md).
    private func applyTailorScale(to sprite: SKSpriteNode, targetHeight: CGFloat) {
        if let height = sprite.texture?.size().height, height > 0 {
            sprite.setScale(targetHeight / height)
        } else {
            sprite.setScale(0.32)
        }
    }

    private func setupFabricCabinetZone() {
        let zone = SKShapeNode(rectOf: CGSize(width: 130, height: 260), cornerRadius: 12)
        zone.position = CGPoint(x: -280, y: 20)
        zone.fillColor = .clear
        zone.strokeColor = .clear
        zone.lineWidth = 3
        zone.name = "fabricCabinet"
        zone.zPosition = 5

        addChild(zone)
    }
    
    private func setupSewingStationZone() {
        let zone = SKShapeNode(rectOf: CGSize(width: 150, height: 200), cornerRadius: 12)
        zone.position = CGPoint(x: 190, y: 0)

        zone.fillColor = .clear
        zone.strokeColor = .clear

        zone.name = "sewingStation"
        zone.zPosition = 5

        addChild(zone)
    }
    
    private func setupButtonZone() {
        let zone = SKShapeNode(rectOf: CGSize(width: 150, height: 200), cornerRadius: 12)
        zone.position = CGPoint(x: 300, y: 0)

        zone.fillColor = .clear
        zone.strokeColor = .clear

        zone.name = "buttonStation"
        zone.zPosition = 5

        addChild(zone)
    }

    private func setupInstructionLabel() {
        // Shadow clone sits behind the main label to improve readability
        // over the bright back-room background.
        instructionShadowLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        instructionShadowLabel.text = "원단 보관장을 눌러보세요."
        instructionShadowLabel.fontSize = 24
        instructionShadowLabel.fontColor = UIColor(white: 0, alpha: 0.55)
        instructionShadowLabel.position = CGPoint(x: 2, y: -2)
        instructionShadowLabel.zPosition = -1   // behind the parent label

        instructionLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        instructionLabel.text = "원단 보관장을 눌러보세요."
        instructionLabel.fontSize = 24
        instructionLabel.fontColor = .white
        instructionLabel.position = CGPoint(x: 0, y: 150)
        instructionLabel.zPosition = 20
        instructionLabel.addChild(instructionShadowLabel)
        addChild(instructionLabel)
    }

    /// Updates both the instruction label and its drop shadow in one call.
    private func setInstructionText(_ text: String) {
        instructionLabel.text = text
        instructionShadowLabel.text = text
    }

    private func setupStationFireflies() {
        fireflyGroupFabric    = makeFireflyGroup(at: CGPoint(x: -280, y: 20))
        fireflyGroupSewing    = makeFireflyGroup(at: CGPoint(x: 190,  y: 0))
        fireflyGroupButtons   = makeFireflyGroup(at: CGPoint(x: 300,  y: 0))
        fireflyGroupMannequin = makeFireflyGroup(at: CGPoint(x: 0,    y: 10))
        updateStationFireflies()
    }

    /// Builds one station's firefly cluster as a single container at the
    /// station's center. Fireflies use container-local positions so the
    /// container alpha (driven by updateStationFireflies()) gates all four
    /// without touching the individual cycle animations.
    private func makeFireflyGroup(at center: CGPoint) -> SKNode {
        let group = SKNode()
        group.position = center
        group.zPosition = 4
        group.alpha = 0                  // initial visibility set by updateStationFireflies()
        addChild(group)

        let fireflyColor = UIColor(red: 1.0, green: 0.95, blue: 0.5, alpha: 1.0)
        for i in 0..<4 {
            let firefly = SKShapeNode(circleOfRadius: 3.5)
            firefly.fillColor = fireflyColor
            firefly.strokeColor = .clear
            firefly.glowWidth = 6
            firefly.alpha = 0
            firefly.position = CGPoint(
                x: CGFloat.random(in: -40...40),
                y: CGFloat.random(in: -60...30)
            )
            group.addChild(firefly)

            let cycle = SKAction.sequence([
                SKAction.run { [weak firefly] in
                    firefly?.position = CGPoint(
                        x: CGFloat.random(in: -40...40),
                        y: CGFloat.random(in: -60...30)
                    )
                    firefly?.alpha = 0
                },
                SKAction.fadeIn(withDuration: 0.5),
                SKAction.group([
                    SKAction.moveBy(x: 0, y: 55, duration: 1.6),
                    SKAction.sequence([
                        SKAction.wait(forDuration: 0.9),
                        SKAction.fadeOut(withDuration: 0.7)
                    ])
                ]),
                SKAction.wait(forDuration: 0.3)
            ])
            firefly.run(.sequence([
                .wait(forDuration: Double(i) * 0.6),
                .repeatForever(cycle)
            ]))
        }
        return group
    }

    /// Fades the active station's firefly group in and the others out, based
    /// on currentState. Called from setupStationFireflies() and from
    /// currentState's didSet so the visible group always tracks the player's
    /// next target.
    private func updateStationFireflies() {
        let target = activeFireflyGroup()
        let groups: [SKNode?] = [
            fireflyGroupFabric,
            fireflyGroupSewing,
            fireflyGroupButtons,
            fireflyGroupMannequin,
        ]
        for group in groups {
            guard let group = group else { continue }
            let goal: CGFloat = (group === target) ? 1.0 : 0.0
            group.run(.fadeAlpha(to: goal, duration: 0.3), withKey: "fireflyFade")
        }
    }

    private func activeFireflyGroup() -> SKNode? {
        switch currentState {
        case .waitingForCabinetTap, .walkingToCabinet:
            return fireflyGroupFabric
        case .waitingForSewing, .walkingToSewing:
            return fireflyGroupSewing
        case .waitingForButtons, .walkingToButtons:
            return fireflyGroupButtons
        case .waitingForMannequin, .walkingToMannequin:
            return fireflyGroupMannequin
        case .finalCheck, .completed:
            return nil
        }
    }

    // Two lines (name + counter) — constrained above the relic row, which
    // sits at a fixed Y shared with MinigameNode/BossMinigameNode's relic-
    // fly-to-slot targets (see relicRowTopInset below). 62pt leaves a clean
    // gap without overlapping the relic row.
    private let tailorBubbleSize = CGSize(width: 160, height: 62)
    // Three lines (name + counter + garment) — nothing fixed sits below this
    // one, so it's free to be as tall as it needs for a comfortable fit.
    private let customerBubbleSize = CGSize(width: 170, height: 84)

    // Combined "how far below the top-left bubble's bottom edge the relic
    // row starts" offset — was 8(topInset)+36(old 1-line bubble)+6(gap)=50
    // before the Status HUD redesign; the tailor bubble is now taller
    // (62pt) so this grew to keep a positive gap instead of overlapping it
    // (a bug found via on-device screenshot: the old 50 put the relic row
    // 14pt *inside* the taller bubble's bottom edge). Mirrored exactly in
    // MinigameNode.swift/BossMinigameNode.swift's relic-fly-to-slot target
    // math — if this changes again, update those two files' `slotY` too.
    private let relicRowTopInset: CGFloat = 8 + 62 + 10

    private func setupHUDCounters() {
        let bubbleStyle: (SKShapeNode, CGPoint, CGSize) -> Void = { bubble, center, bubbleSize in
            bubble.fillColor = UIColor(red: 0.98, green: 0.95, blue: 0.85, alpha: 0.93)
            bubble.strokeColor = UIColor(red: 0.55, green: 0.35, blue: 0.10, alpha: 1.0)
            bubble.lineWidth = 2
            bubble.position = center
            bubble.zPosition = 20
            self.addChild(bubble)
        }

        // Customer Status HUD (top-right): customer name, 💰 counter, ordered
        // garment. Top edge unchanged from the old single-line wallet bubble.
        let walletCenter = CGPoint(x: size.width * 0.36,
                                   y: size.height * 0.44 + 18 - customerBubbleSize.height / 2)
        let walletBubble = SKShapeNode(rectOf: customerBubbleSize, cornerRadius: 20)
        bubbleStyle(walletBubble, walletCenter, customerBubbleSize)
        walletBubbleNode = walletBubble

        let custNameLbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        custNameLbl.text = ProfileManager.shared.selectedDisplayName
        custNameLbl.fontSize = 13
        custNameLbl.fontColor = UIColor(red: 0.30, green: 0.14, blue: 0.00, alpha: 1.0)
        custNameLbl.horizontalAlignmentMode = .center
        custNameLbl.verticalAlignmentMode = .center
        custNameLbl.position = CGPoint(x: 0, y: 26)
        custNameLbl.zPosition = 1
        walletBubble.addChild(custNameLbl)

        let walletLbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        walletLbl.text = "💰 \(Wallet.shared.balance)냥"
        walletLbl.fontSize = 17
        walletLbl.fontColor = UIColor(red: 0.30, green: 0.14, blue: 0.00, alpha: 1.0)
        walletLbl.horizontalAlignmentMode = .center
        walletLbl.verticalAlignmentMode = .center
        walletLbl.position = CGPoint(x: 0, y: 0)
        walletLbl.zPosition = 1
        walletBubble.addChild(walletLbl)
        walletLabel = walletLbl

        if let order {
            let garmentLbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
            garmentLbl.text = "\(order.fabricColor.displayName) \(order.clothingType.displayName)"
            garmentLbl.fontSize = 12
            garmentLbl.fontColor = UIColor(red: 0.45, green: 0.30, blue: 0.10, alpha: 1.0)
            garmentLbl.horizontalAlignmentMode = .center
            garmentLbl.verticalAlignmentMode = .center
            garmentLbl.position = CGPoint(x: 0, y: -26)
            garmentLbl.zPosition = 1
            walletBubble.addChild(garmentLbl)
        }

        // Tailor Status HUD (top-left): tailor name, 🐾 counter, relic row
        // (relic row is built separately by setupRelicHUD(), at a fixed Y
        // that accounts for this bubble's height via relicRowTopInset).
        let magicCenter = CGPoint(x: -size.width / 2 + 24 + tailorBubbleSize.width / 2,
                                  y:  size.height / 2 - 8 - tailorBubbleSize.height / 2)
        let magicBubble = SKShapeNode(rectOf: tailorBubbleSize, cornerRadius: 20)
        bubbleStyle(magicBubble, magicCenter, tailorBubbleSize)
        magicBubbleNode = magicBubble

        let tailorNameLbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        tailorNameLbl.text = tailorIdentity.displayName
        tailorNameLbl.fontSize = 13
        tailorNameLbl.fontColor = UIColor(red: 0.30, green: 0.14, blue: 0.00, alpha: 1.0)
        tailorNameLbl.horizontalAlignmentMode = .center
        tailorNameLbl.verticalAlignmentMode = .center
        tailorNameLbl.position = CGPoint(x: 0, y: 16)
        tailorNameLbl.zPosition = 1
        magicBubble.addChild(tailorNameLbl)

        let magicLbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        magicLbl.text = "🐾 \(Magic.shared.points)마력"
        magicLbl.fontSize = 17
        magicLbl.fontColor = UIColor(red: 0.30, green: 0.14, blue: 0.00, alpha: 1.0)
        magicLbl.horizontalAlignmentMode = .center
        magicLbl.verticalAlignmentMode = .center
        magicLbl.position = CGPoint(x: 0, y: -10)
        magicLbl.zPosition = 1
        magicBubble.addChild(magicLbl)
        magicLabel = magicLbl

        updateLevelUpBadge()
        updateGameCompleteBadge()
    }

    private func updateHUDCounters() {
        walletLabel?.text = "💰 \(Wallet.shared.balance)냥"
        magicLabel?.text  = "🐾 \(Magic.shared.points)마력"
        updateLevelUpBadge()
        updateGameCompleteBadge()
    }

    // ✨ level-up badge — sits beside the 🐾 bubble rather than literally
    // "between" it and the relic row below (CLAUDE.md's original phrasing):
    // there isn't a clean way to fit a third row there without pushing the
    // relic row further down, which the three-file relicRowTopInset sync
    // above already has to account for once as it is. Built once Magic.points
    // crosses 500 (or immediately, by identity, for Ana — see below) —
    // including mid-run, matching the same live-unlock pattern
    // as the in-dungeon ✨ ability button — and flashes a few times only the
    // very first time it appears (Store.loadLevelUpBadgeFlashed()), then
    // just sits there statically on every later appearance.
    private func updateLevelUpBadge() {
        // Ana arrives already knowing her fairy magic — no level-up gate for
        // her era. Gated on identity, not on her point total (Phase 7b) —
        // see the matching gate in MinigameNode/BossMinigameNode.
        let unlocked = tailorIdentity.id == Tailor.anaID
                    || Magic.shared.points >= MagicLevelUpThreshold.levelOne.rawValue
        guard levelUpBadgeNode == nil, unlocked, let magicBubbleNode else { return }

        let badge = SKShapeNode(circleOfRadius: 15)
        badge.fillColor = UIColor(red: 1.0, green: 0.84, blue: 0.31, alpha: 0.95)
        badge.strokeColor = UIColor(red: 0.55, green: 0.35, blue: 0.10, alpha: 1.0)
        badge.lineWidth = 2
        badge.position = CGPoint(x: magicBubbleNode.position.x + tailorBubbleSize.width / 2 + 8 + 15,
                                 y: magicBubbleNode.position.y - 10)
        badge.zPosition = 20
        addChild(badge)

        let star = SKLabelNode(text: "✨")
        star.fontSize = 16
        star.horizontalAlignmentMode = .center
        star.verticalAlignmentMode = .center
        badge.addChild(star)

        levelUpBadgeNode = badge

        if !Store.loadLevelUpBadgeFlashed() {
            Store.saveLevelUpBadgeFlashed()
            badge.setScale(0.3)
            let popIn = SKAction.sequence([
                .scale(to: 1.3, duration: 0.18),
                .scale(to: 1.0, duration: 0.10)
            ])
            let flash = SKAction.sequence([
                .scale(to: 1.25, duration: 0.18),
                .scale(to: 1.0, duration: 0.18)
            ])
            badge.run(.sequence([popIn, .repeat(flash, count: 3)]))
        }
    }

    // 👑 game-complete badge (Phase 7b, task 8) — the v1 ending has been
    // reached and 마력 accrual is frozen (see Magic.add(_:)'s early return).
    // Sits immediately to the right of the ✨ badge, same y, same size —
    // reuses that badge's visual style/placement approach rather than
    // inventing a second idiom, per the task spec. A separate node (not a
    // second state of the ✨ badge) since ✨ keeps meaning "ability
    // unlocked" independently of whether the game is complete. Not yet
    // reachable from anywhere — Store.saveGameComplete() is set by the
    // Estelle epilogue's outro (task 7, not yet built); this only reads
    // the flag, so it activates automatically once that lands.
    private func updateGameCompleteBadge() {
        guard gameCompleteBadgeNode == nil, Store.loadGameComplete(), let magicBubbleNode else { return }

        let badge = SKShapeNode(circleOfRadius: 15)
        badge.fillColor = UIColor(red: 1.0, green: 0.84, blue: 0.31, alpha: 0.95)
        badge.strokeColor = UIColor(red: 0.55, green: 0.35, blue: 0.10, alpha: 1.0)
        badge.lineWidth = 2
        badge.position = CGPoint(x: magicBubbleNode.position.x + tailorBubbleSize.width / 2 + 8 + 15 + 34,
                                 y: magicBubbleNode.position.y - 10)
        badge.zPosition = 20
        addChild(badge)

        let crown = SKLabelNode(text: "👑")
        crown.fontSize = 16
        crown.horizontalAlignmentMode = .center
        crown.verticalAlignmentMode = .center
        badge.addChild(crown)

        gameCompleteBadgeNode = badge

        if !Store.loadGameCompleteBadgeFlashed() {
            Store.saveGameCompleteBadgeFlashed()
            badge.setScale(0.3)
            let popIn = SKAction.sequence([
                .scale(to: 1.3, duration: 0.18),
                .scale(to: 1.0, duration: 0.10)
            ])
            let flash = SKAction.sequence([
                .scale(to: 1.25, duration: 0.18),
                .scale(to: 1.0, duration: 0.18)
            ])
            badge.run(.sequence([popIn, .repeat(flash, count: 3)]))
        }
    }

    private func setupRelicHUD() {
        let slotSize: CGFloat = 28
        let spacing:  CGFloat = 6
        let leftPad:  CGFloat = 24   // left inset (matches magic bubble's left edge)
        // Relic row sits directly below the tailor bubble — see relicRowTopInset.
        let slotX0 = -size.width  / 2 + leftPad + slotSize / 2
        let slotY  =  size.height / 2 - relicRowTopInset - slotSize / 2
        relicSlots.forEach { $0.removeFromParent() }
        relicSlots = []

        // i=0 → Scepter (leftmost); i=3 → Portrait (rightmost)
        for i in 0..<DungeonItem.allCases.count {
            let centerX = slotX0 + CGFloat(i) * (slotSize + spacing)
            let slot = SKShapeNode(rectOf: CGSize(width: slotSize, height: slotSize), cornerRadius: 6)
            slot.fillColor   = UIColor(red: 0.98, green: 0.95, blue: 0.85, alpha: 0.93)
            slot.strokeColor = UIColor(red: 0.55, green: 0.35, blue: 0.10, alpha: 1.0)
            slot.lineWidth = 2
            slot.position = CGPoint(x: centerX, y: slotY)
            slot.zPosition = 20
            addChild(slot)
            relicSlots.append(slot)
        }
    }

    private func updateRelicHUD() {
        let collected = Store.loadCollectedRelics()
        for (i, relic) in DungeonItem.allCases.enumerated() {
            guard i < relicSlots.count else { continue }
            let slot = relicSlots[i]
            let alreadyFilled = slot.children.contains { $0.name == "relicImage" }
            let shouldBeFilled = collected.contains(relic)

            if shouldBeFilled, !alreadyFilled {
                let img = SKSpriteNode(imageNamed: relic.assetName)
                img.size = CGSize(width: 22, height: 22)
                img.position = .zero
                img.zPosition = 1
                img.name = "relicImage"
                slot.addChild(img)
                slot.setScale(1.0)
                slot.run(.sequence([
                    .scale(to: 1.4, duration: 0.12),
                    .scale(to: 1.0, duration: 0.10)
                ]))
            } else if !shouldBeFilled, alreadyFilled {
                slot.removeAllChildren()
            }
        }
    }

    // Translucent grouped-panel backgrounds behind the tailor/customer HUD
    // clusters (Phase 7 Status HUD redesign). Drawn once, at a lower
    // zPosition than everything they sit behind — the bubbles/relic
    // slots/badge keep their own already-tested absolute positions (see
    // setupHUDCounters/setupRelicHUD/updateLevelUpBadge), this just adds a
    // background sized to bound whatever's already there, computed from
    // their actual node frames rather than re-deriving the layout math.
    private func setupStatusPanels() {
        let panelFill   = UIColor.white.withAlphaComponent(0.10)
        let panelStroke = UIColor.white.withAlphaComponent(0.20)
        let pad: CGFloat = 14

        if let magicBubbleNode {
            var minX = magicBubbleNode.position.x - tailorBubbleSize.width / 2
            var maxX = magicBubbleNode.position.x + tailorBubbleSize.width / 2
            var minY = magicBubbleNode.position.y - tailorBubbleSize.height / 2
            var maxY = magicBubbleNode.position.y + tailorBubbleSize.height / 2

            // Reserve the ✨ badge's space unconditionally, not just when it
            // already exists: Magic.points can cross 500 mid-run (the same
            // live-unlock moment the in-dungeon ✨ ability button handles),
            // and this panel is only drawn once at scene setup — if the
            // badge weren't accounted for up front, it would render outside
            // the panel's already-fixed right edge whenever it pops in later
            // instead of at setup.
            let reservedBadgeX = magicBubbleNode.position.x + tailorBubbleSize.width / 2 + 8 + 15
            maxX = max(maxX, reservedBadgeX + 15)
            // Reserve the 👑 game-complete badge's space too, same
            // reasoning — it sits 34pt further right of the ✨ badge (task 8).
            maxX = max(maxX, reservedBadgeX + 34 + 15)
            for slot in relicSlots {
                minX = min(minX, slot.position.x - 14)
                maxX = max(maxX, slot.position.x + 14)
                minY = min(minY, slot.position.y - 14)
                maxY = max(maxY, slot.position.y + 14)
            }

            let panel = SKShapeNode(rectOf: CGSize(width: maxX - minX + pad * 2,
                                                    height: maxY - minY + pad * 2),
                                    cornerRadius: 20)
            panel.fillColor = panelFill
            panel.strokeColor = panelStroke
            panel.lineWidth = 1.5
            panel.position = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
            panel.zPosition = 15
            addChild(panel)
            tailorPanelNode = panel
        }

        if let walletBubbleNode {
            let panel = SKShapeNode(rectOf: CGSize(width: customerBubbleSize.width + pad * 2,
                                                    height: customerBubbleSize.height + pad * 2),
                                    cornerRadius: 20)
            panel.fillColor = panelFill
            panel.strokeColor = panelStroke
            panel.lineWidth = 1.5
            panel.position = walletBubbleNode.position
            panel.zPosition = 15
            addChild(panel)
            customerPanelNode = panel
        }
    }

    // Owner report after a device playthrough: "it feels weird not to see
    // Daphne's Status HUD change as magic points are accrued and relics are
    // collected" while inside a dungeon. The minigame overlay
    // (MinigameNode/BossMinigameNode, zPosition 50) is a full-screen node
    // added on top of BackRoomScene, so it was drawing over the HUD (15/20)
    // for the entire run — boost the HUD above the minigame's own content
    // (its tallest persistent element sits at effective zPosition 57; see
    // MinigameNode/BossMinigameNode for the max local values) while a
    // dungeon is active, and drop it back down once control returns to the
    // plain back room. Restoring to the original 15/20 (rather than leaving
    // it boosted permanently) matters because the exit-dialog overlay
    // (zPosition 60, only ever shown in the back room, never during a
    // minigame) is meant to darken the ENTIRE screen including the HUD
    // corners — a permanently-boosted HUD would poke out above that dim.
    private func setStatusHUDBoosted(_ boosted: Bool) {
        let panelZ: CGFloat   = boosted ? 58 : 15
        let contentZ: CGFloat = boosted ? 59 : 20
        tailorPanelNode?.zPosition   = panelZ
        customerPanelNode?.zPosition = panelZ
        magicBubbleNode?.zPosition   = contentZ
        walletBubbleNode?.zPosition  = contentZ
        levelUpBadgeNode?.zPosition  = contentZ
        gameCompleteBadgeNode?.zPosition = contentZ
        relicSlots.forEach { $0.zPosition = contentZ }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let minigame = activeMinigame {
            for touch in touches { minigame.handleTouchBegan(touch) }
            return
        }
        if let boss = activeBossMinigame {
            for touch in touches { boss.handleTouchBegan(touch) }
            return
        }

        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        #if DEBUG
        // Temporary dev shortcut: triple-tap the bottom-right corner to cycle
        // the current tailor, so Ana's BackRoomScene presence can be tested
        // before the real Daphne/Aurora/Polaris/Ana handoff scene exists.
        // Bottom-right is clear of the HUD (tailor HUD top-left, customer HUD
        // top-right, quit button center). Remove before shipping — see
        // CLAUDE.md's "Known gaps" debug-shortcut checklist.
        if touch.tapCount >= 3, location.x > size.width * 0.30, location.y < -size.height * 0.30 {
            let ids = Tailor.all.map { $0.id }
            let currentIndex = ids.firstIndex(of: Store.loadCurrentTailor()) ?? 0
            let nextID = ids[(currentIndex + 1) % ids.count]
            Store.saveCurrentTailor(nextID)
            tailor.removeFromParent()
            setupTailor()
            print("DEBUG: switched current tailor to \(nextID)")
            return
        }
        #endif

        // Exit dialog intercepts all taps when visible
        if exitDialogNode != nil {
            handleExitDialogTap(at: location)
            return
        }

        // Quit button
        if let qBtn = quitButton, !qBtn.isHidden,
           qBtn.contains(touch.location(in: self)) {
            showExitDialog()
            return
        }

        if handleInteraction(at: location) {
            return
        }

        handleMovement(at: location)
    }

    private func handleExitDialogTap(at location: CGPoint) {
        guard let order = order else { return }
        for node in nodes(at: location) {
            guard let name = node.name else { continue }
            switch name {
            case "exitRefund":
                exitDialogNode?.removeFromParent()
                exitDialogNode = nil
                // Full deposit refund. 마력 earned this session stays in
                // Magic.shared.points — Magic is monotonic, no rollback needed.
                Wallet.shared.balance += order.depositAmount
                Store.clearActiveOrder()
                returnToFrontShopEmpty()
                return
            case "exitCancel":
                exitDialogNode?.removeFromParent()
                exitDialogNode = nil
                return
            default:
                continue
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let minigame = activeMinigame {
            for touch in touches { minigame.handleTouchEnded(touch) }
        }
        if let boss = activeBossMinigame {
            for touch in touches { boss.handleTouchEnded(touch) }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let minigame = activeMinigame {
            for touch in touches { minigame.handleTouchEnded(touch) }
        }
        if let boss = activeBossMinigame {
            for touch in touches { boss.handleTouchEnded(touch) }
        }
    }

    // MARK: - Keyboard play (forwarded from GameViewController)

    @discardableResult
    func handleKeyDown(_ keyCode: UIKeyboardHIDUsage) -> Bool {
        if let minigame = activeMinigame { return minigame.handleKeyDown(keyCode) }
        if let boss = activeBossMinigame { return boss.handleKeyDown(keyCode) }
        return false
    }

    @discardableResult
    func handleKeyUp(_ keyCode: UIKeyboardHIDUsage) -> Bool {
        if let minigame = activeMinigame { return minigame.handleKeyUp(keyCode) }
        if let boss = activeBossMinigame { return boss.handleKeyUp(keyCode) }
        return false
    }

    override func update(_ currentTime: TimeInterval) {
        activeMinigame?.update(currentTime: currentTime)
        activeBossMinigame?.update(currentTime: currentTime)

        if let halo = tailorHaloNode {
            halo.position = CGPoint(x: tailor.position.x, y: tailor.position.y)
        }
    }
    
    private func handleInteraction(at location: CGPoint) -> Bool {
        let tappedNodes = nodes(at: location)

        for node in tappedNodes {
            guard let nodeName = node.name else { continue }

            switch nodeName {
            case "fabricCabinet":
                guard currentState == .waitingForCabinetTap else { return true }

                setInstructionText("원단 보관장으로 가는 중이에요.")
                currentState = .walkingToCabinet

                moveTailor(to: cabinetInteractionX) { [weak self] in
                    guard let self = self else { return }
                    self.presentMinigame(for: .fabricCabinet)
                }

                return true
                
            case "sewingStation":
                guard currentState == .waitingForSewing else { return true }

                setInstructionText("재봉대로 이동 중이에요.")
                currentState = .walkingToSewing

                moveTailor(to: 120) { [weak self] in
                    guard let self = self else { return }
                    self.presentMinigame(for: .sewingStation)
                }

                return true
                
            case "buttonStation":
                guard currentState == .waitingForButtons else { return true }

                setInstructionText("단추 공간으로 이동 중이에요.")
                currentState = .walkingToButtons

                moveTailor(to: 300) { [weak self] in
                    guard let self = self else { return }
                    self.presentMinigame(for: .buttonStation)
                }

                return true
                
            case "mannequin":
                guard currentState == .waitingForMannequin else { return true }

                setInstructionText("마네킹으로 이동 중이에요.")
                currentState = .walkingToMannequin

                moveTailor(to: 0) { [weak self] in
                    guard let self = self else { return }
                    self.presentBossMinigame()
                }

                return true
                
            default:
                continue
            
            }
        }

        return false
    }

    private func handleMovement(at location: CGPoint) {
        let movableStates: [BackRoomState] = [
            .waitingForCabinetTap,
            .waitingForSewing,
            .waitingForButtons,
            .waitingForMannequin
        ]

        guard movableStates.contains(currentState) else { return }

        if location.x < 0 {
            moveTailor(by: -80)
        } else {
            moveTailor(by: 80)
        }
    }

    private func moveTailor(by amount: CGFloat) {
        let newX = tailor.position.x + amount

        let leftLimit = -self.size.width / 2 + 50
        let rightLimit = self.size.width / 2 - 50

        let clampedX = max(leftLimit, min(rightLimit, newX))

        let move = SKAction.moveTo(x: clampedX, duration: 0.2)
        move.timingMode = .easeOut

        let moveUp = SKAction.moveBy(x: 0, y: 10, duration: 0.1)
        let moveDown = SKAction.moveBy(x: 0, y: -10, duration: 0.1)

        let bounce = SKAction.sequence([moveUp, moveDown])
        let group = SKAction.group([move, bounce])

        if amount < 0 {
            tailor.xScale = abs(tailor.xScale)
        } else {
            tailor.xScale = -abs(tailor.xScale)
        }

        tailor.run(group)
    }

    private func moveTailor(to targetX: CGFloat, completion: (() -> Void)? = nil) {
        let leftLimit = -self.size.width / 2 + 50
        let rightLimit = self.size.width / 2 - 50
        let clampedX = max(leftLimit, min(rightLimit, targetX))

        let distance = abs(tailor.position.x - clampedX)
        let duration = max(0.15, TimeInterval(distance / 300))

        let move = SKAction.moveTo(x: clampedX, duration: duration)
        move.timingMode = .easeOut

        let moveUp = SKAction.moveBy(x: 0, y: 10, duration: 0.1)
        let moveDown = SKAction.moveBy(x: 0, y: -10, duration: 0.1)
        let bounce = SKAction.sequence([moveUp, moveDown])

        let bounceCount = max(1, Int(duration / 0.2))
        let repeatedBounce = SKAction.repeat(bounce, count: bounceCount)

        let group = SKAction.group([move, repeatedBounce])

        if clampedX < tailor.position.x {
            tailor.xScale = abs(tailor.xScale)
        } else {
            tailor.xScale = -abs(tailor.xScale)
        }

        tailor.run(group) {
            completion?()
        }
    }

    // MARK: - Minigame overlay

    private func presentMinigame(for station: MinigameStation) {
        guard let scene = self.scene else { return }

        // Pause back-room tailor while minigame runs
        tailor.isPaused = true
        quitButton?.isHidden = true

        // Back-room touches are intercepted in touchesBegan via the activeMinigame
        // early-return, so no separate touch-shield node is needed.

        let config = MinigameConfig.make(for: station, order: order)
        let minigame = MinigameNode(
            config: config,
            onRelicCollected: { [weak self] _ in
                self?.updateRelicHUD()
            }
        ) { [weak self] completedStation in
            self?.handleMinigameCompletion(for: completedStation)
        }
        minigame.zPosition = 50
        minigame.name = "minigame"
        activeMinigame = minigame
        addChild(minigame)
        minigame.setup(in: scene)
        setStatusHUDBoosted(true)
    }

    private func presentBossMinigame() {
        guard let scene = self.scene else { return }
        tailor.isPaused = true
        quitButton?.isHidden = true

        let boss = BossMinigameNode(
            order: order,
            onRelicCollected: { [weak self] _ in
                self?.updateRelicHUD()
            }
        ) { [weak self] in
            self?.handleBossCompletion()
        }
        boss.zPosition = 50
        boss.name = "bossMinigame"
        activeBossMinigame = boss
        addChild(boss)
        boss.setup(in: scene)
        setStatusHUDBoosted(true)
    }

    private func handleBossCompletion() {
        activeBossMinigame?.removeFromParent()
        activeBossMinigame = nil
        setStatusHUDBoosted(false)
        scene?.physicsWorld.gravity = .zero
        tailor.isPaused = false
        updateQuitButtonVisibility()
        Store.clearActiveOrder()
        currentState = .finalCheck
        setInstructionText(garmentCompletionText(for: order))
        updateHUDCounters()

        // Phase 5 — TailorChoiceScene fires once when all four relics have been
        // collected and the deduction scene hasn't been shown yet.
        let allRelicsCollected = Store.loadCollectedRelics().count == DungeonItem.allCases.count

        if allRelicsCollected && !Store.loadRelicDeductionShown() {
            Store.saveRelicDeductionShown()
            presentTailorChoiceScene()
        } else {
            placeDressOnMannequin()
        }
        // Note: the 300-마력 tailor handoff (TailorHandoffScene) is gated in
        // FrontShopScene.handleSaveTrophy() instead, deliberately AFTER the
        // garment is saved to the wardrobe — not here — so the sequence
        // reads as "Daphne's order is saved, then she leaves" rather than
        // implying Ana finished a dress she never touched.
    }

    private func presentTailorChoiceScene() {
        guard let view = self.view else { return }
        let scene = TailorChoiceScene()
        scene.scaleMode = .resizeFill
        scene.completedOrder = order
        let transition = SKTransition.crossFade(withDuration: 0.6)
        view.presentScene(scene, transition: transition)
    }

    private func handleMinigameCompletion(for station: MinigameStation) {
        // Tear down overlay
        activeMinigame?.removeFromParent()
        activeMinigame = nil
        setStatusHUDBoosted(false)

        // Restore gravity (back room has no physics bodies, so zero is correct)
        scene?.physicsWorld.gravity = .zero

        // Resume tailor
        tailor.isPaused = false

        // Advance back-room state machine
        switch station {
        case .fabricCabinet:
            celebrateTailor()
            showTailorHalo(color: haloLight)
            setInstructionText("잘했어요! 재봉대로 가보세요.")
            currentState = .waitingForSewing
        case .sewingStation:
            setInstructionText("단추를 달아볼까요?")
            updateHaloColor(to: haloMedium)
            currentState = .waitingForButtons
        case .buttonStation:
            setInstructionText("완성된 \(garmentNoun(for: order))를 마네킹에 입혀볼까요?")
            updateHaloColor(to: haloDark)
            currentState = .waitingForMannequin
        }
        // Sparkle "ding" as the next station becomes ready.
        SoundManager.shared.play("sfx_station_unlock.mp3")
        updateQuitButtonVisibility()
        updateHUDCounters()
    }

    private func setupMannequinZone() {
        let zone = SKShapeNode(rectOf: CGSize(width: 120, height: 220), cornerRadius: 12)
        zone.position = CGPoint(x: 0, y: 10)

        zone.fillColor = .clear
        zone.strokeColor = .clear

        zone.name = "mannequin"
        zone.zPosition = 5

        addChild(zone)
    }
    
    private func showTailorHalo(color: UIColor) {
        tailorHaloNode?.removeFromParent()

        let haloSize = haloBaseSize
        let scale = Tailor.haloScale(for: tailorIdentity)
        let halo = SKShapeNode(rectOf: haloSize, cornerRadius: haloSize.width / 2)
        halo.fillColor = color.withAlphaComponent(0.45)
        halo.strokeColor = color.withAlphaComponent(0.85)
        halo.lineWidth = 3 * scale
        halo.glowWidth = 24 * scale
        halo.position = CGPoint(x: tailor.position.x, y: tailor.position.y)
        halo.zPosition = 8
        halo.name = "tailorHalo"

        tailorHaloNode = halo
        addChild(halo)

        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 1.0, duration: 0.65),
            SKAction.fadeAlpha(to: 0.10, duration: 0.65)
        ])
        halo.run(.repeatForever(pulse), withKey: "haloPulse")
    }

    private func updateHaloColor(to color: UIColor) {
        let oldHalo = tailorHaloNode
        tailorHaloNode = nil
        oldHalo?.removeAllActions()
        oldHalo?.run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()]))

        run(.wait(forDuration: 0.15)) { [weak self] in
            self?.showTailorHalo(color: color)
        }
    }

    private func placeDressOnMannequin() {
        celebrateTailor()

        guard let halo = tailorHaloNode else {
            returnToFrontShop()
            return
        }

        tailorHaloNode = nil
        halo.removeAllActions()
        halo.alpha = 1.0

        // Divide by the halo's actual current width (varies per tailor via
        // Tailor.haloScale), not a hardcoded 70 — that assumed Ana's halo
        // size and under-expanded Daphne's smaller halo.
        let targetScale = max(size.width, size.height) * 2.0 / haloBaseSize.width
        let expand = SKAction.scale(to: targetScale, duration: 0.85)
        expand.timingMode = .easeIn

        // Sustained warm bloom as the halo fills the screen.
        SoundManager.shared.play("sfx_halo_expand.mp3")

        halo.run(expand) { [weak self] in
            self?.returnToFrontShop()
        }
    }
    
    private func returnToFrontShop() {
        guard let view = self.view else { return }
        let scene = FrontShopScene(size: self.size)

        scene.scaleMode = .resizeFill
        scene.shouldShowFinishedGarment = true
        scene.finishedGarmentImageName = garmentImageName(for: order)
        scene.completedOrder = order

        let transition = SKTransition.crossFade(withDuration: 0.6)
        view.presentScene(scene, transition: transition)
    }
    
    private func celebrateTailor() {
        let up = SKAction.moveBy(x: 0, y: 12, duration: 0.1)
        let down = SKAction.moveBy(x: 0, y: -12, duration: 0.1)
        tailor.run(SKAction.sequence([up, down]))
    }

    // MARK: - Active order persistence

    private func saveActiveOrderSnapshot() {
        guard currentState != .finalCheck, currentState != .completed else { return }
        guard let order = order else { return }
        // Don't overwrite a cleared record after order completes
        let snapshot = ActiveOrder(
            clothingType: order.clothingType,
            fabricColor: order.fabricColor,
            depositAmount: order.depositAmount,
            backRoomStateName: currentState.rawValue,
            savedAt: Date()
        )
        Store.saveActiveOrder(snapshot)
    }

    private func applyResumeStateIfNeeded() {
        guard let stateName = resumeStateName,
              let saved = BackRoomState(rawValue: stateName) else { return }

        // Map saved state → nearest forward .waitingForX station
        let resumeTarget: BackRoomState
        switch saved {
        case .waitingForCabinetTap, .walkingToCabinet:
            resumeTarget = .waitingForCabinetTap
        case .waitingForSewing, .walkingToSewing:
            resumeTarget = .waitingForSewing
            showTailorHalo(color: haloLight)
            setInstructionText("재봉대로 가보세요.")
        case .waitingForButtons, .walkingToButtons:
            resumeTarget = .waitingForButtons
            showTailorHalo(color: haloMedium)
            setInstructionText("단추를 달아볼까요?")
        case .waitingForMannequin, .walkingToMannequin:
            resumeTarget = .waitingForMannequin
            showTailorHalo(color: haloDark)
            setInstructionText("완성된 \(garmentNoun(for: order))를 마네킹에 입혀볼까요?")
        default:
            resumeTarget = .waitingForCabinetTap
        }

        currentState = resumeTarget
        updateQuitButtonVisibility()
    }

    // MARK: - Quit button

    private func setupQuitButton() {
        // Independent placement (Status HUD redesign) — no longer nested
        // under the customer panel now that the wallet bubble grew to fit
        // the customer name + garment line; sits centered between the two
        // panels instead. NOT at the same height as instructionLabel (0, 150)
        // — an earlier pass put it there and the two collided on-device.
        let button = SKShapeNode(rectOf: CGSize(width: 108, height: 40), cornerRadius: 12)
        button.fillColor = UIColor(red: 0.55, green: 0.20, blue: 0.15, alpha: 0.88)
        button.strokeColor = .clear
        button.position = CGPoint(x: 0, y: 100)
        button.zPosition = 20
        button.name = "quitButton"
        addChild(button)
        quitButton = button

        let label = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        label.text = "그만할래"
        label.fontSize = 18
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.name = "quitButton"
        label.zPosition = 1
        button.addChild(label)
    }

    private func updateQuitButtonVisibility() {
        let visibleStates: [BackRoomState] = [
            .waitingForCabinetTap, .walkingToCabinet,
            .waitingForSewing,     .walkingToSewing,
            .waitingForButtons,    .walkingToButtons,
            .waitingForMannequin,  .walkingToMannequin
        ]
        let minigameActive = (activeMinigame != nil || activeBossMinigame != nil)
        quitButton?.isHidden = minigameActive || !visibleStates.contains(currentState)
    }

    private func showExitDialog() {
        guard let order = order else { return }

        exitDialogNode?.removeFromParent()

        let refundedBalance = Wallet.shared.balance + order.depositAmount

        let overlay = SKNode()
        overlay.zPosition = 60
        overlay.name = "exitDialog"
        addChild(overlay)
        exitDialogNode = overlay

        // Dim background
        let dim = SKShapeNode(rectOf: size)
        dim.fillColor = UIColor(white: 0, alpha: 0.55)
        dim.strokeColor = .clear
        dim.zPosition = -1
        overlay.addChild(dim)

        // Panel
        let panel = SKShapeNode(rectOf: CGSize(width: 320, height: 210), cornerRadius: 24)
        panel.fillColor = UIColor(red: 0.96, green: 0.91, blue: 0.80, alpha: 0.98)
        panel.strokeColor = UIColor.brown
        panel.lineWidth = 4
        panel.zPosition = 1
        overlay.addChild(panel)

        let title = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        title.text = "정말 그만할래요?"
        title.fontSize = 24
        title.fontColor = .black
        title.position = CGPoint(x: 0, y: 70)
        title.verticalAlignmentMode = .center
        panel.addChild(title)

        // Full deposit refund — 마력 earned stays (Magic is monotonic)
        let btnA = makeDialogButton(
            text: "보증금 환불 → 지갑 \(refundedBalance)냥",
            name: "exitRefund",
            position: CGPoint(x: 0, y: 5),
            width: 280
        )
        panel.addChild(btnA)

        // Cancel
        let btnB = makeDialogButton(
            text: "취소",
            name: "exitCancel",
            position: CGPoint(x: 0, y: -65),
            width: 160
        )
        panel.addChild(btnB)
    }

    private func makeDialogButton(text: String, name: String, position: CGPoint, width: CGFloat) -> SKShapeNode {
        let button = SKShapeNode(rectOf: CGSize(width: width, height: 50), cornerRadius: 14)
        button.fillColor = UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 1.0)
        button.strokeColor = UIColor.brown
        button.lineWidth = 2
        button.position = position
        button.name = name

        let label = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        label.text = text
        label.fontSize = 15
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.name = name
        label.zPosition = 1
        button.addChild(label)
        return button
    }

    private func returnToFrontShopEmpty() {
        guard let view = self.view else { return }
        let scene = FrontShopScene(size: self.size)
        scene.scaleMode = .resizeFill
        let transition = SKTransition.crossFade(withDuration: 0.6)
        view.presentScene(scene, transition: transition)
    }
}
