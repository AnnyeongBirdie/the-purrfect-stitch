//
//  StorybookScene.swift
//  DesignerAna
//
//  The 📖 storybook scene — accessed from the nav strip in FrontShopScene.
//  Shows a table of contents followed by five readable chapters: the kingdom,
//  the royal family, the economy, the workshop & its dungeon relics, and the
//  cast of characters featured in the game.
//

import SpriteKit

class StorybookScene: SKScene {

    // ── Data model ────────────────────────────────────────────────────────────

    private struct Page {
        /// PNG asset to load as a sprite illustration on the left page. Nil = use emoji.
        let illustrationAsset: String?
        /// Emoji shown when no sprite asset is available.
        let illustrationEmoji: String?
        let pageTitle: String
        let pageBody:  String
        /// Per-page multiplier applied on top of the shared illustration scale.
        /// 1.0 = default size; >1 enlarges, <1 shrinks. Defaults to 1.0.
        var illustrationScale: CGFloat = 1.0
    }

    private struct Chapter {
        let title:    String
        let tocEmoji: String
        let pages:    [Page]
    }

    // ── Content ───────────────────────────────────────────────────────────────

    private let chapters: [Chapter] = {
        return [

            // ── 1. World Introduction (merged: world + creator lore) ──────
            Chapter(
                title:    "왕국 소개",
                tocEmoji: "🏰",
                pages: [
                    Page(
                        illustrationAsset: nil,
                        illustrationEmoji: "🏰",
                        pageTitle: "먼지 왕국에 오신 걸 환영해요!",
                        pageBody:
                            "옛날 옛적, 먼지 왕국이라는 아주 특별한 곳이 있었어요.\n\n" +
                            "이 왕국에는 마법사도 있고, 재봉사도 있고, " +
                            "커다란 먼지 몬스터도 살고 있답니다.\n\n" +
                            "나쁜 몬스터는 아니에요. 사실 그들에게는 " +
                            "아직 아무도 모르는 비밀이 있거든요.\n\n" +
                            "이 왕국의 이야기를 함께 떠나볼까요? 📖"
                    ),
                    Page(
                        illustrationAsset: nil,
                        illustrationEmoji: "💻",
                        pageTitle: "신비한 창조자, 개발자",
                        pageBody:
                            "먼지 왕국을 만든 분은 아주 신비한 존재예요. " +
                            "사람들은 그분을 '개발자'라고 불러요.\n\n" +
                            "아주 먼 옛날엔 누구나 아는 직업이었지만, 이제는 " +
                            "그게 무슨 일인지 아무도 모른답니다. 전설에 따르면 " +
                            "개발자는 반은 사람 엄마, 반은 인공지능(AI)이었대요.\n\n" +
                            "개발자에겐 신기한 규칙이 있었어요. 버그(작은 벌레)를 " +
                            "하나 잡을 때마다 새 버그 두 마리가 생겨났대요! " +
                            "그래서 왕국엔 지금도 가끔 이상한 일이 벌어진답니다. 🐛✨"
                    ),
                    Page(
                        illustrationAsset: nil,
                        illustrationEmoji: "🗺",
                        pageTitle: "왕국의 모습",
                        pageBody:
                            "왕국에는 커다란 성과 작은 마을들이 있어요.\n\n" +
                            "마법사의 탑, 재봉사 가게, 시장이 있는 광장...\n\n" +
                            "모두 개발자가 하나하나 정성껏 코드로 지어낸 곳들이래요.\n\n" +
                            "언젠가 왕국 지도 전체를 볼 수 있게 될 거예요! ✨"
                    )
                ]
            ),

            // ── 2. The Royal Family ───────────────────────────────────────
            Chapter(
                title:    "왕실 가족",
                tocEmoji: "👑",
                pages: [
                    // King
                    Page(
                        illustrationAsset: "KingCat",
                        illustrationEmoji: nil,
                        pageTitle: "고양이 임금님",
                        pageBody:
                            "먼지 왕국을 다스리는 마음 따뜻한 임금님이에요.\n\n" +
                            "손에는 황금 도끼를 들고 있지만, 한 번도 누군가와 " +
                            "싸운 적이 없답니다. 사실은 아주 다정한 분이거든요.\n\n" +
                            "왕국과 백성들을 무척 사랑해요. 던전의 먼지 몬스터들도 " +
                            "미워하지 않고, 분명 무슨 사연이 있을 거라 믿고 있답니다.\n\n" +
                            "언젠가 임금님이 그 비밀을 풀어줄까요? 👑"
                    ),
                    // Queen
                    Page(
                        illustrationAsset: "QueenCat",
                        illustrationEmoji: nil,
                        pageTitle: "지혜로운 왕비님",
                        pageBody:
                            "백성을 사랑으로 다스리는 지혜로운 왕비님이에요.\n\n" +
                            "왕국의 오래된 이야기를 누구보다 많이 알고 있어요. " +
                            "손에 든 보석 지팡이는 왕국에서 가장 오래된 보물이랍니다.\n\n" +
                            "왕비님은 가끔 이렇게 속삭여요. " +
                            "\"먼지 몬스터들도... 옛날엔 다른 모습이었단다.\"\n\n" +
                            "왕비님이 아는 비밀은 과연 무엇일까요? 🤫"
                    ),
                    // First Princess — Estelle
                    Page(
                        illustrationAsset: "FirstPrincessCat",
                        illustrationEmoji: nil,
                        pageTitle: "첫째 공주, 에스텔",
                        pageBody:
                            "왕국의 첫째 공주, 에스텔이에요. 보랏빛 눈동자와 " +
                            "풍성한 곱슬털을 가졌답니다.\n\n" +
                            "그림 그리는 걸 무척 좋아해서, 늘 필요한 것보다 훨씬 " +
                            "많은 미술 도구를 들고 다닌답니다. 🎨\n\n" +
                            "조용하지만 무척 용감해요. 어느 날 에스텔은 털실 몬스터와 " +
                            "먼지 몬스터의 숨겨진 비밀을 풀기 위해 홀로 길을 떠났어요.\n\n" +
                            "에스텔의 용감한 모험은 또 다른 이야기에서 펼쳐질 거예요. 📖"
                    ),
                    // Second Princess — Anastasia ("Ana")
                    Page(
                        illustrationAsset: "SecondPrincessCat",
                        illustrationEmoji: nil,
                        pageTitle: "둘째 공주, 아나스타샤",
                        pageBody:
                            "왕국의 둘째 공주, 아나스타샤예요. 다들 다정하게 " +
                            "'아나'라고 부른답니다.\n\n" +
                            "씩씩하고 호기심 많은 샴고양이 공주님이죠. 예쁜 " +
                            "드레스를 좋아해서 재봉사 가게에 자주 놀러 온대요.\n\n" +
                            "언니 에스텔이 모험을 떠난 뒤로, 아나는 온갖 사고를 " +
                            "치며 왕국을 들썩이게 한답니다.\n\n" +
                            "\"언니, 나도 가만히 있을 순 없어!\" " +
                            "아나의 이야기는 이제 막 시작되었어요. ✨"
                    )
                ]
            ),

            // ── 3. Kingdom Economy ────────────────────────────────────────
            Chapter(
                title:    "왕국의 경제",
                tocEmoji: "💰",
                pages: [
                    Page(
                        illustrationAsset: "NyangCoin",
                        illustrationEmoji: nil,
                        pageTitle: "냥이란?",
                        pageBody:
                            "이 왕국에서는 '냥'이라는 특별한 돈을 써요.\n\n" +
                            "냥은 고양이 발바닥 모양의 동전이랍니다! 🐾\n\n" +
                            "열심히 일하거나 퀴즈를 풀면 냥을 더 벌 수 있어요."
                    ),
                    Page(
                        illustrationAsset: nil,
                        illustrationEmoji: "🏆",
                        pageTitle: "냥을 쓰는 방법",
                        pageBody:
                            "냥은 재봉사 가게에서 옷을 주문할 때 써요.\n\n" +
                            "드레스 50냥 · 바지 40냥 · 셔츠 30냥\n\n" +
                            "지갑 💰 아이콘을 누르면 퀴즈를 풀어서 냥을 벌 수 있어요. " +
                            "정답 하나당 +15냥!\n\n" +
                            "던전 보물 상자에서도 냥이 나온답니다! 🪙"
                    )
                ]
            ),

            // ── 4. The Workshop, Its Dungeons & Their Relics ──────────────
            Chapter(
                title:    "신기한 옷공방과 던전",
                tocEmoji: "🧵",
                pages: [
                    Page(
                        illustrationAsset: nil,
                        illustrationEmoji: "🏪",
                        pageTitle: "재봉사 가게",
                        pageBody:
                            "왕국 한복판에 자리 잡은 재봉사 가게에 오신 걸 환영해요!\n\n" +
                            "이 가게는 겉에서 보면 평범해 보이지만, " +
                            "뒤쪽 작업실로 들어가면 놀라운 일이 기다리고 있어요.\n\n" +
                            "멋진 옷을 만들기 위해서는 용감한 재봉사가 필요하답니다!"
                    ),
                    Page(
                        illustrationAsset: nil,
                        illustrationEmoji: "🗝",
                        pageTitle: "신비한 던전",
                        pageBody:
                            "작업실 지하에는 신비한 던전이 있어요!\n\n" +
                            "원단 창고, 재봉틀 방, 단추 방, " +
                            "그리고 마네킹 방까지...\n\n" +
                            "각 방마다 먼지 몬스터들이 살고 있답니다.\n\n" +
                            "무서워 보이지만, 그들에게는 아직 " +
                            "아무도 모르는 비밀이 있어요. 과연 그 비밀은? 🤫"
                    ),
                    // Relic — purple jeweled scepter (fabric cabinet minigame)
                    Page(
                        illustrationAsset: "PurpleScepter",
                        illustrationEmoji: nil,
                        pageTitle: "보랏빛 보석 지팡이",
                        pageBody:
                            "던전 곳곳에는 오래전 잃어버린 신기한 보물들이 " +
                            "숨어 있어요.\n\n" +
                            "그중 하나는 왕비님의 빨간 보석 지팡이와 꼭 닮은 " +
                            "보랏빛 지팡이예요.\n\n" +
                            "원단 창고 미니게임을 깨면, 이 신비한 지팡이를 " +
                            "손에 넣을 수 있답니다! 🔮"
                    ),
                    // Relic — Estelle's paint brushes (sewing machine minigame)
                    Page(
                        illustrationAsset: "PaintBrush",
                        illustrationEmoji: nil,
                        pageTitle: "에스텔의 그림 붓",
                        pageBody:
                            "첫째 공주 에스텔이 무척 아끼던 그림 붓들이에요.\n\n" +
                            "모험을 떠나며 던전 어딘가에 두고 갔대요.\n\n" +
                            "재봉틀 미니게임을 깨면, 이 붓들을 되찾을 수 있어요! 🖌"
                    ),
                    // Relic — Estelle's palette (buttons minigame)
                    Page(
                        illustrationAsset: "Palette",
                        illustrationEmoji: nil,
                        pageTitle: "에스텔의 팔레트",
                        pageBody:
                            "에스텔이 가장 좋아하던 그림 팔레트예요.\n\n" +
                            "알록달록한 물감이 가득 묻어 있답니다.\n\n" +
                            "단추 미니게임을 깨면, 이 팔레트를 찾을 수 있어요! 🎨"
                    ),
                    // Relic — royal family portrait (boss dungeon minigame)
                    Page(
                        illustrationAsset: "RoyalFamilyPortrait",
                        illustrationEmoji: nil,
                        pageTitle: "왕실 가족 초상화",
                        pageBody:
                            "왕실 가족 모두가 함께 그려진 소중한 초상화예요.\n\n" +
                            "던전 가장 깊은 곳에서, 먼지 대장이 보물 상자 위에 " +
                            "앉아 지키고 있어요.\n\n" +
                            "보스 던전 미니게임을 깨면, 이 초상화를 되찾을 수 " +
                            "있답니다! 🖼"
                    )
                ]
            ),

            // ── 5. Character Profiles (cast featured in the game) ─────────
            Chapter(
                title:    "등장인물 소개",
                tocEmoji: "👥",
                pages: [
                    // Shopkeeper
                    Page(
                        illustrationAsset: "Shopkeeper",
                        illustrationEmoji: nil,
                        pageTitle: "가게 주인",
                        pageBody:
                            "재봉사 가게의 주인이에요.\n\n" +
                            "항상 미소를 잃지 않는 다정한 분이죠. 수수께끼와 퀴즈 " +
                            "내는 걸 무척 좋아해서, 손님에게 종종 깜짝 문제를 " +
                            "내곤 한답니다. 🧩\n\n" +
                            "오랫동안 던전 몬스터 때문에 골치가 아팠던 가게 주인은, " +
                            "마법사의 조수를 작업실 관리자로 채용했어요.\n\n" +
                            "\"던전 정리만 해주면 뭐든 해드릴게요!\" 🤝"
                    ),
                    // Tailor
                    Page(
                        illustrationAsset: "Tailor",
                        illustrationEmoji: nil,
                        pageTitle: "재봉사",
                        pageBody:
                            "원래는 위대한 마법사의 조수였어요.\n\n" +
                            "하지만 지각을 너무 자주 해서 결국 벌을 받고 " +
                            "이 재봉사 가게로 보내졌답니다.\n\n" +
                            "요술 바늘 하나면 어떤 옷이든 뚝딱! " +
                            "던전 몬스터도 마법으로 거뜬히 상대해요. ✨"
                    ),
                    // Monster — a tangled ball of string & yarn (not dust)
                    Page(
                        illustrationAsset: "Monster",
                        illustrationEmoji: nil,
                        pageTitle: "엉킨 실 몬스터",
                        pageBody:
                            "던전에 사는 작은 몬스터예요.\n\n" +
                            "사실은 먼지가 아니라, 엉키고 엉킨 실과 " +
                            "털실 뭉치랍니다!\n\n" +
                            "처음엔 무섭게 보이지만 무척 수줍음을 타요. " +
                            "이 몬스터에게도 아직 아무도 모르는 비밀이 숨어 있어요.\n\n" +
                            "그 비밀은 다음 이야기에서 밝혀질 거예요. 🧶"
                    ),
                    // Boss — drawn slightly larger than the other monsters
                    Page(
                        illustrationAsset: "Boss",
                        illustrationEmoji: nil,
                        pageTitle: "먼지 대장",
                        pageBody:
                            "던전 깊은 곳을 지키는 커다란 먼지 몬스터예요.\n\n" +
                            "작은 몬스터들의 대장으로, 무려 3번의 공격을 " +
                            "버틸 수 있는 강인한 존재랍니다.\n\n" +
                            "보물 상자 위에 앉아 무언가를 지키고 있어요. " +
                            "과연 상자 안에는 무엇이 있을까요? 📦",
                        illustrationScale: 1.12
                    ),
                    // Minions (BossAdd) — drawn smaller than the 엉킨 실 몬스터
                    Page(
                        illustrationAsset: "BossAdd",
                        illustrationEmoji: nil,
                        pageTitle: "먼지 꼬마들",
                        pageBody:
                            "먼지 대장이 위기에 처하면 나타나는 " +
                            "작은 친구들이에요!\n\n" +
                            "혼자서는 별로 강하지 않지만, " +
                            "여럿이 모이면 꽤 당황스럽답니다.\n\n" +
                            "대장을 무척 따르는 것 같아요. 어쩌면 이 꼬마들이 " +
                            "먼지 몬스터의 비밀을 알고 있을지도 몰라요... 💫",
                        illustrationScale: 0.45
                    )
                ]
            )
        ]
    }()

    // ── State ─────────────────────────────────────────────────────────────────

    /// -1 = table of contents is showing
    private var currentChapterIndex: Int = -1
    private var currentPageIndex:    Int =  0

    // ── Nodes ─────────────────────────────────────────────────────────────────

    private var pageContentNode: SKNode?

    // ── Colour palette ────────────────────────────────────────────────────────

    private let parchment  = UIColor(red: 0.96, green: 0.91, blue: 0.80, alpha: 0.98)
    private let brownDark  = UIColor(red: 0.35, green: 0.18, blue: 0.02, alpha: 1.0)
    private let brownMid   = UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 1.0)
    private let brownLight = UIColor(red: 0.55, green: 0.35, blue: 0.10, alpha: 0.60)
    private let brownFaded = UIColor(red: 0.78, green: 0.52, blue: 0.33, alpha: 0.28)

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        // Warm tan background — frames the open book
        backgroundColor = UIColor(red: 0.86, green: 0.78, blue: 0.60, alpha: 1.0)
        drawBookFrame()
        showTableOfContents()
    }

    // MARK: - Book frame (persistent decoration) ──────────────────────────────

    private func drawBookFrame() {
        let bookW = size.width  * 0.93
        let bookH = size.height * 0.88

        // Parchment pages
        let frame = SKShapeNode(rectOf: CGSize(width: bookW, height: bookH), cornerRadius: 14)
        frame.fillColor   = parchment
        frame.strokeColor = brownLight
        frame.lineWidth   = 5
        frame.position    = .zero
        frame.zPosition   = 1
        frame.name        = "bookFrame"
        addChild(frame)

        // Spine divider — hidden in ToC mode, shown in chapter mode
        let spinePath = CGMutablePath()
        let spineH = bookH * 0.88
        spinePath.move(to:    CGPoint(x: 0, y:  spineH / 2))
        spinePath.addLine(to: CGPoint(x: 0, y: -spineH / 2))
        let spine = SKShapeNode(path: spinePath)
        spine.strokeColor = UIColor(red: 0.55, green: 0.35, blue: 0.10, alpha: 0.30)
        spine.lineWidth   = 2
        spine.zPosition   = 2
        spine.name        = "spineDivider"
        spine.isHidden    = true
        addChild(spine)
    }

    // MARK: - Table of Contents ────────────────────────────────────────────────

    private func showTableOfContents() {
        currentChapterIndex = -1
        currentPageIndex    =  0
        clearPageContent()
        childNode(withName: "spineDivider")?.isHidden = true

        let content = SKNode()
        content.zPosition = 5
        content.name      = "pageContent"
        addChild(content)
        pageContentNode = content

        // Title
        let titleLbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        titleLbl.text                    = "📖 이야기의 세계로"
        titleLbl.fontSize                = 26
        titleLbl.fontColor               = brownDark
        titleLbl.horizontalAlignmentMode = .center
        titleLbl.verticalAlignmentMode   = .center
        titleLbl.position = CGPoint(x: 0, y: size.height * 0.33)
        content.addChild(titleLbl)

        // Chapter buttons — spread evenly in the middle of the book
        let btnW: CGFloat = min(size.width * 0.56, 360)
        let btnH: CGFloat = 40
        let gap:  CGFloat = 48
        // Centre the column: first button top, last button bottom
        let colH   = btnH + CGFloat(chapters.count - 1) * gap
        let startY = colH / 2 - btnH / 2 - 10   // slight downward nudge from centre

        for (i, ch) in chapters.enumerated() {
            let btn = SKShapeNode(rectOf: CGSize(width: btnW, height: btnH), cornerRadius: 12)
            btn.fillColor   = brownMid
            btn.strokeColor = brownLight
            btn.lineWidth   = 2
            btn.position    = CGPoint(x: 0, y: startY - CGFloat(i) * gap)
            btn.zPosition   = 3
            btn.name        = "chapterBtn_\(i)"
            content.addChild(btn)

            let lbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
            lbl.text                    = "\(ch.tocEmoji)  \(i + 1). \(ch.title)"
            lbl.fontSize                = 19
            lbl.fontColor               = .white
            lbl.horizontalAlignmentMode = .center
            lbl.verticalAlignmentMode   = .center
            lbl.name = "chapterBtn_\(i)"
            btn.addChild(lbl)
        }

        // Back-to-shop button (top-left of book)
        addPillButton(to: content,
                      name: "backToShopBtn", label: "← 가게",
                      x: -size.width * 0.38, y: size.height * 0.36)

        content.alpha = 0
        content.run(.fadeIn(withDuration: 0.25))
    }

    // MARK: - Chapter Page ─────────────────────────────────────────────────────

    private func showChapterPage(chapterIndex: Int, pageIndex: Int) {
        guard chapterIndex >= 0, chapterIndex < chapters.count else { return }
        let chapter = chapters[chapterIndex]
        guard pageIndex >= 0, pageIndex < chapter.pages.count else { return }
        let page = chapter.pages[pageIndex]

        currentChapterIndex = chapterIndex
        currentPageIndex    = pageIndex
        clearPageContent()
        childNode(withName: "spineDivider")?.isHidden = false

        let content = SKNode()
        content.zPosition = 5
        content.name      = "pageContent"
        addChild(content)
        pageContentNode = content

        // ── Left page: illustration ───────────────────────────────────────

        let leftCX       = -size.width * 0.225
        let illuTargetH  = size.height * 0.60

        if let assetName = page.illustrationAsset {
            let sprite = SKSpriteNode(imageNamed: assetName)
            let nativeH = sprite.texture?.size().height ?? 100
            let scale   = nativeH > 0 ? illuTargetH / nativeH : 1.0
            sprite.setScale(scale * page.illustrationScale)
            sprite.position  = CGPoint(x: leftCX, y: 0)
            sprite.zPosition = 3
            content.addChild(sprite)
        } else if let emoji = page.illustrationEmoji {
            let emojiLbl = SKLabelNode(text: emoji)
            emojiLbl.fontSize                = size.height * 0.36
            emojiLbl.verticalAlignmentMode   = .center
            emojiLbl.horizontalAlignmentMode = .center
            emojiLbl.position  = CGPoint(x: leftCX, y: 0)
            emojiLbl.zPosition = 3
            content.addChild(emojiLbl)
        }

        // ── Right page: text ──────────────────────────────────────────────

        // rightX is the left edge of the text column, measured from scene centre
        let rightX      = size.width * 0.038
        let rightWidth  = size.width * 0.41   // column width for word-wrap

        // Tiny chapter tag
        let tagLbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        tagLbl.text                    = "제 \(chapterIndex + 1)장  ·  \(chapter.title)"
        tagLbl.fontSize                = 12
        tagLbl.fontColor               = UIColor(red: 0.55, green: 0.35, blue: 0.10, alpha: 0.60)
        tagLbl.horizontalAlignmentMode = .left
        tagLbl.verticalAlignmentMode   = .top
        tagLbl.position  = CGPoint(x: rightX, y: size.height * 0.34)
        tagLbl.zPosition = 3
        content.addChild(tagLbl)

        // Page title
        let titleLbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Bold")
        titleLbl.text                  = page.pageTitle
        titleLbl.fontSize              = 19
        titleLbl.fontColor             = brownDark
        titleLbl.horizontalAlignmentMode = .left
        titleLbl.verticalAlignmentMode   = .top
        titleLbl.numberOfLines           = 2
        titleLbl.preferredMaxLayoutWidth = rightWidth
        titleLbl.position  = CGPoint(x: rightX, y: size.height * 0.30)
        titleLbl.zPosition = 3
        content.addChild(titleLbl)

        // Body text
        let bodyLbl = SKLabelNode(fontNamed: "AppleSDGothicNeo-Regular")
        bodyLbl.text                   = page.pageBody
        bodyLbl.fontSize               = 15
        bodyLbl.fontColor              = UIColor(red: 0.20, green: 0.10, blue: 0.00, alpha: 1.0)
        bodyLbl.horizontalAlignmentMode  = .left
        bodyLbl.verticalAlignmentMode    = .top
        bodyLbl.numberOfLines            = 0
        bodyLbl.preferredMaxLayoutWidth  = rightWidth
        bodyLbl.lineBreakMode            = .byWordWrapping
        bodyLbl.position  = CGPoint(x: rightX, y: size.height * 0.235)
        bodyLbl.zPosition = 3
        content.addChild(bodyLbl)

        // ── Navigation controls ────────────────────────────────────────────
        buildNavControls(chapter: chapter,
                         chapterIndex: chapterIndex,
                         pageIndex: pageIndex,
                         in: content)

        content.alpha = 0
        content.run(.fadeIn(withDuration: 0.20))
    }

    // MARK: - Navigation controls ──────────────────────────────────────────────

    private func buildNavControls(chapter: Chapter,
                                  chapterIndex: Int,
                                  pageIndex: Int,
                                  in node: SKNode) {
        let navY = -size.height * 0.386

        // ← Back to ToC (top-left of book)
        addPillButton(to: node,
                      name: "toTocBtn", label: "← 목차",
                      x: -size.width * 0.38, y: size.height * 0.36)

        // ◀ Prev page
        let hasPrev = pageIndex > 0
        let prevBtn = arrowButton(text: "◀",
                                  name: hasPrev ? "prevPageBtn" : "noopPrev",
                                  active: hasPrev)
        prevBtn.position = CGPoint(x: -size.width * 0.27, y: navY)
        node.addChild(prevBtn)

        // Page dots (only shown when chapter has > 1 page)
        let total = chapter.pages.count
        if total > 1 {
            let dotSpacing: CGFloat = 16
            let totalW = CGFloat(total - 1) * dotSpacing
            for i in 0..<total {
                let dot = SKShapeNode(circleOfRadius: 5)
                dot.fillColor   = i == pageIndex ? brownMid : brownFaded
                dot.strokeColor = .clear
                dot.zPosition   = 10
                dot.position    = CGPoint(x: -totalW / 2 + CGFloat(i) * dotSpacing,
                                          y: navY)
                node.addChild(dot)
            }
        }

        // ▶ Next page
        let hasNext = pageIndex < chapter.pages.count - 1
        let nextBtn = arrowButton(text: "▶",
                                  name: hasNext ? "nextPageBtn" : "noopNext",
                                  active: hasNext)
        nextBtn.position = CGPoint(x: size.width * 0.27, y: navY)
        node.addChild(nextBtn)
    }

    // MARK: - Button helpers ───────────────────────────────────────────────────

    /// Small pill-shaped button (used for "← 가게" and "← 목차").
    private func addPillButton(to node: SKNode,
                               name: String, label: String,
                               x: CGFloat, y: CGFloat) {
        let btn = SKShapeNode(rectOf: CGSize(width: 84, height: 36), cornerRadius: 10)
        btn.fillColor   = brownMid
        btn.strokeColor = brownLight
        btn.lineWidth   = 2
        btn.position    = CGPoint(x: x, y: y)
        btn.zPosition   = 10
        btn.name        = name
        node.addChild(btn)

        let lbl = SKLabelNode(text: label)
        lbl.fontSize                = 14
        lbl.fontColor               = .white
        lbl.verticalAlignmentMode   = .center
        lbl.horizontalAlignmentMode = .center
        lbl.name = name
        btn.addChild(lbl)
    }

    /// ◀ / ▶ arrow button for page navigation.
    private func arrowButton(text: String,
                             name: String,
                             active: Bool) -> SKShapeNode {
        let btn = SKShapeNode(rectOf: CGSize(width: 52, height: 42), cornerRadius: 10)
        btn.fillColor   = active ? brownMid : brownFaded
        btn.strokeColor = .clear
        btn.zPosition   = 10
        btn.name        = name

        let lbl = SKLabelNode(text: text)
        lbl.fontSize                = 20
        lbl.fontColor               = active ? .white
                                             : UIColor(white: 1, alpha: 0.45)
        lbl.verticalAlignmentMode   = .center
        lbl.horizontalAlignmentMode = .center
        lbl.name = name
        btn.addChild(lbl)
        return btn
    }

    // MARK: - Utility ──────────────────────────────────────────────────────────

    private func clearPageContent() {
        pageContentNode?.removeFromParent()
        pageContentNode = nil
    }

    // MARK: - Touch handling ───────────────────────────────────────────────────

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        for node in nodes(at: location) {
            guard let name = node.name else { continue }

            switch name {

            // Chapter title buttons on the ToC
            case _ where name.hasPrefix("chapterBtn_"):
                SoundManager.shared.play("sfx_button_tap.mp3")
                if let i = Int(name.dropFirst("chapterBtn_".count)) {
                    showChapterPage(chapterIndex: i, pageIndex: 0)
                }
                return

            // Page-turn arrows
            case "nextPageBtn":
                SoundManager.shared.play("sfx_button_tap.mp3")
                showChapterPage(chapterIndex: currentChapterIndex,
                                pageIndex:    currentPageIndex + 1)
                return

            case "prevPageBtn":
                SoundManager.shared.play("sfx_button_tap.mp3")
                showChapterPage(chapterIndex: currentChapterIndex,
                                pageIndex:    currentPageIndex - 1)
                return

            // Back to table of contents
            case "toTocBtn":
                SoundManager.shared.play("sfx_button_tap.mp3")
                showTableOfContents()
                return

            // Back to the front shop
            case "backToShopBtn":
                SoundManager.shared.play("sfx_button_tap.mp3")
                transitionToFrontShop()
                return

            // Inactive arrow — absorb without playing a sound
            case _ where name.hasPrefix("noop"):
                return

            default:
                continue
            }
        }
    }

    // MARK: - Scene transition ─────────────────────────────────────────────────

    private func transitionToFrontShop() {
        guard let view  = self.view,
              let scene = FrontShopScene(fileNamed: "GameScene") else { return }
        scene.scaleMode        = .resizeFill
        scene.suppressEntryBell = true
        let transition = SKTransition.crossFade(withDuration: 0.5)
        view.presentScene(scene, transition: transition)
    }
}
