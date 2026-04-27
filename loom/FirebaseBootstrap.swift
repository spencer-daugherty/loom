import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif

enum FirebaseBootstrap {
    static var isConfigured: Bool {
#if canImport(FirebaseCore)
        FirebaseApp.app() != nil
#else
        false
#endif
    }

    static func configureIfNeeded(reason: String) {
#if canImport(FirebaseCore)
        guard !isConfigured else {
            debugLog("already configured reason=\(reason)")
            return
        }
        guard !isPreviewSafeModeEnabled else {
            debugLog("skipped preview safe mode reason=\(reason)")
            return
        }
        debugLog("configure started reason=\(reason)")
        FirebaseApp.configure()
        debugLog("configure finished reason=\(reason)")
#else
        _ = reason
#endif
    }

    private static var isPreviewSafeModeEnabled: Bool {
        let env = ProcessInfo.processInfo.environment
        let flag = (env["LOOM_PREVIEW_SAFE_MODE"] ?? "").lowercased()
        return env["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || env["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
            || flag == "1"
            || flag == "true"
            || flag == "yes"
    }

    private static func debugLog(_ message: String) {
#if DEBUG
        print("[LoomLaunch] FirebaseBootstrap \(message)")
        AppDebugActivityLog.log("FirebaseBootstrap", message)
#else
        _ = message
#endif
    }
}
