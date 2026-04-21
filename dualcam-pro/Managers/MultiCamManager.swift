import AVFoundation
import UIKit
import CoreImage

/// Core engine managing dual-camera capture, preview, and recording via AVCaptureMultiCamSession.
final class MultiCamManager: NSObject, @unchecked Sendable {

    // MARK: - Session

    let session = AVCaptureMultiCamSession()
    private let sessionQueue = DispatchQueue(label: "com.dualcampro.session", qos: .userInitiated)
    private let videoOutputQueue = DispatchQueue(label: "com.dualcampro.videoOutput", qos: .userInitiated)
    private let audioOutputQueue = DispatchQueue(label: "com.dualcampro.audioOutput", qos: .userInitiated)

    // MARK: - Inputs

    private var backCameraInput: AVCaptureDeviceInput?
    private var frontCameraInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?

    // MARK: - Outputs

    private var backVideoOutput = AVCaptureVideoDataOutput()
    private var frontVideoOutput = AVCaptureVideoDataOutput()
    private var audioOutput = AVCaptureAudioDataOutput()

    // MARK: - Preview Layers

    private(set) var backPreviewLayer = AVCaptureVideoPreviewLayer()
    private(set) var frontPreviewLayer = AVCaptureVideoPreviewLayer()

    // MARK: - Recording (AVAssetWriter)

    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var recordingStartTime: CMTime = .zero
    private var isWriterStarted = false

    // MARK: - Separate Track Recording

    private var backAssetWriter: AVAssetWriter?
    private var frontAssetWriter: AVAssetWriter?
    private var backVideoWriterInput: AVAssetWriterInput?
    private var frontVideoWriterInput: AVAssetWriterInput?
    private var backAudioWriterInput: AVAssetWriterInput?
    private var frontAudioWriterInput: AVAssetWriterInput?
    private var separateBackStarted = false
    private var separateFrontStarted = false

    // MARK: - Frame Buffers for Compositing

    private var latestBackBuffer: CVPixelBuffer?
    private var latestFrontBuffer: CVPixelBuffer?
    private let bufferLock = NSLock()

    // MARK: - CI Context for Compositing

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: - State Callbacks

    var onRecordingDurationUpdate: ((TimeInterval) -> Void)?
    var onRecordingFinished: ((URL?, URL?) -> Void)? // (compositeURL, or backURL for separate)
    var onError: ((String) -> Void)?

    // MARK: - Configuration

    var layoutMode: LayoutMode = .pip
    var pipPosition: PiPPosition = .bottomRight
    var pipShape: PiPShape = .rectangle
    var recordingMode: RecordingMode = .liveComposite
    var videoQuality: VideoQuality = .hd1080
    var stabilization: StabilizationLevel = .standard
    /// Normalized PiP rect (0-1 range, UIKit coordinates: origin top-left, y-down).
    /// Updated in real-time from the preview layer's position.
    var pipNormalizedRect: CGRect = CGRect(x: 0.66, y: 0.63, width: 0.32, height: 0.28)

    // MARK: - Public State

    private(set) var isRecording = false
    private(set) var isSessionRunning = false

    // MARK: - Devices

    private(set) var backCamera: AVCaptureDevice?
    private(set) var frontCamera: AVCaptureDevice?
    private(set) var availableBackLenses: [LensType] = []

    // MARK: - Timer

    private var durationTimer: Timer?
    private var recordingDuration: TimeInterval = 0

    // MARK: - Setup

    func configure() {
        sessionQueue.async { [weak self] in
            self?.setupSession()
        }
    }

    private func setupSession() {
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            DispatchQueue.main.async {
                self.onError?("MultiCam is not supported on this device.")
            }
            return
        }

        session.beginConfiguration()

        // --- Back Camera ---
        if let device = bestBackCamera(for: .wide) {
            backCamera = device
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) {
                    session.addInputWithNoConnections(input)
                    backCameraInput = input
                }
            } catch {
                print("Back camera input error: \(error)")
            }
        }

        // --- Front Camera ---
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            frontCamera = device
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) {
                    session.addInputWithNoConnections(input)
                    frontCameraInput = input
                }
            } catch {
                print("Front camera input error: \(error)")
            }
        }

        // --- Back Video Output ---
        backVideoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        backVideoOutput.alwaysDiscardsLateVideoFrames = true
        backVideoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        if session.canAddOutput(backVideoOutput) {
            session.addOutputWithNoConnections(backVideoOutput)
        }

        // --- Front Video Output ---
        frontVideoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        frontVideoOutput.alwaysDiscardsLateVideoFrames = true
        frontVideoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        if session.canAddOutput(frontVideoOutput) {
            session.addOutputWithNoConnections(frontVideoOutput)
        }

        // --- Audio Output ---
        audioOutput.setSampleBufferDelegate(self, queue: audioOutputQueue)
        if session.canAddOutput(audioOutput) {
            session.addOutputWithNoConnections(audioOutput)
        }

        // --- Audio Input ---
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            do {
                let input = try AVCaptureDeviceInput(device: audioDevice)
                if session.canAddInput(input) {
                    session.addInputWithNoConnections(input)
                    audioInput = input
                }
            } catch {
                print("Audio input error: \(error)")
            }
        }

        // --- Connections ---
        connectBackCamera()
        connectFrontCamera()
        connectAudio()

        // --- Preview Layers ---
        setupPreviewLayers()

        // --- Stabilization ---
        applyStabilization()

        session.commitConfiguration()

        // Discover available lenses
        discoverLenses()
    }

    // MARK: - Connections

    private func connectBackCamera() {
        guard let input = backCameraInput, let device = backCamera else { return }

        let ports = input.ports(for: .video, sourceDeviceType: device.deviceType, sourceDevicePosition: .back)
        guard let port = ports.first else { return }

        let connection = AVCaptureConnection(inputPorts: [port], output: backVideoOutput)
        connection.videoRotationAngle = 90
        if session.canAddConnection(connection) {
            session.addConnection(connection)
        }
    }

    private func connectFrontCamera() {
        guard let input = frontCameraInput, let device = frontCamera else { return }

        let ports = input.ports(for: .video, sourceDeviceType: device.deviceType, sourceDevicePosition: .front)
        guard let port = ports.first else { return }

        let connection = AVCaptureConnection(inputPorts: [port], output: frontVideoOutput)
        connection.videoRotationAngle = 90
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        if session.canAddConnection(connection) {
            session.addConnection(connection)
        }
    }

    private func connectAudio() {
        guard let input = audioInput, let device = input.device as AVCaptureDevice? else { return }

        let ports = input.ports(for: .audio, sourceDeviceType: device.deviceType, sourceDevicePosition: .unspecified)
        guard let port = ports.first else { return }

        let connection = AVCaptureConnection(inputPorts: [port], output: audioOutput)
        if session.canAddConnection(connection) {
            session.addConnection(connection)
        }
    }

    // MARK: - Preview Layers

    private func setupPreviewLayers() {
        // Back preview
        backPreviewLayer.setSessionWithNoConnection(session)
        if let input = backCameraInput, let device = backCamera {
            let ports = input.ports(for: .video, sourceDeviceType: device.deviceType, sourceDevicePosition: .back)
            if let port = ports.first {
                let previewConnection = AVCaptureConnection(inputPort: port, videoPreviewLayer: backPreviewLayer)
                previewConnection.videoRotationAngle = 90
                if session.canAddConnection(previewConnection) {
                    session.addConnection(previewConnection)
                }
            }
        }
        backPreviewLayer.videoGravity = .resizeAspectFill

        // Front preview
        frontPreviewLayer.setSessionWithNoConnection(session)
        if let input = frontCameraInput, let device = frontCamera {
            let ports = input.ports(for: .video, sourceDeviceType: device.deviceType, sourceDevicePosition: .front)
            if let port = ports.first {
                let previewConnection = AVCaptureConnection(inputPort: port, videoPreviewLayer: frontPreviewLayer)
                previewConnection.videoRotationAngle = 90
                if previewConnection.isVideoMirroringSupported {
                    previewConnection.automaticallyAdjustsVideoMirroring = false
                    previewConnection.isVideoMirrored = true
                }
                if session.canAddConnection(previewConnection) {
                    session.addConnection(previewConnection)
                }
            }
        }
        frontPreviewLayer.videoGravity = .resizeAspectFill
    }

    // MARK: - Session Control

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = true
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }

    // MARK: - Stabilization

    func applyStabilization() {
        for connection in backVideoOutput.connections {
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = stabilization.avMode
            }
        }
        for connection in frontVideoOutput.connections {
            if connection.isVideoStabilizationSupported {
                connection.preferredVideoStabilizationMode = stabilization.avMode
            }
        }
    }

    // MARK: - Lens Discovery & Switching

    private func discoverLenses() {
        var lenses: [LensType] = []
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: .back
        )
        for device in discoverySession.devices {
            switch device.deviceType {
            case .builtInUltraWideCamera: lenses.append(.ultraWide)
            case .builtInWideAngleCamera: lenses.append(.wide)
            case .builtInTelephotoCamera: lenses.append(.telephoto)
            default: break
            }
        }
        DispatchQueue.main.async {
            self.availableBackLenses = lenses
        }
    }

    private func bestBackCamera(for lens: LensType) -> AVCaptureDevice? {
        return AVCaptureDevice.default(lens.deviceType, for: .video, position: .back)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    func switchBackLens(to lens: LensType) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let newDevice = AVCaptureDevice.default(lens.deviceType, for: .video, position: .back) else { return }
            guard newDevice.uniqueID != self.backCamera?.uniqueID else { return }

            self.session.beginConfiguration()

            // Remove old input and connections
            if let oldInput = self.backCameraInput {
                for connection in self.session.connections {
                    for port in connection.inputPorts {
                        if port.input == oldInput {
                            self.session.removeConnection(connection)
                        }
                    }
                }
                self.session.removeInput(oldInput)
            }

            // Add new input
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                if self.session.canAddInput(newInput) {
                    self.session.addInputWithNoConnections(newInput)
                    self.backCameraInput = newInput
                    self.backCamera = newDevice
                }
            } catch {
                print("Lens switch error: \(error)")
            }

            self.connectBackCamera()

            // Reconnect preview
            self.backPreviewLayer.setSessionWithNoConnection(self.session)
            if let input = self.backCameraInput, let device = self.backCamera {
                let ports = input.ports(for: .video, sourceDeviceType: device.deviceType, sourceDevicePosition: .back)
                if let port = ports.first {
                    let conn = AVCaptureConnection(inputPort: port, videoPreviewLayer: self.backPreviewLayer)
                    conn.videoRotationAngle = 90
                    if self.session.canAddConnection(conn) {
                        self.session.addConnection(conn)
                    }
                }
            }

            self.applyStabilization()
            self.session.commitConfiguration()
        }
    }

    // MARK: - Zoom

    private var backZoomFactor: CGFloat = 1.0
    private var frontZoomFactor: CGFloat = 1.0

    func zoom(by delta: CGFloat, isFront: Bool) {
        let camera = isFront ? frontCamera : backCamera
        guard let device = camera else { return }

        let currentZoom = isFront ? frontZoomFactor : backZoomFactor
        let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 10.0)
        let newZoom = min(max(currentZoom * delta, 1.0), maxZoom)

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = newZoom
            device.unlockForConfiguration()
        } catch {
            print("Zoom error: \(error)")
            return
        }

        if isFront {
            frontZoomFactor = newZoom
        } else {
            backZoomFactor = newZoom
        }
    }

    // MARK: - Focus & Exposure

    func focus(at point: CGPoint, on camera: AVCaptureDevice?) {
        guard let device = camera else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
        } catch {
            print("Focus error: \(error)")
        }
    }

    func lockFocusAndExposure(on camera: AVCaptureDevice?) {
        guard let device = camera else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.locked) {
                device.focusMode = .locked
            }
            if device.isExposureModeSupported(.locked) {
                device.exposureMode = .locked
            }
            device.unlockForConfiguration()
        } catch {
            print("Lock focus error: \(error)")
        }
    }

    // MARK: - Manual Controls

    func setISO(_ iso: Float, on camera: AVCaptureDevice?) {
        guard let device = camera else { return }
        let clamped = min(max(iso, device.activeFormat.minISO), device.activeFormat.maxISO)
        do {
            try device.lockForConfiguration()
            device.setExposureModeCustom(duration: AVCaptureDevice.currentExposureDuration, iso: clamped)
            device.unlockForConfiguration()
        } catch {
            print("ISO error: \(error)")
        }
    }

    func setExposure(_ bias: Float, on camera: AVCaptureDevice?) {
        guard let device = camera else { return }
        let clamped = min(max(bias, device.minExposureTargetBias), device.maxExposureTargetBias)
        do {
            try device.lockForConfiguration()
            device.setExposureTargetBias(clamped)
            device.unlockForConfiguration()
        } catch {
            print("Exposure bias error: \(error)")
        }
    }

    func setWhiteBalance(temperature: Float, on camera: AVCaptureDevice?) {
        guard let device = camera else { return }
        let temperatureAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
            temperature: temperature, tint: 0
        )
        var gains = device.deviceWhiteBalanceGains(for: temperatureAndTint)
        let maxGain = device.maxWhiteBalanceGain
        gains.redGain = min(max(gains.redGain, 1.0), maxGain)
        gains.greenGain = min(max(gains.greenGain, 1.0), maxGain)
        gains.blueGain = min(max(gains.blueGain, 1.0), maxGain)
        do {
            try device.lockForConfiguration()
            device.setWhiteBalanceModeLocked(with: gains)
            device.unlockForConfiguration()
        } catch {
            print("White balance error: \(error)")
        }
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        recordingDuration = 0
        isWriterStarted = false
        cachedPiPMask = nil
        cachedPiPBorder = nil
        cachedPiPShape = nil

        if recordingMode == .separateTracks {
            setupSeparateTrackWriters()
        } else {
            setupCompositeWriter()
        }

        DispatchQueue.main.async {
            self.durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.recordingDuration += 0.1
                self.onRecordingDurationUpdate?(self.recordingDuration)
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false

        DispatchQueue.main.async {
            self.durationTimer?.invalidate()
            self.durationTimer = nil
        }

        if recordingMode == .separateTracks {
            finishSeparateTrackWriters()
        } else {
            finishCompositeWriter()
        }
    }

    // MARK: - Composite Writer Setup

    private func setupCompositeWriter() {
        let outputURL = makeOutputURL(suffix: "composite")

        do {
            let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: videoQuality.width,
                AVVideoHeightKey: videoQuality.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 10_000_000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]
            let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            vInput.expectsMediaDataInRealTime = true

            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: vInput,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: videoQuality.width,
                    kCVPixelBufferHeightKey as String: videoQuality.height
                ]
            )

            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128000
            ]
            let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            aInput.expectsMediaDataInRealTime = true

            if writer.canAdd(vInput) { writer.add(vInput) }
            if writer.canAdd(aInput) { writer.add(aInput) }

            assetWriter = writer
            videoWriterInput = vInput
            audioWriterInput = aInput
            pixelBufferAdaptor = adaptor

        } catch {
            DispatchQueue.main.async { self.onError?("Failed to create writer: \(error.localizedDescription)") }
        }
    }

    private func finishCompositeWriter() {
        guard let writer = assetWriter else { return }
        videoWriterInput?.markAsFinished()
        audioWriterInput?.markAsFinished()

        let outputURL = writer.outputURL
        writer.finishWriting { [weak self] in
            DispatchQueue.main.async {
                if writer.status == .completed {
                    self?.onRecordingFinished?(outputURL, nil)
                } else {
                    self?.onError?("Export failed: \(writer.error?.localizedDescription ?? "Unknown")")
                }
            }
            self?.assetWriter = nil
            self?.videoWriterInput = nil
            self?.audioWriterInput = nil
            self?.pixelBufferAdaptor = nil
        }
    }

    // MARK: - Separate Track Writers

    private func setupSeparateTrackWriters() {
        let backURL = makeOutputURL(suffix: "back")
        let frontURL = makeOutputURL(suffix: "front")
        separateBackStarted = false
        separateFrontStarted = false

        do {
            let bWriter = try AVAssetWriter(outputURL: backURL, fileType: .mp4)
            let fWriter = try AVAssetWriter(outputURL: frontURL, fileType: .mp4)

            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: videoQuality.width,
                AVVideoHeightKey: videoQuality.height
            ]

            let bvInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            bvInput.expectsMediaDataInRealTime = true
            let fvInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            fvInput.expectsMediaDataInRealTime = true

            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 128000
            ]
            let baInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            baInput.expectsMediaDataInRealTime = true
            let faInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            faInput.expectsMediaDataInRealTime = true

            if bWriter.canAdd(bvInput) { bWriter.add(bvInput) }
            if bWriter.canAdd(baInput) { bWriter.add(baInput) }
            if fWriter.canAdd(fvInput) { fWriter.add(fvInput) }
            if fWriter.canAdd(faInput) { fWriter.add(faInput) }

            backAssetWriter = bWriter
            frontAssetWriter = fWriter
            backVideoWriterInput = bvInput
            frontVideoWriterInput = fvInput
            backAudioWriterInput = baInput
            frontAudioWriterInput = faInput

        } catch {
            DispatchQueue.main.async { self.onError?("Failed to create writers: \(error.localizedDescription)") }
        }
    }

    private func finishSeparateTrackWriters() {
        let group = DispatchGroup()
        var backURL: URL?
        var frontURL: URL?

        if let bWriter = backAssetWriter {
            backVideoWriterInput?.markAsFinished()
            backAudioWriterInput?.markAsFinished()
            backURL = bWriter.outputURL
            group.enter()
            bWriter.finishWriting { group.leave() }
        }
        if let fWriter = frontAssetWriter {
            frontVideoWriterInput?.markAsFinished()
            frontAudioWriterInput?.markAsFinished()
            frontURL = fWriter.outputURL
            group.enter()
            fWriter.finishWriting { group.leave() }
        }

        group.notify(queue: .main) { [weak self] in
            self?.onRecordingFinished?(backURL, frontURL)
            self?.backAssetWriter = nil
            self?.frontAssetWriter = nil
        }
    }

    // MARK: - Compositing

    /// Cached PiP overlay images (regenerated when shape/size changes)
    private var cachedPiPMask: CIImage?
    private var cachedPiPBorder: CIImage?
    private var cachedPiPShape: PiPShape?
    private var cachedPiPSize: CGSize = .zero

    private func compositeAndWrite(timestamp: CMTime) {
        bufferLock.lock()
        guard let backPB = latestBackBuffer, let frontPB = latestFrontBuffer else {
            bufferLock.unlock()
            return
        }
        let backBuffer = backPB
        let frontBuffer = frontPB
        bufferLock.unlock()

        guard let writer = assetWriter, let vInput = videoWriterInput, let adaptor = pixelBufferAdaptor else { return }

        // Start writer on first frame
        if !isWriterStarted {
            writer.startWriting()
            writer.startSession(atSourceTime: timestamp)
            recordingStartTime = timestamp
            isWriterStarted = true
        }

        guard vInput.isReadyForMoreMediaData else { return }
        guard writer.status == .writing else { return }

        // Use pixel buffer pool from the adaptor (much faster & compatible)
        guard let pool = adaptor.pixelBufferPool else { return }
        var outputBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &outputBuffer)
        guard let buffer = outputBuffer else { return }

        let backImage = CIImage(cvPixelBuffer: backBuffer)
        let frontImage = CIImage(cvPixelBuffer: frontBuffer)

        let w = videoQuality.width
        let h = videoQuality.height
        let outputSize = CGSize(width: w, height: h)
        let composited = compositeImages(back: backImage, front: frontImage, outputSize: outputSize)

        ciContext.render(composited, to: buffer, bounds: CGRect(origin: .zero, size: outputSize), colorSpace: CGColorSpaceCreateDeviceRGB())

        // Use the raw timestamp (must be >= session start time)
        adaptor.append(buffer, withPresentationTime: timestamp)
    }

    private func compositeImages(back: CIImage, front: CIImage, outputSize: CGSize) -> CIImage {
        let backScaled = scaleToFillCentered(image: back, targetSize: outputSize)

        switch layoutMode {
        case .pip:
            let rect = pipNormalizedRect
            let pipSize = CGSize(
                width: rect.width * outputSize.width,
                height: rect.height * outputSize.height
            )
            // Convert UIKit coords (origin top-left, y-down) to CIImage coords (origin bottom-left, y-up)
            let pipX = rect.origin.x * outputSize.width
            let pipY = (1.0 - rect.origin.y - rect.height) * outputSize.height
            let pipOrigin = CGPoint(x: pipX, y: pipY)
            var frontScaled = scaleToFillCentered(image: front, targetSize: pipSize)
            frontScaled = applyPiPClipAndBorder(to: frontScaled, shape: pipShape, size: pipSize)
            frontScaled = frontScaled
                .transformed(by: CGAffineTransform(translationX: pipOrigin.x, y: pipOrigin.y))
            return frontScaled.composited(over: backScaled)

        case .splitHorizontal:
            let halfW = outputSize.width / 2
            let sideSize = CGSize(width: halfW, height: outputSize.height)
            let backCrop = scaleToFillCentered(image: back, targetSize: sideSize)
            let frontCrop = scaleToFillCentered(image: front, targetSize: sideSize)
                .transformed(by: CGAffineTransform(translationX: halfW, y: 0))
            return frontCrop.composited(over: backCrop)

        case .splitVertical:
            let halfH = outputSize.height / 2
            let halfSize = CGSize(width: outputSize.width, height: halfH)
            let backCrop = scaleToFillCentered(image: back, targetSize: halfSize)
            let frontCrop = scaleToFillCentered(image: front, targetSize: halfSize)
                .transformed(by: CGAffineTransform(translationX: 0, y: halfH))
            return frontCrop.composited(over: backCrop)

        case .reaction:
            let rect = pipNormalizedRect
            let pipSize = CGSize(
                width: rect.width * outputSize.width,
                height: rect.height * outputSize.height
            )
            let pipX = rect.origin.x * outputSize.width
            let pipY = (1.0 - rect.origin.y - rect.height) * outputSize.height
            let pipOrigin = CGPoint(x: pipX, y: pipY)
            var frontScaled = scaleToFillCentered(image: front, targetSize: pipSize)
            frontScaled = applyPiPClipAndBorder(to: frontScaled, shape: pipShape, size: pipSize)
            frontScaled = frontScaled
                .transformed(by: CGAffineTransform(translationX: pipOrigin.x, y: pipOrigin.y))
            return frontScaled.composited(over: backScaled)

        case .interview:
            let halfW = outputSize.width / 2
            let sideSize = CGSize(width: halfW, height: outputSize.height)
            let backCrop = scaleToFillCentered(image: back, targetSize: sideSize)
            let frontCrop = scaleToFillCentered(image: front, targetSize: sideSize)
                .transformed(by: CGAffineTransform(translationX: halfW, y: 0))
            return frontCrop.composited(over: backCrop)
        }
    }

    /// Scale image to fill target size, centering the crop.
    private func scaleToFillCentered(image: CIImage, targetSize: CGSize) -> CIImage {
        let srcSize = image.extent.size
        guard srcSize.width > 0, srcSize.height > 0 else {
            return CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: targetSize))
        }
        let scaleX = targetSize.width / srcSize.width
        let scaleY = targetSize.height / srcSize.height
        let scale = max(scaleX, scaleY)

        let scaledW = srcSize.width * scale
        let scaledH = srcSize.height * scale
        let offsetX = (scaledW - targetSize.width) / 2
        let offsetY = (scaledH - targetSize.height) / 2

        return image
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .transformed(by: CGAffineTransform(translationX: -offsetX, y: -offsetY))
            .cropped(to: CGRect(origin: .zero, size: targetSize))
    }

    /// Apply shape clipping and border to the PiP image.
    private func applyPiPClipAndBorder(to image: CIImage, shape: PiPShape, size: CGSize) -> CIImage {
        // Regenerate cached mask + border when shape or size changes
        if cachedPiPShape != shape || cachedPiPSize != size {
            cachedPiPMask = nil
            cachedPiPBorder = nil

            // Use scale 1.0 so pixel dimensions match CIImage coordinates exactly
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0

            let borderWidth: CGFloat = max(2.0, min(size.width, size.height) * 0.008)
            let rect = CGRect(origin: .zero, size: size)
            let minDim = min(size.width, size.height)

            let cornerRadius: CGFloat
            switch shape {
            case .rectangle:                      cornerRadius = minDim * 0.08
            case .square:                         cornerRadius = 0
            case .circle, .pill, .horizontalPill: cornerRadius = minDim / 2
            }

            // Mask (needed for any shape with rounded corners)
            if cornerRadius > 0 {
                let maskRenderer = UIGraphicsImageRenderer(size: size, format: format)
                let maskImg = maskRenderer.image { _ in
                    UIColor.white.setFill()
                    UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).fill()
                }
                cachedPiPMask = maskImg.cgImage.flatMap { CIImage(cgImage: $0) }
            }

            // Border
            let borderRenderer = UIGraphicsImageRenderer(size: size, format: format)
            let borderImg = borderRenderer.image { _ in
                UIColor.white.withAlphaComponent(0.85).setStroke()
                let inset = rect.insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
                let path = UIBezierPath(roundedRect: inset, cornerRadius: cornerRadius)
                path.lineWidth = borderWidth
                path.stroke()
            }
            cachedPiPBorder = borderImg.cgImage.flatMap { CIImage(cgImage: $0) }

            cachedPiPShape = shape
            cachedPiPSize = size
        }

        var result = image

        // Apply shape clip
        if let mask = cachedPiPMask {
            let clear = CIImage(color: .clear).cropped(to: CGRect(origin: .zero, size: size))
            result = result.applyingFilter("CIBlendWithAlphaMask", parameters: [
                kCIInputBackgroundImageKey: clear,
                kCIInputMaskImageKey: mask
            ])
        }

        // Apply border
        if let border = cachedPiPBorder {
            result = border.composited(over: result)
        }

        return result
    }

    // MARK: - Helpers

    private func makeOutputURL(suffix: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let name = "DualCam_\(formatter.string(from: Date()))_\(suffix).mp4"
        let url = docs.appendingPathComponent(name)
        // Remove existing file if present
        try? FileManager.default.removeItem(at: url)
        return url
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension MultiCamManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        if output == backVideoOutput {
            if let pb = CMSampleBufferGetImageBuffer(sampleBuffer) {
                bufferLock.lock()
                latestBackBuffer = pb
                bufferLock.unlock()
            }

            if isRecording {
                if recordingMode == .separateTracks {
                    writeSeparateVideo(sampleBuffer: sampleBuffer, isBack: true, timestamp: timestamp)
                } else {
                    compositeAndWrite(timestamp: timestamp)
                }
            }

        } else if output == frontVideoOutput {
            if let pb = CMSampleBufferGetImageBuffer(sampleBuffer) {
                bufferLock.lock()
                latestFrontBuffer = pb
                bufferLock.unlock()
            }

            if isRecording && recordingMode == .separateTracks {
                writeSeparateVideo(sampleBuffer: sampleBuffer, isBack: false, timestamp: timestamp)
            }

        } else if output == audioOutput {
            if isRecording {
                writeAudio(sampleBuffer: sampleBuffer, timestamp: timestamp)
            }
        }
    }

    private func writeSeparateVideo(sampleBuffer: CMSampleBuffer, isBack: Bool, timestamp: CMTime) {
        if isBack {
            guard let writer = backAssetWriter, let input = backVideoWriterInput else { return }
            if !separateBackStarted {
                writer.startWriting()
                writer.startSession(atSourceTime: timestamp)
                separateBackStarted = true
            }
            if input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }
        } else {
            guard let writer = frontAssetWriter, let input = frontVideoWriterInput else { return }
            if !separateFrontStarted {
                writer.startWriting()
                writer.startSession(atSourceTime: timestamp)
                separateFrontStarted = true
            }
            if input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }
        }
    }

    private func writeAudio(sampleBuffer: CMSampleBuffer, timestamp: CMTime) {
        if recordingMode == .separateTracks {
            if let input = backAudioWriterInput, separateBackStarted, input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }
            if let input = frontAudioWriterInput, separateFrontStarted, input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }
        } else {
            guard let writer = assetWriter, let input = audioWriterInput else { return }
            if !isWriterStarted { return }
            if writer.status == .writing, input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }
        }
    }
}
