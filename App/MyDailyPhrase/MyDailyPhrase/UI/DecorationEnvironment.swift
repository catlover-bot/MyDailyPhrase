import SwiftUI

private struct CurrentDecorationIdKey: EnvironmentKey {
    // ✅ 空文字はやめる（常に解釈可能なIDにする）
    static let defaultValue: String = "classic"
}

extension EnvironmentValues {
    var currentDecorationId: String {
        get { self[CurrentDecorationIdKey.self] }
        set { self[CurrentDecorationIdKey.self] = newValue }
    }
}
