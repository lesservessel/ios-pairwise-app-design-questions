import SwiftUI

/// Shows the comparison flow until the user asks for results, then the results screen.
struct RunContainerView: View {
    let run: Run

    var body: some View {
        Group {
            if run.isFinished {
                ResultsView(run: run)
            } else {
                ComparisonView(run: run)
            }
        }
        .navigationTitle(run.listName.isEmpty ? "Ranking" : run.listName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
