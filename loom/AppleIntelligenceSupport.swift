import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum AppleIntelligenceSupport {
    static var isForceDisabled: Bool {
        LoomDeveloperBuild.storedFlag(forKey: loomAIDisableAppleIntelligenceDefaultsKey)
    }

    static var isAvailable: Bool {
        guard !isForceDisabled else { return false }
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
            guard AppleIntelligenceSupport.isAvailable, model.isAvailable else { throw AppleIntelligencePurposeInsightsError.unavailable }
            let session = LanguageModelSession(model: model)
            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif
        throw AppleIntelligencePurposeInsightsError.unavailable
    }

    static func readableInsightLines(prompt: String) async throws -> AppleIntelligenceReadableInsightResult {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .general)
            guard AppleIntelligenceSupport.isAvailable, model.isAvailable else { throw AppleIntelligencePurposeInsightsError.unavailable }
            let session = LanguageModelSession(model: model)
            let response = try await session.respond(
                to: prompt,
                generating: AppleIntelligenceReadableInsightOutput.self
            )
            return AppleIntelligenceReadableInsightResult(
                insight: response.content.insight.trimmingCharacters(in: .whitespacesAndNewlines),
                action: response.content.action.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        #endif
        throw AppleIntelligencePurposeInsightsError.unavailable
    }

    static func reflectSummary(prompt: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .general)
            guard AppleIntelligenceSupport.isAvailable, model.isAvailable else { throw AppleIntelligencePurposeInsightsError.unavailable }
            let session = LanguageModelSession(model: model)
            let response = try await session.respond(
                to: prompt,
                generating: AppleIntelligenceReflectInsightOutput.self
            )
            return response.content.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif
        throw AppleIntelligencePurposeInsightsError.unavailable
    }

    static func diagnosticBundle(prompt: String) async throws -> AppleIntelligenceDiagnosticInsightBundle {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .general)
            guard AppleIntelligenceSupport.isAvailable, model.isAvailable else { throw AppleIntelligencePurposeInsightsError.unavailable }
            let session = LanguageModelSession(model: model)
            let response = try await session.respond(
                to: prompt,
                generating: AppleIntelligenceDiagnosticInsightsOutput.self
            )
            return AppleIntelligenceDiagnosticInsightBundle(
                rootCause: response.content.rootCause.trimmingCharacters(in: .whitespacesAndNewlines),
                fulfillmentAreas: response.content.fulfillmentAreas.trimmingCharacters(in: .whitespacesAndNewlines),
                nextDirection: response.content.nextDirection.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        #endif
        throw AppleIntelligencePurposeInsightsError.unavailable
    }

    static func fulfillmentOnboardingInsights(prompt: String) async throws -> AppleIntelligenceFulfillmentOnboardingBundle {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .general)
            guard AppleIntelligenceSupport.isAvailable, model.isAvailable else { throw AppleIntelligencePurposeInsightsError.unavailable }
            let session = LanguageModelSession(model: model)
            let response = try await session.respond(
                to: prompt,
                generating: AppleIntelligenceFulfillmentOnboardingOutput.self
            )
            return AppleIntelligenceFulfillmentOnboardingBundle(
                fulfillmentAreas: response.content.fulfillmentAreas.trimmingCharacters(in: .whitespacesAndNewlines),
                nextDirection: response.content.nextDirection.trimmingCharacters(in: .whitespacesAndNewlines),
                nudge: response.content.nudge?.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        #endif
        throw AppleIntelligencePurposeInsightsError.unavailable
    }

    static func purposeProfile(
        diagnostic: DiagnosticAnswers,
        vision: String,
        passions: [String],
        appContext: LoomAIContextSnapshot? = nil
    ) async throws -> PurposeProfileRecord {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .general)
            guard AppleIntelligenceSupport.isAvailable, model.isAvailable else { throw AppleIntelligencePurposeInsightsError.unavailable }
            let session = LanguageModelSession(model: model)
            let response = try await session.respond(
                to: purposeProfilePrompt(
                    diagnostic: diagnostic,
                    vision: vision,
                    passions: passions,
                    appContext: appContext
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
        passions: [String],
        appContext: LoomAIContextSnapshot?
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
        let contextJSON = AppleIntelligenceInsightPromptBuilder.contextJSON(
            surfaceID: "purpose_profile",
            context: appContext
        )

        return """
        Create a Loom purpose profile insight from the user's diagnostic answers, vision, and passions.

        Requirements:
        - Return a concise purpose profile summary using the provided structured output fields.
        - `profile` should be a short title-case profile name, 2 to 5 words.
        - `strength` should be one concrete sentence about what is working well.
        - `weakness` should be one concrete sentence about the main limiting pattern.
        - `stressTrigger` should be a short phrase describing what tends to create stress.
        - `breakingPoint` should be a short phrase describing what tends to fail first under pressure.
        - Use APP_CONTEXT to understand how Loom works, including the diagnostic flow, Purpose setup, Fulfillment setup, and how these fields will be shown in product UI.
        - Ground every field in the provided inputs. Do not invent facts.
        - If the inputs are still early or sparse, keep the diagnosis broad and directional rather than overly certain.
        - Keep each field compact and readable in product UI.

        APP_CONTEXT JSON:
        \(contextJSON)

        Input JSON:
        \(payloadJSON)
        """
    }
}

struct AppleIntelligenceReadableInsightResult: Sendable {
    let insight: String
    let action: String
}

struct AppleIntelligenceReadableInsightFailureState: Sendable, Equatable {
    let stage: String
    let technicalMessage: String
    let userMessage: String
}

enum AppleIntelligenceReadableInsightMetric: String, Codable, CaseIterable, Sendable {
    case structure = "Structure"
    case outcomes = "Outcomes"
    case actionBlocks = "Action Blocks"
    case littleWins = "Little Wins"
    case carryoverPenalty = "Carryover penalty"
    case engagement = "Engagement"
    case strategicBehavior = "Strategic Behavior"
}

struct AppleIntelligenceReadableInsightLeverageAnalysis: Codable, Sendable, Equatable {
    let metric: AppleIntelligenceReadableInsightMetric
    let currentValue: Double
    let displayValue: String
    let weight: Double
    let headroom: Double
    let opportunity: Double
    let reason: String
    let recommendedAction: String
    let detail: String?
    let isMissing: Bool
}

struct AppleIntelligenceReadableInsightLeverageCandidate: Sendable, Equatable {
    let metric: AppleIntelligenceReadableInsightMetric
    let currentValue: Double
    let displayValue: String
    let weight: Double
    let headroom: Double
    let opportunity: Double
    let reason: String
    let recommendedAction: String
    let detail: String?
    let isMissing: Bool
    let actionabilityPriority: Int
}

enum AppleIntelligenceReadableInsightLeverageEngine {
    static func positiveCandidate(
        metric: AppleIntelligenceReadableInsightMetric,
        currentValue: Double,
        weight: Double,
        reason: String,
        recommendedAction: String,
        detail: String? = nil,
        isMissing: Bool = false,
        actionabilityPriority: Int = 0
    ) -> AppleIntelligenceReadableInsightLeverageCandidate {
        let clamped = max(0, min(1, currentValue))
        let headroom = max(0, 1 - clamped)
        return .init(
            metric: metric,
            currentValue: clamped,
            displayValue: percentText(clamped),
            weight: weight,
            headroom: headroom,
            opportunity: weight * headroom,
            reason: reason,
            recommendedAction: recommendedAction,
            detail: detail,
            isMissing: isMissing,
            actionabilityPriority: actionabilityPriority
        )
    }

    static func dragCandidate(
        metric: AppleIntelligenceReadableInsightMetric,
        currentPenalty: Double,
        weight: Double,
        reason: String,
        recommendedAction: String,
        detail: String? = nil,
        actionabilityPriority: Int = 0
    ) -> AppleIntelligenceReadableInsightLeverageCandidate {
        let clamped = max(0, min(1, currentPenalty))
        return .init(
            metric: metric,
            currentValue: clamped,
            displayValue: percentText(clamped),
            weight: weight,
            headroom: clamped,
            opportunity: weight * clamped,
            reason: reason,
            recommendedAction: recommendedAction,
            detail: detail,
            isMissing: false,
            actionabilityPriority: actionabilityPriority
        )
    }

    static func bestAnalysis(
        from candidates: [AppleIntelligenceReadableInsightLeverageCandidate]
    ) -> AppleIntelligenceReadableInsightLeverageAnalysis? {
        let best = candidates
            .filter { $0.opportunity > 0.0001 }
            .max { lhs, rhs in
                if abs(lhs.opportunity - rhs.opportunity) > 0.0001 {
                    return lhs.opportunity < rhs.opportunity
                }
                if lhs.actionabilityPriority != rhs.actionabilityPriority {
                    return lhs.actionabilityPriority < rhs.actionabilityPriority
                }
                if abs(lhs.weight - rhs.weight) > 0.0001 {
                    return lhs.weight < rhs.weight
                }
                return lhs.metric.rawValue > rhs.metric.rawValue
            }

        return best.map {
            AppleIntelligenceReadableInsightLeverageAnalysis(
                metric: $0.metric,
                currentValue: $0.currentValue,
                displayValue: $0.displayValue,
                weight: $0.weight,
                headroom: $0.headroom,
                opportunity: $0.opportunity,
                reason: $0.reason,
                recommendedAction: $0.recommendedAction,
                detail: $0.detail,
                isMissing: $0.isMissing
            )
        }
    }

    static func percentText(_ value: Double) -> String {
        "\(Int((max(0, min(1, value)) * 100).rounded()))%"
    }
}

struct AppleIntelligenceDiagnosticInsightBundle: Sendable {
    let rootCause: String
    let fulfillmentAreas: String
    let nextDirection: String
}

struct AppleIntelligenceFulfillmentOnboardingBundle: Sendable {
    let fulfillmentAreas: String
    let nextDirection: String
    let nudge: String?
}

struct AppleIntelligenceReadableInsightContextSeed {
    var diagnostic: LoomAIContextSnapshot.DiagnosticSummary?
    var drivingForce: LoomAIContextSnapshot.DrivingForceSummary?
    var purposeProfile: LoomAIContextSnapshot.PurposeProfileSummary?
    var fulfillmentSetup: LoomAIContextSnapshot.FulfillmentSetupSummary?
    var fulfillmentCategories: [LoomAIContextSnapshot.FulfillmentCategorySummary]
    var activeOutcomes: [LoomAIContextSnapshot.OutcomeSummary]
    var currentWeekActionBlocks: [LoomAIContextSnapshot.ActionBlockSummary]
    var recentActivity: LoomAIContextSnapshot.RecentActivitySummary
    var appGuide: [LoomAIContextSnapshot.GuideTopic]
    var dataInventory: [LoomAIContextSnapshot.KnowledgeSectionSummary]
    var notes: [String]

    static let empty = AppleIntelligenceReadableInsightContextSeed(
        diagnostic: nil,
        drivingForce: nil,
        purposeProfile: nil,
        fulfillmentSetup: nil,
        fulfillmentCategories: [],
        activeOutcomes: [],
        currentWeekActionBlocks: [],
        recentActivity: .init(
            quickCompletesLast7Days: 0,
            littleWinsCompletionsLast7Days: 0,
            carryoversLast7Days: 0
        ),
        appGuide: [],
        dataInventory: [],
        notes: []
    )
}

enum AppleIntelligenceReadableInsightContextSupport {
    static func diagnosticSummary(
        personalizationContext: PersonalizationContextValue?,
        diagnosticsSnapshot: DiagnosticsInsightsSnapshot?
    ) -> LoomAIContextSnapshot.DiagnosticSummary? {
        guard let personalization = personalizationContext else { return nil }
        return .init(
            stress: personalization.current.stressSource,
            breaksFirst: personalization.current.breakPoint,
            areas: personalization.current.lifeAreasSelected,
            planningStyle: personalization.current.planningReality,
            firstChange: personalization.current.desiredChange,
            rootCause: diagnosticsSnapshot?.rootCauseText ?? "",
            nextDirection: diagnosticsSnapshot?.nextDirectionText ?? ""
        )
    }

    static func purposeProfileSummary(
        personalizationContext: PersonalizationContextValue?,
        purposeProfileSnapshot: PurposeProfileInsightsSnapshot?
    ) -> LoomAIContextSnapshot.PurposeProfileSummary? {
        if let profileName = personalizationContext?.current.personalityMatch.winner.profileName,
           !profileName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            return .init(
                profile: profileName,
                generatedAt: personalizationContext?.current.createdAt
            )
        }
        guard let purposeProfileSnapshot else { return nil }
        return .init(
            profile: purposeProfileSnapshot.profile,
            generatedAt: purposeProfileSnapshot.generatedAt
        )
    }

    static func fulfillmentSetupSummary(
        personalizationContext: PersonalizationContextValue?
    ) -> LoomAIContextSnapshot.FulfillmentSetupSummary? {
        guard let personalization = personalizationContext?.current else { return nil }
        let names = personalization.lifeAreasSelected
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !names.isEmpty else { return nil }
        let ids = names.map {
            $0
                .lowercased()
                .replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
        }
        return .init(
            selectedCategoryIDs: ids,
            selectedCategoryNames: names,
            categoryCount: names.count,
            focusCategoryNames: Array(names.prefix(3))
        )
    }
}

enum AppleIntelligenceInsightPromptBuilder {
    private struct ReadableInsightContextEnvelope: Codable {
        struct ReadableInsightContext: Codable {
            struct FulfillmentCategory: Codable {
                let name: String
                let mission: String
                let identity: [String]
                let littleWins: [String]
                let connectedPassions: [String]
                let weeklyScore: Double?
            }

            let diagnostic: LoomAIContextSnapshot.DiagnosticSummary?
            let drivingForce: LoomAIContextSnapshot.DrivingForceSummary?
            let purposeProfile: LoomAIContextSnapshot.PurposeProfileSummary?
            let fulfillmentSetup: LoomAIContextSnapshot.FulfillmentSetupSummary?
            let fulfillmentCategories: [FulfillmentCategory]
            let activeOutcomes: [LoomAIContextSnapshot.OutcomeSummary]
            let currentWeekActionBlocks: [LoomAIContextSnapshot.ActionBlockSummary]
            let recentActivity: LoomAIContextSnapshot.RecentActivitySummary
            let appGuide: [LoomAIContextSnapshot.GuideTopic]
            let dataInventory: [LoomAIContextSnapshot.KnowledgeSectionSummary]
            let notes: [String]
        }

        let version: Int
        let surfaceID: String
        let context: ReadableInsightContext?
    }

    private struct ContextEnvelope: Codable {
        let version: Int
        let surfaceID: String
        let context: LoomAIContextSnapshot?
    }

    static let appContextVersion = 2
    static let readableInsightContextVersion = 1
    static let purposeFormulaVersion = 2
    static let fulfillmentFormulaVersion = 2

    static func contextJSON(surfaceID: String, context: LoomAIContextSnapshot?) -> String {
        let envelope = ContextEnvelope(
            version: appContextVersion,
            surfaceID: surfaceID,
            context: context?.compactedForLoomAI()
        )
        return encodeJSON(envelope)
    }

    static func contextJSON(surfaceID: String, seed: AppleIntelligenceReadableInsightContextSeed) -> String {
        contextJSON(
            surfaceID: surfaceID,
            context: lightweightContextSnapshot(from: seed)
        )
    }

    static func contextSignature(surfaceID: String, context: LoomAIContextSnapshot?) -> String {
        stableHash(contextJSON(surfaceID: surfaceID, context: context))
    }

    static func contextSignature(surfaceID: String, seed: AppleIntelligenceReadableInsightContextSeed) -> String {
        stableHash(contextJSON(surfaceID: surfaceID, seed: seed))
    }

    static func readableInsightContextJSON(surfaceID: String, context: LoomAIContextSnapshot?) -> String {
        let compact = context?.compactedForLoomAI()
        let envelope = ReadableInsightContextEnvelope(
            version: readableInsightContextVersion,
            surfaceID: surfaceID,
            context: compact.map { snapshot in
                ReadableInsightContextEnvelope.ReadableInsightContext(
                    diagnostic: snapshot.diagnostic,
                    drivingForce: snapshot.drivingForce,
                    purposeProfile: snapshot.purposeProfile,
                    fulfillmentSetup: snapshot.fulfillmentSetup,
                    fulfillmentCategories: snapshot.fulfillmentCategories.prefix(6).map {
                        .init(
                            name: $0.name,
                            mission: String($0.mission.prefix(120)),
                            identity: Array($0.identity.prefix(3)),
                            littleWins: Array($0.littleWins.prefix(3)),
                            connectedPassions: Array($0.connectedPassions.prefix(3)),
                            weeklyScore: $0.weeklyScore
                        )
                    },
                    activeOutcomes: Array(snapshot.activeOutcomes.prefix(4)),
                    currentWeekActionBlocks: Array(snapshot.currentWeekActionBlocks.prefix(4)),
                    recentActivity: snapshot.recentActivity,
                    appGuide: Array(snapshot.appGuide.prefix(6)),
                    dataInventory: Array(snapshot.dataInventory.prefix(8)).map {
                        .init(
                            id: $0.id,
                            title: $0.title,
                            currentCount: $0.currentCount,
                            historicalCount: $0.historicalCount,
                            keySignals: Array($0.keySignals.prefix(4)),
                            sampleItems: Array($0.sampleItems.prefix(2))
                        )
                    },
                    notes: Array(snapshot.notes.prefix(4))
                )
            }
        )
        return encodeJSON(envelope)
    }

    static func readableInsightContextJSON(surfaceID: String, seed: AppleIntelligenceReadableInsightContextSeed) -> String {
        readableInsightContextJSON(
            surfaceID: surfaceID,
            context: lightweightContextSnapshot(from: seed)
        )
    }

    static func readableInsightContextSignature(surfaceID: String, context: LoomAIContextSnapshot?) -> String {
        stableHash(readableInsightContextJSON(surfaceID: surfaceID, context: context))
    }

    static func readableInsightContextSignature(
        surfaceID: String,
        seed: AppleIntelligenceReadableInsightContextSeed
    ) -> String {
        stableHash(readableInsightContextJSON(surfaceID: surfaceID, seed: seed))
    }

    static func purposeFormulaGuide() -> String {
        """
        Purpose score guide:
        - Current Score is the stabilized evidence score on a 0.0 to 4.0 scale. A first record starts from a neutral 2.0 baseline.
        - Month Score is the previous measured month on the same 0.0 to 4.0 scale.
        - Momentum describes the slope of stabilized evidence over time: improving, stable, or declining.
        - Consistency reflects volatility across recent months: stable, mixed, or volatile.
        - Structure = 60% passion-count saturation plus 40% fulfillment-link saturation.
        - Action Blocks = average follow-through across linked weekly action blocks, weighted 60% block completion and 40% action completion.
        - Carryover penalty = average carried-over rate from linked action blocks; lower is better.
        - Little Wins = completion rate of linked little wins.
        - Outcomes = average score of connected outcomes when they exist.
        - Evidence combines Structure (0.15), Action Blocks (0.25), inverse Carryover penalty (0.10), Little Wins (0.20), and Outcomes (0.30).
        - If Outcomes are missing, the 0.30 Outcomes weight is redistributed to Action Blocks and Little Wins instead of treating Outcomes as failed.
        - Stabilized Evidence = 0.85 * Evidence + 0.15 * (Evidence * Consistency).
        - High Structure without Action Blocks or Little Wins means setup exists but daily or weekly execution is thin.
        - High Outcomes with weaker Action Blocks or Little Wins means direction is clear but support is not yet durable.
        """
    }

    static func fulfillmentFormulaGuide() -> String {
        """
        Fulfillment score guide:
        - Current Score is the stabilized evidence score on a 1.0 to 5.0 scale. A first record starts from a neutral 3.0 baseline.
        - Week Score is the previous measured week on the same 1.0 to 5.0 scale.
        - Momentum describes the slope of stabilized evidence over recent weeks: improving, stable, or declining.
        - Consistency reflects volatility across recent weeks: stable, mixed, or volatile.
        - Structure = vision present (0.20) + mission/purpose present (0.20) + identities/roles (0.18) + resources (0.14) + passions linked (0.14) + little wins defined (0.14).
        - Action Blocks = mean completion across the area's weekly action blocks.
        - Carryover penalty = mean carryover rate from the area's action blocks; lower is better.
        - Little Wins = completion rate of the area's scheduled little wins.
        - Engagement = engaged days this week divided by 4.0, clamped at 100%.
        - Strategic Behavior = 65% strategic completion share plus 35% inverse reactive carryover.
        - Outcomes = average score of linked outcomes when they exist.
        - Evidence combines Structure (0.18), Action Blocks (0.22), inverse Carryover penalty (0.12), Little Wins (0.20), Engagement (0.13), Strategic Behavior (0.15), and optional Outcomes (0.25).
        - If Outcomes are present, the Outcomes weight is added by shaving weight from Action Blocks, Little Wins, and Strategic Behavior. If Outcomes are missing, that weight is not treated as failure.
        - Stabilized Evidence = 0.85 * Evidence + 0.15 * (Evidence * Consistency).
        - High activity with weaker Strategic Behavior means the user is busy but not directing effort deliberately enough.
        - High Outcomes with weaker Action Blocks or Little Wins means the area has direction but needs steadier support.
        """
    }

    static func encodeJSON<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return ((try? encoder.encode(value)).flatMap { String(data: $0, encoding: .utf8) }) ?? "{}"
    }

    static func payloadSignature<T: Encodable>(_ value: T) -> String {
        stableHash(encodeJSON(value))
    }

    private static func stableHash(_ raw: String) -> String {
        raw.unicodeScalars.reduce(UInt64(5381)) { acc, scalar in
            ((acc << 5) &+ acc) &+ UInt64(scalar.value)
        }
        .description
    }

    private static func lightweightContextSnapshot(
        from seed: AppleIntelligenceReadableInsightContextSeed
    ) -> LoomAIContextSnapshot {
        LoomAIContextSnapshot(
            generatedAt: .now,
            personalizationHash: "readable-insight-seed",
            diagnostic: seed.diagnostic,
            drivingForce: seed.drivingForce,
            fulfillmentCategories: seed.fulfillmentCategories,
            activeOutcomes: seed.activeOutcomes,
            currentWeekActionBlocks: seed.currentWeekActionBlocks,
            recentActivity: seed.recentActivity,
            capture: nil,
            recentlyDeleted: nil,
            sectionTimestamps: nil,
            purposeProfile: seed.purposeProfile,
            dataInventory: seed.dataInventory,
            appGuide: seed.appGuide,
            notes: seed.notes,
            purposeDraft: nil,
            fulfillmentSetup: seed.fulfillmentSetup,
            personalization: nil,
            reflectionJournal: nil,
            shareAttachmentPreview: nil
        )
    }
}

enum AppleIntelligenceReadableInsightNormalizer {
    static func fromPlainText(_ text: String) -> AppleIntelligenceReadableInsightResult {
        let paragraphs = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .flatMap { $0.components(separatedBy: "\n") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if paragraphs.count >= 2 {
            return AppleIntelligenceReadableInsightResult(
                insight: paragraphs[0],
                action: paragraphs[1]
            )
        }

        guard let only = paragraphs.first else {
            return AppleIntelligenceReadableInsightResult(insight: "", action: "")
        }

        let sentences = splitSentences(in: only)
        if sentences.count >= 2 {
            return AppleIntelligenceReadableInsightResult(
                insight: sentences[0],
                action: sentences[1]
            )
        }

        return AppleIntelligenceReadableInsightResult(insight: only, action: "")
    }

    private static func splitSentences(in text: String) -> [String] {
        var sentences: [String] = []
        var current = ""

        for character in text {
            current.append(character)
            if ".!?".contains(character) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    sentences.append(trimmed)
                }
                current = ""
            }
        }

        let trailing = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trailing.isEmpty {
            sentences.append(trailing)
        }

        return sentences
    }
}

enum AppleIntelligencePurposeVisionGenerator {
    static func suggestions(
        personalization: PersonalizationSnapshot?,
        currentVision: String,
        previousSuggestions: [String]
    ) async throws -> [String] {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .general)
            guard AppleIntelligenceSupport.isAvailable, model.isAvailable else { throw AppleIntelligencePurposeInsightsError.unavailable }
            let session = LanguageModelSession(model: model)
            let response = try await session.respond(
                to: purposeVisionPrompt(
                    personalization: personalization,
                    currentVision: currentVision,
                    previousSuggestions: previousSuggestions
                ),
                generating: AppleIntelligencePurposeVisionOutput.self
            )
            return response.content.suggestions
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        #endif
        throw AppleIntelligencePurposeInsightsError.unavailable
    }

    private static func purposeVisionPrompt(
        personalization: PersonalizationSnapshot?,
        currentVision: String,
        previousSuggestions: [String]
    ) -> String {
        struct Payload: Codable {
            let personalization: PersonalizationSnapshot?
            let currentVision: String
            let previousSuggestions: [String]
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let payload = Payload(
            personalization: personalization,
            currentVision: currentVision.trimmingCharacters(in: .whitespacesAndNewlines),
            previousSuggestions: previousSuggestions
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        let payloadJSON = ((try? encoder.encode(payload)).flatMap { String(data: $0, encoding: .utf8) }) ?? "{}"

        return """
        Generate 2 short Loom Purpose Vision suggestions.

        Requirements:
        - Return exactly 2 suggestions in the structured output.
        - Each suggestion should be 16 to 28 words.
        - Write in first person singular.
        - Make each suggestion sound concrete, intentional, and aspirational.
        - Ground the wording in the personalization input when present.
        - Favor clarity, momentum, balance, health, relationships, career, or freedom only when supported by the input.
        - Do not repeat or lightly rephrase the current vision.
        - Do not reuse the previous suggestions.
        - Avoid filler, cliches, and generic motivational language.
        - Return only the structured output fields.

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
            guard AppleIntelligenceSupport.isAvailable, model.isAvailable else { throw AppleIntelligencePurposeInsightsError.unavailable }
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
        You are generating one Loom weekly Result from a list of actions.

        Goal:
        - Infer the single unifying outcome the actions contribute toward.
        - Express the outcome, not the tasks.
        - Imply why it matters when possible through specific outcome wording.

        Strict output requirements:
        - Return plain text only.
        - Return exactly one Result.
        - Start with a strong action verb in imperative form.
        - Use 3 to 8 words total.
        - Keep it as a single sentence.
        - No bullets, numbering, quotes, labels, or explanation.
        - No commas unless absolutely necessary.
        - No passive voice.
        - No filler words.
        - Do not list or repeat the actions.
        - Do not copy obvious action phrases from the input.
        - Avoid weak verbs such as: do, make, handle, manage, work on, complete tasks.
        - Prefer specific outcome language over vague phrasing.

        Context guidance:
        - Work tasks: prefer a deliverable, milestone, or productivity outcome.
        - Personal tasks: prefer a practical life outcome.
        - Mixed tasks: choose the most logical unifying outcome.

        Good examples:
        - Finalize key deliverables
        - Deliver essential assignments
        - Secure groceries for meals
        - Restock essential kitchen items
        - Prepare ingredients for meals

        Bad examples:
        - Completed tasks: spreadsheet, story, report
        - Cheese and milk purchased
        - Do weekly tasks
        - Handle everything
        - Make progress on stuff

        Actions:
        \(cleanedActions.map { "- \($0)" }.joined(separator: "\n"))
        """

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .general)
            guard AppleIntelligenceSupport.isAvailable, model.isAvailable else { throw AppleIntelligencePurposeInsightsError.unavailable }
            let session = LanguageModelSession(model: model)
            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif
        throw AppleIntelligencePurposeInsightsError.unavailable
    }
}

enum AppleIntelligenceLoomChatGenerator {
    struct Payload: Codable {
        struct Grounding: Codable {
            let section: String
            let field: String
            let timestamp: String
        }

        struct ActionPayload: Codable {
            let text: String?
            let categoryId: String?
            let categoryName: String?
            let identity: String?
            let replaceIdentity: String?
            let activity: String?
            let replaceActivity: String?
            let passionType: String?
            let title: String?
            let measurable: Bool?
            let unit: String?
        }

        struct Action: Codable {
            let id: String
            let title: String
            let type: String
            let payload: ActionPayload
        }

        struct SuggestionOption: Codable {
            let id: String
            let label: String
            let title: String
            let type: String
            let payload: ActionPayload
        }

        struct SuggestionCard: Codable {
            let id: String
            let title: String
            let description: String
            let options: [SuggestionOption]
        }

        struct Chip: Codable {
            let id: String
            let title: String
            let prompt: String
        }

        struct Debug: Codable {
            let usedContext: Bool
            let confidence: String
            let evidence: [String]
        }

        let message: String
        let grounding: [Grounding]
        let suggestionCards: [SuggestionCard]
        let nextAction: Action?
        let chips: [Chip]
        let actions: [Action]
        let debug: Debug?
    }

    static func chat(
        messages: [LoomAIService.TransportMessage],
        context: LoomAIContextSnapshot,
        routeDescription: String?,
        userLocalDate: String?,
        timezone: String?
    ) async throws -> Payload {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .general)
            guard AppleIntelligenceSupport.isAvailable, model.isAvailable else { throw AppleIntelligencePurposeInsightsError.unavailable }
            let session = LanguageModelSession(model: model)
            let prompt = chatPrompt(
                messages: messages,
                context: context,
                routeDescription: routeDescription,
                userLocalDate: userLocalDate,
                timezone: timezone
            )
            let response = try await session.respond(
                to: prompt,
                generating: AppleIntelligenceLoomChatOutput.self
            )
            return Payload(
                message: response.content.message,
                grounding: response.content.grounding.map {
                    .init(section: $0.section, field: $0.field, timestamp: $0.timestamp)
                },
                suggestionCards: response.content.suggestionCards.map { card in
                    .init(
                        id: card.id,
                        title: card.title,
                        description: card.description,
                        options: card.options.map { option in
                            .init(
                                id: option.id,
                                label: option.label,
                                title: option.title,
                                type: option.type,
                                payload: actionPayload(from: option.payload)
                            )
                        }
                    )
                },
                nextAction: response.content.nextAction.map {
                    .init(
                        id: $0.id,
                        title: $0.title,
                        type: $0.type,
                        payload: actionPayload(from: $0.payload)
                    )
                },
                chips: response.content.chips.map {
                    .init(id: $0.id, title: $0.title, prompt: $0.prompt)
                },
                actions: response.content.actions.map {
                    .init(
                        id: $0.id,
                        title: $0.title,
                        type: $0.type,
                        payload: actionPayload(from: $0.payload)
                    )
                },
                debug: response.content.debug.map {
                    .init(
                        usedContext: $0.usedContext,
                        confidence: $0.confidence,
                        evidence: $0.evidence
                    )
                }
            )
        }
        #endif
        throw AppleIntelligencePurposeInsightsError.unavailable
    }

    static func chatFallbackText(
        messages: [LoomAIService.TransportMessage],
        context: LoomAIContextSnapshot,
        routeDescription: String?,
        userLocalDate: String?,
        timezone: String?
    ) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .general)
            guard AppleIntelligenceSupport.isAvailable, model.isAvailable else { throw AppleIntelligencePurposeInsightsError.unavailable }
            let session = LanguageModelSession(model: model)
            let response = try await session.respond(
                to: chatFallbackPrompt(
                    messages: messages,
                    context: context,
                    routeDescription: routeDescription,
                    userLocalDate: userLocalDate,
                    timezone: timezone
                )
            )
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif
        throw AppleIntelligencePurposeInsightsError.unavailable
    }

    static func threadTitle(transcript: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            let model = SystemLanguageModel(useCase: .general)
            guard AppleIntelligenceSupport.isAvailable, model.isAvailable else { throw AppleIntelligencePurposeInsightsError.unavailable }
            let session = LanguageModelSession(model: model)
            let response = try await session.respond(to: titlePrompt(transcript: transcript))
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        #endif
        throw AppleIntelligencePurposeInsightsError.unavailable
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private static func actionPayload(
        from payload: AppleIntelligenceLoomChatActionPayloadOutput
    ) -> Payload.ActionPayload {
        Payload.ActionPayload(
            text: payload.text,
            categoryId: payload.categoryId,
            categoryName: payload.categoryName,
            identity: payload.identity,
            replaceIdentity: payload.replaceIdentity,
            activity: payload.activity,
            replaceActivity: payload.replaceActivity,
            passionType: payload.passionType,
            title: payload.title,
            measurable: payload.measurable,
            unit: payload.unit
        )
    }
    #endif

    private static func chatPrompt(
        messages: [LoomAIService.TransportMessage],
        context: LoomAIContextSnapshot,
        routeDescription: String?,
        userLocalDate: String?,
        timezone: String?
    ) -> String {
        struct ChatInput: Codable {
            let routeDescription: String?
            let userLocalDate: String?
            let timezone: String?
            let messages: [LoomAIService.TransportMessage]
            let context: LoomAIContextSnapshot
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let payload = ChatInput(
            routeDescription: routeDescription,
            userLocalDate: userLocalDate,
            timezone: timezone,
            messages: messages,
            context: context
        )
        let payloadJSON = ((try? encoder.encode(payload)).flatMap { String(data: $0, encoding: .utf8) }) ?? "{}"
        let latestUserMessage = messages.last(where: { $0.role.lowercased() == "user" })?.content ?? ""
        let route = LoomAIChatProvider.resolveRoute(latestUserMessage: latestUserMessage, context: context)
        let personalizationBrief = LoomAIChatProvider.appleChatPersonalizationBrief(
            context: context,
            route: route,
            latestUserMessage: latestUserMessage
        )
        let routeSupportBrief = LoomAIChatProvider.appleChatRouteSupportBrief(
            context: context,
            route: route
        )
        let routeInstruction = LoomAIChatProvider.appleChatRouteInstruction(
            context: context,
            route: route
        )

        return """
        You are LoomAI inside the Loom app.

        Rules:
        - Ground every answer in the provided Loom messages and context only.
        - Be specific to this user. Avoid generic productivity filler.
        - Keep `message` to 1 to 2 short personalized sentences.
        - Every title, label, and prompt must be non-empty visible text.
        - Never repeat an existing Little Win, Identity, or Passion already in context.
        - If a target list already has 3 items, use a replacement action and name the exact item being replaced.
        - For Little Wins, return small repeatable actions that fit a normal day.
        - Use Loom's seeded corpora and instruction language as style guidance only, not as text to copy.
        \(routeInstruction)
        - For Love & Relationships, prefer appreciation, check-ins, planning time together, listening, or shared experiences when supported by context.
        - Confidence must be `high`, `medium`, or `low`.
        - `debug.evidence` should list the Loom fields you used.
        - If you cannot produce a valid Loom response, return low confidence with empty suggestion surfaces.

        Personalization brief:
        \(personalizationBrief.isEmpty ? "(none)" : personalizationBrief)

        Route support brief:
        \(routeSupportBrief.isEmpty ? "(none)" : routeSupportBrief)

        Input JSON:
        \(payloadJSON)
        """
    }

    private static func titlePrompt(transcript: String) -> String {
        """
        Summarize this Loom chat into a short menu title.

        Rules:
        - Return ONLY the title text.
        - 3 to 7 words preferred.
        - Max 52 characters.
        - Use the user's real topic, goal, or problem.
        - Do not start with How, What, Can, Should, or Help.
        - No ending punctuation.

        Chat transcript:
        \(transcript)
        """
    }

    private static func chatFallbackPrompt(
        messages: [LoomAIService.TransportMessage],
        context: LoomAIContextSnapshot,
        routeDescription: String?,
        userLocalDate: String?,
        timezone: String?
    ) -> String {
        struct ChatInput: Codable {
            let routeDescription: String?
            let userLocalDate: String?
            let timezone: String?
            let messages: [LoomAIService.TransportMessage]
            let context: LoomAIContextSnapshot
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let payload = ChatInput(
            routeDescription: routeDescription,
            userLocalDate: userLocalDate,
            timezone: timezone,
            messages: messages,
            context: context
        )
        let payloadJSON = ((try? encoder.encode(payload)).flatMap { String(data: $0, encoding: .utf8) }) ?? "{}"
        let latestUserMessage = messages.last(where: { $0.role.lowercased() == "user" })?.content ?? ""
        let route = LoomAIChatProvider.resolveRoute(latestUserMessage: latestUserMessage, context: context)
        let routeSupportBrief = LoomAIChatProvider.appleChatRouteSupportBrief(
            context: context,
            route: route
        )
        let routeInstruction = LoomAIChatProvider.appleChatFallbackInstruction(
            context: context,
            route: route
        )

        return """
        You are LoomAI inside the Loom app.

        Return plain text only. Do not return JSON.

        Required format:
        \(routeInstruction)

        Rules:
        - Keep MESSAGE personalized to this Loom context.
        - If OPTIONS are requested, make each option directly executable and keep each option on its own line.
        - Keep any extra text out of the reply.
        - Avoid generic filler.
        - Do not include explanations or labels beyond the required format.
        - Use Loom's seeded corpora and onboarding language as style guidance only, not as text to copy.

        Route support brief:
        \(routeSupportBrief.isEmpty ? "(none)" : routeSupportBrief)

        Input JSON:
        \(payloadJSON)
        """
    }
}

enum AppleIntelligencePurposeInsightsError: Error {
    case unavailable
    case invalidResponse
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
struct AppleIntelligenceReadableInsightOutput {
    let insight: String
    let action: String
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligenceReflectInsightOutput {
    let summary: String
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligenceDiagnosticInsightsOutput {
    let rootCause: String
    let fulfillmentAreas: String
    let nextDirection: String
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligenceFulfillmentOnboardingOutput {
    let fulfillmentAreas: String
    let nextDirection: String
    let nudge: String?
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligencePurposeVisionOutput {
    let suggestions: [String]
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

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligenceLoomChatGroundingOutput {
    let section: String
    let field: String
    let timestamp: String
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligenceLoomChatActionPayloadOutput {
    let text: String?
    let categoryId: String?
    let categoryName: String?
    let identity: String?
    let replaceIdentity: String?
    let activity: String?
    let replaceActivity: String?
    let passionType: String?
    let title: String?
    let measurable: Bool?
    let unit: String?
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligenceLoomChatActionOutput {
    let id: String
    let title: String
    let type: String
    let payload: AppleIntelligenceLoomChatActionPayloadOutput
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligenceLoomChatSuggestionOptionOutput {
    let id: String
    let label: String
    let title: String
    let type: String
    let payload: AppleIntelligenceLoomChatActionPayloadOutput
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligenceLoomChatSuggestionCardOutput {
    let id: String
    let title: String
    let description: String
    let options: [AppleIntelligenceLoomChatSuggestionOptionOutput]
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligenceLoomChatChipOutput {
    let id: String
    let title: String
    let prompt: String
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligenceLoomChatDebugOutput {
    let usedContext: Bool
    let confidence: String
    let evidence: [String]
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable
struct AppleIntelligenceLoomChatOutput {
    let message: String
    let grounding: [AppleIntelligenceLoomChatGroundingOutput]
    let suggestionCards: [AppleIntelligenceLoomChatSuggestionCardOutput]
    let nextAction: AppleIntelligenceLoomChatActionOutput?
    let chips: [AppleIntelligenceLoomChatChipOutput]
    let actions: [AppleIntelligenceLoomChatActionOutput]
    let debug: AppleIntelligenceLoomChatDebugOutput?
}
#endif
