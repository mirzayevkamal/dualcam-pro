import SwiftUI
import AVFoundation
import Photos
import Observation

/// Main view model connecting the MultiCamManager to the SwiftUI UI layer.
@Observable
final class CameraViewModel {

    // MARK: - Manager

    let camManager = MultiCamManager()

    // MARK: - Recording State

    var recordingState: RecordingState = .idle
    var recordingDuration: TimeInterval = 0
    var durationLimit: DurationLimit = .none

    // MARK: - Layout

    var layoutMode: LayoutMode = .pip
    var pipPosition: PiPPosition = .bottomRight
    var pipShape: PiPShape = .rectangle

    // MARK: - Camera Controls

    var iso: Float = 200
    var exposureBias: Float = 0
    var whiteBalanceTemp: Float = 5500
    var selectedLens: LensType = .wide
    var stabilization: StabilizationLevel = .standard

    var availableLenses: [LensType] { camManager.availableBackLenses }

    // MARK: - Recording Mode

    var recordingMode: RecordingMode = .liveComposite

    // MARK: - UI State

    var showControls = false
    var showLayoutPicker = false
    var showSettings = false
    var showExportAlert = false
    var exportProgress: Double = 0
    var alertMessage = ""
    var lastExportedURL: URL?
    var showShareSheet = false

    // MARK: - Thermal

    var thermalWarning: ThermalWarning = .normal

    // MARK: - Setup

    func setup() {
        requestPermissions()
        setupCallbacks()
        camManager.configure()
        observeThermalState()
    }

    func startSession() {
        camManager.startSession()
    }

    func stopSession() {
        camManager.stopSession()
    }

    // MARK: - Permissions

    private func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .video) { _ in }
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { _ in }
    }

    // MARK: - Callbacks

    private func setupCallbacks() {
        camManager.onRecordingDurationUpdate = { [weak self] duration in
            guard let self else { return }
            self.recordingDuration = duration

            // Check duration limit
            if self.durationLimit != .none && duration >= Double(self.durationLimit.rawValue) {
                self.stopRecording()
            }
        }

        camManager.onRecordingFinished = { [weak self] primaryURL, secondaryURL in
            guard let self else { return }
            self.recordingState = .idle

            if let url = primaryURL {
                // Auto-save draft
                _ = ExportManager.shared.saveDraft(url: url)

                // Save to photo library
                self.recordingState = .exporting(progress: 0)
                Task {
                    do {
                        try await ExportManager.shared.saveToPhotoLibrary(url: url)
                        await MainActor.run {
                            self.recordingState = .exported
                            self.lastExportedURL = url
                            self.showExportAlert = true
                            self.alertMessage = "Video saved to Photos!"
                        }
                    } catch {
                        await MainActor.run {
                            self.recordingState = .error(error.localizedDescription)
                            self.alertMessage = "Save failed: \(error.localizedDescription)"
                            self.showExportAlert = true
                        }
                    }
                }
            }

            // Handle secondary URL for separate tracks
            if let url = secondaryURL {
                _ = ExportManager.shared.saveDraft(url: url)
                Task {
                    try? await ExportManager.shared.saveToPhotoLibrary(url: url)
                }
            }
        }

        camManager.onError = { [weak self] message in
            self?.recordingState = .error(message)
            self?.alertMessage = message
            self?.showExportAlert = true
        }
    }

    // MARK: - Recording Control

    func toggleRecording() {
        if camManager.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        // Sync settings to manager
        camManager.layoutMode = layoutMode
        camManager.pipPosition = pipPosition
        camManager.pipShape = pipShape
        camManager.recordingMode = recordingMode
        camManager.stabilization = stabilization

        camManager.startRecording()
        recordingState = .recording
        recordingDuration = 0
    }

    private func stopRecording() {
        camManager.stopRecording()
        // State will be updated via callback
    }

    // MARK: - Camera Controls

    func focusBackCamera(at point: CGPoint) {
        camManager.focus(at: point, on: camManager.backCamera)
    }

    func focusFrontCamera(at point: CGPoint) {
        camManager.focus(at: point, on: camManager.frontCamera)
    }

    func handleZoom(scale: CGFloat, isFront: Bool) {
        camManager.zoom(by: scale, isFront: isFront)
    }

    func lockBackFocus() {
        camManager.lockFocusAndExposure(on: camManager.backCamera)
    }

    func lockFrontFocus() {
        camManager.lockFocusAndExposure(on: camManager.frontCamera)
    }

    func updateISO(_ value: Float) {
        iso = value
        camManager.setISO(value, on: camManager.backCamera)
    }

    func updateExposure(_ value: Float) {
        exposureBias = value
        camManager.setExposure(value, on: camManager.backCamera)
    }

    func updateWhiteBalance(_ value: Float) {
        whiteBalanceTemp = value
        camManager.setWhiteBalance(temperature: value, on: camManager.backCamera)
    }

    func switchLens(_ lens: LensType) {
        selectedLens = lens
        camManager.switchBackLens(to: lens)
    }

    func updateStabilization(_ level: StabilizationLevel) {
        stabilization = level
        camManager.stabilization = level
        camManager.applyStabilization()
    }

    // MARK: - Layout

    func updateLayout(_ mode: LayoutMode) {
        layoutMode = mode
        camManager.layoutMode = mode
    }

    // MARK: - Thermal Monitoring

    private func observeThermalState() {
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkThermalState()
        }
        checkThermalState()
    }

    private func checkThermalState() {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal, .fair:
            thermalWarning = .normal
        case .serious:
            thermalWarning = .elevated
        case .critical:
            thermalWarning = .critical
            // Auto-reduce quality if overheating
            if camManager.isRecording {
                camManager.videoQuality = .hd720
            }
        @unknown default:
            thermalWarning = .normal
        }
    }

    // MARK: - Share

    func shareLastVideo() {
        showShareSheet = true
    }

    var isRecording: Bool {
        if case .recording = recordingState { return true }
        return false
    }
}
