import SwiftUI
import PairwiseEngine

struct ComparisonView: View {
    let run: Run

    private struct Pair: Equatable { let a: Int; let b: Int }
    private struct Metrics {
        var confidence = 0.5
        var projected = 0.5
        var nudge = StopNudge.none
    }

    @State private var engine: RankingEngine
    @State private var pair: Pair?
    @State private var metrics = Metrics()
    @State private var shownAt = Date()
    @State private var showRankings = true

    init(run: Run) {
        self.run = run
        _engine = State(initialValue: run.makeEngine())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                confidenceCard

                if let pair {
                    VStack(spacing: 10) {
                        choiceCard(pair.a, outcome: .aWins)
                        Text("or").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        choiceCard(pair.b, outcome: .bWins)
                    }
                    .id(pair)
                    .transition(.opacity)

                    Button { answer(.tie) } label: {
                        Label("Can't decide – call it a tie", systemImage: "equal.circle")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                }

                HStack {
                    Button(action: undo) { Label("Undo", systemImage: "arrow.uturn.backward") }
                        .disabled(engine.comparisons.isEmpty)
                    Spacer()
                    if !run.isBlind {
                        Button {
                            withAnimation { showRankings.toggle() }
                        } label: {
                            Label(showRankings ? "Hide rankings" : "Show rankings",
                                  systemImage: showRankings ? "eye.slash" : "eye")
                        }
                    }
                }
                .font(.subheadline)

                if !run.isBlind && showRankings { rankingsPanel }

                finishButton
            }
            .padding()
        }
        .background(Theme.cream.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: engine.comparisons.count)
        .onAppear(perform: refresh)
    }

    // MARK: Pieces

    private var confidenceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Confidence").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Text("\(engine.comparisons.count) comparison\(engine.comparisons.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(percent(metrics.confidence))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.accent)
                .contentTransition(.numericText())

            ProgressView(value: metrics.confidence, total: 1).tint(Theme.pear)

            let gain = metrics.projected - metrics.confidence
            Text(gain >= 0.005
                 ? "5 more comparisons → about \(percent(metrics.projected)) (+\(Int((gain * 100).rounded())) pts)"
                 : "5 more comparisons would add very little")
                .font(.footnote)
                .foregroundStyle(.secondary)

            switch metrics.nudge {
            case .none: EmptyView()
            case .good:
                nudge("Looking solid. Stop whenever you like, or keep going to firm it up.", "checkmark.seal")
            case .diminishing:
                nudge("More comparisons are adding little now. A great time to see your results.", "flag.checkered")
            }
        }
        .pearCard()
    }

    private func nudge(_ text: String, _ icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.footnote.weight(.medium))
            .foregroundStyle(Theme.accent)
            .padding(.top, 2)
    }

    private func choiceCard(_ index: Int, outcome: Outcome) -> some View {
        Button { answer(outcome) } label: {
            Text(name(index))
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 110)
                .pearCard()
        }
        .buttonStyle(.plain)
    }

    private var rankingsPanel: some View {
        let order = engine.ranking
        let scores = RunStatistics.normalizedScores(engine.ratings.map(\.mu))
        return VStack(alignment: .leading, spacing: 10) {
            Text("Current ranking").font(.headline)
            ForEach(Array(order.enumerated()), id: \.element) { pos, idx in
                HStack(spacing: 10) {
                    Text("\(pos + 1)").font(.subheadline.monospacedDigit().weight(.bold))
                        .frame(width: 28, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    Text(name(idx)).lineLimit(1)
                    Spacer()
                    Text(String(format: "%.1f", scores[idx]))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pearCard()
    }

    @ViewBuilder
    private var finishButton: some View {
        let label = Text("See results").font(.headline).frame(maxWidth: .infinity)
        if metrics.nudge == .none {
            Button(action: finish) { label }
                .buttonStyle(.bordered).controlSize(.large)
                .disabled(engine.comparisons.isEmpty)
        } else {
            Button(action: finish) { label }
                .buttonStyle(.borderedProminent).controlSize(.large)
        }
    }

    // MARK: Actions

    private func answer(_ outcome: Outcome) {
        guard let pair else { return }
        let duration = min(Date().timeIntervalSince(shownAt), 120)
        engine.record(Comparison(a: pair.a, b: pair.b, outcome: outcome, duration: duration))
        run.comparisons = engine.comparisons
        withAnimation(.easeInOut(duration: 0.2)) { refresh() }
    }

    private func undo() {
        var log = engine.comparisons
        guard !log.isEmpty else { return }
        log.removeLast()
        engine = RankingEngine(itemCount: run.items.count, comparisons: log)
        run.comparisons = log
        withAnimation(.easeInOut(duration: 0.2)) { refresh() }
    }

    private func finish() {
        run.finishedAt = .now
    }

    private func refresh() {
        let next = engine.nextPair()
        pair = next.map { Pair(a: $0.0, b: $0.1) }
        shownAt = Date()
        metrics = Metrics(
            confidence: engine.confidence,
            projected: engine.projectedConfidence(afterAdditional: 5),
            nudge: StopNudge.evaluate(engine)
        )
    }

    private func name(_ i: Int) -> String {
        run.items.indices.contains(i) ? run.items[i] : "?"
    }

    private func percent(_ v: Double) -> String {
        "\(Int((v * 100).rounded()))%"
    }
}
