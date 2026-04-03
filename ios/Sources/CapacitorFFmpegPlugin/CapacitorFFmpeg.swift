import Foundation

// swiftlint:disable identifier_name
/// C-compatible result structure matching Rust's CResult
/// Must match the exact layout of the Rust #[repr(C)] struct
@frozen
public struct CResult {
    let ok: CBool
    let error_message: UnsafeMutablePointer<CChar>?
}
// swiftlint:enable identifier_name

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

/// Initializes the FFmpeg plugin
/// - Returns: A pointer to the initialized plugin instance, or nil if initialization fails
@_silgen_name("init_ffmpeg_plugin")
func init_ffmpeg_plugin() -> UnsafeMutableRawPointer?

/// Deinitializes the FFmpeg plugin and frees associated resources
/// - Parameter plugin: A valid pointer to the plugin instance obtained from init_ffmpeg_plugin
@_silgen_name("deinit_ffmpeg_plugin")
func deinit_ffmpeg_plugin(_ plugin: UnsafeMutableRawPointer)

/// Free the CResult structure and associated error message
/// This must be called when done with a CResult from reencode_video
@_silgen_name("free_c_result")
func free_c_result(_ result: UnsafeMutablePointer<CResult>)

// swiftlint:disable function_parameter_count
/// Re-encode a video file to a lower resolution
/// - Parameters:
///   - plugin: A valid pointer to the plugin instance
///   - inputPath: Path to the input video file (C string)
///   - outputPath: Path to the output video file (C string)
///   - targetWidth: Target width for the output video
///   - targetHeight: Target height for the output video
///   - bitrate: Target bitrate in bits per second (0 or negative for default)
///   - swiftInternalDataStructurePointer: Pointer to Swift data structure for callbacks
///   - informAboutProgress: Callback function for progress updates
/// - Returns: Pointer to CResult structure - caller must call free_c_result() when done
@_silgen_name("reencode_video")
func reencode_video(
    _ plugin: UnsafeMutableRawPointer,
    _ inputPath: UnsafePointer<CChar>,
    _ outputPath: UnsafePointer<CChar>,
    _ targetWidth: Int32,
    _ targetHeight: Int32,
    _ bitrate: Int32,
    _ swiftInternalDataStructurePointer: UnsafeMutableRawPointer?,
    _ informAboutProgress: @escaping @convention(c) (Double, UnsafeMutableRawPointer?) -> Int32
) -> UnsafeMutablePointer<CResult>
// swiftlint:enable function_parameter_count

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

    static var iosCurrent: Self {
        FFmpegCapabilitiesPayload(
            platform: "ios",
            features: [
                "getPluginVersion": FFmpegCapabilityPayload(status: "available", reason: nil),
                "getCapabilities": FFmpegCapabilityPayload(status: "available", reason: nil),
                "reencodeVideo": FFmpegCapabilityPayload(
                    status: "experimental",
                    reason: "Rust-backed H.264 video re-encode with copied non-video streams."
                ),
                "progressEvents": FFmpegCapabilityPayload(
                    status: "available",
                    reason: "Progress events are emitted for accepted reencode jobs."
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

    /// Progress callback closure that can be set from outside
    var onProgress: ((FFmpegProgressPayload) -> Void)?

    override init() {
        super.init()

        guard let plugin = init_ffmpeg_plugin() else {
            print("Failed to initialize plugin")
            return
        }
        self.pointerToRustPlugin = plugin
    }

    deinit {
        if let plugin = self.pointerToRustPlugin {
            deinit_ffmpeg_plugin(plugin)
        }
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

        let bitrateValue = bitrate ?? 0
        let acceptedJob = FFmpegAcceptedJob(jobId: UUID().uuidString)
        let encodingState = SelfForReencodeVideo(
            jobId: acceptedJob.jobId,
            outputPath: outputPath,
            onProgress: self.onProgress
        )

        DispatchQueue.global(qos: .userInitiated).async {
            let statePointer = Unmanaged.passRetained(encodingState).toOpaque()

            let progressCallback: @convention(c) (Double, UnsafeMutableRawPointer?) -> Int32 = { progress, selfPointer in
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

            let resultPtr = inputPath.withCString { inputCStr in
                outputPath.withCString { outputCStr in
                    reencode_video(
                        plugin,
                        inputCStr,
                        outputCStr,
                        width,
                        height,
                        bitrateValue,
                        statePointer,
                        progressCallback
                    )
                }
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

            free_c_result(resultPtr)
        }

        return acceptedJob.jobId
    }

    func getCapabilities() -> FFmpegCapabilitiesPayload {
        FFmpegCapabilitiesPayload.iosCurrent
    }
}

// MARK: - Error Types
public enum FFmpegError: LocalizedError {
    case pluginNotInitialized
    case reencodingFailed(String)
    case invalidPath(String)

    var code: String {
        switch self {
        case .pluginNotInitialized:
            return "PLUGIN_NOT_INITIALIZED"
        case .reencodingFailed:
            return "TRANSCODE_FAILED"
        case .invalidPath:
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
        }
    }
}
