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
    static let schemaVersion = 4

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

enum SupportedDeviceDiagnosticsInsightsComposer {
    static let promptVersion = 1

    private struct Payload: Codable {
        let diagnostic: DiagnosticAnswers
        let selectedAreas: [String]
        let generatedAt: Date
    }

    static func prompt(
        snapshot: PersonalizationSnapshot,
        context: LoomAIContextSnapshot
    ) -> String {
        let payload = Payload(
            diagnostic: DiagnosticAnswers(snapshot: snapshot),
            selectedAreas: snapshot.lifeAreasSelected,
            generatedAt: .now
        )
        let payloadJSON = AppleIntelligenceInsightPromptBuilder.encodeJSON(payload)
        let appContextJSON = AppleIntelligenceInsightPromptBuilder.contextJSON(
            surfaceID: "diagnostic_insights",
            context: context
        )

        return """
        Create Loom diagnostic insights for the user's current personalization snapshot.

        Requirements:
        - Use APP_CONTEXT plus the diagnostic payload below.
        - Return structured output with exactly three fields: `rootCause`, `fulfillmentAreas`, `nextDirection`.
        - Each field should be 2 to 3 calm, practical sentences.
        - `rootCause` should explain the most likely organizing pattern behind the user's current friction, grounded in their stress source, break point, planning reality, and desired first change.
        - `fulfillmentAreas` should explain why Loom uses fulfillment areas as the organizing map for this user. Do not list, rename, or paraphrase the selected area names because the UI already shows them.
        - `nextDirection` should translate the diagnosis into the next practical shift Loom will support. Keep it directional, not absolute.
        - Use APP_CONTEXT to understand the full Loom flow: diagnostics feed Purpose and Fulfillment, then Outcomes, Action Blocks, Little Wins, and reflection carry the system forward.
        - Keep the tone intelligent, personalized, and accurate. Do not invent history or certainty that the app does not support.
        - If the evidence is still early or broad, say that and keep the guidance broad instead of over-diagnosing.
        - Return only structured output.

        APP_CONTEXT JSON:
        \(appContextJSON)

        Diagnostic payload JSON:
        \(payloadJSON)
        """
    }

    static func normalizeBody(
        _ text: String,
        minSentences: Int = 2,
        maxSentences: Int = 3,
        maxLength: Int = 520
    ) -> String {
        _ = minSentences
        let normalized = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "" }

        var sentences = normalized
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if sentences.isEmpty {
            sentences = [normalized]
        }
        if sentences.count > maxSentences {
            sentences = Array(sentences.prefix(maxSentences))
        }

        var output = sentences
            .map { $0.hasSuffix(".") ? $0 : "\($0)." }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if output.count > maxLength {
            let cutoff = output.index(output.startIndex, offsetBy: maxLength)
            output = String(output[..<cutoff]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let lastStop = output.lastIndex(where: { ".!?".contains($0) }) {
                output = String(output[...lastStop]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if !output.hasSuffix(".") {
                output += "."
            }
        }

        return output
    }
}
