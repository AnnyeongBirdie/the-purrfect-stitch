//
//  DressingRoomScene.swift
//  DesignerAna
//
//  Trophy wardrobe — 3×3 grid of completed garments over the dressing-room backdrop.
//

import SpriteKit

class DressingRoomScene: SKScene {

    // Rows = clothing types (top → bottom: dress, shirt, pants)
    // Columns = fabric colors (left → right: pink, blue, yellow)
    // .allCases follows declaration order, which matches that row/column layout.
    private let clothingTypes = ClothingType.allCases
    private let fabricColors  = FabricColor.allCases

    private var safeTop: CGFloat = 0
    private var safeBottom: CGFloat = 0

    private var enlargeOverlay: SKNode?   // non-nil while a trophy is zoomed in

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        safeTop = view.safeAreaInsets.top
        safeBottom = view.safeAreaInsets.bottom
        setupBackground()
        setupTrophyGrid()
        setupBackButton()
    }

    private func setupBackground() {
        // Dark base so the dimmed backdrop reads as muted, letting trophies pop.
        backgroundColor = UIColor(red: 0.10, green: 0.09, blue: 0.14, alpha: 1)
        let bg = SKSpriteNode(imageNamed: "Wardrobe_Background")
        bg.position = .zero
        bg.size = self.size
        bg.zPosition = 0
        bg.alpha = 0.55          // less opaque — the busy backdrop no longer competes
        addChild(bg)
    }

    private func setupTrophyGrid() {
        let garments = Store.loadGarments()

        let g = Layout.trophyGrid(in: size, rows: 3, cols: 3, safeTop: safeTop, safeBottom: safeBottom)

        for (rowIdx, clothing) in clothingTypes.enumerated() {
            for (colIdx, color) in fabricColors.enumerated() {
                let cellX = g.origin.x + CGFloat(colIdx) * g.colSpacing
                let cellY = g.origin.y - CGFloat(rowIdx) * g.rowSpacing

                let matches = garments.filter { $0.clothingType == clothing && $0.fabricColor == color }

                let cell = buildCell(cellSize: g.cellSize, clothing: clothing, color: color,
                                     matches: matches, position: CGPoint(x: cellX, y: cellY))
                addChild(cell)
            }
        }
    }

    private func buildCell(cellSize: CGSize, clothing: ClothingType, color: FabricColor,
                           matches: [FinishedGarment], position: CGPoint) -> SKNode {
        let container = SKNode()
        container.position = position

        // Outline always present — faint for empty slots, brighter for earned ones
        let outline = SKShapeNode(rectOf: cellSize, cornerRadius: 14)
        outline.fillColor = .clear
        outline.strokeColor = .white
        outline.lineWidth = 2
        outline.alpha = matches.isEmpty ? 0.35 : 0.75
        outline.zPosition = 1
        if matches.isEmpty { container.name = "emptyCell" }
        container.addChild(outline)

        if !matches.isEmpty {
            // Trophy sprite on top of outline. Scale to fit the cell while
            // keeping the garment's true proportions (the source images vary in
            // aspect ratio) — no sideways stretching.
            let imageName = garmentImageNameFor(clothing: clothing, color: color)
            let sprite = SKSpriteNode(imageNamed: imageName)
            let native = sprite.size
            let fit = min(cellSize.width / native.width, cellSize.height / native.height)
            sprite.size = CGSize(width: native.width * fit, height: native.height * fit)
            sprite.alpha = 1.0
            sprite.zPosition = 2
            // Name encodes clothing+color so touchesBegan can identify what was
            // tapped. Korean raw values contain no underscores, so the
            // "trophy_<clothing>_<color>" split stays unambiguous.
            let cellName = "trophy_\(clothing.rawValue)_\(color.rawValue)"
            sprite.name = cellName
            container.name = cellName
            container.addChild(sprite)

            // Badge for duplicates
            if matches.count > 1 {
                let badgeSize = CGSize(width: 46, height: 28)
                let badge = SKShapeNode(rectOf: badgeSize, cornerRadius: 8)
                badge.fillColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.7)
                badge.strokeColor = .clear
                badge.position = CGPoint(x: cellSize.width / 2 - 26, y: -cellSize.height / 2 + 16)
                badge.zPosition = 3

                let badgeLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
                badgeLabel.text = "×\(matches.count)"
                badgeLabel.fontSize = 16
                badgeLabel.fontColor = .white
                badgeLabel.alpha = 1.0
                badgeLabel.horizontalAlignmentMode = .center
                badgeLabel.verticalAlignmentMode = .center
                badgeLabel.zPosition = 1
                badge.addChild(badgeLabel)
                container.addChild(badge)
            }
        }

        return container
    }

    private func garmentImageNameFor(clothing: ClothingType, color: FabricColor) -> String {
        "Mannequin_\(clothing.assetFragment)_\(color.assetSuffix)"
    }

    private func setupBackButton() {
        // Nav-icon style — matches the left-edge nav strip in FrontShopScene
        let button = SKShapeNode(rectOf: CGSize(width: 54, height: 54), cornerRadius: 14)
        button.fillColor = UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 0.88)
        button.strokeColor = UIColor(red: 0.55, green: 0.35, blue: 0.10, alpha: 0.6)
        button.lineWidth = 2
        button.position = CGPoint(x: size.width / 2 - 37, y: 0)
        button.zPosition = 10
        button.name = "backButton"
        addChild(button)

        let label = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        label.text = "←"
        label.fontSize = 26
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.name = "backButton"
        label.zPosition = 11
        button.addChild(label)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Any tap dismisses the enlarge overlay.
        if enlargeOverlay != nil {
            dismissEnlarged()
            return
        }

        for node in nodes(at: location) {
            if node.name == "backButton" {
                transitionToFrontShop()
                return
            }
            // Tapped an empty slot?
            if node.name == "emptyCell" {
                showEmptySlotToast()
                return
            }

            // Tapped a filled trophy cell?
            if let name = node.name, name.hasPrefix("trophy_") {
                let parts = name.dropFirst("trophy_".count).split(separator: "_", maxSplits: 1)
                guard parts.count == 2,
                      let clothing = ClothingType(rawValue: String(parts[0])),
                      let color    = FabricColor(rawValue: String(parts[1])) else { continue }
                let garments = Store.loadGarments()
                let count    = garments.filter { $0.clothingType == clothing && $0.fabricColor == color }.count
                showEnlarged(clothing: clothing, color: color, count: count)
                return
            }
        }
    }

    // MARK: - Trophy enlarge overlay

    private func showEnlarged(clothing: ClothingType, color: FabricColor, count: Int) {
        dismissEnlarged()   // safety — shouldn't be open already

        let overlay = SKNode()
        overlay.zPosition = 20
        overlay.name = "enlargeOverlay"
        addChild(overlay)
        enlargeOverlay = overlay

        // Full-screen dim
        let dim = SKShapeNode(rectOf: size)
        dim.fillColor = UIColor(white: 0, alpha: 0.72)
        dim.strokeColor = .clear
        dim.zPosition = 0
        overlay.addChild(dim)

        // Enlarged garment sprite — fit inside 80% of the shorter screen dimension
        let imageName = garmentImageNameFor(clothing: clothing, color: color)
        let sprite = SKSpriteNode(imageNamed: imageName)
        let maxSide = min(size.width, size.height) * 0.80
        let native  = sprite.size
        let fit     = min(maxSide / native.width, maxSide / native.height)
        sprite.size = CGSize(width: native.width * fit, height: native.height * fit)
        sprite.position = CGPoint(x: 0, y: 20)
        sprite.zPosition = 1
        overlay.addChild(sprite)

        // Pop-in animation
        sprite.setScale(0.6)
        sprite.run(.sequence([
            .scale(to: 1.05, duration: 0.18),
            .scale(to: 1.00, duration: 0.08)
        ]))

        // Label: clothing type + color
        let label = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        label.text = "\(color.displayName) \(clothing.displayName)"
        label.fontSize = 26
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -sprite.size.height / 2 - 36)
        label.zPosition = 2
        overlay.addChild(label)

        // Count badge (only if more than one)
        if count > 1 {
            let badgeSize = CGSize(width: 60, height: 34)
            let badge = SKShapeNode(rectOf: badgeSize, cornerRadius: 10)
            badge.fillColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.8)
            badge.strokeColor = .clear
            badge.position = CGPoint(x: sprite.size.width / 2 - 10,
                                     y: sprite.size.height / 2 - 10 + 20)
            badge.zPosition = 3
            let badgeLabel = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
            badgeLabel.text = "×\(count)"
            badgeLabel.fontSize = 20
            badgeLabel.fontColor = .white
            badgeLabel.horizontalAlignmentMode = .center
            badgeLabel.verticalAlignmentMode = .center
            badgeLabel.zPosition = 1
            badge.addChild(badgeLabel)
            overlay.addChild(badge)
        }

        // Hint
        let hint = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        hint.text = "탭하면 닫혀요"
        hint.fontSize = 16
        hint.fontColor = UIColor(white: 1, alpha: 0.45)
        hint.horizontalAlignmentMode = .center
        hint.position = CGPoint(x: 0, y: -size.height / 2 + safeBottom + 30)
        hint.zPosition = 2
        overlay.addChild(hint)
    }

    private func showEmptySlotToast() {
        // Remove any existing toast so rapid taps don't stack.
        childNode(withName: "emptyToast")?.removeFromParent()

        let toast = SKNode()
        toast.name = "emptyToast"
        toast.zPosition = 15
        toast.position = CGPoint(x: 0, y: -size.height * 0.18)
        addChild(toast)

        let pill = SKShapeNode(rectOf: CGSize(width: 310, height: 52), cornerRadius: 26)
        pill.fillColor = UIColor(white: 0.12, alpha: 0.88)
        pill.strokeColor = .clear
        toast.addChild(pill)

        let label = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        label.text = "아직 없어요! 옷을 만들어봐요 👗"
        label.fontSize = 20
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 1
        toast.addChild(label)

        toast.alpha = 0
        toast.run(.sequence([
            .fadeIn(withDuration: 0.2),
            .wait(forDuration: 1.6),
            .fadeOut(withDuration: 0.3),
            .removeFromParent()
        ]))
    }

    private func dismissEnlarged() {
        enlargeOverlay?.run(.sequence([
            .fadeOut(withDuration: 0.15),
            .removeFromParent()
        ]))
        enlargeOverlay = nil
    }

    private func transitionToFrontShop() {
        guard let view = self.view,
              let scene = FrontShopScene(fileNamed: "GameScene") else { return }
        scene.scaleMode = .resizeFill
        scene.suppressEntryBell = true
        let transition = SKTransition.crossFade(withDuration: 0.5)
        view.presentScene(scene, transition: transition)
    }
}
