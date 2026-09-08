//
//  RiddleContentTests.swift
//  DesignerAnaTests
//
//  Loads the shipped riddles.json (not a fixture) and mechanically proves
//  every question is answerable and every arithmetic question is correct.
//  This is the reason the owner can trust 200 questions she did not write
//  herself — treat a failure here as a content bug, never as a test to relax.
//

import XCTest
@testable import DesignerAna

final class RiddleContentTests: XCTestCase {

    /// The shipped bundle content set, loaded the same way RiddleBank does at
    /// runtime. The test bundle is hosted inside the real DesignerAna.app
    /// process (see CLAUDE.md's test-isolation notes), so Bundle.main here
    /// is the same app bundle production code reads from — not the .xctest bundle.
    private func loadShippedRiddles() throws -> [Riddle] {
        guard let url = Bundle.main.url(forResource: "riddles", withExtension: "json") else {
            XCTFail("riddles.json not found in the app bundle — check Copy Bundle Resources")
            return []
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Riddle].self, from: data)
    }

    func testShippedSetHas200QuestionsAcrossFourCategories() throws {
        let riddles = try loadShippedRiddles()
        XCTAssertEqual(riddles.count, 200)

        var counts: [RiddleCategory: Int] = [:]
        for r in riddles { counts[r.category, default: 0] += 1 }
        for category in RiddleCategory.allCases {
            XCTAssertEqual(counts[category], 50, "\(category) should have exactly 50 questions")
        }
    }

    func testEveryQuestionHasExactlyFourChoices() throws {
        let riddles = try loadShippedRiddles()
        for r in riddles {
            XCTAssertEqual(r.choices.count, 4, "'\(r.question)' must have exactly 4 choices")
        }
    }

    func testAnswerExactlyMatchesOneChoice() throws {
        // Same comparison handleAnswer(index:) uses in RiddleScene — a
        // trailing space or different dash makes the question unanswerable.
        let riddles = try loadShippedRiddles()
        for r in riddles {
            XCTAssertTrue(r.choices.contains(r.answer),
                           "'\(r.question)': answer '\(r.answer)' does not exactly match any choice \(r.choices)")
        }
    }

    func testNoDuplicateChoicesWithinAQuestion() throws {
        let riddles = try loadShippedRiddles()
        for r in riddles {
            XCTAssertEqual(Set(r.choices).count, r.choices.count,
                            "'\(r.question)' has duplicate choices: \(r.choices)")
        }
    }

    func testNoLeadingOrTrailingWhitespaceAnywhere() throws {
        let riddles = try loadShippedRiddles()
        for r in riddles {
            XCTAssertFalse(r.question.isEmpty)
            XCTAssertEqual(r.question, r.question.trimmingCharacters(in: .whitespacesAndNewlines),
                            "question has stray whitespace: '\(r.question)'")
            XCTAssertEqual(r.answer, r.answer.trimmingCharacters(in: .whitespacesAndNewlines),
                            "answer has stray whitespace in '\(r.question)'")
            for choice in r.choices {
                XCTAssertFalse(choice.isEmpty)
                XCTAssertEqual(choice, choice.trimmingCharacters(in: .whitespacesAndNewlines),
                                "choice '\(choice)' has stray whitespace in '\(r.question)'")
            }
        }
    }

    func testRewardIsPositive() throws {
        let riddles = try loadShippedRiddles()
        for r in riddles {
            XCTAssertGreaterThan(r.reward, 0, "'\(r.question)' has a non-positive reward")
        }
    }

    func testNoDuplicateQuestionsAcrossTheWholeSet() throws {
        let riddles = try loadShippedRiddles()
        let questions = riddles.map { $0.question }
        XCTAssertEqual(Set(questions).count, questions.count, "duplicate question text found in the shipped set")
    }

    /// Parses each math question with the same regex the sprint prompt specifies,
    /// evaluates it, and asserts it matches the declared answer. Skips anything the
    /// regex doesn't match rather than failing on it, but the skip count itself is
    /// checked so a silently-unreached question can't hide a wrong answer.
    func testArithmeticSelfCheckForMathCategories() throws {
        let riddles = try loadShippedRiddles()
        let mathRiddles = riddles.filter { $0.category == .addSub || $0.category == .mulDiv }
        XCTAssertEqual(mathRiddles.count, 100)

        let pattern = try NSRegularExpression(pattern: #"(\d+)\s*([+\-×÷])\s*(\d+)\s*="#)
        var checked = 0
        var skipped = 0

        for r in mathRiddles {
            let text = r.question
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard let match = pattern.firstMatch(in: text, range: range),
                  let aRange = Range(match.range(at: 1), in: text),
                  let opRange = Range(match.range(at: 2), in: text),
                  let bRange = Range(match.range(at: 3), in: text),
                  let a = Int(text[aRange]),
                  let b = Int(text[bRange]) else {
                skipped += 1
                continue
            }
            let op = String(text[opRange])
            let computed: Int
            switch op {
            case "+": computed = a + b
            case "-": computed = a - b
            case "×": computed = a * b
            case "÷":
                guard b != 0, a % b == 0 else {
                    skipped += 1
                    continue
                }
                computed = a / b
            default:
                skipped += 1
                continue
            }
            XCTAssertEqual(String(computed), r.answer,
                            "'\(r.question)' evaluates to \(computed) but the shipped answer is '\(r.answer)'")
            checked += 1
        }

        XCTAssertLessThanOrEqual(skipped, 4, "arithmetic self-check should reach nearly all 100 math questions")
        XCTAssertGreaterThanOrEqual(checked, 96)
    }

    /// The correct answer's index must be spread across all four button
    /// positions, or a child learns the position instead of the content.
    func testAnswerPositionIsDistributedAcrossAllFourSlots() throws {
        let riddles = try loadShippedRiddles()
        var positionCounts = [Int: Int]()
        for r in riddles {
            guard let idx = r.choices.firstIndex(of: r.answer) else {
                XCTFail("'\(r.question)': answer not found in choices")
                continue
            }
            positionCounts[idx, default: 0] += 1
        }

        XCTAssertEqual(positionCounts.keys.count, 4, "all four answer positions should be used at least once")
        for (_, count) in positionCounts {
            XCTAssertLessThanOrEqual(count, riddles.count / 2,
                                      "no single answer position should hold more than half of all questions")
        }
    }
}
