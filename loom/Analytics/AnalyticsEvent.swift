import Foundation

enum AnalyticsEvent {
    case onboardingStarted(source: String = "onboarding")
    case onboardingCompleted(totalSlides: Int, durationSeconds: Int, source: String = "onboarding")
    case onboardingAbandoned(lastSlideIndex: Int, durationSeconds: Int? = nil, source: String = "onboarding")
    case signupStarted(source: String = "account")
    case signupCompleted(method: String, source: String = "account")
    case signupAbandoned(reason: String, source: String = "account")
    case diagnosticStarted(source: String = "diagnostic", step: Int, stepName: String? = nil, elapsedSeconds: Int)
    case diagnosticCompleted(source: String = "diagnostic", step: Int, stepName: String? = nil, elapsedSeconds: Int)
    case diagnosticAbandoned(source: String = "diagnostic", step: Int, stepName: String? = nil, elapsedSeconds: Int)
    case quickTourStarted(source: String = "content_quick_tour")
    case quickTourStepViewed(stepName: String, stepIndex: Int, source: String = "content_quick_tour")
    case quickTourCompleted(totalSteps: Int, durationSeconds: Int, source: String = "content_quick_tour")
    case setupStarted(source: String = "home_setup", currentStage: String)
    case setupStepViewed(stepName: String, stepIndex: Int, elapsedSeconds: Int, source: String = "home_setup")
    case setupStepCompleted(stepName: String, stepIndex: Int, completionOutcome: String, elapsedSeconds: Int, stepDurationSeconds: Int, source: String = "home_setup")
    case setupExited(stepName: String, stepIndex: Int, elapsedSeconds: Int, stepDurationSeconds: Int, source: String = "home_setup")
    case setupCompleted(elapsedSeconds: Int, source: String = "home_setup")
    case paywallViewed(source: String = "paywall", mode: String = "standard")
    case paywallAbandoned(reason: String, source: String = "paywall")
    case paywallPlanSelected(source: String = "paywall", mode: String = "standard", plan: String, productID: String)
    case paywallNotifyMeTapped(source: String = "paywall", mode: String = "standard", plan: String, productID: String, daysUntilAvailable: Int, authorizationStatus: String)
    case paywallNotifyMeResult(source: String = "paywall", mode: String = "standard", plan: String, productID: String, daysUntilAvailable: Int, authorizationStatus: String, result: String)
    case purchaseStarted(plan: String, productID: String? = nil, source: String = "paywall")
    case purchaseCompleted(plan: String, productID: String? = nil, source: String = "paywall")
    case purchaseFailed(plan: String, productID: String? = nil, errorType: String, source: String = "paywall")
    case restoreStarted(source: String = "paywall")
    case restoreCompleted(source: String = "paywall", restoreOutcome: String, plan: String? = nil)
    case firstActivation(source: String = "root_gate")
    case coreOpened(source: String = "root_gate")
    case dailyActive(source: String = "root_gate", sessionDay: Int, currentStage: String? = nil)
    case retentionDay1(source: String = "root_gate", currentStage: String? = nil)
    case retentionDay3(source: String = "root_gate", currentStage: String? = nil)
    case retentionDay7(source: String = "root_gate", currentStage: String? = nil)

    var name: String {
        switch self {
        case .onboardingStarted: return "onboarding_started"
        case .onboardingCompleted: return "onboarding_completed"
        case .onboardingAbandoned: return "onboarding_abandoned"
        case .signupStarted: return "signup_started"
        case .signupCompleted: return "signup_completed"
        case .signupAbandoned: return "signup_abandoned"
        case .diagnosticStarted: return "diagnostic_started"
        case .diagnosticCompleted: return "diagnostic_completed"
        case .diagnosticAbandoned: return "diagnostic_abandoned"
        case .quickTourStarted: return "quick_tour_started"
        case .quickTourStepViewed: return "quick_tour_step_viewed"
        case .quickTourCompleted: return "quick_tour_completed"
        case .setupStarted: return "setup_started"
        case .setupStepViewed: return "setup_step_viewed"
        case .setupStepCompleted: return "setup_step_completed"
        case .setupExited: return "setup_exited"
        case .setupCompleted: return "setup_completed"
        case .paywallViewed: return "paywall_viewed"
        case .paywallAbandoned: return "paywall_abandoned"
        case .paywallPlanSelected: return "paywall_plan_selected"
        case .paywallNotifyMeTapped: return "paywall_notify_me_tapped"
        case .paywallNotifyMeResult: return "paywall_notify_me_result"
        case .purchaseStarted: return "purchase_started"
        case .purchaseCompleted: return "purchase_completed"
        case .purchaseFailed: return "purchase_failed"
        case .restoreStarted: return "restore_started"
        case .restoreCompleted: return "restore_completed"
        case .firstActivation: return "first_activation"
        case .coreOpened: return "core_opened"
        case .dailyActive: return "daily_active"
        case .retentionDay1: return "retention_day_1"
        case .retentionDay3: return "retention_day_3"
        case .retentionDay7: return "retention_day_7"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case .onboardingStarted(let source):
            return ["source": source]
        case .onboardingCompleted(let totalSlides, let durationSeconds, let source):
            return ["source": source, "total_slides": totalSlides, "duration_seconds": durationSeconds]
        case .onboardingAbandoned(let lastSlideIndex, let durationSeconds, let source):
            return compactParameters(["source": source, "step": lastSlideIndex, "duration_seconds": durationSeconds])
        case .signupStarted(let source):
            return ["source": source]
        case .signupCompleted(let method, let source):
            return ["source": source, "method": method]
        case .signupAbandoned(let reason, let source):
            return ["source": source, "reason": reason]
        case .diagnosticStarted(let source, let step, let stepName, let elapsedSeconds),
             .diagnosticCompleted(let source, let step, let stepName, let elapsedSeconds),
             .diagnosticAbandoned(let source, let step, let stepName, let elapsedSeconds):
            return compactParameters(["source": source, "step": step, "step_name": stepName, "time_spent_seconds": elapsedSeconds])
        case .quickTourStarted(let source):
            return ["source": source]
        case .quickTourStepViewed(let stepName, let stepIndex, let source):
            return ["source": source, "step_name": stepName, "step_index": stepIndex]
        case .quickTourCompleted(let totalSteps, let durationSeconds, let source):
            return ["source": source, "total_steps": totalSteps, "duration_seconds": durationSeconds]
        case .setupStarted(let source, let currentStage):
            return ["source": source, "current_stage": currentStage]
        case .setupStepViewed(let stepName, let stepIndex, let elapsedSeconds, let source):
            return ["source": source, "step_name": stepName, "step_index": stepIndex, "elapsed_seconds": elapsedSeconds]
        case .setupStepCompleted(let stepName, let stepIndex, let completionOutcome, let elapsedSeconds, let stepDurationSeconds, let source):
            return ["source": source, "step_name": stepName, "step_index": stepIndex, "completion_outcome": completionOutcome, "elapsed_seconds": elapsedSeconds, "step_duration_seconds": stepDurationSeconds]
        case .setupExited(let stepName, let stepIndex, let elapsedSeconds, let stepDurationSeconds, let source):
            return ["source": source, "step_name": stepName, "step_index": stepIndex, "elapsed_seconds": elapsedSeconds, "step_duration_seconds": stepDurationSeconds]
        case .setupCompleted(let elapsedSeconds, let source):
            return ["source": source, "elapsed_seconds": elapsedSeconds]
        case .paywallViewed(let source, let mode):
            return ["source": source, "mode": mode]
        case .paywallAbandoned(let reason, let source):
            return ["source": source, "reason": reason]
        case .paywallPlanSelected(let source, let mode, let plan, let productID):
            return ["source": source, "mode": mode, "plan": plan, "product_id": productID]
        case .paywallNotifyMeTapped(let source, let mode, let plan, let productID, let daysUntilAvailable, let authorizationStatus):
            return [
                "source": source,
                "mode": mode,
                "plan": plan,
                "product_id": productID,
                "days_until_available": daysUntilAvailable,
                "authorization_status": authorizationStatus
            ]
        case .paywallNotifyMeResult(let source, let mode, let plan, let productID, let daysUntilAvailable, let authorizationStatus, let result):
            return [
                "source": source,
                "mode": mode,
                "plan": plan,
                "product_id": productID,
                "days_until_available": daysUntilAvailable,
                "authorization_status": authorizationStatus,
                "result": result
            ]
        case .purchaseStarted(let plan, let productID, let source),
             .purchaseCompleted(let plan, let productID, let source):
            return compactParameters(["source": source, "plan": plan, "product_id": productID])
        case .purchaseFailed(let plan, let productID, let errorType, let source):
            return compactParameters(["source": source, "plan": plan, "product_id": productID, "error_type": errorType])
        case .restoreStarted(let source):
            return ["source": source]
        case .restoreCompleted(let source, let restoreOutcome, let plan):
            return compactParameters(["source": source, "restore_outcome": restoreOutcome, "plan": plan])
        case .firstActivation(let source):
            return ["source": source]
        case .coreOpened(let source):
            return ["source": source]
        case .dailyActive(let source, let sessionDay, let currentStage):
            return compactParameters(["source": source, "session_day": sessionDay, "current_stage": currentStage])
        case .retentionDay1(let source, let currentStage):
            return compactParameters(["source": source, "session_day": 1, "current_stage": currentStage])
        case .retentionDay3(let source, let currentStage):
            return compactParameters(["source": source, "session_day": 3, "current_stage": currentStage])
        case .retentionDay7(let source, let currentStage):
            return compactParameters(["source": source, "session_day": 7, "current_stage": currentStage])
        }
    }

    private func compactParameters(_ parameters: [String: Any?]) -> [String: Any] {
        parameters.compactMapValues { $0 }
    }
}
