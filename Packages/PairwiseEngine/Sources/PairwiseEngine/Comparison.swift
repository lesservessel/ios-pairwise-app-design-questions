import Foundation

public enum Outcome: String, Codable, Sendable, Equatable {
    case aWins
    case bWins
    case tie
}

/// One user decision. `a` and `b` are indices into the run's item snapshot.
public struct Comparison: Codable, Equatable, Sendable {
    public var a: Int
    public var b: Int
    public var outcome: Outcome
    /// Seconds the user took to decide.
    public var duration: TimeInterval
    public var date: Date

    public init(a: Int, b: Int, outcome: Outcome, duration: TimeInterval = 0, date: Date = Date()) {
        self.a = a
        self.b = b
        self.outcome = outcome
        self.duration = duration
        self.date = date
    }

    public var winner: Int? {
        switch outcome {
        case .aWins: return a
        case .bWins: return b
        case .tie: return nil
        }
    }

    public var loser: Int? {
        switch outcome {
        case .aWins: return b
        case .bWins: return a
        case .tie: return nil
        }
    }
}
