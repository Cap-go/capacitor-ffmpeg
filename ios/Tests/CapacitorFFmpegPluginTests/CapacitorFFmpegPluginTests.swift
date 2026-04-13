import AVFoundation
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

private final class MockAudioExportSession: AudioExportSessioning {
    var outputURL: URL?
    var outputFileType: AVFileType?
    var status: AVAssetExportSession.Status
    var error: Error?

    private let onExport: (MockAudioExportSession) -> Void

    init(
        status: AVAssetExportSession.Status = .completed,
        error: Error? = nil,
        onExport: @escaping (MockAudioExportSession) -> Void = { _ in }
    ) {
        self.status = status
        self.error = error
        self.onExport = onExport
    }

    func exportAsynchronously(completionHandler handler: @escaping @Sendable () -> Void) {
        onExport(self)
        handler()
    }
}

private func writeToneWav(to url: URL) throws {
    let toneFormat = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
    let toneFile = try AVAudioFile(forWriting: url, settings: toneFormat.settings)
    let toneBuffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: toneFormat, frameCapacity: 44_100))
    toneBuffer.frameLength = 44_100
    let samples = try XCTUnwrap(toneBuffer.floatChannelData?[0])
    for index in 0..<Int(toneBuffer.frameLength) {
        samples[index] = Float(sin(2.0 * .pi * 440.0 * Double(index) / 44_100.0))
    }
    try toneFile.write(from: toneBuffer)
}

final class CapacitorFFmpegPluginTests: XCTestCase {
    func testCapabilitiesPayloadDescribesTheCurrentIosScope() {
        let payload = CapacitorFFmpeg().getCapabilities().asDictionary
        let features = payload["features"] as? [String: [String: Any]]

        XCTAssertEqual(payload["platform"] as? String, "ios")
        XCTAssertEqual(features?["getCapabilities"]?["status"] as? String, "available")
        XCTAssertEqual(features?["reencodeVideo"]?["status"] as? String, "experimental")
        XCTAssertEqual(features?["convertImage"]?["status"] as? String, "available")
        XCTAssertEqual(features?["convertAudio"]?["status"] as? String, "available")
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
        let fileManager = FileManager.default
        let baseURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: baseURL) }

        let inputURL = baseURL.appendingPathComponent("input.png")
        let outputURL = baseURL.appendingPathComponent("output.png")
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12))
        let image = renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
        }

        try XCTUnwrap(image.pngData()).write(to: inputURL)
        try Data("stale".utf8).write(to: outputURL)

        let result = try CapacitorFFmpeg().convertImage(
            inputPath: inputURL.path,
            outputPath: outputURL.path,
            format: "png"
        )

        XCTAssertEqual(result.format, "png")
        XCTAssertEqual(result.outputPath, outputURL.absoluteString)
        XCTAssertTrue(fileManager.fileExists(atPath: outputURL.path))
    }

    func testConvertAudioRejectsUnsupportedFormats() throws {
        let fileManager = FileManager.default
        let baseURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: baseURL) }

        let inputURL = baseURL.appendingPathComponent("input.wav")
        let outputURL = baseURL.appendingPathComponent("output.wav")

        try writeToneWav(to: inputURL)

        XCTAssertThrowsError(
            try CapacitorFFmpeg().convertAudio(
                inputPath: inputURL.path,
                outputPath: outputURL.path,
                format: "wav"
            )
        ) { error in
            XCTAssertEqual((error as? FFmpegError)?.code, "INVALID_ARGUMENT")
            XCTAssertEqual(error.localizedDescription, "Unsupported audio format: wav")
        }
    }

    func testConvertAudioWritesM4AOutputWhenExportSucceeds() throws {
        let fileManager = FileManager.default
        let baseURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: baseURL) }

        let inputURL = baseURL.appendingPathComponent("input.wav")
        let outputURL = baseURL.appendingPathComponent("output.m4a")
        try writeToneWav(to: inputURL)
        try Data("stale".utf8).write(to: outputURL)

        let exportSession = MockAudioExportSession { session in
            XCTAssertNotEqual(session.outputURL, outputURL)
            XCTAssertEqual(session.outputURL?.deletingLastPathComponent(), outputURL.deletingLastPathComponent())
            XCTAssertEqual(session.outputFileType, .m4a)
            try? Data("converted-audio".utf8).write(to: XCTUnwrap(session.outputURL))
            session.status = .completed
        }

        let result = try CapacitorFFmpeg(audioExportSessionFactory: { asset, presetName in
            XCTAssertEqual(asset.tracks(withMediaType: .audio).count, 1)
            XCTAssertEqual(presetName, AVAssetExportPresetAppleM4A)
            return exportSession
        }).convertAudio(
            inputPath: inputURL.path,
            outputPath: outputURL.path,
            format: "m4a"
        )

        XCTAssertEqual(result.format, "m4a")
        XCTAssertEqual(result.outputPath, outputURL.absoluteString)
        XCTAssertEqual(try String(contentsOf: outputURL), "converted-audio")
    }

    func testConvertAudioRemovesPartialOutputWhenExportFails() throws {
        let fileManager = FileManager.default
        let baseURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: baseURL) }

        let inputURL = baseURL.appendingPathComponent("input.wav")
        let outputURL = baseURL.appendingPathComponent("output.m4a")
        try writeToneWav(to: inputURL)
        try Data("keep-existing-output".utf8).write(to: outputURL)

        let exportError = NSError(
            domain: "CapacitorFFmpegPluginTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "simulated export failure"]
        )
        let exportSession = MockAudioExportSession(status: .failed, error: exportError) { session in
            XCTAssertNotEqual(session.outputURL, outputURL)
            try? Data("partial-output".utf8).write(to: XCTUnwrap(session.outputURL))
        }

        XCTAssertThrowsError(
            try CapacitorFFmpeg(audioExportSessionFactory: { _, _ in exportSession }).convertAudio(
                inputPath: inputURL.path,
                outputPath: outputURL.path,
                format: "m4a"
            )
        ) { error in
            XCTAssertEqual((error as? FFmpegError)?.code, "TRANSCODE_FAILED")
            XCTAssertEqual(error.localizedDescription, "Media transcode failed: simulated export failure")
        }

        XCTAssertEqual(try String(contentsOf: outputURL), "keep-existing-output")
    }

    func testConvertAudioRemovesPartialTemporaryOutputWhenNoDestinationExists() throws {
        let fileManager = FileManager.default
        let baseURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: baseURL) }

        let inputURL = baseURL.appendingPathComponent("input.wav")
        let outputURL = baseURL.appendingPathComponent("output.m4a")
        try writeToneWav(to: inputURL)

        let exportError = NSError(
            domain: "CapacitorFFmpegPluginTests",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "simulated export failure"]
        )
        let exportSession = MockAudioExportSession(status: .failed, error: exportError) { session in
            try? Data("partial-output".utf8).write(to: XCTUnwrap(session.outputURL))
        }

        XCTAssertThrowsError(
            try CapacitorFFmpeg(audioExportSessionFactory: { _, _ in exportSession }).convertAudio(
                inputPath: inputURL.path,
                outputPath: outputURL.path,
                format: "m4a"
            )
        ) { error in
            XCTAssertEqual((error as? FFmpegError)?.code, "TRANSCODE_FAILED")
        }

        XCTAssertFalse(fileManager.fileExists(atPath: outputURL.path))
    }
}
