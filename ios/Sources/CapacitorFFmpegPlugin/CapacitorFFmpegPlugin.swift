import Foundation
import Capacitor

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(CapacitorFFmpegPlugin)
public class CapacitorFFmpegPlugin: CAPPlugin, CAPBridgedPlugin {
    private let pluginVersion: String = "0.0.8"
    public let identifier = "CapacitorFFmpegPlugin"
    public let jsName = "CapacitorFFmpeg"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "getCapabilities", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "reencodeVideo", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "convertImage", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getPluginVersion", returnType: CAPPluginReturnPromise)
    ]

    private let implementation = CapacitorFFmpeg()

    override public func load() {
        super.load()

        implementation.onProgress = { [weak self] payload in
            DispatchQueue.main.async {
                self?.notifyListeners("progress", data: payload.asDictionary)
            }
        }
    }

    @objc func reencodeVideo(_ call: CAPPluginCall) {
        guard let inputPath = call.getString("inputPath") else {
            call.reject("Input path is required", "INVALID_ARGUMENT")
            return
        }
        guard let outputPath = call.getString("outputPath") else {
            call.reject("Output path is required", "INVALID_ARGUMENT")
            return
        }
        guard let height = call.getInt("height") else {
            call.reject("Height is required", "INVALID_ARGUMENT")
            return
        }
        guard let width = call.getInt("width") else {
            call.reject("Width is required", "INVALID_ARGUMENT")
            return
        }
        let bitrate = call.getInt("bitrate", 0)

        do {
            guard height > 0 && height <= Int32.max else {
                call.reject("Height must be between 0 and \(Int32.max)", "INVALID_ARGUMENT")
                return
            }
            guard width > 0 && width <= Int32.max else {
                call.reject("Width must be between 0 and \(Int32.max)", "INVALID_ARGUMENT")
                return
            }
            guard bitrate >= 0 else {
                call.reject("Negative bitrate is illegal!", "INVALID_ARGUMENT")
                return
            }

            let jobId = try self.implementation.reencodeVideo(
                inputPath: inputPath,
                outputPath: outputPath,
                width: Int32(width),
                height: Int32(height),
                bitrate: Int32(bitrate)
            )

            call.resolve([
                "jobId": jobId,
                "status": "queued"
            ])
        } catch {
            reject(call, with: error)
        }
    }

    @objc func convertImage(_ call: CAPPluginCall) {
        guard let inputPath = call.getString("inputPath") else {
            call.reject("Input path is required", "INVALID_ARGUMENT")
            return
        }
        guard let outputPath = call.getString("outputPath") else {
            call.reject("Output path is required", "INVALID_ARGUMENT")
            return
        }
        guard let format = call.getString("format") else {
            call.reject("Output format is required", "INVALID_ARGUMENT")
            return
        }

        let quality = call.getDouble("quality")

        do {
            let result = try implementation.convertImage(
                inputPath: inputPath,
                outputPath: outputPath,
                format: format,
                quality: quality
            )

            call.resolve(result.asDictionary)
        } catch {
            reject(call, with: error)
        }
    }

    @objc func getPluginVersion(_ call: CAPPluginCall) {
        call.resolve(["version": self.pluginVersion])
    }

    @objc func getCapabilities(_ call: CAPPluginCall) {
        call.resolve(implementation.getCapabilities().asDictionary)
    }

    private func reject(_ call: CAPPluginCall, with error: Error) {
        if let ffmpegError = error as? FFmpegError {
            call.reject(ffmpegError.localizedDescription, ffmpegError.code)
            return
        }

        call.reject(error.localizedDescription, "TRANSCODE_FAILED")
    }
}
