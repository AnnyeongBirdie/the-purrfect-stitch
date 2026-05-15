import UIKit

enum Layout {

    /// Evenly-spaced positions for the three front-shop characters.
    /// Wardrobe on the left, shopkeeper at centre, mannequin on the right.
    static func frontShopCharacters(in size: CGSize) -> (wardrobe: CGPoint, shopkeeper: CGPoint, mannequin: CGPoint) {
        let spread = size.width * 0.28
        let baseY  = -size.height * 0.19
        return (
            wardrobe:   CGPoint(x: -spread,  y: baseY + size.height * 0.04),
            shopkeeper: CGPoint(x: 0,         y: baseY),
            mannequin:  CGPoint(x: +spread,   y: baseY)
        )
    }

    /// Frame for the relaunch / order-continuation dialog panel.
    /// Panel top sits `gap` below `speechBubbleBottomY`;
    /// panel bottom never intrudes into the bottom safe-area.
    static func relaunchDialogFrame(
        in size: CGSize,
        below speechBubbleBottomY: CGFloat,
        safeBottom: CGFloat,
        gap: CGFloat = 16
    ) -> (center: CGPoint, size: CGSize) {
        let panelTop    = speechBubbleBottomY - gap
        let panelBottom = -size.height / 2 + safeBottom + 16
        let height      = min(280, panelTop - panelBottom)
        let width       = size.width * 0.82
        let centerY     = (panelTop + panelBottom) / 2
        return (CGPoint(x: 0, y: centerY), CGSize(width: width, height: max(height, 160)))
    }

    /// Geometry for the dressing-room trophy grid.
    /// Centred vertically inside the safe rect, below a back-button band at the top.
    static func trophyGrid(
        in size: CGSize,
        rows: Int,
        cols: Int,
        safeTop: CGFloat,
        safeBottom: CGFloat,
        backButtonBand: CGFloat = 60
    ) -> (origin: CGPoint, cellSize: CGSize, colSpacing: CGFloat, rowSpacing: CGFloat) {
        let usableTop    =  size.height / 2 - safeTop    - backButtonBand
        let usableBottom = -size.height / 2 + safeBottom + 16
        let usableHeight = usableTop - usableBottom
        let usableWidth  = size.width * 0.82

        let cellH       = min(150, (usableHeight - CGFloat(rows  - 1) * 20) / CGFloat(rows))
        let cellW       = min(120, (usableWidth  - CGFloat(cols  - 1) * 16) / CGFloat(cols))
        let rowSpacing  = (usableHeight - cellH) / CGFloat(rows  - 1)
        let colSpacing  = (usableWidth  - cellW) / CGFloat(cols  - 1)

        // origin = centre of the top-left cell
        let origin = CGPoint(
            x: -usableWidth  / 2 + cellW / 2,
            y:  usableTop         - cellH / 2
        )
        return (origin, CGSize(width: cellW, height: cellH), colSpacing, rowSpacing)
    }
}
