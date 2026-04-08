import CapacitorFFmpegNativeCore
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

extension CResult {
    /// Extract error message as Swift String if available
    var errorString: String? {
        guard ok == false, let errorPtr = error_message else { return nil }
        return String(cString: errorPtr)
    }

    /// Convert to Swift Result type
    func toSwiftResult() -> Result<Void, FFmpegError> {
        if ok != false {
            return .success(())
        } else {
            let errorMsg = errorString ?? "Unknown error"
            return .failure(.reencodingFailed(errorMsg))
        }
    }
}

typealias FFmpegProgressCallback = @convention(c) (Double, UnsafeMutableRawPointer?) -> Int32

protocol FFmpegNativeBinding {
    func initPlugin() -> UnsafeMutableRawPointer?
    func deinitPlugin(_ plugin: UnsafeMutableRawPointer)
    func freeResult(_ rawResult: UnsafeMutablePointer<CResult>)
    func reencodeVideo(
        plugin: UnsafeMutableRawPointer,
        inputPath: UnsafePointer<CChar>,
        outputPath: UnsafePointer<CChar>,
        targetWidth: Int32,
        targetHeight: Int32,
        bitrate: Int32,
        statePointer: UnsafeMutableRawPointer?,
        progressCallback: @escaping FFmpegProgressCallback
    ) -> UnsafeMutablePointer<CResult>?
}

private struct LinkedFFmpegNativeBindings: FFmpegNativeBinding {
    func initPlugin() -> UnsafeMutableRawPointer? {
        init_ffmpeg_plugin()
    }

    func deinitPlugin(_ plugin: UnsafeMutableRawPointer) {
        deinit_ffmpeg_plugin(plugin)
    }

    func freeResult(_ rawResult: UnsafeMutablePointer<CResult>) {
        free_c_result(rawResult)
    }

    func reencodeVideo(
        plugin: UnsafeMutableRawPointer,
        inputPath: UnsafePointer<CChar>,
        outputPath: UnsafePointer<CChar>,
        targetWidth: Int32,
        targetHeight: Int32,
        bitrate: Int32,
        statePointer: UnsafeMutableRawPointer?,
        progressCallback: @escaping FFmpegProgressCallback
    ) -> UnsafeMutablePointer<CResult>? {
        reencode_video(
            plugin,
            inputPath,
            outputPath,
            targetWidth,
            targetHeight,
            bitrate,
            statePointer,
            progressCallback
        )
    }
}

struct FFmpegAcceptedJob {
    let jobId: String
    let status: String = "queued"

    var asDictionary: [String: Any] {
        [
            "jobId": jobId,
            "status": status
        ]
    }
}

struct FFmpegConvertedImage {
    let outputPath: String
    let format: String

    var asDictionary: [String: Any] {
        [
            "outputPath": outputPath,
            "format": format
        ]
    }
}

struct FFmpegCapabilityPayload {
    let status: String
    let reason: String?

    var asDictionary: [String: Any] {
        var payload: [String: Any] = [
            "status": status
        ]

        if let reason {
            payload["reason"] = reason
        }

        return payload
    }
}

struct FFmpegCapabilitiesPayload {
    let platform: String
    let features: [String: FFmpegCapabilityPayload]

    var asDictionary: [String: Any] {
        [
            "platform": platform,
            "features": features.mapValues(\.asDictionary)
        ]
    }

    static func iosCurrent(nativeCoreAvailable: Bool, nativeCoreReason: String?) -> Self {
        FFmpegCapabilitiesPayload(
            platform: "ios",
            features: [
                "getPluginVersion": FFmpegCapabilityPayload(status: "available", reason: nil),
                "getCapabilities": FFmpegCapabilityPayload(status: "available", reason: nil),
                "reencodeVideo": FFmpegCapabilityPayload(
                    status: nativeCoreAvailable ? "experimental" : "unavailable",
                    reason: nativeCoreAvailable
                        ? "Rust-backed H.264 video re-encode with copied non-video streams."
                        : nativeCoreReason
                ),
                "convertImage": FFmpegCapabilityPayload(
                    status: "available",
                    reason: "Still-image conversion is available on iOS for jpeg and png outputs."
                ),
                "progressEvents": FFmpegCapabilityPayload(
                    status: nativeCoreAvailable ? "available" : "unavailable",
                    reason: nativeCoreAvailable
                        ? "Progress events are emitted for accepted reencode jobs."
                        : nativeCoreReason
                ),
                "probeMedia": FFmpegCapabilityPayload(
                    status: "unimplemented",
                    reason: "probeMedia is planned but not implemented on iOS yet."
                ),
                "generateThumbnail": FFmpegCapabilityPayload(
                    status: "unimplemented",
                    reason: "generateThumbnail is planned but not implemented on iOS yet."
                ),
                "extractAudio": FFmpegCapabilityPayload(
                    status: "unimplemented",
                    reason: "extractAudio is planned but not implemented on iOS yet."
                ),
                "remux": FFmpegCapabilityPayload(
                    status: "unimplemented",
                    reason: "remux is planned but not implemented on iOS yet."
                ),
                "trim": FFmpegCapabilityPayload(
                    status: "unimplemented",
                    reason: "trim is planned but not implemented on iOS yet."
                )
            ]
        )
    }
}

struct FFmpegProgressPayload {
    let jobId: String
    let progress: Double
    let state: String
    let message: String?
    let outputPath: String?

    var asDictionary: [String: Any] {
        var payload: [String: Any] = [
            "jobId": jobId,
            "progress": progress,
            "state": state,
            // Keep the legacy key while callers migrate to `jobId`.
            "fileId": jobId
        ]

        if let message {
            payload["message"] = message
        }

        if let outputPath {
            payload["outputPath"] = outputPath
        }

        return payload
    }
}

private final class SelfForReencodeVideo {
    let jobId: String
    let outputPath: String
    let onProgress: ((FFmpegProgressPayload) -> Void)?

    init(jobId: String, outputPath: String, onProgress: ((FFmpegProgressPayload) -> Void)?) {
        self.jobId = jobId
        self.outputPath = outputPath
        self.onProgress = onProgress
    }

    func emit(progress: Double, state: String, message: String? = nil, outputPath: String? = nil) {
        let payload = FFmpegProgressPayload(
            jobId: jobId,
            progress: progress,
            state: state,
            message: message,
            outputPath: outputPath
        )

        DispatchQueue.main.async {
            self.onProgress?(payload)
        }
    }
}

@objc public class CapacitorFFmpeg: NSObject {
    var pointerToRustPlugin: UnsafeMutableRawPointer?
    private let nativeBindings: any FFmpegNativeBinding
    private let nativeCoreReason: String?

    /// Progress callback closure that can be set from outside
    var onProgress: ((FFmpegProgressPayload) -> Void)?

    public override convenience init() {
        self.init(nativeBindings: LinkedFFmpegNativeBindings())
    }

    init(nativeBindings: any FFmpegNativeBinding) {
        self.nativeBindings = nativeBindings
        let resolvedPlugin = nativeBindings.initPlugin()
        self.pointerToRustPlugin = resolvedPlugin
        self.nativeCoreReason = resolvedPlugin == nil ? "The native FFmpeg core could not be initialized." : nil

        super.init()

        if resolvedPlugin == nil {
            print("Failed to initialize plugin")
        }
    }

    deinit {
        if let plugin = self.pointerToRustPlugin {
            nativeBindings.deinitPlugin(plugin)
        }
    }

    private func resolveFileURL(from rawPath: String) throws -> URL {
        let trimmedPath = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedPath.isEmpty == false else {
            throw FFmpegError.invalidArgument("A file path is required.")
        }

        if let url = URL(string: trimmedPath), url.isFileURL {
            return url
        }

        return URL(fileURLWithPath: trimmedPath)
    }

    private func resolveFilesystemPath(from rawPath: String) throws -> String {
        try resolveFileURL(from: rawPath).path
    }

    private func resolveDestinationType(for format: String) throws -> CFString {
        switch format.lowercased() {
        case "webp":
            throw FFmpegError.invalidArgument("webp output is not supported on iOS yet. Use jpeg or png.")
        case "jpeg", "jpg":
            return UTType.jpeg.identifier as CFString
        case "png":
            return UTType.png.identifier as CFString
        default:
            throw FFmpegError.invalidArgument("Unsupported image format: \(format)")
        }
    }

    private func resolveQuality(_ quality: Double?) throws -> Double? {
        guard let quality else {
            return nil
        }

        guard quality >= 0.0, quality <= 1.0 else {
            throw FFmpegError.invalidArgument("Image quality must be between 0.0 and 1.0.")
        }

        return quality
    }

    public func reencodeVideo(
        inputPath: String,
        outputPath: String,
        width: Int32,
        height: Int32,
        bitrate: Int32? = nil
    ) throws -> String {
        guard let plugin = self.pointerToRustPlugin else {
            throw FFmpegError.pluginNotInitialized
        }

        guard width > 0 else {
            throw FFmpegError.invalidArgument("Width must be greater than 0.")
        }
        guard height > 0 else {
            throw FFmpegError.invalidArgument("Height must be greater than 0.")
        }

        let bitrateValue = bitrate ?? 0
        guard bitrateValue >= 0 else {
            throw FFmpegError.invalidArgument("Bitrate must be greater than or equal to 0.")
        }

        let inputURL = try resolveFileURL(from: inputPath).standardizedFileURL
        let outputURL = try resolveFileURL(from: outputPath).standardizedFileURL
        guard inputURL.path != outputURL.path else {
            throw FFmpegError.invalidArgument("In-place conversion is not allowed. Choose a different output path.")
        }

        let resolvedInputPath = inputURL.path
        let resolvedOutputPath = outputURL.path
        let acceptedJob = FFmpegAcceptedJob(jobId: UUID().uuidString)
        let encodingState = SelfForReencodeVideo(
            jobId: acceptedJob.jobId,
            outputPath: outputPath,
            onProgress: self.onProgress
        )

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let statePointer = Unmanaged.passRetained(encodingState).toOpaque()

            let progressCallback: FFmpegProgressCallback = { progress, selfPointer in
                guard let selfPointer else {
                    return -1
                }

                let state = Unmanaged<SelfForReencodeVideo>.fromOpaque(selfPointer).takeUnretainedValue()
                state.emit(
                    progress: min(max(progress, 0.0), 0.99),
                    state: "running",
                    message: "Re-encoding video...",
                    outputPath: state.outputPath
                )
                return 0
            }

            let resultPtr = resolvedInputPath.withCString { inputCStr in
                resolvedOutputPath.withCString { outputCStr in
                    self.nativeBindings.reencodeVideo(
                        plugin: plugin,
                        inputPath: inputCStr,
                        outputPath: outputCStr,
                        targetWidth: width,
                        targetHeight: height,
                        bitrate: bitrateValue,
                        statePointer: statePointer,
                        progressCallback: progressCallback
                    )
                }
            }

            guard let resultPtr else {
                let state = Unmanaged<SelfForReencodeVideo>.fromOpaque(statePointer).takeRetainedValue()
                state.emit(
                    progress: 0.0,
                    state: "failed",
                    message: "The native FFmpeg core returned no result."
                )
                return
            }

            let state = Unmanaged<SelfForReencodeVideo>.fromOpaque(statePointer).takeRetainedValue()
            let result = resultPtr.pointee

            if result.ok != false {
                state.emit(
                    progress: 1.0,
                    state: "completed",
                    message: "Re-encoding completed.",
                    outputPath: state.outputPath
                )
            } else {
                state.emit(
                    progress: 0.0,
                    state: "failed",
                    message: result.errorString ?? "Unknown error"
                )
            }

            self.nativeBindings.freeResult(resultPtr)
        }

        return acceptedJob.jobId
    }

    func convertImage(
        inputPath: String,
        outputPath: String,
        format: String,
        quality: Double? = nil
    ) throws -> FFmpegConvertedImage {
        let inputURL = try resolveFileURL(from: inputPath).standardizedFileURL
        let outputURL = try resolveFileURL(from: outputPath).standardizedFileURL
        let destinationType = try resolveDestinationType(for: format)
        let normalizedQuality = try resolveQuality(quality)

        guard inputURL.path != outputURL.path else {
            throw FFmpegError.invalidArgument("In-place conversion is not allowed. Choose a different output path.")
        }

        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil) else {
            throw FFmpegError.invalidPath(inputPath)
        }
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw FFmpegError.reencodingFailed("Could not decode the input image.")
        }

        let outputDirectory = outputURL.deletingLastPathComponent()
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        let temporaryOutputURL = outputDirectory
            .appendingPathComponent(".ffmpeg-convert-\(UUID().uuidString)")
            .appendingPathExtension(outputURL.pathExtension.isEmpty ? "tmp" : outputURL.pathExtension)
        defer {
            try? fileManager.removeItem(at: temporaryOutputURL)
        }

        guard let destination = CGImageDestinationCreateWithURL(temporaryOutputURL as CFURL, destinationType, 1, nil) else {
            throw FFmpegError.reencodingFailed("Could not create the output image container.")
        }

        var properties: [CFString: Any] = [:]
        if let normalizedQuality, format.lowercased() != "png" {
            properties[kCGImageDestinationLossyCompressionQuality] = normalizedQuality
        }

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw FFmpegError.reencodingFailed("The converted image could not be finalized.")
        }

        if fileManager.fileExists(atPath: outputURL.path) {
            _ = try fileManager.replaceItemAt(outputURL, withItemAt: temporaryOutputURL)
        } else {
            try fileManager.moveItem(at: temporaryOutputURL, to: outputURL)
        }

        return FFmpegConvertedImage(
            outputPath: outputURL.absoluteString,
            format: format.lowercased() == "jpg" ? "jpeg" : format.lowercased()
        )
    }

    func getCapabilities() -> FFmpegCapabilitiesPayload {
        FFmpegCapabilitiesPayload.iosCurrent(
            nativeCoreAvailable: pointerToRustPlugin != nil,
            nativeCoreReason: nativeCoreReason
        )
    }
}

// MARK: - Error Types
public enum FFmpegError: LocalizedError {
    case pluginNotInitialized
    case reencodingFailed(String)
    case invalidPath(String)
    case invalidArgument(String)

    var code: String {
        switch self {
        case .pluginNotInitialized:
            return "PLUGIN_NOT_INITIALIZED"
        case .reencodingFailed:
            return "TRANSCODE_FAILED"
        case .invalidPath, .invalidArgument:
            return "INVALID_ARGUMENT"
        }
    }

    public var errorDescription: String? {
        switch self {
        case .pluginNotInitialized:
            return "FFmpeg plugin was not properly initialized"
        case .reencodingFailed(let message):
            return "Video re-encoding failed: \(message)"
        case .invalidPath(let path):
            return "Invalid file path: \(path)"
        case .invalidArgument(let message):
            return message
        }
    }
}
