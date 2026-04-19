import Foundation

enum LoomDeveloperBuild {
    #if DEBUG
    static let isInternalBuild = true
    #else
    static let isInternalBuild = false
    #endif

    static func enabled(_ value: Bool) -> Bool {
        isInternalBuild && value
    }

    static func storedFlag(forKey key: String, defaults: UserDefaults = .standard) -> Bool {
        isInternalBuild && defaults.bool(forKey: key)
    }
}
