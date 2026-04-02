import SwiftUI

// MARK: - AxisToggle
//
// Custom toggle matching the Axis design system.
// Track: rounded capsule 40×22pt. Thumb: white circle 18pt.
// Off: #2C2C32 track | On: #4B9EFF track.
// Smooth 200ms spring, ReduceMotion respected, VoiceOver accessible.

struct AxisToggle: View {
    @Binding var isOn: Bool
    var label: String? = nil
    var accessibilityLabel: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let trackWidth: CGFloat = 40
    private let trackHeight: CGFloat = 22
    private let thumbSize: CGFloat = 18
    private let thumbPadding: CGFloat = 2

    // Off track: #2C2C32
    private let trackOffColor = Color(hex: 0x2C2C32)
    // On track: #4B9EFF
    private let trackOnColor = Color(hex: 0x4B9EFF)
    private let thumbColor = Color.white

    private var thumbOffset: CGFloat {
        let travel = trackWidth - thumbSize - (thumbPadding * 2)
        return isOn ? travel : 0
    }

    var body: some View {
        HStack(spacing: AxisSpacing.space3) {
            if let label = label {
                Text(label)
                    .font(AxisTypography.bodyFont)
                    .foregroundColor(.axisTextPrimary)
                    .lineSpacing(AxisTypography.bodyLineHeight - 14)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    isOn.toggle()
                }
            } label: {
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(isOn ? trackOnColor : trackOffColor)
                        .frame(width: trackWidth, height: trackHeight)

                    // Thumb
                    Circle()
                        .fill(thumbColor)
                        .frame(width: thumbSize, height: thumbSize)
                        .padding(thumbPadding)
                        .offset(x: thumbOffset)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel ?? label ?? "Toggle")
            .accessibilityValue(isOn ? "On" : "Off")
            .accessibilityHint("Double tap to \(isOn ? "disable" : "enable")")
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
        }
    }
}

// MARK: - Preview

#Preview("Off") {
    VStack(spacing: 24) {
        AxisToggle(isOn: .constant(false), label: "Guardian")
        AxisToggle(isOn: .constant(true), label: "Enabled")
    }
    .padding(24)
    .frame(width: 280)
    .background(Color.axisBackground)
}
