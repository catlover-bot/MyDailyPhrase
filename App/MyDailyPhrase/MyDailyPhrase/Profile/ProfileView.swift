import SwiftUI

struct ProfileView: View {
    @StateObject private var vm: ProfileViewModel

    init(vm: ProfileViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }

    var body: some View {
        Form {
            Section("Your ID") {
                Text(vm.userId)
                    .font(.footnote)
                    .textSelection(.enabled)
            }

            Section("Display Name") {
                TextField("表示名", text: $vm.displayName)
                Button("保存") { vm.save() }
            }
        }
        .navigationTitle("Profile")
        .onAppear { vm.load() }
    }
}
