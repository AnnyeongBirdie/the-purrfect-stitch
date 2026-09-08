//
//  TailorIdentityTests.swift
//  DesignerAnaTests
//

import XCTest
@testable import DesignerAna

final class TailorIdentityTests: XCTestCase {

    func testIdentityForKnownIDsReturnsTheMatchingEntry() {
        XCTAssertEqual(Tailor.identity(for: "daphne").displayName, "다프네")
        XCTAssertEqual(Tailor.identity(for: "ana").displayName, "아나 공주")
    }

    func testIdentityForUnknownIDFallsBackToTheDefaultTailor() {
        let fallback = Tailor.identity(for: "nonexistent-id")
        XCTAssertEqual(fallback.id, Tailor.defaultID)
    }

    func testHaloScaleIsOneForAnaAndSeventyPercentForDaphne() {
        let ana = Tailor.identity(for: "ana")
        let daphne = Tailor.identity(for: "daphne")

        XCTAssertEqual(Tailor.haloScale(for: ana), 1.0, accuracy: 0.0001,
                        "Ana's height is the halo's own tuning reference — must scale 1:1")
        XCTAssertEqual(Tailor.haloScale(for: daphne), 0.70, accuracy: 0.0001,
                        "Daphne renders at 70% of Ana's height, per Tailor Identity's own renderedHeight")
    }

    func testDaphneIsPlatformerAndAnaIsPuzzle() {
        XCTAssertEqual(Tailor.identity(for: "daphne").minigameCategory, .platformer)
        XCTAssertEqual(Tailor.identity(for: "ana").minigameCategory, .puzzle)
    }

    func testDaphneHasNoPuzzleGenresAssigned() {
        let daphne = Tailor.identity(for: "daphne")
        XCTAssertTrue(daphne.puzzleGenres.isEmpty)
        XCTAssertNil(daphne.bossPuzzleGenre)
    }

    func testAnaHasAPuzzleGenreForEveryRegularStationAndABossGenre() {
        let ana = Tailor.identity(for: "ana")
        XCTAssertEqual(ana.puzzleGenres[.fabricCabinet], .sudoku)
        XCTAssertEqual(ana.puzzleGenres[.sewingStation], .spotTheDifference)
        XCTAssertEqual(ana.puzzleGenres[.buttonStation], .crossword)
        XCTAssertEqual(ana.bossPuzzleGenre, .mysteryBoard)
    }
}
