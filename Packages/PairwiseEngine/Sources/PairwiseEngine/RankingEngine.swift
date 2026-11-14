import Foundation

/// Gaussian skill belief for one item.
public struct Rating: Equatable, Sendable {
    public var mu: Double
    public var sigma: Double
    public var variance: Double { sigma * sigma }
}

/// Adaptive pairwise ranking using a TrueSkill-style Gaussian update with draw (tie) support.
///
/// The engine is a pure value type. The comparison log is the source of truth: any engine
/// can be rebuilt by replaying `comparisons`.
public struct RankingEngine: Sendable {
    public static let initialMu = 25.0
    public static let initialSigma = 25.0 / 3.0
    public static let beta = initialSigma / 2.0
    /// Draw margin for roughly a 10% prior chance of a tie.
    public static let drawMargin = 0.74

    public let itemCount: Int
    public private(set) var ratings: [Rating]
    public private(set) var comparisons: [Comparison] = []
    private var pairCounts: [Int: Int] = [:]

    public init(itemCount: Int, comparisons: [Comparison] = []) {
        self.itemCount = itemCount
        self.ratings = Array(
            repeating: Rating(mu: Self.initialMu, sigma: Self.initialSigma),
            count: itemCount
        )
        for c in comparisons { record(c) }
    }

    // MARK: - Updating

    public mutating func record(_ comparison: Comparison) {
        guard comparison.a != comparison.b,
              (0..<itemCount).contains(comparison.a),
              (0..<itemCount).contains(comparison.b) else { return }

        comparisons.append(comparison)
        pairCounts[pairKey(comparison.a, comparison.b), default: 0] += 1

        let ra = ratings[comparison.a]
        let rb = ratings[comparison.b]
        let c2 = 2 * Self.beta * Self.beta + ra.variance + rb.variance
        let c = c2.squareRoot()
        let eps = Self.drawMargin / c

        switch comparison.outcome {
        case .aWins, .bWins:
            let winnerIdx = comparison.winner!
            let loserIdx = comparison.loser!
            let w = ratings[winnerIdx]
            let l = ratings[loserIdx]
            let t = (w.mu - l.mu) / c
            let v = Self.vWin(t, eps)
            let wv = Self.wWin(t, eps)
            ratings[winnerIdx] = Self.updated(w, shift: w.variance / c * v, factor: w.variance / c2 * wv)
            ratings[loserIdx] = Self.updated(l, shift: -l.variance / c * v, factor: l.variance / c2 * wv)
        case .tie:
            let t = (ra.mu - rb.mu) / c
            let v = Self.vDraw(t, eps)
            let wv = Self.wDraw(t, eps)
            ratings[comparison.a] = Self.updated(ra, shift: ra.variance / c * v, factor: ra.variance / c2 * wv)
            ratings[comparison.b] = Self.updated(rb, shift: -rb.variance / c * v, factor: rb.variance / c2 * wv)
        }
    }

    private static func updated(_ r: Rating, shift: Double, factor: Double) -> Rating {
        let newVar = r.variance * max(1 - factor, 1e-4)
        return Rating(mu: r.mu + shift, sigma: newVar.squareRoot())
    }

    private static func vWin(_ t: Double, _ eps: Double) -> Double {
        let x = t - eps
        let denom = Gaussian.cdf(x)
        if denom < 1e-12 { return -x }
        return Gaussian.pdf(x) / denom
    }

    private static func wWin(_ t: Double, _ eps: Double) -> Double {
        let v = vWin(t, eps)
        return min(max(v * (v + t - eps), 0), 1 - 1e-6)
    }

    private static func vDraw(_ t: Double, _ eps: Double) -> Double {
        let denom = Gaussian.cdf(eps - t) - Gaussian.cdf(-eps - t)
        if denom < 1e-12 { return t < 0 ? (-t + eps) : (-t - eps) }
        return (Gaussian.pdf(-eps - t) - Gaussian.pdf(eps - t)) / denom
    }

    private static func wDraw(_ t: Double, _ eps: Double) -> Double {
        let denom = Gaussian.cdf(eps - t) - Gaussian.cdf(-eps - t)
        if denom < 1e-12 { return 1 - 1e-6 }
        let v = vDraw(t, eps)
        let w = v * v + ((eps - t) * Gaussian.pdf(eps - t) + (eps + t) * Gaussian.pdf(eps + t)) / denom
        return min(max(w, 0), 1 - 1e-6)
    }

    // MARK: - Ranking

    /// Item indices, best first.
    public var ranking: [Int] {
        (0..<itemCount).sorted { x, y in
            if ratings[x].mu != ratings[y].mu { return ratings[x].mu > ratings[y].mu }
            return x < y
        }
    }

    /// Mean probability that a randomly chosen pair is ordered correctly by the current ranking.
    /// 0.5 means no information (coin flip), 1.0 means every pair is certain.
    public var confidence: Double {
        let order = ranking
        guard order.count > 1 else { return 1 }
        var total = 0.0
        var pairs = 0
        for i in 0..<order.count {
            for j in (i + 1)..<order.count {
                let hi = ratings[order[i]]
                let lo = ratings[order[j]]
                let s = (hi.variance + lo.variance).squareRoot()
                total += Gaussian.cdf((hi.mu - lo.mu) / s)
                pairs += 1
            }
        }
        return total / Double(pairs)
    }

    /// Estimated confidence after `count` more comparisons, assuming the user's answers
    /// agree with the current ranking.
    public func projectedConfidence(afterAdditional count: Int = 5) -> Double {
        var copy = self
        for _ in 0..<count {
            guard let (a, b) = copy.nextPair() else { break }
            let outcome: Outcome = copy.ratings[a].mu >= copy.ratings[b].mu ? .aWins : .bWins
            copy.record(Comparison(a: a, b: b, outcome: outcome))
        }
        return copy.confidence
    }

    // MARK: - Pair selection

    /// The most informative pair to ask next: close in skill, high combined uncertainty,
    /// not asked repeatedly, and never the same pair twice in a row.
    public func nextPair() -> (Int, Int)? {
        guard itemCount >= 2 else { return nil }
        let last = comparisons.last
        var best: (Int, Int)?
        var bestScore = -Double.infinity

        for i in 0..<itemCount {
            for j in (i + 1)..<itemCount {
                if itemCount > 2, let last, pairKey(last.a, last.b) == pairKey(i, j) { continue }
                let ri = ratings[i]
                let rj = ratings[j]
                let c2 = 2 * Self.beta * Self.beta + ri.variance + rj.variance
                let delta = ri.mu - rj.mu
                let closeness = exp(-delta * delta / (2 * c2))
                let uncertainty = (ri.variance + rj.variance) / c2.squareRoot()
                let repeats = Double(pairCounts[pairKey(i, j), default: 0])
                let score = closeness * uncertainty / (1 + repeats)
                if score > bestScore + 1e-12 {
                    bestScore = score
                    best = (i, j)
                }
            }
        }
        return best
    }

    private func pairKey(_ a: Int, _ b: Int) -> Int {
        min(a, b) * itemCount + max(a, b)
    }
}
