import SwiftUI

struct ContentView: View {
    @State private var entries: [MoodEntry] = []

    private let store = MoodEntryStore()

    var body: some View {
        HStack(alignment: .top, spacing: 32) {
            MoodEntryEditor(onSave: reload)
            HistoryListView(entries: entries)
                .frame(width: 220, height: 320)
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
