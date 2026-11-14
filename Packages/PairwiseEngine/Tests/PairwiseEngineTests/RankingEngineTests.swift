import XCTest
@testable import PairwiseEngine

final class RankingEngineTests: XCTestCase {
    /// Simulates a user with a hidden true order (lower index = better).
    private func simulate(items: Int, steps: Int, noise: Double = 0, seed: UInt64 = 1) -> RankingEngine {
        var engine = RankingEngine(itemCount: items)
        var rng = SeededGenerator(seed: seed)
        for _ in 0..<steps {
            guard let (a, b) = engine.nextPair() else { break }
            var aBetter = a < b
            if noise > 0, Double.random(in: 0..<1, using: &rng) < noise { aBetter.toggle() }
            engine.record(Comparison(a: a, b: b, outcome: aBetter ? .aWins : .bWins))
        }
        return engine
    }

    func testStartsWithNoInformation() {
        let engine = RankingEngine(itemCount: 5)
        XCTAssertEqual(engine.confidence, 0.5, accuracy: 1e-9)
    }

    func testWinnerRisesLoserFalls() {
        var engine = RankingEngine(itemCount: 3)
        engine.record(Comparison(a: 0, b: 1, outcome: .aWins))
        XCTAssertGreaterThan(engine.ratings[0].mu, engine.ratings[1].mu)
        XCTAssertEqual(engine.ranking.first, 0)
    }

    func testSigmaShrinksWithComparisons() {
        var engine = RankingEngine(itemCount: 3)
        let before = engine.ratings[0].sigma
        engine.record(Comparison(a: 0, b: 1, outcome: .aWins))
        XCTAssertLessThan(engine.ratings[0].sigma, before)
        XCTAssertLessThan(engine.ratings[1].sigma, before)
        XCTAssertEqual(engine.ratings[2].sigma, before, accuracy: 1e-12)
    }

    func testTiePullsMeansTogether() {
        var engine = RankingEngine(itemCount: 3)
        engine.record(Comparison(a: 0, b: 1, outcome: .aWins))
        engine.record(Comparison(a: 0, b: 2, outcome: .aWins))
        let gapBefore = engine.ratings[0].mu - engine.ratings[1].mu
        engine.record(Comparison(a: 0, b: 1, outcome: .tie))
        let gapAfter = engine.ratings[0].mu - engine.ratings[1].mu
        XCTAssertLessThan(gapAfter, gapBefore)
    }

    func testTieBetweenFreshItemsKeepsThemEqual() {
        var engine = RankingEngine(itemCount: 3)
        engine.record(Comparison(a: 0, b: 1, outcome: .tie))
        XCTAssertEqual(engine.ratings[0].mu, engine.ratings[1].mu, accuracy: 1e-9)
        XCTAssertLessThan(engine.ratings[0].sigma, RankingEngine.initialSigma)
    }

    func testConfidenceIncreasesWithConsistentAnswers() {
        var last = 0.0
        for steps in stride(from: 0, through: 40, by: 10) {
            let c = simulate(items: 8, steps: steps).confidence
            XCTAssertGreaterThanOrEqual(c, last - 1e-9)
            last = c
        }
        XCTAssertGreaterThan(last, 0.9)
    }

    func testConvergesToTrueOrder() {
        let engine = simulate(items: 8, steps: 60)
        XCTAssertEqual(engine.ranking, Array(0..<8))
    }

    func testNoisyUserStillRoughlyConverges() {
        let engine = simulate(items: 6, steps: 60, noise: 0.1)
        XCTAssertEqual(engine.ranking.first, 0)
        XCTAssertEqual(engine.ranking.last, 5)
    }

    func testAdaptiveNeedsFarFewerThanRoundRobin() {
        let items = 12
        let engine = simulate(items: items, steps: items * (items - 1) / 2 / 2)
        // Half the comparisons of a round-robin should land every item near its true place.
        for (position, item) in engine.ranking.enumerated() {
            XCTAssertLessThanOrEqual(abs(position - item), 4)
        }
        XCTAssertEqual(engine.ranking.first, 0)
    }

    func testProjectedConfidenceIsNotLower() {
        let engine = simulate(items: 6, steps: 5)
        XCTAssertGreaterThan(engine.projectedConfidence(afterAdditional: 5), engine.confidence)
    }

    func testProjectionDoesNotMutate() {
        let engine = simulate(items: 6, steps: 5)
        let count = engine.comparisons.count
        _ = engine.projectedConfidence()
        XCTAssertEqual(engine.comparisons.count, count)
    }

    func testNextPairNeverRepeatsImmediately() {
        var engine = RankingEngine(itemCount: 4)
        var previous: (Int, Int)?
        for _ in 0..<20 {
            let pair = engine.nextPair()!
            if let p = previous { XCTAssertFalse(p.0 == pair.0 && p.1 == pair.1) }
            previous = pair
            engine.record(Comparison(a: pair.0, b: pair.1, outcome: pair.0 < pair.1 ? .aWins : .bWins))
        }
    }

    func testTwoItemsStillProducePairs() {
        let engine = RankingEngine(itemCount: 3)
        XCTAssertNotNil(engine.nextPair())
    }

    func testReplayReproducesState() {
        let engine = simulate(items: 6, steps: 20)
        let replay = RankingEngine(itemCount: 6, comparisons: engine.comparisons)
        XCTAssertEqual(replay.ratings, engine.ratings)
    }

    func testInvalidComparisonsIgnored() {
        var engine = RankingEngine(itemCount: 3)
        engine.record(Comparison(a: 1, b: 1, outcome: .aWins))
        engine.record(Comparison(a: 0, b: 9, outcome: .aWins))
        XCTAssertTrue(engine.comparisons.isEmpty)
    }

    func testNumericalStabilityOnLongRuns() {
        let engine = simulate(items: 5, steps: 400)
        for r in engine.ratings {
            XCTAssertTrue(r.mu.isFinite)
            XCTAssertTrue(r.sigma.isFinite)
            XCTAssertGreaterThan(r.sigma, 0)
        }
        XCTAssertLessThanOrEqual(engine.confidence, 1.0)
    }
}

final class StatisticsTests: XCTestCase {
    func testNormalizedScoresRangeAndOrder() {
        let s = RunStatistics.normalizedScores([30, 25, 20, 10])
        XCTAssertTrue(s.allSatisfy { $0 >= 1 && $0 <= 10 })
        XCTAssertEqual(s, s.sorted(by: >))
        XCTAssertEqual(s.reduce(0, +) / 4, 5.5, accuracy: 0.5)
    }

    func testIdenticalScoresAreMidpoint() {
        XCTAssertEqual(RunStatistics.normalizedScores([25, 25, 25]), [5.5, 5.5, 5.5])
    }

    func testTallies() {
        var e = RankingEngine(itemCount: 3)
        e.record(Comparison(a: 0, b: 1, outcome: .aWins, duration: 2))
        e.record(Comparison(a: 0, b: 2, outcome: .tie, duration: 4))
        let stats = RunStatistics(engine: e)
        let zero = stats.items.first { $0.index == 0 }!
        XCTAssertEqual(zero.wins, 1)
        XCTAssertEqual(zero.ties, 1)
        XCTAssertEqual(zero.comparisons, 2)
        XCTAssertEqual(zero.winRate!, 0.75, accuracy: 1e-9)
        XCTAssertEqual(stats.tieCount, 1)
        XCTAssertEqual(stats.averageDecisionTime!, 3, accuracy: 1e-9)
        XCTAssertEqual(stats.fastestDecision?.duration, 2)
        XCTAssertEqual(stats.slowestDecision?.duration, 4)
    }

    func testUncomparedItemHasNilWinRate() {
        var e = RankingEngine(itemCount: 3)
        e.record(Comparison(a: 0, b: 1, outcome: .aWins))
        let stats = RunStatistics(engine: e)
        XCTAssertNil(stats.items.first { $0.index == 2 }!.winRate)
    }

    func testDetectsIntransitiveTriad() {
        var e = RankingEngine(itemCount: 3)
        e.record(Comparison(a: 0, b: 1, outcome: .aWins))
        e.record(Comparison(a: 1, b: 2, outcome: .aWins))
        e.record(Comparison(a: 2, b: 0, outcome: .aWins))
        XCTAssertEqual(RunStatistics(engine: e).intransitiveTriads, 1)
    }

    func testNoTriadWhenConsistent() {
        var e = RankingEngine(itemCount: 3)
        e.record(Comparison(a: 0, b: 1, outcome: .aWins))
        e.record(Comparison(a: 1, b: 2, outcome: .aWins))
        e.record(Comparison(a: 0, b: 2, outcome: .aWins))
        XCTAssertEqual(RunStatistics(engine: e).intransitiveTriads, 0)
    }

    func testBiggestUpset() {
        var e = RankingEngine(itemCount: 4)
        // 0 > 1 > 2 > 3 firmly, then 3 beats 0 once
        for _ in 0..<3 {
            e.record(Comparison(a: 0, b: 1, outcome: .aWins))
            e.record(Comparison(a: 1, b: 2, outcome: .aWins))
            e.record(Comparison(a: 2, b: 3, outcome: .aWins))
            e.record(Comparison(a: 0, b: 2, outcome: .aWins))
            e.record(Comparison(a: 1, b: 3, outcome: .aWins))
        }
        e.record(Comparison(a: 3, b: 0, outcome: .aWins))
        let upset = RunStatistics(engine: e).biggestUpset
        XCTAssertEqual(upset?.winner, 3)
        XCTAssertEqual(upset?.loser, 0)
    }

    func testStabilityNilForShortRuns() {
        var e = RankingEngine(itemCount: 3)
        e.record(Comparison(a: 0, b: 1, outcome: .aWins))
        XCTAssertNil(RunStatistics(engine: e).topStability)
    }

    func testNudgeStartsNone() {
        XCTAssertEqual(StopNudge.evaluate(RankingEngine(itemCount: 4)), .none)
    }

    func testNudgeEventuallyFires() {
        var engine = RankingEngine(itemCount: 5)
        for _ in 0..<80 {
            let (a, b) = engine.nextPair()!
            engine.record(Comparison(a: a, b: b, outcome: a < b ? .aWins : .bWins))
        }
        XCTAssertNotEqual(StopNudge.evaluate(engine), .none)
    }
}

struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
