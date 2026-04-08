import CapacitorFFmpegNativeCore
import Darwin
import UIKit
import XCTest
@testable import CapacitorFFmpegPlugin

private struct FailingFFmpegNativeBindings: FFmpegNativeBinding {
    func initPlugin() -> UnsafeMutableRawPointer? {
        nil
    }

    func deinitPlugin(_ plugin: UnsafeMutableRawPointer) {
        _ = plugin
    }

    func freeResult(_ rawResult: UnsafeMutablePointer<CResult>) {
        _ = rawResult
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
        _ = plugin
        _ = inputPath
        _ = outputPath
        _ = targetWidth
        _ = targetHeight
        _ = bitrate
        _ = statePointer
        _ = progressCallback
        return nil
    }
}

final class CapacitorFFmpegPluginTests: XCTestCase {
    func testCapabilitiesPayloadDescribesTheCurrentIosScope() {
        let payload = CapacitorFFmpeg().getCapabilities().asDictionary
        let features = payload["features"] as? [String: [String: Any]]

        XCTAssertEqual(payload["platform"] as? String, "ios")
        XCTAssertEqual(features?["getCapabilities"]?["status"] as? String, "available")
        XCTAssertEqual(features?["reencodeVideo"]?["status"] as? String, "experimental")
        XCTAssertEqual(features?["convertImage"]?["status"] as? String, "available")
    }

    func testCapabilitiesPayloadExplainsNativeCoreInitializationFailure() {
        let payload = CapacitorFFmpeg(nativeBindings: FailingFFmpegNativeBindings()).getCapabilities().asDictionary
        let features = payload["features"] as? [String: [String: Any]]

        XCTAssertEqual(features?["reencodeVideo"]?["status"] as? String, "unavailable")
        XCTAssertEqual(
            features?["reencodeVideo"]?["reason"] as? String,
            "The native FFmpeg core could not be initialized."
        )
    }

    func testAcceptedJobDictionaryUsesQueuedStatus() {
        let acceptedJob = FFmpegAcceptedJob(jobId: "job-123")

        XCTAssertEqual(acceptedJob.asDictionary["jobId"] as? String, "job-123")
        XCTAssertEqual(acceptedJob.asDictionary["status"] as? String, "queued")
    }

    func testProgressPayloadKeepsStructuredAndLegacyKeysAligned() {
        let payload = FFmpegProgressPayload(
            jobId: "job-123",
            progress: 0.5,
            state: "running",
            message: "Re-encoding video...",
            outputPath: "file:///output.mp4"
        )

        XCTAssertEqual(payload.asDictionary["jobId"] as? String, "job-123")
        XCTAssertEqual(payload.asDictionary["fileId"] as? String, "job-123")
        XCTAssertEqual(payload.asDictionary["progress"] as? Double, 0.5)
        XCTAssertEqual(payload.asDictionary["state"] as? String, "running")
        XCTAssertEqual(payload.asDictionary["message"] as? String, "Re-encoding video...")
        XCTAssertEqual(payload.asDictionary["outputPath"] as? String, "file:///output.mp4")
    }

    func testPluginNotInitializedErrorDescription() {
        XCTAssertEqual(
            FFmpegError.pluginNotInitialized.errorDescription,
            "FFmpeg plugin was not properly initialized"
        )
    }

    func testPluginNotInitializedErrorCodeMatchesContract() {
        XCTAssertEqual(FFmpegError.pluginNotInitialized.code, "PLUGIN_NOT_INITIALIZED")
    }

    func testReencodeThrowsWhenNativeCoreInitializationFails() {
        XCTAssertThrowsError(
            try CapacitorFFmpeg(nativeBindings: FailingFFmpegNativeBindings()).reencodeVideo(
                inputPath: "/tmp/input.mp4",
                outputPath: "/tmp/output.mp4",
                width: 320,
                height: 240
            )
        ) { error in
            XCTAssertEqual((error as? FFmpegError)?.code, "PLUGIN_NOT_INITIALIZED")
        }
    }

    func testSuccessResultConvertsToSwiftSuccess() {
        let result = CResult(ok: true, error_message: nil)

        switch result.toSwiftResult() {
        case .success:
            break
        case .failure(let error):
            XCTFail("Expected success, got \(error)")
        }
    }

    func testFailureResultConvertsToSwiftError() {
        let errorPointer = strdup("native failure")
        defer { free(errorPointer) }

        let result = CResult(ok: false, error_message: errorPointer)

        switch result.toSwiftResult() {
        case .success:
            XCTFail("Expected failure result")
        case .failure(let error):
            XCTAssertEqual(
                error.errorDescription,
                "Video re-encoding failed: native failure"
            )
            XCTAssertEqual(error.code, "TRANSCODE_FAILED")
        }
    }

    func testConvertImageWritesAnOutputFile() throws {
        let fm = FileManager.default
        let baseURL = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: baseURL, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: baseURL) }

        let inputURL = baseURL.appendingPathComponent("input.png")
        let outputURL = baseURL.appendingPathComponent("output.png")
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12))
        let image = renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
        }

        try XCTUnwrap(image.pngData()).write(to: inputURL)

        let result = try CapacitorFFmpeg().convertImage(
            inputPath: inputURL.path,
            outputPath: outputURL.path,
            format: "png"
        )

        XCTAssertEqual(result.format, "png")
        XCTAssertEqual(result.outputPath, outputURL.absoluteString)
        XCTAssertTrue(fm.fileExists(atPath: outputURL.path))
    }
}
