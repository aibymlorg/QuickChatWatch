import SwiftUI

/// Main tab navigation for iPhone companion app
struct MainTabView: View {
    @EnvironmentObject var watchConnector: WatchConnectorService
    @EnvironmentObject var environmentDetector: EnvironmentDetectionService

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            ContentView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            // Phrases Tab
            PhrasesView()
                .tabItem {
                    Label("Phrases", systemImage: "text.bubble.fill")
                }
                .tag(1)

            // History Tab
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(2)

            // Settings Tab
            PhoneSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(.cyan)
    }
}

/// View for managing custom phrases
struct PhrasesView: View {
    @EnvironmentObject var watchConnector: WatchConnectorService
    @EnvironmentObject var environmentDetector: EnvironmentDetectionService

    @State private var customPhrases: [String] = []
    @State private var newPhrase = ""
    @State private var showingAddPhrase = false

    var body: some View {
        NavigationStack {
            List {
                // Quick phrases section
                Section {
                    ForEach(customPhrases, id: \.self) { phrase in
                        HStack {
                            Text(phrase)
                                .lineLimit(2)

                            Spacer()

                            Button {
                                sendPhraseToWatch(phrase)
                            } label: {
                                Image(systemName: "arrow.right.circle")
                                    .foregroundColor(.cyan)
                            }
                        }
                    }
                    .onDelete(perform: deletePhrase)
                } header: {
                    Text("My Phrases")
                } footer: {
                    Text("Swipe left to delete. Tap arrow to send directly to Watch.")
                }

                // Environment-based phrases
                if let context = environmentDetector.currentContext {
                    Section {
                        ForEach(context.type.suggestedPhrases, id: \.self) { phrase in
                            HStack {
                                Text(phrase)
                                    .lineLimit(2)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Button {
                                    customPhrases.append(phrase)
                                    savePhrases()
                                } label: {
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Image(systemName: context.type.icon)
                            Text("\(context.type.displayName) Suggestions")
                        }
                    }
                }
            }
            .navigationTitle("Phrases")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddPhrase = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .alert("Add Phrase", isPresented: $showingAddPhrase) {
                TextField("Enter phrase", text: $newPhrase)
                Button("Cancel", role: .cancel) {
                    newPhrase = ""
                }
                Button("Add") {
                    if !newPhrase.isEmpty {
                        customPhrases.append(newPhrase)
                        savePhrases()
                        newPhrase = ""
                    }
                }
            } message: {
                Text("Enter a phrase to add to your collection")
            }
            .onAppear {
                loadPhrases()
            }
        }
    }

    private func loadPhrases() {
        if let data = UserDefaults.standard.data(forKey: "customPhrases"),
           let phrases = try? JSONDecoder().decode([String].self, from: data) {
            customPhrases = phrases
        }
    }

    private func savePhrases() {
        if let data = try? JSONEncoder().encode(customPhrases) {
            UserDefaults.standard.set(data, forKey: "customPhrases")
        }
    }

    private func deletePhrase(at offsets: IndexSet) {
        customPhrases.remove(atOffsets: offsets)
        savePhrases()
    }

    private func sendPhraseToWatch(_ phrase: String) {
        watchConnector.sendCustomPhrases([phrase], scenario: "custom")
    }
}

/// View for showing phrase usage history
struct HistoryView: View {
    @State private var history: [PhraseHistoryItem] = []

    var body: some View {
        NavigationStack {
            Group {
                if history.isEmpty {
                    ContentUnavailableView(
                        "No History Yet",
                        systemImage: "clock",
                        description: Text("Phrases spoken on your Watch will appear here")
                    )
                } else {
                    List {
                        ForEach(history) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.phrase)
                                    .font(.body)

                                HStack {
                                    Image(systemName: item.source == "watch" ? "applewatch" : "iphone")
                                        .font(.caption2)

                                    Text(item.timestamp, style: .relative)
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    if let context = item.context {
                                        Text("•")
                                            .foregroundColor(.secondary)
                                        Text(context)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !history.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear") {
                            history.removeAll()
                            saveHistory()
                        }
                    }
                }
            }
            .onAppear {
                loadHistory()
            }
        }
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "phraseHistory"),
           let items = try? JSONDecoder().decode([PhraseHistoryItem].self, from: data) {
            history = items.sorted { $0.timestamp > $1.timestamp }
        }
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: "phraseHistory")
        }
    }
}

struct PhraseHistoryItem: Identifiable, Codable {
    let id: UUID
    let phrase: String
    let timestamp: Date
    let source: String // "watch" or "phone"
    let context: String?

    init(phrase: String, source: String, context: String? = nil) {
        self.id = UUID()
        self.phrase = phrase
        self.timestamp = Date()
        self.source = source
        self.context = context
    }
}

#Preview {
    MainTabView()
        .environmentObject(WatchConnectorService.shared)
        .environmentObject(EnvironmentDetectionService.shared)
}
