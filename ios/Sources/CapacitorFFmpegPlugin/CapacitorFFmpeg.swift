import Foundation
import BackgroundTasks

/// C-compatible result structure matching Rust's CResult
/// Must match the exact layout of the Rust #[repr(C)] struct
@frozen
public struct CResult {
    let ok: CBool  // C-compatible boolean (same as Rust bool)
    let error_message: UnsafeMutablePointer<CChar>?  // Exact same field name as Rust
}

extension CResult {
    /// Extract error message as Swift String if available
    var errorString: String? {
        guard ok == false, let errorPtr = error_message else { return nil }
        return String(cString: errorPtr)
    }

    /// Convert to Swift Result type
    func toSwiftResult() -> Result<Void, FFmpegError> {
        if ok != false {  // Using != false instead of == true for CBool safety
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

// MARK: - Encoding State Management
/// Holds the state for a single video re-encoding operation
@available(iOS 26.0, *)
private class SelfForReencodeVideo {
    let task: BGContinuedProcessingTask
    let onProgress: ((Double, String) -> Void)?

    init(task: BGContinuedProcessingTask, onProgress: ((Double, String) -> Void)?) {
        self.task = task
        self.onProgress = onProgress
    }
}

@available(iOS 26.0, *)
@objc public class CapacitorFFmpeg: NSObject {

    var pointerToRustPlugin: UnsafeMutableRawPointer?

    /// Progress callback closure that can be set from outside
    public var onProgress: ((Double, String) -> Void)?

    override init() {
        super.init()

        guard let plugin = init_ffmpeg_plugin() else {
            print("Failed to initialize plugin")
            return
        }
        self.pointerToRustPlugin = plugin
    }

    deinit {
        // We have to deinit the Rust managed memory
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
    ) throws {
        guard let plugin = self.pointerToRustPlugin else {
            throw FFmpegError.pluginNotInitialized
        }

        // Use provided bitrate or 0 for default
        let bitrateValue = bitrate ?? 0

        // Create the task
        let longEncodeTask = BGContinuedProcessingTaskRequest(
            identifier: "ee.forgr.capacitor-ffmpeg.example-app.ffmpeg-reencode",
            title: "A video export",
            subtitle: "About to start..."
        )

        BGTaskScheduler.shared.register(forTaskWithIdentifier: longEncodeTask.identifier, using: nil) { task in
            guard let task = task as? BGContinuedProcessingTask else { return }

            // Create the encoding state on the heap
            let selfForReencode = SelfForReencodeVideo(
                task: task,
                onProgress: self.onProgress
            )

            task.progress.totalUnitCount = 100
            task.progress.completedUnitCount = 0

            // Convert to unmanaged pointer to keep it alive during encoding
            let selfPtr = Unmanaged.passRetained(selfForReencode).toOpaque()

            // Progress callback that uses the selfPtr
            let progressCallback: @convention(c) (Double, UnsafeMutableRawPointer?) -> Int32 = { progress, selfPointer in
                guard let selfPointer = selfPointer else { return -1 }

                let selfForReencode = Unmanaged<SelfForReencodeVideo>.fromOpaque(selfPointer).takeUnretainedValue()

                // Update task progress
                selfForReencode.task.progress.completedUnitCount = Int64(progress * 100)

                // Call Swift progress callback on main queue
                DispatchQueue.main.async {
                    selfForReencode.onProgress?(progress, "Re-encoding video...")
                }

                // Check if encoding is complete
                if progress > 0.99 {
                    print("Encoding completed with progress: \(progress)")
                    selfForReencode.task.setTaskCompleted(success: true)
                }

                return 0 // Success
            }

            // Convert Swift strings to C strings and call Rust
            let resultPtr = inputPath.withCString { inputCStr in
                outputPath.withCString { outputCStr in
                    reencode_video(
                        plugin,
                        inputCStr,
                        outputCStr,
                        width,
                        height,
                        bitrateValue,
                        selfPtr,
                        progressCallback
                    )
                }
            }

            // Release the retained reference
            Unmanaged<SelfForReencodeVideo>.fromOpaque(selfPtr).release()

            // Check the result
            let result = resultPtr.pointee

            if result.ok != false {
                print("FFmpeg re-encoding completed successfully")
                selfForReencode.task.setTaskCompleted(success: true)
            } else {
                let errorMessage = result.errorString ?? "Unknown error"

                print("FFmpeg re-encoding failed: \(errorMessage)")
                selfForReencode.task.setTaskCompleted(success: false)

                // Optionally call error callback on main queue
                DispatchQueue.main.async {
                    selfForReencode.onProgress?(0.0, "Error: \(errorMessage)")
                }
            }

            // Always free the result structure
            free_c_result(resultPtr)
        }

        try BGTaskScheduler.shared.submit(longEncodeTask)
    }
}

// MARK: - Error Types
public enum FFmpegError: LocalizedError {
    case pluginNotInitialized
    case reencodingFailed(String)
    case invalidPath(String)

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
