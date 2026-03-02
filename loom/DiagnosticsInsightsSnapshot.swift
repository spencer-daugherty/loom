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
    var version: Int

    init(
        snapshotKey: String,
        userKey: String,
        diagnosticsHash: String,
        generatedAt: Date = .now,
        rootCauseText: String,
        fulfillmentText: String,
        nextDirectionText: String,
        version: Int = DiagnosticsInsightsHasher.schemaVersion
    ) {
        self.snapshotKey = snapshotKey
        self.userKey = userKey
        self.diagnosticsHash = diagnosticsHash
        self.generatedAt = generatedAt
        self.rootCauseText = rootCauseText
        self.fulfillmentText = fulfillmentText
        self.nextDirectionText = nextDirectionText
        self.version = version
    }
}

enum DiagnosticsInsightsHasher {
    static let schemaVersion = 1

    static func hash(for snapshot: PersonalizationSnapshot) -> String {
        let canonicalLifeAreas = snapshot.lifeAreasSelected
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .sorted()

        let payload: [String: Any] = [
            "version": schemaVersion,
            "stressSource": snapshot.stressSource.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            "breakPoint": snapshot.breakPoint.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            "planningReality": snapshot.planningReality.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            "desiredChange": snapshot.desiredChange.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            "lifeAreasSelected": canonicalLifeAreas
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else {
            return "hash_error_v\(schemaVersion)"
        }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func snapshotKey(userKey: String, diagnosticsHash: String) -> String {
        "\(PersonalizationUserIdentity.storageSafeKey(for: userKey))|\(schemaVersion)|\(diagnosticsHash)"
    }
}
