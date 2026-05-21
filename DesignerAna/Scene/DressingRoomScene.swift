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
    private let clothingTypes = ["드레스", "셔츠", "바지"]
    private let fabricColors  = ["분홍", "파랑", "노랑"]

    private var safeTop: CGFloat = 0
    private var safeBottom: CGFloat = 0

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

    private func buildCell(cellSize: CGSize, clothing: String, color: String,
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

    private func garmentImageNameFor(clothing: String, color: String) -> String {
        let garmentPart: String
        switch clothing {
        case "셔츠": garmentPart = "Shirt"
        case "바지": garmentPart = "Pants"
        default:     garmentPart = "Dress"
        }
        let colorPart: String
        switch color {
        case "파랑": colorPart = "Blue"
        case "노랑": colorPart = "Yellow"
        default:     colorPart = "Pink"
        }
        return "Mannequin_\(garmentPart)_\(colorPart)"
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

        for node in nodes(at: location) {
            if node.name == "backButton" {
                transitionToFrontShop()
                return
            }
        }
    }

    private func transitionToFrontShop() {
        guard let view = self.view,
              let scene = FrontShopScene(fileNamed: "GameScene") else { return }
        scene.scaleMode = .resizeFill
        let transition = SKTransition.crossFade(withDuration: 0.5)
        view.presentScene(scene, transition: transition)
    }
}
