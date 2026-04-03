import Darwin
import XCTest
@testable import CapacitorFFmpegPlugin

final class CapacitorFFmpegPluginTests: XCTestCase {
    func testCapabilitiesPayloadDescribesTheCurrentIosScope() {
        let payload = FFmpegCapabilitiesPayload.iosCurrent.asDictionary
        let features = payload["features"] as? [String: [String: Any]]

        XCTAssertEqual(payload["platform"] as? String, "ios")
        XCTAssertEqual(features?["getCapabilities"]?["status"] as? String, "available")
        XCTAssertEqual(features?["reencodeVideo"]?["status"] as? String, "experimental")
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
}
