import Foundation

// Import the Rust C functions
@_silgen_name("add_two_numbers")
func add_two_numbers(_ a: Int32, _ b: Int32) -> Int32

@_silgen_name("init_ffmpeg")
func init_ffmpeg() -> Int32

@objc public class CapacitorFFmpeg: NSObject {
    @objc public func echo(_ value: String) -> String {
        let a = add_two_numbers(10, 20)
        print("Number \(a)")
        print(value)
        return value
    }
    
    @objc public func addTwoNumbers(_ a: Int32, _ b: Int32) -> Int32 {
        return add_two_numbers(a, b)
    }
    
    @objc public func initializeFFmpeg() -> Int32 {
        return init_ffmpeg()
    }
}
