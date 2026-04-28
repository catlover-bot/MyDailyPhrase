import SwiftUI
import Domain
import Presentation

struct HistoryView: View {
    @StateObject private var vm: HistoryViewModel

    init(viewModel: HistoryViewModel) {
        _vm = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            if vm.entries.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(vm.entries, id: \.dateKey) { entry in
                        HistoryEntryCard(entry: entry)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    vm.deleteEntry(dateKey: entry.dateKey)
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("履歴")
        .searchable(text: $vm.query, prompt: "お題や回答を検索")
        .task {
            vm.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .entryDidUpdate)) { _ in
            vm.load()
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if vm.hasActiveSearch {
            ContentUnavailableView.search(text: vm.query)
                .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        } else {
            ContentUnavailableView(
                "まだ履歴がありません",
                systemImage: "book.closed",
                description: Text("今日の回答を保存すると、ここからいつでも振り返れます。")
            )
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        }
    }
}

private struct HistoryEntryCard: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(formattedDate(entry.dateKey))
                .font(.headline)

            Text(entry.prompt.text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(answerText)
                .font(.body)
                .foregroundStyle(answerText == "未回答" ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
        .accessibilityElement(children: .combine)
    }

    private var answerText: String {
        let trimmed = entry.answer?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "未回答" : trimmed
    }

    private func formattedDate(_ dateKey: String) -> String {
        let calendar = Calendar.autoupdatingCurrent
        guard let date = DateKey.date(from: dateKey, calendar: calendar) else { return dateKey }

        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.calendar = calendar
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
