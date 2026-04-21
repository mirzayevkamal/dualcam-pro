import Foundation
import AVFoundation

// MARK: - Recording State

enum RecordingState: Equatable {
    case idle
    case recording
    case exporting(progress: Double)
    case exported
    case error(String)
}

// MARK: - Camera Mode (which cameras to use)

enum CameraMode: String, CaseIterable, Identifiable {
    case frontAndBack = "Front + Back"
    case backAndBack = "Dual Back"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .frontAndBack: return "person.2.fill"
        case .backAndBack: return "camera.fill"
        }
    }
}

// MARK: - Recording Mode

enum RecordingMode: String, CaseIterable, Identifiable {
    case liveComposite = "Live Composite"
    case separateTracks = "Separate Tracks"
    case smart = "Smart Mode"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .liveComposite: return "film"
        case .separateTracks: return "square.split.2x1"
        case .smart: return "brain"
        }
    }

    var subtitle: String {
        switch self {
        case .liveComposite: return "Ready-to-post video"
        case .separateTracks: return "Save both streams"
        case .smart: return "AI auto-switch"
        }
    }
}

// MARK: - Layout Mode

enum LayoutMode: String, CaseIterable, Identifiable {
    case pip = "PiP"
    case splitHorizontal = "Split H"
    case splitVertical = "Split V"
    case reaction = "Reaction"
    case interview = "Interview"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .pip: return "pip"
        case .splitHorizontal: return "rectangle.split.2x1"
        case .splitVertical: return "rectangle.split.1x2"
        case .reaction: return "person.crop.rectangle"
        case .interview: return "person.2"
        }
    }
}

// MARK: - PiP Shape

enum PiPShape: String, CaseIterable, Identifiable {
    case rectangle = "Rectangle"
    case square = "Square"
    case circle = "Circle"
    case pill = "Pill"
    case horizontalPill = "H-Pill"

    var id: String { rawValue }

    /// Whether this shape requires a square aspect ratio PiP frame.
    var requiresSquareFrame: Bool {
        self == .square || self == .circle
    }
}

// MARK: - PiP Corner Position

enum PiPPosition: String, CaseIterable, Identifiable {
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"

    var id: String { rawValue }
}

// MARK: - Duration Limit

enum DurationLimit: Int, CaseIterable, Identifiable {
    case none = 0
    case fifteen = 15
    case thirty = 30
    case sixty = 60
    case threeMinutes = 180

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .none: return "∞"
        case .fifteen: return "15s"
        case .thirty: return "30s"
        case .sixty: return "60s"
        case .threeMinutes: return "3m"
        }
    }
}

// MARK: - Video Quality

enum VideoQuality: String, CaseIterable, Identifiable {
    case hd720 = "720p"
    case hd1080 = "1080p"

    var id: String { rawValue }

    // Portrait dimensions (phone is held upright)
    var width: Int {
        switch self {
        case .hd720: return 720
        case .hd1080: return 1080
        }
    }

    var height: Int {
        switch self {
        case .hd720: return 1280
        case .hd1080: return 1920
        }
    }
}

// MARK: - Stabilization Mode

enum StabilizationLevel: String, CaseIterable, Identifiable {
    case off = "Off"
    case standard = "Standard"
    case cinematic = "Cinematic"

    var id: String { rawValue }

    var avMode: AVCaptureVideoStabilizationMode {
        switch self {
        case .off: return .off
        case .standard: return .standard
        case .cinematic: return .cinematic
        }
    }

    var icon: String {
        switch self {
        case .off: return "hand.raised.slash"
        case .standard: return "hand.raised"
        case .cinematic: return "film"
        }
    }
}

// MARK: - Lens Type

enum LensType: String, CaseIterable, Identifiable {
    case ultraWide = "0.5x"
    case wide = "1x"
    case telephoto = "2x"

    var id: String { rawValue }

    var deviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .ultraWide: return .builtInUltraWideCamera
        case .wide: return .builtInWideAngleCamera
        case .telephoto: return .builtInTelephotoCamera
        }
    }
}

// MARK: - Thermal State

enum ThermalWarning {
    case normal
    case elevated
    case critical

    var message: String? {
        switch self {
        case .normal: return nil
        case .elevated: return "Device warming up. Performance may be reduced."
        case .critical: return "Device overheating! Recording quality reduced."
        }
    }
}
