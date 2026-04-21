import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var viewModel = CameraViewModel()

    var body: some View {
        ZStack {
            // Camera Preview (full screen)
            CameraPreviewView(
                backPreviewLayer: viewModel.camManager.backPreviewLayer,
                frontPreviewLayer: viewModel.camManager.frontPreviewLayer,
                layoutMode: viewModel.layoutMode,
                pipPosition: viewModel.pipPosition,
                pipShape: viewModel.pipShape,
                onTapBack: { point in
                    viewModel.focusBackCamera(at: point)
                },
                onTapFront: { point in
                    viewModel.focusFrontCamera(at: point)
                },
                onLongPressBack: {
                    viewModel.lockBackFocus()
                },
                onLongPressFront: {
                    viewModel.lockFrontFocus()
                },
                onPinchZoom: { scale, isFront in
                    viewModel.handleZoom(scale: scale, isFront: isFront)
                },
                onPiPPositionChanged: { rect in
                    viewModel.camManager.pipNormalizedRect = rect
                }
            )
            .ignoresSafeArea()

            // Overlay UI
            VStack {
                topBar
                Spacer()
                bottomControls
            }

            // Thermal warning
            if let message = viewModel.thermalWarning.message {
                thermalBanner(message: message)
            }

            // Export progress overlay
            if case .exporting(let progress) = viewModel.recordingState {
                exportOverlay(progress: progress)
            }
        }
        .statusBarHidden(true)
        .onAppear {
            viewModel.setup()
            viewModel.startSession()
        }
        .onDisappear {
            viewModel.stopSession()
        }
        .alert("DualCam Pro", isPresented: $viewModel.showExportAlert) {
            Button("OK") { viewModel.recordingState = .idle }
            if viewModel.lastExportedURL != nil {
                Button("Share") { viewModel.shareLastVideo() }
            }
        } message: {
            Text(viewModel.alertMessage)
        }
        .sheet(isPresented: $viewModel.showShareSheet) {
            if let url = viewModel.lastExportedURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack(spacing: 8) {
            HStack {
                // Recording mode indicator
                Menu {
                    ForEach(RecordingMode.allCases) { mode in
                        Button {
                            viewModel.recordingMode = mode
                        } label: {
                            Label(mode.rawValue, systemImage: mode.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.recordingMode.icon)
                        Text(viewModel.recordingMode.rawValue)
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .disabled(viewModel.isRecording)

                Spacer()

                // Duration limit
                if !viewModel.isRecording {
                    Menu {
                        ForEach(DurationLimit.allCases) { limit in
                            Button {
                                viewModel.durationLimit = limit
                            } label: {
                                HStack {
                                    Text(limit.displayName)
                                    if viewModel.durationLimit == limit {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                            Text(viewModel.durationLimit.displayName)
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                }

                Spacer()

                // Video quality
                Menu {
                    ForEach(VideoQuality.allCases) { quality in
                        Button {
                            viewModel.camManager.videoQuality = quality
                        } label: {
                            HStack {
                                Text(quality.rawValue)
                                if viewModel.camManager.videoQuality == quality {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Text(viewModel.camManager.videoQuality.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .disabled(viewModel.isRecording)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 12) {
            // Camera controls panel
            CameraControlsView(
                isExpanded: $viewModel.showControls,
                iso: $viewModel.iso,
                exposureBias: $viewModel.exposureBias,
                whiteBalanceTemp: $viewModel.whiteBalanceTemp,
                selectedLens: $viewModel.selectedLens,
                stabilization: $viewModel.stabilization,
                availableLenses: viewModel.availableLenses,
                onISOChange: { viewModel.updateISO($0) },
                onExposureChange: { viewModel.updateExposure($0) },
                onWhiteBalanceChange: { viewModel.updateWhiteBalance($0) },
                onLensChange: { viewModel.switchLens($0) },
                onStabilizationChange: { viewModel.updateStabilization($0) }
            )

            // Layout picker
            if !viewModel.isRecording {
                LayoutPickerView(
                    selectedLayout: $viewModel.layoutMode,
                    pipPosition: $viewModel.pipPosition,
                    pipShape: $viewModel.pipShape
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Recording button
            RecordingButtonView(
                isRecording: viewModel.isRecording,
                duration: viewModel.recordingDuration,
                onTap: {
                    viewModel.toggleRecording()
                }
            )
            .padding(.bottom, 20)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Thermal Banner

    private func thermalBanner(message: String) -> some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "thermometer.sun.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.red.opacity(0.8), in: Capsule())
            .padding(.top, 60)

            Spacer()
        }
        .transition(.move(edge: .top))
    }

    // MARK: - Export Overlay

    private func exportOverlay(progress: Double) -> some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView(value: progress) {
                    Text("Saving...")
                        .font(.headline)
                        .foregroundStyle(.white)
                } currentValueLabel: {
                    Text("\(Int(progress * 100))%")
                        .font(.system(.title2, design: .monospaced))
                        .foregroundStyle(.yellow)
                }
                .progressViewStyle(.linear)
                .tint(.yellow)
                .frame(width: 200)
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ContentView()
}
