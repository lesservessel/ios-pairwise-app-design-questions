import SwiftUI
import PairwiseEngine

struct ResultsView: View {
    let run: Run

    var body: some View {
        let stats = RunStatistics(engine: run.makeEngine())
        ScrollView {
            VStack(spacing: 16) {
                summary(stats)
                rankingCard(stats)
                highlights(stats)

                Button {
                    run.finishedAt = nil
                } label: {
                    Label("Keep ranking", systemImage: "arrow.clockwise").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding()
        }
        .background(Theme.cream.ignoresSafeArea())
    }

    // MARK: Sections

    private func summary(_ s: RunStatistics) -> some View {
        HStack {
            stat("Confidence", "\(Int((s.confidence * 100).rounded()))%")
            Divider()
            stat("Comparisons", "\(s.totalComparisons)")
            Divider()
            stat("Ties", "\(s.tieCount)")
        }
        .frame(maxWidth: .infinity)
        .pearCard()
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.title, design: .rounded).weight(.bold)).foregroundStyle(Theme.accent)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func rankingCard(_ s: RunStatistics) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your ranking").font(.headline)
            ForEach(s.items, id: \.index) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(item.rank)")
                            .font(.subheadline.monospacedDigit().weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .trailing)
                        Text(name(item.index)).font(.body.weight(.semibold))
                        Spacer()
                        Text(String(format: "%.1f", item.score))
                            .font(.title3.monospacedDigit().weight(.bold))
                            .foregroundStyle(Theme.accent)
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.pear.opacity(0.18))
                            Capsule().fill(Theme.pear)
                                .frame(width: g.size.width * (item.score - 1) / 9)
                        }
                    }
                    .frame(height: 8)
                    .padding(.leading, 38)

                    Text(detail(item))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 38)
                }
            }
            Text("Scores run 1–10, centered at 5.5, with each standard deviation of skill worth 1.5 points.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pearCard()
    }

    private func detail(_ i: ItemStats) -> String {
        guard let rate = i.winRate else { return "Never compared" }
        var parts = ["Win \(Int((rate * 100).rounded()))%",
                     "\(i.wins)W \(i.losses)L" + (i.ties > 0 ? " \(i.ties)T" : ""),
                     "Certainty \(Int((i.certainty * 100).rounded()))%"]
        if i.comparisons == 1 { parts[1] += " (1 game)" }
        return parts.joined(separator: " · ")
    }

    private func highlights(_ s: RunStatistics) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Fun facts").font(.headline)

            if let r = s.closestRivalry {
                fact("flame", "Closest rivalry",
                     "\(name(r.a)) vs \(name(r.b)) — met \(r.meetings)×, nearly neck and neck.")
            }
            if let u = s.biggestUpset {
                fact("bolt", "Biggest upset",
                     "\(name(u.winner)) beat \(name(u.loser)), who finished \(u.rankGap) place\(u.rankGap == 1 ? "" : "s") higher.")
            }
            fact("arrow.triangle.2.circlepath", "Consistency",
                 s.intransitiveTriads == 0
                 ? "No contradictions. Your choices were perfectly consistent."
                 : "\(s.intransitiveTriads) circular triad\(s.intransitiveTriads == 1 ? "" : "s") (A beat B, B beat C, C beat A).")
            if let st = s.topStability {
                fact("chart.line.flattrend.xyaxis", "Top-5 stability",
                     "\(Int((st * 100).rounded()))% of the top positions were unchanged over your last 10 picks.")
            }
            if let avg = s.averageDecisionTime {
                fact("timer", "Average decision", seconds(avg))
            }
            if let f = s.fastestDecision {
                fact("hare", "Fastest pick", "\(seconds(f.duration)) — \(name(f.a)) vs \(name(f.b))")
            }
            if let sl = s.slowestDecision, sl != s.fastestDecision {
                fact("tortoise", "Toughest call", "\(seconds(sl.duration)) — \(name(sl.a)) vs \(name(sl.b))")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pearCard()
    }

    private func fact(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func name(_ i: Int) -> String {
        run.items.indices.contains(i) ? run.items[i] : "?"
    }

    private func seconds(_ t: TimeInterval) -> String {
        String(format: "%.1fs", t)
    }
}
