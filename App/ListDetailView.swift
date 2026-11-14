import SwiftUI
import SwiftData

struct ListDetailView: View {
    @Bindable var list: ItemList
    @Environment(\.modelContext) private var context
    @State private var newItem = ""
    @State private var showPaste = false
    @State private var showStart = false
    @State private var pendingBlind: Bool?
    @State private var activeRun: Run?

    private static let minItems = 3

    var body: some View {
        List {
            Section("Name") {
                TextField("List name", text: $list.name)
                    .onChange(of: list.name) { list.updatedAt = .now }
            }
            .listRowBackground(Theme.card)

            Section("Add items") {
                HStack {
                    TextField("Add an item", text: $newItem)
                        .submitLabel(.done)
                        .onSubmit(addItem)
                    Button(action: addItem) {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                    .buttonStyle(.borderless)
                    .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Button("Paste several items…") { showPaste = true }
            }
            .listRowBackground(Theme.card)

            Section("\(list.items.count) item\(list.items.count == 1 ? "" : "s")") {
                ForEach(list.items, id: \.self) { Text($0) }
                    .onDelete { offsets in
                        list.items.remove(atOffsets: offsets)
                        list.updatedAt = .now
                    }
                    .onMove { from, to in
                        list.items.move(fromOffsets: from, toOffset: to)
                    }
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.cream.ignoresSafeArea())
        .navigationTitle(list.name.isEmpty ? "Untitled" : list.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .safeAreaInset(edge: .bottom) { startBar }
        .sheet(isPresented: $showPaste) {
            PasteItemsSheet { text in list.add(ItemList.parse(text)) }
        }
        .sheet(isPresented: $showStart, onDismiss: {
            if let blind = pendingBlind {
                pendingBlind = nil
                let run = Run(list: list, isBlind: blind)
                context.insert(run)
                activeRun = run
            }
        }) {
            NewRunSheet(listName: list.name, itemCount: list.items.count) { blind in
                pendingBlind = blind
            }
        }
        .navigationDestination(item: $activeRun) { RunContainerView(run: $0) }
    }

    private var startBar: some View {
        VStack(spacing: 6) {
            Button {
                showStart = true
            } label: {
                Text("Start ranking").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(list.items.count < Self.minItems)

            if list.items.count < Self.minItems {
                let missing = Self.minItems - list.items.count
                Text("Add \(missing) more item\(missing == 1 ? "" : "s") to start (minimum \(Self.minItems)).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.bar)
    }

    private func addItem() {
        if list.add([newItem]) > 0 { newItem = "" }
    }
}

struct PasteItemsSheet: View {
    var onAdd: (String) -> Int
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var skipped: Int?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("One item per line. Blank lines and duplicates are skipped.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .background(Theme.cream.ignoresSafeArea())
            .navigationTitle("Paste items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        _ = onAdd(text)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct NewRunSheet: View {
    let listName: String
    let itemCount: Int
    var onStart: (Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var blind = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Blind mode", isOn: $blind)
                } footer: {
                    Text("Blind mode hides the live ranking so it can't sway your choices. You'll see the order when you finish. Confidence is still shown.")
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.cream.ignoresSafeArea())
            .navigationTitle("Rank \(itemCount) items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        onStart(blind)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
