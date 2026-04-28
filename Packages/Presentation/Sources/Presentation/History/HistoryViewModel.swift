import Foundation
import Domain

@MainActor
public final class HistoryViewModel: ObservableObject {
    @Published public private(set) var entries: [Entry] = []
    @Published public var query: String = "" {
        didSet { applyFilters() }
    }

    private let listEntries: ListEntriesUseCase
    private let deleteEntryUseCase: DeleteEntryUseCase
    private var allEntries: [Entry] = []

    public init(
        listEntries: ListEntriesUseCase,
        deleteEntry: DeleteEntryUseCase
    ) {
        self.listEntries = listEntries
        self.deleteEntryUseCase = deleteEntry
    }

    public func load() {
        allEntries = listEntries.execute()
        applyFilters()
    }

    public func deleteEntry(dateKey: String) {
        deleteEntryUseCase.execute(dateKey: dateKey)
        load()
        NotificationCenter.default.post(name: .entryDidUpdate, object: nil)
    }

    public var hasActiveSearch: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func applyFilters() {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase

        if normalizedQuery.isEmpty {
            entries = allEntries.sorted { $0.dateKey > $1.dateKey }
            return
        }

        entries = allEntries
            .filter { entry in
                let prompt = entry.prompt.text.localizedLowercase
                let answer = (entry.answer ?? "").localizedLowercase
                return prompt.contains(normalizedQuery) || answer.contains(normalizedQuery)
            }
            .sorted { $0.dateKey > $1.dateKey }
    }
}
