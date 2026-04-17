import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum LoomInternalDemoMode {
    static let isEnabled = true

    static let grantedPlanDefaultsKey = "loom.internal_demo.granted_plan"
    static let appliedResetTokenDefaultsKey = "loom.internal_demo.applied_reset_token"
}

struct TestDemoProvisioningProfile: Sendable, Equatable {
    let isEnabled: Bool
    let templateID: String?
    let templateVersion: Int
    let resetToken: Int
    let grantedPlan: SubscriptionPlan?
    let autoCompleteGates: Bool
    let alertTitle: String?
    let alertMessage: String?

    var activatesDemoWorkspace: Bool {
        LoomInternalDemoMode.isEnabled && isEnabled
    }

    init(
        isEnabled: Bool,
        templateID: String?,
        templateVersion: Int,
        resetToken: Int,
        grantedPlan: SubscriptionPlan?,
        autoCompleteGates: Bool,
        alertTitle: String?,
        alertMessage: String?
    ) {
        self.isEnabled = isEnabled
        self.templateID = templateID
        self.templateVersion = templateVersion
        self.resetToken = resetToken
        self.grantedPlan = grantedPlan
        self.autoCompleteGates = autoCompleteGates
        self.alertTitle = alertTitle
        self.alertMessage = alertMessage
    }
}

enum TestDemoProvisioningService {
    static func fetchCurrentProfile(for userID: String) async -> TestDemoProvisioningProfile? {
        guard LoomInternalDemoMode.isEnabled else { return nil }

        #if canImport(FirebaseFirestore)
        let trimmedUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUserID.isEmpty else { return nil }

        do {
            let document = try await Firestore.firestore()
                .collection("users")
                .document(trimmedUserID)
                .collection("demoProvisioning")
                .document("current")
                .getDocument()

            guard let data = document.data() else { return nil }
            let isEnabled = boolValue(data["enabled"]) ?? false
            guard isEnabled else { return nil }

            return TestDemoProvisioningProfile(
                isEnabled: true,
                templateID: stringValue(data["templateId"]),
                templateVersion: intValue(data["templateVersion"]) ?? 1,
                resetToken: intValue(data["resetToken"]) ?? 0,
                grantedPlan: stringValue(data["grantedPlan"]).flatMap(SubscriptionPlan.init(rawValue:)),
                autoCompleteGates: boolValue(data["autoCompleteGates"]) ?? true,
                alertTitle: stringValue(data["alertTitle"]),
                alertMessage: stringValue(data["alertMessage"])
            )
        } catch {
            AppDebugActivityLog.log(
                "TestDemoProvisioningService",
                "Failed to fetch demo provisioning for user=\(trimmedUserID) error=\(error.localizedDescription)"
            )
            return nil
        }
        #else
        return nil
        #endif
    }

    static func clearLocalProvisioningState(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: LoomInternalDemoMode.grantedPlanDefaultsKey)
        defaults.removeObject(forKey: LoomInternalDemoMode.appliedResetTokenDefaultsKey)
    }

    private static func stringValue(_ rawValue: Any?) -> String? {
        guard let string = rawValue as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func boolValue(_ rawValue: Any?) -> Bool? {
        switch rawValue {
        case let value as Bool:
            return value
        case let number as NSNumber:
            return number.boolValue
        default:
            return nil
        }
    }

    private static func intValue(_ rawValue: Any?) -> Int? {
        switch rawValue {
        case let value as Int:
            return value
        case let number as NSNumber:
            return number.intValue
        default:
            return nil
        }
    }
}
