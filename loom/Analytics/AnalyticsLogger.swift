import Foundation
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

enum AnalyticsLogger {
    static func log(_ event: AnalyticsEvent) {
        let params = event.parameters
#if canImport(FirebaseAnalytics)
        Analytics.logEvent(event.name, parameters: params)
#endif
#if DEBUG
        print("[Analytics] \(event.name) \(params)")
#endif
    }

    static func setUserProperty(_ value: String?, forName name: String) {
#if canImport(FirebaseAnalytics)
        Analytics.setUserProperty(value, forName: name)
#endif
#if DEBUG
        print("[Analytics] set_user_property \(name)=\(value ?? "nil")")
#endif
    }

    static func featureUsed(
        _ featureName: String,
        source: String,
        step: String? = nil,
        variant: String? = nil
    ) {
        log(.featureUsed(featureName: featureName, source: source, step: step, variant: variant))
    }

    // TODO: Add additional typed events only after funnel hypotheses are defined.
    // TODO: Keep event payloads free of PII and free-text content.
}
