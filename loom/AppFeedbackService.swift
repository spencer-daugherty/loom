#if canImport(FirebaseFirestore)
import Foundation
import FirebaseFirestore
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

enum AppFeedbackServiceError: LocalizedError {
    case invalidRating
    case unavailable

    var errorDescription: String? {
        switch self {
        case .invalidRating:
            return "Please select a star rating before submitting."
        case .unavailable:
            return "Feedback is temporarily unavailable. Please try again later."
        }
    }
}

actor AppFeedbackService {
    static let shared = AppFeedbackService()

    private let db: Firestore
    private let defaults: UserDefaults

    init(
        db: Firestore = Firestore.firestore(),
        defaults: UserDefaults = .standard
    ) {
        self.db = db
        self.defaults = defaults
    }

    func submit(rating: Int, details: String) async throws {
        guard (1...5).contains(rating) else {
            throw AppFeedbackServiceError.invalidRating
        }

        let now = Date()
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let bundle = Bundle.main
        let version = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "unknown"
        let build = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "unknown"
        let userKey = PersonalizationUserIdentity.currentUserKey(defaults: defaults)

        #if canImport(FirebaseAuth)
        let firebaseUser = Auth.auth().currentUser
        let firebaseUID = firebaseUser?.uid.trimmingCharacters(in: .whitespacesAndNewlines)
        let authEmail = firebaseUser?.email?.trimmingCharacters(in: .whitespacesAndNewlines)
        let authName = firebaseUser?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        #else
        let firebaseUID: String? = nil
        let authEmail: String? = nil
        let authName: String? = nil
        #endif

        let storedEmail = defaults.string(forKey: UserSessionStore.Keys.accountEmail)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let storedName = defaults.string(forKey: UserSessionStore.Keys.accountName)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let authProvider = defaults.string(forKey: UserSessionStore.Keys.authProvider)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var payload: [String: Any] = [
            "rating": rating,
            "submittedAt": Timestamp(date: now),
            "submittedAtISO8601": ISO8601DateFormatter().string(from: now),
            "source": "account_feedback_sheet",
            "platform": "iOS",
            "appVersion": version,
            "build": build,
            "userKey": userKey
        ]

        if !trimmedDetails.isEmpty {
            payload["details"] = trimmedDetails
        }
        if let firebaseUID, !firebaseUID.isEmpty {
            payload["firebaseUID"] = firebaseUID
        }
        if let email = authEmail, !email.isEmpty {
            payload["email"] = email
        } else if let storedEmail, !storedEmail.isEmpty {
            payload["email"] = storedEmail
        }
        if let name = authName, !name.isEmpty {
            payload["name"] = name
        } else if let storedName, !storedName.isEmpty {
            payload["name"] = storedName
        }
        if let authProvider, !authProvider.isEmpty {
            payload["authProvider"] = authProvider
        }

        do {
            _ = try await db.collection("app_feedback").addDocument(data: payload)
        } catch {
            throw AppFeedbackServiceError.unavailable
        }
    }
}
#endif
