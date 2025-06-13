import Foundation

@objc public class CapacitorFFmpeg: NSObject {
    @objc public func echo(_ value: String) -> String {
        print(value)
        return value
    }
}
