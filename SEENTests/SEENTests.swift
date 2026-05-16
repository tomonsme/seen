//
//  SEENTests.swift
//  SEENTests
//
//  Created by Tomoya Miyake on 2026/05/09.
//

import Foundation
import Testing
@testable import AURA

@MainActor
struct SEENTests {

    @Test func localAnalyzerReturnsAuraResultFields() async throws {
        let answers: [String: AuraAnswer] = [
            "overthink_texts": .yes,
            "act_unbothered": .yes,
            "emotionally_available": .no,
            "reply_fast": .yes,
            "main_character": .sometimes,
            "hard_to_read": .yes,
            "spiral_silently": .yes
        ]

        let analysis = LocalAuraAnalyzer().analyze(answers: answers)

        #expect((0...100).contains(analysis.auraScore))
        #expect(analysis.socialType.isEmpty == false)
        #expect(analysis.badgeTitle.isEmpty == false)
        #expect(analysis.rarity.isEmpty == false)
        #expect(AuraVisual.allCasesForTesting.contains(analysis.visual))
        #expect(analysis.roast.isEmpty == false)
        #expect(analysis.hiddenPattern.isEmpty == false)
        #expect(analysis.receipt.isEmpty == false)
        #expect(analysis.matchup.isEmpty == false)
        #expect(analysis.shareLine.isEmpty == false)
        #expect(analysis.friendHook.isEmpty == false)
        #expect(analysis.challenge.isEmpty == false)
        #expect(analysis.metrics.count == 4)
        #expect(analysis.disclaimer.contains("entertainment") == true)
    }

    @Test func analyzerFallsBackWithoutEndpoint() async throws {
        let analysis = try await AuraAnalyzer().analyze(answers: [:])

        #expect((0...100).contains(analysis.auraScore))
        #expect(analysis.roast.isEmpty == false)
        #expect(analysis.metrics.count == 4)
    }

    @Test func duoAnalyzerReturnsShareableCompatibility() async throws {
        let first = LocalAuraAnalyzer().analyze(answers: [
            "overthink_texts": .yes,
            "act_unbothered": .sometimes,
            "main_character": .yes
        ])
        let second = LocalAuraAnalyzer().analyze(answers: [
            "hard_to_read": .yes,
            "reply_fast": .yes,
            "spiral_silently": .sometimes
        ])

        let compatibility = LocalCompatibilityAnalyzer().analyze(first: first, second: second, mode: .softLaunchTest)

        #expect((0...100).contains(compatibility.score))
        #expect(compatibility.modeTitle == DuoMode.softLaunchTest.rawValue)
        #expect(compatibility.modeHook.isEmpty == false)
        #expect(compatibility.title.isEmpty == false)
        #expect(compatibility.verdict.isEmpty == false)
        #expect(compatibility.tension.isEmpty == false)
        #expect(compatibility.greenFlag.isEmpty == false)
        #expect(compatibility.shareLine.isEmpty == false)
    }

    @Test func partyPollAnalyzerReturnsLocalResult() async throws {
        let result = LocalPartyPollAnalyzer().analyze(
            names: ["Mia", "Jay", "Ava"],
            votes: [
                "overthinks": "Mia",
                "main_character": "Jay",
                "hard_to_read": "Mia",
                "secret_softie": "Ava",
                "soft_launch": "Mia",
                "needs_approval": "Jay"
            ]
        )

        #expect(result.winner == "Mia")
        #expect(result.title.isEmpty == false)
        #expect(result.verdict.isEmpty == false)
        #expect(result.receipt.isEmpty == false)
        #expect(result.shareLine.isEmpty == false)
        #expect(result.scores.count == 3)
        #expect(result.disclaimer.contains("not saved") == true)
    }

    @Test func dailyDropProviderReturnsStableDailyDrop() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let provider = LocalDailyDropProvider()

        let first = provider.today(now: date, calendar: calendar)
        let second = provider.today(now: date.addingTimeInterval(60 * 60), calendar: calendar)

        #expect(first.id == second.id)
        #expect(first.title.isEmpty == false)
        #expect(first.prompt.isEmpty == false)
        #expect(first.verdict.isEmpty == false)
        #expect(first.receipt.isEmpty == false)
        #expect(first.shareLine.isEmpty == false)
        #expect(first.disclaimer.contains("not saved") == true)
    }

    @Test func scanUsesSevenQuestions() async throws {
        #expect(auraQuestions.count == 7)
        #expect(partyPollQuestions.count == 6)
        #expect(AuraAnswer.allCases.map(\.rawValue) == ["No", "Sometimes", "Yes"])
        #expect(DuoMode.allCases.count == 4)
    }
}

private extension AuraVisual {
    static var allCasesForTesting: [AuraVisual] {
        [.pulse, .prism, .spark, .eclipse, .signal]
    }
}
