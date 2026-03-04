import Foundation
import SwiftData
import CryptoKit

@Model
final class DiagnosticsInsightsSnapshot {
    @Attribute(.unique) var snapshotKey: String
    var userKey: String
    var diagnosticsHash: String
    var generatedAt: Date
    var rootCauseText: String
    var fulfillmentText: String
    var nextDirectionText: String
    var purposeRefreshCycleKey: String?
    var version: Int

    init(
        snapshotKey: String,
        userKey: String,
        diagnosticsHash: String,
        generatedAt: Date = .now,
        rootCauseText: String,
        fulfillmentText: String,
        nextDirectionText: String,
        purposeRefreshCycleKey: String? = nil,
        version: Int = DiagnosticsInsightsHasher.schemaVersion
    ) {
        self.snapshotKey = snapshotKey
        self.userKey = userKey
        self.diagnosticsHash = diagnosticsHash
        self.generatedAt = generatedAt
        self.rootCauseText = rootCauseText
        self.fulfillmentText = fulfillmentText
        self.nextDirectionText = nextDirectionText
        self.purposeRefreshCycleKey = purposeRefreshCycleKey
        self.version = version
    }
}

enum DiagnosticsInsightsHasher {
    static let schemaVersion = 2

    static func hash(for snapshot: PersonalizationSnapshot) -> String {
        let normalizedAnswers = DiagnosticAnswers(
            stress: snapshot.stressSource.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            breaksFirst: snapshot.breakPoint.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            areas: snapshot.lifeAreasSelected
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
                .sorted(),
            planningStyle: snapshot.planningReality.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            firstChange: snapshot.desiredChange.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )

        guard let data = try? JSONEncoder().encode(normalizedAnswers) else {
            return "hash_error_v\(schemaVersion)"
        }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func snapshotKey(userKey: String, diagnosticsHash: String) -> String {
        "\(PersonalizationUserIdentity.storageSafeKey(for: userKey))|\(schemaVersion)|\(diagnosticsHash)"
    }
}
