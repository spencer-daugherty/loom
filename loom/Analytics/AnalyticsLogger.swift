import Foundation
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

enum AnalyticsLogger {
    static func log(_ event: AnalyticsEvent) {
        let params = event.parameters
        AppDebugActivityLog.log("Analytics", "\(event.name) \(params)")
#if canImport(FirebaseAnalytics)
        guard AnalyticsCollectionPolicy.shouldCollectAnalytics else { return }
        Analytics.logEvent(event.name, parameters: params)
#endif
#if DEBUG
        print("[Analytics] \(event.name) \(params)")
#endif
    }

    static func setUserProperty(_ value: String?, forName name: String) {
        AppDebugActivityLog.log("Analytics", "set_user_property \(name)=\(value ?? "nil")")
#if canImport(FirebaseAnalytics)
        guard AnalyticsCollectionPolicy.shouldCollectAnalytics else { return }
        Analytics.setUserProperty(value, forName: name)
#endif
#if DEBUG
        print("[Analytics] set_user_property \(name)=\(value ?? "nil")")
#endif
    }

    // Keep external analytics limited to AnalyticsEvent so release telemetry stays reviewable,
    // typed, and free of PII or user-authored free text.
}
