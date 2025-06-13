import Foundation
import Capacitor

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(CapacitorFFmpegPlugin)
public class CapacitorFFmpegPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "CapacitorFFmpegPlugin"
    public let jsName = "CapacitorFFmpeg"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "echo", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "addTwoNumbers", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "initializeFFmpeg", returnType: CAPPluginReturnPromise)
    ]
    private let implementation = CapacitorFFmpeg()

    @objc func echo(_ call: CAPPluginCall) {
        let value = call.getString("value") ?? ""
        call.resolve([
            "value": implementation.echo(value)
        ])
    }
    
    @objc func addTwoNumbers(_ call: CAPPluginCall) {
        let a = call.getInt("a") ?? 0
        let b = call.getInt("b") ?? 0
        let result = implementation.addTwoNumbers(Int32(a), Int32(b))
        call.resolve([
            "result": Int(result)
        ])
    }
    
    @objc func initializeFFmpeg(_ call: CAPPluginCall) {
        let result = implementation.initializeFFmpeg()
        call.resolve([
            "result": Int(result)
        ])
    }
}
