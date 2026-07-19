import SwiftUI

struct ContentView: View {
    @State private var entries: [MoodEntry] = []

    private let store = MoodEntryStore()

    var body: some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: 24) {
                MoodEntryEditor(onSave: reload)
                WeeklyDiagramView(entries: entries)
                    .padding(.leading, 24)
            }
            HistoryListView(entries: entries)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(24)
        .onAppear(perform: reload)
    }

    private func reload() {
        entries = (try? store.fetchAll()) ?? []
    }
}

#Preview {
    ContentView()
}
