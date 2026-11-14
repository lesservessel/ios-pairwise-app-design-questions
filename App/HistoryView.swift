import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Run.startedAt, order: .reverse) private var runs: [Run]

    var body: some View {
        NavigationStack {
            Group {
                if runs.isEmpty {
                    VStack(spacing: 16) {
                        PearMark().frame(width: 80, height: 80)
                        Text("No rankings yet").font(.title2.bold())
                        Text("Every ranking you run is saved here, even if you later change or delete the list.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(runs) { run in
                            NavigationLink(value: run) { RunRow(run: run) }
                                .listRowBackground(Theme.card)
                        }
                        .onDelete { offsets in
                            for i in offsets { context.delete(runs[i]) }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.cream.ignoresSafeArea())
            .navigationTitle("History")
            .navigationDestination(for: Run.self) { RunContainerView(run: $0) }
        }
    }
}

private struct RunRow: View {
    let run: Run

    var body: some View {
        let log = run.comparisons
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(run.listName.isEmpty ? "Untitled" : run.listName).font(.headline)
                if run.isBlind {
                    Image(systemName: "eye.slash").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(run.isFinished ? "Finished" : "In progress")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(run.isFinished ? Theme.pear.opacity(0.3) : Color.orange.opacity(0.25), in: Capsule())
            }
            if run.isFinished || !run.isBlind,
               !log.isEmpty,
               let top = run.makeEngine().ranking.first,
               run.items.indices.contains(top) {
                Text("#1  \(run.items[top])").font(.subheadline)
            }
            Text("\(run.items.count) items · \(log.count) comparisons · \(run.startedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
