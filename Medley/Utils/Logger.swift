import Foundation

enum Logger {
    static func log(_ message: String) { print("[LOG] \(message)") }
    static func log(error: Error, context: String = "") { print("[ERROR] \(context): \(error)") }
}
