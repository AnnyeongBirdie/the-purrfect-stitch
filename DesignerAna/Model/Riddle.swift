//
//  Riddle.swift
//  DesignerAna
//
//  Multiple-choice riddle model + question bank.
//  RiddleBank first tries to load from Documents/riddles.json
//  (parent-editable at runtime), then falls back to hardcoded defaults.
//

import Foundation

// MARK: - Model

struct Riddle: Codable {
    let question: String
    let choices: [String]   // exactly 4 elements
    let answer: String      // must match one element in choices
    var reward: Int         // 냥 awarded for a correct answer

    // Allow the JSON to omit "reward" and default to 15.
    init(question: String, choices: [String], answer: String, reward: Int = 15) {
        self.question = question
        self.choices  = choices
        self.answer   = answer
        self.reward   = reward
    }

    private enum CodingKeys: String, CodingKey {
        case question, choices, answer, reward
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        question = try c.decode(String.self, forKey: .question)
        choices  = try c.decode([String].self,  forKey: .choices)
        answer   = try c.decode(String.self, forKey: .answer)
        reward   = (try? c.decode(Int.self, forKey: .reward)) ?? 15
    }
}

// MARK: - Bank

enum RiddleBank {

    /// Returns a shuffled copy of the riddle deck.
    static func load() -> [Riddle] {
        (loadFromDocuments() ?? defaultRiddles).shuffled()
    }

    // MARK: Documents-based override

    private static func loadFromDocuments() -> [Riddle]? {
        guard let docs = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let url = docs.appendingPathComponent("riddles.json")
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let riddles = try? JSONDecoder().decode([Riddle].self, from: data),
              !riddles.isEmpty else { return nil }
        return riddles
    }

    // MARK: Hardcoded defaults (8 math + 7 Korean-language trivia)

    static let defaultRiddles: [Riddle] = [

        // ── Math ──────────────────────────────────────────────────────────────
        Riddle(question: "3 + 4 = ?",
               choices: ["5", "6", "7", "8"],
               answer: "7"),

        Riddle(question: "10 - 6 = ?",
               choices: ["3", "4", "5", "6"],
               answer: "4"),

        Riddle(question: "2 × 5 = ?",
               choices: ["8", "9", "10", "12"],
               answer: "10"),

        Riddle(question: "12 ÷ 4 = ?",
               choices: ["2", "3", "4", "6"],
               answer: "3"),

        Riddle(question: "7 + 8 = ?",
               choices: ["13", "14", "15", "16"],
               answer: "15"),

        Riddle(question: "9 × 3 = ?",
               choices: ["24", "27", "30", "33"],
               answer: "27"),

        Riddle(question: "20 - 13 = ?",
               choices: ["5", "6", "7", "8"],
               answer: "7"),

        Riddle(question: "4 × 4 = ?",
               choices: ["12", "14", "16", "18"],
               answer: "16"),

        // ── Korean trivia ─────────────────────────────────────────────────────
        Riddle(question: "사과는 무슨 색일까요?",
               choices: ["파랑", "노랑", "빨강", "초록"],
               answer: "빨강"),

        Riddle(question: "하늘은 무슨 색일까요?",
               choices: ["빨강", "파랑", "초록", "노랑"],
               answer: "파랑"),

        Riddle(question: "고양이는 어떻게 울까요?",
               choices: ["멍멍", "야옹", "꽥꽥", "음매"],
               answer: "야옹"),

        Riddle(question: "일주일은 며칠일까요?",
               choices: ["5일", "6일", "7일", "8일"],
               answer: "7일"),

        Riddle(question: "봄 다음에 오는 계절은?",
               choices: ["겨울", "가을", "여름", "봄"],
               answer: "여름"),

        Riddle(question: "1년은 몇 개월일까요?",
               choices: ["10개월", "11개월", "12개월", "13개월"],
               answer: "12개월"),

        Riddle(question: "태양은 어느 방향에서 뜰까요?",
               choices: ["서쪽", "북쪽", "남쪽", "동쪽"],
               answer: "동쪽"),
    ]
}
