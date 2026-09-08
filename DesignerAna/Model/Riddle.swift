//
//  Riddle.swift
//  DesignerAna
//
//  Multiple-choice riddle model + question bank.
//  RiddleBank first tries to load from Documents/riddles.json
//  (parent-editable at runtime), then falls back to hardcoded defaults.
//

import Foundation
import os.log

// MARK: - Category

/// Stable ASCII ids so a parent's hand-edited JSON never has to contain
/// Korean category text. Display names are resolved in code so they can
/// change without invalidating every parent file.
enum RiddleCategory: String, Codable, CaseIterable {
    case addSub   // 덧셈과 뺄셈
    case mulDiv   // 곱셈과 나눗셈
    case enToKo   // 영한 단어 암기
    case koToEn   // 한영 단어 암기

    var displayName: String {
        switch self {
        case .addSub: return "덧셈과 뺄셈"
        case .mulDiv: return "곱셈과 나눗셈"
        case .enToKo: return "영한 단어 암기"
        case .koToEn: return "한영 단어 암기"
        }
    }
}

// MARK: - Model

struct Riddle: Codable {
    let question: String
    let choices: [String]   // exactly 4 elements
    let answer: String      // must match one element in choices
    var reward: Int         // 냥 awarded for a correct answer
    var category: RiddleCategory

    // Allow the JSON to omit "reward"/"category" and default sensibly.
    init(question: String, choices: [String], answer: String, reward: Int = 15, category: RiddleCategory = .addSub) {
        self.question = question
        self.choices  = choices
        self.answer   = answer
        self.reward   = reward
        self.category = category
    }

    private enum CodingKeys: String, CodingKey {
        case question, choices, answer, reward, category
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        question = try c.decode(String.self, forKey: .question)
        choices  = try c.decode([String].self,  forKey: .choices)
        answer   = try c.decode(String.self, forKey: .answer)
        reward   = (try? c.decode(Int.self, forKey: .reward)) ?? 15
        // A parent's file that omits or misspells category still loads —
        // it just falls back to a neutral value rather than throwing and
        // silently dumping the whole file back to defaults.
        category = (try? c.decode(RiddleCategory.self, forKey: .category)) ?? .addSub
    }
}

// MARK: - Bank

enum RiddleBank {

    private static let log = OSLog(subsystem: "com.annyeongbirdie.thepurrfectstitch", category: "RiddleBank")

    /// Returns a shuffled copy of the riddle deck.
    /// Load order: a parent's Documents/riddles.json override, then the
    /// bundled v1 content set, then a tiny hardcoded last resort so a
    /// corrupt bundle can never leave the quiz empty.
    static func load() -> [Riddle] {
        (loadFromDocuments() ?? loadFromBundle() ?? fallbackRiddles).shuffled()
    }

    /// Copies the bundled content set into Documents on first launch, so a
    /// parent who opens the Files app finds an editable file in the real
    /// format instead of an empty folder. Absent-only — never overwrites,
    /// or a parent's edits would be destroyed on every launch. Deleting the
    /// file is therefore the reset path: the next launch reseeds it.
    static func seedDocumentsIfNeeded() {
        guard let docs = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = docs.appendingPathComponent("riddles.json")
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        guard let bundleURL = Bundle.main.url(forResource: "riddles", withExtension: "json"),
              let data = try? Data(contentsOf: bundleURL) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: Documents-based override (parent-editable)

    private static func loadFromDocuments() -> [Riddle]? {
        guard let docs = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let url = docs.appendingPathComponent("riddles.json")
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        do {
            let riddles = try JSONDecoder().decode([Riddle].self, from: data)
            guard !riddles.isEmpty else { return nil }
            return riddles
        } catch {
            // Known limitation (v1): this is the only signal a parent's typo
            // gets. A visible in-app warning is filed as a v2 candidate.
            os_log("Documents/riddles.json failed to decode, falling back to bundled defaults: %{public}@",
                   log: log, type: .error, String(describing: error))
            return nil
        }
    }

    // MARK: Bundled content set (the shipped v1 quiz)

    private static func loadFromBundle() -> [Riddle]? {
        guard let url = Bundle.main.url(forResource: "riddles", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let riddles = try? JSONDecoder().decode([Riddle].self, from: data),
              !riddles.isEmpty else { return nil }
        return riddles
    }

    // MARK: Hardcoded last resort (only if the bundled JSON is itself missing/corrupt)

    static let fallbackRiddles: [Riddle] = [
        Riddle(question: "47 + 25 = ?",
               choices: ["62", "72", "612", "82"],
               answer: "72", category: .addSub),
        Riddle(question: "83 - 26 = ?",
               choices: ["57", "63", "67", "47"],
               answer: "57", category: .addSub),
        Riddle(question: "7 × 8 = ?",
               choices: ["54", "56", "63", "64"],
               answer: "56", category: .mulDiv),
        Riddle(question: "56 ÷ 7 = ?",
               choices: ["6", "7", "8", "9"],
               answer: "8", category: .mulDiv),
        Riddle(question: "\"cat\"의 뜻은?",
               choices: ["개", "고양이", "토끼", "쥐"],
               answer: "고양이", category: .enToKo),
        Riddle(question: "\"apple\"의 뜻은?",
               choices: ["바나나", "포도", "사과", "딸기"],
               answer: "사과", category: .enToKo),
        Riddle(question: "\"학교\"는 영어로?",
               choices: ["home", "school", "park", "store"],
               answer: "school", category: .koToEn),
        Riddle(question: "\"물\"은 영어로?",
               choices: ["milk", "juice", "water", "tea"],
               answer: "water", category: .koToEn),
    ]
}
