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

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        setupBackground()
        setupTrophyGrid()
        setupBackButton()
    }

    private func setupBackground() {
        let bg = SKSpriteNode(imageNamed: "Wardrobe_Background")
        bg.position = .zero
        bg.size = self.size
        bg.zPosition = 0
        addChild(bg)
    }

    private func setupTrophyGrid() {
        let garments = Store.loadGarments()

        let cellSize = CGSize(width: 110, height: 150)
        let colSpacing: CGFloat = 130
        let rowSpacing: CGFloat = 170

        // Grid origin: center of the lower half of the scene
        let gridOriginX: CGFloat = 0
        let gridOriginY: CGFloat = -size.height * 0.12

        for (rowIdx, clothing) in clothingTypes.enumerated() {
            for (colIdx, color) in fabricColors.enumerated() {
                let cellX = gridOriginX + (CGFloat(colIdx) - 1) * colSpacing
                let cellY = gridOriginY - CGFloat(rowIdx) * rowSpacing

                let matches = garments.filter { $0.clothingType == clothing && $0.fabricColor == color }

                let cell = buildCell(cellSize: cellSize, clothing: clothing, color: color,
                                     matches: matches, position: CGPoint(x: cellX, y: cellY))
                addChild(cell)
            }
        }
    }

    private func buildCell(cellSize: CGSize, clothing: String, color: String,
                           matches: [FinishedGarment], position: CGPoint) -> SKNode {
        let container = SKNode()
        container.position = position

        if matches.isEmpty {
            // Faint placeholder outline
            let outline = SKShapeNode(rectOf: cellSize, cornerRadius: 14)
            outline.fillColor = .clear
            outline.strokeColor = .white
            outline.lineWidth = 2
            outline.alpha = 0.35
            outline.zPosition = 1
            container.addChild(outline)
        } else {
            // Trophy sprite
            let imageName = garmentImageNameFor(clothing: clothing, color: color)
            let sprite = SKSpriteNode(imageNamed: imageName)
            sprite.size = cellSize
            sprite.alpha = 0.85
            sprite.zPosition = 1
            container.addChild(sprite)

            // Badge for duplicates
            if matches.count > 1 {
                let badgeSize = CGSize(width: 46, height: 28)
                let badge = SKShapeNode(rectOf: badgeSize, cornerRadius: 8)
                badge.fillColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 0.7)
                badge.strokeColor = .clear
                badge.position = CGPoint(x: cellSize.width / 2 - 26, y: -cellSize.height / 2 + 16)
                badge.zPosition = 2

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
        let button = SKShapeNode(rectOf: CGSize(width: 100, height: 44), cornerRadius: 14)
        button.fillColor = UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 1.0)
        button.strokeColor = UIColor.brown
        button.lineWidth = 2
        button.position = CGPoint(x: -size.width / 2 + 70, y: size.height / 2 - 50)
        button.zPosition = 10
        button.name = "backButton"
        addChild(button)

        let label = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        label.text = "← 닫기"
        label.fontSize = 20
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
