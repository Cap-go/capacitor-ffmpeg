import Foundation
@testable import CapacitorFFmpegPlugin

@_cdecl("init_ffmpeg_plugin")
func initFFmpegPluginShim() -> UnsafeMutableRawPointer? {
    UnsafeMutableRawPointer(bitPattern: 0x1)
}

@_cdecl("deinit_ffmpeg_plugin")
func deinitFFmpegPluginShim(_ plugin: UnsafeMutableRawPointer?) {
    _ = plugin
}

@_cdecl("free_c_result")
func freeCResultShim(_ rawResult: UnsafeMutableRawPointer?) {
    guard let rawResult else { return }

    let result = rawResult.assumingMemoryBound(to: CResult.self)
    if let errorPointer = result.pointee.error_message {
        free(errorPointer)
    }

    result.deinitialize(count: 1)
    result.deallocate()
}

// swiftlint:disable function_parameter_count
@_cdecl("reencode_video")
func reencodeVideoShim(
    _ plugin: UnsafeMutableRawPointer?,
    _ inputPath: UnsafePointer<CChar>?,
    _ outputPath: UnsafePointer<CChar>?,
    _ targetWidth: Int32,
    _ targetHeight: Int32,
    _ bitrate: Int32,
    _ swiftInternalDataStructurePointer: UnsafeMutableRawPointer?,
    _ informAboutProgress: @escaping @convention(c) (Double, UnsafeMutableRawPointer?) -> Int32
) -> UnsafeMutableRawPointer? {
    _ = plugin
    _ = inputPath
    _ = outputPath
    _ = targetWidth
    _ = targetHeight
    _ = bitrate

    let result = UnsafeMutablePointer<CResult>.allocate(capacity: 1)
    result.initialize(to: CResult(ok: true, error_message: nil))
    _ = informAboutProgress(1.0, swiftInternalDataStructurePointer)
    return UnsafeMutableRawPointer(result)
}
// swiftlint:enable function_parameter_count
