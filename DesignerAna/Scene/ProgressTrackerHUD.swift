//
//  ProgressTrackerHUD.swift
//  DesignerAna
//
//  Always-visible overall game progress tracker (owner request 2026-09-10).
//  Spans both Daphne's and Ana's arcs on one bar, since 마력 already runs
//  continuously 0→3000 across the whole v1 story (Daphne 0→1000 at her
//  handoff, Ana 1000→3000 at the ending gate — one shared, monotonic-ish
//  counter; see Magic.swift and CLAUDE.md's Currency & economy). Tick
//  marks sit at the two MagicLevelUpThreshold fractions, since those ARE
//  the story's milestones (✨ ability unlock, 🤝 the tailor handoff) —
//  exact positions, not estimates. Reaching Magic.endingThreshold (or the
//  gameComplete flag going true) switches the display to a finished state.
//
//  Shared across FrontShopScene, BackRoomScene, MinigameNode, and
//  BossMinigameNode — the core gameplay loop. Deliberately NOT shown in
//  narrative cutscenes (each is its own self-contained story beat, and a
//  persistent progress readout would undercut that) or meta/utility
//  screens (SettingsScene, RiddleScene, DressingRoomScene, StorybookScene,
//  TitleScene) which aren't "gameplay in progress" moments.
//
//  Usage: instantiate, call configure() once, add as a child at the
//  desired position, then call refresh() any time Magic.shared.points or
//  Store.loadGameComplete() may have changed (this project's existing
//  onMagicChanged hook is the natural place).
//

import SpriteKit
import UIKit

final class ProgressTrackerHUD: SKNode {

    private var track: SKShapeNode!
    private var fill: SKShapeNode!
    private var iconLabel: SKLabelNode!
    private var percentLabel: SKLabelNode!
    private var barWidth: CGFloat = 110
    private let barHeight: CGFloat = 8

    // (fraction along the bar, tick color) for each named milestone.
    private var milestoneFractions: [CGFloat] {
        [
            CGFloat(MagicLevelUpThreshold.levelOne.rawValue) / CGFloat(Magic.endingThreshold),
            CGFloat(MagicLevelUpThreshold.levelTwo.rawValue) / CGFloat(Magic.endingThreshold),
        ]
    }

    private let goldFill = UIColor(red: 1.0, green: 0.84, blue: 0.31, alpha: 1.0)
    private let completeFill = UIColor(red: 0.95, green: 0.70, blue: 0.15, alpha: 1.0)

    func configure() {
        let track = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight), cornerRadius: barHeight / 2)
        track.fillColor = UIColor.white.withAlphaComponent(0.22)
        track.strokeColor = UIColor.white.withAlphaComponent(0.45)
        track.lineWidth = 1
        track.zPosition = 0
        addChild(track)
        self.track = track

        let fillNode = SKShapeNode()
        fillNode.fillColor = goldFill
        fillNode.strokeColor = .clear
        fillNode.zPosition = 1
        addChild(fillNode)
        self.fill = fillNode

        for m in milestoneFractions {
            let tick = SKShapeNode(rectOf: CGSize(width: 2, height: barHeight + 4))
            tick.fillColor = UIColor.white.withAlphaComponent(0.75)
            tick.strokeColor = .clear
            tick.position = CGPoint(x: -barWidth / 2 + barWidth * m, y: 0)
            tick.zPosition = 2
            addChild(tick)
        }

        let icon = SKLabelNode(text: "📖")
        icon.fontSize = 13
        icon.verticalAlignmentMode = .center
        icon.horizontalAlignmentMode = .right
        icon.position = CGPoint(x: -barWidth / 2 - 6, y: 1)
        icon.zPosition = 2
        addChild(icon)
        iconLabel = icon

        let percent = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        percent.fontSize = 11
        percent.fontColor = .white
        percent.verticalAlignmentMode = .center
        percent.horizontalAlignmentMode = .left
        percent.position = CGPoint(x: barWidth / 2 + 7, y: 0)
        percent.zPosition = 2
        addChild(percent)
        percentLabel = percent

        refresh()
    }

    func refresh() {
        let complete = Store.loadGameComplete()
        let fraction = Self.overallProgressFraction()
        let w = max(0.01, barWidth * fraction)
        fill.path = CGPath(
            roundedRect: CGRect(x: -barWidth / 2, y: -barHeight / 2, width: w, height: barHeight),
            cornerWidth: barHeight / 2, cornerHeight: barHeight / 2, transform: nil
        )
        fill.fillColor = complete ? completeFill : goldFill
        iconLabel.text = complete ? "👑" : "📖"
        percentLabel.text = complete ? "자유 플레이" : "\(Int((fraction * 100).rounded()))%"
    }

    static func overallProgressFraction() -> CGFloat {
        if Store.loadGameComplete() { return 1.0 }
        let pts = CGFloat(Magic.shared.points)
        return min(1.0, max(0.0, pts / CGFloat(Magic.endingThreshold)))
    }
}
