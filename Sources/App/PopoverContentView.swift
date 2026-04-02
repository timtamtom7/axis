import SwiftUI

/// Root SwiftUI view for the Axis menu bar popover.
/// Contains the tabbed interface: Chat | Map | History | Skills
struct PopoverContentView: View {
    @State private var selectedTab: Tab = .chat

    enum Tab: String, CaseIterable {
        case chat = "Chat"
        case map = "Map"
        case history = "History"
        case skills = "Skills"

        var icon: String {
            switch self {
            case .chat:    return "bubble.left.and.bubble.right"
            case .map:     return "map"
            case .history: return "clock"
            case .skills:  return "bolt.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            TabBar(selectedTab: $selectedTab)

            Divider()
                .background(Color(hex: "2C2C30"))

            // Content
            TabView(selection: $selectedTab) {
                PlaceholderTab(title: "Chat")
                    .tag(Tab.chat)

                PlaceholderTab(title: "Project Map")
                    .tag(Tab.map)

                PlaceholderTab(title: "Chat History")
                    .tag(Tab.history)

                PlaceholderTab(title: "Skills")
                    .tag(Tab.skills)
            }
            .tabViewStyle(.automatic)
        }
        .frame(width: 480, height: 640)
        .background(Color(hex: "0A0A0C"))
    }
}

// MARK: - Tab Bar

private struct TabBar: View {
    @Binding var selectedTab: PopoverContentView.Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PopoverContentView.Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .medium))
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(selectedTab == tab ? Color(hex: "FAFAFA") : Color(hex: "8E8E93"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        selectedTab == tab
                            ? Color(hex: "1E1E22")
                            : Color.clear
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Settings gear
            Button {
                // Settings action
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "8E8E93"))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 12)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }
}

// MARK: - Placeholder Tab

private struct PlaceholderTab: View {
    let title: String

    var body: some View {
        VStack {
            Spacer()
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(hex: "8E8E93"))
            Text("Coming in R1")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "5C5C60"))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "0A0A0C"))
    }
}

// MARK: - Color Extension (hex support)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
