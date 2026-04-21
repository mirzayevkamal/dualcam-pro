import SwiftUI

/// Expandable panel for per-camera manual controls: ISO, Exposure, White Balance, Lens.
struct CameraControlsView: View {
    @Binding var isExpanded: Bool
    @Binding var iso: Float
    @Binding var exposureBias: Float
    @Binding var whiteBalanceTemp: Float
    @Binding var selectedLens: LensType
    @Binding var stabilization: StabilizationLevel
    let availableLenses: [LensType]
    let onISOChange: (Float) -> Void
    let onExposureChange: (Float) -> Void
    let onWhiteBalanceChange: (Float) -> Void
    let onLensChange: (LensType) -> Void
    let onStabilizationChange: (StabilizationLevel) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Toggle button
            Button {
                withAnimation(.spring(response: 0.35)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                    Text("Controls")
                        .font(.caption.bold())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            }

            if isExpanded {
                VStack(spacing: 16) {
                    // Lens Selector
                    if availableLenses.count > 1 {
                        lensSelector
                    }

                    // ISO
                    controlRow(
                        icon: "camera.aperture",
                        label: "ISO",
                        value: String(format: "%.0f", iso),
                        range: 50...1600,
                        current: $iso
                    ) { newValue in
                        onISOChange(newValue)
                    }

                    // Exposure
                    controlRow(
                        icon: "sun.max",
                        label: "EV",
                        value: String(format: "%+.1f", exposureBias),
                        range: -3...3,
                        current: $exposureBias
                    ) { newValue in
                        onExposureChange(newValue)
                    }

                    // White Balance
                    controlRow(
                        icon: "thermometer.medium",
                        label: "WB",
                        value: String(format: "%.0fK", whiteBalanceTemp),
                        range: 2500...8000,
                        current: $whiteBalanceTemp
                    ) { newValue in
                        onWhiteBalanceChange(newValue)
                    }

                    // Stabilization
                    stabilizationSelector
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Lens Selector

    private var lensSelector: some View {
        HStack(spacing: 8) {
            ForEach(availableLenses) { lens in
                Button {
                    selectedLens = lens
                    onLensChange(lens)
                } label: {
                    Text(lens.rawValue)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(selectedLens == lens ? .black : .white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(selectedLens == lens ? Color.yellow : Color.white.opacity(0.2))
                        )
                }
            }
        }
    }

    // MARK: - Control Row

    private func controlRow(
        icon: String,
        label: String,
        value: String,
        range: ClosedRange<Float>,
        current: Binding<Float>,
        onChange: @escaping (Float) -> Void
    ) -> some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 20)
                Text(label)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(value)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.yellow)
            }
            Slider(value: current, in: range) { editing in
                if !editing {
                    onChange(current.wrappedValue)
                }
            }
            .tint(.yellow)
            .onChange(of: current.wrappedValue) { _, newValue in
                onChange(newValue)
            }
        }
    }

    // MARK: - Stabilization Selector

    private var stabilizationSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "hand.raised")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                Text("Stabilization")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.7))
            }
            HStack(spacing: 8) {
                ForEach(StabilizationLevel.allCases) { level in
                    Button {
                        stabilization = level
                        onStabilizationChange(level)
                    } label: {
                        Text(level.rawValue)
                            .font(.caption.bold())
                            .foregroundStyle(stabilization == level ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(stabilization == level ? Color.yellow : Color.white.opacity(0.2))
                            )
                    }
                }
            }
        }
    }
}
