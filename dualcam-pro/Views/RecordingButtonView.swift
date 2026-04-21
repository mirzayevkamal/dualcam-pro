import SwiftUI

/// Large recording button with animated state and duration display.
struct RecordingButtonView: View {
    let isRecording: Bool
    let duration: TimeInterval
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Duration display
            if isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .modifier(PulseModifier())
                    Text("REC")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.red)
                    Text(formatDuration(duration))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(.black.opacity(0.6), in: Capsule())
            }

            // Record button
            Button(action: onTap) {
                ZStack {
                    // Outer ring
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .frame(width: 72, height: 72)

                    // Inner shape
                    if isRecording {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.red)
                            .frame(width: 28, height: 28)
                    } else {
                        Circle()
                            .fill(.red)
                            .frame(width: 58, height: 58)
                    }
                }
            }
            .animation(.spring(response: 0.3), value: isRecording)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, tenths)
    }
}

/// Pulsing animation for the REC indicator.
private struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.3 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Duration Limit Picker

struct DurationLimitPicker: View {
    @Binding var selected: DurationLimit

    var body: some View {
        HStack(spacing: 6) {
            ForEach(DurationLimit.allCases) { limit in
                Button {
                    selected = limit
                } label: {
                    Text(limit.displayName)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(selected == limit ? .black : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(selected == limit ? Color.yellow : Color.white.opacity(0.2))
                        )
                }
            }
        }
    }
}
