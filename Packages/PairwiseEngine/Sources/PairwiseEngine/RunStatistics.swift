import Foundation

public struct ItemStats: Equatable, Sendable {
    public let index: Int
    /// 1-based.
    public let rank: Int
    public let mu: Double
    public let sigma: Double
    /// Normalized score on a 1...10 scale.
    public let score: Double
    public let comparisons: Int
    public let wins: Int
    public let losses: Int
    public let ties: Int
    /// Ties count as half a win. Nil if never compared.
    public let winRate: Double?
    /// 0...1, how settled this item's position is (1 - sigma / initial sigma).
    public let certainty: Double
}

public struct Rivalry: Equatable, Sendable {
    public let a: Int
    public let b: Int
    public let meetings: Int
    /// Final skill gap between the two items.
    public let gap: Double
}

public struct Upset: Equatable, Sendable {
    public let winner: Int
    public let loser: Int
    /// How many places the winner sits below the loser in the final ranking.
    public let rankGap: Int
}

public struct RunStatistics: Equatable, Sendable {
    public let items: [ItemStats]          // ordered best first
    public let confidence: Double
    public let totalComparisons: Int
    public let tieCount: Int
    public let closestRivalry: Rivalry?
    public let biggestUpset: Upset?
    public let intransitiveTriads: Int
    /// Fraction of the top-k positions unchanged versus 10 comparisons ago. Nil if fewer than 10 comparisons.
    public let topStability: Double?
    public let averageDecisionTime: TimeInterval?
    public let fastestDecision: Comparison?
    public let slowestDecision: Comparison?

    public init(engine: RankingEngine) {
        let order = engine.ranking
        let n = engine.itemCount
        let log = engine.comparisons

        // Per-item tallies
        var wins = [Int](repeating: 0, count: n)
        var losses = [Int](repeating: 0, count: n)
        var ties = [Int](repeating: 0, count: n)
        for c in log {
            switch c.outcome {
            case .aWins: wins[c.a] += 1; losses[c.b] += 1
            case .bWins: wins[c.b] += 1; losses[c.a] += 1
            case .tie: ties[c.a] += 1; ties[c.b] += 1
            }
        }

        let scores = Self.normalizedScores(engine.ratings.map(\.mu))
        var rankOf = [Int](repeating: 0, count: n)
        for (pos, idx) in order.enumerated() { rankOf[idx] = pos + 1 }

        items = order.map { idx in
            let r = engine.ratings[idx]
            let played = wins[idx] + losses[idx] + ties[idx]
            return ItemStats(
                index: idx,
                rank: rankOf[idx],
                mu: r.mu,
                sigma: r.sigma,
                score: scores[idx],
                comparisons: played,
                wins: wins[idx],
                losses: losses[idx],
                ties: ties[idx],
                winRate: played == 0 ? nil : (Double(wins[idx]) + 0.5 * Double(ties[idx])) / Double(played),
                certainty: min(max(1 - r.sigma / RankingEngine.initialSigma, 0), 1)
            )
        }

        confidence = engine.confidence
        totalComparisons = log.count
        tieCount = log.filter { $0.outcome == .tie }.count

        // Head-to-head
        var meetings: [Int: Int] = [:]
        var net: [Int: Int] = [:]   // key i*n+j: wins of i over j minus wins of j over i
        for c in log {
            meetings[min(c.a, c.b) * n + max(c.a, c.b), default: 0] += 1
            if let w = c.winner, let l = c.loser {
                net[w * n + l, default: 0] += 1
                net[l * n + w, default: 0] -= 1
            }
        }

        // Closest rivalry: smallest gap among pairs that met, most meetings breaks ties
        var rivalry: Rivalry?
        for (key, count) in meetings {
            let i = key / n, j = key % n
            let gap = abs(engine.ratings[i].mu - engine.ratings[j].mu)
            let candidate = Rivalry(a: i, b: j, meetings: count, gap: gap)
            if let current = rivalry {
                if gap < current.gap - 1e-9 || (abs(gap - current.gap) <= 1e-9 && count > current.meetings) {
                    rivalry = candidate
                }
            } else {
                rivalry = candidate
            }
        }
        closestRivalry = rivalry

        // Biggest upset
        var upset: Upset?
        for c in log {
            guard let w = c.winner, let l = c.loser else { continue }
            let gap = rankOf[w] - rankOf[l]
            if gap > 0, gap > (upset?.rankGap ?? 0) {
                upset = Upset(winner: w, loser: l, rankGap: gap)
            }
        }
        biggestUpset = upset

        // Intransitive triads: i beats j, j beats k, k beats i (by net head-to-head)
        func beats(_ x: Int, _ y: Int) -> Bool { (net[x * n + y] ?? 0) > 0 }
        var triads = 0
        if n >= 3 {
            for i in 0..<n {
                for j in (i + 1)..<n {
                    for k in (j + 1)..<n {
                        if (beats(i, j) && beats(j, k) && beats(k, i)) ||
                            (beats(i, k) && beats(k, j) && beats(j, i)) {
                            triads += 1
                        }
                    }
                }
            }
        }
        intransitiveTriads = triads

        // Stability of the top positions over the last 10 comparisons
        if log.count >= 10 {
            let earlier = RankingEngine(itemCount: n, comparisons: Array(log.dropLast(10)))
            let k = min(5, n)
            let before = Array(earlier.ranking.prefix(k))
            let now = Array(order.prefix(k))
            let same = zip(before, now).filter { $0 == $1 }.count
            topStability = Double(same) / Double(k)
        } else {
            topStability = nil
        }

        // Decision timing (ignore zero durations, e.g. imported data)
        let timed = log.filter { $0.duration > 0 }
        averageDecisionTime = timed.isEmpty ? nil : timed.map(\.duration).reduce(0, +) / Double(timed.count)
        fastestDecision = timed.min { $0.duration < $1.duration }
        slowestDecision = timed.max { $0.duration < $1.duration }
    }

    /// Maps skill means to 1...10 via z-score: mean 5.5, one standard deviation = 1.5 points, clamped.
    /// Identical skills all score 5.5.
    public static func normalizedScores(_ mus: [Double]) -> [Double] {
        guard !mus.isEmpty else { return [] }
        let mean = mus.reduce(0, +) / Double(mus.count)
        let variance = mus.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(mus.count)
        let sd = variance.squareRoot()
        guard sd > 1e-9 else { return mus.map { _ in 5.5 } }
        return mus.map { min(max(5.5 + 1.5 * ($0 - mean) / sd, 1), 10) }
    }
}
