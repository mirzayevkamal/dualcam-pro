import SwiftUI

/// Horizontal layout mode picker with icons and PiP customization options.
struct LayoutPickerView: View {
    @Binding var selectedLayout: LayoutMode
    @Binding var pipPosition: PiPPosition
    @Binding var pipShape: PiPShape

    var body: some View {
        VStack(spacing: 12) {
            // Layout mode selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(LayoutMode.allCases) { mode in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selectedLayout = mode
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 18))
                                Text(mode.rawValue)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(selectedLayout == mode ? .black : .white)
                            .frame(width: 60, height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedLayout == mode ? Color.yellow : Color.white.opacity(0.15))
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            // PiP options (only when PiP or Reaction layout)
            if selectedLayout == .pip {
                HStack(spacing: 16) {
                    // Shape picker
                    HStack(spacing: 6) {
                        Text("Shape")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                        ForEach(PiPShape.allCases) { shape in
                            Button {
                                pipShape = shape
                            } label: {
                                shapeIcon(for: shape)
                                    .foregroundStyle(pipShape == shape ? .yellow : .white.opacity(0.5))
                                    .frame(width: 24, height: 24)
                            }
                        }
                    }

                    Spacer()

                    // Position picker
                    HStack(spacing: 6) {
                        Text("Pos")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                        positionGrid
                    }
                }
                .padding(.horizontal, 20)
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private func shapeIcon(for shape: PiPShape) -> some View {
        switch shape {
        case .rectangle:
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(lineWidth: 2)
        case .square:
            Rectangle()
                .strokeBorder(lineWidth: 2)
        case .circle:
            Circle()
                .strokeBorder(lineWidth: 2)
        case .pill:
            Capsule()
                .strokeBorder(lineWidth: 2)
                .frame(width: 14, height: 24)
        case .horizontalPill:
            Capsule()
                .strokeBorder(lineWidth: 2)
                .frame(width: 24, height: 14)
        }
    }

    private var positionGrid: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                positionDot(.topLeft)
                positionDot(.topRight)
            }
            HStack(spacing: 2) {
                positionDot(.bottomLeft)
                positionDot(.bottomRight)
            }
        }
    }

    private func positionDot(_ position: PiPPosition) -> some View {
        Button {
            pipPosition = position
        } label: {
            Circle()
                .fill(pipPosition == position ? Color.yellow : Color.white.opacity(0.3))
                .frame(width: 10, height: 10)
        }
    }
}

// MARK: - Recording Mode Picker

struct RecordingModePicker: View {
    @Binding var selected: RecordingMode

    var body: some View {
        HStack(spacing: 8) {
            ForEach(RecordingMode.allCases) { mode in
                Button {
                    selected = mode
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 16))
                        Text(mode.rawValue)
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selected == mode ? .black : .white)
                    .frame(width: 80, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selected == mode ? Color.yellow : Color.white.opacity(0.15))
                    )
                }
            }
        }
    }
}
