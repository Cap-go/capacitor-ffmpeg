import Foundation
import BackgroundTasks

/// Initializes the FFmpeg plugin
/// - Parameter informAboutProgress: Callback function for progress updates
/// - Returns: A pointer to the initialized plugin instance, or nil if initialization fails
@_silgen_name("init_ffmpeg_plugin")
func init_ffmpeg_plugin(_ informAboutProgress: @escaping @convention(c) (Double, UnsafePointer<CChar>) -> Int32) -> UnsafeMutableRawPointer?

/// Deinitializes the FFmpeg plugin and frees associated resources
/// - Parameter plugin: A valid pointer to the plugin instance obtained from init_ffmpeg_plugin
@_silgen_name("deinit_ffmpeg_plugin")
func deinit_ffmpeg_plugin(_ plugin: UnsafeMutableRawPointer) -> Void

/// Re-encode a video file to a lower resolution
/// - Parameters:
///   - plugin: A valid pointer to the plugin instance
///   - inputPath: Path to the input video file (C string)
///   - outputPath: Path to the output video file (C string)
///   - targetWidth: Target width for the output video
///   - targetHeight: Target height for the output video
///   - bitrate: Target bitrate in bits per second (0 or negative for default)
/// - Returns: 0 on success, -1 on error
@_silgen_name("reencode_video")
func reencode_video(_ plugin: UnsafeMutableRawPointer, _ inputPath: UnsafePointer<CChar>, _ outputPath: UnsafePointer<CChar>, _ targetWidth: Int32, _ targetHeight: Int32, _ bitrate: Int32) -> Int32

@available(iOS 26.0, *)
@objc public class CapacitorFFmpeg: NSObject {
    
    var pointerToRustPlugin: UnsafeMutableRawPointer? = nil
    
    private static var lastSeenProgress = 0 as Double;
    
    /// Progress callback closure that can be set from outside
    public var onProgress: ((Double, String) -> Void)?
    
    /// Store the C callback to prevent deallocation
    private var progressCallback: (@convention(c) (Double, UnsafePointer<CChar>) -> Int32)?
    
    private var longEncodeTask: BGContinuedProcessingTaskRequest = BGContinuedProcessingTaskRequest(
        identifier: "ee.forgr.capacitor-ffmpeg.example-app.ffmpeg-reencode",
        title: "A video export",
        subtitle: "About to start...",
    )
    
    override init() {
        super.init()
        
        // Create the C callback function and store it as instance variable
        self.progressCallback = { progress, fileIdPtr in
            // Convert C string to Swift string
            let fileId = String(cString: fileIdPtr)
            
            // Call the Swift progress handler if available
            // Note: We need to capture self, but we can't in a C function
            // So we'll handle this differently - store a static reference
            CapacitorFFmpeg.handleProgress(progress: progress, fileId: fileId)
            
            CapacitorFFmpeg.lastSeenProgress = progress;
            
            return 0 // Success
        }
        
        guard let callback = self.progressCallback,
              let plugin = init_ffmpeg_plugin(callback) else {
            print("Failed to initialize plugin")
            return
        }
        self.pointerToRustPlugin = plugin
        
        // Store reference for the callback
        CapacitorFFmpeg.activeInstance = self
    }
    
    // Static reference to handle callback since C callbacks can't capture self
    private static var activeInstance: CapacitorFFmpeg?
    
    private static func handleProgress(progress: Double, fileId: String) {
        DispatchQueue.main.async {
            activeInstance?.onProgress?(progress, fileId)
        }
    }
    
    deinit {
        // Clear static reference
        CapacitorFFmpeg.activeInstance = nil
        
        // Clear the callback reference
        self.progressCallback = nil
        
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
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: self.longEncodeTask.identifier, using: nil) { task in
            guard let task = task as? BGContinuedProcessingTask else { return }
            
            // Convert Swift strings to C strings
            let result = inputPath.withCString { inputCStr in
                outputPath.withCString { outputCStr in
                    reencode_video(plugin, inputCStr, outputCStr, width, height, bitrateValue)
                }
            }
            
            // Check the result
            if result != 0 {
                print("FFmpeg re-encoding failed with code")
                // throw FFmpegError.reencodingFailed("FFmpeg re-encoding failed with code: \(result)")
            }
            
            while (true) {
                usleep(50000) //will sleep for 1 second
                task.progress.completedUnitCount = Int64(CapacitorFFmpeg.lastSeenProgress * 100)
                if (CapacitorFFmpeg.lastSeenProgress > 0.99) {
                    print("lastSeenProgress \(CapacitorFFmpeg.lastSeenProgress)")
                    task.setTaskCompleted(success: true)
                }
            }
        }
        
        try BGTaskScheduler.shared.submit(self.longEncodeTask)
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
