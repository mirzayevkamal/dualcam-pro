import Photos
import AVFoundation
import UIKit

/// Handles background video export, saving to Photos, and draft management.
final class ExportManager: @unchecked Sendable {

    static let shared = ExportManager()
    private init() {}

    // MARK: - Save to Photos Library

    func saveToPhotoLibrary(url: URL) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }

    // MARK: - Export with Progress

    func exportComposite(
        from url: URL,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        let asset = AVURLAsset(url: url)

        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw ExportError.cannotCreateSession
        }

        let outputURL = makeFinalOutputURL()
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        try await exportSession.export(to: outputURL, as: .mp4)
        progress(1.0)
        return outputURL
    }

    // MARK: - Draft Management

    func saveDraft(url: URL) -> URL? {
        let draftsDir = draftsDirectory()
        let dest = draftsDir.appendingPathComponent(url.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: url, to: dest)
            return dest
        } catch {
            print("Draft save error: \(error)")
            return nil
        }
    }

    func listDrafts() -> [URL] {
        let dir = draftsDirectory()
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)) ?? []
        return files.sorted { a, b in
            let aDate = (try? a.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            let bDate = (try? b.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            return aDate > bDate
        }
    }

    func deleteDraft(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Share

    func shareVideo(url: URL, from viewController: UIViewController) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        viewController.present(activityVC, animated: true)
    }

    // MARK: - Helpers

    private func makeFinalOutputURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let name = "DualCamPro_\(formatter.string(from: Date())).mp4"
        let url = docs.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
        return url
    }

    private func draftsDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let drafts = docs.appendingPathComponent("Drafts")
        if !FileManager.default.fileExists(atPath: drafts.path) {
            try? FileManager.default.createDirectory(at: drafts, withIntermediateDirectories: true)
        }
        return drafts
    }
}

// MARK: - Errors

enum ExportError: LocalizedError {
    case cannotCreateSession
    case unknownFailure
    case cancelled

    var errorDescription: String? {
        switch self {
        case .cannotCreateSession: return "Cannot create export session"
        case .unknownFailure: return "Export failed"
        case .cancelled: return "Export was cancelled"
        }
    }
}
