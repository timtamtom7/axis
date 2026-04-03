import SwiftUI

// MARK: - EmptyChatView
//
// Empty state when no chat is selected or first launch.
// Warm, inviting — not corporate. One primary action.

struct EmptyChatView: View {
    let onNewChat: () -> Void

    var body: some View {
        VStack(spacing: AxisSpacing.space6) {
            Spacer()

            // Brain icon
            Image(systemName: "brain.head.profile")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(.axisGold)
                .shadow(color: Color.axisGold.opacity(0.3), radius: 12, x: 0, y: 4)

            // Title
            Text("Start a conversation")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.axisTextPrimary)

            // Subtitle
            Text("Open a project to begin")
                .font(.system(size: 13))
                .foregroundColor(.axisTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            // Primary action
            Button {
                onNewChat()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 12, weight: .medium))
                    Text("New Chat")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Color.axisAccent)
                .cornerRadius(AxisSpacing.radiusMedium)
            }
            .buttonStyle(.plain)
            .shadow(color: Color.axisAccent.opacity(0.4), radius: 8, x: 0, y: 3)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.axisBackground)
    }
}

// MARK: - Previews

#Preview("Empty chat") {
    EmptyChatView(onNewChat: {})
        .frame(width: 480, height: 640)
}
