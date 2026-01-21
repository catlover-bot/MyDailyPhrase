import SwiftUI

struct GradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                .indigo.opacity(0.20),
                .purple.opacity(0.16),
                .pink.opacity(0.12),
                .clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
