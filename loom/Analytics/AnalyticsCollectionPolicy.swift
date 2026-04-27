import Foundation
import Darwin
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

enum AnalyticsCollectionPolicy {
    static let releaseOverrideDefaultsKey = "loom.analytics.collection.enabled"
    private static let sandboxReceiptName = "sandboxReceipt"

    static var shouldCollectAnalytics: Bool {
        if isRunningForPreviews { return false }
        if isDebuggerAttached { return false }
#if DEBUG
        return false
#else
        if isDemoWorkspaceActive { return false }
        if isTestFlightOrSandboxInstall { return false }
        let defaults = UserDefaults.standard
        if defaults.object(forKey: releaseOverrideDefaultsKey) != nil {
            return defaults.bool(forKey: releaseOverrideDefaultsKey)
        }
        return true
#endif
    }

    static func refreshCollectionState() {
#if canImport(FirebaseAnalytics)
        #if DEBUG
        Analytics.setAnalyticsCollectionEnabled(false)
        #else
        Analytics.setAnalyticsCollectionEnabled(shouldCollectAnalytics)
        #endif
#endif
    }

    private static var isRunningForPreviews: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
    }

    private static var isDebuggerAttached: Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        let result = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        if result != 0 {
            return false
        }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    private static var isDemoWorkspaceActive: Bool {
        LoomDefaultsScope.currentWorkspace() != nil
    }

    private static var isTestFlightOrSandboxInstall: Bool {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else { return false }
        return receiptURL.lastPathComponent == sandboxReceiptName
    }
}
