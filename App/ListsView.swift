import SwiftUI
import SwiftData

struct ListsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ItemList.updatedAt, order: .reverse) private var lists: [ItemList]
    @State private var path: [ItemList] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if lists.isEmpty {
                    VStack(spacing: 16) {
                        PearMark().frame(width: 96, height: 96)
                        Text("No lists yet").font(.title2.bold())
                        Text("Make a list of things you want to rank. Pairwise will ask you a series of this-or-that questions and work out your order.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button("Create a list", action: newList)
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(lists) { list in
                            NavigationLink(value: list) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(list.name.isEmpty ? "Untitled" : list.name).font(.headline)
                                    Text("\(list.items.count) item\(list.items.count == 1 ? "" : "s")")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .listRowBackground(Theme.card)
                        }
                        .onDelete { offsets in
                            for i in offsets { context.delete(lists[i]) }
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.cream.ignoresSafeArea())
            .navigationTitle("Pairwise")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: newList) { Image(systemName: "plus") }
                }
            }
            .navigationDestination(for: ItemList.self) { ListDetailView(list: $0) }
        }
    }

    private func newList() {
        let list = ItemList(name: "New List")
        context.insert(list)
        path.append(list)
    }
}
