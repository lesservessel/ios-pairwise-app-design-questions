import Foundation

/// When to gently suggest the user can stop. There is no hard finish; the user always decides.
public enum StopNudge: Equatable, Sendable {
    case none
    /// Confidence passed 90%.
    case good
    /// Confidence passed 97%, or 5 more comparisons would add under 1 point.
    case diminishing

    public static func evaluate(_ engine: RankingEngine) -> StopNudge {
        guard engine.comparisons.count >= engine.itemCount else { return .none }
        let now = engine.confidence
        let gain = engine.projectedConfidence(afterAdditional: 5) - now
        if now >= 0.97 || (now >= 0.85 && gain < 0.01) { return .diminishing }
        if now >= 0.90 { return .good }
        return .none
    }
}
