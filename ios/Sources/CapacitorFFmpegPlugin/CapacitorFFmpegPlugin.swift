import Foundation
import Capacitor

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@available(iOS 26.0, *)
@objc(CapacitorFFmpegPlugin)
public class CapacitorFFmpegPlugin: CAPPlugin, CAPBridgedPlugin {
    private let PLUGIN_VERSION: String = "0.0.7"
    public let identifier = "CapacitorFFmpegPlugin"
    public let jsName = "CapacitorFFmpeg"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "reencodeVideo", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getPluginVersion", returnType: CAPPluginReturnPromise)
    ]

    private let implementation = CapacitorFFmpeg()

    override public func load() {
        super.load()

        // Set up progress callback
        implementation.onProgress = { [weak self] progress, fileId in
            DispatchQueue.main.async {
                self?.notifyListeners("progress", data: [
                    "progress": progress,
                    "fileId": fileId
                ])
            }
        }
    }

    @objc func reencodeVideo(_ call: CAPPluginCall) {
        guard let inputPath = call.getString("inputPath") else {
            call.reject("Input path is required")
            return
        }
        guard let outputPath = call.getString("outputPath") else {
            call.reject("Output path is required")
            return
        }
        guard let height = call.getInt("height") else {
            call.reject("Height is required")
            return
        }
        guard let width = call.getInt("width") else {
            call.reject("Width is required")
            return
        }
        let bitrate = call.getInt("bitrate", 0) // 0 means default, which is 1 MB/s

        do {
            guard height > 0 && height <= Int32.max else {
                call.reject("Height must be between 0 and \(Int32.max)")
                return
            }
            guard width > 0 && width <= Int32.max else {
                call.reject("Width must be between 0 and \(Int32.max)")
                return
            }
            guard bitrate >= 0 else {
                call.reject("Negative bitrate is illegal!")
                return
            }
            let height32 = Int32(height)
            let width32 = Int32(width)
            let bitrate32 = Int32(bitrate)
            try self.implementation.reencodeVideo(inputPath: inputPath, outputPath: outputPath, width: width32, height: height32, bitrate: bitrate32)

            // Success - resolve the promise
            call.resolve()
        } catch {
            call.reject(error.localizedDescription)
        }
    }

    @objc func getPluginVersion(_ call: CAPPluginCall) {
        call.resolve(["version": self.PLUGIN_VERSION])
    }

}
