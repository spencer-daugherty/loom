import Foundation

enum AnalyticsEvent {
    case onboardingStarted(source: String = "onboarding")
    case onboardingSlideViewed(index: Int, source: String = "onboarding")
    case onboardingCompleted(totalSlides: Int, durationSeconds: Int, source: String = "onboarding")
    case onboardingAbandoned(lastSlideIndex: Int, source: String = "onboarding")
    case signupStarted(source: String = "account")
    case signupCompleted(method: String, source: String = "account")
    case signupAbandoned(reason: String, source: String = "account")
    case diagnosticStarted(source: String = "diagnostic", step: Int, elapsedSeconds: Int)
    case diagnosticCompleted(source: String = "diagnostic", step: Int, elapsedSeconds: Int)
    case diagnosticAbandoned(source: String = "diagnostic", step: Int, elapsedSeconds: Int)
    case diagnosticUpdated(source: String = "diagnostic", step: Int, elapsedSeconds: Int)
    case paywallViewed(source: String = "paywall")
    case paywallAbandoned(reason: String, source: String = "paywall")
    case paywallPlanSelected(plan: String, source: String = "paywall")
    case purchaseStarted(plan: String, source: String = "paywall")
    case purchaseCompleted(plan: String, source: String = "paywall")
    case purchaseFailed(plan: String, errorType: String, source: String = "paywall")
    case firstActivation(source: String = "root_gate")
    case coreOpened(source: String = "root_gate")
    case dailyActive(source: String = "root_gate", sessionDay: Int)
    case retentionDay1(source: String = "root_gate")
    case retentionDay7(source: String = "root_gate")
    case featureUsed(featureName: String, source: String, step: String?, variant: String?)

    var name: String {
        switch self {
        case .onboardingStarted: return "onboarding_started"
        case .onboardingSlideViewed: return "onboarding_slide_viewed"
        case .onboardingCompleted: return "onboarding_completed"
        case .onboardingAbandoned: return "onboarding_abandoned"
        case .signupStarted: return "signup_started"
        case .signupCompleted: return "signup_completed"
        case .signupAbandoned: return "signup_abandoned"
        case .diagnosticStarted: return "diagnostic_started"
        case .diagnosticCompleted: return "diagnostic_completed"
        case .diagnosticAbandoned: return "diagnostic_abandoned"
        case .diagnosticUpdated: return "diagnostic_updated"
        case .paywallViewed: return "paywall_viewed"
        case .paywallAbandoned: return "paywall_abandoned"
        case .paywallPlanSelected: return "paywall_plan_selected"
        case .purchaseStarted: return "purchase_started"
        case .purchaseCompleted: return "purchase_completed"
        case .purchaseFailed: return "purchase_failed"
        case .firstActivation: return "first_activation"
        case .coreOpened: return "core_opened"
        case .dailyActive: return "daily_active"
        case .retentionDay1: return "retention_day_1"
        case .retentionDay7: return "retention_day_7"
        case .featureUsed: return "feature_used"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case .onboardingStarted(let source):
            return ["source": source]
        case .onboardingSlideViewed(let index, let source):
            return ["source": source, "step": index]
        case .onboardingCompleted(let totalSlides, let durationSeconds, let source):
            return ["source": source, "total_slides": totalSlides, "duration_seconds": durationSeconds]
        case .onboardingAbandoned(let lastSlideIndex, let source):
            return ["source": source, "step": lastSlideIndex]
        case .signupStarted(let source):
            return ["source": source]
        case .signupCompleted(let method, let source):
            return ["source": source, "method": method]
        case .signupAbandoned(let reason, let source):
            return ["source": source, "reason": reason]
        case .diagnosticStarted(let source, let step, let elapsedSeconds):
            return ["source": source, "step": step, "time_spent_seconds": elapsedSeconds]
        case .diagnosticCompleted(let source, let step, let elapsedSeconds):
            return ["source": source, "step": step, "time_spent_seconds": elapsedSeconds]
        case .diagnosticAbandoned(let source, let step, let elapsedSeconds):
            return ["source": source, "step": step, "time_spent_seconds": elapsedSeconds]
        case .diagnosticUpdated(let source, let step, let elapsedSeconds):
            return ["source": source, "step": step, "time_spent_seconds": elapsedSeconds]
        case .paywallViewed(let source):
            return ["source": source]
        case .paywallAbandoned(let reason, let source):
            return ["source": source, "reason": reason]
        case .paywallPlanSelected(let plan, let source):
            return ["source": source, "plan": plan]
        case .purchaseStarted(let plan, let source):
            return ["source": source, "plan": plan]
        case .purchaseCompleted(let plan, let source):
            return ["source": source, "plan": plan]
        case .purchaseFailed(let plan, let errorType, let source):
            return ["source": source, "plan": plan, "error_type": errorType]
        case .firstActivation(let source):
            return ["source": source]
        case .coreOpened(let source):
            return ["source": source]
        case .dailyActive(let source, let sessionDay):
            return ["source": source, "session_day": sessionDay]
        case .retentionDay1(let source):
            return ["source": source, "session_day": 1]
        case .retentionDay7(let source):
            return ["source": source, "session_day": 7]
        case .featureUsed(let featureName, let source, let step, let variant):
            var params: [String: Any] = ["source": source, "feature_name": featureName]
            if let step, !step.isEmpty { params["step"] = step }
            if let variant, !variant.isEmpty { params["variant"] = variant }
            return params
        }
    }
}
