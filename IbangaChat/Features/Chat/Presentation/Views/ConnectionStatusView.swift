import SwiftUI

struct ConnectionStatusView: View {
    let state: SecureConnectionState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: IbangaSpacing.xs + 2) {
            StatusDot(color: state.indicatorColor)
                .opacity(state.isInProgress && isPulsing ? 0.35 : 1)
                .animation(
                    state.isInProgress && !reduceMotion ? .easeInOut(duration: 0.8).repeatForever() : .default,
                    value: isPulsing
                )
            Text(state.title)
                .font(IbangaTypography.caption)
                .foregroundStyle(IbangaColors.textSecondary)
                .contentTransition(.opacity)
        }
        .animation(.easeOut(duration: 0.25), value: state)
        .onAppear { isPulsing = true }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        ConnectionStatusView(state: .secure)
        ConnectionStatusView(state: .establishingSession)
        ConnectionStatusView(state: .inactive)
        ConnectionStatusView(state: .failed)
    }
}
