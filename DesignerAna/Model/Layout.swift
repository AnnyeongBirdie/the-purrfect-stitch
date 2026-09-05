import UIKit

enum Layout {

    /// Evenly-spaced positions for the three front-shop characters.
    /// Customer NPC on the left, shopkeeper at centre, mannequin on the right.
    /// (This slot was a never-wired-up "wardrobe" prop position — repurposed
    /// for the Phase 6b customer NPC since it already mirrors mannequin's
    /// spread on the opposite side, at the same ground level.)
    static func frontShopCharacters(in size: CGSize) -> (customer: CGPoint, shopkeeper: CGPoint, mannequin: CGPoint) {
        // Pulled in from 0.28 — some avatars (e.g. a sword-holding Knight)
        // widen the customer's bounding box enough to overlap the nav icon
        // strip at -0.38*width on narrower screens. Tightening the spread
        // buys clearance at every screen size without touching the nav
        // icons themselves.
        let spread = size.width * 0.20
        let baseY  = -size.height * 0.19
        return (
            customer:   CGPoint(x: -spread,  y: baseY),
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

        // Slender cells — taller than wide — so garment trophies stand upright
        // instead of being stretched sideways to fill a wide cell.
        let rowGap: CGFloat = 18
        let colGap: CGFloat = 48
        let cellH = min(150, (usableHeight - rowGap * CGFloat(rows - 1)) / CGFloat(rows))
        let cellW = cellH * 0.72

        let rowSpacing = cellH + rowGap
        let colSpacing = cellW + colGap

        // Centre the grid on x = 0 and within the usable vertical band.
        let usableMidY = (usableTop + usableBottom) / 2
        let origin = CGPoint(
            x: -colSpacing * CGFloat(cols - 1) / 2,
            y:  usableMidY + rowSpacing * CGFloat(rows - 1) / 2
        )
        return (origin, CGSize(width: cellW, height: cellH), colSpacing, rowSpacing)
    }
}
