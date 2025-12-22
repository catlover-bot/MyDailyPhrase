import SwiftUI
import Presentation

struct ContentView: View {
    @StateObject private var viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("今日のお題")
                        .font(.headline)

                    Text(viewModel.promptText)
                        .font(.title3)
                        .bold()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("あなたの回答")
                        .font(.headline)

                    TextField("短く一言で…", text: $viewModel.answerText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3, reservesSpace: true)
                }

                Button {
                    viewModel.submit()
                } label: {
                    Text(viewModel.isAnsweredToday ? "更新する" : "保存する")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                HStack {
                    Text("連続日数")
                    Spacer()
                    Text("\(viewModel.streak) 日")
                        .bold()
                }
                .padding(.top, 8)

                Spacer()
            }
            .padding()
            .navigationTitle("MyDailyPhrase")
        }
        .onAppear { viewModel.load() }
    }
}
