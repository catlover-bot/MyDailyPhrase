import SwiftUI
import Domain

struct UserProfileView: View {
    let userId: String
    let name: String

    @EnvironmentObject private var vm: CommunityViewModel

    var body: some View {
        let challenges = vm.challenges(for: userId)

        List {
            Section {
                VStack(spacing: 8) {
                    Text(name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("ID: \(userId)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .padding(.vertical)
            }

            Section("投稿したチャレンジ (\(challenges.count))") {
                if challenges.isEmpty {
                    Text("まだ投稿がありません")
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    ForEach(challenges, id: \.id) { challenge in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(challenge.link.prompt)
                                .font(.headline)
                            Text(challenge.createdAt, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            vm.refresh()
        }
    }
}
