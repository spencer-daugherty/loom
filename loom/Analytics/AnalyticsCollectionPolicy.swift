import Foundation
import Darwin

enum AnalyticsCollectionPolicy {
    static let releaseOverrideDefaultsKey = "loom.analytics.collection.enabled"

    static var shouldCollectAnalytics: Bool {
        if isRunningForPreviews { return false }
        if isDebuggerAttached { return false }
#if DEBUG
        return false
#else
        let defaults = UserDefaults.standard
        if defaults.object(forKey: releaseOverrideDefaultsKey) != nil {
            return defaults.bool(forKey: releaseOverrideDefaultsKey)
        }
        return true
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
}
