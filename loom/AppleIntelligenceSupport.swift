import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum AppleIntelligenceSupport {
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }
}

enum AppleIntelligencePurposeInsightsGenerator {
    static func readableInsight(prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .general)
            guard model.isAvailable else { throw AppleIntelligencePurposeInsightsError.unavailable }
            let session = LanguageModelSession(model: model)
            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif
        throw AppleIntelligencePurposeInsightsError.unavailable
    }

    static func purposeProfile(
        diagnostic: DiagnosticAnswers,
        vision: String,
        passions: [String]
    ) async throws -> PurposeProfileRecord {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .general)
            guard model.isAvailable else { throw AppleIntelligencePurposeInsightsError.unavailable }
            let session = LanguageModelSession(model: model)
            let response = try await session.respond(
                to: purposeProfilePrompt(
                    diagnostic: diagnostic,
                    vision: vision,
                    passions: passions
                ),
                generating: AppleIntelligencePurposeProfileOutput.self
            )
            return PurposeProfileRecord(
                profile: response.content.profile.trimmingCharacters(in: .whitespacesAndNewlines),
                strength: response.content.strength.trimmingCharacters(in: .whitespacesAndNewlines),
                weakness: response.content.weakness.trimmingCharacters(in: .whitespacesAndNewlines),
                stressTrigger: response.content.stressTrigger.trimmingCharacters(in: .whitespacesAndNewlines),
                breakingPoint: response.content.breakingPoint.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        #endif
        throw AppleIntelligencePurposeInsightsError.unavailable
    }

    private static func purposeProfilePrompt(
        diagnostic: DiagnosticAnswers,
        vision: String,
        passions: [String]
    ) -> String {
        struct Payload: Codable {
            let diagnostic: DiagnosticAnswers
            let vision: String
            let passions: [String]
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payload = Payload(
            diagnostic: diagnostic,
            vision: vision.trimmingCharacters(in: .whitespacesAndNewlines),
            passions: passions
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        let payloadJSON = ((try? encoder.encode(payload)).flatMap { String(data: $0, encoding: .utf8) }) ?? "{}"

        return """
        Create a Loom purpose profile insight from the user's diagnostic answers, vision, and passions.

        Requirements:
        - Return a concise purpose profile summary using the provided structured output fields.
        - `profile` should be a short title-case profile name, 2 to 5 words.
        - `strength` should be one concrete sentence about what is working well.
        - `weakness` should be one concrete sentence about the main limiting pattern.
        - `stressTrigger` should be a short phrase describing what tends to create stress.
        - `breakingPoint` should be a short phrase describing what tends to fail first under pressure.
        - Ground every field in the provided inputs. Do not invent facts.
        - Keep each field compact and readable in product UI.

        Input JSON:
        \(payloadJSON)
        """
    }
}

enum AppleIntelligenceAutoGroupGenerator {
    struct Result: Codable {
        struct Group: Codable {
            let name: String
            let fulfillmentArea: String
            let actionIDs: [String]
        }

        let confidence: String
        let reason: String
        let groups: [Group]
    }

    static func grouping(prompt: String) async throws -> Result {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .general)
            guard model.isAvailable else { throw AppleIntelligencePurposeInsightsError.unavailable }
            let session = LanguageModelSession(model: model)
            let response = try await session.respond(
                to: prompt,
                generating: AppleIntelligenceAutoGroupGenerableOutput.self
            )
            return Result(
                confidence: response.content.confidence,
                reason: response.content.reason,
                groups: response.content.groups.map { group in
                    Result.Group(
                        name: group.name,
                        fulfillmentArea: group.fulfillmentArea,
                        actionIDs: group.actionIDs
                    )
                }
            )
        }
        #endif
        throw AppleIntelligencePurposeInsightsError.unavailable
    }
}

enum AppleIntelligencePlanResultGenerator {
    static func suggestion(actions: [String]) async throws -> String {
        let cleanedActions = actions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleanedActions.isEmpty else { throw AppleIntelligencePurposeInsightsError.unavailable }

        let prompt = """
        Create one concise weekly result statement from these actions.

        Requirements:
        - Return plain text only.
        - Keep it to 2 to 6 words.
        - Make it specific and outcome-oriented, not a generic phrase.
        - Ground it directly in the action list. Do not invent context.
        - Prefer the clearest end result implied by the actions.
        - Do not include quotation marks, bullets, numbering, or explanations.

        Actions:
        \(cleanedActions.map { "- \($0)" }.joined(separator: "\n"))
        """

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .general)
            guard model.isAvailable else { throw AppleIntelligencePurposeInsightsError.unavailable }
            let session = LanguageModelSession(model: model)
            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif
        throw AppleIntelligencePurposeInsightsError.unavailable
    }
}

enum AppleIntelligencePurposeInsightsError: Error {
    case unavailable
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligencePurposeProfileOutput {
    let profile: String
    let strength: String
    let weakness: String
    let stressTrigger: String
    let breakingPoint: String
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligenceAutoGroupGenerableGroupOutput {
    let name: String
    let fulfillmentArea: String
    let actionIDs: [String]
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligenceAutoGroupGenerableOutput {
    let confidence: String
    let reason: String
    let groups: [AppleIntelligenceAutoGroupGenerableGroupOutput]
}
#endif
