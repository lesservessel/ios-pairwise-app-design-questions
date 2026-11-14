import Foundation
import SwiftData
import PairwiseEngine

/// A saved list of items. Editable at any time; runs keep their own snapshot.
@Model
final class ItemList {
    var id: UUID
    var name: String
    var items: [String]
    var createdAt: Date
    var updatedAt: Date

    init(name: String = "New List", items: [String] = []) {
        self.id = UUID()
        self.name = name
        self.items = items
        self.createdAt = .now
        self.updatedAt = .now
    }

    /// Adds trimmed, non-empty, case-insensitively unique items. Returns how many were added.
    @discardableResult
    func add(_ raw: [String]) -> Int {
        var added = 0
        for entry in raw {
            let cleaned = ItemList.clean(entry)
            guard !cleaned.isEmpty,
                  !items.contains(where: { $0.caseInsensitiveCompare(cleaned) == .orderedSame })
            else { continue }
            items.append(cleaned)
            added += 1
        }
        if added > 0 { updatedAt = .now }
        return added
    }

    /// Splits pasted text into one item per line.
    static func parse(_ text: String) -> [String] {
        text.components(separatedBy: .newlines)
    }

    private static func clean(_ s: String) -> String {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        for bullet in ["- ", "• ", "* ", "– "] where t.hasPrefix(bullet) {
            t = String(t.dropFirst(bullet.count)).trimmingCharacters(in: .whitespaces)
            break
        }
        return t
    }
}

/// One ranking session. Snapshots the list's items so later list edits never change history.
@Model
final class Run {
    var id: UUID
    var listName: String
    var sourceListID: UUID?
    var items: [String]
    var isBlind: Bool
    var startedAt: Date
    var finishedAt: Date?
    var logData: Data

    init(list: ItemList, isBlind: Bool) {
        self.id = UUID()
        self.listName = list.name
        self.sourceListID = list.id
        self.items = list.items
        self.isBlind = isBlind
        self.startedAt = .now
        self.finishedAt = nil
        self.logData = Data()
    }

    var isFinished: Bool { finishedAt != nil }

    /// Full comparison log, the source of truth for rankings and statistics.
    var comparisons: [Comparison] {
        get { (try? JSONDecoder().decode([Comparison].self, from: logData)) ?? [] }
        set { logData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    func makeEngine() -> RankingEngine {
        RankingEngine(itemCount: items.count, comparisons: comparisons)
    }
}
